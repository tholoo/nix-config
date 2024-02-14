{ config, pkgs, ... }:
{
  imports = [
    ./cmp.nix
    ./comment.nix
    ./harpoon.nix
    ./lsp.nix
    ./neo-tree.nix
    ./nix.nix
    ./none-ls.nix
    ./telescope.nix
    ./treesitter.nix
  ];

  programs.nixvim = {
    colorschemes.ayu.enable = true;

    plugins = {
      gitsigns = {
        enable = true;
        signs = {
          add.text = "+";
          change.text = "~";
        };
      };

      nvim-autopairs.enable = true;

      nvim-colorizer = {
        enable = true;
        userDefaultOptions.names = false;
      };

      oil.enable = true;
    };
  };
}
