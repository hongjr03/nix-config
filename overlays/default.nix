# Custom packages overlay. Applied on every host via nixosModules.core so
# `pkgs.rime-frost` (and anything else we add under pkgs/) is visible to
# both NixOS and Home Manager (`useGlobalPkgs`).
final: _prev: {
  rime-frost = final.callPackage ../pkgs/rime-frost.nix { };
}
