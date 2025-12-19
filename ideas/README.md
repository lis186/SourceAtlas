# ideas/ - 腦力激盪區

> ⚠️ **實驗性質** - 這裡的內容可能不完整、不正確，隨時可能刪除

## 💡 用途

這是 SourceAtlas 的「思考空間」，用於：

- 💭 記錄突發靈感
- 🔬 實驗性研究
- 🤔 未成熟的想法
- 📝 快速筆記

---

## ✅ 可以做的

- ✅ 寫得很亂沒關係
- ✅ 想法不完整也可以
- ✅ 隨時刪除不需要的
- ✅ 不需要嚴格格式

---

## ❌ 不應該做的

- ❌ 長期滯留（超過 1 個月考慮清理或升級）
- ❌ 放重要資訊（應該放 proposals/ 或正式文檔）
- ❌ 當作垃圾桶（無價值內容應該刪除）
- ❌ 提交敏感資訊（永遠不應該）

---

## 🔄 生命週期

```
ideas/brainstorm.md
  ↓ 1-4 週研究驗證
  ↓ 發現有價值且可行
proposals/feature-name/
  ↓ 排入 roadmap
  ↓ 開始實作
dev-notes/YYYY-MM/implementation.md
```

---

## 📋 當前探索

### 活躍想法

- **[CLAUDE.md 瘦身計畫](./claude-md-slimming.md)** ✅ 已升級
  - **建立日期**: 2025-12-16
  - **成熟度**: 已升級到 proposal
  - **內容**: 將 CLAUDE.md 從 1,108 行精簡到 500 行以下
  - **Proposal**: [proposals/claude-md-optimization/](../proposals/claude-md-optimization/)

- **[Skills Auto-Activation Hooks](./skills-auto-activation-hooks.md)**
  - **建立日期**: 2025-12-16
  - **成熟度**: 30%
  - **內容**: 使用 Hooks 主動注入 SourceAtlas context，而非被動依賴 CLAUDE.md 規則
  - **來源**: Reddit 文章 "Claude Code is a Beast"
  - **下一步**: 研究 Claude Code Hooks API

- **[Dev Docs 任務文檔系統](./dev-docs-task-system.md)**
  - **建立日期**: 2025-12-16
  - **成熟度**: 40%
  - **內容**: 三文件系統（plan/context/tasks）追蹤大型任務進度，防止 Claude 失憶
  - **來源**: Reddit 文章 "Claude Code is a Beast"
  - **下一步**: 評估是否需要 `/atlas.task` 命令

- **[Gentle Reminders Hooks](./gentle-reminders-hooks.md)**
  - **建立日期**: 2025-12-16
  - **成熟度**: 30%
  - **內容**: 非阻塞式自我檢查提醒，在每次回應後顯示品質檢查清單
  - **來源**: Reddit 文章 "Claude Code is a Beast"
  - **下一步**: 評估 token 成本

- **[Claude Code Plugins 學習筆記](./claude-code-plugins-learnings.md)**
  - **建立日期**: 2025-12-12
  - **成熟度**: 85% (大部分已升級或擱置)
  - **內容**: 分析 Claude Code 官方 plugins，提煉可借鑑的設計模式
  - **探索狀態**:
    - ✅ **漸進式輸出** - `/atlas.pattern` 完成 (v2.9.3)，其他擱置
    - ✅ **持久化** - `--save` + `/atlas.clear` 完成 (v2.9.1)
    - 🔲 信心分數 + Threshold 機制
    - 🔲 輸出格式統一
  - **下一步**: 評估「信心分數 Threshold」可行性（低優先）

### 已升級

- [x] **code-maat 整合** → 已實作為 `/atlas.history` (v2.6.0)
- [x] **/atlas.flow** → 已實作 (v2.7.0)

---

## 🚀 升級標準

**從 ideas/ 升級到 proposals/ 需要**：

1. ✅ **使用場景清晰** - 解決什麼實際問題
2. ✅ **技術方案可行** - 已經過初步驗證
3. ✅ **價值主張明確** - 為什麼值得做
4. ✅ **文檔基本完整** - 有架構設計和實作思路

**不符合的想法**：
- 🗑️ 沒價值 → 直接刪除
- ⏸️ 暫時擱置 → 標註 `[paused]`
- 🔬 繼續研究 → 保留在 ideas/

---

## 🧹 清理原則

**每月檢查**（在月度 review 時）：

```bash
# 檢視所有 ideas
ls -lt ideas/*.md

# 決策：
# - 超過 1 個月 → 升級或刪除
# - 已實作 → 移到 dev-notes/
# - 已放棄 → 刪除或記錄原因
```

**清理範例**：
```bash
# 想法已成熟
mv ideas/new-feature.md proposals/new-feature/README.md

# 想法已放棄（記錄原因）
echo "放棄原因：技術不可行" >> ideas/abandoned-idea.md
git mv ideas/abandoned-idea.md dev-notes/archives/abandoned/

# 想法無價值
rm ideas/random-thought.md
```

---

## 📝 檔案命名建議

雖然不強制，但建議：

```
ideas/
├── ai-quality-scoring-v2.md          # 主題清晰
├── technical-debt-quantification.md  # 使用連字號
└── 2025-11-24-random-thought.md      # 可選日期前綴
```

**不建議**：
```
❌ idea.md                    # 太模糊
❌ 新想法.md                  # 避免中文檔名
❌ MyGreatIdea123.md          # 不清楚是什麼
```

---

## 🤝 參與方式

**發現有趣的想法？**
- 💬 在 ideas/*.md 檔案中加入你的想法（直接編輯）
- 📝 開 Issue 討論
- 🔀 提 PR 補充細節

**想提出新想法？**
1. 創建 `ideas/your-idea-name.md`
2. 寫下你的想法（不用完美）
3. Commit 並分享

---

## ⏰ Review 時間表

- **每週** - 個人檢視，記錄新發現
- **每月** - 團隊 review，決定升級/刪除
- **每季** - 清理超過 3 個月的想法

---

## 💡 提示

- **允許失敗** - 80% 的想法可能不會實作，這很正常
- **快速驗證** - 用最小代價測試可行性
- **記錄過程** - 即使失敗也記錄「為什麼不可行」
- **保持流動** - ideas/ 應該保持活躍，不是長期存放處

---

## 📚 範例想法結構

```markdown
# 想法標題

## 問題
（要解決什麼問題？）

## 初步想法
（怎麼解決？）

## 疑問
- [ ] 技術上可行嗎？
- [ ] 有人需要嗎？
- [ ] 成本效益如何？

## 下一步
（如何驗證？）

## 更新日誌
- 2025-11-24: 初次記錄
- 2025-11-25: 測試了 X，發現 Y
```

---

**記住：這是思考空間，不是產品。盡情探索！**
