{ pkgs, lib, ... }:

{
  home.stateVersion = "26.05";

  # Wrapper loads sops-rendered API keys, then execs upstream `pi`.
  home.packages = [
    pkgs.grok-build
    (pkgs.writeShellApplication {
      name = "pi";
      text = ''
        if [ -f /run/secrets/pi.env ]; then
          set -a
          # shellcheck disable=SC1091
          source /run/secrets/pi.env
          set +a
        fi
        exec ${lib.getExe pkgs.pi-coding-agent} "$@"
      '';
    })
  ];

  home.file.".pi/agent/models.json".source = ./pi/models.json;
  home.file.".pi/agent/settings.json".text = builtins.toJSON {
    defaultProvider = "openrouter";
  };

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
}
