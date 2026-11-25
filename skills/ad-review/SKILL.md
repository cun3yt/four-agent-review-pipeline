---
name: ad-review
description: Run the full four-agent review pipeline on a spec file
disable-model-invocation: true
---

# Four-Agent Review Pipeline Orchestrator

Run the complete mutual-distrust review pipeline for the given spec file.

## Spec File
$ARGUMENTS

## Prerequisites
- Spec file must exist at `.specs/$ARGUMENTS.spec.md`
- If it doesn't exist, tell the user to run `/ad-spec $ARGUMENTS` first

## Pipeline

Execute these phases IN ORDER. Do not skip phases. Do not proceed if a gate fails.

### Phase 1: Test Writer

Spawn a subagent (Agent tool) with this EXACT prompt:

> You are a Test Writer. Read the spec at `.specs/$ARGUMENTS.spec.md` and the type
> signatures of files mentioned in the spec (use Grep to find exports/types — do NOT
> read full implementation files). Generate test skeletons with describe/it blocks
> for every acceptance criterion and edge case. Write ONLY skeletons with TODO
> comments — no function calls, no assertions with real code.
> Use Vitest syntax (describe, it, expect) unless the target package already uses Jest.
> Write the skeleton file to the conventional test location for the relevant package.
> Do NOT read docs/rules/ files.

Use `subagent_type: "general-purpose"`.

After the subagent returns:
- Note the skeleton file path
- Read the skeleton file and save its contents for Phase 3 comparison

### Phase 2: Implementer

Spawn a subagent (Agent tool, `isolation: "worktree"`) with this prompt:

> Implement the feature described in the spec at `.specs/$ARGUMENTS.spec.md`.
> Follow coding conventions in `docs/rules/` (read them all — import patterns,
> JSDoc requirements, color system, UI patterns, etc.).
> Complete these test skeletons by filling in real function calls and assertions:
> [PASTE THE SKELETON FILE CONTENTS HERE]
> Make all necessary code changes and complete the tests.
> Run `pnpm typecheck` and `pnpm test` before finishing to verify your work compiles and passes.

After the subagent returns, note the worktree path.

### Phase ⚡: Checkpoint

Run the deterministic checkpoint:

```bash
bash scripts/review/checkpoint.sh
```

**Gate logic:**
- If ALL pass → proceed to Phase 3
- If ANY fail → show failures, ask user: "Checkpoint failed. Send back to Implementer? (Y/n)"
  - If yes → spawn new Implementer subagent in the SAME worktree with the failure list
  - Re-run checkpoint after fix
  - Max 3 checkpoint retries before escalating: "Checkpoint still failing after 3 attempts. Manual intervention needed."

Save the checkpoint evidence JSON for Phase 3.

### Phase 3: Enforcer

Prepare a briefing file for the Enforcer (it runs in a forked context and can only Read files):

```bash
# Write the briefing
cat > /tmp/enforcer-briefing.md << 'BRIEF'
## Changed Files
[output of: git diff main...HEAD --name-only]

## Checkpoint Evidence
[checkpoint JSON from Phase ⚡]

## Original Test Skeletons (Phase 1, before implementation)
[saved skeleton contents from Phase 1]
BRIEF
```

Then invoke the Enforcer skill:

```
Skill(skill: "ad-enforce", args: "$ARGUMENTS")
```

The `/ad-enforce` skill runs with `context: fork` — system-enforced read-only tools. It reads the spec, rules, diff, and skeletons itself, then reports a structured verdict.

**Gate logic:**
- If PASS → proceed to Phase 4
- If FAIL → show violations, ask user: "Enforcer found violations. Send back to Implementer? (Y/n)"
  - If yes → spawn Implementer subagent with ONLY the violation list (not enforcer reasoning)
  - Re-run checkpoint → enforcer loop
  - Max 3 enforcer retries before escalating

### Phase 4: Breaker

Get the list of changed files:
```bash
git diff main...HEAD --name-only
```

Spawn a subagent (Agent tool) with this prompt:

> You are the Breaker. Read ONLY these changed files and write adversarial tests
> designed to make them fail:
> [LIST OF CHANGED FILES]
>
> Focus on: boundary values (empty, null, 0, -1, MAX_SAFE_INTEGER), type coercion,
> race conditions, concurrent calls, missing validation, injection attacks, auth bypass.
> Write tests at tests/adversarial/$ARGUMENTS.adversarial.test.ts
> Run the tests and report which pass and which fail.
>
> Do NOT read the spec, docs/rules/, test skeletons, or any other context files.
> Only read the changed files listed above.

Use `subagent_type: "general-purpose"`.

**Gate logic:**
- If all adversarial tests pass → pipeline complete
- If any fail → show failures, ask user: "Breaker found N failures. Send back to Implementer? (Y/n)"
  - If yes → full loop: Implementer → Checkpoint → Enforcer → Breaker
  - Max 2 full-loop retries

### Done

When all phases pass, report:

```
═══════════════════════════════════════════════════
  REVIEW PIPELINE COMPLETE
═══════════════════════════════════════════════════
  Spec:         .specs/$ARGUMENTS.spec.md
  Skeletons:    [skeleton file path]
  Adversarial:  tests/adversarial/$ARGUMENTS.adversarial.test.ts
  Worktree:     [worktree path/branch]

  Phases:
    1. Test Writer    ✓ [N skeletons]
    2. Implementer    ✓ [N files changed]
    ⚡ Checkpoint      ✓ lint + typecheck + tests
    3. Enforcer       ✓ [N rules checked, 0 violations]
    4. Breaker        ✓ [N adversarial tests, 0 failures]

  Next: Review the worktree changes, then merge when ready.
═══════════════════════════════════════════════════
```
