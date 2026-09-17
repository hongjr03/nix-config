# Wire Home Manager and sops-nix into the NixOS evaluation.
# User *accounts* live in modules/nixos/users; user *environments*
# live in modules/home and are attached there.

{ inputs, ... }:

{
  imports = [ ../../sops/system.nix ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
  };
}
