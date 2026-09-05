# Agent desktop and browser tools

## Native desktop

Enable `mine.agent-desktop.enable` in both the NixOS host and Home Manager home.
The system module enables the packaged ydotool daemon and grants the configured
user membership in its socket-access group. The home module installs
`agent-desktop`. Apply both configurations and log out/in for new group membership.
This grants desktop input capability to processes running as that user.

Run commands from the local Hyprland session so `WAYLAND_DISPLAY`,
`XDG_RUNTIME_DIR` and `HYPRLAND_INSTANCE_SIGNATURE` are present. The CLI uses
the NixOS ydotool socket by default and honors `YDOTOOL_SOCKET` overrides.

1. Run `agent-desktop windows` and `agent-desktop monitors` to identify the target.
2. Run `agent-desktop screenshot --monitor <output>` and inspect the PNG at the
   returned path. Output defaults to a private directory inside the session
   runtime directory, outside the repository. `--output` accepts a new file path.
3. Use the returned window address and monitor name for input commands:

   ```sh
   agent-desktop focus --window 0x1234
   agent-desktop click --window 0x1234 --monitor OUTPUT 200 150
   agent-desktop scroll --window 0x1234 --monitor OUTPUT 200 150 down --steps 3
   agent-desktop key --window 0x1234 ctrl+a
   printf '%s' 'Example text' | agent-desktop type --window 0x1234
   ```

4. Take another screenshot or inspect application state to verify the result.

Coordinates are monitor-local logical pixels: `(0, 0)` is the screenshot's top
left, even with scaled, rotated or negatively positioned monitors. Use the
original PNG dimensions if an image viewer scales its preview. Capture again
after a monitor layout change. Click and scroll coordinates must be inside the
target window; the CLI focuses and checks the window before sending input.
Window targeting and a per-session command lock reduce accidental interactions;
the human can still move focus during an action, so avoid simultaneous input.

`key` uses physical US-layout key names, including modifiers, letters, digits,
navigation keys and F1–F12. `type` pastes Unicode text and **replaces the clipboard**;
use `--paste-key ctrl+shift+v` for terminals. Text is not returned in command output.
All normal results and errors are JSON. `--help` describes each command.

## Browser automation

Codex uses the `agent-browser` launcher. The launcher uses the
Playwright MCP and matching Chromium packages pinned by `flake.lock`, with no
runtime npm installation.

Profiles live under `$XDG_STATE_HOME/agent-browsers/codex/`, defaulting to
`~/.local/state/agent-browsers/codex/`, with private permissions. A launcher
leases `primary` or the first available `parallel-N` slot. Every slot is persistent
and has its own cookies/logins; a new parallel slot may need a separate login.
Slots are reused after sessions exit. They are separate from the human's browser.

For a specific reusable identity, configure launcher arguments such as
`--profile research`. A busy named profile fails instead of being
shared. Multiple agents must not manually launch Chromium against the same
profile directory. Existing `/tmp` profiles are not automatically imported.

Restart agent processes after applying Home Manager to load the new MCP command.
Browser profiles and desktop images are runtime state; keep them out of Git,
Nix derivations, instruction files and diagnostic reports.

## Verification

Run these from the repository root:

```sh
python3 -m unittest discover -s packages/agent-desktop/tests
python3 -m unittest discover -s packages/agent-browser/tests
nix build .#agent-desktop .#agent-browser
```

For end-to-end input testing, use a disposable window with synthetic content.
Exercise focus, click, scroll, shortcut and Unicode paste, then inspect the
window's resulting state. For the browser, start concurrent sessions and verify
separate profile directories, then reopen a slot to verify persistence.
