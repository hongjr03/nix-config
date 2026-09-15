{
  description = "NixOS + Home Manager configuration";

  # Layers, bottom to top:
  #   pkgs/            derivations
  #   overlays/        make them visible as pkgs.*
  #   modules/nixos    system profiles and parameterized services
  #   modules/home     user environments (core = any host, desktop = a seat)
  #   hosts/<name>     one machine: hardware + which modules it imports
  #
  # A host file is a bill of materials. It should read as "what this box is",
  # not as a dump of every option.

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
    inputs@{ self, nixpkgs, ... }:
    {
      overlays.default = import ./overlays;

      nixosModules = {
        core = ./modules/nixos/core;
        desktop = ./modules/nixos/desktop;
        users-jiarong = ./modules/nixos/users/jiarong.nix;
        lab-printer-proxy = ./modules/nixos/lab-printer-proxy.nix;
      };

      homeModules = {
        core = ./modules/home/core;
        desktop = ./modules/home/desktop;
      };

      packages.x86_64-linux.rime-frost =
        nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/rime-frost.nix { };

      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/workstation ];
      };
    };
}
