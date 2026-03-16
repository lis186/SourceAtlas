#!/bin/bash
# feathers-monster-method (ObjC fallback) — 偵測行數超過 50 行的 ObjC 方法
# 精確度: HIGH
# 已知誤報:
#   - 包含大量註解的方法（註解行也被計入）
#   - 長 switch-case 語句（每個 case 邏輯簡單但行數多）
#   - 自動產生的程式碼（如 CoreData managed object subclass）
# 已知漏報:
#   - 透過 #define 巨集壓縮行數的方法
#
# 來源: Working Effectively with Legacy Code, Ch.22
#
# 用法:
#   bash monster-method.sh <source-directory> [threshold]
#   bash monster-method.sh ./NYCore 50
#
# 退出碼:
#   0 — 無違規
#   1 — 找到違規
#   2 — 參數錯誤

set -euo pipefail

TARGET_DIR="${1:-.}"
THRESHOLD="${2:-50}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: 目錄不存在: $TARGET_DIR" >&2
    exit 2
fi

echo "=== Feathers Monster Method (ObjC) — 閾值 $THRESHOLD 行 ==="
echo "精確度: HIGH"
echo ""

VIOLATIONS=0

while read -r file; do
    in_method=false
    method_name=""
    method_start=0
    brace_depth=0
    line_num=0

    while IFS= read -r line; do
        ((line_num++)) || true

        stripped=$(echo "$line" | sed 's|//.*||')

        # 偵測 ObjC 方法宣告
        if echo "$stripped" | grep -qE '^\s*[-+]\s*\('; then
            if $in_method; then
                local_length=$((line_num - method_start))
                if (( local_length > THRESHOLD )); then
                    echo "VIOLATION: $file:$method_start — $method_name ($local_length 行)"
                    ((VIOLATIONS++)) || true
                fi
            fi
            method_name=$(echo "$stripped" | sed -E 's/.*[-+]\s*\([^)]*\)\s*//' | sed -E 's/[:{].*//' | xargs)
            method_start=$line_num
            in_method=true
            brace_depth=0
        fi

        if $in_method; then
            opens=$(echo "$stripped" | tr -cd '{' | wc -c | tr -d ' ')
            closes=$(echo "$stripped" | tr -cd '}' | wc -c | tr -d ' ')
            brace_depth=$((brace_depth + opens - closes))

            if (( brace_depth <= 0 )) && (( line_num != method_start )) && (( opens > 0 || closes > 0 )); then
                local_length=$((line_num - method_start))
                if (( local_length > THRESHOLD )); then
                    echo "VIOLATION: $file:$method_start — $method_name ($local_length 行)"
                    ((VIOLATIONS++)) || true
                fi
                in_method=false
            fi
        fi
    done < "$file"

    # 檔案結尾仍在方法內
    if $in_method; then
        local_length=$((line_num - method_start))
        if (( local_length > THRESHOLD )); then
            echo "VIOLATION: $file:$method_start — $method_name ($local_length 行)"
            ((VIOLATIONS++)) || true
        fi
    fi
done < <(find "$TARGET_DIR" -name "*.m" -not -path "*/Pods/*" -not -path "*/DerivedData/*")

if [[ $VIOLATIONS -eq 0 ]]; then
    echo "PASS: 無超過 $THRESHOLD 行的方法"
    exit 0
else
    echo ""
    echo "共 $VIOLATIONS 個違規"
    exit 1
fi
