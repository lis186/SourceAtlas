# Claude Code Plugins 學習筆記

## 來源

- **日期**：2025-12-12
- **參考**：https://github.com/anthropics/claude-code/tree/main/plugins
- **分析的 Plugins**：code-review, feature-dev, plugin-dev, security-guidance

## 值得探索的方向

### 1. 並行 Agent 架構

**來自**：code-review

**設計**：
- 4 個 Agent 並行執行（2 Compliance + 1 Bug + 1 History）
- 每個 Agent 有獨立 focus area
- 結果匯總後統一過濾

**潛在應用**：
- `/atlas.overview` 可並行分析：技術棧、架構、測試、文檔
- `/atlas.impact` 可並行追蹤：imports、exports、tests、configs

**待驗證**：
- [ ] Claude Code 的 Task tool 並行效能如何？
- [ ] 是否會增加 token 消耗（多個 agent 各自讀檔）？
- [ ] 結果合併的複雜度？

**SourceAtlas 現況**：單一執行，較慢但 token 可控

---

### 2. 漸進式輸出（Progressive Disclosure）⭐ 深度探索

**來自**：plugin-dev

**設計**：
```
Level 1: Metadata（永遠載入）- 觸發描述，~50 tokens
Level 2: Core SKILL.md（觸發時）- 核心 API，~1,500 tokens
Level 3: References/Examples（按需）- 詳細指南，~3,000+ tokens
```

---

#### 🔍 深度分析（2025-12-12）

##### 現況盤點

| 命令 | 現況 | 預估 tokens | 問題 |
|------|------|-------------|------|
| `/atlas.overview` | 全量 YAML | ~2,000 | 小專案不需要這麼多 |
| `/atlas.pattern` | 完整報告 | ~800 | 有時只想知道「有沒有」 |
| `/atlas.flow` | 已有漸進！ | 變動 | ✅ 標記 🔍 讓用戶選擇展開 |
| `/atlas.history` | 全量報告 | ~1,500 | - |
| `/atlas.impact` | 全量分析 | ~1,000 | - |
| `/atlas.deps` | 全量盤點 | ~1,200 | - |

**發現**：`/atlas.flow` 已經實作漸進式揭露！
- 主路徑 >7 步驟會停下來
- 標記 🔍 讓用戶選擇展開
- 這是現成的參考模式

##### 三種實作方式比較

| 方式 | 優點 | 缺點 | 適用 |
|------|------|------|------|
| **A. 參數控制** | 簡單、明確 | 增加學習成本 | 進階用戶 |
| **B. 互動式** | 漸進揭露 | 打斷流程 | 探索場景 |
| **C. 智慧預設** | 零學習 | 可能猜錯 | 大部分場景 |

**建議**：**C + A 混合** - 智慧預設 + 可選覆蓋

##### 各命令漸進式設計

**1. `/atlas.overview` 漸進式**

```
預設行為（智慧判斷）：
├── TINY 專案：Level 1 only（50 tokens）
├── SMALL 專案：Level 1-2（200 tokens）
└── MEDIUM+ 專案：Level 1-3（完整，2000 tokens）

可選參數：
--brief    → 強制 Level 1
--full     → 強制 Level 3
--save     → 儲存完整版本
```

Level 1（指紋卡片）：
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

Level 2（假設摘要）：
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

Level 3（完整 YAML）：現有格式

**2. `/atlas.pattern` 漸進式**

```
預設行為：
├── 找到 ≤3 個檔案：Level 2（實作指南摘要）
└── 找到 >3 個檔案：Level 1（統計 + 選擇）

可選參數：
--list     → 只列出檔案
--full     → 完整分析
```

Level 1（統計 + 選擇）：
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

**3. `/atlas.history` 漸進式**

已經有選擇機制（Hotspots/Coupling/Contributors），可增加：

```
Level 1：Top 5 熱點 + 建議
Level 2：Top 20 + 趨勢分析
Level 3：完整報告 + 圖表
```

##### 實作成本評估

| 命令 | 改動幅度 | 工作量 | 優先級 |
|------|----------|--------|--------|
| `/atlas.overview` | 中 | 2-3h | ⭐⭐⭐⭐ |
| `/atlas.pattern` | 中 | 2h | ⭐⭐⭐ |
| `/atlas.flow` | 已有 | - | ✅ |
| `/atlas.history` | 小 | 1h | ⭐⭐ |
| `/atlas.deps` | 小 | 1h | ⭐⭐ |

**總工作量**：約 6-8 小時

##### 風險評估

| 風險 | 機率 | 影響 | 緩解 |
|------|------|------|------|
| 智慧預設猜錯 | 中 | 低 | 提供 `--full` 覆蓋 |
| 用戶不習慣 | 中 | 中 | 清楚的 `💡` 提示 |
| 增加維護複雜度 | 低 | 中 | 統一 Level 定義 |

##### 結論

**可行性**：✅ 高
**價值**：
- Token 效率提升 30-50%（小專案）
- 認知負擔降低（先看摘要再深入）
- 與 `/atlas.flow` 現有設計一致

**建議**：升級到 `proposals/` 進行正式設計

---

### 3. 信心分數 + Threshold 機制

**來自**：code-review

**設計**：
```
信心分數：0-100
Threshold：80（可調整）
只報告 ≥ threshold 的問題
```

**評分標準**：
```
0   → 不確定，可能是 false positive
25  → 稍有信心，可能是真的
50  → 中等信心，真的但次要
75  → 高度信心，真的且重要
100 → 絕對確定，一定是真的
```

**潛在應用**：
- `/atlas.overview` 假設生成：只輸出信心 ≥ 0.7 的假設
- `/atlas.impact` 影響分析：區分「確定影響」vs「可能影響」

**待驗證**：
- [ ] 現有 0.0-1.0 是否足夠？還是需要 0-100？
- [ ] Threshold 應該是固定還是可配置？
- [ ] 如何在 prompt 中引導 LLM 給出準確分數？

**SourceAtlas 現況**：有 0.0-1.0 信心分數，但沒有 threshold 過濾

---

### 4. Validation Subagent

**來自**：code-review

**設計**：
```
Step 4: 4 agents 並行找問題
Step 5: 對每個問題，啟動 validation subagent 驗證
Step 6: 過濾掉未通過驗證的問題
```

**潛在應用**：
- `/atlas.overview` Stage 0 生成假設後，用 subagent 驗證
- 取代目前的 Stage 1 手動驗證？

**待驗證**：
- [ ] 驗證 subagent 的 token 成本？
- [ ] 是否能達到 Stage 1 的驗證品質？
- [ ] 自動驗證 vs 人工驗證的取捨？

**SourceAtlas 現況**：Stage 1 是獨立步驟，需要人工觸發

---

### 5. Hook 機制轉 Constitution 規則

**來自**：security-guidance

**設計**：
```
PreToolUse hook → 在工具執行前驗證
可以阻擋不符合規則的操作
```

**潛在應用**：
```bash
# 把 Constitution Article II（排除目錄）轉為 hook
if [[ "$file_path" == *"node_modules"* ]]; then
  echo "BLOCKED: Constitution Article II violation"
  exit 1
fi
```

**待驗證**：
- [ ] SourceAtlas 是 slash command，不是 plugin，能用 hook 嗎？
- [ ] 是否需要把 SourceAtlas 轉為 plugin 架構？
- [ ] 目前 `validate-constitution.sh` 是否足夠？

**SourceAtlas 現況**：Constitution 是文檔 + 事後驗證，不是事前阻擋

---

### 6. 標準化輸出格式

**來自**：code-review

**設計**：
```markdown
## Code review

Found 3 issues:

1. [description] (CLAUDE.md says: "[exact quote]")
   https://github.com/.../file.ts#L67-L72
```

**潛在應用**：
- 統一所有 `/atlas.*` 命令的輸出結構
- 定義 SourceAtlas Output Schema

**待驗證**：
- [ ] 目前各命令輸出格式差異多大？
- [ ] 需要 breaking change 嗎？
- [ ] 是否需要 JSON schema 定義？

**SourceAtlas 現況**：各命令輸出格式不一致

---

## SourceAtlas 已經做得更好的地方

這些是 SourceAtlas 的優勢，不需要改：

1. **Constitution 治理** - Claude Code Plugins 沒有統一規則框架
2. **規模感知** - Plugins 是一刀切，SourceAtlas 有 5 級策略
3. **資訊理論** - 高熵優先、掃描比例上限
4. **141 Patterns** - 預定義 pattern，不依賴即時判斷
5. **Handoffs 原則** - 動態下一步，不是固定流程

---

## 優先級評估

| 方向 | 價值 | 難度 | 建議優先級 |
|------|------|------|------------|
| 漸進式輸出 | 高（token 效率） | 中 | ⭐⭐⭐⭐ |
| 信心 Threshold | 中（減少雜訊） | 低 | ⭐⭐⭐ |
| 並行 Agent | 中（速度） | 高 | ⭐⭐ |
| Validation Subagent | 低（已有 Stage 1） | 高 | ⭐ |
| Hook 機制 | 低（已有驗證腳本） | 高 | ⭐ |
| 輸出格式統一 | 中（一致性） | 中 | ⭐⭐⭐ |

---

## 下一步

- [ ] 評估漸進式輸出的具體設計
- [ ] 測試信心分數 threshold 在 `/atlas.overview` 假設上的效果
- [ ] 審視各命令輸出格式，評估統一成本

## 升級條件

當滿足以下條件時，可將具體項目移至 `proposals/`：

1. 確定要實作哪個功能
2. 有具體的技術方案
3. 完成初步可行性驗證
4. 定義清晰的使用場景
