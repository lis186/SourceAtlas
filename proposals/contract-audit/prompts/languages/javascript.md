# Language Plugin: JavaScript
# Contract Audit 語言插件 -- JavaScript / Node.js / Browser
# Version: 1.0

---

## 適用範圍

- 純 JavaScript 模組（`.js` / `.mjs` / `.cjs` / `.jsx`）
- Node.js 後端（Express, Koa, Fastify, Hapi）
- 前端框架（React, Vue, Svelte——不使用 TypeScript 的專案）
- CommonJS 和 ESM 混合專案
- Legacy JavaScript（ES5 及以前）

**與 TypeScript 插件的關係**：本插件專注於 JavaScript 獨有的隱含合約風險。React lifecycle、Angular、RxJS 等框架層的合約請同時參考 `typescript.md`，其稽核要點在 JS 中同樣適用（但缺少型別系統保護，風險更高）。

---

## 1. 通知/事件原語

### EventEmitter (Node.js)
```javascript
const EventEmitter = require('node:events');

class OrderService extends EventEmitter {
  async placeOrder(order) {
    await this.repository.save(order);
    this.emit("orderPlaced", { orderId: order.id, total: order.total });
  }
}

orderService.on("orderPlaced", (data) => {
  notificationService.send(data.orderId);
});
```

稽核要點：
- 事件名稱是字串——拼寫錯誤靜默失敗，且無型別系統可檢查
- `emit` 的 payload 完全無型別約束——消費端的屬性存取假設全部是隱含合約
- 未處理的 `error` 事件會**直接 crash 程序**（`throw` 到 event loop）——這是 Node.js 最重要的合約之一
- `captureRejections: true` 可將 async listener 的 rejection 路由到 `error` 事件——預設為 false
- `on` 回傳 emitter 本身（可鏈式呼叫），`addListener` 是 `on` 的別名
- `newListener` / `removeListener` 事件在新增/移除 listener 時自動觸發——可能導致遞迴
- `events.on(emitter, eventName)` 回傳 AsyncIterator——可用 `for await...of` 消費

### DOM Events (Browser)
```javascript
element.addEventListener("click", handler, { passive: true, once: true });
window.addEventListener("message", (event) => {
  if (event.origin !== expectedOrigin) return; // 安全合約
  const data = JSON.parse(event.data);
});
```

稽核要點：
- `addEventListener` 的第三參數 options 物件中 `passive: true` 表示不會呼叫 `preventDefault()`——違反此合約會被瀏覽器忽略並印出警告
- `postMessage` 的 `origin` 檢查是安全合約——省略 origin 驗證是 XSS 風險
- `event.target` vs `event.currentTarget`——事件委派（delegation）中兩者不同
- `{ once: true }` 讓 listener 只觸發一次——等同 jQuery 的 `.one()`

### 自訂 Pub/Sub Pattern
```javascript
// 常見的手寫 pub/sub（無型別保護）
const listeners = {};
function on(event, fn) { (listeners[event] ??= []).push(fn); }
function emit(event, ...args) { (listeners[event] ?? []).forEach(fn => fn(...args)); }
function off(event, fn) { listeners[event] = (listeners[event] ?? []).filter(f => f !== fn); }
```

稽核要點：
- 手寫 pub/sub 沒有 `maxListeners` 保護——記憶體洩漏不會被警告
- `off` 需要相同函式參考——`on("x", () => {})` 後無法 `off`
- 事件名稱是任意字串——沒有集中定義的事件清單時，重構極易遺漏

---

## 2. 同步原語

### Promise
```javascript
function fetchWithRetry(url, retries = 3) {
  return fetch(url).catch(err => {
    if (retries > 0) return fetchWithRetry(url, retries - 1);
    throw err;
  });
}
```

稽核要點：
- `.catch()` 回傳新的 resolved Promise——`.catch().then()` 鏈中，then 即使前面出錯也會執行
- `Promise.race` 中落敗的 Promise 副作用仍繼續——無取消機制
- `Promise.all` 快速失敗（fast-fail）——任一 reject 即整體 reject，但其餘 Promise 的副作用仍執行
- `Promise.allSettled` 不 fast-fail——等待所有 Promise 完成，回傳每個的 status/value/reason
- 在 `.then()` 中不回傳 Promise 會導致鏈斷裂——後續 then 收到 undefined

### async/await
```javascript
// 陷阱：forEach 不等待 async callback
items.forEach(async (item) => {
  await process(item); // 每個 Promise 被丟棄
});
// 此處所有處理尚未完成

// 正確版本
for (const item of items) {
  await process(item); // 循序
}
// 或
await Promise.all(items.map(item => process(item))); // 並行
```

稽核要點：
- `Array.forEach` / `Array.map` / `Array.filter` 不等待 async callback——這是 JS 最常見的隱含合約陷阱
- `for...of` + `await` 是循序，`Promise.all` + `map` 是並行——行為差異巨大
- 未 `await` 的 Promise 其 rejection 可能成為 unhandled rejection（Node 15+ 終止程序）
- `async` 函式永遠回傳 Promise——即使函式體是同步的

### Node.js Streams
```javascript
const { pipeline } = require('node:stream/promises');
const fs = require('node:fs');
const zlib = require('node:zlib');

await pipeline(
  fs.createReadStream('input.tar'),
  zlib.createGzip(),
  fs.createWriteStream('output.tar.gz')
);
```

稽核要點：
- `readable.pipe(writable)` **不處理錯誤**——readable 出錯時 writable 不會自動關閉，導致記憶體洩漏
- `stream.pipeline()` 是 `pipe` 的安全替代——自動處理錯誤並清理所有 stream
- Backpressure：readable 產生資料比 writable 消費快時，`pipe` 自動暫停 readable——但 `write()` 回傳 false 後繼續寫入會導致記憶體膨脹
- Stream 有兩種模式：flowing（自動推送）和 paused（手動 `read()`）——附加 `data` listener 自動切換到 flowing
- `highWaterMark` 控制內部 buffer 大小——預設 16KB（objectMode 下為 16 個物件）
- `destroy()` 是清理 stream 的唯一安全方式——`close` 事件不保證所有資源已釋放

### AbortController
```javascript
const controller = new AbortController();
const { signal } = controller;

// signal 可串接傳遞
const response = await fetch(url, { signal });
const timeout = setTimeout(() => controller.abort(), 5000);

signal.addEventListener("abort", () => {
  clearTimeout(timeout);
});
```

稽核要點：
- `AbortController` 是 Node.js 和 Browser 通用的取消機制——但並非所有 API 都支援
- `signal.aborted` 在 abort 後為 true——但檢查時機是合約（可能在 abort 前已檢查過）
- `abort()` 後 `signal` 觸發 `abort` 事件——所有綁定該 signal 的操作都會收到取消通知
- `signal.reason` (Node 17.2+) 可攜帶取消原因——消費端可能依賴 reason 的型別

### Worker Threads (Node.js)
```javascript
const { Worker, isMainThread, parentPort } = require('node:worker_threads');

if (isMainThread) {
  const worker = new Worker(__filename, { workerData: { items } });
  worker.on("message", (result) => { /* ... */ });
  worker.on("error", (err) => { /* ... */ });
} else {
  const result = heavyComputation(workerData);
  parentPort.postMessage(result);
}
```

稽核要點：
- `postMessage` 使用結構化克隆——函式、Symbol、DOM 節點無法傳遞
- `SharedArrayBuffer` + `Atomics` 是唯一的真正共享記憶體——需要 COOP/COEP headers（Browser）
- Worker 的 `error` 事件未處理可能導致靜默失敗
- `__filename` 在 ESM 中不可用——需要 `import.meta.url`

---

## 3. 生命週期模式

### Node.js Process Events
```javascript
process.on("uncaughtException", (err, origin) => {
  logger.fatal({ err, origin });
  process.exit(1);
});

process.on("unhandledRejection", (reason, promise) => {
  logger.error({ reason });
  // Node 15+: 預設會終止程序
});

process.on("SIGTERM", async () => {
  await server.close();
  await db.disconnect();
  process.exit(0);
});
```

稽核要點：
- `uncaughtException` handler 之後繼續執行是危險的——程序狀態不確定
- `unhandledRejection` 在 Node 15+ 預設終止程序——Node 14 只是警告
- `SIGTERM` / `SIGINT` 的 graceful shutdown 順序是合約——先停止接受新連線，再等待進行中的請求
- `beforeExit` 事件中可以執行非同步操作，`exit` 事件中不行
- `process.exit()` 不等待 pending I/O——可能導致資料遺失

### Express/Koa Middleware Chain
```javascript
// 順序是合約
app.use(cors());
app.use(express.json({ limit: "10mb" }));
app.use(authMiddleware);
app.use("/api", router);
app.use(errorHandler); // 4 個參數的 error middleware 必須在最後

// Koa 的洋蔥模型
app.use(async (ctx, next) => {
  const start = Date.now();
  await next(); // 控制權傳遞給下一個 middleware
  ctx.set("X-Response-Time", `${Date.now() - start}ms`); // next() 之後執行
});
```

稽核要點：
- Express error middleware 必須有 **4 個參數** `(err, req, res, next)` 才會被識別——3 個參數會被當作普通 middleware
- `next()` 未呼叫會導致請求掛起——用戶端永遠等不到回應
- `next(err)` 跳過所有普通 middleware，直接到 error middleware
- Express `express.json()` 的 `limit` 選項是安全合約——無限制時可被 payload 攻擊
- Koa 的 `await next()` 實現洋蔥模型——`next()` 之後的程式碼在下游 middleware 完成後才執行

### React Lifecycle (Hooks)
```javascript
useEffect(() => {
  const controller = new AbortController();
  fetchData(controller.signal);
  return () => controller.abort();
}, [dependency]);

// useCallback / useMemo（無型別保護下風險更高）
const handleClick = useCallback((data) => {
  // 沒有型別檢查——data 的結構完全靠文件或 convention
  api.save(data.id, data.name);
}, []);
```

稽核要點：
- 所有 React hooks 的稽核要點同 TypeScript 插件——但 JS 無型別保護，dependency array 中的錯誤更難發現
- `useCallback` 的 dependency array 遺漏不會有編譯錯誤——只能靠 ESLint `exhaustive-deps` 規則
- `useRef` 的 `.current` 型別完全無約束——存取不存在的屬性回傳 `undefined` 而非報錯
- JSX 中的 prop 型別只能靠 `PropTypes`（runtime 警告）或 convention

### Module Initialization Side Effects
```javascript
// CommonJS -- require 時立即執行
const config = require("./config"); // config.js 中的頂層程式碼在 require 時執行
require("./polyfills"); // 修改全域物件

// ESM -- import 時執行
import "./side-effects.js"; // 副作用 import
import { setup } from "./init.js"; // setup 是否有副作用取決於 init.js 的頂層程式碼
```

稽核要點：
- CommonJS `require` 是同步的且有 cache——第一次 require 執行模組程式碼，之後回傳 cache
- ESM `import` 的執行順序由 module graph 決定——不一定等於 import 語句的文字順序
- 模組頂層程式碼的副作用（修改全域物件、建立連線、啟動 timer）是隱含合約
- 循環依賴在 CommonJS 中回傳部分初始化的物件，ESM 中回傳 TDZ 參考——兩者行為不同

---

## 4. 驗證策略

**ast-grep: 完整支援。**

JavaScript 是 ast-grep 的一級支援語言。所有合約應優先使用 ast-grep 規則驗證。

### ast-grep 規則撰寫指南

```yaml
id: n1-event-emitter-error
message: "N1: EventEmitter error handler -- must be present to prevent crash"
severity: error
language: JavaScript
rule:
  pattern: |
    $EMITTER.on("error", $HANDLER)
```

**Pattern 注意事項：**
- JS 沒有型別標注——pattern 比 TypeScript 更簡潔
- CommonJS `require()` 和 ESM `import` 是不同的 AST 節點——需要分別匹配
- JSX 語法需要特別處理——`<Component />` 中的 props 是 AST 節點

### grep 作為補充

```bash
# 檢查 EventEmitter 是否有 error handler
grep -n '\.on("error"' "$file"
grep -n '\.on('\''error'\''' "$file"

# 檢查 pipe vs pipeline（pipe 不安全）
grep -n '\.pipe(' "$file"

# 檢查未 await 的 async 呼叫
grep -n 'forEach(async' "$file"

# 檢查 == 而非 === 的使用
grep -n '[^!=]== ' "$file" | grep -v '==='
```

---

## 5. Effect 防火牆

**強度：最弱（無型別系統）。**

JavaScript 沒有編譯期的型別約束，所有「不可變性」都靠 convention 或 runtime API：

### Object.freeze()
```javascript
const config = Object.freeze({
  apiKey: "abc",
  nested: { mutable: true } // freeze 是淺層的！
});
config.apiKey = "xyz"; // strict mode: TypeError; sloppy mode: 靜默失敗
config.nested.mutable = false; // 成功！
```
- `Object.freeze` 是唯一有 runtime 效果的不可變性機制
- 淺層保護——巢狀物件不受保護
- strict mode 下修改會 TypeError，sloppy mode 靜默忽略——執行模式是合約

### Object.defineProperty()
```javascript
Object.defineProperty(obj, "readonlyProp", {
  value: 42,
  writable: false,
  configurable: false,
});
```
- `writable: false` + `configurable: false` 是最強的 property 保護
- 但可以被 `Object.getOwnPropertyDescriptor` 檢查並繞過（如果 configurable 為 true）

### const 宣告
```javascript
const arr = [1, 2, 3];
arr.push(4); // 成功！ const 只防止重新賦值，不防止修改
arr = []; // TypeError
```
- `const` 只保證 binding 不可變——對 object/array 不保護內容
- `let` vs `const` 的選擇是 convention 合約——部分團隊強制 `const`

**稽核影響：**
- 假設所有物件和陣列的內容都可能被任何有 reference 的程式碼修改
- `Object.freeze` 是唯一的 runtime 保護，但只保護淺層
- 沒有型別系統意味著所有函式參數的型別假設都是隱含合約
- `typeof` 檢查是手動型別守衛——`typeof null === "object"` 是最經典的陷阱

---

## 6. Seam 類型

### Object Seam（Prototype / Factory Function / DI）

#### Prototype-based
```javascript
class HttpClient {
  async get(url) { /* ... */ }
  async post(url, body) { /* ... */ }
}

// 可以在 runtime 替換方法
HttpClient.prototype.get = async function(url) {
  console.log("intercepted:", url);
  return originalGet.call(this, url);
};
```

- JS 的 prototype chain 是動態的——runtime 可以隨時替換任何方法
- `class` 語法只是 prototype 的語法糖——沒有真正的封裝
- `#privateField` (ES2022) 是語言層級的私有——無法透過 prototype 存取

#### Factory Function
```javascript
function createHttpClient(config) {
  // closure 提供真正的私有狀態
  const apiKey = config.apiKey;

  return {
    async get(url) {
      return fetch(url, { headers: { "X-API-Key": apiKey } });
    }
  };
}
```

- Factory function + closure 是 JS 中最強的封裝機制——外部無法存取 `apiKey`
- 但每個實例都建立新的函式物件——memory footprint 比 prototype 大

### Preprocessing Seam（環境變數 / 條件分支）
```javascript
// Node.js 環境變數
if (process.env.NODE_ENV === "production") {
  enableAnalytics();
}

// Webpack DefinePlugin 在編譯時替換
if (process.env.FEATURE_FLAG === "true") {
  enableNewFeature();
}

// 條件 require（CommonJS only）
const db = process.env.DB_TYPE === "postgres"
  ? require("./db/postgres")
  : require("./db/sqlite");
```

- `process.env` 值永遠是 `string | undefined`——`process.env.PORT` 是字串 "3000"，不是數字
- Webpack `DefinePlugin` 做字串替換——`process.env.NODE_ENV` 被替換為 `"production"` 字串字面量
- 條件 `require` 在 CommonJS 中合法但在 ESM 中不行——`import()` 是 ESM 的動態替代

### Link Seam（Module Alias / Monkey-patching）
```javascript
// Monkey-patching（最極端的 Link Seam）
const originalFetch = global.fetch;
global.fetch = async function(url, options) {
  console.log("fetch:", url);
  return originalFetch(url, options);
};

// Jest module mocking
jest.mock("./api-client", () => ({
  fetchUser: jest.fn().mockResolvedValue({ name: "test" }),
}));

// package.json "browser" field
// { "browser": { "./src/crypto-node.js": "./src/crypto-browser.js" } }
```

- Monkey-patching 全域物件（`global.fetch`、`console.log`）是最危險的 Seam——影響所有模組
- Jest `jest.mock` 在模組層級替換——模組被 mock 後的行為可能與真實模組不同
- `require.resolve` 可以在 runtime 查詢模組路徑——但不保證模組存在

---

## 7. Sprout/Wrap 策略

### Sprout Method
```javascript
// Before
function handleOrder(order) {
  // 200 lines of mixed logic
}

// After
function handleOrder(order) {
  const validated = validateOrder(order); // sprouted
  // remaining logic
}

// Sprouted -- independently testable
function validateOrder(order) {
  if (!order.items?.length) throw new Error("empty");
  if (order.total <= 0) throw new Error("invalid total");
  return { ...order, validated: true };
}
```

**JS 優勢：** 獨立函式無需 class 實例化，可直接匯出測試

### Sprout Class
```javascript
class OrderValidator {
  constructor(rules) {
    this.rules = rules;
  }

  validate(order) {
    const violations = this.rules
      .map(rule => rule.check(order))
      .filter(Boolean);
    if (violations.length) throw new ValidationError(violations);
    return { ...order, validated: true };
  }
}
```

### Wrap Method (Higher-Order Function)
```javascript
function withLogging(fn) {
  return function(...args) {
    console.log(`Calling ${fn.name}`, args);
    const result = fn.apply(this, args);
    console.log(`Result:`, result);
    return result;
  };
}

// 注意：此 wrapper 不處理 async 函式——需要另外處理 Promise
function withAsyncLogging(fn) {
  return async function(...args) {
    console.log(`Calling ${fn.name}`);
    try {
      const result = await fn.apply(this, args);
      console.log(`Success:`, result);
      return result;
    } catch (err) {
      console.error(`Error:`, err);
      throw err;
    }
  };
}
```

**JS 注意：** Higher-order function 需要用 `function` 而非箭頭函式來保留 `this` 綁定

### Wrap Class (Proxy)
```javascript
// JS 的 Proxy 是最強大的 Wrap 機制
const loggingProxy = new Proxy(service, {
  get(target, prop, receiver) {
    const value = Reflect.get(target, prop, receiver);
    if (typeof value === "function") {
      return function(...args) {
        console.log(`${String(prop)}(${args})`);
        return value.apply(target, args);
      };
    }
    return value;
  }
});
```

**JS 優勢：** `Proxy` 可以攔截幾乎所有物件操作（get/set/has/delete/apply/construct），無需逐一覆寫方法

---

## 8. 常見隱含合約範例

### 8.1 隱式類型轉換（Type Coercion）
```javascript
// == 使用隱式轉換，=== 不轉換
"0" == false   // true（都轉為數字 0）
"0" === false  // false
null == undefined // true
null === undefined // false

// 算術運算的隱式轉換
"5" - 1  // 4（字串轉數字）
"5" + 1  // "51"（數字轉字串）
[] + []  // ""
[] + {}  // "[object Object]"
{} + []  // 0（{} 被解析為空 block）
```

**重構風險：** 將 `==` 改為 `===` 可能破壞依賴隱式轉換的邏輯。`null == undefined` 是常見的合約——改為 `===` 後需要分別檢查 `null` 和 `undefined`。

### 8.2 this 綁定
```javascript
class Timer {
  count = 0;

  start() {
    // 隱含合約：setInterval 的 callback 中 this 不綁定到 Timer 實例
    setInterval(function() {
      this.count++; // this 是 global 或 undefined（strict mode）
    }, 1000);

    // 修正方式——箭頭函式繼承外層 this
    setInterval(() => {
      this.count++; // this 是 Timer 實例
    }, 1000);
  }
}

// 解構賦值丟失 this
const { start } = new Timer();
start(); // this 是 undefined
```

**重構風險：** 將普通函式改為箭頭函式（或反之）會改變 `this` 綁定。將方法解構出物件會丟失 `this`——這在傳遞 callback 時特別常見。

### 8.3 Hoisting
```javascript
// var hoisting——宣告提升但賦值不提升
console.log(x); // undefined（不是 ReferenceError）
var x = 5;

// function hoisting——整個函式提升
foo(); // 正常執行
function foo() { console.log("works"); }

// let/const 有 TDZ（Temporal Dead Zone）
console.log(y); // ReferenceError
let y = 5;
```

**重構風險：** 將 `var` 改為 `let`/`const` 可能暴露依賴 hoisting 的程式碼。將函式宣告改為函式表達式（`const foo = function() {}`）會破壞 hoisting 行為。

### 8.4 CommonJS vs ESM 行為差異
```javascript
// CommonJS -- 值的拷貝
// a.js
let count = 0;
module.exports = { count, increment() { count++; } };
// b.js
const a = require("./a");
a.increment();
console.log(a.count); // 0（拿到的是拷貝，不是 reference）

// ESM -- live binding
// a.mjs
export let count = 0;
export function increment() { count++; }
// b.mjs
import { count, increment } from "./a.mjs";
increment();
console.log(count); // 1（live binding）
```

**重構風險：** CommonJS → ESM 遷移時，`module.exports` 的值拷貝語義變為 ESM 的 live binding——依賴「值不會變」的程式碼可能出錯。`require` 是同步的，`import()` 是非同步的——替換需要 `await`。

### 8.5 原型鏈污染
```javascript
// 隱含合約：Object.prototype 上的方法可以被任何物件存取
const obj = {};
obj.toString(); // "[object Object]"——繼承自 Object.prototype

// 原型污染攻擊
const malicious = JSON.parse('{"__proto__": {"isAdmin": true}}');
// 如果使用不安全的 deep merge，所有物件都會繼承 isAdmin: true

// 安全替代
const safe = Object.create(null); // 無原型物件
```

**重構風險：** 使用 `for...in` 遍歷物件時會包含原型鏈上的屬性——需要 `hasOwnProperty` 檢查。`Object.create(null)` 建立的物件沒有 `toString`/`valueOf` 等方法——傳入預期一般物件的函式可能出錯。

### 8.6 typeof / instanceof 陷阱
```javascript
typeof null          // "object"（歷史 bug）
typeof []            // "object"（不是 "array"）
typeof NaN           // "number"
typeof undeclaredVar // "undefined"（不是 ReferenceError）

// instanceof 跨 realm 失敗
const iframe = document.createElement("iframe");
document.body.appendChild(iframe);
const iframeArray = iframe.contentWindow.Array;
const arr = new iframeArray(1, 2, 3);
arr instanceof Array // false（不同 realm 的 Array）
Array.isArray(arr)   // true（安全檢查）
```

**重構風險：** 依賴 `typeof` 做型別檢查的程式碼——`typeof null === "object"` 可能導致 null 被誤判為物件。跨 iframe/realm 的 `instanceof` 失敗是隱含合約。

### 8.7 arguments 物件
```javascript
function legacy() {
  // arguments 是 array-like，不是真正的 Array
  arguments.forEach(x => {}); // TypeError: arguments.forEach is not a function

  // 修改 arguments 會影響具名參數（sloppy mode）
  arguments[0] = "changed";
  console.log(firstArg); // "changed"（在 sloppy mode 下）

  // strict mode 或箭頭函式中 arguments 行為不同
}
```

**重構風險：** 將 `function` 改為箭頭函式會丟失 `arguments`——需要改用 rest parameters `(...args)`。`arguments` 與具名參數的雙向綁定（sloppy mode）是非常危險的隱含合約。

### 8.8 Closure 與迴圈變數
```javascript
// 經典陷阱：var 在迴圈中共享
for (var i = 0; i < 5; i++) {
  setTimeout(() => console.log(i), 100); // 全部印出 5
}

// 修正：let 建立 block scope
for (let i = 0; i < 5; i++) {
  setTimeout(() => console.log(i), 100); // 0, 1, 2, 3, 4
}
```

**重構風險：** 將 `var` 改為 `let` 會改變 closure 捕獲的語義——大部分情況下這是正確的修改，但依賴共享變數行為的程式碼會被破壞。

### 8.9 JSON.parse / JSON.stringify 邊界
```javascript
// 隱含合約：JSON.stringify 會丟棄 undefined、function、Symbol
const obj = { a: 1, b: undefined, c: () => {}, d: Symbol("x") };
JSON.stringify(obj); // '{"a":1}'——b, c, d 被靜默移除

// JSON.parse 的 reviver 是合約
JSON.parse(json, (key, value) => {
  if (key === "date") return new Date(value); // 型別轉換合約
  return value;
});

// BigInt 無法 JSON 序列化
JSON.stringify({ n: 1n }); // TypeError
```

**重構風險：** 在物件中新增 `undefined` 值的屬性，`JSON.stringify` 會靜默移除——接收端看不到該屬性，與「屬性值為 null」的語義不同。

### 8.10 Strict Mode 行為差異
```javascript
// sloppy mode
function sloppy() {
  x = 10; // 建立全域變數（不報錯）
  delete Object.prototype; // 靜默失敗
}

// strict mode
"use strict";
function strict() {
  x = 10; // ReferenceError
  delete Object.prototype; // TypeError
}

// ESM 預設是 strict mode
// class body 預設是 strict mode
```

**重構風險：** 從 CommonJS（sloppy）遷移到 ESM（strict）時，依賴隱式全域變數、`with` 語句、`arguments.callee` 等 sloppy mode 特性的程式碼會直接報錯。

---

## 9. JavaScript-TypeScript 遷移合約

JS→TS 遷移時特別需要注意的隱含合約：

### any 型別的隱式擴散
```javascript
// JS 中一切都是隱式 any——遷移到 TS 時需要逐一標記型別
// 常見策略：先用 @ts-check + JSDoc，再遷移為 .ts

/** @type {import("./types").User} */
const user = fetchUser(); // JSDoc 型別標注可在 JS 中使用
```

### 動態屬性存取
```javascript
// JS 中常見但 TS 不友善的模式
const handlers = { click: handleClick, hover: handleHover };
const handler = handlers[eventType]; // TS 需要 index signature 或 assertion
```

### Duck Typing → Structural Typing
```javascript
// JS 的 duck typing 在 TS 中自動對應到 structural typing
// 但手動型別檢查（typeof、instanceof）可能與 TS 的型別收窄不一致
```

稽核要點：
- JS 的隱式 `any` 在 TS 中需要明確型別——`noImplicitAny` 開啟後可能產生大量錯誤
- 動態 property access（`obj[key]`）需要 index signature——不加會是編譯錯誤
- `require` 在 TS 中需要改為 `import`——但 `@types` 可能不存在
- CommonJS 的 `module.exports = class Foo {}` 在 TS 中有 `esModuleInterop` 語義差異
