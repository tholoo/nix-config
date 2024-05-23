{
  none-ls = {
    enable = true;
    enableLspFormat = true;
    sources = {
      formatting = {
        # nixfmt.enable = true;
        # nixpkgs_fmt.enable = true;
      };
    };
    # extraOptions = {
    #   sources = helpers.mkRaw ''
    #     { require("null-ls").builtins.formatting.eslint_d,
    #       require("null-ls").builtins.formatting.prettier_d_slim,
    #       require("null-ls").builtins.code_actions.eslint_d,
    #       require("null-ls").builtins.diagnostics.eslint_d
    #     }
    #   '';
    # };
  };
}
