#!/bin/bash
# gate-seams.sh — Gate 3: Enabling Point Existence Check
#
# Verifies that each seam candidate's enabling point actually exists
# in the source code by running its verification_grep command.
# Candidates with missing enabling points are eliminated.
# At least 1 candidate must survive for the gate to pass.
#
# Usage:
#   bash gate-seams.sh <seams_yaml> <state_dir>
#
# Inputs:
#   $1 — Path to 3_seams.yaml
#   $2 — Path to state directory (.sourceatlas/refactor/{module}/)
#
# Outputs:
#   - Prints PASS/FAIL/ELIMINATED per candidate
#   - Updates state.yaml: 3_gate status, candidates_total, candidates_verified
#   - Exit 0 = gate passed (≥1 candidate verified), Exit 1 = gate failed
set -euo pipefail

SEAMS_FILE="${1:?Usage: gate-seams.sh <seams_yaml> <state_dir>}"
STATE_DIR="${2:?Usage: gate-seams.sh <seams_yaml> <state_dir>}"
STATE_FILE="${STATE_DIR}/state.yaml"

if [ ! -f "$SEAMS_FILE" ]; then
    echo "❌ Seams file not found: $SEAMS_FILE"
    exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
    echo "❌ State file not found: $STATE_FILE"
    exit 1
fi

TARGET_FILE=$(grep '^file:' "$STATE_FILE" | head -1 | sed 's/^file: *//' | tr -d '"')
if [ ! -f "$TARGET_FILE" ]; then
    echo "❌ Target file not found: $TARGET_FILE"
    exit 1
fi

TOTAL=0
VERIFIED=0
ELIMINATED=""

# ─────────────────────────────────────────────────────────
# Helper: update state.yaml
# ─────────────────────────────────────────────────────────

update_state() {
    local gate_status="$1"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update 3_seams status
    if [ "$gate_status" = "pass" ]; then
        sed -i '' "s/  3_seams: .*/  3_seams: { status: verified, completed_at: \"$timestamp\" }/" "$STATE_FILE" 2>/dev/null || true
    fi

    # Update 3_gate
    sed -i '' "s/  3_gate: .*/  3_gate: { status: $gate_status, completed_at: \"$timestamp\", candidates_total: $TOTAL, candidates_verified: $VERIFIED }/" "$STATE_FILE" 2>/dev/null || true
}

echo "📋 Verifying seam enabling points in: $TARGET_FILE"
echo ""

# ─────────────────────────────────────────────────────────
# Extract and verify each candidate's enabling point
# ─────────────────────────────────────────────────────────

# Extract verification_grep lines from seams YAML
# Expected format:
#   seam_candidates:
#     - seam_type: "object"
#       target_dependency: "CocoaSecurity"
#       enabling_point: "constructor injection via initWithBaseURL:"
#       verification_grep: "grep -qn 'initWithBaseURL:' NYHTTPSClient.m"
#       ...

# Parse candidate blocks
CURRENT_DEP=""
CURRENT_TYPE=""
CURRENT_GREP=""

while IFS= read -r line; do
    # Detect new candidate block
    if echo "$line" | grep -q '^\s*- seam_type:'; then
        # Process previous candidate if exists
        if [ -n "$CURRENT_GREP" ]; then
            TOTAL=$((TOTAL + 1))
            LABEL="${CURRENT_TYPE}(${CURRENT_DEP})"

            # Sanity check: verification_grep must start with a known search command
            if ! echo "$CURRENT_GREP" | grep -qE '^(grep|ast-grep|rg) '; then
                echo "PARSE_ERROR [$LABEL] — verification_grep is not a valid search command: $CURRENT_GREP"
                ELIMINATED="${ELIMINATED}\n  - $LABEL: PARSE_ERROR ($CURRENT_GREP)"
            else
                set +e
                eval "$CURRENT_GREP" > /dev/null 2>&1
                RESULT=$?
                set -e

                if [ "$RESULT" -eq 0 ]; then
                    echo "PASS [$LABEL] — enabling point exists"
                    VERIFIED=$((VERIFIED + 1))
                else
                    echo "ELIMINATED [$LABEL] — enabling point not found"
                    ELIMINATED="${ELIMINATED}\n  - $LABEL: $CURRENT_GREP"
                fi
            fi
        fi

        # Reset for new candidate
        CURRENT_TYPE=$(echo "$line" | sed 's/.*seam_type: *"\{0,1\}//' | sed 's/"\{0,1\} *$//')
        CURRENT_DEP=""
        CURRENT_GREP=""
    fi

    # Extract fields
    if echo "$line" | grep -q 'target_dependency:'; then
        CURRENT_DEP=$(echo "$line" | sed 's/.*target_dependency: *"\{0,1\}//' | sed 's/"\{0,1\} *$//')
    fi
    if echo "$line" | grep -q 'verification_grep:'; then
        CURRENT_GREP=$(echo "$line" | sed 's/.*verification_grep: *"\{0,1\}//' | sed 's/"\{0,1\} *$//')
    fi
done < "$SEAMS_FILE"

# Process last candidate
if [ -n "$CURRENT_GREP" ]; then
    TOTAL=$((TOTAL + 1))
    LABEL="${CURRENT_TYPE}(${CURRENT_DEP})"

    # Sanity check: verification_grep must start with a known search command
    if ! echo "$CURRENT_GREP" | grep -qE '^(grep|ast-grep|rg) '; then
        echo "PARSE_ERROR [$LABEL] — verification_grep is not a valid search command: $CURRENT_GREP"
        ELIMINATED="${ELIMINATED}\n  - $LABEL: PARSE_ERROR ($CURRENT_GREP)"
    else
        set +e
        eval "$CURRENT_GREP" > /dev/null 2>&1
        RESULT=$?
        set -e

        if [ "$RESULT" -eq 0 ]; then
            echo "PASS [$LABEL] — enabling point exists"
            VERIFIED=$((VERIFIED + 1))
        else
            echo "ELIMINATED [$LABEL] — enabling point not found"
            ELIMINATED="${ELIMINATED}\n  - $LABEL: $CURRENT_GREP"
        fi
    fi
fi

# ─────────────────────────────────────────────────────────
# Final verdict
# ─────────────────────────────────────────────────────────

echo ""
echo "════════════════════════════════════════"

if [ "$TOTAL" -eq 0 ]; then
    echo "Gate 3: FAILED (no seam candidates with verification_grep found)"
    echo ""
    echo "Each seam candidate in 3_seams.yaml must have a verification_grep field."
    echo "Expected format:"
    echo "  verification_grep: \"grep -qn 'pattern' file\""
    update_state "fail"
    exit 1
elif [ "$VERIFIED" -eq 0 ]; then
    echo "Gate 3: FAILED"
    echo "Candidates: 0/$TOTAL verified — all enabling points missing from source"
    if [ -n "$ELIMINATED" ]; then
        echo ""
        echo "Eliminated:"
        echo -e "$ELIMINATED"
    fi
    echo ""
    echo "Re-run: /atlas.refactor <file> --step 3 --force"
    update_state "fail"
    exit 1
else
    echo "Gate 3: PASSED"
    echo "Candidates: $VERIFIED/$TOTAL verified"
    if [ -n "$ELIMINATED" ]; then
        echo ""
        echo "Eliminated (non-blocking):"
        echo -e "$ELIMINATED"
        echo ""
        echo "Recommended seam auto-selected from verified candidates only."
    fi
    update_state "pass"
    exit 0
fi
