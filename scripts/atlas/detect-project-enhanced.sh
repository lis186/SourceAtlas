#!/bin/bash
# Enhanced Project Detection with Scale-Aware Analysis
# Based on Phase 2 testing results (2025-11-22)

set -e

PROJECT_PATH="${1:-.}"

echo "=== Enhanced Project Detection ==="
echo "📁 Project: $PROJECT_PATH"
echo ""

# Detect project type
echo "🔍 Project Type Detection:"
if [ -f "$PROJECT_PATH/package.json" ]; then
    echo "   ✓ Node.js/TypeScript (package.json found)"
    PROJECT_TYPE="nodejs"
elif [ -f "$PROJECT_PATH/go.mod" ]; then
    echo "   ✓ Go (go.mod found)"
    PROJECT_TYPE="go"
elif [ -f "$PROJECT_PATH/pyproject.toml" ] || [ -f "$PROJECT_PATH/requirements.txt" ]; then
    echo "   ✓ Python (pyproject.toml or requirements.txt found)"
    PROJECT_TYPE="python"
elif [ -f "$PROJECT_PATH/Cargo.toml" ]; then
    echo "   ✓ Rust (Cargo.toml found)"
    PROJECT_TYPE="rust"
elif [ -f "$PROJECT_PATH/composer.json" ]; then
    echo "   ✓ PHP (composer.json found)"
    PROJECT_TYPE="php"
elif [ -f "$PROJECT_PATH/build.gradle" ] || [ -f "$PROJECT_PATH/build.gradle.kts" ] || [ -f "$PROJECT_PATH/settings.gradle" ] || [ -f "$PROJECT_PATH/settings.gradle.kts" ]; then
    echo "   ✓ Android/Kotlin (Gradle project found)"
    PROJECT_TYPE="android"
elif ls "$PROJECT_PATH"/*.xcodeproj 1>/dev/null 2>&1 || ls "$PROJECT_PATH"/*.xcworkspace 1>/dev/null 2>&1; then
    echo "   ✓ iOS/Swift (Xcode project found)"
    PROJECT_TYPE="ios"
elif [ -f "$PROJECT_PATH/Package.swift" ]; then
    echo "   ✓ Swift Package (Package.swift found)"
    PROJECT_TYPE="swift"
else
    echo "   ? Unknown project type"
    PROJECT_TYPE="unknown"
fi

echo ""

# Count actual code files (excluding .venv, node_modules, etc.)
echo "📊 Code File Statistics:"

case "$PROJECT_TYPE" in
    nodejs)
        TOTAL_FILES=$(find "$PROJECT_PATH" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
            ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" ! -path "*/build/*" | wc -l | tr -d ' ')
        echo "   TypeScript/JavaScript files: $TOTAL_FILES"
        ;;
    go)
        TOTAL_FILES=$(find "$PROJECT_PATH" -type f -name "*.go" \
            ! -path "*/vendor/*" ! -path "*/.git/*" ! -path "*/third-party/*" | wc -l | tr -d ' ')
        echo "   Go files: $TOTAL_FILES"
        ;;
    python)
        TOTAL_FILES=$(find "$PROJECT_PATH" -type f -name "*.py" \
            ! -path "*/.venv/*" ! -path "*/venv/*" ! -path "*/__pycache__/*" ! -path "*/.git/*" | wc -l | tr -d ' ')
        echo "   Python files: $TOTAL_FILES"
        ;;
    rust)
        TOTAL_FILES=$(find "$PROJECT_PATH" -type f -name "*.rs" \
            ! -path "*/target/*" ! -path "*/.git/*" | wc -l | tr -d ' ')
        echo "   Rust files: $TOTAL_FILES"
        ;;
    php)
        TOTAL_FILES=$(find "$PROJECT_PATH" -type f -name "*.php" \
            ! -path "*/vendor/*" ! -path "*/.git/*" | wc -l | tr -d ' ')
        echo "   PHP files: $TOTAL_FILES"
        ;;
    android)
        KOTLIN_FILES=$(find "$PROJECT_PATH" -type f -name "*.kt" \
            ! -path "*/build/*" ! -path "*/.gradle/*" ! -path "*/.git/*" | wc -l | tr -d ' ')
        JAVA_FILES=$(find "$PROJECT_PATH" -type f -name "*.java" \
            ! -path "*/build/*" ! -path "*/.gradle/*" ! -path "*/.git/*" | wc -l | tr -d ' ')
        TOTAL_FILES=$((KOTLIN_FILES + JAVA_FILES))
        echo "   Kotlin files: $KOTLIN_FILES"
        echo "   Java files: $JAVA_FILES"
        ;;
    ios|swift)
        SWIFT_FILES=$(find "$PROJECT_PATH" -type f -name "*.swift" \
            ! -path "*/Pods/*" ! -path "*/.build/*" ! -path "*/.git/*" ! -path "*/DerivedData/*" | wc -l | tr -d ' ')
        OBJC_FILES=$(find "$PROJECT_PATH" -type f \( -name "*.m" -o -name "*.h" \) \
            ! -path "*/Pods/*" ! -path "*/.git/*" ! -path "*/DerivedData/*" | wc -l | tr -d ' ')
        TOTAL_FILES=$((SWIFT_FILES + OBJC_FILES))
        echo "   Swift files: $SWIFT_FILES"
        echo "   Objective-C files: $OBJC_FILES"
        ;;
    *)
        TOTAL_FILES=$(find "$PROJECT_PATH" -type f \
            ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.venv/*" \
            ! -path "*/vendor/*" ! -path "*/target/*" ! -path "*/dist/*" \
            ! -path "*/build/*" ! -path "*/__pycache__/*" | wc -l | tr -d ' ')
        echo "   Total files: $TOTAL_FILES"
        ;;
esac

echo ""

# Determine scale based on file count and estimate LOC
if [ "$TOTAL_FILES" -lt 5 ]; then
    SCALE="TINY"
    RECOMMENDED_SCANS="1-2"
    HYPOTHESIS_TARGET="5-8"
elif [ "$TOTAL_FILES" -lt 15 ]; then
    SCALE="SMALL"
    RECOMMENDED_SCANS="2-3"
    HYPOTHESIS_TARGET="7-10"
elif [ "$TOTAL_FILES" -lt 50 ]; then
    SCALE="MEDIUM"
    RECOMMENDED_SCANS="4-6"
    HYPOTHESIS_TARGET="10-15"
elif [ "$TOTAL_FILES" -lt 150 ]; then
    SCALE="LARGE"
    RECOMMENDED_SCANS="6-10"
    HYPOTHESIS_TARGET="12-18"
else
    SCALE="VERY_LARGE"
    RECOMMENDED_SCANS="10-15"
    HYPOTHESIS_TARGET="15-20"
fi

echo "📏 Project Scale: $SCALE"
echo "   Total code files: $TOTAL_FILES"
echo ""

echo "🎯 Recommended Scan Strategy:"
echo "   Files to scan: $RECOMMENDED_SCANS files (to stay <10% of $TOTAL_FILES files)"
echo "   Hypothesis target: $HYPOTHESIS_TARGET hypotheses"
echo ""

echo "✅ Detection Complete"
