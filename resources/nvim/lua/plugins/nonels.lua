return {
  "nvimtools/none-ls.nvim",
  opts = function(_, opts)
    local null_ls = require("null-ls")
    -- opts.root_dir = opts.root_dir
    --   or require("null-ls.utils").root_pattern(".null-ls-root", ".neoconf.json", "Makefile", ".git")
    opts.sources = vim.list_extend(opts.sources or {}, {
      -- nls.builtins.formatting.fish_indent,
      -- nls.builtins.diagnostics.fish,
      -- nls.builtins.formatting.shfmt,
      -- lua
      null_ls.builtins.formatting.stylua,
      -- null_ls.builtins.diagnostics.luacheck,

      -- git
      null_ls.builtins.code_actions.gitsigns,
      null_ls.builtins.diagnostics.gitlint,
      null_ls.builtins.diagnostics.commitlint,

      -- misc
      null_ls.builtins.code_actions.refactoring,
      -- null_ls.builtins.completion.spell,
      null_ls.builtins.diagnostics.codespell,

      -- html
      null_ls.builtins.diagnostics.djlint,

      null_ls.builtins.formatting.djlint,

      -- .env
      null_ls.builtins.diagnostics.dotenv_linter,

      -- python
      null_ls.builtins.diagnostics.ruff,
      null_ls.builtins.formatting.ruff,
      null_ls.builtins.formatting.ruff_format,
      null_ls.builtins.diagnostics.mypy,
      -- null_ls.builtins.diagnostics.mypy,
      -- null_ls.builtins.diagnostics.flake8,

      -- markdown
      null_ls.builtins.diagnostics.markdownlint_cli2,

      -- sql
      -- null_ls.builtins.formatting.sql_formatter,
      -- null_ls.builtins.formatting.sqlformat,
      null_ls.builtins.formatting.sqlfluff.with({
        extra_args = { "--dialect", "mysql" },
      }),
      null_ls.builtins.diagnostics.sqlfluff.with({
        extra_args = { "--dialect", "mysql" },
      }),

      -- bash
      null_ls.builtins.formatting.shfmt,
    })
  end,
}
