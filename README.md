# Four-Agent Review Pipeline

What should happen when someone clicks Reset in a sidebar with no active filters? If a coding agent chooses the behavior and writes a test for its choice, every check can pass while the product question is still open. This pipeline moves that decision upstream. A person approves the expected behavior, four agents divide up implementation and review, and a person decides whether to merge.

[Follow the Reset example through a full run](flow.md), including what each role receives and where a failed check goes.

## Decide what can run unattended

Ankit Jain argues for reviewing intent before implementation. Matt Pocock's `grill-me` skill gives the agent a way to surface decisions while someone is there to answer. In this workflow, the approved spec keeps those answers available when implementation and testing continue unattended. [Jain's essay](https://latent.space/p/reviews-dead/) · [Pocock's skill](https://github.com/mattpocock/skills/blob/main/skills/productivity/grill-me/SKILL.md)

For example, a person might approve this criterion: start with one active filter, click Reset, and verify that the filter is cleared. Click again and verify that the sidebar stays empty. Checking only that both clicks leave the same state would let a broken button pass.

## Follow the change

| Stage | What happens |
|---|---|
| Human approval | Resolve open product questions and approve the acceptance criteria. |
| [Test Writer](skills/ad-test-skeletons/SKILL.md) | Use the spec and type signatures to outline at least one observable case per criterion. Save the original outline for review. |
| Implementer | Work in a separate Git worktree with the spec, outline, project rules, and codebase. Implement the change and fill in the assertions. |
| [Automated checkpoint](skills/ad-checkpoint/SKILL.md) | Run lint, type checks, and tests. Record results, changes in test count, and which test files changed. |
| [Enforcer](skills/ad-enforce/SKILL.md) | Compare the diff and completed tests with the spec, project rules, original outline, and checkpoint evidence. For Reset, find the assertion that actually checks the filters. Use read-only tools. |
| [Breaker](skills/ad-break/SKILL.md) | Act as an adversarial tester. Start from the changed files in a fresh session and try cases the earlier work may have missed, such as two clicks arriving close together. |
| Human review | Inspect the change set, test evidence, and unresolved questions. Decide whether to merge. |

The test outline comes first, which borrows from test-driven development. The Implementer writes the assertions alongside the change, so the workflow does not require observing a failing test before implementation.

## When a check fails

Show the finding to the person supervising the run. If it exposes an unanswered product question, settle the expected behavior first. For an approved fix, return to the Implementer in the same worktree, then run the checkpoint and subsequent stages again. Escalate if the checkpoint or Enforcer still fails after three retries, or if the Breaker still finds failures after two rounds of fixes.

## Try one change

The [scripts folder](scripts/) contains example Bash scripts for a TypeScript project using pnpm. The checkpoint runs `pnpm lint`, `pnpm typecheck`, and `pnpm test`. The test-counting logic looks for `*.test.ts` and `*.test.tsx`. For another stack, adapt those commands and test patterns. The Git diff and Markdown rule collectors are language-independent.

Copy the shell helpers into your target repository under `scripts/review/`. The examples use Git, Bash, jq, pnpm, and Markdown rule files in `docs/rules/`. Adapt the commands and rule paths to the project before running a review. The optional browser configuration is for runners that support Chrome DevTools MCP.

Start with [the spec template](skills/ad-spec/SKILL.md) and a small change with an observable result. Follow [the orchestration instructions](skills/ad-review/SKILL.md) in order. You can supply the role instructions directly in separate sessions. For a runner with skill discovery, use its documented installation paths and permission settings. Verify read-only access before assigning the Enforcer. The sample frontmatter and invocation syntax depend on runner support.

The four roles can use the same model or different models. A fresh session separates conversation history. Tool permissions determine which files an agent can actually read or edit. See the [design notes](design.md) for the reasoning behind the split, and the [optional browser configuration](mcp.chrome-devtools.example.json) for visual checks.
