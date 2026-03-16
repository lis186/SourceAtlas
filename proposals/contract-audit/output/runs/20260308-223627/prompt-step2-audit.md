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

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | dispatch_semaphore_create | 2 | NYHTTPSClient.m:606 |
| 2 | S | dispatch_semaphore_wait | 2 | NYHTTPSClient.m:650 |
| 3 | S | dispatch_semaphore_signal | 2 | NYHTTPSClient.m:642 |
| 4 | S | dispatch_async | 2 | NYLoginViewController.m:154 |
| 5 | S | dispatch_queue_create | 2 | NYCookieManager.m:421 |
| 6 | S | dispatch_barrier | 1 | NYCookieManager.m:421 |
| 7 | S | dispatch_once | 4 | NYHTTPSClient.m:61 |
| 8 | S | DISPATCH_TIME_FOREVER | 2 | NYHTTPSClient.m:650 |
| 9 | S | dispatch_after | 3 | NYLoginChangePasswordVC.m:361 |
| 10 | S | dispatch_group | 9 | NYLoginViewController.m:147 |
| 11 | N | postNotificationName | 5 | NYHTTPSClient.m:747 |
| 12 | N | addObserver_selector | 5 | MBProgressHUD.m:745 |
| 13 | N | addObserver_forKeyPath | 3 | NYLoginViewController.m:812 |
| 14 | N | removeObserver | 6 | MBProgressHUD.m:753 |
| 15 | N | respondsToSelector | 4 | MBProgressHUD.m:294 |
| 16 | N | delegate_property | 7 | MBProgressHUD.m:293 |
| 17 | N | defaultCenter | 15 | NYHTTPSClient.m:747 |
| 18 | N | performSelector | 2 | MBProgressHUD.m:295 |
| 19 | N | completionHandler | 44 | NYHTTPSClient.m:610 |
| 20 | N | success_failure_block | 103 | NYHTTPSClient.m:172 |
| 21 | L | viewDidLoad | 6 | NYLoginChangePasswordVC.m:89 |
| 22 | L | viewWillAppear | 7 | NYLoginChangePasswordVC.m:114 |
| 23 | L | viewDidAppear | 2 | NYLoginViewController.m:476 |
| 24 | L | viewWillDisappear | 2 | NYThirdPartyLoginWebBrowserVC.m:115 |
| 25 | L | viewDidDisappear | 1 | NYLoginViewController.m:489 |
| 26 | L | performSelector_afterDelay | 5 | MBProgressHUD.m:167 |
| 27 | D | sharedInstance | 45 | NYHTTPSClient.m:635 |
| 28 | D | shared_dot | 3 | NYDeviceToken+DI.swift:23 |
| 29 | D | protocol_decl | 1 | NYHTTPSClient.h:28 |
| 30 | D | ifdef_feature | 1 | NYCookieManager.m:249 |
| 31 | D | if_conditional | 10 | MBProgressHUD.m:375 |
| 32 | D | category_interface | 9 | NYHTTPSClient.m:30 |
| 33 | E | NSError_param | 14 | NYHTTPSClient.m:235 |
| 34 | E | errorWithDomain | 11 | NYHTTPSClient.m:309 |
| 35 | C | cancel_operation | 5 | NYHTTPSClient.m:460 |

共 35 個錨點命中。

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
//
// MBProgressHUD.m
// Version 1.2.0
// Created by Matej Bukovinski on 2.4.09.
//

#import "MBProgressHUD.h"
#import <tgmath.h>

#define MBMainThreadAssert() NSAssert([NSThread isMainThread], @"MBProgressHUD needs to be accessed on the main thread.");

CGFloat const MBProgressMaxOffset = 1000000.f;

static const CGFloat MBDefaultPadding = 4.f;
static const CGFloat MBDefaultLabelFontSize = 16.f;
static const CGFloat MBDefaultDetailsLabelFontSize = 12.f;


@interface MBProgressHUD ()

@property (nonatomic, assign) BOOL useAnimation;
@property (nonatomic, assign, getter=hasFinished) BOOL finished;
@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, strong) NSDate *showStarted;
@property (nonatomic, strong) NSArray *paddingConstraints;
@property (nonatomic, strong) NSArray *bezelConstraints;
@property (nonatomic, strong) UIView *topSpacer;
@property (nonatomic, strong) UIView *bottomSpacer;
@property (nonatomic, strong) UIMotionEffectGroup *bezelMotionEffects;
@property (nonatomic, weak) NSTimer *graceTimer;
@property (nonatomic, weak) NSTimer *minShowTimer;
@property (nonatomic, weak) NSTimer *hideDelayTimer;
@property (nonatomic, weak) CADisplayLink *progressObjectDisplayLink;

@end


@interface MBProgressHUDRoundedButton : UIButton
@end


@implementation MBProgressHUD

#pragma mark - Class methods

+ (instancetype)showHUDAddedTo:(UIView *)view animated:(BOOL)animated {
    MBProgressHUD *hud = [[self alloc] initWithView:view];
    hud.removeFromSuperViewOnHide = YES;
    [view addSubview:hud];
    [hud showAnimated:animated];
    return hud;
}

+ (BOOL)hideHUDForView:(UIView *)view animated:(BOOL)animated {
    MBProgressHUD *hud = [self HUDForView:view];
    if (hud != nil) {
        hud.removeFromSuperViewOnHide = YES;
        [hud hideAnimated:animated];
        return YES;
    }
    return NO;
}

+ (MBProgressHUD *)HUDForView:(UIView *)view {
    NSEnumerator *subviewsEnum = [view.subviews reverseObjectEnumerator];
    for (UIView *subview in subviewsEnum) {
        if ([subview isKindOfClass:self]) {
            MBProgressHUD *hud = (MBProgressHUD *)subview;
            if (hud.hasFinished == NO) {
                return hud;
            }
        }
    }
    return nil;
}

#pragma mark - Lifecycle

- (void)commonInit {
    // Set default values for properties
    _animationType = MBProgressHUDAnimationFade;
    _mode = MBProgressHUDModeIndeterminate;
    _margin = 20.0f;
    _defaultMotionEffectsEnabled = NO;

    if (@available(iOS 13.0, tvOS 13, *)) {
       _contentColor = [[UIColor labelColor] colorWithAlphaComponent:0.7f];
    } else {
        _contentColor = [UIColor colorWithWhite:0.f alpha:0.7f];
    }

    // Transparent background
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    // Make it invisible for now
    self.alpha = 0.0f;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.layer.allowsGroupOpacity = NO;

    [self setupViews];
    [self updateIndicators];
    [self registerForNotifications];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self commonInit];
    }
    return self;
}

- (id)initWithView:(UIView *)view {
    NSAssert(view, @"View must not be nil.");
    return [self initWithFrame:view.bounds];
}

- (void)dealloc {
    [self unregisterFromNotifications];
}

#pragma mark - Show & hide

- (void)showAnimated:(BOOL)animated {
    MBMainThreadAssert();
    [self.minShowTimer invalidate];
    self.useAnimation = animated;
    self.finished = NO;
    // If the grace time is set, postpone the HUD display
    if (self.graceTime > 0.0) {
        NSTimer *timer = [NSTimer timerWithTimeInterval:self.graceTime target:self selector:@selector(handleGraceTimer:) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        self.graceTimer = timer;
    }
    // ... otherwise show the HUD immediately
    else {
        [self showUsingAnimation:self.useAnimation];
    }
}

- (void)hideAnimated:(BOOL)animated {
    MBMainThreadAssert();
    [self.graceTimer invalidate];
    self.useAnimation = animated;
    self.finished = YES;
    // If the minShow time is set, calculate how long the HUD was shown,
    // and postpone the hiding operation if necessary
    if (self.minShowTime > 0.0 && self.showStarted) {
        NSTimeInterval interv = [[NSDate date] timeIntervalSinceDate:self.showStarted];
        if (interv < self.minShowTime) {
            NSTimer *timer = [NSTimer timerWithTimeInterval:(self.minShowTime - interv) target:self selector:@selector(handleMinShowTimer:) userInfo:nil repeats:NO];
            [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
            self.minShowTimer = timer;
            return;
        }
    }
    // ... otherwise hide the HUD immediately
    [self hideUsingAnimation:self.useAnimation];
}

- (void)hideAnimated:(BOOL)animated afterDelay:(NSTimeInterval)delay {
    // Cancel any scheduled hideAnimated:afterDelay: calls
    [self.hideDelayTimer invalidate];

    NSTimer *timer = [NSTimer timerWithTimeInterval:delay target:self selector:@selector(handleHideTimer:) userInfo:@(animated) repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.hideDelayTimer = timer;
}

#pragma mark - Timer callbacks

- (void)handleGraceTimer:(NSTimer *)theTimer {
    // Show the HUD only if the task is still running
    if (!self.hasFinished) {
        [self showUsingAnimation:self.useAnimation];
    }
}

- (void)handleMinShowTimer:(NSTimer *)theTimer {
    [self hideUsingAnimation:self.useAnimation];
}

- (void)handleHideTimer:(NSTimer *)timer {
    [self hideAnimated:[timer.userInfo boolValue]];
}

#pragma mark - View Hierrarchy

- (void)didMoveToSuperview {
    [self updateForCurrentOrientationAnimated:NO];
}

#pragma mark - Internal show & hide operations

- (void)showUsingAnimation:(BOOL)animated {
    // Cancel any previous animations
    [self.bezelView.layer removeAllAnimations];
    [self.backgroundView.layer removeAllAnimations];

    // Cancel any scheduled hideAnimated:afterDelay: calls
    [self.hideDelayTimer invalidate];

    self.showStarted = [NSDate date];
    self.alpha = 1.f;

    // Needed in case we hide and re-show with the same NSProgress object attached.
    [self setNSProgressDisplayLinkEnabled:YES];

    // Set up motion effects only at this point to avoid needlessly
    // creating the effect if it was disabled after initialization.
    [self updateBezelMotionEffects];

    if (animated) {
        [self animateIn:YES withType:self.animationType completion:NULL];
    } else {
        self.bezelView.alpha = 1.f;
        self.backgroundView.alpha = 1.f;
    }
}

- (void)hideUsingAnimation:(BOOL)animated {
    // Cancel any scheduled hideAnimated:afterDelay: calls.
    // This needs to happen here instead of in done,
    // to avoid races if another hideAnimated:afterDelay:
    // call comes in while the HUD is animating out.
    [self.hideDelayTimer invalidate];

    if (animated && self.showStarted) {
        self.showStarted = nil;
        [self animateIn:NO withType:self.animationType completion:^(BOOL finished) {
            [self done];
        }];
    } else {
        self.showStarted = nil;
        self.bezelView.alpha = 0.f;
        self.backgroundView.alpha = 1.f;
        [self done];
    }
}

- (void)animateIn:(BOOL)animatingIn withType:(MBProgressHUDAnimation)type completion:(void(^)(BOOL finished))completion {
    // Automatically determine the correct zoom animation type
    if (type == MBProgressHUDAnimationZoom) {
        type = animatingIn ? MBProgressHUDAnimationZoomIn : MBProgressHUDAnimationZoomOut;
    }

    CGAffineTransform small = CGAffineTransformMakeScale(0.5f, 0.5f);
    CGAffineTransform large = CGAffineTransformMakeScale(1.5f, 1.5f);

    // Set starting state
    UIView *bezelView = self.bezelView;
    if (animatingIn && bezelView.alpha == 0.f && type == MBProgressHUDAnimationZoomIn) {
        bezelView.transform = small;
    } else if (animatingIn && bezelView.alpha == 0.f && type == MBProgressHUDAnimationZoomOut) {
        bezelView.transform = large;
    }

    // Perform animations
    dispatch_block_t animations = ^{
        if (animatingIn) {
            bezelView.transform = CGAffineTransformIdentity;
        } else if (!animatingIn && type == MBProgressHUDAnimationZoomIn) {
            bezelView.transform = large;
        } else if (!animatingIn && type == MBProgressHUDAnimationZoomOut) {
            bezelView.transform = small;
        }
        CGFloat alpha = animatingIn ? 1.f : 0.f;
        bezelView.alpha = alpha;
        self.backgroundView.alpha = alpha;
    };
    [UIView animateWithDuration:0.3 delay:0. usingSpringWithDamping:1.f initialSpringVelocity:0.f options:UIViewAnimationOptionBeginFromCurrentState animations:animations completion:completion];
}

- (void)done {
    [self setNSProgressDisplayLinkEnabled:NO];

    if (self.hasFinished) {
        self.alpha = 0.0f;
        if (self.removeFromSuperViewOnHide) {
            [self removeFromSuperview];
        }
    }
    MBProgressHUDCompletionBlock completionBlock = self.completionBlock;
    if (completionBlock) {
        completionBlock();
    }
    id<MBProgressHUDDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(hudWasHidden:)]) {
        [delegate performSelector:@selector(hudWasHidden:) withObject:self];
    }
}

#pragma mark - UI

- (void)setupViews {
    UIColor *defaultColor = self.contentColor;

    MBBackgroundView *backgroundView = [[MBBackgroundView alloc] initWithFrame:self.bounds];
    backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
    backgroundView.backgroundColor = [UIColor clearColor];
    backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backgroundView.alpha = 0.f;
    [self addSubview:backgroundView];
    _backgroundView = backgroundView;

    MBBackgroundView *bezelView = [MBBackgroundView new];
    bezelView.translatesAutoresizingMaskIntoConstraints = NO;
    bezelView.layer.cornerRadius = 5.f;
    bezelView.alpha = 0.f;
    [self addSubview:bezelView];
    _bezelView = bezelView;

    UILabel *label = [UILabel new];
    label.adjustsFontSizeToFitWidth = NO;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = defaultColor;
    label.font = [UIFont boldSystemFontOfSize:MBDefaultLabelFontSize];
    label.opaque = NO;
    label.backgroundColor = [UIColor clearColor];
    _label = label;

    UILabel *detailsLabel = [UILabel new];
    detailsLabel.adjustsFontSizeToFitWidth = NO;
    detailsLabel.textAlignment = NSTextAlignmentCenter;
    detailsLabel.textColor = defaultColor;
    detailsLabel.numberOfLines = 0;
    detailsLabel.font = [UIFont boldSystemFontOfSize:MBDefaultDetailsLabelFontSize];
    detailsLabel.opaque = NO;
    detailsLabel.backgroundColor = [UIColor clearColor];
    _detailsLabel = detailsLabel;

    UIButton *button = [MBProgressHUDRoundedButton buttonWithType:UIButtonTypeCustom];
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:MBDefaultDetailsLabelFontSize];
    [button setTitleColor:defaultColor forState:UIControlStateNormal];
    _button = button;

    for (UIView *view in @[label, detailsLabel, button]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [view setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisHorizontal];
        [view setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisVertical];
        [bezelView addSubview:view];
    }

    UIView *topSpacer = [UIView new];
    topSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    topSpacer.hidden = YES;
    [bezelView addSubview:topSpacer];
    _topSpacer = topSpacer;

    UIView *bottomSpacer = [UIView new];
    bottomSpacer.translatesAutoresizingMaskIntoConstraints = NO;
    bottomSpacer.hidden = YES;
    [bezelView addSubview:bottomSpacer];
    _bottomSpacer = bottomSpacer;
}

- (void)updateIndicators {
    UIView *indicator = self.indicator;
    BOOL isActivityIndicator = [indicator isKindOfClass:[UIActivityIndicatorView class]];
    BOOL isRoundIndicator = [indicator isKindOfClass:[MBRoundProgressView class]];

    MBProgressHUDMode mode = self.mode;
    if (mode == MBProgressHUDModeIndeterminate) {
        if (!isActivityIndicator) {
            // Update to indeterminate indicator
            UIActivityIndicatorView *activityIndicator;
            [indicator removeFromSuperview];
#if !TARGET_OS_MACCATALYST
            if (@available(iOS 13.0, tvOS 13.0, *)) {
#endif
                activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
                activityIndicator.color = [UIColor whiteColor];
#if !TARGET_OS_MACCATALYST
            } else {
                activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
            }
#endif
            [activityIndicator startAnimating];
            indicator = activityIndicator;
            [self.bezelView addSubview:indicator];
        }
    }
    else if (mode == MBProgressHUDModeDeterminateHorizontalBar) {
        // Update to bar determinate indicator
        [indicator removeFromSuperview];
        indicator = [[MBBarProgressView alloc] init];
        [self.bezelView addSubview:indicator];
    }
    else if (mode == MBProgressHUDModeDeterminate || mode == MBProgressHUDModeAnnularDeterminate) {
        if (!isRoundIndicator) {
            // Update to determinante indicator
            [indicator removeFromSuperview];
            indicator = [[MBRoundProgressView alloc] init];
            [self.bezelView addSubview:indicator];
        }
        if (mode == MBProgressHUDModeAnnularDeterminate) {
            [(MBRoundProgressView *)indicator setAnnular:YES];
        }
    }
    else if (mode == MBProgressHUDModeCustomView && self.customView != indicator) {
        // Update custom view indicator
        [indicator removeFromSuperview];
        indicator = self.customView;
        [self.bezelView addSubview:indicator];
    }
    else if (mode == MBProgressHUDModeText) {
        [indicator removeFromSuperview];
        indicator = nil;
    }
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.indicator = indicator;

    if ([indicator respondsToSelector:@selector(setProgress:)]) {
        [(id)indicator setValue:@(self.progress) forKey:@"progress"];
    }

    [indicator setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisHorizontal];
    [indicator setContentCompressionResistancePriority:998.f forAxis:UILayoutConstraintAxisVertical];

    [self updateViewsForColor:self.contentColor];
    [self setNeedsUpdateConstraints];
}

- (void)updateViewsForColor:(UIColor *)color {
    if (!color) return;

    self.label.textColor = color;
    self.detailsLabel.textColor = color;
    [self.button setTitleColor:color forState:UIControlStateNormal];

    // UIAppearance settings are prioritized. If they are preset the set color is ignored.

    UIView *indicator = self.indicator;
    if ([indicator isKindOfClass:[UIActivityIndicatorView class]]) {
        UIActivityIndicatorView *appearance = nil;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 90000
        appearance = [UIActivityIndicatorView appearanceWhenContainedIn:[MBProgressHUD class], nil];
#else
        // For iOS 9+
        appearance = [UIActivityIndicatorView appearanceWhenContainedInInstancesOfClasses:@[[MBProgressHUD class]]];
#endif

        if (appearance.color == nil) {
            ((UIActivityIndicatorView *)indicator).color = color;
        }
    } else if ([indicator isKindOfClass:[MBRoundProgressView class]]) {
        MBRoundProgressView *appearance = nil;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 90000
        appearance = [MBRoundProgressView appearanceWhenContainedIn:[MBProgressHUD class], nil];
#else
        appearance = [MBRoundProgressView appearanceWhenContainedInInstancesOfClasses:@[[MBProgressHUD class]]];
#endif
        if (appearance.progressTintColor == nil) {
            ((MBRoundProgressView *)indicator).progressTintColor = color;
        }
        if (appearance.backgroundTintColor == nil) {
            ((MBRoundProgressView *)indicator).backgroundTintColor = [color colorWithAlphaComponent:0.1];
        }
    } else if ([indicator isKindOfClass:[MBBarProgressView class]]) {
        MBBarProgressView *appearance = nil;
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 90000
        appearance = [MBBarProgressView appearanceWhenContainedIn:[MBProgressHUD class], nil];
#else
        appearance = [MBBarProgressView appearanceWhenContainedInInstancesOfClasses:@[[MBProgressHUD class]]];
#endif
        if (appearance.progressColor == nil) {
            ((MBBarProgressView *)indicator).progressColor = color;
        }
        if (appearance.lineColor == nil) {
            ((MBBarProgressView *)indicator).lineColor = color;
        }
    } else {
        [indicator setTintColor:color];
    }
}

- (void)updateBezelMotionEffects {
    MBBackgroundView *bezelView = self.bezelView;
    UIMotionEffectGroup *bezelMotionEffects = self.bezelMotionEffects;

    if (self.defaultMotionEffectsEnabled && !bezelMotionEffects) {
        CGFloat effectOffset = 10.f;
        UIInterpolatingMotionEffect *effectX = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
        effectX.maximumRelativeValue = @(effectOffset);
        effectX.minimumRelativeValue = @(-effectOffset);

        UIInterpolatingMotionEffect *effectY = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
        effectY.maximumRelativeValue = @(effectOffset);
        effectY.minimumRelativeValue = @(-effectOffset);

        UIMotionEffectGroup *group = [[UIMotionEffectGroup alloc] init];
        group.motionEffects = @[effectX, effectY];

        self.bezelMotionEffects = group;
        [bezelView addMotionEffect:group];
    } else if (bezelMotionEffects) {
        self.bezelMotionEffects = nil;
        [bezelView removeMotionEffect:bezelMotionEffects];
    }
}

#pragma mark - Layout

- (void)updateConstraints {
    UIView *bezel = self.bezelView;
    UIView *topSpacer = self.topSpacer;
    UIView *bottomSpacer = self.bottomSpacer;
    CGFloat margin = self.margin;
    NSMutableArray *bezelConstraints = [NSMutableArray array];
    NSDictionary *metrics = @{@"margin": @(margin)};

    NSMutableArray *subviews = [NSMutableArray arrayWithObjects:self.topSpacer, self.label, self.detailsLabel, self.button, self.bottomSpacer, nil];
    if (self.indicator) [subviews insertObject:self.indicator atIndex:1];

    // Remove existing constraints
    [self removeConstraints:self.constraints];
    [topSpacer removeConstraints:topSpacer.constraints];
    [bottomSpacer removeConstraints:bottomSpacer.constraints];
    if (self.bezelConstraints) {
        [bezel removeConstraints:self.bezelConstraints];
        self.bezelConstraints = nil;
    }

    // Center bezel in container (self), applying the offset if set
    CGPoint offset = self.offset;
    NSMutableArray *centeringConstraints = [NSMutableArray array];
    [centeringConstraints addObject:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1.f constant:offset.x]];
    [centeringConstraints addObject:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.f constant:offset.y]];
    [self applyPriority:998.f toConstraints:centeringConstraints];
    [self addConstraints:centeringConstraints];

    // Ensure minimum side margin is kept
    NSMutableArray *sideConstraints = [NSMutableArray array];
    [sideConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(>=margin)-[bezel]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(bezel)]];
    [sideConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=margin)-[bezel]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(bezel)]];
    [self applyPriority:999.f toConstraints:sideConstraints];
    [self addConstraints:sideConstraints];

    // Minimum bezel size, if set
    CGSize minimumSize = self.minSize;
    if (!CGSizeEqualToSize(minimumSize, CGSizeZero)) {
        NSMutableArray *minSizeConstraints = [NSMutableArray array];
        [minSizeConstraints addObject:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:minimumSize.width]];
        [minSizeConstraints addObject:[NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:minimumSize.height]];
        [self applyPriority:997.f toConstraints:minSizeConstraints];
        [bezelConstraints addObjectsFromArray:minSizeConstraints];
    }

    // Square aspect ratio, if set
    if (self.square) {
        NSLayoutConstraint *square = [NSLayoutConstraint constraintWithItem:bezel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeWidth multiplier:1.f constant:0];
        square.priority = 997.f;
        [bezelConstraints addObject:square];
    }

    // Top and bottom spacing
    [topSpacer addConstraint:[NSLayoutConstraint constraintWithItem:topSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:margin]];
    [bottomSpacer addConstraint:[NSLayoutConstraint constraintWithItem:bottomSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.f constant:margin]];
    // Top and bottom spaces should be equal
    [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:topSpacer attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:bottomSpacer attribute:NSLayoutAttributeHeight multiplier:1.f constant:0.f]];

    // Layout subviews in bezel
    NSMutableArray *paddingConstraints = [NSMutableArray new];
    [subviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop) {
        // Center in bezel
        [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeCenterX multiplier:1.f constant:0.f]];
        // Ensure the minimum edge margin is kept
        [bezelConstraints addObjectsFromArray:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(>=margin)-[view]-(>=margin)-|" options:0 metrics:metrics views:NSDictionaryOfVariableBindings(view)]];
        // Element spacing
        if (idx == 0) {
            // First, ensure spacing to bezel edge
            [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeTop multiplier:1.f constant:0.f]];
        } else if (idx == subviews.count - 1) {
            // Last, ensure spacing to bezel edge
            [bezelConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:bezel attribute:NSLayoutAttributeBottom multiplier:1.f constant:0.f]];
        }
        if (idx > 0) {
            // Has previous
            NSLayoutConstraint *padding = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:subviews[idx - 1] attribute:NSLayoutAttributeBottom multiplier:1.f constant:0.f];
            [bezelConstraints addObject:padding];
            [paddingConstraints addObject:padding];
        }
    }];

    [bezel addConstraints:bezelConstraints];
    self.bezelConstraints = bezelConstraints;

    self.paddingConstraints = [paddingConstraints copy];
    [self updatePaddingConstraints];

    [super updateConstraints];
}

- (void)layoutSubviews {
    // There is no need to update constraints if they are going to
    // be recreated in [super layoutSubviews] due to needsUpdateConstraints being set.
    // This also avoids an issue on iOS 8, where updatePaddingConstraints
    // would trigger a zombie object access.
    if (!self.needsUpdateConstraints) {
        [self updatePaddingConstraints];
    }
    [super layoutSubviews];
}

- (void)updatePaddingConstraints {
    // Set padding dynamically, depending on whether the view is visible or not
    __block BOOL hasVisibleAncestors = NO;
    [self.paddingConstraints enumerateObjectsUsingBlock:^(NSLayoutConstraint *padding, NSUInteger idx, BOOL *stop) {
        UIView *firstView = (UIView *)padding.firstItem;
        UIView *secondView = (UIView *)padding.secondItem;
        BOOL firstVisible = !firstView.hidden && !CGSizeEqualToSize(firstView.intrinsicContentSize, CGSizeZero);
        BOOL secondVisible = !secondView.hidden && !CGSizeEqualToSize(secondView.intrinsicContentSize, CGSizeZero);
        // Set if both views are visible or if there's a visible view on top that doesn't have padding
        // added relative to the current view yet
        padding.constant = (firstVisible && (secondVisible || hasVisibleAncestors)) ? MBDefaultPadding : 0.f;
        hasVisibleAncestors |= secondVisible;
    }];
}

- (void)applyPriority:(UILayoutPriority)priority toConstraints:(NSArray *)constraints {
    for (NSLayoutConstraint *constraint in constraints) {
        constraint.priority = priority;
    }
}

#pragma mark - Properties

- (void)setMode:(MBProgressHUDMode)mode {
    if (mode != _mode) {
        _mode = mode;
        [self updateIndicators];
    }
}

- (void)setCustomView:(UIView *)customView {
    if (customView != _customView) {
        _customView = customView;
        if (self.mode == MBProgressHUDModeCustomView) {
            [self updateIndicators];
        }
    }
}

- (void)setOffset:(CGPoint)offset {
    if (!CGPointEqualToPoint(offset, _offset)) {
        _offset = offset;
        [self setNeedsUpdateConstraints];
    }
}

- (void)setMargin:(CGFloat)margin {
    if (margin != _margin) {
        _margin = margin;
        [self setNeedsUpdateConstraints];
    }
}

- (void)setMinSize:(CGSize)minSize {
    if (!CGSizeEqualToSize(minSize, _minSize)) {
        _minSize = minSize;
        [self setNeedsUpdateConstraints];
    }
}

- (void)setSquare:(BOOL)square {
    if (square != _square) {
        _square = square;
        [self setNeedsUpdateConstraints];
    }
}

- (void)setProgressObjectDisplayLink:(CADisplayLink *)progressObjectDisplayLink {
    if (progressObjectDisplayLink != _progressObjectDisplayLink) {
        [_progressObjectDisplayLink invalidate];

        _progressObjectDisplayLink = progressObjectDisplayLink;

        [_progressObjectDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

- (void)setProgressObject:(NSProgress *)progressObject {
    if (progressObject != _progressObject) {
        _progressObject = progressObject;
        [self setNSProgressDisplayLinkEnabled:YES];
    }
}

- (void)setProgress:(float)progress {
    if (progress != _progress) {
        _progress = progress;
        UIView *indicator = self.indicator;
        if ([indicator respondsToSelector:@selector(setProgress:)]) {
            [(id)indicator setValue:@(self.progress) forKey:@"progress"];
        }
    }
}

- (void)setContentColor:(UIColor *)contentColor {
    if (contentColor != _contentColor && ![contentColor isEqual:_contentColor]) {
        _contentColor = contentColor;
        [self updateViewsForColor:contentColor];
    }
}

- (void)setDefaultMotionEffectsEnabled:(BOOL)defaultMotionEffectsEnabled {
    if (defaultMotionEffectsEnabled != _defaultMotionEffectsEnabled) {
        _defaultMotionEffectsEnabled = defaultMotionEffectsEnabled;
        [self updateBezelMotionEffects];
    }
}

#pragma mark - NSProgress

- (void)setNSProgressDisplayLinkEnabled:(BOOL)enabled {
    // We're using CADisplayLink, because NSProgress can change very quickly and observing it may starve the main thread,
    // so we're refreshing the progress only every frame draw
    if (enabled && self.progressObject) {
        // Only create if not already active.
        if (!self.progressObjectDisplayLink) {
            self.progressObjectDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateProgressFromProgressObject)];
        }
    } else {
        self.progressObjectDisplayLink = nil;
    }
}

- (void)updateProgressFromProgressObject {
    self.progress = self.progressObject.fractionCompleted;
}

#pragma mark - Notifications

- (void)registerForNotifications {
#if !TARGET_OS_TV && !TARGET_OS_MACCATALYST
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self selector:@selector(statusBarOrientationDidChange:)
               name:UIDeviceOrientationDidChangeNotification object:nil];
#endif
}

- (void)unregisterFromNotifications {
#if !TARGET_OS_TV && !TARGET_OS_MACCATALYST
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
#endif
}

#if !TARGET_OS_TV && !TARGET_OS_MACCATALYST
- (void)statusBarOrientationDidChange:(NSNotification *)notification {
    UIView *superview = self.superview;
    if (!superview) {
        return;
    } else {
        [self updateForCurrentOrientationAnimated:YES];
    }
}
#endif

- (void)updateForCurrentOrientationAnimated:(BOOL)animated {
    // Stay in sync with the superview in any case
    if (self.superview) {
        self.frame = self.superview.bounds;
    }

    // Not needed on iOS 8+, compile out when the deployment target allows,
    // to avoid sharedApplication problems on extension targets
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 80000
    // Only needed pre iOS 8 when added to a window
    BOOL iOS8OrLater = kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0;
    if (iOS8OrLater || ![self.superview isKindOfClass:[UIWindow class]]) return;

    // Make extension friendly. Will not get called on extensions (iOS 8+) due to the above check.
    // This just ensures we don't get a warning about extension-unsafe API.
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if (!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) return;

    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    UIInterfaceOrientation orientation = application.statusBarOrientation;
    CGFloat radians = 0;

    if (UIInterfaceOrientationIsLandscape(orientation)) {
        radians = orientation == UIInterfaceOrientationLandscapeLeft ? -(CGFloat)M_PI_2 : (CGFloat)M_PI_2;
        // Window coordinates differ!
        self.bounds = CGRectMake(0, 0, self.bounds.size.height, self.bounds.size.width);
    } else {
        radians = orientation == UIInterfaceOrientationPortraitUpsideDown ? (CGFloat)M_PI : 0.f;
    }

    if (animated) {
        [UIView animateWithDuration:0.3 animations:^{
            self.transform = CGAffineTransformMakeRotation(radians);
        }];
    } else {
        self.transform = CGAffineTransformMakeRotation(radians);
    }
#endif
}

@end


@implementation MBRoundProgressView

#pragma mark - Lifecycle

- (id)init {
    return [self initWithFrame:CGRectMake(0.f, 0.f, 37.f, 37.f)];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        _progress = 0.f;
        _annular = NO;
        _progressTintColor = [[UIColor alloc] initWithWhite:1.f alpha:1.f];
        _backgroundTintColor = [[UIColor alloc] initWithWhite:1.f alpha:.1f];
    }
    return self;
}

#pragma mark - Layout

- (CGSize)intrinsicContentSize {
    return CGSizeMake(37.f, 37.f);
}

#pragma mark - Properties

- (void)setProgress:(float)progress {
    if (progress != _progress) {
        _progress = progress;
        [self setNeedsDisplay];
    }
}

- (void)setProgressTintColor:(UIColor *)progressTintColor {
    NSAssert(progressTintColor, @"The color should not be nil.");
    if (progressTintColor != _progressTintColor && ![progressTintColor isEqual:_progressTintColor]) {
        _progressTintColor = progressTintColor;
        [self setNeedsDisplay];
    }
}

- (void)setBackgroundTintColor:(UIColor *)backgroundTintColor {
    NSAssert(backgroundTintColor, @"The color should not be nil.");
    if (backgroundTintColor != _backgroundTintColor && ![backgroundTintColor isEqual:_backgroundTintColor]) {
        _backgroundTintColor = backgroundTintColor;
        [self setNeedsDisplay];
    }
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    if (_annular) {
        // Draw background
        CGFloat lineWidth = 2.f;
        UIBezierPath *processBackgroundPath = [UIBezierPath bezierPath];
        processBackgroundPath.lineWidth = lineWidth;
        processBackgroundPath.lineCapStyle = kCGLineCapButt;
        CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        CGFloat radius = (self.bounds.size.width - lineWidth)/2;
        CGFloat startAngle = - ((float)M_PI / 2); // 90 degrees
        CGFloat endAngle = (2 * (float)M_PI) + startAngle;
        [processBackgroundPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
        [_backgroundTintColor set];
        [processBackgroundPath stroke];
        // Draw progress
        UIBezierPath *processPath = [UIBezierPath bezierPath];
        processPath.lineCapStyle = kCGLineCapSquare;
        processPath.lineWidth = lineWidth;
        endAngle = (self.progress * 2 * (float)M_PI) + startAngle;
        [processPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
        [_progressTintColor set];
        [processPath stroke];
    } else {
        // Draw background
        CGFloat lineWidth = 2.f;
        CGRect allRect = self.bounds;
        CGRect circleRect = CGRectInset(allRect, lineWidth/2.f, lineWidth/2.f);
        CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        [_progressTintColor setStroke];
        [_backgroundTintColor setFill];
        CGContextSetLineWidth(context, lineWidth);
        CGContextStrokeEllipseInRect(context, circleRect);
        // 90 degrees
        CGFloat startAngle = - ((float)M_PI / 2.f);
        // Draw progress
        UIBezierPath *processPath = [UIBezierPath bezierPath];
        processPath.lineCapStyle = kCGLineCapButt;
        processPath.lineWidth = lineWidth * 2.f;
        CGFloat radius = (CGRectGetWidth(self.bounds) / 2.f) - (processPath.lineWidth / 2.f);
        CGFloat endAngle = (self.progress * 2.f * (float)M_PI) + startAngle;
        [processPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
        // Ensure that we don't get color overlapping when _progressTintColor alpha < 1.f.
        CGContextSetBlendMode(context, kCGBlendModeCopy);
        [_progressTintColor set];
        [processPath stroke];
    }
}

@end


@implementation MBBarProgressView

#pragma mark - Lifecycle

- (id)init {
    return [self initWithFrame:CGRectMake(.0f, .0f, 120.0f, 20.0f)];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _progress = 0.f;
        _lineColor = [UIColor whiteColor];
        _progressColor = [UIColor whiteColor];
        _progressRemainingColor = [UIColor clearColor];
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}

#pragma mark - Layout

- (CGSize)intrinsicContentSize {
    return CGSizeMake(120.f, 10.f);
}

#pragma mark - Properties

- (void)setProgress:(float)progress {
    if (progress != _progress) {
        _progress = progress;
        [self setNeedsDisplay];
    }
}

- (void)setProgressColor:(UIColor *)progressColor {
    NSAssert(progressColor, @"The color should not be nil.");
    if (progressColor != _progressColor && ![progressColor isEqual:_progressColor]) {
        _progressColor = progressColor;
        [self setNeedsDisplay];
    }
}

- (void)setProgressRemainingColor:(UIColor *)progressRemainingColor {
    NSAssert(progressRemainingColor, @"The color should not be nil.");
    if (progressRemainingColor != _progressRemainingColor && ![progressRemainingColor isEqual:_progressRemainingColor]) {
        _progressRemainingColor = progressRemainingColor;
        [self setNeedsDisplay];
    }
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetLineWidth(context, 2);
    CGContextSetStrokeColorWithColor(context,[_lineColor CGColor]);
    CGContextSetFillColorWithColor(context, [_progressRemainingColor CGColor]);

    // Draw background and Border
    CGFloat radius = (rect.size.height / 2) - 2;
    CGContextMoveToPoint(context, 2, rect.size.height/2);
    CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius);
    CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius);
    CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius);
    CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height/2, radius);
    CGContextDrawPath(context, kCGPathFillStroke);

    CGContextSetFillColorWithColor(context, [_progressColor CGColor]);
    radius = radius - 2;
    CGFloat amount = self.progress * rect.size.width;

    // Progress in the middle area
    if (amount >= radius + 4 && amount <= (rect.size.width - radius - 4)) {
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
        CGContextAddLineToPoint(context, amount, 4);
        CGContextAddLineToPoint(context, amount, radius + 4);

        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
        CGContextAddLineToPoint(context, amount, rect.size.height - 4);
        CGContextAddLineToPoint(context, amount, radius + 4);

        CGContextFillPath(context);
    }

    // Progress in the right arc
    else if (amount > radius + 4) {
        CGFloat x = amount - (rect.size.width - radius - 4);

        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
        CGContextAddLineToPoint(context, rect.size.width - radius - 4, 4);
        CGFloat angle = -acos(x/radius);
        if (isnan(angle)) angle = 0;
        CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height/2, radius, M_PI, angle, 0);
        CGContextAddLineToPoint(context, amount, rect.size.height/2);

        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
        CGContextAddLineToPoint(context, rect.size.width - radius - 4, rect.size.height - 4);
        angle = acos(x/radius);
        if (isnan(angle)) angle = 0;
        CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height/2, radius, -M_PI, angle, 1);
        CGContextAddLineToPoint(context, amount, rect.size.height/2);

        CGContextFillPath(context);
    }

    // Progress is in the left arc
    else if (amount < radius + 4 && amount > 0) {
        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
        CGContextAddLineToPoint(context, radius + 4, rect.size.height/2);

        CGContextMoveToPoint(context, 4, rect.size.height/2);
        CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
        CGContextAddLineToPoint(context, radius + 4, rect.size.height/2);

        CGContextFillPath(context);
    }
}

@end


@interface MBBackgroundView ()

@property UIVisualEffectView *effectView;

@end


@implementation MBBackgroundView

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _style = MBProgressHUDBackgroundStyleBlur;
        if (@available(iOS 13.0, *)) {
            #if TARGET_OS_TV
            _blurEffectStyle = UIBlurEffectStyleRegular;
            #else
            _blurEffectStyle = UIBlurEffectStyleSystemThickMaterial;
            #endif
            // Leaving the color unassigned yields best results.
        } else {
            _blurEffectStyle = UIBlurEffectStyleLight;
            _color = [UIColor colorWithWhite:0.8f alpha:0.6f];
        }

        self.clipsToBounds = YES;

        [self updateForBackgroundStyle];
    }
    return self;
}

#pragma mark - Layout

- (CGSize)intrinsicContentSize {
    // Smallest size possible. Content pushes against this.
    return CGSizeZero;
}

#pragma mark - Appearance

- (void)setStyle:(MBProgressHUDBackgroundStyle)style {
    if (_style != style) {
        _style = style;
        [self updateForBackgroundStyle];
    }
}

- (void)setColor:(UIColor *)color {
    NSAssert(color, @"The color should not be nil.");
    if (color != _color && ![color isEqual:_color]) {
        _color = color;
        [self updateViewsForColor:color];
    }
}

- (void)setBlurEffectStyle:(UIBlurEffectStyle)blurEffectStyle {
    if (_blurEffectStyle == blurEffectStyle) {
        return;
    }

    _blurEffectStyle = blurEffectStyle;

    [self updateForBackgroundStyle];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Views

- (void)updateForBackgroundStyle {
    [self.effectView removeFromSuperview];
    self.effectView = nil;

    MBProgressHUDBackgroundStyle style = self.style;
    if (style == MBProgressHUDBackgroundStyleBlur) {
        UIBlurEffect *effect =  [UIBlurEffect effectWithStyle:self.blurEffectStyle];
        UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
        [self insertSubview:effectView atIndex:0];
        effectView.frame = self.bounds;
        effectView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = self.color;
        self.layer.allowsGroupOpacity = NO;
        self.effectView = effectView;
    } else {
        self.backgroundColor = self.color;
    }
}

- (void)updateViewsForColor:(UIColor *)color {
    if (self.style == MBProgressHUDBackgroundStyleBlur) {
        self.backgroundColor = self.color;
    } else {
        self.backgroundColor = self.color;
    }
}

@end


@implementation MBProgressHUDRoundedButton

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CALayer *layer = self.layer;
        layer.borderWidth = 1.f;
    }
    return self;
}

#pragma mark - Layout

- (void)layoutSubviews {
    [super layoutSubviews];
    // Fully rounded corners
    CGFloat height = CGRectGetHeight(self.bounds);
    self.layer.cornerRadius = ceil(height / 2.f);
}

- (CGSize)intrinsicContentSize {
    // Only show if we have associated control events and a title
    if ((self.allControlEvents == 0) || ([self titleForState:UIControlStateNormal].length == 0))
		return CGSizeZero;
    CGSize size = [super intrinsicContentSize];
    // Add some side padding
    size.width += 20.f;
    return size;
}

#pragma mark - Color

- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state {
    [super setTitleColor:color forState:state];
    // Update related colors
    [self setHighlighted:self.highlighted];
    self.layer.borderColor = color.CGColor;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    UIColor *baseColor = [self titleColorForState:UIControlStateSelected];
    self.backgroundColor = highlighted ? [baseColor colorWithAlphaComponent:0.1f] : [UIColor clearColor];
}

@end
//
//  NYDeviceToken+DI.swift
//  NineyiAppShop
//
//  Created by Alex Lin on 2020/6/20.
//  Copyright © 2020 91App. All rights reserved.
//

import NYCore
import AdSupport

extension DeviceToken: DIProcess {
    static func handleDI() {
        self.uploader = DeviceTokenUploader()
    }
}

// MARK: -
struct DeviceTokenUploader: NYCore.DeviceTokenUploader {
    func upload(token: String, completion: @escaping (Bool) -> Void) {
        // Note: appVer 應該要改寫在 NYInfoPlist 才是. (目前沒)
        //       guid 應該要另外寫 class/struct 取得？
        let guid = NYCookieManager.shared()?.cookieValue(fromLocal: kCOOKIE_NAME_GUID) ?? ""
        let adID = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        let appVer = NYGlobalData.appVersionString() ?? ""

        // Create Params
        let params: [AnyHashable: Any] = [
            "GUID" : guid,
            "token": token,
            "AdvertisingId": adID,
            "appVer": appVer
        ]
        
        // Call API
        NYHTTPSClient.shared()?.get91APIObj("APPNotification/UpdateToken/", parameters: params, success: { (_, response: NYAPIObj<String?>) in
            // Check return code
            let isSuccessed = response.returnCode == APIReturnCode.api0001
            completion(isSuccessed)
        }, failure: { (_, _) in
            // Fail
            completion(false)
        })
    }
}
//
//  NYCDNHTTPClient.h
//  NineYiShopping
//
//  Created by 陸韻涵 on 2014/7/16.
//  Copyright (c) 2014年 91mai. All rights reserved.
//

#import "NYHTTPSClient.h"

@interface NYCDNHTTPClient : NYHTTPSClient

+ (NYCDNHTTPClient *)sharedClient;

@end
//
//  NYCookieManager.m
//  NineYiShopping
//
//  Created by Daniel Kao on 2014/11/21.
//  Copyright (c) 2014年 91mai. All rights reserved.
//

#import "NYCookieManager.h"
#import "NYDataProvider.h"
#import "NYGlobalData.h"
#import "NYBaseURLConfig.h"

// NOTE: CookieManager的寫法目前無法把NYUserDefaultsHelper拿掉，可能需要大改
// (可以寫動態selector來取userDefault中的method，但不大好)
#import "NYUserDefault.h"
#import "NYUserDefaultsHelper.h"

#import "NYKeychainHelper.h"
#import "NYNotificationExtensionKeychainHelper.h"

#import <NYCore/NSDateFormatter+Formatter.h>
#import <Webkit/WebKit.h>
#import <NYCore/NYCore-Swift.h>


static NSString * const kExpirationDateSuffix = @"-expiratio-date";

NSString * const kNYCookieStatusServerReturnsEmpty = @"NYCookieStatusServerReturnsEmpty";

NSString * const kCOOKIE_NAME_AUTH                      = @"auth";
NSString * const kCOOKIE_NAME_U_AUTH                    = @"uAUTH";
NSString * const kCOOKIE_NAME_U_AUTH_EXPRESS            = @"uAUTH_express";
NSString * const kCOOKIE_NAME_GUID                      = @"GUID";
NSString * const kCOOKIE_NAME_APP_VER                   = @"appVer";
NSString * const kCOOKIE_NAME_TRACE_FR                  = @"trace-fr";

NSString * const kCOOKIE_FR_CODE_DEFAULT                = @"direct";
NSString * const kCOOKIE_FR_CODE_REF                    = @"ref";

@interface NYCookieManager ()
@property (nonatomic, strong) NSMutableDictionary *cookieDict;

- (NSString *)expirationDateKeyForCookieName:(NSString *)cookieName;
- (NSArray *)filteredCookiesWithPredicateString:(NSString *)predicateString;
- (void)loadCookiesFromDisk;

- (void)restoreCookies;
- (void)overwriteSpecificCookies;
- (void)registerAppIfGUIDNotExist;
- (void)updateServerUDIDIfVDIDChanged;
- (void)updateUauthFromLocalGUID;
@end

@implementation NYCookieManager

+ (NYCookieManager *)sharedManager {
    static NYCookieManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[NYCookieManager alloc] init];
    });
    return _sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        [self loadCookiesFromDisk];
    }
    return self;
}

- (void)setupCookies {
    // The following methods should be excuted synchronously.
    [self restoreCookies];
    [self registerAppIfGUIDNotExist];
    [self updateServerUDIDIfVDIDChanged];
    [self updateUauthFromLocalGUID];
    [self overwriteSpecificCookies];
}

- (NSArray *)domainNames {
    NSArray <NSString *> *domains = [NYBaseURLConfig allDomains];
    //由於 mobile domain 是 run time 從 API 拿到的，如果不放在這裡跟其他 domain 一起處理, 就必須在所有登入的地方都 manually set cookie to mobile domain，會顯得很分散
    NSString *mobileDomain = [NYUserDefault mobileDomainUrlString];
    if ([mobileDomain length] > 0 &&
        ![domains containsObject:mobileDomain]) {
        domains = [domains arrayByAddingObject:mobileDomain];
    }

    NSString *officialShopDomain = [NYUserDefault officialShopUrlString];
    if ([officialShopDomain length] > 0 &&
        ![domains containsObject:officialShopDomain]) {
        domains = [domains arrayByAddingObject:officialShopDomain];
    }

    return domains;
}

- (NSArray *)domainNamesExcludeCDNDomain {
    NSMutableArray <NSString *> *allDomains = [NYBaseURLConfig allDomains].mutableCopy;
    [allDomains removeObject:[NYBaseURLConfig domainNameForCDNServer]];
    return allDomains;
}

- (NSArray *)cookieNames {
    return @[kCOOKIE_NAME_GUID, kCOOKIE_NAME_U_AUTH, kCOOKIE_NAME_AUTH, kCOOKIE_NAME_APP_VER, kCOOKIE_NAME_TRACE_FR];
}

- (NSDictionary *)cookieDict {
    return _cookieDict;
}

- (NSString *)cookieValueFromLocal:(NSString *)cookieName {
    NSString *cookieValue = _cookieDict[cookieName];
    if (!cookieValue || [cookieValue hasPrefix:kNYCookieStatusServerReturnsEmpty]) {
        cookieValue = @"";
    }
    return cookieValue;
}

- (NSDictionary *)cookiesByCookieName:(NSString *)cookieName {
    NSArray *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"name LIKE '%@'", cookieName]];
    
    __block NSMutableDictionary *cookiePairs = @{}.mutableCopy;
    [matchedCookies enumerateObjectsUsingBlock:^(NSHTTPCookie *cookie, NSUInteger idx, BOOL *stop) {
        NSString *cookieDomain = cookie.domain;
        NSString *cookieValue = cookie.value;
        [cookiePairs addEntriesFromDictionary:@{cookieDomain:cookieValue}];
    }];
    
    return cookiePairs;
}

- (NSDictionary *)cookiesByDomain:(NSString *)domainName {
    NSArray *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"domain == '%@'", domainName]];
    
    __block NSMutableDictionary *cookiePairs = @{}.mutableCopy;
    [matchedCookies enumerateObjectsUsingBlock:^(NSHTTPCookie *cookie, NSUInteger idx, BOOL *stop) {
        NSString *cookieName = cookie.name;
        NSString *cookieValue = cookie.value;
        [cookiePairs addEntriesFromDictionary:@{cookieName:cookieValue}];
    }];
    
    return cookiePairs;
}

- (NSString *)cookieByCookieName:(NSString *)cookieName domain:(NSString *)domainName {
    NSArray *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"name == '%@' and domain == '%@'", cookieName, domainName]];
    NSHTTPCookie *cookie = [matchedCookies lastObject];
    return cookie.value;
}

- (NSString *)cookieByCookieName:(NSString *)cookieName domain:(NSString *)domainName path:(NSString *)path {
    NSArray *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"name == '%@' and domain == '%@' and path == '%@'", cookieName, domainName, path]];
    NSHTTPCookie *cookie = [matchedCookies lastObject];
    return cookie.value;
}

- (void)setCookieValue:(NSString *)cookieValue forCookieName:(NSString *)cookieName {
    [self setCookieValue:cookieValue forCookieName:cookieName expirationDate:nil];
}

- (void)setCookieValue:(NSString *)cookieValue forCookieName:(NSString *)cookieName expirationDate:(NSDate *)expirationDate {
    if (!cookieValue || !cookieName) {
        return;
    } else if (cookieValue.length == 0 || [cookieValue isEqualToString:kNYCookieStatusServerReturnsEmpty]) {
        if ([cookieName isEqualToString:kCOOKIE_NAME_AUTH]) {
            [NYCrashlyticsHelper recordWithError:[NSError errorWithDomain:@"NYCookieManager.emptyAuth" code:0 userInfo:@{}]];
        }
    }
    
    if (!expirationDate || [[NSDate date] timeIntervalSinceDate:expirationDate] < 0) {
        [self setNSHTTPCookieWithCookieName:cookieName andValue:cookieValue];
    }
    
    if ([cookieName isEqualToString:kCOOKIE_NAME_GUID] || [cookieName isEqualToString:kCOOKIE_NAME_U_AUTH]) {
        [self setKeychainValue:cookieValue forKey:cookieName];
    }
    
    _cookieDict[cookieName] = cookieValue;
    
    [NYUserDefaultsHelper setObject:cookieValue forKey:cookieName];
    if (expirationDate) {
        [NYUserDefaultsHelper setObject:expirationDate forKey:[self expirationDateKeyForCookieName:cookieName]];
    }
}

- (void)setFRAsRefAtTime:(NSDate* )setDate {
    [self setCookieValue:kCOOKIE_FR_CODE_REF forCookieName:kCOOKIE_NAME_TRACE_FR expirationDate:[setDate dateByAddingTimeInterval:24*60*60]];
}

- (void)removeCookieWithCookieName:(NSString *)cookieName {
    [self removeCookieWithCookieName:cookieName shouldRemoveFromNSUserDefaults:YES];
    
    if ([cookieName isEqualToString:kCOOKIE_NAME_AUTH]) {
        [NYCrashlyticsHelper recordWithError:[NSError errorWithDomain:@"NYCookieManager.removeAuth" code:0 userInfo:@{}]];
    }
}

- (void)removeCookieWithCookieName:(NSString *)cookieName
    shouldRemoveFromNSUserDefaults:(BOOL)shouldRemoveFromNSUserDefaults {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray<NSHTTPCookie *> *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"name == '%@'", cookieName]];
    [matchedCookies enumerateObjectsUsingBlock:^(NSHTTPCookie *cookie, NSUInteger idx, BOOL *stop) {
        // Remove cookie from NSHTTPCookieStorage
        [cookieStorage deleteCookie:cookie];
    }];
    
    [_cookieDict removeObjectForKey:cookieName];

    if (shouldRemoveFromNSUserDefaults) {
        [NYUserDefaultsHelper removeObjectForKey:cookieName];
    }
}

- (void)resetFRCookie {
    NSString* expirationDateKey = [self expirationDateKeyForCookieName:kCOOKIE_NAME_TRACE_FR];
    
    // 1. Remove Cookie from NSHTTPCookieStorage
    [self removeCookieWithCookieName:kCOOKIE_NAME_TRACE_FR shouldRemoveFromNSUserDefaults:NO];
    
    // 2. Get latest Cookie from NSUserDefaults
    NSDate *expirationDate = [NYUserDefaultsHelper objectForKey:expirationDateKey];
    NSString *cookieValue = [NYUserDefaultsHelper objectForKey:kCOOKIE_NAME_TRACE_FR];
    
    // 3. Set Cookie in NSHTTPCookieStorage if cookie is up to date
    BOOL expired = expirationDate &&
    [expirationDate timeIntervalSinceDate:[NSDate date]] < 0; // 20150202 - 20150203 < 0
    
    BOOL hasCookieValue = cookieValue && cookieValue.length > 0;
    if (expired || !hasCookieValue || [cookieValue isEqualToString:@"<null>"]) {
        cookieValue = kCOOKIE_FR_CODE_DEFAULT; // bts 8583, 8585. If expired, set FR code to DEFAULT
        expirationDate = [[NSDate date] dateByAddingTimeInterval:24*60*60]; // bts 8585 (Comment) FR為direct時，需顯示expiry date，時間為下單後的24小時
    }
    
    [self setNSHTTPCookieWithCookieName:kCOOKIE_NAME_TRACE_FR andValue:cookieValue];
    _cookieDict[kCOOKIE_NAME_TRACE_FR] = cookieValue;
    
    [NYUserDefaultsHelper setObject:cookieValue forKey:kCOOKIE_NAME_TRACE_FR];
    if (expirationDate) {
        [NYUserDefaultsHelper setObject:expirationDate forKey:expirationDateKey];
    } else {
        [NYUserDefaultsHelper removeObjectForKey:expirationDateKey];
    }
}

- (void)printNSHTTPCookies {
#ifdef DEBUG
        NSLog(@"=================");
        NSHTTPCookieStorage *sharedHTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSArray *cookies = [sharedHTTPCookieStorage cookies];
        NSEnumerator *enumerator = [cookies objectEnumerator];
        NSHTTPCookie *cookie;
        while (cookie = [enumerator nextObject]) {
            NSLog(@"-----------------------------");
            NSLog(@"Domain: %@", cookie.domain);
            NSLog(@"CookieName: %@", cookie.name);
            NSLog(@"CookieValue: %@", cookie.value);
            NSLog(@"[cookie description] %@",[cookie description]);
        }
        NSLog(@"=================");
#endif
}

- (NSString *)expirationDateStringForCookieName:(NSString *)cookieName {
    NSDate *expirationDate = [NYUserDefaultsHelper objectForKey:[self expirationDateKeyForCookieName:cookieName]];
    NSDateFormatter *dateFormatter = [NSDateFormatter dateFormatterToSecond];

    return [dateFormatter stringFromDate:expirationDate];
}

- (NSString *)localVDID {
    NSString *vdid = [NYUserDefault VDID];
    if (!vdid) {
        vdid = @"";
    }
    return vdid;
}

- (NSString *)VDID {
    return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}


#pragma mark - Private Helpers

- (NSString *)expirationDateKeyForCookieName:(NSString *)cookieName {
    return [cookieName stringByAppendingString:kExpirationDateSuffix];
}

- (NSArray *)filteredCookiesWithPredicateString:(NSString *)predicateString {
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    NSPredicate *filter = [NSPredicate predicateWithFormat:predicateString];
    NSArray *matchedCookies = [cookies filteredArrayUsingPredicate:filter];

    return matchedCookies;
}

- (void)loadCookiesFromDisk {
    
    BOOL (^isCookieValueValid)(id cookieValue) = ^BOOL(id cookieValue) {
        return [cookieValue isKindOfClass:[NSString class]] && [(NSString *)cookieValue length] > 0;
    };
    
    self.cookieDict = @{}.mutableCopy;
    NSMutableDictionary *cookies = _cookieDict;
    [[self cookieNames] enumerateObjectsUsingBlock:^(NSString *cookieName, NSUInteger idx, BOOL *stop) {

        BOOL isCookieNameGUIDorUauth = [cookieName isEqualToString:kCOOKIE_NAME_GUID] || [cookieName isEqualToString:kCOOKIE_NAME_U_AUTH];
        if (isCookieNameGUIDorUauth) {
            NSString *cookieValueFromKeychain = [self keychainValueForKey:cookieName];
            if (isCookieValueValid(cookieValueFromKeychain)) {
                [cookies addEntriesFromDictionary:@{cookieName:cookieValueFromKeychain}];
            }
        } else {
            NSString *cookieValue = [NYUserDefaultsHelper objectForKey:cookieName];
            if (isCookieValueValid(cookieValue)) {
                [cookies addEntriesFromDictionary:@{cookieName:cookieValue}];
            }
        }
    }];
}

- (void)restoreCookies {
    typeof(self) __weak weakSelf = self;
    [_cookieDict.copy enumerateKeysAndObjectsUsingBlock:^(NSString *cookieName, NSString *cookieValue, BOOL *stop) {
        [weakSelf setCookieValue:cookieValue forCookieName:cookieName];
    }];
}

- (void)restoreDictCookies:(NSString *)cookieName value:(NSString *)cookieValue {
    _cookieDict[cookieName] = cookieValue;
}

- (void)forceUpdateUAuth {
    /*
     只有 HTTPCookieStorage 裡的 uAuth 跟我們自己存的 uAuth 不一樣時才要拿自己存的蓋過去，避免不必要的 set 動作（somehow API request 可能會沒有帶 uAuth，此時 response 會給一組臨時的 uAuth 並要求 setCookie，這個時候就會被蓋成我們不想要的資料，所以需要再覆蓋回來）
     */
    __block BOOL shouldUpdateUAuth = NO;
    __block NSString *uAuth = self.cookieDict[kCOOKIE_NAME_U_AUTH];
    if (uAuth == nil) { return; }
    NSArray<NSHTTPCookie *> *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"name == '%@'", kCOOKIE_NAME_U_AUTH]];
    [matchedCookies enumerateObjectsUsingBlock:^(NSHTTPCookie *cookie, NSUInteger idx, BOOL *stop) {
        if ([uAuth isEqualToString:cookie.value] == NO) {
            shouldUpdateUAuth = YES;
            *stop = YES;
        }
    }];
    
    if (shouldUpdateUAuth) {
        [self setNSHTTPCookieWithCookieName:kCOOKIE_NAME_U_AUTH
                                   andValue:uAuth];
    }
}

- (void)updateUauthFromLocalGUID {
    NSString *guid = [self cookieValueFromLocal:kCOOKIE_NAME_GUID];
    if (guid.length > 0) {
        [[NYDataProvider sharedInstance] getUauthWithCompletionHandler:^(NSDictionary *data, NSError *error) {
            NSDictionary *response = data[kDATA_KEY];
            if ([response[@"ReturnCode"] isEqualToString:@"API0001"]) {
                NSString *uAuth = response[@"uAUTH"];
                if ([uAuth isKindOfClass:[NSString class]] && uAuth.length > 0) {
                    [self setCookieValue:uAuth forCookieName:kCOOKIE_NAME_U_AUTH];
                }
            }
        }];
    }
}

- (void)updateServerUDIDIfVDIDChanged {
    NSString *VDID = [self VDID];
    
    BOOL isVDIDChanged = ![VDID isEqualToString:[self localVDID]];
    if (isVDIDChanged) {
        [[NYDataProvider sharedInstance] updateServerUDIDWithCompletionHandler:^(NSDictionary *data, NSError *error) {
            NSDictionary *response = data[kDATA_KEY];
            if ([response isKindOfClass:[NSDictionary class]] && [response[@"ReturnCode"] isEqualToString:@"API0001"]) {
                [NYUserDefault setVDID:VDID];
            }
        }];
    }
}

- (void)registerAppIfGUIDNotExist {
    NSInteger count = 0;
    // 如果沒拿到GUID, retry 3次。
    while ([[self cookieValueFromLocal:kCOOKIE_NAME_GUID] length] == 0 && count < 3) {
        NSString *guid = [self cookieValueFromLocal:kCOOKIE_NAME_GUID];
        
        if ([guid isEqualToString:@""]) {
            [self registerAPP];
        }
        
        count++;
    }
}

- (void)setAppVerCookie {
    // Make sure appVer cookie get updated
    NSString *appVer = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    [self setCookieValue:appVer forCookieName:kCOOKIE_NAME_APP_VER];
}

- (void)overwriteSpecificCookies {
    [self setAppVerCookie];
}

- (void)registerAPP {
    // 第一次使用
    NSString *VDID = [self VDID];
    
    typeof(self) __weak weakSelf = self;
    [[NYDataProvider sharedInstance]
     registerAppWithVDID:VDID
     shopId:[NYGlobalData shopId]
     platform:@"iOS"
     sendSynchronousRequest:YES
     completionHandler:^(NSDictionary *data, NSError *error) {
        dispatch_barrier_sync(dispatch_queue_create("com.nineyi.SerialQueue", DISPATCH_QUEUE_SERIAL), ^{
            // App 首次開啟，會 retry 3 次，此處先不顯示 error message
            [weakSelf handleRegisterResponse:data shouldAlert:NO vdid:VDID];
        });
     }];
}

- (void)registerAPPWithCompletion:(void(^)(void))completion {
    NSString *VDID = [self VDID];
    
    typeof(self) __weak weakSelf = self;
    [[NYDataProvider sharedInstance]
     registerAppWithVDID:VDID
     shopId:[NYGlobalData shopId]
     platform:@"iOS"
     sendSynchronousRequest:NO
     completionHandler:^(NSDictionary *data, NSError *error) {
        // 從 CMSLaunchViewController 來的，顯示 error message
        [weakSelf handleRegisterResponse:data shouldAlert:YES vdid:VDID];
        
        completion();
     }];
}

- (void)handleRegisterResponse:(NSDictionary *)data shouldAlert:(BOOL)shouldAlert vdid:(NSString *)vdid {
    NSDictionary *dict = data[kDATA_KEY];
    id returnCode = dict[@"ReturnCode"];
    NSString *defaultErrorMsg = NYLocalizedString(@"common_alert_system_is_busy", nil);
    
    void(^alertWithErrorCode)(NSString *) = ^(NSString *message){
        if (!shouldAlert) {
            return;
        }
        
        NSString *errorCode = [AppErrorCodeLegacy p01199];
        NSString *errorCodeDesc = [NSString stringWithFormat:NYLocalizedString(@"common_alert_error_code", nil), errorCode];
        NSString *alertMessage = [message stringByAppendingFormat:@"\n(%@)", errorCodeDesc];
        [self displayErrorAlertWithTitle:nil message:alertMessage];
    };
    
    // 無效的 response or returnCode
    if (!dict || ![returnCode isKindOfClass:[NSString class]]) {
        alertWithErrorCode(defaultErrorMsg);
        return;
    }
    
    // 成功 (API0001)
    if ([returnCode isEqualToString:@"API0001"]) {
        NSString *GUID = dict[@"Data"];
        NSString *uAuth = dict[@"uAUTH"];
        
        GUID = GUID.length > 0 ? GUID : kNYCookieStatusServerReturnsEmpty;
        uAuth = uAuth.length > 0 ? uAuth : kNYCookieStatusServerReturnsEmpty;
        
        // 寫入CookieStorage
        [self setCookieWithGUID:GUID uAuth:uAuth VDID:vdid];
        
        // uAUTH_express 要清掉
        [self removeCookieWithCookieName:kCOOKIE_NAME_U_AUTH_EXPRESS];
        return;
    }
    
    if (!shouldAlert) {
        return;
    }
    
    // 其他錯誤情況
    NSString *message = dict[@"Message"];
    
    // Server 已知錯誤，不加 error code
    // API0002: 兩把金鑰都解密失敗
    // API0005: 舊金鑰被阻擋
    BOOL isKnownServerError = ([returnCode isEqualToString:@"API0002"] || [returnCode isEqualToString:@"API0005"]);
    
    if (isKnownServerError) {
        if (message && message.length > 0) {
            [self displayErrorAlertWithTitle:nil message:message];
            return;
        }
    }
    
    if (message && message.length > 0) {
        alertWithErrorCode(message);
    } else {
        alertWithErrorCode(defaultErrorMsg);
    }
}

- (void)displayErrorAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIViewController *rootVC = [[NYUIComponentUtil getKeyWindow] rootViewController];
    [rootVC ny_displayAlertWithTitle:title message:message];
}

- (void) setNSHTTPCookieWithCookieName:(NSString* ) cookieName andValue:(NSString*) cookieValue {
    [self removeCookieWithCookieName:cookieName shouldRemoveFromNSUserDefaults:NO];
    if ([cookieName isEqualToString:kCOOKIE_NAME_U_AUTH]) {
        [self restoreDictCookies:cookieName value:cookieValue];
    }
    
    for (NSString *domain in [self domainNames]) {
        NSMutableDictionary *cookieProperties = @{}.mutableCopy;
        [cookieProperties setObject:cookieName forKey:NSHTTPCookieName];
        [cookieProperties setObject:cookieValue forKey:NSHTTPCookieValue];
        [cookieProperties setObject:domain forKey:NSHTTPCookieDomain];
        [cookieProperties setObject:@"/" forKey:NSHTTPCookiePath];

        if ([cookieName isEqualToString:@"uAUTH"]) {
            [cookieProperties setObject:@"true" forKey:@"HttpOnly"];
        }
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }
}

- (void)setCookiesToDomain:(NSString* )domainName {
    [_cookieDict enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSMutableDictionary *properties = @{}.mutableCopy;
        [properties setObject:key forKey:NSHTTPCookieName];
        [properties setObject:obj forKey:NSHTTPCookieValue];
        [properties setObject:domainName forKey:NSHTTPCookieDomain];
        [properties setObject:@"/" forKey:NSHTTPCookiePath];
        NSHTTPCookie *newCookie = [NSHTTPCookie cookieWithProperties:properties];
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:newCookie];
    }];
}

- (void)setCookieWithGUID:(NSString *)GUID uAuth:(NSString *)uAuth VDID:(NSString *)VDID {
    [self setCookieValue:GUID forCookieName:kCOOKIE_NAME_GUID];
    [self setCookieValue:uAuth forCookieName:kCOOKIE_NAME_U_AUTH];
    [NYUserDefault setVDID:VDID];
    
    // 移除 Clip 來的 uAUTH_express
    [self removeCookieWithCookieName:kCOOKIE_NAME_U_AUTH_EXPRESS];
}

- (NSString *)keychainValueForKey:(NSString *)key {
    NSString *value;
    if ([key isEqualToString:kCOOKIE_NAME_U_AUTH]) {
        value = [NYKeychainHelper uAuth];
    } else if ([key isEqualToString:kCOOKIE_NAME_GUID]) {
        value = [NYKeychainHelper GUID];
    } else {
        NSAssert(NO, @"不認識的 Cookie Name");
    }
    
    return value;
}

- (void)setKeychainValue:(NSString *)value forKey:(NSString *)key {
    if ([key isEqualToString:kCOOKIE_NAME_U_AUTH]) {
        [NYKeychainHelper saveUAUTH:value];
    } else if ([key isEqualToString:kCOOKIE_NAME_GUID]) {
        [NYKeychainHelper saveGUID:value];
        [NYNotificationExtensionKeychainHelper saveGUID:value];
    } else {
        NSAssert(NO, @"不認識的 Cookie Name");
    }
}

- (void)clearGUIDAndUAUTH {
    [NYKeychainHelper deleteGUID];
    [NYKeychainHelper deleteUAUAH];
    _cookieDict[kCOOKIE_NAME_GUID] = nil;
    _cookieDict[kCOOKIE_NAME_U_AUTH] = nil;
}

@end
//
//  NYDataProvider+Search.m
//  Pods
//
//  Created by Alex Lin on 2016/8/3.
//
//

#import "NYDataProvider+Search.h"

#import "NYCDNHTTPClient.h"
#import "NYHTTPSClient.h"

@implementation NYDataProvider (Search)

#define Search_USE_DUMMY false
#pragma mark - Old

- (void)getShopSalePageTermListByKeyword:(NSString *)keyword
                                  shopId:(NSNumber *)shopId
                       completionHandler:(void (^)(NSArray *relatedKeywords, NSError *error))completionHandler {
    //Create client & check dummy
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"Search/GetShopSalePageTermListByKeyword";
    
    //Parameter
    NSDictionary *params = @{@"shopId"  : shopId,
                             @"keyword" : keyword};
    
    //GET
    [client getPath:path parameters:params requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        //Success
        //Sort, and remove duplicate items in the JSON, terms is an array of NSString
        NSArray *result = [[NSOrderedSet orderedSetWithArray: [JSON valueForKeyPath: @"SalePageTermText"]] array];
        
        //Call back
        completionHandler(result, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        //Error
        completionHandler(nil, error);
    }];
}


//- (void)getShopSalePageBySearchWithShopId:(NSNumber *)shopId
//                                  keyword:(NSString *)keyword
//                                  orderBy:(NSString *)orderBy
//                               startIndex:(NSInteger)startIndex
//                                 maxCount:(NSInteger)maxCount
//                        completionHandler:(void (^)(NSArray<NYItemObject *> *resultItems, NSError *error))completionHandler {
//    //Create client & check dummy
//    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
//    NSString *path = @"Search/GetShopSalePageBySearch";
//
//    //Parameter
//    NSDictionary *params = @{@"shopId"          : shopId,
//                             @"searchWord"      : keyword,
//                             @"orderby"         : orderBy,
//                             @"startIndex"      : @(startIndex),
//                             @"maxCount"        : @(maxCount)};
//
//    //GET
//    [client getPath:path parameters:params requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(AFHTTPRequestOperation *operation, id JSON) {
//        //Success
//        NSArray *itemDatas = JSON[@"data"];
//
//        //Create itemObjecs
//        NSMutableArray *result = [NSMutableArray array];
//        [itemDatas enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull data, NSUInteger idx, BOOL * _Nonnull stop) {
//            [result addObject:[[NYItemObject alloc] initWithJSONDict:data]];
//        }];
//
//        //Call back
//        completionHandler(result, nil);
//    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//        //Error
//        completionHandler(nil, error);
//    }];
//}

#pragma mark - Search V2

- (void)getShopHotKeywordListWithShopId:(NSNumber *)shopId
                               maxCount:(NSInteger)maxCount
                      completionHandler:(void (^)(NSArray<NSString *> *hotKeywords, NSError *error))completionHandler {
    //Create client & check dummy
    NSString *path = @"SearchV2/GetShopHotKeywordList";
    
    //Parameter
    NSDictionary *params = @{@"shopId"          : shopId,
                             @"maxCount"        : @(maxCount)};
    
    //GET
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:params requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        //Success
        NSArray *hotKeywords = JSON[@"Data"];
        
        //簡易防呆
        if ([hotKeywords isKindOfClass:[NSNull class]]) {
            hotKeywords = [NSArray array];
        }
        
        //Call back
        completionHandler(hotKeywords, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        //Error
        completionHandler(nil, error);
    }];
}

- (void)getShopCategoryListBySearchWithShopId:(NSNumber *)shopId
                                      keywork:(NSString *)keyword
                                     minPrice:(NSNumber *)minPrice
                                     maxPrice:(NSNumber *)maxPrice
                                      payType:(NSString *)payType
                                 shippingType:(NSString *)shippingType
                               scoreThreshold:(NSNumber *)scoreThreshold
                                   isResearch:(NSString *)isResearch
                            completionHandler:(void (^)(NSDictionary *json, NSError *error))completionHandler {
    //Create client & check dummy
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"SearchV2/GetShopCategoryListBySearch";
    
    //Parameter
    NSDictionary *params = @{@"shopId"          : shopId,
                             @"keyword"         : keyword,
                             @"minPrice"        : minPrice ? minPrice : @"",
                             @"maxPrice"        : maxPrice ? maxPrice : @"",
                             @"payType"         : payType,
                             @"shippingType"    : shippingType,
                             @"scoreThreshold"  : scoreThreshold,
                             @"isResearch"      : isResearch};
    
    //GET
    [client getPath:path parameters:params requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        //Success
        //Call back
        completionHandler(JSON, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        //Error
        completionHandler(nil, error);
    }];
}

- (AnyPromise *)getShopCategoryListBySearchPromiseWithShopId:(NSNumber *)shopId
                                                     keywork:(NSString *)keyword
                                                    minPrice:(NSNumber *)minPrice
                                                    maxPrice:(NSNumber *)maxPrice
                                                     payType:(NSString *)payType
                                                shippingType:(NSString *)shippingType
                                              scoreThreshold:(NSNumber *)scoreThreshold
                                                  isResearch:(NSString *)isResearch {
    //Create client & check dummy
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"SearchV2/GetShopCategoryListBySearch";
    
    //Parameter
    NSDictionary *params = @{@"shopId"          : shopId,
                             @"keyword"         : keyword,
                             @"minPrice"        : minPrice ? minPrice : @"",
                             @"maxPrice"        : maxPrice ? maxPrice : @"",
                             @"payType"         : payType,
                             @"shippingType"    : shippingType,
                             @"scoreThreshold"  : scoreThreshold,
                             @"isResearch"      : isResearch};
    
    //Return promise
    return [client getPath:path parameters:params].then(^(NSDictionary *json) {
        return json;
    }).catch(^(NSError *error) {
        return [NSNull null];
    });
}

- (void)getShopSalePageBySearchWithShopId:(NSNumber *)shopId
                                  keyword:(NSString *)keyword
                                    order:(NSString *)order
                               startIndex:(NSInteger)startIndex
                                 maxCount:(NSInteger)maxCount
                             displayScore:(NSString *)displayScore
                           shopCategoryId:(NSNumber *)shopCategoryId
                                 minPrice:(NSNumber *)minPrice
                                 maxPrice:(NSNumber *)maxPrice
                                  payType:(NSString *)payType
                             shippingType:(NSString *)shippingType
                           scoreThreshold:(NSNumber *)scoreThreshold
                               isResearch:(NSString *)isResearch
                        completionHandler:(void (^)(NSDictionary *json, NSError *error))completionHandler {
    //Create client & check dummy
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"SearchV2/GetShopSalePageBySearch";
    
    //Parameter
    NSMutableDictionary *params = @{@"shopId"          : shopId,
                                    @"keyword"         : keyword,
                                    @"order"           : order,
                                    @"startIndex"      : @(startIndex),
                                    @"maxCount"        : @(maxCount),
                                    @"displayScore"    : displayScore,
                                    @"shopCategoryId"  : (shopCategoryId.integerValue > 0) ? shopCategoryId : @"",
                                    @"payType"         : payType,
                                    @"shippingType"    : shippingType,
                                    @"scoreThreshold"  : scoreThreshold,
                                    @"isResearch"      : isResearch}.mutableCopy;
    if (minPrice) {
        params[@"minPrice"] = minPrice;
    }

    if (maxPrice) {
        params[@"maxPrice"] = maxPrice;
    }

    //GET
    [client getPath:path parameters:params requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        //Success
        //Call back
        completionHandler(JSON, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        //Error
        completionHandler(nil, error);
    }];
}

- (AnyPromise *)getShopSalePageBySearchPromiseWithShopId:(NSNumber *)shopId
                                                 keyword:(NSString *)keyword
                                                   order:(NSString *)order
                                              startIndex:(NSInteger)startIndex
                                                maxCount:(NSInteger)maxCount
                                            displayScore:(NSString *)displayScore
                                          shopCategoryId:(NSNumber *)shopCategoryId
                                                minPrice:(NSNumber *)minPrice
                                                maxPrice:(NSNumber *)maxPrice
                                                 payType:(NSString *)payType
                                            shippingType:(NSString *)shippingType
                                          scoreThreshold:(NSNumber *)scoreThreshold
                                              isResearch:(NSString *)isResearch {
    //Create client & check dummy
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"SearchV2/GetShopSalePageBySearch";
    
    //Parameter
    NSDictionary *params = @{@"shopId"          : shopId,
                             @"keyword"         : keyword,
                             @"order"           : order,
                             @"startIndex"      : @(startIndex),
                             @"maxCount"        : @(maxCount),
                             @"displayScore"    : displayScore,
                             @"shopCategoryId"  : (shopCategoryId.integerValue > 0) ? shopCategoryId : @"",
                             @"minPrice"        : minPrice ? minPrice : @"",
                             @"maxPrice"        : maxPrice ? maxPrice : @"",
                             @"payType"         : payType,
                             @"shippingType"    : shippingType,
                             @"scoreThreshold"  : scoreThreshold,
                             @"isResearch"      : isResearch};
    
    //Return promise
    return [client getPath:path parameters:params].then(^(NSDictionary *json) {
        return json;
    }).catch(^(NSError *error) {
        return [NSNull null];
    });
}

- (void)GetShopPayTypeAndShippingTypeListWithShopId:(NSNumber *)shopId
                                     needCleanCache:(BOOL)isNeedCleanCache
                                  completionHandler:(void (^)(NSDictionary *json, NSError *error))completionHandler {
    //Create client & check dummy
    NSString *path = @"SearchV2/GetShopPayTypeAndShippingTypeList";
    
    //Parameter
    NSDictionary *params = @{@"shopId"  : shopId,
                             @"r"       : isNeedCleanCache ? @"t" : @"f"};
    
    //GET
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:params requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        //Success
        //Call back
        completionHandler(JSON, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        //Error
        completionHandler(nil, error);
    }];
}

- (AnyPromise *)GetShopPayTypeAndShippingTypeListPromiseWithShopId:(NSNumber *)shopId
                                                    needCleanCache:(BOOL)isNeedCleanCache {
    //Create client & check dummy
    NSString *path = @"SearchV2/GetShopPayTypeAndShippingTypeList";
    
    //Parameter
    NSDictionary *params = @{@"shopId"  : shopId,
                             @"r"       : isNeedCleanCache ? @"t" : @"f"};
    
    //Return promise
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    return [client getPath:path parameters:params].then(^(NSDictionary *json) {
        return json;
    }).catch(^(NSError *error) {
        return [NSNull null];
    });
}

@end
//
//  NYECouponHTTPSClient.h
//  NineYiShopping
//
//  Created by Hanna on 2014/6/12.
//  Copyright (c) 2014年 91mai. All rights reserved.
//

#import "NYHTTPSClient.h"

@interface NYECouponHTTPSClient : NYHTTPSClient

+ (NYECouponHTTPSClient *)sharedClient;

- (void)postPathForECoupon:(NSString *)path
                parameters:(NSDictionary *)parameters
                   success:(void (^)(NSURLSessionDataTask *, id))success
                   failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

@end
//
//  NYFacebookGraphAPIClient.h
//  NineYiShopping
//
//  Created by Daniel Kao on 2015/1/5.
//  Copyright (c) 2015年 91mai. All rights reserved.
//

#import "NYHTTPSClient.h"

@interface NYFacebookGraphAPIClient : NYHTTPSClient

@end
//
//  NYTrackingClient.m
//  Pods
//
//  Created by Eric Huang on 2018/3/14.
//

#import "NYTrackingClient.h"
#import "NYBaseURLConfig.h"
#import "NYGlobalData.h"
#import <sys/utsname.h>

#import <WebKit/WebKit.h>
#import <NYCore/NYCore-Swift.h>

@interface NYTrackingClient ()

@property (nonatomic, strong) NSString *userAgent;

@end

@implementation NYTrackingClient

+ (NYTrackingClient *)sharedClient {
    static NYTrackingClient *_sharedClient = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[NYTrackingClient alloc] initWithBaseURL:[NYBaseURLConfig baseHTTPSURLWith91AnalyticsDomain]];
        _sharedClient.userAgent = WKWebView.userAgent;
    });
    return _sharedClient;
}

- (NSURLSessionDataTask *)addOperationWithRequestType:(NYHTTPRequestType)requestType
                                         responseType:(NYHTTPResponseType)responseType
                                               method:(NSString *)method
                                                 path:(NSString *)path
                                           parameters:(NSDictionary *)parameters
                                isSynchrounousRequest:(BOOL)isSynchrounousRequest
                                              success:(void (^)(NSURLSessionDataTask *, id))success
                                              failure:(void (^)(NSURLSessionDataTask *, id))failure {
    
    NSMutableDictionary *mutableParameters = [parameters mutableCopy];
    if ([super shouldAppendAppVerToURL:self.baseURL]) {
        NSDictionary *appVerParameter = @{@"appVer" : [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]};
        if (!mutableParameters) {
            mutableParameters = [appVerParameter mutableCopy];
        }
        else {
            [mutableParameters setValuesForKeysWithDictionary:appVerParameter];
        }
    }
    
    NSMutableURLRequest *request = [self requestWithType:requestType method:method path:path parameters:mutableParameters];
    request.HTTPShouldHandleCookies = YES;
    
    struct utsname systemInfo;
    uname(&systemInfo);
   
    NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString *userAppInfo = [NSString stringWithFormat:@" %@/%@ %@", [NYGlobalData bundleId], [NYGlobalData appVersionString], deviceModel];
    NSString *headerValue = [self.userAgent stringByAppendingString:userAppInfo];
    
    [request setValue:headerValue forHTTPHeaderField:@"User-Agent"];
    
    self.responseSerializer = [super responseSerializerWithType:responseType];
    
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
        if (error) {
            if (failure) {
                failure(dataTask, error);
            }
        } else {
            if (success) {
                success(dataTask, responseObject);
            }
        }
        
        if (isSynchrounousRequest) {
            dispatch_semaphore_signal(semaphore);
        }
    }];
    
    [dataTask resume];
    
    if (isSynchrounousRequest) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    
    return dataTask;
}

@end
//
//  NYLoginChangePasswordVC.m
//  NineyiAppShop
//
//  Created by Alex Lin on 2015/6/9.
//  Copyright (c) 2015年 91App. All rights reserved.
//

#import <NYCore/NYCore-Swift.h>
#import "NYLoginChangePasswordVC.h"

#import "NYMemberLoginCell.h"
//#import "NYLoginPageCollectionViewCell.h"

#import <NYCore/NYGlobalData.h>
#import <NYCore/NYLoginHelper.h>
#import <NYCore/UIColor+ThemeColor.h>
#import <NYCore/UIViewController+NYAlertControllerHelper.h>
#import <NYCore/NSBundle+PodsBundle.h>
#import <NYCore/UIScreen+MainBounds.h>
#import <NYCore/NYLocalizationString.h>
#import <NYCore/NYProgressHUD.h>
#import "NYLoginUserDataModel.h"

//API Code
static NSString * const kNYAPIChangePasswordCodeSuccess                       = @"API3171";
static NSString * const kNYAPIChangePasswordCodeWrongPassword                 = @"API3172";
static NSString * const kNYAPIChangePasswordCodeInvalidFormat                 = @"API3173";
static NSString * const kNYAPIChangePasswordCodeSystemError                   = @"API3179";

//Cell identifier
NSString * const kNYLoginChangePasswordPageCellIdentifierTitle               = @"NYLoginChangePasswordPageTitle";
NSString * const kNYLoginChangePasswordPageCellIdentifierCellPhoneText       = @"NYMemberChangePasswordPhoneNumberCell";
NSString * const kNYLoginChangePasswordPageCellIdentifierOriginPasswordText  = @"NYMemberChangePasswordOldPasswordCell";
NSString * const kNYLoginChangePasswordPageCellIdentifierNewPasswordText     = @"NYMemberChangePasswordNewPasswordCell";
NSString * const kNYLoginCellTypeRegexDescribeCellIdentifierRegexDescribe    = @"NYMemberLoginCellTypeRegexDescribeCell";
NSString * const kNYLoginChangePasswordPageCellIdentifierRedButton           = @"NYLoginChangePasswordPageRedButton";

//User Information Key
static NSString * const kUserInfoCellPhone        = @"CellPhone";
static NSString * const kUserInfoPassword         = @"Password";
static NSString * const kUserInfoNewPassword      = @"NewPassword";
static NSString * const kUserInfoRegex            = @"Regex";
static NSString * const kUserInfoRegexContents    = @"RegexContents";

@interface NYLoginChangePasswordVC () <NYMemberLoginCellDelegate>

@property (nonatomic, strong) void(^completionBlock)(void);

@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *collectionBottomConstraint;

@property (nonatomic, strong) NSMutableArray *cellsIdentifierArray;

@property (nonatomic, strong) NYMemberLoginCell *oPasswordCell;
@property (nonatomic, strong) NYMemberLoginCell *nPasswordCell;

@end

@implementation NYLoginChangePasswordVC

- (instancetype)initFromStoryBoard {
    NSBundle *bundle = [NSBundle nyBundleWithNYLoginViewController];
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:NSStringFromClass([self class]) bundle:bundle];
    self = [storyBoard instantiateViewControllerWithIdentifier:NSStringFromClass([self class])];
    
    //Default value
    _userInformation = [[NSMutableDictionary alloc] initWithDictionary:@{kUserInfoCellPhone       :@"",
                                                                         kUserInfoPassword        :@"",
                                                                         kUserInfoNewPassword     :@"",
                                                                         kUserInfoRegex           :@"",
                                                                         kUserInfoRegexContents   :@[]}];
    __weak typeof(self) weakSelf = self;
    _completionBlock = ^(){
        [weakSelf.navigationController popViewControllerAnimated:YES];
    };
    
    return self;
}

- (instancetype)initFromStoryBoardWithCompletionBlock:(void(^)(void))block {
    self = [[NYLoginChangePasswordVC alloc] initFromStoryBoard];
    if (self) {
        _completionBlock = block;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //Listen keyboard event
    [self registerForKeyboardNotifications];
    
    NSBundle *bundle = [NSBundle nyBundleWithNYLoginViewController];
    
    //Register xib
    [self.collectionView registerNib:[UINib nibWithNibName:kNYMemberChangePasswordPhoneNumberCell bundle:bundle]
          forCellWithReuseIdentifier:kNYMemberChangePasswordPhoneNumberCell];

    [self.collectionView registerNib:[UINib nibWithNibName:kNYMemberChangePasswordOldPasswordCell bundle:bundle]
          forCellWithReuseIdentifier:kNYMemberChangePasswordOldPasswordCell];

    [self.collectionView registerNib:[UINib nibWithNibName:kNYMemberChangePasswordNewPasswordCell bundle:bundle]
          forCellWithReuseIdentifier:kNYMemberChangePasswordNewPasswordCell];
    
    [self.collectionView registerNib:[UINib nibWithNibName:kNYLoginCellTypeRegexDescribeCellIdentifierRegexDescribe bundle:bundle]
          forCellWithReuseIdentifier:kNYLoginCellTypeRegexDescribeCellIdentifierRegexDescribe];
    
    // 取得密碼 regex 規則設定
    [self fetchPasswordRegexSetting];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.backgroundColor = [UIColor whiteColor];
    
    //Set up logo
    if (!self.navigationItem.titleView) {
        self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed: ([NYModuleConfig isBrandIdentityModuleEnabled]) ? @"shopLogo_brand" : @"shopLogo"]];
    }
    self.edgesForExtendedLayout = UIRectEdgeBottom;
}

- (void)dealloc {
    //Remove notification event
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Fetch Data

- (void)fetchPasswordRegexSetting {
    // 取得密碼 regex 與文案
    [NYProgressHUD showHUDAddedToView:self.view];
    __weak typeof(self) weakSelf = self;
    
    [NYLoginPasswordRegexProcessor getPasswordRegexSettingWithCompletion:^(BOOL isSuccess, NSString * _Nonnull regex, NSArray<NSString *> * _Nonnull regexContents) {
        [NYProgressHUD hideAllHUDsForView:weakSelf.view];
        
        if (isSuccess) {
            weakSelf.userInformation[kUserInfoRegex] = regex;
            weakSelf.userInformation[kUserInfoRegexContents] = regexContents;
        } else {
            // 錯誤情境不做任何處理，app 預設判斷上限 128 碼
            weakSelf.userInformation[kUserInfoRegex] = DEFAULT_PWD_REGEX;
            weakSelf.userInformation[kUserInfoRegexContents] = @[];
        }
        
        [weakSelf generateCollectionItemsArray];
        [weakSelf.collectionView reloadData];
    }];
}

#pragma mark - CellSelectEvent

- (void)nextStepClick {
    //Check password format & error animation
    if (![self.oPasswordCell formatCheck]) {
        [self.oPasswordCell changeBorderColorWithColor:[UIColor redColor]];
        [self.oPasswordCell shake];
        [self.oPasswordCell showSecureText];
        
        [self ny_displayAlertWithTitle:NYLocalizedString(@"login_password_regex_alert_old_incorrect", nil) message:nil];
        return;
    }
    [self.oPasswordCell changeBorderColorWithColor:[UIColor grayColor]];
    
    if (![self.nPasswordCell checkIsNotEmpty]) {
        [self.nPasswordCell changeBorderColorWithColor:[UIColor redColor]];
        [self.nPasswordCell shake];
        [self.nPasswordCell showSecureText];
        
        [self ny_displayAlertWithTitle:NYLocalizedString(@"login_password_regex_warning_new_password_empty", nil) message:nil];
        return;
    }
    
    if (![self.nPasswordCell formatCheck]) {
        [self.nPasswordCell changeBorderColorWithColor:[UIColor redColor]];
        [self.nPasswordCell shake];
        [self.nPasswordCell showSecureText];
        
        [self ny_displayAlertWithTitle:NYLocalizedString(@"login_password_regex_warning_new_password_length", nil) message:nil];
        return;
    }
    [self.nPasswordCell changeBorderColorWithColor:[UIColor grayColor]];
    
    //Call API (ChangePassword)
    [self callLoginHelperChangePassword];
}

#pragma mark - Collection Construct Method

- (void)generateCollectionItemsArray {
    //Create only once
    if (!self.cellsIdentifierArray) {
        
        __block NSMutableArray *regexContentCells = [[NSMutableArray alloc] init];
        [self.userInformation[kUserInfoRegexContents] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [regexContentCells addObject:kNYLoginCellTypeRegexDescribeCellIdentifierRegexDescribe];
        }];
        
        self.cellsIdentifierArray = [NSMutableArray arrayWithArray:@[@[kNYLoginChangePasswordPageCellIdentifierTitle],
                                                                     @[kNYLoginChangePasswordPageCellIdentifierCellPhoneText],
                                                                     @[kNYLoginChangePasswordPageCellIdentifierOriginPasswordText],
                                                                     @[kNYLoginChangePasswordPageCellIdentifierNewPasswordText],
                                                                     @[kNYLoginChangePasswordPageCellIdentifierRedButton]]];
        if (regexContentCells.count > 0) {
            [self.cellsIdentifierArray insertObject:regexContentCells atIndex:(self.cellsIdentifierArray.count - 1)];
        }
    }
}

//Check size with identifier
- (CGSize)generateCollectionCellSizeWithID:(NSString *)identifier {
    if ([identifier isEqualToString:kNYLoginChangePasswordPageCellIdentifierTitle]) {
        return CGSizeMake([UIScreen mainScreenWidth], 65);
    }
    else if ([identifier isEqualToString:kNYLoginChangePasswordPageCellIdentifierRedButton]) {
        return CGSizeMake([UIScreen mainScreenWidth], 56);
    }
    else if ([identifier isEqualToString:kNYLoginCellTypeRegexDescribeCellIdentifierRegexDescribe]) {
        return CGSizeMake([UIScreen mainScreenWidth], 20);
    }
    
    //Default
    return CGSizeMake([UIScreen mainScreenWidth], 50);
}

//Check inset with identifier (First row in section)
- (UIEdgeInsets)generateCollectionSectionInsetWithID:(NSString *)identifier {
    if ([identifier isEqualToString:kNYLoginChangePasswordPageCellIdentifierTitle]) {
        return UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    }
    else if ([identifier isEqualToString:kNYLoginChangePasswordPageCellIdentifierCellPhoneText]) {
        return UIEdgeInsetsMake(16.0f, 0.0f, 0.0f, 0.0f);
    }
    else if ([identifier isEqualToString:kNYLoginChangePasswordPageCellIdentifierOriginPasswordText]) {
        return UIEdgeInsetsMake(10.0f, 0.0f, 0.0f, 0.0f);
    }
    else if ([identifier isEqualToString:kNYLoginChangePasswordPageCellIdentifierNewPasswordText]) {
        return UIEdgeInsetsMake(10.0f, 0.0f, 0.0f, 0.0f);
    }
    else if ([identifier isEqualToString:kNYLoginChangePasswordPageCellIdentifierRedButton]) {
        return UIEdgeInsetsMake(10.0f, 0.0f, 0.0f, 0.0f);
    }
    else if ([identifier isEqualToString:kNYLoginCellTypeRegexDescribeCellIdentifierRegexDescribe]) {
        return UIEdgeInsetsMake(10.0f, 0.0f, 0.0f, 0.0f);
    }
    
    //Default
    return UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return [self cellsIdentifierArray].count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return ((NSArray*)[self cellsIdentifierArray][section]).count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [self cellsIdentifierArray][indexPath.section][indexPath.row];
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:indexPath];

    //Point to cell & set content
    if ([identifier isEqualToString:kNYLoginChangePasswordPageCellIdentifierCellPhoneText]) {
        NYMemberLoginCell *phoneCell = (NYMemberLoginCell *)cell;
        [phoneCell setConetnt:self.userInformation];
    }
    else if ([identifier isEqualToString:kNYLoginChangePasswordPageCellIdentifierOriginPasswordText]) {
        self.oPasswordCell = (NYMemberLoginCell *)cell;
        [self.oPasswordCell setConetnt:self.userInformation];
        self.oPasswordCell.delegate = self;
    }
    else if ([identifier isEqualToString:kNYLoginChangePasswordPageCellIdentifierNewPasswordText]) {
        self.nPasswordCell = (NYMemberLoginCell *)cell;
        [self.nPasswordCell setConetnt:self.userInformation];
        self.nPasswordCell.delegate = self;
    }
    else if ([identifier isEqualToString:kNYLoginCellTypeRegexDescribeCellIdentifierRegexDescribe]) {
        NYMemberLoginCellTypeRegexDescribeCell *describeCell = (NYMemberLoginCellTypeRegexDescribeCell *)cell;
        NSArray *regexContents = self.userInformation[kUserInfoRegexContents];
        if (regexContents.count > indexPath.row) {
            [describeCell setContent:regexContents[indexPath.row]];
        }
    }
    
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return CGSizeZero;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *identifier = [self cellsIdentifierArray][indexPath.section][indexPath.row];
    return [self generateCollectionCellSizeWithID:identifier];
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    
    NSString *identifier = [self cellsIdentifierArray][section][0];
    return [self generateCollectionSectionInsetWithID:identifier];
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0f;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0f;
}

#pragma mark - UICollectionViewDelegate

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    if ([cell.reuseIdentifier isEqualToString:kNYLoginChangePasswordPageCellIdentifierRedButton]) {
        //手機認證
        [self nextStepClick];
    }
}

#pragma mark - scrollView
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    //收鍵盤
    if (scrollView.isDragging) {
        [self.view endEditing:YES];
    }
}

#pragma mark - KeyBorad Event

- (void)registerForKeyboardNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}


- (void)keyboardWasShown:(NSNotification *)notification {
    CGSize keyboardSize = [[notification userInfo][UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    self.collectionBottomConstraint.constant = keyboardSize.height - (([NYGlobalData shopId] != 0)?48:0);
    
    //Scroll (用Delay是為了解決, constraint並不會直接改frame size, 但若是用layout的話, 他method會主動scroll textfield貼keyboard, 導致我scroll的位置被吃掉)
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [weakSelf.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:2] atScrollPosition:UICollectionViewScrollPositionTop animated:YES];
    });
}

- (void)keyboardWillBeHidden:(NSNotification *)notification {
    self.collectionBottomConstraint.constant = 0;
}

#pragma mark - NYMemberLoginCellDelegate

//- (void)NYMemberLoginCellDidClickedEnter:(NYMemberLoginCell *)cell {
//    if (cell == self.oPasswordCell) {
//        //Focus to next text
//        [self.collectionView scrollRectToVisible:self.nPasswordCell.frame animated:NO];
//        [self.nPasswordCell showKeyboard];
//    }
//    else if (cell == self.nPasswordCell) {
//        //Call click event
//        [self nextStepClick:nil];
//    }
//}

#pragma mark - Call LoginHelper

- (void)callLoginHelperChangePassword {
    NSString *oPasswordString = self.userInformation[kUserInfoPassword];
    NSString *nPasswordString = self.userInformation[kUserInfoNewPassword];
    
    __weak typeof(self) weakSelf = self;
    
    //Call LoginHelper (ChangePassword)
    [NYProgressHUD showHUDAddedToView:self.view];
    [[NYLoginHelper sharedInstance] changePasswordVia91maiWithShopID:[NYGlobalData shopId] oldPassword:oPasswordString newPassword:nPasswordString completionHandler:^(NSDictionary *data, NSError *error) {
        [NYProgressHUD hideAllHUDsForView:weakSelf.view];
        if (!error) {
            NSDictionary *responseDict = data[kDATA_KEY];
            NSString *responseCode = responseDict[@"ReturnCode"];
            NSString *message = responseDict[@"Message"];
            
            if ([responseCode isEqualToString:kNYAPIChangePasswordCodeSuccess]) {
                //修改密碼成功
                [weakSelf showHUDWithTitle:NYLocalizedString(@"login_change_password_success", nil) duration:2 complete:^{
                    if (weakSelf.completionBlock) {
                        weakSelf.completionBlock();
                    }
                }];
            }
            else if ([responseCode isEqualToString:kNYAPIChangePasswordCodeWrongPassword]) {
                //舊密碼錯誤
                [weakSelf.oPasswordCell changeBorderColorWithColor:[UIColor redColor]];
                [weakSelf.oPasswordCell shake];
                [weakSelf.oPasswordCell showSecureText];
                [self ny_displayAlertWithTitle:message message:@""];
            }
            else if ([responseCode isEqualToString:kNYAPIChangePasswordCodeInvalidFormat]) {
                // 新密碼格式錯誤 
                NSLog(@"callAPI_fbRegister Logic Error Code: 3173");
                [weakSelf.nPasswordCell changeBorderColorWithColor:[UIColor redColor]];
                [weakSelf.nPasswordCell shake];
                [weakSelf.nPasswordCell showSecureText];
                [self ny_displayAlertWithTitle:message message:@""];
            }
            else if ([responseCode isEqualToString:kNYAPIChangePasswordCodeSystemError]) {
                //系統錯誤
                [self ny_displayAlertWithTitle:@"" message:message];
            }
            else {
                NSLog(@"Error - Unknown api code : %@", responseCode);
            }
        }
        else {
            //Connection error alert
            [self ny_displayBadNetworkWithReloadBlock:^{
                //Retry
                [weakSelf callLoginHelperChangePassword];
            } cancelBlock:^{
                //Do nothing
            }];
        }
    }];
}

@end
//
//  NYLoginVCInfo.m
//  Pods
//
//  Created by 陸韻涵 on 2016/1/7.
//
//

#import "NYLoginVCInfo.h"

@implementation NYLoginVCInfo

+ (instancetype)sharedInfo {
    static NYLoginVCInfo *dataModel;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dataModel = [[NYLoginVCInfo alloc] init];
    });
    
    return dataModel;
}

/**
 * 處理登入成功後的流程
 *
 * 此方法執行以下操作：
 * 1. 呼叫 loginCompletion（如果存在）
 * 2. 將 waitingForLoginVC 設為 nil
 * 3. 清除相關資訊
 * 4. 發送登入成功通知
 * 5. 根據參數決定是否重置 loginCompletion
 *
 * - Parameter resetCompletion: 是否重置 loginCompletion。
 *   - 設為 YES 時，會在執行完 loginCompletion 後將其設為 nil，避免重複呼叫
 *   - 設為 NO 時，保留 loginCompletion 不變
 *
 * - Note: 在某些情況下（如寶雅的第三方登入），可能會重複觸發登入流程，
 *   此時應將 resetCompletion 設為 YES 以避免 loginCompletion 被重複呼叫。
 */
- (void)finishLoginWithCompletionReset:(BOOL)resetCompletion {
    if (self.loginCompletion) {
        self.loginCompletion();
    }
    
    if (resetCompletion) {
        self.loginCompletion = nil;
    }
    
    self.waitingForLoginVC = nil;
    [self clearInfo];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NYLoginNotification" object:nil];
}

- (void)clearInfo {
    self.isResendVerifyCodeReachLimit = NO;
    self.isViaVoiceServiceReachLimit = NO;
    self.loginProcessStartTime = nil;
}

@end
//
//  NYLoginRootVC.m
//  NineyiAppShop
//
//  Created by 陸韻涵 on 2015/6/15.
//  Copyright (c) 2015年 91App. All rights reserved.
//

#import <NYCore/NYCore-Swift.h>
#import "NYLoginViewController.h"
#import "NYLoginCell.h"
#import "NYLoginUserDataModel.h"
#import "NYThirdPartyLoginWebBrowserVC.h"
#import "NYLoginVCInfo.h"
#import "NYLoginPagerViewController.h"
#import "NYOptInViewModel.h"

#import <NYCore/NYLoginHelper.h>
#import <NYCore/NYDataProvider+MemberCenter.h>
#import <NYCore/NYDataProvider+Login.h>
#import <NYCore/NYGlobalData.h>
#import <NYCore/NYUserDefault.h>
#import <NYCore/NYADElementObject.h>
#import <NYCore/NYBaseURLConfig.h>
#import <NYCore/NYAppSettingsHelper.h>
#import <NYCore/NYMemberHelper.h>
#import <NYCore/NYNotificationHelper.h>
#import <NYCore/NYStatisticHelper.h>
#import <NYCore/NYAlertPresenter.h>
#import <NYCore/UIViewController+NYAlertControllerHelper.h>
#import <NYCore/UIColor+ThemeColor.h>
#import <NYCore/NSBundle+PodsBundle.h>
#import <NYCore/UIScreen+MainBounds.h>
#import <NYCore/UIDevice+PlatformHelper.h>
#import <NYCore/NSString+Regex.h>
#import <NYCore/NYLocalizationString.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <NYCore/NYProgressHUD.h>
#import <objc/runtime.h>
#import <NYIcon/NYIcon-Swift.h>

// const String for Firebase Analytics
NSString * const kFAParamSignupLoginMethodFacebook                           = @"facebook";
NSString * const kFAParamSignupLoginMethodAppleSignIn                        = @"apple_id";
NSString * const kFAParamSignupLoginMethodLine                               = @"line";
NSString * const kFAParamSignupLoginMethodShopAccount                        = @"shop_account";
NSString * const kFAParamSignupLoginMethodPhone                              = @"phone";
NSString * const kFAParamSignupLoginStatusFinish                             = @"finish";
NSString * const kFAParamSelectContentType                                   = @"LoginMethod";
NSString * const kFAParamSelectContentItemName                               = @"Button";
NSString * const kFAParamSelectContentFrom                                   = @"Login";

// const String for API parameter
// member type
NSString * const kMemberType_NineYi                                          = @"NineYi";
NSString * const kMemberType_Facebook                                        = @"Facebook";
NSString * const kMemberType_Line                                            = @"Line";
NSString * const kMemberType_ThirdpartyAuth                                  = @"ThirdpartyAuth";
NSString * const kMemberType_Express                                         = @"Express";
// verify type
NSString * const kVerifyType_Login                                           = @"Login";
NSString * const kVerifyType_Register                                        = @"Register";
NSString * const kVerifyType_CellPhoneVerify                                 = @"CellPhoneVerify";
NSString * const kVerifyType_ResetPassword                                   = @"ResetPassword";
// sms type
NSString * const kSMSType_LoginMember                                        = @"LoginMember";
NSString * const kSMSType_RegisterMember                                     = @"RegisterMember";
NSString * const kSMSType_MemberPassword                                     = @"MemberPassword";

typedef enum {
    NYLoginTextFieldFormatCheckTypeCellPhone,
    NYLoginTextFieldFormatCheckTypeVerifyCode,
    NYLoginTextFieldFormatCheckTypePassword,
    NYLoginTextFieldFormatCheckTypeThirdPartyAuth,
    NYLoginTextFieldFormatCheckTypeNoCheck,
} NYLoginTextFieldFormatCheckType;

@interface UIViewController (NYLoginVCInfo)

@property (nonatomic, strong) UIView *loginMaskView;

@end

@implementation UIViewController (NYLoginVCInfo)

- (void)setLoginMaskView:(UIView *)loginMaskView {
    objc_setAssociatedObject(self, @"kNYLoginMaskView", loginMaskView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIView *)loginMaskView {
    return objc_getAssociatedObject(self, @"kNYLoginMaskView");
}

@end

@implementation UIViewController (LoginCheck)

- (void)displayUnloginView {
    if (!self.loginMaskView) {
        self.loginMaskView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.loginMaskView.backgroundColor = [UIColor colorWithHexString:@"0xEFEFEF"];
        
        //Label
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 50, CGRectGetWidth(self.loginMaskView.frame), 25)];
        titleLabel.text = NYLocalizedString(@"login_not_login_yet", nil);
        titleLabel.textAlignment = NSTextAlignmentCenter;
        [self.loginMaskView addSubview:titleLabel];
        
        //Button
        UIView *grayView = [[UIView alloc] initWithFrame:CGRectMake(13, 90, CGRectGetWidth(self.loginMaskView.frame) - 26, 56)];
        grayView.backgroundColor = [UIColor colorWithHexString:@"0xECECEC"];
        grayView.layer.cornerRadius = 6.0f;
        
        UIButton *loginButton = [[UIButton alloc] initWithFrame:CGRectMake(7, 6, CGRectGetWidth(grayView.frame) - 14, 44)];
        UIColor *cmsMainBtnBgColor = [[NYCMSThemeEngine sharedInstance] mainBtnBgColor];
        UIColor *cmsMainBtnTextColor = [[NYCMSThemeEngine sharedInstance] mainBtnTextColor];
        loginButton.backgroundColor = cmsMainBtnBgColor;
        [loginButton setTitleColor:cmsMainBtnTextColor forState:UIControlStateNormal];
        loginButton.layer.cornerRadius = 5.0f;
        [loginButton setTitle:NYLocalizedString(@"login_btn_login_or_register", nil) forState:UIControlStateNormal];
        [loginButton addTarget:self action:@selector(presentLoginVC) forControlEvents:UIControlEventTouchUpInside];
        
        [grayView addSubview:loginButton];
        [self.loginMaskView addSubview:grayView];
        
        
        [self.view addSubview:self.loginMaskView];
    }
}

- (void)hideUnLoginView {
    if (self.loginMaskView) {
        [self.loginMaskView removeFromSuperview];
        self.loginMaskView = nil;
    }
}

- (void)presentLoginVC {
    NYLoginVCInfo *info = [NYLoginVCInfo sharedInfo];
    [self hideUnLoginView];
    [self presentLoginVCShouldShowUnLoginMask:info.shouldShowUnloginMask WithLoginSuccessCompletion:info.loginCompletion];
}

- (void)presentLoginVCShouldShowUnLoginMask:(BOOL)shouldShowMask WithLoginSuccessCompletion:(NYLoginSuccessCompletion)completion {
    // 如果有需要等待才開始轉 Loading
    dispatch_group_t group = [NYAppSettingsHelper group];
    BOOL needLoading = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 0));
    if (needLoading) {
        [NYProgressHUD showHUDAddedToView:self.view];
    }

    dispatch_queue_t bgQueue = dispatch_queue_create("nineyi.login.wait", nil);
    dispatch_async(bgQueue, ^{
        // Max wait 5s
        dispatch_time_t timeLimit = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
        dispatch_group_wait(group, timeLimit);

        // Must run in main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            if (needLoading) {
                [NYProgressHUD hideAllHUDsForView:self.view];
            }

            [[NYLoginUserDataModel sharedModel] clear];
            [[NYLoginVCInfo sharedInfo] clearInfo];

            NYLoginVCInfo *info = [NYLoginVCInfo sharedInfo];
            info.shouldShowUnloginMask = shouldShowMask;
            info.waitingForLoginVC     = self;
            info.loginCompletion       = completion;
            info.loginProcessStartTime = [NSDate date];

            UIViewController <UINavigationControllerDelegate> *presentedVC = [NYLoginViewController loginVC];

            UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:presentedVC];
            navi.delegate = presentedVC;
            navi.modalPresentationStyle = UIModalPresentationFullScreen;

            // 這個 singleton 會在AppDelegate拿到
            if ([[NYAppSettingsHelper sharedInstance] thirdpartyBasedAuth] == NYThirdpartyBasedAuthNoData) {
                // 強制登入卻拿不到 thirdpartyBasedAuth 時，就一直跳 alert 卡使用
                if ([NYCountryConfig isNeedLoginToUseAppIn:[NYGlobalData countryCode]]) {
                    __weak typeof(self) weakSelf = self;
                    [self ny_displayAlertWithTitle:@"" message:NYLocalizedString(@"login_thirdparty_service_error", nil) cancelButtonTitle:NYLocalizedString(@"common_confirm", nil) onDismiss:^{
                        [weakSelf presentLoginVCShouldShowUnLoginMask:shouldShowMask WithLoginSuccessCompletion:completion];
                    }];
                }
                else {
                    [self ny_displayAlertWithTitle:@"" message:NYLocalizedString(@"login_thirdparty_service_error", nil)];
                }
                return;
            }

            if (!self.loginMaskView || [NYCountryConfig isNeedLoginToUseAppIn:[NYGlobalData countryCode]]) {
                if (info.presentCompletion) {
                    info.presentCompletion(navi);
                } else if ([[NYAppSettingsHelper sharedInstance] thirdpartyBasedAuth] == NYThirdpartyBasedAuthEnable) {
                    NYThirdPartyLoginWebBrowserVC *webVC = [NYThirdPartyLoginWebBrowserVC viewController];
                    UINavigationController *webNavi = [[UINavigationController alloc] initWithRootViewController:webVC];
                    webNavi.modalPresentationStyle = UIModalPresentationFullScreen;
                    [self presentViewController:webNavi animated:YES completion:^{}];
                } else {
                    [self presentViewController:navi animated:YES completion:^{}];
                }
            }
        });
    });
}

- (void)presentValidateCellPhoneVC {
    UIViewController <UINavigationControllerDelegate> *presentedVC = [NYLoginViewController validateCellPhoneVC];
    
    UINavigationController *navi = [[UINavigationController alloc] initWithRootViewController:presentedVC];
    navi.delegate = presentedVC;
    navi.modalPresentationStyle = UIModalPresentationFullScreen;

    [self presentViewController:navi animated:YES completion:^{}];
}

@end

static UIViewController *(^_webViewCreator)(NSURL *);
static UIViewController *(^_htmlWebViewCreator)(NSString *);
static UIViewController *(^_resetPasswordMultiFactorAuthViewControllerCreator)(MultiFactorAuthResetPasswordObject *, void (^)(void), void (^)(void));
static void(^_presentProfileBlock)(UIViewController *, void (^)(void));
static void(^_reCaptchaGetTokenBlock)(void (^)(NSString *));

@interface NYLoginViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, NYOptInCellDelegate>

@property (nonatomic, assign) NYLoginProcessType loginType;
@property (nonatomic, strong) NSMutableArray *entries;

@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *collectionViewTopConstraint;
@property (nonatomic, weak) IBOutlet UIView *notRecevingSMSMessageHelpView;
@property (nonatomic, weak) IBOutlet UIButton *resendVerifyCodeServiceButton;
@property (nonatomic, weak) IBOutlet UIImageView *resendVerifyCodeServiceButtonIcon;
@property (nonatomic, weak) IBOutlet UILabel *resendVerifyCodeServiceButtonLabel;
@property (nonatomic, weak) IBOutlet UIButton *verifyViaVoiceServiceButton;
@property (nonatomic, weak) IBOutlet UIImageView *verifyViaVoiceServiceButtonIcon;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *notRecevingSMSMessageHelpViewBottomConstraint;
@property (nonatomic, weak) IBOutlet UILabel *dialVerifyViaVoiceServiceDescription;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *dialVerifyViaVoiceServiceTopConstraint;

@property (weak, nonatomic) IBOutlet UIView *registerWithCellPhoneRemindView;
@property (weak, nonatomic) IBOutlet UILabel *registerWithCellPhoneRemindDescription;
@property (weak, nonatomic) IBOutlet UIButton *registerWithCellPhoneRemindButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *registerWithCellPhoneRemindViewBottomConstraint;

@property (nonatomic, assign) NSUInteger passwordErrorCounter;

//驗證碼頁
@property (nonatomic, assign) BOOL enableNotReceivingSMSFlag;

@property (nonatomic, assign) BOOL isNormallyClosed;

//OAuth登入
@property (nonatomic, strong) NSDictionary *thirdPartyAuthLoginInfoDic;
@property (nonatomic, strong) NSString *accessToken;
@property (nonatomic, assign) BOOL shouldGetInternalTokenAndLogin;

//reCaptcha驗證
@property (nonatomic, assign) BOOL canUseReCaptcha; // 判斷是否可以去打 google API 取得 reCaptcha token（有啟用 reCaptcha 且 Appgen 有 reCaptcha key）
@property (nonatomic, strong) NYLoginViewModel<NYLoginFlowContext> *flowViewModel;

- (id)initWithNYLoginProcessType:(NYLoginProcessType)loginType;
- (NSArray *)generateEntriedForLoginType:(NYLoginProcessType)type;
- (void)registerCellIdentifierFromEntries:(NSArray *)entries;

- (IBAction)resendVerifyCode:(UIButton *)sender;
- (IBAction)resendVerifyCodeUseVoice:(UIButton *)sender;
@end

@implementation NYLoginViewController

// Injection
+ (void)setWebViewCreator:(UIViewController *(^)(NSURL *))creator {
    _webViewCreator = creator;
}

+ (UIViewController *(^)(NSURL *))webViewCreator {
    if (_webViewCreator) {
        return _webViewCreator;
    }
    return ^UIViewController *(NSURL *url) {
        return nil;
    };
}

+ (void)setHTMLWebViewCreator:(UIViewController *(^)(NSString *))creator {
    _htmlWebViewCreator = creator;
}

+ (UIViewController *(^)(NSString *))htmlWebViewCreator {
    if (_htmlWebViewCreator) {
        return _htmlWebViewCreator;
    }
    return ^UIViewController *(NSString *url) {
        return nil;
    };
}

+ (void)setResetPasswordMultiFactorAuthViewControllerCreator:(UIViewController *(^)(MultiFactorAuthResetPasswordObject *, void (^)(void), void (^)(void)))creator {
    _resetPasswordMultiFactorAuthViewControllerCreator = creator;
}

+ (UIViewController *(^)(MultiFactorAuthResetPasswordObject *, void (^)(void), void (^)(void)))resetPasswordMultiFactorAuthViewControllerCreator {
    if (_resetPasswordMultiFactorAuthViewControllerCreator) {
        return _resetPasswordMultiFactorAuthViewControllerCreator;
    }
    return ^UIViewController *(MultiFactorAuthResetPasswordObject *data, void (^completion)(void), void (^dismissHandler)(void)) {
        return nil;
    };
}

+ (void)setPresentProfileBlock:(void (^)(UIViewController *, void (^)(void)))block {
    _presentProfileBlock = block;
}

+ (void (^)(UIViewController *, void (^)(void)))presentProfileBlock {
    if (_presentProfileBlock) {
        return _presentProfileBlock;
    }
    return ^(UIViewController *vc, void (^completion)(void)) {
        completion();
    };
}

+ (void)setReCaptchaGetTokenBlock:(void (^)(void (^)(NSString *)))block {
    _reCaptchaGetTokenBlock = block;
}

+ (void (^)(void (^)(NSString *)))reCaptchaGetTokenBlock {
    if (_reCaptchaGetTokenBlock) {
        return _reCaptchaGetTokenBlock;
    }
    return ^(void (^completion)(NSString *)) {
        completion(@"");
    };
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    // 是 WebView 就不要做, HTML 的可以
    Class webViewClass = [[NYLoginViewController webViewCreator]([[NSURL alloc] init]) class];
    BOOL isWebView = [viewController isKindOfClass:webViewClass];
    if (isWebView) {
        return;
    }

    [navigationController.navigationItem setHidesBackButton:YES animated:NO];
    if ([navigationController.viewControllers count] > 1) {
        if ([NYLoginVCInfo sharedInfo].backButtonImageName) {
            UIImage *image = [[UIImage iconWith:[NYLoginVCInfo sharedInfo].backButtonImageName size:24] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            UIBarButtonItem *backBarButtonItem = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:([viewController isKindOfClass:[NYLoginViewController class]]) ? viewController : self action:@selector(abortLoginOrRegisterProcess)];
            [backBarButtonItem setTintColor:[[NYCMSThemeEngine sharedInstance] subColor] ? : [UIColor buttonNavigationPreviousTintColor]];
            UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
            spaceItem.width = -11.0f;
            viewController.navigationItem.leftBarButtonItems = @[spaceItem, backBarButtonItem];
        } else {
            //有待考證
            [self.navigationItem.backBarButtonItem setAction:@selector(abortLoginOrRegisterProcess)];
        }
    }
}

/// Initialize with ViewModel from previous steps
- (id)initWithNYLoginProcessType:(NYLoginProcessType)loginType viewModel:(NYLoginViewModel<NYLoginFlowContext> *)viewModel userCountryCode:(NSString *)userCountryCode userCountryID:(NSNumber *)userCountryID {
    NSBundle *bundle = [NSBundle nyBundleWithNYLoginViewController];
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:NSStringFromClass([self class]) bundle:bundle];
    self = [storyBoard instantiateViewControllerWithIdentifier:[self storyboardControllerIdentifierForLoginProcessType:loginType]];
    
    self.loginType = loginType;
    
    if (viewModel) {
        self.flowViewModel = [viewModel copy];
    } else {
        self.flowViewModel = [[NYLoginViewModel alloc] initWithShopID:[NYGlobalData shopId]];
    }
    
    self.flowViewModel.delegate = self;
    self.entries = [self generateEntriedForLoginType:loginType].mutableCopy;
    self.countryID = userCountryID;
    self.countryPhoneCode = userCountryCode;
    
    [self configureNavigationItems];
    [self observeKeyboardNotificationAtVerifyCodeProcess];
    [self observeTextFieldContentToSetupActionButtonEnableStatus];
    
    return self;
}

/// Initialize with country code and country id
- (id)initWithNYLoginProcessType:(NYLoginProcessType)loginType userCountryCode:(NSString *)userCountryCode userCountryID:(NSNumber *)userCountryID {
    return [self initWithNYLoginProcessType:loginType viewModel:nil userCountryCode:userCountryCode userCountryID:userCountryID];
}

/// Initialize with NYLoginProcessType
- (id)initWithNYLoginProcessType:(NYLoginProcessType)loginType {
    self = [self initWithNYLoginProcessType:loginType userCountryCode:nil userCountryID:nil];
    return self;
}

+ (NYLoginViewController *)loginVC {
    NYLoginViewController *loginVC = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeLogin];
    
    return loginVC;
}

+ (NYLoginViewController *)validateCellPhoneVC {
    NYLoginViewController *vc = [[NYLoginViewController alloc]
                                          initWithNYLoginProcessType:NYLoginProcessTypeSocialAccountValidateCellPhone
                                          userCountryCode:@""
                                          userCountryID:@1];
    
    return vc;
}

+ (void)customBackButtonImageName:(NSString *)leftButtonImageName andDismissButtonImageName:(NSString *)rightButtonImageName andTitleViewImageName:(NSString *)titleImageName {
    [NYLoginVCInfo sharedInfo].backButtonImageName = leftButtonImageName;
    [NYLoginVCInfo sharedInfo].dismissButtonImageName = rightButtonImageName;
    [NYLoginVCInfo sharedInfo].titleImageName = titleImageName;
}

+ (void)customPresentCompletion:(NYLoginPresentCompletion)presentCompletion andDismissCompletion:(NYLoginDismissCompletion)dismissCompletion {
    NYLoginVCInfo *info = [NYLoginVCInfo sharedInfo];
    info.presentCompletion = presentCompletion;
    info.dismissCompletion = dismissCompletion;
}

// MARK: - lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self registerCellIdentifierFromEntries:self.entries];
    self.alertPresenter = [[NYAlertPresenter alloc] init];

    self.resendVerifyCodeServiceButton.isAccessibilityElement = YES;
    self.resendVerifyCodeServiceButton.accessibilityIdentifier = AccessibilityID.loginResendSmsBtn;
    self.resendVerifyCodeServiceButtonLabel.layer.cornerRadius = 6.0f;
    self.resendVerifyCodeServiceButtonLabel.layer.masksToBounds = YES;
    self.resendVerifyCodeServiceButtonIcon.image = [UIImage iconWithKey:IconKey.ico_mail size:20 tintColor: [UIColor colorWithHexString:@"000000"] backgroundColor:[UIColor clearColor]];
    [self setupResendVerifyCodeButtonEnable:YES withTitle:NYLocalizedString(@"login_btn_resend_verify_code", nil)];
    self.verifyViaVoiceServiceButtonIcon.image = [[UIImage iconWithKey:IconKey.ico_phone size:20 tintColor: [UIColor colorWithHexString:@"ffffff"] backgroundColor:[UIColor clearColor]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.verifyViaVoiceServiceButton setTitle:NYLocalizedString(@"login_voice_verify", nil) forState:UIControlStateNormal];

    self.registerWithCellPhoneRemindDescription.text = NYLocalizedString(@"member_personal_info_protection_registration_cancel_hint_text", nil);
    [self.registerWithCellPhoneRemindButton addTarget:self action:@selector(dismissSelfFromPresentingByUser) forControlEvents:UIControlEventTouchUpInside];
    [self updateCellPhoneRemindViewHidden];
    
    //只有商店會有在登入頁的時候去確認要不要顯示OAuth登入按鈕及廣告版位
    if (self.loginType == NYLoginProcessTypeLogin) {
        [self fetchThirdPartyAuthInfoAndLineChannelIdAndAdBannerInfo];
    }
    
    //只有在輸入驗證碼頁會執行沒收到簡訊的倒數計時
    [self countDownNotRecevingSMSIfNeededWithLoginType:self.loginType];
    
    // reCaptcha
    BOOL isReCaptchaEnabled = [NYUserDefault isReCaptchaEnable];
    NSString *reCaptchaApiKey = [NYModuleConfig reCaptchaApiKey];
    self.canUseReCaptcha = (isReCaptchaEnabled && ![reCaptchaApiKey isEqualToString:@""]);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self prepareForLogin];
    [self prepareForValidateCellPhone];
    [self prepareForBindingCellPhoneSetPassword];
    [self prepareForMemberDirectSetPassword];
    [self sendAnalytics];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.loginType != NYLoginProcessTypeLogin) {
        //登入首頁以外、如果遇到有輸入框的畫面須自動focus
        NSIndexPath *indexPath = [[self indexPathForTextField] firstObject];
        if (indexPath) {
            NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
            [cell textFieldBecomeFirstResponder];
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    // 為了讓使用者重新回到這要這頁要可以看到原本的樣子，在did disappear做reload
    if (self.loginType == NYLoginProcessTypeLogin) {
        self.entries = [self generateEntriedForLoginType:NYLoginProcessTypeLogin].mutableCopy;
        [self fetchThirdPartyAuthInfoAndLineChannelIdAndAdBannerInfo];
    }
    
    // reset
    NYLoginVCInfo *info = [NYLoginVCInfo sharedInfo];
    info.presentCompletion = nil;
    info.dismissCompletion = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [self removeObserverForKeyboard];
    [self removeObserverForLoginInfo];
    
    //檢查是否為iPad點擊黑色部分關掉右邊頁面
    if (self.loginType == NYLoginProcessTypeLogin && self.entries && !self.isNormallyClosed) {
        NYLoginVCInfo *info = [NYLoginVCInfo sharedInfo];
        if (info.shouldShowUnloginMask) {
            [info.waitingForLoginVC displayUnloginView];
        }
    }
}

- (void)sendAnalytics {
    switch (self.loginType) {
        case NYLoginProcessTypeLogin:
            [[NYStatisticHelper sharedHelper] sendPageName:@"Login" title:nil pageId:nil];
            break;
        default:
            break;
    }
}

- (void)prepareForLogin {
    if (self.loginType == NYLoginProcessTypeLogin) {
        //先確認是否需要進行OAuth登入再將使用者資料清空
        if (self.shouldGetInternalTokenAndLogin) {
            self.shouldGetInternalTokenAndLogin = NO;
            
            if ([[NYLoginUserDataModel sharedModel] accessToken]) {
                //485行會把NYLoginUserDataModel accessToken清掉、所以這邊用viewController的property存下來
                self.accessToken = [[NYLoginUserDataModel sharedModel] accessToken];
                
                [self getThirdpartyMemberRegisterStatusWithToken];
            }
        }
        
        //進到登入首頁、把原本暫存的使用者資料清空
        [[NYLoginUserDataModel sharedModel] clear];
        
        // 取得需不需要強制輸入使用者資料 or 通知聲明
        [self fetchRegisterSettingConfig];
        
        // 取得密碼 regex 規則設定
        [self fetchPasswordRegexSetting:nil];
    }
}

- (void)prepareForValidateCellPhone {
    if (self.loginType == NYLoginProcessTypeSocialAccountValidateCellPhone ||
        self.loginType == NYLoginProcessTypeSocialAccountBindingCellPhone) {
        // 進到手機驗證/綁定頁，把原本暫存的使用者資料清空
        [[NYLoginUserDataModel sharedModel] clear];
    }
}

- (void)prepareForBindingCellPhoneSetPassword {
    BOOL shouldRefetch = [NYLoginUserDataModel sharedModel].passwordRegexContents.count == 0 &&
    (self.loginType == NYLoginProcessTypeSocialAccountBindingCellPhonSetPassword ||
     self.loginType == NYLoginProcessTypeMemberDirectSetPassword);
    
    if (shouldRefetch) {
        __weak typeof(self) weakSelf = self;
        
        // 取得密碼 regex 規則設定
        [self fetchPasswordRegexSetting:^{
            // 帳號綁定狀態為: 已綁定手機，待設定密碼
            // 若直接從帳號綁定頁進入，可能會沒有密碼規則，故需先取得密碼規則，重新產生 entries render 畫面
            weakSelf.entries = [weakSelf generateEntriedForLoginType:weakSelf.loginType].mutableCopy;
            [weakSelf registerCellIdentifierFromEntries:weakSelf.entries];
            
            [weakSelf.collectionView reloadData];
        }];
    }
}

- (void)prepareForMemberDirectSetPassword {
    if (self.loginType == NYLoginProcessTypeVerifyCodeMemberDirectSetPassword) {
        [self prepareSetPasswordOTP];
    }
}

- (void)configureNavigationItems {
    if (self.loginType == NYLoginProcessTypeSocialAccountValidateCellPhone) {
        UIAction *dismissAction = [UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
            [self dismissSelfFromPresentingByUser];
        }];
        
        UIBarButtonItem *dissmissButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                 primaryAction:dismissAction];
        
        self.navigationItem.rightBarButtonItem = dissmissButton;
        self.navigationItem.title = NYLocalizedString(@"member_verify_cell_phone_title", nil);
        
    } else if ([NYLoginVCInfo sharedInfo].titleImageName) {
        UIImageView *titleImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[NYLoginVCInfo sharedInfo].titleImageName]];
        //做法與 NYHomeViewPagerController 一樣
        //這邊如果把width改成比圖片窄的話UIKit會自動把titleView的寬度改成圖片的寬度
        //比圖片寬的話卻又會變成設定的寬度，所以width設0讓UIKit自己抓，但是高度沒有此規則
        if (![NYModuleConfig isBrandIdentityModuleEnabled]) {
            [titleImageView setFrame:CGRectMake(0, 0, 0, 42)];
        }
        self.navigationItem.titleView = titleImageView;
    } else {
        self.navigationItem.title = NYLocalizedString(@"login_btn_login", nil);
    }

    if (self.loginType == NYLoginProcessTypeLogin ||
        self.loginType == NYLoginProcessTypeSocialAccountBindingCellPhone ||
        self.loginType == NYLoginProcessTypeSocialAccountBindingCellPhonSetPassword ||
        self.loginType == NYLoginProcessTypeVerifyCodeMemberDirectSetPassword ||
        self.loginType == NYLoginProcessTypeMemberDirectSetPassword ||
        self.loginType == NYLoginProcessTypeExpressSetPassword) {
        UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        spaceItem.width = -11.0f;
        UIBarButtonItem *dismiss = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismissSelfFromPresentingByUser)];
        
        if ([NYLoginVCInfo sharedInfo].dismissButtonImageName) {
            UIButton *dismissButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 40.0f, 40.0f)];
            [dismissButton setImage:[[UIImage iconWith:[NYLoginVCInfo sharedInfo].dismissButtonImageName size:24] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
            [dismissButton setTintColor:[[NYCMSThemeEngine sharedInstance] subColor] ? : [UIColor iconCommonWebViewCloseTintColor]];
            [dismissButton addTarget:self action:@selector(dismissSelfFromPresentingByUser) forControlEvents:UIControlEventTouchUpInside];
            
            dismiss = [[UIBarButtonItem alloc] initWithCustomView:dismissButton];
            self.navigationItem.rightBarButtonItems = @[spaceItem, dismiss];
        }
        
        self.navigationItem.rightBarButtonItem = dismiss;
    }
}

- (void)observeKeyboardNotificationAtVerifyCodeProcess {
    switch (self.loginType) {
        case NYLoginProcessTypeLogin:
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideAdBanner) name:UIKeyboardDidShowNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showAdBanner) name:UIKeyboardDidHideNotification object:nil];
            break;
        case NYLoginProcessTypeVerifyCodeFacebookRegister:
        case NYLoginProcessTypeVerifyCodeLineLoginRegister:
        case NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish:
        case NYLoginProcessTypeVerifyCodeNineYiForgetPassword:
        case NYLoginProcessTypeVerifyCodeNineYiRegister:
        case NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber:
        case NYLoginProcessTypeVerifyCodeThirdpartyRegister:
        case NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone:
        case NYLoginProcessTypeLineLoginExceedSMSLimit:
        case NYLoginProcessTypeVerifyCodeExpressRegister:
        case NYLoginProcessTypeVerifyCodeExpressResetPassword:
        case NYLoginProcessTypeVerifyCodeMemberDirectSetPassword:
        {
            [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(viewWillAppear:) name:UIApplicationDidBecomeActiveNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShowNotification:) name:UIKeyboardWillChangeFrameNotification object:nil];
        }
            break;
            
        case NYLoginProcessTypeNineYiEnterPassword:
        case NYLoginProcessTypeNineYiSetPassword:
        case NYLoginProcessTypeSocialAccountBindingCellPhonSetPassword:
        case NYLoginProcessTypeMemberDirectSetPassword:
        case NYLoginProcessTypeExpressSetPassword:
        case NYLoginProcessTypeFacebookBingingCellPhone:
        case NYLoginProcessTypeFacebookBingingCellPhoneNotFinish:
        case NYLoginProcessTypeLineLoginBingingCellPhone:
        case NYLoginProcessTypeNineYiResetPassword:
        case NYLoginProcessTypeExpressResetPassword:
        case NYLoginProcessTypeNineYiISPResetPassword:
        case NYLoginProcessTypeThirdpartyBingingCellPhone:
        case NYLoginProcessTypeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeSocialAccountBindingCellPhone:
        case NYLoginProcessTypeUnknown:
        default:
            break;
    }
}

- (void)removeObserverForKeyboard {
    switch (self.loginType) {
        case NYLoginProcessTypeLogin:
        case NYLoginProcessTypeVerifyCodeFacebookRegister:
        case NYLoginProcessTypeVerifyCodeLineLoginRegister:
        case NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish:
        case NYLoginProcessTypeVerifyCodeNineYiForgetPassword:
        case NYLoginProcessTypeVerifyCodeNineYiRegister:
        case NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber:
        case NYLoginProcessTypeVerifyCodeThirdpartyRegister:
        case NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone:
        case NYLoginProcessTypeLineLoginExceedSMSLimit:
        case NYLoginProcessTypeVerifyCodeExpressRegister:
        case NYLoginProcessTypeVerifyCodeExpressResetPassword:
        case NYLoginProcessTypeVerifyCodeMemberDirectSetPassword:
        {
            [[NSNotificationCenter defaultCenter] removeObserver:self];
        }
            break;
            
        case NYLoginProcessTypeNineYiEnterPassword:
        case NYLoginProcessTypeNineYiSetPassword:
        case NYLoginProcessTypeSocialAccountBindingCellPhonSetPassword:
        case NYLoginProcessTypeMemberDirectSetPassword:
        case NYLoginProcessTypeExpressSetPassword:
        case NYLoginProcessTypeFacebookBingingCellPhone:
        case NYLoginProcessTypeFacebookBingingCellPhoneNotFinish:
        case NYLoginProcessTypeLineLoginBingingCellPhone:
        case NYLoginProcessTypeNineYiResetPassword:
        case NYLoginProcessTypeExpressResetPassword:
        case NYLoginProcessTypeNineYiISPResetPassword:
        case NYLoginProcessTypeThirdpartyBingingCellPhone:
        case NYLoginProcessTypeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeSocialAccountBindingCellPhone:
        case NYLoginProcessTypeUnknown:
        default:
            break;
    }
}

- (void)abortLoginOrRegisterProcess {
    switch (self.loginType) {
        case NYLoginProcessTypeNineYiResetPassword:
        case NYLoginProcessTypeExpressResetPassword:
        case NYLoginProcessTypeNineYiISPResetPassword:
        case NYLoginProcessTypeNineYiSetPassword:
        case NYLoginProcessTypeSocialAccountBindingCellPhonSetPassword:
        case NYLoginProcessTypeMemberDirectSetPassword:
        case NYLoginProcessTypeExpressSetPassword:
        case NYLoginProcessTypeVerifyCodeFacebookRegister:
        case NYLoginProcessTypeVerifyCodeLineLoginRegister:
        case NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish:
        case NYLoginProcessTypeVerifyCodeNineYiForgetPassword:
        case NYLoginProcessTypeVerifyCodeNineYiRegister:
        case NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber:
        case NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone:
        case NYLoginProcessTypeFacebookBingingCellPhone:
        case NYLoginProcessTypeFacebookBingingCellPhoneNotFinish:
        case NYLoginProcessTypeLineLoginBingingCellPhone:
        case NYLoginProcessTypeThirdpartyBingingCellPhone:
        case NYLoginProcessTypeVerifyCodeThirdpartyRegister:
        case NYLoginProcessTypeLineLoginExceedSMSLimit:
        case NYLoginProcessTypeVerifyCodeExpressRegister:
        case NYLoginProcessTypeVerifyCodeExpressResetPassword:
        {
            __weak typeof(self) weakSelf = self;
            [self.registerWithCellPhoneRemindView setHidden:YES];
            [self ny_displayAlertWithTitle:NYLocalizedString(@"login_alert_interrupt_login_title", nil) message:nil confirmBlock:^{
                [weakSelf.navigationController popToRootViewControllerAnimated:YES];
            } cancelBlock:^{
                if (self.isExistingMemberForgetPassword == YES) {
                    // Do nothing
                } else {
                    [UIView transitionWithView:self.registerWithCellPhoneRemindView duration:1 options:UIViewAnimationOptionTransitionFlipFromLeft animations:^{
                        self.registerWithCellPhoneRemindView.alpha = 1;
                    } completion:^(BOOL finished) {
                        [self.registerWithCellPhoneRemindView setHidden:NO];
                    }];
                }
            }];
        }
            break;
        case NYLoginProcessTypeLogin:
        case NYLoginProcessTypeNineYiEnterPassword:
        case NYLoginProcessTypeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeSocialAccountBindingCellPhone:
        case NYLoginProcessTypeUnknown:
        default:
            [self.navigationController popViewControllerAnimated:YES];
            break;
    }
    
}

- (void)keyboardDidShowNotification:(NSNotification *)notif {
    NSIndexPath *indexPath = [self indexPathForCellType:NYLoginCellTypeNotRecevingSMSMessage];
    if (!indexPath) {
        [self.collectionView performBatchUpdates:^{
            //NOTE: 直接把沒收到簡訊的cell加在最後面、沒去檢查ActionButton的indexPath
            [self.entries addObject:@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNotRecevingSMSMessage andContent:nil]]];
            [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:[self indexPathForCellType:NYLoginCellTypeNotRecevingSMSMessage].section]];
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 animations:^{
                self.notRecevingSMSMessageHelpViewBottomConstraint.constant = -CGRectGetHeight(self.notRecevingSMSMessageHelpView.frame);
                CGFloat keyboardHeight = CGRectGetHeight([[[notif userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue]);
                self.registerWithCellPhoneRemindViewBottomConstraint.constant = keyboardHeight;
                [self.view layoutIfNeeded];
            }];
        }];
    } else {
        [UIView animateWithDuration:0.5 animations:^{
            CGFloat keyboardHeight = CGRectGetHeight([[[notif userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue]);
            self.registerWithCellPhoneRemindViewBottomConstraint.constant = keyboardHeight;
            [self.registerWithCellPhoneRemindView.superview layoutIfNeeded];
        }];
    }
}

- (void)observeTextFieldContentToSetupActionButtonEnableStatus {
    switch (self.loginType) {
        case NYLoginProcessTypeFacebookBingingCellPhone:
        case NYLoginProcessTypeFacebookBingingCellPhoneNotFinish:
        case NYLoginProcessTypeLineLoginBingingCellPhone:
        case NYLoginProcessTypeThirdpartyBingingCellPhone:
        case NYLoginProcessTypeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeSocialAccountBindingCellPhone:
            //限制十碼才可按下一步
            [[NYLoginUserDataModel sharedModel] addObserver:self forKeyPath:@"cellPhone" options:NSKeyValueObservingOptionNew context:nil];
            break;
        case NYLoginProcessTypeVerifyCodeFacebookRegister:
        case NYLoginProcessTypeVerifyCodeLineLoginRegister:
        case NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish:
        case NYLoginProcessTypeVerifyCodeNineYiForgetPassword:
        case NYLoginProcessTypeVerifyCodeNineYiRegister:
        case NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber:
        case NYLoginProcessTypeVerifyCodeThirdpartyRegister:
        case NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone:
        case NYLoginProcessTypeLineLoginExceedSMSLimit:
        case NYLoginProcessTypeVerifyCodeExpressRegister:
        case NYLoginProcessTypeVerifyCodeExpressResetPassword:
        case NYLoginProcessTypeVerifyCodeMemberDirectSetPassword:
            //限制四碼才可按下一步
            [[NYLoginUserDataModel sharedModel] addObserver:self forKeyPath:@"verifyCode" options:NSKeyValueObservingOptionNew context:nil];
            break;
        case NYLoginProcessTypeNineYiEnterPassword:
        case NYLoginProcessTypeNineYiResetPassword:
        case NYLoginProcessTypeExpressResetPassword:
        case NYLoginProcessTypeNineYiISPResetPassword:
        case NYLoginProcessTypeNineYiSetPassword:
        case NYLoginProcessTypeSocialAccountBindingCellPhonSetPassword:
        case NYLoginProcessTypeMemberDirectSetPassword:
        case NYLoginProcessTypeExpressSetPassword:
            //限制六碼以上才可按下一步
            [[NYLoginUserDataModel sharedModel] addObserver:self forKeyPath:@"password" options:NSKeyValueObservingOptionNew context:nil];
            break;
        case NYLoginProcessTypeLogin:
        case NYLoginProcessTypeUnknown:
        default:
            break;
    }
}

- (void)removeObserverForLoginInfo {
    switch (self.loginType) {
        case NYLoginProcessTypeFacebookBingingCellPhone:
        case NYLoginProcessTypeFacebookBingingCellPhoneNotFinish:
        case NYLoginProcessTypeLineLoginBingingCellPhone:
        case NYLoginProcessTypeThirdpartyBingingCellPhone:
        case NYLoginProcessTypeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeSocialAccountBindingCellPhone:
            //限制十碼才可按下一步
            [[NYLoginUserDataModel sharedModel] removeObserver:self forKeyPath:@"cellPhone"];
            break;
        case NYLoginProcessTypeVerifyCodeFacebookRegister:
        case NYLoginProcessTypeVerifyCodeLineLoginRegister:
        case NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish:
        case NYLoginProcessTypeVerifyCodeNineYiForgetPassword:
        case NYLoginProcessTypeVerifyCodeNineYiRegister:
        case NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber:
        case NYLoginProcessTypeVerifyCodeThirdpartyRegister:
        case NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone:
        case NYLoginProcessTypeLineLoginExceedSMSLimit:
        case NYLoginProcessTypeVerifyCodeExpressRegister:
        case NYLoginProcessTypeVerifyCodeExpressResetPassword:
        case NYLoginProcessTypeVerifyCodeMemberDirectSetPassword:
            //限制四碼才可按下一步
            [[NYLoginUserDataModel sharedModel] removeObserver:self forKeyPath:@"verifyCode"];
            break;
        case NYLoginProcessTypeNineYiEnterPassword:
        case NYLoginProcessTypeNineYiResetPassword:
        case NYLoginProcessTypeExpressResetPassword:
        case NYLoginProcessTypeNineYiISPResetPassword:
        case NYLoginProcessTypeNineYiSetPassword:
        case NYLoginProcessTypeSocialAccountBindingCellPhonSetPassword:
        case NYLoginProcessTypeMemberDirectSetPassword:
        case NYLoginProcessTypeExpressSetPassword:
            //限制六碼以上才可按下一步
            [[NYLoginUserDataModel sharedModel] removeObserver:self forKeyPath:@"password"];
            break;
        case NYLoginProcessTypeLogin:
        case NYLoginProcessTypeUnknown:
        default:
            break;
    }
}

- (BOOL)shouldHideRegisterRemindView {
    // 非註冊流程，不顯示提醒文案
    BOOL isNotRegisterFlow = self.loginType == NYLoginProcessTypeSocialAccountValidateCellPhone ||
    self.loginType == NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber ||
    self.loginType == NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone ||
    self.loginType == NYLoginProcessTypeSocialAccountBindingCellPhone ||
    self.loginType == NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone ||
    self.loginType == NYLoginProcessTypeVerifyCodeExpressRegister ||
    self.loginType == NYLoginProcessTypeVerifyCodeExpressResetPassword ||
    self.loginType == NYLoginProcessTypeVerifyCodeMemberDirectSetPassword;
    
    return self.isExistingMemberForgetPassword || isNotRegisterFlow;
}

- (void)updateCellPhoneRemindViewHidden {
    if ([self shouldHideRegisterRemindView] == YES) {
        [self.registerWithCellPhoneRemindView setHidden:YES];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NYLoginUserDataModel *userModel = [NYLoginUserDataModel sharedModel];
    
    if ([keyPath isEqualToString:@"password"]) {
        NSIndexPath *indexPath = [self indexPathForCellType:NYLoginCellTypeNineYiActionButton];
        NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        [cell cellActionButtonEnable:(userModel.password)];
    }
    else if ([keyPath isEqualToString:@"verifyCode"]) {
        if (self.loginType == NYLoginProcessTypeVerifyCodeFacebookRegister ||
            self.loginType == NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish) {
            NSIndexPath *indexPath = [self indexPathForCellType:NYLoginCellTypeFacebookAction];
            NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
            [cell cellActionButtonEnable:(userModel.verifyCode)];
        }
        else if (self.loginType == NYLoginProcessTypeVerifyCodeNineYiForgetPassword ||
                   self.loginType == NYLoginProcessTypeVerifyCodeNineYiRegister ||
                   self.loginType == NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber ||
                   self.loginType == NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone ||
                   self.loginType == NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone ||
                   self.loginType == NYLoginProcessTypeVerifyCodeExpressRegister ||
                   self.loginType == NYLoginProcessTypeVerifyCodeExpressResetPassword ||
                   self.loginType == NYLoginProcessTypeVerifyCodeMemberDirectSetPassword) {
            NSIndexPath *indexPath = [self indexPathForCellType:NYLoginCellTypeNineYiActionButton];
            NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
            [cell cellActionButtonEnable:(userModel.verifyCode)];
        }
        else if (self.loginType == NYLoginProcessTypeVerifyCodeThirdpartyRegister) {
            NSIndexPath *indexPath = [self indexPathForCellType:NYLoginCellTypeThirdpartyAuthCellPhoneBindingAction];
            NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
            [cell cellActionButtonEnable:(userModel.verifyCode)];
        }
        else if (self.loginType == NYLoginProcessTypeVerifyCodeLineLoginRegister ||
                 self.loginType == NYLoginProcessTypeLineLoginExceedSMSLimit) {
            NSIndexPath *indexPath = [self indexPathForCellType:NYLoginCellTypeLineLoginAction];
            NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
            [cell cellActionButtonEnable:(userModel.verifyCode)];
        }
    }
    else if ([keyPath isEqualToString:@"cellPhone"]) {
        NSIndexPath *indexPath;
        if ([self indexPathForCellType:NYLoginCellTypeFacebookAction]) {
            indexPath = [self indexPathForCellType:NYLoginCellTypeFacebookAction];
        }
        else if ([self indexPathForCellType:NYLoginCellTypeAppleSignInAction]) {
            indexPath = [self indexPathForCellType:NYLoginCellTypeAppleSignInAction];
        }
        else if ([self indexPathForCellType:NYLoginCellTypeThirdpartyAuthCellPhoneBindingAction]) {
            indexPath = [self indexPathForCellType:NYLoginCellTypeThirdpartyAuthCellPhoneBindingAction];
        }
        else if ([self indexPathForCellType:NYLoginCellTypeLineLoginAction]) {
            indexPath = [self indexPathForCellType:NYLoginCellTypeLineLoginAction];
        }
        else if (self.loginType == NYLoginProcessTypeSocialAccountValidateCellPhone) {
            indexPath = [self indexPathForCellType:NYLoginCellTypeNineYiActionButton];
        }
        else if (self.loginType == NYLoginProcessTypeSocialAccountBindingCellPhone) {
            indexPath = [self indexPathForCellType:NYLoginCellTypeNineYiActionButton];
        }

        NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        [cell cellActionButtonEnable:(userModel.cellPhone)];
    }
}

#pragma mark - Actions
- (void)actionForNineYiActionButton {
    NYLoginUserDataModel *userModel = [NYLoginUserDataModel sharedModel];
    switch (self.loginType) {
        case NYLoginProcessTypeLogin:
            [self.view endEditing:YES];
            [self nineyiActionButtonAtLoginProcessTypeLogin];
            break;
        case NYLoginProcessTypeNineYiEnterPassword:
        {
            if (userModel.password) {
                [self.view endEditing:YES];
                [self nineyiActionButtonAtLoginProcessTypeNineYiEnterPassword];
            }
        }
            break;
        case NYLoginProcessTypeNineYiSetPassword:
        {
            if (userModel.password) {
                [self.view endEditing:YES];
                [self nineyiActionButtonAtLoginProcessTypeNineYiSetPassword];
            }
        }
            break;
        case NYLoginProcessTypeSocialAccountBindingCellPhonSetPassword:
        case NYLoginProcessTypeMemberDirectSetPassword:
        case NYLoginProcessTypeExpressSetPassword: {
            if (userModel.password) {
                [self.view endEditing:YES];
                [self nineyiActionButtonAtSetPassword];
            }
        }
            break;
        case NYLoginProcessTypeNineYiResetPassword:
        case NYLoginProcessTypeExpressResetPassword:
        {
            if (userModel.password) {
                [self.view endEditing:YES];
                [self nineyiActionButtonAtLoginProcessTypeNineYiResetPassword];
            }
        }
            break;
        case NYLoginProcessTypeNineYiISPResetPassword: {
            if (userModel.password) {
                [self.view endEditing:YES];
                [self nineyiActionButtonAtLoginProcessTypeNineYiResetPassword];
            }
        }
            break;
        case NYLoginProcessTypeVerifyCodeNineYiRegister:
        case NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber:
        case NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone:
        case NYLoginProcessTypeVerifyCodeExpressRegister:
        {
            if (userModel.verifyCode) {
                [self.view endEditing:YES];
                //-34: iPhoneX padding
                self.notRecevingSMSMessageHelpViewBottomConstraint.constant = -CGRectGetHeight(self.notRecevingSMSMessageHelpView.frame) - 34;
                
                [self.notRecevingSMSMessageHelpView layoutIfNeeded];
                
                self.view.backgroundColor = [UIColor colorWithHexString:@"0xF7F7F7"];

                if (self.loginType == NYLoginProcessTypeVerifyCodeExpressRegister &&
                    self.flowViewModel.isLoginFlow) {
                    [self nineyiActionButtonAtLoginProcessTypeVerifyCodeLogin];
                    break;
                }
                
                [self nineyiActionButtonAtLoginProcessTypeVerifyCodeRegister];
            }
        }
            break;
        case NYLoginProcessTypeVerifyCodeNineYiForgetPassword:
        case NYLoginProcessTypeVerifyCodeExpressResetPassword:
        case NYLoginProcessTypeVerifyCodeMemberDirectSetPassword:
        {
            if (userModel.verifyCode) {
                [self.view endEditing:YES];
                self.notRecevingSMSMessageHelpViewBottomConstraint.constant = -CGRectGetHeight(self.notRecevingSMSMessageHelpView.frame);
                
                [self nineyiActionButtonAtLoginProcessTypeVerifyCodeNineYiForgetPassword];
            }
        }
            break;
        case NYLoginProcessTypeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeSocialAccountBindingCellPhone: {
            [self.view endEditing:YES];
            [self actionButtonAtLoginProcessTypeSocialAccountValidateCellPhone];
        }
            break;
        default:
            break;
    }
}

- (void)actionForThirdpartyAuthActionButton {
    [self.view endEditing:YES];
    __weak typeof(self) weakSelf = self;
    
    if (self.loginType == NYLoginProcessTypeLogin) {
        if (self.accessToken) {
            [self getThirdpartyMemberRegisterStatusWithToken];
        } else {
            self.shouldGetInternalTokenAndLogin = YES;
            
            NSURL *url = [NSURL URLWithString:self.thirdPartyAuthLoginInfoDic[@"ThirdPartyOAuthUrl"]];
            NYThirdPartyLoginWebBrowserVC *webVC = [NYThirdPartyLoginWebBrowserVC viewControllerWithOAuthURL:url];
            [self.navigationController pushViewController:webVC animated:YES];
        }
    } else {
        [self.collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof NYLoginCell * _Nonnull cell, NSUInteger idx, BOOL * _Nonnull stop) {
            [cell configureTextFieldLayoutWithWarningEffect:NO warningType:NYWarningTypeNone];
        }];
        
        NYLoginUserDataModel *userModel = [NYLoginUserDataModel sharedModel];
        [self textFormatCheck:userModel.loginId cellType:NYLoginCellTypeThirdpartyAuthInputAccountCell WithWarningMessage:NYLocalizedString(@"login_input_account", nil) AndSuccessCompletion:^{
            [weakSelf textFormatCheck:userModel.thirdpartyPassword cellType:NYLoginCellTypeThirdpartyAuthInputPasswordCell WithWarningMessage:NYLocalizedString(@"login_input_password", nil) AndSuccessCompletion:^{
                [NYProgressHUD showHUDAddedToView:weakSelf.view];
                
                //舊的第三方登入、source、device、appVer因api參數調整不需再帶
                [[NYLoginHelper sharedInstance] getThirdpartyMemberRegisterStatusWithLoginId:userModel.loginId
                                                                                    password:userModel.thirdpartyPassword
                                                                                      shopId:[NYGlobalData shopId]
                                                                                 countryCode:self.countryPhoneCode
                                                                                   countryID:self.countryID
                                                                           completionHandler:^(NSDictionary *data, NSError *error) {
                    //Before Login time
                    NSDate *timeBeforeLogin = [[NYLoginVCInfo sharedInfo] loginProcessStartTime];
                    
                    [NYProgressHUD hideAllHUDsForView:weakSelf.view];
                    if (error) {
                        [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                            [weakSelf actionForThirdpartyAuthActionButton];
                        }];
                    }
                    else {
                        NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
                        NSString *message = [weakSelf apiReturnMessageForReturnData:data];

                        //登入成功
                        if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetThirdpartyMemberRegisterStatusSuccess]) {
                            [weakSelf dismissSelfFromPresentingAfterLoginSuccessWithIsRegister:NO];
                            
                            // FA
                            NSTimeInterval loginDuration = [timeBeforeLogin timeIntervalSinceNow];
                            [[NYStatisticHelper sharedHelper] sendEventLoginWithMethod:kFAParamSignupLoginMethodShopAccount
                                                                                status:kFAParamSignupLoginStatusFinish
                                                                              duration:@(-loginDuration)];
                        }
                        //密碼錯誤
                        else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetThirdpartyMemberRegisterStatusWrongPassword]) {
                            NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[weakSelf indexPathForCellType:NYLoginCellTypeThirdpartyAuthInputPasswordCell]];
                            [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypePassword];
                            [weakSelf insertWaringCellAfterIndexPath:[weakSelf indexPathForCellType:NYLoginCellTypeThirdpartyAuthInputPasswordCell] withWariningMessage:message];
                        }
                        //未完成註冊
                        else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetThirdpartyMemberRegisterStatusRegisterNotFinished]) {
                            userModel.thirdpartyToken = data[kDATA_KEY][@"Data"][@"token"];
                            NYLoginViewController *bindingCellPhone = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeThirdpartyBingingCellPhone userCountryCode:self.countryPhoneCode userCountryID:self.countryID];
                            [self.navigationController pushViewController:bindingCellPhone animated:YES];
                        }
                        //系統錯誤
                        else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetThirdpartyMemberRegisterStatusSystemError]) {
                            [weakSelf displayAlertMessage:message];
                        }
                    }
                }];
            }];
        }];
    }
}

//登入首頁、按下「Facebook」
- (void)actionForLoginViaFacebookAtLoginProcessLogin {
    [self.view endEditing:YES];
    [NYProgressHUD showMessage:NYLocalizedString(@"login_fb_getting_authorize", nil) toView:self.view];
    
    [self handleFacebookLogin];
}

- (void)checkFacebookUserRegisterStatusWithAccessToken:(NSString *)token authToken:(NSString *)authToken {
    [NYProgressHUD showHUDAddedToView:self.view];
    
    __weak typeof(self) weakSelf = self;
    [[NYLoginHelper sharedInstance] getRegisterStatusViaFacebookWithShopID:[NYGlobalData shopId] 
                                                               accessToken:token
                                                                 authToken:authToken
                                                         completionHandler:^(NSDictionary *data, NSError *error) {
        [NYProgressHUD hideAllHUDsForView:weakSelf.view];
        if (error) {
            [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                [weakSelf checkFacebookUserRegisterStatusWithAccessToken:token authToken:authToken];
            }];
        } else {
            NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
            NSString *message = [weakSelf apiReturnMessageForReturnData:data];
            
            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetFacebookRegisterStatusCodeRegistered]) {
                [weakSelf loginFacebookMember];
                // GA FB登入完成
                NSDate *timeBeforeLogin = [[NYLoginVCInfo sharedInfo] loginProcessStartTime];
                NSTimeInterval loginDuration = [timeBeforeLogin timeIntervalSinceNow];
                [[NYStatisticHelper sharedHelper] sendEventLoginWithMethod:kFAParamSignupLoginMethodFacebook
                                                                    status:kFAParamSignupLoginStatusFinish
                                                                  duration:@(-loginDuration)];
            } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetFacebookRegisterStatusCodeUnfinished]) {
                NYLoginViewController *bindingCellPhone = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeFacebookBingingCellPhoneNotFinish];
                [self.navigationController pushViewController:bindingCellPhone animated:YES];
            } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetFacebookRegisterStatusCodeNotRegistered]) {
                NYLoginViewController *bindingCellPhone = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeFacebookBingingCellPhone userCountryCode:self.countryPhoneCode userCountryID:self.countryID];
                [self.navigationController pushViewController:bindingCellPhone animated:YES];
            } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetFacebookRegisterStatusCodeSystemError]) {
                [self displayAlertMessage:message];
            }
        }
    }];
}

- (void)actionForFBAndLineLoginActionButton {
    NYLoginUserDataModel *userModel = [NYLoginUserDataModel sharedModel];
    
    switch (self.loginType) {
        case NYLoginProcessTypeFacebookBingingCellPhone:
        case NYLoginProcessTypeFacebookBingingCellPhoneNotFinish:
        case NYLoginProcessTypeLineLoginBingingCellPhone:
        {
            if (userModel.cellPhone) {
                [self.view endEditing:YES];
                
                [self fbAndLineActionButtonAtLoginProcessTypeBindgingPhoneWithCountryCode:self.countryPhoneCode countryID:self.countryID];
            }
        }
            break;
        case NYLoginProcessTypeVerifyCodeFacebookRegister:
        case NYLoginProcessTypeVerifyCodeLineLoginRegister:
        case NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish:
        case NYLoginProcessTypeLineLoginExceedSMSLimit:
        {
            if (userModel.verifyCode) {
                [self.view endEditing:YES];
                
                [UIView animateWithDuration:0.5 animations:^{
                    //-34: iPhoneX padding
                    self.notRecevingSMSMessageHelpViewBottomConstraint.constant = -CGRectGetHeight(self.notRecevingSMSMessageHelpView.frame) - 34;
                    [self.notRecevingSMSMessageHelpView.superview layoutIfNeeded];
                }];
                
                self.view.backgroundColor = [UIColor colorWithHexString:@"0xF7F7F7"];

                [self fbAndLineActionButtonAtLoginProcessTypeVerifyCodeRegister];
            }
        }
            break;
        default:
            break;
    }
}

- (void)actionForThirdpartyAuthCellPhoneBindingAction {
    [self.collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof NYLoginCell * _Nonnull cell, NSUInteger idx, BOOL * _Nonnull stop) {
        [cell configureTextFieldLayoutWithWarningEffect:NO warningType:NYWarningTypeNone];
    }];
    
    NYLoginUserDataModel *userModel = [NYLoginUserDataModel sharedModel];
    
    if (self.loginType == NYLoginProcessTypeThirdpartyBingingCellPhone) {
        [self checkIsValidWithCellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                           countryAliasCode:self.countryAliasCode
                          successCompletion:^{
            __weak typeof(self) weakSelf = self;
            NSString *title = NYLocalizedString(@"login_alert_will_send_verify_code_title", nil);
            [weakSelf ny_displayAlertWithTitle:title message:nil confirmBlock:^{
                [NYProgressHUD showHUDAddedToView:weakSelf.view];
                [[NYLoginHelper sharedInstance] createThirdpartyMemberRegisterRequestWithToken:userModel.thirdpartyToken
                                                                                     cellPhone:userModel.cellPhone
                                                                                        shopId:[NYGlobalData shopId]
                                                                                   countryCode:weakSelf.countryPhoneCode
                                                                                     countryID:weakSelf.countryID
                                                                             completionHandler:^(NSDictionary *data, NSError *error) {
                    [NYProgressHUD hideAllHUDsForView:weakSelf.view];
                    if (error) {
                        [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                            [weakSelf actionForThirdpartyAuthCellPhoneBindingAction];
                        }];
                    }
                    else {
                        NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
                        NSString *message = [weakSelf apiReturnMessageForReturnData:data];
                        // 成功 or 綁定的手機待開通
                        if (([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateThirdpartyMemberRegisterRequestSuccess]) || ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetNineYiMemberRegisterStatusNeedActivate])) {
                            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetNineYiMemberRegisterStatusNeedActivate]) {
                                [NYLoginUserDataModel sharedModel].shouldActivate = YES;
                            }
                            NYLoginViewController *verifyCodeVC = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeVerifyCodeThirdpartyRegister userCountryCode:weakSelf.countryPhoneCode userCountryID:weakSelf.countryID];
                            [weakSelf.navigationController pushViewController:verifyCodeVC animated:YES];
                        }
                        //手機格式有誤
                        else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateThirdpartyMemberRegisterRequestInvalidFormat]) {
                            NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[[weakSelf indexPathForTextField] firstObject]];
                            [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeCellPhone];
                            [weakSelf insertWaringCellAfterIndexPath:[[weakSelf indexPathForTextField] firstObject] withWariningMessage:message];
                        }
                        //第三方會員已完成註冊
                        else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateThirdpartyMemberRegisterRequestAlreadyRegistered]) {
                            [weakSelf displayAlertTitle:nil messageAndBackToRoot:message];
                        }
                        //簡訊發送超過限制
                        else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateThirdpartyMemberRegisterRequestReachSMSLimit]) {
                            [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit = YES;
                            NYLoginViewController *verifyCodeVC = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeVerifyCodeThirdpartyRegister userCountryCode:weakSelf.countryPhoneCode userCountryID:weakSelf.countryID];
                            [weakSelf.navigationController pushViewController:verifyCodeVC animated:YES];
                        }
                        //系統錯誤
                        else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateThirdpartyMemberRegisterRequestSystemError]) {
                            [weakSelf displayAlertMessage:message];
                        }
                    }
                }];
            } cancelBlock:nil];
        }];
    } else if (self.loginType == NYLoginProcessTypeVerifyCodeThirdpartyRegister) {
        if (userModel.verifyCode) {
            [self.view endEditing:YES];

            [UIView animateWithDuration:0.5 animations:^{
                //-34: iPhoneX padding
                self.notRecevingSMSMessageHelpViewBottomConstraint.constant = -CGRectGetHeight(self.notRecevingSMSMessageHelpView.frame) - 34;
                [self.notRecevingSMSMessageHelpView.superview layoutIfNeeded];
            }];
            
            self.view.backgroundColor = [UIColor colorWithHexString:@"0xF7F7F7"];

            [self thirdpartyAuthActionButtonAtLoginProcessTypeVerifyCodeThirdpartyAuthRegister];
        }
    }
}

- (void)actionForNotRecevingSMSMessage {
    [self.view endEditing:YES];
    
    self.view.backgroundColor = [UIColor colorWithHexString:@"0xEEEEEE"];
    
    [UIView animateWithDuration:0.5 animations:^{
        self.notRecevingSMSMessageHelpViewBottomConstraint.constant = 0;
        self.registerWithCellPhoneRemindViewBottomConstraint.constant = self.view.safeAreaInsets.bottom + CGRectGetHeight(self.notRecevingSMSMessageHelpView.frame);
        [self.view layoutIfNeeded];
    }];

    NSIndexPath *indexpath = [self indexPathForCellType:NYLoginCellTypeNotRecevingSMSMessage];
    if (indexpath) {
        [self.entries removeObjectAtIndex:indexpath.section];
        [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:indexpath.section]];
    }
    
    if ([self isSMSServiceOnly]) {
        // 隱藏語音驗證按鈕
        [self.verifyViaVoiceServiceButton setHidden:YES];
        [self.verifyViaVoiceServiceButtonIcon setHidden:YES];

        // 重設 constraint，提示訊息對齊簡訊驗證按鈕
        self.dialVerifyViaVoiceServiceTopConstraint = nil;
        self.dialVerifyViaVoiceServiceTopConstraint = [NSLayoutConstraint constraintWithItem:self.dialVerifyViaVoiceServiceDescription
                                                                                   attribute:NSLayoutAttributeTop
                                                                                   relatedBy:NSLayoutRelationEqual
                                                                                      toItem:self.resendVerifyCodeServiceButtonLabel
                                                                                   attribute:NSLayoutAttributeBottom
                                                                                  multiplier:1.0
                                                                                    constant:10.0];
        self.dialVerifyViaVoiceServiceTopConstraint.active = YES;
    }
}

- (void)actionForForgetPassword {
    __weak typeof(self) weakSelf = self;
    [self startResetPasswordMultiFactorAuthWithShopID:[NYGlobalData shopId]
                                            cellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                                          countryCode:self.countryPhoneCode
                                            countryID:self.countryID
                                sendVerifyCodeHandler:^{
        // 只有 不需要雙重驗證 或 走完雙重驗證成功 的才會進來發送簡訊流程
        [weakSelf actionForForgetPasswordWithSendSMSWithIsRegister:NO];
    }];
}

- (void)actionForForgetPasswordWithSendSMSWithIsRegister:(BOOL)isRegister {
    __weak typeof(self) weakSelf = self;
    [self ny_displayAlertWithTitle:NYLocalizedString(@"login_alert_will_send_verify_code_title", nil) message:NYLocalizedString(@"login_alert_will_send_verify_code_msg", nil) confirmBlock:^{
        
        //BTS 14006 Crash防呆, 照理說根本不該跑進此邏輯
        if (![NYLoginUserDataModel sharedModel].cellPhone) {
            [weakSelf displayAlertTitle:NYLocalizedString(@"login_alert_login_system_error", nil) messageAndBackToRoot:nil];
            
            return;
        }
        
        void(^resetPasswordVia91mai)(NSString *) = ^(NSString *reCaptchaToken) {
            [[NYLoginHelper sharedInstance] resetPasswordVia91maiWithShopID:[NYGlobalData shopId]
                                                                  cellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                                                             reCaptchaToken:reCaptchaToken
                                                                countryCode:self.countryPhoneCode
                                                                  countryID:self.countryID
                                                          completionHandler:^(NSDictionary *data, NSError *error) {
                if (error) {
                    [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                        [weakSelf actionForForgetPassword];
                    }];
                } else {
                    NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
                    NSString *message = [weakSelf apiReturnMessageForReturnData:data];
                    
                    [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit = NO;
                    
                    //手機尚未開通要走忘記密碼流程
                    if (([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIResetPasswordCodeSuccess]) || ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetNineYiMemberRegisterStatusNeedActivate])) {
                        NYLoginViewController *verifyCodeVC = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeVerifyCodeNineYiForgetPassword userCountryCode:weakSelf.countryPhoneCode userCountryID:weakSelf.countryID];
                        verifyCodeVC.isExistingMemberForgetPassword = !isRegister;
                        [self.navigationController pushViewController:verifyCodeVC animated:YES];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIResetPasswordCodeReachSMSLimit]) {
                        [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit = YES;
                        NYLoginViewController *verifyCodeVC = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeVerifyCodeNineYiForgetPassword userCountryCode:weakSelf.countryPhoneCode userCountryID:weakSelf.countryID];
                        verifyCodeVC.isExistingMemberForgetPassword = !isRegister;
                        [self.navigationController pushViewController:verifyCodeVC animated:YES];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIResetPasswordCodeNotRegistered]) {
                        [weakSelf displayAlertTitle:nil messageAndBackToRoot:message];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIReCaptchaVerificationError]) {
                        //reCaptcha 驗證失敗
                        [weakSelf displayAlertMessage:message];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIResetPasswordCodeSystemError]) {
                        [weakSelf displayAlertMessage:message];
                    }
                }
            }];
        };
        
        if (weakSelf.canUseReCaptcha) {
            [NYLoginViewController reCaptchaGetTokenBlock](^(NSString *reCaptchaToken) {
                if (reCaptchaToken && ![reCaptchaToken isEqualToString:@""]) {
                    resetPasswordVia91mai(reCaptchaToken);
                } else {
                    // 拿不到 token 就用原 API error 處理方式
                    [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                        [weakSelf actionForForgetPassword];
                    }];
                }
            });
        } else {
            resetPasswordVia91mai(@"");
        }
        
    } cancelBlock:nil];
}

- (void)warningCellPhone:(NSString *)message {
    NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:[[self indexPathForTextField] firstObject]];
    [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeCellPhone];
    [self insertWaringCellAfterIndexPath:[[self indexPathForTextField] firstObject] withWariningMessage:message];
}

#pragma mark - 登入註冊首頁
- (void)nineyiActionButtonAtLoginProcessTypeLogin {
    NYLoginUserDataModel *userModel = [NYLoginUserDataModel sharedModel];

    // 手機格式錯誤、顯示warning cell
    void(^addWariningCell)(NSString *) = ^(NSString *wariningMessage) {
        NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:[[self indexPathForTextField] firstObject]];
        [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeCellPhone];
        [self insertWaringCellAfterIndexPath:[[self indexPathForTextField] firstObject] withWariningMessage:wariningMessage];
    };
    
    // app 先判斷使用者輸入空的電話做訊息提示
    if (!userModel.cellPhone || [userModel.cellPhone isEqualToString:@""]) {
        addWariningCell(NYLocalizedString(@"login_warning_invalid_cellphone", nil));
        return;
    }

    // cellPhone 帶空字串，打 [取得使用者註冊狀態的 API] -> 也會進入 [未註冊+未完成註冊、詢問是否繼續加入會員] -> 再打 Google 確認電話號碼 API 由這邊進行 UI 阻擋。
    NSString *nonnullCellPhoneString = userModel.cellPhone ?: @"";
    NSString *nonnullCountryPhoneCodeString = self.countryPhoneCode ?: @"";
    NSNumber *nonnullCountryID = self.countryID ?: @0;

    //取得使用者註冊狀態
    [NYProgressHUD showHUDAddedToView:self.view];
    void(^getRegisterStatusVia91mai)(NSString *) = ^(NSString *reCaptchaToken) {
        [self loginCellPhoneWithShopID:[NYGlobalData shopId]
                             cellPhone:nonnullCellPhoneString
                        reCaptchaToken:reCaptchaToken
                           countryCode:nonnullCountryPhoneCodeString
                             countryID:nonnullCountryID
                     completionHandler:^(NYLoginMembership * _Nonnull membership) {
            
            __weak typeof(self) weakSelf = self;
            [NYProgressHUD hideAllHUDsForView:self.view];
            
            if (membership.status == CellPhoneMemberRegisterStatusApiError) {
                [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                    [weakSelf nineyiActionButtonAtLoginProcessTypeLogin];
                }];
            } else {
                //註冊過、走登入流程
                if (membership.status == CellPhoneMemberRegisterStatusRegistered) {                   
                    // 繼續登入相關流程（加入開啟驗證碼登入與密碼設定判斷）
                    [weakSelf handleCellPhoneRegistered];
                }

                //未註冊+未完成註冊、詢問是否繼續加入會員
                else if (membership.status == CellPhoneMemberRegisterStatusUnregistered) {
                    
                    if (membership.needSetPassword) {
                        [NYLoginUserDataModel sharedModel].shouldIgnoreMemberPresent = YES;
                    }

                    [weakSelf checkIsValidWithCellPhone:nonnullCellPhoneString
                                       countryAliasCode:weakSelf.countryAliasCode
                                      successCompletion:^{
                        //詢問使用者是否要加入會員、確認：call註冊api、取消：不做事
                        [weakSelf ny_displayAlertWithTitle:nil message:membership.message confirmBlock:^{
                            // 發送驗證碼以進行註冊 / 驗證碼登入 / 驗證碼註冊 流程
                            [weakSelf requestOTPWithShopID:[NYGlobalData shopId]
                                                 cellPhone:nonnullCellPhoneString
                                               countryCode:nonnullCountryPhoneCodeString
                                                 countryID:nonnullCountryID];
                        } cancelBlock:nil];
                    }];
                }

                //尚未開通要走開通流程、進入忘記密碼頁
                else if (membership.status == CellPhoneMemberRegisterStatusNeedActivate) {
                    [NYLoginUserDataModel sharedModel].shouldActivate = YES;
                    [weakSelf actionForForgetPasswordWithSendSMSWithIsRegister:YES];
                }
                
                //reCaptcha 驗證失敗
                else if (membership.status == CellPhoneMemberRegisterStatusReCaptchaVerifyFailed) {
                    [weakSelf displayAlertMessage:membership.message];
                }

                //系統錯誤
                else if (membership.status == CellPhoneMemberRegisterStatusSystemError) {
                    [weakSelf displayAlertMessage:membership.message];
                }
            }
        }];
    };

    if (self.canUseReCaptcha) {
        [NYLoginViewController reCaptchaGetTokenBlock](^(NSString *reCaptchaToken) {
            __weak typeof(self) weakSelf = self;
            if (reCaptchaToken && ![reCaptchaToken isEqualToString:@""]) {
                getRegisterStatusVia91mai(reCaptchaToken);
            } else {
                // 拿不到 token 就用原 API error 處理方式
                [NYProgressHUD hideAllHUDsForView:weakSelf.view];
                [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                    [weakSelf nineyiActionButtonAtLoginProcessTypeLogin];
                }];
            }
        });
    } else {
        getRegisterStatusVia91mai(@"");
    }
}

#pragma mark - 輸入密碼完成登入
- (void)nineyiActionButtonAtLoginProcessTypeNineYiEnterPassword {
    [self textFormateCheck:[NYLoginUserDataModel sharedModel].password checkType:NYLoginTextFieldFormatCheckTypeNoCheck WithWarningMessage:NYLocalizedString(@"login_password_regex_warning_invalid_password_length", nil) AndSuccessCompletion:^{
        //Before Login time
        NSDate *timeBeforeLogin = [[NYLoginVCInfo sharedInfo] loginProcessStartTime];
        __weak typeof(self) weakSelf = self;
        
        //BTS 14006 Crash防呆, 照理說根本不該跑進此邏輯
        if (![NYLoginUserDataModel sharedModel].cellPhone) {
            [weakSelf displayAlertTitle:NYLocalizedString(@"login_alert_login_system_error", nil) messageAndBackToRoot:nil];
            return;
        }
        
        [NYProgressHUD showHUDAddedToView:self.view];
        
        //device參數只有門市小幫手是帶Pad、其餘iOS跟Android都是帶Mobile
        void(^loginVia91mai)(NSString *) = ^(NSString *reCaptchaToken) {
            [[NYLoginHelper sharedInstance] loginVia91maiWithShopID:[NYGlobalData shopId]
                                                          cellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                                                           password:[NYLoginUserDataModel sharedModel].password
                                                     reCaptchaToken:reCaptchaToken
                                                             source:@"iOSApp"
                                                             device:@"Mobile"
                                                         appVersion:[NYGlobalData appVersionString]
                                                        countryCode:self.countryPhoneCode
                                                          countryId:self.countryID
                                                  completionHandler:^(NSDictionary *data, NSError *error) {
                [NYProgressHUD hideAllHUDsForView:weakSelf.view];
                if (error) {
                    [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                        [weakSelf nineyiActionButtonAtLoginProcessTypeNineYiEnterPassword];
                    }];
                } else {
                    NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
                    NSString *message = [weakSelf apiReturnMessageForReturnData:data];
                    
                    if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILoginCodeSuccess]) {
                        [weakSelf dismissSelfFromPresentingAfterLoginSuccessWithIsRegister:NO];

                        [NYLoginViewController commonActionAfterLoginSuccess];

                        // FA 手機登入完成
                        NSString *userPhoneNumber = [NYLoginUserDataModel sharedModel].cellPhone;
                        [self setEventUserInfoWithPhone:userPhoneNumber];
                        NSTimeInterval loginDuration = [timeBeforeLogin timeIntervalSinceNow];
                        [[NYStatisticHelper sharedHelper] sendEventLoginWithMethod:kFAParamSignupLoginMethodPhone
                                                                             status:kFAParamSignupLoginStatusFinish
                                                                           duration:@(-loginDuration)];

                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILoginCodeNeedResetPassword]) {
                        // 小幫手註冊前往重置密碼
                        NYLoginViewController *resetPasswordVC = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeNineYiISPResetPassword userCountryCode:self.countryPhoneCode userCountryID:self.countryID];
                        [weakSelf.navigationController pushViewController:resetPasswordVC animated:YES];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILoginCodeWrongPassword]) {
                        NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[[weakSelf indexPathForTextField] firstObject]];
                        [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypePassword];
                        [weakSelf insertWaringCellAfterIndexPath:[[weakSelf indexPathForTextField] firstObject] withWariningMessage:message];

                        weakSelf.passwordErrorCounter++;
                        if (weakSelf.passwordErrorCounter == 5) {
                            UIAlertAction *yesAction = [UIAlertAction actionWithTitle:NYLocalizedString(@"common_yes", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                weakSelf.passwordErrorCounter = 0;
                            }];

                            UIAlertAction *noAction = [UIAlertAction actionWithTitle:NYLocalizedString(@"common_no", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                                [weakSelf.navigationController popToRootViewControllerAnimated:YES];
                            }];

                            NSString *title = NYLocalizedString(@"login_alert_check_register_account", nil);
                            NSString *message = [NSString stringWithFormat:@"+%@ %@", self.countryPhoneCode, [NYLoginUserDataModel sharedModel].cellPhone];
                            [weakSelf ny_displayAlertWithTitle:title message:message confirmAction:yesAction cancelAction:noAction];
                        }

                        //Show password
                        NYLoginCell *passwordCell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:(NSIndexPath *)[[weakSelf indexPathForTextField] firstObject]];
                        [passwordCell showSecureText];
                        
                    //reCaptcha 驗證失敗
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIReCaptchaVerificationError]) {
                        [weakSelf displayAlertMessage:message];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILoginCodeSystemError]) {
                        [weakSelf displayAlertMessage:message];
                    }
                }
            }];
        };
        
        if (self.canUseReCaptcha) {
            [NYLoginViewController reCaptchaGetTokenBlock](^(NSString *reCaptchaToken) {
                if (reCaptchaToken && ![reCaptchaToken isEqualToString:@""]) {
                    loginVia91mai(reCaptchaToken);
                } else {
                    // 拿不到 token 就用原 API error 處理方式
                    [NYProgressHUD hideAllHUDsForView:weakSelf.view];
                    [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                        [weakSelf nineyiActionButtonAtLoginProcessTypeNineYiEnterPassword];
                    }];
                }
            });
        } else {
            loginVia91mai(@"");
        }
    }];
}

#pragma mark - 驗證碼頁

/// 是否只有簡訊驗證（不支援語音驗證功能）
- (BOOL)isSMSServiceOnly {
    // MY 市場只有簡訊驗證
    NYCountryType countryType = [NYGlobalData countryType];
    
    if (countryType == NYCountryTypeMY) {
        return YES;
    } else {
        return NO;
    }
}

/// 如果為驗證碼頁才進行倒數
- (void)countDownNotRecevingSMSIfNeededWithLoginType:(NYLoginProcessType)loginType {
    if (loginType == NYLoginProcessTypeVerifyCodeFacebookRegister ||
        loginType == NYLoginProcessTypeVerifyCodeLineLoginRegister ||
        loginType == NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish ||
        loginType == NYLoginProcessTypeLineLoginExceedSMSLimit ||
        loginType == NYLoginProcessTypeVerifyCodeNineYiForgetPassword ||
        loginType == NYLoginProcessTypeVerifyCodeNineYiRegister ||
        loginType == NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber ||
        loginType == NYLoginProcessTypeVerifyCodeThirdpartyRegister ||
        loginType == NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone ||
        loginType == NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone ||
        loginType == NYLoginProcessTypeVerifyCodeExpressRegister ||
        loginType == NYLoginProcessTypeVerifyCodeExpressResetPassword ||
        loginType == NYLoginProcessTypeVerifyCodeMemberDirectSetPassword) {

        //倒數15秒後才可以按"沒收到簡訊"
        [self countDownNotRecevingSMS:15];
    }
}

// OTP 登入
- (void)nineyiActionButtonAtLoginProcessTypeVerifyCodeLogin {
    [self textFormateCheck:[NYLoginUserDataModel sharedModel].verifyCode checkType:NYLoginTextFieldFormatCheckTypeVerifyCode WithWarningMessage:NYLocalizedString(@"login_warning_invalid_verify_code", nil) AndSuccessCompletion:^{
        [self confirmNineYiMemberVerifyCodeWithVerifyType:@"Login"];
    }];
}

//九易會員註冊 / OTP 註冊
- (void)nineyiActionButtonAtLoginProcessTypeVerifyCodeRegister {
    [self textFormateCheck:[NYLoginUserDataModel sharedModel].verifyCode checkType:NYLoginTextFieldFormatCheckTypeVerifyCode WithWarningMessage:NYLocalizedString(@"login_warning_invalid_verify_code", nil) AndSuccessCompletion:^{
        [self confirmNineYiMemberVerifyCodeWithVerifyType:@"Register"];
    }];
}

//會員忘記密碼 / 驗證碼登入設定密碼
- (void)nineyiActionButtonAtLoginProcessTypeVerifyCodeNineYiForgetPassword {
    [self textFormateCheck:[NYLoginUserDataModel sharedModel].verifyCode checkType:NYLoginTextFieldFormatCheckTypeVerifyCode WithWarningMessage:NYLocalizedString(@"login_warning_invalid_verify_code", nil) AndSuccessCompletion:^{
        [self confirmNineYiMemberVerifyCodeWithVerifyType:@"ResetPassword"];
    }];
}

- (void)confirmNineYiMemberVerifyCodeWithVerifyType:(NSString *)verifyType {
    __weak typeof(self) weakSelf = self;
    
    //BTS 14006 Crash防呆, 照理說根本不該跑進此邏輯
    if (![NYLoginUserDataModel sharedModel].cellPhone) {
        [weakSelf displayAlertTitle:NYLocalizedString(@"login_alert_login_system_error", nil) messageAndBackToRoot:nil];
        return;
    }
    
    [NYProgressHUD showHUDAddedToView:self.view];
    
    void(^confirmVerifyCodeVia91)(NSString *) = ^(NSString *reCaptchaToken) {
        [weakSelf confirmVerifyCodeBy:self.loginType
                               shopID:[NYGlobalData shopId]
                            cellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                          countryCode:self.countryPhoneCode
                            countryID:self.countryID
                           verifyCode:[NYLoginUserDataModel sharedModel].verifyCode
                           verifyType:verifyType
                       reCaptchaToken:reCaptchaToken
                    completionHandler:^(NYLoginOTPOperation * _Nonnull otpOperation) {
            
            [NYProgressHUD hideAllHUDsForView:weakSelf.view];
            
            if (otpOperation.verifyResult == CellPhoneOTPVerifyResultApiError) {
                [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                    [weakSelf confirmNineYiMemberVerifyCodeWithVerifyType:verifyType];
                }];
            } else {
                
                if (otpOperation.verifyResult == CellPhoneOTPVerifyResultSuccess) {
                    // verify phone number only
                    if (weakSelf.loginType == NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber) {
                        if ([NYLoginVCInfo sharedInfo].dismissCompletion) {
                            [weakSelf dismissSelfFromPresentingByUser];
                            
                            return;
                        }
                        
                    } else if (weakSelf.loginType == NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone) {
                        [self updateCellPhone:^{
                            [NYProgressHUD showSuccessMessage:NYLocalizedString(@"member_cell_phone_verification_success", nil) toView:weakSelf.view duration:2.0];
                            
                            [weakSelf dismissSelfFromPresentingByUser];
                        }];
                        
                        return;
                        
                    } else if (weakSelf.loginType == NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone) {
                        [self updateCellPhone:^{
                            // 從帳號綁定頁來的設定密碼要打新的 API
                            NYLoginViewController *setPasswordVC = [[NYLoginViewController alloc]
                                                                    initWithNYLoginProcessType:NYLoginProcessTypeSocialAccountBindingCellPhonSetPassword
                                                                    userCountryCode:weakSelf.countryPhoneCode
                                                                    userCountryID:weakSelf.countryID];
                            
                            [weakSelf.navigationController pushViewController:setPasswordVC animated:YES];
                        }];
                        
                        return;
                        
                    } else if (weakSelf.loginType == NYLoginProcessTypeVerifyCodeExpressRegister ||
                               weakSelf.loginType == NYLoginProcessTypeVerifyCodeExpressResetPassword) {
                        [NYProgressHUD showHUDAddedToView:self.view];
                        // 驗證碼檢核通過
                        [weakSelf handleOTPVerified];
                        return;
                    }
                    
                    NYLoginProcessType type = NYLoginProcessTypeNineYiSetPassword;
                    
                    if (weakSelf.loginType == NYLoginProcessTypeVerifyCodeNineYiForgetPassword) {
                        type = NYLoginProcessTypeNineYiResetPassword;
                        
                    } else if (weakSelf.loginType == NYLoginProcessTypeVerifyCodeMemberDirectSetPassword) {
                        // 設定密碼 (從會員專區來的)
                        type = NYLoginProcessTypeMemberDirectSetPassword;
                    }
                    
                    NYLoginViewController *setPasswordVC = [[NYLoginViewController alloc] initWithNYLoginProcessType:type
                                                                                                     userCountryCode:weakSelf.countryPhoneCode
                                                                                                       userCountryID:weakSelf.countryID];
                    
                    [weakSelf.navigationController pushViewController:setPasswordVC animated:YES];
                } else if (otpOperation.verifyResult == CellPhoneOTPVerifyResultWrongCode) {
                    NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[[weakSelf indexPathForTextField] firstObject]];
                    [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeVerifyCode];
                    [weakSelf insertWaringCellAfterIndexPath:[[self indexPathForTextField] firstObject] withWariningMessage:otpOperation.message];
                } else if (otpOperation.verifyResult == CellPhoneOTPVerifyResultCodeExpired ||
                           otpOperation.verifyResult == CellPhoneOTPVerifyResultAlreadyRegistered) {
                    [weakSelf displayAlertTitle:nil messageAndBackToRoot:otpOperation.message];
                } else if (otpOperation.verifyResult == CellPhoneOTPVerifyResultReCaptchaVerifyFailed) {
                    //reCaptcha 驗證失敗
                    [weakSelf displayAlertMessage:otpOperation.message];
                } else if (otpOperation.verifyResult == CellPhoneOTPVerifyResultSystemError) {
                    [weakSelf displayAlertMessage:otpOperation.message];
                }
            }
        }];
    };
    
    if (self.canUseReCaptcha) {
        [NYLoginViewController reCaptchaGetTokenBlock](^(NSString *reCaptchaToken) {
            if (reCaptchaToken && ![reCaptchaToken isEqualToString:@""]) {
                confirmVerifyCodeVia91(reCaptchaToken);
            } else {
                // 拿不到 token 就用原 API error 處理方式
                [NYProgressHUD hideAllHUDsForView:weakSelf.view];
                [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                    [weakSelf confirmNineYiMemberVerifyCodeWithVerifyType:verifyType];
                }];
            }
        });
    } else {
        confirmVerifyCodeVia91(@"");
    }
}

- (void)resendVerifyCodeWithMemberType:(NSString *)memberType andVerifyType:(NSString *)verifyType smsType:(NSString *)smsType {
    __weak typeof(self) weakSelf = self;
    
    //BTS 14006 Crash防呆, 照理說根本不該跑進此邏輯
    if (![NYLoginUserDataModel sharedModel].cellPhone) {
        [weakSelf displayAlertTitle:NYLocalizedString(@"login_alert_login_system_error", nil) messageAndBackToRoot:nil];
        return;
    }
    
    [NYProgressHUD showHUDAddedToView:self.view];
    [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit = NO;
    
    //重送驗證碼
    void(^resendVerifyCode)(NSString *) = ^(NSString *reCaptchaToken) {
        [self resendVerifyCodeBy:self.loginType
                          shopID:[NYGlobalData shopId]
                       cellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                     countryCode:self.countryPhoneCode
                       countryID:self.countryID
                      memberType:memberType
                      verifyType:verifyType
                         smsType:smsType
                  reCaptchaToken:reCaptchaToken
               completionHandler:^(NYLoginOTPOperation * _Nonnull otpOperation) {
            [NYProgressHUD hideAllHUDsForView:weakSelf.view];

            if (otpOperation.sendResult == CellPhoneSendOTPResultApiError) {
                [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                    [weakSelf resendVerifyCodeWithMemberType:memberType andVerifyType:verifyType smsType:smsType];
                }];
            } else {
                if (otpOperation.sendResult == CellPhoneSendOTPResultSuccess) {
                    NSNumber *countdownTime = ([NYBaseURLConfig isTestEnvironment]) ? @(5) : @(30);
                    [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(resendVerifyCodeAndVoiceServiceCountDownWithCountDownTimer:) userInfo:countdownTime repeats:NO];
                } else if (otpOperation.sendResult == CellPhoneSendOTPResultReachSMSLimit) {
                    [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit = YES;
                    [weakSelf setupResendVerifyCodeButtonEnable:NO withTitle:NYLocalizedString(@"login_btn_resend_verify_code", nil)];
                    [weakSelf showResendVerifyCodeOverLimitAlert];
                    
                    if ([NYLoginVCInfo sharedInfo].isViaVoiceServiceReachLimit == YES) {
                        [weakSelf setupVerifyViaVoiceServiceButtonEnable:NO];
                    }

                    if ([self isResendActionNotAvailable]) {
                        [weakSelf dialVerifyViaVoiceServiceDescription].text = NYLocalizedString(@"login_verify_limit_description", nil);
                        [weakSelf dialVerifyViaVoiceServiceDescription].textColor = [UIColor colorWithHexString:@"0xFF5353"];
                    }

                } else if (otpOperation.sendResult == CellPhoneSendOTPResultIsRegistered) {
                    [weakSelf displayAlertTitle:nil messageAndBackToRoot:otpOperation.message];
                } else if (otpOperation.sendResult == CellPhoneSendOTPResultReCaptchaVerifyFailed) {
                    //reCaptcha 驗證失敗
                    [weakSelf displayAlertMessage:otpOperation.message];
                } else if (otpOperation.sendResult == CellPhoneSendOTPResultSystemError) {
                    [weakSelf displayAlertMessage:otpOperation.message];
                }
            }
        }];
    };
    
    if (self.canUseReCaptcha) {
        [NYLoginViewController reCaptchaGetTokenBlock](^(NSString *reCaptchaToken) {
            if (reCaptchaToken && ![reCaptchaToken isEqualToString:@""]) {
                resendVerifyCode(reCaptchaToken);
            } else {
                // 拿不到 token 就用原 API error 處理方式
                [NYProgressHUD hideAllHUDsForView:weakSelf.view];
                [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                    [weakSelf resendVerifyCodeWithMemberType:memberType andVerifyType:verifyType smsType:smsType];
                }];
            }
        });
    } else {
        resendVerifyCode(@"");
    }
}

/// 語音驗證（Nexmo）
- (void)resendVerifyCodeUseVoiceWithMemberType:(NSString *)memberType andVerifyType:(NSString *)verifyType {
    [NYProgressHUD showHUDAddedToView:self.view];
    [NYLoginVCInfo sharedInfo].isViaVoiceServiceReachLimit = NO;
    // 重送語音驗證 API
    __weak typeof(self) weakSelf = self;
    
    [weakSelf resendVerifyCodeUseVoiceBy:weakSelf.loginType
                                  shopID:[NYGlobalData shopId]
                               cellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                             countryCode:weakSelf.countryPhoneCode
                               countryID:weakSelf.countryID
                              memberType:memberType
                              verifyType:verifyType
                       completionHandler:^(NYLoginOTPOperation * _Nonnull otpOperation) {
        //API 結果回來 根據結果再來開關

        [NYProgressHUD hideAllHUDsForView:weakSelf.view];
        [weakSelf setupResendVerifyCodeButtonEnable:NO withTitle:NYLocalizedString(@"login_btn_resend_verify_code", nil)];

        if (otpOperation.sendResult == CellPhoneSendOTPResultApiError) {
            [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                [weakSelf resendVerifyCodeUseVoiceWithMemberType:memberType andVerifyType:verifyType];
            }];
        } else {
            if (otpOperation.sendResult == CellPhoneSendOTPResultSuccess) {
                NSNumber *countdownTime = @(30);
                [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(resendVerifyCodeAndVoiceServiceCountDownWithCountDownTimer:) userInfo:countdownTime repeats:NO];
                
                // 25.12 操作效率優化：先撥號再 alert 告知五秒內會收到
                [weakSelf resendVerifyCodeUseVoiceSuccess];
                
            } else if (otpOperation.sendResult == CellPhoneSendOTPResultReachSMSLimit) {

                [NYLoginVCInfo sharedInfo].isViaVoiceServiceReachLimit = YES;
                [weakSelf setupVerifyViaVoiceServiceButtonEnable:NO];
                [weakSelf showResendVerifyCodeUseVoiceOverLimitAlert];
                
                if (![NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit) {
                    [weakSelf setupResendVerifyCodeButtonEnable:YES withTitle:NYLocalizedString(@"login_btn_resend_verify_code", nil)];
                }

                if ([self isResendActionNotAvailable]) {
                    [weakSelf dialVerifyViaVoiceServiceDescription].text = NYLocalizedString(@"login_verify_limit_description", nil);
                    [weakSelf dialVerifyViaVoiceServiceDescription].textColor = [UIColor colorWithHexString:@"0xFF5353"];
                    [weakSelf setupResendVerifyCodeButtonEnable:NO withTitle:NYLocalizedString(@"login_btn_resend_verify_code", nil)];
                }

            } else if (otpOperation.sendResult == CellPhoneSendOTPResultIsRegistered) {
                [weakSelf displayAlertTitle:nil messageAndBackToRoot:otpOperation.message];
            } else if (otpOperation.sendResult == CellPhoneSendOTPResultSystemError) {
                if (![NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit) {
                    [weakSelf setupResendVerifyCodeButtonEnable:YES withTitle:NYLocalizedString(@"login_btn_resend_verify_code", nil)];
                }
                [weakSelf displayAlertMessage:otpOperation.message];
            }
        }
    }];
}

- (void)resendVerifyCodeUseVoiceSuccess {
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:NYLocalizedString(@"login_alert_voice_service_login_confirm", nil)
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NYLocalizedString(@"login_alert_voice_service_login_missed", nil)
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * _Nonnull action) {
        [self ny_displayAlertWithTitle:[NSString stringWithFormat:@"%@？", NYLocalizedString(@"login_alert_voice_service_login_missed", nil)]
                               message:NYLocalizedString(@"member_card_check_reception", nil)];
    }];
    
    NSString *displayPhone = [NSString stringWithFormat:@"+%@ %@", self.countryPhoneCode, [NYLoginUserDataModel sharedModel].cellPhone];
    NSString *title = [NSString stringWithFormat:NYLocalizedString(@"login_alert_voice_service_login_title", nil), displayPhone];
    NSString *message = NYLocalizedString(@"login_alert_voice_service_login_msg", nil);
    
    [self ny_displayAlertWithTitle:title
                           message:message
                     confirmAction:confirm
                      cancelAction:cancel];
}

/// 簡訊是否已達到上限，若達到上限則重新發送動作不可使用
- (BOOL)isResendActionNotAvailable {
    if ([self isSMSServiceOnly]) {
        return [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit;
    } else {
        return [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit && [NYLoginVCInfo sharedInfo].isViaVoiceServiceReachLimit;
    }
}

- (IBAction)resendVerifyCode:(UIButton *)sender {
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:NYLocalizedString(@"login_alert_confirm_resend", nil)
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
        [self confirmResendVerifyCode];
    }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NYLocalizedString(@"common_cancel", nil)
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
    
    NSString *displayPhone = [NSString stringWithFormat:@"+%@ %@", self.countryPhoneCode, [NYLoginUserDataModel sharedModel].cellPhone];
    NSString *title = [NSString stringWithFormat:NYLocalizedString(@"login_alert_resend_verify_code_title", nil), displayPhone];
    NSString *message = NYLocalizedString(@"login_alert_resend_verify_code_msg", nil);
    
    [self ny_displayAlertWithTitle:title
                           message:message
                     confirmAction:confirm
                      cancelAction:cancel];
}

- (void)confirmResendVerifyCode {
    if ([self.resendVerifyCodeServiceButtonLabel.text isEqualToString:NYLocalizedString(@"login_btn_resend_verify_code", nil)]) {
        switch (self.loginType) {
            case NYLoginProcessTypeVerifyCodeNineYiRegister:
                [self resendVerifyCodeWithMemberType:kMemberType_NineYi andVerifyType:kVerifyType_Register smsType:kSMSType_RegisterMember];
                break;
            case NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber:
            case NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone:
            case NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone:
                [self resendVerifyCodeWithMemberType:kMemberType_NineYi andVerifyType:kVerifyType_Register smsType:kSMSType_MemberPassword];
                break;
            case NYLoginProcessTypeVerifyCodeFacebookRegister:
                [self resendVerifyCodeWithMemberType:kMemberType_Facebook andVerifyType:kVerifyType_Register smsType:kSMSType_RegisterMember];
                break;
            case NYLoginProcessTypeVerifyCodeLineLoginRegister:
            case NYLoginProcessTypeLineLoginExceedSMSLimit:
                [self resendVerifyCodeWithMemberType:kMemberType_Line andVerifyType:kVerifyType_Register smsType:kSMSType_RegisterMember];
                break;
            case NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish:
                [self resendVerifyCodeWithMemberType:kMemberType_Facebook andVerifyType:kVerifyType_CellPhoneVerify smsType:kSMSType_RegisterMember];
                break;
            case NYLoginProcessTypeVerifyCodeNineYiForgetPassword:
                [self resendVerifyCodeWithMemberType:kMemberType_NineYi andVerifyType:kVerifyType_ResetPassword smsType:kSMSType_MemberPassword];
                break;
            case NYLoginProcessTypeVerifyCodeThirdpartyRegister:
                [self resendVerifyCodeWithMemberType:kMemberType_ThirdpartyAuth andVerifyType:kVerifyType_Register smsType:kSMSType_RegisterMember];
                break;
            case NYLoginProcessTypeVerifyCodeExpressRegister: {
                if (self.flowViewModel.isLoginFlow) {
                    [self resendVerifyCodeWithMemberType:kMemberType_Express andVerifyType:kVerifyType_Login smsType:kSMSType_LoginMember];
                } else {
                    [self resendVerifyCodeWithMemberType:kMemberType_Express andVerifyType:kVerifyType_Register smsType:kSMSType_RegisterMember];
                }
                
                break;
            }
            case NYLoginProcessTypeVerifyCodeExpressResetPassword:
            case NYLoginProcessTypeVerifyCodeMemberDirectSetPassword:
                [self resendVerifyCodeWithMemberType:kMemberType_Express andVerifyType:kVerifyType_ResetPassword smsType:kSMSType_MemberPassword];
                break;
            default:
                break;
        }
    }
}

- (IBAction)resendVerifyCodeUseVoice:(UIButton *)sender {
    switch (self.loginType) {
        case NYLoginProcessTypeVerifyCodeNineYiRegister:
        case NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber:
        case NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone:
            [self resendVerifyCodeUseVoiceWithMemberType:kMemberType_NineYi andVerifyType:kVerifyType_Register];
            break;
        case NYLoginProcessTypeVerifyCodeNineYiForgetPassword:
            [self resendVerifyCodeUseVoiceWithMemberType:kMemberType_NineYi andVerifyType:kVerifyType_ResetPassword];
            break;
        case NYLoginProcessTypeVerifyCodeFacebookRegister:
            [self resendVerifyCodeUseVoiceWithMemberType:kMemberType_Facebook andVerifyType:kVerifyType_Register];
            break;
        case NYLoginProcessTypeVerifyCodeLineLoginRegister:
        case NYLoginProcessTypeLineLoginExceedSMSLimit:
            [self resendVerifyCodeUseVoiceWithMemberType:kMemberType_Line andVerifyType:kVerifyType_Register];
            break;
        case NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish:
            [self resendVerifyCodeUseVoiceWithMemberType:kMemberType_Facebook andVerifyType:kVerifyType_CellPhoneVerify];
            break;
        case NYLoginProcessTypeVerifyCodeThirdpartyRegister:
            [self resendVerifyCodeUseVoiceWithMemberType:kMemberType_ThirdpartyAuth andVerifyType:kVerifyType_Register];
            break;
        case NYLoginProcessTypeVerifyCodeExpressRegister: {
            NSString *verifyType = self.flowViewModel.isLoginFlow ? kVerifyType_Login : kVerifyType_Register;
            [self resendVerifyCodeUseVoiceWithMemberType:kMemberType_Express andVerifyType:verifyType];
            break;
        }
        case NYLoginProcessTypeVerifyCodeExpressResetPassword:
        case NYLoginProcessTypeVerifyCodeMemberDirectSetPassword:
            [self resendVerifyCodeUseVoiceWithMemberType:kMemberType_Express andVerifyType:kVerifyType_ResetPassword];
            break;
        default:
            break;
    }
}

- (void)showResendVerifyCodeOverLimitAlert {
    if ([self isSMSServiceOnly]) {
        // 只有簡訊驗證的 market，需聯絡客服
        UIAlertAction *confirm = [UIAlertAction actionWithTitle:NYLocalizedString(@"common_confirm", nil)
                                                          style:UIAlertActionStyleDefault
                                                        handler:nil];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:NYLocalizedString(@"login_alert_go_to_customer_service", nil)
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
            
            [self dismissSelfWithCustomExtraCompletionBlock:^{
                // 轉商店客服頁 webView（native 會針對設定隱藏/顯示商店客服 tab，不處理這個情境，用 webView 方式呈現)
                RoutingObject *routingObj = [[RoutingObject alloc] initWithTargetType:RoutingTargetTypeCustomerServiceEntry];
                [[NYNotificationHelper sharedInstance] navigateToTargetPageWith:routingObj];
            }];
        }];
        
        [self ny_displayAlertWithTitle:NYLocalizedString(@"login_btn_contact_customer_service_instead", nil)
                               message:NYLocalizedString(@"login_contact_customer_service_message", nil)
                         confirmAction:confirm
                          cancelAction:cancel];
    } else {
        // 詢問是否要改用語音驗證
        UIAlertAction *confirm = [UIAlertAction actionWithTitle:NYLocalizedString(@"login_alert_change_to_voice", nil)
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
            [self resendVerifyCodeUseVoice:nil];
        }];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:NYLocalizedString(@"common_cancel", nil)
                                                         style:UIAlertActionStyleDefault
                                                       handler:nil];
        
        [self ny_displayAlertWithTitle:NYLocalizedString(@"login_alert_sms_reach_limit_title", nil)
                               message:NYLocalizedString(@"login_alert_sms_reach_limit_msg", nil)
                         confirmAction:confirm
                          cancelAction:cancel];
    }
}

- (void)showResendVerifyCodeUseVoiceOverLimitAlert {
    [self ny_displayAlertWithTitle:NYLocalizedString(@"login_alert_voice_reach_limit_title", nil) message:NYLocalizedString(@"login_alert_voice_reach_limit_msg", nil)];
}

- (void)resendVerifyCodeStopCountDown {
    [self setupResendVerifyCodeButtonEnable:YES withTitle:NYLocalizedString(@"login_btn_resend_verify_code", nil)];
}

- (void)resendVerifyCodeAndVoiceServiceCountDownWithCountDownTimer:(NSTimer *)countDownTimer {
    NSNumber *countDownTime = countDownTimer.userInfo;
    if (countDownTime.integerValue >= 1) {
        [self setupVerifyViaVoiceServiceButtonEnable:NO];
        [self setupResendVerifyCodeButtonEnable:NO withTitle:[NSString stringWithFormat:@"%@", NYLocalizedString(@"login_btn_resend_verify_code", nil)]];

        [self setViaVoiceCountDownString:[NSString stringWithFormat:NYLocalizedString(@"login_voice_count_down_description", nil), (long)countDownTime.integerValue]];
        [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(resendVerifyCodeAndVoiceServiceCountDownWithCountDownTimer:) userInfo:@(countDownTime.integerValue - 1) repeats:NO];
    } else {

        if (![NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit) {
            [self resendVerifyCodeStopCountDown];
        }
        
        if (![NYLoginVCInfo sharedInfo].isViaVoiceServiceReachLimit) {
            [self setupVerifyViaVoiceServiceButtonEnable:YES];
        }

        [self setViaVoiceCountDownString:@""];
    }
}

/// 語音驗證倒數字串
- (void)setViaVoiceCountDownString:(NSString *)message {
    [self.dialVerifyViaVoiceServiceDescription setText:message];
}

- (void)setupResendVerifyCodeButtonEnable:(BOOL)enable withTitle:(NSString *)title {
    self.resendVerifyCodeServiceButton.userInteractionEnabled = enable;
    self.resendVerifyCodeServiceButtonLabel.text = title;
    
    if (enable) {
        self.resendVerifyCodeServiceButtonIcon.tintColor = [UIColor colorWithHexString:@"0xFF9933"];
        self.resendVerifyCodeServiceButtonLabel.textColor = [UIColor blackColor];
        self.resendVerifyCodeServiceButtonLabel.backgroundColor = [UIColor whiteColor];
    } else {
        self.resendVerifyCodeServiceButtonIcon.tintColor = [UIColor whiteColor];
        self.resendVerifyCodeServiceButtonLabel.textColor = [UIColor whiteColor];
        self.resendVerifyCodeServiceButtonLabel.backgroundColor = [UIColor colorWithHexString:@"0xCCCCCC"];
    }
}

- (void)setupVerifyViaVoiceServiceButtonEnable:(BOOL)enable {
    __weak typeof(self) weakSelf = self;
    weakSelf.verifyViaVoiceServiceButton.enabled = enable;
    if (enable) {
        weakSelf.verifyViaVoiceServiceButtonIcon.tintColor = [UIColor colorWithHexString:@"0x2DC55B"];
        weakSelf.verifyViaVoiceServiceButton.backgroundColor = [UIColor whiteColor];
        [weakSelf.verifyViaVoiceServiceButton setTitleColor:[UIColor colorWithHexString:@""] forState:UIControlStateNormal];
        weakSelf.verifyViaVoiceServiceButton.userInteractionEnabled = YES;
    }
    else {
        weakSelf.verifyViaVoiceServiceButtonIcon.tintColor = [UIColor whiteColor];
        weakSelf.verifyViaVoiceServiceButton.backgroundColor = [UIColor colorWithHexString:@"0xCCCCCC"];
        [weakSelf.verifyViaVoiceServiceButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        weakSelf.verifyViaVoiceServiceButton.userInteractionEnabled = NO;
    }
}

#pragma mark - 設定密碼頁
- (void)nineyiActionButtonAtLoginProcessTypeNineYiSetPassword {
    [self textFormateCheck:[NYLoginUserDataModel sharedModel].password checkType:NYLoginTextFieldFormatCheckTypePassword WithWarningMessage:NYLocalizedString(@"login_password_regex_warning_invalid_password_length", nil) AndSuccessCompletion:^{
        __weak typeof(self) weakSelf = self;
        
        //BTS 14006 Crash防呆, 照理說根本不該跑進此邏輯
        if (![NYLoginUserDataModel sharedModel].cellPhone) {
            [weakSelf displayAlertTitle:NYLocalizedString(@"login_alert_login_system_error", nil) messageAndBackToRoot:nil];
            return;
        }
        
        //Before Login time
        NSDate *timeBeforeLogin = [[NYLoginVCInfo sharedInfo] loginProcessStartTime];
        
        [NYProgressHUD showHUDAddedToView:self.view];
        NYLoginUserDataModel *userModel = [NYLoginUserDataModel sharedModel];
        
        //device參數只有門市小幫手是帶Pad、其餘iOS跟Android都是帶Mobile
        [[NYLoginHelper sharedInstance] finishRegisterVia91maiWithShopID:[NYGlobalData shopId]
                                                               cellPhone:userModel.cellPhone
                                                                password:userModel.password
                                                                  source:@"iOSApp"
                                                                  device:@"Mobile"
                                                              appVersion:[NYGlobalData appVersionString]
                                                             countryCode:self.countryPhoneCode
                                                               countryID:self.countryID
                                                        enableOptInSplit:[NYLoginUserDataModel sharedModel].enableOptInSplit
                                                                 isOptIn:[NYLoginUserDataModel sharedModel].optinValue
                                                             isEnableEDM:@([NYLoginUserDataModel sharedModel].isEnableEDM)
                                                          isEnableEdmSMS:@([NYLoginUserDataModel sharedModel].isEnableEdmSMS)
                                                        isAppPushProfile:@([NYLoginUserDataModel sharedModel].isAppPushProfile)
                                                       completionHandler:^(NSDictionary *data, NSError *error) {
        
            [NYProgressHUD hideAllHUDsForView:weakSelf.view];
            if (error) {
                [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                    [weakSelf nineyiActionButtonAtLoginProcessTypeNineYiSetPassword];
                }];
            } else {
                NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
                NSString *message = [weakSelf apiReturnMessageForReturnData:data];
                
                if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeSuccess]) {
                    [weakSelf dismissSelfFromPresentingAfterLoginSuccessWithIsRegister:YES];
                    [[NYReferrerBindingLinkInjectionHelper shared] cleanStoredReferrerInfo];
                    // FA
                    [self setEventUserInfoWithPhone:userModel.cellPhone];
                    NSTimeInterval loginDuration = [timeBeforeLogin timeIntervalSinceNow];
                    [[NYStatisticHelper sharedHelper] sendEventSignUpWithMethod:kFAParamSignupLoginMethodPhone
                                                                         status:kFAParamSignupLoginStatusFinish
                                                                       duration:@(-loginDuration)];
                } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeInvalidFormat]) {
                    NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[[weakSelf indexPathForTextField] firstObject]];
                    [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeCellPhone];
                    [weakSelf displayAlertMessage:message];
                } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeExpired] ||
                         [returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeAlreadyRegistered]) {
                    [weakSelf displayAlertTitle:nil messageAndBackToRoot:message];
                } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeSystemError]) {
                    [weakSelf displayAlertMessage:message];
                }
            }
        }];
    }];
}

- (void)nineyiActionButtonAtLoginProcessTypeNineYiResetPassword {
    [self textFormateCheck:[NYLoginUserDataModel sharedModel].password checkType:NYLoginTextFieldFormatCheckTypePassword WithWarningMessage:NYLocalizedString(@"login_password_regex_warning_invalid_password_length", nil) AndSuccessCompletion:^{
        __weak typeof(self) weakSelf = self;
        
        //BTS 14006 Crash防呆, 照理說根本不該跑進此邏輯
        if (![NYLoginUserDataModel sharedModel].cellPhone) {
            [weakSelf displayAlertTitle:NYLocalizedString(@"login_alert_login_system_error", nil) messageAndBackToRoot:nil];
            return;
        }
        
        //Before Login time
        NSDate *timeBeforeLogin = [[NYLoginVCInfo sharedInfo] loginProcessStartTime];
        
        [NYProgressHUD showHUDAddedToView:self.view];
        
        //device參數只有門市小幫手是帶Pad、其餘iOS跟Android都是帶Mobile
        
        [weakSelf resetPasswordBy:self.loginType
                           shopID:[NYGlobalData shopId]
                        cellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                      countryCode:self.countryPhoneCode
                        countryID:self.countryID
                         password:[NYLoginUserDataModel sharedModel].password
                completionHandler:^(NYLoginPasswordOperation * _Nonnull passwordOperation) {
            
            [NYProgressHUD hideAllHUDsForView:weakSelf.view];
            
            if (passwordOperation.resetResult == CellPhonePasswordResetResultApiError) {
                [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                    [weakSelf nineyiActionButtonAtLoginProcessTypeNineYiResetPassword];
                }];
            } else {
                if (passwordOperation.resetResult == CellPhonePasswordResetResultSuccess) {
                    if (self.loginType == NYLoginProcessTypeExpressResetPassword) {
                        // 驗證碼註冊 → (關閉驗證碼登入功能) → 登入：屬於已註冊會員
                        
                        // send login event
                        NSDate *timeBeforeLogin = [[NYLoginVCInfo sharedInfo] loginProcessStartTime];
                        NSTimeInterval loginDuration = [[NSDate date] timeIntervalSinceDate:timeBeforeLogin];
                        [[NYStatisticHelper sharedHelper] sendEventLoginWithMethod:kFAParamSignupLoginMethodPhone
                                                                             status:kFAParamSignupLoginStatusFinish
                                                                           duration:@(loginDuration)];
                        
                        [weakSelf dismissSelfFromPresentingAfterLoginSuccessWithIsRegister:NO];
                    } else if ([NYLoginUserDataModel sharedModel].shouldActivate) {
                        // 線下會員註冊未開通情況下，會走忘記密碼 -> 重新設定密碼
                        // 屬於 未開通 情況 因此 IsResgister 要設為 YES
                        // 因爲後續在 「dismissSelfFromPresentingAfterLoginSuccessWithIsResgister」
                        // 需要多打 Validation 這隻 API
                        [weakSelf dismissSelfFromPresentingAfterLoginSuccessWithIsRegister:YES];
                    } else {
                        [weakSelf dismissSelfFromPresentingAfterLoginSuccessWithIsRegister:NO];
                    }

                    [[NYReferrerBindingLinkInjectionHelper shared] cleanStoredReferrerInfo];
                } else if (passwordOperation.resetResult == CellPhonePasswordResetResultInvalidFormat) {
                    NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[[weakSelf indexPathForTextField] firstObject]];
                    [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypePassword];
                    [weakSelf displayAlertMessage:passwordOperation.message];
                } else if (passwordOperation.resetResult == CellPhonePasswordResetResultCodeExpired) {
                    [weakSelf displayAlertTitle:nil messageAndBackToRoot:passwordOperation.message];
                } else if (passwordOperation.resetResult == CellPhonePasswordResetResultSystemError) {
                    [weakSelf displayAlertMessage:passwordOperation.message];
                }
            }
        }];
    }];
}

- (void)readyForSetPasswordWithVerifyType:(NSString *)verifyType {
    NYLoginUserDataModel *userModel = [NYLoginUserDataModel sharedModel];
    
    [self textFormateCheck:userModel.password checkType:NYLoginTextFieldFormatCheckTypePassword WithWarningMessage:NYLocalizedString(@"login_password_regex_warning_invalid_password_length", nil) AndSuccessCompletion:^{
        __weak typeof(self) weakSelf = self;
        
        if (!userModel.cellPhone) {
            [weakSelf displayAlertTitle:NYLocalizedString(@"login_alert_login_system_error", nil) messageAndBackToRoot:nil];
            return;
        }
        
        [NYProgressHUD showHUDAddedToView:self.view];
        
        [[NYLoginHelper sharedInstance] bindingCellPhoneSetPasswordWithShopID:[NYGlobalData shopId]
                                                                    cellPhone:userModel.cellPhone
                                                                     password:userModel.password
                                                                       source:@"iOSApp"
                                                                       device:@"Mobile"
                                                                   appVersion:[NYGlobalData appVersionString]
                                                                  countryCode:weakSelf.countryPhoneCode
                                                                    countryID:weakSelf.countryID
                                                                   verifyType:verifyType
                                                            completionHandler:^(NSDictionary *data, NSError *error) {
            
            [NYProgressHUD hideAllHUDsForView:weakSelf.view];
            if (error) {
                [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                    [weakSelf readyForSetPasswordWithVerifyType:verifyType];
                }];
            } else {
                NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
                NSString *message = [weakSelf apiReturnMessageForReturnData:data];
                
                if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeSuccess]) {
                    [NYProgressHUD showSuccess:NYLocalizedString(@"member_account_binding_set_password_completed", nil) toView:weakSelf.view];
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [weakSelf dismissSelfFromPresentingByUser];
                    });
                    
                    // FA
                    [self setEventUserInfoWithPhone:userModel.cellPhone];
                    
                } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeInvalidFormat]) {
                    NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[[weakSelf indexPathForTextField] firstObject]];
                    [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeCellPhone];
                    [weakSelf displayAlertMessage:message];
                    
                } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeExpired] ||
                           [returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeAlreadyRegistered]) {
                    [weakSelf displayAlertTitle:nil messageAndBackToRoot:message];
                    
                } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeSystemError]) {
                    [weakSelf displayAlertMessage:message];
                    
                } else {
                    // 其它錯誤
                    [weakSelf displayAlertTitle:[NSString stringWithFormat:NYLocalizedString(@"common_alert_error_code", nil), returnCode]
                           messageAndBackToRoot:nil];
                }
            }
        }];
    }];
}

- (void)nineyiActionButtonAtSetPassword {
    if (self.loginType == NYLoginProcessTypeMemberDirectSetPassword) {
        [self readyForSetPasswordWithVerifyType:@"ResetPassword"];
    } else {
        [self readyForSetPasswordWithVerifyType:@""];
    }
}

#pragma mark - fb / line / 第三方 登入 輸入電話號碼綁定頁
- (void)fbAndLineActionButtonAtLoginProcessTypeBindgingPhoneWithCountryCode:(NSString *)countryCode countryID:(NSNumber *)countryID {
    [self checkIsValidWithCellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                       countryAliasCode:self.countryAliasCode
                      successCompletion:^{
        __weak typeof(self) weakSelf = self;
        [weakSelf ny_displayAlertWithTitle:NYLocalizedString(@"login_alert_will_send_verify_code_title", nil) message:nil confirmBlock:^{
            [NYProgressHUD showHUDAddedToView:weakSelf.view];
            // create member
            if (weakSelf.loginType == NYLoginProcessTypeLineLoginBingingCellPhone) {
                
                [[NYLoginHelper sharedInstance] createLineMemberRegisterRequestWithShopId:[NYGlobalData shopId]
                                                                                cellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                                                                              accessToken:[[LineLoginInjectionHelper shared] getCurrentToken]
                                                                              countryCode:countryCode
                                                                                countryId:countryID
                                                                        completionHandler:^(NSDictionary *data, NSError *error) {
                    [NYProgressHUD hideAllHUDsForView:weakSelf.view];
                    if (error) {
                        [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                            [weakSelf fbAndLineActionButtonAtLoginProcessTypeBindgingPhoneWithCountryCode:countryCode countryID:countryID];
                        }];
                    } else {
                        NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
                        NSString *message = [weakSelf apiReturnMessageForReturnData:data];
                        [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit = NO;
       
                        // 成功 or 綁定的手機待開通
                        if (([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateLineMemberRegisterRequestSuccessed]) ||
                            ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateLineMemberRegisterRequestNeedActivate])) {
                            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateLineMemberRegisterRequestNeedActivate]) {
                                [NYLoginUserDataModel sharedModel].shouldActivate = YES;
                            }
                            NYLoginViewController *verifyCodeVC = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeVerifyCodeLineLoginRegister userCountryCode:countryCode userCountryID:countryID];
                            [weakSelf.navigationController pushViewController:verifyCodeVC animated:YES];
                        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateLineMemberRegisterRequestInvalidPhoneFormat]) {
                            NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[[weakSelf indexPathForTextField] firstObject]];
                            [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeCellPhone];
                            [weakSelf insertWaringCellAfterIndexPath:[[weakSelf indexPathForTextField] firstObject] withWariningMessage:message];
                        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateLineMemberRegisterRequestReachSMSLimit]) {
                            [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit = YES;
                            NYLoginViewController *verifyCodeVC = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeVerifyCodeLineLoginRegister  userCountryCode:weakSelf.countryPhoneCode userCountryID:weakSelf.countryID];
                            [weakSelf.navigationController pushViewController:verifyCodeVC animated:YES];
                        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateLineMemberRegisterRequestHadBinding]) {
                            [weakSelf displayAlertTitle:nil messageAndBackToRoot:message];
                        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateLineMemberRegisterRequestSystemError] ||
                                   [returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateLineMemberRegisterRequestError]) {
                            [weakSelf displayAlertMessage:message];
                        }
                    }
                }];
            } else if (weakSelf.loginType == NYLoginProcessTypeFacebookBingingCellPhone ||
                       weakSelf.loginType == NYLoginProcessTypeFacebookBingingCellPhoneNotFinish) {
                // 原先 FB 的移進來這個 Block
                [[NYLoginHelper sharedInstance] registerViaFacebookWithShopID:[NYGlobalData shopId]
                                                                    cellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                                                                  accessToken:[[NYLoginHelper sharedInstance] getFacebookCurrentAccessTokenString]
                                                                    authToken:[[NYLoginHelper sharedInstance] getFacebookCurrentAuthTokenString]
                                                                  countryCode:countryCode
                                                                    countryID:countryID
                                                            completionHandler:^(NSDictionary *data, NSError *error) {
                    [NYProgressHUD hideAllHUDsForView:weakSelf.view];
                    if (error) {
                        [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                            [weakSelf fbAndLineActionButtonAtLoginProcessTypeBindgingPhoneWithCountryCode:countryCode countryID:countryID];
                        }];
                    } else {
                        NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
                        NSString *message = [weakSelf apiReturnMessageForReturnData:data];
                        [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit = NO;
                        
                        // 成功 or 綁定的手機待開通
                        if (([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFacebookRegisterCodeSuccess]) || ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetNineYiMemberRegisterStatusNeedActivate])) {
                            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetNineYiMemberRegisterStatusNeedActivate]) {
                                [NYLoginUserDataModel sharedModel].shouldActivate = YES;
                            }
                            BOOL isLoginTypeFaceBindingCellPhoneNotFinished = (weakSelf.loginType == NYLoginProcessTypeFacebookBingingCellPhoneNotFinish);
                            NYLoginProcessType newVCLoginType = isLoginTypeFaceBindingCellPhoneNotFinished ? NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish : NYLoginProcessTypeVerifyCodeFacebookRegister;
                            NYLoginViewController *verifyCodeVC = [[NYLoginViewController alloc] initWithNYLoginProcessType:newVCLoginType userCountryCode:countryCode userCountryID:countryID];
                            [weakSelf.navigationController pushViewController:verifyCodeVC animated:YES];
                        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFacebookRegisterCodeInvalidFormat]) {
                            NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[[weakSelf indexPathForTextField] firstObject]];
                            [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeCellPhone];
                            [weakSelf insertWaringCellAfterIndexPath:[[weakSelf indexPathForTextField] firstObject] withWariningMessage:message];
                        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFacebookRegisterCodeReachSMSLimit]) {
                            [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit = YES;
                            BOOL isFacebookBindgingCellPhoneNotFinish = (weakSelf.loginType == NYLoginProcessTypeFacebookBingingCellPhoneNotFinish);
                            NYLoginProcessType newVCLoginType = isFacebookBindgingCellPhoneNotFinish ? NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish : NYLoginProcessTypeVerifyCodeFacebookRegister;
                            NYLoginViewController *verifyCodeVC = [[NYLoginViewController alloc] initWithNYLoginProcessType:newVCLoginType  userCountryCode:weakSelf.countryPhoneCode userCountryID:weakSelf.countryID];
                            [weakSelf.navigationController pushViewController:verifyCodeVC animated:YES];
                        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFacebookRegisterCodeAlreadyRegistered]) {
                            [weakSelf displayAlertTitle:nil messageAndBackToRoot:message];
                        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFacebookRegisterCodeSystemError]) {
                            [weakSelf displayAlertMessage:message];
                        }
                    }
                }];
            }
        } cancelBlock:nil];
    }];
}

/// fb / line 有手機登入需輸入驗證碼來註冊
- (void)fbAndLineActionButtonAtLoginProcessTypeVerifyCodeRegister {
    [self textFormateCheck:[NYLoginUserDataModel sharedModel].verifyCode checkType:NYLoginTextFieldFormatCheckTypeVerifyCode WithWarningMessage:NYLocalizedString(@"login_warning_invalid_verify_code", nil) AndSuccessCompletion:^{
        __weak typeof(self) weakSelf = self;
        
        //BTS 14006 Crash防呆, 照理說根本不該跑進此邏輯
        if (![NYLoginUserDataModel sharedModel].cellPhone) {
            [weakSelf displayAlertTitle:NYLocalizedString(@"login_alert_login_system_error", nil) messageAndBackToRoot:nil];
            return;
        }
        
        //Before Login time
        NSDate *timeBeforeLogin = [[NYLoginVCInfo sharedInfo] loginProcessStartTime];
        
        [NYProgressHUD showHUDAddedToView:self.view];

        if (self.loginType == NYLoginProcessTypeVerifyCodeLineLoginRegister ||
            self.loginType == NYLoginProcessTypeLineLoginExceedSMSLimit) {
            [[NYLoginHelper sharedInstance] confirmLineVerifyCodeWithCellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                                                                          code:[NYLoginUserDataModel sharedModel].verifyCode
                                                                   countryCode:weakSelf.countryPhoneCode
                                                                     countryId:weakSelf.countryID
                                                                       isOptIn:[NYLoginUserDataModel sharedModel].optinValue
                                                             completionHandler:^(NSDictionary *data, NSError *error) {
                [NYProgressHUD hideAllHUDsForView:weakSelf.view];
                if (error) {
                    [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                        [weakSelf fbAndLineActionButtonAtLoginProcessTypeVerifyCodeRegister];
                    }];
                } else {
                    NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
                    NSString *message = [weakSelf apiReturnMessageForReturnData:data];

                    if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILineMemberConfirmVerifyCodeCodeSuccess] ||
                        [returnCode isEqualToString:NYLoginReturnCodes.kNYAPILineMemberConfirmVerifyCodeCodeSuccessButSentCouponFail]) {
                        [weakSelf continueFirstRegisterLineLoginAndShowGetCouponIfNeedWith:data];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILineMemberConfirmVerifyCodeCodeWrongCode]) {
                        NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[[weakSelf indexPathForTextField] firstObject]];
                        [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeVerifyCode];
                        [weakSelf insertWaringCellAfterIndexPath:[[weakSelf indexPathForTextField] firstObject] withWariningMessage:message];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILineMemberConfirmVerifyCodeCodeExpired] ||
                             [returnCode isEqualToString:NYLoginReturnCodes.kNYAPILineMemberConfirmVerifyCodeCodeAlreadyRegistered]) {
                        [weakSelf displayAlertTitle:nil messageAndBackToRoot:message];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILineMemberConfirmVerifyCodeCodeSystemErrorI] ||
                               [returnCode isEqualToString:NYLoginReturnCodes.kNYAPILineMemberConfirmVerifyCodeCodeSystemErrorII]) {
                        [weakSelf displayAlertMessage:message];
                    }
                }
            }];
        } else {
            // 原先非 Apple Login 的 Code 的移進來這個 Block，
            // 且 thirdpartyAuthActionButtonAtLoginProcessTypeVerifyCodeThirdpartyAuthRegister 也會 call
            // 因此這邊就不做型別判斷
            
            // device參數只有門市小幫手是帶Pad、其餘iOS跟Android都是帶Mobile
            [[NYLoginHelper sharedInstance] confirmVerifyCodeViaFacebookWithShopID:[NYGlobalData shopId]
                                                                       accessToken:[[NYLoginHelper sharedInstance] getFacebookCurrentAccessTokenString]
                                                                         authToken:[[NYLoginHelper sharedInstance] getFacebookCurrentAuthTokenString]
                                                                         cellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                                                                              code:[NYLoginUserDataModel sharedModel].verifyCode
                                                                            source:@"iOSApp"
                                                                            device:@"Mobile"
                                                                        appVersion:[NYGlobalData appVersionString]
                                                                       countryCode:self.countryPhoneCode
                                                                         countryID:self.countryID
                                                                  enableOptInSplit:[NYLoginUserDataModel sharedModel].enableOptInSplit
                                                                           isOptIn:[NYLoginUserDataModel sharedModel].optinValue
                                                                       isEnableEDM:@([NYLoginUserDataModel sharedModel].isEnableEDM)
                                                                    isEnableEdmSMS:@([NYLoginUserDataModel sharedModel].isEnableEdmSMS)
                                                                  isAppPushProfile:@([NYLoginUserDataModel sharedModel].isAppPushProfile)
                                                                 completionHandler:^(NSDictionary *data, NSError *error) {
                [NYProgressHUD hideAllHUDsForView:weakSelf.view];
                if (error) {
                    [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                        [weakSelf fbAndLineActionButtonAtLoginProcessTypeVerifyCodeRegister];
                    }];
                } else {
                    NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
                    NSString *message = [weakSelf apiReturnMessageForReturnData:data];
                    
                    if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFacebookConfirmVerifyCodeCodeSuccess]) {
                        [weakSelf dismissSelfFromPresentingAfterLoginSuccessWithIsRegister:YES];
                        [[NYReferrerBindingLinkInjectionHelper shared] cleanStoredReferrerInfo];
                        // FA
                        NSString *userPhoneNumber = [NYLoginUserDataModel sharedModel].cellPhone;
                        [self setEventUserInfoWithPhone:userPhoneNumber];
                        NSTimeInterval loginDuration = [timeBeforeLogin timeIntervalSinceNow];
                        [[NYStatisticHelper sharedHelper] sendEventSignUpWithMethod:kFAParamSignupLoginMethodFacebook
                                                                             status:kFAParamSignupLoginStatusFinish
                                                                           duration:@(-loginDuration)];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFacebookConfirmVerifyCodeCodeWrongCode]) {
                        NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[[weakSelf indexPathForTextField] firstObject]];
                        [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeVerifyCode];
                        [weakSelf insertWaringCellAfterIndexPath:[[weakSelf indexPathForTextField] firstObject] withWariningMessage:message];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFacebookConfirmVerifyCodeCodeExpired] ||
                             [returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFacebookConfirmVerifyCodeCodeAlreadyRegistered]) {
                        [weakSelf displayAlertTitle:nil messageAndBackToRoot:message];
                    } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFacebookConfirmVerifyCodeCodeSystemError]) {
                        [weakSelf displayAlertMessage:message];
                    }
                }
            }];
        }
    }];
}

- (void)thirdpartyAuthActionButtonAtLoginProcessTypeVerifyCodeThirdpartyAuthRegister {
     NYLoginUserDataModel *userModel = [NYLoginUserDataModel sharedModel];
    [self textFormateCheck:userModel.verifyCode checkType:NYLoginTextFieldFormatCheckTypeVerifyCode WithWarningMessage:NYLocalizedString(@"login_warning_invalid_verify_code", nil) AndSuccessCompletion:^{
        
        //Before Login time
        NSDate *timeBeforeLogin = [[NYLoginVCInfo sharedInfo] loginProcessStartTime];
        
        [NYProgressHUD showHUDAddedToView:self.view];
        
        __weak typeof(self) weakSelf = self;
        [[NYLoginHelper sharedInstance] confirmThirdpartyMemberVerifyCodeWithCellPhone:userModel.cellPhone
                                                                                shopId:[NYGlobalData shopId]
                                                                                  code:userModel.verifyCode
                                                                                 token:userModel.thirdpartyToken
                                                                                source:@"iOSApp"
                                                                                device:@"Mobile"
                                                                            appVersion:[NYGlobalData appVersionString]
                                                                           countryCode:self.countryPhoneCode
                                                                             countryID:self.countryID
                                                                               isOptIn:[NYLoginUserDataModel sharedModel].optinValue
                                                                     completionHandler:^(NSDictionary *data, NSError *error) {
            [NYProgressHUD hideAllHUDsForView:weakSelf.view];
            if (error) {
                [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                    [weakSelf fbAndLineActionButtonAtLoginProcessTypeVerifyCodeRegister];
                }];
            } else {
                NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
                NSString *message = [weakSelf apiReturnMessageForReturnData:data];
                
                if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIConfirmThirdpartyMemberVerifyCodeSuccess]) {
                    [weakSelf dismissSelfFromPresentingAfterLoginSuccessWithIsRegister:YES];
                    [[NYReferrerBindingLinkInjectionHelper shared] cleanStoredReferrerInfo];
                    // FA
                    [self setEventUserInfoWithPhone:userModel.cellPhone];
                    NSTimeInterval loginDuration = [timeBeforeLogin timeIntervalSinceNow];
                    // 第三方的手機驗證成功會在這裡，失敗會call facebookActionButtonAtLoginProcessTypeVerifyCodeFacebookRegister()，目前這邊都是FB
                    [[NYStatisticHelper sharedHelper] sendEventSignUpWithMethod:kFAParamSignupLoginMethodShopAccount
                                                                         status:kFAParamSignupLoginStatusFinish
                                                                       duration:@(-loginDuration)];
                }
                //第三方手機註冊驗證碼
                else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIConfirmThirdpartyMemberVerifyCodeWrongCode]) {
                    NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:[[weakSelf indexPathForTextField] firstObject]];
                    [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeVerifyCode];
                    [weakSelf insertWaringCellAfterIndexPath:[[weakSelf indexPathForTextField] firstObject] withWariningMessage:message];
                } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIConfirmThirdpartyMemberVerifyCodeAlreadyRegistered] ||
                         [returnCode isEqualToString:NYLoginReturnCodes.kNYAPIConfirmThirdpartyMemberVerifyCodeExpired]) {
                    [weakSelf displayAlertTitle:nil messageAndBackToRoot:message];
                } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIConfirmThirdpartyMemberVerifyCodeSystemError]) {
                    [weakSelf displayAlertMessage:message];
                }
            }
        }];
    }];
}

#pragma mark - 手機驗證頁
- (void)actionButtonAtLoginProcessTypeSocialAccountValidateCellPhone {
    NYLoginUserDataModel *userModel = [NYLoginUserDataModel sharedModel];
    
    // 手機格式錯誤、顯示warning cell
    void(^addWariningCell)(NSString *) = ^(NSString *wariningMessage) {
        NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:[[self indexPathForTextField] firstObject]];
        [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeCellPhone];
        [self insertWaringCellAfterIndexPath:[[self indexPathForTextField] firstObject] withWariningMessage:wariningMessage];
    };
    
    // app 先判斷使用者輸入空的電話做訊息提示
    if (!userModel.cellPhone || [userModel.cellPhone isEqualToString:@""]) {
        addWariningCell(NYLocalizedString(@"login_warning_invalid_cellphone", nil));
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    // 輸入驗證碼頁
    void(^pushSocialAccountVerifyCodeVC)(NYLoginProcessType) = ^(NYLoginProcessType type){
        NYLoginViewController *verifyCodeVC = [[NYLoginViewController alloc]
                                               initWithNYLoginProcessType:type
                                               userCountryCode:weakSelf.countryPhoneCode
                                               userCountryID:weakSelf.countryID];
        // 更新 countryAliasCode，手機驗證完打 updateCellPhone API 需要 countryAliasCode
        [verifyCodeVC setUserCountryWithCountryCode:weakSelf.countryPhoneCode
                                          countryID:weakSelf.countryID
                                   countryAliasCode:weakSelf.countryAliasCode];
        
        [weakSelf.navigationController pushViewController:verifyCodeVC animated:YES];
    };
    
    // 取得驗證碼
    void(^sendVerifyCode)(NSString *) = ^(NSString *reCaptchaToken) {
        [[NYLoginHelper sharedInstance] sendVerifyCodeWithShopID:[NYGlobalData shopId]
                                                       cellPhone:userModel.cellPhone
                                                  reCaptchaToken:reCaptchaToken
                                                     countryCode:weakSelf.countryPhoneCode
                                                       countryID:@1
                                                         smsType:@"MemberPassword"
                                               completionHandler:^(NSDictionary *data, NSError *error) {
            
            NSString *returnCode = data[kDATA_KEY][@"ReturnCode"] ?: @"";
            [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit = NO;
            [NYLoginVCInfo sharedInfo].isViaVoiceServiceReachLimit = NO;
            BOOL isValidateCellPhone = self.loginType == NYLoginProcessTypeSocialAccountValidateCellPhone;
            BOOL isBindingCellPhone = self.loginType == NYLoginProcessTypeSocialAccountBindingCellPhone;
            
            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateNineYiMemberRegisterRequestSuccess]) {
                // 檢核成功、進入輸入驗證碼頁
                
                // 手機號碼存起來
                [NYUserDefault setUserCellPhone:userModel.cellPhone];
                
                if (isValidateCellPhone) {
                    // 從手機驗證頁來
                    pushSocialAccountVerifyCodeVC(NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone);
                    
                } else if (isBindingCellPhone) {
                    // 從帳號綁定頁來
                    pushSocialAccountVerifyCodeVC(NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone);
                }
                
            } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateNineYiMemberRegisterRequestReachSMSLimit]) {
                // 簡訊發送超過上限、進入輸入驗證碼頁
                [NYLoginVCInfo sharedInfo].isResendVerifyCodeReachLimit = YES;
                
                if (isValidateCellPhone) {
                    // 從手機驗證頁來
                    pushSocialAccountVerifyCodeVC(NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone);
                    
                } else if (isBindingCellPhone) {
                    // 從帳號綁定頁來
                    pushSocialAccountVerifyCodeVC(NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone);
                }
                
            } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateNineYiMemberRegisterRequestInvalidFormat]) {
                // 手機格式錯誤、顯示warning cell
                [weakSelf displayAlertMessage:NYLocalizedString(@"member_info_phonenumber_type_error_message", nil)];

            } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICreateNineYiMemberRegisterRequestRegistered]) {
                // 會員(可能在別台手機或官網)已完成註冊、回登入首頁
                [weakSelf displayAlertTitle:NYLocalizedString(@"member_info_phonenumber_havebeenused_error_message", nil)
                       messageAndBackToRoot:NYLocalizedString(@"member_info_phonenumber_havebeenused_description_errordialog", nil)];

            } else {
                // 其它錯誤
                [weakSelf displayAlertTitle:[NSString stringWithFormat:NYLocalizedString(@"common_alert_error_code", nil), returnCode]
                       messageAndBackToRoot:nil];
            }
        }];
    };
    
    [self checkIsValidWithCellPhone:userModel.cellPhone
                   countryAliasCode:self.countryAliasCode
                  successCompletion:^{
        
        if (weakSelf.canUseReCaptcha) {
            [NYLoginViewController reCaptchaGetTokenBlock](^(NSString *reCaptchaToken) {
                if (reCaptchaToken && ![reCaptchaToken isEqualToString:@""]) {
                    sendVerifyCode(reCaptchaToken);
                } else {
                    // 拿不到 token 就用原 API error 處理方式
                    [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                        [weakSelf actionButtonAtLoginProcessTypeSocialAccountValidateCellPhone];
                    }];
                }
            });
        } else {
            sendVerifyCode(@"");
        }
    }];
}

#pragma mark - private helper
- (void)getThirdpartyMemberRegisterStatusWithToken {
    [NYProgressHUD showHUDAddedToView:self.view];
    __weak typeof(self) weakSelf = self;
    [[NYDataProvider sharedInstance] getThirdpartyMemberRegisterStatusWithTokenWithAccessToken:self.accessToken ShopId:[NYGlobalData shopId] completionHandler:^(NSDictionary *data, NSError *error) {
        [NYProgressHUD hideAllHUDsForView:weakSelf.view];
        
        if (error) {
            [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                [weakSelf getThirdpartyMemberRegisterStatusWithToken];
            }];
        } else {
            NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
            NSString *message = [weakSelf apiReturnMessageForReturnData:data];
            
            NSString *thirdPartyToken = data[kNYDataKey][@"Data"][@"authSessionToken"];
            if (thirdPartyToken.length > 0) {
                [[NYLoginUserDataModel sharedModel] setThirdpartyToken:thirdPartyToken];
            }
            
            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetThirdpartyMemberRegisterStatusWithTokenRegistered]) {
                [weakSelf loginThirdpartyMember];
                // GA 商店官網帳號登入完成
            } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetThirdpartyMemberRegisterStatusWithTokenUnregistered]) {
                NYLoginViewController *bindingCellPhone = [[NYLoginViewController alloc] initWithNYLoginProcessType:NYLoginProcessTypeThirdpartyBingingCellPhone userCountryCode:self.countryPhoneCode userCountryID:self.countryID];
                [self.navigationController pushViewController:bindingCellPhone animated:YES];
            } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetThirdpartyMemberRegisterStatusWithTokenExpired]) {
                [weakSelf displayAlertMessage:message];
                [[NYLoginUserDataModel sharedModel] setAccessToken:nil];
                [[NYLoginUserDataModel sharedModel] setThirdpartyToken:nil];
                self.accessToken = nil;
                
                [self actionForThirdpartyAuthActionButton];
            } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetThirdpartyMemberRegisterStatusWithTokenSystemError]) {
                [weakSelf displayAlertMessage:message];
            }
        }
    }];
}

- (void)loginThirdpartyMember {
    //Before Login time
    NSDate *timeBeforeLogin = [[NYLoginVCInfo sharedInfo] loginProcessStartTime];
    
    [NYProgressHUD showHUDAddedToView:self.view];
    
    NYLoginUserDataModel *userModel = [NYLoginUserDataModel sharedModel];
    
    __weak typeof(self) weakSelf = self;
    [[NYLoginHelper sharedInstance] loginThirdpartyMemberWithAuthSessionToken:userModel.thirdpartyToken
                                                                       shopId:[NYGlobalData shopId]
                                                                       source:@"iOSApp"
                                                                       device:@"Mobile"
                                                                   appVersion:[NYGlobalData appVersionString]
                                                                  countryCode:self.countryPhoneCode
                                                                    countryID:self.countryID
                                                            completionHandler:^(NSDictionary *data, NSError *error) {
        [NYProgressHUD hideAllHUDsForView:self.view];
        if (error) {
            [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                [weakSelf loginThirdpartyMember];
            }];
        } else {
            NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
            NSString *message = [weakSelf apiReturnMessageForReturnData:data];
            
            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILoginThirdpartyMemberSuccess]) {
                [weakSelf dismissSelfFromPresentingAfterLoginSuccessWithIsRegister:NO];
                [NYLoginViewController commonActionAfterLoginSuccess];
                // FA
                NSTimeInterval loginDuration = [timeBeforeLogin timeIntervalSinceNow];
                [[NYStatisticHelper sharedHelper] sendEventLoginWithMethod:kFAParamSignupLoginMethodShopAccount
                                                                    status:kFAParamSignupLoginStatusFinish
                                                                  duration:@(-loginDuration)];
                [[LoginInjectionHelper shared] syncServingLocationIfNeeded];
            } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILoginThirdpartyMemberSystemError]) {
                [weakSelf displayAlertMessage:message];
            }
        }
    }];
}

- (void)fetchRegisterSettingConfig {
    // 取得需不需要強制輸入使用者資料 or 通知聲明
    [NYProgressHUD showHUDAddedToView:self.view];
    __weak typeof(self) weakSelf = self;
    [[NYDataProvider sharedInstance] getRegisterSettingConfigWithShopID:[NYGlobalData shopId] completion:^(BOOL enableProfile, BOOL enableOptin, BOOL defaultOptin, BOOL allFilled, BOOL enableOptInSplit, NSError *error) {
        [NYProgressHUD hideAllHUDsForView:weakSelf.view];

        if (error) {
            // Fail
            [weakSelf ny_displayBadNetworkWithReloadBlock:^{
                [weakSelf fetchRegisterSettingConfig];
            } cancelBlock:^{
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            }];
        } else {
            // Success
            [NYLoginUserDataModel sharedModel].enableProfile = enableProfile;
            [NYLoginUserDataModel sharedModel].enableOptin = enableOptin;
            [NYLoginUserDataModel sharedModel].optin = defaultOptin;
            [NYLoginUserDataModel sharedModel].isEnableEDM = defaultOptin;
            [NYLoginUserDataModel sharedModel].isEnableEdmSMS = defaultOptin;
            [NYLoginUserDataModel sharedModel].isAppPushProfile = defaultOptin;
            [NYLoginUserDataModel sharedModel].enableOptInSplit = enableOptInSplit;
            [NYLoginUserDataModel sharedModel].isProfileFilled = allFilled;
        }
    }];
}

- (void)fetchPasswordRegexSetting:(void(^)(void))completion {
    // 取得密碼 regex 與文案
    [NYProgressHUD showHUDAddedToView:self.view];
    __weak typeof(self) weakSelf = self;
    
    [NYLoginPasswordRegexProcessor getPasswordRegexSettingWithCompletion:^(BOOL isSuccess, NSString * _Nonnull regex, NSArray<NSString *> * _Nonnull regexContents) {
        [NYProgressHUD hideAllHUDsForView:weakSelf.view];
        
        if (isSuccess) {
            [NYLoginUserDataModel sharedModel].passwordRegex = regex;
            [NYLoginUserDataModel sharedModel].passwordRegexContents = regexContents;
        } else {
            // 錯誤情境不做任何處理，app 預設判斷上限 128 碼
            [NYLoginUserDataModel sharedModel].passwordRegex = DEFAULT_PWD_REGEX;
            [NYLoginUserDataModel sharedModel].passwordRegexContents = @[];
        }
        
        if (completion) {
            completion();
        }
    }];
}

- (void)fetchThirdPartyAuthInfoAndLineChannelIdAndAdBannerInfo {
    __weak typeof(self) weakSelf = self;
    
    [NYProgressHUD showHUDAddedToView:self.view];
    dispatch_group_t group = dispatch_group_create();

    // CALL API
    dispatch_group_enter(group);
    [[NYDataProvider sharedInstance] getShopThirdpartyAuthInfoWithShopId:[NYGlobalData shopId] device:@"Mobile" completionHandler:^(NSDictionary *data, NSError *error) {
        if (!error) {
            NSString *returnCode = [weakSelf apiReturnCodeForReturnData:data];
//            NSString *message = [weakSelf apiReturnMessageForReturnData:data];
            
            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIGetShopThirdpartyAuthInfoSuccess]) {
                weakSelf.thirdPartyAuthLoginInfoDic = data[kNYDataKey][@"Data"];
            }
        }
        dispatch_group_leave(group);
    }];
    
    if (NYUserDefault.isLineLoginEnable) {
        // CALL API GET LINE CHANNELID
        dispatch_group_enter(group);

        [[NYDataProvider sharedInstance] getLineLoginChannelIdWithShopId:[NYGlobalData shopId]
                                                              completion:^(NSString *channelId) {
            if (![channelId isEqualToString: @""]) {
                weakSelf.lineChannelId = channelId;
                [weakSelf setupLineChannelIdIfNeed:weakSelf.lineChannelId];
            }
            dispatch_group_leave(group);
        }];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [NYProgressHUD hideAllHUDsForView:weakSelf.view];

        //因為廣告版位資訊是insert進去的、需等到確定OAuth按鈕是否顯示之後再insert進entries
        //且也需要先取得 Line channel ID 來決定是否顯示 Line Login Button
        //因此在 notify 裡面才重新產生 entries
        weakSelf.entries = [weakSelf generateEntriedForLoginType:weakSelf.loginType].mutableCopy;
        [weakSelf registerCellIdentifierFromEntries:weakSelf.entries];
        [weakSelf fetchAdBannerInfo];
    });
}

- (void)fetchAdBannerInfo {
    __weak typeof(self) weakSelf = self;
    
    //Call API
    [NYProgressHUD showHUDAddedToView:self.view];
    [[NYDataProvider sharedInstance] getShopLayoutTemplateDataForShopId:[NYGlobalData shopId].integerValue andADCode:[NSString stringWithFormat:@"SpLoginAdMobile"] completionHandler:^(NSDictionary *data, NSError *error) {
        //先收鍵盤 (變免跟顯示/隱藏Banner的事件衝突)
        [weakSelf.view endEditing:YES];
        [NYProgressHUD hideAllHUDsForView:weakSelf.view];
        NSArray *objects = data[kDATA_KEY];
        if (objects.count > 0 && !error) {
            //Success
            [weakSelf.entries insertObject:@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeLoginAdBanner andContent:@{@"SpLoginAdMobile" : objects.firstObject}]] atIndex:0];
        }
        else {
            //Error (do nothing?)
        }
        
        [weakSelf.collectionView reloadData];
    }];
}

- (void)insertWaringCellAfterIndexPath:(NSIndexPath *)indexPath withWariningMessage:(NSString *)message {
    NSIndexPath *warningIndexPath = [self indexPathForWarningCell:self.entries];
    if (warningIndexPath) {
        return;
    }

    [self.entries insertObject:@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeWarningCell
                                                                      andContent:@{@"cellTitle": message}]]
                       atIndex:indexPath.section + 1];
    [self.collectionView reloadData];
}

- (void)removeWarningCell {
    NSIndexPath *indexPath = [self indexPathForWarningCell:self.entries];
    if (indexPath) {
        [self.entries removeObjectAtIndex:indexPath.section];
        [self.collectionView reloadData];
    }
}

- (void)changeLoginStyle {
    NSIndexPath *indexPath = [self indexPathForCellType:NYLoginCellTypeShowPhoneLoginText];
    
    [self.entries removeObjectAtIndex:indexPath.section];
    [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section]];
    
    [self.entries insertObject:@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNineYiActionButton
                                                                      andContent:@{@"cellTitle":NYLocalizedString(@"login_loginCell_title_login_or_register_with_cellPhoneNumber", nil),
                                                                                   @"backgroundColor":[UIColor orangeColor]}]]
                       atIndex:indexPath.section];
    [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:indexPath.section]];
    [self.entries insertObject:@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldPhoneNumber
                                                                      andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_cellphone", nil)}]]
                       atIndex:indexPath.section];
    [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:indexPath.section]];
}

- (NSString *)storyboardControllerIdentifierForLoginProcessType:(NYLoginProcessType)type {
    switch (type) {
        case NYLoginProcessTypeLogin:
        case NYLoginProcessTypeNineYiEnterPassword:
        case NYLoginProcessTypeNineYiSetPassword:
        case NYLoginProcessTypeSocialAccountBindingCellPhonSetPassword:
        case NYLoginProcessTypeMemberDirectSetPassword:
        case NYLoginProcessTypeExpressSetPassword:
        case NYLoginProcessTypeNineYiResetPassword:
        case NYLoginProcessTypeExpressResetPassword:
        case NYLoginProcessTypeNineYiISPResetPassword:
        case NYLoginProcessTypeFacebookBingingCellPhone:
        case NYLoginProcessTypeLineLoginBingingCellPhone:
        case NYLoginProcessTypeFacebookBingingCellPhoneNotFinish:
        case NYLoginProcessTypeThirdpartyBingingCellPhone:
        case NYLoginProcessTypeAppleSignIn:
        case NYLoginProcessTypeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeSocialAccountBindingCellPhone:
            return @"NYLoginViewController";
            break;
        case NYLoginProcessTypeVerifyCodeNineYiRegister:
        case NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber:
        case NYLoginProcessTypeVerifyCodeNineYiForgetPassword:
        case NYLoginProcessTypeVerifyCodeFacebookRegister:
        case NYLoginProcessTypeVerifyCodeLineLoginRegister:
        case NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish:
        case NYLoginProcessTypeVerifyCodeThirdpartyRegister:
        case NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone:
        case NYLoginProcessTypeLineLoginExceedSMSLimit:
        case NYLoginProcessTypeVerifyCodeExpressRegister:
        case NYLoginProcessTypeVerifyCodeExpressResetPassword:
        case NYLoginProcessTypeVerifyCodeMemberDirectSetPassword:
            return @"NYVerifyCodeVC";
            break;
        case NYLoginProcessTypeUnknown:
        default:
            return @"";
            break;
    }
}

- (void)registerCellIdentifierFromEntries:(NSArray *)entries {
    NSBundle *bundle = [NSBundle nyBundleWithNYLoginViewController];
    [entries enumerateObjectsUsingBlock:^(NSArray *section, NSUInteger idx, BOOL *stop) {
        [section enumerateObjectsUsingBlock:^(NYLoginCellDataModel *dataModel, NSUInteger idx, BOOL *stop) {
            BOOL nibExist = [bundle pathForResource:dataModel.cellIdentifier ofType:@"nib"] ? YES : NO;
            if (nibExist) {
                [self.collectionView registerNib:[UINib nibWithNibName:dataModel.cellIdentifier bundle:bundle]
                      forCellWithReuseIdentifier:dataModel.cellIdentifier];
            }
        }];
    }];
 
    NYLoginCellDataModel *warningDataModel = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeWarningCell andContent:nil];
    [self.collectionView registerNib:[UINib nibWithNibName:warningDataModel.cellIdentifier bundle:bundle]
          forCellWithReuseIdentifier:warningDataModel.cellIdentifier];
    
    NYLoginCellDataModel *thirdPartyAuthAccountModel = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeThirdpartyAuthInputAccountCell andContent:nil];
    [self.collectionView registerNib:[UINib nibWithNibName:thirdPartyAuthAccountModel.cellIdentifier bundle:bundle]
          forCellWithReuseIdentifier:thirdPartyAuthAccountModel.cellIdentifier];

    NYLoginCellDataModel *thirdPartyAuthPasswordModel = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeThirdpartyAuthInputPasswordCell andContent:nil];
    [self.collectionView registerNib:[UINib nibWithNibName:thirdPartyAuthPasswordModel.cellIdentifier bundle:bundle]
          forCellWithReuseIdentifier:thirdPartyAuthPasswordModel.cellIdentifier];
    
    [self.collectionView registerNib:[UINib nibWithNibName:@"NYLoginNineYiActionCell" bundle:bundle]
          forCellWithReuseIdentifier:@"NYLoginNineYiActionCell"];
    [self.collectionView registerNib:[UINib nibWithNibName:@"NYLoginPhoneNumberCell" bundle:bundle]
          forCellWithReuseIdentifier:@"NYLoginPhoneNumberCell"];
    [self.collectionView registerNib:[UINib nibWithNibName:@"NYLoginAntiFraudCell" bundle:bundle]
          forCellWithReuseIdentifier:@"NYLoginAntiFraudCell"];
    [self.collectionView registerNib:[UINib nibWithNibName:@"NYLoginTextOnlyCell" bundle:bundle]
          forCellWithReuseIdentifier:@"NYLoginTextOnlyCell"];
    [self.collectionView registerNib:[UINib nibWithNibName:@"NYLoginAppleSignInCell" bundle:bundle]
          forCellWithReuseIdentifier:@"NYLoginAppleSignInCell"];
    [self.collectionView registerNib:[UINib nibWithNibName:@"NYLoginLineLoginCell" bundle:bundle]
          forCellWithReuseIdentifier:@"NYLoginLineLoginCell"];
    [self.collectionView registerNib:[UINib nibWithNibName:@"NYLoginOnlyPhoneLoginWarningCell" bundle:bundle]
          forCellWithReuseIdentifier:@"NYLoginCellIdentifierOnlyPhoneLoginWarning"];
    [self.collectionView registerNib:[UINib nibWithNibName:@"NYOptInCell" bundle:bundle]
          forCellWithReuseIdentifier:@"NYOptInCell"];
}

- (NSMutableArray *)indexPathForTextField {
    NSMutableArray *contentForIndexPath = [NSMutableArray array];
    [self.entries enumerateObjectsUsingBlock:^(NSArray *sectionInfo, NSUInteger sectionIdx, BOOL *stop) {
        [sectionInfo enumerateObjectsUsingBlock:^(NYLoginCellDataModel *dataModel, NSUInteger rowIdx, BOOL *stop) {
            if (dataModel.cellType == NYLoginCellTypeTextFieldPhoneNumber ||
                dataModel.cellType == NYLoginCellTypeTextFieldPassword ||
                dataModel.cellType == NYLoginCellTypeTextFieldVerifyCode ||
                dataModel.cellType == NYLoginCellTypeThirdpartyAuthInputAccountCell ||
                dataModel.cellType == NYLoginCellTypeThirdpartyAuthInputPasswordCell ||
                dataModel.cellType == NYLoginCellTypeThirdpartyAuthTextFieldPhoneNumber) {
                [contentForIndexPath addObject:[NSIndexPath indexPathForRow:rowIdx inSection:sectionIdx]];
            }
        }];
    }];
    
    return contentForIndexPath;
}

- (NSIndexPath *)indexPathForWarningCell:(NSArray *)entries {
    NSMutableArray *contentForIndexPath = [NSMutableArray array];
    [self.entries enumerateObjectsUsingBlock:^(NSArray *sectionInfo, NSUInteger sectionIdx, BOOL *stop) {
        [sectionInfo enumerateObjectsUsingBlock:^(NYLoginCellDataModel *dataModel, NSUInteger rowIdx, BOOL *stop) {
            if (dataModel.cellType == NYLoginCellTypeWarningCell) {
                [contentForIndexPath addObject:[NSIndexPath indexPathForRow:rowIdx inSection:sectionIdx]];
            }
        }];
    }];
    
    return [contentForIndexPath firstObject];
}

- (NSIndexPath *)indexPathForCellType:(NYLoginCellType)type {
    NSMutableArray *contentForIndexPath = [NSMutableArray array];
    [self.entries enumerateObjectsUsingBlock:^(NSArray *sectionInfo, NSUInteger sectionIdx, BOOL *stop) {
        [sectionInfo enumerateObjectsUsingBlock:^(NYLoginCellDataModel *dataModel, NSUInteger rowIdx, BOOL *stop) {
            if (dataModel.cellType == type) {
                [contentForIndexPath addObject:[NSIndexPath indexPathForRow:rowIdx inSection:sectionIdx]];
            }
        }];
    }];
    
    return [contentForIndexPath firstObject];
}

- (void)dismissSelfFromPresentingByUser {
    [self.view endEditing:YES];
    NYLoginVCInfo *info = [NYLoginVCInfo sharedInfo];
    if (info.shouldShowUnloginMask) {
        [info.waitingForLoginVC displayUnloginView];
    }
    [info clearInfo];
    if (info.dismissCompletion) {
        info.dismissCompletion();
    } else {
        [self dismissViewControllerAnimated:YES completion:^{
            
        }];
    }
    self.isNormallyClosed = YES;
}

- (void)dismissSelfWithCustomExtraCompletionBlock:(void(^)(void))extCompletion {
    [self.view endEditing:YES];
    NYLoginVCInfo *info = [NYLoginVCInfo sharedInfo];
    if (info.shouldShowUnloginMask) {
        [info.waitingForLoginVC displayUnloginView];
    }
    [info clearInfo];
    if (info.dismissCompletion) {
        info.dismissCompletion();
        extCompletion();
    } else {
        [self dismissViewControllerAnimated:YES completion:^{
            extCompletion();
        }];
    }
    self.isNormallyClosed = YES;
}

- (void)presentProfileBlockAndConfirmAutoGetCouponAlert {
    __weak typeof(self) weakSelf = self;
    [NYLoginViewController presentProfileBlock](self, ^() {
        [weakSelf confirmAutoGetCouponAlert];
    });
}

- (NSArray *)generateEntriedForLoginType:(NYLoginProcessType)type {
    switch (type) {
        typedef NYLoginCellDataModel Model;
        case NYLoginProcessTypeLogin:
        {
            NSMutableArray *entry = [NSMutableArray array];
            
            Model *loginTitle = [NYLoginCellDataModel
                                 cellDataModelWithCellType:NYLoginCellTypeLoginTitle
                                 andContent:@{@"content1":NYLocalizedString(@"login_title_account_notice", nil)}];
            Model *phoneNumberTextField = [NYLoginCellDataModel
                                            cellDataModelWithCellType:NYLoginCellTypeTextFieldPhoneNumber
                                            andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_cellphone", nil)}];
            Model *btn = [NYLoginCellDataModel
                          cellDataModelWithCellType:NYLoginCellTypeNineYiActionButton
                          andContent:@{@"cellTitle":NYLocalizedString(@"login_btn_login_or_register", nil)}];
            [entry addObjectsFromArray:@[@[loginTitle],
                                         @[phoneNumberTextField],
                                         @[btn]
                                         ]];
            
            BOOL needShowAppleSignIn = [self isAppleSignInEnable];
            BOOL needShowFBLogin = [self isFBLoginEnable] && needShowAppleSignIn;
            BOOL needShowLineLogin = [self isLineLoginEnable] && needShowAppleSignIn;
            BOOL isOAuthLoginEnable = [self.thirdPartyAuthLoginInfoDic[@"EnableThirdpartyAuthMember"] boolValue];
            BOOL needShowThirdPartyLogin = [NYUserDefault shouldEnableLocationMember] && isOAuthLoginEnable;
            
            if (needShowFBLogin || needShowThirdPartyLogin) {
                Model *seperator = [NYLoginCellDataModel
                             cellDataModelWithCellType:NYLoginCellTypeNineYiFacebookSeperator
                             andContent:nil];
                [entry addObject:@[seperator]];
            }
            
            if (needShowFBLogin) {
                Model *fbLogin = [NYLoginCellDataModel
                                  cellDataModelWithCellType:NYLoginCellTypeFacebookLogin
                                  andContent:nil];
                [entry addObject:@[fbLogin]];
            }
            
            if (needShowLineLogin && self.lineChannelId != nil) {
                Model *linelogin = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeLineLogin andContent:nil];
                [entry addObject:@[linelogin]];
            }
            
            if (needShowAppleSignIn) {
                Model *appleSignIn = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginAppleSignInCell andContent:nil];
                [entry addObject:@[appleSignIn]];
            }
            
            if (needShowThirdPartyLogin) {
                NSString *oAuthLoginButtonTitle = (self.thirdPartyAuthLoginInfoDic[@"ThirdpartyAuthButtonContent"]) ? : NYLocalizedString(@"login_btn_third_party_account_login", nil);
                Model *thirdpartyLogin = [NYLoginCellDataModel
                                          cellDataModelWithCellType:NYLoginCellTypeThirdpartyAuthLoginButtonCell
                                          andContent:@{@"cellTitle":oAuthLoginButtonTitle}];
                [entry addObject:@[thirdpartyLogin]];
            }

            if (!needShowAppleSignIn) {
                Model *onlyPhoneLoginWarning = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeOnlyPhoneLoginWarning andContent:nil];
                [entry addObject:@[onlyPhoneLoginWarning]];
            }

            Model *announcement = [NYLoginCellDataModel
                                   cellDataModelWithCellType:NYLoginCellTypeAnnoucementPrefix
                                   andContent:@{@"content1":NYLocalizedString(@"login_xib_account_notice", nil)}];
            Model *serviceInstruction = [NYLoginCellDataModel
                                         cellDataModelWithCellType:NYLoginCellTypeAnnoucementServiceInstruction
                                         andContent:@{@"content1":NYLocalizedString(@"login_xib_service_term", nil)}];
            Model *and = [NYLoginCellDataModel
                          cellDataModelWithCellType:NYLoginCellTypeAnnoucementAnd
                          andContent:@{@"content1":NYLocalizedString(@"login_xib_and", nil)}];
            Model *privacy = [NYLoginCellDataModel
                              cellDataModelWithCellType:NYLoginCellTypeAnnoucementPrivacy
                              andContent:@{@"content1":NYLocalizedString(@"login_xib_privacy_notice", nil)}];
            [entry addObjectsFromArray:@[@[announcement],
                                         @[serviceInstruction,
                                           and,
                                           privacy]
                                         ]];

            if ([NYUserDefault getAntiFraudPreference]) {
                Model *antiFraud = [NYLoginCellDataModel
                                    cellDataModelWithCellType:NYLoginAntiFraudCell andContent:nil];
                NSArray *antiFraudArray = @[antiFraud];
                [entry addObject:antiFraudArray];
            }
            
            return entry;
        }
            break;
        case NYLoginProcessTypeNineYiEnterPassword:
        {
            return [self generateEnterPasswordEntries];
            break;
        }
        case NYLoginProcessTypeNineYiSetPassword:
        case NYLoginProcessTypeSocialAccountBindingCellPhonSetPassword:
        {
            return [self generateSetPasswordEntriesWithIsOptInOnly:[NYLoginUserDataModel sharedModel].isOptinOnly
                                                 shouldShowProfile:[NYLoginUserDataModel sharedModel].shouldShowProfile];
            break;
            // 您的註冊即將完成 (UI說不確定會不會反悔, 先拔出來)
            // Note: 幾個月後都沒人說就刪掉吧, 連 LanguageTool 一起 (2020/8/7)
            //        @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeRegistrationIsAboutToFinish andContent:@{@"content1":NYLocalizedString(@"login_title_register_almost_complete", nil)}]]
        }
        case NYLoginProcessTypeMemberDirectSetPassword:
        case NYLoginProcessTypeExpressSetPassword:
        {
            return [self generateSetPasswordEntriesWithIsOptInOnly:NO shouldShowProfile:NO];
            break;
        }
        case NYLoginProcessTypeNineYiResetPassword:
        case NYLoginProcessTypeExpressResetPassword:
        {
            NSMutableArray *entry = [NSMutableArray array];
            BOOL shouldActivate = [NYLoginUserDataModel sharedModel].shouldActivate;
            if (shouldActivate) {
                Model *activateTitle = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeActivateTitle andContent:@{@"content1":NYLocalizedString(@"login_title_activate_set_password", nil)}];
                [entry addObject:@[activateTitle]];
            }
            
            [entry addObjectsFromArray:@[
                @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypePasswordSettingTitle andContent:@{@"content1":NYLocalizedString(@"login_title_set_password", nil), @"content2":NYLocalizedString(@"login_title_check_password", nil)}]],
                @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldPassword andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_password_regex_placeholder_password_format", nil),
                                                                                                                @"eyeClickBlock":^{
                    // GA (輸入密碼眼睛icon)
                    // 2021.05.06 拔掉 GA
                }}]],
                @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNineYiActionButton andContent:@{@"cellTitle":NYLocalizedString(@"common_completed", nil)}]]
            ]];
            NSArray *regexDescribeCellDataModels = [self generateRegexDescribeCellDataModels];
            if (regexDescribeCellDataModels.count > 0) {
                [entry insertObject:regexDescribeCellDataModels atIndex:(entry.count - 1)];
            }
            return entry;
            break;
        }
        case NYLoginProcessTypeNineYiISPResetPassword: {
            NSMutableArray *dataModels = [NSMutableArray arrayWithArray:@[
                @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypePasswordSettingTitle andContent:@{@"content1":NYLocalizedString(@"login_title_isp_reset_password", nil)}]],
                @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldPassword andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_password_regex_placeholder_new_password", nil),
                                                                                                                @"eyeClickBlock":^{
                    // GA (輸入密碼眼睛icon)
                    // 2021.05.06 拔掉 GA
                }}]],
                @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNineYiActionButton andContent:@{@"cellTitle":NYLocalizedString(@"common_confirm", nil)}]]]];
            NSArray *regexDescribeCellDataModels = [self generateRegexDescribeCellDataModels];
            if (regexDescribeCellDataModels.count > 0) {
                [dataModels insertObject:regexDescribeCellDataModels atIndex:(dataModels.count - 1)];
            }
            return dataModels;
        }
            break;
        case NYLoginProcessTypeFacebookBingingCellPhone:
        case NYLoginProcessTypeFacebookBingingCellPhoneNotFinish:
            return @[@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeFacebookCellPhoneBindingTitle andContent:@{@"content1":NYLocalizedString(@"login_fb_title_phone_binding", nil)}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldPhoneNumber andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_cellphone", nil)}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeFacebookAction andContent:@{@"cellTitle":NYLocalizedString(@"common_btn_next", nil)}]]];
            break;
        case NYLoginProcessTypeLineLoginBingingCellPhone:
            return @[@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeFacebookCellPhoneBindingTitle andContent:@{@"content1":NYLocalizedString(@"login_fb_title_phone_binding", nil)}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldPhoneNumber andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_cellphone", nil)}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeLineLoginAction andContent:@{@"cellTitle":NYLocalizedString(@"common_btn_next", nil)}]]];
            break;
        case NYLoginProcessTypeThirdpartyBingingCellPhone:
            return @[@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeThirdpartyAuthCellPhoneBindingTitle andContent:@{@"content1":NYLocalizedString(@"login_phone_verify", nil)}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeThirdpartyAuthCellPhoneBindingSubtitle andContent:@{@"content1":NYLocalizedString(@"login_title_will_send_verify_code", nil)}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeThirdpartyAuthTextFieldPhoneNumber andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_cellphone", nil)}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeThirdpartyAuthCellPhoneBindingAction andContent:@{@"cellTitle":NYLocalizedString(@"common_btn_next", nil)}]]];
            break;
        case NYLoginProcessTypeVerifyCodeNineYiRegister:
        case NYLoginProcessTypeVerifyCodeExpressResetPassword:
        case NYLoginProcessTypeVerifyCodeExpressRegister:
        case NYLoginProcessTypeVerifyCodeMemberDirectSetPassword: {
            return [self generateVerifyCodeEntries];
            break;
        }
        case NYLoginProcessTypeVerifyCodeSSOValidatePhoneNumber:
        case NYLoginProcessTypeVerifyCodeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeVerifyCodeSocialAccountBindingCellPhone: {
            return @[@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeCellPhoneTitle andContent:nil]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginTextOnlyCell andContent:@{@"content1":NYLocalizedString(@"login_verify_phone_for_full_function", nil)}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldVerifyCode andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_verify_code", nil), @"icon": @"icon_login_phone"}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNineYiActionButton andContent:@{@"cellTitle":NYLocalizedString(@"member_info_phonenumber_verify_button", nil)}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNotRecevingSMSMessage andContent:nil]]];
            break;
        }
        case NYLoginProcessTypeVerifyCodeNineYiForgetPassword:
            return @[@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeCellPhoneTitle andContent:nil]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldVerifyCode andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_verify_code", nil)}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNineYiActionButton andContent:@{@"cellTitle":NYLocalizedString(@"common_btn_next", nil)}]],
                     @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNotRecevingSMSMessage andContent:nil]]];
            break;
        case NYLoginProcessTypeVerifyCodeThirdpartyRegister: {
            NSMutableArray *entry = [NSMutableArray array];
            [entry addObject:@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeCellPhoneTitle andContent:nil]]];
            
            BOOL shouldActivate = [NYLoginUserDataModel sharedModel].shouldActivate;
            if (shouldActivate) {
                Model *activateTitle = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeActivateTitle andContent:@{@"content1":NYLocalizedString(@"login_title_activate_verify_code", nil)}];
                [entry addObject:@[activateTitle]];
            }
            if ([NYLoginUserDataModel sharedModel].isOptinOnly) {
                [entry addObjectsFromArray:@[
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldVerifyCode andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_verify_code", nil)}]],
                    @[[NYOptInViewModel viewModelWithDefaultEnabled:[NYLoginUserDataModel sharedModel].optin
                                                       isOptInSplit:NO
                                                      fromLoginPage:YES
                                                  isOnlyMemberRight:NO]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeThirdpartyAuthCellPhoneBindingAction andContent:@{@"cellTitle":NYLocalizedString(@"common_completed", nil)}]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNotRecevingSMSMessage andContent:nil]]
                ]];
            } else {
                BOOL hasProfile = [NYLoginUserDataModel sharedModel].shouldShowProfile;
                NSString *btnTitle = hasProfile? NYLocalizedString(@"common_btn_next", nil) : NYLocalizedString(@"common_completed", nil);
                [entry addObjectsFromArray:@[
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldVerifyCode andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_verify_code", nil)}]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeThirdpartyAuthCellPhoneBindingAction andContent:@{@"cellTitle":btnTitle}]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNotRecevingSMSMessage andContent:nil]]
                ]];
            }
            return entry;
            break;
        }
        case NYLoginProcessTypeVerifyCodeFacebookRegister:
        case NYLoginProcessTypeVerifyCodeFacebookRegisterNotFinish: {
            NSMutableArray *entry = [NSMutableArray array];
            [entry addObject:@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeCellPhoneTitle andContent:nil]]];
            
            BOOL shouldActivate = [NYLoginUserDataModel sharedModel].shouldActivate;
            if (shouldActivate) {
                Model *activateTitle = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeActivateTitle andContent:@{@"content1":NYLocalizedString(@"login_title_activate_verify_code", nil)}];
                [entry addObject:@[activateTitle]];
            }
            if ([NYLoginUserDataModel sharedModel].isOptinOnly) {
                [entry addObjectsFromArray:@[
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldVerifyCode andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_verify_code", nil)}]],
                    @[[NYOptInViewModel viewModelWithDefaultEnabled:[NYLoginUserDataModel sharedModel].optin
                                                       isOptInSplit:[NYLoginUserDataModel sharedModel].enableOptInSplit
                                                      fromLoginPage:YES
                                                  isOnlyMemberRight:NO]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeFacebookAction andContent:@{@"cellTitle":NYLocalizedString(@"common_completed", nil)}]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNotRecevingSMSMessage andContent:nil]]
                ]];
            } else {
                BOOL hasProfile = [NYLoginUserDataModel sharedModel].shouldShowProfile;
                NSString *btnTitle = hasProfile? NYLocalizedString(@"common_btn_next", nil) : NYLocalizedString(@"common_completed", nil);
                [entry addObjectsFromArray:@[
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldVerifyCode andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_verify_code", nil)}]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeFacebookAction andContent:@{@"cellTitle":btnTitle}]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNotRecevingSMSMessage andContent:nil]]
                ]];
            }
            return entry;
            break;
        }
        case NYLoginProcessTypeVerifyCodeLineLoginRegister:
        case NYLoginProcessTypeLineLoginExceedSMSLimit:
        {
            NSMutableArray *entry = [NSMutableArray array];
            [entry addObject:@[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeCellPhoneTitle andContent:nil]]];
            
            BOOL shouldActivate = [NYLoginUserDataModel sharedModel].shouldActivate;
            if (shouldActivate) {
                Model *activateTitle = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeActivateTitle andContent:@{@"content1":NYLocalizedString(@"login_title_activate_verify_code", nil)}];
                [entry addObject:@[activateTitle]];
            }
            if ([NYLoginUserDataModel sharedModel].isOptinOnly) {
                [entry addObjectsFromArray:@[
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldVerifyCode andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_verify_code", nil)}]],
                    @[[NYOptInViewModel viewModelWithDefaultEnabled:[NYLoginUserDataModel sharedModel].optin
                                                       isOptInSplit:NO
                                                      fromLoginPage:YES
                                                  isOnlyMemberRight:NO]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeLineLoginAction andContent:@{@"cellTitle":NYLocalizedString(@"common_completed", nil)}]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNotRecevingSMSMessage andContent:nil]]
                ]];
            } else {
                BOOL hasProfile = [NYLoginUserDataModel sharedModel].shouldShowProfile;
                NSString *btnTitle = hasProfile? NYLocalizedString(@"common_btn_next", nil) : NYLocalizedString(@"common_completed", nil);
                [entry addObjectsFromArray:@[
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldVerifyCode andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_verify_code", nil)}]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeLineLoginAction andContent:@{@"cellTitle":btnTitle}]],
                    @[[NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNotRecevingSMSMessage andContent:nil]]
                ]];
            }
            return entry;
            break;
        }
        case NYLoginProcessTypeSocialAccountValidateCellPhone:
        case NYLoginProcessTypeSocialAccountBindingCellPhone: {
            NSMutableArray *entry = [NSMutableArray array];
            
            Model *loginTitle = [NYLoginCellDataModel
                                 cellDataModelWithCellType:NYLoginCellTypeLoginTitle
                                 andContent:@{@"content1":NYLocalizedString(@"member_verify_cell_phone_number", nil)}];
            Model *phoneNumberTextField = [NYLoginCellDataModel
                                            cellDataModelWithCellType:NYLoginCellTypeTextFieldPhoneNumber
                                            andContent:@{@"customPlaceholderString":NYLocalizedString(@"member_info_phonenumber_type_placeholder", nil)}];
            Model *btn = [NYLoginCellDataModel
                          cellDataModelWithCellType:NYLoginCellTypeNineYiActionButton
                          andContent:@{@"cellTitle":NYLocalizedString(@"member_send_sms_verify_code", nil)}];
            [entry addObjectsFromArray:@[@[loginTitle],
                                         @[phoneNumberTextField],
                                         @[btn]
                                         ]];

            if ([NYUserDefault getAntiFraudPreference]) {
                Model *antiFraud = [NYLoginCellDataModel
                                    cellDataModelWithCellType:NYLoginAntiFraudCell andContent:nil];
                NSArray *antiFraudArray = @[antiFraud];
                [entry addObject:antiFraudArray];
            }
            
            return entry;
            break;
        }
        case NYLoginProcessTypeUnknown:
        default:
            return @[];
            break;
    }
}

- (NSArray *)generateRegexDescribeCellDataModels {
    __block NSMutableArray *dataModels = [[NSMutableArray alloc] init];
    [[NYLoginUserDataModel sharedModel].passwordRegexContents enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *describe = [NSString stringWithFormat:@"・%@", obj];
        NSDictionary *content = @{@"content1":describe};
        NYLoginCellDataModel *dataModel = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeRegexDescribeCell andContent:content];
        [dataModels addObject:dataModel];
    }];
    
    return dataModels;
}

#pragma mark 驗證碼登入相關

- (NSArray *)generateVerifyCodeEntries {
    typedef NYLoginCellDataModel Model;
    NSMutableArray *entry = [NSMutableArray array];
    
    // 手機號碼標題
    Model *cellPhoneTitle = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeCellPhoneTitle
                                                                 andContent:nil];
    [entry addObject:@[cellPhoneTitle]];
    
    // 驗證碼輸入欄位
    Model *verifyCodeTextField = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldVerifyCode
                                                                      andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_verify_code", nil)}];
    [entry addObject:@[verifyCodeTextField]];
    
    // 只有驗證碼登入的註冊流程要有
    if (self.flowViewModel.shouldShowOptInOption &&
        self.loginType == NYLoginProcessTypeVerifyCodeExpressRegister) {
        // opt-in 選項
        Model *optInViewModel = [NYOptInViewModel viewModelWithDefaultEnabled:[NYLoginUserDataModel sharedModel].optin
                                                                 isOptInSplit:[NYLoginUserDataModel sharedModel].enableOptInSplit
                                                                fromLoginPage:YES
                                                            isOnlyMemberRight:NO];
        [entry addObject:@[optInViewModel]];
    }
    
    // 確認按鈕
    NSString *title = self.flowViewModel.verificationActionButtonTitle ?: NYLocalizedString(@"common_btn_next", nil);
    Model *actionButton = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNineYiActionButton
                                                               andContent:@{@"cellTitle":title}];
    [entry addObject:@[actionButton]];
    
    // 沒收到簡訊提示
    Model *notReceivingSMS = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNotRecevingSMSMessage
                                                                  andContent:nil];
    [entry addObject:@[notReceivingSMS]];
    
    return entry;
}

- (NSArray *)generateEnterPasswordEntries {
    typedef NYLoginCellDataModel Model;
    NSMutableArray *entry = [NSMutableArray array];
    
    // 手機號碼標題
    Model *cellPhoneTitle = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeCellPhoneTitle
                                                                 andContent:nil];
    [entry addObject:@[cellPhoneTitle]];
    
    // 密碼輸入欄位
    Model *passwordTextField = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldPassword
                                                                    andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_placeholder_password", nil),
                                                                                 @"eyeClickBlock":^{}}];
    [entry addObject:@[passwordTextField]];
    
    // 登入按鈕
    Model *loginButton = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNineYiActionButton
                                                              andContent:@{@"cellTitle":NYLocalizedString(@"login_btn_login", nil)}];
    [entry addObject:@[loginButton]];
    
    // 忘記密碼
    Model *forgetPasswordButton = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeForgetPassword
                                                                         andContent:@{@"content1":NYLocalizedString(@"login_btn_forget_password", nil)}];
    [entry addObject:@[forgetPasswordButton]];
    
    if (self.flowViewModel.shouldShowOTPOption) {
        // 切換到驗證碼登入選項
        Model *switchToOTPLogin = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeEnterPasswordOTPAction
                                                                       andContent:@{@"content1":NYLocalizedString(@"login_btn_use_sms_login", nil)}];
        [entry addObject:@[switchToOTPLogin]];
    }
    
    return entry;
}

- (NSArray *)generateSetPasswordEntriesWithIsOptInOnly:(BOOL)isOptInOnly shouldShowProfile:(BOOL)shouldShowProfile {
    typedef NYLoginCellDataModel Model;
    NSMutableArray *entry = [NSMutableArray array];
    NSString *btnTitle = @"";
    
    // 標題
    Model *title = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypePasswordSettingTitle
                                                        andContent:@{@"content1":NYLocalizedString(@"login_title_set_password", nil), @"content2":NYLocalizedString(@"login_title_check_password", nil)}];
    [entry addObject:@[title]];
    
    // 密碼輸入欄位
    Model *passwordTextField = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeTextFieldPassword
                                                                    andContent:@{@"customPlaceholderString":NYLocalizedString(@"login_password_regex_placeholder_password_format", nil),
                                                                                 @"eyeClickBlock":^{}}];
    [entry addObject:@[passwordTextField]];
    
    // 密碼輸入規則提示
    NSArray *regexDescribeCellDataModels = [self generateRegexDescribeCellDataModels];
    if (regexDescribeCellDataModels.count > 0) {
        [entry addObject:regexDescribeCellDataModels];
    }
    
    if (isOptInOnly) {
        // opt-in 選項
        Model *optInViewModel = [NYOptInViewModel viewModelWithDefaultEnabled:[NYLoginUserDataModel sharedModel].optin
                                                        isOptInSplit:[NYLoginUserDataModel sharedModel].enableOptInSplit
                                                       fromLoginPage:YES
                                                   isOnlyMemberRight:NO];
        [entry addObject:@[optInViewModel]];
        
        // 按鈕標題
        btnTitle = NYLocalizedString(@"common_completed", nil);
        
    } else if (shouldShowProfile) {
        // 按鈕題標
        btnTitle = NYLocalizedString(@"common_btn_next", nil);
    } else {
        // 按鈕標題
        btnTitle = NYLocalizedString(@"common_completed", nil);
    }
    
    // 確認按鈕
    Model *buttonViewModel = [NYLoginCellDataModel cellDataModelWithCellType:NYLoginCellTypeNineYiActionButton
                                                                    andContent:@{@"cellTitle":btnTitle}];
    
    [entry addObject:@[buttonViewModel]];
    
    return entry;
}

#pragma mark -

- (void)setUserCountryWithCountryCode:(NSString *)countryCode countryID:(NSNumber *)countryID countryAliasCode:(NSString *)countryAliasCode {
    self.countryPhoneCode = countryCode;
    self.countryID = countryID;
    self.countryAliasCode = countryAliasCode;
}

//目前只有Login首頁「登入/註冊」有用到
- (void)textFormateCheck:(NSString *)textToBeCheck checkType:(NYLoginTextFieldFormatCheckType)checkType WithWarningMessage:(NSString *)warningMessage AndSuccessCompletion:(void (^)(void))completion {
    NSArray *indexPathes = [self indexPathForTextField];
    
    if (indexPathes.count > 0) {
        [self removeWarningCell];
        
        NSIndexPath *indexPath = [indexPathes firstObject];
        NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        NSString *regex = [self formatRegexPatternForCheckType:checkType];
        if (textToBeCheck && [self validateWithRegexPattern:regex andString:textToBeCheck]) {
            [cell configureTextFieldLayoutWithWarningEffect:NO warningType:NYWarningTypeNone];
            completion ();
        } else {
            if (checkType == NYLoginTextFieldFormatCheckTypePassword) {
                 [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypePassword];
                //Show password
                NYLoginCell *passwordCell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:(NSIndexPath *)[[self indexPathForTextField] firstObject]];
                [passwordCell showSecureText];
            } else {
                 [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeCellPhone];
            }
            
            [self insertWaringCellAfterIndexPath:indexPath withWariningMessage:warningMessage];
        }
    }
}

- (void)checkIsValidWithCellPhone:(NSString *)cellPhone
                 countryAliasCode:(NSString *)countryAliasCode
                successCompletion:(void (^)(void))successCompletion {
    __weak typeof(self) weakSelf = self;
    [NYProgressHUD showHUDAddedToView:weakSelf.view];
    NSString *nonnullCellPhoneString = cellPhone ?: @"";
    NSString *nonnullCountryAliasCodeString = countryAliasCode ?: @"";
    [NYDataProvider.sharedInstance checkIsValidWithCellPhone:nonnullCellPhoneString
                                            countryAliasCode:nonnullCountryAliasCodeString
                                           completionHandler:^(NSDictionary * _Nullable data, NSError * _Nullable error) {
        [NYProgressHUD hideAllHUDsForView:weakSelf.view];
        NSArray *indexPathes = [weakSelf indexPathForTextField];
        [weakSelf removeWarningCell];
        NSIndexPath *indexPath = [indexPathes firstObject];
        NYLoginCell *cell = (NYLoginCell *)[weakSelf.collectionView cellForItemAtIndexPath:indexPath];

        if (error) {
            [weakSelf displayNoNetworkAlertWithReloadCompletion:^{
                [weakSelf checkIsValidWithCellPhone:cellPhone countryAliasCode:countryAliasCode successCompletion:successCompletion];
            }];
        } else {
            NSString *returnCode = data[kDATA_KEY][@"ReturnCode"];
            NSString *message = data[kDATA_KEY][@"Message"];
            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICellPhoneIsValid]) {
                [cell configureTextFieldLayoutWithWarningEffect:NO warningType:NYWarningTypeNone];
                successCompletion();
            } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPICellPhoneIsNotValid]) {
                [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeCellPhone];
                [weakSelf insertWaringCellAfterIndexPath:indexPath withWariningMessage:message];
            }
        }
    }];
}

- (void)textFormatCheck:(NSString *)textToBeCheck cellType:(NYLoginCellType)cellType WithWarningMessage:(NSString *)warningMessage AndSuccessCompletion:(void (^)(void))completion {
    NSArray *indexPathes = [self indexPathForTextField];
    if (indexPathes.count > 0) {
        [self removeWarningCell];
        
        NSIndexPath *indexPath = [self indexPathForCellType:cellType];
        NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        
        NSString *regex = [self formatRegexPatternForCheckType:NYLoginTextFieldFormatCheckTypeThirdPartyAuth];
        if (textToBeCheck && [self validateWithRegexPattern:regex andString:textToBeCheck]) {
            [cell configureTextFieldLayoutWithWarningEffect:NO warningType:NYWarningTypeNone];
            completion ();
        } else {
            [cell configureTextFieldLayoutWithWarningEffect:YES warningType:NYWarningTypeCellPhone];
            [self insertWaringCellAfterIndexPath:indexPath withWariningMessage:warningMessage];
        }
    }
}

- (NSString *)formatRegexPatternForCheckType:(NYLoginTextFieldFormatCheckType)type {
    switch (type) {
        case NYLoginTextFieldFormatCheckTypePassword:
            return [NYLoginUserDataModel sharedModel].passwordRegex;
            break;
        case NYLoginTextFieldFormatCheckTypeVerifyCode:
            return @"^[0-9]{4}$";
            break;
        case NYLoginTextFieldFormatCheckTypeThirdPartyAuth:
        case NYLoginTextFieldFormatCheckTypeNoCheck:
            return @".+";
        default:
            return nil;
            break;
    }
}

- (BOOL)validateWithRegexPattern:(NSString *)regex andString:(NSString *)string {
    NSPredicate *regexPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    //傳回YES或NO
    return [regexPredicate evaluateWithObject:string];
}

- (NSString *)apiReturnCodeForReturnData:(NSDictionary *)returnData {
    return returnData[kDATA_KEY][@"ReturnCode"];
}

- (NSString *)apiReturnMessageForReturnData:(NSDictionary *)returnData {
    return returnData[kDATA_KEY][@"Message"];
}

///沒收到簡訊, 在x秒前不可以使用的倒數計時
- (void)countDownNotRecevingSMS:(NSInteger)count {
    //Check count
    if (count >= 1) {
        NSIndexPath *indexPath = [self indexPathForCellType:NYLoginCellTypeNotRecevingSMSMessage];
        NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        [cell setNotRecevingSMSCountDownString:[NSString stringWithFormat:NYLocalizedString(@"login_not_receive_sms_countdown", nil), count] enabled:NO];
        
        //Recursive calling
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            //Count down
            [weakSelf countDownNotRecevingSMS:count - 1];
        });
    } else {
        //Finish
        NSIndexPath *indexPath = [self indexPathForCellType:NYLoginCellTypeNotRecevingSMSMessage];
        NYLoginCell *cell = (NYLoginCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        [cell setNotRecevingSMSCountDownString:NYLocalizedString(@"login_btn_not_receive_sms", nil) enabled:YES];
        
        self.enableNotReceivingSMSFlag = YES;
    }
}

+ (void)commonActionAfterLoginSuccess {
    [[NYReferrerBindingLinkInjectionHelper shared] cleanStoredReferrerInfo];
    [[NYStatisticHelper sharedHelper] setEmarsysContact];
}

- (void)updateCellPhone:(void(^)(void))completion {
    __weak typeof(self) weakSelf = self;

    // 手機驗證結束更新品牌會員編號
    [[NYDataProvider sharedInstance] getVIPInfoWithShopID:[NYGlobalData shopId]
                                                isBinding:[NYUserDefault shouldEnableLocationMember]
                                        completionHandler:^(NSString *returnCode, NSString *message, NSDictionary *data, NSError *error) {
        if (error) {
            return;
        }
        
        NSString *ouid = NILIFY(data[@"VipMember"][@"OuterId"]);
        [NYUserDefault setOuterMemberId:ouid];
    }];
    
    [[NYLoginHelper sharedInstance] updateCellPhoneWithCellPhone:[NYLoginUserDataModel sharedModel].cellPhone
                                                     countryCode:weakSelf.countryPhoneCode
                                                       countryID:weakSelf.countryID
                                                countryAliasCode:weakSelf.countryAliasCode
                                               completionHandler:^(NSDictionary *data, NSError *error) {
        if (error) {
            [weakSelf ny_displayAlertWithTitle:NYLocalizedString(@"common_alert_system_is_busy", nil) message:nil];
            return;
        }
        
        if (completion) {
            completion();
        }
    }];
}

#pragma mark Alert

- (void)displayNoNetworkAlertWithReloadCompletion:(void (^)(void))completion {
    //Connection error alert
    [self ny_displayBadNetworkWithReloadBlock:completion cancelBlock:nil];
}

- (void)displayAlertMessage:(NSString *)message {
    [self ny_displayAlertWithTitle:nil message:message];
}

- (void)displayAlertTitle:(NSString *)title messageAndBackToRoot:(NSString *)message {
    __weak typeof(self) weakSelf = self;
    [self ny_displayAlertWithTitle:title message:message cancelButtonTitle:NYLocalizedString(@"common_confirm", nil) onDismiss:^{
        [weakSelf.navigationController popToRootViewControllerAnimated:YES];
    }];
}

#pragma mark AdBanner

//這邊是用Top constraint把東西超出範圍, 導致看不見而已
- (void)showAdBanner {
    if ([self indexPathForCellType:NYLoginCellTypeLoginAdBanner]) {
        [UIView animateWithDuration:0.35 animations:^{
            self.collectionViewTopConstraint.constant = 0;
            [self.collectionView.superview layoutIfNeeded];
        }];
    }
}

- (void)hideAdBanner {
    NSIndexPath *indexPath = [self indexPathForCellType:NYLoginCellTypeLoginAdBanner];
    if (indexPath) {
        [UIView animateWithDuration:0.35 animations:^{
            NYLoginCellDataModel *cellDataModel = self.entries[indexPath.section][indexPath.row];
            self.collectionViewTopConstraint.constant = -cellDataModel.cellSize.height;
            [self.collectionView.superview layoutIfNeeded];
        }];
    }
}

#pragma mark Tracking
- (void)setEventUserInfoWithPhone:(NSString *)phoneNumber {
    NSString *completePhoneNumber = [[NYMemberHelper shareInstance] formatPhoneNumberWithCountryCode:self.countryPhoneCode phoneNumber:phoneNumber];
    [[NYStatisticHelper sharedHelper] setPhoneNumber:completePhoneNumber];
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView.isDragging) {
        [self.view endEditing:YES];
    }
}

#pragma mark - UICollectionViewDataSource
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.entries.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.entries[section] count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    id dataModel = self.entries[indexPath.section][indexPath.row];
    if ([dataModel isKindOfClass:[NYOptInViewModel class]]) {
        // 活動推播
        NYOptInViewModel *viewModel = dataModel;
        NYOptInCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:viewModel.cellIdentifier forIndexPath:indexPath];
        [cell setContentWith:viewModel];
        cell.delegate = self;
        return cell;
    }
    
    NYLoginCellDataModel *cellDataModel = self.entries[indexPath.section][indexPath.row];
    NYLoginCell *cell = (NYLoginCell *)[collectionView dequeueReusableCellWithReuseIdentifier:cellDataModel.cellIdentifier forIndexPath:indexPath];
    cell.dataModel = cellDataModel;
    cell.parentVC = self;
    
    if (cellDataModel.cellType == NYLoginCellTypeCellPhoneTitle) {
        [cell setContentWithCountryCode:self.countryPhoneCode];
    } else {
        [cell setupContent];
    }
    
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NYLoginCellDataModel *cellDataModel = self.entries[indexPath.section][indexPath.row];
    switch (cellDataModel.cellType) {
        case NYLoginCellTypeLoginAdBanner:
            if (cellDataModel.cellContent[@"SpLoginAdMobile"]) {
                //推頁
                NYADElementObject *adObj = cellDataModel.cellContent[@"SpLoginAdMobile"];
                if (adObj.targetType == TargetTypeCustom) {
                    //推WebView & enable from ADBanner flag
                    UIViewController *webVC = [NYLoginViewController webViewCreator](adObj.link);
                    [self.navigationController pushViewController:webVC animated:YES];
                }
                else {
                    //Dismiss後推頁
                    [self dismissSelfWithCustomExtraCompletionBlock:^{
                        [[NYNotificationHelper sharedInstance] handleADElementObject:adObj];
                    }];
                }
            }
            break;
        case NYLoginCellTypeShowPhoneLoginText:
            [self changeLoginStyle];
            break;
        case NYLoginCellTypeNineYiActionButton:
            [self actionForNineYiActionButton];
            break;
        case NYLoginCellTypeFacebookLogin:
            [self actionForLoginViaFacebookAtLoginProcessLogin];
            break;
        case NYLoginCellTypeThirdpartyAuthLoginButtonCell:
            [self actionForThirdpartyAuthActionButton];
            break;
        case NYLoginCellTypeNotRecevingSMSMessage:
            //倒數結束前, 沒收到簡訊不可以按
            if (self.enableNotReceivingSMSFlag) {
                [self actionForNotRecevingSMSMessage];
            }
            break;
        case NYLoginCellTypeFacebookAction:
        case NYLoginCellTypeAppleSignInAction:
        case NYLoginCellTypeLineLoginAction:
            [self actionForFBAndLineLoginActionButton];
            break;
        case NYLoginCellTypeThirdpartyAuthCellPhoneBindingAction:
            [self actionForThirdpartyAuthCellPhoneBindingAction];
            break;
        case NYLoginCellTypeForgetPassword:
            [self actionForForgetPassword];
            break;
        case NYLoginCellTypeAnnoucementServiceInstruction:
        {
            // 2.10.5 會員權益聲明
            NSString *pathString = @"V2/MyAccount/VipMemberBenefits";
            NSString *domainString = [NYBaseURLConfig baseHTTPSURLWithAppServiceWebPageDomain].absoluteString;
            NSString *urlString = [NSString stringWithFormat:@"%@/%@", domainString, pathString];
            NSURL *targetURL = [NSURL URLWithString:urlString];
            UIViewController *vc = [NYLoginViewController webViewCreator](targetURL);
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
        case NYLoginCellTypeAnnoucementPrivacy:
        {
            // Create URL
            NSString *pathString = @"MyAccount/AppPrivacy";
            NSString *domainString = [NYBaseURLConfig baseHTTPSURLWithAppServiceWebPageDomain].absoluteString;
            NSString *urlString = [NSString stringWithFormat:@"%@/%@?shopId=%@", domainString, pathString, [NYGlobalData shopId]];
            NSURL *targetURL = [NSURL URLWithString:urlString];
            
            //隱私權說明
            UIViewController *vc = [NYLoginViewController webViewCreator](targetURL);
            [self.navigationController pushViewController:vc animated:YES];
        }
            break;
        case NYLoginAppleSignInCell:
        {
            [self handleAppleSignInCellPress];
            break;
        }
        case NYLoginCellTypeLineLogin:
        {
            [self handleLineLoginCellPress];
            break;
        }
        case NYLoginCellTypeEnterPasswordOTPAction:
        {
            [self handleSwitchOTPAction];
            break;
        }
            break;
        default:
            break;
    }
}

#pragma mark - UICollectionViewDelegateFlowLayout
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    NYLoginCellDataModel *cellDataModel = self.entries[indexPath.section][indexPath.row];
    return cellDataModel.cellSize;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0f;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 0.0f;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    NYLoginCellDataModel *cellDataModel = [self.entries[section] firstObject];
    if (cellDataModel.cellType == NYLoginCellTypeAnnoucementPrefix) {
        return UIEdgeInsetsMake(12.0f, 0.0, 0.0f, 0.0f);
    } else if (cellDataModel.cellType == NYLoginCellTypeAnnoucementServiceInstruction) {
        // Calculate proper left space
        __block CGFloat totalWidth = 0.0;
        [self.entries[section] enumerateObjectsUsingBlock:^(NYLoginCellDataModel * _Nonnull model, NSUInteger idx, BOOL * _Nonnull stop) {
            totalWidth += model.cellSize.width;
        }];
        
        CGFloat screenWidth = CGRectGetWidth([UIScreen mainScreen].bounds);
        CGFloat leftSpace = floor((screenWidth - totalWidth) / 2.0);
        
        return UIEdgeInsetsMake(0.0, leftSpace, 4.0, 0.0);
    } else if (cellDataModel.cellType == NYLoginCellTypeLoginAdBanner) {
        return UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    } else if (cellDataModel.cellType == NYLoginCellTypeCellPhoneTitle) {
        return UIEdgeInsetsMake(16.0, 0.0, 8.0, 0.0);
    } else {
        return UIEdgeInsetsMake(4.0f, 0.0f, 4.0f, 0.0f);
    }
}

#pragma mark - NYLoginAutoGetCouponAlertViewDelegate
- (void)confirmAutoGetCouponAlert {
    [_alertPresenter dismissAlert];
    NYLoginVCInfo *info = [NYLoginVCInfo sharedInfo];
    [NYProgressHUD showSuccessMessage:NYLocalizedString(@"login_success", nil) toView:info.waitingForLoginVC.view duration:2.0];

    [NYUserDefault setLastLoginVersion:[NYGlobalData appVersionString]];

    [info.waitingForLoginVC hideUnLoginView];
    if (info.dismissCompletion) {
        info.dismissCompletion();
        
        [info finishLoginWithCompletionReset:NO];
    } else {
        [self dismissViewControllerAnimated:YES completion:^{
            [info finishLoginWithCompletionReset:NO];
        }];
    }
    self.isNormallyClosed = YES;

    [[NSNotificationCenter defaultCenter] postNotificationName:@"NYDismissLoginViewControllerNotification" object:nil];
}

#pragma mark - NYOptInCellDelegate
- (void)optInCell:(NYOptInCell *)cell enableDidClickWith:(NYOptInViewModel *)viewModel {
    [NYLoginUserDataModel sharedModel].optin = viewModel.isBasicOpt;
    [NYLoginUserDataModel sharedModel].isEnableEDM = viewModel.isEdmOpt;
    [NYLoginUserDataModel sharedModel].isEnableEdmSMS = viewModel.isEdmSMSOpt;
    [NYLoginUserDataModel sharedModel].isAppPushProfile = viewModel.isAppOpt;
}

@end
//
//  NYThirdPartyLoginWebBrowserVC.m
//  Pods
//
//  Created by Eric Huang on 2018/4/18.
//

#import <NYCore/NYCore-Swift.h>
#import "NYThirdPartyLoginWebBrowserVC.h"
#import "NYLoginVCInfo.h"
#import "NYLoginUserDataModel.h"

#import <NYCore/NYDataProvider+Login.h>
#import <NYCore/NYLoginHelper.h>
#import <NYCore/NYUserDefault.h>
#import <NYCore/UIColor+ThemeColor.h>
#import <NYCore/NSBundle+PodsBundle.h>
#import <NYCore/UIViewController+NYAlertControllerHelper.h>
#import <NYCore/NYLocalizationString.h>
#import <NYCore/NYProgressHUD.h>
#import <NYCore/NYStatisticHelper.h>
#import <NYCore/NYAlertPresenter.h>
#import <WebKit/WebKit.h>
#import <NYIcon/NYIcon-Swift.h>
#import <NYCore/NSString+Regex.h>

/*
 Note:
 理想上是用 WKWebViewController
 這邊先不這樣使用, 因為先 dependency & 太多需要 internal 的 properties 的問題.
 應該要先等 Login 改版後再來處理比較適當.
 */

/*
 Note:
 目前 hk 有逾時跳轉的導頁邏輯仍走 WKWebView，導致行為不符合預期
 未來登入重構時，請將 WKWebView -> NYWKWebView，否則不會走原生導頁
 */

@interface NYThirdPartyLoginWebBrowserVC () <WKNavigationDelegate, WKUIDelegate>

@property (nonatomic, strong) WKWebView *webView; // TODO: WKWebView 改為 NYWKWebView
@property (nonatomic, strong) NSURL *oAuthStartURL; // 舊官網登入用
@property (nonatomic, assign) BOOL needsRedirectAfterLogin;
@property (nonatomic, assign) BOOL isLoginThirdPartyMember;
@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) void(^completionBlock)(void);
@property (nonatomic, strong) SSOLoadingView *ssoLoadingView;
@property (nonatomic, assign) BOOL isThirdPartyNewRegistered; // 用來識別第三方登入的使用者是新註冊or舊會員

@end

@implementation NYThirdPartyLoginWebBrowserVC

+ (instancetype)viewController {
    NYThirdPartyLoginWebBrowserVC *vc = [[NYThirdPartyLoginWebBrowserVC alloc] initWithNibName:NSStringFromClass(self.class)
                                                                                        bundle:[NSBundle nyBundleWithNYLoginViewController]];
    
    return vc;
}

+ (instancetype)viewControllerWithOAuthURL:(NSURL *)oAuthURL {
    NYThirdPartyLoginWebBrowserVC *vc = [NYThirdPartyLoginWebBrowserVC viewController];
    vc.oAuthStartURL = oAuthURL;
    return vc;
}

+ (instancetype)viewControllerWithThirdPartyToken:(NSString *)token loginSuccessCompletionBlock:(void (^)(void))completionBlock {
    NYThirdPartyLoginWebBrowserVC *vc = [NYThirdPartyLoginWebBrowserVC viewController];
    vc.needsRedirectAfterLogin = YES;
    vc.completionBlock = completionBlock;
    vc.token = token;
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    self.alertPresenter = [[NYAlertPresenter alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
    // (2021/3) 本來是修 PX iOS 12 的 bug，但目前 Tokuyo 也反應偶發無限登入問題，因此把版本判斷拿掉
    if ([NYLoginHelper sharedInstance].isLogin) {
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    
    [super viewWillAppear:animated];

    // Config dismiss button
    [self configureNavigationItems];

    // Tracking
    [[NYStatisticHelper sharedHelper] sendPageName:@"Login" title:nil pageId:nil];

    // Process login with token first or fetch URL if needed
    if (self.needsRedirectAfterLogin) {
        [self processSSOLoginWithToken:self.token];
        
    } else if (self.oAuthStartURL) {
        // 舊官網第三方登入
        // Setup WebView
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:self.oAuthStartURL];
        [self setupWKWebView];
        [self.webView loadRequest:request];

    } else {
        // 全家型的第三方登入
        [self processThirdPartyLogin];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // 避免 runJavaScriptAlert function 沒有 call back 導致 crash
    self.webView.UIDelegate = nil;
}

- (void)processThirdPartyLogin {
    typedef void (^Completion)(BOOL isThirdPartyAppSSOEnabled);
    Completion completion = ^void(BOOL isThirdPartyAppSSOEnabled) {
        [NYThirdPartySSOHelper shared].isThirdPartyAppSSOEnabled = isThirdPartyAppSSOEnabled;
        [NYUserDefault setSSOEnabled:isThirdPartyAppSSOEnabled];
        [self getShopThirdpartyAuthInfo];
        if (self.needsRedirectAfterLogin == NO
            && [[NYThirdPartySSOHelper shared] shouldRedirectToThirdPartySSO]
            && isThirdPartyAppSSOEnabled) {
            // SSO 前再次確認是否已登入 (iOS 12.X, 14.0 容易發生誤判)
            if ([NYLoginHelper sharedInstance].isLogin) {
                [self dismissViewControllerAnimated:NO completion:nil];
            } else {
                [self redirectToThirdPartySSO];
            }
        }
    };
    [self updateSSORuntimeConfigWithCompletion:completion];
}

- (void)updateSSORuntimeConfigWithCompletion:(void (^)(BOOL))completion {
    [NYGraphQLHelper
    thirdPartyTogglesWithShopId:[NYGlobalData shopId]
    appVer:[NYGlobalData appVersionString]
    completion:^(NSDictionary *rawData, NSError *error) {
        NSDictionary *welcomePageDict = rawData[@"data"][@"login"];
        NSDictionary *shopStaticSetting = welcomePageDict[@"thirdPartyToggles"];
        if (shopStaticSetting) {
            BOOL isThirdPartyAppSSOEnabled = [shopStaticSetting[@"isThirdPartyAppSSOEnabled"] boolValue];
            completion(isThirdPartyAppSSOEnabled);
        } else {
            completion(NO);
        }
    }];
}

- (void)processSSOLoginWithToken:(NSString *)ssoToken {
    [self showSSOLoadingView];
    [self getThirdpartyMemberRegisterStatusWithToken:ssoToken];
}

- (void)redirectToThirdPartySSO {
    NSURL *url = [[NYThirdPartySSOHelper shared] getSsoRedirectUrl];
    [[NYThirdPartySSOHelper shared] hasRedirectedOut];
    if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url
                                           options:@{}
                                 completionHandler:nil];
    }
}

- (void)getShopThirdpartyAuthInfo {
    __weak typeof(self) weakSelf = self;
    [[NYDataProvider sharedInstance]
     getShopThirdpartyAuthInfoWithShopId:[NYGlobalData shopId]
     device:@"Mobile"
     completionHandler:^(NSDictionary *data, NSError *error) {
        NSURLRequest *request = [self createRequestByAppendingInternalQuery:[NSURL URLWithString:data[kNYDataKey][@"Data"][@"ThirdPartyOAuthUrl"]]];
        
        // set cookies
        NSDictionary *properties = @{NSHTTPCookieValue: @"false",
                                     NSHTTPCookieName: @"isDisplayHeader",
                                     NSHTTPCookiePath: @"/",
                                     NSHTTPCookieDomain: request.URL.host ? : @""};
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:properties];
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];

        // Setup WebView
        [weakSelf setupWKWebView];
        [weakSelf.webView loadRequest:request];
     }];
}

- (void)getThirdpartyMemberRegisterStatusWithToken:(NSString *)token {
    __weak typeof(self) weakSelf = self;
    if (!weakSelf.needsRedirectAfterLogin) {
        [NYProgressHUD showHUDAddedToView:weakSelf.view];
    }
    [[NYDataProvider sharedInstance]
     getThirdpartyMemberRegisterStatusWithTokenWithAccessToken:token ShopId:[NYGlobalData shopId] completionHandler:^(NSDictionary *data, NSError *error) {
        if (!weakSelf.needsRedirectAfterLogin) {
            [NYProgressHUD hideAllHUDsForView:weakSelf.view];
        }

        if (error) {
            [weakSelf dismissSSOLoadingViewIfNeeded];
            [weakSelf ny_displayBadNetworkWithReloadBlock:^{
                [weakSelf getShopThirdpartyAuthInfo];
            } cancelBlock:nil];
        } else {
            NSString *returnCode = data[kDATA_KEY][@"ReturnCode"];
            NSString *message = data[kDATA_KEY][@"Message"];
            
            NSDictionary *dataDict = data[kNYDataKey][@"Data"];
            self.isThirdPartyNewRegistered = [dataDict[@"IsThirdPartyNewRegistered"] boolValue];
            NSString *thirdPartyToken = dataDict[@"authSessionToken"];
            if (thirdPartyToken.length > 0) {
                [[NYLoginUserDataModel sharedModel] setThirdpartyToken:thirdPartyToken];
            }
            
            // kNYAPIGetThirdpartyMemberRegisterStatusWithTokenRegistered
            if ([returnCode isEqualToString:@"API3241"]) {
                [weakSelf loginThirdpartyMember];
            }
            // 任何意外都用這套，顯示 message & 重新 load 頁面
            else {
                [weakSelf dismissSSOLoadingViewIfNeeded];
                [weakSelf ny_displayAlertWithTitle:nil message:message];
                [weakSelf getShopThirdpartyAuthInfo];
            }
        }
    }];
}

- (void)loginThirdpartyMember {
    // Will be called many times.
    // Add flag check yo prevent login flow smoothly.
    if (self.isLoginThirdPartyMember)
        return;
    self.isLoginThirdPartyMember = YES;
    
    if (!self.needsRedirectAfterLogin) {
        [NYProgressHUD showHUDAddedToView:self.view];
    }
    
    // TODO: 若國際有第三方登入也要處理
    // Thirdparty member login 拿不到 countryList 用預設值台灣代替
    NSString *countryCode = @"886";
    NSNumber *countryID = @1;
    
    __weak typeof(self) weakSelf = self;
    [[NYLoginHelper sharedInstance]
     loginThirdpartyMemberWithAuthSessionToken:[[NYLoginUserDataModel sharedModel] thirdpartyToken]
     shopId:[NYGlobalData shopId]
     source:@"iOSApp"
     device:@"Mobile"
     appVersion:[NYGlobalData appVersionString]
     countryCode:countryCode
     countryID:countryID
     completionHandler:^(NSDictionary *data, NSError *error) {
        if (!weakSelf.needsRedirectAfterLogin) {
            [NYProgressHUD hideAllHUDsForView:weakSelf.view];
        }
        
        if (error) {
            weakSelf.isLoginThirdPartyMember = NO; // reset if error
            
            [weakSelf dismissSSOLoadingViewIfNeeded];
            [weakSelf ny_displayBadNetworkWithReloadBlock:^{
                [weakSelf loginThirdpartyMember];
            } cancelBlock:nil];
        } else {
            NSString *returnCode = data[kDATA_KEY][@"ReturnCode"];
            NSString *message = data[kDATA_KEY][@"Message"];
            
            //kNYAPILoginThirdpartyMemberSuccess
            if ([returnCode isEqualToString:@"API3251"]) {
                [weakSelf dismissSelfFromPresentingAfterLoginSuccess];
                [NYLoginViewController commonActionAfterLoginSuccess];
                [weakSelf sendStatisticEvent];
                [weakSelf dismissSSOLoadingViewIfNeeded];
                if (weakSelf.completionBlock) {
                    weakSelf.completionBlock();
                }
                [[LoginInjectionHelper shared] syncServingLocationIfNeeded];
            }
            // 任何意外都用這套，顯示 message & 重新 load 頁面
            else {
                [weakSelf dismissSSOLoadingViewIfNeeded];
                [weakSelf ny_displayAlertWithTitle:nil message:message];
                [weakSelf getShopThirdpartyAuthInfo];
            }
        }
     }];
}

- (void)showSSOLoadingView {
    if (self.ssoLoadingView) {
        [self.ssoLoadingView removeFromSuperview];
        self.ssoLoadingView = nil;
    }
    [self.navigationItem.rightBarButtonItem setEnabled:NO];
    self.ssoLoadingView = [[SSOLoadingView alloc] initWithFrame: self.view.bounds];
    [self.ssoLoadingView startAnimation];
    [self.view addSubview:self.ssoLoadingView];
}

- (void)dismissSSOLoadingViewIfNeeded {
    if (!self.ssoLoadingView) {
        return;
    }
    [[NYThirdPartySSOHelper shared] clear];
    [self.navigationItem.rightBarButtonItem setEnabled:YES];
    [self.ssoLoadingView stopAnimation];
    [self.ssoLoadingView removeFromSuperview];
    self.ssoLoadingView = nil;
    self.needsRedirectAfterLogin = NO;
}

- (void)sendStatisticEvent {
    if (self.isThirdPartyNewRegistered) {
        // FA, tracking
        [[NYStatisticHelper sharedHelper] sendEventSignUpWithMethod:kFAParamSignupLoginMethodShopAccount
                                                             status:kFAParamSignupLoginStatusFinish
                                                           duration:nil];
    } else {
        // FA, tracking
        [[NYStatisticHelper sharedHelper] sendEventLoginWithMethod:kFAParamSignupLoginMethodShopAccount
                                                            status:kFAParamSignupLoginStatusFinish
                                                          duration:nil];
    }
}

#pragma mark - Dismiss

- (void)configureNavigationItems {
    // 強制登入不給右上角的按鈕
    if ([NYCountryConfig isNeedLoginToUseAppIn:[NYGlobalData countryCode]]) {
        return;
    }

    UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spaceItem.width = -11.0f;
    UIBarButtonItem *dismiss = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismissSelfFromPresentingByUser)];

    if ([NYLoginVCInfo sharedInfo].dismissButtonImageName) {
        UIButton *dismissButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 40.0f, 40.0f)];
        [dismissButton setImage:[[UIImage iconWith:[NYLoginVCInfo sharedInfo].dismissButtonImageName size:24] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        UIColor *dismissBtnColor = [[NYCMSThemeEngine sharedInstance] subColor] ?: [UIColor iconCommonWebViewCloseTintColor];
        [dismissButton setTintColor:dismissBtnColor];
        [dismissButton addTarget:self action:@selector(dismissSelfFromPresentingByUser) forControlEvents:UIControlEventTouchUpInside];

        dismiss = [[UIBarButtonItem alloc] initWithCustomView:dismissButton];
        self.navigationItem.rightBarButtonItems = @[spaceItem, dismiss];
    }

    self.navigationItem.rightBarButtonItem = dismiss;
}

- (void)dismissSelfFromPresentingByUser {
    [self.view endEditing:YES];
    NYLoginVCInfo *info = [NYLoginVCInfo sharedInfo];
    if (info.shouldShowUnloginMask) {
        [info.waitingForLoginVC displayUnloginView];
    }
    [info clearInfo];
    if (info.dismissCompletion) {
        info.dismissCompletion();
    } else {
        [self dismissViewControllerAnimated:YES completion:^{
            
        }];
    }
}

#pragma mark - WK
#pragma mark UIDelegate

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    // Load request without create new window
    [webView loadRequest:navigationAction.request];
    return nil;
}

// Note: 以下三個Method必須要實作才會有作用
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    // Create native alert
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];

    NSString *confirmStr = NYLocalizedString(@"common_confirm", nil);
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:confirmStr style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (completionHandler) {
            completionHandler();
        }
    }];
    [alert addAction:confirmAction];

    // Present
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    // Create native confirm
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];

    NSString *confirmStr = NYLocalizedString(@"common_confirm", nil);
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:confirmStr style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (completionHandler) {
            completionHandler(YES);
        }
    }];
    [alert addAction:confirmAction];

    NSString *cancelStr = NYLocalizedString(@"common_cancel", nil);
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelStr style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (completionHandler) {
            completionHandler(NO);
        }
    }];
    [alert addAction:cancelAction];

    // Present
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler {
    // Create native prompt
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:prompt preferredStyle:UIAlertControllerStyleAlert];

    NSString *confirmStr = NYLocalizedString(@"common_confirm", nil);
    __weak UIAlertController *weakAlert = alert;
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:confirmStr style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = weakAlert.textFields.firstObject;
        if (completionHandler && textField) {
            completionHandler(textField.text);
        }
    }];
    [alert addAction:confirmAction];

    NSString *cancelStr = NYLocalizedString(@"common_cancel", nil);
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelStr style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (completionHandler) {
            completionHandler(nil);
        }
    }];
    [alert addAction:cancelAction];

    // Present
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark NavigationDelegate

- (NSString *)extractAccessToken:(NSString *)fragment {
    if (!fragment) return nil;
    
    NSString *pattern = @"access_token=([^&]*)";
    NSArray *matches = [fragment matchesWithPattern:pattern];
    return matches.firstObject;
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {

    NSURLRequest *request = navigationAction.request;
    NSString *urlPath = request.URL.path.lowercaseString;
    if ([self isExcludedLoadingPatternWithPath:urlPath]) {
        [NYProgressHUD hideAllHUDsForView:self.view];
        decisionHandler(WKNavigationActionPolicyAllow);
    } else if ([urlPath isEqualToString:@"/v2/login/thirdpartybasedoauthsuccess"]) {
        NSString *accessToken = [self extractAccessToken:request.URL.fragment];
        if (accessToken) {
            [[NYLoginUserDataModel sharedModel] setAccessToken:accessToken];
        }

        // Check status
        [self getThirdpartyMemberRegisterStatusWithToken:accessToken];

        // Cancel
        [NYProgressHUD hideAllHUDsForView:self.view];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else if ([urlPath isEqualToString:@"/v2/login/thirdpartyoauthsuccess"]) {
        NSString *accessToken = [self extractAccessToken:request.URL.fragment];
        if (accessToken) {
            [[NYLoginUserDataModel sharedModel] setAccessToken:accessToken];
        }
        [self.navigationController popViewControllerAnimated:YES];

        // Cancel
        [NYProgressHUD hideAllHUDsForView:self.view];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        // Load
        if ([NYUserDefault isLoadingViewEnable]){
            [NYProgressHUD showHUDAddedToView:self.view];
        }
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // Hide all loading
    [NYProgressHUD hideAllHUDsForView:self.view];

    // Setup title
    self.title = webView.title;
}

#pragma mark - WK Helper

- (void)setupWKWebView {
    // Remove Old WebView
    [self.webView removeFromSuperview];

    // Create WebView & Add
    self.webView = [self createWebView];
    self.webView.frame = self.view.bounds;
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    [self.view addSubview:_webView];
}

- (WKWebView *)createWebView {
    // Note: 確保每次的 Cookies 都是清空全新的, 不共用
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;

    // Setup Cookies
    WKHTTPCookieStore *wkCookieStore = config.websiteDataStore.httpCookieStore;
    [NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull cookie, NSUInteger idx, BOOL * _Nonnull stop) {
        [wkCookieStore setCookie:cookie completionHandler:nil];
    }];

    // Setup Insets
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero
                                            configuration:config];
    webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;

    if (@available(iOS 16.4, *)) {
        webView.inspectable = YES;
    } else {
        // Fallback on earlier versions
    }

    return webView;
}

#pragma mark - NYLoginAutoGetCouponAlertViewDelegate
- (void)confirmAutoGetCouponAlert {
    [_alertPresenter dismissAlert];
    NYLoginVCInfo *info = [NYLoginVCInfo sharedInfo];
    [NYProgressHUD showSuccessMessage:NYLocalizedString(@"login_success", nil) toView:info.waitingForLoginVC.view duration:2.0];

    [NYUserDefault setLastLoginVersion:[NYGlobalData appVersionString]];

    [info.waitingForLoginVC hideUnLoginView];
    if (info.dismissCompletion) {
        info.dismissCompletion();
        
        [info finishLoginWithCompletionReset:NO];
    } else {
        [self dismissViewControllerAnimated:YES completion:^{
            /* 寶雅的第三方登入有可能重複觸發 getThirdpartyMemberRegisterStatusWithToken 的流程，進而導致 loginCompletion 也重複呼叫
             但 NYMemberV2ViewController 在接 completion 的地方使用 Task (concurrency)，可能在不同 thread 重複呼叫引發 crash
             此處暫解先將已完成的 loginCompletion 設為 nil，避免 App crash
             */
            [info finishLoginWithCompletionReset:YES];
        }];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"NYDismissLoginViewControllerNotification" object:nil];
}

@end
