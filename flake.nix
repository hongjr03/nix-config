{
  description = "Lab workstation NixOS configuration";

  nixConfig = {
    extra-substituters = [ "https://mirrors.cernet.edu.cn/nix-channels/store" ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    # Pinned to the nixpkgs revision this machine is already running.
    nixpkgs.url = "github:NixOS/nixpkgs/93108a538f07";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    {
      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/workstation/configuration.nix ];
      };
    };
}
