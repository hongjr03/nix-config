# Shared NixOS baseline for every host we manage.
# Hosts import this; they do not copy it.
#
# Intentionally *not* here: bootloader, NetworkManager, firewall holes,
# desktop, or anyone's home. Those vary per machine.

{ inputs, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    ./nix.nix
    ./locale.nix
    ./ssh.nix
    ./tools.nix
    ./home-manager.nix
  ];
}
