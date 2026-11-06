# Unix account + Home Manager attachment for jiarong.
# The account is a system concern; the environment is modules/home/core.
# Graphical home (modules/home/desktop) is imported by the host that has a seat.

{
  inputs,
  pkgs,
  ...
}:

{
  imports = [ ../../sops/pi-env.nix ];

  programs.fish.enable = true;

  users.users.jiarong = {
    isNormalUser = true;
    description = "jiarong";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILVkHsWEwpLLbG4msCgpYnqKZhOpmyRM9Q4rNCxpTIJC hongj@Jiarong-Desktop"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMlyHMlFbP25zB9A1L8KpgM8Pugma1tZoRGQ2Xn+bRsP jiarong@JiarongdeMacBook-Air.local"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPp0EXEF02hTvLGQWYLMrXJVAKkBn6VcLlQ2yeEKZn25 jiarong@workstation"
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "jiarong" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # opencode rotates its Go model lineup constantly and pi's own catalog
  # sources lag it by weeks, so pull the live list once a day as this user
  # (the script rewrites ~/.pi/agent/models-store.json). Reads a public
  # endpoint, so no secret is involved. Skipped until the machine has run pi.
  systemd.services.sync-opencode-go-models = {
    description = "Refresh pi's opencode-go model catalog";
    serviceConfig = {
      Type = "oneshot";
      User = "jiarong";
      ExecStart = "${pkgs.sync-opencode-go-models}/bin/sync-opencode-go-models";
    };
  };

  systemd.timers.sync-opencode-go-models = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 09:15:00";
      # Catch up on the next boot if the box was off at 09:15.
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
  };

  home-manager.users.jiarong = {
    imports = [ inputs.self.homeModules.core ];
    programs.git.settings.user = {
      name = "hongjr03";
      email = "hongjr03@gmail.com";
    };
  };
}
