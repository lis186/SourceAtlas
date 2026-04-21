#!/usr/bin/env bash
# gate-platform-migration.sh — Step 7 gate for platform-migration and platform-strangler modes.
#
# Three checks:
#   1. legacy_removed:      Each from_slot in S_strangler_plan.yaml no longer exists
#   2. target_implemented:  Each to_slot in S_strangler_plan.yaml is implemented
#   3. no_double_dispatch:  platform-dispatch-rules.yaml conflict rules pass
#
# Reads deployment target from project (xcconfig / project.pbxproj) to apply
# version-conditional rules correctly (F4: avoids false positives on iOS 12 compat).
#
# Writes results to 7_gate_results.yaml under platform_checks section.
# Exits 0 (all checks pass) or 1 (any check fails).
#
# Usage: gate-platform-migration.sh <state-dir>
set -euo pipefail

STATE_DIR="${1:?Usage: gate-platform-migration.sh <state-dir>}"
PROJECT_ROOT="${2:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"

PLAN="$STATE_DIR/S_strangler_plan.yaml"
DISPATCH_RULES="$(dirname "$0")/../references/platform-dispatch-rules.yaml"
GATE_RESULTS="$STATE_DIR/7_gate_results.yaml"
STATE_FILE="$STATE_DIR/state.yaml"

# ── Detect deployment target ──────────────────────────────────────────────────
DEPLOYMENT_TARGET=""
set +o pipefail
DEPLOYMENT_TARGET=$(grep -r 'IPHONEOS_DEPLOYMENT_TARGET' \
    --include="*.xcconfig" --include="*.pbxproj" "$PROJECT_ROOT" 2>/dev/null \
    | grep -v '/(Pods|DerivedData|Carthage)/' \
    | grep -oE '[0-9]+\.[0-9]+' | sort -V | head -1 || echo "")
set -o pipefail
DEPLOYMENT_TARGET=${DEPLOYMENT_TARGET:-"0.0"}

# ── Check 1 & 2: legacy_removed + target_implemented ─────────────────────────
legacy_total=0; legacy_passed=0; legacy_offenders=()
target_total=0; target_passed=0; target_offenders=()

if [[ -f "$PLAN" ]] && command -v yq &>/dev/null; then
    item_count=$(yq e '.migration_plan | length' "$PLAN" 2>/dev/null || echo 0)
    for i in $(seq 0 $((item_count - 1))); do
        status=$(yq e ".migration_plan[$i].status" "$PLAN")
        from_slot=$(yq e ".migration_plan[$i].from_slot" "$PLAN")
        to_slot=$(yq e ".migration_plan[$i].to_slot" "$PLAN")
        legacy_cmd=$(yq e ".migration_plan[$i].verification.legacy_removed" "$PLAN")
        new_cmd=$(yq e ".migration_plan[$i].verification.new_implemented" "$PLAN")
        zone_id=$(yq e ".migration_plan[$i].zone_id" "$PLAN")

        # legacy_removed check
        if [[ -n "$legacy_cmd" && "$legacy_cmd" != "null" && "$legacy_cmd" != *"<from_slot_pattern>"* ]]; then
            legacy_total=$((legacy_total+1))
            set +e; eval "$legacy_cmd" >/dev/null 2>&1; exit_code=$?; set -e
            if [[ $exit_code -eq 0 ]]; then
                legacy_offenders+=("zone=$zone_id: '$from_slot' still present in legacy file")
            else
                legacy_passed=$((legacy_passed+1))
            fi
        fi

        # target_implemented check
        if [[ -n "$new_cmd" && "$new_cmd" != "null" && "$new_cmd" != *"<to_slot_pattern>"* && -n "$to_slot" && "$to_slot" != "null" ]]; then
            target_total=$((target_total+1))
            set +e; eval "$new_cmd" >/dev/null 2>&1; exit_code=$?; set -e
            if [[ $exit_code -ne 0 ]]; then
                target_offenders+=("zone=$zone_id: '$to_slot' not yet implemented in target file")
            else
                target_passed=$((target_passed+1))
            fi
        fi
    done
fi

legacy_status="pass"; [[ ${#legacy_offenders[@]} -gt 0 ]] && legacy_status="fail"
target_status="pass"; [[ ${#target_offenders[@]} -gt 0 ]] && target_status="fail"

# ── Check 3: no_double_dispatch ───────────────────────────────────────────────
dispatch_total=0; dispatch_passed=0; dispatch_offenders=(); dispatch_info=()

if [[ -f "$DISPATCH_RULES" ]] && command -v yq &>/dev/null; then
    rule_count=$(yq e '.rules | length' "$DISPATCH_RULES" 2>/dev/null || echo 0)
    for i in $(seq 0 $((rule_count - 1))); do
        rule_id=$(yq e ".rules[$i].id" "$DISPATCH_RULES")
        description=$(yq e ".rules[$i].description" "$DISPATCH_RULES")
        legacy_pat=$(yq e ".rules[$i].legacy_pattern" "$DISPATCH_RULES")
        target_pat=$(yq e ".rules[$i].target_pattern" "$DISPATCH_RULES")
        severity=$(yq e ".rules[$i].severity_if_coexist" "$DISPATCH_RULES")
        check_type=$(yq e ".rules[$i].check_type // \"coexist\"" "$DISPATCH_RULES")
        remediation=$(yq e ".rules[$i].remediation" "$DISPATCH_RULES")
        min_ver=$(yq e ".rules[$i].condition.deployment_target_gte // \"0.0\"" "$DISPATCH_RULES")

        # Apply version condition: skip rule if deployment target is below minimum
        if [[ "$min_ver" != "0.0" ]]; then
            ver_major=$(echo "$DEPLOYMENT_TARGET" | cut -d. -f1)
            min_major=$(echo "$min_ver" | cut -d. -f1)
            if [[ "$ver_major" -lt "$min_major" ]]; then
                continue  # deployment target too low — rule doesn't apply
            fi
        fi

        dispatch_total=$((dispatch_total+1))

        set +o pipefail
        legacy_hit=$(grep -rlE "$legacy_pat" --include="*.swift" --include="*.m" \
            --include="*.h" --include="*.kt" --include="*.java" \
            "$PROJECT_ROOT" 2>/dev/null \
            | grep -Ev '/(Pods|build|DerivedData|Carthage|SourcePackages)/' \
            | head -1 || echo "")
        target_hit=$(grep -rlE "$target_pat" --include="*.swift" --include="*.m" \
            --include="*.h" --include="*.kt" --include="*.java" --include="Info.plist" \
            "$PROJECT_ROOT" 2>/dev/null \
            | grep -Ev '/(Pods|build|DerivedData|Carthage|SourcePackages)/' \
            | head -1 || echo "")
        set -o pipefail

        if [[ "$check_type" = "target_must_exist" ]]; then
            # Special: fire when target_pattern is ABSENT
            if [[ -n "$legacy_hit" && -z "$target_hit" ]]; then
                dispatch_offenders+=("[$rule_id] $description | Remediation: $remediation")
            else
                dispatch_passed=$((dispatch_passed+1))
            fi
        else
            # Standard coexist check
            if [[ -n "$legacy_hit" && -n "$target_hit" ]]; then
                if [[ "$severity" = "fail" ]]; then
                    dispatch_offenders+=("[$rule_id] $description | Remediation: $remediation")
                else
                    dispatch_info+=("[$rule_id] $description (info — expected during iOS 12 compat)")
                    dispatch_passed=$((dispatch_passed+1))
                fi
            else
                dispatch_passed=$((dispatch_passed+1))
            fi
        fi
    done
fi

dispatch_status="pass"; [[ ${#dispatch_offenders[@]} -gt 0 ]] && dispatch_status="fail"

# ── Overall ───────────────────────────────────────────────────────────────────
overall="pass"
[[ "$legacy_status" = "fail" || "$target_status" = "fail" || "$dispatch_status" = "fail" ]] && overall="fail"

# ── Write 7_gate_results.yaml ─────────────────────────────────────────────────
cat >> "$GATE_RESULTS" <<YAML

platform_checks:
  deployment_target_detected: "$DEPLOYMENT_TARGET"
  legacy_removed:
    status: "$legacy_status"
    total: $legacy_total
    passed: $legacy_passed
    offenders:
YAML
for o in "${legacy_offenders[@]:-}"; do
    [[ -z "$o" ]] && continue; echo "      - \"$o\"" >> "$GATE_RESULTS"
done
[[ ${#legacy_offenders[@]} -eq 0 ]] && echo "      []" >> "$GATE_RESULTS"

cat >> "$GATE_RESULTS" <<YAML
  target_implemented:
    status: "$target_status"
    total: $target_total
    passed: $target_passed
    offenders:
YAML
for o in "${target_offenders[@]:-}"; do
    [[ -z "$o" ]] && continue; echo "      - \"$o\"" >> "$GATE_RESULTS"
done
[[ ${#target_offenders[@]} -eq 0 ]] && echo "      []" >> "$GATE_RESULTS"

cat >> "$GATE_RESULTS" <<YAML
  no_double_dispatch:
    status: "$dispatch_status"
    total: $dispatch_total
    passed: $dispatch_passed
    offenders:
YAML
for o in "${dispatch_offenders[@]:-}"; do
    [[ -z "$o" ]] && continue; echo "      - \"$o\"" >> "$GATE_RESULTS"
done
[[ ${#dispatch_offenders[@]} -eq 0 ]] && echo "      []" >> "$GATE_RESULTS"

cat >> "$GATE_RESULTS" <<YAML
    info:
YAML
for o in "${dispatch_info[@]:-}"; do
    [[ -z "$o" ]] && continue; echo "      - \"$o\"" >> "$GATE_RESULTS"
done
[[ ${#dispatch_info[@]} -eq 0 ]] && echo "      []" >> "$GATE_RESULTS"

cat >> "$GATE_RESULTS" <<YAML
  overall: "$overall"
YAML

echo "Platform migration gate: legacy=$legacy_status target=$target_status dispatch=$dispatch_status → $overall"

if [[ "$overall" = "fail" ]]; then
    echo ""
    echo "Failures:"
    for o in "${legacy_offenders[@]:-}" "${target_offenders[@]:-}" "${dispatch_offenders[@]:-}"; do
        [[ -z "$o" ]] && continue; echo "  - $o"
    done
    exit 1
fi
exit 0
