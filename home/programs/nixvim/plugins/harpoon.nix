{ config, pkgs, ... }:
{
  programs.nixvim = {
    plugins.harpoon = {
      enable = false;

      keymapsSilent = true;

      keymaps = {
        addFile = "<leader>a";
        toggleQuickMenu = "<C-e>";
        navFile = {
          "1" = "<leader>j";
          "2" = "<leader>k";
          "3" = "<leader>l";
          "4" = "<leader>m";
        };
      };
    };
  };
}
