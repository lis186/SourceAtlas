#!/bin/bash
# ast-grep-search.sh - SourceAtlas 統一 AST 搜尋入口
#
# 設計原則：
# 1. 單一入口 - 所有 atlas 命令通過此腳本使用 ast-grep
# 2. 優雅降級 - ast-grep 不可用時提供 grep fallback 命令
# 3. 效能優先 - 快取偵測結果，避免重複檢查
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
#   definition <name>      - 定義搜尋 (for /atlas.flow)
#   import [module]        - Import 語句提取 (for /atlas.flow, /atlas.impact)
#
# Options:
#   --lang <language>      - 指定語言 (swift|tsx|kotlin|python|go|rust|ruby)
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
    elif [[ -f "$path/Gemfile" ]] || [[ -f "$path/config.ru" ]]; then
        echo "ruby"
    else
        echo "tsx"  # 預設
    fi
}

# ============================================================
# Inline Rule 執行
# ============================================================
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
        go)
            {
                $AST_GREP_CMD --pattern "\$OBJ.$func_name(\$\$\$)" --lang go --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "$func_name(\$\$\$)" --lang go --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        rust)
            {
                $AST_GREP_CMD --pattern "\$OBJ.$func_name(\$\$\$)" --lang rust --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "$func_name(\$\$\$)" --lang rust --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        ruby)
            {
                $AST_GREP_CMD --pattern "\$OBJ.$func_name(\$\$\$)" --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "$func_name(\$\$\$)" --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "$func_name \$\$\$" --lang ruby --json "$PROJECT_PATH" 2>/dev/null
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
        python)
            {
                # 類型標註
                $AST_GREP_CMD --pattern "\$VAR: $type_name" --lang python --json "$PROJECT_PATH" 2>/dev/null
                # 返回類型
                $AST_GREP_CMD --pattern "-> $type_name" --lang python --json "$PROJECT_PATH" 2>/dev/null
                # 類繼承
                $AST_GREP_CMD --pattern "class \$NAME($type_name)" --lang python --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        go)
            {
                # 變數宣告
                $AST_GREP_CMD --pattern "var \$VAR $type_name" --lang go --json "$PROJECT_PATH" 2>/dev/null
                # 函數參數/返回類型
                $AST_GREP_CMD --pattern "\$VAR $type_name" --lang go --json "$PROJECT_PATH" 2>/dev/null
                # 指標類型
                $AST_GREP_CMD --pattern "*$type_name" --lang go --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        rust)
            {
                # 變數宣告
                $AST_GREP_CMD --pattern "let \$VAR: $type_name" --lang rust --json "$PROJECT_PATH" 2>/dev/null
                # 返回類型
                $AST_GREP_CMD --pattern "-> $type_name" --lang rust --json "$PROJECT_PATH" 2>/dev/null
                # impl
                $AST_GREP_CMD --pattern "impl $type_name" --lang rust --json "$PROJECT_PATH" 2>/dev/null
                # 泛型
                $AST_GREP_CMD --pattern "<$type_name>" --lang rust --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        ruby)
            {
                # Ruby 是動態類型，搜尋類定義和模組
                $AST_GREP_CMD --pattern "class $type_name" --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "module $type_name" --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "$type_name.new" --lang ruby --json "$PROJECT_PATH" 2>/dev/null
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
        python)
            case "$normalized" in
                "async"|"async function"|"async def")
                    $AST_GREP_CMD --pattern 'async def $NAME' --lang python --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "decorator"|"decorators")
                    $AST_GREP_CMD --pattern '@$DECORATOR' --lang python --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "class"|"dataclass")
                    $AST_GREP_CMD --pattern '@dataclass' --lang python --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                *)
                    echo "[]"
                    exit 2
                    ;;
            esac
            ;;
        go)
            case "$normalized" in
                "goroutine"|"go routine"|"concurrent")
                    $AST_GREP_CMD --pattern 'go $FUNC($$$)' --lang go --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "channel"|"chan")
                    $AST_GREP_CMD --pattern 'chan $TYPE' --lang go --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "interface")
                    $AST_GREP_CMD --pattern 'type $NAME interface { $$$ }' --lang go --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "struct")
                    $AST_GREP_CMD --pattern 'type $NAME struct { $$$ }' --lang go --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "defer")
                    $AST_GREP_CMD --pattern 'defer $EXPR' --lang go --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                *)
                    echo "[]"
                    exit 2
                    ;;
            esac
            ;;
        rust)
            case "$normalized" in
                "async"|"async function"|"async fn")
                    $AST_GREP_CMD --pattern 'async fn $NAME' --lang rust --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "await")
                    $AST_GREP_CMD --pattern '$EXPR.await' --lang rust --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "trait")
                    $AST_GREP_CMD --pattern 'trait $NAME' --lang rust --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "impl"|"implementation")
                    $AST_GREP_CMD --pattern 'impl $TYPE' --lang rust --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "macro"|"macros")
                    $AST_GREP_CMD --pattern '$NAME!' --lang rust --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "derive")
                    $AST_GREP_CMD --pattern '#[derive($$$)]' --lang rust --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                *)
                    echo "[]"
                    exit 2
                    ;;
            esac
            ;;
        ruby)
            case "$normalized" in
                "class")
                    $AST_GREP_CMD --pattern 'class $NAME' --lang ruby --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "module")
                    $AST_GREP_CMD --pattern 'module $NAME' --lang ruby --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "def"|"method"|"function")
                    $AST_GREP_CMD --pattern 'def $NAME' --lang ruby --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "block"|"do block")
                    $AST_GREP_CMD --pattern 'do $$$' --lang ruby --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
                    ;;
                "attr"|"attr_accessor")
                    $AST_GREP_CMD --pattern 'attr_accessor $$$' --lang ruby --json "$PROJECT_PATH" 2>/dev/null || echo "[]"
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
            go) echo "grep -rn 'go func\\|go \\w' --include='*.go' \"$PROJECT_PATH\"" ;;
            rust) echo "grep -rn '\\.await\\|async fn' --include='*.rs' \"$PROJECT_PATH\"" ;;
            ruby) echo "grep -rn 'Thread.new\\|async' --include='*.rb' \"$PROJECT_PATH\"" ;;
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
        go)
            {
                # Go 使用 goroutine 而非 async/await
                $AST_GREP_CMD --pattern 'go $FUNC($$$)' --lang go --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'go func() { $$$ }()' --lang go --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern '<-$CHAN' --lang go --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        rust)
            {
                $AST_GREP_CMD --pattern '$EXPR.await' --lang rust --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'async fn $NAME' --lang rust --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'async move { $$$ }' --lang rust --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        ruby)
            {
                # Ruby 使用 Thread 或 async gem
                $AST_GREP_CMD --pattern 'Thread.new { $$$ }' --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'Async { $$$ }' --lang ruby --json "$PROJECT_PATH" 2>/dev/null
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
                python)
                    {
                        $AST_GREP_CMD --pattern 'requests.$METHOD($$$)' --lang python --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'httpx.$METHOD($$$)' --lang python --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'aiohttp.$METHOD($$$)' --lang python --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                go)
                    {
                        $AST_GREP_CMD --pattern 'http.Get($$$)' --lang go --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'http.Post($$$)' --lang go --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'client.Do($$$)' --lang go --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                rust)
                    {
                        $AST_GREP_CMD --pattern 'reqwest::get($$$)' --lang rust --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'client.get($$$)' --lang rust --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'hyper::Client' --lang rust --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                ruby)
                    {
                        $AST_GREP_CMD --pattern 'Net::HTTP.$METHOD($$$)' --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'HTTParty.$METHOD($$$)' --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'Faraday.$METHOD($$$)' --lang ruby --json "$PROJECT_PATH" 2>/dev/null
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
                python)
                    {
                        $AST_GREP_CMD --pattern 'session.query($$$)' --lang python --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern '$MODEL.objects.$METHOD($$$)' --lang python --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                go)
                    {
                        $AST_GREP_CMD --pattern 'db.Query($$$)' --lang go --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'db.Exec($$$)' --lang go --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'gorm.Open($$$)' --lang go --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                rust)
                    {
                        $AST_GREP_CMD --pattern 'diesel::$METHOD($$$)' --lang rust --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'sqlx::query($$$)' --lang rust --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                ruby)
                    {
                        $AST_GREP_CMD --pattern '$MODEL.find($$$)' --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern '$MODEL.where($$$)' --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'ActiveRecord::Base.$METHOD($$$)' --lang ruby --json "$PROJECT_PATH" 2>/dev/null
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
# 定義搜尋 (definition) - 找 top-level 定義
# ============================================================
op_definition() {
    local name="$1"
    local lang
    lang=$(detect_language "$PROJECT_PATH")

    if $FALLBACK_MODE; then
        case "$lang" in
            swift) echo "grep -rn 'func $name\\|class $name\\|struct $name\\|enum $name' --include='*.swift' \"$PROJECT_PATH\"" ;;
            tsx|typescript) echo "grep -rn 'function $name\\|class $name\\|const $name\\|interface $name\\|type $name' --include='*.ts' --include='*.tsx' \"$PROJECT_PATH\"" ;;
            kotlin) echo "grep -rn 'fun $name\\|class $name\\|object $name\\|data class $name' --include='*.kt' \"$PROJECT_PATH\"" ;;
            python) echo "grep -rn '^def $name\\|^class $name' --include='*.py' \"$PROJECT_PATH\"" ;;
            go) echo "grep -rn 'func $name\\|type $name struct\\|type $name interface' --include='*.go' \"$PROJECT_PATH\"" ;;
            rust) echo "grep -rn 'fn $name\\|struct $name\\|enum $name\\|trait $name' --include='*.rs' \"$PROJECT_PATH\"" ;;
            ruby) echo "grep -rn 'def $name\\|class $name\\|module $name' --include='*.rb' \"$PROJECT_PATH\"" ;;
        esac
        return 0
    fi

    case "$lang" in
        swift)
            {
                $AST_GREP_CMD --pattern "func $name(\$\$\$)" --lang swift --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "class $name" --lang swift --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "struct $name" --lang swift --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "enum $name" --lang swift --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        tsx|typescript)
            {
                $AST_GREP_CMD --pattern "function $name(\$\$\$)" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "class $name" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "const $name = \$\$\$" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "interface $name" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "type $name = \$\$\$" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "export function $name(\$\$\$)" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "export class $name" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "export const $name = \$\$\$" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        kotlin)
            {
                $AST_GREP_CMD --pattern "fun $name(\$\$\$)" --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "class $name" --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "object $name" --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "data class $name" --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        python)
            {
                $AST_GREP_CMD --pattern "def $name(\$\$\$):" --lang python --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "class $name:" --lang python --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "class $name(\$\$\$):" --lang python --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        go)
            {
                $AST_GREP_CMD --pattern "func $name(\$\$\$)" --lang go --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "type $name struct { \$\$\$ }" --lang go --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "type $name interface { \$\$\$ }" --lang go --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        rust)
            {
                $AST_GREP_CMD --pattern "fn $name(\$\$\$)" --lang rust --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "pub fn $name(\$\$\$)" --lang rust --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "struct $name" --lang rust --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "enum $name" --lang rust --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "trait $name" --lang rust --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        ruby)
            {
                $AST_GREP_CMD --pattern "def $name" --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "class $name" --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "module $name" --lang ruby --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        *)
            echo "[]"
            exit 2
            ;;
    esac
}

# ============================================================
# Import 語句提取 (import) - 支援可選過濾
# ============================================================
op_import() {
    local module="$1"  # 可選
    local lang
    lang=$(detect_language "$PROJECT_PATH")

    if $FALLBACK_MODE; then
        case "$lang" in
            swift) echo "grep -rn '^import ' --include='*.swift' \"$PROJECT_PATH\"" ;;
            tsx|typescript) echo "grep -rn '^import \\|require(' --include='*.ts' --include='*.tsx' \"$PROJECT_PATH\"" ;;
            kotlin) echo "grep -rn '^import ' --include='*.kt' \"$PROJECT_PATH\"" ;;
            python) echo "grep -rn '^import \\|^from .* import' --include='*.py' \"$PROJECT_PATH\"" ;;
            go) echo "grep -rn '^import ' --include='*.go' \"$PROJECT_PATH\"" ;;
            rust) echo "grep -rn '^use \\|^mod ' --include='*.rs' \"$PROJECT_PATH\"" ;;
            ruby) echo "grep -rn \"require \\|require_relative \" --include='*.rb' \"$PROJECT_PATH\"" ;;
        esac
        return 0
    fi

    local result
    case "$lang" in
        swift)
            result=$($AST_GREP_CMD --pattern 'import $MODULE' --lang swift --json "$PROJECT_PATH" 2>/dev/null || echo "[]")
            ;;
        tsx|typescript)
            result=$({
                $AST_GREP_CMD --pattern 'import $$$ from "$SOURCE"' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "import $$$ from '\$SOURCE'" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'import "$SOURCE"' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'require("$SOURCE")' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "require('\$SOURCE')" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []')
            ;;
        kotlin)
            result=$($AST_GREP_CMD --pattern 'import $PACKAGE' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null || echo "[]")
            ;;
        python)
            result=$({
                $AST_GREP_CMD --pattern 'import $MODULE' --lang python --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'from $MODULE import $$$' --lang python --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []')
            ;;
        go)
            result=$({
                $AST_GREP_CMD --pattern 'import "$PKG"' --lang go --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'import ( $$$ )' --lang go --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []')
            ;;
        rust)
            result=$({
                $AST_GREP_CMD --pattern 'use $PATH' --lang rust --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'mod $NAME' --lang rust --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'extern crate $NAME' --lang rust --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []')
            ;;
        ruby)
            result=$({
                $AST_GREP_CMD --pattern 'require "$FILE"' --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "require '\$FILE'" --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'require_relative "$FILE"' --lang ruby --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "require_relative '\$FILE'" --lang ruby --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []')
            ;;
        *)
            echo "[]"
            exit 2
            ;;
    esac

    # 可選過濾：若提供 module 參數，只返回包含該 module 的 import
    if [[ -n "$module" ]]; then
        echo "$result" | jq --arg m "$module" '[.[] | select(.text | contains($m))]'
    else
        echo "$result"
    fi
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
    definition)
        [[ -z "$TARGET" ]] && { echo "Error: Definition name required" >&2; exit 3; }
        result=$(op_definition "$TARGET")
        ;;
    import)
        # TARGET 是可選的（用於過濾特定 module）
        result=$(op_import "$TARGET")
        ;;
    *)
        echo "Error: Unknown operation: $OPERATION" >&2
        exit 2
        ;;
esac

# 輸出結果
if $FALLBACK_MODE; then
    # Fallback 模式：直接輸出 grep 命令（result 已經是 grep 命令字串）
    echo "$result"
else
    # 正常模式：處理 JSON 輸出
    process_output "$result"
fi
