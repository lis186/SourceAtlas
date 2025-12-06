#!/bin/bash
# Enhanced Project Detection with Scale-Aware Analysis
# Based on ANALYSIS_CONSTITUTION.md v1.0
# Updated: 2025-12-05 - Added methodology/documentation project support
# Updated: 2025-12-05 - Added monorepo detection (workspaces, lerna, pnpm, nx)

set -e

PROJECT_PATH="${1:-.}"

echo "=== Enhanced Project Detection ==="
echo "📁 Project: $PROJECT_PATH"
echo "📜 Constitution: v1.0"
echo ""

# Detect project type (order matters - more specific first)
echo "🔍 Project Type Detection:"

# Check for methodology/documentation projects first
# These are primarily Markdown + scripts, with minimal code
MD_COUNT=$(find "$PROJECT_PATH" -maxdepth 3 -type f -name "*.md" ! -path "*/.git/*" 2>/dev/null | wc -l | tr -d ' ')
SH_COUNT=$(find "$PROJECT_PATH" -maxdepth 3 -type f \( -name "*.sh" -o -name "*.ps1" \) ! -path "*/.git/*" 2>/dev/null | wc -l | tr -d ' ')
CODE_COUNT=$(find "$PROJECT_PATH" -maxdepth 3 -type f \( -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.swift" -o -name "*.kt" -o -name "*.java" -o -name "*.php" \) ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.venv/*" ! -path "*/vendor/*" 2>/dev/null | wc -l | tr -d ' ')

# Helper function: Check for monorepo markers
check_monorepo() {
    local path="$1"

    # Check for explicit monorepo config files
    if [ -f "$path/lerna.json" ]; then
        echo "lerna"
        return 0
    fi
    if [ -f "$path/pnpm-workspace.yaml" ]; then
        echo "pnpm"
        return 0
    fi
    if [ -f "$path/nx.json" ]; then
        echo "nx"
        return 0
    fi
    if [ -f "$path/turbo.json" ]; then
        echo "turborepo"
        return 0
    fi

    # Check for workspaces in package.json
    if [ -f "$path/package.json" ]; then
        if grep -q '"workspaces"' "$path/package.json" 2>/dev/null; then
            echo "npm-workspaces"
            return 0
        fi
    fi

    # Check for Go workspace
    if [ -f "$path/go.work" ]; then
        echo "go-workspace"
        return 0
    fi

    return 1
}

# Helper function: Detect type from subdirectories (for monorepo)
detect_from_subdirs() {
    local path="$1"
    local found_type=""

    # Check immediate subdirectories for config files
    for subdir in "$path"/*/; do
        [ -d "$subdir" ] || continue
        subdir_name=$(basename "$subdir")

        # Skip common non-package directories
        [[ "$subdir_name" =~ ^(node_modules|\.git|\.venv|vendor|build|dist|target)$ ]] && continue

        if [ -f "$subdir/package.json" ]; then
            found_type="nodejs"
            break
        elif [ -f "$subdir/go.mod" ]; then
            found_type="go"
            break
        elif [ -f "$subdir/pyproject.toml" ] || [ -f "$subdir/setup.py" ]; then
            found_type="python"
            break
        elif [ -f "$subdir/Cargo.toml" ]; then
            found_type="rust"
            break
        fi
    done

    echo "$found_type"
}

# Methodology project: Markdown > Code, and has shell scripts
if [ "$MD_COUNT" -gt 10 ] && [ "$MD_COUNT" -gt "$CODE_COUNT" ] && [ "$SH_COUNT" -gt 0 ]; then
    echo "   ✓ Methodology/Documentation Project (Markdown-driven)"
    echo "     (Markdown: $MD_COUNT, Scripts: $SH_COUNT, Code: $CODE_COUNT)"
    PROJECT_TYPE="methodology"
# Check for monorepo first (before single-package detection)
elif MONOREPO_TYPE=$(check_monorepo "$PROJECT_PATH"); then
    echo "   ✓ Monorepo ($MONOREPO_TYPE)"
    PROJECT_TYPE="monorepo"
    MONOREPO_TOOL="$MONOREPO_TYPE"

    # Try to detect primary language from packages
    SUBDIR_TYPE=$(detect_from_subdirs "$PROJECT_PATH")
    if [ -n "$SUBDIR_TYPE" ]; then
        echo "     Primary package type: $SUBDIR_TYPE"
        MONOREPO_PRIMARY="$SUBDIR_TYPE"
    fi
elif [ -f "$PROJECT_PATH/package.json" ]; then
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
    # Last resort: check subdirectories for config files
    SUBDIR_TYPE=$(detect_from_subdirs "$PROJECT_PATH")
    if [ -n "$SUBDIR_TYPE" ]; then
        echo "   ✓ $SUBDIR_TYPE (detected from subdirectory)"
        echo "     Note: Config file in subdirectory, may be monorepo without explicit config"
        PROJECT_TYPE="$SUBDIR_TYPE"
        IS_IMPLICIT_MONOREPO="true"
    else
        echo "   ? Unknown project type"
        PROJECT_TYPE="unknown"
    fi
fi

echo ""

# Count actual content files (excluding .venv, node_modules, etc.)
# Per Constitution Article II: Forced exclusion directories
echo "📊 Content File Statistics:"

case "$PROJECT_TYPE" in
    methodology)
        # Methodology projects: count Markdown, Shell, Python CLI, YAML/JSON configs
        MD_FILES=$(find "$PROJECT_PATH" -type f -name "*.md" \
            ! -path "*/.git/*" | wc -l | tr -d ' ')
        SCRIPT_FILES=$(find "$PROJECT_PATH" -type f \( -name "*.sh" -o -name "*.ps1" \) \
            ! -path "*/.git/*" | wc -l | tr -d ' ')
        PY_FILES=$(find "$PROJECT_PATH" -type f -name "*.py" \
            ! -path "*/.venv/*" ! -path "*/venv/*" ! -path "*/__pycache__/*" ! -path "*/.git/*" | wc -l | tr -d ' ')
        CONFIG_FILES=$(find "$PROJECT_PATH" -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.toml" \) \
            ! -path "*/.git/*" ! -path "*/node_modules/*" | wc -l | tr -d ' ')
        TOTAL_FILES=$((MD_FILES + SCRIPT_FILES + PY_FILES + CONFIG_FILES))
        echo "   Markdown files: $MD_FILES"
        echo "   Script files (sh/ps1): $SCRIPT_FILES"
        echo "   Python files: $PY_FILES"
        echo "   Config files (yaml/json/toml): $CONFIG_FILES"
        ;;
    monorepo)
        # Monorepo: count based on primary type, or all code files
        if [ "$MONOREPO_PRIMARY" = "nodejs" ]; then
            TOTAL_FILES=$(find "$PROJECT_PATH" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
                ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" ! -path "*/build/*" | wc -l | tr -d ' ')
            echo "   TypeScript/JavaScript files: $TOTAL_FILES"
        elif [ "$MONOREPO_PRIMARY" = "go" ]; then
            TOTAL_FILES=$(find "$PROJECT_PATH" -type f -name "*.go" \
                ! -path "*/vendor/*" ! -path "*/.git/*" | wc -l | tr -d ' ')
            echo "   Go files: $TOTAL_FILES"
        elif [ "$MONOREPO_PRIMARY" = "python" ]; then
            TOTAL_FILES=$(find "$PROJECT_PATH" -type f -name "*.py" \
                ! -path "*/.venv/*" ! -path "*/venv/*" ! -path "*/__pycache__/*" ! -path "*/.git/*" | wc -l | tr -d ' ')
            echo "   Python files: $TOTAL_FILES"
        elif [ "$MONOREPO_PRIMARY" = "rust" ]; then
            TOTAL_FILES=$(find "$PROJECT_PATH" -type f -name "*.rs" \
                ! -path "*/target/*" ! -path "*/.git/*" | wc -l | tr -d ' ')
            echo "   Rust files: $TOTAL_FILES"
        else
            # Mixed or unknown: count all code files
            TOTAL_FILES=$(find "$PROJECT_PATH" -type f \( \
                -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
                -o -name "*.py" -o -name "*.go" -o -name "*.rs" \
                \) ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.venv/*" \
                ! -path "*/vendor/*" ! -path "*/target/*" ! -path "*/dist/*" ! -path "*/build/*" | wc -l | tr -d ' ')
            echo "   Total code files (mixed): $TOTAL_FILES"
        fi
        # Count packages
        PKG_COUNT=$(find "$PROJECT_PATH" -maxdepth 2 -name "package.json" -o -name "go.mod" -o -name "Cargo.toml" -o -name "pyproject.toml" 2>/dev/null | wc -l | tr -d ' ')
        echo "   Packages detected: $PKG_COUNT"
        ;;
    nodejs)
        TOTAL_FILES=$(find "$PROJECT_PATH" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
            ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" ! -path "*/build/*" ! -path "*/.next/*" ! -path "*/.nuxt/*" | wc -l | tr -d ' ')
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
        # Fallback: count all content files
        TOTAL_FILES=$(find "$PROJECT_PATH" -type f \( \
            -name "*.md" -o -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
            -o -name "*.go" -o -name "*.rs" -o -name "*.php" -o -name "*.swift" -o -name "*.kt" -o -name "*.java" \
            -o -name "*.sh" -o -name "*.ps1" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.toml" \
            \) ! -path "*/.git/*" ! -path "*/node_modules/*" ! -path "*/.venv/*" \
            ! -path "*/vendor/*" ! -path "*/target/*" ! -path "*/dist/*" \
            ! -path "*/build/*" ! -path "*/__pycache__/*" ! -path "*/Pods/*" \
            ! -path "*/.next/*" ! -path "*/.nuxt/*" ! -path "*/DerivedData/*" | wc -l | tr -d ' ')
        echo "   Total content files: $TOTAL_FILES"
        ;;
esac

echo ""

# Determine scale based on file count
# Per Constitution Article VI: Scale-Aware Policy
if [ "$TOTAL_FILES" -lt 20 ]; then
    SCALE="TINY"
    MAX_SCAN_RATIO="50%"
    MAX_SCAN_FILES="10"
    LOW_CONFIDENCE_LIMIT="2"
    HYPOTHESIS_TARGET="5-8"
elif [ "$TOTAL_FILES" -lt 50 ]; then
    SCALE="SMALL"
    MAX_SCAN_RATIO="20%"
    MAX_SCAN_FILES="10"
    LOW_CONFIDENCE_LIMIT="3"
    HYPOTHESIS_TARGET="7-10"
elif [ "$TOTAL_FILES" -lt 150 ]; then
    SCALE="MEDIUM"
    MAX_SCAN_RATIO="10%"
    MAX_SCAN_FILES="15"
    LOW_CONFIDENCE_LIMIT="4"
    HYPOTHESIS_TARGET="10-15"
elif [ "$TOTAL_FILES" -lt 500 ]; then
    SCALE="LARGE"
    MAX_SCAN_RATIO="5%"
    MAX_SCAN_FILES="25"
    LOW_CONFIDENCE_LIMIT="5"
    HYPOTHESIS_TARGET="12-18"
else
    SCALE="VERY_LARGE"
    MAX_SCAN_RATIO="3%"
    MAX_SCAN_FILES="30"
    LOW_CONFIDENCE_LIMIT="6"
    HYPOTHESIS_TARGET="15-20"
fi

# Calculate recommended scan count
RECOMMENDED_SCAN_COUNT=$((TOTAL_FILES * ${MAX_SCAN_RATIO%\%} / 100))
if [ "$RECOMMENDED_SCAN_COUNT" -gt "$MAX_SCAN_FILES" ]; then
    RECOMMENDED_SCAN_COUNT="$MAX_SCAN_FILES"
fi
if [ "$RECOMMENDED_SCAN_COUNT" -lt 1 ]; then
    RECOMMENDED_SCAN_COUNT="1"
fi

echo "📏 Project Scale: $SCALE"
echo "   Total content files: $TOTAL_FILES"
echo ""

echo "🎯 Recommended Scan Strategy (per Constitution Article I & VI):"
echo "   Max scan ratio: $MAX_SCAN_RATIO (up to $MAX_SCAN_FILES files)"
echo "   Recommended scan count: ~$RECOMMENDED_SCAN_COUNT files"
echo "   Hypothesis target: $HYPOTHESIS_TARGET"
echo "   Low-confidence hypothesis limit: $LOW_CONFIDENCE_LIMIT"
echo ""

# Branch-Aware Context Detection (spec-kit inspired)
echo "🌿 Context Detection:"

# Detect current Git branch
if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

    if [ -n "$GIT_BRANCH" ]; then
        echo "   Git branch: $GIT_BRANCH"
    fi

    # Detect relative position in repo (for monorepo awareness)
    CURRENT_ABS=$(cd "$PROJECT_PATH" && pwd)
    if [ -n "$GIT_ROOT" ] && [ "$CURRENT_ABS" != "$GIT_ROOT" ]; then
        REL_PATH="${CURRENT_ABS#$GIT_ROOT/}"
        echo "   Relative path: $REL_PATH"
        CONTEXT_PATH="$REL_PATH"
    else
        CONTEXT_PATH=""
    fi
else
    echo "   Git: Not a git repository"
    GIT_BRANCH=""
    CONTEXT_PATH=""
fi

# Detect package context (for monorepo subdirectories)
PACKAGE_NAME=""
if [ -f "$PROJECT_PATH/package.json" ]; then
    PACKAGE_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJECT_PATH/package.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    if [ -n "$PACKAGE_NAME" ]; then
        echo "   Package name: $PACKAGE_NAME"
    fi
elif [ -f "$PROJECT_PATH/Cargo.toml" ]; then
    PACKAGE_NAME=$(grep -E '^\s*name\s*=' "$PROJECT_PATH/Cargo.toml" 2>/dev/null | head -1 | sed 's/.*= *"\([^"]*\)".*/\1/')
    if [ -n "$PACKAGE_NAME" ]; then
        echo "   Crate name: $PACKAGE_NAME"
    fi
elif [ -f "$PROJECT_PATH/go.mod" ]; then
    PACKAGE_NAME=$(grep -E '^module ' "$PROJECT_PATH/go.mod" 2>/dev/null | head -1 | sed 's/module //')
    if [ -n "$PACKAGE_NAME" ]; then
        echo "   Module name: $PACKAGE_NAME"
    fi
elif [ -f "$PROJECT_PATH/pyproject.toml" ]; then
    PACKAGE_NAME=$(grep -E '^\s*name\s*=' "$PROJECT_PATH/pyproject.toml" 2>/dev/null | head -1 | sed 's/.*= *"\([^"]*\)".*/\1/')
    if [ -n "$PACKAGE_NAME" ]; then
        echo "   Package name: $PACKAGE_NAME"
    fi
fi

# Generate context-aware output path suggestion
echo ""
echo "📂 Suggested Output Path:"
if [ -n "$CONTEXT_PATH" ]; then
    # In subdirectory of repo
    SAFE_CONTEXT=$(echo "$CONTEXT_PATH" | tr '/' '-')
    OUTPUT_PATH=".sourceatlas/$SAFE_CONTEXT"
    echo "   $OUTPUT_PATH/"
    echo "   (Context: analyzing subdirectory '$CONTEXT_PATH')"
elif [ -n "$GIT_BRANCH" ] && [ "$GIT_BRANCH" != "main" ] && [ "$GIT_BRANCH" != "master" ]; then
    # On feature branch
    SAFE_BRANCH=$(echo "$GIT_BRANCH" | tr '/' '-')
    OUTPUT_PATH=".sourceatlas/$SAFE_BRANCH"
    echo "   $OUTPUT_PATH/"
    echo "   (Context: analyzing on branch '$GIT_BRANCH')"
else
    # Default: root analysis
    OUTPUT_PATH=".sourceatlas"
    echo "   $OUTPUT_PATH/"
    echo "   (Context: root project analysis)"
fi

echo ""
echo "✅ Detection Complete"
