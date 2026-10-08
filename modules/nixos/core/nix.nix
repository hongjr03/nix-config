{ inputs, ... }:

{
  nixpkgs.overlays = [ inputs.self.overlays.default ];
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Campus mirror first: reachable without the proxy, so `nh os switch`
    # still substitutes when mihomo is down. cernet is its upstream.
    # The PVE portal image declares this mirror too, but a plain value here
    # overrides its `lib.mkDefault`, so it has to be listed explicitly.
    substituters = [
      "https://mirrors.pascal-lab.net/nix-channels/store"
      "https://mirrors.cernet.edu.cn/nix-channels/store"
    ];
  };
}
