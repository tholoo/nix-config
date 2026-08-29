# Security and privacy

This project needs no API key, Codex token, Wi-Fi password, or other secret.
The ESP32 receives only compact task-status and aggregate usage metadata over
the local USB cable.

## Data handled

The hook reads Codex lifecycle event JSON from standard input, but persists
only session/subagent identifiers, the project directory basename, a short
prefix derived from the submitted prompt, state, and timestamps. It does not
persist complete prompts, assistant responses, transcripts, source code, tool
arguments, tool output, environment variables, or credentials.

Runtime state lives in `/tmp/codex-board-$UID/state.sqlite3` with a private
state directory. `codex-board clear` deletes the tracked rows. State is
normally removed by the operating system at reboot.

Zellij Agent Deck receives the same lifecycle event and independently stores a
bounded, normalized prefix of the prompt in its private runtime state. There
is no shared title registry or publisher service.

The Nix composition wraps Agent Deck's existing `mark-read` command only to
forward the sanitized task key to `codex-board acknowledge`. It does not pass
the title, prompt, message, project path, or Agent Deck record contents.

The `SessionEnd` hook deletes the closed root session and all of its subagent
rows. Completed task metadata therefore remains only while that Codex session
is open, unless the hook is unavailable or interrupted.

The serial protocol carries project basename, short title, state, elapsed
time, state age, aggregate remaining percentages/reset times, and today's
token count. It carries no account or installation
identifier, plan name, device serial number, USB identifier, source content,
or authentication material.

## Network behavior

The bridge makes no independent network-reachability request. It reads
aggregate usage through the locally authenticated Codex app server and does
not embed or log authentication data. Standard proxy environment variables may
still be honored by Codex while retrieving account usage.

## Codex hooks

The Nix integration installs the immutable `codex-board` command and merges
its handlers with existing managed hooks. The fallback dashboard
`install-hooks` command edits only `$CODEX_HOME/hooks.json`, creates a
timestamped backup, and preserves unrelated hook groups.

On Glacier, a Home Manager user service runs the bridge after login. Its udev
rule assigns only tty devices with Espressif vendor ID `303a` and product ID
`1001` or `4001` to the normal local `users` group with mode `0660`; it does
not grant access to arbitrary serial devices.

Hook exceptions are reported to standard error and return success so the
dashboard cannot block an ordinary Codex task.

## Repository audit

On 2026-08-28 the source and documentation were scanned for common API-key,
token, password, private-key, device-serial, and MAC-address patterns. No
secret or device-unique identifier was found. Personal absolute paths in tests
and examples were replaced with generic placeholders. Local build directories,
virtual environments, firmware artifacts, and Python bytecode are ignored.

No automated scan can prove that future edits contain no secret. Before
publishing, review the staged diff and repeat a secret scan with a dedicated
tool if the project ever begins handling credentials.
