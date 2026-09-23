-- Run with the built editor in a disposable XDG environment:
-- nvim --headless -i NONE -c 'lua dofile("checks/nvim-snippets.lua")'
-- Uses Blink's real snippet provider without starting a language server.
local ok, err = pcall(function()
	local config = require("blink.cmp.config")
	assert(config.snippets.preset == "luasnip", "nested placeholders require LuaSnip")
	assert(config.keymap.preset == "default", "completion key preset changed")
	assert(vim.tbl_contains(config.sources.default, "snippets"), "snippet source missing")
	local keys = require("blink.cmp.keymap").get_mappings(config.keymap, "default")
	local selection = require("blink.cmp.completion.list").get_selection_mode({ mode = "default" })
	assert(selection.preselect, "first completion must be highlighted")
	assert(not selection.auto_insert, "highlighting must not insert text")
	assert(keys["<C-n>"][1] == "select_next" and keys["<C-p>"][1] == "select_prev", "preserve Ctrl N/P navigation")
	assert(keys["<CR>"] == nil, "Blink must not override normal Enter")
	assert(keys["<C-y>"][1] == "select_and_accept", "preserve optional Ctrl Y acceptance")
	assert(
		vim.deep_equal(keys["<Tab>"], { "snippet_forward", "accept", "fallback" }),
		"Tab must prioritize snippet jumps, then accept a selected item"
	)
	assert(keys["<S-Tab>"][1] == "snippet_backward", "Shift Tab must jump backward")

	local registry = require("blink.cmp.sources.snippets.default.registry").new({})
	for _, ft in ipairs({ "python", "rust", "nix", "go", "javascript", "typescript", "sh", "html", "css", "markdown" }) do
		assert(#registry:get_snippets_for_ft(ft) > 0, "no templates for " .. ft)
	end
end)
if not ok then
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd.cquit()
else
	-- Exercise real input with a completion selected while editing a placeholder.
	-- Calling the mapping with a closed menu misses acceptance stealing the jump.
	local cmp = require("blink.cmp")
	local config = require("blink.cmp.config")
	config.sources.default = { "buffer" }
	local function input(keys)
		vim.api.nvim_input(keys)
		coroutine.yield()
	end
	local function show_completion()
		cmp.show({ providers = { "buffer" } })
		assert(
			vim.wait(2000, function()
				return cmp.is_visible() and cmp.get_selected_item() ~= nil
			end, 10),
			"buffer completion must be visible and selected"
		)
	end
	local scenario = coroutine.create(function()
		input("<Esc>")
		vim.lsp.enable({ "basedpyright", "ruff", "rust_analyzer" }, false)
		for _, case in ipairs({ { "python", "def" }, { "rust", "fn" } }) do
			vim.cmd("enew!")
			vim.bo.filetype = case[1]
			config.sources.default = { "snippets" }
			input("i" .. case[2])
			cmp.show({ providers = { "snippets" } })
			assert(
				vim.wait(2000, function()
					return cmp.is_visible() and cmp.get_selected_item() ~= nil
				end, 10),
				case[1] .. " snippets must appear"
			)
			assert(cmp.get_selected_item().label == case[2], "expected template: " .. case[2])
			input("<Tab>")
			assert(config.snippets.active({ direction = 1 }), case[1] .. " snippet must expand")
			local before = vim.api.nvim_win_get_cursor(0)
			input("<Tab>")
			assert(not vim.deep_equal(before, vim.api.nvim_win_get_cursor(0)), case[1] .. " Tab must jump")
			input("<S-Tab>")
			assert(vim.deep_equal(before, vim.api.nvim_win_get_cursor(0)), case[1] .. " Shift Tab must return")
			require("luasnip").unlink_current()
			cmp.hide()
			input("<Esc>")
		end
		vim.cmd("enew!")
		config.sources.default = { "buffer" }
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "example_completion", "" })
		vim.api.nvim_win_set_cursor(0, { 2, 0 })
		input("i")
		config.snippets.expand("${1:first} ${2:second}$0")
		coroutine.yield()
		input("exa")
		show_completion()
		assert(config.snippets.active({ direction = 1 }), "typing must keep the snippet active")
		input("<Tab>")
		assert(vim.api.nvim_get_current_line() == "exa second", "Tab accepted completion instead of jumping")
		assert(vim.api.nvim_get_mode().mode == "s", "Tab must select the next placeholder")
		assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 4 }), "Tab must reach the second placeholder")
		-- Completion acceptance must still work outside a snippet.
		require("luasnip").unlink_current()
		cmp.hide()
		input("<Esc>")
		vim.cmd("enew!")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "example_completion" })
		input("oexa")
		show_completion()
		local selected = cmp.get_selected_item().label
		assert(selected == "example_completion", "expected the synthetic buffer completion")
		input("<Tab>")
		assert(
			vim.trim(vim.api.nvim_get_current_line()) == selected,
			"Tab must still accept completion outside snippets"
		)
		for _, leave_keys in ipairs({ "<Esc>o", "<Esc>A<CR>" }) do
			-- Accept the reported nested template through the real completion pipeline.
			input("<Esc>")
			vim.cmd("enew!")
			vim.bo.filetype = "python"
			config.sources.default = { "snippets" }
			input("iase")
			cmp.show({ providers = { "snippets" } })
			assert(
				vim.wait(2000, function()
					return cmp.is_visible() and cmp.get_selected_item() ~= nil
				end, 10),
				"Python snippets must appear in completion"
			)
			assert(cmp.get_selected_item().label == "ase", "expected Python ase snippet")
			input("<Tab>")
			assert(
				vim.api.nvim_get_current_line() == "self.assertEqual(expected, actual, 'message')",
				"accepting ase must expand its nested placeholders instead of deleting the trigger"
			)
			assert(config.snippets.active({ direction = 1 }), "ase placeholders must remain active")
			input("wanted<Tab>")
			input("received<Tab>")
			assert(
				vim.api.nvim_get_current_line() == "self.assertEqual(wanted, received, 'message')",
				"ase placeholder editing and Tab navigation must work"
			)
			-- Leaving a snippet before its final tabstop must release Tab ownership.
			cmp.hide()
			input(leave_keys)
			local next_line = vim.api.nvim_win_get_cursor(0)[1]
			assert(next_line == 2, "expected a new line below ase")
			input("<Tab>")
			assert(vim.api.nvim_win_get_cursor(0)[1] == next_line, "Tab jumped back into the previous ase snippet")
			assert(not config.snippets.active({ direction = 1 }), "snippet stayed active after leaving its region")
			input("ase")
			cmp.show({ providers = { "snippets" } })
			assert(
				vim.wait(2000, function()
					return cmp.is_visible() and cmp.get_selected_item() ~= nil
				end, 10),
				"next-line snippet completion must appear"
			)
			assert(cmp.get_selected_item().label == "ase", "expected another ase completion")
			input("<Tab>")
			assert(vim.api.nvim_win_get_cursor(0)[1] == next_line, "new snippet jumped to the previous line")
			assert(
				vim.trim(vim.api.nvim_get_current_line()) == "self.assertEqual(expected, actual, 'message')",
				"Tab must accept a second ase snippet on the next line"
			)
			require("luasnip").unlink_current()
		end
		print(
			"PASS: snippet collection, expansion, placeholder navigation, ordinary completion, Python ase acceptance and exit"
		)
		vim.cmd("qa!")
	end)
	-- Yield to Neovim's input loop between key presses and snippet selections.
	local function resume()
		local success, failure = coroutine.resume(scenario)
		if not success then
			io.stderr:write(tostring(failure) .. "\n")
			vim.cmd.cquit()
		elseif coroutine.status(scenario) ~= "dead" then
			vim.defer_fn(resume, 100)
		end
	end
	vim.defer_fn(resume, 100)
end
