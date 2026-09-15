# Unix account + Home Manager attachment for jiarong.
# The account is a system concern; the environment is modules/home/core.
# Graphical home (modules/home/desktop) is imported by the host that has a seat.

{
  config,
  inputs,
  ...
}:

{
  users.users.jiarong = {
    isNormalUser = true;
    description = "jiarong";
    extraGroups = [
      "networkmanager"
      "wheel"
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

  home-manager.users.jiarong.imports = [ inputs.self.homeModules.core ];

  # Agent API keys: decrypted at activation, consumed by the `pi` wrapper.
  sops.secrets = {
    anthropic_api_key = { owner = "jiarong"; };
    openai_api_key = { owner = "jiarong"; };
    gemini_api_key = { owner = "jiarong"; };
    openrouter_api_key = { owner = "jiarong"; };
  };
  sops.templates."pi.env" = {
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
}
