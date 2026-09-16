# Shared nix-darwin baseline for every Mac we manage.
# Hosts import this; they do not copy it.
#
# Intentionally *not* here: Homebrew cask/formula lists, system.defaults,
# hostname, or anyone's home. Those vary per machine.

{ inputs, ... }:

{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    ./nix.nix
    ./home-manager.nix
    ./tools.nix
    ./homebrew.nix
  ];

  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
}
