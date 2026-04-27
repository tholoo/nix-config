{
  inputs,
  config,
  lib,
  ...
}:
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
        experimental-features = [
          "nix-command"
          "flakes"
          "configurable-impure-env"
        ];
        # Pass proxy into fixed-output derivation builds (crate downloads, etc.)
        impure-env = [
          "http_proxy=socks5h://127.0.0.1:10808"
          "https_proxy=socks5h://127.0.0.1:10808"
          "HTTP_PROXY=socks5h://127.0.0.1:10808"
          "HTTPS_PROXY=socks5h://127.0.0.1:10808"
        ];
        # Deduplicate and optimize nix store
        auto-optimise-store = true;
        trusted-users = [
          "@wheel"
          "admin"
          "root"
        ];
        substituters = [
          "https://cache.nixos.org?priority=1"
          "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=2"
        ];
        extra-substituters = [
          "https://nix-community.cachix.org?priority=3"
          "https://anyrun.cachix.org?priority=4"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
        ];
        warn-dirty = false;
        connect-timeout = 5;
        download-attempts = 3;
        narinfo-cache-negative-ttl = 0;
      };

      # This will add each flake input as a registry
      # To make nix commands consistent with your flake
      # nix.registry = (lib.mapAttrs (_: flake: { inherit flake; })) (
      #   (lib.filterAttrs (_: lib.isType "flake")) inputs
      # );

      # This will additionally add your inputs to the system's legacy channels
      # Making legacy nix commands consistent as well, awesome!
      # nix.nixPath = [ "/etc/nix/path" ];
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
      # environment.etc = (
      #   lib.mapAttrs' (name: value: {
      #     name = "nix/path/${name}";
      #     value.source = value.flake;
      #   }) config.nix.registry
      # );
    };
  };
}
