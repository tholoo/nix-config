-- Run with the built editor in a disposable XDG environment:
-- nvim --headless -i NONE -c 'lua dofile("checks/nvim-snippets.lua")'
-- Uses Blink's real snippet provider without starting a language server.
local ok, err = pcall(function()
	local config = require("blink.cmp.config")
	assert(config.snippets.preset == "default", "keep Neovim's native snippet engine")
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
		vim.deep_equal(keys["<Tab>"], { "accept", "snippet_forward", "fallback" }),
		"Tab must accept only a selected item, then try a snippet jump"
	)
	assert(keys["<S-Tab>"][1] == "snippet_backward", "Shift Tab must jump backward")

	local registry = require("blink.cmp.sources.snippets.default.registry").new({})
	for _, ft in ipairs({ "python", "rust", "nix", "go", "javascript", "typescript", "sh", "html", "css", "markdown" }) do
		assert(#registry:get_snippets_for_ft(ft) > 0, "no templates for " .. ft)
	end

	for _, ft in ipairs({ "python", "rust" }) do
		local opts = vim.deepcopy(config.sources.providers.snippets.opts or {})
		opts.get_filetype = function()
			return ft
		end
		local source = require("blink.cmp.sources.snippets.default").new(opts)
		local items
		source:get_completions({
			id = ft == "python" and 1 or 2,
			cursor = { 1, 0 },
			bounds = { start_col = 1 },
			get_line = function()
				return ""
			end,
		}, function(result)
			items = result.items
		end)
		assert(items and #items > 0, "Blink did not offer " .. ft .. " snippets")
		-- Pick the documented templates deterministically. Table iteration order
		-- varies, and some collection entries use unsupported nested placeholders.
		local trigger = ft == "python" and "def" or "fn"
		local candidate
		for _, item in ipairs(items) do
			if item.label == trigger then
				candidate = item
				break
			end
		end
		assert(candidate, "missing " .. ft .. " template: " .. trigger)
		assert(candidate.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet)
		vim.cmd.enew()
		require("blink.cmp.keymap.apply").keymap_to_current_buffer(keys)
		config.snippets.expand(candidate.insertText)
		assert(vim.snippet.active({ direction = 1 }), ft .. " snippet did not activate")
		local before = vim.api.nvim_win_get_cursor(0)
		-- With no completion selected, the actual Tab mapping must jump instead.
		vim.fn.maparg("<Tab>", "i", false, true).callback()
		assert(
			vim.wait(1000, function()
				return not vim.deep_equal(before, vim.api.nvim_win_get_cursor(0))
			end, 10),
			ft .. " Tab did not jump forward"
		)
		assert(vim.snippet.active({ direction = -1 }), ft .. " cannot jump backward")
		vim.fn.maparg("<S-Tab>", "s", false, true).callback()
		assert(
			vim.wait(1000, function()
				return vim.deep_equal(before, vim.api.nvim_win_get_cursor(0))
			end, 10),
			ft .. " Shift Tab did not jump backward"
		)
		vim.snippet.stop()
		vim.cmd("enew!")
	end
end)
if not ok then
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd.cquit()
else
	print("PASS: snippet collection coverage, Python/Rust Blink completions, native expansion and placeholder jumps")
	vim.cmd("qa!")
end
