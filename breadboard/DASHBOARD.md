# Codex status dashboard

The dashboard shows up to six current Codex root sessions or subagents. Three
fit on the 128x64 OLED at once; additional entries rotate to another page every
five seconds.

The integration uses documented Codex lifecycle hooks. Hooks update a small
SQLite database under `/tmp/codex-board-$UID/`; the laptop bridge sends an
atomic snapshot to the ESP32 over USB every two seconds. It does not read or
modify files in the projects being displayed.

## LED meanings

| LED / GPIO | Meaning |
|---|---|
| Green / GPIO4 | At least one displayed task is complete |
| Yellow / GPIO5 | At least one displayed task is working |
| Red / GPIO6 | Task error, network offline, or laptop bridge lost |
| Blue / GPIO7 | A task needs user input or approval |
| Harder blue / GPIO10 | Laptop bridge is alive and the network probe succeeds |
| Self-cycling / GPIO11 | Input or network failure has waited at least three minutes |

Several LEDs may be on simultaneously. For example, green plus yellow means
one task completed while another is still running. If red is on, the OLED
distinguishes `ERROR`, network offline (`N:X`), and `HOST LINK LOST`.

## OLED format

Each task uses two lines. The project and elapsed time appear first, followed
by the Codex-generated title and state:

```text
CODEX 3 L:OK N:+
nix-config     3h22
do xyz           RUN
palimpsest
another title   DONE
projectA
_              INPUT
```

`_` means Codex has not supplied the short title yet. States are `RUN`, `DONE`,
`INPUT`, and `ERROR`.

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

Load the three example rows and start the USB bridge:

```bash
.venv/bin/python host/codex_board.py clear
.venv/bin/python host/codex_board.py demo
.venv/bin/python host/codex_board.py daemon --port /dev/ttyACM0
```

The bridge automatically recognizes Espressif USB devices when `--port auto`
is used, but an explicit port is clearer during initial setup. Press `Ctrl-C`
to stop it.

The network monitor probes `https://chatgpt.com` from the laptop. It declares
the connection online after two successes and offline after three failures.
Override the URL only when diagnosing a network/proxy setup:

```bash
.venv/bin/python host/codex_board.py daemon \
  --port /dev/ttyACM0 --probe-url https://chatgpt.com
```

## 3. Activate the declarative Codex integration

In this `nix-config` repository, `modules/shared/codex-hooks.nix` packages the
bridge as `codex-board` and merges the dashboard events with the existing
managed agent-deck hooks. A separate `codex-title` registry owns generated
session titles and publishes them to independent service adapters. No token or
mutable user hook file is required.

The `breadboard` directory is currently untracked, so a Git-backed flake omits
it. When you are ready to activate the changes, stage only this new directory;
no commit is required. First build the complete Glacier configuration:

```bash
git add breadboard
sudo nixos-rebuild build --flake .#glacier --accept-flake-config
```

If that succeeds, activate it explicitly:

```bash
sudo nixos-rebuild switch --flake .#glacier --accept-flake-config
```

After activation, restart Codex and unplug/reconnect the ESP32 once so the new
udev access rule is applied. The hooks are supplied by the managed system
requirements, the bridge CLI is available directly as `codex-board`, and the
background service starts automatically at login.

These events are recorded:

- `UserPromptSubmit`: starts a task and places `_` on the display.
- A separate metadata hook asks Codex to store a 2-4 word title with
  `codex-title`. The registry publishes it to the independent Breadboard and
  Zellij Agent Deck adapters.
- `PreToolUse` and `PostToolUse`: mark work in progress and detect structured
  tool failures.
- `PermissionRequest`: marks the root task as `INPUT`.
- `Stop`: marks the task `DONE`, or `INPUT` when the final response asks a
  question. A completed task stays visible while its Codex session is open.
- `SubagentStart` and `SubagentStop`: add and finish separate subagent rows.
- `SessionEnd`: removes the root task and all subagents belonging to the closed
  session. Green turns off when no remaining session is `DONE`.

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
after USB is restored. It also inherits the configured Glacier proxy for its
network probe.

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
codex-board packet --network online
codex-title list
codex-title get --session SESSION_ID
```

The ESP32 turns red and shows `HOST LINK LOST` after 15 seconds without a
bridge snapshot. This does not use silence from an active Codex task as a
disconnect signal: an agent may legitimately reason for several minutes
without running a tool.

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

The laptop probe has failed repeatedly or the USB bridge heartbeat expired.
Read the OLED and bridge terminal for the specific state.

### Red and harder-blue LEDs are both on

The laptop and network are reachable, but a tracked task's latest structured
tool result reported an error. A later successful tool call returns the task to
`RUN`; finishing the turn changes it to `DONE` or `INPUT`.

### Re-run the electrical self-test

The original code remains `src/main.cpp` under the `bringup` environment:

```bash
.venv/bin/pio run -e bringup
.venv/bin/pio run -e bringup -t upload --upload-port /dev/ttyACM0
```

Restore the dashboard afterward by flashing `-e dashboard` again.

## Limits

- Codex does not currently document a dedicated network-disconnected hook.
  Connectivity is therefore measured independently by the laptop bridge.
- A question mark in the final assistant message is treated as `INPUT`; this
  deliberately favors notifying you over silently marking a question done.
- The OLED font is ASCII and limited to about 21 characters per line. Longer
  project names and titles are clipped.
- The bridge must own the USB serial port, so it cannot run alongside a serial
  monitor or firmware upload.
