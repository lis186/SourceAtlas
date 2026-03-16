Contract: Lifecycle Management through Initialization Flag
Category: L
Trigger:  Calling any method that checks `isInitialized`.
Effect:   The class instance has an internal state machine (`initialized` -> `not initialized`). Methods behave differently based on this state, primarily after `init()` is called and before `close()` is called.
Evidence: EventHistory.ts:47 -- `if (this.isInitialized) { return }`

Contract: Background Cleanup Process
Category: L
Trigger:  Successful completion of the `init()` method.
Effect:   A `setInterval` timer is started, which periodically calls the `cleanup()` method to delete old records from the database. This is a background side effect.
Evidence: EventHistory.ts:60 -- `this.startCleanupTimer()`

Contract: Internal State Mutation
Category: M
Trigger:  Successful `init()` call or `close()` call.
Effect:   The internal boolean flag `isInitialized` is changed.
Evidence: EventHistory.ts:58 -- `this.isInitialized = true`

Contract: Database Record Creation
Category: M
Trigger:  Calling `recordOperation` when the instance is initialized and enabled.
Effect:   A new record is created and passed to the `DatabaseManager` to be persisted.
Evidence: EventHistory.ts:102 -- `await this.dbManager.addRecord(record)`

Contract: Database Record Deletion (All)
Category: M
Trigger:  Calling the `clear()` method.
Effect:   All records are deleted from the database via `dbManager.clearAllRecords()`.
Evidence: EventHistory.ts:187 -- `await this.dbManager.clearAllRecords()`

Contract: Database Record Deletion (Expired)
Category: M
Trigger:  Calling the `cleanup()` method, either directly or via the background timer.
Effect:   Records older than `options.retentionTime` are deleted from the database.
Evidence: EventHistory.ts:201 -- `const deletedCount = await this.dbManager.cleanupExpiredRecords(...)`

Contract: Configuration Update
Category: M
Trigger:  Calling `updateOptions`.
Effect:   The internal `options` object is mutated with new values.
Evidence: EventHistory.ts:260 -- `this.options = { ...this.options, ...newOptions }`

Contract: Warning on Sensitive Option Change
Category: N
Trigger:  Calling `updateOptions` with a new `databaseName` or `databaseVersion`.
Effect:   A warning message is logged, notifying the developer that a re-initialization is required for the change to take effect.
Evidence: EventHistory.ts:263 -- `logger.warn('資料庫名稱或版本變更需要重新初始化')`

Contract: Swallowed Error on Record Operation
Category: E
Trigger:  An error occurring during `dbManager.addRecord`.
Effect:   The error is caught, logged, and then suppressed. The caller of `recordOperation` does not receive an exception and is unaware the operation failed.
Evidence: EventHistory.ts:114 -- `logger.error({ error, operation, channel }, '記錄事件操作失敗')`

Contract: Swallowed Error on Query
Category: E
Trigger:  An error occurring during `dbManager.queryRecords`.
Effect:   The error is caught, logged, and an empty array `[]` is returned. The caller cannot distinguish between a failed query and a query that genuinely found no results.
Evidence: EventHistory.ts:128 -- `return []`

Contract: Swallowed Error on Latest Record Fetch
Category: E
Trigger:  An error occurring during `dbManager.getLatestRecord`.
Effect:   The error is caught, logged, and `null` is returned. The caller cannot distinguish between a failed query and a query for a non-existent record.
Evidence: EventHistory.ts:143 -- `return null`

Contract: Swallowed Error on Stats Fetch
Category: E
Trigger:  An error occurring during `dbManager.getStats`.
Effect:   The error is caught, logged, and a zeroed-out `EventHistoryStats` object is returned. The caller cannot distinguish between a failure and a truly empty database.
Evidence: EventHistory.ts:161 -- `return { totalRecords: 0, channelCount: 0 }`

Contract: Silent No-Op on Uninitialized/Disabled Methods
Category: E
Trigger:  Calling most public methods (`recordOperation`, `queryRecords`, `clear`, `cleanup`, etc.) when `isInitialized` is `false` or `options.enabled` is `false`.
Effect:   The method returns immediately with a default value (e.g., `void`, `[]`, `null`, `0`) without performing its primary function. This is a silent fallback.
Evidence: EventHistory.ts:84 -- `if (!this.isInitialized || !this.options.enabled) { return }`

Contract: Initialization Error Propagation
Category: E
Trigger:  An error occurring during `dbManager.init()` inside the `init()` method.
Effect:   The error is logged and then re-thrown to the caller. The caller is responsible for handling initialization failure.
Evidence: EventHistory.ts:64 -- `throw error`

Contract: Cleanup Timer Cancellation
Category: C
Trigger:  Calling `close()` or calling `init()` which then calls `startCleanupTimer()` again.
Effect:   The existing `setInterval` timer for background cleanup is cleared and stopped.
Evidence: EventHistory.ts:238 -- `clearInterval(this.cleanupTimer)`

Contract: Dependency on Database Manager
Category: D
Trigger:  Instantiation of the `EventHistory` class.
Effect:   An instance of `DatabaseManager` is created and stored, and most public methods delegate their core logic to it. The `EventHistory` class is implicitly dependent on the behavior and correctness of `DatabaseManager`.
Evidence: EventHistory.ts:40 -- `this.dbManager = new DatabaseManager(...)`

Contract: Dependency on Logger
Category: D
Trigger:  Any method call that results in logging.
Effect:   The code relies on an external, shared `logger` instance from `@91app/shared-provider` to report information, warnings, and errors.
Evidence: EventHistory.ts:51 -- `logger.info('EventHistory 已停用')`

Contract: Propagation of Query Results
Category: P
Trigger:  A successful call to `queryRecords`.
Effect:   An array of `EventHistoryRecord` objects, originating from the `DatabaseManager`, is returned to the caller. The data crosses the module boundary.
Evidence: EventHistory.ts:126 -- `return await this.dbManager.queryRecords(query)`

TOTAL CONTRACTS FOUND: 18
CATEGORY BREAKDOWN: M=[4] L=[2] N=[1] S=[0] E=[7] C=[1] D=[2] P=[1]

EXTERNAL_DEPENDENCY: /Users/justinlee/dev/matrix/libs/event-history/src/DatabaseManager.ts -- This class is instantiated and its methods (`init`, `close`, `addRecord`, `queryRecords`, `cleanupExpiredRecords`, `getStats`, `getLatestRecord`, `clearAllRecords`) are called throughout `EventHistory`. It handles the entire persistence layer.
EXTERNAL_DEPENDENCY: @91app/shared-provider -- Provides the shared `logger` singleton used for all logging output.
EXTERNAL_DEPENDENCY: @91app/trinity-kernel -- Provides the `IEventHistory` interface, defining the public API contract that this class implements for external consumers.
EXTERNAL_DEPENDENCY: /Users/justinlee/dev/matrix/libs/event-history/src/examples.ts -- Likely a consumer of the `EventHistory` class, calling methods like `queryRecords` and `getStats` to consume the data propagated from the module.
