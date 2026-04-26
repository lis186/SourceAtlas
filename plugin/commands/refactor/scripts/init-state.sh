#!/usr/bin/env bash
# init-state.sh — Step 1 Select Target: deterministic state initialization.
#
# Writes:
#   .sourceatlas/refactor/{module}/state.yaml
#   .sourceatlas/refactor/{module}/1_target.yaml
#
# Calls pilot-run.sh internally for phase/zone/platform detection.
#
# Usage:
#   init-state.sh <project-root> <target-file> [--mode <name>] [--force]
#
# Exit codes:
#   0  success — state.yaml + 1_target.yaml written
#   1  usage error
#   2  target not found
#   3  state already exists and --force not given
#
set -euo pipefail

PROJECT_ROOT="${1:?Usage: init-state.sh <project-root> <target-file> [--mode <name>] [--force]}"
TARGET="${2:?Usage: init-state.sh <project-root> <target-file> [--mode <name>] [--force]}"
shift 2 || true

MODE_OVERRIDE=""
FORCE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)  MODE_OVERRIDE="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        *)       shift ;;
    esac
done

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
[[ -f "$TARGET" ]] || TARGET="$PROJECT_ROOT/$TARGET"
[[ -f "$TARGET" ]] || { echo "error: target not found: $TARGET" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

# Emit a YAML double-quoted scalar with " and \ escaped.
# Use this for any value that might contain user-controlled characters (filenames).
yaml_dq() {
    local s="${1//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '"%s"' "$s"
}

# ── Derive identifiers ──────────────────────────────────────────────────────
basename_noext="$(basename "$TARGET")"
module_name="$(echo "${basename_noext%.*}" | tr '[:upper:]' '[:lower:]')"
ext="${basename_noext##*.}"
case "$ext" in
    m|mm|h)         language="objc";    group="A" ;;
    swift)          language="swift";   group="A" ;;
    java)           language="java";    group="A" ;;
    kt|kts)         language="kotlin";  group="A" ;;
    rs)             language="rust";    group="A" ;;
    go)             language="go";      group="B" ;;
    ts|tsx)         language="typescript"; group="B" ;;
    js|jsx)         language="javascript"; group="C" ;;
    py)             language="python";  group="C" ;;
    *)              language="$ext";    group="A" ;;
esac

state_dir="$PROJECT_ROOT/.sourceatlas/refactor/$module_name"
state_file="$state_dir/state.yaml"
target_file="$state_dir/1_target.yaml"

# ── Idempotency guard ───────────────────────────────────────────────────────
if [[ -f "$state_file" && "$FORCE" -ne 1 ]]; then
    echo "error: $state_file already exists. Re-run with --force to overwrite." >&2
    exit 3
fi

mkdir -p "$state_dir"

# ── Compute deterministic facts ─────────────────────────────────────────────
line_count=$(wc -l < "$TARGET" | tr -d ' ')
file_hash=$(shasum -a 256 "$TARGET" | awk '{print $1}')
iso_now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# commits_90d via git log (best-effort; 0 if not a git repo)
commits_90d=0
if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    since_date=$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d 2>/dev/null || echo "")
    if [[ -n "$since_date" ]]; then
        commits_90d=$(git -C "$PROJECT_ROOT" log --oneline --since="$since_date" -- "$TARGET" 2>/dev/null | wc -l | tr -d ' ')
    fi
fi

score=$(( line_count * commits_90d ))
if   (( score > 10000 )); then recommendation="proceed"
elif (( score >= 3000 )); then recommendation="caution"
else                           recommendation="skip"
fi

# ── Run pilot-run.sh (writes pilot-{module}.md, includes platform detection) ─
pilot_report="$PROJECT_ROOT/.sourceatlas/refactor/pilot-${module_name}.md"
echo "→ Running pilot-run.sh..." >&2
bash "$SCRIPT_DIR/pilot-run.sh" "$PROJECT_ROOT" "$TARGET" >&2 || true

# ── Parse pilot report for migration mode + platform signals ────────────────
detected_mode="seam-injection"
platform_id=""
platform_ref=""
detection_signals_inline="[]"

if [[ -f "$pilot_report" ]]; then
    # awk-based extraction: find key, take value between quotes (or trailing word)
    extract() {
        awk -v key="$1" '
            $0 ~ "^[[:space:]]*" key ":" {
                # try quoted value first
                if (match($0, /"[^"]*"/)) {
                    print substr($0, RSTART+1, RLENGTH-2)
                } else {
                    # fall back to first word after the colon
                    sub("^[[:space:]]*" key ":[[:space:]]*", "")
                    sub("[[:space:]]*$", "")
                    print
                }
                exit
            }
        ' "$pilot_report"
    }

    pmt=$(extract recommended_mode)
    if [[ -n "$pmt" ]]; then detected_mode="$pmt"; fi

    pid=$(extract platform_id)
    if [[ -n "$pid" ]]; then platform_id="$pid"; fi

    pref=$(extract reference)
    if [[ -n "$pref" ]]; then platform_ref="$pref"; fi

    if [[ -n "$platform_id" ]]; then
        detection_signals_inline=$(printf '\n    - "platform_id: %s"' "$platform_id")
    fi
fi

# ── Apply --mode override ───────────────────────────────────────────────────
if [[ -n "$MODE_OVERRIDE" ]]; then
    final_mode="$MODE_OVERRIDE"
    detection_source="override"
else
    final_mode="$detected_mode"
    detection_source="auto"
fi

# Auto-confirm only when mode is seam-injection (the safe default).
# Other modes require explicit user confirmation per Critical Rule 13.
if [[ "$final_mode" == "seam-injection" || "$detection_source" == "override" ]]; then
    confirmed="true"
    confirmed_at="\"$iso_now\""
else
    confirmed="false"
    confirmed_at="null"
fi

case "$final_mode" in
    seam-injection)      origin="developer"; granularity="single-swap" ;;
    strangler-fig)       origin="developer"; granularity="zone-by-zone" ;;
    platform-migration)  origin="platform";  granularity="single-swap" ;;
    platform-strangler)  origin="platform";  granularity="zone-by-zone" ;;
    *)                   origin="developer"; granularity="single-swap" ;;
esac

# ── ObjC/Swift showstopper counts (best-effort grep on target) ──────────────
swizzle_count=0
storyboard_dispatch=0
category_count=0
cross_language_exposed=false

if [[ "$language" == "objc" || "$language" == "swift" ]]; then
    # grep -c returns 1 when no match → || true to keep set -e happy; head -1 strips fallback echo
    swizzle_count=$(grep -cE 'method_exchangeImplementations' "$TARGET" 2>/dev/null | head -1 || true)
    storyboard_dispatch=$(grep -cE 'NSStringFromClass|UIStoryboard.*instantiateViewController' "$TARGET" 2>/dev/null | head -1 || true)
    category_count=$(grep -cE '^@interface[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(' "$TARGET" 2>/dev/null | head -1 || true)
    swizzle_count=${swizzle_count:-0}
    storyboard_dispatch=${storyboard_dispatch:-0}
    category_count=${category_count:-0}
    xlang_yaml="$PROJECT_ROOT/.sourceatlas/cross-language.yaml"
    if [[ -f "$xlang_yaml" ]] && grep -q "$module_name" "$xlang_yaml" 2>/dev/null; then
        cross_language_exposed=true
    fi
fi

# ── Write state.yaml ────────────────────────────────────────────────────────
file_rel="${TARGET#$PROJECT_ROOT/}"
module_q=$(yaml_dq "$module_name")
file_q=$(yaml_dq "$file_rel")

cat > "$state_file" <<EOF
schema_version: "2.0"
module: $module_q
file: $file_q
language: "$language"
language_group: "$group"
file_hash: "$file_hash"
created: "$iso_now"
updated: "$iso_now"
current_step: 1
zone_id: null
session_boundaries: [2, 5]

migration_mode:
  interface_origin: "$origin"
  migration_granularity: "$granularity"
  mode_name: "$final_mode"
  detection_source: "$detection_source"
  detection_signals: $detection_signals_inline
  confirmed: $confirmed
  confirmed_at: $confirmed_at

candidate_lock:
  locked: true
  score: $score
  locked_at: "$iso_now"

steps:
  1_target:    { status: produced, completed_at: "$iso_now" }
  2a_zones:    { status: pending, completed_at: null }
  2_contracts: { status: pending, completed_at: null, audit_mode: null }
  2_gate:      { status: pending, completed_at: null, rules_total: 0, rules_passed: 0 }
  3_seams:     { status: pending, completed_at: null, skip_reason: null }
  3_gate:      { status: pending, completed_at: null, candidates_total: 0, candidates_verified: 0, skip_reason: null }
  4_tests:     { status: pending, completed_at: null }
  5_interface: { status: pending, completed_at: null, migration_type: null, target_language: null, target_interface_ref: null, skip_reason: null }
  6_adapter:   { status: pending, completed_at: null, skip_reason: null }
  7_gate:      { status: pending, completed_at: null, replacement_script: null }
EOF

# ── Write 1_target.yaml ─────────────────────────────────────────────────────
pilot_ref_q=$(yaml_dq ".sourceatlas/refactor/pilot-${module_name}.md")
history_ref_q=$(yaml_dq ".sourceatlas/history/${module_name}.yaml")
impact_ref_q=$(yaml_dq ".sourceatlas/impact/${module_name}.yaml")

cat > "$target_file" <<EOF
module: $module_q
file: $file_q
language: "$language"
language_group: "$group"
line_count: $line_count
file_hash: "$file_hash"

suitability:
  commits_90d: $commits_90d
  score: $score
  blast_radius: null
  recommendation: "$recommendation"
  reason: "score=$score (lines=$line_count × commits_90d=$commits_90d)"

pilot_ref: $pilot_ref_q
history_ref: $history_ref_q
impact_ref: $impact_ref_q

migration_mode:
  mode_name: "$final_mode"
  detection_source: "$detection_source"
  detection_signals: $detection_signals_inline
  reference: $([ -n "$platform_ref" ] && echo "\"$platform_ref\"" || echo "null")
  confirmed: $confirmed

showstoppers:
  swizzle_count: $swizzle_count
  storyboard_dispatch: $storyboard_dispatch
  category_count: $category_count
  cross_language_exposed: $cross_language_exposed
EOF

# ── Summary to stdout ───────────────────────────────────────────────────────
cat <<EOF
Step 1 — Select Target: produced

  module:          $module_name
  file:            $file_rel
  language:        $language (group $group)
  line_count:      $line_count
  commits_90d:     $commits_90d
  score:           $score → $recommendation

  migration_mode:  $final_mode ($detection_source)
  confirmed:       $confirmed
EOF

if [[ "$confirmed" == "false" ]]; then
    cat <<EOF

  ⚠️  Mode requires user confirmation before Step 2.
  Run \`/atlas.refactor $file_rel --mode <name>\` to override, or confirm to proceed.
EOF
fi

if (( swizzle_count > 0 || storyboard_dispatch > 0 )); then
    echo
    echo "  ⚠️  Showstoppers detected:"
    if (( swizzle_count > 0 )); then
        echo "    - swizzle: $swizzle_count occurrence(s) — preserve order in Step 5"
    fi
    if (( storyboard_dispatch > 0 )); then
        echo "    - storyboard string dispatch: $storyboard_dispatch — Step 5 must keep class names"
    fi
fi

echo
echo "  artifacts: $state_file"
echo "             $target_file"
echo "             $pilot_report"
