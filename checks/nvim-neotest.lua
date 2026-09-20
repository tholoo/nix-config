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
end)
if not ok then
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd.cquit()
else
	print("PASS: neotest adapters, all test actions, and preserved tour navigation")
	vim.cmd("qa!")
end
