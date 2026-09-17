#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
exec /nix/var/nix/profiles/default/bin/nix run "$repo_dir#pascal-cloud-host-home-manager" -- switch --flake "$repo_dir#jiarong-pascal-cloud-host"
