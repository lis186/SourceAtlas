#!/bin/bash
# ast-grep-flow.sh - Flow 分析專用的 AST 搜尋
#
# 專為 /atlas.flow 設計，提供：
# 1. 函數呼叫追蹤（排除註解和字串）
# 2. async/await 流程識別
# 3. Boundary 偵測（API、DB、第三方）
#
# 使用方式：
#   ./ast-grep-flow.sh <operation> <target> <project_type> <project_path>
#
# Operations:
#   call <function_name>   - 追蹤函數呼叫
#   async                  - 追蹤 async/await 流程
#   boundary <type>        - 偵測邊界（api, db, third-party）
#   entry <keyword>        - 尋找入口點

set -euo pipefail

OPERATION="${1:-}"
TARGET="${2:-}"
PROJECT_TYPE="${3:-}"
PROJECT_PATH="${4:-.}"

# 偵測 ast-grep
detect_ast_grep() {
    if command -v ast-grep &> /dev/null; then
        echo "ast-grep"
    elif command -v sg &> /dev/null; then
        echo "sg"
    else
        return 1
    fi
}

AST_GREP_CMD=$(detect_ast_grep) || exit 1

# ============================================================
# 函數呼叫追蹤
# ============================================================
trace_function_call() {
    local func_name="$1"
    local lang="$2"

    case "$lang" in
        swift)
            # Swift: 方法呼叫 obj.method() 或 method()
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
# Async/Await 流程追蹤
# ============================================================
trace_async_flow() {
    local lang="$1"

    case "$lang" in
        swift)
            # Swift async/await
            {
                $AST_GREP_CMD --pattern 'await $EXPR' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'async let $NAME = $EXPR' --lang swift --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        tsx|typescript)
            # TypeScript async/await
            {
                $AST_GREP_CMD --pattern 'await $EXPR' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern 'async function $NAME($$$) { $$$ }' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        kotlin)
            # Kotlin coroutines
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
# Boundary 偵測（API、DB、第三方服務）
# ============================================================
detect_boundary() {
    local boundary_type="$1"
    local lang="$2"

    case "$boundary_type" in
        api)
            case "$lang" in
                swift)
                    {
                        $AST_GREP_CMD --pattern 'URLSession.shared.dataTask($$$)' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'URLSession.shared.data($$$)' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'AF.request($$$)' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'Alamofire.request($$$)' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                tsx|typescript)
                    {
                        $AST_GREP_CMD --pattern 'fetch($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'axios.$METHOD($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'axios($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
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
                *)
                    echo "[]"
                    ;;
            esac
            ;;
        db)
            case "$lang" in
                swift)
                    {
                        # Core Data
                        $AST_GREP_CMD --pattern '$CTX.fetch($$$)' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern '$CTX.save()' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                        # Realm
                        $AST_GREP_CMD --pattern 'realm.write { $$$ }' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'realm.objects($$$)' --lang swift --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                tsx|typescript)
                    {
                        # Prisma
                        $AST_GREP_CMD --pattern 'prisma.$MODEL.findUnique($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'prisma.$MODEL.findMany($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern 'prisma.$MODEL.create($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                        # TypeORM
                        $AST_GREP_CMD --pattern '$REPO.find($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern '$REPO.save($$$)' --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                kotlin)
                    {
                        # Room
                        $AST_GREP_CMD --pattern '@Query($$$)' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern '@Insert' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern '@Delete' --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                python)
                    {
                        # SQLAlchemy
                        $AST_GREP_CMD --pattern '$SESSION.query($$$)' --lang python --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern '$SESSION.add($$$)' --lang python --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern '$SESSION.commit()' --lang python --json "$PROJECT_PATH" 2>/dev/null
                        # Django ORM
                        $AST_GREP_CMD --pattern '$MODEL.objects.filter($$$)' --lang python --json "$PROJECT_PATH" 2>/dev/null
                        $AST_GREP_CMD --pattern '$MODEL.objects.get($$$)' --lang python --json "$PROJECT_PATH" 2>/dev/null
                    } | jq -s 'add // []'
                    ;;
                *)
                    echo "[]"
                    ;;
            esac
            ;;
        *)
            echo "[]"
            ;;
    esac
}

# ============================================================
# 入口點搜尋
# ============================================================
find_entry_points() {
    local keyword="$1"
    local lang="$2"

    case "$lang" in
        swift)
            {
                # 函數定義
                $AST_GREP_CMD --pattern "func $keyword" --lang swift --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "func ${keyword}(" --lang swift --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        tsx|typescript)
            {
                # 函數/方法定義
                $AST_GREP_CMD --pattern "function $keyword" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "const $keyword = " --lang tsx --json "$PROJECT_PATH" 2>/dev/null
                $AST_GREP_CMD --pattern "$keyword(" --lang tsx --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        kotlin)
            {
                $AST_GREP_CMD --pattern "fun $keyword" --lang kotlin --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        python)
            {
                $AST_GREP_CMD --pattern "def $keyword" --lang python --json "$PROJECT_PATH" 2>/dev/null
            } | jq -s 'add // []'
            ;;
        *)
            echo "[]"
            ;;
    esac
}

# ============================================================
# 主程式路由
# ============================================================
map_project_type_to_lang() {
    case "$1" in
        swift|ios) echo "swift" ;;
        typescript|react|nextjs|vue|tsx) echo "tsx" ;;
        kotlin|android) echo "kotlin" ;;
        python|django|fastapi|flask) echo "python" ;;
        *) echo "$1" ;;
    esac
}

LANG=$(map_project_type_to_lang "$PROJECT_TYPE")

case "$OPERATION" in
    call)
        trace_function_call "$TARGET" "$LANG"
        ;;
    async)
        trace_async_flow "$LANG"
        ;;
    boundary)
        detect_boundary "$TARGET" "$LANG"
        ;;
    entry)
        find_entry_points "$TARGET" "$LANG"
        ;;
    *)
        echo "Usage: $0 <call|async|boundary|entry> <target> <project_type> <project_path>"
        exit 1
        ;;
esac
