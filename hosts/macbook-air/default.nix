# Bill of materials for this machine.
# Hardware is still macOS; this file only says which modules it pulls in.
# Shared opinions live in modules/; they are not copied here.

{ inputs, ... }:

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

  # First nix-darwin version on this machine. Never change without
  # reading `darwin-rebuild changelog`.
  system.stateVersion = 6;
}
