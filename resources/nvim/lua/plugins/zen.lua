return {
  {
    {
      "folke/twilight.nvim",
      opts = {
        context = 10, -- amount of lines that will try to be show around the current line
        treesiter = true,
        expand = { -- for treesitter, we we always try to expand to the top-most ancestor with these types
          "method",
          "function",
          "table",
          "if_statement",
        },
        exclude = {}, -- exclude these filetypes
      },
    },
  },
  {
    "folke/zen-mode.nvim",
    opts = {
      plugins = {
        options = {
          enabled = true,
          ruler = false,
          showcmd = false,
          laststatus = 0,
        },
        twilight = { enabled = false },
        tmux = { enabled = true },
        wezterm = {
          enabled = false,
          -- can be either an absolute font size or the number of incremental steps
          font = "+1", -- (10% increase per step)
        },
      },
      -- callback where you can add custom code when the Zen window opens
      on_open = function(win) end,
      -- callback where you can add custom code when the Zen window closes
      on_close = function() end,
    },
    keys = {
      {
        "<leader>zz",
        "<CMD>ZenMode<CR>",
        "Zen",
      },
    },
  },
}
