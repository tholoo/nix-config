-- Run with the configured Neovim:
-- nvim --headless -c 'lua dofile("checks/nvim-lazygit.lua")'
-- Or with a minimal init loading lazygit.nvim and the integration under test.
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/repo", "p")
local original_cwd = vim.fn.getcwd()
local failures = {}
local function wait_for(predicate, message)
	assert(vim.wait(5000, predicate, 20), message)
end
local function screen(buf)
	return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end
local function test(name, body, shell)
	local original_shell = vim.env.SHELL
	if shell then
		vim.env.SHELL = shell
	end
	local ok, err = pcall(body)
	vim.env.SHELL = original_shell
	if ok then
		print("PASS: " .. name)
	else
		table.insert(failures, name .. ": " .. tostring(err))
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[buf].buftype == "terminal" then
			pcall(vim.fn.jobstop, vim.b[buf].terminal_job_id)
		end
	end
	vim.wait(100, function()
		return false
	end)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_config(win).relative ~= "" then
			vim.api.nvim_win_close(win, true)
		end
	end
	LAZYGIT_BUFFER = nil
	LAZYGIT_LOADED = false
end

-- Isolate all LazyGit state and Git configuration from the user's checkout.
vim.env.XDG_CONFIG_HOME = root .. "/config"
vim.env.XDG_STATE_HOME = root .. "/state"
vim.env.GIT_CONFIG_GLOBAL = "/dev/null"
vim.env.GIT_CONFIG_NOSYSTEM = "1"
vim.env.EDITOR = "nvim"
vim.env.VISUAL = "nvim"
vim.env.TERM = "xterm-256color"
vim.fn.mkdir(root .. "/config/lazygit", "p")
vim.fn.writefile({
	"disableStartupPopups: true",
	"gui:",
	"  useHunkModeInStagingView: false",
	"git:",
	"  autoFetch: false",
	"update:",
	"  method: never",
}, root .. "/config/lazygit/config.yml")
if type(vim.g.lazygit_config_file_path) == "table" then
	local configs = vim.g.lazygit_config_file_path
	configs[1] = root .. "/config/lazygit/config.yml"
	vim.g.lazygit_config_file_path = configs
end
vim.fn.system({ "git", "init", "-q", root .. "/repo" })
assert(vim.v.shell_error == 0, "git init failed")
vim.cmd.cd(root .. "/repo")
local filename = "file with 'quotes' ; $dollar.txt"
vim.fn.writefile({ "first line", "second line", "third line" }, filename)
vim.o.columns = 160
vim.o.lines = 50
vim.o.hidden = true
local function launch()
	local source = vim.api.nvim_get_current_win()
	vim.cmd.LazyGit()
	local float = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_get_current_buf()
	wait_for(function()
		return vim.b[buf].terminal_job_id ~= nil and screen(buf):find("$dollar", 1, true) ~= nil
	end, "LazyGit did not show the test file")
	return source, float, buf, vim.b[buf].terminal_job_id
end

test("Escape dismisses a popup, then quits at top level", function()
	local source, float, buf, job = launch()
	vim.fn.chansend(job, "\r")
	wait_for(function()
		return screen(buf):find("Return to files panel", 1, true) ~= nil
	end, "staging view did not open")
	vim.fn.chansend(job, "\27")
	wait_for(function()
		return screen(buf):find("Return to files panel", 1, true) == nil
	end, "Escape did not leave staging")
	assert(vim.api.nvim_win_is_valid(float), "Escape quit from a nested view")
	vim.fn.chansend(job, "?")
	wait_for(function()
		return screen(buf):find("Type to filter", 1, true) ~= nil
	end, "help popup did not open")
	vim.fn.chansend(job, "\27")
	wait_for(function()
		return screen(buf):find("Type to filter", 1, true) == nil
	end, "Escape did not dismiss help")
	assert(vim.api.nvim_win_is_valid(float), "Escape quit while dismissing a popup")
	vim.fn.chansend(job, "\27")
	wait_for(function()
		return not vim.api.nvim_win_is_valid(float)
	end, "top-level Escape did not close LazyGit")
	assert(vim.api.nvim_get_current_win() == source, "Escape did not return to the source window")
end)

local function edit_from_files()
	vim.cmd.enew()
	local modified = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_lines(modified, 0, -1, false, { "unsaved work" })
	vim.bo.modified = true
	vim.cmd.vsplit()
	local source, float, _, job = launch()
	vim.fn.chansend(job, "e")
	wait_for(function()
		return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(source)) == root .. "/repo/" .. filename
	end, "e did not open the selected file in the original window")
	wait_for(function()
		return not vim.api.nvim_win_is_valid(float)
	end, "editing left the LazyGit float open")
	assert(vim.api.nvim_get_current_win() == source, "edit focus left the original window")
	assert(#vim.api.nvim_list_tabpages() == 1, "editing created a new tab")
	assert(vim.bo[modified].modified, "unsaved buffer was discarded")
	assert(vim.api.nvim_buf_get_lines(modified, 0, -1, false)[1] == "unsaved work", "unsaved text changed")
	wait_for(function()
		return LAZYGIT_BUFFER == nil and not LAZYGIT_LOADED
	end, "LazyGit did not reset its state")
	-- Reopen without resetting plugin globals: stale jobs must not break the next launch.
	local _, reopened, _, next_job = launch()
	vim.fn.chansend(next_job, "\27")
	wait_for(function()
		return not vim.api.nvim_win_is_valid(reopened)
	end, "reopened LazyGit did not close")
end

local function edit_at_line()
	local source, float, buf, job = launch()
	vim.fn.chansend(job, "\r")
	wait_for(function()
		return screen(buf):find("Return to files panel", 1, true) ~= nil
	end, "staging view did not open")
	vim.fn.chansend(job, "je")
	wait_for(function()
		return not vim.api.nvim_win_is_valid(float)
	end, "edit-at-line did not close LazyGit")
	wait_for(function()
		return LAZYGIT_BUFFER == nil
	end, "edit-at-line did not finish quitting LazyGit")
	assert(vim.api.nvim_get_current_win() == source, "edit-at-line left the original window")
	assert(vim.api.nvim_win_get_cursor(source)[1] == 2, "edit-at-line lost the selected line")
end

-- LazyGit executes os.edit through $SHELL. Nushell deliberately does not
-- interpolate "$NVIM" inside a plain quoted string as POSIX shells do.
for _, shell in ipairs({ "bash", "nu" }) do
	local executable = vim.fn.exepath(shell)
	assert(executable ~= "", "LazyGit regression checks require " .. shell .. " on PATH")
	test("e opens in the originating split and preserves unsaved text (" .. shell .. ")", edit_from_files, executable)
	test("e in the diff preserves the selected line (" .. shell .. ")", edit_at_line, executable)
end

vim.cmd.cd(original_cwd)
vim.fn.delete(root, "rf")
for _, failure in ipairs(failures) do
	io.stderr:write("FAIL: " .. failure .. "\n")
end
if #failures > 0 then
	vim.cmd("cquit 1")
end
vim.cmd("qa!")
