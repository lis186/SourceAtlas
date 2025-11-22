# Contributing to SourceAtlas

感謝你對 SourceAtlas 的興趣！我們歡迎所有形式的貢獻。

## 🚀 快速開始

### 我想貢獻什麼？

**實作新功能** → 查看 [當前優先任務](#當前優先任務)
**修復 Bug** → 查看 [Issues](https://github.com/lis186/sourceatlas2/issues)
**改進文檔** → 直接提交 PR
**提供回饋** → 開 Issue 或加入討論

---

## 📚 貢獻者閱讀路徑

**第一次貢獻？** 按照這個順序閱讀：

1. **README.md** (5 分鐘) - 了解專案是什麼
2. **CLAUDE.md** (15 分鐘) - 開發規範和核心原則 ⭐ 必讀
3. **.dev-notes/NEXT_STEPS.md** (10 分鐘) - 當前任務和優先級
4. **.dev-notes/implementation-roadmap.md** (15 分鐘) - 詳細實作計畫

**進階閱讀**：
- `.dev-notes/KEY_LEARNINGS.md` - v1.0 關鍵學習
- `.dev-notes/HISTORY.md` - 完整歷史和決策記錄
- `PRD.md` - 產品需求文檔

---

## ⭐ 當前優先任務

### Phase 1 - 最高優先級（當前）

| 任務 | 優先級 | 預估時間 | 技能需求 |
|------|--------|----------|----------|
| `/atlas-pattern` 命令實作 | ⭐⭐⭐⭐⭐ | 1-2 天 | Bash + Markdown |
| `/atlas` 完整三階段分析 | ⭐⭐⭐⭐⭐ | 2-3 天 | Bash + Markdown |
| `find-patterns.sh` 腳本 | ⭐⭐⭐⭐⭐ | 1 天 | Bash |

**推薦起點**：`/atlas-pattern` - 有清晰需求，可參考 `atlas-overview.md` 範例

詳細規格見：
- PRD.md 第 2 節「場景 2：學習現有模式」
- .dev-notes/implementation-roadmap.md Phase 1

---

## 🛠️ 開發設置

### 環境需求

- **Claude Code** - 必須（用於測試 Commands）
- **Bash 4.0+** - POSIX-compliant shell
- **Git** - 版本控制
- **GitButler** - Git 工作流程管理（可選但推薦）

### 設置步驟

```bash
# 1. Clone 專案
git clone https://github.com/lis186/sourceatlas2.git
cd sourceatlas2

# 2. 檢查環境
bash --version  # 應該 >= 4.0
git --version

# 3. 測試現有 scripts
bash scripts/atlas/detect-project-enhanced.sh .
bash scripts/atlas/scan-entropy.sh .

# 4. 閱讀開發規範
cat CLAUDE.md  # 完整開發指南
```

---

## 📝 開發規範

### 8 項核心原則（必須遵循）

詳見 `CLAUDE.md`，簡要版本：

1. **規模感知設計** - 根據專案大小調整（TINY → VERY_LARGE）
2. **標準優於自訂** - 使用 YAML、Markdown，不發明格式
3. **測試先行** - 在 3+ 真實專案測試
4. **文檔同步** - 邊開發邊寫文檔
5. **基準測量** - 使用 `benchmark.sh` 驗證
6. **排除目錄** - 永遠排除 .venv、node_modules、__pycache__
7. **資訊理論** - 高熵優先，結構 > 實作細節
8. **證據為本** - 每個論點需要證據（file:line 引用）

### Bash Scripts 規範

```bash
#!/usr/bin/env bash
set -euo pipefail  # 嚴格模式

# 清楚的註解說明用途
# 錯誤處理和邊界情況
# POSIX-compliant（避免 bashisms）
```

### Commands 格式

參考 `.claude/commands/atlas-overview.md`：

```markdown
---
description: 簡短描述（<100 字）
allowed-tools: Bash, Glob, Grep, Read
argument-hint: [optional: 參數提示]
---

# Command 名稱

## Context
## Your Task
## Output Format
```

---

## 🧪 測試要求

### 必須測試

在提交 PR 前，**必須**：

1. **在 3+ 不同專案測試**
   - 不同規模：TINY、MEDIUM、LARGE
   - 不同語言：Python、TypeScript、Go 等
   - 建議使用 `test_targets/` 中的專案

2. **執行 benchmark 驗證**
   ```bash
   bash scripts/atlas/benchmark.sh <project-path>
   ```

   確保：
   - ✅ 速度：<15 分鐘
   - ✅ 大小：<200 行輸出
   - ✅ Tokens：<3000
   - ✅ 掃描率：<10%（MEDIUM/LARGE）

3. **跨平台測試**（如可能）
   - macOS
   - Linux（Ubuntu/Debian）
   - Windows WSL（可選）

### 測試範例

```bash
# 測試 detect-project-enhanced.sh
cd test_targets/cursor-talk-to-figma-mcp
bash ../../scripts/atlas/detect-project-enhanced.sh .

# 應該輸出：
# - Project type: WEB_APP
# - Scale: SMALL
# - Language: TypeScript
```

---

## 🔄 Git 工作流程

### 重要：GitButler 流程

⚠️ **不要手動使用 `git commit`**

本專案使用 **GitButler** 自動管理 commits 和分支：

- GitButler 會自動創建 commits
- 專注於編寫代碼和測試
- 任務完成後，停止工作，讓 GitButler 執行後處理

**如果你不使用 GitButler**：
- 可以 fork 專案並正常提交 PR
- PR 會被 review 後合併到 GitButler workspace

### 提交訊息規範

遵循 **Conventional Commits**：

```
feat: add /atlas-pattern command
fix: correct scan-entropy.sh path handling
docs: update USAGE_GUIDE for new command
test: add benchmark for TINY projects
```

類型：`feat`, `fix`, `docs`, `test`, `refactor`, `style`, `chore`

---

## ✅ 提交 PR 檢查清單

在提交 Pull Request 前，確認：

- [ ] 在 3+ 不同專案測試（不同規模、語言）
- [ ] 執行 `benchmark.sh` 並達標（速度/大小/tokens）
- [ ] 更新相關文檔（USAGE_GUIDE.md, README.md）
- [ ] 遵循 8 項核心原則
- [ ] Bash scripts 使用 `set -euo pipefail`
- [ ] 有清楚的註解和使用範例
- [ ] 跨平台測試（至少 macOS + Linux）
- [ ] 文檔與代碼同步更新

### PR 描述模板

```markdown
## 描述
[簡短描述這個 PR 做了什麼]

## 測試結果
- [x] cursor-talk-to-figma-mcp (SMALL, TypeScript)
- [x] smart-weather-mcp-server (MEDIUM, TypeScript)
- [x] github-mcp-server (LARGE, Go)

## Benchmark 結果
- 速度：10 分鐘 ✅
- 大小：145 行 ✅
- Tokens：2450 ✅
- 掃描率：8% ✅

## 文檔更新
- [x] USAGE_GUIDE.md
- [x] README.md（如適用）
```

---

## 💬 獲得幫助

**有問題？**

1. 查看 **CLAUDE.md** - 最完整的開發指南
2. 閱讀 **.dev-notes/** - 歷史決策和學習
3. 查看現有實作 - `.claude/commands/atlas-overview.md`
4. 開 Issue 提問

**討論想法？**
- 開 GitHub Discussion
- 或直接開 Issue 描述你的想法

---

## 🎯 貢獻類型

### 代碼貢獻

- 實作新 Commands（`/atlas-pattern`, `/atlas`, `/atlas-impact`）
- 改進 Scripts（效能優化、錯誤處理）
- 加入測試（自動化測試套件）

### 文檔貢獻

- 改進初學者指南
- 加入使用範例
- 翻譯文檔（英文版）
- 修正錯字和不清楚的說明

### 測試和驗證

- 在更多專案測試
- 報告 bugs 和邊界情況
- 提供使用回饋

### 研究貢獻

- 擴大驗證樣本（目前 N=5）
- 進行對照實驗
- 學術論文合作

---

## 📜 授權

提交貢獻表示你同意你的代碼以 **CC-BY-SA 4.0** 授權。

---

## 🙏 感謝

感謝所有貢獻者讓 SourceAtlas 變得更好！

特別感謝：
- v1.0 驗證階段的測試專案
- 所有提供回饋的開發者
- Claude Code 團隊

---

**準備好開始了嗎？**

1. 閱讀 **CLAUDE.md**
2. 查看 **.dev-notes/NEXT_STEPS.md**
3. 選擇一個 Phase 1 任務
4. 開始貢獻！🚀
