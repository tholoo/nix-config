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

    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.snowfall-lib.mkFlake {
      inherit inputs;
      src = ./.;
      snowfall = {
        # Choose a namespace to use for your flake's packages, library,
        # and overlays.
        namespace = "mine";
        meta = {
          name = "tholo-config";
          title = "tholo's config";
        };
      };

      channels-config = {
        allowUnfree = true;
        allowUnfreePredicate = _: true;
      };

      systems.modules.nixos = with inputs; [ agenix.nixosModules.default ];

      # Add a module to a specific host.
      # systems.hosts.my-host.modules = with inputs; [
      # my-input.nixosModules.my-module
      # ];

      # systems.hosts.my-host.specialArgs = {
      #   my-custom-value = "my-value";
      # };

      homes.modules = with inputs; [
        nixvim.homeManagerModules.nixvim
        agenix.homeManagerModules.default
      ];

      # homes.users."my-user@my-host".specialArgs = {
      #   my-custom-value = "my-value";
      # };

      outputs-builder = channels: { formatter = channels.nixpkgs.nixfmt-rfc-style; };
    };
  # callPackage = lib.callPackageWith {
  #   inherit
  #     flakeSelf
  #     nixpkgs
  #     home-manager
  #     inputs
  #     outputs
  #     getNixFiles
  #     ;
  # };
  #   # inputs.stylix = {
  #   #   image = ./resources/wallpapers/wallhaven-8586my_1920x1080.png;
  #   #   polarity = "dark";
  #   # };
  #
  #   checks = builtins.mapAttrs (
  #     system: deployLib: deployLib.deployChecks self.deploy
  #   ) inputs.deploy-rs.lib;
  # };
}
