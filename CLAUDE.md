# CLAUDE.md

本檔案為 Claude Code (claude.ai/code) 在此 codebase 工作時提供指導。

## 專案總覽

**SourceAtlas** 是一個專為 AI 優化的 codebase 分析工具，設計用於快速理解任何 codebase，通過掃描少於 5% 的檔案即可達到 70-95% 的理解深度。它使用資訊理論原則，優先處理高熵檔案（配置、文檔、模型）而非實作細節。

**核心創新**：三階段分析框架，相比傳統程式碼審查方法節省 95%+ 的時間和 token。

**當前狀態**：
- **v1.0** ✅ - 方法論驗證完成（2025-11-22）
- **v2.7.0** ✅ - Commands 架構完成，含流程追蹤（2025-12-01）
- **v2.8.0** ✅ - Constitution v1.0 + Monorepo 支援（2025-12-05）
- **v2.8.1** ✅ - Constitution v1.1 + Handoffs 原則（2025-12-06）
- **v2.9.0** ✅ - Dependency Analysis `/atlas.deps` 完成測試（2025-12-12）
- **v2.9.1** ✅ - 持久化 v2.0：30 天過期警告、Handoffs 互斥規則（2025-12-13）
- **v2.9.2** ✅ - `/atlas.list` 過期標記增強、`/atlas.init` 驗證機制（2025-12-13）

## 架構

### 三階段分析流程

系統使用漸進式分析方法：

1. **Stage 0: 專案指紋** (~10-15 分鐘, ~20k tokens)
   - 掃描 <5% 檔案達到 70-80% 理解
   - 識別技術棧、架構模式、業務領域
   - 生成 10-15 個待驗證假設
   - 輸出格式：`.yaml` (v1.0 決策：YAML > TOON，生態系統優先)

2. **Stage 1: 假設驗證** (~20-30 分鐘, ~30k tokens)
   - 系統化驗證 Stage 0 的假設
   - 達到 85-95% 理解深度
   - 為每個假設記錄證據
   - 輸出格式：`.md`

3. **Stage 2: Git 熱點分析** (~15-20 分鐘, ~20k tokens)
   - 分析 commit 歷史和檔案變動頻率
   - 識別開發模式和 AI 協作程度
   - 重建專案時間線
   - 輸出格式：`.md`

### 核心設計原則

> ⚠️ **重要**：分析行為的完整原則定義在 [ANALYSIS_CONSTITUTION.md](./ANALYSIS_CONSTITUTION.md)。
> 本節僅為摘要，Constitution 為權威來源。

**資訊理論基礎**（詳見 Constitution Article I）：

- 高熵檔案（configs、READMEs、models）包含不成比例的大量資訊
- 結構 > 實作細節，更適合快速理解
- 漸進式精煉勝過窮舉式掃描
- 掃描比例上限：TINY 50%, SMALL 20%, MEDIUM 10%, LARGE 5%, VERY_LARGE 3%

**格式選擇** (v1.0 決策)：

- **YAML** 為主要格式（標準生態系統 > 14% token 優化）
- TOON 格式已評估但未採用（詳見 `dev-notes/toon-vs-yaml-analysis.md`）
- 用於 Stage 0 輸出：`.yaml`
- 用於 Stage 1-2 輸出：`.md`

## 目錄結構

```
sourceatlas2/
├── README.md               # 使用者文檔（中文）
├── CLAUDE.md               # 本檔案 - AI 協作指南（開發 SourceAtlas）
├── ANALYSIS_CONSTITUTION.md # ⭐ 分析憲法 - 分析行為的不可變原則
├── PROMPTS.md              # 所有 3 個階段的完整 prompt 模板
├── PRD.md                  # 產品需求（v2.7 Commands 架構）
├── USAGE_GUIDE.md          # 詳細使用說明
├── GLOBAL_INSTALLATION.md  # 全局安裝指南
│
├── .claude/commands/       # Claude Code 斜線命令
│   ├── atlas.overview.md   # ✅ /atlas.overview (Stage 0)
│   └── atlas.pattern.md    # ✅ /atlas.pattern (Pattern Learning)
│
├── scripts/                # 分析腳本
│   ├── atlas/              # ⭐ Atlas 命令核心腳本
│   └── install-global.sh   # ⭐ 全局安裝腳本
│
├── proposals/              # ✅ 功能提案（未實作功能）⭐
│   ├── README.md           # 提案索引
│   └── code-maat-integration/  # code-maat 整合設計 (已實作於 v2.6)
│       ├── SOURCEATLAS_CODEMAAT_INTEGRATION.md
│       ├── CODE_MAAT_FORMAT_CHEATSHEET.md
│       ├── PERFORMANCE_CONSIDERATIONS.md
│       └── UPDATES_SUMMARY.md
│
├── examples/               # ✅ 外部參考專案（學習用）⭐
│   └── README.md           # 說明和推薦專案（專案本身被 git ignore）
│
├── dev-notes/              # ✅ 開發記錄與方法論 ⭐
│   ├── README.md           # SourceAtlas 知識庫索引
│   ├── HISTORY.md          # 按時間線查看專案演進
│   ├── KEY_LEARNINGS.md    # 核心學習與發現
│   ├── METHODOLOGY.md      # 開發方法論
│   ├── ROADMAP.md          # 未來規劃
│   ├── 2025-11/            # 月度實作記錄
│   └── archives/           # 歷史存檔
│
├── ideas/                  # ✅ 實驗性想法（草稿筆記）⭐
│   └── README.md           # 使用說明和當前探索
│
├── test_targets/           # 測試專案（git ignore）
└── test_results/           # 分析輸出（git ignore）
```

## 安裝與使用

### 全局安裝（推薦）⭐

**一次安裝，隨處可用**：

```bash
# 從 SourceAtlas 專案根目錄執行
./install-global.sh

# 現在可以在任何專案使用
cd ~/projects/any-project
/atlas.overview
/atlas.pattern "api endpoint"
```

**安裝方式**：
- **預設（Symlink）**：自動同步更新，推薦日常使用
- **Copy 方式**：`INSTALL_METHOD=copy ./install-global.sh`，適合需要穩定版本

**管理命令**：
- `./install-global.sh --check` - 檢查安裝狀態
- `./install-global.sh --remove` - 解除安裝

📚 **完整指南**：見 [GLOBAL_INSTALLATION.md](./GLOBAL_INSTALLATION.md)

### 使用分析 Prompts

#### 何時執行分析

在以下情況執行 SourceAtlas 分析：

- 接手新的 codebase
- 進行程式碼審查或技術盡職調查
- 評估開發者候選人的 GitHub 專案
- 學習開源專案
- 評估 AI 協作成熟度

### Stage 選擇指南

- **<500 LOC**：跳過 SourceAtlas，直接閱讀
- **500-2000 LOC**：使用 Stage 0-1
- **>2000 LOC 且有 Git 歷史**：使用全部 3 個階段

### 執行分析

**v1.0 方式**（手動 Prompts）：
1. 從 `PROMPTS.md` 複製相關階段的 prompt
2. 將 `[PROJECT_PATH]` 替換為實際路徑
3. 以指定格式生成輸出（Stage 0 用 .yaml，Stage 1-2 用 .md）

**v2.9.0 方式**（Commands）：
- `/atlas.init` ✅ - 專案初始化，注入自動觸發規則（已實作，2025-11-30）
- `/atlas.overview` ✅ - Stage 0 專案指紋（已實作，2025-11-20）【支援 `--save`】
- `/atlas.pattern` ✅ - 學習設計模式（已實作，2025-11-22）【支援 `--save`】
- `/atlas.impact` ✅ - 影響範圍分析（已實作，2025-11-25）【支援 `--save`】
- `/atlas.history` ✅ - 時序分析（Git 歷史）（已實作，2025-11-30）【支援 `--save`】
- `/atlas.flow` ✅ - 流程追蹤與資料流分析（已實作，2025-12-01）【支援 `--save`】
- `/atlas.deps` ✅ - Dependency 分析（已完成測試，2025-12-12）【支援 `--save`】
- `/atlas.list` ✅ - 列出已儲存的分析結果（2025-12-13）⭐ NEW
- `/atlas.clear` ✅ - 清空已儲存的分析結果（2025-12-12）

**持久化功能**：
- 加入 `--save` 參數可將分析結果儲存至 `.sourceatlas/` 目錄
- 範例：`/atlas.pattern "repository" --save` → 儲存至 `.sourceatlas/patterns/repository.md`
- 使用 `/atlas.clear` 清空已儲存的分析結果
- 使用 `/atlas.list` 查看已儲存的分析結果
- 已儲存的分析會自動作為快取，下次執行相同命令時直接載入
- 加入 `--force` 參數可跳過快取，強制重新分析

### 使用專案記憶（.sourceatlas/）

**觸發條件**：當使用者問題涉及以下情境時，主動查詢 `.sourceatlas/`：
- 專案層級問題：「這專案」「這個 codebase」「專案架構」「整體」「全貌」
- 延續之前分析：「之前分析」「上次」「我們討論過」
- 明確要求概覽：「overview」「summarize」「給我背景」

**動作**：
1. 執行 `ls .sourceatlas/ 2>/dev/null` 檢查是否存在
2. 如果存在，優先讀取 `overview.yaml`（專案全貌）
3. 根據問題內容，判斷是否需要讀取其他快取：
   - Pattern 相關 → `.sourceatlas/patterns/`
   - 依賴相關 → `.sourceatlas/deps/`
   - 歷史相關 → `.sourceatlas/history.md`
   - 影響分析 → `.sourceatlas/impact/`
   - 流程相關 → `.sourceatlas/flows/`

**不觸發**（避免不必要的 token 成本）：
- 「幫我改這個 bug」→ 直接改，不需要快取
- 「這個 function 做什麼」→ 直接讀原始碼
- 「執行測試」→ 直接執行，不需要背景

**完整三階段分析**（罕見場景）：
針對深度盡職調查（評估開源專案、招聘評估、技術盡調），使用 `PROMPTS.md` 手動執行 Stage 0-1-2

**重要**：Stage prompts 彼此依賴。務必先完成 Stage 0 再做 Stage 1，先完成 Stage 1 再做 Stage 2。

## AI 協作檢測

SourceAtlas 的獨特能力之一是識別 AI 輔助開發模式：

### AI 協作成熟度模型

- **Level 0**：無 AI（傳統開發）
- **Level 1-2**：基礎 AI 使用（偶爾使用工具）
- **Level 3**：系統化 AI 協作 ⭐
  - 有 `CLAUDE.md` 或類似的 AI 配置
  - 15-20% 註解密度（相比人工的 5-8%）
  - 98%+ 程式碼一致性
  - 100% Conventional Commits
  - 文檔/程式碼比 >1:1
- **Level 4**：生態級別（團隊級 AI 整合）

**關鍵指標**：尋找 CLAUDE.md、.cursor/rules/、高註解密度、完美的 commit 訊息一致性和豐富的文檔。

## 檔案格式

### YAML 格式 (.yaml)

用於 Stage 0 輸出（v1.0 決策）。主要特性：

- 標準 YAML 語法（廣泛生態系統支援）
- 結構化區段：專案指紋、假設、掃描檔案
- 所有推論的信心等級（0.0-1.0）
- 相比 TOON 僅多 14% tokens，但換取標準工具支援

範例結構：

```yaml
metadata:
  project_name: example
  scan_time: "2025-11-22T10:00:00Z"
  total_files: 500
  scanned_files: 12
  scan_ratio: "2.4%"

project_fingerprint:
  project_type: WEB_APP
  scale: MEDIUM
  # ...additional fields

hypotheses:
  architecture:
    - hypothesis: "Uses JWT authentication"
      confidence: 0.75
      evidence: "Found jwt dependency, auth middleware present"
```

**為什麼選擇 YAML 而非 TOON？**
- 標準格式 > 自訂格式（極簡哲學）
- 14% token 差異屬於邊際效益
- 完整分析見 `dev-notes/toon-vs-yaml-analysis.md`

### Markdown 報告 (.md)

用於 Stage 1-2 輸出：

- 標準 GitHub-flavored markdown
- 用表格呈現結構化資料
- 用程式碼區塊呈現證據
- 清晰的章節標題

## 輸出要求

### 信心等級

始終包含推論的信心等級：

- **0.0-0.5**：低信心（需要驗證）
- **0.5-0.7**：中等信心
- **0.7-0.85**：高信心
- **0.85-1.0**：非常高信心（幾乎確定）

### 基於證據的分析

每個論點都必須有證據支持：

- 相關時包含行號的檔案路徑
- Shell 命令輸出
- 文檔的直接引用
- 統計分析（檔案數量、commit 模式等）

## 需要識別的常見模式

### 架構模式

- **MVC/MVVM**：尋找 models/、views/、controllers/ 或 viewmodels/
- **微服務**：多個服務目錄、docker-compose.yml、API gateway
- **Monorepo**：package.json 中的 workspaces、多個 package.json 檔案
- **Clean Architecture**：分層分離（domain/、infrastructure/、application/）

### 技術棧指標

- `package.json` → Node.js/TypeScript/JavaScript
- `composer.json` → PHP/Laravel
- `Cargo.toml` → Rust
- `go.mod` → Go
- `*.csproj` → C#/.NET
- `requirements.txt`/`pyproject.toml` → Python

### 開發者能力信號

- **測試覆蓋率 >90%**：專業/專家級別
- **無測試**：初學者或快速原型
- **有 CLAUDE.md**：系統化 AI 協作
- **只有 1-2 個 commits**：糟糕的 Git 習慣（初學者）
- **Conventional Commits**：良好的開發實踐

## 語言和本地化

### 核心原則：台灣用語優先 ⭐

**重要**：所有文檔必須使用**台灣繁體中文**術語，避免中國大陸用語。

| 正確（台灣） | 錯誤（中國） | 英文替代 |
|------------|------------|---------|
| 程式碼 | 代碼 | code |
| 軟體 | 软件 | software |
| 資料庫 | 数据库 | database |
| 網路 | 网络 | network |
| 伺服器 | 服务器 | server |
| codebase | 代碼庫 | codebase |

**語言使用規範**：
- 主要文檔使用繁體中文（zh-TW，**台灣用語**）
- 程式碼和技術術語使用英文
- **當不確定台灣用語時，直接使用英文原文**（如：codebase, commit, repository）
- 生成報告時，匹配專案的主要語言
- 使用者文檔（README、USAGE_GUIDE）使用台灣繁體中文
- 技術規格（PRD、PROMPTS）混合使用中英文

## 版本控制

**版本號說明**：
- **SourceAtlas 產品版本**（如 v2.6.0）：追蹤整個產品的開發階段
- **提案文檔版本**（如 proposals/ 下的 v3.0）：追蹤個別提案的設計變更

**當前產品版本**：
- **v1.0** ✅ - 方法論驗證完成（2025-11-22）
- **v2.7.0** ✅ - Flow 分析完成（2025-12-01）

**版本歷程**（詳見 `dev-notes/HISTORY.md`）：
- v2.7.0 (2025-12-01): `/atlas.flow` - 流程追蹤
- v2.6.0 (2025-11-30): `/atlas.history` - 時序分析
- v2.5.x (2025-11-30): 多語言 Patterns（141 patterns）
- v1.0 (2025-11-22): 方法論驗證完成

### 忽略的目錄

- `test_targets/` - 用於驗證的克隆 codebase（大型，不追蹤到 git）
- `test_results/` - 生成的分析輸出（可以重新生成）
- `examples/*` - clone 的參考專案（僅追蹤 README.md）

這些被 git 忽略以保持 codebase 精簡，同時保護測試專案的隱私。

## 開發工作流程

### Git 和版本控制

- **絕對不要使用 `git commit` 命令** - GitButler 正在使用其內部流程和 `but` CLI hooks 自動管理所有 commits 和分支
- **專注於編寫乾淨的程式碼和測試** - 不要擔心 commits 或分支
- **當任務完成時，停止工作**並允許 GitButler hooks 執行後處理命令

此工作流程確保功能的清晰分離，並允許 GitButler 自動組織 commits 和分支，無需手動介入。

## v1.0 關鍵學習（必讀！）

**2025-11-22 完成的 v1.0 驗證揭示了 6 個關鍵洞察**：

1. ✅ **資訊理論確實有效** - <5% 掃描達 70-80% 理解（5/5 專案驗證）
2. ⭐ **規模感知至關重要** - TINY/SMALL/MEDIUM/LARGE/VERY_LARGE 需要不同策略
3. ⭐ **YAML > TOON** - 標準生態系統 > 14% token 節省
4. ✅ **必須排除 .venv/node_modules** - 避免虛增檔案數量
5. ✅ **基準測試揭示真相** - 在真實專案測試，不只是理論
6. ✅ **AI 協作模式可檢測** - Level 0-4 成熟度模型

> **詳細分析與證據**：見 [dev-notes/KEY_LEARNINGS.md](./dev-notes/KEY_LEARNINGS.md) 和 [dev-notes/HISTORY.md](./dev-notes/HISTORY.md)

**實作任何新功能時，謹記這些學習！**

---

## iOS Patterns 擴展（v2.5.1）✅

**2025-11-23 完成的 iOS patterns 全面擴展**：

### 成果總結

- ✅ **新增 18 個 iOS patterns**（10 Tier 1 + 8 Tier 2）
- ✅ **Pattern 總數**: 16 → 34 (+112.5%)
- ✅ **測試專案**: 7 個 iOS 專案（2K ~ 255K LOC）
- ✅ **檔案檢測**: 152+ 檔案
- ✅ **整體準確率**: 92%+
- ✅ **架構覆蓋**: SwiftUI, UIKit, TCA, Redux, Clean Architecture

### 關鍵技術發現⭐

1. **DIContainer 是現代 Factory pattern** - Clean Architecture 專案使用 `*DIContainer.swift` 而非 `*Factory.swift`
2. **TCA 使用 *Domain.swift** - The Composable Architecture 使用 `@Reducer` macro 搭配 `*Domain.swift` 命名
3. **Middleware 是 Redux 架構專用** - Clean Architecture 使用 Use Cases，MVVM 使用 ViewModels
4. **現代 iOS 趨勢（2025）**:
   - `@Observable` > `ObservableObject`
   - `async/await` > Combine
   - 無 ViewModels（純 SwiftUI）

### 新增的 Patterns

**Tier 1 核心（10 個）**:
1. Protocol/Delegate（UIKit 通訊）
2. Combine/Publisher（Reactive）⚠️ 需內容分析
3. async/await（並發）⚠️ 需內容分析
4. Repository（資料抽象）
5. Service Layer（業務邏輯）
6. Use Case/Interactor（領域操作）
7. UICollectionViewLayout（自訂佈局）
8. Factory/DIContainer（物件創建）
9. Animation（UI 動畫）
10. Router（路由管理）

**Tier 2 補充（8 個）**:
11. ObservableObject（SwiftUI 狀態）
12. Reducer (TCA)（Redux-like）
13. Environment/Configuration（環境配置）
14. Cache（快取管理）
15. Theme/Style（主題樣式）
16. Mock/Stub（測試基礎）
17. Middleware（Redux 中介層）
18. Localization（國際化）

### 文檔產出

所有文檔位於 `test_targets/ios-*.md`:
1. `ios-patterns-expansion-research-report.md` - 研究報告
2. `ios-tier1-phase1-implementation-report.md` - Week 1 實作
3. `ios-tier1-phase1-week2-implementation-report.md` - Week 2 實作
4. `ios-tier2-implementation-report.md` - Tier 2 實作
5. `ios-patterns-expansion-complete-report.md` - 完整總結

### 方法論傳承

基於此次實戰，建立了可重複使用的框架：
- **[dev-notes/archives/lessons/new-language-support-methodology.md](./dev-notes/archives/lessons/new-language-support-methodology.md)** - 6 階段系統化方法論
- 適用於未來新增任何程式語言支援（Kotlin, Go, Rust, Flutter 等）
- 包含完整檢查清單、快速啟動腳本、品質標準

> **詳細報告**：見 `test_targets/ios-patterns-expansion-complete-report.md`

---

## Kotlin/Android Patterns（v2.5.2）✅

**2025-11-30 完成的 Kotlin/Android patterns 支援**：

### 成果總結

- ✅ **31 個 patterns**（12 Tier 1 + 19 Tier 2）
- ✅ **測試專案**: 8 個 Kotlin 專案（817 ~ 32K LOC）
- ✅ **整體準確率**: 95%+
- ✅ **架構覆蓋**: MVVM, MVI, Clean Architecture, Circuit

### 關鍵技術發現⭐

1. **Circuit library 使用 Presenter 模式** - `*Presenter.kt` 取代 `*ViewModel.kt`
2. **Compose 使用 Component 模式** - `*Component.kt` 取代 `*Screen.kt`
3. **MVI 需要額外 patterns** - `*UiState.kt`, `*Intent.kt`, `*Effect.kt`
4. **SQLDelight 取代 Room** - Kotlin Multiplatform 專案使用 SQLDelight
5. **大型專案使用更多 patterns** - Factory, Provider, Contract, Config 等在生產級 App 很常見

### Tier 1 核心 Patterns（12 個）

| Pattern | 別名 | 檔案模式 |
|---------|------|----------|
| ViewModel | presenter, mvvm | `*ViewModel.kt`, `*Presenter.kt` |
| Repository | repo | `*Repository.kt`, `*DataSource.kt` |
| UseCase | interactor | `*UseCase.kt`, `*Interactor.kt` |
| DAO | room, database | `*Dao.kt`, `*Entity.kt`, `*Database.kt` |
| DI Module | hilt, dagger | `*Module.kt`, `*Component.kt` |
| API | retrofit, network | `*Api.kt`, `*ApiService.kt` |
| Compose | screen | `*Screen.kt`, `*Component.kt` |
| State | uistate, stateflow | `*State.kt`, `*UiState.kt`, `*Intent.kt` |
| Adapter | recyclerview | `*Adapter.kt`, `*ViewHolder.kt` |
| Fragment | - | `*Fragment.kt` |
| Activity | - | `*Activity.kt` |
| Navigation | nav | `*Navigator.kt`, `*Directions.kt` |

### Tier 2 補充 Patterns（19 個）

| Pattern | 別名 | 用途 |
|---------|------|------|
| Service | - | 背景服務 |
| Receiver | broadcast | 廣播接收 |
| Mapper | converter | 資料轉換 |
| Sealed | result, resource | 密封類狀態 |
| Extension | ext | Kotlin 擴展函數 |
| Binding | viewbinding, databinding | 視圖綁定 |
| Singleton | object, manager | 單例管理 |
| Worker | workmanager, background | 背景任務 |
| Test | mock, fake, stub | 測試相關 |
| Store | redux, mvi | 狀態管理 |
| Factory | builder, creator | 物件創建 |
| Provider | content provider | 內容提供 |
| Contract | interface | 介面契約 |
| Config | settings, preferences | 配置設定 |
| Validator | validation | 驗證邏輯 |
| Parser | serializer | 解析序列化 |
| Formatter | format | 格式化 |
| Loader | fetcher | 資料載入 |
| Listener | callback, handler | 事件監聽 |

### 測試專案

| 專案 | 規模 | 檔案數 | 架構 |
|------|------|--------|------|
| Android App 1 | Large | 303 | Clean + MVVM |
| Android App 2 | Large | 629 | Circuit/MVI (KMP) |
| Android App 3 | Small | 56 | MVVM |
| Android App 4 | Small | 27 | MVVM |
| Android App 5 | Small | 20 | MVVM + Compose |
| Android App 6 | Very Large | 3,131 | 生產級郵件客戶端 |
| Android App 7 | Medium | 475 | 視頻串流 |
| Android App 8 | Medium | 596 | Podcast App |

> **詳細報告**：見 [dev-notes/2025-11/2025-11-30-kotlin-patterns-implementation-report.md](./dev-notes/2025-11/2025-11-30-kotlin-patterns-implementation-report.md)

---

## Python Patterns（v2.5.3）✅

**2025-11-30 完成的 Python patterns 支援**：

### 成果總結

- ✅ **26 個 patterns**（12 Tier 1 + 14 Tier 2）
- ✅ **測試專案**: 10 個 Python 專案（60 ~ 2884 files）
- ✅ **框架覆蓋**: Django, FastAPI, Flask, Celery, Scrapy, Pydantic, SQLAlchemy, Starlette

### 關鍵技術發現⭐

1. **Python 專案常有 package.json** - Django 等專案有前端資源，需調整檢測順序（Python 優先於 TypeScript）
2. **Django 使用特定檔案命名** - `models.py`, `views.py`, `admin.py`, `urls.py` 等
3. **Starlette/FastAPI 使用 routing.py** - 需同時支援 `routes.py` 和 `routing.py`
4. **Scrapy 有特殊模式** - `pipelines.py`, `spiders.py`
5. **框架專案 vs 應用專案** - 框架專案較少使用 service/repository 模式

### Tier 1 核心 Patterns（12 個）

| Pattern | 別名 | 檔案模式 |
|---------|------|----------|
| Model | models, orm, django model | `models.py`, `*model.py` |
| View | views, django view, endpoint | `views.py`, `*view.py` |
| Serializer | schema, pydantic, marshmallow | `*serializers.py`, `*schema.py` |
| Service | services, business logic | `*service.py`, `*services.py` |
| Repository | repo, data access | `*repository.py`, `*repo.py` |
| API | router, routing, fastapi, flask, routes, urls | `*router.py`, `*routing.py`, `urls.py` |
| Form | forms, django form | `forms.py`, `*form.py` |
| Task | celery, background job, worker | `tasks.py`, `*celery.py` |
| Test | tests, pytest, unittest | `test_*.py`, `conftest.py` |
| Admin | django admin | `admin.py` |
| Middleware | middlewares | `*middleware.py` |
| Config | settings, configuration | `settings.py`, `*config.py` |

### Tier 2 補充 Patterns（14 個）

| Pattern | 別名 | 用途 |
|---------|------|------|
| Migration | migrations, alembic | 資料庫遷移 |
| Command | management command, cli | CLI 命令 |
| Util | utils, helpers | 工具函數 |
| Exception | exceptions, errors | 例外處理 |
| Validator | validators, validation | 驗證邏輯 |
| Factory | factories, factory boy | 測試工廠 |
| Fixture | fixtures, test data | 測試資料 |
| Signal | signals, django signal | Django 信號 |
| Manager | managers, django manager | Django Manager |
| Mixin | mixins | 混入類 |
| Decorator | decorators | 裝飾器 |
| Client | http client, api client | HTTP 客戶端 |
| Pipeline | pipelines, scrapy pipeline | Scrapy 管線 |
| Spider | spiders, scrapy, crawler | Scrapy 爬蟲 |

### 測試專案

| 專案 | Python 檔案數 | 類型 |
|------|--------------|------|
| Django | 2,884 | Web 框架 |
| FastAPI | 1,190 | API 框架 |
| SQLAlchemy | 656 | ORM |
| Celery | 410 | 任務佇列 |
| Scrapy | 410 | 爬蟲框架 |
| Pydantic | 396 | 資料驗證 |
| Flask | 83 | Web 框架 |
| Cookiecutter-Django | 70 | 專案模板 |
| Starlette | 67 | ASGI 框架 |
| httpx | 60 | HTTP 客戶端 |

---

## TypeScript/React/Vue Patterns（v2.5.4）✅

**2025-11-30 完成的前端生態系統 patterns 擴展**：

### 成果總結

- ✅ **50 個 patterns**（25 Tier 1 + 25 Tier 2）
- ✅ **測試專案**: 7+ 個前端專案
- ✅ **框架覆蓋**: React, Vue, Next.js, Nuxt, Zustand, Pinia, TanStack Query, Framer Motion

### 關鍵技術發現⭐

1. **React 生態系統趨勢（2025）**:
   - Zustand 取代 Redux 成為首選狀態管理
   - TanStack Query 用於伺服器狀態
   - Framer Motion 成為動畫標準
   - Server Components 改變架構模式
2. **Vue 生態系統趨勢**:
   - Pinia 取代 Vuex
   - Composables 取代 Options API
   - VueUse 提供豐富的 utility composables
3. **組織模式差異**:
   - React: `hooks/`, `components/`, `store/`
   - Vue: `composables/`, `components/`, `stores/`

### React Tier 1 Patterns（18 個）

| Pattern | 別名 | 用途 |
|---------|------|------|
| React Component | component | 組件定義 |
| React Hook | hook, hooks, custom hook | 自訂 Hook |
| State Management | store, state, zustand, redux | 狀態管理 |
| API Endpoint | api, endpoint, trpc | API 端點 |
| Authentication | auth, login | 身份驗證 |
| Form Handling | form, react hook form, zod | 表單處理 |
| Database Query | database, query, prisma | 資料庫查詢 |
| Networking | network, http client, fetch, axios | 網路請求 |
| Next.js Page | page | 頁面路由 |
| Next.js Layout | layout | 佈局組件 |
| React Query | tanstack query, data fetching, swr | 資料獲取 |
| React Context | context api | Context 狀態 |
| HOC | higher order component | 高階組件 |
| Error Boundary | boundary | 錯誤邊界 |
| Suspense | fallback | Suspense 組件 |
| Portal | modal, dialog | Portal/Modal |
| Ref | forward ref, imperative handle | Ref 處理 |
| Memo | memoization, performance | 效能優化 |

### Vue Tier 1 Patterns（7 個）

| Pattern | 別名 | 用途 |
|---------|------|------|
| Vue Component | sfc, vue | SFC 組件 |
| Composable | composition, vue hook | Composition API |
| Pinia | pinia store, vue store | 狀態管理 |
| Vue Router | vue routes, router | 路由管理 |
| Directive | directives, vue directive | 指令 |
| Vue Plugin | plugin, plugins | 插件 |
| Provide/Inject | provide, inject | 依賴注入 |

### Tier 2 補充 Patterns（25 個）

**React Tier 2**:
- Next.js Middleware, Loading, Error
- Server Components, Server Actions
- Background Job, File Upload
- Test (Vitest/Jest), Theme/Styling
- Animation (Framer Motion)
- i18n, Validation (Zod/Yup), tRPC

**Vue Tier 2**:
- Nuxt Page, Layout, Middleware, Plugin, Composable
- Vue Transition, Mixin, Filter
- Vue Test, i18n, Router Guard

### 測試專案

| 專案 | 類型 | 特色 |
|------|------|------|
| Excalidraw | React | 畫布應用、豐富 Hooks |
| Mantine | React | UI 組件庫、完整 Hooks |
| Shadcn UI | React | 現代 UI 組件 |
| Bulletproof React | React | 最佳實踐範例 |
| Element Plus | Vue | 企業級 UI 組件 |
| VueUse | Vue | Utility Composables |
| Naive UI | Vue | 現代 UI 組件 |

---

## 當前狀態（v2.9.0）

基於 PRD v2.9.0、v1.0 學習和 Constitution v1.1：

### ✅ 已完成 - 核心 6 Commands
- [x] `/atlas.init` - 專案初始化（自動觸發規則）✅ (2025-11-30)
- [x] `/atlas.overview` - Stage 0 專案指紋 ✅ (2025-11-20)
- [x] `/atlas.pattern` - 學習設計模式 ✅ (2025-11-22) ⭐⭐⭐⭐⭐
- [x] `/atlas.impact` - 影響範圍分析（靜態）✅ (2025-11-25) ⭐⭐⭐⭐
- [x] `/atlas.history` - 時序分析（Git 歷史）✅ (2025-11-30) ⭐⭐⭐⭐⭐
- [x] `/atlas.flow` - 流程追蹤（11 種分析模式）✅ (2025-12-01) ⭐⭐⭐⭐⭐

### ✅ 已完成 - v2.9.0 Dependency Analysis
- [x] `/atlas.deps` - Dependency 分析 ✅ (2025-12-12) ⭐⭐⭐⭐⭐
  - Phase 0 規則確認機制
  - Built-in rules (iOS, Android, Python)
  - WebSearch 動態規則生成
  - 純粹盤點 vs 升級模式識別
  - 4 場景測試，100% 準確率 (42/42 樣本)
  - Production Ready (Grade A+ 9.7/10)

### ✅ 已完成 - 品質框架
- [x] **Constitution v1.1** - 分析行為的不可變原則 + Handoffs 原則 ✅ (2025-12-06)
- [x] **Article VII: Handoffs 原則** - 發現驅動的動態下一步建議 ✅ (2025-12-06)
- [x] **validate-constitution.sh** - 自動化合規驗證 ✅ (2025-12-05)
- [x] **Monorepo 偵測** - lerna/pnpm/nx/turborepo/npm workspaces ✅ (2025-12-05)
- [x] **Branch-Aware Context** - Git 分支/子目錄/Package 偵測 ✅ (2025-12-06)
- [x] **--save 參數** - 所有分析命令支援儲存至 `.sourceatlas/` ✅ (2025-12-12)
- [x] **/atlas.clear** - 清空已儲存的分析結果 ✅ (2025-12-12)

### ✅ 已完成 - Model 效能優化 (2025-12-12)

各命令根據任務複雜度使用不同 Claude 模型，平衡速度與品質：

| 命令 | Model | 原因 |
|------|-------|------|
| `/atlas.init` | Haiku | 簡單文字注入，無需推理 |
| `/atlas.overview` | Sonnet | 假設生成需要中等推理能力 |
| `/atlas.pattern` | Sonnet | 模式匹配和實作指南生成 |
| `/atlas.history` | Sonnet | Git 分析和洞察生成 |
| `/atlas.impact` | Sonnet | 依賴追蹤和風險評估 |
| `/atlas.deps` | Sonnet | 依賴盤點和規則匹配 |
| `/atlas.flow` | Opus | 複雜多層邏輯流追蹤（11 種分析模式）|
| `/atlas.clear` | Haiku | 簡單檔案刪除操作 |

**預期效益**：
- Haiku 命令：速度提升 50%+，成本降低 70%
- Sonnet 命令：速度提升 20-30%，成本降低 40%
- 整體品質維持高標準（E2E 測試 100% 通過）

### ✅ 已完成 - 多語言支援
- [x] iOS/Swift - 34 patterns
- [x] Kotlin/Android - 31 patterns
- [x] Python - 26 patterns
- [x] TypeScript/React/Vue - 50 patterns
- **總計：141 patterns**

### 🔮 未來（v3.0）
- Go/Rust/Ruby patterns
- SourceAtlas Monitor - 持續追蹤和趨勢分析
- 技術債務量化
- 健康度儀表板
- `/atlas.standup` - 整合 GitLab MR 工具（cycle-time, branch-health）

**決策記錄**:
- (2025-12-12): **Model 效能優化** - 各命令指定最適 Model（Haiku/Sonnet/Opus），E2E 測試 100% 通過
- (2025-12-08): `/atlas.deps` 設計開始 - 專為 Library/Framework 升級場景（情境 8）
- (2025-11-25): `/atlas.find` 已取消 - 功能由現有 commands 涵蓋
- (2025-11-30): `/atlas.history` 實作完成 - 單一命令 + 零參數 + 智慧輸出 + 自動安裝 code-maat
- (2025-12-01): `/atlas.flow` 實作完成 - 11 種分析模式 + 語言專屬入口點 + 增強邊界識別
- (2025-12-05): **Constitution v1.0** 實作完成 - 7 Articles + 驗證腳本 + Monorepo 偵測
- (2025-12-06): **Constitution v1.1** 實作完成 - 新增 Article VII: Handoffs 原則（5 Sections）
- (2025-12-06): `/atlas.validate` 已取消 - 改為內建品質檢查（獨立命令過度工程化）
- (2025-12-06): **Branch-Aware Context** 實作完成 - Git 分支/子目錄/Package 偵測
- (2025-12-06): **--save 參數** 實作完成 - 可選儲存至 `.sourceatlas/overview.yaml`

**詳細路線圖**：見 [dev-notes/implementation-roadmap.md](./dev-notes/implementation-roadmap.md) 和 [PRD.md](./PRD.md)

---

## 實作核心原則（基於 v1.0 經驗 + Constitution v1.1）

實作任何新功能時，**必須遵循**：

1. **規模感知設計** - 不要一刀切，根據專案大小調整（Constitution Article VI）
2. **標準優於自訂** - 用 YAML、Markdown，不發明格式（Constitution Article V）
3. **測試先行** - 在 3+ 真實專案測試，不只是理論
4. **文檔同步** - 邊開發邊寫文檔，不要事後補
5. **基準測量** - 建立指標，持續追蹤
6. **排除目錄** - 永遠排除 .venv、node_modules、__pycache__（Constitution Article II）
7. **資訊理論** - 高熵優先，結構 > 實作細節（Constitution Article I）
8. **證據為本** - 每個論點需要 `file:line` 證據（Constitution Article IV）
9. **驗證合規** - 使用 `validate-constitution.sh` 驗證分析輸出
