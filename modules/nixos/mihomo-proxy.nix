# Parameterized Mihomo proxy for every host that needs it.
#
# Hosts declare intent only: TUN or not, allow-lan or not, and any
# site-specific DIRECT rules. The DNS block, subscription provider, proxy
# group, sops wiring and Nix/comin proxy environment live here so the policy
# cannot drift between machines.
#
# Two shapes are supported:
#   - headless servers: tunMode = false, setProxyEnv = true. Explicit proxy
#     env vars drive nix, git over HTTPS and comin; SSH and the campus portal
#     stay direct.
#   - graphical desktops: tunMode = true. The TUN device captures everything
#     that does not honor proxy env vars.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.mihomo-proxy;

  listenAddress = if cfg.allowLan then "*" else "127.0.0.1";

  tunBlock = lib.optionalString cfg.tunMode ''
    tun:
      enable: true
      stack: mixed
      auto-route: true
      auto-detect-interface: true
      dns-hijack:
        - any:53

  '';

  rulesBlock =
    "rules:\n"
    + "# Site rules first: the campus portal and the subscription bootstrap must\n"
    + "# never depend on the proxy, and login has to succeed before a node exists.\n"
    + lib.concatMapStrings (r: "  - ${r}\n") (baseRules ++ cfg.extraRules)
    + "  - MATCH,PROXY\n";

  baseRules = [
    "DOMAIN-SUFFIX,nju.edu.cn,DIRECT"
    "DOMAIN-SUFFIX,pascal-lab.net,DIRECT"
    "IP-CIDR,114.212.80.0/21,DIRECT"
    # Most proxy nodes refuse port 22; keep SSH direct.
    "DST-PORT,22,DIRECT"
  ];
in
{
  options.services.mihomo-proxy = {
    enable = lib.mkEnableOption "Mihomo subscription proxy";

    tunMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Capture all traffic with a TUN device. Use on graphical hosts; on
        headless servers prefer the explicit proxy environment because TUN
        hijacks DNS and breaks campus login, SSH and port-based rules.
      '';
    };

    allowLan = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Listen on all interfaces so other LAN hosts can use the proxy.";
    };

    setProxyEnv = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Export HTTP_PROXY/HTTPS_PROXY to interactive sessions, the nix daemon
        and comin. Redundant (but harmless) when tunMode is on; expected on
        headless hosts where TUN is off.
      '';
    };

    mixedPort = lib.mkOption {
      type = lib.types.port;
      default = 7890;
      description = "HTTP/SOCKS mixed proxy port.";
    };

    externalController = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:9090";
      description = "Mihomo RESTful controller address (zashboard target).";
    };

    webui = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.zashboard;
      defaultText = lib.literalExpression "pkgs.zashboard";
      description = "Web UI shipped with mihomo (zashboard by default).";
    };

    extraRules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "DOMAIN-SUFFIX,example.com,DIRECT" ];
      description = ''
        Site-specific rules appended before `MATCH,PROXY`, after the shared
        campus/SSH DIRECT rules.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The URL and controller credential never enter the store.
    sops.secrets = {
      mihomo_subscription_url.sopsFile = ../../secrets/mihomo.yaml;
      mihomo_controller_secret.sopsFile = ../../secrets/mihomo.yaml;
    };

    sops.templates."mihomo-config.yaml" = {
      restartUnits = [ "mihomo.service" ];
      content = ''
        mixed-port: ${toString cfg.mixedPort}
        allow-lan: ${lib.boolToString cfg.allowLan}
        bind-address: "${listenAddress}"
        mode: rule
        log-level: info
        ipv6: true
        external-controller: ${cfg.externalController}
        secret: "${config.sops.placeholder.mihomo_controller_secret}"

        dns:
          enable: true
          enhanced-mode: fake-ip
          nameserver:
            - 223.5.5.5
            - 119.29.29.29

        ${tunBlock}proxy-providers:
          sub:
            type: http
            url: "${config.sops.placeholder.mihomo_subscription_url}"
            interval: 86400
            path: ./sub.yaml
            health-check:
              enable: true
              url: https://www.gstatic.com/generate_204
              interval: 300

        proxy-groups:
          - name: PROXY
            type: select
            use:
              - sub

      ''
      + rulesBlock;
    };

    services.mihomo = {
      enable = true;
      inherit (cfg) tunMode webui;
      configFile = config.sops.templates."mihomo-config.yaml".path;
    };

    systemd.services.nix-daemon.environment = lib.mkIf cfg.setProxyEnv {
      HTTP_PROXY = "http://127.0.0.1:${toString cfg.mixedPort}";
      HTTPS_PROXY = "http://127.0.0.1:${toString cfg.mixedPort}";
      NO_PROXY = "127.0.0.1,localhost,pascal-lab.net,.nju.edu.cn,114.212.0.0/16";
    };

    systemd.services.comin.serviceConfig.Environment =
      lib.mkIf (cfg.setProxyEnv && config.services.comin.enable)
        (
          "HTTP_PROXY=http://127.0.0.1:${toString cfg.mixedPort} "
          + "HTTPS_PROXY=http://127.0.0.1:${toString cfg.mixedPort}"
        );

    # Interactive shells get the same proxy. SSH is not proxied, so
    # git@github.com keeps using the network's direct route.
    environment.variables = lib.mkIf cfg.setProxyEnv {
      http_proxy = "http://127.0.0.1:${toString cfg.mixedPort}";
      https_proxy = "http://127.0.0.1:${toString cfg.mixedPort}";
      no_proxy = "127.0.0.1,localhost,pascal-lab.net,.nju.edu.cn,114.212.0.0/16";
    };
  };
}
