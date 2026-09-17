# Materialize AIHUB_API_KEY as /run/secrets/pi.env for the `pi` wrapper
# in modules/home/core. NixOS and Darwin both import this so the wrapper
# stays platform-agnostic.
#
# Only aihub is wired. Other keys stay in secrets.yaml for later.

{ config, ... }:

{
  sops.secrets.aihub_api_key = {
    owner = "jiarong";
  };
  sops.templates."pi.env" = {
    path = "/run/secrets/pi.env";
    owner = "jiarong";
    mode = "0400";
    content = ''
      AIHUB_API_KEY=${config.sops.placeholder.aihub_api_key}
    '';
  };
}
