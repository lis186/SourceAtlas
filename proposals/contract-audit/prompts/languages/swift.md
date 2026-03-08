# Language Plugin: Swift
# Contract Audit 語言插件 -- Swift / iOS
# Version: 2.0

---

## 適用範圍

- 純 Swift 模組（`.swift`）
- Mixed ObjC + Swift 模組中的 Swift 部分
- iOS / macOS 框架中使用 Swift 的元件
- SwiftUI 或 UIKit 架構

---

## 1. 通知/事件原語

### NotificationCenter
```swift
NotificationCenter.default.post(name: .userDidLogout, object: self, userInfo: ["reason": "expired"])
```

稽核要點：
- Swift 使用 `Notification.Name` 靜態常數（比 ObjC 字串更安全但仍是 runtime 機制）
- `userInfo` 型別為 `[AnyHashable: Any]?`——取值需要強制轉型，轉型失敗是隱含合約
- `addObserver(forName:object:queue:using:)` 回傳的 token 必須保留並在適當時機移除

### Combine
```swift
publisher
    .receive(on: DispatchQueue.main)
    .sink { [weak self] value in
        self?.update(value)
    }
    .store(in: &cancellables)
```

稽核要點：
- `receive(on:)` 的 scheduler 是執行緒合約
- `store(in: &cancellables)` 的生命週期——`cancellables` 被清空時所有訂閱取消
- `sink` 的 closure 捕獲語義（`[weak self]` vs strong capture）
- Publisher 的 `Failure` 型別是合約——`Never` vs 具體錯誤型別

### async/await + AsyncSequence
```swift
for await event in eventStream {
    process(event)
}
```

稽核要點：
- `Task` 的取消傳播——`Task.isCancelled` 是否被檢查
- Structured vs unstructured concurrency（`Task { }` vs `async let`）
- `AsyncSequence` 的終止條件是合約

### Delegate / Protocol Callback
```swift
protocol NetworkClientDelegate: AnyObject {
    func didFinish(with result: Result<Data, Error>)
}
```

稽核要點：
- `AnyObject` 約束確保 weak reference 可行
- protocol 方法的預設實作（extension）可能隱藏合約

---

## 2. 同步原語

### Actor Isolation
```swift
actor NetworkManager {
    var requestCount = 0

    func sendRequest() async {
        requestCount += 1
        // ...
    }
}
```

稽核要點：
- actor 內部狀態自動序列化——但跨 actor 呼叫必須 `await`
- `nonisolated` 方法可以同步存取但不能讀寫 actor 狀態
- `@MainActor` 標記確保在主執行緒執行——是 UI 更新的合約
- actor reentrancy：`await` 點是潛在的狀態變更點

### DispatchQueue
```swift
let serialQueue = DispatchQueue(label: "com.app.serial")
serialQueue.sync { /* critical section */ }
```

稽核要點：
- 與 ObjC 相同：`sync` 在同一 serial queue 上會死鎖
- `DispatchQueue.main.async` 是 UI 更新的常見合約

### async/await
```swift
func fetchData() async throws -> Data {
    try await URLSession.shared.data(from: url).0
}
```

稽核要點：
- `throws` 是錯誤傳播合約——呼叫者必須 `try`
- `async` 標記所有 suspension point——每個 `await` 都是潛在的並行問題
- `Task.checkCancellation()` 是否在長時間操作中被呼叫

### NSLock / os_unfair_lock（Swift wrapper）
```swift
private let lock = NSLock()
func safeAccess() {
    lock.lock()
    defer { lock.unlock() }
    // critical section
}
```

稽核要點：
- `defer` 確保 unlock——但 `throw` 或 early return 前是否已正確處理
- Swift 6 的 `Mutex` 類型提供更安全的替代

---

## 3. 生命週期模式

### UIViewController Lifecycle (UIKit)
```
viewDidLoad() -> viewWillAppear(_:) -> viewDidAppear(_:) -> viewWillDisappear(_:) -> viewDidDisappear(_:) -> deinit
```

稽核要點：
- 與 ObjC 相同的生命週期順序
- `deinit` 中的清理是合約——Combine cancellables、NotificationCenter observer 移除
- `override` 是否呼叫 `super`——遺漏 `super` 呼叫是常見的隱含合約破壞

### SwiftUI Lifecycle
```swift
struct ContentView: View {
    var body: some View { ... }

    .onAppear { /* setup */ }
    .onDisappear { /* cleanup */ }
    .task { /* async work, auto-cancelled on disappear */ }
    .onChange(of: value) { /* react to state change */ }
}
```

稽核要點：
- `.task` 修飾器在 view disappear 時自動取消——這是框架合約
- `.onAppear` 可能被呼叫多次（NavigationStack push/pop）
- `@StateObject` 只初始化一次，`@ObservedObject` 每次 body 重算都可能重建
- `@EnvironmentObject` 缺失會導致 runtime crash

### App Lifecycle (SwiftUI)
```swift
@main
struct MyApp: App {
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup { ContentView() }
            .onChange(of: scenePhase) { phase in
                // active, inactive, background
            }
    }
}
```

---

## 4. 驗證策略

**ast-grep: 完整支援。**

Swift 是 ast-grep 的一級支援語言。所有合約應優先使用 ast-grep 規則驗證。

### ast-grep 規則撰寫指南

```yaml
id: n1-notification-post
message: "N1: UserDidLogout notification -- contract must be present"
severity: error
language: Swift
rule:
  pattern: |
    NotificationCenter.default.post(name: $NAME, object: $OBJ, userInfo: $INFO)
```

**Pattern 注意事項：**
- 使用 `$VAR` 匹配單一節點，`$$$` 匹配多節點序列
- 避免在 pattern 中包含 closure 捕獲列表（`[weak self]`）——ast-grep 無法正確匹配
- 對於 `addObserver` 類合約，使用 `all + kind + has` 組合：
  ```yaml
  rule:
    all:
      - kind: function_declaration
      - has:
          regex: "addObserver"
      - has:
          regex: "specificNotificationName"
  ```
- `severity: error` 表示合約必須存在（找到 = PASS）
- `severity: warning` 表示 lint/bug 偵測規則（找到 = FAIL）

### grep 作為補充

某些合約可能更適合用 grep 驗證（例如字串常量、設定值）。語言插件不禁止使用 grep，但 ast-grep 應為首選。

### Mixed ObjC + Swift 模組

- Swift 部分：使用 ast-grep 規則（Artifact 2b）
- ObjC 部分：參見 objc.md 語言插件
- 跨語言合約：兩側都驗證，Coverage Table 中明確連結

---

## 5. Effect 防火牆

**強度：強。**

Swift 提供多層語言層級的不可變性保證：

### let 宣告
```swift
let value = 42  // 不可重新賦值
```
- `let` 對 value type 是完全不可變的
- `let` 對 reference type 只保證 reference 不變，object 內部狀態仍可變

### Value Types (struct, enum, tuple)
```swift
struct Point { var x: Int; var y: Int }
let p = Point(x: 1, y: 2)  // p.x 和 p.y 都不可變
```
- 傳遞 value type 時自動複製——不會產生共享狀態
- `mutating` 關鍵字明確標記會修改 self 的方法

### Actor Isolation
```swift
actor Counter {
    var count = 0  // 只能在 actor 內部同步存取
}
```
- Actor 內部狀態自動受保護
- 跨 actor 存取必須 `await`——編譯器強制

### Sendable Protocol
```swift
struct Config: Sendable {
    let apiKey: String
    let timeout: TimeInterval
}
```
- `Sendable` 標記型別可安全跨並行邊界傳遞
- 編譯器檢查 `Sendable` 合規性（Swift 6 strict concurrency）

**稽核影響：**
- 對 `let` + value type 的組合，不需要追蹤並行修改
- 對 `var` + reference type，需要與 ObjC 相同等級的警覺
- Actor-isolated 狀態可以信任其序列化保證
- `@unchecked Sendable` 是手動繞過——必須標記為潛在風險

---

## 6. Seam 類型

### Object Seam（Protocol）
```swift
protocol NetworkClient {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}
```

- Swift protocol 不支援 `@optional`（除非 `@objc optional`）——所有方法必須實作
- Protocol extension 提供預設實作——預設實作本身是隱含合約
- 泛型約束（`where T: NetworkClient`）是編譯期的接縫

### Preprocessing Seam（條件編譯）
```swift
#if DEBUG
    enableDebugMode()
#endif

#if canImport(UIKit)
    // iOS-specific code
#endif

@available(iOS 16.0, *)
func newFeature() { ... }
```

- `#if` 條件編譯與 ObjC 相同
- `@available` 是 runtime 檢查——但呼叫端的 `if #available` 守衛是合約
- Swift 沒有巨集（直到 Swift 5.9 Macros）——巨集展開是新的 Preprocessing Seam

### Swift Macros (5.9+)
```swift
@Observable
class ViewModel {
    var name: String = ""  // macro 自動生成 observation infrastructure
}
```

- Macro 展開的程式碼是隱含合約——開發者可能不知道展開後的完整行為
- 使用 `swift package dump-syntax-tree` 可以檢視展開結果

**Note: Swift 不支援 Link Seam。** 沒有 category 或 method swizzling 的原生機制。`@objc` 標記的方法仍可被 ObjC runtime swizzle，但這不是 Swift 原生特性。

---

## 7. Sprout/Wrap 策略

所有四種 Feathers 策略均適用於 Swift，且有語言特定的優勢：

### Sprout Method
```swift
// Before
func handleRequest(_ request: URLRequest) async throws -> Data {
    // 200 lines of mixed logic
}

// After
func handleRequest(_ request: URLRequest) async throws -> Data {
    let authedRequest = injectAuthHeaders(request)  // sprouted
    // remaining logic
}

// Sprouted method -- independently testable
private func injectAuthHeaders(_ request: URLRequest) -> URLRequest {
    var mutable = request
    mutable.setValue(authToken, forHTTPHeaderField: "Authorization")
    return mutable
}
```

**Swift 優勢：** value type (URLRequest) 確保 sprout method 不會意外修改原始參數

### Sprout Class
```swift
struct AuthHeaderInjector {
    let tokenProvider: () -> String?

    func inject(into request: URLRequest) -> URLRequest {
        var mutable = request
        if let token = tokenProvider() {
            mutable.setValue(token, forHTTPHeaderField: "Authorization")
        }
        return mutable
    }
}
```

**Swift 優勢：** struct 可以用 closure 注入依賴，不需要 protocol

### Wrap Method
```swift
func handleRequest(_ request: URLRequest) async throws -> Data {
    log(request)
    let result = try await handleRequest_original(request)
    log(result)
    return result
}
```

**Swift 優勢：** `async throws` 自動傳播錯誤和取消

### Wrap Class (Decorator)
```swift
struct LoggingNetworkClient: NetworkClient {
    let wrapped: NetworkClient

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        logger.debug("Sending: \(request.url?.absoluteString ?? "")")
        let result = try await wrapped.send(request)
        logger.debug("Received: \(result.1.statusCode)")
        return result
    }
}
```

**Swift 優勢：** protocol conformance 確保 wrapper 與原始型別介面一致

### Interceptor Chain（Swift 特有模式）
```swift
protocol RequestInterceptor {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

protocol ResponseInterceptor {
    func intercept(_ response: (Data, URLResponse)) async throws -> (Data, URLResponse)
}
```

**適用場景：** 當多個 Mutation Contract 需要被拆分為獨立、可排序的處理步驟

---

## 8. 常見隱含合約範例

### 8.1 Optional 解包假設
```swift
// 隱含合約：fetchUser() 一定回傳非 nil（但簽名是 Optional）
let user = try await fetchUser()!  // force unwrap = crash if nil

// 更微妙的版本
guard let user = try await fetchUser() else { return }  // 靜默 return 是合約
```

### 8.2 Actor Reentrancy
```swift
actor SessionManager {
    var token: String?

    func refreshIfNeeded() async {
        if token == nil {
            // 隱含合約：await 之後 token 可能已被另一個呼叫者設定
            token = try? await authService.refresh()
            // 另一個 caller 可能在 await 期間也進入此方法
        }
    }
}
```

### 8.3 Combine Pipeline 順序
```swift
// 隱含合約：debounce -> removeDuplicates -> map 的順序不可變更
searchText
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .removeDuplicates()
    .map { query in SearchRequest(query: query) }
    .sink { [weak self] request in self?.search(request) }
    .store(in: &cancellables)
```

### 8.4 @MainActor 傳播
```swift
// 隱含合約：viewModel 的所有 public 方法必須在主執行緒呼叫
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [Item] = []

    func load() async {
        items = try? await service.fetchItems() ?? []
    }
}
```

### 8.5 Task 取消傳播
```swift
// 隱含合約：.task modifier 在 view disappear 時取消 Task
// 如果 loadData() 內部啟動了 unstructured Task，那個 Task 不會被取消
struct ListView: View {
    var body: some View {
        List(items) { item in ... }
            .task { await viewModel.loadData() }
    }
}

// ViewModel 中的隱含合約破壞
func loadData() async {
    Task {  // unstructured -- 不會隨 parent 取消
        await backgroundSync()
    }
}
```

### 8.6 Codable 欄位合約
```swift
// 隱含合約：JSON 必須包含 "id" 和 "name" 欄位，否則整個解碼失敗
struct User: Codable {
    let id: Int
    let name: String
    var email: String?  // optional -- 缺少不會導致解碼失敗
}
```

**重構風險：** 如果後端 API 將 `id` 欄位從 `Int` 改為 `String`（例如遷移至 UUID），或新增一個非 optional 欄位，整個 `Codable` 自動合成的 `init(from:)` 會解碼失敗並拋出 `DecodingError`。由於 Swift 的 `Codable` 採用全有或全無策略，單一欄位不匹配即導致整筆資料解碼失敗——不會產生編譯錯誤，只在 runtime 拋出例外。當多個 model 共用同一個 API 回應時，一處欄位變更可能導致不相關的資料也無法解析。

### 8.7 Protocol Extension 預設實作隱藏
```swift
protocol Trackable {
    func track(event: String)
}

extension Trackable {
    // 隱含合約：如果實作者未覆寫此方法，事件會被靜默忽略
    func track(event: String) {
        // default: do nothing
    }
}
```
