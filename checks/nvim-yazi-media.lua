-- Run with the built editor in a disposable XDG environment:
-- nvim --headless -i NONE -c 'lua dofile("checks/nvim-yazi-media.lua")'
-- Uses synthetic media headers and captures launches without playing video.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local jobstart = vim.fn.jobstart
local ok, err = pcall(function()
	local video = root .. "/sample 'video'.mp4"
	local second = root .. "/video with spaces.mkv"
	local text = root .. "/notes.mp4"
	local header = string.char(0, 0, 0, 24) .. "ftypisom" .. string.char(0, 0, 2, 0) .. "isomiso2"
	for _, path in ipairs({ video, second }) do
		local handle = assert(io.open(path, "wb"))
		handle:write(header)
		handle:close()
	end
	vim.fn.writefile({ "plain text despite the video extension" }, text)
	local config = require("yazi").config
	local starts = {}
	vim.fn.jobstart = function(command, opts)
		starts[#starts + 1] = { command = command, opts = opts }
		return 42
	end
	vim.cmd.enew()
	local original = vim.api.nvim_get_current_buf()
	config.open_file_function(video)
	assert(vim.api.nvim_get_current_buf() == original, "video opened in the editor")
	assert(#starts == 1 and starts[1].command[2] == "--" and starts[1].command[3] == video, "wrong player arguments")
	assert(starts[1].command[1]:match("/bin/mpv$") and starts[1].opts.detach, "configured mpv must run independently")
	assert(vim.fn.executable(starts[1].command[1]) == 1, "configured player missing")
	config.open_file_function(text)
	assert(vim.api.nvim_buf_get_name(0) == text and #starts == 1, "non-video file must still open in editor")
	config.hooks.yazi_opened_multiple_files({ video, text, second })
	assert(
		#starts == 2 and vim.deep_equal({ unpack(starts[2].command, 3) }, { video, second }),
		"videos should form one playlist"
	)
	assert(vim.deep_equal(vim.fn.argv(), { text }), "mixed selection opened video in editor")
	local current = vim.api.nvim_get_current_buf()
	config.hooks.yazi_opened_multiple_files({ video, second })
	assert(#starts == 3 and vim.api.nvim_get_current_buf() == current, "video-only selection changed editor buffer")
	print("PASS: real MIME detection, video routing, ordinary files, mixed selections, playlist and literal filenames")
end)
vim.fn.jobstart = jobstart
vim.fn.delete(root, "rf")
if not ok then
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd.cquit()
else
	vim.cmd("qa!")
end
