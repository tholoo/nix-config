{ lib, ... }:
{
  plugins.oil = {
    enable = true;
    # keymaps = { "<leader>i" = "actions.open_cwd"; };
    # keymaps = { callback = "function() require('oil').open_cwd() end", desc = “”, nowait = true })
    settings = {
      default_file_explorer = true;
      delete_to_trash = true;
      skip_confirm_for_simple_edits = true;
      view_options = {
        show_hidden = true;
        natural_order = true;
        is_always_hidden = # lua
          ''
            function (name, _)
              return name == ".." or name == ".git" or name == ".direnv"
            end
          '';
      };
    };
  };
  keymaps = lib.mkAfter [
    {
      key = "<leader>i";
      action = "<CMD>Oil<CR>";
      options = {
        silent = true;
        noremap = true;
      };
    }
    {
      key = "-";
      action = "<CMD>Oil<CR>";
      options = {
        silent = true;
        noremap = true;
      };
    }
  ];
}
