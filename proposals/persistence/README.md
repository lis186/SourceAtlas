# Proposal: 探索結果持久化

**Status**: 🟡 Phase 2 設計中
**Version**: 1.3
**Author**: Claude & Justin
**Created**: 2025-12-12
**Updated**: 2025-12-12
**Phase 1 Completed**: 2025-12-12

---

## 問題陳述

### 痛點

1. **分析結果隨 session 消失**
   - 早上用 `/atlas.overview` 了解專案
   - 下午開新 session，分析結果不見了
   - 每次都要重跑，浪費時間和 tokens

2. **新成員無法受益**
   - 資深成員做過的分析，新人看不到
   - 知識無法累積

### ~~事後才想儲存~~ （不解決）

原本考慮 `/atlas.save` 解決「忘了加 --save」的問題，但：
- 實作複雜（需要暫存機制）
- 價值有限（重跑只要 2-3 分鐘）
- **決策**：不做，保持簡單

---

## 解決方案

### 兩個功能

| 功能 | 用途 |
|------|------|
| `--save` | 執行時儲存結果 |
| `/atlas.clear` | 清空已儲存的分析 |

---

## 詳細設計

### 1. 統一 `--save` 參數

**所有命令支援**：
```bash
/atlas.overview --save
/atlas.pattern "repository" --save
/atlas.flow "checkout" --save
/atlas.history --save
/atlas.impact "User model" --save
/atlas.deps "react" --save
```

**儲存位置**：
```
.sourceatlas/
├── overview.yaml           # /atlas.overview --save
├── patterns/
│   └── {pattern-name}.md   # /atlas.pattern "X" --save
├── flows/
│   └── {flow-name}.md      # /atlas.flow "X" --save
├── history.md              # /atlas.history --save
├── impact/
│   └── {target-name}.md    # /atlas.impact "X" --save
└── deps/
    └── {library-name}.md   # /atlas.deps "X" --save
```

**檔名轉換規則**：
- 空格 → `-`
- 特殊字元移除
- 全小寫
- 範例：`"User model"` → `user-model.md`

**儲存格式**：
- `/atlas.overview`：YAML（維持現有格式）
- 其他命令：純文字 Markdown（終端顏色/格式化會轉為純文字）

---

### 2. `/atlas.clear` 命令

**用法**：
```bash
/atlas.clear              # 清空全部
/atlas.clear patterns     # 清空 patterns/
```

**行為**：對話式確認，不需要 `y/N` prompt

```
使用者：/atlas.clear

Claude：找到以下已儲存的分析：
- overview.yaml
- patterns/ (3 個檔案)
- history.md

確定要全部刪除嗎？

使用者：好

Claude：
✅ 已清空 .sourceatlas/
```

**可清空的目標**：
- `overview` - 專案概覽
- `patterns` - pattern 分析
- `flows` - 流程分析
- `history` - 歷史分析
- `impact` - 影響分析
- `deps` - 依賴分析
- （無參數）- 全部

---

## 實作方式

### 關鍵理解

`.claude/commands/*.md` 是 **prompt 模板**，不是程式碼：
- 沒有「解析參數」，是 LLM 理解自然語言
- 「儲存到檔案」是 LLM 用 Write tool 完成
- 實作 = 在 prompt 末尾加入儲存指示

---

### Prompt 修改範例

#### `/atlas.pattern` 加入 `--save`

**修改 1**：更新 `argument-hint`

```yaml
argument-hint: [pattern type, e.g., "api endpoint", "background job"] [--save]
```

**修改 2**：在檔案末尾加入 Save Mode 區段

```markdown
---

## Save Mode (--save)

If `--save` is in arguments:

1. Parse pattern name from arguments (remove `--save`):
   - `"repository" --save` → pattern name is `repository`
   - Convert to filename: spaces → `-`, lowercase, remove special chars

2. Create directory if needed:
```bash
mkdir -p .sourceatlas/patterns
```

3. After generating the analysis, save to `.sourceatlas/patterns/{name}.md`

4. Confirm at the end:
```
💾 已儲存至 .sourceatlas/patterns/{name}.md
```
```

---

#### `/atlas.clear` 完整 prompt

**新檔案**：`.claude/commands/atlas.clear.md`

```markdown
---
description: Clear saved SourceAtlas analysis results
model: haiku
allowed-tools: Bash, Read
argument-hint: (optional) [target: overview|patterns|flows|history|impact|deps]
---

# SourceAtlas: Clear Saved Results

## Context

**Target**: $ARGUMENTS (default: all)

## Your Task

Help user clear saved analysis results from `.sourceatlas/` directory.

### Step 1: Check what exists

```bash
ls -la .sourceatlas/ 2>/dev/null || echo "No .sourceatlas/ directory found"
```

### Step 2: Report findings

List what will be deleted based on target:
- If no argument or "all": list everything
- If specific target (e.g., "patterns"): list only that

Example output:
```
找到以下已儲存的分析：
- overview.yaml (2025-12-12)
- patterns/ (3 個檔案)
- history.md (2025-12-11)

確定要刪除嗎？
```

### Step 3: Wait for confirmation

Ask user to confirm. Do NOT proceed without explicit confirmation.

### Step 4: Delete if confirmed

Based on target:

```bash
# All
rm -rf .sourceatlas/*

# Specific target
rm -rf .sourceatlas/patterns/   # for "patterns"
rm -f .sourceatlas/overview.yaml  # for "overview"
rm -f .sourceatlas/history.md     # for "history"
rm -rf .sourceatlas/flows/        # for "flows"
rm -rf .sourceatlas/impact/       # for "impact"
rm -rf .sourceatlas/deps/         # for "deps"
```

### Step 5: Confirm deletion

```
✅ 已清空
```

---

## If nothing to clear

```
.sourceatlas/ 目錄不存在或已經是空的
```
```

---

## 現有支援狀態

| 命令 | `--save` 狀態 | 儲存格式 |
|------|---------------|----------|
| `/atlas.overview` | ✅ 已有 | YAML |
| `/atlas.pattern` | ✅ 已完成 | Markdown |
| `/atlas.flow` | ✅ 已完成 | Markdown |
| `/atlas.history` | ✅ 已完成 | Markdown |
| `/atlas.impact` | ✅ 已完成 | Markdown |
| `/atlas.deps` | ✅ 已完成 | Markdown |
| `/atlas.clear` | ✅ 已建立 | - |

---

## 實作計畫

### Phase 1：各命令加入 `--save`（1h）

每個命令修改內容：
1. `argument-hint` 加入 `[--save]`
2. 末尾加入 `## Save Mode (--save)` 區段

順序：
1. `/atlas.pattern`
2. `/atlas.flow`
3. `/atlas.history`
4. `/atlas.impact`
5. `/atlas.deps`

### Phase 2：建立 `/atlas.clear`（20min）

建立 `.claude/commands/atlas.clear.md`

### Phase 3：文檔更新（20min）

- `CLAUDE.md`：更新命令說明
- `README.md`：新增持久化說明

---

## 工作量估算

| 項目 | 工作量 |
|------|--------|
| Phase 1：5 個命令加 `--save` | 1h |
| Phase 2：`/atlas.clear` | 20min |
| Phase 3：文檔更新 | 20min |
| **總計** | **~1.5-2h** |

---

## 設計決策記錄

### ~~`/atlas.save`~~ - 已刪除

**原因**：
- 需要暫存機制（每次執行自動寫入 `.cache/last.json`）
- 實作複雜度與價值不成比例
- 忘了加 `--save` 就重跑，只要 2-3 分鐘

### `/atlas.clear` 簡化

**原因**：
- 不需要 `--force`（對話式確認更自然）
- 不需要 `--dry-run`（先列出再確認就是 dry-run）
- 不需要互動選單（直接對話）

---

## 驗收標準（Phase 1）

- [x] 6 個命令支援 `--save`
- [x] `/atlas.clear` 可清空 `.sourceatlas/`
- [x] 文檔已更新
- [x] QA 測試通過（9.7/10）

---

## Phase 2：快取整合

### 設計審查會議結論（2025-12-12）

**參與者**：架構師、Claude Code 資深工程師、實作工程師、資深 PO

#### 核心問題

Phase 1 的 `--save` 只是「匯出」，存了但沒用到。使用者的真正需求是：

> **「不要讓我浪費時間重複做一樣的事」**

#### 方案比較

| 方案 | 描述 | 結論 |
|------|------|------|
| **詢問式** | 發現快取後詢問「要重用嗎？」 | ❌ UX 差，打斷流程 |
| **提示式** | 加「💡 執行 /atlas.list 查看」 | ❌ 時機太晚，分析已開始 |
| **告知式** | 有快取直接用，顯示來源 | ✅ 採用 |

#### 關鍵決策

1. **預設行為**：有快取就直接用，不詢問
2. **跳過方式**：`--force` 強制重新分析
3. **不做過期**：顯示日期，讓使用者自己判斷

---

### Phase 2a：告知式快取

#### 設計原則

- **Opt-out** 而非 **Opt-in**：預設用快取，要重跑才加參數
- **不打斷流程**：不詢問，直接執行
- **透明度**：清楚顯示來源和日期

#### 行為矩陣

| 快取存在 | `--force` | `--save` | 行為 |
|---------|-----------|----------|------|
| ❌ | - | ❌ | 正常分析 |
| ❌ | - | ✅ | 分析 + 儲存 |
| ✅ | ❌ | - | **直接載入快取**（顯示來源） |
| ✅ | ✅ | ❌ | 重新分析（不覆蓋舊快取） |
| ✅ | ✅ | ✅ | 重新分析 + 覆蓋 |

#### 功能 1：告知式快取檢查

**各命令加入快取檢查邏輯**：

```markdown
## Cache Check（分析前，最高優先）

**如果沒有 `--force`**：

1. 根據參數計算快取檔案路徑：
   - `/atlas.overview` → `.sourceatlas/overview.yaml`
   - `/atlas.pattern "api"` → `.sourceatlas/patterns/api.md`
   - `/atlas.history` → `.sourceatlas/history.md`
   - 以此類推...

2. 用 Bash 檢查檔案是否存在：
   ```bash
   ls -la .sourceatlas/overview.yaml 2>/dev/null
   ```

3. 如果存在：
   - 讀取檔案修改時間（從 ls 輸出）
   - 計算距今天數
   - 用 Read tool 讀取檔案內容
   - 輸出：
     ```
     📁 載入快取：.sourceatlas/overview.yaml（3 天前）
     💡 重新分析請加 --force

     ---
     [快取內容]
     ```
   - **結束，不執行分析**

4. 如果不存在：正常執行分析

**如果有 `--force`**：跳過快取檢查，直接分析
```

#### 功能 2：`--force` 參數

**用途**：強制重新分析，忽略快取

**各命令修改**：

1. 更新 `argument-hint`：
   ```yaml
   argument-hint: [pattern type] [--save] [--force]
   ```

2. 在 Cache Check 區段處理 `--force`

#### 功能 3：`/atlas.list` 命令

**用途**：列出所有已儲存的分析

**新檔案**：`.claude/commands/atlas.list.md`

```markdown
---
description: List saved SourceAtlas analysis results
model: haiku
allowed-tools: Bash
---

# SourceAtlas: List Saved Results

## Your Task

列出 `.sourceatlas/` 目錄中所有已儲存的分析結果。

### Step 1: Check directory exists

```bash
ls -la .sourceatlas/ 2>/dev/null || echo "NOT_FOUND"
```

如果輸出 `NOT_FOUND`：
```
📁 尚無已儲存的分析

使用 `--save` 參數儲存分析結果：
- `/atlas.overview --save`
- `/atlas.pattern "api" --save`
```
結束。

### Step 2: List all files with dates

```bash
find .sourceatlas -type f -exec ls -la {} \; 2>/dev/null
```

### Step 3: Format output

將結果整理成表格：

```
📁 .sourceatlas/ 已儲存的分析：

| 類型 | 檔案 | 大小 | 修改時間 |
|------|------|------|----------|
| overview | overview.yaml | 2.3 KB | 3 天前 |
| pattern | patterns/api.md | 1.5 KB | 5 天前 |
| pattern | patterns/repository.md | 2.1 KB | 5 天前 |
| history | history.md | 4.2 KB | 7 天前 |

💡 提示：
- 重新分析：`/atlas.pattern "api" --force`
- 清空快取：`/atlas.clear`
```
```

---

### 快取檔案路徑對照表

| 命令 | 參數 | 快取路徑 |
|------|------|----------|
| `/atlas.overview` | - | `.sourceatlas/overview.yaml` |
| `/atlas.overview` | `src/api` | `.sourceatlas/overview-src-api.yaml` |
| `/atlas.pattern` | `"api"` | `.sourceatlas/patterns/api.md` |
| `/atlas.pattern` | `"User Service"` | `.sourceatlas/patterns/user-service.md` |
| `/atlas.history` | - | `.sourceatlas/history.md` |
| `/atlas.flow` | `"checkout"` | `.sourceatlas/flows/checkout.md` |
| `/atlas.impact` | `"User model"` | `.sourceatlas/impact/user-model.md` |
| `/atlas.deps` | `"react"` | `.sourceatlas/deps/react.md` |

**檔名正規化規則**：
1. 移除 `--save`、`--force` 參數
2. 空格 → `-`
3. 斜線 `/` → `-`
4. 移除特殊字元 `{}()`
5. 全小寫

---

### 不做的功能

| 功能 | 原因 | 來源 |
|------|------|------|
| 詢問式互動 | UX 差，打斷流程 | 架構師 |
| 過期自動失效 | 太聰明，讓使用者決定 | 架構師 |
| 差異比較 | 複雜度高，Phase 2b 觀察 | 工程師 |
| 快取版本控制 | 過度工程化 | 架構師 |

---

### Phase 2a 實作計畫

| 項目 | 內容 | 工作量 |
|------|------|--------|
| 1 | `/atlas.list` 命令 | 30min |
| 2 | 各命令加入 Cache Check 區段（6 個） | 1.5h |
| 3 | 各命令加入 `--force` 參數（包含在上面） | - |
| 4 | 測試 | 30min |
| | **總計** | **~2.5h** |

---

### Phase 2a 驗收標準

- [ ] `/atlas.list` 可列出所有快取及修改時間
- [ ] 有快取時，直接載入並顯示來源
- [ ] `--force` 可跳過快取，強制重新分析
- [ ] `--force --save` 可重新分析並覆蓋快取

---

### 成功指標（Linda 建議）

| 指標 | 定義 | 目標 |
|------|------|------|
| 快取命中率 | 載入快取次數 / 總執行次數 | > 30% |
| `--force` 使用率 | 使用 --force 次數 / 快取存在時的執行次數 | < 50% |

**判讀**：
- 如果 `--force` 使用率 > 50%，代表快取沒用，需重新評估
- 如果快取命中率 < 10%，代表使用者不常用 `--save`

---

### Phase 2b：進階功能（觀察後決定）

以下功能**暫不實作**，根據 Phase 2a 使用情況決定：

| 功能 | 觸發條件 |
|------|---------|
| 過期建議 | 使用者抱怨「用了舊的分析」 |
| 差異比較 | 使用者要求「看看有什麼不同」 |
| 自動清理 | 快取檔案累積太多 |

---

## 相關文件

- [ideas/claude-code-plugins-learnings.md](../../ideas/claude-code-plugins-learnings.md) - 原始探索
