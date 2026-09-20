# Pi extension bundle

Dependencies are pinned in `package.json` and `package-lock.json`. Pi supplies
its own SDK/TUI runtime; `compile.py` keeps those imports external.

## Claude UI compatibility patches

The source is upstream [`pi-claude-code-ui`](https://github.com/FammasMaz/pi-cc-tools),
currently pinned to 1.0.83. Patches apply in the order in `default.nix`, with
zero fuzz so upstream drift fails the build rather than silently losing a fix:

- `claude-ui-previews.patch`: bounded completed-tool previews.
- `claude-ui-process-commands.patch`: retain background-process launch commands.
- `claude-ui-spinner.patch`: compact activity indicators.
- `claude-ui-markdown.patch`: retain Pi's Markdown options and transformation
  pipeline when replacing assistant/thinking components; invalidate the user
  message cache when core invalidates or rebuilds its content; protect literal
  code from the UI's math formatting.

Markdown transformations must run **once on the full message block**, with its
message type, streaming state, and actual available content width, before the
UI splits out display math. This includes built-in Mermaid and arbitrary
extension transformers. Source messages must remain unchanged. Pi's Mermaid
mode remains authoritative; there is no UI-specific enable flag.

Keep this as a patch stack for now. If migrating to a maintained fork later,
carry over these regression tests and upstream provenance, then pin the fork
revision rather than retaining a second patch stack.

## Running-process status companion

`processes-status.ts` is a local, read-only extension; `@aliou/pi-processes`
remains unpatched. Home Manager disables the stock status widget and loads this
companion only when process management is enabled.

The companion reads `processes:request:list` on startup and on
`processes:changed`, then displays only live jobs below the editor. It hides
itself when none remain. Stopping jobs and jobs whose stop timed out remain
visible because they may still be running. Successful, failed, and killed
process records and logs are untouched and remain available through `/ps`.
The dock, notifications, process tool, and `/ps:clear` retain upstream behavior.

There is no polling, automatic clearing, or replacement of the process tool.
Listeners are removed on shutdown/reload; RPC/JSON/print modes do not install a
TUI widget. The small event-bus contract is verified against the pinned package
in the smoke test. Names are sanitized and rendering is width-bounded.

## Permission gate and Codex auto-review

`@gotgenes/pi-permission-system` 32.1.0 enforces tool permissions, with
`@mzwing/pi-permission-auto-review` 0.4.0 registered as its `auto-review`
authorizer. Home Manager installs writable configs from
`modules/home/apps/tui/pi/{permissions,permission-review}.json` into the matching
`~/.pi/agent/extensions/<package-name>/config.json` locations. Managed fields are
restored on activation; unrelated preferences are retained. The extensions'
`/permission-system` and `/permission-auto-review` commands remain available.

The policy defaults to `ask`, allows ordinary file-inspection tools and user
questions, and explicitly sends shell commands through review. The `process`
tool's command/cwd arguments also use the shell gate; non-launch actions still
pass through the generic tool gate. No custom Git denylist is installed, and
YOLO mode is off. Outside-workspace access remains `ask`, but is delegated to
the configured reviewer before human fallback. This includes read/write variants,
symlink-resolved skill paths, shell/background calls, and forwarded child asks.
It is not an outside-workspace allowlist: a model denial still blocks, and an
unavailable reviewer still requires human approval. Explicit `path` asks remain
human-only, and deterministic path/outside-directory denies remain authoritative.

The reviewer uses `openai-codex` / `codex-auto-review` with the existing Codex
login and its bundled baseline policy, not an API-key provider. Missing auth,
invalid responses, or unavailable reviewers fall back to normal permission
handling (a prompt with a UI, refusal when approval cannot be obtained).
These are permission checks, **not a sandbox** or server-side branch protection.
Trusted project configs and session approvals can change the effective policy.

Both extensions are explicitly loaded in native subagents, including the
researcher whose extension list overrides defaults. The pinned subagent runner
publishes `PI_SUBAGENT_PARENT_SESSION`, allowing child asks to reach the parent's
reviewer/UI. This does not retrofit external CLI runners with Pi's tool hooks.

The gate's extensionless `#src` aliases are resolved at build time, and its
public service is bundled separately. Both use the same session-keyed
`Symbol.for()` registry. Tree-sitter's WASM files and Pi's SDK stay external;
the auto-review package already ships compiled ESM.

`permission-external-review.patch` intentionally changes the pinned gate's
`src/authority/delegation-envelope.ts`: it removes only the `external_directory`
family from the surfaces that automatic authorizers cannot approve. The `path`
family and missing-surface fallback are untouched. The patch applies with zero
fuzz before bundling, so upstream drift fails the build. This is a local policy
choice, not upstream's default; the reviewer package itself remains unpatched.

## Desktop completion notifications

`desktop-notify.ts` sends one native `notify-send` notification when the root
interactive Pi session reaches `agent_settled`, after retries, compaction, and
queued follow-ups have finished. Individual tool/model turns, subagents,
headless/RPC sessions, cancelled runs, and sessions without a desktop D-Bus
address do not notify. Terminal errors get a distinct notification instead of a
success message. Duplicate settled events are coalesced, including while a
notification is being delivered. Delivery is bounded and failure only adds a UI
warning; it does not fail the completed agent turn.

Only a sanitized project basename and generic completion status are shown—never
assistant output, tool results, or error details. Arguments are passed directly
to the executable, not through a shell. No terminal OSC sequence or bell is sent.

Home Manager enables this through `mine.pi.enableNotifications` by default on
GUI-tagged homes and supplies an absolute `PI_NOTIFY_SEND` path from `libnotify`.
It is not included in native subagent extension lists. The Ghostty module
separately disables `desktop-notifications` and sets `notify-on-command-finish`
to `never`, avoiding terminal-generated duplicates globally. Other applications'
native desktop notifications are unaffected. Reload Ghostty's configuration
(or restart it), and activate/restart Pi to pick up the respective changes.

## Validation

```sh
nix build .#pi-extensions
```

The package check phase runs the output-preview unit tests and renderer,
spinner, Markdown, running-process widget, permission, and desktop-notification smoke suites against
the real Pi SDK in an isolated home, offline, without a real model call. Markdown checks cover Mermaid modes,
streaming/final/restored content, arbitrary transformations, full-block scope,
transformer ordering/error fallback, thinking, user-message invalidation,
resizing, ordinary Markdown, math, links, literal code (including incomplete
streaming fences) and narrow terminal widths.
Existing renderer checks cover tool previews, diffs and image-result handling.
The process-widget suite checks lifecycle cleanup, filtering, narrow/Unicode
rendering, headless modes, and the upstream event bridge with actual successful
and failing synthetic processes. It verifies completed records and logs survive.

Permission checks use the managed configs and a synthetic Codex provider. They
exercise registration/load order, shell approvals and denials, background
process launches and stdin, authentication/response failures, outside-directory
approvals/denials and symlinked skill reads, explicit path restrictions,
headless-child forwarding (including outside paths), and missing-reviewer fallback. Commands in
these permission fixtures are inspected, never executed; this does not test live
Codex authentication or the real model's classification quality.

Desktop-notification checks exercise settled-run deduplication, retries and
follow-ups, cancellation/error handling, root/subagent and mode filtering,
missing D-Bus, session resets, label sanitization, and delivery failures with a
fake executable boundary. They do not send real desktop notifications.

A successful build validates the package; it does not activate Home Manager
or replace extensions in an already-running Pi session.
