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

# Check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"

    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        print_error "Not a git repository"
        exit 1
    fi
    print_status "Git repository detected"

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
    java -jar "$CODEMAAT_JAR" -l "$GIT_LOG_FILE" -c git2 -a revisions 2>/dev/null \
        | tail -n +2 \
        | sort -t, -k2 -nr \
        | head -20 \
        || echo "# No data available"

    echo ""
}

# Run coupling analysis
run_coupling_analysis() {
    print_section "Temporal Coupling Analysis"

    echo "# COUPLING - Files that change together"
    echo "# Format: entity,coupled,degree,average-revs"
    java -jar "$CODEMAAT_JAR" -l "$GIT_LOG_FILE" -c git2 -a coupling 2>/dev/null \
        | tail -n +2 \
        | awk -F, 'NR>0 && $3 >= 0.3' \
        | sort -t, -k3 -nr \
        | head -20 \
        || echo "# No significant coupling found"

    echo ""
}

# Run author analysis
run_author_analysis() {
    print_section "Recent Contributors Analysis"

    echo "# CONTRIBUTORS - Recent activity by author"
    echo "# Format: entity,author,added,deleted"
    java -jar "$CODEMAAT_JAR" -l "$GIT_LOG_FILE" -c git2 -a entity-ownership 2>/dev/null \
        | tail -n +2 \
        | head -30 \
        || echo "# No data available"

    echo ""
}

# Run summary analysis
run_summary_analysis() {
    print_section "Summary Statistics"

    echo "# SUMMARY - Overview statistics"
    java -jar "$CODEMAAT_JAR" -l "$GIT_LOG_FILE" -c git2 -a summary 2>/dev/null \
        || echo "# No summary available"

    echo ""
}

# Generate knowledge concentration report
run_knowledge_concentration() {
    print_section "Knowledge Concentration (Bus Factor Risk)"

    echo "# KNOWLEDGE CONCENTRATION - Files with single contributor"
    echo "# These files have bus factor risk"

    # Get files with only one author
    java -jar "$CODEMAAT_JAR" -l "$GIT_LOG_FILE" -c git2 -a entity-ownership 2>/dev/null \
        | tail -n +2 \
        | cut -d, -f1 \
        | sort \
        | uniq -c \
        | awk '$1 == 1 {print $2}' \
        | head -10 \
        || echo "# No single-contributor files found"

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
