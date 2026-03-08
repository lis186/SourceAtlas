#!/bin/bash
# feathers-programming-by-difference (ObjC fallback) — 偵測子類別 override <= 2 方法
# 精確度: MEDIUM
# 已知誤報:
#   - 合理的 Template Method 模式（子類別僅覆寫一個 hook method）
#   - UIViewController 子類別只覆寫 viewDidLoad（非常普遍且合理）
#   - 單元測試的 mock 子類別
#   - Category 中的方法不會被偵測為 override
# 已知漏報:
#   - Protocol extension 的預設實作被覆寫不會被偵測
#   - 使用 @dynamic 的 ObjC 屬性
#
# 來源: Working Effectively with Legacy Code, Ch.20
#
# 用法:
#   bash programming-by-difference.sh <source-directory> [max-overrides]
#   bash programming-by-difference.sh ./Sources 2
#
# 退出碼:
#   0 — 無違規
#   1 — 找到違規
#   2 — 參數錯誤

set -euo pipefail

TARGET_DIR="${1:-.}"
MAX_OVERRIDES="${2:-2}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: 目錄不存在: $TARGET_DIR" >&2
    exit 2
fi

echo "=== Feathers Programming by Difference (ObjC) — override <= $MAX_OVERRIDES 方法 ==="
echo "精確度: MEDIUM"
echo ""

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

VIOLATIONS=0

# ObjC 的 "override" 不像 Swift 有明確關鍵字
# 偵測策略: 找到繼承宣告，然後計算 .m 檔中的方法數量
# 如果方法很少（<= MAX_OVERRIDES），可能是 programming by difference

# 步驟 1: 從 .h 檔找出所有繼承關係
find "$TARGET_DIR" -name "*.h" -not -path "*/Pods/*" -not -path "*/DerivedData/*" | while read -r header; do
    # 匹配 @interface ClassName : ParentClass
    grep -nE '@interface\s+[A-Za-z0-9_]+\s*:\s*[A-Za-z0-9_]+' "$header" 2>/dev/null | while read -r match; do
        class_name=$(echo "$match" | sed -E 's/.*@interface\s+([A-Za-z0-9_]+)\s*:.*/\1/')
        parent_name=$(echo "$match" | sed -E 's/.*:\s*([A-Za-z0-9_]+).*/\1/')
        line_num=$(echo "$match" | cut -d: -f1)

        # 跳過常見基礎類別的直接子類別（通常不是 programming by difference）
        case "$parent_name" in
            NSObject|UIView|UIControl|CALayer) continue ;;
        esac

        # 找對應的 .m 檔
        impl_file=$(echo "$header" | sed 's/\.h$/.m/')
        if [[ ! -f "$impl_file" ]]; then
            continue
        fi

        # 計算 .m 檔中該 class 的方法數量
        # 用 @implementation ClassName 到 @end 之間的方法計數
        method_count=$(sed -n "/@implementation $class_name/,/@end/p" "$impl_file" 2>/dev/null \
            | grep -cE '^\s*[-+]\s*\(' || true)

        if (( method_count > 0 && method_count <= MAX_OVERRIDES )); then
            echo "VIOLATION: $header:$line_num — $class_name (繼承 $parent_name, 僅 $method_count 個方法)"
            ((VIOLATIONS++)) || true
        fi
    done
done

if [[ $VIOLATIONS -eq 0 ]]; then
    echo "PASS: 無 programming by difference 嫌疑的子類別"
    exit 0
else
    echo ""
    echo "共 $VIOLATIONS 個違規 -- 考慮改用組合 (Composition) 或策略模式 (Strategy)"
    exit 1
fi
