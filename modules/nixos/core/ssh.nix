{
  # Client-side ssh-agent would fight 1Password's agent.
  programs.ssh.startAgent = false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
