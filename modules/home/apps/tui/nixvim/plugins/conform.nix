{
  conform-nvim = {
    enable = false;
    # formatters = {inherit }
    settings = {
      format_on_save = {
        lspFallback = true;
      };

      formatters_by_ft = {
        lua = [ "stylua" ];
        nix = [ ];
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
        "*" = [ "codespell" ];
        # Use the "_" filetype to run formatters on filetypes that don't
        # have other formatters configured.
        "_" = [ "trim_whitespace" ];
      };
    };
  };
}
