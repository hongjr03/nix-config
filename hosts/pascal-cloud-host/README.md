# pascal-cloud-host

`pascal-cloud-host` runs Debian with multi-user Nix. It is intentionally not
a `nixosConfiguration`: Debian remains responsible for the base OS, kernel,
networking, SSH daemon, and package bootstrap.

The tracked deployment boundary is:

- `home.nix` and `switch-home.sh`: jiarong's Home Manager environment.
- `debian/nix.conf`, `debian/mihomo.service.in`, and `apply-system.sh`:
  root-owned Nix, Mihomo, Zashboard, and systemd state.
- `secrets/mihomo.yaml`: encrypted Mihomo configuration. The private age key
  is provisioned outside Git at `/root/.config/sops/age/keys.txt`.

## Apply

Clone this repository to `/home/jiarong/nix-config`. Initial provisioning must
install multi-user Nix, create the `jiarong` sudo user, install its SSH key,
and provision the SOPS age key by an out-of-band secure channel.

After that, update the two management layers independently:

```sh
cd /home/jiarong/nix-config
./hosts/pascal-cloud-host/scripts/switch-home.sh
sudo ./hosts/pascal-cloud-host/scripts/apply-system.sh
```

`apply-system.sh` uses packages from this flake's lock file, decrypts the
Mihomo configuration only into `/etc/mihomo/config.yaml`, installs the unit,
and atomically replaces the Zashboard UI link. It never writes the age key or
decrypted secret into the Nix store.
