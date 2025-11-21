#!/bin/bash
# SourceAtlas - Project Type Detection Script
#
# Purpose: Collect raw project metadata for AI analysis
# Philosophy: Scripts collect data, AI does reasoning
#
# Usage: ./detect-project.sh [target_directory]

set -euo pipefail

TARGET_DIR="${1:-.}"

# Color output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

main() {
    echo "=== Project Detection ==="
    echo "Target: $TARGET_DIR"
    echo ""

    detect_project_files
    echo ""

    project_statistics
    echo ""

    detect_ai_indicators
    echo ""

    show_structure
}

detect_project_files() {
    echo "--- Project Files ---"

    # Check for language-specific files
    local files=(
        "package.json"          # Node.js
        "composer.json"         # PHP
        "Gemfile"               # Ruby
        "go.mod"                # Go
        "Cargo.toml"            # Rust
        "requirements.txt"      # Python
        "pyproject.toml"        # Python (modern)
        "pom.xml"               # Java (Maven)
        "build.gradle"          # Java (Gradle)
        "*.csproj"              # C#/.NET
        "mix.exs"               # Elixir
        "pubspec.yaml"          # Dart/Flutter
        "*.xcodeproj"           # iOS/macOS
    )

    for pattern in "${files[@]}"; do
        if find "$TARGET_DIR" -maxdepth 2 -name "$pattern" 2>/dev/null | head -1 | grep -q .; then
            echo "Found: $pattern"
        fi
    done
}

project_statistics() {
    echo "--- Project Statistics ---"

    # Total files
    local total_files=$(find "$TARGET_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "Total files: $total_files"

    # Lines of code by language (top 5)
    echo ""
    echo "Lines of code by extension:"
    find "$TARGET_DIR" -type f 2>/dev/null |
        sed 's/.*\.//' |
        sort |
        uniq -c |
        sort -rn |
        head -10

    # Directory count
    local dir_count=$(find "$TARGET_DIR" -type d 2>/dev/null | wc -l | tr -d ' ')
    echo ""
    echo "Total directories: $dir_count"

    # Git information (if available)
    if [ -d "$TARGET_DIR/.git" ]; then
        echo ""
        echo "Git repository: Yes"
        cd "$TARGET_DIR"
        echo "Total commits: $(git rev-list --all --count 2>/dev/null || echo 'N/A')"
        echo "Branches: $(git branch -a 2>/dev/null | wc -l | tr -d ' ')"
        echo "Last commit: $(git log -1 --format='%ar' 2>/dev/null || echo 'N/A')"
    else
        echo ""
        echo "Git repository: No"
    fi
}

detect_ai_indicators() {
    echo "--- AI Collaboration Indicators ---"

    # Check for AI configuration files
    local ai_files=(
        "CLAUDE.md"
        ".claude/CLAUDE.md"
        ".cursor/rules"
        ".aider.conf.yml"
        ".github/copilot.yml"
    )

    for file in "${ai_files[@]}"; do
        if [ -f "$TARGET_DIR/$file" ] || [ -d "$TARGET_DIR/$file" ]; then
            echo "Found: $file"
        fi
    done

    # Check for high comment density (AI indicator)
    if command -v cloc &> /dev/null; then
        echo ""
        echo "Code metrics (via cloc):"
        cloc "$TARGET_DIR" --quiet 2>/dev/null | grep -E "SUM:|Language" || echo "cloc analysis failed"
    fi
}

show_structure() {
    echo "--- Directory Structure (2 levels) ---"

    # Use tree if available, otherwise fall back to find
    if command -v tree &> /dev/null; then
        tree -L 2 -d --charset ascii "$TARGET_DIR" 2>/dev/null | head -50
    else
        find "$TARGET_DIR" -maxdepth 2 -type d 2>/dev/null |
            grep -v node_modules |
            grep -v .git |
            head -30
    fi
}

# Run main function
main
