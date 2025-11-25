# CLAUDE.md

本檔案為 Claude Code (claude.ai/code) 在此 codebase 工作時提供指導。

## 專案總覽

**SourceAtlas** 是一個專為 AI 優化的 codebase 分析工具，設計用於快速理解任何 codebase，通過掃描少於 5% 的檔案即可達到 70-95% 的理解深度。它使用資訊理論原則，優先處理高熵檔案（配置、文檔、模型）而非實作細節。

**核心創新**：三階段分析框架，相比傳統程式碼審查方法節省 95%+ 的時間和 token。

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
- TOON 格式已評估但未採用（詳見 `dev-notes/toon-vs-yaml-analysis.md`）
- 用於 Stage 0 輸出：`.yaml`
- 用於 Stage 1-2 輸出：`.md`

## 目錄結構

```
sourceatlas2/
├── README.md               # 使用者文檔（中文）
├── CLAUDE.md               # 本檔案 - AI 協作指南
├── PROMPTS.md              # 所有 3 個階段的完整 prompt 模板
├── PRD.md                  # 產品需求（v2.5 Commands 架構）
├── USAGE_GUIDE.md          # 詳細使用說明
├── GLOBAL_INSTALLATION.md  # 全局安裝指南
│
├── .claude/commands/       # Claude Code 斜線命令
│   ├── atlas-overview.md   # ✅ /atlas-overview (Stage 0)
│   └── atlas-pattern.md    # ✅ /atlas-pattern (Pattern Learning)
│
├── scripts/                # 分析腳本
│   ├── atlas/              # ⭐ Atlas 命令核心腳本
│   └── install-global.sh   # ⭐ 全局安裝腳本
│
├── proposals/              # ✅ 功能提案（未實作功能）⭐
│   ├── README.md           # 提案索引
│   └── code-maat-integration/  # code-maat 整合設計 (v3.0 候選)
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
/atlas-overview
/atlas-pattern "api endpoint"
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

**v2.5 方式**（Commands，開發中）：
- `/atlas-overview` ✅ - Stage 0 專案指紋（已實作）
- `/atlas-pattern` ✅ - 學習設計模式（已實作）
- `/atlas-impact` 🔵 - 影響範圍分析（開發中）
- `/atlas-find` 🔵 - 智慧搜尋（開發中）

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

## 使用測試結果

### 已驗證專案

本 codebase 包含來自多個驗證專案的分析，涵蓋不同規模、語言和成熟度等級。由於隱私考量，測試專案和結果檔案已從 git 歷史中移除，但分析方法論和框架仍然完整保留。

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
- **SourceAtlas 產品版本**（如 v2.5.2）：追蹤整個產品的開發階段
- **提案文檔版本**（如 proposals/ 下的 v2.1）：追蹤個別提案的設計變更

**當前產品版本**：
- **v1.0** ✅ - 方法論驗證完成（2025-11-22）
- **v2.5** 🔵 - Commands 實作中（預計 3-4 週）

**版本歷程**：
- v2.5.1 (2025-11-23): **iOS Patterns 擴展完成** - 新增 18 個 iOS patterns (16 → 34, +112.5%)
- v1.0 (2025-11-22): 完成 5 專案驗證、YAML vs TOON 決策、規模感知算法
- v2.0 (2025-11-19): 手動 Prompts 方法論
- v2.5 (進行中): Claude Code Commands 整合

### 忽略的目錄

- `test_targets/` - 用於驗證的克隆 codebase（大型，不追蹤到 git）
- `test_results/` - 生成的分析輸出（可以重新生成）
- `examples/*` - clone 的參考專案（僅追蹤 README.md）

這些被 git 忽略以保持 codebase 精簡，同時保護測試專案的隱私。

---

## 資訊分層與想法孵化

SourceAtlas 是**方法論型專案**，價值不只在程式碼，更在思考過程。因此採用**全部可見**的透明化策略。

### 三層架構

| 層級 | 路徑 | 成熟度 | 用途 | 可見性 |
|------|------|--------|------|--------|
| **想法** | `ideas/` | 0-30% | 實驗性想法、草稿筆記 | ✅ 可見 |
| **提案** | `proposals/` | 70-90% | 成熟提案、待實作功能 | ✅ 可見 |
| **記錄** | `dev-notes/` | 100% | 已完成的實作記錄 | ✅ 可見 |

### 生命週期

```
ideas/*.md
  ↓ 1-4 週研究驗證
  ↓ 確認價值和可行性
proposals/feature-name/
  ↓ 排入 roadmap
  ↓ 開始實作
dev-notes/YYYY-MM/implementation.md
```

### 為什麼全部可見？

1. **專案性質** - SourceAtlas 是方法論型專案，不是純工具
2. **價值主張** - 思考過程和設計決策本身就是產品的一部分
3. **社群參與** - 透明度建立信任，鼓勵貢獻
4. **學習資源** - 開發記錄是其他人學習分析方法論的寶貴資源

### 什麼應該隱藏？

只隱藏**工具配置**：
- `.claude/` - Claude Code 專用配置
- `.git/` - 版本控制內部
- `.vscode/`, `.idea/` - 編輯器配置（如果有）

---

## 各資料夾用途詳解

### ideas/ - 腦力激盪區

**用途**：記錄未成熟的想法、實驗性研究、突發靈感

**規則**：
- ✅ 可以不完整、可以亂
- ✅ 隨時可刪除
- ❌ 不應該長期滯留（超過 1 個月考慮升級或刪除）

**範例**：
- `ai-quality-scoring-v2.md` - 改進 AI 品質評分
- `technical-debt-quantification.md` - 技術債務量化

📚 **詳細說明**：見 [ideas/README.md](./ideas/README.md)

### proposals/ - 功能提案庫

**用途**：已經過研究驗證的成熟提案，等待排入 roadmap

**要求**：
- ✅ 使用場景清晰
- ✅ 技術方案可行（已驗證）
- ✅ 價值主張明確
- ✅ 文檔基本完整

**當前提案**：
- `code-maat-integration/` - 時序分析整合 (v3.0 候選)

📚 **詳細說明**：見 [proposals/README.md](./proposals/README.md)

### examples/ - 外部參考專案

**用途**：存放用於學習和研究的第三方專案

**與 test_targets/ 的區別**：
- `examples/` - 手動探索、學習架構模式
- `test_targets/` - 自動化測試、驗證方法論

**注意**：
- 專案本身不追蹤到 git（太大）
- 只追蹤 README.md（說明和推薦）

📚 **詳細說明**：見 [examples/README.md](./examples/README.md)

### dev-notes/ - SourceAtlas 知識庫

**用途**：完整的開發歷史、關鍵決策和方法論

**核心檔案**（Layer 1）：
- `HISTORY.md` - 專案演進時間線
- `KEY_LEARNINGS.md` - 核心學習與發現
- `METHODOLOGY.md` - 開發方法論
- `ROADMAP.md` - 未來規劃

**組織方式**：
- 大寫檔案（5 個上限）- 持續更新的索引
- 月度資料夾（YYYY-MM/）- 詳細實作記錄
- archives/ - 歷史存檔

📚 **詳細說明**：見 [dev-notes/README.md](./dev-notes/README.md)

---

## 升級標準

### ideas/ → proposals/

需要滿足：
- ✅ 使用場景清晰（解決什麼問題）
- ✅ 技術方案可行（已驗證）
- ✅ 價值主張明確（為什麼做）
- ✅ 文檔完整（README + 詳細設計）

### proposals/ → dev-notes/

當功能開始實作：
- ✅ 已納入 roadmap
- ✅ 創建 dev-notes/YYYY-MM/implementation.md
- ✅ 更新 HISTORY.md
- ✅ 提案保留在 proposals/（作為設計文檔）

## 開發工作流程

### Git 和版本控制

- **絕對不要使用 `git commit` 命令** - GitButler 正在使用其內部流程和 `but` CLI hooks 自動管理所有 commits 和分支
- **專注於編寫乾淨的程式碼和測試** - 不要擔心 commits 或分支
- **當任務完成時，停止工作**並允許 GitButler hooks 執行後處理命令

此工作流程確保功能的清晰分離，並允許 GitButler 自動組織 commits 和分支，無需手動介入。

## dev-notes/ 管理規則

**dev-notes/** 資料夾記錄完整開發歷史、關鍵決策和方法論。**所有 AI 和開發者必須遵守以下規則**。

### 檔案分類決策樹

創建或整理 dev-notes 檔案時，**嚴格按照此決策樹**：

#### Step 1: 是否為「持續參考」？

回答以下 3 個問題，**全部為 YES** 才是持續參考：

1. ❓ 這個檔案會被**頻繁更新**嗎？（每週至少 1 次）
2. ❓ 這個檔案是**索引/導航**性質嗎？（指向其他檔案）
3. ❓ 這個檔案提供**長期有效的方法論/原則**嗎？

**如果 3 個都是 YES** → 使用**大寫檔名** (UPPER_CASE.md)
- **限制：最多 5 個大寫檔案**
- 當前已有：README.md, HISTORY.md, KEY_LEARNINGS.md, ROADMAP.md, METHODOLOGY.md
- **⛔ 絕不創建新的大寫檔案**（除非明確討論並批准）

**否則** → 使用**日期前綴** (YYYY-MM-DD-topic-type.md)

#### Step 2: 確定檔案名稱

**格式**: `YYYY-MM-DD-topic-type.md`

- **YYYY-MM-DD**: 使用**完成日期**（不是開始日期）
- **topic**: 主題，使用連字號分隔（如 `objective-c-support`）
- **type**: 類型後綴
  - `implementation`: 實作記錄
  - `analysis`: 分析報告
  - `decision`: 決策記錄
  - `test`: 測試報告
  - `experiment`: 實驗嘗試

**範例**:
```
2025-11-23-objective-c-support-implementation.md
2025-11-20-toon-vs-yaml-decision.md
2025-11-22-atlas-pattern-implementation.md
```

#### Step 3: 確定存放位置

```bash
# 決策邏輯
if 檔案完成日期屬於當前月或上個月:
    放在 dev-notes/YYYY-MM/
elif 檔案是「決策分析」類型:
    放在 dev-notes/archives/decisions/
elif 檔案是「方法論深度分析」:
    放在 dev-notes/archives/lessons/
else:
    放在 dev-notes/YYYY-MM/ (對應月份)
```

#### Step 4: 檢查是否需要合併

**合併條件**（滿足任一即合併）：
1. 同一天（YYYY-MM-DD）+ 同一主題 → 合併為一個檔案
2. 同一主題的多個測試結果 → 合併為一個完整報告
3. 計劃 + 實作 + 報告 → 合併為完整記錄

**範例合併**:
```
❌ Before (4 個分散檔案):
- objective-c-support-gap-analysis.md
- objective-c-support-test-report.md
- ***REMOVED***-objc-analysis.md
- objc-percentage-calculation-method.md

✅ After (1 個完整報告):
- 2025-11-23-objective-c-support.md
  - Phase 1: Gap Analysis
  - Phase 2: Implementation
  - Phase 3: Testing
  - Appendix A: Calculation Method
  - Appendix B: ***REMOVED*** Analysis
```

### 更新大寫檔案的規則

#### 更新 HISTORY.md

每完成一個重大功能/決策，**立即追加**一條記錄：

```markdown
### Week N (MM/DD-MM/DD): 主題
- **功能名稱** (MM/DD): 簡短描述（1 行）→ [詳細](連結)
```

#### 更新 KEY_LEARNINGS.md

每發現重要學習，追加到相應章節：

```markdown
### N. 學習標題
**發現**: 1 句話
**證據**: 1 句話
**應用**: 1 句話
→ [完整分析](連結)
```

#### 更新 ROADMAP.md

- 每週更新「Immediate Actions」
- 每月更新「Phase Progress」

#### 更新月度 README

每月最後一天，更新 `YYYY-MM/README.md`：

```markdown
## 本月重點
（2-3 句話總結）

## 主要成果
（列出 3-5 個重點，每個 2-3 行 + 連結）

## 關鍵學習
（提煉 2-3 個核心學習）
```

### 執行原則（AI 必須遵守）

1. ⛔ **絕不創建新的大寫檔案**（除非明確討論並批准）
2. ✅ **所有新內容使用日期前綴**
3. ✅ **完成後立即更新 HISTORY.md**
4. ✅ **同主題內容必須合併**
5. ✅ **每月最後一天檢查並更新月度 README**
6. ✅ **3 個月前的內容考慮移到 archives/**

### 驗證工具

創建或整理檔案後，執行檢查：

```bash
# 驗證結構
dev-notes/scripts/validate.sh

# 檢查項目：
✅ 檔名符合規範（大寫或日期前綴）
✅ 大寫檔案不超過 5 個
✅ 日期檔案有對應的月度資料夾
✅ 月度 README.md 存在且完整
✅ HISTORY.md 有最新記錄
```

### 範例：創建新實作記錄

```bash
# ❌ 錯誤做法
touch ios-support.md
touch test-results.md

# ✅ 正確做法
1. 確定日期：2025-11-23
2. 確定主題：ios-patterns-consolidation
3. 確定類型：implementation
4. 創建：dev-notes/2025-11/2025-11-23-ios-patterns-consolidation.md
5. 更新：dev-notes/HISTORY.md（追加一條記錄）
6. 更新：dev-notes/2025-11/README.md（本月重點）
```

### 資訊分層原則

本資料夾遵循 SourceAtlas 的資訊理論原則：

- **Layer 0** (README.md): 10 秒快速理解
- **Layer 1** (5 個核心檔案): 5 分鐘掌握全貌
- **Layer 2** (月度資料夾): 30 分鐘理解細節
- **Layer 3** (archives/): 深度挖掘

**完整規範**: 見 [dev-notes/README.md](./dev-notes/README.md)

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

**詳細路線圖**：見 [dev-notes/implementation-roadmap.md](./dev-notes/implementation-roadmap.md) 和 [dev-notes/NEXT_STEPS.md](./dev-notes/NEXT_STEPS.md)

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
