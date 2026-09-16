# Zed on a machine with a seat. Not in core: a headless box does not
# need an editor GUI. settings.json stays mutable so the GUI can save.

{ pkgs, ... }:

{
  programs.zed-editor = {
    enable = true;
    extraPackages = [ pkgs.nixd ];
    extensions = [ "nix" ];
  };
}
