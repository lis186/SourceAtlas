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
