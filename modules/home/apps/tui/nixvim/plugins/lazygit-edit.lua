-- LazyGit supplies shell-quoted filenames; send them as RPC data, never Lua code.
-- Read the inherited endpoint directly: "$NVIM" is literal text in Nushell.
local address = vim.env.NVIM
assert(address and address ~= "", "missing parent Neovim socket (NVIM)")
local connected, channel = pcall(vim.fn.sockconnect, "pipe", address, { rpc = true })
assert(connected and channel > 0, "could not connect to parent Neovim at " .. address .. ": " .. tostring(channel))
local filename = vim.fn.fnamemodify(assert(arg[1], "missing filename"), ":p")
local ok, err = pcall(
	vim.rpcrequest,
	channel,
	"nvim_exec_lua",
	[[
	return require("editor.lazygit").edit(...)
]],
	{ filename, tonumber(arg[2]) }
)
vim.fn.chanclose(channel)
if not ok then
	error(err)
end
