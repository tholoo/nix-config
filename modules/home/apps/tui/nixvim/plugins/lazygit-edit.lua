-- LazyGit supplies shell-quoted arguments; send filenames as RPC data, never Lua code.
local channel = vim.fn.sockconnect("pipe", assert(arg[1], "missing Neovim socket"), { rpc = true })
assert(channel > 0, "could not connect to the parent Neovim")
local filename = vim.fn.fnamemodify(assert(arg[2], "missing filename"), ":p")
local ok, err = pcall(
	vim.rpcrequest,
	channel,
	"nvim_exec_lua",
	[[
	return require("editor.lazygit").edit(...)
]],
	{ filename, tonumber(arg[3]) }
)
vim.fn.chanclose(channel)
if not ok then
	error(err)
end
