CONFIRM M-001: `recordOperation()` explicitly injects `timestamp: Date.now()` before persistence.
CONFIRM M-002: `cleanup()` passes `this.options.retentionTime` into `cleanupExpiredRecords()`.
CONFIRM M-003: `clear()` directly invokes `dbManager.clearAllRecords()` as destructive mutation.
CONFIRM M-004: `updateOptions()` performs a shallow merge and does not reinitialize `dbManager`.
DISPUTE M-005: “constructor 後必須先 init 才能用其他方法” is overstated; public methods are callable and no-op via guards.
  Evidence: EventHistory.ts:76 -- `if (!this.isInitialized || !this.options.enabled) { return }`

CONFIRM L-001: `init()` has an early-return idempotency guard.
CONFIRM L-002: `init()` exits early when disabled and leaves `isInitialized` false.
DISPUTE L-003: The “可能阻止垃圾回收” claim is overstated because timer lifecycle has explicit teardown.
  Evidence: EventHistory.ts:237 -- `this.stopCleanupTimer()`
CONFIRM L-004: `close()` ordering is implemented as stop timer -> close db -> set `isInitialized=false`.
DISPUTE L-005: Title claims a distinct “已關閉” state, but state is only one boolean and closed/uninitialized both map to `false`.
  Evidence: EventHistory.ts:22 -- `private isInitialized = false`

CONFIRM E-001: `init()` logs and rethrows on failure.
CONFIRM E-002: `recordOperation()` catches and suppresses write errors.
CONFIRM E-003: `queryRecords()` catches and returns `[]`.
CONFIRM E-004: `getLatestPublishRecord()` catches and returns `null`.
CONFIRM E-005: `getStats()` catches and returns zeroed stats.
CONFIRM E-006: `clear()` logs and rethrows on failure.
CONFIRM E-007: `cleanup()` catches and returns `0`.
DISPUTE E-008: Trigger is overstated; `cleanup()` already catches internally, so timer catch is mostly defensive/unreachable for normal cleanup failures.
  Evidence: EventHistory.ts:199-201 -- `catch (error) { ... return 0 }`
DISPUTE E-009: This contract is not directly established in `EventHistory`; module guards prevent uninitialized calls here, so stated trigger path is overstated for this artifact.
  Evidence: EventHistory.ts:111 -- `if (!this.isInitialized || !this.options.enabled) { return [] }`

CONFIRM S-001: `init()` has no mutex/in-flight promise guard around `await this.dbManager.init()`.
CONFIRM S-002: periodic `setInterval` creates concurrent cleanup execution path.
DISPUTE S-003: “operation may call dbManager after close” is overstated for shown methods; db call is invoked before await suspension.
  Evidence: EventHistory.ts:91 -- `await this.dbManager.addRecord(record)`
DISPUTE S-004: Contract asserts same-transaction/order semantics not shown by provided anchor; only `Promise.all` parallelism is evidenced.
  Evidence: DatabaseManager.ts:238 -- `Promise.all([ new Promise<number>(...), new Promise<EventHistoryRecord[]>(...) ])`

CONFIRM D-001: `EventHistory` depends on `DatabaseManager` init-before-use sequencing.
CONFIRM D-002: Module has hard dependency on shared `logger`.
CONFIRM D-003: Class implements external `IEventHistory` interface.
DISPUTE D-004: This is primarily a type-level annotation dependency, not a runtime lifecycle dependency as written.
  Evidence: EventHistory.ts:21 -- `private cleanupTimer?: NodeJS.Timeout`
CONFIRM D-005: Imported `./types` shapes define this module’s API/data contracts.

CONFIRM C-001: `stopCleanupTimer()` cancels interval and clears handle.
DISPUTE C-002: “無法取消進行中的資料庫操作” is too broad as stated in this artifact; timer cancellation does exist as a cancellation mechanism.
  Evidence: EventHistory.ts:227 -- `clearInterval(this.cleanupTimer)`

CONFIRM P-001: Guard returns method-specific empty defaults when uninitialized/disabled.
DISPUTE P-002: Undefined-field indexing/query impact is speculative; only raw optional propagation is evidenced.
  Evidence: EventHistory.ts:81-89 -- `eventType: event?.type, event, ... from, targetEvent`
CONFIRM P-003: `getStats()` error fallback equals disabled/uninitialized fallback value.

ADD Warning on sensitive DB option changes:
  Category: N
  Trigger: `updateOptions()` receives `databaseName` or `databaseVersion`
  Effect: Emits warning notification that re-init is required
  Evidence: EventHistory.ts:266-268 -- `logger.warn('資料庫名稱或版本變更需要重新初始化')`

ADD Query result passthrough propagation:
  Category: P
  Trigger: successful `queryRecords(query)`
  Effect: `DatabaseManager` results are propagated across module boundary without transformation
  Evidence: EventHistory.ts:116 -- `return await this.dbManager.queryRecords(query)`

META_ISSUE M-004: Scope -- marked `class`, but contract behavior is method-local (`updateOptions`).
META_ISSUE L-002: Scope -- marked `class`, but behavior is specific to `init()`.
META_ISSUE L-003: Scope -- marked `class`, but behavior is specific to `init()/startCleanupTimer()`.
META_ISSUE L-004: Scope -- marked `class`, but behavior is specific to `close()`.
META_ISSUE S-001: Scope -- marked `class`, but race is specific to `init()`.
META_ISSUE D-004: Seam_Type -- `preprocessing` appears mismatched; this is a type/import seam rather than preprocessing logic.

COVERAGE M: 4 contracts found -- OK
COVERAGE L: 3 contracts found -- OK
COVERAGE N: 1 contracts found -- SUSPECT_MISSING: only logger warning; no pub/sub signal contracts captured
COVERAGE S: 2 contracts found -- OK
COVERAGE E: 7 contracts found -- OK
COVERAGE C: 1 contracts found -- SUSPECT_MISSING: in-flight cancellation semantics remain under-specified
COVERAGE D: 4 contracts found -- OK
COVERAGE P: 3 contracts found -- OK

SUMMARY
CONFIRM: 23
DISPUTE: 10
ADD: 2
META_ISSUE: 6
CONFIRM_RATIO: 69.7%DEGRADED=no
