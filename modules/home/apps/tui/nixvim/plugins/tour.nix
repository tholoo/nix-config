{ tourPlugin }:
{
  extraPlugins = [ tourPlugin ];
  extraConfigLua = ''
    require("tour").setup({})
    vim.keymap.set("n", "]t", "<Plug>(tour-next)", { desc = "Next tour step" })
    vim.keymap.set("n", "[t", "<Plug>(tour-prev)", { desc = "Previous tour step" })
    vim.keymap.set("n", "<leader>to", "<Plug>(tour-overview)", { desc = "Tour overview" })
    vim.keymap.set("n", "<leader>tr", "<Plug>(tour-resume)", { desc = "Resume tour" })
    vim.keymap.set("n", "<leader>tc", "<Plug>(tour-close)", { desc = "Close tour" })
    vim.keymap.set("n", "<leader>tl", "<cmd>TourList<cr>", { desc = "Saved tours" })
  '';
}
