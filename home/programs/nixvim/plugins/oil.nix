{
  programs.nixvim = {
    plugins.oil = {
      enable = true;
      deleteToTrash = true;
      keymaps = {
        open_cwd = "<leader>i";
      };
    };
  };
}
