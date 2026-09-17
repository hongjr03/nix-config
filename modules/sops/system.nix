# Shared sops-nix settings for every machine that decrypts at activation.
# Host SSH ed25519 keys are the recipients (see .sops.yaml). The admin age
# key is for editing secrets, not for this.

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
