Contract: Initialization State Guard
Category: L
Trigger:  Calling any method before `init()` has completed successfully.
Effect:   Most methods will return early with no effect, returning empty or null values.
Evidence: EventHistory.ts:50 -- `if (this.isInitialized) { return; }`

Contract: Disabled Module
Category: L
Trigger:  Instantiating the class with `enabled: false` in the options, or calling any method when so configured.
Effect:   The `init()` method will log and return, and all other operational methods will return early with no effect.
Evidence: EventHistory.ts:54 -- `if (!this.options.enabled) { logger.info('EventHistory 已停用'); return; }`

Contract: Background Cleanup Process
Category: L
Trigger:  Successful completion of the `init()` method.
Effect:   A timer is started that periodically calls the `cleanup()` method every 60 seconds to delete old records.
Evidence: EventHistory.ts:63 -- `this.startCleanupTimer()`

Contract: Internal State Mutation on Init/Close
Category: M
Trigger:  Calling `init()` or `close()`.
Effect:   The internal `isInitialized` flag is set to `true` on successful `init()` and `false` after `close()`.
Evidence: EventHistory.ts:61 -- `this.isInitialized = true`

Contract: Database Record Creation
Category: M
Trigger:  Calling `recordOperation` on an initialized and enabled instance.
Effect:   A new record is created and passed to the `DatabaseManager` to be persisted.
Evidence: EventHistory.ts:98 -- `await this.dbManager.addRecord(record)`

Contract: Full Data Purge
Category: M
Trigger:  Calling the `clear()` method.
Effect:   All event history records are deleted from the database.
Evidence: EventHistory.ts:162 -- `await this.dbManager.clearAllRecords()`

Contract: Expired Data Deletion
Category: M
Trigger:  Calling the `cleanup()` method, either directly or via the background timer.
Effect:   Records older than the configured `retentionTime` are deleted from the database.
Evidence: EventHistory.ts:175 -- `const deletedCount = await this.dbManager.cleanupExpiredRecords(this.options.retentionTime)`

Contract: Initialization Failure Propagation
Category: P
Trigger:  An error occurring during the `dbManager.init()` call.
Effect:   The error is caught, logged, and then re-thrown to the caller of `init()`.
Evidence: EventHistory.ts:67 -- `throw error`

Contract: Silent Error Handling in Queries
Category: E
Trigger:  An error occurring within the database manager during a query (`queryRecords`, `getLatestPublishRecord`, `getStats`).
Effect:   The error is logged, but it is not propagated to the caller. Instead, a default "empty" value (e.g., `[]`, `null`, or a zeroed object) is returned.
Evidence: EventHistory.ts:117 -- `logger.error({ error, query }, '查詢事件記錄失敗'); return []`

Contract: Swallowed Error in Record Operation
Category: E
Trigger:  An error occurring when trying to add a record via `recordOperation`.
Effect:   The error is logged and the operation fails silently without notifying the caller.
Evidence: EventHistory.ts:109 -- `logger.error({ error, operation, channel }, '記錄事件操作失敗')`

Contract: Background Cleanup Timer Cancellation
Category: C
Trigger:  Calling the `close()` method.
Effect:   The periodic `setInterval` timer for background cleanup is stopped and cleared.
Evidence: EventHistory.ts:203 -- `this.stopCleanupTimer()`

Contract: Dependency on Database Manager
Category: D
Trigger:  Almost every method call (`init`, `recordOperation`, `queryRecords`, `cleanup`, `close`, etc.).
Effect:   The class delegates all storage, retrieval, and deletion operations to an instance of `DatabaseManager`.
Evidence: EventHistory.ts:37 -- `this.dbManager = new DatabaseManager(...)`

Contract: Dependency on Logger
Category: D
Trigger:  Various state transitions, operations, and errors throughout the class.
Effect:   The class relies on a `logger` imported from `@91app/shared-provider` to output informational and error messages.
Evidence: EventHistory.ts:8 -- `import { logger } from '@91app/shared-provider'`

Contract: Configuration Update Requires Re-init
Category: L
Trigger:  Calling `updateOptions` and changing `databaseName` or `databaseVersion`.
Effect:   A warning is logged indicating that the module needs to be re-initialized for the change to take effect.
Evidence: EventHistory.ts:233 -- `logger.warn('資料庫名稱或版本變更需要重新初始化')`

Contract: State Exposure Through Getters
Category: P
Trigger:  Accessing the `initialized` or `enabled` properties.
Effect:   The internal state of the module (`isInitialized` flag, `options.enabled` value) is exposed to callers.
Evidence: EventHistory.ts:220 -- `get initialized(): boolean { return this.isInitialized; }`

TOTAL CONTRACTS FOUND: 15
CATEGORY BREAKDOWN: M=[4] L=[4] N=[0] S=[0] E=[3] C=[1] D=[3] P=[2]

## Section 4: Boundary Discovery

EXTERNAL_DEPENDENCY: `DatabaseManager` -- This class is instantiated and used for all database operations (init, close, add, query, cleanup). It's the primary downstream dependency for the entire lifecycle and data flow.
EXTERNAL_DEPENDENCY: `@91app/shared-provider` `logger` -- This is a global/singleton dependency used for all logging throughout the module.
EXTERNAL_DEPENDENCY: `@91app/trinity-kernel` `IEventHistory` -- This is an interface that the `EventHistory` class implements, indicating that other parts of the `trinity-kernel` system are the intended consumers of this module.
EXTERNAL_DEPENDENCY: `examples.ts` -- This file was identified in the static scan and likely contains example code showing how to instantiate and use the `EventHistory` class, making it a direct consumer.
EXTERNAL_DEPENDENCY: Callers of `recordOperation` -- Any module that calls `recordOperation` is a producer of the events being recorded. These are the primary inputs to the system.
EXTERNAL_DEPENDENCY: Callers of `queryRecords` -- Any module that calls `queryRecords` or `getLatestPublishRecord` is a consumer of the historical event data.
