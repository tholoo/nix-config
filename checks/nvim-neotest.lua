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
end)
if not ok then
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd.cquit()
else
	print("PASS: neotest adapters, test actions, tour navigation, and output Escape/reopen")
	vim.cmd("qa!")
end
