-- A pane-scoped fullscreen lease. Zellij has a toggle, not an atomic setter:
-- serialize our own requests and recheck state, without claiming to arbitrate
-- simultaneous manual fullscreen changes made by another client.
local M = {}

function M.new(opts)
	opts = opts or {}
	local env = opts.env or vim.env
	local command = opts.command or vim.g.editor_zellij_command or "zellij"
	local run = opts.run
		or function(argv, callback)
			local ok, err = pcall(vim.system, argv, { text = true, timeout = 1500 }, vim.schedule_wrap(callback))
			if not ok then
				callback({ code = -1, stderr = tostring(err) })
			end
		end
	local size = opts.size or function()
		return vim.o.columns, vim.o.lines
	end
	local notify = opts.notify or function(err)
		vim.notify("Diff fullscreen: " .. err, vim.log.levels.WARN)
	end
	local queue, leases = {}, {}
	local busy, owned, stopping = false, false, false
	local session = env.ZELLIJ_SESSION_NAME
	local id = tonumber(((env.ZELLIJ_PANE_ID or ""):gsub("^terminal_", "")))
	local inside = env.ZELLIJ ~= nil and env.ZELLIJ ~= ""
	local target = id and ("terminal_" .. id)

	local function pump()
		if busy or #queue == 0 then
			return
		end
		busy = true
		table.remove(queue, 1)(function()
			busy = false
			pump()
		end)
	end
	local function enqueue(fn)
		table.insert(queue, fn)
		pump()
	end
	local function action(args, callback)
		local argv = { command, "--session", session, "action" }
		vim.list_extend(argv, args)
		run(argv, function(result)
			if result.code ~= 0 then
				callback(
					nil,
					vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr) or "Zellij command failed"
				)
			else
				callback(result.stdout or "")
			end
		end)
	end
	local function query(callback)
		action({ "list-panes", "--json", "--all" }, function(output, err)
			if err then
				callback(nil, err)
				return
			end
			local ok, panes = pcall(vim.json.decode, output)
			if not ok or type(panes) ~= "table" or not vim.islist(panes) then
				callback(nil, "Invalid Zellij pane list")
				return
			end
			for _, pane in ipairs(panes) do
				if type(pane) == "table" and pane.id == id and pane.is_plugin == false then
					if
						pane.is_floating
						or pane.is_suppressed
						or pane.exited
						or type(pane.is_fullscreen) ~= "boolean"
					then
						callback(nil, "Expected a live tiled Zellij pane")
					else
						-- Zellij leaves fullscreen off when there is no other pane
						-- to hide. UI bars, floats, and other tabs do not need zooming.
						local sole_pane = pane.tab_id ~= nil
						for _, other in ipairs(panes) do
							if
								other.tab_id == pane.tab_id
								and (other.id ~= pane.id or other.is_plugin)
								and not other.is_floating
								and not other.is_suppressed
								and other.is_selectable ~= false
							then
								sole_pane = false
								break
							end
						end
						callback(pane, nil, sole_pane)
					end
					return
				end
			end
			callback(nil, "The containing Zellij pane no longer exists")
		end)
	end
	local function toggle(callback)
		action({ "toggle-fullscreen", "--pane-id", target }, callback)
	end
	local function restore(callback)
		if not owned or next(leases) then
			callback()
			return
		end
		query(function(pane, err)
			if err then
				callback(err)
			elseif not pane.is_fullscreen then
				owned = false
				callback()
			else
				toggle(function(_, toggle_err)
					if not toggle_err then
						owned = false
					end
					callback(toggle_err)
				end)
			end
		end)
	end
	local function ready(callback)
		local deadline = vim.uv.hrtime() + 2e9
		local function check()
			if stopping then
				callback("Editor is exiting")
				return
			end
			query(function(pane, err, sole_pane)
				if err then
					callback(err)
					return
				end
				local columns, lines = size()
				if
					(pane.is_fullscreen or sole_pane)
					and columns == pane.pane_content_columns
					and lines == pane.pane_content_rows
				then
					callback()
				elseif vim.uv.hrtime() >= deadline then
					callback("Timed out waiting for fullscreen and Neovim's terminal resize")
				else
					vim.defer_fn(check, 25)
				end
			end)
		end
		-- Give queued SIGWINCH/UI resize events a chance to run. Size comparison
		-- also succeeds without a resize event when the pane was already maximal.
		vim.schedule(check)
	end

	local self = {}
	function self.acquire(callback)
		enqueue(function(done)
			local function finish(err)
				if stopping then
					err = err or "Editor is exiting"
				end
				if err then
					restore(function(restore_err)
						if restore_err then
							notify(restore_err)
						end
						callback(nil, err)
						done()
					end)
				else
					local lease = {}
					leases[lease] = true
					callback(lease)
					done()
				end
			end
			if stopping then
				finish("Editor is exiting")
			elseif not inside then
				finish()
			elseif not target or not session or session == "" then
				finish("Missing Zellij session or terminal pane identity")
			else
				query(function(pane, err, sole_pane)
					if err then
						finish(err)
					elseif pane.is_fullscreen or sole_pane then
						ready(finish)
					else
						-- Even a timed-out command may have reached Zellij. Re-query
						-- during rollback rather than leaving an unowned fullscreen.
						owned = true
						toggle(function(_, toggle_err)
							if toggle_err then
								finish(toggle_err)
							else
								ready(finish)
							end
						end)
					end
				end)
			end
		end)
	end
	function self.release(lease)
		enqueue(function(done)
			leases[lease] = nil
			restore(function(err)
				if err then
					notify(err)
				end
				done()
			end)
		end)
	end
	function self.shutdown()
		stopping = true
		enqueue(function(done)
			leases = {}
			restore(function(err)
				if err then
					notify(err)
				end
				done()
			end)
		end)
		-- Exit cannot keep an asynchronous cleanup alive indefinitely.
		if not vim.wait(3500, function()
			return not busy and #queue == 0
		end, 10) then
			notify("Fullscreen cleanup did not finish before exit")
		end
	end
	return self
end

return M
