---
name: grill
description: Rewrite the user's prompt to be clearer, then interview them relentlessly about every aspect until reaching shared understanding. Use when the user wants to stress-test a plan, clarify a vague idea, or mentions "grill".
user-invocable: true
---

First, take the prompt or plan in $ARGUMENTS and **rewrite it** — make it clearer, more precise, and better structured. Present the rewritten version and ask if it captures the intent.

Then, interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the decision tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.
