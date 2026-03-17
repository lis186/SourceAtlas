# Blind Contract Scout
# 盲掃合約發現者 -- 語言無關版本
# 此 prompt 由 Gemini 執行，獨立於主稽核者（Auditor）運作，不參考任何既有合約清單。

## ROLE

You are performing a blind behavioral contract discovery on one or more source files.
You have NO prior list of contract IDs. You are NOT trying to confirm anyone else's work.
Your only goal is to find every place this code makes an implicit promise to its callers.

The target code may be written in any language (`typescript`). Adapt your analysis accordingly.

## WHAT TO LOOK FOR

Scan for all eight categories of behavioral contracts:

| Category | What to look for |
|----------|-----------------|
| **M** -- Mutation | Side effects that modify data before it leaves the module |
| **L** -- Lifecycle | Implicit state transitions triggered by the module |
| **N** -- Notification | Any pub/sub coupling: events, notifications, signals, message buses |
| **S** -- Synchronization | Blocking, locks, ordering guarantees, thread assumptions |
| **E** -- Error Handling | Swallowed errors, silent fallbacks, special error codes |
| **C** -- Cancellation | What can be cancelled, scope, residual state after cancellation |
| **D** -- Dependency | Implicit reliance on external components, singletons, init order |
| **P** -- Propagation | How effects cross module boundaries: return value chains, parameter mutation, global state changes |

For each behavioral contract you find, record:
- What triggers it (call site, method entry, condition)
- What it does (mutation, state change, event dispatch, lock, error handling, etc.)
- Exact filename and line number
- One-sentence description

## OUTPUT FORMAT

For each contract:

```
Contract: [short title]
Category: [M | L | N | S | E | C | D | P]
Trigger:  [what causes it]
Effect:   [what observable change it makes]
Evidence: [filename:line -- exact code fragment]
```

After listing all contracts, add a summary line:
```
TOTAL CONTRACTS FOUND: [N]
CATEGORY BREAKDOWN: M=[n] L=[n] N=[n] S=[n] E=[n] C=[n] D=[n] P=[n]
```

## Section 4: Boundary Discovery

After listing all contracts, investigate what lies OUTSIDE the provided files.
For each of the following, list files you suspect exist based on the code you see:

1. **Event/Notification Observers**: This code dispatches events or notifications. What classes or modules likely observe them?
   Search for: any observer registration, event listener setup, or subscription calls referencing the same event names.

2. **External Synchronization**: This code uses synchronization primitives (locks, semaphores, actors, mutexes, async barriers). Are there other classes with similar patterns?

3. **Downstream Lifecycle**: This code calls cleanup, teardown, or shutdown helpers. What classes implement them?

4. **Singleton / Global State**: This code reads or writes shared global state. What other modules depend on the same state?

5. **Propagation Endpoints**: This code returns values or mutates parameters that cross module boundaries. What are the likely consumers?

For each finding, output:
```
EXTERNAL_DEPENDENCY: [suspected filename or class/module name] -- [reason / what event or call triggers it]
```

If you cannot find evidence, output:
```
EXTERNAL_DEPENDENCY: (none found)
```

## INSTRUCTIONS

- Read every line of the provided source file(s). Do not skip sections.
- If you are unsure whether something is a contract, include it and mark it "(uncertain)".
- Do NOT use contract IDs from any other document. Assign no IDs.
- Do NOT produce verification scripts or ast-grep rules. Discovery only.
- Adapt your analysis to `typescript` idioms -- for example, use language-appropriate terminology for events, notifications, lifecycle hooks, and synchronization primitives.



## Step 0 Discovery Note
The following related files were found by static scan (not included in full -- reference them in Section 4):
- /Users/justinlee/dev/matrix/libs/event-history/src/DatabaseManager.ts
- /Users/justinlee/dev/matrix/libs/event-history/src/examples.ts
/**
 * EventHistory 主要類別
 * 提供事件歷史記錄的核心功能
 */

import { logger } from '@91app/shared-provider'
import type { IEventHistory } from '@91app/trinity-kernel'
import {
	EventHistoryOptions,
	EventHistoryRecord,
	EventHistoryQuery,
	EventHistoryStats,
	EventPayload,
	EventOperation,
} from './types'
import { DatabaseManager } from './DatabaseManager'

export class EventHistory implements IEventHistory {
	private dbManager: DatabaseManager
	private options: Required<EventHistoryOptions>
	private cleanupTimer?: NodeJS.Timeout
	private isInitialized = false

	constructor(options: EventHistoryOptions = {}) {
		this.options = {
			retentionTime: 300000, // 5分鐘
			maxRecords: 1000,
			enabled: true,
			databaseName: 'EventHistory',
			databaseVersion: 1,
			...options,
		}

		this.dbManager = new DatabaseManager(
			this.options.databaseName,
			this.options.databaseVersion,
		)
	}

	/**
	 * 初始化 EventHistory
	 */
	async init(): Promise<void> {
		if (this.isInitialized) {
			return
		}

		if (!this.options.enabled) {
			logger.info('EventHistory 已停用')
			return
		}

		try {
			await this.dbManager.init()
			this.isInitialized = true
			logger.info('EventHistory 初始化成功')

			// 啟動定期清理
			this.startCleanupTimer()
		} catch (error) {
			logger.error({ error }, 'EventHistory 初始化失敗')
			throw error
		}
	}

	/**
	 * 記錄事件操作
	 */
	async recordOperation(
		operation: EventOperation,
		channel: string,
		event?: EventPayload,
		from?: string,
		targetEvent?: string[],
	): Promise<void> {
		if (!this.isInitialized || !this.options.enabled) {
			return
		}

		try {
			const record: Omit<EventHistoryRecord, 'id'> = {
				operation,
				channel,
				eventType: event?.type,
				event,
				timestamp: Date.now(),
				from,
				targetEvent,
			}

			await this.dbManager.addRecord(record)

			logger.trace(
				{
					operation,
					channel,
					eventType: event?.type,
					from,
				},
				'記錄事件操作',
			)
		} catch (error) {
			logger.error({ error, operation, channel }, '記錄事件操作失敗')
		}
	}

	/**
	 * 查詢事件記錄
	 */
	async queryRecords(query: EventHistoryQuery): Promise<EventHistoryRecord[]> {
		if (!this.isInitialized || !this.options.enabled) {
			return []
		}

		try {
			return await this.dbManager.queryRecords(query)
		} catch (error) {
			logger.error({ error, query }, '查詢事件記錄失敗')
			return []
		}
	}

	/**
	 * 獲取特定頻道的最新發布記錄
	 */
	async getLatestPublishRecord(
		channel: string,
		eventType?: string,
	): Promise<EventHistoryRecord | null> {
		if (!this.isInitialized || !this.options.enabled) {
			return null
		}

		try {
			return await this.dbManager.getLatestRecord(channel, eventType)
		} catch (error) {
			logger.error({ error, channel, eventType }, '獲取最新發布記錄失敗')
			return null
		}
	}

	/**
	 * 獲取統計資訊
	 */
	async getStats(): Promise<EventHistoryStats> {
		if (!this.isInitialized || !this.options.enabled) {
			return {
				totalRecords: 0,
				channelCount: 0,
			}
		}

		try {
			return await this.dbManager.getStats()
		} catch (error) {
			logger.error({ error }, '獲取統計資訊失敗')
			return {
				totalRecords: 0,
				channelCount: 0,
			}
		}
	}

	/**
	 * 清空所有記錄
	 */
	async clear(): Promise<void> {
		if (!this.isInitialized || !this.options.enabled) {
			return
		}

		try {
			await this.dbManager.clearAllRecords()
			logger.info('EventHistory 已清空所有記錄')
		} catch (error) {
			logger.error({ error }, '清空記錄失敗')
			throw error
		}
	}

	/**
	 * 清理過期記錄
	 */
	async cleanup(): Promise<number> {
		if (!this.isInitialized || !this.options.enabled) {
			return 0
		}

		try {
			const deletedCount = await this.dbManager.cleanupExpiredRecords(
				this.options.retentionTime,
			)

			if (deletedCount > 0) {
				logger.info({ deletedCount }, '清理過期記錄')
			}

			return deletedCount
		} catch (error) {
			logger.error({ error }, '清理過期記錄失敗')
			return 0
		}
	}

	/**
	 * 啟動定期清理計時器
	 */
	private startCleanupTimer(): void {
		if (this.cleanupTimer) {
			clearInterval(this.cleanupTimer)
		}

		// 每分鐘檢查一次是否需要清理
		this.cleanupTimer = setInterval(async () => {
			try {
				await this.cleanup()
			} catch (error) {
				logger.error({ error }, '定期清理失敗')
			}
		}, 60000)
	}

	/**
	 * 停止定期清理計時器
	 */
	private stopCleanupTimer(): void {
		if (this.cleanupTimer) {
			clearInterval(this.cleanupTimer)
			this.cleanupTimer = undefined
		}
	}

	/**
	 * 關閉 EventHistory
	 */
	async close(): Promise<void> {
		this.stopCleanupTimer()

		if (this.isInitialized) {
			this.dbManager.close()
			this.isInitialized = false
			logger.info('EventHistory 已關閉')
		}
	}

	/**
	 * 檢查是否已初始化
	 */
	get initialized(): boolean {
		return this.isInitialized
	}

	/**
	 * 檢查是否啟用
	 */
	get enabled(): boolean {
		return this.options.enabled
	}

	/**
	 * 更新選項
	 */
	updateOptions(newOptions: Partial<EventHistoryOptions>): void {
		this.options = { ...this.options, ...newOptions }

		if (newOptions.databaseName || newOptions.databaseVersion) {
			logger.warn('資料庫名稱或版本變更需要重新初始化')
		}
	}
}
