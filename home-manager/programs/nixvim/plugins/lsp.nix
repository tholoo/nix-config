{ lib, ... }: {
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
    servers = lib.fold (name: c: { "${name}".enable = true; } // c) { } [
      "tsserver"

      "lua-ls"

      "ruff-lsp"
      "pyright"
      # NOTE: Broken because of rust version
      # "pylyzer"
      # "pylsp"

      "nil_ls"
      # "nixd"

      "html"
      "htmx"

      "jsonls"
      "yamlls"

      "dockerls"

      "eslint"

      "gopls"

      # NOTE: Broken
      # "graphql"

      "typos-lsp"

      "typst-lsp"
    ];

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
