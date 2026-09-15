# jiarong's environment on any machine, graphical or not.
# Hosts attach this via modules/nixos/users/jiarong.nix.

{ pkgs, lib, ... }:

{
  home.stateVersion = "26.05";

  # Interactive bash (including SSH login) reads ~/.bashrc via /etc/bashrc.
  programs.bash.enable = true;

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "hongjr03";
      email = "hongjr03@gmail.com";
    };
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
    defaultProvider = "openrouter";
  };
}
