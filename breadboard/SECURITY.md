# Security and privacy

This project needs no API key, Codex token, Wi-Fi password, or other secret.
The ESP32 receives only compact task-status metadata over the local USB cable.

## Data handled

The hook reads Codex lifecycle event JSON from standard input, but persists
only session/subagent identifiers, the project directory basename, a short
generated title, state, and timestamps. It does not persist prompts, assistant
responses, transcripts, source code, tool arguments, tool output, environment
variables, or credentials.

Runtime state lives in `/tmp/codex-board-$UID/state.sqlite3` with a private
state directory. `codex-board clear` deletes the tracked rows. State is
normally removed by the operating system at reboot.

The `SessionEnd` hook deletes the closed root session and all of its subagent
rows. Completed task metadata therefore remains only while that Codex session
is open, unless the hook is unavailable or interrupted.

The serial protocol carries project basename, short title, state, elapsed
time, state age, and the network result. It carries no device serial number,
USB identifier, source content, or authentication material.

## Network behavior

The bridge makes a small HTTPS reachability probe to `https://chatgpt.com`.
It does not call an AI API and sends no dashboard task data in that request.
Standard proxy environment variables may be honored by Python's URL opener.

## Codex hooks

The Nix integration installs an immutable `codex-board` command and merges its
handlers with existing managed hooks. The fallback `install-hooks` command
edits only `$CODEX_HOME/hooks.json`, creates a timestamped backup, and preserves
unrelated hook groups.

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
