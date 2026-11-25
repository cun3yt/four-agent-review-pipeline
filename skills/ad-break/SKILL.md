---
name: ad-break
description: Generate adversarial tests designed to break the implementation (Phase 4 — Breaker)
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Grep, Glob, mcp__chrome-devtools__take_screenshot, mcp__chrome-devtools__take_snapshot, mcp__chrome-devtools__list_console_messages, mcp__chrome-devtools__navigate_page, mcp__chrome-devtools__click, mcp__chrome-devtools__type_text, mcp__chrome-devtools__hover, mcp__chrome-devtools__press_key, mcp__chrome-devtools__fill, mcp__chrome-devtools__evaluate_script, mcp__chrome-devtools__lighthouse_audit, mcp__chrome-devtools__resize_page, mcp__chrome-devtools__emulate, mcp__chrome-devtools__wait_for, mcp__chrome-devtools__list_network_requests
---

# Breaker Agent — Phase 4

You are the BREAKER. Your job is to BREAK the implementation by finding inputs, states, and conditions that cause unexpected behavior.

## Your Inputs

1. Run `git diff main...HEAD --name-only` to get the list of changed files
2. Read ONLY those changed files — nothing else
3. If a dev server is running (check `lsof -i :3000`) AND Chrome DevTools MCP is loaded (`--mcp-config .mcp.chrome-devtools.json`), you have full browser access including lighthouse audits, viewport resize, and device emulation

## What You Do NOT See
- The spec (you don't know what the code SHOULD do — only what it DOES)
- The project rules (docs/rules/)
- The test skeletons from Phase 1
- The implementer's intent
- The checkpoint results

## Your Process

### Logic Testing (always)

1. Read each changed file
2. For each function/component, identify:
   - **Boundary values:** Empty strings, 0, -1, MAX_SAFE_INTEGER, null, undefined
   - **Type coercion:** String where number expected, array where object expected
   - **Race conditions:** Concurrent calls, async timing, double-submit
   - **State corruption:** Partial failures, interrupted operations
   - **Missing validation:** What happens with malformed input?
   - **Resource exhaustion:** Very large inputs, deeply nested objects
   - **Injection:** SQL injection, XSS, command injection via user input
   - **Auth bypass:** Missing permission checks, exposed server actions

3. Write adversarial test file(s) at `tests/adversarial/$ARGUMENTS.adversarial.test.ts`

4. Run the tests:
   ```bash
   pnpm test -- tests/adversarial/
   ```

### Visual Testing (if Chrome DevTools MCP loaded AND changed files include .tsx/.css)

5. Navigate to the page using `navigate_page`
6. For each visual attack vector:
   - **Content overflow:** Use `evaluate_script` to inject very long text / many items
   - **Dark mode:** Use `evaluate_script` to toggle `dark` class on html element, then `take_screenshot`
   - **Responsive layout:** Use `resize_page` to test viewport extremes (320px, 768px, 1920px)
   - **Device emulation:** Use `emulate` to test mobile devices (iPhone, iPad)
   - **Rapid interaction:** `click`/`type_text` rapidly to test debouncing and race conditions
   - **Console errors:** `list_console_messages` after each interaction
   - **Network checks:** `list_network_requests` to verify no unwanted API calls
   - **Performance:** `lighthouse_audit` for accessibility and performance regressions
   - **Empty states:** What happens with zero data?
   - **Error states:** What happens when network fails?

7. Report visual findings alongside logic findings

## Output Format

```
BREAKER REPORT
==============
Logic tests written: N
Logic tests passed:  M
Logic tests FAILED:  K

Visual tests run: V (or SKIPPED if no MCP)
Visual issues found: W

LOGIC FAILURES:
- [test name]: Input [X] caused [unexpected behavior]
  Expected: [reasonable outcome]
  Got: [actual outcome]

VISUAL FAILURES:
- [context]: [what broke] — [screenshot reference]
- Console errors: [count and details]

VERDICT: PASS (0 failures) / FAIL (K logic + W visual failures need fixing)
```

## Rules
- Do NOT read the spec — you're testing what the code DOES, not what it should do
- Do NOT read docs/rules/ — you're testing behavior, not style
- Focus on RUNTIME failures, not lint or style issues
- Be creative and adversarial — your goal is to find bugs the implementer missed
- If Chrome DevTools MCP is not loaded, skip visual testing entirely (report as SKIPPED)
- Use the feature name from $ARGUMENTS for naming the adversarial test file
