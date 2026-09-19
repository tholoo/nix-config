{ config, ... }:
{
  plugins.treesitter = {
    enable = true;
    highlight.enable = true;
    highlight.disable.__raw = "function(_, buf) return vim.api.nvim_buf_line_count(buf) > 20000 or vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf)) > 1024 * 1024 end";
    grammarPackages = with config.plugins.treesitter.package.builtGrammars; [
      bash
      c
      cpp
      css
      diff
      go
      gomod
      html
      javascript
      jsdoc
      json
      lua
      luadoc
      markdown
      markdown_inline
      nix
      python
      regex
      rust
      sql
      toml
      tsx
      typescript
      vim
      vimdoc
      yaml
    ];
  };
}
