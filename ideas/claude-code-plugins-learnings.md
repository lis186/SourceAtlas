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

### 2. 漸進式輸出（Progressive Disclosure）

**來自**：plugin-dev

**設計**：
```
Level 1: Metadata（永遠載入）- 觸發描述，~50 tokens
Level 2: Core SKILL.md（觸發時）- 核心 API，~1,500 tokens
Level 3: References/Examples（按需）- 詳細指南，~3,000+ tokens
```

**潛在應用**：
```
/atlas.overview
├── Level 1：專案指紋（類型、規模、主語言）~50 tokens
├── Level 2：假設列表 + 掃描檔案 ~200 tokens
└── Level 3：完整 YAML + 證據 ~2,000 tokens

/atlas.pattern
├── Level 1：Pattern 名稱 + 檔案計數 ~30 tokens
├── Level 2：實作指南摘要 ~150 tokens
└── Level 3：完整範例程式碼 ~500+ tokens
```

**待驗證**：
- [ ] 如何讓使用者選擇輸出層級？（參數？互動？）
- [ ] 是否需要改 command 架構？
- [ ] 與 `--save` 參數的互動？

**SourceAtlas 現況**：全量輸出，token 效率可改善

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
