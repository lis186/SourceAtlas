# SourceAtlas + code-maat 整合開發文檔

**文檔版本**: 2.1 (2025-11-24)
**目標產品版本**: SourceAtlas v2.6 ⭐

---

## ⚠️ 重要說明（2025-11-24 更新）

### 目標版本變更

本提案設計用於 **SourceAtlas v2.6**（非 v2.5）。

**原因**：v2.5 已規劃 `/atlas.impact` 命令用於靜態影響分析，與本提案功能互補但不重疊。

### 命令簡化（2025-11-24 更新）

原提案有 3 個命令，現簡化為 **2 個命令**：

| 原提案 | v2.6 最終設計 | 說明 |
|--------|--------------|------|
| `/changes` | `/atlas.changes` | ✅ 整合完整時序分析功能 |
| `/impact` | **已移除** | ⚠️ 整合到 `/atlas.changes` |
| `/expert` | `/atlas.expert` | ✅ 保持獨立 |

**簡化理由**：
- `/atlas.changes` 已包含耦合度分析（`--coupling` 選項）
- 避免功能重疊和用戶混淆
- 保持命令職責清晰

### v2.5 vs v2.6 的分析區別

| 命令 | 版本 | 分析方法 | 適用場景 | 狀態 |
|------|------|---------|---------|------|
| `/atlas.impact` | v2.5 | **靜態分析**（代碼結構） | API 變更、前後端影響 | Phase 2 |
| `/atlas.changes` | v2.6 | **時序分析**（git 歷史） | 變更頻率、耦合度、風險評估 | 提案階段 |

**兩者互補使用**：
- 改 API 前：用 `/atlas.impact` 找靜態依賴（誰調用了這個 API）
- 改核心邏輯前：用 `/atlas.changes` 看時序耦合（歷史上常一起改的檔案）

---

## 📋 目錄

1. [Executive Summary](#executive-summary)
2. [什麼是 code-maat？](#什麼是-code-maat)
3. [為什麼要整合 code-maat？](#為什麼要整合-code-maat)
4. [新增命令設計](#新增命令設計)
5. [技術架構](#技術架構)
6. [code-maat 整合方案](#code-maat-整合方案)
7. [Scripts 開發規範](#scripts-開發規範)
8. [實作指南](#實作指南)
9. [測試策略](#測試策略)
10. [部署與維護](#部署與維護)

---

## Executive Summary

### 目標
為 SourceAtlas v2.6 增加 2 個新命令，提供程式碼的時序分析能力：
- `/atlas.changes` - 歷史查詢（整合變更頻率、**耦合度分析**、熱點、風險評估）
- `/atlas.expert` - 專家查詢

### 關鍵決策
- **工具選擇**: 使用 code-maat 進行 git 歷史分析
- **架構**: Scripts 收集數據 → YAML 輸出 → Claude 解讀
- **實作語言**: Shell Script（輕量、可維護）
- **整合方式**: 透過 Claude Code Skills 機制

### 預期價值
- 新任務上手更快
- 改代碼出錯率降低
- 快速找到對的人
- Code Review 品質提升

---

## 什麼是 code-maat？

### 簡介
code-maat 是一個**分析 git 歷史的命令列工具**，由 Adam Tornhill 開發（《Your Code as a Crime Scene》作者）。

### 核心能力
code-maat 可以從 git log 中提取以下資訊：

```
輸入: git log
     ↓
  code-maat 分析
     ↓
輸出: CSV 格式的分析結果
```

#### 1. 變更頻率分析（revisions）
**告訴你**: 哪些檔案改最多次

```csv
entity,n-revs
src/payment_service.rb,245
src/auth_controller.rb,156
src/user_model.rb,89
```

#### 2. 耦合分析（coupling）
**告訴你**: 哪些檔案常一起改

```csv
entity,coupled,degree,average-revs
payment_service.rb,payment_controller.rb,92,245
payment_service.rb,stripe_integration.rb,78,245
```

#### 3. 程式碼變動量分析（churn）
**告訴你**: 每個檔案的程式碼變動量

```csv
entity,added,deleted,commits
src/payment_service.rb,3450,890,245
src/auth_controller.rb,2100,450,156
src/user_model.rb,1200,320,89
```

#### 4. 作者分析（authors / hotspot-authors）
**告訴你**: 誰改了什麼

```csv
entity,n-authors,n-revs
payment_service.rb,8,245
auth_controller.rb,5,156
```

#### 5. 主要開發者（main-dev）
**告訴你**: 每個檔案的主要維護者

```csv
entity,main-dev,added,total-added,ownership
payment_service.rb,Alice,1850,2380,0.78
payment_controller.rb,Bob,890,1200,0.74
```

### 為什麼選擇 code-maat？

| 優點 | 說明 |
|------|------|
| ✅ **專注時序分析** | 專門設計來分析演化模式 |
| ✅ **成熟穩定** | 工業界驗證，書籍支持 |
| ✅ **輕量獨立** | 單一 JAR 檔，無複雜依賴 |
| ✅ **標準輸出** | CSV 格式，易於解析 |
| ✅ **豐富分析** | 提供 15+ 種分析類型 |

---

## 為什麼要整合 code-maat？

### 問題：SourceAtlas 缺少時間維度

**當前 SourceAtlas (v2.5)**：
```
/overview → 程式碼「是什麼」（結構、語義）
/pattern  → 程式碼「怎麼組織」（模式、架構）
```

**缺少**：
```
❌ 程式碼「怎麼演化」（歷史）
❌ 程式碼「哪裡活躍」（熱點）
❌ 程式碼「誰在維護」（專家）
```

### 解決方案：加入時序分析

**新增命令**：
```
/changes → 歷史查詢（變更頻率、專家、熱點）
/impact  → 影響分析（耦合、風險）
/expert  → 專家查詢（找人、知識地圖）
```

### 真實使用場景

#### 場景 1：接到新任務
```
開發者: /task payment priority
系統: 
  核心檔案: payment_service.rb (245次變更)
  專家: Alice (78%貢獻)
  參考: "多幣別支付"功能 (2個月前)
  警告: stripe_integration 是地雷區
```
→ 顯著減少上手時間

#### 場景 2：準備改代碼
```
開發者: /impact payment_service.rb
系統:
  風險: 🔴 HIGH (245次變更，3次bug)
  必須檢查: payment_controller.rb (90%耦合)
  歷史教訓: 注意幣別轉換問題
```
→ 有效降低出錯率

#### 場景 3：想找人討論
```
開發者: /expert payment
系統:
  Alice: 核心邏輯專家 (78%貢獻)
  Bob: API層專家 (15%貢獻)
  建議: 架構問題找Alice
```
→ 快速找到合適專家

---

## 新增命令設計

### 命令總覽

```
SourceAtlas Commands:

  靜態分析 (v2.5):
    /atlas.overview  → 專案指紋 ✅
    /atlas.pattern   → 模式識別 ✅
    /atlas.impact    → 靜態影響分析（API、類型）⏳

  時序分析 (v2.6 新增 - 簡化版):
    /atlas.changes   → 歷史查詢 + 耦合度分析 + 熱點 + 風險評估
    /atlas.expert    → 專家查詢
```

---

### 1. `/atlas.changes` - 歷史查詢 + 耦合度分析

#### 用途
查詢程式碼的變更歷史、**耦合度分析**、熱點、風險評估等完整時序資訊。

**整合功能**（簡化版設計）：
- ✅ 變更頻率分析（哪些檔案改最多）
- ✅ **耦合度分析**（哪些檔案常一起改）← 整合原 `/atlas.coupling`
- ✅ 熱點識別（高風險區域）
- ✅ 風險評估（基於歷史 bug 和變更模式）
- ✅ PR 影響分析（基於歷史耦合度）
- ✅ 專家資訊（誰改了什麼）

#### 語法
```bash
/atlas.changes <target> [options]

target: 檔案路徑 | 模組名稱 | . (整個專案)
options:
  --who        顯示專家資訊
  --hotspots   顯示熱點排名
  --since <期間>  限制時間範圍 (例: 30d, 3m, 1y)
  --coupling   顯示耦合關係
```

#### 使用範例

**基本用法 - 檔案歷史**
```bash
/atlas.changes src/payment_service.rb
```

**輸出 YAML 格式**：
```yaml
file: src/payment_service.rb
analysis_type: changes

summary:
  total_revisions: 245
  n_authors: 8
  first_commit: 2023-01-15
  last_commit: 2024-11-21
  change_frequency: 9.6 commits/week
  
authors:
  primary:
    name: Alice
    contribution_pct: 78
    lines_added: 1850
    lines_total: 2380
    
  secondary:
    name: Bob
    contribution_pct: 15
    lines_added: 356
    
bug_history:
  - issue: "Bug #1234: 計算錯誤"
    date: 2024-08-15
    root_cause: "沒處理null值"
    fixed_by: Alice
    commit: a3b4c5d
    
  - issue: "Bug #2345: 性能問題"
    date: 2024-09-20
    root_cause: "N+1 query"
    fixed_by: Bob
    commit: e7f8g9h
    
recent_changes:
  - date: 2024-11-21
    author: Alice
    message: "Add promotional discount logic"
    files_changed: 4
    suspicion_level: high  # 因為最近改動
    
  - date: 2024-11-15
    author: Bob
    message: "Refactor calculate_total method"
    files_changed: 2
    
coupling:
  high:  # >0.8
    - file: payment_controller.rb
      degree: 0.92
      reason: "18/20次一起改"
      
  medium:  # 0.5-0.8
    - file: stripe_webhook.rb
      degree: 0.65
      reason: "常需要同步更新"
      
risk_assessment:
  level: high
  score: 8.5
  factors:
    - "245次變更（熱點）"
    - "8位作者（複雜協作）"
    - "3次bug歷史"
    - "高耦合度（12個檔案）"
```

**進階用法 - 找專家**
```bash
/atlas.changes payment --who
```

**輸出**：
```yaml
module: payment
analysis_type: experts

experts:
  primary:
    - name: Alice
      contribution_pct: 78
      files:
        - payment_service.rb (245 commits)
        - stripe_integration.rb (89 commits)
      expertise: ["核心邏輯", "第三方整合"]
      last_active: 3 days ago
      best_for: "架構問題、複雜邏輯"
      
  secondary:
    - name: Bob
      contribution_pct: 15
      files:
        - payment_controller.rb (156 commits)
      expertise: ["API層", "前端對接"]
      last_active: 1 week ago
      best_for: "API設計問題"
      
team_knowledge_map:
  alice: [payment, stripe, billing]
  bob: [api, controller, webhook]
  charlie: [legacy_system]
  
knowledge_risk:
  level: high
  reason: "Alice 負責78%，單點故障"
  suggestion: "建議知識轉移給其他成員"
```

**進階用法 - 熱點分析**
```bash
/atlas.changes . --hotspots
```

**輸出**：
```yaml
scope: entire_project
analysis_type: hotspots

hotspots:
  critical:  # 極度活躍 + 高複雜度
    - file: payment_service.rb
      revisions: 245
      authors: 8
      complexity: 8.5
      bugs: 3
      risk_score: 9.2
      recommendation: "立即重構"
      
  high:
    - file: auth_controller.rb
      revisions: 156
      authors: 5
      complexity: 6.2
      bugs: 1
      risk_score: 7.5
      recommendation: "監控，考慮重構"
      
  moderate:
    - file: user_model.rb
      revisions: 89
      authors: 4
      complexity: 4.3
      bugs: 0
      risk_score: 4.8
      recommendation: "目前穩定"
      
project_health:
  hotspot_count: 12
  critical_count: 2
  overall_score: 65
  trend: "惡化"  # 熱點數量增加中
```

---

### 2. `/atlas.expert` - 專家查詢

#### 用途
找出模組或檔案的專家，以及反向查詢開發者的專長領域。

#### 語法
```bash
/atlas.expert <query>

query:
  - 模組名稱（例: payment）
  - 檔案路徑（例: payment_service.rb）
  - 開發者名稱（例: Alice）- 反向查詢
```

#### 使用範例

**找模組專家**
```bash
/atlas.expert payment
```

**輸出**：
```yaml
query: payment
query_type: module
analysis_type: expertise

experts:
  tier_1:  # 核心專家
    - name: Alice
      contribution_pct: 78
      total_commits: 245
      files:
        - payment_service.rb (156 commits)
        - stripe_integration.rb (89 commits)
      expertise_areas:
        - "核心支付邏輯"
        - "Stripe 整合"
        - "金額計算與貨幣轉換"
      activity:
        last_commit: 2024-11-21
        status: "活躍"
        recent_work: "促銷折扣功能"
      best_for:
        - "架構設計問題"
        - "複雜業務邏輯"
        - "Stripe API 問題"
      contact_suggestion: "首選專家，任何問題都可找她"
      
  tier_2:  # 次要專家
    - name: Bob
      contribution_pct: 15
      total_commits: 67
      files:
        - payment_controller.rb (45 commits)
        - payment_webhook.rb (22 commits)
      expertise_areas:
        - "API 層設計"
        - "Webhook 處理"
        - "前端對接"
      activity:
        last_commit: 2024-11-15
        status: "活躍"
      best_for:
        - "API 設計問題"
        - "前後端整合"
        - "Webhook 事件"
      contact_suggestion: "API 相關問題找他最快"
      
  tier_3:  # 歷史貢獻者
    - name: Charlie
      contribution_pct: 7
      total_commits: 23
      files:
        - legacy_payment_processor.rb (23 commits)
      expertise_areas:
        - "舊系統知識"
      activity:
        last_commit: 2024-05-10
        status: "不活躍（6個月未動）"
      best_for:
        - "歷史遺留問題"
      contact_suggestion: "可能記憶模糊，非必要不打擾"
      
team_collaboration:
  alice_bob_coupling: 0.45
  note: "Alice 和 Bob 常合作（45%的commit有協作）"
  
knowledge_distribution:
  concentration: high
  primary_expert_ownership: 78%
  risk_level: high
  assessment: "知識過度集中在 Alice"
  
recommendations:
  - type: "知識轉移"
    priority: high
    action: "建議讓 Bob 參與更多核心邏輯開發"
    reason: "降低 Alice 的單點故障風險"
    
  - type: "文檔化"
    priority: medium
    action: "Alice 應撰寫核心邏輯文檔"
    reason: "減少知識依賴"
    
suggested_reviewers:
  for_architecture: ["Alice"]
  for_api: ["Bob"]
  for_comprehensive: ["Alice", "Bob"]
```

**反向查詢 - 開發者的專長**
```bash
/atlas.expert Alice
```

**輸出**：
```yaml
query: Alice
query_type: developer
analysis_type: expertise_map

developer_profile:
  name: Alice
  total_contributions: 1850 lines
  active_period: 2023-01 to 2024-11
  activity_level: high
  
expertise_areas:
  primary:  # >50% 貢獻
    - module: payment
      contribution_pct: 78
      files:
        - payment_service.rb (156 commits, 1200 lines)
        - stripe_integration.rb (89 commits, 650 lines)
      skills: ["核心邏輯", "Stripe API", "金額計算"]
      
  secondary:  # 20-50% 貢獻
    - module: billing
      contribution_pct: 35
      files:
        - invoice_generator.rb (45 commits, 380 lines)
      skills: ["發票生成", "計費邏輯"]
      
  occasional:  # <20% 貢獻
    - module: auth
      contribution_pct: 12
      files:
        - oauth_controller.rb (8 commits, 120 lines)
      skills: ["OAuth 整合"]
      
collaboration_pattern:
  frequent_collaborators:
    - name: Bob
      co_commit_rate: 0.45
      modules: [payment, webhook]
      
  mentoring:
    - name: David
      pattern: "常在 Alice 改動後進行小修改"
      assessment: "可能是 Alice 在指導 David"
      
recent_focus:
  last_30_days:
    - area: payment
      commits: 12
      focus: "促銷折扣功能"
      
  trending: "payment 模組持續投入"
  
working_style:
  commit_frequency: 9.6 commits/week
  commit_size: medium (平均80行/commit)
  code_review_activity: high
  bug_fix_ratio: 0.15  # 15%的commit是bug修復
  
best_to_ask_about:
  - "Payment 系統的任何問題"
  - "Stripe 整合與 API 使用"
  - "金額計算與精度問題"
  - "Billing 與發票生成"
  
not_best_for:
  - "Frontend 問題（很少碰）"
  - "Infrastructure（沒碰過）"
  
contact_recommendations:
  availability: "活躍開發者，回應快"
  communication_style: "技術導向，喜歡具體問題"
  when_to_contact: "架構設計階段、複雜bug調查"
```

---

## 技術架構

### 整體架構圖

```
┌─────────────────────────────────────────────────────────────┐
│                        Claude Code                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                   SourceAtlas Skill                  │  │
│  │                                                       │  │
│  │  Commands:                                           │  │
│  │  /overview  /pattern  /changes  /impact  /expert    │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│                           ↓                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              SourceAtlas Scripts                     │  │
│  │                                                       │  │
│  │  collect_changes.sh                                  │  │
│  │  analyze_impact.sh                                   │  │
│  │  find_experts.sh                                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│                           ↓                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                   code-maat                          │  │
│  │              (JAR executable)                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                  │
│                           ↓                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                   Git Repository                     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 資料流

```
1. 開發者輸入命令
   /changes payment_service.rb
         ↓
2. Claude 觸發對應 Script
   collect_changes.sh payment_service.rb
         ↓
3. Script 執行 git log
   git log --numstat --format=... > /tmp/git.log
         ↓
4. Script 執行 code-maat
   maat -l /tmp/git.log -c git2 -a revisions
   maat -l /tmp/git.log -c git2 -a coupling
   maat -l /tmp/git.log -c git2 -a authors
         ↓
5. Script 組合結果輸出 YAML
   file: payment_service.rb
   total_revisions: 245
   authors: [...]
   coupling: [...]
         ↓
6. Claude 解讀 YAML
   根據 YAML 數據 + AI 理解
   生成自然語言分析報告
         ↓
7. 回應開發者
   [詳細的分析報告]
```

### 檔案結構

```
sourceatlas/
├── SKILL.md                    # Skill 定義（已存在）
├── scripts/
│   ├── common/
│   │   ├── config.sh          # 共用配置
│   │   ├── codemaat.sh        # code-maat wrapper
│   │   ├── git_utils.sh       # git 操作工具
│   │   └── yaml_builder.sh    # YAML 輸出工具
│   │
│   ├── changes/
│   │   ├── collect_changes.sh      # /changes 主腳本
│   │   ├── analyze_revisions.sh    # 變更頻率分析
│   │   ├── analyze_coupling.sh     # 耦合分析
│   │   ├── analyze_authors.sh      # 作者分析
│   │   └── analyze_hotspots.sh     # 熱點分析
│   │
│   ├── impact/
│   │   ├── analyze_impact.sh       # /impact 主腳本
│   │   ├── check_dependencies.sh   # 依賴檢查
│   │   ├── predict_failures.sh     # 失敗預測
│   │   └── risk_assessment.sh      # 風險評估
│   │
│   └── expert/
│       ├── find_experts.sh         # /expert 主腳本
│       ├── expertise_map.sh        # 專長地圖
│       └── knowledge_risk.sh       # 知識風險
│
└── tests/
    └── test_scripts.sh        # 測試腳本
```

---

## code-maat 整合方案

### 安裝與配置

#### 1. 下載 code-maat

```bash
# 到 GitHub releases 頁面下載
# https://github.com/adamtornhill/code-maat/releases

# 或用 wget
wget https://github.com/adamtornhill/code-maat/releases/download/v1.0.4/code-maat-1.0.4-standalone.jar

# 移動到合適位置
mkdir -p ~/.sourceatlas/bin
mv code-maat-1.0.4-standalone.jar ~/.sourceatlas/bin/
```

#### 2. 配置別名

在 `~/.zshrc` 或 `~/.bashrc` 加入：

```bash
# code-maat 別名
export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
alias maat='java -jar $CODEMAAT_JAR'
```

重新載入配置：
```bash
source ~/.zshrc
```

驗證安裝：
```bash
maat -h
# 應該顯示 code-maat 的幫助訊息
```

#### 3. 在 Scripts 中使用

**方法 A：直接使用別名**（需要先 source）
```bash
#!/bin/bash
# 在 script 開頭
if ! command -v maat &> /dev/null; then
    echo "Error: code-maat not found. Please install it first."
    exit 1
fi

# 使用
maat -l git.log -c git2 -a revisions > revisions.csv
```

**方法 B：使用環境變數**（推薦）
```bash
#!/bin/bash
# 在 config.sh 中定義
CODEMAAT_JAR="${CODEMAAT_JAR:-$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar}"

# 檢查檔案存在
if [ ! -f "$CODEMAAT_JAR" ]; then
    echo "Error: code-maat JAR not found at $CODEMAAT_JAR"
    exit 1
fi

# 使用
java -jar "$CODEMAAT_JAR" -l git.log -c git2 -a revisions > revisions.csv
```

### code-maat 核心用法

#### 基本流程

```bash
# Step 1: 產生 git log
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%an' \
    --no-renames > /tmp/git.log

# Step 2: 執行 code-maat 分析
java -jar code-maat.jar \
    -l /tmp/git.log \
    -c git2 \
    -a <analysis-type> \
    > output.csv
```

#### 常用分析類型

**1. revisions - 變更頻率**
```bash
maat -l git.log -c git2 -a revisions > revisions.csv

# 輸出格式
# entity,n-revs
# src/payment_service.rb,245
# src/auth_controller.rb,156
```

**2. churn - 程式碼變動量**
```bash
maat -l git.log -c git2 -a churn > churn.csv

# 輸出格式
# entity,added,deleted,commits
# src/payment_service.rb,3450,890,245
# src/auth_controller.rb,2100,450,156
```

**3. coupling - 耦合分析**
```bash
maat -l git.log -c git2 -a coupling > coupling.csv

# 輸出格式
# entity,coupled,degree,average-revs
# payment_service.rb,payment_controller.rb,92,245
# payment_service.rb,stripe_integration.rb,78,245
```

**4. authors - 作者分析**
```bash
maat -l git.log -c git2 -a authors > authors.csv

# 輸出格式
# entity,n-authors,n-revs
# payment_service.rb,8,245
```

**5. main-dev - 主要開發者**
```bash
maat -l git.log -c git2 -a main-dev > main-dev.csv

# 輸出格式
# entity,main-dev,added,total-added,ownership
# payment_service.rb,Alice,1850,2380,0.78
```

**6. entity-ownership - 知識分布**
```bash
maat -l git.log -c git2 -a entity-ownership > ownership.csv

# 輸出格式
# entity,author,added,deleted
# payment_service.rb,Alice,1850,230
# payment_service.rb,Bob,356,89
```

**7. soc - 變更集中度（Sum of Coupling）**
```bash
maat -l git.log -c git2 -a soc > soc.csv

# 輸出格式
# entity,soc
# payment_service.rb,456  # 數字越高，越常跟其他檔案一起改
```

#### 參數說明

```bash
-l, --log <file>           # Git log 檔案
-c, --version-control <vcs> # 版本控制系統 (git2)
-a, --analysis <type>      # 分析類型
-n, --min-revs <num>       # 最小變更次數 (預設5)
-i, --min-coupling <num>   # 最小耦合度 (預設30)
-r, --rows <num>           # 限制輸出行數
-o, --output <file>        # 輸出檔案
```

### 整合範例：完整的分析腳本

```bash
#!/bin/bash
# analyze_file.sh - 分析單一檔案的完整資訊

FILE=$1
REPO_ROOT=$(git rev-parse --show-toplevel)
TMP_DIR="/tmp/sourceatlas-$$"
mkdir -p "$TMP_DIR"

# 產生 git log
cd "$REPO_ROOT"
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%an' \
    --no-renames \
    -- "$FILE" > "$TMP_DIR/git.log"

# 執行多種分析
maat -l "$TMP_DIR/git.log" -c git2 -a revisions > "$TMP_DIR/revisions.csv"
maat -l "$TMP_DIR/git.log" -c git2 -a authors > "$TMP_DIR/authors.csv"
maat -l "$TMP_DIR/git.log" -c git2 -a main-dev > "$TMP_DIR/main-dev.csv"

# 全專案的 coupling 分析（需要完整 log）
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%an' \
    --no-renames > "$TMP_DIR/full-git.log"
maat -l "$TMP_DIR/full-git.log" -c git2 -a coupling | \
    grep "$FILE" > "$TMP_DIR/coupling.csv"

# 解析結果並輸出 YAML
cat << EOF
file: $FILE
analysis_date: $(date -I)

revisions:
  total: $(awk -F, 'NR==2 {print $2}' "$TMP_DIR/revisions.csv")
  
authors:
$(awk -F, 'NR>1 {print "  - name: " $1 "\n    commits: " $3}' "$TMP_DIR/authors.csv")

main_developer:
$(awk -F, 'NR==2 {print "  name: " $2 "\n  ownership: " $5}' "$TMP_DIR/main-dev.csv")

coupling:
$(awk -F, 'NR>1 {print "  - file: " $2 "\n    degree: " $3}' "$TMP_DIR/coupling.csv")
EOF

# 清理
rm -rf "$TMP_DIR"
```

---

## Scripts 開發規範

### 通用規範

#### 1. Shebang 與設定

所有 script 開頭：
```bash
#!/bin/bash
set -euo pipefail  # 錯誤即停止，未定義變數視為錯誤

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
```

#### 2. 配置管理

使用共用配置檔 `scripts/common/config.sh`:
```bash
#!/bin/bash
# scripts/common/config.sh

# code-maat 配置
CODEMAAT_JAR="${CODEMAAT_JAR:-$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar}"

# 暫存目錄
TMP_DIR="${TMP_DIR:-/tmp/sourceatlas}"
mkdir -p "$TMP_DIR"

# 最小變更次數閾值
MIN_REVISIONS=5

# 最小耦合度閾值
MIN_COUPLING=30

# 檢查 code-maat
check_codemaat() {
    if [ ! -f "$CODEMAAT_JAR" ]; then
        echo "Error: code-maat not found at $CODEMAAT_JAR" >&2
        echo "Please download it from: https://github.com/adamtornhill/code-maat/releases" >&2
        return 1
    fi
}

# 執行 code-maat
run_maat() {
    local log_file=$1
    local analysis=$2
    java -jar "$CODEMAAT_JAR" -l "$log_file" -c git2 -a "$analysis"
}
```

#### 3. Git 操作工具

`scripts/common/git_utils.sh`:
```bash
#!/bin/bash
# scripts/common/git_utils.sh

# 獲取 repo 根目錄
get_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

# 檢查是否在 git repo 中
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
}

# 產生 git log（針對特定檔案）
generate_git_log() {
    local file=$1
    local output=$2
    local since=${3:-}  # 可選：時間範圍
    
    local args=(
        --all
        --numstat
        --date=short
        --pretty=format:'--%h--%ad--%an'
        --no-renames
    )
    
    if [ -n "$since" ]; then
        args+=(--since="$since")
    fi
    
    if [ -n "$file" ]; then
        args+=(-- "$file")
    fi
    
    git log "${args[@]}" > "$output"
}

# 產生完整專案的 git log
generate_full_log() {
    local output=$1
    local since=${2:-}
    
    generate_git_log "" "$output" "$since"
}

# 獲取最近的 commits
get_recent_commits() {
    local file=$1
    local count=${2:-10}
    
    git log --oneline -n "$count" -- "$file"
}

# 獲取檔案的 bug fix commits
get_bug_fixes() {
    local file=$1
    
    git log --all --grep='fix\|bug\|Fix\|Bug' \
        --pretty=format:'%h|%ad|%an|%s' \
        --date=short \
        -- "$file"
}
```

#### 4. YAML 建構工具

`scripts/common/yaml_builder.sh`:
```bash
#!/bin/bash
# scripts/common/yaml_builder.sh

# 開始 YAML 文件
yaml_start() {
    echo "---"
}

# 添加鍵值對
yaml_add() {
    local key=$1
    local value=$2
    local indent=${3:-0}
    
    local spaces=$(printf '%*s' $indent '')
    echo "${spaces}${key}: ${value}"
}

# 添加列表項
yaml_add_list_item() {
    local value=$1
    local indent=${2:-0}
    
    local spaces=$(printf '%*s' $indent '')
    echo "${spaces}- ${value}"
}

# 添加區塊
yaml_add_block() {
    local key=$1
    local indent=${2:-0}
    
    local spaces=$(printf '%*s' $indent '')
    echo "${spaces}${key}:"
}

# CSV 轉 YAML 列表
csv_to_yaml_list() {
    local csv_file=$1
    local key_name=$2
    local indent=${3:-2}
    
    local spaces=$(printf '%*s' $indent '')
    
    awk -F, -v spaces="$spaces" -v key="$key_name" '
    NR > 1 {
        print spaces "- " key ": " $1
        for (i = 2; i <= NF; i++) {
            print spaces "  field" i ": " $i
        }
    }
    ' "$csv_file"
}
```

### 命令專屬 Scripts

#### 1. `/changes` Script

`scripts/changes/collect_changes.sh`:
```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../common/config.sh"
source "$SCRIPT_DIR/../common/git_utils.sh"
source "$SCRIPT_DIR/../common/yaml_builder.sh"

# 使用說明
usage() {
    cat << EOF
Usage: $SCRIPT_NAME <target> [options]

Arguments:
  target              File path or module name

Options:
  --who              Show expert information
  --hotspots         Show hotspots ranking
  --since <period>   Limit time range (e.g., 30d, 3m, 1y)
  --coupling         Show coupling relationships

Examples:
  $SCRIPT_NAME src/payment_service.rb
  $SCRIPT_NAME payment --who
  $SCRIPT_NAME . --hotspots
EOF
    exit 1
}

# 解析參數
TARGET=""
MODE="basic"  # basic, who, hotspots, coupling
SINCE=""

while [ $# -gt 0 ]; do
    case $1 in
        --who) MODE="who"; shift ;;
        --hotspots) MODE="hotspots"; shift ;;
        --coupling) MODE="coupling"; shift ;;
        --since) SINCE="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) TARGET="$1"; shift ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo "Error: target is required" >&2
    usage
fi

# 檢查環境
check_git_repo || exit 1
check_codemaat || exit 1

# 建立暫存目錄
SESSION_TMP="$TMP_DIR/changes-$$"
mkdir -p "$SESSION_TMP"

# 清理函數
cleanup() {
    rm -rf "$SESSION_TMP"
}
trap cleanup EXIT

# 產生 git log
REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

if [ "$TARGET" = "." ]; then
    # 整個專案
    generate_full_log "$SESSION_TMP/git.log" "$SINCE"
    FILE_FILTER=""
else
    # 特定檔案
    generate_git_log "$TARGET" "$SESSION_TMP/git.log" "$SINCE"
    FILE_FILTER="$TARGET"
fi

# 根據模式執行不同分析
case $MODE in
    basic)
        # 基本分析：revisions + authors + coupling
        run_maat "$SESSION_TMP/git.log" revisions > "$SESSION_TMP/revisions.csv"
        run_maat "$SESSION_TMP/git.log" authors > "$SESSION_TMP/authors.csv"
        run_maat "$SESSION_TMP/git.log" main-dev > "$SESSION_TMP/main-dev.csv"
        
        # 需要完整 log 來分析 coupling
        if [ -n "$FILE_FILTER" ]; then
            generate_full_log "$SESSION_TMP/full.log" "$SINCE"
            run_maat "$SESSION_TMP/full.log" coupling | \
                grep "$FILE_FILTER" > "$SESSION_TMP/coupling.csv" || true
        fi
        
        # 獲取 bug fixes
        get_bug_fixes "$TARGET" > "$SESSION_TMP/bugs.txt"
        
        # 獲取最近 commits
        get_recent_commits "$TARGET" 10 > "$SESSION_TMP/recent.txt"
        
        # 組合輸出 YAML
        yaml_start
        yaml_add "file" "$TARGET"
        yaml_add "analysis_type" "changes"
        yaml_add "analysis_date" "$(date -I)"
        
        yaml_add_block "summary"
        # 解析 revisions
        total_revs=$(awk -F, 'NR==2 {print $2}' "$SESSION_TMP/revisions.csv")
        yaml_add "total_revisions" "$total_revs" 2
        
        # 解析 authors
        n_authors=$(awk -F, 'NR==2 {print $2}' "$SESSION_TMP/authors.csv")
        yaml_add "n_authors" "$n_authors" 2
        
        # 更多細節...
        ;;
        
    who)
        # 專家分析
        source "$SCRIPT_DIR/analyze_authors.sh"
        analyze_experts "$TARGET" "$SESSION_TMP" "$SINCE"
        ;;
        
    hotspots)
        # 熱點分析
        source "$SCRIPT_DIR/analyze_hotspots.sh"
        analyze_hotspots "$SESSION_TMP" "$SINCE"
        ;;
        
    coupling)
        # 耦合分析
        source "$SCRIPT_DIR/analyze_coupling.sh"
        analyze_coupling "$TARGET" "$SESSION_TMP" "$SINCE"
        ;;
esac
```

#### 2. `/impact` Script

`scripts/impact/analyze_impact.sh`:
```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../common/config.sh"
source "$SCRIPT_DIR/../common/git_utils.sh"
source "$SCRIPT_DIR/../common/yaml_builder.sh"

# 使用說明
usage() {
    cat << EOF
Usage: $SCRIPT_NAME <target>

Arguments:
  target    File path, method (file::method), or PR number (PR#123)

Examples:
  $SCRIPT_NAME src/payment_service.rb
  $SCRIPT_NAME src/payment_service.rb::calculate_total
  $SCRIPT_NAME PR#123
EOF
    exit 1
}

TARGET=$1
if [ -z "$TARGET" ]; then
    usage
fi

# 檢查環境
check_git_repo || exit 1
check_codemaat || exit 1

SESSION_TMP="$TMP_DIR/impact-$$"
mkdir -p "$SESSION_TMP"

cleanup() {
    rm -rf "$SESSION_TMP"
}
trap cleanup EXIT

REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# 判斷 target 類型
if [[ $TARGET == PR#* ]]; then
    # PR 分析
    PR_NUM=${TARGET#PR#}
    analyze_pr_impact "$PR_NUM" "$SESSION_TMP"
else
    # 檔案分析
    FILE_PATH=$TARGET
    analyze_file_impact "$FILE_PATH" "$SESSION_TMP"
fi

# 分析檔案影響
analyze_file_impact() {
    local file=$1
    local tmp=$2
    
    # 1. 靜態依賴分析（用 grep 或 tree-sitter）
    echo "Analyzing static dependencies..." >&2
    find_static_dependencies "$file" > "$tmp/static_deps.txt"
    
    # 2. 時序耦合分析
    echo "Analyzing temporal coupling..." >&2
    generate_full_log "$tmp/full.log"
    run_maat "$tmp/full.log" coupling | \
        grep "$file" | \
        awk -F, '$3 >= 80' > "$tmp/high_coupling.csv"
    run_maat "$tmp/full.log" coupling | \
        grep "$file" | \
        awk -F, '$3 >= 50 && $3 < 80' > "$tmp/medium_coupling.csv"
    
    # 3. 歷史問題分析
    echo "Analyzing historical issues..." >&2
    get_bug_fixes "$file" > "$tmp/bugs.txt"
    
    # 4. 風險評估
    echo "Calculating risk score..." >&2
    calculate_risk_score "$file" "$tmp" > "$tmp/risk.txt"
    
    # 5. 測試影響分析
    echo "Analyzing test impact..." >&2
    find_related_tests "$file" > "$tmp/tests.txt"
    
    # 6. 組合輸出
    yaml_start
    yaml_add "target" "$file"
    yaml_add "analysis_type" "impact"
    
    yaml_add_block "risk_assessment"
    risk_level=$(cat "$tmp/risk.txt")
    yaml_add "overall_risk" "$risk_level" 2
    
    # ... 更多細節
}

# 計算風險分數
calculate_risk_score() {
    local file=$1
    local tmp=$2
    
    # 因素1: 變更頻率
    generate_git_log "$file" "$tmp/file.log"
    revisions=$(run_maat "$tmp/file.log" revisions | awk -F, 'NR==2 {print $2}')
    
    # 因素2: 作者數量
    authors=$(run_maat "$tmp/file.log" authors | awk -F, 'NR==2 {print $2}')
    
    # 因素3: Bug 數量
    bugs=$(wc -l < "$tmp/bugs.txt")
    
    # 因素4: 耦合度
    coupling_count=$(wc -l < "$tmp/high_coupling.csv")
    
    # 簡單的評分算法
    score=0
    [ "$revisions" -gt 200 ] && score=$((score + 3))
    [ "$revisions" -gt 100 ] && score=$((score + 2))
    [ "$authors" -gt 5 ] && score=$((score + 2))
    [ "$bugs" -gt 2 ] && score=$((score + 3))
    [ "$coupling_count" -gt 5 ] && score=$((score + 2))
    
    if [ "$score" -ge 8 ]; then
        echo "high"
    elif [ "$score" -ge 5 ]; then
        echo "medium"
    else
        echo "low"
    fi
}

# 尋找靜態依賴（簡化版）
find_static_dependencies() {
    local file=$1
    
    # Ruby requires
    grep -h "require.*['\"].*$file" **/*.rb 2>/dev/null || true
    
    # Import statements (可擴展支持更多語言)
}

# 尋找相關測試
find_related_tests() {
    local file=$1
    local basename=$(basename "$file" .rb)
    
    # 尋找 spec 或 test 檔案
    find . -type f \( -name "*${basename}*spec.rb" -o -name "*${basename}*test.rb" \)
}

# PR 分析（支援 GitHub 和 GitLab）
analyze_pr_impact() {
    local pr_num=$1
    local tmp=$2
    
    echo "Analyzing PR#$pr_num..." >&2
    
    # 檢測使用哪個平台
    local platform=""
    local remote_url=$(git config --get remote.origin.url)
    
    if [[ $remote_url == *"github.com"* ]]; then
        platform="github"
    elif [[ $remote_url == *"gitlab"* ]]; then
        platform="gitlab"
    else
        echo "Error: Cannot detect platform. Only GitHub and GitLab are supported." >&2
        exit 1
    fi
    
    # 根據平台使用不同的 CLI
    if [ "$platform" = "github" ]; then
        # 使用 GitHub CLI (gh)
        if ! command -v gh &> /dev/null; then
            echo "Error: gh CLI not found. Please install it:" >&2
            echo "  https://cli.github.com/" >&2
            exit 1
        fi
        
        gh pr view "$pr_num" --json files,title,additions,deletions > "$tmp/pr.json"
        
    elif [ "$platform" = "gitlab" ]; then
        # 使用 GitLab CLI (glab)
        if ! command -v glab &> /dev/null; then
            echo "Error: glab CLI not found. Please install it:" >&2
            echo "  https://gitlab.com/gitlab-org/cli" >&2
            exit 1
        fi
        
        # 提取 project ID 和 MR number
        glab mr view "$pr_num" --json files,title > "$tmp/pr.json"
    fi
    
    # 提取改動的檔案（JSON 解析）
    # 使用 jq 或 python 解析 JSON
    if command -v jq &> /dev/null; then
        jq -r '.files[].path' "$tmp/pr.json" > "$tmp/changed_files.txt"
    else
        # 使用 python 作為備選
        python3 -c "
import json
import sys
with open('$tmp/pr.json') as f:
    data = json.load(f)
    for file in data.get('files', []):
        print(file.get('path', ''))
" > "$tmp/changed_files.txt"
    fi
    
    # 分析每個檔案的影響
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        analyze_file_impact "$file" "$tmp" >> "$tmp/file_impacts.yaml"
    done < "$tmp/changed_files.txt"
    
    # 輸出綜合分析
    yaml_start
    yaml_add "target" "PR#$pr_num"
    yaml_add "platform" "$platform"
    yaml_add "analysis_type" "pr_impact"
    
    # ... 更多分析細節
}

# 執行主邏輯
if [[ $TARGET == PR#* ]]; then
    PR_NUM=${TARGET#PR#}
    analyze_pr_impact "$PR_NUM" "$SESSION_TMP"
else
    analyze_file_impact "$TARGET" "$SESSION_TMP"
fi
```

#### 3. `/expert` Script

`scripts/expert/find_experts.sh`:
```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../common/config.sh"
source "$SCRIPT_DIR/../common/git_utils.sh"
source "$SCRIPT_DIR/../common/yaml_builder.sh"

usage() {
    cat << EOF
Usage: $SCRIPT_NAME <query>

Arguments:
  query    Module name, file path, or developer name

Examples:
  $SCRIPT_NAME payment
  $SCRIPT_NAME src/payment_service.rb
  $SCRIPT_NAME Alice  (reverse query)
EOF
    exit 1
}

QUERY=$1
if [ -z "$QUERY" ]; then
    usage
fi

check_git_repo || exit 1
check_codemaat || exit 1

SESSION_TMP="$TMP_DIR/expert-$$"
mkdir -p "$SESSION_TMP"

cleanup() {
    rm -rf "$SESSION_TMP"
}
trap cleanup EXIT

REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# 判斷查詢類型
if [ -f "$QUERY" ] || [[ $QUERY == */* ]]; then
    # 檔案或模組查詢
    find_file_experts "$QUERY" "$SESSION_TMP"
else
    # 可能是開發者名稱（反向查詢）
    # 先嘗試找檔案，如果找不到則視為開發者
    if git log --all --author="$QUERY" --oneline | head -1 > /dev/null 2>&1; then
        find_developer_expertise "$QUERY" "$SESSION_TMP"
    else
        # 視為模組名稱
        find_module_experts "$QUERY" "$SESSION_TMP"
    fi
fi

# 找檔案專家
find_file_experts() {
    local file=$1
    local tmp=$2
    
    generate_git_log "$file" "$tmp/file.log"
    
    # 主要開發者
    run_maat "$tmp/file.log" main-dev > "$tmp/main-dev.csv"
    
    # 所有貢獻者
    run_maat "$tmp/file.log" entity-ownership > "$tmp/ownership.csv"
    
    # 輸出 YAML
    yaml_start
    yaml_add "query" "$file"
    yaml_add "query_type" "file"
    yaml_add "analysis_type" "expertise"
    
    yaml_add_block "experts"
    
    # 解析主要開發者
    yaml_add_block "tier_1" 2
    awk -F, 'NR==2 {
        print "    - name: " $2
        print "      contribution_pct: " int($5 * 100)
        print "      lines_added: " $3
    }' "$tmp/main-dev.csv"
    
    # ... 更多細節
}

# 找模組專家
find_module_experts() {
    local module=$1
    local tmp=$2
    
    # 找出模組下的所有檔案
    if [ -d "$module" ]; then
        files=$(find "$module" -type f -name "*.rb" -o -name "*.js" -o -name "*.py")
    else
        # 用 grep 找包含模組名稱的檔案
        files=$(find . -type f \( -name "*.rb" -o -name "*.js" -o -name "*.py" \) -path "*$module*")
    fi
    
    if [ -z "$files" ]; then
        echo "Error: No files found for module $module" >&2
        exit 1
    fi
    
    # 對所有檔案產生 log
    echo "$files" | while read -r file; do
        git log --all --pretty=format:'%an' -- "$file"
    done | sort | uniq -c | sort -rn > "$tmp/contributors.txt"
    
    # 輸出 YAML
    yaml_start
    yaml_add "query" "$module"
    yaml_add "query_type" "module"
    
    yaml_add_block "experts"
    
    # 解析貢獻者（簡化版）
    awk '{
        if (NR <= 3) tier = "tier_1"
        else if (NR <= 6) tier = "tier_2"
        else tier = "tier_3"
        
        if (last_tier != tier) {
            print tier ":"
            last_tier = tier
        }
        print "  - name: " $2
        print "    commits: " $1
    }' "$tmp/contributors.txt"
}

# 找開發者專長（反向查詢）
find_developer_expertise() {
    local developer=$1
    local tmp=$2
    
    # 獲取開發者的所有 commits
    git log --all --author="$developer" --name-only --pretty=format: | \
        sort | uniq -c | sort -rn > "$tmp/files.txt"
    
    # 輸出 YAML
    yaml_start
    yaml_add "query" "$developer"
    yaml_add "query_type" "developer"
    
    yaml_add_block "developer_profile"
    yaml_add "name" "$developer" 2
    
    total_commits=$(git log --all --author="$developer" --oneline | wc -l)
    yaml_add "total_commits" "$total_commits" 2
    
    yaml_add_block "expertise_areas"
    
    # 解析檔案（分組為模組）
    yaml_add_block "primary" 2
    head -5 "$tmp/files.txt" | while read -r count file; do
        [ -z "$file" ] && continue
        echo "    - file: $file"
        echo "      commits: $count"
    done
    
    # ... 更多細節
}
```

---

## 實作指南

### Phase 1: 環境設定

#### 任務清單
- [ ] 下載並安裝 code-maat
- [ ] 配置 shell 別名
- [ ] 測試 code-maat 基本功能
- [ ] 建立 scripts 目錄結構

#### 驗證
```bash
# 測試 code-maat
cd your-test-repo
git log --all --numstat --date=short --pretty=format:'--%h--%ad--%an' > /tmp/test.log
maat -l /tmp/test.log -c git2 -a revisions

# 應該看到 CSV 輸出
```

---

### Phase 2: 共用工具開發

#### 任務清單
- [ ] 實作 `scripts/common/config.sh`
- [ ] 實作 `scripts/common/git_utils.sh`
- [ ] 實作 `scripts/common/yaml_builder.sh`
- [ ] 撰寫單元測試

#### 測試範例
```bash
# 測試 git_utils.sh
source scripts/common/git_utils.sh
check_git_repo && echo "OK"
get_repo_root
generate_git_log "README.md" "/tmp/test.log"
```

---

### Phase 3: `/changes` 命令

#### 任務清單
- [ ] 實作 `collect_changes.sh` 主腳本
- [ ] 實作基本模式（檔案歷史）
- [ ] 實作 `--who` 模式
- [ ] 實作 `--hotspots` 模式
- [ ] 實作 `--coupling` 模式
- [ ] 整合到 SKILL.md
- [ ] 測試各種場景

#### 測試
```bash
# 基本測試
./scripts/changes/collect_changes.sh src/payment_service.rb

# 專家測試
./scripts/changes/collect_changes.sh payment --who

# 熱點測試
./scripts/changes/collect_changes.sh . --hotspots
```

---

### Phase 4: `/impact` 命令

#### 任務清單
- [ ] 實作 `analyze_impact.sh` 主腳本
- [ ] 實作檔案影響分析
- [ ] 實作風險評估算法
- [ ] 實作 PR 分析（支援 GitHub 和 GitLab）
- [ ] 整合到 SKILL.md
- [ ] 測試

---

### Phase 5: `/expert` 命令

#### 任務清單
- [ ] 實作 `find_experts.sh` 主腳本
- [ ] 實作檔案專家查詢
- [ ] 實作模組專家查詢
- [ ] 實作反向查詢（開發者專長）
- [ ] 整合到 SKILL.md
- [ ] 測試

---

### Phase 6: 整合與優化

#### 任務清單
- [ ] 效能優化（快取、並行處理）
- [ ] 錯誤處理完善
- [ ] 文檔完善
- [ ] 端到端測試
- [ ] 使用者測試

---

## 測試策略

### 單元測試

**測試 git_utils.sh**:
```bash
#!/bin/bash
# tests/test_git_utils.sh

source scripts/common/git_utils.sh

test_get_repo_root() {
    local root=$(get_repo_root)
    [ -d "$root/.git" ] || {
        echo "FAIL: get_repo_root"
        return 1
    }
    echo "PASS: get_repo_root"
}

test_check_git_repo() {
    check_git_repo || {
        echo "FAIL: check_git_repo"
        return 1
    }
    echo "PASS: check_git_repo"
}

# 執行測試
test_get_repo_root
test_check_git_repo
```

### 整合測試

**測試 /changes 命令**:
```bash
#!/bin/bash
# tests/integration/test_changes.sh

SCRIPT="./scripts/changes/collect_changes.sh"

# 測試1: 基本檔案分析
test_basic_file_analysis() {
    output=$($SCRIPT README.md)
    echo "$output" | grep -q "file: README.md" || {
        echo "FAIL: basic file analysis"
        return 1
    }
    echo "PASS: basic file analysis"
}

# 測試2: 專家查詢
test_expert_query() {
    output=$($SCRIPT src --who)
    echo "$output" | grep -q "experts:" || {
        echo "FAIL: expert query"
        return 1
    }
    echo "PASS: expert query"
}

test_basic_file_analysis
test_expert_query
```

### 測試資料準備

建立測試用 git repository:
```bash
#!/bin/bash
# tests/setup_test_repo.sh

mkdir -p /tmp/test-repo
cd /tmp/test-repo
git init

# 創建測試檔案
cat > payment_service.rb << 'EOF'
class PaymentService
  def calculate_total(amount)
    amount * 1.1
  end
end
EOF

git add payment_service.rb
git commit -m "Initial commit" --author="Alice <alice@example.com>"

# 模擬多次修改
for i in {1..10}; do
    echo "# Change $i" >> payment_service.rb
    git add payment_service.rb
    git commit -m "Update payment service $i" --author="Alice <alice@example.com>"
done

# 模擬其他作者
echo "# Bob's change" >> payment_service.rb
git add payment_service.rb
git commit -m "Bob's update" --author="Bob <bob@example.com>"
```

---

## 部署與維護

### 安裝檢查清單

**用戶端安裝**:
```bash
# 1. 檢查 Java
java -version  # 需要 Java 8+

# 2. 下載 code-maat
wget https://github.com/adamtornhill/code-maat/releases/download/v1.0.4/code-maat-1.0.4-standalone.jar
mkdir -p ~/.sourceatlas/bin
mv code-maat-1.0.4-standalone.jar ~/.sourceatlas/bin/

# 3. 配置環境
echo 'export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"' >> ~/.zshrc
echo 'alias maat="java -jar $CODEMAAT_JAR"' >> ~/.zshrc
source ~/.zshrc

# 4. 驗證
maat -h

# 5. 安裝 GitHub CLI（如果使用 GitHub）
# macOS
brew install gh
# 或從 https://cli.github.com/ 下載

# 驗證並登入
gh auth login

# 6. 安裝 GitLab CLI（如果使用 GitLab）
# macOS
brew install glab
# 或從 https://gitlab.com/gitlab-org/cli 下載

# 驗證並登入
glab auth login

# 7. 安裝 jq（JSON 解析工具，可選）
brew install jq  # macOS
# 或
sudo apt-get install jq  # Ubuntu/Debian
```

**注意**：
- 如果你的專案在 GitHub，需要安裝 `gh`
- 如果你的專案在 GitLab，需要安裝 `glab`
- `jq` 用於解析 PR/MR 資訊，沒有的話會使用 Python 備選方案

### 故障排除

**常見問題**:

1. **code-maat 找不到**
```bash
Error: code-maat not found

解決:
export CODEMAAT_JAR="/path/to/code-maat.jar"
```

2. **Java 版本問題**
```bash
Error: Unsupported class version

解決:
java -version  # 確認 Java 8+
brew install openjdk@11  # macOS
```

3. **git log 太大**
```bash
Error: Out of memory

解決:
# 限制分析範圍
git log --since="6 months ago" ...
```

4. **權限問題**
```bash
Error: Permission denied

解決:
chmod +x scripts/**/*.sh
```

5. **GitHub CLI 認證問題**
```bash
Error: gh: Not authenticated

解決:
gh auth login
# 按照提示完成認證
```

6. **GitLab CLI 認證問題**
```bash
Error: glab: authentication failed

解決:
glab auth login
# 按照提示完成認證
# 或使用 Personal Access Token
export GITLAB_TOKEN="your-token"
```

7. **PR/MR 分析找不到平台**
```bash
Error: Cannot detect platform

解決:
# 檢查 git remote
git remote -v
# 確認 remote URL 包含 github.com 或 gitlab
```

8. **jq 未安裝（JSON 解析失敗）**
```bash
如果沒有 jq，系統會自動使用 Python

如果兩者都沒有:
brew install jq  # macOS
# 或
sudo apt-get install jq  # Ubuntu
```

### 效能優化

**快取策略**:
```bash
# 快取 git log
CACHE_DIR="$HOME/.sourceatlas/cache"
CACHE_FILE="$CACHE_DIR/$(pwd | md5).log"

if [ -f "$CACHE_FILE" ] && [ $(find "$CACHE_FILE" -mmin -60) ]; then
    # 使用快取（60分鐘內）
    cp "$CACHE_FILE" "$TMP_DIR/git.log"
else
    # 重新產生
    generate_full_log "$TMP_DIR/git.log"
    cp "$TMP_DIR/git.log" "$CACHE_FILE"
fi
```

**並行處理**:
```bash
# 並行執行多個分析
{
    run_maat "$log" revisions > revisions.csv &
    run_maat "$log" authors > authors.csv &
    run_maat "$log" coupling > coupling.csv &
    wait
}
```

### 大型 Codebase 的效能考量

> ⚠️ **注意**: 以下功能為待討論的優化方向，尚未實作

對於歷史悠久或大型的 codebase，code-maat 分析可能面臨以下挑戰：

#### 問題識別

**1. 執行時間過長**
```bash
# 大型專案的 git log 可能需要數分鐘
# coupling 分析在大量檔案時特別耗時

範例：10萬+ commits 的專案
- git log 產生: 30-60 秒
- revisions 分析: 10-20 秒
- coupling 分析: 2-5 分鐘
- 總計: 3-6 分鐘
```

**2. 檔案體積過大**
```bash
# git log 輸出可能達到數百 MB
範例：
- 中型專案 (2年歷史): 50-100 MB
- 大型專案 (5年歷史): 200-500 MB
- 超大型專案 (10年+): 1 GB+
```

**3. 記憶體消耗**
```bash
# code-maat 需要載入整個 log 到記憶體
# JVM heap size 可能不足
```

#### 待討論的解決方案

**方案 1: 分批處理（Batching）**

概念：將分析拆分為多個時間範圍
```bash
# 按月份分批
for month in {1..12}; do
    git log --since="2024-$month-01" --until="2024-$month-31" > log_$month.log
    maat -l log_$month.log -c git2 -a revisions > revisions_$month.csv
done

# 合併結果
merge_csv_results revisions_*.csv > revisions_total.csv
```

**優點**：
- 每次處理較小的數據集
- 可以並行處理不同時間段
- 失敗後只需重跑部分批次

**缺點**：
- coupling 分析需要完整歷史
- 需要實作結果合併邏輯
- 可能遺漏跨批次的模式

**方案 2: 多層快取（Multi-tier Cache）**

概念：快取不同粒度的分析結果
```bash
.sourceatlas/cache/
├── git-log/
│   ├── full.log              # 完整 log（定期更新）
│   ├── incremental/
│   │   ├── 2024-11.log      # 月份增量
│   │   └── 2024-12.log
│   └── metadata.json         # 快取元數據
│
├── analysis/
│   ├── revisions.csv         # 完整分析結果
│   ├── coupling.csv
│   └── last_updated.txt
│
└── incremental/
    └── 2024-12/              # 增量分析
        ├── revisions.csv
        └── coupling.csv
```

**快取策略**：
- L1: 記憶體快取（當前 session）
- L2: 檔案快取（60分鐘有效）
- L3: 增量快取（只更新最近的變更）

**方案 3: 增量更新（Incremental Update）**

概念：只分析新的 commits
```bash
# 讀取上次分析的時間戳
LAST_COMMIT=$(cat .sourceatlas/last_analyzed.txt)

# 只抓取新的 commits
git log $LAST_COMMIT..HEAD --numstat > incremental.log

# 分析增量
maat -l incremental.log -c git2 -a revisions > new_revisions.csv

# 合併到現有結果
merge_incremental revisions.csv new_revisions.csv > updated_revisions.csv

# 更新時間戳
git rev-parse HEAD > .sourceatlas/last_analyzed.txt
```

**挑戰**：
- coupling 需要重新計算（因為是相對關係）
- revisions 可以簡單累加
- main-dev 需要重新計算 ownership 百分比

**方案 4: 取樣分析（Sampling）**

概念：只分析部分歷史
```bash
# 選項 A: 最近 N 個月
git log --since="6 months ago" > recent.log

# 選項 B: 取樣 commits（每 N 個取一個）
git log --all | sample_every_n 10 > sampled.log

# 選項 C: 只分析活躍檔案
find_active_files --threshold 10 > active_files.txt
git log -- $(cat active_files.txt) > active.log
```

**適用場景**：
- 快速概覽（不需要精確數據）
- 開發中的即時回饋
- 識別趨勢而非精確值

**方案 5: 資料庫儲存（Database Backend）**

概念：將分析結果存入資料庫
```bash
# SQLite schema
CREATE TABLE revisions (
    file TEXT PRIMARY KEY,
    n_revs INTEGER,
    last_updated TIMESTAMP
);

CREATE TABLE coupling (
    file_a TEXT,
    file_b TEXT,
    degree INTEGER,
    last_updated TIMESTAMP,
    PRIMARY KEY (file_a, file_b)
);

# 增量更新
INSERT OR REPLACE INTO revisions (file, n_revs, last_updated)
VALUES ('payment.rb', 245, CURRENT_TIMESTAMP);
```

**優點**：
- 快速查詢
- 易於增量更新
- 可以建立索引優化效能

**缺點**：
- 增加系統複雜度
- 需要資料庫維護
- 初始建立仍需完整分析

#### 效能基準測試（待補充）

需要在真實專案上測試：

| 專案規模 | Commits | 檔案數 | 當前方案耗時 | 優化後目標 |
|---------|---------|--------|-------------|-----------|
| 小型 | <10K | <500 | ? | <30秒 |
| 中型 | 10K-50K | 500-2K | ? | <2分鐘 |
| 大型 | 50K-100K | 2K-5K | ? | <5分鐘 |
| 超大型 | >100K | >5K | ? | <10分鐘 |

#### 決策建議

**Phase 1 (當前)**：
- ✅ 實作基本快取（60分鐘）
- ✅ 並行處理多個分析
- ⏸️ 暫不處理大型專案優化

**Phase 2 (未來)**：
- 📋 收集真實專案的效能數據
- 📋 根據數據決定優化方向
- 📋 優先實作 ROI 最高的方案

**Phase 3 (長期)**：
- 📋 考慮完整的增量更新系統
- 📋 可能需要資料庫支援
- 📋 提供效能調優選項給使用者

#### 討論要點

以下問題需要在實作前討論：

1. **快取失效策略**
   - 如何判斷快取是否過期？
   - 檔案被修改後如何觸發更新？
   - 快取大小限制？

2. **增量更新的準確性**
   - coupling 必須重新計算嗎？
   - ownership 百分比如何增量更新？
   - 可接受的誤差範圍？

3. **使用者體驗**
   - 第一次執行慢可以接受嗎？
   - 是否需要進度條？
   - 後台更新 vs 即時更新？

4. **資源限制**
   - JVM heap size 設定多少？
   - 磁碟空間預算？
   - 可接受的分析時間上限？

5. **降級策略**
   - 超大專案是否自動切換到取樣模式？
   - 提供「快速模式」vs「完整模式」？
   - 如何通知使用者當前使用的模式？

---

## 附錄

### A. code-maat 主要分析類型與輸出格式

#### 核心分析類型（SourceAtlas 使用）

**1. revisions - 變更頻率分析**
```bash
maat -l git.log -c git2 -a revisions

# 輸出格式
entity,n-revs
src/payment_service.rb,245
src/auth_controller.rb,156
```
- entity: 檔案路徑
- n-revs: 修訂次數

**2. churn - 程式碼變動量分析**
```bash
maat -l git.log -c git2 -a churn

# 輸出格式
entity,added,deleted,commits
src/payment_service.rb,3450,890,245
src/auth_controller.rb,2100,450,156
```
- entity: 檔案路徑
- added: 新增的程式碼行數
- deleted: 刪除的程式碼行數
- commits: 提交次數

**3. coupling - 耦合度分析**
```bash
maat -l git.log -c git2 -a coupling

# 輸出格式
entity,coupled,degree,average-revs
payment_service.rb,payment_controller.rb,92,245
payment_service.rb,stripe_integration.rb,78,245
```
- entity: 主要檔案
- coupled: 耦合的檔案
- degree: 耦合程度（百分比，0-100）
- average-revs: 平均修訂次數

**4. authors / hotspot-authors - 作者分析**
```bash
maat -l git.log -c git2 -a authors

# 輸出格式
entity,n-authors,n-revs
payment_service.rb,8,245
auth_controller.rb,5,156
```
- entity: 檔案路徑
- n-authors: 貢獻者人數
- n-revs: 修訂次數

**5. main-dev - 主要開發者**
```bash
maat -l git.log -c git2 -a main-dev

# 輸出格式
entity,main-dev,added,total-added,ownership
payment_service.rb,Alice,1850,2380,0.78
payment_controller.rb,Bob,890,1200,0.74
```
- entity: 檔案路徑
- main-dev: 主要開發者名稱
- added: 該開發者新增的行數
- total-added: 總新增行數
- ownership: 所有權百分比（0-1）

**6. entity-ownership - 所有權分布**
```bash
maat -l git.log -c git2 -a entity-ownership

# 輸出格式
entity,author,added,deleted
payment_service.rb,Alice,1850,230
payment_service.rb,Bob,356,89
```

#### 其他可用分析類型

```bash
main-dev-by-revs   # 按commit數的主要開發者
entity-effort      # 開發投入
soc                # 耦合總和
abs-churn          # 絕對變更量（廢棄，用 churn 替代）
author-churn       # 作者變更量
entity-churn       # 實體變更量
refactoring-main-dev  # 重構專家
communication      # 溝通模式
fragmentation      # 碎片化程度
identity           # 身份分析
```

### B. Git Log 格式說明

code-maat 使用的特殊格式:
```bash
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%an' \
    --no-renames

輸出範例:
--a3b4c5d--2024-11-21--Alice
10      5       src/payment_service.rb
3       1       src/payment_controller.rb

--e7f8g9h--2024-11-20--Bob
25      8       src/stripe_integration.rb
```

格式說明:
- `--a3b4c5d`: commit hash
- `--2024-11-21`: commit date
- `--Alice`: author name
- `10      5`: 10行新增，5行刪除
- `src/payment_service.rb`: 檔案路徑

### C. YAML 輸出範例

完整的 `/changes` 輸出範例:
```yaml
---
file: src/payment_service.rb
analysis_type: changes
analysis_date: 2024-11-24

summary:
  total_revisions: 245
  n_authors: 8
  first_commit: 2023-01-15
  last_commit: 2024-11-21
  change_frequency: 9.6
  period: 23 months

authors:
  primary:
    name: Alice
    contribution_pct: 78
    lines_added: 1850
    lines_total: 2380
    ownership: 0.78
    
  secondary:
    name: Bob
    contribution_pct: 15
    lines_added: 356
    lines_total: 2380
    
  others:
    count: 6
    contribution_pct: 7

bug_history:
  count: 3
  bugs:
    - issue: "Bug #1234"
      date: 2024-08-15
      root_cause: "Null pointer"
      fixed_by: Alice
      commit: a3b4c5d
      
recent_changes:
  - date: 2024-11-21
    author: Alice
    message: "Add promotional discount"
    files_changed: 4
    suspicion_level: high

coupling:
  high:
    - file: payment_controller.rb
      degree: 92
      evidence: "18/20 times changed together"
      
risk_assessment:
  level: high
  score: 8.5
  factors:
    - "245 revisions (hotspot)"
    - "8 authors (complex)"
    - "3 bugs in history"
```

### D. 參考資源

**code-maat 相關**:
- GitHub: https://github.com/adamtornhill/code-maat
- 書籍: "Your Code as a Crime Scene" by Adam Tornhill
- 書籍: "Software Design X-Rays" by Adam Tornhill

**SourceAtlas 相關**:
- PRD v2.5.2
- SKILL.md

**Shell Script 最佳實踐**:
- Google Shell Style Guide
- ShellCheck: https://www.shellcheck.net/

---

## 總結

這份文檔提供了完整的 code-maat 整合方案，包括：

1. **為什麼整合**: 解決 SourceAtlas 缺少時序維度的問題
2. **整合什麼**: 3個新命令（/changes, /impact, /expert）
3. **怎麼整合**: 詳細的技術架構和實作指南
4. **如何開發**: 完整的 Shell Script 範例和規範

**關鍵成功因素**:
- ✅ 使用 code-maat 的成熟能力
- ✅ Shell Script 保持輕量
- ✅ YAML 輸出便於 AI 理解
- ✅ 模組化設計易於維護

**下一步行動**:
1. 閱讀並理解本文檔
2. 設定開發環境（Phase 1）
3. 開發共用工具（Phase 2）
4. 逐步實作三個命令（Phase 3-5）
5. 測試與優化（Phase 6）

有任何問題都可以參考本文檔，或回來討論！
