# 漸進式輸出 (Progressive Disclosure)

> **狀態**: ⚪ 部分完成後擱置
> **建立日期**: 2025-12-16
> **擱置日期**: 2025-12-18
> **來源**: [ideas/claude-code-plugins-learnings.md](../../ideas/claude-code-plugins-learnings.md)
> **已完成**: `/atlas.pattern` Smart 模式 + `--brief`/`--full` (v2.9.3)
> **擱置原因**: 其他命令已有快取，效益有限，假設未驗證

## 問題陳述

### 現況

目前所有 `/atlas.*` 命令輸出**固定詳細程度**，不論專案大小：

| 命令 | 輸出 | 預估 tokens | 問題 |
|------|------|-------------|------|
| `/atlas.overview` | 全量 YAML | ~2,000 | 小專案不需要這麼多 |
| `/atlas.pattern` | 完整報告 | ~800 | 有時只想知道「有沒有」 |
| `/atlas.history` | 全量報告 | ~1,500 | - |
| `/atlas.impact` | 全量分析 | ~1,000 | - |
| `/atlas.deps` | 全量盤點 | ~1,200 | - |

### 影響

1. **Token 浪費** - 小專案生成過多不需要的細節
2. **認知負擔** - 用戶被大量資訊淹沒
3. **回應延遲** - 生成完整報告較慢

### 現有參考

**`/atlas.flow` 已實作漸進式揭露**：
- 主路徑 >7 步驟會停下來
- 標記 🔍 讓用戶選擇展開
- 這是現成的參考模式

---

## 解決方案：三層漸進式架構

### 核心設計

```
Level 1: 指紋卡片（~50 tokens）  ← 預設給 TINY/SMALL 專案
Level 2: 假設摘要（~200 tokens） ← 預設給 MEDIUM 專案
Level 3: 完整報告（~2000 tokens）← 預設給 LARGE+ 專案 / --full
```

### 智慧預設 + 可選覆蓋

**預設行為**：根據專案規模自動選擇詳細程度
**覆蓋參數**：
- `--brief` → 強制 Level 1
- `--full` → 強制 Level 3

---

## 各命令設計

### 1. `/atlas.overview` 漸進式

**智慧預設**：
```
├── TINY 專案：Level 1 only（50 tokens）
├── SMALL 專案：Level 1-2（200 tokens）
└── MEDIUM+ 專案：Level 1-3（完整，2000 tokens）
```

**Level 1（指紋卡片）**：
```markdown
## 專案指紋

| 項目 | 值 |
|------|-----|
| 類型 | WEB_APP |
| 規模 | MEDIUM (2.5K files) |
| 語言 | TypeScript + React |
| 架構 | Clean Architecture |
| AI 協作 | Level 3 |

💡 輸入 `more` 查看假設列表
```

**Level 2（假設摘要）**：
```markdown
## 假設（共 12 個）

高信心（≥0.8）：
1. 使用 Zustand 狀態管理 (0.95)
2. Repository pattern 資料層 (0.88)
3. Jest + Testing Library 測試 (0.85)

中信心（0.5-0.8）：
4. 可能有未使用的 Redux 遺留 (0.65)

💡 輸入 `full` 查看完整 YAML
```

**Level 3**：現有完整 YAML 格式

---

### 2. `/atlas.pattern` 漸進式

**智慧預設**：
```
├── 找到 ≤3 個檔案：Level 2（實作指南摘要）
└── 找到 >3 個檔案：Level 1（統計 + 選擇）
```

**Level 1（統計 + 選擇）**：
```markdown
## Pattern: Repository

找到 15 個匹配檔案：

📊 分布統計：
- src/repositories/: 8 個
- src/data/: 5 個
- tests/: 2 個

🔍 選擇要深入分析的：
1. UserRepository.ts (核心，最多引用)
2. BaseRepository.ts (基底類別)
3. OrderRepository.ts (複雜度最高)

💡 輸入數字（如 `1`）或 `all` 完整分析
```

---

### 3. `/atlas.history` 漸進式

**Level 1**：Top 5 熱點 + 建議
**Level 2**：Top 20 + 趨勢分析
**Level 3**：完整報告

---

### 4. `/atlas.deps` 漸進式

**Level 1**：摘要（依賴數量 + 主要框架）
**Level 2**：分類列表
**Level 3**：完整盤點 + 升級建議

---

## 實作計畫

### Phase 1: `/atlas.overview` 漸進式

1. 修改 `atlas.overview.md` 加入規模偵測
2. 實作 Level 1/2/3 輸出模板
3. 加入 `--brief` 和 `--full` 參數
4. 測試 TINY/SMALL/MEDIUM/LARGE 專案

### Phase 2: `/atlas.pattern` 漸進式

1. 修改 `atlas.pattern.md` 加入檔案數量偵測
2. 實作統計 + 選擇介面
3. 測試多檔案場景

### Phase 3: 其他命令

1. `/atlas.history` 加入 Top N 控制
2. `/atlas.deps` 加入摘要模式

---

## 成本評估

| 命令 | 改動幅度 | 工作量 |
|------|----------|--------|
| `/atlas.overview` | 中 | 2-3h |
| `/atlas.pattern` | 中 | 2h |
| `/atlas.flow` | 已有 | - |
| `/atlas.history` | 小 | 1h |
| `/atlas.deps` | 小 | 1h |

**總工作量**：約 6-8 小時

---

## 預期效益

### Token 節省

| 場景 | 優化前 | 優化後 | 節省 |
|------|--------|--------|------|
| TINY 專案 overview | ~2,000 | ~50 | **97%** |
| SMALL 專案 overview | ~2,000 | ~200 | **90%** |
| Pattern 多檔案 | ~800 | ~150 | **81%** |

### 其他效益

- **認知負擔降低** - 先看摘要，需要時再深入
- **回應更快** - 生成簡短輸出更快
- **與 `/atlas.flow` 一致** - 統一的漸進式體驗

---

## 風險與緩解

| 風險 | 機率 | 影響 | 緩解 |
|------|------|------|------|
| 智慧預設猜錯 | 中 | 低 | 提供 `--full` 覆蓋 |
| 用戶不習慣 | 中 | 中 | 清楚的 `💡` 提示 |
| 增加維護複雜度 | 低 | 中 | 統一 Level 定義 |

---

## 相容性

- **--save 參數**：儲存時一律儲存 Level 3（完整版）
- **--force 參數**：不受影響
- **現有輸出格式**：Level 3 = 現有格式，無 breaking change

---

## 驗收標準

1. `/atlas.overview` 在 TINY 專案輸出 <100 tokens
2. `/atlas.pattern` 在 >5 檔案時顯示選擇介面
3. 所有命令支援 `--brief` 和 `--full` 參數
4. 💡 提示清晰，用戶知道如何獲取更多資訊

---

## 更新日誌

- 2025-12-16: 從 ideas/claude-code-plugins-learnings.md 升級為 proposal
