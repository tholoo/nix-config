return {
  "echasnovski/mini.surround",
  enabled = false,
  opts = {
    mappings = {
      add = "s",
      delete = "ds",
      -- find = "fs",
      -- find_left = "Fs",
      highlight = "gsh",
      replace = "cs",
      update_n_lines = "gsn",
      insert_line = "ss",
    },
  },
  keys = {
    { "S", "s$", desc = "surround line" },
  },
}
