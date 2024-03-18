{ ... }: {
  nvim-cmp = {
    enable = true;
    autoEnableSources = true;
    sources =
      [ { name = "nvim_lsp"; } { name = "path"; } { name = "buffer"; } ];
    mapping = { "<C-Space>" = "cmp.mapping.confirm({ select = true })"; };
  };
}
