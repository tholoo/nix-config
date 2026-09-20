"""Real stdio MCP -> private headless Neovim -> pinned tour.nvim integration."""

import json
import os
import subprocess
import tempfile
import time
import unittest
from functools import wraps
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from nvim_mcp.client import NvimClient


def with_session(test):
    # AnyIO cancel scopes must enter and exit in the same asyncio task;
    # unittest runs asyncSetUp/test/cleanup in separate tasks.
    @wraps(test)
    async def run(self):
        async with (
            stdio_client(
                StdioServerParameters(command=os.environ["MCP_COMMAND"], env=self.env)
            ) as channels,
            ClientSession(*channels) as self.session,
        ):
            await self.session.initialize()
            connected = await self.session.call_tool("connect", {})
            self.assertFalse(connected.is_error)
            await test(self)

    return run


@unittest.skipUnless(
    os.environ.get("NVIM_TEST"), "set NVIM_TEST, TOUR_PLUGIN and MCP_COMMAND"
)
class ProtocolTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.socket = str(self.root / "nvim.sock")
        env = {
            "PATH": os.environ.get("PATH", ""),
            "HOME": str(self.root),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "XDG_DATA_HOME": str(self.root / "data"),
            "XDG_STATE_HOME": str(self.root / "state"),
            "XDG_CACHE_HOME": str(self.root / "cache"),
            "TOUR_PLUGIN": os.environ["TOUR_PLUGIN"],
            "DEV_NVIM_SOCKET": self.socket,
        }
        self.env = env
        self.log = self.enterContext(open(self.root / "nvim.log", "w+"))
        self.addCleanup(self.stop_editor)
        self.start_editor()

    def start_editor(self):
        self.editor = subprocess.Popen(
            [
                os.environ["NVIM_TEST"],
                "--headless",
                "-n",  # Disposable restart fixtures must not leave recovery swap files.
                "-u",
                "NONE",
                "-i",
                "NONE",
                "--listen",
                self.socket,
                "--cmd",
                "lua vim.opt.rtp:prepend(vim.env.TOUR_PLUGIN)",
            ],
            cwd=self.root,
            env=self.env,
            stdin=subprocess.DEVNULL,
            stdout=self.log,
            stderr=self.log,
        )
        deadline = time.monotonic() + 10
        while not Path(self.socket).exists():
            if self.editor.poll() is not None or time.monotonic() > deadline:
                self.log.seek(0)
                self.fail("headless fixture failed: " + self.log.read())
            time.sleep(0.01)
        self.rpc = NvimClient.connect(self.socket)
        self.addCleanup(self.rpc.close)

    def stop_editor(self):
        if self.editor.poll() is None:
            self.editor.terminate()
            try:
                self.editor.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.editor.kill()
                self.editor.wait()

    async def tool(self, name, **kwargs):
        result = await self.session.call_tool(name, kwargs)
        self.assertFalse(result.is_error, str(result))
        self.assertIsInstance(result.structured_content, dict, str(result))
        return result.structured_content

    async def upstream_state(self, name):
        # Upstream state tools return JSON text, unlike our structured snapshots.
        result = await self.session.call_tool(name, {})
        self.assertFalse(result.is_error, str(result))
        return json.loads(result.content[0].text)

    def buffer(self, file="fixture.lua", lines=None):
        lines = lines if lines is not None else ["local λ = 1", "\treturn λ", ""]
        (self.root / file).write_text("disk content\n")
        buf = self.rpc.exec_lua(
            """
            local file, lines = ...
            local b = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(b, file)
            vim.api.nvim_buf_set_lines(b, 0, -1, true, lines)
            return b
        """,
            str(self.root / file),
            lines,
        )
        return buf, lines

    def tour_file(self, file="fixture.lua"):
        data = {
            "version": 1,
            "id": "fixture-tour",
            "title": "Fixture",
            "project_root": str(self.root),
            "steps": [
                {
                    "title": "One",
                    "location": {
                        "file": file,
                        "range": {
                            "start": {"line": 1, "col": 0},
                            "end": {"line": 1, "col": 5},
                        },
                    },
                }
            ],
        }
        # Quotes/backslashes in a real filename exercise RPC argument handling.
        path = self.root / "tour'\"\\.json"
        path.write_text(json.dumps(data))
        return path, data

    @with_session
    async def test_tool_discovery_and_annotations(self):
        tools = {tool.name: tool for tool in (await self.session.list_tools()).tools}
        for name in ("tour_load", "read_buffer_snapshot"):
            self.assertIsNotNone(tools[name].output_schema)
        self.assertTrue(tools["read_buffer_snapshot"].annotations.read_only_hint)
        self.assertFalse(tools["tour_load"].annotations.read_only_hint)
        self.assertFalse(tools["tour_load"].annotations.idempotent_hint)
        self.assertIn("read_full_buf", tools)
        self.assertIn("send_command", tools)

    @with_session
    async def test_raw_snapshot_exact_paths_ranges_and_no_mutation(self):
        file = "odd['\"\\].lua"
        buf, lines = self.buffer(file)
        state = "return {vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0), vim.api.nvim_list_bufs()}"
        before = self.rpc.exec_lua(state)
        snap = await self.tool("read_buffer_snapshot", file=file)
        self.assertEqual(snap["lines"], lines)
        self.assertEqual(snap["bufnr"], buf)
        self.assertTrue(snap["modified"])
        self.assertEqual(snap["file"], str(self.root / file))
        self.assertEqual(snap["total_lines"], 3)
        self.assertEqual(
            snap["changedtick"],
            self.rpc.exec_lua("return vim.api.nvim_buf_get_changedtick(...)", buf),
        )
        part = await self.tool(
            "read_buffer_snapshot", file=file, start_line=2, end_line=2
        )
        self.assertEqual(part["lines"], [lines[1]])
        self.assertEqual((part["start_line"], part["end_line"]), (2, 2))
        for first, last in ((3, 2), (1, 4), (5, 6)):
            invalid = await self.tool(
                "read_buffer_snapshot", file=file, start_line=first, end_line=last
            )
            self.assertEqual(invalid["code"], "invalid_range")
        missing = await self.tool("read_buffer_snapshot", file=".*lua")
        self.assertEqual(missing["code"], "buffer_not_loaded")
        (self.root / "unopened.lua").write_text("return 1\n")
        missing = await self.tool("read_buffer_snapshot", file="unopened.lua")
        self.assertEqual(missing["code"], "buffer_not_loaded")
        self.assertEqual(self.rpc.exec_lua(state), before)
        again = await self.tool("read_buffer_snapshot", file=file)
        self.assertEqual(again, snap)
        self.assertEqual((self.root / file).read_text(), "disk content\n")
        self.rpc.exec_lua(
            "vim.api.nvim_buf_set_lines(...)", buf, 0, 1, True, ["changed"]
        )
        after = await self.tool("read_buffer_snapshot", file=file)
        self.assertGreater(after["changedtick"], snap["changedtick"])
        self.assertEqual(after["lines"][0], "changed")

    @with_session
    async def test_editor_target_context_preserves_visual_selection_and_unsaved_text(self):
        buf, lines = self.buffer(lines=["first function", "second function", "tail"])
        self.rpc.exec_lua("vim.api.nvim_set_current_buf(...)", buf)
        state = """return {vim.fn.mode(), vim.api.nvim_get_current_win(),
            vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0),
            vim.fn.getpos('v'), vim.api.nvim_buf_get_changedtick(0)}"""
        for keys, mode in (
            ("gg0vjl", "visual"),
            ("gg0Vj", "visual_line"),
            ("gg0" + chr(22) + "jl", "visual_block"),
        ):
            self.rpc.exec_lua("vim.cmd.normal({args = {...}, bang = true})", keys)
            before = self.rpc.exec_lua(state)
            full = await self.upstream_state("get_state")
            active = full["windows"][0]
            self.assertEqual(full["mode"], mode)
            self.assertEqual(active["file"], "fixture.lua")
            self.assertTrue(active["modified"])
            self.assertEqual(active["line"], 2)
            self.assertEqual(active["selection"]["start_line"], 1)
            self.assertEqual(active["selection"]["end_line"], 2)
            self.assertEqual(active["selection"]["mode"], mode)
            brief = await self.upstream_state("get_state_brief")
            self.assertNotIn("selection", brief["active_window"])
            snap = await self.tool("read_buffer_snapshot", file=active["file"])
            self.assertEqual(snap["lines"], lines)
            self.assertTrue(snap["modified"])
            self.assertEqual(self.rpc.exec_lua(state), before)
            self.rpc.exec_lua(
                "vim.cmd.normal({args = {string.char(27)}, bang = true})"
            )
        normal = await self.upstream_state("get_state")
        self.assertEqual(normal["mode"], "normal")
        self.assertNotIn(
            "selection", normal["windows"][0], "old visual marks are not active context"
        )
        self.assertEqual((self.root / "fixture.lua").read_text(), "disk content\n")

    @with_session
    async def test_disconnected_editor_and_restart_keep_the_assigned_socket(self):
        self.buffer()
        await self.tool("read_buffer_snapshot", file="fixture.lua")
        self.stop_editor()
        self.rpc.close()
        disconnected = await self.session.call_tool(
            "read_buffer_snapshot", {"file": "fixture.lua"}
        )
        self.assertTrue(disconnected.is_error)
        # A real replacement editor at the same socket must be usable by the
        # existing MCP process, without inheriting the old buffer snapshot.
        self.start_editor()
        self.buffer(lines=["replacement editor"])
        snapshot = await self.tool("read_buffer_snapshot", file="fixture.lua")
        self.assertEqual(snapshot["lines"], ["replacement editor"])

    @with_session
    async def test_empty_buffer_and_argument_validation(self):
        self.buffer(lines=[""])
        snap = await self.tool("read_buffer_snapshot", file="fixture.lua")
        self.assertEqual(snap["lines"], [""])
        for arguments in ({"start_line": 0}, {"end_line": -1}, {"start_line": 1.5}):
            result = await self.session.call_tool(
                "read_buffer_snapshot", {"file": "fixture.lua", **arguments}
            )
            self.assertTrue(result.is_error)

    @with_session
    async def test_tour_receipt_stale_rejection_and_all_ranges(self):
        buf, _lines = self.buffer()
        path, data = self.tour_file()
        source = self.rpc.exec_lua(
            "return require('tour').read_source(...)", "fixture.lua"
        )
        revisions = {source["file"]: source["revision"]}
        receipt = await self.tool("tour_load", path=str(path), revisions=revisions)
        for field in ("ok", "persisted", "displayed"):
            self.assertIs(receipt[field], True, receipt)
        self.assertEqual(receipt["id"], "fixture-tour")
        self.assertEqual((receipt["current_step"], receipt["step_count"]), (1, 1))
        self.assertEqual(receipt["errors"], [])
        saved = list((self.root / "state").rglob("fixture-tour.json"))
        self.assertEqual(len(saved), 1)
        saved_content = saved[0].read_text()
        self.rpc.exec_lua(
            "vim.api.nvim_buf_set_lines(...)", buf, 0, 1, True, ["changed"]
        )
        failed = await self.tool("tour_load", path=str(path), revisions=revisions)
        self.assertFalse(failed["ok"])
        self.assertFalse(failed["persisted"])
        self.assertIn("stale_source", [e["code"] for e in failed["errors"]])
        self.assertEqual(saved[0].read_text(), saved_content)
        self.assertEqual((self.root / "fixture.lua").read_text(), "disk content\n")
        data["steps"].append(
            {
                "title": "Bad",
                "location": {
                    "file": "fixture.lua",
                    "range": {
                        "start": {"line": 99, "col": 0},
                        "end": {"line": 99, "col": 1},
                    },
                },
            }
        )
        path.write_text(json.dumps(data))
        failed = await self.tool("tour_load", path=str(path))
        self.assertFalse(failed["persisted"])
        self.assertTrue(
            any(e.get("step") == 2 and "bounds" in e for e in failed["errors"])
        )
        self.assertEqual(saved[0].read_text(), saved_content)

    @with_session
    async def test_unavailable_plugin_and_null_persistence_are_structured(self):
        self.rpc.exec_lua(
            "package.loaded.tour = {}; package.preload.tour = function() return {} end"
        )
        result = await self.tool("tour_load", path="missing.json")
        self.assertFalse(result["persisted"])
        self.assertEqual(result["errors"][0]["code"], "tour_unavailable")
        # Fault injection verifies Lua vim.NIL survives RPC and MCP as JSON null.
        self.rpc.exec_lua("""
          package.loaded.tour = {load_checked = function()
            return {ok = false, persisted = vim.NIL, displayed = false,
              errors = {{code = 'persistence_failed', message = 'fixture'}}}
          end}
        """)
        result = await self.tool("tour_load", path="fixture.json")
        self.assertIsNone(result["persisted"])
        self.assertFalse(result["ok"])
