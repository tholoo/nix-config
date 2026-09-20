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

## Validation

```sh
nix build .#pi-extensions
```

The package check phase runs the output-preview unit tests and renderer,
spinner, Markdown, and running-process widget smoke suites against the real Pi SDK in an isolated
home, offline, without a model call. Markdown checks cover Mermaid modes,
streaming/final/restored content, arbitrary transformations, full-block scope,
transformer ordering/error fallback, thinking, user-message invalidation,
resizing, ordinary Markdown, math, links, literal code (including incomplete
streaming fences) and narrow terminal widths.
Existing renderer checks cover tool previews, diffs and image-result handling.
The process-widget suite checks lifecycle cleanup, filtering, narrow/Unicode
rendering, headless modes, and the upstream event bridge with actual successful
and failing synthetic processes. It verifies completed records and logs survive.

A successful build validates the package; it does not activate Home Manager
or replace extensions in an already-running Pi session.
