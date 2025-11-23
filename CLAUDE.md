# CLAUDE.md

本檔案為 Claude Code (claude.ai/code) 在此代碼庫工作時提供指導。

## 專案總覽

**SourceAtlas** 是一個專為 AI 優化的代碼庫分析工具，設計用於快速理解任何代碼庫，通過掃描少於 5% 的檔案即可達到 70-95% 的理解深度。它使用資訊理論原則，優先處理高熵檔案（配置、文檔、模型）而非實作細節。

**核心創新**：三階段分析框架，相比傳統代碼審查方法節省 95%+ 的時間和 token。

**當前狀態**：
- **v1.0** ✅ - 方法論驗證完成（2025-11-22）
- **v2.5** 🔵 - Commands 架構實作中（目標：3-4 週）

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

**資訊理論基礎**：

- 高熵檔案（configs、READMEs、models）包含不成比例的大量資訊
- 結構 > 實作細節，更適合快速理解
- 漸進式精煉勝過窮舉式掃描

**格式選擇** (v1.0 決策)：

- **YAML** 為主要格式（標準生態系統 > 14% token 優化）
- TOON 格式已評估但未採用（詳見 `.dev-notes/toon-vs-yaml-analysis.md`）
- 用於 Stage 0 輸出：`.yaml`
- 用於 Stage 1-2 輸出：`.md`

## 目錄結構

```
sourceatlas2/
├── PROMPTS.md              # 所有 3 個階段的完整 prompt 模板
├── README.md               # 使用者文檔（中文）
├── PRD.md                  # 產品需求（v2.5 Commands 架構）
├── USAGE_GUIDE.md          # 詳細使用說明
│
├── .claude/commands/       # ⭐ Claude Code 斜線命令
│   └── atlas-overview.md   # ✅ /atlas-overview (Stage 0)
│
├── scripts/atlas/          # ⭐ 輔助腳本
│   ├── detect-project-enhanced.sh  # ✅ 規模感知偵測
│   ├── scan-entropy.sh             # ✅ 高熵檔案掃描
│   ├── benchmark.sh                # ✅ 效能測試
│   └── compare-formats.sh          # ✅ 格式比較
│
├── .dev-notes/             # ⭐ 開發紀錄（關鍵學習）
│   ├── v1-implementation-log.md    # v1.0 完整紀錄
│   ├── toon-vs-yaml-analysis.md    # 格式決策分析
│   ├── implementation-roadmap.md   # v2.5 實作路線圖
│   └── NEXT_STEPS.md               # 下一步行動指南
│
├── test_results/           # 驗證專案的分析輸出（已被 git 忽略）
└── test_targets/           # 用於驗證的克隆代碼庫（已被 git 忽略）
```

## 使用分析 Prompts

### 何時執行分析

在以下情況執行 SourceAtlas 分析：

- 接手新的代碼庫
- 進行代碼審查或技術盡職調查
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

**v2.5 方式**（Commands，開發中）：
- `/atlas-overview` ✅ - Stage 0 專案指紋（已實作）
- `/atlas-pattern` 🔵 - 學習設計模式（最高優先級，開發中）
- `/atlas` 🔵 - 完整三階段分析（開發中）
- `/atlas-impact` 🔵 - 影響範圍分析（開發中）
- `/atlas-find` 🔵 - 智慧搜尋（開發中）

**重要**：Stage prompts 彼此依賴。務必先完成 Stage 0 再做 Stage 1，先完成 Stage 1 再做 Stage 2。

## AI 協作檢測

SourceAtlas 的獨特能力之一是識別 AI 輔助開發模式：

### AI 協作成熟度模型

- **Level 0**：無 AI（傳統開發）
- **Level 1-2**：基礎 AI 使用（偶爾使用工具）
- **Level 3**：系統化 AI 協作 ⭐
  - 有 `CLAUDE.md` 或類似的 AI 配置
  - 15-20% 註解密度（相比人工的 5-8%）
  - 98%+ 代碼一致性
  - 100% Conventional Commits
  - 文檔/代碼比 >1:1
- **Level 4**：生態級別（團隊級 AI 整合）

**關鍵指標**：尋找 CLAUDE.md、.cursor/rules/、高註解密度、完美的 commit 訊息一致性和豐富的文檔。

## 使用測試結果

### 已驗證專案

本代碼庫包含來自多個驗證專案的分析，涵蓋不同規模、語言和成熟度等級。由於隱私考量，測試專案和結果檔案已從 git 歷史中移除，但分析方法論和框架仍然完整保留。

### 將測試結果用作範例

創建新分析時：

- 參考 `test_results/` 中的 `.yaml` 檔案了解輸出格式（如果有的話）
- Stage 1 應達到 >80% 驗證準確率
- 研究 AI 模式識別技術
- 遵循系統化的比較分析方法論

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
- 完整分析見 `.dev-notes/toon-vs-yaml-analysis.md`

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

- 主要文檔使用繁體中文（zh-TW）
- 代碼和技術術語使用英文
- 生成報告時，匹配專案的主要語言
- 使用者文檔（README、USAGE_GUIDE）使用中文
- 技術規格（PRD、PROMPTS）混合使用中英文

## 版本控制

**當前版本**：
- **v1.0** ✅ - 方法論驗證完成（2025-11-22）
- **v2.5** 🔵 - Commands 實作中（預計 3-4 週）

**版本歷程**：
- v2.5.1 (2025-11-23): **iOS Patterns 擴展完成** - 新增 18 個 iOS patterns (16 → 34, +112.5%)
- v1.0 (2025-11-22): 完成 5 專案驗證、YAML vs TOON 決策、規模感知算法
- v2.0 (2025-11-19): 手動 Prompts 方法論
- v2.5 (進行中): Claude Code Commands 整合

### 忽略的目錄

- `test_targets/` - 用於分析的克隆代碼庫（大型，不需要在 repo 中）
- `test_results/` - 生成的分析輸出（可以重新生成）
- `reference/` - 臨時參考資料

這些被 git 忽略以保持代碼庫精簡，同時保護測試專案的隱私。

## 開發工作流程

### Git 和版本控制

- **絕對不要使用 `git commit` 命令** - GitButler 正在使用其內部流程和 `but` CLI hooks 自動管理所有 commits 和分支
- **專注於編寫乾淨的代碼和測試** - 不要擔心 commits 或分支
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

> **詳細分析與證據**：見 `.dev-notes/KEY_LEARNINGS.md` 和 `.dev-notes/HISTORY.md`

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
- **`.dev-notes/new-language-support-methodology.md`** - 6 階段系統化方法論
- 適用於未來新增任何程式語言支援（Kotlin, Go, Rust, Flutter 等）
- 包含完整檢查清單、快速啟動腳本、品質標準

> **詳細報告**：見 `test_targets/ios-patterns-expansion-complete-report.md`

---

## 開發中功能（v2.5）

基於 PRD v2.5.2 和 v1.0 學習，當前開發路線：

### Phase 1 (Week 1) - 最高優先級
- [x] `/atlas-overview` - Stage 0 專案指紋 ✅
- [ ] `/atlas-pattern` ⭐⭐⭐⭐⭐ - 學習設計模式（PRD #1 優先級）
- [ ] `/atlas` - 完整三階段分析

### Phase 2-4 (Week 2-4)
- [ ] `/atlas-impact` ⭐⭐⭐⭐ - 影響範圍分析（API 變更場景）
- [ ] `/atlas-find` - 智慧搜尋
- [ ] `/atlas-explain` - 深入解釋
- [ ] 完整測試與文檔

### 未來（v3.0+）
- SourceAtlas Monitor - 持續追蹤和趨勢分析
- 技術債務量化
- 健康度儀表板

**詳細路線圖**：見 `.dev-notes/implementation-roadmap.md` 和 `.dev-notes/NEXT_STEPS.md`

---

## 實作核心原則（基於 v1.0 經驗）

實作任何新功能時，**必須遵循**：

1. **規模感知設計** - 不要一刀切，根據專案大小調整
2. **標準優於自訂** - 用 YAML、Markdown，不發明格式
3. **測試先行** - 在 3+ 真實專案測試，不只是理論
4. **文檔同步** - 邊開發邊寫文檔，不要事後補
5. **基準測量** - 建立指標，持續追蹤
6. **排除目錄** - 永遠排除 .venv、node_modules、__pycache__
7. **資訊理論** - 高熵優先，結構 > 實作細節
8. **證據為本** - 每個論點需要證據（file:line 引用）
