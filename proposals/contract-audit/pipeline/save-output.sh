#!/usr/bin/env bash
# ==============================================================================
# save-output.sh
# 將合約審計管線輸出存儲為 .sourceatlas/audit/{module}.yaml
# ==============================================================================
#
# 用法：
#   ./save-output.sh <module_name> <input_file>
#
# 參數：
#   module_name  模組名稱（例如 NYHTTPSClient）
#   input_file   管線產出的 YAML 檔案路徑
#
# 行為：
#   1. 建立 .sourceatlas/audit/ 目錄（如果不存在）
#   2. 如果已存在舊結果，備份到 {module}.yaml.bak
#   3. 複製管線輸出到目標路徑
#   4. 輸出存儲路徑供使用者確認
#
# 範例：
#   ./save-output.sh NYHTTPSClient /tmp/audit-result.yaml
# ==============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# 參數檢查
# --------------------------------------------------------------------------
if [ $# -lt 2 ]; then
  echo "錯誤：參數不足" >&2
  echo "用法：$0 <module_name> <input_file>" >&2
  exit 1
fi

MODULE_NAME="$1"
INPUT_FILE="$2"

# 驗證模組名稱（只允許英數字、底線、連字號）
if [[ ! "$MODULE_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "錯誤：模組名稱只允許英數字、底線和連字號：$MODULE_NAME" >&2
  exit 1
fi

# 驗證輸入檔案存在
if [ ! -f "$INPUT_FILE" ]; then
  echo "錯誤：輸入檔案不存在：$INPUT_FILE" >&2
  exit 1
fi

# 驗證輸入檔案為有效的 YAML（基本檢查：非空且含有 metadata 欄位）
if ! grep -q "^metadata:" "$INPUT_FILE" 2>/dev/null; then
  echo "錯誤：輸入檔案缺少 metadata 區塊，可能不是有效的審計輸出：$INPUT_FILE" >&2
  exit 1
fi

# --------------------------------------------------------------------------
# 尋找專案根目錄（向上尋找 .sourceatlas/ 或 CLAUDE.md）
# --------------------------------------------------------------------------
find_project_root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.sourceatlas" ] || [ -f "$dir/CLAUDE.md" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  # 找不到時使用當前目錄
  echo "$PWD"
}

PROJECT_ROOT="$(find_project_root)"
AUDIT_DIR="$PROJECT_ROOT/.sourceatlas/audit"
OUTPUT_FILE="$AUDIT_DIR/${MODULE_NAME}.yaml"

# --------------------------------------------------------------------------
# 建立目錄
# --------------------------------------------------------------------------
if [ ! -d "$AUDIT_DIR" ]; then
  mkdir -p "$AUDIT_DIR"
  echo "已建立目錄：$AUDIT_DIR"
fi

# --------------------------------------------------------------------------
# 備份舊結果
# --------------------------------------------------------------------------
if [ -f "$OUTPUT_FILE" ]; then
  cp "$OUTPUT_FILE" "${OUTPUT_FILE}.bak"
  echo "已備份舊結果：${OUTPUT_FILE}.bak"
fi

# --------------------------------------------------------------------------
# 存儲輸出
# --------------------------------------------------------------------------
cp "$INPUT_FILE" "$OUTPUT_FILE"

# --------------------------------------------------------------------------
# 確認訊息
# --------------------------------------------------------------------------
echo ""
echo "合約審計結果已存儲："
echo "  路徑：$OUTPUT_FILE"
echo "  模組：$MODULE_NAME"
echo ""

# 顯示摘要資訊（如果 summary 段落存在）
if grep -q "^summary:" "$OUTPUT_FILE" 2>/dev/null; then
  TOTAL=$(grep "total_contracts:" "$OUTPUT_FILE" | head -1 | sed 's/.*: *//')
  PINCH=$(grep "pinch_points_count:" "$OUTPUT_FILE" | head -1 | sed 's/.*: *//')
  COMPLETENESS=$(grep "completeness:" "$OUTPUT_FILE" | head -1 | sed 's/.*: *"//' | sed 's/".*//')
  if [ -n "$TOTAL" ]; then
    echo "  合約總數：$TOTAL"
  fi
  if [ -n "$PINCH" ]; then
    echo "  Pinch Points：$PINCH"
  fi
  if [ -n "$COMPLETENESS" ]; then
    echo "  完整性：$COMPLETENESS"
  fi
  echo ""
fi
