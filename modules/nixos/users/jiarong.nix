# Unix account + Home Manager attachment for jiarong.
# The account is a system concern; the environment is modules/home/core.
# Graphical home (modules/home/desktop) is imported by the host that has a seat.

{
  config,
  inputs,
  pkgs,
  ...
}:

{
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

  # Only aihub is wired into the `pi` wrapper. Other keys stay in
  # secrets.yaml for later; they are not exported into the agent env.
  sops.secrets.aihub_api_key = {
    owner = "jiarong";
  };
  sops.templates."pi.env" = {
    path = "/run/secrets/pi.env";
    owner = "jiarong";
    mode = "0400";
    content = ''
      AIHUB_API_KEY=${config.sops.placeholder.aihub_api_key}
    '';
  };
}
