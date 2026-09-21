---
name: record-preference
description: Record explicit personal coding/agent preferences as training data when the user prefers one implementation, design, API, or structure over another; rejects agent work and accepts or deliberately directs a replacement; corrects a design choice with a reusable subjective preference; or explains a recently recorded preference. Exclude ordinary bug/correctness fixes, restated requirements, silence, and routine edits. Also use when explicitly asked to record a preference.
---

# Record preference

Capture explicit preference events in `~/.local/share/agent-preferences/records/` as UTF-8 YAML, one self-contained record per event. This is a dataset, not coding context: read records only to record, deduplicate, or attach an explanation for this invocation. Do not modify `AGENTS.md`, build training/retrieval machinery, or load the dataset into ordinary coding sessions.

## 1. Establish the event

Manual `/skill:record-preference` or `/record-preference` is explicit instruction to record the relevant event in the current conversation/work, not evidence for an invented comparison. Any trailing arguments narrow the target. For `dry-run`, preview only; never write to the real dataset.

Automatic use requires reasonable evidence of a subjective, stylistic, or design preference. Identify an agent-produced rejected implementation/change/design and the replacement the user explicitly accepted or deliberately directed. A precise user-directed design is eligible even before implementation; record it as a design, not as implemented code. A vague wish for improvement is insufficient.

The only gold label is **the complete accepted state > the complete rejected state**, in this task's context. It is neither an absolute acceptability label nor a universal rule. Preserve the actual user words that establish rejection and acceptance/direction, with source locators. One statement can establish both.

Tests passing, silence, elapsed time, continuing the conversation, Git history alone, and unchanged agent output are not preference evidence. Ordinary bug fixes, objective correctness repairs, restated requirements, and unendorsed edits are not automatic recording events. If a transition mixes correctness and preference changes, retain the coupled full transition and flag that mixture in the annotations; do not turn the correctness repair into a standalone preference.

If either side or the explicit preference evidence cannot be identified reliably, do not save a record. For manual requests, ask a focused question for the missing evidence/version. For automatic candidates, defer rather than interrupt for weak evidence. Completion: both sides and the user's explicit choice are identified, or recording stops with the gap explained.

## 2. Recover and bound the transition

Use the current conversation, the agent's previous proposals/tool edits, and relevant current files, staged/unstaged diffs, or Git snapshots as needed. Git helps recover content, not user intent. Inspect read-only; do not reset, checkout, stage, save editor buffers, or change project code to reconstruct a version.

Identify the task, the relevant pre-decision base/context, the rejected agent version, and the accepted version. Current code is not automatically the accepted version: bind it to the user's evidence and exclude later unrelated changes. Use source locators that actually exist (message/tool IDs when available, otherwise a precise conversational locator; file/revision/range for observed code). Mark reconstruction from observed edits as such. Never fabricate quotes, IDs, timestamps, or missing code. Unknown metadata is `null`; missing base content may be noted if both compared states are still recoverable.

Keep the entire decision-bearing transition, including interacting changes across files/call sites. Omit unrelated working-tree edits and huge irrelevant files, and describe the scope/exclusions explicitly. Prefer base-relative unified diffs plus embedded relevant base code when they preserve both sides unambiguously; otherwise use complete scoped snapshots or exact design excerpts. Include imports, contracts, callers, or surrounding code needed to understand the choice. No ellipses in decision-bearing content. Git hashes/paths alone, prose summaries, or chunks alone cannot substitute for the full pair. If content was truncated, retrieve it before recording.

The record must be intelligible without access to the original repository/session. Avoid credentials and irrelevant private data; use consistent explicit redaction markers on both sides and describe redactions. If redaction would erase the decision, stop and ask. Completion: an authoritative, self-contained pair covers the full event at a declared scope.

## 3. Annotate without relabeling

Under `model_annotations`, give the full transition three separate annotations:
- `rejected_description`: concrete, neutral properties of the rejected state.
- `accepted_description`: corresponding concrete, neutral properties of the accepted state.
- `preference_delta`: best-effort inference about the direction of preference, not a user quotation or ground-truth rationale.

Ground descriptions in the actual artifacts. Replace vague praise such as “cleaner” or “more maintainable” with the specific structural difference. Record uncertainty and mixed correctness/preference changes in `caveats`.

When more than one conceptually distinct change exists, add semantic chunks. Each chunk references both sides of the authoritative pair (artifact IDs and exact ranges/hunk headings/symbols), with its own descriptions and inferred delta. Use `related_chunk_ids` and `interaction` to retain dependencies, overlaps, and trade-offs. All chunks are model-generated structural annotations: **no independent chunk preference labels**. For a single concept, `chunks: []` is sufficient.

Store an explicit user explanation separately, verbatim, with its source and recording time. Preserve qualifications and scope. A user's explanation has stronger rationale provenance than the inferred delta; retain both, even if they disagree. Completion: observations, inferred rationales, and direct user explanations remain distinguishable.

## 4. Schema v1

Use these exact keys and types. The YAML below is a template, not a record to save. Replace placeholders from evidence; use `null` for unknown optional scalars and `[]` for empty lists. Timestamp strings are quoted ISO-8601 UTC. `recorded_at` is capture time; `event_at` is nullable if the event time is unknown.

```yaml
schema_version: 1
record_id: "<UTC timestamp>-<UUIDv4>"
recorded_at: "<capture time>"
event_at: null
updated_at: null
source:
  harness: pi
  session_id: null
  model: null
project:
  name: null
  repository_root: null
  revision: null
  languages: []
  file_paths: []
task:
  context: "<original task or bounded, faithful context summary>"
  source: "<actual task locator>"
base:
  context: "<relevant pre-decision context; disclose unknowns>"
  artifacts: []
full_transition:
  scope: "<all decision-bearing changes included; unrelated exclusions>"
  representation: scoped_snapshots
  rejected:
    - id: r1
      path: null
      language: null
      source: "<agent proposal/tool edit/file-revision locator>"
      content: "<complete rejected content within scope>"
  accepted:
    - id: a1
      path: null
      language: null
      source: "<accepted replacement or user-directed design locator>"
      content: "<complete accepted content within scope>"
  redactions: []
gold_preference:
  label: "accepted > rejected"
  scope: full_transition
  acceptance_kind: explicit_acceptance
  rejection_evidence:
    - quote: "<exact user words>"
      source: "<actual user-message locator>"
  acceptance_evidence:
    - quote: "<exact user words>"
      source: "<actual user-message locator>"
user_explanations: []
model_annotations:
  full_transition:
    rejected_description: "<concrete property>"
    accepted_description: "<corresponding concrete property>"
    preference_delta: "<model-inferred direction>"
  chunks: []
  caveats: []
provenance:
  gold_preference: explicit_user_preference_evidence
  user_explanations: direct_user_explanation
  model_annotations: model_generated_annotation
  artifacts: source_grounded_content_not_preference_labels
  task_and_base_context: source_grounded_model_summary
```

`representation` is `scoped_snapshots`, `base_diffs`, or `design_excerpts`. In `base_diffs`, both sides contain unified patches against the **same embedded base**, not against each other; `base.artifacts` uses the same artifact shape (`id`, `path`, `language`, `source`, `content`). Include enough base content to reconstruct both scoped versions. In snapshots, a `null` artifact content explicitly denotes absence (added/deleted artifacts), not an unknown version; document this in scope. Artifact IDs are unique within the record. Use YAML literal blocks (`|`) for multiline code, patches, and quotes.

`acceptance_kind` is `explicit_acceptance` or `explicit_direction`; the latter means the user deliberately chose the represented target, not that implementation or testing finished.

Each `model_annotations.chunks` entry has this shape; side locators must resolve to the full pair:

```yaml
id: c1
rejected_side:
  - artifact_id: r1
    locator: "<exact lines, symbol, or patch hunk>"
accepted_side:
  - artifact_id: a1
    locator: "<exact lines, symbol, or patch hunk>"
rejected_description: "<concrete property>"
accepted_description: "<corresponding property>"
preference_delta: "<model inference, not independent gold>"
related_chunk_ids: []
interaction: "<relationship to other chunks, or none>"
```

Each `user_explanations` entry contains `quote`, `source`, and `recorded_at`. Do not generate entries when no explanation was given. The rejection/acceptance evidence may also contain an explanation; copy that rationale faithfully here rather than substituting a model paraphrase.

## 5. Validate and publish

Before writing, check the current conversation's recording receipts to avoid recording the same event twice. Read only specifically relevant records if needed, not the whole dataset. Repeated manual invocation of the same event should return the existing path, not duplicate it.

Parse the candidate with an available safe YAML parser (no arbitrary object construction or duplicate keys). Check required fields/types, unique artifact/chunk IDs, resolvable chunk references, valid representation/acceptance kind, explicit user evidence on both sides, complete artifacts, and absence of independent chunk labels. Ensure there are no template placeholders or invented provenance. For base diffs, check that both patches reconstruct the scoped states in a temporary directory, never the working tree. If validation cannot be completed, report the limitation and do not publish an unchecked record.

Use existing shell/Python/Node tools, not a new persistent CLI. Create the records directory if necessary. Generate the timestamp and a fresh UUIDv4 at runtime; the filename is `<record_id>.yaml`. Default to private directory/file permissions (0700/0600). Publish append-only with an atomic **no-overwrite** operation: for example, write and fsync a uniquely created temporary file in the records directory, then hard-link it to the final filename and unlink the temporary name. Retry with a new ID on collision. A check-then-normal-write sequence or overwrite-capable rename is insufficient for new records. Clean up only temporary files created by this invocation.

Re-read and parse the published record and report its ID/path with a one-sentence description. Records otherwise remain immutable. No source-code edits, commits, instruction updates, or model training are part of recording.

## 6. Attach a subsequent explanation

When the user explains a recently recorded preference, use the receipt/event in this conversation to identify that exact record. Do not select the globally newest file: concurrent sessions may be recording unrelated events. If the target is ambiguous, ask which record. If there is no existing record, create one only if the full event satisfies the earlier evidence checks.

For a just-recorded event, append the verbatim explanation to `user_explanations` and set `updated_at`; preserve all prior explanations, the original pair, gold evidence, and model annotations unchanged. Deduplicate an already-attached explanation. Lock the specific record with a stable advisory lockfile (outside the `*.yaml` set), re-read under that lock, validate the explanation-only change, then atomically replace the file using a same-directory temporary file. All explanation writers must use the same lock path, `<record path>.lock`. This is the sole in-place update exception; do not use it to revise historical labels or rationales. Re-read and report the updated record path.
