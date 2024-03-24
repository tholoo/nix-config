return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    -- opts = function(_, opts)
    --
    --   return opts
    -- end
    -- config = function()
    --   require("telescope").load_extension("fzf")
    -- end,
  },
  keys = {
    { "<C-f>", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
  },
  opts = {
    defaults = {
      layout_strategy = "horizontal",
      layout_config = { prompt_position = "top" },
      sorting_strategy = "ascending",
      winblend = 0,
      file_ignore_patterns = { "pyc" },
    },
  },
  -- keys = {
  -- add a keymap to browse plugin files
  -- stylua: ignore
  --   {
  --     "<leader>fp",
  --     function() require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root }) end,
  --     desc = "Find Plugin File",
  --   },
  -- },
  -- change some options
  -- opts = {
  --   defaults = {
  --     layout_strategy = "horizontal",
  --     layout_config = { prompt_position = "top" },
  --     sorting_strategy = "ascending",
  --     winblend = 0,
  --     file_ignore_patterns = {"pyc"}
  --   },
  -- },
  -- opts = function(_, opts)
  -- local function flash(prompt_bufnr)
  --   require("flash").jump({
  --     pattern = "^",
  --     label = { after = { 0, 0 } },
  --     search = {
  --       mode = "search",
  --       exclude = {
  --         function(win)
  --           return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "TelescopeResults"
  --         end,
  --       },
  --     },
  --     action = function(match)
  --       local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
  --       picker:set_selection(match.pos[1] - 1)
  --     end,
  --   })
  -- end
  -- opts.defaults = {
  --     layout_strategy = "horizontal",
  --     layout_config = { prompt_position = "top" },
  --     sorting_strategy = "ascending",
  --     winblend = 0,
  --     file_ignore_patterns = {"pyc"}
  -- }
  -- opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
  -- mappings = {
  --   n = { t = flash },
  --   i = { ["<c-s>"] = flash },
  -- },
  -- })
  -- end,
  -- },
}
