{
  conform = {
    enable = true;
    formattersByFt = {
      lua = [ "stylua" ];
      nix = [ "nix" ];
      python = [ "ruff_format" ];
      # Use a sub-list to run only the first available formatter
      javascript = [ [ "prettierd" "prettier" ] ];
      # Use the "*" filetype to run formatters on all filetypes.
      "*" = [ "codespell" ];
      # Use the "_" filetype to run formatters on filetypes that don't
      # have other formatters configured.
      "_" = [ "trim_whitespace" ];
    };
  };
}
