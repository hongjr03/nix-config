# jiarong's environment on any machine, graphical or not.
# Hosts attach this via the user module (NixOS) or the darwin host.

{
  pkgs,
  lib,
  ...
}:

{
  home.stateVersion = "26.05";

  programs.fish.enable = true;
  # fish sets generateCaches = mkDefault true for `man` completion. Darwin
  # uses the system man(1) (package = null at stateVersion 26.05), so that
  # option does nothing and home-manager warns.
  programs.man.generateCaches = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin false;

  programs.starship.enable = true;

  programs.fzf.enable = true;

  # `--cmd cd` makes `cd` / `cdi` the zoxide commands. Also keep the
  # classic `z` / `zi` names so both work.
  programs.zoxide = {
    enable = true;
    options = [ "--cmd cd" ];
  };
  home.shellAliases = {
    z = "cd";
    zi = "cdi";
  };

  # Identity is per-host: NixOS and this Mac commit as different people.
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings.init.defaultBranch = "main";
  };

  # 1Password GUI owns the agent (Settings → Developer → Use the SSH agent).
  # Requires the desktop session; a missing socket makes ssh skip to files.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    # Host aliases stay in ~/.ssh/config.local; this file only owns the agent.
    includes = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ "~/.ssh/config.local" ];
    settings."*".IdentityAgent =
      if pkgs.stdenv.hostPlatform.isDarwin then
        # Path contains spaces; ssh_config needs the quotes in the file.
        ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"''
      else
        "~/.1password/agent.sock";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # nvim-lspconfig does not auto-enable servers; upstream quickstart is vim.lsp.enable().
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    initLua = ''
      vim.lsp.enable("nixd")
    '';
    plugins = [ pkgs.vimPlugins.nvim-lspconfig ];
  };

  home.packages = [
    pkgs.nixd
    pkgs.fastfetch
    pkgs.sops
    pkgs.age
    pkgs.gh
    pkgs.fd
    pkgs.ripgrep
    pkgs.grok-build
    (pkgs.writeShellApplication {
      name = "pi";
      text = ''
        if [ -f /run/secrets/pi.env ]; then
          set -a
          # shellcheck disable=SC1091
          source /run/secrets/pi.env
          set +a
        fi
        exec ${lib.getExe pkgs.pi-coding-agent} "$@"
      '';
    })
  ];

  home.file.".pi/agent/models.json".source = ./pi/models.json;
  home.file.".pi/agent/settings.json".text = builtins.toJSON {
    defaultProvider = "aihub";
    defaultModel = "gpt-6-astra";
  };
}
