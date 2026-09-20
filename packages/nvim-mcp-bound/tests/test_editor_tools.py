import asyncio
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch

sys.path.insert(0, str(Path(__file__).parents[1]))
from editor_tools import exec_lua


class ExecutionTests(unittest.IsolatedAsyncioTestCase):
    def manager(self, client):
        return SimpleNamespace(
            _lock=asyncio.Lock(),
            _nvim=client,
            _socket_path="/tmp/fixture.sock",
            _reconnect_unlocked=AsyncMock(),
            _auto_connect_unlocked=AsyncMock(),
        )

    async def test_arguments_are_rpc_data_not_interpolated_code(self):
        client = Mock()
        client.exec_lua.return_value = {"ok": True}
        manager = self.manager(client)
        path = "quote'\"\\\n; error('not code').json"
        self.assertEqual(await exec_lua(manager, "return ...", path), {"ok": True})
        client.exec_lua.assert_called_once_with("return ...", path)

    async def test_failed_request_is_never_replayed(self):
        client = Mock()
        client.exec_lua.side_effect = OSError("response lost after save")
        manager = self.manager(client)
        with self.assertRaisesRegex(OSError, "response lost"):
            await exec_lua(manager, "mutation")
        client.exec_lua.assert_called_once()
        client.close.assert_called_once()
        self.assertIsNone(manager._nvim)
        manager._reconnect_unlocked.assert_not_called()

        replacement = Mock()
        replacement.exec_lua.return_value = {"ok": True}
        manager._reconnect_unlocked.side_effect = lambda: setattr(
            manager, "_nvim", replacement
        )
        await exec_lua(manager, "next explicit request")
        manager._reconnect_unlocked.assert_awaited_once()
        replacement.exec_lua.assert_called_once_with("next explicit request")
        manager._auto_connect_unlocked.assert_not_called()

    async def test_cancellation_keeps_lock_until_rpc_settles(self):
        client = Mock()
        manager = self.manager(client)
        started, finish = asyncio.Event(), asyncio.Event()

        async def slow_rpc(*args):
            started.set()
            await finish.wait()
            return {"ok": True}

        with patch("editor_tools.asyncio.to_thread", side_effect=slow_rpc):
            task = asyncio.create_task(exec_lua(manager, "mutation"))
            await started.wait()
            task.cancel()
            await asyncio.sleep(0)
            self.assertTrue(manager._lock.locked())
            finish.set()
            with self.assertRaises(asyncio.CancelledError):
                await task
        self.assertFalse(manager._lock.locked())
        self.assertIsNone(manager._nvim)
        client.close.assert_called_once()

    async def test_missing_editor_stops_before_rpc(self):
        manager = self.manager(None)
        manager._socket_path = None
        manager._auto_connect_unlocked.return_value = {"error": "editor unavailable"}
        with self.assertRaisesRegex(RuntimeError, "editor unavailable"):
            await exec_lua(manager, "return 1")

    async def test_uses_upstream_lock(self):
        client = Mock()
        manager = self.manager(client)
        client.exec_lua.side_effect = lambda *_: {"locked": manager._lock.locked()}
        self.assertEqual(await exec_lua(manager, "return 1"), {"locked": True})
        self.assertFalse(manager._lock.locked())
