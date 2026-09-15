{ inputs, ... }:

{
  nixpkgs.overlays = [ inputs.self.overlays.default ];
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [ "https://mirrors.cernet.edu.cn/nix-channels/store" ];
  };
}
