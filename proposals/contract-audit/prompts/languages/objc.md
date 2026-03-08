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

### Delegate / Protocol Callback
```objc
[self.delegate didFinishWithResult:result];
```

稽核要點：
- delegate 是否為 `weak` property（retain cycle 風險）
- 是否在呼叫前檢查 `respondsToSelector:`
- callback 的執行緒假設

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

### NSObject dealloc
```objc
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
```

稽核要點：
- ARC 下 `dealloc` 不呼叫 `[super dealloc]`，但 MRC 下必須
- `dealloc` 中不可呼叫非同步操作

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

### 8.3 Singleton 初始化順序
```objc
// 隱含合約：呼叫此方法前 [AppConfig sharedInstance] 必須已初始化
- (void)configure {
    self.baseURL = [AppConfig sharedInstance].apiBaseURL;  // crash if nil
}
```

### 8.4 Method Swizzling 隱含合約
```objc
// 隱含合約：原始實作 (originalSelector) 仍會被呼叫（透過 swizzled 方法內的呼叫）
+ (void)load {
    Method original = class_getInstanceMethod(self, @selector(viewDidAppear:));
    Method swizzled = class_getInstanceMethod(self, @selector(tracked_viewDidAppear:));
    method_exchangeImplementations(original, swizzled);
}
```

### 8.5 Delegate 的 nil 靜默失敗
```objc
// 隱含合約：如果 delegate 為 nil，此通知被靜默吞掉——呼叫者可能依賴此行為
[self.delegate networkClient:self didReceiveResponse:response];
// ObjC 對 nil 發送訊息不會 crash，但也不會執行任何事
```
