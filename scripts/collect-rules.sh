#!/bin/bash
# collect-rules.sh — Concatenate all docs/rules/*.md files
# Usage: ./collect-rules.sh [repo-root]

REPO="${1:-$(git rev-parse --show-toplevel)}"
RULES_DIR="$REPO/docs/rules"

if [ ! -d "$RULES_DIR" ]; then
  echo "ERROR: Rules directory not found at $RULES_DIR" >&2
  exit 1
fi

echo "# Project Rules (from docs/rules/)"
echo ""

for f in "$RULES_DIR"/*.md; do
  [ -f "$f" ] || continue
  echo "## $(basename "$f" .md)"
  echo ""
  cat "$f"
  echo ""
  echo "---"
  echo ""
done
