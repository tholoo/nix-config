-- Run with the configured editor in an isolated XDG environment:
-- nvim --headless -i NONE -c 'lua dofile("checks/nvim-rust-diagnostics.lua")'
local ok, err = pcall(function()
	vim.cmd.enew()
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = { '#[cfg(feature = "example")]', "mod example {", "    pub fn example() {}", "}" }
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	local ns = vim.api.nvim_create_namespace("rust-inactive-fixture")
	local diagnostic = {
		lnum = 0,
		col = 0,
		end_lnum = 3,
		end_col = 1,
		severity = vim.diagnostic.severity.HINT,
		source = "rust-analyzer",
		code = "inactive-code",
		message = "code is inactive due to #[cfg] directives: example is disabled",
		_tags = { unnecessary = true },
		user_data = { lsp = { data = { fixture = true } } },
	}
	local function marks()
		local underline_ns = vim.diagnostic.get_namespace(ns).user_data.underline_ns
		return vim.api.nvim_buf_get_extmarks(bufnr, underline_ns, 0, -1, { details = true })
	end
	local function assert_header()
		local rendered = marks()
		assert(#rendered > 0, "inactive marker missing")
		for _, mark in ipairs(rendered) do
			assert(mark[2] == 0 and mark[4].end_row == 0, "inactive highlight covers code body")
			assert(mark[4].end_col == #lines[1], "marker does not cover header")
			local groups = vim.inspect(mark[4].hl_group)
			assert(groups:find("DiagnosticUnderlineHint", 1, true), "inactive hint missing")
			assert(not groups:find("DiagnosticUnnecessary", 1, true), "inactive code is dimmed")
		end
	end
	for _, code in ipairs({ "inactive-code", "inactive_code" }) do
		diagnostic.code = code
		vim.diagnostic.set(ns, bufnr, { diagnostic })
		assert_header()
		local stored = vim.diagnostic.get(bufnr, { namespace = ns })[1]
		assert(stored.end_lnum == 3 and stored._tags.unnecessary, "diagnostic range/tags mutated")
		assert(stored.message == diagnostic.message, "message changed")
		assert(vim.deep_equal(stored.user_data, diagnostic.user_data), "code action data changed")
		vim.diagnostic.hide(ns, bufnr)
		assert(#marks() == 0, "hiding diagnostics left a marker")
		vim.diagnostic.show(ns, bufnr)
		assert_header()
	end
	for _, change in ipairs({ { code = "unused-variable" }, { source = "other-server" } }) do
		vim.diagnostic.set(ns, bufnr, { vim.tbl_extend("force", diagnostic, change) })
		local found_body, found_dim = false, false
		for _, mark in ipairs(marks()) do
			found_body = found_body or mark[4].end_row > 0
			found_dim = found_dim or vim.inspect(mark[4].hl_group):find("DiagnosticUnnecessary", 1, true) ~= nil
		end
		assert(found_body and found_dim, "unrelated diagnostic rendering changed")
	end
	vim.diagnostic.reset(ns, bufnr)
	assert(#marks() == 0, "clearing diagnostics left a marker")
	print("PASS: readable inactive Rust blocks, header marker, preserved diagnostics, hide/show, unrelated diagnostics")
end)
if ok then
	vim.cmd("qa!")
else
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd("cquit 1")
end
