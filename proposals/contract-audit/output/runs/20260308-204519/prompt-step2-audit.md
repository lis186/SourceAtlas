# Contract Audit Skeleton
# 通用合約稽核骨架 -- 語言無關
# Version: 2.0

---

## ROLE

你是一位資深工程師，正在執行重構前的合約稽核。你的目標是將目標模組中每一個隱含的行為合約變成**明確的、可驗證的、可機器檢查的**，然後才進行任何重構。

---

## INPUT

你會收到：
- **目標模組**：一個或多個原始碼檔案
- **語言上下文**：由語言插件定義（參見 `languages/objc.md`）
- **重構意圖**：簡短描述即將進行的變更

讀取所提供的每一個檔案的每一行。不可摘要或跳過任何段落。

---

## CONTRACT TAXONOMY

辨識以下八個類別的合約。為每個合約指定一個穩定的 ID，格式為 `{Category}-{三位數序號}`（例如 `M-001`、`N-002`、`D-001`），符合 `^[MLNSECDP]-[0-9]{3}$` 正規表示式。

### Category M -- Mutation Contracts
在資料離開模組之前施加的副作用。
- 哪些資料被新增、修改、或移除？
- 輸入條件為何（例如 GET vs POST、環境旗標）？
- 資料來源為何（singleton、設定儲存、bundle、UUID）？
- 來源為 nil 或空值時會發生什麼事？

### Category L -- Lifecycle / State Machine Contracts
模組觸發的隱含狀態轉換。
- 什麼事件觸發狀態變更？
- 確切的動作序列為何？
- 是否有守衛條件（feature flags、debug bypasses）？
- 轉換之後會發生什麼——正常執行是否繼續？

### Category N -- Notification / Observation Contracts
模組引入的任何 pub/sub 耦合。
- 通知名稱（確切字串或常數）
- 發送對象（object: nil、self、singleton？）
- 附帶資料的 key 與值型別
- 通知發送的執行緒
- 所有已知的觀察者及其消費的內容

### Category S -- Synchronization Contracts
任何阻塞、鎖定、或順序保證。
- Semaphore / mutex / actor / lock 的使用
- 超時值（特別是無限等待）
- Signal 順序相對於 callback 的關係
- 哪些執行緒可以安全地呼叫各進入點
- 隱藏在非同步外觀 API 後面的同步呼叫

### Category E -- Error Handling Contracts
- 哪些錯誤被吞掉、哪些被傳播？
- 是否有呼叫者依賴的靜默 fallback？
- 是否有具特殊含義的錯誤碼？

### Category C -- Cancellation Contracts
- 什麼可以被取消、如何取消？
- 取消的範圍為何（單一請求、符合條件的所有請求）？
- 取消後留下什麼狀態？

### Category D -- Dependency Contracts
模組對外部元件的隱含依賴。
- 模組假設了哪些外部服務或類別的存在？
- 哪些全域狀態或 singleton 被讀取或寫入？
- 初始化順序是否有隱含要求？
- 外部依賴不可用時的降級行為為何？

### Category P -- Propagation Contracts
效應如何跨越模組邊界傳播。
- 回傳值經過哪些轉換鏈才到達最終消費者？
- 哪些參數會被呼叫者修改（out parameters、mutable references）？
- 哪些全域狀態在此方法執行期間被改變？
- 效應傳播到幾層深度才穩定？

---

## FEATHERS LEGACY CODE ANALYSIS

以下三個分析指令必須在產出 Artifact 1 之前執行，其結果整合進合約文件中。

### F1: Tell the Story

用不超過三個核心概念描述此系統模組的職責。例如：「此模組是一個請求攔截器，負責 (1) 注入認證標頭、(2) 管理冪等性、(3) 控制重試邏輯。」

完成概要後，列出這三個概念中的**省略（謊言）**——亦即為了簡潔而略去、但重構時不可忽略的細節。格式：

```
STORY: [三個概念的一句話描述]
LIES:
- [省略 1]: [為什麼這個省略在重構時很危險]
- [省略 2]: ...
- [省略 3]: ...
```

### F2: Scratch Refactoring

不執行任何重構，僅**描述**你會對此模組進行的前三項重構操作。對每一項操作，說明該操作會揭示哪些隱藏合約。格式：

```
SCRATCH_REFACTORING:
1. [操作描述]
   REVEALS: [此操作會暴露的隱含合約，對應 Contract ID 或 "NEW"]
2. ...
3. ...
```

如果 Scratch Refactoring 揭示了 Taxonomy 分類階段未發現的合約，立即補充進 Artifact 1。

### F3: Effect Propagation Tracing

對目標模組中每一個 public 方法，追蹤以下三種 effect：

1. **Return Value Chain**: 回傳值經過哪些轉換到達最終消費者
2. **Parameter Mutation**: 哪些傳入參數會被修改（含 out parameters）
3. **Global State**: 哪些全域狀態或 singleton 在執行期間被改變

格式：

```
EFFECT_TRACE: [method signature]
  RETURN:  [chain description or "void"]
  MUTATES: [parameter list or "none"]
  GLOBAL:  [global state changes or "none"]
  DEPTH:   [propagation depth until effect stabilizes]
```

將 Effect Trace 結果標記為 Category P 合約納入 Artifact 1。

---

## CONTRACT METADATA

每個合約除了基本欄位外，必須包含以下元資料：

```
Scope:       [method | class | module]
Seam_Type:   [object | preprocessing | link | none]
Pinch_Point: [true | false]
```

- **Scope**: 合約的影響範圍——限於單一方法、整個類別、或跨模組
- **Seam_Type**: 根據語言插件定義的接縫類型（見 `languages/objc.md`）
- **Pinch_Point**: 是否為「狹窄通道」——多個執行路徑在此匯聚，適合插入測試替身

---

## OUTPUT FORMAT

依序產出四個 Artifact。

---

### Artifact 1: Contract Spec Document

對每一個發現的合約：

```
{Category}-{NNN}: [Short title]

Trigger:      [什麼觸發此合約的執行]
Input:        [消費的資料及來源]
Output:       [可觀察的效應：header set / notification posted / logout called / etc.]
Condition:    [守衛條件、feature flags、nil checks]
Ordering:     [相對於其他合約的位置——"before callback"、"after resume" 等]
Risk:         [CRITICAL / HIGH / MEDIUM / LOW] -- [一行理由]
Evidence:     [filename:line -- 確切的程式碼片段]
Scope:        [method | class | module]
Seam_Type:    [object | preprocessing | link | none]
Pinch_Point:  [true | false]
```

在文件開頭包含 F1 (Tell the Story) 與 F2 (Scratch Refactoring) 的輸出。
在最後包含 F3 (Effect Propagation Tracing) 的結果。

文件末尾產出 **Risk Matrix** 表格：

| ID | Risk | Description | Refactoring Impact |
|----|------|-------------|-------------------|

---

### Artifact 2: Verification Scripts

根據語言插件（`languages/objc.md`）產出對應的驗證方式。

#### 2a. grep 驗證腳本（適用於不支援 ast-grep 的語言）

產出 `verify-contracts-[ModuleName].sh`，用 `grep -qn` 驗證每個合約仍存在於原始碼中。

```bash
#!/bin/bash
set -e
PASS=0; FAIL=0
assert_match() {
  local id="$1" pattern="$2" file="$3"
  if grep -qn "$pattern" "$file"; then
    echo "PASS [$id]"; ((PASS++))
  else
    echo "FAIL [$id] -- pattern not found: $pattern"; ((FAIL++))
  fi
}

TARGET="path/to/TargetFile"

# [generated assertions]

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
```

每個合約 ID 一個 `assert_match` 呼叫。使用 Evidence 欄位中**最具區別性的子字串**。

#### 2b. ast-grep 規則檔（適用於支援 ast-grep 的語言）

每個合約產出一個 `.yml` 檔案。

```
File: .ast-grep/rules/[ModuleName]/[id]-[short-slug].yml
```

```yaml
id: [id]-[short-slug]
message: "[ID]: [Short title] -- contract must be present"
severity: error
language: {language}
rule:
  pattern: |
    [ast-grep pattern]
note: |
  Contract source: [Evidence reference]
  Refactoring requirement: [新程式碼必須實作的內容]
```

**Pattern 撰寫規則：**
- 使用 `$VAR` 表示單節點萬用字元，`$$$` 表示多節點序列
- 優先匹配最窄的唯一結構
- 對於無法用單一 pattern 表達的順序合約（L、S 類別），在 `note:` 中說明限制及需要的人工審查
- 不要產出匹配範圍過廣的規則

#### 語言驗證策略選擇

查閱語言插件（`languages/objc.md`）中的「驗證策略」段落，決定使用 2a、2b、或兩者皆用。

---

### Artifact 3: Coverage Table

將每個合約 ID 對應到其驗證方法：

| ID | Title | Verified By | File / Assertion |
|----|-------|-------------|-----------------|
| M-001 | ... | grep script | `verify-contracts-X.sh` line N |
| N-001 | ... | ast-grep | `.ast-grep/rules/X/N-001-slug.yml` |
| L-005 | ... | manual review | ordering cannot be expressed as pattern -- see note |

將**無法**用 pattern 表達的順序/時序合約標記為 `manual review`，並包含審查者必須檢查的具體描述。

---

### Artifact 4: Line Attribution Table

對目標檔案中**每一個可執行行**產出逐行歸因。

| Line(s) | Classification | Contract ID(s) |
|---------|---------------|----------------|
| 96-109  | CONTRACT      | M-001          |
| 158     | INFRA         | --             |
| 301     | SKIP          | -- (commented out) |

**分類規則：**
- `CONTRACT` -- 此行實作或參與某個具名合約
- `INFRA` -- 樣板、設定、或無獨立行為合約的結構性程式碼
- `SKIP` -- 死碼、註解、或 pragma marks

**完整性要求：** 每一行都必須出現在此表中。任何未分類的行都是一個明確的稽核缺口，必須在定稿前解決。如果不確定某一行，將其分類為 `CONTRACT ?` 並附加備註。

表格底部產出摘要：

```
Total lines:       [N]
CONTRACT lines:    [N] ([%])
INFRA lines:       [N] ([%])
SKIP lines:        [N] ([%])
Unclassified:      [N] -- MUST BE ZERO to pass completeness gate
```

---

## MULTI-AGENT PIPELINE

此骨架支援多代理稽核流程。各角色的 prompt 獨立存在，但共享相同的 Contract Taxonomy 和 Output Format。

### Agent 1: Auditor（主稽核者）
使用本骨架加語言插件，產出 Artifact 1-4。

### Agent 2: Blind Scout（盲掃者）
獨立發現合約，不參考 Auditor 的結果。僅產出合約清單與外部依賴發現。

### Agent 3: Adversary（對抗者）
比對 Auditor 與 Blind Scout 的結果，產出 CONFIRM / DISPUTE / ADD 判定。
CONFIRM 比率不得超過 70%。

### Agent 4: Applier（合併者）
機械性地將 Adversary 的修正套用到最終合約文件。
不做判斷、不做推論，僅套用有明確證據的變更。

---

## QUALITY GATES

定稿前必須驗證：

1. **每個合約都有證據** -- 至少一個 `filename:line` 引用及程式碼片段
2. **無合約是無來源推斷的** -- 如果找不到程式碼，必須明確說明
3. **每個合約都有 Risk 等級** -- 不允許空的 Risk 欄位
4. **順序合約必須明確** -- "before X" 和 "after Y" 必須引用特定 ID 或行號
5. **驗證 pattern 可編譯** -- ast-grep pattern 使用正確的 `$VAR` / `$$$` 語法及 YAML 縮排
6. **grep pattern 具區別性** -- 每個 `assert_match` 使用的字串足夠特定，不會匹配到無關程式碼
7. **行歸因完整** -- Artifact 4 摘要顯示 `Unclassified: 0`；每個 CONTRACT 行都對應到 Artifact 1 中存在的合約 ID
8. **元資料完整** -- 每個合約都包含 Scope、Seam_Type、Pinch_Point 欄位
9. **Feathers 分析完成** -- F1、F2、F3 三個分析均已執行並整合
10. **完整性宣告** -- 以下列其一結尾：
   - `COMPLETE: All executable lines attributed. No known audit gaps.`
   - `INCOMPLETE: [N] lines unresolved -- [list line numbers and why they are ambiguous]`

如果任何 gate 失敗，必須在產出最終輸出前修正。

---

## KNOWN PITFALLS

以下是從先前稽核中學到的常見陷阱：

- **外觀非同步但內部阻塞的 API** -- 總是檢查實作，不只是呼叫簽名（例如 Promise/Combine wrapper 內部呼叫同步方法）
- **在狀態轉換後執行的 Callback** -- 驗證轉換是在 callback 之前還是之後觸發；這往往是最關鍵的順序合約
- **Singleton 上的共享可變狀態** -- 標記任何在請求處理期間寫入、同時被並行讀取的 property
- **Feature flags 作為合約修飾器** -- 記錄每一個停用或繞過合約的旗標（debug bypasses、A/B flags、remote config）
- **通知的執行緒假設** -- 發送執行緒是一個合約；觀察者可能有隱含的執行緒要求
- **輔助檔案 = 額外稽核範圍** -- 如果提供了主要模組以外的額外檔案，也必須稽核其合約
- **Effect 傳播深度被低估** -- 回傳值經過多層轉換後，原始合約可能在消費端已不可見
- **隱含的初始化順序依賴** -- 模組假設某個 singleton 已初始化但未明確檢查

---

## INVOCATION TEMPLATE

```
Audit the following module for refactoring contracts:

Target files:
- [filename] ([N] lines) [attached]

Language context: [language] (語言插件: languages/objc.md)

Refactoring intent: [brief description]

Apply the Contract Audit Skeleton with language plugin: languages/objc.md
```

---

## LANGUAGE PLUGIN REFERENCE

語言插件提供以下語言特定的資訊，以 `languages/objc.md` 佔位符引用：

1. **通知/事件原語** -- 語言特定的 pub/sub 機制
2. **同步原語** -- 語言特定的並行控制機制
3. **生命週期模式** -- 框架特定的生命週期 hook
4. **驗證策略** -- 使用 grep、ast-grep、或兩者
5. **Effect 防火牆** -- 語言提供的不可變性保證強度
6. **Seam 類型** -- 語言支援的接縫類型及其運作方式
7. **Sprout/Wrap 策略** -- 可用的遺留程式碼改造模式
8. **常見隱含合約** -- 語言特有的典型隱含合約範例

--- LANGUAGE PLUGIN: objc ---
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
--- END LANGUAGE PLUGIN ---
## Refactoring Intent
Migrate RoomBubbleCellData from ObjC to Swift, preserving thread-safety contracts (@synchronized, dispatch_sync/async) and notification patterns (URLPreviewDidUpdateNotification)


## 目標原始碼

/*
Copyright 2019-2024 New Vector Ltd.
Copyright 2015 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

#import "RoomBubbleCellData.h"

#import "EventFormatter.h"

#import "AvatarGenerator.h"
#import "Tools.h"
#import "RoomReactionsViewSizer.h"

#import "GeneratedInterface-Swift.h"

static NSAttributedString *timestampVerticalWhitespace = nil;

NSString *const URLPreviewDidUpdateNotification = @"URLPreviewDidUpdateNotification";

@interface RoomBubbleCellData()

@property(nonatomic, readonly) BOOL addVerticalWhitespaceForSelectedComponentTimestamp;
@property(nonatomic, readwrite) CGFloat additionalContentHeight;
@property(nonatomic) BOOL shouldUpdateAdditionalContentHeight;

// Flags to "Show All" reactions for an event
@property(nonatomic) NSMutableSet<NSString* /* eventId */> *eventsToShowAllReactions;

@end

@implementation RoomBubbleCellData

- (BOOL)addVerticalWhitespaceForSelectedComponentTimestamp
{
    return self.showTimestampForSelectedComponent && !self.displayTimestampForSelectedComponentOnLeftWhenPossible;
}

#pragma mark - Override MXKRoomBubbleCellData

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _eventsToShowAllReactions = [NSMutableSet set];
        _componentIndexOfSentMessageTick = -1;
    }
    return self;
}

- (instancetype)initWithEvent:(MXEvent *)event andRoomState:(MXRoomState *)roomState andRoomDataSource:(MXKRoomDataSource *)roomDataSource
{
    self = [super initWithEvent:event andRoomState:roomState andRoomDataSource:roomDataSource];
    
    if (self)
    {
        self.displayTimestampForSelectedComponentOnLeftWhenPossible = YES;
        
        switch (event.eventType)
        {
            case MXEventTypeRoomMember:
            {
                // Membership events have their own cell type
                self.tag = RoomBubbleCellDataTagMembership;
                
                // Membership events can be collapsed together
                self.collapsable = YES;
                
                // Collapse them by default
                self.collapsed = YES;
                
                //  find the room create event in stateEvents
                MXEvent *roomCreateEvent = [roomState.stateEvents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"wireType == %@", kMXEventTypeStringRoomCreate]].firstObject;
                NSString *creatorUserId = [MXRoomCreateContent modelFromJSON:roomCreateEvent.content].creatorUserId;
                if (creatorUserId)
                {
                    MXRoomMemberEventContent *content = [MXRoomMemberEventContent modelFromJSON:event.content];
                    if ([kMXMembershipStringJoin isEqualToString:content.membership] &&
                        [creatorUserId isEqualToString:event.sender])
                    {
                        //  join event of the room creator
                        //  group it with room creation events
                        self.tag = RoomBubbleCellDataTagRoomCreateConfiguration;
                    }
                }
            }
                break;
            case MXEventTypeRoomCreate:
            {
                MXRoomCreateContent *createContent = [MXRoomCreateContent modelFromJSON:event.content];
                
                if (createContent.roomPredecessorInfo)
                {
                    self.tag = RoomBubbleCellDataTagRoomCreateWithPredecessor;
                }
                else
                {
                    self.tag = RoomBubbleCellDataTagRoomCreationIntro;
                }
                
                // Membership events can be collapsed together
                self.collapsable = YES;
                
                // Collapse them by default
                self.collapsed = YES;
            }
                break;
            case MXEventTypeRoomTopic:
            case MXEventTypeRoomName:
            case MXEventTypeRoomEncryption:
            case MXEventTypeRoomHistoryVisibility:
            case MXEventTypeRoomGuestAccess:
            case MXEventTypeRoomAvatar:
            case MXEventTypeRoomJoinRules:
            {
                self.tag = RoomBubbleCellDataTagRoomCreateConfiguration;
                
                // Membership events can be collapsed together
                self.collapsable = YES;
                
                // Collapse them by default
                self.collapsed = YES;
            }
                break;
            case MXEventTypeCallInvite:
            case MXEventTypeCallAnswer:
            case MXEventTypeCallHangup:
            case MXEventTypeCallReject:
            {
                self.tag = RoomBubbleCellDataTagCall;
                
                // Call events can be collapsed together
                self.collapsable = YES;
                
                // Collapse them by default
                self.collapsed = YES;
                
                // Show timestamps always on right
                self.displayTimestampForSelectedComponentOnLeftWhenPossible = NO;
                break;
            }
            case MXEventTypeCallNotify:
            {
                self.tag = RoomBubbleCellDataTagRTCCallNotify;
                self.collapsable = NO;
                self.collapsed = NO;
                self.displayTimestampForSelectedComponentOnLeftWhenPossible = NO;
                break;
            }
            case MXEventTypePollStart:
            case MXEventTypePollEnd:
            {
                self.tag = RoomBubbleCellDataTagPoll;
                self.collapsable = NO;
                self.collapsed = NO;
                
                break;
            }
            case MXEventTypeBeaconInfo:
            {
                self.tag = RoomBubbleCellDataTagLiveLocation;
                self.collapsable = NO;
                self.collapsed = NO;
                
                [self updateBeaconInfoSummaryWithId:event.eventId andEvent:event];
                break;
            }
            case MXEventTypeCustom:
            {
                if ([event.type isEqualToString:kWidgetMatrixEventTypeString]
                    || [event.type isEqualToString:kWidgetModularEventTypeString])
                {
                    Widget *widget = [[Widget alloc] initWithWidgetEvent:event inMatrixSession:roomDataSource.mxSession];
                    if ([widget.type isEqualToString:kWidgetTypeJitsiV1] ||
                        [widget.type isEqualToString:kWidgetTypeJitsiV2])
                    {
                        self.tag = RoomBubbleCellDataTagGroupCall;
                        
                        // Show timestamps always on right
                        self.displayTimestampForSelectedComponentOnLeftWhenPossible = NO;
                    }
                }
                else if ([event.type isEqualToString:VoiceBroadcastSettings.voiceBroadcastInfoContentKeyType])
                {
                    VoiceBroadcastInfo *voiceBroadcastInfo = [VoiceBroadcastInfo modelFromJSON: event.content];
                    
                    // Check if the state event corresponds to the beginning of a voice broadcast
                    if ([VoiceBroadcastInfo isStartedFor:voiceBroadcastInfo.state])
                    {
                        // Retrieve the most recent voice broadcast info.
                        MXEvent *lastVoiceBroadcastInfoEvent = [roomDataSource.roomState stateEventsWithType:VoiceBroadcastSettings.voiceBroadcastInfoContentKeyType].lastObject;
                        if (event.originServerTs > lastVoiceBroadcastInfoEvent.originServerTs)
                        {
                            lastVoiceBroadcastInfoEvent = event;
                        }
                        
                        VoiceBroadcastInfo *lastVoiceBroadcastInfo = [VoiceBroadcastInfo modelFromJSON: lastVoiceBroadcastInfoEvent.content];
                        
                        // Handle the specific case where the state event is a started voice broadcast (the voiceBroadcastId is the event id itself).
                        if (!lastVoiceBroadcastInfo.voiceBroadcastId)
                        {
                            lastVoiceBroadcastInfo.voiceBroadcastId = lastVoiceBroadcastInfoEvent.eventId;
                        }
                        
                        // Check if the voice broadcast is still alive.
                        if ([lastVoiceBroadcastInfo.voiceBroadcastId isEqualToString:event.eventId] && ![VoiceBroadcastInfo isStoppedFor:lastVoiceBroadcastInfo.state])
                        {
                            // Check whether this broadcast is sent from the currrent session to display it with the recorder view or not.
                            if ([event.stateKey isEqualToString:self.mxSession.myUserId] &&
                                [voiceBroadcastInfo.deviceId isEqualToString:self.mxSession.myDeviceId])
                            {
                                self.tag = RoomBubbleCellDataTagVoiceBroadcastRecord;
                            }
                            else
                            {
                                self.tag = RoomBubbleCellDataTagVoiceBroadcastPlayback;
                            }
                            
                            self.voiceBroadcastState = lastVoiceBroadcastInfo.state;
                        }
                        else
                        {
                            self.tag = RoomBubbleCellDataTagVoiceBroadcastPlayback;
                            self.voiceBroadcastState = VoiceBroadcastInfo.stoppedValue;
                        }
                    }
                    else
                    {
                        self.tag = RoomBubbleCellDataTagVoiceBroadcastNoDisplay;
                        
                        if ([VoiceBroadcastInfo isStoppedFor:voiceBroadcastInfo.state])
                        {
                            // This state event corresponds to the end of a voice broadcast
                            // Force the tag of the potential cellData which corresponds to the started event to switch the display from recorder to listener
                            RoomBubbleCellData *bubbleData = [roomDataSource cellDataOfEventWithEventId:voiceBroadcastInfo.voiceBroadcastId];
                            bubbleData.tag = RoomBubbleCellDataTagVoiceBroadcastPlayback;
                            bubbleData.voiceBroadcastState = VoiceBroadcastInfo.stoppedValue;
                        }
                    }
                    self.collapsable = NO;
                    self.collapsed = NO;
                    
                    break;
                }
                
                break;
            }
            case MXEventTypeRoomMessage:
            {
                if (event.location)
                {
                    self.tag = RoomBubbleCellDataTagLocation;
                    self.collapsable = NO;
                    self.collapsed = NO;
                }
                else if (event.content[VoiceBroadcastSettings.voiceBroadcastContentKeyChunkType])
                {
                    self.tag = RoomBubbleCellDataTagVoiceBroadcastNoDisplay;
                    self.collapsable = NO;
                    self.collapsed = NO;
                }
                
                break;
            }
            default:
                break;
        }
        
        [self keyVerificationDidUpdate];

        // Increase maximum number of components
        self.maxComponentCount = 20;

        // Indicate that the text message layout should be recomputed.
        [self invalidateTextLayout];
        
        // Load a url preview if necessary.
        [self refreshURLPreviewForEventId:event.eventId];
    }
    
    return self;
}

- (NSUInteger)updateEvent:(NSString *)eventId withEvent:(MXEvent *)event
{
    NSUInteger retVal = [super updateEvent:eventId withEvent:event];

    // Update any URL preview data as necessary.
    [self refreshURLPreviewForEventId:event.eventId];
    
    if (self.tag == RoomBubbleCellDataTagLiveLocation)
    {
        [self updateBeaconInfoSummaryWithId:eventId andEvent:event];
    }
    
    // Handle here the case where an audio chunk of a voice broadcast have been decrypted with delay
    // We take the opportunity of this update to disable the display of this chunk in the room timeline
    if (event.eventType == MXEventTypeRoomMessage && event.content[VoiceBroadcastSettings.voiceBroadcastContentKeyChunkType]) {
        self.tag = RoomBubbleCellDataTagVoiceBroadcastNoDisplay;
        self.collapsable = NO;
        self.collapsed = NO;
    }

    return retVal;
}

- (void)prepareBubbleComponentsPosition
{
    if (shouldUpdateComponentsPosition)
    {
        // The bubble layout depends on the room read receipts which must be retrieved on the main thread to prevent us from race conditions.
        // Check here the current thread, this is just a sanity check because this method is called during the rendering step
        // which takes place on the main thread.
        if ([NSThread currentThread] != [NSThread mainThread])
        {
            MXLogDebug(@"[RoomBubbleCellData] prepareBubbleComponentsPosition called on wrong thread");
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self refreshBubbleComponentsPosition];
            });
        }
        else
        {
            [self refreshBubbleComponentsPosition];
        }
        
        shouldUpdateComponentsPosition = NO;
    }
    
    [self updateAdditionalContentHeightIfNeeded];
}

- (NSAttributedString*)attributedTextMessage
{
    [self buildAttributedStringIfNeeded];
    
    return attributedTextMessage;
}

- (NSAttributedString*)attributedTextMessageWithoutPositioningSpace
{
    [self buildAttributedStringIfNeeded];
    
    return attributedTextMessageWithoutPositioningSpace;
}

- (BOOL)hasNoDisplay
{
    BOOL hasNoDisplay = YES;
    
    switch (self.tag)
    {
        case RoomBubbleCellDataTagKeyVerificationNoDisplay:
            hasNoDisplay = YES;
            break;
        case RoomBubbleCellDataTagRoomCreationIntro:
            hasNoDisplay = NO;
            break;
        case RoomBubbleCellDataTagPoll:
            if (!self.events.lastObject.isEditEvent)
            {
                hasNoDisplay = NO;
            }
            
            break;
        case RoomBubbleCellDataTagLocation:
            hasNoDisplay = NO;
            break;
        case RoomBubbleCellDataTagLiveLocation:
            // Show the cell only if the summary exists
            if (self.beaconInfoSummary)
            {
                hasNoDisplay = NO;
            }
            
            break;
        case RoomBubbleCellDataTagVoiceBroadcastRecord:
        case RoomBubbleCellDataTagVoiceBroadcastPlayback:
            hasNoDisplay = NO;
            break;
        case RoomBubbleCellDataTagVoiceBroadcastNoDisplay:
            break;
        case RoomBubbleCellDataTagRTCCallNotify:
        {
            hasNoDisplay = NO;
            break;
        }
        default:
            hasNoDisplay = [super hasNoDisplay];
            break;
    }
    
    return hasNoDisplay;
}

- (BOOL)hasThreadRoot
{
    if (!RiotSettings.shared.enableThreads)
    {
        //  do not consider this cell data if threads not enabled in the timeline
        return NO;
    }

    if (roomDataSource.threadId)
    {
        //  do not consider this cell data if in a thread view
        return NO;
    }
    
    return super.hasThreadRoot;
}

- (BOOL)mergeWithBubbleCellData:(id<MXKRoomBubbleCellDataStoring>)bubbleCellData
{
    RoomTimelineConfiguration *timelineConfiguration = [RoomTimelineConfiguration shared];
    if (NO == [timelineConfiguration.currentStyle canMergeWithCellData:bubbleCellData into:self]) {
        return NO;
    }

    return [super mergeWithBubbleCellData:bubbleCellData];
}

#pragma mark - Bubble collapsing

- (BOOL)collapseWith:(id<MXKRoomBubbleCellDataStoring>)cellData
{
    if (self.tag == RoomBubbleCellDataTagMembership
        && cellData.tag == RoomBubbleCellDataTagMembership)
    {
        // For now, do not merge VoIP conference events
        if (![MXCallManager isConferenceUser:cellData.events.firstObject.stateKey])
        {
            // Keep a pagination between events of different days
            NSString *bubbleDateString = [roomDataSource.eventFormatter dateStringFromDate:self.date withTime:NO];
            NSString *eventDateString = [roomDataSource.eventFormatter dateStringFromDate:((RoomBubbleCellData*)cellData).date withTime:NO];
            if (bubbleDateString && eventDateString && [bubbleDateString isEqualToString:eventDateString])
            {
                return YES;
            }
        }

        return NO;
    }
    else if (self.tag == RoomBubbleCellDataTagRoomCreateConfiguration && cellData.tag == RoomBubbleCellDataTagRoomCreateConfiguration)
    {
        return YES;
    }
    else if (self.tag == RoomBubbleCellDataTagCall && cellData.tag == RoomBubbleCellDataTagCall)
    {
        //  Check if the same call
        MXEvent * event1 = self.events.firstObject;
        MXCallEventContent *eventContent1 = [MXCallEventContent modelFromJSON:event1.content];

        MXEvent * event2 = cellData.events.firstObject;
        MXCallEventContent *eventContent2 = [MXCallEventContent modelFromJSON:event2.content];

        return [eventContent1.callId isEqualToString:eventContent2.callId];
    }
    
    if (self.tag == RoomBubbleCellDataTagRoomCreateWithPredecessor || cellData.tag == RoomBubbleCellDataTagRoomCreateWithPredecessor)
    {
        return NO;
    }
    
    return [super collapseWith:cellData];
}

- (void)setCollapsed:(BOOL)collapsed
{
    if (collapsed != self.collapsed)
    {
        super.collapsed = collapsed;

        // Refresh only cells series header
        if (self.collapsedAttributedTextMessage && self.nextCollapsableCellData)
        {
            [self invalidateTextLayout];
        }
    }
}

#pragma mark -

- (void)invalidateLayout
{
    [self invalidateTextLayout];
    [self setNeedsUpdateAdditionalContentHeight];
}

- (void)buildAttributedString
{
    // CAUTION: This method must be called on the main thread.

    // Return the collapsed string only for cells series header
    if (self.collapsed && self.collapsedAttributedTextMessage && self.nextCollapsableCellData)
    {
        NSAttributedString *attributedString = super.collapsedAttributedTextMessage;
        
        self.attributedTextMessage = attributedString;
        self.attributedTextMessageWithoutPositioningSpace = attributedString;
        
        return;
    }

    NSMutableAttributedString *currentAttributedTextMsg;
    
    NSMutableAttributedString *currentAttributedTextMsgWithoutVertSpace = [NSMutableAttributedString new];
    
    NSInteger selectedComponentIndex = self.selectedComponentIndex;
    NSInteger lastMessageIndex = self.containsLastMessage ? self.mostRecentComponentIndex : NSNotFound;
    
    MXKRoomBubbleComponent *component;
    NSAttributedString *componentString;
    NSUInteger index = 0;
    for (; index < bubbleComponents.count; index++)
    {
        component = bubbleComponents[index];
        componentString = component.attributedTextMessage;
        
        if (componentString)
        {
            // Check whether another component than this one is selected
            // Note: When a component is selected, it is highlighted by applying an alpha on other components.
            if (selectedComponentIndex != NSNotFound && selectedComponentIndex != index && componentString.length)
            {
                // Apply alpha to blur this component
                componentString = [componentString withTextColorAlpha:.2];
                if (@available(iOS 15.0, *)) {
                    [PillsFormatter setPillAlpha:.2 inAttributedString:componentString];
                }
            }
            else if (@available(iOS 15.0, *))
            {
                // PillTextAttachment are not created again every time, we have to set alpha back to standard if needed.
                [PillsFormatter setPillAlpha:1.f inAttributedString:componentString];
            }
            
            // Check whether the timestamp is displayed for this component, and check whether a vertical whitespace is required
            if (((selectedComponentIndex == index && self.addVerticalWhitespaceForSelectedComponentTimestamp) || lastMessageIndex == index) && (self.shouldHideSenderInformation || self.shouldHideSenderName))
            {
                currentAttributedTextMsg = [[NSMutableAttributedString alloc] initWithAttributedString:[RoomBubbleCellData timestampVerticalWhitespace]];
                [currentAttributedTextMsg appendAttributedString:componentString];
                
                [currentAttributedTextMsgWithoutVertSpace appendAttributedString:componentString];
            }
            else
            {
                // Init attributed string with the first text component
                currentAttributedTextMsg = [[NSMutableAttributedString alloc] initWithAttributedString:componentString];
                
                [currentAttributedTextMsgWithoutVertSpace appendAttributedString:componentString];
            }

            [self addVerticalWhitespaceToString:currentAttributedTextMsg forEvent:component.event.eventId];
            
            // The first non empty component has been handled.
            break;
        }
    }
    
    for (index++; index < bubbleComponents.count; index++)
    {
        component = bubbleComponents[index];
        componentString = component.attributedTextMessage;
        
        if (componentString)
        {
            [currentAttributedTextMsg appendAttributedString:[MXKRoomBubbleCellDataWithAppendingMode messageSeparator]];
            
            // Check whether another component than this one is selected
            if (selectedComponentIndex != NSNotFound && selectedComponentIndex != index && componentString.length)
            {
                // Apply alpha to blur this component
                componentString = [componentString withTextColorAlpha:.2];
                if (@available(iOS 15.0, *)) {
                    [PillsFormatter setPillAlpha:.2 inAttributedString:componentString];
                }
            }
            else if (@available(iOS 15.0, *))
            {
                // PillTextAttachment are not created again every time, we have to set alpha back to standard if needed.
                [PillsFormatter setPillAlpha:1.f inAttributedString:componentString];
            }
            
            // Check whether the timestamp is displayed
            if ((selectedComponentIndex == index && self.addVerticalWhitespaceForSelectedComponentTimestamp) || lastMessageIndex == index)
            {
                [currentAttributedTextMsg appendAttributedString:[RoomBubbleCellData timestampVerticalWhitespace]];
            }
            
            // Append attributed text
            [currentAttributedTextMsg appendAttributedString:componentString];
            
            [self addVerticalWhitespaceToString:currentAttributedTextMsg forEvent:component.event.eventId];
            
            [currentAttributedTextMsgWithoutVertSpace appendAttributedString:componentString];
        }
    }
    
    // With bubbles the text is truncated with quote messages containing vertical border view
    // Add horizontal space to fix the issue
    if (self.displayFix & MXKRoomBubbleComponentDisplayFixHtmlBlockquote)
    {
        [currentAttributedTextMsgWithoutVertSpace appendString:@"       "];
    }
        
    self.attributedTextMessage = currentAttributedTextMsg;
    
    self.attributedTextMessageWithoutPositioningSpace = currentAttributedTextMsgWithoutVertSpace;
}

- (void)buildAttributedStringIfNeeded
{
    @synchronized(bubbleComponents)
    {
        if (self.hasAttributedTextMessage && !attributedTextMessage.length)
        {
            // Attributed text message depends on the room read receipts which must be retrieved on the main thread to prevent us from race conditions.
            // Check here the current thread, this is just a sanity check because the attributed text message
            // is requested during the rendering step which takes place on the main thread.
            if ([NSThread currentThread] != [NSThread mainThread])
            {
                MXLogDebug(@"[RoomBubbleCellData] attributedTextMessage called on wrong thread");
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [self buildAttributedString];
                });
            }
            else
            {
                [self buildAttributedString];
            }
        }
    }
}

- (NSInteger)firstVisibleComponentIndex
{
    __block NSInteger firstVisibleComponentIndex = NSNotFound;
    
    MXEvent *firstEvent = self.events.firstObject;
    BOOL isPoll = firstEvent.isTimelinePollEvent;
    BOOL isVoiceBroadcast = (firstEvent.eventType == MXEventTypeCustom && [firstEvent.type isEqualToString: VoiceBroadcastSettings.voiceBroadcastInfoContentKeyType]);
    
    if ((isPoll || self.attachment || isVoiceBroadcast) && self.bubbleComponents.count)
    {
        firstVisibleComponentIndex = 0;
    }
    else
    {
        [self.bubbleComponents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            MXKRoomBubbleComponent *component = (MXKRoomBubbleComponent*)obj;
            
            if (component.attributedTextMessage)
            {
                firstVisibleComponentIndex = idx;
                *stop = YES;
            }
        }];
    }
    
    return firstVisibleComponentIndex;
}

- (void)refreshBubbleComponentsPosition
{
    // CAUTION: This method must be called on the main thread.
    
    @synchronized(bubbleComponents)
    {
        NSInteger bubbleComponentsCount = bubbleComponents.count;
        
        // Check whether there is at least one component.
        if (bubbleComponentsCount)
        {
            // Set position of the first component
            CGFloat positionY = (self.attachment == nil || self.attachment.type == MXKAttachmentTypeFile || self.attachment.type == MXKAttachmentTypeAudio) ? MXKROOMBUBBLECELLDATA_TEXTVIEW_DEFAULT_VERTICAL_INSET : 0;
            MXKRoomBubbleComponent *component;
            NSUInteger index = 0;
            
            // Use same position for first components without render (redacted)
            for (; index < bubbleComponentsCount; index++)
            {
                // Compute the vertical position for next component
                component = bubbleComponents[index];
                
                component.position = CGPointMake(0, positionY);
                
                if (component.attributedTextMessage)
                {
                    break;
                }
            }
            
            // Check whether the position of other components need to be refreshed
            if (!self.attachment && index < bubbleComponentsCount)
            {
                NSMutableAttributedString *attributedString = [NSMutableAttributedString new];
                NSInteger selectedComponentIndex = self.selectedComponentIndex;
                NSInteger lastMessageIndex = self.containsLastMessage ? self.mostRecentComponentIndex : NSNotFound;
                NSInteger visibleMessageIndex = 0;

                for (; index < bubbleComponentsCount; index++)
                {
                    // Compute the vertical position for next component
                    component = bubbleComponents[index];
                    
                    if (component.attributedTextMessage)
                    {
                        // Prepare its attributed string by considering potential vertical margin required to display timestamp.
                        NSAttributedString *componentString = component.attributedTextMessage;

                        // Check whether the timestamp is displayed for this component, and check whether a vertical whitespace is required
                        
                        if (((selectedComponentIndex == index && self.addVerticalWhitespaceForSelectedComponentTimestamp) || lastMessageIndex == index)
                            && !(visibleMessageIndex == 0 && !(self.shouldHideSenderInformation || self.shouldHideSenderName)))
                        {
                            [attributedString appendAttributedString:[RoomBubbleCellData timestampVerticalWhitespace]];
                        }
                        
                        // Append this attributed string.
                        [attributedString appendAttributedString:componentString];
                        
                        // Compute the height of the resulting string.
                        CGFloat cumulatedHeight = [self rawTextHeight:attributedString];
                        
                        // Deduce the position of the beginning of this component.
                        positionY = MXKROOMBUBBLECELLDATA_TEXTVIEW_DEFAULT_VERTICAL_INSET + (cumulatedHeight - [self rawTextHeight:componentString]);
                        
                        component.position = CGPointMake(0, positionY);
                        
                        // Vertical whitespace is added in case of read receipts or reactions
                        [self addVerticalWhitespaceToString:attributedString forEvent:component.event.eventId];
                        
                        [attributedString appendAttributedString:[MXKRoomBubbleCellDataWithAppendingMode messageSeparator]];
                        
                        visibleMessageIndex++;
                    }
                    else
                    {
                        component.position = CGPointMake(0, positionY);
                    }
                }
            }
        }
    }
}

- (void)addVerticalWhitespaceToString:(NSMutableAttributedString *)attributedString forEvent:(NSString *)eventId
{
    CGFloat additionalVerticalHeight = 0;
    
    // Add vertical whitespace in case of a url preview.
    additionalVerticalHeight+= [self urlPreviewHeightForEventId:eventId];
    // Add vertical whitespace in case of reactions.
    additionalVerticalHeight+= [self reactionHeightForEventId:eventId];
    // Add vertical whitespace in case of a thread root
    additionalVerticalHeight+= [self threadSummaryViewHeightForEventId:eventId];
    // Add vertical whitespace in case of from a thread
    additionalVerticalHeight+= [self fromAThreadViewHeightForEventId:eventId];
    // Add vertical whitespace in case of read receipts.
    additionalVerticalHeight+= [self readReceiptHeightForEventId:eventId];
    
    if (additionalVerticalHeight)
    {
        [attributedString appendAttributedString:[RoomBubbleCellData verticalWhitespaceForHeight: additionalVerticalHeight]];
    }
}

- (CGFloat)computeAdditionalHeight
{
    CGFloat height = 0;
    
    for (MXKRoomBubbleComponent *bubbleComponent in self.bubbleComponents)
    {
        NSString *eventId = bubbleComponent.event.eventId;
        
        height+= [self urlPreviewHeightForEventId:eventId];
        height+= [self reactionHeightForEventId:eventId];
        height+= [self threadSummaryViewHeightForEventId:eventId];
        height+= [self fromAThreadViewHeightForEventId:eventId];
        height+= [self readReceiptHeightForEventId:eventId];
    }
    
    return height;
}

- (void)updateAdditionalContentHeightIfNeeded;
{
    if (self.shouldUpdateAdditionalContentHeight)
    {
        void(^updateAdditionalHeight)(void) = ^() {
            self.additionalContentHeight = [self computeAdditionalHeight];
        };
        
        // The additional height depends on the room read receipts and reactions view which must be calculated on the main thread.
        // Check here the current thread, this is just a sanity check because this method is called during the rendering step
        // which takes place on the main thread.
        if ([NSThread currentThread] != [NSThread mainThread])
        {
            MXLogDebug(@"[RoomBubbleCellData] prepareBubbleComponentsPosition called on wrong thread");
            dispatch_sync(dispatch_get_main_queue(), ^{
                updateAdditionalHeight();
            });
        }
        else
        {
            updateAdditionalHeight();
        }
        
        self.shouldUpdateAdditionalContentHeight = NO;
    }
}

- (void)setNeedsUpdateAdditionalContentHeight
{
    self.shouldUpdateAdditionalContentHeight = YES;
}

- (CGFloat)threadSummaryViewHeightForEventId:(NSString*)eventId
{
    if (!RiotSettings.shared.enableThreads)
    {
        //  do not show thread summary view if threads not enabled in the timeline
        return 0;
    }
    if (roomDataSource.threadId)
    {
        //  do not show thread summary view on threads
        return 0;
    }
    NSInteger index = [self bubbleComponentIndexForEventId:eventId];
    if (index == NSNotFound)
    {
        return 0;
    }
    MXKRoomBubbleComponent *component = self.bubbleComponents[index];
    if (!component.thread)
    {
        //  component is not a thread root
        return 0;
    }
    return PlainRoomCellLayoutConstants.threadSummaryViewTopMargin +
        [ThreadSummaryView contentViewHeightForThread:component.thread fitting:self.maxTextViewWidth];
}

- (CGFloat)fromAThreadViewHeightForEventId:(NSString*)eventId
{
    if (!RiotSettings.shared.enableThreads)
    {
        //  do not show from a thread view if threads not enabled
        return 0;
    }
    if (roomDataSource.threadId)
    {
        //  do not show from a thread view on threads
        return 0;
    }
    NSInteger index = [self bubbleComponentIndexForEventId:eventId];
    if (index == NSNotFound)
    {
        return 0;
    }
    MXKRoomBubbleComponent *component = self.bubbleComponents[index];
    if (!component.event.isInThread)
    {
        //  event is not in a thread
        return 0;
    }
    return PlainRoomCellLayoutConstants.fromAThreadViewTopMargin +
        [FromAThreadView contentViewHeightForEvent:component.event fitting:self.maxTextViewWidth];
}

- (CGFloat)urlPreviewHeightForEventId:(NSString*)eventId
{
    MXKRoomBubbleComponent *component = [self bubbleComponentWithLinkForEventId:eventId];
    if (!component.showURLPreview)
    {
        return 0;
    }
    
    return PlainRoomCellLayoutConstants.urlPreviewViewTopMargin + [URLPreviewView contentViewHeightFor:component.urlPreviewData
                                                                                       fitting:self.maxTextViewWidth];
}

- (CGFloat)reactionHeightForEventId:(NSString*)eventId
{
    CGFloat height = 0;
    
    NSUInteger reactionCount = self.reactions[eventId].reactions.count;
    
    MXAggregatedReactions *aggregatedReactions = self.reactions[eventId];
    
    if (reactionCount)
    {
        CGFloat reactionsViewWidth = self.maxTextViewWidth - 4;
        
        static RoomReactionsViewSizer *reactionsViewSizer;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            reactionsViewSizer = [RoomReactionsViewSizer new];
        });

        BOOL showAllReactions = [self.eventsToShowAllReactions containsObject:eventId];
        RoomReactionsViewModel *viewModel = [[RoomReactionsViewModel alloc] initWithAggregatedReactions:aggregatedReactions eventId:eventId showAll:showAllReactions];
        height = [reactionsViewSizer heightForViewModel:viewModel fittingWidth:reactionsViewWidth] + PlainRoomCellLayoutConstants.reactionsViewTopMargin;
    }
    
    return height;
}

- (CGFloat)readReceiptHeightForEventId:(NSString*)eventId
{
    CGFloat height = 0;
    
    if (self.readReceipts[eventId].count)
    {
        height = PlainRoomCellLayoutConstants.readReceiptsViewHeight + PlainRoomCellLayoutConstants.readReceiptsViewTopMargin;
    }
    
    return height;
}

- (void)setContainsLastMessage:(BOOL)containsLastMessage
{
    // Check whether there is something to do
    if (_containsLastMessage || containsLastMessage)
    {
        // Update flag
        _containsLastMessage = containsLastMessage;
        
        // Indicate that the text message layout should be recomputed.
        [self invalidateTextLayout];
    }
}

- (void)setSelectedEventId:(NSString *)selectedEventId
{
    // Check whether there is something to do
    if (_selectedEventId || selectedEventId.length)
    { 
        // Update flag
        _selectedEventId = selectedEventId;
        
        // Indicate that the text message layout should be recomputed.
        [self invalidateTextLayout];
    }
}

- (NSInteger)oldestComponentIndex
{
    // Update the related component index
    NSInteger oldestComponentIndex = NSNotFound;
    
    NSArray *components = self.bubbleComponents;
    NSInteger index = 0;
    while (index < components.count)
    {
        MXKRoomBubbleComponent *component = components[index];
        if (component.attributedTextMessage && component.date)
        {
            oldestComponentIndex = index;
            break;
        }
        index++;
    }
    
    return oldestComponentIndex;
}

- (NSInteger)mostRecentComponentIndex
{
    // Update the related component index
    NSInteger mostRecentComponentIndex = NSNotFound;
    
    NSArray *components = self.bubbleComponents;
    NSInteger index = components.count;
    while (index--)
    {
        MXKRoomBubbleComponent *component = components[index];
        if (component.attributedTextMessage && component.date)
        {
            mostRecentComponentIndex = index;
            break;
        }
    }
    
    return mostRecentComponentIndex;
}

- (NSInteger)selectedComponentIndex
{
    // Update the related component index
    NSInteger selectedComponentIndex = NSNotFound;
    
    if (_selectedEventId)
    {
        NSArray *components = self.bubbleComponents;
        NSInteger index = components.count;
        while (index--)
        {
            MXKRoomBubbleComponent *component = components[index];
            if ([component.event.eventId isEqualToString:_selectedEventId])
            {
                selectedComponentIndex = index;
                break;
            }
        }
    }
    
    return selectedComponentIndex;
}

- (MXKRoomBubbleComponent *)bubbleComponentWithLinkForEventId:(NSString *)eventId
{
    NSInteger index = [self bubbleComponentIndexForEventId:eventId];
    if (index == NSNotFound)
    {
        return nil;
    }
    
    MXKRoomBubbleComponent *component = self.bubbleComponents[index];
    if (!component.link)
    {
        return nil;
    }
    
    return component;
}

#pragma mark -

+ (NSAttributedString *)timestampVerticalWhitespace
{
    @synchronized(self)
    {
        if (timestampVerticalWhitespace == nil)
        {
            timestampVerticalWhitespace = [[NSAttributedString alloc] initWithString:@"\n" attributes:@{NSForegroundColorAttributeName : [UIColor blackColor],
                                                                                                          NSFontAttributeName: [UIFont systemFontOfSize:12]}];
        }
    }
    return timestampVerticalWhitespace;
}

+ (NSAttributedString *)verticalWhitespaceForHeight:(CGFloat)height
{
    UIFont *sizingFont = [UIFont systemFontOfSize:2];
    CGFloat returnHeight = sizingFont.lineHeight;
    
    NSUInteger returns = (NSUInteger)round(height/returnHeight);
    NSMutableString *returnString = [NSMutableString string];
    
    for (NSUInteger i = 0; i < returns; i++)
    {
        [returnString appendString:@"\n"];
    }
    
    return [[NSAttributedString alloc] initWithString:returnString attributes:@{NSForegroundColorAttributeName : [UIColor blackColor],
                                                                                NSFontAttributeName: sizingFont}];
}

- (BOOL)hasSameSenderAsBubbleCellData:(id<MXKRoomBubbleCellDataStoring>)bubbleCellData
{
    if (self.tag == RoomBubbleCellDataTagMembership || bubbleCellData.tag == RoomBubbleCellDataTagMembership)
    {
        // We do not want to merge membership event cells with other cell types
        return NO;
    }
    
    if (self.tag == RoomBubbleCellDataTagRoomCreateWithPredecessor || bubbleCellData.tag == RoomBubbleCellDataTagRoomCreateWithPredecessor)
    {
        // We do not want to merge room create event cells with other cell types
        return NO;
    }
    
    if (self.tag == RoomBubbleCellDataTagPoll) {
        MXEvent* event = self.events.firstObject;
        
        if (event) {
            // m.poll.ended events should always show the sender information
            return event.eventType != MXEventTypePollEnd;
        }
    }

    if (self.hasThreadRoot || bubbleCellData.hasThreadRoot)
    {
        // We do not want to merge events containing thread roots
        return NO;
    }

    return [super hasSameSenderAsBubbleCellData:bubbleCellData];
}

- (BOOL)addEvent:(MXEvent*)event andRoomState:(MXRoomState*)roomState
{
    if (self.hasThreadRoot)
    {
        // We don't want to add any events into this bubble data if it's a thread root
        return NO;
    }
    RoomTimelineConfiguration *timelineConfiguration = [RoomTimelineConfiguration shared];
    
    if (NO == [timelineConfiguration.currentStyle canAddEvent:event and:roomState to:self]) {
        return NO;
    }
    
    BOOL shouldAddEvent = YES;
    
    switch (self.tag)
    {
        case RoomBubbleCellDataTagKeyVerificationNoDisplay:
        case RoomBubbleCellDataTagKeyVerificationRequest:
        case RoomBubbleCellDataTagKeyVerificationRequestIncomingApproval:
        case RoomBubbleCellDataTagKeyVerificationConclusion:
            shouldAddEvent = NO;
            break;
        case RoomBubbleCellDataTagRoomCreateWithPredecessor:
            // We do not want to merge room create event cells with other cell types
            shouldAddEvent = NO;
            break;
        case RoomBubbleCellDataTagMembership:
            // One single bubble per membership event
            shouldAddEvent = NO;
            break;
        case RoomBubbleCellDataTagCall:
            shouldAddEvent = NO;
            break;
        case RoomBubbleCellDataTagGroupCall:
            shouldAddEvent = NO;
            break;
        case RoomBubbleCellDataTagRTCCallNotify:
            shouldAddEvent = NO;
            break;
        case RoomBubbleCellDataTagRoomCreateConfiguration:
            shouldAddEvent = NO;
            break;
        case RoomBubbleCellDataTagRoomCreationIntro:
            shouldAddEvent = NO;
            break;
        case RoomBubbleCellDataTagPoll:
            shouldAddEvent = NO;
            break;
        case RoomBubbleCellDataTagLocation:
            shouldAddEvent = NO;
            break;
        case RoomBubbleCellDataTagLiveLocation:
            shouldAddEvent = NO;
            break;
        case RoomBubbleCellDataTagVoiceBroadcastRecord:
        case RoomBubbleCellDataTagVoiceBroadcastPlayback:
        case RoomBubbleCellDataTagVoiceBroadcastNoDisplay:
            shouldAddEvent = NO;
            break;
        default:
            break;
    }
    
    // If the current bubbleData supports adding events then check
    // if the incoming event can be added in
    if (shouldAddEvent)
    {
        switch (event.eventType)
        {
            case MXEventTypeRoomMessage:
            {
                if (event.location) {
                    shouldAddEvent = NO;
                    break;
                }
                
                NSString *messageType = event.content[kMXMessageTypeKey];
                
                if ([messageType isEqualToString:kMXMessageTypeKeyVerificationRequest])
                {
                    shouldAddEvent = NO;
                }
                break;
            }
            case MXEventTypeKeyVerificationStart:
            case MXEventTypeKeyVerificationAccept:
            case MXEventTypeKeyVerificationKey:
            case MXEventTypeKeyVerificationMac:
            case MXEventTypeKeyVerificationDone:
            case MXEventTypeKeyVerificationCancel:
                shouldAddEvent = NO;
                break;
            case MXEventTypeRoomMember:
                shouldAddEvent = NO;
                break;
            case MXEventTypeRoomCreate:
                shouldAddEvent = NO;
                break;
            case MXEventTypeRoomTopic:
            case MXEventTypeRoomName:
            case MXEventTypeRoomEncryption:
            case MXEventTypeRoomHistoryVisibility:
            case MXEventTypeRoomGuestAccess:
            case MXEventTypeRoomAvatar:
            case MXEventTypeRoomJoinRules:
                shouldAddEvent = NO;
                break;
            case MXEventTypeCallInvite:
            case MXEventTypeCallAnswer:
            case MXEventTypeCallHangup:
            case MXEventTypeCallReject:
                shouldAddEvent = NO;
                break;
            case MXEventTypeCallNotify:
                shouldAddEvent = NO;
                break;
            case MXEventTypePollStart:
            case MXEventTypePollEnd:
                shouldAddEvent = NO;
                break;
            case MXEventTypeBeaconInfo:
                shouldAddEvent = NO;
                break;
            case MXEventTypeCustom:
            {
                if ([event.type isEqualToString:kWidgetMatrixEventTypeString]
                    || [event.type isEqualToString:kWidgetModularEventTypeString])
                {
                    Widget *widget = [[Widget alloc] initWithWidgetEvent:event inMatrixSession:roomDataSource.mxSession];
                    if ([widget.type isEqualToString:kWidgetTypeJitsiV1] ||
                        [widget.type isEqualToString:kWidgetTypeJitsiV2])
                    {
                        shouldAddEvent = NO;
                    }
                } else if ([event.type isEqualToString:VoiceBroadcastSettings.voiceBroadcastInfoContentKeyType]) {
                    shouldAddEvent = NO;
                }
                break;
            }
            default:
                break;
        }
    }
    
    if (shouldAddEvent)
    {
        shouldAddEvent = [super addEvent:event andRoomState:roomState];
        
        // If the event was added, load any url preview data if necessary.
        if (shouldAddEvent)
        {
            [self refreshURLPreviewForEventId:event.eventId];
        }
    }
    
    return shouldAddEvent;
}

- (void)setKeyVerification:(MXKeyVerification *)keyVerification
{
    _keyVerification = keyVerification;
    
    [self keyVerificationDidUpdate];
}

- (void)keyVerificationDidUpdate
{
    MXEvent *event = self.getFirstBubbleComponentWithDisplay.event;
    MXKeyVerification *keyVerification = _keyVerification;
    
    if (!event)
    {
        return;
    }
    
    switch (event.eventType)
    {
        case MXEventTypeKeyVerificationCancel:
        {
            RoomBubbleCellDataTag cellDataTag;
            
            MXTransactionCancelCode *transactionCancelCode = keyVerification.transaction.reasonCancelCode;
            
            if (transactionCancelCode
                && ([transactionCancelCode isEqual:[MXTransactionCancelCode mismatchedSas]]
                    || [transactionCancelCode isEqual:[MXTransactionCancelCode mismatchedKeys]]
                    || [transactionCancelCode isEqual:[MXTransactionCancelCode mismatchedCommitment]]
                    )
                )
            {
                cellDataTag = RoomBubbleCellDataTagKeyVerificationConclusion;
            }
            else
            {
                cellDataTag = RoomBubbleCellDataTagKeyVerificationNoDisplay;
            }
            
            self.tag = cellDataTag;
        }
            break;
        case MXEventTypeKeyVerificationDone:
        {
            RoomBubbleCellDataTag cellDataTag;
            
            // Avoid to display incoming and outgoing done, only display the incoming one.
            if (self.isIncoming && keyVerification && (keyVerification.state == MXKeyVerificationStateVerified))
            {
                cellDataTag = RoomBubbleCellDataTagKeyVerificationConclusion;
            }
            else
            {
                cellDataTag = RoomBubbleCellDataTagKeyVerificationNoDisplay;
            }
            
            self.tag = cellDataTag;
        }
            break;
        case MXEventTypeRoomMessage:
        {
            NSString *msgType = event.content[kMXMessageTypeKey];
            
            if ([msgType isEqualToString:kMXMessageTypeKeyVerificationRequest])
            {
                RoomBubbleCellDataTag cellDataTag;
                
                if (self.isIncoming && !self.isKeyVerificationOperationPending && keyVerification && keyVerification.state == MXKeyVerificationRequestStatePending)
                {
                    cellDataTag = RoomBubbleCellDataTagKeyVerificationRequestIncomingApproval;
                }
                else
                {
                    cellDataTag = RoomBubbleCellDataTagKeyVerificationRequest;
                }
                
                self.tag = cellDataTag;
            }
        }
            break;
        default:
            break;
    }
    
}

#pragma mark - Show all reactions

- (BOOL)showAllReactionsForEvent:(NSString*)eventId
{
    return [self.eventsToShowAllReactions containsObject:eventId];
}

- (void)setShowAllReactions:(BOOL)showAllReactions forEvent:(NSString*)eventId
{
    if (showAllReactions)
    {
        [self.eventsToShowAllReactions addObject:eventId];
    }
    else
    {
        [self.eventsToShowAllReactions removeObject:eventId];
    }
}

- (NSString *)accessibilityLabel
{
    NSString *accessibilityLabel;

    // Only media require manual handling for accessibility
    if (self.attachment)
    {
        NSString *mediaName = [self accessibilityLabelForAttachmentType:self.attachment.type];

        MXJSONModelSetString(accessibilityLabel, self.events.firstObject.content[kMXMessageBodyKey]);
        if (accessibilityLabel)
        {
            accessibilityLabel = [NSString stringWithFormat:@"%@ %@", mediaName, accessibilityLabel];
        }
        else
        {
            accessibilityLabel = mediaName;
        }
    }

    return accessibilityLabel;
}

- (NSString*)accessibilityLabelForAttachmentType:(MXKAttachmentType)attachmentType
{
    NSString *accessibilityLabel;
    switch (attachmentType)
    {
        case MXKAttachmentTypeImage:
            accessibilityLabel = [VectorL10n mediaTypeAccessibilityImage];
            break;
        case MXKAttachmentTypeAudio:
            accessibilityLabel = [VectorL10n mediaTypeAccessibilityAudio];
            break;
        case MXKAttachmentTypeVoiceMessage:
            accessibilityLabel = [VectorL10n mediaTypeAccessibilityAudio];
            break;
        case MXKAttachmentTypeVideo:
            accessibilityLabel = [VectorL10n mediaTypeAccessibilityVideo];
            break;
        case MXKAttachmentTypeFile:
            accessibilityLabel = [VectorL10n mediaTypeAccessibilityFile];
            break;
        case MXKAttachmentTypeSticker:
            accessibilityLabel = [VectorL10n mediaTypeAccessibilitySticker];
            break;
        default:
            accessibilityLabel = @"";
            break;
    }

    return accessibilityLabel;
}

#pragma mark - URL Previews

- (void)refreshURLPreviewForEventId:(NSString *)eventId
{
    // Get the event's component, but only if it has a link.
    MXKRoomBubbleComponent *component = [self bubbleComponentWithLinkForEventId:eventId];
    if (!component)
    {
        return;
    }
    
    // Don't show the preview if they're disabled globally or this one has been dismissed previously.
    component.showURLPreview = RiotSettings.shared.roomScreenShowsURLPreviews && [URLPreviewService.shared shouldShowPreviewFor:component.event];
    if (!component.showURLPreview)
    {
        return;
    }
    
    // If there is existing preview data, the message has been edited.
    // Clear the data to show the loading state when the preview isn't cached.
    if (component.urlPreviewData)
    {
        component.urlPreviewData = nil;
    }
    
    // Set the preview data.
    MXWeakify(self);
    
    NSDictionary<NSString *, NSString*> *userInfo = @{
        @"eventId": eventId,
        @"roomId": self.roomId
    };
    
    [URLPreviewService.shared previewFor:component.link
                                     and:component.event
                                    with:self.mxSession
                                 success:^(URLPreviewData * _Nonnull urlPreviewData) {
        MXStrongifyAndReturnIfNil(self);
        
        // Update the preview data, indicate that the message layout needs refreshing and send a notification for refresh
        component.urlPreviewData = urlPreviewData;
        [self invalidateLayout];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:URLPreviewDidUpdateNotification object:nil userInfo:userInfo];
        });
        
    } failure:^(NSError * _Nullable error) {
        MXStrongifyAndReturnIfNil(self);
        
        MXLogDebug(@"[RoomBubbleCellData] Failed to get url preview")
        
        // Remove the loading URLPreviewView, indicate that the layout needs refreshing and send a notification for refresh
        component.showURLPreview = NO;
        [self invalidateLayout];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:URLPreviewDidUpdateNotification object:nil userInfo:userInfo];
        });
    }];
}

- (void)updateBeaconInfoSummaryWithId:(NSString *)eventId andEvent:(MXEvent*)event
{
    if (event.eventType != MXEventTypeBeaconInfo)
    {
        MXLogErrorDetails(@"[RoomBubbleCellData] Try to update beacon info summary with wrong event type", @{
            @"event_id": eventId ?: @"unknown"
        });
        return;
    }
    
    id<MXBeaconInfoSummaryProtocol> beaconInfoSummary = [self.mxSession.aggregations.beaconAggregations beaconInfoSummaryFor:eventId inRoomWithId:self.roomId];
    
    if (!beaconInfoSummary)
    {
        MXBeaconInfo *beaconInfo = [[MXBeaconInfo alloc] initWithMXEvent:event];
        
        // A start beacon info event (isLive == true) should have an associated BeaconInfoSummary
        if (beaconInfo && beaconInfo.isLive)
        {
            MXLogErrorDetails(@"[RoomBubbleCellData] No beacon info summary found for beacon info start event", @{
                @"event_id": eventId ?: @"unknown"
            });
        }
    }
    
    self.beaconInfoSummary = beaconInfoSummary;
}

@end
/*
Copyright 2024 New Vector Ltd.
Copyright 2015 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

#import "MatrixKit.h"

@protocol MXBeaconInfoSummaryProtocol;

extern NSString *const URLPreviewDidUpdateNotification;

// Custom tags for MXKRoomBubbleCellDataStoring.tag
typedef NS_ENUM(NSInteger, RoomBubbleCellDataTag)
{
    RoomBubbleCellDataTagMessage = 0, // Default value used for messages
    RoomBubbleCellDataTagMembership,
    RoomBubbleCellDataTagRoomCreateConfiguration,
    RoomBubbleCellDataTagRoomCreateWithPredecessor,
    RoomBubbleCellDataTagKeyVerificationNoDisplay,
    RoomBubbleCellDataTagKeyVerificationRequestIncomingApproval,
    RoomBubbleCellDataTagKeyVerificationRequest,
    RoomBubbleCellDataTagKeyVerificationConclusion,
    RoomBubbleCellDataTagCall,
    RoomBubbleCellDataTagGroupCall,
    RoomBubbleCellDataTagRTCCallNotify,
    RoomBubbleCellDataTagRoomCreationIntro,
    RoomBubbleCellDataTagPoll,
    RoomBubbleCellDataTagLocation,
    RoomBubbleCellDataTagLiveLocation,
    RoomBubbleCellDataTagVoiceBroadcastRecord,
    RoomBubbleCellDataTagVoiceBroadcastPlayback,
    RoomBubbleCellDataTagVoiceBroadcastNoDisplay
};

/**
 `RoomBubbleCellData` defines Vector bubble cell data model.
 */
@interface RoomBubbleCellData : MXKRoomBubbleCellDataWithAppendingMode

/**
 A Boolean value that determines whether this bubble contains the current last message.
 Used to keep displaying the timestamp of the last message.
 */
@property(nonatomic) BOOL containsLastMessage;

/**
 Indicate true to display the timestamp of the selected component.
 */
@property(nonatomic) BOOL showTimestampForSelectedComponent;

/**
 Indicate true to display the timestamp of the selected component on the left if possible (YES by default).
 */
@property(nonatomic) BOOL displayTimestampForSelectedComponentOnLeftWhenPossible;

/**
 The event id of the current selected event inside the bubble. Default is nil.
 */
@property(nonatomic) NSString *selectedEventId;

/**
 The index of the oldest component (component with a timestamp, and an actual display). NSNotFound by default.
 */
@property(nonatomic, readonly) NSInteger oldestComponentIndex;

/**
 The index of the most recent component (component with a timestamp, and an actual display). NSNotFound by default.
 */
@property(nonatomic, readonly) NSInteger mostRecentComponentIndex;

/**
 The index of the current selected component. NSNotFound by default.
 */
@property(nonatomic, readonly) NSInteger selectedComponentIndex;

/**
 Return additional content height (read receipts, reactions).
 */
@property(nonatomic, readonly) CGFloat additionalContentHeight;

/**
 MXKeyVerification object associated to key verification event when using key verification by direct message.
 */
@property(nonatomic, strong) MXKeyVerification *keyVerification;

/**
 Indicate if there is a pending operation that updates `keyVerification` property.
 */
@property(nonatomic) BOOL isKeyVerificationOperationPending;

@property(nonatomic, strong) id<MXBeaconInfoSummaryProtocol> beaconInfoSummary;

/**
 Index of the component which needs a sent tick displayed. -1 if none.
 */
@property(nonatomic) NSInteger componentIndexOfSentMessageTick;

@property(nonatomic, strong) NSString *voiceBroadcastState;

/**
 Indicate that both the text message layout and any additional content height are no longer
 valid and should be recomputed before presentation in a bubble cell. This could be due
 to a content change, or the available space for the cell has been updated.
 
 This is a convenience method that calls `invalidateTextLayout` and
 `setNeedsUpdateAdditionalContentHeight` together.
 */
- (void)invalidateLayout;

/**
 Indicate to update additional content height.
 */
- (void)setNeedsUpdateAdditionalContentHeight;

/**
 Update additional content height if needed.
 */
- (void)updateAdditionalContentHeightIfNeeded;

/**
 The index of the first visible component. NSNotFound by default.
 */
- (NSInteger)firstVisibleComponentIndex;

/**
 Returns the bubble component for the specified event ID, but only if that component
 has detected a link in the event's body. Otherwise returns `nil`.
 
 This will also return `nil` If URL previews have been disabled by the user.
 */
- (MXKRoomBubbleComponent *)bubbleComponentWithLinkForEventId:(NSString *)eventId;

#pragma mark - Show all reactions

- (BOOL)showAllReactionsForEvent:(NSString*)eventId;
- (void)setShowAllReactions:(BOOL)showAllReactions forEvent:(NSString*)eventId;


#pragma mark - Accessibility

- (NSString*)accessibilityLabel;

@end
/*
Copyright 2024 New Vector Ltd.
Copyright 2017 Vector Creations Ltd
Copyright 2015 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

#import "RoomParticipantsViewController.h"

#import "RoomMemberDetailsViewController.h"

#import "GeneratedInterface-Swift.h"

#import "Contact.h"

#import "MXCallManager.h"

#import "ContactTableViewCell.h"

#import "RageShakeManager.h"

@interface RoomParticipantsViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UIGestureRecognizerDelegate, MXKRoomMemberDetailsViewControllerDelegate, RoomParticipantsInviteCoordinatorBridgePresenterDelegate>
{
    // Search result
    NSString *currentSearchText;
    NSMutableArray<Contact*> *filteredActualParticipants;
    NSMutableArray<Contact*> *filteredInvitedParticipants;
    
    // Mask view while processing a request
    UIActivityIndicatorView *pendingMaskSpinnerView;
    
    // The members events listener.
    id membersListener;
    
    // Observe kMXSessionWillLeaveRoomNotification to be notified if the user leaves the current room.
    id leaveRoomNotificationObserver;
    
    // Observe kMXRoomDidFlushDataNotification to take into account the updated room members when the room history is flushed.
    id roomDidFlushDataNotificationObserver;
    
    RoomMemberDetailsViewController *memberDetailsViewController;
    
    UIAlertController *currentAlert;
    
    // Observe kThemeServiceDidChangeThemeNotification to handle user interface theme change.
    id kThemeServiceDidChangeThemeNotificationObserver;
    
    RoomParticipantsInviteCoordinatorBridgePresenter *invitePresenter;
}

@end

@implementation RoomParticipantsViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([RoomParticipantsViewController class])
                          bundle:[NSBundle bundleForClass:[RoomParticipantsViewController class]]];
}

+ (instancetype)roomParticipantsViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([RoomParticipantsViewController class])
                                          bundle:[NSBundle bundleForClass:[RoomParticipantsViewController class]]];
}

#pragma mark -

- (void)finalizeInit
{
    [super finalizeInit];
    
    // Setup `MXKViewControllerHandling` properties
    self.enableBarTintColorStatusChange = NO;
    self.rageShakeManager = [RageShakeManager sharedManager];
    self.showParticipantCustomAccessoryView = YES;
    self.showInviteUserFab = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // Check whether the view controller has been pushed via storyboard
    if (!self.tableView)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }
    
    // Adjust Top and Bottom constraints to take into account potential navBar and tabBar.
    [NSLayoutConstraint deactivateConstraints:@[_searchBarTopConstraint]];
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated"
    _searchBarTopConstraint = [NSLayoutConstraint constraintWithItem:self.topLayoutGuide
                                                           attribute:NSLayoutAttributeBottom
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:self.searchBarHeader
                                                           attribute:NSLayoutAttributeTop
                                                          multiplier:1.0f
                                                            constant:0.0f];
    #pragma clang diagnostic pop
    
    [NSLayoutConstraint activateConstraints:@[_searchBarTopConstraint]];
    
    self.navigationItem.title = [VectorL10n roomParticipantsTitle];
    
    if (self.mxRoom.summary.roomType == MXRoomTypeSpace)
    {
        _searchBarView.placeholder = [VectorL10n searchDefaultPlaceholder];
    }
    else if (self.mxRoom.isDirect)
    {
        _searchBarView.placeholder = [VectorL10n roomParticipantsFilterRoomMembersForDm];
    }
    else
    {
        _searchBarView.placeholder = [VectorL10n roomParticipantsFilterRoomMembers];
    }
    _searchBarView.returnKeyType = UIReturnKeyDone;
    _searchBarView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    
    // Search bar header is hidden when no room is provided
    _searchBarHeader.hidden = (self.mxRoom == nil);
    
    [self setNavBarButtons];
    
    // Hide line separators of empty cells
    self.tableView.tableFooterView = [[UIView alloc] init];
    
    [self.tableView registerClass:ContactTableViewCell.class forCellReuseIdentifier:@"ParticipantTableViewCellId"];
    
    
    if (_showInviteUserFab)
    {
        // Add invite members button programmatically
        [self vc_addFABWithImage:AssetImages.addMemberFloatingAction.image
                          target:self
                          action:@selector(onAddParticipantButtonPressed)];
    }
    
    // Observe user interface theme change.
    kThemeServiceDidChangeThemeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kThemeServiceDidChangeThemeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        [self userInterfaceThemeDidChange];
        
    }];
    [self userInterfaceThemeDidChange];
}

- (void)userInterfaceThemeDidChange
{
    [ThemeService.shared.theme applyStyleOnNavigationBar:self.navigationController.navigationBar];

    self.activityIndicator.backgroundColor = ThemeService.shared.theme.overlayBackgroundColor;
    
    [self refreshSearchBarItemsColor:_searchBarView];
    
    _searchBarHeaderBorder.backgroundColor = ThemeService.shared.theme.headerBorderColor;
    
    // Check the table view style to select its bg color.
    self.tableView.backgroundColor = ((self.tableView.style == UITableViewStylePlain) ? ThemeService.shared.theme.backgroundColor : ThemeService.shared.theme.headerBackgroundColor);
    self.view.backgroundColor = self.tableView.backgroundColor;
    self.tableView.separatorColor = ThemeService.shared.theme.lineBreakColor;
    
    if (self.tableView.dataSource)
    {
        [self.tableView reloadData];
    }

    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return ThemeService.shared.theme.statusBarStyle;
}

// This method is called when the viewcontroller is added or removed from a container view controller.
- (void)didMoveToParentViewController:(nullable UIViewController *)parent
{
    [super didMoveToParentViewController:parent];
    
    [self setNavBarButtons];
}

- (void)destroy
{
    if (kThemeServiceDidChangeThemeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kThemeServiceDidChangeThemeNotificationObserver];
        kThemeServiceDidChangeThemeNotificationObserver = nil;
    }
    
    if (leaveRoomNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:leaveRoomNotificationObserver];
        leaveRoomNotificationObserver = nil;
    }
    
    if (roomDidFlushDataNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomDidFlushDataNotificationObserver];
        roomDidFlushDataNotificationObserver = nil;
    }
    
    if (membersListener)
    {
        MXWeakify(self);
        [self.mxRoom liveTimeline:^(id<MXEventTimeline> liveTimeline) {
            MXStrongifyAndReturnIfNil(self);

            [liveTimeline removeListener:self->membersListener];
            self->membersListener = nil;
        }];
    }
    
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    _mxRoom = nil;
    
    filteredActualParticipants = nil;
    filteredInvitedParticipants = nil;
    
    actualParticipants = nil;
    invitedParticipants = nil;
    userParticipant = nil;
    
    [self removePendingActionMask];
    
    [super destroy];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Refresh display
    [self refreshTableView];
    
    [self.screenTracker trackScreen];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (memberDetailsViewController)
    {
        [memberDetailsViewController destroy];
        memberDetailsViewController = nil;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    // cancel any pending search
    [self searchBarCancelButtonClicked:_searchBarView];
}

- (void)withdrawViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    // Check whether the current view controller is displayed inside a segmented view controller in order to withdraw the right item
    if (self.parentViewController && [self.parentViewController isKindOfClass:SegmentedViewController.class])
    {
        [((SegmentedViewController*)self.parentViewController) withdrawViewControllerAnimated:animated completion:completion];
    }
    else
    {
        [super withdrawViewControllerAnimated:animated completion:completion];
    }
}

#pragma mark -

- (void)setMxRoom:(MXRoom *)mxRoom
{
    // Cancel any pending search
    [self searchBarCancelButtonClicked:_searchBarView];

    // Make sure we can access synchronously to self.mxRoom and mxRoom data
    // to avoid race conditions
    MXWeakify(self);
    [mxRoom.mxSession preloadRoomsData:_mxRoom ? @[_mxRoom.roomId, mxRoom.roomId] : @[mxRoom.roomId]
                             onComplete:^{
        MXStrongifyAndReturnIfNil(self);

        // Remove previous room registration (if any).
        if (self.mxRoom)
        {
            // Remove the previous listener
            if (self->leaveRoomNotificationObserver)
            {
                [[NSNotificationCenter defaultCenter] removeObserver:self->leaveRoomNotificationObserver];
                self->leaveRoomNotificationObserver = nil;
            }
            if (self->roomDidFlushDataNotificationObserver)
            {
                [[NSNotificationCenter defaultCenter] removeObserver:self->roomDidFlushDataNotificationObserver];
                self->roomDidFlushDataNotificationObserver = nil;
            }
            if (self->membersListener)
            {
                MXWeakify(self);
                [self.mxRoom liveTimeline:^(id<MXEventTimeline> liveTimeline) {
                    MXStrongifyAndReturnIfNil(self);

                    [liveTimeline removeListener:self->membersListener];
                    self->membersListener = nil;
                }];
            }

            [self removeMatrixSession:self.mxRoom.mxSession];
        }

        self->_mxRoom = mxRoom;

        if (self.mxRoom)
        {
            self.searchBarHeader.hidden = NO;
            
            if (self.mxRoom.summary.roomType == MXRoomTypeSpace)
            {
                self.searchBarView.placeholder = [VectorL10n searchDefaultPlaceholder];
            }
            else if (self.mxRoom.isDirect)
            {
                self.searchBarView.placeholder = [VectorL10n roomParticipantsFilterRoomMembersForDm];
            }
            else
            {
                self.searchBarView.placeholder = [VectorL10n roomParticipantsFilterRoomMembers];
            }

            // Update the current matrix session.
            [self addMatrixSession:self.mxRoom.mxSession];

            // Observe kMXSessionWillLeaveRoomNotification to be notified if the user leaves the current room.
            self->leaveRoomNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionWillLeaveRoomNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {

                // Check whether the user will leave the room related to the displayed participants
                if (notif.object == self.mxRoom.mxSession)
                {
                    NSString *roomId = notif.userInfo[kMXSessionNotificationRoomIdKey];
                    if (roomId && [roomId isEqualToString:self.mxRoom.roomId])
                    {
                        // We remove the current view controller.
                        [self withdrawViewControllerAnimated:YES completion:nil];
                    }
                }
            }];

            // Observe room history flush (sync with limited timeline, or state event redaction)
            self->roomDidFlushDataNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomDidFlushDataNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {

                MXRoom *room = notif.object;
                if (self.mxRoom.mxSession == room.mxSession && [self.mxRoom.roomId isEqualToString:room.roomId])
                {
                    // The existing room history has been flushed during server sync. Take into account the updated room members list.
                    [self refreshParticipantsFromRoomMembers];

                    [self refreshTableView];
                }

            }];

            // Register a listener for events that concern room members
            NSArray *mxMembersEvents = @[kMXEventTypeStringRoomMember, kMXEventTypeStringRoomThirdPartyInvite, kMXEventTypeStringRoomPowerLevels];

            MXWeakify(self);
            [self.mxRoom liveTimeline:^(id<MXEventTimeline> liveTimeline) {
                MXStrongifyAndReturnIfNil(self);

                self->membersListener = [liveTimeline listenToEventsOfTypes:mxMembersEvents onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {

                    // Consider only live event
                    if (direction == MXTimelineDirectionForwards)
                    {
                        switch (event.eventType)
                        {
                            case MXEventTypeRoomMember:
                            {
                                // Take into account updated member
                                // Ignore here change related to the current user (this change is handled by leaveRoomNotificationObserver)
                                if ([event.stateKey isEqualToString:self.mxRoom.mxSession.myUser.userId] == NO)
                                {
                                    MXRoomMember *mxMember = [liveTimeline.state.members memberWithUserId:event.stateKey];
                                    if (mxMember)
                                    {
                                        // Remove previous occurrence of this member (if any)
                                        [self removeParticipantByKey:mxMember.userId];

                                        // If any, remove 3pid invite corresponding to this room member
                                        if (mxMember.thirdPartyInviteToken)
                                        {
                                            [self removeParticipantByKey:mxMember.thirdPartyInviteToken];
                                        }

                                        [self handleRoomMember:mxMember];

                                        [self finalizeParticipantsList:liveTimeline.state];

                                        [self refreshTableView];
                                    }
                                }

                                break;
                            }
                            case MXEventTypeRoomThirdPartyInvite:
                            {
                                MXRoomThirdPartyInvite *thirdPartyInvite = [liveTimeline.state thirdPartyInviteWithToken:event.stateKey];
                                if (thirdPartyInvite)
                                {
                                    [self addRoomThirdPartyInviteToParticipants:thirdPartyInvite roomState:liveTimeline.state];

                                    [self finalizeParticipantsList:liveTimeline.state];

                                    [self refreshTableView];
                                }
                                break;
                            }
                            case MXEventTypeRoomPowerLevels:
                            {
                                [self refreshParticipantsFromRoomMembers];

                                [self refreshTableView];
                                break;
                            }
                            default:
                                break;
                        }
                    }
                }];
            }];
        }
        else
        {
            // Search bar header is hidden when no room is provided
            self.searchBarHeader.hidden = YES;
        }

        // Refresh the members list.
        [self refreshParticipantsFromRoomMembers];

        [self refreshTableView];
    }];
}

- (void)setEnableMention:(BOOL)enableMention
{
    if (_enableMention != enableMention)
    {
        _enableMention = enableMention;
        
        if (memberDetailsViewController)
        {
            memberDetailsViewController.enableMention = enableMention;
        }
    }
}

- (void)startActivityIndicator
{
    // Check whether the current view controller is displayed inside a segmented view controller in order to run the right activity view
    if (self.parentViewController && [self.parentViewController isKindOfClass:SegmentedViewController.class])
    {
        [((SegmentedViewController*)self.parentViewController) startActivityIndicator];
        
        // Force stop the activity view of the view controller
        [self.activityIndicator stopAnimating];
    }
    else
    {
        [super startActivityIndicator];
    }
}

- (void)stopActivityIndicator
{
    // Check whether the current view controller is displayed inside a segmented view controller in order to stop the right activity view
    if (self.parentViewController && [self.parentViewController isKindOfClass:SegmentedViewController.class])
    {
        [((SegmentedViewController*)self.parentViewController) stopActivityIndicator];
        
        // Force stop the activity view of the view controller
        [self.activityIndicator stopAnimating];
    }
    else
    {
        [super stopActivityIndicator];
    }
}

#pragma mark - Internals

- (void)refreshTableView
{
    [self.tableView reloadData];
}

- (void)setNavBarButtons
{
    // Check whether the view controller is currently displayed inside a segmented view controller or not.
    UIViewController* topViewController = ((self.parentViewController) ? self.parentViewController : self);
    topViewController.navigationItem.rightBarButtonItem = nil;
    
    if (self.showCancelBarButtonItem)
    {
        topViewController.navigationItem.leftBarButtonItem  = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onCancel:)];
    }
    else
    {
        topViewController.navigationItem.leftBarButtonItem = nil;
    }
}

- (void)onAddParticipantButtonPressed
{
    self->invitePresenter = [[RoomParticipantsInviteCoordinatorBridgePresenter alloc] initWithSession:self.mxRoom.mxSession room:self.mxRoom parentSpaceId:self.parentSpaceId currentSearchText:currentSearchText actualParticipants:actualParticipants invitedParticipants:invitedParticipants userParticipant:userParticipant];
    self->invitePresenter.delegate = self;
    [self->invitePresenter presentFrom:self animated:true];
}

- (void)refreshParticipantsFromRoomMembers
{
    actualParticipants = [NSMutableArray array];
    invitedParticipants = [NSMutableArray array];
    userParticipant = nil;
    
    if (self.mxRoom)
    {
        // Retrieve the current members from the room state
        MXWeakify(self);
        [self.mxRoom state:^(MXRoomState *roomState) {
            MXStrongifyAndReturnIfNil(self);

            NSArray *members = [roomState.members membersWithoutConferenceUser];
            NSString *userId = self.mxRoom.mxSession.myUser.userId;
            NSArray *roomThirdPartyInvites = roomState.thirdPartyInvites;

            for (MXRoomMember *mxMember in members)
            {
                // Update the current participants list
                if ([mxMember.userId isEqualToString:userId])
                {
                    if (mxMember.membership == MXMembershipJoin || mxMember.membership == MXMembershipInvite)
                    {
                        // The user is in this room
                        NSString *displayName = [VectorL10n you];

                        self->userParticipant = [[Contact alloc] initMatrixContactWithDisplayName:displayName andMatrixID:userId];
                        self->userParticipant.mxMember = [roomState.members memberWithUserId:userId];
                    }
                }
                else
                {
                    [self handleRoomMember:mxMember];
                }
            }

            for (MXRoomThirdPartyInvite *roomThirdPartyInvite in roomThirdPartyInvites)
            {
                [self addRoomThirdPartyInviteToParticipants:roomThirdPartyInvite roomState:roomState];
            }

            [self finalizeParticipantsList:roomState];
        }];
    }
}

- (void)handleRoomMember:(MXRoomMember*)mxMember
{
    // Add this member after checking his status
    if (mxMember.membership == MXMembershipJoin || mxMember.membership == MXMembershipInvite)
    {
        // Prepare the display name of this member
        NSString *displayName = mxMember.displayname;
        if (displayName.length == 0)
        {
            // Look for the corresponding MXUser in matrix session
            MXUser *mxUser = [self.mxRoom.mxSession userWithUserId:mxMember.userId];
            if (mxUser)
            {
                displayName = ((mxUser.displayname.length > 0) ? mxUser.displayname : mxMember.userId);
            }
            else
            {
                displayName = mxMember.userId;
            }
        }
        
        // Create the contact related to this member
        Contact *contact = [[Contact alloc] initMatrixContactWithDisplayName:displayName andMatrixID:mxMember.userId];
        contact.mxMember = mxMember;
        
        if (mxMember.membership == MXMembershipInvite)
        {
            [invitedParticipants addObject:contact];
        }
        else
        {
            [actualParticipants addObject:contact];
        }
    }
}

- (void)reloadSearchResult
{
    if (currentSearchText.length)
    {
        NSString *searchText = currentSearchText;
        currentSearchText = nil;
        
        [self searchBar:_searchBarView textDidChange:searchText];
    }
}

- (void)addRoomThirdPartyInviteToParticipants:(MXRoomThirdPartyInvite*)roomThirdPartyInvite roomState:(MXRoomState*)roomState
{
    // If the homeserver has converted the 3pid invite into a room member, do no show it
    // If the invite has been revoked (null display name), do not show it too.
    if (![roomState memberWithThirdPartyInviteToken:roomThirdPartyInvite.token]
        && roomThirdPartyInvite.displayname)
    {
        Contact *contact = [[Contact alloc] initMatrixContactWithDisplayName:roomThirdPartyInvite.displayname andMatrixID:nil];
        contact.isThirdPartyInvite = YES;
        contact.mxThirdPartyInvite = roomThirdPartyInvite;
        
        [invitedParticipants addObject:contact];
    }
}

// key is a room member user id or a room 3pid invite token
- (void)removeParticipantByKey:(NSString*)key
{
    NSUInteger index;
    
    if (actualParticipants.count)
    {
        for (index = 0; index < actualParticipants.count; index++)
        {
            Contact *contact = actualParticipants[index];
            
            if (contact.mxMember && [contact.mxMember.userId isEqualToString:key])
            {
                [actualParticipants removeObjectAtIndex:index];
                return;
            }
        }
    }
    
    if (invitedParticipants.count)
    {
        for (index = 0; index < invitedParticipants.count; index++)
        {
            Contact *contact = invitedParticipants[index];
            
            if (contact.mxMember && [contact.mxMember.userId isEqualToString:key])
            {
                [invitedParticipants removeObjectAtIndex:index];
                return;
            }
            
            if (contact.mxThirdPartyInvite && [contact.mxThirdPartyInvite.token isEqualToString:key])
            {
                [invitedParticipants removeObjectAtIndex:index];
                return;
            }
        }
    }
}

- (void)finalizeParticipantsList:(MXRoomState*)roomState
{
    // Sort contacts by last active, with "active now" first.
    // ...and then by power
    // ...and then alphabetically.
    // We could tiebreak instead by "last recently spoken in this room" if we wanted to.
    NSComparator comparator = ^NSComparisonResult(Contact *contactA, Contact *contactB) {
        
        MXUser *userA = [self.mxRoom.mxSession userWithUserId:contactA.mxMember.userId];
        MXUser *userB = [self.mxRoom.mxSession userWithUserId:contactB.mxMember.userId];
        
        if (!userA && !userB)
        {
            return [contactA.sortingDisplayName compare:contactB.sortingDisplayName options:NSCaseInsensitiveSearch];
        }
        if (userA && !userB)
        {
            return NSOrderedAscending;
        }
        if (!userA && userB)
        {
            return NSOrderedDescending;
        }
        
        if (userA.currentlyActive && userB.currentlyActive)
        {
            // Order first by power levels (admins then moderators then others)
            MXRoomPowerLevels *powerLevels = [roomState powerLevels];
            NSInteger powerLevelA = [roomState powerLevelOfUserWithUserID:contactA.mxMember.userId];
            NSInteger powerLevelB = [roomState powerLevelOfUserWithUserID:contactB.mxMember.userId];
            
            if (powerLevelA == powerLevelB)
            {
                // Then order by name
                if (contactA.sortingDisplayName.length && contactB.sortingDisplayName.length)
                {
                    return [contactA.sortingDisplayName compare:contactB.sortingDisplayName options:NSCaseInsensitiveSearch];
                }
                else if (contactA.sortingDisplayName.length)
                {
                    return NSOrderedAscending;
                }
                else if (contactB.sortingDisplayName.length)
                {
                    return NSOrderedDescending;
                }
                return [contactA.displayName compare:contactB.displayName options:NSCaseInsensitiveSearch];
            }
            else
            {
                return powerLevelB - powerLevelA;
            }
            
        }
        
        if (userA.currentlyActive && !userB.currentlyActive)
        {
            return NSOrderedAscending;
        }
        if (!userA.currentlyActive && userB.currentlyActive)
        {
            return NSOrderedDescending;
        }
        
        // Finally, compare the lastActiveAgo
        NSUInteger lastActiveAgoA = userA.lastActiveAgo;
        NSUInteger lastActiveAgoB = userB.lastActiveAgo;
        
        if (lastActiveAgoA == lastActiveAgoB)
        {
            return NSOrderedSame;
        }
        else
        {
            return ((lastActiveAgoA > lastActiveAgoB) ? NSOrderedDescending : NSOrderedAscending);
        }
    };
    
    // Sort each participants list in alphabetical order
    [actualParticipants sortUsingComparator:comparator];
    [invitedParticipants sortUsingComparator:comparator];
    
    // Reload search result if any
    [self reloadSearchResult];
}

- (void)addPendingActionMask
{
    // Remove potential existing mask
    [self removePendingActionMask];
    
    // Add a spinner above the tableview to avoid that the user tap on any other button
    pendingMaskSpinnerView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    pendingMaskSpinnerView.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:0.5];
    pendingMaskSpinnerView.frame = self.tableView.frame;
    pendingMaskSpinnerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin;
    
    // append it
    [self.tableView.superview addSubview:pendingMaskSpinnerView];
    
    // animate it
    [pendingMaskSpinnerView startAnimating];
    
    // Show the spinner after a delay so that if it is removed in a short future,
    // it is not displayed to the end user.
    pendingMaskSpinnerView.alpha = 0;
    [UIView animateWithDuration:0.3 delay:0.3 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        
        self->pendingMaskSpinnerView.alpha = 1;
        
    } completion:^(BOOL finished) {
    }];
}

- (void)removePendingActionMask
{
    if (pendingMaskSpinnerView)
    {
        [pendingMaskSpinnerView removeFromSuperview];
        pendingMaskSpinnerView = nil;
    }
}

- (void)pushViewController:(UIViewController*)viewController
{
    // Check whether the view controller is displayed inside a segmented one.
    if (self.parentViewController.navigationController)
    {
        // Hide back button title
        [self.parentViewController vc_removeBackTitle];

        [self.parentViewController.navigationController pushViewController:viewController animated:YES];
    }
    else
    {
        // Hide back button title
        [self vc_removeBackTitle];

        [self.navigationController pushViewController:viewController animated:YES];
    }
}

- (void)showDetailFor:(MXRoomMember* _Nonnull)member from:(UIView* _Nullable)sourceView {
    memberDetailsViewController = [RoomMemberDetailsViewController roomMemberDetailsViewController];
    
    // Set delegate to handle action on member (start chat, mention)
    memberDetailsViewController.delegate = self;
    memberDetailsViewController.enableMention = _enableMention;
    memberDetailsViewController.enableVoipCall = NO;
    
    [memberDetailsViewController displayRoomMember:member withMatrixRoom:self.mxRoom];
    
    [self pushViewController:memberDetailsViewController];
}

#pragma mark - UITableView data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger count = 0;
    
    participantsSection = invitedSection = -1;
    
    if (currentSearchText.length)
    {
        if (filteredActualParticipants.count)
        {
            participantsSection = count++;
        }
        
        if (filteredInvitedParticipants.count)
        {
            invitedSection = count++;
        }
    }
    else
    {
        if (userParticipant || actualParticipants.count)
        {
            participantsSection = count++;
        }
        
        if (invitedParticipants.count)
        {
            invitedSection = count++;
        }
    }
    
    return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = 0;
    
    if (section == participantsSection)
    {
        if (currentSearchText.length)
        {
            count = filteredActualParticipants.count;
        }
        else
        {
            count = actualParticipants.count;
            if (userParticipant)
            {
                count++;
            }
        }
    }
    else if (section == invitedSection)
    {
        if (currentSearchText.length)
        {
            count = filteredInvitedParticipants.count;
        }
        else
        {
            count = invitedParticipants.count;
        }
    }
    
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    
    if (indexPath.section == participantsSection || indexPath.section == invitedSection)
    {
        ContactTableViewCell* participantCell = [tableView dequeueReusableCellWithIdentifier:@"ParticipantTableViewCellId" forIndexPath:indexPath];
        participantCell.selectionStyle = UITableViewCellSelectionStyleNone;
        participantCell.showCustomAccessoryView = self.showParticipantCustomAccessoryView;
        
        participantCell.mxRoom = self.mxRoom;
        
        Contact *contact;
        
        if ((indexPath.section == participantsSection && userParticipant && indexPath.row == 0) && !currentSearchText.length)
        {
            // oneself dedicated cell
            contact = userParticipant;
        }
        else
        {
            NSInteger index = indexPath.row;
            NSArray *participants;
            
            if (indexPath.section == participantsSection)
            {
                if (currentSearchText.length)
                {
                    participants = filteredActualParticipants;
                }
                else
                {
                    participants = actualParticipants;
                    
                    if (userParticipant)
                    {
                        index --;
                    }
                }
            }
            else
            {
                if (currentSearchText.length)
                {
                    participants = filteredInvitedParticipants;
                }
                else
                {
                    participants = invitedParticipants;
                }
            }
            
            if (index < participants.count)
            {
                contact = participants[index];
            }
        }
        
        if (contact)
        {
            [participantCell render:contact];
            
            if (contact.mxMember)
            {
                MXRoomState *roomState = self.mxRoom.dangerousSyncState;
                
                // Update member power level
                MXRoomPowerLevels *powerLevels = [roomState powerLevels];
                NSInteger powerLevel = [roomState powerLevelOfUserWithUserID:contact.mxMember.userId];
                
                RoomPowerLevel roomPowerLevel = [RoomPowerLevelHelper roomPowerLevelFrom:powerLevel];
                
                NSString *powerLevelText;
                
                switch (roomPowerLevel) {
                    case RoomPowerLevelOwner:
                        powerLevelText = [VectorL10n roomMemberPowerLevelShortOwner];
                        break;
                    case RoomPowerLevelAdmin:
                        powerLevelText = [VectorL10n roomMemberPowerLevelShortAdmin];
                        break;
                    case RoomPowerLevelModerator:
                        powerLevelText = [VectorL10n roomMemberPowerLevelShortModerator];
                        break;
                    default:
                        powerLevelText = nil;
                        break;
                }
                
                participantCell.powerLevelLabel.text = powerLevelText;
                
                // Update the contact display name by considering the current room state.
                if (contact.mxMember.userId)
                {
                    participantCell.contactDisplayNameLabel.text = [roomState.members memberName:contact.mxMember.userId];
                }
            }
        }
        
        cell = participantCell;
    }
    else
    {
        // Return a fake cell to prevent app from crashing.
        cell = [[UITableViewCell alloc] init];
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == participantsSection || indexPath.section == invitedSection)
    {
        return YES;
    }
    return NO;
}

- (void)tableView:(UITableView*)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath*)indexPath
{
    // iOS8 requires this method to enable editing (see editActionsForRowAtIndexPath).
}

#pragma mark - UITableView delegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
{
    cell.backgroundColor = ThemeService.shared.theme.backgroundColor;
    
    // Update the selected background view
    if (ThemeService.shared.theme.selectedBackgroundColor)
    {
        cell.selectedBackgroundView = [[UIView alloc] init];
        cell.selectedBackgroundView.backgroundColor = ThemeService.shared.theme.selectedBackgroundColor;
    }
    else
    {
        if (tableView.style == UITableViewStylePlain)
        {
            cell.selectedBackgroundView = nil;
        }
        else
        {
            cell.selectedBackgroundView.backgroundColor = nil;
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    CGFloat height = 0.0;
    
    if (section == invitedSection)
    {
        height = 30.0;
    }
    
    return height;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView* sectionHeader;
    
    if (section == invitedSection)
    {
        sectionHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 30)];
        sectionHeader.backgroundColor = ThemeService.shared.theme.headerBackgroundColor;
        
        CGRect frame = sectionHeader.frame;
        frame.origin.x = 20;
        frame.origin.y = 5;
        frame.size.width = sectionHeader.frame.size.width - 10;
        frame.size.height -= 10;
        UILabel *headerLabel = [[UILabel alloc] initWithFrame:frame];
        headerLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
        headerLabel.font = [UIFont boldSystemFontOfSize:15.0];
        headerLabel.backgroundColor = [UIColor clearColor];
        
        headerLabel.text = [VectorL10n roomParticipantsInvitedSection];
        
        [sectionHeader addSubview:headerLabel];
    }
    
    return sectionHeader;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 74.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Sanity check
    if (!self.mxRoom)
    {
        return;
    }
    
    Contact *contact;
    
    // oneself dedicated cell
    if ((indexPath.section == participantsSection && userParticipant && indexPath.row == 0) && !currentSearchText.length)
    {
        contact = userParticipant;
    }
    else
    {
        NSInteger index = indexPath.row;
        NSArray *participants;
        
        if (indexPath.section == participantsSection)
        {
            if (currentSearchText.length)
            {
                participants = filteredActualParticipants;
            }
            else
            {
                participants = actualParticipants;
                
                if (userParticipant)
                {
                    index --;
                }
            }
        }
        else
        {
            if (currentSearchText.length)
            {
                participants = filteredInvitedParticipants;
            }
            else
            {
                participants = invitedParticipants;
            }
        }
        
        if (index < participants.count)
        {
            contact = participants[index];
        }
    }
    
    if (contact.mxMember)
    {
        UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath:indexPath];
        [self showDetailFor:contact.mxMember from:selectedCell];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray* actions;
    
    // add the swipe to delete only on participants sections
    if (indexPath.section == participantsSection || indexPath.section == invitedSection)
    {
        actions = [[NSMutableArray alloc] init];
        
        // Patch: Force the width of the button by adding whitespace characters into the title string.
        UITableViewRowAction *leaveAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"        "  handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
            
            [self onDeleteAt:indexPath];
            
        }];
        
        leaveAction.backgroundColor = [MXKTools convertImageToPatternColor:@"remove_icon" backgroundColor:ThemeService.shared.theme.headerBackgroundColor patternSize:CGSizeMake(74, 74) resourceSize:CGSizeMake(24, 24)];
        [actions insertObject:leaveAction atIndex:0];
    }
    
    return actions;
}

#pragma mark - MXKRoomMemberDetailsViewControllerDelegate

- (void)roomMemberDetailsViewController:(MXKRoomMemberDetailsViewController *)roomMemberDetailsViewController startChatWithMemberId:(NSString *)matrixId completion:(void (^)(void))completion
{
    [[AppDelegate theDelegate] showNewDirectChat:matrixId withMatrixSession:self.mxRoom.mxSession completion:completion];
}

- (void)roomMemberDetailsViewController:(MXKRoomMemberDetailsViewController *)roomMemberDetailsViewController mention:(MXRoomMember*)member
{
    if (_delegate)
    {
        id<RoomParticipantsViewControllerDelegate> delegate = _delegate;
        
        // Withdraw the current view controller, and let the delegate mention the member
        [self withdrawViewControllerAnimated:YES completion:^{
            
            [delegate roomParticipantsViewController:self mention:member];
            
        }];
    }
}

#pragma mark - Actions

- (void)onDeleteAt:(NSIndexPath*)path
{
    NSUInteger section = path.section;
    NSUInteger row = path.row;
    
    if (section == participantsSection || section == invitedSection)
    {
        if (currentAlert)
        {
            [currentAlert dismissViewControllerAnimated:NO completion:nil];
            currentAlert = nil;
        }
        
        if (section == participantsSection && userParticipant && (0 == row) && !currentSearchText.length)
        {
            [self leaveRoom];
        }
        else
        {
            NSMutableArray *participants;
            
            if (section == participantsSection)
            {
                if (currentSearchText.length)
                {
                    participants = filteredActualParticipants;
                }
                else
                {
                    participants = actualParticipants;
                    
                    if (userParticipant)
                    {
                        row --;
                    }
                }
            }
            else
            {
                if (currentSearchText.length)
                {
                    participants = filteredInvitedParticipants;
                }
                else
                {
                    participants = invitedParticipants;
                }
            }
            
            if (row < participants.count)
            {
                Contact *contact = participants[row];
                MXWeakify(self);
                
                if (contact.mxMember)
                {
                    NSString *memberUserId = contact.mxMember.userId;
                    
                    // Kick ?
                    NSString *promptMsg = [VectorL10n roomParticipantsRemovePromptMsg:(contact ? contact.displayName : memberUserId)];
                    currentAlert = [UIAlertController alertControllerWithTitle:[VectorL10n roomParticipantsRemovePromptTitle]
                                                                       message:promptMsg
                                                                preferredStyle:UIAlertControllerStyleAlert];
                    
                    [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                                     style:UIAlertActionStyleCancel
                                                                   handler:^(UIAlertAction * action) {
                                                                       
                                                                       MXStrongifyAndReturnIfNil(self);
                                                                       self->currentAlert = nil;
                                                                       
                                                                   }]];
                    
                    [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n remove]
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * action) {
                                                                       
                                                                       MXStrongifyAndReturnIfNil(self);
                                                                       self->currentAlert = nil;
                                                                       
                                                                       [self addPendingActionMask];
                                                                       MXWeakify(self);
                                                                       [self.mxRoom kickUser:memberUserId
                                                                                      reason:nil
                                                                                     success:^{
                                                                                         
                                                                                         MXStrongifyAndReturnIfNil(self);
                                                                                         [self removePendingActionMask];
                                                                                         
                                                                                         [participants removeObjectAtIndex:row];
                                                                                         
                                                                                         // Refresh display
                                                                                         [self.tableView reloadData];
                                                                                         
                                                                                     } failure:^(NSError *error) {
                                                                                         
                                                                                         MXStrongifyAndReturnIfNil(self);
                                                                                         [self removePendingActionMask];
                                                                                         MXLogDebug(@"[RoomParticipantsVC] Kick %@ failed", memberUserId);
                                                                                         // Alert user
                                                                                         [[AppDelegate theDelegate] showErrorAsAlert:error];
                                                                                         
                                                                                     }];
                                                                       
                                                                   }]];
                }
                else if (contact.mxThirdPartyInvite)
                {
                    // This is a third-party invite
                    currentAlert = [UIAlertController alertControllerWithTitle:nil
                                                                       message:[VectorL10n roomParticipantsRemoveThirdPartyInvitePromptMsg]
                                                                preferredStyle:UIAlertControllerStyleAlert];
                    
                    [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                                     style:UIAlertActionStyleCancel
                                                                   handler:^(UIAlertAction * action) {
                                                                       
                                                                       MXStrongifyAndReturnIfNil(self);
                                                                       self->currentAlert = nil;
                                                                       
                                                                   }]];
                    
                    [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n remove]
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * action) {
                                                                       
                                                                       MXStrongifyAndReturnIfNil(self);
                                                                       self->currentAlert = nil;
                                                                       
                                                                       [self addPendingActionMask];
                                                                       MXWeakify(self);
                                                                       [self.mxRoom sendStateEventOfType:kMXEventTypeStringRoomThirdPartyInvite
                                                                                                 content:@{} stateKey:contact.mxThirdPartyInvite.token success:^(NSString *eventId) {
                                                                                                     
                                                                                                     MXStrongifyAndReturnIfNil(self);
                                                                                                     [self removePendingActionMask];
                                                                                                     
                                                                                                     [participants removeObjectAtIndex:row];
                                                                                                     
                                                                                                     // Refresh display
                                                                                                     [self.tableView reloadData];
                                                                                                     
                                                                                                 } failure:^(NSError *error) {
                                                                                                     
                                                                                                     MXStrongifyAndReturnIfNil(self);
                                                                                                     [self removePendingActionMask];
                                                                                                     MXLogDebug(@"[RoomParticipantsVC] Revoke 3pid invite failed");
                                                                                                     // Alert user
                                                                                                     [[AppDelegate theDelegate] showErrorAsAlert:error];
                                                                                                     
                                                                                                 }];
                                                                       
                                                                   }]];
                }
                
                [currentAlert mxk_setAccessibilityIdentifier:@"RoomParticipantsVCKickAlert"];
                [self presentViewController:currentAlert animated:YES completion:nil];
            }
        }
    }
}

- (void)leaveRoom {
    MXWeakify(self);
    
    [self.mxRoom isLastOwnerWithCompletionHandler:^(BOOL isLastOwner, NSError* error) {
        if (isLastOwner)
        {
            MXStrongifyAndReturnIfNil(self);
            self->currentAlert = [UIAlertController alertControllerWithTitle:[VectorL10n error]
                                                               message:[VectorL10n roomParticipantsLeaveNotAllowedForLastOwnerMsg]
                                                        preferredStyle:UIAlertControllerStyleAlert];
            
            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                             style:UIAlertActionStyleCancel
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               MXStrongifyAndReturnIfNil(self);
                                                               self->currentAlert = nil;
                                                           }]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:self->currentAlert animated:YES completion:nil];
            });
        }
        else
        {
            // Leave ?
            MXStrongifyAndReturnIfNil(self);
            NSString *title, *message;
            if (self.mxRoom.isDirect)
            {
                title = [VectorL10n roomParticipantsLeavePromptTitleForDm];
                message = [VectorL10n roomParticipantsLeavePromptMsgForDm];
            }
            else
            {
                title = [VectorL10n roomParticipantsLeavePromptTitle];
                message = [VectorL10n roomParticipantsLeavePromptMsg];
            }
            
            self->currentAlert = [UIAlertController alertControllerWithTitle:title
                                                               message:message
                                                        preferredStyle:UIAlertControllerStyleAlert];
            
            MXWeakify(self);
            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                             style:UIAlertActionStyleCancel
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               MXStrongifyAndReturnIfNil(self);
                                                               self->currentAlert = nil;
                                                               
                                                           }]];
            
            [self->currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n leave]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               MXStrongifyAndReturnIfNil(self);
                                                               self->currentAlert = nil;
                                                               
                                                               [self addPendingActionMask];
                                                               MXWeakify(self);
                                                               [self.mxRoom leave:^{
                                                                   
                                                                   MXStrongifyAndReturnIfNil(self);
                                                                   [self withdrawViewControllerAnimated:YES completion:nil];
                                                                   
                                                               } failure:^(NSError *error) {
                                                                   
                                                                   MXStrongifyAndReturnIfNil(self);
                                                                   [self removePendingActionMask];
                                                                   MXLogDebug(@"[RoomParticipantsVC] Leave room %@ failed", self.mxRoom.roomId);
                                                                   // Alert user
                                                                   [[AppDelegate theDelegate] showErrorAsAlert:error];
                                                                   
                                                               }];
                                                               
                                                           }]];
            
            [self->currentAlert mxk_setAccessibilityIdentifier:@"RoomParticipantsVCLeaveAlert"];
            [self presentViewController:self->currentAlert animated:YES completion:nil];
        }
    }];
}

- (void)onCancel:(id)sender
{
    [self withdrawViewControllerAnimated:YES completion:nil];
}

#pragma mark - UISearchBar delegate

- (void)refreshSearchBarItemsColor:(UISearchBar *)searchBar
{
    // bar tint color
    searchBar.barTintColor = searchBar.tintColor = ThemeService.shared.theme.tintColor;
    searchBar.tintColor = ThemeService.shared.theme.tintColor;
    
    // FIXME: this all seems incredibly fragile and tied to gutwrenching the current UISearchBar internals.
    
    // text color
    UITextField *searchBarTextField = searchBar.vc_searchTextField;
    searchBarTextField.textColor = ThemeService.shared.theme.textSecondaryColor;
    
    // Magnifying glass icon.
    UIImageView *leftImageView = (UIImageView *)searchBarTextField.leftView;
    leftImageView.image = [leftImageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    // remove the gray background color
    UIView *effectBackgroundTop =  [searchBarTextField valueForKey:@"_effectBackgroundTop"];
    UIView *effectBackgroundBottom =  [searchBarTextField valueForKey:@"_effectBackgroundBottom"];
    effectBackgroundTop.hidden = YES;
    effectBackgroundBottom.hidden = YES;
    
    // place holder
    searchBarTextField.textColor = ThemeService.shared.theme.searchPlaceholderColor;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    // Update search results.
    NSUInteger index;
    MXKContact *contact;
    
    searchText = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (!currentSearchText.length || [searchText hasPrefix:currentSearchText] == NO)
    {
        // Copy participants and invited participants
        filteredActualParticipants = [NSMutableArray arrayWithArray:actualParticipants];
        filteredInvitedParticipants = [NSMutableArray arrayWithArray:invitedParticipants];
        
        // Add the current user if he belongs to the room members.
        if (userParticipant)
        {
            [filteredActualParticipants addObject:userParticipant];
        }
    }
    
    currentSearchText = searchText;
    
    // Filter room participants
    if (currentSearchText.length)
    {
        for (index = 0; index < filteredActualParticipants.count;)
        {
            contact = filteredActualParticipants[index];
            if (![contact matchedWithPatterns:@[currentSearchText]])
            {
                [filteredActualParticipants removeObjectAtIndex:index];
            }
            else
            {
                index++;
            }
        }
        
        for (index = 0; index < filteredInvitedParticipants.count;)
        {
            contact = filteredInvitedParticipants[index];
            if (![contact matchedWithPatterns:@[currentSearchText]])
            {
                [filteredInvitedParticipants removeObjectAtIndex:index];
            }
            else
            {
                index++;
            }
        }
    }
    else
    {
        filteredActualParticipants = nil;
        filteredInvitedParticipants = nil;
    }
    
    // Refresh display
    [self refreshTableView];
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    searchBar.showsCancelButton = YES;
    
    return YES;
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar
{
    searchBar.showsCancelButton = NO;
    
    return YES;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // "Done" key has been pressed.
    
    // Dismiss keyboard
    [_searchBarView resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    if (currentSearchText)
    {
        currentSearchText = nil;
        filteredActualParticipants = nil;
        filteredInvitedParticipants = nil;
        
        [self refreshTableView];
    }
    
    searchBar.text = nil;
    // Leave search
    [searchBar resignFirstResponder];
}

#pragma mark - RoomParticipantsInviteCoordinatorBridgePresenterDelegate

- (void)roomParticipantsInviteCoordinatorBridgePresenterDidComplete:(RoomParticipantsInviteCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    self->invitePresenter = nil;
}

- (void)roomParticipantsInviteCoordinatorBridgePresenterDidStartLoading:(RoomParticipantsInviteCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [self addPendingActionMask];
}

- (void)roomParticipantsInviteCoordinatorBridgePresenterDidEndLoading:(RoomParticipantsInviteCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [self removePendingActionMask];
}

@end
/*
Copyright 2018-2024 New Vector Ltd.
Copyright 2017 Vector Creations Ltd
Copyright 2014 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

@import MobileCoreServices;

#import "RoomViewController.h"

#import "RoomDataSource.h"
#import "RoomBubbleCellData.h"

#import "RoomInputToolbarView.h"
#import "DisabledRoomInputToolbarView.h"

#import "RoomActivitiesView.h"

#import "AttachmentsViewController.h"

#import "EventDetailsView.h"

#import "RoomAvatarTitleView.h"
#import "ExpandedRoomTitleView.h"
#import "SimpleRoomTitleView.h"
#import "PreviewRoomTitleView.h"

#import "RoomMemberDetailsViewController.h"
#import "ContactDetailsViewController.h"

#import "SegmentedViewController.h"
#import "RoomSettingsViewController.h"

#import "RoomFilesViewController.h"

#import "RoomSearchViewController.h"

#import "UsersDevicesViewController.h"

#import "ReadReceiptsViewController.h"

#import "JitsiViewController.h"

#import "RoomEmptyBubbleCell.h"
#import "RoomMembershipExpandedBubbleCell.h"
#import "MXKRoomBubbleTableViewCell+Riot.h"

#import "AvatarGenerator.h"
#import "Tools.h"
#import "WidgetManager.h"
#import "ShareManager.h"

#import "GBDeviceInfo_iOS.h"

#import "RoomEncryptedDataBubbleCell.h"
#import "EncryptionInfoView.h"

#import "MXRoom+Riot.h"

#import "IntegrationManagerViewController.h"
#import "WidgetPickerViewController.h"
#import "StickerPickerViewController.h"

#import "EventFormatter.h"

#import "SettingsViewController.h"
#import "SecurityViewController.h"

#import "TypingUserInfo.h"

#import "MXSDKOptions.h"

#import "RoomTimelineCellProvider.h"

#import "GeneratedInterface-Swift.h"

NSNotificationName const RoomCallTileTappedNotification = @"RoomCallTileTappedNotification";
NSNotificationName const RoomGroupCallTileTappedNotification = @"RoomGroupCallTileTappedNotification";
const NSTimeInterval kResizeComposerAnimationDuration = .05;
static const int kThreadListBarButtonItemTag = 99;
static UIEdgeInsets kThreadListBarButtonItemContentInsetsNoDot;
static UIEdgeInsets kThreadListBarButtonItemContentInsetsDot;
static CGSize kThreadListBarButtonItemImageSize;

@interface RoomViewController () <UISearchBarDelegate, UIGestureRecognizerDelegate, UIScrollViewAccessibilityDelegate, RoomTitleViewTapGestureDelegate, MXKRoomMemberDetailsViewControllerDelegate, ContactsTableViewControllerDelegate, MXServerNoticesDelegate, RoomContextualMenuViewControllerDelegate,
    ReactionsMenuViewModelCoordinatorDelegate, EditHistoryCoordinatorBridgePresenterDelegate, MXKDocumentPickerPresenterDelegate, EmojiPickerCoordinatorBridgePresenterDelegate,
    ReactionHistoryCoordinatorBridgePresenterDelegate, CameraPresenterDelegate, MediaPickerCoordinatorBridgePresenterDelegate,
    RoomDataSourceDelegate, RoomCreationModalCoordinatorBridgePresenterDelegate, RoomInfoCoordinatorBridgePresenterDelegate, DialpadViewControllerDelegate, RemoveJitsiWidgetViewDelegate, VoiceMessageControllerDelegate, SpaceDetailPresenterDelegate, CompletionSuggestionCoordinatorBridgeDelegate, ThreadsCoordinatorBridgePresenterDelegate, ThreadsBetaCoordinatorBridgePresenterDelegate, MXThreadingServiceDelegate, RoomParticipantsInviteCoordinatorBridgePresenterDelegate, RoomInputToolbarViewDelegate, ComposerCreateActionListBridgePresenterDelegate>
{
    
    // The preview header
    __weak PreviewRoomTitleView *previewHeader;
    
    // The user taps on a user id contained in a message
    MXKContact *selectedContact;
    
    // List of members who are typing in the room.
    NSArray *currentTypingUsers;
    
    // Typing notifications listener.
    __weak id typingNotifListener;
    
    // The position of the first touch down event stored in case of scrolling when the expanded header is visible.
    CGPoint startScrollingPoint;
    
    // Missed discussions badge
    NSUInteger missedDiscussionsCount;
    NSUInteger missedHighlightCount;
    UILabel *missedDiscussionsBadgeLabel;
    UIView *missedDiscussionsDotView;
    
    // Potential encryption details view.
    __weak EncryptionInfoView *encryptionInfoView;
    
    // The list of unknown devices that prevent outgoing messages from being sent
    MXUsersDevicesMap<MXDeviceInfo*> *unknownDevices;
    
    // Observe kAppDelegateDidTapStatusBarNotification to handle tap on clock status bar.
    __weak id kAppDelegateDidTapStatusBarNotificationObserver;
    
    // Observe kAppDelegateNetworkStatusDidChangeNotification to handle network status change.
    __weak id kAppDelegateNetworkStatusDidChangeNotificationObserver;

    // Observers to manage MXSession state (and sync errors)
    __weak id kMXSessionStateDidChangeObserver;

    // Observers to manage ongoing conference call banner
    __weak id kMXCallStateDidChangeObserver;
    __weak id kMXCallManagerConferenceStartedObserver;
    __weak id kMXCallManagerConferenceFinishedObserver;

    // Observers to manage widgets
    __weak id kMXKWidgetManagerDidUpdateWidgetObserver;
    
    // Observer kMXRoomSummaryDidChangeNotification to keep updated the missed discussion count
    __weak id mxRoomSummaryDidChangeObserver;

    // Observer for removing the re-request explanation/waiting dialog
    __weak id mxEventDidDecryptNotificationObserver;
    
    // The table view cell in which the read marker is displayed (nil by default).
    MXKRoomBubbleTableViewCell *readMarkerTableViewCell;
    
    // Tell whether the view controller is appeared or not.
    BOOL isAppeared;
    
    // A flag indicating whether a room has been left
    BOOL isRoomLeft;
    
    // The last known frame of the view used to detect whether size-related layout change is needed
    CGRect lastViewBounds;
    
    // Tell whether the room has a Jitsi call or not.
    BOOL hasJitsiCall;
    
    // The right bar button items back up.
    NSArray<UIBarButtonItem *> *rightBarButtonItems;

    // Observe kThemeServiceDidChangeThemeNotification to handle user interface theme change.
    __weak id kThemeServiceDidChangeThemeNotificationObserver;
    
    // Observe URL preview updates to refresh cells.
    __weak id URLPreviewDidUpdateNotificationObserver;
    
    // Listener for `m.room.tombstone` event type
    __weak id tombstoneEventNotificationsListener;

    // Homeserver notices
    MXServerNotices *serverNotices;
    
    // Formatted body parser for events
    FormattedBodyParser *formattedBodyParser;
    
    // Time to display notification content in the timeline
    MXTaskProfile *notificationTaskProfile;
    
    // Observe kMXEventTypeStringRoomMember events
    __weak id roomMemberEventListener;
}

@property (nonatomic, strong) RemoveJitsiWidgetView *removeJitsiWidgetView;


@property (nonatomic, strong) RoomContextualMenuViewController *roomContextualMenuViewController;
@property (nonatomic, strong) RoomContextualMenuPresenter *roomContextualMenuPresenter;
@property (nonatomic, strong) MXKErrorAlertPresentation *errorPresenter;
@property (nonatomic, strong) NSAttributedString *textMessageBeforeEditing;
@property (nonatomic, strong) NSString *htmlTextBeforeEditing;
@property (nonatomic, strong) EditHistoryCoordinatorBridgePresenter *editHistoryPresenter;
@property (nonatomic, strong) MXKDocumentPickerPresenter *documentPickerPresenter;
@property (nonatomic, strong) EmojiPickerCoordinatorBridgePresenter *emojiPickerCoordinatorBridgePresenter;
@property (nonatomic, strong) ReactionHistoryCoordinatorBridgePresenter *reactionHistoryCoordinatorBridgePresenter;
@property (nonatomic, strong) CameraPresenter *cameraPresenter;
@property (nonatomic, strong) MediaPickerCoordinatorBridgePresenter *mediaPickerPresenter;
@property (nonatomic, strong) RoomMessageURLParser *roomMessageURLParser;
@property (nonatomic, strong) RoomCreationModalCoordinatorBridgePresenter *roomCreationModalCoordinatorBridgePresenter;
@property (nonatomic, strong) RoomInfoCoordinatorBridgePresenter *roomInfoCoordinatorBridgePresenter;
@property (nonatomic, strong) CustomSizedPresentationController *customSizedPresentationController;
@property (nonatomic, strong) RoomParticipantsInviteCoordinatorBridgePresenter *participantsInvitePresenter;
@property (nonatomic, strong) ThreadsCoordinatorBridgePresenter *threadsBridgePresenter;
@property (nonatomic, strong) ThreadsBetaCoordinatorBridgePresenter *threadsBetaBridgePresenter;
@property (nonatomic, strong) SlidingModalPresenter *threadsNoticeModalPresenter;
@property (nonatomic, strong) ComposerCreateActionListBridgePresenter *composerCreateActionListBridgePresenter;
@property (nonatomic, getter=isActivitiesViewExpanded) BOOL activitiesViewExpanded;
@property (nonatomic, getter=isScrollToBottomHidden) BOOL scrollToBottomHidden;
@property (nonatomic, getter=isMissedDiscussionsBadgeHidden) BOOL missedDiscussionsBadgeHidden;

@property (nonatomic, strong) VoiceMessageController *voiceMessageController;
@property (nonatomic, strong) SpaceDetailPresenter *spaceDetailPresenter;

@property (nonatomic, strong) ShareManager *shareManager;
@property (nonatomic, strong) EventMenuBuilder *eventMenuBuilder;

@property (nonatomic, strong) CompletionSuggestionCoordinatorBridge *completionSuggestionCoordinator;
@property (nonatomic, weak) IBOutlet UIView *completionSuggestionContainerView;

@property (nonatomic, readwrite) RoomDisplayConfiguration *displayConfiguration;

// The direct chat target user. The room timeline is presented without an actual room until the direct chat is created
@property (nonatomic, nullable, strong) MXUser *directChatTargetUser;

// When layout of the screen changes (e.g. height), we no longer know whether
// to autoscroll to the bottom again or not. Instead we need to capture the
// scroll state just before the layout change, and restore it after the layout.
@property (nonatomic) BOOL wasScrollAtBottomBeforeLayout;

// Check if we should wait for other participants
@property (nonatomic, readonly) BOOL shouldWaitForOtherParticipants;

@end

@implementation RoomViewController
@synthesize roomPreviewData;

#pragma mark - Class methods

+ (void)initialize
{
    kThreadListBarButtonItemContentInsetsNoDot = UIEdgeInsetsMake(0, 8, 0, 8);
    kThreadListBarButtonItemContentInsetsDot = UIEdgeInsetsMake(0, 8, 6, 8);
    kThreadListBarButtonItemImageSize = CGSizeMake(21, 21);
}

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass(self.class)
                          bundle:[NSBundle bundleForClass:self.class]];
}

+ (instancetype)roomViewController
{
    RoomViewController *controller = [[[self class] alloc] initWithNibName:NSStringFromClass(self.class)
                                                                    bundle:[NSBundle bundleForClass:self.class]];
    controller.displayConfiguration = [RoomDisplayConfiguration default];
    return controller;
}

+ (instancetype)instantiateWithConfiguration:(RoomDisplayConfiguration *)configuration
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
    NSString *storyboardId = [NSString stringWithFormat:@"%@StoryboardId", self.className];
    RoomViewController *controller = [storyboard instantiateViewControllerWithIdentifier:storyboardId];
    controller.displayConfiguration = configuration;
    return controller;
}

+ (NSString *)className
{
    NSString *result = NSStringFromClass(self.class);
    if ([result containsString:@"."])
    {
        result = [result componentsSeparatedByString:@"."].lastObject;
    }
    return result;
}

#pragma mark -

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        // Disable auto join
        self.autoJoinInvitedRoom = NO;
        
        // Disable auto scroll to bottom on keyboard presentation
        self.scrollHistoryToTheBottomOnKeyboardPresentation = NO;
    }
    
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        // Disable auto join
        self.autoJoinInvitedRoom = NO;
        
        // Disable auto scroll to bottom on keyboard presentation
        self.scrollHistoryToTheBottomOnKeyboardPresentation = NO;
    }
    
    return self;
}

#pragma mark -

- (void)finalizeInit
{
    [super finalizeInit];

    [self registerPillAttachmentViewProviderIfNeeded];
    self.resizeComposerAnimationDuration = kResizeComposerAnimationDuration;
    
    // Setup `MXKViewControllerHandling` properties
    self.enableBarTintColorStatusChange = NO;
    self.rageShakeManager = [RageShakeManager sharedManager];
    formattedBodyParser = [FormattedBodyParser new];
    self.eventMenuBuilder = [EventMenuBuilder new];
    
    _showMissedDiscussionsBadge = YES;
    _scrollToBottomHidden = YES;
    _isWaitingForOtherParticipants = NO;
    
    // Listen to the event sent state changes
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventDidChangeSentState:) name:kMXEventDidChangeSentStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventDidChangeIdentifier:) name:kMXEventDidChangeIdentifierNotification object:nil];
    
    // Show / hide actions button in document preview according BuildSettings
    self.allowActionsInDocumentPreview = BuildSettings.messageDetailsAllowShare;
    
    _voiceMessageController = [[VoiceMessageController alloc] initWithThemeService:ThemeService.shared mediaServiceProvider:VoiceMessageMediaServiceProvider.sharedProvider];
    self.voiceMessageController.delegate = self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Register first customized cell view classes used to render bubbles
    [[RoomTimelineConfiguration shared].currentStyle.cellProvider registerCellsForTableView:self.bubblesTableView];
    
    [self vc_removeBackTitle];
    
    // Display leftBarButtonItems or leftBarButtonItem to the right of the Back button
    self.navigationItem.leftItemsSupplementBackButton = YES;
    
    [self setupRemoveJitsiWidgetRemoveView];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // Replace the default input toolbar view.
        // Note: this operation will force the layout of subviews. That is why cell view classes must be registered before.
        [self updateRoomInputToolbarViewClassIfNeeded];
    });
    
    // set extra area
    [self setRoomActivitiesViewClass:RoomActivitiesView.class];
    
    // Custom the attachmnet viewer
    [self setAttachmentsViewerClass:AttachmentsViewController.class];
    
    // Custom the event details view
    [self setEventDetailsViewClass:EventDetailsView.class];
    
    // Prepare missed dicussion badge (if any)
    self.showMissedDiscussionsBadge = _showMissedDiscussionsBadge;

    // Refresh the waiting for other participants state
    [self refreshWaitForOtherParticipantsState];

    // Set up the room title view according to the data source (if any)
    [self refreshRoomTitle];
    
    // Refresh tool bar if the room data source is set.
    if (self.roomDataSource)
    {
        [self refreshRoomInputToolbar];
    }
    
    self.roomContextualMenuPresenter = [RoomContextualMenuPresenter new];
    self.errorPresenter = [MXKErrorAlertPresentation new];
    self.roomMessageURLParser = [RoomMessageURLParser new];
    
    self.jumpToLastUnreadLabel.text = [VectorL10n roomJumpToFirstUnread];
    
    MXWeakify(self);
    
    // Observe user interface theme change.
    kThemeServiceDidChangeThemeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kThemeServiceDidChangeThemeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        [self userInterfaceThemeDidChange];
        
    }];
    
    [self userInterfaceThemeDidChange];
    
    // Observe URL preview updates.
    [self registerURLPreviewNotifications];
    
    [self setupActions];
    
    [self setupCompletionSuggestionViewIfNeeded];
    
    [self.topBannersStackView vc_removeAllSubviews];
}

- (void)userInterfaceThemeDidChange
{
    // Consider the main navigation controller if the current view controller is embedded inside a split view controller.
    UINavigationController *mainNavigationController = self.navigationController;
    if (self.splitViewController.isCollapsed && self.splitViewController.viewControllers.count)
    {
        mainNavigationController = self.splitViewController.viewControllers.firstObject;
    }
    
    [ThemeService.shared.theme applyStyleOnNavigationBar:self.navigationController.navigationBar];
    if (mainNavigationController)
    {
        [ThemeService.shared.theme applyStyleOnNavigationBar:mainNavigationController.navigationBar];
    }
    
    // Keep navigation bar transparent in some cases
    if (!self.previewHeaderContainer.hidden)
    {
        self.navigationController.navigationBar.translucent = YES;
        mainNavigationController.navigationBar.translucent = YES;
    }
    
    [self.inputToolbarView customizeViewRendering];
    
    self.activityIndicator.backgroundColor = ThemeService.shared.theme.overlayBackgroundColor;
    
    [self.removeJitsiWidgetView updateWithTheme:ThemeService.shared.theme];
    
    // Prepare jump to last unread banner
    self.jumpToLastUnreadImageView.tintColor = ThemeService.shared.theme.tintColor;
    self.jumpToLastUnreadLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
    
    self.previewHeaderContainer.backgroundColor = ThemeService.shared.theme.headerBackgroundColor;
    
    // Check the table view style to select its bg color.
    self.bubblesTableView.backgroundColor = ((self.bubblesTableView.style == UITableViewStylePlain) ? ThemeService.shared.theme.backgroundColor : ThemeService.shared.theme.headerBackgroundColor);
    self.bubblesTableView.separatorColor = ThemeService.shared.theme.lineBreakColor;
    self.view.backgroundColor = self.bubblesTableView.backgroundColor;
    
    if (self.bubblesTableView.dataSource)
    {
        [self.bubblesTableView reloadData];
    }
    
    [self.scrollToBottomButton vc_addShadowWithColor:ThemeService.shared.theme.shadowColor
                                              offset:CGSizeMake(0, 4)
                                              radius:6
                                             opacity:0.2];

    self.inputBackgroundView.backgroundColor = [ThemeService.shared.theme.backgroundColor colorWithAlphaComponent:0.98];
    
    if (ThemeService.shared.isCurrentThemeDark)
    {
        [self.scrollToBottomButton setImage:AssetImages.scrolldownDark.image forState:UIControlStateNormal];

        self.jumpToLastUnreadBanner.backgroundColor = ThemeService.shared.theme.colors.navigation;
        [self.jumpToLastUnreadBanner vc_removeShadow];
        self.resetReadMarkerButton.tintColor = ThemeService.shared.theme.colors.quarterlyContent;
        if (self.maximisedToolbarDimmingView) {
            self.maximisedToolbarDimmingView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.29];
        }
    }
    else
    {
        [self.scrollToBottomButton setImage:AssetImages.scrolldown.image forState:UIControlStateNormal];
        
        self.jumpToLastUnreadBanner.backgroundColor = ThemeService.shared.theme.colors.background;
        [self.jumpToLastUnreadBanner vc_addShadowWithColor:ThemeService.shared.theme.shadowColor
                                                    offset:CGSizeMake(0, 4)
                                                    radius:8
                                                   opacity:0.1];
        self.resetReadMarkerButton.tintColor = ThemeService.shared.theme.colors.tertiaryContent;
        if (self.maximisedToolbarDimmingView) {
            self.maximisedToolbarDimmingView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.12];
        }
    }
    
    self.scrollToBottomBadgeLabel.badgeColor = ThemeService.shared.theme.tintColor;
    
    [self updateThreadListBarButtonBadgeWith:self.mainSession.threadingService];
    
    [self.liveLocationSharingBannerView updateWithTheme:ThemeService.shared.theme];
    
    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return ThemeService.shared.theme.statusBarStyle;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Refresh the room title view
    [self refreshRoomTitle];
    
    //  refresh remove Jitsi widget view
    [self refreshRemoveJitsiWidgetView];
    
    // Refresh tool bar if the room data source is set.
    if (self.roomDataSource)
    {
        [self refreshRoomInputToolbar];
    }
    
    // Reset typing notification in order to remove the allocated space
    if ([self.roomDataSource isKindOfClass:RoomDataSource.class])
    {
        [((RoomDataSource*)self.roomDataSource) resetTypingNotification];
    }

    [self listenTypingNotifications];
    [self listenCallNotifications];
    [self listenWidgetNotifications];
    [self listenTombstoneEventNotifications];
    [self listenMXSessionStateChangeNotifications];
    
    MXWeakify(self);
    
    // Observe kAppDelegateDidTapStatusBarNotification.
    kAppDelegateDidTapStatusBarNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kAppDelegateDidTapStatusBarNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        [self setBubbleTableViewContentOffset:CGPointMake(-self.bubblesTableView.adjustedContentInset.left, -self.bubblesTableView.adjustedContentInset.top) animated:YES];
    }];
    
    if ([self.roomDataSource.roomId isEqualToString:[LegacyAppDelegate theDelegate].lastNavigatedRoomIdFromPush])
    {
        [self startActivityIndicator];
        [self.roomDataSource reload];
        [LegacyAppDelegate theDelegate].lastNavigatedRoomIdFromPush = nil;
        
        notificationTaskProfile = [MXSDKOptions.sharedInstance.profiler startMeasuringTaskWithName:MXTaskProfileNameNotificationsOpenEvent];
    }
    
    [self updateTopBanners];
    
    self.bubblesTableView.clipsToBounds = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // hide action
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    [self removeTypingNotificationsListener];
    
    if (self.customizedRoomDataSource)
    {
        // Cancel potential selected event (to leave edition mode)
        if (self.customizedRoomDataSource.selectedEventId)
        {
            [self cancelEventSelection];
        }
    }
    [self cancelEventHighlight];
    
    // Hide preview header to restore navigation bar settings
    [self showPreviewHeader:NO];
    
    if (kAppDelegateDidTapStatusBarNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kAppDelegateDidTapStatusBarNotificationObserver];
        kAppDelegateDidTapStatusBarNotificationObserver = nil;
    }
    
    [self removeCallNotificationsListeners];
    [self removeWidgetNotificationsListeners];
    [self removeTombstoneEventNotificationsListener];
    [self removeMXSessionStateChangeNotificationsListener];
    
    // Re-enable the read marker display, and disable its update.
    self.roomDataSource.showReadMarker = YES;
    self.updateRoomReadMarker = NO;
    isAppeared = NO;
    
    [VoiceMessageMediaServiceProvider.sharedProvider pauseAllServices];
    [VoiceBroadcastRecorderProvider.shared pauseRecording];
    [VoiceBroadcastPlaybackProvider.shared pausePlaying];
    
    // Stop the loading indicator even if the session is still in progress
    [self stopLoadingUserIndicator];
    
    [self setMaximisedToolbarIsHiddenIfNeeded: YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Screen tracking
    MXRoomSummary *summary = [self.mainSession roomWithRoomId:self.roomDataSource.roomId].summary;
    if (!summary || !summary.isJoined)
    {
        [AnalyticsScreenTracker trackScreen: AnalyticsScreenRoomPreview];
    }
    else
    {
        [AnalyticsScreenTracker trackScreen: AnalyticsScreenRoom];
    }

    isAppeared = YES;
    [self checkReadMarkerVisibility];
    
    if (self.roomDataSource)
    {
        // Set visible room id
        [AppDelegate theDelegate].visibleRoomId = self.roomDataSource.roomId;
    }
    
    MXWeakify(self);
    
    // Observe network reachability
    kAppDelegateNetworkStatusDidChangeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kAppDelegateNetworkStatusDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        [self refreshActivitiesViewDisplay];
        
    }];
    [self refreshActivitiesViewDisplay];
    [self refreshJumpToLastUnreadBannerDisplay];
    
    // Observe missed notifications
    mxRoomSummaryDidChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomSummaryDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        MXRoomSummary *roomSummary = notif.object;
        
        if ([roomSummary.roomId isEqualToString:self.roomDataSource.roomId])
        {
            [self refreshMissedDiscussionsCount:NO];
        }
    }];
    [self refreshMissedDiscussionsCount:YES];
    self.keyboardHeight = MAX(self.keyboardHeight, 0);
    
    if (hasJitsiCall &&
        !self.isRoomHavingAJitsiCall)
    {
        //  the room had a Jitsi call before, but not now
        hasJitsiCall = NO;
        [self reloadBubblesTable:YES];
    }
    
    self.showSettingsInitially = NO;

    if (!RiotSettings.shared.threadsNoticeDisplayed && RiotSettings.shared.enableThreads)
    {
        [self showThreadsNotice];
    }

    if (self.saveProgressTextInput && self.roomDataSource)
    {
        // Retrieve the potential message partially typed during last room display.
        // Note: We have to wait for viewDidAppear before updating growingTextView (viewWillAppear is too early)
        [self.inputToolbarView setPartialContent:self.roomDataSource.partialAttributedTextMessage];
    }
    
    [self setMaximisedToolbarIsHiddenIfNeeded: NO];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // Hide contextual menu if needed
    [self hideContextualMenuAnimated:NO];
    
    // Reset visible room id
    [AppDelegate theDelegate].visibleRoomId = nil;
    
    if (kAppDelegateNetworkStatusDidChangeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kAppDelegateNetworkStatusDidChangeNotificationObserver];
        kAppDelegateNetworkStatusDidChangeNotificationObserver = nil;
    }
    
    if (mxRoomSummaryDidChangeObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:mxRoomSummaryDidChangeObserver];
        mxRoomSummaryDidChangeObserver = nil;
    }
    
    if (mxEventDidDecryptNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:mxEventDidDecryptNotificationObserver];
        mxEventDidDecryptNotificationObserver = nil;
    }
        
    if (self.isRoomHavingAJitsiCall)
    {
        hasJitsiCall = YES;
        [self reloadBubblesTable:YES];
    }
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.wasScrollAtBottomBeforeLayout = self.isBubblesTableScrollViewAtTheBottom;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    BOOL didViewChangeBounds = !CGRectEqualToRect(lastViewBounds, self.view.bounds);
    lastViewBounds = self.view.bounds;
    
    UIEdgeInsets contentInset = self.bubblesTableView.contentInset;
    contentInset.bottom = self.view.safeAreaInsets.bottom;
    self.bubblesTableView.contentInset = contentInset;
    
    // Check here whether a subview has been added or removed
    if (encryptionInfoView)
    {
        if (!encryptionInfoView.superview)
        {
            // Reset
            encryptionInfoView = nil;
            
            // Reload the full table to take into account a potential change on a device status.
            [self.bubblesTableView reloadData];
        }
    }
    
    if (eventDetailsView)
    {
        if (!eventDetailsView.superview)
        {
            // Reset
            eventDetailsView = nil;
        }
    }
    
    // Check whether the preview header is visible
    if (previewHeader)
    {
        if (previewHeader.mainHeaderContainer.isHidden)
        {
            // Check here the main background height to display a correct navigation bar background.
            CGRect frame = self.navigationController.navigationBar.frame;
            
            CGFloat mainHeaderBackgroundHeight = frame.size.height + (frame.origin.y > 0 ? frame.origin.y : 0);
            
            if (previewHeader.mainHeaderBackgroundHeightConstraint.constant != mainHeaderBackgroundHeight)
            {
                previewHeader.mainHeaderBackgroundHeightConstraint.constant = mainHeaderBackgroundHeight;
                
                // Force the layout of previewHeader to update the position of 'bottomBorderView' which
                // is used to define the actual height of the preview container.
                [previewHeader layoutIfNeeded];
            }
        }
        
        self.edgesForExtendedLayout = UIRectEdgeAll;
        
        // Adjust the top constraint of the bubbles table
        CGRect frame = previewHeader.bottomBorderView.frame;
        self.previewHeaderContainerHeightConstraint.constant = frame.origin.y + frame.size.height;
        
        self.bubblesTableViewTopConstraint.constant = self.previewHeaderContainerHeightConstraint.constant - self.bubblesTableView.adjustedContentInset.top;
    }
    else
    {
        // In non expanded header mode, the navigation bar is opaque
        // The table view must not display behind it
        self.edgesForExtendedLayout = UIRectEdgeLeft | UIRectEdgeBottom | UIRectEdgeRight;
    }
    
    // re-scroll to the bottom, if at bottom before the most recent layout
    if (self.wasScrollAtBottomBeforeLayout && didViewChangeBounds)
    {
        self.wasScrollAtBottomBeforeLayout = NO;
        [self scrollBubblesTableViewToBottomAnimated:NO];
    }
    
    [self refreshMissedDiscussionsCount:YES];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator
{
    if ([self.titleView isKindOfClass:RoomTitleView.class])
    {
        RoomTitleView *roomTitleView = (RoomTitleView*)self.titleView;
        if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation))
        {
            [roomTitleView updateLayoutForOrientation:UIInterfaceOrientationPortrait];
        }
        else
        {
            [roomTitleView updateLayoutForOrientation:UIInterfaceOrientationLandscapeLeft];
        }
    }

    // Hide the expanded header or the preview in case of iPad and iPhone 6 plus.
    // On these devices, the display mode of the splitviewcontroller may change during screen rotation.
    // It may correspond to an overlay mode in portrait and a side-by-side mode in landscape.
    // This display mode change involves a change at the navigation bar level.
    // If we don't hide the header, the navigation bar is in a wrong state after rotation. FIXME: Find a way to keep visible the header on rotation.
    if ([GBDeviceInfo deviceInfo].family == GBDeviceFamilyiPad || [GBDeviceInfo deviceInfo].displayInfo.display >= GBDeviceDisplay5p5Inch)
    {
        // Hide the preview header (if any) before rotating (It will be restored by `refreshRoomTitle` call if this is still a room preview).
        [self showPreviewHeader:NO];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((coordinator.transitionDuration + 0.5) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            // Let [self refreshRoomTitle] refresh this title view correctly
            [self refreshRoomTitle];
            
        });
    }
    else if (previewHeader)
    {
        // Refresh here the preview header according to the coming screen orientation.
        
        // Retrieve the affine transform indicating the amount of rotation being applied to the interface.
        // This transform is the identity transform when no rotation is applied.
        // Otherwise, it is a transform that applies a 90 degree, -90 degree, or 180 degree rotation.
        CGAffineTransform transform = coordinator.targetTransform;
        
        // Consider here only the transform that applies a +/- 90 degree.
        if (transform.b * transform.c == -1)
        {
            UIInterfaceOrientation currentScreenOrientation = [[UIApplication sharedApplication] statusBarOrientation];
            BOOL isLandscapeOriented = YES;
            
            switch (currentScreenOrientation)
            {
                case UIInterfaceOrientationLandscapeRight:
                case UIInterfaceOrientationLandscapeLeft:
                {
                    // We leave here landscape orientation
                    isLandscapeOriented = NO;
                    break;
                }
                default:
                    break;
            }
            
            [self refreshPreviewHeader:isLandscapeOriented];
        }
    }
    else
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((coordinator.transitionDuration + 0.5) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            // Refresh the room title at the end of the transition to take into account the potential changes during the transition.
            // For example the display of a preview header is ignored during transition.
            [self refreshRoomTitle];
            
        });
    }
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

#pragma mark - Accessibility

// Handle scrolling when VoiceOver is on because it does not work well if we let the system do:
// VoiceOver loses the focus on the tableview
- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)direction
{
    BOOL canScroll = YES;
    
    // Scroll by one page
    CGFloat tableViewHeight = self.bubblesTableView.frame.size.height;
    
    CGPoint offset = self.bubblesTableView.contentOffset;
    switch (direction)
    {
        case UIAccessibilityScrollDirectionUp:
            offset.y -= tableViewHeight;
            break;
            
        case UIAccessibilityScrollDirectionDown:
            offset.y += tableViewHeight;
            break;
            
        default:
            break;
    }
    
    if (offset.y < 0 && ![self.roomDataSource.timeline canPaginate:MXTimelineDirectionBackwards])
    {
        // Can't paginate more. Let's stick on the first item
        UIView *focusedView = [self firstCellWithAccessibilityDataInCells:self.bubblesTableView.visibleCells.objectEnumerator];
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, focusedView);
        canScroll = NO;
    }
    else if (offset.y > self.bubblesTableView.contentSize.height - tableViewHeight
             && ![self.roomDataSource.timeline canPaginate:MXTimelineDirectionForwards])
    {
        // Can't paginate more. Let's stick on the last item with accessibility
        UIView *focusedView = [self firstCellWithAccessibilityDataInCells:self.bubblesTableView.visibleCells.reverseObjectEnumerator];
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, focusedView);
        canScroll = NO;
    }
    else
    {
        // Disable VoiceOver while scrolling
        self.bubblesTableView.accessibilityElementsHidden = YES;
        
        [self setBubbleTableViewContentOffset:offset animated:NO];
        
        NSEnumerator<UITableViewCell*> *cells;
        if (direction == UIAccessibilityScrollDirectionUp)
        {
            cells = self.bubblesTableView.visibleCells.objectEnumerator;
        }
        else
        {
            cells = self.bubblesTableView.visibleCells.reverseObjectEnumerator;
        }
        UIView *cell = [self firstCellWithAccessibilityDataInCells:cells];
        
        self.bubblesTableView.accessibilityElementsHidden = NO;
        
        // Force VoiceOver to focus on a visible item
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, cell);
    }
    
    // If we cannot scroll, let VoiceOver indicates the border
    return canScroll;
}

- (UIView*)firstCellWithAccessibilityDataInCells:(NSEnumerator<UITableViewCell*>*)cells
{
    UIView *view;
    
    for (UITableViewCell *cell in cells)
    {
        if (![cell isKindOfClass:[RoomEmptyBubbleCell class]])
        {
            view = cell;
            break;
        }
    }
    
    return view;
}


#pragma mark - Override MXKRoomViewController

- (void)addMatrixSession:(MXSession *)mxSession
{
    [super addMatrixSession:mxSession];
    
    [mxSession.threadingService addDelegate:self];
    [self updateThreadListBarButtonBadgeWith:mxSession.threadingService];
}

- (void)removeMatrixSession:(MXSession *)mxSession
{
    [mxSession.threadingService removeDelegate:self];
    
    [super removeMatrixSession:mxSession];
}

- (void)onMatrixSessionChange
{
    [super onMatrixSessionChange];
    
    // Re-enable the read marker display, and disable its update.
    self.roomDataSource.showReadMarker = YES;
    self.updateRoomReadMarker = NO;
}

#pragma mark - Loading indicators

- (BOOL)providesCustomActivityIndicator {
    return YES;
}

// Override of a legacy method to determine whether to use a newer implementation instead.
// Will be removed in the future https://github.com/vector-im/element-ios/issues/5608
- (void)startActivityIndicator {
    [self.delegate roomViewControllerDidStartLoading:self];
}

// Override of a legacy method to determine whether to use a newer implementation instead.
// Will be removed in the future https://github.com/vector-im/element-ios/issues/5608
- (void)stopActivityIndicator
{
    if (notificationTaskProfile)
    {
        // Consider here we have displayed the message corresponding to the notification
        [MXSDKOptions.sharedInstance.profiler stopMeasuringTaskWithProfile:notificationTaskProfile];
        notificationTaskProfile = nil;
    }
    // The legacy super implementation of `stopActivityIndicator` contains a number of checks grouped under `canStopActivityIndicator`
    // to determine whether the indicator can be stopped or not (and the method should thus rather be called `stopActivityIndicatorIfPossible`).
    // Since the newer indicators are not calling super implementation, the check for `canStopActivityIndicator` has to be performed manually.
    if ([self canStopActivityIndicator]) {
        [self stopLoadingUserIndicator];
    }
}

- (void)stopLoadingUserIndicator
{
    [self.delegate roomViewControllerDidStopLoading:self];
}

- (void)displayRoom:(MXKRoomDataSource *)dataSource
{
    // Remove potential preview Data
    if (roomPreviewData)
    {
        roomPreviewData = nil;
        [self removeMatrixSession:self.mainSession];
    }
    
    // Set potential discussion target user to nil, now use the dataSource to populate the view
    self.directChatTargetUser = nil;
    
    // Enable the read marker display, and disable its update.
    dataSource.showReadMarker = YES;
    self.updateRoomReadMarker = NO;
    
    [super displayRoom:dataSource];
    
    self.customizedRoomDataSource = nil;
    
    if (self.roomDataSource)
    {
        [self listenToServerNotices];
        
        self.eventsAcknowledgementEnabled = YES;
        
        // Store ref on customized room data source
        if ([dataSource isKindOfClass:RoomDataSource.class])
        {
            self.customizedRoomDataSource = (RoomDataSource*)dataSource;
        }
        
        // Set room title view
        [self refreshRoomTitle];
        
        // Stop any pending voice broadcast if needed
        [self stopUncompletedVoiceBroadcastIfNeeded];
    }
    else
    {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
    
    [self refreshRoomInputToolbar];
    
    [VoiceMessageMediaServiceProvider.sharedProvider setCurrentRoomSummary:dataSource.room.summary];
    _voiceMessageController.roomId = dataSource.roomId;
    
    _completionSuggestionCoordinator = [[CompletionSuggestionCoordinatorBridge alloc] initWithMediaManager:self.roomDataSource.mxSession.mediaManager
                                                                                          room:dataSource.room
                                                                                        userID:self.roomDataSource.mxSession.myUserId];
    _completionSuggestionCoordinator.delegate = self;
    
    [self setupCompletionSuggestionViewIfNeeded];

    [self updateRoomInputToolbarViewClassIfNeeded];
    
    [self updateTopBanners];
}

- (void)onRoomDataSourceReady
{
    // Handle here invitation
    if (self.roomDataSource.room.summary.membership == MXMembershipInvite)
    {
        self.navigationItem.rightBarButtonItem.enabled = NO;
        
        // Show preview header
        [self showPreviewHeader:YES];
    }
    
    [super onRoomDataSourceReady];
}

- (void)updateViewControllerAppearanceOnRoomDataSourceState
{
    [super updateViewControllerAppearanceOnRoomDataSourceState];
    
    if (self.isRoomPreview)
    {
        self.navigationItem.rightBarButtonItem.enabled = NO;
        
        // Remove input tool bar if any
        if (self.inputToolbarView)
        {
            [super setRoomInputToolbarViewClass:nil];
        }
        
        if (previewHeader)
        {
            previewHeader.mxRoom = self.roomDataSource.room;
            
            // Force the layout of subviews (some constraints may have been updated)
            [self forceLayoutRefresh];
        }
    }
    else if (self.isNewDirectChat)
    {
        [self refreshRoomInputToolbar];
    }
    else
    {
        [self showPreviewHeader:NO];
        
        self.navigationItem.rightBarButtonItem.enabled = (self.roomDataSource != nil);
        
        self.titleView.editable = NO;
        
        if (self.roomDataSource)
        {
            // Update the input toolbar class and update the layout
            [self updateRoomInputToolbarViewClassIfNeeded];
            
            self.inputToolbarView.hidden = (self.roomDataSource.state != MXKDataSourceStateReady);
            
            // Restore room activities view if none
            if (!self.activitiesView)
            {
                // And the extra area
                [self setRoomActivitiesViewClass:RoomActivitiesView.class];
            }
        }
    }
}

- (void)leaveRoomOnEvent:(MXEvent*)event
{
    // Force a simple title view initialised with the current room before leaving actually the room.
    [self setRoomTitleViewClass:SimpleRoomTitleView.class];
    self.titleView.editable = NO;
    self.titleView.mxRoom = self.roomDataSource.room;
    
    // Hide the potential read marker banner.
    self.jumpToLastUnreadBannerContainer.hidden = YES;
    
    [super leaveRoomOnEvent:event];
    [self notifyDelegateOnLeaveRoomIfNecessary];
}


+ (Class) mainToolbarClass
{
    if (RiotSettings.shared.enableWysiwygComposer)
    {
        return WysiwygInputToolbarView.class;
    }
    else
    {
        return RoomInputToolbarView.class;
    }
}

// Set the input toolbar according to the current display
- (void)updateRoomInputToolbarViewClassIfNeeded
{
    Class roomInputToolbarViewClass = [RoomViewController mainToolbarClass];

    // If RTE is enabled, delay the toolbar setup until `completionSuggestionCoordinator` is ready.
    if (roomInputToolbarViewClass == WysiwygInputToolbarView.class && _completionSuggestionCoordinator == nil)
    {
        return;
    }
    
    BOOL shouldDismissContextualMenu = NO;
    
    // Check the user has enough power to post message
    if (self.roomDataSource.roomState)
    {
        MXRoomPowerLevels *powerLevels = self.roomDataSource.roomState.powerLevels;
        NSInteger userPowerLevel = [self.roomDataSource.roomState powerLevelOfUserWithUserID:self.mainSession.myUser.userId];
        
        BOOL canSend = (userPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsMessage:kMXEventTypeStringRoomMessage]);
        BOOL isRoomObsolete = self.roomDataSource.roomState.isObsolete;
        BOOL isResourceLimitExceeded = [self.roomDataSource.mxSession.syncError.errcode isEqualToString:kMXErrCodeStringResourceLimitExceeded];        
        
        if (isRoomObsolete || isResourceLimitExceeded || _isWaitingForOtherParticipants)
        {
            roomInputToolbarViewClass = nil;
            shouldDismissContextualMenu = YES;
        }
        else if (!canSend)
        {
            roomInputToolbarViewClass = DisabledRoomInputToolbarView.class;
            shouldDismissContextualMenu = YES;
        }
    }
    
    // Do not show toolbar in case of preview
    if (self.isRoomPreview)
    {
        roomInputToolbarViewClass = nil;
        shouldDismissContextualMenu = YES;
    }
    
    if (shouldDismissContextualMenu)
    {
        [self hideContextualMenuAnimated:NO];
    }
    
    // Change inputToolbarView class only if given class is different from current one
    if (!self.inputToolbarView || ![self.inputToolbarView isMemberOfClass:roomInputToolbarViewClass])
    {
        [super setRoomInputToolbarViewClass:roomInputToolbarViewClass];
        if ([self.inputToolbarView.class conformsToProtocol:@protocol(RoomInputToolbarViewProtocol)]) {
            id<RoomInputToolbarViewProtocol> inputToolbar = (id<RoomInputToolbarViewProtocol>)self.inputToolbarView;
            [inputToolbar setVoiceMessageToolbarView:self.voiceMessageController.voiceMessageToolbarView];
        }
        
        [self updateInputToolBarViewHeight];
        [self refreshRoomInputToolbar];
    }
}

// Get the height of the current room input toolbar
- (CGFloat)inputToolbarHeight
{
    CGFloat height = 0;
    
    if ([self.inputToolbarView.class conformsToProtocol:@protocol(RoomInputToolbarViewProtocol)]) {
        id<RoomInputToolbarViewProtocol> inputToolbar = (id<RoomInputToolbarViewProtocol>)self.inputToolbarView;
        height = inputToolbar.toolbarHeight;
    }
    else if ([self.inputToolbarView isKindOfClass:DisabledRoomInputToolbarView.class])
    {
        height = ((DisabledRoomInputToolbarView*)self.inputToolbarView).mainToolbarMinHeightConstraint.constant;
    }
    
    return height;
}

- (void)setRoomActivitiesViewClass:(Class)roomActivitiesViewClass
{
    // Do not show room activities in case of preview (FIXME: show it when live events will be supported during peeking)
    if (self.isRoomPreview)
    {
        roomActivitiesViewClass = nil;
    }
    
    [super setRoomActivitiesViewClass:roomActivitiesViewClass];
    
    if (!self.isActivitiesViewExpanded)
    {
        self.roomActivitiesContainerHeightConstraint.constant = 0;
    }
}

- (BOOL)sendAsIRCStyleCommandIfPossible:(NSString*)string
{
    // Override the default behavior for `/join` command in order to open automatically the joined room

    NSString* kMXKSlashCmdJoinRoom = [MXKSlashCommandsHelper commandNameFor:MXKSlashCommandJoinRoom];
    
    if ([string hasPrefix:kMXKSlashCmdJoinRoom])
    {
        // Join a room
        NSString *roomAlias;
        
        // Sanity check
        if (string.length > kMXKSlashCmdJoinRoom.length)
        {
            roomAlias = [string substringFromIndex:kMXKSlashCmdJoinRoom.length + 1];
            
            // Remove white space from both ends
            roomAlias = [roomAlias stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        
        // Check
        if (roomAlias.length)
        {
            Analytics.shared.joinedRoomTrigger = AnalyticsJoinedRoomTriggerSlashCommand;
            
            // TODO: /join command does not support via parameters yet
            [self.mainSession joinRoom:roomAlias viaServers:nil success:^(MXRoom *room) {
                                
                [self showRoomWithId:room.roomId];
                
            } failure:^(NSError *error) {
                
                MXLogDebug(@"[RoomVC] Join roomAlias (%@) failed", roomAlias);
                //Alert user
                [self showError:error];
                
            }];
        }
        else
        {
            // Display cmd usage in text input as placeholder
            self.inputToolbarView.placeholder = [MXKSlashCommandsHelper commandUsageFor:MXKSlashCommandJoinRoom];
        }
        return YES;
    }
    return [super sendAsIRCStyleCommandIfPossible:string];
}

- (void)setKeyboardHeight:(CGFloat)keyboardHeight
{
    [super setKeyboardHeight:keyboardHeight];

    self.inputToolbarView.maxHeight = round(([UIScreen mainScreen].bounds.size.height - keyboardHeight) * 0.7);

    // Make the activity indicator follow the keyboard
    // At runtime, this creates a smooth animation
    CGPoint activityIndicatorCenter = self.activityIndicator.center;
    activityIndicatorCenter.y = self.view.center.y - keyboardHeight / 2;
    self.activityIndicator.center = activityIndicatorCenter;
}

- (void)dismissTemporarySubViews
{
    [super dismissTemporarySubViews];
    
    if (encryptionInfoView)
    {
        [encryptionInfoView removeFromSuperview];
        encryptionInfoView = nil;
    }
}

- (void)setBubbleTableViewDisplayInTransition:(BOOL)bubbleTableViewDisplayInTransition
{
    if (self.isBubbleTableViewDisplayInTransition != bubbleTableViewDisplayInTransition)
    {
        [super setBubbleTableViewDisplayInTransition:bubbleTableViewDisplayInTransition];
        
        // Refresh additional displays when the table is ready.
        if (!bubbleTableViewDisplayInTransition && !self.bubblesTableView.isHidden)
        {
            [self refreshActivitiesViewDisplay];
            [self refreshRoomTitle];
            
            [self checkReadMarkerVisibility];
            [self refreshJumpToLastUnreadBannerDisplay];
        }
    }
}

- (void)sendTextMessage:(NSString*)msgTxt
{
    // Create before sending the message in case of a discussion (direct chat)
    MXWeakify(self);
    [self createDiscussionIfNeeded:^(BOOL readyToSend) {
        MXStrongifyAndReturnIfNil(self);
        if (readyToSend)
        {
            // The event modified is always fetch from the actual data source
            MXEvent *eventModified = [self.roomDataSource eventWithEventId:self.customizedRoomDataSource.selectedEventId];
            
            // In the case the event is a reply or and edit, and it's done on a non-live timeline
            // we have to fetch live timeline in order to display the event properly
            [self setupRoomDataSourceToResolveEvent:^(MXKRoomDataSource *roomDataSource) {
                if (self.inputToolBarSendMode == RoomInputToolbarViewSendModeReply && eventModified)
                {
                    [roomDataSource sendReplyToEvent:eventModified withTextMessage:msgTxt success:nil failure:^(NSError *error) {
                        // Just log the error. The message will be displayed in red in the room history
                        MXLogDebug(@"[MXKRoomViewController] sendTextMessage failed.");
                    }];
                }
                else if (self.inputToolBarSendMode == RoomInputToolbarViewSendModeEdit && eventModified)
                {
                    [roomDataSource replaceTextMessageForEvent:eventModified withTextMessage:msgTxt success:nil failure:^(NSError *error) {
                        // Just log the error. The message will be displayed in red
                        MXLogDebug(@"[MXKRoomViewController] sendTextMessage failed.");
                    }];
                }
                else
                {
                    // Let the datasource send it and manage the local echo
                    [roomDataSource sendTextMessage:msgTxt success:nil failure:^(NSError *error)
                     {
                        // Just log the error. The message will be displayed in red in the room history
                        MXLogDebug(@"[MXKRoomViewController] sendTextMessage failed.");
                    }];
                }
                
                if (self.customizedRoomDataSource.selectedEventId)
                {
                    [self cancelEventSelection];
                }
            }];
        }
        // Errors are handled at the request level. This should be improved in case of code rewriting.
    }];
}

- (void)setupRoomDataSourceToResolveEvent: (void (^)(MXKRoomDataSource *roomDataSource))onComplete
{
    // If the event occur on timeline not live, use the live data source to resolve event
    BOOL isLive = self.roomDataSource.isLive;
    if (!isLive)
    {
        if (self.roomDataSourceLive == nil)
        {
            MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:self.mainSession];

            [roomDataSourceManager roomDataSourceForRoom:self.roomDataSource.roomId
                                                  create:YES
                                              onComplete:^(MXKRoomDataSource *roomDataSource) {
                self.roomDataSourceLive = roomDataSource;
                [self.roomDataSourceLive finalizeInitialization];
                onComplete(self.roomDataSourceLive);
            }];
        }
        else
        {
            onComplete(self.roomDataSourceLive);
        }
    }
    else
    {
        onComplete(self.roomDataSource);
    }
}

- (void)setRoomTitleViewClass:(Class)roomTitleViewClass
{
    if ([self.titleView.class isEqual:roomTitleViewClass]) {
        return;
    }
    
    // Sanity check: accept only MXKRoomTitleView classes or sub-classes
    NSParameterAssert([roomTitleViewClass isSubclassOfClass:MXKRoomTitleView.class]);
    
    MXKRoomTitleView *titleView = [roomTitleViewClass roomTitleView];
    [self setValue:titleView forKey:@"titleView"];
    titleView.delegate = self;
    titleView.mxRoom = self.roomDataSource.room;
    titleView.mxUser = self.directChatTargetUser;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:titleView];
    
    if ([titleView isKindOfClass:RoomTitleView.class])
    {
        RoomTitleView *roomTitleView = (RoomTitleView*)self.titleView;
        missedDiscussionsBadgeLabel = roomTitleView.missedDiscussionsBadgeLabel;
        missedDiscussionsDotView = roomTitleView.dotView;
        [roomTitleView updateLayoutForOrientation:[UIApplication sharedApplication].statusBarOrientation];
    }

    [self updateViewControllerAppearanceOnRoomDataSourceState];
    
    [self updateTitleViewEncryptionDecoration];
}

- (void)destroy
{
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    if (self.customizedRoomDataSource)
    {
        self.customizedRoomDataSource.selectedEventId = nil;
        self.customizedRoomDataSource = nil;
    }
    
    [self removeTypingNotificationsListener];
    
    if (kThemeServiceDidChangeThemeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kThemeServiceDidChangeThemeNotificationObserver];
        kThemeServiceDidChangeThemeNotificationObserver = nil;
    }
    if (kAppDelegateDidTapStatusBarNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kAppDelegateDidTapStatusBarNotificationObserver];
        kAppDelegateDidTapStatusBarNotificationObserver = nil;
    }
    if (kAppDelegateNetworkStatusDidChangeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kAppDelegateNetworkStatusDidChangeNotificationObserver];
        kAppDelegateNetworkStatusDidChangeNotificationObserver = nil;
    }
    if (mxRoomSummaryDidChangeObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:mxRoomSummaryDidChangeObserver];
        mxRoomSummaryDidChangeObserver = nil;
    }
    if (mxEventDidDecryptNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:mxEventDidDecryptNotificationObserver];
        mxEventDidDecryptNotificationObserver = nil;
    }
    if (URLPreviewDidUpdateNotificationObserver)
    {
        [NSNotificationCenter.defaultCenter removeObserver:URLPreviewDidUpdateNotificationObserver];        
    }
    
    [self removeCallNotificationsListeners];
    [self removeWidgetNotificationsListeners];
    [self removeTombstoneEventNotificationsListener];
    [self removeMXSessionStateChangeNotificationsListener];
    [self removeServerNoticesListener];
    
    if (previewHeader)
    {
        // Here [destroy] is called before [viewWillDisappear:]
        MXLogDebug(@"[RoomVC] destroyed whereas it is still visible");
        
        [previewHeader removeFromSuperview];
        previewHeader = nil;
        
        // Hide preview header container to ignore [self showPreviewHeader:NO] call (if any).
        self.previewHeaderContainer.hidden = YES;
    }
    
    roomPreviewData = nil;
    
    missedDiscussionsBadgeLabel = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidChangeSentStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidChangeIdentifierNotification object:nil];
    
    [self waitForOtherParticipant:NO];
    
    [super destroy];
}

#pragma mark - Start DM

/**
 Create a direct chat with given user.
 */
- (void)createDiscussionWithUser:(MXUser*)user completion:(void (^)(BOOL success))onComplete
{
    [self startActivityIndicator];
    
    [[AppDelegate theDelegate] createDirectChatWithUserId:user.userId completion:^(NSString *roomId) {
        if (roomId)
        {
            MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:self.mainSession];
            [roomDataSourceManager roomDataSourceForRoom:roomId create:YES onComplete:^(MXKRoomDataSource *roomDataSource) {
                [self stopActivityIndicator];
                [self setRoomInputToolbarViewClass:nil];
                [self displayRoom:roomDataSource];
                
                onComplete(YES);
            }];
        }
        else
        {
            [self stopActivityIndicator];
            onComplete(NO);
        }
    }];
}

/**
 Create the discussion if needed
 */
- (void)createDiscussionIfNeeded:(void (^)(BOOL readyToSend))onComplete
{
    void(^completion)(BOOL) = ^(BOOL readyToSend) {
        self.inputToolbarView.userInteractionEnabled = true;
        if (onComplete) {
            onComplete(readyToSend);
        }
    };
    
    if (self.directChatTargetUser)
    {
        // Disable the input tool bar during this operation. This prevents us from creating several discussions, or
        // trying to send several invites.
        self.inputToolbarView.userInteractionEnabled = false;
        
        [self createDiscussionWithUser:self.directChatTargetUser completion:completion];
    }
    else
    {
        completion(YES);
    }
}

#pragma mark - Properties

-(void)setActivitiesViewExpanded:(BOOL)activitiesViewExpanded
{
    if (_activitiesViewExpanded != activitiesViewExpanded)
    {
        _activitiesViewExpanded = activitiesViewExpanded;
        
        self.roomActivitiesContainerHeightConstraint.constant = activitiesViewExpanded ? 53 : 0;
        [super roomInputToolbarView:self.inputToolbarView heightDidChanged:[self inputToolbarHeight] completion:nil];
    }
}

- (void)setScrollToBottomHidden:(BOOL)scrollToBottomHidden
{
    if (_scrollToBottomHidden != scrollToBottomHidden)
    {
        _scrollToBottomHidden = scrollToBottomHidden;
    }
    
    if (!_scrollToBottomHidden && [self.roomDataSource isKindOfClass:RoomDataSource.class])
    {
        RoomDataSource *roomDataSource = (RoomDataSource *) self.roomDataSource;
        if (roomDataSource.currentTypingUsers && !roomDataSource.currentTypingUsers.count)
        {
            [roomDataSource resetTypingNotification];
            [self.bubblesTableView reloadData];
        }
    }

    [UIView animateWithDuration:.2 animations:^{
        self.scrollToBottomBadgeLabel.alpha = (scrollToBottomHidden || !self.scrollToBottomBadgeLabel.text) ? 0 : 1;
        self.scrollToBottomButton.alpha = scrollToBottomHidden ? 0 : 1;
    }];
}

- (void)setMissedDiscussionsBadgeHidden:(BOOL)missedDiscussionsBadgeHidden{
    _missedDiscussionsBadgeHidden = missedDiscussionsBadgeHidden;
    
    missedDiscussionsBadgeLabel.hidden = missedDiscussionsBadgeHidden;
    missedDiscussionsDotView.hidden = missedDiscussionsBadgeHidden;
}

- (BOOL)shouldShowLiveLocationSharingBannerView
{
    return self.customizedRoomDataSource.isCurrentUserSharingActiveLocation;
}

#pragma mark - Wait for 3rd party invitee

- (void)setIsWaitingForOtherParticipants:(BOOL)isWaitingForOtherParticipants
{
    if (_isWaitingForOtherParticipants == isWaitingForOtherParticipants)
    {
        return;
    }

    _isWaitingForOtherParticipants = isWaitingForOtherParticipants;
    [self updateRoomInputToolbarViewClassIfNeeded];
    
    if (_isWaitingForOtherParticipants)
    {
        if (self->roomMemberEventListener == nil)
        {
            MXWeakify(self);
            self->roomMemberEventListener = [self.roomDataSource.room listenToEventsOfTypes:@[kMXEventTypeStringRoomMember] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {
                MXStrongifyAndReturnIfNil(self);
                if (direction != MXTimelineDirectionForwards)
                {
                    return;
                }
                [self refreshWaitForOtherParticipantsState];
            }];
        }
    }
    else
    {
        if (self->roomMemberEventListener != nil)
        {
            [self.roomDataSource.room removeListener:self->roomMemberEventListener];
            self->roomMemberEventListener = nil;
        }
    }
}

- (BOOL)shouldWaitForOtherParticipants
{
    MXRoomState *roomState = self.roomDataSource.roomState;
    BOOL isDirect = self.roomDataSource.room.isDirect;
    
    // Wait for the other participant only if it is a direct encrypted room with only one member waiting for a third party guest.
    return (isDirect && roomState.isEncrypted && roomState.membersCount.members == 1 && roomState.thirdPartyInvites.count > 0);
}

- (void)refreshWaitForOtherParticipantsState
{
    [self waitForOtherParticipant:self.shouldWaitForOtherParticipants];
}

#pragma mark - Internals

- (UIBarButtonItem *)videoCallBarButtonItem
{
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:AssetImages.videoCall.image
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(onVideoCallPressed:)];
    item.accessibilityLabel = [VectorL10n roomAccessibilityVideoCall];
    
    return item;
}

- (UIBarButtonItem *)joinJitsiBarButtonItem
{
    CallTileActionButton *button = [CallTileActionButton new];
    [button setImage:AssetImages.callVideoIcon.image
            forState:UIControlStateNormal];
    [button setTitle:[VectorL10n roomJoinGroupCall]
            forState:UIControlStateNormal];
    [button addTarget:self
               action:@selector(onVideoCallPressed:)
     forControlEvents:UIControlEventTouchUpInside];
    button.contentEdgeInsets = UIEdgeInsetsMake(4, 12, 4, 12);
    
    UIBarButtonItem *item;
    
    if (RiotSettings.shared.enableThreads)
    {
        // Add some spacing when there is a threads button
        UIView *buttonContainer = [[UIView alloc] initWithFrame:CGRectZero];
        [buttonContainer vc_addSubViewMatchingParent:button withInsets:UIEdgeInsetsMake(0, 0, 0, -12)];
        
        item = [[UIBarButtonItem alloc] initWithCustomView:buttonContainer];
    }
    else
    {
        item = [[UIBarButtonItem alloc] initWithCustomView:button];
    }
    
    item.accessibilityLabel = [VectorL10n roomAccessibilityVideoCall];
    
    return item;
}

- (UIBarButtonItem *)threadMoreBarButtonItem
{
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:AssetImages.roomContextMenuMore.image
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(onButtonPressed:)];
    item.accessibilityLabel = [VectorL10n roomAccessibilityThreadMore];
    
    return item;
}

- (UIBarButtonItem *)threadListBarButtonItem
{
    UIButton *button = [UIButton new];
    button.contentEdgeInsets = kThreadListBarButtonItemContentInsetsNoDot;
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [button setImage:[AssetImages.threadsIcon.image vc_resizedWith:kThreadListBarButtonItemImageSize]
            forState:UIControlStateNormal];
    [button addTarget:self
               action:@selector(onThreadListTapped:)
     forControlEvents:UIControlEventTouchUpInside];
    button.accessibilityLabel = [VectorL10n roomAccessibilityThreads];

    UIBarButtonItem *result = [[UIBarButtonItem alloc] initWithCustomView:button];
    result.tag = kThreadListBarButtonItemTag;
    return result;
}

- (void)setupRemoveJitsiWidgetRemoveView
{
    if (!self.displayConfiguration.jitsiWidgetRemoverEnabled)
    {
        return;
    }
    
    self.removeJitsiWidgetView = [RemoveJitsiWidgetView instantiate];
    self.removeJitsiWidgetView.delegate = self;
    
    [self.removeJitsiWidgetContainer vc_addSubViewMatchingParent:self.removeJitsiWidgetView];
    
    self.removeJitsiWidgetContainer.hidden = YES;
    
    [self refreshRemoveJitsiWidgetView];
}

- (void)forceLayoutRefresh
{
    // Sanity check: check whether the table view data source is set.
    if (self.bubblesTableView.dataSource)
    {
        [self.view layoutIfNeeded];
    }
}

- (BOOL)isRoomPreview
{
    if (self.isContextPreview)
    {
        return YES;
    }
    
    // Check first whether some preview data are defined.
    if (roomPreviewData)
    {
        return YES;
    }
    
    if (self.roomDataSource && self.roomDataSource.state == MXKDataSourceStateReady && self.roomDataSource.room.summary.membership == MXMembershipInvite)
    {
        return YES;
    }
    
    return NO;
}

// Indicates if a new direct chat with a target user (without associated room) is occuring.
- (BOOL)isNewDirectChat
{
    return self.directChatTargetUser != nil;
}

- (BOOL)isEncryptionEnabled
{
    return self.roomDataSource.room.summary.isEncrypted && self.mainSession.crypto != nil;
}

- (BOOL)supportCallOption
{
    if (!self.displayConfiguration.callsEnabled)
    {
        return NO;
    }
    BOOL callOptionAllowed = (self.roomDataSource.room.isDirect && RiotSettings.shared.roomScreenAllowVoIPForDirectRoom) || (!self.roomDataSource.room.isDirect && RiotSettings.shared.roomScreenAllowVoIPForNonDirectRoom);
    return callOptionAllowed && BuildSettings.allowVoIPUsage && self.roomDataSource.mxSession.callManager && self.roomDataSource.room.summary.membersCount.joined >= 2;
}

- (BOOL)isCallActive
{
    MXCall *callInRoom = [self.roomDataSource.mxSession.callManager callInRoom:self.roomDataSource.roomId];
    
    return (callInRoom && callInRoom.state != MXCallStateEnded)
    || self.customizedRoomDataSource.jitsiWidget;
}

- (BOOL)canSendStateEventWithType:(MXEventTypeString)eventTypeString
{
    MXRoomPowerLevels *powerLevels = [self.roomDataSource.roomState powerLevels];
    NSInteger requiredPower = [powerLevels minimumPowerLevelForSendingEventAsStateEvent:eventTypeString];
    NSInteger myPower = [self.roomDataSource.roomState powerLevelOfUserWithUserID:self.roomDataSource.mxSession.myUserId];
    return myPower >= requiredPower;
}

/**
 Returns a flag for the current user whether it's privileged to add/remove Jitsi widgets to this room.
 */
- (BOOL)canEditJitsiWidget
{
    return [self canSendStateEventWithType:kWidgetModularEventTypeString];
}

- (void)registerURLPreviewNotifications
{
    MXWeakify(self);
    
    URLPreviewDidUpdateNotificationObserver = [NSNotificationCenter.defaultCenter addObserverForName:URLPreviewDidUpdateNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification * _Nonnull notification) {
        
        MXStrongifyAndReturnIfNil(self);        
        
        // Ensure this is the correct room
        if (![(NSString*)notification.userInfo[@"roomId"] isEqualToString:self.roomDataSource.roomId])
        {
            return;
        }
        
        // Get the indexPath for the updated cell.
        NSString *updatedEventId = notification.userInfo[@"eventId"];
        NSInteger updatedEventIndex = [self.roomDataSource indexOfCellDataWithEventId:updatedEventId];
        NSIndexPath *updatedIndexPath = [NSIndexPath indexPathForRow:updatedEventIndex inSection:0];
        
        // Store the content size and offset before reloading the cell
        CGFloat originalContentSize = self.bubblesTableView.contentSize.height;
        CGPoint contentOffset = self.bubblesTableView.contentOffset;
        
        // Only update the content offset if the cell is visible or above the current visible cells.
        BOOL shouldUpdateContentOffset = NO;
        NSIndexPath *lastVisibleIndexPath = [self.bubblesTableView indexPathsForVisibleRows].lastObject;
        if (lastVisibleIndexPath && updatedIndexPath.row < lastVisibleIndexPath.row)
        {
            shouldUpdateContentOffset = YES;
        }
        
        // Note: Despite passing in the index path, this reloads the whole table.
        [self dataSource:self.roomDataSource didCellChange:updatedIndexPath];
        
        // Update the content offset to include any changes to the scroll view's height.
        if (shouldUpdateContentOffset)
        {
            CGFloat delta = self.bubblesTableView.contentSize.height - originalContentSize;
            contentOffset.y += delta;
            
            self.bubblesTableView.contentOffset = contentOffset;
        }
    }];
}

- (void)refreshRoomTitle
{
    NSMutableArray *rightBarButtonItems = nil;
    
    // Set the right room title view
    if (self.isRoomPreview)
    {
        [self showPreviewHeader:YES];
    }
    else if (self.roomDataSource)
    {
        [self showPreviewHeader:NO];
        
        if (self.roomDataSource.isLive)
        {
            rightBarButtonItems = [NSMutableArray new];
            BOOL hasCustomJoinButton = NO;
            
            if (self.supportCallOption)
            {
                if (self.roomDataSource.room.summary.membersCount.joined == 2
                    && self.roomDataSource.room.isDirect
                    && !self.mainSession.vc_homeserverConfiguration.jitsi.useFor1To1Calls)
                {
                    //  voice call button for Matrix call
                    UIBarButtonItem *itemVoice = [[UIBarButtonItem alloc] initWithImage:AssetImages.voiceCallHangonIcon.image
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(onVoiceCallPressed:)];
                    itemVoice.accessibilityLabel = [VectorL10n roomAccessibilityCall];
                    itemVoice.enabled = !self.isCallActive;
                    [rightBarButtonItems addObject:itemVoice];
                    
                    //  video call button for Matrix call
                    UIBarButtonItem *itemVideo = [self videoCallBarButtonItem];
                    itemVideo.enabled = !self.isCallActive;
                    [rightBarButtonItems addObject:itemVideo];
                }
                else
                {
                    //  video call button for Jitsi call
                    if (self.isCallActive)
                    {
                        if (self.isRoomHavingAJitsiCall)
                        {
                            //  show a disabled call button
                            UIBarButtonItem *item = [self videoCallBarButtonItem];
                            item.enabled = NO;
                            [rightBarButtonItems addObject:item];
                        }
                        else
                        {
                            UIBarButtonItem *item = [self joinJitsiBarButtonItem];
                            [rightBarButtonItems addObject:item];
                            
                            hasCustomJoinButton = YES;
                        }
                    }
                    else
                    {
                        //  show a video call button
                        //  item will still be enabled, and when tapped an alert will be displayed to the user
                        UIBarButtonItem *item = [self videoCallBarButtonItem];
                        if (!self.canEditJitsiWidget)
                        {
                            item.image = [AssetImages.videoCall.image vc_withAlpha:0.3];
                        }
                        [rightBarButtonItems addObject:item];
                    }
                }
            }
            
            if ([self widgetsCount:NO])
            {
                UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:AssetImages.integrationsIcon.image
                                                                         style:UIBarButtonItemStylePlain
                                                                        target:self
                                                                        action:@selector(onIntegrationsPressed:)];
                item.accessibilityLabel = [VectorL10n roomAccessibilityIntegrations];
                if (hasCustomJoinButton)
                {
                    item.imageInsets = UIEdgeInsetsMake(0, -5, 0, -5);
                    item.landscapeImagePhoneInsets = UIEdgeInsetsMake(0, -5, 0, -5);
                }
                [rightBarButtonItems addObject:item];
            }
        }
        
        // Do not change title view class here if the expanded header is visible.
        [self setRoomTitleViewClass:RoomTitleView.class];
        ((RoomTitleView*)self.titleView).tapGestureDelegate = self;
        
        MXKImageView *userPictureView = ((RoomTitleView*)self.titleView).pictureView;
        
        // Set user picture in input toolbar
        if (userPictureView)
        {
            [self.roomDataSource.room.summary setRoomAvatarImageIn:userPictureView];
        }
        
        [self refreshMissedDiscussionsCount:YES];
        
        if (RiotSettings.shared.enableThreads && !_isWaitingForOtherParticipants)
        {
            if (self.roomDataSource.threadId)
            {
                //  in a thread
                if (rightBarButtonItems == nil)
                {
                    rightBarButtonItems = [NSMutableArray new];
                }
                UIBarButtonItem *itemThreadMore = [self threadMoreBarButtonItem];
                [rightBarButtonItems insertObject:itemThreadMore atIndex:0];
            }
            else
            {
                //  in a regular timeline
                UIBarButtonItem *itemThreadList = [self threadListBarButtonItem];
                [self updateThreadListBarButtonItem:itemThreadList
                                               with:self.mainSession.threadingService];
                [rightBarButtonItems insertObject:itemThreadList atIndex:0];
            }
        }
    }
    else if (self.isNewDirectChat)
    {
        [self showPreviewHeader:NO];
        
        [self setRoomTitleViewClass:RoomTitleView.class];
        MXKImageView *userPictureView = ((RoomTitleView*)self.titleView).pictureView;
        
        // Set user picture in input toolbar
        if (userPictureView)
        {
            [userPictureView vc_setRoomAvatarImageWith:self.directChatTargetUser.avatarUrl
                                                roomId:self.directChatTargetUser.userId
                                           displayName:self.directChatTargetUser.displayname ?: self.directChatTargetUser.userId
                                          mediaManager:self.mainSession.mediaManager];
        }
    }
    
    self.navigationItem.rightBarButtonItems = rightBarButtonItems;
}

- (void)updateInputToolBarVisibility
{
    BOOL hideInputToolBar = NO;
    
    if (self.roomDataSource)
    {
        hideInputToolBar = (self.roomDataSource.state != MXKDataSourceStateReady);
    }
    
    self.inputToolbarView.hidden = hideInputToolBar;
}

- (void)refreshRoomInputToolbar
{
    MXKImageView *userPictureView;
    
    // Show or hide input tool bar
    [self updateInputToolBarVisibility];
    
    // Check whether the input toolbar is ready before updating it.
    if (self.inputToolbarView && [self inputToolbarConformsToToolbarViewProtocol])
    {
        id<RoomInputToolbarViewProtocol> roomInputToolbarView = (id<RoomInputToolbarViewProtocol>) self.inputToolbarView;
        
        // Update encryption decoration if needed
        [self updateEncryptionDecorationForRoomInputToolbar:roomInputToolbarView];

        // Update actions when the input toolbar refreshed
        [self setupActions];
        
        // Update placeholder and hide voice message view
        if (self.isNewDirectChat)
        {
            [self setInputToolBarSendMode:RoomInputToolbarViewSendModeCreateDM forEventWithId:nil];
            [roomInputToolbarView setVoiceMessageToolbarView:nil];
        }
    }
    else if (self.inputToolbarView && [self.inputToolbarView isKindOfClass:DisabledRoomInputToolbarView.class])
    {
        DisabledRoomInputToolbarView *roomInputToolbarView = (DisabledRoomInputToolbarView*)self.inputToolbarView;
        
        // Get user picture view in input toolbar
        userPictureView = roomInputToolbarView.pictureView;
        
        // For the moment, there is only one reason to use `DisabledRoomInputToolbarView`
        [roomInputToolbarView setDisabledReason:[VectorL10n roomDoNotHavePermissionToPost]];
    }
    
    // Set user picture in input toolbar
    if (userPictureView)
    {
        UIImage *preview = [AvatarGenerator generateAvatarForMatrixItem:self.mainSession.myUser.userId withDisplayName:self.mainSession.myUser.displayname];
        
        // Suppose the avatar is stored unencrypted on the Matrix media repository.
        userPictureView.enableInMemoryCache = YES;
        [userPictureView setImageURI:self.mainSession.myUser.avatarUrl
                            withType:nil
                 andImageOrientation:UIImageOrientationUp
                       toFitViewSize:userPictureView.frame.size
                          withMethod:MXThumbnailingMethodCrop
                        previewImage:preview
                        mediaManager:self.mainSession.mediaManager];
        [userPictureView.layer setCornerRadius:userPictureView.frame.size.width / 2];
        userPictureView.clipsToBounds = YES;
    }
}

- (void)setInputToolBarSendMode:(RoomInputToolbarViewSendMode)sendMode forEventWithId:(NSString *)eventId
{
    if (self.inputToolbarView && [self inputToolbarConformsToToolbarViewProtocol])
    {
        MXKRoomInputToolbarView <RoomInputToolbarViewProtocol> *roomInputToolbarView = (MXKRoomInputToolbarView <RoomInputToolbarViewProtocol> *) self.inputToolbarView;
        if (eventId)
        {
            MXEvent *event = [self.roomDataSource eventWithEventId:eventId];
            MXRoomMember * roomMember = [self.roomDataSource.roomState.members memberWithUserId:event.sender];
            if (roomMember.displayname.length)
            {
                roomInputToolbarView.eventSenderDisplayName = roomMember.displayname;
            }
            else
            {
                roomInputToolbarView.eventSenderDisplayName = event.sender;
            }
        }
        else
        {
            roomInputToolbarView.eventSenderDisplayName = nil;
        }
        roomInputToolbarView.sendMode = sendMode;
    }
}

- (RoomInputToolbarViewSendMode)inputToolBarSendMode
{
    RoomInputToolbarViewSendMode sendMode = RoomInputToolbarViewSendModeSend;
    if (self.inputToolbarView && [self.inputToolbarView isKindOfClass:[RoomInputToolbarView class]])
    {
        RoomInputToolbarView *roomInputToolbarView = (RoomInputToolbarView*)self.inputToolbarView;
        sendMode = roomInputToolbarView.sendMode;
    }
    
    return sendMode;
}

- (void)onSwipeGesture:(UISwipeGestureRecognizer*)swipeGestureRecognizer
{
    UIView *view = swipeGestureRecognizer.view;
    
    if (view == self.activitiesView)
    {
        // Dismiss the keyboard when user swipes down on activities view.
        [self.inputToolbarView dismissKeyboard];
    }
}

- (void)updateInputToolBarViewHeight
{
    // Update the inputToolBar height.
    CGFloat height = [self inputToolbarHeight];
    // Disable animation during the update
    [UIView setAnimationsEnabled:NO];
    [self roomInputToolbarView:self.inputToolbarView heightDidChanged:height completion:nil];
    [UIView setAnimationsEnabled:YES];
}

- (UIImage*)roomEncryptionBadgeImage
{
    UIImage *encryptionIcon;
    
    if (self.isEncryptionEnabled)
    {
        RoomEncryptionTrustLevel roomEncryptionTrustLevel = ((RoomDataSource*)self.roomDataSource).encryptionTrustLevel;
        
        encryptionIcon = [EncryptionTrustLevelBadgeImageHelper roomBadgeImageFor:roomEncryptionTrustLevel];
    }
    
    return encryptionIcon;
}

- (void)updateInputToolbarEncryptionDecoration
{
    if (self.inputToolbarView && [self inputToolbarConformsToToolbarViewProtocol])
    {
        id<RoomInputToolbarViewProtocol> roomInputToolbarView = (id<RoomInputToolbarViewProtocol>)self.inputToolbarView;
        [self updateEncryptionDecorationForRoomInputToolbar:roomInputToolbarView];
    }
}

- (void)updateTitleViewEncryptionDecoration
{
    if (![self.titleView isKindOfClass:[RoomTitleView class]])
    {
        return;
    }
    
    RoomTitleView *roomTitleView = (RoomTitleView*)self.titleView;
    roomTitleView.badgeImageView.image = self.roomEncryptionBadgeImage;
}

- (void)updateEncryptionDecorationForRoomInputToolbar:(id<RoomInputToolbarViewProtocol>)roomInputToolbarView
{
    roomInputToolbarView.isEncryptionEnabled = self.isEncryptionEnabled;
}

- (void)handleLongPressFromCell:(id<MXKCellRendering>)cell withTappedEvent:(MXEvent*)event
{
    if (event && !self.customizedRoomDataSource.selectedEventId)
    {
        [self showContextualMenuForEvent:event fromSingleTapGesture:NO cell:cell animated:YES];
    }
}

- (void)showReactionHistoryForEventId:(NSString*)eventId animated:(BOOL)animated
{
    if (self.reactionHistoryCoordinatorBridgePresenter.isPresenting)
    {
        return;
    }
    
    ReactionHistoryCoordinatorBridgePresenter *presenter = [[ReactionHistoryCoordinatorBridgePresenter alloc] initWithSession:self.mainSession roomId:self.roomDataSource.roomId eventId:eventId];
    presenter.delegate = self;
    
    [presenter presentFrom:self animated:animated];
    
    self.reactionHistoryCoordinatorBridgePresenter = presenter;
}

- (void)showCameraControllerAnimated:(BOOL)animated
{
    CameraPresenter *cameraPresenter = [CameraPresenter new];
    cameraPresenter.delegate = self;
    [cameraPresenter presentCameraFrom:self with:@[MXKUTI.image, MXKUTI.movie] animated:YES];
    
    self.cameraPresenter = cameraPresenter;
}


- (void)showMediaPickerAnimated:(BOOL)animated
{
    MediaPickerCoordinatorBridgePresenter *mediaPickerPresenter = [[MediaPickerCoordinatorBridgePresenter alloc] initWithSession:self.mainSession mediaUTIs:@[MXKUTI.image, MXKUTI.movie] allowsMultipleSelection:YES];
    mediaPickerPresenter.delegate = self;
    
    UIView *sourceView;
    
    if ([self.inputToolbarView isKindOfClass:RoomInputToolbarView.class])
    {
        sourceView = ((RoomInputToolbarView*)self.inputToolbarView).attachMediaButton;
    }
    else
    {
        sourceView = self.inputToolbarView;
    }
    
    [mediaPickerPresenter presentFrom:self sourceView:sourceView sourceRect:sourceView.bounds animated:YES];
    
    self.mediaPickerPresenter = mediaPickerPresenter;
}

- (void)showRoomCreationModal
{
    [self.roomCreationModalCoordinatorBridgePresenter dismissWithAnimated:NO completion:nil];
    
    self.roomCreationModalCoordinatorBridgePresenter = [[RoomCreationModalCoordinatorBridgePresenter alloc] initWithSession:self.mainSession roomState:self.roomDataSource.roomState];
    self.roomCreationModalCoordinatorBridgePresenter.delegate = self;
    [self.roomCreationModalCoordinatorBridgePresenter presentFrom:self animated:YES];
}

- (void)showMemberDetails:(MXRoomMember *)member
{
    if (!member)
    {
        return;
    }
    RoomMemberDetailsViewController *memberViewController = [RoomMemberDetailsViewController roomMemberDetailsViewController];
    
    // Set delegate to handle action on member (start chat, mention)
    memberViewController.delegate = self;
    memberViewController.enableMention = (self.inputToolbarView != nil);
    memberViewController.enableVoipCall = NO;
    
    [memberViewController displayRoomMember:member withMatrixRoom:self.roomDataSource.room];
    
    [self.navigationController pushViewController:memberViewController animated:YES];
}

- (void)showRoomAvatarChange
{
    [self showRoomInfoWithInitialSection:RoomInfoSectionChangeAvatar animated:YES];
}

- (void)showAddParticipants
{
    self.participantsInvitePresenter = [[RoomParticipantsInviteCoordinatorBridgePresenter alloc] initWithSession:self.roomDataSource.mxSession room:self.roomDataSource.room parentSpaceId:self.parentSpaceId];
    self.participantsInvitePresenter.delegate = self;
    [self.participantsInvitePresenter presentFrom:self animated:YES];
}

- (void)showRoomTopicChange
{
    [self showRoomInfoWithInitialSection:RoomInfoSectionChangeTopic animated:YES];
}

- (void)showRoomInfo
{
    [self showRoomInfoWithInitialSection:RoomInfoSectionNone animated:YES];
}

- (void)showRoomInfoWithInitialSection:(RoomInfoSection)roomInfoSection animated:(BOOL)animated
{
    RoomInfoCoordinatorParameters *parameters = [[RoomInfoCoordinatorParameters alloc] initWithSession:self.roomDataSource.mxSession room:self.roomDataSource.room parentSpaceId:self.parentSpaceId initialSection:roomInfoSection canAddParticipants: !self.isWaitingForOtherParticipants];

    self.roomInfoCoordinatorBridgePresenter = [[RoomInfoCoordinatorBridgePresenter alloc] initWithParameters:parameters];
    
    self.roomInfoCoordinatorBridgePresenter.delegate = self;
    [self.roomInfoCoordinatorBridgePresenter pushFrom:self.navigationController animated:animated];
}

- (void)setupActions {
    
    if (![self.inputToolbarView isKindOfClass:RoomInputToolbarView.class]) {
        return;
    }
    
    RoomInputToolbarView *roomInputView = ((RoomInputToolbarView *) self.inputToolbarView);
    MXWeakify(self);
    NSMutableArray *actionItems = [NSMutableArray new];
    if (RiotSettings.shared.roomScreenAllowMediaLibraryAction)
    {
        [actionItems addObject:[[RoomActionItem alloc] initWithImage:AssetImages.actionMediaLibrary.image andAction:^{
            MXStrongifyAndReturnIfNil(self);
            if ([self.inputToolbarView isKindOfClass:RoomInputToolbarView.class]) {
                ((RoomInputToolbarView *) self.inputToolbarView).actionMenuOpened = NO;
            }
            [self showMediaPickerAnimated:YES];
        }]];
    }
    if (RiotSettings.shared.roomScreenAllowStickerAction && !self.isNewDirectChat)
    {
        [actionItems addObject:[[RoomActionItem alloc] initWithImage:AssetImages.actionSticker.image andAction:^{
            MXStrongifyAndReturnIfNil(self);
            if ([self.inputToolbarView isKindOfClass:RoomInputToolbarView.class]) {
                ((RoomInputToolbarView *) self.inputToolbarView).actionMenuOpened = NO;
            }
            [self roomInputToolbarViewPresentStickerPicker];
        }]];
    }
    if (RiotSettings.shared.roomScreenAllowFilesAction)
    {
        [actionItems addObject:[[RoomActionItem alloc] initWithImage:AssetImages.actionFile.image andAction:^{
            MXStrongifyAndReturnIfNil(self);
            if ([self.inputToolbarView isKindOfClass:RoomInputToolbarView.class]) {
                ((RoomInputToolbarView *) self.inputToolbarView).actionMenuOpened = NO;
            }
            [self roomInputToolbarViewDidTapFileUpload];
        }]];
    }
    if (RiotSettings.shared.enableVoiceBroadcast && !self.isNewDirectChat)
    {
        [actionItems addObject:[[RoomActionItem alloc] initWithImage:AssetImages.actionLive.image andAction:^{
            MXStrongifyAndReturnIfNil(self);
            if ([self.inputToolbarView isKindOfClass:RoomInputToolbarView.class]) {
                ((RoomInputToolbarView *) self.inputToolbarView).actionMenuOpened = NO;
            }
            [self roomInputToolbarViewDidTapVoiceBroadcast];
        }]];
    }
    if (BuildSettings.pollsEnabled && self.displayConfiguration.sendingPollsEnabled && !self.isNewDirectChat)
    {
        [actionItems addObject:[[RoomActionItem alloc] initWithImage:AssetImages.actionPoll.image andAction:^{
            MXStrongifyAndReturnIfNil(self);
            if ([self.inputToolbarView isKindOfClass:RoomInputToolbarView.class]) {
                ((RoomInputToolbarView *) self.inputToolbarView).actionMenuOpened = NO;
            }
            [self.delegate roomViewControllerDidRequestPollCreationFormPresentation:self];
        }]];
    }
    if (BuildSettings.locationSharingEnabled && !self.isNewDirectChat)
    {
        [actionItems addObject:[[RoomActionItem alloc] initWithImage:AssetImages.actionLocation.image andAction:^{
            MXStrongifyAndReturnIfNil(self);
            if ([self.inputToolbarView isKindOfClass:RoomInputToolbarView.class]) {
                ((RoomInputToolbarView *) self.inputToolbarView).actionMenuOpened = NO;
            }
            [self.delegate roomViewControllerDidRequestLocationSharingFormPresentation:self];
        }]];
    }
    if (RiotSettings.shared.roomScreenAllowCameraAction)
    {
        [actionItems addObject:[[RoomActionItem alloc] initWithImage:AssetImages.actionCamera.image andAction:^{
            MXStrongifyAndReturnIfNil(self);
            if ([self.inputToolbarView isKindOfClass:RoomInputToolbarView.class]) {
                ((RoomInputToolbarView *) self.inputToolbarView).actionMenuOpened = NO;
            }
            [self showCameraControllerAnimated:YES];
        }]];
    }
    roomInputView.actionsBar.actionItems = actionItems;
}

- (NSString *)textInputContextIdentifier
{
    return self.roomDataSource.roomId;
}

- (void)roomInputToolbarViewPresentStickerPicker
{
    // Search for the sticker picker widget in the user account
    Widget *widget = [[WidgetManager sharedManager] userWidgets:self.roomDataSource.mxSession ofTypes:@[kWidgetTypeStickerPicker]].firstObject;
    
    if (widget)
    {
        // Display the widget
        [widget widgetUrl:^(NSString * _Nonnull widgetUrl) {
            
            StickerPickerViewController *stickerPickerVC = [[StickerPickerViewController alloc] initWithUrl:widgetUrl forWidget:widget];
            
            stickerPickerVC.roomDataSource = self.roomDataSource;
            
            [self.navigationController pushViewController:stickerPickerVC animated:YES];
        } failure:^(NSError * _Nonnull error) {
            
            MXLogDebug(@"[RoomVC] Cannot display widget %@", widget);
            [self showError:error];
        }];
    }
    else
    {
        // The Sticker picker widget is not installed yet. Propose the user to install it
        MXWeakify(self);
        
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        
        NSString *alertMessage = [NSString stringWithFormat:@"%@\n%@",
                                  [VectorL10n widgetStickerPickerNoStickerpacksAlert],
                                  [VectorL10n widgetStickerPickerNoStickerpacksAlertAddNow]];
                                   
        UIAlertController *installPrompt = [UIAlertController alertControllerWithTitle:nil
                                                                               message:alertMessage
                                                                        preferredStyle:UIAlertControllerStyleAlert];
        
        [installPrompt addAction:[UIAlertAction actionWithTitle:[VectorL10n no]
                                                          style:UIAlertActionStyleCancel
                                                        handler:^(UIAlertAction * action)
                                 {
            MXStrongifyAndReturnIfNil(self);
            self->currentAlert = nil;
            
        }]];
        
        [installPrompt addAction:[UIAlertAction actionWithTitle:[VectorL10n yes]
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * action)
                                 {
            MXStrongifyAndReturnIfNil(self);
            self->currentAlert = nil;
            
            // Show the sticker picker settings screen
            IntegrationManagerViewController *modularVC = [[IntegrationManagerViewController alloc]
                                                           initForMXSession:self.roomDataSource.mxSession
                                                           inRoom:self.roomDataSource.roomId
                                                           screen:[IntegrationManagerViewController screenForWidget:kWidgetTypeStickerPicker]
                                                           widgetId:nil];
            
            [self presentViewController:modularVC animated:NO completion:nil];
        }]];
        
        [installPrompt mxk_setAccessibilityIdentifier:@"RoomVCStickerPickerAlert"];
        [self presentViewController:installPrompt animated:YES completion:nil];
        currentAlert = installPrompt;
    }
}

- (void)roomInputToolbarViewDidTapFileUpload
{
    MXKDocumentPickerPresenter *documentPickerPresenter = [MXKDocumentPickerPresenter new];
    documentPickerPresenter.delegate = self;
    
    NSArray<MXKUTI*> *allowedUTIs = @[MXKUTI.data];
    [documentPickerPresenter presentDocumentPickerWith:allowedUTIs from:self animated:YES completion:nil];
    
    self.documentPickerPresenter = documentPickerPresenter;
}

- (void)roomInputToolbarViewDidTapVoiceBroadcast
{
    // Check first the room permission
    if (![self canSendStateEventWithType:VoiceBroadcastSettings.voiceBroadcastInfoContentKeyType])
    {
        [self showAlertWithTitle:[VectorL10n voiceBroadcastUnauthorizedTitle] message:[VectorL10n voiceBroadcastPermissionDeniedMessage]];
        return;
    }
    
    MXSession* session = self.roomDataSource.mxSession;
    // Check whether the user is not already broadcasting here or in another room
    if (session.voiceBroadcastService)
    {
        [self showAlertWithTitle:[VectorL10n voiceBroadcastUnauthorizedTitle] message:[VectorL10n voiceBroadcastAlreadyInProgressMessage]];
        return;
    }
    
    // Prevents listening a VB when recording a new one
    [VoiceBroadcastPlaybackProvider.shared pausePlaying];
    
    // Check connectivity
    if ([AppDelegate theDelegate].isOffline)
    {
        [self showAlertWithTitle:[VectorL10n voiceBroadcastConnectionErrorTitle] message:[VectorL10n voiceBroadcastConnectionErrorMessage]];
        return;
    }
    
    // Request the voice broadcast service to start recording - No service is returned if someone else is already broadcasting in the room
    [session getOrCreateVoiceBroadcastServiceFor:self.roomDataSource.room completion:^(VoiceBroadcastService *voiceBroadcastService) {
        if (voiceBroadcastService) {
            [voiceBroadcastService startVoiceBroadcastWithSuccess:^(NSString * _Nullable success) { } failure:^(NSError * _Nonnull error) {
                [self showAlertWithTitle:[VectorL10n voiceBroadcastConnectionErrorTitle] message:[VectorL10n voiceBroadcastConnectionErrorMessage]];
                [session tearDownVoiceBroadcastService];
            }];
        }
        else
        {
            [self showAlertWithTitle:[VectorL10n voiceBroadcastUnauthorizedTitle] message:[VectorL10n voiceBroadcastBlockedBySomeoneElseMessage]];
        }
    }];
}

/**
 Send a video asset via the room input toolbar prompting the user for the conversion preset to use
 if the `showMediaCompressionPrompt` setting has been enabled.
 @param videoAsset The video asset to send
 @param isPhotoLibraryAsset Whether the asset was picked from the user's photo library.
 */
- (void)sendVideoAsset:(AVAsset *)videoAsset isPhotoLibraryAsset:(BOOL)isPhotoLibraryAsset
{
    if (![self inputToolbarConformsToToolbarViewProtocol])
    {
        return;
    }
    
    if (RiotSettings.shared.showMediaCompressionPrompt)
    {
        // Show the video conversion prompt for the user to select what size video they would like to send.
        UIAlertController *compressionPrompt = [MXKTools videoConversionPromptForVideoAsset:videoAsset
                                                                              withCompletion:^(NSString *presetName) {
            // When the preset name is missing, the user cancelled.
            if (!presetName)
            {
                return;
            }
            
            // Set the chosen preset and send the video (conversion takes place in the SDK).
            [MXSDKOptions sharedInstance].videoConversionPresetName = presetName;
            
            // Create before sending the message in case of a discussion (direct chat)
            [self createDiscussionIfNeeded:^(BOOL readyToSend) {
                if (readyToSend && [self inputToolbarConformsToToolbarViewProtocol])
                {
                    [self.inputToolbarView sendSelectedVideoAsset:videoAsset isPhotoLibraryAsset:isPhotoLibraryAsset];
                }
                // Errors are handled at the request level. This should be improved in case of code rewriting.
            }];
        }];
        
        UIView *sourceView;
        
        if ([self.inputToolbarView isKindOfClass:RoomInputToolbarView.class])
        {
            sourceView = ((RoomInputToolbarView*)self.inputToolbarView).attachMediaButton;
        }
        else
        {
            sourceView = self.inputToolbarView;
        }
        
        compressionPrompt.popoverPresentationController.sourceView = sourceView;
        compressionPrompt.popoverPresentationController.sourceRect = sourceView.bounds;
        
        [self presentViewController:compressionPrompt animated:YES completion:nil];
    }
    else
    {
        // Otherwise default to 1080p and send the video.
        [MXSDKOptions sharedInstance].videoConversionPresetName = AVAssetExportPreset1920x1080;
        
        // Create before sending the message in case of a discussion (direct chat)
        [self createDiscussionIfNeeded:^(BOOL readyToSend) {
            if (readyToSend && [self inputToolbarConformsToToolbarViewProtocol])
            {
                [self.inputToolbarView sendSelectedVideoAsset:videoAsset isPhotoLibraryAsset:isPhotoLibraryAsset];
            }
            // Errors are handled at the request level. This should be improved in case of code rewriting.
        }];
    }
}

- (void)showRoomWithId:(NSString*)roomId
{
    if (self.delegate)
    {
        [self.delegate roomViewController:self showRoomWithId:roomId eventId:nil];
    }
    else
    {
        [[AppDelegate theDelegate] showRoom:roomId andEventId:nil withMatrixSession:self.roomDataSource.mxSession];
    }
}

- (void)notifyDelegateOnLeaveRoomIfNecessary {
    if (isRoomLeft) {
        return;
    }
    isRoomLeft = YES;
    
    if (self.delegate)
    {
        [self.delegate roomViewControllerDidLeaveRoom:self];
    }
    else
    {
        [[AppDelegate theDelegate] restoreInitialDisplay:^{}];
    }
}

- (void)roomPreviewDidTapCancelAction
{
    // Decline this invitation = leave this page
    if (self.delegate)
    {
        [self.delegate roomViewControllerPreviewDidTapCancel:self];
    }
    else
    {
        [[AppDelegate theDelegate] restoreInitialDisplay:^{}];
    }
}

- (void)startChatWithUserId:(NSString *)userId completion:(void (^)(void))completion
{
    if (self.delegate)
    {
        [self.delegate roomViewController:self startChatWithUserId:userId completion:completion];
    }
    else
    {
        [[AppDelegate theDelegate] showNewDirectChat:userId withMatrixSession:self.mainSession completion:completion];
    }
}

- (void)showError:(NSError*)error
{
    [[AppDelegate theDelegate] showErrorAsAlert:error];
}

- (UIAlertController*)showAlertWithTitle:(NSString*)title message:(NSString*)message
{
    return [[AppDelegate theDelegate] showAlertWithTitle:title message:message];
}

- (ScreenPresentationParameters*)buildUniversalLinkPresentationParameters
{
    return [[ScreenPresentationParameters alloc] initWithRestoreInitialDisplay:NO stackAboveVisibleViews:BuildSettings.allowSplitViewDetailsScreenStacking sender:self sourceView:nil];
}

- (BOOL)handleUniversalLinkURL:(NSURL*)url
{
    ScreenPresentationParameters *screenParameters = [self buildUniversalLinkPresentationParameters];
    UniversalLinkParameters *parameters = [[UniversalLinkParameters alloc] initWithUrl:url
                                                                presentationParameters:screenParameters];
    return [self handleUniversalLinkWithParameters:parameters];
}

- (BOOL)handleUniversalLinkFragment:(NSString*)fragment fromURL:(NSURL*)url
{
    ScreenPresentationParameters *screenParameters = [self buildUniversalLinkPresentationParameters];
    UniversalLink *universalLink = [[UniversalLink alloc] initWithUrl:url];
    UniversalLinkParameters *parameters = [[UniversalLinkParameters alloc] initWithFragment:fragment
                                                                              universalLink:universalLink
                                                                     presentationParameters:screenParameters];
    return [self handleUniversalLinkWithParameters:parameters];
}

- (BOOL)handleUniversalLinkWithParameters:(UniversalLinkParameters*)parameters
{
    Analytics.shared.joinedRoomTrigger = AnalyticsJoinedRoomTriggerTimeline;
    
    if (self.delegate)
    {
        return [self.delegate roomViewController:self handleUniversalLinkWithParameters:parameters];
    }
    else
    {
        return [[AppDelegate theDelegate] handleUniversalLinkWithParameters:parameters];
    }
}

- (void)setupCompletionSuggestionViewIfNeeded
{
    if(!self.isViewLoaded) {
        return;
    }
    
    UIViewController *suggestionsViewController = self.completionSuggestionCoordinator.toPresentable;
    
    if (!suggestionsViewController)
    {
        return;
    }
    
    [suggestionsViewController.view setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    [self addChildViewController:suggestionsViewController];
    [self.completionSuggestionContainerView addSubview:suggestionsViewController.view];
    
    [NSLayoutConstraint activateConstraints:@[[suggestionsViewController.view.topAnchor constraintEqualToAnchor:self.completionSuggestionContainerView.topAnchor],
                                              [suggestionsViewController.view.leadingAnchor constraintEqualToAnchor:self.completionSuggestionContainerView.leadingAnchor],
                                              [suggestionsViewController.view.trailingAnchor constraintEqualToAnchor:self.completionSuggestionContainerView.trailingAnchor],
                                              [suggestionsViewController.view.bottomAnchor constraintEqualToAnchor:self.completionSuggestionContainerView.bottomAnchor],]];
    
    [suggestionsViewController didMoveToParentViewController:self];
}

- (void)updateTopBanners
{
    [self.view bringSubviewToFront:self.topBannersStackView];
    
    [self updateLiveLocationBannerViewVisibility];
}

- (void)showEmojiPickerForEventId:(NSString *)eventId
{
    EmojiPickerCoordinatorBridgePresenter *emojiPickerCoordinatorBridgePresenter = [[EmojiPickerCoordinatorBridgePresenter alloc] initWithSession:self.mainSession roomId:self.roomDataSource.roomId eventId:eventId];
    emojiPickerCoordinatorBridgePresenter.delegate = self;
    
    NSInteger cellRow = [self.roomDataSource indexOfCellDataWithEventId:eventId];
    
    UIView *sourceView;
    CGRect sourceRect = CGRectNull;
    
    if (cellRow >= 0)
    {
        NSIndexPath *cellIndexPath = [NSIndexPath indexPathForRow:cellRow inSection:0];
        UITableViewCell *cell = [self.bubblesTableView cellForRowAtIndexPath:cellIndexPath];
        sourceView = cell;
        
        if ([cell isKindOfClass:[MXKRoomBubbleTableViewCell class]])
        {
            MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell*)cell;
            NSInteger bubbleComponentIndex = [roomBubbleTableViewCell.bubbleData bubbleComponentIndexForEventId:eventId];
            sourceRect = [roomBubbleTableViewCell componentFrameInContentViewForIndex:bubbleComponentIndex];
        }
        
    }
    
    [emojiPickerCoordinatorBridgePresenter presentFrom:self sourceView:sourceView sourceRect:sourceRect animated:YES];
    self.emojiPickerCoordinatorBridgePresenter = emojiPickerCoordinatorBridgePresenter;
}

#pragma mark - Jitsi

- (void)showJitsiCallWithWidget:(Widget*)widget
{
    [[AppDelegate theDelegate].callPresenter displayJitsiCallWithWidget:widget];
}

- (void)endActiveJitsiCall
{
    [[AppDelegate theDelegate].callPresenter endActiveJitsiCall];
}

- (BOOL)isRoomHavingAJitsiCall
{
    return [self isRoomHavingAJitsiCallForWidgetId:self.roomDataSource.roomId];
}

- (BOOL)isRoomHavingAJitsiCallForWidgetId:(NSString*)widgetId
{
    return [[AppDelegate theDelegate].callPresenter.jitsiVC.widget.roomId isEqualToString:widgetId];
}

#pragma mark - Dialpad

- (void)openDialpad
{
    DialpadViewController *controller = [DialpadViewController instantiateWithConfiguration:[DialpadConfiguration default]];
    controller.delegate = self;
    self.customSizedPresentationController = [[CustomSizedPresentationController alloc] initWithPresentedViewController:controller presentingViewController:self];
    self.customSizedPresentationController.dismissOnBackgroundTap = NO;
    self.customSizedPresentationController.cornerRadius = 16;
    
    controller.transitioningDelegate = self.customSizedPresentationController;
    [self presentViewController:controller animated:YES completion:nil];
}

#pragma mark - DialpadViewControllerDelegate

- (void)dialpadViewControllerDidTapCall:(DialpadViewController *)viewController withPhoneNumber:(NSString *)phoneNumber
{
    if (self.mainSession.callManager && phoneNumber.length > 0)
    {
        [self startActivityIndicator];
        
        [viewController dismissViewControllerAnimated:YES completion:^{
            MXWeakify(self);
            [self.mainSession.callManager placeCallAgainst:phoneNumber withVideo:NO success:^(MXCall * _Nonnull call) {
                MXStrongifyAndReturnIfNil(self);
                [self stopActivityIndicator];
                self.customSizedPresentationController = nil;
                
                //  do nothing extra here. UI will be handled automatically by the CallService.
            } failure:^(NSError * _Nullable error) {
                MXStrongifyAndReturnIfNil(self);
                [self stopActivityIndicator];
            }];
        }];
    }
}

- (void)dialpadViewControllerDidTapClose:(DialpadViewController *)viewController
{
    [viewController dismissViewControllerAnimated:YES completion:nil];
    self.customSizedPresentationController = nil;
}

#pragma mark - Hide/Show preview header

- (void)showPreviewHeader:(BOOL)isVisible
{
    if (self.previewHeaderContainer && self.previewHeaderContainer.isHidden == isVisible)
    {
        // Check conditions before making the preview room header visible.
        // This operation is ignored if a screen rotation is in progress,
        // or if the view controller is not embedded inside a split view controller yet.
        if (isVisible && (isSizeTransitionInProgress == YES || !self.splitViewController))
        {
            MXLogDebug(@"[RoomVC] Show preview header ignored");
            return;
        }
        
        if (isVisible)
        {
            PreviewRoomTitleView *previewHeader = [PreviewRoomTitleView roomTitleView];
            previewHeader.delegate = self;
            previewHeader.tapGestureDelegate = self;
            previewHeader.translatesAutoresizingMaskIntoConstraints = NO;
            [self.previewHeaderContainer addSubview:previewHeader];
            
            self->previewHeader = previewHeader;
            
            // Force preview header in full width
            NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:previewHeader
                                                                              attribute:NSLayoutAttributeLeading
                                                                              relatedBy:NSLayoutRelationEqual
                                                                                 toItem:self.previewHeaderContainer
                                                                              attribute:NSLayoutAttributeLeading
                                                                             multiplier:1.0
                                                                               constant:0];
            NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:previewHeader
                                                                               attribute:NSLayoutAttributeTrailing
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:self.previewHeaderContainer
                                                                               attribute:NSLayoutAttributeTrailing
                                                                              multiplier:1.0
                                                                                constant:0];
            // Vertical constraints are required for iOS > 8
            NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:previewHeader
                                                                             attribute:NSLayoutAttributeTop
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:self.previewHeaderContainer
                                                                             attribute:NSLayoutAttributeTop
                                                                            multiplier:1.0
                                                                              constant:0];
            NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:previewHeader
                                                                                attribute:NSLayoutAttributeBottom
                                                                                relatedBy:NSLayoutRelationEqual
                                                                                   toItem:self.previewHeaderContainer
                                                                                attribute:NSLayoutAttributeBottom
                                                                               multiplier:1.0
                                                                                 constant:0];
            
            [NSLayoutConstraint activateConstraints:@[leftConstraint, rightConstraint, topConstraint, bottomConstraint]];
            
            if (roomPreviewData)
            {
                previewHeader.roomPreviewData = roomPreviewData;
            }
            else if (self.roomDataSource)
            {
                previewHeader.mxRoom = self.roomDataSource.room;
            }
            
            self.previewHeaderContainer.hidden = NO;
            
            // Finalize preview header display according to the screen orientation
            [self refreshPreviewHeader:UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])];
        }
        else
        {
            [previewHeader removeFromSuperview];
            previewHeader = nil;
            
            self.previewHeaderContainer.hidden = YES;
            
            // Consider the main navigation controller if the current view controller is embedded inside a split view controller.
            UINavigationController *mainNavigationController = self.navigationController;
            if (self.splitViewController.isCollapsed && self.splitViewController.viewControllers.count)
            {
                mainNavigationController = self.splitViewController.viewControllers.firstObject;
            }
            
            // Set a default title view class without handling tap gesture (Let [self refreshRoomTitle] refresh this view correctly).
            [self setRoomTitleViewClass:RoomTitleView.class];
                        
            // Remove the shadow image used to hide the bottom border of the navigation bar when the preview header is displayed
            [mainNavigationController.navigationBar setShadowImage:nil];
            [mainNavigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
            
            [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                             animations:^{
                
                self.bubblesTableViewTopConstraint.constant = 0;
                
                // Force to render the view
                [self forceLayoutRefresh];
                
            }
                             completion:^(BOOL finished){
            }];
        }
    }
    
    // Consider the main navigation controller if the current view controller is embedded inside a split view controller.
    UINavigationController *mainNavigationController = self.navigationController;
    if (self.splitViewController.isCollapsed && self.splitViewController.viewControllers.count)
    {
        mainNavigationController = self.splitViewController.viewControllers.firstObject;
    }
    mainNavigationController.navigationBar.translucent = isVisible;
    self.navigationController.navigationBar.translucent = isVisible;
}

- (void)refreshPreviewHeader:(BOOL)isLandscapeOriented
{
    if (previewHeader)
    {
        if (isLandscapeOriented
            && [GBDeviceInfo deviceInfo].family != GBDeviceFamilyiPad)
        {
            CGRect frame = self.navigationController.navigationBar.frame;
            
            previewHeader.mainHeaderContainer.hidden = YES;
            previewHeader.mainHeaderBackgroundHeightConstraint.constant = frame.size.height + (frame.origin.y > 0 ? frame.origin.y : 0);
            
            [self setRoomTitleViewClass:RoomTitleView.class];
            // We don't want to handle tap gesture here
            
            // Remove details icon
            RoomTitleView *roomTitleView = (RoomTitleView*)self.titleView;
            
            // Set preview data to provide the room name
            roomTitleView.roomPreviewData = roomPreviewData;
        }
        else
        {
            previewHeader.mainHeaderContainer.hidden = NO;
            previewHeader.mainHeaderBackgroundHeightConstraint.constant = previewHeader.mainHeaderContainer.frame.size.height;
            
            if ([previewHeader isKindOfClass:PreviewRoomTitleView.class])
            {
                // In case of preview, update the header height so that we can
                // display as much as possible the room topic in this header.
                // Note: the header height is handled by the previewHeader.mainHeaderBackgroundHeightConstraint.
                PreviewRoomTitleView *previewRoomTitleView = (PreviewRoomTitleView *)previewHeader;
                
                // Compute the height required to display all the room topic
                CGSize sizeThatFitsTextView = [previewRoomTitleView.roomTopic sizeThatFits:CGSizeMake(previewRoomTitleView.roomTopic.frame.size.width, MAXFLOAT)];
                
                // Increase the preview header height according to the room topic height
                // but limit it in order to let room for room messages at the screen bottom.
                // This free space depends on the device.
                // On an iphone 5 screen, the room topic height cannot be more than 50px.
                // Then, on larger screen, we can allow it a bit more height but we
                // apply a factor to give more priority to the display of more messages.
                CGFloat screenHeight = [[UIScreen mainScreen] bounds].size.height;
                CGFloat maxRoomTopicHeight = 50 + (screenHeight - 568) / 3;
                
                CGFloat additionalHeight = MIN(maxRoomTopicHeight, sizeThatFitsTextView.height)
                - previewRoomTitleView.roomTopic.frame.size.height;
                
                previewHeader.mainHeaderBackgroundHeightConstraint.constant += additionalHeight;
            }
            
            [self setRoomTitleViewClass:RoomAvatarTitleView.class];
            // Note the avatar title view does not define tap gesture.
            
            previewHeader.roomAvatar.alpha = 0.0;
            
            // Set the avatar provided in preview data
            if (roomPreviewData.roomAvatarUrl)
            {
                previewHeader.roomAvatarURL = roomPreviewData.roomAvatarUrl;
            }
            else if (roomPreviewData.roomId && roomPreviewData.roomName)
            {
                previewHeader.roomAvatarPlaceholder = [AvatarGenerator generateAvatarForMatrixItem:roomPreviewData.roomId withDisplayName:roomPreviewData.roomName];
            }
            else
            {
                previewHeader.roomAvatarPlaceholder = [MXKTools paintImage:AssetImages.placeholder.image
                                                                 withColor:ThemeService.shared.theme.tintColor];
            }
        }
        
        // Force the layout of previewHeader to update the position of 'bottomBorderView' which is used
        // to define the actual height of the preview container.
        [previewHeader layoutIfNeeded];
        CGRect frame = previewHeader.bottomBorderView.frame;
        self.previewHeaderContainerHeightConstraint.constant = frame.origin.y + frame.size.height;
        
        // Consider the main navigation controller if the current view controller is embedded inside a split view controller.
        UINavigationController *mainNavigationController = self.navigationController;
        if (self.splitViewController.isCollapsed && self.splitViewController.viewControllers.count)
        {
            mainNavigationController = self.splitViewController.viewControllers.firstObject;
        }
        
        // When the preview header is displayed, we hide the bottom border of the navigation bar (the shadow image).
        // The default shadow image is nil. When non-nil, this property represents a custom shadow image to show instead
        // of the default. For a custom shadow image to be shown, a custom background image must also be set with the
        // setBackgroundImage:forBarMetrics: method. If the default background image is used, then the default shadow
        // image will be used regardless of the value of this property.
        UIImage *shadowImage = [[UIImage alloc] init];
        [mainNavigationController.navigationBar setShadowImage:shadowImage];
        [mainNavigationController.navigationBar setBackgroundImage:shadowImage forBarMetrics:UIBarMetricsDefault];
        
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn
                         animations:^{
            
            self.bubblesTableViewTopConstraint.constant = self.previewHeaderContainerHeightConstraint.constant - self.bubblesTableView.adjustedContentInset.top;
            
            self->previewHeader.roomAvatar.alpha = 1;
            
            // Force to render the view
            [self forceLayoutRefresh];
            
        }
                         completion:^(BOOL finished){
        }];
    }
}

#pragma mark - Preview

- (void)displayRoomPreview:(RoomPreviewData *)previewData
{
    // Release existing room data source or preview
    [self displayRoom:nil];
    
    if (previewData)
    {
        self.eventsAcknowledgementEnabled = NO;
        
        [self addMatrixSession:previewData.mxSession];
        
        roomPreviewData = previewData;
        
        [self refreshRoomTitle];
        
        if (roomPreviewData.roomDataSource)
        {
            [super displayRoom:roomPreviewData.roomDataSource];
        }
    }
}

#pragma mark - New discussion

- (void)displayNewDirectChatWithTargetUser:(nonnull MXUser*)directChatTargetUser session:(nonnull MXSession*)session
{
    // `[displayRoom:]` may require the session, setting it here before calling it
    [self addMatrixSession:session];

    // Release existing room data source or preview
    [self displayRoom:nil];
    
    self.directChatTargetUser = directChatTargetUser;
    
    self.eventsAcknowledgementEnabled = NO;

    [self refreshRoomTitle];
    [self refreshRoomInputToolbar];
}

#pragma mark - MXKDataSourceDelegate

- (Class<MXKCellRendering>)cellViewClassForCellData:(MXKCellData*)cellData
{
    RoomTimelineCellIdentifier cellIdentifier = [self cellIdentifierForCellData:cellData andRoomDataSource:self.customizedRoomDataSource];
    
    RoomTimelineConfiguration *timelineConfiguration = [RoomTimelineConfiguration shared];
            
    return [timelineConfiguration.currentStyle.cellProvider cellViewClassForCellIdentifier:cellIdentifier];;
}

- (RoomTimelineCellIdentifier)cellIdentifierForCellData:(MXKCellData*)cellData andRoomDataSource:(RoomDataSource *)customizedRoomDataSource;
{
    // Sanity check
    if (![cellData conformsToProtocol:@protocol(MXKRoomBubbleCellDataStoring)])
    {
        return RoomTimelineCellIdentifierUnknown;
    }
    
    BOOL showEncryptionBadge = NO;
    RoomTimelineCellIdentifier cellIdentifier;
        
    id<MXKRoomBubbleCellDataStoring> bubbleData = (id<MXKRoomBubbleCellDataStoring>)cellData;
    
    MXKRoomBubbleCellData *roomBubbleCellData;
    
    if ([bubbleData isKindOfClass:MXKRoomBubbleCellData.class])
    {
        roomBubbleCellData = (MXKRoomBubbleCellData*)bubbleData;
        showEncryptionBadge = roomBubbleCellData.containsBubbleComponentWithEncryptionBadge;
    }
    
    // Select the suitable table view cell class, by considering first the empty bubble cell.
    if (bubbleData.hasNoDisplay)
    {
        cellIdentifier = RoomTimelineCellIdentifierEmpty;
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagRoomCreationIntro)
    {
        cellIdentifier = RoomTimelineCellIdentifierRoomCreationIntro;
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagRoomCreateWithPredecessor)
    {
        cellIdentifier = RoomTimelineCellIdentifierRoomPredecessor;
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagKeyVerificationRequestIncomingApproval)
    {
        cellIdentifier = bubbleData.isPaginationFirstBubble ? RoomTimelineCellIdentifierKeyVerificationIncomingRequestApprovalWithPaginationTitle : RoomTimelineCellIdentifierKeyVerificationIncomingRequestApproval;
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagKeyVerificationRequest)
    {
        cellIdentifier = bubbleData.isPaginationFirstBubble ? RoomTimelineCellIdentifierKeyVerificationRequestStatusWithPaginationTitle : RoomTimelineCellIdentifierKeyVerificationRequestStatus;
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagKeyVerificationConclusion)
    {
        cellIdentifier = bubbleData.isPaginationFirstBubble ? RoomTimelineCellIdentifierKeyVerificationConclusionWithPaginationTitle : RoomTimelineCellIdentifierKeyVerificationConclusion;
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagMembership)
    {
        if (bubbleData.collapsed)
        {
            if (bubbleData.nextCollapsableCellData)
            {
                cellIdentifier = bubbleData.isPaginationFirstBubble ? RoomTimelineCellIdentifierMembershipCollapsedWithPaginationTitle : RoomTimelineCellIdentifierMembershipCollapsed;
            }
            else
            {
                // Use a normal membership cell for a single membership event
                cellIdentifier = bubbleData.isPaginationFirstBubble ? RoomTimelineCellIdentifierMembershipWithPaginationTitle : RoomTimelineCellIdentifierMembership;
            }
        }
        else if (bubbleData.collapsedAttributedTextMessage)
        {
            // The cell (and its series) is not collapsed but this cell is the first
            // of the series. So, use the cell with the "collapse" button.
            cellIdentifier = bubbleData.isPaginationFirstBubble ? RoomTimelineCellIdentifierMembershipExpandedWithPaginationTitle : RoomTimelineCellIdentifierMembershipExpanded;
        }
        else
        {
            cellIdentifier = bubbleData.isPaginationFirstBubble ? RoomTimelineCellIdentifierMembershipWithPaginationTitle : RoomTimelineCellIdentifierMembership;
        }
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagRoomCreateConfiguration)
    {
        cellIdentifier = bubbleData.isPaginationFirstBubble ? RoomTimelineCellIdentifierRoomCreationCollapsedWithPaginationTitle : RoomTimelineCellIdentifierRoomCreationCollapsed;
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagCall)
    {
        cellIdentifier = RoomTimelineCellIdentifierDirectCallStatus;
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagGroupCall)
    {
        cellIdentifier = RoomTimelineCellIdentifierGroupCallStatus;
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagRTCCallNotify)
    {
        cellIdentifier = RoomTimelineCellIdentifierMatrixRTCCall;
    }
    else if (bubbleData.attachment.type == MXKAttachmentTypeVoiceMessage || bubbleData.attachment.type == MXKAttachmentTypeAudio)
    {
        if (bubbleData.isIncoming)
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingVoiceMessageWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingVoiceMessageWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingVoiceMessage;
            }
        }
        else
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingVoiceMessageWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingVoiceMessageWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingVoiceMessage;
            }
        }
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagPoll)
    {
        if (bubbleData.isIncoming)
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingPollWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingPollWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingPoll;
            }
        }
        else
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingPollWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingPollWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingPoll;
            }
        }
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagLocation || bubbleData.tag == RoomBubbleCellDataTagLiveLocation)
    {
        if (bubbleData.isIncoming)
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingLocationWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingLocationWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingLocation;
            }
        }
        else
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingLocationWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingLocationWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingLocation;
            }
        }
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagVoiceBroadcastPlayback)
    {
        if (bubbleData.isIncoming)
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingVoiceBroadcastPlaybackWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingVoiceBroadcastPlaybackWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = RoomTimelineCellIdentifierIncomingVoiceBroadcastPlayback;
            }
        }
        else
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingVoiceBroadcastPlaybackWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingVoiceBroadcastPlaybackWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = RoomTimelineCellIdentifierOutgoingVoiceBroadcastPlayback;
            }
        }
    }
    else if (bubbleData.tag == RoomBubbleCellDataTagVoiceBroadcastRecord)
    {
        if (bubbleData.isPaginationFirstBubble)
        {
            cellIdentifier = RoomTimelineCellIdentifierOutgoingVoiceBroadcastRecorderWithPaginationTitle;
        }
        else if (bubbleData.shouldHideSenderInformation)
        {
            cellIdentifier = RoomTimelineCellIdentifierOutgoingVoiceBroadcastRecorderWithoutSenderInfo;
        }
        else
        {
            cellIdentifier = RoomTimelineCellIdentifierOutgoingVoiceBroadcastRecorder;
        }
    }
    
    else if (roomBubbleCellData.getFirstBubbleComponentWithDisplay.event.isEmote)
    {
        if (bubbleData.isIncoming)
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                if (bubbleData.shouldHideSenderName)
                {
                    cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingEmoteEncryptedWithPaginationTitleWithoutSenderName : RoomTimelineCellIdentifierIncomingEmoteWithPaginationTitleWithoutSenderName;
                }
                else
                {
                    cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingEmoteEncryptedWithPaginationTitle : RoomTimelineCellIdentifierIncomingEmoteWithPaginationTitle;
                }
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingEmoteEncryptedWithoutSenderInfo : RoomTimelineCellIdentifierIncomingEmoteWithoutSenderInfo;
            }
            else if (bubbleData.shouldHideSenderName)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingEmoteEncryptedWithoutSenderName : RoomTimelineCellIdentifierIncomingEmoteWithoutSenderName;
            }
            else
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingEmoteEncrypted : RoomTimelineCellIdentifierIncomingEmote;
            }
        }
        else
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                if (bubbleData.shouldHideSenderName)
                {
                    cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingEmoteEncryptedWithPaginationTitleWithoutSenderName : RoomTimelineCellIdentifierOutgoingEmoteWithPaginationTitleWithoutSenderName;
                }
                else
                {
                    cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingEmoteEncryptedWithPaginationTitle : RoomTimelineCellIdentifierOutgoingEmoteWithPaginationTitle;
                }
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingEmoteEncryptedWithoutSenderInfo : RoomTimelineCellIdentifierOutgoingEmoteWithoutSenderInfo;
            }
            else if (bubbleData.shouldHideSenderName)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingEmoteEncryptedWithoutSenderName : RoomTimelineCellIdentifierOutgoingEmoteWithoutSenderName;
            }
            else
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingEmoteEncrypted : RoomTimelineCellIdentifierOutgoingEmote;
            }
        }
    }
    else if (bubbleData.isIncoming)
    {
        if (bubbleData.isAttachmentWithThumbnail)
        {
            // Check whether the provided celldata corresponds to a selected sticker
            if (customizedRoomDataSource.selectedEventId && (bubbleData.attachment.type == MXKAttachmentTypeSticker) && [bubbleData.attachment.eventId isEqualToString:customizedRoomDataSource.selectedEventId])
            {
                cellIdentifier = RoomTimelineCellIdentifierSelectedSticker;
            }
            else if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingAttachmentEncryptedWithPaginationTitle : RoomTimelineCellIdentifierIncomingAttachmentWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingAttachmentEncryptedWithoutSenderInfo : RoomTimelineCellIdentifierIncomingAttachmentWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingAttachmentEncrypted : RoomTimelineCellIdentifierIncomingAttachment;
            }
        }
        else if (bubbleData.isAttachment)
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingAttachmentWithoutThumbnailEncryptedWithPaginationTitle : RoomTimelineCellIdentifierIncomingAttachmentWithoutThumbnailWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingAttachmentWithoutThumbnailEncryptedWithoutSenderInfo : RoomTimelineCellIdentifierIncomingAttachmentWithoutThumbnailWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingAttachmentWithoutThumbnailEncrypted : RoomTimelineCellIdentifierIncomingAttachmentWithoutThumbnail;
            }
        }
        else
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                if (bubbleData.shouldHideSenderName)
                {
                    cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingTextMessageEncryptedWithPaginationTitleWithoutSenderName : RoomTimelineCellIdentifierIncomingTextMessageWithPaginationTitleWithoutSenderName;
                }
                else
                {
                    cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingTextMessageEncryptedWithPaginationTitle : RoomTimelineCellIdentifierIncomingTextMessageWithPaginationTitle;
                }
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingTextMessageEncryptedWithoutSenderInfo : RoomTimelineCellIdentifierIncomingTextMessageWithoutSenderInfo;
            }
            else if (bubbleData.shouldHideSenderName)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingTextMessageEncryptedWithoutSenderName : RoomTimelineCellIdentifierIncomingTextMessageWithoutSenderName;
            }
            else
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierIncomingTextMessageEncrypted : RoomTimelineCellIdentifierIncomingTextMessage;
            }
        }
    }
    else
    {
        // Handle here outgoing bubbles
        if (bubbleData.isAttachmentWithThumbnail)
        {
            // Check whether the provided celldata corresponds to a selected sticker
            if (customizedRoomDataSource.selectedEventId && (bubbleData.attachment.type == MXKAttachmentTypeSticker) && [bubbleData.attachment.eventId isEqualToString:customizedRoomDataSource.selectedEventId])
            {
                cellIdentifier = RoomTimelineCellIdentifierSelectedSticker;
            }
            else if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingAttachmentEncryptedWithPaginationTitle : RoomTimelineCellIdentifierOutgoingAttachmentWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingAttachmentEncryptedWithoutSenderInfo : RoomTimelineCellIdentifierOutgoingAttachmentWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingAttachmentEncrypted : RoomTimelineCellIdentifierOutgoingAttachment;
            }
        }
        else if (bubbleData.isAttachment)
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingAttachmentWithoutThumbnailEncryptedWithPaginationTitle : RoomTimelineCellIdentifierOutgoingAttachmentWithoutThumbnailWithPaginationTitle;
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingAttachmentWithoutThumbnailEncryptedWithoutSenderInfo : RoomTimelineCellIdentifierOutgoingAttachmentWithoutThumbnailWithoutSenderInfo;
            }
            else
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingAttachmentWithoutThumbnailEncrypted : RoomTimelineCellIdentifierOutgoingAttachmentWithoutThumbnail;
            }
        }
        else
        {
            if (bubbleData.isPaginationFirstBubble)
            {
                if (bubbleData.shouldHideSenderName)
                {
                    cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingTextMessageEncryptedWithPaginationTitleWithoutSenderName : RoomTimelineCellIdentifierOutgoingTextMessageWithPaginationTitleWithoutSenderName;
                }
                else
                {
                    cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingTextMessageEncryptedWithPaginationTitle : RoomTimelineCellIdentifierOutgoingTextMessageWithPaginationTitle;
                }
            }
            else if (bubbleData.shouldHideSenderInformation)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingTextMessageEncryptedWithoutSenderInfo : RoomTimelineCellIdentifierOutgoingTextMessageWithoutSenderInfo;
            }
            else if (bubbleData.shouldHideSenderName)
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingTextMessageEncryptedWithoutSenderName : RoomTimelineCellIdentifierOutgoingTextMessageWithoutSenderName;
            }
            else
            {
                cellIdentifier = showEncryptionBadge ? RoomTimelineCellIdentifierOutgoingTextMessageEncrypted : RoomTimelineCellIdentifierOutgoingTextMessage;
            }
        }
    }
    
    return cellIdentifier;
}

#pragma mark - MXKDataSource delegate

- (void)dataSource:(MXKDataSource *)dataSource didRecognizeAction:(NSString *)actionIdentifier inCell:(id<MXKCellRendering>)cell userInfo:(NSDictionary *)userInfo
{
    // Handle here user actions on bubbles for Vector app
    if (self.customizedRoomDataSource)
    {
        id<MXKRoomBubbleCellDataStoring> bubbleData;
        
        if ([cell isKindOfClass:[MXKRoomBubbleTableViewCell class]])
        {
            MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell*)cell;
            bubbleData = roomBubbleTableViewCell.bubbleData;
        }
        
        
        if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellTapOnAvatarView])
        {
            MXRoomMember *member = [self.roomDataSource.roomState.members memberWithUserId:userInfo[kMXKRoomBubbleCellUserIdKey]];
            [self showMemberDetails:member];
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellLongPressOnAvatarView])
        {
            // Add the member display name in text input
            MXRoomMember *roomMember = [self.roomDataSource.roomState.members memberWithUserId:userInfo[kMXKRoomBubbleCellUserIdKey]];
            if (roomMember)
            {
                [self mention:roomMember];
            }
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellStopShareButtonPressed])
        {
            NSString *beaconInfoEventId;
            
            if ([bubbleData isKindOfClass:[RoomBubbleCellData class]])
            {
                RoomBubbleCellData *roomBubbleCellData = (RoomBubbleCellData*)bubbleData;
                beaconInfoEventId = roomBubbleCellData.beaconInfoSummary.id;
            }
            
            [self.delegate roomViewControllerDidStopLiveLocationSharing:self beaconInfoEventId:beaconInfoEventId];
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellRetryShareButtonPressed])
        {
            MXEvent *selectedEvent = userInfo[kMXKRoomBubbleCellEventKey];
            if (selectedEvent)
            {
                // TODO: - Implement retry live location action
            }
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellTapOnMessageTextView] || [actionIdentifier isEqualToString:kMXKRoomBubbleCellTapOnContentView])
        {
            // Retrieve the tapped event
            MXEvent *tappedEvent = userInfo[kMXKRoomBubbleCellEventKey];
            
            // Check whether a selection already exist or not
            if (self.customizedRoomDataSource.selectedEventId)
            {
                [self cancelEventSelection];
            }
            else if (bubbleData.tag == RoomBubbleCellDataTagLiveLocation)
            {
                [self.delegate roomViewController:self didRequestLiveLocationPresentationForBubbleData:bubbleData];
            }
            else if (tappedEvent)
            {
                if (tappedEvent.eventType == MXEventTypeRoomCreate)
                {
                    // Handle tap on RoomPredecessorBubbleCell
                    MXRoomCreateContent *createContent = [MXRoomCreateContent modelFromJSON:tappedEvent.content];
                    NSString *predecessorRoomId = createContent.roomPredecessorInfo.roomId;
                    
                    if (predecessorRoomId)
                    {
                        // Show predecessor room
                        Analytics.shared.viewRoomTrigger = AnalyticsViewRoomTriggerTombstone;
                        [self showRoomWithId:predecessorRoomId];
                    }
                    else
                    {
                        // Show contextual menu on single tap if bubble is not collapsed
                        if (bubbleData.collapsed)
                        {
                            // Do nothing here as we display room creation modal only if the user taps on the room name
                        }
                        else
                        {
                            [self showContextualMenuForEvent:tappedEvent fromSingleTapGesture:YES cell:cell animated:YES];
                        }
                    }
                }
                else if (bubbleData.tag == RoomBubbleCellDataTagCall)
                {
                    if ([bubbleData isKindOfClass:[RoomBubbleCellData class]])
                    {
                        //  post notification `RoomCallTileTapped`
                        [[NSNotificationCenter defaultCenter] postNotificationName:RoomCallTileTappedNotification object:bubbleData];
                        
                        preventBubblesTableViewScroll = YES;
                        [self selectEventWithId:tappedEvent.eventId];
                    }
                }
                else if (bubbleData.tag == RoomBubbleCellDataTagGroupCall)
                {
                    if ([bubbleData isKindOfClass:[RoomBubbleCellData class]])
                    {
                        //  post notification `RoomGroupCallTileTapped`
                        [[NSNotificationCenter defaultCenter] postNotificationName:RoomGroupCallTileTappedNotification object:bubbleData];
                        
                        preventBubblesTableViewScroll = YES;
                        [self selectEventWithId:tappedEvent.eventId];
                    }
                }
                else
                {
                    // Show contextual menu on single tap if bubble is not collapsed
                    if (bubbleData.collapsed)
                    {
                        [self selectEventWithId:tappedEvent.eventId];
                    }
                    else
                    {
                        if (tappedEvent.location) {
                            [_delegate roomViewController:self didRequestLocationPresentationForEvent:tappedEvent bubbleData:bubbleData];
                        } else {
                            [self showContextualMenuForEvent:tappedEvent fromSingleTapGesture:YES cell:cell animated:YES];
                        }
                    }
                }
            }
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellTapOnOverlayContainer])
        {
            // Cancel the current event selection
            [self cancelEventSelection];
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellRiotEditButtonPressed])
        {
            [self dismissKeyboard];
            
            MXEvent *selectedEvent = userInfo[kMXKRoomBubbleCellEventKey];
            
            if (selectedEvent)
            {
                [self showContextualMenuForEvent:selectedEvent fromSingleTapGesture:YES cell:cell animated:YES];
            }
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellKeyVerificationIncomingRequestAcceptPressed])
        {
            NSString *eventId = userInfo[kMXKRoomBubbleCellEventIdKey];
            
            RoomDataSource *roomDataSource = (RoomDataSource*)self.roomDataSource;
            
            [roomDataSource acceptVerificationRequestForEventId:eventId success:^{
                
            } failure:^(NSError *error) {
                [self showError:error];
            }];
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellKeyVerificationIncomingRequestDeclinePressed])
        {
            NSString *eventId = userInfo[kMXKRoomBubbleCellEventIdKey];
            
            RoomDataSource *roomDataSource = (RoomDataSource*)self.roomDataSource;
            
            [roomDataSource declineVerificationRequestForEventId:eventId success:^{
                
            } failure:^(NSError *error) {
                [self showError:error];
            }];
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellTapOnAttachmentView])
        {
            if (((MXKRoomBubbleTableViewCell*)cell).bubbleData.attachment.eventSentState == MXEventSentStateFailed)
            {
                // Shortcut: when clicking on an unsent media, show the action sheet to resend it
                NSString *eventId = ((MXKRoomBubbleTableViewCell*)cell).bubbleData.attachment.eventId;
                MXEvent *selectedEvent = [self.roomDataSource eventWithEventId:eventId];
                
                if (selectedEvent)
                {
                    [self dataSource:dataSource didRecognizeAction:kMXKRoomBubbleCellRiotEditButtonPressed inCell:cell userInfo:@{kMXKRoomBubbleCellEventKey:selectedEvent}];
                }
                else
                {
                    MXLogDebug(@"[RoomViewController] didRecognizeAction:inCell:userInfo tap on attachment with event state MXEventSentStateFailed. Selected event is nil for event id %@", eventId);
                }
            }
            else if (((MXKRoomBubbleTableViewCell*)cell).bubbleData.attachment.type == MXKAttachmentTypeSticker)
            {
                // We don't open the attachments viewer when the user taps on a sticker.
                // We consider this tap like a selection.
                
                // Check whether a selection already exist or not
                if (self.customizedRoomDataSource.selectedEventId)
                {
                    [self cancelEventSelection];
                }
                else
                {
                    // Highlight this event in displayed message
                    [self selectEventWithId:((MXKRoomBubbleTableViewCell*)cell).bubbleData.attachment.eventId];
                }
            }
            else
            {
                // Keep default implementation
                [super dataSource:dataSource didRecognizeAction:actionIdentifier inCell:cell userInfo:userInfo];
            }
        }
        else if ([actionIdentifier isEqualToString:kRoomEncryptedDataBubbleCellTapOnEncryptionIcon])
        {
            // Retrieve the tapped event
            MXEvent *tappedEvent = userInfo[kMXKRoomBubbleCellEventKey];
            
            if (tappedEvent)
            {
                [self showEncryptionInformation:tappedEvent];
            }
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellTapOnReceiptsContainer])
        {
            MXKReceiptSendersContainer *container = userInfo[kMXKRoomBubbleCellReceiptsContainerKey];
            [ReadReceiptsViewController openInViewController:self fromContainer:container withSession:self.mainSession];
        }
        else if ([actionIdentifier isEqualToString:kRoomMembershipExpandedBubbleCellTapOnCollapseButton])
        {
            // Reset the selection before collapsing
            self.customizedRoomDataSource.selectedEventId = nil;
            
            [self.roomDataSource collapseRoomBubble:((MXKRoomBubbleTableViewCell*)cell).bubbleData collapsed:YES];
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellLongPressOnEvent])
        {
            MXEvent *tappedEvent = userInfo[kMXKRoomBubbleCellEventKey];
            
            if (!bubbleData.collapsed)
            {
                [self handleLongPressFromCell:cell withTappedEvent:tappedEvent];
            }
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellLongPressOnReactionView])
        {
            NSString *tappedEventId = userInfo[kMXKRoomBubbleCellEventIdKey];
            if (tappedEventId)
            {
                [self showReactionHistoryForEventId:tappedEventId animated:YES];
            }
        }
        else if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellTapOnAddReaction])
        {
            NSString *tappedEventId = userInfo[kMXKRoomBubbleCellEventIdKey];
            if (tappedEventId)
            {
                [self showEmojiPickerForEventId:tappedEventId];
            }
        }
        else if ([actionIdentifier isEqualToString:RoomDirectCallStatusCell.callBackAction])
        {
            MXEvent *callInviteEvent = userInfo[kMXKRoomBubbleCellEventKey];
            MXCallInviteEventContent *eventContent = [MXCallInviteEventContent modelFromJSON:callInviteEvent.content];
            
            [self placeCallWithVideo2:eventContent.isVideoCall];
        }
        else if ([actionIdentifier isEqualToString:RoomDirectCallStatusCell.declineAction])
        {
            MXEvent *callInviteEvent = userInfo[kMXKRoomBubbleCellEventKey];
            MXCallInviteEventContent *eventContent = [MXCallInviteEventContent modelFromJSON:callInviteEvent.content];
            
            MXCall *call = [self.mainSession.callManager callWithCallId:eventContent.callId];
            [call hangup];
        }
        else if ([actionIdentifier isEqualToString:RoomDirectCallStatusCell.answerAction])
        {
            MXEvent *callInviteEvent = userInfo[kMXKRoomBubbleCellEventKey];
            MXCallInviteEventContent *eventContent = [MXCallInviteEventContent modelFromJSON:callInviteEvent.content];
            
            MXCall *call = [self.mainSession.callManager callWithCallId:eventContent.callId];
            [call answer];
        }
        else if ([actionIdentifier isEqualToString:RoomDirectCallStatusCell.endCallAction])
        {
            MXEvent *callInviteEvent = userInfo[kMXKRoomBubbleCellEventKey];
            MXCallInviteEventContent *eventContent = [MXCallInviteEventContent modelFromJSON:callInviteEvent.content];
            
            MXCall *call = [self.mainSession.callManager callWithCallId:eventContent.callId];
            [call hangup];
        }
        else if ([actionIdentifier isEqualToString:RoomGroupCallStatusCell.joinAction] ||
                 [actionIdentifier isEqualToString:RoomGroupCallStatusCell.answerAction])
        {
            MXWeakify(self);

            // Check app permissions first
            [MXKTools checkAccessForCall:YES
             manualChangeMessageForAudio:[VectorL10n microphoneAccessNotGrantedForCall:AppInfo.current.displayName]
             manualChangeMessageForVideo:[VectorL10n cameraAccessNotGrantedForCall:AppInfo.current.displayName]
               showPopUpInViewController:self completionHandler:^(BOOL granted) {
                
                MXStrongifyAndReturnIfNil(self);
                if (granted)
                {
                    // Present the Jitsi view controller
                    Widget *jitsiWidget = [self.customizedRoomDataSource jitsiWidget];
                    if (jitsiWidget)
                    {
                        [self showJitsiCallWithWidget:jitsiWidget];
                    }
                }
                else
                {
                    MXLogDebug(@"[RoomVC] didRecognizeAction:inCell:userInfo Warning: The application does not have the permission to join/answer the group call");
                }
            }];
            
            MXEvent *widgetEvent = userInfo[kMXKRoomBubbleCellEventKey];
            Widget *widget = [[Widget alloc] initWithWidgetEvent:widgetEvent
                                                 inMatrixSession:self.customizedRoomDataSource.mxSession];
            [[JitsiService shared] resetDeclineForWidgetWithId:widget.widgetId];
        }
        else if ([actionIdentifier isEqualToString:RoomGroupCallStatusCell.leaveAction])
        {
            [self endActiveJitsiCall];
            [self reloadBubblesTable:YES];
        }
        else if ([actionIdentifier isEqualToString:RoomGroupCallStatusCell.declineAction])
        {
            MXEvent *widgetEvent = userInfo[kMXKRoomBubbleCellEventKey];
            Widget *widget = [[Widget alloc] initWithWidgetEvent:widgetEvent
                                                 inMatrixSession:self.customizedRoomDataSource.mxSession];
            [[JitsiService shared] declineWidgetWithId:widget.widgetId];
            [self reloadBubblesTable:YES];
        }
        else if ([actionIdentifier isEqualToString:RoomCreationIntroCell.tapOnAvatarView])
        {
            [self showRoomAvatarChange];
        }
        else if ([actionIdentifier isEqualToString:RoomCreationIntroCell.tapOnAddParticipants])
        {
            [self showAddParticipants];
        }
        else if ([actionIdentifier isEqualToString:RoomCreationIntroCell.tapOnAddTopic])
        {
            [self showRoomTopicChange];
        }
        else if ([actionIdentifier isEqualToString:RoomCreationIntroCell.tapOnRoomName])
        {
            [self showRoomCreationModal];
        }
        else
        {
            // Keep default implementation for other actions
            [super dataSource:dataSource didRecognizeAction:actionIdentifier inCell:cell userInfo:userInfo];
        }
    }
    else
    {
        // Keep default implementation for other actions
        [super dataSource:dataSource didRecognizeAction:actionIdentifier inCell:cell userInfo:userInfo];
    }
}

// Display the additiontal event actions menu
- (void)showAdditionalActionsMenuForEvent:(MXEvent*)selectedEvent inCell:(id<MXKCellRendering>)cell animated:(BOOL)animated
{
    MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell *)cell;
    MXKAttachment *attachment = roomBubbleTableViewCell.bubbleData.attachment;
    
    BOOL isJitsiCallEvent = NO;
    switch (selectedEvent.eventType) {
        case MXEventTypeCustom:
            if ([selectedEvent.type isEqualToString:kWidgetMatrixEventTypeString]
                || [selectedEvent.type isEqualToString:kWidgetModularEventTypeString])
            {
                Widget *widget = [[Widget alloc] initWithWidgetEvent:selectedEvent inMatrixSession:self.roomDataSource.mxSession];
                if ([widget.type isEqualToString:kWidgetTypeJitsiV1] ||
                    [widget.type isEqualToString:kWidgetTypeJitsiV2])
                {
                    isJitsiCallEvent = YES;
                }
            }
        default:
            break;
    }
    
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    [self.eventMenuBuilder reset];
    
    MXWeakify(self);
    
    BOOL showThreadOption = [self showThreadOptionForEvent:selectedEvent];
    if (showThreadOption && [self canCopyEvent:selectedEvent andCell:cell])
    {
        MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell *)cell;
        MXKRoomBubbleCellData *cellData = roomBubbleTableViewCell.bubbleData;
        [self.eventMenuBuilder addItemWithType:EventMenuItemTypeCopy
                                        action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionCopy]
                                                                        style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * action) {
            MXStrongifyAndReturnIfNil(self);
            
            [self cancelEventSelection];
            
            [self copyEvent:selectedEvent inCell:cell withCellData:cellData];
        }]];
    }
    
    // Add actions for a failed event
    if (selectedEvent.sentState == MXEventSentStateFailed)
    {
        [self.eventMenuBuilder addItemWithType:EventMenuItemTypeRetrySending
                                        action:[UIAlertAction actionWithTitle:[VectorL10n retry]
                                                                        style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * action) {
            MXStrongifyAndReturnIfNil(self);
            
            [self cancelEventSelection];
            
            // Let the datasource resend. It will manage local echo, etc.
            [self.roomDataSource resendEventWithEventId:selectedEvent.eventId success:nil failure:nil];
        }]];
        
        [self.eventMenuBuilder addItemWithType:EventMenuItemTypeRemove
                                        action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionDelete]
                                                                        style:UIAlertActionStyleDestructive
                                                                      handler:^(UIAlertAction * action) {
            MXStrongifyAndReturnIfNil(self);
            
            [self cancelEventSelection];
            
            [self.roomDataSource removeEventWithEventId:selectedEvent.eventId];
        }]];
    }
    
    // View in room action
    if (self.roomDataSource.threadId && [selectedEvent.eventId isEqualToString:self.roomDataSource.threadId])
    {
        //  if in the thread and selected event is the root event
        //  add "View in room" action
        [self.eventMenuBuilder addItemWithType:EventMenuItemTypeViewInRoom
                                        action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionViewInRoom]
                                                                        style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * action) {
            MXStrongifyAndReturnIfNil(self);
            [self.delegate roomViewController:self
                               showRoomWithId:self.roomDataSource.roomId
                                      eventId:selectedEvent.eventId];
        }]];
    }
    
    // Add actions for text message
    if (!attachment)
    {
        // Retrieved data related to the selected event
        NSArray *components = roomBubbleTableViewCell.bubbleData.bubbleComponents;
        MXKRoomBubbleComponent *selectedComponent;
        for (selectedComponent in components)
        {
            if ([selectedComponent.event.eventId isEqualToString:selectedEvent.eventId])
            {
                break;
            }
            selectedComponent = nil;
        }
        
        
        // Check status of the selected event
        if (selectedEvent.sentState == MXEventSentStatePreparing ||
            selectedEvent.sentState == MXEventSentStateEncrypting ||
            selectedEvent.sentState == MXEventSentStateSending)
        {
            [self.eventMenuBuilder addItemWithType:EventMenuItemTypeCancelSending
                                            action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionCancelSend]
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * action) {
                MXStrongifyAndReturnIfNil(self);
                
                self->currentAlert = nil;
                
                // Cancel and remove the outgoing message
                [self.roomDataSource.room cancelSendingOperation:selectedEvent.eventId];
                [self.roomDataSource removeEventWithEventId:selectedEvent.eventId];
                
                [self cancelEventSelection];
            }]];
        }
        
        if (selectedEvent.sentState == MXEventSentStateSent &&
            !selectedEvent.isTimelinePollEvent &&
            // Forwarding of live-location shares still to be implemented
            selectedEvent.eventType != MXEventTypeBeaconInfo)
        {
            [self.eventMenuBuilder addItemWithType:EventMenuItemTypeForward
                                            action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionForward]
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * action) {
                MXStrongifyAndReturnIfNil(self);

                [self cancelEventSelection];

                [self presentEventForwardingDialogForSelectedEvent:selectedEvent];
            }]];
        }
        
        if (!isJitsiCallEvent && BuildSettings.messageDetailsAllowShare && !selectedEvent.isTimelinePollEvent &&
            selectedEvent.eventType != MXEventTypeBeaconInfo)
        {
            [self.eventMenuBuilder addItemWithType:EventMenuItemTypeShare
                                            action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionShare]
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * action) {
                MXStrongifyAndReturnIfNil(self);
                
                [self cancelEventSelection];
                
                UIActivityViewController *activityViewController = nil;
                if (selectedEvent.location) {
                    activityViewController = [self.delegate roomViewController:self locationShareActivityViewControllerForEvent:selectedEvent];
                }
                
                if (activityViewController == nil && selectedComponent.textMessage) {
                    NSArray *activityItems = @[selectedComponent.textMessage];
                    activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
                }
                
                if (activityViewController)
                {
                    activityViewController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
                    activityViewController.popoverPresentationController.sourceView = roomBubbleTableViewCell;
                    activityViewController.popoverPresentationController.sourceRect = roomBubbleTableViewCell.bounds;
                    
                    [self presentViewController:activityViewController animated:YES completion:nil];
                }
            }]];
        }
    }
    else // Add action for attachment
    {
        // Forwarding for already sent attachments
        if (selectedEvent.sentState == MXEventSentStateSent && (attachment.type == MXKAttachmentTypeFile ||
                                                                attachment.type == MXKAttachmentTypeImage ||
                                                                attachment.type == MXKAttachmentTypeVideo ||
                                                                attachment.type == MXKAttachmentTypeVoiceMessage)) {
            [self.eventMenuBuilder addItemWithType:EventMenuItemTypeForward
                                            action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionForward]
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * action) {
                MXStrongifyAndReturnIfNil(self);

                [self cancelEventSelection];
                
                [self presentEventForwardingDialogForSelectedEvent:selectedEvent];
            }]];
        }
        
        if (BuildSettings.messageDetailsAllowSave)
        {
            if (attachment.type == MXKAttachmentTypeImage || attachment.type == MXKAttachmentTypeVideo)
            {
                [self.eventMenuBuilder addItemWithType:EventMenuItemTypeSaveMedia
                                                action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionSave]
                                                                                style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction * action) {
                    MXStrongifyAndReturnIfNil(self);
                    
                    [self cancelEventSelection];
                    
                    [self startActivityIndicator];
                    
                    MXWeakify(self);
                    [attachment save:^{
                        MXStrongifyAndReturnIfNil(self);
                        [self stopActivityIndicator];
                    } failure:^(NSError *error) {
                        MXStrongifyAndReturnIfNil(self);
                        [self stopActivityIndicator];
                        
                        //Alert user
                        [self showError:error];
                    }];
                    
                    // Start animation in case of download during attachment preparing
                    [roomBubbleTableViewCell startProgressUI];
                }]];
            }
        }
        
        // Check status of the selected event
        if (selectedEvent.sentState == MXEventSentStatePreparing ||
            selectedEvent.sentState == MXEventSentStateEncrypting ||
            selectedEvent.sentState == MXEventSentStateUploading ||
            selectedEvent.sentState == MXEventSentStateSending)
        {
            // Upload id is stored in attachment url (nasty trick)
            NSString *uploadId = roomBubbleTableViewCell.bubbleData.attachment.contentURL;
            if ([MXMediaManager existingUploaderWithId:uploadId])
            {
                [self.eventMenuBuilder addItemWithType:EventMenuItemTypeCancelSending
                                                action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionCancelSend]
                                                                                style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction * action) {
                    
                    MXStrongifyAndReturnIfNil(self);
                    
                    // Get again the loader
                    MXMediaLoader *loader = [MXMediaManager existingUploaderWithId:uploadId];
                    if (loader)
                    {
                        [loader cancel];
                    }
                    // Hide the progress animation
                    roomBubbleTableViewCell.progressView.hidden = YES;
                    
                    self->currentAlert = nil;
                    
                    // Remove the outgoing message and its related cached file.
                    [[NSFileManager defaultManager] removeItemAtPath:roomBubbleTableViewCell.bubbleData.attachment.cacheFilePath error:nil];
                    [[NSFileManager defaultManager] removeItemAtPath:roomBubbleTableViewCell.bubbleData.attachment.thumbnailCachePath error:nil];
                    
                    // Cancel and remove the outgoing message
                    [self.roomDataSource.room cancelSendingOperation:selectedEvent.eventId];
                    [self.roomDataSource removeEventWithEventId:selectedEvent.eventId];
                    
                    [self cancelEventSelection];
                }]];
            }
        }
        
        if (attachment.type != MXKAttachmentTypeSticker)
        {
            if (BuildSettings.messageDetailsAllowShare)
            {
                [self.eventMenuBuilder addItemWithType:EventMenuItemTypeShare
                                                action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionShare]
                                                                                style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction * action) {
                    MXStrongifyAndReturnIfNil(self);
                    
                    [self cancelEventSelection];
                    
                    [self startActivityIndicator];
                    
                    MXWeakify(self);
                    [attachment prepareShare:^(NSURL *fileURL) {
                        MXStrongifyAndReturnIfNil(self);
                        
                        [self stopActivityIndicator];
                        
                        self->documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
                        [self->documentInteractionController setDelegate:self];
                        self->currentSharedAttachment = attachment;
                        
                        if (![self->documentInteractionController presentOptionsMenuFromRect:self.view.frame inView:self.view animated:YES])
                        {
                            self->documentInteractionController = nil;
                            [attachment onShareEnded];
                            self->currentSharedAttachment = nil;
                        }
                        
                    } failure:^(NSError *error) {
                        [self showError:error];
                        [self stopActivityIndicator];
                    }];
                    
                    // Start animation in case of download during attachment preparing
                    [roomBubbleTableViewCell startProgressUI];
                }]];
            }
        }
    }
    
    // Check status of the selected event
    if (selectedEvent.sentState == MXEventSentStateSent)
    {
        // Check whether download is in progress
        if (selectedEvent.isMediaAttachment)
        {
            NSString *downloadId = roomBubbleTableViewCell.bubbleData.attachment.downloadId;
            if ([MXMediaManager existingDownloaderWithIdentifier:downloadId])
            {
                [self.eventMenuBuilder addItemWithType:EventMenuItemTypeCancelDownloading
                                                action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionCancelDownload]
                                                                                style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction * action) {
                    MXStrongifyAndReturnIfNil(self);
                    
                    [self cancelEventSelection];
                    
                    // Get again the loader
                    MXMediaLoader *loader = [MXMediaManager existingDownloaderWithIdentifier:downloadId];
                    if (loader)
                    {
                        [loader cancel];
                    }
                    // Hide the progress animation
                    roomBubbleTableViewCell.progressView.hidden = YES;
                }]];
            }
        }
        
        if (BuildSettings.messageDetailsAllowPermalink)
        {
            [self.eventMenuBuilder addItemWithType:EventMenuItemTypePermalink
                                            action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionPermalink]
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * action) {
                MXStrongifyAndReturnIfNil(self);
                
                [self cancelEventSelection];
                
                // Create a matrix.to permalink that is common to all matrix clients
                NSString *permalink = [MXTools permalinkToEvent:selectedEvent.eventId inRoom:selectedEvent.roomId];
                NSURL *url = [NSURL URLWithString:permalink];
                
                if (url)
                {
                    MXKPasteboardManager.shared.pasteboard.URL = url;
                    [self.view vc_toastWithMessage:VectorL10n.roomEventCopyLinkInfo
                                             image:AssetImages.linkIcon.image
                                          duration:2.0
                                          position:ToastPositionBottom
                                  additionalMargin:self.roomInputToolbarContainerHeightConstraint.constant];
                }
                else
                {
                    MXLogDebug(@"[RoomViewController] Contextual menu permalink action failed. Permalink is nil room id/event id: %@/%@", selectedEvent.roomId, selectedEvent.eventId);
                }
            }]];
        }
        
        if (BuildSettings.messageDetailsAllowViewSource)
        {
            [self.eventMenuBuilder addItemWithType:EventMenuItemTypeViewSource
                                            action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionViewSource]
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * action) {
                MXStrongifyAndReturnIfNil(self);
                
                [self cancelEventSelection];
                
                // Display event details
                [self showEventDetails:selectedEvent];
            }]];
            
            
            // Add "View Decrypted Source" for e2ee event we can decrypt
            if (selectedEvent.isEncrypted && selectedEvent.clearEvent)
            {
                [self.eventMenuBuilder addItemWithType:EventMenuItemTypeViewDecryptedSource
                                                action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionViewDecryptedSource]
                                                                                style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction * action) {
                    MXStrongifyAndReturnIfNil(self);
                    
                    [self cancelEventSelection];
                    
                    // Display clear event details
                    [self showEventDetails:selectedEvent.clearEvent];
                }]];
            }
        }
        
        // Do not allow to redact the event that enabled encryption (m.room.encryption)
        // because it breaks everything
        if (selectedEvent.eventType != MXEventTypeRoomEncryption)
        {
            NSString *title;
            EventMenuItemType itemType;
            if (selectedEvent.eventType == MXEventTypePollStart)
            {
                title = [VectorL10n roomEventActionRemovePoll];
                itemType = EventMenuItemTypeRemovePoll;
            }
            else
            {
                title = [VectorL10n roomEventActionRedact];
                itemType = EventMenuItemTypeRemove;
            }
            
            [self.eventMenuBuilder addItemWithType:itemType
                                            action:[UIAlertAction actionWithTitle:title
                                                                            style:UIAlertActionStyleDestructive
                                                                          handler:^(UIAlertAction * action) {
                MXStrongifyAndReturnIfNil(self);
                
                [self cancelEventSelection];
                
                [self startActivityIndicator];
                
                NSArray<NSString *>* relationTypes = nil;
                // If it's a voice broadcast, delete the selected event and all related events.
                if (selectedEvent.eventType == MXEventTypeCustom && [selectedEvent.type isEqualToString:VoiceBroadcastSettings.voiceBroadcastInfoContentKeyType]) {
                    relationTypes = @[MXEventRelationTypeReference];
                }
                
                MXWeakify(self);
                [self.roomDataSource.room redactEvent:selectedEvent.eventId withRelations:relationTypes reason:nil success:^{
                    MXStrongifyAndReturnIfNil(self);
                    [self stopActivityIndicator];
                } failure:^(NSError *error) {
                    MXStrongifyAndReturnIfNil(self);
                    [self stopActivityIndicator];
                    
                    MXLogDebug(@"[RoomVC] Redact event (%@) failed", selectedEvent.eventId);
                    //Alert user
                    [self showError:error];
                }];
            }]];
        }
        
        if (selectedEvent.eventType == MXEventTypePollStart && [selectedEvent.sender isEqualToString:self.mainSession.myUserId])
        {
            if ([self.delegate roomViewController:self canEndPollWithEventIdentifier:selectedEvent.eventId])
            {
                [self.eventMenuBuilder addItemWithType:EventMenuItemTypeEndPoll
                                                action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionEndPoll]
                                                                                style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction * action) {
                    MXStrongifyAndReturnIfNil(self);
                    
                    [self.delegate roomViewController:self endPollWithEventIdentifier:selectedEvent.eventId];
                    
                    [self hideContextualMenuAnimated:YES];
                }]];
            }
        }
        
        // Add reaction history if event contains reactions
        if (roomBubbleTableViewCell.bubbleData.reactions[selectedEvent.eventId].aggregatedReactionsWithNonZeroCount)
        {
            [self.eventMenuBuilder addItemWithType:EventMenuItemTypeReactionHistory
                                            action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionReactionHistory]
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * action) {
                MXStrongifyAndReturnIfNil(self);
                
                [self cancelEventSelection];
                
                // Show reaction history
                [self showReactionHistoryForEventId:selectedEvent.eventId animated:YES];
            }]];
        }
        
        if (![selectedEvent.sender isEqualToString:self.mainSession.myUserId] && RiotSettings.shared.roomContextualMenuShowReportContentOption)
        {
            [self.eventMenuBuilder addItemWithType:EventMenuItemTypeReport
                                            action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionReport]
                                                                            style:UIAlertActionStyleDestructive
                                                                          handler:^(UIAlertAction * action) {
                MXStrongifyAndReturnIfNil(self);
                
                [self cancelEventSelection];
                
                // Prompt user to enter a description of the problem content.
                UIAlertController *reportReasonAlert = [UIAlertController alertControllerWithTitle:[VectorL10n roomEventActionReportPromptReason]
                                                                                           message:nil
                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                
                [reportReasonAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.secureTextEntry = NO;
                    textField.placeholder = nil;
                    textField.keyboardType = UIKeyboardTypeDefault;
                }];
                
                MXWeakify(self);
                [reportReasonAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n ok] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                    MXStrongifyAndReturnIfNil(self);
                    
                    NSString *text = [self->currentAlert textFields].firstObject.text;
                    self->currentAlert = nil;
                    
                    [self startActivityIndicator];
                    
                    MXWeakify(self);
                    [self.roomDataSource.room reportEvent:selectedEvent.eventId score:-100 reason:text success:^{
                        MXStrongifyAndReturnIfNil(self);
                        
                        [self stopActivityIndicator];
                        
                        // Prompt user to ignore content from this user
                        UIAlertController *ignoreUserAlert = [UIAlertController alertControllerWithTitle:[VectorL10n roomEventActionReportPromptIgnoreUser]
                                                                                                 message:nil
                                                                                          preferredStyle:UIAlertControllerStyleAlert];
                        
                        MXWeakify(self);
                        [ignoreUserAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n yes] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                            
                            MXStrongifyAndReturnIfNil(self);
                            self->currentAlert = nil;
                            
                            [self startActivityIndicator];
                            
                            MXWeakify(self);
                            // Add the user to the blacklist: ignored users
                            [self.mainSession ignoreUsers:@[selectedEvent.sender] success:^{
                                MXStrongifyAndReturnIfNil(self);
                                [self stopActivityIndicator];
                            } failure:^(NSError *error) {
                                MXStrongifyAndReturnIfNil(self);
                                [self stopActivityIndicator];
                                
                                MXLogDebug(@"[RoomVC] Ignore user (%@) failed", selectedEvent.sender);
                                //Alert user
                                [self showError:error];
                            }];
                        }]];
                        
                        [ignoreUserAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n no] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                            MXStrongifyAndReturnIfNil(self);
                            self->currentAlert = nil;
                        }]];
                        
                        [self presentViewController:ignoreUserAlert animated:YES completion:nil];
                        self->currentAlert = ignoreUserAlert;
                        
                    } failure:^(NSError *error) {
                        MXStrongifyAndReturnIfNil(self);
                        [self stopActivityIndicator];
                        
                        MXLogDebug(@"[RoomVC] Report event (%@) failed", selectedEvent.eventId);
                        //Alert user
                        [self showError:error];
                        
                    }];
                }]];
                
                [reportReasonAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel] style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
                    MXStrongifyAndReturnIfNil(self);
                    self->currentAlert = nil;
                }]];
                
                [self presentViewController:reportReasonAlert animated:YES completion:nil];
                self->currentAlert = reportReasonAlert;
            }]];
        }
        
        if (!isJitsiCallEvent && self.roomDataSource.room.summary.isEncrypted)
        {
            [self.eventMenuBuilder addItemWithType:EventMenuItemTypeViewEncryption
                                            action:[UIAlertAction actionWithTitle:[VectorL10n roomEventActionViewEncryption]
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * action) {
                MXStrongifyAndReturnIfNil(self);
                
                [self cancelEventSelection];
                
                // Display encryption details
                [self showEncryptionInformation:selectedEvent];
            }]];
        }
    }

    [self.eventMenuBuilder addItemWithType:EventMenuItemTypeCancel
                                    action:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                                    style:UIAlertActionStyleCancel
                                                                  handler:^(UIAlertAction * action) {
        MXStrongifyAndReturnIfNil(self);

        [self hideContextualMenuAnimated:YES];
    }]];
    
    // Do not display empty action sheet
    if (!self.eventMenuBuilder.isEmpty)
    {
        UIAlertController *actionsMenu = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        //  build actions and add them to the alert
        NSArray<UIAlertAction*> *actions = [self.eventMenuBuilder build];
        for (UIAlertAction *action in actions)
        {
            [actionsMenu addAction:action];
        }
        
        NSInteger bubbleComponentIndex = [roomBubbleTableViewCell.bubbleData bubbleComponentIndexForEventId:selectedEvent.eventId];
        
        CGRect sourceRect = [roomBubbleTableViewCell componentFrameInContentViewForIndex:bubbleComponentIndex];
        
        [actionsMenu mxk_setAccessibilityIdentifier:@"RoomVCEventMenuAlert"];
        [actionsMenu popoverPresentationController].sourceView = roomBubbleTableViewCell;
        [actionsMenu popoverPresentationController].sourceRect = sourceRect;
        [self dismissKeyboard];
        [self presentViewController:actionsMenu animated:animated completion:nil];
        currentAlert = actionsMenu;
    }
}

- (void)presentEventForwardingDialogForSelectedEvent:(MXEvent *)selectedEvent
{
    ForwardingShareItemSender *shareItemSender = [[ForwardingShareItemSender alloc] initWithEvent:selectedEvent];
    self.shareManager = [[ShareManager alloc] initWithShareItemSender:shareItemSender
                                                                 type:ShareManagerTypeForward
                                                              session:self.mainSession];
    
    MXWeakify(self);
    [self.shareManager setCompletionCallback:^(ShareManagerResult result) {
        MXStrongifyAndReturnIfNil(self);
        if ([self.presentedViewController isEqual:self.shareManager.mainViewController])
        {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        self.shareManager = nil;
    }];
    
    [self presentViewController:self.shareManager.mainViewController animated:YES completion:nil];
}

- (BOOL)dataSource:(MXKDataSource *)dataSource shouldDoAction:(NSString *)actionIdentifier inCell:(id<MXKCellRendering>)cell userInfo:(NSDictionary *)userInfo defaultValue:(BOOL)defaultValue
{
    BOOL shouldDoAction = defaultValue;
    
    if ([actionIdentifier isEqualToString:kMXKRoomBubbleCellShouldInteractWithURL])
    {
        // Try to catch universal link supported by the app
        NSURL *url = userInfo[kMXKRoomBubbleCellUrl];
        // Retrieve the type of interaction expected with the URL (See UITextItemInteraction)
        NSNumber *urlItemInteractionValue = userInfo[kMXKRoomBubbleCellUrlItemInteraction];
        
        RoomMessageURLType roomMessageURLType = RoomMessageURLTypeUnknown;
        
        if (url)
        {
            roomMessageURLType = [self.roomMessageURLParser parseURL:url];
        }
        
        // When a link refers to a room alias/id, a user id or an event id, the non-ASCII characters (like '#' in room alias) has been escaped
        // to be able to convert it into a legal URL string.
        NSString *absoluteURLString = [url.absoluteString stringByRemovingPercentEncoding];
        
        // If the link can be open it by the app, let it do
        if ([Tools isUniversalLink:url])
        {
            shouldDoAction = NO;
            
            [self handleUniversalLinkURL:url];
        }
        // Open a detail screen about the clicked user
        else if ([MXTools isMatrixUserIdentifier:absoluteURLString])
        {
            shouldDoAction = NO;
            
            NSString *userId = absoluteURLString;
            
            MXRoomMember* member = [self.roomDataSource.roomState.members memberWithUserId:userId];
            if (member)
            {
                // Use the room member detail VC for room members
                [self showMemberDetails:member];
            }
            else
            {
                // Use the contact detail VC for other users
                MXUser *user = [self.roomDataSource.room.mxSession userWithUserId:userId];
                if (user)
                {
                    selectedContact = [[MXKContact alloc] initMatrixContactWithDisplayName:((user.displayname.length > 0) ? user.displayname : user.userId) andMatrixID:user.userId];
                }
                else
                {
                    selectedContact = [[MXKContact alloc] initMatrixContactWithDisplayName:userId andMatrixID:userId];
                }
                [self performSegueWithIdentifier:@"showContactDetails" sender:self];
            }
        }
        // Open the clicked room
        else if ([MXTools isMatrixRoomIdentifier:absoluteURLString] || [MXTools isMatrixRoomAlias:absoluteURLString])
        {
            shouldDoAction = NO;
            
            NSString *roomIdOrAlias = absoluteURLString;
            
            // Create a permalink to open or preview the room.
            NSString *permalink = [MXTools permalinkToRoom:roomIdOrAlias];
            NSURL *permalinkURL = [NSURL URLWithString:permalink];
            
            [self handleUniversalLinkURL:permalinkURL];
        }
        else if ([absoluteURLString hasPrefix:EventFormatterOnReRequestKeysLinkAction])
        {
            NSArray<NSString*> *arguments = [absoluteURLString componentsSeparatedByString:EventFormatterLinkActionSeparator];
            if (arguments.count > 1)
            {
                NSString *eventId = arguments[1];
                MXEvent *event = [self.roomDataSource eventWithEventId:eventId];
                
                if (event)
                {
                    [self reRequestKeysAndShowExplanationAlert:event];
                }
            }
        }
        else if ([absoluteURLString hasPrefix:EventFormatterEditedEventLinkAction])
        {
            NSArray<NSString*> *arguments = [absoluteURLString componentsSeparatedByString:EventFormatterLinkActionSeparator];
            if (arguments.count > 1)
            {
                NSString *eventId = arguments[1];
                [self showEditHistoryForEventId:eventId animated:YES];
            }
            shouldDoAction = NO;
        }
        else if (url && urlItemInteractionValue)
        {
            // Fallback case for external links
            switch (urlItemInteractionValue.integerValue) {
                case UITextItemInteractionInvokeDefaultAction:
                {
                    switch (roomMessageURLType) {
                        case RoomMessageURLTypeAppleDataDetector:
                            // Keep the default OS behavior on single tap when UITextView data detector detect a known type.
                            shouldDoAction = YES;
                            break;
                        case RoomMessageURLTypeDummy:
                            // Do nothing for dummy links
                            shouldDoAction = NO;
                            break;
                        case RoomMessageURLTypeHttp:
                            shouldDoAction = YES;
                            break;
                        default:
                        {
                            MXEvent *tappedEvent = userInfo[kMXKRoomBubbleCellEventKey];
                            URLValidationResult *result = [URLValidator validateTappedURL:url in:tappedEvent];
                            if (result.shouldShowConfirmationAlert)
                            {
                                [self showDifferentURLsAlertFor:url
                                                  visibleURLString:result.visibleURLString];
                                return NO;
                            }
                            // Try to open the link
                            [[UIApplication sharedApplication] vc_open:url completionHandler:^(BOOL success) {
                                if (!success)
                                {
                                    [self showUnableToOpenLinkErrorAlert];
                                }
                            }];
                            shouldDoAction = NO;
                            break;
                        }
                    }
                }
                    break;
                case UITextItemInteractionPresentActions:
                {
                    if (roomMessageURLType == RoomMessageURLTypeHttp) {
                        shouldDoAction = YES;
                    } else {
                        // Retrieve the tapped event
                        MXEvent *tappedEvent = userInfo[kMXKRoomBubbleCellEventKey];
                        
                        if (tappedEvent)
                        {
                            // Long press on link, present room contextual menu.
                            [self showContextualMenuForEvent:tappedEvent fromSingleTapGesture:NO cell:cell animated:YES];
                        }
                        
                        shouldDoAction = NO;
                    }
                }
                    break;
                case UITextItemInteractionPreview:
                    // Force touch on link, let MXKRoomBubbleTableViewCell UITextView use default peek and pop behavior.
                    break;
                default:
                    break;
            }
        }
        else
        {
            [self showUnableToOpenLinkErrorAlert];
        }
    }
    
    return shouldDoAction;
}

- (void)selectEventWithId:(NSString*)eventId
{
    [self selectEventWithId:eventId inputToolBarSendMode:RoomInputToolbarViewSendModeSend showTimestamp:YES];
}

- (void)selectEventWithId:(NSString*)eventId inputToolBarSendMode:(RoomInputToolbarViewSendMode)inputToolBarSendMode showTimestamp:(BOOL)showTimestamp
{
    [self setInputToolBarSendMode:inputToolBarSendMode forEventWithId:eventId];
    
    self.customizedRoomDataSource.showBubbleDateTimeOnSelection = showTimestamp;
    self.customizedRoomDataSource.selectedEventId = eventId;
    
    // Force table refresh
    [self dataSource:self.roomDataSource didCellChange:nil];
}

- (void)cancelEventSelection
{
    [self setInputToolBarSendMode:RoomInputToolbarViewSendModeSend forEventWithId:nil];
    
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    self.customizedRoomDataSource.showBubbleDateTimeOnSelection = YES;
    self.customizedRoomDataSource.selectedEventId = nil;
    self.customizedRoomDataSource.highlightedEventId = nil;
    
    [self restoreTextMessageBeforeEditing];
    
    // Force table refresh
    [self dataSource:self.roomDataSource didCellChange:nil];
}

- (void)showUnableToOpenLinkErrorAlert
{
    [self showAlertWithTitle:[VectorL10n error]
                     message:[VectorL10n roomMessageUnableOpenLinkErrorMessage]];
}

- (void)editEventContentWithId:(NSString*)eventId
{
    MXEvent *event = [self.roomDataSource eventWithEventId:eventId];
    
    if ([self inputToolbarConformsToHtmlToolbarViewProtocol])
    {
        MXKRoomInputToolbarView <HtmlRoomInputToolbarViewProtocol> *htmlInputToolBarView = (MXKRoomInputToolbarView <HtmlRoomInputToolbarViewProtocol> *) self.inputToolbarView;
        self.htmlTextBeforeEditing = htmlInputToolBarView.htmlContent;
        htmlInputToolBarView.htmlContent = [self.customizedRoomDataSource editableHtmlTextMessageFor:event];
    }
    else if ([self inputToolbarConformsToToolbarViewProtocol])
    {
        self.textMessageBeforeEditing = self.inputToolbarView.attributedTextMessage;
        self.inputToolbarView.attributedTextMessage = [self.customizedRoomDataSource editableAttributedTextMessageFor:event];
    }
    
    [self selectEventWithId:eventId inputToolBarSendMode:RoomInputToolbarViewSendModeEdit showTimestamp:YES];
}

- (void)restoreTextMessageBeforeEditing
{
    
   
    if (self.htmlTextBeforeEditing && [self inputToolbarConformsToHtmlToolbarViewProtocol])
    {
        MXKRoomInputToolbarView <HtmlRoomInputToolbarViewProtocol> *htmlInputToolBarView = (MXKRoomInputToolbarView <HtmlRoomInputToolbarViewProtocol> *) self.inputToolbarView;
        htmlInputToolBarView.htmlContent = self.htmlTextBeforeEditing;
    }
    else if (self.textMessageBeforeEditing && [self inputToolbarConformsToToolbarViewProtocol])
    {
        self.inputToolbarView.attributedTextMessage = self.textMessageBeforeEditing;
    }
    
    self.textMessageBeforeEditing = nil;
    self.htmlTextBeforeEditing = nil;
}

- (BOOL)inputToolbarConformsToHtmlToolbarViewProtocol
{
    return [self.inputToolbarView conformsToProtocol:@protocol(HtmlRoomInputToolbarViewProtocol)];
}

- (BOOL)inputToolbarConformsToToolbarViewProtocol
{
    return [self.inputToolbarView conformsToProtocol:@protocol(RoomInputToolbarViewProtocol)];
}

- (void)showDifferentURLsAlertFor:(NSURL *)url visibleURLString:(NSString *)visibleURLString
{
    //  urls are different, show confirmation alert
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[VectorL10n externalLinkConfirmationTitle] message:[VectorL10n externalLinkConfirmationMessage:visibleURLString :url.absoluteString] preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *continueAction = [UIAlertAction actionWithTitle:[VectorL10n continue] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        // Try to open the link
        [[UIApplication sharedApplication] vc_open:url completionHandler:^(BOOL success) {
            if (!success)
            {
                [self showUnableToOpenLinkErrorAlert];
            }
        }];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[VectorL10n cancel] style:UIAlertActionStyleCancel handler:nil];

    [alert addAction:continueAction];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - RoomDataSourceDelegate

- (void)roomDataSourceDidUpdateEncryptionTrustLevel:(RoomDataSource *)roomDataSource
{
    [self updateInputToolbarEncryptionDecoration];
    [self updateTitleViewEncryptionDecoration];
}

- (void)roomDataSource:(RoomDataSource *)roomDataSource didTapThread:(id<MXThreadProtocol>)thread
{
    [self openThreadWithId:thread.id];

    [Analytics.shared trackInteraction:AnalyticsUIElementRoomThreadSummaryItem];
}

- (void)roomDataSourceDidUpdateCurrentUserSharingLocationStatus:(RoomDataSource *)roomDataSource
{
    [self updateLiveLocationBannerViewVisibility];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Keep ref on destinationViewController
    [super prepareForSegue:segue sender:sender];
    
    id pushedViewController = [segue destinationViewController];
    
    if ([[segue identifier] isEqualToString:@"showRoomSearch"])
    {
        // Dismiss keyboard
        [self dismissKeyboard];
        
        RoomSearchViewController* roomSearchViewController = (RoomSearchViewController*)pushedViewController;
        // Add the current data source to be able to search messages.
        roomSearchViewController.roomDataSource = self.roomDataSource;
    }
    else if ([[segue identifier] isEqualToString:@"showContactDetails"])
    {
        if (selectedContact)
        {
            ContactDetailsViewController *contactDetailsViewController = segue.destinationViewController;
            contactDetailsViewController.enableVoipCall = NO;
            contactDetailsViewController.contact = selectedContact;
            
            selectedContact = nil;
        }
    }
    else if ([[segue identifier] isEqualToString:@"showUnknownDevices"])
    {
        if (unknownDevices)
        {
            UsersDevicesViewController *usersDevicesViewController = (UsersDevicesViewController *)segue.destinationViewController.childViewControllers.firstObject;
            [usersDevicesViewController displayUsersDevices:unknownDevices andMatrixSession:self.roomDataSource.mxSession onComplete:nil];
            
            unknownDevices = nil;
        }
    }
}

#pragma mark - VoIP

- (void)placeCallWithVideo:(BOOL)video
{
    __weak __typeof(self) weakSelf = self;
    
    // Check app permissions first
    [MXKTools checkAccessForCall:video
     manualChangeMessageForAudio:[VectorL10n microphoneAccessNotGrantedForCall:AppInfo.current.displayName]
     manualChangeMessageForVideo:[VectorL10n cameraAccessNotGrantedForCall:AppInfo.current.displayName]
       showPopUpInViewController:self completionHandler:^(BOOL granted) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            
            if (granted)
            {
                if (video)
                {
                    [self placeCallWithVideo2:video];
                }
                else if (self.mainSession.callManager.supportsPSTN)
                {
                    [self showVoiceCallActionSheet];
                }
                else
                {
                    [self placeCallWithVideo2:NO];
                }
            }
            else
            {
                MXLogDebug(@"RoomViewController: Warning: The application does not have the permission to place the call");
            }
        }
    }];
}

- (void)showVoiceCallActionSheet
{
    // Ask the user the kind of the call: voice or dialpad?
    UIAlertController *callActionSheet = [UIAlertController alertControllerWithTitle:nil
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    
    __weak typeof(self) weakSelf = self;
    [callActionSheet addAction:[UIAlertAction actionWithTitle:[VectorL10n roomPlaceVoiceCall]
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * action) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            self->currentAlert = nil;
            
            [self placeCallWithVideo2:NO];
        }
        
    }]];
    
    [callActionSheet addAction:[UIAlertAction actionWithTitle:[VectorL10n roomOpenDialpad]
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * action) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            self->currentAlert = nil;
            
            [self openDialpad];
        }
        
    }]];
    
    [callActionSheet addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction * action) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            self->currentAlert = nil;
        }
        
    }]];
    
    [callActionSheet popoverPresentationController].barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    [callActionSheet popoverPresentationController].permittedArrowDirections = UIPopoverArrowDirectionUp;
    [self presentViewController:callActionSheet animated:YES completion:nil];
    currentAlert = callActionSheet;
}

- (void)placeCallWithVideo2:(BOOL)video
{
    Widget *jitsiWidget = [self.customizedRoomDataSource jitsiWidget];
    if (jitsiWidget)
    {
        //  If there is already a Jitsi call, join it
        [self showJitsiCallWithWidget:jitsiWidget];
    }
    else
    {
        if (self.roomDataSource.room.summary.membersCount.joined == 2
            && self.roomDataSource.room.isDirect
            && !self.mainSession.vc_homeserverConfiguration.jitsi.useFor1To1Calls)
        {
            //  Matrix call
            [self.roomDataSource.room placeCallWithVideo:video success:nil failure:nil];
        }
        else
        {
            //  Jitsi call
            if (self.canEditJitsiWidget)
            {
                //  User has right to add a Jitsi widget
                //  Create the Jitsi widget and open it directly
                [self startActivityIndicator];
                
                MXWeakify(self);
                
                [[WidgetManager sharedManager] createJitsiWidgetInRoom:self.roomDataSource.room
                                                             withVideo:video
                                                               success:^(Widget *jitsiWidget)
                 {
                    MXStrongifyAndReturnIfNil(self);
                    [self stopActivityIndicator];
                    
                    [self showJitsiCallWithWidget:jitsiWidget];
                }
                                                               failure:^(NSError *error)
                 {
                    MXStrongifyAndReturnIfNil(self);
                    [self stopActivityIndicator];
                    
                    [self showJitsiErrorAsAlert:error];
                }];
            }
            else
            {
                //  Insufficient privileges to add a Jitsi widget
                MXWeakify(self);
                [currentAlert dismissViewControllerAnimated:NO completion:nil];
                
                UIAlertController *unprivilegedAlert = [UIAlertController alertControllerWithTitle:[VectorL10n roomNoPrivilegesToCreateGroupCall]
                                                                                           message:nil
                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                
                [unprivilegedAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n ok]
                                                                      style:UIAlertActionStyleDefault
                                                                    handler:^(UIAlertAction * action)
                                         {
                    MXStrongifyAndReturnIfNil(self);
                    self->currentAlert = nil;
                }]];
                
                [unprivilegedAlert mxk_setAccessibilityIdentifier:@"RoomVCCallAlert"];
                [self presentViewController:unprivilegedAlert animated:YES completion:nil];
                currentAlert = unprivilegedAlert;
            }
        }
    }
}

- (void)hangupCall
{
    MXCall *callInRoom = [self.roomDataSource.mxSession.callManager callInRoom:self.roomDataSource.roomId];
    if (callInRoom)
    {
        [callInRoom hangup];
    }
    else if (self.isRoomHavingAJitsiCall)
    {
        [self endActiveJitsiCall];
        [self reloadBubblesTable:YES];
    }
    
    [self refreshActivitiesViewDisplay];
    [self refreshRoomInputToolbar];
}

#pragma mark - MXKRoomInputToolbarViewDelegate

- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView isTyping:(BOOL)typing
{
    [super roomInputToolbarView:toolbarView isTyping:typing];

    // TODO: Improve so we don't save partial message twice.
    RoomInputToolbarView *inputToolbar = (RoomInputToolbarView *)toolbarView;

    if (self.saveProgressTextInput && self.roomDataSource && inputToolbar)
    {
        // Store the potential message partially typed in text input
        self.roomDataSource.partialAttributedTextMessage = inputToolbar.attributedTextMessage;
    }

    // Cancel potential selected event (to leave edition mode)
    NSString *selectedEventId = self.customizedRoomDataSource.selectedEventId;
    if (typing && selectedEventId && ![self.roomDataSource canReplyToEventWithId:selectedEventId])
    {
        [self cancelEventSelection];
    }
}

- (void)roomInputToolbarView:(MXKRoomInputToolbarView*)toolbarView heightDidChanged:(CGFloat)height completion:(void (^)(BOOL finished))completion
{
    if (self.roomInputToolbarContainerHeightConstraint.constant != height)
    {
        [super roomInputToolbarView:toolbarView heightDidChanged:height completion:^(BOOL finished) {
            
            if (completion)
            {
                completion (finished);
            }
        }];
    }
}

- (void)roomInputToolbarViewDidTapCancel:(MXKRoomInputToolbarView<RoomInputToolbarViewProtocol>*)toolbarView
{
    [self cancelEventSelection];
}
 
- (void)roomInputToolbarViewDidChangeTextMessage:(RoomInputToolbarView *)toolbarView
{
    [self.completionSuggestionCoordinator processTextMessage:toolbarView.textMessage];
}

- (void)didDetectTextPattern:(SuggestionPatternWrapper *)suggestionPattern
{
    [self.completionSuggestionCoordinator processSuggestionPattern:suggestionPattern];
}

- (CompletionSuggestionViewModelContextWrapper *)completionSuggestionContext
{
    return [self.completionSuggestionCoordinator sharedContext];
}

- (MXMediaManager *)mediaManager
{
    return self.mainSession.mediaManager;
}

- (void)roomInputToolbarViewDidOpenActionMenu:(RoomInputToolbarView*)toolbarView
{
    // Consider opening the action menu as beginning to type and share encryption keys if requested.
    if ([MXKAppSettings standardAppSettings].outboundGroupSessionKeyPreSharingStrategy == MXKKeyPreSharingWhenTyping)
    {
        [self shareEncryptionKeys];
    }
}

- (void)roomInputToolbarView:(RoomInputToolbarView *)toolbarView sendFormattedTextMessage:(NSString *)formattedTextMessage withRawText:(NSString *)rawText
{
    // Create before sending the message in case of a discussion (direct chat)
    MXWeakify(self);
    [self createDiscussionIfNeeded:^(BOOL readyToSend) {
        MXStrongifyAndReturnIfNil(self);
        
        if (readyToSend) {
            [self sendFormattedTextMessage:rawText htmlMsg:formattedTextMessage];
        }
        // Errors are handled at the request level. This should be improved in case of code rewriting.
    }];
}

- (void)roomInputToolbarView:(MXKRoomInputToolbarView *)toolbarView sendCommand:(NSString *)commandText
{
    // Create before sending the message in case of a discussion (direct chat)
    MXWeakify(self);
    [self createDiscussionIfNeeded:^(BOOL readyToSend) {
        MXStrongifyAndReturnIfNil(self);

        if (readyToSend) {
            if (![self sendAsIRCStyleCommandIfPossible:commandText])
            {
                // Display an error for unknown command
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                               message:[VectorL10n roomCommandErrorUnknownCommand]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:[VectorL10n ok] style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        }
    }];
}

- (void)roomInputToolbarViewShowSendMediaActions:(MXKRoomInputToolbarView *)toolbarView
{
    NSMutableArray *actionItems = [NSMutableArray new];
    if (RiotSettings.shared.roomScreenAllowMediaLibraryAction)
    {
        [actionItems addObject:@(ComposerCreateActionPhotoLibrary)];
    }
    if (RiotSettings.shared.roomScreenAllowStickerAction && !self.isNewDirectChat)
    {
        [actionItems addObject:@(ComposerCreateActionStickers)];
    }
    if (RiotSettings.shared.roomScreenAllowFilesAction)
    {
        [actionItems addObject:@(ComposerCreateActionAttachments)];
    }
    if (RiotSettings.shared.enableVoiceBroadcast && !self.isNewDirectChat)
    {
        [actionItems addObject:@(ComposerCreateActionVoiceBroadcast)];
    }
    if (BuildSettings.pollsEnabled && self.displayConfiguration.sendingPollsEnabled && !self.isNewDirectChat)
    {
        [actionItems addObject:@(ComposerCreateActionPolls)];
    }
    if (BuildSettings.locationSharingEnabled && !self.isNewDirectChat)
    {
        [actionItems addObject:@(ComposerCreateActionLocation)];
    }
    if (RiotSettings.shared.roomScreenAllowCameraAction)
    {
        [actionItems addObject:@(ComposerCreateActionCamera)];
    }
    
    self.composerCreateActionListBridgePresenter = [[ComposerCreateActionListBridgePresenter alloc] initWithActions:actionItems
                                                                                                     wysiwygEnabled:RiotSettings.shared.enableWysiwygComposer
                                                                                              textFormattingEnabled:RiotSettings.shared.enableWysiwygTextFormatting];
    self.composerCreateActionListBridgePresenter.delegate = self;
    [self.composerCreateActionListBridgePresenter presentFrom:self animated:YES];
}

- (void)roomInputToolbarView:(RoomInputToolbarView *)toolbarView sendAttributedTextMessage:(NSAttributedString *)attributedTextMessage
{
    // Create before sending the message in case of a discussion (direct chat)
    MXWeakify(self);
    [self createDiscussionIfNeeded:^(BOOL readyToSend) {
        MXStrongifyAndReturnIfNil(self);
        
        if (readyToSend) {
            BOOL isMessageAHandledCommand = NO;
            // "/me" command is supported with Pills in RoomDataSource.
            if (![attributedTextMessage.string hasPrefix:[MXKSlashCommandsHelper commandNameFor:MXKSlashCommandEmote]])
            {
                // Other commands currently work with identifiers (e.g. ban, invite, op, etc).
                NSString *message;
                if (@available(iOS 15.0, *))
                {
                    message = [PillsFormatter stringByReplacingPillsIn:attributedTextMessage mode:PillsReplacementTextModeIdentifier];
                }
                else
                {
                    message = attributedTextMessage.string;
                }
                // Try to send the slash command
                isMessageAHandledCommand = [self sendAsIRCStyleCommandIfPossible:message];
            }
            
            if (!isMessageAHandledCommand)
            {
                [self sendAttributedTextMessage:attributedTextMessage];
            }
        }
        // Errors are handled at the request level. This should be improved in case of code rewriting.
    }];
}

- (void)roomInputToolbarView:(MXKRoomInputToolbarView *)toolbarView shouldStorePartialContent:(NSAttributedString *)partialAttributedTextMessage
{
    self.roomDataSource.partialAttributedTextMessage = partialAttributedTextMessage;
}

#pragma mark - MXKRoomMemberDetailsViewControllerDelegate

- (void)roomMemberDetailsViewController:(MXKRoomMemberDetailsViewController *)roomMemberDetailsViewController startChatWithMemberId:(NSString *)matrixId completion:(void (^)(void))completion
{
    [self startChatWithUserId:matrixId completion:completion];
}

- (void)roomMemberDetailsViewController:(MXKRoomMemberDetailsViewController *)roomMemberDetailsViewController mention:(MXRoomMember*)member
{
    [self mention:member];
}

#pragma mark - Action

- (IBAction)onVoiceCallPressed:(id)sender
{
    // Manage case of a Voice broadcast listening -> Pause Voice broadcast playback
    [VoiceBroadcastPlaybackProvider.shared pausePlaying];
    
    if (VoiceBroadcastRecorderProvider.shared.isVoiceBroadcastRecording) {
        [[AppDelegate theDelegate] showAlertWithTitle:VectorL10n.voiceBroadcastVoipCannotStartTitle
                                              message:VectorL10n.voiceBroadcastVoipCannotStartDescription];
    }
    else if (self.isCallActive)
    {
        [self hangupCall];
    }
    else
    {
        [self placeCallWithVideo:NO];
    }
}

- (IBAction)onVideoCallPressed:(id)sender
{
    // Manage case of a Voice broadcast listening -> Pause Voice broadcast playback
    [VoiceBroadcastPlaybackProvider.shared pausePlaying];

    if (VoiceBroadcastRecorderProvider.shared.isVoiceBroadcastRecording) {
        [[AppDelegate theDelegate] showAlertWithTitle:VectorL10n.voiceBroadcastVoipCannotStartTitle
                                              message:VectorL10n.voiceBroadcastVoipCannotStartDescription];
    } else {
        [self placeCallWithVideo:YES];
    }
}

- (IBAction)onThreadListTapped:(id)sender
{
    self.threadsBridgePresenter = [self.delegate threadsCoordinatorForRoomViewController:self threadId:nil];
    self.threadsBridgePresenter.delegate = self;
    [self.threadsBridgePresenter pushFrom:self.navigationController animated:YES];

    [Analytics.shared trackInteraction:AnalyticsUIElementRoomThreadListButton];
}

- (IBAction)onIntegrationsPressed:(id)sender
{
    WidgetPickerViewController *widgetPicker = [[WidgetPickerViewController alloc] initForMXSession:self.roomDataSource.mxSession
                                                                                             inRoom:self.roomDataSource.roomId];
    
    [widgetPicker showInViewController:self];
}

- (void)scrollToBottomAction:(id)sender
{
    [self goBackToLive];
}

- (IBAction)onButtonPressed:(id)sender
{
    if (sender == self.jumpToLastUnreadButton)
    {
        // Dismiss potential keyboard.
        [self dismissKeyboard];
        NSString *eventId = self.roomDataSource.room.accountData.readMarkerEventId;
        NSString *threadId = self.roomDataSource.threadId;
        [self reloadRoomWihtEventId:eventId threadId:threadId forceUpdateRoomMarker:YES];
    }
    else if (sender == self.resetReadMarkerButton)
    {
        // Move the read marker to the current read receipt position.
        [self.roomDataSource.room forgetReadMarker];
        
        // Hide the banner
        self.jumpToLastUnreadBannerContainer.hidden = YES;
    }
}

- (void)handleReportRoom 
{
    // Prompt user to enter a description of the problem content.
    UIAlertController *reportReasonAlert = [UIAlertController alertControllerWithTitle:[VectorL10n roomActionReportPromptReason]
                                                                               message:nil
                                                                        preferredStyle:UIAlertControllerStyleAlert];
    
    [reportReasonAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.secureTextEntry = NO;
        textField.placeholder = nil;
        textField.keyboardType = UIKeyboardTypeDefault;
    }];
    
    MXWeakify(self);
    [reportReasonAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n ok] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        MXStrongifyAndReturnIfNil(self);
        
        NSString *text = [self->currentAlert textFields].firstObject.text;
        self->currentAlert = nil;
        
        [self startActivityIndicator];
        
        [self.roomDataSource.mxSession.matrixRestClient reportRoom:self.roomDataSource.roomId reason:text success:^{
            MXStrongifyAndReturnIfNil(self);
            [self stopActivityIndicator];
        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);
            [self stopActivityIndicator];
            
            MXLogDebug(@"[RoomVC] Report room (%@) failed", self.roomDataSource.roomId);
            //Alert user
            [self showError:error];
        }];
    }]];
    
    [reportReasonAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel] style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        MXStrongifyAndReturnIfNil(self);
        self->currentAlert = nil;
    }]];
    
    [self presentViewController:reportReasonAlert animated:YES completion:nil];
    self->currentAlert = reportReasonAlert;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = ThemeService.shared.theme.backgroundColor;
    
    // Update the selected background view
    if (ThemeService.shared.theme.selectedBackgroundColor)
    {
        cell.selectedBackgroundView = [[UIView alloc] init];
        cell.selectedBackgroundView.backgroundColor = ThemeService.shared.theme.selectedBackgroundColor;
    }
    else
    {
        if (tableView.style == UITableViewStylePlain)
        {
            cell.selectedBackgroundView = nil;
        }
        else
        {
            cell.selectedBackgroundView.backgroundColor = nil;
        }
    }
    
    if ([cell isKindOfClass:MXKRoomBubbleTableViewCell.class] && ![cell isKindOfClass:MXKRoomEmptyBubbleTableViewCell.class])
    {
        MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell*)cell;
        if (roomBubbleTableViewCell.readMarkerView)
        {
            readMarkerTableViewCell = roomBubbleTableViewCell;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self checkReadMarkerVisibility];
            });
        }
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
    if (cell == readMarkerTableViewCell)
    {
        readMarkerTableViewCell = nil;
    }
    
    [super tableView:tableView didEndDisplayingCell:cell forRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

#pragma mark -

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [super scrollViewDidScroll:scrollView];
    
    [self checkReadMarkerVisibility];
    
    // Switch back to the live mode when the user scrolls to the bottom of the non live timeline.
    if (!self.roomDataSource.isLive && ![self isRoomPreview] && !self.isNewDirectChat)
    {
        CGFloat contentBottomPosY = self.bubblesTableView.contentOffset.y + self.bubblesTableView.frame.size.height - self.bubblesTableView.adjustedContentInset.bottom;
        if (contentBottomPosY >= self.bubblesTableView.contentSize.height && ![self.roomDataSource.timeline canPaginate:MXTimelineDirectionForwards])
        {
            [self goBackToLive];
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if ([MXKRoomViewController instancesRespondToSelector:@selector(scrollViewWillBeginDragging:)])
    {
        [super scrollViewWillBeginDragging:scrollView];
    }
    
    [self cancelEventHighlight];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if ([MXKRoomViewController instancesRespondToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)])
    {
        [super scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
    }
    
    if (decelerate == NO)
    {
        // Handle swipe on expanded header
        [self onScrollViewDidEndScrolling:scrollView];
        
        [self refreshActivitiesViewDisplay];
        [self refreshJumpToLastUnreadBannerDisplay];
    }
    else
    {
        // Dispatch async the expanded header handling in order to let the deceleration go first.
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Handle swipe on expanded header
            [self onScrollViewDidEndScrolling:scrollView];
            
        });
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if ([MXKRoomViewController instancesRespondToSelector:@selector(scrollViewDidEndDecelerating:)])
    {
        [super scrollViewDidEndDecelerating:scrollView];
    }
    
    [self refreshActivitiesViewDisplay];
    [self refreshJumpToLastUnreadBannerDisplay];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if ([MXKRoomViewController instancesRespondToSelector:@selector(scrollViewDidEndScrollingAnimation:)])
    {
        [super scrollViewDidEndScrollingAnimation:scrollView];
    }
    
    [self refreshActivitiesViewDisplay];
    [self refreshJumpToLastUnreadBannerDisplay];
}

- (void)onScrollViewDidEndScrolling:(UIScrollView *)scrollView
{
    
}

#pragma mark - MXKRoomTitleViewDelegate

- (BOOL)roomTitleViewShouldBeginEditing:(MXKRoomTitleView*)titleView
{
    // Disable room name edition
    return NO;
}

#pragma mark - RoomTitleViewTapGestureDelegate

- (void)roomTitleView:(RoomTitleView*)titleView recognizeTapGesture:(UITapGestureRecognizer*)tapGestureRecognizer
{
    UIView *tappedView = tapGestureRecognizer.view;
    
    if (tappedView == titleView.titleMask)
    {
        [self showRoomInfo];
    }
    else if (tappedView == previewHeader.rightButton)
    {
        // 'Join' button has been pressed
        if (!roomPreviewData)
        {
            [self joinRoom:^(MXKRoomViewControllerJoinRoomResult result) {
                switch (result)
                {
                    case MXKRoomViewControllerJoinRoomResultSuccess:
                        [self refreshRoomTitle];
                        break;
                    case MXKRoomViewControllerJoinRoomResultFailureRoomEmpty:
                        [self declineRoomInvitation];
                        break;
                    default:
                        break;
                }
            }];
            
            return;
        }
        
        // Attempt to join the room (keep reference on the potential eventId, the preview data will be removed automatically in case of success).
        NSString *eventId = roomPreviewData.eventId;
        
        // We promote here join by room alias instead of room id when an alias is available.
        NSString *roomIdOrAlias = roomPreviewData.roomId;
        
        if (roomPreviewData.roomCanonicalAlias.length)
        {
            roomIdOrAlias = roomPreviewData.roomCanonicalAlias;
        }
        else if (roomPreviewData.roomAliases.count)
        {
            roomIdOrAlias = roomPreviewData.roomAliases.firstObject;
        }
        
        // Note in case of simple link to a room the signUrl param is nil
        [self joinRoomWithRoomIdOrAlias:roomIdOrAlias viaServers:roomPreviewData.viaServers
                             andSignUrl:roomPreviewData.emailInvitation.signUrl
                             completion:^(MXKRoomViewControllerJoinRoomResult result) {
            
            switch (result)
            {
                case MXKRoomViewControllerJoinRoomResultSuccess:
                {
                    // If an event was specified, replace the datasource by a non live datasource showing the event
                    if (eventId)
                    {
                        MXWeakify(self);
                        [RoomDataSource loadRoomDataSourceWithRoomId:self.roomDataSource.roomId
                                                      initialEventId:eventId
                                                            threadId:self.roomDataSource.threadId
                                                    andMatrixSession:self.mainSession
                                                          onComplete:^(id roomDataSource) {
                            MXStrongifyAndReturnIfNil(self);
                            
                            [roomDataSource finalizeInitialization];
                            ((RoomDataSource*)roomDataSource).markTimelineInitialEvent = YES;
                            
                            [self displayRoom:roomDataSource];
                            
                            self.hasRoomDataSourceOwnership = YES;
                        }];
                    }
                    else
                    {
                        // Enable back the text input
                        [self setRoomInputToolbarViewClass:[RoomViewController mainToolbarClass]];
                        [self updateInputToolBarViewHeight];
                        
                        // And the extra area
                        [self setRoomActivitiesViewClass:RoomActivitiesView.class];
                        
                        [self refreshRoomTitle];
                        [self refreshRoomInputToolbar];
                    }
                    break;
                }
                case MXKRoomViewControllerJoinRoomResultFailureRoomEmpty:
                    [self declineRoomInvitation];
                    break;
                default:
                    break;
            }
        }];
    }
    else if (tappedView == previewHeader.leftButton)
    {
        [self presentDeclineOptionsFromView:tappedView];
    }
    else if (tappedView == previewHeader.reportButton)
    {
        [self handleReportRoom];
    }
}

- (void)presentDeclineOptionsFromView:(UIView *)view
{
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:[VectorL10n roomPreviewDeclineInvitationOptions]
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    [actionSheet addAction:[UIAlertAction actionWithTitle:[VectorL10n decline]
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * _Nonnull action) {
        [self declineRoomInvitation];
    }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:[VectorL10n ignoreUser]
                                                    style:UIAlertActionStyleDestructive
                                                  handler:^(UIAlertAction * _Nonnull action) {
        [self ignoreInviteSender];
    }]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                    style:UIAlertActionStyleCancel
                                                  handler:nil]];
    actionSheet.popoverPresentationController.sourceView = view;
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)declineRoomInvitation
{
    // 'Decline' button has been pressed
    if (roomPreviewData)
    {
        [self roomPreviewDidTapCancelAction];
    }
    else
    {
        [self startActivityIndicator];
        MXWeakify(self);
        [self.roomDataSource.room leave:^{
            MXStrongifyAndReturnIfNil(self);
            
            [self stopActivityIndicator];
            [self popToHomeViewController];
            
        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);
            
            [self stopActivityIndicator];
            MXLogDebug(@"[RoomVC] Failed to reject an invited room (%@) failed", self.roomDataSource.room.roomId);
            
        }];
    }
}

- (void)ignoreInviteSender
{
    [self startActivityIndicator];
    MXWeakify(self);
    [self.roomDataSource.room ignoreInviteSender:^{
        MXStrongifyAndReturnIfNil(self);
        
        [self stopActivityIndicator];
        [self popToHomeViewController];

    } failure:^(NSError *error) {
        MXStrongifyAndReturnIfNil(self);
        
        [self stopActivityIndicator];
        MXLogDebug(@"[RoomVC] Failed to ignore inviter in room (%@)", self.roomDataSource.room.roomId);
    }];
}

- (void)popToHomeViewController
{
    // We remove the current view controller.
    // Pop to homes view controller
    [[AppDelegate theDelegate] restoreInitialDisplay:^{}];
}

#pragma mark - Typing management

- (void)removeTypingNotificationsListener
{
    if (self.roomDataSource)
    {
        // Remove the previous live listener
        if (typingNotifListener)
        {
            MXWeakify(self);
            [self.roomDataSource.room liveTimeline:^(id<MXEventTimeline> liveTimeline) {
                MXStrongifyAndReturnIfNil(self);
                
                [liveTimeline removeListener:self->typingNotifListener];
                self->typingNotifListener = nil;
            }];
        }
    }
    
    currentTypingUsers = nil;
}

- (void)listenTypingNotifications
{
    if (self.roomDataSource)
    {
        // Add typing notification listener
        MXWeakify(self);
        self->typingNotifListener = [self.roomDataSource.room listenToEventsOfTypes:@[kMXEventTypeStringTypingNotification] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {
            MXStrongifyAndReturnIfNil(self);
            
            // Handle only live events
            if (direction == MXTimelineDirectionForwards)
            {
                // Retrieve typing users list
                NSMutableArray *typingUsers = [NSMutableArray arrayWithArray:self.roomDataSource.room.typingUsers];
                // Remove typing info for the current user
                NSUInteger index = [typingUsers indexOfObject:self.mainSession.myUser.userId];
                if (index != NSNotFound)
                {
                    [typingUsers removeObjectAtIndex:index];
                }
                
                // Ignore this notification if both arrays are empty
                if (self->currentTypingUsers.count || typingUsers.count)
                {
                    self->currentTypingUsers = typingUsers;
                    [self refreshActivitiesViewDisplay];
                }
            }
        }];
        
        // Retrieve the current typing users list
        NSMutableArray *typingUsers = [NSMutableArray arrayWithArray:self.roomDataSource.room.typingUsers];
        // Remove typing info for the current user
        NSUInteger index = [typingUsers indexOfObject:self.mainSession.myUser.userId];
        if (index != NSNotFound)
        {
            [typingUsers removeObjectAtIndex:index];
        }
        currentTypingUsers = typingUsers;
        [self refreshActivitiesViewDisplay];
    }
}

- (void)refreshTypingNotification
{
    RoomDataSource *roomDataSource = (RoomDataSource *) self.roomDataSource;
    BOOL needsUpdate = currentTypingUsers.count != roomDataSource.currentTypingUsers.count;

    NSMutableArray *typingUsers = [NSMutableArray new];
    for (NSUInteger i = 0 ; i < currentTypingUsers.count ; i++) {
        NSString *userId = currentTypingUsers[i];
        MXRoomMember* member = [self.roomDataSource.roomState.members memberWithUserId:userId];
        TypingUserInfo *userInfo;
        if (member)
        {
            userInfo = [[TypingUserInfo alloc] initWithMember: member];
        }
        else
        {
            userInfo = [[TypingUserInfo alloc] initWithUserId: userId];
        }
        [typingUsers addObject:userInfo];
        needsUpdate = needsUpdate || userInfo.userId != ((MXRoomMember *) roomDataSource.currentTypingUsers[i]).userId;
    }

    if (needsUpdate)
    {
//        BOOL needsReload = roomDataSource.currentTypingUsers == nil;
        // Quick fix for https://github.com/vector-im/element-ios/issues/4230
        BOOL needsReload = YES;
        roomDataSource.currentTypingUsers = typingUsers;
        if (needsReload)
        {
            [self.bubblesTableView reloadData];
        }
        else
        {
            NSInteger count = [self.bubblesTableView numberOfRowsInSection:0];
            NSIndexPath *lastIndexPath = [NSIndexPath indexPathForRow:count - 1 inSection:0];
            [self.bubblesTableView reloadRowsAtIndexPaths:@[lastIndexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
        
        if (self.isScrollToBottomHidden
            && !self.bubblesTableView.isDragging
            && !self.bubblesTableView.isDecelerating)
        {
            NSInteger count = [self.bubblesTableView numberOfRowsInSection:0];
            if (count)
            {
                [self scrollBubblesTableViewToBottomAnimated:YES];
            }
        }
    }
}

#pragma mark - Call notifications management

- (void)removeCallNotificationsListeners
{
    if (kMXCallStateDidChangeObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kMXCallStateDidChangeObserver];
        kMXCallStateDidChangeObserver = nil;
    }
    if (kMXCallManagerConferenceStartedObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kMXCallManagerConferenceStartedObserver];
        kMXCallManagerConferenceStartedObserver = nil;
    }
    if (kMXCallManagerConferenceFinishedObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kMXCallManagerConferenceFinishedObserver];
        kMXCallManagerConferenceFinishedObserver = nil;
    }
}

- (void)listenCallNotifications
{
    MXWeakify(self);
    
    kMXCallStateDidChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXCallStateDidChange object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        MXCall *call = notif.object;
        if ([call.room.roomId isEqualToString:self.customizedRoomDataSource.roomId])
        {
            [self refreshActivitiesViewDisplay];
            [self refreshRoomInputToolbar];
        }
    }];
    kMXCallManagerConferenceStartedObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXCallManagerConferenceStarted object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        NSString *roomId = notif.object;
        if ([roomId isEqualToString:self.customizedRoomDataSource.roomId])
        {
            [self refreshActivitiesViewDisplay];
        }
    }];
    kMXCallManagerConferenceFinishedObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXCallManagerConferenceFinished object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        NSString *roomId = notif.object;
        if ([roomId isEqualToString:self.customizedRoomDataSource.roomId])
        {
            [self refreshActivitiesViewDisplay];
            [self refreshRoomInputToolbar];
        }
    }];
}


#pragma mark - Server notices management

- (void)removeServerNoticesListener
{
    if (serverNotices)
    {
        [serverNotices close];
        serverNotices = nil;
    }
}

- (void)listenToServerNotices
{
    if (!serverNotices)
    {
        serverNotices = [[MXServerNotices alloc] initWithMatrixSession:self.roomDataSource.mxSession];
        serverNotices.delegate = self;
    }
}

- (void)serverNoticesDidChangeState:(MXServerNotices *)serverNotices
{
    [self refreshActivitiesViewDisplay];
}

#pragma mark - Widget notifications management

- (void)removeWidgetNotificationsListeners
{
    if (kMXKWidgetManagerDidUpdateWidgetObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kMXKWidgetManagerDidUpdateWidgetObserver];
        kMXKWidgetManagerDidUpdateWidgetObserver = nil;
    }
}

- (void)listenWidgetNotifications
{
    if (!self.displayConfiguration.jitsiWidgetRemoverEnabled)
    {
        return;
    }
    
    MXWeakify(self);
    
    kMXKWidgetManagerDidUpdateWidgetObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kWidgetManagerDidUpdateWidgetNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        Widget *widget = notif.object;
        if (widget.mxSession == self.roomDataSource.mxSession
            && [widget.roomId isEqualToString:self.customizedRoomDataSource.roomId])
        {
            //  Call button update
            [self refreshRoomTitle];
            //  Remove Jitsi widget view update
            [self refreshRemoveJitsiWidgetView];
        }
    }];
}

- (void)showJitsiErrorAsAlert:(NSError*)error
{
    // Customise the error for permission issues
    if ([error.domain isEqualToString:WidgetManagerErrorDomain] && error.code == WidgetManagerErrorCodeNotEnoughPower)
    {
        error = [NSError errorWithDomain:error.domain
                                    code:error.code
                                userInfo:@{
                                    NSLocalizedDescriptionKey: [VectorL10n roomConferenceCallNoPower]
                                }];
    }
    
    // Alert user
    [self showError:error];
}

- (NSUInteger)widgetsCount:(BOOL)includeUserWidgets
{
    if (!self.displayConfiguration.integrationsEnabled)
    {
        return 0;
    }
    
    NSUInteger widgetsCount = [[WidgetManager sharedManager] widgetsNotOfTypes:@[kWidgetTypeJitsiV1, kWidgetTypeJitsiV2]
                                                                        inRoom:self.roomDataSource.room
                                                                 withRoomState:self.roomDataSource.roomState].count;
    if (includeUserWidgets)
    {
        widgetsCount += [[WidgetManager sharedManager] userWidgets:self.roomDataSource.room.mxSession].count;
    }
    
    return widgetsCount;
}

#pragma mark - Unreachable Network Handling

- (void)refreshActivitiesViewDisplay
{
    if ([self.activitiesView isKindOfClass:RoomActivitiesView.class])
    {
        RoomActivitiesView *roomActivitiesView = (RoomActivitiesView*)self.activitiesView;
        
        // Reset gesture recognizers
        while (roomActivitiesView.gestureRecognizers.count)
        {
            [roomActivitiesView removeGestureRecognizer:roomActivitiesView.gestureRecognizers[0]];
        }
        
        if ([self.roomDataSource.mxSession.syncError.errcode isEqualToString:kMXErrCodeStringResourceLimitExceeded])
        {
            self.activitiesViewExpanded = YES;
            [roomActivitiesView showResourceLimitExceededError:self.roomDataSource.mxSession.syncError.userInfo onAdminContactTapped:^(NSURL *adminContactURL) {
                [[UIApplication sharedApplication] vc_open:adminContactURL completionHandler:^(BOOL success) {
                    if (!success)
                    {
                        MXLogDebug(@"[RoomVC] refreshActivitiesViewDisplay: adminContact(%@) cannot be opened", adminContactURL);
                    }
                }];
            }];
        }
        else if ([AppDelegate theDelegate].isOffline)
        {
            // Doing nothing here as the offline notification is now handled by the AppCoordinator
        }
        else if (self.customizedRoomDataSource.roomState.isObsolete)
        {
            self.activitiesViewExpanded = YES;
            MXWeakify(self);
            [roomActivitiesView displayRoomReplacementWithRoomLinkTappedHandler:^{
                MXStrongifyAndReturnIfNil(self);
                
                MXEvent *stoneTombEvent = [self.customizedRoomDataSource.roomState stateEventsWithType:kMXEventTypeStringRoomTombStone].lastObject;
                
                NSString *replacementRoomId = self.customizedRoomDataSource.roomState.tombStoneContent.replacementRoomId;
                if ([self.roomDataSource.mxSession roomWithRoomId:replacementRoomId])
                {
                    // Open the room if it is already joined
                    [self showRoomWithId:replacementRoomId];
                }
                else
                {
                    // Else auto join it via the server that sent the event
                    MXLogDebug(@"[RoomVC] Auto join an upgraded room: %@ -> %@. Sender: %@",                              self.customizedRoomDataSource.roomState.roomId,
                          replacementRoomId, stoneTombEvent.sender);
                    
                    NSString *viaSenderServer = [MXTools serverNameInMatrixIdentifier:stoneTombEvent.sender];
                    
                    if (viaSenderServer)
                    {
                        [self startActivityIndicator];
                        [self.roomDataSource.mxSession joinRoom:replacementRoomId viaServers:@[viaSenderServer] success:^(MXRoom *room) {
                            [self stopActivityIndicator];

                            [self showRoomWithId:replacementRoomId];
                            
                        } failure:^(NSError *error) {
                            [self stopActivityIndicator];
                            
                            MXLogDebug(@"[RoomVC] Failed to join an upgraded room. Error: %@",
                                  error);
                            [self showError:error];
                        }];
                    }
                }
            }];
        }
        else if ([self checkUnsentMessages] == NO)
        {
            // Show "scroll to bottom" icon when the most recent message is not visible,
            // or when the timelime is not live (this icon is used to go back to live).
            // Note: we check if `currentEventIdAtTableBottom` is set to know whether the table has been rendered at least once.
            if (!self.roomDataSource.isLive || (currentEventIdAtTableBottom && [self isBubblesTableScrollViewAtTheBottom] == NO))
            {
                if (self.roomDataSource.room)
                {
                    // Retrieve the unread messages count on the current thread
                    NSUInteger unreadCount = [self.mainSession.store
                                              localUnreadEventCount:self.roomDataSource.room.roomId
                                              threadId:self.roomDataSource.threadId ?: kMXEventTimelineMain
                                              withTypeIn:self.mainSession.unreadEventTypes];
                    
                    self.scrollToBottomBadgeLabel.text = unreadCount ? [NSString stringWithFormat:@"%lu", unreadCount] : nil;
                    self.scrollToBottomHidden = NO;
                }
                else
                {
                    //  will be here for left rooms
                    self.scrollToBottomBadgeLabel.text = nil;
                    self.scrollToBottomHidden = YES;
                }
            }
            else if (serverNotices.usageLimit && serverNotices.usageLimit.isServerNoticeUsageLimit)
            {
                self.scrollToBottomHidden = YES;
                self.activitiesViewExpanded = YES;
                [roomActivitiesView showResourceUsageLimitNotice:serverNotices.usageLimit onAdminContactTapped:^(NSURL *adminContactURL) {
                    [[UIApplication sharedApplication] vc_open:adminContactURL completionHandler:^(BOOL success) {
                        if (!success)
                        {
                            MXLogDebug(@"[RoomVC] refreshActivitiesViewDisplay: adminContact(%@) cannot be opened", adminContactURL);
                        }
                    }];
                }];
            }
            else
            {
                self.scrollToBottomHidden = YES;
                self.activitiesViewExpanded = NO;
                [self refreshTypingNotification];
            }
        }
        
        // Recognize swipe downward to dismiss keyboard if any
        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onSwipeGesture:)];
        [swipe setNumberOfTouchesRequired:1];
        [swipe setDirection:UISwipeGestureRecognizerDirectionDown];
        [roomActivitiesView addGestureRecognizer:swipe];
    }
}

- (void)goBackToLive
{
    if (self.roomDataSource.isLive)
    {
        // Enable the read marker display, and disable its update (in order to not mark as read all the new messages by default).
        self.roomDataSource.showReadMarker = YES;
        self.updateRoomReadMarker = NO;
        
        [self scrollBubblesTableViewToBottomAnimated:YES];

        [self cancelEventHighlight];
    }
    else
    {
        MXWeakify(self);

        void(^continueBlock)(MXKRoomDataSource *, BOOL) = ^(MXKRoomDataSource *roomDataSource, BOOL hasRoomDataSourceOwnership){
            MXStrongifyAndReturnIfNil(self);

            [roomDataSource finalizeInitialization];

            // Scroll to bottom the bubble history on the display refresh.
            self->shouldScrollToBottomOnTableRefresh = YES;

            [self displayRoom:roomDataSource];

            // Set the room view controller has the data source ownership here.
            self.hasRoomDataSourceOwnership = hasRoomDataSourceOwnership;

            [self refreshActivitiesViewDisplay];
            [self refreshJumpToLastUnreadBannerDisplay];

            if (self.saveProgressTextInput)
            {
                // Restore the potential message partially typed before jump to last unread messages.
                [self.inputToolbarView setPartialContent:roomDataSource.partialAttributedTextMessage];
            }
        };

        if (self.roomDataSource.threadId)
        {
            [ThreadDataSource loadRoomDataSourceWithRoomId:self.roomDataSource.roomId
                                            initialEventId:nil
                                                  threadId:self.roomDataSource.threadId
                                          andMatrixSession:self.mainSession
                                                onComplete:^(ThreadDataSource *threadDataSource)
             {
                continueBlock(threadDataSource, YES);
            }];
        }
        else if (self.roomDataSource.roomId)
        {
            if (self.isContextPreview)
            {
                [RoomPreviewDataSource loadRoomDataSourceWithRoomId:self.roomDataSource.roomId
                                                           threadId:nil
                                                   andMatrixSession:self.mainSession
                                                         onComplete:^(RoomPreviewDataSource *roomDataSource)
                 {
                    continueBlock(roomDataSource, YES);
                }];
            }
            else
            {
                // Switch back to the room live timeline managed by MXKRoomDataSourceManager
                MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:self.mainSession];

                [roomDataSourceManager roomDataSourceForRoom:self.roomDataSource.roomId
                                                      create:YES
                                                  onComplete:^(MXKRoomDataSource *roomDataSource) {
                    continueBlock(roomDataSource, NO);
                }];
            }
        }
    }
}

#pragma mark - Missed discussions handling

- (void)refreshMissedDiscussionsCount:(BOOL)force
{
    // Ignore this action when no room is displayed
    if (!self.showMissedDiscussionsBadge || !self.roomDataSource || !missedDiscussionsBadgeLabel
        || [UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPhone
        || ([[UIScreen mainScreen] nativeBounds].size.height > 2532 && UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)))
    {
        self.missedDiscussionsBadgeHidden = YES;
        return;
    }
    
    self.missedDiscussionsBadgeHidden = NO;

    NSUInteger highlightCount = 0;
    NSUInteger missedCount = [[AppDelegate theDelegate].masterTabBarController missedDiscussionsCount];
    
    // Compute the missed notifications count of the current room by considering its notification mode in Riot.
    NSUInteger roomNotificationCount = self.roomDataSource.room.summary.notificationCount;
    if (self.roomDataSource.room.isMentionsOnly)
    {
        // Only the highlighted missed messages must be considered here.
        roomNotificationCount = self.roomDataSource.room.summary.highlightCount;
    }
    
    // Remove the current room from the missed discussion counter.
    if (missedCount && roomNotificationCount)
    {
        missedCount--;
    }
    
    if (missedCount)
    {
        // Compute the missed highlight count
        highlightCount = [[AppDelegate theDelegate].masterTabBarController missedHighlightDiscussionsCount];
        if (highlightCount && self.roomDataSource.room.summary.highlightCount)
        {
            // Remove the current room from the missed highlight counter
            highlightCount--;
        }
    }
    
    if (force || missedDiscussionsCount != missedCount || missedHighlightCount != highlightCount)
    {
        missedDiscussionsCount = missedCount;
        missedHighlightCount = highlightCount;
        
        if (missedCount)
        {
            // Refresh missed discussions count label
            if (missedCount > 99)
            {
                missedDiscussionsBadgeLabel.text = @"99+";
            }
            else
            {
                missedDiscussionsBadgeLabel.text = [NSString stringWithFormat:@"%tu", missedCount];
            }
            
            missedDiscussionsDotView.alpha = highlightCount == 0 ? 0 : 1;
        }
        else
        {
            missedDiscussionsBadgeLabel.text = nil;
        }
    }
}

#pragma mark - Unsent Messages Handling

-(BOOL)checkUnsentMessages
{
    MXRoomSummarySentStatus sentStatus = MXRoomSummarySentStatusOk;
    if ([self.activitiesView isKindOfClass:RoomActivitiesView.class])
    {
        sentStatus = self.roomDataSource.room.summary.sentStatus;
        
        if (sentStatus != MXRoomSummarySentStatusOk)
        {
            NSString *notification = sentStatus == MXRoomSummarySentStatusSentFailedDueToUnknownDevices ?
            [VectorL10n roomUnsentMessagesUnknownDevicesNotification] :
            [VectorL10n roomUnsentMessagesNotification];
            
            MXWeakify(self);
            RoomActivitiesView *roomActivitiesView = (RoomActivitiesView*) self.activitiesView;
            self.activitiesViewExpanded = YES;
            [roomActivitiesView displayUnsentMessagesNotification:notification withResendLink:^{
                
                [self resendAllUnsentMessages];
                
            } andCancelLink:^{
                
                [self cancelAllUnsentMessages];
                
            } andIconTapGesture:^{
                MXStrongifyAndReturnIfNil(self);
                
                if (self->currentAlert)
                {
                    [self->currentAlert dismissViewControllerAnimated:NO completion:nil];
                }
                
                MXWeakify(self);
                UIAlertController *resendAlert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
                
                [resendAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n roomResendUnsentMessages]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                    
                    MXStrongifyAndReturnIfNil(self);
                    
                    [self resendAllUnsentMessages];
                    self->currentAlert = nil;
                    
                }]];
                
                [resendAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n roomDeleteUnsentMessages]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                    
                    MXStrongifyAndReturnIfNil(self);
                    
                    [self cancelAllUnsentMessages];
                    self->currentAlert = nil;
                    
                }]];
                
                [resendAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                                style:UIAlertActionStyleCancel
                                                              handler:^(UIAlertAction * action) {
                    
                    MXStrongifyAndReturnIfNil(self);
                    
                    self->currentAlert = nil;
                    
                }]];
                
                [resendAlert mxk_setAccessibilityIdentifier:@"RoomVCUnsentMessagesMenuAlert"];
                [resendAlert popoverPresentationController].sourceView = roomActivitiesView;
                [resendAlert popoverPresentationController].sourceRect = roomActivitiesView.bounds;
                [self presentViewController:resendAlert animated:YES completion:nil];
                self->currentAlert = resendAlert;
                
            }];
        }
    }
    
    return sentStatus != MXRoomSummarySentStatusOk;
}

- (void)eventDidChangeSentState:(NSNotification *)notif
{
    // We are only interested by event that has just failed in their encryption
    // because of unknown devices in the room
    MXEvent *event = notif.object;
    if (event.sentState == MXEventSentStateFailed &&
        [event.roomId isEqualToString:self.roomDataSource.roomId]
        && [event.sentError.domain isEqualToString:MXEncryptingErrorDomain]
        && event.sentError.code == MXEncryptingErrorUnknownDeviceCode
        && !unknownDevices)   // Show the alert once in case of resending several events
    {
        __weak __typeof(self) weakSelf = self;
        
        [self dismissTemporarySubViews];
        
        // List all unknown devices
        unknownDevices  = [[MXUsersDevicesMap alloc] init];
        
        NSArray<MXEvent*> *outgoingMsgs = self.roomDataSource.room.outgoingMessages;
        for (MXEvent *event in outgoingMsgs)
        {
            if (event.sentState == MXEventSentStateFailed
                && [event.sentError.domain isEqualToString:MXEncryptingErrorDomain]
                && event.sentError.code == MXEncryptingErrorUnknownDeviceCode)
            {
                MXUsersDevicesMap<MXDeviceInfo*> *eventUnknownDevices = event.sentError.userInfo[MXEncryptingErrorUnknownDeviceDevicesKey];
                
                [unknownDevices addEntriesFromMap:eventUnknownDevices];
            }
        }
        
        UIAlertController *unknownDevicesAlert = [UIAlertController alertControllerWithTitle:[VectorL10n unknownDevicesAlertTitle]
                                                                                     message:[VectorL10n unknownDevicesAlert]
                                                                              preferredStyle:UIAlertControllerStyleAlert];
        
        [unknownDevicesAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n unknownDevicesVerify]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                self->currentAlert = nil;
                
                [self performSegueWithIdentifier:@"showUnknownDevices" sender:self];
            }
            
        }]];
        
        [unknownDevicesAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n unknownDevicesSendAnyway]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
            
            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                self->currentAlert = nil;
                
                // Acknowledge the existence of all devices
                self->unknownDevices = nil;
                
                // And resend pending messages
                [self resendAllUnsentMessages];
            }
            
        }]];
        
        [unknownDevicesAlert mxk_setAccessibilityIdentifier:@"RoomVCUnknownDevicesAlert"];
        [self presentViewController:unknownDevicesAlert animated:YES completion:nil];
        currentAlert = unknownDevicesAlert;
    }
}

- (void)eventDidChangeIdentifier:(NSNotification *)notif
{
    MXEvent *event = notif.object;
    NSString *previousId = notif.userInfo[kMXEventIdentifierKey];
    
    if ([self.customizedRoomDataSource.selectedEventId isEqualToString:previousId])
    {
        MXLogDebug(@"[RoomVC] eventDidChangeIdentifier: Update selectedEventId");
        self.customizedRoomDataSource.selectedEventId = event.eventId;
    }
}


- (void)resendAllUnsentMessages
{
    // List unsent event ids
    NSArray *outgoingMsgs = self.roomDataSource.room.outgoingMessages;
    NSMutableArray *failedEventIds = [NSMutableArray arrayWithCapacity:outgoingMsgs.count];
    
    for (MXEvent *event in outgoingMsgs)
    {
        if (event.sentState == MXEventSentStateFailed)
        {
            [failedEventIds addObject:event.eventId];
        }
    }
    
    // Launch iterative operation
    [self resendFailedEvent:0 inArray:failedEventIds];
}

- (void)resendFailedEvent:(NSUInteger)index inArray:(NSArray*)failedEventIds
{
    if (index < failedEventIds.count)
    {
        NSString *failedEventId = failedEventIds[index];
        NSUInteger nextIndex = index + 1;
        
        // Let the datasource resend. It will manage local echo, etc.
        [self.roomDataSource resendEventWithEventId:failedEventId success:^(NSString *eventId) {
            
            [self resendFailedEvent:nextIndex inArray:failedEventIds];
            
        } failure:^(NSError *error) {
            
            [self resendFailedEvent:nextIndex inArray:failedEventIds];
            
        }];
        
        return;
    }
    
    // Refresh activities view
    [self refreshActivitiesViewDisplay];
}

- (void)cancelAllUnsentMessages
{
    UIAlertController *cancelAlert = [UIAlertController alertControllerWithTitle:[VectorL10n roomUnsentMessagesCancelTitle]
                                                                         message:[VectorL10n roomUnsentMessagesCancelMessage]
                                                                  preferredStyle:UIAlertControllerStyleAlert];
    
    MXWeakify(self);
    [cancelAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel] style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        MXStrongifyAndReturnIfNil(self);
        self->currentAlert = nil;
    }]];
    
    [cancelAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n delete] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        MXStrongifyAndReturnIfNil(self);
        // Remove unsent event ids
        for (NSUInteger index = 0; index < self.roomDataSource.room.outgoingMessages.count;)
        {
            MXEvent *event = self.roomDataSource.room.outgoingMessages[index];
            if (event.sentState == MXEventSentStateFailed)
            {
                [self.roomDataSource removeEventWithEventId:event.eventId];
            }
            else
            {
                index ++;
            }
        }
        
        [self refreshActivitiesViewDisplay];
        self->currentAlert = nil;
    }]];
    
    [self presentViewController:cancelAlert animated:YES completion:nil];
    currentAlert = cancelAlert;
}

# pragma mark - Encryption Information view

- (void)showEncryptionInformation:(MXEvent *)event
{
    [self dismissKeyboard];
    
    // Remove potential existing subviews
    [self dismissTemporarySubViews];
    
    EncryptionInfoView *encryptionInfoView = [[EncryptionInfoView alloc] initWithEvent:event andMatrixSession:self.roomDataSource.mxSession];
    
    // Add shadow on added view
    encryptionInfoView.layer.cornerRadius = 5;
    encryptionInfoView.layer.shadowOffset = CGSizeMake(0, 1);
    encryptionInfoView.layer.shadowOpacity = 0.5f;
    
    // Add the view and define edge constraints
    [self.view addSubview:encryptionInfoView];
    
    self->encryptionInfoView = encryptionInfoView;
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated"
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:encryptionInfoView
                                                          attribute:NSLayoutAttributeTop
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.topLayoutGuide
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1.0f
                                                           constant:10.0f]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:encryptionInfoView
                                                          attribute:NSLayoutAttributeBottom
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:self.bottomLayoutGuide
                                                          attribute:NSLayoutAttributeTop
                                                         multiplier:1.0f
                                                           constant:-10.0f]];
    #pragma clang diagnostic pop
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                          attribute:NSLayoutAttributeLeading
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:encryptionInfoView
                                                          attribute:NSLayoutAttributeLeading
                                                         multiplier:1.0f
                                                           constant:-10.0f]];
    
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view
                                                          attribute:NSLayoutAttributeTrailing
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:encryptionInfoView
                                                          attribute:NSLayoutAttributeTrailing
                                                         multiplier:1.0f
                                                           constant:10.0f]];
    [self.view setNeedsUpdateConstraints];
}



#pragma mark - Read marker handling

- (void)checkReadMarkerVisibility
{
    if (readMarkerTableViewCell && isAppeared && !self.isBubbleTableViewDisplayInTransition)
    {
        // Check whether the read marker is visible
        CGFloat contentTopPosY = self.bubblesTableView.contentOffset.y + self.bubblesTableView.adjustedContentInset.top;
        CGFloat readMarkerViewPosY = readMarkerTableViewCell.frame.origin.y + readMarkerTableViewCell.readMarkerView.frame.origin.y;
        if (contentTopPosY <= readMarkerViewPosY)
        {
            // Compute the max vertical position visible according to contentOffset
            CGFloat contentBottomPosY = self.bubblesTableView.contentOffset.y + self.bubblesTableView.frame.size.height - self.bubblesTableView.adjustedContentInset.bottom;
            if (readMarkerViewPosY <= contentBottomPosY)
            {
                // Launch animation
                [self animateReadMarkerView];
                
                // Disable the read marker display when it has been rendered once.
                self.roomDataSource.showReadMarker = NO;
                [self refreshJumpToLastUnreadBannerDisplay];
                
                // Update the read marker position according the events acknowledgement in this view controller.
                self.updateRoomReadMarker = YES;
                
                if (self.roomDataSource.isLive)
                {
                    // Move the read marker to the current read receipt position.
                    [self.roomDataSource.room forgetReadMarker];
                }
            }
        }
    }
}

- (void)animateReadMarkerView
{
    // Check whether the cell with the read marker is known and if the marker is not animated yet.
    
    if (!readMarkerTableViewCell || readMarkerTableViewCell.readMarkerView.isHidden == NO)
    {
        return;
    }
        
    RoomBubbleCellData *cellData = (RoomBubbleCellData*)readMarkerTableViewCell.bubbleData;
    
    id<RoomTimelineCellDecorator> cellDecorator = [RoomTimelineConfiguration shared].currentStyle.cellDecorator;
    
    [cellDecorator dissmissReadMarkerViewForCell:readMarkerTableViewCell
                                        cellData:cellData
                                        animated:YES
                                      completion:^{
       
        self->readMarkerTableViewCell = nil;
    }];
}

- (void)refreshRemoveJitsiWidgetView
{
    if (!self.displayConfiguration.jitsiWidgetRemoverEnabled)
    {
        return;
    }
    
    if (self.roomDataSource.isLive && !self.roomDataSource.isPeeking)
    {
        Widget *jitsiWidget = [self.customizedRoomDataSource jitsiWidget];
        
        if (jitsiWidget && self.canEditJitsiWidget)
        {
            [self.removeJitsiWidgetView reset];
            self.removeJitsiWidgetContainer.hidden = NO;
            self.removeJitsiWidgetView.delegate = self;
        }
        else
        {
            self.removeJitsiWidgetContainer.hidden = YES;
            self.removeJitsiWidgetView.delegate = nil;
        }
    }
    else
    {
        [self.removeJitsiWidgetView reset];
        self.removeJitsiWidgetContainer.hidden = YES;
        self.removeJitsiWidgetView.delegate = self;
    }
}

- (void)refreshJumpToLastUnreadBannerDisplay
{
    // This banner is only displayed when the room timeline is in live (and no peeking).
    // Check whether the read marker exists and has not been rendered yet.
    if (self.roomDataSource.isLive && !self.roomDataSource.isPeeking && self.roomDataSource.showReadMarker && self.roomDataSource.room.accountData.readMarkerEventId)
    {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            return [evaluatedObject isKindOfClass:MXKRoomBubbleTableViewCell.class];
        }];
        NSArray *visibleCells = [[self.bubblesTableView visibleCells] filteredArrayUsingPredicate:predicate];
        UITableViewCell *cell = visibleCells.firstObject;
        if (cell)
        {
            MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell*)cell;
            // Check whether the read marker is inside the first displayed cell.
            if (roomBubbleTableViewCell.readMarkerView)
            {
                // The read marker display is still enabled (see roomDataSource.showReadMarker flag),
                // this means the read marker was not been visible yet.
                // We show the banner if the marker is located in the top hidden part of the cell.
                CGFloat contentTopPosY = self.bubblesTableView.contentOffset.y + self.bubblesTableView.adjustedContentInset.top;
                CGFloat readMarkerViewPosY = roomBubbleTableViewCell.frame.origin.y + roomBubbleTableViewCell.readMarkerView.frame.origin.y;
                self.jumpToLastUnreadBannerContainer.hidden = (contentTopPosY < readMarkerViewPosY);
            }
            else
            {
                // Check whether the read marker event is anterior to the first event displayed in the first rendered cell.
                MXKRoomBubbleComponent *component = roomBubbleTableViewCell.bubbleData.bubbleComponents.firstObject;
                MXEvent *firstDisplayedEvent = component.event;
                MXEvent *currentReadMarkerEvent = [self.roomDataSource.mxSession.store eventWithEventId:self.roomDataSource.room.accountData.readMarkerEventId inRoom:self.roomDataSource.roomId];
                
                if (!currentReadMarkerEvent || (currentReadMarkerEvent.originServerTs < firstDisplayedEvent.originServerTs))
                {
                    self.jumpToLastUnreadBannerContainer.hidden = NO;
                }
                else
                {
                    self.jumpToLastUnreadBannerContainer.hidden = YES;
                    
                    // Force the read marker position in order to not depend on the read marker animation (https://github.com/vector-im/element-ios/issues/7420)
                    self.updateRoomReadMarker = YES;
                }
            }
        }
    }
    else
    {
        self.jumpToLastUnreadBannerContainer.hidden = YES;
        
        // Initialize the read marker if it does not exist yet, only in case of live timeline.
        if (!self.roomDataSource.room.accountData.readMarkerEventId && self.roomDataSource.isLive && !self.roomDataSource.isPeeking)
        {
            // Move the read marker to the current read receipt position by default.
            [self.roomDataSource.room forgetReadMarker];
        }
    }
}

#pragma mark - ContactsTableViewControllerDelegate

- (void)contactsTableViewController:(ContactsTableViewController *)contactsTableViewController didSelectContact:(MXKContact*)contact
{
    __weak typeof(self) weakSelf = self;
    
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    // Invite ?
    NSString *promptMsg = [VectorL10n roomParticipantsInvitePromptMsg:contact.displayName];
    UIAlertController *invitePrompt = [UIAlertController alertControllerWithTitle:[VectorL10n roomParticipantsInvitePromptTitle]
                                                                         message:promptMsg
                                                                  preferredStyle:UIAlertControllerStyleAlert];
    
    [invitePrompt addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                     style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction * action) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            self->currentAlert = nil;
        }
        
    }]];
    
    [invitePrompt addAction:[UIAlertAction actionWithTitle:[VectorL10n invite]
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
        
        // Sanity check
        if (!weakSelf)
        {
            return;
        }
        
        typeof(self) self = weakSelf;
        self->currentAlert = nil;
        
        MXSession* session = self.roomDataSource.mxSession;
        NSString* roomId = self.roomDataSource.roomId;
        MXRoom *room = [session roomWithRoomId:roomId];
        
        NSArray *identifiers = contact.matrixIdentifiers;
        NSString *participantId;
        
        if (identifiers.count)
        {
            participantId = identifiers.firstObject;
            
            // Invite this user if a room is defined
            [room inviteUser:participantId success:^{
                
                // Refresh display by removing the contacts picker
                [contactsTableViewController withdrawViewControllerAnimated:YES completion:nil];
                
            } failure:^(NSError *error) {
                
                MXLogDebug(@"[RoomVC] Invite %@ failed", participantId);
                // Alert user
                [self showError:error];
                
            }];
        }
        else
        {
            if (contact.emailAddresses.count)
            {
                // This is a local contact, consider the first email by default.
                // TODO: Prompt the user to select the right email.
                MXKEmail *email = contact.emailAddresses.firstObject;
                participantId = email.emailAddress;
            }
            else
            {
                // This is the text filled by the user.
                participantId = contact.displayName;
            }
            
            // Is it an email or a Matrix user ID?
            if ([MXTools isEmailAddress:participantId])
            {
                [room inviteUserByEmail:participantId success:^{
                    
                    // Refresh display by removing the contacts picker
                    [contactsTableViewController withdrawViewControllerAnimated:YES completion:nil];
                    
                } failure:^(NSError *error) {
                    
                    MXLogDebug(@"[RoomVC] Invite be email %@ failed", participantId);
                    // Alert user
                    if ([error.domain isEqualToString:kMXRestClientErrorDomain]
                        && error.code == MXRestClientErrorMissingIdentityServer)
                    {
                        [self showAlertWithTitle:[VectorL10n errorInvite3pidWithNoIdentityServer] message:nil];
                    }
                    else
                    {
                        [self showError:error];
                    }
                }];
            }
            else //if ([MXTools isMatrixUserIdentifier:participantId])
            {
                [room inviteUser:participantId success:^{
                    
                    // Refresh display by removing the contacts picker
                    [contactsTableViewController withdrawViewControllerAnimated:YES completion:nil];
                    
                } failure:^(NSError *error) {
                    
                    MXLogDebug(@"[RoomVC] Invite %@ failed", participantId);
                    // Alert user
                    [self showError:error];
                    
                }];
            }
        }
        
    }]];
    
    [invitePrompt mxk_setAccessibilityIdentifier:@"RoomVCInviteAlert"];
    [self presentViewController:invitePrompt animated:YES completion:nil];
    currentAlert = invitePrompt;
}

#pragma mark - Re-request encryption keys

- (void)reRequestKeysAndShowExplanationAlert:(MXEvent*)event
{
    MXWeakify(self);
    __block UIAlertController *alert;
    
    // Force device verification if session has cross-signing activated and device is not yet verified
    if (self.mainSession.crypto.crossSigning && self.mainSession.crypto.crossSigning.state == MXCrossSigningStateCrossSigningExists)
    {
        [self presentReviewUnverifiedSessionsAlert];
        return;
    }
    
    // Make the re-request
    [self.mainSession.crypto reRequestRoomKeyForEvent:event];
    
    // Observe kMXEventDidDecryptNotification to remove automatically the dialog
    // if the user has shared the keys from another device
    mxEventDidDecryptNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXEventDidDecryptNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        MXStrongifyAndReturnIfNil(self);
        
        MXEvent *decryptedEvent = notif.object;
        
        if ([decryptedEvent.eventId isEqualToString:event.eventId])
        {
            [[NSNotificationCenter defaultCenter] removeObserver:self->mxEventDidDecryptNotificationObserver];
            self->mxEventDidDecryptNotificationObserver = nil;
            
            if (self->currentAlert == alert)
            {
                [self->currentAlert dismissViewControllerAnimated:YES completion:nil];
                self->currentAlert = nil;
            }
        }
    }];
    
    // Show the explanation dialog
    alert = [UIAlertController alertControllerWithTitle:VectorL10n.rerequestKeysAlertTitle
                                                message:[VectorL10n e2eRoomKeyRequestMessage:AppInfo.current.displayName]
                                         preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:[VectorL10n ok]
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * action)
                      {
        MXStrongifyAndReturnIfNil(self);
        
        [[NSNotificationCenter defaultCenter] removeObserver:self->mxEventDidDecryptNotificationObserver];
        self->mxEventDidDecryptNotificationObserver = nil;
        
        self->currentAlert = nil;
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
    currentAlert = alert;
}

- (void)presentReviewUnverifiedSessionsAlert
{
    MXLogDebug(@"[MasterTabBarController] presentReviewUnverifiedSessionsAlertWithSession");
    
    [currentAlert dismissViewControllerAnimated:NO completion:nil];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[VectorL10n keyVerificationAlertTitle]
                                                                   message:[VectorL10n keyVerificationAlertBody]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:[VectorL10n keyVerificationSelfVerifyUnverifiedSessionsAlertValidateAction]
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * action) {
        [self showSettingsSecurityScreen];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:[VectorL10n later]
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
    
    currentAlert = alert;
}

- (void)showSettingsSecurityScreen
{
    if (self.delegate)
    {
        [self.delegate roomViewController:self showCompleteSecurityForSession:self.mainSession];
    }
    else
    {
        [[AppDelegate theDelegate] presentCompleteSecurityForSession: self.mainSession];
    }
}

#pragma mark Tombstone event

- (void)listenTombstoneEventNotifications
{
    // Room is already obsolete do not listen to tombstone event
    if (self.roomDataSource.roomState.isObsolete)
    {
        return;
    }
    
    MXWeakify(self);
    
    tombstoneEventNotificationsListener = [self.roomDataSource.room listenToEventsOfTypes:@[kMXEventTypeStringRoomTombStone] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {
        
        MXStrongifyAndReturnIfNil(self);
        
        // Update activitiesView with room replacement information
        [self refreshActivitiesViewDisplay];
        // Hide inputToolbarView
        [self updateRoomInputToolbarViewClassIfNeeded];
    }];
}

- (void)removeTombstoneEventNotificationsListener
{
    if (self.roomDataSource)
    {
        // Remove the previous live listener
        if (tombstoneEventNotificationsListener)
        {
            [self.roomDataSource.room removeListener:tombstoneEventNotificationsListener];
            tombstoneEventNotificationsListener = nil;
        }
    }
}

#pragma mark MXSession state change

- (void)listenMXSessionStateChangeNotifications
{
    MXWeakify(self);
    
    kMXSessionStateDidChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:self.roomDataSource.mxSession queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
        
        MXStrongifyAndReturnIfNil(self);
        
        if (self.roomDataSource.mxSession.state == MXSessionStateSyncError
            || self.roomDataSource.mxSession.state == MXSessionStateRunning)
        {
            [self refreshActivitiesViewDisplay];
            
            // update inputToolbarView
            [self updateRoomInputToolbarViewClassIfNeeded];
        }
    }];
}

- (void)removeMXSessionStateChangeNotificationsListener
{
    if (kMXSessionStateDidChangeObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:kMXSessionStateDidChangeObserver];
        kMXSessionStateDidChangeObserver = nil;
    }
}

#pragma mark - Contextual Menu

- (NSArray<RoomContextualMenuItem*>*)contextualMenuItemsForEvent:(MXEvent*)event andCell:(id<MXKCellRendering>)cell
{
    if (event.sentState == MXEventSentStateFailed)
    {
        return @[
            [self resendMenuItemWithEvent:event],
            [self deleteMenuItemWithEvent:event],
            [self editMenuItemWithEvent:event],
            [self copyMenuItemWithEvent:event andCell:cell]
        ];
    }
    
    BOOL showMoreOption = (event.isState && RiotSettings.shared.roomContextualMenuShowMoreOptionForStates)
        || (!event.isState && RiotSettings.shared.roomContextualMenuShowMoreOptionForMessages);
    BOOL showThreadOption = [self showThreadOptionForEvent:event];
    
    NSMutableArray<RoomContextualMenuItem*> *items = [NSMutableArray arrayWithCapacity:5];
    
    [items addObject:[self replyMenuItemWithEvent:event]];
    if (showThreadOption)
    {
        //  add "Thread" option only if not already in a thread
        [items addObject:[self replyInThreadMenuItemWithEvent:event]];
    }
    [items addObject:[self editMenuItemWithEvent:event]];
    if (!showThreadOption)
    {
        [items addObject:[self copyMenuItemWithEvent:event andCell:cell]];
    }
    if (showMoreOption)
    {
        [items addObject:[self moreMenuItemWithEvent:event andCell:cell]];
    }
    
    return items;
}

- (void)showContextualMenuForEvent:(MXEvent*)event fromSingleTapGesture:(BOOL)usedSingleTapGesture cell:(id<MXKCellRendering>)cell animated:(BOOL)animated
{
    if (self.roomContextualMenuPresenter.isPresenting)
    {
        return;
    }
    
    NSString *selectedEventId = event.eventId;
    
    NSArray<RoomContextualMenuItem*>* contextualMenuItems = [self contextualMenuItemsForEvent:event andCell:cell];
    ReactionsMenuViewModel *reactionsMenuViewModel;
    CGRect bubbleComponentFrameInOverlayView = CGRectNull;
    
    if ([cell isKindOfClass:MXKRoomBubbleTableViewCell.class] && [self.roomDataSource canReactToEventWithId:event.eventId])
    {
        MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell*)cell;
        MXKRoomBubbleCellData *bubbleCellData = roomBubbleTableViewCell.bubbleData;
        NSArray *bubbleComponents = bubbleCellData.bubbleComponents;
        
        NSInteger foundComponentIndex = [bubbleCellData bubbleComponentIndexForEventId:event.eventId];
        CGRect bubbleComponentFrame;
        
        if (bubbleComponents.count > 0)
        {
            NSInteger selectedComponentIndex = foundComponentIndex != NSNotFound ? foundComponentIndex : 0;
            bubbleComponentFrame = [roomBubbleTableViewCell surroundingFrameInTableViewForComponentIndex:selectedComponentIndex];
        }
        else
        {
            bubbleComponentFrame = roomBubbleTableViewCell.frame;
        }
        
        bubbleComponentFrameInOverlayView = [self.bubblesTableView convertRect:bubbleComponentFrame toView:self.overlayContainerView];
        
        NSString *roomId = self.roomDataSource.roomId;
        MXAggregations *aggregations = self.mainSession.aggregations;
        MXAggregatedReactions *aggregatedReactions = [aggregations aggregatedReactionsOnEvent:selectedEventId inRoom:roomId];
        
        reactionsMenuViewModel = [[ReactionsMenuViewModel alloc] initWithAggregatedReactions:aggregatedReactions eventId:selectedEventId];
        reactionsMenuViewModel.coordinatorDelegate = self;
    }
    
    if (!self.roomContextualMenuViewController)
    {
        self.roomContextualMenuViewController = [RoomContextualMenuViewController instantiate];
        self.roomContextualMenuViewController.delegate = self;
    }
    
    [self.roomContextualMenuViewController updateWithContextualMenuItems:contextualMenuItems reactionsMenuViewModel:reactionsMenuViewModel];
    
    [self enableOverlayContainerUserInteractions:YES];
    
    [self.roomContextualMenuPresenter presentWithRoomContextualMenuViewController:self.roomContextualMenuViewController
                                                                             from:self
                                                                               on:self.overlayContainerView
                                                              contentToReactFrame:bubbleComponentFrameInOverlayView
                                                             fromSingleTapGesture:usedSingleTapGesture
                                                                         animated:animated
                                                                       completion:^{
    }];
    
    preventBubblesTableViewScroll = YES;
    [self selectEventWithId:selectedEventId];
}

- (void)hideContextualMenuAnimated:(BOOL)animated
{
    [self hideContextualMenuAnimated:animated completion:nil];
}

- (void)hideContextualMenuAnimated:(BOOL)animated completion:(void(^)(void))completion
{
    [self hideContextualMenuAnimated:animated cancelEventSelection:YES completion:completion];
}

- (void)hideContextualMenuAnimated:(BOOL)animated cancelEventSelection:(BOOL)cancelEventSelection completion:(void(^)(void))completion
{
    if (!self.roomContextualMenuPresenter.isPresenting)
    {
        return;
    }
    
    if (cancelEventSelection)
    {
        [self cancelEventSelection];
    }
    
    preventBubblesTableViewScroll = NO;
    
    [self.roomContextualMenuPresenter hideContextualMenuWithAnimated:animated completion:^{
        [self enableOverlayContainerUserInteractions:NO];
        
        if (completion)
        {
            completion();
        }
    }];
}

- (void)enableOverlayContainerUserInteractions:(BOOL)enableOverlayContainerUserInteractions
{
    self.inputToolbarView.editable = !enableOverlayContainerUserInteractions;
    self.bubblesTableView.scrollsToTop = !enableOverlayContainerUserInteractions;
    self.overlayContainerView.userInteractionEnabled = enableOverlayContainerUserInteractions;
}

- (RoomContextualMenuItem *)resendMenuItemWithEvent:(MXEvent*)event
{
    MXWeakify(self);
    
    RoomContextualMenuItem *resendMenuItem = [[RoomContextualMenuItem alloc] initWithMenuAction:RoomContextualMenuActionResend];
    resendMenuItem.action = ^{
        MXStrongifyAndReturnIfNil(self);
        [self hideContextualMenuAnimated:YES cancelEventSelection:NO completion:nil];
        [self cancelEventSelection];
        [self.roomDataSource resendEventWithEventId:event.eventId success:nil failure:nil];
    };
    
    return resendMenuItem;
}

- (RoomContextualMenuItem *)deleteMenuItemWithEvent:(MXEvent*)event
{
    MXWeakify(self);
    
    RoomContextualMenuItem *deleteMenuItem = [[RoomContextualMenuItem alloc] initWithMenuAction:RoomContextualMenuActionDelete];
    deleteMenuItem.action = ^{
        MXStrongifyAndReturnIfNil(self);
        
        MXWeakify(self);
        [self hideContextualMenuAnimated:YES cancelEventSelection:YES completion:^{
            MXStrongifyAndReturnIfNil(self);
            
            UIAlertController *deleteConfirmation = [UIAlertController alertControllerWithTitle:[VectorL10n roomEventActionDeleteConfirmationTitle]
                                                                                        message:[VectorL10n roomEventActionDeleteConfirmationMessage]
                                                                                 preferredStyle:UIAlertControllerStyleAlert];
            
            [deleteConfirmation addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel] style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            }]];
            
            [deleteConfirmation addAction:[UIAlertAction actionWithTitle:[VectorL10n delete] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
                [self.roomDataSource removeEventWithEventId:event.eventId];
            }]];
            
            [self presentViewController:deleteConfirmation animated:YES completion:nil];
            self->currentAlert = deleteConfirmation;
        }];
    };
    
    return deleteMenuItem;
}

- (RoomContextualMenuItem *)editMenuItemWithEvent:(MXEvent*)event
{
    MXWeakify(self);
    
    RoomContextualMenuItem *editMenuItem = [[RoomContextualMenuItem alloc] initWithMenuAction:RoomContextualMenuActionEdit];
    
    switch (event.eventType) {
        case MXEventTypePollStart: {
            editMenuItem.action = ^{
                MXStrongifyAndReturnIfNil(self);
                [self hideContextualMenuAnimated:YES cancelEventSelection:YES completion:nil];
                [self.delegate roomViewController:self didRequestEditForPollWithStartEvent:event];
            };
            
            editMenuItem.isEnabled = [self.delegate roomViewController:self canEditPollWithEventIdentifier:event.eventId];
            
            break;
        }
        default: {
            editMenuItem.action = ^{
                MXStrongifyAndReturnIfNil(self);
                [self hideContextualMenuAnimated:YES cancelEventSelection:NO completion:nil];
                [self editEventContentWithId:event.eventId];
                
                // And display the keyboard
                [self.inputToolbarView becomeFirstResponder];
            };
            
            editMenuItem.isEnabled = [self.roomDataSource canEditEventWithId:event.eventId];
            
            break;
        }
    }
    
    return editMenuItem;
}

- (RoomContextualMenuItem *)copyMenuItemWithEvent:(MXEvent*)event andCell:(id<MXKCellRendering>)cell
{
    MXWeakify(self);
    
    RoomContextualMenuItem *copyMenuItem = [[RoomContextualMenuItem alloc] initWithMenuAction:RoomContextualMenuActionCopy];
    copyMenuItem.isEnabled = [self canCopyEvent:event andCell:cell];
    MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell *)cell;
    MXKRoomBubbleCellData *cellData = roomBubbleTableViewCell.bubbleData;
    copyMenuItem.action = ^{
        MXStrongifyAndReturnIfNil(self);
        
        [self copyEvent:event inCell:cell withCellData:cellData];
    };
    
    return copyMenuItem;
}

- (BOOL)canCopyEvent:(MXEvent*)event andCell:(id<MXKCellRendering>)cell
{
    MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell *)cell;
    MXKAttachment *attachment = roomBubbleTableViewCell.bubbleData.attachment;
    
    BOOL result = !attachment || attachment.type != MXKAttachmentTypeSticker;
    
    if (attachment && !BuildSettings.messageDetailsAllowCopyMedia)
    {
        result = NO;
    }
    
    if (result)
    {
        switch (event.eventType) {
            case MXEventTypeRoomMessage:
            {
                NSString *messageType = event.content[kMXMessageTypeKey];
                
                if ([messageType isEqualToString:kMXMessageTypeKeyVerificationRequest])
                {
                    result = NO;
                }
                break;
            }
            case MXEventTypeKeyVerificationStart:
            case MXEventTypeKeyVerificationAccept:
            case MXEventTypeKeyVerificationKey:
            case MXEventTypeKeyVerificationMac:
            case MXEventTypeKeyVerificationDone:
            case MXEventTypeKeyVerificationCancel:
            case MXEventTypePollStart:
            case MXEventTypePollEnd:
            case MXEventTypeBeaconInfo:
                result = NO;
                break;
            case MXEventTypeCustom:
                if ([event.type isEqualToString:kWidgetMatrixEventTypeString]
                    || [event.type isEqualToString:kWidgetModularEventTypeString])
                {
                    Widget *widget = [[Widget alloc] initWithWidgetEvent:event inMatrixSession:self.roomDataSource.mxSession];
                    if ([widget.type isEqualToString:kWidgetTypeJitsiV1] ||
                        [widget.type isEqualToString:kWidgetTypeJitsiV2])
                    {
                        result = NO;
                    }
                }
            default:
                break;
        }
    }
    
    return result;
}

- (void)copyEvent:(MXEvent*)event inCell:(id<MXKCellRendering>)cell withCellData:(MXKRoomBubbleCellData *)cellData
{
    MXKRoomBubbleTableViewCell *roomBubbleTableViewCell = (MXKRoomBubbleTableViewCell *)cell;
    MXKAttachment *attachment = cellData.attachment;
    
    if (!attachment)
    {
        NSArray *components = cellData.bubbleComponents;
        MXKRoomBubbleComponent *selectedComponent;
        for (selectedComponent in components)
        {
            if ([selectedComponent.event.eventId isEqualToString:event.eventId])
            {
                break;
            }
            selectedComponent = nil;
        }

        NSAttributedString *attributedTextMessage = selectedComponent.attributedTextMessage;
        
        if (attributedTextMessage)
        {
            if (@available(iOS 15.0, *))
            {
                MXKPasteboardManager.shared.pasteboard.string = [PillsFormatter stringByReplacingPillsIn:attributedTextMessage
                                                                                                    mode:PillsReplacementTextModeMarkdown];
            }
            else
            {
                MXKPasteboardManager.shared.pasteboard.string = attributedTextMessage.string;
            }
        }
        else
        {
            MXLogDebug(@"[RoomViewController] Contextual menu copy failed. Text is nil for room id/event id: %@/%@", selectedComponent.event.roomId, selectedComponent.event.eventId);
        }
        
        [self hideContextualMenuAnimated:YES];
    }
    else if (attachment.type != MXKAttachmentTypeSticker)
    {
        [self hideContextualMenuAnimated:YES completion:^{
            [self startActivityIndicator];
            
            [attachment copy:^{
                
                [self stopActivityIndicator];
                
            } failure:^(NSError *error) {
                
                [self stopActivityIndicator];
                
                //Alert user
                [self showError:error];
            }];
            
            // Start animation in case of download during attachment preparing
            [roomBubbleTableViewCell startProgressUI];
        }];
    }
}

- (RoomContextualMenuItem *)replyMenuItemWithEvent:(MXEvent*)event
{
    MXWeakify(self);
    
    RoomContextualMenuItem *replyMenuItem = [[RoomContextualMenuItem alloc] initWithMenuAction:RoomContextualMenuActionReply];
    replyMenuItem.isEnabled = [self.roomDataSource canReplyToEventWithId:event.eventId] && !self.voiceMessageController.isRecordingAudio;
    replyMenuItem.action = ^{
        MXStrongifyAndReturnIfNil(self);
        
        [self hideContextualMenuAnimated:YES cancelEventSelection:NO completion:nil];
        [self selectEventWithId:event.eventId inputToolBarSendMode:RoomInputToolbarViewSendModeReply showTimestamp:NO];
        
        // And display the keyboard
        [self.inputToolbarView becomeFirstResponder];
    };
    
    return replyMenuItem;
}

- (RoomContextualMenuItem *)replyInThreadMenuItemWithEvent:(MXEvent*)event
{
    MXWeakify(self);
    
    RoomContextualMenuItem *item = [[RoomContextualMenuItem alloc] initWithMenuAction:RoomContextualMenuActionReplyInThread];
    item.isEnabled = [self.roomDataSource canReplyToEventWithId:event.eventId] && !self.voiceMessageController.isRecordingAudio;
    item.action = ^{
        MXStrongifyAndReturnIfNil(self);
        
        [self hideContextualMenuAnimated:YES cancelEventSelection:NO completion:nil];

        if (RiotSettings.shared.enableThreads)
        {
            [self openThreadWithId:event.eventId];
        }
        else
        {
            [self showThreadsBetaForEvent:event];
        }
    };
    
    return item;
}

- (RoomContextualMenuItem *)moreMenuItemWithEvent:(MXEvent*)event andCell:(id<MXKCellRendering>)cell
{
    MXWeakify(self);
    
    RoomContextualMenuItem *moreMenuItem = [[RoomContextualMenuItem alloc] initWithMenuAction:RoomContextualMenuActionMore];
    moreMenuItem.action = ^{
        MXStrongifyAndReturnIfNil(self);
        [self hideContextualMenuAnimated:YES completion:nil];
        [self showAdditionalActionsMenuForEvent:event inCell:cell animated:YES];
    };
    
    return moreMenuItem;
}

#pragma mark - Threads

- (BOOL)showThreadOptionForEvent:(MXEvent*)event
{
    return !self.roomDataSource.threadId
        && !event.threadId
        && (RiotSettings.shared.enableThreads || self.mainSession.store.supportedMatrixVersions.supportsThreads);
}

- (void)showThreadsNotice
{
    if (!self.threadsNoticeModalPresenter)
    {
        self.threadsNoticeModalPresenter = [SlidingModalPresenter new];
    }

    [self.threadsNoticeModalPresenter dismissWithAnimated:NO completion:nil];

    ThreadsNoticeViewController *threadsNoticeVC = [ThreadsNoticeViewController instantiate];

    MXWeakify(self);

    threadsNoticeVC.didTapDoneButton = ^{

        MXStrongifyAndReturnIfNil(self);

        [self.threadsNoticeModalPresenter dismissWithAnimated:YES completion:^{
            RiotSettings.shared.threadsNoticeDisplayed = YES;
        }];
    };

    [self.threadsNoticeModalPresenter present:threadsNoticeVC
                                         from:self.presentedViewController?:self
                                     animated:YES
                                      options:SlidingModalPresenter.SpanningOption
                                   completion:nil];
}

- (void)showThreadsBetaForEvent:(MXEvent *)event
{
    if (self.threadsBetaBridgePresenter)
    {
        [self.threadsBetaBridgePresenter dismissWithAnimated:YES completion:nil];
        self.threadsBetaBridgePresenter = nil;
    }

    self.threadsBetaBridgePresenter = [[ThreadsBetaCoordinatorBridgePresenter alloc] initWithThreadId:event.eventId
                                                                                             infoText:VectorL10n.threadsBetaInformation
                                                                                       additionalText:nil];
    self.threadsBetaBridgePresenter.delegate = self;

    [self.threadsBetaBridgePresenter presentFrom:self.presentedViewController?:self animated:YES];
}

- (void)openThreadWithId:(NSString *)threadId
{
    if (self.threadsBridgePresenter)
    {
        [self.threadsBridgePresenter dismissWithAnimated:YES completion:nil];
        self.threadsBridgePresenter = nil;
    }

    self.threadsBridgePresenter = [self.delegate threadsCoordinatorForRoomViewController:self threadId:threadId];
    self.threadsBridgePresenter.delegate = self;
    [self.threadsBridgePresenter pushFrom:self.navigationController animated:YES];
}

- (void)highlightAndDisplayEvent:(NSString *)eventId completion:(void (^)(void))completion
{
    NSInteger row = [self.roomDataSource indexOfCellDataWithEventId:eventId];
    if (row == NSNotFound)
    {
        //  event with eventId is not loaded into data source yet, load another data source and display it
        [self startActivityIndicator];
        MXWeakify(self);
        [RoomDataSource loadRoomDataSourceWithRoomId:self.roomDataSource.roomId
                                      initialEventId:eventId
                                            threadId:nil
                                    andMatrixSession:self.roomDataSource.mxSession
                                          onComplete:^(RoomDataSource *roomDataSource) {
            MXStrongifyAndReturnIfNil(self);
            [roomDataSource finalizeInitialization];
            [self stopActivityIndicator];
            roomDataSource.markTimelineInitialEvent = YES;
            [self displayRoom:roomDataSource];
            // Give the data source ownership to the room view controller.
            self.hasRoomDataSourceOwnership = YES;
            if (completion)
            {
                completion();
            }
        }];
        return;
    }
    
    NSMutableArray<NSIndexPath *> *rowsToReload = [[NSMutableArray alloc] init];
    // Get the current hightlighted event because we will need to reload it
    NSString *currentHiglightedEventId = self.customizedRoomDataSource.highlightedEventId;
    if (currentHiglightedEventId)
    {
        NSInteger currentHiglightedRow = [self.roomDataSource indexOfCellDataWithEventId:currentHiglightedEventId];
        if (currentHiglightedRow != NSNotFound)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:currentHiglightedRow inSection:0];
            if ([[self.bubblesTableView indexPathsForVisibleRows] containsObject:indexPath])
            {
                [rowsToReload addObject:indexPath];
            }
        }
    }
    
    self.customizedRoomDataSource.highlightedEventId = eventId;
    
    // Add the new highligted event to the list of rows to reload
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    BOOL indexPathIsVisible = [[self.bubblesTableView indexPathsForVisibleRows] containsObject:indexPath];
    if (indexPathIsVisible)
    {
        [rowsToReload addObject:indexPath];
    }
    
    // Reload rows
    if (rowsToReload.count > 0)
    {
        [self.bubblesTableView reloadRowsAtIndexPaths:rowsToReload
                                     withRowAnimation:UITableViewRowAnimationNone];
    }
    
    // Scroll to the newly highlighted row
    if (indexPathIsVisible || [self.bubblesTableView vc_hasIndexPath:indexPath])
    {
        [self.bubblesTableView scrollToRowAtIndexPath:indexPath
                                     atScrollPosition:UITableViewScrollPositionMiddle
                                             animated:YES];
    }

    if (completion)
    {
        completion();
    }
}

- (void)cancelEventHighlight
{
    //  if data source is highlighting an event, dismiss the highlight when user dragges the table view
    if (self.customizedRoomDataSource.highlightedEventId)
    {
        NSInteger row = [self.roomDataSource indexOfCellDataWithEventId:self.customizedRoomDataSource.highlightedEventId];
        if (row == NSNotFound)
        {
            self.customizedRoomDataSource.highlightedEventId = nil;
            return;
        }
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        if ([[self.bubblesTableView indexPathsForVisibleRows] containsObject:indexPath])
        {
            self.customizedRoomDataSource.highlightedEventId = nil;
            [self.bubblesTableView reloadRowsAtIndexPaths:@[indexPath]
                                         withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

- (void)updateThreadListBarButtonBadgeWith:(MXThreadingService *)service
{
    [self updateThreadListBarButtonItem:nil with:service];
}

- (void)updateThreadListBarButtonItem:(UIBarButtonItem *)barButtonItem with:(MXThreadingService *)service
{
    if (!service || _isWaitingForOtherParticipants)
    {
        return;
    }

    __block NSInteger replaceIndex = NSNotFound;
    [self.navigationItem.rightBarButtonItems enumerateObjectsUsingBlock:^(UIBarButtonItem * _Nonnull item, NSUInteger index, BOOL * _Nonnull stop)
     {
        if (item.tag == kThreadListBarButtonItemTag)
        {
            replaceIndex = index;
            *stop = YES;
        }
    }];

    if (!barButtonItem && replaceIndex == NSNotFound)
    {
        //  there is no thread list bar button item, and not provided another to update
        //  ignore
        return;
    }

    UIBarButtonItem *threadListBarButtonItem = barButtonItem ?: [self threadListBarButtonItem];
    UIButton *button = (UIButton *)threadListBarButtonItem.customView;
    
    MXThreadNotificationsCount *notificationsCount = [service notificationsCountForRoom:self.roomDataSource.roomId];
    
    UIImage *buttonIcon = [AssetImages.threadsIcon.image vc_resizedWith:kThreadListBarButtonItemImageSize];
    [button setImage:buttonIcon forState:UIControlStateNormal];
    button.contentEdgeInsets = kThreadListBarButtonItemContentInsetsNoDot;

    if (notificationsCount.notificationsNumber > 0)
    {
        BadgeLabel *badgeLabel = [[BadgeLabel alloc] init];
        badgeLabel.text = notificationsCount.notificationsNumber > 99 ? @"99+" : [NSString stringWithFormat:@"%lu", notificationsCount.notificationsNumber];
        id<Theme> theme = ThemeService.shared.theme;
        badgeLabel.font = theme.fonts.caption1SB;
        badgeLabel.textColor = theme.colors.navigation;
        badgeLabel.badgeColor = notificationsCount.numberOfHighlightedThreads ? theme.colors.alert : theme.colors.secondaryContent;
        [button addSubview:badgeLabel];
        
        [badgeLabel layoutIfNeeded];
        
        badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [badgeLabel.centerYAnchor constraintEqualToAnchor:button.centerYAnchor
                                                constant:badgeLabel.bounds.size.height - buttonIcon.size.height / 2].active = YES;
        [badgeLabel.centerXAnchor constraintEqualToAnchor:button.centerXAnchor
                                                 constant:badgeLabel.bounds.size.width + buttonIcon.size.width / 2].active = YES;
    }

    if (replaceIndex == NSNotFound)
    {
        // there is no thread list bar button item, this was only an update
        return;
    }

    UIBarButtonItem *originalItem = self.navigationItem.rightBarButtonItems[replaceIndex];
    UIButton *originalButton = (UIButton *)originalItem.customView;
    if ([originalButton imageForState:UIControlStateNormal] == [button imageForState:UIControlStateNormal]
        && UIEdgeInsetsEqualToEdgeInsets(originalButton.contentEdgeInsets, button.contentEdgeInsets))
    {
        //  no need to replace, it's the same
        return;
    }
    NSMutableArray<UIBarButtonItem*> *items = [self.navigationItem.rightBarButtonItems mutableCopy];
    items[replaceIndex] = threadListBarButtonItem;
    self.navigationItem.rightBarButtonItems = items;
}

#pragma mark - RoomContextualMenuViewControllerDelegate

- (void)roomContextualMenuViewControllerDidTapBackgroundOverlay:(RoomContextualMenuViewController *)viewController
{
    [self hideContextualMenuAnimated:YES];
}

#pragma mark - ReactionsMenuViewModelCoordinatorDelegate

- (void)reactionsMenuViewModel:(ReactionsMenuViewModel *)viewModel didAddReaction:(NSString *)reaction forEventId:(NSString *)eventId
{
    MXWeakify(self);
    
    [self hideContextualMenuAnimated:YES completion:^{
        
        [self.roomDataSource addReaction:reaction forEventId:eventId success:^{
            
        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);
            
            [self.errorPresenter presentErrorFromViewController:self forError:error animated:YES handler:nil];
        }];
    }];
}

- (void)reactionsMenuViewModel:(ReactionsMenuViewModel *)viewModel didRemoveReaction:(NSString *)reaction forEventId:(NSString *)eventId
{
    MXWeakify(self);
    
    [self hideContextualMenuAnimated:YES completion:^{
        
        [self.roomDataSource removeReaction:reaction forEventId:eventId success:^{
            
        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);
            
            [self.errorPresenter presentErrorFromViewController:self forError:error animated:YES handler:nil];
        }];
        
    }];
}

- (void)reactionsMenuViewModelDidTapMoreReactions:(ReactionsMenuViewModel *)viewModel forEventId:(NSString *)eventId
{
    [self hideContextualMenuAnimated:YES];

    [self showEmojiPickerForEventId:eventId];
}

#pragma mark -

- (void)showEditHistoryForEventId:(NSString*)eventId animated:(BOOL)animated
{
    MXEvent *event = [self.roomDataSource eventWithEventId:eventId];
    EditHistoryCoordinatorBridgePresenter *presenter = [[EditHistoryCoordinatorBridgePresenter alloc] initWithSession:self.roomDataSource.mxSession event:event];
    
    presenter.delegate = self;
    [presenter presentFrom:self animated:animated];
    
    self.editHistoryPresenter = presenter;
}

#pragma mark - EditHistoryCoordinatorBridgePresenterDelegate

- (void)editHistoryCoordinatorBridgePresenterDelegateDidComplete:(EditHistoryCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    self.editHistoryPresenter = nil;
}

#pragma mark - DocumentPickerPresenterDelegate

- (void)documentPickerPresenterWasCancelled:(MXKDocumentPickerPresenter *)presenter
{
    self.documentPickerPresenter = nil;
}

- (void)documentPickerPresenter:(MXKDocumentPickerPresenter *)presenter didPickDocumentsAt:(NSURL *)url
{
    self.documentPickerPresenter = nil;
    
    MXKUTI *fileUTI = [[MXKUTI alloc] initWithLocalFileURL:url];
    NSString *mimeType = fileUTI.mimeType;
    
    if (fileUTI.isImage)
    {
        NSData *imageData = [[NSData alloc] initWithContentsOfURL:url];
        
        [self sendImage:imageData mimeType:mimeType];
    }
    else if (fileUTI.isVideo)
    {
        [self sendVideo:url];
    }
    else if (fileUTI.isFile)
    {
        [self sendFile:url mimeType:mimeType];
    }
    else
    {
        MXLogDebug(@"[MXKRoomViewController] File upload using MIME type %@ is not supported.", mimeType);
        
        [self showAlertWithTitle:[VectorL10n fileUploadErrorTitle]
                         message:[VectorL10n fileUploadErrorUnsupportedFileTypeMessage]];
    }
}

- (void)sendImage:(NSData *)imageData mimeType:(NSString *)mimeType {
    // Create before sending the message in case of a discussion (direct chat)
    MXWeakify(self);
    [self createDiscussionIfNeeded:^(BOOL readyToSend) {
        MXStrongifyAndReturnIfNil(self);
        if (readyToSend)
        {
            // Let the datasource send it and manage the local echo
            [self.roomDataSource sendImage:imageData mimeType:mimeType success:nil failure:^(NSError *error) {
                // Nothing to do. The image is marked as unsent in the room history by the datasource
                MXLogDebug(@"[MXKRoomViewController] sendImage failed.");
            }];
        }
        // Errors are handled at the request level. This should be improved in case of code rewriting.
    }];
}

- (void)sendVideo:(NSURL * _Nonnull)url {
    // Create before sending the message in case of a discussion (direct chat)
    MXWeakify(self);
    [self createDiscussionIfNeeded:^(BOOL readyToSend) {
        MXStrongifyAndReturnIfNil(self);
        if (readyToSend)
        {
            // Let the datasource send it and manage the local echo
            [(RoomDataSource*)self.roomDataSource sendVideo:url success:nil failure:^(NSError *error) {
                // Nothing to do. The video is marked as unsent in the room history by the datasource
                MXLogDebug(@"[MXKRoomViewController] sendVideo failed.");
            }];
        }
        // Errors are handled at the request level. This should be improved in case of code rewriting.
    }];
}

- (void)sendFile:(NSURL * _Nonnull)url mimeType:(NSString *)mimeType {
    // Create before sending the message in case of a discussion (direct chat)
    MXWeakify(self);
    [self createDiscussionIfNeeded:^(BOOL readyToSend) {
        MXStrongifyAndReturnIfNil(self);
        if (readyToSend)
        {
            // Let the datasource send it and manage the local echo
            [self.roomDataSource sendFile:url mimeType:mimeType success:nil failure:^(NSError *error) {
                // Nothing to do. The file is marked as unsent in the room history by the datasource
                MXLogDebug(@"[MXKRoomViewController] sendFile failed.");
            }];
        }
        // Errors are handled at the request level. This should be improved in case of code rewriting.
    }];
}

#pragma mark - EmojiPickerCoordinatorBridgePresenterDelegate

- (void)emojiPickerCoordinatorBridgePresenter:(EmojiPickerCoordinatorBridgePresenter *)coordinatorBridgePresenter didAddEmoji:(NSString *)emoji forEventId:(NSString *)eventId
{
    MXWeakify(self);
    
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:^{
        [self.roomDataSource addReaction:emoji forEventId:eventId success:^{
            
        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);
            
            [self.errorPresenter presentErrorFromViewController:self forError:error animated:YES handler:nil];
        }];
    }];
    self.emojiPickerCoordinatorBridgePresenter = nil;
}

- (void)emojiPickerCoordinatorBridgePresenter:(EmojiPickerCoordinatorBridgePresenter *)coordinatorBridgePresenter didRemoveEmoji:(NSString *)emoji forEventId:(NSString *)eventId
{
    MXWeakify(self);
    
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:^{
        
        [self.roomDataSource removeReaction:emoji forEventId:eventId success:^{
            
        } failure:^(NSError *error) {
            MXStrongifyAndReturnIfNil(self);
            
            [self.errorPresenter presentErrorFromViewController:self forError:error animated:YES handler:nil];
        }];
    }];
    self.emojiPickerCoordinatorBridgePresenter = nil;
}

- (void)emojiPickerCoordinatorBridgePresenterDidCancel:(EmojiPickerCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    self.emojiPickerCoordinatorBridgePresenter = nil;
}

#pragma mark - ReactionHistoryCoordinatorBridgePresenterDelegate

- (void)reactionHistoryCoordinatorBridgePresenterDelegateDidClose:(ReactionHistoryCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:^{
        self.reactionHistoryCoordinatorBridgePresenter = nil;
    }];
}

#pragma mark - CameraPresenterDelegate

- (void)cameraPresenterDidCancel:(CameraPresenter *)cameraPresenter
{
    [cameraPresenter dismissWithAnimated:YES completion:nil];
    self.cameraPresenter = nil;
}

- (void)cameraPresenter:(CameraPresenter *)cameraPresenter didSelectImage:(UIImage *)image
{
    [cameraPresenter dismissWithAnimated:YES completion:nil];
    self.cameraPresenter = nil;
    
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
    
    // Create before sending the message in case of a discussion (direct chat)
    [self createDiscussionIfNeeded:^(BOOL readyToSend) {
        if (readyToSend && [self inputToolbarConformsToToolbarViewProtocol])
        {
            [self.inputToolbarView sendSelectedImage:imageData
                                       withMimeType:MXKUTI.jpeg.mimeType
                                 andCompressionMode:MediaCompressionHelper.defaultCompressionMode
                                isPhotoLibraryAsset:NO];
        }
        // Errors are handled at the request level. This should be improved in case of code rewriting.
    }];
}

- (void)cameraPresenter:(CameraPresenter *)cameraPresenter didSelectVideoAt:(NSURL *)url
{
    [cameraPresenter dismissWithAnimated:YES completion:nil];
    self.cameraPresenter = nil;
    
    AVURLAsset *selectedVideo = [AVURLAsset assetWithURL:url];
    [self sendVideoAsset:selectedVideo isPhotoLibraryAsset:NO];
}

#pragma mark - MediaPickerCoordinatorBridgePresenterDelegate

- (void)mediaPickerCoordinatorBridgePresenterDidCancel:(MediaPickerCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    self.mediaPickerPresenter = nil;
}

- (void)mediaPickerCoordinatorBridgePresenter:(MediaPickerCoordinatorBridgePresenter *)coordinatorBridgePresenter didSelectImageData:(NSData *)imageData withUTI:(MXKUTI *)uti
{
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    self.mediaPickerPresenter = nil;
    
    // Create before sending the message in case of a discussion (direct chat)
    [self createDiscussionIfNeeded:^(BOOL readyToSend) {
        if (readyToSend && [self inputToolbarConformsToToolbarViewProtocol])
        {
            [self.inputToolbarView sendSelectedImage:imageData
                                       withMimeType:uti.mimeType
                                 andCompressionMode:MediaCompressionHelper.defaultCompressionMode
                                isPhotoLibraryAsset:YES];
        }
        // Errors are handled at the request level. This should be improved in case of code rewriting.
    }];
}

- (void)mediaPickerCoordinatorBridgePresenter:(MediaPickerCoordinatorBridgePresenter *)coordinatorBridgePresenter didSelectVideo:(AVAsset *)videoAsset
{
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    self.mediaPickerPresenter = nil;
    
    [self sendVideoAsset:videoAsset isPhotoLibraryAsset:YES];
}

- (void)mediaPickerCoordinatorBridgePresenter:(MediaPickerCoordinatorBridgePresenter *)coordinatorBridgePresenter didSelectAssets:(NSArray<PHAsset *> *)assets
{
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    self.mediaPickerPresenter = nil;
    
    // Set a 1080p video conversion preset as compression mode only has an effect on the images.
    [MXSDKOptions sharedInstance].videoConversionPresetName = AVAssetExportPreset1920x1080;
    
    // Create before sending the message in case of a discussion (direct chat)
    [self createDiscussionIfNeeded:^(BOOL readyToSend) {
        if (readyToSend && [self inputToolbarConformsToToolbarViewProtocol])
        {
            [self.inputToolbarView sendSelectedAssets:assets withCompressionMode:MediaCompressionHelper.defaultCompressionMode];
        }
        // Errors are handled at the request level. This should be improved in case of code rewriting.
    }];
}

#pragma mark - RoomCreationModalCoordinatorBridgePresenter

- (void)roomCreationModalCoordinatorBridgePresenterDelegateDidComplete:(RoomCreationModalCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    self.roomCreationModalCoordinatorBridgePresenter = nil;
}

#pragma mark - RoomInfoCoordinatorBridgePresenterDelegate

- (void)roomInfoCoordinatorBridgePresenterDelegateDidComplete:(RoomInfoCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [coordinatorBridgePresenter dismissWithAnimated:YES completion:nil];
    self.roomInfoCoordinatorBridgePresenter = nil;
}

- (void)roomInfoCoordinatorBridgePresenter:(RoomInfoCoordinatorBridgePresenter *)coordinatorBridgePresenter didRequestMentionForMember:(MXRoomMember *)member
{
    [self mention:member];
}

- (void)roomInfoCoordinatorBridgePresenterDelegateDidLeaveRoom:(RoomInfoCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [self notifyDelegateOnLeaveRoomIfNecessary];
}

- (void)roomInfoCoordinatorBridgePresenter:(RoomInfoCoordinatorBridgePresenter *)coordinatorBridgePresenter didReplaceRoomWithReplacementId:(NSString *)roomId
{
    if (self.delegate)
    {
        [self.delegate roomViewController:self didReplaceRoomWithReplacementId:roomId];
    }
    else
    {
        ScreenPresentationParameters *presentationParameters = [[ScreenPresentationParameters alloc] initWithRestoreInitialDisplay:YES stackAboveVisibleViews:NO];
        RoomNavigationParameters *parameters = [[RoomNavigationParameters alloc] initWithRoomId:roomId eventId:nil mxSession:self.mainSession presentationParameters:presentationParameters showSettingsInitially:YES];
        [[AppDelegate theDelegate] showRoomWithParameters:parameters];
    }
}

- (void)roomInfoCoordinatorBridgePresenter:(RoomInfoCoordinatorBridgePresenter *)coordinator
                       viewEventInTimeline:(MXEvent *)event
{
    [self.navigationController popToViewController:self animated:true];
    [self reloadRoomWihtEventId:event.eventId threadId:event.threadId forceUpdateRoomMarker:NO];
}

- (void)roomInfoCoordinatorBridgePresenterDidRequestReportRoom:(RoomInfoCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [self handleReportRoom];
}

-(void)reloadRoomWihtEventId:(NSString *)eventId
                    threadId:(NSString *)threadId
       forceUpdateRoomMarker:(BOOL)forceUpdateRoomMarker
{
    // Jump to the last unread event by using a temporary room data source initialized with the last unread event id.
    MXWeakify(self);
    [RoomDataSource loadRoomDataSourceWithRoomId:self.roomDataSource.roomId
                                  initialEventId:eventId
                                        threadId:threadId
                                andMatrixSession:self.mainSession
                                      onComplete:^(id roomDataSource) {
        MXStrongifyAndReturnIfNil(self);
        
        [roomDataSource finalizeInitialization];
        
        // Center the bubbles table content on the bottom of the read marker event in order to display correctly the read marker view.
        self.centerBubblesTableViewContentOnTheInitialEventBottom = YES;
        [self displayRoom:roomDataSource];
        
        // Give the data source ownership to the room view controller.
        self.hasRoomDataSourceOwnership = YES;
        
        // Force the read marker update if needed (e.g if we jumped on the last unread message using the banner).
        self.updateRoomReadMarker |= forceUpdateRoomMarker;
    }];
}

#pragma mark - RemoveJitsiWidgetViewDelegate

- (void)removeJitsiWidgetViewDidCompleteSliding:(RemoveJitsiWidgetView *)view
{
    view.delegate = nil;
    Widget *jitsiWidget = [self.customizedRoomDataSource jitsiWidget];
    
    [self startActivityIndicator];
    
    //  close the widget
    MXWeakify(self);
    
    [[WidgetManager sharedManager] closeWidget:jitsiWidget.widgetId
                                        inRoom:self.roomDataSource.room
                                       success:^{
        MXStrongifyAndReturnIfNil(self);
        [self stopActivityIndicator];
        //  we can wait for kWidgetManagerDidUpdateWidgetNotification, but we want to be faster
        self.removeJitsiWidgetContainer.hidden = YES;
        self.removeJitsiWidgetView.delegate = nil;
        
        //  end active call if exists
        if ([self isRoomHavingAJitsiCall])
        {
            [self endActiveJitsiCall];
        }
    } failure:^(NSError *error) {
        MXStrongifyAndReturnIfNil(self);
        [self showJitsiErrorAsAlert:error];
        [self stopActivityIndicator];
    }];
}

#pragma mark - VoiceMessageControllerDelegate

- (void)voiceMessageControllerDidRequestMicrophonePermission:(VoiceMessageController *)voiceMessageController
{
    NSString *message = [VectorL10n microphoneAccessNotGrantedForVoiceMessage:AppInfo.current.displayName];
    
    [MXKTools checkAccessForMediaType:AVMediaTypeAudio
                  manualChangeMessage: message
            showPopUpInViewController:self completionHandler:^(BOOL granted) {
        
    }];
}

- (BOOL)voiceMessageControllerDidRequestRecording:(VoiceMessageController *)voiceMessageController
{
    MXSession* session = self.roomDataSource.mxSession;
    // Check whether the user is not already broadcasting here or in another room
    if (session.voiceBroadcastService)
    {
        [self showAlertWithTitle:[VectorL10n voiceMessageBroadcastInProgressTitle] message:[VectorL10n voiceMessageBroadcastInProgressMessage]];

        return NO;
    }

    return YES;
}

- (void)voiceMessageController:(VoiceMessageController *)voiceMessageController
    didRequestSendForFileAtURL:(NSURL *)url
                      duration:(NSUInteger)duration
                       samples:(NSArray<NSNumber *> *)samples
                    completion:(void (^)(BOOL))completion
{
    [self.roomDataSource sendVoiceMessage:url additionalContentParams:nil mimeType:nil duration:duration samples:samples success:^(NSString *eventId) {
        MXLogDebug(@"Success with event id %@", eventId);
        completion(YES);
    } failure:^(NSError *error) {
        MXLogError(@"Failed sending voice message");
        completion(NO);
    }];
}

#pragma mark - SpaceDetailPresenterDelegate

- (void)spaceDetailPresenterDidComplete:(SpaceDetailPresenter *)presenter
{
    self.spaceDetailPresenter = nil;
}

- (void)spaceDetailPresenter:(SpaceDetailPresenter *)presenter didOpenSpaceWithId:(NSString *)spaceId
{
    self.spaceDetailPresenter = nil;
    [[LegacyAppDelegate theDelegate] openSpaceWithId:spaceId];
}

- (void)spaceDetailPresenter:(SpaceDetailPresenter *)presenter didJoinSpaceWithId:(NSString *)spaceId
{
    self.spaceDetailPresenter = nil;
    [[LegacyAppDelegate theDelegate] openSpaceWithId:spaceId];
}

#pragma mark - CompletionSuggestionCoordinatorBridgeDelegate

- (void)completionSuggestionCoordinatorBridge:(CompletionSuggestionCoordinatorBridge *)coordinator
             didRequestMentionForMember:(MXRoomMember *)member
                            textTrigger:(NSString *)textTrigger
{
    [self removeTriggerTextFromComposer:textTrigger];
    [self mention:member];
}

- (void)completionSuggestionCoordinatorBridgeDidRequestMentionForRoom:(CompletionSuggestionCoordinatorBridge *)coordinator
                                                    textTrigger:(NSString *)textTrigger
{
    [self removeTriggerTextFromComposer:textTrigger];
    [self.inputToolbarView pasteText:[CompletionSuggestionUserID.room stringByAppendingString:@" "]];
}

- (void)completionSuggestionCoordinatorBridge:(CompletionSuggestionCoordinatorBridge *)coordinator
                           didRequestCommand:(NSString *)command
                                 textTrigger:(NSString *)textTrigger
{
    [self removeTriggerTextFromComposer:textTrigger];
    [self setCommand:command];
}

- (void)removeTriggerTextFromComposer:(NSString *)textTrigger
{
    RoomInputToolbarView *toolbar = (RoomInputToolbarView *)self.inputToolbarView;
    Class roomInputToolbarViewClass = [RoomViewController mainToolbarClass];

    // RTE handles removing the text trigger by itself.
    if (roomInputToolbarViewClass == WysiwygInputToolbarView.class && RiotSettings.shared.enableWysiwygTextFormatting)
    {
        return;
    }

    if (toolbar && textTrigger.length) {
        NSMutableAttributedString *attributedTextMessage = [[NSMutableAttributedString alloc] initWithAttributedString:toolbar.attributedTextMessage];
        [[attributedTextMessage mutableString] replaceOccurrencesOfString:textTrigger
                                                               withString:@""
                                                                  options:NSBackwardsSearch | NSAnchoredSearch
                                                                    range:NSMakeRange(0, attributedTextMessage.length)];
        [toolbar setAttributedTextMessage:attributedTextMessage];
    }
}

- (void)completionSuggestionCoordinatorBridge:(CompletionSuggestionCoordinatorBridge *)coordinator didUpdateViewHeight:(CGFloat)height
{
    if (self.completionSuggestionContainerHeightConstraint.constant != height)
    {
        self.completionSuggestionContainerHeightConstraint.constant = height;

        [self.view layoutIfNeeded];
    }
}

#pragma mark - ThreadsCoordinatorBridgePresenterDelegate

- (void)threadsCoordinatorBridgePresenterDelegateDidComplete:(ThreadsCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    self.threadsBridgePresenter = nil;
}

- (void)threadsCoordinatorBridgePresenterDelegateDidSelect:(ThreadsCoordinatorBridgePresenter *)coordinatorBridgePresenter roomId:(NSString *)roomId eventId:(NSString *)eventId
{
    MXWeakify(self);
    [self.threadsBridgePresenter dismissWithAnimated:YES completion:^{
        MXStrongifyAndReturnIfNil(self);
        
        if (eventId)
        {
            [self highlightAndDisplayEvent:eventId completion:nil];
        }
    }];
}

- (void)threadsCoordinatorBridgePresenterDidDismissInteractively:(ThreadsCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    self.threadsBridgePresenter = nil;
}

#pragma mark - ThreadsBetaCoordinatorBridgePresenterDelegate

- (void)threadsBetaCoordinatorBridgePresenterDelegateDidTapEnable:(ThreadsBetaCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    MXWeakify(self);
    [self.threadsBetaBridgePresenter dismissWithAnimated:YES completion:^{
        MXStrongifyAndReturnIfNil(self);
        [self cancelEventSelection];
        [self.roomDataSource reload];
        [self openThreadWithId:coordinatorBridgePresenter.threadId];
    }];
}

- (void)threadsBetaCoordinatorBridgePresenterDelegateDidTapCancel:(ThreadsBetaCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    MXWeakify(self);
    [self.threadsBetaBridgePresenter dismissWithAnimated:YES completion:^{
        MXStrongifyAndReturnIfNil(self);
        [self cancelEventSelection];
    }];
}

#pragma mark - MXThreadingServiceDelegate

- (void)threadingServiceDidUpdateThreads:(MXThreadingService *)service
{
    [self updateThreadListBarButtonBadgeWith:service];
}

#pragma mark - RoomParticipantsInviteCoordinatorBridgePresenterDelegate

- (void)roomParticipantsInviteCoordinatorBridgePresenterDidComplete:(RoomParticipantsInviteCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    self.participantsInvitePresenter = nil;
}

- (void)roomParticipantsInviteCoordinatorBridgePresenterDidStartLoading:(RoomParticipantsInviteCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [self startActivityIndicator];
}

- (void)roomParticipantsInviteCoordinatorBridgePresenterDidEndLoading:(RoomParticipantsInviteCoordinatorBridgePresenter *)coordinatorBridgePresenter
{
    [self stopActivityIndicator];
}

#pragma mark - Pills
/// Register provider for Pills.
- (void)registerPillAttachmentViewProviderIfNeeded
{
    if (@available(iOS 15.0, *))
    {
        if (![NSTextAttachment textAttachmentViewProviderClassForFileType:PillsFormatter.pillUTType])
        {
            [NSTextAttachment registerTextAttachmentViewProviderClass:PillAttachmentViewProvider.class forFileType:PillsFormatter.pillUTType];
        }
    }
}

#pragma mark - ComposerCreateActionListBridgePresenter

- (void)composerCreateActionListBridgePresenterDelegateDidComplete:(ComposerCreateActionListBridgePresenter *)coordinatorBridgePresenter action:(enum ComposerCreateAction)action
{
    
    [coordinatorBridgePresenter dismissWithAnimated:true completion:^{
        switch (action) {
            case ComposerCreateActionPhotoLibrary:
                [self showMediaPickerAnimated:YES];
                break;
            case ComposerCreateActionStickers:
                [self roomInputToolbarViewPresentStickerPicker];
                break;
            case ComposerCreateActionAttachments:
                [self roomInputToolbarViewDidTapFileUpload];
                break;
            case ComposerCreateActionVoiceBroadcast:
                [self roomInputToolbarViewDidTapVoiceBroadcast];
                break;
            case ComposerCreateActionPolls:
                [self.delegate roomViewControllerDidRequestPollCreationFormPresentation:self];
                break;
            case ComposerCreateActionLocation:
                [self.delegate roomViewControllerDidRequestLocationSharingFormPresentation:self];
                break;
            case ComposerCreateActionCamera:
                [self showCameraControllerAnimated:YES];
                break;
        }
        self.composerCreateActionListBridgePresenter = nil;
    }];
}

- (void)composerCreateActionListBridgePresenterDelegateDidToggleTextFormatting:(ComposerCreateActionListBridgePresenter *)coordinatorBridgePresenter enabled:(BOOL)enabled
{
    [self togglePlainTextMode];
}

- (void)composerCreateActionListBridgePresenterDidDismissInteractively:(ComposerCreateActionListBridgePresenter *)coordinatorBridgePresenter
{
    self.composerCreateActionListBridgePresenter = nil;
}

@end
/*
Copyright 2024 New Vector Ltd.
Copyright 2015 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

#import "MXKRoomSettingsViewController.h"

#import "NSBundle+MatrixKit.h"

#import "MXKSwiftHeader.h"

@interface MXKRoomSettingsViewController()
{    
    // the room events listener
    id roomListener;
    
    // Observe kMXSessionWillLeaveRoomNotification to be notified if the user leaves the current room.
    id leaveRoomNotificationObserver;
    
    // Observe kMXRoomDidFlushDataNotification to take into account the updated room state when the room history is flushed.
    id roomDidFlushDataNotificationObserver;
}
@end

@implementation MXKRoomSettingsViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRoomSettingsViewController class])
                          bundle:[NSBundle bundleForClass:[MXKRoomSettingsViewController class]]];
}

+ (instancetype)roomSettingsViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKRoomSettingsViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKRoomSettingsViewController class]]];
}

#pragma mark -

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self refreshRoomSettings];
}

#pragma mark - Override MXKTableViewController

- (void)finalizeInit
{
    [super finalizeInit];
}

- (void)destroy
{
    if (roomListener)
    {
        MXWeakify(self);
        [mxRoom liveTimeline:^(id<MXEventTimeline> liveTimeline) {
            MXStrongifyAndReturnIfNil(self);

            [liveTimeline removeListener:self->roomListener];
            self->roomListener = nil;
        }];
    }
    
    if (leaveRoomNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:leaveRoomNotificationObserver];
        leaveRoomNotificationObserver = nil;
    }
    
    if (roomDidFlushDataNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomDidFlushDataNotificationObserver];
        roomDidFlushDataNotificationObserver = nil;
    }
    
    mxRoom = nil;
    mxRoomState = nil;
    
    [super destroy];
}

- (void)onMatrixSessionStateDidChange:(NSNotification *)notif;
{
    // Check this is our Matrix session that has changed
    if (notif.object == self.mainSession)
    {
        [super onMatrixSessionStateDidChange:notif];
        
        // refresh when the session sync is done.
        if (MXSessionStateRunning == self.mainSession.state)
        {
            [self refreshRoomSettings];
        }
    }
}

#pragma mark - Public API

/**
 Set the dedicated session and the room Id
 */
- (void)initWithSession:(MXSession*)mxSession andRoomId:(NSString*)roomId
{
    // Update the matrix session
    if (self.mainSession)
    {
        [self removeMatrixSession:self.mainSession];
    }
    mxRoom = nil;
    
    // Sanity checks
    if (mxSession && roomId)
    {
        [self addMatrixSession:mxSession];
        
        // Report the room identifier
        _roomId = roomId;
        mxRoom = [mxSession roomWithRoomId:roomId];
    }
    
    if (mxRoom)
    {
        // Register a listener to handle messages related to room name, topic...
        MXWeakify(self);
        [mxRoom liveTimeline:^(id<MXEventTimeline> liveTimeline) {
            MXStrongifyAndReturnIfNil(self);

            self->roomListener = [liveTimeline listenToEventsOfTypes:@[kMXEventTypeStringRoomName, kMXEventTypeStringRoomTopic, kMXEventTypeStringRoomAliases, kMXEventTypeStringRoomAvatar, kMXEventTypeStringRoomPowerLevels, kMXEventTypeStringRoomCanonicalAlias, kMXEventTypeStringRoomJoinRules, kMXEventTypeStringRoomGuestAccess, kMXEventTypeStringRoomHistoryVisibility] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {

                // Consider only live events
                if (direction == MXTimelineDirectionForwards)
                {
                    [self updateRoomState:liveTimeline.state];
                }
            }];
        
            // Observe kMXSessionWillLeaveRoomNotification to be notified if the user leaves the current room.
            self->leaveRoomNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionWillLeaveRoomNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {

                // Check whether the user will leave the room related to the displayed participants
                if (notif.object == self.mainSession)
                {
                    NSString *roomId = notif.userInfo[kMXSessionNotificationRoomIdKey];
                    if (roomId && [roomId isEqualToString:self.roomId])
                    {
                        // We remove the current view controller.
                        [self withdrawViewControllerAnimated:YES completion:nil];
                    }
                }
            }];

            // Observe room history flush (sync with limited timeline, or state event redaction)
            self->roomDidFlushDataNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomDidFlushDataNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {

                MXRoom *room = notif.object;
                if (self.mainSession == room.mxSession && [self.roomId isEqualToString:room.roomId])
                {
                    // The existing room history has been flushed during server sync. Take into account the updated room state.
                    [self updateRoomState:liveTimeline.state];
                }

            }];

            [self updateRoomState:liveTimeline.state];
        }];
    }
    
    self.title = [VectorL10n roomDetailsTitle];
}

- (void)refreshRoomSettings
{
    [self.tableView reloadData];
}

- (void)updateRoomState:(MXRoomState*)newRoomState
{
    mxRoomState = newRoomState.copy;
    
    [self refreshRoomSettings];
}

#pragma mark - UITableViewDataSource

// empty by default

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return a fake cell to prevent app from crashing.
    return [[UITableViewCell alloc] init];
}

@end
/*
Copyright 2024 New Vector Ltd.
Copyright 2017 Vector Creations Ltd
Copyright 2015 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

#import "MXKRecentListViewController.h"

#import "MXKRoomDataSourceManager.h"

#import "MXKInterleavedRecentsDataSource.h"
#import "MXKInterleavedRecentTableViewCell.h"

#import "MXKSwiftHeader.h"

@interface MXKRecentListViewController ()
{
    /**
     The data source providing UITableViewCells
     */
    MXKRecentsDataSource *dataSource;
    
    /**
     Search handling
     */
    UIBarButtonItem *searchButton;
    BOOL ignoreSearchRequest;
    
    /**
     The reconnection animated view.
     */
    __weak UIView* reconnectingView;
    
    /**
     The current table view header if any.
     */
    UIView* tableViewHeaderView;
    
    /**
     The latest server sync date
     */
    NSDate* latestServerSync;
    
    /**
     The restart the event connnection
     */
    BOOL restartConnection;
}

@end

@implementation MXKRecentListViewController
@synthesize dataSource;

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRecentListViewController class])
                          bundle:[NSBundle bundleForClass:[MXKRecentListViewController class]]];
}

+ (instancetype)recentListViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKRecentListViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKRecentListViewController class]]];
}

#pragma mark -

- (void)finalizeInit
{
    [super finalizeInit];
    
    _recentsUpdateEnabled = YES;
    _enableBarButtonSearch = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Check whether the view controller has been pushed via storyboard
    if (!_recentsTableView)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated"
    // Adjust search bar Top constraint to take into account potential navBar.
    if (_recentsSearchBarTopConstraint)
    {
        _recentsSearchBarTopConstraint.active = NO;
        _recentsSearchBarTopConstraint = [NSLayoutConstraint constraintWithItem:self.topLayoutGuide
                                                                      attribute:NSLayoutAttributeBottom
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.recentsSearchBar
                                                                      attribute:NSLayoutAttributeTop
                                                                     multiplier:1.0f
                                                                       constant:0.0f];

        _recentsSearchBarTopConstraint.active = YES;
    }
    
    // Adjust table view Bottom constraint to take into account tabBar.
    if (_recentsTableViewBottomConstraint)
    {
        _recentsTableViewBottomConstraint.active = NO;
        _recentsTableViewBottomConstraint = [NSLayoutConstraint constraintWithItem:self.bottomLayoutGuide
                                                                         attribute:NSLayoutAttributeTop
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.recentsTableView
                                                                         attribute:NSLayoutAttributeBottom
                                                                        multiplier:1.0f
                                                                          constant:0.0f];

        _recentsTableViewBottomConstraint.active = YES;
    }
    #pragma clang diagnostic pop
    
    // Hide search bar by default
    [self hideSearchBar:YES];
    
    // Apply search option in navigation bar
    self.enableBarButtonSearch = _enableBarButtonSearch;
    
    // Add an accessory view to the search bar in order to retrieve keyboard view.
    self.recentsSearchBar.inputAccessoryView = [[UIView alloc] initWithFrame:CGRectZero];
    
    // Finalize table view configuration
    self.recentsTableView.delegate = self;
    self.recentsTableView.dataSource = dataSource; // Note: dataSource may be nil here
    
    // Set up classes to use for cells
    [self.recentsTableView registerNib:MXKRecentTableViewCell.nib forCellReuseIdentifier:MXKRecentTableViewCell.defaultReuseIdentifier];
    // Consider here the specific case where interleaved recents are supported
    [self.recentsTableView registerNib:MXKInterleavedRecentTableViewCell.nib forCellReuseIdentifier:MXKInterleavedRecentTableViewCell.defaultReuseIdentifier];
    
    // Add a top view which will be displayed in case of vertical bounce.
    CGFloat height = self.recentsTableView.frame.size.height;
    UIView *topview = [[UIView alloc] initWithFrame:CGRectMake(0,-height,self.recentsTableView.frame.size.width,height)];
    topview.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topview.backgroundColor = [UIColor groupTableViewBackgroundColor];
    [self.recentsTableView addSubview:topview];
    self->topview = topview;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // Restore search mechanism (if enabled)
    ignoreSearchRequest = NO;

    // Observe server sync at room data source level too
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onMatrixSessionChange) name:kMXKRoomDataSourceSyncStatusChanged object:nil];
    
    // Observe the server sync
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSyncNotification) name:kMXSessionDidSyncNotification object:nil];
    
    self.recentsUpdateEnabled = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    // The user may still press search button whereas the view disappears
    ignoreSearchRequest = YES;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXKRoomDataSourceSyncStatusChanged object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionDidSyncNotification object:nil];
    
    [self removeReconnectingView];
}

- (void)dealloc
{
    self.recentsSearchBar.inputAccessoryView = nil;
    
    searchButton = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // Dispose of any resources that can be recreated.
}

#pragma mark - Override MXKViewController

- (void)onMatrixSessionChange
{
    [super onMatrixSessionChange];
    
    // Check whether no server sync is in progress in room data sources
    NSArray *mxSessions = self.mxSessions;
    for (MXSession *mxSession in mxSessions)
    {
        if ([MXKRoomDataSourceManager sharedManagerForMatrixSession:mxSession].isServerSyncInProgress)
        {
            // sync is in progress for at least one data source, keep running the loading wheel
            [self startActivityIndicator];
            break;
        }
    }
}

- (void)onKeyboardShowAnimationComplete
{
    // Report the keyboard view in order to track keyboard frame changes
    self.keyboardView = _recentsSearchBar.inputAccessoryView.superview;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
- (void)setKeyboardHeight:(CGFloat)keyboardHeight
{
    // Deduce the bottom constraint for the table view (Don't forget the potential tabBar)
    CGFloat tableViewBottomConst = keyboardHeight - self.bottomLayoutGuide.length;
    // Check whether the keyboard is over the tabBar
    if (tableViewBottomConst < 0)
    {
        tableViewBottomConst = 0;
    }
    
    // Update constraints
    _recentsTableViewBottomConstraint.constant = tableViewBottomConst;
    
    // Force layout immediately to take into account new constraint
    [self.view layoutIfNeeded];
}
#pragma clang diagnostic pop

- (void)destroy
{
    self.recentsTableView.dataSource = nil;
    self.recentsTableView.delegate = nil;
    self.recentsTableView = nil;
    
    dataSource.delegate = nil;
    dataSource = nil;
    
    _delegate = nil;
    
    [topview removeFromSuperview];
    topview = nil;
    
    [super destroy];
}

#pragma mark -

- (void)setEnableBarButtonSearch:(BOOL)enableBarButtonSearch
{
    _enableBarButtonSearch = enableBarButtonSearch;
    
    if (enableBarButtonSearch)
    {
        if (!searchButton)
        {
            searchButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(search:)];
        }
        
        // Add it in right bar items
        NSArray *rightBarButtonItems = self.navigationItem.rightBarButtonItems;
        self.navigationItem.rightBarButtonItems = rightBarButtonItems ? [rightBarButtonItems arrayByAddingObject:searchButton] : @[searchButton];
    }
    else
    {
        NSMutableArray *rightBarButtonItems = [NSMutableArray arrayWithArray: self.navigationItem.rightBarButtonItems];
        [rightBarButtonItems removeObject:searchButton];
        self.navigationItem.rightBarButtonItems = rightBarButtonItems;
    }
}

- (void)displayList:(MXKRecentsDataSource *)listDataSource
{
    // Cancel registration on existing dataSource if any
    if (dataSource)
    {
        dataSource.delegate = nil;
        
        // Remove associated matrix sessions
        NSArray *mxSessions = self.mxSessions;
        for (MXSession *mxSession in mxSessions)
        {
            [self removeMatrixSession:mxSession];
        }
    }
    
    dataSource = listDataSource;
    dataSource.delegate = self;
    
    // Report all matrix sessions at view controller level to update UI according to sessions state
    NSArray *mxSessions = listDataSource.mxSessions;
    for (MXSession *mxSession in mxSessions)
    {
        [self addMatrixSession:mxSession];
    }
    
    if (self.recentsTableView)
    {
        // Set up table data source
        self.recentsTableView.dataSource = dataSource;
    }
}

- (void)refreshRecentsTable
{
    if (!self.recentsUpdateEnabled) return;
    
    isRefreshNeeded = NO;
    
    // For now, do a simple full reload
    [self.recentsTableView reloadData];
}

- (void)hideSearchBar:(BOOL)hidden
{
    self.recentsSearchBar.hidden = hidden;
    self.recentsSearchBarHeightConstraint.constant = hidden ? 0 : 44;
    [self.view setNeedsUpdateConstraints];
}

- (void)setRecentsUpdateEnabled:(BOOL)activeUpdate
{
    _recentsUpdateEnabled = activeUpdate;
    
    if (_recentsUpdateEnabled && isRefreshNeeded)
    {
        [self refreshRecentsTable];
    }
}

#pragma mark - Action

- (IBAction)search:(id)sender
{
    // The user may have pressed search button whereas the view controller was disappearing
    if (ignoreSearchRequest)
    {
        return;
    }
    
    if (self.recentsSearchBar.isHidden)
    {
        // Check whether there are data in which search
        if ([self.dataSource numberOfSectionsInTableView:self.recentsTableView])
        {
            [self hideSearchBar:NO];
            
            // Create search bar
            [self.recentsSearchBar becomeFirstResponder];
        }
    }
    else
    {
        [self searchBarCancelButtonClicked: self.recentsSearchBar];
    }
}

#pragma mark - MXKDataSourceDelegate

- (Class<MXKCellRendering>)cellViewClassForCellData:(MXKCellData*)cellData
{
    // Consider here the specific case where interleaved recents are supported
    if ([dataSource isKindOfClass:MXKInterleavedRecentsDataSource.class])
    {
        return MXKInterleavedRecentTableViewCell.class;
    }
    
    // Return the default recent table view cell
    return MXKRecentTableViewCell.class;
}

- (NSString *)cellReuseIdentifierForCellData:(MXKCellData*)cellData
{
    // Consider here the specific case where interleaved recents are supported
    if ([dataSource isKindOfClass:MXKInterleavedRecentsDataSource.class])
    {
        return MXKInterleavedRecentTableViewCell.defaultReuseIdentifier;
    }
    
    // Return the default recent table view cell
    return MXKRecentTableViewCell.defaultReuseIdentifier;
}

- (void)dataSource:(MXKDataSource *)dataSource didCellChange:(id)changes
{
    if (!_recentsUpdateEnabled)
    {
        isRefreshNeeded = YES;
        return;
    }
    
    // For now, do a simple full reload
    [self refreshRecentsTable];
}

- (void)dataSource:(MXKDataSource *)dataSource didAddMatrixSession:(MXSession *)mxSession
{
    [self addMatrixSession:mxSession];
}

- (void)dataSource:(MXKDataSource *)dataSource didRemoveMatrixSession:(MXSession *)mxSession
{
    [self removeMatrixSession:mxSession];
}

#pragma mark - UITableView delegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [dataSource cellHeightAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // Section header is required only when several recent lists are displayed.
    if (self.dataSource.displayedRecentsDataSourcesCount > 1)
    {
        return 35;
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    // Let dataSource provide the section header.
    return [dataSource viewForHeaderInSection:section
                                    withFrame:[tableView rectForHeaderInSection:section]
                                  inTableView:tableView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_delegate)
    {
        UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath:indexPath];
        
        if ([selectedCell conformsToProtocol:@protocol(MXKCellRendering)])
        {
            id<MXKCellRendering> cell = (id<MXKCellRendering>)selectedCell;
            
            if ([cell respondsToSelector:@selector(renderedCellData)])
            {
                MXKCellData *cellData = cell.renderedCellData;
                if ([cellData conformsToProtocol:@protocol(MXKRecentCellDataStoring)])
                {
                    id<MXKRecentCellDataStoring> recentCellData = (id<MXKRecentCellDataStoring>)cellData;
                    if (recentCellData.isSuggestedRoom)
                    {
                        [_delegate recentListViewController:self
                                     didSelectSuggestedRoom:recentCellData.roomSummary.spaceChildInfo
                                                       from:selectedCell];
                    }
                    else
                    {
                        [_delegate recentListViewController:self
                                              didSelectRoom:recentCellData.roomIdentifier
                                            inMatrixSession:recentCellData.mxSession];
                    }
                }
            }
        }
    }
    
    // Hide the keyboard when user select a room
    // do not hide the searchBar until the view controller disappear
    // on tablets / iphone 6+, the user could expect to search again while looking at a room
    [self.recentsSearchBar resignFirstResponder];
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath*)indexPath
{
    // Release here resources, and restore reusable cells
    if ([cell respondsToSelector:@selector(didEndDisplay)])
    {
        [(id<MXKCellRendering>)cell didEndDisplay];
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    // Detect vertical bounce at the top of the tableview to trigger reconnection.
    if (scrollView == _recentsTableView)
    {
        [self detectPullToKick:scrollView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (scrollView == _recentsTableView)
    {
        [self managePullToKick:scrollView];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == _recentsTableView)
    {
        if (scrollView.contentOffset.y + scrollView.adjustedContentInset.top == 0)
        {
            [self managePullToKick:scrollView];
        }
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    // Apply filter
    if (searchText.length)
    {
        [self.dataSource searchWithPatterns:@[searchText]];
    }
    else
    {
        [self.dataSource searchWithPatterns:nil];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // "Done" key has been pressed
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    // Leave search
    [searchBar resignFirstResponder];
    
    [self hideSearchBar:YES];
    
    self.recentsSearchBar.text = nil;
    
    // Refresh display
    [self.dataSource searchWithPatterns:nil];
}

#pragma mark - resync management

- (void)onSyncNotification
{
    latestServerSync = [NSDate date];
    [self removeReconnectingView];
}

- (BOOL)canReconnect
{
    // avoid restarting connection if some data has been received within 1 second (1000 : latestServerSync is null)
    NSTimeInterval interval = latestServerSync ? [[NSDate date] timeIntervalSinceDate:latestServerSync] : 1000;
    return  (interval > 1) && [self.mainSession reconnect];
}

- (void)addReconnectingView
{
    if (!reconnectingView)
    {
        UIActivityIndicatorView* spinner  = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        spinner.transform = CGAffineTransformMakeScale(0.75f, 0.75f);
        CGRect frame = spinner.frame;
        frame.size.height = 80; // 80 * 0.75 = 60
        spinner.bounds = frame;
        spinner.color = [UIColor darkGrayColor];
        spinner.hidesWhenStopped = NO;
        spinner.backgroundColor = _recentsTableView.backgroundColor;
        [spinner startAnimating];
        
        // no need to manage constraints here, IOS defines them.
        tableViewHeaderView = _recentsTableView.tableHeaderView;
        _recentsTableView.tableHeaderView = reconnectingView = spinner;
    }
}

- (void)removeReconnectingView
{
    if (reconnectingView && !restartConnection)
    {
        _recentsTableView.tableHeaderView = tableViewHeaderView;
        reconnectingView = nil;
    }
}

/**
 Detect if the current connection must be restarted.
 The spinner is displayed until the overscroll ends (and scrollViewDidEndDecelerating is called).
 */
- (void)detectPullToKick:(UIScrollView *)scrollView
{
    if (!reconnectingView)
    {
        // detect if the user scrolls over the tableview top
        restartConnection = (scrollView.contentOffset.y + scrollView.adjustedContentInset.top < -128);
        
        if (restartConnection)
        {
            // wait that list decelerate to display / hide it
            [self addReconnectingView];
        }
    }
}

/**
 Restarts the current connection if it is required.
 The 0.3s delay is added to avoid flickering if the connection does not require to be restarted.
 */
- (void)managePullToKick:(UIScrollView *)scrollView
{
    // the current connection must be restarted
    if (restartConnection)
    {
        // display at least 0.3s the spinner to show to the user that something is pending
        // else the UI is flickering
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            self->restartConnection = NO;
            
            if (![self canReconnect])
            {
                // if the event stream has not been restarted
                // hide the spinner
                [self removeReconnectingView];
            }
            // else wait that onSyncNotification is called.
        });
    }
}

@end
/*
Copyright 2024 New Vector Ltd.
Copyright 2015 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

#import "MXKRoomDataSourceManager.h"

@interface MXKRoomDataSourceManager()
{
    MXSession *mxSession;
    
    /**
     The list of running roomDataSources.
     Each key is a room ID. Each value, the MXKRoomDataSource instance.
     */
    NSMutableDictionary *roomDataSources;
    
    /**
     The list of rooms with a "late decryption" event. Causing bubbles issues
     Each element is a room ID.
     */
    NSMutableSet *roomDataSourcesToDestroy;
    
    /**
     Observe UIApplicationDidReceiveMemoryWarningNotification to dispose of any resources that can be recreated.
     */
    id UIApplicationDidReceiveMemoryWarningNotificationObserver;
    
    /**
     Observe kMXEventDidDecryptNotification to get late decrypted events.
     */
    id mxEventDidDecryptNotificationObserver;
}

@end

static NSMutableDictionary *_roomDataSourceManagers = nil;
static Class _roomDataSourceClass;

@implementation MXKRoomDataSourceManager

+ (MXKRoomDataSourceManager *)sharedManagerForMatrixSession:(MXSession *)mxSession
{
    // Manage a pool of managers: one per Matrix session
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _roomDataSourceManagers = [NSMutableDictionary dictionary];
    });
    
    MXKRoomDataSourceManager *roomDataSourceManager;
    
    // Compute an id for this mxSession object: its pointer address as a string
    NSString *mxSessionId = [NSString stringWithFormat:@"%p", mxSession];
    
    @synchronized(_roomDataSourceManagers)
    {
        if (_roomDataSourceClass == nil)
        {
            // Set default class
            _roomDataSourceClass = MXKRoomDataSource.class;
        }
        // If not available yet, create the `MXKRoomDataSourceManager` for this Matrix session
        roomDataSourceManager = _roomDataSourceManagers[mxSessionId];
        if (!roomDataSourceManager)
        {
            roomDataSourceManager = [[MXKRoomDataSourceManager alloc]initWithMatrixSession:mxSession];
            _roomDataSourceManagers[mxSessionId] = roomDataSourceManager;
        }
    }
    
    return roomDataSourceManager;
}

+ (void)removeSharedManagerForMatrixSession:(MXSession*)mxSession
{
    // Compute the id for this mxSession object: its pointer address as a string
    NSString *mxSessionId = [NSString stringWithFormat:@"%p", mxSession];
    
    @synchronized(_roomDataSourceManagers)
    {
        MXKRoomDataSourceManager *roomDataSourceManager = [_roomDataSourceManagers objectForKey:mxSessionId];
        if (roomDataSourceManager)
        {
            [roomDataSourceManager destroy];
            [_roomDataSourceManagers removeObjectForKey:mxSessionId];
        }
    }
}

+ (void)registerRoomDataSourceClass:(Class)roomDataSourceClass
{
    // Sanity check: accept only MXKRoomDataSource classes or sub-classes
    NSParameterAssert([roomDataSourceClass isSubclassOfClass:MXKRoomDataSource.class]);
    
    @synchronized(_roomDataSourceManagers)
    {
        if (roomDataSourceClass !=_roomDataSourceClass)
        {
            _roomDataSourceClass = roomDataSourceClass;
            
            NSArray *mxSessionIds = _roomDataSourceManagers.allKeys;
            for (NSString *mxSessionId in mxSessionIds)
            {
                MXKRoomDataSourceManager *roomDataSourceManager = [_roomDataSourceManagers objectForKey:mxSessionId];
                if (roomDataSourceManager)
                {
                    [roomDataSourceManager destroy];
                    [_roomDataSourceManagers removeObjectForKey:mxSessionId];
                }
            }
        }
    }
}

- (instancetype)initWithMatrixSession:(MXSession *)matrixSession
{
    self = [super init];
    if (self)
    {
        mxSession = matrixSession;
        roomDataSources = [NSMutableDictionary dictionary];
        roomDataSourcesToDestroy = [NSMutableSet set];
        _releasePolicy = MXKRoomDataSourceManagerReleasePolicyNeverRelease;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didMXSessionDidLeaveRoom:) name:kMXSessionDidLeaveRoomNotification object:nil];
        
        // Observe UIApplicationDidReceiveMemoryWarningNotification
        UIApplicationDidReceiveMemoryWarningNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            MXLogDebug(@"[MXKRoomDataSourceManager] %@: Received memory warning.", self);
            
            // Reload all data sources (except the current used ones) to reduce memory usage.
            for (MXKRoomDataSource *roomDataSource in self->roomDataSources.allValues)
            {
                if (!roomDataSource.delegate)
                {
                    [roomDataSource reload];
                }
            }
            
        }];
        
        // Observe late decrypted events, and store rooms ids in memory
        mxEventDidDecryptNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXEventDidDecryptNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            MXEvent *decryptedEvent = notif.object;
            [self->roomDataSourcesToDestroy addObject:decryptedEvent.roomId];
        }];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionDidLeaveRoomNotification object:nil];
}

- (void)destroy
{
    [self reset];
    
    if (UIApplicationDidReceiveMemoryWarningNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:UIApplicationDidReceiveMemoryWarningNotificationObserver];
        UIApplicationDidReceiveMemoryWarningNotificationObserver = nil;
    }
    if (mxEventDidDecryptNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:mxEventDidDecryptNotificationObserver];
        mxEventDidDecryptNotificationObserver = nil;
    }
}

#pragma mark

- (BOOL)isServerSyncInProgress
{
    // Check first the matrix session state
    if (mxSession.state == MXSessionStateSyncInProgress)
    {
        return YES;
    }
    
    // Check all data sources (events process is asynchronous, server sync may not be complete in data source).
    for (MXKRoomDataSource *roomDataSource in roomDataSources.allValues)
    {
        if (roomDataSource.serverSyncEventCount)
        {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark

- (void)reset
{
    NSArray *roomIds =  roomDataSources.allKeys;
    for (NSString *roomId in roomIds)
    {
        [self closeRoomDataSourceWithRoomId:roomId forceClose:YES];
    }
}

- (BOOL)hasRoomDataSourceForRoom:(NSString *)roomId
{
    return roomDataSources[roomId] != nil;
}

- (void)roomDataSourceForRoom:(NSString *)roomId create:(BOOL)create onComplete:(void (^)(MXKRoomDataSource *roomDataSource))onComplete
{
    NSParameterAssert(roomId);

    // If not available yet, create the room data source
    MXKRoomDataSource *roomDataSource = roomDataSources[roomId];
    
    // check if the room's dataSource has events with late decryption issues and destroys it
    BOOL roomDataSourceToBeDestroyed = [roomDataSourcesToDestroy containsObject:roomId];
    
    if (roomDataSource && roomDataSourceToBeDestroyed && create) {
        [roomDataSource destroy];
        roomDataSources[roomId] = nil;
        roomDataSource = nil;
    }
    
    if (!roomDataSource && create && roomId)
    {
        [roomDataSourcesToDestroy removeObject:roomId];
        [_roomDataSourceClass loadRoomDataSourceWithRoomId:roomId threadId:nil andMatrixSession:mxSession onComplete:^(id roomDataSource) {
            [self addRoomDataSource:roomDataSource];
            onComplete(roomDataSource);
        }];
    }
    else
    {
        onComplete(roomDataSource);
    }
}

- (void)addRoomDataSource:(MXKRoomDataSource *)roomDataSource
{
    roomDataSources[roomDataSource.roomId] = roomDataSource;
}

- (void)closeRoomDataSourceWithRoomId:(NSString*)roomId forceClose:(BOOL)forceRelease;
{
    // Check first whether this roomDataSource is well handled by this manager
    if (!roomId || !roomDataSources[roomId])
    {
        MXLogDebug(@"[MXKRoomDataSourceManager] Failed to close an unknown room id: %@", roomId);
        return;
    }

    MXKRoomDataSource *roomDataSource = roomDataSources[roomId];

    // According to the policy, it is interesting to keep the room data source in life: it can keep managing echo messages
    // in background for instance
    MXKRoomDataSourceManagerReleasePolicy releasePolicy = _releasePolicy;
    if (forceRelease)
    {
        // Act as ReleaseOnClose policy
        releasePolicy = MXKRoomDataSourceManagerReleasePolicyReleaseOnClose;
    }
    
    switch (releasePolicy)
    {
        case MXKRoomDataSourceManagerReleasePolicyReleaseOnClose:
            
            // Destroy and forget the instance
            [roomDataSource destroy];
            [roomDataSources removeObjectForKey:roomDataSource.roomId];
            break;
            
        case MXKRoomDataSourceManagerReleasePolicyNeverRelease:
            
            // The close here consists in no more sending actions to the current view controller, the room data source delegate
            roomDataSource.delegate = nil;
            
            // Keep the instance for life (reduce memory usage by flushing room data if the number of bubbles is over 30).
            [roomDataSource limitMemoryUsage:roomDataSource.maxBackgroundCachedBubblesCount];
            break;
            
        default:
            break;
    }
}

- (void)didMXSessionDidLeaveRoom:(NSNotification *)notif
{
    if (mxSession == notif.object)
    {
        // The room is no more available, remove it from the manager
        [self closeRoomDataSourceWithRoomId:notif.userInfo[kMXSessionNotificationRoomIdKey] forceClose:YES];
    }
}

@end
/*
Copyright 2018-2024 New Vector Ltd.
Copyright 2015 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

#import "MXKCallViewController.h"

@import MatrixSDK;

#import "MXKAppSettings.h"
#import "MXKSoundPlayer.h"
#import "MXKTools.h"
#import "NSBundle+MatrixKit.h"

#import "MXKSwiftHeader.h"

NSString *const kMXKCallViewControllerWillAppearNotification = @"kMXKCallViewControllerWillAppearNotification";
NSString *const kMXKCallViewControllerAppearedNotification = @"kMXKCallViewControllerAppearedNotification";
NSString *const kMXKCallViewControllerWillDisappearNotification = @"kMXKCallViewControllerWillDisappearNotification";
NSString *const kMXKCallViewControllerDisappearedNotification = @"kMXKCallViewControllerDisappearedNotification";
NSString *const kMXKCallViewControllerBackToAppNotification = @"kMXKCallViewControllerBackToAppNotification";

static const CGFloat kLocalPreviewMargin = 20;

@interface MXKCallViewController ()
{
    NSTimer *hideOverlayTimer;
    NSTimer *updateStatusTimer;
    
    Boolean isMovingLocalPreview;
    Boolean isSelectingLocalPreview;
    
    CGPoint startNewLocalMove;

    /**
     The popup showed in case of call stack error.
     */
    UIAlertController *errorAlert;
    
    // the room events listener
    id roomListener;
    
    // Observe kMXRoomDidFlushDataNotification to take into account the updated room members when the room history is flushed.
    id roomDidFlushDataNotificationObserver;
    
    // Observe AVAudioSessionRouteChangeNotification
    id audioSessionRouteChangeNotificationObserver;
    
    // Current alert (if any).
    UIAlertController *currentAlert;
    
    //  Current peer display name
    NSString *peerDisplayName;
}

@property (nonatomic, assign) Boolean isRinging;

@property (nonatomic, nullable) UIView *incomingCallView;

@property (nonatomic, strong) UITapGestureRecognizer *onHoldCallContainerTapRecognizer;

@end

@implementation MXKCallViewController
@synthesize backgroundImageView;
@synthesize localPreviewContainerView, localPreviewVideoView, localPreviewActivityView, remotePreviewContainerView;
@synthesize overlayContainerView, callContainerView, callerImageView, callerNameLabel, callStatusLabel;
@synthesize callToolBar, rejectCallButton, answerCallButton, endCallButton;
@synthesize callControlContainerView, speakerButton, audioMuteButton, videoMuteButton;
@synthesize backToAppButton, cameraSwitchButton;
@synthesize backToAppStatusWindow;
@synthesize mxCall;
@synthesize mxCallOnHold;
@synthesize onHoldCallerImageView;
@synthesize onHoldCallContainerView;

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass(self.class)
                          bundle:[NSBundle bundleForClass:self.class]];
}

+ (instancetype)callViewController:(MXCall*)call
{
    MXKCallViewController *instance = [[[self class] alloc] initWithNibName:NSStringFromClass(self.class)
                                                                     bundle:[NSBundle bundleForClass:self.class]];
    
    // Load the view controller's view now (buttons and views will then be available).
    if ([instance respondsToSelector:@selector(loadViewIfNeeded)])
    {
        // iOS 9 and later
        [instance loadViewIfNeeded];
    }
    else if (instance.view)
    {
        // Patch: on iOS < 9.0, we load the view by calling its getter.
    }
    
    instance.mxCall = call;
    
    return instance;
}

#pragma mark -

- (void)finalizeInit
{
    [super finalizeInit];
    
    _playRingtone = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    updateStatusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimeStatusLabel) userInfo:nil repeats:YES];
    
    self.callerImageView.defaultBackgroundColor = [UIColor clearColor];
    self.backToAppButton.backgroundColor = [UIColor clearColor];
    self.audioMuteButton.backgroundColor = [UIColor clearColor];
    self.videoMuteButton.backgroundColor = [UIColor clearColor];
    self.resumeButton.backgroundColor = [UIColor clearColor];
    self.moreButton.backgroundColor = [UIColor clearColor];
    self.speakerButton.backgroundColor = [UIColor clearColor];
    self.transferButton.backgroundColor = [UIColor clearColor];
    
    [self.backToAppButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_backtoapp"] forState:UIControlStateNormal];
    [self.backToAppButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_backtoapp"] forState:UIControlStateHighlighted];
    [self.audioMuteButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_audio_unmute"] forState:UIControlStateNormal];
    [self.audioMuteButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_audio_mute"] forState:UIControlStateSelected];
    [self.videoMuteButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_video_unmute"] forState:UIControlStateNormal];
    [self.videoMuteButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_video_mute"] forState:UIControlStateSelected];
    [self.moreButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_call_more"] forState:UIControlStateNormal];
    [self.moreButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_call_more"] forState:UIControlStateSelected];
    [self.speakerButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_speaker_off"] forState:UIControlStateNormal];
    [self.speakerButton setImage:[NSBundle mxk_imageFromMXKAssetsBundleWithName:@"icon_speaker_on"] forState:UIControlStateSelected];
    
    // Localize string
    [answerCallButton setTitle:[VectorL10n answerCall] forState:UIControlStateNormal];
    [answerCallButton setTitle:[VectorL10n answerCall] forState:UIControlStateHighlighted];
    [rejectCallButton setTitle:[VectorL10n rejectCall] forState:UIControlStateNormal];
    [rejectCallButton setTitle:[VectorL10n rejectCall] forState:UIControlStateHighlighted];
    [endCallButton setTitle:[VectorL10n endCall] forState:UIControlStateNormal];
    [endCallButton setTitle:[VectorL10n endCall] forState:UIControlStateHighlighted];
    [_resumeButton setTitle:[VectorL10n resumeCall] forState:UIControlStateNormal];
    [_resumeButton setTitle:[VectorL10n resumeCall] forState:UIControlStateHighlighted];
    
    // Refresh call information
    self.mxCall = mxCall;
    
    // Listen to AVAudioSession activation notification if CallKit is available and enabled
    BOOL isCallKitAvailable = [MXCallKitAdapter callKitAvailable] && [MXKAppSettings standardAppSettings].isCallKitEnabled;
    if (isCallKitAvailable)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioSessionActivationNotification)
                                                     name:kMXCallKitAdapterAudioSessionDidActive
                                                   object:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXCallKitAdapterAudioSessionDidActive object:nil];

    [self removeObservers];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKCallViewControllerWillAppearNotification object:nil];
    
    [self updateLocalPreviewLayout];
    [self showOverlayContainer:YES];
    
    if (mxCall)
    {
        // Refresh call display according to the call room state.
        [self callRoomStateDidChange:^{
            // Refresh call status
            [self call:self->mxCall stateDidChange:self->mxCall.state reason:nil];
        }];

    }
    
    if (_delegate)
    {
        backToAppButton.hidden = NO;
    }
    else
    {
        backToAppButton.hidden = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKCallViewControllerAppearedNotification object:nil];
    
    // trick to hide the volume at launch
    // as the mininum volume is forced by the application
    // the volume popup can be displayed
    //    volumeView = [[MPVolumeView alloc] initWithFrame: CGRectMake(5000, 5000, 0, 0)];
    //    [self.view addSubview: volumeView];
    //
    //    dispatch_after(dispatch_walltime(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    //        [volumeView removeFromSuperview];
    //    });
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKCallViewControllerWillDisappearNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKCallViewControllerDisappearedNotification object:nil];
}

- (void)dismiss
{
    if (_delegate)
    {
        [_delegate dismissCallViewController:self completion:nil];
    }
    else
    {
        // Auto dismiss after few seconds
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
        });
    }
}

#pragma mark - override MXKViewController

- (void)destroy
{
    self.peer = nil;
    
    self.mxCall = nil;
    
    _delegate = nil;
    
    self.isRinging = NO;
    
    [hideOverlayTimer invalidate];
    [updateStatusTimer invalidate];
    
    _incomingCallView = nil;
    
    _onHoldCallContainerTapRecognizer = nil;
    
    [super destroy];
}

#pragma mark - Properties

- (UIImage *)picturePlaceholder
{
    return [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"default-profile"];
}

- (void)setMxCall:(MXCall *)call
{
    // Remove previous call (if any)
    if (mxCall)
    {
        mxCall.delegate = nil;
        mxCall.selfVideoView = nil;
        mxCall.remoteVideoView = nil;
        [self removeMatrixSession:self.mainSession];
        
        [self removeObservers];
        
        mxCall = nil;
    }
    
    if (call && call.room)
    {
        mxCall = call;
        
        [self addMatrixSession:mxCall.room.mxSession];

        MXWeakify(self);

        // Register a listener to handle messages related to room name, members...
        roomListener = [mxCall.room listenToEventsOfTypes:@[kMXEventTypeStringRoomName, kMXEventTypeStringRoomTopic, kMXEventTypeStringRoomAliases, kMXEventTypeStringRoomAvatar, kMXEventTypeStringRoomCanonicalAlias, kMXEventTypeStringRoomMember] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {
            MXStrongifyAndReturnIfNil(self);

            // Consider only live events
            if (self->mxCall && direction == MXTimelineDirectionForwards)
            {
                // The room state has been changed
                [self callRoomStateDidChange:nil];
            }
        }];
        
        // Observe room history flush (sync with limited timeline, or state event redaction)
        roomDidFlushDataNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomDidFlushDataNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            MXStrongifyAndReturnIfNil(self);
            
            MXRoom *room = notif.object;
            if (self->mxCall && self.mainSession == room.mxSession && [self->mxCall.room.roomId isEqualToString:room.roomId])
            {
                // The existing room history has been flushed during server sync.
                // Take into account the updated room state
                [self callRoomStateDidChange:nil];
            }
            
        }];
        
        audioSessionRouteChangeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            [self updateProximityAndSleep];
            
        }];
        
        // Hide video mute on voice call
        self.videoMuteButton.hidden = !call.isVideoCall;
        
        // Hide camera switch on voice call
        self.cameraSwitchButton.hidden = !call.isVideoCall;
        
        _moreButtonForVideo.hidden = !call.isVideoCall;
        _moreButtonForVoice.hidden = call.isVideoCall;
        
        // Observe call state change
        call.delegate = self;

        // Display room call information
        [self callRoomStateDidChange:^{
            [self call:call stateDidChange:call.state reason:nil];
        }];
        
        if (call.isVideoCall && localPreviewContainerView)
        {
            // Access to the camera is mandatory to display the self view
            // Check the permission right now
            NSString *appDisplayName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
            [MXKTools checkAccessForMediaType:AVMediaTypeVideo
                          manualChangeMessage:[VectorL10n cameraAccessNotGrantedForCall:appDisplayName]

                    showPopUpInViewController:self completionHandler:^(BOOL granted) {

                   if (granted)
                   {
                       self->localPreviewContainerView.hidden = NO;
                       self->remotePreviewContainerView.hidden = NO;

                       call.selfVideoView = self->localPreviewVideoView;
                       call.remoteVideoView = self->remotePreviewContainerView;
                       [self applyDeviceOrientation:YES];

                       [[NSNotificationCenter defaultCenter] addObserver:self
                                                                selector:@selector(deviceOrientationDidChange)
                                                                    name:UIDeviceOrientationDidChangeNotification
                                                                  object:nil];
                   }
               }];
        }
        else
        {
            localPreviewContainerView.hidden = YES;
            remotePreviewContainerView.hidden = YES;
        }
    }
}

- (void)setMxCallOnHold:(MXCall *)callOnHold
{
    if (mxCallOnHold == callOnHold)
    {
        //  setting same property, return
        return;
    }
    
    mxCallOnHold = callOnHold;
    
    if (mxCallOnHold)
    {
        self.onHoldCallContainerView.hidden = NO;
        [self.onHoldCallContainerView addGestureRecognizer:self.onHoldCallContainerTapRecognizer];
        [self.onHoldCallContainerView setUserInteractionEnabled:YES];
        
        // Handle peer here
        if (mxCallOnHold.isIncoming)
        {
            self.peerOnHold = [mxCallOnHold.room.mxSession getOrCreateUser:mxCallOnHold.callerId];
        }
        else
        {
            // For 1:1 call, find the other peer
            // Else, the room information will be used to display information about the call
            MXWeakify(self);
            [mxCallOnHold.room state:^(MXRoomState *roomState) {
                MXStrongifyAndReturnIfNil(self);
            
                MXUser *theMember = nil;
                NSArray *members = roomState.members.joinedMembers;
                for (MXUser *member in members)
                {
                    if (![member.userId isEqualToString:self->mxCallOnHold.callerId])
                    {
                        theMember = member;
                        break;
                    }
                }

                self.peerOnHold = theMember;
            }];
        }
    }
    else
    {
        [self.onHoldCallContainerView removeGestureRecognizer:self.onHoldCallContainerTapRecognizer];
        [self.onHoldCallContainerView setUserInteractionEnabled:NO];
        self.onHoldCallContainerView.hidden = YES;
        self.peerOnHold = nil;
    }
}

- (void)setPeer:(MXUser *)peer
{
    _peer = peer;
    
    [self updatePeerInfoDisplay];
}

- (void)setPeerOnHold:(MXUser *)peerOnHold
{
    _peerOnHold = peerOnHold;
    
    NSString *peerAvatarURL;
    
    if (_peerOnHold)
    {
        peerAvatarURL = _peerOnHold.avatarUrl;
    }
    else if (mxCall.isConferenceCall)
    {
        peerAvatarURL = mxCallOnHold.room.summary.avatar;
    }
    
    onHoldCallerImageView.imageView.contentMode = UIViewContentModeScaleAspectFill;
    
    if (peerAvatarURL)
    {
        // Suppose avatar url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
        onHoldCallerImageView.mediaFolder = kMXMediaManagerAvatarThumbnailFolder;
        onHoldCallerImageView.enableInMemoryCache = YES;
        [onHoldCallerImageView setImageURI:peerAvatarURL
                                  withType:nil
                       andImageOrientation:UIImageOrientationUp
                             toFitViewSize:onHoldCallerImageView.frame.size
                                withMethod:MXThumbnailingMethodCrop
                              previewImage:self.picturePlaceholder
                              mediaManager:self.mainSession.mediaManager];
    }
    else
    {
        onHoldCallerImageView.image = self.picturePlaceholder;
    }
}

- (void)updatePeerInfoDisplay
{
    NSString *peerAvatarURL;
    
    if (_peer)
    {
        peerDisplayName = [_peer displayname];
        if (!peerDisplayName.length)
        {
            peerDisplayName = _peer.userId;
        }
        peerAvatarURL = _peer.avatarUrl;
    }
    else if (mxCall.isConferenceCall)
    {
        peerDisplayName = mxCall.room.summary.displayName;
        peerAvatarURL = mxCall.room.summary.avatar;
    }
    
    if (mxCall.isConsulting)
    {
        callerNameLabel.text = [VectorL10n callConsultingWithUser:peerDisplayName];
    }
    else
    {
        if (mxCall.isVideoCall)
        {
            callerNameLabel.text = [VectorL10n callVideoWithUser:peerDisplayName];
        }
        else
        {
            callerNameLabel.text = [VectorL10n callVoiceWithUser:peerDisplayName];
        }
    }
    
    if (peerAvatarURL)
    {
        // Suppose avatar url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
        callerImageView.mediaFolder = kMXMediaManagerAvatarThumbnailFolder;
        callerImageView.enableInMemoryCache = YES;
        [callerImageView setImageURI:peerAvatarURL
                            withType:nil
                 andImageOrientation:UIImageOrientationUp
                       toFitViewSize:callerImageView.frame.size
                          withMethod:MXThumbnailingMethodCrop
                        previewImage:self.picturePlaceholder
                        mediaManager:self.mainSession.mediaManager];
    }
    else
    {
        callerImageView.image = self.picturePlaceholder;
    }
    
    // Round caller image view
    [callerImageView.layer setCornerRadius:callerImageView.frame.size.width / 2];
    callerImageView.clipsToBounds = YES;
}

- (void)setIsRinging:(Boolean)isRinging
{
    if (_isRinging != isRinging)
    {
        if (isRinging)
        {
            NSURL *audioUrl;
            if (mxCall.isIncoming)
            {
                if (self.playRingtone)
                    audioUrl = [self audioURLWithName:@"ring"];
            }
            else
            {
                audioUrl = [self audioURLWithName:@"ringback"];
            }
            
            if (audioUrl)
            {
                [[MXKSoundPlayer sharedInstance] playSoundAt:audioUrl repeat:YES vibrate:mxCall.isIncoming routeToBuiltInReceiver:!mxCall.isIncoming];
            }
        }
        else
        {
            [[MXKSoundPlayer sharedInstance] stopPlayingWithAudioSessionDeactivation:NO];
        }
        
        _isRinging = isRinging;
    }
}

- (void)setDelegate:(id<MXKCallViewControllerDelegate>)delegate
{
    _delegate = delegate;
    
    if (_delegate)
    {
        backToAppButton.hidden = NO;
    }
    else
    {
        backToAppButton.hidden = YES;
    }
}

- (UITapGestureRecognizer *)onHoldCallContainerTapRecognizer
{
    if (_onHoldCallContainerTapRecognizer == nil)
    {
        _onHoldCallContainerTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(onHoldCallContainerTapped:)];
    }
    return _onHoldCallContainerTapRecognizer;
}

- (BOOL)isDisplayingAlert
{
    return errorAlert != nil;
}

- (UIButton *)moreButton
{
    if (mxCall.isVideoCall)
    {
        return _moreButtonForVideo;
    }
    return _moreButtonForVoice;
}

#pragma mark - Sounds

- (NSURL *)audioURLWithName:(NSString *)soundName
{
    return [NSBundle mxk_audioURLFromMXKAssetsBundleWithName:soundName];
}

#pragma mark - Actions

- (void)onHoldCallContainerTapped:(UITapGestureRecognizer *)recognizer
{
    if ([self.delegate respondsToSelector:@selector(callViewControllerDidTapOnHoldCall:)])
    {
        [self.delegate callViewControllerDidTapOnHoldCall:self];
    }
}

- (IBAction)onButtonPressed:(id)sender
{
    if (sender == answerCallButton)
    {
        // If we are here, we have access to the camera
        // The following check is mainly to check microphone access permission
        NSString *appDisplayName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];

        [MXKTools checkAccessForCall:mxCall.isVideoCall
         manualChangeMessageForAudio:[VectorL10n microphoneAccessNotGrantedForCall:appDisplayName]
         manualChangeMessageForVideo:[VectorL10n cameraAccessNotGrantedForCall:appDisplayName]
           showPopUpInViewController:self completionHandler:^(BOOL granted) {

               if (granted)
               {
                   [self->mxCall answer];
               }
           }];
    }
    else if (sender == rejectCallButton || sender == endCallButton)
    {
        if (mxCall.state != MXCallStateEnded)
        {
            [mxCall hangup];
        }
        else
        {
            [self dismiss];
        }
    }
    else if (sender == audioMuteButton)
    {
        mxCall.audioMuted = !mxCall.audioMuted;
        audioMuteButton.selected = mxCall.audioMuted;
    }
    else if (sender == videoMuteButton)
    {
        mxCall.videoMuted = !mxCall.videoMuted;
        videoMuteButton.selected = mxCall.videoMuted;
    }
    else if (sender == _resumeButton)
    {
        [mxCall hold:NO];
    }
    else if (sender == self.moreButton)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        
        MXWeakify(self);
        
        NSMutableArray<UIAlertAction *> *actions = [NSMutableArray arrayWithCapacity:4];
        
        if (self.speakerButton == nil)
        {
            //  audio device action
            UIAlertAction *audioDeviceAction = [UIAlertAction actionWithTitle:[VectorL10n callMoreActionsChangeAudioDevice]
                                                                        style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * action) {
                
                MXStrongifyAndReturnIfNil(self);
                self->currentAlert = nil;
                [self showAudioDeviceOptions];
                
            }];
            
            [actions addObject:audioDeviceAction];
        }
        
        //  check the call can be up/downgraded
        
        //  check the call can send DTMF tones
        if (self.mxCall.supportsDTMF)
        {
            UIAlertAction *dialpadAction = [UIAlertAction actionWithTitle:[VectorL10n callMoreActionsDialpad]
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {
                
                MXStrongifyAndReturnIfNil(self);
                self->currentAlert = nil;
                [self openDialpad];
                
            }];
            
            [actions addObject:dialpadAction];
        }
        
        //  check the call be holded/unholded
        if (mxCall.supportsHolding)
        {
            NSString *actionLocKey = (mxCall.state == MXCallStateOnHold) ? [VectorL10n callMoreActionsUnhold] : [VectorL10n callMoreActionsHold];
            
            UIAlertAction *holdAction = [UIAlertAction actionWithTitle:actionLocKey
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action) {
                
                MXStrongifyAndReturnIfNil(self);
                self->currentAlert = nil;
                [self->mxCall hold:(self.mxCall.state != MXCallStateOnHold)];
                
            }];
            
            [actions addObject:holdAction];
        }
        
        //  check the call be transferred
        if (mxCall.supportsTransferring && self.peer)
        {
            UIAlertAction *transferAction = [UIAlertAction actionWithTitle:[VectorL10n callMoreActionsTransfer]
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction * action) {
                
                MXStrongifyAndReturnIfNil(self);
                self->currentAlert = nil;
                
                [self openCallTransfer];
            }];
            
            [actions addObject:transferAction];
        }
        
        if (actions.count > 0)
        {
            //  create the alert
            currentAlert = [UIAlertController alertControllerWithTitle:nil
                                                               message:nil
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
            
            //  add actions
            [actions enumerateObjectsUsingBlock:^(UIAlertAction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [currentAlert addAction:obj];
            }];
            
            //  add cancel action always
            [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                             style:UIAlertActionStyleCancel
                                                           handler:^(UIAlertAction * action) {
                
                MXStrongifyAndReturnIfNil(self);
                self->currentAlert = nil;
                
            }]];
            
            [currentAlert popoverPresentationController].sourceView = self.moreButton;
            [currentAlert popoverPresentationController].sourceRect = self.moreButton.bounds;
            [self presentViewController:currentAlert animated:YES completion:nil];
        }
    }
    else if (sender == speakerButton)
    {
        [self showAudioDeviceOptions];
    }
    else if (sender == cameraSwitchButton)
    {
        switch (mxCall.cameraPosition)
        {
            case AVCaptureDevicePositionFront:
                mxCall.cameraPosition = AVCaptureDevicePositionBack;
                break;
                
            default:
                mxCall.cameraPosition = AVCaptureDevicePositionFront;
                break;
        }
    }
    else if (sender == backToAppButton)
    {
        if (_delegate)
        {
            // Dismiss the view controller whereas the call is still running
            [_delegate dismissCallViewController:self completion:nil];
        }
    }
    else if (sender == _transferButton)
    {
        //  actually transfer the call without consulting
        [self.mainSession.callManager transferCall:mxCall.callWithTransferee
                                                to:mxCall.transferTarget
                                    withTransferee:mxCall.transferee
                                      consultFirst:NO
                                           success:^(NSString * _Nullable newCallId) {
            
        }
                                           failure:^(NSError * _Nullable error) {
            
        }];
    }
    
    [self updateProximityAndSleep];
}

- (void)showAudioDeviceOptions
{
    NSMutableArray<UIAlertAction *> *actions = [NSMutableArray new];
    NSArray<MXiOSAudioOutputRoute *> *availableRoutes = mxCall.audioOutputRouter.availableOutputRoutes;
    
    for (MXiOSAudioOutputRoute *route in availableRoutes)
    {
        //  route action
        NSString *name = route.name;
        if (route.routeType == MXiOSAudioOutputRouteTypeLoudSpeakers)
        {
            name = [VectorL10n callMoreActionsAudioUseDevice];
        }
        MXWeakify(self);
        UIAlertAction *routeAction = [UIAlertAction actionWithTitle:name
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action) {
            
            MXStrongifyAndReturnIfNil(self);
            self->currentAlert = nil;
            [self->mxCall.audioOutputRouter changeCurrentRouteTo:route];
            
        }];
        
        [actions addObject:routeAction];
    }
    
    if (actions.count > 0)
    {
        //  create the alert
        currentAlert = [UIAlertController alertControllerWithTitle:nil
                                                           message:nil
                                                    preferredStyle:UIAlertControllerStyleActionSheet];
        
        for (UIAlertAction *action in actions)
        {
            [currentAlert addAction:action];
        }
        
        //  add cancel action
        MXWeakify(self);
        [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n cancel]
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction * action) {
            
            MXStrongifyAndReturnIfNil(self);
            self->currentAlert = nil;
            
        }]];
        
        [currentAlert popoverPresentationController].sourceView = self.moreButton;
        [currentAlert popoverPresentationController].sourceRect = self.moreButton.bounds;
        [self presentViewController:currentAlert animated:YES completion:nil];
    }
}
    
#pragma mark - DTMF

- (void)openDialpad
{
    //  no-op
}

#pragma mark - Call Transfer

- (void)openCallTransfer
{
    //  no-op
}

#pragma mark - MXCallDelegate

- (void)call:(MXCall *)call stateDidChange:(MXCallState)state reason:(MXEvent *)event
{
    // Set default configuration of bottom bar
    endCallButton.hidden = NO;
    rejectCallButton.hidden = YES;
    answerCallButton.hidden = YES;
    self.moreButton.enabled = YES;
    _resumeButton.hidden = state != MXCallStateOnHold;
    _pausedIcon.hidden = state != MXCallStateOnHold && state != MXCallStateRemotelyOnHold;
    _transferButton.hidden = YES;
    
    [localPreviewActivityView stopAnimating];
    
    switch (state)
    {
        case MXCallStateFledgling:
            self.isRinging = NO;
            callStatusLabel.text = [VectorL10n callConnecting];
            break;
        case MXCallStateWaitLocalMedia:
            self.isRinging = NO;
            [self configureSpeakerButton];
            [localPreviewActivityView startAnimating];
            
            // Try to show a special view for incoming view
            [self configureIncomingCallViewIfRequiredWith:call];
            
            break;
        case MXCallStateCreateOffer:
        {
            // When CallKit is enabled and we have an outgoing call, we need to start playing ringback sound
            // only after AVAudioSession will be activated by the system otherwise the sound will be gone.
            // We always receive signal about MXCallStateCreateOffer earlier than the system activates AVAudioSession
            // so we start playing ringback sound only on AVAudioSession activation in handleAudioSessionActivationNotification
            BOOL isCallKitAvailable = [MXCallKitAdapter callKitAvailable] && [MXKAppSettings standardAppSettings].isCallKitEnabled;
            if (!isCallKitAvailable)
            {
                self.isRinging = YES;
            }
            
            callStatusLabel.text = [VectorL10n callConnecting];
            break;
        }
        case MXCallStateInviteSent:
        {
            callStatusLabel.text = [VectorL10n callRinging];
            break;
        }
        case MXCallStateRinging:
            self.isRinging = YES;
            [self configureSpeakerButton];
            if (call.isVideoCall)
            {
                callStatusLabel.text = [VectorL10n incomingVideoCall];
            }
            else
            {
                callStatusLabel.text = [VectorL10n incomingVoiceCall];
            }
            // Update bottom bar
            endCallButton.hidden = YES;
            rejectCallButton.hidden = NO;
            answerCallButton.hidden = NO;
            
            // Try to show a special view for incoming view
            [self configureIncomingCallViewIfRequiredWith:call];
            
            break;
        case MXCallStateConnecting:
            self.isRinging = NO;
            
            // User has accepted the call and we can remove incomingCallView
            if (self.incomingCallView)
            {
                [UIView transitionWithView:self.view
                                  duration:0.33
                                   options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionCurveEaseOut
                                animations:^{
                                    [self.incomingCallView removeFromSuperview];
                                }
                                completion:^(BOOL finished) {
                                    self.incomingCallView = nil;
                                }];
            }
            
            break;
        case MXCallStateConnected:
            self.isRinging = NO;
            [self updateTimeStatusLabel];

            if (call.isVideoCall)
            {
                self.callerImageView.hidden = YES;
                
                if (call.isConferenceCall)
                {
                    // Do not show self view anymore because it is returned by the conference bridge
                    self.localPreviewContainerView.hidden = YES;

                    // Well, hide does not work. So, shrink the view to nil
                    self.localPreviewContainerView.frame = CGRectZero;
                }
            }
            audioMuteButton.enabled = YES;
            videoMuteButton.enabled = YES;
            speakerButton.enabled = YES;
            cameraSwitchButton.enabled = YES;
            if (call.isConsulting)
            {
                _transferButton.hidden = NO;
            }

            break;
        case MXCallStateOnHold:
            callStatusLabel.text = [VectorL10n callHolded];
            
            break;
        case MXCallStateRemotelyOnHold:
            audioMuteButton.enabled = NO;
            videoMuteButton.enabled = NO;
            speakerButton.enabled = NO;
            cameraSwitchButton.enabled = NO;
            self.moreButton.enabled = NO;
            callStatusLabel.text = [VectorL10n callRemoteHolded:peerDisplayName];
            
            break;
        case MXCallStateInviteExpired:
            // MXCallStateInviteExpired state is sent as an notification
            // MXCall will move quickly to the MXCallStateEnded state
            self.isRinging = NO;
            callStatusLabel.text = [VectorL10n callInviteExpired];
            
            break;
        case MXCallStateEnded:
        {
            self.isRinging = NO;
            callStatusLabel.text = [VectorL10n callEnded];
            
            NSString *soundName = [self soundNameForCallEnding];
            if (soundName)
            {
                NSURL *audioUrl = [self audioURLWithName:soundName];
                [[MXKSoundPlayer sharedInstance] playSoundAt:audioUrl repeat:NO vibrate:NO routeToBuiltInReceiver:YES];
            }
            else
            {
                [[MXKSoundPlayer sharedInstance] stopPlayingWithAudioSessionDeactivation:YES];
            }
            
            // Except in case of call error, quit the screen right now
            if (!errorAlert)
            {
                [self dismiss];
            }

            break;
        }
        default:
            break;
    }
    
    [self updateProximityAndSleep];
}

- (void)call:(MXCall *)call didEncounterError:(NSError *)error reason:(MXCallHangupReason)reason
{
    MXLogDebug(@"[MXKCallViewController] didEncounterError. mxCall.state: %tu. Stop call due to error: %@", mxCall.state, error);

    if (mxCall.state != MXCallStateEnded)
    {
        // Popup the error to the user
        NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
        if (!title)
        {
            title = [VectorL10n error];
        }
        NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
        if (!msg)
        {
            msg = [VectorL10n errorCommonMessage];
        }

        MXWeakify(self);
        errorAlert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        
        [errorAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n ok]
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * action) {
            
            MXStrongifyAndReturnIfNil(self);
            self->errorAlert = nil;
            [self dismiss];
            
        }]];
        
        [self presentViewController:errorAlert animated:YES completion:nil];
        
        // And interrupt the call
        [mxCall hangupWithReason:reason];
    }
}

- (void)callConsultingStatusDidChange:(MXCall *)call
{
    [self updatePeerInfoDisplay];
    
    if (call.isConsulting)
    {
        NSString *title = [VectorL10n callTransferToUser:call.transferee.displayname];
        [_transferButton setTitle:title forState:UIControlStateNormal];
        _transferButton.hidden = call.state != MXCallStateConnected;
    }
    else
    {
        _transferButton.hidden = YES;
    }
}

- (void)callAssertedIdentityDidChange:(MXCall *)call
{
    MXAssertedIdentityModel *assertedIdentity = call.assertedIdentity;
    
    if (assertedIdentity)
    {
        //  update caller display name and avatar with the asserted identity
        NSString *peerAvatarURL = assertedIdentity.avatarUrl;
        
        if (assertedIdentity.displayname)
        {
            peerDisplayName = assertedIdentity.displayname;
        }
        else if (assertedIdentity.userId)
        {
            peerDisplayName = assertedIdentity.userId;
        }
        
        if (mxCall.isVideoCall)
        {
            callerNameLabel.text = [VectorL10n callVideoWithUser:peerDisplayName];
        }
        else
        {
            callerNameLabel.text = [VectorL10n callVoiceWithUser:peerDisplayName];
        }
        
        if (peerAvatarURL)
        {
            // Suppose avatar url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
            callerImageView.mediaFolder = kMXMediaManagerAvatarThumbnailFolder;
            callerImageView.enableInMemoryCache = YES;
            [callerImageView setImageURI:peerAvatarURL
                                withType:nil
                     andImageOrientation:UIImageOrientationUp
                           toFitViewSize:callerImageView.frame.size
                              withMethod:MXThumbnailingMethodCrop
                            previewImage:self.picturePlaceholder
                            mediaManager:self.mainSession.mediaManager];
        }
        else
        {
            callerImageView.image = self.picturePlaceholder;
        }
        
        [updateStatusTimer fire];
    }
    else
    {
        //  go back to the original display name and avatar
        [self updatePeerInfoDisplay];
    }
}

- (void)callAudioOutputRouteTypeDidChange:(MXCall *)call
{
    [self configureSpeakerButton];
}

- (void)callAvailableAudioOutputsDidChange:(MXCall *)call
{
    
}

#pragma mark - Internal

- (void)removeObservers
{
    if (roomDidFlushDataNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomDidFlushDataNotificationObserver];
        roomDidFlushDataNotificationObserver = nil;
    }
    
    if (audioSessionRouteChangeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:audioSessionRouteChangeNotificationObserver];
        audioSessionRouteChangeNotificationObserver = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (roomListener && mxCall.room)
    {
        MXWeakify(self);
        [mxCall.room liveTimeline:^(id<MXEventTimeline> liveTimeline) {
            MXStrongifyAndReturnIfNil(self);

            [liveTimeline removeListener:self->roomListener];
            self->roomListener = nil;
        }];
    }
}

- (void)callRoomStateDidChange:(dispatch_block_t)onComplete
{
    // Handle peer here
    if (mxCall.isIncoming)
    {
        self.peer = [mxCall.room.mxSession getOrCreateUser:mxCall.callerId];
        if (onComplete)
        {
            onComplete();
        }
    }
    else
    {
        // For 1:1 call, find the other peer
        // Else, the room information will be used to display information about the call
        if (!mxCall.isConferenceCall)
        {
            MXWeakify(self);
            [mxCall.room state:^(MXRoomState *roomState) {
                MXStrongifyAndReturnIfNil(self);
            
                MXUser *theMember = nil;
                NSArray *members = roomState.members.joinedMembers;
                for (MXUser *member in members)
                {
                    if (![member.userId isEqualToString:self->mxCall.callerId])
                    {
                        theMember = member;
                        break;
                    }
                }

                self.peer = theMember;
                if (onComplete)
                {
                    onComplete();
                }
            }];
        }
        else
        {
            self.peer = nil;
            if (onComplete)
            {
                onComplete();
            }
        }
    }
}

- (BOOL)isBuiltInReceiverAudioOuput
{
#if TARGET_IPHONE_SIMULATOR
    return YES;
#endif
    BOOL isBuiltInReceiverUsed = NO;
    
    // Check whether the audio output is the built-in receiver
    AVAudioSessionRouteDescription *audioRoute = [[AVAudioSession sharedInstance] currentRoute];
    if (audioRoute.outputs.count)
    {
        // TODO: handle the case where multiple outputs are returned
        AVAudioSessionPortDescription *audioOutputs = audioRoute.outputs.firstObject;
        isBuiltInReceiverUsed = ([audioOutputs.portType isEqualToString:AVAudioSessionPortBuiltInReceiver]);
    }
    
    return isBuiltInReceiverUsed;
}

- (NSString *)soundNameForCallEnding
{
    if (mxCall.endReason == MXCallEndReasonUnknown)
        return nil;
    
    if (mxCall.isEstablished)
        return @"callend";
    
    if (mxCall.endReason == MXCallEndReasonBusy || (!mxCall.isIncoming && mxCall.endReason == MXCallEndReasonMissed))
        return @"busy";
    
    return nil;
}

- (void)handleAudioSessionActivationNotification
{
    // It's only relevant for outgoing calls which aren't in connected state
    if (self.mxCall.state >= MXCallStateCreateOffer && self.mxCall.state != MXCallStateConnected && self.mxCall.state != MXCallStateEnded)
    {
        self.isRinging = YES;
    }
}

#pragma mark - UI methods

- (void)configureSpeakerButton
{
    switch (mxCall.audioOutputRouter.currentRoute.routeType)
    {
        case MXiOSAudioOutputRouteTypeBuiltIn:
            self.speakerButton.selected = NO;
            break;
        case MXiOSAudioOutputRouteTypeLoudSpeakers:
        case MXiOSAudioOutputRouteTypeExternalWired:
        case MXiOSAudioOutputRouteTypeExternalBluetooth:
        case MXiOSAudioOutputRouteTypeExternalCar:
            self.speakerButton.selected = YES;
            break;
    }
}

- (void)configureIncomingCallViewIfRequiredWith:(MXCall *)call
{
    if (call.isIncoming && !self.incomingCallView)
    {
        UIView *incomingCallView = [self createIncomingCallView];
        if (incomingCallView)
        {
            self.incomingCallView = incomingCallView;
            [self.view addSubview:incomingCallView];
            
            incomingCallView.translatesAutoresizingMaskIntoConstraints = NO;
            [incomingCallView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0].active = YES;
            [incomingCallView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:0].active = YES;
            [incomingCallView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0].active = YES;
            [incomingCallView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:0].active = YES;
        }
    }
}

- (void)updateLocalPreviewLayout
{
    // On IOS 8 and later, the screen size is oriented.
    CGRect bounds = [[UIScreen mainScreen] bounds];
    BOOL isLandscapeOriented = (bounds.size.width > bounds.size.height);
    
    CGFloat maxPreviewFrameSize, minPreviewFrameSize;
    
    if (_localPreviewContainerViewWidthConstraint.constant < _localPreviewContainerViewHeightConstraint.constant)
    {
        maxPreviewFrameSize = _localPreviewContainerViewHeightConstraint.constant;
        minPreviewFrameSize = _localPreviewContainerViewWidthConstraint.constant;
    }
    else
    {
        minPreviewFrameSize = _localPreviewContainerViewHeightConstraint.constant;
        maxPreviewFrameSize = _localPreviewContainerViewWidthConstraint.constant;
    }
    
    if (isLandscapeOriented)
    {
        _localPreviewContainerViewHeightConstraint.constant = minPreviewFrameSize;
        _localPreviewContainerViewWidthConstraint.constant = maxPreviewFrameSize;
    }
    else
    {
        _localPreviewContainerViewHeightConstraint.constant = maxPreviewFrameSize;
        _localPreviewContainerViewWidthConstraint.constant = minPreviewFrameSize;
    }
    
    CGPoint previewOrigin = self.localPreviewContainerView.frame.origin;
    
    if (previewOrigin.x != (bounds.size.width - _localPreviewContainerViewWidthConstraint.constant - kLocalPreviewMargin))
    {
        CGFloat posX = (bounds.size.width - _localPreviewContainerViewWidthConstraint.constant - kLocalPreviewMargin);
        _localPreviewContainerViewLeadingConstraint.constant = posX;
    }
    
    if (previewOrigin.y != kLocalPreviewMargin)
    {
        CGFloat posY = (bounds.size.height - _localPreviewContainerViewHeightConstraint.constant - kLocalPreviewMargin);
        _localPreviewContainerViewTopConstraint.constant = posY;
    }
}

- (void)showOverlayContainer:(BOOL)isShown
{
    if (mxCall && !mxCall.isVideoCall) isShown = YES;
    if (mxCall.state != MXCallStateConnected) isShown = YES;
    
    if (isShown)
    {
        overlayContainerView.hidden = NO;
        if (mxCall && mxCall.isVideoCall)
        {
            [hideOverlayTimer invalidate];
            hideOverlayTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(hideOverlay:) userInfo:nil repeats:NO];
        }
    }
    else
    {
        overlayContainerView.hidden = YES;
    }
}

- (void)toggleOverlay
{
    [self showOverlayContainer:overlayContainerView.isHidden];
}

- (void)hideOverlay:(NSTimer*)theTimer
{
    [self showOverlayContainer:NO];
    hideOverlayTimer = nil;
}

- (void)updateTimeStatusLabel
{
    if (mxCall.state == MXCallStateConnected)
    {
        NSUInteger duration = mxCall.duration / 1000;
        NSUInteger secs = duration % 60;
        NSUInteger mins = (duration - secs) / 60;
        callStatusLabel.text = [NSString stringWithFormat:@"%02tu:%02tu", mins, secs];
    }
}

 - (void)updateProximityAndSleep
 {
     BOOL inCall = (mxCall.state == MXCallStateConnected || mxCall.state == MXCallStateRinging || mxCall.state == MXCallStateInviteSent || mxCall.state == MXCallStateConnecting || mxCall.state == MXCallStateCreateOffer || mxCall.state == MXCallStateCreateAnswer);

     BOOL isBuiltInReceiverUsed = self.isBuiltInReceiverAudioOuput;
     
     // Enable the proximity monitoring when the built in receiver is used as the audio output.
     BOOL enableProxMonitoring = inCall && isBuiltInReceiverUsed;
     
     UIDevice *device = [UIDevice currentDevice];
     if (device && device.isProximityMonitoringEnabled != enableProxMonitoring)
     {
         [device setProximityMonitoringEnabled:enableProxMonitoring];
     }

     // Disable the idle timer during a video call, or during a voice call which is performed with the built-in receiver.
     // Note: if the device is locked, VoIP calling get dropped if an incoming GSM call is received.
     BOOL disableIdleTimer = inCall && (mxCall.isVideoCall || isBuiltInReceiverUsed);
     
     UIApplication *sharedApplication = [UIApplication performSelector:@selector(sharedApplication)];
     if (sharedApplication && sharedApplication.isIdleTimerDisabled != disableIdleTimer)
     {
         sharedApplication.idleTimerDisabled = disableIdleTimer;
     }
 }

- (UIView *)createIncomingCallView
{
    return nil;
}

#pragma mark - UIResponder Touch Events

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.view];
    if ((!self.localPreviewContainerView.hidden) && CGRectContainsPoint(self.localPreviewContainerView.frame, point))
    {
        // Starting to move the local preview view
        if (mxCallOnHold)
        {
            //  if there is a call on hold, do not move local preview for now
            //  TODO: Instead of wholly avoiding mobility of local preview, just avoid the on hold call's corner here
            return;
        }
        isSelectingLocalPreview = YES;
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    isMovingLocalPreview = NO;
    isSelectingLocalPreview = NO;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (isMovingLocalPreview)
    {
        UITouch *touch = [touches anyObject];
        CGPoint point = [touch locationInView:self.view];
        
        CGRect bounds = self.view.bounds;
        CGFloat midX = bounds.size.width / 2.0;
        CGFloat midY = bounds.size.height / 2.0;
        
        CGFloat posX = (point.x < midX) ? 20.0 : (bounds.size.width - _localPreviewContainerViewWidthConstraint.constant - 20.0);
        CGFloat posY = (point.y < midY) ? 20.0 : (bounds.size.height - _localPreviewContainerViewHeightConstraint.constant - 20.0);
        
        _localPreviewContainerViewLeadingConstraint.constant = posX;
        _localPreviewContainerViewTopConstraint.constant = posY;
        
        [self.view setNeedsUpdateConstraints];
    }
    else
    {
        [self toggleOverlay];
    }
    isMovingLocalPreview = NO;
    isSelectingLocalPreview = NO;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.view];
    
    if (isSelectingLocalPreview)
    {
        isMovingLocalPreview = YES;
        self.localPreviewContainerView.center = point;
    }
}

#pragma mark - UIDeviceOrientationDidChangeNotification

- (void)deviceOrientationDidChange
{
    [self applyDeviceOrientation:NO];
    
    [self showOverlayContainer:YES];
}

- (void)applyDeviceOrientation:(BOOL)forcePortrait
{
    if (mxCall)
    {
        UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
        
        // Set the camera orientation according to the orientation supported by the app
        if (UIDeviceOrientationPortrait == deviceOrientation || UIDeviceOrientationLandscapeLeft == deviceOrientation || UIDeviceOrientationLandscapeRight == deviceOrientation)
        {
            mxCall.selfOrientation = deviceOrientation;
            [self updateLocalPreviewLayout];
        }
        else if (forcePortrait)
        {
            mxCall.selfOrientation = UIDeviceOrientationPortrait;
            [self updateLocalPreviewLayout];
        }        
    }
}

@end
/*
Copyright 2018-2024 New Vector Ltd.
Copyright 2017 Vector Creations Ltd
Copyright 2015 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

#import "MXKRoomMemberDetailsViewController.h"

@import MatrixSDK.MXMediaManager;

#import "MXKTableViewCellWithButtons.h"

#import "NSBundle+MatrixKit.h"

#import "MXKAppSettings.h"

#import "MXKConstants.h"

#import "MXKSwiftHeader.h"

@interface MXKRoomMemberDetailsViewController ()
{
    id membersListener;
    
    // mask view while processing a request
    UIActivityIndicatorView * pendingMaskSpinnerView;
    
    // Observe left rooms
    id leaveRoomNotificationObserver;
    
    // Observe kMXRoomDidFlushDataNotification to take into account the updated room members when the room history is flushed.
    id roomDidFlushDataNotificationObserver;

    // Cache for the room live timeline
    id<MXEventTimeline> mxRoomLiveTimeline;
}

@end

@implementation MXKRoomMemberDetailsViewController
@synthesize mxRoom;

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRoomMemberDetailsViewController class])
                          bundle:[NSBundle bundleForClass:[MXKRoomMemberDetailsViewController class]]];
}

+ (instancetype)roomMemberDetailsViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKRoomMemberDetailsViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKRoomMemberDetailsViewController class]]];
}

- (void)finalizeInit
{
    [super finalizeInit];
    
    actionsArray = [[NSMutableArray alloc] init];
    _enableLeave = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Check whether the view controller has been pushed via storyboard
    if (!self.tableView)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }
    
    // ignore useless update
    if (_mxRoomMember)
    {
        [self initObservers];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self initObservers];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self removeObservers];
}

- (void)destroy
{
    // close any pending actionsheet
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    [self removePendingActionMask];
    
    [self removeObservers];
    
    _delegate = nil;
    _mxRoomMember = nil;
    
    actionsArray = nil;
    
    [super destroy];
}

#pragma mark -

- (void)displayRoomMember:(MXRoomMember*)roomMember withMatrixRoom:(MXRoom*)room
{
    [self removeObservers];
    
    mxRoom = room;

    MXWeakify(self);
    [mxRoom liveTimeline:^(id<MXEventTimeline> liveTimeline) {
        MXStrongifyAndReturnIfNil(self);

        self->mxRoomLiveTimeline = liveTimeline;

        // Update matrix session associated to the view controller
        NSArray *mxSessions = self.mxSessions;
        for (MXSession *mxSession in mxSessions) {
            [self removeMatrixSession:mxSession];
        }
        [self addMatrixSession:room.mxSession];

        self->_mxRoomMember = roomMember;

        [self initObservers];
    }];
}

- (id<MXEventTimeline> )mxRoomLiveTimeline
{
    // @TODO(async-state): Just here for dev
    NSAssert(mxRoomLiveTimeline, @"[MXKRoomMemberDetailsViewController] Room live timeline must be preloaded before accessing to MXKRoomMemberDetailsViewController.mxRoomLiveTimeline");
    return mxRoomLiveTimeline;
}

- (UIImage*)picturePlaceholder
{
    return [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"default-profile"];
}

- (void)setEnableMention:(BOOL)enableMention
{
    if (_enableMention != enableMention)
    {
        _enableMention = enableMention;
        
        [self updateMemberInfo];
    }
}

- (void)setEnableVoipCall:(BOOL)enableVoipCall
{
    if (_enableVoipCall != enableVoipCall)
    {
        _enableVoipCall = enableVoipCall;
        
        [self updateMemberInfo];
    }
}

- (void)setEnableLeave:(BOOL)enableLeave
{
    if (_enableLeave != enableLeave)
    {
        _enableLeave = enableLeave;
        
        [self updateMemberInfo];
    }
}

- (IBAction)onActionButtonPressed:(id)sender
{
    if ([sender isKindOfClass:[UIButton class]])
    {
        // Check whether an action is already in progress
        if ([self hasPendingAction])
        {
            return;
        }
        
        UIButton *button = (UIButton*)sender;
        
        switch (button.tag)
        {
            case MXKRoomMemberDetailsActionInvite:
            {
                [self addPendingActionMask];
                [mxRoom inviteUser:_mxRoomMember.userId
                           success:^{
                               
                               [self removePendingActionMask];
                               
                           } failure:^(NSError *error) {
                               
                               [self removePendingActionMask];
                               MXLogDebug(@"[MXKRoomMemberDetailsVC] Invite %@ failed", self->_mxRoomMember.userId);
                               // Notify MatrixKit user
                               NSString *myUserId = self.mainSession.myUser.userId;
                               [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
                               
                           }];
                break;
            }
            case MXKRoomMemberDetailsActionLeave:
            {
                MXWeakify(self);
                [self.mxRoom isLastOwnerWithCompletionHandler:^(BOOL isLastOwner, NSError* error){
                    if (isLastOwner)
                    {
                        UIAlertController *isLastOwnerPrompt = [UIAlertController alertControllerWithTitle:[VectorL10n error]
                                                                                                   message:[VectorL10n roomParticipantsLeaveNotAllowedForLastOwnerMsg]
                                                                                            preferredStyle:UIAlertControllerStyleAlert];
                        
                        [isLastOwnerPrompt addAction:[UIAlertAction actionWithTitle:[VectorL10n ok]
                                                                              style:UIAlertActionStyleCancel
                                                                            handler:^(UIAlertAction * action) {
                            MXStrongifyAndReturnIfNil(self);
                            self->currentAlert = nil;
                        }]];
                        
                        MXStrongifyAndReturnIfNil(self);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self presentViewController:isLastOwnerPrompt animated:YES completion:nil];
                            self->currentAlert = isLastOwnerPrompt;
                        });
                    }
                    else
                    {
                        MXStrongifyAndReturnIfNil(self);
                        [self addPendingActionMask];
                        MXWeakify(self);
                        [self.mxRoom leave:^{
                            MXStrongifyAndReturnIfNil(self);
                            [self removePendingActionMask];
                            [self withdrawViewControllerAnimated:YES completion:nil];
                            
                        } failure:^(NSError *error) {
                            MXStrongifyAndReturnIfNil(self);
                            [self removePendingActionMask];
                            MXLogDebug(@"[MXKRoomMemberDetailsVC] Leave room %@ failed", self->mxRoom.roomId);
                            // Notify MatrixKit user
                            NSString *myUserId = self.mainSession.myUser.userId;
                            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
                            
                        }];
                    }
                }];
                break;
            }
            case MXKRoomMemberDetailsActionKick:
            {
                [self addPendingActionMask];
                [mxRoom kickUser:_mxRoomMember.userId
                          reason:nil
                         success:^{
                             
                             [self removePendingActionMask];
                             // Pop/Dismiss the current view controller if the left members are hidden
                             if (![[MXKAppSettings standardAppSettings] showLeftMembersInRoomMemberList])
                             {
                                 [self withdrawViewControllerAnimated:YES completion:nil];
                             }
                             
                         } failure:^(NSError *error) {
                             
                             [self removePendingActionMask];
                             MXLogDebug(@"[MXKRoomMemberDetailsVC] Kick %@ failed", self->_mxRoomMember.userId);
                             // Notify MatrixKit user
                             NSString *myUserId = self.mainSession.myUser.userId;
                             [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
                             
                         }];
                break;
            }
            case MXKRoomMemberDetailsActionBan:
            {
                [self addPendingActionMask];
                [mxRoom banUser:_mxRoomMember.userId
                         reason:nil
                        success:^{
                            
                            [self removePendingActionMask];
                            
                        } failure:^(NSError *error) {
                            
                            [self removePendingActionMask];
                            MXLogDebug(@"[MXKRoomMemberDetailsVC] Ban %@ failed", self->_mxRoomMember.userId);
                            // Notify MatrixKit user
                            NSString *myUserId = self.mainSession.myUser.userId;
                            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
                            
                        }];
                break;
            }
            case MXKRoomMemberDetailsActionUnban:
            {
                [self addPendingActionMask];
                [mxRoom unbanUser:_mxRoomMember.userId
                          success:^{
                              
                              [self removePendingActionMask];
                              
                          } failure:^(NSError *error) {
                              
                              [self removePendingActionMask];
                              MXLogDebug(@"[MXKRoomMemberDetailsVC] Unban %@ failed", self->_mxRoomMember.userId);
                              // Notify MatrixKit user
                              NSString *myUserId = self.mainSession.myUser.userId;
                              [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
                              
                          }];
                break;
            }
            case MXKRoomMemberDetailsActionIgnore:
            {
                // Prompt user to ignore content from this user
                MXWeakify(self);
                
                if (currentAlert)
                {
                    [currentAlert dismissViewControllerAnimated:NO completion:nil];
                }
                
                currentAlert = [UIAlertController alertControllerWithTitle:[VectorL10n roomMemberIgnorePrompt] message:nil preferredStyle:UIAlertControllerStyleAlert];
                
                [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n yes]
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action) {
                                                                   
                                                                   MXStrongifyAndReturnIfNil(self);
                                                                   
                                                                   self->currentAlert = nil;
                                                                   
                                                                   // Add the user to the blacklist: ignored users
                                                                   [self addPendingActionMask];
                                                                   
                                                                   MXWeakify(self);
                                                                   
                                                                   [self.mainSession ignoreUsers:@[self.mxRoomMember.userId]
                                                                                         success:^{
                                                                                             
                                                                                             MXStrongifyAndReturnIfNil(self);
                                                                                             
                                                                                             [self removePendingActionMask];
                                                                                             
                                                                                         } failure:^(NSError *error) {
                                                                                             
                                                                                             MXStrongifyAndReturnIfNil(self);
                                                                                             
                                                                                             [self removePendingActionMask];
                                                                                             MXLogDebug(@"[MXKRoomMemberDetailsVC] Ignore %@ failed", self.mxRoomMember.userId);
                                                                                             
                                                                                             // Notify MatrixKit user
                                                                                             NSString *myUserId = self.mainSession.myUser.userId;
                                                                                             [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
                                                                                             
                                                                                         }];
                                                                   
                                                               }]];
                
                [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n no]
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action) {
                                                                   
                                                                   MXStrongifyAndReturnIfNil(self);
                                                                   
                                                                   self->currentAlert = nil;
                                                               }]];
                
                [self presentViewController:currentAlert animated:YES completion:nil];
                break;
            }
            case MXKRoomMemberDetailsActionUnignore:
            {
                // Remove the member from the ignored user list.
                [self addPendingActionMask];
                
                MXWeakify(self);
                
                [self.mainSession unIgnoreUsers:@[self.mxRoomMember.userId]
                                            success:^{
                                                
                                                MXStrongifyAndReturnIfNil(self);
                                                [self removePendingActionMask];

                                            } failure:^(NSError *error) {

                                                MXStrongifyAndReturnIfNil(self);
                                                
                                                [self removePendingActionMask];
                                                MXLogDebug(@"[MXKRoomMemberDetailsVC] Unignore %@ failed", self.mxRoomMember.userId);

                                                // Notify MatrixKit user
                                                NSString *myUserId = self.mainSession.myUser.userId;
                                                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];

                                            }];
                break;
            }
            case MXKRoomMemberDetailsActionSetDefaultPowerLevel:
            {
                break;
            }
            case MXKRoomMemberDetailsActionSetModerator:
            {
                break;
            }
            case MXKRoomMemberDetailsActionSetAdmin:
            {
                break;
            }
            case MXKRoomMemberDetailsActionSetCustomPowerLevel:
            {
                [self updateUserPowerLevel];
                break;
            }
            case MXKRoomMemberDetailsActionStartChat:
            {
                if (self.delegate)
                {
                    [self addPendingActionMask];
                    
                    [self.delegate roomMemberDetailsViewController:self startChatWithMemberId:_mxRoomMember.userId completion:^{
                        
                        [self removePendingActionMask];
                    }];
                }
                break;
            }
            case MXKRoomMemberDetailsActionStartVoiceCall:
            case MXKRoomMemberDetailsActionStartVideoCall:
            {
                BOOL isVideoCall = (button.tag == MXKRoomMemberDetailsActionStartVideoCall);
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(roomMemberDetailsViewController:placeVoipCallWithMemberId:andVideo:)])
                {
                    [self addPendingActionMask];
                    
                    [self.delegate roomMemberDetailsViewController:self placeVoipCallWithMemberId:_mxRoomMember.userId andVideo:isVideoCall];
                    
                    [self removePendingActionMask];
                }
                else
                {
                    [self addPendingActionMask];
                    
                    MXRoom* directRoom = [self.mainSession directJoinedRoomWithUserId:_mxRoomMember.userId];
                    
                    // Place the call directly if the room exists
                    if (directRoom)
                    {
                        [directRoom placeCallWithVideo:isVideoCall success:nil failure:nil];
                        [self removePendingActionMask];
                    }
                    else
                    {
                        // Create a new room
                        MXRoomCreationParameters *roomCreationParameters = [MXRoomCreationParameters parametersForDirectRoomWithUser:_mxRoomMember.userId];
                        [self.mainSession createRoomWithParameters:roomCreationParameters success:^(MXRoom *room) {

                            // Delay the call in order to be sure that the room is ready
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [room placeCallWithVideo:isVideoCall success:nil failure:nil];
                                [self removePendingActionMask];
                            });

                        } failure:^(NSError *error) {

                            MXLogDebug(@"[MXKRoomMemberDetailsVC] Create room failed");
                            [self removePendingActionMask];
                            // Notify MatrixKit user
                            NSString *myUserId = self.mainSession.myUser.userId;
                            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];

                        }];
                    }
                }
                break;
            }
            case MXKRoomMemberDetailsActionMention:
            {
                // Sanity check
                if (_delegate && [_delegate respondsToSelector:@selector(roomMemberDetailsViewController:mention:)])
                {
                    id<MXKRoomMemberDetailsViewControllerDelegate> delegate = _delegate;
                    MXRoomMember *member = _mxRoomMember;
                    
                    // Withdraw the current view controller, and let the delegate mention the member
                    [self withdrawViewControllerAnimated:YES completion:^{
                        
                        [delegate roomMemberDetailsViewController:self mention:member];

                    }];
                }
                break;
            }
            default:
                break;
        }
    }
}

#pragma mark - Internals

- (void)initObservers
{
    // Remove any pending observers
    [self removeObservers];
    
    if (mxRoom)
    {
        // Observe room's members update
        NSArray *mxMembersEvents = @[kMXEventTypeStringRoomMember, kMXEventTypeStringRoomPowerLevels];
        self->membersListener = [mxRoom listenToEventsOfTypes:mxMembersEvents onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {

            // consider only live event
            if (direction == MXTimelineDirectionForwards)
            {
                [self refreshRoomMember];
            }
        }];

        // Observe kMXSessionWillLeaveRoomNotification to be notified if the user leaves the current room.
        leaveRoomNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionWillLeaveRoomNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            // Check whether the user will leave the room related to the displayed member
            if (notif.object == self.mainSession)
            {
                NSString *roomId = notif.userInfo[kMXSessionNotificationRoomIdKey];
                if (roomId && [roomId isEqualToString:self->mxRoom.roomId])
                {
                    // We must remove the current view controller.
                    [self withdrawViewControllerAnimated:YES completion:nil];
                }
            }
        }];
        
        // Observe room history flush (sync with limited timeline, or state event redaction)
        roomDidFlushDataNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomDidFlushDataNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            MXRoom *room = notif.object;
            if (self.mainSession == room.mxSession && [self->mxRoom.roomId isEqualToString:room.roomId])
            {
                // The existing room history has been flushed during server sync.
                // Take into account the updated room members list by updating the room member instance
                [self refreshRoomMember];
            }
            
        }];
    }
    
    [self updateMemberInfo];
}

- (void)removeObservers
{
    if (leaveRoomNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:leaveRoomNotificationObserver];
        leaveRoomNotificationObserver = nil;
    }
    if (roomDidFlushDataNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomDidFlushDataNotificationObserver];
        roomDidFlushDataNotificationObserver = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (membersListener && mxRoom)
    {
        MXWeakify(self);
        [mxRoom liveTimeline:^(id<MXEventTimeline> liveTimeline) {
            MXStrongifyAndReturnIfNil(self);

            [liveTimeline removeListener:self->membersListener];
            self->membersListener = nil;
        }];
    }
}

- (void)refreshRoomMember
{
    // Hide potential action sheet
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
        currentAlert = nil;
    }
    
    MXRoomMember* nextRoomMember = nil;
    
    // get the updated memmber
    NSArray<MXRoomMember *> *membersList = self.mxRoomLiveTimeline.state.members.members;
    for (MXRoomMember* member in membersList)
    {
        if ([member.userId isEqualToString:_mxRoomMember.userId])
        {
            nextRoomMember = member;
            break;
        }
    }
    
    // does the member still exist ?
    if (nextRoomMember)
    {
        // Refresh member
        _mxRoomMember = nextRoomMember;
        [self updateMemberInfo];
    }
    else
    {
        [self withdrawViewControllerAnimated:YES completion:nil];
    }
}

- (void)updateMemberInfo
{
    self.title = _mxRoomMember.displayname ? _mxRoomMember.displayname : _mxRoomMember.userId;
    
    // set the thumbnail info
    self.memberThumbnail.contentMode = UIViewContentModeScaleAspectFill;
    self.memberThumbnail.defaultBackgroundColor = [UIColor clearColor];
    [self.memberThumbnail.layer setCornerRadius:self.memberThumbnail.frame.size.width / 2];
    [self.memberThumbnail setClipsToBounds:YES];
    
    self.memberThumbnail.mediaFolder = kMXMediaManagerAvatarThumbnailFolder;
    self.memberThumbnail.enableInMemoryCache = YES;
    [self.memberThumbnail setImageURI:_mxRoomMember.avatarUrl
                             withType:nil
                  andImageOrientation:UIImageOrientationUp
                        toFitViewSize:self.memberThumbnail.frame.size
                           withMethod:MXThumbnailingMethodCrop
                         previewImage:self.picturePlaceholder
                           mediaManager:self.mainSession.mediaManager];
    
    self.roomMemberMatrixInfo.text = _mxRoomMember.userId;
    
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Check user's power level before allowing an action (kick, ban, ...)
    MXRoomState *roomState = self.mxRoomLiveTimeline.state;
    MXRoomPowerLevels *powerLevels = [self.mxRoomLiveTimeline.state powerLevels];
    NSInteger memberPowerLevel = [roomState powerLevelOfUserWithUserID:_mxRoomMember.userId];
    NSInteger oneSelfPowerLevel = [roomState powerLevelOfUserWithUserID:self.mainSession.myUser.userId];
    
    [actionsArray removeAllObjects];
    
    // Consider the case of the user himself
    if ([_mxRoomMember.userId isEqualToString:self.mainSession.myUser.userId])
    {
        if (_enableLeave)
        {
            [actionsArray addObject:@(MXKRoomMemberDetailsActionLeave)];
        }
        
        if (oneSelfPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsStateEvent:kMXEventTypeStringRoomPowerLevels])
        {
            [actionsArray addObject:@(MXKRoomMemberDetailsActionSetCustomPowerLevel)];
        }
    }
    else if (_mxRoomMember)
    {
        if (_enableVoipCall)
        {
            // Offer voip call options
            [actionsArray addObject:@(MXKRoomMemberDetailsActionStartVoiceCall)];
            [actionsArray addObject:@(MXKRoomMemberDetailsActionStartVideoCall)];
        }
        
        // Consider membership of the selected member
        switch (_mxRoomMember.membership)
        {
            case MXMembershipInvite:
            case MXMembershipJoin:
            {
                // Check conditions to be able to kick someone
                if (oneSelfPowerLevel >= [powerLevels kick] && oneSelfPowerLevel > memberPowerLevel)
                {
                    [actionsArray addObject:@(MXKRoomMemberDetailsActionKick)];
                }
                // Check conditions to be able to ban someone
                if (oneSelfPowerLevel >= [powerLevels ban] && oneSelfPowerLevel > memberPowerLevel)
                {
                    [actionsArray addObject:@(MXKRoomMemberDetailsActionBan)];
                }
                
                // Check whether the option Ignore may be presented
                if (_mxRoomMember.membership == MXMembershipJoin)
                {
                    // is he already ignored ?
                    if (![self.mainSession isUserIgnored:_mxRoomMember.userId])
                    {
                        [actionsArray addObject:@(MXKRoomMemberDetailsActionIgnore)];
                    }
                    else
                    {
                        [actionsArray addObject:@(MXKRoomMemberDetailsActionUnignore)];
                    }
                }
                break;
            }
            case MXMembershipLeave:
            {
                // Check conditions to be able to invite someone
                if (oneSelfPowerLevel >= [powerLevels invite])
                {
                    [actionsArray addObject:@(MXKRoomMemberDetailsActionInvite)];
                }
                // Check conditions to be able to ban someone
                if (oneSelfPowerLevel >= [powerLevels ban] && oneSelfPowerLevel > memberPowerLevel)
                {
                    [actionsArray addObject:@(MXKRoomMemberDetailsActionBan)];
                }
                break;
            }
            case MXMembershipBan:
            {
                // Check conditions to be able to unban someone
                if (oneSelfPowerLevel >= [powerLevels ban] && oneSelfPowerLevel > memberPowerLevel)
                {
                    [actionsArray addObject:@(MXKRoomMemberDetailsActionUnban)];
                }
                break;
            }
            default:
            {
                break;
            }
        }
        
        // update power level
        if (oneSelfPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsStateEvent:kMXEventTypeStringRoomPowerLevels] && oneSelfPowerLevel > memberPowerLevel)
        {
            [actionsArray addObject:@(MXKRoomMemberDetailsActionSetCustomPowerLevel)];
        }
        
        // offer to start a new chat only if the room is not the first direct chat with this user
        // it does not make sense : it would open the same room
        MXRoom* directRoom = [self.mainSession directJoinedRoomWithUserId:_mxRoomMember.userId];
        if (!directRoom || (![directRoom.roomId isEqualToString:mxRoom.roomId]))
        {
            [actionsArray addObject:@(MXKRoomMemberDetailsActionStartChat)];
        }
    }
    
    if (_enableMention)
    {
        // Add mention option
        [actionsArray addObject:@(MXKRoomMemberDetailsActionMention)];
    }
    
    return (actionsArray.count + 1) / 2;
}

- (NSString*)actionButtonTitle:(MXKRoomMemberDetailsAction)action
{
    NSString *title;
    
    switch (action)
    {
        case MXKRoomMemberDetailsActionInvite:
            title = [VectorL10n invite];
            break;
        case MXKRoomMemberDetailsActionLeave:
            title = [VectorL10n leave];
            break;
        case MXKRoomMemberDetailsActionKick:
            title = [VectorL10n kick];
            break;
        case MXKRoomMemberDetailsActionBan:
            title = [VectorL10n ban];
            break;
        case MXKRoomMemberDetailsActionUnban:
            title = [VectorL10n unban];
            break;
        case MXKRoomMemberDetailsActionIgnore:
            title = [VectorL10n ignore];
            break;
        case MXKRoomMemberDetailsActionUnignore:
            title = [VectorL10n unignore];
            break;
        case MXKRoomMemberDetailsActionSetDefaultPowerLevel:
            title = [VectorL10n setDefaultPowerLevel];
            break;
        case MXKRoomMemberDetailsActionSetModerator:
            title = [VectorL10n setModerator];
            break;
        case MXKRoomMemberDetailsActionSetAdmin:
            title = [VectorL10n setAdmin];
            break;
        case MXKRoomMemberDetailsActionSetCustomPowerLevel:
            title = [VectorL10n setPowerLevel];
            break;
        case MXKRoomMemberDetailsActionStartChat:
            title = [VectorL10n startChat];
            break;
        case MXKRoomMemberDetailsActionStartVoiceCall:
            title = [VectorL10n startVoiceCall];
            break;
        case MXKRoomMemberDetailsActionStartVideoCall:
            title = [VectorL10n startVideoCall];
            break;
        case MXKRoomMemberDetailsActionMention:
            title = [VectorL10n mention];
            break;
        default:
            break;
    }
    
    return title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.tableView == tableView)
    {
        NSInteger row = indexPath.row;
        
        MXKTableViewCellWithButtons *cell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButtons defaultReuseIdentifier]];
        if (!cell)
        {
            cell = [[MXKTableViewCellWithButtons alloc] init];
        }
        
        cell.mxkButtonNumber = 2;
        NSArray *buttons = cell.mxkButtons;
        NSInteger index = row * 2;
        NSString *text = nil;
        for (UIButton *button in buttons)
        {
            NSNumber *actionNumber;
            if (index < actionsArray.count)
            {
                actionNumber = [actionsArray objectAtIndex:index];
            }
            
            text = (actionNumber ? [self actionButtonTitle:actionNumber.unsignedIntegerValue] : nil);
            
            button.hidden = (text.length == 0);
            
            button.layer.borderColor = button.tintColor.CGColor;
            button.layer.borderWidth = 1;
            button.layer.cornerRadius = 5;
            
            [button setTitle:text forState:UIControlStateNormal];
            [button setTitle:text forState:UIControlStateHighlighted];
            
            [button addTarget:self action:@selector(onActionButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            
            button.tag = (actionNumber ? actionNumber.unsignedIntegerValue : -1);
            
            index ++;
        }
        
        return cell;
    }
    
    // Return a fake cell to prevent app from crashing.
    return [[UITableViewCell alloc] init];
}


#pragma mark - button management

- (BOOL)hasPendingAction
{
    return nil != pendingMaskSpinnerView;
}

- (void)addPendingActionMask
{
    // add a spinner above the tableview to avoid that the user tap on any other button
    pendingMaskSpinnerView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    pendingMaskSpinnerView.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.5];
    pendingMaskSpinnerView.frame = self.tableView.frame;
    pendingMaskSpinnerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin;
    
    // append it
    [self.tableView.superview addSubview:pendingMaskSpinnerView];
    
    // animate it
    [pendingMaskSpinnerView startAnimating];
}

- (void)removePendingActionMask
{
    if (pendingMaskSpinnerView)
    {
        [pendingMaskSpinnerView removeFromSuperview];
        pendingMaskSpinnerView = nil;
        [self.tableView reloadData];
    }
}

- (void)setPowerLevel:(NSInteger)value promptUser:(BOOL)promptUser
{
    NSInteger currentPowerLevel = [self.mxRoomLiveTimeline.state powerLevelOfUserWithUserID:_mxRoomMember.userId];
    
    // check if the power level has not yet been set to 0
    if (value != currentPowerLevel)
    {
        __weak typeof(self) weakSelf = self;

        if (promptUser && value == [self.mxRoomLiveTimeline.state powerLevelOfUserWithUserID:self.mainSession.myUser.userId])
        {
            // If the user is setting the same power level as his to another user, ask him for a confirmation
            if (currentAlert)
            {
                [currentAlert dismissViewControllerAnimated:NO completion:nil];
            }
            
            currentAlert = [UIAlertController alertControllerWithTitle:[VectorL10n roomMemberPowerLevelPrompt] message:nil preferredStyle:UIAlertControllerStyleAlert];
            
            [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n no]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               if (weakSelf)
                                                               {
                                                                   typeof(self) self = weakSelf;
                                                                   self->currentAlert = nil;
                                                               }
                                                               
                                                           }]];
            
            [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n yes]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               if (weakSelf)
                                                               {
                                                                   typeof(self) self = weakSelf;
                                                                   self->currentAlert = nil;
                                                                   
                                                                   // The user confirms. Apply the power level
                                                                   [self setPowerLevel:value promptUser:NO];
                                                               }
                                                               
                                                           }]];
            
            [self presentViewController:currentAlert animated:YES completion:nil];
        }
        else
        {
            [self addPendingActionMask];

            // Reset user power level
            [self.mxRoom setPowerLevelOfUserWithUserID:_mxRoomMember.userId powerLevel:value success:^{

                __strong __typeof(weakSelf)strongSelf = weakSelf;
                [strongSelf removePendingActionMask];

            } failure:^(NSError *error) {

                __strong __typeof(weakSelf)strongSelf = weakSelf;
                [strongSelf removePendingActionMask];
                MXLogDebug(@"[MXKRoomMemberDetailsVC] Set user power (%@) failed", strongSelf.mxRoomMember.userId);

                // Notify MatrixKit user
                NSString *myUserId = strongSelf.mainSession.myUser.userId;
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error userInfo:myUserId ? @{kMXKErrorUserIdKey: myUserId} : nil];
                
            }];
        }
    }
}

- (void)updateUserPowerLevel
{
    __weak typeof(self) weakSelf = self;
    
    if (currentAlert)
    {
        [currentAlert dismissViewControllerAnimated:NO completion:nil];
    }
    
    currentAlert = [UIAlertController alertControllerWithTitle:[VectorL10n powerLevel] message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    
    if (![self.mainSession.myUser.userId isEqualToString:_mxRoomMember.userId])
    {
        [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n resetToDefault]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (weakSelf)
                                                           {
                                                               typeof(self) self = weakSelf;
                                                               self->currentAlert = nil;
                                                               
                                                               [self setPowerLevel:self.mxRoomLiveTimeline.state.powerLevels.usersDefault promptUser:YES];
                                                           }
                                                           
                                                       }]];
    }
    
    [currentAlert addTextFieldWithConfigurationHandler:^(UITextField *textField)
    {
        typeof(self) self = weakSelf;
        
        textField.secureTextEntry = NO;
        textField.text = [NSString stringWithFormat:@"%ld", (long)[self.mxRoomLiveTimeline.state powerLevelOfUserWithUserID:self.mxRoomMember.userId]];
        textField.placeholder = nil;
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    
    [currentAlert addAction:[UIAlertAction actionWithTitle:[VectorL10n ok]
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       
                                                       if (weakSelf)
                                                       {
                                                           typeof(self) self = weakSelf;
                                                           NSString *text = [self->currentAlert textFields].firstObject.text;
                                                           self->currentAlert = nil;
                                                           
                                                           if (text.length > 0)
                                                           {
                                                               [self setPowerLevel:[text integerValue] promptUser:YES];
                                                           }
                                                       }
                                                       
                                                   }]];
    
    [self presentViewController:currentAlert animated:YES completion:nil];
}

@end
/*
Copyright 2024 New Vector Ltd.
Copyright 2019 The Matrix.org Foundation C.I.C
Copyright 2018 New Vector Ltd
Copyright 2017 Vector Creations Ltd
Copyright 2015 OpenMarket Ltd

SPDX-License-Identifier: AGPL-3.0-only
Please see LICENSE in the repository root for full details.
 */

#import "MXKRoomDataSource.h"

@import MatrixSDK;

#import "MXKQueuedEvent.h"
#import "MXKRoomBubbleTableViewCell.h"

#import "MXKRoomBubbleCellData.h"

#import "MXKTools.h"
#import "MXAggregatedReactions+MatrixKit.h"

#import "MXKAppSettings.h"

#import "GeneratedInterface-Swift.h"

const BOOL USE_THREAD_TIMELINE = YES;

#pragma mark - Constant definitions

NSString *const kMXKRoomBubbleCellDataIdentifier = @"kMXKRoomBubbleCellDataIdentifier";

NSString *const kMXKRoomDataSourceSyncStatusChanged = @"kMXKRoomDataSourceSyncStatusChanged";
NSString *const kMXKRoomDataSourceFailToLoadTimelinePosition = @"kMXKRoomDataSourceFailToLoadTimelinePosition";
NSString *const kMXKRoomDataSourceTimelineError = @"kMXKRoomDataSourceTimelineError";
NSString *const kMXKRoomDataSourceTimelineErrorErrorKey = @"kMXKRoomDataSourceTimelineErrorErrorKey";

NSString * const MXKRoomDataSourceErrorDomain = @"kMXKRoomDataSourceErrorDomain";

typedef NS_ENUM (NSUInteger, MXKRoomDataSourceError) {
    MXKRoomDataSourceErrorResendGeneric = 10001,
    MXKRoomDataSourceErrorResendInvalidMessageType = 10002,
    MXKRoomDataSourceErrorResendInvalidLocalFilePath = 10003,
};


@interface MXKRoomDataSource ()
{
    /**
     If the data is not from a live timeline, `initialEventId` is the event in the past
     where the timeline starts.
     */
    NSString *initialEventId;

    /**
     Current pagination request (if any)
     */
    MXHTTPOperation *paginationRequest;
    
    /**
     The actual listener related to the current pagination in the timeline.
     */
    id paginationListener;
    
    /**
     The listener to incoming events in the room.
     */
    id liveEventsListener;
    
    /**
     The listener to redaction events in the room.
     */
    id redactionListener;
    
    /**
     The listener to receipts events in the room.
     */
    id receiptsListener;

    /**
     The listener to reactions changed in the room.
     */
    id reactionsChangeListener;
    
    /**
     The listener to edits in the room.
     */
    id eventEditsListener;
    
    /**
     Current secondary pagination request (if any)
     */
    MXHTTPOperation *secondaryPaginationRequest;
    
    /**
     The listener to incoming events in the secondary room.
     */
    id secondaryLiveEventsListener;
    
    /**
     The listener to redaction events in the secondary room.
     */
    id secondaryRedactionListener;
    
    /**
     The actual listener related to the current pagination in the secondary timeline.
     */
    id secondaryPaginationListener;
    
    /**
     Mapping between events ids and bubbles.
     */
    NSMutableDictionary *eventIdToBubbleMap;
    
    /**
     Typing notifications listener.
     */
    id typingNotifListener;
    
    /**
     List of members who are typing in the room.
     */
    NSArray *currentTypingUsers;
    
    /**
     Snapshot of the queued events.
     */
    NSMutableArray *eventsToProcessSnapshot;
    
    /**
     Snapshot of the bubbles used during events processing.
     */
    NSMutableArray<id<MXKRoomBubbleCellDataStoring>> *bubblesSnapshot;
    
    /**
     The room being peeked, if any.
     */
    MXPeekingRoom *peekingRoom;

    /**
     If any, the non terminated series of collapsable events at the start of self.bubbles.
     (Such series is determined by the cell data of its oldest event).
     */
    id<MXKRoomBubbleCellDataStoring> collapsableSeriesAtStart;

    /**
     If any, the non terminated series of collapsable events at the end of self.bubbles.
     (Such series is determined by the cell data of its oldest event).
     */
    id<MXKRoomBubbleCellDataStoring> collapsableSeriesAtEnd;

    /**
     Observe UIApplicationSignificantTimeChangeNotification to trigger cell change on time formatting change.
     */
    id UIApplicationSignificantTimeChangeNotificationObserver;
    
    /**
     Observe NSCurrentLocaleDidChangeNotification to trigger cell change on time formatting change.
     */
    id NSCurrentLocaleDidChangeNotificationObserver;
    
    /**
     Observe kMXRoomDidFlushDataNotification to trigger cell change when existing room history has been flushed during server sync.
     */
    id roomDidFlushDataNotificationObserver;
    
    /**
     Observe kMXRoomDidUpdateUnreadNotification to refresh unread counters.
     */
    id roomDidUpdateUnreadNotificationObserver;
    
    /**
     Emote slash command prefix @"/me "
     */
    NSString *emoteMessageSlashCommandPrefix;
}

/**
 Indicate to stop back-paginating when finding an un-decryptable event as previous event.
 It is used to hide pre join UTD events before joining the room.
 */
@property (nonatomic, assign) BOOL shouldPreventBackPaginationOnPreviousUTDEvent;

/**
 Indicate to stop back-paginating.
 */
@property (nonatomic, assign) BOOL shouldStopBackPagination;

@property (nonatomic, readwrite) MXRoom *room;
@property (nonatomic, readwrite) MXThread *thread;

@property (nonatomic, readwrite) MXRoom *secondaryRoom;
@property (nonatomic, strong) id<MXEventTimeline> secondaryTimeline;
@property (nonatomic, readwrite) NSString *threadId;

@end

@implementation MXKRoomDataSource

+ (void)loadRoomDataSourceWithRoomId:(NSString*)roomId threadId:(NSString*)threadId andMatrixSession:(MXSession*)mxSession onComplete:(void (^)(id roomDataSource))onComplete
{
    MXKRoomDataSource *roomDataSource = [[self alloc] initWithRoomId:roomId andMatrixSession:mxSession threadId:threadId];
    [self ensureSessionStateForDataSource:roomDataSource initialEventId:nil andMatrixSession:mxSession onComplete:onComplete];
}

+ (void)loadRoomDataSourceWithRoomId:(NSString*)roomId initialEventId:(NSString*)initialEventId threadId:(NSString*)threadId andMatrixSession:(MXSession*)mxSession onComplete:(void (^)(id roomDataSource))onComplete
{
    MXKRoomDataSource *roomDataSource = [[self alloc] initWithRoomId:roomId initialEventId:initialEventId threadId:threadId andMatrixSession:mxSession];
    [self ensureSessionStateForDataSource:roomDataSource initialEventId:initialEventId andMatrixSession:mxSession onComplete:onComplete];
}

+ (void)loadRoomDataSourceWithPeekingRoom:(MXPeekingRoom*)peekingRoom andInitialEventId:(NSString*)initialEventId onComplete:(void (^)(id roomDataSource))onComplete
{
    MXKRoomDataSource *roomDataSource = [[self alloc] initWithPeekingRoom:peekingRoom andInitialEventId:initialEventId];
    [self finalizeRoomDataSource:roomDataSource onComplete:onComplete];
}

/// Ensure session state to be store data ready for the roomDataSource.
+ (void)ensureSessionStateForDataSource:(MXKRoomDataSource*)roomDataSource initialEventId:(NSString*)initialEventId andMatrixSession:(MXSession*)mxSession onComplete:(void (^)(id roomDataSource))onComplete
{
    //  if store is not ready, roomDataSource.room will be nil. So onComplete block will never be called.
    //  In order to successfully fetch the room, we should wait for store to be ready.
    if (mxSession.state >= MXSessionStateStoreDataReady)
    {
        [self finalizeRoomDataSource:roomDataSource onComplete:onComplete];
    }
    else
    {
        //  wait for session state to be store data ready
        __block id sessionStateObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionStateDidChangeNotification object:mxSession queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            if (mxSession.state >= MXSessionStateStoreDataReady)
            {
                [[NSNotificationCenter defaultCenter] removeObserver:sessionStateObserver];
                [self finalizeRoomDataSource:roomDataSource onComplete:onComplete];
            }
        }];
    }
}

+ (void)finalizeRoomDataSource:(MXKRoomDataSource*)roomDataSource onComplete:(void (^)(id roomDataSource))onComplete
{
    if (roomDataSource)
    {
        [roomDataSource finalizeInitialization];

        // Asynchronously preload data here so that the data will be ready later
        // to synchronously respond to that request

        if (USE_THREAD_TIMELINE)
        {
            if (roomDataSource.threadId)
            {
                [roomDataSource.thread liveTimeline:^(id<MXEventTimeline> _Nonnull liveTimeline) {
                    [liveTimeline resetPagination];
                    onComplete(roomDataSource);
                }];
            }
            else
            {
                [roomDataSource.room liveTimeline:^(id<MXEventTimeline> liveTimeline) {
                    [liveTimeline resetPagination];
                    onComplete(roomDataSource);
                }];
            }
        }
        else
        {
            [roomDataSource.room liveTimeline:^(id<MXEventTimeline> liveTimeline) {
                [liveTimeline resetPagination];
                onComplete(roomDataSource);
            }];
        }
    }
}

- (instancetype)initWithRoomId:(NSString *)roomId andMatrixSession:(MXSession *)matrixSession threadId:(NSString *)threadId
{
    self = [super initWithMatrixSession:matrixSession];
    if (self)
    {
        MXLogVerbose(@"[MXKRoomDataSource][%p] initWithRoomId: %@", self, roomId);
        
        _roomId = roomId;
        _threadId = threadId;
        _secondaryRoomEventTypes = @[
            kMXEventTypeStringCallInvite,
            kMXEventTypeStringCallCandidates,
            kMXEventTypeStringCallAnswer,
            kMXEventTypeStringCallSelectAnswer,
            kMXEventTypeStringCallHangup,
            kMXEventTypeStringCallReject,
            kMXEventTypeStringCallNegotiate,
            kMXEventTypeStringCallReplaces,
            kMXEventTypeStringCallRejectReplacement
        ];
        NSString *virtualRoomId = [matrixSession virtualRoomOf:_roomId];
        if (virtualRoomId)
        {
            _secondaryRoomId = virtualRoomId;
        }
        _isLive = YES;
        bubbles = [NSMutableArray array];
        eventsToProcess = [NSMutableArray array];
        eventIdToBubbleMap = [NSMutableDictionary dictionary];
        
        _filterMessagesWithURL = NO;
        
        emoteMessageSlashCommandPrefix = [NSString stringWithFormat:@"%@ ", [MXKSlashCommandsHelper commandNameFor:MXKSlashCommandEmote]];

        // Set default data and view classes
        // Cell data
        [self registerCellDataClass:MXKRoomBubbleCellData.class forCellIdentifier:kMXKRoomBubbleCellDataIdentifier];
        
        // Set default MXEvent -> NSString formatter
        self.eventFormatter = [[MXKEventFormatter alloc] initWithMatrixSession:self.mxSession];
        // Apply here the event types filter to display only the wanted event types.
        self.eventFormatter.eventTypesFilterForMessages = [MXKAppSettings standardAppSettings].eventsFilterForMessages;
        
        // display the read receips by default
        self.showBubbleReceipts = YES;
        
        // show the read marker by default
        self.showReadMarker = YES;
        
        // Disable typing notification in cells by default.
        self.showTypingNotifications = NO;
        
        self.useCustomDateTimeLabel = NO;
        self.useCustomReceipts = NO;
        self.useCustomUnsentButton = NO;
        
        _maxBackgroundCachedBubblesCount = MXKROOMDATASOURCE_CACHED_BUBBLES_COUNT_THRESHOLD;
        _paginationLimitAroundInitialEvent = MXKROOMDATASOURCE_PAGINATION_LIMIT_AROUND_INITIAL_EVENT;

        // Observe UIApplicationSignificantTimeChangeNotification to refresh bubbles if date/time are shown.
        // UIApplicationSignificantTimeChangeNotification is posted if DST is updated, carrier time is updated
        UIApplicationSignificantTimeChangeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationSignificantTimeChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            [self onDateTimeFormatUpdate];
        }];
        
        // Observe NSCurrentLocaleDidChangeNotification to refresh bubbles if date/time are shown.
        // NSCurrentLocaleDidChangeNotification is triggered when the time swicthes to AM/PM to 24h time format
        NSCurrentLocaleDidChangeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSCurrentLocaleDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            [self onDateTimeFormatUpdate];
            
        }];

        // Listen to the event sent state changes
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventDidChangeSentState:) name:kMXEventDidChangeSentStateNotification object:nil];
        // Listen to events decrypted
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventDidDecrypt:) name:kMXEventDidDecryptNotification object:nil];
        // Listen to virtual rooms change
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(virtualRoomsDidChange:) name:kMXSessionVirtualRoomsDidChangeNotification object:matrixSession];
    }
    return self;
}

- (instancetype)initWithRoomId:(NSString*)roomId initialEventId:(NSString*)initialEventId2 threadId:(NSString*)threadId andMatrixSession:(MXSession*)mxSession
{
    self = [self initWithRoomId:roomId andMatrixSession:mxSession threadId:threadId];
    if (self)
    {
        if (initialEventId2)
        {
            initialEventId = initialEventId2;
            _isLive = NO;
        }
    }

    return self;
}

- (instancetype)initWithPeekingRoom:(MXPeekingRoom*)peekingRoom2 andInitialEventId:(NSString*)theInitialEventId
{
    self = [self initWithRoomId:peekingRoom2.roomId initialEventId:theInitialEventId threadId:nil andMatrixSession:peekingRoom2.mxSession];
    if (self)
    {
        peekingRoom = peekingRoom2;
        _isPeeking = YES;
    }
    return self;
}

- (void)dealloc
{
    [self unregisterEventEditsListener];
    [self unregisterScanManagerNotifications];
    [self unregisterReactionsChangeListener];
}

- (MXRoomState *)roomState
{
    // @TODO(async-state): Just here for dev
    NSAssert(_timeline.state, @"[MXKRoomDataSource] Room state must be preloaded before accessing to MXKRoomDataSource.roomState");
    return _timeline.state;
}

- (void)onDateTimeFormatUpdate
{
    // update the date and the time formatters
    [self.eventFormatter initDateTimeFormatters];
    
    // refresh the UI if it is required
    if (self.showBubblesDateTime && self.delegate)
    {
        // Reload all the table
        [self.delegate dataSource:self didCellChange:nil];
    }
}

- (void)markAllAsRead
{
    [_room.summary markAllAsRead];
}

- (void)limitMemoryUsage:(NSInteger)maxBubbleNb
{
    NSInteger bubbleCount;
    @synchronized(bubbles)
    {
        bubbleCount = bubbles.count;
    }
    
    if (bubbleCount > maxBubbleNb)
    {
        // Do nothing if some local echoes are in progress.
        NSArray<MXEvent*>* outgoingMessages = _room.outgoingMessages;
        
        for (NSInteger index = 0; index < outgoingMessages.count; index++)
        {
            MXEvent *outgoingMessage = [outgoingMessages objectAtIndex:index];
            
            if (outgoingMessage.sentState == MXEventSentStateSending ||
                outgoingMessage.sentState == MXEventSentStatePreparing ||
                outgoingMessage.sentState == MXEventSentStateEncrypting ||
                outgoingMessage.sentState == MXEventSentStateUploading)
            {
                MXLogDebug(@"[MXKRoomDataSource][%p] cancel limitMemoryUsage because some messages are being sent", self);
                return;
            }
        }

        // Reset the room data source (return in initial state: minimum memory usage).
        [self reload];
    }
}

- (void)reset
{
    if (roomDidFlushDataNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomDidFlushDataNotificationObserver];
        roomDidFlushDataNotificationObserver = nil;
    }
    
    if (roomDidUpdateUnreadNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:roomDidUpdateUnreadNotificationObserver];
        roomDidUpdateUnreadNotificationObserver = nil;
    }
    
    if (paginationRequest)
    {
        // We have to remove here the listener. A new pagination request may be triggered whereas the cancellation of this one is in progress
        [_timeline removeListener:paginationListener];
        paginationListener = nil;
        
        [paginationRequest cancel];
        paginationRequest = nil;
    }
    
    if (secondaryPaginationRequest)
    {
        // We have to remove here the listener. A new pagination request may be triggered whereas the cancellation of this one is in progress
        [_secondaryTimeline removeListener:secondaryPaginationListener];
        secondaryPaginationListener = nil;
        
        [secondaryPaginationRequest cancel];
        secondaryPaginationRequest = nil;
    }
    
    if (_room && liveEventsListener)
    {
        [_timeline removeListener:liveEventsListener];
        liveEventsListener = nil;
        
        [_timeline removeListener:redactionListener];
        redactionListener = nil;
        
        [_timeline removeListener:receiptsListener];
        receiptsListener = nil;
    }
    
    if (_secondaryRoom && secondaryLiveEventsListener)
    {
        [_secondaryTimeline removeListener:secondaryLiveEventsListener];
        secondaryLiveEventsListener = nil;
        
        [_secondaryTimeline removeListener:secondaryRedactionListener];
        secondaryRedactionListener = nil;
    }
    
    if (_room && typingNotifListener)
    {
        [_timeline removeListener:typingNotifListener];
        typingNotifListener = nil;
    }
    currentTypingUsers = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXRoomInitialSyncNotification object:nil];
    
    @synchronized(eventsToProcess)
    {
        MXLogVerbose(@"[MXKRoomDataSource][%p] Reset eventsToProcess", self);
        [eventsToProcess removeAllObjects];
    }
    
    // Suspend the reset operation if some events is under processing
    @synchronized(eventsToProcessSnapshot)
    {
        eventsToProcessSnapshot = nil;
        bubblesSnapshot = nil;
        
        @synchronized(bubbles)
        {
            for (id<MXKRoomBubbleCellDataStoring> bubble in bubbles) {
                bubble.prevCollapsableCellData = nil;
                bubble.nextCollapsableCellData = nil;
            }
            [bubbles removeAllObjects];
        }
        
        @synchronized(eventIdToBubbleMap)
        {
            [eventIdToBubbleMap removeAllObjects];
        }
        
        self.room = nil;
        self.thread = nil;
        self.secondaryRoom = nil;
    }
    
    _serverSyncEventCount = 0;
}

- (void)reload
{
    [self reloadNotifying:YES];
}

- (void)reloadNotifying:(BOOL)notify
{
    MXLogVerbose(@"[MXKRoomDataSource][%p] Reload - room id: %@", self, _roomId);
    
    [self setState:MXKDataSourceStatePreparing];
    
    [self reset];
    
    // Reload
    [self didMXSessionStateChange];
    
    // Notify the delegate to refresh the tableview
    if (notify && self.delegate)
    {
        [self.delegate dataSource:self didCellChange:nil];
    }
}

- (void)destroy
{
    MXLogDebug(@"[MXKRoomDataSource][%p] Destroy - room id: %@ - thread id: %@", self, _roomId, _threadId);
    
    [self unregisterScanManagerNotifications];
    [self unregisterReactionsChangeListener];
    [self unregisterEventEditsListener];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidChangeSentStateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidDecryptNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidChangeIdentifierNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXSessionVirtualRoomsDidChangeNotification object:nil];

    if (NSCurrentLocaleDidChangeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:NSCurrentLocaleDidChangeNotificationObserver];
        NSCurrentLocaleDidChangeNotificationObserver = nil;
    }
    
    if (UIApplicationSignificantTimeChangeNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:UIApplicationSignificantTimeChangeNotificationObserver];
        UIApplicationSignificantTimeChangeNotificationObserver = nil;
    }

    // If the room data source was used to peek into a room, stop the events stream on this room
    if (peekingRoom)
    {
        [_room.mxSession stopPeeking:peekingRoom];
    }

    [self reset];
    
    self.eventFormatter = nil;
    
    eventsToProcess = nil;
    bubbles = nil;
    eventIdToBubbleMap = nil;

    [_timeline destroy];
    [_secondaryTimeline destroy];
    
    [super destroy];
}

- (void)didMXSessionStateChange
{
    if (MXSessionStateStoreDataReady <= self.mxSession.state)
    {
        if (USE_THREAD_TIMELINE)
        {
            if (_threadId)
            {
                [self initializeTimelineForThread];
            }
            else
            {
                [self initializeTimelineForRoom];
            }
        }
        else
        {
            [self initializeTimelineForRoom];
        }
    }
}

- (void)initializeTimelineForRoom
{
    // Check whether the room is not already set
    if (!_room)
    {
        // Are we peeking into a random room or displaying a room the user is part of?
        if (peekingRoom)
        {
            self.room = peekingRoom;
        }
        else
        {
            self.room = [self.mxSession roomWithRoomId:_roomId];
        }

        if (_room)
        {
            // This is the time to set up the timeline according to the called init method
            if (_isLive)
            {
                // LIVE
                MXWeakify(self);
                [_room liveTimeline:^(id<MXEventTimeline> liveTimeline) {
                    MXStrongifyAndReturnIfNil(self);

                    self->_timeline = liveTimeline;

                    // Only one pagination process can be done at a time by an MXRoom object.
                    // This assumption is satisfied by MatrixKit. Only MXRoomDataSource does it.
                    [self.timeline resetPagination];

                    // Observe room history flush (sync with limited timeline, or state event redaction)
                    self->roomDidFlushDataNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXRoomDidFlushDataNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {

                        MXRoom *room = notif.object;
                        if (self.mxSession == room.mxSession && ([self.roomId isEqualToString:room.roomId] ||
                                                                 ([self.secondaryRoomId isEqualToString:room.roomId])))
                        {
                            // The existing room history has been flushed during server sync because a gap has been observed between local and server storage.
                            [self reload];
                        }

                    }];

                    // Add the event listeners, by considering all the event types (the event filtering is applying by the event formatter),
                    // except if only the events with a url key in their content must be handled.
                    [self refreshEventListeners:(self.filterMessagesWithURL ? @[kMXEventTypeStringRoomMessage] : [MXKAppSettings standardAppSettings].allEventTypesForMessages)];

                    // display typing notifications is optional
                    // the inherited class can manage them by its own.
                    if (self.showTypingNotifications)
                    {
                        // Register on typing notif
                        [self listenTypingNotifications];
                    }

                    // Manage unsent messages
                    [self handleUnsentMessages];

                    // Update here data source state if it is not already ready
                    if (!self->_secondaryRoomId)
                    {
                        [self setState:MXKDataSourceStateReady];
                    }

                    // Check user membership in this room
                    MXMembership membership = self.room.summary.membership;
                    if (membership == MXMembershipUnknown || membership == MXMembershipInvite)
                    {
                        // Here the initial sync is not ended or the room is a pending invitation.
                        // Note: In case of invitation, a full sync will be triggered if the user joins this room.

                        // We have to observe here 'kMXRoomInitialSyncNotification' to reload room data when room sync is done.
                        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didMXRoomInitialSynced:) name:kMXRoomInitialSyncNotification object:self.room];
                    }
                }];
                
                if (!_secondaryRoom && _secondaryRoomId)
                {
                    _secondaryRoom = [self.mxSession roomWithRoomId:_secondaryRoomId];
                    
                    if (_secondaryRoom)
                    {
                        MXWeakify(self);
                        [_secondaryRoom liveTimeline:^(id<MXEventTimeline> liveTimeline) {
                            MXStrongifyAndReturnIfNil(self);

                            self->_secondaryTimeline = liveTimeline;

                            // Only one pagination process can be done at a time by an MXRoom object.
                            // This assumption is satisfied by MatrixKit. Only MXRoomDataSource does it.
                            [self.secondaryTimeline resetPagination];

                            // Add the secondary event listeners, by considering the event types in self.secondaryRoomEventTypes
                            [self refreshSecondaryEventListeners:self.secondaryRoomEventTypes];
                            
                            // Update here data source state if it is not already ready
                            [self setState:MXKDataSourceStateReady];

                            // Check user membership in the secondary room
                            MXMembership membership = self.secondaryRoom.summary.membership;
                            if (membership == MXMembershipUnknown || membership == MXMembershipInvite)
                            {
                                // Here the initial sync is not ended or the room is a pending invitation.
                                // Note: In case of invitation, a full sync will be triggered if the user joins this room.

                                // We have to observe here 'kMXRoomInitialSyncNotification' to reload room data when room sync is done.
                                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didMXRoomInitialSynced:) name:kMXRoomInitialSyncNotification object:self.secondaryRoom];
                            }
                        }];
                    }
                }
            }
            else
            {
                // Past timeline
                // Less things need to configured
                _timeline = [_room timelineOnEvent:initialEventId];

                // Refresh the event listeners. Note: events for past timelines come only from pagination request
                [self refreshEventListeners:nil];
                
                MXWeakify(self);

                // Preload the state and some messages around the initial event
                [_timeline resetPaginationAroundInitialEventWithLimit:_paginationLimitAroundInitialEvent success:^{

                    MXStrongifyAndReturnIfNil(self);
                    
                    // Do a "classic" reset. The room view controller will paginate
                    // from the events stored in the timeline store
                    [self.timeline resetPagination];
                    
                    // Update here data source state if it is not already ready
                    [self setState:MXKDataSourceStateReady];

                } failure:^(NSError *error) {
                    
                    MXStrongifyAndReturnIfNil(self);

                    MXLogDebug(@"[MXKRoomDataSource][%p] Failed to resetPaginationAroundInitialEventWithLimit", self);

                    // Notify the error
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceTimelineError
                                                                        object:self
                                                                      userInfo:@{
                                                                                 kMXKRoomDataSourceTimelineErrorErrorKey: error
                                                                                 }];
                }];
            }
        }
        else
        {
            MXLogDebug(@"[MXKRoomDataSource][%p] Warning: The user does not know the room %@", self, _roomId);
            
            // Update here data source state if it is not already ready
            [self setState:MXKDataSourceStateFailed];
        }
    }
}

- (void)initializeTimelineForThread
{
    // Check whether the thread is not already set
    if (_thread && self.state == MXKDataSourceStateReady)
    {
        return;
    }
    
    _thread = [self.mxSession.threadingService threadWithId:_threadId];
    
    if (!_thread)
    {
        //  there is not a thread yet available, this will be a new thread
        _thread = [self.mxSession.threadingService createTempThreadWithId:_threadId roomId:_roomId];
    }
    
    if (!_room)
    {
        //  also hold a reference to the room
        _room = [self.mxSession roomWithRoomId:_roomId];
    }
    
    if (_thread)
    {
        if (_isLive)
        {
            [_thread liveTimeline:^(id<MXEventTimeline> _Nonnull liveTimeline) {
                self->_timeline = liveTimeline;
                
                // Only one pagination process can be done at a time by an MXThread object.
                // This assumption is satisfied by MXRoomDataSource.
                [self.timeline resetPagination];
                
                // Add the event listeners, by considering all the event types (the event filtering is applying by the event formatter),
                // except if only the events with a url key in their content must be handled.
                [self refreshEventListeners:(self.filterMessagesWithURL ? @[kMXEventTypeStringRoomMessage] : [MXKAppSettings standardAppSettings].allEventTypesForMessages)];
                
                // Manage unsent messages
                [self handleUnsentMessages];
                
                [self setState:MXKDataSourceStateReady];
            }];
        }
        else
        {
            // Past timeline
            // Less things need to configured
            _timeline = [_thread timelineOnEvent:initialEventId];
            
            // Refresh the event listeners. Note: events for past timelines come only from pagination request
            [self refreshEventListeners:nil];
            
            MXWeakify(self);

            // Preload the state and some messages around the initial event
            [_timeline resetPaginationAroundInitialEventWithLimit:_paginationLimitAroundInitialEvent success:^{

                MXStrongifyAndReturnIfNil(self);
                
                // Do a "classic" reset. The room view controller will paginate
                // from the events stored in the timeline store
                [self.timeline resetPagination];
                
                // Update here data source state if it is not already ready
                [self setState:MXKDataSourceStateReady];

            } failure:^(NSError *error) {
                
                MXStrongifyAndReturnIfNil(self);

                MXLogDebug(@"[MXKRoomDataSource][%p] Failed to resetPaginationAroundInitialEventWithLimit", self);

                // Notify the error
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceTimelineError
                                                                    object:self
                                                                  userInfo:@{
                                                                      kMXKRoomDataSourceTimelineErrorErrorKey: error
                                                                  }];
            }];
        }
    }
    else
    {
        MXLogDebug(@"[MXKRoomDataSource][%p] Warning: The user does not know the thread %@", self, _threadId);
        
        // Update here data source state if it is not already ready
        [self setState:MXKDataSourceStateFailed];
    }
}

- (NSArray *)attachmentsWithThumbnail
{
    NSMutableArray *attachments = [NSMutableArray array];
    
    @synchronized(bubbles)
    {
        for (id<MXKRoomBubbleCellDataStoring> bubbleData in bubbles)
        {
            if (bubbleData.isAttachmentWithThumbnail && bubbleData.attachment.type != MXKAttachmentTypeSticker && !bubbleData.showAntivirusScanStatus)
            {
                [attachments addObject:bubbleData.attachment];
            }
        }
    }
    
    return attachments;
}

- (NSAttributedString *)partialAttributedTextMessage
{
    return _room.partialAttributedTextMessage;
}

- (void)setPartialAttributedTextMessage:(NSAttributedString *)partialAttributedTextMessage
{
    _room.partialAttributedTextMessage = partialAttributedTextMessage;
}

- (void)refreshEventListeners:(NSArray *)liveEventTypesFilterForMessages
{
    // Remove the existing listeners
    if (liveEventsListener)
    {
        [_timeline removeListener:liveEventsListener];
        [_timeline removeListener:redactionListener];
        [_timeline removeListener:receiptsListener];
    }

    // Listen to live events only for live timeline
    // Events for past timelines come only from pagination request
    if (_isLive)
    {
        // Register a new one with the requested filter
        MXWeakify(self);
        liveEventsListener = [_timeline listenToEventsOfTypes:liveEventTypesFilterForMessages onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {
            
            MXStrongifyAndReturnIfNil(self);

            if (MXTimelineDirectionForwards == direction)
            {
                if (event.eventType == MXEventTypeRoomMember && event.isUserProfileChange)
                {
                    [self refreshProfilesIfNeeded];
                }

                // Check for local echo suppression
                MXEvent *localEcho;
                if (self.room.outgoingMessages.count && [event.sender isEqualToString:self.mxSession.myUser.userId])
                {
                    localEcho = [self.room pendingLocalEchoRelatedToEvent:event];
                    if (localEcho)
                    {
                        // Check whether the local echo has a timestamp (in this case, it is replaced with the actual event).
                        if (localEcho.originServerTs != kMXUndefinedTimestamp)
                        {
                            // Replace the local echo by the true event sent by the homeserver
                            [self replaceEvent:localEcho withEvent:event];
                        }
                        else
                        {
                            // Remove the local echo, and process independently the true event.
                            [self replaceEvent:localEcho withEvent:nil];
                            localEcho = nil;
                        }
                    }
                }

                if (self.secondaryRoom)
                {
                    [self reloadNotifying:NO];
                }
                else if (nil == localEcho)
                {
                    // Process here incoming events, and outgoing events sent from another device.
                    if (self.threadId == nil && event.isInThread)
                    {
                        NSInteger index = [self indexOfCellDataWithEventId:event.relatesTo.eventId];
                        if (index != NSNotFound)
                        {
                            [self reloadNotifying:NO];
                        }
                    }
                    else
                    {
                        [self queueEventForProcessing:event withRoomState:roomState direction:MXTimelineDirectionForwards];
                        [self processQueuedEvents:nil];
                    }
                }
            }
        }];

        receiptsListener = [_timeline listenToEventsOfTypes:@[kMXEventTypeStringReceipt] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {

            if (MXTimelineDirectionForwards == direction)
            {
                // Handle this read receipt
                [self didReceiveReceiptEvent:event roomState:roomState];
            }
        }];
    }

    // Register a listener to handle redaction which can affect live and past timelines
    MXWeakify(self);
    redactionListener = [_timeline listenToEventsOfTypes:@[kMXEventTypeStringRoomRedaction] onEvent:^(MXEvent *redactionEvent, MXTimelineDirection direction, MXRoomState *roomState) {

        MXStrongifyAndReturnIfNil(self);

        // Consider only live redaction events
        if (direction == MXTimelineDirectionForwards)
        {
            // Do the processing on the processing queue
            dispatch_async(MXKRoomDataSource.processingQueue, ^{

                // Check whether a message contains the redacted event
                id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:redactionEvent.redacts];
                if (bubbleData)
                {
                    BOOL shouldRemoveBubbleData = NO;
                    BOOL hasChanged = NO;
                    MXEvent *redactedEvent = nil;

                    @synchronized (bubbleData)
                    {
                        // Retrieve the original event to redact it
                        NSArray *events = bubbleData.events;

                        for (MXEvent *event in events)
                        {
                            if ([event.eventId isEqualToString:redactionEvent.redacts])
                            {
                                // Check whether the event was not already redacted (Redaction may be handled by event timeline too).
                                if (!event.isRedactedEvent)
                                {
                                    redactedEvent = [event prune];
                                    redactedEvent.redactedBecause = redactionEvent.JSONDictionary;
                                }

                                break;
                            }
                        }

                        if (redactedEvent)
                        {
                            // Update bubble data
                            NSUInteger remainingEvents = [bubbleData updateEvent:redactionEvent.redacts withEvent:redactedEvent];

                            [self refreshRepliesWithUpdatedEventId:redactedEvent.eventId];

                            hasChanged = YES;

                            // Remove the bubble if there is no more events
                            shouldRemoveBubbleData = (remainingEvents == 0);
                        }
                    }

                    // Check whether the bubble should be removed
                    if (shouldRemoveBubbleData)
                    {
                        [self removeCellData:bubbleData];
                    }

                    if (hasChanged)
                    {
                        // Update the delegate on main thread
                        dispatch_async(dispatch_get_main_queue(), ^{

                            if (self.delegate)
                            {
                                [self.delegate dataSource:self didCellChange:nil];
                            }

                        });
                    }
                }

            });
        }
    }];
}

- (void)refreshSecondaryEventListeners:(NSArray *)liveEventTypesFilterForMessages
{
    // Remove the existing listeners
    if (secondaryLiveEventsListener)
    {
        [_secondaryTimeline removeListener:secondaryLiveEventsListener];
        [_secondaryTimeline removeListener:secondaryRedactionListener];
    }

    // Listen to live events only for live timeline
    // Events for past timelines come only from pagination request
    if (_isLive)
    {
        // Register a new one with the requested filter
        MXWeakify(self);
        secondaryLiveEventsListener = [_secondaryTimeline listenToEventsOfTypes:liveEventTypesFilterForMessages onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState) {
            
            MXStrongifyAndReturnIfNil(self);
            
            if (MXTimelineDirectionForwards == direction)
            {
                // Check for local echo suppression
                MXEvent *localEcho;
                if (self.secondaryRoom.outgoingMessages.count && [event.sender isEqualToString:self.mxSession.myUserId])
                {
                    localEcho = [self.secondaryRoom pendingLocalEchoRelatedToEvent:event];
                    if (localEcho)
                    {
                        // Check whether the local echo has a timestamp (in this case, it is replaced with the actual event).
                        if (localEcho.originServerTs != kMXUndefinedTimestamp)
                        {
                            // Replace the local echo by the true event sent by the homeserver
                            [self replaceEvent:localEcho withEvent:event];
                        }
                        else
                        {
                            // Remove the local echo, and process independently the true event.
                            [self replaceEvent:localEcho withEvent:nil];
                            localEcho = nil;
                        }
                    }
                }

                if (nil == localEcho)
                {
                    // Process here incoming events, and outgoing events sent from another device.
                    [self queueEventForProcessing:event withRoomState:roomState direction:MXTimelineDirectionForwards];
                    [self processQueuedEvents:nil];
                }
            }
        }];

    }

    // Register a listener to handle redaction which can affect live and past timelines
    secondaryRedactionListener = [_secondaryTimeline listenToEventsOfTypes:@[kMXEventTypeStringRoomRedaction] onEvent:^(MXEvent *redactionEvent, MXTimelineDirection direction, MXRoomState *roomState) {

        // Consider only live redaction events
        if (direction == MXTimelineDirectionForwards)
        {
            // Do the processing on the processing queue
            dispatch_async(MXKRoomDataSource.processingQueue, ^{

                // Check whether a message contains the redacted event
                id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:redactionEvent.redacts];
                if (bubbleData)
                {
                    BOOL shouldRemoveBubbleData = NO;
                    BOOL hasChanged = NO;
                    MXEvent *redactedEvent = nil;

                    @synchronized (bubbleData)
                    {
                        // Retrieve the original event to redact it
                        NSArray *events = bubbleData.events;

                        for (MXEvent *event in events)
                        {
                            if ([event.eventId isEqualToString:redactionEvent.redacts])
                            {
                                // Check whether the event was not already redacted (Redaction may be handled by event timeline too).
                                if (!event.isRedactedEvent)
                                {
                                    redactedEvent = [event prune];
                                    redactedEvent.redactedBecause = redactionEvent.JSONDictionary;
                                }

                                break;
                            }
                        }

                        if (redactedEvent)
                        {
                            // Update bubble data
                            NSUInteger remainingEvents = [bubbleData updateEvent:redactionEvent.redacts withEvent:redactedEvent];

                            hasChanged = YES;

                            // Remove the bubble if there is no more events
                            shouldRemoveBubbleData = (remainingEvents == 0);
                        }
                    }

                    // Check whether the bubble should be removed
                    if (shouldRemoveBubbleData)
                    {
                        [self removeCellData:bubbleData];
                    }

                    if (hasChanged)
                    {
                        // Update the delegate on main thread
                        dispatch_async(dispatch_get_main_queue(), ^{

                            if (self.delegate)
                            {
                                [self.delegate dataSource:self didCellChange:nil];
                            }

                        });
                    }
                }

            });
        }
    }];
}

- (void)setFilterMessagesWithURL:(BOOL)filterMessagesWithURL
{
    _filterMessagesWithURL = filterMessagesWithURL;
    
    if (_isLive && _room)
    {
        // Update the event listeners by considering the right types for the live events.
        [self refreshEventListeners:(_filterMessagesWithURL ? @[kMXEventTypeStringRoomMessage] : [MXKAppSettings standardAppSettings].allEventTypesForMessages)];
    }
}

- (void)setEventFormatter:(MXKEventFormatter *)eventFormatter
{
    if (_eventFormatter)
    {
        // Remove observers on previous event formatter settings
        [_eventFormatter.settings removeObserver:self forKeyPath:@"showRedactionsInRoomHistory"];
        [_eventFormatter.settings removeObserver:self forKeyPath:@"showUnsupportedEventsInRoomHistory"];
    }
    
    _eventFormatter = eventFormatter;
    
    if (_eventFormatter)
    {
        // Add observer to flush stored data on settings changes
        [_eventFormatter.settings  addObserver:self forKeyPath:@"showRedactionsInRoomHistory" options:0 context:nil];
        [_eventFormatter.settings  addObserver:self forKeyPath:@"showUnsupportedEventsInRoomHistory" options:0 context:nil];
    }
}

- (void)setShowBubblesDateTime:(BOOL)showBubblesDateTime
{
    _showBubblesDateTime = showBubblesDateTime;
    
    if (self.delegate)
    {
        // Reload all the table
        [self.delegate dataSource:self didCellChange:nil];
    }
}

- (void)setShowTypingNotifications:(BOOL)shouldShowTypingNotifications
{
    _showTypingNotifications = shouldShowTypingNotifications;
    
    if (shouldShowTypingNotifications)
    {
        // Register on typing notif
        [self listenTypingNotifications];
    }
    else
    {
        // Remove the live listener
        if (typingNotifListener)
        {
            [_timeline removeListener:typingNotifListener];
            currentTypingUsers = nil;
            typingNotifListener = nil;
        }
    }
}

- (void)listenTypingNotifications
{
    // Remove the previous live listener
    if (typingNotifListener)
    {
        [_timeline removeListener:typingNotifListener];
        currentTypingUsers = nil;
    }
    
    // Add typing notification listener
    MXWeakify(self);
    
    typingNotifListener = [_timeline listenToEventsOfTypes:@[kMXEventTypeStringTypingNotification] onEvent:^(MXEvent *event, MXTimelineDirection direction, MXRoomState *roomState)
    {
        MXStrongifyAndReturnIfNil(self);
        
        // Handle only live events
        if (direction == MXTimelineDirectionForwards)
        {
            // Retrieve typing users list
            NSMutableArray *typingUsers = [NSMutableArray arrayWithArray:self.room.typingUsers];

            // Remove typing info for the current user
            NSUInteger index = [typingUsers indexOfObject:self.mxSession.myUser.userId];
            if (index != NSNotFound)
            {
                [typingUsers removeObjectAtIndex:index];
            }
            // Ignore this notification if both arrays are empty
            if (self->currentTypingUsers.count || typingUsers.count)
            {
                self->currentTypingUsers = typingUsers;
                
                if (self.delegate)
                {
                    // refresh all the table
                    [self.delegate dataSource:self didCellChange:nil];
                }
            }
        }
    }];
    
    currentTypingUsers = _room.typingUsers;
}

- (void)cancelAllRequests
{
    if (paginationRequest)
    {
        // We have to remove here the listener. A new pagination request may be triggered whereas the cancellation of this one is in progress
        [_timeline removeListener:paginationListener];
        paginationListener = nil;
        
        [paginationRequest cancel];
        paginationRequest = nil;
    }
    
    [super cancelAllRequests];
}

- (void)setDelegate:(id<MXKDataSourceDelegate>)delegate
{
    super.delegate = delegate;
    
    // Register to MXScanManager notification only when a delegate is set
    if (delegate && self.mxSession.scanManager)
    {
        [self registerScanManagerNotifications];
    }

    // Register to reaction notification only when a delegate is set
    if (delegate)
    {
        [self registerReactionsChangeListener];
        [self registerEventEditsListener];
    }
}

- (void)setRoom:(MXRoom *)room
{
    if (![_room isEqual:room])
    {
        _room = room;
        
        [self roomDidSet];
    }
}

- (void)roomDidSet
{
    
}

- (BOOL)shouldQueueEventForProcessing:(MXEvent*)event roomState:(MXRoomState*)roomState direction:(MXTimelineDirection)direction
{
    if (self.filterMessagesWithURL)
    {
        // Check whether the event has a value for the 'url' key in its content.
        if (!event.getMediaURLs.count)
        {
            // ignore the event
            return NO;
        }
        
        // Ignore voice message related to an actual voice broadcast.
        if (event.content[VoiceBroadcastSettings.voiceBroadcastContentKeyChunkType] != nil) {
            return NO;
        }
    }
    
    // Check for undecryptable messages that were sent while the user was not in the room and hide them
    if ([MXKAppSettings standardAppSettings].hidePreJoinedUndecryptableEvents
        && direction == MXTimelineDirectionBackwards)
    {
        [self checkForPreJoinUTDWithEvent:event roomState:roomState];
        
        // Hide pre joint UTD events
        if (self.shouldStopBackPagination)
        {
            return NO;
        }
    }

    if (!USE_THREAD_TIMELINE && direction == MXTimelineDirectionBackwards && self.threadId)
    {
        //  when not using a thread timeline, data source will desperately fill the screen  with events by filtering them locally.
        //  we can stop when we see the thread root event when paginating backwards
        if ([event.eventId isEqualToString:self.threadId])
        {
            self.shouldStopBackPagination = YES;
        }
    }
    
    return YES;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([@"showRedactionsInRoomHistory" isEqualToString:keyPath] || [@"showUnsupportedEventsInRoomHistory" isEqualToString:keyPath])
    {
        // Flush the current bubble data and rebuild them
        [self reload];
    }
}

#pragma mark - Public methods
- (id<MXKRoomBubbleCellDataStoring>)cellDataAtIndex:(NSInteger)index
{
    id<MXKRoomBubbleCellDataStoring> bubbleData;
    @synchronized(bubbles)
    {
        if (index < bubbles.count)
        {
            bubbleData = bubbles[index];
        }
    }
    return bubbleData;
}

- (id<MXKRoomBubbleCellDataStoring>)cellDataOfEventWithEventId:(NSString *)eventId
{
    id<MXKRoomBubbleCellDataStoring> bubbleData;
    @synchronized(eventIdToBubbleMap)
    {
        bubbleData = eventIdToBubbleMap[eventId];
    }
    return bubbleData;
}

- (NSInteger)indexOfCellDataWithEventId:(NSString *)eventId
{
    NSInteger index = NSNotFound;
    
    id<MXKRoomBubbleCellDataStoring> bubbleData;
    @synchronized(eventIdToBubbleMap)
    {
        bubbleData = eventIdToBubbleMap[eventId];
    }
    
    if (bubbleData)
    {
        @synchronized(bubbles)
        {
            index = [bubbles indexOfObject:bubbleData];
        }
    }
    
    return index;
}

- (CGFloat)cellHeightAtIndex:(NSInteger)index withMaximumWidth:(CGFloat)maxWidth
{
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataAtIndex:index];
    
    // Sanity check
    if (bubbleData && self.delegate)
    {
        // Compute here height of bubble cell
        Class<MXKCellRendering> cellViewClass = [self.delegate cellViewClassForCellData:bubbleData];
        return [cellViewClass heightForCellData:bubbleData withMaximumWidth:maxWidth];
    }
    
    return 0;
}

- (void)invalidateBubblesCellDataCache
{
    @synchronized(bubbles)
    {
        for (id<MXKRoomBubbleCellDataStoring> bubble in bubbles)
        {
            [bubble invalidateTextLayout];
        }
    }
}

#pragma mark - Pagination
- (void)paginate:(NSUInteger)numItems direction:(MXTimelineDirection)direction onlyFromStore:(BOOL)onlyFromStore success:(void (^)(NSUInteger addedCellNumber))success failure:(void (^)(NSError *error))failure
{
    // Check the current data source state, and the actual user membership for this room.
    if (state != MXKDataSourceStateReady || ((self.room.summary.membership == MXMembershipUnknown || self.room.summary.membership == MXMembershipInvite) && ![self.roomState.historyVisibility isEqualToString:kMXRoomHistoryVisibilityWorldReadable]))
    {
        // Back pagination is not available here.
        if (failure)
        {
            failure(nil);
        }
        return;
    }
    
    if (paginationRequest || secondaryPaginationRequest)
    {
        MXLogDebug(@"[MXKRoomDataSource][%p] paginate: a pagination is already in progress", self);
        if (failure)
        {
            failure(nil);
        }
        return;
    }
    
    if (NO == [self canPaginate:direction])
    {
        MXLogDebug(@"[MXKRoomDataSource][%p] paginate: No more events to paginate", self);
        if (success)
        {
            success(0);
        }
    }
    
    __block NSUInteger addedCellNb = 0;
    __block NSMutableArray<NSError*> *operationErrors = [NSMutableArray arrayWithCapacity:2];
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    // Define a new listener for this pagination
    paginationListener = [_timeline listenToEventsOfTypes:(_filterMessagesWithURL ? @[kMXEventTypeStringRoomMessage] : [MXKAppSettings standardAppSettings].allEventTypesForMessages) onEvent:^(MXEvent *event, MXTimelineDirection direction2, MXRoomState *roomState) {
        
        if (direction2 == direction)
        {
            [self queueEventForProcessing:event withRoomState:roomState direction:direction];
        }
        
    }];
    
    // Keep a local reference to this listener.
    id localPaginationListenerRef = paginationListener;
    
    dispatch_group_enter(dispatchGroup);
    // Launch the pagination
    
    MXWeakify(self);
    paginationRequest = [_timeline paginate:numItems
                                  direction:direction
                              onlyFromStore:onlyFromStore
                                   complete:^{
        
        MXStrongifyAndReturnIfNil(self);
        
        // Everything went well, remove the listener
        self->paginationRequest = nil;
        [self.timeline removeListener:self->paginationListener];
        self->paginationListener = nil;
        
        // Once done, process retrieved events
        [self processQueuedEvents:^(NSUInteger addedHistoryCellNb, NSUInteger addedLiveCellNb) {
            
            addedCellNb += (direction == MXTimelineDirectionBackwards) ? addedHistoryCellNb : addedLiveCellNb;
            dispatch_group_leave(dispatchGroup);
            
        }];
        
    } failure:^(NSError *error) {
        
        MXLogDebug(@"[MXKRoomDataSource][%p] paginateBackMessages fails", self);
        
        MXStrongifyAndReturnIfNil(self);
        
        // Something wrong happened or the request was cancelled.
        // Check whether the request is the actual one before removing listener and handling the retrieved events.
        if (localPaginationListenerRef == self->paginationListener)
        {
            self->paginationRequest = nil;
            [self.timeline removeListener:self->paginationListener];
            self->paginationListener = nil;
            
            // Process at least events retrieved from store
            [self processQueuedEvents:^(NSUInteger addedHistoryCellNb, NSUInteger addedLiveCellNb) {
                
                [operationErrors addObject:error];
                if (addedHistoryCellNb)
                {
                    addedCellNb += addedHistoryCellNb;
                }
                dispatch_group_leave(dispatchGroup);

            }];
        }
        
    }];
    
    if (_secondaryTimeline)
    {
        // Define a new listener for this pagination
        secondaryPaginationListener = [_secondaryTimeline listenToEventsOfTypes:_secondaryRoomEventTypes onEvent:^(MXEvent *event, MXTimelineDirection direction2, MXRoomState *roomState) {
            
            if (direction2 == direction)
            {
                [self queueEventForProcessing:event withRoomState:roomState direction:direction];
            }
            
        }];
        
        // Keep a local reference to this listener.
        id localPaginationListenerRef = secondaryPaginationListener;
        
        dispatch_group_enter(dispatchGroup);
        // Launch the pagination
        MXWeakify(self);
        secondaryPaginationRequest = [_secondaryTimeline paginate:numItems
                                                        direction:direction
                                                    onlyFromStore:onlyFromStore
                                                         complete:^{
            
            MXStrongifyAndReturnIfNil(self);
            
            // Everything went well, remove the listener
            self->secondaryPaginationRequest = nil;
            [self.secondaryTimeline removeListener:self->secondaryPaginationListener];
            self->secondaryPaginationListener = nil;
            
            // Once done, process retrieved events
            [self processQueuedEvents:^(NSUInteger addedHistoryCellNb, NSUInteger addedLiveCellNb) {
                
                addedCellNb += (direction == MXTimelineDirectionBackwards) ? addedHistoryCellNb : addedLiveCellNb;
                dispatch_group_leave(dispatchGroup);

            }];
            
        } failure:^(NSError *error) {
            
            MXLogDebug(@"[MXKRoomDataSource][%p] paginateBackMessages fails", self);
            
            MXStrongifyAndReturnIfNil(self);
            
            // Something wrong happened or the request was cancelled.
            // Check whether the request is the actual one before removing listener and handling the retrieved events.
            if (localPaginationListenerRef == self->secondaryPaginationListener)
            {
                self->secondaryPaginationRequest = nil;
                [self.secondaryTimeline removeListener:self->secondaryPaginationListener];
                self->secondaryPaginationListener = nil;
                
                // Process at least events retrieved from store
                [self processQueuedEvents:^(NSUInteger addedHistoryCellNb, NSUInteger addedLiveCellNb) {
                    
                    [operationErrors addObject:error];
                    if (addedHistoryCellNb)
                    {
                        addedCellNb += addedHistoryCellNb;
                    }
                    dispatch_group_leave(dispatchGroup);

                }];
            }
            
        }];
    }
    
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
        if (operationErrors.count)
        {
            if (failure)
            {
                failure(operationErrors.firstObject);
            }
        }
        else
        {
            if (success)
            {
                success(addedCellNb);
            }
        }
    });
}

- (void)paginateToFillRect:(CGRect)rect direction:(MXTimelineDirection)direction withMinRequestMessagesCount:(NSUInteger)minRequestMessagesCount success:(void (^)(void))success failure:(void (^)(NSError *error))failure
{
    MXLogDebug(@"[MXKRoomDataSource][%p] paginateToFillRect: %@", self, NSStringFromCGRect(rect));
    
    // During the first call of this method, the delegate is supposed defined.
    // This delegate may be removed whereas this method is called by itself after a pagination request.
    // The delegate is required here to be able to compute cell height (and prevent infinite loop in case of reentrancy).
    if (!self.delegate)
    {
        MXLogDebug(@"[MXKRoomDataSource][%p] paginateToFillRect ignored (delegate is undefined)", self);
        if (failure)
        {
            failure(nil);
        }
        return;
    }

    // Get the total height of cells already loaded in memory
    CGFloat minMessageHeight = CGFLOAT_MAX;
    CGFloat bubblesTotalHeight = 0;

    @synchronized(bubbles)
    {
        // Check whether data has been aldready loaded
        if (bubbles.count)
        {
            NSUInteger eventsCount = 0;
            for (NSInteger i = bubbles.count - 1; i >= 0; i--)
            {
                id<MXKRoomBubbleCellDataStoring> bubbleData = bubbles[i];
                eventsCount += bubbleData.events.count;
                
                CGFloat bubbleHeight = [self cellHeightAtIndex:i withMaximumWidth:rect.size.width];
                // Sanity check
                if (bubbleHeight)
                {
                    bubblesTotalHeight += bubbleHeight;

                    if (bubblesTotalHeight > rect.size.height)
                    {
                        // No need to compute more cells heights, there are enough to fill the rect
                        MXLogDebug(@"[MXKRoomDataSource][%p] -> %tu already loaded bubbles (%tu events) are enough to fill the screen", self, bubbles.count - i, eventsCount);
                        break;
                    }
                    
                    // Compute the minimal height an event takes
                    minMessageHeight = MIN(minMessageHeight, bubbleHeight / bubbleData.events.count);
                }
            }
        }
        else if (minRequestMessagesCount && [self canPaginate:direction])
        {
            MXLogDebug(@"[MXKRoomDataSource][%p] paginateToFillRect: Prefill with data from the store", self);
            // Give a chance to load data from the store before doing homeserver requests
            // Reuse minRequestMessagesCount because we need to provide a number.
            [self paginate:minRequestMessagesCount direction:direction onlyFromStore:YES success:^(NSUInteger addedCellNumber) {

                // Then retry
                [self paginateToFillRect:rect direction:direction withMinRequestMessagesCount:minRequestMessagesCount success:success failure:failure];

            } failure:failure];
            return;
        }
    }
    
    // Is there enough cells to cover all the requested height?
    if (bubblesTotalHeight < rect.size.height)
    {
        // No. Paginate to get more messages
        if ([self canPaginate:direction])
        {
            // Bound the minimal height to 44
            minMessageHeight = MIN(minMessageHeight, 44);
            
            // Load messages to cover the remaining height
            // Use an extra of 50% to manage unsupported/unexpected/redated events
            NSUInteger messagesToLoad = ceil((rect.size.height - bubblesTotalHeight) / minMessageHeight * 1.5);

            // It does not worth to make a pagination request for only 1 message.
            // So, use minRequestMessagesCount
            messagesToLoad = MAX(messagesToLoad, minRequestMessagesCount);
            
            MXLogDebug(@"[MXKRoomDataSource][%p] paginateToFillRect: need to paginate %tu events to cover %fpx", self, messagesToLoad, rect.size.height - bubblesTotalHeight);
            [self paginate:messagesToLoad direction:direction onlyFromStore:NO success:^(NSUInteger addedCellNumber) {
                
                [self paginateToFillRect:rect direction:direction withMinRequestMessagesCount:minRequestMessagesCount success:success failure:failure];
                
            } failure:failure];
        }
        else
        {
            
            MXLogDebug(@"[MXKRoomDataSource][%p] paginateToFillRect: No more events to paginate", self);
            if (success)
            {
                success();
            }
        }
    }
    else
    {
        // Yes. Nothing to do
        if (success)
        {
            success();
        }
    }
}


#pragma mark - Sending
- (void)sendTextMessage:(NSString *)text success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    
    BOOL isEmote = [self isMessageAnEmote:text];
    NSString *sanitizedText = [self sanitizedMessageText:text];
    NSString *html = [self htmlMessageFromSanitizedText:sanitizedText];
    
    // Make the request to the homeserver
    if (isEmote)
    {
        [_room sendEmote:sanitizedText formattedText:html threadId:self.threadId localEcho:&localEchoEvent success:success failure:failure];
    }    
    else
    {
        [_room sendTextMessage:sanitizedText formattedText:html threadId:self.threadId localEcho:&localEchoEvent success:success failure:failure];
    }
    
    if (localEchoEvent)
    {
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)sendReplyToEvent:(MXEvent*)eventToReply
         withTextMessage:(NSString *)text
                 success:(void (^)(NSString *))success
                 failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    
    NSString *sanitizedText = [self sanitizedMessageText:text];
    NSString *html = [self htmlMessageFromSanitizedText:sanitizedText];
    
    id<MXSendReplyEventStringLocalizerProtocol> stringLocalizer = [MXKSendReplyEventStringLocalizer new];
    
    [_room sendReplyToEvent:eventToReply withTextMessage:sanitizedText formattedTextMessage:html stringLocalizer:stringLocalizer threadId:self.threadId localEcho:&localEchoEvent success:success failure:failure];
    
    if (localEchoEvent)
    {
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (BOOL)isMessageAnEmote:(NSString*)text
{
    return [text hasPrefix:emoteMessageSlashCommandPrefix];
}

- (NSString*)sanitizedMessageText:(NSString*)rawText
{
    NSString *text;
    
    //Remove NULL bytes from the string, as they are likely to trip up many things later,
    //including our own C-based Markdown-to-HTML convertor.
    //
    //Normally, we don't expect people to be entering NULL bytes in messages,
    //but because of a bug in iOS 11, it's easy to have it happen.
    //
    //iOS 11's Smart Punctuation feature "conveniently" converts double hyphens (`--`) to longer en-dashes (`—`).
    //However, when adding any kind of dash/hyphen after such an en-dash,
    //iOS would also insert a NULL byte inbetween the dashes (`<en-dash>NULL<some other dash>`).
    //
    //Even if a future iOS update fixes this,
    //we'd better be defensive and always remove occurrences of NULL bytes from text messages.
    text = [rawText stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%C", 0x00000000] withString:@""];
    
    // Check whether the message is an emote
    if ([self isMessageAnEmote:text])
    {
        // Remove "/me " string
        text = [text substringFromIndex:emoteMessageSlashCommandPrefix.length];
    }
    
    return text;
}

- (NSString*)htmlMessageFromSanitizedText:(NSString*)sanitizedText
{
    NSString *html;
    
    // Did user use Markdown text?
    NSString *htmlStringFromMarkdown = [_eventFormatter htmlStringFromMarkdownString:sanitizedText];
    
    if ([htmlStringFromMarkdown isEqualToString:sanitizedText])
    {
        // No formatted string
        html = nil;
    }
    else
    {
        html = htmlStringFromMarkdown;
    }
    
    return html;
}

- (void)sendImage:(UIImage *)image success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    // Make sure the uploaded image orientation is up
    image = [MXKTools forceImageOrientationUp:image];
    
    // Only jpeg image is supported here
    NSString *mimetype = @"image/jpeg";
    NSData *imageData = UIImageJPEGRepresentation(image, 0.9);
    
    // Shall we need to consider a thumbnail?
    UIImage *thumbnail = nil;
    if (_room.summary.isEncrypted)
    {
        // Thumbnail is useful only in case of encrypted room
        thumbnail = [MXKTools reduceImage:image toFitInSize:CGSizeMake(800, 600)];
        if (thumbnail == image)
        {
            thumbnail = nil;
        }
    }
    
    [self sendImageData:imageData withImageSize:image.size mimeType:mimetype andThumbnail:thumbnail success:success failure:failure];
}

- (BOOL)canReplyToEventWithId:(NSString*)eventIdToReply
{
    MXEvent *eventToReply = [self eventWithEventId:eventIdToReply];
    return [self.room canReplyToEvent:eventToReply];
}

- (void)sendImage:(NSData *)imageData mimeType:(NSString *)mimetype success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    UIImage *image = [UIImage imageWithData:imageData];
    
    // Shall we need to consider a thumbnail?
    UIImage *thumbnail = nil;
    if (_room.summary.isEncrypted)
    {
        // Thumbnail is useful only in case of encrypted room
        thumbnail = [MXKTools reduceImage:image toFitInSize:CGSizeMake(800, 600)];
        if (thumbnail == image)
        {
            thumbnail = nil;
        }
    }
    
    [self sendImageData:imageData withImageSize:image.size mimeType:mimetype andThumbnail:thumbnail success:success failure:failure];
}

- (void)sendImageData:(NSData*)imageData withImageSize:(CGSize)imageSize mimeType:(NSString*)mimetype andThumbnail:(UIImage*)thumbnail success:(void (^)(NSString *eventId))success failure:(void (^)(NSError *error))failure
{
    __block MXEvent *localEchoEvent = nil;
    
    [_room sendImage:imageData withImageSize:imageSize mimeType:mimetype andThumbnail:thumbnail threadId:self.threadId localEcho:&localEchoEvent success:success failure:failure];
    
    if (localEchoEvent)
    {
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)sendVideo:(NSURL *)videoLocalURL withThumbnail:(UIImage *)videoThumbnail success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    AVURLAsset *videoAsset = [AVURLAsset assetWithURL:videoLocalURL];
    [self sendVideoAsset:videoAsset withThumbnail:videoThumbnail success:success failure:failure];
}

- (void)sendVideoAsset:(AVAsset *)videoAsset withThumbnail:(UIImage *)videoThumbnail success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    
    [_room sendVideoAsset:videoAsset withThumbnail:videoThumbnail threadId:self.threadId localEcho:&localEchoEvent success:success failure:failure];
    
    if (localEchoEvent)
    {
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)sendAudioFile:(NSURL *)audioFileLocalURL mimeType:mimeType success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    
    [_room sendAudioFile:audioFileLocalURL mimeType:mimeType threadId:self.threadId localEcho:&localEchoEvent success:success failure:failure keepActualFilename:YES];
    
    if (localEchoEvent)
    {
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)sendVoiceMessage:(NSURL *)audioFileLocalURL
 additionalContentParams:(NSDictionary *)additionalContentParams
                mimeType:mimeType
                duration:(NSUInteger)duration
                 samples:(NSArray<NSNumber *> *)samples
                 success:(void (^)(NSString *))success
                 failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    
    [_room sendVoiceMessage:audioFileLocalURL additionalContentParams:additionalContentParams mimeType:mimeType duration:duration samples:samples threadId:self.threadId localEcho:&localEchoEvent success:success failure:failure keepActualFilename:YES];
    
    if (localEchoEvent)
    {
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}


- (void)sendFile:(NSURL *)fileLocalURL mimeType:(NSString*)mimeType success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    
    [_room sendFile:fileLocalURL mimeType:mimeType threadId:self.threadId localEcho:&localEchoEvent success:success failure:failure];
    
    if (localEchoEvent)
    {
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)sendMessageWithContent:(NSDictionary *)msgContent success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    
    // Make the request to the homeserver
    [_room sendMessageWithContent:msgContent threadId:self.threadId localEcho:&localEchoEvent success:success failure:failure];
    
    if (localEchoEvent)
    {
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)sendLocationWithLatitude:(double)latitude
                       longitude:(double)longitude
                     description:(NSString *)description
                  coordinateType:(MXEventAssetType)coordinateType
                         success:(void (^)(NSString *))success
                         failure:(void (^)(NSError *))failure
{
    __block MXEvent *localEchoEvent = nil;
    
    // Make the request to the homeserver
    [_room sendLocationWithLatitude:latitude
                          longitude:longitude
                        description:description
                           threadId:self.threadId
                          localEcho:&localEchoEvent
                          assetType:coordinateType
                            success:success failure:failure];
    
    if (localEchoEvent)
    {
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)sendEventOfType:(MXEventTypeString)eventTypeString content:(NSDictionary<NSString*, id>*)msgContent success:(void (^)(NSString *eventId))success failure:(void (^)(NSError *error))failure
{
    __block MXEvent *localEchoEvent = nil;

    // Make the request to the homeserver
    [_room sendEventOfType:eventTypeString content:msgContent threadId:self.threadId localEcho:&localEchoEvent success:success failure:failure];

    if (localEchoEvent)
    {
        // Make the data source digest this fake local echo message
        [self queueEventForProcessing:localEchoEvent withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        [self processQueuedEvents:nil];
    }
}

- (void)resendEventWithEventId:(NSString *)eventId success:(void (^)(NSString *))success failure:(void (^)(NSError *))failure
{
    MXEvent *event = [self eventWithEventId:eventId];
    
    // Sanity check
    if (!event)
    {
        return;
    }
    
    MXLogInfo(@"[MXKRoomDataSource][%p] resendEventWithEventId. EventId: %@", self, event.eventId);
    
    // Check first whether the event is encrypted
    if ([event.wireType isEqualToString:kMXEventTypeStringRoomEncrypted])
    {
        // We try here to resent an encrypted event
        // Note: we keep the existing local echo.
        [_room sendEventOfType:kMXEventTypeStringRoomEncrypted content:event.wireContent threadId:self.threadId localEcho:&event success:success failure:failure];
    }
    else if ([event.type isEqualToString:kMXEventTypeStringRoomMessage])
    {
        // And retry the send the message according to its type
        NSString *msgType = event.content[kMXMessageTypeKey];
        if ([msgType isEqualToString:kMXMessageTypeText] || [msgType isEqualToString:kMXMessageTypeEmote])
        {
            // Resend the Matrix event by reusing the existing echo
            [_room sendMessageWithContent:event.content threadId:self.threadId localEcho:&event success:success failure:failure];
        }
        else if ([msgType isEqualToString:kMXMessageTypeImage])
        {
            // Check whether the sending failed while uploading the data.
            // If the content url corresponds to a upload id, the upload was not complete.
            NSString *contentURL = event.content[@"url"];
            if (contentURL && [contentURL hasPrefix:kMXMediaUploadIdPrefix])
            {
                NSString *mimetype = nil;
                if (event.content[@"info"])
                {
                    mimetype = event.content[@"info"][@"mimetype"];
                }
                
                NSString *localImagePath = [MXMediaManager cachePathForMatrixContentURI:contentURL andType:mimetype inFolder:_roomId];
                UIImage* image = [MXMediaManager loadPictureFromFilePath:localImagePath];
                if (image)
                {
                    // Restart sending the image from the beginning.
                    
                    // Remove the local echo.
                    [self removeEventWithEventId:eventId];
                    
                    if (mimetype)
                    {
                        NSData *imageData = [NSData dataWithContentsOfFile:localImagePath];
                        [self sendImage:imageData mimeType:mimetype success:success failure:failure];
                    }
                    else
                    {
                        [self sendImage:image success:success failure:failure];
                    }
                }
                else
                {
                    if (failure)
                    {
                        failure([NSError errorWithDomain:MXKRoomDataSourceErrorDomain code:MXKRoomDataSourceErrorResendGeneric userInfo:nil]);
                    }
                    MXLogWarning(@"[MXKRoomDataSource][%p] resendEventWithEventId: Warning - Unable to resend room message of type: %@", self, msgType);
                }
            }
            else
            {
                // Resend the Matrix event by reusing the existing echo
                [_room sendMessageWithContent:event.content threadId:self.threadId localEcho:&event success:success failure:failure];
            }
        }
        else if ([msgType isEqualToString:kMXMessageTypeAudio])
        {
            // Check whether the sending failed while uploading the data.
            // If the content url corresponds to a upload id, the upload was not complete.
            NSString *contentURL = event.content[@"url"];
            if (!contentURL || ![contentURL hasPrefix:kMXMediaUploadIdPrefix])
            {
                // Resend the Matrix event by reusing the existing echo
                [_room sendMessageWithContent:event.content threadId:self.threadId localEcho:&event success:success failure:failure];
                return;
            }
            
            NSString *mimetype = event.content[@"info"][@"mimetype"];
            NSString *localFilePath = [MXMediaManager cachePathForMatrixContentURI:contentURL andType:mimetype inFolder:_roomId];
            NSURL *localFileURL = [NSURL URLWithString:localFilePath];
            
            if (![NSFileManager.defaultManager fileExistsAtPath:localFilePath]) {
                if (failure)
                {
                    failure([NSError errorWithDomain:MXKRoomDataSourceErrorDomain code:MXKRoomDataSourceErrorResendInvalidLocalFilePath userInfo:nil]);
                }
                MXLogWarning(@"[MXKRoomDataSource][%p] resendEventWithEventId: Warning - Unable to resend voice message, invalid file path.", self);
                return;
            }
            
            // Remove the local echo.
            [self removeEventWithEventId:eventId];
            
            if (event.isVoiceMessage) {
                // Voice message
                NSNumber *duration = event.content[kMXMessageContentKeyExtensibleAudioMSC1767][kMXMessageContentKeyExtensibleAudioDuration];
                NSArray<NSNumber *> *samples = event.content[kMXMessageContentKeyExtensibleAudioMSC1767][kMXMessageContentKeyExtensibleAudioWaveform];

                // Additional content params in case it is a voicebroacast chunk
                NSDictionary* additionalContentParams = nil;
                if (event.content[kMXEventRelationRelatesToKey] != nil && event.content[VoiceBroadcastSettings.voiceBroadcastContentKeyChunkType] != nil) {
                    additionalContentParams = @{
                        kMXEventRelationRelatesToKey: event.content[kMXEventRelationRelatesToKey],
                        VoiceBroadcastSettings.voiceBroadcastContentKeyChunkType: event.content[VoiceBroadcastSettings.voiceBroadcastContentKeyChunkType]
                    };
                }

                [self sendVoiceMessage:localFileURL additionalContentParams:additionalContentParams mimeType:mimetype duration:duration.doubleValue samples:samples success:success failure:failure];
            } else {
                [self sendAudioFile:localFileURL mimeType:mimetype success:success failure:failure];
            }
        }
        else if ([msgType isEqualToString:kMXMessageTypeVideo])
        {
            // Check whether the sending failed while uploading the data.
            // If the content url corresponds to a upload id, the upload was not complete.
            NSString *contentURL = event.content[@"url"];
            if (contentURL && [contentURL hasPrefix:kMXMediaUploadIdPrefix])
            {
                // TODO: Support resend on attached video when upload has been failed.
                MXLogDebug(@"[MXKRoomDataSource][%p] resendEventWithEventId: Warning - Unable to resend attached video (upload was not complete)", self);
                failure([NSError errorWithDomain:MXKRoomDataSourceErrorDomain code:MXKRoomDataSourceErrorResendInvalidMessageType userInfo:nil]);
            }
            else
            {
                // Resend the Matrix event by reusing the existing echo
                [_room sendMessageWithContent:event.content threadId:self.threadId localEcho:&event success:success failure:failure];
            }
        }
        else if ([msgType isEqualToString:kMXMessageTypeFile])
        {
            // Check whether the sending failed while uploading the data.
            // If the content url corresponds to a upload id, the upload was not complete.
            NSString *contentURL = event.content[@"url"];
            if (contentURL && [contentURL hasPrefix:kMXMediaUploadIdPrefix])
            {
                NSString *mimetype = nil;
                if (event.content[@"info"])
                {
                    mimetype = event.content[@"info"][@"mimetype"];
                }
                
                if (mimetype)
                {
                    // Restart sending the image from the beginning.
                    
                    // Remove the local echo
                    [self removeEventWithEventId:eventId];
                    
                    NSString *localFilePath = [MXMediaManager cachePathForMatrixContentURI:contentURL andType:mimetype inFolder:_roomId];
                    
                    [self sendFile:[NSURL fileURLWithPath:localFilePath isDirectory:NO] mimeType:mimetype success:success failure:failure];
                }
                else
                {
                    if (failure)
                    {
                        failure([NSError errorWithDomain:MXKRoomDataSourceErrorDomain code:MXKRoomDataSourceErrorResendGeneric userInfo:nil]);
                    }
                    MXLogWarning(@"[MXKRoomDataSource][%p] resendEventWithEventId: Warning - Unable to resend room message of type: %@", self, msgType);
                }
            }
            else
            {
                // Resend the Matrix event by reusing the existing echo
                [_room sendMessageWithContent:event.content threadId:self.threadId localEcho:&event success:success failure:failure];
            }
        }
        else
        {
            if (failure)
            {
                failure([NSError errorWithDomain:MXKRoomDataSourceErrorDomain code:MXKRoomDataSourceErrorResendInvalidMessageType userInfo:nil]);
            }
            MXLogWarning(@"[MXKRoomDataSource][%p] resendEventWithEventId: Warning - Unable to resend room message of type: %@", self, msgType);
        }
    }
    else
    {
        if (failure)
        {
            failure([NSError errorWithDomain:MXKRoomDataSourceErrorDomain code:MXKRoomDataSourceErrorResendInvalidMessageType userInfo:nil]);
        }
        MXLogWarning(@"[MXKRoomDataSource][%p] MXKRoomDataSource: Warning - Only resend of MXEventTypeRoomMessage is allowed. Event.type: %@", self, event.type);
    }
}


#pragma mark - Events management
- (MXEvent *)eventWithEventId:(NSString *)eventId
{
    MXEvent *theEvent;
    
    // First, retrieve the cell data hosting the event
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:eventId];
    if (bubbleData)
    {
        // Then look into the events in this cell
        for (MXEvent *event in bubbleData.events)
        {
            if ([event.eventId isEqualToString:eventId])
            {
                theEvent = event;
                break;
            }
        }
    }
    return theEvent;
}

- (void)removeEventWithEventId:(NSString *)eventId
{
    MXLogVerbose(@"[MXKRoomDataSource][%p] removeEventWithEventId: %@", self, eventId);
    
    // First, retrieve the cell data hosting the event
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:eventId];
    if (bubbleData)
    {
        NSUInteger remainingEvents;
        @synchronized (bubbleData)
        {
            remainingEvents = [bubbleData removeEvent:eventId];
        }
        
        // If there is no more events in the bubble, remove it
        if (0 == remainingEvents)
        {
            [self removeCellData:bubbleData];
        }

        // Remove the event from the outgoing messages storage
        [_room removeOutgoingMessage:eventId];
    
        // Update the delegate
        if (self.delegate)
        {
            [self.delegate dataSource:self didCellChange:nil];
        }
    }
}

- (void)didReceiveReceiptEvent:(MXEvent *)receiptEvent roomState:(MXRoomState *)roomState
{
    // Do the processing on the same processing queue
    MXWeakify(self);
    dispatch_async(MXKRoomDataSource.processingQueue, ^{
        MXStrongifyAndReturnIfNil(self);

        // Remove the previous displayed read receipt for each user who sent a
        // new read receipt.
        // To implement it, we need to find the sender id of each new read receipt
        // among the read receipts array of all events in all bubbles.
        NSArray *readReceiptSenders = receiptEvent.readReceiptSenders;

        @synchronized(self->bubbles)
        {
            for (MXKRoomBubbleCellData *cellData in self->bubbles)
            {
                NSMutableDictionary<NSString* /* eventId */, NSArray<MXReceiptData*> *> *updatedCellDataReadReceipts = [NSMutableDictionary dictionary];

                NSDictionary<NSString*, NSArray<MXReceiptData*>*> *readReceiptsCopy = [cellData.readReceipts mutableDeepCopy];
                for (NSString *eventId in readReceiptsCopy)
                {
                    for (MXReceiptData *receiptData in readReceiptsCopy[eventId])
                    {
                        for (NSString *senderId in readReceiptSenders)
                        {
                            if ([receiptData.userId isEqualToString:senderId])
                            {
                                if (!updatedCellDataReadReceipts[eventId])
                                {
                                    updatedCellDataReadReceipts[eventId] = readReceiptsCopy[eventId];
                                }

                                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userId!=%@", receiptData.userId];
                                updatedCellDataReadReceipts[eventId] = [updatedCellDataReadReceipts[eventId] filteredArrayUsingPredicate:predicate];
                                break;
                            }
                        }

                    }
                }

                // Flush found changed to the cell data
                for (NSString *eventId in updatedCellDataReadReceipts)
                {
                    if (updatedCellDataReadReceipts[eventId].count)
                    {
                        [self updateCellData:cellData withReadReceipts:updatedCellDataReadReceipts[eventId] forEventId:eventId];
                    }
                    else
                    {
                        [self updateCellData:cellData withReadReceipts:nil forEventId:eventId];
                    }
                }
            }
        }
        
        dispatch_group_t dispatchGroup = dispatch_group_create();

        // Update cell data we have received a read receipt for
        NSArray *readEventIds = receiptEvent.readReceiptEventIds;
        if (RiotSettings.shared.enableThreads)
        {
            NSArray *readThreadIds = receiptEvent.readReceiptThreadIds;
            for (int i = 0 ; i < readEventIds.count ; i++)
            {
                NSString *eventId = readEventIds[i];
                MXKRoomBubbleCellData *cellData = [self cellDataOfEventWithEventId:eventId];
                if (cellData)
                {
                    if ([readThreadIds[i] isEqualToString:kMXEventUnthreaded])
                    {
                        // Unthreaded RR must be propagated through all threads.
                        [self.mxSession.threadingService allThreadsInRoomWithId:self.roomId onlyParticipated:NO completion:^(NSArray<id<MXThreadProtocol>> *threads) {
                            NSMutableArray *threadIds = [NSMutableArray arrayWithObject:kMXEventTimelineMain];
                            for (id<MXThreadProtocol> thread in threads)
                            {
                                [threadIds addObject:thread.id];
                            }
                            
                            for (NSString *threadId in threadIds)
                            {
                                @synchronized(self->bubbles)
                                {
                                    dispatch_group_enter(dispatchGroup);
                                    [self addReadReceiptsForEvent:eventId threadId:threadId inCellDatas:self->bubbles startingAtCellData:cellData completion:^{
                                        dispatch_group_leave(dispatchGroup);
                                    }];
                                }
                            }
                        }];
                    }
                    else
                    {
                        NSString *threadId = readThreadIds[i];
                        @synchronized(self->bubbles)
                        {
                            dispatch_group_enter(dispatchGroup);
                            [self addReadReceiptsForEvent:eventId threadId:threadId inCellDatas:self->bubbles startingAtCellData:cellData completion:^{
                                dispatch_group_leave(dispatchGroup);
                            }];
                        }
                    }
                }
            }
        }
        else
        {
            // If
            for (NSString *eventId in readEventIds)
            {
                MXKRoomBubbleCellData *cellData = [self cellDataOfEventWithEventId:eventId];
                @synchronized(self->bubbles)
                {
                    dispatch_group_enter(dispatchGroup);
                    [self addReadReceiptsForEvent:eventId threadId:kMXEventTimelineMain inCellDatas:self->bubbles startingAtCellData:cellData completion:^{
                        dispatch_group_leave(dispatchGroup);
                    }];
                }
            }
        }

        dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
            if (self.delegate)
            {
                [self.delegate dataSource:self didCellChange:nil];
            }
        });
    });
}

- (void)updateCellData:(MXKRoomBubbleCellData*)cellData withReadReceipts:(NSArray<MXReceiptData*>*)readReceipts forEventId:(NSString*)eventId
{
    cellData.readReceipts[eventId] = readReceipts;
    
    // Indicate that the text message layout should be recomputed.
    [cellData invalidateTextLayout];
}

- (void)handleUnsentMessages
{
    // Add the unsent messages at the end of the conversation
    NSArray<MXEvent*>* outgoingMessages = _room.outgoingMessages;
    
    [self.mxSession decryptEvents:outgoingMessages inTimeline:nil onComplete:^(NSArray<MXEvent *> *failedEvents) {
        
        for (MXEvent *outgoingMessage in outgoingMessages)
        {
            [self queueEventForProcessing:outgoingMessage withRoomState:self.roomState direction:MXTimelineDirectionForwards];
        }
        
        MXLogVerbose(@"[MXKRoomDataSource][%p] handleUnsentMessages: queued %tu events", self, outgoingMessages.count);
        
        [self processQueuedEvents:nil];
    }];
}

#pragma mark - Bubble collapsing

- (void)collapseRoomBubble:(id<MXKRoomBubbleCellDataStoring>)bubbleData collapsed:(BOOL)collapsed
{
    if (bubbleData.collapsed != collapsed)
    {
        id<MXKRoomBubbleCellDataStoring> nextBubbleData = bubbleData;
        do
        {
            nextBubbleData.collapsed = collapsed;
        }
        while ((nextBubbleData = nextBubbleData.nextCollapsableCellData));

        if (self.delegate)
        {
            // Reload all the table
            [self.delegate dataSource:self didCellChange:nil];
        }
    }
}

#pragma mark - Private methods

- (void)replaceEvent:(MXEvent*)eventToReplace withEvent:(MXEvent*)event
{
    MXLogVerbose(@"[MXKRoomDataSource][%p] replaceEvent: %@ with: %@", self, eventToReplace.eventId, event.eventId);
    
    if (eventToReplace.isLocalEvent)
    {
        // Stop listening to the identifier change for the replaced event.
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidChangeIdentifierNotification object:eventToReplace];
    }
    
    // Retrieve the cell data hosting the replaced event
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:eventToReplace.eventId];
    if (!bubbleData)
    {
        return;
    }
    
    NSUInteger remainingEvents;
    @synchronized (bubbleData)
    {
        // Check whether the local echo is replaced or removed
        if (event)
        {
            remainingEvents = [bubbleData updateEvent:eventToReplace.eventId withEvent:event];
        }
        else
        {
            remainingEvents = [bubbleData removeEvent:eventToReplace.eventId];
        }
    }
    
    // Update bubbles mapping
    @synchronized (eventIdToBubbleMap)
    {
        // Remove the broken link from the map
        [eventIdToBubbleMap removeObjectForKey:eventToReplace.eventId];
        
        if (event && remainingEvents)
        {
            eventIdToBubbleMap[event.eventId] = bubbleData;
            
            if (event.isLocalEvent)
            {
                // Listen to the identifier change for the local events.
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localEventDidChangeIdentifier:) name:kMXEventDidChangeIdentifierNotification object:event];
            }
        }
    }
    
    // If there is no more events in the bubble, remove it
    if (0 == remainingEvents)
    {
        [self removeCellData:bubbleData];
    }

    // Update the delegate
    if (self.delegate)
    {
        [self.delegate dataSource:self didCellChange:nil];
    }
}

- (NSArray<NSIndexPath *> *)removeCellData:(id<MXKRoomBubbleCellDataStoring>)cellData
{
    NSMutableArray *deletedRows = [NSMutableArray array];
    
    MXLogVerbose(@"[MXKRoomDataSource][%p] removeCellData: %@", self, [cellData.events valueForKey:@"eventId"]);
    
    // Remove potential occurrences in bubble map
    @synchronized (eventIdToBubbleMap)
    {
        for (MXEvent *event in cellData.events)
        {
            [eventIdToBubbleMap removeObjectForKey:event.eventId];
            
            if (event.isLocalEvent)
            {
                // Stop listening to the identifier change for this event.
                [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidChangeIdentifierNotification object:event];
            }
        }
    }
    
    // Check whether the adjacent bubbles can merge together
    @synchronized(bubbles)
    {
        NSUInteger index = [bubbles indexOfObject:cellData];
        if (index != NSNotFound)
        {
            [bubbles removeObjectAtIndex:index];
            [deletedRows addObject:[NSIndexPath indexPathForRow:index inSection:0]];
            
            if (bubbles.count)
            {
                // Update flag in remaining data
                if (index == 0)
                {
                    // We removed here the first bubble.
                    // We have to update the 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags of the new first bubble.
                    id<MXKRoomBubbleCellDataStoring> firstCellData = bubbles.firstObject;
                    
                    firstCellData.isPaginationFirstBubble = ((self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay) && firstCellData.date);
                    
                    // Keep visible the sender information by default,
                    // except if the bubble has no display (composed only by ignored events).
                    firstCellData.shouldHideSenderInformation = firstCellData.hasNoDisplay;
                }
                else if (index < bubbles.count)
                {
                    // We removed here a bubble which is not the before last.
                    id<MXKRoomBubbleCellDataStoring> cellData1 = bubbles[index-1];
                    id<MXKRoomBubbleCellDataStoring> cellData2 = bubbles[index];
                    
                    // Check first whether the neighbor bubbles can merge
                    Class class = [self cellDataClassForCellIdentifier:kMXKRoomBubbleCellDataIdentifier];
                    if ([class instancesRespondToSelector:@selector(mergeWithBubbleCellData:)])
                    {
                        if ([cellData1 mergeWithBubbleCellData:cellData2])
                        {
                            [bubbles removeObjectAtIndex:index];
                            [deletedRows addObject:[NSIndexPath indexPathForRow:(index + 1) inSection:0]];
                            
                            cellData2 = nil;
                        }
                    }
                    
                    if (cellData2)
                    {
                        // Update its 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags
                        
                        // Pagination handling
                        if (self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay && !cellData2.isPaginationFirstBubble)
                        {
                            // Check whether a new pagination starts on the second cellData
                            NSString *cellData1DateString = [self.eventFormatter dateStringFromDate:cellData1.date withTime:NO];
                            NSString *cellData2DateString = [self.eventFormatter dateStringFromDate:cellData2.date withTime:NO];
                            
                            if (!cellData1DateString)
                            {
                                cellData2.isPaginationFirstBubble = (cellData2DateString && cellData.isPaginationFirstBubble);
                            }
                            else
                            {
                                cellData2.isPaginationFirstBubble = (cellData2DateString && ![cellData2DateString isEqualToString:cellData1DateString]);
                            }
                        }
                        
                        // Check whether the sender information is relevant for this bubble.
                        // Check first if the bubble is not composed only by ignored events.
                        cellData2.shouldHideSenderInformation = cellData2.hasNoDisplay;
                        if (!cellData2.shouldHideSenderInformation && cellData2.isPaginationFirstBubble == NO)
                        {
                            // Check whether the neighbor bubbles have been sent by the same user.
                            cellData2.shouldHideSenderInformation = [cellData2 hasSameSenderAsBubbleCellData:cellData1];
                        }
                    }

                }
            }
        }
    }
    
    return deletedRows;
}

- (void)didMXRoomInitialSynced:(NSNotification *)notif
{
    // Refresh the room data source when the room has been initialSync'ed
    MXRoom *room = notif.object;
    if (self.mxSession == room.mxSession &&
        ([self.roomId isEqualToString:room.roomId] || [self.secondaryRoomId isEqualToString:room.roomId]))
    { 
        MXLogDebug(@"[MXKRoomDataSource][%p] didMXRoomInitialSynced for room: %@", self, room.roomId);
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXRoomInitialSyncNotification object:room];
        
        [self reload];
    }
}

- (void)eventDidChangeSentState:(NSNotification *)notif
{
    MXEvent *event = notif.object;
    if ([event.roomId isEqualToString:_roomId])
    {
        MXLogVerbose(@"[MXKRoomDataSource][%p] eventDidChangeSentState: %@, to: %tu", self, event.eventId, event.sentState);
        
        // Retrieve the cell data hosting the local echo
        id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:event.eventId];
        if (!bubbleData)
        {
            //  Initial state for local echos
            BOOL isInitial = event.isLocalEvent &&
                (event.sentState == MXEventSentStateSending || event.sentState == MXEventSentStateEncrypting);
            if (!isInitial)
            {
                MXLogWarning(@"[MXKRoomDataSource][%p] eventDidChangeSentState: Cannot find bubble data for event: %@", self, event.eventId);
            }
            return;
        }
        
        @synchronized (bubbleData)
        {
            [bubbleData updateEvent:event.eventId withEvent:event];
        }
        
        // Inform the delegate
        if (self.delegate && (self.secondaryRoom ? bubbles.count > 0 : YES))
        {
            [self.delegate dataSource:self didCellChange:nil];
        }
    }
}

- (void)localEventDidChangeIdentifier:(NSNotification *)notif
{
    MXEvent *event = notif.object;
    NSString *previousId = notif.userInfo[kMXEventIdentifierKey];
    
    MXLogVerbose(@"[MXKRoomDataSource][%p] localEventDidChangeIdentifier from: %@ to: %@", self, previousId, event.eventId);
    
    if (event && previousId)
    {
        // Update bubbles mapping
        @synchronized (eventIdToBubbleMap)
        {
            id<MXKRoomBubbleCellDataStoring> bubbleData = eventIdToBubbleMap[previousId];
            if (bubbleData && event.eventId)
            {
                eventIdToBubbleMap[event.eventId] = bubbleData;
                [eventIdToBubbleMap removeObjectForKey:previousId];

                // The bubble data must use the final event id too
                [bubbleData updateEvent:previousId withEvent:event];
            }
        }
        
        if (!event.isLocalEvent)
        {
            // Stop listening to the identifier change when the event becomes an actual event.
            [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXEventDidChangeIdentifierNotification object:event];
        }
    }
}

- (void)eventDidDecrypt:(NSNotification *)notif
{
    MXEvent *event = notif.object;
    if ([event.roomId isEqualToString:_roomId] ||
        ([event.roomId isEqualToString:_secondaryRoomId] && [_secondaryRoomEventTypes containsObject:event.type]))
    {
        // Retrieve the cell data hosting the event
        id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:event.eventId];
        if (!bubbleData)
        {
            return;
        }

        // We need to update the data of the cell that displays the event.
        // The trickiest update is when the cell contains several events and the event
        // to update turns out to be an attachment.
        // In this case, we need to split the cell into several cells so that the attachment
        // has its own cell.
        if (bubbleData.events.count == 1 || ![_eventFormatter isSupportedAttachment:event])
        {
            // If the event is still a text, a simple update is enough
            // If the event is an attachment, it has already its own cell. Let the bubble
            // data handle the type change.
            @synchronized (bubbleData)
            {
                [bubbleData updateEvent:event.eventId withEvent:event];
            }
        }
        else
        {
            @synchronized (bubbleData)
            {
                BOOL eventIsFirstInBubble = NO;
                NSInteger bubbleDataIndex =  [bubbles indexOfObject:bubbleData];
                
                if (NSNotFound == bubbleDataIndex)
                {
                    // If bubbleData is not in bubbles there is nothing to update for this event, its not displayed.
                    return;
                }

                // We need to create a dedicated cell for the event attachment.
                // From the current bubble, remove the updated event and all events after.
                NSMutableArray<MXEvent*> *removedEvents;
                NSUInteger remainingEvents = [bubbleData removeEventsFromEvent:event.eventId removedEvents:&removedEvents];

                // If there is no more events in this bubble, remove it
                if (0 == remainingEvents)
                {
                    eventIsFirstInBubble = YES;
                    @synchronized (eventsToProcessSnapshot)
                    {
                        [bubbles removeObjectAtIndex:bubbleDataIndex];
                        bubbleDataIndex--;
                    }
                }

                // Create a dedicated bubble for the attachment
                if (removedEvents.count)
                {
                    Class class = [self cellDataClassForCellIdentifier:kMXKRoomBubbleCellDataIdentifier];

                    id<MXKRoomBubbleCellDataStoring> newBubbleData = [[class alloc] initWithEvent:removedEvents[0] andRoomState:self.roomState andRoomDataSource:self];

                    if (eventIsFirstInBubble)
                    {
                        // Apply same config as before
                        newBubbleData.isPaginationFirstBubble = bubbleData.isPaginationFirstBubble;
                        newBubbleData.shouldHideSenderInformation = bubbleData.shouldHideSenderInformation;
                    }
                    else
                    {
                        // This new bubble is not the first. Show nothing
                        newBubbleData.isPaginationFirstBubble = NO;
                        newBubbleData.shouldHideSenderInformation = YES;
                    }

                    // Update bubbles mapping
                    @synchronized (eventIdToBubbleMap)
                    {
                        eventIdToBubbleMap[event.eventId] = newBubbleData;
                    }

                    @synchronized (eventsToProcessSnapshot)
                    {
                        [bubbles insertObject:newBubbleData atIndex:bubbleDataIndex + 1];
                    }
                }

                // And put other cutted events in another bubble
                if (removedEvents.count > 1)
                {
                    Class class = [self cellDataClassForCellIdentifier:kMXKRoomBubbleCellDataIdentifier];

                    id<MXKRoomBubbleCellDataStoring> newBubbleData;
                    for (NSUInteger i = 1; i < removedEvents.count; i++)
                    {
                        MXEvent *removedEvent = removedEvents[i];
                        if (i == 1)
                        {
                            newBubbleData = [[class alloc] initWithEvent:removedEvent andRoomState:self.roomState andRoomDataSource:self];
                        }
                        else
                        {
                            [newBubbleData addEvent:removedEvent andRoomState:self.roomState];
                        }

                        // Update bubbles mapping
                        @synchronized (eventIdToBubbleMap)
                        {
                            eventIdToBubbleMap[removedEvent.eventId] = newBubbleData;
                        }
                    }

                    // Do not show the
                    newBubbleData.isPaginationFirstBubble = NO;
                    newBubbleData.shouldHideSenderInformation = YES;

                    @synchronized (eventsToProcessSnapshot)
                    {
                        [bubbles insertObject:newBubbleData atIndex:bubbleDataIndex + 2];
                    }
                }
            }
        }

        // Update the delegate
        if (self.delegate)
        {
            [self.delegate dataSource:self didCellChange:nil];
        }
    }
}

// Indicates whether an event has base requirements to allow actions (like reply, reactions, edit, etc.)
- (BOOL)canPerformActionOnEvent:(MXEvent*)event
{
    BOOL isSent = event.sentState == MXEventSentStateSent;
    
    if (!isSent) {
        return NO;
    }
    
    if (event.isTimelinePollEvent) {
        return YES;
    }
    
    // Specific case for voice broadcast event
    if (event.eventType == MXEventTypeCustom &&
        [event.type isEqualToString:VoiceBroadcastSettings.voiceBroadcastInfoContentKeyType]) {
        
        // Ensures that we only support reactions for a start event
        VoiceBroadcastInfo* voiceBroadcastInfo = [VoiceBroadcastInfo modelFromJSON: event.content];
        if ([VoiceBroadcastInfo isStartedFor: voiceBroadcastInfo.state]) {
            return YES;
        }
    }
    
    BOOL isRoomMessage = (event.eventType == MXEventTypeRoomMessage);
    
    if (!isRoomMessage) {
        return NO;
    }
    
    NSString *messageType = event.content[kMXMessageTypeKey];
    if (messageType == nil || [messageType isEqualToString:@"m.bad.encrypted"]) {
        return NO;
    }
    
    return YES;
}

- (void)setState:(MXKDataSourceState)newState
{
    if (self->state != newState)
    {
        self->state = newState;

        if (self.delegate && [self.delegate respondsToSelector:@selector(dataSource:didStateChange:)])
        {
            [self.delegate dataSource:self didStateChange:self->state];
        }
    }
}

- (void)setSecondaryRoomId:(NSString *)secondaryRoomId
{
    if (_secondaryRoomId != secondaryRoomId)
    {
        _secondaryRoomId = secondaryRoomId;
        
        if (self.state == MXKDataSourceStateReady)
        {
            [self reload];
        }
    }
}

- (void)setSecondaryRoomEventTypes:(NSArray<MXEventTypeString> *)secondaryRoomEventTypes
{
    if (_secondaryRoomEventTypes != secondaryRoomEventTypes)
    {
        _secondaryRoomEventTypes = secondaryRoomEventTypes;
        
        if (self.state == MXKDataSourceStateReady)
        {
            [self reload];
        }
    }
}

#pragma mark - Asynchronous events processing
 + (dispatch_queue_t)processingQueue
{
    static dispatch_queue_t processingQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        processingQueue = dispatch_queue_create("MXKRoomDataSource", DISPATCH_QUEUE_SERIAL);
    });

    return processingQueue;
}

- (void)queueEventForProcessing:(MXEvent*)event withRoomState:(MXRoomState*)roomState direction:(MXTimelineDirection)direction
{
    if (event.isLocalEvent)
    {
        MXLogVerbose(@"[MXKRoomDataSource][%p] queueEventForProcessing: %@", self, event.eventId);
    }
    
    if (![self shouldQueueEventForProcessing:event roomState:roomState direction:direction])
    {
        return;
    }
    
    MXKQueuedEvent *queuedEvent = [[MXKQueuedEvent alloc] initWithEvent:event andRoomState:roomState direction:direction];
    
    // Count queued events when the server sync is in progress
    if (self.mxSession.state == MXSessionStateSyncInProgress)
    {
        queuedEvent.serverSyncEvent = YES;
        _serverSyncEventCount++;
        
        if (_serverSyncEventCount == 1)
        {
            // Notify that sync process starts
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceSyncStatusChanged object:self userInfo:nil];
        }
    }
    
    @synchronized(eventsToProcess)
    {
        [eventsToProcess addObject:queuedEvent];
        
        if (self.secondaryRoom)
        {
            //  use a stable sorting here, which means it won't change the order of events unless it has to.
            [eventsToProcess sortWithOptions:NSSortStable
                             usingComparator:^NSComparisonResult(MXKQueuedEvent * _Nonnull event1, MXKQueuedEvent * _Nonnull event2) {
                return [event2.eventDate compare:event1.eventDate];
            }];
        }
    }
}

- (BOOL)canPaginate:(MXTimelineDirection)direction
{
    if (_secondaryTimeline)
    {
        if (![_timeline canPaginate:direction] && ![_secondaryTimeline canPaginate:direction])
        {
            return NO;
        }
    }
    else
    {
        if (![_timeline canPaginate:direction])
        {
            return NO;
        }
    }
    
    if (direction == MXTimelineDirectionBackwards && self.shouldStopBackPagination)
    {
        return NO;
    }
    
    return YES;
}

// Check for undecryptable messages that were sent while the user was not in the room.
- (void)checkForPreJoinUTDWithEvent:(MXEvent*)event roomState:(MXRoomState*)roomState
{
    // Only check for encrypted rooms
    if (!self.room.summary.isEncrypted)
    {
        return;
    }
    
    // Back pagination is stopped do not check for other pre join events
    if (self.shouldStopBackPagination)
    {
        return;
    }
    
    // if we reach a UTD and flag is set, hide previous encrypted messages and stop back-paginating
    if (event.eventType == MXEventTypeRoomEncrypted
        && [event.decryptionError.domain isEqualToString:MXDecryptingErrorDomain]
        && self.shouldPreventBackPaginationOnPreviousUTDEvent)
    {
        self.shouldStopBackPagination = YES;
        return;
    }
    
    self.shouldStopBackPagination = NO;
    
    if (event.eventType != MXEventTypeRoomMember)
    {
        return;
    }
    
    NSString *userId = event.stateKey;
    
    // Only check "m.room.member" event for current user
    if (![userId isEqualToString:self.mxSession.myUserId])
    {
        return;
    }
    
    BOOL shouldPreventBackPaginationOnPreviousUTDEvent = NO;
    
    MXRoomMember *member = [roomState.members memberWithUserId:userId];
    
    if (member)
    {
        switch (member.membership) {
            case MXMembershipJoin:
            {
                // if we reach a join event for the user:
                //  - if prev-content is invite, continue back-paginating
                //  - if prev-content is join (was just an avatar or displayname change), continue back-paginating
                //  - otherwise, set a flag and continue back-paginating
                
                NSString *previousMemberhsip = event.prevContent[@"membership"];
                
                BOOL isPrevContentAnInvite = [previousMemberhsip isEqualToString:@"invite"];
                BOOL isPrevContentAJoin = [previousMemberhsip isEqualToString:@"join"];
                
                if (!(isPrevContentAnInvite || isPrevContentAJoin))
                {
                    shouldPreventBackPaginationOnPreviousUTDEvent = YES;
                }
            }
                break;
            case MXMembershipInvite:
                // if we reach an invite event for the user, set flag and continue back-paginating
                shouldPreventBackPaginationOnPreviousUTDEvent = YES;
                break;
            default:
                break;
        }
    }
    
    self.shouldPreventBackPaginationOnPreviousUTDEvent = shouldPreventBackPaginationOnPreviousUTDEvent;
}

- (BOOL)checkBing:(MXEvent*)event
{
    BOOL isHighlighted = NO;
    
    // read receipts have no rule
    if (![event.type isEqualToString:kMXEventTypeStringReceipt]) {
        // Check if we should bing this event
        MXPushRule *rule = [self.mxSession.notificationCenter ruleMatchingEvent:event roomState:self.roomState];
        if (rule)
        {
            // Check whether is there an highlight tweak on it
            for (MXPushRuleAction *ruleAction in rule.actions)
            {
                if (ruleAction.actionType == MXPushRuleActionTypeSetTweak)
                {
                    if ([ruleAction.parameters[@"set_tweak"] isEqualToString:@"highlight"])
                    {
                        // Check the highlight tweak "value"
                        // If not present, highlight. Else check its value before highlighting
                        if (nil == ruleAction.parameters[@"value"] || YES == [ruleAction.parameters[@"value"] boolValue])
                        {
                            isHighlighted = YES;
                            break;
                        }
                    }
                }
            }
        }
    }
    
    event.mxkIsHighlighted = isHighlighted;
    return isHighlighted;
}

- (void)processQueuedEvents:(void (^)(NSUInteger addedHistoryCellNb, NSUInteger addedLiveCellNb))onComplete
{
    MXWeakify(self);
    
    // Do the processing on the processing queue
    dispatch_async(MXKRoomDataSource.processingQueue, ^{
        
        MXStrongifyAndReturnIfNil(self);
        
        // Note: As this block is always called from the same processing queue,
        // only one batch process is done at a time. Thus, an event cannot be
        // processed twice
        
        // Snapshot queued events to avoid too long lock.
        @synchronized(self->eventsToProcess)
        {
            if (self->eventsToProcess.count)
            {
                self->eventsToProcessSnapshot = self->eventsToProcess;
                if (self.secondaryRoom)
                {
                    @synchronized(self->bubbles)
                    {
                        [self->bubblesSnapshot removeAllObjects];
                    }
                }
                else
                {
                    self->eventsToProcess = [NSMutableArray array];
                }
            }
        }

        NSUInteger serverSyncEventCount = 0;
        NSUInteger addedHistoryCellCount = 0;
        NSUInteger addedLiveCellCount = 0;
        
        dispatch_group_t dispatchGroup = dispatch_group_create();

        // Lock on `eventsToProcessSnapshot` to suspend reload or destroy during the process.
        @synchronized(self->eventsToProcessSnapshot)
        {
            // Is there events to process?
            // The list can be empty because several calls of processQueuedEvents may be processed
            // in one pass in the processingQueue
            if (self->eventsToProcessSnapshot.count)
            {
                // Make a quick copy of changing data to avoid to lock it too long time
                @synchronized(self->bubbles)
                {
                    self->bubblesSnapshot = [self->bubbles mutableCopy];
                }

                NSMutableSet<id<MXKRoomBubbleCellDataStoring>> *collapsingCellDataSeriess = [NSMutableSet set];

                for (MXKQueuedEvent *queuedEvent in self->eventsToProcessSnapshot)
                {
                    @synchronized (self->eventIdToBubbleMap)
                    {
                        //  Check whether the event processed before
                        if (self->eventIdToBubbleMap[queuedEvent.event.eventId])
                        {
                            MXLogVerbose(@"[MXKRoomDataSource][%p] processQueuedEvents: Skip event: %@, state: %tu", self, queuedEvent.event.eventId, queuedEvent.event.sentState);
                            continue;
                        }
                    }
                    
                    @autoreleasepool
                    {
                        // Count events received while the server sync was in progress
                        if (queuedEvent.serverSyncEvent)
                        {
                            serverSyncEventCount ++;
                        }

                        // Check whether the event must be highlighted
                        [self checkBing:queuedEvent.event];

                        // Retrieve the MXKCellData class to manage the data
                        Class class = [self cellDataClassForCellIdentifier:kMXKRoomBubbleCellDataIdentifier];
                        NSAssert([class conformsToProtocol:@protocol(MXKRoomBubbleCellDataStoring)], @"MXKRoomDataSource only manages MXKCellData that conforms to MXKRoomBubbleCellDataStoring protocol");

                        BOOL eventManaged = NO;
                        BOOL updatedBubbleDataHadNoDisplay = NO;
                        id<MXKRoomBubbleCellDataStoring> bubbleData;
                        if ([class instancesRespondToSelector:@selector(addEvent:andRoomState:)] && 0 < self->bubblesSnapshot.count)
                        {
                            // Try to concatenate the event to the last or the oldest bubble?
                            if (queuedEvent.direction == MXTimelineDirectionBackwards)
                            {
                                bubbleData = self->bubblesSnapshot.firstObject;
                            }
                            else
                            {
                                bubbleData = self->bubblesSnapshot.lastObject;
                            }

                            @synchronized (bubbleData)
                            {
                                updatedBubbleDataHadNoDisplay = bubbleData.hasNoDisplay;
                                eventManaged = [bubbleData addEvent:queuedEvent.event andRoomState:queuedEvent.state];
                            }
                        }

                        if (NO == eventManaged)
                        {
                            // The event has not been concatenated to an existing cell, create a new bubble for this event
                            bubbleData = [[class alloc] initWithEvent:queuedEvent.event andRoomState:queuedEvent.state andRoomDataSource:self];
                            if (!bubbleData)
                            {
                                // The event is ignored
                                continue;
                            }

                            // Check cells collapsing
                            if (bubbleData.hasAttributedTextMessage)
                            {
                                if (bubbleData.collapsable)
                                {
                                    if (queuedEvent.direction == MXTimelineDirectionBackwards)
                                    {
                                        // Try to collapse it with the series at the start of self.bubbles
                                        if (self->collapsableSeriesAtStart && [self->collapsableSeriesAtStart collapseWith:bubbleData])
                                        {
                                            // bubbleData becomes the oldest cell data of the current series
                                            self->collapsableSeriesAtStart.prevCollapsableCellData = bubbleData;
                                            bubbleData.nextCollapsableCellData = self->collapsableSeriesAtStart;

                                            // The new cell must have the collapsed state as the series
                                            bubbleData.collapsed = self->collapsableSeriesAtStart.collapsed;

                                            // Release data of the previous header
                                            self->collapsableSeriesAtStart.collapseState = nil;
                                            self->collapsableSeriesAtStart.collapsedAttributedTextMessage = nil;
                                            [collapsingCellDataSeriess removeObject:self->collapsableSeriesAtStart];

                                            // And keep a ref of data for the new start of the series
                                            self->collapsableSeriesAtStart = bubbleData;
                                            self->collapsableSeriesAtStart.collapseState = queuedEvent.state;
                                            [collapsingCellDataSeriess addObject:self->collapsableSeriesAtStart];
                                        }
                                        else
                                        {
                                            // This is a ending point for a new collapsable series of cells
                                            self->collapsableSeriesAtStart = bubbleData;
                                            self->collapsableSeriesAtStart.collapseState = queuedEvent.state;
                                            [collapsingCellDataSeriess addObject:self->collapsableSeriesAtStart];
                                        }
                                    }
                                    else
                                    {
                                        // Try to collapse it with the series at the end of self.bubbles
                                        if (self->collapsableSeriesAtEnd && [self->collapsableSeriesAtEnd collapseWith:bubbleData])
                                        {
                                            // Put bubbleData at the series tail
                                            // Find the tail
                                            id<MXKRoomBubbleCellDataStoring> tailBubbleData = self->collapsableSeriesAtEnd;
                                            while (tailBubbleData.nextCollapsableCellData)
                                            {
                                                tailBubbleData = tailBubbleData.nextCollapsableCellData;
                                            }

                                            tailBubbleData.nextCollapsableCellData = bubbleData;
                                            bubbleData.prevCollapsableCellData = tailBubbleData;

                                            // The new cell must have the collapsed state as the series
                                            bubbleData.collapsed = tailBubbleData.collapsed;

                                            // If the start of the collapsible series stems from an event in a different processing
                                            // batch, we need to track it here so that we can update the summary string later
                                            if (![collapsingCellDataSeriess containsObject:self->collapsableSeriesAtEnd]) {
                                                [collapsingCellDataSeriess addObject:self->collapsableSeriesAtEnd];
                                            }
                                        }
                                        else
                                        {
                                            // This is a starting point for a new collapsable series of cells
                                            self->collapsableSeriesAtEnd = bubbleData;
                                            self->collapsableSeriesAtEnd.collapseState = queuedEvent.state;
                                            [collapsingCellDataSeriess addObject:self->collapsableSeriesAtEnd];
                                        }
                                    }
                                }
                                else
                                {
                                    // The new bubble is not collapsable.
                                    // We can close one border of the current series being built (if any)
                                    if (queuedEvent.direction == MXTimelineDirectionBackwards && self->collapsableSeriesAtStart)
                                    {
                                        // This is the begin border of the series
                                        self->collapsableSeriesAtStart = nil;
                                    }
                                    else if (queuedEvent.direction == MXTimelineDirectionForwards && self->collapsableSeriesAtEnd)
                                    {
                                        // This is the end border of the series
                                        self->collapsableSeriesAtEnd = nil;
                                    }
                                }
                            }

                            if (queuedEvent.direction == MXTimelineDirectionBackwards)
                            {
                                // The new bubble data will be inserted at first position.
                                // We have to update the 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags of the current first bubble.

                                // Pagination handling
                                if ((self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay) && bubbleData.date)
                                {
                                    // A new pagination starts with this new bubble data
                                    bubbleData.isPaginationFirstBubble = YES;

                                    // Check whether the current first displayed pagination title is still relevant.
                                    if (self->bubblesSnapshot.count)
                                    {
                                        NSInteger index = 0;
                                        id<MXKRoomBubbleCellDataStoring> previousFirstBubbleDataWithDate;
                                        NSString *firstBubbleDateString;
                                        while (index < self->bubblesSnapshot.count)
                                        {
                                            previousFirstBubbleDataWithDate = self->bubblesSnapshot[index++];
                                            firstBubbleDateString = [self.eventFormatter dateStringFromDate:previousFirstBubbleDataWithDate.date withTime:NO];
                                            
                                            if (firstBubbleDateString)
                                            {
                                                break;
                                            }
                                        }
                                        
                                        if (firstBubbleDateString)
                                        {
                                            NSString *bubbleDateString = [self.eventFormatter dateStringFromDate:bubbleData.date withTime:NO];
                                            previousFirstBubbleDataWithDate.isPaginationFirstBubble = (bubbleDateString && ![firstBubbleDateString isEqualToString:bubbleDateString]);
                                        }
                                    }
                                }
                                else
                                {
                                    bubbleData.isPaginationFirstBubble = NO;
                                }

                                // Sender information are required for this new first bubble data,
                                // except if the bubble has no display (composed only by ignored events).
                                bubbleData.shouldHideSenderInformation = bubbleData.hasNoDisplay;

                                // Check whether this information is relevant for the current first bubble.
                                if (!bubbleData.shouldHideSenderInformation && self->bubblesSnapshot.count)
                                {
                                    id<MXKRoomBubbleCellDataStoring> previousFirstBubbleData = self->bubblesSnapshot.firstObject;

                                    if (previousFirstBubbleData.isPaginationFirstBubble == NO)
                                    {
                                        // Check whether the current first bubble has been sent by the same user.
                                        previousFirstBubbleData.shouldHideSenderInformation |= [previousFirstBubbleData hasSameSenderAsBubbleCellData:bubbleData];
                                    }
                                }

                                // Insert the new bubble data in first position
                                [self->bubblesSnapshot insertObject:bubbleData atIndex:0];
                                
                                addedHistoryCellCount++;
                            }
                            else
                            {
                                // The new bubble data will be added at the last position
                                // We have to update its 'isPaginationFirstBubble' and 'shouldHideSenderInformation' flags according to the previous last bubble.

                                // Pagination handling
                                if (self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay)
                                {
                                    // Check whether a new pagination starts at this bubble
                                    NSString *bubbleDateString = [self.eventFormatter dateStringFromDate:bubbleData.date withTime:NO];
                                    
                                    // Look for the current last bubble with date
                                    NSInteger index = self->bubblesSnapshot.count;
                                    NSString *lastBubbleDateString;
                                    while (index--)
                                    {
                                        id<MXKRoomBubbleCellDataStoring> previousLastBubbleData = self->bubblesSnapshot[index];
                                        lastBubbleDateString = [self.eventFormatter dateStringFromDate:previousLastBubbleData.date withTime:NO];
                                        
                                        if (lastBubbleDateString)
                                        {
                                            break;
                                        }
                                    }
                                    
                                    if (lastBubbleDateString)
                                    {
                                        bubbleData.isPaginationFirstBubble = (bubbleDateString && ![bubbleDateString isEqualToString:lastBubbleDateString]);
                                    }
                                    else
                                    {
                                        bubbleData.isPaginationFirstBubble = (bubbleDateString != nil);
                                    }
                                }
                                else
                                {
                                    bubbleData.isPaginationFirstBubble = NO;
                                }

                                // Check whether the sender information is relevant for this new bubble.
                                bubbleData.shouldHideSenderInformation = bubbleData.hasNoDisplay;
                                if (!bubbleData.shouldHideSenderInformation && self->bubblesSnapshot.count && (bubbleData.isPaginationFirstBubble == NO))
                                {
                                    // Check whether the previous bubble has been sent by the same user.
                                    id<MXKRoomBubbleCellDataStoring> previousLastBubbleData = self->bubblesSnapshot.lastObject;
                                    bubbleData.shouldHideSenderInformation = [bubbleData hasSameSenderAsBubbleCellData:previousLastBubbleData];
                                }

                                // Insert the new bubble in last position
                                [self->bubblesSnapshot addObject:bubbleData];
                                
                                addedLiveCellCount++;
                            }
                        }
                        else if (updatedBubbleDataHadNoDisplay && !bubbleData.hasNoDisplay)
                        {
                            // Here the event has been added in an existing bubble data which had no display,
                            // and the added event provides a display to this bubble data.
                            if (queuedEvent.direction == MXTimelineDirectionBackwards)
                            {
                                // The bubble is the first one.
                                
                                // Pagination handling
                                if ((self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay) && bubbleData.date)
                                {
                                    // A new pagination starts with this bubble data
                                    bubbleData.isPaginationFirstBubble = YES;
                                    
                                    // Look for the first next bubble with date to check whether its pagination title is still relevant.
                                    if (self->bubblesSnapshot.count)
                                    {
                                        NSInteger index = 1;
                                        id<MXKRoomBubbleCellDataStoring> nextBubbleDataWithDate;
                                        NSString *firstNextBubbleDateString;
                                        while (index < self->bubblesSnapshot.count)
                                        {
                                            nextBubbleDataWithDate = self->bubblesSnapshot[index++];
                                            firstNextBubbleDateString = [self.eventFormatter dateStringFromDate:nextBubbleDataWithDate.date withTime:NO];
                                            
                                            if (firstNextBubbleDateString)
                                            {
                                                break;
                                            }
                                        }
                                        
                                        if (firstNextBubbleDateString)
                                        {
                                            NSString *bubbleDateString = [self.eventFormatter dateStringFromDate:bubbleData.date withTime:NO];
                                            nextBubbleDataWithDate.isPaginationFirstBubble = (bubbleDateString && ![firstNextBubbleDateString isEqualToString:bubbleDateString]);
                                        }
                                    }
                                }
                                else
                                {
                                    bubbleData.isPaginationFirstBubble = NO;
                                }
                                
                                // Sender information are required for this new first bubble data
                                bubbleData.shouldHideSenderInformation = NO;
                                
                                // Check whether this information is still relevant for the next bubble.
                                if (self->bubblesSnapshot.count > 1)
                                {
                                    id<MXKRoomBubbleCellDataStoring> nextBubbleData = self->bubblesSnapshot[1];
                                    
                                    if (nextBubbleData.isPaginationFirstBubble == NO)
                                    {
                                        // Check whether the current first bubble has been sent by the same user.
                                        nextBubbleData.shouldHideSenderInformation |= [nextBubbleData hasSameSenderAsBubbleCellData:bubbleData];
                                    }
                                }
                            }
                            else
                            {
                                // The bubble data is the last one
                                
                                // Pagination handling
                                if (self.bubblesPagination == MXKRoomDataSourceBubblesPaginationPerDay)
                                {
                                    // Check whether a new pagination starts at this bubble
                                    NSString *bubbleDateString = [self.eventFormatter dateStringFromDate:bubbleData.date withTime:NO];
                                    
                                    // Look for the first previous bubble with date
                                    NSInteger index = self->bubblesSnapshot.count - 1;
                                    NSString *firstPreviousBubbleDateString;
                                    while (index--)
                                    {
                                        id<MXKRoomBubbleCellDataStoring> previousBubbleData = self->bubblesSnapshot[index];
                                        firstPreviousBubbleDateString = [self.eventFormatter dateStringFromDate:previousBubbleData.date withTime:NO];
                                        
                                        if (firstPreviousBubbleDateString)
                                        {
                                            break;
                                        }
                                    }
                                    
                                    if (firstPreviousBubbleDateString)
                                    {
                                        bubbleData.isPaginationFirstBubble = (bubbleDateString && ![bubbleDateString isEqualToString:firstPreviousBubbleDateString]);
                                    }
                                    else
                                    {
                                        bubbleData.isPaginationFirstBubble = (bubbleDateString != nil);
                                    }
                                }
                                else
                                {
                                    bubbleData.isPaginationFirstBubble = NO;
                                }
                                
                                // Check whether the sender information is relevant for this new bubble.
                                bubbleData.shouldHideSenderInformation = NO;
                                if (self->bubblesSnapshot.count && (bubbleData.isPaginationFirstBubble == NO))
                                {
                                    // Check whether the previous bubble has been sent by the same user.
                                    NSInteger index = self->bubblesSnapshot.count - 1;
                                    if (index--)
                                    {
                                        id<MXKRoomBubbleCellDataStoring> previousBubbleData = self->bubblesSnapshot[index];
                                        bubbleData.shouldHideSenderInformation = [bubbleData hasSameSenderAsBubbleCellData:previousBubbleData];
                                    }
                                }
                            }
                        }

                        [self updateCellDataReactions:bubbleData forEventId:queuedEvent.event.eventId];

                        // Store event-bubble link to the map
                        @synchronized (self->eventIdToBubbleMap)
                        {
                            self->eventIdToBubbleMap[queuedEvent.event.eventId] = bubbleData;
                        }
                        
                        if (queuedEvent.event.isLocalEvent)
                        {
                            // Listen to the identifier change for the local events.
                            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localEventDidChangeIdentifier:) name:kMXEventDidChangeIdentifierNotification object:queuedEvent.event];
                        }
                    }
                }

                for (MXKQueuedEvent *queuedEvent in self->eventsToProcessSnapshot)
                {
                    @autoreleasepool
                    {
                        dispatch_group_enter(dispatchGroup);
                        [self addReadReceiptsForEvent:queuedEvent.event.eventId
                                             threadId:queuedEvent.event.threadId
                                          inCellDatas:self->bubblesSnapshot
                                   startingAtCellData:self->eventIdToBubbleMap[queuedEvent.event.eventId] completion:^{
                            dispatch_group_leave(dispatchGroup);
                        }];
                    }
                }

                // Check if all cells of self.bubbles belongs to a single collapse series.
                // In this case, collapsableSeriesAtStart and collapsableSeriesAtEnd must be equal
                // in order to handle next forward or backward pagination.
                if (self->collapsableSeriesAtStart && self->collapsableSeriesAtStart == self->bubbles.firstObject)
                {
                    // Find the tail
                    id<MXKRoomBubbleCellDataStoring> tailBubbleData = self->collapsableSeriesAtStart;
                    while (tailBubbleData.nextCollapsableCellData)
                    {
                        tailBubbleData = tailBubbleData.nextCollapsableCellData;
                    }

                    if (tailBubbleData == self->bubbles.lastObject)
                    {
                        self->collapsableSeriesAtEnd = self->collapsableSeriesAtStart;
                    }
                }
                else if (self->collapsableSeriesAtEnd)
                {
                    // Find the start
                    id<MXKRoomBubbleCellDataStoring> startBubbleData = self->collapsableSeriesAtEnd;
                    while (startBubbleData.prevCollapsableCellData)
                    {
                        startBubbleData = startBubbleData.prevCollapsableCellData;
                    }

                    if (startBubbleData == self->bubbles.firstObject)
                    {
                        self->collapsableSeriesAtStart = self->collapsableSeriesAtEnd;
                    }
                }

                // Compose (= compute collapsedAttributedTextMessage) of collapsable seriess
                for (id<MXKRoomBubbleCellDataStoring> bubbleData in collapsingCellDataSeriess)
                {
                    // Get all events of the series
                    NSMutableArray<MXEvent*> *events = [NSMutableArray array];
                    id<MXKRoomBubbleCellDataStoring> nextBubbleData = bubbleData;
                    do
                    {
                        [events addObjectsFromArray:nextBubbleData.events];
                    }
                    while ((nextBubbleData = nextBubbleData.nextCollapsableCellData));

                    // Build the summary string for the series
                    bubbleData.collapsedAttributedTextMessage = [self.eventFormatter attributedStringFromEvents:events
                                                                                                  withRoomState:bubbleData.collapseState
                                                                                             andLatestRoomState:self.roomState
                                                                                                          error:nil];

                    // Release collapseState objects, even the one of collapsableSeriesAtStart.
                    // We do not need to keep its state because if an collapsable event comes before collapsableSeriesAtStart,
                    // we will take the room state of this event.
                    if (bubbleData != self->collapsableSeriesAtEnd)
                    {
                        bubbleData.collapseState = nil;
                    }
                }
            }
            self->eventsToProcessSnapshot = nil;
        }
        
        // Check whether some events have been processed
        if (self->bubblesSnapshot)
        {
            // Updated data can be displayed now
            // Block MXKRoomDataSource.processingQueue while the processing is finalised on the main thread
            dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                // Check whether self has not been reloaded or destroyed
                if (self.state == MXKDataSourceStateReady && self->bubblesSnapshot)
                {
                    if (self.serverSyncEventCount)
                    {
                        self->_serverSyncEventCount -= serverSyncEventCount;
                        if (!self.serverSyncEventCount)
                        {
                            // Notify that sync process ends
                            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKRoomDataSourceSyncStatusChanged object:self userInfo:nil];
                        }
                    }
                    if (self.secondaryRoom) {
                        [self->bubblesSnapshot sortWithOptions:NSSortStable
                                               usingComparator:^NSComparisonResult(MXKRoomBubbleCellData * _Nonnull bubbleData1, MXKRoomBubbleCellData * _Nonnull bubbleData2) {
                            if (bubbleData1.date)
                            {
                                if (bubbleData2.date)
                                {
                                    return [bubbleData1.date compare:bubbleData2.date];
                                }
                                else
                                {
                                    return NSOrderedDescending;
                                }
                            }
                            else
                            {
                                if (bubbleData2.date)
                                {
                                    return NSOrderedAscending;
                                }
                                else
                                {
                                    return NSOrderedSame;
                                }
                            }
                        }];
                    }
                    self->bubbles = self->bubblesSnapshot;
                    self->bubblesSnapshot = nil;
                    
                    if (self.delegate)
                    {
                        [self.delegate dataSource:self didCellChange:nil];
                    }
                    else
                    {
                        // Check the memory usage of the data source. Reload it if the cache is too huge.
                        [self limitMemoryUsage:self.maxBackgroundCachedBubblesCount];
                    }
                }
                
                // Inform about the end if requested
                if (onComplete)
                {
                    onComplete(addedHistoryCellCount, addedLiveCellCount);
                }
            });
        }
        else
        {
            // No new event has been added, we just inform about the end if requested.
            if (onComplete)
            {
                dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
                    onComplete(0, 0);
                });
            }
        }
    });
}

/**
 Add the read receipts of an event into the timeline (which is in array of cell datas)

 If the event is not displayed, read receipts will be added to a previous displayed message.

 @param eventId the id of the event.
 @param threadId the Id of the thread related of the event.
 @param cellDatas the working array of cell datas.
 @param cellData the original cell data the event belongs to.
 @param completion completion block
 */
- (void)addReadReceiptsForEvent:(NSString*)eventId
                       threadId:(NSString *)threadId
                    inCellDatas:(NSArray<id<MXKRoomBubbleCellDataStoring>>*)cellDatas
             startingAtCellData:(id<MXKRoomBubbleCellDataStoring>)cellData
                     completion:(void (^)(void))completion
{
    if (self.showBubbleReceipts)
    {
        if (self.room)
        {
            [self.room getEventReceipts:eventId threadId:threadId sorted:YES completion:^(NSArray<MXReceiptData *> * _Nonnull readReceipts) {
                if (readReceipts.count)
                {
                    NSInteger cellDataIndex = [cellDatas indexOfObject:cellData];
                    if (cellDataIndex != NSNotFound)
                    {
                        [self addReadReceipts:readReceipts forEvent:eventId inCellDatas:cellDatas atCellDataIndex:cellDataIndex];
                    }
                }
                
                if (!RiotSettings.shared.enableThreads)
                {
                    // If threads are disabled, we may have several threaded RR with same userId
                    // but different threadId within the same timeline.
                    // We just need to keep the latest one.
                    [self clearDuplicatedReadReceiptsInCellDatas:cellDatas];
                }

                if (completion)
                {
                    completion();
                }
            }];
        }
        else if (completion)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    }
    else if (completion)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
    }
}

- (void)addReadReceipts:(NSArray<MXReceiptData*> *)readReceipts forEvent:(NSString*)eventId inCellDatas:(NSArray<id<MXKRoomBubbleCellDataStoring>>*)cellDatas atCellDataIndex:(NSInteger)cellDataIndex
{
    id<MXKRoomBubbleCellDataStoring> cellData = cellDatas[cellDataIndex];

    if ([cellData isKindOfClass:MXKRoomBubbleCellData.class])
    {
        MXKRoomBubbleCellData *roomBubbleCellData = (MXKRoomBubbleCellData*)cellData;

        BOOL areReadReceiptsAssigned = NO;
        for (MXKRoomBubbleComponent *component in roomBubbleCellData.bubbleComponents.reverseObjectEnumerator)
        {
            if (component.attributedTextMessage)
            {
                if (roomBubbleCellData.readReceipts[component.event.eventId])
                {
                    NSArray<MXReceiptData*> *currentReadReceipts = roomBubbleCellData.readReceipts[component.event.eventId];
                    NSMutableArray<MXReceiptData*> *newReadReceipts = [NSMutableArray arrayWithArray:currentReadReceipts];
                    for (MXReceiptData *readReceipt in readReceipts)
                    {
                        BOOL alreadyHere = NO;
                        for (MXReceiptData *currentReadReceipt in currentReadReceipts)
                        {
                            if ([readReceipt.userId isEqualToString:currentReadReceipt.userId])
                            {
                                alreadyHere = YES;
                                break;
                            }
                        }

                        if (!alreadyHere)
                        {
                            [newReadReceipts addObject:readReceipt];
                        }
                    }
                    [self updateCellData:roomBubbleCellData withReadReceipts:newReadReceipts forEventId:component.event.eventId];
                }
                else
                {
                    [self updateCellData:roomBubbleCellData withReadReceipts:readReceipts forEventId:component.event.eventId];
                }
                areReadReceiptsAssigned = YES;
                break;
            }

            MXLogDebug(@"[MXKRoomDataSource][%p] addReadReceipts: Read receipts for an event(%@) that is not displayed", self, eventId);
        }

        if (!areReadReceiptsAssigned)
        {
            MXLogDebug(@"[MXKRoomDataSource][%p] addReadReceipts: Try to attach read receipts to an older message: %@", self, eventId);

            // Try to assign RRs to a previous cell data
            if (cellDataIndex >= 1)
            {
                [self addReadReceipts:readReceipts forEvent:eventId inCellDatas:cellDatas atCellDataIndex:cellDataIndex - 1];
            }
            else
            {
                MXLogDebug(@"[MXKRoomDataSource][%p] addReadReceipts: Fail to attach read receipts for an event(%@)", self, eventId);
            }
        }
    }
}

/**
 Clear all potential duplicated RR with same user ID within a given list of cell data.
 
 This is needed for client with threads disabled in order to clean threaded RRs.
 
 @param cellDatas the working array of cell datas.
 */
- (void)clearDuplicatedReadReceiptsInCellDatas:(NSArray<id<MXKRoomBubbleCellDataStoring>>*)cellDatas
{
    NSMutableSet<NSString *> *seenUserIds = [NSMutableSet set];
    for (id<MXKRoomBubbleCellDataStoring> cellData in cellDatas.reverseObjectEnumerator)
    {
        if ([cellData isKindOfClass:MXKRoomBubbleCellData.class])
        {
            MXKRoomBubbleCellData *roomBubbleCellData = (MXKRoomBubbleCellData*)cellData;

            for (MXKRoomBubbleComponent *component in roomBubbleCellData.bubbleComponents)
            {
                if (component.attributedTextMessage)
                {
                    if (roomBubbleCellData.readReceipts[component.event.eventId])
                    {
                        NSArray<MXReceiptData*> *currentReadReceipts = roomBubbleCellData.readReceipts[component.event.eventId];
                        NSMutableArray<MXReceiptData*> *newReadReceipts = [NSMutableArray array];
                        for (MXReceiptData *readReceipt in currentReadReceipts)
                        {
                            if (![seenUserIds containsObject:readReceipt.userId])
                            {
                                [newReadReceipts addObject:readReceipt];
                                [seenUserIds addObject:readReceipt.userId];
                            }
                        }
                        [self updateCellData:roomBubbleCellData withReadReceipts:newReadReceipts forEventId:component.event.eventId];
                    }
                }
            }
        }
    }
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // PATCH: Presently no bubble must be displayed until the user joins the room.
    // FIXME: Handle room data source in case of room preview
    if (self.room.summary.membership == MXMembershipInvite)
    {
        return 0;
    }
    
    NSInteger count;
    @synchronized(bubbles)
    {
        count = bubbles.count;
    }
    return count;
}

- (void)scanBubbleDataIfNeeded:(id<MXKRoomBubbleCellDataStoring>)bubbleData
{
    MXScanManager *scanManager = self.mxSession.scanManager;
    
    if (!scanManager && ![bubbleData isKindOfClass:MXKRoomBubbleCellData.class])
    {
        return;
    }

    MXKRoomBubbleCellData *roomBubbleCellData = (MXKRoomBubbleCellData*)bubbleData;
    
    NSString *contentURL = roomBubbleCellData.attachment.contentURL;

    // If the content url corresponds to an upload id, the upload is in progress or not complete.
    // Create a fake event scan with in progress status when uploading media.
    // Since there is no event scan in database it will be overriden by MXScanManager on media upload complete.
    if (contentURL && [contentURL hasPrefix:kMXMediaUploadIdPrefix])
    {
        MXKRoomBubbleComponent *firstBubbleComponent = roomBubbleCellData.bubbleComponents.firstObject;
        MXEvent *firstBubbleComponentEvent = firstBubbleComponent.event;
        
        if (firstBubbleComponent && firstBubbleComponent.eventScan.antivirusScanStatus != MXAntivirusScanStatusInProgress && firstBubbleComponentEvent)
        {
            MXEventScan *uploadEventScan = [MXEventScan new];
            uploadEventScan.eventId = firstBubbleComponentEvent.eventId;
            uploadEventScan.antivirusScanStatus = MXAntivirusScanStatusInProgress;
            uploadEventScan.antivirusScanDate = nil;
            uploadEventScan.mediaScans = @[];
            
            firstBubbleComponent.eventScan = uploadEventScan;
        }
    }
    else
    {
        for (MXKRoomBubbleComponent *bubbleComponent in roomBubbleCellData.bubbleComponents)
        {
            MXEvent *event = bubbleComponent.event;
            
            if ([event isContentScannable])
            {
                [scanManager scanEventIfNeeded:event];
                // NOTE: - [MXScanManager scanEventIfNeeded:] perform modification in background, so - [MXScanManager eventScanWithId:] do not retrieve the last state of event scan.
                // It is noticeable when eventScan should be created for the first time. It would be better to return an eventScan with an in progress scan status instead of nil.
                MXEventScan *eventScan = [scanManager eventScanWithId:event.eventId];
                bubbleComponent.eventScan = eventScan;
            }
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell<MXKCellRendering> *cell;
    
    id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataAtIndex:indexPath.row];
    
    // Launch an antivirus scan on events contained in bubble data if needed
    [self scanBubbleDataIfNeeded:bubbleData];
    
    if (bubbleData && self.delegate)
    {
        // Retrieve the cell identifier according to cell data.
        NSString *identifier = [self.delegate cellReuseIdentifierForCellData:bubbleData];
        if (identifier)
        {
            cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
            
            // Make sure we listen to user actions on the cell
            cell.delegate = self;
            
            // Update typing flag before rendering
            bubbleData.isTyping = _showTypingNotifications && currentTypingUsers && ([currentTypingUsers indexOfObject:bubbleData.senderId] != NSNotFound);
            // Report the current timestamp display option
            bubbleData.showBubbleDateTime = self.showBubblesDateTime;
            // display the read receipts
            bubbleData.showBubbleReceipts = self.showBubbleReceipts;
            // let the caller application manages the time label?
            bubbleData.useCustomDateTimeLabel = self.useCustomDateTimeLabel;
            // let the caller application manages the receipt?
            bubbleData.useCustomReceipts = self.useCustomReceipts;
            // let the caller application manages the unsent button?
            bubbleData.useCustomUnsentButton = self.useCustomUnsentButton;
            
            // Make the bubble display the data
            [cell render:bubbleData];
        }
    }
    
    // Sanity check: this method may be called during a layout refresh while room data have been modified.
    if (!cell)
    {
        // Return an empty cell
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"fakeCell"];
    }
    
    return cell;
}

#pragma mark - MXScanManager notifications

- (void)registerScanManagerNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MXScanManagerEventScanDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(eventScansDidChange:) name:MXScanManagerEventScanDidChangeNotification object:nil];
}

- (void)unregisterScanManagerNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MXScanManagerEventScanDidChangeNotification object:nil];
}
     
- (void)eventScansDidChange:(NSNotification*)notification
{
    // TODO: Avoid to call the delegate to often. Set a minimum time interval to avoid table view flickering.
    [self.delegate dataSource:self didCellChange:nil];
}


#pragma mark - Reactions

- (void)registerReactionsChangeListener
{
    if (!self.showReactions || reactionsChangeListener)
    {
        return;
    }

    MXWeakify(self);
    reactionsChangeListener = [self.mxSession.aggregations listenToReactionCountUpdateInRoom:self.roomId block:^(NSDictionary<NSString *,MXReactionCountChange *> * _Nonnull changes) {
        MXStrongifyAndReturnIfNil(self);

        BOOL updated = NO;
        for (NSString *eventId in changes)
        {
            id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:eventId];
            if (bubbleData)
            {
                // TODO: Be smarted and use changes[eventId]
                [self updateCellDataReactions:bubbleData forEventId:eventId];
                updated = YES;
            }
        }

        if (updated)
        {
            [self.delegate dataSource:self didCellChange:nil];
        }
    }];
}

- (void)unregisterReactionsChangeListener
{
    if (reactionsChangeListener)
    {
        [self.mxSession.aggregations removeListener:reactionsChangeListener];
        reactionsChangeListener = nil;
    }
}

- (void)updateCellDataReactions:(id<MXKRoomBubbleCellDataStoring>)cellData forEventId:(NSString*)eventId
{
    if (!self.showReactions || ![cellData isKindOfClass:MXKRoomBubbleCellData.class])
    {
        return;
    }

    MXKRoomBubbleCellData *roomBubbleCellData = (MXKRoomBubbleCellData*)cellData;

    MXAggregatedReactions *aggregatedReactions = [self.mxSession.aggregations aggregatedReactionsOnEvent:eventId inRoom:self.roomId].aggregatedReactionsWithNonZeroCount;
    
    if (self.showOnlySingleEmojiReactions)
    {
        aggregatedReactions = aggregatedReactions.aggregatedReactionsWithSingleEmoji;
    }
    
    if (aggregatedReactions)
    {
        if (!roomBubbleCellData.reactions)
        {
            roomBubbleCellData.reactions = [NSMutableDictionary dictionary];
        }

        roomBubbleCellData.reactions[eventId] = aggregatedReactions;
    }
    else
    {
        // unreaction
        roomBubbleCellData.reactions[eventId] = nil;
    }

    // Indicate that the text message layout should be recomputed.
    [roomBubbleCellData invalidateTextLayout];
}

- (BOOL)canReactToEventWithId:(NSString*)eventId
{
    BOOL canReact = NO;
    
    MXEvent *event = [self eventWithEventId:eventId];
    
    if ([self canPerformActionOnEvent:event])
    {
        NSString *messageType = event.content[kMXMessageTypeKey];
        
        if ([messageType isEqualToString:kMXMessageTypeKeyVerificationRequest])
        {
            canReact = NO;
        }
        else
        {
            canReact = YES;
        }
    }
    
    return canReact;
}

- (void)addReaction:(NSString *)reaction forEventId:(NSString *)eventId success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    [self.mxSession.aggregations addReaction:reaction forEvent:eventId inRoom:self.roomId success:success failure:^(NSError * _Nonnull error) {
        MXLogDebug(@"[MXKRoomDataSource][%p] Fail to send reaction on eventId: %@", self, eventId);
        if (failure)
        {
            failure(error);
        }
    }];
}

- (void)removeReaction:(NSString *)reaction forEventId:(NSString *)eventId success:(void (^)(void))success failure:(void (^)(NSError *))failure
{
    [self.mxSession.aggregations removeReaction:reaction forEvent:eventId inRoom:self.roomId success:success failure:^(NSError * _Nonnull error) {
        MXLogDebug(@"[MXKRoomDataSource][%p] Fail to unreact on eventId: %@", self, eventId);
        if (failure)
        {
            failure(error);
        }
    }];
}

#pragma mark - Editions

- (BOOL)canEditEventWithId:(NSString*)eventId
{
    MXEvent *event = [self eventWithEventId:eventId];
    BOOL isRoomMessage = event.eventType == MXEventTypeRoomMessage;
    NSString *messageType = event.content[kMXMessageTypeKey];
    
    return isRoomMessage
    && ([messageType isEqualToString:kMXMessageTypeText] || [messageType isEqualToString:kMXMessageTypeEmote])
    && [event.sender isEqualToString:self.mxSession.myUserId]
    && [event.roomId isEqualToString:self.roomId];
}

- (NSString*)editableTextMessageForEvent:(MXEvent*)event
{
    NSString *editableTextMessage;
    
    if (event.isReplyEvent)
    {
        MXReplyEventParser *replyEventParser = [MXReplyEventParser new];
        MXReplyEventParts *replyEventParts = [replyEventParser parse:event];
        
        editableTextMessage = replyEventParts.bodyParts.replyText;
    }
    else
    {
        editableTextMessage = event.content[kMXMessageBodyKey];
    }
    
    return editableTextMessage;
}

- (void)registerEventEditsListener
{
    if (eventEditsListener)
    {
        return;
    }
    
    MXWeakify(self);
    eventEditsListener = [self.mxSession.aggregations listenToEditsUpdateInRoom:self.roomId block:^(MXEvent * _Nonnull replaceEvent) {
        MXStrongifyAndReturnIfNil(self);

        [self updateEventWithReplaceEvent:replaceEvent];
    }];
}

- (void)updateEventWithReplaceEvent:(MXEvent*)replaceEvent
{
    NSString *editedEventId = replaceEvent.relatesTo.eventId;

    dispatch_async(MXKRoomDataSource.processingQueue, ^{

        // Check whether a message contains the edited event
        id<MXKRoomBubbleCellDataStoring> bubbleData = [self cellDataOfEventWithEventId:editedEventId];
        if (bubbleData)
        {
            BOOL hasChanged = [self updateCellData:bubbleData forEditionWithReplaceEvent:replaceEvent andEventId:editedEventId];

            if (hasChanged)
            {
                // Update the delegate on main thread
                dispatch_async(dispatch_get_main_queue(), ^{

                    if (self.delegate)
                    {
                        [self.delegate dataSource:self didCellChange:nil];
                    }

                });
            }
        }
    });
}

- (void)unregisterEventEditsListener
{
    if (eventEditsListener)
    {
        [self.mxSession.aggregations removeListener:eventEditsListener];
        eventEditsListener = nil;
    }
}

- (BOOL)refreshRepliesWithUpdatedEventId:(NSString*)updatedEventId
{
    BOOL hasChanged = NO;

    @synchronized (bubbles) {
        for (id<MXKRoomBubbleCellDataStoring> bubbleCellData in bubbles)
        {
            for (MXEvent *event in bubbleCellData.events)
            {
                if ([event.relatesTo.inReplyTo.eventId isEqual:updatedEventId])
                {
                    [bubbleCellData updateEvent:event.eventId withEvent:event];
                    [bubbleCellData invalidateTextLayout];
                    hasChanged = YES;
                }
            }
        }
    }

    return hasChanged;
}

- (BOOL)updateCellData:(id<MXKRoomBubbleCellDataStoring>)bubbleCellData forEditionWithReplaceEvent:(MXEvent*)replaceEvent andEventId:(NSString*)eventId
{
    BOOL hasChanged = NO;

    hasChanged = [self refreshRepliesWithUpdatedEventId:eventId];

    @synchronized (bubbleCellData)
    {
        // Retrieve the original event to edit it
        NSArray *events = bubbleCellData.events;
        MXEvent *editedEvent = nil;
        
        // If not already done, update edited event content in-place
        // This is required for:
        //   - local echo
        //   - non live timeline in memory store (permalink)
        for (MXEvent *event in events)
        {
            if ([event.eventId isEqualToString:eventId])
            {
                // Check whether the event was not already edited
                if (![event.unsignedData.relations.replace.eventId isEqualToString:replaceEvent.eventId])
                {
                    editedEvent = [event editedEventFromReplacementEvent:replaceEvent];
                }
                break;
            }
        }
        
        if (editedEvent)
        {
            if (editedEvent.sentState != replaceEvent.sentState)
            {
                // Relay the replace event state to the edited event so that the display
                // of the edited will rerun the classic sending color flow.
                // Note: this must be done on the main thread (this operation triggers
                // the call of [self eventDidChangeSentState])
                dispatch_async(dispatch_get_main_queue(), ^{
                    editedEvent.sentState = replaceEvent.sentState;
                });
            }

            [bubbleCellData updateEvent:eventId withEvent:editedEvent];
            [bubbleCellData invalidateTextLayout];
            hasChanged = YES;
        }
    }
    
    return hasChanged;
}

- (void)replaceTextMessageForEvent:(MXEvent*)event
                   withTextMessage:(NSString *)text
                           success:(void (^)(NSString *))success
                           failure:(void (^)(NSError *))failure
{
    NSString *sanitizedText = [self sanitizedMessageText:text];
    NSString *formattedText = [self htmlMessageFromSanitizedText:sanitizedText];
    
    NSString *eventBody = event.content[kMXMessageBodyKey];
    NSString *eventFormattedBody = event.content[@"formatted_body"];
    
    if (![sanitizedText isEqualToString:eventBody] && (!eventFormattedBody || ![formattedText isEqualToString:eventFormattedBody]))
    {
        [self.mxSession.aggregations replaceTextMessageEvent:event withTextMessage:sanitizedText formattedText:formattedText localEchoBlock:^(MXEvent * _Nonnull replaceEventLocalEcho) {

            // Apply the local echo to the timeline
            [self updateEventWithReplaceEvent:replaceEventLocalEcho];

            // Integrate the replace local event into the timeline like when sending a message
            // This also allows to manage read receipt on this replace event
            [self queueEventForProcessing:replaceEventLocalEcho withRoomState:self.roomState direction:MXTimelineDirectionForwards];
            [self processQueuedEvents:nil];

        } success:success failure:failure];
    }
    else
    {
        failure(nil);
    }
}

#pragma mark - Virtual Rooms

- (void)virtualRoomsDidChange:(NSNotification *)notification
{
    //  update secondary room id
    self.secondaryRoomId = [self.mxSession virtualRoomOf:self.roomId];
}

#pragma mark - Use Only Latest Profiles

/**
 Refresh avatars and display names (AKA profiles) if needed.
 */
- (void)refreshProfilesIfNeeded
{
   @synchronized (bubbles) {
        for (id<MXKRoomBubbleCellDataStoring> bubble in bubbles)
        {
            [bubble refreshProfilesIfNeeded:self.roomState];
        }
    }
}

@end
