"""Exercise the configured editor in a disposable, isolated Zellij session.

python checks/nvim-diff-zoom.py --nvim /path/to/configured/bin/nvim --zellij /path/to/zellij
No commands are sent to an existing user session.
"""

import argparse
import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


def wait_for(predicate, message, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(0.05)
    raise AssertionError(message)


def run(args):
    with tempfile.TemporaryDirectory(prefix="nvim-diff-zoom-") as tmp:
        base = Path(tmp)
        runtime = base / "run"
        runtime.mkdir(mode=0o700)
        config = base / "config"
        config.mkdir()
        (config / "config.kdl").write_text(
            "show_startup_tips false\nshow_release_notes false\n"
            "session_serialization false\n"
        )
        env = dict(
            os.environ,
            XDG_RUNTIME_DIR=str(runtime),
            XDG_CACHE_HOME=str(base / "cache"),
            XDG_STATE_HOME=str(base / "state"),
            XDG_DATA_HOME=str(base / "data"),
            ZELLIJ_CONFIG_DIR=str(config),
            GIT_CONFIG_GLOBAL="/dev/null",
            GIT_CONFIG_NOSYSTEM="1",
        )
        for key in (
            "ZELLIJ",
            "ZELLIJ_SESSION_NAME",
            "ZELLIJ_PANE_ID",
            "ZELLIJ_CONFIG_FILE",
            "NVIM",
            "NVIM_ADDRESS",
            "DEV_NVIM_SOCKET",
        ):
            env.pop(key, None)
        repo = base / "repo with spaces"
        repo.mkdir()
        socket = base / "editor.sock"

        def command(argv, check=True):
            return subprocess.run(
                argv,
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
                timeout=20,
                check=check,
            )

        def action(*argv):
            return command(
                [args.zellij, "--session", "diff-fixture", "action", *argv]
            ).stdout

        def panes():
            return [
                p
                for p in json.loads(action("list-panes", "--json", "--all"))
                if not p["is_plugin"]
            ]

        def lua(expr):
            result = command(
                [
                    args.nvim,
                    "--server",
                    str(socket),
                    "--remote-expr",
                    "luaeval(" + json.dumps("vim.json.encode((" + expr + "))") + ")",
                ]
            )
            return json.loads(result.stdout)

        def execute(body):
            return lua("(function() " + body + "; return true end)()")

        def diff_count():
            return lua(
                "#vim.tbl_filter(function(w) return vim.wo[w].diff end, vim.api.nvim_list_wins())"
            )

        def toggle():
            execute('vim.fn.maparg(" gd", "n", false, true).callback()')

        command(["git", "init", "--quiet"])
        file = repo / "example.txt"
        file.write_text("first\noriginal\nlast\n")
        second_file = repo / "second.txt"
        second_file.write_text("another original\n")
        command(["git", "add", "example.txt", "second.txt"])
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
                "--quiet",
                "-m",
                "fixture",
            ]
        )
        file.write_text("first\nstaged change\nlast\n")
        command(["git", "add", "example.txt"])
        file.write_text("first\nstaged change\nunstaged change\n")
        second_file.write_text("another changed file\n")
        layout = base / "layout.kdl"
        layout.write_text(
            'layout {\n tab name="fixture" {\n  pane split_direction="vertical" {\n'
            + "   pane command="
            + json.dumps(args.nvim)
            + " cwd="
            + json.dumps(str(repo))
            + ' { args "--listen" '
            + json.dumps(str(socket))
            + " "
            + json.dumps(str(file))
            + "; }\n"
            + "   pane command="
            + json.dumps(shutil.which("bash"))
            + ' { args "--noprofile" "--norc"; }\n'
            + "  }\n }\n}\n"
        )
        started = False
        try:
            command(
                [
                    args.zellij,
                    "--new-session-with-layout",
                    str(layout),
                    "attach",
                    "--create-background",
                    "diff-fixture",
                ]
            )
            started = True
            wait_for(socket.exists, "editor socket did not appear")
            wait_for(
                lambda: lua("vim.b.gitsigns_status_dict ~= nil"),
                "Gitsigns did not attach",
            )
            pane_id = int(lua('vim.env.ZELLIJ_PANE_ID:gsub("^terminal_", "")'))
            initial = panes()
            assert len(initial) == 2, initial
            sentinel = next(p for p in initial if p["id"] != pane_id)

            def editor():
                return next(p for p in panes() if p["id"] == pane_id)

            # Record state at the exact point the real Gitsigns diff is invoked.
            execute(
                'local gs = require("gitsigns"); local original = gs.diffthis; '
                "gs.diffthis = function(...) vim.g.fixture_call_count = (vim.g.fixture_call_count or 0) + 1; "
                'local result = vim.system({vim.g.editor_zellij_command, "--session", vim.env.ZELLIJ_SESSION_NAME, "action", "list-panes", "--json", "--all"}, {text=true}):wait(); '
                "assert(result.code == 0); "
                "for _, p in ipairs(vim.json.decode(result.stdout)) do "
                "if not p.is_plugin and tostring(p.id) == vim.env.ZELLIJ_PANE_ID then "
                "vim.g.fixture_order_ok = p.is_fullscreen and vim.o.columns == p.pane_content_columns and vim.o.lines == p.pane_content_rows "
                "end end; return original(...) end"
            )
            # An unrelated Neovim split must survive diff close.
            execute(
                'vim.cmd.split(); vim.g.fixture_unrelated = vim.api.nvim_get_current_win(); vim.cmd.wincmd("p")'
            )
            assert not editor()["is_fullscreen"]
            toggle()
            wait_for(lambda: diff_count() == 2, "diff did not open")
            assert lua("vim.g.fixture_order_ok"), "diff opened before fullscreen/resize"
            assert editor()["is_fullscreen"]
            originals = lua(
                'vim.tbl_map(function(w) return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false) end, vim.tbl_filter(function(w) return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):match("^gitsigns://") ~= nil end, vim.api.nvim_list_wins()))'
            )
            assert originals == [["first", "original", "last"]], originals
            toggle()
            wait_for(lambda: not editor()["is_fullscreen"], "layout not restored")
            assert diff_count() == 0
            assert lua("vim.api.nvim_win_is_valid(vim.g.fixture_unrelated)")
            print(
                "PASS: targeted fullscreen and resize before HEAD diff; close restores layout and preserves unrelated split"
            )

            action("toggle-fullscreen", "--pane-id", f"terminal_{pane_id}")
            toggle()
            wait_for(lambda: diff_count() == 2, "pre-fullscreen diff did not open")
            toggle()
            wait_for(lambda: diff_count() == 0, "pre-fullscreen diff did not close")
            assert editor()["is_fullscreen"], "pre-existing fullscreen was lost"
            action("toggle-fullscreen", "--pane-id", f"terminal_{pane_id}")
            print("PASS: pre-existing fullscreen is preserved")

            toggle()
            wait_for(lambda: diff_count() == 2, "manual-close diff did not open")
            execute(
                'for _, w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):match("^gitsigns://") then vim.api.nvim_win_close(w, false) end end'
            )
            wait_for(
                lambda: not editor()["is_fullscreen"],
                "manual close did not restore layout",
            )
            print("PASS: manual diff-window close restores layout")

            # Two Neovim tabs share one containing Zellij pane lease.
            toggle()
            wait_for(lambda: diff_count() == 2, "first tab diff did not open")
            execute("vim.cmd.tabnew(" + json.dumps(str(second_file)) + ")")
            wait_for(
                lambda: lua("vim.b.gitsigns_status_dict ~= nil"),
                "second tab did not attach",
            )
            toggle()
            wait_for(lambda: diff_count() == 4, "second tab diff did not open")
            toggle()
            wait_for(lambda: diff_count() == 2, "second tab diff did not close")
            assert editor()["is_fullscreen"], (
                "closing one tab released another tab's zoom"
            )
            execute("vim.cmd.tabclose()")
            toggle()
            wait_for(
                lambda: not editor()["is_fullscreen"], "last diff did not release zoom"
            )
            print("PASS: multiple diff tabs share fullscreen until the last closes")

            # With no Gitsigns attachment, opening is a no-op and must roll back.
            execute("vim.cmd.enew()")
            count = lua("vim.g.fixture_call_count")
            toggle()
            wait_for(
                lambda: lua("vim.g.fixture_call_count") > count,
                "failure-path diff did not run",
            )
            wait_for(
                lambda: not editor()["is_fullscreen"], "no-op diff did not roll back"
            )
            print("PASS: a buffer with no comparison rolls fullscreen back")

            after = next(p for p in panes() if p["id"] == sentinel["id"])
            assert (after["tab_id"], after["terminal_command"]) == (
                sentinel["tab_id"],
                sentinel["terminal_command"],
            )
            execute("vim.cmd.edit(" + json.dumps(str(file)) + ")")
            toggle()
            wait_for(lambda: diff_count() == 2, "exit-test diff did not open")
            execute('vim.schedule(function() vim.cmd("qa!") end)')
            wait_for(lambda: not socket.exists(), "editor did not exit")
            assert not any(p["is_fullscreen"] for p in panes())
            print("PASS: editor exit cleans up; unrelated pane untouched")
        except Exception:
            if socket.exists():
                print(
                    "Fixture diagnostics:",
                    lua(
                        '(function() local result = {}; for _, w in ipairs(vim.api.nvim_list_wins()) do table.insert(result, {window=w, tab=vim.api.nvim_win_get_tabpage(w), diff=vim.wo[w].diff, buffer=vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))}) end; return {windows=result, messages=vim.api.nvim_exec2("messages", {output=true}).output} end)()'
                    ),
                )
            raise
        finally:
            if started:
                command([args.zellij, "kill-session", "diff-fixture"], check=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--nvim", required=True)
    parser.add_argument("--zellij", default=shutil.which("zellij"))
    run(parser.parse_args())
