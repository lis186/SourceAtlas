# Context 優化與 atlas.flow 分層架構重構

**日期**: 2026-01-01
**版本**: v2.11.0
**類型**: Optimization / Refactor

---

## 背景

隨著 SourceAtlas 功能增長，Claude Code 的 context 使用量逐漸成為瓶頸：

1. **Memory 檔案過大** - 12.9k tokens，佔用大量 context
2. **atlas.flow 單體架構** - 2708 行，每次載入完整內容
3. **累積的 dead code** - 未使用的腳本造成維護負擔

## 優化成果

### 1. Memory 檔案精簡 (93% 減少)

| 項目 | 優化前 | 優化後 | 減少 |
|------|--------|--------|------|
| CLAUDE.md | 12,900 tokens | 839 tokens | 93.5% |

**方法**：
- 移除冗餘內容，保留核心指引
- 將詳細說明移至專門 skill 檔案
- 新建 3 個獨立 skill：`multi-approach.md`, `dev-notes-guide.md`, `pre-release.md`

### 2. atlas.flow 分層架構 (88% 減少)

| 項目 | 優化前 | 優化後 | 減少 |
|------|--------|--------|------|
| atlas.flow.md | 2,708 行 | 239 行 | 91.2% |
| 首次載入 | 完整內容 | 核心 + dispatch | 88% |

**分層設計**：

```
Tier 1 (內建)     - 5 個常用模式，直接內嵌
Tier 2 (外部載入) - 6 個中等頻率模式
Tier 3 (外部載入) - 3 個特化模式
```

**外部模式檔案** (`scripts/atlas/flow-modes/`):
- `mode-04-state-machine.md`
- `mode-05-flow-comparison.md`
- `mode-06-log-discovery.md`
- `mode-07-feature-toggle.md`
- `mode-09-transaction.md`
- `mode-11-cache-flow.md`
- `mode-12-taint-analysis.md` (新)
- `mode-13-dead-code.md` (新)
- `mode-14-concurrency.md` (新)

**Dispatch 機制修復**：
- 問題：原本的 dispatch 表格被當作文件輸出，而非指令執行
- 解法：STEP 0 移至最頂部，改用命令式語法「Then execute this action」
- 加入明確指令：「Load the file NOW... Do NOT continue reading this document」

### 3. Dead Code 清理

**刪除的腳本** (5 個)：

| 腳本 | 原因 |
|------|------|
| `benchmark.sh` | 開發期測試，已不需要 |
| `compare-formats.sh` | 格式比較，已不需要 |
| `detect-project.sh` | 被 enhanced 版本取代 |
| `history.sh` | 未被任何指令調用 |
| `validate-constitution.sh` | 開發期驗證，已不需要 |

**重新命名**：
- `detect-project-enhanced.sh` → `detect-project.sh`

### 4. 保留的核心腳本 (6 個)

| 腳本 | 用途 |
|------|------|
| `ast-grep-search.sh` | AST 搜尋核心 |
| `detect-ai-tools.sh` | AI 工具偵測 |
| `detect-project.sh` | 專案類型偵測 |
| `find-patterns.sh` | 模式分析核心 |
| `scan-entropy.sh` | 熵值掃描 |
| `swift-analyzer.sh` | Swift 分析 |

## 技術細節

### Dispatch 表格語法對比

**修復前** (被當作文件輸出)：
```markdown
| Keywords | Mode |
|----------|------|
| "dead code" | Mode 13: Dead Code |
```

**修復後** (被當作指令執行)：
```markdown
| If arguments contain... | Then execute this action |
|------------------------|--------------------------|
| "dead code" | `Read scripts/atlas/flow-modes/mode-13-dead-code.md` then follow its instructions |
```

### 更新的檔案

| 檔案 | 變更 |
|------|------|
| `.claude/commands/atlas.flow.md` | 重寫為 239 行分層版本 |
| `plugin/commands/flow.md` | 同步更新 |
| `plugin/commands/overview.md` | 更新 detect-project 引用 |
| `.claude/commands/atlas.overview.md` | 更新 detect-project 引用 |

## 驗證測試

執行 `/atlas.flow "dead code in scripts/atlas"` 測試：

1. ✅ 新版 239 行 skill 正確載入
2. ✅ STEP 0 偵測到 "dead code" 關鍵字
3. ✅ 顯示載入外部檔案的指令
4. ✅ mode-13-dead-code.md 成功載入並執行
5. ✅ 產出完整 dead code 分析報告

## 後續建議

1. **測試其他 Tier 2-3 模式** - concurrency, taint analysis 等
2. **監控 context 使用** - 確認優化效果持續
3. **考慮更多 skill 抽取** - 若 CLAUDE.md 再次膨脹

---

## 版本歷史

| 版本 | 日期 | 變更 |
|------|------|------|
| v2.11.0 | 2026-01-02 | Context 優化、分層架構、dead code 清理 |
