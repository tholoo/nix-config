{ pkgs, lib, ... }:
{
  rustaceanvim.enable = true;
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
        gr = "references";
        gt = "type_definition";
        gD = "implementation";
        K = "hover";
        "<leader>cr" = "rename";
        "<leader>fs" = "workspace_symbol";
        "<ctrl-s>" = "workspace_symbol";
        "<leader>ca" = "code_action";
        "<leader>ch" = "signature_help";
      };
      extra = [
        {
          key = "<leader>fs";
          action.__raw = # lua
            ''
              function()
                require("telescope.builtin").lsp_dynamic_workspace_symbols({})
              end
            '';
        }
      ];
    };
    postConfig = # lua
      ''
        vim.fn.sign_define('DiagnosticSignError', { text = '', texthl = 'DiagnosticSignError' })
        vim.fn.sign_define('DiagnosticSignWarn', { text = '', texthl = 'DiagnosticSignWarn' })
        vim.fn.sign_define('DiagnosticSignInfo', { text = '', texthl = 'DiagnosticSignInfo' })
        vim.fn.sign_define('DiagnosticSignHint', { text = '', texthl = 'DiagnosticSignHint' })

        vim.diagnostic.config({
          severity_sort = true
        })
      '';
    servers =
      lib.fold (name: c: { "${name}".enable = true; } // c)
        {
          nil-ls = {
            enable = true;
            settings = {
              formatting.command = [ "${lib.getExe pkgs.nixfmt-rfc-style}" ];
              nix.flake = {
                autoArchive = true;
                autoEvalInputs = true;
              };
            };
          };
        }
        [
          "tsserver"
          "volar"

          "lua-ls"

          "ruff-lsp"
          "pyright"
          # NOTE: Broken because of rust version
          # "pylyzer"
          # "pylsp"

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

    onAttach = # lua
      ''
        if client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
            vim.lsp.inlay_hint.enable(true, {bufnr})
        end
      '';
  };

  lsp-format.enable = true;

  lspkind.enable = true;
  # lspsaga.enable = true;
  navic = {
    enable = true;
    lsp.autoAttach = true;
  };
  # lsp-lines.enable = true;
}
