#!/usr/bin/env bash
# pilot-run.sh — end-to-end refactor pilot for a single target file.
#
# Chains the ObjC/Swift-aware scripts together:
#   detect-phase → detect-zones → runtime-hidden-deps (target-scoped)
#   + reference to project-level cross-language.yaml
#
# Produces a single Step-1 readiness report per target for human review.
#
# Usage: pilot-run.sh <project-root> <target-file> [--output <path>]
#
set -euo pipefail

PROJECT_ROOT="${1:?Usage: pilot-run.sh <project-root> <target-file>}"
TARGET="${2:?Usage: pilot-run.sh <project-root> <target-file>}"
OUTPUT=""

shift 2 || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) OUTPUT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
[[ -f "$TARGET" ]] || TARGET="$PROJECT_ROOT/$TARGET"
[[ -f "$TARGET" ]] || { echo "error: target not found: $TARGET" >&2; exit 2; }

basename_noext=$(basename "$TARGET")
module_name="${basename_noext%.*}"

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="$PROJECT_ROOT/.sourceatlas/refactor/pilot-${module_name}.md"
fi
mkdir -p "$(dirname "$OUTPUT")"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "# Pilot Report: $basename_noext" > "$OUTPUT"
echo "" >> "$OUTPUT"
echo "Target: \`$TARGET\`" >> "$OUTPUT"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Reading guide — what each section means and what phase numbers represent
echo "## Reading Guide" >> "$OUTPUT"
cat >> "$OUTPUT" <<'GUIDE'
- **Phase**: based on Feathers' Legacy Code Playbook
  - `phase: 1`   — zero test coverage on this module → focus on adding coverage; rank zones by *least edit-distance to a working test* (Feathers' "easiest first")
  - `phase: 1.5` — 1-2 test files exist → expand coverage before restructuring
  - `phase: 2`   — ≥3 test files exist → safe to rank zones by architectural value (extract first what reduces coupling most)
- **Zones**: contiguous code regions delimited by `#pragma mark` (ObjC) or `// MARK:` (Swift). Each lists its line count, methods, and detected dependencies.
- **Cross-language**: project-wide visibility metrics (Bridging-Header, -Swift.h, @objc surface, nullability coverage).
- **Runtime-Hidden Dependencies**: Category / swizzle / KVC / IB / storyboard sites — things static import analysis misses but that affect runtime behavior.
- **Recommended First Slice**: heuristic suggestion for the safest first refactor target. **Always verify before acting.**

GUIDE
echo "" >> "$OUTPUT"

# Phase
echo "## Phase Detection" >> "$OUTPUT"
echo '```yaml' >> "$OUTPUT"
bash "$SCRIPT_DIR/detect-phase.sh" "$TARGET" --project-root "$PROJECT_ROOT" 2>&1 >> "$OUTPUT" || true
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Zones
echo "## Zone Map" >> "$OUTPUT"
echo '```yaml' >> "$OUTPUT"
bash "$SCRIPT_DIR/detect-zones.sh" "$TARGET" 2>&1 >> "$OUTPUT" || true
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Cross-language context (global — regenerate only if missing)
xlang_file="$PROJECT_ROOT/.sourceatlas/cross-language.yaml"
if [[ ! -f "$xlang_file" ]]; then
    bash "$SCRIPT_DIR/cross-language-visibility.sh" "$PROJECT_ROOT" >/dev/null 2>&1 || true
fi
echo "## Cross-Language Visibility (project-level)" >> "$OUTPUT"
if [[ -f "$xlang_file" ]]; then
    echo '```yaml' >> "$OUTPUT"
    grep -E "^[[:space:]]*(bridging_headers_count|generated_swift_headers_count|objc_annotations|objcmembers_annotations|ns_swift_name_count|total_headers|headers_with_nonnull_region|nonnull_coverage_pct|nullability_token_count|language_boundaries|swift_to_objc_exposure|objc_to_swift_safety):" "$xlang_file" | sed 's/^  //' >> "$OUTPUT" || true
    echo '```' >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Target-scoped runtime hidden deps
echo "## Runtime-Hidden Dependencies (target-scoped)" >> "$OUTPUT"
scoped_yaml="$PROJECT_ROOT/.sourceatlas/refactor/${module_name}-runtime-hidden.yaml"
bash "$SCRIPT_DIR/runtime-hidden-deps.sh" "$PROJECT_ROOT" --output "$scoped_yaml" --target "$module_name" >/dev/null 2>&1 || true
if [[ -f "$scoped_yaml" ]]; then
    echo '```yaml' >> "$OUTPUT"
    grep -A 60 '^summary:' "$scoped_yaml" >> "$OUTPUT" || true
    echo '```' >> "$OUTPUT"

    # Per-class breakdown: top files by category/swizzle count
    echo "" >> "$OUTPUT"
    echo "### Top hot files for this module's hidden-dep classes" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
    {
        echo "# Top files containing categories on $module_name or swizzling near it"
        grep -rlE "^@interface $module_name \\(|method_exchangeImplementations|class_replaceMethod" \
            --include="*.m" --include="*.mm" --include="*.h" "$PROJECT_ROOT" 2>/dev/null \
            | grep -Ev '/(Pods|build|DerivedData|Carthage)/' | head -10
    } >> "$OUTPUT" || true
    echo '```' >> "$OUTPUT"

    # Specific swizzle locations (file:line)
    echo "" >> "$OUTPUT"
    echo "### Swizzle sites (specific locations)" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
    grep -rnE 'method_exchangeImplementations|class_replaceMethod|method_setImplementation' \
        --include="*.m" --include="*.mm" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null \
        | grep -Ev '/(Pods|build|DerivedData|Carthage)/' | head -15 >> "$OUTPUT" || true
    echo '```' >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# Focused runtime-hidden references to this module (post-hoc scan)
echo "### Direct Category/Extension surface referring to \`$module_name\`" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
grep -rnE "^@interface $module_name \(|^extension $module_name\b" \
    --include="*.m" --include="*.mm" --include="*.h" --include="*.swift" \
    "$PROJECT_ROOT" 2>/dev/null \
    | grep -Ev '/(Pods|build|DerivedData|Carthage)/' \
    | head -20 >> "$OUTPUT" || true
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Paired header API surface (for .m/.mm only)
case "$TARGET" in
    *.m|*.mm)
        header="${TARGET%.*}.h"
        if [[ -f "$header" ]]; then
            echo "## Paired Header API Surface (\`$(basename "$header")\`)" >> "$OUTPUT"
            local_methods=$(grep -cE '^[-+] *\(' "$header" 2>/dev/null || echo 0)
            local_props=$(grep -cE '^@property' "$header" 2>/dev/null || echo 0)
            local_nullnonnull=$(grep -cE 'NS_ASSUME_NONNULL_BEGIN|_Nullable|_Nonnull|nullable|nonnull|NS_SWIFT_NAME|NS_REFINED_FOR_SWIFT' "$header" 2>/dev/null || echo 0)
            echo '```yaml' >> "$OUTPUT"
            echo "header_path: \"$header\"" >> "$OUTPUT"
            echo "public_methods: $local_methods" >> "$OUTPUT"
            echo "public_properties: $local_props" >> "$OUTPUT"
            echo "nullability_tokens: $local_nullnonnull" >> "$OUTPUT"
            echo '```' >> "$OUTPUT"
            echo "" >> "$OUTPUT"
            echo "### Public API declarations (first 40)" >> "$OUTPUT"
            echo '```objc' >> "$OUTPUT"
            grep -nE '^@interface|^@property|^[-+] *\(' "$header" 2>/dev/null | head -40 >> "$OUTPUT" || true
            echo '```' >> "$OUTPUT"
        fi
        ;;
esac
echo "" >> "$OUTPUT"

# ── Test files referencing this module — read from detect-phase output ──
# (Strict consistency: pilot-run reuses the SAME list detect-phase counted,
# so test_refs count never disagrees with the file list shown below.)
echo "## Test Files Covering \`$module_name\`" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
set +o pipefail
test_files=$(grep -E '^[[:space:]]*-[[:space:]]+"' "$OUTPUT" \
    | sed -n '/test_file_paths:/,$p' \
    | grep -E '^[[:space:]]+-[[:space:]]+"' \
    | sed 's/^[[:space:]]*-[[:space:]]*"//; s/"[[:space:]]*$//' \
    | head -20 || true)
# Fallback (older detect-phase without test_file_paths): use awk to find the block
if [[ -z "$test_files" ]]; then
    test_files=$(awk '/test_file_paths:/{flag=1; next} flag && /^[[:space:]]+-[[:space:]]/{print; next} flag{exit}' "$OUTPUT" \
        | sed 's/^[[:space:]]*-[[:space:]]*"//; s/"[[:space:]]*$//' | head -20 || true)
fi
set -o pipefail
if [[ -n "$test_files" ]]; then
    echo "$test_files" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "(count matches phase detection's test_refs)" >> "$OUTPUT"
else
    echo "(no test files reference this module by name)" >> "$OUTPUT"
fi
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# ── Recommended First Slice (PHASE-AWARE) ─────────────────────────────
# Phase 1/1.5 (Feathers): smallest zone with fewest deps — least edit-distance to a working test
# Phase 2:                zone with HIGHEST dep count — biggest architectural lever
# Tie-breaker on Phase 2: prefer zones already named in test files
# ── Testability Triage ───────────────────────────────────────────────
# Categorise the target so the recommendation matches reality:
#   pure_logic     — no UIKit / IB / singleton: testable as-is
#   needs_surgery  — UIKit + logic mixed: needs Extract to ViewModel/Sprout
#   ui_only        — heavy IB/xib/storyboard binding: prefer snapshot/UI test
echo "## Testability Triage" >> "$OUTPUT"

# Detect signals (from target file + paired .h + paired .xib presence)
paired_h="${TARGET%.*}.h"
paired_xib="${TARGET%.*}.xib"
target_basename_noext="${basename_noext%.*}"

# Use a helper that always returns a single integer, even when grep -c
# returns 0 with exit 1 (no match). `|| echo 0` is wrong because grep -c
# already prints "0" on no-match — it would emit "0\n0" and break $((...)).
_ccount() { local n; n=$(grep -cE "$1" "$2" 2>/dev/null); [[ -z "$n" ]] && n=0; echo "$n"; }
set +o pipefail
ui_imports=$(_ccount '^(#import[[:space:]]+<UIKit|import[[:space:]]+UIKit|import[[:space:]]+SwiftUI)' "$TARGET")
if [[ -f "$paired_h" ]]; then
    ui_imports=$((ui_imports + $(_ccount '^(#import[[:space:]]+<UIKit|import[[:space:]]+UIKit)' "$paired_h")))
fi
ib_outlets=$(_ccount 'IBOutlet|IBAction|@IBOutlet|@IBAction' "$TARGET")
if [[ -f "$paired_h" ]]; then
    ib_outlets=$((ib_outlets + $(_ccount 'IBOutlet|IBAction' "$paired_h")))
fi
has_xib=0; [[ -f "$paired_xib" ]] && has_xib=1
storyboard_refs=$(grep -rl "$target_basename_noext" --include="*.storyboard" --include="*.xib" "$PROJECT_ROOT" 2>/dev/null \
    | grep -Ev '/(Pods|build|DerivedData)/' | wc -l | tr -d ' ')
singleton_use=$(_ccount '\bsharedInstance\b|\.shared\b|\.default\b' "$TARGET")
mainactor_use=$(_ccount '@MainActor' "$TARGET")

# ── Companion files (structural preparation already done?) ──
# Strong signal: a file is NAMED as a companion (find by filename).
#   {stem}+*.swift / {stem}+*.m   — Swift extension convention
#   {stem}ViewModel.* / {stem}Presenter.* / {stem}LayoutEngine.*
#   {stem}Helper.* / {stem}Factory.* / {stem}Coordinator.*
#   {stem}Processor.* / {stem}DataSource.* / {stem}Delegate.*
#   {stem}Extensions.* (when engineers follow non-`+` convention)
companion_tmp=$(mktemp)
strong_suffixes="+*.swift +*.m ViewModel.swift ViewModel.m Presenter.swift Presenter.m LayoutEngine.swift LayoutEngine.m Helper.swift Helper.m Factory.swift Factory.m Coordinator.swift Coordinator.m Processor.swift Processor.m DataSource.swift DataSource.m Delegate.swift Delegate.m Extensions.swift Extensions.m"
{
    for suf in $strong_suffixes; do
        find "$PROJECT_ROOT" -name "${target_basename_noext}${suf}" 2>/dev/null
    done
} | grep -Ev '/(Pods|build|DerivedData|Carthage|SourcePackages|node_modules)/' \
  | grep -v "$TARGET" | sort -u > "$companion_tmp" || true
companion_count=$(wc -l < "$companion_tmp" | tr -d ' ')
set -o pipefail

# Classify and emit the strategy block directly to a temp file.
# (bash 3.2 mishandles $(cat <<HEREDOC ... HEREDOC) — write to file instead.)
strategy_tmp=$(mktemp)
# Heavy singleton coupling defeats "pure_logic" — even without UIKit, you'd
# need to fake N singletons to test. Treat as needs_surgery (Sprout Class).
heavy_singletons=0; [[ "$singleton_use" -gt 5 ]] && heavy_singletons=1
# Partial surgery signal: ≥1 named companion file (ViewModel / Presenter /
# LayoutEngine / Extensions / +Category) means someone already extracted
# at least one thing — partial surgery is done.
has_structural_prep=0; [[ "$companion_count" -ge 1 ]] && has_structural_prep=1

if [[ "$ui_imports" -eq 0 && "$ib_outlets" -eq 0 && "$has_xib" -eq 0 && "$storyboard_refs" -eq 0 && "$heavy_singletons" -eq 0 ]]; then
    testability="pure_logic"
    cat > "$strategy_tmp" <<'BLK'
**Strategy: write characterization tests now** — target has no UI dependencies. Should take 30-60 minutes.

1. Add `XCTest` file mirroring the target name.
2. For each public method: pick representative inputs, capture current outputs, assert them.
3. Run tests once to confirm they pass against today's behavior.
4. Now you have a real safety net — proceed with Feathers' standard playbook.
BLK
elif [[ "$has_xib" -eq 1 || "$storyboard_refs" -gt 0 || "$ib_outlets" -gt 5 ]]; then
    if [[ "$has_structural_prep" -eq 1 ]]; then
        testability="partial_surgery_done"
        cat > "$strategy_tmp" <<BLK
**Strategy: finish the surgery, then test** — target is UI-bound but $companion_count companion files already exist (ViewModel / Presenter / Helper / Extensions). Previous engineers have done partial structural preparation.

Order of operations:

1. **Audit what's already extracted** — review the companion files listed below. Note what logic already lives outside the target.
2. **Identify remaining bleed** — what's still in the target that should live in a companion? Move it.
3. **Test the companions** — they're plain classes, testable directly. This builds your safety net.
4. **Snapshot test the UI** for regression guard.
5. **Migrate** — the remaining VC code should be thin enough to rewrite confidently.

Risk: **medium** (lower than ui_only without prep). Work already done helps.
See dev-notes/2026-04/2026-04-15-history-replay-nymemberloyaltypoint.md
BLK
    else
        testability="ui_only"
        cat > "$strategy_tmp" <<BLK
**Strategy: surgery before tests** — target is UI-bound (xib=$has_xib, IB outlets=$ib_outlets, storyboard refs=$storyboard_refs) AND no companion files found.

Direct characterization tests are expensive. Order of operations:

1. **Move presentation logic out** — extract calculation/data-shaping to a plain class such as ViewModel or Presenter. The plain class IS testable; test it.
2. **Replace xib/storyboard with code** if possible — removes IB string-dispatch, equivalent to breaking a Link Seam.
3. **Snapshot test as a cheap UI safety net** — swift-snapshot-testing or FBSnapshotTestCase: ~1 line per visual state.
4. **THEN do the language migration** — by now most logic lives in testable plain classes.

Risk: **high** (no prep done yet).
This matches what nineyiappshop's team historically did: sub-view extract → xib removal → rewrite.
See dev-notes/2026-04/2026-04-15-history-replay-nymemberloyaltypoint.md
BLK
    fi
else
    testability="needs_surgery"
    cat > "$strategy_tmp" <<BLK
**Strategy: small surgery first, then test** — target imports UIKit but logic looks separable. singletons=$singleton_use, IB=$ib_outlets.

1. **Extract pure logic** into a sibling class — Feathers' Sprout Class. Anything that does not read/write a UIView belongs there.
2. **Test the extracted class** — it has no UIKit deps now.
3. **Wrap remaining UIKit calls** behind a protocol so they can be faked in tests — Feathers' Extract Interface.
4. **Now write characterization tests** on the original target's remaining logic.
BLK
fi

# Confidence score (0-10) — how confident can we be that this target is
# safe to act on right now? Higher = less prep needed.
#
#   testability base:  pure_logic 6  | partial_surgery_done 4
#                      needs_surgery 3 | ui_only 1
#   + companion files present (>=2):  +2
#   + existing test file count (>0):  +2 (up to)
#   - heavy singleton (>20):          -1
#   (clamped to 0..10)
case "$testability" in
    pure_logic)           conf=6 ;;
    partial_surgery_done) conf=4 ;;
    needs_surgery)        conf=3 ;;
    ui_only)              conf=1 ;;
    *)                    conf=0 ;;
esac
[[ "$companion_count" -ge 1 ]] && conf=$((conf + 1))
[[ "$companion_count" -ge 3 ]] && conf=$((conf + 1))
# test_refs extracted earlier from YAML (if present); recompute safely
existing_tests=$(grep -E '^  test_refs:' "$OUTPUT" | head -1 | awk '{print $2}')
existing_tests=${existing_tests:-0}
if [[ "$existing_tests" -ge 3 ]]; then
    conf=$((conf + 2))
elif [[ "$existing_tests" -ge 1 ]]; then
    conf=$((conf + 1))
fi
[[ "$singleton_use" -gt 20 ]] && conf=$((conf - 1))
[[ "$conf" -lt 0 ]] && conf=0
[[ "$conf" -gt 10 ]] && conf=10

# Confidence label
if   [[ "$conf" -ge 8 ]]; then conf_label="HIGH — ready to proceed"
elif [[ "$conf" -ge 5 ]]; then conf_label="MEDIUM — verify prep items before acting"
else conf_label="LOW — do structural prep first"
fi

cat >> "$OUTPUT" <<EOF
\`\`\`yaml
testability:
  level: "$testability"
  confidence_score: $conf        # 0 (risky) … 10 (safe to act)
  confidence_label: "$conf_label"
  signals:
    uikit_imports: $ui_imports
    ib_outlets_actions: $ib_outlets
    has_paired_xib: $has_xib
    storyboard_xib_refs: $storyboard_refs
    singleton_access: $singleton_use
    mainactor_use: $mainactor_use
  structural_prep:
    companion_files_count: $companion_count
    existing_tests: $existing_tests
\`\`\`

EOF

# Emit companion files if any
if [[ "$companion_count" -gt 0 ]]; then
    echo "### Companion files already extracted" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
    cat "$companion_tmp" >> "$OUTPUT"
    echo '```' >> "$OUTPUT"
    echo "" >> "$OUTPUT"
fi
rm -f "$companion_tmp"

cat "$strategy_tmp" >> "$OUTPUT"
rm -f "$strategy_tmp"
echo "" >> "$OUTPUT"

echo "## Recommended First Slice" >> "$OUTPUT"

# Resolve detected phase from earlier section
detected_phase=$(grep -E '^[[:space:]]*phase:' "$OUTPUT" | head -1 | sed 's/.*phase: *//' | tr -d '"' | tr -d ' ')

zone_yaml="$PROJECT_ROOT/.sourceatlas/refactor/${module_name}-zones.tmp"
bash "$SCRIPT_DIR/detect-zones.sh" "$TARGET" 2>/dev/null > "$zone_yaml" || true

if [[ -s "$zone_yaml" ]]; then
    # Common parsing → tab-separated tuple per zone:
    #   line_count <TAB> deps_n <TAB> id <TAB> name <TAB> lines
    parsed=$(awk '
        /^  - id: "/        { if (id) { print line_count "\t" deps_n "\t" id "\t" name "\t" lines } ;
                              id=$0; sub(/^  - id: "/, "", id); sub(/".*/, "", id);
                              name=""; lines=""; line_count=0; deps_n=0 }
        /^    name: "/      { name=$0; sub(/^    name: "/, "", name); sub(/".*/, "", name) }
        /^    lines: \[/    { lines=$0; sub(/^    lines: /, "", lines) }
        /^    line_count:/  { line_count=$2 }
        /^    deps:/        { gsub(/[][,]/, " "); deps_n=NF-1; if (deps_n<0) deps_n=0 }
        END                 { if (id) print line_count "\t" deps_n "\t" id "\t" name "\t" lines }
    ' "$zone_yaml")

    set +o pipefail
    case "$detected_phase" in
        2)
            # Phase 2: highest deps_n (architectural lever); tie-break by larger line_count
            pick=$(echo "$parsed" | sort -t$'\t' -k2,2nr -k1,1nr | head -1)
            heuristic_label="Phase 2 — highest-dep-count zone (architectural lever)"
            heuristic_why="Phase 2 means coverage is sufficient to refactor for design; pick the zone whose extraction reduces the most coupling."
            ;;
        *)
            # Phase 1 / 1.5 / unknown: smallest line_count, then fewest deps (Feathers easiest-first)
            pick=$(echo "$parsed" | sort -t$'\t' -k1,1n -k2,2n | head -1)
            heuristic_label="Phase 1/1.5 — smallest zone with fewest deps (Feathers' easiest-first)"
            heuristic_why="With low test coverage, prioritize zones easiest to wrap in a characterization test — least edit-distance to a working safety net."
            ;;
    esac
    set -o pipefail

    if [[ -n "$pick" ]]; then
        pick_lc=$(echo "$pick" | awk -F'\t' '{print $1}')
        pick_deps=$(echo "$pick" | awk -F'\t' '{print $2}')
        pick_id=$(echo "$pick" | awk -F'\t' '{print $3}')
        pick_name=$(echo "$pick" | awk -F'\t' '{print $4}')
        pick_lines=$(echo "$pick" | awk -F'\t' '{print $5}')

        cat >> "$OUTPUT" <<EOF
> **Heuristic**: $heuristic_label
> **Detected phase**: \`$detected_phase\`

\`\`\`yaml
recommended_zone:
  id: "$pick_id"
  name: "$pick_name"
  lines: $pick_lines
  line_count: $pick_lc
  dep_count: $pick_deps
\`\`\`

**Why this zone first**: $heuristic_why

### Next concrete actions
1. **Open** \`$basename_noext\` and locate the \`$pick_name\` zone (lines $pick_lines).
2. **Read** the methods in this zone (\`$pick_lc\` lines, $pick_deps deps) to understand current behavior.
3. **Cross-reference the test files listed above** — does any existing test already touch this zone? If yes, run it as your baseline.
4. **Write/extend a characterization test** (Feathers Step 4) that asserts the *current* output of one method in this zone (don't fix bugs yet).
5. **Run the test once** — if it passes, you have a safety net for this slice.
6. **Stop here** and report back; do NOT extract a seam until the test runs green.
EOF
    fi
fi
rm -f "$zone_yaml"
echo "" >> "$OUTPUT"

echo "## Step-1 Readiness Checklist" >> "$OUTPUT"
echo "- [ ] Phase detected and matches team expectation" >> "$OUTPUT"
echo "- [ ] Zone map covers all major sections of target" >> "$OUTPUT"
echo "- [ ] Cross-language exposure reviewed (Bridging-Header, -Swift.h)" >> "$OUTPUT"
echo "- [ ] Runtime-hidden showstoppers (swizzle/KVO/storyboard) triaged" >> "$OUTPUT"
echo "- [ ] Paired header API surface recorded" >> "$OUTPUT"
echo "- [ ] Recommended First Slice reviewed (override if heuristic looks wrong)" >> "$OUTPUT"

echo "wrote $OUTPUT"
