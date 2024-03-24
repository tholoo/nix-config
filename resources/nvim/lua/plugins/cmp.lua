return {
  "hrsh7th/nvim-cmp",
  -- opts = function(_, opts)
  --   local cmp = require("cmp")
  --   opts.window = {
  --     completion = require("cmp.config.window").bordered({ scrollbar = false }),
  --     documentation = require("cmp.config.window").bordered(),
  --   }
  --   opts.mapping = {
  --     ["<CR>"] = require("cmp").mapping(function(fallback)
  --       fallback()
  --     end),
  --
  --     ["<C-Space>"] = require("cmp").mapping.confirm({
  --       behavior = require("cmp").ConfirmBehavior.Insert,
  --       select = true,
  --     }),
  --   }
  --   -- modify the sources part of the options table
  --   opts.sources = cmp.config.sources({
  --     { name = "nvim_lsp", priority = 1000 },
  --     { name = "luasnip", priority = 750 },
  --     { name = "buffer", priority = 500 },
  --     { name = "path", priority = 250 },
  --     { name = "vim-dadbod-completion", priority = 700 }, -- add new source
  --   })
  --   -- return the new table to be used
  --   return opts
  -- end,

  -- opts = function(_, opts)
  --   opts.window = {
  --     completion = require("cmp.config.window").bordered({ scrollbar = false }),
  --     documentation = require("cmp.config.window").bordered(),
  --   }
  --   opts.mapping = {
  --     ["<CR>"] = require("cmp").mapping(function(fallback)
  --       fallback()
  --     end),
  --
  --     ["<C-Space>"] = require("cmp").mapping.confirm({
  --       behavior = require("cmp").ConfirmBehavior.Insert,
  --       select = true,
  --     }),
  --   }
  --
  --   return opts
  -- end,

  opts = {
    window = {
      completion = require("cmp.config.window").bordered({ scrollbar = false }),
      documentation = require("cmp.config.window").bordered(),
    },
    mapping = {
      ["<CR>"] = require("cmp").mapping(function(fallback)
        fallback()
      end),

      ["<C-Space>"] = require("cmp").mapping.confirm({
        behavior = require("cmp").ConfirmBehavior.Insert,
        select = true,
      }),
    },
  },
}
