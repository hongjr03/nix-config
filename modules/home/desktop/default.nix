# jiarong's graphical environment. Imported by hosts that have a seat,
# not by the user module — a headless box should not grow Ghostty/Zed/Rime.

{ pkgs, ... }:

{
  imports = [ ./plasma.nix ];

  # Enable 白霜拼音 as the Rime default (rime-frost ships this as a suggestion file).
  home.file.".local/share/fcitx5/rime/default.custom.yaml".text = ''
    patch:
      __include: rime_frost_suggestion:/
  '';

  programs.ghostty = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      # Let TUI apps (Grok) read/write the clipboard via OSC 52 without a prompt.
      clipboard-read = "allow";
      clipboard-write = "allow";
    };
  };

  # settings.json stays mutable so the GUI can save preferences.
  programs.zed-editor = {
    enable = true;
    extraPackages = [ pkgs.nixd ];
    extensions = [ "nix" ];
  };
}
