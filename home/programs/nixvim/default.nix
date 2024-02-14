{ pkgs, ... }: {
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    luaLoader.enable = true;

    # Highlight and remove extra white spaces
    highlight.ExtraWhitespace.bg = "red";
    match.ExtraWhitespace = "\\s\\+$";

    options = {
      number = true;
      relativenumber = true;
      shiftwidth = 4;
    };

    globals.mapleader = " ";

    plugins = {
      lualine.enable = true;

      lsp = {
        enable = true;
	keymaps = {
          silent = true;
          diagnostic = {
            # Navigate in diagnostics
            "[d" = "goto_prev";
            "]d" = "goto_next";
          };
        };
	lspBuf = {
          gd = "definition";
          gD = "references";
          gt = "type_definition";
          gi = "implementation";
          K = "hover";
            "<leader>cr" = "rename";
        };
	servers = {
	  tsserver.enable = true;
	  lua-ls.enable = true;
        };
      };

      nvim-cmp = {
        enable = true;
        autoEnableSources = true;
        sources = [
          {name = "nvim_lsp";}
          {name = "path";}
          {name = "buffer";}
        ];
        mapping = {
          "<C-Space>" = "cmp.mapping.confirm({ select = true })";
        };
      };

      telescope.enable = true;
      oil.enable = true;
      treesitter.enable = true;
      luasnip.enable = true;
    };
  };
}
