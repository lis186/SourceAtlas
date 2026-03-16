#!/bin/bash
# feathers-mutable-public-field (ObjC fallback) — 偵測 .h 中的可寫 @property
# 精確度: MEDIUM
# 已知誤報:
#   - delegate 屬性宣告為 weak（合理的可變屬性）
#   - IBOutlet 屬性（UIKit 要求）
#   - 簡單 Model/DTO 類別的屬性
#   - readwrite 是 ObjC 屬性預設值，所以未標註 readonly 的都會被偵測
# 已知漏報:
#   - Class extension (.m 檔中) 重新宣告為 readwrite 的屬性
#   - 使用 @public 直接暴露的 ivar
#
# 來源: Working Effectively with Legacy Code, Ch.11
#
# 用法:
#   bash mutable-public-field.sh <source-directory> [--verbose]
#   bash mutable-public-field.sh ./NYCore
#
# 退出碼:
#   0 — 無違規
#   1 — 找到違規
#   2 — 參數錯誤

set -euo pipefail

TARGET_DIR="${1:-.}"
VERBOSE=false
if [[ "${2:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: 目錄不存在: $TARGET_DIR" >&2
    exit 2
fi

echo "=== Feathers Mutable Public Field (ObjC) ==="
echo "精確度: MEDIUM"
echo ""

VIOLATIONS=0

# 在 .h 檔中找 @property 宣告，排除 readonly 的
while read -r header; do
    # 找到所有 @property 宣告
    while read -r match; do
        line_num=$(echo "$match" | cut -d: -f1)
        prop_line=$(echo "$match" | cut -d: -f2-)

        # 跳過 readonly 屬性
        if echo "$prop_line" | grep -q 'readonly'; then
            continue
        fi

        # 跳過 delegate（通常是 weak delegate 模式，合理）
        if echo "$prop_line" | grep -qi 'delegate'; then
            if $VERBOSE; then
                echo "SKIP (delegate): $header:$line_num"
            fi
            continue
        fi

        # 跳過 IBOutlet
        if echo "$prop_line" | grep -q 'IBOutlet'; then
            if $VERBOSE; then
                echo "SKIP (IBOutlet): $header:$line_num"
            fi
            continue
        fi

        # 提取屬性名稱
        prop_name=$(echo "$prop_line" | sed -E 's/.*\)\s*//' | sed -E 's/\s*[;=].*//' | awk '{print $NF}' | tr -d '*;')

        echo "VIOLATION: $header:$line_num — 公開可變屬性: $prop_name"
        ((VIOLATIONS++)) || true
    done < <(grep -nE '@property\s*\(' "$header" 2>/dev/null)
done < <(find "$TARGET_DIR" -name "*.h" -not -path "*/Pods/*" -not -path "*/DerivedData/*")

echo ""
if [[ $VIOLATIONS -eq 0 ]]; then
    echo "PASS: 無公開可變屬性"
    exit 0
else
    echo "共 $VIOLATIONS 個違規 -- 考慮加上 readonly 並提供明確的 setter 方法"
    exit 1
fi
