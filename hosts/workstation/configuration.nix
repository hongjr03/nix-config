# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  nixpkgs.config.allowUnfree = true;

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
    fcitx5.addons = with pkgs; [
      # These are frontend modules for different toolkits (GTK/Qt)
      # They are usually necessary for the IME to work in various apps.
      fcitx5-gtk
      qt6Packages.fcitx5-chinese-addons # If you use Qt apps (KDE, etc.)
      
      # A basic color theme (optional, but nice)
      fcitx5-nord
    ];
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

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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

  
  services.gnome.gnome-remote-desktop.enable = true;

  systemd.services.gnome-remote-desktop = {
    wantedBy = [ "graphical.target" ];
  };
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

  # Install firefox.
  programs.firefox.enable = true;

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
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

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
