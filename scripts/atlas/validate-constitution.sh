#!/bin/bash
# SourceAtlas Constitution Validator v1.0
# Validates analysis output against ANALYSIS_CONSTITUTION.md rules
#
# Usage:
#   ./validate-constitution.sh <analysis_file.yaml|md>
#   ./validate-constitution.sh --check-structure
#
# Exit codes:
#   0 - All validations passed
#   1 - Validation failed
#   2 - Input error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONSTITUTION_VERSION="1.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

echo "=== SourceAtlas Constitution Validator ==="
echo "📜 Constitution Version: $CONSTITUTION_VERSION"
echo ""

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if running structure check
if [[ "$1" == "--check-structure" ]]; then
    echo "🔍 Checking SourceAtlas structure compliance..."
    echo ""

    # Check for Constitution file
    if [[ -f "ANALYSIS_CONSTITUTION.md" ]]; then
        pass "ANALYSIS_CONSTITUTION.md exists"
    else
        fail "ANALYSIS_CONSTITUTION.md not found"
    fi

    # Check that all atlas commands reference Constitution
    echo ""
    echo "📋 Checking command Constitution references:"

    COMMANDS_DIR=".claude/commands"
    if [[ -d "$COMMANDS_DIR" ]]; then
        for cmd in "$COMMANDS_DIR"/atlas.*.md; do
            if [[ -f "$cmd" ]]; then
                CMD_NAME=$(basename "$cmd")
                if grep -q "Constitution" "$cmd"; then
                    pass "$CMD_NAME references Constitution"
                else
                    fail "$CMD_NAME missing Constitution reference"
                fi
            fi
        done
    else
        warn "Commands directory not found: $COMMANDS_DIR"
    fi

    # Check detection script
    echo ""
    echo "📋 Checking detection script:"

    DETECT_SCRIPT="scripts/atlas/detect-project-enhanced.sh"
    if [[ -f "$DETECT_SCRIPT" ]]; then
        if grep -q "Constitution" "$DETECT_SCRIPT"; then
            pass "detect-project-enhanced.sh references Constitution"
        else
            warn "detect-project-enhanced.sh should reference Constitution"
        fi

        # Check for forced exclusions (Article II)
        if grep -q "node_modules" "$DETECT_SCRIPT" && grep -q ".venv" "$DETECT_SCRIPT"; then
            pass "Forced exclusions implemented (node_modules, .venv)"
        else
            fail "Missing forced exclusions (Article II violation)"
        fi
    else
        warn "Detection script not found: $DETECT_SCRIPT"
    fi

    # Summary
    echo ""
    echo "=== Structure Check Summary ==="
    echo -e "  ${GREEN}Passed${NC}: $PASS_COUNT"
    echo -e "  ${RED}Failed${NC}: $FAIL_COUNT"
    echo -e "  ${YELLOW}Warnings${NC}: $WARN_COUNT"

    if [[ $FAIL_COUNT -gt 0 ]]; then
        exit 1
    fi
    exit 0
fi

# Validate analysis file
if [[ -z "$1" ]]; then
    echo "Usage: $0 <analysis_file.yaml|md>"
    echo "       $0 --check-structure"
    exit 2
fi

ANALYSIS_FILE="$1"

if [[ ! -f "$ANALYSIS_FILE" ]]; then
    echo "Error: File not found: $ANALYSIS_FILE"
    exit 2
fi

FILE_EXT="${ANALYSIS_FILE##*.}"
echo "📄 Analyzing: $ANALYSIS_FILE"
echo "📁 Format: $FILE_EXT"
echo ""

# =========================================
# Article I Validation: Information Theory
# =========================================
echo "--- Article I: Information Theory ---"

# Check for metadata (Section 5.2)
if [[ "$FILE_EXT" == "yaml" ]] || [[ "$FILE_EXT" == "yml" ]]; then
    # YAML file validation

    # Check scan_ratio
    if grep -q "scan_ratio:" "$ANALYSIS_FILE"; then
        # Extract numeric value from scan_ratio (handles "8.9%" or 8.9 or "8.9")
        SCAN_RATIO=$(grep "scan_ratio:" "$ANALYSIS_FILE" | head -1 | grep -oE '[0-9]+\.?[0-9]*' | head -1)
        if [[ -n "$SCAN_RATIO" ]]; then
            # Extract scale to determine max ratio
            SCALE=$(grep "project_scale:" "$ANALYSIS_FILE" | head -1 | grep -oE '(TINY|SMALL|MEDIUM|LARGE|VERY_LARGE)' | head -1)

            case "$SCALE" in
                "TINY")       MAX_RATIO=50 ;;
                "SMALL")      MAX_RATIO=20 ;;
                "MEDIUM")     MAX_RATIO=10 ;;
                "LARGE")      MAX_RATIO=5 ;;
                "VERY_LARGE") MAX_RATIO=3 ;;
                *)            MAX_RATIO=10 ; SCALE="UNKNOWN" ;;  # Default to MEDIUM
            esac

            # Compare (bash integer comparison - truncate decimal)
            RATIO_INT=${SCAN_RATIO%.*}
            RATIO_INT=${RATIO_INT:-0}
            if [[ $RATIO_INT -le $MAX_RATIO ]]; then
                pass "Scan ratio ${SCAN_RATIO}% within limit (max: ${MAX_RATIO}% for $SCALE)"
            else
                fail "Scan ratio ${SCAN_RATIO}% exceeds limit (max: ${MAX_RATIO}% for $SCALE)"
            fi
        fi
    else
        fail "Missing scan_ratio in metadata (Article I, Section 1.2)"
    fi

    # Check scanned_files list
    if grep -q "scanned_files:" "$ANALYSIS_FILE" || grep -q "files_scanned:" "$ANALYSIS_FILE"; then
        pass "Scanned files list present"
    else
        warn "No scanned files list found (Article I, Section 1.1 recommends recording)"
    fi

elif [[ "$FILE_EXT" == "md" ]]; then
    # Markdown file validation

    # Check for scan statistics
    if grep -q -i "scan" "$ANALYSIS_FILE" && grep -q "%" "$ANALYSIS_FILE"; then
        pass "Scan statistics present in report"
    else
        warn "Consider adding scan statistics to report"
    fi
fi

# =========================================
# Article II Validation: Exclusion Policy
# =========================================
echo ""
echo "--- Article II: Exclusion Policy ---"

# Check that forbidden directories are not referenced as scanned
FORBIDDEN_DIRS=("node_modules" ".venv" "vendor" "__pycache__" ".git" "Pods" "DerivedData" "build" "dist" "target" ".next" ".nuxt")

FOUND_FORBIDDEN=0
for dir in "${FORBIDDEN_DIRS[@]}"; do
    # Check if file references this directory as a scanned file (not just mentioning it)
    if grep -E "^\s*-.*${dir}/" "$ANALYSIS_FILE" 2>/dev/null | grep -v "#" | grep -v "exclude" > /dev/null; then
        fail "Forbidden directory in scan list: $dir (Article II violation)"
        FOUND_FORBIDDEN=1
    fi
done

if [[ $FOUND_FORBIDDEN -eq 0 ]]; then
    pass "No forbidden directories in scan list"
fi

# =========================================
# Article III Validation: Hypothesis Policy
# =========================================
echo ""
echo "--- Article III: Hypothesis Policy ---"

if [[ "$FILE_EXT" == "yaml" ]] || [[ "$FILE_EXT" == "yml" ]]; then
    # Count hypotheses
    HYPOTHESIS_COUNT=$(grep -c "hypothesis:" "$ANALYSIS_FILE" 2>/dev/null || echo "0")

    if [[ $HYPOTHESIS_COUNT -gt 0 ]]; then
        info "Found $HYPOTHESIS_COUNT hypotheses"

        # Check hypothesis structure (Section 3.2)
        # Each hypothesis should have: hypothesis, confidence, evidence, validation_method
        COMPLETE_HYPOTHESES=$(grep -A 4 "hypothesis:" "$ANALYSIS_FILE" | grep -c "confidence:" || echo "0")

        if [[ $COMPLETE_HYPOTHESES -eq $HYPOTHESIS_COUNT ]]; then
            pass "All hypotheses have confidence levels"
        else
            warn "Some hypotheses missing confidence levels"
        fi

        # Count low-confidence hypotheses
        LOW_CONF_COUNT=$(grep -E "confidence: *0\.[0-4]" "$ANALYSIS_FILE" | wc -l | tr -d ' ')

        # Get scale for limit check
        SCALE=$(grep "project_scale:" "$ANALYSIS_FILE" | head -1 | grep -oE '(TINY|SMALL|MEDIUM|LARGE|VERY_LARGE)' | head -1)

        case "$SCALE" in
            "TINY")       LOW_CONF_LIMIT=2 ;;
            "SMALL")      LOW_CONF_LIMIT=3 ;;
            "MEDIUM")     LOW_CONF_LIMIT=4 ;;
            "LARGE")      LOW_CONF_LIMIT=5 ;;
            "VERY_LARGE") LOW_CONF_LIMIT=6 ;;
            *)            LOW_CONF_LIMIT=4 ; SCALE="UNKNOWN" ;;
        esac

        if [[ $LOW_CONF_COUNT -le $LOW_CONF_LIMIT ]]; then
            pass "Low-confidence hypotheses ($LOW_CONF_COUNT) within limit ($LOW_CONF_LIMIT for $SCALE)"
        else
            fail "Too many low-confidence hypotheses: $LOW_CONF_COUNT (limit: $LOW_CONF_LIMIT for $SCALE)"
        fi
    else
        info "No hypotheses found (may be a different report type)"
    fi
fi

# =========================================
# Article IV Validation: Evidence Policy
# =========================================
echo ""
echo "--- Article IV: Evidence Policy ---"

# Check for evidence format (file:line references)
EVIDENCE_REFS=$(grep -oE "[a-zA-Z0-9_/.-]+\.(ts|js|py|swift|kt|go|rs|rb|php|md|yaml|yml|json):[0-9]+" "$ANALYSIS_FILE" 2>/dev/null | wc -l | tr -d ' ')

if [[ $EVIDENCE_REFS -gt 0 ]]; then
    pass "Found $EVIDENCE_REFS file:line evidence references"
else
    # Also check for file-only references (acceptable for configs)
    FILE_REFS=$(grep -oE "[a-zA-Z0-9_/.-]+\.(ts|js|py|swift|kt|go|rs|rb|php|md|yaml|yml|json|toml)" "$ANALYSIS_FILE" 2>/dev/null | wc -l | tr -d ' ')
    if [[ $FILE_REFS -gt 5 ]]; then
        pass "Found $FILE_REFS file references (consider adding line numbers for precision)"
    else
        warn "Limited evidence references found. Consider adding more file:line citations"
    fi
fi

# Check for unsupported claims (Section 4.3)
# Look for definitive statements without evidence markers
UNSUPPORTED=$(grep -E "^(This|The project|It) (is|uses|has) (a |an )?(high|low|good|bad|excellent|poor)" "$ANALYSIS_FILE" 2>/dev/null | grep -v "evidence\|證據\|引用\|:" | wc -l | tr -d ' ')

if [[ $UNSUPPORTED -gt 0 ]]; then
    warn "Found $UNSUPPORTED potentially unsupported claims (Article IV, Section 4.3)"
fi

# =========================================
# Article V Validation: Output Policy
# =========================================
echo ""
echo "--- Article V: Output Policy ---"

# Check for required metadata
REQUIRED_META=("analysis_time\|Analysis Time\|timestamp" "total_files\|Total Files" "scanned_files\|Scanned Files" "project_scale\|Project Scale\|Scale" "constitution_version\|Constitution")

MISSING_META=0
for meta in "${REQUIRED_META[@]}"; do
    if grep -qi "$meta" "$ANALYSIS_FILE"; then
        : # Found
    else
        META_NAME=$(echo "$meta" | cut -d'\' -f1)
        warn "Missing recommended metadata: $META_NAME"
        MISSING_META=$((MISSING_META + 1))
    fi
done

if [[ $MISSING_META -eq 0 ]]; then
    pass "All recommended metadata present"
fi

# Check constitution version reference
if grep -q "constitution" "$ANALYSIS_FILE" || grep -q "Constitution" "$ANALYSIS_FILE"; then
    pass "Constitution reference found"
else
    warn "Consider adding constitution_version to output (Article V, Section 5.2)"
fi

# =========================================
# Summary
# =========================================
echo ""
echo "==========================================="
echo "=== Constitution Validation Summary ==="
echo "==========================================="
echo -e "  ${GREEN}Passed${NC}:   $PASS_COUNT"
echo -e "  ${RED}Failed${NC}:   $FAIL_COUNT"
echo -e "  ${YELLOW}Warnings${NC}: $WARN_COUNT"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}❌ Validation FAILED${NC}"
    echo "   Some outputs violate Constitution principles."
    echo "   Review the failures above and correct the analysis."
    exit 1
elif [[ $WARN_COUNT -gt 3 ]]; then
    echo -e "${YELLOW}⚠️ Validation PASSED with warnings${NC}"
    echo "   Consider addressing the warnings for better compliance."
    exit 0
else
    echo -e "${GREEN}✅ Validation PASSED${NC}"
    echo "   Output complies with Constitution v$CONSTITUTION_VERSION"
    exit 0
fi
