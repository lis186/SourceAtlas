#!/bin/bash
# 驗證腳本：比對 grep vs ast-grep 的結果

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AST_SCRIPT="$SCRIPT_DIR/atlas/ast-grep-search.sh"
PROJECT_PATH="${1:-test_targets/go-gin}"
LANG="${2:-go}"

echo "=== op_definition 驗證 ==="
echo "專案: $PROJECT_PATH"
echo "語言: $LANG"
echo ""

# 函數列表
FUNCS="formatAsDate Default New recover Logger BasicAuth Error"

MATCH=0
MISMATCH=0

for func in $FUNCS; do
    # grep 計數
    case "$LANG" in
        go) GREP_N=$(grep -rn "^func $func" "$PROJECT_PATH" --include='*.go' 2>/dev/null | wc -l | tr -d ' ') ;;
        ruby) GREP_N=$(grep -rn "^[[:space:]]*def $func\|^[[:space:]]*class $func\|^[[:space:]]*module $func" "$PROJECT_PATH" --include='*.rb' 2>/dev/null | wc -l | tr -d ' ') ;;
        rust) GREP_N=$(grep -rn "^pub fn $func\|^fn $func\|^pub struct $func\|^struct $func" "$PROJECT_PATH" --include='*.rs' 2>/dev/null | wc -l | tr -d ' ') ;;
    esac

    # ast-grep 計數
    AST_N=$(bash "$AST_SCRIPT" definition "$func" --path "$PROJECT_PATH" --json 2>/dev/null | jq 'length')

    if [ "$GREP_N" = "$AST_N" ]; then
        STATUS="✅"
        MATCH=$((MATCH + 1))
    else
        STATUS="❌"
        MISMATCH=$((MISMATCH + 1))
    fi

    printf "%-20s grep=%-3s ast=%-3s %s\n" "$func" "$GREP_N" "$AST_N" "$STATUS"
done

TOTAL=$((MATCH + MISMATCH))
echo ""
echo "=== 結果 ==="
echo "匹配: $MATCH/$TOTAL"
echo "準確率: $(echo "scale=1; $MATCH * 100 / $TOTAL" | bc)%"
