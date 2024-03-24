return {
  "echasnovski/mini.ai",
  config = function(_, opts)
    local spec_treesitter = require("mini.ai").gen_spec.treesitter
    opts.custom_textobjects["v"] =
      spec_treesitter({ a = { "@assignment.inner" }, i = { "@assignment.rhs", "@identifier.inner" } })
    opts.custom_textobjects["V"] = spec_treesitter({ a = { "@assignment.outer" }, i = { "@assignment.lhs" } })
    opts.search_method = "cover_or_nearest"
    require("mini.ai").setup(opts)
  end,
}
