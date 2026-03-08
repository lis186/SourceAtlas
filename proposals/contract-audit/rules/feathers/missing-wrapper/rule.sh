#!/bin/bash
# feathers-missing-wrapper — 偵測 10+ 個檔案 import 同一第三方深層 class
# 來源: Working Effectively with Legacy Code, Ch.15 "My Application Is All API Calls"
#
# 用法:
#   bash rule.sh <source-directory> [threshold]
#   bash rule.sh ./Sources 10
#   bash rule.sh ./Sources 5
#
# 退出碼:
#   0 — 無違規
#   1 — 找到違規
#   2 — 參數錯誤
#
# 「深層 class」定義: import 路徑含有 2 層以上子模組
# 例如 import Alamofire.Session.Request（深層）vs import Alamofire（頂層）
#
# 支援語言: Swift, Objective-C, Java, Kotlin

set -euo pipefail

TARGET_DIR="${1:-.}"
THRESHOLD="${2:-10}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: 目錄不存在: $TARGET_DIR" >&2
    exit 2
fi

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

echo "=== Feathers Missing Wrapper 偵測 (閾值: $THRESHOLD 個檔案) ==="

# 收集所有 import 語句
# Swift: import Module.SubModule
# ObjC: #import <Framework/Header.h> 或 #import "Path/Header.h"
# Java/Kotlin: import com.package.sub.Class

find "$TARGET_DIR" \( -name "*.swift" -o -name "*.m" -o -name "*.h" -o -name "*.java" -o -name "*.kt" \) \
    -not -path "*/.build/*" -not -path "*/Pods/*" -not -path "*/node_modules/*" \
    -not -path "*/__pycache__/*" -not -path "*/DerivedData/*" | while read -r file; do

    # Swift deep imports (e.g., import Module.SubModule)
    grep -oE '^import [A-Za-z0-9_]+\.[A-Za-z0-9_.]+' "$file" 2>/dev/null | while read -r imp; do
        echo "$imp"
    done

    # ObjC framework imports (e.g., #import <AFNetworking/AFHTTPSessionManager.h>)
    grep -oE '#import <[^>]+>' "$file" 2>/dev/null | while read -r imp; do
        echo "$imp"
    done

    # ObjC quoted imports with path (e.g., #import "Vendor/SomeClass.h")
    grep -oE '#import "[^"]*/"[^"]*"' "$file" 2>/dev/null | while read -r imp; do
        echo "$imp"
    done

    # Java/Kotlin imports (e.g., import com.google.firebase.auth.FirebaseAuth)
    grep -oE '^import [a-z][a-z0-9_]*\.[a-z][a-z0-9_.]*\.[A-Z][A-Za-z0-9_]*' "$file" 2>/dev/null | while read -r imp; do
        echo "$imp"
    done

done | sort | uniq -c | sort -rn > "$TMPFILE"

VIOLATIONS=0

while read -r count import_stmt; do
    if [[ $count -ge $THRESHOLD ]]; then
        echo "VIOLATION: $import_stmt -- $count 個檔案引用 (閾值 $THRESHOLD)"
        ((VIOLATIONS++)) || true
    fi
done < "$TMPFILE"

echo ""
if [[ $VIOLATIONS -eq 0 ]]; then
    echo "PASS: 無超過 $THRESHOLD 個檔案引用的深層 import"
    exit 0
else
    echo "共 $VIOLATIONS 個違規 -- 考慮建立 Wrapper/Facade 封裝這些直接依賴"
    exit 1
fi
