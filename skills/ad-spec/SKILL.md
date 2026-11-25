---
name: ad-spec
description: Create a spec file with acceptance criteria for a feature or bug fix
disable-model-invocation: true
allowed-tools: Read, Write, Grep, Glob
---

# Create Specification File

Create a spec file at `.specs/$ARGUMENTS.spec.md` with the following structure.

## Template

```markdown
# Feature: [Name]

**Created:** [YYYY-MM-DD]
**Updated:** [YYYY-MM-DD]

## Context
[1-2 sentences about what this feature/fix does and why]

## Acceptance Criteria
- [ ] AC-1: [First criterion — observable, testable]
- [ ] AC-2: [Second criterion]
- [ ] AC-3: [etc.]

## Affected Files (estimated)
- path/to/file.ts — what changes
- path/to/other.ts — what changes

## Edge Cases
- [Edge case 1]
- [Edge case 2]

## Visual Criteria (for frontend features — omit for pure logic)
- [ ] VC-1: [Visual constraint, e.g., "Badge uses text-muted-foreground for inactive state"]
- [ ] VC-2: [Layout constraint, e.g., "No horizontal overflow at 320px viewport"]

## Out of Scope
- [What this does NOT include]
```

## Instructions

1. Read any existing code referenced by the user's feature description
2. Read the relevant GitHub issue if one is referenced
3. Create the spec file following the template above. Set both **Created** and **Updated** to today's date (YYYY-MM-DD)
4. Ensure every acceptance criterion is:
   - **Observable:** Can be verified by looking at output/behavior
   - **Testable:** Can be turned into an automated test assertion
   - **Independent:** Each criterion stands alone
5. Include **Visual Criteria** only if the change involves UI (.tsx/.css files)
6. Present the spec to the user for review before proceeding
