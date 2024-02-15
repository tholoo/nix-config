{
  description = "Tholo's NixOS Config";

  inputs = {
    # stable
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    # unstable
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # home-manager, used for managing user configuration
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

    # for storing secrets
    # agenix = {
    # url = "github:ryantm/agenix";
    # inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = { self, nixpkgs, home-manager, nixvim, ... }@inputs:
    let
      system = "x86_64-linux";
      username = "tholo";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
      homeConfigurations."${username}" =
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ nixvim.homeManagerModules.nixvim ./home/home.nix ];

          # Optionally use extraSpecialArgs
          # to pass through arguments to home.nix
          extraSpecialArgs = { inherit username; };
        };
    };

  # nixosConfigurations = {
  # "nixos" = nixpkgs.lib.nixosSystem rec {
  # system = "x86_64-linux";
  # # specialArgs = inputs;
  # specialArgs = { inherit inputs; };
  # modules = /[
  # ./configuration.nix
  # # make home-manager as a module of nixos
  # # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
  # inputs.agenix.nixosModules.default
  # 
  # {
  # environment.systemPackages = [ inputs.agenix.packages.${system}.default ];
  # }
  # 
  # home-manager.nixosModules.home-manager
  # 
  # {
  # home-manager.useGlobalPkgs = true;
  # home-manager.useUserPackages = true;
  # 
  # home-manager.users.tholo = import ./home.nix;
  # 
  # # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
  # }
  # ];
  # };
  # };
  # };
  # };
}
