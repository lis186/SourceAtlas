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

## Step 0.7 錨定合約
## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

| # | 類別 | 模式 | 命中次數 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | dispatch_semaphore_create | 1 | NYHTTPSClient.m:606 |
| 2 | S | dispatch_semaphore_wait | 1 | NYHTTPSClient.m:650 |
| 3 | S | dispatch_semaphore_signal | 1 | NYHTTPSClient.m:642 |
| 4 | S | dispatch_once | 1 | NYHTTPSClient.m:61 |
| 5 | S | DISPATCH_TIME_FOREVER | 1 | NYHTTPSClient.m:650 |
| 6 | N | postNotificationName | 2 | NYHTTPSClient.m:747 |
| 7 | N | defaultCenter | 2 | NYHTTPSClient.m:747 |
| 8 | N | completionHandler | 1 | NYHTTPSClient.m:610 |
| 9 | N | success_failure_block | 85 | NYHTTPSClient.m:172 |
| 10 | D | sharedInstance | 1 | NYHTTPSClient.m:635 |
| 11 | D | protocol_decl | 1 | NYHTTPSClient.h:28 |
| 12 | D | category_interface | 1 | NYHTTPSClient.m:30 |
| 13 | E | NSError_param | 13 | NYHTTPSClient.m:235 |
| 14 | E | errorWithDomain | 9 | NYHTTPSClient.m:309 |
| 15 | C | cancel_operation | 1 | NYHTTPSClient.m:460 |

共 15 個錨點命中。

對於每個錨定合約，你的 Artifact 1 必須包含至少一個對應的 {Category}-{NNN} 合約。
若你認為某個錨點不構成合約，必須在 Artifact 4 中說明原因。


## 目標原始碼

//
//  NYHTTPSClient.m
//  NineYiShopping
//
//  Created by stedy on 13/4/17.
//  Copyright (c) 2013年 Julie Lin. All rights reserved.
//

#import "NYHTTPSClient.h"
#import "NYJSONRequestSerializer.h"
#import "NYBaseURLConfig.h"
#import "NSString+Regex.h"
#import "NYCookieManager.h"
#import "NYGlobalData.h"
#import "NYUserDefault.h"
#import "NYLoginHelper.h"
#import <NYCore/NYCore-Swift.h>

// Deprecated: 保留作為 fallback，請使用 NYAESKeyManager.decryptedAESKey() 取得 AES Key
static NSString *const kAesKey      = @"8167b887e6b30cbb553cdf7fdd62e602";
static NSString *const kSalt        = @"fdsfds";
static NSString *const kHMAC_SHA512 = @"8167b887";

/// 取得 AES Key（優先使用加密儲存的 key，失敗則使用 fallback）
static NSString *aesKey(void) {
    NSString *key = [NYAESKeyManager decryptedAESKey];
    return key ?: [NYAESKeyManager fallbackKey];
}

@interface NYHTTPSClient ()
- (AFHTTPRequestSerializer *)requestSerializerWithType:(NYHTTPRequestType)type;
- (AFHTTPResponseSerializer *)responseSerializerWithType:(NYHTTPResponseType)type;

- (BOOL)shouldAppendAppVerToURL:(NSURL *)url;

// For record API info only, should not use this method in Release build.
- (void)recordApiInfo:(NSString *)path parameters:(NSDictionary *)parameter method:(NSString *)method requestSerializerType:(NYHTTPRequestType)requestType responseSerializerType:(NYHTTPResponseType)responseType responseContentType:(NSString *)responseContentType;

+ (void)initLogFile;
+ (NSString *)logFilePath;
@end

@implementation NYHTTPSClient

static NYHTTPClientLogLevel _logLevel = NYHTTPClientLogLevelOff;

+ (NYHTTPClientLogLevel)logLevel {
    return _logLevel;
}

+ (void)setLogLevel:(NYHTTPClientLogLevel)logLevel {
    if (logLevel == NYHTTPClientLogLevelAPIInfo) {
        [self initLogFile];
    }
    _logLevel = logLevel;
}

+ (NYHTTPSClient *)sharedClient {
    static id _sharedClient = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[NYHTTPSClient alloc] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/webapi/", [NYBaseURLConfig baseHTTPSURLWithWebAPIDomain].absoluteString]]];
        if (NYUserDefaultV2.isSSLPinningEnabled) {
            [_sharedClient setSecurityPolicy:[NYSecurityPolicy policy]];
        }
    });
    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url {
    if (self = [super initWithBaseURL:url]) {
        
    }
    return self;
}

#pragma mark - NSMutableURLRequest Factory
- (NSMutableURLRequest *)requestWithType:(NYHTTPRequestType)type method:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    NSString *URLString;
    if (![self.baseURL.absoluteString hasSuffix:@"/"] && ![path hasPrefix:@"/"]) {
        URLString = [NSString stringWithFormat:@"%@/%@", self.baseURL.absoluteString, path];
    } else {
        URLString = [NSString stringWithFormat:@"%@%@", self.baseURL.absoluteString, path];
    }
    
    // 在還沒有取得交集之前，預設語系帶 en-US。理論上只有 GetShopAvailLanguages 這隻 API 會使用
    NSMutableString *updateURLString = URLString.mutableCopy;
    NSMutableDictionary *updatedParameters = (parameters == nil) ? @{}.mutableCopy : parameters.mutableCopy;
    NSNumber *shopId = [NYGlobalData shopId];
    NSString *selectedLang = [NYLocalizationString selectedLanguageCode];
    NSString *preferedLang = [NSLocale preferredLanguages].firstObject;
    NSString *lang = selectedLang.length > 0 ? selectedLang
    : preferedLang.length > 0 ? preferedLang
    : @"en-US";
    
    if ([method.uppercaseString isEqualToString:@"GET"]) {
        // 如果已經有ShopID就更新 (大小寫不拘)
        __block NSString *shopIDKey = nil;
        [updatedParameters enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([key.lowercaseString isEqualToString:@"shopid"]) {
                shopIDKey = key;
                *stop = YES;
            }
        }];
        shopIDKey = shopIDKey ? : @"shopId";

        // 因為只有 GET 才放在 parameters 會被放進 query string
        updatedParameters[shopIDKey] = shopId;
        updatedParameters[@"lang"] = lang;
    } else {
        // 非 GET 需另外處理
        NSURLComponents *urlComponenets = [NSURLComponents componentsWithString:URLString];
        NSArray<NSURLQueryItem *> *queryItems = urlComponenets.queryItems;
        if (queryItems.count == 0) {
            // 代表沒有 query string，需要加 ?shopId=%@&lang=%@
            [updateURLString appendString:[NSString stringWithFormat:@"?shopId=%@&lang=%@", shopId, lang]];
        } else {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.name LIKE[cd] %@", @"shopId"];
            if ([queryItems filteredArrayUsingPredicate:predicate].count > 0) {
                // 有包含 shopId，僅需加上 lang=%@
                [updateURLString appendString:[NSString stringWithFormat:@"&lang=%@", lang]];
            } else {
                // 沒有包含 shopId，也是需要兩個都加
                [updateURLString appendString:[NSString stringWithFormat:@"&shopId=%@&lang=%@", shopId, lang]];
            }
        }
    }
    
    AFHTTPRequestSerializer *requestSerializer = [self requestSerializerWithType:type];
    NSMutableURLRequest *outputRequest = [requestSerializer requestWithMethod:method
                                                                    URLString:updateURLString
                                                                   parameters:updatedParameters
                                                                        error:nil];
    // Restore uAuth
    [[NYCookieManager sharedManager] forceUpdateUAuth];

    // Change Accept-Language if user selected other language
    if (NYLocalizationString.selectedLanguage != NYLanguageUserDefault) {
        [outputRequest setValue:NYLocalizationString.selectedLanguageCode
             forHTTPHeaderField:@"Accept-Language"];
    } else {
        // 將語系對應到LanguageTool上合法的語系 (如zh-MY -> zh-TW)
        NSString *currentLanguageCode = [[NSLocale preferredLanguages] firstObject];
        NSString *supportedLanguageCode = [NYLocalizationString properLanguageKeyWith:currentLanguageCode];

        if (supportedLanguageCode) {
            [outputRequest setValue:supportedLanguageCode forHTTPHeaderField:@"Accept-Language"];
        }
    }
    
    // Set Authorization
    if (NYLoginUserDataModel.sharedModel.expressAccessToken != nil) {
        [outputRequest setValue:NYLoginUserDataModel.sharedModel.expressAccessToken
             forHTTPHeaderField:@"Authorization"];
    }
    
    return outputRequest;
}

- (NSMutableURLRequest *)httpRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    return [self requestWithType:NYHTTPRequestTypeHTTP method:method path:path parameters:parameters];
}

- (NSMutableURLRequest *)jsonRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    return [self requestWithType:NYHTTPRequestTypeJSON method:method path:path parameters:parameters];
}

#pragma mark - HTTP GET

- (void)syncGetPath:(NSString *)path
         parameters:(NSDictionary *)parameters
            success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
            failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    [self syncGetPath:path parameters:parameters requestType:NYHTTPRequestTypeHTTP responseType:NYHTTPResponseTypeJSON success:success failure:failure];
}

- (void)syncGetPath:(NSString *)path
         parameters:(NSDictionary *)parameters
        requestType:(NYHTTPRequestType)requestType
       responseType:(NYHTTPResponseType)responseType
            success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
            failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    [self addOperationWithRequestType:requestType
                         responseType:responseType
                               method:@"GET"
                                 path:path
                           parameters:parameters
                isSynchrounousRequest:YES
                       requestTimeout:nil
                              success:success
                              failure:failure];
}

- (AnyPromise *)getPath:(NSString *)path parameters:(NSDictionary *)parameters {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver  _Nonnull resolve) {
        [self getPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {
            resolve(PMKManifold(responseObject, operation));
        } failure:^(NSURLSessionDataTask *operation, NSError *error) {
            resolve(error);
        }];
    }];
    //return [[self getPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {} failure:^(NSURLSessionDataTask *operation, NSError *error) {}] promise];
}

- (NSURLSessionDataTask *)getPath:(NSString *)path
                       parameters:(NSDictionary *)parameters
                          success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                          failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    return [self getPath:path parameters:parameters requestType:NYHTTPRequestTypeHTTP responseType:NYHTTPResponseTypeJSON success:success failure:failure];
}

- (NSURLSessionDataTask *)getPath:(NSString *)path
                       parameters:(NSDictionary *)parameters
                      requestType:(NYHTTPRequestType)requestType
                     responseType:(NYHTTPResponseType)responseType
                          success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                          failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    return [self addOperationWithRequestType:requestType responseType:responseType method:@"GET" path:path parameters:parameters success:success failure:failure];
}

#pragma mark - HTP POST

- (void)syncPostPath:(NSString *)path
          parameters:(NSDictionary *)parameters
             success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
             failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    [self syncPostPath:path parameters:parameters requestType:NYHTTPRequestTypeHTTP responseType:NYHTTPResponseTypeJSON success:success failure:failure];
}

- (void)syncPostPath:(NSString *)path
          parameters:(NSDictionary *)parameters
         requestType:(NYHTTPRequestType)requestType
        responseType:(NYHTTPResponseType)responseType
             success:(void (^)(NSURLSessionDataTask *, id))success
             failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    [self addOperationWithRequestType:requestType
                         responseType:responseType
                               method:@"POST"
                                 path:path
                           parameters:parameters
                isSynchrounousRequest:YES
                       requestTimeout:nil
                              success:success
                              failure:failure];
}

- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver  _Nonnull resolve) {
        [self syncPostPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {
            resolve(PMKManifold(responseObject, operation));
        } failure:^(NSURLSessionDataTask *operation, NSError *error) {
            resolve(error);
        }];
    }];
    //return [[self postPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {} failure:^(NSURLSessionDataTask *operation, NSError *error) {}] promise];
}

- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters requestType:(NYHTTPRequestType)requestType responseType:(NYHTTPResponseType)responseType {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver  _Nonnull resolve) {
        [self postPath:path parameters:parameters requestType:requestType responseType:responseType success:^(NSURLSessionDataTask *operation, id responseObject) {
            resolve(PMKManifold(responseType, operation));
        } failure:^(NSURLSessionDataTask *operation, NSError *error) {
            resolve(error);
        }];
    }];
}

- (NSURLSessionDataTask *)postPath:(NSString *)path
      parameters:(NSDictionary *)parameters
         success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    return [self postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:success failure:failure];
}

- (NSURLSessionDataTask *)postPath:(NSString *)path
                        parameters:(NSDictionary *)parameters
                       requestType:(NYHTTPRequestType)requestType
                      responseType:(NYHTTPResponseType)responseType
                           success:(void (^)(NSURLSessionDataTask *, id))success
                           failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    return [self addOperationWithRequestType:requestType responseType:responseType method:@"POST" path:path parameters:parameters success:success failure:failure];
}

- (NSURLSessionDataTask *)postPath:(NSString *)path
                        parameters:(NSDictionary *)parameters
                       requestType:(NYHTTPRequestType)requestType
                      responseType:(NYHTTPResponseType)responseType
                    requestTimeout:(NSNumber *)requestTimeout
                           success:(void (^)(NSURLSessionDataTask *, id))success
                           failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    return [self addOperationWithRequestType:requestType
                                responseType:responseType
                                      method:@"POST"
                                        path:path
                                  parameters:parameters
                              requestTimeout:requestTimeout
                                     success:success
                                     failure:failure];
}

- (void)postPath:(NSString *)path dataStr:(NSString *)dataStr   //For RegistAPP
sendSynchronousRequest:(BOOL)sendSynchronousRequest
         success:(void (^)(NSURLSessionDataTask *operation, id JSON))success
         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    
    NSData *data = [dataStr dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    NSString *currentAESKey = aesKey();
    if (currentAESKey.length < 32) {
        NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid AES key length"}];
        failure(nil, error);
        return;
    }
    
    NSData *aesKey = [[currentAESKey substringWithRange:NSMakeRange(0, 32)] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *aesIv = [[currentAESKey substringWithRange:NSMakeRange(0, 16)] dataUsingEncoding:NSUTF8StringEncoding];
    
    // 使用 CryptoSwift 進行 AES 加密
    NSString *encryptedBase64 = [NYCryptoSwiftInterface aesEncryptWithData:data key:aesKey iv:aesIv];
    if (!encryptedBase64) {
        NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"AES encryption failed"}];
        failure(nil, error);
        return;
    }
    NSLog(@"encrypted base64: %@", encryptedBase64);
    
    NSString *timestamp     = [self timestamp];
    NSString *salt          = kSalt;
    NSString *hmacSHA512    = kHMAC_SHA512;
    
    // 使用 CryptoSwift 進行 HMAC-SHA512
    NSString *hmacSha512Hex = [NYCryptoSwiftInterface hmacSha512:[NSString stringWithFormat:@"%@%@%@", timestamp, salt, encryptedBase64] hmacKey:hmacSHA512];
    if (!hmacSha512Hex) {
        NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"HMAC-SHA512 failed"}];
        failure(nil, error);
        return;
    }
    NSLog(@"hmacSha512 hex signature: %@", hmacSha512Hex);
    
    NSDictionary *parameters = @{
                                 @"ciphertext":encryptedBase64,
                                 @"timeStamp":timestamp,
                                 @"signature":hmacSha512Hex
                                 };
    
    if (sendSynchronousRequest) {
        [self syncPostPath:path parameters:parameters success:success failure:failure];
    }
    else {
        [self postPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {
            success(operation, responseObject);
        } failure:^(NSURLSessionDataTask *operation, NSError *error) {
            failure(operation, error);
        }];
    }
}

- (void)postPathForEncryptData:(NSString *)path
                    parameters:(NSDictionary *)parameters
                       success:(void (^)(NSURLSessionDataTask *, id))success
                       failure:(void (^)(NSURLSessionDataTask *, NSError *))failure   //For NYMemberCard pull data
{
    [self postPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *currentAESKey = aesKey();
        if (currentAESKey.length < 32) {
            NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid AES key length"}];
            failure(nil, error);
            return;
        }
        
        NSData *aesKey = [[currentAESKey substringWithRange:NSMakeRange(0, 32)] dataUsingEncoding:NSUTF8StringEncoding];
        NSData *aesIv = [[currentAESKey substringWithRange:NSMakeRange(0, 16)] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *salt  = kSalt;
        NSString *hmacSHA512 = kHMAC_SHA512;
        
        NSString *cipherText = responseObject[@"cipherText"];
        NSString *signature = responseObject[@"signature"];
        NSString *timestamp = responseObject[@"timeStamp"];
        
        // 使用 CryptoSwift 進行 HMAC-SHA512 驗證
        NSString *hmacSha512Hex = [NYCryptoSwiftInterface hmacSha512:[NSString stringWithFormat:@"%@%@%@", timestamp, salt, cipherText] hmacKey:hmacSHA512];
        if (!hmacSha512Hex) {
            NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"HMAC-SHA512 verification failed"}];
            failure(operation, error);
            return;
        }
        
        if ([hmacSha512Hex isEqualToString:signature]) {
            // 使用 CryptoSwift 進行 AES 解密
            NSData *decryptedData = [NYCryptoSwiftInterface aesDecryptWithBase64:cipherText key:aesKey iv:aesIv];
            if (!decryptedData) {
                NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"AES decryption failed"}];
                failure(operation, error);
                return;
            }
            
            NSError *error;
            id jsonObject = [NSJSONSerialization JSONObjectWithData:decryptedData options:0 error:&error];
            if (error) {
                failure(operation, error);
                return;
            }
            success(operation, jsonObject);
        } else {
            NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"HMAC signature verification failed"}];
            failure(operation, error);
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        failure (operation, error);
    }];
}

- (void)postPathForECoupon:(NSString *)path
                parameters:(NSDictionary *)parameters
                   success:(void (^)(NSURLSessionDataTask *, id))success
                   failure:(void (^)(NSURLSessionDataTask *, NSError *))failure
{
    NSString *timestamp     = [self timestamp];
    NSString *salt          = kSalt;
    NSString *hmacSHA512    = kHMAC_SHA512;
    
    // 使用 CryptoSwift 進行 HMAC-SHA512
    NSString *hmacSha512Hex = [NYCryptoSwiftInterface hmacSha512:[NSString stringWithFormat:@"%@%@%@", timestamp, salt, parameters[@"eCouponGiftId"]] hmacKey:hmacSHA512];
    if (!hmacSha512Hex) {
        NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"HMAC-SHA512 failed"}];
        failure(nil, error);
        return;
    }
    
    NSDictionary *parametersForRequest = @{@"eCouponId":parameters[@"eCouponId"],
                                           @"eCouponGiftId": parameters[@"eCouponGiftId"],
                                           @"SenderFBId": parameters[@"SenderFBId"],
                                           @"ReceiverFBId": parameters[@"ReceiverFBId"],
                                           @"timestamp": timestamp,
                                           @"signature": hmacSha512Hex};
    //應Alan要求將post改為get, 方便server tracking
    [self getPath:path parameters:parametersForRequest success:^(NSURLSessionDataTask *operation, id responseObject) {
        success(operation, responseObject);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        failure(operation, error);
    }];
}

- (void)cancelAllHTTPOperationsWithMethod:(NSString *)method
                                     path:(NSString *)path
{
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.baseURL.absoluteString, path];
    NSURLRequest *request = [[AFHTTPRequestSerializer serializer] requestWithMethod:method URLString:urlString parameters:nil error:nil];
    NSString *pathToBeMatched = request.URL.absoluteString;
    
    for (NSOperation *operation in [self.operationQueue operations]) {
        if (![operation isKindOfClass:[NSURLSessionDataTask class]]) {
            continue;
        }

        NSURLSessionDataTask *task = (NSURLSessionDataTask *)operation;
        BOOL hasMatchingMethod = !method || [method isEqualToString:task.currentRequest.HTTPMethod];
        BOOL hasMatchingPath = [task.currentRequest.URL.path isEqual:pathToBeMatched];
        
        if (hasMatchingMethod && hasMatchingPath) {
            [operation cancel];
        }
    }
}

- (NSString *)timestamp {
    NSDate *start = [NSDate date];
    NSTimeInterval timeInterval = [start timeIntervalSince1970];
    double now_timestamp = fabs(timeInterval);
    
    now_timestamp += 28800; //GMT +8
    NSLog(@"time: %.0f", now_timestamp);
    
    NSString *timestamp = [NSString stringWithFormat:@"%.0f", now_timestamp];
    return timestamp;
}

#pragma mark - Logger

- (void)logMismatchShopID:(NSString *)responseShopID urlString:(NSString *)urlString {
    NSDictionary *logData = @{@"url": urlString,
                              @"exceptedShopId": [NYGlobalData shopId],
                              @"responseShopId": responseShopID};

    // error code: 91-400 代表示 91 專屬 400 bad request
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:91400 userInfo:logData];
    [self.logger recordError:error];
}

#pragma mark - Private Helpers

- (AFHTTPRequestSerializer *)requestSerializerWithType:(NYHTTPRequestType)type {
    AFHTTPRequestSerializer *serializer;
    switch (type) {
        case NYHTTPRequestTypeHTTP:
            serializer = [AFHTTPRequestSerializer serializer];
            break;
        case NYHTTPRequestTypeJSON:
            serializer = [AFJSONRequestSerializer serializer];
            break;
        case NYHTTPRequestTypeFixedFloat:
            serializer = [NYJSONRequestSerializer serializer];
            break;
        default:
            NSAssert(NO, @"Unrecognized Request Type");
            break;
    }
    
    //APP/Web 對齊timeout setting
    serializer.timeoutInterval = 30.0f;
    
    return serializer;
}

- (AFHTTPResponseSerializer *)responseSerializerWithType:(NYHTTPResponseType)type {
    AFHTTPResponseSerializer *serializer;
    switch (type) {
        case NYHTTPResponseTypeHTTP:
            serializer = [AFHTTPResponseSerializer serializer];
            break;
        case NYHTTPResponseTypeJSON:
            serializer = [AFJSONResponseSerializer serializerWithReadingOptions:NSJSONReadingMutableContainers | NSJSONReadingAllowFragments];
            break;
        default:
            NSAssert(NO, @"Unrecognized Request Type");
            break;
    }
    return serializer;
}

- (NSURLSessionDataTask *)addOperationWithRequestType:(NYHTTPRequestType)requestType
                       responseType:(NYHTTPResponseType)responseType
                             method:(NSString *)method
                               path:(NSString *)path
                         parameters:(NSDictionary *)parameters
                            success:(void (^)(NSURLSessionDataTask *, id))success
                            failure:(void (^)(NSURLSessionDataTask *, id))failure {

    return [self addOperationWithRequestType:requestType
                                responseType:responseType
                                      method:method
                                        path:path
                                  parameters:parameters
                       isSynchrounousRequest:NO
                              requestTimeout:nil
                                     success:success
                                     failure:failure];
}

- (NSURLSessionDataTask *)addOperationWithRequestType:(NYHTTPRequestType)requestType
                                         responseType:(NYHTTPResponseType)responseType
                                               method:(NSString *)method
                                                 path:(NSString *)path
                                           parameters:(NSDictionary *)parameters
                                       requestTimeout:(NSNumber *)requestTimeout
                                              success:(void (^)(NSURLSessionDataTask *, id))success
                                              failure:(void (^)(NSURLSessionDataTask *, id))failure {

    return [self addOperationWithRequestType:requestType
                                responseType:responseType
                                      method:method
                                        path:path
                                  parameters:parameters
                       isSynchrounousRequest:NO
                              requestTimeout:requestTimeout
                                     success:success
                                     failure:failure];
}

- (NSURLSessionDataTask *)addOperationWithRequestType:(NYHTTPRequestType)requestType
                                         responseType:(NYHTTPResponseType)responseType
                                               method:(NSString *)method
                                                 path:(NSString *)path
                                           parameters:(NSDictionary *)parameters
                                isSynchrounousRequest:(BOOL)isSynchrounousRequest
                                       requestTimeout:(NSNumber *)requestTimeout
                                              success:(void (^)(NSURLSessionDataTask *, id))success
                                              failure:(void (^)(NSURLSessionDataTask *, id))failure {
    NSMutableDictionary *mutableParameters = [parameters mutableCopy];
    if ([self shouldAppendAppVerToURL:self.baseURL]) {
        NSDictionary *appVerParameter = @{@"appVer" : [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]};
        if (!mutableParameters) {
            mutableParameters = [appVerParameter mutableCopy];
        }
        else {
            [mutableParameters setValuesForKeysWithDictionary:appVerParameter];
        }
    }
    
    NSMutableURLRequest *request = [self requestWithType:requestType method:method path:path parameters:mutableParameters];
    if (requestTimeout) {
        [request setTimeoutInterval:requestTimeout.doubleValue];
    }
    request.HTTPShouldHandleCookies = YES;
    [request setValue:[NSUUID UUID].UUIDString forHTTPHeaderField:@"ny-idempotency-key"];
    [request setValue:[[NYGlobalData shopId] stringValue]  forHTTPHeaderField:@"n1-shop-id"];

    self.responseSerializer = [self responseSerializerWithType:responseType];
    
    if ([NYBaseURLConfig isTestEnvironment]) {
        self.securityPolicy.allowInvalidCertificates = YES;
        self.securityPolicy.validatesDomainName = NO;
    }

    dispatch_semaphore_t semaphore;
    if (isSynchrounousRequest) {
        semaphore = dispatch_semaphore_create(0);
    }

    __block NSURLSessionDataTask *dataTask = nil;
    dataTask = [self dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        [self notifyResponseWithTask:dataTask responseObject:responseObject];
        // Note: 檢查 response header shopId 跟目前 shopId 是否一致，如果不同需要 log error.
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSString *expectedShopIdString = [NYGlobalData shopId].stringValue;
            NSString *responseShopId = httpResponse.allHeaderFields[@"x-shop-id"] ? : expectedShopIdString;
            BOOL isShopIdMismatch = ![expectedShopIdString isEqualToString:responseShopId];
            
            if (isShopIdMismatch) {
                [self logMismatchShopID:responseShopId
                              urlString:request.URL.absoluteString];
            }
        }

        if (error) {
            if (failure) {
                failure(dataTask, error);
            }
        } else {
            if (success) {
                // ignoreAuthExpireLogoutEnabled : debug 專用，從 setting 改
                if ([self logoutWithURL:dataTask.originalRequest.URL
                             resposeObj:responseObject] &&
                    ![NYUserDefault ignoreAuthExpireLogoutEnabled]) {
                    [[NYLoginHelper sharedInstance] logoutAndLoginAgainWithCompletionHandler:nil];
                }
                success(dataTask, responseObject);
            }
        }
         
         if (isSynchrounousRequest) {
             dispatch_semaphore_signal(semaphore);
         }
    }];

    [self notifyRequestWithTask:dataTask];
    [dataTask resume];
    
    if (isSynchrounousRequest) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }

    return dataTask;
}

- (BOOL)shouldAppendAppVerToURL:(NSURL *)url {
    NSString *urlStr = self.baseURL.absoluteString;
    NSString *facebookDomainPattern = @"(graph.facebook)";
    NSString *cdnDomainPattern = [NSString stringWithFormat:@"(%@)", [NYBaseURLConfig domainNameForCDNServer]];
    // tracking service 的 key 不是 "appVer" 所以不在這邊送額外處理
    NSString *trackingDomainPattern = [NSString stringWithFormat:@"(%@)", [NYBaseURLConfig domainNameForTrackServer]];
    // cms domain 不加 query string
    NSString *cmsDomainPattern = @"cms";
    // cpdl domain 不加
    NSString *cpdlDomainPattern = @"(cpdl)";
    
    if ([urlStr isMatchWithPattern:facebookDomainPattern] ||
        [urlStr isMatchWithPattern:cdnDomainPattern] ||
        [urlStr isMatchWithPattern:trackingDomainPattern] ||
        [urlStr containsString:cmsDomainPattern] ||
        [urlStr isMatchWithPattern:cpdlDomainPattern]) {
        return NO;
    }
    return YES;
}

- (BOOL)logoutWithURL:(NSURL *)url
           resposeObj:(id)resposeObj {
    NSDictionary *resposeDict = (NSDictionary *)resposeObj;
    if (![resposeDict isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSString *path = url.path;
    NSString *returnCode = resposeDict[@"ReturnCode"];
    for (NSDictionary *apiCheck in [NYUserDefault logoutAPICheckList]) {
        NSString *checkPattern = [NSString stringWithFormat:@"(%@)", apiCheck[@"path"]];
        if ([path isMatchWithPattern:checkPattern]) {
            if ([returnCode isEqualToString:apiCheck[@"logoutReturnCode"]]) {
                return YES;
            }
            break;
        }
    }
    return NO;
}

#pragma mark - Log Helpers

- (void)recordApiInfo:(NSString *)path parameters:(NSDictionary *)parameters method:(NSString *)method requestSerializerType:(NYHTTPRequestType)requestType responseSerializerType:(NYHTTPResponseType)responseType responseContentType:(NSString *)responseContentType {
    if (_logLevel == NYHTTPClientLogLevelAPIInfo) {
        NSString *parameterEncoding, *responseEncoding;
        if ([method isEqualToString:@"GET"]) {
            parameterEncoding = @"Query String parameter";
        } else if ([method isEqualToString:@"POST"]) {
            parameterEncoding = requestType == NYHTTPRequestTypeHTTP ? @"URL form parameter" : @"JSON form parameter ";
        } else {
            parameterEncoding = @"Unrecognized parameter encofing";
        }
        responseEncoding = responseType == NYHTTPResponseTypeHTTP ? @"plain/text Response" : @"JSON Response";
        
        NSMutableString *parameterString;
        if (parameters) {
            NSError *error = nil;
            NSData *parameterData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&error];
            parameterString = [[NSMutableString alloc] initWithData:parameterData encoding:NSUTF8StringEncoding];
            [parameterString replaceOccurrencesOfString:@"," withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, parameterString.length)];
        }
        NSString *apiInfo = [NSString stringWithFormat:@"%@, %@, %@, %@, %@, %@, %@", self.baseURL, path, parameterString, method, parameterEncoding, responseEncoding, responseContentType];
        
        NSMutableString *apiLog = [NSMutableString stringWithContentsOfFile:[[self class] logFilePath] encoding:NSUTF8StringEncoding error:nil];
        if (!apiLog) {
            apiLog = @"".mutableCopy;
        }
        if ([apiLog rangeOfString:apiInfo].location == NSNotFound) {
            [apiLog appendFormat:@"%@\n", apiInfo];
        }
        
        [apiLog writeToFile:[[self class] logFilePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

+ (NSString *)logFilePath {
    NSString *documentDirPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *logFilePath = [documentDirPath stringByAppendingPathComponent:@"API-Log.csv"];
    return logFilePath;
}

+ (void)initLogFile {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self logFilePath]]) {
        [fileManager removeItemAtPath:[self logFilePath] error:nil];
    }
}

- (void)notifyRequestWithTask:(NSURLSessionTask * _Nullable)task {
    if (task == nil) { return; }
    [NSNotificationCenter.defaultCenter postNotificationName:@"apiRequest"
                                                      object:self
                                                    userInfo:@{@"task": task}];
}

- (void)notifyResponseWithTask:(NSURLSessionTask * _Nullable)task
                responseObject:(id _Nullable)responseObject {
    if (task == nil) { return; }

    NSDictionary * aUserInfo;

    if (responseObject == nil) {
        aUserInfo = @{@"task": task};
    } else {
        aUserInfo = @{@"task": task, @"responseObject":responseObject};
    }

    [NSNotificationCenter.defaultCenter postNotificationName:@"apiResponse"
                                                      object:self
                                                    userInfo:aUserInfo];
}

@end
//
//  NYHTTPSClient.h
//  NineYiShopping
//
//  Created by stedy on 13/4/17.
//  Copyright (c) 2013年 Julie Lin. All rights reserved.
//

#import <AFNetworking/AFHTTPSessionManager.h>
#import <PromiseKit/PromiseKit.h>

typedef NS_ENUM(NSInteger, NYHTTPRequestType) {
    NYHTTPRequestTypeFixedFloat,
    NYHTTPRequestTypeHTTP,
    NYHTTPRequestTypeJSON
};

typedef NS_ENUM(NSInteger, NYHTTPResponseType) {
    NYHTTPResponseTypeHTTP,
    NYHTTPResponseTypeJSON
};

typedef NS_ENUM(NSInteger, NYHTTPClientLogLevel) {
    NYHTTPClientLogLevelOff,
    NYHTTPClientLogLevelAPIInfo
};

@protocol NYHTTPSClientLogger <NSObject>

- (void)recordError:(NSError *)error NS_SWIFT_NAME(record(error:));

@end

#pragma mark -

@interface NYHTTPSClient : AFHTTPSessionManager

@property (nonatomic, strong) id<NYHTTPSClientLogger> logger;

+ (NYHTTPClientLogLevel)logLevel;
+ (void)setLogLevel:(NYHTTPClientLogLevel)logLevel;

+(NYHTTPSClient *)sharedClient;

- (NSMutableURLRequest *)requestWithType:(NYHTTPRequestType)type method:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters;
- (NSMutableURLRequest *)httpRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters;
- (NSMutableURLRequest *)jsonRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters;

- (void)syncGetPath:(NSString *)path
        parameters:(NSDictionary *)parameters
           success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
           failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

- (void)syncGetPath:(NSString *)path
        parameters:(NSDictionary *)parameters
       requestType:(NYHTTPRequestType)requestType
      responseType:(NYHTTPResponseType)responseType
           success:(void (^)(NSURLSessionDataTask *, id))success
           failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (AnyPromise *)getPath:(NSString *)path parameters:(NSDictionary *)parameters;

- (NSURLSessionDataTask *)getPath:(NSString *)path
     parameters:(NSDictionary *)parameters
        success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
        failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

- (NSURLSessionDataTask *)getPath:(NSString *)path
     parameters:(NSDictionary *)parameters
    requestType:(NYHTTPRequestType)requestType
   responseType:(NYHTTPResponseType)responseType
        success:(void (^)(NSURLSessionDataTask *, id))success
        failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (void)syncPostPath:(NSString *)path
          parameters:(NSDictionary *)parameters
             success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
             failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

- (void)syncPostPath:(NSString *)path
          parameters:(NSDictionary *)parameters
         requestType:(NYHTTPRequestType)requestType
        responseType:(NYHTTPResponseType)responseType
             success:(void (^)(NSURLSessionDataTask *, id))success
             failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters;

- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters requestType:(NYHTTPRequestType)requestType responseType:(NYHTTPResponseType)responseType;

- (NSURLSessionDataTask *)postPath:(NSString *)path
      parameters:(NSDictionary *)parameters
         success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

- (NSURLSessionDataTask *)postPath:(NSString *)path
                        parameters:(NSDictionary *)parameters
                       requestType:(NYHTTPRequestType)requestType
                      responseType:(NYHTTPResponseType)responseType
                           success:(void (^)(NSURLSessionDataTask *, id))success
                           failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (NSURLSessionDataTask *)postPath:(NSString *)path
                        parameters:(NSDictionary *)parameters
                       requestType:(NYHTTPRequestType)requestType
                      responseType:(NYHTTPResponseType)responseType
                    requestTimeout:(NSNumber *)requestTimeout
                           success:(void (^)(NSURLSessionDataTask *, id))success
                           failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (void)postPathForECoupon:(NSString *)path
                parameters:(NSDictionary *)parameters
                   success:(void (^)(NSURLSessionDataTask *, id))success
                   failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (void)postPathForEncryptData:(NSString *)path
                    parameters:(NSDictionary *)parameters
                       success:(void (^)(NSURLSessionDataTask *, id))success
                       failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;   //For NYMemberCard pull data

- (void)postPath:(NSString *)path dataStr:(NSString *)dataStr
sendSynchronousRequest:(BOOL)sendSynchronousRequest
         success:(void (^)(NSURLSessionDataTask *operation, id JSON))success
         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

- (void)cancelAllHTTPOperationsWithMethod:(NSString *)method
                                     path:(NSString *)path;

- (NSString *)timestamp;

#pragma mark - for tracking client use
- (AFHTTPRequestSerializer *)requestSerializerWithType:(NYHTTPRequestType)type;
- (AFHTTPResponseSerializer *)responseSerializerWithType:(NYHTTPResponseType)type;
- (BOOL)shouldAppendAppVerToURL:(NSURL *)url;

@end
