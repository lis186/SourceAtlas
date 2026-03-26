#!/bin/bash
# detect-language.sh -- 語言偵測橋接腳本
#
# 整合 detect-project.sh 的專案偵測結果，自動映射到合約審計語言插件。
# 輸出為 key=value 格式，供 run-baseline.sh 等管線腳本消費。
#
# 用法：
#   bash detect-language.sh [專案路徑]
#   bash detect-language.sh --file <檔案路徑>
#
# 輸出（stdout）：
#   LANGUAGE=swift
#   PLUGIN=languages/swift.md
#
# 結束碼：
#   0 - 成功偵測並找到對應插件
#   1 - 偵測成功但無對應插件（WARN 輸出至 stderr）
#   2 - 參數錯誤
#
# 範例：
#   # 偵測整個專案
#   eval "$(bash detect-language.sh /path/to/project)"
#   echo "$LANGUAGE"  # => swift
#
#   # 根據單一檔案副檔名推斷
#   eval "$(bash detect-language.sh --file src/Foo.swift)"
#   echo "$PLUGIN"    # => languages/swift.md
#
#   # 混合語言專案中，以目標檔案為準
#   eval "$(bash detect-language.sh --file Classes/Bar.m)"
#   echo "$LANGUAGE"  # => objc

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT_PROJECT="$(cd "$SCRIPT_DIR/../../.." && pwd)/scripts/atlas/detect-project.sh"
LANGUAGES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/prompts/languages"

# ==============================================================================
# 輔助函式
# ==============================================================================

usage() {
  cat <<'USAGE'
用法：
  detect-language.sh [選項] [專案路徑]

選項：
  --file <path>   根據單一檔案的副檔名直接推斷語言（跳過專案偵測）
  --help, -h      顯示此說明

輸出（stdout，供 eval 消費）：
  LANGUAGE=<語言標識>
  PLUGIN=languages/<語言>.md

結束碼：
  0  成功偵測並找到對應插件
  1  偵測成功但無對應插件（需手動指定）
  2  參數錯誤

範例：
  # 偵測專案語言
  eval "$(bash detect-language.sh /path/to/project)"

  # 根據檔案副檔名推斷
  eval "$(bash detect-language.sh --file src/AppDelegate.m)"

  # 搭配 run-baseline.sh 使用
  eval "$(bash detect-language.sh --file "$TARGET_FILE")"
  bash run-baseline.sh --language "$LANGUAGE" "$TARGET_FILE"
USAGE
  exit 0
}

# 記錄訊息到 stderr（不干擾管線輸出）
log() {
  echo "$@" >&2
}

# 根據副檔名映射語言標識
# 傳回空字串表示無法辨識
ext_to_language() {
  local ext="$1"
  case "$ext" in
    m|h)       echo "objc" ;;
    swift)     echo "swift" ;;
    ts|tsx)    echo "typescript" ;;
    js|jsx|mjs|cjs) echo "javascript" ;;
    go)        echo "go" ;;
    kt|kts)    echo "kotlin" ;;
    py)        echo "python" ;;
    rs)        echo "rust" ;;
    java)      echo "java" ;;
    *)         echo "" ;;
  esac
}

# 根據 detect-project.sh 的 PROJECT_TYPE 映射語言標識
project_type_to_language() {
  local ptype="$1"
  case "$ptype" in
    ios)
      # iOS 專案可能混合 ObjC 與 Swift，需要進一步判斷
      echo "ios-mixed"
      ;;
    swift)
      echo "swift"
      ;;
    nodejs)
      echo "nodejs-mixed"
      ;;
    go)
      echo "go"
      ;;
    kotlin|android)
      echo "kotlin"
      ;;
    python)
      echo "python"
      ;;
    rust)
      echo "rust"
      ;;
    java)
      echo "java"
      ;;
    *)
      echo ""
      ;;
  esac
}

# 檢查語言插件是否存在，輸出結果
emit_result() {
  local lang="$1"
  local plugin_file="${lang}.md"
  local plugin_path="${LANGUAGES_DIR}/${plugin_file}"

  if [ -f "$plugin_path" ]; then
    echo "LANGUAGE=${lang}"
    echo "PLUGIN=languages/${plugin_file}"
    return 0
  else
    echo "LANGUAGE=${lang}"
    echo "PLUGIN="
    log "WARN: 語言 '${lang}' 無對應插件檔案 (languages/${plugin_file})"
    log "WARN: 可用插件："
    for f in "$LANGUAGES_DIR"/*.md; do
      [ -f "$f" ] && log "  - $(basename "$f" .md)"
    done
    log "WARN: 請使用 --language 手動指定語言"
    return 1
  fi
}

# ==============================================================================
# 參數解析
# ==============================================================================

FILE_MODE=""
PROJECT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      ;;
    --file)
      if [ -z "${2:-}" ]; then
        log "ERROR: --file 需要指定檔案路徑"
        exit 2
      fi
      FILE_MODE="$2"
      shift 2
      ;;
    -*)
      log "ERROR: 未知選項 $1"
      log "執行 $0 --help 查看用法"
      exit 2
      ;;
    *)
      PROJECT_PATH="$1"
      shift
      ;;
  esac
done

# ==============================================================================
# 模式一：根據單一檔案副檔名推斷
# ==============================================================================

if [ -n "$FILE_MODE" ]; then
  EXT="${FILE_MODE##*.}"
  LANG=$(ext_to_language "$EXT")

  if [ -z "$LANG" ]; then
    log "WARN: 無法從副檔名 '.${EXT}' 推斷語言"
    log "WARN: 支援的副檔名：.m .h (objc), .swift (swift), .ts .tsx (typescript), .js .jsx .mjs .cjs (javascript), .go (go), .kt .kts (kotlin), .py (python), .rs (rust), .java (java)"
    log "WARN: 請使用 --language 手動指定語言"
    echo "LANGUAGE="
    echo "PLUGIN="
    exit 1
  fi

  emit_result "$LANG"
  exit $?
fi

# ==============================================================================
# 模式二：呼叫 detect-project.sh 偵測專案語言
# ==============================================================================

PROJECT_PATH="${PROJECT_PATH:-.}"

if [ ! -d "$PROJECT_PATH" ]; then
  log "ERROR: 專案路徑不存在：$PROJECT_PATH"
  exit 2
fi

if [ ! -f "$DETECT_PROJECT" ]; then
  log "ERROR: detect-project.sh 不存在：$DETECT_PROJECT"
  log "  請確認 scripts/atlas/detect-project.sh 存在"
  exit 2
fi

# 執行 detect-project.sh，擷取輸出（stderr 靜音）
DETECT_OUTPUT=$(bash "$DETECT_PROJECT" "$PROJECT_PATH" 2>/dev/null)

# 從輸出中解析 PROJECT_TYPE
# detect-project.sh 的輸出格式範例：
#   "   ✓ iOS/Swift (Xcode project found)"  => PROJECT_TYPE 設為 ios
#   "   ✓ Node.js/TypeScript (package.json found)" => PROJECT_TYPE 設為 nodejs
# 我們透過特徵字串來辨識
if echo "$DETECT_OUTPUT" | grep -q "iOS/Swift\|Swift Package\|Swift/Tuist"; then
  # iOS 或 Swift 專案
  # 進一步判斷：檢查 ObjC 和 Swift 檔案比例
  SWIFT_COUNT=$(find "$PROJECT_PATH" -type f -name "*.swift" \
    ! -path "*/Pods/*" ! -path "*/.build/*" ! -path "*/.git/*" ! -path "*/DerivedData/*" \
    2>/dev/null | wc -l | tr -d ' ')
  OBJC_COUNT=$(find "$PROJECT_PATH" -type f \( -name "*.m" -o -name "*.h" \) \
    ! -path "*/Pods/*" ! -path "*/.git/*" ! -path "*/DerivedData/*" \
    2>/dev/null | wc -l | tr -d ' ')

  if [ "$OBJC_COUNT" -gt 0 ] && [ "$SWIFT_COUNT" -gt 0 ]; then
    # 混合語言專案：預設選擇檔案數較多的語言
    log "INFO: 偵測到混合語言專案 (Swift: ${SWIFT_COUNT}, ObjC: ${OBJC_COUNT})"
    log "INFO: 若需針對特定檔案審計，請使用 --file <path> 依副檔名決定"
    if [ "$SWIFT_COUNT" -ge "$OBJC_COUNT" ]; then
      emit_result "swift"
    else
      emit_result "objc"
    fi
  elif [ "$SWIFT_COUNT" -gt 0 ]; then
    emit_result "swift"
  elif [ "$OBJC_COUNT" -gt 0 ]; then
    emit_result "objc"
  else
    # 偵測為 iOS 但找不到原始碼檔案（不太可能但防禦性處理）
    emit_result "swift"
  fi

elif echo "$DETECT_OUTPUT" | grep -q "Node.js/TypeScript\|Node.js"; then
  # Node.js 專案：檢查是否有 TypeScript 檔案來區分 TS / JS
  TS_COUNT=$(find "$PROJECT_PATH" -type f \( -name "*.ts" -o -name "*.tsx" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" ! -path "*/build/*" \
    2>/dev/null | wc -l | tr -d ' ')
  JS_COUNT=$(find "$PROJECT_PATH" -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.mjs" -o -name "*.cjs" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" ! -path "*/build/*" \
    2>/dev/null | wc -l | tr -d ' ')

  if [ "$TS_COUNT" -gt 0 ]; then
    # 有 TS 檔案則判定為 typescript（TS 專案通常也包含 JS 檔案）
    log "INFO: Node.js 專案偵測到 TypeScript (TS: ${TS_COUNT}, JS: ${JS_COUNT})"
    emit_result "typescript"
  elif [ "$JS_COUNT" -gt 0 ]; then
    log "INFO: Node.js 專案偵測到純 JavaScript (JS: ${JS_COUNT})"
    emit_result "javascript"
  else
    # 有 package.json 但找不到原始碼，預設 typescript
    emit_result "typescript"
  fi

else
  # 嘗試從輸出中提取專案類型名稱
  DETECTED_TYPE=$(echo "$DETECT_OUTPUT" | grep -oE '(Ruby/Rails|Go |Rust |Python |Android/Kotlin|PHP )' | head -1 | tr -d ' ' | tr '/' '-' | tr '[:upper:]' '[:lower:]')

  if [ -n "$DETECTED_TYPE" ]; then
    log "WARN: 偵測到專案類型 '${DETECTED_TYPE}'，但目前無對應語言插件"
    log "WARN: 可用插件："
    for f in "$LANGUAGES_DIR"/*.md; do
      [ -f "$f" ] && log "  - $(basename "$f" .md)"
    done
    log "WARN: 請使用 --language 手動指定語言"
    echo "LANGUAGE=${DETECTED_TYPE}"
    echo "PLUGIN="
    exit 1
  else
    log "WARN: 無法辨識專案類型"
    log "WARN: detect-project.sh 輸出摘要："
    echo "$DETECT_OUTPUT" | grep -E "^   " | head -5 | while read -r line; do
      log "  $line"
    done
    log "WARN: 請使用 --language 手動指定語言"
    echo "LANGUAGE="
    echo "PLUGIN="
    exit 1
  fi
fi
