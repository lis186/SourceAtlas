# CLAUDE.md

本檔案為 Claude Code (claude.ai/code) 在此代碼庫工作時提供指導。

## 專案總覽

**SourceAtlas v2.0** 是一個專為 AI 優化的代碼庫分析工具，設計用於快速理解任何代碼庫，通過掃描少於 5% 的檔案即可達到 70-95% 的理解深度。它使用資訊理論原則，優先處理高熵檔案（配置、文檔、模型）而非實作細節。

**核心創新**：三階段分析框架，相比傳統代碼審查方法節省 95%+ 的時間和 token。

## 架構

### 三階段分析流程

系統使用漸進式分析方法：

1. **Stage 0: 專案指紋** (~10-15 分鐘, ~20k tokens)
   - 掃描 <5% 檔案達到 70-80% 理解
   - 識別技術棧、架構模式、業務領域
   - 生成 10-15 個待驗證假設
   - 輸出格式：`.toon` (Token Optimized Output Notation)

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

**TOON 格式** (Token Optimized Output Notation)：

- 針對 token 效率優化的自訂 YAML-like 格式
- 相比 JSON 節省 30-50% tokens
- 人類可讀且機器可解析
- 用於 Stage 0 輸出

## 目錄結構

```
sourceatlas2/
├── PROMPTS.md              # 所有 3 個階段的完整 prompt 模板
├── README.md               # 使用者文檔（中文）
├── PRD.md                  # 產品需求（未來 CLI 工具設計）
├── USAGE_GUIDE.md          # 詳細使用說明
├── prompts/                # 個別 prompt 檔案
│   ├── stage0-fingerprint.md
│   ├── stage1-validation.md
│   └── stage2-hotspots.md
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

### 執行 Prompts

所有 prompts 都在 `PROMPTS.md` 中。關鍵步驟：

1. 從 `PROMPTS.md` 複製相關階段的 prompt
2. 將 `[PROJECT_PATH]` 替換為實際路徑
3. 按照指示執行檔案讀取和 shell 命令
4. 以指定格式生成輸出（Stage 0 用 .toon，Stage 1-2 用 .md）
5. 將結果儲存在 `test_results/` 供參考

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

- 參考 `test_results/` 中的 `.toon` 檔案了解輸出格式（如果有的話）
- Stage 1 應達到 >80% 驗證準確率
- 研究 AI 模式識別技術
- 遵循系統化的比較分析方法論

## 檔案格式

### TOON 格式 (.toon)

用於 Stage 0 輸出。主要特性：

- 帶有 metadata 標頭的 YAML-like 語法
- 結構化區段：專案指紋、假設、掃描檔案
- 所有推論的信心等級（0.0-1.0）
- 為 AI 消費優化的 token 使用

範例結構：

```toon
metadata:
  project_name: example
  scan_time: 2025-11-19T10:00:00Z
  total_files: 500
  scanned_files: 12
  scan_ratio: 2.4%

## Project Fingerprint
project_type: WEB_APP
scale: MEDIUM
# ...additional fields

## Hypotheses
- hypothesis: "Uses JWT authentication"
  confidence: 0.75
  evidence: ["Found jwt dependency", "auth middleware present"]
```

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

當前版本：**v2.0**

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

## 未來開發（v2.1+）

基於 PRD.md，未來計劃包括：

- CLI 工具實作（`satlas` 命令）
- 自動化索引和查詢
- 多語言解析器支援
- 大型代碼庫的效能優化（>100k LOC）

實作這些功能時，維持核心原則：

- 基於資訊理論的優先級排序
- Token 效率
- 漸進式精煉
- 基於證據的分析
