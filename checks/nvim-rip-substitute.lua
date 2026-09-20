-- Run with the configured editor in a disposable XDG environment:
-- nvim --headless -i NONE -c 'lua dofile("checks/nvim-rip-substitute.lua")'
-- Exercises real ripgrep on scratch buffers; no project files are changed.
local ok, err = pcall(function()
	assert(require("rip-substitute"), "rip-substitute is missing")
	assert(vim.fn.exists(":RipSubstitute") == 2, "RipSubstitute command missing")
	assert(vim.system({ "rg", "--pcre2-version" }, { text = true }):wait().code == 0, "ripgrep lacks PCRE2")
	for _, mode in ipairs({ "n", "x" }) do
		local map = vim.fn.maparg(" rs", mode, false, true)
		assert(map.callback and map.desc, "missing Space rs mapping in " .. mode)
	end

	local function fixture()
		vim.cmd("enew!")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha alpha", "alpha", "alpha" })
		vim.bo.modified = false
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		return vim.api.nvim_get_current_buf()
	end
	local function open(mode)
		vim.fn.maparg(" rs", mode, false, true).callback()
		assert(vim.bo.filetype == "rip-substitute", "replacement popup did not open")
		vim.cmd.stopinsert()
		return vim.api.nvim_get_current_buf()
	end
	local function popup_action(key)
		local map = vim.fn.maparg(key, "n", false, true)
		assert(map.buffer == 1 and map.callback, "missing popup action " .. key)
		map.callback()
	end
	local function replace(source, expected)
		local popup = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_lines(popup, 0, -1, false, { "alpha", "beta" })
		vim.api.nvim_exec_autocmds("TextChanged", { buffer = popup })
		popup_action("<CR>")
		assert(
			vim.wait(5000, function()
				return vim.deep_equal(vim.api.nvim_buf_get_lines(source, 0, -1, false), expected)
			end, 10),
			"wrong substitution result: " .. vim.inspect(vim.api.nvim_buf_get_lines(source, 0, -1, false))
		)
		assert(not vim.api.nvim_buf_is_valid(popup), "popup was not cleaned up")
		assert(vim.api.nvim_get_current_buf() == source, "source buffer did not regain focus")
		assert(vim.bo[source].modified, "replacement must remain an unsaved edit")
	end

	local source = fixture()
	local original = vim.api.nvim_buf_get_lines(source, 0, -1, false)
	local popup = open("n")
	assert(vim.api.nvim_buf_get_lines(popup, 0, 1, false)[1] == "alpha", "cursor-word prefill missing")
	popup_action("q")
	assert(vim.api.nvim_get_current_buf() == source, "cancel did not restore source")
	assert(vim.deep_equal(vim.api.nvim_buf_get_lines(source, 0, -1, false), original), "cancel changed source")
	assert(not vim.bo[source].modified, "cancel dirtied source")

	open("n")
	replace(source, { "beta beta", "beta", "beta" })
	vim.cmd.undo()
	assert(vim.deep_equal(vim.api.nvim_buf_get_lines(source, 0, -1, false), original), "cannot undo replacement")

	source = fixture()
	vim.cmd("normal! ggVj")
	assert(vim.fn.mode() == "V", "fixture did not select lines")
	open("x")
	replace(source, { "beta beta", "beta", "alpha" })
end)
if not ok then
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd.cquit()
else
	print("PASS: rip-substitute mappings, PCRE2, prefill, cancel, buffer replacement/undo and selected-line range")
	vim.cmd("qa!")
end
