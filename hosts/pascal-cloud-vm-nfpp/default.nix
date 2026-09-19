# Bill of materials for this machine.
# Pascal Cloud (PVE Portal) headless VM. No seat, no desktop, no lab services.
# The PVE Portal image conventions (chpasswd shim, /bin/bash, njunet script,
# guest-init one-shot) are inherited from the cloud image and kept here.

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    inputs.self.nixosModules.core
    inputs.self.nixosModules.users-jiarong
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILVkHsWEwpLLbG4msCgpYnqKZhOpmyRM9Q4rNCxpTIJC hongj@Jiarong-Desktop"
  ];

  networking.hostName = "pascal-cloud-vm-nfpp";

  # The cloud image got DHCP from virtualisation/proxmox-image.nix (and its
  # eth0 naming); this host does not import it, so state DHCP explicitly or
  # the machine comes up with no address and falls off the network on the
  # first switch.
  networking.useDHCP = false;
  networking.interfaces.ens18.useDHCP = true;

  # The portal reads this host's IP through qemu-guest-agent; without it the
  # console shows no IPs (proxmox-image.nix used to set this for the image).
  services.qemuGuest.enable = true;

  # BIOS (Grub) VM on PVE; no EFI partition exists.
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  # The portal resets root's password via /usr/sbin/chpasswd and expects
  # password ssh to still work; root keys also stay authorized.
  # mkForce: the core baseline disables password auth for normal machines.
  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "yes";
    PasswordAuthentication = lib.mkForce true;
    KbdInteractiveAuthentication = lib.mkForce true;
  };
  users.mutableUsers = true;
  services.fail2ban.enable = true;

  # PVE Portal changes passwords via /usr/sbin/chpasswd; /server-scripts
  # expect /bin/bash.
  systemd.tmpfiles.rules = [
    "d /usr/sbin 0755 root root -"
    "L+ /usr/sbin/chpasswd - - - - ${pkgs.shadow}/bin/chpasswd"
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
  ];

  users.motd = ''
    ==========================================
           Welcome to the PASCAL Cloud
    ==========================================
    注意事项：
    1. 重要数据请随时备份
    2. 联网请执行 /server-scripts/njunet.sh
    ==========================================
  '';

  # switch 会 SIGTERM cloud-init。runcmd 只用 boot+reboot；哨兵在第二次开机写。
  systemd.services.pve-portal-guest-init = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!/var/lib/pve-portal/guest-init.done";
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.curl
      pkgs.gnutar
      pkgs.gzip
      pkgs.coreutils
      pkgs.nix
    ];
    script = ''
      set -eu
      ${pkgs.curl}/bin/curl -o /server-scripts.tar.gz https://box.nju.edu.cn/seafhttp/f/77a8ccfa9e4440bca365/?op=view
      ${pkgs.gnutar}/bin/tar -xzf /server-scripts.tar.gz -C /
      rm -f /server-scripts.tar.gz
      ${pkgs.nix}/bin/nix-collect-garbage -d
      mkdir -p /var/lib/pve-portal
      date -Is > /var/lib/pve-portal/guest-init.done
    '';
  };

  # Mihomo local proxy: campus network here is unstable for nix/GitHub.
  # Nix builds get routed through it via proxy env vars below; nodes are
  # picked in the dashboard. Secrets come from sops (same files as ics-host).
  # The static policy is reviewed here; mihomo refreshes its provider in its
  # state directory. The URL and controller credential never enter the store.
  sops.secrets = {
    mihomo_subscription_url.sopsFile = ../../secrets/mihomo.yaml;
    mihomo_controller_secret.sopsFile = ../../secrets/mihomo.yaml;
  };
  sops.templates."mihomo-config.yaml" = {
    restartUnits = [ "mihomo.service" ];
    content = ''
      mixed-port: 7890
      allow-lan: false
      mode: rule
      log-level: info
      ipv6: true
      external-controller: 127.0.0.1:9090
      secret: "${config.sops.placeholder.mihomo_controller_secret}"

      dns:
        enable: true
        enhanced-mode: fake-ip
        nameserver:
          - 223.5.5.5
          - 119.29.29.29

      proxy-providers:
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

      rules:
        # Campus portal and the subscription bootstrap must not depend on the
        # proxy: login has to succeed before any proxy node exists.
        - DOMAIN-SUFFIX,nju.edu.cn,DIRECT
        - DOMAIN-SUFFIX,nloli.xyz,DIRECT
        - DOMAIN-SUFFIX,pascal-lab.net,DIRECT
        - IP-CIDR,114.212.80.0/21,DIRECT
        # Campus network reaches GitHub over SSH directly, and most proxy
        # nodes refuse port 22. Keep interactive git@github.com working.
        - DST-PORT,22,DIRECT
        - MATCH,PROXY
    '';
  };
  services.mihomo = {
    enable = true;
    # Headless server: no TUN. Explicit proxy env vars (below) drive nix,
    # git over HTTPS and comin; SSH and the campus portal stay direct.
    tunMode = false;
    configFile = config.sops.templates."mihomo-config.yaml".path;
    webui = pkgs.zashboard;
  };

  # Nix builds (go-modules FODs, tarball fetches) honor proxy env vars
  # (impureEnvVars); route them through the local mihomo mixed-port.
  # NB: impureEnvVars are passed from the *client* process env, so any out-of-
  # tree nix invocation (e.g. comin) needs the same env: comin carries it too.
  systemd.services.nix-daemon.environment = {
    HTTP_PROXY = "http://127.0.0.1:7890";
    HTTPS_PROXY = "http://127.0.0.1:7890";
    NO_PROXY = "127.0.0.1,localhost,pascal-lab.net,.nju.edu.cn,114.212.0.0/16";
  };
  systemd.services.comin.serviceConfig.Environment =
    "HTTP_PROXY=http://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890";

  # Interactive shells get the same proxy. SSH is not proxied, so
  # git@github.com keeps working over the campus network's direct route.
  home-manager.users.jiarong.home.sessionVariables = {
    http_proxy = "http://127.0.0.1:7890";
    https_proxy = "http://127.0.0.1:7890";
    no_proxy = "127.0.0.1,localhost,pascal-lab.net,.nju.edu.cn,114.212.0.0/16";
  };

  # Log in to NJU campus network after the portal has installed the script.
  # Credentials are tracked in sops (secrets/njunet.yaml) and decrypted to
  # /run/secrets at activation; they never enter the Nix store.
  sops.secrets = {
    nju_id.sopsFile = ../../secrets/njunet.yaml;
    nju_password.sopsFile = ../../secrets/njunet.yaml;
  };
  sops.templates."njunet.env" = {
    path = "/run/secrets/njunet.env";
    owner = "root";
    mode = "0400";
    content = ''
      NJU_ID=${config.sops.placeholder.nju_id}
      NJU_PASSWORD=${config.sops.placeholder.nju_password}
    '';
  };

  systemd.services.nju-campus-login = {
    description = "NJU campus network login";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "pve-portal-guest-init.service"
    ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "/server-scripts/njunet.sh";
    path = [
      pkgs.bash
      pkgs.curl
    ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.templates."njunet.env".path;
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 30;
    };
    # Feed credentials through stdin so they never appear in the process list.
    script = ''
      set -eu
      printf '%s\n%s\n' "$NJU_ID" "$NJU_PASSWORD" \
        | ${pkgs.bash}/bin/bash /server-scripts/njunet.sh
    '';
  };

  # Mihomo needs the campus session up first: before login only the portal is
  # reachable, and TUN would take over DNS and break the login itself.
  systemd.services.mihomo = {
    after = [ "nju-campus-login.service" ];
    requires = [ "nju-campus-login.service" ];
  };

  # Pull origin/main and switch. Public HTTPS, no deploy key.
  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        url = "https://github.com/hongjr03/nix-config.git";
        branches.main.name = "main";
      }
    ];
  };

  # First NixOS version on this machine. Never change without reading
  # `man configuration.nix` / nixos-rebuild changelog.
  system.stateVersion = "26.05";
}
