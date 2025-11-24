# SourceAtlas + code-maat 整合文檔更新摘要

**文檔版本**: 2.1 (2025-11-24)

---

## 📌 版本號說明

本提案使用兩種版本號：

| 版本類型 | 當前版本 | 說明 |
|---------|---------|------|
| **文檔版本** | v2.1 | 本提案文檔的修訂版本 |
| **目標產品版本** | v3.0 | 本提案計劃實作到 SourceAtlas v3.0 |

- **文檔版本** 追蹤本提案的設計變更（v1.0 → v2.0 → v2.1）
- **產品版本** 指 SourceAtlas 產品本身的版本（當前 v2.5.2，規劃 v3.0）

---

## 📋 更新歷史

### v2.1 (2025-11-24) - 命令簡化（3→2）⭐

#### 重大變更

**命令數量簡化**：3 個命令 → **2 個命令**

| 原 v2.0 | v2.1 最終設計 | 變更原因 |
|---------|--------------|----------|
| `/atlas-changes` | `/atlas-changes` | ✅ **擴充**：整合耦合度分析功能 |
| `/atlas-coupling` | **已移除** | ⚠️ 功能整合到 `/atlas-changes` |
| `/atlas-expert` | `/atlas-expert` | ✅ 保持不變 |

**簡化理由**：
1. **功能重疊**：`/atlas-changes` 已有 `--coupling` 選項
2. **避免混淆**：用戶不需要在 changes 和 coupling 之間選擇
3. **職責清晰**：`/atlas-changes` = 完整時序分析，`/atlas-expert` = 專家查詢
4. **學習成本低**：2 個命令比 3 個更容易記憶和使用

**更新內容**：

1. **PRD.md v3.0 規劃**
   - 候選功能 A：2 個命令（原 3 個）
   - `/atlas-changes` 整合功能列表
   - 更新範例使用場景

2. **proposals/README.md**
   - 更新命令列表（3 → 2）
   - 強調 `/atlas-changes` 整合耦合度分析

3. **SOURCEATLAS_CODEMAAT_INTEGRATION.md**
   - 更新「重要說明」章節
   - 更新 Executive Summary（2 個命令）
   - 更新命令總覽（簡化版）
   - **移除整個 `/atlas-coupling` 章節**（238 行）
   - 擴充 `/atlas-changes` 功能說明
   - `/atlas-expert` 編號：3 → 2

**最終 v3.0 命令清單**：
```bash
/atlas-changes     # 歷史查詢 + 耦合度 + 熱點 + 風險評估
/atlas-expert      # 專家查詢 + 知識地圖
```

**與 v2.5 的對比**：
```bash
# v2.5 靜態分析
/atlas-overview    # 專案指紋 ✅
/atlas-pattern     # 模式學習 ✅
/atlas-impact      # 靜態影響分析（API、類型）⏳

# v3.0 時序分析（簡化）
/atlas-changes     # 歷史 + 耦合度 + 風險
/atlas-expert      # 專家查詢
```

**影響範圍**：
- ✅ PRD.md 更新完成
- ✅ proposals/README.md 更新完成
- ✅ SOURCEATLAS_CODEMAAT_INTEGRATION.md 更新完成（移除 238 行）
- ✅ 文檔版本：2.0 → 2.1

**向後相容性**：
- ⚠️ 破壞性變更（移除 `/atlas-coupling`）
- ✅ 但提案尚未實作，不影響現有系統
- ✅ 簡化後更容易實作和維護

---

### v2.0 (2025-11-24) - 命名規範與版本定位

#### 重大變更

**目標版本變更**：
- v2.5 → **v3.0**（本提案設計用於 SourceAtlas v3.0）
- 原因：v2.5 已規劃 `/atlas-impact` 用於靜態影響分析

**命令重新命名**（符合 /atlas- 前綴規範）：

| 原提案 | v3.0 正式名稱 | 變更原因 |
|--------|--------------|---------|
| `/changes` | `/atlas-changes` | 保持 atlas- 前綴一致性 |
| `/impact` | `/atlas-coupling` ⚠️ | 避免與 v2.5 `/atlas-impact` 衝突 |
| `/expert` | `/atlas-expert` | 保持 atlas- 前綴一致性 |

**新增內容**：
1. **⚠️ 重要說明章節**（文檔開頭）
   - 說明目標版本變更（v2.5 → v3.0）
   - 命名變更對照表
   - v2.5 vs v3.0 的 Impact 分析區別

2. **與 v2.5 的區別說明**
   - `/atlas-impact`（v2.5）= 靜態分析（代碼結構）
   - `/atlas-coupling`（v3.0）= 時序分析（git 歷史）
   - 兩者互補使用的範例

3. **命令總覽更新**
   - 新增 v2.5 靜態分析命令列表
   - v3.0 時序分析命令列表
   - 標註 `/atlas-pattern` 已完成 ✅

**文檔更新範圍**：
- Executive Summary
- 命令設計章節（3 個命令）
- 所有命令範例（`/changes` → `/atlas-changes` 等）
- 100+ 處命令名稱更新

**影響範圍**：
- ✅ SOURCEATLAS_CODEMAAT_INTEGRATION.md（主要文檔）
- ✅ 文檔版本：1.0 → 2.0
- ⚠️ 其他文檔待同步更新

**向後相容性**：
- ⚠️ 這是破壞性變更（命令名稱完全改變）
- ✅ 但提案尚未實作，不影響現有系統
- ✅ 文檔中已明確標註所有變更

---

### v1.3 (2025-11-24) - 大型 Codebase 效能考量

#### 新增章節

**「大型 Codebase 的效能考量」**（位於「效能優化」章節內）

標註為**待討論的優化方向**，尚未實作，包含：

##### 1. 問題識別

記錄大型專案可能面臨的挑戰：
- **執行時間過長**: 10萬+ commits 的專案可能需要 3-6 分鐘
- **檔案體積過大**: git log 輸出可能達 1 GB+
- **記憶體消耗**: JVM heap size 可能不足

##### 2. 五個待討論的解決方案

**方案 1: 分批處理（Batching）**
- 將分析拆分為多個時間範圍
- 可並行處理，失敗後只需重跑部分
- 需要實作結果合併邏輯

**方案 2: 多層快取（Multi-tier Cache）**
- L1: 記憶體快取
- L2: 檔案快取（60分鐘）
- L3: 增量快取
- 提供快取目錄結構設計

**方案 3: 增量更新（Incremental Update）**
- 只分析新的 commits
- revisions 可累加，coupling 需重算
- 包含實作概念代碼

**方案 4: 取樣分析（Sampling）**
- 最近 N 個月
- 取樣 commits（每 N 個取一個）
- 只分析活躍檔案

**方案 5: 資料庫儲存（Database Backend）**
- SQLite schema 設計
- 支援增量更新
- 提供查詢優化

##### 3. 效能基準測試框架

提供測試框架（待補充實際數據）：

| 專案規模 | Commits | 當前耗時 | 優化目標 |
|---------|---------|---------|---------|
| 小型 | <10K | ? | <30秒 |
| 中型 | 10K-50K | ? | <2分鐘 |
| 大型 | 50K-100K | ? | <5分鐘 |
| 超大型 | >100K | ? | <10分鐘 |

##### 4. 決策建議（分階段）

**Phase 1 (當前)**：
- 實作基本快取（60分鐘）
- 並行處理
- 暫不處理大型專案優化

**Phase 2 (未來)**：
- 收集真實效能數據
- 根據數據決定優化方向

**Phase 3 (長期)**：
- 完整增量更新系統
- 資料庫支援

##### 5. 討論要點清單

列出 5 個關鍵討論主題：
1. 快取失效策略
2. 增量更新的準確性
3. 使用者體驗
4. 資源限制
5. 降級策略

#### 設計考量

- ⚠️ 明確標註為「待討論」，避免誤導
- 📋 提供具體的解決方案而非空泛建議
- 🎯 包含實作概念代碼幫助理解
- 📊 提供效能基準測試框架
- 🚀 分階段實作建議

---

### v1.2 (2025-11-24) - code-maat 輸出格式更正

#### 更新內容

**1. 修正 code-maat CSV 輸出格式**

根據實際的 code-maat 輸出格式，更正了文檔中的欄位名稱和範例：

##### revisions 分析
- ❌ 錯誤：`entity,n-revisions`
- ✅ 正確：`entity,n-revs`

##### 新增 churn 分析說明
新增程式碼變動量分析的完整說明：
```csv
entity,added,deleted,commits
src/payment_service.rb,3450,890,245
```

欄位說明：
- `entity`: 檔案路徑
- `added`: 新增的程式碼行數
- `deleted`: 刪除的程式碼行數
- `commits`: 提交次數

**2. 更新「什麼是 code-maat？」章節**

新增第 3 項分析類型：
- ✅ 程式碼變動量分析（churn）

更新編號順序：
1. 變更頻率分析（revisions）
2. 耦合分析（coupling）
3. 程式碼變動量分析（churn） ← 新增
4. 作者分析（authors / hotspot-authors）
5. 主要開發者（main-dev）

**3. 更新「code-maat 核心用法」章節**

在常用分析類型中：
- ✅ 修正 revisions 輸出格式註解
- ✅ 新增 churn 分析範例
- ✅ 更新後續編號（3→4, 4→5, 5→6, 6→7）

新增內容：
```bash
**2. churn - 程式碼變動量**
maat -l git.log -c git2 -a churn > churn.csv

# 輸出格式
# entity,added,deleted,commits
# src/payment_service.rb,3450,890,245
```

**4. 更新「附錄 A - code-maat 分析類型」**

完全重寫附錄 A，提供更詳細的格式說明：

- ✅ 分為「核心分析類型」和「其他可用分析類型」
- ✅ 每個核心分析類型都有完整的命令範例和輸出格式
- ✅ 詳細說明每個欄位的含義

核心分析類型（SourceAtlas 使用）：
1. revisions - 變更頻率分析
2. churn - 程式碼變動量分析 ← 新增詳細說明
3. coupling - 耦合度分析
4. authors / hotspot-authors - 作者分析
5. main-dev - 主要開發者
6. entity-ownership - 所有權分布

---

### v1.1 (2025-11-24) - 時間規劃移除 & PR 分析雙平台支援

#### 1. 移除所有時間規劃

已移除文檔中所有關於開發時間的估算，包括：

#### Executive Summary
- ❌ 移除：具體的百分比提升數字（-50%, -60%, -70%）
- ✅ 改為：定性描述（"顯著減少"、"有效降低"、"快速找到"）

#### 使用場景價值描述
- 場景 1：`上手時間 -50%` → `顯著減少上手時間`
- 場景 2：`出錯率 -60%` → `有效降低出錯率`
- 場景 3：`找對人時間 -70%` → `快速找到合適專家`

#### 實作指南
移除所有 Phase 的時間估算：
- Phase 1: ~~環境設定（1 天）~~ → 環境設定
- Phase 2: ~~共用工具開發（2-3 天）~~ → 共用工具開發
- Phase 3: ~~`/changes` 命令（3-4 天）~~ → `/changes` 命令
- Phase 4: ~~`/impact` 命令（3-4 天）~~ → `/impact` 命令
- Phase 5: ~~`/expert` 命令（2-3 天）~~ → `/expert` 命令
- Phase 6: ~~整合與優化（2-3 天）~~ → 整合與優化

#### 總結
- ❌ 移除：`預計總開發時間：2-3 週`
- ✅ 保留：實作步驟的描述，不含時間估算

---

### 2. PR/MR 分析支援 GitHub 和 GitLab

#### 命令設計更新

**`/impact` 命令語法**：
```bash
target: 
  - 檔案路徑
  - 方法名稱 (file::method)
  - PR/MR 編號 (PR#123)
    * GitHub: 需要 gh CLI
    * GitLab: 需要 glab CLI
```

#### 實作更新

**新的 `analyze_pr_impact` 函數**：
- ✅ 自動偵測平台（GitHub 或 GitLab）
- ✅ 根據平台使用不同的 CLI 工具
  - GitHub: `gh` CLI
  - GitLab: `glab` CLI
- ✅ 統一的錯誤處理和提示
- ✅ 支援 jq 或 Python 解析 JSON

**核心邏輯**：
```bash
# 偵測平台
if [[ $remote_url == *"github.com"* ]]; then
    platform="github"
    # 使用 gh CLI
elif [[ $remote_url == *"gitlab"* ]]; then
    platform="gitlab"
    # 使用 glab CLI
fi
```

#### 安裝指南更新

新增安裝步驟：

**Step 5: GitHub CLI**
```bash
brew install gh
gh auth login
```

**Step 6: GitLab CLI**
```bash
brew install glab
glab auth login
```

**Step 7: jq（JSON 解析）**
```bash
brew install jq
```

#### 故障排除新增

新增 4 個故障排除項目：

5. **GitHub CLI 認證問題**
   - 錯誤：`gh: Not authenticated`
   - 解決：`gh auth login`

6. **GitLab CLI 認證問題**
   - 錯誤：`glab: authentication failed`
   - 解決：`glab auth login` 或設定 `GITLAB_TOKEN`

7. **PR/MR 分析找不到平台**
   - 錯誤：`Cannot detect platform`
   - 解決：檢查 git remote URL

8. **jq 未安裝**
   - 說明：會自動使用 Python 備選
   - 解決：安裝 jq 以獲得更好的效能

#### 輸出格式更新

PR 分析輸出新增 `platform` 欄位：
```yaml
target: PR#123
title: "Add payment priority feature"
analysis_type: pr_impact
platform: github  # 或 gitlab
```

#### Phase 4 任務清單更新

- ❌ 舊：實作 PR 分析（需要 gh CLI）
- ✅ 新：實作 PR 分析（支援 GitHub 和 GitLab）

---

## 技術細節

### 平台偵測邏輯
```bash
local remote_url=$(git config --get remote.origin.url)

if [[ $remote_url == *"github.com"* ]]; then
    platform="github"
elif [[ $remote_url == *"gitlab"* ]]; then
    platform="gitlab"
else
    echo "Error: Cannot detect platform..."
    exit 1
fi
```

### CLI 工具使用

**GitHub**:
```bash
gh pr view "$pr_num" --json files,title,additions,deletions
```

**GitLab**:
```bash
glab mr view "$pr_num" --json files,title
```

### JSON 解析策略

**優先使用 jq**:
```bash
if command -v jq &> /dev/null; then
    jq -r '.files[].path' "$tmp/pr.json"
fi
```

**備選使用 Python**:
```bash
python3 -c "
import json
with open('$tmp/pr.json') as f:
    data = json.load(f)
    for file in data.get('files', []):
        print(file.get('path', ''))
"
```

---

## 文檔統計

- **總行數**: 2,356 行
- **主要章節**: 10 個
- **代碼範例**: 50+ 個
- **使用場景**: 3 個核心場景
- **命令設計**: 3 個新命令（/changes, /impact, /expert）
- **支援平台**: 2 個（GitHub, GitLab）

---

## 向後相容性

所有更改都是**向後相容**的：

1. ✅ 移除時間估算不影響實作內容
2. ✅ PR 分析自動偵測平台，無需手動配置
3. ✅ 如果只安裝一個 CLI（gh 或 glab），只能用該平台的功能
4. ✅ jq 為可選依賴，有 Python 備選方案

---

## 建議的後續行動

### 開發者閱讀順序
1. **Executive Summary** - 了解整體目標
2. **什麼是 code-maat？** - 理解基礎工具
3. **新增命令設計** - 了解要開發什麼
4. **實作指南** - 按 Phase 開始實作

### 必要的環境準備
```bash
# 基礎工具
brew install openjdk@11  # Java
wget <code-maat JAR>     # code-maat

# 根據你的平台選擇安裝
brew install gh    # GitHub 用戶
brew install glab  # GitLab 用戶

# 可選但建議
brew install jq    # JSON 解析
```

### 測試清單
- [ ] 測試 GitHub PR 分析
- [ ] 測試 GitLab MR 分析
- [ ] 測試平台自動偵測
- [ ] 測試 JSON 解析（jq 和 Python）
- [ ] 測試認證錯誤處理

---

## 文檔品質保證

### ✅ 已驗證
- 所有時間估算已移除
- PR/MR 分析支援雙平台
- 代碼範例語法正確
- 故障排除完整
- 安裝指南詳細

### 📝 保持一致
- 用詞統一（PR/MR、GitHub/GitLab）
- 格式一致（YAML 縮排、Bash 語法）
- 範例完整（包含輸入和輸出）

---

## 聯絡與支援

如有任何疑問或建議，請參考：
- 主文檔：`SOURCEATLAS_CODEMAAT_INTEGRATION.md`
- code-maat GitHub: https://github.com/adamtornhill/code-maat
- GitHub CLI: https://cli.github.com/
- GitLab CLI: https://gitlab.com/gitlab-org/cli
