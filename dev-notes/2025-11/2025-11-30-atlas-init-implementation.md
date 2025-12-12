# /atlas.init 命令實作與隱性觸發驗證

**日期**: 2025-11-30
**狀態**: ✅ 完成

---

## 概述

實作 `/atlas.init` 命令，讓 SourceAtlas 能夠在目標專案中注入自動觸發規則，使 Claude Code 能夠根據用戶意圖自動建議使用適當的 Atlas 命令。

---

## 背景與動機

### 問題

SourceAtlas 的命令（`/atlas-overview`, `/atlas-pattern`, `/atlas-impact`）已經可以全局安裝，但 Claude Code **不知道何時應該主動建議使用這些命令**。

### 研究參考

參考 [GitHub spec-kit](https://github.com/github/spec-kit) 的做法：
- `specify init` 在專案中注入模板和規則
- 透過 CLAUDE.md 讓 AI agent 知道何時使用特定命令

### 解決方案

創建 `/atlas.init` 命令，將「自動觸發規則」注入目標專案的 CLAUDE.md。

---

## 實作細節

### 命令位置

`.claude/commands/atlas.init.md`

### 功能

1. 檢查目標專案是否已有 CLAUDE.md
2. 檢查是否已有 SourceAtlas 區段（避免重複）
3. 注入標準化的觸發規則（英文）

### 注入內容

```markdown
## SourceAtlas Auto-Trigger Rules

| User Intent | Command |
|-------------|---------|
| "What is this project", "Help me understand the codebase" | `/atlas-overview` |
| "How does this project implement X", "Learn the pattern" | `/atlas-pattern [pattern]` |
| "What will this change affect" | `/atlas-impact [target]` |
| User just joined project and seems unfamiliar | `/atlas-overview` |

### When NOT to auto-trigger
- User is asking about a specific file they already know
- User is doing routine coding tasks
- User explicitly says they don't need overview/analysis
```

---

## 命令重命名決策

### 變更

`atlas-*` → `atlas.*`（dot-separated format）

### 原因

1. 與其他工具慣例一致（如 `speckit.*`）
2. 更清晰的命名空間分隔
3. 視覺上更易識別為 SourceAtlas 系列命令

### 影響檔案

- `.claude/commands/atlas.init.md`
- `.claude/commands/atlas.overview.md`
- `.claude/commands/atlas.pattern.md`
- `.claude/commands/atlas.impact.md`
- 所有文檔中的命令引用

---

## 隱性觸發驗證測試

### 測試設計

使用 10 個 subagent 並行測試，模擬不同經驗的開發者在各種專案中的查詢。

### 測試矩陣

| 專案 | 類型 | 開發者 | 查詢 | 預期 | 結果 |
|------|------|--------|------|------|------|
| iOS App 1 | iOS | Junior | 「幫我理解這個 codebase」 | `/atlas-overview` | ✅ |
| iOS App 2 | iOS | Mid | 「改 Article 模型會影響什麼」 | `/atlas-impact` | ✅ |
| iOS App 3 | SwiftUI | Senior | 「看看 API client 的實作模式」 | `/atlas-pattern` | ✅ |
| Android App 1 | Android | Junior | "What is this project?" | `/atlas-overview` | ✅ |
| Android App 2 | Android | Mid | "What depends on download manager?" | `/atlas-impact` | ✅ |
| Ruby App 1 | Ruby | Senior | "Show me payment processing pattern" | `/atlas-pattern` | ✅ |
| Python App 1 | Python | Junior | "Quick overview of architecture?" | `/atlas-overview` | ✅ |
| iOS App 4 | iOS | Mid | 「在 product.rb 加 validation」 | 不觸發 | ✅ |
| iOS App 5 | iOS | Senior | "Fix line 245 in PostListViewController" | 不觸發 | ✅ |
| Web App 1 | Web | Mid | "How does this handle API endpoints?" | `/atlas-pattern` | ✅ |

### 測試結果

```
總測試數: 10
正確觸發: 8/8 (100%)
正確不觸發: 2/2 (100%)
整體準確率: 10/10 (100%)
平均信心度: 95%
```

### 關鍵發現

1. **觸發規則有效** - 所有應觸發場景都正確識別
2. **邊界條件正確** - 例行任務、已知檔案正確排除
3. **跨語言工作** - 中英文查詢都能正確識別意圖
4. **跨專案類型** - iOS, Android, Ruby, Python, Web 都能正確處理

---

## 文檔更新

### 更新檔案

| 檔案 | 變更 |
|------|------|
| PRD.md | 加入 `/atlas-init` 設計規劃 |
| README.md | 4 個命令、使用決策樹 |
| CLAUDE.md | 命令列表、當前狀態 |
| GLOBAL_INSTALLATION.md | 完整安裝指南 |
| install-global.sh | 安裝 4 個命令 |

---

## 使用方式

```bash
# 重新安裝以獲取新命令
cd ~/dev/sourceatlas2
./install-global.sh

# 在任何專案中
cd ~/projects/any-project
/atlas.init  # 首次使用：注入自動觸發規則
```

執行後，Claude Code 會根據對話內容自動建議使用適當的 Atlas 命令。

---

## 相關連結

- [spec-kit 參考](https://github.com/github/spec-kit)
- [PRD.md 更新](../../PRD.md)
- [命令檔案](../../.claude/commands/atlas.init.md)
