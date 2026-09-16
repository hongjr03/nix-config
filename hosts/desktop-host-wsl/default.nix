# Bill of materials for this machine.
# WSL2 guest on Jiarong-Desktop. No seat, no lab services.
# Networking is Windows/Mihomo; this guest does not run its own proxy.

{
  inputs,
  ...
}:

{
  imports = [
    inputs.self.nixosModules.core
    inputs.self.nixosModules.users-jiarong
  ];

  wsl.enable = true;
  wsl.defaultUser = "jiarong";

  networking.hostName = "desktop-host-wsl";

  # Flake attr is desktop-host-wsl. nh reads this first.
  environment.variables.NH_OS_FLAKE = "/home/jiarong/nix-config#desktop-host-wsl";

  # First NixOS version on this machine. Never change without reading
  # `man configuration.nix` / nixos-rebuild changelog.
  system.stateVersion = "26.05";
}
