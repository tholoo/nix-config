{ lib, ... }:
{
  plugins = {
    luasnip.enable = true;
    friendly-snippets.enable = true;
  };

  keymaps = lib.mkAfter [
    {
      key = "<tab>";
      action.__raw = # lua
        ''
          function()
            return require("luasnip").jumpable(1) and "<Plug>luasnip-jump-next" or "<tab>"
          end
        '';
      mode = "i";
      options = {
        expr = true;
        silent = true;
      };
    }
    {
      key = "<tab>";
      action.__raw = # lua
        "function() require('luasnip').jump(1) end";
      mode = [ "s" ];
      options = {
        silent = true;
        noremap = true;
      };
    }
    {
      key = "<s-tab>";
      action.__raw = # lua
        "function() require('luasnip').jump(-1) end";
      mode = [
        "i"
        "s"
      ];
      options = {
        silent = true;
        noremap = true;
      };
    }
    {
      key = "<C-E>";
      action.__raw = # lua
        ''
          function()
            if require('luasnip').choice_active() then
                require('luasnip').change_choice(1)
            end
          end
        '';
      mode = [
        "i"
        "s"
      ];
      options = {
        silent = true;
        noremap = true;
      };
    }
  ];
}
