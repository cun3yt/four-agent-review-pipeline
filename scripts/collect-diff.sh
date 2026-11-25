#!/bin/bash
# collect-diff.sh — Get the diff between main and current HEAD
# Usage: ./collect-diff.sh [worktree-path] [--files-only]

WORK_DIR="${1:-.}"
cd "$WORK_DIR" || exit 2

if [ "$2" = "--files-only" ]; then
  git diff main...HEAD --name-only
else
  git diff main...HEAD
fi
