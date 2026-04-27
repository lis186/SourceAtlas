#!/usr/bin/env bash
# gate-strangler.sh — Verify a S_strangler_plan.yaml entry-by-entry.
#
# For each item in the plan:
#   1. Run verification.legacy_removed  (should exit 1 = pattern NOT found)
#   2. Run verification.new_implemented (should exit 0 = pattern found)
#   3. Update item status: done | pending | failed
#
# Writes results to 7_gate_results.yaml under platform_checks.strangler section.
# Exits 0 if all items are "done", 1 if any remain "failed" or "pending".
#
# Usage: gate-strangler.sh <state-dir> [--zone <zone-id>]
set -euo pipefail

STATE_DIR="${1:?Usage: gate-strangler.sh <state-dir>}"
ZONE_FILTER=""
[[ "${2:-}" = "--zone" ]] && ZONE_FILTER="${3:-}"

PLAN="$STATE_DIR/S_strangler_plan.yaml"
GATE_RESULTS="$STATE_DIR/7_gate_results.yaml"

if [[ ! -f "$PLAN" ]]; then
    echo "❌ S_strangler_plan.yaml not found: $PLAN"
    echo "   Run: /atlas.refactor <file> --step 2 to generate the plan."
    exit 1
fi

# yq is preferred; awk fallback handles read-only parsing when yq is unavailable.
# Status write-back requires yq — without it, items remain "pending" in the plan
# and will be re-checked on every run (correctness preserved, slightly slower).
HAS_YQ=0
if command -v yq &>/dev/null; then
    HAS_YQ=1
fi

# Item parser: emits one record per item to stdout in TSV format:
#   zone_id<TAB>status<TAB>from_slot<TAB>to_slot<TAB>legacy_cmd<TAB>new_cmd
parse_items() {
    if [[ "$HAS_YQ" -eq 1 ]]; then
        local n=$(yq e '.migration_plan | length' "$PLAN" 2>/dev/null || echo 0)
        local i
        for i in $(seq 0 $((n - 1))); do
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$(yq e ".migration_plan[$i].zone_id" "$PLAN")" \
                "$(yq e ".migration_plan[$i].status" "$PLAN")" \
                "$(yq e ".migration_plan[$i].from_slot" "$PLAN")" \
                "$(yq e ".migration_plan[$i].to_slot" "$PLAN")" \
                "$(yq e ".migration_plan[$i].verification.legacy_removed" "$PLAN")" \
                "$(yq e ".migration_plan[$i].verification.new_implemented" "$PLAN")"
        done
    else
        # awk fallback: parse migration_plan list-of-mappings
        awk '
            /^migration_plan:/ { in_plan = 1; next }
            in_plan && /^[a-zA-Z]/ { in_plan = 0 }
            in_plan && /^[[:space:]]*-[[:space:]]+zone_id:/ {
                if (have) {
                    printf "%s\t%s\t%s\t%s\t%s\t%s\n", zone, status, from, to, lcmd, ncmd
                }
                have = 1; zone=""; status=""; from=""; to=""; lcmd=""; ncmd=""; in_verif = 0
                line = $0
                sub(/.*zone_id:[[:space:]]*"?/, "", line); sub(/"?[[:space:]]*$/, "", line)
                zone = line
                next
            }
            in_plan && have {
                line = $0
                sub(/^[[:space:]]+/, "", line)
                if (line ~ /^verification:/) { in_verif = 1; next }
                if (line ~ /^[a-z]/ && line !~ /^legacy_removed:|^new_implemented:/) in_verif = 0
                if (line ~ /^status:/)    { v=line; sub(/^status:[[:space:]]*"?/, "", v);    sub(/"?[[:space:]]*$/, "", v); status = v }
                if (line ~ /^from_slot:/) { v=line; sub(/^from_slot:[[:space:]]*"?/, "", v); sub(/"?[[:space:]]*$/, "", v); from = v }
                if (line ~ /^to_slot:/)   { v=line; sub(/^to_slot:[[:space:]]*"?/, "", v);   sub(/"?[[:space:]]*$/, "", v); to = v }
                if (in_verif && line ~ /^legacy_removed:/)  { v=line; sub(/^legacy_removed:[[:space:]]*"?/, "", v);  sub(/"?[[:space:]]*$/, "", v); lcmd = v }
                if (in_verif && line ~ /^new_implemented:/) { v=line; sub(/^new_implemented:[[:space:]]*"?/, "", v); sub(/"?[[:space:]]*$/, "", v); ncmd = v }
            }
            END {
                if (have) printf "%s\t%s\t%s\t%s\t%s\t%s\n", zone, status, from, to, lcmd, ncmd
            }
        ' "$PLAN"
    fi
}

if [[ "$HAS_YQ" -eq 0 ]]; then
    echo "warning: yq not found — using awk fallback. Status write-back is disabled (passing items will be re-checked on next run). Install yq for full functionality: brew install yq (macOS) | apt install yq (Linux)" >&2
fi

total=0
passed=0
failed=0
offenders=()
item_idx=-1

while IFS=$'\t' read -r zone_id status from_slot to_slot legacy_cmd new_cmd; do
    item_idx=$((item_idx+1))
    [[ -z "$zone_id" ]] && continue
    [[ -n "$ZONE_FILTER" && "$zone_id" != "$ZONE_FILTER" ]] && continue

    [[ "$status" = "done" ]] && { total=$((total+1)); passed=$((passed+1)); continue; }
    total=$((total+1))

    item_failed=0

    # legacy_removed: command should FAIL (grep returns 1 = not found = removed)
    if [[ -n "$legacy_cmd" && "$legacy_cmd" != "null" ]]; then
        set +e
        eval "$legacy_cmd" >/dev/null 2>&1
        legacy_exit=$?
        set -e
        if [[ $legacy_exit -eq 0 ]]; then
            # Pattern still found → legacy NOT removed yet
            offenders+=("zone=$zone_id from_slot='$from_slot': legacy still present")
            item_failed=1
        fi
    fi

    # new_implemented: command should SUCCEED (grep returns 0 = found = implemented)
    if [[ -n "$new_cmd" && "$new_cmd" != "null" ]]; then
        set +e
        eval "$new_cmd" >/dev/null 2>&1
        new_exit=$?
        set -e
        if [[ $new_exit -ne 0 ]]; then
            offenders+=("zone=$zone_id to_slot='$to_slot': new implementation not found")
            item_failed=1
        fi
    fi

    if [[ $item_failed -eq 0 ]]; then
        passed=$((passed+1))
        # Update status in plan (yq-only — awk fallback skips write-back)
        if [[ "$HAS_YQ" -eq 1 ]]; then
            yq e -i ".migration_plan[$item_idx].status = \"done\"" "$PLAN" 2>/dev/null || true
        fi
    else
        failed=$((failed+1))
    fi
done < <(parse_items)

overall="pass"
[[ $failed -gt 0 ]] && overall="fail"

# Write to 7_gate_results.yaml (merge into existing or create)
cat >> "$GATE_RESULTS" <<YAML

strangler_gate:
  total: $total
  passed: $passed
  failed: $failed
  overall: "$overall"
  offenders:
YAML
for o in "${offenders[@]:-}"; do
    [[ -z "$o" ]] && continue
    echo "    - \"$o\"" >> "$GATE_RESULTS"
done
[[ ${#offenders[@]} -eq 0 ]] && echo "    []" >> "$GATE_RESULTS"

echo "Strangler gate: $passed/$total passed (${overall})"

if [[ "$overall" = "fail" ]]; then
    echo ""
    echo "Failures:"
    for o in "${offenders[@]:-}"; do
        [[ -z "$o" ]] && continue
        echo "  - $o"
    done
    exit 1
fi

exit 0
