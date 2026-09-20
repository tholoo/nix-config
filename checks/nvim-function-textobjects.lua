-- Run with the configured editor in a disposable XDG environment:
-- nvim --headless -i NONE -c 'lua dofile("checks/nvim-function-textobjects.lua")'
-- Exercises real parsers, queries, and operator mappings on scratch buffers.
local ok, err = pcall(function()
	vim.opt.clipboard = {} -- Keep synthetic yanks off the desktop clipboard.
	local ai = require("mini.ai")
	assert(type(ai.config.custom_textobjects.f) == "function", "function definition object missing")
	assert(ai.config.custom_textobjects.F, "function-call object must be preserved")
	assert(ai.config.n_lines == 100, "do not widen unrelated textobject searches")

	local function normalized(text)
		local lines = vim.split(text, "\n", { plain = true })
		for i, line in ipairs(lines) do
			lines[i] = vim.trim(line)
		end
		while lines[1] == "" do
			table.remove(lines, 1)
		end
		while lines[#lines] == "" do
			table.remove(lines)
		end
		return table.concat(lines, "\n")
	end
	local function fixture(ft, lines, cursor)
		vim.cmd("enew!")
		vim.bo.buftype = "nofile" -- Do not start language servers for fixtures.
		vim.bo.swapfile = false
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
		vim.bo.filetype = ft
		local lang = vim.treesitter.language.get_lang(ft)
		assert(vim.treesitter.query.get(lang, "textobjects"), "missing textobject queries for " .. ft)
		vim.treesitter.get_parser(0, lang):parse()
		vim.api.nvim_win_set_cursor(0, cursor)
	end
	local function yank(keys)
		vim.fn.setreg("z", "UNTOUCHED")
		vim.cmd.normal({ '"z' .. keys, bang = false })
		assert(
			vim.wait(1000, function()
				return vim.fn.getreg("z") ~= "UNTOUCHED"
			end, 10),
			keys .. " did not yank"
		)
		return normalized(vim.fn.getreg("z"))
	end
	local function check(ft, body, cursor)
		local lines = vim.list_extend(vim.deepcopy(body), { "", "// sentinel outside function" })
		if ft == "python" then
			lines[#lines] = "# sentinel outside function"
		elseif ft == "lua" then
			lines[#lines] = "-- sentinel outside function"
		end
		fixture(ft, lines, cursor)
		assert(yank("yaf") == normalized(table.concat(body, "\n")), ft .. " yaf must include the whole function only")
		vim.api.nvim_win_set_cursor(0, cursor)
		local inner = vim.list_slice(body, 2, ft == "python" and #body or #body - 1)
		assert(
			yank("yif") == normalized(table.concat(inner, "\n")),
			ft .. " yif must include the whole body, not the nested block"
		)
	end

	check("python", {
		"def example(value):",
		"    if value:",
		"        value += 1",
		"    return value",
	}, { 3, 9 })
	check("rust", {
		"fn example(mut value: i32) -> i32 {",
		"    if value > 0 {",
		"        value += 1;",
		"    }",
		"    value",
		"}",
	}, { 3, 9 })
	check("javascript", { "function example(value) {", "    return value + 1;", "}" }, { 2, 12 })
	check("typescript", { "function example(value: number): number {", "    return value + 1;", "}" }, { 2, 12 })
	check("go", { "func example(value int) int {", "    return value + 1", "}" }, { 2, 12 })
	check("c", { "int example(int value) {", "    return value + 1;", "}" }, { 2, 12 })
	check("lua", { "local function example(value)", "    return value + 1", "end" }, { 2, 12 })

	-- An inner definition must win over its containing outer definition.
	fixture("python", {
		"def outer():",
		"    def inner():",
		"        return 1",
		"    return inner()",
	}, { 3, 10 })
	assert(yank("yaf") == "def inner():\nreturn 1", "nested function selection must choose the nearest definition")

	-- Both boundaries lie beyond the old 100-line neighborhood.
	local long = { "fn long_function() {" }
	for _ = 1, 260 do
		table.insert(long, "    let value = 1;")
	end
	table.insert(long, "}")
	check("rust", long, { 131, 10 })

	fixture("python", { "result = calculate(first, second)" }, { 1, 21 })
	assert(yank("yaF") == "calculate(first, second)", "uppercase F must preserve function calls")
	vim.api.nvim_win_set_cursor(0, { 1, 21 })
	assert(yank("yiF") == "first, second", "uppercase inner F must preserve call arguments")
end)
if not ok then
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd.cquit()
else
	print(
		"PASS: function definition/body yanks across seven languages, nested/long functions, and preserved call objects"
	)
	vim.cmd("qa!")
end
