return {
  "monaqa/dial.nvim",
  config = function()
    local augend = require("dial.augend")
    require("dial.config").augends:register_group({
      -- default augends used when no group name is specified
      default = {
        augend.integer.alias.decimal, -- nonnegative decimal number (0, 1, 2, 3, ...)
        augend.integer.alias.hex, -- nonnegative hex number  (0x01, 0x1a1f, etc.)
        augend.date.alias["%Y/%m/%d"], -- date (2022/02/19, etc.)
        augend.constant.alias.bool, -- boolean value (true <-> false)
        augend.date.alias["%Y-%m-%d"],
        augend.date.alias["%m/%d"],
        augend.date.alias["%H:%M"],
        augend.constant.alias.ja_weekday_full,
      },
    })
  end,
  keys = {
    {
      "<C-a>", -- Increment number under cursor
      function()
        return require("dial.map").manipulate("increment", "normal")
      end,
      "n",
    },
    {
      "<C-x>", -- Decrement number under cursor
      function()
        return require("dial.map").manipulate("decrement", "normal")
      end,
      "n",
    },
    --   {
    --     "g<C-a>", -- Increment in gnormal mode
    --     function()
    --       return require("dial.map").manipulate("increment", "gnormal")
    --     end,
    --     "gnormal",
    --   },
    --   {
    --     "g<C-x>", -- Decrement in gnormal mode
    --     function()
    --       return require("dial.map").manipulate("decrement", "gnormal")
    --     end,
    --     "gnormal",
    --   },
    --   {
    --     "<C-a>", -- Increment in visual mode
    --     function()
    --       return require("dial.map").manipulate("increment", "visual")
    --     end,
    --     "v",
    --   },
    --   {
    --     "<C-x>", -- Decrement in visual mode
    --     function()
    --       return require("dial.map").manipulate("decrement", "visual")
    --     end,
    --     "v",
    --   },
    --   {
    --     "g<C-a>", -- Increment in gvisual mode
    --     function()
    --       return require("dial.map").manipulate("increment", "gvisual")
    --     end,
    --     "gvisual",
    --   },
    --   {
    --     "g<C-x>", -- Decrement in gvisual mode
    --     function()
    --       return require("dial.map").manipulate("decrement", "gvisual")
    --     end,
    --     "gvisual",
    --   },
  },
}
