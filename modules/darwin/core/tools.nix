# Developer QoL that belongs on every Mac we rebuild from this flake.
# nix-darwin has no programs.nh; install the package and set NH_FLAKE
# the same way the NixOS module does.

{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.nh ];

  environment.variables.NH_FLAKE = "/Users/jiarong/nix-config";
}
