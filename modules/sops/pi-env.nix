# Materialize Pi API keys as /run/secrets/pi.env for the `pi` wrapper in
# modules/home/core. NixOS and Darwin both import this so the wrapper stays
# platform-agnostic.

{ config, ... }:

{
  sops.secrets = {
    aihub_codex_api_key.owner = "jiarong";
    aihub_deepseek_api_key.owner = "jiarong";
    opencode_api_key.owner = "jiarong";
  };
  sops.templates."pi.env" = {
    path = "/run/secrets/pi.env";
    owner = "jiarong";
    mode = "0400";
    content = ''
      AIHUB_CODEX_API_KEY=${config.sops.placeholder.aihub_codex_api_key}
      AIHUB_DEEPSEEK_API_KEY=${config.sops.placeholder.aihub_deepseek_api_key}
      OPENCODE_API_KEY=${config.sops.placeholder.opencode_api_key}
    '';
  };
}
