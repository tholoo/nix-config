return {
  "kylechui/nvim-surround",
  version = "*", -- Use for stability; omit to use `main` branch for the latest features
  event = "VeryLazy",
  config = function()
    require("nvim-surround").setup({
      keymaps = {
        normal = "s",
        normal_cur = "ss",
        visual = "s",
        visual_line = "gs",
      },
    })
  end,
}
