#!/bin/bash
# count-tests.sh — Count it() blocks across all test files
# Usage: ./count-tests.sh [directory]

DIR="${1:-.}"
find "$DIR" -name '*.test.ts' -o -name '*.test.tsx' | \
  xargs grep -c '\bit(' 2>/dev/null | \
  awk -F: '{sum+=$NF} END{print sum+0}'
