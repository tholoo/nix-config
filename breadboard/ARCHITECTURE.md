# Codex breadboard architecture and project record

Date: 2026-08-28

## Purpose

This project turns the verified ESP32-S3 breadboard into an ambient Codex
status display. The OLED answers usage questions while the LEDs retain the
original task-state behavior:

1. How much usage remains and when does it reset?
2. How many tokens have been used today?
3. Is an agent finished, working, waiting for input, or reporting an error?
4. Is the laptop bridge still sending heartbeats?

The ESP32 does not run an AI model and does not receive source code or complete
prompts. It is a small display client for status metadata produced on the
laptop.

## Hardware baseline

- Board: DevKit-style ESP32-S3 with two USB-C connectors
- Module: ESP32-S3-N8R2, 8 MB flash and 2 MB PSRAM
- Display: 0.96-inch 128x64 SSD1306 I2C OLED
- OLED: SDA GPIO8, SCL GPIO9, VDD 3.3 V, common GND
- Six active-high, individually resisted LED channels:
  - GPIO4: green
  - GPIO5: yellow
  - GPIO6: red
  - GPIO7: blue
  - GPIO10: “harder blue”
  - GPIO11: internally self-cycling seven-color/strobing LED
- Every LED has its own 220-ohm series resistor and its cathode connected to
  GND.

The hardware bring-up firmware and reported observations are preserved in
`src/main.cpp` and `HARDWARE_BRINGUP_RESULTS.md`.

## System layout

```text
Codex lifecycle hooks --------+-------> host/codex_board.py hook
                              |                    |
                              |                    v
                              |         codex-board state.sqlite3
                              |
                              +-------> Zellij Agent Deck hook

codex app-server usage ----> systemd user daemon --> USB serial --> ESP32
codex-board state.sqlite3 --------------------------^ (LED state only)
```

The hook commands are deliberately short-lived. They update SQLite and exit.
The long-running daemon owns the serial device and sends the latest snapshot
to the ESP32 every two seconds. On Glacier,
Home Manager starts it at login and systemd restarts it after unexpected
failure. The daemon itself polls for the ESP32 and reconnects after unplugging.

## Codex event mapping

| Hook event | Dashboard action |
|---|---|
| `UserPromptSubmit` | Start/reset the root task, derive its title from the prompt start, state `RUN`; classify Codex's automatic title-generation helper as internal |
| `PreToolUse` | Mark the root task `RUN` |
| `PostToolUse` | Mark `ERROR` for a structured failure, otherwise `RUN` |
| `PermissionRequest` | Mark the root task `INPUT` |
| `Stop` | Mark `DONE`, or `INPUT` when the final response asks a question; keep it visible while the session remains open |
| `SessionEnd` | Delete the root row and all of that session's subagent rows |
| `SubagentStart` | Retain a separate running subagent row for lifecycle bookkeeping; do not send it to the board |
| `SubagentStop` | Mark the retained subagent row complete; do not change the board LEDs |

On a regular `UserPromptSubmit`, Breadboard stores a sanitized 32-character
prefix of the prompt as its task title. Zellij Agent Deck independently derives
its own normalized title from the same hook payload. Codex's automatic Luna
title-generation session uses a recognizable internal prompt; Breadboard keeps
that classification across its later hooks and never serializes the helper as
a root task. Retained helper rows from before this behavior are reclassified
when the database opens. The Breadboard title is sent in the existing serial
record, although the usage-focused OLED no longer renders it.

Normal questions are inferred from a question mark or a small set of explicit
input-request phrases in the final assistant message. This favors visible
notification over silently treating a question as complete.

## Task state and timing

Root-task duration begins at `UserPromptSubmit` and freezes when the task
becomes `DONE`. Subagent duration begins at `SubagentStart`, but subagent rows
remain host-only and do not contribute to any board LED. Each root state also
has a separate age used for the delayed strobing alert.

A completed task remains retained so the user can notice it while its Codex
session is still open. Agent Deck's existing `mark-read` action acknowledges
the row when it jumps to that pane; resuming the session also acknowledges it.
Acknowledged rows use state `A` and no longer illuminate green. Closing the
session removes its root and subagent rows immediately.

The host sends at most six root-task rows to the board. Ordering is:

1. input required
2. error
3. working
4. completed

Within a state, the most recently updated rows come first.

## LED rules

The LEDs are independent; several may be illuminated simultaneously.

| LED | On when |
|---|---|
| Green | At least one root task is unacknowledged `DONE` |
| Yellow | At least one root task is `RUN` |
| Red | A root task is `ERROR` or the host heartbeat is lost |
| Blue | Host heartbeat is present |
| Harder blue | At least one root task is `INPUT` |
| Self-cycling | Input or any continuous red alert has remained for at least 180 seconds |

Useful combinations include:

- green + yellow: one task finished while another remains active
- red + blue: task/tool error while the host bridge remains reachable
- red without blue: host bridge or USB failure
- harder blue + self-cycling: user input has been waiting for at least three minutes

## OLED behavior

The default Adafruit 6x8 font provides about 21 characters on each of eight
lines. The fixed display shows two remaining-usage windows with reset
countdowns and bars, followed by today's tokens and sync age:

```text
CODEX USAGE
7D         L75% R4d00h
[==============     ]
5H         L80% R2h00m
[===============    ]
TODAY 12M TOKENS
SYNC 12s
```

The values above are fictional. `L` is remaining percentage and `R` is time
until reset. Task records are still parsed and
retained by the firmware for the unchanged LED rules, but are not drawn.

Long project names and titles in the retained task protocol are converted to
ASCII and clipped. The OLED is one-bit from the controller's perspective, but
this particular panel has fixed
color zones: its top 16 pixel rows are yellow and its remaining 48 rows are
blue. Firmware can switch pixels only on or off; it cannot choose their color.
LED colors provide the aggregate visual status.

## USB serial protocol

The host sends complete snapshots rather than incremental updates:

```text
BEGIN
USAGE|1|12345678|12
LIMIT|7D|75|345600
LIMIT|5H|80|7200
TASK|nix-config|repair flake setup|W|12120|15
TASK|palimpsest|update parser|D|842|93
END
```

Protocol fields:

- `USAGE|available|today_tokens|sync_age_seconds`
- `LIMIT|label|remaining_percent|reset_seconds` (up to two)
- `TASK|project|title|state|elapsed_seconds|state_age_seconds`
- state is `W`, `D`, `I`, `E`, or acknowledged `A`

The firmware stages all rows after `BEGIN` and replaces the visible snapshot
only after `END`. A partial USB write therefore does not produce a half-updated
screen.

Any complete snapshot refreshes the host heartbeat. After 15 seconds without
one, the firmware turns off the blue LED, turns on red, and displays
`HOST LINK LOST`.

## Host heartbeat

Every complete serial snapshot refreshes the host heartbeat. The link LED
therefore reports only whether the laptop bridge and USB serial path are alive;
it is independent of ChatGPT reachability and proxy state.

Silence from a working agent is never used as a disconnect signal because a
legitimate reasoning phase may run for several minutes without tool events.

## State storage and privacy

Runtime state is stored in:

```text
/tmp/codex-board-$UID/state.sqlite3
```

This makes the state writable from sandboxed local commands and disposable at
reboot. Dashboard rows contain session/subagent identifiers, project directory
basename, a short prefix derived from the prompt, state, and timestamps. Full
prompts, assistant replies, transcripts, source code, credentials, and tool
output are not stored.

The `clear` command removes all rows. The daemon and hooks use SQLite locking
so concurrent agents can update the same database safely.

## Hook installation and trust

In the Nix configuration, the bridge is packaged as `codex-board` and its
handlers are merged into the managed Zellij Agent Deck Codex requirements.
This preserves existing Agent Deck handlers and avoids a mutable user hook
file while keeping the services independent.

For a non-Nix installation, `python3 host/codex_board.py install-hooks` merges
the handlers into `$CODEX_HOME/hooks.json` (falling back to
`~/.codex/hooks.json`). Existing files receive a timestamped backup, unrelated
hook groups are preserved, and reinstalling replaces only older dashboard
entries.

Codex requires new or changed non-managed hooks to be reviewed and trusted.
After installing or moving this directory, restart Codex and use `/hooks` to
review the exact commands. `uninstall-hooks` removes only this integration.

The portable example uses a placeholder path; generated hooks always resolve
the actual script location. Managed Nix hooks use an immutable Nix-store path.

## Firmware targets and recovery

`platformio.ini` defines two isolated environments:

- `dashboard` builds `src/dashboard.cpp` and is the default.
- `bringup` builds the preserved `src/main.cpp` electrical self-test.

Switching firmware does not alter wiring. Re-run the self-test with:

```bash
.venv/bin/pio run -e bringup -t upload --upload-port /dev/ttyACM0
```

Restore normal operation with the same command using `-e dashboard`.

The USB serial monitor, firmware upload, and bridge cannot own the port at the
same time. Stop the managed bridge before using either tool:

```bash
systemctl --user stop codex-board
```

The NixOS configuration assigns only Espressif USB serial devices with product
IDs `1001` and `4001` to the normal local `users` group with mode `0660`.

## Electrical safety properties

- OLED power remains 3.3 V.
- GPIO8/GPIO9 remain dedicated to I2C.
- LED GPIOs use the physically verified active-high wiring.
- Firmware writes the inactive LOW level before setting LED pins as outputs.
- It never intentionally changes an LED pin back to input.
- GPIO output never exceeds normal ESP32 3.3 V logic.
- The self-cycling LED receives only on/off control; its internal colors are
  not treated as independently addressable channels.

## Validation record

Completed in software:

- `dashboard` PlatformIO environment builds successfully.
- preserved `bringup` PlatformIO environment builds successfully.
- Python syntax compilation succeeds.
- Thirteen dashboard unit tests cover root task states, input detection, tool
  failure recovery, host-only subagent rows, session-close removal, serial
  filtering/sanitization, usage parsing, hook rendering, and safe hook
  installation/removal.
- The isolated Nix `codex-board` package builds and runs successfully.
- Managed requirements preserve agent-deck metadata and handlers while adding
  independent dashboard lifecycle handlers.
- The Glacier Home Manager activation package, including
  `codex-board.service`, builds successfully.
- The Glacier NixOS module renders group-access rules only for Espressif tty
  product IDs `1001` and `4001`.

Completed physically before the dashboard work:

- OLED, I2C, every LED, forward/backward chase, all-on test, and continuous
  chase were reported working.

Completed physically with the original session-oriented dashboard firmware on
2026-08-28:

- The original OLED rendered a complete three-row demo snapshot with `L:OK N:+` and
  distinct `INPUT`, `RUN`, and `DONE` states.
- The green, yellow, blue, and harder-blue link LEDs illuminated together for
  the mixed demo state.
- The red error LED and self-cycling delayed-alert LED remained off, as
  expected.
- The managed host service connected through USB and the harder-blue link LED
  illuminated.
- A real Codex session generated its short title, transitioned to `DONE`, and
  illuminated green after its task completed.

Not yet physically verified with the usage-focused OLED firmware:

- green-LED update after closing a session with the `SessionEnd` behavior
- usage-window rendering and countdown updates
- heartbeat loss/recovery behavior after removing the independent network probe

Only a physical observation after flashing can mark those items as passed.

## Directory contents

```text
breadboard/
  README.md                       quick start and bring-up instructions
  DASHBOARD.md                    operational setup and troubleshooting
  ARCHITECTURE.md                 design decisions and protocol record
  HARDWARE_BRINGUP_RESULTS.md     reported physical baseline
  platformio.ini                  dashboard and bringup build environments
  requirements.txt               pinned local Python tools
  setup.sh                        creates .venv and installs dependencies
  src/dashboard.cpp              normal dashboard firmware
  src/main.cpp                   preserved hardware self-test firmware
  host/codex_board.py            hook handler, database CLI, and USB daemon
  host/codex-hooks.example.json  concrete hook example for this location
  host/requirements.txt          bridge-only Python dependency
  tests/test_codex_board.py      host-side unit tests
```
