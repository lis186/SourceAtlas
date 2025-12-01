# Swift/iOS 入口點和邊界模式研究報告

基於 4 個真實 iOS 專案的分析：Signal-iOS、WordPress-iOS、Swiftfin、***REMOVED***

## 1. 入口點模式（Entry Points）

### 1.1 App 啟動入口（Application Entry）

| 類型 | Pattern | 範例 | 檔案位置 | 優先級 |
|------|---------|------|----------|-------|
| **App 主入口（SwiftUI）** | `@main` | `struct SwiftfinApp: App { var body: some Scene }` | SwiftfinApp.swift | **CRITICAL** |
| **App 主入口（UIKit）** | `@UIApplicationMain` | `class AppDelegate: UIResponder, UIApplicationDelegate` | AppDelegate.swift | **CRITICAL** |
| **AppDelegate 方法** | `func application(_:didFinishLaunchingWithOptions:)` | 初始化 logging, database, DI 容器 | AppDelegate.swift:158 | **CRITICAL** |
| **SceneDelegate（多場景）** | `func scene(_:willConnectTo:options:)` | SwiftUI WindowGroup 初始化 | 通常在 @main 中定義 | HIGH |

**實例片段（Signal-iOS AppDelegate.swift:158-180）**：
```swift
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let launchStartedAt = CACurrentMediaTime()
        NSSetUncaughtExceptionHandler(uncaughtExceptionHandler(_:))
        let mainAppContext = MainAppContext()
        SetCurrentAppContext(mainAppContext, isRunningTests: false)
        debugLogger.enableFileLogging(appContext: mainAppContext, canLaunchInBackground: true)
        // ... 初始化 database, DI, services ...
        return true
    }
}
```

### 1.2 UI 入口（View Lifecycle）

#### UIKit ViewController 生命週期

| 事件 | Pattern | 追蹤點 | 範例 |
|------|---------|--------|------|
| **初始化** | `init(coder:)`, `init(nibName:bundle:)` | 構造函數 | ConversationViewController.load() |
| **視圖加載** | `func viewDidLoad()` | 控制器初始化後 | UIViewController 子類 |
| **視圖即將出現** | `func viewWillAppear(_:)` | 動畫前 | 訂閱事件、刷新資料 |
| **視圖已出現** | `func viewDidAppear(_:)` | 動畫完成後 | 啟動計時器、播放動畫 |
| **視圖即將消失** | `func viewWillDisappear(_:)` | 動畫前 | 清理資源、儲存狀態 |
| **視圖已消失** | `func viewDidDisappear(_:)` | 動畫完成後 | 停止計時器、取消訂閱 |

#### SwiftUI 視圖生命週期

| 事件 | Pattern | 追蹤點 | 範例 |
|------|---------|--------|------|
| **視圖出現** | `.onAppear { }` | 視圖首次出現時 | Swiftfin: `EpisodeMediaPlayerQueue.onAppear` |
| **視圖消失** | `.onDisappear { }` | 視圖移除時 | Swiftfin: `SinceLastDisappearModifier.onDisappear` |
| **狀態對象** | `@StateObject` | 視圖所有者 | `@StateObject var viewModel = ViewModel()` |
| **觀察對象** | `@ObservedObject` | 外部綁定 | `@ObservedObject var store` |
| **環境對象** | `@EnvironmentObject` | 跨層級傳遞 | `.environmentObject(appState)` |

**實例片段（Swiftfin SwiftfinApp.swift:18-46）**：
```swift
@main
struct SwiftfinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate
    
    @StateObject
    private var valueObservation = ValueObservation()
    
    init() {
        // Logging bootstrap
        LoggingSystem.bootstrap { label in
            let handlers: [any LogHandler] = [PersistentLogHandler(label: label)]
            var multiplexHandler = MultiplexLogHandler(handlers)
            multiplexHandler.logLevel = .trace
            return multiplexHandler
        }
        
        // CoreStore setup
        CoreStoreDefaults.dataStack = SwiftfinStore.dataStack
        
        // Nuke image cache configuration
        ImageCache.shared.costLimit = 1024 * 1024 * 200
    }
    
    var body: some Scene {
        WindowGroup {
            OverlayToastView {
                PreferencesView {
                    RootView()
                }
            }
        }
    }
}
```

### 1.3 事件入口（Event Handlers）

#### UIControl 事件

| 事件類型 | Pattern | 追蹤特徵 | 範例 |
|---------|---------|--------|------|
| **Target-Action** | `.addTarget(_:action:for:)` | `#selector()` 方法 | ConversationViewController+GestureRecognizers.swift:21 |
| **IBAction** | `@IBAction func buttonTapped()` | Objective-C Bridge | Signal-iOS（部分仍使用） |
| **GestureRecognizer** | 所有 UIGestureRecognizer 子類 | `gestureRecognizer.delegate` | ConversationViewController+GestureRecognizers.swift |
| **Notification** | `NotificationCenter.default.addObserver()` | 選擇器（@selector） | Signal-iOS AppDelegate:51 |

**實例片段（ConversationViewController+GestureRecognizers.swift:14-52）**：
```swift
func configureGestureRecognizersIfNeeded() {
    guard !collectionViewGestureRecongnizersConfigured else { return }
    
    // Tap gesture
    collectionViewTapGestureRecognizer.setTapDelegate(self)
    collectionViewTapGestureRecognizer.delegate = self
    collectionView.addGestureRecognizer(collectionViewTapGestureRecognizer)
    
    // Long press gesture
    collectionViewLongPressGestureRecognizer.addTarget(self, action: #selector(handleLongPressGesture))
    collectionViewLongPressGestureRecognizer.delegate = self
    collectionView.addGestureRecognizer(collectionViewLongPressGestureRecognizer)
    
    // Context menu gesture
    collectionViewContextMenuGestureRecognizer.addTarget(self, action: #selector(handleLongPressGesture))
    collectionView.addGestureRecognizer(collectionViewContextMenuGestureRecognizer)
    
    // Pan gesture
    collectionViewPanGestureRecognizer.addTarget(self, action: #selector(handlePanGesture))
    collectionViewPanGestureRecognizer.delegate = self
    collectionView.addGestureRecognizer(collectionViewPanGestureRecognizer)
}

// UIGestureRecognizerDelegate
public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard !isShowingSelectionUI else {
        return gestureRecognizer == collectionViewTapGestureRecognizer
    }
    
    if gestureRecognizer == collectionViewPanGestureRecognizer {
        let translation = collectionViewPanGestureRecognizer.translation(in: view)
        return abs(translation.x) > abs(translation.y)
    }
    return true
}
```

### 1.4 網路回調入口（Network Callbacks）

#### URLSession 委托模式

| 回調類型 | Protocol | 方法簽名 | 追蹤特徵 |
|---------|----------|---------|---------|
| **響應接收** | `URLSessionDataDelegate` | `func urlSession(_:dataTask:didReceive:)` | Signal-iOS OWSUrlSession.swift:796 |
| **資料接收** | `URLSessionDataDelegate` | `func urlSession(_:dataTask:didReceive data:)` | Signal-iOS OWSUrlSession.swift:1051 |
| **重定向處理** | `URLSessionTaskDelegate` | `func urlSession(_:task:willPerformHTTPRedirection:)` | Signal-iOS OWSUrlSession.swift:1035 |
| **認證挑戰** | `URLSessionTaskDelegate` | `func urlSession(_:task:didReceive challenge:)` | Signal-iOS OWSUrlSession.swift:703 |
| **快取決策** | `URLSessionDataDelegate` | `func urlSession(_:dataTask:willCacheResponse:)` | Signal-iOS ProxiedContentDownloader.swift:878 |

**實例片段（Signal-iOS OWSUrlSession.swift:905-926）**：
```swift
private class URLSessionDelegateBox: NSObject {
    private let openBlock: OpenBlock
    private let closeBlock: CloseBlock
    
    init(openBlock: @escaping OpenBlock, closeBlock: @escaping CloseBlock) {
        self.openBlock = openBlock
        self.closeBlock = closeBlock
    }
}

extension URLSessionDelegateBox: URLSessionDelegate, URLSessionTaskDelegate, 
                                URLSessionDownloadDelegate, URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, 
                   didReceive response: URLResponse, 
                   completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Handle response
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, 
                   didReceive data: Data) {
        // Accumulate data
    }
}
```

### 1.5 後台任務入口（Background Tasks）

| 任務類型 | Framework | 入口點 | 追蹤特徵 |
|---------|----------|--------|---------|
| **App Refresh** | BackgroundTasks | `BGTaskScheduler.register(forTaskWithIdentifier:using:launchHandler:)` | Signal-iOS MessageFetchBGRefreshTask.swift:59 |
| **Processing Task** | BackgroundTasks | `registerForTaskWithIdentifier(_:using:launchHandler:)` | Signal-iOS BGProcessingTaskRunner.swift |
| **Remote Notification** | UserNotifications | `func application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` | Signal-iOS AppDelegate:1466 |
| **Local Notification** | UserNotifications | `UNUserNotificationCenter.current().delegate` | 通常在 SceneDelegate 設定 |

**實例片段（Signal-iOS MessageFetchBGRefreshTask.swift:59-69）**：
```swift
public static func register(appReadiness: AppReadiness) {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: Self.taskIdentifier,
        using: nil,
        launchHandler: { task in
            appReadiness.runNowOrWhenAppDidBecomeReadyAsync {
                Self.getShared(appReadiness: appReadiness)!.performTask(task)
            }
        }
    )
}
```

### 1.6 Deep Link 和 URL Scheme 入口

| 方法 | 簽名 | 追蹤點 |
|-----|------|--------|
| **Universal Link** | `func application(_:continue:restorationHandler:)` | AppDelegate |
| **Custom Scheme** | `func application(_:open:options:) -> Bool` | AppDelegate:1777 |
| **URL Context** | `func scene(_:openURLContexts:)` | SceneDelegate |

**實例片段（Signal-iOS AppDelegate.swift:1777）**：
```swift
func application(_ app: UIApplication, open url: URL, 
                options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    // Handle URL scheme
    return true
}
```

---

## 2. 邊界模式（Boundaries）

### 2.1 網路邊界（Network Boundaries）

#### URLSession 邊界

| 層級 | Pattern | 實作方式 | 符號 |
|-----|---------|---------|------|
| **低層** | `URLSession.shared` | 單例，直接使用 | 🌐 [Direct] |
| **抽象層** | `OWSURLSession` | 自訂包裝類 | 🌐 [Wrapped] |
| **委托** | `URLSessionDelegate` | Protocol conformance | 🌐 [Delegate] |
| **資料任務** | `URLSessionDataTask` | 異步回調 | 🌐 [Task] |

**Signal-iOS 架構（OWSUrlSession.swift:18-100）**：
```swift
public class OWSURLSession: OWSURLSessionProtocol {
    public let endpoint: OWSURLSessionEndpoint
    
    required public init(
        endpoint: OWSURLSessionEndpoint,
        configuration: URLSessionConfiguration,
        maxResponseSize: Int?,
        canUseSignalProxy: Bool,
        onFailureCallback: ((any Error) -> Void)?,
    ) {
        // 自訂初始化，支援代理、SSL pinning 等
    }
    
    private lazy var delegateBox = URLSessionDelegateBox(delegate: self)
    
    public func dataTask(
        with request: URLRequest,
        completion: @escaping (Result<HTTPResponse, Error>) -> Void
    ) -> URLSessionDataTask {
        // 自訂資料任務包裝
    }
}
```

**委托鏈架構註解（OWSUrlSession.swift:897-902）**：
```
OWSURLSession 
    ↓ (session)
URLSession 
    ↓ (delegate)
URLSessionDelegateBox
    ↓ (implements protocols)
URLSessionDelegate
URLSessionTaskDelegate
URLSessionDataDelegate
URLSessionDownloadDelegate
```

#### Moya/Alamofire 模式

| 框架 | 入口點 | 特徵 |
|-----|--------|------|
| **Moya** | `MoyaProvider<API>.request()` | Plugin-based, enum 驅動 |
| **Alamofire** | `AF.request()` | 鏈式 API |
| **URLSession** | `URLSession.shared.dataTask()` | 委托回調 |

### 2.2 資料庫邊界（Database Boundaries）

#### GRDB（Signal-iOS）

| 操作 | Pattern | 追蹤點 | 符號 |
|-----|---------|--------|------|
| **讀操作** | `db.read { tx in ... }` | SDSDatabaseStorage | 💾 [Read] |
| **寫操作** | `db.write { tx in ... }` | SDSDatabaseStorage | 💾 [Write] |
| **變更觀察** | `DatabaseChangeObserver` | 跨進程通知 | 💾 [Observer] |
| **事務** | `tx: DBReadTransaction`, `tx: DBWriteTransaction` | 資料庫方法參數 | 💾 [Transaction] |

**實例片段（Signal-iOS SDSDatabaseStorage.swift:32-56）**：
```swift
@objc
public class SDSDatabaseStorage: NSObject, DB {
    private let asyncWriteQueue = DispatchQueue(label: "org.signal.database.write-async", qos: .userInitiated)
    private let awaitableWriteQueue = ConcurrentTaskQueue(concurrentLimit: 1)
    
    public init(appReadiness: AppReadiness, databaseFileUrl: URL, keychainStorage: any KeychainStorage) throws {
        self.appReadiness = appReadiness
        self._databaseChangeObserver = DatabaseChangeObserverImpl(appReadiness: appReadiness)
        self.databaseFileUrl = databaseFileUrl
        self.keyFetcher = GRDBKeyFetcher(keychainStorage: keychainStorage)
        self.grdbStorage = try GRDBDatabaseStorageAdapter(
            databaseChangeObserver: _databaseChangeObserver,
            databaseFileUrl: databaseFileUrl,
            keyFetcher: self.keyFetcher
        )
        
        super.init()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
}
```

#### CoreData（WordPress-iOS）和 CoreStore（Swiftfin）

| ORM | Pattern | 特徵 |
|-----|---------|------|
| **CoreData** | `@FetchRequest` | SwiftUI 集成 |
| **CoreStore** | `CoreStoreDefaults.dataStack` | 全局初始化 |
| **自訂** | `db.read(...)` | Signal 設計 |

### 2.3 系統服務邊界（System Service Boundaries）

#### NotificationCenter

| 用途 | Pattern | 追蹤特徵 | 符號 |
|-----|---------|--------|------|
| **應用狀態** | `UIApplication.didBecomeActiveNotification` | AppDelegate | 🔔 [App State] |
| **自訂事件** | `Notification.Name(rawValue: "...")` | 全局常量 | 🔔 [Custom] |
| **發佈** | `NotificationCenter.default.post()` | MainAppContext.swift:48 | 🔔 [Post] |
| **訂閱** | `addObserver(_:selector:name:object:)` | AppDelegate.swift:51 | 🔔 [Subscribe] |

**實例片段（Signal-iOS MainAppContext.swift:48-54）**：
```swift
self.crossProcess = SDSCrossProcess(callback: { @MainActor [weak self] () -> Void in
    self?.handleCrossProcessWrite()
})
NotificationCenter.default.addObserver(self,
                                       selector: #selector(didBecomeActive),
                                       name: UIApplication.didBecomeActiveNotification,
                                       object: nil)
```

#### UserDefaults 和 Keychain

| 儲存類型 | 用途 | Pattern | 框架 |
|---------|------|---------|------|
| **UserDefaults** | 偏好設定、簡單狀態 | `Defaults[.key]` (Swiftfin) | Defaults |
| **Keychain** | 敏感資訊（密碼、令牌） | `KeychainStorageImpl` | Signal 自訂 |
| **Core Data** | 複雜資料模型 | `@FetchRequest` | Apple |
| **GRDB** | 結構化資料 | `db.read {}`  | GRDB |

**Swiftfin 模式**：
```swift
if Defaults[.signOutOnClose] {
    Defaults[.lastSignedInUserID] = .signedOut
}
```

---

## 3. Swift 特殊追蹤挑戰

### 3.1 async/await 追蹤挑戰

| 挑戰 | 範例 | 建議處理方式 |
|-----|------|-------------|
| **隱式線程轉移** | `await MainActor.run { }` | 追蹤 @MainActor 屬性和函數邊界 |
| **任務結構化並發** | `Task { await func() }` | 追蹤 Task 創建和 await 點 |
| **AsyncSequence** | `for await value in sequence` | 追蹤 AsyncSequence 的生產者和消費者 |
| **Function Coloring** | async 函數只能被 await 呼叫 | 必須分離同步和異步呼叫鏈 |

**實例片段（Swiftfin SwiftfinApp+ValueObservation.swift）**：
```swift
for await newValue in Defaults.updates(.lastSignedInUserID) {
    await MainActor.run {
        self.lastSignedInUserID = newValue
    }
}
```

### 3.2 Combine Publisher 追蹤挑戰

| 挑戰 | 範例 | 建議處理方式 |
|-----|------|-------------|
| **鏈式操作** | `.map().filter().sink()` | 追蹤 Publisher 的轉換操作符 |
| **取消令牌** | `AnyCancellable` | 追蹤訂閱生命週期，注意內存洩漏 |
| **背景線程** | `.receive(on: DispatchQueue.main)` | 追蹤 receive(on:) 邊界 |
| **延遲訂閱** | Combine 的「冷」特性 | 追蹤 .sink() 呼叫時機 |

**iOS 特徵**：
- Signal-iOS 傾向于回調而非 Combine（向後兼容 Objective-C）
- WordPress-iOS 部分使用 Combine（新功能）
- Swiftfin（現代 SwiftUI）大量使用 async/await 而非 Combine

### 3.3 Closure 和 Completion Handler 追蹤挑戰

| 挑戰 | Pattern | 追蹤特徵 |
|-----|---------|---------|
| **@escaping 檢查** | `completion: @escaping () -> Void` | 搜索 `@escaping` 關鍵字 |
| **多層嵌套** | 回調地獄 | 追蹤分支和保存狀態 |
| **弱引用** | `[weak self]` capture | 檢查循環引用風險 |
| **線程安全** | `DispatchQueue.main.async` | 追蹤線程邊界 |

**實例片段（Signal-iOS SignalApp.swift:52-67）**：
```swift
func dismissAllModals(animated: Bool, completion: (() -> Void)?) {
    guard let window = CurrentAppContext().mainWindow else {
        owsFailDebug("Missing window.")
        return
    }
    guard let rootViewController = window.rootViewController else {
        owsFailDebug("Missing rootViewController.")
        return
    }
    let hasModal = rootViewController.presentedViewController != nil
    if hasModal {
        rootViewController.dismiss(animated: animated, completion: completion)
    } else {
        completion?()
    }
}
```

### 3.4 Protocol Extension 和 Default Implementation

| 模式 | 追蹤特徵 | 挑戰 |
|-----|---------|------|
| **Protocol with Default** | `extension ProtoName { func method() {} }` | 靜態分析難以確定呼叫目標 |
| **Generic Constraints** | `where Self: SomeType` | 多個實作版本 |
| **Self-Conforming Types** | 在 protocol 中 `Self` 類型參數 | 型別檢查複雜 |

**信號 iOS 例子**：
```swift
extension UIGestureRecognizerDelegate {
    // Optional methods with default do-nothing implementations
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                                shouldReceive event: UIEvent) -> Bool { true }
}
```

---

## 4. 建議新增的偵測規則

### 4.1 高優先級規則（應立即加入）

```
# Entry Point Detection Rules

## Rule 1: @main and @UIApplicationMain
Pattern: `@main\s+(struct|class)|@UIApplicationMain`
Priority: CRITICAL
Description: App entry point marker
Action: Mark as app initialization root

## Rule 2: Application Delegate Methods
Pattern: `func application\(_:\s*(didFinishLaunchingWithOptions|willEnterForeground|didBecomeActive|willResignActive|didEnterBackground)\s*`
Priority: CRITICAL
Description: App lifecycle boundaries
Action: Track state transitions and initialization order

## Rule 3: View Controller Lifecycle
Pattern: `func (viewDidLoad|viewWillAppear|viewDidAppear|viewWillDisappear|viewDidDisappear)\(`
Priority: HIGH
Description: UIViewController lifecycle boundaries
Action: Track view initialization and teardown

## Rule 4: Gesture Recognizer Targets
Pattern: `\.addTarget\(_:action:#selector\(`
Priority: HIGH
Description: Event handlers via target-action
Action: Resolve selector and track handler

## Rule 5: URLSession Delegate
Pattern: `extension\s+\w+.*:\s*(URLSessionDelegate|URLSessionDataDelegate|URLSessionTaskDelegate)`
Priority: HIGH
Description: Network response callbacks
Action: Track network boundary implementations

## Rule 6: NotificationCenter Subscriptions
Pattern: `NotificationCenter\.default\.(addObserver|post).*name:`
Priority: HIGH
Description: System and custom notifications
Action: Track notification producers and consumers

## Rule 7: Closure Entry Points
Pattern: `\{\s*\[weak\s+self\]|@escaping.*Void\s*\)`
Priority: MEDIUM
Description: Completion handlers and callbacks
Action: Track escaping closures and memory safety

## Rule 8: Background Tasks
Pattern: `BGTaskScheduler\.shared\.register\(|beginBackgroundTask\(`
Priority: MEDIUM
Description: Background execution entry points
Action: Track background task lifecycle

## Rule 9: SwiftUI onAppear/onDisappear
Pattern: `\.on(Appear|Disappear)\s*\{`
Priority: MEDIUM
Description: SwiftUI view lifecycle
Action: Track SwiftUI initialization boundaries

## Rule 10: @StateObject and @ObservedObject
Pattern: `@(State)?ObservedObject\s+var|@StateObject`
Priority: MEDIUM
Description: State object lifecycle in SwiftUI
Action: Track ObservableObject conformance
```

### 4.2 邊界偵測規則

```
## Boundary Detection Rules

## Rule B1: URLSession Configuration
Pattern: `URLSessionConfiguration\.(default|ephemeral|background)\(`
Priority: HIGH
Description: Network boundary initialization
Action: Track network isolation settings

## Rule B2: Database Read/Write
Pattern: `db\.(read|write)\s*\{|DBReadTransaction|DBWriteTransaction`
Priority: CRITICAL
Description: Database access boundaries
Action: Track transaction scope and thread safety

## Rule B3: GRDB Database Access
Pattern: `grdbStorage\.read\(|\.database\(ofPool:`
Priority: HIGH
Description: GRDB-specific boundaries
Action: Track GRDB-specific transaction patterns

## Rule B4: Keychain Access
Pattern: `KeychainStorageImpl|KeychainError|SecItemCopy|SecItemAdd`
Priority: MEDIUM
Description: Sensitive data storage boundary
Action: Track secure storage access

## Rule B5: NotificationCenter Post/Subscribe
Pattern: `NotificationCenter\.default\.post|addObserver.*selector`
Priority: MEDIUM
Description: System event boundaries
Action: Track notification flow

## Rule B6: Thread Dispatch
Pattern: `DispatchQueue\.(main|global|init\(label:)\)\.async|@MainActor`
Priority: HIGH
Description: Thread crossing boundaries
Action: Track thread safety violations

## Rule B7: async/await Boundaries
Pattern: `await\s+\w+\(|@MainActor\s+(func|var|class)`
Priority: HIGH
Description: Structured concurrency boundaries
Action: Track thread transitions
```

### 4.3 Swift 特殊模式規則

```
## Swift-Specific Pattern Rules

## Rule S1: @escaping Closures
Pattern: `@escaping\s*\(|completion:\s*@escaping`
Priority: HIGH
Description: Long-lived closures requiring capture list
Action: Check for [weak self] patterns and memory safety

## Rule S2: Weak Self Capture
Pattern: `\[weak\s+(self|delegate|owner)\]`
Priority: MEDIUM
Description: Memory safety in escaping closures
Action: Verify no strong reference cycles

## Rule S3: Protocol Extension Methods
Pattern: `extension\s+\w+\s*where\s+Self\s*:|extension\s+Protocol\w+`
Priority: MEDIUM
Description: Default implementations in protocols
Action: Track actual resolved implementations

## Rule S4: AsyncSequence and AsyncIterator
Pattern: `for\s+await\s+\w+\s+in|AsyncSequence|AsyncIterator`
Priority: MEDIUM
Description: Async iteration boundaries
Action: Track producer and consumer

## Rule S5: Objective-C Bridge
Pattern: `@objc\s+|@objcMembers|NSObject|protocol.*@objc`
Priority: MEDIUM
Description: Objective-C interoperability
Action: Track Swift-ObjC boundaries

## Rule S6: @MainActor Attribute
Pattern: `@MainActor\s+(func|var|class|struct)|MainActor\.run`
Priority: HIGH
Description: Main thread safety
Action: Verify all UI updates are on main thread
```

---

## 5. 實作檢查清單

### 5.1 Entry Point 檢測清單

- [x] 偵測 `@main` 和 `@UIApplicationMain`
- [x] 追蹤 AppDelegate 的 6 個關鍵生命週期方法
- [x] 追蹤 ViewController 的 6 個生命週期方法
- [x] 追蹤 SwiftUI 的 `.onAppear` 和 `.onDisappear`
- [x] 追蹤 GestureRecognizer 的 `#selector` 目標
- [x] 追蹤 NotificationCenter 訂閱
- [x] 追蹤 URLSession 委托實作
- [x] 追蹤 BackgroundTasks 註冊
- [x] 追蹤 Deep Link 處理方法
- [x] 追蹤 @StateObject/@ObservedObject 初始化

### 5.2 Boundary 檢測清單

- [x] URLSession 配置和委托
- [x] GRDB 讀寫事務
- [x] CoreData @FetchRequest
- [x] Keychain 存取
- [x] UserDefaults 讀寫
- [x] DispatchQueue 線程轉移
- [x] NotificationCenter 發佈/訂閱
- [x] @MainActor 邊界
- [x] async/await 邊界
- [x] Combine .sink() 訂閱

### 5.3 Swift 特殊模式清單

- [x] @escaping 閉包檢測
- [x] [weak self] 模式
- [x] Protocol extension 實作
- [x] AsyncSequence 生產者/消費者
- [x] Objective-C 橋接
- [x] Closure 嵌套層級
- [x] 記憶體安全（循環引用風險）

---

## 6. 專案特定發現

### Signal-iOS（通訊 App）
- 大量使用自訂 `OWSURLSession` 包裝 URLSession，支援代理和 SSL pinning
- GRDB 為主要資料庫，支援多進程同步
- 仍廣泛使用 Objective-C 互操作性（@objc, selectors）
- 複雜的後台任務管理（MessageFetchBGRefreshTask）

### WordPress-iOS（內容管理）
- 模組化架構，分離主應用和 Modules
- 漸進式 SwiftUI 採用（UIHostingController bridge）
- CoreData 用於本地快取
- Widget 支援（JetpackStatsWidgets with @main）

### Swiftfin（媒體播放器）
- 純 SwiftUI 應用（完全現代化）
- 大量使用 async/await（>20 处）
- CoreStore 用於資料庫（CRUD 抽象）
- @StateObject 和 @Published 作為主要狀態管理

### ***REMOVED***（電商）
- UIKit 為主（較傳統）
- 混合 UIViewController 和 SwiftUI（部分視圖）

---

## 7. 推薦的 Grep Patterns（可直接用於 atlas 命令）

```bash
# 入口點
grep -r "@main\|@UIApplicationMain" . --include="*.swift"
grep -r "func application(" . --include="*.swift"
grep -r "func viewDidLoad\|viewWillAppear" . --include="*.swift"
grep -r "\.onAppear\|\.onDisappear" . --include="*.swift"

# 邊界
grep -r "URLSession\|dataTask" . --include="*.swift"
grep -r "db\.read\|db\.write" . --include="*.swift"
grep -r "NotificationCenter\|UserDefaults" . --include="*.swift"
grep -r "@MainActor\|await " . --include="*.swift"

# 特殊模式
grep -r "@escaping\|weak self" . --include="*.swift"
grep -r "for await\|AsyncSequence" . --include="*.swift"
grep -r "extension.*protocol\|where Self" . --include="*.swift"
```

---

## 結論

iOS/Swift 的入口點和邊界模式相比其他平台有獨特性：

1. **多層次生命週期**：AppDelegate → ViewController → View 形成 3 層初始化
2. **委托模式主導**：幾乎所有邊界都用 Protocol + Delegate 實作
3. **線程安全至關重要**：@MainActor、DispatchQueue、async/await 是核心
4. **雙軌並行**：同時支援 UIKit（legacy）和 SwiftUI（modern）
5. **記憶體管理**：[weak self]、@escaping、AnyCancellable 循環引用風險大

為了有效追蹤 iOS 應用流程，必須同時理解：
- **同步路徑**：target-action、notification、delegate
- **異步路徑**：completion handler、Combine、async/await
- **背景執行**：BackgroundTasks、URLSession background downloads
- **線程轉移**：主線程、後台隊列、全局隊列之間的切換

