{ tourPlugin }:
{
  extraPlugins = [ tourPlugin ];
  plugins.which-key.settings.spec = [
    {
      __unkeyed-1 = "<leader>T";
      group = "tours";
    }
  ];
  extraConfigLua = ''
    require("tour").setup({})
    vim.keymap.set("n", "]t", "<Plug>(tour-next)", { desc = "Next tour step" })
    vim.keymap.set("n", "[t", "<Plug>(tour-prev)", { desc = "Previous tour step" })
    vim.keymap.set("n", "<leader>To", "<Plug>(tour-overview)", { desc = "Tour overview" })
    vim.keymap.set("n", "<leader>Tr", "<Plug>(tour-resume)", { desc = "Resume tour" })
    vim.keymap.set("n", "<leader>Tc", "<Plug>(tour-close)", { desc = "Close tour" })
    vim.keymap.set("n", "<leader>Tl", "<cmd>TourList<cr>", { desc = "Saved tours" })
  '';
}
