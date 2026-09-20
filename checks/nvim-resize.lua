-- Run with the configured editor (uses only disposable scratch buffers):
-- nvim --headless -i NONE -c 'lua dofile("checks/nvim-resize.lua")'
local api = vim.api
local tabs = {}
local focus, floating, float_config

local function balanced(tab)
	local wins = vim.tbl_filter(function(win)
		return api.nvim_win_get_config(win).relative == ""
	end, api.nvim_tabpage_list_wins(tab))
	assert(#wins == 4, "resize must preserve the split layout")
	for _, dimension in ipairs({ api.nvim_win_get_width, api.nvim_win_get_height }) do
		local sizes = vim.tbl_map(dimension, wins)
		assert(math.max(unpack(sizes)) - math.min(unpack(sizes)) <= 1, "unbalanced splits: " .. vim.inspect(sizes))
	end
end

local steps = {
	function()
		vim.o.columns = 100
		vim.o.lines = 32
	end,
	function()
		for i = 1, 2 do
			if i > 1 then
				vim.cmd.tabnew()
			end
			vim.bo.buftype = "nofile"
			vim.bo.swapfile = false
			vim.cmd.vsplit()
			vim.cmd.split()
			vim.cmd.wincmd("h")
			vim.cmd.split()
			vim.cmd.wincmd("=")
			tabs[i] = api.nvim_get_current_tabpage()
			balanced(tabs[i])
		end
		focus = api.nvim_get_current_win()
		vim.o.columns = 200
		vim.o.lines = 60
	end,
	function()
		for _, tab in ipairs(tabs) do
			balanced(tab)
		end
		assert(api.nvim_get_current_win() == focus, "resize changed focus")
		floating = api.nvim_open_win(api.nvim_create_buf(false, true), true, {
			relative = "editor",
			row = 2,
			col = 2,
			width = 20,
			height = 5,
			style = "minimal",
		})
		float_config = api.nvim_win_get_config(floating)
		vim.o.columns = 100
		vim.o.lines = 32
	end,
	function()
		for _, tab in ipairs(tabs) do
			balanced(tab)
		end
		assert(api.nvim_get_current_win() == floating, "resize stole floating-window focus")
		assert(vim.deep_equal(api.nvim_win_get_config(floating), float_config), "resize altered floating window")
		api.nvim_win_close(floating, true)
		vim.cmd("tabonly!")
		vim.cmd("only!")
		vim.cmd.vsplit()
		vim.wo.winfixwidth = true
		api.nvim_win_set_width(0, 25)
		focus = api.nvim_get_current_win()
		vim.o.columns = 200
	end,
	function()
		assert(api.nvim_win_get_width(focus) == 25, "resize must respect winfixwidth")
		assert(api.nvim_get_current_win() == focus, "resize changed fixed-window focus")
	end,
}

local function run(index)
	local step = steps[index]
	if not step then
		print("PASS: grow/shrink balances splits across tabs, preserves focus/floats and fixed widths")
		vim.cmd("qa!")
		return
	end
	local ok, err = pcall(step)
	if not ok then
		io.stderr:write(tostring(err) .. "\n")
		vim.cmd.cquit()
		return
	end
	-- Let the real VimResized event run; do not synthesize an autocmd invocation.
	vim.defer_fn(function()
		run(index + 1)
	end, 50)
end
run(1)
