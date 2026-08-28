# Shared Codex session titles

`codex-title` is the neutral source of truth for short, generated Codex task
titles. It is independent of Breadboard, Zellij Agent Deck, and any future
consumer.

Codex writes a title once:

```bash
codex-title set --session SESSION_ID --title "Short task title"
```

Any process can read the title without knowing about its current consumers:

```bash
codex-title get --session SESSION_ID
codex-title get --session SESSION_ID --json
codex-title list
```

Records are private per-session JSON files under
`$CODEX_TITLE_STATE_DIR`, or under `$XDG_RUNTIME_DIR/codex-titles-$UID` by
default. Session IDs are hashed in filenames. The JSON API contains `schema`,
`session`, `title`, and `updated_at` fields. Hook payloads and prompts are never
stored, and runtime records live outside the source repository.
The managed `SessionEnd` hook removes a closed session's registry record;
runtime-directory cleanup at reboot is the fallback.

## Live consumers

`set` also publishes the canonical title to each executable in
`$CODEX_TITLE_SINK_DIR`. A sink receives this stable argument contract:

```text
SINK --session SESSION_ID --title TITLE
```

Sinks are isolated, best-effort adapters. A missing, failed, or slow sink does
not prevent the registry from storing the title or notifying other sinks. The
Nix composition currently installs adapters for Breadboard and Zellij Agent
Deck; neither service knows about the other. A future live consumer can add an
adapter, while read-only consumers need only the CLI or JSON API.
