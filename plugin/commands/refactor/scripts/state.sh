#!/usr/bin/env bash
# state.sh — sole write API for .sourceatlas/refactor/{module}/state.yaml.
#
# All state.yaml mutations MUST go through this script. Direct Edit/Write of
# state.yaml is forbidden by SKILL.md Critical Rule 15 — this script is the
# enforcement point that makes the rule observable (it refuses bad state).
#
# Subcommands:
#   advance     --module <m> [--to <step>]      Advance current_step + mark step verified
#   set-zone    --module <m> --zone <id>        Set zone_id (requires 2a_zones.yaml)
#   confirm-mode --module <m>                   Set migration_mode.confirmed=true
#   set-status  --module <m> --step <key> --status <produced|verified|skipped> [--skip-reason <txt>] [--audit-mode <full|subagent>]
#   show        --module <m>                    Print current state summary
#
# Exit codes:
#   0  success
#   1  usage error
#   2  state.yaml not found
#   3  precondition failed (e.g. previous step not verified)
#   4  invalid argument value
#
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

usage() {
    cat >&2 <<'EOF'
Usage: state.sh <subcommand> --module <module-name> [args]

  advance     [--to <step>]                Advance to next step (default: current+1)
  set-zone    --zone <id>                  Set zone_id from 2a_zones.yaml
  confirm-mode                             Set migration_mode.confirmed=true
  set-status  --step <key> --status <s> [--skip-reason <txt>]
  show
EOF
    exit 1
}

[[ $# -ge 1 ]] || usage
SUBCMD="$1"; shift

MODULE=""
TO_STEP=""
ZONE_ID=""
STEP_KEY=""
STATUS=""
SKIP_REASON=""
AUDIT_MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --module)      MODULE="$2";      shift 2 ;;
        --to)          TO_STEP="$2";     shift 2 ;;
        --zone)        ZONE_ID="$2";     shift 2 ;;
        --step)        STEP_KEY="$2";    shift 2 ;;
        --status)      STATUS="$2";      shift 2 ;;
        --skip-reason) SKIP_REASON="$2"; shift 2 ;;
        --audit-mode)  AUDIT_MODE="$2";  shift 2 ;;
        *) echo "error: unknown flag: $1" >&2; usage ;;
    esac
done

[[ -n "$MODULE" ]] || { echo "error: --module required" >&2; usage; }

state_dir="$PROJECT_ROOT/.sourceatlas/refactor/$MODULE"
state_file="$state_dir/state.yaml"

[[ -f "$state_file" ]] || { echo "error: state.yaml not found at $state_file" >&2; exit 2; }

iso_now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Read a top-level scalar from state.yaml (no nesting).
get_scalar() {
    awk -v key="$1" '
        $0 ~ "^" key ":" {
            sub("^" key ":[[:space:]]*", "")
            sub("[[:space:]]*$", "")
            gsub("\"", "")
            print
            exit
        }
    ' "$state_file"
}

# Rewrite a single top-level scalar key in place.
set_scalar() {
    local key="$1" value="$2"
    local tmp="$state_file.tmp"
    awk -v key="$key" -v value="$value" '
        BEGIN { done = 0 }
        $0 ~ "^" key ":" && !done {
            print key ": " value
            done = 1
            next
        }
        { print }
    ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
}

# Rewrite a step entry status (steps are inline-flow style).
# Example: "  1_target:    { status: pending, completed_at: null }"
set_step_status() {
    local step="$1" new_status="$2" reason="$3"
    local tmp="$state_file.tmp"
    awk -v step="$step" -v st="$new_status" -v reason="$reason" -v now="$iso_now" '
        $0 ~ "^[[:space:]]+" step ":[[:space:]]*\\{" {
            line = $0
            sub(/status:[[:space:]]*[a-z]+/, "status: " st, line)
            sub(/completed_at:[[:space:]]*[^,}]+/, "completed_at: \"" now "\"", line)
            if (reason != "") {
                if (match(line, /skip_reason:[[:space:]]*[^,}]+/)) {
                    sub(/skip_reason:[[:space:]]*[^,}]+/, "skip_reason: \"" reason "\"", line)
                }
            }
            print line
            next
        }
        { print }
    ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
}

# Map step number → step key for advance lookup.
step_key_for_num() {
    case "$1" in
        1)   echo "1_target" ;;
        2)   echo "2_contracts" ;;
        2a)  echo "2a_zones" ;;
        3)   echo "3_seams" ;;
        4)   echo "4_tests" ;;
        5)   echo "5_interface" ;;
        6)   echo "6_adapter" ;;
        7)   echo "7_gate" ;;
        8)   echo "8_new_impl" ;;
        9|9a|9b|9c) echo "9_swap" ;;   # shadow sub-phases share one state entry
        10)  echo "10_verification" ;;
        11)  echo "11_integration" ;;
        12)  echo "12_cleanup" ;;
        13)  echo "13_delete_legacy" ;;
        *)   echo "" ;;
    esac
}

# Read dispatch value for a given (step_key, mode) from mode-dispatch.yaml.
# Returns one of: applies | skip | replaced | "" (unknown).
# The dispatch YAML uses "S"-prefixed keys (S1_target) while state uses
# unprefixed (1_target); we add "S" inside the lookup.
SCRIPT_DIR_FOR_DISPATCH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH_FILE="$SCRIPT_DIR_FOR_DISPATCH/../references/mode-dispatch.yaml"

dispatch_for() {
    local step_key="$1" mode="$2"
    [[ -f "$DISPATCH_FILE" ]] || { echo ""; return; }
    awk -v step="S${step_key}" -v mode="$mode" '
        # Step header: "  S1_target:" (indented under "steps:")
        $0 ~ "^[[:space:]]+" step ":[[:space:]]*$" { in_step = 1; next }
        # Next sibling step at same indent level → exit current step block
        in_step && /^[[:space:]]+S[0-9]/ { in_step = 0; in_mode = 0 }
        in_step {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            # Mode scalar: "seam-injection: applies"
            # Mode mapping: "platform-migration:" then nested "dispatch: replaced"
            if (line ~ "^" mode ":") {
                rest = line
                sub("^" mode ":[[:space:]]*", "", rest)
                if (rest != "") { print rest; exit }
                in_mode = 1; next
            }
            if (in_mode) {
                if (line ~ /^dispatch:/) {
                    sub(/^dispatch:[[:space:]]*/, "", line)
                    gsub(/"/, "", line)
                    print line
                    exit
                }
                # Exit mode mapping if we hit another mode key (top of next mapping)
                if (line ~ /^[a-z]/ && line !~ /^dispatch:|^skip_reason:|^replacement_script:|^note:/) {
                    in_mode = 0
                }
            }
        }
    ' "$DISPATCH_FILE"
}

case "$SUBCMD" in
    show)
        cat <<EOF
$(get_scalar module) — current_step: $(get_scalar current_step)
  zone_id:       $(get_scalar zone_id)
  language:      $(get_scalar language)
EOF
        grep -E '^\s+(1_target|2a_zones|2_contracts|3_seams|4_tests|5_interface|6_adapter|7_gate|8_new_impl|9_swap|10_verification|11_integration|12_cleanup|13_delete_legacy):' "$state_file" \
            | sed 's/^[[:space:]]*/  /'
        ;;

    advance)
        current=$(get_scalar current_step)
        if [[ "$current" == "13" ]]; then
            echo "error: already at final step 13 — playbook complete. Promote via: state.sh set-status --module $MODULE --step 13_delete_legacy --status verified" >&2
            exit 3
        fi
        target_step="${TO_STEP:-$((current + 1))}"
        prev_key=$(step_key_for_num "$current")
        [[ -n "$prev_key" ]] || { echo "error: cannot map current_step=$current" >&2; exit 4; }

        prev_line=$(grep -E "^[[:space:]]+${prev_key}:" "$state_file" || true)
        if [[ -z "$prev_line" ]]; then
            echo "error: cannot advance — step '$prev_key' not found in state.yaml" >&2
            exit 4
        fi
        prev_status=$(echo "$prev_line" | sed -E 's/.*status: *([a-z]+).*/\1/')
        if [[ "$prev_status" != "produced" && "$prev_status" != "verified" && "$prev_status" != "skipped" ]]; then
            echo "error: cannot advance — $prev_key.status=$prev_status (need produced|verified|skipped)" >&2
            exit 3
        fi

        # Critical Rule 17: dispatch ↔ status consistency check.
        # mode-dispatch.yaml is the source of truth for which steps apply per mode.
        # If a step's dispatch is "skip" but status isn't "skipped", the LLM bypassed
        # the dispatch rule (e.g. ran /atlas.seam in platform-migration where S3=skip).
        mode=$(awk '/^[[:space:]]+mode_name:/ {print $2; exit}' "$state_file" | tr -d '"')
        if [[ -n "$mode" ]]; then
            disp=$(dispatch_for "$prev_key" "$mode")
            case "$disp" in
                skip)
                    if [[ "$prev_status" != "skipped" ]]; then
                        echo "error: dispatch mismatch — $prev_key for mode '$mode' is dispatch=skip but status=$prev_status." >&2
                        echo "       Run: state.sh set-status --module $MODULE --step $prev_key --status skipped --skip-reason '<reason>'" >&2
                        exit 3
                    fi
                    ;;
                replaced)
                    # Replaced steps still produce/verify their own artifact via the replacement_script.
                    # Accept produced/verified; reject skipped (LLM should run replacement, not skip).
                    if [[ "$prev_status" == "skipped" ]]; then
                        echo "error: dispatch mismatch — $prev_key for mode '$mode' is dispatch=replaced (run replacement_script) but status=skipped." >&2
                        exit 3
                    fi
                    ;;
                applies|"")
                    # Normal path or unknown step (e.g. composite gates) — allow produced/verified/skipped.
                    ;;
                *)
                    echo "error: unknown dispatch value '$disp' for $prev_key + $mode in mode-dispatch.yaml" >&2
                    exit 4
                    ;;
            esac
        fi

        # Step-specific artifact validation before advancing.
        # Step 5 (interface design) → require swap_strategy ∈ {direct, shadow}.
        # This is the user-decision lock per Critical Rule 16: state.sh refuses
        # to advance past Step 5 if swap_strategy is null/missing/invalid.
        if [[ "$current" == "5" ]]; then
            interface_file="$state_dir/5_interface.yaml"
            if [[ ! -f "$interface_file" ]]; then
                echo "error: cannot advance — 5_interface.yaml missing at $interface_file" >&2
                exit 3
            fi
            swap=$(awk '/^swap_strategy:/ {print $2; exit}' "$interface_file" | tr -d '"' | tr -d "'")
            case "$swap" in
                direct|shadow) ;;
                *) echo "error: cannot advance — 5_interface.yaml.swap_strategy must be 'direct' or 'shadow' (got: '$swap'). User must confirm per workflow.md §5.5b before Step 6." >&2
                   exit 3 ;;
            esac
        fi

        # Promote prev step from produced → verified (if it has a gate, gate runner promotes; otherwise auto)
        final_status="$prev_status"
        if [[ "$prev_status" == "produced" ]]; then
            set_step_status "$prev_key" "verified" ""
            final_status="verified"
        fi

        set_scalar current_step "$target_step"
        set_scalar updated "\"$iso_now\""
        echo "advanced: $prev_key $final_status → current_step=$target_step"
        ;;

    set-zone)
        [[ -n "$ZONE_ID" ]] || { echo "error: --zone required" >&2; usage; }
        zones_file="$state_dir/2a_zones.yaml"
        [[ -f "$zones_file" ]] || { echo "error: 2a_zones.yaml not found — run init-step2a.sh first" >&2; exit 3; }

        if ! grep -qE "^[[:space:]]+- id: \"${ZONE_ID}\"" "$zones_file"; then
            echo "error: zone '$ZONE_ID' not found in 2a_zones.yaml" >&2
            exit 4
        fi

        set_scalar zone_id "\"$ZONE_ID\""
        set_scalar updated "\"$iso_now\""
        echo "zone_id set: $ZONE_ID"
        ;;

    confirm-mode)
        # Find migration_mode.confirmed and flip to true; record confirmed_at.
        tmp="$state_file.tmp"
        awk -v now="$iso_now" '
            BEGIN { in_mm = 0 }
            /^migration_mode:/ { in_mm = 1; print; next }
            in_mm && /^[a-zA-Z]/ { in_mm = 0 }
            in_mm && /^[[:space:]]+confirmed:/ {
                sub(/confirmed:.*/, "confirmed: true")
            }
            in_mm && /^[[:space:]]+confirmed_at:/ {
                sub(/confirmed_at:.*/, "confirmed_at: \"" now "\"")
            }
            { print }
        ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"

        set_scalar updated "\"$iso_now\""
        echo "migration_mode.confirmed = true"
        ;;

    set-status)
        [[ -n "$STEP_KEY" && -n "$STATUS" ]] || { echo "error: --step and --status required" >&2; usage; }
        case "$STATUS" in
            produced|verified|skipped) ;;
            *) echo "error: --status must be one of produced|verified|skipped" >&2; exit 4 ;;
        esac
        set_step_status "$STEP_KEY" "$STATUS" "$SKIP_REASON"
        if [[ -n "$AUDIT_MODE" ]]; then
            case "$AUDIT_MODE" in
                full|subagent) ;;
                *) echo "error: --audit-mode must be full|subagent" >&2; exit 4 ;;
            esac
            tmp="$state_file.tmp"
            awk -v step="$STEP_KEY" -v am="$AUDIT_MODE" '
                $0 ~ "^[[:space:]]+" step ":[[:space:]]*\\{" {
                    sub(/audit_mode:[[:space:]]*[^,}]+/, "audit_mode: " am)
                }
                { print }
            ' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
            echo "$STEP_KEY.audit_mode = $AUDIT_MODE"
        fi
        set_scalar updated "\"$iso_now\""
        echo "$STEP_KEY.status = $STATUS"
        ;;

    *)
        echo "error: unknown subcommand: $SUBCMD" >&2
        usage
        ;;
esac
