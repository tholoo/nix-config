return {
  { "williamboman/mason.nvim", enabled = false },
  {
    "VonHeikemen/lsp-zero.nvim",
    branch = "v3.x",
    config = function()
      local lsp_zero = require("lsp-zero")
      lsp_zero.extend_lspconfig()
      lsp_zero.set_preferences({
        suggest_lsp_servers = true,
        setup_servers_on_start = true,
        call_servers = "global",
      })

      lsp_zero.on_attach(function(client, bufnr)
        -- see :help lsp-zero-keybindings
        -- to learn the available actions
        lsp_zero.default_keymaps({ buffer = bufnr })
      end)

      lsp_zero.setup_servers({ "tsserver", "ruff", "ruff_lsp" })
    end,
  },
  -- {'neovim/nvim-lspconfig'},
  -- {'hrsh7th/cmp-nvim-lsp'},
  -- {'hrsh7th/nvim-cmp'},
  -- {'L3MON4D3/LuaSnip'},
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        -- pyright will be automatically installed with mason and loaded with lspconfig
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "off",
              },
            },
          },
        },
      },
    },
  },
}
