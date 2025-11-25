# SourceAtlas

** 3 個斜線命令，快速理解任何 codebase **

適用於 Claude Code | 支援 iOS/TypeScript/Android

---

## 💡 能幫你做什麼？

- ❌ 接手新專案，花好幾天還是看不懂架構
- ❌ 想改程式，不敢動，怕影響其他地方
- ❌ 想學習專案的設計模式，找不到好範例

**→ 用 SourceAtlas：5-15 分鐘理解專案、0.1-30 秒找範例、1-2 分鐘分析影響**

---

## 🚀 三個命令

### 1. 快速理解專案

```bash
/atlas-overview
```

**5-15 分鐘得到**：技術棧、架構模式、程式品質、專案規模

**範例**：接手一個 50K LOC 的專案，10-15 分鐘內知道它用什麼框架、MVVM 還是 Clean Architecture、測試覆蓋率多少

---

### 2. 學習設計模式

```bash
/atlas-pattern "api endpoint"
/atlas-pattern "file upload"
/atlas-pattern "authentication"
```

**0.1-30 秒找到**：2-3 個最佳範例檔案 + file:line 引用 + 實作指南

**範例**：想知道這個專案怎麼處理 API，直接找到 `UserAPI.swift:45` 和測試範例

**支援 71 個 patterns**：MVVM、Networking、Core Data、React Hook、Next.js API...

---

### 3. 分析程式影響

```bash
/atlas-impact "src/api/users.ts"
/atlas-impact api "/api/users/{id}"
```

**1-2 分鐘得到**：誰在用、會不會 breaking、要改哪些測試、遷移步驟

**範例**：要重構 User API，1-2 分鐘內知道 23 個檔案在用，有 5 個 breaking changes

**iOS 專案特別功能**：自動檢查 Swift/ObjC interop 風險（nullability、@objc 暴露、memory 問題）

---

## 🔧 前置需求

- **Claude Code** - [安裝指南](https://claude.ai/code)
- **Git** - 版本控制工具
- **macOS/Linux** - 目前支援的平台

---

## 📦 安裝

**完整安裝指南**：[GLOBAL_INSTALLATION.md](./GLOBAL_INSTALLATION.md)

### 快速安裝（2 分鐘）

```bash
git clone https://github.com/lis186/SourceAtlas2.git ~/dev/sourceatlas2
cd ~/dev/sourceatlas2 && ./install-global.sh
```

安裝一次，所有專案都能用：

```bash
cd ~/projects/any-project
/atlas-overview
```

---

## 💬 常見問題

**Q: 需要什麼？**
A: Claude Code + 2 分鐘安裝

**Q: 支援什麼語言？**
A: iOS/Swift (29 patterns)、TypeScript/React (22)、Android/Kotlin (20)

**Q: 準確嗎？**
A: Pattern 準確率 92-100%、Impact 分析 4.2/5 星（8 個專案測試）

**Q: 會很慢嗎？**
A: `/atlas-overview` 10-15 分鐘、`/atlas-pattern` 0.1 秒、`/atlas-impact` 1-2 分鐘

**Q: 私有 codebase 可以用嗎？**
A: 可以！所有分析都在本地執行

**Q: 什麼時候不適合用？**
A:
- 小型專案（<2K LOC）- 直接閱讀更快
- 需要 100% 精確度（如生產決策）- 使用靜態分析工具
- 敏感代碼庫 - 需要考慮 Claude API 隱私政策

**Q: 沒有 Claude Code 怎麼辦？**
A: 可用手動方式（見 [PROMPTS.md](./PROMPTS.md)），但建議用 Claude Code

---

## 📚 更多資訊

**使用說明**：[USAGE_GUIDE.md](./USAGE_GUIDE.md)
**開發歷史**：[dev-notes/HISTORY.md](./dev-notes/HISTORY.md)
**技術細節**：[CLAUDE.md](./CLAUDE.md)

---

## 🗺️ 命令完成度

**v2.5 (當前)**：3/5 命令完成

- ✅ `/atlas-overview` - 專案概覽
- ✅ `/atlas-pattern` - 設計模式
- ✅ `/atlas-impact` - 影響分析
- 🔵 `/atlas-find` - 智慧搜尋（開發中）
- 🔵 `/atlas-explain` - 深入解釋（開發中）

**v3.0 (規劃中)**：Python/Ruby/Go Analyzer、更多 patterns、技術債務量化

---

## 🤝 回饋與貢獻

- 回報問題：[GitHub Issues](https://github.com/lis186/SourceAtlas2/issues)
- 貢獻程式：歡迎 PR
- 新增語言：Python、Ruby、Go、Rust...

---

**SourceAtlas** - Claude Code 的程式分析助手
v2.5 | 最新更新: 2025-11-25 | MIT License

Made with ❤️ and 🤖
