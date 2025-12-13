#!/bin/bash
# ast-grep-search.sh - SourceAtlas 統一 AST 搜尋入口
#
# 設計原則：
# 1. 單一入口 - 所有 atlas 命令通過此腳本使用 ast-grep
# 2. 優雅降級 - ast-grep 不可用時提供 grep fallback 命令
# 3. 規則集中 - YAML rules 統一管理於 ast-grep-rules/
# 4. 效能優先 - 快取偵測結果，避免重複檢查
#
# 使用方式：
#   ./ast-grep-search.sh <operation> <target> [options]
#
# Operations:
#   call <function>        - 函數呼叫追蹤 (for /atlas.flow, /atlas.impact)
#   type <typename>        - 類型引用搜尋 (for /atlas.impact)
#   pattern <pattern>      - 設計模式搜尋 (for /atlas.pattern)
#   usage <api>            - API 使用盤點 (for /atlas.deps)
#   async                  - async/await 流程 (for /atlas.flow)
#   boundary <type>        - 邊界偵測 api|db (for /atlas.flow)
#
# Options:
#   --lang <language>      - 指定語言 (swift|tsx|kotlin|python)
#   --path <project_path>  - 專案路徑 (default: .)
#   --fallback             - 輸出 grep fallback 命令（不執行 ast-grep）
#   --json                 - JSON 輸出格式
#   --count                - 只輸出匹配數量
#
# Exit codes:
#   0 - 成功
#   1 - ast-grep 未安裝（使用 --fallback 取得替代命令）
#   2 - 不支援的 operation/pattern
#   3 - 參數錯誤

set -euo pipefail

# ============================================================
# 配置
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_DIR="${SCRIPT_DIR}/ast-grep-rules"

# 預設值
PROJECT_PATH="."
LANG=""
OUTPUT_JSON=false
OUTPUT_COUNT=false
FALLBACK_MODE=false

# ============================================================
# ast-grep 偵測（快取結果）
# ============================================================
AST_GREP_CMD=""
AST_GREP_AVAILABLE=false

detect_ast_grep() {
    if [[ -n "$AST_GREP_CMD" ]]; then
        return 0
    fi

    if command -v ast-grep &> /dev/null; then
        AST_GREP_CMD="ast-grep"
        AST_GREP_AVAILABLE=true
        return 0
    elif command -v sg &> /dev/null; then
        AST_GREP_CMD="sg"
        AST_GREP_AVAILABLE=true
        return 0
    else
        AST_GREP_AVAILABLE=false
        return 1
    fi
}

# ============================================================
# 語言自動偵測
# ============================================================
detect_language() {
    local path="$1"

    # 如果已指定語言，直接返回
    if [[ -n "$LANG" ]]; then
        echo "$LANG"
        return
    fi

    # 基於專案檔案偵測
    if [[ -f "$path/Package.swift" ]] || [[ -d "$path/"*.xcodeproj ]] || [[ -d "$path/"*.xcworkspace ]]; then
        echo "swift"
    elif [[ -f "$path/package.json" ]]; then
        # 檢查是否為 TypeScript
        if [[ -f "$path/tsconfig.json" ]] || grep -q '"typescript"' "$path/package.json" 2>/dev/null; then
            echo "tsx"
        else
            echo "tsx"  # 預設使用 tsx（支援 JS）
        fi
    elif [[ -f "$path/build.gradle" ]] || [[ -f "$path/build.gradle.kts" ]]; then
        echo "kotlin"
    elif [[ -f "$path/requirements.txt" ]] || [[ -f "$path/pyproject.toml" ]] || [[ -f "$path/setup.py" ]]; then
        echo "python"
    elif [[ -f "$path/go.mod" ]]; then
        echo "go"
    elif [[ -f "$path/Cargo.toml" ]]; then
        echo "rust"
    else
        echo "tsx"  # 預設
    fi
}

# ============================================================
# YAML Rule 執行
# ============================================================
run_yaml_rule() {
    local rule_file="$1"

    if [[ -f "$RULES_DIR/$rule_file" ]]; then
        $AST_GREP_CMD scan --rule "$RULES_DIR/$rule_file" --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
    else
        # 規則檔案不存在，返回空
        echo "[]"
    fi
}

run_inline_rule() {
    local rule_content="$1"
    local temp_rule
    temp_rule=$(mktemp /tmp/ast-grep-rule-XXXXXX.yaml)
    echo "$rule_content" > "$temp_rule"
    $AST_GREP_CMD scan --rule "$temp_rule" --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
    rm -f "$temp_rule"
}

# ============================================================
# 函數呼叫追蹤 (call)
# ============================================================
op_call() {
    local func_name="$1"
    local lang
    lang=$(detect_language "$PROJECT_PATH")

    if $FALLBACK_MODE; then
        echo "grep -rn \"$func_name(\" --include=\"*.$lang\" \"$PROJECT_PATH\""
        return 0
    fi

    case "$lang" in
        swift)
            {
                $AST_GREP_CMD --pattern "\$OBJ.$func_name(\$\$\$)" --lang swift --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "$func_name(\$\$\$)" --lang swift --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        tsx|typescript)
            {
                $AST_GREP_CMD --pattern "\$OBJ.$func_name(\$\$\$)" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "$func_name(\$\$\$)" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        kotlin)
            {
                $AST_GREP_CMD --pattern "\$OBJ.$func_name(\$\$\$)" --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "$func_name(\$\$\$)" --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        python)
            {
                $AST_GREP_CMD --pattern "\$OBJ.$func_name(\$\$\$)" --lang python --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "$func_name(\$\$\$)" --lang python --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        *)
            echo "[]"
            ;;
    esac
}

# ============================================================
# 類型引用搜尋 (type)
# ============================================================
op_type() {
    local type_name="$1"
    local lang
    lang=$(detect_language "$PROJECT_PATH")

    if $FALLBACK_MODE; then
        echo "grep -rn \"$type_name\" --include=\"*.$lang\" \"$PROJECT_PATH\" | grep -v \"//.*$type_name\""
        return 0
    fi

    case "$lang" in
        swift)
            {
                # 變數宣告
                $AST_GREP_CMD --pattern "\$VAR: $type_name" --lang swift --json "$PROJECT_PATH" 2>/dev/null
                # 返回類型
                $AST_GREP_CMD --pattern "-> $type_name" --lang swift --json "$PROJECT_PATH" 2>/dev/null
                # 泛型參數
                $AST_GREP_CMD --pattern "<$type_name>" --lang swift --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        tsx|typescript)
            {
                $AST_GREP_CMD --pattern "\$VAR: $type_name" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "as $type_name" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "<$type_name>" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        kotlin)
            {
                # 類型宣告
                $AST_GREP_CMD --pattern "\$VAR: \$\$\$$type_name" --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                # 類繼承
                $AST_GREP_CMD --pattern "class \$NAME : \$\$\$$type_name\$\$\$" --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        *)
            echo "[]"
            ;;
    esac
}

# ============================================================
# 設計模式搜尋 (pattern)
# ============================================================
op_pattern() {
    local pattern_name="$1"
    local lang
    lang=$(detect_language "$PROJECT_PATH")
    local normalized
    normalized=$(echo "$pattern_name" | tr '[:upper:]' '[:lower:]')

    if $FALLBACK_MODE; then
        echo "grep -rn \"$pattern_name\" --include=\"*.$lang\" \"$PROJECT_PATH\""
        return 0
    fi

    case "$lang" in
        swift)
            case "$normalized" in
                "async"|"async function"|"async func")
                    run_inline_rule '
id: swift-async-function
language: Swift
rule:
  kind: function_declaration
  has:
    pattern: async
'
                    ;;
                "await"|"await expression")
                    $AST_GREP_CMD --pattern 'await $EXPR' --lang swift --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                *)
                    echo "[]"
                    exit 2
                    ;;
            esac
            ;;
        tsx|typescript)
            case "$normalized" in
                "hook"|"hooks"|"custom hook")
                    run_inline_rule '
id: tsx-custom-hook
language: Tsx
rule:
  kind: function_declaration
  has:
    kind: identifier
    regex: "^use[A-Z]"
'
                    ;;
                "usestate"|"state")
                    $AST_GREP_CMD --pattern 'useState($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "useeffect"|"effect")
                    $AST_GREP_CMD --pattern 'useEffect($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                *)
                    echo "[]"
                    exit 2
                    ;;
            esac
            ;;
        kotlin)
            case "$normalized" in
                "suspend"|"suspend function"|"coroutine")
                    $AST_GREP_CMD --pattern 'suspend fun $NAME' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "data class")
                    $AST_GREP_CMD --pattern 'data class $NAME' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "composable"|"compose")
                    $AST_GREP_CMD --pattern '@Composable' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                *)
                    echo "[]"
                    exit 2
                    ;;
            esac
            ;;
        *)
            echo "[]"
            exit 2
            ;;
    esac
}

# ============================================================
# API 使用盤點 (usage)
# ============================================================
op_usage() {
    local api_name="$1"
    local lang
    lang=$(detect_language "$PROJECT_PATH")

    if $FALLBACK_MODE; then
        echo "grep -rn \"$api_name\" --include=\"*.$lang\" \"$PROJECT_PATH\""
        return 0
    fi

    # 對於常見 API，使用精確 pattern
    case "$api_name" in
        "useEffect"|"useState"|"useCallback"|"useMemo"|"useRef")
            $AST_GREP_CMD --pattern "$api_name(\$\$\$)" --lang tsx --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
            ;;
        "fetch")
            $AST_GREP_CMD --pattern 'fetch($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
            ;;
        "axios")
            {
                $AST_GREP_CMD --pattern 'axios($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'axios.$METHOD($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        *)
            # 通用 pattern
            $AST_GREP_CMD --pattern "$api_name(\$\$\$)" --lang "$lang" --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
            ;;
    esac
}

# ============================================================
# async/await 流程追蹤 (async)
# ============================================================
op_async() {
    local lang
    lang=$(detect_language "$PROJECT_PATH")

    if $FALLBACK_MODE; then
        case "$lang" in
            swift) echo "grep -rn 'await ' --include='*.swift' \"$PROJECT_PATH\"" ;;
            tsx) echo "grep -rn 'await ' --include='*.ts' --include='*.tsx' \"$PROJECT_PATH\"" ;;
            kotlin) echo "grep -rn 'suspend fun' --include='*.kt' \"$PROJECT_PATH\"" ;;
            python) echo "grep -rn 'await ' --include='*.py' \"$PROJECT_PATH\"" ;;
        esac
        return 0
    fi

    case "$lang" in
        swift)
            {
                $AST_GREP_CMD --pattern 'await $EXPR' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'async let $NAME = $EXPR' --lang swift --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        tsx|typescript)
            {
                $AST_GREP_CMD --pattern 'await $EXPR' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'async function $NAME($$$) { $$$ }' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        kotlin)
            {
                $AST_GREP_CMD --pattern 'suspend fun $NAME' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'withContext($$$) { $$$ }' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'launch { $$$ }' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        python)
            {
                $AST_GREP_CMD --pattern 'await $EXPR' --lang python --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'async def $NAME($$$):' --lang python --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        *)
            echo "[]"
            ;;
    esac
}

# ============================================================
# 邊界偵測 (boundary)
# ============================================================
op_boundary() {
    local boundary_type="$1"
    local lang
    lang=$(detect_language "$PROJECT_PATH")

    if $FALLBACK_MODE; then
        case "$boundary_type" in
            "api") echo "grep -rn 'fetch\\|axios\\|URLSession\\|Retrofit' \"$PROJECT_PATH\"" ;;
            "db") echo "grep -rn 'prisma\\|realm\\|CoreData\\|Room' \"$PROJECT_PATH\"" ;;
        esac
        return 0
    fi

    case "$boundary_type" in
        "api")
            case "$lang" in
                swift)
                    {
                        $AST_GREP_CMD --pattern 'URLSession.shared.dataTask($$$)' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'URLSession.shared.data($$$)' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                tsx|typescript)
                    {
                        $AST_GREP_CMD --pattern 'fetch($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'axios.$METHOD($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                kotlin)
                    {
                        $AST_GREP_CMD --pattern 'Retrofit.create($$$)' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'OkHttpClient()' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                *)
                    echo "[]"
                    ;;
            esac
            ;;
        "db")
            case "$lang" in
                swift)
                    {
                        $AST_GREP_CMD --pattern '$CTX.fetch($$$)' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'realm.write { $$$ }' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                tsx|typescript)
                    {
                        $AST_GREP_CMD --pattern 'prisma.$MODEL.findUnique($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'prisma.$MODEL.findMany($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                kotlin)
                    {
                        $AST_GREP_CMD --pattern '@Query($$$)' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern '@Insert' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                *)
                    echo "[]"
                    ;;
            esac
            ;;
        *)
            echo "[]"
            exit 2
            ;;
    esac
}

# ============================================================
# 輸出處理
# ============================================================
process_output() {
    local result="$1"

    if $OUTPUT_COUNT; then
        echo "$result" | jq 'length'
    elif $OUTPUT_JSON; then
        echo "$result"
    else
        # 簡化輸出：file:line
        echo "$result" | jq -r '.[] | "\(.file):\(.range.start.line)"' 2>/dev/null || echo "$result"
    fi
}

# ============================================================
# 參數解析
# ============================================================
OPERATION=""
TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang)
            LANG="$2"
            shift 2
            ;;
        --path)
            PROJECT_PATH="$2"
            shift 2
            ;;
        --fallback)
            FALLBACK_MODE=true
            shift
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        --count)
            OUTPUT_COUNT=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 <operation> <target> [options]"
            echo ""
            echo "Operations:"
            echo "  call <function>     - Function call tracing"
            echo "  type <typename>     - Type reference search"
            echo "  pattern <pattern>   - Design pattern search"
            echo "  usage <api>         - API usage inventory"
            echo "  async               - Async/await flow tracing"
            echo "  boundary <type>     - Boundary detection (api|db)"
            echo ""
            echo "Options:"
            echo "  --lang <language>   - Specify language (swift|tsx|kotlin|python)"
            echo "  --path <path>       - Project path (default: .)"
            echo "  --fallback          - Output grep fallback command"
            echo "  --json              - JSON output format"
            echo "  --count             - Output match count only"
            exit 0
            ;;
        *)
            if [[ -z "$OPERATION" ]]; then
                OPERATION="$1"
            elif [[ -z "$TARGET" ]]; then
                TARGET="$1"
            fi
            shift
            ;;
    esac
done

# ============================================================
# 主程式
# ============================================================

# 檢查必要參數
if [[ -z "$OPERATION" ]]; then
    echo "Error: Operation required" >&2
    echo "Usage: $0 <operation> <target> [options]" >&2
    exit 3
fi

# 非 fallback 模式下檢查 ast-grep
if ! $FALLBACK_MODE; then
    if ! detect_ast_grep; then
        echo "Error: ast-grep not installed. Use --fallback for grep alternative." >&2
        exit 1
    fi
fi

# 執行操作
case "$OPERATION" in
    call)
        [[ -z "$TARGET" ]] && { echo "Error: Function name required" >&2; exit 3; }
        result=$(op_call "$TARGET")
        ;;
    type)
        [[ -z "$TARGET" ]] && { echo "Error: Type name required" >&2; exit 3; }
        result=$(op_type "$TARGET")
        ;;
    pattern)
        [[ -z "$TARGET" ]] && { echo "Error: Pattern name required" >&2; exit 3; }
        result=$(op_pattern "$TARGET")
        ;;
    usage)
        [[ -z "$TARGET" ]] && { echo "Error: API name required" >&2; exit 3; }
        result=$(op_usage "$TARGET")
        ;;
    async)
        result=$(op_async)
        ;;
    boundary)
        [[ -z "$TARGET" ]] && { echo "Error: Boundary type required (api|db)" >&2; exit 3; }
        result=$(op_boundary "$TARGET")
        ;;
    *)
        echo "Error: Unknown operation: $OPERATION" >&2
        exit 2
        ;;
esac

# 輸出結果
if ! $FALLBACK_MODE; then
    process_output "$result"
fi
