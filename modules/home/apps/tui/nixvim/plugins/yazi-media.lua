local M = {}

-- Return editor selections and send videos to a single mpv playlist.
function M.open(files, file_command, mpv_command)
	local editor_files, videos = {}, {}
	for _, path in ipairs(files) do
		local result = vim.system({ file_command, "--brief", "--mime-type", "--dereference", "--", path }, {
			text = true,
		}):wait()
		if result.code == 0 and vim.trim(result.stdout or ""):match("^video/") then
			table.insert(videos, path)
		else
			table.insert(editor_files, path)
		end
	end
	if #videos > 0 then
		local command = { mpv_command, "--" }
		vim.list_extend(command, videos)
		if vim.fn.jobstart(command, { detach = true }) <= 0 then
			vim.notify("Could not start mpv for the selected videos", vim.log.levels.ERROR)
		end
	end
	return editor_files
end

return M
