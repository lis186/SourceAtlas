# /atlas.flow 提案

> 從程式碼抽取業務邏輯流程，解決「梳理 flow 花太多時間」的痛點

## 版本

- **提案版本**: v2.0
- **日期**: 2025-12-01
- **狀態**: 實作中

---

## 問題陳述

### 痛點

工程師在接手或修改不熟悉的功能時，**梳理業務流程**是最耗時的部分：

| 現狀 | 問題 |
|------|------|
| 梳理一個 flow 要 **4-16 小時** | 時間成本高 |
| 知識留在個人腦中 | 無法分享 |
| 有些人有記錄，大部分沒有 | 知識不累積 |
| 程式碼常常改 | 文檔會過時 |
| 每次都重來 | 重複浪費 |

### 常見重災區

- 用戶註冊流程
- 優惠券/折扣計算
- Routing/權限控制
- 付款/退款流程
- 訂單狀態機

---

## 解決方案

### /atlas.flow

```bash
/atlas.flow "用戶下單"
```

**即時生成**業務流程分析，不需要維護文檔。

---

## 分析模式總覽

### 11 個分析模式

| 類別 | Mode | 觸發關鍵字 | 用途 |
|------|------|-----------|------|
| **核心** | Forward Tracing | (預設) | 向下追蹤執行順序 |
| **核心** | Reverse Tracing | 被誰調用, who calls | 向上追蹤調用者 |
| **核心** | Error Path | 失敗, 錯誤, error | 追蹤失敗路徑 |
| **核心** | Data Flow | 怎麼計算, 資料流 | 追蹤資料變化 |
| **變異** | State Machine | 狀態機, lifecycle | 狀態轉換視覺化 |
| **變異** | Comparison | 比較, vs, 差異 | 比較兩個流程 |
| **變異** | Feature Toggle | toggle, 開關, A/B | 開關影響分析 |
| **變異** | Permission/Role | 角色, 權限, RBAC | 按角色分析流程 |
| **系統** | Log Analysis | log, 從 log | 從 log 重建流程 |
| **系統** | Event/Message | event, 事件, queue | 事件驅動追蹤 |
| **系統** | Transaction | transaction, rollback | 交易邊界分析 |
| **系統** | Cache Flow | cache, 快取, TTL | 快取影響分析 |

---

## 入口點識別

### 設計原則：用戶確認 > AI 猜測

避免 AI 猜錯入口點浪費時間，採用三種情況處理：

### 情況 1：用戶明確指定起點

```bash
# 指定檔案
/atlas.flow "從 src/services/order.ts 開始，追蹤下單流程"

# 指定 function
/atlas.flow "從 OrderService.create() 開始"

# 指定行號
/atlas.flow "從 src/checkout.ts:45 開始"
```

→ **直接開始追蹤**，不問問題

### 情況 2：用戶沒有指定起點

```bash
/atlas.flow "下單流程"
```

→ **AI 搜尋並提供選項**：

```
找到 3 個可能的入口點：

1. OrderService.create()
   📍 src/services/order.ts:45

2. CheckoutController.submit()
   📍 src/controllers/checkout.ts:120

3. useCheckout() hook
   📍 src/hooks/useCheckout.ts:30

請選擇要從哪個開始？（或直接說「1」「2」「3」）
```

### 情況 3：只有一個匹配

→ **自動開始**，不問問題

### 追蹤深度控制

用自然語言控制：

```bash
/atlas.flow "從 OrderService.create() 開始，追 3 層"
/atlas.flow "從 OrderService.create() 開始，只看這個檔案內"
/atlas.flow "從 OrderService.create() 開始，完整追蹤"
```

預設行為：
- 追蹤到「邊界」為止（外部 API、資料庫、第三方服務）
- 自動簡化過深的分支

---

## 漸進式展開（資訊理論應用）

### 問題：長篇大論 = 認知過載

一次輸出 50 個步驟，用戶根本看不完。

### 解決：適時停下來，讓用戶選擇

```
下單流程（主要路徑）
====================

1. CheckoutController.submit()     → 接收請求
   📍 src/controllers/checkout.ts:120

2. CartService.validate()          → 驗證購物車
   📍 src/services/cart.ts:45

3. DiscountEngine.apply()          → 計算折扣
   📍 src/services/discount.ts:120
   ├── VIPDiscount.calculate()     → VIP 折扣
   ├── CouponService.apply()       → 優惠券      🔍 [3a]
   └── PointsService.redeem()      → 點數折抵    🔍 [3b]

4. InventoryService.reserve()      → 預扣庫存
   📍 src/services/inventory.ts:156

5. PaymentService.process()        → 處理付款    🔍 [5]
   📍 src/services/payment.ts:200

6. OrderService.create()           → 建立訂單
   📍 src/services/order.ts:45

──────────────────────────────────
📊 流程概覽：6 個主要步驟，3 個可展開

🔍 展開：3a / 3b / 5 / 全部
   或直接說「展開 Coupon」「展開付款」
──────────────────────────────────
```

### 編號規則

| 類型 | 格式 | 範例 |
|------|------|------|
| 主步驟可展開 | `[N]` | `[5]` |
| 子步驟可展開 | `[Na]` `[Nb]` | `[3a]` `[3b]` |
| 深層子步驟 | `[Nab]` | `[3a1]` |

**好處**：
- 保留位置資訊（知道在哪一步）
- 字母區分同層子項目
- 也支援自然語言（「展開付款」）

### 停止點原則

| 情況 | 行為 |
|------|------|
| 主路徑 >7 步驟 | 停下來，詢問是否繼續 |
| 遇到複雜子流程 | 標記 🔍，讓用戶選擇展開 |
| 遇到外部邊界 | 自動停止（API、DB、第三方） |
| 遇到遞迴/循環 | 標記並停止，避免無限展開 |

### 資訊理論依據

> **7±2 法則**：人類工作記憶一次處理 5-9 個項目
>
> **漸進揭露**：先給概覽，需要時再深入
>
> **用戶控制**：讓用戶決定何時深入，而非 AI 決定

---

## 進階模式詳解

### Mode: Reverse Tracing（反向追蹤）

```bash
/atlas.flow "OrderService.create() 被誰調用"
```

輸出：
```
誰調用了 OrderService.create()？
================================

調用者（3 個入口）：
├── CheckoutController.submit()     → 正常下單
│   📍 src/controllers/checkout.ts:120
│
├── AdminController.manualOrder()   → 後台手動建單
│   📍 src/controllers/admin.ts:45
│
└── CronJob.retryFailedOrders()     → 重試失敗訂單
    📍 src/jobs/retry.ts:80

💡 修改 OrderService.create() 會影響這 3 個入口
```

### Mode: Error Path（失敗路徑）

```bash
/atlas.flow "下單失敗會怎樣"
```

輸出：
```
下單流程（失敗路徑）
==================

1. CartService.validate()
   📍 src/services/cart.ts:45
   ⚠️ 失敗 → CartEmptyError
      └── 回傳 400 + 錯誤訊息

2. InventoryService.check()
   📍 src/services/inventory.ts:78
   ⚠️ 失敗 → OutOfStockError
      ├── 記錄 log
      ├── 發送通知給運營
      └── 回傳 409 + 缺貨商品清單

📌 風險：step 4 沒有 rollback，可能有孤兒訂單
```

### Mode: Feature Toggle（開關分析）

```bash
/atlas.flow "下單流程有哪些 feature toggle"
```

輸出：
```
下單流程 Feature Toggles
========================

發現 4 個影響此流程的 feature toggle：

┌─────────────────────────────────────────────────────────────┐
│ Toggle                    │ 影響步驟        │ 目前狀態      │
├───────────────────────────┼─────────────────┼───────────────┤
│ NEW_PAYMENT_FLOW          │ Step 5 付款     │ 🟡 50% rollout│
│ ENABLE_POINTS_REDEMPTION  │ Step 3 折扣     │ 🟢 ON         │
│ USE_NEW_INVENTORY_API     │ Step 4 庫存     │ 🔴 OFF        │
│ BETA_CHECKOUT_UI          │ Step 1 前端     │ 🟡 Beta users │
└─────────────────────────────────────────────────────────────┘
```

### Mode: Event/Message（事件追蹤）

```bash
/atlas.flow "ORDER_CREATED 事件觸發什麼"
```

輸出：
```
ORDER_CREATED 事件追蹤
======================

📤 事件發送：
OrderService.create()
   📍 src/services/order.ts:210
   → emit("ORDER_CREATED", { orderId, userId, items })

📥 事件監聽者（4 個）：

1. InventoryListener.onOrderCreated()
   📍 src/listeners/inventory.ts:30
   → 扣減實際庫存

2. NotificationListener.onOrderCreated()
   📍 src/listeners/notification.ts:45
   → 發送確認信給用戶

📌 注意事項：
• Listener 執行順序不保證
• InventoryListener 失敗不會 rollback 訂單
```

### Mode: Transaction（交易邊界）

```bash
/atlas.flow "下單流程的 transaction"
```

輸出：
```
下單流程 Transaction 分析
=========================

┌─ Transaction 1 (@Transactional) ────────────┐
│ 1. CartService.validate()                    │
│ 2. InventoryService.reserve()                │
│ 3. OrderService.create()                     │
└──────────────────────────────────────────────┘

[無 Transaction - 外部呼叫]
4. PaymentService.process()
   ⚠️ 無法 rollback

⚠️ 風險：
• Step 4 失敗時，Transaction 1 已 commit
• 需要補償機制（Saga pattern）
```

### Mode: Permission/Role（權限分析）

```bash
/atlas.flow "刪除訂單，按角色"
```

輸出：
```
刪除訂單流程（按角色）
=====================

[ADMIN] → 直接刪除，不可恢復
[SELLER] → 只能取消未發貨，需填原因
[BUYER] → 只能申請取消，等待賣家同意

📊 權限矩陣：
| 操作 | ADMIN | SELLER | BUYER |
|------|-------|--------|-------|
| 硬刪除 | ✅ | ❌ | ❌ |
| 直接取消 | ✅ | ✅ | ❌ |
| 申請取消 | ✅ | ✅ | ✅ |
```

### Mode: Cache（快取分析）

```bash
/atlas.flow "獲取商品，包含 cache"
```

輸出：
```
獲取商品價格（Cache 分析）
=========================

1. 檢查 Cache
   💾 Key: "product:${id}:price"
   💾 TTL: 5 分鐘

   [CACHE HIT] → 直接返回（~5ms）
   [CACHE MISS] → 查 DB（~50-100ms）

⚠️ Cache 一致性風險：
❌ ProductService.bulkUpdate() 沒有清 cache！
```

---

## 注意事項標記（資訊理論應用）

標注「值得注意」的部分，減少認知負擔：

| 類型 | 說明 | 標記 |
|------|------|------|
| **順序特殊** | 步驟順序和常見模式不同 | 📌 順序 |
| **缺少保護** | 沒有 transaction、沒有 rollback | 📌 風險 |
| **隱藏副作用** | 看起來是查詢，實際會修改 | 📌 副作用 |
| **重複邏輯** | 多處計算同一件事 | 📌 重複 |
| **不一致** | 同樣邏輯在不同地方實作不同 | 📌 不一致 |
| **魔法數字** | 硬編碼的業務規則 | 📌 魔法值 |

**原則**：
> 一般的部分：掃一眼就過
> 注意事項：停下來仔細看

---

## 輸出選項（非獨立模式）

這些不是獨立模式，而是可以加在任何模式上的選項：

| 選項 | 語法 | 說明 |
|------|------|------|
| 時間標註 | `顯示時間` | ⏱️ sync/async, ⏳ 預估延遲 |
| 作者資訊 | `顯示作者` | 👤 git blame 資訊 |
| 測試覆蓋 | `顯示測試` | 🧪 是否有測試覆蓋 |
| Mermaid | `輸出 mermaid` | 流程圖格式 |

範例：
```bash
/atlas.flow "下單流程，顯示時間"
/atlas.flow "下單流程，輸出 mermaid"
```

---

## 目標用戶

基於用戶研究，識別出六種主要角色：

| 角色 | 情境 | 時間壓力 | 最需要的 |
|------|------|----------|---------|
| **資深工程師** | 接手遺留系統 | 1 小時修 Bug | 執行順序 + 風險標記 |
| **Tech Lead** | 帶團隊重構 | 3 天評估 | 向上溝通 + 量化複雜度 |
| **技術顧問** | 盡職調查 | 1 週報告 | 商業語言 + 投資建議 |
| **初級工程師** | 修不熟的 Bug | 當天解決 | 檔案位置 + 影響範圍 |
| **QA 工程師** | 寫測試案例 | 功能上線前 | 所有分支 + 錯誤碼 |
| **DevOps/SRE** | 線上問題排查 | 立即 | Log 點 + 依賴服務 |

### 共同需求

1. **執行順序** - 先做什麼、再做什麼
2. **檔案位置 + 行號** - 可以直接跳過去
3. **業務語言解釋** - 不只是程式碼
4. **影響範圍** - 改了會不會弄壞其他
5. **分層輸出** - 5 分鐘摘要 → 需要時深入

### 共同厭惡

- ❌ 只列檔案清單（grep 就能做到）
- ❌ 純技術術語（CEO 看不懂）
- ❌ 貼全部程式碼（不需要複製貼上機器人）
- ❌ 沒有優先級（50 個問題沒時間全看）
- ❌ 沒有檔案位置（看得到吃不到）

---

## 設計原則

### 1. 零參數設計

符合 SourceAtlas 風格，不強制任何參數：

```bash
/atlas.flow "用戶下單"  # 就這樣，沒有 --flags
```

### 2. 智慧預設

根據情境自動選擇輸出格式：
- CLI 直接執行 → ASCII + 顏色
- 複雜流程 → 自動簡化 + 標注異常

### 3. 自然語言控制

用自然語言調整輸出和模式：

```bash
/atlas.flow "用戶下單，詳細一點"
/atlas.flow "用戶下單，看失敗路徑"
/atlas.flow "用戶下單，有哪些 feature toggle"
```

### 4. 模式自動偵測

根據用戶輸入自動選擇模式：

```
if 用戶問「被誰調用」→ Reverse Tracing
if 用戶問「失敗」「錯誤」→ Error Path
if 用戶問「feature toggle」「開關」→ Feature Toggle
if 用戶問「transaction」「交易」→ Transaction Boundary
...
```

---

## 命令串接設計

### 有價值的串接場景

| 串接 | 場景 | 價值 |
|------|------|------|
| overview → flow | 從全貌到細節 | ⭐⭐⭐⭐⭐ |
| flow → impact | 理解後想修改 | ⭐⭐⭐⭐⭐ |
| history → flow | 熱點為什麼常改 | ⭐⭐⭐⭐ |
| flow → flow | 分層探索子流程 | ⭐⭐⭐⭐⭐ |

### 上下文感知追問

```
用戶: /atlas.flow "登入流程"
AI: （輸出流程）

用戶: step 6 怎麼運作的
AI: （自動展開 step 6 細節）

用戶: 這裡改了會影響什麼
AI: （自動調用 /atlas.impact）

用戶: 為什麼這裡常被改
AI: （自動調用 /atlas.history）
```

---

## 價值主張

| 指標 | 現狀 | 有 /atlas.flow |
|------|------|----------------|
| 梳理時間 | 4-16 小時 | 5 分鐘 |
| 知識分享 | 在個人腦中 | 可輸出分享 |
| 文檔過時 | 常見 | 每次都最新 |
| 不同人理解 | 不一致 | 一致輸出 |

---

## 實作狀態

- [x] 完成 POC 測試 ✅
- [x] 測試「登入流程」分析 ✅
- [x] 測試「export to PNG」分析（Excalidraw）✅
- [x] 測試「第三方 SSO」分析（iOS Swift/ObjC）✅
- [x] 設計 11 個分析模式 ✅
- [x] 實作命令串接機制 ✅
- [ ] 更多專案驗證
- [ ] 收集回饋，迭代設計

---

## 相關文件

- 實作：`.claude/commands/atlas.flow.md`
- 用戶研究：本提案內含六種角色分析
- 建議測試專案：Excalidraw、Cal.com、電商類 App
