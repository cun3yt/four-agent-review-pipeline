---
name: ad-checkpoint
description: Run deterministic checks (lint, typecheck, test) and report evidence
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Deterministic Checkpoint

Run all deterministic checks and report the results as structured evidence.

## Steps

1. Run the checkpoint script:
   ```bash
   bash scripts/review/checkpoint.sh
   ```

2. If any check fails, report EXACTLY what failed with the raw output.
   Do not interpret or suggest fixes — just report the facts.

3. Format the output as an evidence summary:

```
══ CHECKPOINT EVIDENCE ═══════════════════════════
│  Lint:       PASS/FAIL (N errors)
│  Typecheck:  PASS/FAIL (N errors)
│  Tests:      PASS/FAIL (N passed, M failed)
│  Test count: before → after (delta: +/-N)
│  Modified:   [list of changed test files]
═══════════════════════════════════════════════════
```

4. If ALL pass, say "CHECKPOINT PASSED — ready for enforcer."
   If ANY fail, say "CHECKPOINT FAILED — implementer must fix before proceeding."
