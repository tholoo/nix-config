-- Run with the built, configured editor in a disposable XDG environment:
-- nvim --headless -i NONE -c 'lua dofile("checks/nvim-neotest.lua")'
-- Checks startup, adapter loading, keymap dispatch, and tour-key preservation.
-- Does not launch project tests or connect to the user's editor.
local ok, err = pcall(function()
	local neotest = require("neotest")
	for _, adapter in ipairs({ "python", "golang", "rust", "jest", "vitest" }) do
		assert(require("neotest-" .. adapter), "missing adapter: " .. adapter)
	end
	local mapping = function(keys)
		local result = vim.fn.maparg(keys, "n", false, true)
		assert(result.lhs, "missing mapping: " .. keys)
		assert(result.desc and result.desc ~= "", "missing description: " .. keys)
		return result
	end
	local direct = {
		[" tt"] = neotest.run.run,
		[" tl"] = neotest.run.run_last,
		[" ts"] = neotest.run.stop,
		[" tS"] = neotest.summary.toggle,
		[" tO"] = neotest.output_panel.toggle,
	}
	for keys, callback in pairs(direct) do
		assert(mapping(keys).callback == callback, "wrong test action: " .. keys)
	end
	local check_dispatch = function(keys, target, method, expected)
		local original = target[method]
		local called = false
		target[method] = function(arg)
			called = true
			assert(vim.deep_equal(arg, expected), "wrong arguments: " .. keys)
		end
		local success, failure = pcall(mapping(keys).callback)
		target[method] = original
		assert(success, failure)
		assert(called, "action not called: " .. keys)
	end
	vim.cmd.enew()
	vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. "_test.py")
	check_dispatch(" tf", neotest.run, "run", vim.api.nvim_buf_get_name(0))
	check_dispatch(" tw", neotest.watch, "toggle", vim.api.nvim_buf_get_name(0))
	check_dispatch(" ta", neotest.run, "run", vim.fn.getcwd())
	check_dispatch(" to", neotest.output, "open", { enter = true, auto_close = true })
	check_dispatch(" tn", neotest.jump, "next", { status = "failed" })
	check_dispatch(" tp", neotest.jump, "prev", { status = "failed" })
	local tours = {
		["]t"] = "<Plug>(tour-next)",
		["[t"] = "<Plug>(tour-prev)",
		[" To"] = "<Plug>(tour-overview)",
		[" Tr"] = "<Plug>(tour-resume)",
		[" Tc"] = "<Plug>(tour-close)",
		[" Tl"] = "<cmd>TourList<cr>",
	}
	for keys, rhs in pairs(tours) do
		assert(mapping(keys).rhs:lower() == rhs:lower(), "wrong tour action: " .. keys)
	end
	for _, keys in ipairs({ " tr", " tc" }) do
		assert(vim.fn.maparg(keys, "n") == "", "old tour mapping remains: " .. keys)
	end

	-- Use the real output consumer with synthetic results, not a project runner.
	local source_win = vim.api.nvim_get_current_win()
	local source_buf = vim.api.nvim_get_current_buf()
	local source_escape = vim.fn.maparg("<Esc>", "n", false, true)
	local output = require("neotest.consumers.output")({
		listeners = {},
		get_nearest = function()
			return {
				data = function()
					return { id = "fixture", name = "Synthetic test" }
				end,
			},
				"synthetic"
		end,
		get_results = function()
			return { fixture = { status = "passed", short = "Synthetic test output\nPassed" } }
		end,
	})
	for _ = 1, 2 do
		output.open({ short = true, enter = true, auto_close = true })
		assert(
			vim.wait(3000, function()
				return vim.bo.filetype == "neotest-output"
			end, 10),
			"test output did not open"
		)
		local output_win = vim.api.nvim_get_current_win()
		assert(vim.api.nvim_win_get_config(output_win).relative ~= "", "output must be a popup")
		for _, mode in ipairs({ "n", "t" }) do
			local escape = vim.fn.maparg("<Esc>", mode, false, true)
			assert(escape.buffer == 1 and escape.desc == "Close test output", "missing buffer-local Escape")
		end
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "xt", false)
		assert(not vim.api.nvim_win_is_valid(output_win), "Escape must close test output")
		assert(vim.api.nvim_get_current_win() == source_win, "Escape must return to the source window")
		assert(vim.api.nvim_get_current_buf() == source_buf, "source buffer must remain open")
		assert(vim.deep_equal(vim.fn.maparg("<Esc>", "n", false, true), source_escape), "source Escape mapping changed")
	end

	-- Drive the real panel consumer with successive synthetic runs. This checks
	-- hidden-panel clearing as well as preservation when merely toggling it.
	local client = {
		listeners = {},
		get_position = function()
			return {
				get_key = function()
					return {
						data = function()
							return { type = "test" }
						end,
					}
				end,
			}
		end,
	}
	local panel = require("neotest.consumers.output_panel")(client)
	local latest_output = require("neotest.config").consumers.latest_output
	if latest_output then
		latest_output(client)
	end
	local function emit(event, ...)
		local args = { ... }
		local done, failure = false, nil
		require("nio").run(function()
			if client.listeners[event] then
				local success, message = pcall(client.listeners[event], unpack(args))
				if not success then
					failure = message
				end
			end
			done = true
		end)
		assert(
			vim.wait(3000, function()
				return done
			end, 10),
			"panel event did not finish: " .. event
		)
		assert(not failure, failure)
	end
	local function text()
		return table.concat(vim.api.nvim_buf_get_lines(panel.buffer(), 0, -1, false), "\n")
	end
	local function contains(marker)
		return text():find(marker, 1, true) ~= nil
	end
	local function output_file(marker)
		local path = vim.fn.tempname()
		vim.fn.writefile({ marker }, path)
		return path
	end
	local old = output_file("OLD_RUN_MARKER")
	local new_a = output_file("LATEST_RUN_A")
	local new_b = output_file("LATEST_RUN_B")
	emit("run", "synthetic", "suite", { "test_a", "test_b" })
	emit("results", "synthetic", { test_a = { status = "passed", output = old } }, false)
	assert(
		vim.wait(3000, function()
			return contains("OLD_RUN_MARKER")
		end, 10),
		"first run output missing"
	)
	assert(vim.fn.bufwinid(panel.buffer()) == -1, "running tests must not open the panel")

	emit("run", "synthetic", "suite", { "test_a", "test_b" })
	assert(not contains("OLD_RUN_MARKER"), "output panel retained the previous run")
	emit("results", "synthetic", {
		test_a = { status = "passed", output = new_a },
		test_b = { status = "failed", output = new_b },
	}, false)
	assert(
		vim.wait(3000, function()
			return contains("LATEST_RUN_A") and contains("LATEST_RUN_B")
		end, 10),
		"panel must retain all output from the latest run"
	)
	for _ = 1, 2 do
		mapping(" tO").callback()
		assert(vim.fn.bufwinid(panel.buffer()) ~= -1, "Space tO must open panel")
		assert(
			contains("LATEST_RUN_A") and contains("LATEST_RUN_B") and not contains("OLD_RUN_MARKER"),
			"toggling must preserve only current output"
		)
		mapping(" tO").callback()
	end
	panel.open()
	emit("run", "synthetic", "suite", { "test_a" })
	assert(not contains("LATEST_RUN_A") and not contains("LATEST_RUN_B"), "visible panel must also clear on a new run")
	assert(vim.fn.bufwinid(panel.buffer()) ~= -1, "clearing must not close the panel")
	panel.close()
	for _, path in ipairs({ old, new_a, new_b }) do
		vim.fn.delete(path)
	end
end)
if not ok then
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd.cquit()
else
	print("PASS: neotest adapters, test actions, tour navigation, output Escape/reopen, and latest-run output panel")
	vim.cmd("qa!")
end
