#!/bin/bash
# SourceAtlas - High-Entropy File Scanner
#
# Purpose: Identify files with high information value for analysis
# Philosophy: Scripts collect data, AI does reasoning
#
# Information Theory Principle:
#   High-entropy files contain disproportionate project understanding
#   (README, configs, models > implementation details)
#
# Usage: ./scan-entropy.sh [target_directory]

set -euo pipefail

TARGET_DIR="${1:-.}"

main() {
    echo "=== High-Entropy File Scan ==="
    echo "Target: $TARGET_DIR"
    echo ""

    echo "--- Priority 1: Documentation (Highest Entropy) ---"
    scan_documentation
    echo ""

    echo "--- Priority 2: Configuration Files ---"
    scan_configuration
    echo ""

    echo "--- Priority 3: Core Models/Entities (Sample) ---"
    scan_models
    echo ""

    echo "--- Priority 4: Entry Points (Sample) ---"
    scan_entry_points
    echo ""

    echo "--- Priority 5: Test Samples ---"
    scan_tests
    echo ""

    echo "=== Scan Summary ==="
    generate_summary
}

scan_documentation() {
    # Documentation files contain project-level context
    local doc_patterns=(
        "README.md"
        "README.MD"
        "readme.md"
        "CLAUDE.md"
        "CONTRIBUTING.md"
        "ARCHITECTURE.md"
        "DESIGN.md"
        "docs/*.md"
        "documentation/*.md"
    )

    for pattern in "${doc_patterns[@]}"; do
        find "$TARGET_DIR" -maxdepth 3 -path "*/$pattern" -type f 2>/dev/null | while read -r file; do
            local size=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
            echo "📄 $file ($size lines)"
        done
    done

    # Check if no docs found
    if ! find "$TARGET_DIR" -maxdepth 3 -iname "readme*" -type f 2>/dev/null | grep -q .; then
        echo "⚠️  No README found"
    fi
}

scan_configuration() {
    # Configuration files reveal technology stack and architecture decisions
    local config_files=(
        "package.json"
        "composer.json"
        "Gemfile"
        "go.mod"
        "Cargo.toml"
        "requirements.txt"
        "pyproject.toml"
        "pom.xml"
        "build.gradle"
        "tsconfig.json"
        "webpack.config.*"
        "vite.config.*"
        "docker-compose.yml"
        "Dockerfile"
        ".env.example"
        "config/*.yml"
        "config/*.yaml"
        "config/*.json"
    )

    for pattern in "${config_files[@]}"; do
        find "$TARGET_DIR" -maxdepth 3 -path "*/$pattern" -type f 2>/dev/null | head -10 | while read -r file; do
            local size=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
            echo "⚙️  $file ($size lines)"
        done
    done
}

scan_models() {
    # Core data models reveal domain structure
    # Sample only 3-5 models (don't enumerate all)
    echo "Sampling core models (showing first 5):"

    local model_paths=(
        "models/"
        "app/models/"
        "src/models/"
        "lib/models/"
        "domain/entities/"
        "entities/"
    )

    for path in "${model_paths[@]}"; do
        find "$TARGET_DIR" -path "*/$path*" -type f \( -name "*.rb" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" \) 2>/dev/null |
            head -5 | while read -r file; do
            local size=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
            echo "🗂️  $file ($size lines)"
        done
    done
}

scan_entry_points() {
    # Entry points reveal architecture patterns
    # Sample 1-2 examples only
    echo "Sampling entry points (showing first 3):"

    local entry_patterns=(
        "main.*"
        "index.*"
        "app.*"
        "server.*"
        "routes/*"
        "controllers/*"
        "handlers/*"
        "api/*"
    )

    for pattern in "${entry_patterns[@]}"; do
        find "$TARGET_DIR" -path "*/$pattern" -type f 2>/dev/null |
            grep -v node_modules |
            grep -v vendor |
            head -3 | while read -r file; do
            local size=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
            echo "🚪 $file ($size lines)"
        done
    done
}

scan_tests() {
    # Sample test files to understand testing approach
    echo "Sampling test files (showing first 3):"

    find "$TARGET_DIR" -type f \( -name "*test*" -o -name "*spec*" \) 2>/dev/null |
        grep -v node_modules |
        grep -v vendor |
        grep -E "\.(test|spec)\.(js|ts|rb|py|go)$" |
        head -3 | while read -r file; do
        local size=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
        echo "🧪 $file ($size lines)"
    done
}

generate_summary() {
    # Count total files vs scanned files
    local total_files=$(find "$TARGET_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')

    # Estimate scanned files (rough approximation)
    local scanned_count=0
    scanned_count=$((scanned_count + $(find "$TARGET_DIR" -maxdepth 3 -iname "readme*" -type f 2>/dev/null | wc -l | tr -d ' ')))
    scanned_count=$((scanned_count + $(find "$TARGET_DIR" -maxdepth 3 -name "package.json" -o -name "composer.json" 2>/dev/null | wc -l | tr -d ' ')))
    scanned_count=$((scanned_count + 8)) # Assume ~8 models/controllers/tests sampled

    echo "Estimated scan coverage:"
    echo "  Total files: $total_files"
    echo "  Files to scan: ~$scanned_count"

    if [ "$total_files" -gt 0 ]; then
        local scan_ratio=$(awk "BEGIN {printf \"%.1f\", ($scanned_count / $total_files) * 100}")
        echo "  Scan ratio: ~${scan_ratio}%"

        if (( $(echo "$scan_ratio < 5" | bc -l) )); then
            echo "  ✅ Within <5% target"
        else
            echo "  ⚠️  Exceeds 5% - consider reducing scope"
        fi
    fi
}

# Run main function
main
