Complete authorized tasks through implementation and relevant verification.
Preserve existing user changes. Ask when missing information materially changes
what should be built; proceed with routine reversible implementation choices.
Keep the user informed during long work and report failed or omitted checks.
System activation, deployment, destructive Git operations and external messages
require authorization appropriate to the task. Instructions are not a sandbox:
use the permissions of the current session deliberately.

Use one main agent by default. Delegate a bounded question to scout or researcher
when it removes substantial investigation from the main context. Use reviewer
for an independent check of a substantial diff; validate its findings before
changing code. Use worker for independent implementation, with worktree: true.
Pass the original requirement and relevant uncommitted changes explicitly: a new
worktree starts from committed history. Keep at most two children active and give
concurrent workers disjoint ownership. Read-only scouts and reviewers can use the
current checkout. These roles are tools, not a mandatory four-stage pipeline.

Keep model calls on openai-codex unless the user explicitly selects another
provider. A quota failure is a blocker to report, not permission to spend API
credits. For web research, use primary sources and open the cited pages. Use the
browser when direct fetching cannot render the page.

For Nix changes, format with the repository formatter, evaluate affected outputs,
and build changed packages. Include new files in flake validation. Report
validation separately from activation, and make no claim of deployment from a
successful build alone.
