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
# Re-run scan limited to files referring to module_name
echo "## Runtime-Hidden Dependencies (target-scoped)" >> "$OUTPUT"
scoped_yaml="$PROJECT_ROOT/.sourceatlas/refactor/${module_name}-runtime-hidden.yaml"
bash "$SCRIPT_DIR/runtime-hidden-deps.sh" "$PROJECT_ROOT" --output "$scoped_yaml" --target "$module_name" >/dev/null 2>&1 || true
if [[ -f "$scoped_yaml" ]]; then
    echo '```yaml' >> "$OUTPUT"
    grep -A 60 '^summary:' "$scoped_yaml" >> "$OUTPUT" || true
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

# Header exposure (for .m/.mm only)
case "$TARGET" in
    *.m|*.mm)
        header="${TARGET%.*}.h"
        if [[ -f "$header" ]]; then
            echo "### Nullability / ObjC exposure in paired header" >> "$OUTPUT"
            echo '```' >> "$OUTPUT"
            grep -cE 'NS_ASSUME_NONNULL_BEGIN|_Nullable|_Nonnull|nullable|nonnull|NS_SWIFT_NAME|NS_REFINED_FOR_SWIFT' "$header" \
                | awk '{print "nullability_tokens_in_header: "$1}' >> "$OUTPUT" || true
            echo '```' >> "$OUTPUT"
        fi
        ;;
esac
echo "" >> "$OUTPUT"

echo "## Step-1 Readiness Checklist" >> "$OUTPUT"
echo "- [ ] Phase detected and matches team expectation" >> "$OUTPUT"
echo "- [ ] Zone map covers all major sections of target" >> "$OUTPUT"
echo "- [ ] Cross-language exposure reviewed (Bridging-Header, -Swift.h)" >> "$OUTPUT"
echo "- [ ] Runtime-hidden showstoppers (swizzle/KVO/storyboard) triaged" >> "$OUTPUT"
echo "- [ ] Nullability coverage on paired header recorded" >> "$OUTPUT"

echo "wrote $OUTPUT"
