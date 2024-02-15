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

    globals.mapleader = " ";

    options = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      clipboard = ["unnamedplus"];
      smartindent = true;
      expandtab = true;
      wrap = false;
      # swapfile = false; #Undotree
      # backup = false; #Undotree
      undofile = true;
      incsearch = true;
      termguicolors = true;
      scrolloff = 8;
      signcolumn = "yes";
      updatetime = 50;
      # foldlevelstart = 99;
    };

    plugins = {
      lualine.enable = true;
      luasnip.enable = true;
    };
  };
}
