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
  hostname = "hetzner";
  system = "x86_64-linux";
  pkgs = import nixpkgs { inherit system; };
  deployPkgs = import nixpkgs {
    inherit system;
    overlays = [
      inputs.deploy-rs.overlay
      (self: super: {
        deploy-rs = {
          inherit (pkgs) deploy-rs;
          lib = super.deploy-rs.lib;
        };
      })
    ];
  };
in
{
  nixosConfigurations."${hostname}" = nixpkgs.lib.nixosSystem {
    inherit system;
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
      inputs.disko.nixosModules.disko
      # inputs.nixvim.nixosManagerModules.nixvim
      inputs.home-manager.nixosModules.home-manager
      ./configuration.nix
    ];
  };

  deploy.nodes."${hostname}" = {
    hostname = "tholo.tech";
    sshUser = "root";
    remoteBuild = true;
    profiles.system = {
      user = "root";
      path = deployPkgs.deploy-rs.lib.activate.nixos flakeSelf.nixosConfigurations."${hostname}";
    };
  };

  # homeConfigurations."${username}" = home-manager.lib.homeManagerConfiguration {
  #   pkgs = nixpkgs.legacyPackages.x86_64-linux;
  #   extraSpecialArgs = {
  #     inherit
  #       inputs
  #       outputs
  #       getNixFiles
  #       flakeSelf
  #       username
  #       hostname
  #       ;
  #   };
  #   modules = [
  #     inputs.nixvim.homeManagerModules.nixvim
  #     ./home.nix
  #   ];
  # };
}
