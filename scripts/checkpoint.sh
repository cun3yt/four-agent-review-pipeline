#!/bin/bash
#
# @fileoverview Quality gate that runs lint, typecheck, and tests, then outputs
# a machine-readable JSON evidence report to stdout.
#
# Designed for automated review pipelines — an agent or CI step can parse the
# JSON to decide whether a branch is safe to merge. Also tracks test count
# delta (before vs after) to catch test deletions that mask failures.
#
# @usage
#   ./checkpoint.sh [worktree-path] [base-branch]
#
# @param worktree-path  Directory to run checks in (default: current dir ".")
# @param base-branch    Branch to compare against for test delta and modified
#                       files. Auto-detected via 3-layer fallback if omitted:
#                         1. Explicit $2 argument
#                         2. GitHub PR base branch (via `gh pr view`)
#                         3. Falls back to "main"
#
# @returns JSON to stdout with structure:
#   {
#     "allPass":           boolean,   -- true only if lint + typecheck + tests all pass
#     "baseBranch":        string,    -- which branch was compared against
#     "timestamp":         string,    -- UTC ISO 8601
#     "lint":              { pass, exitCode, errorCount },
#     "typecheck":         { pass, exitCode, errorCount },
#     "tests":             { pass, exitCode, passed, failed },
#     "testCount":         { before, after, delta },
#     "modifiedTestFiles": string     -- comma-separated list of changed test files
#   }
#
# @exits
#   0 — all checks passed
#   1 — one or more checks failed (JSON still written to stdout)
#   2 — invalid worktree-path (directory does not exist)
#
# @requires pnpm, git, gh (optional, for PR base detection)
#
# @example
#   # Auto-detect base branch from open PR
#   ./checkpoint.sh .
#
#   # Explicit base branch
#   ./checkpoint.sh . develop
#
#   # Run in a git worktree
#   ./checkpoint.sh /tmp/worktree-abc123 main
#

set -o pipefail

WORK_DIR="${1:-.}"
cd "$WORK_DIR" || exit 2

# ─── Detect base branch (3-layer fallback) ───────────────────
# Layer 1: Explicit argument ($2) — caller knows the target
# Layer 2: GitHub PR base — reads actual PR target via gh CLI
# Layer 3: Default to "main"
if [ -n "$2" ]; then
  BASE_BRANCH="$2"
elif command -v gh &>/dev/null; then
  BASE_BRANCH=$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null || echo "main")
else
  BASE_BRANCH="main"
fi

# ─── Count tests BEFORE (from base branch) ───────────────────
TEST_COUNT_BEFORE=$(git ls-tree -r --name-only "$BASE_BRANCH" 2>/dev/null | \
  grep -E '\.test\.(ts|tsx)$' | \
  xargs -I{} git show "${BASE_BRANCH}:{}" 2>/dev/null | \
  grep -c '\bit(' 2>/dev/null || echo "0")

# ─── Run checks ─────────────────────────────────────────────
LINT_OUTPUT=$(pnpm lint 2>&1); LINT_EXIT=$?
TYPE_OUTPUT=$(pnpm typecheck 2>&1); TYPE_EXIT=$?
TEST_OUTPUT=$(pnpm test 2>&1); TEST_EXIT=$?

# ─── Count tests AFTER ──────────────────────────────────────
TEST_COUNT_AFTER=$(find . -name '*.test.ts' -o -name '*.test.tsx' | \
  xargs grep -c '\bit(' 2>/dev/null | \
  awk -F: '{sum+=$NF} END{print sum+0}')

# ─── Modified test files ────────────────────────────────────
MODIFIED_TESTS=$(git diff "${BASE_BRANCH}...HEAD" --name-only -- '*.test.ts' '*.test.tsx' 2>/dev/null | tr '\n' ',' | sed 's/,$//')

# ─── Lint error count ───────────────────────────────────────
LINT_ERRORS=$(echo "$LINT_OUTPUT" | grep -cE '(error|Error)' 2>/dev/null || echo "0")

# ─── Typecheck error count ──────────────────────────────────
TYPE_ERRORS=$(echo "$TYPE_OUTPUT" | grep -cE 'error TS' 2>/dev/null || echo "0")

# ─── Test result parsing ────────────────────────────────────
TESTS_PASSED=$(echo "$TEST_OUTPUT" | grep -oE '[0-9]+ passed' | head -1 | grep -oE '[0-9]+' || echo "0")
TESTS_FAILED=$(echo "$TEST_OUTPUT" | grep -oE '[0-9]+ failed' | head -1 | grep -oE '[0-9]+' || echo "0")

# ─── Build evidence JSON ────────────────────────────────────
ALL_PASS="true"
[ $LINT_EXIT -ne 0 ] || [ $TYPE_EXIT -ne 0 ] || [ $TEST_EXIT -ne 0 ] && ALL_PASS="false"

cat <<EOF
{
  "allPass": $ALL_PASS,
  "baseBranch": "$BASE_BRANCH",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "lint": {
    "pass": $([ $LINT_EXIT -eq 0 ] && echo true || echo false),
    "exitCode": $LINT_EXIT,
    "errorCount": $LINT_ERRORS
  },
  "typecheck": {
    "pass": $([ $TYPE_EXIT -eq 0 ] && echo true || echo false),
    "exitCode": $TYPE_EXIT,
    "errorCount": $TYPE_ERRORS
  },
  "tests": {
    "pass": $([ $TEST_EXIT -eq 0 ] && echo true || echo false),
    "exitCode": $TEST_EXIT,
    "passed": $TESTS_PASSED,
    "failed": $TESTS_FAILED
  },
  "testCount": {
    "before": $TEST_COUNT_BEFORE,
    "after": $TEST_COUNT_AFTER,
    "delta": $((TEST_COUNT_AFTER - TEST_COUNT_BEFORE))
  },
  "modifiedTestFiles": "$MODIFIED_TESTS"
}
EOF

[ "$ALL_PASS" = "true" ] && exit 0 || exit 1
