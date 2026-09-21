-- One read-only RPC: the text, cursor and active selection describe one instant.
local max_bytes, max_lines = ...
local api = vim.api
local buf, win = api.nvim_get_current_buf(), api.nvim_get_current_win()
local cursor, mode = api.nvim_win_get_cursor(win), vim.fn.mode()
local total = api.nvim_buf_line_count(buf)
local function file(b)
  local name = api.nvim_buf_get_name(b)
  if name == '' then return '' end
  return vim.uv.fs_realpath(name) or vim.fs.normalize(name)
end
local result = {
  version = 1, editor_pid = vim.fn.getpid(), cwd = vim.fn.getcwd(), mode = mode,
  bufnr = buf, window = win, file = file(buf), filetype = vim.bo[buf].filetype,
  modified = vim.bo[buf].modified, changedtick = api.nvim_buf_get_changedtick(buf),
  total_lines = total, cursor = { line = cursor[1], byte_col = cursor[2] },
  viewport = { first = vim.fn.line('w0'), last = vim.fn.line('w$') },
  buffers = {}, lines = {},
}
local buffers = api.nvim_list_bufs()
for _, b in ipairs(buffers) do
  if api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted and vim.bo[b].buftype == '' then
    if #result.buffers == 100 then result.buffers_omitted = true; break end
    table.insert(result.buffers, { bufnr = b, file = file(b), modified = vim.bo[b].modified })
  end
end
-- Prompt, terminal, help and plugin buffers are not implicit source attachments.
if vim.bo[buf].buftype ~= '' then
  result.omitted = true
  result.reason = 'Active window is not a regular editing buffer'
  return result
end

if mode == 'v' or mode == 'V' or mode == '\22' then
  local anchor = vim.fn.getpos('v')
  result.selection = {
    kind = mode == 'v' and 'character' or (mode == 'V' and 'line' or 'block'),
    anchor = { line = anchor[2], byte_col = anchor[3] - 1 },
    cursor = result.cursor, exclusive = vim.o.selection == 'exclusive',
    -- Virtual columns preserve block selection semantics across tabs/wide text.
    anchor_vcol = vim.fn.virtcol('v'), cursor_vcol = vim.fn.virtcol('.'),
  }
end

local used_bytes, seen = 0, {}
local function continuation(byte) return byte and byte >= 128 and byte < 192 end
local function add_range(first, last)
  for line = math.max(1, first), math.min(total, last) do
    if #result.lines >= max_lines or used_bytes >= max_bytes - 1 then break end
    if not seen[line] then
      seen[line] = true
      local text = api.nvim_buf_get_lines(buf, line - 1, line, true)[1]
      local available = max_bytes - used_bytes - 1
      local start = 1
      if #text > available and line == cursor[1] then
        start = math.max(1, cursor[2] - math.floor(available / 2) + 1)
      end
      while start > 1 and continuation(text:byte(start)) do start = start - 1 end
      local finish = math.min(#text, start + available - 1)
      while finish >= start and continuation(text:byte(finish + 1)) do finish = finish - 1 end
      local excerpt = text:sub(start, finish)
      local partial = start > 1 or finish < #text
      table.insert(result.lines, {
        line = line, text = excerpt, byte_col = start - 1, truncated = partial,
      })
      used_bytes = used_bytes + #excerpt + 1
      if partial then result.omitted = true end
    end
  end
end

if total <= max_lines and api.nvim_buf_get_offset(buf, total) <= max_bytes then
  add_range(1, total)
else
  result.omitted = true
  add_range(cursor[1], cursor[1])
  -- Include modest selections in full; for huge selections prioritize the
  -- cursor endpoint and show the anchor too, rather than consuming the budget.
  local selection = result.selection
  if selection then
    local first = math.min(selection.anchor.line, cursor[1])
    local last = math.max(selection.anchor.line, cursor[1])
    if last - first < math.floor(max_lines / 2) then add_range(first, last) end
  end
  add_range(cursor[1] - 40, cursor[1] + 40)
  if selection then add_range(selection.anchor.line - 8, selection.anchor.line + 8) end
  add_range(result.viewport.first, result.viewport.last)
end
table.sort(result.lines, function(a, b) return a.line < b.line end)
result.omitted = result.omitted or #result.lines < total
result.text_bytes = used_bytes
return result
