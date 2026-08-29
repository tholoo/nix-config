# Codex status dashboard

The OLED is a fixed Codex usage panel. Session lifecycle tracking still runs in
the background and drives the LEDs exactly as before, but individual sessions
are no longer rendered on the small display.

The integration uses documented Codex lifecycle hooks. Hooks update a small
SQLite database under `/tmp/codex-board-$UID/`; the laptop bridge sends an
atomic snapshot to the ESP32 over USB every two seconds. It does not read or
modify files in the projects being displayed.

## LED meanings

| LED / GPIO | Meaning |
|---|---|
| Green / GPIO4 | At least one completed root task has not been acknowledged |
| Yellow / GPIO5 | At least one root task is working |
| Red / GPIO6 | Root-task error or laptop bridge lost |
| Blue / GPIO7 | A root task needs user input or approval |
| Harder blue / GPIO10 | Laptop bridge heartbeat is present |
| Self-cycling / GPIO11 | Blue input or any continuous red alert has lasted at least three minutes |

Several LEDs may be on simultaneously. For example, green plus yellow means
one unread task completed while another is still running. The OLED displays
`HOST LINK LOST` when snapshots stop; use `codex-board list` when red and the
harder-blue link LED are both on to identify a tracked task error.

## OLED format

The two most useful quota windows show their remaining percentage, reset
countdown, and a remaining-capacity bar. The bottom lines show today's token
usage and the age of the last successful usage sync:

```text
CODEX USAGE
7D         L75% R4d00h
[==============     ]
SPARK5H    L80% R2h00m
[===============    ]
TODAY 12M TOKENS
SYNC 12s
```

The example values are fictional. `L` means remaining/left and `R` means time
until reset. If Codex exposes only one main quota window, the second row uses
the next model-specific limit; if no second window exists, it says
`NO SECOND QUOTA`. Usage failure does not disable session-driven LEDs.

When Agent Deck jumps to a completed root task, its existing `mark-read` action
also acknowledges the matching dashboard row. Green turns off if no other
unread root completion remains. Subagent rows remain host-side bookkeeping and
never illuminate LEDs. Resuming a completed Codex session does the same through
`SessionStart`. Simply focusing an already-open pane by other means has no
reliable Codex event and cannot be detected.

## 1. Build and flash

Close any existing serial monitor, then run:

```bash
.venv/bin/pio run -e dashboard
.venv/bin/pio device list
.venv/bin/pio run -e dashboard -t upload --upload-port /dev/ttyACM0
```

Use the port reported on your laptop if it is not `/dev/ttyACM0`. If upload
cannot connect, hold **BOOT**, tap **RESET**, release **BOOT**, and retry. On
this NixOS host, temporary ownership may be required after the USB device
reappears:

```bash
sudo chown "$USER" /dev/ttyACM0
```

Optionally inspect startup output, then close the monitor with `Ctrl-C`:

```bash
.venv/bin/pio device monitor --port /dev/ttyACM0 --baud 115200
```

## 2. Test the display without Codex hooks

Load the three example task states for the LEDs and start the USB bridge. The
OLED itself reads live usage through the local Codex sign-in:

```bash
.venv/bin/python host/codex_board.py clear
.venv/bin/python host/codex_board.py demo
.venv/bin/python host/codex_board.py daemon --port /dev/ttyACM0
```

The bridge automatically recognizes Espressif USB devices when `--port auto`
is used, but an explicit port is clearer during initial setup. Press `Ctrl-C`
to stop it.

## 3. Activate the declarative Codex integration

In this `nix-config` repository, `modules/shared/codex-hooks.nix` packages the
bridge as `codex-board` and merges the dashboard events with the existing
managed Agent Deck hooks. Each hook derives its own bounded title directly
from the beginning of the submitted prompt. No model-generated title hook,
token, publisher service, or mutable user hook file is required.

When you are ready to activate the host-side changes, first build the complete
Glacier configuration; no commit is required:

```bash
sudo nixos-rebuild build --flake .#glacier --accept-flake-config
```

If that succeeds, activate it explicitly:

```bash
sudo nixos-rebuild switch --flake .#glacier --accept-flake-config
```

After activation, start a new Codex process and reload Agent Deck (a new Zellij
session is sufficient) so both pick up the managed hooks and helper. Unplug and
reconnect the ESP32 once so the new udev access rule is applied. The bridge CLI
is available directly as `codex-board`, and the background service starts
automatically at login.

The NixOS switch does not update the ESP32 firmware. Flash the `dashboard`
environment separately using the commands in section 1 to activate the OLED
layout and LED timing changes.

These events are recorded:

- `UserPromptSubmit`: starts a task and derives its title from the beginning of
  the prompt. Zellij Agent Deck independently does the same for its task record.
- `PreToolUse` and `PostToolUse`: mark work in progress and detect structured
  tool failures.
- `PermissionRequest`: marks the root task as `INPUT`.
- `Stop`: marks the task `DONE`, or `INPUT` when the final response asks a
  question. A completed task stays visible while its Codex session is open.
- `SubagentStart` and `SubagentStop`: retain host-side lifecycle rows for
  bookkeeping; subagents are not sent to the board and do not affect its LEDs.
- `SessionEnd`: removes the root task and all subagents belonging to the closed
  session. Green turns off when no remaining session is `DONE`.
- Agent Deck `mark-read` or a resumed `SessionStart`: changes a completed root
  row to acknowledged (`SEEN` internally), clearing its green alert without
  deleting the retained row.

The hooks are global managed hooks, so they can show `~/nix-config`,
`palimpsest`, and other repositories without adding or changing anything
inside those projects.

For a non-Nix installation, the fallback installer safely merges its entries
into `$CODEX_HOME/hooks.json`, backing up the file and preserving unrelated
hooks:

```bash
python3 host/codex_board.py install-hooks
```

## 4. Background operation

No terminal needs to remain open. Check the service and follow its logs with:

```bash
systemctl --user status codex-board
journalctl --user -u codex-board -f
```

The daemon keeps running when the board is absent and reconnects automatically
after USB is restored.

The background service, serial monitor, and firmware uploader cannot share the
port. Use this sequence around flashing or monitoring:

```bash
systemctl --user stop codex-board
# flash firmware or open the serial monitor
systemctl --user start codex-board
```

Restart it after configuration changes with:

```bash
systemctl --user restart codex-board
```

For foreground diagnostics only, stop the service and run:

```bash
codex-board daemon --port auto
```

Other useful local controls are:

```bash
codex-board list
codex-board clear
codex-board packet
```

The ESP32 turns red and shows `HOST LINK LOST` after 15 seconds without a
bridge snapshot. This does not use silence from an active Codex task as a
disconnect signal: an agent may legitimately reason for several minutes
without running a tool.

Any continuously red condition (task error or lost host) turns on the
self-cycling LED after three minutes. Blue input retains its independent
three-minute escalation.

## Troubleshooting

### Bridge says permission denied

After the declarative NixOS configuration is active, reconnect the ESP32 once
to apply its narrowly scoped udev rule. Then restart the service:

```bash
systemctl --user restart codex-board
```

The rule assigns only Espressif USB IDs `303a:1001` and `303a:4001` to the
normal local `users` group; it does not make every serial device user-writable.

### OLED shows `HOST LINK LOST`

- Confirm the bridge command is still running.
- Run `.venv/bin/pio device list` and check whether the USB port changed.
- Ensure no serial monitor or second bridge owns the port.

### Red LED is on while harder blue is off

The USB bridge heartbeat expired. Read the OLED and bridge terminal for link
state. If the harder-blue link LED is still on, use `codex-board list` to check
for a task error.

### Red and harder-blue LEDs are both on

The laptop bridge is reachable, but a tracked task's latest structured tool
result reported an error. A later successful tool call returns the task to
`RUN`; finishing the turn changes it to `DONE` or `INPUT`.

### Re-run the electrical self-test

The original code remains `src/main.cpp` under the `bringup` environment:

```bash
.venv/bin/pio run -e bringup
.venv/bin/pio run -e bringup -t upload --upload-port /dev/ttyACM0
```

Restore the dashboard afterward by flashing `-e dashboard` again.

## Limits

- A question mark in the final assistant message is treated as `INPUT`; this
  deliberately favors notifying you over silently marking a question done.
- The OLED font is ASCII and limited to about 21 characters per line. Usage
  labels and values are compacted to fit.
- The bridge must own the USB serial port, so it cannot run alongside a serial
  monitor or firmware upload.
