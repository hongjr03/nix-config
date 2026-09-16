# Wire Home Manager into the nix-darwin evaluation.
# User *accounts* live on the host; user *environments* live in
# modules/home and are attached there.

{ inputs, ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
  };
}
