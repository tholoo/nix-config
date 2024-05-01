{
  flakeSelf,
  nixpkgs,
  home-manager,
  outputs,
  inputs,
  getNixFiles,
  ...
}:
{
  nixosConfigurations = {
    "homepc" = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs outputs;
      };
      modules = [
        # inputs.stylix.nixosModules.stylix
        ./configuration.nix
      ];
    };
  };

  homeConfigurations = {
    "tholo" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = {
          inherit
            inputs
            outputs
            getNixFiles
            flakeSelf
            ;
        };
      modules = [
        # inputs.stylix.homeManagerModules.stylix
        inputs.nixvim.homeManagerModules.nixvim
        ./home.nix
      ];
    };
  };
}
