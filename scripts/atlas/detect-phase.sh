#!/usr/bin/env bash
# detect-phase.sh — Detect refactoring phase (1 / 1.5 / 2) for a target module
#
# Usage: detect-phase.sh <file-path> [--project-root <dir>]
#
# Output: YAML to stdout
#
# Phase logic:
#   Phase 1   — test_refs == 0: zero coverage → Feathers ordering (testability first)
#   Phase 1.5 — test_refs  < 3: partial coverage → Feathers ordering (expand coverage first)
#   Phase 2   — test_refs >= 3: sufficient coverage → architectural value ordering
#
# Exit codes:
#   0 - success
#   1 - file not found

set -uo pipefail

FILE_PATH="${1:?Usage: detect-phase.sh <file-path> [--project-root <dir>]}"
PROJECT_ROOT=""

shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-root) PROJECT_ROOT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ ! -f "$FILE_PATH" ]]; then
    echo "error: file not found: $FILE_PATH" >&2
    exit 1
fi

MODULE_NAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')

# Auto-detect project root: walk up from file to find .git / Podfile / package.json
if [[ -z "$PROJECT_ROOT" ]]; then
    DIR=$(dirname "$(cd "$(dirname "$FILE_PATH")" && pwd)/$(basename "$FILE_PATH")")
    while [[ "$DIR" != "/" ]]; do
        if [[ -d "$DIR/.git" ]] || [[ -f "$DIR/Podfile" ]] || [[ -f "$DIR/package.json" ]] || [[ -f "$DIR/go.mod" ]]; then
            PROJECT_ROOT="$DIR"
            break
        fi
        DIR=$(dirname "$DIR")
    done
    PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

# Source file extensions to search
# ObjC: .m .h  |  ObjC++: .mm  |  Swift: .swift
EXTS=(--include="*.m" --include="*.mm" --include="*.h"
      --include="*.swift" --include="*.ts" --include="*.tsx"
      --include="*.js" --include="*.jsx" --include="*.py"
      --include="*.go" --include="*.java" --include="*.kt")

# Files referencing the module name
ALL_REFS=$(grep -rl "$MODULE_NAME" "$PROJECT_ROOT" "${EXTS[@]}" 2>/dev/null || true)

TEST_REFS=$(echo "$ALL_REFS" | grep -iE "test|spec" | wc -l | tr -d ' ')
PROD_REFS=$(echo "$ALL_REFS" | grep -viE "test|spec" | grep -v "^$" | wc -l | tr -d ' ')

# Phase decision
if [[ "$TEST_REFS" -eq 0 ]]; then
    PHASE="1"
    RANKING="feathers"
    RATIONALE="Zero test coverage — sort zones by testability (Feathers: least edit distance to working test)"
elif [[ "$TEST_REFS" -lt 3 ]]; then
    PHASE="1.5"
    RANKING="feathers"
    RATIONALE="Partial coverage (${TEST_REFS} test file(s)) — expand coverage before restructuring"
else
    PHASE="2"
    RANKING="architectural"
    RATIONALE="Sufficient coverage (${TEST_REFS} test files) — sort zones by architectural value"
fi

cat <<YAML
phase_detection:
  module: "${MODULE_NAME}"
  file: "${FILE_PATH}"
  project_root: "${PROJECT_ROOT}"
  phase: "${PHASE}"
  test_refs: ${TEST_REFS}
  prod_refs: ${PROD_REFS}
  ranking_strategy: "${RANKING}"
  rationale: "${RATIONALE}"
YAML
