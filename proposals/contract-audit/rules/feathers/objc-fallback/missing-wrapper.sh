#!/bin/bash
# feathers-missing-wrapper (ObjC fallback) — 偵測 10+ 檔案 import 同一第三方深層 class
# 精確度: HIGH
# 已知誤報:
#   - 專案內部的 framework header 被當作第三方（如 #import <MyFramework/MyClass.h>）
#   - UIKit 系統 framework 的 import（如 <UIKit/UIKit.h>）是合理的
#   - 條件編譯 (#ifdef) 內的 import 實際上可能不會被執行
# 已知漏報:
#   - 使用 @class forward declaration 而非 #import 的依賴
#   - 透過 umbrella header 間接引用的依賴
#
# 來源: Working Effectively with Legacy Code, Ch.15
#
# 用法:
#   bash missing-wrapper.sh <source-directory> [threshold]
#   bash missing-wrapper.sh ./NYCore 10
#
# 退出碼:
#   0 — 無違規
#   1 — 找到違規
#   2 — 參數錯誤

set -euo pipefail

TARGET_DIR="${1:-.}"
THRESHOLD="${2:-10}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: 目錄不存在: $TARGET_DIR" >&2
    exit 2
fi

echo "=== Feathers Missing Wrapper (ObjC) — 閾值 $THRESHOLD 個檔案 ==="
echo "精確度: HIGH"
echo ""

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# 收集所有 #import <Framework/Header.h> 格式的引用
# 排除系統 framework
SYSTEM_FRAMEWORKS="UIKit|Foundation|CoreGraphics|CoreFoundation|QuartzCore|Security|SystemConfiguration|CoreData|MapKit|CoreLocation|AVFoundation|Photos|WebKit|SafariServices|StoreKit|MessageUI|Social|Accounts|EventKit|HealthKit|HomeKit|CloudKit|GameKit|SceneKit|SpriteKit|Metal|MetalKit|ARKit|CoreML|Vision|NaturalLanguage|CryptoKit|Combine|SwiftUI"

find "$TARGET_DIR" \( -name "*.m" -o -name "*.h" \) \
    -not -path "*/Pods/*" -not -path "*/DerivedData/*" | while read -r file; do
    grep -oE '#import <[^>]+>' "$file" 2>/dev/null
done | grep -vE "#import <($SYSTEM_FRAMEWORKS)/" | sort | uniq -c | sort -rn > "$TMPFILE"

VIOLATIONS=0

while read -r count import_stmt; do
    if [[ -n "$count" ]] && (( count >= THRESHOLD )); then
        echo "VIOLATION: $import_stmt -- $count 個檔案引用 (閾值 $THRESHOLD)"
        ((VIOLATIONS++)) || true
    fi
done < "$TMPFILE"

echo ""
if [[ $VIOLATIONS -eq 0 ]]; then
    echo "PASS: 無超過 $THRESHOLD 個檔案引用的第三方深層 import"
    exit 0
else
    echo "共 $VIOLATIONS 個違規 -- 考慮建立 Wrapper/Facade 封裝這些直接依賴"
    exit 1
fi
