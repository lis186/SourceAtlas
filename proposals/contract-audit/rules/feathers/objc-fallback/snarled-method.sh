#!/bin/bash
# feathers-snarled-method (ObjC fallback) — 偵測巢狀深度 > 3 的 ObjC 方法
# 精確度: MEDIUM
# 已知誤報:
#   - 字串常數中含有大括號（如 JSON 模板）會干擾深度計算
#   - 多行巨集展開可能被錯誤計算
#   - Block 語法的大括號會增加巢狀計數
# 已知漏報:
#   - 使用 #define 巨集隱藏的巢狀結構
#
# 來源: Working Effectively with Legacy Code, Ch.22
#
# 用法:
#   bash snarled-method.sh <source-directory> [max-depth]
#   bash snarled-method.sh ./NYCore 3
#
# 退出碼:
#   0 — 無違規
#   1 — 找到違規
#   2 — 參數錯誤

set -euo pipefail

TARGET_DIR="${1:-.}"
MAX_DEPTH="${2:-3}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: 目錄不存在: $TARGET_DIR" >&2
    exit 2
fi

echo "=== Feathers Snarled Method (ObjC) — 巢狀深度 > $MAX_DEPTH ==="
echo "精確度: MEDIUM"
echo ""

VIOLATIONS=0

while read -r file; do
    in_method=false
    method_name=""
    method_start=0
    brace_depth=0
    max_seen_depth=0
    line_num=0

    while IFS= read -r line; do
        ((line_num++)) || true

        # 跳過單行註解
        stripped=$(echo "$line" | sed 's|//.*||')

        # 偵測 ObjC 方法宣告
        if echo "$stripped" | grep -qE '^\s*[-+]\s*\('; then
            # 回報前一個方法
            if $in_method && (( max_seen_depth > MAX_DEPTH )); then
                echo "VIOLATION: $file:$method_start — $method_name (最大巢狀深度 $max_seen_depth, 閾值 $MAX_DEPTH)"
                ((VIOLATIONS++)) || true
            fi
            method_name=$(echo "$stripped" | sed -E 's/.*[-+]\s*\([^)]*\)\s*//' | sed -E 's/[:{].*//' | xargs)
            method_start=$line_num
            in_method=true
            brace_depth=0
            max_seen_depth=0
        fi

        if $in_method; then
            # 逐字元計算大括號（簡易版）
            opens=$(echo "$stripped" | tr -cd '{' | wc -c | tr -d ' ')
            closes=$(echo "$stripped" | tr -cd '}' | wc -c | tr -d ' ')
            brace_depth=$((brace_depth + opens - closes))

            if (( brace_depth > max_seen_depth )); then
                max_seen_depth=$brace_depth
            fi

            # 方法結束
            if (( brace_depth <= 0 )) && (( line_num != method_start )) && (( opens > 0 || closes > 0 )); then
                if (( max_seen_depth > MAX_DEPTH )); then
                    echo "VIOLATION: $file:$method_start — $method_name (最大巢狀深度 $max_seen_depth, 閾值 $MAX_DEPTH)"
                    ((VIOLATIONS++)) || true
                fi
                in_method=false
            fi
        fi
    done < "$file"
done < <(find "$TARGET_DIR" -name "*.m" -not -path "*/Pods/*" -not -path "*/DerivedData/*")

if [[ $VIOLATIONS -eq 0 ]]; then
    echo "PASS: 無超過深度 $MAX_DEPTH 的巢狀方法"
    exit 0
else
    echo ""
    echo "共 $VIOLATIONS 個違規"
    exit 1
fi
