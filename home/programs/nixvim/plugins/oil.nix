{
  programs.nixvim = {
    plugins.oil = {
      enable = true;
      deleteToTrash = true;
      keymaps = {
        "<leader>i" =  "open_cwd";
      };
      skipConfirmForSimpleEdits = true;
    };
  };
}
