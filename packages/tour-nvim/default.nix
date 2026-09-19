{ inputs, pkgs, ... }:
(import (inputs.tour-nvim + "/nix/package.nix") {
  inherit pkgs;
  src = inputs.tour-nvim;
}).plugin
