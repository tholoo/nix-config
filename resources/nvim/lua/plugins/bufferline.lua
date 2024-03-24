return {
  "akinsho/bufferline.nvim",
  enabled = false,
  opts = {
    options = {
      buffer_close_icon = "",
      close_icon = "",
      style_preset = require("bufferline").style_preset.minimal,
      show_buffer_close_icons = false,
    },
  },
  -- Disable tab line
  -- vim.g.bufferline = false
  -- vim.opt.showtabline = 0

  keys = {
    {
      "<leader>bf", -- pick a buffer
      function()
        require("bufferline").pick()
      end,
      "Choose Buffer",
    },
    {
      "<leader>bb", -- toggle bufferline
      function()
        -- find the current status
        local sbl = vim.g.bufferline
        -- -- toggle the status
        vim.g.bufferline = not sbl
        -- toggle the tabline
        vim.opt.showtabline = sbl and 2 or 0
        -- nnoremap <expr><silent> <leader>, &showtabline ? ":set showtabline=0\<cr>" : ":set showtabline=2\<cr>"
      end,
      "Close/Show Bufferline",
    },
  },
}
