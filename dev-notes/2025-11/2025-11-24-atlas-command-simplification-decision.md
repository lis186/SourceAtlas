# SourceAtlas 命令簡化決策記錄

**日期**: 2025-11-24
**類型**: 架構決策 (ADR)
**狀態**: ✅ 已完成
**影響範圍**: PRD.md, CLAUDE.md, proposals/

---

## 📋 決策摘要

今日完成三個重要決策和實作：

1. **版本號統一** - 區分產品版本與文檔版本
2. **移除 `/atlas` 命令** - 簡化命令集，避免混淆
3. **code-maat 提案簡化** - 從 3 個命令簡化為 2 個

---

## 1️⃣ 版本號統一

### 問題

多個文檔使用不同版本號系統，造成混淆：
- PRD.md: v2.5.3
- code-maat proposal: v2.0 / v2.1 不一致
- 缺乏統一的版本號語意

### 決策

**建立兩種版本號系統**：

| 版本類型 | 格式 | 用途 | 範例 |
|---------|------|------|------|
| **產品版本** | v{major}.{minor}.{patch} | SourceAtlas 產品開發階段 | v2.5.3 |
| **文檔版本** | v{major}.{minor} | 個別提案的修訂版本 | v2.1 |

**產品版本**（SourceAtlas）:
- v1.0 - 方法論驗證完成
- v2.5 - Commands 架構（當前）
- v2.6 - 時序分析 + Monitor（未來）

**文檔版本**（proposals/）:
- 追蹤個別提案的設計變更
- 獨立於產品版本
- 範例：code-maat 提案從 v1.0 → v2.0 → v2.1

### 實作

**更新的文檔**：
1. `SOURCEATLAS_CODEMAAT_INTEGRATION.md`
   ```markdown
   **文檔版本**: 2.1 (2025-11-24)
   **目標產品版本**: SourceAtlas v2.6
   ```

2. `UPDATES_SUMMARY.md`
   - 新增「📌 版本號說明」章節
   - 清楚解釋兩種版本號

3. `CLAUDE.md`
   - 新增版本號說明
   - 區分產品版本和提案文檔版本

### 影響

✅ 版本號語意清晰
✅ 避免文檔版本與產品版本混淆
✅ 未來新提案可遵循相同規範

---

## 2️⃣ 移除 `/atlas` 三階段分析命令

### 問題分析

`/atlas` 命令存在以下問題：

#### A. 使用場景不清晰

檢視 PRD 的 5 個真實場景：

| 場景 | 需求 | 使用命令 | 需要完整三階段？ |
|------|------|---------|----------------|
| 快速理解新專案 | 70-80% 理解 | `/atlas.overview` | ❌ 否 |
| Bug 修復 | 找到問題點 | `/atlas.find` | ❌ 否 |
| 學習模式 | 遵循現有架構 | `/atlas.pattern` | ❌ 否 |
| 影響範圍 | 評估變更影響 | `/atlas.impact` | ❌ 否 |

**結論**：所有日常開發場景都不需要完整三階段分析（45-75 分鐘）

#### B. 與 `/atlas.overview` 功能重疊

```bash
# 用戶困惑點
/atlas.overview  # Stage 0 專案指紋（10-15分鐘）
/atlas          # Stage 0 + 1 + 2（45-75分鐘）

# 疑問：
- 我應該用哪個？
- /atlas 包含 overview 嗎？
- 如果我已經用了 /atlas，還需要 /atlas.overview 嗎？
```

#### C. 產品定位不符

PRD 核心定位：
```
✅ 即時探索（Commands）- 5-15 分鐘快速分析
❌ 批次處理（三階段）- 45-75 分鐘完整分析
```

### 決策

**移除 `/atlas` 命令**，理由：

1. ✅ **真實需求驅動** - 5 個場景都不需要它
2. ✅ **避免混淆** - 清晰的命令職責分工
3. ✅ **符合產品定位** - 專注於即時探索
4. ✅ **保留彈性** - 深度分析改用 `PROMPTS.md`

### 替代方案

**日常開發**（使用 Commands）：
```bash
/atlas.overview  # Stage 0 專案指紋 ⭐⭐⭐⭐⭐
/atlas.pattern   # 學習設計模式 ⭐⭐⭐⭐⭐
/atlas.impact    # 影響範圍分析 ⭐⭐⭐⭐
/atlas.find      # 智慧搜尋 ⭐⭐
/atlas.explain   # 深入解釋 ⭐
```

**深度盡職調查**（罕見場景）：
```bash
# 適用場景：
✅ 評估開源專案是否適合採用
✅ 評估開發者候選人作品（招聘）
✅ 技術盡職調查（投資、收購）
✅ 重大重構前的完整評估

# 執行方式：
使用 PROMPTS.md 手動執行 Stage 0-1-2（45-75 分鐘）
```

### 實作

**PRD.md 更新**（11 處修改）：
- ✅ 移除架構圖中的 `/atlas` 行
- ✅ 移除命令優先級列表中的完整分析部分
- ✅ 新增「完整三階段分析（罕見場景）」說明
- ✅ 移除「範例 3: `/atlas` (完整分析)」整節（38 行）
- ✅ 批量修正命令名稱（加連字號）
- ✅ 更新 Phase 1 清單
- ✅ 更新版本資訊

**CLAUDE.md 更新**：
```markdown
**v2.5 方式**（Commands）：
- `/atlas.overview` ✅ - Stage 0 專案指紋
- `/atlas.pattern` ✅ - 學習設計模式
- `/atlas.impact` 🔵 - 影響範圍分析
- `/atlas.find` 🔵 - 智慧搜尋

**完整三階段分析**（罕見場景）：
針對深度盡職調查，使用 `PROMPTS.md` 手動執行 Stage 0-1-2
```

**PROMPTS.md 驗證**：
- ✅ 完整保留所有三階段分析內容（1,251 行）
- ✅ Stage 0, 1, 2 的 prompts 全部保留

### 影響

**立即效果**：
- ✅ 命令數量：6 → 5（減少 16.7%）
- ✅ 學習成本降低
- ✅ 職責更清晰

**長期效益**：
- ✅ 用戶不會在 overview 和完整分析之間困惑
- ✅ 保持產品「即時探索」的核心定位
- ✅ 深度分析能力通過 PROMPTS.md 完整保留

---

## 3️⃣ code-maat 提案簡化（3→2→1 命令）

### 背景

原 code-maat 提案設計 3 個命令：
- `/atlas.changes` - 變更頻率分析
- `/atlas.coupling` - 耦合度分析
- `/atlas.expert` - 專家查詢

### 問題

1. **命名混淆**：用戶反饋 "atlas-coupling 太不容易懂了"
2. **功能重疊**：發現 `/atlas.changes` 已有 `--coupling` 選項

### 決策（2025-11-24）

**簡化為 2 個命令**：

```bash
/atlas.changes   # 整合完整時序分析（變更頻率 + 耦合度 + 熱點 + 風險）
/atlas.expert    # 專家查詢 + 知識地圖
```

### 進一步簡化（2025-11-30 更新）⭐

經過 9 個模擬開發者角色討論，進一步簡化為 **1 個命令**：

```bash
/atlas.history   # 智慧時序分析（Hotspots + Coupling + Contributors）
```

**關鍵決策**：
1. **目標用戶**：Legacy Codebase 接手者（最高價值場景）
2. **零參數優先**：適合跨 AI 工具移植（Cursor, Copilot, Windsurf）
3. **政治敏感度**：用「Recent Contributors」取代「Ownership %」
4. **命名投票**：`/atlas.history` 獲得 3 票勝出

**v3.0 設計**：
- `/atlas.expert` 反向查詢功能價值較低，已移除
- 所有功能整合到 `/atlas.history` 的智慧輸出

### 實作

**更新的文檔**：
1. `SOURCEATLAS_CODEMAAT_INTEGRATION.md`
   - 移除整個 `/atlas.coupling` 章節（238 行）
   - `/atlas.changes` → `/atlas.history`
   - `/atlas.expert` 移除
   - 文檔版本更新為 v3.0

2. `UPDATES_SUMMARY.md`
   - 新增 v3.0 changelog
   - 記錄設計決策過程

3. `proposals/README.md`
   - 更新命令清單（3→2→1）

4. `PRD.md`
   - 更新 v2.6 規劃章節

### 影響

**提案狀態**：
- 文檔版本：v2.0 → v2.1 → v3.0
- 目標產品版本：v2.6（不變）
- 狀態：🟢 已批准待實作

---

## 📊 今日成果總結

### 更新的文檔（8 個）

| 文檔 | 變更類型 | 行數變化 |
|------|---------|---------|
| PRD.md | 移除 `/atlas`，命令簡化 | ~50 行減少 |
| CLAUDE.md | 執行分析章節更新 | +6 行 |
| PROMPTS.md | 驗證保留完整 | 0（保持 1,251 行）|
| SOURCEATLAS_CODEMAAT_INTEGRATION.md | 移除 coupling，版本更新 | -238 行 |
| UPDATES_SUMMARY.md | 新增 v2.1 changelog | +30 行 |
| proposals/README.md | 命令簡化說明 | ~10 行修改 |

### 決策影響矩陣

| 決策 | 用戶體驗 | 開發效率 | 長期維護 |
|------|---------|---------|---------|
| 版本號統一 | ➕ 清晰 | ➕ 減少混淆 | ➕➕ 可擴展 |
| 移除 `/atlas` | ➕➕ 避免困惑 | ➕ 減少開發 | ➕➕ 職責清晰 |
| 提案簡化 | ➕➕ 學習成本低 | ➕ 減少實作 | ➕ 易維護 |

### 關鍵學習

1. **使用場景倒推設計** ⭐
   - 從 5 個真實場景分析發現 `/atlas` 無使用需求
   - 設計功能前先確認真實使用場景

2. **命令命名重要性**
   - "coupling" 技術性太強，不易理解
   - 發現功能重疊後果斷簡化

3. **版本號語意化**
   - 產品版本 vs 文檔版本需要明確區分
   - 統一規範避免未來混淆

4. **保留彈性**
   - 移除 `/atlas` 但保留 PROMPTS.md
   - 罕見場景仍可使用完整功能

---

## 🎯 下一步

根據 PRD v2.5 roadmap：

### Phase 2：影響分析功能（建議下一步）

**實作 `/atlas.impact` - 靜態影響分析** ⭐⭐⭐⭐

**場景**：
- API 變更影響（場景 3B，高頻需求）
- Model 變更的連鎖影響

**預計工作量**：
1. 創建 `.claude/commands/atlas.impact.md`
2. 實作影響分析邏輯（靜態依賴分析）
3. 測試 3+ 個真實場景

---

## 📚 相關文檔

- [PRD.md](../../PRD.md) - 產品需求文檔
- [CLAUDE.md](../../CLAUDE.md) - AI 協作指南
- [PROMPTS.md](../../PROMPTS.md) - 完整三階段分析 prompts
- [proposals/code-maat-integration/](../../proposals/code-maat-integration/) - v2.6 時序分析提案
- [HISTORY.md](../HISTORY.md) - 完整開發歷史

---

## 🏷️ 標籤

`決策記錄` `架構設計` `命令簡化` `版本管理` `v2.5`
