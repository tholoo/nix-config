{ lib, ... }:
{
  plugins.gitsigns = {
    enable = true;
    settings.signs = {
      add.text = "▎";
      change.text = "▎";
      delete.text = "";
      topdelete.text = "";
      changedelete.text = "▎";
      untracked.text = "▎";
    };
  };
  keymaps = lib.mkAfter [
    {
      key = "<leader>cd";
      action.__raw = # lua
        "function() require('neogen').generate() end";
      mode = [ "n" ];
      options = {
        silent = true;
        noremap = true;
      };
    }
    {
      key = "]h";
      action = "<CMD>Gitsigns next_hunk<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "[h";
      action = "<CMD>Gitsigns prev_hunk<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<leader>ghs";
      action = "<CMD>Gitsigns stage_hunk<CR>";
      mode = [
        "n"
        "v"
      ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<leader>ghr ";
      action = "<CMD>Gitsigns reset_hunk<CR>";
      mode = [
        "n"
        "v"
      ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<leader>ghS";
      action = "<CMD>Gitsigns stage_buffer<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<leader>ghu";
      action = "<CMD>Gitsigns undo_stage_hunk<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<leader>ghR";
      action = "<CMD>Gitsigns reset_buffer<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<leader>ghp";
      action = "<CMD>Gitsigns preview_hunk_inline<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<leader>ghb";
      action = "<CMD>Gitsigns blame_line<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
    {
      key = "<leader>ghd";
      action = "<CMD>Gitsigns diffthis<CR>";
      mode = [ "n" ];
      options = {
        noremap = true;
      };
    }
  ];
}
