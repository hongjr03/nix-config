# Bill of materials for this machine.
# WSL2 guest on Jiarong-Desktop. No seat, no lab services.
# Networking is Windows/Mihomo; this guest does not run its own proxy.

{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    inputs.self.nixosModules.core
    inputs.self.nixosModules.users-jiarong
  ];

  wsl.enable = true;
  wsl.defaultUser = "jiarong";

  # Windows Zed remote runs `wsl --exec cp` with no login PATH.
  # NixOS-WSL /bin is otherwise just sh/mount. Without cp the Nix
  # extension never uploads and nixd never starts.
  wsl.extraBin = [
    {
      name = "cp";
      src = "${pkgs.coreutils}/bin/cp";
    }
    {
      name = "uname";
      src = "${pkgs.coreutils}/bin/uname";
    }
    {
      name = "mkdir";
      src = "${pkgs.coreutils}/bin/mkdir";
    }
  ];

  networking.hostName = "desktop-host-wsl";

  # Flake attr is desktop-host-wsl. nh reads this first.
  environment.variables.NH_OS_FLAKE = "/home/jiarong/nix-config#desktop-host-wsl";

  # First NixOS version on this machine. Never change without reading
  # `man configuration.nix` / nixos-rebuild changelog.
  system.stateVersion = "26.05";
}
