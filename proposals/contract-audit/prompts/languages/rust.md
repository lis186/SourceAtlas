# Language Plugin: Rust
# Contract Audit 語言插件 -- Rust / Tokio / Common Frameworks
# Version: 1.0

---

## 適用範圍

- 純 Rust 模組（`.rs`）
- 非同步 runtime（Tokio, async-std, smol）
- Web 框架（Axum, Actix-web, Rocket, Warp）
- CLI 工具（clap, structopt）
- 系統程式（embedded, OS, driver）
- FFI 混合模組中的 Rust 部分

---

## 1. 通知/事件原語

### Channel (std::sync::mpsc / crossbeam / tokio)

```rust
use std::sync::mpsc;

// 標準庫 mpsc（多生產者，單消費者）
let (tx, rx) = mpsc::channel();      // 無界
let (tx, rx) = mpsc::sync_channel(100); // 有界

tx.send(event).unwrap();
let event = rx.recv().unwrap();       // 阻塞
let event = rx.try_recv();            // 非阻塞，回傳 Result

// tokio channel
let (tx, rx) = tokio::sync::mpsc::channel(100);
let (tx, rx) = tokio::sync::broadcast::channel(100);
let (tx, rx) = tokio::sync::oneshot::channel();
let (tx, rx) = tokio::sync::watch::channel(initial_value);
```

稽核要點：
- `mpsc::channel` 是無界的——生產速度大於消費速度時記憶體無限增長
- `mpsc::sync_channel` buffer 滿時 `send` 阻塞——在 async context 中使用會阻塞整個 thread
- 所有 `tx` 都 drop 後，`rx.recv()` 回傳 `Err(RecvError)`——是 channel 關閉的信號
- `rx` drop 後，`tx.send()` 回傳 `Err(SendError)`——生產端必須處理
- `tokio::sync::broadcast` 是多生產者多消費者——慢 consumer 會 lag（`RecvError::Lagged`）
- `tokio::sync::oneshot` 只能發送一個值——第二次 send 編譯錯誤（ownership 已轉移）
- `tokio::sync::watch` 只保留最新值——類似 Kotlin 的 StateFlow

### Callback / Handler

```rust
fn register_handler<F>(handler: F)
where
    F: Fn(Event) -> Result<()> + Send + Sync + 'static,
{
    // ...
}

// Closure 作為 callback
register_handler(|event| {
    println!("{:?}", event);
    Ok(())
});
```

稽核要點：
- `Fn` vs `FnMut` vs `FnOnce` 是 closure 的呼叫合約——`FnOnce` 只能呼叫一次（消費 captured 變數）
- `Send + Sync + 'static` 是跨 thread 傳遞的合約——不滿足的 closure 編譯失敗
- `'static` 表示 closure 不能借用 local 變數——必須 move ownership 進 closure

### Event / Observer Pattern

```rust
// tokio::sync::Notify
let notify = Arc::new(tokio::sync::Notify::new());

// 等待端
notify.notified().await;

// 通知端
notify.notify_one();   // 喚醒一個 waiter
notify.notify_waiters(); // 喚醒所有 waiter
```

稽核要點：
- `Notify` 沒有值——純粹是同步信號
- `notify_one` 在沒有 waiter 時會「記住」一次通知——下一個 `notified()` 立即返回
- `notify_waiters` 不記住——只喚醒當前的 waiter

---

## 2. 同步原語

### Ownership 與 Borrow Checker

```rust
fn take_ownership(s: String) {
    // s 的 ownership 被轉移到此函式
}

fn borrow(s: &str) {
    // 不可變借用——可以有多個同時存在
}

fn borrow_mut(s: &mut String) {
    // 可變借用——同一時間只能有一個
}
```

稽核要點：
- **Ownership 是 Rust 最基本的合約**——每個值恰好有一個 owner
- 不可變借用（`&T`）和可變借用（`&mut T`）不能同時存在——編譯器強制
- ownership 轉移後，原變數不可使用——使用會編譯錯誤
- `Clone` 是顯式複製——cost 可見；`Copy` 是隱式複製——只適用於簡單型別
- 跨 closure/thread 邊界需要 `move`——捕獲 ownership 而非 reference

### Mutex / RwLock (std)

```rust
use std::sync::{Mutex, RwLock, Arc};

let data = Arc::new(Mutex::new(Vec::new()));
let data_clone = Arc::clone(&data);

std::thread::spawn(move || {
    let mut guard = data_clone.lock().unwrap();
    guard.push(1);
    // guard drop 時自動釋放鎖
});
```

稽核要點：
- `Mutex::lock()` 回傳 `Result`——如果持有鎖的 thread panic，mutex 進入 poisoned 狀態
- `.unwrap()` 在 poisoned mutex 上 panic——應根據場景決定是否 `lock().unwrap_or_else(|e| e.into_inner())`
- `MutexGuard` 的 `Drop` 自動釋放鎖——但 guard 存活過久會延長 critical section
- `RwLock` 允許多個讀取者——但寫入者需要等待所有讀取者釋放（可能飢餓）
- `std::sync::Mutex` 會阻塞 thread——在 async 中應使用 `tokio::sync::Mutex`

### Tokio Mutex / RwLock

```rust
use tokio::sync::Mutex;

let data = Arc::new(Mutex::new(Vec::new()));
let mut guard = data.lock().await;  // 不阻塞 thread
guard.push(1);
```

稽核要點：
- `tokio::sync::Mutex` 不會 poison——panic 時 guard drop 正常釋放
- `tokio::sync::Mutex` 的 `lock()` 是 `async`——可以在等待時讓出 thread
- 跨 `.await` 持有 `std::sync::MutexGuard` 會編譯警告——因為 `MutexGuard` 不是 `Send`

### Atomic

```rust
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};

let flag = AtomicBool::new(false);
flag.store(true, Ordering::Release);
let val = flag.load(Ordering::Acquire);
```

稽核要點：
- `Ordering` 選擇是合約——`Relaxed` 最快但不保證跨 thread 可見順序
- `Acquire/Release` 成對使用保證 happens-before 關係
- `SeqCst` 最嚴格——全局順序一致，但效能最低
- 錯誤的 `Ordering` 不會導致 UB（在 safe Rust 中），但會導致邏輯錯誤

### async/await (Tokio)

```rust
#[tokio::main]
async fn main() {
    let handle = tokio::spawn(async {
        fetch_data().await
    });

    let result = handle.await.unwrap();
}
```

稽核要點：
- `tokio::spawn` 產生的 task 在 runtime thread pool 上執行——task 必須是 `Send + 'static`
- `JoinHandle.await` 回傳 `Result`——`Err(JoinError)` 表示 task panic 或被取消
- `tokio::spawn` 的 task panic 不會傳播到 spawner——只能透過 `JoinHandle` 觀察
- `select!` macro 在其中一個 branch 完成時取消其他——被取消的 Future 在下一個 `.await` 點停止
- `tokio::task::spawn_blocking` 用於 CPU 密集或同步 I/O——在專用 thread pool 上執行

---

## 3. 生命週期模式

### Drop Trait

```rust
struct Connection {
    handle: RawHandle,
}

impl Drop for Connection {
    fn drop(&mut self) {
        unsafe { close_handle(self.handle); }
    }
}
```

稽核要點：
- `Drop::drop` 在值離開 scope 時自動呼叫——是 RAII 的核心
- drop 順序：struct 的 field 按宣告順序 drop
- `std::mem::forget` 跳過 `drop`——是 safe 的，但會導致資源洩漏
- `ManuallyDrop` 延遲 drop——需要手動呼叫 `ManuallyDrop::drop`
- `drop(value)` 提前觸發 drop——常用於提前釋放鎖

### Lifetime Annotations

```rust
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}

struct Parser<'input> {
    input: &'input str,
}
```

稽核要點：
- lifetime annotation 是借用的合約——告訴編譯器 reference 的有效範圍
- `'static` 表示整個程式執行期間有效——不是「靜態分配」，是「存活最久」
- lifetime elision rules 在簡單情況下自動推斷——但複雜情況需要顯式標註
- struct 中的 lifetime 表示「struct 不能比借用的資料活得更久」

### Tokio Runtime Lifecycle

```rust
#[tokio::main]
async fn main() {
    // runtime 在 main 結束時 shutdown
}

// 或手動控制
let rt = tokio::runtime::Runtime::new().unwrap();
rt.block_on(async { /* ... */ });
// rt drop 時等待所有 spawned task 完成
```

稽核要點：
- `#[tokio::main]` 建立 multi-thread runtime——`#[tokio::main(flavor = "current_thread")]` 是單 thread
- runtime drop 時等待所有 task 完成——但不會主動取消 task
- `runtime.shutdown_timeout(duration)` 設定等待上限——超時後強制終止

### Axum / Actix-web Handler Lifecycle

```rust
// Axum
async fn handler(
    State(db): State<Pool>,
    Json(body): Json<CreateUser>,
) -> Result<Json<User>, AppError> {
    let user = db.create_user(body).await?;
    Ok(Json(user))
}

let app = Router::new()
    .route("/users", post(handler))
    .with_state(pool);
```

稽核要點：
- Axum extractor 按參數順序執行——extractor 失敗會短路（不執行 handler）
- `State` 在 application 啟動時注入——是 shared state 的合約
- handler 的回傳型別必須 impl `IntoResponse`——自訂 error type 需要 impl 此 trait
- middleware 順序影響行為——`layer` 按外到內順序包裹

### Builder Pattern Lifecycle

```rust
let client = Client::builder()
    .timeout(Duration::from_secs(30))
    .connect_timeout(Duration::from_secs(5))
    .build()?;
```

稽核要點：
- `.build()` 消費 builder——build 後不能再修改（ownership 轉移）
- builder 通常在 `.build()` 時驗證——無效組合在 build 時才被發現
- 某些 builder 的 `.build()` 回傳 `Result`——驗證失敗是可能的

---

## 4. 驗證策略

**ast-grep: 完整支援。**

Rust 是 ast-grep 的支援語言。所有合約應優先使用 ast-grep 規則驗證。

### ast-grep 規則撰寫指南

```yaml
id: s1-std-mutex-in-async
message: "S1: std::sync::Mutex used in async context — use tokio::sync::Mutex"
severity: warning
language: Rust
rule:
  pattern: |
    $GUARD.lock().unwrap()
  inside:
    kind: async_block
```

**Pattern 注意事項：**
- Rust 的 macro 展開需要注意：`println!`、`vec!`、`tokio::select!` 的 AST 結構不同於函式呼叫
- `?` 運算子是語法糖——AST 中是 `try_expression`
- `impl Trait` 在 AST 中與泛型參數不同
- lifetime `'a` 在 AST 中是獨立節點

### grep 作為補充

```bash
# 檢查 unsafe 使用
grep -n 'unsafe\s*{' "$file"

# 檢查 unwrap/expect（潛在 panic 點）
grep -n '\.unwrap()\|\.expect(' "$file"

# 檢查 Arc<Mutex> 模式
grep -n 'Arc<Mutex\|Arc<RwLock' "$file"

# 檢查 tokio::spawn
grep -n 'tokio::spawn\|spawn_blocking' "$file"

# 檢查 mem::forget / ManuallyDrop
grep -n 'mem::forget\|ManuallyDrop' "$file"
```

---

## 5. Effect 防火牆

**強度：極強。**

Rust 的 ownership 和型別系統提供編譯時不可變性保證，是所有語言中最強的 Effect 防火牆。

### 預設不可變

```rust
let x = 5;       // 不可變
let mut y = 5;   // 需要明確標記 mut
```

- Rust 變數預設不可變——`mut` 是明確的 opt-in
- 不可變性是深層的——`let v: Vec<i32>` 不能 push（不像 Java 的 `final` 只保護 reference）

### Ownership + Move Semantics

```rust
let s = String::from("hello");
let s2 = s;  // s 的 ownership 被轉移
// println!("{s}");  // 編譯錯誤！s 已無效
```

- move 語義確保「只有一個 owner 可以修改」——不可能有兩個地方同時修改同一資料
- `Clone` 是顯式的——不會意外共享 mutable state

### Send / Sync Traits

```rust
// Send: 可以跨 thread 轉移 ownership
// Sync: 可以跨 thread 共享 reference（&T 是 Send）
fn spawn_task<T: Send + 'static>(data: T) {
    std::thread::spawn(move || {
        // data 在此 thread 中使用
    });
}
```

- `Send` 和 `Sync` 是自動推導的 marker trait——包含非 Send/Sync 型別的 struct 自動不是 Send/Sync
- `Rc<T>` 不是 `Send`——編譯器阻止跨 thread 傳遞（必須用 `Arc<T>`）
- `Cell<T>` / `RefCell<T>` 不是 `Sync`——不能跨 thread 共享（必須用 `Mutex<T>`）

### Enum + Exhaustive Match

```rust
enum State {
    Loading,
    Success(Data),
    Error(String),
}

fn handle(state: State) {
    match state {
        State::Loading => show_spinner(),
        State::Success(data) => show_data(data),
        State::Error(msg) => show_error(msg),
        // 新增 variant 會導致編譯錯誤
    }
}
```

- `match` 必須窮舉——新增 enum variant 會在所有 `match` 點觸發編譯錯誤
- `#[non_exhaustive]` 標記的 enum 不能在外部 crate 窮舉——強制加 `_ =>` wildcard

**稽核影響：**
- Rust 的 borrow checker 在編譯時消除了大部分 data race——不需要 runtime 檢查
- `unsafe` 繞過所有保證——每個 `unsafe` block 都是最高風險的稽核目標
- 型別系統表達的合約（Send, Sync, lifetime）由編譯器強制——不需要 CI 規則驗證

---

## 6. Seam 類型

### Object Seam（Trait）

```rust
trait Repository {
    async fn get(&self, id: &str) -> Result<User>;
    async fn save(&self, user: &User) -> Result<()>;
}

struct PostgresRepo {
    pool: PgPool,
}

impl Repository for PostgresRepo {
    async fn get(&self, id: &str) -> Result<User> {
        // ...
    }
    async fn save(&self, user: &User) -> Result<()> {
        // ...
    }
}
```

- Trait 是 Rust 的 Object Seam——類似 Go interface 但需要顯式 `impl`
- `dyn Trait` 是動態分派（vtable）——`impl Trait` 是靜態分派（monomorphization）
- `dyn Trait` 需要 `Box<dyn Trait>` 或 `&dyn Trait`——因為大小在編譯時未知
- trait 的 default method 是隱含合約——override 時需要維持相同語義

### Preprocessing Seam（cfg）

```rust
#[cfg(target_os = "linux")]
fn platform_specific() {
    // 只在 Linux 上編譯
}

#[cfg(feature = "advanced")]
mod advanced_features;

#[cfg(test)]
mod tests {
    // 只在 test 時編譯
}
```

- `#[cfg(...)]` 在編譯時決定——條件不滿足的程式碼完全不存在於二進位中
- `#[cfg(feature = "...")]` 由 Cargo.toml 的 features 控制——feature 組合是合約
- `#[cfg(test)]` 是測試程式碼的隔離機制

### Link Seam

```rust
// 動態載入
use libloading::{Library, Symbol};
let lib = Library::new("libplugin.so")?;
let func: Symbol<fn() -> i32> = lib.get(b"plugin_init")?;

// Cargo features 控制依賴
// Cargo.toml:
// [features]
// postgres = ["sqlx/postgres"]
// sqlite = ["sqlx/sqlite"]
```

- Cargo features 是編譯時的 Link Seam——不同 feature 組合連結不同的程式碼
- `libloading` 是 runtime 動態載入——unsafe，需要手動保證 ABI 相容
- `extern "C"` 函式是 FFI 邊界——calling convention 是合約

---

## 7. Sprout/Wrap 策略

### Sprout Function

```rust
// Before
fn process_order(order: Order) -> Result<Receipt> {
    // 200 lines of mixed validation + processing
}

// After
fn process_order(order: Order) -> Result<Receipt> {
    let validated = validate_order(&order)?;
    process_validated(validated)
}

// Sprouted — independently testable
fn validate_order(order: &Order) -> Result<ValidatedOrder> {
    ensure!(!order.items.is_empty(), "Order must have items");
    ensure!(order.total > 0, "Total must be positive");
    Ok(ValidatedOrder::from(order))
}
```

**Rust 優勢：** `?` 運算子讓 error propagation 零摩擦——sprout function 的錯誤自然傳播到 caller。

### Wrap via Newtype

```rust
struct UserId(String);
struct Email(String);

impl UserId {
    fn new(id: impl Into<String>) -> Result<Self> {
        let id = id.into();
        ensure!(!id.is_empty(), "UserId cannot be empty");
        Ok(Self(id))
    }
}
```

**Rust 優勢：** Newtype pattern 提供零成本抽象——編譯時型別安全，runtime 無開銷。防止 primitive obsession（傳錯 String 參數）。

### Wrap via Middleware (Tower)

```rust
use tower::{ServiceBuilder, ServiceExt};

let service = ServiceBuilder::new()
    .timeout(Duration::from_secs(30))
    .rate_limit(100, Duration::from_secs(1))
    .service(MyService);
```

**Rust 優勢：** Tower 的 `Service` trait 是通用的 middleware 抽象——每層是獨立的 struct，可單獨測試。

### Wrap via Decorator (Trait impl)

```rust
struct LoggingRepo<T: Repository> {
    inner: T,
}

impl<T: Repository> Repository for LoggingRepo<T> {
    async fn get(&self, id: &str) -> Result<User> {
        tracing::info!(id, "fetching user");
        let result = self.inner.get(id).await;
        tracing::info!(id, ?result, "fetch complete");
        result
    }

    async fn save(&self, user: &User) -> Result<()> {
        self.inner.save(user).await
    }
}
```

**Rust 優勢：** 泛型 Decorator 不需要 dynamic dispatch——monomorphization 在編譯時展開為直接呼叫。

---

## 8. 常見隱含合約範例

### 8.1 unwrap() / expect() panic

```rust
let value = some_option.unwrap(); // None 時 panic
let data = result.expect("should not fail"); // Err 時 panic
```

**重構風險：** 將 `unwrap` 改為 `?` 改變了錯誤處理策略——從 panic（terminate）到 propagate（caller 處理）。反向也成立。

### 8.2 Iterator 惰性求值

```rust
let mapped = vec.iter().map(|x| x * 2);
// 此時什麼都沒發生！map 是惰性的
let collected: Vec<_> = mapped.collect(); // 此時才執行
```

**重構風險：** 將 eager（`for` loop）改為 lazy（iterator chain）可能改變副作用的執行時機和順序。

### 8.3 String vs &str

```rust
fn greet(name: &str) { }      // 借用，零拷貝
fn greet_owned(name: String) { } // 取得 ownership

greet("hello");                // &str 直接傳遞
greet_owned("hello".to_string()); // 需要分配
```

**重構風險：** 將 `&str` 參數改為 `String` 強制所有 caller 分配記憶體——效能影響可能很大。反向可能讓函式無法存儲參數。

### 8.4 unsafe 合約

```rust
unsafe fn dangerous(ptr: *const u8, len: usize) -> &[u8] {
    // caller 必須保證：
    // 1. ptr 是有效的，指向 len 個連續 u8
    // 2. ptr 在回傳的 reference 存活期間不被修改
    // 3. ptr 不是 null
    std::slice::from_raw_parts(ptr, len)
}
```

**重構風險：** `unsafe` 的 safety invariant 是純文件合約——編譯器不驗證，違反導致 undefined behavior。

### 8.5 impl Drop 與 panic

```rust
impl Drop for Resource {
    fn drop(&mut self) {
        if self.handle.is_valid() {
            self.handle.close(); // 如果 close() panic?
        }
    }
}
```

**重構風險：** Drop 中 panic 在正常情況下「只是」panic，但在 unwinding（另一個 panic 正在處理）時會直接 abort 程式。

### 8.6 Deref 隱式轉換

```rust
let s = String::from("hello");
let r: &str = &s;  // Deref 自動轉換 &String -> &str

let v = vec![1, 2, 3];
let slice: &[i32] = &v;  // Deref 自動轉換 &Vec<i32> -> &[i32]
```

**重構風險：** `Deref` 是隱式的——新增自訂 `Deref` impl 可能改變方法解析順序，導致呼叫到不同的方法。

### 8.7 Pin 與 self-referential struct

```rust
let future = async {
    let data = vec![1, 2, 3];
    let reference = &data;
    some_async_op().await;  // await 點——future 可能被移動
    println!("{:?}", reference); // 如果 future 被移動，reference 失效
};
// Pin<Box<Future>> 防止 future 被移動
```

**重構風險：** 手動 impl `Future` 時忘記 `Pin` 可能導致 undefined behavior——async/await 語法自動處理此問題。

### 8.8 Orphan Rule

```rust
// 不能為外部 crate 的 type 實作外部 crate 的 trait
// impl serde::Serialize for reqwest::Response {} // 編譯錯誤！

// 解法：Newtype wrapper
struct MyResponse(reqwest::Response);
impl serde::Serialize for MyResponse { /* ... */ }
```

**重構風險：** 將型別移到不同 crate 可能使現有的 trait impl 違反 orphan rule——需要 newtype wrapper。

---

## 9. FFI 互操作合約

```rust
// Rust 呼叫 C
extern "C" {
    fn strlen(s: *const c_char) -> usize;
}

let c_str = CString::new("hello").unwrap();
let len = unsafe { strlen(c_str.as_ptr()) };

// C 呼叫 Rust
#[no_mangle]
pub extern "C" fn rust_add(a: i32, b: i32) -> i32 {
    a + b
}
```

稽核要點：
- `extern "C"` 函式必須使用 C-compatible 型別——`String`、`Vec` 等 Rust 型別不能直接傳遞
- `CString::new` 在包含 null byte 時回傳 `Err`——C 字串以 null 結尾
- `CStr::from_ptr` 是 unsafe——caller 必須保證指標有效且以 null 結尾
- `#[no_mangle]` 防止 Rust 的 name mangling——但 symbol 名稱衝突是 caller 的問題
- `Box::into_raw` / `Box::from_raw` 用於跨 FFI 邊界傳遞 heap 物件——每個 `into_raw` 必須恰好對應一個 `from_raw`
- `panic` 跨 FFI 邊界是 undefined behavior——FFI 函式必須 catch_unwind
