{ pkgs, ... }:
{
  extraPlugins = [ pkgs.vimPlugins.nvim-rip-substitute ];
  extraConfigLua = ''
    require("rip-substitute").setup({})
  '';
  keymaps = [
    {
      key = "<leader>rs";
      mode = [
        "n"
        "x"
      ];
      action.__raw = "function() require('rip-substitute').sub() end";
      options.desc = "Search and replace (rip-substitute)";
    }
  ];
}
