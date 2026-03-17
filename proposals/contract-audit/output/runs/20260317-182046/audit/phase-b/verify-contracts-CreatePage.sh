#!/bin/bash
# verify-contracts-CreatePage.sh
# Generated: 2026-03-17
# Final contracts: audit/output/final-contracts.md
set -e
PASS=0; FAIL=0
assert_match() {
  local id="$1" pattern="$2" file="$3"
  if grep -qn "$pattern" "$file"; then
    echo "PASS [$id]"; ((PASS++))
  else
    echo "FAIL [$id] -- pattern not found: $pattern"; ((FAIL++))
  fi
}

TARGET="create-page.js"

# S-001: Promise wrapping readline.question
assert_match "S-001" "new Promise.*rl.question" "$TARGET"

# S-002: async main function (Scope corrected to method per DISPUTE)
assert_match "S-002" "async function main" "$TARGET"

# S-003: Synchronous fs operations
assert_match "S-003" "fs.mkdirSync" "$TARGET"

# D-001: Node.js built-in requires (Seam_Type corrected to link per META_ISSUE)
assert_match "D-001a" "require('fs')" "$TARGET"
assert_match "D-001b" "require('path')" "$TARGET"
assert_match "D-001c" "require('readline')" "$TARGET"

# D-002: process.cwd() dependency (Risk lowered to MEDIUM per DISPUTE)
assert_match "D-002" "process.cwd()" "$TARGET"

# D-003: example folder existence check
assert_match "D-003" "src.*app.*example" "$TARGET"

# D-004: process.stdin/stdout (Condition corrected: no isTTY check per DISPUTE)
assert_match "D-004" "process.stdin" "$TARGET"

# D-005: Dynamic import in template string
assert_match "D-005" "import('@/app/" "$TARGET"

# D-006: Manual registry update dependency (ADD)
assert_match "D-006" "config-registry" "$TARGET"

# E-001: try-catch wrapping main logic
assert_match "E-001a" "try {" "$TARGET"
assert_match "E-001b" "catch (error)" "$TARGET"

# E-002: Validation early exit
assert_match "E-002" 'kebab-case' "$TARGET"

# M-001: Directory creation (Risk lowered to LOW per DISPUTE)
assert_match "M-001" "mkdirSync.*recursive" "$TARGET"

# M-002: File write
assert_match "M-002" "writeFileSync" "$TARGET"

# M-003: Multiple replacement strategies (Risk lowered to HIGH per DISPUTE)
# M-003a: quoted pattern
assert_match "M-003a" "quotedRegex" "$TARGET"
# M-003b: comment pattern
assert_match "M-003b" "commentRegex" "$TARGET"
# M-003c: word boundary pattern
assert_match "M-003c" "wordRegex" "$TARGET"

# M-004: README.md skip (ADD)
assert_match "M-004" "README.md" "$TARGET"

# L-001: readline lifecycle - create and close
assert_match "L-001a" "readline.createInterface" "$TARGET"
assert_match "L-001b" "finally" "$TARGET"

# C-001: Early exit on validation failure
assert_match "C-001" "rl.close.*return\|return.*rl.close" "$TARGET"

# C-002: finally block cleanup (ADD)
assert_match "C-002" "finally.*{" "$TARGET"

# P-001: replacements propagation
assert_match "P-001" "replacements" "$TARGET"

# P-002: generateId with Date.now
assert_match "P-002" "Date.now()" "$TARGET"

# N-001: Console notification channel (ADD)
assert_match "N-001" "log\.\(success\|error\|info\)" "$TARGET"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
