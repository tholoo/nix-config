return {
  {
    "eandrju/cellular-automaton.nvim",
    keys = {
      -- add a keymap to browse plugin files
      -- stylua: ignore
      -- {
      --   "<jeader>\\\\",
      --   "<C-w>q",
      --   desc = "Reset",
      -- },
      {
        "<leader>\\r",
        function()
          require("cellular-automaton").start_animation("make_it_rain")
        end,
        desc = "Make it rain",
      },
      {
        "<leader>\\s",
        function()
          require("cellular-automaton").start_animation("scramble")
        end,
        desc = "Make it rain",
      },
    },
  },
}
