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

  networking.hostName = "pascal-cloud-vm-nk3p";

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

  # comin rebuilds fetch Go modules in the build it triggers. Its service is
  # a non-interactive client for the go-modules FOD (impureEnvVars), so it
  # must source GOPROXY itself.
  systemd.services.comin.serviceConfig.Environment = "GOPROXY=https://goproxy.cn,direct";

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
