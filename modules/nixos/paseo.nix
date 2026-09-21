# Paseo: a self-hosted daemon that runs AI coding agents (Claude Code, Codex,
# Pi, ...) and lets desktop, mobile and CLI clients drive them.
#
# One daemon per machine, one systemd unit. Clients pair over Paseo's
# end-to-end encrypted relay by default, so no inbound firewall hole is
# needed; turn `relay.enable` off to accept direct LAN/loopback connections
# only.
#
# Run it as the login user that owns the agent credentials, not as the
# throwaway `paseo` system user, or the agents it spawns will not find the
# user's CLI tools, git config or API keys.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.paseo;

  settingsFile = (pkgs.formats.json { }).generate "paseo-config.json" cfg.settings;
in
{
  options.services.paseo = {
    enable = lib.mkEnableOption "the Paseo agent daemon";

    package = lib.mkPackageOption pkgs "paseo" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = "paseo";
      description = "User account the daemon runs as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = if cfg.user == "paseo" then "paseo" else cfg.user;
      defaultText = lib.literalExpression ''if cfg.user == "paseo" then "paseo" else cfg.user'';
      description = "Group the daemon runs as.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = if cfg.user == "paseo" then "/var/lib/paseo" else "/home/${cfg.user}/.paseo";
      defaultText = lib.literalExpression ''
        if cfg.user == "paseo"
        then "/var/lib/paseo"
        else "/home/''${cfg.user}/.paseo"
      '';
      description = "PASEO_HOME: agent data, config and logs.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6767;
      description = "Port the daemon listens on.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the daemon binds to.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open `port` in the firewall. Only needed for direct connections from
        another host; the default relay path needs no inbound port.
      '';
    };

    inheritUserEnvironment = lib.mkOption {
      type = lib.types.bool;
      default = cfg.user != "paseo";
      defaultText = lib.literalExpression ''cfg.user != "paseo"'';
      description = ''
        Put the user's profiles (system, home-manager, user) on the daemon's
        PATH, so the agents it spawns can find claude/codex/pi and friends.
      '';
    };

    relay = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Reach clients through Paseo's relay. When false, the daemon runs
          with `--no-relay` and only accepts direct connections.
        '';
      };

      endpoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "relay.example.com:443";
        description = "Self-hosted relay to use instead of the hosted default.";
      };

      useTls = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether a self-hosted relay endpoint speaks TLS.";
      };
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''{ HTTPS_PROXY = "http://127.0.0.1:7890"; }'';
      description = "Extra environment variables for the daemon.";
    };

    settings = lib.mkOption {
      type = (pkgs.formats.json { }).type;
      default = { };
      example = lib.literalExpression ''
        {
          daemon.mcp = { enabled = true; injectIntoAgents = false; };
        }
      '';
      description = ''
        Declarative `$PASEO_HOME/config.json`. Rewritten on every start, so do
        not also edit it with the `paseo` CLI.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = lib.mkIf (cfg.user == "paseo") {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
    };

    users.groups.${cfg.group} = lib.mkIf (cfg.group == "paseo") { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.paseo = {
      description = "Paseo - self-hosted daemon for AI coding agents";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = lib.mkIf (cfg.settings != { }) ''
        install -m 0600 ${settingsFile} ${cfg.dataDir}/config.json
      '';

      environment = {
        PASEO_HOME = cfg.dataDir;
        PASEO_LISTEN = "${cfg.listenAddress}:${toString cfg.port}";
      }
      // lib.optionalAttrs cfg.inheritUserEnvironment {
        # mkForce: the default systemd PATH only carries coreutils/grep/sed.
        PATH = lib.mkForce (
          lib.concatStringsSep ":" (
            [
              "/home/${cfg.user}/.nix-profile/bin"
              "/home/${cfg.user}/.local/state/nix/profile/bin"
              "/etc/profiles/per-user/${cfg.user}/bin"
            ]
            ++ [
              "/run/current-system/sw/bin"
              "/run/wrappers/bin"
              "/nix/var/nix/profiles/default/bin"
            ]
          )
        );
      }
      // lib.optionalAttrs (cfg.relay.enable && cfg.relay.endpoint != null) {
        PASEO_RELAY_ENDPOINT = cfg.relay.endpoint;
        PASEO_RELAY_USE_TLS = lib.boolToString cfg.relay.useTls;
      }
      // cfg.environment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart =
          "${cfg.package}/bin/paseo-server" + lib.optionalString (!cfg.relay.enable) " --no-relay";
        Restart = "on-failure";
        RestartSec = 5;
        # The server handles SIGTERM itself; give it room to drain.
        KillSignal = "SIGTERM";
        TimeoutStopSec = 15;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    environment.systemPackages = [ cfg.package ];
  };
}
