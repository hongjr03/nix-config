# Declarative Plasma. High-level options first; configFile for things
# rc2nix captured that have no module yet (per-device libinput).
#
# overrideConfig stays off: kwin tiling IDs are per-output.

{ inputs, ... }:

{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  programs.plasma = {
    enable = true;

    input.keyboard.layouts = [ { layout = "us"; } ];

    kwin.virtualDesktops.number = 1;

    # Matches ~/.config/plasma-org.kde.plasma.desktop-appletsrc (bottom panel).
    panels = [
      {
        location = "bottom";
        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.pager"
          "org.kde.plasma.icontasks"
          "org.kde.plasma.marginsseparator"
          {
            systemTray.items.extra = [
              "org.kde.plasma.clipboard"
              "org.kde.plasma.manage-inputmethod"
              "org.kde.plasma.keyboardlayout"
              "org.kde.plasma.keyboardindicator"
              "org.kde.plasma.notifications"
              "org.kde.plasma.volume"
              "org.kde.plasma.networkmanagement"
              "org.kde.plasma.brightness"
              "org.kde.plasma.battery"
              "org.kde.plasma.printmanager"
              "org.kde.kscreen"
              "org.kde.plasma.weather"
            ];
          }
          "org.kde.plasma.digitalclock"
          "org.kde.plasma.showdesktop"
        ];
      }
    ];

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

      # Wayland clipboard is owned by the offering app. OSC 52 copies from
      # Ghostty/Grok vanish when focus changes unless Klipper holds them.
      klipperrc.General.PreventEmptyClipboard = true;
      klipperrc.General.IgnoreSelection = true;
    };
  };
}
