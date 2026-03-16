Contract: Initialization State Gate
Category: L
Trigger:  Calling any method before `init()` has successfully completed.
Effect:   Most methods will return early with default/empty values or do nothing if the `isInitialized` flag is false.
Evidence: EventHistory.ts:94 -- `if (!this.isInitialized || !this.options.enabled) { return; }`

Contract: Silent Operation Failure
Category: E
Trigger:  An error occurring during the `dbManager.addRecord(record)` call.
Effect:   The error is caught, logged, and then suppressed. The caller of `recordOperation` is not notified of the failure.
Evidence: EventHistory.ts:114 -- `} catch (error) { logger.error({ error, operation, channel }, '記錄事件操作失敗'); }`

Contract: Silent Query Failure
Category: E
Trigger:  An error occurring while querying the database via `dbManager.queryRecords(query)`.
Effect:   The error is caught, logged, and an empty array `[]` is returned, masking the underlying problem from the caller.
Evidence: EventHistory.ts:128 -- `} catch (error) { logger.error({ error, query }, '查詢事件記錄失敗'); return []; }`

Contract: Silent Stats Failure
Category: E
Trigger:  An error occurring while fetching statistics from the database.
Effect:   The error is caught, logged, and a default object with zeroed-out stats is returned.
Evidence: EventHistory.ts:162 -- `} catch (error) { logger.error({ error }, '獲取統計資訊失敗'); return { totalRecords: 0, channelCount: 0 }; }`

Contract: Background Data Pruning
Category: L
Trigger:  Successful completion of the `init()` method.
Effect:   A timer (`setInterval`) is started to periodically call the `cleanup()` method every 60 seconds, which purges old records from the database.
Evidence: EventHistory.ts:205 -- `this.cleanupTimer = setInterval(async () => { ... }, 60000)`

Contract: Graceful Shutdown
Category: L
Trigger:  Calling the `close()` method.
Effect:   The background cleanup timer is stopped, the database connection is closed, and the `isInitialized` flag is set to false, effectively shutting down the module.
Evidence: EventHistory.ts:223 -- `async close(): Promise<void> { this.stopCleanupTimer(); ... }`

Contract: Record Creation
Category: M
Trigger:  Calling `recordOperation` when the module is initialized and enabled.
Effect:   A new event record is created and persisted to the database via `dbManager.addRecord`.
Evidence: EventHistory.ts:106 -- `await this.dbManager.addRecord(record)`

Contract: Record Deletion (Cleanup)
Category: M
Trigger:  Calling the `cleanup()` method, which is also triggered by an internal timer.
Effect:   Records older than `options.retentionTime` are deleted from the database.
Evidence: EventHistory.ts:187 -- `const deletedCount = await this.dbManager.cleanupExpiredRecords( this.options.retentionTime, )`

Contract: Dependency on Database Manager
Category: D
Trigger:  Instantiation of the `EventHistory` class.
Effect:   An instance of `DatabaseManager` is created and used for all database operations (init, add, query, clear, close).
Evidence: EventHistory.ts:29 -- `this.dbManager = new DatabaseManager(...)`

Contract: Dependency on Shared Logger
Category: D
Trigger:  Any logging action (e.g., info, error, trace).
Effect:   The module implicitly relies on the global/shared `logger` from `@91app/shared-provider` to be configured and available.
Evidence: EventHistory.ts:7 -- `import { logger } from '@91app/shared-provider'`

Contract: Data Propagation on Query
Category: P
Trigger:  Calling `queryRecords(query)`.
Effect:   The results from the database query are returned directly to the caller.
Evidence: EventHistory.ts:125 -- `return await this.dbManager.queryRecords(query)`

Contract: Hot-Swappable Options
Category: M
Trigger:  Calling `updateOptions(newOptions)`.
Effect:   Internal configuration properties like `retentionTime` and `enabled` are mutated at runtime, affecting subsequent operations.
Evidence: EventHistory.ts:245 -- `this.options = { ...this.options, ...newOptions }`

TOTAL CONTRACTS FOUND: 12
CATEGORY BREAKDOWN: M=[3] L=[3] N=[0] S=[0] E=[3] C=[0] D=[2] P=[1]

## Section 4: Boundary Discovery

EXTERNAL_DEPENDENCY: /Users/justinlee/dev/matrix/libs/event-history/src/DatabaseManager.ts -- This class is instantiated and its methods (`init`, `addRecord`, `queryRecords`, `getStats`, `clearAllRecords`, `cleanupExpiredRecords`, `close`) are called directly by `EventHistory`.
EXTERNAL_DEPENDENCY: `@91app/shared-provider` -- The global `logger` is imported from this module and used for all logging.
EXTERNAL_DEPENDENCY: `@91app/trinity-kernel` -- The `IEventHistory` interface is implemented, implying `EventHistory` is consumed by a larger system or framework that depends on this kernel.
EXTERNAL_DEPENDENCY: /Users/justinlee/dev/matrix/libs/event-history/src/examples.ts -- This file likely contains example code demonstrating how to instantiate and use the `EventHistory` class, making it a consumer.
