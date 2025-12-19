#!/bin/bash
# detect-ai-tools.sh - Detect AI coding tool configurations in a project
# Part of SourceAtlas v2.9.4
#
# Usage: detect-ai-tools.sh [path]
#
# Output: JSON-like structured output for AI collaboration level detection

set -uo pipefail
# Note: Not using -e because check_tool returns 1 when tool not found (expected behavior)

TARGET_PATH="${1:-.}"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Change to target directory
cd "$TARGET_PATH" 2>/dev/null || {
    echo "Error: Cannot access directory: $TARGET_PATH" >&2
    exit 1
}

echo "═══════════════════════════════════════════════════════════════"
echo "  SourceAtlas AI Tool Detection v2.9.4"
echo "  Target: $(pwd)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Initialize counters
TIER1_COUNT=0
TIER2_SCORE=0
TOOLS_FOUND=()

# ═══════════════════════════════════════════════════════════════════════════════
# TIER 1: High-Confidence Indicators (Tool-Specific Config Files)
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}▶ TIER 1: Tool-Specific Configuration Files${NC}"
echo "───────────────────────────────────────────────────────────────"

# Function to check file/directory existence and report
check_tool() {
    local tool_name="$1"
    local confidence="$2"
    shift 2
    local files=("$@")
    local found=0
    local found_files=()

    for file in "${files[@]}"; do
        if [[ -e "$file" ]]; then
            found=1
            found_files+=("$file")
        fi
    done

    if [[ $found -eq 1 ]]; then
        echo -e "  ${GREEN}✓${NC} ${tool_name} (${confidence})"
        for f in "${found_files[@]}"; do
            # Get file info
            if [[ -d "$f" ]]; then
                local count=$(find "$f" -type f 2>/dev/null | wc -l | tr -d ' ')
                echo -e "    └─ ${f}/ (${count} files)"
            else
                local lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
                echo -e "    └─ ${f} (${lines} lines)"
            fi
        done
        TIER1_COUNT=$((TIER1_COUNT + 1))
        TOOLS_FOUND+=("$tool_name")
        return 0
    else
        echo -e "  ${RED}✗${NC} ${tool_name}"
        return 1
    fi
}

# Check each tool
check_tool "Claude Code" "+0.30" "CLAUDE.md" ".claude"
check_tool "Cursor (legacy)" "+0.25" ".cursorrules"
check_tool "Cursor (new)" "+0.25" ".cursor/rules"
check_tool "Windsurf (legacy)" "+0.25" ".windsurfrules"
check_tool "Windsurf (new)" "+0.25" ".windsurf/rules"
check_tool "GitHub Copilot" "+0.20" ".github/copilot-instructions.md"
check_tool "Cline" "+0.25" ".clinerules"
check_tool "Cline (dir)" "+0.25" ".clinerules"
check_tool "Roo" "+0.25" ".roo"
check_tool "Aider" "+0.25" "CONVENTIONS.md" ".aider.conf.yml" ".aider.input.history"
check_tool "Continue.dev (legacy)" "+0.25" ".continuerules"
check_tool "Continue.dev (new)" "+0.25" ".continue/rules"
check_tool "JetBrains AI" "+0.20" ".aiignore"
check_tool "AGENTS.md (standard)" "+0.20" "AGENTS.md"
check_tool "Sourcegraph Cody" "+0.15" ".vscode/cody.json"
check_tool "Replit" "+0.15" "replit.nix" ".replit"
check_tool "Ruler (multi-tool)" "+0.20" ".ruler"

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# TIER 2: Indirect Indicators
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}▶ TIER 2: Indirect Indicators${NC}"
echo "───────────────────────────────────────────────────────────────"

# Check for Conventional Commits (last 20 commits)
if git rev-parse --git-dir > /dev/null 2>&1; then
    TOTAL_COMMITS=$(git log --oneline -20 2>/dev/null | wc -l | tr -d ' ')
    if [[ $TOTAL_COMMITS -gt 0 ]]; then
        # Conventional commit pattern: type(scope): or type:
        CONVENTIONAL_COMMITS=$(git log --oneline -20 2>/dev/null | grep -cE "^[a-f0-9]+ (feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\([^)]+\))?:" || true)
        COMMIT_RATIO=$((CONVENTIONAL_COMMITS * 100 / TOTAL_COMMITS))

        if [[ $COMMIT_RATIO -ge 80 ]]; then
            echo -e "  ${GREEN}✓${NC} Conventional Commits: ${COMMIT_RATIO}% (${CONVENTIONAL_COMMITS}/${TOTAL_COMMITS})"
            TIER2_SCORE=$((TIER2_SCORE + 1))
        else
            echo -e "  ${YELLOW}△${NC} Conventional Commits: ${COMMIT_RATIO}% (${CONVENTIONAL_COMMITS}/${TOTAL_COMMITS})"
        fi
    else
        echo -e "  ${RED}✗${NC} Conventional Commits: No commits found"
    fi
else
    echo -e "  ${RED}✗${NC} Conventional Commits: Not a git repository"
fi

# Check documentation richness (docs-to-code ratio)
# Exclude common test/example directories
MD_FILES=$(find . -name "*.md" \
    -not -path "*/node_modules/*" \
    -not -path "*/.venv/*" \
    -not -path "*/vendor/*" \
    -not -path "*/test_targets/*" \
    -not -path "*/examples/*" \
    -not -path "*/.git/*" \
    2>/dev/null | wc -l | tr -d ' ')
CODE_FILES=$(find . \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.swift" -o -name "*.kt" -o -name "*.java" -o -name "*.go" -o -name "*.rs" -o -name "*.sh" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.venv/*" \
    -not -path "*/vendor/*" \
    -not -path "*/test_targets/*" \
    -not -path "*/examples/*" \
    -not -path "*/.git/*" \
    2>/dev/null | wc -l | tr -d ' ')

if [[ $CODE_FILES -gt 0 ]]; then
    DOC_RATIO=$(echo "scale=2; $MD_FILES / $CODE_FILES" | bc 2>/dev/null || echo "0")
    if (( $(echo "$DOC_RATIO >= 0.5" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "  ${GREEN}✓${NC} Docs-to-Code Ratio: ${DOC_RATIO} (${MD_FILES} md / ${CODE_FILES} code files)"
        TIER2_SCORE=$((TIER2_SCORE + 1))
    else
        echo -e "  ${YELLOW}△${NC} Docs-to-Code Ratio: ${DOC_RATIO} (${MD_FILES} md / ${CODE_FILES} code files)"
    fi
else
    echo -e "  ${YELLOW}△${NC} Docs-to-Code Ratio: No code files found"
fi

# Check for comprehensive README
if [[ -f "README.md" ]]; then
    README_LINES=$(wc -l < "README.md" | tr -d ' ')
    if [[ $README_LINES -ge 100 ]]; then
        echo -e "  ${GREEN}✓${NC} README.md: ${README_LINES} lines (comprehensive)"
        TIER2_SCORE=$((TIER2_SCORE + 1))
    else
        echo -e "  ${YELLOW}△${NC} README.md: ${README_LINES} lines"
    fi
else
    echo -e "  ${RED}✗${NC} README.md: Not found"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# AI COLLABORATION LEVEL ASSESSMENT
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}▶ AI COLLABORATION LEVEL ASSESSMENT${NC}"
echo "───────────────────────────────────────────────────────────────"

# Check for comprehensive AI config (CLAUDE.md with significant content)
COMPREHENSIVE_CONFIG=0
if [[ -f "CLAUDE.md" ]]; then
    CLAUDE_LINES=$(wc -l < "CLAUDE.md" | tr -d ' ')
    if [[ $CLAUDE_LINES -ge 100 ]]; then
        COMPREHENSIVE_CONFIG=1
    fi
fi
if [[ -f ".cursorrules" ]]; then
    CURSOR_LINES=$(wc -l < ".cursorrules" | tr -d ' ')
    if [[ $CURSOR_LINES -ge 50 ]]; then
        COMPREHENSIVE_CONFIG=1
    fi
fi

# Calculate level based on findings
LEVEL=0
CONFIDENCE="0.5"

if [[ $TIER1_COUNT -eq 0 && $TIER2_SCORE -eq 0 ]]; then
    LEVEL=0
    CONFIDENCE="0.9"
    DESCRIPTION="No AI - Traditional development"
elif [[ $TIER1_COUNT -eq 1 && $TIER2_SCORE -eq 0 && $COMPREHENSIVE_CONFIG -eq 0 ]]; then
    LEVEL=1
    CONFIDENCE="0.7"
    DESCRIPTION="Occasional use - Single tool, minimal integration"
elif [[ $TIER1_COUNT -ge 1 && $TIER2_SCORE -ge 1 && $COMPREHENSIVE_CONFIG -eq 0 ]]; then
    LEVEL=2
    CONFIDENCE="0.75"
    DESCRIPTION="Frequent use - Active AI assistance"
elif [[ $COMPREHENSIVE_CONFIG -eq 1 || ($TIER1_COUNT -ge 2 && $TIER2_SCORE -ge 2) ]]; then
    LEVEL=3
    CONFIDENCE="0.85"
    DESCRIPTION="Systematic collaboration - Comprehensive AI config or multi-tool"
fi

# Check for Level 4 indicators
if [[ -d ".ruler" ]] || [[ -f "AGENTS.md" && $TIER1_COUNT -ge 2 ]]; then
    LEVEL=4
    CONFIDENCE="0.9"
    DESCRIPTION="Ecosystem-level - Multi-tool or standardized AI integration"
fi

# Output level with color
case $LEVEL in
    0) LEVEL_COLOR="${RED}" ;;
    1) LEVEL_COLOR="${YELLOW}" ;;
    2) LEVEL_COLOR="${YELLOW}" ;;
    3) LEVEL_COLOR="${GREEN}" ;;
    4) LEVEL_COLOR="${CYAN}" ;;
esac

echo -e "  Level: ${LEVEL_COLOR}${LEVEL}${NC} (${DESCRIPTION})"
echo -e "  Confidence: ${CONFIDENCE}"
echo -e "  Tier 1 Tools Found: ${TIER1_COUNT}"
echo -e "  Tier 2 Score: ${TIER2_SCORE}/3"

if [[ ${#TOOLS_FOUND[@]} -gt 0 ]]; then
    echo -e "  Tools Detected: ${TOOLS_FOUND[*]}"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# YAML OUTPUT (for programmatic use)
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}▶ YAML OUTPUT${NC}"
echo "───────────────────────────────────────────────────────────────"
echo "ai_collaboration:"
echo "  level: $LEVEL"
echo "  confidence: $CONFIDENCE"
echo "  description: \"$DESCRIPTION\""
echo "  tier1_tools_count: $TIER1_COUNT"
echo "  tier2_score: $TIER2_SCORE"
if [[ ${#TOOLS_FOUND[@]} -gt 0 ]]; then
    echo "  tools_detected:"
    for tool in "${TOOLS_FOUND[@]}"; do
        echo "    - \"$tool\""
    done
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
