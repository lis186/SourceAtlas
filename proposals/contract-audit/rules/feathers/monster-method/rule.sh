#!/bin/bash
# feathers-monster-method — 偵測行數超過 50 行的方法
# 來源: Working Effectively with Legacy Code, Ch.22
#
# 用法:
#   bash rule.sh <source-directory> [threshold]
#   bash rule.sh ./Sources 50
#   bash rule.sh ./Sources 80 --swift-only
#
# 退出碼:
#   0 — 無違規
#   1 — 找到違規
#   2 — 參數錯誤
#
# 支援語言: Swift, Objective-C, Java, C#

set -euo pipefail

TARGET_DIR="${1:-.}"
THRESHOLD="${2:-50}"
SWIFT_ONLY=false

if [[ "${3:-}" == "--swift-only" ]]; then
    SWIFT_ONLY=true
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: 目錄不存在: $TARGET_DIR" >&2
    exit 2
fi

VIOLATIONS=0

# 偵測 Swift 方法
detect_swift() {
    local file="$1"
    local in_func=false
    local func_name=""
    local func_start=0
    local brace_depth=0
    local line_num=0

    while IFS= read -r line; do
        ((line_num++)) || true

        # 偵測 func 宣告
        if echo "$line" | grep -qE '^\s*(public |private |internal |open |fileprivate |override |static |class )*func '; then
            if $in_func && (( line_num - func_start > THRESHOLD )); then
                echo "VIOLATION: $file:$func_start — $func_name ($((line_num - func_start)) 行, 閾值 $THRESHOLD)"
                ((VIOLATIONS++)) || true
            fi
            func_name=$(echo "$line" | sed -E 's/.*func ([a-zA-Z0-9_]+).*/\1/')
            func_start=$line_num
            in_func=true
            brace_depth=0
        fi

        # 追蹤大括號深度（簡易版，不處理字串內的大括號）
        local opens closes
        opens=$(echo "$line" | tr -cd '{' | wc -c | tr -d ' ')
        closes=$(echo "$line" | tr -cd '}' | wc -c | tr -d ' ')
        brace_depth=$((brace_depth + opens - closes))

        if $in_func && [[ $brace_depth -le 0 ]] && [[ $func_start -ne $line_num ]]; then
            local length=$((line_num - func_start))
            if (( length > THRESHOLD )); then
                echo "VIOLATION: $file:$func_start — $func_name ($length 行, 閾值 $THRESHOLD)"
                ((VIOLATIONS++)) || true
            fi
            in_func=false
        fi
    done < "$file"

    # 處理檔案結尾仍在方法內的情況
    if $in_func; then
        local length=$((line_num - func_start))
        if (( length > THRESHOLD )); then
            echo "VIOLATION: $file:$func_start — $func_name ($length 行, 閾值 $THRESHOLD)"
            ((VIOLATIONS++)) || true
        fi
    fi
}

# 偵測 ObjC 方法
detect_objc() {
    local file="$1"
    local in_method=false
    local method_name=""
    local method_start=0
    local brace_depth=0
    local line_num=0

    while IFS= read -r line; do
        ((line_num++)) || true

        # 偵測 ObjC 方法宣告 (- 或 +)
        if echo "$line" | grep -qE '^\s*[-+]\s*\('; then
            if $in_method; then
                local length=$((line_num - method_start))
                if (( length > THRESHOLD )); then
                    echo "VIOLATION: $file:$method_start — $method_name ($length 行, 閾值 $THRESHOLD)"
                    ((VIOLATIONS++)) || true
                fi
            fi
            method_name=$(echo "$line" | sed -E 's/.*[-+]\s*\([^)]*\)\s*//' | sed -E 's/[:{].*//')
            method_start=$line_num
            in_method=true
            brace_depth=0
        fi

        local opens closes
        opens=$(echo "$line" | tr -cd '{' | wc -c | tr -d ' ')
        closes=$(echo "$line" | tr -cd '}' | wc -c | tr -d ' ')
        brace_depth=$((brace_depth + opens - closes))

        if $in_method && [[ $brace_depth -le 0 ]] && [[ $method_start -ne $line_num ]] && [[ $opens -gt 0 || $closes -gt 0 ]]; then
            local length=$((line_num - method_start))
            if (( length > THRESHOLD )); then
                echo "VIOLATION: $file:$method_start — $method_name ($length 行, 閾值 $THRESHOLD)"
                ((VIOLATIONS++)) || true
            fi
            in_method=false
        fi
    done < "$file"
}

echo "=== Feathers Monster Method 偵測 (閾值: $THRESHOLD 行) ==="

# Swift 檔案
while read -r f; do
    detect_swift "$f"
done < <(find "$TARGET_DIR" -name "*.swift" -not -path "*/.build/*" -not -path "*/Pods/*")

# 非 Swift 檔案
if ! $SWIFT_ONLY; then
    while read -r f; do
        detect_objc "$f"
    done < <(find "$TARGET_DIR" \( -name "*.m" -o -name "*.java" -o -name "*.cs" \) \
        -not -path "*/.build/*" -not -path "*/Pods/*")
fi

if [[ $VIOLATIONS -eq 0 ]]; then
    echo "PASS: 無超過 $THRESHOLD 行的方法"
    exit 0
else
    echo ""
    echo "共 $VIOLATIONS 個違規"
    exit 1
fi
