# Security and privacy

This project needs no API key, Codex token, Wi-Fi password, or other secret.
The ESP32 receives only compact task-status and aggregate usage metadata over
the local USB cable.

## Data handled

The hook reads Codex lifecycle event JSON from standard input, but persists
only session/subagent identifiers, the project directory basename, a short
generated title, state, and timestamps. It does not persist prompts, assistant
responses, transcripts, source code, tool arguments, tool output, environment
variables, or credentials.

Runtime state lives in `/tmp/codex-board-$UID/state.sqlite3` with a private
state directory. `codex-board clear` deletes the tracked rows. State is
normally removed by the operating system at reboot.

Generated titles also live in private JSON records under
`/tmp/codex-titles-$UID` (or `$CODEX_TITLE_STATE_DIR`). The directory is mode
`0700`, records are mode `0600`, and filenames contain a hash rather than the
session ID. `codex-title clear` deletes these records. The immutable Nix sink
directory contains only the configured local Breadboard and Agent Deck
adapters; sinks receive the session ID and short title, never the original
prompt. A user-level path unit republishes changed records outside the Codex
sandbox; it does not add fields or copy them into the source repository.

The managed `SessionEnd` hook deletes the matching shared title record. A
reboot removes any record left behind if session cleanup was interrupted.

The Nix composition wraps Agent Deck's existing `mark-read` command only to
forward the sanitized task key to `codex-board acknowledge`. It does not pass
the title, prompt, message, project path, or Agent Deck record contents.

The `SessionEnd` hook deletes the closed root session and all of its subagent
rows. Completed task metadata therefore remains only while that Codex session
is open, unless the hook is unavailable or interrupted.

The serial protocol carries project basename, short title, state, elapsed
time, state age, aggregate remaining percentages/reset times, today's token
count, and the network result. It carries no account or installation
identifier, plan name, device serial number, USB identifier, source content,
or authentication material.

## Network behavior

The bridge makes a small HTTPS reachability probe to `https://chatgpt.com` and
reads aggregate usage through the locally authenticated Codex app server. It
does not embed or log authentication data, and sends no dashboard task data in
the reachability request. Standard proxy environment variables may be honored.

## Codex hooks

The Nix integration installs immutable `codex-board` and `codex-title` commands
and merges their handlers with existing managed hooks. The fallback dashboard
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
