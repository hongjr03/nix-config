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
    # Track the 26.05 stable channel so `nix flake update nixpkgs` actually moves.
    # Keep this in lockstep with home-manager/release-26.05 below.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
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

      packages.${system}.rime-frost = pkgs.callPackage ./pkgs/rime-frost.nix { };

      # Official Nix formatter. `nix fmt` reformats the tree; `nix fmt -- --ci` checks.
      formatter.${system} = pkgs.nixfmt-tree;

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.nixfmt-tree
          pkgs.sops
          pkgs.nh
        ];
      };

      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/workstation
          inputs.comin.nixosModules.comin
        ];
      };
    };
}
