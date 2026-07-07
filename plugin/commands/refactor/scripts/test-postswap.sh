#!/usr/bin/env bash
# test-postswap.sh — self-check for the Steps 8-13 state extension + gate-postswap.sh.
# Runs against a throwaway fixture project in mktemp; no network, no side effects.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T=$(mktemp -d "${TMPDIR:-/tmp}/postswap-test.XXXXXX")
trap 'rm -rf "$T"' EXIT
export PROJECT_ROOT="$T"

S() { bash "$SCRIPT_DIR/state.sh" "$@"; }
G() { bash "$SCRIPT_DIR/gate-postswap.sh" "$@"; }

fail=0
expect() { # expect <label> <want_exit> <got_exit>
    if [[ "$2" -eq "$3" ]]; then echo "ok  $1"
    else echo "FAIL $1 (want exit $2, got $3)"; fail=1; fi
}

# ── Fixture ─────────────────────────────────────────────────────────────────
mkdir -p "$T/.sourceatlas/refactor/legacy" "$T/src"
cat > "$T/.sourceatlas/refactor/legacy/state.yaml" <<'EOF'
schema_version: "2.1"
module: "legacy"
file: "src/Legacy.m"
current_step: 7
updated: "x"
migration_mode:
  mode_name: "seam-injection"
steps:
  7_gate:      { status: produced, completed_at: null, replacement_script: null }
  8_new_impl:       { status: pending, completed_at: null }
  9_swap:           { status: pending, completed_at: null }
  10_verification:  { status: pending, completed_at: null }
  11_integration:   { status: pending, completed_at: null }
  12_cleanup:       { status: pending, completed_at: null }
  13_delete_legacy: { status: pending, completed_at: null }
EOF
printf 'module: "legacy"\nfile: "src/Legacy.m"\n' > "$T/.sourceatlas/refactor/legacy/1_target.yaml"
printf 'protocol:\n  name: "LegacySeam"\nswap_strategy: "direct"\n' > "$T/.sourceatlas/refactor/legacy/5_interface.yaml"
printf 'class LegacyAdapter: LegacySeam {}\n' > "$T/.sourceatlas/refactor/legacy/6_adapter.swift"
printf '@implementation Legacy\n@end\n' > "$T/src/Legacy.m"

# ── State machine: advance 7 → 13, then terminal refusal ────────────────────
S advance --module legacy >/dev/null; expect "advance 7→8" 0 $?
for step in 8_new_impl 9_swap 10_verification 11_integration 12_cleanup; do
    S set-status --module legacy --step "$step" --status produced >/dev/null
    S advance --module legacy >/dev/null
done
expect "advance walk reached 13" 0 $?
S advance --module legacy >/dev/null 2>&1; expect "advance at 13 refused" 3 $?

# ── Gate step 8 ──────────────────────────────────────────────────────────────
printf 'final class NewImpl {}\n' > "$T/src/NewImpl.swift"
G --module legacy --step 8 --impl-file "$T/src/NewImpl.swift" >/dev/null; expect "step8 clean impl passes" 0 $?
printf 'final class NewImpl { let l = Legacy() }\n' > "$T/src/NewImpl.swift"
G --module legacy --step 8 --impl-file "$T/src/NewImpl.swift" >/dev/null; expect "step8 legacy ref fails" 3 $?
printf 'final class NewImpl {}\n' > "$T/src/NewImpl.swift"

# ── Gate step 12 ─────────────────────────────────────────────────────────────
printf 'let x = LegacyAdapter()\n' > "$T/src/Wiring.swift"
G --module legacy --step 12 >/dev/null; expect "step12 wired adapter fails" 3 $?
printf 'let x = NewImpl()\n' > "$T/src/Wiring.swift"
G --module legacy --step 12 >/dev/null; expect "step12 clean passes" 0 $?

# ── Gate step 13 ─────────────────────────────────────────────────────────────
G --module legacy --step 13 >/dev/null; expect "step13 legacy present fails" 3 $?
rm "$T/src/Legacy.m"
G --module legacy --step 13 >/dev/null; expect "step13 deleted passes" 0 $?

[[ "$fail" -eq 0 ]] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
