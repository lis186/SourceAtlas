#!/bin/bash
# run-baseline.sh -- Phase A 合約審計管線orchestrator
#
# 支援兩種模式：
#   1. 配置檔驅動：自動讀取 audit.config.yml
#   2. CLI 參數驅動：向後相容，無配置檔時用 CLI 參數
#
# CLI 參數優先於配置檔（可覆蓋任何設定）。
#
# 用法：
#   bash run-baseline.sh                              # 讀取 audit.config.yml
#   bash run-baseline.sh --config path/to/config.yml  # 指定配置檔
#   bash run-baseline.sh file1.m file2.h              # 純 CLI 模式（向後相容）
#   bash run-baseline.sh --module Foo --language swift file.swift
#
# 管線步驟：
#   Step 0:   邊界發現（rg 靜態掃描）
#   Step 0.5: Feathers 規則掃描（可選，--skip-feathers 跳過）
#   Step 1:   Gemini 盲掃
#   Step 1.5: 依賴圖譜分析（Seam + Pinch Point）
#   Step 2:   Claude 結構化審計
#   Step 3:   Codex 對抗性評論
#   Step 4:   Claude 合併 + Pinch Point 標記
#
# 外部依賴：
#   gemini  -- Google Gemini CLI（Step 1 盲掃）
#   claude  -- Anthropic Claude Code CLI（Step 1.5, 2, 4）
#   codex   -- OpenAI Codex CLI，使用 codex exec（Step 3 對抗性評論）
#   rg      -- ripgrep，用於靜態文字搜尋（Step 0, 0.5）
#   YAML 解析使用內建 awk/grep/sed，不需要 yq

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

# ==============================================================================
# 初始化執行環境
# ==============================================================================

RUN_ID=$(TZ=Asia/Taipei date +%Y%m%d-%H%M%S)
RUN_DIR="$OUTPUT/runs/$RUN_ID"
PROJECT_ROOT="$(pwd)"

mkdir -p "$RUN_DIR/claude-artifacts"

echo "=== Phase A 合約審計管線 ==="
echo "模組名稱: $MODULE_NAME"
echo "語言:     $LANGUAGE"
echo "Run ID:   $RUN_ID"
echo "Run Dir:  $RUN_DIR"
echo "目標檔案: $TARGET_FILES"
[ -n "$REFACTORING_INTENT" ] && echo "重構意圖: $REFACTORING_INTENT"
[ -n "$CONFIG_FILE" ] && echo "配置檔:   $CONFIG_FILE"
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
config_file: ${CONFIG_FILE:-none}
EOF

# ==============================================================================
# Step 0: 邊界發現
# ==============================================================================

echo "[Step 0] 邊界發現..."

TARGET_DIR="$(dirname "${CLI_TARGETS[0]}")"
EXTRA_FILES=""

# 建立 rg --type 參數
RG_TYPE_ARGS=""
if [ -n "$FILE_TYPES" ]; then
  IFS=',' read -ra FT_ARRAY <<< "$FILE_TYPES"
  for ft in "${FT_ARRAY[@]}"; do
    RG_TYPE_ARGS="$RG_TYPE_ARGS --type $ft"
  done
fi

# 觀察者模式搜尋
OBSERVER_FILES=""
if [ -n "$OBSERVER_PATTERNS" ]; then
  OBSERVER_FILES=$(rg "$OBSERVER_PATTERNS" \
    $RG_TYPE_ARGS -l "$PROJECT_ROOT" 2>/dev/null \
    | grep -vE 'Tests?/|Spec\.' \
    | grep -v "$(basename "${CLI_TARGETS[0]}")" \
    | head -"$MAX_BOUNDARY_FILES" || true)
fi

# 同步原語搜尋
SEMAPHORE_FILES=""
if [ -n "$SYNC_PATTERNS" ]; then
  SEMAPHORE_FILES=$(rg "$SYNC_PATTERNS" \
    $RG_TYPE_ARGS -l "$TARGET_DIR" 2>/dev/null \
    | grep -v "$(basename "${CLI_TARGETS[0]}")" \
    | head -"$MAX_BOUNDARY_FILES" || true)
fi

EXTRA_FILES="$OBSERVER_FILES $SEMAPHORE_FILES"
EXTRA_COUNT=$(echo "$EXTRA_FILES" | tr ' ' '\n' | grep -c '[^[:space:]]' || echo 0)
echo "  發現 $EXTRA_COUNT 個相關檔案"
echo "$EXTRA_FILES" | tr ' ' '\n' | grep '[^[:space:]]' | sed 's/^/    /' || true

# 合併目標檔案（去重）
ALL_TARGET_FILES="$TARGET_FILES"
for f in $EXTRA_FILES; do
  [[ -f "$f" ]] && ALL_TARGET_FILES="$ALL_TARGET_FILES $f"
done

# ==============================================================================
# Step 0.5: Feathers 規則掃描（可選）
# ==============================================================================

FEATHERS_SCAN_FILE="$RUN_DIR/feathers-scan.txt"

if [ "$SKIP_FEATHERS" = "false" ]; then
  echo "[Step 0.5] Feathers 規則掃描..."

  FEATHERS_RULES_DIR="$AUDIT_DIR/rules/feathers"
  FEATHERS_HIT_COUNT=0

  if [ -d "$FEATHERS_RULES_DIR" ]; then
    echo "# Feathers 規則掃描結果" > "$FEATHERS_SCAN_FILE"
    echo "# 掃描時間: $(TZ=Asia/Taipei date)" >> "$FEATHERS_SCAN_FILE"
    echo "" >> "$FEATHERS_SCAN_FILE"

    # 遍歷每個規則目錄，執行掃描
    for rule_dir in "$FEATHERS_RULES_DIR"/*/; do
      rule_name=$(basename "$rule_dir")
      # 若規則目錄下有可執行的掃描腳本，則執行
      if [ -x "$rule_dir/scan.sh" ]; then
        echo "  執行規則: $rule_name"
        echo "## $rule_name" >> "$FEATHERS_SCAN_FILE"
        if bash "$rule_dir/scan.sh" $ALL_TARGET_FILES >> "$FEATHERS_SCAN_FILE" 2>&1; then
          FEATHERS_HIT_COUNT=$((FEATHERS_HIT_COUNT + 1))
        fi
        echo "" >> "$FEATHERS_SCAN_FILE"
      elif [ -f "$rule_dir/rule.yaml" ]; then
        # 使用 rule.yaml 中的 pattern 進行 grep 掃描
        echo "  規則（YAML）: $rule_name"
        echo "## $rule_name" >> "$FEATHERS_SCAN_FILE"
        PATTERNS=$(grep "pattern:" "$rule_dir/rule.yaml" | sed "s/.*pattern:[[:space:]]*['\"]\\(.*\\)['\"].*/\\1/" | sed 's/\$[A-Z_]*/.*/g')
        for pat in $PATTERNS; do
          for tf in $ALL_TARGET_FILES; do
            rg "$pat" "$tf" 2>/dev/null >> "$FEATHERS_SCAN_FILE" || true
          done
        done
        echo "" >> "$FEATHERS_SCAN_FILE"
      fi
    done

    FEATHERS_LINE_COUNT=$(wc -l < "$FEATHERS_SCAN_FILE")
    echo "  Feathers 規則掃描完成: $FEATHERS_HIT_COUNT 個命中"
    echo "  完成: $FEATHERS_LINE_COUNT 行輸出寫入 feathers-scan.txt"
  else
    echo "  WARN: Feathers 規則目錄不存在: $FEATHERS_RULES_DIR"
    echo "# Feathers 規則目錄不存在" > "$FEATHERS_SCAN_FILE"
  fi
else
  echo "[Step 0.5] SKIP: Feathers 規則掃描（--skip-feathers）"
  echo "# Feathers scan skipped" > "$FEATHERS_SCAN_FILE"
fi

# ==============================================================================
# Step 1: Gemini 盲掃
# ==============================================================================

echo "[Step 1] Gemini 盲掃..."

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

{ cat "$PROMPTS/gemini-blind-scan.md" | sed "s/{language}/${LANGUAGE}/g"; echo "$GEMINI_INTENT_HINT"; echo "$GEMINI_EXTRA_HINT"; cat $TARGET_FILES; } \
  | gemini -m gemini-2.5-pro -p - --sandbox false \
  > "$RUN_DIR/gemini-findings.md"

GEMINI_LINES=$(wc -l < "$RUN_DIR/gemini-findings.md")
if [ "$GEMINI_LINES" -le 30 ]; then
  echo "ABORT: Gemini 輸出過短（$GEMINI_LINES 行，需 > 30）。"
  exit 1
fi
echo "  PASS: $GEMINI_LINES 行"

# ==============================================================================
# Step 1.5: 依賴圖譜分析（Feathers 第 3 步「打破依賴」）
# ==============================================================================

echo "[Step 1.5] 依賴圖譜分析..."

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
    echo "  Seam 識別已啟用（pinch_point_threshold=$PINCH_POINT_THRESHOLD）"

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

    env -u CLAUDECODE claude \
      -p "$DEP_PROMPT" \
      --permission-mode bypassPermissions \
      --output-format text \
      > "$DEP_ANALYSIS_FILE"

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

# ==============================================================================
# Step 2: Claude 結構化審計
# ==============================================================================

echo "[Step 2] Claude 結構化審計..."

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

# 附加重構意圖
INTENT_CONTEXT=""
[ -n "$REFACTORING_INTENT" ] && INTENT_CONTEXT="
## Refactoring Intent
$REFACTORING_INTENT
"

env -u CLAUDECODE claude \
  -p "${AUDIT_PROMPT}${INTENT_CONTEXT}${FEATHERS_CONTEXT}${DEP_CONTEXT}

$(cat $ALL_TARGET_FILES)" \
  --permission-mode bypassPermissions \
  --output-format text \
  > "$RUN_DIR/claude-artifacts/all-artifacts.md"

# 品質門檻：Unclassified 必須為 0
if ! grep -q "Unclassified:.*0" "$RUN_DIR/claude-artifacts/all-artifacts.md"; then
  echo "ABORT: Artifact 4 顯示有未分類的行。品質門檻要求 Unclassified: 0。"
  echo "  檢查: $RUN_DIR/claude-artifacts/all-artifacts.md"
  exit 1
fi
echo "  PASS: Unclassified: 0 確認"

# ── Step 2.5: 結構完整性軟門檻 ──
echo "[Step 2.5] 結構完整性檢查..."
for prefix in N S L D P; do
  COUNT=$(grep -c "^${prefix}-[0-9]\{3\}" "$RUN_DIR/claude-artifacts/all-artifacts.md" 2>/dev/null || echo 0)
  echo "  ${prefix}-contracts: $COUNT"
done
echo "  （軟門檻 -- 管線繼續執行）"

# ==============================================================================
# Step 3: Codex 對抗性評論
# ==============================================================================

echo "[Step 3] Codex 對抗性評論..."

codex exec \
  -o "$RUN_DIR/codex-review.md" \
  "$(cat "$PROMPTS/codex-adversary.md"; echo; cat "$RUN_DIR/claude-artifacts/all-artifacts.md"; echo; cat "$RUN_DIR/gemini-findings.md")"

# 品質門檻：CONFIRM ratio <= 70%
CONFIRM_RATIO=$(grep "CONFIRM_RATIO:" "$RUN_DIR/codex-review.md" \
  | grep -oE '[0-9]+' | tail -1)

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

# ==============================================================================
# Step 4: Claude 合併 + Pinch Point 標記
# ==============================================================================

echo "[Step 4] Claude 合併 + Pinch Point 標記..."
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

env -u CLAUDECODE claude \
  -p "$(cat "$PROMPTS/claude-applier.md")${APPLIER_EXTRA}

$(cat "$RUN_DIR/claude-artifacts/all-artifacts.md")

$(cat "$RUN_DIR/codex-review.md")" \
  --permission-mode bypassPermissions \
  --output-format text \
  > "$RUN_DIR/apply.log"

# 驗證產出檔案
if [ ! -f "$OUTPUT/final-contracts.md" ]; then
  echo "ABORT: Applier 未產出 final-contracts.md"
  exit 1
fi
if [ ! -f "$PHASE_B/verify-contracts-${MODULE_NAME}.sh" ]; then
  echo "ABORT: Applier 未產出 verify-contracts-${MODULE_NAME}.sh"
  exit 1
fi
echo "  PASS: final-contracts.md 和驗證腳本已產出"

# ── 歸檔產出到執行目錄 ──
cp "$OUTPUT/final-contracts.md" "$RUN_DIR/final-contracts.md"
cp "$PHASE_B/verify-contracts-${MODULE_NAME}.sh" "$RUN_DIR/verify-contracts-${MODULE_NAME}.sh"
if compgen -G "$PHASE_B/rules/*.yml" > /dev/null 2>&1; then
  cp "$PHASE_B/rules/"*.yml "$RUN_DIR/"
fi

# ==============================================================================
# Step 5: 自我驗證
# ==============================================================================

echo "[Step 5] 自我驗證（Phase B 對當前原始碼）..."
chmod +x "$PHASE_B/verify-contracts-${MODULE_NAME}.sh"
if ! bash "$PHASE_B/run-ci.sh"; then
  echo "ABORT: Phase B 自我檢查失敗。Applier 產出有問題。"
  exit 1
fi
echo "  PASS: Phase B 自我檢查 100%"

# ==============================================================================
# 完成
# ==============================================================================

# 更新 latest 符號連結
ln -sfn "runs/$RUN_ID" "$OUTPUT/latest"

echo ""
echo "=== Phase A 完成 ==="
echo "Run ID:         $RUN_ID"
echo "Run dir:        $RUN_DIR"
echo "Latest:         $OUTPUT/latest -> runs/$RUN_ID"
echo "最終合約:       $OUTPUT/final-contracts.md"
echo "CI 腳本:        $PHASE_B/verify-contracts-${MODULE_NAME}.sh"
echo "ast-grep 規則:  $PHASE_B/rules/"
echo "依賴分析:       $RUN_DIR/dependency-graph.json"
echo "管線設定:       $RUN_DIR/pipeline-config.log"
