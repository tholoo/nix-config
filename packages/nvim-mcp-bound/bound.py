"""Upstream nvim-mcp with workspace binding and structured editor tools."""

import asyncio
import os
from pathlib import Path

from nvim_mcp.discovery import probe_socket
from nvim_mcp.manager import NeovimManager
from nvim_mcp.types import CONNECT_TIMEOUT


class BoundNeovimManager(NeovimManager):
    def __init__(self, address):
        super().__init__()
        if not Path(address).is_absolute():
            raise ValueError("DEV_NVIM_SOCKET must be an absolute Unix socket path")
        self.address = str(Path(address).resolve())

    async def discover(self):
        # No global scan, fallback, or stale discovery cache when the editor exits.
        if str(Path(self.address).resolve()) != self.address:
            return []
        try:
            instance = await asyncio.wait_for(
                asyncio.to_thread(probe_socket, self.address),
                timeout=CONNECT_TIMEOUT,
            )
            return [instance] if instance is not None else []
        except (OSError, RuntimeError, asyncio.TimeoutError):
            return []

    async def _connect_to(self, path):
        if not Path(path).is_absolute() or str(Path(path).resolve()) != self.address:
            raise OSError(
                "This MCP server is bound to its paired workspace's Neovim socket"
            )
        return await super()._connect_to(self.address)


def main():
    from nvim_mcp import server
    from editor_tools import register

    address = os.environ.get("DEV_NVIM_SOCKET")
    if address:
        server.manager = BoundNeovimManager(address)
    register(server)
    server.main()


if __name__ == "__main__":
    main()
