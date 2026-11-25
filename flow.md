# Four-Agent Review Pipeline — Full Flow

**Purpose:** Visual walkthrough of the complete `/ad-review` pipeline,
showing what happens at each phase, what each agent sees, and how failures loop back.

---

## 1. Full Pipeline Walkthrough

```
USER: /ad-review sidebar-filter-reset

┌─────────────────────────────────────────────────────────────────────────┐
│  ORCHESTRATOR  (ad-review skill, runs in your main agent session )     │
│                                                                        │
│  Step 0: Verify .specs/sidebar-filter-reset.spec.md exists             │
│          If missing → "Run /ad-spec sidebar-filter-reset first"        │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 1: TEST WRITER  (subagent, general-purpose)              │  │
│  │                                                                  │  │
│  │  SEES:  • .specs/sidebar-filter-reset.spec.md                   │  │
│  │         • Type signatures of affected files (Grep for exports)  │  │
│  │                                                                  │  │
│  │  DOES NOT SEE:  • Full implementation files                     │  │
│  │                 • docs/rules/                                 │  │
│  │                 • Any other code beyond type signatures          │  │
│  │                                                                  │  │
│  │  PRODUCES:  Test skeleton file with describe/it blocks          │  │
│  │             Every AC → at least one it() block                  │  │
│  │             Only TODO comments, NO real assertions              │  │
│  │                                                                  │  │
│  │  OUTPUT: tests/sidebar-filter-reset.test.ts (skeleton)          │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  Orchestrator saves skeleton contents for Phase 3 comparison           │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 2: IMPLEMENTER  (subagent, isolation: "worktree")        │  │
│  │                                                                  │  │
│  │  SEES:  • .specs/sidebar-filter-reset.spec.md                   │  │
│  │         • docs/rules/* (ALL rules — reads them all)          │  │
│  │         • Test skeletons from Phase 1 (pasted into prompt)      │  │
│  │         • Full codebase (in isolated worktree copy)             │  │
│  │                                                                  │  │
│  │  DOES NOT SEE:  • Test Writer's reasoning                      │  │
│  │                 • Orchestrator's internal state                 │  │
│  │                                                                  │  │
│  │  DOES:                                                          │  │
│  │    1. Reads all docs/rules/*.md                              │  │
│  │    2. Implements the feature per spec                           │  │
│  │    3. Fills in test skeletons with real assertions              │  │
│  │    4. Runs pnpm typecheck && pnpm test                         │  │
│  │                                                                  │  │
│  │  PRODUCES:  Working code + completed tests in worktree          │  │
│  │  OUTPUT:    .worktrees/<name>/ (isolated branch)         │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  PHASE ⚡: CHECKPOINT  (pure shell, NO LLM)                     │  │
│  │                                                                  │  │
│  │  RUNS:  bash scripts/review/                                    │  │
│  │         checkpoint.sh                                           │  │
│  │                                                                  │  │
│  │  CHECKS:                                                        │  │
│  │    ✓ pnpm lint          → pass/fail                             │  │
│  │    ✓ pnpm typecheck     → pass/fail                             │  │
│  │    ✓ pnpm test          → pass/fail                             │  │
│  │    ✓ Test count delta   → new tests ≥ skeleton count            │  │
│  │    ✓ Modified test files list                                   │  │
│  │                                                                  │  │
│  │  PRODUCES:  JSON evidence blob                                  │  │
│  │  {                                                              │  │
│  │    "lint": "pass",                                              │  │
│  │    "typecheck": "pass",                                         │  │
│  │    "test": "pass",                                              │  │
│  │    "test_count_before": 120,                                    │  │
│  │    "test_count_after": 127,                                     │  │
│  │    "new_tests": 7,                                              │  │
│  │    "modified_test_files": ["tests/sidebar-filter-reset.test.ts"]│  │
│  │  }                                                              │  │
│  │                                                                  │  │
│  │  GATE: ALL must pass → proceed                                  │  │
│  │        ANY fail → loop back to Implementer (max 3×)             │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  Orchestrator writes /tmp/enforcer-briefing.md:                        │
│    • Changed files list (git diff main...HEAD --name-only)             │
│    • Checkpoint evidence JSON                                          │
│    • Original test skeletons from Phase 1                              │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 3: ENFORCER  (Skill tool, context: fork = READ-ONLY)    │  │
│  │                                                                  │  │
│  │  SYSTEM ENFORCEMENT:                                            │  │
│  │    context: fork removes Edit, Write, Bash from available tools │  │
│  │    Only has: Read, Grep, Glob + 3 Chrome DevTools MCP           │  │
│  │    (take_screenshot, take_snapshot, list_console_messages)       │  │
│  │    This is NOT a prompt instruction — tools are GONE            │  │
│  │                                                                  │  │
│  │  SEES:  • /tmp/enforcer-briefing.md (changed files, evidence)  │  │
│  │         • docs/rules/* (ALL rules)                           │  │
│  │         • .specs/sidebar-filter-reset.spec.md                   │  │
│  │         • Original test skeletons (via briefing)                │  │
│  │         • All changed files (reads each one)                    │  │
│  │                                                                  │  │
│  │  DOES NOT SEE:  • Implementer's reasoning or intent            │  │
│  │                 • Task description or conversation history      │  │
│  │                 • Why the code was written this way             │  │
│  │                                                                  │  │
│  │  PERFORMS 4 CHECKS:                                             │  │
│  │    Check 1: Rule Compliance                                     │  │
│  │      For each changed file × each docs/rules/*.md:          │  │
│  │      - Import patterns (database.md)                            │  │
│  │      - API key patterns (api-keys.md)                           │  │
│  │      - UI patterns (ui-patterns.md)                             │  │
│  │      - Color system (color-system.md)                           │  │
│  │      - JSDoc requirements (jsdoc.md)                            │  │
│  │      - File size limits (<250 lines)                            │  │
│  │      - Logging rules (logging.md)                               │  │
│  │      - No `any` types, no dynamic imports                       │  │
│  │                                                                  │  │
│  │    Check 2: Spec Coverage                                       │  │
│  │      For each AC in spec:                                       │  │
│  │      - Does a test exist? Has real assertions? Not just TODO?   │  │
│  │                                                                  │  │
│  │    Check 3: Skeleton Integrity                                  │  │
│  │      - All Phase 1 describe() blocks still present?             │  │
│  │      - All Phase 1 it() blocks still present?                   │  │
│  │      - Any assertions weakened (.toBe → .toBeDefined)?          │  │
│  │      - Any tests deleted?                                       │  │
│  │                                                                  │  │
│  │    Check 4: Visual Criteria (if spec has ## Visual Criteria)    │  │
│  │      - take_screenshot for visual verification                  │  │
│  │      - take_snapshot for semantic HTML                          │  │
│  │      - list_console_messages for error detection                │  │
│  │      - SKIPPED if no MCP or no visual criteria in spec         │  │
│  │                                                                  │  │
│  │  PRODUCES:  Structured verdict                                  │  │
│  │  VERDICT: PASS / FAIL                                           │  │
│  │  VIOLATIONS: [file:line — rule — violation — fix]               │  │
│  │  SPEC GAPS: [AC-N: issue]                                       │  │
│  │  TEST INTEGRITY: [preserved/deleted/weakened]                   │  │
│  │  VISUAL: [VC-N: PASS/FAIL/SKIPPED]                             │  │
│  │                                                                  │  │
│  │  GATE: PASS → proceed                                           │  │
│  │        FAIL → loop back to Implementer (max 3×)                 │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 4: BREAKER  (subagent, general-purpose)                  │  │
│  │                                                                  │  │
│  │  SEES:  • Changed files ONLY (git diff main...HEAD --name-only)│  │
│  │         • Chrome DevTools MCP (16 tools, if loaded)              │  │
│  │                                                                  │  │
│  │  DOES NOT SEE:  • The spec (doesn't know what code SHOULD do)  │  │
│  │                 • docs/rules/                                 │  │
│  │                 • Test skeletons from Phase 1                   │  │
│  │                 • Implementer's intent or reasoning             │  │
│  │                 • Checkpoint results                            │  │
│  │                 • Enforcer's verdict                            │  │
│  │                                                                  │  │
│  │  DOES:                                                          │  │
│  │    1. Reads each changed file                                   │  │
│  │    2. Identifies attack vectors per function/component:         │  │
│  │       - Boundary values (empty, null, 0, -1, MAX_SAFE_INTEGER) │  │
│  │       - Type coercion (string↔number, array↔object)            │  │
│  │       - Race conditions (concurrent calls, double-submit)       │  │
│  │       - State corruption (partial failures)                     │  │
│  │       - Missing validation (malformed input)                    │  │
│  │       - Resource exhaustion (huge inputs, deep nesting)         │  │
│  │       - Injection (SQL, XSS, command injection)                 │  │
│  │       - Auth bypass (missing permission checks)                 │  │
│  │    3. If Chrome DevTools MCP + .tsx files changed → visual:      │  │
│  │       - Viewport resize, device emulation, dark mode toggle     │  │
│  │       - Lighthouse audit, console errors, network requests      │  │
│  │       - Content overflow, rapid interaction, empty/error states  │  │
│  │    4. Writes adversarial tests                                  │  │
│  │    5. Runs adversarial tests                                    │  │
│  │                                                                  │  │
│  │  PRODUCES:                                                      │  │
│  │    tests/adversarial/sidebar-filter-reset.adversarial.test.ts   │  │
│  │    BREAKER REPORT with logic + visual results                   │  │
│  │                                                                  │  │
│  │  GATE: All pass → PIPELINE COMPLETE                             │  │
│  │        Any fail → loop back (full cycle, max 2×)                │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                        │
│  ═══════════════════════════════════════════════════════════════════   │
│    REVIEW PIPELINE COMPLETE                                           │
│  ═══════════════════════════════════════════════════════════════════   │
│    Spec:         .specs/sidebar-filter-reset.spec.md                  │
│    Skeletons:    tests/sidebar-filter-reset.test.ts                   │
│    Adversarial:  tests/adversarial/sidebar-filter-reset.adv.test.ts   │
│    Worktree:     .worktrees/<name>/                            │
│                                                                        │
│    Phases:                                                             │
│      1. Test Writer    ✓ [7 skeletons]                                │
│      2. Implementer    ✓ [4 files changed]                            │
│      ⚡ Checkpoint      ✓ lint + typecheck + tests                     │
│      3. Enforcer       ✓ [N rules checked, 0 violations]             │
│      4. Breaker        ✓ [12 adversarial tests, 0 failures]          │
│                                                                        │
│    Next: Review the worktree changes, then merge when ready.          │
│  ═══════════════════════════════════════════════════════════════════   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Information Asymmetry Map

Each agent deliberately sees only what it needs. This prevents collusion (one agent
covering for another's mistakes) and ensures genuine independent verification.

```
                    SPEC    RULES   CODE    SKELETONS   EVIDENCE   CHANGED
                                                                    FILES
Test Writer          ✓       ✗      types     —           —          —
                                    only
Implementer          ✓       ✓       ✓        ✓           —          —
                                   (full)   (to fill)
Checkpoint           —       —       —        —           —          —
(shell only)        runs lint/typecheck/test — no LLM, no context
Enforcer             ✓       ✓      reads     ✓           ✓          ✓
                                   changed  (original)  (JSON)
Breaker              ✗       ✗      reads     ✗           ✗          ✓
                                   changed                        (only these)
                                    only
```

**Why this matters:**
- Test Writer can't see implementation → tests reflect spec, not code
- Enforcer can't see intent → judges by rules and evidence, not sympathy
- Breaker can't see spec → tests what code DOES, not what it SHOULD do
- Checkpoint has no LLM → deterministic, unforgeable evidence

---

## 3. Loop-Back Paths

### Happy Path (no failures)

```
/ad-review sidebar-filter-reset
    │
    ├─→ Phase 1: Test Writer ──→ skeletons ✓
    │
    ├─→ Phase 2: Implementer ──→ code + tests ✓
    │
    ├─→ Phase ⚡: Checkpoint ──→ all pass ✓
    │
    ├─→ Phase 3: Enforcer ──→ PASS ✓
    │
    ├─→ Phase 4: Breaker ──→ 0 failures ✓
    │
    └─→ ✅ PIPELINE COMPLETE
```

### Checkpoint Fails

```
Phase 2: Implementer ──→ code
    │
    ├─→ Phase ⚡: Checkpoint ──→ FAIL (typecheck errors)
    │       │
    │       ├─→ User: "Send back to Implementer? (Y/n)"
    │       │       │
    │       │       └─→ Y: Spawn new Implementer with failure list
    │       │               │
    │       │               └─→ Phase ⚡: Checkpoint (retry 1/3)
    │       │                       │
    │       │                       ├─→ PASS → continue to Phase 3
    │       │                       └─→ FAIL → retry (max 3)
    │       │
    │       └─→ After 3 fails: "Manual intervention needed"
```

### Enforcer Fails

```
Phase ⚡: Checkpoint ──→ PASS
    │
    ├─→ Phase 3: Enforcer ──→ FAIL
    │       │
    │       │  VIOLATIONS:
    │       │  - src/components/sidebar.tsx:42 — color-system.md
    │       │    — uses raw hex color — use theme token
    │       │  - src/hooks/useFilter.ts — jsdoc.md
    │       │    — exported hook missing JSDoc
    │       │
    │       ├─→ User: "Send back to Implementer? (Y/n)"
    │       │       │
    │       │       └─→ Y: Spawn Implementer with ONLY violation list
    │       │               (NOT enforcer reasoning — just the facts)
    │       │               │
    │       │               └─→ Phase ⚡ → Phase 3 (retry 1/3)
    │       │
    │       └─→ After 3 fails: "Enforcer still failing. Manual review."
```

### Breaker Fails

```
Phase 3: Enforcer ──→ PASS
    │
    ├─→ Phase 4: Breaker ──→ FAIL
    │       │
    │       │  BREAKER REPORT:
    │       │  Logic tests FAILED: 2
    │       │  - "handles null filter value": Expected graceful
    │       │    handling, got TypeError: Cannot read property
    │       │  - "concurrent filter resets": Race condition,
    │       │    state corrupted when called twice rapidly
    │       │
    │       ├─→ User: "Send back to Implementer? (Y/n)"
    │       │       │
    │       │       └─→ Y: FULL LOOP restart
    │       │               Implementer → Checkpoint → Enforcer → Breaker
    │       │               (retry 1/2)
    │       │
    │       └─→ After 2 full loops: "Breaker still finding bugs. Manual fix."
```

### Maximum Retry Counts

```
┌────────────────────┬────────────┬──────────────────────────────────┐
│ Gate               │ Max Retries│ What Gets Re-run                 │
├────────────────────┼────────────┼──────────────────────────────────┤
│ Checkpoint         │ 3          │ Implementer → Checkpoint         │
│ Enforcer           │ 3          │ Implementer → Checkpoint →       │
│                    │            │ Enforcer                         │
│ Breaker            │ 2          │ Implementer → Checkpoint →       │
│                    │            │ Enforcer → Breaker (full loop)   │
└────────────────────┴────────────┴──────────────────────────────────┘
```

---

## 4. Process Isolation Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  YOUR REVIEW SESSION                                                │
│  (main conversation context)                                        │
│                                                                     │
│  /ad-review sidebar-filter-reset                                    │
│       │                                                             │
│       │  ┌─────────────────────────────────────────────────┐       │
│       ├──│ Agent tool (subagent_type: "general-purpose")   │       │
│       │  │ Test Writer — fresh context, no parent history  │       │
│       │  │ Returns: skeleton file path + contents          │       │
│       │  └─────────────────────────────────────────────────┘       │
│       │                                                             │
│       │  ┌─────────────────────────────────────────────────┐       │
│       ├──│ Agent tool (isolation: "worktree")              │       │
│       │  │ Implementer — git worktree, isolated branch     │       │
│       │  │ Changes don't touch your working directory      │       │
│       │  │ Returns: worktree path + branch name            │       │
│       │  └─────────────────────────────────────────────────┘       │
│       │                                                             │
│       │  ┌─────────────────────────────────────────────────┐       │
│       ├──│ Bash tool (no LLM)                              │       │
│       │  │ checkpoint.sh — deterministic, unforgeable      │       │
│       │  │ Returns: JSON evidence                          │       │
│       │  └─────────────────────────────────────────────────┘       │
│       │                                                             │
│       │  ┌─────────────────────────────────────────────────┐       │
│       ├──│ Skill tool (context: fork)                      │       │
│       │  │ Enforcer — system-enforced read-only            │       │
│       │  │ Edit/Write/Bash tools REMOVED at system level   │       │
│       │  │ Returns: structured verdict                     │       │
│       │  └─────────────────────────────────────────────────┘       │
│       │                                                             │
│       │  ┌─────────────────────────────────────────────────┐       │
│       └──│ Agent tool (subagent_type: "general-purpose")   │       │
│          │ Breaker — fresh context, sees only changed files│       │
│          │ Returns: adversarial test results               │       │
│          └─────────────────────────────────────────────────┘       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

KEY:
  Agent tool  = subprocess, fresh context, no parent history
  isolation   = git worktree (separate copy of repo)
  context     = fork (system-enforced tool restrictions)
  Bash tool   = no LLM, pure shell execution
```

---

## 5. Estimated Timeline

```
┌────────────────────┬───────────┬───────────────────────────────────┐
│ Phase              │ Duration  │ Notes                             │
├────────────────────┼───────────┼───────────────────────────────────┤
│ 1. Test Writer     │ 2-4 min   │ Reads spec + types, writes       │
│                    │           │ skeleton file                     │
├────────────────────┼───────────┼───────────────────────────────────┤
│ 2. Implementer     │ 5-15 min  │ Full implementation + test fill.  │
│                    │           │ Biggest variable — depends on     │
│                    │           │ feature complexity                │
├────────────────────┼───────────┼───────────────────────────────────┤
│ ⚡ Checkpoint       │ 2-5 min   │ Lint + typecheck + test suite.    │
│                    │           │ Monorepo = longer typecheck       │
├────────────────────┼───────────┼───────────────────────────────────┤
│ 3. Enforcer        │ 3-5 min   │ Reads rules + files. No shell,   │
│                    │           │ just analysis                     │
├────────────────────┼───────────┼───────────────────────────────────┤
│ 4. Breaker         │ 3-8 min   │ Reads changed files, writes +    │
│                    │           │ runs adversarial tests            │
├────────────────────┼───────────┼───────────────────────────────────┤
│ TOTAL (happy path) │ 15-37 min │ No loop-backs needed             │
│ TOTAL (1 retry)    │ 25-55 min │ One checkpoint or enforcer retry │
└────────────────────┴───────────┴───────────────────────────────────┘
```

---

## 6. Quick Reference

### Slash Commands

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `/ad-spec <name>` | Create spec file at `.specs/<name>.spec.md` | Before starting pipeline |
| `/ad-review <name>` | Run full 4-phase pipeline | Main entry point |
| `/ad-test-skeletons <name>` | Phase 1 only (Test Writer) | Testing individual phases |
| `/ad-checkpoint` | Phase ⚡ only (shell checks) | Testing individual phases |
| `/ad-enforce <name>` | Phase 3 only (Enforcer, read-only) | Testing individual phases |
| `/ad-break <name>` | Phase 4 only (Breaker) | Testing individual phases |

### Agent Isolation Summary

| Agent | Tool Access | Context | Can Modify Files? | Sees Spec? | Sees Rules? |
|-------|------------|---------|-------------------|------------|-------------|
| Test Writer | Read, Write, Grep, Glob | Subagent | Yes (skeleton only) | Yes | No |
| Implementer | All tools | Worktree | Yes (isolated branch) | Yes | Yes |
| Checkpoint | Bash only | Shell script | No | No | No |
| Enforcer | Read, Grep, Glob + 3 Chrome DevTools MCP | Fork (read-only) | **No (system-enforced)** | Yes | Yes |
| Breaker | All tools + 16 Chrome DevTools MCP | Subagent | Yes (adversarial tests) | **No** | **No** |

---

## 7. File Artifacts Produced

After a successful pipeline run, these files exist:

```
.specs/
  sidebar-filter-reset.spec.md          ← Created by /ad-spec (pre-pipeline)

tests/
  sidebar-filter-reset.test.ts          ← Phase 1 skeleton → Phase 2 completed

tests/adversarial/
  sidebar-filter-reset.adversarial.test.ts  ← Phase 4 adversarial tests

.worktrees/<name>/               ← Isolated branch with all changes
                                           (review, then merge to your branch)

/tmp/enforcer-briefing.md               ← Ephemeral, cleaned up by OS
```
