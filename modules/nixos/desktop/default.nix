# Graphical workstation profile: Plasma 6, fcitx5, PipeWire, and GUI apps.
# Import this from a host that has a seat. Lab policy (autologin, KRDP port,
# sleep) stays on the host — that is "this box", not "a desktop".

{
  config,
  lib,
  pkgs,
  ...
}:

{
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      # Plasma/KWin owns text-input; do not set GTK_IM_MODULE/QT_IM_MODULE.
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-gtk
        fcitx5-mellow-themes
        # 白霜拼音. modules/home/desktop enables rime_frost_suggestion.
        (fcitx5-rime.override {
          rimeDataPkgs = [ rime-frost ];
        })
      ];
      settings = {
        # Grok uses Ctrl+Space for voice recording; don't steal it.
        globalOptions."Hotkey/TriggerKeys"."0" = "Control+Shift+space";
        inputMethod = {
          "Groups/0" = {
            Name = "默认";
            "Default Layout" = "us";
            DefaultIM = "rime";
          };
          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "rime";
          GroupOrder."0" = "默认";
        };
        addons.classicui.globalSection = {
          Theme = "kwinblur-mellow-youlan";
          DarkTheme = "kwinblur-mellow-youlan-dark";
          UseDarkTheme = "True";
          "Vertical Candidate List" = "False";
        };
      };
    };
  };

  # Plasma 6 on Wayland. SDDM is the native login manager; mixing GDM + Plasma
  # is unsupported.
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    konsole # Ghostty is the terminal
    elisa
  ];
  programs.kde-pim.enable = false;
  services.orca.enable = false;

  # KWin must spawn fcitx5 as the virtual keyboard so it gets the
  # zwp_input_method socket. XDG autostart would start a second instance
  # without that socket.
  environment.etc."xdg/kwinrc".text = ''
    [Wayland]
    InputMethod=${config.i18n.inputMethod.package}/share/applications/fcitx5-wayland-launcher.desktop
  '';
  environment.etc."xdg/autostart/org.fcitx.Fcitx5.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';

  services.xserver.xkb = {
    layout = "cn";
    variant = "";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ExtensionSettings installs add-ons on first launch from addons.mozilla.org
  # (not the nix store). force_installed keeps them pinned by policy.
  programs.firefox = {
    enable = true;
    policies.ExtensionSettings =
      let
        amo = slug: "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
      in
      {
        "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
          install_url = amo "1password-x-password-manager";
          installation_mode = "force_installed";
          default_area = "navbar";
        };
        "uBlock0@raymondhill.net" = {
          install_url = amo "ublock-origin";
          installation_mode = "force_installed";
        };
      };
  };

  xdg.mime.defaultApplications = {
    "text/html" = "firefox.desktop";
    "application/xhtml+xml" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/about" = "firefox.desktop";
    "x-scheme-handler/unknown" = "firefox.desktop";
  };
  environment.sessionVariables.BROWSER = "firefox";
  environment.sessionVariables.TERMINAL = "ghostty";

  xdg.terminal-exec = {
    enable = true;
    settings = {
      KDE = [ "com.mitchellh.ghostty.desktop" ];
      default = [ "com.mitchellh.ghostty.desktop" ];
    };
  };

  # Dedicated NixOS modules install setuid/setgid wrappers and PolKit rules.
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
  };
}
