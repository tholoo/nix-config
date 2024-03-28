{ lib, ... }: {
  plugins = {
    luasnip.enable = true;
    friendly-snippets.enable = true;
  };

  keymaps = lib.mkAfter [
    {
      key = "<tab>";
      action = ''
        function()
          return require("luasnip").jumpable(1) and "<Plug>luasnip-jump-next" or "<tab>"
        end
      '';
      lua = true;
      mode = "i";
      options = {
        expr = true;
        silent = true;
      };
    }
    {
      key = "<tab>";
      action = "function() require('luasnip').jump(1) end";
      lua = true;
      mode = [ "s" ];
      options = {
        silent = true;
        noremap = true;
      };
    }
    {
      key = "<s-tab>";
      action = "function() require('luasnip').jump(-1) end";
      lua = true;
      mode = [ "i" "s" ];
      options = {
        silent = true;
        noremap = true;
      };
    }
    {
      key = "<C-E>";
      action = ''
        function()
          if require('luasnip').choice_active() then
              require('luasnip').change_choice(1)
          end
        end
      '';
      lua = true;
      mode = [ "i" "s" ];
      options = {
        silent = true;
        noremap = true;
      };
    }
  ];
}
