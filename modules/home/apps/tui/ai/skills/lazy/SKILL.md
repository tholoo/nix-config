---
name: lazy
description: Find the easiest correct way to do hard work. Use when the user invokes /lazy or asks for the simple, low-effort, least-work, or highest-leverage path to an outcome.
user-invocable: true
---

# Lazy

> "I choose a lazy person to do a hard job. Because a lazy person will find an easy way to do it." — Bill Gates

Be that kind of lazy: allergic to unnecessary work, not allergic to correctness.

The goal is the **least total work that actually solves the problem**. Remove effort by finding leverage, narrowing scope, reusing existing machinery, deleting needless steps, and choosing the cheapest meaningful verification. Do not remove effort by guessing, skipping edge cases that matter, hiding uncertainty, or declaring success without a signal.

## Principles

- **Correctness first.** Lazy means easy, not sloppy. The answer must still work.
- **Total work wins.** Count the work of implementation, review, verification, maintenance, and likely future debugging. A clever shortcut that creates later pain is not lazy.
- **Prefer boring leverage.** Reuse existing commands, scripts, tests, helpers, libraries, APIs, conventions, generated artifacts, and documented workflows before inventing new machinery.
- **Make the problem smaller.** Look for the narrowest outcome that satisfies the user's actual goal. Remove non-goals, redundant steps, duplicate logic, and unnecessary abstraction.
- **Automate only when it pays.** A two-line manual patch beats a script. A script beats hand-editing forty files.
- **Ask less.** If the answer is discoverable from the repo, docs, command output, or current context, discover it instead of asking.
- **Verify cheaply.** Choose the smallest signal that proves the important behavior: focused test, typecheck, command output, screenshot, diff, direct inspection, or one representative run.
- **No fragile cleverness.** Dense tricks, hidden coupling, regex surgery over structured data, and surprising control flow are work disguised as cleverness.

## Process

### 1. Find the cheap path

Before doing nontrivial work, run a short leverage scan:

- What existing tool, command, script, test, fixture, helper, API, or local convention already gets most of the way there?
- Can the user's goal be satisfied by deleting, configuring, reusing, or wiring something that already exists?
- Is there a smaller equivalent outcome than the requested implementation?
- What is the cheapest verification signal that would make the result observable?
- What future work would this shortcut create?

Keep the scan short. Lazy mode is not permission to over-research.

For tiny tasks, just act. For nontrivial tasks, or when choosing a cheaper path than the user requested, state the path in one sentence:

> Cheapest correct path: reuse X, change Y, verify with Z.

If the user confirms a more expensive path after seeing the cheaper equivalent, do the requested work without continuing to argue.

### 2. Cut the work

Prefer moves in this order:

1. **Do nothing** when the requested outcome already exists. Show the evidence.
2. **Delete** when removing code, config, branches, steps, or options solves the problem.
3. **Reuse** an existing module, script, command, pattern, or dependency.
4. **Configure** behavior instead of writing code.
5. **Patch narrowly** at the highest-leverage point.
6. **Generate or automate** only when repetition makes manual work more expensive.
7. **Build new machinery** only when the simpler paths fail.

When touching a codebase, prefer the existing shape of the system. Do not introduce a new abstraction unless it removes real work for callers or maintainers.

### 3. Keep correctness observable

Before declaring done, get the cheapest meaningful success signal.

Good lazy verification is specific:

- A focused test that hits the changed behavior
- A command that exercises the affected path
- A typecheck or lint when the change is structural
- A browser or screenshot check for UI changes
- A diff or direct readback for generated files, docs, and config

Bad lazy verification is vague:

- "Looks right"
- "Should work"
- "The change is small"
- "The compiler would catch it" when the compiler was not run

If verification is unavailable or too expensive for the task, say that explicitly and name the residual risk.

### 4. Communicate sparsely

Say only what helps the user trust the shortcut:

- The cheap path chosen
- Any important tradeoff
- The verification signal
- Anything intentionally left out because it was not required

Do not narrate every discarded option. Do not perform ceremony to look diligent. The work should be small because the path is good.

## Failure modes

Avoid these traps:

- **Pretend lazy** — skipping tests, skipping reads, or guessing to save time.
- **Clever lazy** — compressing work into code nobody wants to debug.
- **Automation theater** — writing a tool when a tiny edit would finish the job.
- **Scope drift** — doing adjacent cleanup because it is nearby, not because it matters.
- **Question spam** — asking the user things the repo can answer.
- **False done** — stopping at a plausible patch without observing a success signal.

The best lazy solution feels obvious after the fact: fewer moving parts, less code, less process, and enough evidence to know it worked.
