-- Configured Neovim: nvim --headless -c 'lua dofile("checks/nvim-diff-zoom.lua")'
local source = vim.env.NVIM_TEST_SOURCE
local function load(name)
	return source and dofile(source .. "/" .. name .. ".lua") or require("editor." .. name)
end
local Zoom, Diff = load("zellij-zoom"), load("git-diff")
local failures, passed = {}, 0
local function wait(predicate)
	assert(vim.wait(5000, predicate, 10), "timed out")
end
local function test(name, body)
	local ok, err = pcall(body)
	if ok then
		passed = passed + 1
		print("PASS: " .. name)
	else
		table.insert(failures, name .. ": " .. tostring(err))
	end
end
local function rig(options)
	local r = vim.tbl_extend(
		"force",
		{ fullscreen = false, toggles = 0, width = 60, calls = {}, warnings = {} },
		options or {}
	)
	if r.fullscreen then
		r.width = 120
	end
	r.zoom = Zoom.new({
		env = r.env or { ZELLIJ = "0", ZELLIJ_SESSION_NAME = "fixture session", ZELLIJ_PANE_ID = "7" },
		command = "/fixture/zellij",
		size = function()
			return r.width, 40
		end,
		notify = function(message)
			table.insert(r.warnings, message)
		end,
		run = function(argv, cb)
			assert(argv[1] == "/fixture/zellij" and argv[2] == "--session" and argv[3] == "fixture session")
			table.insert(r.calls, argv[5])
			vim.schedule(function()
				local failed = r.fail == argv[5]
				if failed then
					r.fail = nil
				end
				if argv[5] == "toggle-fullscreen" then
					assert(argv[6] == "--pane-id" and argv[7] == "terminal_7")
					if not failed or r.apply_then_fail then
						r.fullscreen = not r.fullscreen
						r.toggles = r.toggles + 1
						if not r.delay_resize then
							r.width = r.fullscreen and 120 or 60
						end
					end
				end
				local pane = {
					id = 7,
					is_plugin = false,
					is_fullscreen = r.fullscreen,
					is_floating = r.floating,
					pane_content_columns = r.fullscreen and 120 or 60,
					pane_content_rows = 40,
				}
				local panes = { { id = 7, is_plugin = true }, { id = 99, is_plugin = false } }
				if not r.missing then
					table.insert(panes, pane)
				end
				cb({
					code = failed and 1 or 0,
					stderr = failed and "fixture failure" or "",
					stdout = r.bad_json and "not json" or vim.json.encode(panes),
				})
			end)
		end,
	})
	function r.acquire()
		local complete, lease, err = false, nil, nil
		r.zoom.acquire(function(l, e)
			complete, lease, err = true, l, e
		end)
		wait(function()
			return complete
		end)
		return lease, err
	end
	return r
end

test("targeted fullscreen acquisition and restoration", function()
	local r = rig()
	local lease, err = r.acquire()
	assert(lease and not err and r.fullscreen and r.toggles == 1)
	r.zoom.release(lease)
	wait(function()
		return not r.fullscreen
	end)
	assert(r.toggles == 2)
end)
test("already-fullscreen panes stay fullscreen", function()
	local r = rig({ fullscreen = true })
	local lease = assert(r.acquire())
	r.zoom.release(lease)
	r.zoom.shutdown()
	assert(r.fullscreen and r.toggles == 0)
end)
test("outside Zellij runs no commands", function()
	local r = rig({ env = {} })
	r.zoom.release(assert(r.acquire()))
	r.zoom.shutdown()
	assert(#r.calls == 0)
end)
test("missing pane identity fails without commands", function()
	local r = rig({ env = { ZELLIJ = "0" } })
	local lease, err = r.acquire()
	assert(not lease and err and #r.calls == 0)
end)
for name, options in pairs({
	["query failure"] = { fail = "list-panes" },
	["invalid JSON"] = { bad_json = true },
	["missing pane"] = { missing = true },
	["floating pane"] = { floating = true },
	["toggle failure"] = { fail = "toggle-fullscreen" },
}) do
	test(name .. " does not grant a lease", function()
		local r = rig(options)
		local lease, err = r.acquire()
		assert(not lease and err and not r.fullscreen)
	end)
end
test("a toggle applied before failure is rolled back", function()
	local r = rig({ fail = "toggle-fullscreen", apply_then_fail = true })
	local lease, err = r.acquire()
	assert(not lease and err and not r.fullscreen and r.toggles == 2)
end)
test("waits for resize before granting lease", function()
	local r = rig({ delay_resize = true })
	local lease
	r.zoom.acquire(function(l, err)
		assert(not err)
		lease = l
	end)
	wait(function()
		return r.fullscreen
	end)
	assert(not vim.wait(80, function()
		return lease ~= nil
	end, 10))
	r.width = 120
	wait(function()
		return lease ~= nil
	end)
	r.zoom.shutdown()
end)
test("resize timeout rolls fullscreen back", function()
	local r = rig({ delay_resize = true })
	local lease, err = r.acquire()
	assert(not lease and err:find("Timed out") and not r.fullscreen)
end)
test("multiple users retain fullscreen until last release", function()
	local r = rig()
	local first, second = assert(r.acquire()), assert(r.acquire())
	r.zoom.release(first)
	assert(r.fullscreen and r.toggles == 1)
	r.zoom.release(second)
	wait(function()
		return not r.fullscreen
	end)
	assert(r.toggles == 2)
end)
test("manual unfullscreen is not toggled back on during release", function()
	local r = rig()
	local lease = assert(r.acquire())
	r.fullscreen = false
	r.zoom.release(lease)
	r.zoom.shutdown()
	assert(not r.fullscreen and r.toggles == 1)
end)
test("exit restores an active lease", function()
	local r = rig()
	assert(r.acquire())
	r.zoom.shutdown()
	assert(not r.fullscreen and r.toggles == 2)
end)

test("queued acquisitions serialize fullscreen toggles", function()
	local r = rig()
	local acquired = {}
	for _ = 1, 2 do
		r.zoom.acquire(function(lease, err)
			assert(not err)
			table.insert(acquired, lease)
		end)
	end
	wait(function()
		return #acquired == 2
	end)
	assert(r.toggles == 1)
	r.zoom.release(acquired[1])
	r.zoom.release(acquired[1])
	assert(r.fullscreen)
	r.zoom.release(acquired[2])
	r.zoom.shutdown()
	assert(not r.fullscreen and r.toggles == 2)
end)
test("exit cancels an in-flight acquisition", function()
	local r = rig()
	local finished, result, failure
	r.zoom.acquire(function(lease, err)
		finished, result, failure = true, lease, err
	end)
	r.zoom.shutdown()
	assert(finished and not result and failure and not r.fullscreen)
end)

-- Exercise the lifecycle with real Neovim windows and a controlled diff backend.
local original_notify = vim.notify
vim.notify = function() end
local serial = 0
local function diff_rig(options)
	options = options or {}
	pcall(vim.api.nvim_del_augroup_by_name, "EditorGitDiff")
	vim.cmd("silent! tabonly!")
	vim.cmd("silent! only!")
	vim.cmd.enew()
	vim.cmd.diffoff()
	local r = { opened = 0, acquired = 0, released = 0, source = vim.api.nvim_get_current_win() }
	r.manager = Diff.setup({
		zoom = {
			acquire = function(callback)
				r.acquired = r.acquired + 1
				r.resolve = function()
					callback(options.zoom_error and nil or {}, options.zoom_error)
				end
				if not options.delayed then
					vim.schedule(r.resolve)
				end
			end,
			release = function()
				r.released = r.released + 1
			end,
			shutdown = function() end,
		},
		diffthis = function(callback)
			r.opened = r.opened + 1
			if options.open_error then
				error("diff creation failed")
			end
			if options.no_diff then
				callback()
				return
			end
			local win = vim.api.nvim_get_current_win()
			vim.cmd.vnew()
			serial = serial + 1
			vim.api.nvim_buf_set_name(0, "gitsigns://fixture//HEAD/test-" .. serial)
			vim.cmd.diffthis()
			r.original = vim.api.nvim_get_current_win()
			vim.api.nvim_set_current_win(win)
			vim.cmd.diffthis()
			callback()
		end,
	})
	return r
end
test("duplicate presses await zoom, toggle closes only its own diff", function()
	local r = diff_rig({ delayed = true })
	vim.cmd.vnew()
	local unrelated = vim.api.nvim_get_current_win()
	vim.api.nvim_set_current_win(r.source)
	r.manager.toggle()
	r.manager.toggle()
	assert(r.acquired == 1 and r.opened == 0)
	r.resolve()
	assert(r.opened == 1 and vim.wo.diff)
	r.manager.toggle()
	assert(r.released == 1 and not vim.wo.diff and vim.api.nvim_win_is_valid(unrelated))
end)
test("fullscreen failure prevents diff opening", function()
	local r = diff_rig({ zoom_error = "fixture zoom failure" })
	r.manager.toggle()
	vim.wait(40, function()
		return false
	end)
	assert(r.opened == 0)
end)
for name, options in pairs({ ["failed diff"] = { open_error = true }, ["no diff produced"] = { no_diff = true } }) do
	test(name .. " releases zoom", function()
		local r = diff_rig(options)
		r.manager.toggle()
		wait(function()
			return r.released == 1
		end)
	end)
end
test("vanished source cancels a pending open", function()
	local r = diff_rig({ delayed = true })
	r.manager.toggle()
	vim.cmd.vnew()
	vim.api.nvim_win_close(r.source, true)
	r.resolve()
	assert(r.released == 1 and r.opened == 0)
end)
test("changed focus cancels a pending open", function()
	local r = diff_rig({ delayed = true })
	r.manager.toggle()
	vim.cmd.vnew()
	r.resolve()
	assert(r.released == 1 and r.opened == 0)
end)
test("manually closing original releases zoom", function()
	local r = diff_rig()
	r.manager.toggle()
	wait(function()
		return r.original ~= nil
	end)
	vim.api.nvim_win_close(r.original, true)
	wait(function()
		return r.released == 1
	end)
	assert(not vim.wo.diff)
end)
test("repurposed original window is preserved", function()
	local r = diff_rig()
	r.manager.toggle()
	wait(function()
		return r.original ~= nil
	end)
	vim.api.nvim_win_set_buf(r.original, vim.api.nvim_create_buf(true, false))
	wait(function()
		return r.released == 1
	end)
	assert(vim.api.nvim_win_is_valid(r.original))
end)
test("manual source close releases zoom", function()
	local r = diff_rig()
	r.manager.toggle()
	wait(function()
		return r.original ~= nil
	end)
	vim.api.nvim_win_close(r.source, true)
	wait(function()
		return r.released == 1
	end)
end)
test("two tabs keep independent diff lifetimes", function()
	local r = diff_rig()
	r.manager.toggle()
	wait(function()
		return r.opened == 1
	end)
	local first = vim.api.nvim_get_current_tabpage()
	vim.cmd.tabnew()
	r.manager.toggle()
	wait(function()
		return r.opened == 2
	end)
	r.manager.toggle()
	assert(r.released == 1)
	vim.api.nvim_set_current_tabpage(first)
	assert(vim.wo.diff)
	r.manager.toggle()
	assert(r.released == 2)
end)
test("closing a diff tab releases its lease", function()
	local r = diff_rig()
	vim.cmd.tabnew()
	r.manager.toggle()
	wait(function()
		return r.original ~= nil
	end)
	vim.cmd.tabclose()
	wait(function()
		return r.released == 1
	end)
end)
test("manual vimdiff is left alone", function()
	local r = diff_rig()
	vim.cmd.diffthis()
	r.manager.toggle()
	assert(r.acquired == 0 and vim.wo.diff)
end)
vim.notify = original_notify
if #failures > 0 then
	io.stderr:write(table.concat(failures, "\n") .. "\n")
	vim.cmd("cquit 1")
else
	print(string.format("PASS: %d diff/fullscreen scenarios", passed))
	vim.cmd("qa!")
end
