return {
  "nvim-telescope/telescope-file-browser.nvim",
  dependencies = { -- note how they're inverted to above example
    {
      "nvim-telescope/telescope.nvim",
      dependencies = { "nvim-lua/plenary.nvim" },
    },
  },
  keys = {
    { -- lazy style key map
      "<leader>fo",
      "<cmd>Telescope file_browser<cr>",
      desc = "browser",
    },
  },
  -- opts = {
  --   extensions = {
  --     file_browser = {
  --       theme = "ivy",
  --       -- disables netrw and use telescope-file-browser in its place
  --       hijack_netrw = true,
  --       mappings = {
  --         ["i"] = {
  --           -- your custom insert mode mappings
  --         },
  --         ["n"] = {
  --           -- your custom normal mode mappings
  --         },
  --       },
  --     },
  --   },
  -- },
  config = function(_, opts)
    -- Calling telescope's setup from multiple specs does not hurt, it will happily merge the
    -- configs for us. We won't use data, as everything is in it's own namespace (telescope
    -- defaults, as well as each extension).
    require("telescope").setup(opts)
    require("telescope").load_extension("file_browser")
  end,
}
