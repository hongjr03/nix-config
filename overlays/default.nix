# Custom packages overlay. Applied on every host via nixosModules.core so
# `pkgs.rime-frost` (and anything else we add under pkgs/) is visible to
# both NixOS and Home Manager (`useGlobalPkgs`).
{ inputs }:
final: prev: {
  rime-frost = final.callPackage ../pkgs/rime-frost.nix { };
  # 26.05 still has 0.75.4. Unstable already ships 0.85.1.
  pi-coding-agent =
    inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.pi-coding-agent;

  # goproxy injection: Pascal Cloud hosts cannot reach proxy.golang.org, which
  # breaks the go-modules fetch of sops-install-secrets. sops-nix' module uses
  # `pkgs.callPackage <sops-nix source> {}` (NOT pkgs.sops-install-secrets), so
  # we queue up the patched package here; hosts that need it pick it up via
  # `sops.package` (see hosts/pascal-cloud-vm-nk3p). GOPROXY is inherited by
  # go-modules (pkgs/build-support/go/module.nix). goproxy.cn is reachable from
  # Pascal Cloud; harmless elsewhere.
  sops-install-secrets =
    (prev.callPackage inputs.sops-nix { }).sops-install-secrets.overrideAttrs
      (old: {
        env = (old.env or { }) // {
          GOPROXY = "https://goproxy.cn,direct";
        };
      });
}
