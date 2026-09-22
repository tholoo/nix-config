-- Run with the configured editor in a disposable XDG environment:
-- nvim --headless -i NONE -c 'lua dofile("checks/nvim-leap.lua")'
-- Uses real Leap targets and keystrokes; never accesses the system clipboard.
vim.opt.clipboard = ""
local function input(keys)
	vim.api.nvim_input(keys)
	coroutine.yield()
end
local function lines()
	return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end
local function fixture(content, cursor)
	vim.cmd("enew!")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, content)
	vim.api.nvim_win_set_cursor(0, cursor or { 1, 0 })
	vim.cmd("normal! zt")
end
local function copy(keys, pattern)
	input(keys)
	input(pattern)
	input("s") -- First label, with a unique synthetic match.
end
local scenario = coroutine.create(function()
	fixture({ "X", "quartz stone" })
	local view = vim.fn.winsaveview()
	copy("yirw", "qu")
	assert(vim.deep_equal(lines(), { "Xquartz", "quartz stone" }), "remote word was not copied")
	assert(vim.deep_equal(vim.fn.winsaveview(), view), "copy moved the cursor or scrolled")
	input("u")
	assert(vim.deep_equal(lines(), { "X", "quartz stone" }), "copy must be one undo step")

	fixture({ "X", "quartz stone" })
	-- Named registers also receive the yank; copying uses the actual yank event.
	copy('"ayirw', "qu")
	assert(vim.fn.getreg("a") == "quartz", "named register was lost")
	assert(lines()[1] == "Xquartz", "named-register remote copy failed")

	fixture({ "X", "quartz stone", "second line" })
	copy("y2rr", "qu")
	assert(
		vim.deep_equal(lines(), { "X", "quartz stone", "second line", "quartz stone", "second line" }),
		"linewise copy/count failed"
	)
	assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }), "linewise copy moved cursor")

	-- Cross-window sources remain untouched and focus returns to the destination.
	fixture({ "X" })
	local dest_win = vim.api.nvim_get_current_win()
	vim.cmd("vnew")
	local source_win = vim.api.nvim_get_current_win()
	local source_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "quartz stone" })
	vim.api.nvim_set_current_win(dest_win)
	copy("yirw", "qu")
	assert(vim.api.nvim_get_current_win() == dest_win and lines()[1] == "Xquartz", "cross-window copy failed")
	assert(
		vim.deep_equal(vim.api.nvim_buf_get_lines(source_buf, 0, -1, false), { "quartz stone" }),
		"copy edited its source"
	)
	assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }), "cross-window copy moved cursor")
	vim.api.nvim_win_close(source_win, true)

	fixture({ "X", "quartz stone" })
	vim.fn.setreg('"', "stale contents")
	input("yirw")
	input("<Esc>")
	assert(vim.deep_equal(lines(), { "X", "quartz stone" }), "canceled search pasted stale text")
	input("yirw")
	input("qu")
	input("<Esc>")
	assert(vim.deep_equal(lines(), { "X", "quartz stone" }), "canceled label selection changed text")

	copy("dirw", "qu")
	assert(vim.deep_equal(lines(), { "X", " stone" }), "remote delete must not paste")
	assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }), "remote delete did not return")

	-- Ordinary yanks must remain ordinary yanks.
	fixture({ "quartz stone" })
	input("yiw")
	assert(lines()[1] == "quartz stone", "ordinary yank unexpectedly pasted")
	assert(vim.fn.maparg("gsa", "n") ~= "", "surround mapping was displaced")
	print("PASS: remote word/line copy, counts, registers, splits, cursor/view, undo, cancellation and ordinary yanks")
	vim.cmd("qa!")
end)
local function resume()
	local ok, err = coroutine.resume(scenario)
	if not ok then
		io.stderr:write(tostring(err) .. "\n")
		vim.cmd.cquit()
	elseif coroutine.status(scenario) ~= "dead" then
		vim.defer_fn(resume, 100)
	end
end
vim.defer_fn(resume, 100)
vim.defer_fn(function()
	io.stderr:write("remote-copy check timed out\n")
	vim.cmd.cquit()
end, 20000)
