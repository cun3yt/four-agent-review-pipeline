# Design: Four-Agent Mutual Distrust Review

**Based on:** [How to Kill the Code Review](https://www.latent.space/p/reviews-dead) (Latent Space)

Why the pipeline is shaped the way it is. For the step-by-step flow see `flow.md`.

---

## The Solution: Swiss Cheese Model

Replace the single human review gate with **5 imperfect layers** that collectively catch everything:

```
┌─────────────────────────────────────────────────────────────────┐
│                    HUMAN INTENT REVIEW                           │
│         "Is this the right thing to build?"                      │
│         Review SPECS, not CODE                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Layer 5: Adversarial Verification                              │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Break-it agent: generates edge case tests to find holes    │ │
│  │ Security scanner: OWASP Top 10 checks on diff             │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Layer 4: Permission Systems                                    │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ CODEOWNERS: route PRs by sensitivity                       │ │
│  │ Package boundaries: enforce import rules                   │ │
│  │ Agent scoping: limit AI to relevant files                  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Layer 3: Acceptance Criteria                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ .specs/ directory: markdown specs per feature              │ │
│  │ Spec-to-test mapper: CI fails if spec has no test          │ │
│  │ Tests generated FROM specs, not from reading code          │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Layer 2: Deterministic Guardrails                              │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ CI pipeline: lint + typecheck + test + build               │ │
│  │ Pre-commit: lint-staged + commitlint                       │ │
│  │ Custom rules: import patterns, file size, boundaries       │ │
│  │ Rule compiler: docs/rules/ → machine checks             │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  Layer 1: Competitive Generation                                │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Multiple implementations in parallel worktrees             │ │
│  │ Scoring: diff size + deps + type errors + test coverage    │ │
│  │ Pick winner automatically or human selects                 │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Core Pattern: Dual-Agent Mutual Distrust

The article's deepest insight isn't "use AI to review code." It's that **no agent should verify its own work**, and the verifying agent should be structurally prevented from colluding with the implementing agent.

LLMs are unreliable at self-verification. An agent that writes code, then checks it, reads charitably — it sees what it *meant* to write, not what it actually wrote. The fix: **separation of powers at the agent level**, like a financial control where the person who writes the check cannot sign it.

### Four-Agent Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  ┌───────────────────────┐                                                  │
│  │    HUMAN              │                                                  │
│  │    Reviews INTENT     │ ◄──── "Is this the right thing to build?"        │
│  │    (specs, criteria)  │                                                  │
│  └──────────┬────────────┘                                                  │
│             │ approved spec                                                  │
│             ▼                                                                │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  TEST WRITER AGENT                                                   │   │
│  │                                                                      │   │
│  │  Knows: spec/acceptance criteria + codebase types                    │   │
│  │  Does NOT know: how the implementation will work                     │   │
│  │  Produces: test skeletons derived from the spec                      │   │
│  │  (Defines WHAT to test before the code exists)                       │   │
│  └──────────┬───────────────────────────────────────────────────────────┘   │
│             │ test skeletons (expectations without function calls)          │
│             ▼                                                                │
│  ┌───────────────────────┐     ┌────────────────────────────────────────┐   │
│  │  IMPLEMENTER AGENT    │     │  ENFORCER AGENT                       │   │
│  │                       │     │                                        │   │
│  │  Knows:               │     │  Knows:                                │   │
│  │  ✓ Task description   │     │  ✓ docs/rules/ (every file)        │   │
│  │  ✓ Codebase context   │     │  ✓ The diff (code + completed tests)  │   │
│  │  ✓ User intent        │     │  ✓ lint/typecheck/test results        │   │
│  │  ✓ Conventions        │     │                                        │   │
│  │  ✓ Test skeletons     │     │  Does NOT know:                        │   │
│  │    (fills them in)    │     │  ✗ WHY the code was written           │   │
│  │                       │     │  ✗ The task description               │   │
│  │  Does NOT know:       │     │  ✗ Implementer's reasoning            │   │
│  │  ✗ Enforcer reasoning │     │                                        │   │
│  │  ✗ Whether it passed  │     │  Checks (among other things):         │   │
│  │  ✗ Breaker tests      │     │  ✓ "Do tests actually verify the      │   │
│  │                       │     │     spec criteria?"                    │   │
│  │  Can:                 │     │  ✓ Read diff (not edit)               │   │
│  │  ✓ Write code         │     │  ✗ Modify the code                   │   │
│  │  ✓ Complete tests     │     │  ✗ Be persuaded by "but I meant..."  │   │
│  │  ✗ Approve own code   │     │                                        │   │
│  │  ✗ Skip enforcement   │     │                                        │   │
│  └──────────┬────────────┘     └──────────────────┬─────────────────────┘   │
│             │ produces diff                        │ produces verdict        │
│             │ (code + completed tests)             │                        │
│             │    ┌─────────────────────────────┐   │                        │
│             └───►│  ITERATION LOOP             │◄──┘                        │
│                  │  Enforcer rejects (3 issues) │                            │
│                  │  → Implementer gets list:    │                            │
│                  │    "L42: wrong import"       │                            │
│                  │    "L98: no JSDoc"           │                            │
│                  │    "test for AC-3 is empty"  │                            │
│                  │  → Implementer fixes         │                            │
│                  │  → Enforcer re-checks        │                            │
│                  │  → PASS after round 2        │                            │
│                  └──────────────┬────────────────┘                           │
│                                 │                                            │
│                                 ▼                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  BREAKER AGENT                                                       │   │
│  │                                                                      │   │
│  │  Knows: ONLY the final code (changed files)                          │   │
│  │  Does NOT know: intent, rules, spec, why code exists                 │   │
│  │  Goal: generate adversarial tests that make the code fail            │   │
│  │  Output: additional test file (edge cases, race conditions)          │   │
│  │  MCP:   Full access — navigate, resize, emulate, click, screenshot   │   │
│  │         (visual adversarial testing: viewports, dark mode, devices)   │   │
│  │  If tests fail → back to implementer (sees failing test, not why)    │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Who Writes the Tests?

There are **three layers of tests**, each written by a different agent with different information:

```
Layer 1: TEST WRITER → Spec-derived test skeletons (BEFORE implementation)
  Written from acceptance criteria. Defines what to test.
  No function calls — just expectations and structure.
  Example: it('should apply percentage discount before fixed')

Layer 2: IMPLEMENTER → Completes the skeletons (DURING implementation)
  Fills in real function calls now that the interface exists.
  Example: const result = applyDiscounts({ percent: 10, fixed: 5 }, 100);
           expect(result.total).toBe(85);

Layer 3: BREAKER → Adversarial tests (AFTER implementation)
  Tries to break the code with edge cases the others missed.
  Written blind to intent and rules — pure adversary.
  Example: it('handles concurrent updates without corruption')
```

**Why three layers?** Each prevents a specific failure mode:
- Test Writer prevents: "implementer writes tests that match its implementation" (circular validation)
- Implementer completing skeletons prevents: "tests that don't compile because they were written before the interface"
- Breaker prevents: "both spec and implementation share the same blind spots"

### MCP Integration — Browser Eyes for Agents

When Chrome DevTools MCP is available, agents gain the ability to **see the browser**. This changes the pipeline for frontend features:

**Enforcer gains read-only visual verification:**
- `take_screenshot` — capture viewport or element
- `take_snapshot` — full accessibility tree
- `evaluate_script` — check computed styles, DOM structure
- `lighthouse_audit` — accessibility, performance scores
- `list_console_messages` — catch console errors

**Enforcer read-only isolation:** Give the reviewer a separate session with read-only access to the inputs. Configure and verify that restriction in the runner before relying on it.

**Breaker gains full visual adversarial testing:**
- All Enforcer tools plus: `navigate_page`, `resize_page`, `emulate`, `click`, `fill`, `type_text`
- Viewport extremes (320px, 375px, 768px, 1440px, 2560px)
- Dark mode toggling, device emulation (iPhone SE, Galaxy Fold)
- Content overflow injection (very long text, many items)
- Interaction stress tests (rapid click, race conditions)

**Coverage impact:**

| Feature Type | Without MCP | With MCP |
|---|---|---|
| Pure utility function | ~95% | ~95% |
| Server action / API | ~85% | ~85% |
| Frontend component | ~65% | **~90%** |
| Full-stack feature | ~75% | **~85%** |

**Graceful degradation:** If Chrome DevTools MCP is not available (not configured for the session), visual checks report `SKIPPED` and the pipeline continues. No MCP = no crash, just lower coverage for frontend work.

**Extended checkpoint:** For specs with `## Visual Criteria`, the checkpoint starts a dev server (`pnpm dev`) so downstream agents can use MCP against localhost.

### Agent × MCP Tool Matrix

| MCP Tool | Test Writer | Implementer | Enforcer | Breaker |
|---|---|---|---|---|
| `take_screenshot` | — | Yes | **Yes** | **Yes** |
| `take_snapshot` | — | Yes | **Yes** | **Yes** |
| `evaluate_script` | — | Yes | **Yes** | **Yes** |
| `lighthouse_audit` | — | — | **Yes** | **Yes** |
| `list_console_messages` | — | Yes | **Yes** | **Yes** |
| `navigate_page` | — | Yes | — | **Yes** |
| `resize_page` | — | Yes | — | **Yes** |
| `emulate` | — | — | — | **Yes** |
| `click` / `fill` / `type_text` | — | Yes | — | **Yes** |

### *Conventions vs. Invariants — What the Implementer Sees

The implementer DOES see **mechanical conventions** (import patterns, color restrictions, JSDoc requirements, file size limits) — these are coding standards it should just follow. Hiding them would only create unnecessary fix cycles for predictable violations.

What the implementer does NOT see is **its own verdict**. It cannot self-certify. It cannot mark its own work as reviewed. The enforcer independently checks the same rules and produces a pass/fail verdict.

**Two kinds of rules:**

| Rule Type | Example | Implementer Sees? | Why |
|---|---|---|---|
| **Conventions** (mechanical) | `import from @acme/db` | YES | No judgment needed — just follow it |
| **Invariants** (subjective) | "Is this architecture sound?" | NO — enforcer judges | Self-verification bias lives here |

The distrust isn't about hiding information — it's about **separating the roles of writer and approver**. A bank employee knows the check-writing policy. They still can't sign their own check.

### Communication Protocol: Structured Verdicts Only

The enforcer communicates to the implementer ONLY through structured, actionable verdicts — never reasoning or intent:

```typescript
type EnforcerVerdict = {
  pass: boolean;
  violations: Array<{
    file: string;
    line: number;
    rule: string;        // "database.md"
    violation: string;   // "Direct import from 'raw-orm-package'"
    fix: string;         // "Import from '@acme/db'"
  }>;
  specGaps: Array<{
    criterion: string;   // "AC-3"
    issue: string;       // "Test exists but assertion is empty"
  }>;
  testIntegrity: {
    skeletonsPreserved: boolean;     // All Test Writer skeletons still exist
    deletedTests: Array<{
      testName: string;              // "rejects null input"
      justified: boolean;            // Does spec change justify this?
      justification?: string;        // "Interface changed per AC-2"
    }>;
    weakenedAssertions: string[];    // Tests where assertions were downgraded
  };
  visualChecks?: Array<{             // Only present if spec has Visual Criteria
    criterion: string;               // "VC-1", "VC-2"
    status: 'pass' | 'fail' | 'skipped'; // skipped = MCP unavailable
    detail: string;                  // "horizontal overflow at 320px" or "a11y score: 97"
  }>;
  // NO reasoning about intent
  // NO "I think you should restructure this"
  // NO alternative approach suggestions
};
```

The enforcer can say "this line violates this rule" or "skeleton test 'rejects null input' was deleted without spec justification." It CANNOT say "I think you should do it differently." That would leak intent-level judgment into the verification layer.

### Information Asymmetry Matrix

| | Sees Spec | Sees Intent | Sees Conventions | Sees Implementation | Writes Code | Writes Tests | MCP Access | Approves Own Work |
|---|---|---|---|---|---|---|---|---|
| **Test Writer** | YES | **NO** | **NO** | **NO** (runs before impl) | NO | Skeletons only | None | N/A |
| **Implementer** | YES | YES | YES | YES (writes it) | YES | Completes skeletons | Full (if frontend) | **NO** |
| **Enforcer** | YES | **NO** | YES | Diff only | NO | NO | **Read-only** (screenshot, snapshot, a11y) | N/A |
| **Breaker** | **NO** | **NO** | **NO** | Changed files only | NO | Adversarial only | **Full** (navigate, resize, emulate, click) | N/A |

### Phase Input/Output Contract

Every phase has formally defined inputs, outputs, and gate conditions. **Nothing advances until its gate passes. Failed gates loop back — they never forward failures downstream.**

| Phase | Agent | Inputs | Outputs | MCP | Gate Condition |
|---|---|---|---|---|---|
| **0** | Human | Business need | Spec file (acceptance criteria + visual criteria) | — | Human approves spec |
| **1** | Test Writer | Spec file, codebase type signatures | Test skeleton file (`describe`/`it` blocks, no function calls) | None | Skeletons cover every acceptance criterion |
| **2** | Implementer | Task description, conventions (`docs/rules/`), test skeletons, codebase | Code diff + completed test file (skeletons filled with real calls) | Full | — (no self-gate, passes to checkpoint) |
| **⚡** | **Checkpoint** (deterministic) | Code from Phase 2 | Lint results, typecheck results, test pass/fail, **test count delta**, modified test list. **Starts dev server if spec has Visual Criteria.** | — | ALL pass → Phase 3. FAIL → Phase 2. |
| **3** | Enforcer (**Skill**, `context:fork`) | Diff, rules, spec, **original skeletons**, checkpoint evidence | Verdict: violations + spec gaps + skeleton integrity + **visual checks** | **Read-only** | PASS → Phase 4. FAIL → Phase 2. |
| **4** | Breaker | Changed files only (no spec, no rules, no intent, no skeletons) | Adversarial test file + **visual adversarial results** | **Full** | All pass → DONE. Any fail → Phase 2. |

### Deterministic Checkpoint (Inter-Agent, Not Final Gate)

The checkpoint is NOT a CI gate that runs after everything is done. It runs **between the Implementer and the Enforcer**, acting as an inter-agent evidence checkpoint. Its outputs serve two purposes: (1) fast auto-fix loop for the Implementer, (2) evidence package for the Enforcer.

```
══ DETERMINISTIC CHECKPOINT ══════════════════════════════════════
│  pnpm lint          → pass/fail + violation list
│  pnpm typecheck     → pass/fail + error list
│  pnpm test          → pass/fail + which tests failed
│  Test count delta   → "before: 120, after: 123 (delta: +3)"
│  Modified tests     → list of test files changed/deleted with names
│  Dev server         → started if spec has Visual Criteria (for MCP)
══════════════════════════════════════════════════════════════════
```

**Dev server for frontend features:** If the spec contains a `## Visual Criteria` section, the checkpoint starts a dev server (`pnpm dev`) so the Enforcer and Breaker can use Chrome DevTools MCP to verify visual constraints against localhost. The dev server is cleaned up after the pipeline completes.

**If ANY check fails:** Loop back to Implementer with the error output. No agent judgment needed — just "fix these 3 type errors." The Enforcer never sees broken code.

**If ALL pass:** Results are packaged as an **evidence bundle** forwarded to the Enforcer:
- `lint: PASS` — Enforcer doesn't re-check imports (machine already verified)
- `typecheck: PASS` — Enforcer doesn't re-check types
- `tests: PASS, 123 total (was 120, delta: +3)` — Enforcer knows baseline is clean
- `modified tests: cart-service.test.ts (+3 tests), validator.test.ts (-1 test: "rejects null input")`

This means the Enforcer doesn't waste cycles on things machines already verified. It focuses on **semantic questions** the checkpoint can't answer: "Do the tests actually verify the spec?" "Is the deleted test justified by the spec change?" "Were assertion strengths preserved?"

### Test Integrity Verification

Three layered mechanisms prevent the Implementer from gaming the test suite:

#### A. Test Count Delta (Checkpoint — Deterministic)

The checkpoint reports: how many tests existed before vs. after.

```
Test count: 117 (was 120, delta: -3)
Deleted tests:
  - parseConfig: handles empty key
  - parseConfig: rejects null input
  - validatePath: blocks traversal
```

Cheap to compute (`grep -c "it(" tests/` or parsing test runner output) but turns silent test deletion into an explicit, undeniable fact that the Enforcer must address.

#### B. Skeleton Integrity Check (Enforcer — Semantic)

The Enforcer receives the **original test skeletons from Phase 1** alongside the **completed tests from Phase 2**. It checks:

- Every skeleton `it()` block still exists in the completed tests
- Assertions weren't weakened (e.g., `.toBeDefined()` replacing a specific `.toEqual(expected)`)
- No skeleton was silently deleted
- Completed tests actually exercise the spec, not just pass trivially

The skeletons serve as a **tamper-evident seal**: the Test Writer defined what to verify before the code existed, and the Enforcer checks that the Implementer honored those definitions.

#### C. Adversarial Re-coverage (Breaker — Independent)

The Breaker doesn't know which tests existed or were deleted. Since it generates adversarial tests from the code alone, it naturally re-discovers edge cases the deleted tests would have caught. If the Implementer deleted "handles null config key" to hide a bug, the Breaker will likely generate exactly that test.

```
Implementer deletes: 'rejects null input'
     ↓
Checkpoint reports: "delta: -1, deleted: rejects null input"
     ↓
Enforcer flags: "deletion not justified by spec — skeleton required this test"
     ↓ (even if Enforcer misses it)
Breaker generates: 'what if key is null?' → test fails → caught
```

**The three layers cover each other's blind spots:**

| Mechanism | What It Catches | What It Misses |
|---|---|---|
| Test count delta (checkpoint) | Any deletion — quantitative fact | Doesn't know if deletion is justified |
| Skeleton integrity (Enforcer) | Unjustified deletions, weakened assertions, missing skeleton coverage | Could be convinced by plausible diff context |
| Adversarial re-coverage (Breaker) | Actual bugs hidden by deletion | Won't re-cover every deleted test's specific intent |

No single mechanism is foolproof. Together they make test tampering structurally difficult.

### Orchestration Flow

```
Phase 0: Human writes/approves spec (acceptance criteria)
         OUTPUT → spec file

Phase 1: Test Writer reads spec → generates test skeletons
         INPUT  ← spec file, codebase type signatures
         OUTPUT → test skeleton file
         (describe/it blocks with assertion intent, no function calls)

Phase 2: Implementer writes code + completes test skeletons
         INPUT  ← task description, conventions, test skeletons, codebase
         OUTPUT → code diff + completed test file

    ╔══ DETERMINISTIC CHECKPOINT ═════════════════════════════════════╗
    ║  lint: PASS ✓                                                   ║
    ║  typecheck: PASS ✓                                              ║
    ║  tests: PASS ✓ (123 total, was 120, delta: +3)                  ║
    ║  modified tests: cart-service.test.ts (+3), validator.test.ts ║
    ║                  (-1: "rejects null input")                     ║
    ╠═════════════════════════════════════════════════════════════════╣
    ║  FAIL → loop back to Phase 2 with error output                  ║
    ║  PASS → package results as evidence, advance to Phase 3         ║
    ╚═════════════════════════════════════════════════════════════════╝

Phase 3: Enforcer reviews (runs as Skill with context:fork — read-only enforced)
         INPUT  ← diff, rules, spec, original test skeletons,
                   checkpoint evidence package
         MCP    ← read-only: screenshot, snapshot, evaluate_script, lighthouse, console
         OUTPUT → structured verdict (violations + spec gaps + skeleton integrity + visual)
         Round 1: 5 rule violations + 1 spec gap + 1 skeleton mismatch + 1 visual fail
         Round 2: → back to Phase 2 → checkpoint ✓ → Enforcer
                  1 violation remaining
         Round 3: → back to Phase 2 → checkpoint ✓ → Enforcer → PASS ✓

Phase 4: Breaker generates adversarial tests
         INPUT  ← changed files only
         MCP    ← full: navigate, resize, emulate, click, fill, screenshot
         OUTPUT → adversarial test file + visual adversarial results
         8 logic tests + 5 visual tests → 2 fail
         → back to Phase 2 → checkpoint ✓ → Enforcer ✓ → Breaker
         → all pass ✓

DONE → merge candidate for human review of INTENT (not code)
```

Max 5 rounds per phase. If still failing → escalate to human.

**Note:** Every loop-back to Phase 2 re-runs the full checkpoint. The Enforcer always receives fresh evidence. This prevents the Implementer from "fixing" an enforcer violation while silently breaking something else.
