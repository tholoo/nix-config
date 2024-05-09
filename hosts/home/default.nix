{
  flakeSelf,
  nixpkgs,
  home-manager,
  outputs,
  inputs,
  getNixFiles,
  ...
}:
let
  username = "tholo";
  hostname = "homepc";
in
{
  nixosConfigurations = {
    "${hostname}" = nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit
          inputs
          outputs
          getNixFiles
          flakeSelf
          username
          hostname
          ;
      };
      modules = [
        # inputs.stylix.nixosModules.stylix
        inputs.agenix.nixosModules.default
        ./configuration.nix
      ];
    };
  };

  homeConfigurations = {
    "${username}" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = {
        inherit
          inputs
          outputs
          getNixFiles
          flakeSelf
          username
          hostname
          ;
      };
      modules = [
        # inputs.stylix.homeManagerModules.stylix
        inputs.nixvim.homeManagerModules.nixvim
        inputs.agenix.homeManagerModules.default
        ./home.nix
      ];
    };
  };
}
