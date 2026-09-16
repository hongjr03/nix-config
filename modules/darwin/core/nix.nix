{ inputs, ... }:

{
  nixpkgs.overlays = [ inputs.self.overlays.default ];
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Flake `nixConfig.extra-substituters` is a restricted setting.
    # nix-darwin already trusts root; @admin covers this laptop's account.
    trusted-users = [ "@admin" ];
    substituters = [ "https://mirrors.cernet.edu.cn/nix-channels/store" ];
  };
}
