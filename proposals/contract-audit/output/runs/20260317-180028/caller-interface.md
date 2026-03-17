## Caller Interface Extract（Step 0.9）

外部模組引用 EventHistory 的片段（±5 行上下文）：

### DatabaseManager.ts (10 references)
```
1-/**
2- * IndexedDB 資料庫管理器
3: * 負責管理 EventHistory 的資料庫操作
4- */
5-
6:import { EventHistoryRecord, EventHistoryQuery, EventHistoryStats } from './types'
7-
8-export class DatabaseManager {
9-	private db: IDBDatabase | null = null
10-	private dbName: string
11-	private dbVersion: number
12-	private storeName = 'eventHistory'
13-
14:	constructor(dbName: string = 'EventHistory', dbVersion: number = 1) {
15-		this.dbName = dbName
16-		this.dbVersion = dbVersion
17-	}
18-
19-	/**
--
63-	}
64-
65-	/**
66-	 * 新增事件記錄
67-	 */
68:	async addRecord(record: Omit<EventHistoryRecord, 'id'>): Promise<number> {
69-		const db = this.ensureDb()
70-
71-		return new Promise((resolve, reject) => {
72-			const transaction = db.transaction([this.storeName], 'readwrite')
73-			const store = transaction.objectStore(this.storeName)
--
84-	}
85-
86-	/**
87-	 * 查詢事件記錄
88-	 */
89:	async queryRecords(query: EventHistoryQuery): Promise<EventHistoryRecord[]> {
90-		const db = this.ensureDb()
91-
92-		return new Promise((resolve, reject) => {
93-			const transaction = db.transaction([this.storeName], 'readonly')
94-			const store = transaction.objectStore(this.storeName)
95-
96:			let request: IDBRequest<EventHistoryRecord[]>
97-
98-			if (query.channel && query.startTime !== undefined && query.endTime !== undefined) {
99-				// 使用複合索引查詢特定頻道和時間範圍
100-				const index = store.index('channel_timestamp')
101-				const range = IDBKeyRange.bound(
--
163-	}
164-
165-	/**
166-	 * 獲取特定頻道的最新記錄
167-	 */
168:	async getLatestRecord(channel: string, eventType?: string): Promise<EventHistoryRecord | null> {
169:		const query: EventHistoryQuery = {
170-			channel,
171-			eventType,
172-			operation: 'publish',
173-			limit: 1,
174-		}
--
224-	}
225-
226-	/**
227-	 * 獲取資料庫統計資訊
228-	 */
229:	async getStats(): Promise<EventHistoryStats> {
230-		const db = this.ensureDb()
231-
232-		return new Promise((resolve, reject) => {
233-			const transaction = db.transaction([this.storeName], 'readonly')
234-			const store = transaction.objectStore(this.storeName)
--
238-			Promise.all([
239-				new Promise<number>((res, rej) => {
240-					countRequest.onsuccess = () => res(countRequest.result)
241-					countRequest.onerror = () => rej(countRequest.error)
242-				}),
243:				new Promise<EventHistoryRecord[]>((res, rej) => {
244-					getAllRequest.onsuccess = () => res(getAllRequest.result || [])
245-					getAllRequest.onerror = () => rej(getAllRequest.error)
246-				}),
247-			])
248-				.then(([totalRecords, records]) => {
```

### examples.ts (13 references)
```
1-/**
2- * Event History 使用範例
3- */
4-
5:import { EventHistory } from './index'
6:import { IEventHistory } from '@91app/trinity-kernel'
7-
8:// 範例 1: 基本使用 EventHistory
9:async function basicEventHistoryExample() {
10:	console.log('=== 基本使用 EventHistory 範例 ===')
11-
12:	const eventHistory = new EventHistory({
13-		retentionTime: 600000, // 10分鐘
14-		maxRecords: 500,
15:		databaseName: 'MyAppEventHistory',
16-	})
17-
18-	await eventHistory.init()
19-
20-	// 記錄一些操作
--
48-}
49-
50-// 執行範例
51-async function runExamples() {
52-	try {
53:		await basicEventHistoryExample()
54-		await eventEmitterIntegrationExample()
55-	} catch (error) {
56-		console.error('範例執行失敗:', error)
57-	}
58-}
--
64-
65-// 範例 2: 與 EventEmitter 整合範例
66-async function eventEmitterIntegrationExample() {
67-	console.log('=== EventEmitter 整合範例 ===')
68-
69:	// 建立 EventHistory 實例
70:	const eventHistory = new EventHistory({
71-		retentionTime: 600000, // 10分鐘
72-		maxRecords: 500,
73-		databaseName: 'EventEmitterHistory',
74-	})
75-
76-	await eventHistory.init()
77-
78:	// 模擬 EventEmitter 使用 IEventHistory
79-	const mockEventEmitter = {
80:		eventHistory: eventHistory as IEventHistory,
81-
82-		async subscribe(channel: string, listener: Function) {
83-			// 記錄訂閱操作
84-			await this.eventHistory.recordOperation('subscribe', channel)
85-			console.log(`已訂閱頻道: ${channel}`)
--
109-	}
110-
111-	await eventHistory.close()
112-}
113-
114:export { basicEventHistoryExample, eventEmitterIntegrationExample }
```

