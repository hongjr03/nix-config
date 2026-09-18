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

  home-manager.users.jiarong = {
    imports = [ inputs.self.homeModules.core ];
    programs.git.settings.user = {
      name = "hongjr03";
      email = "hongjr03@gmail.com";
    };
  };
}
