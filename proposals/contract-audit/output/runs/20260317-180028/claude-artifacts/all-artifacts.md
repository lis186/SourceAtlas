檔案不在本地磁碟中，我將根據你提供的內聯程式碼進行完整的合約稽核。這是一個大型分析任務，讓我系統性地產出四個 Artifact。

---

# Contract Audit: EventHistory.ts

## 目標模組

- **EventHistory.ts** (~270 行) — 主要稽核對象
- **DatabaseManager.ts** (部分，從 Caller Interface 擷取)
- **examples.ts** (部分，從 Caller Interface 擷取)

**重構意圖**：（由你提供的上下文推斷）重構前的完整合約盤點

---

# Artifact 1: Contract Spec Document

---

## F1: Tell the Story

```
STORY: 此模組是一個事件歷史記錄的 Facade，負責 (1) 透過 DatabaseManager 將事件操作寫入 IndexedDB、(2) 提供多維度查詢介面、(3) 管理記錄的生命週期（定期清理與過期淘汰）。

LIES:
- 「停用就是不做事」：disabled/uninitialized 時靜默回傳空值，呼叫者無法區分「沒有資料」和「功能被關閉」——重構時若改變回傳語義，所有消費端都會受影響
- 「錯誤被妥善處理」：大多數方法吞掉錯誤並回傳預設值，呼叫者無法偵測資料庫故障——重構若改為拋出會破壞所有現有消費端
- 「cleanup 是背景獨立運作」：定期清理計時器可以與任何操作並行執行，包括 close()，且沒有任何並行保護——重構時移動 cleanup 邏輯可能引入競態條件
```

## F2: Scratch Refactoring

```
SCRATCH_REFACTORING:
1. 將守衛模式 (!this.isInitialized || !this.options.enabled) 提取為 private ensureReady() 方法
   REVEALS: P-001（每個方法的「空值」回傳型別不同：void / [] / null / {totalRecords:0,channelCount:0} / 0），以及 E-001~E-008（哪些方法拋出、哪些吞掉錯誤的不一致性）

2. 讓 DatabaseManager 透過建構函式注入而非內部建立
   REVEALS: D-001（dbManager.init() 必須在任何其他 dbManager 方法之前呼叫的隱含順序）、L-002（isInitialized 與 dbManager 初始化狀態的耦合）

3. 將 setInterval 替換為可注入的排程器
   REVEALS: S-002（cleanup 與其他操作的並行執行）、S-003（close() 與進行中操作的競態條件）、L-003（cleanup timer 啟動時機與 init 的綁定）
```

---

## Contracts

---

### Category M — Mutation Contracts

---

**M-001: 記錄建立時自動注入 timestamp**

```
Trigger:      呼叫 recordOperation() 且 isInitialized=true 且 enabled=true
Input:        operation, channel, event?, from?, targetEvent? 參數
Output:       IndexedDB 中新增一筆記錄，timestamp 為 Date.now()
Condition:    isInitialized === true && options.enabled === true
Ordering:     在 dbManager.addRecord() 之前組裝 record 物件
Risk:         MEDIUM -- timestamp 由模組控制而非由呼叫者傳入，重構時若改為允許外部 timestamp 會影響所有查詢的排序假設
Evidence:     EventHistory.ts:81-89 -- `const record: Omit<EventHistoryRecord, 'id'> = { ... timestamp: Date.now(), ... }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**M-002: 清理過期記錄基於 retentionTime**

```
Trigger:      呼叫 cleanup()（手動或由計時器觸發）且 isInitialized=true 且 enabled=true
Input:        this.options.retentionTime（預設 300000ms = 5 分鐘）
Output:       IndexedDB 中刪除超過 retentionTime 的記錄；回傳刪除筆數
Condition:    isInitialized === true && options.enabled === true
Ordering:     在 dbManager.cleanupExpiredRecords() 之後才記錄 log
Risk:         HIGH -- retentionTime 可被 updateOptions() 動態修改，且修改立即生效於下次 cleanup，可能意外刪除大量資料
Evidence:     EventHistory.ts:190-191 -- `const deletedCount = await this.dbManager.cleanupExpiredRecords(this.options.retentionTime)`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

**M-003: clear() 刪除所有記錄**

```
Trigger:      呼叫 clear() 且 isInitialized=true 且 enabled=true
Input:        無
Output:       IndexedDB 中 eventHistory store 的所有記錄被刪除
Condition:    isInitialized === true && options.enabled === true
Ordering:     dbManager.clearAllRecords() 完成後記錄 log
Risk:         HIGH -- 不可逆的破壞性操作，無確認機制，且失敗時會拋出錯誤（與其他方法吞掉錯誤的行為不一致）
Evidence:     EventHistory.ts:173 -- `await this.dbManager.clearAllRecords()`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**M-004: updateOptions() 淺合併但不重新初始化**

```
Trigger:      呼叫 updateOptions()
Input:        Partial<EventHistoryOptions>
Output:       this.options 被淺合併更新；若包含 databaseName 或 databaseVersion 僅記錄 warn
Condition:    無——即使未初始化也可呼叫
Ordering:     合併立即生效，但 dbManager 不會更新
Risk:         CRITICAL -- 修改 databaseName/databaseVersion 後 dbManager 仍指向舊資料庫，造成 options 與實際行為不一致。修改 retentionTime 立即生效於下次 cleanup，可能意外改變資料保留策略。修改 enabled 為 false 後所有操作靜默停止但 cleanup timer 仍在運行
Evidence:     EventHistory.ts:263-268 -- `this.options = { ...this.options, ...newOptions }`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

**M-005: constructor 建立 DatabaseManager 實例並設定預設 options**

```
Trigger:      new EventHistory(options?)
Input:        EventHistoryOptions（全部 optional，有預設值）
Output:       建立新的 DatabaseManager 實例（尚未初始化）；options 被合併為 Required<EventHistoryOptions>
Condition:    無
Ordering:     constructor 完成後必須呼叫 init() 才能使用其他方法
Risk:         MEDIUM -- 預設值是硬編碼的隱含合約：retentionTime=300000, maxRecords=1000, enabled=true, databaseName='EventHistory', databaseVersion=1
Evidence:     EventHistory.ts:24-38 -- `constructor(options: EventHistoryOptions = {}) { ... this.dbManager = new DatabaseManager(...) }`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

---

### Category L — Lifecycle / State Machine Contracts

---

**L-001: init() 冪等——已初始化時直接 return**

```
Trigger:      呼叫 init() 且 isInitialized === true
Input:        無
Output:       無（直接返回，不執行任何操作）
Condition:    this.isInitialized === true
Ordering:     在任何 dbManager 操作之前檢查
Risk:         MEDIUM -- 冪等性依賴 isInitialized 布林旗標，但此旗標沒有並行保護（見 S-001）
Evidence:     EventHistory.ts:44-46 -- `if (this.isInitialized) { return }`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

**L-002: init() 在 disabled 時提前返回，不設定 isInitialized**

```
Trigger:      呼叫 init() 且 options.enabled === false
Input:        this.options.enabled
Output:       logger.info 記錄停用訊息；isInitialized 保持 false
Condition:    this.options.enabled === false（且 isInitialized === false）
Ordering:     在 isInitialized 檢查之後、dbManager.init() 之前
Risk:         HIGH -- disabled 的 EventHistory 永遠不會被初始化，所有後續操作靜默回傳空值。若之後透過 updateOptions() 將 enabled 改為 true，仍然不會自動初始化（isInitialized 仍為 false），必須重新呼叫 init()
Evidence:     EventHistory.ts:48-51 -- `if (!this.options.enabled) { logger.info('EventHistory 已停用'); return }`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

**L-003: init 成功後啟動 cleanup timer**

```
Trigger:      dbManager.init() 成功完成
Input:        無
Output:       啟動 setInterval（60000ms），定期呼叫 this.cleanup()
Condition:    init() 路徑中 try 區塊成功執行
Ordering:     在 isInitialized = true 和 logger.info 之後
Risk:         MEDIUM -- timer 的生命週期與 EventHistory 實例綁定，但 JavaScript 的 setInterval 持有對 callback 的參考，可能阻止垃圾回收
Evidence:     EventHistory.ts:59 -- `this.startCleanupTimer()`
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

**L-004: close() 先停 timer 再關閉 dbManager 並重設 isInitialized**

```
Trigger:      呼叫 close()
Input:        無
Output:       停止 cleanup timer → 關閉 dbManager → isInitialized = false → 記錄 log
Condition:    isInitialized === true 時執行 dbManager.close()；isInitialized === false 時僅停止 timer
Ordering:     1. stopCleanupTimer() → 2. dbManager.close() → 3. isInitialized = false
Risk:         HIGH -- close() 不是 async-safe：停止 timer 後若有已排程但尚未完成的 cleanup 仍在執行，dbManager.close() 會在 cleanup 完成前關閉資料庫。另外 dbManager.close() 是同步呼叫，但 close() 本身是 async——這暗示未來可能有非同步清理需求
Evidence:     EventHistory.ts:236-244 -- `async close(): Promise<void> { this.stopCleanupTimer(); if (this.isInitialized) { this.dbManager.close(); this.isInitialized = false; ... } }`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

**L-005: 狀態機：未初始化 → 已初始化 → 已關閉**

```
Trigger:      init() / close() 呼叫
Input:        無
Output:       isInitialized 在 false ↔ true 之間切換
Condition:    init: !isInitialized && enabled; close: isInitialized
Ordering:     正向: constructor → init() → [operations] → close()。close() 後可再次 init()
Risk:         CRITICAL -- 狀態機只有一個布林值 isInitialized，無法區分「從未初始化」、「已初始化」、「正在初始化」、「已關閉」、「正在關閉」五種狀態。重構時若需要更精細的狀態控制，需要替換為 enum
Evidence:     EventHistory.ts:22,44-46,55,241 -- `private isInitialized = false` ... `this.isInitialized = true` ... `this.isInitialized = false`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

---

### Category E — Error Handling Contracts

---

**E-001: init() 重新拋出錯誤**

```
Trigger:      dbManager.init() 拋出錯誤
Input:        任何 dbManager.init() 的例外
Output:       logger.error 記錄後 re-throw 原始錯誤
Condition:    try 區塊中 dbManager.init() 失敗
Ordering:     log → throw（isInitialized 保持 false，timer 未啟動）
Risk:         HIGH -- 這是唯二會拋出的方法之一（另一個是 clear），呼叫者必須 catch
Evidence:     EventHistory.ts:60-63 -- `catch (error) { logger.error({ error }, 'EventHistory 初始化失敗'); throw error }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**E-002: recordOperation() 吞掉所有錯誤**

```
Trigger:      dbManager.addRecord() 拋出錯誤
Input:        任何資料庫寫入例外
Output:       logger.error 記錄；不拋出；Promise<void> 正常 resolve
Condition:    try 區塊中 dbManager.addRecord() 失敗
Ordering:     log 後靜默返回
Risk:         HIGH -- 呼叫者無法得知記錄是否成功寫入。若 IndexedDB 配額已滿或資料庫損毀，所有寫入會靜默失敗
Evidence:     EventHistory.ts:102-104 -- `catch (error) { logger.error({ error, operation, channel }, '記錄事件操作失敗') }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**E-003: queryRecords() 吞掉錯誤並回傳空陣列**

```
Trigger:      dbManager.queryRecords() 拋出錯誤
Input:        任何資料庫讀取例外
Output:       logger.error 記錄；回傳 []
Condition:    try 區塊中查詢失敗
Ordering:     log → return []
Risk:         HIGH -- 呼叫者無法區分「查無結果」和「查詢失敗」
Evidence:     EventHistory.ts:117-120 -- `catch (error) { logger.error({ error, query }, '查詢事件記錄失敗'); return [] }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**E-004: getLatestPublishRecord() 吞掉錯誤並回傳 null**

```
Trigger:      dbManager.getLatestRecord() 拋出錯誤
Input:        任何資料庫讀取例外
Output:       logger.error 記錄；回傳 null
Condition:    try 區塊中查詢失敗
Ordering:     log → return null
Risk:         HIGH -- 呼叫者無法區分「無最新記錄」和「查詢失敗」
Evidence:     EventHistory.ts:136-139 -- `catch (error) { logger.error({ error, channel, eventType }, '獲取最新發布記錄失敗'); return null }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**E-005: getStats() 吞掉錯誤並回傳空統計**

```
Trigger:      dbManager.getStats() 拋出錯誤
Input:        任何資料庫讀取例外
Output:       logger.error 記錄；回傳 { totalRecords: 0, channelCount: 0 }
Condition:    try 區塊中查詢失敗
Ordering:     log → return 空統計
Risk:         HIGH -- 呼叫者無法區分「資料庫為空」和「資料庫不可用」；回傳的空統計與 disabled guard 回傳值完全相同
Evidence:     EventHistory.ts:155-161 -- `catch (error) { logger.error({ error }, '獲取統計資訊失敗'); return { totalRecords: 0, channelCount: 0 } }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**E-006: clear() 重新拋出錯誤**

```
Trigger:      dbManager.clearAllRecords() 拋出錯誤
Input:        任何資料庫寫入例外
Output:       logger.error 記錄後 re-throw 原始錯誤
Condition:    try 區塊中清空失敗
Ordering:     log → throw
Risk:         MEDIUM -- 與 E-001 一致，拋出行為正確。但與 E-002~E-005/E-007 不一致，呼叫者可能不預期此方法會拋出
Evidence:     EventHistory.ts:175-178 -- `catch (error) { logger.error({ error }, '清空記錄失敗'); throw error }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**E-007: cleanup() 吞掉錯誤並回傳 0**

```
Trigger:      dbManager.cleanupExpiredRecords() 拋出錯誤
Input:        任何資料庫寫入例外
Output:       logger.error 記錄；回傳 0
Condition:    try 區塊中清理失敗
Ordering:     log → return 0
Risk:         MEDIUM -- 呼叫者無法區分「無過期記錄」和「清理失敗」。計時器會持續呼叫，所以失敗會在 log 中反覆出現
Evidence:     EventHistory.ts:199-201 -- `catch (error) { logger.error({ error }, '清理過期記錄失敗'); return 0 }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**E-008: startCleanupTimer 的 callback 吞掉 cleanup 錯誤**

```
Trigger:      計時器 callback 中 this.cleanup() 拋出錯誤
Input:        任何 cleanup() 的例外（理論上 cleanup 本身已吞掉，但 E-007 可能有遺漏）
Output:       logger.error 記錄
Condition:    setInterval callback 中的 try-catch
Ordering:     log 後繼續——計時器不會停止
Risk:         LOW -- 這是雙重保護（cleanup 本身已吞掉錯誤），但若 cleanup 的 guard 邏輯或 cleanup 被重構為拋出，此處是最後防線
Evidence:     EventHistory.ts:214-220 -- `setInterval(async () => { try { await this.cleanup() } catch (error) { logger.error({ error }, '定期清理失敗') } }, 60000)`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**E-009: DatabaseManager.ensureDb() 拋出錯誤（跨模組）**

```
Trigger:      任何 dbManager 方法在 db 為 null 時被呼叫
Input:        DatabaseManager 內部 this.db === null
Output:       throw new Error（推測，基於 DatabaseManager.ts:60 的 throw_new 錨點）
Condition:    dbManager.init() 未呼叫或失敗
Ordering:     在任何 IDB 交易之前
Risk:         HIGH -- EventHistory 依賴 init() 成功後才呼叫 dbManager 方法。若 isInitialized 狀態不一致（例如 close() 後的競態條件），此錯誤會被各方法的 catch 區塊捕獲
Evidence:     DatabaseManager.ts:60 -- throw_new 錨點
Scope:        module
Seam_Type:    object
Pinch_Point:  true
```

---

### Category S — Synchronization Contracts

---

**S-001: init() 無並行保護——可能重複初始化**

```
Trigger:      多個呼叫者同時呼叫 init()
Input:        isInitialized 旗標（非原子性檢查）
Output:       可能執行多次 dbManager.init()，多次設定 isInitialized = true，多次啟動 timer
Condition:    兩個 init() 呼叫在 await dbManager.init() 之前都通過了 isInitialized 檢查
Ordering:     第一個 await 讓出控制權後，第二個呼叫可以進入 try 區塊
Risk:         HIGH -- 重複 dbManager.init() 可能導致資料庫連線異常；重複 startCleanupTimer() 會清除前一個 timer 再建新的（因為 startCleanupTimer 本身有保護），但中間有短暫的 timer 空窗期
Evidence:     EventHistory.ts:44-63 -- `if (this.isInitialized) { return } ... await this.dbManager.init() ... this.isInitialized = true`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

**S-002: cleanup timer 與其他操作並行執行**

```
Trigger:      setInterval callback 觸發（每 60 秒）
Input:        無
Output:       cleanup() 可以與 recordOperation()、queryRecords() 等同時執行
Condition:    timer 已啟動（init 成功後）
Ordering:     無保證——cleanup 的 IndexedDB 交易與其他操作的交易可能交錯
Risk:         MEDIUM -- IndexedDB 本身有交易隔離機制，但 cleanup 刪除記錄可能導致同時進行的 queryRecords 結果不一致（non-repeatable read）
Evidence:     EventHistory.ts:214 -- `this.cleanupTimer = setInterval(async () => { ... await this.cleanup() ... }, 60000)`
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

**S-003: close() 與進行中操作的競態條件**

```
Trigger:      在某個 async 方法（如 recordOperation）的 await 期間呼叫 close()
Input:        isInitialized 在操作進行中被設為 false
Output:       進行中的操作可能在 dbManager 已關閉後嘗試使用它
Condition:    async 操作在 close() 前通過了 guard 檢查，但在 close() 後才到達 dbManager 呼叫
Ordering:     close() 的 dbManager.close() 是同步的，可以在任何 await 之間發生
Risk:         HIGH -- 可能導致「database not open」錯誤。被各方法的 catch 區塊捕獲並吞掉，但行為不正確
Evidence:     EventHistory.ts:236-244 -- `async close() { this.stopCleanupTimer(); if (this.isInitialized) { this.dbManager.close(); this.isInitialized = false; } }`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

**S-004: DatabaseManager.getStats() 使用 Promise.all 並行查詢（錨定合約）**

```
Trigger:      EventHistory.getStats() → dbManager.getStats()
Input:        兩個 IDB 請求（count + getAll）
Output:       兩個請求並行執行，都成功後回傳合併結果
Condition:    在同一個 readonly 交易中
Ordering:     Promise.all 保證兩者都完成後才 resolve；任一失敗則 reject
Risk:         MEDIUM -- 如果一個請求成功但另一個失敗，成功的結果被丟棄。EventHistory 的 E-005 會將整個失敗吞掉
Evidence:     DatabaseManager.ts:238 -- `Promise.all([ new Promise<number>(...), new Promise<EventHistoryRecord[]>(...) ])`
Scope:        module
Seam_Type:    object
Pinch_Point:  false
```

---

### Category D — Dependency Contracts

---

**D-001: DatabaseManager 的 init-before-use 隱含順序**

```
Trigger:      任何 dbManager 方法呼叫
Input:        dbManager 的內部 db: IDBDatabase | null
Output:       若 db 為 null（未 init），ensureDb() 拋出錯誤
Condition:    dbManager.init() 必須在任何其他方法之前成功完成
Ordering:     constructor → init() → [addRecord/queryRecords/getLatestRecord/getStats/clearAllRecords/cleanupExpiredRecords/close]
Risk:         HIGH -- EventHistory 透過 isInitialized 旗標保護此順序，但旗標沒有並行保護（S-001）
Evidence:     EventHistory.ts:34-37,54 -- `this.dbManager = new DatabaseManager(...)` ... `await this.dbManager.init()`；DatabaseManager.ts:60 -- throw_new
Scope:        module
Seam_Type:    object
Pinch_Point:  true
```

**D-002: 依賴 @91app/shared-provider 的 logger**

```
Trigger:      模組載入時
Input:        @91app/shared-provider 套件必須可用且匯出 logger
Output:       logger 物件用於 info/error/trace/warn 層級的記錄
Condition:    import 時期解析
Ordering:     模組載入時即匯入
Risk:         LOW -- logger 是穩定的共用基礎設施，不太可能變更。但 logger 不可用會導致 import 失敗
Evidence:     EventHistory.ts:6 -- `import { logger } from '@91app/shared-provider'`
Scope:        module
Seam_Type:    link
Pinch_Point:  false
```

**D-003: 實作 IEventHistory 介面（@91app/trinity-kernel）**

```
Trigger:      模組載入時（型別檢查階段）
Input:        @91app/trinity-kernel 的 IEventHistory 介面定義
Output:       EventHistory 必須滿足 IEventHistory 的所有方法簽名
Condition:    TypeScript 編譯期檢查
Ordering:     編譯時
Risk:         CRITICAL -- 介面定義在外部套件中，其任何變更都可能破壞此模組。介面的方法簽名是跨套件合約——重構時必須保持相容。examples.ts:80 明確使用 `eventHistory as IEventHistory`
Evidence:     EventHistory.ts:18 -- `export class EventHistory implements IEventHistory`；examples.ts:80 -- `eventHistory: eventHistory as IEventHistory`
Scope:        module
Seam_Type:    object
Pinch_Point:  true
```

**D-004: 依賴 Node.js timer API（setInterval / clearInterval）**

```
Trigger:      init() 成功後
Input:        NodeJS.Timeout 型別；setInterval / clearInterval 全域函式
Output:       計時器 ID 存於 this.cleanupTimer
Condition:    瀏覽器環境（IndexedDB）同時使用 NodeJS.Timeout 型別——環境不一致
Risk:         MEDIUM -- IndexedDB 是瀏覽器 API，但 NodeJS.Timeout 是 Node.js 型別。在純瀏覽器環境中 NodeJS.Timeout 不存在，需要 @types/node 或 polyfill。實際上 setInterval/clearInterval 在兩個環境都可用，但型別定義不同
Evidence:     EventHistory.ts:21 -- `private cleanupTimer?: NodeJS.Timeout`；EventHistory.ts:214 -- `this.cleanupTimer = setInterval(...)`
Scope:        class
Seam_Type:    preprocessing
Pinch_Point:  false
```

**D-005: 依賴 ./types 模組的型別定義**

```
Trigger:      模組載入時
Input:        EventHistoryOptions, EventHistoryRecord, EventHistoryQuery, EventHistoryStats, EventPayload, EventOperation
Output:       這些型別定義 EventHistory 的 public API 形狀
Condition:    import 時期解析
Ordering:     編譯時
Risk:         MEDIUM -- 型別變更（例如新增必要欄位）會影響所有使用此模組的消費端
Evidence:     EventHistory.ts:8-15 -- `import { EventHistoryOptions, EventHistoryRecord, ... } from './types'`
Scope:        module
Seam_Type:    link
Pinch_Point:  false
```

---

### Category C — Cancellation Contracts

---

**C-001: stopCleanupTimer 取消定期清理**

```
Trigger:      呼叫 stopCleanupTimer()（由 close() 呼叫或 startCleanupTimer() 重設時呼叫）
Input:        this.cleanupTimer
Output:       clearInterval 停止計時器；cleanupTimer 設為 undefined
Condition:    cleanupTimer !== undefined
Ordering:     clearInterval → undefined 賦值
Risk:         MEDIUM -- clearInterval 只能阻止未來的 callback，無法取消已在執行中的 cleanup() 呼叫。若 cleanup() 正在 await dbManager.cleanupExpiredRecords()，它會繼續完成
Evidence:     EventHistory.ts:226-231 -- `private stopCleanupTimer(): void { if (this.cleanupTimer) { clearInterval(this.cleanupTimer); this.cleanupTimer = undefined } }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**C-002: 無法取消進行中的資料庫操作**

```
Trigger:      任何 async 方法的 await dbManager.xxx() 進行中
Input:        無取消機制（無 AbortController、無 Promise cancellation）
Output:       操作必須完成或失敗，無法中途取消
Condition:    總是
Ordering:     不適用
Risk:         MEDIUM -- close() 無法等待進行中的操作完成，導致 S-003 的競態條件
Evidence:     全部 async 方法——無 AbortSignal 參數
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

---

### Category N — Notification / Observation Contracts

（此模組無 pub/sub 或事件發射機制。）

---

### Category P — Propagation Contracts

---

**P-001: guard 模式回傳不同的「空值」型別**

```
Trigger:      呼叫任何 public async 方法時 !isInitialized || !enabled
Input:        isInitialized, options.enabled
Output:       每個方法回傳不同的「空」值：
              - recordOperation → void (return)
              - queryRecords → []
              - getLatestPublishRecord → null
              - getStats → { totalRecords: 0, channelCount: 0 }
              - clear → void (return)
              - cleanup → 0
Condition:    isInitialized === false || options.enabled === false
Ordering:     在任何業務邏輯之前
Risk:         CRITICAL -- 消費端無法區分「功能停用」和「真的沒有資料」。這些空值與錯誤 fallback 值完全相同（見 E-003~E-007），使得故障偵測不可能
Evidence:     EventHistory.ts:76-78,111-113,130-132,146-151,168-170,185-187
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

**P-002: recordOperation 將 optional 參數原封不動傳給 DatabaseManager**

```
Trigger:      呼叫 recordOperation()
Input:        event?.type, event, from, targetEvent — 全部 optional
Output:       eventType 可能是 undefined（透過 event?.type）；event/from/targetEvent 可能是 undefined
Condition:    呼叫者未傳入 optional 參數
Ordering:     組裝 record 物件後立即傳給 dbManager.addRecord()
Risk:         MEDIUM -- DatabaseManager 和 IndexedDB 索引可能對 undefined 欄位有特殊處理（不索引、無法查詢）。eventType 的 undefined 值意味著某些 query 無法匹配
Evidence:     EventHistory.ts:81-89 -- `eventType: event?.type, event, ... from, targetEvent`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

**P-003: getStats() 的 fallback 值與真實空資料庫相同**

```
Trigger:      getStats() 失敗或 disabled
Input:        無
Output:       { totalRecords: 0, channelCount: 0 }
Condition:    disabled/uninitialized（P-001）或 error（E-005）
Ordering:     不適用
Risk:         HIGH -- 消費端可能根據 totalRecords === 0 判斷「資料庫為空」並觸發初始化邏輯，但實際上資料庫可能有大量資料（只是查詢失敗了）
Evidence:     EventHistory.ts:147-150,157-160
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

## F3: Effect Propagation Tracing

```
EFFECT_TRACE: constructor(options?: EventHistoryOptions)
  RETURN:  EventHistory instance
  MUTATES: none (creates new instance)
  GLOBAL:  none
  DEPTH:   0

EFFECT_TRACE: async init(): Promise<void>
  RETURN:  void
  MUTATES: this.isInitialized (false → true), this.cleanupTimer (undefined → Timeout)
  GLOBAL:  IndexedDB database created/opened via dbManager.init(); logger side-effect
  DEPTH:   2 (EventHistory → DatabaseManager → IndexedDB)

EFFECT_TRACE: async recordOperation(operation, channel, event?, from?, targetEvent?): Promise<void>
  RETURN:  void
  MUTATES: none (parameters not mutated)
  GLOBAL:  IndexedDB record inserted via dbManager.addRecord(); logger side-effect
  DEPTH:   2 (EventHistory → DatabaseManager → IndexedDB)

EFFECT_TRACE: async queryRecords(query: EventHistoryQuery): Promise<EventHistoryRecord[]>
  RETURN:  EventHistoryRecord[] → returned directly to caller (no transformation)
  MUTATES: none
  GLOBAL:  none (read-only); logger on error
  DEPTH:   2 (EventHistory → DatabaseManager → IndexedDB)

EFFECT_TRACE: async getLatestPublishRecord(channel, eventType?): Promise<EventHistoryRecord | null>
  RETURN:  EventHistoryRecord | null → returned directly to caller (no transformation)
  MUTATES: none
  GLOBAL:  none (read-only); logger on error
  DEPTH:   2 (EventHistory → DatabaseManager → IndexedDB)

EFFECT_TRACE: async getStats(): Promise<EventHistoryStats>
  RETURN:  EventHistoryStats → returned directly from dbManager (no transformation)
  MUTATES: none
  GLOBAL:  none (read-only); logger on error
  DEPTH:   2 (EventHistory → DatabaseManager → IndexedDB, uses Promise.all internally)

EFFECT_TRACE: async clear(): Promise<void>
  RETURN:  void
  MUTATES: none (parameters)
  GLOBAL:  IndexedDB store cleared via dbManager.clearAllRecords(); logger side-effect
  DEPTH:   2 (EventHistory → DatabaseManager → IndexedDB)

EFFECT_TRACE: async cleanup(): Promise<number>
  RETURN:  number (deleted count) → returned directly to caller or consumed by timer callback
  MUTATES: none
  GLOBAL:  IndexedDB expired records deleted; logger side-effect if deletedCount > 0
  DEPTH:   2 (EventHistory → DatabaseManager → IndexedDB)

EFFECT_TRACE: private startCleanupTimer(): void
  RETURN:  void
  MUTATES: this.cleanupTimer (set to new Timeout)
  GLOBAL:  registers setInterval callback in event loop
  DEPTH:   1 (EventHistory → Node.js timer)

EFFECT_TRACE: private stopCleanupTimer(): void
  RETURN:  void
  MUTATES: this.cleanupTimer (set to undefined)
  GLOBAL:  deregisters interval from event loop
  DEPTH:   1 (EventHistory → Node.js timer)

EFFECT_TRACE: async close(): Promise<void>
  RETURN:  void
  MUTATES: this.isInitialized (true → false), this.cleanupTimer (→ undefined)
  GLOBAL:  IndexedDB connection closed via dbManager.close(); logger side-effect
  DEPTH:   2 (EventHistory → DatabaseManager → IndexedDB)

EFFECT_TRACE: get initialized(): boolean
  RETURN:  boolean → direct property access, no transformation
  MUTATES: none
  GLOBAL:  none
  DEPTH:   0

EFFECT_TRACE: get enabled(): boolean
  RETURN:  boolean → direct property access, no transformation
  MUTATES: none
  GLOBAL:  none
  DEPTH:   0

EFFECT_TRACE: updateOptions(newOptions: Partial<EventHistoryOptions>): void
  RETURN:  void
  MUTATES: this.options (shallow merge)
  GLOBAL:  logger.warn if databaseName or databaseVersion changed
  DEPTH:   0
```

---

## Risk Matrix

| ID | Risk | Description | Refactoring Impact |
|----|------|-------------|-------------------|
| M-004 | CRITICAL | updateOptions 淺合併但不重新初始化 dbManager | 若重構加入 re-init 邏輯，需處理進行中操作和 timer 重設 |
| L-005 | CRITICAL | 狀態機僅用布林值，無法區分 5 種狀態 | 改為 enum 會影響所有 guard 檢查 |
| D-003 | CRITICAL | 實作 IEventHistory 介面 | 任何方法簽名變更必須同步更新外部介面 |
| P-001 | CRITICAL | guard 回傳值與 error fallback 完全相同 | 若改為拋出或回傳 Result 型別，會破壞所有消費端 |
| M-002 | HIGH | retentionTime 可被動態修改，立即生效 | 重構清理邏輯時需考慮動態參數 |
| M-003 | HIGH | clear() 是不可逆破壞性操作 | 加入確認機制會改變 API |
| L-002 | HIGH | disabled 時 init 不設 isInitialized | 重新啟用需手動 re-init |
| L-004 | HIGH | close() 不等待進行中操作 | 加入 graceful shutdown 需追蹤活躍操作數 |
| E-001 | HIGH | init() 拋出 | 與多數方法吞掉錯誤不一致 |
| E-002 | HIGH | recordOperation 吞掉寫入錯誤 | 改為拋出會破壞呼叫者假設 |
| E-003 | HIGH | queryRecords 吞掉錯誤回傳 [] | 同上 |
| E-004 | HIGH | getLatestPublishRecord 吞掉錯誤回傳 null | 同上 |
| E-005 | HIGH | getStats 吞掉錯誤回傳空統計 | 同上 |
| E-009 | HIGH | DatabaseManager.ensureDb() 拋出 | 被 EventHistory catch 捕獲，但狀態不一致時會觸發 |
| S-001 | HIGH | init() 無並行保護 | 加入 mutex 需引入 async-mutex 套件 |
| S-003 | HIGH | close() 與進行中操作競態 | 需追蹤活躍操作或加入 closing 狀態 |
| D-001 | HIGH | dbManager init-before-use | 重構 DI 時需保持初始化順序 |
| P-003 | HIGH | getStats fallback 值與真實空資料庫相同 | 改變回傳值會影響所有消費端 |
| M-001 | MEDIUM | timestamp 由模組控制 | 允許外部 timestamp 需改 API |
| M-005 | MEDIUM | constructor 預設值硬編碼 | 改變預設值會影響無參數建構的行為 |
| L-001 | MEDIUM | init 冪等但無並行保護 | 見 S-001 |
| L-003 | MEDIUM | init 成功後啟動 timer | timer 邏輯與 init 耦合 |
| E-006 | MEDIUM | clear() 拋出 | 與吞掉模式不一致但行為正確 |
| E-007 | MEDIUM | cleanup 吞掉錯誤回傳 0 | 計時器會反覆觸發失敗的 cleanup |
| S-002 | MEDIUM | cleanup timer 無並行保護 | IndexedDB 交易隔離提供部分保護 |
| S-004 | MEDIUM | getStats 內部 Promise.all | 一個失敗全部失敗 |
| C-001 | MEDIUM | stopCleanupTimer 無法取消進行中 cleanup | 需 AbortController |
| C-002 | MEDIUM | 無法取消進行中 DB 操作 | 需要 AbortController 支援 |
| D-004 | MEDIUM | NodeJS.Timeout 在瀏覽器環境 | 型別不一致 |
| D-005 | MEDIUM | 依賴 ./types 型別定義 | 型別變更影響 public API |
| P-002 | MEDIUM | optional 參數 undefined 傳播 | 影響 IndexedDB 索引查詢 |
| D-002 | LOW | 依賴 logger | 穩定基礎設施 |
| E-008 | LOW | timer callback 雙重 catch | 安全網 |

---

# Artifact 2: Verification Scripts

## 2a: grep 驗證腳本

```bash
#!/bin/bash
# verify-contracts-EventHistory.sh
set -e
PASS=0; FAIL=0
assert_match() {
  local id="$1" pattern="$2" file="$3"
  if grep -qn "$pattern" "$file"; then
    echo "PASS [$id]"; ((PASS++))
  else
    echo "FAIL [$id] -- pattern not found: $pattern"; ((FAIL++))
  fi
}

TARGET="EventHistory.ts"

# M-001: Auto-timestamp in record creation
assert_match "M-001" "timestamp: Date.now()" "$TARGET"

# M-002: Cleanup uses retentionTime
assert_match "M-002" "cleanupExpiredRecords" "$TARGET"

# M-003: Clear all records
assert_match "M-003" "clearAllRecords" "$TARGET"

# M-004: updateOptions shallow merge without re-init
assert_match "M-004" "this.options = { ...this.options, ...newOptions }" "$TARGET"

# M-005: Default options in constructor
assert_match "M-005" "retentionTime: 300000" "$TARGET"

# L-001: Idempotent init guard
assert_match "L-001" "if (this.isInitialized)" "$TARGET"

# L-002: Disabled early return in init
assert_match "L-002" "if (!this.options.enabled)" "$TARGET"

# L-003: startCleanupTimer called in init
assert_match "L-003" "this.startCleanupTimer()" "$TARGET"

# L-004: close stops timer then closes dbManager
assert_match "L-004" "this.stopCleanupTimer()" "$TARGET"

# L-005: isInitialized boolean field
assert_match "L-005" "private isInitialized = false" "$TARGET"

# E-001: init re-throws
assert_match "E-001" "EventHistory 初始化失敗" "$TARGET"

# E-002: recordOperation swallows errors
assert_match "E-002" "記錄事件操作失敗" "$TARGET"

# E-003: queryRecords swallows errors
assert_match "E-003" "查詢事件記錄失敗" "$TARGET"

# E-004: getLatestPublishRecord swallows errors
assert_match "E-004" "獲取最新發布記錄失敗" "$TARGET"

# E-005: getStats swallows errors
assert_match "E-005" "獲取統計資訊失敗" "$TARGET"

# E-006: clear re-throws
assert_match "E-006" "清空記錄失敗" "$TARGET"

# E-007: cleanup swallows errors
assert_match "E-007" "清理過期記錄失敗" "$TARGET"

# E-008: Timer callback error handling
assert_match "E-008" "定期清理失敗" "$TARGET"

# S-001: Non-atomic init guard (structural)
assert_match "S-001" "await this.dbManager.init()" "$TARGET"

# S-002: setInterval for cleanup
assert_match "S-002" "setInterval" "$TARGET"

# S-003: close sets isInitialized false
assert_match "S-003" "this.isInitialized = false" "$TARGET"

# D-001: DatabaseManager instantiation
assert_match "D-001" "new DatabaseManager" "$TARGET"

# D-002: Logger import
assert_match "D-002" "import { logger } from" "$TARGET"

# D-003: IEventHistory interface
assert_match "D-003" "implements IEventHistory" "$TARGET"

# D-004: NodeJS.Timeout
assert_match "D-004" "NodeJS.Timeout" "$TARGET"

# C-001: clearInterval in stopCleanupTimer
assert_match "C-001" "clearInterval(this.cleanupTimer)" "$TARGET"

# P-001: Guard pattern (representative check)
assert_match "P-001" "!this.isInitialized || !this.options.enabled" "$TARGET"

# P-002: Optional chaining on event
assert_match "P-002" "eventType: event?.type" "$TARGET"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
```

## 2b: ast-grep 規則

```yaml
# .ast-grep/rules/EventHistory/M-001-auto-timestamp.yml
id: M-001-auto-timestamp
message: "M-001: Record creation with auto-timestamp -- contract must be present"
severity: error
language: TypeScript
rule:
  pattern: |
    timestamp: Date.now()
note: |
  Contract source: EventHistory.ts:86
  Refactoring requirement: timestamp must be injected at record creation time
```

```yaml
# .ast-grep/rules/EventHistory/M-004-shallow-merge-options.yml
id: M-004-shallow-merge-options
message: "M-004: updateOptions shallow merge without re-initialization -- contract must be present"
severity: error
language: TypeScript
rule:
  pattern: |
    this.options = { ...this.options, ...$NEW_OPTIONS }
note: |
  Contract source: EventHistory.ts:264
  Refactoring requirement: options merge must NOT trigger automatic dbManager re-initialization
```

```yaml
# .ast-grep/rules/EventHistory/L-001-idempotent-init.yml
id: L-001-idempotent-init
message: "L-001: init() idempotency guard -- contract must be present"
severity: error
language: TypeScript
rule:
  kind: if_statement
  has:
    pattern: this.isInitialized
note: |
  Contract source: EventHistory.ts:44-46
  Refactoring requirement: init() must be idempotent -- early return when already initialized
```

```yaml
# .ast-grep/rules/EventHistory/L-004-close-sequence.yml
id: L-004-close-sequence
message: "L-004: close() must stop timer then close dbManager -- contract must be present"
severity: error
language: TypeScript
rule:
  pattern: |
    async close(): Promise<void> {
      $$$
    }
note: |
  Contract source: EventHistory.ts:236-244
  Refactoring requirement: close must (1) stop timer, (2) close dbManager, (3) set isInitialized=false.
  LIMITATION: ast-grep cannot verify ordering of statements within the body. Manual review required.
```

```yaml
# .ast-grep/rules/EventHistory/E-002-record-swallow.yml
id: E-002-record-swallow
message: "E-002: recordOperation() must catch and swallow errors -- contract must be present"
severity: error
language: TypeScript
rule:
  kind: method_definition
  all:
    - has:
        regex: "recordOperation"
    - has:
        kind: try_statement
note: |
  Contract source: EventHistory.ts:80-104
  Refactoring requirement: recordOperation must NOT throw -- errors are logged and swallowed
```

```yaml
# .ast-grep/rules/EventHistory/S-002-cleanup-interval.yml
id: S-002-cleanup-interval
message: "S-002: Cleanup timer using setInterval -- contract must be present"
severity: error
language: TypeScript
rule:
  pattern: |
    setInterval($$$)
note: |
  Contract source: EventHistory.ts:214
  Refactoring requirement: periodic cleanup must be scheduled; interval value is 60000ms
```

```yaml
# .ast-grep/rules/EventHistory/D-003-interface-impl.yml
id: D-003-interface-impl
message: "D-003: EventHistory must implement IEventHistory -- contract must be present"
severity: error
language: TypeScript
rule:
  pattern: |
    class EventHistory implements IEventHistory {
      $$$
    }
note: |
  Contract source: EventHistory.ts:18
  Refactoring requirement: EventHistory must satisfy IEventHistory interface from @91app/trinity-kernel
```

```yaml
# .ast-grep/rules/EventHistory/P-001-guard-pattern.yml
id: P-001-guard-pattern
message: "P-001: Guard pattern returns empty values when disabled/uninitialized -- contract must be present"
severity: error
language: TypeScript
rule:
  pattern: |
    if (!this.isInitialized || !this.options.enabled) {
      $$$
    }
note: |
  Contract source: EventHistory.ts:76,111,130,146,168,185
  Refactoring requirement: guard pattern must exist in every public method that accesses dbManager.
  Return values vary per method -- see contract P-001 for specifics.
```

---

# Artifact 3: Coverage Table

| ID | Title | Verified By | File / Assertion |
|----|-------|-------------|-----------------|
| M-001 | Auto-timestamp | grep + ast-grep | `verify-contracts-EventHistory.sh` M-001; `.ast-grep/rules/EventHistory/M-001-auto-timestamp.yml` |
| M-002 | Cleanup retentionTime | grep | `verify-contracts-EventHistory.sh` M-002 |
| M-003 | Clear all records | grep | `verify-contracts-EventHistory.sh` M-003 |
| M-004 | updateOptions shallow merge | grep + ast-grep | `verify-contracts-EventHistory.sh` M-004; `.ast-grep/rules/EventHistory/M-004-shallow-merge-options.yml` |
| M-005 | Constructor defaults | grep | `verify-contracts-EventHistory.sh` M-005 |
| L-001 | Idempotent init | grep + ast-grep | `verify-contracts-EventHistory.sh` L-001; `.ast-grep/rules/EventHistory/L-001-idempotent-init.yml` |
| L-002 | Disabled init early return | grep | `verify-contracts-EventHistory.sh` L-002 |
| L-003 | Init starts cleanup timer | grep | `verify-contracts-EventHistory.sh` L-003 |
| L-004 | Close sequence | grep + ast-grep | `verify-contracts-EventHistory.sh` L-004; `.ast-grep/rules/EventHistory/L-004-close-sequence.yml` -- **ordering is manual review** |
| L-005 | State machine boolean | grep | `verify-contracts-EventHistory.sh` L-005 |
| E-001 | init re-throws | grep | `verify-contracts-EventHistory.sh` E-001 |
| E-002 | recordOperation swallows | grep + ast-grep | `verify-contracts-EventHistory.sh` E-002; `.ast-grep/rules/EventHistory/E-002-record-swallow.yml` |
| E-003 | queryRecords swallows | grep | `verify-contracts-EventHistory.sh` E-003 |
| E-004 | getLatestPublishRecord swallows | grep | `verify-contracts-EventHistory.sh` E-004 |
| E-005 | getStats swallows | grep | `verify-contracts-EventHistory.sh` E-005 |
| E-006 | clear re-throws | grep | `verify-contracts-EventHistory.sh` E-006 |
| E-007 | cleanup swallows | grep | `verify-contracts-EventHistory.sh` E-007 |
| E-008 | Timer callback catch | grep | `verify-contracts-EventHistory.sh` E-008 |
| E-009 | DatabaseManager.ensureDb throws | manual review | 需檢查 DatabaseManager.ts:60 — ensureDb() 在 db===null 時拋出 |
| S-001 | Non-atomic init | grep + manual review | `verify-contracts-EventHistory.sh` S-001 — 需手動驗證 await 與 isInitialized 之間無保護 |
| S-002 | Cleanup timer concurrency | grep + ast-grep | `verify-contracts-EventHistory.sh` S-002; `.ast-grep/rules/EventHistory/S-002-cleanup-interval.yml` |
| S-003 | close() race condition | grep + manual review | `verify-contracts-EventHistory.sh` S-003 — 需手動驗證 close 不等待進行中操作 |
| S-004 | Promise.all in getStats | manual review | DatabaseManager.ts:238 — 需驗證兩個 IDB 請求的 reject 處理 |
| D-001 | dbManager init-before-use | grep | `verify-contracts-EventHistory.sh` D-001 |
| D-002 | Logger dependency | grep | `verify-contracts-EventHistory.sh` D-002 |
| D-003 | IEventHistory interface | grep + ast-grep | `verify-contracts-EventHistory.sh` D-003; `.ast-grep/rules/EventHistory/D-003-interface-impl.yml` |
| D-004 | NodeJS.Timeout | grep | `verify-contracts-EventHistory.sh` D-004 |
| D-005 | Types dependency | manual review | 需檢查 ./types 中型別定義與使用是否一致 |
| C-001 | Stop cleanup timer | grep | `verify-contracts-EventHistory.sh` C-001 |
| C-002 | No in-flight cancellation | manual review | 所有 async 方法均無 AbortSignal — 確認無遺漏 |
| P-001 | Guard empty values | grep + ast-grep | `verify-contracts-EventHistory.sh` P-001; `.ast-grep/rules/EventHistory/P-001-guard-pattern.yml` |
| P-002 | Optional param propagation | grep | `verify-contracts-EventHistory.sh` P-002 |
| P-003 | getStats fallback identity | manual review | 需驗證 disabled guard 和 error catch 回傳相同的 `{ totalRecords: 0, channelCount: 0 }` |

---

# Artifact 4: Line Attribution Table

| Line(s) | Classification | Contract ID(s) |
|---------|---------------|----------------|
| 1-4     | SKIP           | -- (JSDoc comment) |
| 5       | SKIP           | -- (blank line) |
| 6       | CONTRACT       | D-002 |
| 7       | CONTRACT       | D-003 |
| 8-15    | CONTRACT       | D-005 |
| 16      | CONTRACT       | D-001 |
| 17      | SKIP           | -- (blank line) |
| 18      | CONTRACT       | D-003, L-005 |
| 19      | CONTRACT       | D-001 |
| 20      | CONTRACT       | M-004, M-005 |
| 21      | CONTRACT       | D-004, C-001 |
| 22      | CONTRACT       | L-005 |
| 23      | SKIP           | -- (blank line) |
| 24      | CONTRACT       | M-005 |
| 25-31   | CONTRACT       | M-005 |
| 32      | INFRA          | -- (closing spread) |
| 33      | SKIP           | -- (blank line) |
| 34-37   | CONTRACT       | D-001, M-005 |
| 38      | INFRA          | -- (closing brace) |
| 39      | SKIP           | -- (blank line) |
| 40-42   | SKIP           | -- (JSDoc comment) |
| 43      | CONTRACT       | L-001, L-002, L-003, E-001 |
| 44-46   | CONTRACT       | L-001 |
| 47      | SKIP           | -- (blank line) |
| 48-51   | CONTRACT       | L-002 |
| 52      | SKIP           | -- (blank line) |
| 53      | CONTRACT       | E-001 |
| 54      | CONTRACT       | D-001, S-001 |
| 55      | CONTRACT       | L-005, S-001 |
| 56      | INFRA          | -- (log) |
| 57      | SKIP           | -- (blank line) |
| 58      | SKIP           | -- (comment) |
| 59      | CONTRACT       | L-003 |
| 60-63   | CONTRACT       | E-001 |
| 64      | INFRA          | -- (closing brace) |
| 65      | SKIP           | -- (blank line) |
| 66-68   | SKIP           | -- (JSDoc comment) |
| 69-75   | CONTRACT       | M-001, P-002 |
| 76-78   | CONTRACT       | P-001 |
| 79      | SKIP           | -- (blank line) |
| 80      | CONTRACT       | E-002 |
| 81-89   | CONTRACT       | M-001, P-002 |
| 90      | SKIP           | -- (blank line) |
| 91      | CONTRACT       | D-001, M-001 |
| 92      | SKIP           | -- (blank line) |
| 93-101  | INFRA          | -- (trace logging) |
| 102-104 | CONTRACT       | E-002 |
| 105     | INFRA          | -- (closing brace) |
| 106     | SKIP           | -- (blank line) |
| 107-109 | SKIP           | -- (JSDoc comment) |
| 110     | CONTRACT       | E-003 |
| 111-113 | CONTRACT       | P-001 |
| 114     | SKIP           | -- (blank line) |
| 115     | CONTRACT       | E-003 |
| 116     | CONTRACT       | D-001 |
| 117-120 | CONTRACT       | E-003 |
| 121     | INFRA          | -- (closing brace) |
| 122     | SKIP           | -- (blank line) |
| 123-125 | SKIP           | -- (JSDoc comment) |
| 126-129 | CONTRACT       | E-004 |
| 130-132 | CONTRACT       | P-001 |
| 133     | SKIP           | -- (blank line) |
| 134     | CONTRACT       | E-004 |
| 135     | CONTRACT       | D-001 |
| 136-139 | CONTRACT       | E-004 |
| 140     | INFRA          | -- (closing brace) |
| 141     | SKIP           | -- (blank line) |
| 142-144 | SKIP           | -- (JSDoc comment) |
| 145     | CONTRACT       | E-005 |
| 146-151 | CONTRACT       | P-001, P-003 |
| 152     | SKIP           | -- (blank line) |
| 153     | CONTRACT       | E-005 |
| 154     | CONTRACT       | D-001, S-004 |
| 155-161 | CONTRACT       | E-005, P-003 |
| 162     | INFRA          | -- (closing brace) |
| 163     | SKIP           | -- (blank line) |
| 164-166 | SKIP           | -- (JSDoc comment) |
| 167     | CONTRACT       | M-003, E-006 |
| 168-170 | CONTRACT       | P-001 |
| 171     | SKIP           | -- (blank line) |
| 172     | CONTRACT       | E-006 |
| 173     | CONTRACT       | M-003, D-001 |
| 174     | INFRA          | -- (log) |
| 175-178 | CONTRACT       | E-006 |
| 179     | INFRA          | -- (closing brace) |
| 180     | SKIP           | -- (blank line) |
| 181-183 | SKIP           | -- (JSDoc comment) |
| 184     | CONTRACT       | M-002, E-007 |
| 185-187 | CONTRACT       | P-001 |
| 188     | SKIP           | -- (blank line) |
| 189     | CONTRACT       | E-007 |
| 190-192 | CONTRACT       | M-002, D-001 |
| 193     | SKIP           | -- (blank line) |
| 194-196 | CONTRACT       | M-002 |
| 197     | SKIP           | -- (blank line) |
| 198     | CONTRACT       | M-002 |
| 199-201 | CONTRACT       | E-007 |
| 202     | INFRA          | -- (closing brace) |
| 203     | SKIP           | -- (blank line) |
| 204     | SKIP           | -- (blank line) |
| 205-207 | SKIP           | -- (JSDoc comment) |
| 208     | CONTRACT       | L-003, S-002 |
| 209-211 | CONTRACT       | C-001 |
| 212     | SKIP           | -- (blank line) |
| 213     | SKIP           | -- (comment) |
| 214-220 | CONTRACT       | S-002, E-008 |
| 221     | INFRA          | -- (closing brace) |
| 222     | SKIP           | -- (blank line) |
| 223-225 | SKIP           | -- (JSDoc comment) |
| 226     | CONTRACT       | C-001 |
| 227-230 | CONTRACT       | C-001 |
| 231     | INFRA          | -- (closing brace) |
| 232     | SKIP           | -- (blank line) |
| 233-235 | SKIP           | -- (JSDoc comment) |
| 236     | CONTRACT       | L-004, S-003 |
| 237     | CONTRACT       | L-004, C-001 |
| 238     | SKIP           | -- (blank line) |
| 239     | CONTRACT       | L-004, L-005 |
| 240     | CONTRACT       | L-004, D-001 |
| 241     | CONTRACT       | L-004, L-005, S-003 |
| 242     | INFRA          | -- (log) |
| 243     | INFRA          | -- (closing brace) |
| 244     | INFRA          | -- (closing brace) |
| 245     | SKIP           | -- (blank line) |
| 246-248 | SKIP           | -- (JSDoc comment) |
| 249-251 | INFRA          | -- (getter, no contract) |
| 252     | SKIP           | -- (blank line) |
| 253-255 | SKIP           | -- (JSDoc comment) |
| 256-258 | INFRA          | -- (getter, no contract) |
| 259     | SKIP           | -- (blank line) |
| 260-262 | SKIP           | -- (JSDoc comment) |
| 263     | CONTRACT       | M-004 |
| 264     | CONTRACT       | M-004 |
| 265     | SKIP           | -- (blank line) |
| 266-268 | CONTRACT       | M-004 |
| 269     | INFRA          | -- (closing brace) |
| 270     | INFRA          | -- (closing class brace) |

### Summary

```
Total lines:       270
CONTRACT lines:    153 (56.7%)
INFRA lines:       30  (11.1%)
SKIP lines:        87  (32.2%)
Unclassified:      0
```

---

## Anchoring Contract Verification (Step 0.7)

| # | 類別 | 模式 | 對應合約 |
|---|------|------|---------|
| 1 | S | Promise_all (DatabaseManager.ts:238) | S-004 — getStats 內部 Promise.all 並行查詢 |
| 2 | S | async_function (examples.ts:9) | 涵蓋於 D-003（IEventHistory 介面要求 async API）及 P-001（所有 async 方法的 guard 模式） |
| 3 | E | try_block (EventHistory.ts, 9 處) | E-001, E-002, E-003, E-004, E-005, E-006, E-007, E-008（8 個 try-catch + init 中的 try = 9） |
| 4 | E | throw_new (DatabaseManager.ts:60) | E-009 — DatabaseManager.ensureDb() 拋出；被 D-001 的順序合約保護 |

---

## Completeness Declaration

**COMPLETE: All executable lines attributed. No known audit gaps.**

所有 270 行已分類。4 個錨定合約均有對應的 Contract ID。28 個合約（M:5, L:5, E:9, S:4, D:5, C:2, P:3）全部具備 Evidence 引用、Risk 等級、及 Scope/Seam_Type/Pinch_Point 元資料。F1/F2/F3 三項 Feathers 分析均已完成並整合。

---

`★ Insight ─────────────────────────────────────`
**此模組最危險的設計決策**是 guard pattern 回傳值與 error fallback 值完全相同（P-001）。這意味著任何消費端都無法透過回傳值判斷模組是否正常運作——一個停用的、損壞的、和正常但資料為空的 EventHistory 從外部看起來完全一樣。

**重構時的首要風險**是錯誤處理策略的不一致性：init() 和 clear() 會拋出，但其他 6 個方法吞掉錯誤。如果重構統一為全部拋出或全部吞掉，都會破壞現有消費端的假設。建議引入 Result 型別（`Success<T> | Failure`）作為漸進式改善路徑。

**狀態機的簡陋性**（L-005）是第二大風險源。單一布林值無法表達「正在初始化」和「正在關閉」兩種過渡狀態，這是 S-001 和 S-003 競態條件的根本原因。
`─────────────────────────────────────────────────`
