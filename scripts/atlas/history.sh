#!/bin/bash
# ============================================================================
# history.sh - SourceAtlas Git History Analysis Script
# ============================================================================
#
# Purpose: Generate temporal analysis data using code-maat
# Philosophy: Scripts collect data quickly, AI does deep interpretation
#
# Usage:
#   ./history.sh [scope] [months]
#   ./history.sh                    # Analyze entire repo, last 12 months
#   ./history.sh src/               # Analyze specific directory
#   ./history.sh . 6                # Analyze last 6 months
#
# Output: CSV data for AI interpretation
#
# Requirements:
#   - Java 8+ (for code-maat)
#   - code-maat JAR (run install-codemaat.sh first)
#   - Git repository
#
# ============================================================================

set -euo pipefail

# Configuration
SCOPE="${1:-.}"
MONTHS="${2:-12}"
TEMP_DIR="/tmp/sourceatlas-history"
GIT_LOG_FILE="$TEMP_DIR/git-history.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored message
print_status() {
    echo -e "${GREEN}[✓]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

print_section() {
    echo -e "${CYAN}=== $1 ===${NC}" >&2
}

# Check if running in interactive mode
is_interactive() {
    [[ -t 0 && -t 1 ]]
}

# Ask user for confirmation
ask_user() {
    local prompt="$1"
    local default="${2:-n}"

    if ! is_interactive; then
        # Non-interactive mode, use default
        [[ "$default" == "y" ]]
        return $?
    fi

    local response
    echo -e "${YELLOW}$prompt${NC}" >&2
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Check and handle shallow clone
check_shallow_clone() {
    # Check if this is a shallow repository
    if git rev-parse --is-shallow-repository 2>/dev/null | grep -q "true"; then
        local commit_count
        commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "1")

        echo "" >&2
        print_warning "偵測到 Shallow Clone（淺層克隆）"
        echo "" >&2
        echo -e "${YELLOW}問題說明：${NC}" >&2
        echo "  此倉庫只有 $commit_count 個 commit，無法進行完整的歷史分析。" >&2
        echo "  Hotspot、Coupling、Contributors 分析需要完整的 Git 歷史。" >&2
        echo "" >&2
        echo -e "${CYAN}解決方案：${NC}" >&2
        echo "  執行 'git fetch --unshallow' 下載完整歷史" >&2
        echo "  （這可能需要幾分鐘，取決於倉庫大小）" >&2
        echo "" >&2

        if ask_user "是否要現在下載完整歷史？[y/N] " "n"; then
            echo "" >&2
            print_status "正在下載完整歷史..."
            echo "（大型專案可能需要 2-5 分鐘，請耐心等待）" >&2
            echo "" >&2

            if git fetch --unshallow 2>&1 | while read line; do echo "  $line" >&2; done; then
                print_status "完整歷史下載成功！"
                echo "" >&2
            else
                print_error "下載失敗。請手動執行："
                echo "  git fetch --unshallow" >&2
                echo "" >&2
                echo "然後重新執行此腳本。" >&2
                exit 1
            fi
        else
            echo "" >&2
            print_warning "繼續使用有限的歷史資料（結果可能不完整）"
            echo "" >&2
        fi
    fi
}

# Check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"

    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        print_error "Not a git repository"
        exit 1
    fi
    print_status "Git repository detected"

    # Check for shallow clone
    check_shallow_clone

    # Check Java
    if ! command -v java &> /dev/null; then
        print_error "Java is required but not found"
        echo "Please install Java 8+ first:" >&2
        echo "  macOS:   brew install openjdk@11" >&2
        echo "  Ubuntu:  sudo apt install openjdk-11-jre" >&2
        exit 1
    fi
    print_status "Java found"

    # Check code-maat
    if [ -z "${CODEMAAT_JAR:-}" ]; then
        # Try default location
        if [ -f "$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar" ]; then
            export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
        else
            # Auto-install code-maat if not found
            print_warning "code-maat not found. Installing automatically..."

            # Find the install script
            local script_dir
            script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            local install_script="$script_dir/../install-codemaat.sh"

            if [ -f "$install_script" ]; then
                if bash "$install_script"; then
                    print_status "code-maat installed successfully"
                    export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
                else
                    print_error "Failed to install code-maat automatically"
                    echo "" >&2
                    echo "Please install manually:" >&2
                    echo "  ./scripts/install-codemaat.sh" >&2
                    exit 1
                fi
            else
                print_error "Install script not found at: $install_script"
                echo "" >&2
                echo "Please run from SourceAtlas directory or set CODEMAAT_JAR environment variable" >&2
                exit 1
            fi
        fi
    fi

    # Verify code-maat works
    if ! java -jar "$CODEMAAT_JAR" -h &> /dev/null; then
        print_error "code-maat is not working correctly"
        echo "Please reinstall: ./scripts/install-codemaat.sh --remove && ./scripts/install-codemaat.sh" >&2
        exit 1
    fi
    print_status "code-maat ready at: $CODEMAAT_JAR"

    # Create temp directory
    mkdir -p "$TEMP_DIR"
    print_status "Temp directory ready"
}

# Generate git log in code-maat format
generate_git_log() {
    print_section "Generating Git Log"

    # Calculate date range
    local after_date
    if [[ "$OSTYPE" == "darwin"* ]]; then
        after_date=$(date -v-${MONTHS}m +%Y-%m-%d)
    else
        after_date=$(date -d "${MONTHS} months ago" +%Y-%m-%d)
    fi

    print_status "Analyzing commits since: $after_date"

    # Generate log for code-maat
    if [ "$SCOPE" = "." ]; then
        git log --all --numstat --date=short \
            --pretty=format:'--%h--%ad--%aN' \
            --after="$after_date" \
            > "$GIT_LOG_FILE" 2>/dev/null || true
    else
        git log --all --numstat --date=short \
            --pretty=format:'--%h--%ad--%aN' \
            --after="$after_date" \
            -- "$SCOPE" \
            > "$GIT_LOG_FILE" 2>/dev/null || true
    fi

    # Count commits and files
    local commit_count
    local file_count
    commit_count=$(grep -c "^--" "$GIT_LOG_FILE" 2>/dev/null || echo "0")
    file_count=$(awk 'NF==3 && $1 ~ /^[0-9]+$/' "$GIT_LOG_FILE" 2>/dev/null | cut -f3 | sort -u | wc -l | tr -d ' ')

    print_status "Found: $commit_count commits, $file_count unique files"

    if [ "$commit_count" -lt 10 ]; then
        print_warning "Very few commits found. Consider extending the time range."
    fi

    echo "$commit_count"
}

# Run hotspot analysis (revisions)
run_hotspot_analysis() {
    print_section "Hotspot Analysis (Most Changed Files)"

    echo "# HOTSPOTS - Files with most revisions"
    echo "# Format: entity,n-revs"

    local result
    result=$(java -jar "$CODEMAAT_JAR" -l "$GIT_LOG_FILE" -c git2 -a revisions 2>/dev/null \
        | tail -n +2 \
        | sort -t, -k2 -nr \
        | head -20) || true

    if [ -n "$result" ]; then
        echo "$result"
    else
        echo "# No hotspot data available"
    fi

    echo ""
}

# Run coupling analysis
run_coupling_analysis() {
    print_section "Temporal Coupling Analysis"

    echo "# COUPLING - Files that change together"
    echo "# Format: entity,coupled,degree,average-revs"
    echo "# Threshold: degree >= 30% (files change together at least 30% of the time)"

    local result
    result=$(java -jar "$CODEMAAT_JAR" -l "$GIT_LOG_FILE" -c git2 -a coupling 2>/dev/null \
        | tail -n +2 \
        | awk -F, 'NR>0 && $3 >= 0.3' \
        | sort -t, -k3 -nr \
        | head -20) || true

    if [ -n "$result" ]; then
        echo "$result"
    else
        echo "# No significant coupling found (no file pairs change together >= 30%)"
    fi

    echo ""
}

# Run author analysis
run_author_analysis() {
    print_section "Recent Contributors Analysis"

    echo "# CONTRIBUTORS - Recent activity by author"
    echo "# Format: entity,author,added,deleted"

    local result
    result=$(java -jar "$CODEMAAT_JAR" -l "$GIT_LOG_FILE" -c git2 -a entity-ownership 2>/dev/null \
        | tail -n +2 \
        | head -30) || true

    if [ -n "$result" ]; then
        echo "$result"
    else
        echo "# No contributor data available"
    fi

    echo ""
}

# Run summary analysis
run_summary_analysis() {
    print_section "Summary Statistics"

    echo "# SUMMARY - Overview statistics"

    local result
    result=$(java -jar "$CODEMAAT_JAR" -l "$GIT_LOG_FILE" -c git2 -a summary 2>/dev/null) || true

    if [ -n "$result" ]; then
        echo "$result"
    else
        echo "# No summary available"
    fi

    echo ""
}

# Generate knowledge concentration report
run_knowledge_concentration() {
    print_section "Knowledge Concentration (Bus Factor Risk)"

    echo "# KNOWLEDGE CONCENTRATION - Files with single contributor"
    echo "# These files have bus factor risk (only one person has touched them)"

    # Get files with only one author
    local result
    result=$(java -jar "$CODEMAAT_JAR" -l "$GIT_LOG_FILE" -c git2 -a entity-ownership 2>/dev/null \
        | tail -n +2 \
        | cut -d, -f1 \
        | sort \
        | uniq -c \
        | awk '$1 == 1 {print $2}' \
        | head -10) || true

    if [ -n "$result" ]; then
        echo "$result"
    else
        echo "# Good news: No single-contributor files found (knowledge is distributed)"
    fi

    echo ""
}

# Main
main() {
    local start_time=$(date +%s)

    echo "# ============================================" >&2
    echo "# SourceAtlas Git History Analysis" >&2
    echo "# ============================================" >&2
    echo "" >&2

    # Check prerequisites
    check_prerequisites

    # Get repository info
    local repo_name=$(basename "$(git rev-parse --show-toplevel)")
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

    echo "" >&2
    print_status "Repository: $repo_name"
    print_status "Branch: $current_branch"
    print_status "Scope: $SCOPE"
    print_status "Period: Last $MONTHS months"
    echo "" >&2

    # Generate git log
    local commit_count
    commit_count=$(generate_git_log)

    if [ "$commit_count" -eq 0 ]; then
        print_error "No commits found in the specified period"
        exit 1
    fi

    echo ""

    # Output header
    echo "# ============================================"
    echo "# SOURCEATLAS HISTORY ANALYSIS RESULTS"
    echo "# ============================================"
    echo "# Repository: $repo_name"
    echo "# Branch: $current_branch"
    echo "# Scope: $SCOPE"
    echo "# Period: Last $MONTHS months"
    echo "# Commits: $commit_count"
    echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "# ============================================"
    echo ""

    # Run analyses
    run_hotspot_analysis
    run_coupling_analysis
    run_author_analysis
    run_knowledge_concentration
    run_summary_analysis

    # Cleanup
    rm -f "$GIT_LOG_FILE"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo "" >&2
    print_status "Analysis completed in ${duration}s"
    echo "" >&2
    echo "Tip: Pipe output to a file for AI analysis:" >&2
    echo "  ./scripts/atlas/history.sh > analysis.csv" >&2
}

# Run main
main "$@"
