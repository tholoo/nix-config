{
  description = "Tholo's Nix Config";
  nixConfig = {
    substituters = [
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=1"
      "https://cache.nixos.org?priority=2"
    ];
    extra-substituters = [
      # "https://aseipp-nix-cache.global.ssl.fastly.net"
      "https://nix-community.cachix.org?priority=3"
      "https://anyrun.cachix.org?priority=4"
    ];
    extra-trusted-public-keys = [
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
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

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

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

    nix-alien.url = "github:thiagokokada/nix-alien";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # dedsec-grub-theme = {
    #   url = "gitlab:VandalByte/dedsec-grub-theme";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    nur.url = "github:nix-community/NUR";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    NixVirt = {
      url = "github:AshleyYakeley/NixVirt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    srvos = {
      url = "github:nix-community/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zellij-switch.url = "github:mostafaqanbaryan/zellij-switch";

    nixflix = {
      url = "github:kiriwalawren/nixflix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      lib = inputs.snowfall-lib.mkLib {
        inherit inputs;
        src = ./.;

        snowfall = {
          namespace = "mine";
          meta = {
            name = "tholo-config";
            title = "tholo's config";
          };
        };
      };
    in
    lib.mkFlake {
      channels-config = {
        allowUnfree = true;
        allowUnfreePredicate = _: true;
        permittedInsecurePackages = [
          "dotnet-sdk-6.0.428" # godot
        ];
      };

      overlays = with inputs; [
        # neovim-nightly-overlay.overlays.default
        nur.overlays.default
        fenix.overlays.default
        zellij-switch.overlays.default
      ];

      systems.modules.nixos = with inputs; [
        agenix.nixosModules.default
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        nixos-generators.nixosModules.all-formats
        nur.modules.nixos.default
        # dedsec-grub-theme.nixosModule
        NixVirt.nixosModules.default
        nixflix.nixosModules.default
      ];

      systems.hosts.glacier.modules = with inputs.nixos-hardware.nixosModules; [
        inputs.srvos.nixosModules.desktop

        # ideapad-ideapad-slim-5
        common-gpu-amd
        common-cpu-amd
        common-pc-laptop
        common-pc-laptop-ssd
      ];

      systems.hosts.granite.modules = with inputs.srvos; [
        nixosModules.server
        nixosModules.hardware-hetzner-cloud
        nixosModules.mixins-terminfo
        nixosModules.mixins-trusted-nix-caches
      ];

      # systems.hosts.my-host.specialArgs = {
      #   my-custom-value = "my-value";
      # };

      homes.modules = with inputs; [
        nixvim.homeModules.nixvim
        agenix.homeManagerModules.default
        nix-index-database.homeModules.nix-index
        zen-browser.homeModules.beta
        # stylix.homeModules.stylix
      ];

      # homes.users."my-user@my-host".specialArgs = {
      #   my-custom-value = "my-value";
      # };

      outputs-builder = channels: { formatter = channels.nixpkgs.nixfmt-rfc-style; };

      deploy.nodes = {
        "granite" = {
          hostname = "granite";
          sshUser = "root";
          remoteBuild = true;
          profiles.system = {
            user = "root";
            path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations.granite;
          };
        };
      };

      checks = builtins.mapAttrs (
        system: deploy-lib: deploy-lib.deployChecks inputs.self.deploy
      ) inputs.deploy-rs.lib;

      alias = {
        shells.default = "default";
      };
    };
}
