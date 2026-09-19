local map = function(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end
local fzf = require("fzf-lua")
map("n", "<leader><space>", fzf.files, "Find files")
map("n", "<leader>ff", fzf.files, "Find files")
map("n", "<leader>,", fzf.buffers, "Open buffers")
map("n", "<leader>fb", fzf.buffers, "Open buffers")
map("n", "<leader>fr", fzf.oldfiles, "Recent files")
map("n", "<leader>/", fzf.live_grep, "Search project")
map("n", "<leader>fw", fzf.grep_cword, "Search word")
map("n", "<leader>fs", fzf.lsp_document_symbols, "Document symbols")
map("n", "<leader>fS", fzf.lsp_live_workspace_symbols, "Workspace symbols")
map("n", "<leader>fd", fzf.diagnostics_workspace, "Diagnostics")
map("n", "<leader>fh", fzf.help_tags, "Help")
map("n", "<leader>e", "<cmd>Yazi<cr>", "Yazi at current file")
map("n", "<leader>E", "<cmd>Yazi cwd<cr>", "Yazi at working directory")
map("n", "<S-h>", "<cmd>bprevious<cr>", "Previous buffer")
map("n", "<S-l>", "<cmd>bnext<cr>", "Next buffer")
map("n", "<leader>bb", "<C-^>", "Alternate buffer")
map("n", "<leader>bd", "<cmd>bdelete<cr>", "Close buffer")
map("n", "<leader>w", "<cmd>write<cr>", "Save")
map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlight")
map("n", "<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
map({ "n", "x" }, "<leader>cf", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, "Format")
map("n", "<leader>uf", function()
	vim.b.disable_autoformat = not vim.b.disable_autoformat
	print("Format on save: " .. (vim.b.disable_autoformat and "off" or "on"))
end, "Toggle buffer format on save")
map("n", "<leader>uh", function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
end, "Toggle inlay hints")
map("n", "<C-d>", "<C-d>zz", "Half page down")
map("n", "<C-u>", "<C-u>zz", "Half page up")
map("x", "<", "<gv", "Indent left")
map("x", ">", ">gv", "Indent right")

vim.diagnostic.config({
	severity_sort = true,
	update_in_insert = false,
	virtual_text = false,
	float = { border = "rounded", source = true },
	signs = { text = { [1] = "󰅚", [2] = "󰀪", [3] = "󰋽", [4] = "󰌶" } },
})

local group = vim.api.nvim_create_augroup("editor_workflow", { clear = true })
-- Reload external AI edits only when Neovim has no conflicting unsaved changes.
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
	group = group,
	callback = function()
		if vim.fn.mode() ~= "c" then
			vim.cmd.checktime()
		end
	end,
})
vim.api.nvim_create_autocmd("FileType", {
	group = group,
	callback = function()
		vim.opt_local.formatoptions:remove({ "r", "o" })
	end,
})
vim.api.nvim_create_autocmd("TextYankPost", {
	group = group,
	callback = function()
		vim.hl.on_yank({ timeout = 150 })
	end,
})
-- Ruff handles linting; basedpyright owns Python hover/type information.
vim.api.nvim_create_autocmd("LspAttach", {
	group = group,
	callback = function(event)
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if client and client.name == "ruff" then
			client.server_capabilities.hoverProvider = false
		end
	end,
})
