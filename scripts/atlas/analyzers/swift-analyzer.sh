#!/bin/bash
# Swift/Objective-C Interop Deep Analyzer
# 用於 /atlas.impact 命令，提供 Swift 特定的深度分析

set -euo pipefail

# 顏色定義
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 參數
TARGET_FILE="${1:-}"
PROJECT_ROOT="${2:-.}"

if [ -z "$TARGET_FILE" ]; then
    echo "Usage: $0 <target_file> [project_root]"
    echo "Example: $0 NYProductCell.m /path/to/project"
    exit 1
fi

echo -e "${BLUE}=== Swift/Objective-C Deep Analysis ===${NC}\n"

# ==========================================
# 1. Nullability Annotations Check
# ==========================================
echo -e "${YELLOW}## 1. Nullability Annotations Coverage${NC}\n"

analyze_nullability() {
    local total_headers=0
    local missing_nullability=0
    local missing_files=()

    # 找出所有 .h 檔案
    while IFS= read -r header; do
        ((total_headers++))

        # 檢查是否有 NS_ASSUME_NONNULL
        if ! grep -q "NS_ASSUME_NONNULL" "$header"; then
            ((missing_nullability++))
            missing_files+=("$header")
        fi
    done < <(find "$PROJECT_ROOT" -name "*.h" -not -path "*/Pods/*" -not -path "*/build/*" -not -path "*/.build/*")

    if [ $total_headers -eq 0 ]; then
        echo "ℹ️  No Objective-C header files found (Pure Swift project?)"
        return
    fi

    local coverage_pct=$((100 - (missing_nullability * 100 / total_headers)))

    echo "**Coverage**: $coverage_pct% ($((total_headers - missing_nullability))/$total_headers files)"

    if [ $missing_nullability -gt 0 ]; then
        echo -e "\n🔴 **CRITICAL**: $missing_nullability header files missing nullability annotations\n"
        echo "**Risk**: All properties become implicitly unwrapped optionals (\`!\`) in Swift, causing runtime crashes"
        echo ""
        echo "**Missing annotations**:"

        # 只顯示前 10 個，避免輸出過長
        local count=0
        for file in "${missing_files[@]}"; do
            if [ $count -lt 10 ]; then
                local line_count=$(wc -l < "$file" 2>/dev/null || echo "?")
                echo "- \`$file\` ($line_count lines)"
                ((count++))
            fi
        done

        if [ $missing_nullability -gt 10 ]; then
            echo "- ... and $((missing_nullability - 10)) more files"
        fi

        # 生成修復腳本
        echo ""
        echo "**Auto-fix script**:"
        echo '```bash'
        echo "# Add nullability to all headers"
        echo "find . -name '*.h' -not -path '*/Pods/*' -exec \\"
        echo "  sed -i '' '1i\\"
        echo "NS_ASSUME_NONNULL_BEGIN' {} \\; -exec \\"
        echo "  sed -i '' '\$a\\"
        echo "NS_ASSUME_NONNULL_END' {} \\;"
        echo '```'
    else
        echo -e "\n✅ All header files have nullability annotations"
    fi
}

analyze_nullability

# ==========================================
# 2. @objc Exposure Detection
# ==========================================
echo -e "\n${YELLOW}## 2. Objective-C Exposure Analysis${NC}\n"

analyze_objc_exposure() {
    local objc_classes=()
    local objc_members_classes=()
    local objc_funcs=()

    # 檢測 @objc class
    while IFS= read -r line; do
        local file=$(echo "$line" | cut -d: -f1)
        local line_no=$(echo "$line" | cut -d: -f2)
        local content=$(echo "$line" | cut -d: -f3-)
        objc_classes+=("$file:$line_no")
    done < <(grep -rn "@objc.*class" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null || true)

    # 檢測 @objcMembers
    while IFS= read -r line; do
        local file=$(echo "$line" | cut -d: -f1)
        local line_no=$(echo "$line" | cut -d: -f2)
        objc_members_classes+=("$file:$line_no")
    done < <(grep -rn "@objcMembers" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null || true)

    # 檢測 @objc func
    local objc_func_count=$(grep -rn "@objc.*func" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | wc -l || echo 0)

    echo "**Exposure Summary**:"
    echo "- \`@objc class\`: ${#objc_classes[@]}"
    echo "- \`@objcMembers class\`: ${#objc_members_classes[@]}"
    echo "- \`@objc func\`: $objc_func_count"

    if [ ${#objc_classes[@]} -gt 0 ] || [ ${#objc_members_classes[@]} -gt 0 ]; then
        echo ""
        echo "⚠️ **Risk**: Changes to these classes/methods affect Objective-C code"
        echo ""

        if [ ${#objc_members_classes[@]} -gt 0 ]; then
            echo "**@objcMembers classes** (all members exposed):"
            local count=0
            for entry in "${objc_members_classes[@]}"; do
                if [ $count -lt 15 ]; then
                    echo "- \`$entry\` ← Review required"
                    ((count++))
                fi
            done

            if [ ${#objc_members_classes[@]} -gt 15 ]; then
                echo "- ... and $((${#objc_members_classes[@]} - 15)) more classes"
            fi
        fi

        echo ""
        echo "**Breaking Change Risk**:"
        echo "- Renaming exposed methods → Compile errors in ObjC"
        echo "- Changing parameter types → Runtime crashes"
        echo "- Removing methods → Linker errors"
    else
        echo ""
        echo "✅ No @objc exposure detected (Pure Swift or minimal bridging)"
    fi
}

analyze_objc_exposure

# ==========================================
# 3. Bridging Header Analysis
# ==========================================
echo -e "\n${YELLOW}## 3. Bridging Header Analysis${NC}\n"

analyze_bridging_header() {
    # 尋找 Bridging Header
    local bridging_headers=()
    while IFS= read -r file; do
        bridging_headers+=("$file")
    done < <(find "$PROJECT_ROOT" -name "*-Bridging-Header.h" -not -path "*/Pods/*" -not -path "*/build/*" 2>/dev/null || true)

    if [ ${#bridging_headers[@]} -eq 0 ]; then
        echo "ℹ️  No bridging header found (Pure Swift or SPM project)"
        return
    fi

    for header in "${bridging_headers[@]}"; do
        echo "**File**: \`$header\`"

        # 計算 imports
        local import_count=$(grep -c "^#import" "$header" || echo 0)
        echo "**Imports**: $import_count Objective-C headers"

        # 列出所有 imports
        if [ $import_count -gt 0 ]; then
            echo ""
            echo "**Imported headers**:"
            (grep "^#import" "$header" | head -20 || true) | while IFS= read -r line; do
                [ -n "$line" ] && echo "- $line"
            done

            if [ $import_count -gt 20 ]; then
                echo "- ... and $((import_count - 20)) more"
            fi
        fi

        # 檢測潛在的循環依賴
        echo ""
        echo "**Circular Dependency Check**:"

        local target_basename=$(basename "$TARGET_FILE" .m)
        target_basename=$(basename "$target_basename" .swift)

        if grep -q "$target_basename" "$header"; then
            echo "⚠️ **Potential circular dependency detected**:"
            echo "- Bridging header imports \`$target_basename\`"
            echo "- Swift code may import this header"
        else
            echo "✅ No obvious circular dependencies"
        fi
    done
}

analyze_bridging_header

# ==========================================
# 4. Memory Management Analysis
# ==========================================
echo -e "\n${YELLOW}## 4. Memory Management Analysis${NC}\n"

analyze_memory_management() {
    # 計算 weak/unowned 使用
    local weak_count=$(grep -rn "\bweak var\|\bweak let" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | wc -l || echo 0)
    local unowned_count=$(grep -rn "\bunowned" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | wc -l || echo 0)

    echo "**Reference Counting**:"
    echo "- \`weak\` references: $weak_count"
    echo "- \`unowned\` references: $unowned_count"

    if [ $unowned_count -gt 0 ]; then
        echo ""
        echo "⚠️ **\`unowned\` Risk**: Crashes if referenced object is deallocated"
        echo ""
        echo "**Found \`unowned\` usage**:"
        (grep -rn "\bunowned" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | head -5 || true) | while IFS= read -r line; do
            [ -n "$line" ] || continue
            local file=$(echo "$line" | cut -d: -f1)
            local line_no=$(echo "$line" | cut -d: -f2)
            echo "- \`$file:$line_no\`"
        done

        if [ $unowned_count -gt 5 ]; then
            echo "- ... and $((unowned_count - 5)) more"
        fi

        echo ""
        echo "**Recommendation**: Prefer \`weak\` over \`unowned\` unless lifecycle is guaranteed"
    fi

    # 檢測潛在的 retain cycle patterns
    echo ""
    echo "**Retain Cycle Detection** (heuristic):"

    # Pattern: closure capturing self without [weak self]
    local closure_self=$(grep -rn "{ self\." --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | \
                        grep -v "\[weak self\]" | \
                        grep -v "\[unowned self\]" | wc -l || echo 0)

    if [ $closure_self -gt 0 ]; then
        echo "⚠️ Found $closure_self closures capturing \`self\` without \`[weak self]\`"
        echo ""
        echo "**Potential retain cycles**:"
        (grep -rn "{ self\." --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | \
            grep -v "\[weak self\]" | \
            grep -v "\[unowned self\]" | head -5 || true) | while IFS= read -r line; do
            [ -n "$line" ] || continue
            local file=$(echo "$line" | cut -d: -f1)
            local line_no=$(echo "$line" | cut -d: -f2)
            echo "- \`$file:$line_no\` ← Review required"
        done
    else
        echo "✅ No obvious retain cycle patterns detected"
    fi
}

analyze_memory_management

# ==========================================
# 5. Swift Version & API Availability
# ==========================================
echo -e "\n${YELLOW}## 5. Swift Version & API Availability${NC}\n"

analyze_swift_version() {
    # 檢查是否有 .swift-version 檔案
    if [ -f "$PROJECT_ROOT/.swift-version" ]; then
        local swift_ver=$(cat "$PROJECT_ROOT/.swift-version")
        echo "**Swift Version**: $swift_ver (from .swift-version)"
    else
        echo "**Swift Version**: Not specified (.swift-version not found)"
    fi

    # 檢查 @available 使用
    local available_count=$(grep -rn "@available" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | wc -l || echo 0)
    echo "**API Availability**: $available_count \`@available\` annotations found"

    if [ $available_count -gt 0 ]; then
        echo ""
        echo "**Platform-specific code detected** (sample):"
        (grep -rn "@available" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | head -5 || true) | while IFS= read -r line; do
            [ -n "$line" ] || continue
            local file=$(echo "$line" | cut -d: -f1)
            local line_no=$(echo "$line" | cut -d: -f2)
            local content=$(echo "$line" | cut -d: -f3-)
            echo "- \`$file:$line_no\`: $content"
        done
    fi
}

analyze_swift_version

# ==========================================
# 6. SwiftUI vs UIKit Detection
# ==========================================
echo -e "\n${YELLOW}## 6. UI Framework Analysis${NC}\n"

analyze_ui_framework() {
    local swiftui_files=$(grep -rl "import SwiftUI" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | wc -l || echo 0)
    local uikit_files=$(grep -rl "import UIKit" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | wc -l || echo 0)

    echo "**UI Framework Usage**:"
    echo "- SwiftUI files: $swiftui_files"
    echo "- UIKit files: $uikit_files"

    if [ $swiftui_files -gt 0 ] && [ $uikit_files -gt 0 ]; then
        echo ""
        echo "⚠️ **Hybrid UI architecture detected** (SwiftUI + UIKit)"
        echo ""
        echo "**Integration points**:"

        # 檢測 UIViewRepresentable (SwiftUI wrapping UIKit)
        local view_representable=$(grep -rn "UIViewRepresentable\|UIViewControllerRepresentable" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | wc -l || echo 0)
        echo "- \`UIViewRepresentable\`: $view_representable (SwiftUI → UIKit)"

        # 檢測 UIHostingController (UIKit hosting SwiftUI)
        local hosting_controller=$(grep -rn "UIHostingController" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | wc -l || echo 0)
        echo "- \`UIHostingController\`: $hosting_controller (UIKit → SwiftUI)"

        echo ""
        echo "**Migration consideration**: Changes to target file may affect both UI frameworks"
    elif [ $swiftui_files -gt 0 ]; then
        echo ""
        echo "✅ Modern SwiftUI-only architecture"
    else
        echo ""
        echo "ℹ️  UIKit-based architecture"
    fi
}

analyze_ui_framework

# ==========================================
# 7. Summary & Recommendations
# ==========================================
echo -e "\n${YELLOW}## 7. Summary & Quick Wins${NC}\n"

generate_summary() {
    echo "**Immediate Actions** (Quick wins):"
    echo ""

    # Check nullability
    local missing_nullability=$(find "$PROJECT_ROOT" -name "*.h" -not -path "*/Pods/*" -exec grep -L "NS_ASSUME_NONNULL" {} \; 2>/dev/null | wc -l || echo 0)
    if [ $missing_nullability -gt 0 ]; then
        echo "1. ⚠️ **Add nullability annotations** to $missing_nullability header files"
        echo "   Priority: 🔴 CRITICAL (prevents runtime crashes)"
        echo "   Effort: ~30 minutes"
        echo ""
    fi

    # Check unowned
    local unowned_count=$(grep -rn "\bunowned" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | wc -l || echo 0)
    if [ $unowned_count -gt 0 ]; then
        echo "2. ⚠️ **Review $unowned_count \`unowned\` references**"
        echo "   Priority: 🟡 MEDIUM (potential crashes)"
        echo "   Effort: ~1-2 hours"
        echo ""
    fi

    # Check @objcMembers
    local objc_members=$(grep -rn "@objcMembers" --include="*.swift" "$PROJECT_ROOT" 2>/dev/null | wc -l || echo 0)
    if [ $objc_members -gt 0 ]; then
        echo "3. ℹ️ **Document $objc_members @objcMembers classes**"
        echo "   Priority: 🟢 LOW (good to know)"
        echo "   Effort: ~30 minutes"
        echo ""
    fi

    echo "**Long-term Improvements**:"
    echo "- Consider migrating Objective-C code to Swift (if applicable)"
    echo "- Add SwiftLint rules for memory management"
    echo "- Use Instruments to detect actual retain cycles"
}

generate_summary

echo -e "\n${GREEN}=== Analysis Complete ===${NC}"
echo ""
echo "💡 **Tip**: Run \`swiftlint\` or \`xcodebuild analyze\` for additional static analysis"
