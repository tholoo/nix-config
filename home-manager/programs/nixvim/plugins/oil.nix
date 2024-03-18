{ lib, ... }: {
  plugins.oil = {
    enable = true;
    deleteToTrash = true;
    # keymaps = { "<leader>i" = "actions.open_cwd"; };
    # keymaps = { callback = "function() require('oil').open_cwd() end", desc = “”, nowait = true })
    skipConfirmForSimpleEdits = true;
  };
  keymaps = lib.mkAfter [{
    key = "<leader>i";
    action = "<CMD>Oil<CR>";
    options = {
      silent = true;
      noremap = true;
    };
  }];
}
