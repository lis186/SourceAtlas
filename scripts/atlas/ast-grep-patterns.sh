#!/bin/bash
# ast-grep-patterns.sh - 高價值 patterns 的 AST 精確搜尋
#
# 設計原則：
# 1. 選擇性整合 - 只處理 Type B patterns（需內容分析）
# 2. 優雅降級 - ast-grep 未安裝時返回空，由呼叫者降級到 grep
# 3. 效能優先 - 使用 --json 輸出，避免重複解析
#
# 使用方式：
#   ./ast-grep-patterns.sh <pattern> <project_type> <project_path>
#
# 返回：
#   成功時輸出 JSON 格式的匹配結果
#   ast-grep 未安裝時返回 exit 1
#   pattern 不支援時返回 exit 2

set -euo pipefail

PATTERN="${1:-}"
PROJECT_TYPE="${2:-}"
PROJECT_PATH="${3:-.}"

# 取得腳本目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_DIR="${SCRIPT_DIR}/ast-grep-rules"

# ============================================================
# 偵測 ast-grep
# ============================================================
detect_ast_grep() {
    if command -v ast-grep &> /dev/null; then
        echo "ast-grep"
        return 0
    elif command -v sg &> /dev/null; then
        echo "sg"
        return 0
    else
        return 1
    fi
}

AST_GREP_CMD=$(detect_ast_grep) || {
    # ast-grep 未安裝，靜默退出讓呼叫者降級
    exit 1
}

# ============================================================
# 動態生成 YAML Rule（臨時檔案）
# ============================================================
create_temp_rule() {
    local rule_content="$1"
    local temp_file
    temp_file=$(mktemp /tmp/ast-grep-rule-XXXXXX.yaml)
    echo "$rule_content" > "$temp_file"
    echo "$temp_file"
}

cleanup_temp_rule() {
    local temp_file="$1"
    [[ -f "$temp_file" ]] && rm -f "$temp_file"
}

run_with_yaml_rule() {
    local rule_content="$1"
    local temp_rule
    temp_rule=$(create_temp_rule "$rule_content")
    $AST_GREP_CMD scan --rule "$temp_rule" --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
    cleanup_temp_rule "$temp_rule"
}

# ============================================================
# Type B Patterns 定義（需內容分析，ast-grep 高價值）
# ============================================================

# Swift patterns
swift_async_function() {
    run_with_yaml_rule '
id: swift-async-function
language: Swift
rule:
  kind: function_declaration
  has:
    pattern: async
'
}

swift_await_expression() {
    $AST_GREP_CMD --pattern 'await $EXPR' \
        --lang swift --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
}

# TypeScript/React patterns
tsx_use_state() {
    $AST_GREP_CMD --pattern 'useState($$$)' \
        --lang tsx --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
}

tsx_use_effect() {
    $AST_GREP_CMD --pattern 'useEffect($$$)' \
        --lang tsx --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
}

tsx_use_query() {
    $AST_GREP_CMD --pattern 'useQuery($$$)' \
        --lang tsx --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
}

tsx_use_mutation() {
    $AST_GREP_CMD --pattern 'useMutation($$$)' \
        --lang tsx --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
}

tsx_use_client() {
    # 'use client' directive 需要 YAML rule
    run_with_yaml_rule '
id: tsx-use-client
language: Tsx
rule:
  kind: expression_statement
  has:
    kind: string
    regex: "^.use client.$"
'
}

# Kotlin patterns
kotlin_suspend_fun() {
    # Kotlin 使用簡單 pattern 即可有效匹配
    $AST_GREP_CMD --pattern 'suspend fun $NAME' \
        --lang kotlin --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
}

kotlin_composable() {
    $AST_GREP_CMD --pattern '@Composable' \
        --lang kotlin --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
}

# ============================================================
# Pattern 路由
# ============================================================
normalize_pattern() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | xargs
}

merge_json_arrays() {
    jq -s 'add // []'
}

NORMALIZED=$(normalize_pattern "$PATTERN")

case "$PROJECT_TYPE" in
    "swift"|"ios")
        case "$NORMALIZED" in
            "async"|"await"|"async await"|"async/await"|"concurrency")
                # 合併 async function 和 await expression
                {
                    swift_async_function
                    swift_await_expression
                } | merge_json_arrays
                ;;
            "async function"|"async func")
                swift_async_function
                ;;
            "await"|"await expression")
                swift_await_expression
                ;;
            *)
                # 不支援的 pattern，返回 exit 2
                exit 2
                ;;
        esac
        ;;

    "typescript"|"react"|"nextjs"|"vue"|"tsx")
        case "$NORMALIZED" in
            "hook"|"hooks"|"custom hook"|"react hook")
                # 合併常見 hooks
                {
                    tsx_use_state
                    tsx_use_effect
                } | merge_json_arrays
                ;;
            "usestate"|"state"|"react state")
                tsx_use_state
                ;;
            "useeffect"|"effect"|"side effect")
                tsx_use_effect
                ;;
            "tanstack"|"tanstack query"|"react query"|"usequery")
                {
                    tsx_use_query
                    tsx_use_mutation
                } | merge_json_arrays
                ;;
            "use client"|"client component"|"client directive")
                tsx_use_client
                ;;
            *)
                exit 2
                ;;
        esac
        ;;

    "kotlin"|"android")
        case "$NORMALIZED" in
            "suspend"|"suspend fun"|"coroutine"|"coroutines")
                kotlin_suspend_fun
                ;;
            "composable"|"compose"|"jetpack compose")
                kotlin_composable
                ;;
            *)
                exit 2
                ;;
        esac
        ;;

    *)
        # 不支援的專案類型
        exit 2
        ;;
esac
