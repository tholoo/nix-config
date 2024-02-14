{ pkgs, ... }: {
  programs.nixvim = {
    enable = true;

    # options = {
      # number = true;
      # relativenumber = true;
      # shiftwidth = 4;
    # };
# 
    # globals.mapleader = " ";
# 
    # plugins = {
      # lualine.enable = true;
# 
      # lsp = {
        # enable = true;
        # servers = { 
          # tsserver.enable = true;
          # lua-ls.enable = true;
        # };
      # };
# 
      # nvim-cmp = {
        # enable = true;
        # autoEnableSources = true;
        # sources = [
          # {name = "nvim_lsp";}
          # {name = "path";}
          # {name = "buffer";}
        # ];
        # mapping = {
          # "<C-Space>" = "cmp.mapping.confirm({ select = true })";
        # };
      # };
# 
      # telescope.enable = true;
      # oil.enable = true;
      # treesitter.enable = true;
      # luasnip.enable = true;
    # };
  };
}
