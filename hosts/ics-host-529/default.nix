# Bill of materials for this machine.
# Hardware, site policy, and which profiles/modules it pulls in.
# Shared opinions live in modules/; they are not copied here.

{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    inputs.self.nixosModules.core
    inputs.self.nixosModules.users-jiarong
    inputs.self.nixosModules.desktop
    inputs.self.nixosModules.lab-printer-proxy
  ];

  # Kernel/DNS hostname cannot contain '@' (RFC 1123 / NixOS type).
  # Pretty name is what hostnamectl and desktop UIs show.
  networking.hostName = "ics-host-529";
  environment.etc."machine-info".text = ''
    PRETTY_HOSTNAME=ics-host@529
  '';
  networking.networkmanager.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # This lab box stays reachable; a laptop would not set these.
  services.displayManager.autoLogin = {
    enable = true;
    user = "jiarong";
  };
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # KRDP (Plasma Remote Desktop) listens on 3389 once enabled in System Settings.
  networking.firewall.allowedTCPPorts = [
    3389
    7890
    9090
    21116
  ];
  networking.firewall.allowedUDPPorts = [ 21116 ];
  networking.firewall.checkReversePath = "loose";
  networking.firewall.trustedInterfaces = [
    "Meta"
    "mihomo"
  ];

  home-manager.users.jiarong.imports = [ inputs.self.homeModules.desktop ];

  services.lab-printer-proxy = {
    enable = true;
    backend = "192.168.5.19";
    campusCidr = "114.212.80.0/21";
    seedClientIPs = [ "114.212.81.36" ];
  };

  # Bearer token lives in sops; the script only reads it at runtime so it
  # never enters the nix store (environment.etc is world-readable).
  sops.secrets.pascal_ddns_token = {
    owner = "jiarong";
    mode = "0400";
  };
  environment.etc."pascal-ddns.sh" = {
    mode = "0755";
    source = pkgs.writeShellScript "pascal-ddns.sh" ''
      set -eu
      export PATH=/run/current-system/sw/bin:/run/wrappers/bin
      token=$(tr -d '\n' < ${config.sops.secrets.pascal_ddns_token.path})
      [ -n "$token" ]
      sleep "$(od -An -N2 -tu2 /dev/urandom | awk -v max=291 '{ gsub(/[[:space:]]/, "", $0); print $0 - max * int($0 / max) }')"
      ip a | curl -fsS -X POST http://pascal08.svr.pascal-lab.net:8788/api/v1/report \
        -H "Authorization: Bearer $token" \
        -H 'Content-Type: text/plain; charset=utf-8' \
        --data-binary @- >/dev/null
    '';
  };
  services.cron = {
    enable = true;
    systemCronJobs = [
      "*/5 * * * * jiarong /etc/pascal-ddns.sh"
    ];
  };

  # Subscription URL and dashboard secret stay in sops. The NixOS module
  # LoadCredentials the decrypted file so it never lands in the nix store.
  sops.secrets.mihomo-config = {
    format = "binary";
    sopsFile = ../../secrets/mihomo.yaml;
    restartUnits = [ "mihomo.service" ];
  };
  services.mihomo = {
    enable = true;
    configFile = config.sops.secrets.mihomo-config.path;
    webui = pkgs.zashboard;
    tunMode = true;
  };

  environment.systemPackages = with pkgs; [
    xpra
    xterm
  ];

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
