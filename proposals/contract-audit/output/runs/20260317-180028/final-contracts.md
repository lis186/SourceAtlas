# Final Contract Spec
# Generated: 2026-03-17
# Auditor artifacts: claude-artifacts/ (inline in conversation)
# Adversary review: codex-review.md
# DEGRADED: no

---

## Module: EventHistory.ts (~270 lines)

### Category M — Mutation Contracts

---

M-001: 記錄建立時自動注入 timestamp

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

---

M-002: 清理過期記錄基於 retentionTime

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

---

M-003: clear() 刪除所有記錄

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

---

M-004: updateOptions() 淺合併但不重新初始化

```
Trigger:      呼叫 updateOptions()
Input:        Partial<EventHistoryOptions>
Output:       this.options 被淺合併更新；若包含 databaseName 或 databaseVersion 僅記錄 warn
Condition:    無——即使未初始化也可呼叫
Ordering:     合併立即生效，但 dbManager 不會更新
Risk:         CRITICAL -- 修改 databaseName/databaseVersion 後 dbManager 仍指向舊資料庫，造成 options 與實際行為不一致。修改 retentionTime 立即生效於下次 cleanup，可能意外改變資料保留策略。修改 enabled 為 false 後所有操作靜默停止但 cleanup timer 仍在運行
Evidence:     EventHistory.ts:263-268 -- `this.options = { ...this.options, ...newOptions }`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

> [META_ISSUE resolved] Scope changed from `class` to `method` per Adversary feedback — contract behavior is method-local to `updateOptions()`, even though its effect is class-wide.

---

M-005: constructor 建立 DatabaseManager 實例並設定預設 options

```
Trigger:      new EventHistory(options?)
Input:        EventHistoryOptions（全部 optional，有預設值）
Output:       建立新的 DatabaseManager 實例（尚未初始化）；options 被合併為 Required<EventHistoryOptions>
Condition:    無
Ordering:     constructor 完成後，其他 public 方法可呼叫但在 init() 前均為 no-op（透過 guard 回傳空值）
Risk:         MEDIUM -- 預設值是硬編碼的隱含合約：retentionTime=300000, maxRecords=1000, enabled=true, databaseName='EventHistory', databaseVersion=1
Evidence:     EventHistory.ts:24-38 -- `constructor(options: EventHistoryOptions = {}) { ... this.dbManager = new DatabaseManager(...) }`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

> [DISPUTED -- accepted] Ordering updated per Adversary evidence (EventHistory.ts:76): public methods are callable pre-init but no-op via guards, not inaccessible.

---

### Category L — Lifecycle / State Machine Contracts

---

L-001: init() 冪等——已初始化時直接 return

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

---

L-002: init() 在 disabled 時提前返回，不設定 isInitialized

```
Trigger:      呼叫 init() 且 options.enabled === false
Input:        this.options.enabled
Output:       logger.info 記錄停用訊息；isInitialized 保持 false
Condition:    this.options.enabled === false（且 isInitialized === false）
Ordering:     在 isInitialized 檢查之後、dbManager.init() 之前
Risk:         HIGH -- disabled 的 EventHistory 永遠不會被初始化，所有後續操作靜默回傳空值。若之後透過 updateOptions() 將 enabled 改為 true，仍然不會自動初始化（isInitialized 仍為 false），必須重新呼叫 init()
Evidence:     EventHistory.ts:48-51 -- `if (!this.options.enabled) { logger.info('EventHistory 已停用'); return }`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

> [META_ISSUE resolved] Scope changed from `class` to `method` per Adversary feedback — behavior is specific to `init()`.

---

L-003: init 成功後啟動 cleanup timer

```
Trigger:      dbManager.init() 成功完成
Input:        無
Output:       啟動 setInterval（60000ms），定期呼叫 this.cleanup()
Condition:    init() 路徑中 try 區塊成功執行
Ordering:     在 isInitialized = true 和 logger.info 之後
Risk:         LOW -- timer 生命週期有明確的 teardown 機制（close() 呼叫 stopCleanupTimer()），GC 阻止風險已被緩解
Evidence:     EventHistory.ts:59 -- `this.startCleanupTimer()`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

> [DISPUTED -- accepted] Risk downgraded from MEDIUM to LOW per Adversary evidence (EventHistory.ts:237): explicit teardown via `stopCleanupTimer()` mitigates GC concern.
> [META_ISSUE resolved] Scope changed from `class` to `method`.

---

L-004: close() 先停 timer 再關閉 dbManager 並重設 isInitialized

```
Trigger:      呼叫 close()
Input:        無
Output:       停止 cleanup timer → 關閉 dbManager → isInitialized = false → 記錄 log
Condition:    isInitialized === true 時執行 dbManager.close()；isInitialized === false 時僅停止 timer
Ordering:     1. stopCleanupTimer() → 2. dbManager.close() → 3. isInitialized = false
Risk:         HIGH -- close() 不是 async-safe：停止 timer 後若有已排程但尚未完成的 cleanup 仍在執行，dbManager.close() 會在 cleanup 完成前關閉資料庫。另外 dbManager.close() 是同步呼叫，但 close() 本身是 async——這暗示未來可能有非同步清理需求
Evidence:     EventHistory.ts:236-244 -- `async close(): Promise<void> { this.stopCleanupTimer(); if (this.isInitialized) { this.dbManager.close(); this.isInitialized = false; ... } }`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

> [META_ISSUE resolved] Scope changed from `class` to `method` per Adversary feedback.

---

L-005: 狀態機：未初始化 → 已初始化 → 已關閉

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

> [DISPUTED -- evidence inconclusive] Adversary notes closed/uninitialized both map to `false` (EventHistory.ts:22), which is precisely the limitation this contract identifies. The contract documents the SHOULD-BE states vs the IS implementation gap.

---

### Category N — Notification Contracts

---

N-001: updateOptions() 對敏感 DB 參數變更發出警告

```
Trigger:      呼叫 updateOptions() 且 newOptions 包含 databaseName 或 databaseVersion
Input:        newOptions.databaseName 或 newOptions.databaseVersion
Output:       logger.warn 記錄「資料庫名稱或版本變更需要重新初始化」
Condition:    newOptions 包含 databaseName 或 databaseVersion 鍵
Ordering:     在 options 淺合併之後
Risk:         MEDIUM -- 僅發出警告但不阻止變更或自動重新初始化，呼叫者可能忽略警告導致 M-004 的 options/dbManager 不一致問題
Evidence:     EventHistory.ts:266-268 -- `logger.warn('資料庫名稱或版本變更需要重新初始化')`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

> [ADD from Adversary review] Valid evidence with filename:line. Complements M-004.

---

### Category E — Error Handling Contracts

---

E-001: init() 重新拋出錯誤

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

---

E-002: recordOperation() 吞掉所有錯誤

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

---

E-003: queryRecords() 吞掉錯誤並回傳空陣列

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

---

E-004: getLatestPublishRecord() 吞掉錯誤並回傳 null

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

---

E-005: getStats() 吞掉錯誤並回傳空統計

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

---

E-006: clear() 重新拋出錯誤

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

---

E-007: cleanup() 吞掉錯誤並回傳 0

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

---

E-008: startCleanupTimer 的 callback 吞掉 cleanup 錯誤

```
Trigger:      計時器 callback 中 this.cleanup() 拋出錯誤
Input:        任何 cleanup() 的例外（理論上 cleanup 本身已吞掉，見 E-007）
Output:       logger.error 記錄
Condition:    setInterval callback 中的 try-catch
Ordering:     log 後繼續——計時器不會停止
Risk:         LOW -- 防禦性雙重 catch：cleanup() 已在 E-007 中吞掉錯誤，此處在正常流程中不可達。僅作為未來重構安全網（若 cleanup 被改為拋出）
Evidence:     EventHistory.ts:214-220 -- `setInterval(async () => { try { await this.cleanup() } catch (error) { logger.error({ error }, '定期清理失敗') } }, 60000)`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

> [DISPUTED -- accepted] Risk downgraded from LOW (unchanged) and description updated to note defensive/unreachable nature per Adversary evidence (EventHistory.ts:199-201).

---

E-009: DatabaseManager.ensureDb() 拋出錯誤（跨模組）

```
Trigger:      任何 dbManager 方法在 db 為 null 時被呼叫
Input:        DatabaseManager 內部 this.db === null
Output:       throw new Error（基於 DatabaseManager.ts:60 的 throw_new 錨點）
Condition:    dbManager.init() 未呼叫或失敗
Ordering:     在任何 IDB 交易之前
Risk:         MEDIUM -- EventHistory 的 guard 模式（P-001）在正常流程中阻止此路徑被觸發。僅在並行競態條件下（S-001, S-003）可能繞過 guard 觸發此錯誤，屆時被各方法的 catch 區塊捕獲
Evidence:     DatabaseManager.ts:60 -- throw_new 錨點
Scope:        module
Seam_Type:    object
Pinch_Point:  true
```

> [DISPUTED -- accepted] Risk downgraded from HIGH to MEDIUM per Adversary evidence (EventHistory.ts:111): module guards prevent uninitialized calls under normal flow; only race conditions bypass guards.

---

### Category S — Synchronization Contracts

---

S-001: init() 無並行保護——可能重複初始化

```
Trigger:      多個呼叫者同時呼叫 init()
Input:        isInitialized 旗標（非原子性檢查）
Output:       可能執行多次 dbManager.init()，多次設定 isInitialized = true，多次啟動 timer
Condition:    兩個 init() 呼叫在 await dbManager.init() 之前都通過了 isInitialized 檢查
Ordering:     第一個 await 讓出控制權後，第二個呼叫可以進入 try 區塊
Risk:         HIGH -- 重複 dbManager.init() 可能導致資料庫連線異常；重複 startCleanupTimer() 會清除前一個 timer 再建新的（因為 startCleanupTimer 本身有保護），但中間有短暫的 timer 空窗期
Evidence:     EventHistory.ts:44-63 -- `if (this.isInitialized) { return } ... await this.dbManager.init() ... this.isInitialized = true`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

> [META_ISSUE resolved] Scope changed from `class` to `method` per Adversary feedback — race is specific to `init()`.

---

S-002: cleanup timer 與其他操作並行執行

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

---

S-003: close() 與進行中操作的競態條件

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

> [DISPUTED -- evidence inconclusive] Adversary claims race is overstated because "db call is invoked before await suspension" (EventHistory.ts:91), but `await this.dbManager.addRecord(record)` IS an await suspension point where close() could interleave. Keeping Auditor's version.

---

S-004: DatabaseManager.getStats() 使用 Promise.all 並行查詢（錨定合約）

```
Trigger:      EventHistory.getStats() → dbManager.getStats()
Input:        兩個 IDB 請求（count + getAll）
Output:       兩個請求並行執行，都成功後回傳合併結果
Condition:    兩個 Promise 都必須 resolve 才能取得結果
Ordering:     Promise.all 保證兩者都完成後才 resolve；任一失敗則 reject
Risk:         MEDIUM -- 如果一個請求成功但另一個失敗，成功的結果被丟棄。EventHistory 的 E-005 會將整個失敗吞掉
Evidence:     DatabaseManager.ts:238 -- `Promise.all([ new Promise<number>(...), new Promise<EventHistoryRecord[]>(...) ])`
Scope:        module
Seam_Type:    object
Pinch_Point:  false
```

> [DISPUTED -- accepted] Removed "在同一個 readonly 交易中" claim per Adversary evidence: only `Promise.all` parallelism is directly evidenced, transaction semantics unconfirmed.

---

### Category D — Dependency Contracts

---

D-001: DatabaseManager 的 init-before-use 隱含順序

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

---

D-002: 依賴 @91app/shared-provider 的 logger

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

---

D-003: 實作 IEventHistory 介面（@91app/trinity-kernel）

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

---

D-004: 依賴 Node.js timer API（setInterval / clearInterval）

```
Trigger:      init() 成功後
Input:        setInterval / clearInterval 全域函式（runtime）；NodeJS.Timeout 型別（compile-time）
Output:       計時器 ID 存於 this.cleanupTimer
Condition:    型別層級依賴 @types/node（NodeJS.Timeout）；runtime 層級依賴全域 timer API（兩環境均可用）
Risk:         LOW -- setInterval/clearInterval 在瀏覽器和 Node.js 環境都可用。NodeJS.Timeout 是純型別註解依賴，不影響 runtime 行為
Evidence:     EventHistory.ts:21 -- `private cleanupTimer?: NodeJS.Timeout`；EventHistory.ts:214 -- `this.cleanupTimer = setInterval(...)`
Scope:        class
Seam_Type:    link
Pinch_Point:  false
```

> [DISPUTED -- accepted] Risk downgraded from MEDIUM to LOW per Adversary evidence: this is a type-level annotation dependency, not a runtime lifecycle dependency.
> [META_ISSUE resolved] Seam_Type changed from `preprocessing` to `link` — this is an import/type dependency seam.

---

D-005: 依賴 ./types 模組的型別定義

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

C-001: stopCleanupTimer 取消定期清理

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

---

C-002: 無法取消進行中的資料庫操作

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

> [DISPUTED -- evidence inconclusive] Adversary cites timer cancellation (EventHistory.ts:227) as existing cancellation mechanism, but this contract specifically addresses DATABASE operations, not timer scheduling. Timer cancellation is covered by C-001. Keeping Auditor's version.

---

### Category P — Propagation Contracts

---

P-001: guard 模式回傳不同的「空值」型別

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

---

P-002: recordOperation 將 optional 參數原封不動傳給 DatabaseManager

```
Trigger:      呼叫 recordOperation()
Input:        event?.type, event, from, targetEvent — 全部 optional
Output:       eventType 可能是 undefined（透過 event?.type）；event/from/targetEvent 可能是 undefined
Condition:    呼叫者未傳入 optional 參數
Ordering:     組裝 record 物件後立即傳給 dbManager.addRecord()
Risk:         LOW -- optional 參數以 undefined 傳播至 DatabaseManager 是 TypeScript 的正常行為。對 IndexedDB 索引的影響為推測性——無直接證據證明 undefined 欄位導致查詢問題
Evidence:     EventHistory.ts:81-89 -- `eventType: event?.type, event, ... from, targetEvent`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

> [DISPUTED -- accepted] Risk downgraded from MEDIUM to LOW per Adversary evidence: indexing/query impact is speculative, only raw optional propagation is evidenced.

---

P-003: getStats() 的 fallback 值與真實空資料庫相同

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

P-004: queryRecords 結果原封不動跨模組傳播

```
Trigger:      queryRecords(query) 成功完成
Input:        dbManager.queryRecords(query) 的回傳值
Output:       DatabaseManager 的查詢結果直接回傳給呼叫者，無任何轉換或過濾
Condition:    isInitialized === true && options.enabled === true && 查詢成功
Ordering:     await dbManager.queryRecords() → return result
Risk:         LOW -- 跨模組邊界的直接傳播意味著 DatabaseManager 的回傳格式直接決定 EventHistory 的 public API 回傳格式。若 DatabaseManager 內部改變查詢結果結構，會穿透至消費端
Evidence:     EventHistory.ts:116 -- `return await this.dbManager.queryRecords(query)`
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

> [ADD from Adversary review] Valid evidence with filename:line. Documents the passthrough propagation pattern.

---

## Risk Matrix (Post-Merge)

| ID | Risk | Pinch Point | Description |
|----|------|-------------|-------------|
| M-004 | CRITICAL | YES | updateOptions 淺合併但不重新初始化 dbManager |
| L-005 | CRITICAL | YES | 狀態機僅用布林值，無法區分 5 種狀態 |
| D-003 | CRITICAL | YES | 實作 IEventHistory 介面 |
| P-001 | CRITICAL | YES | guard 回傳值與 error fallback 完全相同 |
| M-002 | HIGH | YES | retentionTime 可被動態修改，立即生效 |
| M-003 | HIGH | -- | clear() 是不可逆破壞性操作 |
| L-002 | HIGH | YES | disabled 時 init 不設 isInitialized |
| L-004 | HIGH | YES | close() 不等待進行中操作 |
| E-001 | HIGH | -- | init() 拋出 |
| E-002 | HIGH | -- | recordOperation 吞掉寫入錯誤 |
| E-003 | HIGH | -- | queryRecords 吞掉錯誤回傳 [] |
| E-004 | HIGH | -- | getLatestPublishRecord 吞掉錯誤回傳 null |
| E-005 | HIGH | -- | getStats 吞掉錯誤回傳空統計 |
| S-001 | HIGH | YES | init() 無並行保護 |
| S-003 | HIGH | YES | close() 與進行中操作競態 |
| D-001 | HIGH | YES | dbManager init-before-use |
| P-003 | HIGH | -- | getStats fallback 值與真實空資料庫相同 |
| M-001 | MEDIUM | -- | timestamp 由模組控制 |
| M-005 | MEDIUM | YES | constructor 預設值硬編碼 |
| L-001 | MEDIUM | YES | init 冪等但無並行保護 |
| N-001 | MEDIUM | -- | 敏感 DB 參數變更僅警告不阻止 |
| E-006 | MEDIUM | -- | clear() 拋出（與吞掉模式不一致） |
| E-007 | MEDIUM | -- | cleanup 吞掉錯誤回傳 0 |
| E-009 | MEDIUM | YES | DatabaseManager.ensureDb 拋出（正常流程不可達） |
| S-002 | MEDIUM | -- | cleanup timer 無並行保護 |
| S-004 | MEDIUM | -- | getStats 內部 Promise.all |
| C-001 | MEDIUM | -- | stopCleanupTimer 無法取消進行中 cleanup |
| C-002 | MEDIUM | -- | 無法取消進行中 DB 操作 |
| D-005 | MEDIUM | -- | 依賴 ./types 型別定義 |
| L-003 | LOW | -- | init 成功後啟動 timer（有明確 teardown） |
| D-002 | LOW | -- | 依賴 logger |
| D-004 | LOW | -- | NodeJS.Timeout 型別註解依賴 |
| E-008 | LOW | -- | timer callback 防禦性雙重 catch |
| P-002 | LOW | -- | optional 參數 undefined 傳播 |
| P-004 | LOW | -- | queryRecords 結果跨模組直接傳播 |

---

## Merge Changelog

| Source | Action | Contract | Detail |
|--------|--------|----------|--------|
| CONFIRM | carry forward | M-001, M-002, M-003, M-004, L-001, L-002, L-004, E-001~E-007, S-001, S-002, D-001, D-002, D-003, D-005, C-001, P-001, P-003 | 23 contracts confirmed as-is |
| DISPUTE | accepted | M-005 | Updated Ordering: methods are callable pre-init (no-op via guards) |
| DISPUTE | accepted | L-003 | Risk downgraded MEDIUM→LOW; GC concern mitigated by explicit teardown |
| DISPUTE | inconclusive | L-005 | Kept Auditor's version; contract documents IS vs SHOULD-BE gap |
| DISPUTE | accepted | E-008 | Description updated: defensive/unreachable under normal flow |
| DISPUTE | accepted | E-009 | Risk downgraded HIGH→MEDIUM; guards prevent under normal flow |
| DISPUTE | inconclusive | S-003 | Kept Auditor's version; await IS the suspension point |
| DISPUTE | accepted | S-004 | Removed transaction semantics claim; kept Promise.all behavior |
| DISPUTE | accepted | D-004 | Risk downgraded MEDIUM→LOW; Seam_Type→link; clarified type-level |
| DISPUTE | inconclusive | C-002 | Kept Auditor's version; timer ≠ DB operation cancellation |
| DISPUTE | accepted | P-002 | Risk downgraded MEDIUM→LOW; indexing impact speculative |
| ADD | accepted | N-001 | New: updateOptions warning on DB param changes |
| ADD | accepted | P-004 | New: queryRecords passthrough propagation |
| META_ISSUE | accepted | M-004, L-002, L-003, L-004, S-001 | Scope changed class→method |
| META_ISSUE | accepted | D-004 | Seam_Type changed preprocessing→link |
