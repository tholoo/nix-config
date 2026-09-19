"""Test dev inside a manually created Zellij session, using temporary worktrees.

Run with nvim-mcp's Python environment:
python integration.py --dev /path/to/dev --mcp /path/to/nvim-mcp
"""

import argparse
import asyncio
import json
import os
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from contextlib import AsyncExitStack
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from nvim_mcp.discovery import probe_socket


def fixture_agent():
    root = Path(os.environ["DEV_WORKSPACE_ROOT"])
    (root / "agent-fixture.json").write_text(
        json.dumps(
            {
                "pid": os.getpid(),
                "cwd": os.getcwd(),
                "socket": os.environ["DEV_NVIM_SOCKET"],
                "inherited": os.environ.get("DEV_FIXTURE_ENV"),
            }
        )
    )
    while True:
        signal.pause()


def wait_for(predicate, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(0.1)
    raise AssertionError("Timed out waiting for fixture readiness")


async def tool(session, name, arguments=None):
    result = await session.call_tool(name, arguments or {})
    return result.structured_content or json.loads(result.content[0].text)


async def run(args):
    with tempfile.TemporaryDirectory(prefix="dv-") as tmp:
        base = Path(tmp)
        runtime = base / "run"
        runtime.mkdir(mode=0o700)
        zconfig = base / "zellij"
        zconfig.mkdir()
        (zconfig / "config.kdl").write_text(
            "show_startup_tips false\nshow_release_notes false\nsession_serialization false\n"
        )
        env = dict(
            os.environ,
            XDG_RUNTIME_DIR=str(runtime),
            ZELLIJ_CONFIG_DIR=str(zconfig),
            XDG_CACHE_HOME=str(base / "cache"),
            XDG_DATA_HOME=str(base / "data"),
            DEV_FIXTURE_ENV="old-server",
        )
        for name in (
            "ZELLIJ",
            "ZELLIJ_SESSION_NAME",
            "ZELLIJ_PANE_ID",
            "ZELLIJ_CONFIG_FILE",
            "NVIM",
            "DEV_NVIM_SOCKET",
            "NVIM_ADDRESS",
        ):
            env.pop(name, None)
        root = base / 'repo "quoted"'
        root.mkdir()

        def command(argv, check=True):
            return subprocess.run(
                argv,
                cwd=root,
                env=env,
                capture_output=True,
                text=True,
                check=check,
                timeout=30,
            )

        def action(*argv):
            return command(
                ["zellij", "--session", "manual-fixture", "action", *argv]
            ).stdout

        def panes():
            return [
                p
                for p in json.loads(action("list-panes", "--json", "--all"))
                if not p["is_plugin"]
            ]

        command(["git", "init", "--quiet"])
        command(
            [
                "git",
                "-c",
                "user.name=Fixture",
                "-c",
                "user.email=fixture@example.invalid",
                "-c",
                "commit.gpgsign=false",
                "commit",
                "--allow-empty",
                "--quiet",
                "-m",
                "fixture",
            ]
        )
        worktree = base / "worktree"
        command(["git", "worktree", "add", "--quiet", "-b", "second", str(worktree)])
        config = base / "dev.json"
        config.write_text(
            json.dumps(
                {
                    "editorCommand": [shutil.which("nvim"), "--clean", "-n"],
                    "agentCommand": [
                        sys.executable,
                        str(Path(__file__).resolve()),
                        "--fixture-agent",
                    ],
                    "zellijCommand": shutil.which("zellij"),
                    "direnvCommand": None,
                }
            )
        )
        dev = [args.dev, "--config", str(config)]
        states = [
            json.loads(command(dev + ["--status", str(p)]).stdout)
            for p in (root, worktree)
        ]
        outside = command(dev + [str(root)], check=False)
        assert (
            outside.returncode != 0 and "existing Zellij session" in outside.stderr
        ), outside
        layout = base / "manual.kdl"
        layout.write_text(
            "layout {\n"
            + "\n".join(
                f' tab name="{name}" {{ pane cwd={json.dumps(str(cwd))} command={json.dumps(shutil.which("bash"))} {{ args "--noprofile" "--norc"; }}; }}'
                for name, cwd in (
                    ("first", root),
                    ("second", worktree),
                    ("untouched", base),
                )
            )
            + "\n}\n"
        )
        try:
            with open(base / "zellij.log", "w") as log:  # noqa: ASYNC230 - fixture setup
                subprocess.run(  # noqa: ASYNC221 - fixture setup precedes MCP clients
                    [
                        "zellij",
                        "--new-session-with-layout",
                        str(layout),
                        "attach",
                        "--create-background",
                        "manual-fixture",
                    ],
                    env=env,
                    stdin=subprocess.DEVNULL,
                    stdout=log,
                    stderr=log,
                    check=True,
                    timeout=20,
                )
            original = wait_for(
                lambda: current if len(current := panes()) == 3 else None
            )
            by_tab = {p["tab_name"]: p for p in original}
            sentinel = by_tab["untouched"]
            callers = [by_tab["first"], by_tab["second"]]
            for caller, state in zip(callers, states, strict=True):
                wait_for(
                    lambda caller=caller: action(
                        "dump-screen", "--pane-id", f"terminal_{caller['id']}"
                    ).strip()
                )
                line = (
                    "export DEV_FIXTURE_ENV=launching-shell; "
                    + shlex.join(dev + [state["root"]])
                    + "\n"
                )
                action("write-chars", "--pane-id", f"terminal_{caller['id']}", line)
                wait_for(lambda state=state: probe_socket(state["socket"]))
            fixtures = []
            for caller, state in zip(callers, states, strict=True):
                marker = Path(state["root"]) / "agent-fixture.json"
                wait_for(marker.exists)
                fixture = json.loads(marker.read_text())
                fixtures.append(fixture)
                assert (
                    fixture["socket"] == state["socket"]
                    and fixture["cwd"] == state["root"]
                )
                assert fixture["inherited"] == "launching-shell", fixture
                pair = [p for p in panes() if p["tab_id"] == caller["tab_id"]]
                assert len(pair) == 2 and caller["id"] in [p["id"] for p in pair], pair
                editor = next(p for p in pair if p["id"] == caller["id"])
                assert (
                    abs(
                        editor["pane_columns"] / sum(p["pane_columns"] for p in pair)
                        - 0.6
                    )
                    <= 0.02
                ), pair
            assert (
                command(
                    ["zellij", "list-sessions", "--short", "--no-formatting"]
                ).stdout.strip()
                == "manual-fixture"
            )
            after = next(p for p in panes() if p["id"] == sentinel["id"])
            assert (
                after["tab_id"] == sentinel["tab_id"]
                and after["terminal_command"] == sentinel["terminal_command"]
            )
            assert len(json.loads(action("list-tabs", "--json"))) == 3
            print(
                "current panes retained, 60/40 split, shell environment, no new sessions/tabs PASS",
                flush=True,
            )
            async with AsyncExitStack() as stack:
                sessions = []
                for state in states:
                    channels = await stack.enter_async_context(
                        stdio_client(
                            StdioServerParameters(
                                command=args.mcp,
                                env=env | {"DEV_NVIM_SOCKET": state["socket"]},
                            )
                        )
                    )
                    session = await stack.enter_async_context(ClientSession(*channels))
                    await session.initialize()
                    sessions.append(session)
                    result = await tool(session, "connect")
                    assert result.get("connected") == state["socket"], result
                denied = await tool(
                    sessions[0], "connect", {"socket_path": states[1]["socket"]}
                )
                assert "bound" in denied.get("error", ""), denied
                print("two worktrees and foreign MCP socket rejection PASS", flush=True)
                os.kill(probe_socket(states[0]["socket"]).pid, signal.SIGTERM)
                wait_for(lambda: not Path(states[0]["socket"]).exists())
                assert "error" in await tool(sessions[0], "connect")
                os.kill(fixtures[0]["pid"], 0)
                await asyncio.sleep(0.2)
                action(
                    "write-chars",
                    "--pane-id",
                    f"terminal_{callers[0]['id']}",
                    shlex.join(dev + [str(root)]) + "\n",
                )
                wait_for(lambda: probe_socket(states[0]["socket"]))
                assert len(panes()) == 5
                assert (
                    json.loads((root / "agent-fixture.json").read_text())["pid"]
                    == fixtures[0]["pid"]
                )
                assert (await tool(sessions[0], "connect"))["connected"] == states[0][
                    "socket"
                ]
                print(
                    "editor returns to shell; rerunning dev reuses agent and reconnects MCP PASS",
                    flush=True,
                )
        except Exception:
            for failed_pane in panes():
                print(
                    action(
                        "dump-screen",
                        "--full",
                        "--pane-id",
                        f"terminal_{failed_pane['id']}",
                    ),
                    file=sys.stderr,
                )
            raise
        finally:
            command(["zellij", "kill-session", "manual-fixture"], check=False)


if __name__ == "__main__":
    if "--fixture-agent" in sys.argv:
        fixture_agent()
    else:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("--dev", required=True)
        parser.add_argument("--mcp", required=True)
        asyncio.run(run(parser.parse_args()))
