---
name: debug
description: Debug an issue methodically — gather info and ask the user to run commands before attempting fixes. Use when the user reports a bug, error, or unexpected behavior.
user-invocable: true
---

Debug the issue described in $ARGUMENTS.

**Do NOT jump into fixing.** Follow this process:

1. **Reproduce** — understand the exact symptoms. Read relevant code, logs, and error messages.
2. **Hypothesize** — form a ranked list of likely causes.
3. **Gather evidence** — for each hypothesis, tell me what command to run or what to check, and wait for the result before continuing. Prefer diagnostic commands (print, log, status, version) over changes.
4. **Narrow down** — eliminate hypotheses one by one based on evidence.
5. **Confirm root cause** — only once you have strong evidence, explain the root cause clearly.
6. **Propose fix** — suggest the minimal fix and ask for confirmation before applying it.

At every step, explain your reasoning. If you need me to run something, ask me — do not run destructive or mutating commands yourself.
