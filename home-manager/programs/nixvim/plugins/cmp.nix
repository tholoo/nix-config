{ ... }:
{
  cmp = {
    enable = true;
    settings = {
      window = {
        completion = {
          __raw = ''require("cmp.config.window").bordered({ scrollbar = false, completeopt = 'menu,menuone,noinsert'})'';
          # border = "rounded";
          # scrollbar = false;
          # completeopt = "menu,menuone,noinsert";
        };
        documentation = {
          __raw = ''require("cmp.config.window").bordered()'';
          # border = "rounded";
        };
      };
      mapping = {
        "<C-Space>" = "cmp.mapping.confirm({ behavior = require('cmp').ConfirmBehavior.Insert, select = true })";
        "<C-p>" = "cmp.mapping.select_prev_item(cmp_select)";
        "<C-n>" = ''
          function(_)
                  if cmp.visible() then
                    cmp.select_next_item(cmp_select)
                  else
                    cmp.complete()
                  end
                end
        '';
        # "<C-b>" = "cmp.mapping.scroll_docs(-4)";
        # "<C-f>" = "cmp.mapping.scroll_docs(4)";
        # "<C-Space>" = "cmp.mapping.complete()";
        # "<C-e>" = "cmp.mapping.abort()";
        # "<CR>" = "cmp.mapping.confirm({ select = true })";
      };

      snippet.expand = ''
        function(args)
          require('luasnip').lsp_expand(args.body)
        end
      '';
      # sources = [{ name = "nvim-lsp"; }];
      sources = map (name: { inherit name; }) [
        "luasnip"
        "cmdline"
        "dap"
        "dictionary"
        "fish"
        "git"
        "nvim_lsp"
        "nvim_lsp_document_symbol"
        "nvim_lsp_signature_help"
        "nvim_lua"
        "path"
        # this needs to be at the bottom to avoid duped completions
        "buffer"
      ];
    };
  };
}
# } // lib.fold (src: c: c // { "cmp-${src}".enable = true; }) { } [
#   "buffer"
#   "cmdline"
#   "dap"
#   "dictionary"
#   "fish"
#   "git"
#   "nvim-lsp"
#   "nvim-lsp-document-symbol"
#   "nvim-lsp-signature-help"
#   "nvim-lua"
#   "path"
# ]
