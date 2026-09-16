{
  description = "NixOS + nix-darwin + Home Manager configuration";

  # Layers, bottom to top:
  #   pkgs/            derivations
  #   overlays/        make them visible as pkgs.*
  #   modules/nixos    NixOS system profiles and parameterized services
  #   modules/darwin   nix-darwin system profiles
  #   modules/home     user environments (core = any host, desktop = a seat)
  #   hosts/<name>     one machine: hardware + which modules it imports
  #
  # A host file is a bill of materials. It should read as "what this box is",
  # not as a dump of every option.
  #
  # Do not put substituters in flake `nixConfig`. Restricted settings make
  # `direnv use flake` prompt, and the prompt is unanswerable from a fish
  # hook. The Cernet mirror lives on each machine via nix.settings.

  inputs = {
    # Track the 26.05 stable channel so `nix flake update nixpkgs` actually moves.
    # Keep this in lockstep with home-manager/release-26.05 below.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Darwin packages get their own 26.05 backport branch; nix-darwin-26.05
    # is documented to follow this, not nixos-26.05.
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
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
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-darwin,
      ...
    }:
    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${linuxSystem};
      darwinPkgs = nixpkgs-darwin.legacyPackages.${darwinSystem};
      mkDevShell =
        p:
        p.mkShell {
          packages = [
            p.nixfmt-tree
            p.sops
            p.nh
          ];
        };
    in
    {
      overlays.default = import ./overlays;

      nixosModules = {
        core = ./modules/nixos/core;
        desktop = ./modules/nixos/desktop;
        users-jiarong = ./modules/nixos/users/jiarong.nix;
        lab-printer-proxy = ./modules/nixos/lab-printer-proxy.nix;
      };

      darwinModules = {
        core = ./modules/darwin/core;
      };

      homeModules = {
        core = ./modules/home/core;
        desktop = ./modules/home/desktop;
      };

      packages.${linuxSystem}.rime-frost = pkgs.callPackage ./pkgs/rime-frost.nix { };

      # Official Nix formatter. `nix fmt` reformats the tree; `nix fmt -- --ci` checks.
      formatter = {
        ${linuxSystem} = pkgs.nixfmt-tree;
        ${darwinSystem} = darwinPkgs.nixfmt-tree;
      };

      devShells = {
        ${linuxSystem}.default = mkDevShell pkgs;
        ${darwinSystem}.default = mkDevShell darwinPkgs;
      };

      nixosConfigurations."ics-host-529" = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/ics-host-529
          inputs.comin.nixosModules.comin
        ];
      };

      nixosConfigurations."desktop-host-wsl" = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/desktop-host-wsl
          inputs.nixos-wsl.nixosModules.default
        ];
      };

      darwinConfigurations.macbook-air = inputs.nix-darwin.lib.darwinSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/macbook-air ];
      };
    };
}
