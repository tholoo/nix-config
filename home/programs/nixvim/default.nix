{ pkgs, lib, ... }: {
  # imports = lib.concatMap import [
    # ./plugins
  # ];
  imports = [
    ./plugins
  ];
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    # extraPackages = with pkgs; [
    # ];

    luaLoader.enable = true;
    clipboard.providers = {
      xsel.enable = true;
    };

    # Highlight and remove extra white spaces
    highlight.ExtraWhitespace.bg = "red";
    match.ExtraWhitespace = "\\s\\+$";

    options = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      clipboard = ["unnamedplus"];
      smartindent = true;
      expandtab = true;
    };

    globals.mapleader = " ";

    plugins = {
      lualine.enable = true;
      telescope.enable = true;
      oil.enable = true;
      luasnip.enable = true;
    };
  };
}
