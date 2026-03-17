## Feature Sketch（Step 0.8）

| # | 方法 | 行號 | 引用屬性 |
|---|------|------|---------|
| 1 | `constructor(options: EventHistoryOptions = {}) {` | EventHistory.ts:24 | this.dbManager,this.options |
| 2 | `async init(): Promise<void> {` | EventHistory.ts:43 | this.isInitialized |
| 3 | `if (this.isInitialized) {` | EventHistory.ts:44 | this.isInitialized,this.options |
| 4 | `if (!this.options.enabled) {` | EventHistory.ts:48 | this.dbManager,this.isInitialized,this.options,this.startCleanupTimer |
| 5 | `async recordOperation(` | EventHistory.ts:69 | this.isInitialized,this.options |
| 6 | `if (!this.isInitialized || !this.options.enabled) {` | EventHistory.ts:76 | this.dbManager,this.isInitialized,this.options |
| 7 | `async queryRecords(query: EventHistoryQuery): Promise<EventHistoryRecord[]> {` | EventHistory.ts:110 | this.isInitialized,this.options |
| 8 | `if (!this.isInitialized || !this.options.enabled) {` | EventHistory.ts:111 | this.dbManager,this.isInitialized,this.options |
| 9 | `async getLatestPublishRecord(` | EventHistory.ts:126 | this.isInitialized,this.options |
| 10 | `if (!this.isInitialized || !this.options.enabled) {` | EventHistory.ts:130 | this.dbManager,this.isInitialized,this.options |
| 11 | `async getStats(): Promise<EventHistoryStats> {` | EventHistory.ts:145 | this.isInitialized,this.options |
| 12 | `if (!this.isInitialized || !this.options.enabled) {` | EventHistory.ts:146 | this.dbManager,this.isInitialized,this.options |
| 13 | `async clear(): Promise<void> {` | EventHistory.ts:167 | this.isInitialized,this.options |
| 14 | `if (!this.isInitialized || !this.options.enabled) {` | EventHistory.ts:168 | this.dbManager,this.isInitialized,this.options |
| 15 | `async cleanup(): Promise<number> {` | EventHistory.ts:184 | this.isInitialized,this.options |
| 16 | `if (!this.isInitialized || !this.options.enabled) {` | EventHistory.ts:185 | this.dbManager,this.isInitialized,this.options |
| 17 | `if (deletedCount > 0) {` | EventHistory.ts:194 |  |
| 18 | `private startCleanupTimer(): void {` | EventHistory.ts:208 | this.cleanupTimer |
| 19 | `if (this.cleanupTimer) {` | EventHistory.ts:209 | this.cleanupTimer |
| 20 | `clearInterval(this.cleanupTimer)` | EventHistory.ts:210 | this.cleanup,this.cleanupTimer |
| 21 | `private stopCleanupTimer(): void {` | EventHistory.ts:226 | this.cleanupTimer |
| 22 | `if (this.cleanupTimer) {` | EventHistory.ts:227 | this.cleanupTimer |
| 23 | `clearInterval(this.cleanupTimer)` | EventHistory.ts:228 | this.cleanupTimer |
| 24 | `async close(): Promise<void> {` | EventHistory.ts:236 | this.isInitialized,this.stopCleanupTimer |
| 25 | `if (this.isInitialized) {` | EventHistory.ts:239 | this.dbManager,this.isInitialized,this.options |
| 26 | `updateOptions(newOptions: Partial<EventHistoryOptions>): void {` | EventHistory.ts:263 | this.options |
| 27 | `if (newOptions.databaseName || newOptions.databaseVersion) {` | EventHistory.ts:266 |  |

共 27 個方法。
