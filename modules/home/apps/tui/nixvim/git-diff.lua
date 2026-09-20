local M = {}

function M.setup(opts)
	opts = opts or {}
	local zoom = opts.zoom or require("editor.zellij-zoom").new()
	local diffthis = opts.diffthis
		or function(callback)
			-- HEAD includes both staged and unstaged edits.
			require("gitsigns").diffthis("HEAD", { vertical = true, split = "aboveleft" }, callback)
		end
	local diffs = {}
	local function source_valid(diff)
		return vim.api.nvim_win_is_valid(diff.source) and vim.api.nvim_win_get_buf(diff.source) == diff.buffer
	end
	local function originals(diff)
		local result = {}
		for win, buf in pairs(diff.originals) do
			if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf and vim.wo[win].diff then
				result[win] = buf
			end
		end
		return result
	end
	local function close(tab, diff)
		diffs[tab] = nil
		for win in pairs(originals(diff)) do
			-- Never discard edits or close a window that has been repurposed.
			local ok = pcall(vim.api.nvim_win_close, win, false)
			if not ok and vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_call(win, function()
					vim.cmd.diffoff()
				end)
			end
		end
		if source_valid(diff) then
			vim.api.nvim_win_call(diff.source, function()
				vim.cmd.diffoff()
			end)
		end
		if diff.lease then
			zoom.release(diff.lease)
			diff.lease = nil
		end
	end
	local function cleanup()
		for tab, diff in pairs(diffs) do
			if
				not diff.pending
				and (not source_valid(diff) or not vim.wo[diff.source].diff or not next(originals(diff)))
			then
				close(tab, diff)
			end
		end
	end
	local group = vim.api.nvim_create_augroup("EditorGitDiff", { clear = true })
	vim.api.nvim_create_autocmd({ "WinClosed", "TabClosed", "BufWinEnter", "BufWinLeave" }, {
		group = group,
		callback = function()
			vim.schedule(cleanup)
		end,
	})
	vim.api.nvim_create_autocmd("OptionSet", {
		group = group,
		pattern = "diff",
		callback = function()
			vim.schedule(cleanup)
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = zoom.shutdown,
	})

	local self = {}
	function self.toggle()
		cleanup()
		local tab = vim.api.nvim_get_current_tabpage()
		local diff = diffs[tab]
		if diff then
			if not diff.pending then
				close(tab, diff)
				if source_valid(diff) then
					vim.api.nvim_set_current_win(diff.source)
				end
			end
			return
		end
		-- Leave manually opened vimdiff sessions alone.
		if vim.wo.diff then
			return
		end
		diff = {
			source = vim.api.nvim_get_current_win(),
			buffer = vim.api.nvim_get_current_buf(),
			originals = {},
			pending = true,
		}
		diffs[tab] = diff
		zoom.acquire(function(lease, err)
			diff.lease = lease
			if
				err
				or not source_valid(diff)
				or vim.api.nvim_get_current_win() ~= diff.source
				or vim.wo[diff.source].diff
			then
				-- Do not steal focus back after an asynchronous fullscreen request.
				diffs[tab] = nil
				if lease then
					zoom.release(lease)
				end
				if err then
					vim.notify("Diff fullscreen: " .. err, vim.log.levels.ERROR)
				end
				return
			end
			local existing = {}
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
				existing[win] = true
			end
			local function completed(diff_err)
				diff.pending = false
				if vim.api.nvim_tabpage_is_valid(tab) then
					for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
						local buf = vim.api.nvim_win_get_buf(win)
						if
							not existing[win]
							and vim.wo[win].diff
							and vim.api.nvim_buf_get_name(buf):match("^gitsigns://")
						then
							diff.originals[win] = buf
						end
					end
				end
				if diff_err or not next(diff.originals) or not source_valid(diff) then
					close(tab, diff)
				end
				if diff_err then
					vim.notify(diff_err, vim.log.levels.ERROR)
				end
				cleanup()
			end
			local ok, open_err = pcall(diffthis, completed)
			if not ok then
				completed(tostring(open_err))
			end
		end)
	end
	return self
end

return M
