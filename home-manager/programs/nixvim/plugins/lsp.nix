{
  lsp = {
    enable = true;
    keymaps = {
      silent = true;
      diagnostic = {
        # Navigate in diagnostics
        "[d" = "goto_prev";
        "]d" = "goto_next";
      };
      lspBuf = {
        gd = "definition";
        gD = "references";
        gt = "type_definition";
        gi = "implementation";
        K = "hover";
        "<leader>cr" = "rename";
      };
    };
    servers = {
      tsserver.enable = true;

      lua-ls.enable = true;

      ruff-lsp.enable = true;
      pyright.enable = true;
      pylyzer.enable = true;
      # pylsp.enable = true;

      nil_ls.enable = true;
      nixd.enable = true;

      html.enable = true;

      jsonls.enable = true;
    };
  };

  lsp-format = { enable = true; };
  lspkind.enable = true;
  lsp-lines.enable = true;
}
