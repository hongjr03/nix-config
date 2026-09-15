# Declarative Plasma. High-level options first; configFile for things
# rc2nix captured that have no module yet (per-device libinput).
#
# overrideConfig is off on purpose: rc2nix does not capture panels, and
# kwin tiling IDs are per-output. Turning it on would reset the panel.

{ inputs, ... }:

{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  programs.plasma = {
    enable = true;

    input.keyboard.layouts = [ { layout = "us"; } ];

    kwin.virtualDesktops.number = 1;

    configFile = {
      # Compx 8k is the pointer whose wheel should be inverted.
      "kcminputrc"."Libinput/14139/4569/Compx Wireless mouse 8k dongle-L".NaturalScroll = true;
      "kcminputrc"."Libinput/1133/50504/Logitech USB Receiver Mouse".NaturalScroll = false;
      "kcminputrc"."Libinput/14139/4569/Compx Wireless mouse 8k dongle-L Consumer Control".NaturalScroll =
        false;
      "kcminputrc"."Libinput/14139/4569/Compx Wireless mouse 8k dongle-L Mouse".NaturalScroll = false;
      "kcminputrc"."Libinput/1133/50504/Logitech USB Receiver Mouse".ScrollMethod = 0;

      kwinrc.Xwayland.Scale = 1.7;

      kwalletrc.Wallet.Enabled = false;
      "kwalletrc"."org.freedesktop.secrets".apiEnabled = true;

      "plasma-localerc".Formats.LANG = "zh_CN.UTF-8";
    };
  };
}
