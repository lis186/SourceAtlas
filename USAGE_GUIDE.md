# SourceAtlas - 使用指南

**6 個斜線命令的完整使用說明**

適用於 Claude Code | v2.7.0

---

## 目錄

1. [安裝](#安裝)
2. [命令 1: /atlas.overview](#命令-1-atlasoverview)
3. [命令 2: /atlas.pattern](#命令-2-atlaspattern)
4. [命令 3: /atlas.impact](#命令-3-atlasimpact)
5. [命令 4: /atlas.history](#命令-4-atlashistory)
6. [命令 5: /atlas.flow](#命令-5-atlasflow)
7. [命令 6: /atlas.init](#命令-6-atlasinit)
8. [常見問題](#常見問題)

---

## 安裝

**完整安裝指南**：[GLOBAL_INSTALLATION.md](./GLOBAL_INSTALLATION.md)

### 快速開始

```bash
git clone https://github.com/lis186/SourceAtlas.git ~/dev/sourceatlas2
cd ~/dev/sourceatlas2 && ./install-global.sh
```

安裝一次，所有專案都能用。

---

## 命令 1: /atlas.overview

**快速理解專案全貌**

### 使用方式

```bash
/atlas.overview
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
/atlas.overview
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

**下一步**：用 `/atlas.pattern "api endpoint"` 學習 API 實作方式

---

## 命令 2: /atlas.pattern

**學習專案的設計模式**

### 使用方式

```bash
/atlas.pattern "api endpoint"
/atlas.pattern "file upload"
/atlas.pattern "authentication"
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

### 支援的 Patterns (141 個)

#### 快速總覽

| 語言 | Pattern 數量 | 主要類別 |
|------|-------------|----------|
| **iOS/Swift** | 34 | 架構、UI、資料處理、功能模組 |
| **TypeScript/React/Vue** | 50 | React 核心、Vue 核心、後端整合 |
| **Android/Kotlin** | 31 | Architecture Components、UI、資料層 |
| **Python** | 26 | Django、FastAPI、Flask、Celery |

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

**試用範例**：`/atlas.pattern "api endpoint"`

### 執行時間

**0.1 - 30 秒**（取決於專案大小）

### 使用範例

#### 範例 1: 學習 API 設計

**情境**：要新增一個 API endpoint，不確定專案的寫法

**命令**：
```bash
/atlas.pattern "api endpoint"
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
/atlas.pattern "swiftui view"
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

## 命令 3: /atlas.impact

**分析程式碼變更影響**

### 使用方式

```bash
# 分析檔案
/atlas.impact "src/api/users.ts"

# 分析 API
/atlas.impact api "/api/users/{id}"

# 分析 Model
/atlas.impact "User model"
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
/atlas.impact api "/api/users/{id}"
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
/atlas.impact "User.swift"
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

## 常見問題

### Q: 命令執行失敗怎麼辦？

**A**: 檢查以下幾點：

1. **確認安裝**:
   ```bash
   ls ~/.claude/commands/atlas.*.md
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
- 🔵 Python (開發中)
- 🔵 Ruby (開發中)
- 🔵 Go (開發中)

### Q: 分析結果保存在哪裡？

**A**:
- 輸出直接顯示在 Claude Code 對話中
- 不會自動保存檔案
- 可以手動複製結果儲存

### Q: 可以分析私有 codebase 嗎？

**A**: 可以！所有分析都在本地執行，程式碼不會上傳。

### Q: 效能如何？會不會很慢？

**A**:
- `/atlas.overview`: 10-15 分鐘
- `/atlas.pattern`: 0.1-30 秒
- `/atlas.impact`: 1-2 分鐘

使用資訊理論原則，只掃描 <5% 檔案。

### Q: 支援 Monorepo 嗎？

**A**: 支援！建議在每個子專案目錄執行命令。

範例：
```bash
cd packages/web
/atlas.overview

cd ../api
/atlas.overview
```

---

## 進階使用

### 組合使用命令

**場景**: 接手新專案並要新增功能

```bash
# Step 1: 理解專案 (10 分鐘)
/atlas.overview

# Step 2: 學習現有實作 (0.1 秒)
/atlas.pattern "api endpoint"
/atlas.pattern "authentication"

# Step 3: 分析影響 (1 分鐘)
/atlas.impact "src/api/auth.ts"
```

**總時間**: 15 分鐘內完整掌握專案

---

## 疑難排解

### 問題 1: 找不到 patterns

**症狀**: `/atlas.pattern` 回報「No patterns found」

**解決方式**:
1. 確認專案類型是否支援（iOS/TypeScript/Android）
2. 檢查檔案結構是否符合慣例
3. 嘗試更通用的 pattern 名稱（如用 "api" 而非 "api endpoint"）

### 問題 2: Swift Analyzer 沒有執行

**症狀**: iOS 專案沒有顯示 Swift/ObjC interop 分析

**解決方式**:
1. 確認專案有 `.xcodeproj` 或 `.xcworkspace`
2. 確認目標檔案是 `.swift`、`.m` 或 `.h`
3. 檢查 `scripts/atlas/analyzers/swift-analyzer.sh` 是否存在

### 問題 3: 執行時間過長

**症狀**: `/atlas.overview` 超過 20 分鐘還沒完成

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
| 專案過大 (>100K LOC) | 在子目錄執行：`cd src && /atlas.overview` | 依子目錄數量分散時間 |
| 網路延遲 | 檢查 [Claude API 狀態](https://status.anthropic.com) | 等待或稍後重試 |

**仍然緩慢？** 請[回報問題](https://github.com/lis186/SourceAtlas/issues)並附上診斷結果

### 問題 4: 命令找不到

**症狀**: 執行 `/atlas.overview` 時顯示「Command not found」

**診斷步驟**:

```bash
# 1. 檢查命令檔案是否存在
ls -la ~/.claude/commands/atlas.*.md

# 2. 檢查檔案權限
ls -l ~/.claude/commands/atlas.*.md

# 3. 檢查 Claude Code 版本
# 在 Claude Code 中執行：/help
```

**解決方式**：

| 檢查結果 | 原因 | 修復方法 |
|---------|------|---------|
| 檔案不存在 | 未安裝或安裝失敗 | 重新執行 `./install-global.sh` |
| 權限錯誤（---x------） | Symlink 指向不存在的位置 | `./install-global.sh --remove` 後重裝 |
| Claude Code 版本過舊 | 不支援 Slash Commands | 更新 Claude Code 到最新版本 |

### 問題 5: 輸出格式不正確

**症狀**: `/atlas.overview` 輸出純文字而非 YAML 格式

**診斷步驟**:

```bash
# 檢查 prompt 文件內容
head -20 ~/.claude/commands/atlas.overview.md
```

**可能原因**：

| 症狀 | 原因 | 修復方法 |
|------|------|---------|
| 缺少 frontmatter (---) | 檔案損壞 | `git restore .claude/commands/` 後重裝 |
| 內容是舊版本 | 未更新到最新版 | `cd ~/dev/sourceatlas2 && git pull && ./install-global.sh` |
| YAML 語法錯誤 | AI 解析問題 | 重新執行命令（Claude 隨機性） |

### 問題 6: Pattern 搜尋結果不準確

**症狀**: `/atlas.pattern "api"` 回傳不相關的檔案

**常見原因與解決**：

| 情況 | 原因 | 改善方法 |
|------|------|---------|
| 找到測試檔案而非實作 | Pattern 太通用 | 使用更具體的關鍵字：`/atlas.pattern "api endpoint"` |
| 找到舊程式碼 | 專案有歷史遺留 | 檢查檔案的最後修改日期，關注最新的 |
| 語言混用 | 多語言專案 | 指定目錄：先 `cd ios/` 再執行命令 |
| 零結果 | 關鍵字不符專案慣例 | 嘗試同義詞：`"controller"` → `"view model"` |

**改善搜尋準確度的技巧**：

1. **從通用到具體**：先用 `"api"` 看有什麼，再精煉為 `"api endpoint"`
2. **查看 Pattern 列表**：參考 [支援的 Patterns](#支援的-patterns-141-個)
3. **結合 overview**：先用 `/atlas.overview` 了解架構後再搜尋

### 快速診斷檢查清單

執行以下命令做完整健康檢查：

```bash
# === SourceAtlas 健康檢查 ===

echo "1. 檢查安裝..."
ls -la ~/.claude/commands/atlas.*.md

echo -e "\n2. 檢查腳本..."
ls -la ~/.claude/scripts/atlas/

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
- ✅ 看到 6 個 .md 檔案（init, overview, pattern, impact, history, flow）
- ✅ 看到 scripts/atlas/ 目錄
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
v2.7.0 | 更新時間: 2025-12-03
