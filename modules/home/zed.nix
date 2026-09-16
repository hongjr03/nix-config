# Zed from nixpkgs, for Linux seats. Darwin installs the Homebrew cask
# on the host instead (see hosts/macbook-air). Not in core: a headless
# box does not need an editor GUI. settings.json stays mutable so the
# GUI can save.

{ pkgs, ... }:

{
  programs.zed-editor = {
    enable = true;
    extraPackages = [ pkgs.nixd ];
    extensions = [ "nix" ];
  };
}
