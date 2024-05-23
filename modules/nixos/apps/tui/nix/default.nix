{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "nix";
in
{
  options.mine.${name} = mkEnable config { tags = [ "tui" ]; };

  config = mkIf cfg.enable {
    nix = {
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };

      settings = {
        experimental-features = "nix-command flakes";
        # Deduplicate and optimize nix store
        auto-optimise-store = true;
        trusted-users = [
          "@wheel"
          "admin"
          "root"
          "${config.mine.username}"
        ];
        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };

      # This will add each flake input as a registry
      # To make nix commands consistent with your flake
      # nix.registry = (lib.mapAttrs (_: flake: { inherit flake; })) (
      #   (lib.filterAttrs (_: lib.isType "flake")) inputs
      # );

      # This will additionally add your inputs to the system's legacy channels
      # Making legacy nix commands consistent as well, awesome!
      # nix.nixPath = [ "/etc/nix/path" ];
      # environment.etc = (
      #   lib.mapAttrs' (name: value: {
      #     name = "nix/path/${name}";
      #     value.source = value.flake;
      #   }) config.nix.registry
      # );
    };
  };
}
