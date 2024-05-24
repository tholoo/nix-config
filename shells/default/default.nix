{ pkgs, mkShell, ... }:

mkShell { packages = with pkgs; [ deploy-rs ]; }
