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
    inputs.self.nixosModules.mihomo-proxy
    inputs.self.nixosModules.paseo
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

  # Campus proxy. Headless host: no TUN, explicit proxy env drives nix and
  # comin; SSH and the campus portal stay direct. See modules/nixos/mihomo-proxy.nix.
  services.mihomo-proxy = {
    enable = true;
    tunMode = false;
    setProxyEnv = true;
    extraRules = [
      # Subscription bootstrap must not depend on the proxy.
      "DOMAIN-SUFFIX,nloli.xyz,DIRECT"
    ];
  };

  # Paseo daemon: run coding agents here and pair the MacBook / phone to it.
  # Runs as jiarong so the agents inherit this user's tools and credentials;
  # remote clients reach it through Paseo's relay, so no firewall hole.
  services.paseo = {
    enable = true;
    user = "jiarong";
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
