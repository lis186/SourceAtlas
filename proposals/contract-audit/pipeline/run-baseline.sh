#!/bin/bash
# run-baseline.sh -- Phase A 合約審計管線orchestrator
#
# 支援三種模式：
#   1. 配置檔驅動：自動讀取 audit.config.yml
#   2. CLI 參數驅動：向後相容，無配置檔時用 CLI 參數
#   3. Agent 模式（--agent）：不呼叫 LLM CLI，改為輸出 prompt 檔案供
#      Claude Code skill/subagent 協調。適用於在 Claude Code session 內執行。
#
# CLI 參數優先於配置檔（可覆蓋任何設定）。
#
# 用法：
#   bash run-baseline.sh                              # 讀取 audit.config.yml
#   bash run-baseline.sh --config path/to/config.yml  # 指定配置檔
#   bash run-baseline.sh file1.m file2.h              # 純 CLI 模式（向後相容）
#   bash run-baseline.sh --module Foo --language swift file.swift
#   bash run-baseline.sh --agent                      # Agent 模式（不呼叫 LLM CLI）
#
# 管線步驟：
#   Step 0:   邊界發現（rg 靜態掃描）
#   Step 0.5: Feathers 規則掃描（可選，--skip-feathers 跳過）
#   Step 0.7: 確定性合約預掃描（grep patterns/ 錨定模式）
#   Step 0.8: Feature Sketch（方法-屬性矩陣，純 grep）
#   Step 0.9: Caller Interface Extraction（補充檔案壓縮，純 grep）
#   Step 1:   Gemini 盲掃
#   Step 1.5: 依賴圖譜分析（Seam + Pinch Point）
#   Step 2:   Claude 結構化審計
#   Step 3:   Codex 對抗性評論
#   Step 4:   Claude 合併 + Pinch Point 標記
#
# 外部依賴（CLI 模式）：
#   gemini  -- Google Gemini CLI（Step 1 盲掃）
#   claude  -- Anthropic Claude Code CLI（Step 1.5, 2, 4）
#   codex   -- OpenAI Codex CLI，使用 codex exec（Step 3 對抗性評論）
#   rg      -- ripgrep，用於靜態文字搜尋（Step 0, 0.5）
#   YAML 解析使用內建 awk/grep/sed，不需要 yq
#
# Agent 模式外部依賴：
#   rg      -- ripgrep（Step 0, 0.5 仍由腳本執行）
#   其餘步驟由呼叫者（Claude Code skill）協調 LLM 呼叫

set -euo pipefail

# ==============================================================================
# 常數與預設值
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUDIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROMPTS="$AUDIT_DIR/prompts"
OUTPUT="$AUDIT_DIR/output"
PHASE_B="$AUDIT_DIR/phase-b"

# 預設值（可被 config 或 CLI 覆蓋）
CONFIG_FILE=""
MODULE_NAME=""
LANGUAGE=""
TARGET_FILES=""
REFACTORING_INTENT=""
OBSERVER_PATTERNS=""
SYNC_PATTERNS=""
FILE_TYPES=""
MAX_BOUNDARY_FILES=5
VERIFY_PRIMARY="grep"
VERIFY_SECONDARY="none"
IMPORT_PATTERNS=""
SEAM_DETECTION="true"
PINCH_POINT_THRESHOLD=3
SKIP_FEATHERS="false"
AGENT_MODE="false"
FRAMEWORKS=""
NO_AUTO_DETECT="false"

# ==============================================================================
# 輔助函式
# ==============================================================================

usage() {
  cat <<'USAGE'
用法：
  run-baseline.sh [選項] [target-files...]

選項：
  --config FILE       指定配置檔路徑（預設：audit.config.yml）
  --module NAME       模組名稱（覆蓋配置檔）
  --language LANG     語言標識：objc|swift|typescript|go|kotlin|python|rust|java
  --target FILE       目標檔案（可多次指定，覆蓋配置檔）
  --intent TEXT       重構意圖描述
  --observer-pat PAT  觀察者模式 regex
  --sync-pat PAT      同步原語 regex
  --file-types TYPES  搜尋檔案類型（逗號分隔，如 objc,swift）
  --verify-primary V  主要驗證：grep|ast-grep（預設 grep）
  --verify-secondary V 次要驗證：ast-grep|clang-ast-dump|none
  --no-seam           停用 Seam 識別
  --skip-feathers     跳過 Step 0.5 Feathers 規則掃描
  --pinch-threshold N Pinch Point 閾值（預設 3）
  --frameworks LIST   框架列表（逗號分隔，如 react,rxjs），覆蓋配置檔與自動偵測
  --no-auto-detect    停用框架自動偵測
  --agent             Agent 模式：不呼叫 LLM CLI，輸出 prompt 檔案供外部協調
  --help              顯示此說明

配置檔模式：
  若目前目錄存在 audit.config.yml，自動讀取。
  CLI 參數優先於配置檔設定。

向後相容模式：
  run-baseline.sh file1.m file2.h
  不需配置檔，直接指定目標檔案（行為與舊版一致）。

範例：
  # 使用配置檔
  cp audit.config.example-objc.yml audit.config.yml
  bash run-baseline.sh

  # 純 CLI 模式
  bash run-baseline.sh --module NYHTTPSClient --language objc \
    NYCore/Classes/NYHTTPSClient.m NYCore/Classes/NYHTTPSClient.h

  # 混合模式（CLI 覆蓋配置檔中的 module）
  bash run-baseline.sh --module OverrideName
USAGE
  exit 0
}

# 記錄訊息到 stderr（不干擾管線輸出）
log() {
  echo "$@" >&2
}

# 從 YAML 讀取單值欄位（簡易解析，不依賴外部工具）
yaml_value() {
  local file="$1" key="$2"
  grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | sed 's/^["'"'"']\(.*\)["'"'"']$/\1/' || true
}

# 從 YAML 讀取巢狀欄位（如 boundary_discovery.observer_patterns）
yaml_nested() {
  local file="$1" parent="$2" key="$3"
  awk -v parent="$parent" -v key="$key" '
    $0 ~ "^"parent":" { in_parent=1; next }
    in_parent && /^[^ ]/ { in_parent=0 }
    in_parent && $0 ~ "^  "key":" {
      sub(/^  [^:]+:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
    }
  ' "$file" 2>/dev/null || true
}

# 從 YAML 讀取陣列欄位
yaml_array() {
  local file="$1" key="$2"
  awk -v key="$key" '
    $0 ~ "^"key":" { in_array=1; next }
    in_array && /^  - / { sub(/^  - /, ""); gsub(/^["'"'"']|["'"'"']$/, ""); print; next }
    in_array && /^[^ ]/ { exit }
  ' "$file" 2>/dev/null || true
}

# 從 YAML 讀取巢狀陣列欄位
yaml_nested_array() {
  local file="$1" parent="$2" key="$3"
  awk -v parent="$parent" -v key="$key" '
    $0 ~ "^"parent":" { in_parent=1; next }
    in_parent && /^[^ ]/ { in_parent=0 }
    in_parent && $0 ~ "^  "key":" { in_array=1; next }
    in_parent && in_array && /^    - / { sub(/^    - /, ""); gsub(/^["'"'"']|["'"'"']$/, ""); print; next }
    in_parent && in_array && /^  [^ ]/ { in_array=0 }
    in_parent && in_array && /^[^ ]/ { exit }
  ' "$file" 2>/dev/null || true
}

# ==============================================================================
# parse_verdict() -- 從 LLM 輸出中模糊匹配 CONFIRM / DISPUTE / ADD 判定詞
#
# 用法：
#   parse_verdict "CONFIRM" "$file"   → 輸出匹配行數
#   parse_verdict "DISPUTE" "$file"   → 從檔案中解析
#
# 支援：
#   - 大小寫不敏感（confirm, Confirm, CONFIRM）
#   - 常見變體（CONFIRMED → CONFIRM, DISPUTED → DISPUTE, ADDED → ADD）
#   - Markdown 格式（**CONFIRM**, ## CONFIRM, `CONFIRM`）
#   - 前後空白容忍
# ==============================================================================
parse_verdict() {
  local verdict="$1"
  local file="$2"

  # 建立含變體的正則：如 CONFIRM 也匹配 CONFIRMED
  local pattern
  case "$(echo "$verdict" | tr '[:lower:]' '[:upper:]')" in
    CONFIRM)  pattern='CONFIRM(ED)?' ;;
    DISPUTE)  pattern='DISPUTE(D)?' ;;
    ADD)      pattern='ADD(ED)?' ;;
    *)        pattern="$verdict" ;;
  esac

  # 允許前導空白、Markdown 格式（**、##、`、- ）
  # 完整正則：可選前綴 → 判定詞 → 空格或冒號後接內容
  local result
  result=$(grep -icE "^[[:space:]]*([\*#\`\-]*[[:space:]]*)*${pattern}[[:space:]*\`]*[[:space:]:]" "$file" 2>/dev/null || true)
  echo "${result:-0}"
}

# parse_confirm_ratio() -- 從 LLM 輸出中模糊解析 CONFIRM_RATIO 值
# 支援：CONFIRM_RATIO: 65%, confirm ratio: 65, **CONFIRM_RATIO**: 65%
parse_confirm_ratio() {
  local file="$1"
  grep -iE 'confirm.?ratio' "$file" 2>/dev/null \
    | grep -oE '[0-9]+' | tail -1 || true
}

# has_any_verdict() -- 檢查檔案中是否包含任何判定詞（CONFIRM/DISPUTE/ADD）
# 回傳 0（成功）表示有找到，回傳 1（失敗）表示完全沒有
has_any_verdict() {
  local file="$1"
  local total=0
  total=$(( $(parse_verdict "CONFIRM" "$file") + $(parse_verdict "DISPUTE" "$file") + $(parse_verdict "ADD" "$file") ))
  [ "$total" -gt 0 ]
}

# verdict_retry_hint -- 在 retry 時追加到 prompt 末尾的格式提示
VERDICT_RETRY_HINT="

---
重要格式提醒：請確保每個合約的評論以 CONFIRM、DISPUTE 或 ADD 開頭。
每行判定必須嚴格以大寫 CONFIRM、DISPUTE 或 ADD 作為行首關鍵字。
末尾 SUMMARY 區塊必須包含 CONFIRM_RATIO: [N]% 統計。"

# 在隔離環境中呼叫 claude CLI（防止 project context / session 記憶污染）
# 用法：claude_isolated "prompt text" > output_file
claude_isolated() {
  local tmpdir
  tmpdir=$(mktemp -d)
  pushd "$tmpdir" > /dev/null
  env -u CLAUDECODE claude \
    -p "$1" \
    --no-session-persistence \
    --permission-mode bypassPermissions \
    --output-format text
  local rc=$?
  popd > /dev/null
  rm -rf "$tmpdir"
  return $rc
}

# Preflight 環境檢查：確認所有必要工具與檔案就緒
preflight_check() {
  local missing_tools=()

  # rg 無論哪種模式都需要
  command -v rg >/dev/null 2>&1 || missing_tools+=("rg")

  # CLI 模式額外需要 gemini, claude, codex
  if [ "$AGENT_MODE" != "true" ]; then
    command -v gemini >/dev/null 2>&1 || missing_tools+=("gemini")
    command -v claude >/dev/null 2>&1 || missing_tools+=("claude")
    command -v codex  >/dev/null 2>&1 || missing_tools+=("codex")
  fi

  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo "" >&2
    echo "ERROR: 缺少必要工具: ${missing_tools[*]}" >&2
    echo "" >&2
    echo "安裝指引：" >&2
    for tool in "${missing_tools[@]}"; do
      case "$tool" in
        rg)     echo "  rg:      brew install ripgrep" >&2 ;;
        gemini) echo "  gemini:  npm install -g @google/gemini-cli         (需要 Google AI API key)" >&2 ;;
        claude) echo "  claude:  npm install -g @anthropic-ai/claude-code  (需要 Anthropic API key)" >&2 ;;
        codex)  echo "  codex:   npm i -g @openai/codex                    (需要 OPENAI_API_KEY)" >&2 ;;
      esac
    done
    if [ "$AGENT_MODE" != "true" ]; then
      echo "" >&2
      echo "或使用 --agent 模式（僅需 rg，不呼叫 LLM CLI）：" >&2
      echo "  bash run-baseline.sh --agent [其他參數]" >&2
    fi
    exit 1
  fi

  # 檢查 TARGET_FILES 中列出的檔案都存在
  local missing_files=()
  for f in $TARGET_FILES; do
    [ -f "$f" ] || missing_files+=("$f")
  done
  if [ ${#missing_files[@]} -gt 0 ]; then
    echo "ERROR: 以下目標檔案不存在：" >&2
    for f in "${missing_files[@]}"; do
      echo "  $f" >&2
    done
    exit 1
  fi

  # 檢查 LANGUAGE 已指定
  if [ -z "$LANGUAGE" ]; then
    echo "ERROR: 未指定語言。請透過 --language 或配置檔指定。" >&2
    exit 1
  fi

  # 檢查 patterns 檔存在
  local patterns_file="$AUDIT_DIR/patterns/${LANGUAGE}.patterns"
  if [ ! -f "$patterns_file" ]; then
    echo "ERROR: patterns 檔不存在：$patterns_file" >&2
    echo "  支援的語言：$(ls "$AUDIT_DIR/patterns/"*.patterns 2>/dev/null | xargs -I{} basename {} .patterns | tr '\n' ' ')" >&2
    exit 1
  fi
}

# ==============================================================================
# 參數解析
# ==============================================================================

CLI_TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      ;;
    --config)
      CONFIG_FILE="$2"; shift 2
      ;;
    --module)
      MODULE_NAME="$2"; shift 2
      ;;
    --language)
      LANGUAGE="$2"; shift 2
      ;;
    --target)
      CLI_TARGETS+=("$2"); shift 2
      ;;
    --intent)
      REFACTORING_INTENT="$2"; shift 2
      ;;
    --observer-pat)
      OBSERVER_PATTERNS="$2"; shift 2
      ;;
    --sync-pat)
      SYNC_PATTERNS="$2"; shift 2
      ;;
    --file-types)
      FILE_TYPES="$2"; shift 2
      ;;
    --verify-primary)
      VERIFY_PRIMARY="$2"; shift 2
      ;;
    --verify-secondary)
      VERIFY_SECONDARY="$2"; shift 2
      ;;
    --no-seam)
      SEAM_DETECTION="false"; shift
      ;;
    --skip-feathers)
      SKIP_FEATHERS="true"; shift
      ;;
    --frameworks)
      FRAMEWORKS="$2"; shift 2
      ;;
    --no-auto-detect)
      NO_AUTO_DETECT="true"; shift
      ;;
    --agent)
      AGENT_MODE="true"; shift
      ;;
    --pinch-threshold)
      PINCH_POINT_THRESHOLD="$2"; shift 2
      ;;
    -*)
      log "ERROR: 未知選項 $1"
      log "執行 $0 --help 查看用法"
      exit 1
      ;;
    *)
      CLI_TARGETS+=("$1"); shift
      ;;
  esac
done

# ==============================================================================
# 讀取配置檔
# ==============================================================================

# 自動偵測配置檔
if [ -z "$CONFIG_FILE" ] && [ -f "audit.config.yml" ]; then
  CONFIG_FILE="audit.config.yml"
  log "偵測到 audit.config.yml，自動載入配置"
fi

if [ -n "$CONFIG_FILE" ]; then
  if [ ! -f "$CONFIG_FILE" ]; then
    log "ERROR: 配置檔不存在：$CONFIG_FILE"
    exit 1
  fi

  log "讀取配置檔：$CONFIG_FILE"

  # 讀取基本欄位（CLI 未指定時才使用配置檔值）
  [ -z "$MODULE_NAME" ] && MODULE_NAME=$(yaml_value "$CONFIG_FILE" "module")
  [ -z "$LANGUAGE" ] && LANGUAGE=$(yaml_value "$CONFIG_FILE" "language")
  [ -z "$REFACTORING_INTENT" ] && REFACTORING_INTENT=$(yaml_value "$CONFIG_FILE" "refactoring_intent")

  # 讀取目標檔案（CLI 未指定時）
  if [ ${#CLI_TARGETS[@]} -eq 0 ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && CLI_TARGETS+=("$line")
    done < <(yaml_array "$CONFIG_FILE" "target_files")
  fi

  # 讀取邊界發現設定
  [ -z "$OBSERVER_PATTERNS" ] && OBSERVER_PATTERNS=$(yaml_nested "$CONFIG_FILE" "boundary_discovery" "observer_patterns")
  [ -z "$SYNC_PATTERNS" ] && SYNC_PATTERNS=$(yaml_nested "$CONFIG_FILE" "boundary_discovery" "sync_patterns")

  if [ -z "$FILE_TYPES" ]; then
    _ft=$(yaml_nested_array "$CONFIG_FILE" "boundary_discovery" "file_types" | tr '\n' ',' | sed 's/,$//')
    [ -n "$_ft" ] && FILE_TYPES="$_ft"
  fi

  _max=$(yaml_nested "$CONFIG_FILE" "boundary_discovery" "max_files")
  [ -n "$_max" ] && MAX_BOUNDARY_FILES="$_max"

  # 讀取驗證策略
  _vp=$(yaml_nested "$CONFIG_FILE" "verification" "primary")
  [ -n "$_vp" ] && [ "$VERIFY_PRIMARY" = "grep" ] && VERIFY_PRIMARY="$_vp"

  _vs=$(yaml_nested "$CONFIG_FILE" "verification" "secondary")
  [ -n "$_vs" ] && [ "$VERIFY_SECONDARY" = "none" ] && VERIFY_SECONDARY="$_vs"

  # 讀取框架設定（CLI 未指定時）
  if [ -z "$FRAMEWORKS" ]; then
    _fw=$(yaml_array "$CONFIG_FILE" "frameworks" | tr '\n' ',' | sed 's/,$//')
    [ -n "$_fw" ] && FRAMEWORKS="$_fw"
  fi

  # 讀取依賴分析設定
  [ -z "$IMPORT_PATTERNS" ] && IMPORT_PATTERNS=$(yaml_nested "$CONFIG_FILE" "dependency_analysis" "import_patterns")

  _sd=$(yaml_nested "$CONFIG_FILE" "dependency_analysis" "seam_detection")
  [ -n "$_sd" ] && SEAM_DETECTION="$_sd"

  _ppt=$(yaml_nested "$CONFIG_FILE" "dependency_analysis" "pinch_point_threshold")
  [ -n "$_ppt" ] && PINCH_POINT_THRESHOLD="$_ppt"
fi

# ==============================================================================
# 參數驗證
# ==============================================================================

TARGET_FILES="${CLI_TARGETS[*]:-}"

if [ -z "$TARGET_FILES" ]; then
  log "ERROR: 未指定目標檔案。"
  log "  使用配置檔：建立 audit.config.yml（參考 audit.config.example-*.yml）"
  log "  使用 CLI：$0 <file1> [file2 ...]"
  exit 1
fi

# 從第一個目標檔案推斷模組名（如未指定）
if [ -z "$MODULE_NAME" ]; then
  FIRST_TARGET="${CLI_TARGETS[0]}"
  MODULE_NAME=$(basename "${FIRST_TARGET%.*}")
  log "自動推斷模組名：$MODULE_NAME"
fi

# 語言未指定時，嘗試從副檔名推斷
if [ -z "$LANGUAGE" ]; then
  FIRST_TARGET="${CLI_TARGETS[0]}"
  EXT="${FIRST_TARGET##*.}"
  case "$EXT" in
    m|h)       LANGUAGE="objc" ;;
    swift)     LANGUAGE="swift" ;;
    ts|tsx)    LANGUAGE="typescript" ;;
    js|jsx|mjs|cjs) LANGUAGE="javascript" ;;
    go)        LANGUAGE="go" ;;
    kt|kts)    LANGUAGE="kotlin" ;;
    py)        LANGUAGE="python" ;;
    rs)        LANGUAGE="rust" ;;
    java)      LANGUAGE="java" ;;
    *)
      log "WARN: 無法從副檔名 .$EXT 推斷語言，使用預設驗證策略"
      ;;
  esac
  [ -n "$LANGUAGE" ] && log "自動推斷語言：$LANGUAGE"
fi

# 驗證語言插件存在
if [ -n "$LANGUAGE" ] && [ ! -f "$PROMPTS/languages/${LANGUAGE}.md" ]; then
  log "WARN: 語言插件 prompts/languages/${LANGUAGE}.md 不存在"
  log "  將僅使用通用骨架 skeleton.md"
fi

# Preflight 檢查（配置解析完成後、Step 0 之前）
preflight_check

# ==============================================================================
# 初始化執行環境
# ==============================================================================

RUN_ID=$(TZ=Asia/Taipei date +%Y%m%d-%H%M%S)
RUN_DIR="$OUTPUT/runs/$RUN_ID"
PROJECT_ROOT="$(pwd)"

mkdir -p "$RUN_DIR/claude-artifacts"

# -- 計時基礎設施（相容 bash 3.x / macOS 預設 shell）--
PIPELINE_START=$(date +%s)
T_STEP0=0; T_STEP05=0; T_STEP07=0; T_STEP08=0; T_STEP09=0; T_STEP1=0; T_STEP15=0; T_STEP2=0; T_STEP3=0; T_STEP4=0; T_STEP5=0
_STEP_START=0
step_start() { _STEP_START=$(date +%s); }
step_end() {
  local end=$(date +%s)
  local elapsed=$(( end - _STEP_START ))
  eval "T_${1}=$elapsed"
  echo "  ⏱ ${elapsed}s"
}

echo "=== Phase A 合約審計管線 ==="
echo "模組名稱: $MODULE_NAME"
echo "語言:     $LANGUAGE"
echo "Run ID:   $RUN_ID"
echo "Run Dir:  $RUN_DIR"
echo "目標檔案: $TARGET_FILES"
[ -n "$REFACTORING_INTENT" ] && echo "重構意圖: $REFACTORING_INTENT"
[ -n "$CONFIG_FILE" ] && echo "配置檔:   $CONFIG_FILE"
[ "$AGENT_MODE" = "true" ] && echo "模式:     Agent（不呼叫 LLM CLI，輸出 prompt 檔案）"
echo ""

# 將管線設定寫入執行記錄
cat > "$RUN_DIR/pipeline-config.log" <<EOF
module: $MODULE_NAME
language: $LANGUAGE
target_files: $TARGET_FILES
refactoring_intent: $REFACTORING_INTENT
verify_primary: $VERIFY_PRIMARY
verify_secondary: $VERIFY_SECONDARY
seam_detection: $SEAM_DETECTION
pinch_point_threshold: $PINCH_POINT_THRESHOLD
skip_feathers: $SKIP_FEATHERS
agent_mode: $AGENT_MODE
config_file: ${CONFIG_FILE:-none}
EOF

# ==============================================================================
# Step 0: 邊界發現
# ==============================================================================

echo "[Step 0] 邊界發現..."
step_start "step0"

TARGET_DIR="$(dirname "${CLI_TARGETS[0]}")"
EXTRA_FILES=""

# --- Layer 2: 語言預設邊界模式（config 未指定時自動套用）---
if [ -z "$OBSERVER_PATTERNS" ] && [ -n "$LANGUAGE" ]; then
  case "$LANGUAGE" in
    objc)
      OBSERVER_PATTERNS='postNotificationName|addObserver.*selector|NSNotificationCenter'
      SYNC_PATTERNS='dispatch_semaphore|dispatch_barrier|@synchronized'
      [ -z "$FILE_TYPES" ] && FILE_TYPES="objc,swift"
      ;;
    swift)
      OBSERVER_PATTERNS='NotificationCenter\.default\.post|\.sink\b|\.addObserver'
      SYNC_PATTERNS='DispatchSemaphore|DispatchQueue\.main\.sync|actor\b'
      [ -z "$FILE_TYPES" ] && FILE_TYPES="swift"
      ;;
    typescript)
      OBSERVER_PATTERNS='\.emit\(|\.on\(|addEventListener|\.subscribe\('
      SYNC_PATTERNS='Promise\.all|new Worker|SharedArrayBuffer'
      [ -z "$FILE_TYPES" ] && FILE_TYPES="ts"
      ;;
    javascript)
      OBSERVER_PATTERNS='\.on\(|\.emit\(|addEventListener|\.subscribe\('
      SYNC_PATTERNS='Promise\.all|new Worker|SharedArrayBuffer'
      [ -z "$FILE_TYPES" ] && FILE_TYPES="js"
      ;;
  esac
  [ -n "$OBSERVER_PATTERNS" ] && log "  自動套用 $LANGUAGE 預設邊界模式"
fi

# 建立 rg --type 參數
RG_TYPE_ARGS=""
if [ -n "$FILE_TYPES" ]; then
  IFS=',' read -ra FT_ARRAY <<< "$FILE_TYPES"
  for ft in "${FT_ARRAY[@]}"; do
    RG_TYPE_ARGS="$RG_TYPE_ARGS --type $ft"
  done
fi

# --- Layer 1: 反向依賴搜尋（誰 import/reference 了目標模組？）---
# 按引用次數排序：引用越多 = 依賴越深 = 合約關係越緊密
REVERSE_FILES=""
BASENAME_TARGET=$(basename "${CLI_TARGETS[0]%.*}")
REVERSE_FILES_ALL=$(rg -c "$BASENAME_TARGET" $RG_TYPE_ARGS "$PROJECT_ROOT" 2>/dev/null \
  | grep -vE 'Tests?/|Spec\.|\.build/|Pods/' \
  | grep -v "$(basename "${CLI_TARGETS[0]}")" \
  || true)
if [ -n "$REVERSE_FILES_ALL" ]; then
  REVERSE_TOTAL=$(echo "$REVERSE_FILES_ALL" | wc -l | tr -d ' ')
  # 按引用次數降序，取 top MAX_BOUNDARY_FILES
  REVERSE_FILES=$(echo "$REVERSE_FILES_ALL" \
    | sort -t: -k2 -nr \
    | head -"$MAX_BOUNDARY_FILES" \
    | cut -d: -f1)
  REVERSE_KEPT=$(echo "$REVERSE_FILES" | wc -l | tr -d ' ')
  log "  Layer 1（反向依賴）: ${REVERSE_TOTAL} 個引用 ${BASENAME_TARGET} 的檔案，取 top ${REVERSE_KEPT}（按引用次數）"
fi

# --- Layer 2: 觀察者/同步模式搜尋（低精準度，限制 MAX_BOUNDARY_FILES）---
OBSERVER_FILES=""
if [ -n "$OBSERVER_PATTERNS" ]; then
  OBSERVER_FILES=$(rg "$OBSERVER_PATTERNS" \
    $RG_TYPE_ARGS -l "$TARGET_DIR" 2>/dev/null \
    | grep -vE 'Tests?/|Spec\.' \
    | grep -v "$(basename "${CLI_TARGETS[0]}")" \
    || true)
fi

SEMAPHORE_FILES=""
if [ -n "$SYNC_PATTERNS" ]; then
  SEMAPHORE_FILES=$(rg "$SYNC_PATTERNS" \
    $RG_TYPE_ARGS -l "$TARGET_DIR" 2>/dev/null \
    | grep -v "$(basename "${CLI_TARGETS[0]}")" \
    || true)
fi

# Layer 2 去重（排除已在 Layer 1 中的檔案），限制數量
PATTERN_FILES=""
PATTERN_CANDIDATES=$(echo "$OBSERVER_FILES $SEMAPHORE_FILES" \
  | tr ' ' '\n' | sort -u | grep '[^[:space:]]' || true)
if [ -n "$PATTERN_CANDIDATES" ]; then
  if [ -n "$REVERSE_FILES" ]; then
    # 排除已在 Layer 1 中的檔案
    PATTERN_FILES=$(echo "$PATTERN_CANDIDATES" \
      | while read -r pf; do echo "$REVERSE_FILES" | grep -qF "$pf" || echo "$pf"; done \
      | head -"$MAX_BOUNDARY_FILES" || true)
  else
    PATTERN_FILES=$(echo "$PATTERN_CANDIDATES" | head -"$MAX_BOUNDARY_FILES")
  fi
fi

# --- Layer 3: Layer 1（top N by ref count）+ Layer 2（限制後）合併 ---
EXTRA_FILES=$(echo "$REVERSE_FILES"$'\n'"$PATTERN_FILES" \
  | sort -u | grep '[^[:space:]]' || true)
EXTRA_FILES=$(echo "$EXTRA_FILES" | tr '\n' ' ')
EXTRA_COUNT=$(echo "$EXTRA_FILES" | tr ' ' '\n' | grep -c '[^[:space:]]' || true)
EXTRA_COUNT=${EXTRA_COUNT:-0}
echo "  發現 $EXTRA_COUNT 個相關檔案"
echo "$EXTRA_FILES" | tr ' ' '\n' | grep '[^[:space:]]' | sed 's/^/    /' || true

# 合併目標檔案（去重）
ALL_TARGET_FILES="$TARGET_FILES"
for f in $EXTRA_FILES; do
  [[ -f "$f" ]] && ALL_TARGET_FILES="$ALL_TARGET_FILES $f"
done
step_end "STEP0"

# ==============================================================================
# Step 0.5: Feathers 規則掃描（可選）
# ==============================================================================

FEATHERS_SCAN_FILE="$RUN_DIR/feathers-scan.txt"

if [ "$SKIP_FEATHERS" = "false" ]; then
  echo "[Step 0.5] Feathers 規則掃描..."
  step_start "step05"

  FEATHERS_RULES_DIR="$AUDIT_DIR/rules/feathers"
  FEATHERS_HIT_COUNT=0

  if [ -d "$FEATHERS_RULES_DIR" ]; then
    echo "# Feathers 規則掃描結果" > "$FEATHERS_SCAN_FILE"
    echo "# 掃描時間: $(TZ=Asia/Taipei date)" >> "$FEATHERS_SCAN_FILE"
    echo "" >> "$FEATHERS_SCAN_FILE"

    # 遍歷每個規則目錄，只輸出命中結果
    for rule_dir in "$FEATHERS_RULES_DIR"/*/; do
      rule_name=$(basename "$rule_dir")
      RULE_HITS=""

      if [ -x "$rule_dir/scan.sh" ]; then
        echo "  執行規則: $rule_name"
        RULE_HITS=$(bash "$rule_dir/scan.sh" $TARGET_FILES 2>/dev/null || true)
      elif [ -f "$rule_dir/rule.yaml" ]; then
        # rule.yaml 是 ast-grep 規則，包含 $VAR 佔位符
        # 檢查是否有 grep-fallback 腳本可用
        FALLBACK_SCRIPT=""
        if [ -n "$LANGUAGE" ]; then
          # 嘗試語言特定 fallback（如 ../objc-fallback/xxx.sh）
          FALLBACK_SCRIPT=$(grep "fallback:" "$rule_dir/rule.yaml" 2>/dev/null \
            | sed "s/.*fallback:[[:space:]]*//" | sed 's/^["'"'"']\(.*\)["'"'"']$/\1/' || true)
          if [ -n "$FALLBACK_SCRIPT" ] && [ -f "$rule_dir/$FALLBACK_SCRIPT" ]; then
            echo "  規則（fallback）: $rule_name"
            RULE_HITS=$(bash "$rule_dir/$FALLBACK_SCRIPT" $TARGET_FILES 2>/dev/null || true)
          else
            echo "  規則（YAML/ast-grep）: $rule_name -- SKIP（需要 ast-grep，非 grep 可用）"
          fi
        else
          echo "  規則（YAML/ast-grep）: $rule_name -- SKIP（需要 ast-grep）"
        fi
      fi

      # 只在有命中時寫入輸出檔
      if [ -n "$(echo "$RULE_HITS" | tr -d '[:space:]')" ]; then
        echo "## $rule_name" >> "$FEATHERS_SCAN_FILE"
        echo "$RULE_HITS" >> "$FEATHERS_SCAN_FILE"
        echo "" >> "$FEATHERS_SCAN_FILE"
        FEATHERS_HIT_COUNT=$((FEATHERS_HIT_COUNT + 1))
        echo "    ✓ 命中"
      fi
    done

    FEATHERS_LINE_COUNT=$(wc -l < "$FEATHERS_SCAN_FILE")
    echo "  Feathers 規則掃描完成: $FEATHERS_HIT_COUNT 個規則命中"
    echo "  輸出: $FEATHERS_LINE_COUNT 行（僅命中結果）"
  else
    echo "  WARN: Feathers 規則目錄不存在: $FEATHERS_RULES_DIR"
    echo "# Feathers 規則目錄不存在" > "$FEATHERS_SCAN_FILE"
  fi
  step_end "STEP05"
else
  echo "[Step 0.5] SKIP: Feathers 規則掃描（--skip-feathers）"
  echo "# Feathers scan skipped" > "$FEATHERS_SCAN_FILE"
fi

# ==============================================================================
# Step 0.7: 確定性合約預掃描（錨定模式）
# ==============================================================================

ANCHOR_FILE="$RUN_DIR/anchor-contracts.md"
PATTERNS_DIR="$AUDIT_DIR/patterns"
PATTERN_FILE="$PATTERNS_DIR/${LANGUAGE}.patterns"

# -- 框架偵測（自動偵測目標檔案中使用的框架）--
# NOTE: 使用 read -ra 將空格分隔的檔案列表轉為陣列，避免含空白路徑時 word splitting 問題
detect_frameworks() {
  local detected=""
  local -a file_arr
  read -ra file_arr <<< "$ALL_TARGET_FILES"

  # React: import/require react
  if rg -q "import.*from ['\"]react['\"]|require\(['\"]react['\"]\)" "${file_arr[@]}" 2>/dev/null; then
    detected="${detected:+$detected,}react"
  fi

  # Angular: decorators
  if rg -q '@Component|@Injectable|@NgModule' "${file_arr[@]}" 2>/dev/null; then
    detected="${detected:+$detected,}angular"
  fi

  # RxJS: import rxjs
  if rg -q "import.*from ['\"]rxjs['\"]" "${file_arr[@]}" 2>/dev/null; then
    detected="${detected:+$detected,}rxjs"
  fi

  # Combine: import Combine
  if rg -q 'import Combine' "${file_arr[@]}" 2>/dev/null; then
    detected="${detected:+$detected,}combine"
  fi

  # SwiftUI: import SwiftUI
  if rg -q 'import SwiftUI' "${file_arr[@]}" 2>/dev/null; then
    detected="${detected:+$detected,}swiftui"
  fi

  # Express: require/import express
  if rg -q "require\(['\"]express['\"]\)|from ['\"]express['\"]" "${file_arr[@]}" 2>/dev/null; then
    detected="${detected:+$detected,}express"
  fi

  echo "$detected"
}

# -- 決定最終框架列表 --
RESOLVED_FRAMEWORKS="$FRAMEWORKS"
if [ -z "$RESOLVED_FRAMEWORKS" ] && [ "$NO_AUTO_DETECT" = "false" ] && [ -n "$LANGUAGE" ]; then
  RESOLVED_FRAMEWORKS=$(detect_frameworks)
  if [ -n "$RESOLVED_FRAMEWORKS" ]; then
    log "  自動偵測到框架：$RESOLVED_FRAMEWORKS"
  fi
fi

# -- 合併 patterns 檔：通用 + 框架特定 --
merge_pattern_files() {
  local merged="$RUN_DIR/merged.patterns"
  local loaded_sources=""

  # 1. 永遠載入通用 patterns
  if [ -f "$PATTERN_FILE" ]; then
    cat "$PATTERN_FILE" > "$merged"
    loaded_sources="$(basename "$PATTERN_FILE")"
  else
    > "$merged"
  fi

  # 2. 追加框架特定 patterns
  if [ -n "$RESOLVED_FRAMEWORKS" ]; then
    IFS=',' read -ra FW_LIST <<< "$RESOLVED_FRAMEWORKS"
    for fw in "${FW_LIST[@]}"; do
      fw=$(echo "$fw" | tr -d '[:space:]')
      local fw_file="$PATTERNS_DIR/${LANGUAGE}-${fw}.patterns"
      if [ -f "$fw_file" ]; then
        echo "" >> "$merged"
        echo "# --- framework: ${fw} ---" >> "$merged"
        cat "$fw_file" >> "$merged"
        loaded_sources="${loaded_sources} + $(basename "$fw_file")"
      else
        log "  WARN: 框架 patterns 檔不存在：$fw_file（跳過）"
      fi
    done
  fi

  # 回傳值：第一行是來源描述，第二行是合併檔路徑
  echo "$loaded_sources"
  echo "$merged"
}

if [ -n "$LANGUAGE" ] && [ -f "$PATTERN_FILE" ]; then
  echo "[Step 0.7] 確定性合約預掃描..."
  step_start "step07"

  # 合併 patterns 並取得來源資訊
  MERGE_OUTPUT=$(merge_pattern_files)
  MERGED_PATTERN_FILE=$(echo "$MERGE_OUTPUT" | tail -1)
  LOADED_SOURCES=$(echo "$MERGE_OUTPUT" | head -1)

  ANCHOR_COUNT=0

  {
    echo "## 確定性錨定合約（Step 0.7）"
    echo ""
    echo "以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約："
    echo ""
    if [ -n "$RESOLVED_FRAMEWORKS" ]; then
      echo "**載入的框架 patterns**：${RESOLVED_FRAMEWORKS}"
      echo ""
    fi
    echo "| # | 類別 | 模式 | 獨特位置 | 首次出現 |"
    echo "|---|------|------|---------|---------|"
  } > "$ANCHOR_FILE"

  while IFS=$'\t' read -r category name pattern description || [ -n "$category" ]; do
    # 跳過註解和空行
    [[ "$category" =~ ^# ]] && continue
    [[ -z "$category" ]] && continue

    # 對所有目標檔案 grep 此模式
    HITS=""
    HIT_COUNT=0
    FIRST_HIT=""

    ALL_MATCHES=""
    for tf in $ALL_TARGET_FILES; do
      if [ -f "$tf" ]; then
        MATCHES=$(grep -nE "$pattern" "$tf" 2>/dev/null || true)
        if [ -n "$MATCHES" ]; then
          COUNT=$(echo "$MATCHES" | wc -l | tr -d ' ')
          HIT_COUNT=$((HIT_COUNT + COUNT))
          # 收集所有命中行（帶檔名前綴）用於去重
          PREFIXED=$(echo "$MATCHES" | sed "s|^|$(basename "$tf"):|")
          ALL_MATCHES="${ALL_MATCHES}
${PREFIXED}"
          if [ -z "$FIRST_HIT" ]; then
            FIRST_LINE=$(echo "$MATCHES" | head -1 | cut -d: -f1)
            FIRST_HIT="$(basename "$tf"):${FIRST_LINE}"
          fi
        fi
      fi
    done

    if [ "$HIT_COUNT" -gt 0 ]; then
      ANCHOR_COUNT=$((ANCHOR_COUNT + 1))
      # 去重：按檔名+行號計算獨特位置數（降噪）
      UNIQUE_LOCS=$(echo "$ALL_MATCHES" | grep '[^[:space:]]' \
        | cut -d: -f1,2 | sort -u | wc -l | tr -d ' ')
      # 噪音閾值：超過 20 個獨特位置標記為 pervasive（風格約束，非具體錨點）
      NOISE_MARKER=""
      if [ "$UNIQUE_LOCS" -gt 20 ]; then
        NOISE_MARKER=" ⚠️ pervasive"
      fi
      echo "| $ANCHOR_COUNT | $category | $name | ${UNIQUE_LOCS}${NOISE_MARKER} | $FIRST_HIT |" >> "$ANCHOR_FILE"
    fi
  done < "$MERGED_PATTERN_FILE" || true

  echo "" >> "$ANCHOR_FILE"
  echo "共 $ANCHOR_COUNT 個錨點命中。" >> "$ANCHOR_FILE"

  echo "  載入 patterns：${LOADED_SOURCES}"
  echo "  錨點命中: ${ANCHOR_COUNT}"
  echo "  輸出: $ANCHOR_FILE"
  step_end "STEP07"
else
  echo "[Step 0.7] SKIP: 無對應的模式檔案（${LANGUAGE}.patterns）"
  echo "# Step 0.7 skipped -- no pattern file for language: $LANGUAGE" > "$ANCHOR_FILE"
fi

# ==============================================================================
# Step 0.8: Feature Sketch（方法-屬性矩陣）
# ==============================================================================

SKETCH_FILE="$RUN_DIR/feature-sketch.md"
echo "[Step 0.8] Feature Sketch..."
step_start "step08"

{
  echo "## Feature Sketch（Step 0.8）"
  echo ""
  echo "| # | 方法 | 行號 | 引用屬性 |"
  echo "|---|------|------|---------|"
} > "$SKETCH_FILE"

METHOD_COUNT=0
for tf in $TARGET_FILES; do
  [ -f "$tf" ] || continue
  case "$LANGUAGE" in
    objc)       METHOD_RE='^\s*[-+]\s*\(' ;;
    swift)      METHOD_RE='^\s*(func |init\(|deinit\b)' ;;
    typescript) METHOD_RE='^\s*(async\s+)?(public|private|protected)?\s*(static\s+)?\w+\s*\(' ;;
    *)          METHOD_RE='^\s*(func |def |fn |public |private )' ;;
  esac

  # 取得所有方法行號列表（避免 pipefail 問題）
  METHOD_LINES=$(grep -nE "$METHOD_RE" "$tf" 2>/dev/null || true)
  [ -z "$METHOD_LINES" ] && continue
  TOTAL_LINES=$(wc -l < "$tf" | tr -d ' ')

  echo "$METHOD_LINES" | (while IFS=: read -r lineno signature; do
    # 取方法體（到下一個方法或檔尾）
    NEXT_LINE=$(echo "$METHOD_LINES" \
      | awk -F: -v cur="$lineno" '$1 > cur { print $1; exit }')
    [ -z "$NEXT_LINE" ] && NEXT_LINE="$TOTAL_LINES"

    # 從方法體提取屬性引用（pipefail 安全：用 set +o pipefail 包裹）
    PROPS=""
    case "$LANGUAGE" in
      objc) PROPS=$(set +o pipefail; sed -n "${lineno},${NEXT_LINE}p" "$tf" \
              | grep -oE 'self\.\w+|_[a-z]\w+' | sort -u | tr '\n' ', ' | sed 's/,$//') ;;
      swift) PROPS=$(set +o pipefail; sed -n "${lineno},${NEXT_LINE}p" "$tf" \
              | grep -oE 'self\.\w+' | sort -u | tr '\n' ', ' | sed 's/,$//') ;;
      *) PROPS=$(set +o pipefail; sed -n "${lineno},${NEXT_LINE}p" "$tf" \
              | grep -oE 'this\.\w+|self\.\w+' | sort -u | tr '\n' ', ' | sed 's/,$//') ;;
    esac

    METHOD_COUNT=$((METHOD_COUNT + 1))
    # 截斷過長的簽名
    SHORT_SIG=$(echo "$signature" | sed 's/^[[:space:]]*//' | cut -c1-80)
    echo "| $METHOD_COUNT | \`$SHORT_SIG\` | $(basename "$tf"):$lineno | $PROPS |"
  done || true) >> "$SKETCH_FILE"
done

# 計算方法數（從產出檔案，因 while 子 shell 中的計數無法回傳）
METHOD_COUNT=$(grep -c "^|.*\`" "$SKETCH_FILE" 2>/dev/null || true)
METHOD_COUNT=${METHOD_COUNT:-0}
echo "" >> "$SKETCH_FILE"
echo "共 $METHOD_COUNT 個方法。" >> "$SKETCH_FILE"
echo "  方法數: $METHOD_COUNT"
step_end "STEP08"

# ==============================================================================
# Step 0.9: Caller Interface Extraction
# ==============================================================================

CALLER_FILE="$RUN_DIR/caller-interface.md"
echo "[Step 0.9] Caller Interface Extraction..."
step_start "step09"

if [ "$EXTRA_COUNT" -gt 0 ]; then
  {
    echo "## Caller Interface Extract（Step 0.9）"
    echo ""
    echo "外部模組引用 ${BASENAME_TARGET} 的片段（±5 行上下文）："
    echo ""
  } > "$CALLER_FILE"

  TOTAL_REFS=0
  for sf in $EXTRA_FILES; do
    [ -f "$sf" ] || continue
    REFS=$(rg -c "$BASENAME_TARGET" "$sf" 2>/dev/null || true)
    REFS=${REFS:-0}
    [ "$REFS" -eq 0 ] && continue
    TOTAL_REFS=$((TOTAL_REFS + REFS))
    echo "### $(basename "$sf") (${REFS} references)" >> "$CALLER_FILE"
    echo '```' >> "$CALLER_FILE"
    rg -n -C5 "$BASENAME_TARGET" "$sf" 2>/dev/null >> "$CALLER_FILE"
    echo '```' >> "$CALLER_FILE"
    echo "" >> "$CALLER_FILE"
  done

  # 500 行安全閥
  CALLER_LINES=$(wc -l < "$CALLER_FILE" | tr -d ' ')
  if [ "$CALLER_LINES" -gt 500 ]; then
    head -500 "$CALLER_FILE" > "${CALLER_FILE}.tmp"
    echo "" >> "${CALLER_FILE}.tmp"
    echo "⚠️ TRUNCATED: ${CALLER_LINES} → 500 行" >> "${CALLER_FILE}.tmp"
    mv "${CALLER_FILE}.tmp" "$CALLER_FILE"
    CALLER_LINES=500
  fi

  # 計算壓縮率
  ORIG_LINES=0
  for sf in $EXTRA_FILES; do
    [ -f "$sf" ] && ORIG_LINES=$((ORIG_LINES + $(wc -l < "$sf" | tr -d ' ')))
  done
  echo "  ${TOTAL_REFS} 個引用，${CALLER_LINES} 行（原始 ${ORIG_LINES} 行，壓縮 $((CALLER_LINES * 100 / (ORIG_LINES + 1)))%）"
else
  echo "  SKIP: 無補充檔案"
  echo "# Step 0.9 skipped -- no supplementary files" > "$CALLER_FILE"
fi
step_end "STEP09"

# ==============================================================================
# Step 1: Gemini 盲掃
# ==============================================================================

echo "[Step 1] Gemini 盲掃..."
step_start "step1"

GEMINI_EXTRA_HINT=""
if [ -n "$(echo "$EXTRA_FILES" | tr -d '[:space:]')" ]; then
  GEMINI_EXTRA_HINT="

## Step 0 Discovery Note
The following related files were found by static scan (not included in full -- reference them in Section 4):
$(echo "$EXTRA_FILES" | tr ' ' '\n' | grep '[^[:space:]]' | sed 's/^/- /')"
fi

# 組合 Gemini prompt：盲掃模板 + 重構意圖 + 發現檔案 + 目標原始碼
GEMINI_INTENT_HINT=""
[ -n "$REFACTORING_INTENT" ] && GEMINI_INTENT_HINT="
## Refactoring Intent
$REFACTORING_INTENT
"

GEMINI_PROMPT_FILE="$RUN_DIR/prompt-step1-gemini.md"
{ cat "$PROMPTS/gemini-blind-scan.md" | sed "s/{language}/${LANGUAGE}/g"; echo "$GEMINI_INTENT_HINT"; echo "$GEMINI_EXTRA_HINT"; cat $TARGET_FILES; } \
  > "$GEMINI_PROMPT_FILE"

if [ "$AGENT_MODE" = "true" ]; then
  echo "  AGENT: prompt 已寫入 $GEMINI_PROMPT_FILE"
  echo "  等待外部完成: $RUN_DIR/gemini-findings.md"
  step_end "STEP1"
  # Agent 模式在此暫停 — Step 0/0.5 的靜態結果已產出，
  # 後續 LLM 步驟由呼叫者（Claude Code skill）協調
  echo ""
  echo "=== Agent 模式暫停 ==="
  echo "靜態分析已完成（Step 0, 0.5, 0.7, 0.8, 0.9）。"
  if [ -f "$ANCHOR_FILE" ] && grep -q "^|" "$ANCHOR_FILE" 2>/dev/null; then
    ANCHOR_TOTAL=$(grep -c "^| [0-9]" "$ANCHOR_FILE" 2>/dev/null || true)
    ANCHOR_TOTAL=${ANCHOR_TOTAL:-0}
    echo "錨定合約: ${ANCHOR_TOTAL} 個錨點（${ANCHOR_FILE}）"
  fi
  if [ -f "$SKETCH_FILE" ] && [ "$(wc -l < "$SKETCH_FILE")" -gt 3 ]; then
    SKETCH_METHODS=$(grep -c "^|.*\`" "$SKETCH_FILE" 2>/dev/null || true)
    SKETCH_METHODS=${SKETCH_METHODS:-0}
    echo "Feature Sketch: ${SKETCH_METHODS} 個方法（${SKETCH_FILE}）"
  fi
  if [ -f "$CALLER_FILE" ] && [ "$(wc -l < "$CALLER_FILE")" -gt 3 ]; then
    echo "Caller Interface: ${CALLER_FILE}"
  fi
  echo "以下 prompt 檔案已準備好供外部 LLM 呼叫："
  echo ""
  echo "  Step 1 (Gemini):  $GEMINI_PROMPT_FILE"
  echo "    輸出到:          $RUN_DIR/gemini-findings.md"
  echo ""

  # 提前產出 Step 1.5/2/3/4 的 prompt 檔案
  # Step 1.5: 依賴圖譜分析
  DEP_ANALYSIS_FILE="$RUN_DIR/dependency-graph.json"
  if [ -n "$IMPORT_PATTERNS" ] && [ "$SEAM_DETECTION" = "true" ]; then
    IMPORT_LIST=""
    for tf in $ALL_TARGET_FILES; do
      if [ -f "$tf" ]; then
        IMPORTS=$(rg "$IMPORT_PATTERNS" "$tf" 2>/dev/null || true)
        if [ -n "$IMPORTS" ]; then
          IMPORT_LIST="${IMPORT_LIST}
--- $tf ---
$IMPORTS"
        fi
      fi
    done
    REVERSE_DEPS=""
    for tf in $TARGET_FILES; do
      BASENAME=$(basename "${tf%.*}")
      RDEPS=$(rg "$BASENAME" $RG_TYPE_ARGS -l "$PROJECT_ROOT" 2>/dev/null \
        | grep -vE 'Tests?/|Spec\.|\.build/' \
        | head -10 || true)
      [ -n "$RDEPS" ] && REVERSE_DEPS="${REVERSE_DEPS}
--- 依賴 $BASENAME 的檔案 ---
$RDEPS"
    done

    cat > "$RUN_DIR/prompt-step1.5-dep.md" <<DEPPROMPT
你是一位遺留代碼專家。基於以下依賴資訊，執行以下分析：

1. 建立依賴方向圖（簡化版，列出 A -> B 表示 A 依賴 B）
2. 為每個依賴標記 Seam 類型：
   - Object Seam: 可透過物件替換改變行為（依賴注入、Protocol/Interface）
   - Preprocessing Seam: 編譯期可替換（宏、條件編譯）
   - Link Seam: 連結期可替換（動態連結庫、module alias）
   - None: 硬依賴，無法輕易替換
3. 識別 Pinch Point：入邊數 >= $PINCH_POINT_THRESHOLD 的節點
4. 為每個 Pinch Point 建議依賴打破策略（Sprout/Wrap/Extract Interface）

語言: $LANGUAGE
模組: $MODULE_NAME
重構意圖: ${REFACTORING_INTENT:-未指定}

=== 正向依賴（目標模組 import 了什麼）===
$IMPORT_LIST

=== 反向依賴（誰 import 了目標模組）===
$REVERSE_DEPS

輸出格式為 JSON，結構如下：
{
  "dependency_graph": [
    { "from": "ModuleA", "to": "ModuleB", "seam_type": "object|preprocessing|link|none" }
  ],
  "pinch_points": [
    {
      "node": "ModuleName",
      "in_degree": 5,
      "is_pinch_point": true,
      "suggested_strategy": "Extract Interface / Sprout / Wrap"
    }
  ],
  "seam_summary": [
    { "dependency": "A -> B", "seam_type": "object", "reason": "..." }
  ]
}
只輸出合法的 JSON，不要包含 Markdown 或其他格式。
DEPPROMPT
    echo "  Step 1.5 (Claude): $RUN_DIR/prompt-step1.5-dep.md"
    echo "    輸出到:           $DEP_ANALYSIS_FILE"
  fi

  # Step 2: Claude 結構化審計
  AUDIT_PROMPT=""
  if [ -f "$PROMPTS/skeleton.md" ]; then
    AUDIT_PROMPT=$(cat "$PROMPTS/skeleton.md")
  fi
  if [ -n "$LANGUAGE" ] && [ -f "$PROMPTS/languages/${LANGUAGE}.md" ]; then
    AUDIT_PROMPT=$(echo "$AUDIT_PROMPT" | sed "s/{language_plugin}/languages\/${LANGUAGE}.md/g")
    AUDIT_PROMPT="${AUDIT_PROMPT}

--- LANGUAGE PLUGIN: ${LANGUAGE} ---
$(cat "$PROMPTS/languages/${LANGUAGE}.md")
--- END LANGUAGE PLUGIN ---"
  fi
  INTENT_CONTEXT=""
  [ -n "$REFACTORING_INTENT" ] && INTENT_CONTEXT="
## Refactoring Intent
$REFACTORING_INTENT
"
  # 組合錨定合約上下文
  ANCHOR_CONTEXT=""
  if [ -f "$ANCHOR_FILE" ] && grep -q "^|" "$ANCHOR_FILE" 2>/dev/null; then
    ANCHOR_CONTEXT="

## Step 0.7 錨定合約
$(cat "$ANCHOR_FILE")

對於每個錨定合約，你的 Artifact 1 必須包含至少一個對應的 {Category}-{NNN} 合約。
若你認為某個錨點不構成合約，必須在 Artifact 4 中說明原因。
"
  fi

  # 組合 Feature Sketch 上下文
  SKETCH_CONTEXT=""
  if [ -f "$SKETCH_FILE" ] && [ "$(wc -l < "$SKETCH_FILE")" -gt 3 ]; then
    SKETCH_CONTEXT="

## Step 0.8 Feature Sketch
以下方法-屬性矩陣顯示模組內部的功能群集，用於識別 M（Mutation）和 L（Lifecycle）合約：
$(cat "$SKETCH_FILE")
"
  fi

  # 組合 Caller Interface 上下文
  CALLER_CONTEXT=""
  if [ -f "$CALLER_FILE" ] && [ "$(wc -l < "$CALLER_FILE")" -gt 3 ]; then
    CALLER_CONTEXT="

## Step 0.9 Caller Interface
以下是外部模組引用目標模組的片段，用於識別 D（Dependency）和 P（Propagation）合約：
$(cat "$CALLER_FILE")
"
  fi

  { echo "${AUDIT_PROMPT}${INTENT_CONTEXT}${ANCHOR_CONTEXT}${SKETCH_CONTEXT}${CALLER_CONTEXT}"; echo ""; echo "## 目標原始碼"; echo ""; cat $TARGET_FILES; } \
    > "$RUN_DIR/prompt-step2-audit.md"
  echo "  Step 2 (Claude):  $RUN_DIR/prompt-step2-audit.md"
  echo "    輸出到:          $RUN_DIR/claude-artifacts/all-artifacts.md"

  # Step 3: Codex 對抗性評論（Agent 模式追加格式提示，避免判定詞解析失敗）
  { cat "$PROMPTS/codex-adversary.md"; echo "$VERDICT_RETRY_HINT"; } \
    > "$RUN_DIR/prompt-step3-codex.md"
  echo "  Step 3 (Codex):   $RUN_DIR/prompt-step3-codex.md"
  echo "    輸入:            all-artifacts.md + gemini-findings.md"
  echo "    輸出到:          $RUN_DIR/codex-review.md"

  # Step 4: Claude 合併
  cp "$PROMPTS/claude-applier.md" "$RUN_DIR/prompt-step4-applier.md"
  echo "  Step 4 (Claude):  $RUN_DIR/prompt-step4-applier.md"
  echo "    輸入:            all-artifacts.md + codex-review.md + dependency-graph.json"
  echo "    輸出到:          $RUN_DIR/final-contracts.md"
  echo "                     $PHASE_B/verify-contracts-${MODULE_NAME}.sh"

  echo ""
  echo "Feathers 掃描: $FEATHERS_SCAN_FILE"
  echo "所有目標檔案:  $ALL_TARGET_FILES"
  echo ""
  echo "呼叫者可依序執行 Step 1→1.5→2→3→4，"
  echo "或平行執行 Step 1 和 Step 1.5，再接續 Step 2→3→4。"
  exit 0
fi

{ cat "$GEMINI_PROMPT_FILE"; } \
  | gemini -m gemini-2.5-pro -p - --sandbox false \
  > "$RUN_DIR/gemini-findings.md"

GEMINI_LINES=$(wc -l < "$RUN_DIR/gemini-findings.md")
if [ "$GEMINI_LINES" -le 30 ]; then
  echo "ABORT: Gemini 輸出過短（$GEMINI_LINES 行，需 > 30）。"
  exit 1
fi
echo "  PASS: $GEMINI_LINES 行"
step_end "STEP1"

# ==============================================================================
# Step 1.5: 依賴圖譜分析（Feathers 第 3 步「打破依賴」）
# ==============================================================================

echo "[Step 1.5] 依賴圖譜分析..."
step_start "step15"

DEP_ANALYSIS_FILE="$RUN_DIR/dependency-graph.json"

if [ -n "$IMPORT_PATTERNS" ]; then
  echo "  import 模式: $IMPORT_PATTERNS"

  # 1. 從目標檔案提取 import/include 清單
  IMPORT_LIST=""
  for tf in $ALL_TARGET_FILES; do
    if [ -f "$tf" ]; then
      IMPORTS=$(rg "$IMPORT_PATTERNS" "$tf" 2>/dev/null || true)
      if [ -n "$IMPORTS" ]; then
        IMPORT_LIST="${IMPORT_LIST}
--- $tf ---
$IMPORTS"
      fi
    fi
  done

  # 2. 從相依檔案反向搜尋（誰 import 了目標模組）
  REVERSE_DEPS=""
  for tf in $TARGET_FILES; do
    BASENAME=$(basename "${tf%.*}")
    RDEPS=$(rg "$BASENAME" $RG_TYPE_ARGS -l "$PROJECT_ROOT" 2>/dev/null \
      | grep -vE 'Tests?/|Spec\.|\.build/' \
      | head -10 || true)
    [ -n "$RDEPS" ] && REVERSE_DEPS="${REVERSE_DEPS}
--- 依賴 $BASENAME 的檔案 ---
$RDEPS"
  done

  # 3. 呼叫 LLM 識別 Seam 類型和 Pinch Point
  if [ "$SEAM_DETECTION" = "true" ]; then
    echo "  Seam 識別已啟用（pinch_point_threshold=${PINCH_POINT_THRESHOLD}）"

    DEP_PROMPT="你是一位遺留代碼專家。基於以下依賴資訊，執行以下分析：

1. 建立依賴方向圖（簡化版，列出 A -> B 表示 A 依賴 B）
2. 為每個依賴標記 Seam 類型：
   - Object Seam: 可透過物件替換改變行為（依賴注入、Protocol/Interface）
   - Preprocessing Seam: 編譯期可替換（宏、條件編譯）
   - Link Seam: 連結期可替換（動態連結庫、module alias）
   - None: 硬依賴，無法輕易替換
3. 識別 Pinch Point：入邊數 >= $PINCH_POINT_THRESHOLD 的節點
4. 為每個 Pinch Point 建議依賴打破策略（Sprout/Wrap/Extract Interface）

語言: $LANGUAGE
模組: $MODULE_NAME
重構意圖: ${REFACTORING_INTENT:-未指定}

=== 正向依賴（目標模組 import 了什麼）===
$IMPORT_LIST

=== 反向依賴（誰 import 了目標模組）===
$REVERSE_DEPS

輸出格式為 JSON，結構如下：
{
  \"dependency_graph\": [
    { \"from\": \"ModuleA\", \"to\": \"ModuleB\", \"seam_type\": \"object|preprocessing|link|none\" }
  ],
  \"pinch_points\": [
    {
      \"node\": \"ModuleName\",
      \"in_degree\": 5,
      \"is_pinch_point\": true,
      \"suggested_strategy\": \"Extract Interface / Sprout / Wrap\"
    }
  ],
  \"seam_summary\": [
    { \"dependency\": \"A -> B\", \"seam_type\": \"object\", \"reason\": \"...\" }
  ]
}
只輸出合法的 JSON，不要包含 Markdown 或其他格式。"

    claude_isolated "$DEP_PROMPT" > "$DEP_ANALYSIS_FILE"

    DEP_LINES=$(wc -l < "$DEP_ANALYSIS_FILE")
    echo "  PASS: 依賴分析完成（$DEP_LINES 行）"
  else
    echo "  SKIP: Seam 識別已停用"
    echo '{"dependency_graph":[],"pinch_points":[],"seam_summary":[]}' > "$DEP_ANALYSIS_FILE"
  fi
else
  echo "  SKIP: 未設定 import_patterns，跳過依賴分析"
  echo '{"dependency_graph":[],"pinch_points":[],"seam_summary":[]}' > "$DEP_ANALYSIS_FILE"
fi
step_end "STEP15"

# ==============================================================================
# Step 2: Claude 結構化審計
# ==============================================================================

echo "[Step 2] Claude 結構化審計..."
step_start "step2"

# 組合 prompt：skeleton + 語言插件
AUDIT_PROMPT=""

if [ -f "$PROMPTS/skeleton.md" ]; then
  AUDIT_PROMPT=$(cat "$PROMPTS/skeleton.md")
else
  # Fallback：使用舊的單體 prompt
  log "  WARN: skeleton.md 不存在，嘗試使用 claude-contract-audit.md"
  if [ -f "$PROMPTS/claude-contract-audit.md" ]; then
    AUDIT_PROMPT=$(cat "$PROMPTS/claude-contract-audit.md")
  else
    log "  ERROR: 找不到審計 prompt 模板"
    exit 1
  fi
fi

# 替換 {language_plugin} 佔位符為實際語言插件檔名
if [ -n "$LANGUAGE" ] && [ -f "$PROMPTS/languages/${LANGUAGE}.md" ]; then
  AUDIT_PROMPT=$(echo "$AUDIT_PROMPT" | sed "s/{language_plugin}/languages\/${LANGUAGE}.md/g")
  AUDIT_PROMPT="${AUDIT_PROMPT}

--- LANGUAGE PLUGIN: ${LANGUAGE} ---
$(cat "$PROMPTS/languages/${LANGUAGE}.md")
--- END LANGUAGE PLUGIN ---"
  echo "  語言插件: ${LANGUAGE}.md"
else
  # 無語言插件時，清除佔位符避免混淆
  AUDIT_PROMPT=$(echo "$AUDIT_PROMPT" | sed 's/{language_plugin}/（未指定語言插件）/g')
fi

# 附加 Feathers 掃描結果（如果有）
FEATHERS_CONTEXT=""
if [ -f "$FEATHERS_SCAN_FILE" ] && [ "$(wc -l < "$FEATHERS_SCAN_FILE")" -gt 3 ]; then
  FEATHERS_CONTEXT="

## Step 0.5 Feathers 規則掃描結果
以下是 Feathers 規則對目標模組的靜態掃描結果，請在合約分析中參考這些結構性品質問題：
$(cat "$FEATHERS_SCAN_FILE")
"
fi

# 附加依賴分析結果（如果有）
DEP_CONTEXT=""
if [ -f "$DEP_ANALYSIS_FILE" ] && ! grep -q '"dependency_graph":\[\]' "$DEP_ANALYSIS_FILE" 2>/dev/null; then
  DEP_CONTEXT="

## Step 1.5 依賴分析結果（JSON）
$(cat "$DEP_ANALYSIS_FILE")

請在合約中標記以下元資料：
- scope: method / class / module
- seam_type: object / preprocessing / link / none（參考 JSON 中的 seam_type）
- pinch_point: true / false（參考 JSON 中的 pinch_points）
"
fi

# 附加錨定合約（Step 0.7）
ANCHOR_CONTEXT=""
if [ -f "$ANCHOR_FILE" ] && grep -q "^|" "$ANCHOR_FILE" 2>/dev/null; then
  ANCHOR_CONTEXT="

## Step 0.7 錨定合約
$(cat "$ANCHOR_FILE")

對於每個錨定合約，你的 Artifact 1 必須包含至少一個對應的 {Category}-{NNN} 合約。
若你認為某個錨點不構成合約，必須在 Artifact 4 中說明原因。
"
fi

# 附加重構意圖
INTENT_CONTEXT=""
[ -n "$REFACTORING_INTENT" ] && INTENT_CONTEXT="
## Refactoring Intent
$REFACTORING_INTENT
"

# 附加 Feature Sketch（Step 0.8）
SKETCH_CONTEXT=""
if [ -f "$SKETCH_FILE" ] && [ "$(wc -l < "$SKETCH_FILE")" -gt 3 ]; then
  SKETCH_CONTEXT="

## Step 0.8 Feature Sketch
以下方法-屬性矩陣顯示模組內部的功能群集，用於識別 M（Mutation）和 L（Lifecycle）合約：
$(cat "$SKETCH_FILE")
"
fi

# 附加 Caller Interface（Step 0.9）
CALLER_CONTEXT=""
if [ -f "$CALLER_FILE" ] && [ "$(wc -l < "$CALLER_FILE")" -gt 3 ]; then
  CALLER_CONTEXT="

## Step 0.9 Caller Interface
以下是外部模組引用目標模組的片段，用於識別 D（Dependency）和 P（Propagation）合約：
$(cat "$CALLER_FILE")
"
fi

claude_isolated "${AUDIT_PROMPT}${INTENT_CONTEXT}${FEATHERS_CONTEXT}${DEP_CONTEXT}${ANCHOR_CONTEXT}${SKETCH_CONTEXT}${CALLER_CONTEXT}

$(cat $TARGET_FILES)" > "$RUN_DIR/claude-artifacts/all-artifacts.md"

# 品質門檻：Unclassified 必須為 0
if ! grep -q "Unclassified:.*0" "$RUN_DIR/claude-artifacts/all-artifacts.md"; then
  echo "ABORT: Artifact 4 顯示有未分類的行。品質門檻要求 Unclassified: 0。"
  echo "  檢查: $RUN_DIR/claude-artifacts/all-artifacts.md"
  exit 1
fi
echo "  PASS: Unclassified: 0 確認"

# ── Step 2.5: 結構完整性軟門檻 ──
echo "[Step 2.5] 結構完整性檢查..."
step_end "STEP2"
MISSING_CATEGORIES=""
for prefix in M L N S E C D P; do
  COUNT=$(grep -c "^### ${prefix}-[0-9]\{3\}" "$RUN_DIR/claude-artifacts/all-artifacts.md" 2>/dev/null || true)
  COUNT=${COUNT:-0}
  if [ "$COUNT" -eq 0 ]; then
    echo "  ${prefix}-contracts: 0 ⚠️  MISSING"
    MISSING_CATEGORIES="${MISSING_CATEGORIES} ${prefix}"
  else
    echo "  ${prefix}-contracts: $COUNT"
  fi
done
if [ -n "$MISSING_CATEGORIES" ]; then
  echo "  ⚠️  缺失類別:${MISSING_CATEGORIES}"
  echo "  （軟門檻 -- 管線繼續，Codex Step 3 可能補充）"
else
  echo "  ✓ 全部 8 類別均有覆蓋"
fi

# ── 錨定合約覆蓋檢查 ──
if [ -f "$ANCHOR_FILE" ] && grep -q "^|" "$ANCHOR_FILE" 2>/dev/null; then
  # 計算錨點數（排除表頭行）
  ANCHOR_TOTAL=$(grep -c "^| [0-9]" "$ANCHOR_FILE" 2>/dev/null || true)
  ANCHOR_TOTAL=${ANCHOR_TOTAL:-0}
  ANCHOR_COVERED=0

  # 對每個錨定類別，檢查 all-artifacts.md 中是否有對應合約
  while IFS='|' read -r _ num cat name _rest; do
    # 清理空白
    cat=$(echo "$cat" | tr -d ' ')
    [ -z "$cat" ] && continue
    [[ "$cat" =~ ^[#-] ]] && continue

    # 檢查 all-artifacts.md 中是否有 {cat}-{NNN} 格式的合約
    if grep -q "^### ${cat}-[0-9]\{3\}" "$RUN_DIR/claude-artifacts/all-artifacts.md" 2>/dev/null; then
      ANCHOR_COVERED=$((ANCHOR_COVERED + 1))
    fi
  done < <(grep "^| [0-9]" "$ANCHOR_FILE" 2>/dev/null || true)

  echo "  錨點覆蓋: ${ANCHOR_COVERED} / ${ANCHOR_TOTAL}（類別層級）"
  if [ "$ANCHOR_COVERED" -lt "$ANCHOR_TOTAL" ]; then
    # 找出未覆蓋的類別
    UNCOVERED_CATS=""
    while IFS='|' read -r _ num cat name _rest; do
      cat=$(echo "$cat" | tr -d ' ')
      [ -z "$cat" ] && continue
      if ! grep -q "^### ${cat}-[0-9]\{3\}" "$RUN_DIR/claude-artifacts/all-artifacts.md" 2>/dev/null; then
        UNCOVERED_CATS="${UNCOVERED_CATS} ${cat}"
      fi
    done < <(grep "^| [0-9]" "$ANCHOR_FILE" 2>/dev/null || true)
    UNCOVERED_CATS=$(echo "$UNCOVERED_CATS" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    echo "  ⚠️  有未被合約涵蓋的錨點類別:${UNCOVERED_CATS}"
  fi
fi

# ==============================================================================
# Step 3: Codex 對抗性評論
# ==============================================================================

echo "[Step 3] Codex 對抗性評論..."
step_start "step3"

CODEX_PROMPT_BASE="$(cat "$PROMPTS/codex-adversary.md"; echo; cat "$RUN_DIR/claude-artifacts/all-artifacts.md"; echo; cat "$RUN_DIR/gemini-findings.md")"

codex exec \
  -o "$RUN_DIR/codex-review.md" \
  "$CODEX_PROMPT_BASE"

# -- 判定詞模糊解析 + retry 機制 --
# 檢查是否有任何 CONFIRM/DISPUTE/ADD 判定詞
if ! has_any_verdict "$RUN_DIR/codex-review.md"; then
  echo "  WARN: 首次輸出中未找到任何判定詞（CONFIRM/DISPUTE/ADD），retry 1 次..."

  # 備份首次輸出供除錯
  cp "$RUN_DIR/codex-review.md" "$RUN_DIR/codex-review.attempt1.md"

  # Retry：追加格式提示後重新呼叫
  codex exec \
    -o "$RUN_DIR/codex-review.md" \
    "${CODEX_PROMPT_BASE}${VERDICT_RETRY_HINT}"

  if ! has_any_verdict "$RUN_DIR/codex-review.md"; then
    echo "  WARN: retry 後仍無法解析判定詞，所有合約標記為 UNCERTAIN"
    # 從 all-artifacts.md 提取所有合約 ID，標記為 UNCERTAIN
    {
      echo "# UNCERTAIN -- 判定詞解析失敗，以下為自動產生的 UNCERTAIN 標記"
      grep -oE '^### [A-Z]-[0-9]{3}' "$RUN_DIR/claude-artifacts/all-artifacts.md" 2>/dev/null \
        | sed 's/^### /UNCERTAIN /' | sed 's/$/:  LLM 輸出格式異常，無法解析判定詞/' || true
      echo ""
      echo "SUMMARY"
      echo "CONFIRM: 0"
      echo "DISPUTE: 0"
      echo "ADD: 0"
      echo "UNCERTAIN: ALL"
      echo "CONFIRM_RATIO: 0%"
    } > "$RUN_DIR/codex-review.md"
  else
    echo "  OK: retry 成功，已找到判定詞"
  fi
fi

# 輸出解析統計（使用模糊匹配）
_V_CONFIRM=$(parse_verdict "CONFIRM" "$RUN_DIR/codex-review.md")
_V_DISPUTE=$(parse_verdict "DISPUTE" "$RUN_DIR/codex-review.md")
_V_ADD=$(parse_verdict "ADD" "$RUN_DIR/codex-review.md")
echo "  解析結果: CONFIRM=${_V_CONFIRM}, DISPUTE=${_V_DISPUTE}, ADD=${_V_ADD}"

# 品質門檻：CONFIRM ratio <= 70%（使用模糊解析）
CONFIRM_RATIO=$(parse_confirm_ratio "$RUN_DIR/codex-review.md")

DEGRADED="no"
if [ -z "$CONFIRM_RATIO" ]; then
  echo "  WARN: 無法從 codex-review.md 解析 CONFIRM_RATIO -- 標記為 DEGRADED"
  DEGRADED="yes"
elif [ "$CONFIRM_RATIO" -gt 70 ]; then
  echo "  DEGRADED: CONFIRM ratio $CONFIRM_RATIO% > 70% -- 對抗性評論過弱"
  DEGRADED="yes"
else
  echo "  PASS: CONFIRM ratio ${CONFIRM_RATIO}%"
fi
step_end "STEP3"

# ==============================================================================
# Step 4: Claude 合併 + Pinch Point 標記
# ==============================================================================

echo "[Step 4] Claude 合併 + Pinch Point 標記..."
step_start "step4"
echo "DEGRADED=$DEGRADED" >> "$RUN_DIR/codex-review.md"

# 組合 applier prompt，附加 Pinch Point 標記指令
APPLIER_EXTRA=""
if [ -f "$DEP_ANALYSIS_FILE" ] && ! grep -q '"dependency_graph":\[\]' "$DEP_ANALYSIS_FILE" 2>/dev/null; then
  APPLIER_EXTRA="

## Pinch Point 標記指令
參考以下依賴分析結果（JSON 格式），在最終合約中為每個合約加入元資料：
- scope: method | class | module
- seam_type: object | preprocessing | link | none
- pinch_point: true | false

$(cat "$DEP_ANALYSIS_FILE")
"
fi

# Step 4 使用 RUN_DIR 作為 cwd，讓 Claude 寫的檔案落在正確位置
pushd "$RUN_DIR" > /dev/null
env -u CLAUDECODE claude \
  -p "$(cat "$PROMPTS/claude-applier.md")${APPLIER_EXTRA}

$(cat "$RUN_DIR/claude-artifacts/all-artifacts.md")

$(cat "$RUN_DIR/codex-review.md")" \
  --no-session-persistence \
  --permission-mode bypassPermissions \
  --output-format text > "$RUN_DIR/apply.log"
popd > /dev/null

# 驗證產出檔案（Claude 可能寫到 $RUN_DIR/ 或 $RUN_DIR/audit/output/ 或 $RUN_DIR/audit/phase-b/）
CONTRACTS_FOUND="false"
VERIFY_FOUND="false"
for candidate in "$RUN_DIR/final-contracts.md" "$RUN_DIR/audit/output/final-contracts.md"; do
  if [ -f "$candidate" ]; then
    CONTRACTS_FOUND="true"
    cp "$candidate" "$RUN_DIR/final-contracts.md" 2>/dev/null || true
    cp "$candidate" "$OUTPUT/final-contracts.md"
    break
  fi
done
for candidate in \
  "$RUN_DIR/verify-contracts-${MODULE_NAME}.sh" \
  "$RUN_DIR/audit/phase-b/verify-contracts-${MODULE_NAME}.sh"; do
  if [ -f "$candidate" ]; then
    VERIFY_FOUND="true"
    cp "$candidate" "$RUN_DIR/verify-contracts-${MODULE_NAME}.sh" 2>/dev/null || true
    mkdir -p "$PHASE_B"
    cp "$candidate" "$PHASE_B/verify-contracts-${MODULE_NAME}.sh"
    break
  fi
done

if [ "$CONTRACTS_FOUND" = "false" ]; then
  echo "ABORT: Applier 未產出 final-contracts.md"
  exit 1
fi
if [ "$VERIFY_FOUND" = "false" ]; then
  echo "ABORT: Applier 未產出 verify-contracts-${MODULE_NAME}.sh"
  exit 1
fi
echo "  PASS: final-contracts.md 和驗證腳本已產出"

# ── 歸檔 ast-grep 規則 ──
if compgen -G "$PHASE_B/rules/*.yml" > /dev/null 2>&1; then
  cp "$PHASE_B/rules/"*.yml "$RUN_DIR/"
fi
# Claude 可能把 rules 寫到 $RUN_DIR/audit/phase-b/rules/
if compgen -G "$RUN_DIR/audit/phase-b/rules/*.yml" > /dev/null 2>&1; then
  mkdir -p "$PHASE_B/rules"
  cp "$RUN_DIR/audit/phase-b/rules/"*.yml "$RUN_DIR/"
  cp "$RUN_DIR/audit/phase-b/rules/"*.yml "$PHASE_B/rules/"
fi
step_end "STEP4"

# ==============================================================================
# Step 5: 自我驗證
# ==============================================================================

echo "[Step 5] 自我驗證（Phase B 對當前原始碼）..."
step_start "step5"
chmod +x "$PHASE_B/verify-contracts-${MODULE_NAME}.sh"
if ! bash "$PHASE_B/run-ci.sh"; then
  echo "ABORT: Phase B 自我檢查失敗。Applier 產出有問題。"
  exit 1
fi
echo "  PASS: Phase B 自我檢查 100%"
step_end "STEP5"

# ==============================================================================
# 完成
# ==============================================================================

# 更新 latest 符號連結
ln -sfn "runs/$RUN_ID" "$OUTPUT/latest"

# -- 計時摘要 --
PIPELINE_END=$(date +%s)
PIPELINE_TOTAL=$((PIPELINE_END - PIPELINE_START))

echo ""
echo "=== Phase A 完成 ==="
echo "Run ID:         $RUN_ID"
echo "Run dir:        $RUN_DIR"
echo "Latest:         $OUTPUT/latest -> runs/$RUN_ID"
echo "最終合約:       $RUN_DIR/final-contracts.md"
echo "CI 腳本:        $RUN_DIR/verify-contracts-${MODULE_NAME}.sh"
echo "ast-grep 規則:  $PHASE_B/rules/"
echo "依賴分析:       $RUN_DIR/dependency-graph.json"
echo "管線設定:       $RUN_DIR/pipeline-config.log"
echo ""
echo "=== 計時摘要 ==="
printf "  Step 0   邊界發現:      %4ds\n" "$T_STEP0"
printf "  Step 0.5 Feathers:      %4ds\n" "$T_STEP05"
printf "  Step 0.7 錨定預掃描:   %4ds\n" "$T_STEP07"
printf "  Step 0.8 Feature Sketch:%4ds\n" "$T_STEP08"
printf "  Step 0.9 Caller Iface:  %4ds\n" "$T_STEP09"
printf "  Step 1   Gemini:        %4ds\n" "$T_STEP1"
printf "  Step 1.5 依賴分析:      %4ds\n" "$T_STEP15"
printf "  Step 2   Claude 審計:   %4ds\n" "$T_STEP2"
printf "  Step 3   Codex 對抗:    %4ds\n" "$T_STEP3"
printf "  Step 4   合併:          %4ds\n" "$T_STEP4"
printf "  Step 5   驗證:          %4ds\n" "$T_STEP5"
printf "  ──────────────────────────────\n"
printf "  總計:                   %4ds (%dm %ds)\n" "$PIPELINE_TOTAL" "$((PIPELINE_TOTAL/60))" "$((PIPELINE_TOTAL%60))"

# 寫入計時到執行記錄
cat >> "$RUN_DIR/pipeline-config.log" <<TIMING
---
timing:
  step0_boundary: ${T_STEP0}s
  step05_feathers: ${T_STEP05}s
  step07_anchor: ${T_STEP07}s
  step08_sketch: ${T_STEP08}s
  step09_caller: ${T_STEP09}s
  step1_gemini: ${T_STEP1}s
  step15_dependency: ${T_STEP15}s
  step2_audit: ${T_STEP2}s
  step3_codex: ${T_STEP3}s
  step4_merge: ${T_STEP4}s
  step5_verify: ${T_STEP5}s
  total: ${PIPELINE_TOTAL}s
TIMING
