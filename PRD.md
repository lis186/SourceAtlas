# SourceAtlas PRD v2.6.0

**AI-Powered Codebase Understanding Assistant**

- **版本**: 2.6.0
- **更新日期**: 2025-11-30
- **狀態**: Active Development (v2.6 Planning)

---

## Executive Summary

SourceAtlas 是一個整合在 Claude Code 中的智慧型程式碼理解助手。通過 **Claude Commands (斜線命令) + 輕量 Scripts** 的架構，在開發者的工作流程中提供即時的專案理解、模式學習和影響分析能力。

**核心定位的轉變**：
- ❌ **不是**：獨立的 CLI 索引工具
- ✅ **而是**：Claude Code 原生的分析助手（Commands）

### 核心特色

- 🎯 **即時探索**：不需要預先索引，按需分析
- 📋 **標準格式**：採用 YAML 格式，完整生態系統支援
- 🧠 **智慧理解**：AI 動態推理，而非靜態索引
- ⚡ **工作流整合**：融入 Claude Code，無縫使用
- 🛠️ **輕量設計**：Scripts 收集資料，AI 負責理解

---

## 目錄

1. [產品定位](#1-產品定位)
2. [使用場景](#2-使用場景)
3. [產品架構](#3-產品架構)
4. [核心能力](#4-核心能力)
5. [輸出格式決策](#5-輸出格式決策)
6. [Command 介面設計](#6-command-介面設計)
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
v2.6 (未來) - SourceAtlas Monitor
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
| **原生整合** | 在 Claude Code 中直接使用 `/atlas.*` 命令 |
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

### 場景 0：快速理解新專案（專案概覽）⭐

**情境**：
```
Alice 剛加入團隊，需要快速理解一個 2000+ LOC 的專案
PM 期望她明天就能開始參與開發
```

**傳統方式**：
- 從 README 開始讀
- 逐一打開檔案瀏覽目錄結構
- 猜測技術棧和架構模式
- 詢問資深同事
- **花費 2-3 天才有全局概念**

**使用 SourceAtlas**：
```
Alice: /atlas.overview

AI 分析後回應（10-15 分鐘）：

=== 專案指紋分析 ===

📊 基本資訊：
  - 專案類型: WEB_APP
  - 規模: MEDIUM (~3500 LOC)
  - 架構模式: MVC + Service Layer

🔧 技術棧：
  後端: Ruby on Rails 7.0
  資料庫: PostgreSQL + Redis
  前端: React 18 + TypeScript

🏗️ 架構推論（信心: 0.85）：
  - Controllers 處理 HTTP 請求
  - Services 包含業務邏輯
  - Jobs 處理非同步任務
  - Policies 管理權限

💡 關鍵發現：
  1. 有完整的測試覆蓋（85%+）
  2. 使用 Sidekiq 處理背景任務
  3. AI 協作等級: Level 3（有 CLAUDE.md）

📁 優先閱讀檔案：
  1. app/models/user.rb - 核心資料模型
  2. app/services/order_service.rb - 主要業務邏輯
  3. config/routes.rb - API 路由定義
```

**時間節省**：從 2-3 天 → 10-15 分鐘獲得 70-80% 理解

**後續行動**：
- 需要學習特定模式時 → `/atlas.pattern`
- 需要修改程式碼時 → `/atlas.impact` 評估影響

---

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
Alice: /atlas.impact "order list authorization"

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
Bob: /atlas.pattern "file generation"

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
Developer: /atlas.impact "User model validation"

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
Developer: /atlas.impact api "/api/users/{id}"

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
Reviewer: /atlas.review PR#123

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
Tech Lead: /atlas.health

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
| 場景 0: 快速理解新專案 ⭐ | 10-15 分鐘獲得全局視角 | ✅ Commands | `/atlas.overview` ⭐⭐⭐⭐⭐ |
| 場景 1: Bug 修復 | 快速定位問題 | ✅ Commands | `/atlas.impact` |
| 場景 2: 學習模式 | 識別設計模式 | ✅ Commands | `/atlas.pattern` ⭐⭐⭐⭐⭐ |
| 場景 3B: API 影響分析 ⭐ | 追蹤 API 調用鏈 | ✅ Commands | `/atlas.impact` ⭐⭐⭐⭐ |
| 場景 4: Code Review | 理解變更意圖 | ✅ Commands | `/atlas.overview` + `/atlas.pattern` |
| **持續追蹤** | 需要歷史資料、趨勢分析 | 🔮 SourceAtlas Monitor (v2.6) | |
| 場景 3A: Model 變更影響 | Git 歷史、關聯分析 | 🔮 Monitor | (未來功能) |
| 場景 5: 技術債務 | 持續追蹤、量化指標 | 🔮 Monitor | `/atlas.health` (未來) |

---

## 3. 產品架構

### 3.1 整體架構

```
┌─────────────────────────────────────────────┐
│           Claude Code Environment           │
├─────────────────────────────────────────────┤
│  SourceAtlas Commands (Slash Commands)     │
│  ├─ /atlas.overview      - Project Fingerprint ⭐⭐⭐⭐⭐
│  ├─ /atlas.pattern       - Learn Patterns ⭐⭐⭐⭐⭐
│  └─ /atlas.impact        - Impact Analysis ⭐⭐⭐⭐
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

> **歷史演進**：SourceAtlas 從獨立 CLI 設計演進為 Claude Code Commands 整合。完整演進過程見 `dev-notes/HISTORY.md`

### 3.2 檔案結構

**當前狀態** (v1.0 完成，v2.5 開發中)：

```
sourceatlas2/
├── .claude/commands/                    # Claude Code Commands
│   ├── atlas.overview.md                # ✅ /atlas.overview（已完成）
│   ├── atlas.pattern.md                 # ✅ /atlas.pattern（已完成）⭐
│   └── atlas.impact.md                  # ✅ /atlas.impact（已完成）
│
├── dev-notes/                           # ⭐ v1.0 開發記錄（重要！）
│   ├── HISTORY.md                       # ✅ 完整歷史與決策記錄
│   ├── KEY_LEARNINGS.md                 # ✅ v1.0 關鍵學習總結
│   ├── toon-vs-yaml-analysis.md         # ✅ 格式決策分析
│   ├── v1-implementation-log.md         # ✅ 完整實作日誌
│   ├── implementation-roadmap.md        # ✅ v2.5 路線圖
│   └── NEXT_STEPS.md                    # ✅ 下一步行動指南
│
├── prompts/                             # v2.0 手動 Prompts（保留參考）
│   ├── stage0-fingerprint.md
│   ├── stage1-validation.md
│   └── stage2-hotspots.md
│
├── scripts/atlas/                       # 輔助腳本
│   ├── detect-project-enhanced.sh       # ✅ 規模感知偵測
│   ├── scan-entropy.sh                  # ✅ 高熵檔案掃描
│   ├── find-patterns.sh                 # ✅ 模式識別（已完成）⭐
│   ├── benchmark.sh                     # ✅ 效能測試
│   └── compare-formats.sh               # ✅ 格式比較
│   # 計畫中：
│   # ├── collect-git.sh                 # ⏳ Git 統計（Phase 2）
│   # └── analyze-dependencies.sh        # ⏳ 依賴分析（Phase 3）
│
├── plugin/                              # 🔮 Marketplace 發布準備
│   └── (獨立的 plugin 結構)
│
├── test_results/                        # 驗證案例（git ignored）
├── test_targets/                        # 測試專案（git ignored）
│
├── CLAUDE.md                            # AI 工作指南
├── PRD.md                               # 產品需求文檔
├── PROMPTS.md                           # 完整 Prompt 模板
├── README.md                            # 專案總覽
└── USAGE_GUIDE.md                       # 使用指南
```

> **說明**：
> - ✅ = 已完成
> - 🔵 = 開發中（Phase 1）
> - ⏳ = 計畫中（Phase 2-3）
> - 🔮 = 未來功能

---

## 4. 核心能力

### 4.1 三階段分析（保留 v2.0 核心）

#### Stage 0: Project Fingerprint
- **目標**：掃描 <5% 檔案達到 70-80% 理解
- **方法**：高熵檔案優先（README, package.json, Models）
- **輸出**：YAML 格式專案指紋
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

#### Pattern（模式識別）⭐⭐⭐⭐⭐
```
/atlas.pattern "api endpoint"

AI 識別：
1. 找到最佳範例檔案
2. 提取設計模式
3. 說明慣例
4. 提供步驟指引
```

#### Impact（影響分析）⭐⭐⭐⭐
```
/atlas.impact api "/api/users/{id}"

AI 分析：
1. 追蹤調用鏈路
2. 識別受影響檔案
3. 評估變更風險
4. 提供遷移清單
```

### 4.3 AI 協作識別（保留 v2.0 發現）

識別專案的 AI 協作成熟度（Level 0-4）：

| Level | 特徵 | 識別方法 |
|-------|------|---------|
| **Level 0** | 無 AI | 傳統程式碼風格 |
| **Level 1-2** | 基礎使用 | 偶爾的 AI 痕跡 |
| **Level 3** | 系統化 | CLAUDE.md、高一致性、詳細註解 |
| **Level 4** | 生態化 | 團隊級 AI 協作（未來） |

---

## 5. 輸出格式決策

### 5.1 格式選擇：YAML (v1.0 決策)

**決策結果**：使用 **YAML** 作為 Stage 0 輸出格式

**評估過程**：v1.0 實作期間，曾評估自訂 TOON (Token Optimized Output Notation) 格式

| 特性 | JSON | YAML | TOON (評估) |
|------|------|------|-------------|
| Token 效率 | 基準 | 基準 +15% | 基準 -14% ✅ |
| 生態系統 | 廣泛 | **廣泛** ✅ | 無 |
| 可讀性 | 中 | **高** ✅ | 高 |
| IDE 支援 | ✓ | **✓** ✅ | ✗ |
| 工具支援 | 多 | **多** ✅ | 無 |
| 學習曲線 | 低 | **低** ✅ | 需學習 |

**TOON vs YAML 測試結果** (cursor-talk-to-figma-mcp 專案):
- TOON: 807 tokens
- YAML: 938 tokens
- **差異**: 131 tokens (14% 節省)

**決策理由**：
1. **14% 節省屬於邊際效益** - 非預期的 30-50%
2. **內容佔 85%，結構僅 15%** - 優化結構的效益有限
3. **生態系統價值高** - YAML 有完整工具鏈、IDE 支援、廣泛使用
4. **符合"極簡"哲學** - 使用標準工具，不重新發明輪子
5. **開發效率** - 無需維護自訂解析器和文檔

**完整分析**：見 `dev-notes/toon-vs-yaml-analysis.md`

### 5.2 YAML 格式規範

用於 Stage 0 輸出：

```yaml
metadata:
  project_name: EcommerceAPI
  scan_time: "2025-11-22T10:00:00Z"
  scanned_files: 12
  total_files_estimate: 450

project_fingerprint:
  project_type: WEB_APP
  framework: Rails 7.0
  architecture: Service-oriented
  scale: LARGE

tech_stack:
  backend:
    language: Ruby 3.1
    framework: Rails 7.0
    database: PostgreSQL 14

hypotheses:
  architecture:
    - hypothesis: "使用 Service Object 模式處理商業邏輯"
      confidence: 0.9
      evidence: "app/services/ 有 15 個 Service 類別"
      validation_method: "檢查 Service 類別結構和呼叫方式"
```

> **格式決策歷史**：v1.0 評估了自訂 TOON 格式（14% token 節省），但最終選擇 YAML 以獲得生態系統支援。詳見 `dev-notes/HISTORY.md` 和 `dev-notes/toon-vs-yaml-analysis.md`

---

## 6. Command 介面設計

### 6.1 核心命令（按優先級）

```bash
# 優先級 ⭐⭐⭐⭐⭐ - 最常用功能
/atlas.overview                    # 專案概覽（Stage 0 指紋）
/atlas.overview src/api            # 分析特定目錄
/atlas.pattern "api endpoint"      # 學習專案如何實作 API 端點
/atlas.pattern "background job"    # 學習背景任務模式
/atlas.pattern "file upload"       # 學習檔案上傳流程

# 優先級 ⭐⭐⭐⭐ - 影響範圍分析
/atlas.impact "User authentication"   # 功能改動影響
/atlas.impact api "/api/users/{id}"   # API 改動影響

# 優先級 ⭐⭐⭐⭐ - Git 歷史分析（v2.6 新增）⭐
/atlas.history                        # 整個專案 hotspots
/atlas.history auth                   # 模組分析（自動偵測）
/atlas.history src/auth/login.ts      # 單一檔案詳細分析

# 優先級 ⭐⭐⭐ - 專案設定
/atlas.init                           # 注入 SourceAtlas 觸發規則到 CLAUDE.md

# 未來功能（v2.7+）
/atlas.health             # 專案健康度分析
/atlas.review PR#123      # PR 變更分析
```

**完整三階段分析**（罕見場景）：

針對深度盡職調查場景（評估開源專案、招聘評估、技術盡調），使用 `PROMPTS.md` 手動執行 Stage 0-1-2 完整分析：

```bash
# 適用場景：
✅ 評估開源專案是否適合採用
✅ 評估開發者候選人作品
✅ 技術盡職調查（投資、收購）
✅ 重大重構前的完整評估

# 不適用日常開發工作（使用上述 Commands）
```

### 6.2 Command 定義結構

#### 範例 1: `/atlas.overview` (專案概覽)

```markdown
# .claude/commands/atlas.overview.md

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
5. Output YAML format report

### High-Entropy Priority:
1. Documentation (README, CLAUDE.md)
2. Config files (package.json, etc.)
3. Core models (3-5 samples)
4. Entry points (1-2 samples)
5. Tests (1-2 samples)

Output Format: YAML (Standard format with ecosystem support)
Time Limit: 10-15 minutes
Understanding Target: 70-80%

STOP after Stage 0 - do not proceed to validation or git analysis.
```

#### 範例 2: `/atlas.pattern` (學習設計模式)

```markdown
# .claude/commands/atlas.pattern.md

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

#### 範例 3: `/atlas.init` (專案設定) ⭐ NEW

```markdown
# .claude/commands/atlas.init.md

---
description: Initialize SourceAtlas in current project - inject auto-trigger rules into CLAUDE.md
allowed-tools: Read, Write, Edit
---

# SourceAtlas: Project Initialization

## Purpose

Inject SourceAtlas auto-trigger rules into the project's CLAUDE.md so Claude Code
knows when to automatically suggest using Atlas commands.

## Behavior

1. Check if CLAUDE.md exists in project root
2. If exists: Append SourceAtlas section (avoid duplicates)
3. If not exists: Create minimal CLAUDE.md with SourceAtlas section

## Injected Content (English)

The command injects the following section:

## SourceAtlas Auto-Trigger Rules

When encountering these situations, automatically execute the corresponding command:

| User Intent | Command |
|-------------|---------|
| "What is this project", "Help me understand codebase" | `/atlas.overview` |
| "How to implement X pattern", "Learn the approach" | `/atlas.pattern [pattern]` |
| "What will this change affect" | `/atlas.impact [target]` |
| Just entered project + unfamiliar | `/atlas.overview` |

## Design Rationale

- Similar to spec-kit's `specify init` approach
- Enables Claude Code to auto-suggest Atlas commands contextually
- Uses English by default (international standard)
- Non-invasive: appends to existing CLAUDE.md
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

#### scripts/atlas.stage0.sh

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

#### scripts/atlas.find.sh

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

低熵檔案：重複的 CRUD Controllers, 樣板程式碼
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
- [x] 創建 `.claude/commands/` 目錄結構 ✅
- [x] 實作 `/atlas.overview` - 專案指紋 ⭐⭐⭐⭐⭐ ✅ (2025-11-20)
- [x] 實作 `/atlas.pattern` - 學習模式 ⭐⭐⭐⭐⭐ ✅ (2025-11-22)
- [x] 實作 `find-patterns.sh` 腳本 ✅ (2025-11-22)
- [x] YAML 格式輸出 ✅ (v1.0 決策)

#### Phase 2: 影響分析功能
- [x] 實作 `/atlas.impact` - 靜態影響分析 ⭐⭐⭐⭐ ✅ (2025-11-25)
  - API 變更影響（場景 3B）
  - 前後端調用鏈分析
  - 測試影響評估
  - Swift/ObjC 語言深度分析（自動觸發）

#### Phase 3: 完善與發布 (當前)
- [x] 實作 `/atlas.init` - 專案設定 ⭐⭐⭐ ✅ (2025-11-30)
  - 注入 SourceAtlas 觸發規則到 CLAUDE.md
  - 讓 Claude Code 自動建議使用 Atlas commands
- [x] 擴展多語言支援（Kotlin ✅, Python ✅, TypeScript/React/Vue ✅, Go/Rust 待定）
- [ ] 完善 Git 分析 Scripts
- [ ] 整體測試與文檔
- [ ] 使用者回饋收集
- [ ] 發布 v2.5.4

**決策**: `/atlas.find` 已取消（功能由現有 3 個 commands 涵蓋）

---

## 10. 成功指標

### 10.1 量化指標

| 指標 | 目標值 | 測量方式 | v2.0 驗證結果 |
|------|--------|----------|--------------|
| **理解準確度** | >85% | AI 能正確定位功能 | ✅ 87-100% |
| **Token 節省** | >80% | vs 完整檔案讀取 | ✅ 95%+ |
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
- [x] Stage 0 能在 15 分鐘內完成分析 ✅
- [x] Stage 1 驗證率 >80% ✅
- [x] Stage 2 識別 AI 協作模式 ✅
- [x] `/atlas.overview` 能快速生成專案指紋 ✅ (2025-11-20)
- [x] `/atlas.pattern` 能識別設計模式 ✅ (2025-11-22, 95%+ 準確率)
- [x] `/atlas.impact` 靜態影響分析 ✅ (2025-11-25, 4.2/5 平均評分, 8 subagent 測試)

#### 質量標準
- [x] 在 4+ 真實專案測試通過 ✅ (`/atlas.pattern` 在 3 個大型專案測試)
- [x] Scripts 在 macOS 運行 ✅ (Linux 待測試)
- [x] 錯誤時提供清晰訊息 ✅
- [ ] 使用者回饋 >4/5 分 (待收集)

---

## 11. 實作路線圖

### v2.5.3 - Python Patterns ✅

**目標**：Python 生態系統完整支援

**狀態**：已完成 (2025-11-30)

**成果**：
- ✅ 26 個 Python patterns（12 Tier 1 + 14 Tier 2）
- ✅ 10 個專案測試（Django, FastAPI, Flask, Celery, Scrapy, Pydantic, SQLAlchemy, Starlette, httpx, cookiecutter-django）
- ✅ 框架覆蓋：Django, FastAPI, Flask, Celery, Scrapy, Pydantic, SQLAlchemy, Starlette

---

### v2.5.4 - TypeScript/React/Vue Patterns ✅

**目標**：前端生態系統完整支援（React、Vue、Next.js、Nuxt）

**狀態**：已完成 (2025-11-30)

**成果**：
- ✅ 50 個 TypeScript/React/Vue patterns（25 Tier 1 + 25 Tier 2）
- ✅ 7+ 個前端專案測試
- ✅ 框架覆蓋：React, Vue, Next.js, Nuxt, Zustand, Pinia, TanStack Query, Framer Motion

#### React Tier 1 Patterns（18 個）✅

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

#### Vue Tier 1 Patterns（7 個）✅

| Pattern | 別名 | 用途 |
|---------|------|------|
| Vue Component | sfc, vue | SFC 組件 |
| Composable | composition, vue hook | Composition API |
| Pinia | pinia store, vue store | 狀態管理 |
| Vue Router | vue routes, router | 路由管理 |
| Directive | directives, vue directive | 指令 |
| Vue Plugin | plugin, plugins | 插件 |
| Provide/Inject | provide, inject | 依賴注入 |

#### Tier 2 補充 Patterns（25 個）✅

**React Tier 2（14 個）**：
- Next.js Middleware, Loading, Error
- Server Components, Server Actions
- Background Job, File Upload
- Test (Vitest/Jest), Theme/Styling
- Animation (Framer Motion)
- i18n, Validation (Zod/Yup), tRPC

**Vue Tier 2（11 個）**：
- Nuxt Page, Layout, Middleware, Plugin, Composable
- Vue Transition, Mixin, Filter
- Vue Test, i18n, Router Guard

#### 測試專案 ✅

| 專案 | 類型 | 特色 |
|------|------|------|
| Excalidraw | React | 畫布應用、豐富 Hooks |
| Mantine | React | UI 組件庫、完整 Hooks |
| Shadcn UI | React | 現代 UI 組件 |
| Bulletproof React | React | 最佳實踐範例 |
| Element Plus | Vue | 企業級 UI 組件 |
| VueUse | Vue | Utility Composables |
| Naive UI | Vue | 現代 UI 組件 |

#### 成功指標 ✅
- [x] React patterns 覆蓋率 >90%（常見專案）
- [x] Vue patterns 覆蓋率 >85%（常見專案）
- [x] 準確率 >90%（無大量誤報）
- [x] 7+ 專案驗證

---

### v2.6.0 - `/atlas.history` 時序分析 ⭐ (當前規劃)

**目標**：Git 歷史時序分析，專為 Legacy Codebase 接手者設計

**狀態**：設計確定，準備實作

---

#### 設計決策記錄 (2025-11-30)

**背景**：通過模擬 9 位不同背景開發者的回饋，確定了以下設計方向。

**目標用戶**：**Legacy Codebase 接手者**（最高價值場景）
- 原始專家可能已離職
- 需要快速識別風險區域
- 需要知道「可以問誰」

**命名決策**：`/atlas.history`（3 票勝出）
- ✅ 直覺、跨平台通用
- ✅ 與現有命令風格一致（名詞）
- ✅ 誠實描述資料來源（git history）
- ❌ 避免 `/atlas.tempo`（太抽象）、`/atlas.risk`（過度承諾）

**命令設計**：單一命令，智慧輸出（零參數優先）

```bash
/atlas.history                    # 整個專案概覽（Top 10 hotspots）
/atlas.history auth               # 模組分析（自動偵測）
/atlas.history src/auth/login.ts  # 單一檔案詳細分析
```

**輸出自動調整**：

| 輸入 | 輸出內容 |
|------|---------|
| 無參數 | Top 10 hotspots + 專案健康度 |
| 模組名 | 模組熱點 + 耦合 + 最近貢獻者 |
| 檔案路徑 | 詳細歷史 + 耦合檔案 + 風險評估 |

**核心輸出（三個重點）**：

| 概念 | 用戶問題 | 政治敏感度 |
|------|---------|-----------|
| **Hotspots** | 「哪些檔案最危險？」 | ✅ 安全 |
| **Coupling** | 「改這個會影響什麼？」 | ✅ 安全 |
| **Recent Contributors** | 「這塊誰最熟？」 | ⚠️ 謹慎表達 |

**「可以問誰」的政治友善設計**：

```yaml
# ✅ 正確表達（強調時效性）
recent_contributors:
  - name: Alice
    last_active: 3 days ago
    context: "最近在處理支付邏輯重構"
suggestion: "建議先問 Alice，她最近有在改這塊"

# ❌ 避免（像績效報告）
ownership:
  Alice: 78% (主要負責人)
  風險: Alice 是瓶頸
```

**移除功能**：
- ❌ `/atlas.expert` 反向查詢（「Alice 負責什麼」）- 對 Legacy 接手者價值低

---

#### 與現有命令的關係

| 命令 | 資料來源 | 回答問題 | 使用時機 |
|------|---------|---------|---------|
| `/atlas.overview` | 檔案系統 | 「這是什麼專案？」 | Day 1 快速了解 |
| `/atlas.pattern` | 程式碼 | 「怎麼實作 X？」 | 學習設計模式 |
| `/atlas.impact` | AST 靜態分析 | 「改這個會壞什麼？」 | API 變更前 |
| `/atlas.history` ⭐ | Git 歷史 | 「這個危不危險？問誰？」 | 重構/接手時 |

**完整工作流程**：
```
overview → pattern → impact → history → 動手改
（結構）   （模式）  （靜態）  （歷史）
```

---

#### 日常工作流程驗證

基於 5 個場景的模擬測試：

| 場景 | `/atlas.history` 填補的缺口 |
|------|---------------------------|
| **Bug 修復** | 哪個檔案最常出 bug？誰能幫我？ |
| **新功能** | 這區穩定嗎？跟什麼耦合？ |
| **Code Review** | 這檔案風險多高？誰該 review？ |
| **Onboarding** | 哪裡是地雷區？問誰？ |
| **Refactoring** | **為什麼**變亂的？從哪開始？ |

---

#### 安裝方案

```bash
# 一鍵安裝 code-maat
./scripts/setup/install-codemaat.sh

# 或手動
curl -sSL https://github.com/adamtornhill/code-maat/releases/download/v1.0.4/code-maat-1.0.4-standalone.jar \
  -o ~/.sourceatlas/bin/code-maat.jar
```

---

#### 實作路線圖

**Phase 1: 核心功能（1-2 週）**
- [ ] `install-codemaat.sh` 安裝腳本
- [ ] `/atlas.history` 命令實作
- [ ] Hotspots 分析
- [ ] Coupling 分析
- [ ] Recent Contributors 分析

**Phase 2: 完善（1 週）**
- [ ] iOS 專案自動排除（Pods/, .pbxproj）
- [ ] 風險評估算法
- [ ] 測試與文檔

---

#### 未來候選功能

**SourceAtlas Monitor**（v2.7+）：
```yaml
持續追蹤:
  - 自動偵測變更
  - 趨勢分析
  - 健康度儀表板

技術債務量化:
  - 自動債務偵測
  - 重構建議
  - 優先級排序
```

**決策點**：根據 `/atlas.history` 的使用回饋決定是否建立完整 Monitor 系統

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

**決策**：v2.5 不建立持續索引，留待 v2.6

**理由**：
1. 即時探索場景（找 Bug、學模式）不需要索引
2. 持續追蹤場景（技術債務）才需要索引
3. 先驗證即時探索的價值
4. 避免過度設計

**影響**：
- v2.5 專注於即時分析
- v2.6 再評估是否需要 Monitor

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
   - `/atlas.overview` (專案指紋，10-15 分鐘) vs `/atlas.pattern` (快速學習，5 分鐘)
   - 用戶根據需求選擇合適的命令
   - Commands 提供清晰的功能邊界

3. **開發效率更高**
   - 一個 Command = 一個 .md 檔案
   - 更簡單、更直接
   - 用戶可輕鬆查看和修改

4. **符合優先級排序**
   - `/atlas.overview` ⭐⭐⭐⭐⭐ (專案指紋)
   - `/atlas.pattern` ⭐⭐⭐⭐⭐ (最常用)
   - `/atlas.impact` ⭐⭐⭐⭐ (影響分析)
   - 不同優先級需要不同命令入口

**實作方案**：

```
.claude/commands/
├── atlas.overview.md     # /atlas.overview - 專案指紋 ✅
├── atlas.pattern.md      # /atlas.pattern - 學習模式 ✅
├── atlas.impact.md       # /atlas.impact - 影響分析
├── atlas.find.md         # /atlas.find - 快速搜尋
└── atlas.explain.md      # /atlas.explain - 深入解釋

scripts/atlas/
├── detect-project.sh
├── scan-entropy.sh
├── find-patterns.sh      # 支援 /atlas.pattern
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
"Would you like me to run `/atlas.pattern` to learn how this codebase handles [X]?"
```

但這是**可選的增強**，不影響核心功能。

**影響**：
- PRD 第 3、6、9 章需要更新
- 將 "Skill" 術語改為 "Commands"
- 檔案結構從 `.claude/skills/` 改為 `.claude/commands/`
- 保持斜線命令介面不變（`/atlas.overview`, `/atlas.pattern` 等）

---

## 版本資訊

**當前版本**: v2.6.0 (2025-11-30)

**開發狀態**：
- v1.0 ✅ - 方法論驗證完成（5 專案測試）
- v2.5.4 ✅ - Commands 架構完成
  - `/atlas.overview` ✅ - 專案概覽（已完成，2025-11-20）
  - `/atlas.pattern` ✅ - 模式學習（已完成，2025-11-22）⭐
  - `/atlas.impact` ✅ - 靜態影響分析（已完成，2025-11-25）
  - `/atlas.init` ✅ - 專案初始化（已完成，2025-11-30）
  - **多語言支援**: iOS (34), Kotlin (31), Python (26), TypeScript/React/Vue (50) = 141 patterns
- v2.6.0 🔵 - 時序分析 (設計完成，準備實作)
  - `/atlas.history` 🔵 - Git 歷史分析（設計確定，2025-11-30）
  - **目標用戶**: Legacy Codebase 接手者
  - **核心輸出**: Hotspots + Coupling + Recent Contributors
- **完整三階段分析**：使用 `PROMPTS.md` 手動執行（深度盡職調查場景）

**決策記錄** (2025-11-30):
- ✅ 命名決定：`/atlas.history`（3 票勝出，直覺、跨平台通用）
- ✅ 設計決定：單一命令 + 智慧輸出（零參數優先，利於跨平台移植）
- ✅ 移除 `/atlas.expert` - 對 Legacy 接手者價值低（原作者可能已離職）
- ✅ 政治友善設計：顯示「Recent Contributors」而非「Ownership %」
- ✅ 目標用戶確定：Legacy Codebase 接手者（最高價值場景）

**決策記錄** (2025-11-25):
- ✅ 取消 `/atlas.find` - 功能已由現有 3 個 commands 涵蓋

> **完整版本歷史與決策記錄**：見 `dev-notes/HISTORY.md`

---

*本文件採用 CC-BY-SA 4.0 授權*
