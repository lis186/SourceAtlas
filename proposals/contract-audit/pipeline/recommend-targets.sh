#!/bin/bash
# SourceAtlas - 審計目標推薦腳本
#
# 整合檔案複雜度、git 變動頻率（hotspot）、耦合度分析，
# 綜合排序推薦最值得進行行為合約審計的檔案。
#
# 注意：此腳本中的「熵值」是以行數作為複雜度的近似指標，
# 並非資訊理論中的 Shannon 熵。若需真正的資訊理論熵值分析，
# 請使用 scripts/atlas/scan-entropy.sh。
#
# 評分公式：score = complexity_rank * 0.4 + hotspot_rank * 0.4 + coupling_rank * 0.2
# （排名越前面分數越高）
#
# 依賴：bash, git, rg, awk, sort
#
# 用法：
#   ./recommend-targets.sh [選項] [目標目錄]
#
# 選項：
#   --top N          顯示前 N 個推薦目標（預設 5）
#   --language <lang> 只分析指定語言（如 ts, py, go, swift, objc, java, kt, rs）
#   --path <dir>     指定掃描目錄（等同位置參數）
#   -h, --help       顯示此說明
#
# 範例：
#   ./recommend-targets.sh --top 10 --language ts /path/to/project
#   ./recommend-targets.sh --language swift .

set -euo pipefail

# -- 預設值 --
TOP_N=5
LANGUAGE=""
TARGET_DIR=""

# -- 暫存目錄 --
TMPDIR_WORK=""

cleanup() {
    if [ -n "$TMPDIR_WORK" ] && [ -d "$TMPDIR_WORK" ]; then
        rm -rf "$TMPDIR_WORK"
    fi
}
trap cleanup EXIT

# -- 使用說明 --
usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
    echo ""
    echo "用法："
    echo "  $(basename "$0") [選項] [目標目錄]"
    echo ""
    echo "選項："
    echo "  --top N            顯示前 N 個推薦目標（預設 5）"
    echo "  --language <lang>  只分析指定語言"
    echo "                     支援: ts, js, py, go, swift, objc, java, kt, rs, rb, php"
    echo "  --path <dir>       指定掃描目錄"
    echo "  -h, --help         顯示此說明"
    echo ""
    echo "注意：複雜度分析使用行數作為近似指標，非資訊理論熵值。"
    echo "      若需真正的熵值分析，請使用 scripts/atlas/scan-entropy.sh。"
}

# -- 參數解析 --
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --top)
                shift
                TOP_N="${1:?'--top 需要一個數字參數'}"
                ;;
            --language)
                shift
                LANGUAGE="${1:?'--language 需要指定語言'}"
                ;;
            --path)
                shift
                TARGET_DIR="${1:?'--path 需要指定目錄'}"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                echo "錯誤：未知選項 '$1'" >&2
                usage >&2
                exit 1
                ;;
            *)
                TARGET_DIR="$1"
                ;;
        esac
        shift
    done

    # 預設為當前目錄
    TARGET_DIR="${TARGET_DIR:-.}"

    # 驗證目錄存在
    if [ ! -d "$TARGET_DIR" ]; then
        echo "錯誤：目錄不存在 '$TARGET_DIR'" >&2
        exit 1
    fi

    # 轉為絕對路徑
    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
}

# -- 語言副檔名對照 --
get_language_glob() {
    local lang="$1"
    case "$lang" in
        ts|typescript)   echo "*.ts" ;;
        js|javascript)   echo "*.js" ;;
        py|python)       echo "*.py" ;;
        go)              echo "*.go" ;;
        swift)           echo "*.swift" ;;
        objc)            echo "*.m" ;;
        java)            echo "*.java" ;;
        kt|kotlin)       echo "*.kt" ;;
        rs|rust)         echo "*.rs" ;;
        rb|ruby)         echo "*.rb" ;;
        php)             echo "*.php" ;;
        *)
            echo "錯誤：不支援的語言 '$lang'" >&2
            echo "支援: ts, js, py, go, swift, objc, java, kt, rs, rb, php" >&2
            exit 1
            ;;
    esac
}

# -- 取得語言的 import 模式 --
get_import_pattern() {
    local lang="$1"
    case "$lang" in
        ts|typescript|js|javascript)
            echo '(import\s+.*from\s+|require\s*\()'
            ;;
        py|python)
            echo '(^import\s+|^from\s+\S+\s+import)'
            ;;
        go)
            echo '^import\s'
            ;;
        swift)
            echo '^import\s'
            ;;
        objc)
            echo '(#import\s+|#include\s+)'
            ;;
        java|kt|kotlin)
            echo '^import\s'
            ;;
        rs|rust)
            echo '(^use\s+|^extern\s+crate)'
            ;;
        rb|ruby)
            echo '(^require\s|^require_relative\s)'
            ;;
        php)
            echo '(^use\s+|^require\s|^include\s)'
            ;;
        "")
            # 通用模式：涵蓋主要語言的 import/require/include
            echo '(^import\s|^from\s+\S+\s+import|require\s*\(|#import\s|#include\s|^use\s)'
            ;;
        *)
            echo '(^import\s|require|#include|^use\s)'
            ;;
    esac
}

# -- 收集原始碼檔案清單 --
collect_files() {
    local file_list="$1"

    # 排除的目錄模式
    local exclude_dirs=(
        ".git"
        "node_modules"
        ".venv"
        "venv"
        "__pycache__"
        ".next"
        "dist"
        "build"
        "vendor"
        ".sourceatlas"
        "*.min.js"
        "*.min.css"
        "*.map"
    )

    local rg_args=("--files")

    # 加入排除目錄
    for dir in "${exclude_dirs[@]}"; do
        rg_args+=("--glob" "!$dir")
    done

    # 如果指定了語言，只搜尋該語言的檔案
    if [ -n "$LANGUAGE" ]; then
        local glob
        glob=$(get_language_glob "$LANGUAGE")
        rg_args+=("--glob" "$glob")
    else
        # 預設只搜尋原始碼檔案
        rg_args+=("--glob" "*.ts" "--glob" "*.tsx" "--glob" "*.js" "--glob" "*.jsx"
                  "--glob" "*.py" "--glob" "*.go" "--glob" "*.swift" "--glob" "*.m"
                  "--glob" "*.h" "--glob" "*.java" "--glob" "*.kt" "--glob" "*.rs"
                  "--glob" "*.rb" "--glob" "*.php" "--glob" "*.c" "--glob" "*.cpp"
                  "--glob" "*.cs" "--glob" "*.vue" "--glob" "*.svelte")
    fi

    rg "${rg_args[@]}" "$TARGET_DIR" 2>/dev/null | sort > "$file_list"
}

# -- 階段 1：檔案複雜度分析 --
# 此處使用行數作為複雜度近似指標，非資訊理論中的熵值。
# 行數越多通常表示邏輯越複雜，越需要審計。
# 若需真正的資訊理論熵值，可呼叫 scripts/atlas/scan-entropy.sh。
analyze_complexity() {
    local file_list="$1"
    local output="$2"

    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local lines
            lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
            echo "$lines $file"
        fi
    done < "$file_list" | sort -rn > "$output"
}

# -- 階段 2：git hotspot 分析 --
# 統計每個檔案在 git 歷史中的變動次數
analyze_hotspot() {
    local file_list="$1"
    local output="$2"

    # 確認目標目錄在 git 管理下
    if ! git -C "$TARGET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "警告：目標目錄不在 git 管理下，跳過 hotspot 分析" >&2
        # 所有檔案給予相同的 hotspot 計數 0
        while IFS= read -r file; do
            echo "0 $file"
        done < "$file_list" > "$output"
        return
    fi

    # 取得 git 根目錄，用於計算相對路徑
    local git_root
    git_root=$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null)

    # 用 git log 統計每個檔案的 commit 次數
    # 限制搜尋範圍以提高效能（最近 1 年）
    git -C "$git_root" log --since="1 year ago" --pretty=format: --name-only 2>/dev/null \
        | sort \
        | uniq -c \
        | sort -rn \
        | awk 'NF >= 2 {print $0}' > "${output}.raw"

    # 將 git 路徑對應回完整路徑
    while IFS= read -r file; do
        local rel_path
        rel_path="${file#$git_root/}"
        local count
        count=$(awk -v f="$rel_path" '$2 == f {print $1; found=1; exit} END {if (!found) print 0}' "${output}.raw")
        echo "${count:-0} $file"
    done < "$file_list" | sort -rn > "$output"

    rm -f "${output}.raw"
}

# -- 階段 3：耦合度分析 --
# 統計每個檔案被其他檔案引用的次數
# 最佳化：先用 rg 一次性擷取所有 import/require 行，再用 awk 批次統計
analyze_coupling() {
    local file_list="$1"
    local output="$2"

    local import_pattern
    import_pattern=$(get_import_pattern "$LANGUAGE")

    # 建立檔名（不含副檔名）到完整路徑的對照表
    local name_map="${output}.namemap"
    while IFS= read -r file; do
        local bname
        bname=$(basename "$file" | sed 's/\.[^.]*$//')
        echo "$bname $file"
    done < "$file_list" > "$name_map"

    # 一次性擷取所有 import/require/include 行
    local all_imports="${output}.imports"
    rg --no-filename --glob '!.git' --glob '!node_modules' --glob '!.venv' --glob '!__pycache__' \
        "$import_pattern" "$TARGET_DIR" 2>/dev/null > "$all_imports" || true

    # 對每個檔案名統計被引用次數
    while IFS=' ' read -r bname file; do
        local count
        # 對常見名稱（index, main 等）用完整檔名搜尋
        if echo "$bname" | grep -qE '^(index|main|app|server|mod|lib|init|__init__)$'; then
            local fullname
            fullname=$(basename "$file")
            count=$(grep -c "$fullname" "$all_imports" 2>/dev/null || echo 0)
        else
            count=$(grep -c "$bname" "$all_imports" 2>/dev/null || echo 0)
        fi
        echo "$count $file"
    done < "$name_map" | sort -rn > "$output"

    rm -f "$name_map" "$all_imports"
}

# -- 綜合排序 --
compute_scores() {
    local complexity_file="$1"
    local hotspot_file="$2"
    local coupling_file="$3"
    local output="$4"

    local total_files
    total_files=$(wc -l < "$complexity_file" | tr -d ' ')

    if [ "$total_files" -eq 0 ]; then
        echo "錯誤：沒有找到任何原始碼檔案" >&2
        exit 1
    fi

    # 建立排名對照表（排名從 1 開始，第 1 名 = 最高值）
    # 標準化排名為 0~1 之間（第 1 名 = 1.0，最後一名 = 接近 0）

    # 複雜度排名
    awk -v total="$total_files" '{rank=NR; score=(total - rank + 1) / total; print $2, score}' "$complexity_file" > "${output}.complexity_rank"

    # hotspot 排名
    awk -v total="$total_files" '{rank=NR; score=(total - rank + 1) / total; print $2, score}' "$hotspot_file" > "${output}.hotspot_rank"

    # 耦合度排名
    awk -v total="$total_files" '{rank=NR; score=(total - rank + 1) / total; print $2, score}' "$coupling_file" > "${output}.coupling_rank"

    # 合併三個維度的排名分數
    # 使用 awk 讀取所有排名，計算加權分數
    awk '
    BEGIN { FS=" " }
    FILENAME ~ /complexity_rank$/ { complexity[$1] = $2; next }
    FILENAME ~ /hotspot_rank$/ { hotspot[$1] = $2; next }
    FILENAME ~ /coupling_rank$/ { coupling[$1] = $2; next }
    END {
        for (file in complexity) {
            e = (file in complexity) ? complexity[file] : 0
            h = (file in hotspot) ? hotspot[file] : 0
            c = (file in coupling) ? coupling[file] : 0
            score = e * 0.4 + h * 0.4 + c * 0.2
            printf "%.4f %s\n", score, file
        }
    }' "${output}.complexity_rank" "${output}.hotspot_rank" "${output}.coupling_rank" \
        | sort -rn > "$output"

    # 清理暫存
    rm -f "${output}.complexity_rank" "${output}.hotspot_rank" "${output}.coupling_rank"
}

# -- 格式化輸出 --
format_output() {
    local scores_file="$1"
    local complexity_file="$2"
    local hotspot_file="$3"
    local coupling_file="$4"
    local total_files="$5"
    local show_n="$6"

    echo ""
    echo "推薦審計目標（共 ${total_files} 個檔案中選出 ${show_n} 個）："
    echo ""

    local rank=0
    while IFS=' ' read -r score file; do
        rank=$((rank + 1))
        if [ "$rank" -gt "$show_n" ]; then
            break
        fi

        # 查詢該檔案的各項原始數值
        local complexity_val
        complexity_val=$(awk -v f="$file" '$2 == f {print $1; exit}' "$complexity_file")
        local hotspot_val
        hotspot_val=$(awk -v f="$file" '$2 == f {print $1; exit}' "$hotspot_file")
        local coupling_val
        coupling_val=$(awk -v f="$file" '$2 == f {print $1; exit}' "$coupling_file")

        # 複雜度等級（基於行數）
        local complexity_level
        if [ "${complexity_val:-0}" -gt 300 ]; then
            complexity_level="高"
        elif [ "${complexity_val:-0}" -gt 100 ]; then
            complexity_level="中"
        else
            complexity_level="低"
        fi

        # 顯示相對路徑
        local display_path
        display_path="${file#$TARGET_DIR/}"

        printf "%2d. %s  (score: %s)\n" "$rank" "$display_path" "$score"
        printf "    複雜度(行數): %s (%s) | git 變動: %s 次 | 被引用: %s 處\n" \
            "$complexity_level" "${complexity_val:-0}" "${hotspot_val:-0}" "${coupling_val:-0}"
    done < "$scores_file"

    echo ""
}

# -- 主程式 --
main() {
    parse_args "$@"

    TMPDIR_WORK=$(mktemp -d)

    local file_list="${TMPDIR_WORK}/files.txt"
    local complexity_result="${TMPDIR_WORK}/complexity.txt"
    local hotspot_result="${TMPDIR_WORK}/hotspot.txt"
    local coupling_result="${TMPDIR_WORK}/coupling.txt"
    local scores_result="${TMPDIR_WORK}/scores.txt"

    echo "=== SourceAtlas 審計目標推薦 ==="
    echo "掃描目錄: ${TARGET_DIR}"
    if [ -n "$LANGUAGE" ]; then
        echo "指定語言: ${LANGUAGE}"
    fi
    echo ""

    # 收集檔案
    echo "-- 收集原始碼檔案..."
    collect_files "$file_list"

    local total_files
    total_files=$(wc -l < "$file_list" | tr -d ' ')

    if [ "$total_files" -eq 0 ]; then
        echo "錯誤：在指定目錄中沒有找到任何原始碼檔案" >&2
        exit 1
    fi

    echo "   找到 ${total_files} 個檔案"

    # 調整 TOP_N 不超過檔案總數
    local show_n=$TOP_N
    if [ "$show_n" -gt "$total_files" ]; then
        show_n=$total_files
    fi

    # 階段 1：檔案複雜度分析（以行數近似）
    echo "-- 分析檔案複雜度（行數近似）..."
    analyze_complexity "$file_list" "$complexity_result"

    # 階段 2：hotspot 分析
    echo "-- 分析 git 變動頻率（hotspot）..."
    analyze_hotspot "$file_list" "$hotspot_result"

    # 階段 3：耦合度分析
    echo "-- 分析耦合度（被引用次數）..."
    analyze_coupling "$file_list" "$coupling_result"

    # 綜合排序
    echo "-- 計算綜合分數..."
    compute_scores "$complexity_result" "$hotspot_result" "$coupling_result" "$scores_result"

    # 輸出結果
    format_output "$scores_result" "$complexity_result" "$hotspot_result" "$coupling_result" "$total_files" "$show_n"

    echo "=== 分析完成 ==="
    echo "評分公式: score = complexity_rank * 0.4 + hotspot_rank * 0.4 + coupling_rank * 0.2"
    echo "（複雜度以行數近似，非資訊理論熵值）"
}

main "$@"
