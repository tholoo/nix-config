{ pkgs, ... }:
{
  pkg = pkgs.vimPlugins.nvim-surround;
  enabled = true;
  event = "VeryLazy";
  main = "nvim-surround";
  opts = {
    keymaps = {
      normal = "s";
      normal_cur = "ss";
      visual = "s";
      visual_line = "gs";
    };
  };
}
