# SourceAtlas PRD v2.5.2

**AI-Powered Codebase Understanding Assistant**

- **版本**: 2.5.2
- **更新日期**: 2025-11-22
- **狀態**: Active Development (Architecture Finalized)

---

## Executive Summary

SourceAtlas 是一個整合在 Claude Code 中的智慧型程式碼理解助手。通過 **Claude Commands (斜線命令) + 輕量 Scripts** 的架構，在開發者的工作流程中提供即時的專案理解、模式學習和影響分析能力。

**核心定位的轉變**：
- ❌ **不是**：獨立的 CLI 索引工具
- ✅ **而是**：Claude Code 原生的分析助手（Commands）

### 核心特色

- 🎯 **即時探索**：不需要預先索引，按需分析
- 🔄 **Token 優化**：採用 TOON 格式，節省 30-50% tokens
- 🧠 **智慧理解**：AI 動態推理，而非靜態索引
- ⚡ **工作流整合**：融入 Claude Code，無縫使用
- 🛠️ **輕量設計**：Scripts 收集資料，AI 負責理解

---

## 目錄

1. [產品定位](#1-產品定位)
2. [使用場景](#2-使用場景)
3. [產品架構](#3-產品架構)
4. [核心能力](#4-核心能力)
5. [TOON 格式規範](#5-toon-格式規範)
6. [Skill 介面設計](#6-skill-介面設計)
7. [Scripts 設計](#7-scripts-設計)
8. [分析方法論](#8-分析方法論)
9. [實作規範](#9-實作規範)
10. [成功指標](#10-成功指標)
11. [實作路線圖](#11-實作路線圖)

---

## 1. 產品定位

### 1.1 產品演進

```
v2.0 (已完成) - 手動 Prompts 方法論
  ↓
v2.5 (當前) - SourceAtlas Skill
  ├─ Claude Code Skill 整合
  ├─ 輕量 Scripts 輔助
  └─ 即時探索能力
  ↓
v3.0 (未來) - SourceAtlas Monitor
  ├─ 持續追蹤系統
  ├─ 歷史趨勢分析
  └─ 健康度儀表板
```

### 1.2 為什麼選擇 Skill 架構

#### 問題：獨立 CLI 的限制

原始 PRD 設計的獨立 CLI 工具存在以下問題：

| 問題 | 影響 |
|------|------|
| 需要匯出索引 | 開發者需要離開 Claude Code |
| 預先建立索引 | 無法應對動態變化 |
| 重複造輪子 | Claude Code 已有檔案操作工具 |
| 開發週期長 | 8 週才能完成 MVP |
| 學習成本高 | 需要記憶新的 CLI 命令 |

#### 解決方案：Skill + Scripts

| 優勢 | 說明 |
|------|------|
| **原生整合** | 在 Claude Code 中直接使用 `/atlas` |
| **即時分析** | 按需探索，不需預先索引 |
| **零學習成本** | 自然語言互動 |
| **快速開發** | 1-2 週完成核心功能 |
| **AI 驅動** | 利用 Claude 的理解能力 |

### 1.3 目標用戶

- **主要**：使用 Claude Code 進行開發的工程師
- **場景**：接手新專案、學習現有模式、Debug、Code Review
- **頻率**：每天多次使用

---

## 2. 使用場景

### 場景 1：接手遺留系統（Bug 修復）

**情境**：
```
新人 Alice 需要修 Bug：
"用戶登入後，特定角色無法看到訂單列表"
```

**傳統方式**：
- 搜尋 "orders" → 50 個檔案
- 猜測是 OrdersController？
- 發現有 authorization 邏輯，但 Policy 在哪？
- 問資深同事（可能在忙）
- **花費 2 小時**

**使用 SourceAtlas**：
```
Alice: /atlas find "order list authorization"

AI 回應：
訂單列表的授權鏈路：
  1. OrdersController#index (app/controllers/orders_controller.rb:23)
     → 呼叫 authorize(@orders)

  2. OrderPolicy#index? (app/policies/order_policy.rb:15)
     → 檢查 user.role 和 store 權限

  3. 相關測試：spec/requests/orders_spec.rb:45

可能問題點：
  - OrderPolicy 2天前被修改
  - Commit: "fix: update role check logic"

建議：先檢查 order_policy.rb:18 的角色判斷邏輯
```

**時間節省**：從 2 小時 → 15 分鐘

---

### 場景 2：新功能開發（學習現有模式）

**情境**：
```
PM: "我們要加新功能：用戶可以匯出發票 PDF"
開發者 Bob: "好，但這專案怎麼處理 PDF 生成的？"
```

**使用 SourceAtlas**：
```
Bob: /atlas pattern "file generation"

AI 回應：
此專案的檔案生成模式（範例：訂單 PDF）：

標準流程：
  1. Controller 接收請求
  2. 入隊背景任務 GeneratePdfJob
  3. Service 使用 Prawn gem 生成
  4. 上傳到 S3 (config/storage.yml:15)
  5. 發送郵件通知用戶

參考實作：
  - Service: app/services/order_pdf_service.rb
  - Job: app/jobs/generate_pdf_job.rb
  - Test: spec/services/order_pdf_service_spec.rb

跟隨此模式新增發票 PDF：
  1. 創建 InvoicePdfService
  2. 創建 GenerateInvoicePdfJob
  3. 配置 S3 bucket
  4. 更新 InvoiceMailer
```

**價值**：避免重新設計，遵循現有架構

---

### 場景 3：影響範圍分析

影響分析是開發中的關鍵需求，包含兩種常見情況：

#### 3A. Model 變更的連鎖影響

**情境**：
```
測試環境發現：改了 User model 的驗證規則後，
3 個看似不相關的功能都壞了
```

**使用 SourceAtlas**：
```
Developer: /atlas impact "User model validation"

AI 回應：
User model 驗證變更的影響範圍：

直接影響（4 處）：
  - RegistrationController#create
  - Admin::UsersController#update
  - Api::V1::ProfileController#update
  - UserImportService（批量匯入）

連鎖影響（3 處）：
  - Order model (belongs_to :user, validates: true)
  - Notification service（假設 user.email 總是有效）
  - Analytics job（依賴 user 資料結構）

測試覆蓋缺口：
  ⚠️ UserImportService 沒有驗證失敗的測試
  ⚠️ Order#user 關聯沒測試 invalid user

建議：
  1. 先補上缺失的測試
  2. 檢查 Notification service 的 email 處理
```

**價值**：預防連鎖失敗，提前補測試

---

#### 3B. API 改動的影響範圍（⭐ 高頻場景）

**情境**：
```
後端 API 端點變更，需要盤點哪些前端頁面會受影響

例如：GET /api/users/{id} 的 response 格式改變
- 'role' 欄位從字串改為陣列 'roles'
- 新增 'profile' 巢狀物件
```

**使用 SourceAtlas**：
```
Developer: /atlas impact api "/api/users/{id}"

AI 回應：
=== API Impact Analysis ===

📍 調用鏈路：
  1. API 層
     - src/types/api.ts (類型定義)
     - src/lib/apiClient.ts (調用封裝)

  2. Hook 層
     - src/hooks/useUser.ts (主要 Hook)
       → 被 5 個元件使用

  3. 元件層
     - src/app/profile/page.tsx
     - src/app/users/[id]/page.tsx
     - src/components/UserCard.tsx
     - src/components/UserBadge.tsx
     - src/app/dashboard/page.tsx

📊 欄位使用分析：

'role' 欄位（⚠️ 將被改為 'roles' 陣列）：
  - 使用次數：8 處
  - 關鍵位置：
    1. UserBadge.tsx:34 - 渲染角色徽章
       if (user.role === 'admin') { ... }

    2. permissions.ts:12 - 權限檢查
       return user.role === 'admin' || user.role === 'editor'

    3. UserForm.tsx:67 - 表單顯示
    4. useUser.ts:23 - 數據轉換

  - 假設類型為字串：✅ 是（全部）
  - 影響評估：🔴 破壞性變更（需要修改）

🧪 測試影響：
  需要更新 5 個測試檔案：
  - useUser.test.ts - Mock 數據
  - UserBadge.test.tsx
  - permissions.test.ts
  - UserForm.test.tsx
  - e2e/user-profile.spec.ts

📋 遷移檢查清單：
  [ ] 更新 API 類型定義（api.ts）
  [ ] 更新 8 處 role → roles 使用
  [ ] 改用 user.roles.includes('admin')
  [ ] 新增向後相容處理（如需要）
  [ ] 更新 5 個測試檔案
  [ ] 測試所有影響的頁面

預估工作量：2-3 小時
風險等級：🔴 高（破壞性變更）
```

**價值**：
- 提前發現所有影響點，避免遺漏
- 給出明確修改清單和遷移步驟
- 評估工作量和風險等級
- 減少前後端協作摩擦

**適用場景**：
- API Response 格式變更
- 新增必填參數
- 欄位移除或改名
- 狀態碼邏輯變更

---

### 場景 4：Code Review（理解變更意圖）

**情境**：
```
收到 PR：新增 PaymentRefundService
Reviewer 不熟悉支付模組，需要快速理解上下文
```

**使用 SourceAtlas**：
```
Reviewer: /atlas review PR#123

AI 回應：
此 PR 在支付模組新增退款服務

模組上下文：
  - 現有：PaymentService (charge, capture)
  - 現有：PaymentWebhookHandler
  - 新增：PaymentRefundService ← 此 PR

架構符合度：✅ 良好
  - 遵循現有 Service Object 模式
  - 錯誤處理方式一致（Result pattern）
  - 命名符合慣例

潛在問題：
  ⚠️ 缺少冪等性處理（PaymentService 有實作）
  ⚠️ Webhook 處理器需要更新支援 refund events
  ⚠️ 測試覆蓋 85%（建議 >90% for payment logic）

建議：
  1. 參考 PaymentService#charge 的冪等性實作
  2. 更新 webhook_handler.rb
```

**價值**：提高 Review 品質，減少來回修改

---

### 場景 5：技術債務管理（專案健康度）

**情境**：
```
Tech Lead 需要向 CTO 報告：
"我們的技術債務有多嚴重？重構優先級？"
```

**使用 SourceAtlas**：
```
Tech Lead: /atlas health

AI 回應：
專案健康度報告

🔴 高風險區域（需立即處理）：
  1. PaymentService
     - 複雜度：450 lines, 8 dependencies
     - 被 12 個檔案依賴（核心模組）
     - 6 個月內修改 23 次（高變動）
     - 測試覆蓋 78%（支付邏輯應 >95%）
     → 建議：拆分為多個小 Service + 補測試

  2. User model
     - God Object 模式（15 concerns）
     - 影響 45 個檔案
     → 建議：提取 Authentication, Authorization 為獨立模組

🟡 中風險（規劃重構）：
  ...

✅ 健康區域：
  - API Controllers（一致性 98%）
  - Background Jobs（測試覆蓋 95%）
```

**價值**：量化技術債務，優先級排序

---

### 場景分類

| 場景類型 | 需求特點 | 適用產品 | 使用命令 |
|---------|---------|---------|----------|
| **即時探索** | 不需歷史資料、即時推理 | ✅ SourceAtlas Commands (v2.5) | |
| 快速理解新專案 | 10-15 分鐘全局視角 | ✅ Commands | `/atlas-map` ⭐⭐⭐⭐⭐ |
| 場景 1: Bug 修復 | 快速定位問題 | ✅ Commands | `/atlas-find` |
| 場景 2: 學習模式 | 識別設計模式 | ✅ Commands | `/atlas-pattern` ⭐⭐⭐⭐⭐ |
| 場景 3B: API 影響分析 ⭐ | 追蹤 API 調用鏈 | ✅ Commands | `/atlas-impact` |
| 場景 4: Code Review | 理解變更意圖 | ✅ Commands | `/atlas-map` + `/atlas` |
| **持續追蹤** | 需要歷史資料、趨勢分析 | 🔮 SourceAtlas Monitor (v3.0) | |
| 場景 3A: Model 變更影響 | Git 歷史、關聯分析 | 🔮 Monitor | (未來功能) |
| 場景 5: 技術債務 | 持續追蹤、量化指標 | 🔮 Monitor | `/atlas-health` (未來) |

---

## 3. 產品架構

### 3.1 整體架構

```
┌─────────────────────────────────────────────┐
│           Claude Code Environment           │
├─────────────────────────────────────────────┤
│  SourceAtlas Commands (Slash Commands)     │
│  ├─ /atlas               - Full Analysis   │
│  ├─ /atlas-pattern       - Learn Patterns  │
│  ├─ /atlas-impact        - Impact Analysis │
│  ├─ /atlas-find          - Quick Search    │
│  └─ /atlas-explain       - Deep Dive       │
├─────────────────────────────────────────────┤
│  Helper Scripts (Bash)                      │
│  ├─ detect-project.sh                      │
│  ├─ scan-entropy.sh                        │
│  ├─ find-patterns.sh                       │
│  ├─ collect-git.sh                         │
│  └─ analyze-dependencies.sh                │
├─────────────────────────────────────────────┤
│  Claude Code Built-in Tools                 │
│  ├─ Glob (file pattern matching)           │
│  ├─ Grep (content search)                  │
│  ├─ Read (file reading)                    │
│  └─ Bash (command execution)               │
└─────────────────────────────────────────────┘
```

### 3.2 與原始 PRD 的對比

| 組件 | 原始 PRD (CLI) | 新設計 (Commands) | 理由 |
|------|---------------|------------------|------|
| **Parser Layer** | ✅ 需實作 | ❌ 移除 | AI 自己理解代碼 |
| **Index Layer** | ✅ 需實作 | ❌ 移除 | 即時探索，不需索引 |
| **Storage Layer** | ✅ 需實作 | ❌ 移除 | 不儲存索引 |
| **Query Layer** | ✅ 需實作 | ❌ 移除 | AI 動態查詢 |
| **Command Prompts** | ❌ 無 | ✅ 新增 | 用戶明確觸發的分析流程 |
| **Helper Scripts** | ❌ 無 | ✅ 新增 | 資料收集 |

### 3.3 檔案結構

```
sourceatlas2/
├── .claude/
│   └── commands/
│       ├── atlas.md             # ✨ /atlas - 完整分析（核心）
│       ├── atlas-overview.md    # ✨ /atlas-overview - 專案概覽 ⭐⭐⭐⭐⭐
│       ├── atlas-pattern.md     # ✨ /atlas-pattern - 學習模式 ⭐⭐⭐⭐⭐
│       ├── atlas-impact.md      # ✨ /atlas-impact - 影響分析
│       ├── atlas-find.md        # /atlas-find - 快速搜尋
│       └── atlas-explain.md     # /atlas-explain - 深入解釋
│
├── scripts/atlas/
│   ├── detect-project.sh        # 專案類型偵測
│   ├── scan-entropy.sh          # 高熵檔案掃描
│   ├── find-patterns.sh         # 模式識別輔助 ⭐
│   ├── collect-git.sh           # Git 統計收集
│   └── analyze-dependencies.sh  # 依賴分析
│
├── templates/
│   ├── stage0-output.toon       # Stage 0 輸出範例
│   ├── stage1-output.md         # Stage 1 輸出範例
│   └── patterns.yaml            # 模式定義庫（可選）
│
├── docs/
│   ├── PROMPTS.md               # 完整 Prompt 文檔（已有）
│   ├── USAGE_GUIDE.md           # 使用指南（已有）
│   ├── README.md                # 總覽（已有）
│   └── CLAUDE.md                # AI 工作指南（已有）
│
└── test_results/                # 驗證案例（已有）
```

---

## 4. 核心能力

### 4.1 三階段分析（保留 v2.0 核心）

#### Stage 0: Project Fingerprint
- **目標**：掃描 <5% 檔案達到 70-80% 理解
- **方法**：高熵檔案優先（README, package.json, Models）
- **輸出**：TOON 格式專案指紋
- **時間**：10-15 分鐘

#### Stage 1: Hypothesis Validation
- **目標**：驗證 Stage 0 假設，達到 85-95% 理解
- **方法**：系統化驗證，提供證據
- **輸出**：驗證報告
- **時間**：20-30 分鐘

#### Stage 2: Git Hotspots Analysis
- **目標**：識別開發模式，理解深度 95%+
- **方法**：分析 commit 歷史、識別熱點
- **輸出**：Git 分析報告
- **時間**：15-20 分鐘

### 4.2 即時探索能力（新增）

#### Find（智慧搜尋）
```
/atlas find "authentication flow"

AI 自動：
1. 理解搜尋意圖
2. 規劃搜尋策略
3. 執行多輪搜尋
4. 整合結果
5. 提供上下文
```

#### Pattern（模式識別）
```
/atlas pattern "api endpoint"

AI 識別：
1. 找到最佳範例檔案
2. 提取設計模式
3. 說明慣例
4. 提供步驟指引
```

#### Explain（深入解釋）
```
/atlas explain app/services/payment_service.rb

AI 分析：
1. 檔案目的和職責
2. 關鍵方法說明
3. 依賴關係
4. 使用範例
5. 測試覆蓋
```

### 4.3 AI 協作識別（保留 v2.0 發現）

識別專案的 AI 協作成熟度（Level 0-4）：

| Level | 特徵 | 識別方法 |
|-------|------|---------|
| **Level 0** | 無 AI | 傳統代碼風格 |
| **Level 1-2** | 基礎使用 | 偶爾的 AI 痕跡 |
| **Level 3** | 系統化 | CLAUDE.md、高一致性、詳細註解 |
| **Level 4** | 生態化 | 團隊級 AI 協作（未來） |

---

## 5. TOON 格式規範

### 5.1 為什麼選擇 TOON（保留原 PRD）

| 特性 | JSON | YAML | TOON | 優勢 |
|------|------|------|------|------|
| Token 使用 | 100% | 85% | 55% | 最佳 |
| 可讀性 | 中 | 高 | 高 | ✓ |
| 註解支援 | ✗ | ✓ | ✓ | ✓ |
| 多行字串 | 複雜 | ✓ | ✓ | ✓ |
| 解析速度 | 快 | 慢 | 快 | ✓ |

### 5.2 TOON 基本語法

```yaml
# 專案指紋範例
metadata:
  project_name: EcommerceAPI
  scan_time: 2025-11-20T10:00:00Z
  scanned_files: 12
  total_files_estimate: 450

## 專案指紋
project_type: WEB_APP
framework: Rails 7.0
architecture: Service-oriented
scale: LARGE

## 技術棧
backend:
  language: Ruby 3.1
  framework: Rails 7.0
  database: PostgreSQL 14

## 假設清單
hypotheses:
  architecture:
    - hypothesis: "使用 Service Object 模式處理商業邏輯"
      confidence: 0.9
      evidence: "app/services/ 有 15 個 Service 類別"
      validation_method: "檢查 Service 類別結構和呼叫方式"
```

### 5.3 Token 優化比較

```
原始 JSON: 156 tokens
TOON 標準: 92 tokens (節省 41%)
TOON 壓縮: 41 tokens (節省 74%)
```

---

## 6. Command 介面設計

### 6.1 核心命令（按優先級）

```bash
# 優先級 ⭐⭐⭐⭐⭐ - 最常用功能
/atlas-overview                    # 專案概覽（Stage 0 指紋）
/atlas-overview src/api            # 分析特定目錄
/atlas-pattern "api endpoint"      # 學習專案如何實作 API 端點
/atlas-pattern "background job"    # 學習背景任務模式
/atlas-pattern "file upload"       # 學習檔案上傳流程

# 優先級 ⭐⭐⭐⭐ - 影響範圍分析
/atlas-impact "User authentication"   # 功能改動影響
/atlas-impact api "/api/users/{id}"   # API 改動影響

# 優先級 ⭐⭐⭐ - 完整分析
/atlas                    # Stage 0-2 完整三階段分析

# 優先級 ⭐⭐ - 快速定位
/atlas-find "user login"  # 快速找到功能實作

# 優先級 ⭐ - 深入解釋
/atlas-explain path/to/file.rb   # 深入解釋特定檔案

# 未來功能（v3.0）
/atlas-health             # 專案健康度分析
/atlas-review PR#123      # PR 變更分析
```

### 6.2 Command 定義結構

#### 範例 1: `/atlas-overview` (專案概覽)

```markdown
# .claude/commands/atlas-overview.md

---
description: Get project overview - scan <5% of files to achieve 70-80% understanding
allowed-tools: Bash, Glob, Grep, Read
argument-hint: [optional: specific directory to analyze]
---

# SourceAtlas: Project Overview (Stage 0 Fingerprint)

## Context

Analysis Target: $ARGUMENTS

Goal: Generate project fingerprint by scanning <5% of files in 10-15 minutes.

## Your Task

Execute Stage 0 Analysis using information theory principles:

1. Run: `bash scripts/atlas/detect-project.sh`
2. Run: `bash scripts/atlas/scan-entropy.sh`
3. Apply high-entropy file prioritization
4. Generate 10-15 hypotheses with confidence levels
5. Output TOON format report

### High-Entropy Priority:
1. Documentation (README, CLAUDE.md)
2. Config files (package.json, etc.)
3. Core models (3-5 samples)
4. Entry points (1-2 samples)
5. Tests (1-2 samples)

Output Format: TOON (Token Optimized Output Notation)
Time Limit: 10-15 minutes
Understanding Target: 70-80%

STOP after Stage 0 - do not proceed to validation or git analysis.
```

#### 範例 2: `/atlas-pattern` (學習設計模式)

```markdown
# .claude/commands/atlas-pattern.md

---
description: Learn design patterns from the current codebase
allowed-tools: Bash, Glob, Grep, Read
argument-hint: [pattern type, e.g., "api endpoint", "background job"]
---

# SourceAtlas: Pattern Learning Mode

## Context

Project structure: !`tree -L 2 -d --charset ascii`

Pattern type requested: **$ARGUMENTS**

## Your Task

Goal: Help the user learn how THIS codebase implements the requested pattern.

Workflow:
1. Run: `bash scripts/atlas/find-patterns.sh "$ARGUMENTS"`
2. Identify 2-3 exemplary implementations
3. Extract the design pattern
4. Provide actionable guidance

Output Format:
- Pattern name and standard approach
- Best example files with line numbers
- Key conventions to follow
- Common pitfalls to avoid
- Testing patterns

Remember: Scan <5% of files, focus on patterns not exhaustive details.
```

#### 範例 3: `/atlas` (完整分析)

```markdown
# .claude/commands/atlas.md

---
description: Full three-stage codebase analysis (fingerprint, validation, hotspots)
allowed-tools: Bash, Glob, Grep, Read
---

# SourceAtlas: Complete Analysis

## Context

Project info: !`bash scripts/atlas/detect-project.sh`

## Stage 0: Project Fingerprint

1. Run: `bash scripts/atlas/scan-entropy.sh`
2. Apply high-entropy file prioritization
3. Scan <5% of files to achieve 70-80% understanding
4. Output TOON format report

### High-Entropy Priority:
1. README.md, CLAUDE.md
2. package.json, composer.json, etc.
3. Models (3-5 core models)
4. Controllers/Routes (1-2 examples)
5. Main config files

## Stage 1: Hypothesis Validation

Systematically validate Stage 0 hypotheses...

## Stage 2: Git Hotspots Analysis

Analyze commit history and development patterns...
```

---

## 7. Scripts 設計

### 7.1 設計原則

**Scripts 只做資料收集，不做理解推理**

```bash
# ✅ 好的 Script 設計
detect_project_type() {
    # 輸出原始資料
    echo "package.json: $(test -f package.json && echo 'exists')"
    echo "composer.json: $(test -f composer.json && echo 'exists')"
    # AI 自己判斷是 Node 還是 PHP 專案
}

# ❌ 壞的 Script 設計
detect_project_type() {
    # 不要在 Script 裡做判斷邏輯
    if [ -f "package.json" ]; then
        echo "This is a Node.js project"
    fi
}
```

### 7.2 核心 Scripts

#### scripts/atlas-stage0.sh

```bash
#!/bin/bash
# Stage 0: 收集專案基本資訊

main() {
    echo "=== Project Detection ==="
    detect_project_files

    echo ""
    echo "=== Project Stats ==="
    project_statistics

    echo ""
    echo "=== High-Entropy Files ==="
    list_high_entropy_files

    echo ""
    echo "=== Directory Structure ==="
    show_structure
}

detect_project_files() {
    # 檢查關鍵檔案是否存在
    for file in package.json composer.json requirements.txt Gemfile pom.xml; do
        [ -f "$file" ] && echo "Found: $file"
    done
}

project_statistics() {
    # 基本統計
    echo "Total files: $(find . -type f | wc -l)"
    echo "Total lines: $(find . -name '*.rb' -o -name '*.js' | xargs wc -l | tail -1)"
    echo "Languages: $(find . -name '*.rb' -o -name '*.js' -o -name '*.py' | \
                         sed 's/.*\.//' | sort | uniq -c)"
}

list_high_entropy_files() {
    # 列出高熵檔案（README, 配置, Models）
    find . -maxdepth 2 -iname 'readme*' -o -iname 'claude*'
    find . -name 'package.json' -o -name 'composer.json'
    find . -path '*/models/*' -o -path '*/app/models/*' | head -5
}

show_structure() {
    # 顯示目錄結構（2 層）
    tree -L 2 -d --charset ascii 2>/dev/null || find . -maxdepth 2 -type d
}

main
```

#### scripts/atlas-find.sh

```bash
#!/bin/bash
# 智慧搜尋輔助工具

search_term="$1"

main() {
    echo "=== File Name Search ==="
    find . -iname "*${search_term}*" -type f | head -10

    echo ""
    echo "=== Content Search ==="
    grep -r -i "$search_term" --include="*.rb" --include="*.js" . | head -20

    echo ""
    echo "=== Related Files ==="
    # 找到包含搜尋詞的檔案後，列出其依賴
    grep -l -r -i "$search_term" . | head -5
}

main
```

### 7.3 Scripts vs AI 分工

| 任務 | 負責方 | 範例 |
|------|-------|------|
| 檔案列表 | Script | `find . -name "*.rb"` |
| 內容搜尋 | Script | `grep -r "User"` |
| 統計資訊 | Script | `wc -l`, `git log --stat` |
| **理解意圖** | AI | "這是用戶認證模組" |
| **識別模式** | AI | "使用 Service Object 模式" |
| **推理關聯** | AI | "改 User model 會影響 Order" |
| **生成建議** | AI | "建議拆分為多個 Service" |

---

## 8. 分析方法論

### 8.1 高熵檔案優先策略（保留 v2.0）

**資訊理論基礎**：
```
資訊熵 = 檔案包含的「意外」資訊量

高熵檔案：README.md, Models, 配置檔
  → 包含專案級理解、資料結構、架構決策

低熵檔案：重複的 CRUD Controllers, 樣板代碼
  → 模式可預測，單獨看價值低
```

**掃描優先序**：
```
1. README.md, CLAUDE.md        (專案描述、規範)
2. package.json, composer.json (技術棧、依賴)
3. Models (3-5 個核心)         (資料結構)
4. Routes, Controllers (1-2 個) (API 設計)
5. 主要配置檔                  (環境、整合)
```

### 8.2 貝葉斯推理模式（保留 v2.0）

```
先驗概率 (Stage 0) + 證據 (Stage 1) = 後驗概率

範例：
Stage 0 假設：「使用 JWT 認證」(信心度 0.7)
  依據：package.json 有 jsonwebtoken

Stage 1 驗證：grep "jwt" → 找到 5 個使用處
  證據：Auth middleware、Token 生成、驗證邏輯

後驗概率：信心度提升至 0.95 ✅ 確認
```

### 8.3 模式識別規則

#### 架構模式

```yaml
MVC:
  indicators:
    - directories: [models, views, controllers]
    - framework: Rails, Django

Service-oriented:
  indicators:
    - directory: services/
    - naming: *_service.rb
    - pattern: Single responsibility

Microservices:
  indicators:
    - multiple: package.json
    - docker: docker-compose.yml
    - gateway: API gateway config
```

#### 設計模式

```yaml
Repository:
  indicators:
    - suffix: Repository
    - methods: [find, save, delete]

Factory:
  indicators:
    - suffix: Factory
    - methods: [create, build]

Observer:
  indicators:
    - methods: [subscribe, notify]
    - gems: [wisper, eventmachine]
```

---

## 9. 實作規範

### 9.1 技術棧

```yaml
skill:
  format: Markdown
  location: .claude/skills/atlas.md
  size: ~500 lines

scripts:
  language: Bash (POSIX)
  location: scripts/
  total_size: ~1000 lines

  dependencies:
    required: [bash, find, grep, git]
    optional: [tree, jq]

templates:
  format: Plain text + YAML
  location: templates/
```

### 9.2 開發優先級

#### Phase 1: 核心 Commands 框架 (Week 1)
- [ ] 創建 `.claude/commands/` 目錄結構
- [ ] 實作 `/atlas` - 完整三階段分析
- [ ] 實作 `/atlas-pattern` - 學習模式 ⭐⭐⭐⭐⭐
- [ ] 基礎 Scripts（detect-project.sh, scan-entropy.sh）
- [ ] TOON 格式輸出

#### Phase 2: 優先功能 (Week 1-2)
- [ ] 完善 `/atlas-pattern` 命令和 Script
- [ ] 實作 `find-patterns.sh` ⭐
- [ ] 在真實專案測試 `/atlas-pattern`
- [ ] 收集回饋並迭代優化

#### Phase 3: 影響分析功能 (Week 2)
- [ ] 實作 `/atlas-impact` - 功能影響分析
- [ ] 實作 `/atlas-impact api` - API 影響分析
- [ ] 相關 Scripts（analyze-dependencies.sh）
- [ ] 測試驗證

#### Phase 4: 輔助功能與優化 (Week 2-3)
- [ ] 實作 `/atlas-find` - 快速搜尋
- [ ] 實作 `/atlas-explain` - 深入解釋
- [ ] 完善 Git 分析 Scripts
- [ ] 整體測試與文檔

---

## 10. 成功指標

### 10.1 量化指標

| 指標 | 目標值 | 測量方式 | v2.0 驗證結果 |
|------|--------|----------|--------------|
| **理解準確度** | >85% | AI 能正確定位功能 | ✅ 87-100% |
| **Token 節省** | >40% | vs 完整檔案讀取 | ✅ 95%+ |
| **時間節省** | >90% | vs 手動理解 | ✅ 95%+ |
| **Stage 0 準確度** | >70% | 假設驗證率 | ✅ 75-95% |
| **使用頻率** | 每天 3+ 次 | 開發者實際使用 | 🔜 待測 |

### 10.2 質化指標

```yaml
使用者體驗:
  - 學習成本：< 5 分鐘上手
  - 回應速度：< 30 秒得到結果
  - 準確性：85% 以上有用
  - 整合度：無縫融入工作流程

技術品質:
  - Script 執行：< 5 秒完成資料收集
  - 錯誤處理：優雅降級
  - 相容性：支援主流語言（Ruby, JS, Python, Go）
```

### 10.3 驗收標準

#### 基本功能
- [x] Stage 0 能在 15 分鐘內完成分析
- [x] Stage 1 驗證率 >80%
- [x] Stage 2 識別 AI 協作模式
- [ ] /atlas find 能找到正確檔案
- [ ] /atlas pattern 能識別設計模式

#### 質量標準
- [ ] 在 4+ 真實專案測試通過
- [ ] 使用者回饋 >4/5 分
- [ ] Scripts 在 Linux/macOS 都能運行
- [ ] 錯誤時提供清晰訊息

---

## 11. 實作路線圖

### v2.5.0 - SourceAtlas Skill (當前)

**目標**：提供即時專案理解能力

**時程**：3-4 週

#### Week 1: 核心 Skill
- [x] 設計 Skill 架構
- [ ] 實作 Stage 0 Skill
- [ ] 實作 Stage 1 Skill
- [ ] 實作 Stage 2 Skill
- [ ] 基礎 Scripts（detect, scan）

#### Week 2-3: 增強功能
- [ ] /atlas find 實作
- [ ] /atlas pattern 實作
- [ ] /atlas explain 實作
- [ ] 完整 Scripts 集合
- [ ] 模式定義庫

#### Week 3-4: 測試與優化
- [ ] 在 5+ 真實專案測試
- [ ] 收集使用回饋
- [ ] 優化 Prompt 和 Scripts
- [ ] 撰寫使用文檔
- [ ] 發布 v2.5.0

---

### v3.0.0 - SourceAtlas Monitor (未來)

**目標**：持續追蹤和趨勢分析

**時程**：3-6 個月

**功能規劃**：
```yaml
持續追蹤:
  - 自動偵測變更
  - 建立歷史索引
  - 趨勢分析

影響分析:
  - 靜態依賴分析
  - Git 歷史關聯
  - 測試覆蓋追蹤

健康度儀表板:
  - 技術債務量化
  - 複雜度追蹤
  - 風險區域識別
```

**是否開發取決於**：
1. v2.5 使用者回饋
2. 是否確實需要持續追蹤
3. 開發資源和時間

---

## 附錄 A：設計決策記錄

### 決策 1：為什麼選擇 Skill 而非 CLI？

**日期**：2025-11-20

**問題**：原始 PRD 設計獨立 CLI 工具 (`satlas`)，是否仍然適合？

**考量因素**：
| 因素 | CLI 工具 | Skill 架構 |
|------|---------|-----------|
| 開發時間 | 8 週 | 1-2 週 |
| 學習成本 | 需學習命令 | 自然語言 |
| 工作流整合 | 需切換工具 | 原生整合 |
| 維護成本 | 高（索引、解析） | 低（Scripts + AI） |
| 靈活性 | 固定索引 | 動態探索 |

**決策**：採用 Claude Code Skill + Scripts 架構

**理由**：
1. 開發者已經在 Claude Code 中工作
2. AI 的理解能力可以替代大量解析邏輯
3. 即時探索比預先索引更靈活
4. 更快交付價值（1-2 週 vs 8 週）

---

### 決策 2：Scripts 的職責範圍

**日期**：2025-11-20

**問題**：Scripts 應該做多少事？

**決策**：Scripts 只做資料收集，不做理解推理

**理由**：
- AI 擅長理解和推理
- Scripts 擅長快速資料收集
- 保持 Scripts 簡單，易於維護
- 避免在 Bash 中實作複雜邏輯

**範例**：
```bash
# ✅ Script 負責
detect_files() { find . -name "*.rb"; }

# ✅ AI 負責
"這些檔案使用 Service Object 模式"
```

---

### 決策 3：是否需要持續索引？

**日期**：2025-11-20

**問題**：v2.5 是否需要建立和維護索引？

**決策**：v2.5 不建立持續索引，留待 v3.0

**理由**：
1. 即時探索場景（找 Bug、學模式）不需要索引
2. 持續追蹤場景（技術債務）才需要索引
3. 先驗證即時探索的價值
4. 避免過度設計

**影響**：
- v2.5 專注於即時分析
- v3.0 再評估是否需要 Monitor

---

### 決策 4：Commands vs Skills？⭐

**日期**：2025-11-20

**問題**：SourceAtlas 應該使用 Claude Code Commands 還是 Skills？

**技術差異**：

| 特性 | Commands | Skills |
|------|----------|--------|
| **觸發方式** | 用戶手動輸入 `/cmd` | AI 自動決定 |
| **控制權** | 用戶明確控制 | AI 上下文判斷 |
| **適用場景** | 主動工具、明確流程 | 被動輔助、專家系統 |
| **參數傳遞** | ✅ 支援 `$ARGUMENTS` | ❌ 不支援 |
| **Script 執行** | ✅ 支援 | ✅ 支援 |
| **檔案結構** | 單一 .md 檔案 | 目錄結構 (SKILL.md + scripts/) |
| **開發速度** | 快（簡單） | 慢（複雜） |

**考量因素**：

| 因素 | Commands | Skills | 勝出 |
|------|----------|--------|------|
| **使用者期望** | 明確觸發分析 | 自動觸發 | ✅ Commands |
| **場景多樣性** | 不同命令對應不同場景 | 單一入口 | ✅ Commands |
| **可預測性** | 高 | 低 | ✅ Commands |
| **開發複雜度** | 低 | 高 | ✅ Commands |
| **Token 效率** | 普通 | 優秀 | Skills |

**決策**：採用 Claude Code Commands 架構

**理由**：

1. **SourceAtlas 是「工具」不是「助手」**
   - 用戶想要明確控制何時執行分析
   - 不希望 AI 自動執行 30 分鐘的完整分析
   - 不同場景需要不同入口點

2. **使用場景需要明確觸發**
   - `/atlas-pattern` (快速學習，5 分鐘) vs `/atlas` (完整分析，30 分鐘)
   - 用戶根據需求選擇合適的命令
   - Commands 提供清晰的功能邊界

3. **開發效率更高**
   - 一個 Command = 一個 .md 檔案
   - 更簡單、更直接
   - 用戶可輕鬆查看和修改

4. **符合優先級排序**
   - `/atlas-pattern` ⭐⭐⭐⭐⭐ (最常用)
   - `/atlas-impact` ⭐⭐⭐⭐
   - `/atlas` ⭐⭐⭐ (完整分析)
   - 不同優先級需要不同命令入口

**實作方案**：

```
.claude/commands/
├── atlas.md              # /atlas - 完整三階段分析
├── atlas-pattern.md      # /atlas-pattern - 學習模式 (最優先)
├── atlas-impact.md       # /atlas-impact - 影響分析
├── atlas-find.md         # /atlas-find - 快速搜尋
└── atlas-explain.md      # /atlas-explain - 深入解釋

scripts/atlas/
├── detect-project.sh
├── scan-entropy.sh
├── find-patterns.sh      # 支援 /atlas-pattern
└── collect-git.sh
```

**未來可能用 Skill 的場景**（可選增強）：

創建一個輔助性的 Skill，在用戶表現出困惑時「建議」使用 SourceAtlas：

```markdown
---
name: sourceatlas-advisor
description: |
  Suggest SourceAtlas commands when user shows confusion about codebase.
  Do NOT auto-trigger analysis.
---

When detecting user confusion, suggest:
"Would you like me to run `/atlas-pattern` to learn how this codebase handles [X]?"
```

但這是**可選的增強**，不影響核心功能。

**影響**：
- PRD 第 3、6、9 章需要更新
- 將 "Skill" 術語改為 "Commands"
- 檔案結構從 `.claude/skills/` 改為 `.claude/commands/`
- 保持斜線命令介面不變（`/atlas`, `/atlas-pattern` 等）

---

## 附錄 B：與 v2.0 的關係

### v2.0 成果（已完成）

```
✅ PROMPTS.md - 完整的三階段 Prompt
✅ USAGE_GUIDE.md - 使用指南
✅ README.md - 專案總覽
✅ 4 個專案驗證
✅ AI 協作識別方法
✅ TOON 格式規範
```

### v2.5 如何使用 v2.0

```yaml
保留:
  - 三階段分析方法論
  - TOON 格式規範
  - 高熵檔案優先策略
  - AI 協作識別邏輯
  - 驗證結果和洞察

轉換:
  - 手動 Prompt → Command 自動化
  - 複製貼上 → 斜線命令觸發
  - 獨立報告 → 對話式互動

新增:
  - /atlas find 智慧搜尋
  - /atlas pattern 模式識別
  - /atlas explain 深入解釋
  - 輔助 Scripts
```

---

## 更新日誌

### v2.5.2 (2025-11-22) - 當前版本 ⭐

**重要新增**：
- **新增 `/atlas-overview` 命令** - 專案概覽（Stage 0 指紋分析）
- 填補 PRD 遺漏：提供獨立的快速理解能力
- 不需執行完整三階段，10-15 分鐘即可獲得 70-80% 理解

**實作內容**：
- `.claude/commands/atlas-overview.md` - 專案概覽命令
- `scripts/atlas/detect-project.sh` - 專案類型檢測腳本
- `scripts/atlas/scan-entropy.sh` - 高熵文件掃描腳本

**優先級調整**：
- `/atlas-overview` 列為最高優先級 (⭐⭐⭐⭐⭐)
- 與 `/atlas-pattern` 並列為最常用命令
- 使用場景：接手新專案、Code Review 準備、快速技術棧評估

**文檔更新**：
- 第 3.3 節：檔案結構新增 atlas-overview.md
- 第 6.1 節：核心命令新增 /atlas-overview
- 第 6.2 節：新增 /atlas-overview 範例
- 場景分類表：新增「快速理解新專案」場景

**設計理念**：
- `/atlas-overview` = 獨立 Stage 0（快速）
- `/atlas` = 完整三階段（深入）
- 給予用戶選擇權，不強制執行完整分析

---

### v2.5.1 (2025-11-20)

**重大決策**：
- **確定採用 Commands 而非 Skills** (決策 4)
- 架構最終定案：Commands + Helper Scripts
- 明確優先級：`/atlas-pattern` (⭐⭐⭐⭐⭐) 為最優先功能

**架構變更**：
- `.claude/skills/` → `.claude/commands/`
- 單一 Skill → 多個專門的 Commands
- 用戶明確觸發 → 更可控、更可預測

**文檔更新**：
- 第 3 章：產品架構（Commands 架構圖）
- 第 6 章：Skill 介面設計 → Command 介面設計
- 附錄 A：新增決策 4（Commands vs Skills）
- 全文統一術語：Skill → Commands

**影響**：
- 開發路徑更清晰
- 實作更簡單（單檔案 Commands）
- 符合用戶期望（明確控制）

---

### v2.5.0 (2025-11-20)

**重大變更**：
- 從獨立 CLI 工具轉為 Claude Code 整合
- 移除複雜的索引系統
- 新增輔助 Scripts 架構
- 保留 v2.0 的核心方法論

**新增**：
- 即時探索命令（find, pattern, explain）
- 5 個真實使用場景分析
- 輕量 Scripts 設計
- 優先級排序（基於真實需求）

**保留自 v2.0**：
- 三階段分析方法
- TOON 格式規範
- 高熵檔案優先策略
- AI 協作識別

---

### v2.0.0 (2025-11-19) - 研究驗證版

- 完成手動 Prompts 方法論
- 驗證 4 個真實專案
- 建立 TOON 格式規範
- 發現 AI 協作識別方法

---

### v1.0.0 (2025-01-15) - 原始 PRD

- 獨立 CLI 工具設計
- 完整索引系統架構
- TOON 格式提出

---

*本文件採用 CC-BY-SA 4.0 授權*
