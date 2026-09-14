{
  description = "Lab workstation NixOS configuration";

  nixConfig = {
    extra-substituters = [ "https://mirrors.cernet.edu.cn/nix-channels/store" ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  # Pinned to the nixpkgs revision this machine is already running.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/93108a538f07";

  outputs =
    { nixpkgs, ... }:
    {
      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/workstation/configuration.nix ];
      };
    };
}
