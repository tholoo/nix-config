import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

spec = importlib.util.spec_from_file_location(
    "bound", Path(__file__).parents[1] / "bound.py"
)
bound = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bound)


class BindingTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        # The probe is mocked in unit tests; run it without executor threads.
        runner = patch.object(
            bound.asyncio,
            "to_thread",
            AsyncMock(side_effect=lambda fn, *args: fn(*args)),
        )
        runner.start()
        self.addCleanup(runner.stop)

    async def test_discovery_only_probes_assigned_socket(self):
        manager = bound.BoundNeovimManager("/tmp/assigned.sock")
        with patch.object(bound, "probe_socket", return_value=None) as probe:
            self.assertEqual(await manager.discover(), [])
            probe.assert_called_once_with("/tmp/assigned.sock")

    async def test_explicit_foreign_socket_is_rejected_before_connect(self):
        manager = bound.BoundNeovimManager("/tmp/assigned.sock")
        with (
            patch.object(manager, "discover", AsyncMock(return_value=[])),
            patch.object(bound.NeovimManager, "_connect_to", AsyncMock()) as connect,
        ):
            result = await manager.connect(socket_path="/tmp/another.sock")
            self.assertIn("bound", result["error"])
            result = await manager.connect(socket_path="127.0.0.1:1234")
            self.assertIn("bound", result["error"])
            connect.assert_not_called()

    async def test_reconnect_is_also_bound(self):
        manager = bound.BoundNeovimManager("/tmp/assigned.sock")
        manager._socket_path = "/tmp/other.sock"
        with patch.object(bound.NeovimManager, "_connect_to", AsyncMock()) as connect:
            with self.assertRaises(RuntimeError):
                await manager._reconnect_unlocked()
            connect.assert_not_called()

    async def test_assigned_connection_uses_upstream(self):
        manager = bound.BoundNeovimManager("/tmp/assigned.sock")
        with patch.object(
            bound.NeovimManager, "_connect_to", AsyncMock(return_value="fixture")
        ) as connect:
            self.assertEqual(await manager._connect_to("/tmp/assigned.sock"), "fixture")
            connect.assert_awaited_once_with("/tmp/assigned.sock")

    async def test_retargeted_symlink_cannot_change_binding(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            address = root / "editor.sock"
            manager = bound.BoundNeovimManager(str(address))
            address.symlink_to(root / "foreign.sock")
            with self.assertRaises(OSError):
                await manager._connect_to(str(address))

    async def test_missing_bound_editor_never_auto_connects_elsewhere(self):
        manager = bound.BoundNeovimManager("/tmp/missing.sock")
        with (
            patch.object(bound, "probe_socket", return_value=None),
            patch.object(manager, "_connect_to", AsyncMock()) as connect,
        ):
            self.assertIn("error", await manager._auto_connect_unlocked())
            connect.assert_not_called()

    def test_relative_binding_is_rejected(self):
        with self.assertRaises(ValueError):
            bound.BoundNeovimManager("relative.sock")
