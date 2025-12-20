# SourceAtlas

> 🌐 [English](./README.md) | **繁體中文**

**9 個斜線命令，快速理解任何 codebase**

適用於 Claude Code | 支援 iOS/TypeScript/Android/Python

[![Version](https://img.shields.io/badge/version-v2.9.6-blue)](https://github.com/lis186/SourceAtlas/releases)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)
[![Constitution](https://img.shields.io/badge/constitution-v1.1-purple)](./ANALYSIS_CONSTITUTION.md)

---

## 💡 解決什麼問題？

- ❌ 接手新專案，花好幾天還是看不懂架構
- ❌ 想改程式，不敢動，怕影響其他地方
- ❌ 想學習專案的設計模式，找不到好範例

**→ 用 SourceAtlas：5-15 分鐘理解專案、0.1-30 秒找範例、1-2 分鐘分析影響**

---

## 🚀 九個命令

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

**支援 221 個 patterns**：MVVM、Networking、Core Data、React Hook、Next.js API、Jetpack Compose、Vue Composable、Pinia、Zustand...

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

### 4. 時序分析（Git 歷史）

```bash
/atlas.history
/atlas.history src/
/atlas.history . 6    # 最近 6 個月
```

**5-10 分鐘得到**：Hotspots（高變動檔案）、Coupling（隱藏依賴）、Recent Contributors（知識分佈）

**範例**：想重構核心模組，5-10 分鐘內知道哪些檔案最常變動、哪些檔案總是一起改、誰最熟悉這塊程式碼

**自動處理**：
- 偵測 Shallow Clone 並提供解決方案
- 自動安裝 code-maat（首次使用）
- 識別 Bus Factor 風險（單一貢獻者）

---

### 5. 流程追蹤（資料流分析）⭐ NEW

```bash
/atlas.flow "user login"
/atlas.flow "from LoginViewController"
/atlas.flow "checkout process"
```

**3-5 分鐘得到**：入口點、執行路徑、邊界識別（API/DB/Auth/Payment）、資料流向

**範例**：想理解登入流程，3-5 分鐘內從 `LoginViewController` 追蹤到 `AuthService` → `APIClient` → `UserRepository`

**11 種分析模式**：
- 語言專屬入口點偵測（Swift, TypeScript, Kotlin, Python）
- 10 種邊界類型：API 🌐, DB 💾, Auth 🔐, Payment 💳, File 📁, Push 📲...
- 信心評分：區分高/低可信度識別結果

---

### 6. 依賴分析（升級規劃）⭐ NEW

```bash
/atlas.deps "iOS 16 → 17"
/atlas.deps "React 17 → 18"
/atlas.deps "Flask 1.x → 3.x"
/atlas.deps "kotlinx.coroutines"  # 純粹盤點
```

**3-30 分鐘得到**：可移除檢查、Deprecated APIs、新功能、第三方相容性、Migration Checklist

**範例**：要升級 iOS 17，15-30 分鐘內得到完整升級計畫：10 處版本檢查可移除、35 個 deprecated API 待更新、16 個現代化機會、40-60 小時工時預估

**核心功能**：
- **Phase 0 規則確認** - 升級前先預覽規則，可補充或調整
- **Built-in Rules** - iOS 16→17, React 17→18, Python 3.11→3.12
- **動態規則生成** - WebSearch 自動查詢最新 migration guides
- **雙模式** - 自動識別「升級分析」vs「純粹盤點」
- **Multi-module 支援** - 處理 Android 30 個 modules 專案
- **Graceful Degradation** - 即使缺少 requirements.txt 也能分析

**Production Ready** - Grade A+ (9.7/10), 100% 準確率 (42/42 樣本測試)

---

### 7. 專案初始化

```bash
/atlas.init
```

**一次設定**：注入自動觸發規則到 CLAUDE.md，之後 Claude 會自動建議適合的命令

---

### 8. 查看已儲存的分析

```bash
/atlas.list
```

**即時查看**：列出 `.sourceatlas/` 中所有快取，顯示過期狀態（⚠️ >30 天），提供可複製的重新分析命令

---

### 9. 清空快取

```bash
/atlas.clear              # 清空全部
/atlas.clear patterns     # 只清空 patterns/
```

**快取管理**：清空已儲存的分析結果，釋放空間或強制重新分析

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
- ✅ **Ruby/Rails**: 完整支援（26 patterns）
- ✅ **Go**: 完整支援（26 patterns）
- ✅ **Rust**: 完整支援（28 patterns）

</details>

### 安裝（2 分鐘）

```bash
# 1. Clone 專案
git clone https://github.com/lis186/SourceAtlas.git ~/dev/sourceatlas2

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

# 應該看到 9 個檔案：
# atlas.init.md
# atlas.overview.md
# atlas.pattern.md
# atlas.impact.md
# atlas.history.md
# atlas.flow.md
# atlas.deps.md
# atlas.list.md
# atlas.clear.md
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
├─ 📊 想了解專案的變動熱點和知識分佈
│   → 用 /atlas.history [scope]
│   → 5-10 分鐘得到：Hotspots + Coupling + Contributors
│   → 例如：/atlas.history src/
│
├─ 🔀 想追蹤某個功能的執行流程
│   → 用 /atlas.flow "描述或入口點"
│   → 3-5 分鐘得到：入口點 + 執行路徑 + 邊界
│   → 例如：/atlas.flow "user login"
│
└─ ❓ 還是不確定
    → 先用 /atlas.overview 建立全貌
    → 再根據需要使用其他命令
```

**常見工作流程**：

1. **新專案入職**：`/atlas.init` → `/atlas.overview` → `/atlas.pattern` 學習關鍵模式
2. **準備重構**：`/atlas.history` 找熱點 → `/atlas.impact` 分析影響 → 開始修改
3. **學習架構**：`/atlas.overview` → 閱讀關鍵檔案 → `/atlas.pattern` 學習細節
4. **接手 Legacy 專案**：`/atlas.history` 看熱點 + 知識分佈 → `/atlas.overview` 理解架構

---

## 📖 使用文檔

### 核心文檔

- **[使用指南](./USAGE_GUIDE.md)** - 完整的命令說明、221 個 patterns、疑難排解
- **[全局安裝](./GLOBAL_INSTALLATION.md)** - 安裝選項、管理命令、疑難排解
- **[Benchmark](./BENCHMARK.md)** - 8 個真實專案的測試結果、準確率數據

### 開發者資源

- **[CLAUDE.md](./CLAUDE.md)** - AI 協作指南、專案架構、開發規範
- **[開發歷史](./dev-notes/HISTORY.md)** - 完整的演進時間線
- **[PRD](./PRD.md)** - 產品需求文檔（v2.7.0）

---

## 💬 常見問題

<details>
<summary><b>Q: 需要什麼？</b></summary>

Claude Code + 2 分鐘安裝

</details>

<details>
<summary><b>Q: 支援什麼語言？</b></summary>

- **iOS/Swift**: 34 patterns (MVVM, Coordinator, Core Data, SwiftUI...)
- **TypeScript/React/Vue**: 50 patterns (Hooks, Next.js, Zustand, Pinia...)
- **Android/Kotlin**: 31 patterns (ViewModel, Room, Compose, Hilt, MVI...)
- **Python**: 26 patterns (Django, FastAPI, Flask, Celery...)
- **Ruby/Rails**: 26 patterns (ActiveRecord, Controller, Service, Job...)
- **Go**: 26 patterns (Handler, Service, Middleware, Transport...)
- **Rust**: 28 patterns (Handler, Service, Middleware, Runtime...)

完整列表見 [USAGE_GUIDE.md](./USAGE_GUIDE.md#支援的-patterns)

</details>

<details>
<summary><b>Q: 準確嗎？</b></summary>

**在 5 個公開開源專案上測試**：

| 指標 | 結果 | 專案 |
|------|------|------|
| **Pattern 檢測** | 73% Good, 27% Fair | 5 個專案 |
| **Swift 品質** | 100% Good | Swiftfin, WordPress-iOS |
| **執行速度** | 0.3s - 14s | 所有 patterns |
| **掃描效率** | <1.5% 檔案 | 所有專案 |

**測試專案**: [Swiftfin](https://github.com/jellyfin/Swiftfin), [WordPress-iOS](https://github.com/wordpress-mobile/WordPress-iOS), [Signal-Android](https://github.com/signalapp/Signal-Android), [AntennaPod](https://github.com/AntennaPod/AntennaPod), [FastAPI](https://github.com/tiangolo/fastapi)

📊 **完整數據**: [BENCHMARK.md](./BENCHMARK.md)

</details>

<details>
<summary><b>Q: 會很慢嗎？</b></summary>

| 命令 | 時間 | 說明 |
|------|------|------|
| `/atlas.overview` | 5-15 分鐘 | 依專案大小 |
| `/atlas.pattern` | 0.1-30 秒 | 通常 <5 秒 |
| `/atlas.impact` | 1-2 分鐘 | 大型專案 2-3 分鐘 |
| `/atlas.history` | 5-10 分鐘 | 依 Git 歷史大小 |

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

<details>
<summary><b>Q: 分析結果可以儲存嗎？</b></summary>

**可以！** 所有分析命令支援 `--save` 參數：

```bash
/atlas.overview --save           # 儲存至 .sourceatlas/overview.yaml
/atlas.pattern "api" --save      # 儲存至 .sourceatlas/patterns/api.md
/atlas.flow "login" --save       # 儲存至 .sourceatlas/flows/login.md
/atlas.history --save            # 儲存至 .sourceatlas/history.md
/atlas.impact "User" --save      # 儲存至 .sourceatlas/impact/user.md
/atlas.deps "react" --save       # 儲存至 .sourceatlas/deps/react.md
```

**清空已儲存的分析**：

```bash
/atlas.clear              # 清空全部
/atlas.clear patterns     # 只清空 patterns/
```

**用途**：
- 📝 保留分析結果供日後參考
- 👥 新成員可以直接閱讀已有分析
- 🔄 避免重複執行相同分析

</details>

---

## 📜 分析憲法 (Constitution)

**v2.8.0 新增**：所有分析命令遵循 [ANALYSIS_CONSTITUTION.md](./ANALYSIS_CONSTITUTION.md)

### 核心原則

| 原則 | 說明 |
|------|------|
| **資訊理論** | 高熵優先、掃描比例上限（TINY 50%, LARGE 5%） |
| **排除原則** | 強制排除 node_modules, .venv, build 等 |
| **假設原則** | 結構化假設 + 信心等級 + 證據引用 |
| **證據原則** | `file:line` 精確引用，禁止無證據論點 |
| **Handoffs** | 發現驅動的動態下一步建議（v1.1 新增） |

### 驗證工具

```bash
# 檢查分析輸出是否符合 Constitution
bash scripts/atlas/validate-constitution.sh <分析輸出.yaml>

# 檢查專案結構合規性
bash scripts/atlas/validate-constitution.sh --check-structure
```

### 實測指標

| 指標 | 數值 |
|------|------|
| file:line 引用 | 每次分析 12 個 |
| 驗證成本 | 自動 1 秒 |
| 輸出行數 | ~133 行 |

---

## 🗺️ 開發狀態

**v2.9.4 (當前)**：AI 協作偵測 - 支援 12+ AI 工具 ✅

- ✅ `/atlas.init` - 專案初始化（自動觸發規則）
- ✅ `/atlas.overview` - 專案概覽
- ✅ `/atlas.pattern` - 設計模式學習
- ✅ `/atlas.impact` - 影響分析（靜態分析）
- ✅ `/atlas.history` - 時序分析（Git 歷史）
- ✅ `/atlas.flow` - 流程追蹤（資料流分析）
- ✅ `/atlas.deps` - 依賴分析（升級規劃）⭐ NEW
- ✅ `/atlas.list` - 查看已儲存的分析 ⭐ NEW
- ✅ `/atlas.clear` - 清空快取
- ✅ **持久化 v2.0** - `--save` 參數、30 天過期警告、告知式快取

**v3.0 (規劃中)**：Go/Rust/Ruby patterns、AST 分析整合、SourceAtlas Monitor

---

## 🤝 回饋與貢獻

- 💬 **回報問題**：[GitHub Issues](https://github.com/lis186/SourceAtlas/issues)
- 🔧 **貢獻程式**：歡迎 PR
- 🌍 **新增語言**：Python、Ruby、Go、Rust...

---

**SourceAtlas** - Claude Code 的程式分析助手
v2.9.4 | 最新更新: 2025-12-19 | MIT License

Made with ❤️ and 🤖
