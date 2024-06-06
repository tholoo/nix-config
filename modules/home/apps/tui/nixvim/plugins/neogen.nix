{ lib, ... }:
{
  plugins.neogen = {
    enable = true;
    snippetEngine = "luasnip";
  };

  keymaps = lib.mkAfter [
    {
      key = "<leader>cs";
      action.__raw = # lua
        "function() require('neogen').generate() end";
      mode = [ "n" ];
      options = {
        silent = true;
        noremap = true;
      };
    }
    #   {
    #     key = "<C-l>";
    #     action.__raw = "function() require('neogen').jump_next end";
    #     mode = [ "i" "s" ];
    #     options = {
    #       silent = true;
    #       noremap = true;
    #     };
    #   }
    #   {
    #     key = "<C-h>";
    #     action.__raw = "function() require('neogen').jump_prev end";
    #     mode = [ "i" "s" ];
    #     options = {
    #       silent = true;
    #       noremap = true;
    #     };
    #   }
  ];
}
