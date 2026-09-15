# JetDirect proxy with a campus IP allowlist.
#
# 9100 is not in allowedTCPPorts (that would be 0.0.0.0/0). Access is an IP
# allowlist: seed known clients, then learn new ones from campus SSH peers
# when DHCP changes.
#
# Hosts enable this and pass site-specific addresses; they do not inline
# the iptables / socat machinery.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.lab-printer-proxy;

  allowlist = pkgs.writeShellApplication {
    name = "lab-printer-allowlist";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.iproute2
      pkgs.iptables
    ];
    text = ''
      set -euo pipefail

      state_dir=/var/lib/lab-printer-proxy
      state=$state_dir/allowed-ips
      port=${toString cfg.port}
      cidr='${cfg.campusCidr}'
      ttl=${toString cfg.allowTtlSec}
      seeds=( ${lib.concatStringsSep " " cfg.seedClientIPs} )
      now=$(date +%s)

      mkdir -p "$state_dir"
      touch "$state"

      ip_to_int() {
        local a b c d
        IFS=. read -r a b c d <<<"$1"
        echo $((a * 16777216 + b * 65536 + c * 256 + d))
      }

      in_cidr() {
        local ip=$1 net prefix ipi neti mask
        net=''${cidr%/*}
        prefix=''${cidr#*/}
        ipi=$(ip_to_int "$ip")
        neti=$(ip_to_int "$net")
        mask=$((0xFFFFFFFF << (32 - prefix) & 0xFFFFFFFF))
        (( (ipi & mask) == (neti & mask) ))
      }

      valid_ip() {
        [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
        local a b c d
        IFS=. read -r a b c d <<<"$1"
        (( a <= 255 && b <= 255 && c <= 255 && d <= 255 ))
      }

      declare -A seen=()

      while read -r ip ts _; do
        valid_ip "$ip" || continue
        [[ ''${ts:-} =~ ^[0-9]+$ ]] || continue
        if (( now - ts < ttl )); then
          seen[$ip]=$ts
        fi
      done < "$state" || true

      while read -r peer; do
        ip=''${peer%:*}
        valid_ip "$ip" || continue
        in_cidr "$ip" || continue
        seen[$ip]=$now
      done < <(ss -tnH state established sport = :22 | awk '{print $5}') || true

      if [[ ''${#seen[@]} -eq 0 ]]; then
        for ip in "''${seeds[@]}"; do
          seen[$ip]=$now
        done
      fi

      tmp=$(mktemp "$state_dir/allowed-ips.XXXXXX")
      for ip in "''${!seen[@]}"; do
        printf '%s %s\n' "$ip" "''${seen[$ip]}"
      done | sort >"$tmp"
      mv "$tmp" "$state"

      iptables -w -N lab-printer-fw 2>/dev/null || true
      iptables -w -F lab-printer-fw
      if ! iptables -w -C nixos-fw -p tcp --dport "$port" -j lab-printer-fw 2>/dev/null; then
        iptables -w -A nixos-fw -p tcp --dport "$port" -j lab-printer-fw
      fi
      for ip in "''${!seen[@]}"; do
        iptables -w -A lab-printer-fw -s "$ip" -j nixos-fw-accept
      done
    '';
  };
in
{
  options.services.lab-printer-proxy = {
    enable = lib.mkEnableOption "JetDirect proxy with a campus IP allowlist";

    backend = lib.mkOption {
      type = lib.types.str;
      description = "Printer address on the lab LAN (JetDirect).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9100;
      description = "JetDirect TCP port to listen on and forward.";
    };

    campusCidr = lib.mkOption {
      type = lib.types.str;
      description = "CIDR of campus clients allowed to be learned from SSH.";
    };

    seedClientIPs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Always-allowed client IPs, used as the initial allowlist.";
    };

    allowTtlSec = lib.mkOption {
      type = lib.types.ints.positive;
      default = 14 * 24 * 3600;
      description = "How long a learned client IP stays on the allowlist.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ allowlist ];

    # Refresh allowlist as soon as a campus SSH session starts (DHCP change).
    environment.etc."ssh/sshrc" = {
      mode = "0644";
      text = ''
        sudo -n ${lib.getExe allowlist} >/dev/null 2>&1 || true
      '';
    };

    networking.firewall.extraCommands = ''
      iptables -w -N lab-printer-fw 2>/dev/null || iptables -w -F lab-printer-fw
      iptables -w -C nixos-fw -p tcp --dport ${toString cfg.port} -j lab-printer-fw 2>/dev/null || \
        iptables -w -A nixos-fw -p tcp --dport ${toString cfg.port} -j lab-printer-fw
      ${lib.concatMapStrings (ip: ''
        iptables -w -A lab-printer-fw -s ${ip} -j nixos-fw-accept
      '') cfg.seedClientIPs}
    '';

    networking.firewall.extraStopCommands = ''
      iptables -w -D nixos-fw -p tcp --dport ${toString cfg.port} -j lab-printer-fw || true
      iptables -w -F lab-printer-fw || true
      iptables -w -X lab-printer-fw || true
    '';

    systemd.services.lab-printer-proxy = {
      description = "Proxy campus :${toString cfg.port} to lab printer at ${cfg.backend}";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "3s";
        DynamicUser = true;
      };
      script = ''
        exec ${pkgs.socat}/bin/socat \
          TCP4-LISTEN:${toString cfg.port},reuseaddr,fork,keepalive \
          TCP4:${cfg.backend}:${toString cfg.port},keepalive,connect-timeout=8
      '';
    };

    systemd.services.lab-printer-allowlist = {
      description = "Refresh JetDirect ${toString cfg.port} allowlist from campus SSH clients";
      after = [
        "firewall.service"
        "network.target"
      ];
      wants = [ "firewall.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe allowlist;
      };
    };

    systemd.timers.lab-printer-allowlist = {
      description = "Periodically refresh JetDirect ${toString cfg.port} allowlist";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "15s";
        OnUnitActiveSec = "30s";
        AccuracySec = "5s";
      };
    };
  };
}
