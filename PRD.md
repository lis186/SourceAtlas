# SourceAtlas PRD v2.9.0

**AI-Powered Codebase Understanding Assistant**

- **版本**: 2.9.0
- **更新日期**: 2025-12-08
- **狀態**: 🔵 In Development (v2.9.0 /atlas.deps)

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
- 📜 **品質保證**：Constitution v1.0 確保分析品質一致性

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
v2.7 (已完成) - SourceAtlas Commands ✅
  ├─ Claude Code Commands 整合
  ├─ 6 個核心命令完成
  ├─ Git 歷史時序分析
  └─ 141 個 patterns 支援
  ↓
v2.8.1 - Constitution v1.1 + Handoffs ✅
  ├─ 分析品質框架（7 個 Articles）
  ├─ 自動化合規驗證
  ├─ Monorepo 偵測支援
  └─ 發現驅動 Handoffs（Article VII: Handoffs 原則）
  ↓
v2.8.2 - Branch-Aware Analysis ✅
  ├─ Git 分支偵測
  ├─ Monorepo 子目錄感知
  ├─ Package 名稱識別
  └─ Context-Aware 輸出路徑建議
  ↓
v2.9.0 (當前) - Dependency Analysis ⭐ NEW
  ├─ /atlas.deps 命令
  ├─ Library 使用點分析
  ├─ Breaking Change 對照
  └─ Migration Checklist 生成
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

#### 3B. Library/Framework 升級（⭐ 高頻場景）

**情境**：
```
需要升級 React 17 → 18，或 axios 0.x → 1.x
不確定專案用了哪些 API、哪些會受 breaking changes 影響
```

**傳統方式**：
- 看 Migration Guide，逐項搜尋
- `grep` 搜尋，但可能遺漏動態 import
- 試著升級，看哪裡報錯
- **經常遺漏、耗時數天**

**使用 SourceAtlas**：
```
Developer: /atlas.deps "react"

AI 回應：
=== Dependency Analysis: react ===

📦 版本資訊：
  - 當前版本: 17.0.2
  - 最新穩定版: 18.2.0

📊 使用統計：
  - Import 次數: 156 處
  - 使用的 API: 23 種

🔍 API 使用詳情：

| API | 使用次數 | 檔案數 | React 18 狀態 |
|-----|---------|--------|--------------|
| `useState` | 89 | 45 | ✅ 相容 |
| `useEffect` | 67 | 38 | ✅ 相容 |
| `ReactDOM.render` | 3 | 1 | ⚠️ Deprecated → createRoot |
| `componentWillMount` | 5 | 3 | 🔴 Removed |

⚠️ Breaking Changes 影響：

1. **ReactDOM.render** (3 處)
   - `src/index.tsx:5` - App entry point
   - `src/utils/modal.tsx:12` - Modal helper
   - `tests/setup.ts:3` - Test setup
   → 需改用 `createRoot`

2. **componentWillMount** (5 處)
   - `src/legacy/OldComponent.tsx:15`
   - `src/legacy/AnotherOld.tsx:22`
   → 需改用 `useEffect` 或 `componentDidMount`

📋 Migration Checklist：

- [ ] 更新 src/index.tsx: ReactDOM.render → createRoot
- [ ] 重構 3 個 Legacy 組件的 lifecycle
- [ ] 更新 test setup
- [ ] 檢查 Concurrent Mode 相容性

預估工作量：4-6 小時
風險等級：🟡 中（有 deprecated API）
```

**價值**：
- 完整盤點所有使用點，避免遺漏
- 自動對照 breaking changes
- 生成具體的 Migration Checklist
- 評估工作量和風險

---

#### 3C. API 改動的影響範圍

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
| **即時探索** | 不需歷史資料、即時推理 | ✅ SourceAtlas Commands | |
| 場景 0: 快速理解新專案 ⭐ | 10-15 分鐘獲得全局視角 | ✅ Commands | `/atlas.overview` ⭐⭐⭐⭐⭐ |
| 場景 1: Bug 修復 | 快速定位問題 | ✅ Commands | `/atlas.flow` + `/atlas.impact` |
| 場景 2: 學習模式 | 識別設計模式 | ✅ Commands | `/atlas.pattern` ⭐⭐⭐⭐⭐ |
| 場景 3B: Library 升級 ⭐ | 盤點 dependency 使用點 | ✅ Commands (v2.9) | `/atlas.deps` ⭐⭐⭐⭐⭐ NEW |
| 場景 3C: API 影響分析 | 追蹤 API 調用鏈 | ✅ Commands | `/atlas.impact` ⭐⭐⭐⭐ |
| 場景 4: Code Review | 理解變更意圖 | ✅ Commands | `/atlas.overview` + `/atlas.pattern` |
| **持續追蹤** | 需要歷史資料、趨勢分析 | 🔮 SourceAtlas Monitor (v3.0) | |
| 場景 3A: Model 變更影響 | Git 歷史、關聯分析 | ✅ Commands | `/atlas.history` |
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
│  ├─ /atlas.impact        - Impact Analysis ⭐⭐⭐⭐
│  ├─ /atlas.history       - Git Temporal Analysis ⭐⭐⭐⭐
│  ├─ /atlas.flow          - Flow Tracing ⭐⭐⭐⭐
│  ├─ /atlas.deps          - Dependency Analysis ⭐⭐⭐⭐⭐ NEW
│  └─ /atlas.init          - Project Setup ⭐⭐⭐
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

# 優先級 ⭐⭐⭐⭐⭐ - Dependency 分析（v2.9 新增）⭐ NEW
/atlas.deps "react"                   # 分析 React 使用情況
/atlas.deps "axios"                   # 分析 axios 使用情況
/atlas.deps "lodash" --breaking       # 顯示 breaking changes 影響

# 優先級 ⭐⭐⭐⭐ - 影響範圍分析
/atlas.impact "User authentication"   # 功能改動影響
/atlas.impact api "/api/users/{id}"   # API 改動影響

# 優先級 ⭐⭐⭐⭐ - Git 歷史分析
/atlas.history                        # 整個專案 hotspots
/atlas.history auth                   # 模組分析（自動偵測）
/atlas.history src/auth/login.ts      # 單一檔案詳細分析

# 優先級 ⭐⭐⭐⭐ - 流程追蹤
/atlas.flow "user checkout"           # 追蹤結帳流程
/atlas.flow "from OrderService"       # 從特定 Service 開始追蹤

# 優先級 ⭐⭐⭐ - 專案設定
/atlas.init                           # 注入 SourceAtlas 觸發規則到 CLAUDE.md

# 未來功能（v3.0+）
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

#### 範例 3: `/atlas.deps` (Dependency 分析) ⭐ NEW

```markdown
# .claude/commands/atlas.deps.md

---
description: Analyze dependency usage for library/framework upgrades
allowed-tools: Bash, Glob, Grep, Read, WebFetch
argument-hint: [library name, e.g., "react", "axios", "lodash"]
---

# SourceAtlas: Dependency Analysis

## Context

Target library: $ARGUMENTS

Goal: Analyze how this library is used in the codebase to facilitate upgrade planning.

## Your Task

1. **Identify Current Version**
   - Check package.json, requirements.txt, Cargo.toml, go.mod, etc.
   - Note: locked version vs declared version

2. **Find All Import/Usage Points**
   - Search for import statements
   - Search for require() calls
   - Search for dynamic imports
   - Count total usage occurrences

3. **Categorize API Usage**
   - List all unique APIs/functions used from the library
   - Count usage frequency for each
   - Identify deprecated APIs if known

4. **Breaking Changes Assessment** (if --breaking flag or latest version differs)
   - Fetch library's CHANGELOG or migration guide (WebFetch if needed)
   - Cross-reference with found usages
   - Highlight affected code locations

5. **Generate Migration Checklist**
   - List all files needing changes
   - Provide specific file:line references
   - Estimate effort level

## Output Format

```yaml
dependency_analysis:
  library: [name]
  current_version: [version]
  latest_version: [version]

usage_summary:
  total_imports: [number]
  unique_files: [number]
  api_count: [number]

api_usage:
  - api: [function/class name]
    count: [number]
    files: [list of file:line]
    status: compatible | deprecated | removed

breaking_changes:
  - change: [description]
    affected_files: [count]
    locations:
      - file: [path]
        line: [number]
        current_usage: [code snippet]
        migration: [suggested fix]

migration_checklist:
  - task: [description]
    files: [list]
    effort: low | medium | high

risk_level: low | medium | high
estimated_effort: [hours]
```

## Key Principles

- Focus on USED APIs, not all available APIs
- Provide specific file:line references (Constitution Article IV)
- Include migration suggestions, not just problem identification
- Assess risk honestly
```

---

#### 範例 4: `/atlas.init` (專案設定)

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

> **詳細路線圖與版本歷史**：見 [dev-notes/ROADMAP.md](./dev-notes/ROADMAP.md)
>
> **歷史版本詳細記錄**：見 [dev-notes/archives/2025-11-prd-roadmap-history.md](./dev-notes/archives/2025-11-prd-roadmap-history.md)

### 當前狀態摘要

| 版本 | 狀態 | 主要功能 |
|------|------|----------|
| v1.0 | ✅ | 方法論驗證（5 專案測試） |
| v2.5.4 | ✅ | Commands 架構 + 141 patterns |
| v2.6.0 | ✅ | `/atlas.history` 時序分析 |
| v2.7.0 | ✅ | `/atlas.flow` 流程追蹤（11 種模式） |
| v2.8.1 | ✅ | Constitution v1.1 + Handoffs |
| v2.9.0 | ✅ | `/atlas.deps` 依賴分析 |
| v3.0 | 🔮 | 語言擴展（Go/Ruby）+ Monitor |

### 核心命令

| 命令 | 用途 | 完成日期 |
|------|------|----------|
| `/atlas.init` | 專案初始化 | 2025-11-30 |
| `/atlas.overview` | 專案指紋 | 2025-11-20 |
| `/atlas.pattern` | 學習設計模式 | 2025-11-22 |
| `/atlas.impact` | 影響範圍分析 | 2025-11-25 |
| `/atlas.history` | Git 時序分析 | 2025-11-30 |
| `/atlas.flow` | 流程追蹤 | 2025-12-01 |
| `/atlas.deps` | 依賴分析 | 2025-12-12 |

---

## 附錄 A：設計決策記錄

> **完整設計決策記錄**：見 [dev-notes/archives/decisions/2025-11-prd-design-decisions.md](./dev-notes/archives/decisions/2025-11-prd-design-decisions.md)

### 關鍵決策摘要

| 決策 | 選擇 | 理由 |
|------|------|------|
| CLI vs Commands | Commands | 原生整合、開發快、用戶控制 |
| Scripts 職責 | 只做資料收集 | AI 負責理解推理 |
| 持續索引 | 延後 | 先驗證即時探索價值 |
| YAML vs TOON | YAML | 生態系統 > 14% token 優化 |

---

## 版本資訊

**當前版本**: v2.9.0 (2025-12-08)

**開發狀態**：
- v1.0 ✅ - 方法論驗證完成（5 專案測試）
- v2.5.4 ✅ - Commands 架構完成
  - `/atlas.overview` ✅ - 專案概覽（已完成，2025-11-20）
  - `/atlas.pattern` ✅ - 模式學習（已完成，2025-11-22）⭐
  - `/atlas.impact` ✅ - 靜態影響分析（已完成，2025-11-25）
  - `/atlas.init` ✅ - 專案初始化（已完成，2025-11-30）
  - **多語言支援**: iOS (34), Kotlin (31), Python (26), TypeScript/React/Vue (50) = 141 patterns
- v2.6.0 ✅ - 時序分析完成
  - `/atlas.history` ✅ - Git 歷史分析（已完成，2025-11-30）
  - **核心輸出**: Hotspots + Coupling + Recent Contributors
- v2.7.0 ✅ - Flow 分析完成
  - `/atlas.flow` ✅ - 流程追蹤（已完成，2025-12-01）⭐
  - **11 種分析模式**：語言專屬入口點偵測
  - **10 種邊界類型**：API, DB, LIB, LOOP, MQ, CLOUD, AUTH, PAY, FILE, PUSH
  - **入口點識別準確率**: 60% → 90%
- v2.8.0 ✅ - Constitution v1.0 品質框架
  - **Constitution v1.0** ✅ - 分析行為的不可變原則（已完成，2025-12-05）
  - **validate-constitution.sh** ✅ - 自動化合規驗證
  - **Monorepo 偵測** ✅ - lerna/pnpm/nx/turborepo/npm workspaces
  - **品質改進**: +3900% file:line 引用、-63% 輸出行數、-95% 驗證成本
- v2.8.1 ✅ - 發現驅動 Handoffs
  - **Constitution v1.1** ✅ - 新增 Article VII: Handoffs 原則（已完成，2025-12-06）
  - **動態下一步建議** ✅ - 根據分析發現，建議 1-2 個最相關的後續命令
  - **5 個 Sections**：發現驅動、結束條件、建議數量、參數品質、理由品質
  - **測試結果**：27 個場景 95%+ 成熟度
- v2.9.0 🔵 - Dependency Analysis ⭐ IN PROGRESS
  - `/atlas.deps` 🔵 - Dependency 使用分析（開發中）
  - **核心功能**：Library 使用點盤點、Breaking Change 對照、Migration Checklist
  - **目標場景**：Library/Framework 升級（情境 8）
- **完整三階段分析**：使用 `PROMPTS.md` 手動執行（深度盡職調查場景）

**決策記錄** (2025-12-08) - v2.9.0:
- 🔵 **新增 `/atlas.deps` 命令**：專門處理 Library/Framework 升級場景
  - **問題識別**：情境 8（Library 升級）目前缺乏專門工具
  - **設計選擇**：新建命令（語意清晰）而非擴展 impact（概念混淆）
  - **核心功能**：Usage 盤點、Breaking Change 對照、Migration Checklist
  - **輸出格式**：YAML（符合現有 Constitution 規範）

**決策記錄** (2025-12-06) - v2.8.2:
- ✅ **Branch-Aware Context**：學習 spec-kit 的 context-aware 設計
  - **Git 分支偵測**：自動識別當前分支
  - **Monorepo 子目錄感知**：偵測相對路徑
  - **Package 名稱識別**：從 package.json/Cargo.toml/go.mod/pyproject.toml 提取
  - **Context Metadata**：YAML metadata 包含 `context` 區塊
- ✅ **--save 參數**：可選儲存分析結果至 `.sourceatlas/overview.yaml`
- ✅ **內建品質檢查**：Constitution Section 5.4

**決策記錄** (2025-12-06) - v2.8.1:
- ✅ Constitution v1.1 實作：新增 Article VII: Handoffs 原則
- ✅ 發現驅動 Handoffs 完成：27 個測試場景驗證，95%+ 成熟度
  - **核心洞察**：SourceAtlas 是探索式工具（非線性），不適合 spec-kit 的線性 handoffs
  - **設計選擇**：根據實際發現動態生成建議，而非靜態列出所有可能命令
  - **5 個 Sections**：發現驅動(7.1)、結束條件(7.2)、建議數量(7.3)、參數品質(7.4)、理由品質(7.5)
- ❌ `/atlas.validate` 命令取消：改為內建品質檢查
  - **靈感來源**：spec-kit checklist.md 的 "Unit Tests for English" 概念
  - **取消原因**：獨立命令過度工程化，分析輸出通常即時消費、自己判斷品質
  - **替代方案**：各命令輸出前內建自動檢查，不合規則警告

**決策記錄** (2025-12-05):
- ✅ Constitution v1.0 實作：學習 spec-kit 的 Constitution 模式
- ✅ 7 個 Articles：資訊理論、排除原則、假設原則、證據原則、輸出原則、規模感知、修訂原則

**決策記錄** (2025-12-01):
- ✅ `/atlas.flow` P0-A 準確性改善：語言專屬模式 + 信心評分

**決策記錄** (2025-11-30):
- ✅ 命名決定：`/atlas.history`（3 票勝出，直覺、跨平台通用）
- ✅ 設計決定：單一命令 + 智慧輸出（零參數優先，利於跨平台移植）
- ✅ 移除 `/atlas.expert` - 對 Legacy 接手者價值低（原作者可能已離職）
- ✅ 政治友善設計：顯示「Recent Contributors」而非「Ownership %」

**決策記錄** (2025-11-25):
- ✅ 取消 `/atlas.find` - 功能已由現有 3 個 commands 涵蓋

> **完整版本歷史與決策記錄**：見 `dev-notes/HISTORY.md`

---

*本文件採用 CC-BY-SA 4.0 授權*
