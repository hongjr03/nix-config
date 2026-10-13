# Developer QoL that belongs on every machine we rebuild from this flake.

{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.python3 ];

  programs.nh = {
    enable = true;
    flake = "/home/jiarong/nix-config";
  };

  # Let Zed (and other FHS-unaware binaries) resolve a normal Linux dynamic
  # linker. Language servers it downloads into ~/.local/share/zed then work.
  programs.nix-ld.enable = true;
}
