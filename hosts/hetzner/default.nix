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
      # inputs.nixvim.nixosManagerModules.nixvim
      inputs.disko.nixosModules.disko
      inputs.home-manager.nixosModules.home-manager
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
}
