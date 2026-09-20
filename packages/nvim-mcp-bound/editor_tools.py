"""Structured tools registered on the upstream server and its existing manager."""

import asyncio
from typing import Annotated, Any

from mcp.types import ToolAnnotations
from pydantic import Field

READ_BUFFER_SNAPSHOT = r"""
local file, first, last = ...
local function canonical(path)
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ':p'))
  return vim.uv.fs_realpath(path) or path
end
local target = canonical(file)
local buf
for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
  local name = vim.api.nvim_buf_get_name(candidate)
  if name ~= '' and vim.api.nvim_buf_is_loaded(candidate)
      and canonical(name) == target then
    if buf then
      return {ok = false, code = 'ambiguous_buffer', file = target,
        error = 'Multiple loaded buffers name this file; resolve the duplicate first'}
    end
    buf = candidate
  end
end
if not buf then
  return {ok = false, code = 'buffer_not_loaded', file = target,
    error = 'No loaded buffer for this exact file; snapshot does not read disk or load buffers'}
end
local total = vim.api.nvim_buf_line_count(buf)
if type(last) ~= 'number' then last = total end
if first > last or first < 1 or last > total then
  return {ok = false, code = 'invalid_range', file = target,
    error = 'Require 1 <= start_line <= end_line <= total_lines', total_lines = total}
end
-- One RPC invocation: no yields, autocmds, cursor moves, or buffer loading
-- between reading the text and its metadata.
return {
  ok = true, file = target, bufnr = buf,
  lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, true),
  start_line = first, end_line = last, total_lines = total,
  modified = vim.bo[buf].modified,
  changedtick = vim.api.nvim_buf_get_changedtick(buf),
}
"""

TOUR_LOAD = r"""
local path, revisions = ...
local loaded, tour = pcall(require, 'tour')
if not loaded or type(tour) ~= 'table' or type(tour.load_checked) ~= 'function' then
  return {ok = false, persisted = false, displayed = false,
    errors = {{code = 'tour_unavailable',
      message = 'This editor needs tour.nvim with load_checked; install/update and restart the editor'}}}
end
local opts = {}
if type(revisions) == 'table' then opts.revisions = revisions end
return tour.load_checked(path, opts)
"""


async def exec_lua(manager, code, *args):
    """Serialize with upstream tools; never replay a potentially completed load."""
    async with manager._lock:
        if manager._nvim is None:
            if manager._socket_path is not None:
                await manager._reconnect_unlocked()
            else:
                error = await manager._auto_connect_unlocked()
                if error is not None:
                    raise RuntimeError(error.get("error", str(error)))
        operation = asyncio.create_task(
            asyncio.to_thread(manager._nvim.exec_lua, code, *args)
        )
        try:
            try:
                return await asyncio.shield(operation)
            except asyncio.CancelledError:
                # A thread cannot be cancelled. Retain the shared lock until its
                # RPC settles, so another tool cannot consume this response.
                await operation
                raise
        except (Exception, asyncio.CancelledError):
            # Discard a possibly desynchronized RPC stream. A future request can
            # reconnect to the same socket, but this request is never repeated.
            manager._nvim.close()
            manager._nvim = None
            raise


def register(server):
    """Use server.manager dynamically, including its workspace socket binding."""

    @server.mcp.tool(
        structured_output=True,
        annotations=ToolAnnotations(readOnlyHint=True, openWorldHint=False),
    )
    async def read_buffer_snapshot(
        file: Annotated[str, Field(min_length=1)],
        start_line: Annotated[int, Field(ge=1, strict=True)] = 1,
        end_line: Annotated[int, Field(ge=1, strict=True)] | None = None,
    ) -> dict[str, Any]:
        """Read raw lines and metadata from an already-loaded buffer, read-only.

        Prefer this to numbered buffer reads when generating byte ranges. file
        is an exact path (relative to the editor cwd or absolute), not a pattern.
        Returns {ok, file, bufnr, lines, start_line, end_line, total_lines,
        modified, changedtick} as structured content. lines have no prefixes.
        Optional line bounds are 1-based, inclusive, and strict (not clamped).
        Errors return {ok:false, code, error}; no disk fallback or buffer loading.

        Text and metadata are captured in one RPC. Compare bufnr and changedtick
        within the same editor session to detect edits; they are not durable
        revisions and do not themselves guard a later operation. For tour_load,
        use content revisions from tour.read_source, including for unopened files.
        """
        return await exec_lua(
            server.manager, READ_BUFFER_SNAPSHOT, file, start_line, end_line
        )

    @server.mcp.tool(
        structured_output=True,
        annotations=ToolAnnotations(
            readOnlyHint=False,
            destructiveHint=False,
            idempotentHint=False,
            openWorldHint=False,
        ),
    )
    async def tour_load(
        path: Annotated[str, Field(min_length=1)],
        revisions: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        """Validate, persist, and display a tour in the connected editor (mutation).

        path names a schema-v1 tour JSON file on the editor's filesystem. Prefer
        an absolute path. revisions optionally maps source paths to inspection
        tokens from require('tour').read_source; pass those tokens unchanged.
        Calls tour.load_checked and returns its receipt as structured content:
        {ok, id?, title?, current_step?, step_count?, persisted, displayed, errors}.
        Success requires ok, persisted, and displayed all true. persisted=null
        means an attempted write was unconfirmed; false means no save attempted.

        On stale_source reread and repair locations, rather than replacing tokens
        just to bypass the check. Preserve the tour ID when repairing errors.
        No source buffers are saved. Transport errors are MCP errors, not receipts;
        completion is unknown. This tool never automatically replays a failed RPC.
        """
        return await exec_lua(server.manager, TOUR_LOAD, path, revisions)
