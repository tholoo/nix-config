-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local Util = require("lazyvim.util")
local map = vim.keymap.set
-- local map = Util.safe_keymap_set
-- local root_files = {
--
-- }

map({ "n" }, "<C-d>", "<C-d>zz", { silent = true })
map({ "n" }, "<C-u>", "<C-u>zz", { silent = true })

map({ "n" }, "]<Space>", ':<C-u>put =repeat(nr2char(10),v:count)<Bar>execute "\'[-1"<CR>', { silent = true })
map({ "n" }, "[<Space>", ':<C-u>put!=repeat(nr2char(10),v:count)<Bar>execute "\']+1"<CR>', { silent = true })

-- vim.keymap.del("n", "s")

vim.keymap.set("n", "<C-f>", "<cmd>Telescope find_files<cr>")

-- vim.keymap.del("n", "<leader>l")
-- vim.keymap.del("n", "<leader>L")

-- lazy
vim.keymap.set("n", "<leader>L", "<cmd>Lazy<cr>", { desc = "Lazy" })

-- I don't know how else to override lazy
local harpoon = require("harpoon")
vim.keymap.set("n", "<leader>l", function()
  harpoon:list():select(4)
end, { desc = "Third Harpoon" })

vim.keymap.del("n", "<C-f>")

vim.keymap.set("n", "<C-_>", function()
  Util.terminal(nil, { border = "rounded" })
end, { desc = "Term with border" })

-- Center on jump to mark
-- :nnoremap <expr> ' "'" . nr2char(getchar()) . 'zz'
-- :nnoremap <expr> ` "`" . nr2char(getchar()) . 'zz'
vim.cmd([[nnoremap <expr> ' "'" . nr2char(getchar()) . 'zz']])
vim.cmd([[nnoremap <expr> ` "`" . nr2char(getchar()) . 'zz']])
