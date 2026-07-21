#!/usr/bin/env bash
# Schema check for overview.yaml — verifies required fields exist.
# Usage: overview.sh <yaml-file>
# Exit 0 if all required fields present, 1 if any missing.

set -euo pipefail

YAML_FILE="${1:?usage: overview.sh <yaml-file>}"
[ -f "$YAML_FILE" ] || { echo "ERROR: $YAML_FILE not found" >&2; exit 2; }

PASS=0
FAIL=0

require() {
  local path="$1"
  val=$(yq -r "$path" "$YAML_FILE" 2>/dev/null || true)
  if [ -n "$val" ] && [ "$val" != "null" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  MISSING: $path"
  fi
}

echo "schema-check: $YAML_FILE"
require '.metadata.project_name'
require '.metadata.scan_time'
require '.metadata.total_files'
require '.metadata.scanned_files'
require '.metadata.project_scale'
require '.project_fingerprint.project_type'
require '.project_fingerprint.primary_language'
require '.hypotheses.architecture'
require '.hypotheses.tech_stack'
require '.hypotheses.business'
require '.tech_stack'
require '.scanned_files'
require '.summary.understanding_depth'
require '.summary.key_findings'

echo "TOTAL: $((PASS + FAIL)) | PASS: $PASS | MISSING: $FAIL"
[ "$FAIL" -eq 0 ] && echo "RESULT: PASSED" || { echo "RESULT: FAILED"; exit 1; }
