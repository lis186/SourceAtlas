# API 影響分析場景補充 - 2025-11-20

## 📌 新場景：API 改動的影響範圍分析

### Justin 的補充

> "影響分析還有一種情況是要盤點某些 API 改動可能影響哪些頁面或功能"

這是一個非常實際且常見的開發場景！

---

## 🎯 場景詳細描述

### 情境：後端 API 端點變更

**常見的 API 變更類型**：
1. **Response 格式改變**
   - 欄位名稱變更：`user_name` → `userName`
   - 資料結構變更：`address` 從字串改為物件
   - 新增巢狀層級：`data.user` → `data.result.user`

2. **必填欄位新增**
   - Request body 新增必填參數
   - 缺少參數會導致 400 錯誤

3. **欄位移除或棄用**
   - 移除某個 response 欄位
   - 標記為 deprecated

4. **狀態碼邏輯變更**
   - 原本 200，現在 201
   - 錯誤處理邏輯改變

---

## 💡 具體案例

### 案例 1：User API Response 格式變更

**變更內容**：
```javascript
// 舊版 API Response
GET /api/users/{id}
{
  "id": 1,
  "name": "Alice",
  "email": "alice@example.com",
  "role": "admin"
}

// 新版 API Response
GET /api/users/{id}
{
  "id": 1,
  "name": "Alice",
  "email": "alice@example.com",
  "roles": ["admin", "editor"],  // ⚠️ role → roles (字串改陣列)
  "profile": {                    // ⚠️ 新增巢狀結構
    "avatar": "...",
    "bio": "..."
  }
}
```

**需要回答的問題**：
1. 哪些頁面/元件使用了這個 API？
2. 哪些程式碼依賴 `role` 欄位（現在改名為 `roles`）？
3. 是否有程式碼假設 `role` 是字串？
4. 影響程度：破壞性變更 vs 新增欄位？

---

### 案例 2：Orders API 新增必填參數

**變更內容**：
```javascript
// 舊版
POST /api/orders
{
  "items": [...],
  "total": 1000
}

// 新版
POST /api/orders
{
  "items": [...],
  "total": 1000,
  "currency": "TWD"  // ⚠️ 新增必填欄位
}
```

**需要回答的問題**：
1. 哪些頁面會建立訂單？
2. 這些頁面的表單是否需要新增 currency 選項？
3. 是否有預設值可以使用？
4. 測試是否需要更新？

---

## 🔍 使用 SourceAtlas 的理想流程

### 使用方式 A：即時探索（v2.5 可做）

```
Developer: /atlas find "API /api/users"

AI 回應：
找到 3 處 API 調用：

1. Hook: src/hooks/useUser.ts:15
   - 使用 apiClient.GET('/api/users/{id}')
   - 被 5 個元件使用

2. Hook: src/hooks/useUsers.ts:23
   - 使用 apiClient.GET('/api/users')
   - 列表頁面使用

3. Service: src/services/userService.ts:45
   - 直接 fetch 調用
   - 被 Admin 頁面使用

影響的頁面：
  - /profile (使用 useUser)
  - /users/{id} (使用 useUser)
  - /admin/users (使用 useUsers)
  - /settings/account (使用 useUser)
  - /dashboard (使用 useUser)

依賴 'role' 欄位的程式碼：
  ⚠️ src/components/UserBadge.tsx:34
     if (user.role === 'admin') { ... }

  ⚠️ src/utils/permissions.ts:12
     function canEdit(user) {
       return user.role === 'admin' || user.role === 'editor';
     }

建議：
1. 更新這 2 處程式碼改用 user.roles.includes('admin')
2. 新增 type guard 確保向後相容
3. 檢查測試是否覆蓋這些情況
```

---

### 使用方式 B：深入分析（v2.5 進階或 v2.6）

```
Developer: /atlas impact api "/api/users/{id}"

AI 回應：
=== API Impact Analysis ===

API: GET /api/users/{id}

📍 調用鏈路：
  1. API 層
     - src/types/api.ts (類型定義)
     - src/lib/apiClient.ts (調用封裝)

  2. Hook 層
     - src/hooks/useUser.ts (主要 Hook)
       → 使用 apiClient.GET()
       → 使用 select 解包數據

  3. 元件層
     - src/app/profile/page.tsx
     - src/app/users/[id]/page.tsx
     - src/components/UserCard.tsx
     - src/components/UserBadge.tsx
     - src/app/dashboard/page.tsx

📊 欄位使用分析：

'role' 欄位（⚠️ 將被改為 'roles'）：
  - 使用次數：8 處
  - 關鍵位置：
    1. UserBadge.tsx:34 - 渲染角色徽章
    2. permissions.ts:12 - 權限檢查
    3. UserForm.tsx:67 - 表單顯示
    4. useUser.ts:23 - 數據轉換

  - 假設類型為字串：✅ 是（全部）
  - 影響評估：🔴 破壞性變更（需要修改）

'email' 欄位：
  - 使用次數：12 處
  - 影響評估：✅ 無變更

新增 'profile' 欄位：
  - 影響評估：🟢 無破壞性（可選擇性使用）

🧪 測試影響：
  - 需要更新：5 個測試檔案
    1. useUser.test.ts - Mock 數據需更新
    2. UserBadge.test.tsx - role → roles
    3. permissions.test.ts - 測試邏輯需更新
    4. UserForm.test.tsx - 表單測試
    5. e2e/user-profile.spec.ts - E2E 測試

📋 遷移檢查清單：
  [ ] 更新 API 類型定義（api.ts）
  [ ] 更新 8 處 role → roles 使用
  [ ] 新增向後相容處理（如果需要）
  [ ] 更新 5 個測試檔案
  [ ] 測試所有影響的頁面
  [ ] 更新文檔

預估工作量：2-3 小時
風險等級：🔴 高（破壞性變更）
```

---

## 🏗️ 技術實作方式

### v2.5 實作（即時探索）

使用 `/atlas find` 搭配智慧搜尋：

```bash
# Script 負責：收集原始資料
grep -r "'/api/users'" src/
grep -r "user\.role" src/
find src -name "*user*.ts" -o -name "*user*.tsx"

# AI 負責：
# 1. 理解 API 調用模式
# 2. 追蹤調用鏈（API → Hook → Component）
# 3. 分析欄位使用
# 4. 評估影響程度
# 5. 生成遷移建議
```

### v2.6 實作（深入分析）

可能需要：
1. **靜態分析**
   - 解析 import/export 關係
   - 建立依賴圖
   - 追蹤數據流

2. **類型分析**
   - 分析 TypeScript 類型使用
   - 檢測類型不匹配
   - 提供自動修復建議

3. **測試覆蓋追蹤**
   - 識別相關測試
   - 檢查測試是否需要更新

---

## 🎯 與其他影響分析的差異

| 場景 | 分析重點 | 資料來源 | 複雜度 |
|------|---------|---------|--------|
| **Model 驗證變更** | 資料流、關聯模型 | 程式碼結構 | 中 |
| **API 端點變更** | 前後端連結、欄位使用 | API 調用、類型定義 | 高 |
| **共用元件變更** | 元件樹、props 傳遞 | React 元件結構 | 中 |

---

## 💡 關鍵洞察

### 1. API 影響分析的獨特性

**不同於 Model 變更**：
- Model 變更：後端內部影響（Service → Model → DB）
- API 變更：**跨層級影響**（後端 → API 契約 → 前端）

**需要額外分析**：
- API 契約（OpenAPI spec, types）
- 前端調用模式（fetch, axios, apiClient）
- 數據轉換層（Hook select, mapper）
- UI 顯示邏輯（Component 使用）

### 2. 前後端分離架構的痛點

在前後端分離的專案中：
```
後端 API 變更 → 中間契約層 → 前端多處使用

問題：
1. 契約更新可能被忽略
2. 前端不知道有變更
3. 運行時才發現錯誤
4. 影響範圍難以評估
```

**SourceAtlas 的價值**：
- 提前發現影響範圍
- 給出明確的修改清單
- 評估遷移成本
- 防止遺漏

### 3. 實際開發流程

**目前（沒有工具）**：
```
1. 後端改 API
2. 更新 OpenAPI spec
3. 前端重新生成類型
4. TypeScript 報錯
5. 逐一修復錯誤（可能遺漏 runtime 問題）
6. 測試發現更多問題
7. 來回修改
```

**理想（有 SourceAtlas）**：
```
1. 後端改 API
2. /atlas impact api "/api/users/{id}"
3. 獲得完整影響清單
4. 按清單逐一修改
5. 一次性完成遷移
6. 減少來回修改
```

---

## 🚀 實作優先級建議

### v2.5 應該實作

**基礎 API 影響分析**：
```
/atlas find "api /api/users"

功能：
✅ 找到所有 API 調用位置
✅ 追蹤到使用的 Hook/Component
✅ 分析欄位使用（基於字串搜尋）
✅ 提供遷移建議
```

**技術方案**：
- 使用 grep 找 API 字串
- 使用 grep 找欄位使用
- AI 整合結果並分析影響
- 不需要複雜的靜態分析

### v2.6 可以增強

**進階分析**：
- 解析 TypeScript 類型
- 建立依賴圖
- 自動生成遷移腳本
- 測試覆蓋檢查

---

## 📝 需要更新的文檔

### 1. PRD.md
- 更新「場景 3：影響範圍分析」
- 新增「API 改動影響分析」子場景
- 提供具體案例

### 2. 場景優先級調整

| 場景 | v2.5 | v2.6 |
|------|------|------|
| Bug 修復 | ✅ 完整 | - |
| 學習模式 | ✅ 完整 | - |
| **API 影響分析** | ✅ 基礎版 | 🔮 進階版 |
| Model 變更影響 | 🔮 基礎版 | 🔮 完整版 |
| 技術債務 | - | 🔮 完整版 |

---

## 💭 思考：這個場景為什麼重要

1. **高頻場景**：
   - 在前後端分離專案中，API 變更非常頻繁
   - 每次後端迭代都可能影響前端

2. **高風險**：
   - 遺漏修改會導致 runtime 錯誤
   - 影響用戶體驗
   - 可能造成數據錯誤

3. **跨團隊協作**：
   - 後端團隊改 API
   - 前端團隊需要快速評估影響
   - 減少溝通成本

4. **展示 SourceAtlas 價值**：
   - 這是傳統 grep 難以做好的場景
   - 需要理解調用鏈
   - 需要評估影響程度
   - 正好展示 AI 分析的優勢

---

## ✅ 下一步行動

1. **更新 PRD.md**：
   - 擴展場景 3，加入 API 影響分析案例
   - 調整場景優先級

2. **設計 Skill**：
   - /atlas find 需要支援 API 分析模式
   - 可能需要專門的 /atlas api 命令

3. **準備測試案例**：
   - 在 Monorepo 專案測試（Laravel + Next.js）
   - 驗證能否準確追蹤 API 使用

---

**總結**：這是一個非常實際且高價值的場景，應該優先實作在 v2.5 中！
