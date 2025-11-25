# SourceAtlas - 使用指南

**3 個斜線命令的完整使用說明**

適用於 Claude Code | v2.5

---

## 目錄

1. [安裝](#安裝)
2. [命令 1: /atlas-overview](#命令-1-atlas-overview)
3. [命令 2: /atlas-pattern](#命令-2-atlas-pattern)
4. [命令 3: /atlas-impact](#命令-3-atlas-impact)
5. [常見問題](#常見問題)

---

## 安裝

### 全局安裝（推薦）

```bash
# 1. 克隆專案
git clone https://github.com/your-org/sourceatlas2.git ~/dev/sourceatlas2

# 2. 執行安裝
cd ~/dev/sourceatlas2
./install-global.sh

# 3. 驗證安裝
cd ~/projects/any-project
/atlas-overview --help
```

安裝一次，所有專案都能用。

詳細說明：[GLOBAL_INSTALLATION.md](./GLOBAL_INSTALLATION.md)

---

## 命令 1: /atlas-overview

**快速理解專案全貌**

### 使用方式

```bash
/atlas-overview
```

### 你會得到什麼

- **技術棧**：語言、框架、資料庫
- **架構模式**：MVC、MVVM、Clean Architecture...
- **專案規模**：檔案數、代碼行數
- **代碼品質**：測試覆蓋率、註解密度
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

### 範例輸出

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

---

## 命令 2: /atlas-pattern

**學習專案的設計模式**

### 使用方式

```bash
/atlas-pattern "api endpoint"
/atlas-pattern "file upload"
/atlas-pattern "authentication"
```

### 你會得到什麼

1. **最佳範例檔案** (2-3 個) + file:line 引用
2. **關鍵慣例**：命名、結構、組織方式
3. **測試模式**：如何測試這個功能
4. **實作指南**：逐步實作新功能

### 支援的 Patterns (71 個)

#### iOS/Swift (29 個)

**核心架構**:
- `mvvm` - MVVM 架構模式
- `coordinator` - Coordinator 導航模式
- `dependency injection` - DI Container/Factory
- `repository` - Repository 資料存取模式

**UI 組件**:
- `swiftui view` - SwiftUI 視圖組合
- `view controller` - UIKit ViewController
- `table view cell` - TableView/CollectionView Cell
- `view modifier` - SwiftUI ViewModifier

**資料處理**:
- `networking` - 網絡層、API Client
- `core data` - Core Data 持久化
- `api endpoint` - REST/GraphQL API

**功能模組**:
- `authentication` - 認證流程
- `file upload` - 檔案上傳
- `background job` - 異步任務
- `error handling` - 錯誤處理

#### TypeScript/React (22 個)

**React 基礎**:
- `react component` - React 組件
- `react hook` - 自定義 Hooks
- `state management` - 狀態管理
- `form handling` - 表單處理

**Next.js 專屬**:
- `nextjs middleware` - 中間件
- `nextjs layout` - App Router 佈局
- `nextjs page` - 頁面組件
- `nextjs loading` - 載入狀態
- `nextjs error` - 錯誤邊界

**後端整合**:
- `api endpoint` - API 路由
- `database query` - Prisma/ORM
- `authentication` - Auth.js/NextAuth

#### Android/Kotlin (20 個)

- `view controller` - Activity/Fragment
- `view model` - ViewModel (AAC)
- `repository` - Repository Pattern
- `use case` - UseCase/Interactor
- `dependency injection` - Hilt/Koin
- ...and more

### 執行時間

**0.1 - 30 秒**（取決於專案大小）

### 使用範例

#### 範例 1: 學習 API 設計

```bash
/atlas-pattern "api endpoint"
```

**輸出**:
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

#### 範例 2: 學習 SwiftUI 組件

```bash
/atlas-pattern "swiftui view"
```

**輸出**:
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

---

## 命令 3: /atlas-impact

**分析代碼變更影響**

### 使用方式

```bash
# 分析檔案
/atlas-impact "src/api/users.ts"

# 分析 API
/atlas-impact api "/api/users/{id}"

# 分析 Model
/atlas-impact "User model"
```

### 你會得到什麼

1. **依賴追蹤**：誰在使用這個 API/Model/Component
2. **Breaking Changes**：哪些變更會破壞現有代碼
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

**場景**: 要重構 `/api/users/{id}` 端點

```bash
/atlas-impact api "/api/users/{id}"
```

**輸出**:
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

#### 範例 2: iOS Model 修改

**場景**: 要修改 Swift Model，擔心影響 Objective-C 代碼

```bash
/atlas-impact "User.swift"
```

**輸出**:
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

---

## 常見問題

### Q: 命令執行失敗怎麼辦？

**A**: 檢查以下幾點：

1. **確認安裝**:
   ```bash
   ls ~/.claude/commands/atlas-*.md
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

### Q: 可以分析私有代碼庫嗎？

**A**: 可以！所有分析都在本地執行，代碼不會上傳。

### Q: 效能如何？會不會很慢？

**A**:
- `/atlas-overview`: 10-15 分鐘
- `/atlas-pattern`: 0.1-30 秒
- `/atlas-impact`: 1-2 分鐘

使用資訊理論原則，只掃描 <5% 檔案。

### Q: 支援 Monorepo 嗎？

**A**: 支援！建議在每個子專案目錄執行命令。

範例：
```bash
cd packages/web
/atlas-overview

cd ../api
/atlas-overview
```

---

## 進階使用

### 組合使用命令

**場景**: 接手新專案並要新增功能

```bash
# Step 1: 理解專案 (10 分鐘)
/atlas-overview

# Step 2: 學習現有實作 (0.1 秒)
/atlas-pattern "api endpoint"
/atlas-pattern "authentication"

# Step 3: 分析影響 (1 分鐘)
/atlas-impact "src/api/auth.ts"
```

**總時間**: 15 分鐘內完整掌握專案

---

## 疑難排解

### 問題 1: 找不到 patterns

**症狀**: `/atlas-pattern` 回報「No patterns found」

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

**症狀**: `/atlas-overview` 超過 20 分鐘還沒完成

**可能原因**:
- 專案過大 (>100K LOC)
- 網絡慢（Claude API）
- 專案包含大量二進制檔案

**解決方式**:
1. 確認 `.gitignore` 正確排除 `node_modules/`、`Pods/` 等
2. 在較小的子目錄執行
3. 等待完成（只需執行一次）

---

## 更多資源

- **技術細節**: [CLAUDE.md](./CLAUDE.md)
- **開發歷史**: [dev-notes/HISTORY.md](./dev-notes/HISTORY.md)
- **功能提案**: [proposals/](./proposals/)
- **回報問題**: [GitHub Issues](https://github.com/your-repo/issues)

---

**SourceAtlas** - Claude Code 的程式分析助手
v2.5 | 更新時間: 2025-11-25
