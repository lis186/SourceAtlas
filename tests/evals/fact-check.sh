#!/usr/bin/env bash
# fact-check.sh — mechanically verify claims in SourceAtlas YAML output
#
# Usage: fact-check.sh <yaml-file> [--cwd <target-repo>]
#
# Extracts verifiable claims (file paths, directories, git branch,
# file counts) from a SourceAtlas output YAML file and checks each
# against the actual filesystem/git state of the target repo.
#
# Exit code: 0 if all claims pass, 1 if any fail.
# Output: one line per claim (PASS/FAIL/WARN), summary at end.

set -euo pipefail

die() { echo "ERROR: $1" >&2; exit 2; }

YAML_FILE=""
TARGET_CWD="."

while [ $# -gt 0 ]; do
  case "$1" in
    --cwd) TARGET_CWD="$2"; shift 2 ;;
    --help|-h)
      sed -n '3,12p' "$0"; exit 0 ;;
    *)
      [ -z "$YAML_FILE" ] && YAML_FILE="$1" || die "unexpected arg: $1"
      shift ;;
  esac
done

[ -z "$YAML_FILE" ] && die "usage: fact-check.sh <yaml-file> [--cwd <target-repo>]"
[ -f "$YAML_FILE" ] || die "file not found: $YAML_FILE"
command -v yq >/dev/null 2>&1 || die "yq required but not found"

PASS=0
FAIL=0
WARN=0

check() {
  local status="$1" msg="$2"
  case "$status" in
    PASS) PASS=$((PASS + 1)); echo "  PASS: $msg" ;;
    FAIL) FAIL=$((FAIL + 1)); echo "  FAIL: $msg" ;;
    WARN) WARN=$((WARN + 1)); echo "  WARN: $msg" ;;
  esac
}

echo "fact-check: $YAML_FILE (cwd: $TARGET_CWD)"
echo

# --- 1. scanned_files[].file must exist ---
echo "[scanned_files]"
files=$(yq -r '.scanned_files[].file' "$YAML_FILE" 2>/dev/null || true)
if [ -z "$files" ]; then
  check WARN "no scanned_files entries found"
else
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ -f "$TARGET_CWD/$f" ]; then
      check PASS "$f exists"
    else
      check FAIL "$f does not exist"
    fi
  done <<< "$files"
fi
echo

# --- 2. metadata.context.git_branch ---
echo "[git_branch]"
claimed_branch=$(yq -r '.metadata.context.git_branch' "$YAML_FILE" 2>/dev/null || true)
if [ -n "$claimed_branch" ] && [ "$claimed_branch" != "null" ]; then
  actual_branch=$(git -C "$TARGET_CWD" branch --show-current 2>/dev/null || echo "")
  if [ "$claimed_branch" = "$actual_branch" ]; then
    check PASS "git_branch '$claimed_branch' matches"
  else
    # ponytail: branch may have changed since scan — WARN not FAIL
    check WARN "git_branch claimed '$claimed_branch', actual '$actual_branch' (may have changed since scan)"
  fi
else
  check WARN "no git_branch claim"
fi
echo

# --- 3. metadata.total_files (±20% tolerance) ---
echo "[file_counts]"
claimed_total=$(yq -r '.metadata.total_files' "$YAML_FILE" 2>/dev/null || true)
if [ -n "$claimed_total" ] && [ "$claimed_total" != "null" ]; then
  actual_total=$(find "$TARGET_CWD" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ')
  min=$((claimed_total * 80 / 100))
  max=$((claimed_total * 120 / 100))
  if [ "$actual_total" -ge "$min" ] && [ "$actual_total" -le "$max" ]; then
    check PASS "total_files $claimed_total within ±20% of actual $actual_total"
  else
    check FAIL "total_files claimed $claimed_total, actual $actual_total (outside ±20%)"
  fi
else
  check WARN "no total_files claim"
fi

claimed_scanned=$(yq -r '.metadata.scanned_files' "$YAML_FILE" 2>/dev/null || true)
if [ -n "$claimed_scanned" ] && [ "$claimed_scanned" != "null" ]; then
  actual_scanned=$(yq -r '.scanned_files | length' "$YAML_FILE" 2>/dev/null || echo 0)
  if [ "$claimed_scanned" -eq "$actual_scanned" ]; then
    check PASS "scanned_files count $claimed_scanned matches array length"
  else
    check FAIL "metadata.scanned_files=$claimed_scanned but array has $actual_scanned entries"
  fi
fi
echo

# --- 4. hypotheses evidence file:line references (sample up to 10) ---
echo "[evidence_refs]"
# Extract file references from evidence fields (pattern: "path/file.ext:NN")
# ponytail: yq v4 can't easily flatten nested map-of-arrays; grep the raw YAML instead
evidence_refs=$(grep -E '^\s+evidence:' "$YAML_FILE" | sed 's/.*evidence: *"*//' | sed 's/"*$//' \
  | grep -oE '[A-Za-z0-9_./-]+\.[a-z]+:[0-9]+' | head -10 || true)

if [ -z "$evidence_refs" ]; then
  check WARN "no file:line evidence references found"
else
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    ref_file="${ref%%:*}"
    ref_line="${ref##*:}"
    if [ ! -f "$TARGET_CWD/$ref_file" ]; then
      check FAIL "evidence ref $ref — file does not exist"
    else
      total_lines=$(wc -l < "$TARGET_CWD/$ref_file" | tr -d ' ')
      if [ "$ref_line" -le "$total_lines" ]; then
        check PASS "evidence ref $ref — file exists, line in range"
      else
        check FAIL "evidence ref $ref — line $ref_line > file length $total_lines"
      fi
    fi
  done <<< "$evidence_refs"
fi
echo

# --- 5. ai_collaboration.tools_detected[].config_file ---
echo "[config_files]"
config_files=$(yq -r '.hypotheses.ai_collaboration.tools_detected[].config_file' "$YAML_FILE" 2>/dev/null || true)
if [ -z "$config_files" ]; then
  check WARN "no config_file claims"
else
  while IFS= read -r cf; do
    [ -z "$cf" ] && continue
    if [ -f "$TARGET_CWD/$cf" ] || [ -d "$TARGET_CWD/$cf" ]; then
      check PASS "config_file '$cf' exists"
    else
      check FAIL "config_file '$cf' does not exist"
    fi
  done <<< "$config_files"
fi
echo

# --- Summary ---
total=$((PASS + FAIL + WARN))
echo "=========================================="
echo "TOTAL: $total checks | PASS: $PASS | FAIL: $FAIL | WARN: $WARN"

if [ "$FAIL" -gt 0 ]; then
  echo "RESULT: FAILED ($FAIL failures)"
  exit 1
else
  echo "RESULT: PASSED (0 failures, $WARN warnings)"
  exit 0
fi
