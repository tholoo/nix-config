return {
  "andythigpen/nvim-coverage",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  keys = {
    {
      "<leader>Cl",
      function()
        require("coverage").load({ true })
      end,
      desc = "Code Coverage Load",
    },
    {
      "<leader>Cc",
      function()
        require("coverage").toggle()
      end,
      desc = "Code Coverage Toggle",
    },
    {
      "<leader>Cs",
      function()
        require("coverage").summary()
      end,
      desc = "Code Coverage Summary",
    },
  },
  config = function()
    require("coverage").setup({
      auto_reload = true,
      highlights = {
        uncovered = { fg = "#d62929" },
      },
    })
  end,
}
