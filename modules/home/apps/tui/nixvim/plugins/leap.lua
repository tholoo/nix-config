-- Leap's visit mode restores the original window and cursor after an operation.
vim.keymap.set("o", "ir", "<Plug>(leap-visit-inner-text-object)", { desc = "Inside remote text object" })
vim.keymap.set("o", "ar", "<Plug>(leap-visit-text-object)", { desc = "Around remote text object" })
vim.keymap.set("o", "rr", function()
	return (vim.v.count == 0 and "1" or "") .. "<Plug>(leap-visit)"
end, { expr = true, desc = "Remote line(s)" })
vim.keymap.set("n", "gR", "<Plug>(leap-visit)", { desc = "Visit remote text, then return" })

local group = vim.api.nvim_create_augroup("editor_leap_copy", { clear = true })
local copied
vim.api.nvim_create_autocmd("User", {
	group = group,
	pattern = "Visit",
	callback = function()
		copied = nil
	end,
})
vim.api.nvim_create_autocmd("TextYankPost", {
	group = group,
	callback = function()
		-- Use the actual yank, including its line/block type, without reading
		-- the system clipboard or accidentally pasting an old register on cancel.
		copied = vim.v.event.operator == "y" and vim.deepcopy(vim.v.event) or nil
	end,
})
vim.api.nvim_create_autocmd("User", {
	group = group,
	pattern = "VisitDone",
	callback = function()
		local yank = copied
		copied = nil
		if not yank then
			return
		end
		local view = vim.fn.winsaveview()
		vim.api.nvim_put(yank.regcontents, yank.regtype, true, false)
		vim.fn.winrestview(view)
	end,
})
