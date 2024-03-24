-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
-- vim.opt.colorcolumn = "100"
vim.opt.shell = "/bin/zsh"

-- Disable auto comment next line
vim.cmd([[autocmd FileType * set formatoptions-=ro]])

vim.opt.spelllang = "en_us"
vim.opt.spell = true

-- Disable tab line
vim.g.bufferline = false
vim.opt.showtabline = 0

-- sync with system clipboard
vim.o.clipboard = "unnamedplus"

vim.o.termguicolors = true
vim.opt.termguicolors = true

-- borders
vim.diagnostic.config({
  float = {
    border = "rounded",
  },
})
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

vim.opt.pumblend = 0

local float = { focusable = true, style = "minimal", border = "rounded" }
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, float)
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, float)

-- TODO: make a python env for neovim
-- let g:python3_host_prog = '/path/to/py3nvim/bin/python'
vim.g.python_host_prog = "/home/tholo/.pyenv/versions/3.12.1/bin/python"
vim.g.python3_host_prog = "/home/tholo/.pyenv/versions/3.12.1/bin/python"

vim.g.copilot_proxy = "localhost:2081"
