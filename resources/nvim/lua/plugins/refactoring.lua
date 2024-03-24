local prefix = "<leader>cR"
return {
  "ThePrimeagen/refactoring.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  keys = {
    {
      prefix .. "e",
      ":Refactor extract ",
      desc = "Extract to function",
      mode = "x",
    },
    {
      prefix .. "f",
      "<CMD>Refactor extract_to_file<CR>",
      desc = "Extract to file",
      mode = "x",
    },
    {
      prefix .. "v",
      "<CMD>Refactor extract_var<CR>",
      desc = "Extract to variable",
      mode = "x",
    },
    {
      prefix .. "i",
      "<CMD>Refactor inline_var<CR>",
      desc = "Inline variable",
      mode = { "n", "x" },
    },
    {
      prefix .. "I",
      "<CMD>Refactor inline_func<CR>",
      desc = "Inline function",
      mode = "n",
    },
    {
      prefix .. "bb",
      ":Refactor extract_block ",
      desc = "Extract to block",
      mode = "n",
    },
    {
      prefix .. "bf",
      "<CMD>Refactor extract_block_to_file<CR>",
      desc = "Extract block to file",
      mode = "n",
    },
    {
      prefix .. "n",
      "<CMD>Refactor refactor_names<CR>",
      desc = "Refactor names",
      mode = "n",
    },
  },
  -- init = function()
  --   vim.keymap.set("v", "<leader>cr", "<CMD>Refactor extract<CR>", { buffer = buffer, desc = "extract" })
  -- end,

  -- config = function()
  --   require("refactoring").setup()
  -- end,
}
