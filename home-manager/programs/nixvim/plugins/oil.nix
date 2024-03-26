{ lib, ... }: {
  plugins.oil = {
    enable = true;
    # keymaps = { "<leader>i" = "actions.open_cwd"; };
    # keymaps = { callback = "function() require('oil').open_cwd() end", desc = “”, nowait = true })
    settings = {
      delete_to_trash = true;
      skip_confirm_for_simple_edits = true;
    };
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
