{ lib, ... }: {
  plugins = {
    luasnip.enable = true;
    friendly-snippets.enable = true;
  };

  keymaps = lib.mkAfter [
    {
      key = "<C-l>";
      action = "function() require('luasnip').jump(1) end";
      lua = true;
      mode = [ "i" "s" ];
      options = {
        silent = true;
        noremap = true;
      };
    }
    {
      key = "<C-h>";
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
