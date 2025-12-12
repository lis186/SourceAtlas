# Proposal: 探索結果持久化

**Status**: 🟡 Phase 2 設計中
**Version**: 1.2
**Author**: Claude & Justin
**Created**: 2025-12-12
**Updated**: 2025-12-12
**Completed**: 2025-12-12

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

## Phase 2：快取整合（設計中）

### 問題：存了但沒用到

Phase 1 完成後，使用者模擬測試發現：

> 「存了就要能用」— 中階工程師
>
> 「我怎麼知道什麼時候該重新分析？」— 初學者
>
> 「不要太囉嗦，要能跳過」— 資深工程師

### 使用者回饋整理

| 面向 | 初學者 | 中階 | 資深 |
|------|--------|------|------|
| **自動檢查快取** | ✅ 很有幫助 | ✅ 應該要有 | ⚠️ 可以，但要能跳過 |
| **詢問確認** | ✅ 需要引導 | ✅ OK | ❌ 太囉嗦，要 `--force` |
| **顯示快取清單** | 🤔 不知道要看 | ✅ 想要 | ✅ 想要 |
| **差異比較** | 🤔 看不懂 | ✅ 有價值 | ✅ 核心功能 |
| **自動過期** | ✅ 需要建議 | ✅ 7天合理 | ⚠️ 讓我自己決定 |

---

### Phase 2a：基礎快取整合

**目標**：讓 Claude 知道快取存在，提供選擇

#### 1. 新增 `--force` 參數

跳過快取檢查，直接重新分析：

```bash
/atlas.overview --force        # 忽略快取，重新分析
/atlas.pattern "api" --force   # 忽略快取，重新分析
```

#### 2. 新增 `/atlas.list` 命令

列出所有已儲存的分析：

```bash
/atlas.list

輸出：
📁 .sourceatlas/ 內容：

| 類型 | 檔案 | 儲存時間 | 年齡 |
|------|------|----------|------|
| overview | overview.yaml | 2025-12-10 | 2 天前 |
| pattern | patterns/repository.md | 2025-12-09 | 3 天前 |
| pattern | patterns/api-endpoint.md | 2025-12-09 | 3 天前 |
| history | history.md | 2025-12-08 | 4 天前 |

💡 使用 `/atlas.clear [target]` 清空特定類型
```

#### 3. 執行時檢查快取

修改各命令 prompt，加入快取檢查邏輯：

```markdown
## Cache Check (執行分析前)

1. 檢查對應的快取檔案是否存在
2. 如果存在，顯示：
   ```
   📁 發現既有分析：.sourceatlas/overview.yaml（3 天前）

   選擇：
   1. 查看既有分析（推薦）
   2. 重新分析（覆蓋既有）
   ```
3. 如果使用者選 1，直接讀取並顯示快取內容
4. 如果使用者選 2，執行分析並覆蓋
5. 如果有 `--force`，跳過此檢查
```

---

### Phase 2b：進階功能（未來）

#### 4. 過期建議

根據分析類型建議不同過期時間：

| 類型 | 建議過期 | 原因 |
|------|---------|------|
| overview | 7 天 | 專案結構可能變動 |
| pattern | 30 天 | 設計模式較穩定 |
| history | 7 天 | Git 持續變動 |
| flow | 14 天 | 流程較穩定 |
| impact | 7 天 | 依賴可能變動 |
| deps | 30 天 | 依賴版本較穩定 |

#### 5. 差異比較

重新分析後，與舊版比較：

```
與舊分析相比：
- 新增 2 個假設（發現新的 API 模組）
- 移除 1 個假設（舊的 legacy 模組已刪除）
- 信心度變化：JWT auth 0.75 → 0.85

要覆蓋舊的 overview.yaml 嗎？
```

---

### 不做的功能

| 功能 | 原因 |
|------|------|
| 自動讀取快取作為 context | 太複雜，可能造成混亂 |
| 強制過期刪除 | 讓使用者決定 |
| 快取版本控制 | 過度工程化 |

---

### Phase 2 實作計畫

| 階段 | 內容 | 工作量 |
|------|------|--------|
| 2a-1 | `--force` 參數（6 個命令） | 30min |
| 2a-2 | `/atlas.list` 命令 | 30min |
| 2a-3 | 快取檢查邏輯（6 個命令） | 1h |
| 2a | **小計** | **2h** |
| 2b | 過期建議 + 差異比較 | 2h |
| | **總計** | **~4h** |

---

### Phase 2 驗收標準

- [ ] `--force` 可跳過快取檢查
- [ ] `/atlas.list` 可列出所有快取
- [ ] 執行命令時會檢查並提示快取
- [ ] 使用者可選擇重用或重新分析

---

## 相關文件

- [ideas/claude-code-plugins-learnings.md](../../ideas/claude-code-plugins-learnings.md) - 原始探索
