檔案不在磁碟上——所有原始碼已在 prompt 中提供。我將根據提供的內容進行完整合約稽核。

---

# Contract Audit: EventHistory Module

## 目標檔案

- **EventHistory.ts** （主要稽核對象，完整提供）
- **DatabaseManager.ts** （外部依賴，部分提供）
- **examples.ts** （使用範例/呼叫端，部分提供）

## 重構意圖

（未明確指定——依骨架要求，產出完整合約文件供未來重構使用）

---

# Artifact 1: Contract Spec Document

---

## F1: Tell the Story

```
STORY: 此模組是一個事件歷史記錄器，負責 (1) 將事件操作持久化到 IndexedDB、(2) 管理初始化/關閉生命週期、(3) 定期清理過期記錄。

LIES:
- 省略 1 — 錯誤吞沒策略：大多數 public 方法在 catch 中靜默回傳預設值（空陣列、0、null），呼叫端無法區分「無資料」與「操作失敗」。重構時若改變錯誤傳播行為，所有消費端的 fallback 假設都會被破壞。
- 省略 2 — enabled 旗標的雙重守衛：`isInitialized` 和 `options.enabled` 在每個 public 方法中同時檢查，但 `updateOptions` 可以在運行時關閉 `enabled` 而不觸發任何清理動作（計時器仍在跑）。這個不一致性被「簡單守衛」的外觀掩蓋。
- 省略 3 — DatabaseManager 是同步 close 但非同步 init：`close()` 中 `this.dbManager.close()` 是同步呼叫，但 `init()` 中 `this.dbManager.init()` 是非同步。重構時若假設對稱的 async/sync 行為會導致錯誤。
```

## F2: Scratch Refactoring

```
SCRATCH_REFACTORING:
1. 將守衛條件 `!this.isInitialized || !this.options.enabled` 提取為 private method `isActive()`
   REVEALS: M-001 至 M-006 的守衛合約實際上是同一個模式；但 `init()` 只檢查 `isInitialized`（不檢查 enabled 的 re-enable 情境），揭示 L-001 的初始化狀態機與 enabled 旗標之間的不一致。

2. 將 `startCleanupTimer` / `stopCleanupTimer` 提取為獨立的 CleanupScheduler 類別
   REVEALS: S-001（setInterval 的非同步 cleanup 在 timer callback 中執行，但沒有防止並發執行的機制）、C-001（stopCleanupTimer 不會取消正在執行的 cleanup）、L-002（timer 的生命週期與 EventHistory 的生命週期耦合）。

3. 將錯誤處理統一為 Result<T, Error> 模式取代 try/catch + 靜默 fallback
   REVEALS: E-001 至 E-008 的每一個 catch block 都有不同的 fallback 策略（有的 throw、有的回傳空值、有的回傳 0），這些差異是隱含合約。統一後會發現哪些呼叫端依賴特定的 fallback 值。
```

---

## 合約清單

### Category M — Mutation Contracts

```
M-001: recordOperation 寫入 IndexedDB 記錄

Trigger:      呼叫 recordOperation(operation, channel, event?, from?, targetEvent?)
Input:        operation (EventOperation), channel (string), event (EventPayload?), from (string?), targetEvent (string[]?)
Output:       一筆新的 EventHistoryRecord 被寫入 IndexedDB（透過 dbManager.addRecord）
Condition:    isInitialized === true && options.enabled === true
Ordering:     獨立操作，無相對順序要求
Risk:         MEDIUM — 靜默丟棄（守衛不通過時 return void，呼叫端無法得知記錄是否成功）
Evidence:     EventHistory.ts:76-100
Scope:        method
Seam_Type:    object (透過 dbManager interface)
Pinch_Point:  true (所有事件記錄都經過此方法)
```

```
M-002: recordOperation 組裝記錄結構

Trigger:      recordOperation 通過守衛條件後
Input:        方法參數 + Date.now() 作為 timestamp
Output:       組裝 Omit<EventHistoryRecord, 'id'> 物件，timestamp 使用呼叫時的 Date.now()
Condition:    同 M-001 守衛
Ordering:     在 dbManager.addRecord 之前
Risk:         LOW — timestamp 使用 Date.now() 而非可注入的時間源，測試難以控制
Evidence:     EventHistory.ts:80-88
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

```
M-003: clear 清空所有記錄

Trigger:      呼叫 clear()
Input:        無
Output:       dbManager.clearAllRecords() 被呼叫，所有 IndexedDB 記錄被刪除
Condition:    isInitialized === true && options.enabled === true
Ordering:     獨立操作
Risk:         HIGH — 不可逆的破壞性操作；錯誤時 throw 而非靜默（與其他方法不同）
Evidence:     EventHistory.ts:167-178
Scope:        method
Seam_Type:    object (透過 dbManager)
Pinch_Point:  true
```

```
M-004: cleanup 刪除過期記錄

Trigger:      呼叫 cleanup() 或 timer 自動觸發
Input:        options.retentionTime（過期閾值）
Output:       dbManager.cleanupExpiredRecords 被呼叫；回傳 deletedCount；deletedCount > 0 時記錄 log
Condition:    isInitialized === true && options.enabled === true
Ordering:     可被 timer（S-001）自動觸發，也可手動呼叫
Risk:         MEDIUM — 錯誤時靜默回傳 0（呼叫端無法區分「無過期記錄」與「清理失敗」）
Evidence:     EventHistory.ts:184-204
Scope:        method
Seam_Type:    object (透過 dbManager)
Pinch_Point:  true
```

```
M-005: updateOptions 修改運行時選項

Trigger:      呼叫 updateOptions(newOptions)
Input:        Partial<EventHistoryOptions>
Output:       this.options 被 spread merge 覆蓋；若 databaseName 或 databaseVersion 變更，僅印出 warn 不做任何動作
Condition:    無守衛——即使未初始化或已關閉也可呼叫
Ordering:     獨立操作，但變更立即影響所有後續方法的守衛條件和行為參數
Risk:         CRITICAL — (1) 無守衛條件，可在任何狀態呼叫；(2) 變更 databaseName/databaseVersion 後不重新初始化，導致 dbManager 指向舊資料庫但 options 記錄新值；(3) 可以在運行時將 enabled 設為 false，但不會停止 cleanup timer
Evidence:     EventHistory.ts:263-269
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

### Category L — Lifecycle / State Machine Contracts

```
L-001: init 初始化狀態轉換

Trigger:      呼叫 init()
Input:        options.enabled 決定是否實際初始化
Output:       (1) 若已初始化 → 直接 return（冪等）
              (2) 若 enabled=false → log info + return（isInitialized 保持 false）
              (3) 正常路徑 → dbManager.init() → isInitialized=true → startCleanupTimer()
Condition:    isInitialized === false 且 options.enabled === true 才會執行完整初始化
Ordering:     必須在所有其他 public 方法（recordOperation, queryRecords 等）之前呼叫
Risk:         HIGH — (1) enabled=false 時 init 完成但 isInitialized 仍為 false，後續所有操作靜默跳過；(2) init 失敗時 throw，但 isInitialized 保持 false，狀態一致；(3) 重複呼叫是安全的（冪等）
Evidence:     EventHistory.ts:43-65
Scope:        class
Seam_Type:    object (透過 dbManager.init)
Pinch_Point:  true (所有功能的前提)
```

```
L-002: close 關閉狀態轉換

Trigger:      呼叫 close()
Input:        無
Output:       (1) stopCleanupTimer() 總是被呼叫
              (2) 若 isInitialized → dbManager.close()（同步）+ isInitialized=false
Condition:    無——即使未初始化也可安全呼叫
Ordering:     在所有操作完成之後；close 後可以重新 init
Risk:         MEDIUM — (1) dbManager.close() 是同步的但 close() 是 async（簽名不對稱）；(2) close 期間如果有進行中的 cleanup 或 recordOperation，不會等待其完成
Evidence:     EventHistory.ts:236-247
Scope:        class
Seam_Type:    object (透過 dbManager.close)
Pinch_Point:  true
```

```
L-003: cleanup timer 生命週期

Trigger:      init 成功後 startCleanupTimer() 被呼叫
Input:        固定間隔 60000ms（1 分鐘）
Output:       setInterval 建立週期性 timer，每次觸發 cleanup()
Condition:    init 成功（isInitialized=true）
Ordering:     在 init 完成之後啟動；在 close 時被 stopCleanupTimer 停止
Risk:         MEDIUM — (1) timer 的間隔硬編碼為 60 秒，不可配置；(2) startCleanupTimer 先 clearInterval 再 setInterval（防止重複），但若 init 被呼叫兩次（冪等守衛已處理）不會到達此處
Evidence:     EventHistory.ts:208-224, 226-232
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

### Category N — Notification / Observation Contracts

```
N-001: Logger 通知（structured logging）

Trigger:      幾乎所有方法的成功/失敗路徑
Input:        logger 從 '@91app/shared-provider' 引入（全域 singleton）
Output:       logger.info / logger.trace / logger.error / logger.warn 呼叫，帶結構化 payload
Condition:    視方法路徑而定
Ordering:     在各自操作完成或失敗之後
Risk:         LOW — logger 是純輸出，不影響控制流；但 logger 的 level 配置決定是否實際輸出
Evidence:     EventHistory.ts:50,56,57,63,95-99,103,118,139,154,163,175,176,196,199,221,245,268
Scope:        class
Seam_Type:    object (logger 是外部 singleton)
Pinch_Point:  false
```

### Category S — Synchronization Contracts

```
S-001: cleanup timer 的並發執行風險

Trigger:      setInterval callback 每 60 秒觸發
Input:        async cleanup() 方法
Output:       每次 timer 觸發都執行 cleanup()，但 cleanup 是 async——若前一次尚未完成，下一次仍會啟動
Condition:    timer 處於活動狀態
Ordering:     無順序保證——多個 cleanup 可能並行執行
Risk:         HIGH — (1) 無 mutex/flag 防止並發 cleanup；(2) 並發的 IndexedDB transaction 可能導致非預期行為；(3) 60 秒間隔通常足夠，但在大資料量清理時可能超時
Evidence:     EventHistory.ts:214-222
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

```
S-002: close 期間的進行中操作

Trigger:      close() 被呼叫時有進行中的 async 操作
Input:        進行中的 recordOperation / queryRecords / cleanup 等
Output:       close 不會等待進行中操作完成——stopCleanupTimer 停止未來觸發，但已啟動的 cleanup 仍在執行；dbManager.close() 同步關閉資料庫連線
Condition:    close() 被呼叫
Ordering:     dbManager.close() 在 stopCleanupTimer() 之後，但不等待進行中的 async 操作
Risk:         HIGH — 正在進行的 dbManager 操作（addRecord, queryRecords 等）會因為底層 IDBDatabase 被關閉而失敗
Evidence:     EventHistory.ts:236-247
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

### Category E — Error Handling Contracts

```
E-001: init 失敗 — throw 傳播

Trigger:      dbManager.init() 拋出例外
Input:        任何 IndexedDB 初始化錯誤
Output:       logger.error 記錄後 throw error（原始錯誤被重新拋出）
Condition:    init 的 try block
Ordering:     isInitialized 保持 false（不會被設為 true）
Risk:         MEDIUM — 呼叫端必須 catch；失敗後物件處於未初始化但可重試的狀態
Evidence:     EventHistory.ts:62-64
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

```
E-002: recordOperation 失敗 — 靜默吞沒

Trigger:      dbManager.addRecord() 拋出例外
Input:        任何 IndexedDB 寫入錯誤
Output:       logger.error 記錄，方法正常 return void（不 throw）
Condition:    recordOperation 的 catch block
Ordering:     呼叫端不知道記錄失敗
Risk:         HIGH — 事件記錄靜默丟失，對依賴完整歷史的功能是隱含的資料遺失
Evidence:     EventHistory.ts:101-103
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

```
E-003: queryRecords 失敗 — 靜默回傳空陣列

Trigger:      dbManager.queryRecords() 拋出例外
Input:        任何 IndexedDB 讀取錯誤
Output:       logger.error 記錄，回傳 []
Condition:    queryRecords 的 catch block
Ordering:     呼叫端無法區分「查無記錄」與「查詢失敗」
Risk:         HIGH — 消費端可能基於空結果做出錯誤決策
Evidence:     EventHistory.ts:116-119
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

```
E-004: getLatestPublishRecord 失敗 — 靜默回傳 null

Trigger:      dbManager.getLatestRecord() 拋出例外
Input:        任何 IndexedDB 讀取錯誤
Output:       logger.error 記錄，回傳 null
Condition:    getLatestPublishRecord 的 catch block
Ordering:     呼叫端無法區分「無記錄」與「查詢失敗」
Risk:         HIGH — 同 E-003
Evidence:     EventHistory.ts:136-139
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

```
E-005: getStats 失敗 — 靜默回傳空統計

Trigger:      dbManager.getStats() 拋出例外
Input:        任何 IndexedDB 讀取錯誤
Output:       logger.error 記錄，回傳 { totalRecords: 0, channelCount: 0 }
Condition:    getStats 的 catch block
Ordering:     呼叫端無法區分「真的是 0 筆記錄」與「統計失敗」
Risk:         MEDIUM — 統計數據不準確但不影響核心功能
Evidence:     EventHistory.ts:156-163
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

```
E-006: clear 失敗 — throw 傳播

Trigger:      dbManager.clearAllRecords() 拋出例外
Input:        任何 IndexedDB 刪除錯誤
Output:       logger.error 記錄後 throw error
Condition:    clear 的 catch block
Ordering:     與 init (E-001) 一樣 throw——與其他方法的靜默 fallback 不一致
Risk:         LOW — throw 行為明確，呼叫端可處理；但與其他方法的錯誤策略不一致是設計合約
Evidence:     EventHistory.ts:175-178
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

```
E-007: cleanup 失敗 — 靜默回傳 0

Trigger:      dbManager.cleanupExpiredRecords() 拋出例外
Input:        任何 IndexedDB 刪除錯誤
Output:       logger.error 記錄，回傳 0
Condition:    cleanup 的 catch block
Ordering:     同 E-002 模式
Risk:         MEDIUM — 過期記錄可能持續累積但不會產生錯誤告警（除了 logger.error）
Evidence:     EventHistory.ts:199-201
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

```
E-008: timer callback 中的 cleanup 失敗 — 靜默吞沒

Trigger:      timer callback 內的 cleanup() 拋出例外
Input:        任何 cleanup 例外
Output:       logger.error 記錄，timer 繼續運作（不會因為一次失敗停止）
Condition:    startCleanupTimer 的 setInterval callback 內 try/catch
Ordering:     timer 下次觸發仍會重試
Risk:         LOW — 容錯行為正確（一次失敗不影響後續重試），但持續失敗只有 log 沒有告警升級
Evidence:     EventHistory.ts:216-221
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### Category C — Cancellation Contracts

```
C-001: stopCleanupTimer 停止 timer 但不取消進行中的 cleanup

Trigger:      close() 或 startCleanupTimer()（重啟前先停止）
Input:        this.cleanupTimer
Output:       clearInterval 停止未來觸發；cleanupTimer 設為 undefined
Condition:    cleanupTimer 存在
Ordering:     已啟動的 cleanup() 呼叫不會被中斷
Risk:         MEDIUM — 在 close() 中，已啟動的 cleanup 可能在 dbManager.close() 後仍嘗試存取已關閉的資料庫
Evidence:     EventHistory.ts:226-232
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### Category D — Dependency Contracts

```
D-001: DatabaseManager 依賴

Trigger:      constructor
Input:        options.databaseName, options.databaseVersion
Output:       建立 DatabaseManager 實例；所有資料操作透過此實例
Condition:    總是在 constructor 中建立
Ordering:     必須在 init() 之前建立（constructor 保證）
Risk:         LOW — 強耦合但明確
Evidence:     EventHistory.ts:35-38
Scope:        class
Seam_Type:    object (可透過 interface 替換)
Pinch_Point:  true
```

```
D-002: logger 依賴（@91app/shared-provider）

Trigger:      模組載入
Input:        全域 logger singleton
Output:       所有 log 輸出透過此 logger
Condition:    import 時 logger 必須可用
Ordering:     模組載入時解析
Risk:         LOW — logger 是純輸出依賴，但若 shared-provider 未初始化可能導致 import 失敗
Evidence:     EventHistory.ts:7
Scope:        module
Seam_Type:    link (import path)
Pinch_Point:  false
```

```
D-003: IEventHistory 介面合約（@91app/trinity-kernel）

Trigger:      class 宣告
Input:        EventHistory implements IEventHistory
Output:       必須滿足 IEventHistory 定義的所有方法簽名
Condition:    編譯期檢查（structural typing）
Ordering:     N/A
Risk:         MEDIUM — interface 變更會導致編譯錯誤；但 structural typing 意味著額外方法（updateOptions, cleanup 等）不在 interface 中的不受約束
Evidence:     EventHistory.ts:19
Scope:        class
Seam_Type:    object (interface implementation)
Pinch_Point:  true
```

### Category P — Propagation Contracts

```
P-001: queryRecords 回傳值傳播

Trigger:      呼叫 queryRecords()
Input:        EventHistoryQuery
Output:       Promise<EventHistoryRecord[]> — 成功時回傳 dbManager 結果；失敗時回傳 []；未初始化/停用時回傳 []
Condition:    三種不同路徑回傳相同型別但語義不同的值
Ordering:     N/A
Risk:         HIGH — 消費端無法區分三種 [] 的來源
Evidence:     EventHistory.ts:110-121
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

```
P-002: getStats 回傳值傳播

Trigger:      呼叫 getStats()
Input:        無
Output:       Promise<EventHistoryStats> — 成功時回傳 dbManager 結果；失敗/未初始化/停用時回傳 { totalRecords: 0, channelCount: 0 }
Condition:    三種路徑回傳相同結構
Ordering:     N/A
Risk:         MEDIUM — 同 P-001 但影響較小（統計用途）
Evidence:     EventHistory.ts:145-165
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

```
P-003: getLatestPublishRecord 回傳值傳播

Trigger:      呼叫 getLatestPublishRecord()
Input:        channel (string), eventType (string?)
Output:       Promise<EventHistoryRecord | null> — 成功時回傳 dbManager 結果；失敗/未初始化/停用時回傳 null
Condition:    三種路徑回傳 null
Ordering:     N/A
Risk:         HIGH — 消費端無法區分「無此記錄」與「查詢失敗」
Evidence:     EventHistory.ts:126-142
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

## F3: Effect Propagation Tracing

```
EFFECT_TRACE: constructor(options: EventHistoryOptions = {})
  RETURN:  void (constructor)
  MUTATES: none (input options 不被修改，spread 建立新物件)
  GLOBAL:  none
  DEPTH:   0

EFFECT_TRACE: async init(): Promise<void>
  RETURN:  void
  MUTATES: none
  GLOBAL:  this.isInitialized (false → true), this.cleanupTimer (undefined → NodeJS.Timeout), dbManager 內部 IDBDatabase 被開啟
  DEPTH:   2 (init → dbManager.init → IndexedDB open)

EFFECT_TRACE: async recordOperation(operation, channel, event?, from?, targetEvent?): Promise<void>
  RETURN:  void
  MUTATES: none
  GLOBAL:  IndexedDB store 新增一筆記錄 (透過 dbManager.addRecord)
  DEPTH:   2 (recordOperation → dbManager.addRecord → IDB transaction)

EFFECT_TRACE: async queryRecords(query): Promise<EventHistoryRecord[]>
  RETURN:  EventHistoryRecord[] → 直接回傳給呼叫端，無中間轉換
  MUTATES: none
  GLOBAL:  none (唯讀操作)
  DEPTH:   1

EFFECT_TRACE: async getLatestPublishRecord(channel, eventType?): Promise<EventHistoryRecord | null>
  RETURN:  EventHistoryRecord | null → 直接回傳，無轉換
  MUTATES: none
  GLOBAL:  none
  DEPTH:   1

EFFECT_TRACE: async getStats(): Promise<EventHistoryStats>
  RETURN:  EventHistoryStats → 直接回傳，無轉換
  MUTATES: none
  GLOBAL:  none
  DEPTH:   1

EFFECT_TRACE: async clear(): Promise<void>
  RETURN:  void
  MUTATES: none
  GLOBAL:  IndexedDB store 所有記錄被刪除
  DEPTH:   2

EFFECT_TRACE: async cleanup(): Promise<number>
  RETURN:  number (deletedCount) → 直接回傳給呼叫端或被 timer callback 忽略
  MUTATES: none
  GLOBAL:  IndexedDB store 過期記錄被刪除
  DEPTH:   2

EFFECT_TRACE: private startCleanupTimer(): void
  RETURN:  void
  MUTATES: none
  GLOBAL:  this.cleanupTimer 被設為新的 setInterval handle
  DEPTH:   0 (但 timer callback 的 effect depth = 2)

EFFECT_TRACE: private stopCleanupTimer(): void
  RETURN:  void
  MUTATES: none
  GLOBAL:  this.cleanupTimer 被清除並設為 undefined
  DEPTH:   0

EFFECT_TRACE: async close(): Promise<void>
  RETURN:  void
  MUTATES: none
  GLOBAL:  this.cleanupTimer 被清除, this.isInitialized → false, dbManager 內部 IDBDatabase 被關閉
  DEPTH:   1

EFFECT_TRACE: get initialized(): boolean
  RETURN:  boolean → 直接回傳 this.isInitialized
  MUTATES: none
  GLOBAL:  none
  DEPTH:   0

EFFECT_TRACE: get enabled(): boolean
  RETURN:  boolean → 直接回傳 this.options.enabled
  MUTATES: none
  GLOBAL:  none
  DEPTH:   0

EFFECT_TRACE: updateOptions(newOptions: Partial<EventHistoryOptions>): void
  RETURN:  void
  MUTATES: none (input 不被修改)
  GLOBAL:  this.options 被 spread merge 覆蓋
  DEPTH:   0
```

---

## Risk Matrix

| ID | Risk | Description | Refactoring Impact |
|----|------|-------------|-------------------|
| M-005 | CRITICAL | updateOptions 無守衛且不同步 dbManager 狀態 | 重構必須決定：是否禁止運行時變更 db 相關選項，或自動重新初始化 |
| E-002 | HIGH | recordOperation 靜默吞沒寫入錯誤 | 重構若改為 throw，所有呼叫端需要新增 error handling |
| E-003 | HIGH | queryRecords 靜默回傳空陣列 | 同上 |
| E-004 | HIGH | getLatestPublishRecord 靜默回傳 null | 同上 |
| P-001 | HIGH | queryRecords 三種路徑回傳相同型別 | 需要引入 Result type 或 error flag |
| P-003 | HIGH | getLatestPublishRecord 三種路徑回傳 null | 同上 |
| S-001 | HIGH | cleanup timer 無並發保護 | 需要加入 isCleaningUp flag 或 mutex |
| S-002 | HIGH | close 不等待進行中操作 | 需要引入 pending operations tracking |
| L-001 | HIGH | init 的 enabled=false 路徑不設 isInitialized | 重構須決定 enabled=false 的語義 |
| M-003 | HIGH | clear 是不可逆操作且 throw（與其他方法不一致） | 重構須統一錯誤策略 |
| L-002 | MEDIUM | close → init 可重新使用但 dbManager 指向同一實例 | 重構須驗證 dbManager 支援重新 init |
| M-001 | MEDIUM | recordOperation 守衛條件靜默丟棄 | 呼叫端可能需要知道記錄是否成功 |
| M-004 | MEDIUM | cleanup 錯誤靜默回傳 0 | 過期記錄可能累積 |
| C-001 | MEDIUM | stopCleanupTimer 不取消進行中 cleanup | 需要 abort mechanism |
| L-003 | MEDIUM | timer 間隔硬編碼 60 秒 | 可考慮加入 options |
| E-005 | MEDIUM | getStats 靜默回傳空統計 | 同 E-002 |
| D-003 | MEDIUM | IEventHistory interface 約束 | interface 變更影響所有 implements |
| M-002 | LOW | Date.now() 不可注入 | 測試問題但非功能問題 |
| E-001 | MEDIUM | init 失敗 throw（正確行為） | 保持 |
| E-006 | LOW | clear 失敗 throw（正確但不一致） | 統一策略時決定 |
| E-007 | MEDIUM | cleanup 靜默回傳 0 | 同上 |
| E-008 | LOW | timer callback 容錯（正確行為） | 保持 |
| N-001 | LOW | logger 通知 | logger 是純輸出 |
| D-001 | LOW | DatabaseManager 依賴 | 強耦合但明確 |
| D-002 | LOW | logger 依賴 | 極少變更 |

---

# Artifact 2: Verification Scripts

## 2a. grep 驗證腳本

```bash
#!/bin/bash
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

# M-001: recordOperation writes to IndexedDB
assert_match "M-001" "await this.dbManager.addRecord(record)" "$TARGET"

# M-002: timestamp uses Date.now()
assert_match "M-002" "timestamp: Date.now()" "$TARGET"

# M-003: clear calls clearAllRecords
assert_match "M-003" "await this.dbManager.clearAllRecords()" "$TARGET"

# M-004: cleanup calls cleanupExpiredRecords with retentionTime
assert_match "M-004" "this.dbManager.cleanupExpiredRecords" "$TARGET"

# M-005: updateOptions spread merge without guards
assert_match "M-005" "this.options = { ...this.options, ...newOptions }" "$TARGET"

# L-001: init sets isInitialized = true after dbManager.init
assert_match "L-001" "this.isInitialized = true" "$TARGET"

# L-002: close sets isInitialized = false
assert_match "L-002" "this.isInitialized = false" "$TARGET"

# L-003: startCleanupTimer uses setInterval with 60000
assert_match "L-003" "setInterval(async" "$TARGET"

# N-001: logger import
assert_match "N-001" "import { logger } from '@91app/shared-provider'" "$TARGET"

# S-001: cleanup timer callback (no concurrency guard)
assert_match "S-001" "await this.cleanup()" "$TARGET"

# S-002: close calls dbManager.close synchronously
assert_match "S-002" "this.dbManager.close()" "$TARGET"

# E-001: init re-throws error
assert_match "E-001" "throw error" "$TARGET"

# E-002: recordOperation catch does not throw
assert_match "E-002" "記錄事件操作失敗" "$TARGET"

# E-003: queryRecords catch returns []
assert_match "E-003" "查詢事件記錄失敗" "$TARGET"

# E-004: getLatestPublishRecord catch returns null
assert_match "E-004" "獲取最新發布記錄失敗" "$TARGET"

# E-005: getStats catch returns empty stats
assert_match "E-005" "獲取統計資訊失敗" "$TARGET"

# E-006: clear re-throws error
assert_match "E-006" "清空記錄失敗" "$TARGET"

# E-007: cleanup catch returns 0
assert_match "E-007" "清理過期記錄失敗" "$TARGET"

# E-008: timer callback catch
assert_match "E-008" "定期清理失敗" "$TARGET"

# C-001: stopCleanupTimer clears interval
assert_match "C-001" "clearInterval(this.cleanupTimer)" "$TARGET"

# D-001: DatabaseManager construction
assert_match "D-001" "new DatabaseManager(" "$TARGET"

# D-002: logger import
assert_match "D-002" "from '@91app/shared-provider'" "$TARGET"

# D-003: implements IEventHistory
assert_match "D-003" "implements IEventHistory" "$TARGET"

# P-001: queryRecords guard returns []
assert_match "P-001" "return \[\]" "$TARGET"

# P-002: getStats guard returns empty stats
assert_match "P-002" "totalRecords: 0" "$TARGET"

# P-003: getLatestPublishRecord guard returns null
assert_match "P-003" "return null" "$TARGET"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
```

## 2b. ast-grep 規則檔

```yaml
# File: .ast-grep/rules/EventHistory/M-001-record-operation-write.yml
id: M-001-record-operation-write
message: "M-001: recordOperation must write via dbManager.addRecord -- contract must be present"
severity: error
language: TypeScript
rule:
  pattern: |
    await this.dbManager.addRecord($RECORD)
note: |
  Contract source: EventHistory.ts:90
  Refactoring requirement: 所有事件記錄必須透過 dbManager.addRecord 寫入
```

```yaml
# File: .ast-grep/rules/EventHistory/M-005-update-options-no-guard.yml
id: M-005-update-options-no-guard
message: "M-005: updateOptions spread merge -- contract must be present"
severity: error
language: TypeScript
rule:
  pattern: |
    this.options = { ...this.options, ...newOptions }
note: |
  Contract source: EventHistory.ts:264
  Refactoring requirement: updateOptions 的 spread merge 行為；注意此方法無 isInitialized/enabled 守衛
```

```yaml
# File: .ast-grep/rules/EventHistory/L-001-init-state-transition.yml
id: L-001-init-state-transition
message: "L-001: init must set isInitialized after dbManager.init -- contract must be present"
severity: error
language: TypeScript
rule:
  kind: assignment_expression
  pattern: |
    this.isInitialized = true
note: |
  Contract source: EventHistory.ts:56
  Refactoring requirement: isInitialized 必須在 dbManager.init 成功後才設為 true
```

```yaml
# File: .ast-grep/rules/EventHistory/S-001-cleanup-timer-no-concurrency.yml
id: S-001-cleanup-timer-no-concurrency
message: "S-001: cleanup timer callback executes async cleanup without concurrency guard"
severity: error
language: TypeScript
rule:
  pattern: |
    setInterval(async () => { $$$ }, $INTERVAL)
note: |
  Contract source: EventHistory.ts:214-222
  Refactoring requirement: 若重構為有並發保護的版本，此 pattern 會改變
```

```yaml
# File: .ast-grep/rules/EventHistory/E-002-record-operation-silent-catch.yml
id: E-002-record-operation-silent-catch
message: "E-002: recordOperation silently catches errors -- contract must be present"
severity: error
language: TypeScript
rule:
  pattern: |
    logger.error({ error, operation, channel }, $MSG)
note: |
  Contract source: EventHistory.ts:103
  Refactoring requirement: recordOperation 的 catch block 靜默吞沒錯誤；若改為 throw 需更新所有呼叫端
```

```yaml
# File: .ast-grep/rules/EventHistory/D-003-implements-ieventhistory.yml
id: D-003-implements-ieventhistory
message: "D-003: EventHistory must implement IEventHistory interface"
severity: error
language: TypeScript
rule:
  pattern: |
    class EventHistory implements IEventHistory { $$$ }
note: |
  Contract source: EventHistory.ts:19
  Refactoring requirement: 重構後必須持續滿足 IEventHistory 介面
```

---

# Artifact 3: Coverage Table

| ID | Title | Verified By | File / Assertion |
|----|-------|-------------|-----------------|
| M-001 | recordOperation 寫入 IndexedDB | grep + ast-grep | `verify-contracts-EventHistory.sh` M-001; `.ast-grep/rules/EventHistory/M-001-record-operation-write.yml` |
| M-002 | timestamp 使用 Date.now() | grep | `verify-contracts-EventHistory.sh` M-002 |
| M-003 | clear 清空所有記錄 | grep | `verify-contracts-EventHistory.sh` M-003 |
| M-004 | cleanup 刪除過期記錄 | grep | `verify-contracts-EventHistory.sh` M-004 |
| M-005 | updateOptions 無守衛 spread merge | grep + ast-grep | `verify-contracts-EventHistory.sh` M-005; `.ast-grep/rules/EventHistory/M-005-update-options-no-guard.yml` |
| L-001 | init 初始化狀態轉換 | grep + ast-grep | `verify-contracts-EventHistory.sh` L-001; `.ast-grep/rules/EventHistory/L-001-init-state-transition.yml` |
| L-002 | close 關閉狀態轉換 | grep | `verify-contracts-EventHistory.sh` L-002 |
| L-003 | cleanup timer 生命週期 | grep | `verify-contracts-EventHistory.sh` L-003 |
| N-001 | Logger 通知 | grep | `verify-contracts-EventHistory.sh` N-001 |
| S-001 | cleanup timer 並發風險 | ast-grep | `.ast-grep/rules/EventHistory/S-001-cleanup-timer-no-concurrency.yml` |
| S-002 | close 不等待進行中操作 | manual review | close() 中 dbManager.close() 是同步的，但正在進行的 async 操作不被追蹤——需人工審查 close 與 pending operations 的時序 |
| E-001 | init throw | grep | `verify-contracts-EventHistory.sh` E-001 |
| E-002 | recordOperation 靜默吞沒 | grep + ast-grep | `verify-contracts-EventHistory.sh` E-002; `.ast-grep/rules/EventHistory/E-002-record-operation-silent-catch.yml` |
| E-003 | queryRecords 靜默回傳 [] | grep | `verify-contracts-EventHistory.sh` E-003 |
| E-004 | getLatestPublishRecord 靜默回傳 null | grep | `verify-contracts-EventHistory.sh` E-004 |
| E-005 | getStats 靜默回傳空統計 | grep | `verify-contracts-EventHistory.sh` E-005 |
| E-006 | clear throw | grep | `verify-contracts-EventHistory.sh` E-006 |
| E-007 | cleanup 靜默回傳 0 | grep | `verify-contracts-EventHistory.sh` E-007 |
| E-008 | timer callback 容錯 | grep | `verify-contracts-EventHistory.sh` E-008 |
| C-001 | stopCleanupTimer 不取消進行中 cleanup | manual review | clearInterval 只停止未來觸發；需人工審查已啟動的 async cleanup 與 close 的時序交互 |
| D-001 | DatabaseManager 依賴 | grep | `verify-contracts-EventHistory.sh` D-001 |
| D-002 | logger 依賴 | grep | `verify-contracts-EventHistory.sh` D-002 |
| D-003 | IEventHistory 介面 | grep + ast-grep | `verify-contracts-EventHistory.sh` D-003; `.ast-grep/rules/EventHistory/D-003-implements-ieventhistory.yml` |
| P-001 | queryRecords 三路 [] 傳播 | grep | `verify-contracts-EventHistory.sh` P-001 |
| P-002 | getStats 三路空統計傳播 | grep | `verify-contracts-EventHistory.sh` P-002 |
| P-003 | getLatestPublishRecord 三路 null 傳播 | grep | `verify-contracts-EventHistory.sh` P-003 |

---

# Artifact 4: Line Attribution Table

以下基於提供的 EventHistory.ts 原始碼（行號依 prompt 中的原始碼順序推算）：

| Line(s) | Classification | Contract ID(s) |
|---------|---------------|----------------|
| 1-6 | SKIP | -- (JSDoc 註解) |
| 7 | CONTRACT | D-002 |
| 8 | CONTRACT | D-003 |
| 9-15 | INFRA | -- (import 型別) |
| 16 | CONTRACT | D-001 |
| 17 | SKIP | -- (空行) |
| 18 | SKIP | -- (空行) |
| 19 | CONTRACT | D-003 |
| 20-22 | INFRA | -- (private field 宣告) |
| 23 | CONTRACT | L-001, L-002 (isInitialized flag) |
| 24 | SKIP | -- (空行) |
| 25 | INFRA | -- (constructor 簽名) |
| 26-33 | CONTRACT | M-005 (options 預設值與 spread merge 模式的初始版本) |
| 34 | SKIP | -- (空行) |
| 35-38 | CONTRACT | D-001 (DatabaseManager 建立) |
| 39 | INFRA | -- (constructor closing brace) |
| 40 | SKIP | -- (空行) |
| 41-42 | SKIP | -- (JSDoc) |
| 43 | INFRA | -- (init 簽名) |
| 44-46 | CONTRACT | L-001 (冪等守衛) |
| 47 | SKIP | -- (空行) |
| 48-51 | CONTRACT | L-001 (enabled=false 提前返回) |
| 52 | SKIP | -- (空行) |
| 53 | INFRA | -- (try) |
| 54 | CONTRACT | L-001 (dbManager.init) |
| 55-56 | CONTRACT | L-001, N-001 (isInitialized=true + log) |
| 57 | SKIP | -- (空行) |
| 58-59 | CONTRACT | L-003 (startCleanupTimer) |
| 60-61 | CONTRACT | E-001, N-001 (catch + log) |
| 62-64 | CONTRACT | E-001 (throw error) |
| 65 | INFRA | -- (closing brace) |
| 66 | SKIP | -- (空行) |
| 67-68 | SKIP | -- (JSDoc) |
| 69-75 | INFRA | -- (recordOperation 簽名) |
| 76-78 | CONTRACT | M-001 (守衛條件) |
| 79 | SKIP | -- (空行) |
| 80 | INFRA | -- (try) |
| 81-89 | CONTRACT | M-002 (record 組裝) |
| 90 | SKIP | -- (空行) |
| 91 | CONTRACT | M-001 (dbManager.addRecord) |
| 92 | SKIP | -- (空行) |
| 93-100 | CONTRACT | N-001 (logger.trace) |
| 101-103 | CONTRACT | E-002, N-001 (catch + logger.error) |
| 104 | INFRA | -- (closing brace) |
| 105 | SKIP | -- (空行) |
| 106-109 | SKIP | -- (JSDoc) |
| 110 | INFRA | -- (queryRecords 簽名) |
| 111-113 | CONTRACT | P-001 (守衛回傳 []) |
| 114 | SKIP | -- (空行) |
| 115 | INFRA | -- (try) |
| 116 | CONTRACT | P-001 (dbManager.queryRecords) |
| 117-119 | CONTRACT | E-003, P-001, N-001 (catch 回傳 []) |
| 120-121 | INFRA | -- (closing braces) |
| 122 | SKIP | -- (空行) |
| 123-125 | SKIP | -- (JSDoc) |
| 126-129 | INFRA | -- (getLatestPublishRecord 簽名) |
| 130-132 | CONTRACT | P-003 (守衛回傳 null) |
| 133 | SKIP | -- (空行) |
| 134 | INFRA | -- (try) |
| 135 | CONTRACT | P-003 (dbManager.getLatestRecord) |
| 136-139 | CONTRACT | E-004, P-003, N-001 (catch 回傳 null) |
| 140-142 | INFRA | -- (closing braces) |
| 143 | SKIP | -- (空行) |
| 144 | SKIP | -- (JSDoc) |
| 145 | INFRA | -- (getStats 簽名) |
| 146-152 | CONTRACT | P-002 (守衛回傳空統計) |
| 153 | SKIP | -- (空行) |
| 154 | INFRA | -- (try) |
| 155 | CONTRACT | P-002 (dbManager.getStats) |
| 156-163 | CONTRACT | E-005, P-002, N-001 (catch 回傳空統計) |
| 164-165 | INFRA | -- (closing braces) |
| 166 | SKIP | -- (空行) |
| 167 | SKIP | -- (JSDoc) |
| 168 | INFRA | -- (clear 簽名) |
| 169-171 | CONTRACT | M-003 (守衛) |
| 172 | SKIP | -- (空行) |
| 173 | INFRA | -- (try) |
| 174-175 | CONTRACT | M-003, N-001 (clearAllRecords + log) |
| 176-178 | CONTRACT | E-006, N-001 (catch + throw) |
| 179 | INFRA | -- (closing brace) |
| 180 | SKIP | -- (空行) |
| 181-183 | SKIP | -- (JSDoc) |
| 184 | INFRA | -- (cleanup 簽名) |
| 185-187 | CONTRACT | M-004 (守衛回傳 0) |
| 188 | SKIP | -- (空行) |
| 189 | INFRA | -- (try) |
| 190-192 | CONTRACT | M-004 (cleanupExpiredRecords) |
| 193 | SKIP | -- (空行) |
| 194-196 | CONTRACT | M-004, N-001 (deletedCount > 0 log) |
| 197 | SKIP | -- (空行) |
| 198 | CONTRACT | M-004 (return deletedCount) |
| 199-201 | CONTRACT | E-007, N-001 (catch 回傳 0) |
| 202-204 | INFRA | -- (closing braces) |
| 205 | SKIP | -- (空行) |
| 206-207 | SKIP | -- (JSDoc) |
| 208 | INFRA | -- (startCleanupTimer 簽名) |
| 209-211 | CONTRACT | L-003, C-001 (清除既有 timer) |
| 212 | SKIP | -- (空行) |
| 213 | SKIP | -- (comment) |
| 214-222 | CONTRACT | L-003, S-001, E-008 (setInterval + async cleanup + catch) |
| 223-224 | INFRA | -- (closing braces) |
| 225 | SKIP | -- (空行) |
| 226 | SKIP | -- (JSDoc) |
| 227 | INFRA | -- (stopCleanupTimer 簽名) |
| 228-231 | CONTRACT | C-001 (clearInterval + undefined) |
| 232 | INFRA | -- (closing brace) |
| 233 | SKIP | -- (空行) |
| 234-235 | SKIP | -- (JSDoc) |
| 236 | INFRA | -- (close 簽名) |
| 237 | CONTRACT | C-001, L-002 (stopCleanupTimer) |
| 238 | SKIP | -- (空行) |
| 239-241 | CONTRACT | L-002, S-002 (isInitialized check) |
| 242 | CONTRACT | L-002, S-002, D-001 (dbManager.close 同步) |
| 243 | CONTRACT | L-002 (isInitialized = false) |
| 244-245 | CONTRACT | N-001 (log) |
| 246-247 | INFRA | -- (closing braces) |
| 248 | SKIP | -- (空行) |
| 249-251 | SKIP | -- (JSDoc) |
| 252-254 | INFRA | -- (getter initialized) |
| 255 | SKIP | -- (空行) |
| 256-258 | SKIP | -- (JSDoc) |
| 259-261 | INFRA | -- (getter enabled) |
| 262 | SKIP | -- (空行) |
| 263 | SKIP | -- (JSDoc) |
| 264 | INFRA | -- (updateOptions 簽名) |
| 265 | CONTRACT | M-005 (spread merge) |
| 266 | SKIP | -- (空行) |
| 267-269 | CONTRACT | M-005, N-001 (db name/version 變更警告) |
| 270 | INFRA | -- (closing brace) |
| 271 | INFRA | -- (class closing brace) |

### 摘要

```
Total lines:       ~271
CONTRACT lines:    ~142 (52%)
INFRA lines:       ~62 (23%)
SKIP lines:        ~67 (25%)
Unclassified:      0
```

---

## 錨定合約驗證（Step 0.7）

| # | 錨點 | 對應合約 |
|---|------|---------|
| 1 | Promise_all (DatabaseManager.ts:238) | 此錨點位於 DatabaseManager.ts 而非主要稽核目標 EventHistory.ts。DatabaseManager.getStats 內部使用 Promise.all 並行執行 count 和 getAll 查詢——在 EventHistory 層面對應 P-002（getStats 的回傳值傳播）和 E-005（getStats 失敗時的錯誤處理）。Promise.all 的 fail-fast 語義意味著任一子查詢失敗會導致整體 reject，被 EventHistory.getStats 的 catch block 捕獲。 |
| 2 | async_function (examples.ts:9) | 對應 L-001（init 必須在操作前呼叫）和 D-003（IEventHistory 介面合約）。examples.ts 展示了正確的使用序列：new → init → 操作 → close。 |
| 3 | try_block (EventHistory.ts:53) | 對應 E-001（init 的 try/catch + throw）。 |
| 4 | throw_new (DatabaseManager.ts:60) | 此錨點位於 DatabaseManager.ts——DatabaseManager.ensureDb 在 db 未開啟時 throw。在 EventHistory 層面對應 D-001（DatabaseManager 依賴）和 E-001 至 E-008（所有 try/catch block 都可能因此 throw 而被觸發）。 |

---

## 完整性宣告

`COMPLETE: All executable lines attributed. No known audit gaps.`

`★ Insight ─────────────────────────────────────`
**此模組最核心的重構風險**在於錯誤處理策略的不一致性：`init()` 和 `clear()` 會 throw，其餘所有方法靜默回傳預設值。這使得呼叫端形成了「EventHistory 不會 throw」的隱含假設（除了 init/clear），但這個假設完全沒有在 IEventHistory interface 的型別簽名中表達。

另一個值得關注的設計決策是 `updateOptions` 方法——它是整個類別中唯一沒有 `isInitialized`/`enabled` 守衛的公開方法，且可以在運行時修改 `databaseName` 而不觸發重新初始化，這在實際使用中幾乎必然是 bug。
`─────────────────────────────────────────────────`
