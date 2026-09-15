# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./lab-printer.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (final: prev: {
      rime-frost = final.callPackage ../../pkgs/rime-frost.nix { };
    })
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "workstation";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      # Plasma/KWin owns text-input; do not set GTK_IM_MODULE/QT_IM_MODULE.
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-gtk
        fcitx5-mellow-themes
        # 白霜拼音. default.custom.yaml in home.nix enables rime_frost_suggestion.
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
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  # Plasma 6 on Wayland. SDDM is the native login manager; mixing GDM + Plasma
  # is unsupported. Autologin keeps RustDesk / KRDP available on this lab box
  # after the display manager restarts (sleep is already disabled).
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "jiarong";
  };
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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "cn";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # Use the WirePlumber session manager
    #wireplumber.enable = true;
  };
  
  environment.etc."pascal-ddns.sh" = {
    source = ./pascal-ddns.sh;
    mode = "0755";
  };

  services.cron = {
    enable = true;
    systemCronJobs = [
      "*/5 * * * * jiarong /etc/pascal-ddns.sh"
    ];
  };

  
  # KRDP (Plasma Remote Desktop) ships with plasma6 and listens on 3389 once
  # enabled in System Settings → Remote Desktop. RustDesk remains the
  # unattended fallback via xdg autostart.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."jiarong" = {
    isNormalUser = true;
    description = "jiarong";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "jiarong" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Install firefox. ExtensionSettings installs add-ons on first launch
  # from addons.mozilla.org (not the nix store). force_installed keeps
  # them pinned by policy; other store add-ons remain allowed.
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

  # Firefox as the XDG default browser.
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

  # Plasma "Open in Terminal" and xdg-open of terminal apps.
  xdg.terminal-exec = {
    enable = true;
    settings = {
      KDE = [ "com.mitchellh.ghostty.desktop" ];
      default = [ "com.mitchellh.ghostty.desktop" ];
    };
  };

  # 1Password GUI + CLI. The dedicated NixOS modules install setuid/setgid
  # wrappers and PolKit rules so CLI integration, system authentication,
  # and browser-extension unlock work (plain systemPackages is not enough).
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "jiarong" ];
  };

  # Interactive bash (including SSH login) reads /etc/bashrc, not ~/.bashrc.
  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };

  programs.git = {
    enable = true;
    config = {
      user.name = "hongjr03";
      user.email = "hongjr03@gmail.com";
    };
  };

  # NixOS wiki "Global Configuration": wrap nvim with plugins + lua.
  # nvim-lspconfig does not auto-enable servers; upstream quickstart is vim.lsp.enable().
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    configure = {
      packages.myVimPackage = with pkgs.vimPlugins; {
        start = [ nvim-lspconfig ];
      };
      customLuaRC = ''
        vim.lsp.enable("nixd")
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    nixd
    fastfetch
    xpra
    xterm
    rustdesk-flutter
    sops
    age
    gh
    ghostty
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs; };
    users.jiarong = import ./home.nix;
  };

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      anthropic_api_key = { owner = "jiarong"; };
      openai_api_key = { owner = "jiarong"; };
      gemini_api_key = { owner = "jiarong"; };
      openrouter_api_key = { owner = "jiarong"; };
    };
    templates."pi.env" = {
      path = "/run/secrets/pi.env";
      owner = "jiarong";
      mode = "0400";
      content = ''
        ANTHROPIC_API_KEY=${config.sops.placeholder.anthropic_api_key}
        OPENAI_API_KEY=${config.sops.placeholder.openai_api_key}
        GEMINI_API_KEY=${config.sops.placeholder.gemini_api_key}
        OPENROUTER_API_KEY=${config.sops.placeholder.openrouter_api_key}
      '';
    };
  };

  # Start RustDesk with the graphical session so this machine can be controlled.
  environment.etc."xdg/autostart/rustdesk.desktop".source =
    "${pkgs.rustdesk-flutter}/share/applications/rustdesk.desktop";

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    ports = [ 22 ]; # Default port
    settings = {
      PasswordAuthentication = true; # Set false later if using keys only
      PermitRootLogin = "prohibit-password"; # More secure default
    };
  };

  # Mihomo (Clash Meta) + zashboard.
  # Subscription lives in the config file, not in the Nix store.
  services.mihomo = {
    enable = true;
    configFile = "/home/jiarong/.config/mihomo/config.yaml";
    webui = pkgs.zashboard;
    tunMode = true;
  };

  # Self-hosted ID + relay so LAN clients do not depend on rs.rustdesk.com.
  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    # Advertise LAN IP, not the hostname (mihomo fake-ip breaks relay).
    signal = {
      relayHosts = [ "114.212.81.57" ];
      extraArgs = [ "--mask" "114.212.80.0/21" ];
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 3389 7890 9090 21116 ];
  networking.firewall.allowedUDPPorts = [ 21116 ];
  networking.firewall.checkReversePath = "loose";
  networking.firewall.trustedInterfaces = [ "Meta" "mihomo" ];
  # JetDirect 9100 allowlist lives in ./lab-printer.nix — do not publish it here.

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [ "https://mirrors.cernet.edu.cn/nix-channels/store" ];
  };
}
