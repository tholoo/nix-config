-- Run with the configured editor:
-- nvim --headless -i NONE -c 'lua dofile("checks/nvim-yank-highlight.lua")'
-- Uses a scratch buffer and a named register; never touches the system clipboard.
local original_deprecate = vim.deprecate
local deprecated = {}
vim.deprecate = function(name, ...)
	table.insert(deprecated, name)
	return original_deprecate(name, ...)
end

local ok, err = pcall(function()
	vim.opt.clipboard = {}
	vim.cmd.enew()
	vim.bo.buftype = "nofile"
	vim.bo.swapfile = false
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Synthetic yank fixture", "Second line" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	for _ = 1, 2 do
		vim.cmd.normal({ '"zyy', bang = true })
		assert(vim.fn.getreg("z") == "Synthetic yank fixture\n", "yank must preserve its contents")
		assert(not vim.tbl_contains(deprecated, "vim.hl.on_yank"), "yank called deprecated vim.hl.on_yank")
		local namespace =
			assert(vim.api.nvim_get_namespaces()["nvim.hl.events"], "missing operator highlight namespace")
		local marks = function()
			return vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })
		end
		assert(#marks() > 0, "yanked text must still be highlighted")
		assert(marks()[1][4].hl_group == "IncSearch", "preserve the default yank highlight group")
		assert(
			vim.wait(1000, function()
				return #marks() == 0
			end, 10),
			"yank highlight must clear after its timeout"
		)
	end
end)
vim.deprecate = original_deprecate
if not ok then
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd.cquit()
else
	print("PASS: repeated yanks highlight and clear without deprecated API calls")
	vim.cmd("qa!")
end
