# Daily check-in for the PASCAL LLM gateway (a new-api instance).
#
# The access token lives in sops, so it never enters the nix store. The
# script next to this file is vendored unmodified from upstream (stdlib
# only), so it can be diffed/replaced wholesale.
#
# A systemd timer is used instead of cron: the run is a one-shot, its
# output belongs in the journal, and Persistent= catches up a missed day
# when the machine was off.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.pascal-checkin;

  script = ./pascal-checkin.py;

  stateDir = "/var/lib/pascal-checkin";
in
{
  options.services.pascal-checkin = {
    enable = lib.mkEnableOption "daily PASCAL platform check-in";

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Account the check-in runs as; should own the sops secret.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 08:13:00";
      example = "*-*-* 07:00:00";
      description = "systemd calendar spec for the daily run.";
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "20min";
      description = "Spread runs of many machines off the exact same second.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.pascal_checkin_token = {
      owner = cfg.user;
      mode = "0400";
    };

    systemd.services.pascal-checkin = {
      description = "PASCAL platform daily check-in";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      # Type=oneshot + Restart= retries transient failures (exit 4) with
      # backoff, but never a bad token (2) or a missing scope (3/5).
      startLimitIntervalSec = 0;
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        StateDirectory = "pascal-checkin";
        StateDirectoryMode = "0700";
        ExecStart = ''
          ${pkgs.python3}/bin/python3 ${script} \
            --token-file ${config.sops.secrets.pascal_checkin_token.path} \
            --log-file ${stateDir}/checkin.log
        '';
        Restart = "on-failure";
        RestartSec = "15min";
        RestartPreventExitStatus = [
          2 # token invalid / expired
          3 # token lacks wallet:write
          5 # local config problem
        ];
        # The script already logs to ${stateDir}/checkin.log; journald gets
        # the same lines so `journalctl -u pascal-checkin` is enough.
        SyslogIdentifier = "pascal-checkin";
      };
    };

    systemd.timers.pascal-checkin = {
      description = "Daily PASCAL platform check-in";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        RandomizedDelaySec = cfg.randomizedDelaySec;
        Persistent = true;
      };
    };
  };
}
