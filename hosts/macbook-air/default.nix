# Bill of materials for this machine.
# Hardware is still macOS; this file only says which modules it pulls in.
# Shared opinions live in modules/; they are not copied here.

{
  inputs,
  pkgs,
  ...
}:

{
  imports = [ inputs.self.darwinModules.core ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  # nix-darwin activation runs as root; user-scoped options (Homebrew,
  # defaults, etc.) apply to this account once we start using them.
  system.primaryUser = "jiarong";
  users.users.jiarong.home = "/Users/jiarong";

  # This machine already had Touch ID sudo via sudo-touchid. nix-darwin
  # owns /etc/pam.d/sudo_local, so keep the same line after the rename.
  security.pam.services.sudo_local.touchIdAuth = true;

  # Flake attr is macbook-air, not LocalHostName. nh reads this first.
  environment.variables.NH_DARWIN_FLAKE = "/Users/jiarong/nix-config#macbook-air";

  # Login shell stays macOS-managed for this existing account. After
  # switch: chsh -s /run/current-system/sw/bin/fish
  programs.fish.enable = true;
  programs.fish.useBabelfish = true;
  environment.shells = [ pkgs.fish ];

  home-manager.users.jiarong = {
    imports = [
      inputs.self.homeModules.core
      inputs.self.homeModules.zed
    ];
    programs.git = {
      settings.user = {
        name = "Hong Jiarong";
        email = "me@jrhim.com";
      };
      signing = {
        key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMlyHMlFbP25zB9A1L8KpgM8Pugma1tZoRGQ2Xn+bRsP";
        format = "ssh";
        signByDefault = true;
        signer = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      };
    };
  };

  # GUI that should exist after cloning this flake onto a new Air.
  # Already installed; brew bundle will adopt them. Everything else
  # currently in `brew list` stays imperative.
  homebrew.casks = [
    "1password"
    "1password-cli"
    "ghostty"
    "wechat"
    "telegram"
    "iina"
  ];

  # First nix-darwin version on this machine. Never change without
  # reading `darwin-rebuild changelog`.
  system.stateVersion = 6;
}
