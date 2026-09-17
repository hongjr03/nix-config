# Homebrew policy for every Mac we manage.
# Cask and formula *lists* live on the host. This file only turns the
# module on. The Brewfile is the source of truth: undeclared brew
# packages are uninstalled on switch.

{
  homebrew.enable = true;

  # Do not auto-update or upgrade during activation: switch stays
  # idempotent. `uninstall` drops formulae/casks/taps missing from
  # the host lists; it does not zap cask data.
  homebrew.onActivation = {
    autoUpdate = false;
    upgrade = false;
    cleanup = "uninstall";
  };
}
