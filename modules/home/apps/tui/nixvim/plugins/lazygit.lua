local M = {}

function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("lazygit_editor", { clear = true }),
		pattern = "lazygit",
		callback = function(event)
			-- lazygit.nvim enters its float before assigning the filetype.
			vim.b[event.buf].lazygit_source_window = vim.fn.win_getid(vim.fn.winnr("#"))
		end,
	})
end

function M.edit(filename, line)
	local buf = vim.api.nvim_get_current_buf()
	local float = vim.api.nvim_get_current_win()
	local source = vim.b[buf].lazygit_source_window
	assert(
		vim.bo[buf].filetype == "lazygit" and vim.api.nvim_win_get_config(float).relative ~= "",
		"the active window is not LazyGit"
	)
	assert(
		source and vim.api.nvim_win_is_valid(source) and vim.api.nvim_win_get_config(source).relative == "",
		"the original editor window is no longer available"
	)

	-- Request a normal exit so lazygit.nvim clears its job/buffer state. Closing
	-- the float immediately prevents remote editing from replacing its terminal.
	vim.fn.chansend(vim.b[buf].terminal_job_id, "\3")
	vim.cmd.stopinsert()
	vim.api.nvim_win_close(float, true)
	vim.api.nvim_set_current_win(source)
	vim.cmd("hide edit " .. vim.fn.fnameescape(filename))
	if line then
		vim.api.nvim_win_set_cursor(source, { math.max(1, math.min(line, vim.api.nvim_buf_line_count(0))), 0 })
	end
end

return M
