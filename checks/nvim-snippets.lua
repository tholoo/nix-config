-- Run with the built editor in a disposable XDG environment:
-- nvim --headless -i NONE -c 'lua dofile("checks/nvim-snippets.lua")'
-- Uses Blink's real snippet provider without starting a language server.
local ok, err = pcall(function()
	local config = require("blink.cmp.config")
	assert(config.snippets.preset == "default", "keep Neovim's native snippet engine")
	assert(config.keymap.preset == "default", "completion key preset changed")
	assert(vim.tbl_contains(config.sources.default, "snippets"), "snippet source missing")
	local keys = require("blink.cmp.keymap.presets").default
	assert(keys["<C-y>"][1] == "select_and_accept", "Ctrl Y must accept")
	assert(keys["<Tab>"][1] == "snippet_forward", "Tab must jump forward")
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
		local candidate
		for _, item in ipairs(items) do
			if item.insertText:find("${1:", 1, true) and item.insertText:find("${2:", 1, true) then
				candidate = item
				break
			end
		end
		assert(candidate, "no multi-placeholder snippet for " .. ft)
		assert(candidate.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet)
		vim.cmd.enew()
		config.snippets.expand(candidate.insertText)
		assert(vim.snippet.active({ direction = 1 }), ft .. " snippet did not activate")
		local before = vim.api.nvim_win_get_cursor(0)
		config.snippets.jump(1)
		assert(not vim.deep_equal(before, vim.api.nvim_win_get_cursor(0)), ft .. " placeholder jump did not move")
		assert(vim.snippet.active({ direction = -1 }), ft .. " cannot jump backward")
		config.snippets.jump(-1)
		assert(vim.deep_equal(before, vim.api.nvim_win_get_cursor(0)), ft .. " backward jump did not return")
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
