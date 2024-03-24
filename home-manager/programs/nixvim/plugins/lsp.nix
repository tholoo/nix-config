{
  lsp = {
    enable = true;
    keymaps = {
      silent = true;
      diagnostic = {
        # Navigate in diagnostics
        "[d" = "goto_prev";
        "]d" = "goto_next";
        "<leader>cd" = "open_float";
      };
      lspBuf = {
        gd = "definition";
        gD = "references";
        gt = "type_definition";
        gi = "implementation";
        K = "hover";
        "<leader>cr" = "rename";
        "<leader>fs" = "workspace_symbol";
        "<leader>ca" = "code_action";
        "<leader>ch" = "signature_help";
      };
    };
    servers = {
      tsserver.enable = true;

      lua-ls.enable = true;

      ruff-lsp.enable = true;
      pyright.enable = true;
      # NOTE: Broken because of rust version
      # pylyzer.enable = true;
      # pylsp.enable = true;

      nil_ls.enable = true;
      # nixd.enable = true;

      html.enable = true;
      htmx.enable = true;

      jsonls.enable = true;
      yamlls.enable = true;

      dockerls.enable = true;

      eslint.enable = true;

      gopls.enable = true;

      # NOTE: Broken
      # graphql.enable = true;

      typos-lsp.enable = true;

      typst-lsp.enable = true;
    };

    onAttach = ''
      if client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
          vim.lsp.inlay_hint.enable(bufnr, true)
      end
    '';
  };

  lsp-format = { enable = true; };
  lspkind.enable = true;
  # lsp-lines.enable = true;
}
