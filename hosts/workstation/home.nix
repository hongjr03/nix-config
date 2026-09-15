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
}
