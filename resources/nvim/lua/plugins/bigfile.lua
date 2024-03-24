return {
  "LunarVim/bigfile.nvim",
  event = "BufReadPre",
  opts = {
    filesize = 10,
  },
  config = function(_, opts)
    require("bigfile").setup(opts)
  end,
}
