# Pi configuration

`mine.pi.enable` installs the Pi release pinned by `llm-agents` and a separate
locked package containing MCP, web search, subagents, background processes and goals.
The initial lock contains `pi-mcp-adapter` 2.34.0, `pi-web-access` 0.29.0,
`pi-subagents` 0.68.0 and `@aliou/pi-processes` 0.12.0. The initial default is
`openai-codex/gpt-6-astra` with high reasoning; `mine.pi.model` changes the model.
The core has no local TUI patches. Runtime startup does not install packages or
check for updates (`PI_OFFLINE=1`); model requests and requested tools still use
the network. Update the flake input and extension lock deliberately.

The extension derivation compiles TypeScript ahead of time while preserving
directory structure, adjacent assets and `import.meta` paths. Pi still supplies
the SDK; the package does not install a second SDK runtime. The MCP adapter uses
only its managed server configuration instead of discovering other clients'
configuration during startup. Individual server tools can still have first-use
costs, including the existing deployment server's pinned npm launcher.

The Home Manager module owns startup defaults and package paths. Activation
atomically merges managed top-level settings into a writable settings file,
retaining other preferences. A malformed existing file stops activation instead
of being discarded. Managed sections, including packages and model scope, replace
old values rather than combining extension lists. Authentication, trust decisions,
sessions and generated runtime state remain outside the repository and Nix store.
No activation is performed by a package build.

Activation also removes obsolete empty regular files named `settings.json.lock`
and `auth.json.lock`: Pi 0.85.1 expects lock directories and otherwise reports
`ENOTDIR` before loading settings or discovering authenticated models. Migration
leaves credentials untouched, preserves directory, symlink and nonempty locks,
and refuses to remove a file locked by another process. The regression checks
cover this existing-profile upgrade case in addition to fresh profiles.

OpenAI subscription auth is selected with `openai-codex`; API-key fallback is not
configured. Run `/login openai-codex` if the existing login has expired or is
missing. Model availability requires a live account check. Pi's model picker is
scoped to that provider; subagents also enforce their provider scope. Trusted
project configuration can override user settings. These settings are not an OS
sandbox or a billing boundary for arbitrary extensions and shell commands.

## Tools and agents

Shared MCP definitions live independently of the Codex module. Pi translates
supported fields explicitly, including per-request authentication helpers. Browser
servers connect on first use and stay alive for the session. Other servers are
lazy. Tools are exposed through search instead of an eagerly expanded catalog.
MCP service entries marked as requiring write approval are conservatively gated
for all tool calls until a reviewed mutation allowlist is available.

See [agent-tools.md](agent-tools.md) for desktop and browser operation. Pi's
Playwright launcher uses `--agent pi`, preserving separate persistent identities
from Codex. Zen is the shared human browser and must be used serially.

The four agent definitions are scout, researcher, reviewer and worker. Builtin
extra roles are disabled. Children inherit repository and host instructions;
only researcher loads the web extension and uses a background child. Models
inherit the parent within the OpenAI subscription scope. Scouts and researchers
have explicit tool allowlists. Reviewer has shell inspection access, so its
read-only instruction is not a security boundary.

Worker launches should use `worktree: true`, with relevant uncommitted context
provided explicitly. There is no automatic pipeline, commit or merge. At most
two children run concurrently by default, with nesting bounded to one level.
Use these roles only when their independent task is useful; their presence does
not establish a code-quality improvement.

No custom personal extension, external memory store, Telegram integration,
auto-fixing LSP suite, alternative statusline or second orchestrator is enabled.
Shared skills are loaded from the same source used by the other coding agents.

## Goals

`@narumitw/pi-goal` 0.54.5 adds an explicit, session-scoped objective to the main
agent. It is not loaded in children. Ordinary requests do not start a goal;
`/goal <objective>` does. No plan extension is installed.

```text
/goal Fix the failing integration tests, verify the build, and leave a reviewable diff. Do not commit.
/goal status
/goal pause
/goal resume
```

Pi continues after queued work, retries and compaction have settled, until the
goal completes, reaches a blocker or limit, or is paused. `/goal pause` aborts the
current goal turn while retaining its state; `/goal clear` removes the objective
but does not cancel unrelated background work. Resume the same Pi session to
restore its goal. A new session does not inherit it.
Completed goals are recorded in the session history and then cleared from the
active slot, so another goal can start immediately.

The package defaults pause after 25 automatic model responses (including tool
loops) or three repeated tool-free no-progress outputs. The user-triggered kickoff
is not counted against the automatic-response limit. These are continuation
limits, not a cap on total subscription usage or child-agent usage. Use `/goal`
and its Settings menu to adjust them; the optional settings file stays writable
outside the Nix store. Managed-run RPC remains disabled by default.

An optional per-goal token budget goes before the objective:

```text
/goal --tokens 100k Fix the regression and verify the relevant tests. Do not commit.
```

Goal mode adds persistence, not permissions or an independent proof of success.
Its completion tool requires an evidence summary, but that summary still needs
to be checked against actual results. Existing subscription routing and agent
concurrency settings continue to apply.

## Validation

Run the settings and browser Python tests, format changed Nix files with the
flake formatter, evaluate affected home/host outputs and build `pi-extensions`,
`agent-browser` and the configured `mine.pi.package`. When validating a Git-backed
flake, include newly added files in its source; a temporary source snapshot can
be used without committing or staging unrelated work.

Initial home and host evaluation used tracked working files plus this change's
new modules and package. Unrelated untracked modules were excluded; including the
unfinished mail module exposed a pre-existing missing `mailserver` option. This
does not establish that all unrelated working-tree additions evaluate together.

Use an isolated `PI_CODING_AGENT_DIR` and synthetic content for smoke tests.
Measure time to interactive input, startup with empty and warm extension caches,
and large-session resume separately. `PI_TIMING=1` reports startup phases.
Measure the first model response separately; a responsive editor is not proof
of a successful provider request. Load extensions incrementally and retain
aggregate timings, never real prompts, tokens, service responses or profiles.

Initial isolated measurements with Pi 0.85.1 on this machine were approximately
24 seconds for a fresh TypeScript extension path, 13 seconds for a fresh compiled
path, and 3–6 seconds for warm compiled starts. These are wall-clock startup
benchmark times with empty MCP configuration and no account requests, not a
controlled comparison against the previous installed setup or a cold OS cache.
Compilation improves first load but does not eliminate the remaining delay;
subagent imports account for most extension loading time. Session resume and
live provider latency remain unmeasured.

Synthetic provider checks exercised scout and reviewer calls, a worker in a
temporary clone's native worktree, and a background researcher with web tools.
They verify runtime wiring and result delivery, not model quality or live
subscription access. The worker fixture intentionally made no edits or test
claims, so its normal acceptance-evidence check remained unsatisfied.

Goal checks with all five packages loaded and a local synthetic provider passed
ordinary-request isolation, completion, explicit pause and clearing, automatic continuation,
the repeated-no-progress pause, paused-session restoration, resume to completion,
and usage-limit stopping. These checks use a temporary profile and session files,
without account requests; they establish lifecycle behavior, not model judgment.

The goal-enabled startup smoke measured about 21 seconds with an empty extension
cache and 16 seconds on the next start. The goal extension's own import/factory
timings were approximately 280 ms and 53 ms respectively. These runs had no
matched baseline and do not establish a regression or a speedup; overall startup
latency remains variable and is not resolved by adding goals.
