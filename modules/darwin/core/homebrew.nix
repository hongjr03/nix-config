# Homebrew policy for every Mac we manage.
# Cask and formula *lists* live on the host. This file only turns the
# module on and keeps `switch` from touching undeclared packages.

{
  homebrew.enable = true;

  # Defaults, written down so nobody "tidies up" with uninstall/zap.
  # `none` = Brewfile is additive; leftover brew installs stay.
  # Do not auto-update or upgrade during activation: switch stays idempotent.
  homebrew.onActivation = {
    autoUpdate = false;
    upgrade = false;
    cleanup = "none";
  };
}
