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
has() { # has <label> <file> <pattern>
    if grep -q -- "$3" "$2" 2>/dev/null; then echo "ok  $1"
    else echo "FAIL $1 (no '$3' in $2)"; fail=1; fi
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
# 11 lines / 2 `if` lines, so step-12 metric ratios are meaningful
cat > "$T/src/Legacy.m" <<'EOF'
@implementation Legacy
- (int)value:(int)x {
    if (x > 0) {
        return x;
    }
    if (x < -10) {
        return -10;
    }
    return 0;
}
@end
EOF

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

# ── Gate step 12 metrics (informational — must never change exit codes) ──────
M="$T/.sourceatlas/refactor/legacy/12_metrics.yaml"
printf 'final class NewImpl {\n    func value(_ x: Int) -> Int {\n        if x > 0 { return x }\n        return 0\n    }\n}\n' > "$T/src/NewImpl.swift"
G --module legacy --step 12 --impl-file "$T/src/NewImpl.swift" >/dev/null; expect "step12 metrics small impl passes" 0 $?
has "step12 metrics writes loc_pct" "$M" "loc_pct"
has "step12 metrics impl path is project-relative" "$M" 'file: "src/NewImpl.swift"'
# bloated impl: >150% of Legacy.m LOC and more `if` lines → flags fire, exit still 0
for i in $(seq 1 30); do echo "        if flag$i { total += $i }"; done > "$T/src/Bloat.swift"
G --module legacy --step 12 --impl-file "$T/src/Bloat.swift" >/dev/null; expect "step12 bloated impl still passes" 0 $?
has "step12 metrics flags loc_ratio_gt_150" "$M" "loc_ratio_gt_150"
G --module legacy --step 12 >/dev/null; expect "step12 no impl-file passes" 0 $?
has "step12 metrics records not_provided" "$M" "not_provided"
printf 'final class NewImpl {}\n' > "$T/src/NewImpl.swift"

# ── Gate step 12 goal checks (declared criteria echo — never a gate) ─────────
# Earlier step-12 runs covered the absent-block silent path; now declare one.
# First: goal with no checks → unverified: true
cat >> "$T/.sourceatlas/refactor/legacy/1_target.yaml" <<'EOF'
success_criteria:
  goal: "wiring references NewImpl only"
  checks: []
EOF
G --module legacy --step 12 --impl-file "$T/src/NewImpl.swift" >/dev/null; expect "step12 goal-only still passes" 0 $?
has "step12 goal-only marks unverified" "$M" "unverified: true"
# Now add actual checks (overwrite success_criteria by rewriting the file tail)
python3 -c "
import re, sys
t = open(sys.argv[1]).read()
t = re.sub(r'success_criteria:.*', '', t, flags=re.DOTALL)
open(sys.argv[1],'w').write(t)
" "$T/.sourceatlas/refactor/legacy/1_target.yaml"
cat >> "$T/.sourceatlas/refactor/legacy/1_target.yaml" <<'EOF'
success_criteria:
  goal: "wiring references NewImpl only"
  checks:
    - desc: "NewImpl wired"
      verify: "grep -q NewImpl src/Wiring.swift"
    - desc: "phantom symbol present"
      verify: "grep -q NoSuchThing src/Wiring.swift"
EOF
G --module legacy --step 12 --impl-file "$T/src/NewImpl.swift" >/dev/null; expect "step12 unmet goal check still passes" 0 $?
has "step12 metrics writes goal_checks" "$M" "goal_checks:"
has "step12 goal check met recorded" "$M" "met: true"
has "step12 goal check unmet recorded" "$M" "met: false"
has "step12 retrospective prompt recorded" "$M" "retrospective:"

# ── Gate step 13 ─────────────────────────────────────────────────────────────
G --module legacy --step 13 >/dev/null; expect "step13 legacy present fails" 3 $?
rm "$T/src/Legacy.m"
G --module legacy --step 13 >/dev/null; expect "step13 deleted passes" 0 $?

[[ "$fail" -eq 0 ]] && echo "ALL PASS" || { echo "FAILURES"; exit 1; }
