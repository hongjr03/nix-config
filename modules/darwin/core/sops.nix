# Wire sops-nix into the nix-darwin evaluation.

{ inputs, ... }:

{
  imports = [
    inputs.sops-nix.darwinModules.sops
    ../../sops/system.nix
  ];
}
