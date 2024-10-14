{ pkgs, lib, ... }:
{
  conform-nvim = {
    enable = true;
    # formatters = {inherit }
    settings = {
      formatters = {
        prettierd = {
          command = lib.getExe pkgs.prettierd;
        };
        codespell = {
          command = lib.getExe pkgs.codespell;
        };
        ruff_format = {
          command = lib.getExe pkgs.ruff;
        };
      };

      format_on_save = {
        lspFallback = true;
      };

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
        # sh = ["shfmt"];
        # yaml = ["prettierd" "prettier"];
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
