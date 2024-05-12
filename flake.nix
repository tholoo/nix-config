{
  description = "Tholo's Nix Config";
  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # Home manager
    home-manager = {
      # stable
      # url = "github:nix-community/home-manager/release-23.11";
      # unstable
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      # If you are not running an unstable channel of nixpkgs, select the corresponding branch of nixvim.
      # url = "github:nix-community/nixvim/nixos-23.05";

      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
    # hardware.url = "github:nixos/nixos-hardware";

    nix-colors.url = "github:misterio77/nix-colors";

    # nur.url = "github:nix-community/NUR";
    stylix.url = "github:danth/stylix";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs.url = "github:serokell/deploy-rs";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      # optionally choose not to download darwin deps (saves some resources on Linux)
      inputs.darwin.follows = "";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      systems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      # This is a function that generates an attribute by calling a function you
      # pass to it, with each system as an argument
      forAllSystems = nixpkgs.lib.genAttrs systems;
      lib = nixpkgs.lib;
      getNixFiles =
        dir:
        with lib;
        map (file: dir + "/${file}") (
          attrNames (
            filterAttrs (
              file: type: (type == "directory") || ((hasSuffix ".nix" file) && !(hasInfix "default" file))
            ) (builtins.readDir dir)
          )
        );
      flakeSelf = self;
      callPackage = lib.callPackageWith {
        inherit
          flakeSelf
          nixpkgs
          home-manager
          inputs
          outputs
          getNixFiles
          ;
      };
      hosts = getNixFiles ./hosts;
      # get all the hosts and merge them
      hostsAttrs = lib.fold (el: c: lib.recursiveUpdate c (callPackage el { })) { } hosts;
    in
    lib.recursiveUpdate hostsAttrs {
      # inputs.stylix = {
      #   image = ./resources/wallpapers/wallhaven-8586my_1920x1080.png;
      #   polarity = "dark";
      # };

      # Your custom packages
      # Accessible through 'nix build', 'nix shell', etc
      packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
      # Formatter for your nix files, available through 'nix fmt'
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      # Your custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };
      # Reusable nixos modules you might want to export
      # These are usually stuff you would upstream into nixpkgs
      nixosModules = import ./modules/nixos;
      # Reusable home-manager modules you might want to export
      # These are usually stuff you would upstream into home-manager
      homeManagerModules = import ./modules/home-manager;

      checks = builtins.mapAttrs (
        system: deployLib: deployLib.deployChecks self.deploy
      ) inputs.deploy-rs.lib;
    };
}
