return {
  {
    "folke/flash.nvim",
    enabled = true,

    keys = {
      {
        "S",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump()
        end,
        desc = "Flash",
      },
      {
        "s",
        mode = { "n", "x", "o" },
        false,
        desc = "Flash Treesitter",
      },
      {
        "r",
        mode = "o",
        false,
        desc = "Remote Flash",
      },
      {
        "R",
        mode = { "o", "x" },
        false,
        desc = "Treesitter Search",
      },
      {
        "<c-s>",
        mode = { "c" },
        false,
        desc = "Toggle Flash Search",
      },
    },
    opts = {
      jump = {
        autojump = false,
      },
      label = {
        -- after = false,
        -- before = true,
        -- style = "inline",
        rainbow = {
          enabled = true,
        },
      },
      modes = {
        char = {
          enabled = false,
          -- autohide = true,
        },
      },
    },
  },
}
