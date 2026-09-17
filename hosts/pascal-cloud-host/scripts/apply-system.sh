#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root" >&2
  exit 1
fi

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
nix_bin=/nix/var/nix/profiles/default/bin/nix
age_key_file=${SOPS_AGE_KEY_FILE:-/root/.config/sops/age/keys.txt}

if [ ! -x "$nix_bin" ]; then
  echo "multi-user Nix is required before applying this host" >&2
  exit 1
fi
if [ ! -r "$age_key_file" ]; then
  echo "missing SOPS age key: $age_key_file" >&2
  exit 1
fi

mihomo=$($nix_bin build --no-link --print-out-paths "$repo_dir#pascal-cloud-host-mihomo")
sops=$($nix_bin build --no-link --print-out-paths "$repo_dir#pascal-cloud-host-sops")
zashboard=$($nix_bin build --no-link --print-out-paths "$repo_dir#pascal-cloud-host-zashboard")

install -D -m 0644 "$repo_dir/hosts/pascal-cloud-host/debian/nix.conf" /etc/nix/nix.conf

if ! getent group mihomo >/dev/null; then
  groupadd --system mihomo
fi
if ! getent passwd mihomo >/dev/null; then
  useradd --system --gid mihomo --home-dir /var/lib/mihomo --create-home --shell /usr/sbin/nologin mihomo
fi

install -d -m 0750 -o root -g mihomo /etc/mihomo
config_file=$(mktemp /etc/mihomo/config.yaml.XXXXXX)
unit_file=$(mktemp /etc/systemd/system/mihomo.service.XXXXXX)
trap 'rm -f "$config_file" "$unit_file"' EXIT

SOPS_AGE_KEY_FILE="$age_key_file" "$sops/bin/sops" --decrypt "$repo_dir/secrets/mihomo.yaml" >"$config_file"
chown root:mihomo "$config_file"
chmod 0640 "$config_file"
mv -f "$config_file" /etc/mihomo/config.yaml

sed "s|@MIHOMO@|$mihomo|g" "$repo_dir/hosts/pascal-cloud-host/debian/mihomo.service.in" >"$unit_file"
chmod 0644 "$unit_file"
mv -f "$unit_file" /etc/systemd/system/mihomo.service

install -d -m 0755 -o mihomo -g mihomo /var/lib/mihomo/.config/mihomo
ui_dir=/var/lib/mihomo/.config/mihomo/ui
rm -rf "$ui_dir"
ln -s "$zashboard" "$ui_dir"
chown -h mihomo:mihomo "$ui_dir"

systemctl daemon-reload
systemctl enable --now mihomo.service
