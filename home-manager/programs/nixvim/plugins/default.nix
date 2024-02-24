{ config, pkgs, lib, ... }:
let
  plugins = [
    ./cmp.nix
    ./comment.nix
    ./conform.nix
    ./copilot.nix
    ./harpoon.nix
    ./lsp.nix
    ./neo-tree.nix
    ./nix.nix
    ./none-ls.nix
    ./oil.nix
    ./telescope.nix
    ./tmux-navigator.nix
    ./treesitter.nix
    ./trouble.nix
    ./ts.nix
  ];
  importedPlugins =
    lib.fold (elem: container: import elem // container) { } plugins;
in {
  # imports = [
  # ];

  programs.nixvim = {
    colorschemes.ayu.enable = true;

    plugins = importedPlugins // {

      gitsigns = {
        enable = true;
        signs = {
          add.text = "+";
          change.text = "~";
        };
      };

      surround.enable = true;

      nvim-autopairs.enable = true;

      nvim-colorizer = {
        enable = true;
        userDefaultOptions.names = false;
      };
    };
  };
}
