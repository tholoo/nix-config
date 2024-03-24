return {
  "folke/noice.nvim",
  enabled = false,
  keys = {
    { "<c-f>", false, mode = { "i", "n", "s" } },
    { "<c-b>", false, mode = { "i", "n", "s" } },
  },
  opts = function(_, opts)
    opts.presets.bottom_search = true -- use a classic bottom cmdline for search
    -- opts.presets.command_palette = false -- position the cmdline and popupmenu together
    opts.presets.long_message_to_split = true -- long messages will be sent to a split
    opts.presets.inc_rename = true -- enables an input dialog for inc-rename.nvim
    opts.presets.lsp_doc_border = true -- add a border to hover docs and signature help
    -- lsp = {
    --   -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
    --   override = {
    --     ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
    --     ["vim.lsp.util.stylize_markdown"] = true,
    --     ["cmp.entry.get_documentation"] = true,
    --   },
  end,
}
