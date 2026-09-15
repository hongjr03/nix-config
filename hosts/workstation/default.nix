# Bill of materials for this machine.
# Hardware, site policy, and which profiles/modules it pulls in.
# Shared opinions live in modules/; they are not copied here.

{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.self.nixosModules.core
    inputs.self.nixosModules.users-jiarong
    inputs.self.nixosModules.desktop
    inputs.self.nixosModules.lab-printer-proxy
  ];

  networking.hostName = "workstation";
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

  services.openssh.settings.PasswordAuthentication = true;

  home-manager.users.jiarong.imports = [ inputs.self.homeModules.desktop ];

  services.lab-printer-proxy = {
    enable = true;
    backend = "192.168.5.19";
    campusCidr = "114.212.80.0/21";
    seedClientIPs = [ "114.212.81.36" ];
  };

  environment.etc."pascal-ddns.sh" = {
    source = ./pascal-ddns.sh;
    mode = "0755";
  };
  services.cron = {
    enable = true;
    systemCronJobs = [
      "*/5 * * * * jiarong /etc/pascal-ddns.sh"
    ];
  };

  # Subscription lives in the config file, not in the Nix store.
  services.mihomo = {
    enable = true;
    configFile = "/home/jiarong/.config/mihomo/config.yaml";
    webui = pkgs.zashboard;
    tunMode = true;
  };

  environment.systemPackages = with pkgs; [
    xpra
    xterm
  ];

  # First NixOS version on this machine. Never change without reading
  # `man configuration.nix` / nixos-rebuild changelog.
  system.stateVersion = "26.05";
}
