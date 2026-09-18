# Custom packages overlay. Applied on every host via nixosModules.core so
# `pkgs.rime-frost` (and anything else we add under pkgs/) is visible to
# both NixOS and Home Manager (`useGlobalPkgs`).
{ inputs }:
final: prev: {
  rime-frost = final.callPackage ../pkgs/rime-frost.nix { };
  # 26.05 still has 0.75.4. Unstable already ships 0.85.1.
  pi-coding-agent =
    inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.pi-coding-agent;

  # Pascal Cloud hosts cannot reach proxy.golang.org. goproxy.cn is reachable
  # there, and the go-modules fetch inherits `env` from the main derivation
  # (pkgs/build-support/go/module.nix), so injecting GOPROXY here makes every
  # Go build (sops-install-secrets incl.) fetch through the CN mirror. Harmless
  # elsewhere as long as goproxy.cn stays reachable.
  sops-install-secrets = prev.sops-install-secrets.overrideAttrs (old: {
    env = (old.env or { }) // {
      GOPROXY = "https://goproxy.cn,direct";
    };
  });
}
