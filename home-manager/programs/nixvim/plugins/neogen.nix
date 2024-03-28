{ lib, ... }: {
  plugins.neogen = {
    enable = true;
    snippetEngine = "luasnip";
  };

  keymaps = lib.mkAfter [{
    key = "<leader>cd";
    action = "function() require('neogen').generate() end";
    lua = true;
    mode = [ "n" ];
    options = {
      silent = true;
      noremap = true;
    };
  }
  #   {
  #     key = "<C-l>";
  #     action = "function() require('neogen').jump_next end";
  #     lua = true;
  #     mode = [ "i" "s" ];
  #     options = {
  #       silent = true;
  #       noremap = true;
  #     };
  #   }
  #   {
  #     key = "<C-h>";
  #     action = "function() require('neogen').jump_prev end";
  #     lua = true;
  #     mode = [ "i" "s" ];
  #     options = {
  #       silent = true;
  #       noremap = true;
  #     };
  #   }
    ];
}
