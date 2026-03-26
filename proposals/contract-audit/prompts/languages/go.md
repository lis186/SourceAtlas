# Language Plugin: Go
# Contract Audit 語言插件 -- Go / Standard Library / Common Frameworks
# Version: 1.0

---

## 適用範圍

- 純 Go 模組（`.go`）
- 標準庫 HTTP server（`net/http`）
- Web 框架（Gin, Echo, Fiber, Chi）
- gRPC 服務
- CLI 工具（Cobra, urfave/cli）
- 資料庫存取（`database/sql`, GORM, sqlx）
- cgo 混合模組中的 Go 部分

---

## 1. 通知/事件原語

### Channel

```go
// 無緩衝 channel——send 和 receive 必須同時就緒
ch := make(chan Event)

// 有緩衝 channel——buffer 滿時 send 阻塞
ch := make(chan Event, 100)

// 方向性 channel——限制 send 或 receive
func producer(out chan<- Event) { out <- Event{} }
func consumer(in <-chan Event)  { e := <-in }
```

稽核要點：
- 無緩衝 channel 是同步點——send 和 receive 必須配對出現，否則 goroutine 永久阻塞（洩漏）
- `nil` channel 的 send 和 receive 都永久阻塞——這是合約，不是 bug（常用於動態禁用 select case）
- `close(ch)` 後 send 會 panic——close 是「不再有更多值」的合約信號
- closed channel 的 receive 立即回傳零值——消費端必須用 `v, ok := <-ch` 檢查
- Channel 是 FIFO——但多個 goroutine 從同一 channel receive 時，誰拿到值是不確定的（fan-out）

### select

```go
select {
case msg := <-msgCh:
    handle(msg)
case err := <-errCh:
    handleError(err)
case <-ctx.Done():
    return ctx.Err()
case <-time.After(5 * time.Second):
    return ErrTimeout
}
```

稽核要點：
- 多個 case 同時就緒時，Go runtime 隨機選擇一個——不保證順序
- `default` case 使 select 非阻塞——沒有 `default` 時 select 永久阻塞直到某 case 就緒
- `time.After` 每次呼叫都建立新 timer——在迴圈中使用會洩漏，應改用 `time.NewTimer` + `Reset`
- 沒有 `ctx.Done()` case 的 select 無法被取消——違反 context 取消傳播合約

### Context 作為事件傳播

```go
ctx, cancel := context.WithCancel(parentCtx)
defer cancel()

// 子 goroutine 監聽取消
go func() {
    select {
    case <-ctx.Done():
        cleanup()
        return
    case work := <-workCh:
        process(work)
    }
}()
```

稽核要點：
- `context.WithCancel` / `WithTimeout` / `WithDeadline` 回傳的 `cancel` 必須被呼叫——不呼叫會洩漏 context 樹中的資源
- 父 context 取消會傳播到所有子 context——但子 context 取消不影響父
- `context.Value` 是隱含依賴——key 的型別必須是 unexported type 以避免碰撞

### Callback / Handler 模式

```go
http.HandleFunc("/api/users", func(w http.ResponseWriter, r *http.Request) {
    // handler 在獨立 goroutine 中執行
})

server.RegisterOnShutdown(func() {
    // shutdown callback
})
```

稽核要點：
- `http.HandleFunc` 在同一 pattern 上多次註冊時，最後一個生效——是 replace 語義
- handler function 在獨立 goroutine 中執行——handler 中存取共享狀態需要同步

---

## 2. 同步原語

### Goroutine

```go
go func() {
    result := heavyComputation()
    resultCh <- result
}()
```

稽核要點：
- goroutine 沒有 parent/child 關係——啟動者無法直接等待、取消或檢查 goroutine 狀態
- goroutine 洩漏是 Go 最常見的合約違反——每個 `go` 關鍵字都需要回答「這個 goroutine 何時結束？」
- goroutine 的 panic 只能在同一 goroutine 中 recover——未 recover 的 panic 會終止整個程式
- `runtime.GOMAXPROCS` 控制並行 OS thread 數——但 goroutine 數量不受限

### sync.Mutex / sync.RWMutex

```go
var mu sync.Mutex
mu.Lock()
defer mu.Unlock()
// critical section

var rwmu sync.RWMutex
rwmu.RLock()
defer rwmu.RUnlock()
// read-only section
```

稽核要點：
- `sync.Mutex` 不可重入——同一 goroutine 重複 Lock 會死鎖
- `sync.Mutex` 是值型別——複製 mutex 後兩個 mutex 獨立，保護不同 critical section（通常是 bug）
- `defer mu.Unlock()` 確保 panic 時也能釋放鎖
- `RWMutex` 的 `RLock` 和 `Lock` 之間的飢餓問題——頻繁 RLock 可能導致 Lock 長期等待

### sync.WaitGroup

```go
var wg sync.WaitGroup
for _, item := range items {
    wg.Add(1)
    go func(item Item) {
        defer wg.Done()
        process(item)
    }(item)
}
wg.Wait()
```

稽核要點：
- `Add` 必須在 `go` 之前呼叫——在 goroutine 內呼叫 `Add` 可能導致 `Wait` 提前返回
- `Add` 和 `Done` 必須配對——不配對會永久阻塞或 panic（counter < 0）
- `WaitGroup` 不可在 `Wait` 期間重用——`Wait` 返回後才能重新 `Add`

### sync.Once

```go
var once sync.Once
var instance *Service

func GetService() *Service {
    once.Do(func() {
        instance = &Service{}
    })
    return instance
}
```

稽核要點：
- `once.Do(f)` 中 `f` panic 的話，`Do` 仍算「已執行」——後續呼叫不會重試
- `sync.Once` 是值型別——複製後各自獨立
- `sync.OnceValue` / `sync.OnceValues`（Go 1.21+）簡化了帶回傳值的場景

### sync.Map

```go
var m sync.Map
m.Store("key", value)
v, ok := m.Load("key")
```

稽核要點：
- `sync.Map` 不是泛型——`Load` 回傳 `any`，需要型別斷言
- 適用場景有限：key 集合穩定或 key 分散（disjoint goroutine 寫入）——其他場景 `Mutex + map` 更快
- `Range` 不保證遍歷期間的一致性快照

### atomic

```go
var counter atomic.Int64
counter.Add(1)
val := counter.Load()
```

稽核要點：
- `atomic` 操作只保證單一變數的原子性——多個變數之間的一致性仍需 Mutex
- `atomic.Value` 的 `Store` 後續呼叫必須存入相同型別——違反會 panic

---

## 3. 生命週期模式

### HTTP Server Lifecycle

```go
server := &http.Server{Addr: ":8080", Handler: mux}

// 啟動
go func() {
    if err := server.ListenAndServe(); err != http.ErrServerClosed {
        log.Fatal(err)
    }
}()

// Graceful shutdown
quit := make(chan os.Signal, 1)
signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
<-quit

ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()
server.Shutdown(ctx)
```

稽核要點：
- `ListenAndServe` 在 `Shutdown` 後回傳 `http.ErrServerClosed`——這不是錯誤，是正常流程
- `Shutdown` 等待所有進行中的請求完成——但 WebSocket/長連線需要額外處理
- `signal.Notify` 的 channel 必須有緩衝——無緩衝可能錯過信號
- `RegisterOnShutdown` 的 callback 在 `Shutdown` 開始時呼叫，不是結束時

### context.Context Lifecycle

```go
func handleRequest(ctx context.Context) error {
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel() // 必須呼叫，即使 timeout 到期

    result, err := doWork(ctx)
    if err != nil {
        return err
    }
    return nil
}
```

稽核要點：
- 每個接受 `context.Context` 的函式都承諾尊重取消——不檢查 `ctx.Done()` 是違約
- `context.TODO()` 是暫時標記——程式碼中存在 `TODO()` 表示 context 傳播鏈未完成
- `context.Background()` 只應在 main、init、測試的頂層使用——其他地方應從 caller 接收

### defer 與資源清理

```go
f, err := os.Open(path)
if err != nil {
    return err
}
defer f.Close()
```

稽核要點：
- `defer` 按 LIFO 順序執行——多個 defer 的執行順序是反向的
- `defer` 的引數在宣告時求值——`defer fmt.Println(x)` 捕獲的是當時的 `x` 值
- 迴圈中的 `defer` 在函式結束時才執行——不是在迴圈迭代結束時，可能導致資源堆積
- `defer f.Close()` 忽略了 Close 的 error——寫入檔案時 Close 的 error 可能表示資料未完整寫入

### database/sql Connection Lifecycle

```go
db, err := sql.Open("postgres", connStr)
if err != nil {
    return err
}
defer db.Close()

db.SetMaxOpenConns(25)
db.SetMaxIdleConns(5)
db.SetConnMaxLifetime(5 * time.Minute)
```

稽核要點：
- `sql.Open` 不建立連線——只驗證 driver，首次查詢才連線
- `db.Close()` 在程式生命週期結束時呼叫——過早關閉會導致所有查詢失敗
- 不設 `MaxOpenConns` 預設無限——可能耗盡資料庫連線
- `ConnMaxLifetime` 過短會導致頻繁重連，過長可能使用到資料庫已關閉的連線

### os.Signal 處理

```go
sigCh := make(chan os.Signal, 1)
signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

go func() {
    sig := <-sigCh
    log.Printf("received signal: %v", sig)
    // graceful shutdown
}()
```

稽核要點：
- `signal.Notify` 不會阻止信號的預設行為——需要 `signal.Reset` 恢復預設
- 第二次收到同一信號時，如果 channel 滿了，信號會被丟棄
- SIGKILL 和 SIGSTOP 無法被捕獲

---

## 4. 驗證策略

**ast-grep: 完整支援。**

Go 是 ast-grep 的支援語言。所有合約應優先使用 ast-grep 規則驗證。

### ast-grep 規則撰寫指南

```yaml
id: s1-goroutine-leak
message: "S1: goroutine started without cancellation mechanism"
severity: warning
language: Go
rule:
  pattern: |
    go func() { $$$ }()
  not:
    inside:
      pattern: |
        select { case <-$CTX.Done(): $$$ }
```

**Pattern 注意事項：**
- Go 的 `defer` 語法需要注意：`defer func() {}()` vs `defer f()`
- goroutine 啟動 `go func(){}()` vs `go namedFunc()`
- 使用 `kind: call_expression` + `has` 組合匹配方法鏈

### grep 作為補充

```bash
# 檢查 goroutine 啟動點
grep -n 'go func\|go [a-z]' "$file"

# 檢查 context 傳播
grep -n 'context\.Background\|context\.TODO' "$file"

# 檢查 mutex 使用
grep -n 'sync\.Mutex\|\.Lock()\|\.Unlock()' "$file"

# 檢查 channel close
grep -n 'close(' "$file" | grep -v '//'

# 檢查 defer 使用
grep -n 'defer ' "$file"
```

---

## 5. Effect 防火牆

**強度：中。**

Go 缺乏 `const` 對複雜型別的支援，但透過其他機制提供不可變性保證。

### Unexported Fields

```go
type User struct {
    name string  // unexported——package 外無法存取
    Age  int     // exported——package 外可存取
}
```

- 小寫字段和方法是 package-level 封裝——這是 Go 唯一的存取控制機制
- 沒有 class-level private——同 package 內的任何檔案都能存取 unexported field

### Value Semantics

```go
type Point struct{ X, Y int }

func move(p Point) Point {
    p.X += 1  // 修改副本，不影響原值
    return p
}
```

- struct 是值型別——賦值和傳參都是複製
- slice、map、channel 是引用型別——共享底層資料
- `*Point`（指標）允許原地修改——選擇值或指標 receiver 是隱含合約

### Interface 作為合約

```go
type Reader interface {
    Read(p []byte) (n int, err error)
}
```

- interface 是隱式實作——不需要 `implements` 關鍵字
- 滿足 interface 的所有方法就算實作——新增 interface 方法會破壞所有現有實作
- 空 interface `any`（`interface{}`）放棄所有型別保證

**稽核影響：**
- 小寫 field/method 可以信任 package 外不可變
- slice/map 參數需要追蹤所有修改點（即使函式簽名看起來無害）
- interface 的隱式實作意味著「移除一個方法」可能無聲地破壞 interface 滿足

---

## 6. Seam 類型

### Object Seam（Interface）

```go
type UserRepository interface {
    GetUser(ctx context.Context, id string) (*User, error)
    SaveUser(ctx context.Context, user *User) error
}

type postgresRepo struct {
    db *sql.DB
}

func (r *postgresRepo) GetUser(ctx context.Context, id string) (*User, error) {
    // ...
}
```

- Go interface 的隱式實作是天然的 Object Seam——任何 struct 都能成為替代品
- 測試中常用 mock struct 替換真實實作
- 「Accept interfaces, return structs」是 Go 慣例——interface 定義在消費端

### Preprocessing Seam（Build Tags）

```go
//go:build linux
// +build linux

package mypackage

func platformSpecific() {
    // 只在 Linux 上編譯
}
```

- build tag 在編譯時選擇檔案——不同平台/環境可以有完全不同的實作
- `_test.go` 後綴是內建的 build tag——測試程式碼不會編譯進生產二進位
- `//go:generate` 觸發程式碼生成——生成的程式碼是隱含依賴

### Link Seam（Plugin / Build-time）

```go
import _ "github.com/lib/pq"  // blank import 註冊 driver

// plugin package (少見但存在)
p, _ := plugin.Open("plugin.so")
sym, _ := p.Lookup("Handler")
```

- blank import `_` 觸發 `init()` 副作用——是最隱蔽的 Link Seam
- `init()` 函式在 package 載入時自動執行——執行順序依 import 順序，不易控制
- `database/sql` driver 註冊是經典的 blank import Link Seam

---

## 7. Sprout/Wrap 策略

### Sprout Function

```go
// Before
func ProcessOrder(order Order) (Receipt, error) {
    // 200 lines of mixed validation + processing
}

// After
func ProcessOrder(order Order) (Receipt, error) {
    if err := validateOrder(order); err != nil {
        return Receipt{}, err
    }
    // remaining logic
}

// Sprouted — independently testable
func validateOrder(order Order) error {
    if len(order.Items) == 0 {
        return errors.New("order must have items")
    }
    if order.Total <= 0 {
        return fmt.Errorf("invalid total: %d", order.Total)
    }
    return nil
}
```

**Go 優勢：** 多回傳值 `(result, error)` 讓 sprout function 的錯誤處理自然地融入呼叫鏈。

### Wrap via Middleware（HTTP）

```go
func LoggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        next.ServeHTTP(w, r)
        log.Printf("%s %s %v", r.Method, r.URL.Path, time.Since(start))
    })
}

// 使用
handler = LoggingMiddleware(AuthMiddleware(handler))
```

**Go 優勢：** `http.Handler` interface + `HandlerFunc` adapter 是天然的 Wrap 機制——middleware 鏈是 Go web 框架的核心模式。

### Wrap via Interface Delegation

```go
type LoggingRepo struct {
    inner UserRepository
    log   *slog.Logger
}

func (r *LoggingRepo) GetUser(ctx context.Context, id string) (*User, error) {
    r.log.Info("GetUser", "id", id)
    user, err := r.inner.GetUser(ctx, id)
    if err != nil {
        r.log.Error("GetUser failed", "id", id, "err", err)
    }
    return user, err
}
```

**Go 優勢：** interface 隱式實作讓 Decorator pattern 不需要繼承——任何滿足 interface 的 struct 都可以 wrap。

### Functional Options Pattern

```go
type Option func(*Server)

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func NewServer(opts ...Option) *Server {
    s := &Server{timeout: 30 * time.Second}
    for _, opt := range opts {
        opt(s)
    }
    return s
}
```

**Go 優勢：** Functional options 是 Go 最常用的建構模式——新增選項不破壞既有呼叫者。

---

## 8. 常見隱含合約範例

### 8.1 nil channel 永久阻塞

```go
var ch chan int  // nil channel
ch <- 1         // 永久阻塞
<-ch            // 永久阻塞
```

**重構風險：** 將 channel 初始化移到條件分支中，某些路徑 channel 保持 nil——send/receive 永久阻塞，不是 panic。

### 8.2 Goroutine 洩漏

```go
func fetch(url string) <-chan Result {
    ch := make(chan Result)
    go func() {
        resp, err := http.Get(url)
        ch <- Result{resp, err}  // 如果沒人讀 ch，goroutine 永久阻塞
    }()
    return ch
}
```

**重構風險：** caller 不讀回傳的 channel（例如 timeout 後放棄），goroutine 永久存活，佔用記憶體和連線。

### 8.3 slice append 覆蓋

```go
original := []int{1, 2, 3, 4, 5}
slice1 := original[:3]  // [1, 2, 3], 共享底層 array
slice1 = append(slice1, 99)  // original[3] 被覆蓋為 99！
```

**重構風險：** 將 slice 傳遞給函式後，函式的 `append` 可能修改 caller 的資料——除非 slice 已經到達 capacity。

### 8.4 Map 並發存取 panic

```go
m := make(map[string]int)
// 兩個 goroutine 同時讀寫 map -> fatal error: concurrent map writes
go func() { m["a"] = 1 }()
go func() { m["b"] = 2 }()
```

**重構風險：** 將單線程程式碼改為並發時，未加鎖的 map 存取會直接 crash（Go 1.6+ 的 race detector 會檢測到）。

### 8.5 Interface nil vs typed nil

```go
type MyError struct{}
func (e *MyError) Error() string { return "error" }

func getError() error {
    var err *MyError  // typed nil
    return err        // 回傳 non-nil error！
}

if getError() != nil {
    // 永遠進入這裡——即使 err 指標本身是 nil
}
```

**重構風險：** 將具體型別改為 interface 回傳時，typed nil 會被視為 non-nil interface——這是 Go 最微妙的合約陷阱。

### 8.6 defer 引數求值時機

```go
func example() {
    x := 1
    defer fmt.Println(x)  // 印出 1，不是 2
    x = 2
}

func example2() {
    x := 1
    defer func() { fmt.Println(x) }()  // 印出 2（closure 捕獲 x）
    x = 2
}
```

**重構風險：** 將 `defer f(x)` 改為 `defer func() { f(x) }()` 會改變行為——前者捕獲值，後者捕獲引用。

### 8.7 init() 執行順序

```go
// 同一 package 內多個檔案的 init() 按檔名字母順序執行
// 不同 package 的 init() 按 import 依賴順序執行

func init() {
    // 註冊 driver、設定全域變數等副作用
}
```

**重構風險：** 移動程式碼到不同檔案可能改變 init() 的執行順序——如果 init() 之間有依賴，行為會改變。

### 8.8 Error wrapping 鏈

```go
if err != nil {
    return fmt.Errorf("failed to fetch user: %w", err)
}

// 呼叫端
if errors.Is(err, sql.ErrNoRows) {
    // 只有 %w 才能被 errors.Is 找到——%v 會切斷 error chain
}
```

**重構風險：** 將 `%w`（wrap）改為 `%v`（format）會切斷 error chain——所有用 `errors.Is` / `errors.As` 檢查的地方都會失效。

---

## 9. cgo 互操作合約

```go
/*
#include <stdlib.h>
*/
import "C"
import "unsafe"

func example() {
    cStr := C.CString("hello")
    defer C.free(unsafe.Pointer(cStr))  // 必須手動釋放
    // ...
}
```

稽核要點：
- `C.CString` 分配 C heap 記憶體——必須手動 `C.free`，Go GC 不管理
- cgo 呼叫會鎖定 OS thread——頻繁 cgo 呼叫可能耗盡 `GOMAXPROCS` 個 thread
- `unsafe.Pointer` 繞過所有型別安全——是最高風險的操作
- cgo 不支援 goroutine 跨越——C callback 不能直接呼叫 Go closure
