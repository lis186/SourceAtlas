# Language Plugin: TypeScript
# Contract Audit 語言插件 -- TypeScript / Node.js / Frontend
# Version: 2.0

---

## 適用範圍

- 純 TypeScript 模組（`.ts` / `.tsx`）
- Node.js 後端（Express, NestJS, Fastify）
- 前端框架（React, Angular, Vue）
- 全端應用（Next.js, Nuxt, SvelteKit）
- Deno / Bun 環境

---

## 1. 通知/事件原語

### EventEmitter (Node.js)
```typescript
class OrderService extends EventEmitter {
  async placeOrder(order: Order): Promise<void> {
    await this.repository.save(order);
    this.emit("orderPlaced", { orderId: order.id, total: order.total });
  }
}

// 觀察端
orderService.on("orderPlaced", (data) => {
  notificationService.send(data.orderId); // 假設 data 包含 orderId
});
```

稽核要點：
- 事件名稱是字串——拼寫錯誤不會產生編譯錯誤，只是靜默不觸發
- `emit` 的 payload 型別無法由 TypeScript 預設推斷（除非使用 typed-emitter 或手動宣告 interface）
- `on` vs `once` 語義不同——`once` 只觸發一次後自動移除
- `removeListener` / `off` 必須傳入**同一個函式參考**，匿名函式無法被移除
- `maxListeners` 預設為 10——超過會印出警告但不報錯

### CustomEvent / addEventListener (Browser)
```typescript
window.addEventListener("storage", (event: StorageEvent) => {
  if (event.key === "authToken") {
    this.handleTokenChange(event.newValue);
  }
});

element.dispatchEvent(new CustomEvent("formSubmit", { detail: { valid: true } }));
```

稽核要點：
- `addEventListener` 的第三個參數（`capture` / `passive` / `once`）是隱含合約
- `removeEventListener` 必須傳入**完全相同的函式參考和 options**
- `CustomEvent.detail` 的型別是 `any`——消費端的型別假設是隱含合約
- 事件冒泡（bubbling）與捕獲（capture）階段的順序是合約

### RxJS Subject / Observable
```typescript
private destroy$ = new Subject<void>();

ngOnInit() {
  this.dataService.getData()
    .pipe(takeUntil(this.destroy$))
    .subscribe(data => this.data = data);
}

ngOnDestroy() {
  this.destroy$.next();
  this.destroy$.complete();
}
```

稽核要點：
- `Subject` vs `BehaviorSubject` vs `ReplaySubject` 的語義差異是合約——新訂閱者是否收到歷史值
- `takeUntil` 的位置必須在 pipe 鏈最後，否則中間 operator 的訂閱不會被清理
- `subscribe` 回傳的 `Subscription` 未 `unsubscribe` = 記憶體洩漏
- `switchMap` vs `mergeMap` vs `concatMap` 的取消/並行語義是順序合約

### WebSocket Message
```typescript
const ws = new WebSocket("wss://api.example.com/ws");
ws.onmessage = (event: MessageEvent) => {
  const data = JSON.parse(event.data); // 假設 event.data 是有效 JSON
  this.handleMessage(data);
};
```

稽核要點：
- `JSON.parse` 可能拋出例外——是否有 try/catch 是錯誤處理合約
- 訊息格式（schema）是跨系統隱含合約
- 重連邏輯和心跳機制是生命週期合約
- `ws.readyState` 的狀態機（CONNECTING / OPEN / CLOSING / CLOSED）是合約

---

## 2. 同步原語

### Promise
```typescript
function fetchWithTimeout(url: string, ms: number): Promise<Response> {
  return Promise.race([
    fetch(url),
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error("timeout")), ms)
    ),
  ]);
}
```

稽核要點：
- `Promise.race` 中未完成的 Promise 不會被取消——只是結果被忽略，副作用仍執行
- `Promise.all` 中任一 reject 會導致整體 reject——其他 Promise 的副作用仍繼續
- `Promise.allSettled` vs `Promise.all` 的錯誤處理語義不同
- 未處理的 rejection 在 Node.js 中會導致 `unhandledRejection` 事件（Node 15+ 預設終止程序）

### async/await
```typescript
async function processItems(items: Item[]): Promise<void> {
  for (const item of items) {
    await processItem(item); // 循序執行
  }
  // vs
  await Promise.all(items.map(item => processItem(item))); // 並行執行
}
```

稽核要點：
- `for...of` + `await` 是循序執行，`Promise.all` + `map` 是並行——行為差異巨大
- `forEach` 不等待 async callback——這是常見的隱含合約陷阱
- `try/catch` 的範圍決定錯誤處理合約——一個 catch 包全部 vs 逐個 catch
- `await` 在非 async 函式中使用會產生編譯錯誤，但 `Promise` 不 `await` 只會靜默丟失結果

### Worker Threads (Node.js)
```typescript
const worker = new Worker("./processor.js", { workerData: { items } });
worker.on("message", (result) => { /* ... */ });
worker.on("error", (err) => { /* ... */ });
worker.on("exit", (code) => { /* ... */ });
```

稽核要點：
- Worker 與主執行緒之間透過結構化克隆（structured clone）傳遞資料——函式和 class instance 無法傳遞
- `SharedArrayBuffer` + `Atomics` 是 TypeScript 中唯一的真正共享記憶體——需要特別小心的同步
- Worker 的 `error` 事件未處理可能導致靜默失敗

### Mutex（透過套件）
```typescript
import { Mutex } from "async-mutex";

const mutex = new Mutex();

async function criticalSection(): Promise<void> {
  const release = await mutex.acquire();
  try {
    await sharedResource.update();
  } finally {
    release();
  }
}
```

稽核要點：
- TypeScript/JavaScript 的單執行緒模型意味著同步程式碼不需要 mutex
- Mutex 只在 `await` 交錯的非同步情境中才有意義
- `finally` 中的 `release()` 是關鍵合約——未釋放會導致永久阻塞

---

## 3. 生命週期模式

### React Lifecycle (Hooks)
```typescript
useEffect(() => {
  const controller = new AbortController();
  fetchData(controller.signal);

  return () => {
    controller.abort(); // cleanup
  };
}, [dependency]);
```

稽核要點：
- `useEffect` 的 cleanup 函式在元件卸載和 dependency 變更時執行
- dependency array 為空 `[]` 表示只在 mount 執行一次，省略則每次 render 執行
- dependency array 的內容是合約——遺漏 dependency 會導致 stale closure
- `AbortController` 的 abort 呼叫是取消合約——fetch 和其他支援 signal 的 API 會拋出 `AbortError`

### React Lifecycle (Class Components)
```typescript
class DataComponent extends React.Component<Props, State> {
  componentDidMount() {
    this.subscription = dataService.subscribe(this.handleData);
  }

  componentWillUnmount() {
    this.subscription?.unsubscribe(); // 清理合約
  }

  componentDidUpdate(prevProps: Props) {
    if (prevProps.id !== this.props.id) {
      this.refetch(); // 隱含合約：id 變更觸發重新取得
    }
  }
}
```

稽核要點：
- `componentWillUnmount` 中的清理是合約——未清理會導致記憶體洩漏或「已卸載元件設定 state」警告
- `componentDidUpdate` 中的條件判斷是合約——遺漏判斷會導致無限迴圈
- `setState` 是非同步的——在 `setState` 之後立即讀取 state 會得到舊值

### Angular Lifecycle
```typescript
@Component({ selector: "app-data", template: "..." })
export class DataComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  ngOnInit() {
    this.service.getData()
      .pipe(takeUntil(this.destroy$))
      .subscribe(data => this.data = data);
  }

  ngOnDestroy() {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

稽核要點：
- `OnInit` / `OnDestroy` 是 interface——不實作 `ngOnDestroy` 不會編譯錯誤，但訂閱不會被清理
- Angular 的 DI 系統（`providedIn: 'root'` vs module-scoped）決定 service 的生命週期
- `ChangeDetectionStrategy.OnPush` 改變了元件更新的觸發條件——是效能與正確性的合約

### Express Middleware Chain (Node.js)
```typescript
app.use(cors());
app.use(express.json());
app.use(authMiddleware);  // 順序是合約——必須在路由之前
app.use("/api", router);
app.use(errorHandler);    // 必須在最後
```

稽核要點：
- middleware 的註冊順序是關鍵合約——`authMiddleware` 必須在受保護路由之前
- `next()` 的呼叫與否決定請求是否繼續——遺漏 `next()` 會導致請求掛起
- error middleware 必須有四個參數 `(err, req, res, next)` 才會被 Express 識別為 error handler
- `express.json()` 的 body 解析在 `authMiddleware` 之前或之後影響認證邏輯

### Node.js Process Events
```typescript
process.on("uncaughtException", (err) => {
  logger.fatal(err);
  process.exit(1); // 隱含合約：必須退出，否則程序處於不確定狀態
});

process.on("SIGTERM", async () => {
  await server.close();    // graceful shutdown 合約
  await db.disconnect();
  process.exit(0);
});
```

稽核要點：
- `uncaughtException` handler 之後繼續執行是危險的——程序狀態不確定
- `SIGTERM` / `SIGINT` handler 的清理順序是合約
- `beforeExit` vs `exit` 事件的語義不同——`exit` 中不能執行非同步操作
- `unhandledRejection` 在 Node 15+ 預設終止程序

---

## 4. 驗證策略

**ast-grep: 完整支援。**

TypeScript 是 ast-grep 的一級支援語言。所有合約應優先使用 ast-grep 規則驗證。

### ast-grep 規則撰寫指南

```yaml
id: n1-event-emitter-emit
message: "N1: orderPlaced event emission -- contract must be present"
severity: error
language: TypeScript
rule:
  pattern: |
    this.emit("orderPlaced", $PAYLOAD)
```

**Pattern 注意事項：**
- 使用 `$VAR` 匹配單一節點，`$$$` 匹配多節點序列
- TypeScript 的型別註解是 AST 的一部分——pattern 中可以包含或省略型別
- JSX/TSX 需要特別處理——`<Component prop={value} />` 中的大括號是 AST 節點
- 對於 decorator（`@Component`、`@Injectable`），使用 `kind: decorator` 節點匹配
- 泛型參數（`Promise<T>`）在 pattern 中用 `$TYPE` 匹配

### TypeScript 專用 ast-grep 技巧

```yaml
# 匹配 useEffect 帶 cleanup
id: l1-useeffect-cleanup
message: "L1: useEffect cleanup function -- contract must be present"
severity: error
language: TypeScript
rule:
  kind: call_expression
  all:
    - has:
        regex: "useEffect"
    - has:
        kind: arrow_function
        has:
          kind: return_statement
```

```yaml
# 匹配 async 函式的 try/catch
id: e1-async-error-handling
message: "E1: async error handling -- contract must be present"
severity: error
language: TypeScript
rule:
  kind: function_declaration
  all:
    - has:
        regex: "async"
    - has:
        kind: try_statement
```

### grep 作為補充

某些合約可能更適合用 grep 驗證（例如字串常量、事件名稱、環境變數）。語言插件不禁止使用 grep，但 ast-grep 應為首選。

---

## 5. Effect 防火牆

**強度：弱（僅型別層）。**

TypeScript 的不可變性保證僅存在於型別系統層面，runtime 完全沒有強制力：

### readonly 修飾器
```typescript
interface Config {
  readonly apiKey: string;
  readonly timeout: number;
}

const config: Config = { apiKey: "abc", timeout: 3000 };
config.apiKey = "xyz"; // 編譯錯誤，但 runtime 不阻止
```
- `readonly` 是淺層的——巢狀 object 的 property 仍可變
- `as const` 是深層的——但只在型別層面
- runtime 可以透過 `(config as any).apiKey = "xyz"` 繞過

### as const 斷言
```typescript
const ROUTES = {
  HOME: "/",
  ABOUT: "/about",
  API: "/api/v1",
} as const;
// type: { readonly HOME: "/"; readonly ABOUT: "/about"; readonly API: "/api/v1" }
```
- 將所有 property 遞迴標記為 `readonly`，將值收窄為 literal type
- 僅存在於編譯期——JavaScript runtime 中 `as const` 完全不存在

### Readonly<T> / ReadonlyArray<T>
```typescript
function processItems(items: ReadonlyArray<Item>): void {
  items.push(newItem); // 編譯錯誤
  items[0].name = "modified"; // 編譯通過！ -- 淺層保護
}
```
- `Readonly<T>` 只保護第一層 property
- `ReadonlyArray<T>` 移除了 `push`、`pop`、`splice` 等方法的型別定義
- `DeepReadonly<T>` 需要自定義 utility type 或第三方套件

### Object.freeze()
```typescript
const frozen = Object.freeze({ key: "value", nested: { mutable: true } });
frozen.key = "new"; // runtime 靜默失敗（strict mode 下拋出 TypeError）
frozen.nested.mutable = false; // 成功！ -- freeze 是淺層的
```
- 這是 TypeScript 中唯一有 runtime 效果的不可變性機制
- 但 `Object.freeze` 是淺層的——巢狀物件不受保護

**稽核影響：**
- 不可信任 `readonly` 作為 runtime 保證——任何 `as any` 轉型都能繞過
- 必須追蹤所有 object reference 的共享路徑，特別是跨模組傳遞的物件
- `Object.freeze` 是唯一有 runtime 效果的手段，但只保護淺層
- 在重構中移除 `readonly` 標記不會產生 runtime 錯誤，但會破壞型別合約

---

## 6. Seam 類型

### Object Seam（interface / abstract class / 依賴注入）

#### Interface
```typescript
interface HttpClient {
  get<T>(url: string): Promise<T>;
  post<T>(url: string, body: unknown): Promise<T>;
}

class FetchHttpClient implements HttpClient {
  async get<T>(url: string): Promise<T> { /* ... */ }
  async post<T>(url: string, body: unknown): Promise<T> { /* ... */ }
}
```

- TypeScript interface 是結構型別（structural typing）——任何形狀匹配的物件都滿足 interface，不需要明確 `implements`
- 這意味著重構時移除一個方法可能不會產生編譯錯誤，只要沒有程式碼明確宣告 `implements`

#### Abstract Class
```typescript
abstract class BaseRepository<T> {
  abstract findById(id: string): Promise<T | null>;
  abstract save(entity: T): Promise<void>;

  async findOrThrow(id: string): Promise<T> {
    const entity = await this.findById(id);
    if (!entity) throw new Error(`Not found: ${id}`);
    return entity;
  }
}
```

- abstract class 同時提供介面定義和共享實作——共享實作本身是隱含合約
- 子類別可能依賴 `findOrThrow` 的錯誤拋出行為

#### 依賴注入（Angular DI / InversifyJS）
```typescript
// Angular
@Injectable({ providedIn: "root" })
class AuthService {
  constructor(private http: HttpClient) {}
}

// InversifyJS
container.bind<HttpClient>(TYPES.HttpClient).to(FetchHttpClient);
```

- DI container 的綁定配置是隱含合約——`providedIn: 'root'` vs module scope 決定 singleton 或多實例
- 替換實作時必須滿足相同的行為合約，不只是型別

### Preprocessing Seam（環境變數 / 編譯時替換）

```typescript
// 環境變數
if (process.env.NODE_ENV === "production") {
  enableAnalytics();
}

// webpack DefinePlugin / Vite define
if (import.meta.env.VITE_FEATURE_FLAG === "true") {
  enableNewFeature();
}

// tsconfig paths
// tsconfig.json: { "paths": { "@api/*": ["src/api/*"] } }
import { UserService } from "@api/user-service";
```

- `process.env` 的值在 runtime 是 `string | undefined`——型別假設是隱含合約
- `DefinePlugin` 在編譯時進行字串替換——替換後的程式碼行為可能與原始碼不同
- 環境變數的存在性是隱含合約——缺少環境變數通常產生 `undefined` 而非明確錯誤

### Link Seam（模組別名 / 模組替換）

```typescript
// tsconfig paths -- 編譯時模組解析
// { "paths": { "@core/*": ["src/core/*"] } }
import { Logger } from "@core/logger";

// webpack resolve.alias -- 打包時模組替換
// resolve: { alias: { "legacy-auth": path.resolve("src/new-auth") } }

// Jest moduleNameMapper -- 測試時模組替換
// { "moduleNameMapper": { "^@api/(.*)$": "<rootDir>/src/__mocks__/api/$1" } }

// package.json "browser" field -- 打包時條件替換
// { "browser": { "./src/crypto-node.ts": "./src/crypto-browser.ts" } }
```

- 模組別名在不同環境（開發、測試、生產）可能解析到不同實作——這是隱含合約
- `moduleNameMapper` 替換可能導致測試通過但生產環境失敗
- `browser` field 替換是 Node.js vs 瀏覽器的行為差異來源

---

## 7. Sprout/Wrap 策略

所有四種 Feathers 策略均適用於 TypeScript，且有語言特定的優勢：

### Sprout Method
```typescript
// Before
async function handleOrder(order: Order): Promise<OrderResult> {
  // 200 lines of mixed logic
}

// After
async function handleOrder(order: Order): Promise<OrderResult> {
  const validated = validateOrder(order); // sprouted
  // remaining logic
}

// Sprouted function -- independently testable, pure function
function validateOrder(order: Order): ValidatedOrder {
  if (!order.items.length) throw new ValidationError("empty");
  return { ...order, validated: true } as ValidatedOrder;
}
```

**TypeScript 優勢：** 獨立函式（非方法）天然適合單元測試，不需要實例化 class

### Sprout Class
```typescript
// 新增獨立 class，不修改舊程式碼
class OrderValidator {
  constructor(private rules: ValidationRule[]) {}

  validate(order: Order): ValidatedOrder {
    for (const rule of this.rules) {
      rule.check(order);
    }
    return { ...order, validated: true } as ValidatedOrder;
  }
}
```

**TypeScript 優勢：** 可以利用泛型和 interface 讓 Sprout Class 從一開始就具備良好的抽象

### Wrap Method（Proxy / Higher-Order Function）

#### Higher-Order Function
```typescript
function withLogging<T extends (...args: any[]) => any>(fn: T): T {
  return ((...args: Parameters<T>): ReturnType<T> => {
    console.log(`Calling ${fn.name} with`, args);
    const result = fn(...args);
    console.log(`Result:`, result);
    return result;
  }) as T;
}

const loggedFetch = withLogging(fetchData);
```

#### Proxy
```typescript
const loggingProxy = new Proxy(originalService, {
  get(target, prop, receiver) {
    const value = Reflect.get(target, prop, receiver);
    if (typeof value === "function") {
      return (...args: unknown[]) => {
        console.log(`${String(prop)} called`);
        return value.apply(target, args);
      };
    }
    return value;
  },
});
```

**TypeScript 優勢：** 泛型讓 higher-order function 保留原始函式的型別簽名

### Wrap Class（Decorator Pattern / Class Extends）

#### Decorator Pattern
```typescript
class CachingHttpClient implements HttpClient {
  constructor(
    private wrapped: HttpClient,
    private cache: Map<string, unknown> = new Map()
  ) {}

  async get<T>(url: string): Promise<T> {
    if (this.cache.has(url)) return this.cache.get(url) as T;
    const result = await this.wrapped.get<T>(url);
    this.cache.set(url, result);
    return result;
  }

  async post<T>(url: string, body: unknown): Promise<T> {
    return this.wrapped.post(url, body);
  }
}
```

#### Class Extends
```typescript
class EnhancedService extends LegacyService {
  override async process(data: Data): Promise<Result> {
    const sanitized = this.sanitize(data);
    return super.process(sanitized);
  }

  private sanitize(data: Data): Data {
    // new logic without touching LegacyService
    return { ...data, cleaned: true };
  }
}
```

**TypeScript 優勢：** `implements` interface 確保 Wrapper 與原始型別介面一致；`override` 關鍵字明確標記覆寫

### Interceptor Chain（Express/NestJS middleware 模式）
```typescript
// Express middleware 作為 Interceptor Chain
interface RequestInterceptor {
  (req: Request, res: Response, next: NextFunction): void;
}

const loggingInterceptor: RequestInterceptor = (req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  next();
};

const authInterceptor: RequestInterceptor = (req, res, next) => {
  const token = req.headers.authorization;
  if (!token) return res.status(401).end();
  req.user = verifyToken(token);
  next();
};

// 註冊順序即為執行順序——順序本身是隱含合約
app.use(loggingInterceptor);
app.use(authInterceptor);

// NestJS Interceptor（更結構化的版本）
@Injectable()
class LoggingInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const start = Date.now();
    return next.handle().pipe(
      tap(() => console.log(`Duration: ${Date.now() - start}ms`)),
    );
  }
}
```

**適用場景：** 當多個橫切關注點（cross-cutting concerns）需要被拆分為獨立、可排序的處理步驟。與 Swift 的 `RequestInterceptor`/`ResponseInterceptor` pattern 等價，但 TypeScript 中更常見的實現形式是 Express middleware 或 NestJS Interceptor。

---

## 8. 常見隱含合約範例

### 8.1 Type Narrowing 被重構破壞
```typescript
// 隱含合約：isError 的 type guard 回傳值決定後續程式碼的型別假設
function isError(result: Success | Failure): result is Failure {
  return "error" in result;
}

function handle(result: Success | Failure) {
  if (isError(result)) {
    console.log(result.error); // TypeScript 知道這是 Failure
  } else {
    console.log(result.data);  // TypeScript 知道這是 Success
  }
}

// 重構風險：如果修改 Failure 型別移除 "error" 屬性，isError 永遠回傳 false
// 但不會產生編譯錯誤——type guard 的實作與型別宣告之間沒有編譯器驗證
```

### 8.2 Optional Chaining 隱含的 undefined 傳播
```typescript
// 隱含合約：optional chaining 在鏈中任一環節為 nullish 時回傳 undefined
const city = user?.address?.city; // type: string | undefined

// 重構風險：呼叫者可能假設 city 一定有值
function formatAddress(user: User): string {
  return `${user?.address?.city}, ${user?.address?.country}`;
  // 如果 address 為 undefined，結果是 "undefined, undefined" 而非報錯
}

// 更危險的版本：optional chaining + 方法呼叫
user?.profile?.getPreferences()?.theme;
// getPreferences() 的副作用只在 profile 存在時執行——這是條件執行合約
```

### 8.3 Enum Reverse Mapping 陷阱
```typescript
// 隱含合約：數值 enum 有 reverse mapping，字串 enum 沒有
enum Status {
  Active = 0,
  Inactive = 1,
}

// Status[0] === "Active" -- reverse mapping 存在
// 重構為字串 enum 時 reverse mapping 消失：

enum Status {
  Active = "active",
  Inactive = "inactive",
}

// Status["active"] === undefined -- 行為完全改變，但不會產生編譯錯誤
```

### 8.4 Structural Typing 的隱含相容
```typescript
interface Point2D { x: number; y: number; }
interface Point3D { x: number; y: number; z: number; }

function distance2D(p: Point2D): number {
  return Math.sqrt(p.x ** 2 + p.y ** 2);
}

const p3d: Point3D = { x: 1, y: 2, z: 3 };
distance2D(p3d); // 合法！ TypeScript 的 structural typing 允許這個呼叫

// 隱含合約：distance2D 接受任何具有 x, y 的物件
// 重構風險：如果 distance2D 開始存取傳入物件的額外屬性，
// 那些屬性可能在某些呼叫點不存在
```

### 8.5 Promise 的靜默吞錯
```typescript
// 隱含合約：未 await 的 Promise rejection 被靜默吞掉
function saveAndNotify(data: Data): void {
  // 注意：沒有 await，也沒有 .catch()
  apiClient.save(data); // Promise<void> 被丟棄
  // 如果 save 失敗，錯誤不會被任何程式碼捕獲
  // Node 15+ 會因 unhandledRejection 終止程序
}

// 更微妙的版本：Array.forEach 不等待 async callback
async function processAll(items: Item[]): Promise<void> {
  items.forEach(async (item) => {
    await process(item); // 每個 item 的 Promise 都被丟棄
  });
  // 此處所有 item 的處理可能尚未完成
}
```

### 8.6 Index Signature 與 undefined 的互動
```typescript
// tsconfig: noUncheckedIndexedAccess 關閉時（預設）
interface Cache {
  [key: string]: CacheEntry;
}

const cache: Cache = {};
const entry = cache["nonexistent"]; // type: CacheEntry（不是 CacheEntry | undefined）
entry.expiry; // runtime: TypeError: Cannot read property 'expiry' of undefined

// 隱含合約：tsconfig 的 noUncheckedIndexedAccess 設定決定型別安全程度
// 重構風險：開啟此選項會導致大量需要 null check 的編譯錯誤
```

### 8.7 Module Side Effects
```typescript
// 隱含合約：import 此模組會觸發副作用
// polyfill.ts
import "reflect-metadata";  // 修改全域 Reflect 物件
import "./array-extensions"; // 擴充 Array.prototype

// 重構風險：移除或重新排序 import 會破壞依賴這些副作用的程式碼
// TypeScript 的 tree-shaking 可能移除「看似未使用」的 side-effect import
// tsconfig 的 "verbatimModuleSyntax" 會影響 side-effect import 的保留行為
```

### 8.8 Discriminated Union 的窮舉性
```typescript
type Action =
  | { type: "add"; item: Item }
  | { type: "remove"; id: string }
  | { type: "update"; item: Item };

function reduce(state: State, action: Action): State {
  switch (action.type) {
    case "add": return { ...state, items: [...state.items, action.item] };
    case "remove": return { ...state, items: state.items.filter(i => i.id !== action.id) };
    case "update": return { ...state, items: state.items.map(i => i.id === action.item.id ? action.item : i) };
  }
}

// 隱含合約：新增 Action variant 時，所有 switch 都必須處理
// 只有啟用 strictNullChecks + 使用 never 檢查才能捕獲遺漏：
function assertNever(x: never): never { throw new Error(`Unexpected: ${x}`); }
// 如果 switch 沒有 default: assertNever(action)，新增 variant 不會報錯
```

### 8.9 Generic extends constraint 的 runtime 擦除
```typescript
// 隱含合約：Generic constraint 僅在編譯期檢查，runtime 完全不存在
interface Serializable {
  serialize(): string;
}

function save<T extends Serializable>(item: T): void {
  const data = item.serialize();  // 編譯期保證 item 有 serialize 方法
  localStorage.setItem("saved", data);
}

// 重構風險：移除 constraint 不會產生編譯錯誤（如果沒有呼叫端違反）
function save<T>(item: T): void {
  // item.serialize() 現在會編譯錯誤——但只在函式內部
  // 如果函式內部改用 (item as any).serialize()，則完全靜默失敗
}

// 更微妙的情況：constraint 用於推斷而非直接呼叫
function merge<T extends Record<string, unknown>>(a: T, b: Partial<T>): T {
  return { ...a, ...b };
}
// 移除 extends Record<string, unknown> 後，T 可以是任何型別
// 呼叫端傳入 number 或 string 不會編譯錯誤，但 spread 行為完全不同
```

**重構風險：** Generic constraint（`extends`）在 JavaScript runtime 中完全被擦除。如果重構時移除或放寬 constraint（例如從 `T extends Serializable` 改為 `T extends object`），所有現有的呼叫端仍然通過編譯，但函式內部對 `T` 的行為假設可能已不成立。特別是當 constraint 用於型別推斷（如 `keyof T`、`T[K]`）而非直接方法呼叫時，移除 constraint 不會在函式內部產生錯誤，卻會讓呼叫端傳入原本不合法的型別，導致 runtime 行為改變。

### 8.10 this 綁定的隱含合約
```typescript
class EventHandler {
  private count = 0;

  handleClick() {
    this.count++; // 隱含合約：this 必須綁定到 EventHandler 實例
  }
}

const handler = new EventHandler();
button.addEventListener("click", handler.handleClick);
// runtime 錯誤！ this 是 undefined 或 button 元素，不是 handler 實例

// 修復方式各有合約含義：
button.addEventListener("click", handler.handleClick.bind(handler)); // 建立新函式，removeEventListener 需要相同參考
button.addEventListener("click", () => handler.handleClick()); // 箭頭函式捕獲 handler，handler 生命週期是合約
// 或在 class 中使用箭頭函式屬性：
// handleClick = () => { this.count++; } // 每個實例獨立副本，無法在 prototype 上覆寫
```
