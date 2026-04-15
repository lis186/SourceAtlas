#!/usr/bin/env bash
# gate-step7.sh — Step 7 Verification Gate (Hard Gate).
#
# Runs three check categories and decides whether the refactor is safe
# to proceed into Steps 8-13 (the actual rewrite):
#
#   7.1 Spike tests         — executed if state.yaml has spike_tests_cmd
#   7.2 Characterization    — executed if state.yaml has characterization_tests_cmd
#   7.3 Contract CI rules   — runs verification_grep from 2_contracts.yaml
#
# Writes 7_gate_results.yaml and updates state.yaml:
#   steps.7_gate: { status: pass|fail, completed_at, ... }
#
# Usage:
#   gate-step7.sh <state_dir>
#
# Optional environment variables:
#   SPIKE_CMD           override spike test command
#   CHARACTERIZATION_CMD  override characterization test command
#   CONTRACTS_FILE      override path to 2_contracts.yaml
#
# Exit codes:
#   0 — all checks passed (overall: pass)
#   1 — at least one check failed (overall: fail)
#   2 — usage / file-not-found errors
#
set -euo pipefail

STATE_DIR="${1:?Usage: gate-step7.sh <state_dir>}"
STATE_FILE="${STATE_DIR}/state.yaml"
CONTRACTS_FILE="${CONTRACTS_FILE:-${STATE_DIR}/2_contracts.yaml}"
RESULTS_FILE="${STATE_DIR}/7_gate_results.yaml"

[[ -f "$STATE_FILE" ]] || { echo "error: state.yaml not found at $STATE_FILE" >&2; exit 2; }

module=$(grep '^module:' "$STATE_FILE" | head -1 | sed 's/^module: *//' | tr -d '"')
file=$(grep '^file:' "$STATE_FILE" | head -1 | sed 's/^file: *//' | tr -d '"')
zone_id=$(grep '^zone_id:' "$STATE_FILE" | head -1 | sed 's/^zone_id: *//' | tr -d '"')

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Resolve test commands (env > state.yaml)
spike_cmd="${SPIKE_CMD:-}"
char_cmd="${CHARACTERIZATION_CMD:-}"
if [[ -z "$spike_cmd" ]]; then
    spike_cmd=$(grep -E '^[[:space:]]*spike_tests_cmd:' "$STATE_FILE" 2>/dev/null \
        | head -1 | sed 's/^[[:space:]]*spike_tests_cmd: *//' | tr -d '"' || true)
fi
if [[ -z "$char_cmd" ]]; then
    char_cmd=$(grep -E '^[[:space:]]*characterization_tests_cmd:' "$STATE_FILE" 2>/dev/null \
        | head -1 | sed 's/^[[:space:]]*characterization_tests_cmd: *//' | tr -d '"' || true)
fi

# ── Run helper ───────────────────────────────────────────────────────
# Runs a shell command and captures status into named variables.
#   _run_cmd <label> <cmd>  → sets RUN_STATUS, RUN_LOG_TAIL
_run_cmd() {
    local label="$1"; local cmd="$2"
    local log; log=$(mktemp)
    set +e
    eval "$cmd" >"$log" 2>&1
    local rc=$?
    set -e
    RUN_STATUS=$rc
    # Keep only the last 20 lines of log
    RUN_LOG_TAIL=$(tail -20 "$log" | sed 's/"/\\"/g')
    rm -f "$log"
}

# ── 7.1 Spike tests ──────────────────────────────────────────────────
spike_status="skipped"
spike_detail=""
if [[ -n "$spike_cmd" ]]; then
    echo "▶ Running spike tests: $spike_cmd"
    _run_cmd "spike" "$spike_cmd"
    if [[ "$RUN_STATUS" -eq 0 ]]; then
        spike_status="pass"
    else
        spike_status="fail"
        spike_detail="$RUN_LOG_TAIL"
    fi
else
    echo "⊘ No spike_tests_cmd in state.yaml — spike check skipped"
fi

# ── 7.2 Characterization tests ───────────────────────────────────────
char_status="skipped"
char_detail=""
if [[ -n "$char_cmd" ]]; then
    echo "▶ Running characterization tests: $char_cmd"
    _run_cmd "char" "$char_cmd"
    if [[ "$RUN_STATUS" -eq 0 ]]; then
        char_status="pass"
    else
        char_status="fail"
        char_detail="$RUN_LOG_TAIL"
    fi
else
    echo "⊘ No characterization_tests_cmd in state.yaml — characterization check skipped"
fi

# ── 7.3 Contract CI rules ────────────────────────────────────────────
contracts_total=0
contracts_pass=0
contracts_fail=0
contracts_failures=""

if [[ -f "$CONTRACTS_FILE" ]]; then
    echo "▶ Running contract verification rules from $CONTRACTS_FILE"

    current_id=""
    current_grep=""

    # Parse contracts YAML: rely on two keys appearing per block:
    #   - id: "..."      (or) contract_id: "..."
    #   verification_grep: "grep ..."
    process_contract() {
        [[ -z "$current_grep" ]] && return 0
        local label="${current_id:-(unlabelled)}"
        contracts_total=$((contracts_total + 1))

        if ! echo "$current_grep" | grep -qE '^(grep|ast-grep|rg) '; then
            contracts_fail=$((contracts_fail + 1))
            contracts_failures="${contracts_failures}    - contract: \"$label\"\n      reason: \"PARSE_ERROR — command not grep/ast-grep/rg\"\n"
            return 0
        fi

        set +e
        eval "$current_grep" >/dev/null 2>&1
        local rc=$?
        set -e

        if [[ "$rc" -eq 0 ]]; then
            contracts_pass=$((contracts_pass + 1))
        else
            contracts_fail=$((contracts_fail + 1))
            local esc_grep
            esc_grep=$(echo "$current_grep" | sed 's/"/\\"/g')
            contracts_failures="${contracts_failures}    - contract: \"$label\"\n      reason: \"pattern not matched\"\n      command: \"$esc_grep\"\n"
        fi
    }

    while IFS= read -r line; do
        if echo "$line" | grep -qE '^[[:space:]]*- (id|contract_id):'; then
            process_contract
            current_id=$(echo "$line" | sed -E 's/.*(id|contract_id): *"?([^"]*)"?[[:space:]]*$/\2/')
            current_grep=""
        elif echo "$line" | grep -qE '^[[:space:]]*verification_grep:'; then
            current_grep=$(echo "$line" | sed -E 's/^[[:space:]]*verification_grep: *"?(.*[^"])"?[[:space:]]*$/\1/')
        fi
    done < "$CONTRACTS_FILE"
    # final block
    process_contract
else
    echo "⊘ No contracts file at $CONTRACTS_FILE — contract check skipped"
fi

contracts_status="skipped"
if [[ "$contracts_total" -gt 0 ]]; then
    if [[ "$contracts_fail" -eq 0 ]]; then
        contracts_status="pass"
    else
        contracts_status="fail"
    fi
fi

# ── 7.4 Compile results ──────────────────────────────────────────────
overall="pass"
[[ "$spike_status"     = "fail" ]] && overall="fail"
[[ "$char_status"      = "fail" ]] && overall="fail"
[[ "$contracts_status" = "fail" ]] && overall="fail"

# If ALL checks skipped, the gate is undefined — treat as fail.
if [[ "$spike_status" = "skipped" && "$char_status" = "skipped" && "$contracts_status" = "skipped" ]]; then
    overall="fail"
fi

{
    echo "# Step 7 Gate Results"
    echo "# Generated by gate-step7.sh"
    echo "module: \"$module\""
    [[ -n "$zone_id" ]] && echo "zone_id: \"$zone_id\""
    echo "file: \"$file\""
    echo "timestamp: \"$timestamp\""
    echo "checks:"
    echo "  spike_tests:"
    echo "    status: \"$spike_status\""
    [[ -n "$spike_detail" ]] && echo "    log_tail: \"$spike_detail\""
    echo "  characterization_tests:"
    echo "    status: \"$char_status\""
    [[ -n "$char_detail" ]] && echo "    log_tail: \"$char_detail\""
    echo "  contract_rules:"
    echo "    status: \"$contracts_status\""
    echo "    total: $contracts_total"
    echo "    passed: $contracts_pass"
    echo "    failed: $contracts_fail"
    if [[ -n "$contracts_failures" ]]; then
        echo "    failures:"
        printf "%b" "$contracts_failures"
    fi
    echo "overall: \"$overall\""
} > "$RESULTS_FILE"

# ── 7.5 Update state.yaml ────────────────────────────────────────────
# Replace any existing `7_gate:` line under steps:
sed -i.bak "s|^\([[:space:]]*\)7_gate:.*|\\17_gate: { status: $overall, completed_at: \"$timestamp\" }|" "$STATE_FILE" 2>/dev/null || true
rm -f "${STATE_FILE}.bak"

# If pass, advance current_step to 8
if [[ "$overall" = "pass" ]]; then
    sed -i.bak "s|^current_step:.*|current_step: 8|" "$STATE_FILE" 2>/dev/null || true
    rm -f "${STATE_FILE}.bak"
fi

# ── 7.6 Print summary ────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "Step 7 Gate: $(echo "$overall" | tr '[:lower:]' '[:upper:]')"
echo "  spike_tests:          $spike_status"
echo "  characterization:     $char_status"
echo "  contract_rules:       $contracts_status ($contracts_pass/$contracts_total)"
echo "Results → $RESULTS_FILE"

if [[ "$overall" = "pass" ]]; then
    echo "✅ Safety net is in place. Ready for Step 8."
    exit 0
else
    echo "❌ Gate FAILED — see $RESULTS_FILE for details. Fix and re-run."
    exit 1
fi
