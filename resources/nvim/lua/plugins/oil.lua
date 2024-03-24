return {
  "stevearc/oil.nvim",
  opts = {
    delete_to_trash = true,
    skip_confirm_for_simple_edits = true,
    win_optiosn = {
      spell = true,
    },
    view_options = {
      show_hidden = true,
    },
    keymaps = {
      ["gos"] = "actions.change_sort",
      ["gox"] = "actions.open_external",
      ["go."] = "actions.toggle_hidden",
      ["go\\"] = "actions.toggle_trash",
    },
  },
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    {
      "<leader>i",
      "<CMD>Oil<CR>",
      desc = "browser",
    },
  },
}
