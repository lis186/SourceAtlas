# SourceAtlas - 使用指南

> 🌐 [sourceatlas.io](https://www.sourceatlas.io) | [English](./USAGE_GUIDE.md) | **繁體中文**

**所有斜線命令的完整使用說明**

適用於 Claude Code | v2.11.0 | Constitution v1.1

---

## 目錄

1. [使用情境](#使用情境)
2. [建議流程](#建議流程)
3. [安裝](#安裝)
4. [/sourceatlas:overview](#atlasoverview) - 專案全貌
5. [/sourceatlas:pattern](#atlaspattern) - 學習設計模式
6. [/sourceatlas:impact](#atlasimpact) - 程式碼變更影響
7. [/sourceatlas:history](#atlashistory) - Git 歷史分析
8. [/sourceatlas:flow](#atlasflow) - 執行流程追蹤
9. [/sourceatlas:deps](#atlasdeps) - 依賴分析
10. [/sourceatlas:list](#atlaslist) - 列出快取分析
11. [/sourceatlas:reset](#atlasreset) - 清除快取分析
12. [常見問題](#常見問題)

---

## 使用情境

SourceAtlas 適用於以下常見情境：

| # | 情境 | 主要命令 | 說明 |
|---|------|---------|------|
| 1 | **接手新專案** | `/sourceatlas:overview` | 加入團隊第一天，快速建立全局認知 |
| 2 | **Code Review** | `/sourceatlas:overview` + `/sourceatlas:history` | 評估程式碼品質和專案演進 |
| 3 | **修 Bug** | `/sourceatlas:flow` | 追蹤執行路徑，定位問題根源 |
| 4 | **新增功能** | `/sourceatlas:pattern` + `/sourceatlas:impact` | 學習現有慣例，評估影響範圍 |
| 5 | **面試評估候選人 GitHub** | `/sourceatlas:overview` + `/sourceatlas:history` | 快速判斷開發能力和習慣 |
| 6 | **學習開源專案** | `/sourceatlas:overview` + `/sourceatlas:pattern` | 理解架構設計和 best practices |
| 7 | **Breaking Change 評估** | `/sourceatlas:impact` + `/sourceatlas:flow` | 修改自己的 API，找出所有呼叫方 |
| 8 | **Library/Framework 升級** | `/sourceatlas:impact` + `/sourceatlas:pattern` | 升級第三方套件，找出使用點、學新寫法 |

### 不同經驗等級的切入點

| 經驗等級 | 主要挑戰 | 建議起點 |
|---------|---------|---------|
| **Junior** | 不知道怎麼「讀」程式碼、容易迷失在細節 | `/sourceatlas:overview` 給全局地圖 → `/sourceatlas:pattern` 學習慣例 |
| **Mid-level** | 知道怎麼讀，但效率不高、容易遺漏 | `/sourceatlas:flow` 追蹤執行路徑 → `/sourceatlas:impact` 評估改動範圍 |
| **Senior** | 效率還行，但想更快、想驗證假設 | `/sourceatlas:history` 看演進脈絡，快速驗證架構猜測 |

---

## 建議流程

### 標準 5 步流程（適用大多數情境）

```
1. /sourceatlas:overview     → 建立全局認知（5-10 分鐘）
2. /sourceatlas:pattern      → 學習該專案的慣例（按需）
3. /sourceatlas:flow         → 追蹤特定功能流程（按需）
4. /sourceatlas:impact       → 評估改動影響（準備動手時）
5. /sourceatlas:history      → 了解演進脈絡（深入時）
```

### 依情境的變體

**情境 1-2：快速理解專案**
```
/sourceatlas:overview → /sourceatlas:history（可選）
```

**情境 3：修 Bug**
```
/sourceatlas:flow "從 [entry point] 開始" → 定位問題
```

**情境 4：新增功能**
```
/sourceatlas:pattern "[功能類型]" → /sourceatlas:impact "[相關檔案]"
```

**情境 7-8：升級評估**
```
/sourceatlas:impact "[API 或 library]" → /sourceatlas:pattern "[新版寫法]"
```

---

## 安裝

**完整 Plugin 指南**：[plugin/README.md](./plugin/README.md)

### 快速開始

```bash
# 在 Claude Code 中執行：
/plugin marketplace add lis186/SourceAtlas
/plugin install sourceatlas@lis186-SourceAtlas
```

本地開發/測試：
```bash
git clone https://github.com/lis186/SourceAtlas.git
claude --plugin-dir ./SourceAtlas/plugin
```

**Agent Skills**：v2.10+ 起，Claude 會根據你的問題自動建議合適的分析 — 不用記指令！

---

## /sourceatlas:overview

**快速理解專案全貌**

### 使用方式

```bash
/sourceatlas:overview
```

### 你會得到什麼

- **技術棧**：語言、框架、資料庫
- **架構模式**：MVC、MVVM、Clean Architecture...
- **專案規模**：檔案數、程式碼行數
- **程式碼品質**：測試覆蓋率、註解密度
- **目錄結構**：關鍵資料夾和檔案

### 使用時機

- ✅ 接手新專案
- ✅ Code Review
- ✅ 技術評估
- ✅ 招聘評估（看候選人的 GitHub 專案）

### 執行時間

- **小專案** (<5K LOC): 5-10 分鐘
- **中型專案** (5K-50K LOC): 10-15 分鐘
- **大型專案** (>50K LOC): 15-20 分鐘

### 使用範例

#### 範例 1: 接手新專案

**情境**：加入團隊第一天，需要快速理解 50K LOC 的專案

**命令**：
```bash
/sourceatlas:overview
```

**輸出**（摘要）：
```yaml
project_type: WEB_APP
primary_language: TypeScript
frameworks:
  - Next.js 14
  - React 18
  - Prisma
architecture_pattern: CLEAN_ARCHITECTURE
test_coverage: 85%
key_directories:
  - src/app/ (Next.js App Router)
  - src/components/ (React Components)
  - prisma/ (Database Schema)
```

**你學到什麼**：
- 這是用 Next.js 14 + React 的全端專案
- 使用 Clean Architecture（程式碼品質高）
- 測試覆蓋率 85%（專業團隊）
- 主要邏輯在 src/app/（App Router 架構）

**下一步**：用 `/sourceatlas:pattern "api endpoint"` 學習 API 實作方式

---

## /sourceatlas:pattern

**學習專案的設計模式**

### 使用方式

```bash
/sourceatlas:pattern "api endpoint"
/sourceatlas:pattern "file upload"
/sourceatlas:pattern "authentication"
```

### 什麼是 "Pattern"？

在 SourceAtlas 中，**Pattern（模式）** 是指專案中重複出現的程式碼結構與設計方式：

- **架構模式**：MVVM、Clean Architecture、Repository
- **實作模式**：API endpoint、檔案上傳、身份驗證
- **UI 模式**：SwiftUI view、React component、自訂按鈕

簡單說就是：**「這個專案通常怎麼實作 X？」**

### 你會得到什麼

1. **最佳範例檔案** (2-3 個) + file:line 引用
2. **關鍵慣例**：命名、結構、組織方式
3. **測試模式**：如何測試這個功能
4. **實作指南**：逐步實作新功能

### 支援的 Patterns (221 個)

#### 快速總覽

| 語言 | Pattern 數量 | 主要類別 |
|------|-------------|----------|
| **iOS/Swift** | 34 | 架構、UI、資料處理、功能模組 |
| **TypeScript/React/Vue** | 50 | React 核心、Vue 核心、後端整合 |
| **Android/Kotlin** | 31 | Architecture Components、UI、資料層 |
| **Python** | 26 | Django、FastAPI、Flask、Celery |
| **Ruby/Rails** | 26 | ActiveRecord、Controller、Service、Job |
| **Go** | 26 | Handler、Service、Middleware、Transport |
| **Rust** | 28 | Handler、Service、Middleware、Runtime |

#### 熱門 Patterns（跨語言）

1. `api endpoint` - REST/GraphQL API 實作
2. `authentication` - 登入/認證流程
3. `view controller` - 畫面/頁面組件
4. `networking` - HTTP 客戶端模式
5. `state management` - 應用程式狀態管理

<details>
<summary><b>📱 iOS/Swift Patterns (34 個)</b></summary>

#### 核心架構 (4)
- `mvvm` - MVVM 架構模式
- `coordinator` - Coordinator 導航模式
- `dependency injection` - DI Container/Factory
- `repository` - Repository 資料存取模式

#### UI 組件 (7)
- `swiftui view` - SwiftUI 視圖組合
- `view controller` - UIKit ViewController
- `table view cell` - TableView/CollectionView Cell
- `view modifier` - SwiftUI ViewModifier
- `custom view` - 自訂 UI 元件
- `collection view layout` - CollectionView 自訂佈局
- `animation` - UI 動畫

#### 資料處理 (8)
- `networking` - 網絡層、API Client
- `core data` - Core Data 持久化
- `api endpoint` - REST/GraphQL API
- `cache` - 快取管理
- `user defaults` - 本地儲存
- `keychain` - 安全儲存
- `codable` - JSON 編解碼
- `combine publisher` - Reactive 資料流

#### 功能模組 (10)
- `authentication` - 認證流程
- `file upload` - 檔案上傳
- `background job` - 異步任務
- `error handling` - 錯誤處理
- `localization` - 國際化
- `push notification` - 推播通知
- `deep linking` - Deep Link 處理
- `image loading` - 圖片載入與快取
- `biometric auth` - Face ID/Touch ID
- `analytics` - 事件追蹤

</details>

<details>
<summary><b>⚛️ TypeScript/React/Vue Patterns (50 個)</b></summary>

#### React 基礎 (6)
- `react component` - React 組件
- `react hook` - 自定義 Hooks
- `state management` - 狀態管理
- `form handling` - 表單處理
- `context provider` - Context API
- `error boundary` - 錯誤邊界

#### Next.js 專屬 (8)
- `nextjs middleware` - 中間件
- `nextjs layout` - App Router 佈局
- `nextjs page` - 頁面組件
- `nextjs loading` - 載入狀態
- `nextjs error` - 錯誤處理
- `server component` - 伺服器組件
- `server action` - Server Actions
- `route handler` - API 路由處理

#### 後端整合 (8)
- `api endpoint` - API 路由
- `database query` - Prisma/ORM
- `authentication` - Auth.js/NextAuth
- `api client` - Fetch/Axios 封裝
- `websocket` - WebSocket 連線
- `graphql` - GraphQL 查詢
- `file upload` - 檔案上傳
- `caching strategy` - 快取策略

</details>

<details>
<summary><b>🤖 Android/Kotlin Patterns (31 個)</b></summary>

#### Architecture Components (8)
- `view controller` - Activity/Fragment
- `view model` - ViewModel (AAC)
- `repository` - Repository Pattern
- `use case` - UseCase/Interactor
- `dependency injection` - Hilt/Koin
- `navigation component` - Navigation 架構
- `room database` - Room 持久化
- `data store` - DataStore 偏好設定

#### UI 層 (6)
- `compose ui` - Jetpack Compose
- `recycler view` - RecyclerView Adapter
- `view binding` - ViewBinding
- `custom view` - 自訂 View
- `animation` - 動畫效果
- `material design` - Material Components

#### 資料與網路 (6)
- `retrofit api` - Retrofit 網路請求
- `coroutines` - Kotlin Coroutines
- `flow` - Kotlin Flow
- `api endpoint` - REST API 實作
- `authentication` - 登入認證
- `file handling` - 檔案處理

</details>

**試用範例**：`/sourceatlas:pattern "api endpoint"`

### 執行時間

**0.1 - 30 秒**（取決於專案大小）

### 使用範例

#### 範例 1: 學習 API 設計

**情境**：要新增一個 API endpoint，不確定專案的寫法

**命令**：
```bash
/sourceatlas:pattern "api endpoint"
```

**輸出**（摘要）：
```
## Best Examples

1. `src/app/api/users/route.ts:15` - GET /api/users
2. `src/app/api/users/[id]/route.ts:20` - GET /api/users/:id
3. `src/app/api/posts/route.ts:10` - POST /api/posts

## Key Conventions

- File: `app/api/[resource]/route.ts`
- Export: `GET`, `POST`, `PUT`, `DELETE`
- Response: `NextResponse.json(data, { status })`
- Error: Try-catch with NextResponse

## Implementation Guide

1. Create `app/api/[resource]/route.ts`
2. Export async function GET/POST
3. Use Prisma for database access
4. Return NextResponse.json()
```

**你學到什麼**：
- 這個專案用 Next.js App Router（不是 Pages Router）
- API 都在 `app/api/` 目錄，用 `route.ts` 命名
- 統一用 Prisma 存取資料庫
- 錯誤處理用 try-catch + NextResponse

**下一步**：照著 Implementation Guide 建立你的新 API

#### 範例 2: 學習 SwiftUI 組件

**情境**：要寫一個自訂 SwiftUI 元件，想學習專案的慣例

**命令**：
```bash
/sourceatlas:pattern "swiftui view"
```

**輸出**（摘要）：
```
## Best Examples

1. `Views/ProductCard.swift:10` - Reusable Card Component
2. `Views/UserProfile.swift:25` - Screen-level View
3. `Views/Components/Button.swift:5` - Custom Button

## Key Conventions

- File: `Views/[ComponentName].swift`
- Struct: Conform to `View` protocol
- Body: Use ViewBuilder
- Preview: Always include PreviewProvider

## Implementation Guide

1. Create new Swift file in Views/
2. Import SwiftUI
3. Struct [Name]: View { var body: some View { ... } }
4. Add PreviewProvider
```

**你學到什麼**：
- 所有 SwiftUI 組件都放在 `Views/` 目錄
- 小型可重用元件放在 `Views/Components/`
- 每個組件必須有 PreviewProvider（團隊標準）
- 命名慣例：大寫開頭的 PascalCase

**下一步**：照著範例檔案的結構，建立你的新元件

---

## /sourceatlas:impact

**分析程式碼變更影響**

### 使用方式

```bash
# 分析檔案
/sourceatlas:impact "src/api/users.ts"

# 分析 API
/sourceatlas:impact api "/api/users/{id}"

# 分析 Model
/sourceatlas:impact "User model"
```

### 你會得到什麼

1. **依賴追蹤**：哪些檔案使用這個 API/Model/Component
2. **Breaking Changes**：哪些變更會破壞現有程式碼
3. **測試影響**：需要更新哪些測試
4. **Migration Checklist**：逐步遷移指南

**iOS 專案特別功能** ⭐:
- Swift/ObjC Interop 風險分析
- Nullability 檢查
- @objc 暴露分析
- Memory 管理問題

### 執行時間

**1-2 分鐘**（大型專案可能需要 2-3 分鐘）

### 使用範例

#### 範例 1: API 重構

**情境**：要重構 `/api/users/{id}` 端點，擔心影響現有功能

**命令**：
```bash
/sourceatlas:impact api "/api/users/{id}"
```

**輸出**（摘要）：
```
## Impact Analysis: /api/users/{id}

### Direct Dependencies (23 files)

1. `src/components/UserProfile.tsx:45` - Fetch user data
2. `src/components/UserCard.tsx:20` - Display user info
3. `src/app/dashboard/page.tsx:30` - Load user list
...

### Breaking Changes 🔴

1. Changing response structure → 15 components need update
2. Adding authentication → 8 API calls need headers
3. Renaming fields → 12 TypeScript interfaces need update

### Migration Checklist

- [ ] Update UserProfile component
- [ ] Update UserCard component
- [ ] Update TypeScript types
- [ ] Update tests (8 test files)
- [ ] Update API documentation
```

**你學到什麼**：
- 這個 API 被 23 個檔案使用（影響範圍大）
- 有 3 種可能的 Breaking Changes
- 需要更新 8 個測試檔案
- 有完整的 Migration Checklist 可以照著做

**下一步**：照著 Migration Checklist 逐步修改，避免遺漏

#### 範例 2: iOS Model 修改

**情境**：要修改 Swift Model，擔心影響 Objective-C 程式碼（混合專案）

**命令**：
```bash
/sourceatlas:impact "User.swift"
```

**輸出**（摘要）：
```
## Impact Analysis: User.swift

### Swift/ObjC Interop Risks 🔴

**Nullability Coverage**: 6% (CRITICAL)
- 2,255 header files missing NS_ASSUME_NONNULL
- Impact: Properties become `!` in Swift → Runtime crashes

**@objc Exposure**:
- 1,135 classes exposed to ObjC
- Changing User.swift affects 45 ObjC files

**Auto-fix Available**:
```bash
# Add nullability to all headers
find . -name '*.h' -not -path '*/Pods/*' -exec \
  sed -i '' '1i\NS_ASSUME_NONNULL_BEGIN' {} \;
```

### Direct Dependencies (45 files)

1. `UserViewController.m:120` - ObjC View Controller
2. `UserCell.m:35` - TableView Cell
...
```

**你學到什麼**：
- 這是 Swift/ObjC 混合專案（iOS 特殊場景）
- Nullability 覆蓋率只有 6%（高風險！）
- 修改 User.swift 會影響 45 個 ObjC 檔案
- 有自動修復腳本可以加上 NS_ASSUME_NONNULL

**下一步**：先執行 Auto-fix 腳本改善 Nullability，再修改 Model

---

## /sourceatlas:history

**分析 git 歷史，找出熱點和團隊知識分布**

### 使用方式

```bash
/sourceatlas:history
/sourceatlas:history src/
```

### 你會得到什麼

1. **熱點**：頻繁修改的檔案（可能複雜或有風險）
2. **時間耦合**：經常一起修改的檔案（隱藏的依賴關係）
3. **近期貢獻者**：誰對哪個區域最熟悉
4. **風險評估**：巴士因子風險和知識集中度

### 執行時間

**5-10 分鐘**（分析 git commit 歷史）

### 前置需求

- 需要 `code-maat`（首次執行時會詢問是否自動安裝）
- Java 8+ 執行環境

### 使用範例

#### 範例 1: 專案全域分析

**情境**：想找出風險區域，了解團隊知識分布

**命令**：
```bash
/sourceatlas:history
```

**輸出**（摘要）：
```
## 熱點 (Top 10)

| 排名 | 檔案 | 修改次數 | 行數 | 複雜度分數 |
|------|------|---------|-----|-----------|
| 1 | src/core/processor.ts | 45 | 892 | 40,140 |
| 2 | src/api/handlers.ts | 38 | 456 | 17,328 |

## 時間耦合 (顯著配對)

| 檔案 A | 檔案 B | 耦合度 | 共同修改次數 |
|--------|--------|--------|-------------|
| src/user/model.ts | src/user/service.ts | 0.85 | 23 |

## 巴士因子風險

- `src/legacy/` - 過去 6 個月只有 1 位貢獻者
- `src/payments/` - 主要貢獻者 3 個月前離開
```

**你學到什麼**：
- `processor.ts` 是熱點，修改了 45 次（可能有技術債）
- User model 和 service 高度耦合（預期內，同一領域）
- Legacy 程式碼有巴士因子風險（需要知識轉移）

**下一步**：用 `/sourceatlas:impact "src/core/processor.ts"` 了解依賴關係後再重構

---

## /sourceatlas:flow

**從入口點追蹤執行流程到邊界**

### 使用方式

```bash
/sourceatlas:flow "user login"
/sourceatlas:flow "checkout process"
/sourceatlas:flow "from LoginViewController"
```

### 你會得到什麼

1. **入口點**：流程從哪裡開始（controllers、handlers 等）
2. **執行路徑**：完整的呼叫鏈，附帶 file:line 引用
3. **邊界識別**：外部接觸點（API、DB、Auth、Payment）
4. **資料流**：資料如何在流程中轉換

### 11 種分析模式

| 模式 | 觸發方式 | 說明 |
|------|---------|------|
| 元件追蹤 | `"from 元件名稱"` | 從特定元件開始追蹤 |
| 功能流程 | `"功能名稱"` | 完整功能執行路徑 |
| API 追蹤 | `"API /路徑"` | 追蹤 API 端點處理 |
| 事件流程 | `"event 名稱"` | 追蹤事件傳播 |
| 資料流程 | `"data 實體名稱"` | 追蹤資料轉換 |
| 錯誤流程 | `"error handling"` | 錯誤傳播路徑 |
| 認證流程 | `"authentication"` | 追蹤認證/權限檢查 |
| 狀態流程 | `"state 狀態名稱"` | 追蹤狀態變化 |
| 整合流程 | `"integration 服務名稱"` | 外部服務呼叫 |
| 生命週期 | `"lifecycle 元件名稱"` | 追蹤元件生命週期 |
| 導航流程 | `"navigation"` | 導航結構 |

### 執行時間

**3-5 分鐘**（取決於流程複雜度）

### 使用範例

#### 範例 1: 理解登入流程

**情境**：需要了解程式碼中的用戶認證流程

**命令**：
```bash
/sourceatlas:flow "user login"
```

**輸出**（摘要）：
```
## 入口點

1. `LoginViewController.swift:25` - UI 入口點
2. `AuthAPI.swift:40` - API 入口點

## 執行路徑

LoginViewController.swift:25
  ↓ loginButtonTapped()
  ↓ AuthService.swift:30 - login(email:password:)
    ↓ APIClient.swift:45 - post("/auth/login")
    ↓ TokenManager.swift:20 - saveToken()
  ↓ NavigationCoordinator.swift:50 - showDashboard()

## 識別到的邊界

| 類型 | 位置 | 用途 |
|------|------|------|
| API | APIClient.swift:45 | 認證端點呼叫 |
| 儲存 | TokenManager.swift:20 | 安全 token 儲存 |
| 導航 | NavigationCoordinator.swift:50 | 畫面轉換 |
```

**你學到什麼**：
- 登入有 2 個入口點（UI 和 API）
- 流程經過 4 個元件：ViewController → Service → APIClient → TokenManager
- Token 安全儲存（TokenManager 使用 Keychain）
- 使用 Coordinator 模式進行導航

**下一步**：用 `/sourceatlas:pattern "authentication"` 學習認證實作慣例

#### 範例 2: 追蹤結帳流程

**情境**：需要修改結帳功能，想先了解完整流程

**命令**：
```bash
/sourceatlas:flow "checkout process"
```

**輸出**（摘要）：
```
## 執行路徑

CartViewController.swift:100
  ↓ checkoutButtonTapped()
  ↓ CheckoutService.swift:25 - initiateCheckout(cart:)
    ↓ PaymentGateway.swift:40 - processPayment()
    ↓ OrderService.swift:60 - createOrder()
    ↓ InventoryService.swift:30 - reserveItems()
  ↓ ConfirmationViewController.swift:15 - show()

## 識別到的邊界

| 類型 | 位置 | 用途 |
|------|------|------|
| 支付 | PaymentGateway.swift:40 | 外部支付 API |
| 資料庫 | OrderService.swift:60 | 訂單持久化 |
| 庫存 | InventoryService.swift:30 | 庫存管理 |
```

**你學到什麼**：
- 結帳涉及支付、訂單、庫存三個系統
- PaymentGateway 是外部 API 邊界（修改風險高）
- 共 5 個服務參與這個流程

**下一步**：修改前先用 `/sourceatlas:impact "CheckoutService.swift"` 評估影響

---

## /sourceatlas:deps

**分析 Library/Framework 使用情況，協助升級規劃**

### 使用方式

```bash
/sourceatlas:deps "react"
/sourceatlas:deps "axios"
/sourceatlas:deps "lodash" --breaking
```

### 什麼是 Dependency 分析？

當你需要升級某個 library 或 framework 時，需要知道：
- 專案用了這個 library 的**哪些 API**？
- 哪些 API 在新版本會有 **breaking changes**？
- 需要修改**哪些檔案**？

`/sourceatlas:deps` 幫你自動盤點所有使用點，對照 breaking changes，生成 migration checklist。

### 你會得到什麼

1. **版本資訊**：當前版本 vs 最新版本
2. **使用統計**：import 次數、檔案數、API 種類
3. **API 使用詳情**：每個 API 的使用次數和位置
4. **Breaking Changes 影響**：哪些使用會受影響
5. **Migration Checklist**：需要修改的檔案和建議

### 執行時間

**1-3 分鐘**（取決於專案大小和 library 使用量）

### 使用範例

#### 範例 1: React 升級評估

**情境**：專案使用 React 17，想升級到 React 18

**命令**：
```bash
/sourceatlas:deps "react"
```

**輸出**（摘要）：
```
=== Dependency Analysis: react ===

📦 版本資訊：
  - 當前版本: 17.0.2
  - 最新穩定版: 18.2.0

📊 使用統計：
  - Import 次數: 156 處
  - 使用的 API: 23 種

🔍 API 使用詳情：

| API | 使用次數 | React 18 狀態 |
|-----|---------|--------------|
| useState | 89 | ✅ 相容 |
| useEffect | 67 | ✅ 相容 |
| ReactDOM.render | 3 | ⚠️ Deprecated |
| componentWillMount | 5 | 🔴 Removed |

⚠️ Breaking Changes 影響：

1. ReactDOM.render (3 處)
   - src/index.tsx:5
   - src/utils/modal.tsx:12
   → 需改用 createRoot

2. componentWillMount (5 處)
   - src/legacy/OldComponent.tsx:15
   → 需改用 useEffect

📋 Migration Checklist：
- [ ] 更新 src/index.tsx
- [ ] 重構 Legacy 組件
- [ ] 更新 test setup

預估工作量：4-6 小時
風險等級：🟡 中
```

**你學到什麼**：
- 專案有 156 處使用 React
- 大部分 API 相容，但有 3 處需要修改 `ReactDOM.render`
- 有 5 個 Legacy 組件使用已移除的 lifecycle
- 預估 4-6 小時可以完成升級

**下一步**：按照 Migration Checklist 逐一修改

#### 範例 2: axios 升級

**情境**：axios 從 0.x 升級到 1.x

**命令**：
```bash
/sourceatlas:deps "axios" --breaking
```

**輸出**（摘要）：
```
=== Dependency Analysis: axios ===

📦 版本資訊：
  - 當前版本: 0.27.2
  - 最新穩定版: 1.6.2

⚠️ Breaking Changes 影響：

1. Response type changes
   - 12 處使用 response.data 的地方
   - TypeScript 類型需要更新

2. Error handling
   - 8 處 catch block 需要調整
   - error.response 結構改變

📋 Migration Checklist：
- [ ] 更新 TypeScript 類型定義
- [ ] 調整 8 處 error handling
- [ ] 更新 interceptors 寫法

預估工作量：2-3 小時
風險等級：🟡 中
```

---

## /sourceatlas:list

**列出快取的分析結果**

### 使用方式

```bash
/sourceatlas:list
```

### 你會得到什麼

顯示 `.sourceatlas/` 中所有快取分析的表格：

```
📁 .sourceatlas/ 已儲存的分析：

| 類型 | 檔案 | 大小 | 修改時間 | 狀態 |
|------|------|------|---------|------|
| overview | overview.yaml | 2.3 KB | 3 天前 | ✅ |
| pattern | patterns/api.md | 1.5 KB | 45 天前 | ⚠️ |
| history | history.md | 4.2 KB | 60 天前 | ⚠️ |

📊 統計：3 個快取，2 個過期（>30 天）
```

### 過期警告

- 超過 **30 天** 的分析會標記 ⚠️
- 過期的分析可能不再反映程式碼庫的現狀
- 使用 `--force` 標記重新分析：`/sourceatlas:overview --force`

---

## /sourceatlas:reset

**清除快取的分析結果**

### 使用方式

```bash
# 清除所有快取分析
/sourceatlas:reset

# 清除特定類型
/sourceatlas:reset overview
/sourceatlas:reset patterns
/sourceatlas:reset history
```

### 支援的目標

| 目標 | 路徑 | 說明 |
|------|------|------|
| `overview` | `.sourceatlas/overview.yaml` | 專案全貌 |
| `patterns` | `.sourceatlas/patterns/` | Pattern 分析 |
| `flows` | `.sourceatlas/flows/` | 流程追蹤 |
| `history` | `.sourceatlas/history.md` | Git 歷史分析 |
| `impact` | `.sourceatlas/impact/` | 影響分析 |
| `deps` | `.sourceatlas/deps/` | 依賴分析 |
| （無參數） | `.sourceatlas/*` | 清除全部 |

### 需要確認

命令會顯示將被刪除的內容，並在執行前要求確認。

---

## 常見問題

### Q: 命令執行失敗怎麼辦？

**A**: 檢查以下幾點：

1. **確認 Plugin 已載入**:
   ```bash
   # 確保你是用這個方式啟動 Claude Code：
   claude --plugin-dir ./SourceAtlas/plugin
   ```

2. **確認在專案目錄**:
   ```bash
   pwd  # 應該在你的專案根目錄
   ```

3. **查看錯誤訊息**: 命令會顯示詳細錯誤，通常是路徑問題

### Q: 可以自定義 patterns 嗎？

**A**: 可以！編輯 `scripts/atlas/patterns/` 下的配置檔案。

範例：新增自定義 pattern
```bash
# 1. 複製現有 pattern
cp scripts/atlas/patterns/ios/networking.sh scripts/atlas/patterns/ios/custom-pattern.sh

# 2. 修改檔案內容
# 3. 重新載入 Claude Code
```

### Q: 支援哪些專案類型？

**A**: 目前支援：

- ✅ iOS (Swift + Objective-C)
- ✅ TypeScript (React + Next.js)
- ✅ Android (Kotlin)
- ✅ Python (26 patterns)
- ✅ Ruby (26 patterns)
- ✅ Go (26 patterns)
- ✅ Rust (28 patterns)

### Q: 分析結果保存在哪裡？

**A**:
- 輸出直接顯示在 Claude Code 對話中
- 加上 `--save` 標記來持久化結果：`/sourceatlas:overview --save`
- 已儲存的分析會放在 `.sourceatlas/` 目錄
- 用 `/sourceatlas:list` 查看已快取的分析
- 快取的分析在重新執行時會自動載入（加 `--force` 可強制重新分析）

### Q: 可以分析私有 codebase 嗎？

**A**: 可以！所有分析都在本地執行，程式碼不會上傳。

### Q: 效能如何？會不會很慢？

**A**:
- `/sourceatlas:overview`: 10-15 分鐘
- `/sourceatlas:pattern`: 0.1-30 秒
- `/sourceatlas:impact`: 1-2 分鐘

使用資訊理論原則，只掃描 <5% 檔案。

### Q: 支援 Monorepo 嗎？

**A**: 支援！建議在每個子專案目錄執行命令。

範例：
```bash
cd packages/web
/sourceatlas:overview

cd ../api
/sourceatlas:overview
```

---

## 進階使用

### 組合使用命令

**場景**: 接手新專案並要新增功能

```bash
# Step 1: 理解專案 (10 分鐘)
/sourceatlas:overview

# Step 2: 學習現有實作 (0.1 秒)
/sourceatlas:pattern "api endpoint"
/sourceatlas:pattern "authentication"

# Step 3: 分析影響 (1 分鐘)
/sourceatlas:impact "src/api/auth.ts"
```

**總時間**: 15 分鐘內完整掌握專案

---

## 疑難排解

### 問題 1: 找不到 patterns

**症狀**: `/sourceatlas:pattern` 回報「No patterns found」

**解決方式**:
1. 確認專案類型是否支援（iOS/TypeScript/Android）
2. 檢查檔案結構是否符合慣例
3. 嘗試更通用的 pattern 名稱（如用 "api" 而非 "api endpoint"）

### 問題 2: Swift Analyzer 沒有執行

**症狀**: iOS 專案沒有顯示 Swift/ObjC interop 分析

**解決方式**:
1. 確認專案有 `.xcodeproj`、`.xcworkspace`、`Package.swift` 或 `Project.swift` (Tuist)
2. 確認目標檔案是 `.swift`、`.m` 或 `.h`
3. 檢查 `scripts/atlas/analyzers/swift-analyzer.sh` 是否存在

### 問題 3: 執行時間過長

**症狀**: `/sourceatlas:overview` 超過 20 分鐘還沒完成

**診斷步驟**（執行這些命令找出原因）:

```bash
# 1. 檢查實際程式碼行數（應 <100K）
find . -name "*.swift" -o -name "*.ts" -o -name "*.kt" | \
  grep -v "node_modules\|Pods\|build" | \
  xargs wc -l 2>/dev/null | tail -1

# 2. 檢查大型二進制檔案（應被排除）
find . -type f -size +10M | head -10

# 3. 檢查 .gitignore 設定
cat .gitignore | grep -E "node_modules|Pods|build|\.app"
```

**解決方式**：

| 根本原因 | 修復方法 | 預期改善 |
|---------|---------|---------|
| 缺少 .gitignore | 加入 `node_modules/`, `Pods/`, `*.app` | 速度提升 80% |
| 專案過大 (>100K LOC) | 在子目錄執行：`cd src && /sourceatlas:overview` | 依子目錄數量分散時間 |
| 網路延遲 | 檢查 [Claude API 狀態](https://status.anthropic.com) | 等待或稍後重試 |

**仍然緩慢？** 請[回報問題](https://github.com/lis186/SourceAtlas/issues)並附上診斷結果

### 問題 4: 命令找不到

**症狀**: 執行 `/sourceatlas:overview` 時顯示「Command not found」

**診斷步驟**:

```bash
# 1. 確保你是用 plugin 方式啟動
claude --plugin-dir ./SourceAtlas/plugin

# 2. 檢查 Claude Code 版本（需要 1.0.33+）
claude --version
```

**解決方式**：

| 檢查結果 | 原因 | 修復方法 |
|---------|------|---------|
| Plugin 未載入 | 未使用 --plugin-dir 參數 | 執行 `claude --plugin-dir ./SourceAtlas/plugin` |
| Claude Code 版本過舊 | 不支援 Plugins（需要 1.0.33+） | 更新 Claude Code 到最新版本 |

### 問題 5: 輸出格式不正確

**症狀**: `/sourceatlas:overview` 輸出純文字而非 YAML 格式

**診斷步驟**:

```bash
# 檢查 plugin 中的 prompt 文件內容
head -20 ./SourceAtlas/plugin/commands/sourceatlas:overview.md
```

**可能原因**：

| 症狀 | 原因 | 修復方法 |
|------|------|---------|
| 缺少 frontmatter (---) | 檔案損壞 | 重新 clone repository |
| 內容是舊版本 | 未更新到最新版 | `cd SourceAtlas && git pull` |
| YAML 語法錯誤 | AI 解析問題 | 重新執行命令（Claude 隨機性） |

### 問題 6: Pattern 搜尋結果不準確

**症狀**: `/sourceatlas:pattern "api"` 回傳不相關的檔案

**常見原因與解決**：

| 情況 | 原因 | 改善方法 |
|------|------|---------|
| 找到測試檔案而非實作 | Pattern 太通用 | 使用更具體的關鍵字：`/sourceatlas:pattern "api endpoint"` |
| 找到舊程式碼 | 專案有歷史遺留 | 檢查檔案的最後修改日期，關注最新的 |
| 語言混用 | 多語言專案 | 指定目錄：先 `cd ios/` 再執行命令 |
| 零結果 | 關鍵字不符專案慣例 | 嘗試同義詞：`"controller"` → `"view model"` |

**改善搜尋準確度的技巧**：

1. **從通用到具體**：先用 `"api"` 看有什麼，再精煉為 `"api endpoint"`
2. **查看 Pattern 列表**：參考 [支援的 Patterns](#支援的-patterns-221-個)
3. **結合 overview**：先用 `/sourceatlas:overview` 了解架構後再搜尋

### 快速診斷檢查清單

執行以下命令做完整健康檢查：

```bash
# === SourceAtlas 健康檢查 ===

echo "1. 檢查 plugin 命令..."
ls -la ./SourceAtlas/plugin/commands/sourceatlas:*.md

echo -e "\n2. 檢查 plugin skills..."
ls -la ./SourceAtlas/plugin/skills/

echo -e "\n3. 檢查專案根目錄..."
pwd

echo -e "\n4. 檢查 Git 狀態..."
git status 2>&1 | head -5

echo -e "\n5. 檢查程式碼規模..."
find . -name "*.swift" -o -name "*.ts" -o -name "*.kt" 2>/dev/null | \
  grep -v "node_modules\|Pods\|build" | wc -l

echo -e "\n=== 檢查完成 ==="
```

**預期結果**：
- ✅ 看到 8 個 .md 命令檔案（overview, pattern, impact, history, flow, deps, list, clear）
- ✅ 看到 6 個 skill 目錄（codebase-overview, pattern-finder 等）
- ✅ 在專案根目錄（有 .git/）
- ✅ 程式碼檔案數 < 1000（TINY/SMALL）或 < 5000（MEDIUM/LARGE）

---

## 更多資源

- **技術細節**: [CLAUDE.md](./CLAUDE.md)
- **開發歷史**: [dev-notes/HISTORY.md](./dev-notes/HISTORY.md)
- **功能提案**: [proposals/](./proposals/)
- **回報問題**: [GitHub Issues](https://github.com/lis186/SourceAtlas/issues)

---

**SourceAtlas** - Claude Code 的程式分析助手
v2.11.0 | 更新時間: 2026-01-02
