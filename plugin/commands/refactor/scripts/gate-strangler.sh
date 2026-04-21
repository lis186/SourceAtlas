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

if ! command -v yq &>/dev/null; then
    echo "❌ yq is required for gate-strangler.sh"
    echo "   Install: brew install yq"
    exit 1
fi

total=0
passed=0
failed=0
offenders=()

item_count=$(yq e '.migration_plan | length' "$PLAN" 2>/dev/null || echo 0)

for i in $(seq 0 $((item_count - 1))); do
    zone_id=$(yq e ".migration_plan[$i].zone_id" "$PLAN")
    [[ -n "$ZONE_FILTER" && "$zone_id" != "$ZONE_FILTER" ]] && continue

    status=$(yq e ".migration_plan[$i].status" "$PLAN")
    [[ "$status" = "done" ]] && { total=$((total+1)); passed=$((passed+1)); continue; }

    from_slot=$(yq e ".migration_plan[$i].from_slot" "$PLAN")
    to_slot=$(yq e ".migration_plan[$i].to_slot" "$PLAN")
    legacy_cmd=$(yq e ".migration_plan[$i].verification.legacy_removed" "$PLAN")
    new_cmd=$(yq e ".migration_plan[$i].verification.new_implemented" "$PLAN")
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
        # Update status in plan
        yq e -i ".migration_plan[$i].status = \"done\"" "$PLAN" 2>/dev/null || true
    else
        failed=$((failed+1))
    fi
done

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
