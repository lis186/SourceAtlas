#!/bin/bash
# rank-candidates.sh — Deterministic refactor candidate ranking
#
# Computes score = commits_90d × lines for every source file in the repo.
# Outputs a sorted JSON array to .sourceatlas/refactor/candidates.json.
# No LLM involvement — same input always produces same output.
#
# Usage:
#   bash rank-candidates.sh [repo_dir]
#
# Output:
#   .sourceatlas/refactor/candidates.json
#
# Score formula: commits_90d × lines  (matches /atlas.history Complexity Score)
set -euo pipefail

REPO_DIR="${1:-.}"
OUTPUT_DIR=".sourceatlas/refactor"
OUTPUT_FILE="${OUTPUT_DIR}/candidates.json"
MIN_LINES=200       # God Class threshold
TOP_N=10            # Max candidates to return
CACHE_TTL=3600      # Seconds before cache expires (1 hour)

cd "$REPO_DIR"

# ─────────────────────────────────────────────────────────
# Cache check
# ─────────────────────────────────────────────────────────

if [ -f "$OUTPUT_FILE" ]; then
    GENERATED_AT=$(grep '"generated_at"' "$OUTPUT_FILE" | sed 's/.*"generated_at": *"\([^"]*\)".*/\1/' || true)
    if [ -n "$GENERATED_AT" ]; then
        # macOS: date -j; Linux: date -d
        EPOCH_CACHE=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$GENERATED_AT" +%s 2>/dev/null \
            || date -d "$GENERATED_AT" +%s 2>/dev/null \
            || echo 0)
        CACHE_AGE=$(( $(date +%s) - EPOCH_CACHE ))
        if [ "$CACHE_AGE" -lt "$CACHE_TTL" ]; then
            echo "📦 Using cached candidates (${CACHE_AGE}s old)" >&2
            cat "$OUTPUT_FILE"
            exit 0
        fi
    fi
fi

# ─────────────────────────────────────────────────────────
# Collect source files
# ─────────────────────────────────────────────────────────

# Extensions to include (source code, not config/docs/data)
EXTENSIONS="m|swift|ts|js|tsx|jsx|go|py|java|kt|rs|cpp|cc|c|h"

# Write matching files to a temp file (bash 3.2 compatible — no mapfile)
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

git ls-files \
    | grep -E "\.($EXTENSIONS)$" \
    | grep -vE "(test|spec|mock|generated|__pycache__|\.min\.|vendor/|node_modules/|Pods/)" \
    | grep -v "^\.git/" \
    > "$TMPFILE" || true

FILE_COUNT=$(wc -l < "$TMPFILE" | tr -d ' ')

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "⚠️  No source files found in $(pwd)" >&2
    mkdir -p "$OUTPUT_DIR"
    printf '{"generated_at":"%s","candidates":[]}\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$OUTPUT_FILE"
    exit 0
fi

# ─────────────────────────────────────────────────────────
# Score each file: commits_90d × lines
# ─────────────────────────────────────────────────────────

SINCE_DATE=$(date -v-90d +"%Y-%m-%d" 2>/dev/null \
    || date -d "90 days ago" +"%Y-%m-%d" 2>/dev/null \
    || echo "")

echo "🔍 Scoring $FILE_COUNT source files..." >&2

# Scored entries: "score\tcommits\tlines\tfile" written to SCORED_FILE
SCORED_FILE=$(mktemp)
trap 'rm -f "$TMPFILE" "$SCORED_FILE"' EXIT

while IFS= read -r file; do
    [ -f "$file" ] || continue

    LINES=$(wc -l < "$file" 2>/dev/null | tr -d ' ' || echo 0)

    # Skip files below God Class threshold
    if [ "$LINES" -lt "$MIN_LINES" ]; then
        continue
    fi

    if [ -n "$SINCE_DATE" ]; then
        COMMITS=$(git log --oneline --since="$SINCE_DATE" -- "$file" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    else
        COMMITS=$(git log --oneline -n 200 -- "$file" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    fi

    SCORE=$(( COMMITS * LINES ))
    printf '%s\t%s\t%s\t%s\n' "$SCORE" "$COMMITS" "$LINES" "$file" >> "$SCORED_FILE"
done < "$TMPFILE"

SCORED_COUNT=$(wc -l < "$SCORED_FILE" | tr -d ' ')

if [ "$SCORED_COUNT" -eq 0 ]; then
    echo "⚠️  No files over ${MIN_LINES} lines found" >&2
    mkdir -p "$OUTPUT_DIR"
    printf '{"generated_at":"%s","candidates":[]}\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$OUTPUT_FILE"
    exit 0
fi

# Sort by score descending, take top N → TOP_FILE
TOP_FILE=$(mktemp)
trap 'rm -f "$TMPFILE" "$SCORED_FILE" "$TOP_FILE"' EXIT
sort -t$'\t' -k1 -rn "$SCORED_FILE" | head -n "$TOP_N" > "$TOP_FILE"

TOP_COUNT=$(wc -l < "$TOP_FILE" | tr -d ' ')

# ─────────────────────────────────────────────────────────
# Helper: check cache presence
# ─────────────────────────────────────────────────────────

has_audit_cache() {
    local module
    module=$(basename "$1" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]')
    [ -f ".sourceatlas/audit/${module}.yaml" ] && echo "true" || echo "false"
}

has_seam_cache() {
    local module
    module=$(basename "$1" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]')
    if [ -f ".sourceatlas/seam/${module}.yaml" ] || [ -f ".sourceatlas/refactor/${module}/3_seams.yaml" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# ─────────────────────────────────────────────────────────
# Build JSON output
# ─────────────────────────────────────────────────────────

mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

{
    printf '{\n'
    printf '  "generated_at": "%s",\n' "$TIMESTAMP"
    printf '  "repo": "%s",\n' "$(basename "$(pwd)")"
    printf '  "min_lines": %d,\n' "$MIN_LINES"
    printf '  "window_days": 90,\n'
    printf '  "candidates": [\n'

    RANK=1
    while IFS=$'\t' read -r score commits lines file; do
        AUDIT=$(has_audit_cache "$file")
        SEAM=$(has_seam_cache "$file")

        printf '    {\n'
        printf '      "rank": %d,\n' "$RANK"
        printf '      "file": "%s",\n' "$file"
        printf '      "lines": %d,\n' "$lines"
        printf '      "commits_90d": %d,\n' "$commits"
        printf '      "score": %d,\n' "$score"
        printf '      "has_audit_cache": %s,\n' "$AUDIT"
        printf '      "has_seam_cache": %s\n' "$SEAM"

        if [ "$RANK" -lt "$TOP_COUNT" ]; then
            printf '    },\n'
        else
            printf '    }\n'
        fi

        RANK=$(( RANK + 1 ))
    done < "$TOP_FILE"

    printf '  ]\n'
    printf '}\n'
} > "$OUTPUT_FILE"

echo "✅ Ranked $TOP_COUNT candidates → $OUTPUT_FILE" >&2
cat "$OUTPUT_FILE"
