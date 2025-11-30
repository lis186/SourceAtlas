# SourceAtlas

**4 個斜線命令，快速理解任何 codebase**

適用於 Claude Code | 支援 iOS/TypeScript/Android

[![Version](https://img.shields.io/badge/version-v2.6.0-blue)](https://github.com/lis186/SourceAtlas2/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

---

## 💡 解決什麼問題？

- ❌ 接手新專案，花好幾天還是看不懂架構
- ❌ 想改程式，不敢動，怕影響其他地方
- ❌ 想學習專案的設計模式，找不到好範例

**→ 用 SourceAtlas：5-15 分鐘理解專案、0.1-30 秒找範例、1-2 分鐘分析影響**

---

## 🚀 三個命令

### 1. 快速理解專案

```bash
/atlas.overview
```

**5-15 分鐘得到**：技術棧、架構模式、程式品質、專案規模

**範例**：接手一個 50K LOC 的專案，10-15 分鐘內知道它用什麼框架、MVVM 還是 Clean Architecture、測試覆蓋率多少

---

### 2. 學習設計模式

```bash
/atlas.pattern "api endpoint"
/atlas.pattern "file upload"
/atlas.pattern "authentication"
```

**0.1-30 秒找到**：2-3 個最佳範例檔案 + file:line 引用 + 實作指南

**範例**：想知道這個專案怎麼處理 API，直接找到 `UserAPI.swift:45` 和測試範例

**支援 141 個 patterns**：MVVM、Networking、Core Data、React Hook、Next.js API、Jetpack Compose、Vue Composable、Pinia、Zustand...

---

### 3. 分析程式影響

```bash
/atlas.impact "src/api/users.ts"
/atlas.impact api "/api/users/{id}"
```

**1-2 分鐘得到**：依賴清單、Breaking Changes 風險、測試影響範圍、遷移步驟

**範例**：要重構 User API，1-2 分鐘內知道 23 個檔案在用，有 5 個 breaking changes

**iOS 專案特別功能**：自動檢查 Swift/ObjC interop 風險（nullability、@objc 暴露、memory 問題）

---

## ⚡ 快速開始

### 前置需求

| 需求 | 最低版本 | 推薦版本 | 說明 |
|------|---------|---------|------|
| **Claude Code** | 0.3+ | Latest | [安裝指南](https://claude.ai/code)<br/>需支援 Slash Commands 功能 |
| **Git** | 2.0+ | 2.30+ | 版本控制工具 |
| **Bash** | 4.0+ | 5.0+ | macOS 預裝 3.2 可用，但建議升級 |
| **作業系統** | - | - | macOS 12+ 或 Linux (Ubuntu 20.04+) |

<details>
<summary><b>⚠️ 相容性注意事項</b></summary>

**Claude Code 版本需求**：
- ✅ **v0.3+**：完整支援 (Slash Commands)
- ❌ **v0.2-**：不支援（請升級）

**作業系統支援**：
- ✅ **macOS 12+** (Monterey): 完整測試
- ✅ **macOS 11** (Big Sur): 應可運作（未完整測試）
- ✅ **Linux (Ubuntu 20.04+)**: 基本支援
- ⚠️ **Linux (其他發行版)**: 可能需要調整腳本
- ❌ **Windows**: 不支援（WSL 未測試）

**Bash 版本**：
- macOS 預裝 Bash 3.2 **可以運作**，但某些功能受限
- 升級到 Bash 5.0+ 可獲得更好的效能：`brew install bash`

**專案語言支援**：
- ✅ **iOS/Swift**: 完整支援（34 patterns）
- ✅ **TypeScript/React/Vue**: 完整支援（50 patterns）
- ✅ **Android/Kotlin**: 完整支援（31 patterns）
- ✅ **Python**: 完整支援（26 patterns）
- 🔵 **Go/Rust**: 規劃中（v2.6）

</details>

### 安裝（2 分鐘）

```bash
# 1. Clone 專案
git clone https://github.com/lis186/SourceAtlas2.git ~/dev/sourceatlas2

# 2. 執行安裝
cd ~/dev/sourceatlas2 && ./install-global.sh
```

✅ 安裝一次，所有專案都能用：

```bash
cd ~/projects/any-project
/atlas.init      # 首次使用：注入自動觸發規則
/atlas.overview  # 快速理解專案
```

### 驗證安裝

```bash
# 檢查命令是否安裝成功
ls ~/.claude/commands/atlas.*.md

# 應該看到 4 個檔案：
# atlas.init.md
# atlas.overview.md
# atlas.pattern.md
# atlas.impact.md
```

📚 **完整安裝指南**：[GLOBAL_INSTALLATION.md](./GLOBAL_INSTALLATION.md)

---

## 🧭 使用決策樹

**不確定該用哪個命令？** 跟著這個流程：

```
你想做什麼？
│
├─ ⚙️ 第一次在這個專案使用 SourceAtlas
│   → 用 /atlas.init
│   → 注入自動觸發規則到 CLAUDE.md
│   → 之後 Claude 會自動建議適合的命令
│
├─ 📚 剛接手專案，想快速理解
│   → 用 /atlas.overview
│   → 5-15 分鐘得到：技術棧、架構、品質
│
├─ 🔍 想學習專案的某個實作方式
│   → 用 /atlas.pattern "關鍵字"
│   → 0.1-30 秒找到：範例檔案 + 實作指南
│   → 例如：/atlas.pattern "api endpoint"
│
├─ ⚠️ 要改程式碼，擔心影響其他地方
│   → 用 /atlas.impact "檔案或API"
│   → 1-2 分鐘得到：依賴清單 + Breaking Changes
│   → 例如：/atlas.impact "src/api/users.ts"
│
└─ ❓ 還是不確定
    → 先用 /atlas.overview 建立全貌
    → 再根據需要使用其他命令
```

**常見工作流程**：

1. **新專案入職**：`/atlas.init` → `/atlas.overview` → `/atlas.pattern` 學習關鍵模式
2. **準備重構**：`/atlas.impact` 分析影響 → 開始修改
3. **學習架構**：`/atlas.overview` → 閱讀關鍵檔案 → `/atlas.pattern` 學習細節

---

## 📖 使用文檔

### 核心文檔

- **[使用指南](./USAGE_GUIDE.md)** - 完整的命令說明、141 個 patterns、疑難排解
- **[全局安裝](./GLOBAL_INSTALLATION.md)** - 安裝選項、管理命令、疑難排解
- **[Benchmark](./BENCHMARK.md)** - 8 個真實專案的測試結果、準確率數據

### 開發者資源

- **[CLAUDE.md](./CLAUDE.md)** - AI 協作指南、專案架構、開發規範
- **[開發歷史](./dev-notes/HISTORY.md)** - 完整的演進時間線
- **[PRD](./PRD.md)** - 產品需求文檔（v2.6.0）

---

## 💬 常見問題

<details>
<summary><b>Q: 需要什麼？</b></summary>

Claude Code + 2 分鐘安裝

</details>

<details>
<summary><b>Q: 支援什麼語言？</b></summary>

- **iOS/Swift**: 29 patterns (MVVM, Coordinator, Core Data, SwiftUI...)
- **TypeScript/React**: 22 patterns (Hooks, Next.js, Server Components...)
- **Android/Kotlin**: 31 patterns (ViewModel, Room, Compose, Hilt, MVI...)

完整列表見 [USAGE_GUIDE.md](./USAGE_GUIDE.md#支援的-patterns-82-個)

</details>

<details>
<summary><b>Q: 準確嗎？</b></summary>

**在 8 個真實專案上測試**：

| 指標 | 結果 | 專案數 |
|------|------|--------|
| **Pattern 檢測** | 92-100% | 7 個 iOS 專案 |
| **Impact 分析** | 95%+ 準確率 | 4 個測試場景 |
| **Overview 理解** | 80-95% 深度 | 1 個 TypeScript 專案 |
| **專案規模** | 2K - 255K LOC | 8 個專案（127x 差距）|

**架構覆蓋**: SwiftUI, UIKit, MVVM, Clean Architecture, TCA, Redux, Swift/ObjC 混合

📊 **完整數據**: [BENCHMARK.md](./BENCHMARK.md)

</details>

<details>
<summary><b>Q: 會很慢嗎？</b></summary>

| 命令 | 時間 | 說明 |
|------|------|------|
| `/atlas.overview` | 5-15 分鐘 | 依專案大小 |
| `/atlas.pattern` | 0.1-30 秒 | 通常 <5 秒 |
| `/atlas.impact` | 1-2 分鐘 | 大型專案 2-3 分鐘 |

</details>

<details>
<summary><b>Q: 私有 codebase 可以用嗎？</b></summary>

可以！所有分析都在本地執行，但需注意：

- ⚠️ 程式碼會傳送到 Claude API 進行分析
- ⚠️ 請參考 [Anthropic 隱私政策](https://www.anthropic.com/legal/privacy)
- ✅ 可以選擇只在公開專案使用

</details>

<details>
<summary><b>Q: 什麼時候不適合用？</b></summary>

❌ **不建議使用的場景**：

1. **小型專案**（<2K LOC）- 直接閱讀更快
2. **需要 100% 精確度**（如生產決策）- 使用靜態分析工具
3. **高度敏感程式碼**（金融、醫療）- 考慮隱私政策限制
4. **離線環境** - 需要網路連接到 Claude API

✅ **適合的場景**：

- 快速理解中大型專案（>2K LOC）
- 學習專案的設計模式
- 評估技術債務和架構
- 重構前的影響分析

</details>

<details>
<summary><b>Q: 沒有 Claude Code 怎麼辦？</b></summary>

可用手動方式（見 [PROMPTS.md](./PROMPTS.md)），但建議用 Claude Code 以獲得最佳體驗。

</details>

---

## 🗺️ 開發狀態

**v2.6.0 (當前)**：5/5 核心命令完成 ✅

- ✅ `/atlas.init` - 專案初始化（自動觸發規則）
- ✅ `/atlas.overview` - 專案概覽
- ✅ `/atlas.pattern` - 設計模式學習
- ✅ `/atlas.impact` - 影響分析（靜態分析）
- ✅ `/atlas.history` - 時序分析（Git 歷史）⭐ NEW

**v2.7 (規劃中)**：Go/Rust/Ruby patterns、SourceAtlas Monitor、技術債務量化

---

## 🤝 回饋與貢獻

- 💬 **回報問題**：[GitHub Issues](https://github.com/lis186/SourceAtlas2/issues)
- 🔧 **貢獻程式**：歡迎 PR
- 🌍 **新增語言**：Python、Ruby、Go、Rust...

---

**SourceAtlas** - Claude Code 的程式分析助手
v2.6.0 | 最新更新: 2025-11-30 | MIT License

Made with ❤️ and 🤖
