{ inputs, pkgs, ... }:
inputs.tholo-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
