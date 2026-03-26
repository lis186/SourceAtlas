# Language Plugin: Objective-C
# Contract Audit 語言插件 -- Objective-C / iOS
# Version: 2.0

---

## 適用範圍

- 純 ObjC 模組（`.m` / `.h`）
- Mixed ObjC + Swift 模組中的 ObjC 部分
- iOS / macOS 框架中使用 ObjC 的元件

---

## 1. 通知/事件原語

### NSNotification / NSNotificationCenter
```objc
[[NSNotificationCenter defaultCenter] postNotificationName:@"SomeName"
                                                    object:self
                                                  userInfo:@{...}];
```

稽核要點：
- `object:` 參數（nil vs self vs singleton）決定觀察者的過濾行為
- `userInfo` 的 key/value 型別是隱含合約——呼叫者用 `objectForKey:` 取值並假設特定型別
- 發送執行緒是合約的一部分；觀察者可能假設在主執行緒

### KVO (Key-Value Observing)
```objc
[self addObserver:self forKeyPath:@"property" options:NSKeyValueObservingOptionNew context:nil];
```

稽核要點：
- 必須配對 `removeObserver:` 否則 crash
- `context` 參數用於區分多重觀察，nil 是常見但危險的做法
- KVO 觸發執行緒與 property 設定執行緒相同

### KVO 進階（手動通知與依賴 key）
```objc
// 關閉自動 KVO 通知
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([key isEqualToString:@"fullName"]) return NO;
    return [super automaticallyNotifiesObserversForKey:key];
}

// 宣告依賴 key——firstName 或 lastName 改變時，自動觸發 fullName 的 KVO 通知
+ (NSSet<NSString *> *)keyPathsForValuesAffectingFullName {
    return [NSSet setWithObjects:@"firstName", @"lastName", nil];
}

// 手動 KVO 通知
- (void)setFullName:(NSString *)fullName {
    [self willChangeValueForKey:@"fullName"];
    _fullName = fullName;
    [self didChangeValueForKey:@"fullName"];
}
```

稽核要點：
- `automaticallyNotifiesObserversForKey:` 回傳 NO 但未配對手動 `willChange/didChange` = KVO 靜默失效
- `keyPathsForValuesAffectingValueForKey:` 定義的依賴關係是隱含合約——移除依賴 property 不會產生編譯錯誤
- 手動 KVO 的 `willChangeValueForKey:` 和 `didChangeValueForKey:` 必須成對呼叫，否則觀察者行為不可預測
- 對 to-many relationship 需使用 `willChange:valuesAt:forKey:` / `didChange:valuesAt:forKey:`

### Delegate / Protocol Callback
```objc
[self.delegate didFinishWithResult:result];
```

稽核要點：
- delegate 是否為 `weak` property（retain cycle 風險）
- 是否在呼叫前檢查 `respondsToSelector:`
- callback 的執行緒假設

### Block Capture 語義
```objc
// Retain cycle 陷阱
[self.manager fetchDataWithCompletion:^(NSData *data) {
    self.data = data;  // block 強引用 self，self 強引用 manager，manager 強引用 block
}];

// 正確的 weak-strong dance
__weak typeof(self) weakSelf = self;
[self.manager fetchDataWithCompletion:^(NSData *data) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) return;
    strongSelf.data = data;
}];
```

稽核要點：
- `__weak` 修飾符使 block 不 retain 該變數——但 block 執行時物件可能已被釋放（nil）
- `__strong` 在 block 內部重新 retain——確保 block 執行期間物件不被釋放
- `__block` 修飾符允許 block 修改外部變數——ARC 下 `__block` 對 object 會 retain（與 MRC 不同）
- 未使用 `__weak` 的 self 參考在非同步 block 中幾乎必然是 retain cycle
- `dispatch_async` 會 retain block，block 會 retain 被捕獲的變數——整條鏈都是合約
- 巢狀 block 的捕獲語義更複雜——內部 block 捕獲外部 block 的 `strongSelf` 仍可能導致 retain cycle

---

## 2. 同步原語

### dispatch_semaphore
```objc
dispatch_semaphore_t sem = dispatch_semaphore_create(0);
// ... async work ...
dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
```

稽核要點：
- `DISPATCH_TIME_FOREVER` 是最危險的模式——如果 signal 永遠不來，主執行緒永久阻塞
- signal 與 wait 的配對順序是關鍵合約
- 在主執行緒使用 `dispatch_semaphore_wait` 會導致 UI 凍結

### @synchronized
```objc
@synchronized(self) {
    // critical section
}
```

稽核要點：
- 鎖定對象的生命週期必須涵蓋所有使用點
- 巢狀 `@synchronized` 可能導致死鎖

### dispatch_queue (serial)
```objc
dispatch_queue_t queue = dispatch_queue_create("com.app.serial", DISPATCH_QUEUE_SERIAL);
dispatch_sync(queue, ^{ ... });
```

稽核要點：
- `dispatch_sync` 在同一個 serial queue 上會死鎖
- serial queue 作為 mutex 的替代品——其序列化保證是合約

### NSLock / NSRecursiveLock
```objc
[lock lock];
// critical section
[lock unlock];
```

稽核要點：
- `NSLock` 不支援重入；同一執行緒二次 lock 會死鎖
- `NSRecursiveLock` 支援重入但效能較差

### dispatch_group
```objc
dispatch_group_t group = dispatch_group_create();

dispatch_group_enter(group);
[self fetchUserWithCompletion:^(User *user) {
    self.user = user;
    dispatch_group_leave(group);
}];

dispatch_group_enter(group);
[self fetchOrdersWithCompletion:^(NSArray *orders) {
    self.orders = orders;
    dispatch_group_leave(group);
}];

dispatch_group_notify(group, dispatch_get_main_queue(), ^{
    [self updateUI];
});
```

稽核要點：
- `enter` 和 `leave` 必須**嚴格配對**——少一個 `leave` 會導致 `notify` / `wait` 永遠不觸發
- 多一個 `leave` 會 crash（EXC_BAD_INSTRUCTION）
- 錯誤路徑（early return、exception）中遺漏 `leave` 是最常見的 bug
- `dispatch_group_wait` 阻塞當前執行緒；`dispatch_group_notify` 非阻塞——混用需注意語義差異
- `dispatch_group_enter` 在非同步操作開始**前**呼叫，`leave` 在 completion handler **內**呼叫

### dispatch_barrier（Reader-Writer Pattern）
```objc
// 用 concurrent queue + barrier 實現 reader-writer lock
dispatch_queue_t queue = dispatch_queue_create("com.app.rwlock", DISPATCH_QUEUE_CONCURRENT);

// 讀取（並行）
- (NSString *)name {
    __block NSString *result;
    dispatch_sync(queue, ^{
        result = _name;
    });
    return result;
}

// 寫入（獨占）
- (void)setName:(NSString *)name {
    dispatch_barrier_async(queue, ^{
        _name = name;
    });
}
```

稽核要點：
- `dispatch_barrier_async` 只在**自訂 concurrent queue** 上有效——對 global queue 使用 barrier 等同於普通 async
- barrier block 等待所有先前提交的 block 完成後才執行，且阻止後續 block 開始
- 讀用 `dispatch_sync`、寫用 `dispatch_barrier_async` 的配對是合約——顛倒會破壞一致性
- 對同一 queue 同時使用 `dispatch_sync` 讀取和 `dispatch_barrier_sync` 寫入可能死鎖

### dispatch_once
```objc
+ (instancetype)sharedInstance {
    static MyClass *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MyClass alloc] init];
    });
    return instance;
}
```

稽核要點：
- `dispatch_once` 保證 block 只執行一次且線程安全——但 block 內部的死鎖（如存取自身 singleton）會永久掛起
- `onceToken` 必須是 `static` 或 `global`——stack 上的 token 行為未定義
- Singleton 的初始化順序依賴是隱含合約（參見 8.3 範例）

### NSOperationQueue / NSOperation
```objc
NSOperationQueue *queue = [[NSOperationQueue alloc] init];
queue.maxConcurrentOperationCount = 3;

NSBlockOperation *op1 = [NSBlockOperation blockOperationWithBlock:^{ /* fetch */ }];
NSBlockOperation *op2 = [NSBlockOperation blockOperationWithBlock:^{ /* parse */ }];
[op2 addDependency:op1];  // op2 等待 op1 完成才開始

[queue addOperations:@[op1, op2] waitUntilFinished:NO];
```

稽核要點：
- `addDependency:` 建立的依賴鏈是合約——移除依賴會改變執行順序
- 循環依賴（op1 → op2 → op1）不會 crash，但兩個 operation 都永遠不會開始
- `cancel` 只設置 `isCancelled` 標誌——operation 必須自行檢查並提前結束，不會強制停止
- NSOperation 的 KVO 屬性（`isFinished`、`isExecuting`、`isCancelled`）必須符合 KVO 合規——自訂 subclass 必須手動觸發 KVO 通知
- `maxConcurrentOperationCount = 1` 使 queue 變為 serial——但不保證同一執行緒

---

## 3. 生命週期模式

### UIViewController Lifecycle
```
viewDidLoad -> viewWillAppear -> viewDidAppear -> viewWillDisappear -> viewDidDisappear -> dealloc
```

稽核要點：
- `viewDidLoad` 只呼叫一次，但 `viewWillAppear` 可能多次呼叫
- `dealloc` 中的清理（removeObserver、invalidate timer）是合約
- 在 `viewDidLoad` 中註冊觀察者但未在 `dealloc` 移除 = 記憶體洩漏或 crash

### AppDelegate Lifecycle
```
application:didFinishLaunchingWithOptions: -> applicationDidBecomeActive: -> applicationWillResignActive: -> applicationDidEnterBackground:
```

稽核要點：
- 初始化順序依賴（哪些 singleton 必須先初始化）
- 背景進入時的狀態保存合約

### NSTimer
```objc
// 建立 repeating timer——target 會被 retain
self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                              target:self
                                            selector:@selector(timerFired:)
                                            userInfo:nil
                                             repeats:YES];
```

稽核要點：
- `NSTimer` 會**強引用 target**——若 target 也強引用 timer = retain cycle（`dealloc` 永遠不會被呼叫）
- `invalidate` 是唯一的停止方式——必須在 timer 所在的 run loop 執行緒上呼叫
- Timer 綁定到 run loop——`scheduledTimerWithTimeInterval:` 自動加入當前 run loop 的 `NSDefaultRunLoopMode`
- 在 scroll 期間 run loop 切換到 `UITrackingRunLoopMode`——預設 mode 下的 timer 不會觸發
- 解法：`[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes]`
- `tolerance` 屬性允許系統合併 timer 以節省電力——設定 tolerance 是效能合約
- iOS 10+ 提供 block-based API（`scheduledTimerWithTimeInterval:repeats:block:`），避免 target retain 問題

### @autoreleasepool
```objc
// 在緊密迴圈中手動管理 autorelease pool
for (int i = 0; i < 100000; i++) {
    @autoreleasepool {
        NSString *temp = [NSString stringWithFormat:@"item_%d", i];
        [self processItem:temp];
    }
}
```

稽核要點：
- 背景執行緒（`dispatch_async`、`NSThread`）不自動建立 autorelease pool——未包裝的 autorelease 物件會洩漏
- GCD dispatch block 自動包裝 autorelease pool（`autoreleaseFrequency` 控制頻率）
- 緊密迴圈中大量建立臨時物件不加 `@autoreleasepool` = 記憶體尖峰
- ARC 下 `@autoreleasepool` 仍然必要——ARC 只管理 retain/release，autorelease 的 drain 時機仍由 pool 控制

### NSObject dealloc
```objc
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timer invalidate];  // timer 必須在 dealloc 前 invalidate
}
```

稽核要點：
- ARC 下 `dealloc` 不呼叫 `[super dealloc]`，但 MRC 下必須
- `dealloc` 中不可呼叫非同步操作
- `dealloc` 中必須 invalidate timer、removeObserver、取消 KVO——遺漏任一項都是潛在 crash
- 但若 timer retain self（常見情況），`dealloc` 根本不會被呼叫——形成死結，需在 `viewWillDisappear` 或明確的 teardown 方法中 invalidate

---

## 4. 驗證策略

**ast-grep: 不支援。**

ast-grep 0.40+ 不支援 `language: objective-c` 或 `language: objc`。
所有 ObjC 合約必須使用 grep fallback 驗證。

### grep 驗證規則

- 使用 `grep -qn` 搭配最具區別性的字串
- 優先使用確切的字串常量（notification name、header name、method selector）
- 避免匹配過廣的 pattern（例如不要只用 `addObserver`）

範例：
```bash
# Good -- 精確匹配 notification name
assert_match "N1" 'postNotificationName:@"kUserDidLogout"' "Target.m"

# Bad -- 過於泛化
assert_match "N1" 'postNotificationName' "Target.m"
```

### Mixed ObjC + Swift 模組

- ObjC 部分：使用 grep 腳本（Artifact 2a）
- Swift 部分：使用 ast-grep 規則（Artifact 2b）
- 跨語言合約（ObjC 發送通知、Swift 觀察）：兩側都驗證，Coverage Table 中明確連結

---

## 5. Effect 防火牆

**強度：最弱。**

ObjC 幾乎沒有語言層級的不可變性保證：

- 所有 `@property` 預設可變（即使宣告為 `readonly`，仍可透過 KVC 修改）
- `const` 僅為編譯期提示，runtime 可繞過
- 沒有 value type（`NSValue` 是 reference type）
- Category 可以覆寫任何方法（swizzling 更不用說）
- `id` 型別完全繞過型別系統

**稽核影響：**
- 假設所有 property 都可能被外部修改
- 必須追蹤每個 mutable collection 的所有存取點
- 對 singleton property 的並行存取必須標記為 Category S 合約

---

## 6. Seam 類型

### Object Seam（Protocol）
```objc
@protocol NetworkClient <NSObject>
- (void)sendRequest:(NSURLRequest *)request completion:(void(^)(NSData *, NSError *))completion;
@end
```

- ObjC protocol 支援 `@optional` 方法——這是隱含合約（呼叫者是否檢查 `respondsToSelector:`）
- protocol 可以在不修改現有類別的情況下引入測試替身

### Preprocessing Seam（巨集、條件編譯）
```objc
#if DEBUG
    [self enableDebugLogging];
#endif

#ifdef FEATURE_NEW_AUTH
    [self useNewAuthFlow];
#else
    [self useLegacyAuthFlow];
#endif
```

- 巨集展開發生在編譯前，runtime 完全不可見
- `#if DEBUG` 段落內的合約在 Release build 中不存在
- 條件編譯標記本身就是一個 Category L 合約

### Link Seam（Category）
```objc
@interface NSURLRequest (CustomHeaders)
- (NSURLRequest *)requestWithInjectedHeaders;
@end
```

- Category 方法可以在連結時替換原始實作
- 多個 Category 定義同名方法 = undefined behavior
- Method swizzling 是最極端的 Link Seam

---

## 7. Sprout/Wrap 策略

所有四種 Feathers 策略均適用於 ObjC：

### Sprout Method
在現有方法中提取新邏輯到獨立方法：
```objc
// Before
- (void)handleRequest:(NSURLRequest *)request {
    // 200 lines of mixed logic
}

// After
- (void)handleRequest:(NSURLRequest *)request {
    [self injectAuthHeaders:request];  // sprouted
    // remaining logic
}
```

**適用場景：** 需要為單一行為添加測試覆蓋時

### Sprout Class
將新邏輯提取到全新的類別：
```objc
// New class
@interface AuthHeaderInjector : NSObject
- (NSURLRequest *)injectHeaders:(NSURLRequest *)request;
@end
```

**適用場景：** 新行為足夠複雜，值得獨立測試時

### Wrap Method
將原方法重新命名，用新方法包裝：
```objc
- (void)handleRequest_original:(NSURLRequest *)request { ... }
- (void)handleRequest:(NSURLRequest *)request {
    [self logRequest:request];
    [self handleRequest_original:request];
}
```

**適用場景：** 需要在不修改原邏輯的情況下添加前/後處理

### Wrap Class
用新類別包裝原始類別（Decorator pattern）：
```objc
@interface LoggingNetworkClient : NSObject <NetworkClient>
@property (nonatomic, strong) id<NetworkClient> wrapped;
@end
```

**適用場景：** 需要在不修改原始類別的情況下改變行為

---

## 8. 常見隱含合約範例

### 8.1 NSNotification 的 userInfo 結構
```objc
// 發送端（隱含合約：userInfo 包含 @"token" key，值為 NSString）
NSDictionary *info = @{@"token": self.authToken ?: @""};
[[NSNotificationCenter defaultCenter] postNotificationName:@"kAuthUpdated" object:nil userInfo:info];

// 觀察端（依賴上述結構）
NSString *token = notification.userInfo[@"token"];
```

**重構風險：** 如果發送端將 key 從 `@"token"` 改為 `@"accessToken"`，或將值型別從 `NSString` 改為 `NSDictionary`，觀察端不會產生任何編譯錯誤——`objectForKey:` 回傳 `id`，型別轉換錯誤只會在 runtime 暴露。多個觀察者可能分散在不同檔案中，遺漏任一處修改即導致靜默失敗。

### 8.2 dispatch_semaphore 將非同步轉為同步
```objc
// 隱含合約：此方法在呼叫者的執行緒上阻塞直到 completion 執行
- (NSDictionary *)fetchDataSync {
    __block NSDictionary *result;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [self fetchDataAsync:^(NSDictionary *data) {
        result = data;
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return result;
}
```

**重構風險：** 如果將 `fetchDataAsync:` 重構為在同一個 serial queue 上回呼（例如改用 `dispatch_async(self.serialQueue, ...)`），而 `fetchDataSync` 也在該 serial queue 上被呼叫，則 `dispatch_semaphore_wait` 永遠不會被 signal——造成死鎖。這種死鎖只在特定執行路徑下發生，單元測試很難覆蓋。

### 8.3 Singleton 初始化順序
```objc
// 隱含合約：呼叫此方法前 [AppConfig sharedInstance] 必須已初始化
- (void)configure {
    self.baseURL = [AppConfig sharedInstance].apiBaseURL;  // crash if nil
}
```

**重構風險：** 如果重構 App 啟動流程（例如將 `AppConfig` 初始化延後到某個非同步操作之後），所有依賴 `[AppConfig sharedInstance]` 的模組可能在初始化完成前就存取它。由於 ObjC 對 nil 發送訊息回傳 0/nil 而非 crash，`self.baseURL` 會被靜默設為 nil，直到網路請求失敗才會發現問題。

### 8.4 Method Swizzling 隱含合約
```objc
// 隱含合約：原始實作 (originalSelector) 仍會被呼叫（透過 swizzled 方法內的呼叫）
+ (void)load {
    Method original = class_getInstanceMethod(self, @selector(viewDidAppear:));
    Method swizzled = class_getInstanceMethod(self, @selector(tracked_viewDidAppear:));
    method_exchangeImplementations(original, swizzled);
}
```

**重構風險：** 如果移除或重新命名 `tracked_viewDidAppear:` 方法，`method_exchangeImplementations` 會靜默失敗（`class_getInstanceMethod` 回傳 NULL），原始方法行為不變但追蹤功能消失。更危險的情況是兩個不同的模組對同一方法進行 swizzling——第二次 swizzle 會將第一次的 swizzled 實作當作「原始」實作，形成脆弱的鏈式依賴，移除任一模組都可能導致呼叫鏈斷裂。

### 8.5 Delegate 的 nil 靜默失敗
```objc
// 隱含合約：如果 delegate 為 nil，此通知被靜默吞掉——呼叫者可能依賴此行為
[self.delegate networkClient:self didReceiveResponse:response];
// ObjC 對 nil 發送訊息不會 crash，但也不會執行任何事
```

**重構風險：** 如果將 delegate pattern 重構為 block/completion handler 模式，nil 的行為語義完全改變——block 為 nil 時呼叫會 crash（EXC_BAD_ACCESS）。此外，如果將 delegate property 從 `weak` 改為 `strong`（例如忘記標記），會產生 retain cycle；反之若原本是 `strong`（某些特殊設計）被改為 `weak`，delegate 可能在使用前被提前釋放。

### 8.6 NSManagedObjectContext 的執行緒合約
```objc
// 隱含合約：NSManagedObjectContext 必須在建立它的執行緒/queue 上使用
NSManagedObjectContext *context = [[NSManagedObjectContext alloc]
    initWithConcurrencyType:NSPrivateQueueConcurrencyType];

// 正確用法——在 context 自己的 queue 上操作
[context performBlock:^{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"User"];
    NSArray *results = [context executeFetchRequest:request error:nil];
    // 處理 results
}];

// 危險用法——在任意執行緒直接存取
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    // 違反執行緒合約！可能導致資料損壞或 crash
    NSArray *results = [context executeFetchRequest:request error:nil];
});
```

**重構風險：** 如果將同步操作重構為非同步（例如移到背景執行緒），但未使用 `performBlock:` 包裹 Core Data 操作，會違反 `NSManagedObjectContext` 的執行緒限制。這種錯誤不會產生編譯警告，且在低負載時可能不會觸發 crash，只在高並行場景下才以資料損壞或間歇性 crash 的形式出現——極難追蹤和重現。

### 8.7 performSelector:withObject:afterDelay: 的 retain 語義
```objc
// 隱含合約：performSelector:withObject:afterDelay: 會 retain target 直到 selector 執行完畢
[self performSelector:@selector(refreshUI) withObject:nil afterDelay:2.0];

// 取消需要明確呼叫，否則即使物件「應該」被釋放，仍會被 run loop 持有
- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

// 危險用法——在 dealloc 中未取消
- (void)startAutoRefresh {
    [self performSelector:@selector(refreshUI) withObject:nil afterDelay:5.0];
    // 如果物件在 5 秒內被釋放，selector 仍會執行——此時 self 已是 dangling pointer
}
```

**重構風險：** 如果將 `performSelector:withObject:afterDelay:` 重構為 `dispatch_after`，retain 語義完全不同——`dispatch_after` 的 block 會 retain 被捕獲的變數，但 block 執行後立即釋放，不需要手動取消。反之，如果忘記在 `dealloc` 中呼叫 `cancelPreviousPerformRequestsWithTarget:`，延遲的 selector 會在物件已釋放後執行，導致 EXC_BAD_ACCESS。ARC 環境下這個問題更隱蔽，因為開發者容易誤以為 ARC 會自動處理所有記憶體管理。

### 8.8 NSArray/NSDictionary 的 nil 處理差異
```objc
// 隱含合約：NSArray 不接受 nil 元素——插入 nil 會 crash
NSString *name = [self getUserName];  // 可能回傳 nil
NSArray *items = @[name];  // 如果 name 為 nil -> NSInvalidArgumentException crash

// 隱含合約：NSDictionary 的 setObject:forKey: 不接受 nil value——會 crash
NSMutableDictionary *params = [NSMutableDictionary dictionary];
[params setObject:[self getToken] forKey:@"token"];  // getToken 回傳 nil -> crash

// 安全替代——但語義不同
[params setValue:[self getToken] forKey:@"token"];  // setValue:forKey: 接受 nil，會移除該 key

// Literal 語法的陷阱
NSDictionary *dict = @{@"key": [self getValue]};  // getValue 回傳 nil -> crash
```

**重構風險：** 如果將 `setValue:forKey:`（KVC 方法，接受 nil）重構為 `setObject:forKey:`（NSDictionary 方法，不接受 nil），或反過來，nil 處理語義完全改變。前者在 value 為 nil 時會移除該 key，後者會直接 crash。同樣地，如果將手動建構的 `NSArray` 重構為使用 literal 語法 `@[...]`，任何潛在的 nil 元素都會從靜默忽略（使用 `addObject:` 搭配 nil 檢查時）變成立即 crash。這類問題在重構大量集合操作時特別容易遺漏。
