# jiarong's graphical environment. Imported by hosts that have a seat,
# not by the user module — a headless box should not grow Ghostty/Zed/Rime.

{ pkgs, ... }:

{
  imports = [
    ./plasma.nix
    ../zed.nix
  ];

  # Enable 白霜拼音 as the Rime default (rime-frost ships this as a suggestion file).
  home.file.".local/share/fcitx5/rime/default.custom.yaml".text = ''
    patch:
      __include: rime_frost_suggestion:/
  '';

  home.packages = [ pkgs.wl-clipboard ];

  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      # OSC 52: Grok (and other TUIs) copy/paste the system clipboard
      # without a prompt. Klipper is told to hold the result in plasma.nix.
      clipboard-read = "allow";
      clipboard-write = "allow";
    };
  };
}
