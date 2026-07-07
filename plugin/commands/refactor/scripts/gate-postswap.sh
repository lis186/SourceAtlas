#!/usr/bin/env bash
# gate-postswap.sh — deterministic Done-When checks for Playbook Steps 8, 12, 13.
#
# Turns the grep-checkable signals from SKILL.md's Steps 8-13 tables into exit
# codes, so "cleanup complete" is a gate, not a claim. Steps 9-11 are verified
# by test suites (re-run gate-step7.sh / your full suite) — not this script.
#
# Usage:
#   gate-postswap.sh --module <m> --step 8  --impl-file <path>
#   gate-postswap.sh --module <m> --step 12 [--adapter-name <N>] [--seam-name <N>] [--skip-seam-check]
#   gate-postswap.sh --module <m> --step 13
#
# Name resolution (when flags omitted):
#   legacy class  = basename of 1_target.yaml `file:` without extension
#   adapter name  = first class/struct/@interface identifier in 6_adapter.* artifact
#   seam name     = 5_interface.yaml protocol.name
#   shadow logger = 5_interface.yaml shadow_config.logger_protocol (shadow strategy only)
#
# Exit codes: 0 pass · 1 usage · 2 state/artifact missing · 3 gate failed
set -uo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

MODULE="" STEP="" IMPL_FILE="" ADAPTER_NAME="" SEAM_NAME="" SKIP_SEAM=0

usage() {
    grep '^# ' "$0" | sed 's/^# //' >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --module)          MODULE="$2";       shift 2 ;;
        --step)            STEP="$2";         shift 2 ;;
        --impl-file)       IMPL_FILE="$2";    shift 2 ;;
        --adapter-name)    ADAPTER_NAME="$2"; shift 2 ;;
        --seam-name)       SEAM_NAME="$2";    shift 2 ;;
        --skip-seam-check) SKIP_SEAM=1;       shift ;;
        *) echo "error: unknown flag: $1" >&2; usage ;;
    esac
done

[[ -n "$MODULE" && -n "$STEP" ]] || usage

state_dir="$PROJECT_ROOT/.sourceatlas/refactor/$MODULE"
target_yaml="$state_dir/1_target.yaml"
interface_yaml="$state_dir/5_interface.yaml"
[[ -d "$state_dir" ]] || { echo "error: no state dir at $state_dir" >&2; exit 2; }

# Search excludes: vendored/build dirs plus the playbook's own artifacts,
# which legitimately mention every name we grep for.
GREP_EXCLUDES=(--exclude-dir=.git --exclude-dir=.sourceatlas --exclude-dir=Pods
               --exclude-dir=node_modules --exclude-dir=build --exclude-dir=.build
               --exclude-dir=DerivedData --exclude-dir=Carthage --exclude-dir=vendor)

ref_count() {  # ref_count <name> → number of referencing lines in the project
    grep -rn "${GREP_EXCLUDES[@]}" -- "$1" "$PROJECT_ROOT" 2>/dev/null | wc -l | tr -d ' '
}

yaml_value() {  # yaml_value <file> <key> → first "key: value", quotes stripped
    awk -v key="$2" '$0 ~ "^[[:space:]]*" key ":" {
        sub("^[[:space:]]*" key ":[[:space:]]*", ""); gsub(/["'"'"']/, ""); print; exit
    }' "$1"
}

legacy_rel=$(yaml_value "$target_yaml" "file")
[[ -n "$legacy_rel" ]] || { echo "error: cannot read file: from $target_yaml" >&2; exit 2; }
legacy_file="$PROJECT_ROOT/$legacy_rel"
legacy_class=$(basename "$legacy_rel"); legacy_class="${legacy_class%.*}"

# Group C (dynamic) module names are often common words ("response", "utils")
# that appear everywhere as plain English or platform identifiers
# (http.ServerResponse). For those languages the meaningful signal is a
# module-path reference (require/import of the legacy file), not the bare word.
TARGET_LANG=$(yaml_value "$target_yaml" "language")
module_ref_pattern() {  # regex matching require('./<mod>') / from '.../<mod>.js'
    printf '%s' "(require\(|from[[:space:]]).*['\"][^'\"]*/${legacy_class}(\.[a-z]+)?['\"]"
}
is_dynamic_lang() {
    case "$TARGET_LANG" in javascript|typescript|python|ruby) return 0 ;; *) return 1 ;; esac
}
module_ref_count() {  # project-wide count of legacy module-path references
    grep -rnE "${GREP_EXCLUDES[@]}" -- "$(module_ref_pattern)" "$PROJECT_ROOT" 2>/dev/null | wc -l | tr -d ' '
}

pass=0; fail=0
check() {  # check <label> <ok:0|1> <detail>
    if [[ "$2" -eq 0 ]]; then echo "  ✅ $1 — $3"; pass=$((pass+1))
    else echo "  ❌ $1 — $3"; fail=$((fail+1)); fi
}

echo "gate-postswap: step $STEP · module $MODULE"
echo "  legacy: $legacy_rel (class: $legacy_class)"

case "$STEP" in
    8)
        [[ -n "$IMPL_FILE" ]] || { echo "error: --step 8 requires --impl-file" >&2; exit 1; }
        [[ -f "$IMPL_FILE" ]]; check "impl_file_exists" $? "$IMPL_FILE"
        if [[ -f "$IMPL_FILE" ]]; then
            if is_dynamic_lang; then
                hits=$(grep -cE -- "$(module_ref_pattern)" "$IMPL_FILE" 2>/dev/null || true); hits=${hits:-0}
                [[ "$hits" -eq 0 ]]; check "no_legacy_module_import_in_impl" $? "require/import of '$legacy_class' → $hits hits (need 0)"
            else
                hits=$(grep -c -- "$legacy_class" "$IMPL_FILE" 2>/dev/null); hits=${hits:-0}
                [[ "$hits" -eq 0 ]]; check "no_legacy_refs_in_impl" $? "grep '$legacy_class' → $hits hits (need 0)"
            fi
        fi
        echo "  ℹ compile + unit tests are your gate too — this script only checks the grep signals"
        ;;

    12)
        adapter_artifact=""
        if [[ -z "$ADAPTER_NAME" ]]; then
            adapter_artifact=$(ls "$state_dir"/6_adapter.* 2>/dev/null | grep -v '\.patch$' | head -1)
            # Anchored to line start so prose like "No adapter class exists"
            # in comments cannot be mistaken for a declaration.
            [[ -n "$adapter_artifact" ]] && ADAPTER_NAME=$(grep -oE '^[[:space:]]*(@interface|class|struct)[[:space:]]+[A-Za-z0-9_]+' "$adapter_artifact" | head -1 | awk '{print $NF}')
        fi
        if [[ -z "$ADAPTER_NAME" ]] && is_dynamic_lang; then
            # Group C: no adapter class by design — 6_adapter.* is test-side
            # mock setup. Done signal: production code never references it.
            base=$(basename "${adapter_artifact:-6_adapter}"); base="${base%.*}"
            hits=$(ref_count "$base")
            [[ "$hits" -eq 0 ]]; check "no_adapter_artifact_refs" $? "grep -r '$base' → $hits hits (need 0; Group C has no adapter class)"
        else
            [[ -n "$ADAPTER_NAME" ]] || { echo "error: cannot derive adapter name — pass --adapter-name" >&2; exit 2; }
            hits=$(ref_count "$ADAPTER_NAME")
            [[ "$hits" -eq 0 ]]; check "adapter_deleted" $? "grep -r '$ADAPTER_NAME' → $hits hits (need 0)"
        fi

        if [[ "$SKIP_SEAM" -eq 0 ]]; then
            [[ -z "$SEAM_NAME" && -f "$interface_yaml" ]] && SEAM_NAME=$(yaml_value "$interface_yaml" "name")
            if [[ -n "$SEAM_NAME" ]]; then
                hits=$(ref_count "$SEAM_NAME")
                [[ "$hits" -eq 0 ]]; check "seam_interface_renamed" $? "grep -r '$SEAM_NAME' → $hits hits (need 0; --skip-seam-check if final name kept)"
            fi
        fi

        if [[ -f "$interface_yaml" ]] && [[ "$(yaml_value "$interface_yaml" "swap_strategy")" == "shadow" ]]; then
            logger=$(yaml_value "$interface_yaml" "logger_protocol")
            if [[ -n "$logger" ]]; then
                hits=$(ref_count "$logger")
                [[ "$hits" -eq 0 ]]; check "shadow_logger_deleted" $? "grep -r '$logger' → $hits hits (need 0)"
            fi
        fi
        ;;

    13)
        [[ ! -f "$legacy_file" ]]; check "legacy_file_deleted" $? "$legacy_rel"
        if is_dynamic_lang; then
            hits=$(module_ref_count)
            [[ "$hits" -eq 0 ]]; check "no_legacy_module_refs" $? "require/import of '$legacy_class' → $hits hits (need 0)"
        else
            hits=$(ref_count "$legacy_class")
            [[ "$hits" -eq 0 ]]; check "no_legacy_class_refs" $? "grep -r '$legacy_class' → $hits hits (need 0)"
        fi
        ;;

    *)
        echo "error: --step must be 8, 12 or 13 (9-11 are test-suite gates)" >&2
        exit 1
        ;;
esac

echo "gate-postswap: $pass passed, $fail failed"
if [[ "$fail" -eq 0 ]]; then
    key=$(case "$STEP" in 8) echo 8_new_impl;; 12) echo 12_cleanup;; 13) echo 13_delete_legacy;; esac)
    echo "PASS — promote with: state.sh set-status --module $MODULE --step $key --status verified"
    exit 0
else
    echo "FAIL — fix the ❌ items above, then re-run"
    exit 3
fi
