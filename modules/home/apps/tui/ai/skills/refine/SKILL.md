---
name: refine
description: Rewrite rough user intent into a precise, executable prompt. Use when the user asks to refine, rewrite, sharpen, clarify, or improve a task, plan, spec, bug report, or implementation request.
---

# Refine

Turn the user's request in $ARGUMENTS into a prompt that can be executed without guesswork.

The refined prompt should preserve intent, remove ambiguity, and expose the few decisions that actually matter.

Do not make the request sound more sophisticated than it is. Make it more useful.

## Principles

- **Preserve intent.** Do not silently change the user's goal, scope, risk tolerance, or desired outcome.
- **Make success observable.** A good prompt says what done looks like.
- **Separate facts from assumptions.** Do not bury guesses inside the rewritten request.
- **Collapse vague verbs.** Replace "fix," "improve," "clean up," "make better," and "look into" with concrete work.
- **Expose decisions.** If two reasonable interpretations would lead to different work, surface the choice.
- **Ask less.** Only ask questions whose answers would materially change the result.
- **Use the project's language.** When a codebase is involved, prefer names from existing files, docs, domain terms, and architecture vocabulary over generic labels.

## Process

### 1. Understand the request

Identify:

- The actual outcome the user wants
- The object of the work: file, feature, system, bug, design, plan, or decision
- The constraints: time, quality bar, compatibility, style, safety, ownership
- The evidence that would prove the task was completed

If the request references a codebase, inspect enough of the repo to use real names. If the answer is discoverable locally, do not ask the user for it.

### 2. Remove ambiguity

Find the ambiguous parts of the request:

- Undefined nouns: "it," "the flow," "the backend," "the architecture"
- Vague outcomes: "better," "cleaner," "robust," "modern," "proper"
- Hidden constraints: compatibility, migration, rollout, performance, tests
- Missing evidence: no repro, no expected output, no acceptance criteria
- Unclear authority: whether to implement, propose, review, or ask questions first

Resolve what can be resolved from context. Leave the rest as explicit questions.

### 3. Rewrite

Write a prompt in the user's voice, but with sharper structure.

The prompt should:

- Start with the desired outcome
- Name the concrete scope
- State non-goals when they prevent scope drift
- Include acceptance criteria
- Include verification steps
- Specify how to handle uncertainty

For bug reports, include the observed symptom, expected behavior, reproduction path, and the fastest feedback loop available.

For implementation requests, include affected surfaces, expected behavior, tests to run, and any compatibility constraints.

For architecture requests, name the modules, interfaces, seams, locality problems, and leverage goals when known. If those are unknown, make discovery part of the prompt.

For planning or product requests, state the decision to be made, the criteria for choosing, and the unresolved tradeoffs.

### 4. Ask only load-bearing questions

Ask no more than five questions.

Each question must meet at least one condition:

- The answer changes the implementation
- The answer changes the scope
- The answer changes the acceptance criteria
- The answer changes the risk profile
- The answer prevents wasted work

For each question, include a recommended answer when you have one.

## Output

Return:

1. **Refined Prompt** — the rewritten request, ready to paste into a new chat or issue.
2. **Acceptance Criteria** — observable outcomes.
3. **Verification** — tests, commands, repro steps, review checks, or screenshots.
4. **Assumptions** — guesses you made to keep the prompt moving.
5. **Questions** — only the unresolved questions that materially affect the work.

Do not implement the refined prompt unless the user explicitly asks you to continue.
