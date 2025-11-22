# SourceAtlas - 使用指南

**版本**: v1.0 完成，v2.5 開發中
**更新時間**: 2025-11-22

---

## 📖 快速開始

### 5 分鐘入門

**步驟 1: 選擇要分析的專案**
```bash
cd /path/to/target/project
```

**步驟 2: 執行 Stage 0 分析**

將 `PROMPTS.md` 中的 "Stage 0: Project Fingerprint" prompt 複製到 Claude，替換 `[PROJECT_PATH]` 為實際路徑。

**步驟 3: 查看結果**

你會得到一個 `.yaml` 格式的報告，包含：
- 技術棧識別
- 架構模式推論
- 10-15 個假設（供 Stage 1 驗證）
- 開發者能力初步評估

**步驟 4: （可選）執行 Stage 1-2**

如果需要更深入的理解，繼續執行 Stage 1 和 Stage 2。

---

## 🎨 使用 `/atlas-pattern` 學習設計模式

### 什麼是 `/atlas-pattern`？

`/atlas-pattern` 是 SourceAtlas v2.5 的核心命令，幫助開發者**學習當前代碼庫如何實作特定模式**，而非從零開始設計。

**核心價值**: 確保一致性，避免重複造輪子，加速新功能開發。

### 快速開始

```bash
/atlas-pattern "api endpoint"
/atlas-pattern "file upload"
/atlas-pattern "background job"
```

**執行時間**: 5-10 分鐘
**掃描檔案**: <5% (遵循 SourceAtlas 資訊理論原則)

### 支援的模式

#### 核心模式
- **api endpoint** / "api" / "endpoint" - REST/GraphQL API 路由、控制器
- **background job** / "job" / "queue" - 異步任務處理、佇列、背景任務
- **file upload** / "upload" / "file storage" - 檔案上傳、儲存、多媒體處理
- **database query** / "database" / "query" - 資料庫存取、ORM 模式
- **authentication** / "auth" / "login" - 認證流程、會話管理

#### iOS/Swift 模式
- **swiftui view** / "view" - SwiftUI 視圖組合模式
- **view controller** / "viewcontroller" - UIKit 視圖控制器模式
- **networking** / "network" - 網絡層、HTTP 客戶端
- **view model** / "viewmodel" / "mvvm" - MVVM 模式、ObservableObject

#### TypeScript/React 模式
- **react component** / "component" - React 組件模式（.tsx）
- **react hook** / "hook" / "hooks" - 自定義 React Hooks（use*.ts）
- **state management** / "store" / "state" - 狀態管理（Context、Redux、Zustand）
- **form handling** / "form" - 表單處理、驗證模式

#### Next.js 特有模式
- **nextjs middleware** / "middleware" - Next.js 中間件（middleware.ts）
- **nextjs layout** / "layout" - App Router 佈局組件（layout.tsx）
- **nextjs page** / "page" - App Router 頁面組件（page.tsx）
- **nextjs loading** / "loading" - 載入狀態組件（loading.tsx）
- **nextjs error** / "error boundary" / "error" - 錯誤邊界組件（error.tsx）

**注意**: 腳本會自動檢測專案類型（TypeScript vs Swift），並套用對應的模式。

### 輸出格式

每個模式分析包含：

1. **最佳範例檔案** (2-3 個，含 file:line 引用)
2. **標準流程** (逐步執行路徑)
3. **關鍵慣例** (命名、結構、組織)
4. **測試模式** (如何測試此模式)
5. **常見陷阱** (需要避免的錯誤)
6. **實作指南** (具體步驟)

### 使用範例

**場景 1: 添加新的 API 端點**

```bash
# 使用者問題
你: 我需要添加一個新的 API 端點來處理用戶註冊

# 執行命令
你: /atlas-pattern "api endpoint"

# AI 回應範例
AI: # Pattern: REST API Endpoints

## Overview
此代碼庫使用基於控制器的架構，路由定義在 `routes/` 目錄。

## Best Examples

### 1. app/controllers/UsersController.swift:23
**Purpose**: 標準 CRUD 端點模式
**Key Code**:
```swift
func create(req: Request) async throws -> UserResponse {
    let input = try req.content.decode(CreateUserInput.self)
    let user = try await userService.create(input)
    return UserResponse(user)
}
```

### 2. app/routes.swift:15
**Purpose**: 路由註冊模式
...

## Key Conventions
- 所有控制器繼承 `BaseController`
- 使用 Codable 進行請求/回應序列化
- Service 層處理業務邏輯
...

## Step-by-Step Implementation Guide
1. 創建 `RegistrationController.swift` 在 `app/controllers/`
2. 定義 `create` 方法，遵循 `UsersController` 模式
3. 在 `routes.swift` 註冊路由
...
```

**場景 2: 學習檔案上傳模式**

```bash
你: /atlas-pattern "file upload"

AI: # Pattern: File Upload & Storage

## Overview
此專案使用多媒體協調器模式，支援多種來源（本地、Tenor GIF、Stock Photos）。

## Best Examples

### 1. Media/TenorMedia.swift:45
**Purpose**: 外部媒體整合模式
...

### 2. Media/AztecMediaPickingCoordinator.swift:120
**Purpose**: 媒體選擇流程協調
...

## Key Conventions
- 所有媒體處理在 `ViewRelated/Media/` 目錄
- 使用 Coordinator 模式管理選擇流程
- 分離媒體模型、API 和視圖層
...
```

**場景 3: Next.js App Router API 路由**

```bash
你: 我需要在 Next.js 專案中添加一個 API 端點來處理用戶註冊

# 執行命令
你: /atlas-pattern "api endpoint"

AI: # Pattern: Next.js App Router API Routes

## Overview
此專案使用 Next.js 13+ App Router，API 路由定義在 `app/api/` 目錄。
每個端點使用 `route.ts` 檔案，支援動態路由和請求處理。

## Best Examples

### 1. app/api/users/route.ts:10
**Purpose**: REST API 端點標準模式
**Key Code**:
```typescript
import { NextRequest, NextResponse } from 'next/server'
import { createUser } from '@/lib/db/users'

export async function POST(request: NextRequest) {
  const body = await request.json()
  const user = await createUser(body)
  return NextResponse.json(user, { status: 201 })
}
```

### 2. app/api/users/[userId]/route.ts:8
**Purpose**: 動態路由參數處理
**Key Code**:
```typescript
export async function GET(
  request: NextRequest,
  { params }: { params: { userId: string } }
) {
  const user = await getUserById(params.userId)
  if (!user) {
    return NextResponse.json({ error: 'Not found' }, { status: 404 })
  }
  return NextResponse.json(user)
}
```

## Key Conventions
- 所有 API 路由在 `app/api/` 目錄
- 檔案名稱必須是 `route.ts` 或 `route.tsx`
- 使用具名導出：GET, POST, PUT, DELETE, PATCH
- 動態路由使用 `[paramName]` 語法
- 錯誤統一返回 JSON 格式

## Testing Pattern
```typescript
// __tests__/api/users.test.ts
import { POST } from '@/app/api/users/route'

describe('POST /api/users', () => {
  it('should create a new user', async () => {
    const request = new Request('http://localhost/api/users', {
      method: 'POST',
      body: JSON.stringify({ name: 'Test User', email: 'test@example.com' }),
    })
    const response = await POST(request as any)
    expect(response.status).toBe(201)
  })
})
```

## Step-by-Step Implementation Guide
1. 創建 `app/api/auth/register/route.ts`
2. 導出 `POST` 函數處理註冊邏輯
3. 使用 Zod 驗證輸入資料
4. 呼叫 Prisma/資料庫創建用戶
5. 返回 JWT token 或 session
6. 添加錯誤處理和驗證邏輯
```

**場景 4: React Custom Hooks**

```bash
你: /atlas-pattern "react hook"

AI: # Pattern: React Custom Hooks

## Overview
此專案使用自定義 Hooks 封裝可複用邏輯，所有 hooks 遵循 `use*` 命名慣例。

## Best Examples

### 1. lib/hooks/use-auth.ts:15
**Purpose**: 認證狀態管理 Hook
**Key Code**:
```typescript
import { useContext } from 'react'
import { AuthContext } from '@/context/auth'

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider')
  }
  return context
}
```

### 2. components/chat/chat-hooks/use-chat-handler.tsx:45
**Purpose**: 複雜業務邏輯 Hook
**Key Code**:
```typescript
export function useChatHandler() {
  const [messages, setMessages] = useState<Message[]>([])
  const [isLoading, setIsLoading] = useState(false)

  const sendMessage = useCallback(async (content: string) => {
    setIsLoading(true)
    try {
      const response = await api.sendMessage(content)
      setMessages(prev => [...prev, response])
    } finally {
      setIsLoading(false)
    }
  }, [])

  return { messages, isLoading, sendMessage }
}
```

## Key Conventions
- 所有 hooks 使用 `use` 前綴
- 放在 `lib/hooks/` 或功能目錄下的 `hooks/` 子目錄
- 使用 TypeScript 定義返回類型
- 複雜 hooks 使用 `useCallback`、`useMemo` 優化性能
- 必要時拋出錯誤（如未在 Provider 內使用）

## Common Pitfalls
- ❌ 忘記添加依賴陣列導致無限循環
- ❌ 在條件語句中呼叫 hooks
- ❌ 未定義 TypeScript 類型
- ✅ 使用 ESLint react-hooks 規則檢查
```

### 測試結果

#### iOS/Swift 專案

已在 6 個大型 iOS 專案測試：

| 專案 | 規模 | 執行時間 | 準確率 | 結果 |
|------|------|---------|--------|------|
| **WordPress-iOS** | 3,639 檔案 (混合) | 15-20s | 95% | ✅ 18/19 標準符合 |
| **Swiftfin** | 829 檔案 (純 SwiftUI) | 2s | 100% | ✅ 8/9 標準符合 |
| **Telegram-iOS** | 9,231 檔案 (遺留) | 1.8-5.7s | 90%+ | ✅ 8/8 標準符合 |
| **Signal-iOS** | 2,514 檔案 | 1.9-5.9s | 97% | ✅ 安全應用模式 |
| **Calculator** | 3 檔案 (極小) | 0.078s | 100% | ✅ 性能基準 |
| **firefox-ios** | 2,767 檔案 | 2.1-4.8s | 90% | ✅ 瀏覽器架構 |

#### TypeScript/React 專案

已在 4 個 TypeScript 專案測試：

| 專案 | 規模 | 執行時間 | 準確率 | 結果 |
|------|------|---------|--------|------|
| **excalidraw** | 540 檔案 (Monorepo) | 0.20-8.19s | 100% | ✅ 有 CLAUDE.md，AI Level 3 |
| **shadcn-ui** | 2,663 檔案 (Turborepo) | 0.29s | 100% | ✅ UI 組件庫 |
| **zustand** | 32 檔案 (小型庫) | 0.10-0.50s | 100% | ✅ 狀態管理庫 |
| **react-email** | 636 檔案 (Monorepo) | 0.15s | 100% | ✅ Email 組件庫 |

#### Next.js 專案

已在 4 個 Next.js 應用測試：

| 專案 | 規模 | 執行時間 | 準確率 | 結果 |
|------|------|---------|--------|------|
| **taxonomy** | 125 檔案 (App Router) | 0.12-2.0s | 100% | ✅ Blog/SaaS 模板 |
| **chatbot-ui** | 256 檔案 (App Router) | 0.10-0.26s | 100% | ✅ AI 聊天介面 |
| **dub** | 3,136 檔案 (Monorepo) | 0.60-30.1s | 100% | ✅ 企業級 SaaS |
| **next-learn** | 131 檔案 (官方) | - | - | ✅ Vercel 官方教學 |

**總體成功率**:
- iOS/Swift: 95%+ (6/6 專案)
- TypeScript/React: 100% (4/4 專案)
- Next.js: 100% (4/4 專案)

### 何時使用 `/atlas-pattern`

✅ **適合的場景**:
1. **開發新功能** - 確保遵循現有模式
2. **新人入職** - 快速學習代碼庫慣例
3. **代碼審查** - 驗證是否符合團隊標準
4. **重構** - 理解現有實作再改進
5. **技術決策** - 了解專案已有的解決方案

❌ **不適合的場景**:
1. **首次接觸代碼庫** - 先用 `/atlas-overview` 建立全局理解
2. **尋找特定 Bug** - 用傳統 debug 工具
3. **需要完整文檔** - 這只是快速模式學習

### 最佳實踐

1. **先全局後局部** - 先執行 `/atlas-overview`，再用 `/atlas-pattern` 深入
2. **驗證範例** - 實際閱讀推薦的檔案，確認理解
3. **遵循慣例** - 嚴格遵循發現的模式，維持一致性
4. **測試驅動** - 參考測試模式，先寫測試再實作
5. **記錄學習** - 記錄發現的模式，建立團隊知識庫

### 進階用法

#### 組合使用

```bash
# 步驟 1: 全局理解
/atlas-overview

# 步驟 2: 學習相關模式
/atlas-pattern "api endpoint"
/atlas-pattern "authentication"

# 步驟 3: 實作新功能（遵循學到的模式）
```

#### 自定義模式（未來功能）

如果需要的模式不在支援清單中，可以提供關鍵字：

```bash
# 通用搜尋
/atlas-pattern "websocket connection"
/atlas-pattern "payment processing"
```

AI 會嘗試找到最相關的檔案並提取模式。

---

## 🎯 何時使用 SourceAtlas？

### ✅ 適合的場景

1. **接手新專案**
   - 快速理解專案架構
   - 識別技術債務
   - 評估代碼品質

2. **Code Review**
   - 了解開發者能力
   - 識別潛在問題
   - 驗證架構設計

3. **技術盡職調查**
   - 評估收購目標的代碼品質
   - 估算維護成本
   - 識別風險

4. **學習優秀專案**
   - 理解專案結構
   - 學習架構模式
   - 研究開發流程

5. **招聘評估**
   - 評估候選人的 GitHub 專案
   - 驗證能力聲明
   - 了解開發習慣

### ❌ 不適合的場景

1. **極小專案** (<500 行)
   - 直接讀完整專案更快

2. **需要深度理解業務邏輯**
   - SourceAtlas 專注於架構和模式
   - 不深入具體業務細節

3. **需要找特定 Bug**
   - 用傳統 debug 工具更合適

---

## 📊 Stage 選擇指南

### 決策樹

```
專案代碼量？
├─ <500 行
│  └─ 不需要 SourceAtlas，直接讀完整專案
│
├─ 500-2000 行
│  └─ 使用 Stage 0-1
│     ├─ Stage 0: 建立輪廓
│     └─ Stage 1: 驗證假設
│
└─ >2000 行
   └─ 使用 Stage 0-2 (完整流程)
      ├─ Stage 0: 建立輪廓
      ├─ Stage 1: 驗證假設
      └─ Stage 2: Git 分析
```

### Stage 對比

| 需求 | Stage 0 | Stage 1 | Stage 2 |
|------|---------|---------|---------|
| 快速了解技術棧 | ✅ | - | - |
| 驗證架構假設 | - | ✅ | - |
| 了解開發模式 | - | - | ✅ |
| 評估開發者能力 | ⭐ | ⭐⭐ | ⭐⭐⭐ |
| 識別 AI 協作 | ⭐ | ⭐⭐ | ⭐⭐⭐ |
| 時間投入 | 10-15 分鐘 | 20-30 分鐘 | 15-20 分鐘 |
| Token 使用 | ~20k | ~30k | ~20k |

---

## 🔍 詳細使用流程

### Stage 0: Project Fingerprint

**目標**: 掃描 <5% 檔案達到 70-80% 理解

**準備工作**:
1. 確保專案目錄可訪問
2. 確認有 Git 歷史（optional，但有助於分析）
3. 準備好執行 shell 命令的權限

**執行步驟**:

1. **使用 Prompt**
   ```
   複製 PROMPTS.md 中的 "Stage 0: Project Fingerprint" prompt
   替換 [PROJECT_PATH] 為實際路徑
   提交給 Claude
   ```

2. **Claude 會自動**:
   - 掃描配置檔案 (package.json, composer.json)
   - 讀取 README.md
   - 掃描專案結構
   - 讀取 3-5 個核心 Model 檔案
   - 生成假設

3. **你會得到**:
   - 一個 `.yaml` 格式的報告
   - 10-15 個待驗證的假設（規模感知調整）
   - 技術棧和架構的推論
   - 開發者能力初步評估

**檢查清單**:
- [ ] 技術棧識別正確？
- [ ] 有明確的假設清單？
- [ ] 開發者能力評估合理？
- [ ] 掃描檔案數 <5%？

**常見問題**:

Q: Stage 0 輸出太長怎麼辦？
A: 這是正常的，YAML 格式設計為完整記錄。可以重點看 `project_fingerprint` 和 `hypotheses` 部分。

Q: 假設太多/太少？
A: 理想是 10-15 個。太多說明不夠聚焦，太少可能遺漏重點。

Q: 信心等級如何解讀？
A: 0.0-0.5 (低), 0.5-0.7 (中), 0.7-0.85 (高), 0.85-1.0 (極高)

---

### Stage 1: Hypothesis Validation

**目標**: 驗證 Stage 0 的假設，達到 85-95% 理解

**準備工作**:
1. 完成 Stage 0 分析
2. 閱讀 Stage 0 報告，理解假設清單
3. 準備好執行驗證命令

**執行步驟**:

1. **提供 Stage 0 報告**
   ```
   先讓 Claude 讀取 Stage 0 報告
   然後使用 Stage 1 prompt
   ```

2. **Claude 會自動**:
   - 提取所有假設
   - 為每個假設設計驗證方法
   - 執行驗證（grep, ls, find 等）
   - 記錄證據
   - 更新信心等級

3. **你會得到**:
   - 驗證報告 (.md 格式)
   - 每個假設的確認/推翻結果
   - 驗證準確率統計
   - 更新後的專案理解

**檢查清單**:
- [ ] 所有假設都被驗證？
- [ ] 每個結論有明確證據？
- [ ] 準確率 >80%？
- [ ] 識別出 Stage 0 的錯誤？

**常見問題**:

Q: 準確率低於 80% 怎麼辦？
A: 這是正常的！Stage 0 是推論，有些推論會被推翻。重要的是學習為什麼推翻。

Q: 如何改進 Stage 0？
A: Stage 1 報告會提供改進建議。基於這些建議優化 Stage 0 prompt。

Q: 無法驗證某些假設？
A: 標記為"需要更多資訊"，說明為什麼無法驗證。

---

### Stage 2: Git Hotspots Analysis

**目標**: 識別開發模式和演進，理解深度達到 95%+

**準備工作**:
1. 確認專案有 Git 歷史
2. 完成 Stage 0-1 (optional，但有助於理解)
3. 確保可以執行 Git 命令

**執行步驟**:

1. **使用 Prompt**
   ```
   複製 Stage 2 prompt
   替換 [PROJECT_PATH]
   提交給 Claude
   ```

2. **Claude 會自動**:
   - 分析 commit 歷史
   - 識別檔案熱點
   - 重建時間線
   - 分析開發模式
   - 評估 AI 協作證據

3. **你會得到**:
   - Git 熱點報告 (.md 格式)
   - 完整的時間線重建
   - 開發模式分析
   - 開發者能力評估

**檢查清單**:
- [ ] 時間線完整？
- [ ] 識別所有關鍵階段？
- [ [ 找出檔案熱點？
- [ ] AI 協作證據充分？

**常見問題**:

Q: 專案沒有 Git 歷史怎麼辦？
A: 跳過 Stage 2，或者只做部分分析（如果有部分歷史）。

Q: Git 歷史太長（1000+ commits）？
A: Stage 2 仍然有效。Git 命令會自動聚合和統計。

Q: 如何識別 AI 協作？
A: 看 commit message 一致性、註解密度、CLAUDE.md 等檔案。

---

## 📋 輸出格式說明

### YAML 格式 (.yaml)

**用於**: Stage 0 報告

**特點**:
- 標準格式，廣泛生態系統支援
- 極佳的人類可讀性
- 完整的 IDE 和工具支援
- 包含完整的 metadata

**v1.0 決策**: 選擇 YAML 而非自訂 TOON 格式（詳見 `.dev-notes/toon-vs-yaml-analysis.md`）

**範例**:
```yaml
metadata:
  project_name: example
  developer: john_doe
  scan_time: "2025-11-22T10:00:00Z"

project_fingerprint:
  project_type: WEB_APP
  architecture: MVC
  scale: MEDIUM
```

### Markdown 格式 (.md)

**用於**: Stage 1-2 報告

**特點**:
- 易讀
- 支援表格、列表
- 可以直接在 GitHub 上查看

---

## 🎯 進階技巧

### 技巧 1: 並行分析多專案

```bash
# 創建批次分析腳本
for project in project1 project2 project3; do
  echo "Analyzing $project..."
  # 對每個專案執行 Stage 0-2
done
```

### 技巧 2: 自定義假設

在 Stage 0 後，你可以手動添加假設到清單中，然後在 Stage 1 驗證。

### 技巧 3: 聚焦特定領域

修改 Prompt，聚焦於特定領域：
- 只分析測試相關
- 只分析安全性
- 只分析性能

### 技巧 4: 對比分析

使用三方對比報告模板，對比多個專案或開發者。

### 技巧 5: 持續追蹤

定期（如每月）執行分析，追蹤專案演進和開發者成長。

---

## ⚠️ 常見陷阱

### 陷阱 1: 過度依賴 Stage 0

**問題**: Stage 0 是推論，不是事實。

**解決**:
- 總是執行 Stage 1 驗證關鍵假設
- 對低信心的推論保持懷疑

### 陷阱 2: 忽略上下文

**問題**: 代碼品質評估需要考慮專案類型。

**解決**:
- 學習專案 vs 生產專案有不同標準
- 個人專案 vs 團隊專案有不同標準

### 陷阱 3: 只看數字

**問題**: 測試覆蓋率 90% 不代表高品質。

**解決**:
- 結合多個維度評估
- 看質量，不只是數量

### 陷阱 4: 忘記更新理解

**問題**: Stage 1 推翻了假設，但沒更新理解。

**解決**:
- 基於驗證結果更新專案理解
- 記錄為什麼某些假設被推翻

---

## 📊 結果解讀指南

### 開發者能力評估

**評分標準**:

| 等級 | 總分 | 特徵 | 代表 |
|------|------|------|------|
| **初學者** | 0-3 | 缺乏基礎知識，代碼混亂 | chiahsing1115 |
| **中級** | 4-6 | 掌握基礎，有架構意識 | - |
| **高級** | 7-8 | 專業品質，高測試覆蓋率 | taiwan-calendar |
| **專家/AI** | 9-10 | 極高產能或 AI 協作 | Mir01 |

**關鍵指標**:
- 代碼規模（lines of code）
- 測試覆蓋率（test coverage）
- Git 習慣（commit quality）
- 架構清晰度（architecture clarity）
- 文檔完整度（documentation）

### AI 協作識別

**Level 0: 無 AI**
- 無 AI 配置檔案
- 註解密度 <5%
- Commit message 不規範

**Level 1-2: 基礎使用**
- 偶爾使用 AI 工具
- 無系統化流程

**Level 3: 系統化 ⭐**
- 有 CLAUDE.md 或類似規範
- 註解密度 15-20%
- 100% Conventional Commits
- 代碼一致性 98%+

**Level 4: 生態化**
- 團隊級別 AI 協作
- 跨專案知識沉澱
- （尚未見到實例）

### 技術債務評估

**極低**: 有系統化追蹤，及時修復
- 例: taiwan-calendar

**低**: 有識別，計劃修復
- 例: Mir01

**中**: 有識別，未計劃
- 大多數專案

**高**: 沒有識別，累積嚴重
- 例: chiahsing1115

---

## 🎓 學習案例

### 案例 1: 評估初學者專案

**背景**: chiahsing1115 的 5 個專案

**分析結果**:
- Stage 0: 快速識別缺乏數據持久化
- Stage 1: 驗證所有 5 個專案都無持久化
- Stage 2: Git 習慣極差（1-2 commits）

**洞察**:
- 正在學習基礎
- 需要導師指導
- 建議優先學習數據持久化

### 案例 2: 評估專業專案

**背景**: taiwan-calendar-mcp-server (15k 行)

**分析結果**:
- Stage 0: 識別出專業級架構
- Stage 1: 100% 假設驗證成功
- Stage 2: 發現 92.27% 測試覆蓋率

**洞察**:
- 專業工程師水準
- TDD 開發模式
- 代碼品質極高

### 案例 3: 識別 AI 協作

**背景**: Mir01 (156k 行，2 個月開發)

**分析結果**:
- Stage 0: 發現 CLAUDE.md 配置
- Stage 1: 驗證出規範與實際差異
- Stage 2: 識別 Level 3 系統化 AI 協作

**洞察**:
- AI 輔助開發的成熟案例
- 規範是"理想"而非"現狀"
- 文檔/代碼比 3:1

---

## 🔧 troubleshooting

### 問題 1: Claude 超過 Token 限制

**症狀**: Claude 回應被截斷

**解決**:
1. 減少掃描檔案數量
2. 分階段執行（先 Stage 0，再 Stage 1）
3. 聚焦特定領域

### 問題 2: Git 命令失敗

**症狀**: `fatal: not a git repository`

**解決**:
1. 確認在正確目錄
2. 檢查是否有 .git 目錄
3. 如果沒有 Git 歷史，跳過 Stage 2

### 問題 3: 無法讀取某些檔案

**症狀**: Permission denied

**解決**:
1. 檢查檔案權限
2. 使用 sudo（如果適當）
3. 跳過受保護的檔案

### 問題 4: Stage 0 推論不準確

**症狀**: Stage 1 驗證率 <60%

**解決**:
1. 檢查是否掃描了正確的檔案
2. 是否遺漏了關鍵配置檔案
3. 調整 Stage 0 prompt，增加特定領域檢查

---

## 📚 延伸閱讀

- `PROMPTS.md` - 完整 Prompt 模板
- `EVALUATION_STANDARDS.md` - 評估標準體系
- `THREE-WAY-DEVELOPER-COMPARISON.md` - 對比案例研究
- `test_results/` - 實際分析案例

---

## 💬 獲得幫助

**常見問題**: 查看本文檔的 troubleshooting 部分

**GitHub Issues**: [報告問題或建議](https://github.com/your-repo/issues)

**社群討論**: [加入討論](https://github.com/your-repo/discussions)

---

**文檔版本**: v1.0 完成，v2.5 開發中
**最後更新**: 2025-11-22
**維護者**: SourceAtlas Team
