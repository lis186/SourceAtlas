## 附錄 A：設計決策記錄

### 決策 1：為什麼選擇 Skill 而非 CLI？

**日期**：2025-11-20

**問題**：原始 PRD 設計獨立 CLI 工具 (`satlas`)，是否仍然適合？

**考量因素**：
| 因素 | CLI 工具 | Skill 架構 |
|------|---------|-----------|
| 開發時間 | 8 週 | 1-2 週 |
| 學習成本 | 需學習命令 | 自然語言 |
| 工作流整合 | 需切換工具 | 原生整合 |
| 維護成本 | 高（索引、解析） | 低（Scripts + AI） |
| 靈活性 | 固定索引 | 動態探索 |

**決策**：採用 Claude Code Skill + Scripts 架構

**理由**：
1. 開發者已經在 Claude Code 中工作
2. AI 的理解能力可以替代大量解析邏輯
3. 即時探索比預先索引更靈活
4. 更快交付價值（1-2 週 vs 8 週）

---

### 決策 2：Scripts 的職責範圍

**日期**：2025-11-20

**問題**：Scripts 應該做多少事？

**決策**：Scripts 只做資料收集，不做理解推理

**理由**：
- AI 擅長理解和推理
- Scripts 擅長快速資料收集
- 保持 Scripts 簡單，易於維護
- 避免在 Bash 中實作複雜邏輯

**範例**：
```bash
# ✅ Script 負責
detect_files() { find . -name "*.rb"; }

# ✅ AI 負責
"這些檔案使用 Service Object 模式"
```

---

### 決策 3：是否需要持續索引？

**日期**：2025-11-20

**問題**：v2.5 是否需要建立和維護索引？

**決策**：v2.5 不建立持續索引，留待 v2.6

**理由**：
1. 即時探索場景（找 Bug、學模式）不需要索引
2. 持續追蹤場景（技術債務）才需要索引
3. 先驗證即時探索的價值
4. 避免過度設計

**影響**：
- v2.5 專注於即時分析
- v2.6 再評估是否需要 Monitor

---

### 決策 4：Commands vs Skills？⭐

**日期**：2025-11-20

**問題**：SourceAtlas 應該使用 Claude Code Commands 還是 Skills？

**技術差異**：

| 特性 | Commands | Skills |
|------|----------|--------|
| **觸發方式** | 用戶手動輸入 `/cmd` | AI 自動決定 |
| **控制權** | 用戶明確控制 | AI 上下文判斷 |
| **適用場景** | 主動工具、明確流程 | 被動輔助、專家系統 |
| **參數傳遞** | ✅ 支援 `$ARGUMENTS` | ❌ 不支援 |
| **Script 執行** | ✅ 支援 | ✅ 支援 |
| **檔案結構** | 單一 .md 檔案 | 目錄結構 (SKILL.md + scripts/) |
| **開發速度** | 快（簡單） | 慢（複雜） |

**考量因素**：

| 因素 | Commands | Skills | 勝出 |
|------|----------|--------|------|
| **使用者期望** | 明確觸發分析 | 自動觸發 | ✅ Commands |
| **場景多樣性** | 不同命令對應不同場景 | 單一入口 | ✅ Commands |
| **可預測性** | 高 | 低 | ✅ Commands |
| **開發複雜度** | 低 | 高 | ✅ Commands |
| **Token 效率** | 普通 | 優秀 | Skills |

**決策**：採用 Claude Code Commands 架構

**理由**：

1. **SourceAtlas 是「工具」不是「助手」**
   - 用戶想要明確控制何時執行分析
   - 不希望 AI 自動執行 30 分鐘的完整分析
   - 不同場景需要不同入口點

2. **使用場景需要明確觸發**
   - `/atlas.overview` (專案指紋，10-15 分鐘) vs `/atlas.pattern` (快速學習，5 分鐘)
   - 用戶根據需求選擇合適的命令
   - Commands 提供清晰的功能邊界

3. **開發效率更高**
   - 一個 Command = 一個 .md 檔案
   - 更簡單、更直接
   - 用戶可輕鬆查看和修改

4. **符合優先級排序**
   - `/atlas.overview` ⭐⭐⭐⭐⭐ (專案指紋)
   - `/atlas.pattern` ⭐⭐⭐⭐⭐ (最常用)
   - `/atlas.impact` ⭐⭐⭐⭐ (影響分析)
   - 不同優先級需要不同命令入口

**實作方案**：

```
.claude/commands/
├── atlas.overview.md     # /atlas.overview - 專案指紋 ✅
├── atlas.pattern.md      # /atlas.pattern - 學習模式 ✅
├── atlas.impact.md       # /atlas.impact - 影響分析
├── atlas.find.md         # /atlas.find - 快速搜尋
└── atlas.explain.md      # /atlas.explain - 深入解釋

scripts/atlas/
├── detect-project.sh
├── scan-entropy.sh
├── find-patterns.sh      # 支援 /atlas.pattern
└── collect-git.sh
```

**未來可能用 Skill 的場景**（可選增強）：

創建一個輔助性的 Skill，在用戶表現出困惑時「建議」使用 SourceAtlas：

```markdown
---
name: sourceatlas-advisor
description: |
  Suggest SourceAtlas commands when user shows confusion about codebase.
  Do NOT auto-trigger analysis.
---

When detecting user confusion, suggest:
"Would you like me to run `/atlas.pattern` to learn how this codebase handles [X]?"
```

但這是**可選的增強**，不影響核心功能。

**影響**：
- PRD 第 3、6、9 章需要更新
- 將 "Skill" 術語改為 "Commands"
- 檔案結構從 `.claude/skills/` 改為 `.claude/commands/`
- 保持斜線命令介面不變（`/atlas.overview`, `/atlas.pattern` 等）

---

