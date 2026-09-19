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
map("n", "<leader>gg", "<cmd>LazyGit<cr>", "Lazygit")
-- Keep one current-file comparison per tab; never close unrelated splits.
local git_diffs = {}
map("n", "<leader>gd", function()
	local tab = vim.api.nvim_get_current_tabpage()
	local diff = git_diffs[tab]
	if diff then
		if diff.pending then
			return
		end
		for win, buf in pairs(diff.originals) do
			if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
				vim.api.nvim_win_close(win, false)
			end
		end
		if vim.api.nvim_win_is_valid(diff.source) then
			vim.api.nvim_set_current_win(diff.source)
			vim.cmd.diffoff()
		end
		git_diffs[tab] = nil
		return
	end
	-- Leave manually opened vimdiff sessions alone.
	if vim.wo.diff then
		return
	end
	local existing = {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		existing[win] = true
	end
	diff = { source = vim.api.nvim_get_current_win(), originals = {}, pending = true }
	git_diffs[tab] = diff
	-- HEAD includes both staged and unstaged edits; Gitsigns restores source focus.
	require("gitsigns").diffthis("HEAD", { vertical = true, split = "aboveleft" }, function(err)
		diff.pending = false
		if vim.api.nvim_tabpage_is_valid(tab) then
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
				if not existing[win] and vim.wo[win].diff then
					diff.originals[win] = vim.api.nvim_win_get_buf(win)
				end
			end
		end
		if not next(diff.originals) then
			git_diffs[tab] = nil
		end
		if err then
			vim.notify(err, vim.log.levels.ERROR)
		end
	end)
end, "Toggle original/current-file diff")
map("n", "]h", function()
	if vim.wo.diff then
		vim.cmd.normal({ vim.v.count1 .. "]c", bang = true })
	else
		require("gitsigns").nav_hunk("next", { target = "all" })
	end
end, "Next Git hunk")
map("n", "[h", function()
	if vim.wo.diff then
		vim.cmd.normal({ vim.v.count1 .. "[c", bang = true })
	else
		require("gitsigns").nav_hunk("prev", { target = "all" })
	end
end, "Previous Git hunk")
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
map("n", "<C-o>", "<C-o>zvzz", "Older jump")
map("n", "<C-i>", "<C-i>zvzz", "Newer jump")
map("n", "<C-t>", "<C-t>zvzz", "Previous tag")
map("n", "n", "nzvzz", "Next search match")
map("n", "N", "Nzvzz", "Previous search match")
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
local reading_stdin = false
vim.api.nvim_create_autocmd("StdinReadPre", {
	group = group,
	once = true,
	callback = function()
		reading_stdin = true
	end,
})
vim.api.nvim_create_autocmd("VimEnter", {
	group = group,
	once = true,
	callback = function()
		vim.schedule(function()
			-- Only replace an empty interactive start, not files, stdin, or a session.
			if
				reading_stdin
				or vim.fn.argc() ~= 0
				or #vim.api.nvim_list_uis() == 0
				or vim.v.this_session ~= ""
				or vim.api.nvim_buf_get_name(0) ~= ""
				or vim.bo.buftype ~= ""
				or vim.bo.modified
				or vim.api.nvim_buf_line_count(0) ~= 1
				or vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= ""
			then
				return
			end
			fzf.files()
		end)
	end,
})
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
