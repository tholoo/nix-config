{ pkgs, lib, ... }:
{
  conform-nvim = {
    enable = true;
    luaConfig = {
      pre = # lua
        ''
          vim.api.nvim_create_user_command("ConformDisable", function(args)
            if args.bang then
              -- ConformDisable! will disable formatting just for this buffer
              vim.b.disable_autoformat = true
            else
              vim.g.disable_autoformat = true
            end
          end, {
            desc = "Disable autoformat-on-save",
            bang = true,
          })
          vim.api.nvim_create_user_command("ConformEnable", function()
            vim.b.disable_autoformat = false
            vim.g.disable_autoformat = false
          end, {
            desc = "Re-enable autoformat-on-save",
          })
        '';
    };
    # formatters = {inherit }
    settings = {
      formatters =
        lib.fold
          (
            pkg_name: c:
            {
              ${pkg_name} = {
                command = lib.getExe pkgs.${pkg_name};
              };
            }
            // c
          )
          {
            ruff_format = {
              command = lib.getExe pkgs.ruff;
            };
          }
          [
            "prettierd"
            "codespell"
            "ruff_format"
            "sqlfluff"
            "stylua"
            "shfmt"
          ];

      format_on_save = # lua
        ''
          function (bufnr)
               -- Disable with a global or buffer-local variable
               if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                 return
               end
               return { lsp_format = "fallback", quiet = true }
           end
        '';

      formatters_by_ft = {
        lua = [ "stylua" ];
        python = [ "ruff_format" ];
        # Use a sub-list to run only the first available formatter
        javascript = [
          [
            "prettierd"
            "prettier"
          ]
        ];
        typescript = [
          "prettierd"
          "prettier"
        ];
        typescriptreact = [ "prettier" ];
        sql = [ "sqlfluff" ];

        # asm = ["asmfmt"];
        # c = ["astyle"];
        # cpp = ["astyle"];
        # css = ["prettierd" "prettier"];
        # cmake = ["cmake_format"];
        # go = ["goimports" "gofumpt" "golines"];
        # html = ["prettierd" "prettier"];
        # javascript = ["prettierd" "prettier"];
        # javascriptreact = ["prettier"];
        # json = ["prettier"];
        # markdown = ["prettier"];
        # rust = ["rustfmt"];
        sh = [ "shfmt" ];
        yaml = [
          "prettierd"
          "prettier"
        ];
        # Use the "*" filetype to run formatters on all filetypes.
        "*" = [
          "injected" # injected languages
          # "codespell"
        ];
        # Use the "_" filetype to run formatters on filetypes that don't
        # have other formatters configured.
        "_" = [ "trim_whitespace" ];
      };
    };
  };
}
