# Custom packages overlay. Applied on every host via nixosModules.core so
# `pkgs.rime-frost` (and anything else we add under pkgs/) is visible to
# both NixOS and Home Manager (`useGlobalPkgs`).
{ inputs }:
final: prev: {
  rime-frost = final.callPackage ../pkgs/rime-frost.nix { };
  # 26.05 still has 0.75.4. Unstable already ships 0.85.1.
  pi-coding-agent =
    inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.pi-coding-agent;
}
