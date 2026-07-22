#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
files=(plugin/commands/refactor/scripts/detect-zones.sh plugin/commands/seam/scripts/detect-zones.sh scripts/atlas/detect-zones.sh)
hashes=$(shasum "${files[@]}" | awk '{print $1}' | sort -u | wc -l | tr -d ' ')
if [ "$hashes" != "1" ]; then
  echo "FAIL: detect-zones.sh copies diverged:" >&2
  shasum "${files[@]}" >&2
  exit 1
fi
echo "OK: all 3 detect-zones.sh copies identical"
