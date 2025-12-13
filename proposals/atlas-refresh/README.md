# /atlas.refresh - 批次重新分析過期快取

**狀態**: 🟡 研究中
**來源**: DX 工程師測試報告建議 (2025-12-13)
**優先級**: 低

---

## 使用場景

### 問題描述

當使用者有多個已儲存的分析結果（`.sourceatlas/`），部分可能已過期（>30 天）。目前需要：

1. 執行 `/atlas.list` 查看所有快取
2. 手動識別哪些已過期
3. 逐一執行 `/atlas.xxx --force` 重新分析

**痛點**：步驟繁瑣，容易遺漏過期快取

### 目標用戶

- 長期維護專案的開發者
- 定期審查 codebase 的技術負責人
- 需要保持分析結果最新的團隊

### 為什麼需要

- **效率**：一個命令取代多次手動操作
- **完整性**：確保所有過期快取都被更新
- **自動化**：可整合到 CI/CD 或定期任務

---

## 功能設計

### 基本用法

```bash
# 重新分析所有過期快取（預設 >30 天）
/atlas.refresh

# 自訂過期閾值
/atlas.refresh --days 7

# 只刷新特定類型
/atlas.refresh --type patterns
/atlas.refresh --type overview,history

# Dry run（只顯示會刷新哪些，不實際執行）
/atlas.refresh --dry-run
```

### 輸出範例

```
🔄 Refreshing expired analysis cache...

Scanning .sourceatlas/:
  ├── overview.yaml (45 days old) - EXPIRED
  ├── patterns/api.md (12 days old) - OK
  ├── patterns/repository.md (35 days old) - EXPIRED
  ├── history.md (60 days old) - EXPIRED
  └── flows/checkout.md (5 days old) - OK

Found 3 expired items (threshold: 30 days)

Refreshing:
  [1/3] overview.yaml... ✓
  [2/3] patterns/repository.md... ✓
  [3/3] history.md... ✓

✅ Refresh complete!
  - Updated: 3 files
  - Skipped: 2 files (still fresh)
  - Total time: 2m 15s
```

### Dry Run 輸出

```
🔍 Dry run - showing what would be refreshed:

| # | File | Age | Status | Command |
|---|------|-----|--------|---------|
| 1 | overview.yaml | 45 days | EXPIRED | /atlas.overview --force --save |
| 2 | patterns/repository.md | 35 days | EXPIRED | /atlas.pattern "repository" --force --save |
| 3 | history.md | 60 days | EXPIRED | /atlas.history --force --save |

Would refresh 3 files. Run without --dry-run to execute.
```

---

## 技術設計

### 命令檔案結構

```yaml
---
description: Batch refresh expired analysis cache
model: sonnet
allowed-tools: Bash, Glob, Read, Task
argument-hint: [--days N] [--type TYPE] [--dry-run]
---
```

### 實作步驟

1. **掃描 `.sourceatlas/`**：列出所有檔案及修改時間
2. **計算過期**：比對閾值（預設 30 天）
3. **解析原始命令**：從檔案路徑推斷原始命令和參數
4. **批次執行**：依序執行各分析命令（加 `--force --save`）
5. **報告結果**：統計更新數量和耗時

### 檔案路徑 → 命令映射

| 檔案路徑 | 原始命令 |
|----------|----------|
| `overview.yaml` | `/atlas.overview --force --save` |
| `overview-src.yaml` | `/atlas.overview src --force --save` |
| `patterns/api.md` | `/atlas.pattern "api" --force --save` |
| `history.md` | `/atlas.history --force --save` |
| `flows/checkout.md` | `/atlas.flow "checkout" --force --save` |
| `impact/user-model.md` | `/atlas.impact "user model" --force --save` |
| `deps/react.md` | `/atlas.deps "react" --force --save` |

### 過期閾值考量

**統一閾值（簡單方案）**：
- 預設 30 天，可用 `--days` 覆蓋

**類型差異化閾值（進階方案）**：

| 類型 | 預設閾值 | 原因 |
|------|---------|------|
| overview | 30 天 | 專案結構相對穩定 |
| pattern | 60 天 | Pattern 很少變動 |
| history | 7 天 | Git 歷史快速變化 |
| impact | 14 天 | 依賴關係可能變動 |
| flow | 30 天 | 流程相對穩定 |
| deps | 7 天 | Library 更新頻繁 |

**建議**：v1 先用統一閾值，收集使用回饋後再考慮差異化

---

## 邊界情況

### 1. 無法推斷原始參數

**問題**：`patterns/very-long-pattern-name-that-was-trunca.md` 被截斷過，無法還原完整參數

**處理**：
```
⚠️ Cannot determine original parameter for: patterns/very-long-pattern-name-that-was-trunca.md
   Skipping. Please refresh manually: /atlas.pattern "..." --force --save
```

### 2. 執行過程中失敗

**處理**：
- 記錄失敗項目
- 繼續執行其他項目
- 最後彙報失敗清單

```
⚠️ Refresh completed with errors:
  - patterns/api.md: Failed (timeout)
  - history.md: Failed (code-maat not installed)

Successfully refreshed: 2/4
Failed: 2/4 (see above)
```

### 3. 大量過期快取

**處理**：
- 顯示預估時間
- 提供取消選項

```
Found 15 expired items. Estimated time: ~30 minutes.
Continue? (y/n)
```

---

## 替代方案比較

| 方案 | 優點 | 缺點 |
|------|------|------|
| `/atlas.refresh` 命令 | 一鍵操作、可追蹤進度 | 需新增命令、增加維護成本 |
| Shell script | 不需改 SourceAtlas | 使用者需手動編寫、不易整合 |
| 在 `/atlas.list` 加選項 | 不需新命令 | 混淆 list 的職責 |

**結論**：新增 `/atlas.refresh` 是最清晰的設計，符合 Unix 哲學（一個命令做一件事）

---

## 實作計畫

### Phase 1: MVP

- [ ] 基本功能：掃描、過期判斷、批次執行
- [ ] 統一 30 天閾值
- [ ] `--dry-run` 支援
- [ ] 進度顯示

### Phase 2: 增強

- [ ] `--days N` 自訂閾值
- [ ] `--type` 篩選類型
- [ ] 差異化閾值（可選）
- [ ] 失敗重試機制

### 測試策略

1. **單元測試**：檔案路徑 → 命令映射
2. **整合測試**：在有多個快取的專案執行
3. **邊界測試**：截斷檔名、空目錄、執行失敗

---

## 開放問題

1. **是否需要確認？** 預設直接執行 or 需要 `--confirm`？
2. **並行執行？** 多個分析可以同時跑嗎？（可能有 rate limit 問題）
3. **通知機制？** 長時間執行時是否需要通知？

---

## 相關文檔

- [Persistence v2.0 實作](../../dev-notes/2025-12/)
- [/atlas.list](../../.claude/commands/atlas.list.md)
- [/atlas.clear](../../.claude/commands/atlas.clear.md)
