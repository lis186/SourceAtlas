#!/bin/bash
# gate-contracts.sh — Gate 2: Contract Verification Dry-Run
#
# Runs grep/ast-grep verification rules from the contracts artifact
# against the source file. ALL rules must pass for the gate to pass.
#
# Usage:
#   bash gate-contracts.sh <contracts_yaml> <state_dir>
#
# Inputs:
#   $1 — Path to 2_contracts.yaml (or verify-contracts-*.sh if exists)
#   $2 — Path to state directory (.sourceatlas/refactor/{module}/)
#
# Outputs:
#   - Prints PASS/FAIL per rule
#   - Updates state.yaml: 2_gate status, rules_total, rules_passed
#   - Exit 0 = gate passed, Exit 1 = gate failed
#
# Design:
#   Modeled after nineyiappshop verify-contracts-*.sh (v4.1)
#   Same assert_match/assert_no_match pattern, same exit code semantics
set -euo pipefail

CONTRACTS_FILE="${1:?Usage: gate-contracts.sh <contracts_yaml> <state_dir>}"
STATE_DIR="${2:?Usage: gate-contracts.sh <contracts_yaml> <state_dir>}"
STATE_FILE="${STATE_DIR}/state.yaml"

if [ ! -f "$CONTRACTS_FILE" ]; then
    echo "❌ Contracts file not found: $CONTRACTS_FILE"
    exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
    echo "❌ State file not found: $STATE_FILE"
    exit 1
fi

# Extract target file from state
TARGET_FILE=$(grep '^file:' "$STATE_FILE" | head -1 | sed 's/^file: *//' | tr -d '"')
if [ ! -f "$TARGET_FILE" ]; then
    echo "❌ Target file not found: $TARGET_FILE"
    exit 1
fi

PASS=0
FAIL=0
TOTAL=0
FAILURES=""

# ─────────────────────────────────────────────────────────
# Helper: update state.yaml
# ─────────────────────────────────────────────────────────

update_state() {
    local gate_status="$1"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update 2_contracts status
    if [ "$gate_status" = "pass" ]; then
        sed -i '' "s/  2_contracts: .*/  2_contracts: { status: verified, completed_at: \"$timestamp\", audit_mode: null }/" "$STATE_FILE" 2>/dev/null || true
    fi

    # Update 2_gate
    sed -i '' "s/  2_gate: .*/  2_gate: { status: $gate_status, completed_at: \"$timestamp\", rules_total: $TOTAL, rules_passed: $PASS }/" "$STATE_FILE" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────
# Rule extraction and execution
# ─────────────────────────────────────────────────────────

# Strategy 1: If a verify-contracts-*.sh exists (from /atlas.audit pipeline),
# run it directly — it's the gold standard
MODULE_NAME=$(grep '^module:' "$STATE_FILE" | head -1 | sed 's/^module: *//' | tr -d '"')
VERIFY_SCRIPT=""

# Check audit output for existing verify script
for candidate in \
    ".sourceatlas/audit/verify-contracts-${MODULE_NAME}.sh" \
    ".sourceatlas/audit/runs/*/verify-contracts-${MODULE_NAME}.sh"; do
    # shellcheck disable=SC2086
    found=$(ls $candidate 2>/dev/null | tail -1 || true)
    if [ -n "$found" ] && [ -f "$found" ]; then
        VERIFY_SCRIPT="$found"
        break
    fi
done

if [ -n "$VERIFY_SCRIPT" ]; then
    echo "📋 Running existing verify script: $VERIFY_SCRIPT"
    echo ""

    # Capture output and exit code
    set +e
    OUTPUT=$(bash "$VERIFY_SCRIPT" 2>&1)
    EXIT_CODE=$?
    set -e

    echo "$OUTPUT"

    # Parse results from output
    PASS=$(echo "$OUTPUT" | grep -c "^PASS " || true)
    FAIL=$(echo "$OUTPUT" | grep -c "^FAIL " || true)
    TOTAL=$((PASS + FAIL))
    FAILURES=$(echo "$OUTPUT" | grep "^FAIL " || true)

    if [ "$EXIT_CODE" -ne 0 ]; then
        echo ""
        # Distinguish script crash from assertion failures
        if ! echo "$OUTPUT" | grep -q "^Results:"; then
            echo "❌ Gate 2 ERROR: verify script crashed (exit $EXIT_CODE) — not an assertion failure"
            echo "   Check script syntax: bash -n $VERIFY_SCRIPT"
        else
            echo "❌ Gate 2 FAILED: $PASS/$TOTAL verification rules passed"
        fi
        update_state "fail"
        exit 1
    fi
else
    # Strategy 2: Extract verification_grep from contracts YAML and run each
    echo "📋 Extracting verification rules from: $CONTRACTS_FILE"
    echo ""

    # Extract lines matching verification patterns
    # Contracts YAML format expected:
    #   verification:
    #     - grep: "pattern"
    #       file: "path"
    #     - grep: "pattern"  (defaults to TARGET_FILE)
    #
    # Or simpler format:
    #   verification_grep: "grep -qn 'pattern' file"

    # Try extraction method A: verification_grep fields
    while IFS= read -r line; do
        if [ -z "$line" ]; then continue; fi
        TOTAL=$((TOTAL + 1))

        # Extract contract ID context (best effort)
        CONTRACT_ID="R${TOTAL}"

        set +e
        eval "$line" > /dev/null 2>&1
        RESULT=$?
        set -e

        if [ "$RESULT" -eq 0 ]; then
            echo "PASS [$CONTRACT_ID]"
            PASS=$((PASS + 1))
        else
            echo "FAIL [$CONTRACT_ID] — $line"
            FAIL=$((FAIL + 1))
            FAILURES="${FAILURES}\n  - [$CONTRACT_ID] $line"
        fi
    # Final sed unescapes YAML \" sequences inside double-quoted scalars —
    # without it, rules containing quotes reach eval as literal \" and fail.
    done < <(grep 'verification_grep:' "$CONTRACTS_FILE" | sed 's/.*verification_grep: *"\{0,1\}//' | sed 's/"\{0,1\} *$//' | sed 's/\\"/"/g')

    # Try extraction method B: verification.grep fields (nested YAML)
    if [ "$TOTAL" -eq 0 ]; then
        while IFS= read -r pattern; do
            if [ -z "$pattern" ]; then continue; fi
            TOTAL=$((TOTAL + 1))
            CONTRACT_ID="R${TOTAL}"

            set +e
            grep -qn "$pattern" "$TARGET_FILE"
            RESULT=$?
            set -e

            if [ "$RESULT" -eq 0 ]; then
                echo "PASS [$CONTRACT_ID]"
                PASS=$((PASS + 1))
            else
                echo "FAIL [$CONTRACT_ID] — pattern not found: $pattern in $TARGET_FILE"
                FAIL=$((FAIL + 1))
                FAILURES="${FAILURES}\n  - [$CONTRACT_ID] $pattern"
            fi
        done < <(grep '^\s*- grep:' "$CONTRACTS_FILE" | sed 's/.*- grep: *"\{0,1\}//' | sed 's/"\{0,1\} *$//')
    fi

    if [ "$TOTAL" -eq 0 ]; then
        echo "⚠️ No verification rules found in contracts file"
        echo "Gate 2 cannot verify — contracts may lack verification_grep fields"
        echo ""
        echo "Expected format in contracts YAML:"
        echo "  verification_grep: \"grep -qn 'pattern' file\""
        echo ""
        echo "Marking as DEGRADED (not failed)"
        PASS=0
        TOTAL=0
    fi
fi

# ─────────────────────────────────────────────────────────
# Final verdict
# ─────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"

if [ "$TOTAL" -eq 0 ]; then
    echo "Gate 2: DEGRADED (no verification rules found)"
    echo "Rules: 0/0"
    update_state "degraded"
    # Degraded = proceed with caution, not a hard fail
    exit 0
elif [ "$FAIL" -eq 0 ]; then
    echo "Gate 2: PASSED"
    echo "Rules: $PASS/$TOTAL passed"
    update_state "pass"
    exit 0
else
    echo "Gate 2: FAILED"
    echo "Rules: $PASS/$TOTAL passed, $FAIL failed"
    if [ -n "$FAILURES" ]; then
        echo ""
        echo "Failed rules:"
        echo -e "$FAILURES"
    fi
    update_state "fail"
    exit 1
fi
