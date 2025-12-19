#!/bin/bash
# .dev-notes/ 結構驗證腳本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTES_DIR="${SCRIPT_DIR}/.."
ERRORS=0

echo "🔍 驗證 .dev-notes/ 結構..."

# 檢查 1: 大寫檔案數量
echo ""
echo "檢查 1: 大寫檔案數量（限制 5 個）"
UPPER_COUNT=$(find "$NOTES_DIR" -maxdepth 1 -name "[A-Z]*.md" | wc -l | tr -d ' ')
if [ "$UPPER_COUNT" -gt 5 ]; then
    echo "❌ 大寫檔案過多: $UPPER_COUNT 個（限制 5 個）"
    find "$NOTES_DIR" -maxdepth 1 -name "[A-Z]*.md" -exec basename {} \;
    ERRORS=$((ERRORS + 1))
else
    echo "✅ 大寫檔案數量: $UPPER_COUNT/5"
fi

# 檢查 2: 必需的大寫檔案存在
echo ""
echo "檢查 2: 必需的核心檔案"
REQUIRED=("README.md" "HISTORY.md" "KEY_LEARNINGS.md" "ROADMAP.md" "METHODOLOGY.md")
for file in "${REQUIRED[@]}"; do
    if [ ! -f "$NOTES_DIR/$file" ]; then
        echo "❌ 缺少核心檔案: $file"
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ $file"
    fi
done

# 檢查 3: 月度資料夾必須有 README.md
echo ""
echo "檢查 3: 月度資料夾必須有 README.md"
find "$NOTES_DIR" -maxdepth 1 -type d -name "20[0-9][0-9]-[0-9][0-9]" | while read dir; do
    if [ ! -f "$dir/README.md" ]; then
        echo "❌ 缺少月度摘要: $dir/README.md"
        ERRORS=$((ERRORS + 1))
    else
        echo "✅ $(basename $dir)/README.md"
    fi
done

# 總結
echo ""
echo "================================"
if [ $ERRORS -eq 0 ]; then
    echo "✅ 所有檢查通過"
    exit 0
else
    echo "❌ 發現 $ERRORS 個問題"
    exit 1
fi
