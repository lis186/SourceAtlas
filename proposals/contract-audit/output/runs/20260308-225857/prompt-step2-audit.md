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
| 4 | S | dispatch_async | 1 | NYDataProvider.m:2511 |
| 5 | S | dispatch_queue_create | 1 | NYCookieManager.m:421 |
| 6 | S | dispatch_barrier | 1 | NYCookieManager.m:421 |
| 7 | S | dispatch_once | 6 | NYHTTPSClient.m:61 |
| 8 | S | DISPATCH_TIME_FOREVER | 2 | NYHTTPSClient.m:650 |
| 9 | S | dispatch_group | 5 | NYCartSecondVC.m:561 |
| 10 | N | postNotificationName | 3 | NYHTTPSClient.m:747 |
| 11 | N | delegate_property | 12 | NYCartSecondVC.m:250 |
| 12 | N | defaultCenter | 3 | NYHTTPSClient.m:747 |
| 13 | N | completionHandler | 288 ⚠️ pervasive | NYHTTPSClient.m:610 |
| 14 | N | success_failure_block | 600 ⚠️ pervasive | NYHTTPSClient.m:172 |
| 15 | L | viewDidLoad | 2 | NYCartSecondVC.m:85 |
| 16 | L | viewWillAppear | 2 | NYCartSecondVC.m:101 |
| 17 | L | viewDidAppear | 2 | NYCartSecondVC.m:106 |
| 18 | D | sharedInstance | 60 ⚠️ pervasive | NYHTTPSClient.m:635 |
| 19 | D | shared_dot | 65 ⚠️ pervasive | NYAppDelegateHelper.m:52 |
| 20 | D | protocol_decl | 1 | NYHTTPSClient.h:28 |
| 21 | D | ifdef_feature | 1 | NYCookieManager.m:249 |
| 22 | D | category_interface | 8 | NYHTTPSClient.m:30 |
| 23 | E | NSError_param | 17 | NYHTTPSClient.m:235 |
| 24 | E | errorWithDomain | 15 | NYHTTPSClient.m:309 |
| 25 | C | cancel_operation | 1 | NYHTTPSClient.m:460 |

共 25 個錨點命中。

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
//  ExternalLink+DI.swift
//  NineyiAppShop
//
//  Created by Alex Lin on 2020/7/2.
//  Copyright © 2020 91App. All rights reserved.
//

import Foundation

extension ExternalLink: DIProcess {
    static func handleDI() {
        fetcher = Fetcher()
    }
}

extension ExternalLink {
    class Fetcher: ExternalLinkFetcher {
        func fetchList(completion: @escaping ([String]) -> Void) {
            // Call API
            let path = "ConfigFile/redirect-whitelist/external-browser.json"
            NYHTTPSClient.appCDNClient.getJSON(path, parameters: [:], success: {
                (operation, externalLinkData: RedirectListData) in
                // Success
                let domains = externalLinkData.urls
                completion(domains)
            }) { (_, _) in
                // Fail, do nothing...
            }
        }
    }
}

private struct RedirectListData: Codable {
    let urls: [String]
}
//
//  NYAppDelegateHelper.m
//  NineYiShopping
//
//  Created by wpsteak on 13/9/12.
//  Copyright (c) 2013年 Julie Lin. All rights reserved.
//

#import "NYAppDelegateHelper.h"

#import "NineyiAppShop-Swift.h"
//API
#import <NYCore/NYHTTPSClient.h>
#import <NYCore/NYUserDefault.h>
#import <NYCore/NYCookieManager.h>
#import <NYCore/NYBaseURLConfig.h>
#import <NYCore/NYGlobalData.h>
#import <NYCore/NYLoginHelper.h>
#import <NYCore/NYDataProvider.h>
#import <NYCore/NYAppSettingsHelper.h>

//Infra
#import <NYCore/NYNotificationHelper.h>
#import <NYCore/NYStatisticHelper.h>

//NYLib
#import <NYCore/NYLoginViewController.h>
#import <NYCore/UIViewController+NYAlertControllerHelper.h>
#import <NYCore/NYCore-Swift.h>
#import <NYCore/NYLocalizationString.h>

//External Lib

@interface NYAppDelegateHelper ()

@end

@implementation NYAppDelegateHelper


#pragma mark - Checking

+ (void)checkIfShopValidWithCompletion:(void (^)(BOOL isAppOff))completion {

    [NYGraphQLHelper appEnableStatusWithShopId:[NYGlobalData shopId] completion:^(NSDictionary *rawData, NSError *error) {
        NSDictionary *appEnableStatusJSON = rawData[@"data"][@"appState"][@"appEnableStatus"];
        BOOL isEnable = [appEnableStatusJSON[@"isEnable"] boolValue];

        //如果是API打不通當作正常處理
        BOOL isAppOff = !error && !isEnable;
        
        LaunchAlertHelper.shared.appOffAlertStatus = isAppOff ? StatusShouldDisplay : StatusPass;

        //Call back
        if (completion) {
            completion(isAppOff);
        }
    }];
}

@end
//
//  NYCartSecondVC.m
//  NineyiAppShop
//
//  Created by Eric Huang on 2016/5/25.
//  Copyright © 2016年 91App. All rights reserved.
//

#import "NYCartSecondVC.h"
#import "NYCartJSONObjectProxy.h"
#import "NYCartPayTypeEnum.h"

#import "NYShoppingCartIndicatorView.h"
#import "NYCartStoreListVC.h"

#import "NYCartOtherOptionVC.h"
#import "NYCartSecondCustomHeaderView.h"
#import "NYCartShippingTypeEnum.h"

#import "NYCartTopPromptView.h"
#import "NYCartSecondPageTopPromptViewModel.h"

#import "NYCartPaymentCell.h"
#import "NYCartPaymentCellViewModel.h"
#import "NYCartShippingCell.h"
#import "NYCartShippingCellViewModel.h"
#import "NYCartSeparatorCell.h"
#import "NYCartSeparatorCellViewModel.h"
#import "NYCartSummaryDetailCell.h"
#import "NYCartSummaryDetailCellViewModel.h"
#import "NYCartSummarySumCell.h"
#import "NYCartSummarySumCellViewModel.h"
#import "NYCartShippingInfoViewModel.h"
#import "NYCartShippingInfoCell.h"
#import "NYCartShippingViewModelProtocol.h"
#import "NineyiAppShop-Swift.h"

#import "NYCartNextStepView.h"
#import "NYCartNextStepViewModel.h"
#import <NYCore/NYDataProvider.h>
#import <NYCore/NYCookieManager.h>
#import <NYCore/NYUrlHelper.h>
#import <NYCore/NYHTTPSClient.h>
#import <NYCore/NSString+Regex.h>
#import <NYCore/UIView+Border.h>
#import <NYCore/NYCore-Swift.h>
#import <NYCore/NYLocalizationString.h>
#import <NYCore/NYStatisticHelper.h>
#import <NYCore/NYTableViewCustomLabelCell.h>
#import <NYCore/NYProgressHUD.h>

@interface NYCartSecondVC () <UITableViewDataSource, UITableViewDelegate, NYCartPaymentCellDelegate, NYCartShippingButtonCellDelegate, NYCartOtherOptionProtocol, NYCartNextStepViewDelegate, NYCartCurrencyInfoCellDelegate>

@property (nonatomic, strong) NSNumber *shopId;
@property (nonatomic, strong) NSMutableArray <NSMutableArray *> *viewModelList;

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIView *cartStepIndicatorContainerView;
@property (weak, nonatomic) IBOutlet NYCartNextStepView *nextStepView;
@property (nonatomic, strong) NSString *payProcessURLString;
@property (nonatomic, strong) NSString *payTypeChannelCode;
@property (nonatomic, assign) NSUInteger paymentTapCount;
@property (nonatomic, assign) NSUInteger shippngTapCount;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *tableViewTopSpaceConstraint;
@property (nonatomic, strong) NYShoppingCartIndicatorView *stepIndicatorView;
@property (nonatomic, strong) NYCartTopPromptView *topPromptView;

@property (nonatomic, assign) BOOL hasTappedDesignatePaymentPromotion;
@property (nonatomic, assign) CGPoint tableCurrentOffset;

@property (nonatomic, assign) BOOL isMemberUpgradePXPayPlus;

@end

@implementation NYCartSecondVC

- (instancetype)initWithShopId:(NSNumber *)shopId {
    self = [self initWithNibName:NSStringFromClass([NYCartSecondVC class]) bundle:[NSBundle mainBundle]];
    _shopId = shopId;
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupTableView];
    [self setupNextStepView];
    [self setupStepIndicatorImageView];
    self.title = NYLocalizedString(@"cart_ga_pageview_cart_second_vc", nil);
    _paymentTapCount = 0;
    _shippngTapCount = 0;
    _tableCurrentOffset = CGPointMake(0.0, 0.0);
    
    // 預設 HintView 會出現（沒有點擊過）
    _hasTappedDesignatePaymentPromotion = false;

    [self sendShoppingCartEcommerceStep2];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self sendPageTrackingEvent];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Overrided Methods
- (UIAlertAction *)continueAction {
    typeof(self) __weak weakSelf = self;
    return [UIAlertAction actionWithTitle:NYLocalizedString(@"cart_continue", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self pushCartWebBrowserVCWithPayProcessURLString:weakSelf.payProcessURLString];
    }];
}

- (UIAlertAction *)reloadAction {
    return [UIAlertAction actionWithTitle:NYLocalizedString(@"common_reload", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {        
    }];
}

#pragma mark - private
- (void)reloadData {
    [self setupTopPromptView];

    // 因為在小尺寸手機 reload 時會亂跳，記住 content offset，reload 完時再塞回去
    self.tableCurrentOffset = _tableView.contentOffset;
    // 先把內容清空 reload，以免欄位數有變少時 out of bound
    self.viewModelList = [NSMutableArray new];
    [self.tableView reloadData];
    // 避免在不同Thread去動到ViewModels, 先把Proxy的那份Copy下來才Reload tableView
    self.viewModelList = [[NYCartJSONObjectProxy sharedInstance] secondPageViewModelListsCopy];
    [self.tableView reloadData];
    _tableView.contentOffset = self.tableCurrentOffset;
}

- (void)setupStepIndicatorImageView {
    CGRect frame = _cartStepIndicatorContainerView.frame;
    
    if (!_stepIndicatorView) {
        //Create indicator view
        NYShoppingCartIndicatorView *indicatorView = [NYShoppingCartIndicatorView indicatorViewWithWidth:CGRectGetWidth(frame)];
        indicatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        indicatorView.frame = frame;
        [indicatorView step2];
        
        //Add
        [_cartStepIndicatorContainerView addSubview:indicatorView];
        _stepIndicatorView = indicatorView;
    }
}

- (void)setupTopPromptView {
    [_topPromptView removeFromSuperview];
    
    NYCartSecondPageTopPromptViewModel *viewModel = [[NYCartJSONObjectProxy sharedInstance] secondPageTopPromptViewModel];
    
    if (viewModel) {
        NSBundle *bundlde = [NSBundle bundleForClass:[viewModel class]];
        _topPromptView = [bundlde loadNibNamed:[[viewModel class] viewNibName]
                                         owner:nil
                                       options:nil].lastObject;
        [_topPromptView setContentWithViewModel:viewModel];
        
        CGFloat y = CGRectGetMaxY(_cartStepIndicatorContainerView.frame);
        CGRect frame = _topPromptView.frame;
        frame.origin.y = y;
        frame.size = [viewModel preferSize];
        _topPromptView.frame = frame;

        [self.view insertSubview:_topPromptView belowSubview:_tableView];
        self.tableViewTopSpaceConstraint.constant = frame.size.height;
        
    } else {
        self.tableViewTopSpaceConstraint.constant = 0;
    }
    
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (void)setupTableView {
    [_tableView setBackgroundColor:[UIColor colorWithHexString:@"0xEEEEEE"]];
    [_tableView registerNib:[NYCartSecondCustomHeaderView nib] forHeaderFooterViewReuseIdentifier:[NYCartSecondCustomHeaderView headerId]];
    NSArray *cellClassList = @[[NYCartPaymentCellViewModel class],
                               [NYCartShippingCellViewModel class],
                               [NYCartSeparatorCellViewModel class],
                               [NYCartSummaryDetailCellViewModel class],
                               [NYCartSummarySumCellViewModel class],
                               [NYCartShippingInfoViewModel class],
                               [NYCartCurrencyInfoViewModel class],
                               [NYCartShippingWithPromotionViewModel class]];
    
    typeof(self) __weak weakSelf = self;
    [cellClassList enumerateObjectsUsingBlock:^(Class _Nonnull class, NSUInteger idx, BOOL * _Nonnull stop) {
        [weakSelf.tableView registerNib:[class nib] forCellReuseIdentifier:[class cellIdentifier]];
    }];
    
    [self.tableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self.tableView setRowHeight:UITableViewAutomaticDimension];
    [self.tableView setEstimatedRowHeight:44.0];
}

- (void)setupNextStepView {
    NYCartNextStepViewModel *viewModel = [[NYCartJSONObjectProxy sharedInstance] secondPageNextStepViewModel];

    NSBundle *bundle = [NSBundle bundleForClass:[NYCartNextStepView class]];
    NYCartNextStepView *view = [bundle loadNibNamed:[[NYCartNextStepView class] description]
                                              owner:nil
                                            options:nil].lastObject;
    
    [[self.nextStepView subviews] valueForKeyPath:@"removeFromSuperview"];
    [self.nextStepView addSubview:view];
    
    [view setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [view setFrame:_nextStepView.bounds];
    [view setDelegate:self];
    [view setContentWithViewMode:viewModel];
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.viewModelList.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.viewModelList[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id<NYCartViewModelProtocol> viewModel = self.viewModelList[indexPath.section][indexPath.row];
    NSString *cellIdentifier = [[viewModel class] cellIdentifier];
    __kindof UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    __weak NYCartJSONObjectProxy *proxy = [NYCartJSONObjectProxy sharedInstance];

    if ([viewModel isKindOfClass:[NYCartPaymentCellViewModel class]]) {
        NYCartPaymentCellViewModel *cartPaymentCellViewModel = (NYCartPaymentCellViewModel *)viewModel;
        NYCartPaymentCell *cartPaymentCell = (NYCartPaymentCell *)cell;
        
        BOOL isSelected = [[cartPaymentCellViewModel identityValue] isEqualToString:[proxy selectedCheckoutPayTypeGroupIdentityValue]];
        cartPaymentCellViewModel.isSelected = isSelected;
        
        cartPaymentCell.delegate = self;
        [cartPaymentCell setContentWithViewModel:cartPaymentCellViewModel];
        
    } else if ([viewModel isKindOfClass:[NYCartShippingCellViewModel class]] ||
             [viewModel isKindOfClass:[NYCartShippingWithPromotionViewModel class]]) {
        id<NYCartShippingViewModelProtocol> cartShippingCellViewModel = (id<NYCartShippingViewModelProtocol>)viewModel;
        NYCartShippingCell *cartShippingCell = (NYCartShippingCell *)cell;
        
        // 因為離島配送都是宅配，所以須判斷 area id 是否一致
        NSString *shippingAreaId = [proxy selectedCheckoutShippingAreaId];

        BOOL isSelected = ([[cartShippingCellViewModel shippingProfileTypeString] isEqualToString:[proxy selectedCheckoutShippingTypeGroupShippingProfileTypeDef]] &&
                           [[cartShippingCellViewModel shippingAreaId] isEqualToString:shippingAreaId]);
        if ([NYCartShippingTypeEnum shippingProfileTypeWithString:[cartShippingCellViewModel shippingProfileTypeString]] == NYCartShippingProfileOversea) {
            isSelected = [[cartShippingCellViewModel shippingId] isEqualToNumber:[proxy selectedCheckoutShippingTypeShippingId]];
        }
       
        [cartShippingCell setContentWithViewModel:cartShippingCellViewModel isSelected:isSelected];
        cartShippingCell.delegate = self;
        
    } else if ([viewModel isKindOfClass:[NYCartSeparatorCellViewModel class]]) {
        NYCartSeparatorCellViewModel *salePageFooterViewModel = (NYCartSeparatorCellViewModel *)viewModel;
        NYCartSeparatorCell *salePageFooterCell = (NYCartSeparatorCell *)cell;
        
        [salePageFooterCell setContentWithViewModel:salePageFooterViewModel];
        
    } else if ([viewModel isKindOfClass:[NYCartSummaryDetailCellViewModel class]]) {
        NYCartSummaryDetailCellViewModel *detailCellViewModel = (NYCartSummaryDetailCellViewModel *)viewModel;
        NYCartSummaryDetailCell *detailCell = (NYCartSummaryDetailCell *)cell;
        
        detailCell.accessibilityIdentifier = @"deliveryDetailCell";
        [detailCell setContentWithViewModel:detailCellViewModel];
        
    } else if ([viewModel isKindOfClass:[NYCartSummarySumCellViewModel class]]) {
        NYCartSummarySumCellViewModel *sumCellViewModel = (NYCartSummarySumCellViewModel *)viewModel;
        NYCartSummarySumCell *sumCell = (NYCartSummarySumCell *)cell;
        
        [sumCell setContentWithViewModel:sumCellViewModel];
        
    } else if ([viewModel isKindOfClass:[NYCartShippingInfoViewModel class]]) {
        NYCartShippingInfoViewModel *shippingInfoCellViewModel = (NYCartShippingInfoViewModel *)viewModel;
        NYCartShippingInfoCell *shippingInfoCell = (NYCartShippingInfoCell *)cell;

        [shippingInfoCell setContentWithViewModel:shippingInfoCellViewModel];
        
    } else if ([viewModel isKindOfClass:[NYCartCurrencyInfoViewModel class]]) {
        NYCartCurrencyInfoViewModel *currencyInfoViewModel = (NYCartCurrencyInfoViewModel *)viewModel;
        NYCartCurrencyInfoCell *currencyInfoCell = (NYCartCurrencyInfoCell *)cell;
        
        [currencyInfoCell setContentWithViewModel:currencyInfoViewModel];
        currencyInfoCell.delegate = self;
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    id<NYCartViewModelProtocol> viewModel = self.viewModelList[indexPath.section][indexPath.row];
    if ([viewModel isKindOfClass:[NYCartPaymentCellViewModel class]]) {
        NYCartPaymentCell *cartPaymentCell = (NYCartPaymentCell *)cell;
        cartPaymentCell.hasTappedDesignatePaymentPromotion = _hasTappedDesignatePaymentPromotion;
        [cartPaymentCell showDesignatePaymentHintIfNeeded];
    }
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id<NYCartViewModelProtocol> viewModel = self.viewModelList[indexPath.section][indexPath.row];
    __weak NYCartJSONObjectProxy *proxy = [NYCartJSONObjectProxy sharedInstance];
    typeof(self) __weak weakSelf = self;
    
    if ([viewModel isKindOfClass:[NYCartPaymentCellViewModel class]]) {
        NYCartPaymentCellViewModel *paymentCellViewModel = (NYCartPaymentCellViewModel *)viewModel;
        BOOL isSelected = [[paymentCellViewModel identityValue] isEqualToString:[proxy selectedCheckoutPayTypeGroupIdentityValue]];
        
        if (isSelected) {
            return;
        }
        _paymentTapCount++;
        
        // Loading Start
        [self displayProgressHUD];
        
        // 付款渠道資料
        id payTypeChannelCode = [paymentCellViewModel shouldShowPayChannelList] ? _payTypeChannelCode ?: [NSNull null] : [NSNull null];
        NSDictionary *payTypeChannelDict = @{kPayTypeChannelCode: payTypeChannelCode};
        
        [proxy updateSelectedCheckoutPayTypeGroupWithIdentityValue:paymentCellViewModel.identityValue
                                                    payTypeChannel:payTypeChannelDict
                                                 completionHandler:^(NSString * _Nullable returnCode,
                                                                     NSString * _Nullable message,
                                                                     NSError * _Nullable error) {
            [weakSelf handleCalculateReturnCode:returnCode message:message error:error];
            
            // Loading End
            [weakSelf hideProgressHUD];
        }];

    } else if ([viewModel isKindOfClass:[NYCartShippingCellViewModel class]] ||
               [viewModel isKindOfClass:[NYCartShippingWithPromotionViewModel class]]) {
        id<NYCartShippingViewModelProtocol> shippingCellViewModel = (id<NYCartShippingViewModelProtocol>)viewModel;
        NSString *selecteShippingProfileTypeString = shippingCellViewModel.shippingProfileTypeString;
        NSString *currentShippingProfileTypeString = [proxy selectedCheckoutShippingTypeGroupShippingProfileTypeDef];
        NSString *selecteShippingAreaId = shippingCellViewModel.shippingAreaId;
        NSString *currentCheckoutShippingAreaId = [proxy selectedCheckoutShippingAreaId];
       
        if ([NYCartShippingTypeEnum shippingProfileTypeWithString:selecteShippingProfileTypeString] == NYCartShippingProfileOversea) {
            BOOL isSelected = [[shippingCellViewModel shippingId] isEqualToNumber:[proxy selectedCheckoutShippingTypeShippingId]];
            if (isSelected) {
                return;
            }

            [proxy updateDisplayShippingTypeWithShippingProfileTypeDef:shippingCellViewModel.shippingProfileTypeString
                                                       selectedIdArray:@[[shippingCellViewModel shippingId]]
                                                selectedShippingAreaId:shippingCellViewModel.shippingAreaId
                                                     completionHandler:nil];
        } else {

            BOOL isSelected = ([selecteShippingProfileTypeString isEqualToString:currentShippingProfileTypeString] &&
                               [selecteShippingAreaId isEqualToString:currentCheckoutShippingAreaId]);
            if (isSelected) {
                return;
            }
        }
        _shippngTapCount++;
        [self updateSelectedCheckoutShippingTypeGroupWithShippingProfileTypeDef:selecteShippingProfileTypeString
                                                                 shippingAreaId:selecteShippingAreaId];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    id<NYCartViewModelProtocol> viewModel = [self.viewModelList[section] firstObject];
    if ([viewModel isKindOfClass:[NYCartPaymentCellViewModel class]] ||
        [viewModel isKindOfClass:[NYCartShippingCellViewModel class]] ||
        [viewModel isKindOfClass:[NYCartShippingWithPromotionViewModel class]]) {
        //Payment & shipping
        return [NYCartSecondCustomHeaderView headerHeight];
    }
    
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    //特例處理: 因為給0的時候 在最下面的Section會走Default, 然後加上一個padding (應該是bottom layout guide?)
    //所以給1
    return 1;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NYCartSecondCustomHeaderView *headerView = nil;
    
    //Check
    id<NYCartViewModelProtocol> viewModel = [self.viewModelList[section] firstObject];
    if ([viewModel isKindOfClass:[NYCartPaymentCellViewModel class]]) {
        //Payment
        headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:[NYCartSecondCustomHeaderView headerId]];
        headerView.titleLabel.text = NYLocalizedString(@"cart_payment_method_title", nil);
        headerView.isAccessibilityElement = YES;
        headerView.accessibilityLabel = @"QE_cart_payment_method_title";
        headerView.accessibilityValue = headerView.titleLabel.text;
    }
    else if ([viewModel isKindOfClass:[NYCartShippingCellViewModel class]] ||
             [viewModel isKindOfClass:[NYCartShippingWithPromotionViewModel class]]) {
        //Shipping
        headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:[NYCartSecondCustomHeaderView headerId]];
        headerView.titleLabel.text = NYLocalizedString(@"cart_delivery_method_title", nil);
        headerView.isAccessibilityElement = YES;
        headerView.accessibilityLabel = @"QE_cart_delivery_method_title";
        headerView.accessibilityValue = headerView.titleLabel.text;
    }
    
    [headerView.contentView setBackgroundColor:[UIColor whiteColor]];
    
    return headerView;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return nil;
}

#pragma mark - NYCartPaymentCellDelegate
- (void)nyCartPaymentButtonClickedWithViewModel:(id<NYCartPaymentViewModelProtocol>)viewModel {
    UIViewController *vc;
    NYCartPayStatisticsType type = [NYCartPayTypeEnum payStatisticsTypeWithString:viewModel.statisticsTypeDef];
    if (type == NYCartPayStatisticsTypeCustomOfflinePayment) {
        NSString *title = [viewModel cellTitle];
        CustomOfflinePaymentVC *infoVC = [CustomOfflinePaymentVC vcWithTitle:title];
        vc = infoVC;
    } else {
        NYInstallmentBankListTableViewControllerV2 *bankListVC = [[NYInstallmentBankListTableViewControllerV2 alloc] initWithIsFromCart:YES viewModel:viewModel];
        vc = bankListVC;
    }

    [self.navigationController pushViewController:vc animated:YES];
}

// 點選指定信用卡活動卡片
- (void)designatePaymentPromotionClickedWithPromotionId:(NSNumber *)promotionId payTypeIdentityValue:(id _Nullable)identityValue {
    [self displayProgressHUD];
    
    // 付款渠道資料
    id payTypeChannelCode = _payTypeChannelCode? : [NSNull null];
    NSDictionary *payTypeChannelDict = @{kPayTypeChannelCode: payTypeChannelCode};
    
    typeof(self) __weak weakSelf = self;
    [[NYCartJSONObjectProxy sharedInstance] updateSelectedDesignatePaymentWithPromotionId:promotionId
                                                                            identityValue:identityValue
                                                                           payTypeChannel:payTypeChannelDict
                                                                        completionHandler:^(NSString * _Nullable returnCode,
                                                                                            NSString * _Nullable message,
                                                                                            NSError * _Nullable error) {
        weakSelf.hasTappedDesignatePaymentPromotion = true;
        [weakSelf handleCalculateReturnCode:returnCode message:message error:error];
        [weakSelf hideProgressHUD];
    }];
}

/// 點選信用卡更多優惠活動卡片轉導活動頁面
/// - Parameter linkUrl: 活動頁面連結
- (void)pushAdditionalOfferWebViewWithURL:(NSURL *)linkUrl {
    if ([linkUrl.absoluteString isEqualToString:@""]) {
        return;
    } else {
        // 若為支援 Native 的 URL，關閉 webVC 後再跳轉原生頁面；若為其他不支援的 URL 直接用 webVC 開
        NYWKWebViewController *webVC = [NYWKWebViewController standardWebVCWithUrl:linkUrl];
        webVC.dismissStatus = NYWKWebViewSelfDismissStatusShouldDismiss;
        [self.navigationController pushViewController:webVC animated:YES];
    }
}

/// 點選付款渠道取得渠道代碼並更新 CartJSONObject
/// - Parameter payChannelCode: 付款渠道代碼
- (void)updatePayChannelCodeWithCode:(NSString *)payChannelCode {
    // Inject
    _payTypeChannelCode = payChannelCode;
    
    // 付款渠道資料
    id payTypeChannelCode = _payTypeChannelCode? : [NSNull null];
    NSDictionary *payTypeChannelDict = @{kPayTypeChannelCode: payTypeChannelCode};
    
    [[NYCartJSONObjectProxy sharedInstance] updateSelectedCheckoutPayTypeGroupPayTypeChannelWithDictionary:payTypeChannelDict];
}

#pragma mark - NYCartShippingButtonCellDelegate
- (void)nyCartShippingOtherOptionBtnPressWithViewModel:(id<NYCartShippingViewModelProtocol>)viewModel {
    NYCartOtherOptionVC *otherOptionVC = [[NYCartOtherOptionVC alloc] initWithShippingProfileTypeDef:[viewModel shippingProfileTypeString] title:[viewModel cellTitle] shippingAreaId:[viewModel shippingAreaId]];
    otherOptionVC.delegate = self;
    [self.navigationController pushViewController:otherOptionVC animated:YES];
}

- (void)nyCartShippingStoreListBtnPressWithViewModel:(id<NYCartShippingViewModelProtocol>)viewModel {
    BOOL isLocalStore = [[[NYCartJSONObjectProxy sharedInstance] selectedShippingAreaDict][@"IsLocal"] boolValue];
    NYCartStoreListVC *storeListVC = [NYCartStoreListVC vcWithShopId:_shopId
                                                        isLocalStore:isLocalStore];
    [self.navigationController pushViewController:storeListVC animated:YES];
}

- (void)nyCartShippingFeeBtnPressWithViewModel:(id<NYCartShippingViewModelProtocol>)viewModel {
    NSString *urlString = [NSString stringWithFormat:@"%@/v2/ShippingArea/ShopShippingWeightProfile", [NYBaseURLConfig baseHTTPSURLWithAppServiceWebPageDomain].absoluteString];
    NSURLComponents *component = [NSURLComponents componentsWithURL:[NSURL URLWithString:urlString] resolvingAgainstBaseURL:YES];
    NSMutableArray<NSURLQueryItem *> *queries = [NSMutableArray new];
    [queries addObject:[NSURLQueryItem queryItemWithName:@"shopId" value:[[NYGlobalData shopId] stringValue]]];
    [queries addObject:[NSURLQueryItem queryItemWithName:@"shopShippingTypeId" value:viewModel.shippingId.stringValue]];
    if (viewModel.isOversea) {
        [queries addObject:[NSURLQueryItem queryItemWithName:@"isOversea" value:@"true"]];
    }
    component.queryItems = queries;

    NYWKWebViewController *webVC = [NYWKWebViewController standardWebVCWithUrl:component.URL];
    [self.navigationController pushViewController:webVC animated:YES];
}

#pragma mark - NYCartOtherOptionProtocol
- (void)updateSelectedCheckoutShippingTypeGroupWithShippingProfileTypeDef:(NSString *)shippingProfileTypeDef shippingAreaId:(NSString *)shippingAreaId {
    [self displayProgressHUD];
    typeof(self) __weak weakSelf = self;
    [[NYCartJSONObjectProxy sharedInstance]
     updateSelectedCheckoutShippingTypeGroupWithShippingProfileTypeDef:shippingProfileTypeDef
     shippingAreaId:shippingAreaId
     completionHandler:^(NSString * _Nullable returnCode, NSString * _Nullable message, NSError * _Nullable error) {
         [weakSelf handleCalculateReturnCode:returnCode message:message error:error];
         [weakSelf hideProgressHUD];
     }];
}

/// 強制選擇 "無需支付費用"
- (void)giftOnlyCartSelectFreeShippingFee {
    // Loading Start
    [self displayProgressHUD];
    
    typeof(self) __weak weakSelf = self;
    [[NYCartJSONObjectProxy sharedInstance] updateSelectedCheckoutPayTypeGroupWithIdentityValue:@"FreeOfCharge"
                                                                                 payTypeChannel:[NSNull null]
                                                                              completionHandler:^(NSString * _Nullable returnCode,
                                                                                                  NSString * _Nullable message,
                                                                                                  NSError * _Nullable error) {
        [weakSelf handleCalculateReturnCode:returnCode message:message error:error];
        
        // Loading End
        [weakSelf hideProgressHUD];
    }];
}

#pragma mark - NYCartCurrencyInfoCellDelegate
- (void)userTappedCurrencyInfoCellInfoAction {
    [self displayMessageWithCurrencyInfoAction];
}

#pragma mark - NYCartNextStepViewDelegate
- (void)nextStepButtonTapped:(UIButton *)nextStepButton {
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    // PX 環境額外做全支付特殊判斷
    dispatch_group_enter(dispatchGroup);
    if ([self isPXCountryAndPXPayPlusNotInstalledAndPXPayInstalled]) {
        __weak typeof(self) weakSelf = self;
        [weakSelf displayProgressHUD];
        [[NYDataProvider sharedInstance] getPXPayHasPXPayPlusMemberWithCompletionHandler:^(NSString * _Nullable returnCode,
                                                                                           NSDictionary * _Nullable data,
                                                                                           NSError * _Nullable error) {
            [weakSelf hideProgressHUD];
            if (!error && data && [returnCode isEqualToString:APIReturnCode.api0001]) {
                weakSelf.isMemberUpgradePXPayPlus = [data[@"IsUpgradeToPXPayPlus"] boolValue]?: NO;
            } else {
                weakSelf.isMemberUpgradePXPayPlus = NO;
            }
            
            dispatch_group_leave(dispatchGroup);
        }];
    } else {
        dispatch_group_leave(dispatchGroup);
    }
    
    // notify
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue(), ^{
        // 判斷是否安裝第三方金流 App
        if ([self isThirdPartyPaymentInstalled] == NO) {
            return;
        }
        
        // 判斷是否滿足 "所選物流超重" or "加上贈品後超重" 等情境
        if ([self isCartOverWeighted]) {
            return;
        }
        
        // 請求付款連結繼續結帳流程
        [self requestPayProcessURL];
    });
}

#pragma mark - 結帳流程相關
/// 購物車 P2 -> P3 取得結帳 URL
- (void)requestPayProcessURL {
    [self displayProgressHUD];
    typeof(self) __weak weakSelf = self;
    [[NYCartJSONObjectProxy sharedInstance] requestPayProcessURL:^(NSString * _Nullable payProcessURLString,
                                                                   NSString * _Nullable returnCode,
                                                                   NSString * _Nullable message,
                                                                   NSError * _Nullable error) {
        [self hideProgressHUD];
        if (!payProcessURLString || [payProcessURLString length] < 0) {
            [weakSelf displayNetworkErrorAlert];
            return;
        }
        
        weakSelf.payProcessURLString = payProcessURLString;
        [weakSelf updatePaymentDomainIfNeededWithUrlString:payProcessURLString];
        [weakSelf handleRequestWithReturnCode:returnCode
                                      message:message
                                        error:error];
    }];
}

- (void)updatePaymentDomainIfNeededWithUrlString:(NSString *)urlString {
    if ([self isCheckoutTypeApplePay] && urlString) {
        NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithString:urlString];
        NSString *domain = urlComponents.host;
        NYCartHTTPSClient *cartClient = (NYCartHTTPSClient *)[NYCartHTTPSClient sharedClient];
        [cartClient updatePaymentClientDomain:domain];
    } else {
        // do nothing
    }
}

- (BOOL)isCheckoutTypeApplePay {
    NSString *payTypeStatisticsTypeDef = [[NYCartJSONObjectProxy sharedInstance] selectedCheckoutPayTypeGroupStatisticsTypeDef];
    return [payTypeStatisticsTypeDef isMatchWithPattern:@"(ApplePay)"];
}

#pragma mark - ReturnCode Handler
- (void)handleCalculateReturnCode:(NSString *)returnCode
                          message:(NSString *)message
                            error:(NSError *)error {
    // returnCode處理，請參考：
    // https://docs.google.com/spreadsheets/d/1zmGZSYDp660LcfnJgpTkQUib7ySKtbQ7nwIxA4sQKf8/edit#gid=568238765
    
    if (error) {
        if (message) {
            [self displayUnpredictableErrorAlertWithErrorCode:message];
        } else {
            [self displayUnpredictableErrorAlert];
        }
    } else if ([returnCode isEqualToString:APIReturnCode.api5011]) { // API5011: 計算購物車成功
        if (message.length > 0) {
            [self displayConfirmMessage:message];
        }
        [self reloadData];
        [self setupNextStepView];
    } else if ([returnCode isEqualToString:APIReturnCode.api5012]) { // API5012: UniqueKey為空值
        [self displayMessage:message];
    } else if ([returnCode isEqualToString:APIReturnCode.api5015]) { // API5015: 該時段已滿單無法結帳
        NSString *msg = NYLocalizedString(@"cart_salepage_no_available_checkout_period", nil);
        [self displayMessageWithPopToRootViewControllerAction:msg];
    } else if ([returnCode isEqualToString:APIReturnCode.api5019]) { // API5019: 購物車資料過期、其他錯誤
        [[NYCartJSONObjectProxy sharedInstance] clearCartData];
        [self displayMessageWithBackToMainTabAndPopToCartFirst:message];
    }
}

- (void)handleRequestWithReturnCode:(NSString *)returnCode
                            message:(NSString *)message
                              error:(NSError *)error {
    // returnCode處理，請參考：
    // https://docs.google.com/spreadsheets/d/1zmGZSYDp660LcfnJgpTkQUib7ySKtbQ7nwIxA4sQKf8/edit#gid=568238765

    typeof(self) __weak weakSelf = self;
    if (error) {
        [self displayNetworkErrorAlert];
    } else if ([returnCode isEqualToString:APIReturnCode.api0001]) { // 取得付費流程網址成功
        [[NYCookieManager sharedManager] resetFRCookie];
        [self pushCartWebBrowserVCWithPayProcessURLString:weakSelf.payProcessURLString];
    } else if ([returnCode isEqualToString:APIReturnCode.api0006]) { // 取得付費流程網址成功，但贈品數量已售完
        [[NYCookieManager sharedManager] resetFRCookie];
        [self displayMessageWithContinueAction:message];
    } else if ([returnCode isMatchWithPattern:@"(API0002|API0007)"]) { // API0002：取得付費流程網址失敗；API0007：贈品數量不足，取得付費流程網址失敗
        [[NYCartJSONObjectProxy sharedInstance] clearCartData];
        [self displayMessageWithPopToRootViewControllerAction:message];
    } else if ([returnCode isEqualToString:APIReturnCode.api5020]) { // API5020: 優惠碼過期專用，2021/4/9: 只會出現在 get shopping cart
        [NYUserDefault setPromoCode:nil];
        [NYUserDefault setPromoCodePoolGroupID:nil];
        [self displayMessageWithPopToRootViewControllerAction:message];
    } else {
        [self displayMessage:message];
    }
}

- (void)pushCartWebBrowserVCWithPayProcessURLString:(NSString *)payProcessURLString {
    NSURL *URL = [NSURL URLWithString:payProcessURLString];

    // TODO: 如果 WKWebView 壞的很嚴重就還原下方註解
    // Create cart third page
    UIViewController *nextVC = [[NYCartThirdVC alloc] initWithStartUrl:URL];

//    // 馬來的購物車第三頁與其他國不同
//    BOOL isNewPaymentType = [NYCountryConfig isNewPaymentTypeIn:[NYGlobalData countryCode]];
//    NYCartJSONObjectProxy *cartData = [NYCartJSONObjectProxy sharedInstance];
//    UIViewController *nextVC = nil;
//    if (!isNewPaymentType) {
//        nextVC = [[NYCartThirdVC alloc] initWithStartUrl:URL];
//    }
//    else {
//        nextVC = [[NYI18NCartWebBrowserVC alloc] initWithPayProcessURL:URL
//                                                      shoppingCartData:cartData];
//    }
    
    [self.navigationController pushViewController:nextVC
                                         animated:YES];
}

#pragma mark - NYProgressHUD Helper Method
- (void)displayProgressHUD {
    [NYProgressHUD showHUDAddedToView:self.view];
}

- (void)hideProgressHUD {
    [NYProgressHUD hideAllHUDsForView:self.view];
}

#pragma mark - shopping cart GA ecommerce
- (void)sendShoppingCartEcommerceStep2 {
    // 2021.05.06 拔掉 GA
    }

- (void)sendPageTrackingEvent {
    [[NYStatisticHelper sharedHelper] sendPageName:[NYFAConstant kFAViewTypeShoppingCart]
                                             title:nil
                                            pageId:nil];
    
    [[NYStatisticHelper sharedHelper] sendEventCheckoutProgressWithStep:@(2)
                                                                  title:[NYFAConstant kFACheckoutProgressConfirmCartList]
                                                                version:nil
                                                                products:@[]];
}

#pragma mark - 第三方支付 App 安裝確認
- (BOOL)isThirdPartyPaymentInstalled {
    NYCartPayStatisticsType payType = [NYCartPayTypeEnum payStatisticsTypeWithString:[[NYCartJSONObjectProxy sharedInstance] selectedCheckoutPayTypeGroupIdentityValue]];
    // 非第三方支付不檢查
    if (payType != NYCartPayStatisticsTypeLinePay           &&
        payType != NYCartPayStatisticsTypeJKOPay            &&
        payType != NYCartPayStatisticsTypePoyaPay           &&
        payType != NYCartPayStatisticsTypePXPay             &&
        payType != NYCartPayStatisticsTypePXPayPlus         &&
        payType != NYCartPayStatisticsTypeAtome             &&
        payType != NYCartPayStatisticsTypeEWalletPayMe      &&
        payType != NYCartPayStatisticsTypeEasyWallet        &&
        payType != NYCartPayStatisticsTypeIcashPay          &&
        payType != NYCartPayStatisticsTypeBoCPay            &&
        payType != NYCartPayStatisticsTypeWechatPayHK) {
        return YES;
    }
    
    return [self checkThirdPartyPaymentInstalledWith:payType];
}

- (BOOL)checkThirdPartyPaymentInstalledWith:(NYCartPayStatisticsType)payType {
    NSString *message = [self paymentStringByType];
    NSURL *urlScheme = [self paymentURLSchemeByType:payType];
    NSURL *downloadURL = [self paymentDownloadURLByType:payType];
    BOOL isPaymentAppInstalled = [[UIApplication sharedApplication] canOpenURL:urlScheme];
    
    // PX環境, 選擇全支付付款, 全支付未安裝, PXPay有安裝. 會員是否升級全支付 為判斷依據
    if ([self isPXCountryAndPXPayPlusNotInstalledAndPXPayInstalled]) {
        isPaymentAppInstalled = self.isMemberUpgradePXPayPlus;
    }
    
    if (isPaymentAppInstalled == NO) {
        // 2.66 調整引導彈窗選項："下載"（左） & "重選付款方式"（右），固兩按鈕的 style 皆為 Default 以達到此順序
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                                 message:message
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:NYLocalizedString(@"common_download", nil)
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication]
             openURL:downloadURL
             options:@{}
             completionHandler:nil];}
        ];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NYLocalizedString(@"common_reselect_payment", nil)
                                                               style:UIAlertActionStyleDefault
                                                             handler:nil];
        
        [alertController addAction:confirmAction];
        [alertController addAction:cancelAction];
        [alertController setPreferredAction:cancelAction];
        [self presentViewController:alertController animated:true completion:nil];
    }
    
    return isPaymentAppInstalled;
}

/** PX 環境, 選擇全支付付款, 未安裝全支付, 有安裝 PXPay, 會給一個敗部復活機會.（只有 PX 環境需要）
 *  判斷會員是不是 PXPay 升級全支付（api 回來的 bool）
 */
- (BOOL)isPXCountryAndPXPayPlusNotInstalledAndPXPayInstalled {
    NYCartPayStatisticsType payType = [NYCartPayTypeEnum payStatisticsTypeWithString:[[NYCartJSONObjectProxy sharedInstance] selectedCheckoutPayTypeGroupIdentityValue]];
    
    // 全支付 安裝狀態
    NSURL *pxPayPlusUrlScheme = [self paymentURLSchemeByType:payType];
    BOOL isPXPayPlusAppInstalled = [[UIApplication sharedApplication] canOpenURL:pxPayPlusUrlScheme];
    // PXPay 安裝狀態
    NSURL *pxPayUrlScheme = [self paymentURLSchemeByType:NYCartPayStatisticsTypePXPay];
    BOOL isPXPayAppInstalled = [[UIApplication sharedApplication] canOpenURL:pxPayUrlScheme];
    
    return (NYGlobalData.countryType == NYCountryTypePX
            && payType == NYCartPayStatisticsTypePXPayPlus
            && isPXPayPlusAppInstalled == NO
            && isPXPayAppInstalled == YES);
}

- (NSString *)paymentStringByType {
    NSString *message = NYLocalizedString(@"cart_alert_third_party_payment_not_installed", nil);
    NSString *payProfile = [[NYCartJSONObjectProxy sharedInstance] selectedCheckoutPayTypeGroupDisplayName];
    
    return [NSString stringWithFormat:message, payProfile];
}

- (NSURL *)paymentURLSchemeByType:(NYCartPayStatisticsType)type {
    NSString *urlSchemeString = @"";
    
    if (type == NYCartPayStatisticsTypeLinePay) {
        urlSchemeString = [NYUrlHelper lineUrlScheme];
    
    } else if (type == NYCartPayStatisticsTypeJKOPay) {
        urlSchemeString = [NYUrlHelper jkosUrlScheme];
    
    } else if (type == NYCartPayStatisticsTypePoyaPay) {
        urlSchemeString = [NYUrlHelper poyaPayUrlScheme];
    
    } else if (type == NYCartPayStatisticsTypePXPay) {
        urlSchemeString = [NYUrlHelper pxPayUrlScheme];
    
    } else if (type == NYCartPayStatisticsTypePXPayPlus) {
        urlSchemeString = [NYUrlHelper pxPayPlusUrlScheme];
    
    } else if (type == NYCartPayStatisticsTypeAtome) {
        urlSchemeString = [NYUrlHelper atomeUrlScheme];
    
    } else if (type == NYCartPayStatisticsTypeEWalletPayMe) {
        urlSchemeString = [NYUrlHelper paymeUrlScheme];
    
    } else if (type == NYCartPayStatisticsTypeBoCPay) {
        urlSchemeString = [NYUrlHelper bocPayUrlScheme];
    
    } else if (type == NYCartPayStatisticsTypeIcashPay) {
        urlSchemeString = [NYUrlHelper icashPayUrlScheme];
    
    } else if (type == NYCartPayStatisticsTypeEasyWallet) {
        urlSchemeString = [NYUrlHelper easyWalletUrlScheme];
    
    } else if (type == NYCartPayStatisticsTypeWechatPayHK) {
        urlSchemeString = [NYUrlHelper wechatPayUrlScheme];
    }
    
    return [NSURL URLWithString:urlSchemeString];
}

- (NSURL *)paymentDownloadURLByType:(NYCartPayStatisticsType)type {
    NSString *downloadURLString = @"";
    
    if (type == NYCartPayStatisticsTypeLinePay) {
        downloadURLString = [NYUrlHelper lineAppStoreUrlString];
    
    } else if (type == NYCartPayStatisticsTypeJKOPay) {
        downloadURLString = [NYUrlHelper jkosAppStoreUrlString];
    
    } else if (type == NYCartPayStatisticsTypePoyaPay) {
        downloadURLString = [NYUrlHelper poyapayAppStoreUrlString];
    
    } else if (type == NYCartPayStatisticsTypePXPay) {
        downloadURLString = [NYUrlHelper pxpayAppStoreUrlString];
        
    } else if (type == NYCartPayStatisticsTypePXPayPlus) {
        downloadURLString = [NYUrlHelper pxPayPlusAppStoreUrlString];
    
    } else if (type == NYCartPayStatisticsTypeAtome) {
        downloadURLString = [NYUrlHelper atomeAppStoreUrlString];
    
    } else if (type == NYCartPayStatisticsTypeEWalletPayMe) {
        downloadURLString = [NYUrlHelper paymeAppStoreUrlString];
    
    } else if (type == NYCartPayStatisticsTypeBoCPay) {
        downloadURLString = [NYUrlHelper bocPayAppStoreUrlString];
    
    } else if (type == NYCartPayStatisticsTypeIcashPay) {
        downloadURLString = [NYUrlHelper icashPayAppStoreUrlString];
    
    } else if (type == NYCartPayStatisticsTypeEasyWallet) {
        downloadURLString = [NYUrlHelper easyWalletAppStoreUrlString];
    
    } else if (type == NYCartPayStatisticsTypeWechatPayHK) {
        downloadURLString = [NYUrlHelper wechatPayAppStoreUrlString];
    }
    
    return [NSURL URLWithString:downloadURLString];
}

#pragma mark - 超重提示
- (BOOL)isCartOverWeighted {
    BOOL isSelectedDeliveryTypeExceedsLimitWeight = [[NYCartJSONObjectProxy sharedInstance] isSelectedDeliveryTypeExceedsLimitWeight];
    BOOL isAddFreeGiftExceedsLimitWeight = [[NYCartJSONObjectProxy sharedInstance] isAddFreeGiftExceedsLimitWeight];
    BOOL isMultipleDeliveryType = [[NYCartJSONObjectProxy sharedInstance] isMultipleDeliveryType];
    BOOL isCartOverWeighted = (isSelectedDeliveryTypeExceedsLimitWeight || isAddFreeGiftExceedsLimitWeight);
    
    // 若超重，根據情境顯示對應的提示
    if (isCartOverWeighted) {
        [self showCartOverWeightAlertActionsWithIsSelectedDeliveryTypeExceedsLimitWeight:isSelectedDeliveryTypeExceedsLimitWeight
                                                         isAddFreeGiftExceedsLimitWeight:isAddFreeGiftExceedsLimitWeight
                                                                  isMultipleDeliveryType:isMultipleDeliveryType];
    }
    
    return isCartOverWeighted;
}

- (void)showCartOverWeightAlertActionsWithIsSelectedDeliveryTypeExceedsLimitWeight:(BOOL)isSelectedDeliveryTypeExceedsLimitWeight
                                                   isAddFreeGiftExceedsLimitWeight:(BOOL)isAddFreeGiftExceedsLimitWeight
                                                            isMultipleDeliveryType:(BOOL)isMultipleDeliveryType {
    // 超重提示彈窗內文
    NSString *overWeightMessage = [self composeOverWeightMessageWithIsSelectedDeliveryTypeExceedsLimitWeight:isSelectedDeliveryTypeExceedsLimitWeight
                                                                             isAddFreeGiftExceedsLimitWeight:isAddFreeGiftExceedsLimitWeight
                                                                                      isMultipleDeliveryType:isMultipleDeliveryType];
    
    // 超重提示彈窗
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[NYLocalizationString stringWithKey:@"cart_alert_over_weight_title"]
                                                                             message:overWeightMessage
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    // Action: "更換運送方式" -> 關閉彈窗
    UIAlertAction *changeDeliveryTypeAction = [UIAlertAction actionWithTitle:[NYLocalizationString stringWithKey:@"cart_alert_over_weight_change_delivery_type"]
                                                                       style:UIAlertActionStyleDefault
                                                                     handler:nil];
    
    // Action: "返回購物車" -> 返回 Cart P1
    UIAlertAction *backToCartAction = [UIAlertAction actionWithTitle:[NYLocalizationString stringWithKey:@"cart_alert_over_weight_back_to_cart"]
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
        [self.navigationController popViewControllerAnimated:YES];
    }];
    
    // Action: "移除並結帳" -> 繼續結帳流程
    UIAlertAction *keepCheckoutWithoutGiftsAction = [UIAlertAction actionWithTitle:[NYLocalizationString stringWithKey:@"cart_alert_over_weight_keep_checkout"]
                                                                             style:UIAlertActionStyleDefault
                                                                           handler:^(UIAlertAction * _Nonnull action) {
        [self requestPayProcessURL];
    }];
    
    // 超重提示彈窗 Actions 組成
    if (isSelectedDeliveryTypeExceedsLimitWeight) {
        // 情境 1：購物車商品超過所選物流的限重（無贈品，有多物流方式）
        [alertController addAction:backToCartAction];
        
        // 高優先級選項：更換運送方式
        [alertController addAction:changeDeliveryTypeAction];
        [alertController setPreferredAction:changeDeliveryTypeAction];
        
    } else if (isAddFreeGiftExceedsLimitWeight) {
        if (isMultipleDeliveryType) {
            // 情境 2-1：購物車商品加上贈品後超過所選物流的限重（同時額外可用物流的選項）
            [alertController addAction:changeDeliveryTypeAction];
        } else {
            // 情境 2-2：購物車商品加上贈品後超過所選物流的限重
            [alertController addAction:backToCartAction];
        }
        
        // 高優先級選項：移除並結帳
        [alertController addAction:keepCheckoutWithoutGiftsAction];
        [alertController setPreferredAction:keepCheckoutWithoutGiftsAction];
    }
    
    [self presentViewController:alertController animated:true completion:nil];
}

- (NSString *)composeOverWeightMessageWithIsSelectedDeliveryTypeExceedsLimitWeight:(BOOL)isSelectedDeliveryTypeExceedsLimitWeight
                                                   isAddFreeGiftExceedsLimitWeight:(BOOL)isAddFreeGiftExceedsLimitWeight
                                                            isMultipleDeliveryType:(BOOL)isMultipleDeliveryType {
    NSArray <NSDictionary *> *freeGiftPromotionList = [[NYCartJSONObjectProxy sharedInstance] freeGiftPromotionList];
    __block NSArray <NSDictionary *> *promotionFreeGiftList;
    __block NSArray <NSString *> *promotionFreeGiftTitleList = [NSMutableArray new]; // 贈品名稱列表
    
    // "FreeGiftPromotionList" -> "PromotionFreeGiftList" -> "Title"
    if (freeGiftPromotionList && freeGiftPromotionList.count > 0) {
        [freeGiftPromotionList enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull freeGiftPromotionDict, NSUInteger idx, BOOL * _Nonnull stop) {
            promotionFreeGiftList = freeGiftPromotionDict[kPromotionFreeGiftList];
            
            if (promotionFreeGiftList && promotionFreeGiftList.count > 0) {
                promotionFreeGiftTitleList = [promotionFreeGiftList valueForKey:@"Title"]; // 拿列表中所有標題
            }
        }];
    }
    
    NSDictionary *selectedCheckoutShippingTypeGroupDeliveryDict = [[NYCartJSONObjectProxy sharedInstance] selectedCheckoutShippingTypeGroupDeliveryDict];
    NSNumber *weightLimit = [selectedCheckoutShippingTypeGroupDeliveryDict[kWeightLimit] isKindOfClass:[NSNumber class]] ? selectedCheckoutShippingTypeGroupDeliveryDict[kWeightLimit] : 0;
    NSInteger weightLimitInKilogram = [weightLimit integerValue] / 1000; // g -> kg
    NSString *weightLimitString = [NSString stringWithFormat:@"%ld", (long)weightLimitInKilogram];
    NSString *internationalComma = [NYLocalizationString stringWithKey:@"common_comma"]; // 多語系逗號
    NSString *composedGiftTitleList = [promotionFreeGiftTitleList componentsJoinedByString:internationalComma]; // e.g. [a, b, c] -> @"a, b, c"
    NSString *composedOverWeightMessage = @"";

    // 情境 1：購物車商品超過所選物流的限重（無贈品，有多物流方式）
    if (isSelectedDeliveryTypeExceedsLimitWeight) {
        NSString *selectedDeliveryTypeOverWeightMessage = [NSString stringWithFormat:[NYLocalizationString
                                                                                      stringWithKey:@"cart_alert_selected_delivery_type_exceeds_limit_weight"], weightLimitString];
        
        composedOverWeightMessage = selectedDeliveryTypeOverWeightMessage;
        
    } else if (isAddFreeGiftExceedsLimitWeight) {
        if (isMultipleDeliveryType) {
            // 情境 2-1：購物車商品加上贈品後超過所選物流的限重（同時額外可用物流的選項）
            NSString *overWeightWithChangeDeliveryTypeActionMessage = [NSString stringWithFormat:[NYLocalizationString
                                                                                                  stringWithKey:@"cart_alert_add_free_gift_exceeds_limit_weight_message_change_delivery_type"], weightLimitString, composedGiftTitleList];
            
            composedOverWeightMessage = overWeightWithChangeDeliveryTypeActionMessage;
            
        } else {
            // 情境 2-2：購物車商品加上贈品後超過所選物流的限重
            NSString *overWeightWithBackToCartActionMessage = [NSString stringWithFormat:[NYLocalizationString
                                                                                          stringWithKey:@"cart_alert_add_free_gift_exceeds_limit_weight_message_back_to_cart"], weightLimitString, composedGiftTitleList];
            
            composedOverWeightMessage = overWeightWithBackToCartActionMessage;
        }
    }
    
    return composedOverWeightMessage;
}

@end
//
//  NYDataProvider+PopupInfo.swift
//  NineyiAppShop
//
//  Created by Tim Chen on 2024/9/19.
//  Copyright © 2024 91App. All rights reserved.
//

import NYCore

@objc public extension NYDataProvider {

    enum PopupInfoError: Error {
        case invalidResponse
        case nineyiError(returnCode: String, msg: String?)
        case networkError(Error?)
    }

    func getPopupInfo(salePageId: String) async throws -> [String: Any] {
        try await withCheckedThrowingContinuation { continuation in
            NYHTTPSClient.shared().getPath("/Sku/GetSkuPopupInfo/\(NYGlobalData.shopId() ?? 0)/\(salePageId)",
                                           parameters: [:]) { _, response in
                guard let json = response as? [String: Any],
                      let returnCode = json["ReturnCode"] as? String
                else {
                    continuation.resume(throwing: PopupInfoError.invalidResponse)
                    return
                }

                guard returnCode == APIReturnCode.api0001 else {
                    let msg = json["Message"] as? String
                    continuation.resume(throwing: PopupInfoError.nineyiError(returnCode: returnCode, msg: msg))
                    return
                }

                let data = json["Data"] as? [String: Any] ?? [:]
                continuation.resume(returning: data)

            } failure: { _, error in
                continuation.resume(throwing: PopupInfoError.networkError(error))
            }
        }
    }
}
//
//  NYDataProvider+ShopIntro.swift
//  NineyiAppShop
//
//  Created by Alex Lin on 2019/12/23.
//  Copyright © 2019 91App. All rights reserved.
//

import Foundation
import NYCore

// Note: 可能要看一下哪些要 Nullable
public struct NYShopIntroduceData: Codable {
    let shopSummary: String
    var shopSummaryMultiLang: String?
    let shopSummaryMulHtmlUrl: String?
    let supplierName: String
    let supplierCompanyPhone: String
    let supplierCompanyCity: String
    let supplierCompanyDistrict: String
    let supplierCompanyAddress: String
    let supplierRegistrationNumber: String?
}

public struct NYShopShoppingNoticeData: Codable {
    let shopId: Int
    let paymentContent: String
    let shippingContent: String
    let changeReturnContent: String
    let customTitle1: String?   // 目前沒用到
    let customContent1: String? // 目前沒用到
    let customTitle2: String?   // 目前沒用到
    let customContent2: String? // 目前沒用到
    let shoppingNoticeHtml: String
}

public struct NYCustomerServiceObj: Codable {
    let type: String?
    let name: String?
    let link: String?
    let timeData: String?
    let note: String?
}

public struct NYShopFunction: Codable {
    let isShowQuestionInsert: Bool
}

public struct NYShopInformationData: Codable {
    var shopIntroduceData: NYShopIntroduceData
    let shopShoppingNoticeData: NYShopShoppingNoticeData
    let customerServiceList: [NYCustomerServiceObj]
    let shopFunction: NYShopFunction?
}

extension NYDataProvider {

    public func getShopInformation(handler: @escaping (_ response: Any?, _ errorMsg: String?) -> Void) {
        // Path & parameters
        let path = "Shop/GetShopInformation/\(NYInfoPlist.shopID)"
        let parameters: [AnyHashable: Any] = [:]

        // Call API
        NYHTTPSClient.shared()?.get91APIObj(path, parameters: parameters, success: { (operation, responseData: NYAPIObj<NYShopInformationData>) in
            // Success
            handler(responseData.data, nil)
        }, failure: { (operation, errorMsg) in
            // Fail
            handler(nil, errorMsg)
        })
    }
}
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
//  NYExchangeRateAPI.swift
//  NineyiAppShop
//
//  Created by Alex Lin on 2019/12/10.
//  Copyright © 2019 91App. All rights reserved.
//

import Foundation
import NYCore

public struct NYExchangeRateAPIDataType: Codable {
    let exchangeRates: [NYExchangeRate]
}

public class NYExchangeRateAPI: NSObject {
    public static let shared = NYExchangeRateAPI()
    private var autoUpdateExchangeTimer: Timer?
    
    @objc static public func handleDidConfigReceive() {
        NYExchangeRateAPI.shared.startTimerIfNeeded()
    }
    
    private override init() {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc private func willEnterForeground() {
        startTimerIfNeeded()
    }
    
    @objc private func didEnterBackground() {
        stopTimer()
    }
    
    private func startTimerIfNeeded() {
        if UserDefaults.standard.bool(forKey: kShouldFrequentlyUpdateCurrencyRate) == false {
            return
        }
        
        let seconds: Int = UserDefaults.standard.integer(forKey: kUpdateCurrencyRateIntervalSec)
        if seconds > 0 {
            // before start timer, do query first
            self.updateExchangeRates {
                // do nothing
            }
            
            autoUpdateExchangeTimer = Timer.scheduledTimer(timeInterval: Double(seconds), target: self, selector: #selector(autoUpdateExchange), userInfo: nil, repeats: true)
        }
    }
    
    private func stopTimer() {
        autoUpdateExchangeTimer?.invalidate()
        autoUpdateExchangeTimer = nil
    }
    
    @objc private func autoUpdateExchange() {
        NYExchangeRateDebugLog.addDebugLog("autoUpdateExchange")
        self.updateExchangeRates {
            // do nothing
        }
    }
    
    public func updateExchangeRates(_ completion: @escaping () -> Void) {
        // Call API
        NYDataProvider.sharedInstance().getExchangeRates(handler: { (exchangeRates, errorMsg) in
            // Update
            if exchangeRates.count > 0 {
                NYExchangeRateDebugLog.addDebugLog("set exchangeRates from API, data=\(exchangeRates)")
                NYExchangeRateConfig.exchangeRates = exchangeRates
            } else {
                // Ignore error
            }
            completion()
        })
    }
}

// MARK: - DataProvider
extension NYDataProvider {
    public func getExchangeRates(handler: @escaping (_ response: [NYExchangeRate], _ errorMsg: String?) -> Void) {
        // Path & parameters
        let path = "ShopCurrencyRate/GetCurrencyRate"
        let parameters = ["shopId": NYGlobalData.shopId()]
        
        NYExchangeRateDebugLog.addDebugLog("getExchangeRates Start")

        // Call API
        NYHTTPSClient.shared().getPath(path, parameters: parameters as [AnyHashable : Any]) { task, response in
            NYExchangeRateDebugLog.addDebugLog("getExchangeRates End")
            
            guard let response = response as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted),
                  let result: NYExchangeRateAPIResponse = try? JSONDecoder.upperCamelDecoder.decode(NYExchangeRateAPIResponse.self, from: jsonData)
            else {
                handler([], "Fail to parse...")
                return
            }
            
            NYExchangeRateDebugLog.addDebugLog("getExchangeRates Response: \(response.jsonString ?? "")")
            
            // Success
            handler(result.data, nil)
            
        } failure: { task, error in
            NYExchangeRateDebugLog.addDebugLog("getExchangeRates Fail Error: \(String(describing: error))")
            
            if let error = error as? NSError {
              NYCrashlyticsHelper.uploader?.recordError(with: error)
            }
            // Fail
            handler([], error?.localizedDescription)
        }
    }
}
//
//  NYHTTPSClient+Swift.swift
//  NineyiAppShop
//
//  Created by Alex Lin on 2019/12/6.
//  Copyright © 2019 91App. All rights reserved.
//

import Foundation
import NYCore

/// API 回傳的基本型態
public struct NYAPIObj<T: Codable>: Codable {
    let returnCode: String
    let data: T
    let message: String
}

// MARK: - NYHTTPSClient
extension NYHTTPSClient {

    static var appCDNClient: NYHTTPSClient {
        return NYHTTPSClient(baseURL: NYBaseURLConfig.basedHTTPSURLWithAppCDNDomain())
    }

    /// For swift & codable.
    /// - Parameter path: Path
    /// - Parameter parameters: Parameters
    /// - Parameter decodeStrategy: Custom decode strategy (optional)
    /// - Parameter success: Success handler
    /// - Parameter failure: Failure handler
    public func getJSON<T: Codable>(
        _ path: String,
        parameters: [AnyHashable: Any],
        decodeStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys,
        success: @escaping (URLSessionDataTask?, T) -> Void,
        failure: @escaping (URLSessionDataTask?, String?) -> Void) {

        self.getPath(path, parameters: parameters, success: {
            (operation, result) in
            guard
                let result = result,
                let jsonData = try? JSONSerialization.data(withJSONObject: result,
                                                           options: .prettyPrinted)
                else {
                    // Parse fail
                    failure(operation, "Fail to parse...")
                    return
            }

            // Parse
            let decoder: JSONDecoder = JSONDecoder()
            decoder.keyDecodingStrategy = decodeStrategy

            if let jsonObj: T = try? decoder.decode(T.self, from: jsonData) {
                // Success
                success(operation, jsonObj)
            } else {
                // Parse fail
                failure(operation, "Fail to parse...")
            }
        }) { (operation, error) in
            // Connection error
            failure(operation, error?.localizedDescription ?? "Unknown connection error...")
        }
    }

    public func get91APIObj<T: Codable>(
        _ path: String,
        parameters: [AnyHashable: Any],
        success: @escaping (URLSessionDataTask?, NYAPIObj<T>) -> Void,
        failure: @escaping (URLSessionDataTask?, String?) -> Void) {
        self.getJSON(path,
                     parameters: parameters,
                     decodeStrategy: .convertFromUpperCamel,
                     success: success,
                     failure: failure)
    }
}
//
//  NYLaunchHelper.swift
//  NineyiAppShop
//
//  Created by Alex Lin on 2019/10/18.
//  Copyright © 2019 91App. All rights reserved.
//

import Foundation

import NYCore
import FirebaseCrashlytics
import SwiftUI
import DesignCloudiOS
import NYIcon

public class NYLaunchHelper: NSObject {}

// MARK: - Life Cycle
extension NYLaunchHelper {
    @objc public static func initializeProcess() {
        self.loadLocalSetting()
        self.handleDependencyInjection()
        self.cleanAndDisableCache()
        self.setupNotificationConfig()
        
        // 開啟 Status bar 上的 loading
        NYNetworkActivityIndicatorManager.shared.startObserveNetworkLoading()
    }
    
    @objc public static func initializeDesignCloud() {
        guard let country = NYGlobalData.countryCode(),
              let shopId = NYGlobalData.shopId() 
        else {
            DCInitInfoCache.shared.setError(DCError.other(description: "Shop config not found.", isNetworkError: false))
            NotificationCenter.default.post(name: .designCloudInitializationCompleted, object: nil)
            return
        }
        let domain = RoutingObject.sharedConfiguration.officialDomain

        setupDesignCloud(country: country, shopId: shopId, domain: domain, completion: {
            NotificationCenter.default.post(name: .designCloudInitializationCompleted, object: nil)
        })
    }
}

// MARK: - Private
extension NYLaunchHelper {

    /// Load local config to memory (static value)
    static func loadLocalSetting() {
        let countryCode: String = NYGlobalData.countryCode()
        let apiEnv: String = NYGlobalData.apiEnvironment()

        // Load config from plist
        guard let urlConfig = NSDictionary.dictionaryInPlist(fileName: "NYBaseURLConfig-Info", keyPath: "\(countryCode).\(apiEnv)") else {
            assert(false, "Error: NYBaseURLConfig-Info not found?")
            return
        }
        NYBaseURLConfig.setApiDomains(urlConfig)

        // Load debug domains
        // !!IMPORTANT!!
        // initializeDebugURLConfig 必須要在 handleDependencyInjection 處理.
        // initializeDebugURLConfig 必須要在 setupNotificationConfig 處理.
        // TODO: 可能要找時間整理一下 QA domain 的切法
        NYURLConfigDebugVC.initializeDebugURLConfig()
    }

    /// Handle all dependency injections in launch phase.
    static func handleDependencyInjection() {
        // Handle Language Inject (called first)
        Language.config = NYI18NConfig.self
        
        // Delegate
        NYNotificationHelper.sharedInstance()?.delegate = NYNotificationPresenter.sharedInstance()
        NYStatisticHelper.shared()?.trackingEventDelegate = NYTrackingEventHelper.shared
        NYECouponFabHelper.shared.delegate = NYCmsFabPresenter.shared
        NYGraphQLTemporaryDataMediator.shared()?.delegate = NYGraphQLTemporaryDataProvider.shared
        NYHTTPSClient.shared()?.logger = Crashlytics.crashlytics()
        NYWKWebViewController.transferDelegate = NYWKWebViewTransferHelper.shared
        LoginInjectionHelper.shared.delegate = RetailStoreService.shared
        LogoutInjectionHelper.shared.delegate = RetailStoreService.shared
        NYReferrerBindingLinkInjectionHelper.shared.delegate = NYReferrerBindingLinkHelper.shared
        LineLoginInjectionHelper.shared.delegate = LineLoginSDKWrapper.sharedInstance
        NYShoppingRebateInjectionHelper.shared.delegate = NYShoppingRebateHelper.shared
        
        // Note: 還有需要嗎？ 現在很多也是直接從 main bundle 取得
        // Inject login logo image
        let isBIDEnable: Bool = NYModuleConfig.isBrandIdentityModuleEnabled()
        let logoName: String = isBIDEnable ? "shopLogo_brand" : "shopLogo"
        NYLoginViewController.customBackButtonImageName(IconKey.ico_chevron_left, andDismissButtonImageName: IconKey.ico_close, andTitleViewImageName: logoName)

        // Handle WK Inject
        self.injectWKProxyHandler()

        // Handle Login Inject
        self.injectLoginWebView()

        // Handle gift eCoupon Inject
        self.injectGiftDetailViewController()
        self.injectMyGiftECouponViewController()
        self.injectExplanationVCPresentShoppintCart()

        self.injectLogoutCleanAllSetting()

        // Inject AES Key
        NYAESKeyManager.inject()
        
        // DI
        DependencyInjection.handleDI()
    }

    // TODO: 需要重構？
    static func setupNotificationConfig() {
        // Get shared config
        let sharedConfig: RoutingObjectConfig = RoutingObject.sharedConfiguration

        // Setup config
        let webServerURLStr: String = NYBaseURLConfig.domainNameForWebServer()
        let appServiceURLStr: String = NYBaseURLConfig.domainNameForAppService()
        let officalURLStr: String? = NYModuleConfig.hostForOfficialShopUrl()
        let baseURLStr: String? = NYBaseURLConfig.baseHTTPSURLWithAppServiceWebPageDomain()?.absoluteString
        sharedConfig.set(nyMaiPageDomain: webServerURLStr,
                        appServicePageDomain: appServiceURLStr,
                        officialDomain: officalURLStr,
                        domainAPI: baseURLStr,
                        shopID: NYGlobalData.shopId(),
                        checkIsDesignCloudPath: DesignCloudBridge.isDesignCloudPath(with:),
                        checkIsForceDCWebView: DesignCloudBridge.shouldForceRenderInWebView(forURL:))

        // Save config to keychain for tracking (Notification-Service)
        NYNotificationExtensionKeychainHelper.saveCountryCode(NYGlobalData.countryCode())
        NYNotificationExtensionKeychainHelper.saveShopId(NYGlobalData.shopId())
    }

    /// Remove cache folder & disable URLSession cache.
    static func cleanAndDisableCache() {

        // Note: 因應 XX邪會 資安檢測報告，必須要關掉 NSURLSession Cache，故採用下列寫法
        // 1. 如果是舊版升級上來的 App，手動砍掉 Caches/<bundleID>/ 底下的 Cache 檔案
        if
            let cachePath: String = NSSearchPathForDirectoriesInDomains(.cachesDirectory,
                                                                        .userDomainMask,
                                                                        true).last,
            let bundleID: String = NYGlobalData.bundleId(),
            let cacheURL: URL = URLComponents(string: cachePath)?.url {
            let cacheBundleURL: URL = cacheURL.appendingPathComponent(bundleID)
            try? FileManager.default.removeItem(at: cacheBundleURL)
        }

        // 2. 將 Cache Size 設為 0，以此方式關閉 Cache
        URLCache.shared = URLCache(memoryCapacity: 0,
                                   diskCapacity: 0,
                                   diskPath: nil)
    }
}

// MARK: - Injection
extension NYLaunchHelper {
    // MARK: WKWebView
    private static func injectWKProxyHandler() {
        self.injectWKLoginPageHandler()
        self.injectWKNativeHomeHandler()
        self.injectWKShoppingIndexLanding()
    }

    private static func injectWKShoppingIndexLanding() {
        NYWKWebViewRequestProxy.shoppingIndexLandingHandler = { (vc: NYWKWebViewController, navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) -> NYWKWebViewController.ProxyDecision in

            guard let urlString: String = navigationAction.request.url?.absoluteString else {
                return .pass
            }

            // Check URL
            guard urlString.contains("/V2/ShoppingCart/Index") else {
                return .pass
            }

            if vc is NYPureWebCartVC {
                return .pass
            }

            if let tabbarController = vc.tabBarController as? NYTabBarControllerV2 {
                // Landing to shopping cart
                if let cartFirstVC = vc.navigationController?.viewControllers.first(where: { $0 is NYCartFirstVC }) {
                    vc.navigationController?.popToViewController(cartFirstVC, animated: true)
                } else {
                    // 如果真的找不到購物車 P1，則去到 stack 中的第一個 vc
                    vc.navigationController?.popViewController(animated: true)
                }
                tabbarController.selectTabBarItem(of: .shoppingCart)
                decisionHandler(.cancel)
                return .made
            }

            if let tabbarController = vc.view.window?.rootViewController as? NYTabBarControllerV2 {
                tabbarController.dismiss(animated: true) {
                    tabbarController.selectTabBarItem(of: .shoppingCart)
                }
                decisionHandler(.cancel)
                return .made
            }

            return .pass
        }
    }

    private static func injectWKNativeHomeHandler() {
        NYWKWebViewRequestProxy.nativeHomeHandler = { (vc: NYWKWebViewController, navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) -> NYWKWebViewController.ProxyDecision in

            guard let urlString: String = navigationAction.request.url?.absoluteString
                , let domain91mai = NYBaseURLConfig.domainNameForWebServer()
                , let domainAppService = NYBaseURLConfig.domainNameForAppService() else {
                    return .pass
            }

            guard let tabbarController = vc.tabBarController as? NYTabBarControllerV2 else {
                return .pass
            }

            if urlString.lowercased().contains("ref=home") ||
                urlString.isMatch(regex: "http[s]?://(\(domain91mai))$") ||
                urlString.isMatch(regex: "http[s]?://(\(domainAppService))$") {
                // Note:
                //   backToHomePageVC 會造成上一頁的 pop 不會觸發 disappear
                //   可以用 willMove(toParent parent: UIViewController?)
                // Landing to home page
                vc.navigationController?.popViewController(animated: true)
                tabbarController.backToHomePageVC()

                decisionHandler(.cancel)
                return .made
            }

            return .pass
        }
    }

    private static func injectWKLoginPageHandler() {
        NYWKWebViewRequestProxy.loginPageHandler = { (vc: NYWKWebViewController, navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) -> NYWKWebViewController.ProxyDecision in

            guard let url = navigationAction.request.url else {
                return .pass
            }

            guard url.path == "/V2/Login/Index" else {
                return .pass
            }

            // Find redirect URL "rt=(target url after login)"
            let redirectName = "rt"
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let redirectQueryItem: URLQueryItem? = urlComponents?.queryItems?.first(where: { $0.name == redirectName })

            guard let redirectUrlString = redirectQueryItem?.value else {
                return .pass
            }

            // Create redirect request
            guard let decodedRtUrlString = redirectUrlString.removingPercentEncoding,
                  let redirectUrl = URLComponents(string: decodedRtUrlString)?.url else {
                return .pass
            }
          
            let redirectRequest = URLRequest(url: redirectUrl)
            let isRedirectToCart = redirectUrl.path.isMatch(regex: PureWebCartConfig.cartURL(withCode: nil)?.path)
            let isCartHandling = vc is NYPureWebCartVC || isRedirectToCart

            // 若購物車免登入可以預覽購物車 P1，但購物車走登入流程不需要蓋 unloginMask
            let shouldMaskVC = !vc.canGoBack() && !isCartHandling
            weak var weakVC = vc

            // Present login page
            if ignoreLoginPopup(by: urlComponents) {
                weakVC?.load(request: redirectRequest, needUpdateCookies: true)
                
            } else {
                if let tabBarController = vc.tabBarController as? NYTabBarControllerV2 {
                    tabBarController.userShouldLogin()
                }
                
                vc.presentLoginVCShouldShowUnLoginMask(shouldMaskVC, withLoginSuccessCompletion: {
                    // 為了塞購物車需要的 cookie，手動重開購物車（如果之後不需要另外塞 cookie，可以直接走 else 轉導）
                    if isCartHandling,
                       let tabBarController = vc.presentingViewController as? NYTabBarControllerV2 {
                        tabBarController.presentShoppingCart()
                        
                    } else {
                        // Redirect after login finished
                        weakVC?.load(request: redirectRequest, needUpdateCookies: true)
                    }
                })
            }

            decisionHandler(.cancel)
            return .made
        }
    }
    
    /// 已登入狀態下，遇到特殊情境應略過 /V2/Login/Index 導登入的處理
    ///
    /// 緣由：
    /// 因為員工推薦碼(23.6.0)功能需要登入，所以外導內帶進 App 的連結會是 /V2/Login/Index(包成 bmai) 讓使用者在綁定推薦人之前能先登入。
    /// 但是目前 App 沒有阻擋已登入狀態就不開啟登入頁的機制 (原本是 redirect 用的機制)，與 PO 討論後加入白名單判斷
    private static func ignoreLoginPopup(by urlComponent: URLComponents?) -> Bool {
        guard let urlComponent = urlComponent else { return false }
        
        // 員工推薦碼
        let scanCodeQuery: URLQueryItem? = urlComponent.queryItems?.first(where: { $0.name == "action" && $0.value == "ScanCode" })
        let isMatched: Bool = scanCodeQuery != nil
        
        return NYLoginHelper.sharedInstance().isLogin && isMatched
    }

    // MARK: Login
    private static func injectLoginWebView() {
        // WebView
        NYLoginViewController.setWebViewCreator { (url) -> UIViewController? in
            let vc: NYWKWebViewController = .standardWebVC(url: url)
            vc.hasTabbar = false
            return vc
        }

        // HTML WebView
        NYLoginViewController.setHTMLWebViewCreator { (htmlStr) -> UIViewController? in
            // Create HTML VC
            let vc: NYFullScreenHTMLViewController = .init()
            vc.loadHTML(htmlStr ?? "")

            return vc
        }
        
        // 雙重驗證頁 + CustomHeightVC
        NYLoginViewController.setResetPasswordMultiFactorAuthViewControllerCreator { (multiFactorAuthResetPasswordObject, completion, dismissHandler) -> UIViewController? in
            guard let multiFactorAuthResetPasswordObject = multiFactorAuthResetPasswordObject else { return nil }
            
            let multiFactorAuthView = ResetPasswordMultiFactorAuthView(data: multiFactorAuthResetPasswordObject, completionHandler: completion, dismissHandler: dismissHandler)
            let hostingVC = UIHostingController(rootView: multiFactorAuthView)
            let customHeightVC = CustomHeightViewController(childVC: hostingVC, screenPercent: 0.85)
            
            return customHeightVC
        }

        // Profile
        NYLoginViewController.setPresentProfileBlock { (vc, completion) in
            // 內部會檢查 option cache
            NYMemberInformationViewController.simpleInfoPageForPresent(pageCompletion: { (navi) in
                guard let profileVC = navi else {
                    return
                }
                // Present
                vc?.present(profileVC, animated: true)
            }, dismissCompletion: { (_, _) in
                completion?()
            })
        }
        
        NYLoginViewController.setReCaptchaGetTokenBlock { (completion) in
            NYReCaptchaHelper.sharedInstance.getToken { (token) in
                completion?(token)
            }
        }
    }

    // MARK: Gift ECoupon
    private static func injectGiftDetailViewController() {
        NYECouponExplanationViewController.setGiftVC { (giftId) -> UIViewController? in
            return NYGiftDetailViewController(giftID: giftId!)
        }
    }
    private static func injectMyGiftECouponViewController() {
        NYECouponExplanationViewController.setMyGiftECouponVC { () -> UIViewController? in
            return NYNewCouponContainerViewController.initWithTypes(pageType: .claimedPage, oldCouponSourceType: .giftEcoupon, newCouponType: .gift, newCouponCustomId: "")
        }
    }

    private static func injectExplanationVCPresentShoppintCart() {
        NYECouponExplanationViewController.setPresentShoppingCart { (vc) in
            if let tabBarController: NYTabBarControllerV2 = vc?.tabBarController as? NYTabBarControllerV2 {
                tabBarController.selectTabBarItem(of: .shoppingCart)
            }
        }
    }
    
    // MARK: HomePage
    @available(*, deprecated, renamed: "homePage(_:)", message: "DesignCloud View 需注入 navigator.")
    @objc static func homepage() -> UIViewController {
        return NYHomeViewPagerController()
    }

    @objc static func homePage(_ navigator: NaviController) -> UIViewController {
        if let designCloudVC = DesignCloudBridge.getHomeViewController(navigator: navigator) {
            return designCloudVC
        } else {
            return NYHomeViewPagerController()
        }
    }
    
    static func emptyHomeViewController(with errorCode: String? = nil) -> NaviController {
        let emptyHomeVC = NYDCInitEmptyViewController()
        if let errorCode {
            emptyHomeVC.displayErrorView(with: errorCode)
        }
        return NaviController(rootViewController: emptyHomeVC)
    }

    /// 依據首頁顯示選項生成對應的首頁 ViewController
    @objc static func homeNavigationController() -> NaviController {
      let rendererType: DesignCloudBridge.RendererType = DesignCloudBridge.getHomePageRendererType()
        switch rendererType {
        case .unknown:
            return NaviController(rootViewController: NYHomeViewPagerController())
        case .webview:
            guard let homePath = DesignCloudBridge.getHomePath(),
                  let homeVC = DCHomeWKWebViewController(path: homePath, dismissStatus: .pass)
            else {
                let emptyHomeVC = NYLaunchHelper.emptyHomeViewController(with: AppErrorCode.AppRelated.l00502)
                return emptyHomeVC
            }
            
            NotificationCenter.default.addObserver(name: .nyLogoutNotification) {
                homeVC.reloadPage()
            }
            
            return NaviController(rootViewController: homeVC)
        case .native:
            let navigationController = NaviController()
            guard let dcViewController = DesignCloudBridge.getHomeViewController(navigator: navigationController) else {
                let emptyHomeVC = NYLaunchHelper.emptyHomeViewController(with: AppErrorCode.AppRelated.l00502)
                return emptyHomeVC
            }

            /// login observer for DesignCloud home
            NotificationCenter.default.addObserver(name: .nyLoginNotification) {
                resetDesignCloudHomeNavigationRootVC(in: navigationController)
            }
            /// logout observer for DesignCloud home
            NotificationCenter.default.addObserver(name: .nyLogoutNotification) {
                resetDesignCloudHomeNavigationRootVC(in: navigationController)
            }

            navigationController.setViewControllers([dcViewController], animated: false)
            return navigationController
        }
    }

    /// 建立新的 DesignCloud HomeVC 取代現有的 navigation controller RootVC
    private static func resetDesignCloudHomeNavigationRootVC(in navigation: NaviController) {
        var stack = navigation.viewControllers
        guard stack.count >= 1,
              let dcHomeVC = DesignCloudBridge.getHomeViewController(navigator: navigation) else {
            return
        }
        stack[0] = dcHomeVC
        navigation.setViewControllers(stack, animated: false)
        DesignCloudBridge.refreshCurrentPage()
    }

    // MARK: ItemList
    /// 只有分類頁！不含人氣商品、瀏覽紀錄
    /// - Parameters:
    ///   - serviceType: 全聯分類頁的當前服務頻道
    ///   - filterObj: 如果是 url 開啟的分類頁，可能會有商品標籤等條件。nil 代表無條件，即顯示該分類底下所有商品。（目前僅一般小分類有商品標籤，全聯分類、標籤分類皆沒有）
    @objc static func itemListVC(categoryId: NSNumber?, filterObj: SearchResultFilterObject? = nil, layoutType: BrowserLayout = .unknown, sortKey: String = "", serviceType: String = "") -> UIViewController {
        if (RetailStoreService.isFeatureEnable()) {
            // 門市購專用小分類頁，有側邊母子分類、服務篩選
            // TODO: 當接口都是 Swift 的時候就可以不用 string 而直接使用 enum 了
            let serviceTypeEnum = FilterServiceType.type(caseInsensitive: serviceType)
            let sortType = NYItemListV2Tools.convertToSortType(from: sortKey)
            return NYPXItemListViewController.pxItemListController(with: categoryId ?? 0, serviceType: serviceTypeEnum, sortType: sortType)
        } else {
            // 一般小分類頁
            return NYItemListV2ViewController.itemListVCCategory(with: categoryId, filterObj: filterObj, defaultLayoutType: layoutType, defaultSortKey: sortKey)
        }
    }

    @objc static func newestCategoryPage() -> UIViewController {
        if (RetailStoreService.isFeatureEnable()) {
            return NYPXItemListViewController.itemListNewestCategory()
        } else {
            return NYItemListV2ViewController.itemListNewestCategory()
        }
    }
    
    private static func injectLogoutCleanAllSetting() {
        NYLoginHelper.setLogoutClearAllSetting { (loginAgain) in
            if let isLogin = NYLoginHelper.sharedInstance()?.isLogin, !isLogin {
                return
            }
            // clean data
            NYFacebookHelper.sharedInstance()?.closeSession()
            NYCookieManager.shared()?.removeCookie(withCookieName: kCOOKIE_NAME_AUTH)
            NYCookieManager.shared()?.removeCookie(withCookieName: "auth_samesite")
            NYUserDefault.setUserCellPhoneCountryID(nil)
            NYUserDefault.setUserCellPhoneCountryCode(nil)
            NYUserDefault.setLastLoginVersion(nil)
            NYUserDefault.setPromoCode(nil)
            NYUserDefault.setPromoCodePoolGroupID(nil)
            NYUserDefault.setMemberCode(nil)
            NYUserDefault.setOuterMemberId(nil)
            NYUserDefault.setCartPayErrorRedirectUrlString(nil)
            NYUserDefault.setDisplayedAlertPromotionIDs(nil)
            NYUserDefault.setUserEmail(nil)
            NYUserDefault.setPXHistoryAddressList(nil)
            NYFavoriteManager.shared()?.deleteCachedFavoriteList()
            // 24.8 移除 收藏舊邏輯, 新邏輯詳見 initFavoriteList
            // 先保留 comment, 觀察幾個版本再移除
            // NYFavoriteManager.shared()?.updateBadgeNumber()
            NYMemberHelper.shareInstance()?.userDidLogout()
            NYUserDefault.setMembershipDefaultCardBarcodeString(nil)
            NYCartJSONObjectProxy.sharedInstance()?.clearCartData()
            NYCartBadgeHelper.sharedInstance()?.resetCartBadgeNumber()
            NYCartBadgeHelper.sharedInstance()?.updateCartBadgeNumber()
            NYThirdPartySSOHelper.shared.clear()
            NYStatisticHelper.shared()?.userDidLogout()
            LogoutInjectionHelper.shared.userLogout()
            LineLoginInjectionHelper.shared.logoutIfNeed()
            NYAgeRestrictedProcessor.Mask.reset()
            NYKeychainHelper.deleteAppleSignInCredential()
            // 登出後把 Widget keychain 清空
            NYBarcodeKeychainCore.shared.deleteBarcode()
            NYUserDefault.setBarcodeKeychainUuId(nil)
            NYBarcodeKeychainCore.shared.reloadWidget()
            // 24.12 登出後清掉 LINE 綁定 memory cache、local cache
            LineBindingHelper.shared.clearCache()
            NYUserDefault.resetDismissLineBindingHint()
            
            // 登出後清除 DesignCloud cached data
            DesignCloud.resetOnLogout()
            initializeDesignCloud()

            // 登出後把 tabbar 所有 VC 退回 root
            if let window: UIWindow = UIApplication.shared.getKeyWindow(),
               let rootTabBar = window.rootViewController as? NYTabBarControllerV2 {
                rootTabBar.viewControllers?.forEach({ (subVC) in
                    if let subNavi = subVC as? UINavigationController {
                        subNavi.popToRootViewController(animated: false)
                        
                        if ((subNavi.visibleViewController as? NYWKWebViewController) != nil) {
                            rootTabBar.userDidLogout()
                        }
                    } else {
                        subVC.navigationController?.popToRootViewController(animated: false)
                    }
                })
                // 登出後指定回首頁
                rootTabBar.selectTabBarItem(of: .index)
                // 如果有再次跳 login 的需要就跳
                if (loginAgain) {
                    rootTabBar.presentLoginVCShouldShowUnLoginMask(false, withLoginSuccessCompletion: nil)
                }
            }
        }
    }
}

// MARK: - Other Extensions
extension Crashlytics: NYHTTPSClientLogger {}
extension NYI18NConfig: LanguageConfig {}

extension NSDictionary {
    static func dictionaryInPlist(fileName: String,
                                  keyPath: String? = nil) -> [AnyHashable: Any]? {
        guard
            let path: String = Bundle.main.path(forResource: "NYBaseURLConfig-Info",
                                                ofType: "plist"),
            let dict: NSDictionary = NSDictionary(contentsOfFile: path) else {
            return nil
        }

        if let keyPath = keyPath {
            return dict.value(forKeyPath: keyPath) as? [AnyHashable : Any]
        }
        return dict as? [AnyHashable : Any]
    }
}

extension NYLaunchHelper {
    private static func setupDesignCloud(country: String, shopId: NSNumber, domain: String, completion: @escaping () -> Void) {
        Task {
            DCInitInfoCache.shared.startFetching()

            // 1. 設定 DC 配置
            configureDesignCloud(
                country: country,
                shopId: shopId,
                domain: domain
            )

            // 2. 重試機制
            var lastError: Error?
            for attempt in 1...maxRetryCount {
                do {
                    if attempt > 1 {
                        let delay = calculateDelay(attempt: attempt - 1)
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }

                    // 3. 取得初始化資訊
                    guard let initInfo = try await DesignCloudBridge.initialize(force: true) else {
                        throw DCInitInfoCache.InitializationError.timeout
                    }
                    
                    // 4. 驗證初始化資訊、更新快取
                    try validateInitInfo(initInfo)
                    DCInitInfoCache.shared.updateInitInfo(initInfo)
                    lastError = nil

                    if initInfo.isAvailable {
                        // 5. 註冊 DC Events
                        DesignCloudEventManager.shared.registerAllEvents()
                    }
                    break
                } catch {
                    lastError = error

                    if DCInitInfoCache.shared.checkNetworkError(from: error) == true {
                        continue
                    } else {
                        break
                    }
                }
            }

            // 如果所有重試都失敗
            if let error = lastError {
                DCInitInfoCache.shared.setError(error)
            }
            completion()
        }
    }
    
    /// 刷新 推薦人標題 In case 語系切換
    static func updateReferrerTitle() {
        NYDataProvider.sharedInstance().getReferrerTitle { referrerTitle, _ in
            if let referrerTitle = referrerTitle, !referrerTitle.isEmpty {
                NYAppSettingsHelper.sharedInstance().leftMenuRefereeTitle = referrerTitle
            }
        }
    }
}

private extension NYLaunchHelper {
    private static var isConfigured = false
    private static let maxRetryCount = 3
    private static let baseDelay: TimeInterval = 0.5  // 基礎延遲時間
    private static let maxDelay: TimeInterval = 4.0   // 最大延遲時間
    
    private static func calculateDelay(attempt: Int) -> TimeInterval {
        // 計算指數退避時間：baseDelay * (2 ^ attempt)
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
        
        // 加入抖動：在 exponentialDelay 的 75%~100% 之間隨機
        let jitterDelay = exponentialDelay * (0.75 + Double.random(in: 0...0.25))
        
        // 確保不過最大延遲時間
        return min(jitterDelay, maxDelay)
    }
    
    static func configureDesignCloud(
        country: String,
        shopId: NSNumber,
        domain: String
    ) {
        guard !isConfigured else { return }
        
        let language = NYLocalizationString.selectedLanguageCode
        let isDevelopment = !["beta", "release"].contains(NYGlobalData.apiEnvironment().lowercased())
        
        DesignCloudBridge.setShopConfig(
            market: country.lowercased(),
            shopId: shopId.stringValue,
            domain: domain,
            defaultLang: language,
            isDevelopment: isDevelopment,
            cloudServerEnvIndex: 0,  // 固定使用 kernelDefault
            isDebug: false  // 固定關閉 debug 模式
        )
        
        isConfigured = true
    }
    
    static func validateInitInfo(_ info: DCInitInfo) throws {
        // 1. 檢查 DC 是否可用
        guard info.isAvailable else { return }
                
        // 2. 檢查是否有首頁設定
        guard let meta = info.homePageMeta,
              meta.existHomePage
        else { return }
        
        // 3. 檢查首頁路徑是否有效
        guard meta.homePagePath != nil
        else {
            throw DCInitInfoCache.InitializationError.invalidHomePath
        }
    }
}

extension NSNotification.Name {
    static let designCloudInitializationCompleted = Notification.Name("DesignCloudInitializationCompleted")
    static let nyLogoutNotification = Notification.Name("NYLogoutNotification")
    static let nyLoginNotification = Notification.Name("NYLoginNotification")
}
//
//  NYCartHTTPSClient.h
//  Pods
//
//  Created by Eric Huang on 2020/8/26.
//

#import "NYHTTPSClient.h"

@interface NYCartHTTPSClient : NYHTTPSClient

/// 給 Apple Pay 用的 paymentClient。API domain 來自 /PayV2/RequestPayProcessUrlV2
- (NYCartHTTPSClient *)paymentClient;
- (void)updatePaymentClientDomain:(NSString *)domain;

@end
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
//  NYDataProvider.m
//  NineYiShopping
//
//  Created by stedy on 13/3/8.
//  Copyright (c) 2013年 Julie Lin. All rights reserved.
//

//只會出現model相關的import，不該出現跟view有關的class
#import "NYDataProvider.h"
#import "NYCookieManager.h"
#import "NSArray+Map.h"
#import "NYPHPHTTPClient.h"
#import "NYECouponHTTPSClient.h"
#import "NYCDNHTTPClient.h"
#import "NYHTTPSClient.h"
#import "NYTrackingClient.h"
#import "NYFacebookGraphAPIClient.h"
#import "NYCartHTTPSClient.h"
#import "NYFTSHTTPClient.h"

#import "NYShopObject.h"
#import "NYShopCategoryObject.h"
#import "NYItemObject.h"
#import "NYItemStatusEnum.h"
#import "NYADElementObject.h"
#import "NYShopAppObject.h"
#import "NYShopDiscountObject.h"
#import <NYCore/NYCore-Swift.h>
#import "NYCouponDetailObject.h"
#import "NYPopularListObject.h"
#import "NYInfoModuleObject.h"
#import "NYMemberCardObject.h"
#import "NYServiceInfoObject.h"
#import "NYGraphQLTemporaryDataMediator.h"

#import "NYFacebookHelper.h"
#import <NYCore/UIDevice+PlatformHelper.h>
#import <NYCore/NSString+Regex.h>
#import "NYUserDefault.h"
#import "NYBaseURLConfig.h"
#import "NYActivityDetailObject.h"

#import <NYCore/NSString+TimestampDecoder.h>
#import <NYCore/NSDate+Calculate.h>

#import <AdSupport/AdSupport.h>

NSString * const kNYDataKey = @"DATA_KEY";
NSString * const kNYAPIDataKey = @"Data";
NSString * const kNYAPIReturnCodeKey = @"ReturnCode";
NSString * const kNYAPIMessage = @"Message";

@interface NYDataProvider ()
@property (nonatomic) NSNumber *shopId;
@property (nonatomic, assign) NSTimeInterval lastUpdate;
@end

@implementation NYDataProvider
+ (instancetype)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init]; // or some other init method
    });

    [_sharedObject keepAlive];
    return _sharedObject;
}

-(instancetype)init{
    self = [super init];
    if (self) {
        self.shopId = [NYGlobalData shopId];
        self.lastUpdate = 0;
    }
    return self;
}

- (NSString *)GUID {
    return [[NYCookieManager sharedManager] cookieValueFromLocal:kCOOKIE_NAME_GUID];
}

- (NSString *)VDID {
    return [[NYCookieManager sharedManager] VDID];
}

#pragma mark - AD Layout

-(void)getShopLayoutTemplateDataForShopId:(NSInteger)shopId
                                andADCode:(NSString *)adCode
                        completionHandler:(DataSourceCompletionHandler)handler
{
    NSString *mobileAdCode = [@"MobileHome_" stringByAppendingString:adCode];
    NSString *path = [NSString stringWithFormat:@"LayoutTemplateData/GetLayoutTemplateData/%@/%@", @(shopId), mobileAdCode];
    
    [[NYCDNHTTPClient sharedClient]
     getPath:path
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON)
         {
             NSArray *object = [self parseLayoutTemplate:adCode withJSONDictionary:JSON];
             handler(@{
                     kAPI_AD_CODE_KEY : adCode,
                     kDATA_KEY : object,
                     }, nil );
         }
         else
         {
             handler( nil, NineYiErrorWithCode(0) );
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        handler( nil, error );
    }];

}

#pragma mark - shop home item

-(void)getShopBasicInfoForShopId:(NSInteger)shopId
               completionHandler:(DataSourceCompletionHandler)handler
{
    NSString *path = [NSString stringWithFormat:@"Shop/GetShopintroductionV2/%@", @(shopId)];
    
    [[NYCDNHTTPClient sharedClient]
     getPath:path
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             if( JSON[@"ShopIntroduceEntity"] == [NSNull null] ) {
                 handler( nil, NineYiErrorWithCode(0));
             }
             else {
                 handler(@{kDATA_KEY : [[NYShopObject alloc] initWithJSONDict: JSON]}, nil );
             }
         }
         else {
             handler( nil, NineYiErrorWithCode(0) );
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        handler( nil, error );
     }];
}

#pragma mark - category list

-(void)getShopCategoryListV2ForShopId:(int)shopId
                    completionHandler:(DataSourceCompletionHandler)handler {
    //Create client
    NSString *path = [NSString stringWithFormat:@"Shop/GetShopCategoryListV2/%d", shopId];
    
    //Parameter
    NSDictionary *params = @{};
    
    //Get (大致跟舊的一樣)
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:params success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        if (JSON) {
            handler(@{kDATA_KEY : [self parseShopCategoryListWithJSONDictionary:JSON]}, nil );
        }
        else {
            handler(nil, NineYiErrorWithCode(0));
        }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         //Error
         handler(nil, error);
     }];
}

#pragma mark - Item detail page related

- (void)getItemStockListBySaleProductSKUIdList:(NSArray *)SKUIdList
                            completionHandler:(void(^)(NSArray *sellingQtyList, NSError *error))completionHandler {
    NSString *idListString = [SKUIdList componentsJoinedByString:@","];
    
    [[NYHTTPSClient sharedClient] postPath:@"ProductStock/GetSellingQtyListNew"
                                parameters:@{@"ids" : idListString}
                                   success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             NSArray *sellingQtyList = JSON;
             completionHandler(sellingQtyList, nil);
         } else {
             completionHandler(nil, NineYiErrorWithCode(0));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

- (void)getSalePageRealTimeData:(NSNumber *)salepageId completionHandler:(DataSourceCompletionHandler)handler {
    [[NYHTTPSClient sharedClient]
     postPath:[NSString stringWithFormat:@"SalePage/GetSalePageRealTimeData/%@", salepageId]
     parameters:nil
     success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
         handler(@{kDATA_KEY : responseObject}, nil );
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        handler(nil, error);
     }];
}

- (void)getItemDetailPageMoreInfoWithShopID:(NSNumber *)shopID
                                 salePageID:(NSNumber *)salePageID
                          completionHandler:(DataSourceCompletionHandler)completionHandler {
    NSString *path = [NSString stringWithFormat:@"SalePage/GetSalePageMoreInfo/%@", salePageID];
    NSDictionary *params = @{@"source":@"iOSApp",
                             @"shopId":shopID};
    
    [[NYCDNHTTPClient sharedClient]
     getPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             completionHandler(JSON, nil);
         } else {
             completionHandler(nil, NineYiErrorWithCode(0));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

- (void)getCMSSalePageListByIds:(NSArray *)ids
           includeSalePageGroup:(BOOL)includeSalePageGroup
          withCompletionHandler:(DataSourceCompletionHandler)handler{
    if (!ids) {
        handler(nil, NineYiErrorWithCode(0));
        return;
    }
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    [params setValue:_shopId forKey:@"shopId"];
    NSString * paramString = [ids componentsJoinedByString:@","];
    [params setValue:paramString forKey:@"salePageIds"];
    [params setValue:(includeSalePageGroup)? @"true" : @"false" forKey:@"includeSalePageGroup"];
    [params setValue:false forKey:@"includeInvisibleSalepage"];
    
    [[NYHTTPSClient sharedClient]
     getPath: @"Cms/GetSalePageListById"
     parameters: params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        if (!JSON) {
            handler(nil, NineYiErrorWithCode(0));
            return;
        }
        
        if (![JSON[kNYAPIDataKey] isKindOfClass:[NSArray class]]) {
            handler(nil, NineYiErrorWithCode(0));
            return;
        }
        
        NSArray *itemObjects = [JSON[kNYAPIDataKey] map: (id)^(id o) {
            return [[NYItemObject alloc] initWithJSONDict:o];
        }];
        
        if (!itemObjects) {
            handler(nil, NineYiErrorWithCode(0));
        } else {
            handler(@{kNYAPIDataKey : itemObjects}, nil);
        }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler(nil, error);
     }];
}

-(void)deleteFavoriteProductForSalePageId:(NSString *)salePageId
                        completionHandler: (DataSourceCompletionHandler) handler
{
   [[NYHTTPSClient sharedClient]
     postPath: @"TraceSalePageList/DeleteItem"
    parameters: @{ @"salePageId":salePageId, @"ShopId":_shopId }
     success:^(NSURLSessionDataTask *operation, id JSON) {
         handler(@{}, nil ); // this command has no return value, always success
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler( nil, error );
     }];

}

-(void)getFavoriteProductListWithCompletionHandler:(DataSourceCompletionHandler) handler
{
    // TODO: 用delegate是暫解，避免NineyiAppApi與NYGraphQLClient兩個pods相互循環引用。最佳解是把使用方(NYLoginHelper, NYFavoriteManager)與NYDataProvider切乾淨
    [[NYGraphQLTemporaryDataMediator shared] getFavoriteProductListWithCompletionHandler: handler];
}

// FIXME: this seems redundant with the fact that we can get the listing of the products already
// 24.8 移除 收藏舊邏輯, 新邏輯詳見 initFavoriteList
// 先保留 comment, 觀察幾個版本再移除
//-(void)getFavoriteProductCountWithCompletionHandler:(DataSourceCompletionHandler) handler
//{
//    [[NYHTTPSClient sharedClient] postPath:@"TraceSalePageList/GetCount" parameters:@{@"ShopId":_shopId} success:^(NSURLSessionDataTask *operation, NSNumber *count) {
//        handler(@{kDATA_KEY:count}, nil);
//    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
//        handler(nil, error);
//    }];
//}

-(void)insertFavoriteProductForSalePageId:(NSString *)salePageId
                        completionHandler: (DataSourceCompletionHandler) handler
{
    // NOTE: 原本的邏輯是先去拉server-side的收藏商品數再打InsertItem，似乎沒必要。
    // 直接打InsertItem就好了，server-side的收藏商品上限是100個，如果要收藏第101個商品時，
    // Server會將最舊的收藏商品踢掉，然後將第101個商品加入
    [[NYHTTPSClient sharedClient]
     postPath:@"TraceSalePageList/InsertItem"
     parameters:@{@"salePageId":salePageId, @"ShopId":_shopId}
     success:^(NSURLSessionDataTask *operation, id res) {
         handler(@{}, nil); // this command has no return value, always success
     } failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler(nil, error);
     }];
}

// Recently browsed APIs
// FIXME
-(NSArray*)getRecentlyBrowsedSalePageIdsAndTitles
{
    NSUserDefaults* pref = [NSUserDefaults standardUserDefaults];
    NSMutableArray *prev20 = [[pref objectForKey: kPREF_RECENTLY_BROWSED] mutableCopy];
    if (prev20.count > 20) {
        [prev20 removeObjectsInRange:NSMakeRange(20, prev20.count - 20)];
    }
    return prev20;
}

-(void)addRecentlyBrowsedForSalePageId:(NSInteger)salePageId andTitle:(NSString*)title
{
    NSUserDefaults* pref = [NSUserDefaults standardUserDefaults];
    NSMutableArray* recents = [[pref objectForKey: kPREF_RECENTLY_BROWSED] mutableCopy];
    if( !recents ) recents = [NSMutableArray new];
    if (!title) title = @"";
    
    NSDictionary* entry = @{ @"SalePageId" : @(salePageId), @"Title" : title};
    
    // first, remove existing pair from the array
    [recents removeObject: entry];
    
    // then, append the new one to the "top"
    [recents insertObject: entry atIndex: 0];
    
    // trim if too long
//    if( recents.count > 20 ) [recents removeLastObject];
    
    [pref setObject: recents forKey: kPREF_RECENTLY_BROWSED];
    [pref synchronize];
}

-(void)clearAllRecentlyBroswedList{
    NSUserDefaults* pref = [NSUserDefaults standardUserDefaults];
    [pref removeObjectForKey:kPREF_RECENTLY_BROWSED];
    [pref synchronize];    
}

#pragma mark - cart


-(void)getCartItemCountWithCompletionHandler:(DataSourceCompletionHandler)handler{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NYCartHTTPSClient sharedClient] postPath:@"ShoppingCartV2/GetCount" parameters:@{ @"ShopId":_shopId} success:^(NSURLSessionDataTask *operation, NSNumber *count) {
         handler(@{kDATA_KEY : count}, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler( nil, error );
    }];
}

#pragma mark - o2o

- (void)getLocationPushInformation:(int)shopId userLocation:(CLLocation *)userLocation completionHandler:(DataSourceCompletionHandler)handler {
    //Create client
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"Lbs/GetLbsList";

    //Parameter
    NSDictionary *parameters = @{@"shopId"  : @(shopId),
                                 @"lat"     : @(userLocation.coordinate.latitude),
                                 @"lon"     : @(userLocation.coordinate.longitude)};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        handler(JSON, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        handler(nil, error);
    }];
}

- (void)getCouponListByShopId:(NSNumber *)shopId CouponType:(NSString *)type completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYPHPHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"o2o/api/coupon/%@/%@", type, shopId]
                 parameters:nil
                    success:^(NSURLSessionDataTask *operation, id JSON) {
                        if (JSON) {
                            NSArray *couponDictionaries = (NSArray *)JSON[@"feed"];
                            __block NSMutableArray *coupons = [NSMutableArray arrayWithCapacity:couponDictionaries.count];
                            [couponDictionaries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

                                if ([@"my" isEqualToString:type]) {
                                    NYCouponDetailObject *couponDetailObject = [[NYCouponDetailObject alloc] initMyCouponWithJSONDictionary:obj];
                                    [coupons addObject:couponDetailObject];
                                }
                                else {
                                    NYCouponDetailObject *couponDetailObject = [[NYCouponDetailObject alloc] initWithJSONDictionary:obj];
                                    [coupons addObject:couponDetailObject];
                                }
                            }];
                            handler (@{kDATA_KEY:coupons}, nil);
                        }else {
                            handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
                        }
                    }
                    failure:^(NSURLSessionDataTask *operation, NSError *error) {
                        handler (nil, error);
                    }];
}


- (void)getCouponListByShopId:(NSNumber *)shopId IsAllCoupon:(BOOL)isAllCoupon completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYPHPHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"o2o/api/coupon/%@/%@", (isAllCoupon) ? @"list" : @"my", shopId]
             parameters:nil
                success:^(NSURLSessionDataTask *operation, id JSON) {
                    if (JSON) {
                        NSArray *couponDictionaries = (NSArray *)JSON[@"feed"];
                        __block NSMutableArray *coupons = [NSMutableArray arrayWithCapacity:couponDictionaries.count];
                        [couponDictionaries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            NYCouponDetailObject *couponDetailObject = [[NYCouponDetailObject alloc] initWithJSONDictionary:obj];
                            [coupons addObject:couponDetailObject];
                        }];
                        handler (@{kDATA_KEY:coupons}, nil);
                    }else {
                        handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
                    }
                }
                failure:^(NSURLSessionDataTask *operation, NSError *error) {
                    handler (nil, error);
                }];
}

- (void)getCouponDetailByCouponId:(NSString *)couponId shopId:(int)shopId completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYPHPHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"o2o/api/coupon/detail/%@", couponId]
             parameters:nil
                success:^(NSURLSessionDataTask *operation, id JSON) {
                    __block NYCouponDetailObject *couponDetailObject;
                    if (([JSON[@"feed"] count] > 0) && (![[[JSON valueForKeyPath:@"feed.type"] firstObject] isEqualToString:@"location"])) {
                        [(NSArray *)JSON[@"feed"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            couponDetailObject = [[NYCouponDetailObject alloc] initWithJSONDictionary:obj];
                        }];
                    }else {
                        couponDetailObject = [[NYCouponDetailObject alloc] initWithJSONDictionary:nil];
                    }
                    handler (@{kDATA_KEY:couponDetailObject}, nil);
                } failure:^(NSURLSessionDataTask *operation, NSError *error) {
                    handler (nil, error);
                }];
}

- (void)takeCouponActionByCouponId:(int)couponId completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYPHPHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"o2o/api/v2/coupon/take/%d", couponId]
                                 parameters:@{@"source": @"iOSApp",
                                              @"supportVersion": eCouponSupportVersion}
                 success:^(NSURLSessionDataTask *operation, id JSON) {
                     if (JSON) {
                         handler (JSON, nil);
                     }else {
                         handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
                     }
                 }
                 failure:^(NSURLSessionDataTask *operation, NSError *error) {
                     handler (nil, error);
                 }];
}

- (void)useCouponActionByCouponId:(int)couponId userCouponID:(NSNumber*)userCouponID userLocation:(CLLocation *)userLocation completionHandler:(DataSourceCompletionHandler)handler
{
    NSDictionary* para = nil;
    if (userCouponID)
    {
        para = @{@"user_coupon_id":userCouponID,
                 @"lat":[NSNumber numberWithFloat:userLocation.coordinate.latitude],
                 @"lon":[NSNumber numberWithFloat:userLocation.coordinate.longitude]
                 };
    }
    else
    {
        para = @{@"lat":[NSNumber numberWithFloat:userLocation.coordinate.latitude],
                 @"lon":[NSNumber numberWithFloat:userLocation.coordinate.longitude]
                 };
    }
    
    [[NYPHPHTTPClient sharedClient] postPath:[NSString stringWithFormat:@"o2o/api/coupon/use/%d", couponId]
              parameters:para
                 success:^(NSURLSessionDataTask *operation, id JSON) {
                     if (JSON) {
                         handler (JSON, nil);
                     }else {
                         handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
                     }
                 }
                 failure:^(NSURLSessionDataTask *operation, NSError *error) {
                     handler (nil, error);
                 }];
}

- (void)getCouponSerialNumberByUserCouponID:(NSNumber *)userCouponID
                          completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYPHPHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"o2o/api/coupon/serialnumber/%@", userCouponID]
                                 parameters:nil
                                    success:^(NSURLSessionDataTask *operation, id JSON) {
                                        //12/25note:  出現錯誤訊息時JSON還是有東西，return code是空字串，錯誤判斷在caller做
                                        handler (JSON, nil);
                                    }
                                    failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                        handler (nil, error);
                                    }];
}

#pragma mark - eCoupon

- (void)setMemberECouponByCode:(NSString *)code
                        shopId:(NSNumber *)shopId
                   eCouponType:(NYECouponType)eCouponType
             CompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYECouponHTTPSClient sharedClient]
     postPath:@"ECoupon/SetMemberECouponByCode"
     parameters:@{@"Code": code,
                  @"ShopId": shopId,
                  @"GUID": [self GUID],
                  @"eCouponType":[NYECouponTypeConverter eCouponTypeStringByType:eCouponType],
                  @"source":@"iOSApp",
                  @"supportVersion":eCouponSupportVersion}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         handler (JSON, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)setMemberECouponByECouponId:(NSNumber *)eCouponId CompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYECouponHTTPSClient sharedClient]
     postPath:@"ECoupon/SetMemberECouponByECouponId"
     parameters:@{@"ECouponId": eCouponId,
                  @"GUID": [self GUID],
                  @"eCouponType":[NYECouponTypeConverter eCouponTypeStringByType:NYECouponTypeAll],
                  @"source":@"iOSApp",
                  @"supportVersion":eCouponSupportVersion}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             handler (JSON, nil);
         }
         else {
             handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)setMemberFirstDownloadECouponByECouponId:(NSNumber *)firstDownloadECouponId CompletionHandler:(DataSourceCompletionHandler)handler {
    [[NYECouponHTTPSClient sharedClient]
     postPath:@"ECoupon/SetMemberFirstDownloadECouponByECouponId"
     parameters:@{@"ECouponId": firstDownloadECouponId,
                  @"GUID": [self GUID]}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             handler (JSON, nil);
         }
         else {
             handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
 
}

#pragma mark - Shop Discount

-(void)getShopDiscountDataWithPromotionId:(NSInteger)promotionId CompletionHandler:(DataSourceCompletionHandler)handler{
    
    NSDictionary *parameters = @{@"id":@(promotionId)};

    [[NYHTTPSClient sharedClient]
     getPath: @"Promotion/GetDetail"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, NSDictionary* JSON) {
         if (JSON) {
             //Note:舊API, error時會傳string, 這邊硬轉成新式的Error格式
             if ([JSON isKindOfClass:[NSString class]]) {
                 NSString *message = (NSString *)JSON;
                 JSON = @{kNYAPIReturnCodeKey : @"API0002",
                          kNYAPIDataKey : [NSDictionary dictionary],
                          kNYAPIMessage : message};
             }
             
             handler(@{kDATA_KEY : JSON}, nil);
         }
         else {
             handler( nil, NineYiErrorWithCode(NYDataProviderErrorCodeNoJSON) );
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler( nil, error );
     }];
}

#pragma mark - Location Wizard

- (void)getMemberInfoWithCompletionHandler:(DataSourceCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"Location/GetMemberInfo" parameters:nil success:^(NSURLSessionDataTask *operation, NSDictionary *JSON) {
         if ([JSON[kNYAPIReturnCodeKey] isEqualToString:@"API0001"]) {
             if ([JSON[kNYAPIDataKey] count] == 0) {
                 completionHandler(nil, NineYiErrorWithCode(NYDataProviderErrorCodeNoJSON));
             }
             else {
                completionHandler(@{kDATA_KEY : JSON}, nil);
             }
         }
         else {
             completionHandler(nil, NineYiErrorWithCode(NYDataProviderErrorCodeNoJSON));
         }
     } failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

#pragma mark
// get hot item list
-(void)getShopSalePageHotItemListByCategoryId:(int)categoryId
                                      orderBy:(NSString *)orderBy
                                   salePageId:(int)salePageId
                            completionHandler: (DataSourceCompletionHandler) handler{
    NSString *path = [@"SalePage/GetSalePageHotListByShopCategoryId/" stringByAppendingFormat:@"%d", categoryId];
    
    NSDictionary *params =
    @{
    @"o"       : orderBy,
    @"sid"    : [NSNumber numberWithInt:salePageId]
    };
    
    [[NYCDNHTTPClient sharedClient]
     getPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
         NSMutableArray *allData = [NSMutableArray array];
         for (NSArray *data in JSON[@"data"]) {
             NSArray *newArray = [allData arrayByAddingObjectsFromArray:data];
             allData = [newArray mutableCopy];
         }
         NSArray *result = [allData map: (id)^(id o) {
             return [[NYItemObject alloc] initWithJSONDict: o];
         }];
         handler(@{kDATA_KEY : result}, nil );
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler( nil, error );
     }];
}

//notification center

-(void)getNotificationDataByShopId:(NSInteger)shopId
                        startIndex:(NSInteger)startIndex
                          maxCount:(NSInteger)maxCount
                 completionHandler:(DataSourceCompletionHandler) handler{
    
    NSDictionary *params =
    @{
    @"shopId"       : [NSString stringWithFormat:@"%ld", (long)shopId],
    @"startIndex"   : [NSString stringWithFormat:@"%ld", (long)startIndex],
    @"maxCount"     : [NSString stringWithFormat:@"%ld", (long)maxCount]
    };
    
    [[NYHTTPSClient sharedClient]
     postPath: @"notificationcenter/getfrontendList"
     parameters: params
     success:^(NSURLSessionDataTask *operation, NSArray* JSON) {
         NSArray* result = [JSON map: (id)^(id obj) {
             return [[RoutingObject alloc] initWithJson:obj];
         }];
         handler(@{kDATA_KEY : result}, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler( nil, error );
     }];
}

// app push notification setting

-(void)getAllAPPPushNotificationSettingWithCompletionHandler:(DataSourceCompletionHandler) handler
{
    NSDictionary *params = @{@"GUID":[self GUID]};
    
    [[NYHTTPSClient sharedClient]
     postPath: @"APPNotification/GetAllAppPhshProfileDataV2"
     parameters: params
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if ([@"API0001" isEqualToString:JSON[kNYAPIReturnCodeKey]]) {
             handler(@{kDATA_KEY:JSON[kNYAPIDataKey][@"APPPushProfileList"]}, nil);
         }
         else {
             handler(nil, [NSError errorWithDomain:JSON[kNYAPIMessage] code:0 userInfo:@{@"GUID": [self GUID]}]);
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler(nil, error);
     }];
}

// Sever 說原本的 API "APPNotification/GetAllAppPhshProfileDataV2/" 是拿 Read/Write DB 會影響效能
// Launch 時改打新 API 拿 Readonly DB 資料，參數和回傳 data 都和原本一樣
-(void)getAllAPPPushNotificationSettingFromReadOnlyDBWithCompletionHandler:(DataSourceCompletionHandler) handler
{
    NSDictionary *params = @{@"GUID":[self GUID]};
    
    [[NYHTTPSClient sharedClient]
     postPath: @"APPNotification/GetAllAppPushProfileDataFromReplica"
     parameters: params
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if ([@"API0001" isEqualToString:JSON[kNYAPIReturnCodeKey]]) {
             handler(@{kDATA_KEY:JSON[kNYAPIDataKey][@"APPPushProfileList"]}, nil);
         }
         else {
             handler(nil, [NSError errorWithDomain:JSON[kNYAPIMessage] code:0 userInfo:@{@"GUID": [self GUID]}]);
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler(nil, error);
     }];
}

- (void)set91AppPushNotificationSettingForType:(NSString *)notificationType
                                       isOn:(BOOL)isOn
                          completionHandler:(AppPushSettingCompletionHandler)completionHandler {
    NSDictionary *params = @{@"appPushProfileDataEntites":@[@{@"GUID":[self GUID],
                                                              @"type":notificationType,
                                                              @"switchValue" : [NSNumber numberWithBool:isOn]
                                                              }]};
    
    [self set91AppPushProfileWithParams:params completionHandler:completionHandler];
}

- (void)set91AppPushProfileWithParams:(NSDictionary *)params completionHandler:(AppPushSettingCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"APPNotification/SetAPPPushProfileDataV2" parameters:params requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        completionHandler(returnCode, message, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

// check web api status
- (void)checkWebApiStatusWithCompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient]
     getPath:@"APPNotification/checkwebapistatus"
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if ([@"online" isEqualToString:JSON[@"Status"]]) {
             handler (JSON, nil);
         }else {
             handler (JSON, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnErrorMessage));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

#pragma mark - Cookie Related

- (void)registerAppWithVDID:(NSString *)VDID
                     shopId:(NSNumber *)shopId
                   platform:(NSString *)platform
     sendSynchronousRequest:(BOOL)sendSynchronousRequest
          completionHandler:(DataSourceCompletionHandler)completionHandler {
    NSString *appVer = [NYGlobalData appVersionString];
    NSDictionary *dict = @{@"UDID":VDID,
                           @"ShopID":shopId,
                           @"platformID":platform,
                           @"AdvertisingId":[[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString]?:@"",
                           @"appVer": appVer,
                           @"source":@"iOSApp",
                           @"device":@"Mobile"};
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:0 // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    NSString *jsonString;
    if (!jsonData) {
        NSLog(@"Got an error: %@", error);
    }
    else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    NSString *path = [NSString stringWithFormat:@"APPNotification/APPRegister?appVer=%@", appVer];
    [[NYHTTPSClient sharedClient]
     postPath:path
     dataStr:jsonString
     sendSynchronousRequest:sendSynchronousRequest
     success:^(NSURLSessionDataTask *operation, id JSON) {
         completionHandler(@{kDATA_KEY:JSON}, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

- (void)updateServerUDIDWithCompletionHandler:(DataSourceCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] syncGetPath:@"APPNotification/UpdateUDID" parameters:@{@"GUID":[self GUID], @"UDID":[self VDID]} success:^(NSURLSessionDataTask *operation, id responseObject) {
        completionHandler(@{kDATA_KEY:responseObject}, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

- (void)getUauthWithCompletionHandler:(DataSourceCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] syncGetPath:@"APPNotification/GetuAUTHByGUID"
                                   parameters:@{@"GUID":[self GUID]}
                                      success:^(NSURLSessionDataTask *operation, id responseObject) {
                                          completionHandler(@{kDATA_KEY:responseObject}, nil);
                                      } failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                          completionHandler(nil, error);
                                      }];
}

#pragma mark - Facebook Related

- (void)getFanPageDataWithFanPageID:(NSString *)fanPageID
                        accessToken:(NSString *)accessToken
                          postCount:(NSNumber *)count
                  completionHandler:(void (^)(NSArray *posts, NSError *error))completionHandler {
    NSString *path = [NSString stringWithFormat:@"%@/posts", fanPageID];
    
    NSString *fields = @"from,message,picture,link,source,name,description,icon,type,status_type,object_id,created_time,child_attachments";
    NSDictionary *params = @{@"limit": @(25),
                             @"access_token": accessToken,
                             @"fields": fields
                             };
    
    [[NYFacebookGraphAPIClient sharedClient] getPath:path parameters:params success:^(NSURLSessionDataTask *operation, NSDictionary *JSON) {
        completionHandler(JSON[@"data"], nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

- (void)getFanPagePhotoURLsWithAccessToken:(NSString *)accessToken
                                    postID:(NSString *)postID
                         completionHandler:(void (^)(NSArray *attachment, NSError *error))completionHandler {
    NSString *path = [NSString stringWithFormat:@"%@/attachments", postID];
    [[NYFacebookGraphAPIClient sharedClient] getPath:path parameters:@{@"access_token":accessToken} success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSArray *attachments = [[responseObject valueForKeyPath:@"data.subattachments.data.media.image.src"] lastObject];
        if (![attachments isKindOfClass:[NSArray class]]) {
            attachments = [responseObject valueForKeyPath:@"data.media.image.src"];
        }
        NSMutableArray *attachmentURLs = @[].mutableCopy;
        [attachments enumerateObjectsUsingBlock:^(NSString *urlString, NSUInteger idx, BOOL *stop) {
            NSURL *url = [NSURL URLWithString:urlString];
            if (url) {
                [attachmentURLs addObject:url];
            }
        }];
        completionHandler(attachmentURLs, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

#pragma mark - 2.0

#pragma mark - APP Configuration

- (void)getCDNDomainSynchronouslyWithCompletionHandler:(DataSourceCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] syncGetPath:@"APPNotification/GetWebAPICDNDomain"
                                   parameters:nil
                                      success:^(NSURLSessionDataTask *operation, id responseObject) {
                                          completionHandler(@{kDATA_KEY:responseObject[@"CDNDomain"]}, nil);
                                      }
                                      failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                          completionHandler(nil, error);
                                      }];
}

#pragma mark - Referee

- (void)getAppRefereeSettings:(NSInteger)shopId completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"AppReferee/GetAppRefereeProfile"]
     parameters:@{@"shopId" : @(shopId)}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         handler (@{kDATA_KEY:JSON}, nil);
     } failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)getSimpleLocationList:(NSInteger)shopId completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"AppReferee/GetLocationList"]
     parameters: @{@"shopId" : @(shopId)}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         handler (@{kDATA_KEY:JSON}, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)getLocationEmployeeList:(NSInteger)shopId locationId:(NSInteger)locationId completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"AppReferee/GetLocationEmployeeList"]
     parameters: @{@"shopId" : @(shopId), @"locationId" : @(locationId)}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         handler (@{kDATA_KEY:JSON}, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)insertAppRefereeWithLocationId:(NSInteger)locationId
                                 empId:(NSString *)empId
                        isRequireLogin:(BOOL)isRequireLogin
                            sourceType:(NSString *)sourceType
                       linkClickedTime:(NSString *)linkClickedTime
                     completionHandler:(DataSourceCompletionHandler)handler {
    NSDictionary *paramDic = @{@"guid":[self GUID],
                               @"shopId":_shopId,
                               @"locationId": @(locationId),
                               @"empId": empId,
                               @"isRequireLogin": (isRequireLogin)? @"true" : @"false",
                               @"appRefereeSourceTypeDef": sourceType};
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:paramDic];
    
    if (linkClickedTime) {
        [params setObject:linkClickedTime forKey:@"linkClickedTime"];
    }
    
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"AppReferee/InsertAppReferee"]
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        if (handler != nil) {
            handler (@{kDATA_KEY:JSON}, nil);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        if (handler != nil) {
            handler (nil, error);
        }
    }];
}

- (void)getAppRefereeWithIsRequireLogin:(BOOL)isRequireLogin
                      completionHandler:(void(^)(NSDictionary *responseObject, NSError *error))completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"AppReferee/GetAppReferee"
                                parameters:@{@"guid":[self GUID],
                                             @"shopId":_shopId,
                                             @"isRequireLogin": (isRequireLogin)? @"true" : @"false"}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
                                       completionHandler(responseObject, nil);
                                   } failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                       completionHandler(nil, error);
                                   }];
}


- (void)getReferrerTitleWithCompletionHandler:(void(^)(NSString *referrerTitle, NSError *error))completionHandler {
    [[NYHTTPSClient sharedClient]
     getPath:@"AppReferee/GetReferrerTitle"
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id responseObject) {
         NSString *referrerTitle = nil;
         if ([responseObject isKindOfClass:[NSDictionary class]]) {
             NSDictionary *json = (NSDictionary *)responseObject;
             id data = json[kNYAPIDataKey];
             if ([data isKindOfClass:[NSDictionary class]]) {
                 id title = ((NSDictionary *)data)[@"ReferrerTitle"];
                 if ([title isKindOfClass:[NSString class]]) {
                     referrerTitle = (NSString *)title;
                 }
             }
         }
         if (completionHandler) {
             completionHandler(referrerTitle, nil);
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         if (completionHandler) {
             completionHandler(nil, error);
         }
     }];
}

#pragma mark - Activity (活動頁公版)

// 側欄使用 - 已轉換成BFF
- (void)getActivityListForShopID:(NSNumber *)shopID compleionHandler:(ActivityListCompletionHandler)handler {

    // input
    // { 'shopId': 0 }
    NSDictionary *params = @{@"shopId": shopID};

    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:[NSString stringWithFormat:@"Activity/GetActivityList"]
            parameters: params
            success:^(NSURLSessionDataTask *operation, id JSON) {
                if ( JSON && JSON[kNYAPIDataKey] ) {
                    NSMutableArray *activityList = [NSMutableArray array];
                    for (NSDictionary *dict in JSON[kNYAPIDataKey] ) {
                        NYActivityDetailObject *activity = [NYActivityDetailObject activityObjectWithJSONDict:dict];
                        if ( activity ) {
                            [activityList addObject:activity];
                        }
                    }

                    NSString *message    = GET_VAL_WITH_DEFAULT(JSON, kNYAPIMessage, @"");
                    NSString *returnCode = GET_VAL_WITH_DEFAULT(JSON, kNYAPIReturnCodeKey, @"");
                    handler(activityList, message, returnCode, nil);
                }
            }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
                handler ([NSArray array], nil, nil, error); // return an empty Activity array
            }];
}

- (void)getActivityDetailForShopId:(NSNumber *)shopId andActivityId:(NSNumber *)activityId
                  compleionHandler:(ActivityDetailCompletionHandler)handler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];

    // input
    // { 'shopId': 0}
    NSDictionary *params = @{@"shopId": shopId};
    [client
            getPath:[NSString stringWithFormat:@"Activity/GetActivityDetail/%@", activityId]
         parameters: params
            success:^(NSURLSessionDataTask *operation, id JSON) {
                NYActivityDetailObject *activity = nil;
                if ( JSON && JSON[kNYAPIDataKey] ) {
                    activity = [NYActivityDetailObject activityObjectWithJSONDict:JSON[kNYAPIDataKey]];
                }
                NSString *message    = GET_VAL_WITH_DEFAULT(JSON, kNYAPIMessage, @"");
                NSString *returnCode = GET_VAL_WITH_DEFAULT(JSON, kNYAPIReturnCodeKey, @"");
                handler(activity, message, returnCode, nil);
            }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
                handler (nil, nil, nil, error); // return an empty Activity array
            }];

}
#pragma mark - Program Logic

#pragma mark - Private Helpers

-(NSDictionary*)parseShopSalesPageQueryResponseWithJSONDictionary:(NSDictionary*)dict
{
    NSMutableDictionary *res = [NSMutableDictionary new];
    
    res[ @"categoryName"            ] = dict[ @"name"                   ];
    res[ @"categoryAllItemCount"    ] = dict[ @"count"                  ];
    res[ @"parentCategoryName"      ] = dict[ @"parentCategoryText"     ];
    res[ @"parentCategoryId"        ] = dict[ @"parentCategoryId"       ];
    res[ @"categoryNameForDisplay"  ] = dict[ @"name"    ];
    if( [dict.allKeys containsObject: @"listmode"] )
        res[ @"listmode"            ] = dict[ @"listmode"               ];
    res[ kAPI_ITEMS_KEY             ] = [dict[ @"data" ] map: (id)^(id o) {
        return [[NYItemObject alloc] initWithJSONDict: o];
    }];
    
    return res;
}

-(NSDictionary *)parseCategoryQueryResponseWithJSONDictionary:(id)dict
{
    NSMutableDictionary *res = [NSMutableDictionary new];

    NSString *statusValue;
    id statusdef = dict[@"statusdef"];
    if ([statusdef isKindOfClass:[NSString class]]) {
        statusValue = statusdef;
    }
    else if ([statusdef isKindOfClass:[NSNumber class]]) {
        NSNumber *status = (NSNumber *)statusdef;
        if ([@(1) isEqualToNumber:status]) {
            statusValue = @"Normal";
        }
        else if ([@(2) isEqualToNumber:status]) {
            statusValue = @"Hide";
        }
    }
    
    [res setValue:statusValue forKey:@"status"];
    res[ @"categoryName"            ] = dict[ @"name"                   ];
    res[ @"categoryAllItemCount"    ] = dict[ @"count"                  ];
    res[ @"parentCategoryName"      ] = dict[ @"parentCategoryText"     ];
    res[ @"parentCategoryId"        ] = dict[ @"parentCategoryId"       ];
    res[ @"categoryNameForDisplay"  ] = dict[ @"name"    ];
    res[ @"listmode"                ] = dict[ @"listmode"               ];
    
    __block NSMutableArray *promotionDetailList = @[].mutableCopy;
    [dict[@"promotionDetailList"] enumerateObjectsUsingBlock:^(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
        //Parse start and end time (time interval since 1970)
        NSTimeInterval startTimeStamp = [dict[@"StartTime"] decodeAPIFormatTimeStamp] / 1000;
        NSTimeInterval endTimeStamp = [dict[@"EndTime"] decodeAPIFormatTimeStamp] / 1000;
        
        //Current time
        NSTimeInterval currentTimeStamp = [NSDate date].timeIntervalSince1970;
        
        //Check range
        if (currentTimeStamp >= startTimeStamp && currentTimeStamp < endTimeStamp) {
            //優惠活動在時間區間內才會加入
            NYShopDiscountObject *discountObject = [[NYShopDiscountObject alloc] initWithJSONDict:dict];
            [promotionDetailList addObject:discountObject];
        }
    }];

    res[@"promotionDetailList"] = promotionDetailList;
    
    res[ kAPI_ITEMS_KEY             ] = [dict[ @"data" ] map: (id)^(id o) {
        return [[NYItemObject alloc] initWithJSONDict: o];
    }];
    
    if ([promotionDetailList firstObject]) {
        res[@"discount"] = [promotionDetailList firstObject];
    }
    
    return res;
}

-(NSDictionary *)parseSalePageListJSONDictionary:(NSDictionary *)oldData {
    //Products
    NSArray *productionJSONs = oldData[@"SalePageList"];
    NSMutableArray *productionList = [NSMutableArray array];
    [productionJSONs enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull json, NSUInteger idx, BOOL * _Nonnull stop) {
        [productionList addObject:[[NYItemObject alloc] initWithJSONDict:json]];
    }];
    
    //Data
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [[oldData allKeys] enumerateObjectsUsingBlock:^(id _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        [dataDict setObject:oldData[key] forKey:key];
    }];
    [dataDict setObject:productionList forKey:@"SalePageList"];
    
    return dataDict;
}

- (NSArray *)parsePromotionListJSONArray:(NSArray *)promotionJSONs {
    NSMutableArray *promotionList = [NSMutableArray array];
    [promotionJSONs enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull json, NSUInteger idx, BOOL * _Nonnull stop) {
        //Parse start and end time (time interval since 1970)
        NSTimeInterval startTimeStamp = [json[@"StartTime"] decodeAPIFormatTimeStamp] / 1000;
        NSTimeInterval endTimeStamp = [json[@"EndTime"] decodeAPIFormatTimeStamp] / 1000;
        
        //Current time
        NSTimeInterval currentTimeStamp = [NSDate date].timeIntervalSince1970;
        
        //Check range
        if (currentTimeStamp >= startTimeStamp && currentTimeStamp < endTimeStamp) {
            //優惠活動在時間區間內才會加入
            NYShopDiscountObject *discountObject = [[NYShopDiscountObject alloc] initWithJSONDict:json];
            [promotionList addObject:discountObject];
        }
    }];
    
    return promotionList;
}

-(NSArray *)parseLayoutTemplate:(NSString *)adCode withJSONDictionary:(id)dict
{
    adCode = [adCode stringByReplacingOccurrencesOfString:@"MobileHome_" withString:@""];
    return [dict map: (id)^(id o) {
        return [[NYADElementObject alloc] initWithADCode: adCode andJSONDictionary: o];
    }];
}

-(NSArray *)parseShopCategoryListWithJSONDictionary:(id)dict
{
    return [dict[ @"List"] map: (id)^(id o) {
        return [[NYShopCategoryObject alloc] initWithJSONDict: o];
    }];
}

-(NSString *)parseItemStatusWithJSONDictionary:(NSString *)dict{
    NSDictionary *itemStatusHashTable = @{
        @"Normal" : @(ItemStatusNormal).stringValue,
        @"NoStart" : @(ItemStatusNoStart).stringValue,
        @"SoldOut" : @(ItemStatusSoldOut).stringValue,
        @"UnListing" : @(ItemStatusUnListing).stringValue,
        @"IsClosed" : @(ItemStatusIsClosed).stringValue
    };
    
    if ([[itemStatusHashTable allKeys] containsObject:dict]) {
        return itemStatusHashTable[dict];
    }
    else {
        return @(ItemStatusUnknown).stringValue;
    }
    
}

#pragma mark - 2.5 InfoModule (資訊模組)

- (void)infoModuleGetInfoModuleListWithShopId:(NSNumber *)shopId
                                         Type:(NYInfoModuleType)infoModuleType
                                   startIndex:(NSInteger)startIndex
                                     maxCount:(NSInteger)maxCount
                             compleionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *infoObjectsList, NSError *error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];

    //Path
    NSMutableString *infoModulePathString = [NSMutableString stringWithString:@"InfoModuleV2/"];
    switch (infoModuleType) {
        case NYInfoModuleTypeAlbum:
            [infoModulePathString appendString:@"GetAlbumList"];
            break;
            
        case NYInfoModuleTypeArticle:
            [infoModulePathString appendString:@"GetArticleList"];
            break;
            
        case NYInfoModuleTypeVideo:
            [infoModulePathString appendString:@"GetVideoList"];
            break;
            
        default:
            break;
    }
    
    //Parameter
    NSDictionary *parameters = @{@"shopId"      : shopId,
                                 @"startIndex"  : @(startIndex),
                                 @"maxCount"    : @(maxCount)};

    
    //GET
    [client getPath:infoModulePathString parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        NSMutableArray *infoModuleObjectsList = [NSMutableArray array];
        id data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]){
            NSArray *list = data[@"List"];
            NSDictionary *shopInfoDict = data[@"Shop"];
            
            [list enumerateObjectsUsingBlock:^(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
                
                //Parse & Add to list
                NYInfoModuleObject *infoObj = [[NYInfoModuleObject alloc] initWithJSONDictionaryFromWebAPI:dict shopInfoDictionary:shopInfoDict];
                [infoModuleObjectsList addObject:infoObj];
            }];
        }

        
        completionHandler(returnCode, message, infoModuleObjectsList, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)infoModuleGetInfoModuleDetailWithInfoModuleObject:(NYInfoModuleObject *)infoModuleObj
                                         compleionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *dict, NSError *error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    //Path
    NSMutableString *infoModulePathString = [NSMutableString stringWithString:@"InfoModuleV2/"];
    NSString *idParameterString = @"albumId";
    switch (infoModuleObj.type) {
        case NYInfoModuleTypeAlbum:
            [infoModulePathString appendString:@"GetAlbumDetail"];
            idParameterString = @"albumId";
            break;
            
        case NYInfoModuleTypeArticle:
            [infoModulePathString appendString:@"GetArticleDetail"];
            idParameterString = @"articleId";
            break;
            
        case NYInfoModuleTypeVideo:
            [infoModulePathString appendString:@"GetVideoDetail"];
            idParameterString = @"videoId";
            break;
            
        default:
            break;
    }
    
    //Parameter
    NSDictionary *parameters = @{idParameterString : infoModuleObj.objId};
    
    //GET
    [client getPath:infoModulePathString parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];

        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 2.5 Location (門市資訊)

- (void)locationModuleGetCityAreaListWithShopId:(NSNumber *)shopId
                            isEnableRetailStore:(BOOL)isEnableRetailStore
                              completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *cityAreaInfoJSON, NSError *error))completionHandler {
    NSString *path = @"LocationV2/GetCityAreaList";
    
    //Parameter
    NSString *isEnableRetailStoreStr = isEnableRetailStore ? @"true" : @"false";
    NSDictionary *parameters = @{@"shopId" : shopId,
                                 @"IsEnableRetailStore" : isEnableRetailStoreStr};
    
    //Get
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        //Call back
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetAreaLocationListWithShopId:(NSNumber *)shopId
                                             areaId:(NSNumber *)areaId
                                isEnableRetailStore:(BOOL)isEnableRetailStore
                                         startIndex:(NSInteger)startIndex
                                           maxCount:(NSInteger)maxCount
                                  completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoJSONList, NSError *error))completionHandler {
    NSString *path = @"LocationV2/GetLocationListByArea";
    
    //Parameter
    NSString *isEnableRetailStoreStr = isEnableRetailStore ? @"true" : @"false";
    NSDictionary *parameters = @{@"shopId"      : shopId,
                                 @"areaId"      : areaId,
                                 @"IsEnableRetailStore" : isEnableRetailStoreStr,
                                 @"startIndex"  : @(startIndex),
                                 @"maxCount"    : @(maxCount)};
    
    //GET
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *list = JSON[kNYAPIDataKey][@"List"];
        
        //Call back
        completionHandler(returnCode, message, list, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetLocationStoreWithStoreId:(NSNumber *)storeId
                                completionHandler:(void (^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError *error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationV2/GetLocationDetail";
    
    //Parameter
    NSMutableDictionary * parameters = [NSMutableDictionary dictionary];
    [parameters setValue:storeId forKey:@"locationId"];
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        if ([data isKindOfClass:[NSDictionary class]]) {
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(returnCode, message, nil, nil);
        }
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetLocationListWithShopId:(NSNumber *)shopId
                                   userLocation:(CLLocation *)userLocation
                            isEnableRetailStore:(BOOL)isEnableRetailStore
                              completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoJSONList, BOOL isSorted, NSInteger totalCount, NSError *error))completionHandler {
    NSString *path = @"LocationV2/GetLocationList";
    
    //Parameter
    NSMutableDictionary * parameters = [NSMutableDictionary dictionary];
    [parameters setValue:shopId forKey:@"shopId"];
    
    //如果有傳經緯度才帶給Server
    if (userLocation) {
        [parameters setValue:@(userLocation.coordinate.latitude) forKey:@"lat"];
        [parameters setValue:@(userLocation.coordinate.longitude) forKey:@"lon"];
    }
    //如果有填才帶給Server
    if (isEnableRetailStore) {
        NSString *isEnableRetailStoreStr = isEnableRetailStore ? @"true" : @"false";
        [parameters setValue:isEnableRetailStoreStr forKey:@"isEnableRetailStore"];
    }
    
    //GET
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        // API format check.
        // If API format is incorrect, try add a empty result instead APP crash
        // see https://bts.nine-yi/edit_bug.aspx?id=14392 for more detail
        id data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]){
            NSArray *list = data[@"List"];
            NSNumber *isSorted = data[@"StoreSort"];
            NSNumber *totalCount = JSON[kNYAPIDataKey][@"LocationCount"];
            completionHandler(returnCode, message, list, [isSorted boolValue], totalCount.integerValue, nil);
        }else{
            completionHandler(returnCode, message, [NSArray array], NO, 0, nil);
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, NO, 0, error);
    }];
}

- (void)locationModuleGetLocationListWithShopId:(NSNumber *)shopId
                                      searchKey:(NSString *)searchKey
                                     startIndex:(NSInteger)startIndex
                                       maxCount:(NSInteger)maxCount
                            isEnableRetailStore:(BOOL)isEnableRetailStore
                              completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoJSONList, BOOL isSorted, NSInteger totalCount, NSError *error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationV2/QueryLocationList";
    
    //Parameter
    NSMutableDictionary * parameters = [NSMutableDictionary dictionary];
    [parameters setValue:shopId forKey:@"shopId"];
    [parameters setValue:searchKey forKey:@"searchKey"];
    [parameters setValue:@(startIndex) forKey:@"startIndex"];
    [parameters setValue:@(maxCount) forKey:@"maxCount"];
    
    //如果有填才帶給Server
    if (isEnableRetailStore) {
        NSString *isEnableRetailStoreStr = isEnableRetailStore ? @"true" : @"false";
        [parameters setValue:isEnableRetailStoreStr forKey:@"isEnableRetailStore"];
    }
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        // API format check.
        // If API format is incorrect, try add a empty result instead APP crash
        // see https://bts.nine-yi/edit_bug.aspx?id=14392 for more detail
        id data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]){
            NSArray *list = data[@"LocationList"];
            NSNumber *isSorted = data[@"StoreSort"];
            NSNumber *totalCount = JSON[kNYAPIDataKey][@"LocationCount"];
            completionHandler(returnCode, message, list, [isSorted boolValue], totalCount.integerValue, nil);
        }else{
            completionHandler(returnCode, message, [NSArray array], NO, 0, nil);
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, NO, 0, error);
    }];
}

- (void)locationModuleGetCityLocationListWithShopId:(NSNumber *)shopId
                                             cityId:(NSNumber *)cityId
                                         startIndex:(NSInteger)startIndex
                                           maxCount:(NSInteger)maxCount
                                  completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoJSONList, NSError *error))completionHandler {
    NSString *path = @"LocationV2/GetLocationListByCity";
    
    //Parameter
    NSDictionary *parameters = @{@"shopId"      : shopId,
                                 @"cityId"      : cityId,
                                 @"startIndex"  : @(startIndex),
                                 @"maxCount"    : @(maxCount)};
    
    //GET
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *list = JSON[kNYAPIDataKey][@"List"];
        
        //Call back
        completionHandler(returnCode, message, list, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetOverseaLocationListWithShopId:(NSNumber *)shopId
                                            startIndex:(NSInteger)startIndex
                                              maxCount:(NSInteger)maxCount
                                     completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoJSONList, NSError *error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationV2/GetOverseaLocationList";
    
    //Parameter
    NSDictionary *parameters = @{@"shopId"      : shopId,
                                 @"startIndex"  : @(startIndex),
                                 @"maxCount"    : @(maxCount)};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *list = JSON[kNYAPIDataKey][@"List"];
        
        //Call back
        completionHandler(returnCode, message, list, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 2.52 LocationAvailable (門市購)

- (void)locationModuleCheckAndArrangeAvailableLocationWithAddress:(NSString *)address
                                                       locationId:(NSNumber *)locationId
                                                 memberLocationId:(NSNumber *)memberLocationId
                                                completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error))completionHandler {
    [self locationModuleGetAvailableLocationListWithAddress:address
                                                 locationId:locationId
                                            isCheckDistance:YES
                                           memberLocationId:memberLocationId
                                          completionHandler:^(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error) {
        if (completionHandler) {
            completionHandler(returnCode, responseMessage, storeInfoDict, error);
        }
    }];
}

- (void)locationModuleArrangeAvailableLocationWithLocationId:(NSNumber *)locationId
                                           completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error))completionHandler {
    [self locationModuleGetAvailableLocationListWithAddress:nil
                                                 locationId:locationId
                                            isCheckDistance:NO
                                           memberLocationId:nil
                                          completionHandler:^(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error) {
        if (completionHandler) {
            completionHandler(returnCode, responseMessage, storeInfoDict, error);
        }
    }];
}

- (void)locationModuleArrangeLocationWithLocationId:(NSNumber *)locationId
                                  completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error))completionHandler {
    [self locationModuleGetAvailableLocationListWithAddress:nil
                                                 locationId:locationId
                                            isCheckDistance:NO
                                           memberLocationId:nil
                                          completionHandler:^(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error) {
        if (completionHandler) {
            completionHandler(returnCode, responseMessage, storeInfoDict, error);
        }
    }];
}

- (void)locationModuleGetAvailableLocationListWithAddress:(NSString *)address
                                               locationId:(NSNumber *)locationId
                                          isCheckDistance:(BOOL)isCheckDistance
                                         memberLocationId:(NSNumber *)memberLocationId
                                        completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"ShopId"];
    // 告訴 server 是否要打 Google API 來計算距離（因為要錢），目前只有門市外送會是 true，門市自取、選擇服務門市都是 false
    [parameters setValue:isCheckDistance ? @"true" : @"false" forKey:@"IsCheckDistance"];
    if (locationId) {
        [parameters setValue:locationId forKey:@"CurrentLocation"];
    }
    if (address) {
        [parameters setValue:address forKey:@"Address"];
    }
    if (memberLocationId) {
        // 告訴 server 常用收件人資料，購物車顯示要用
        [parameters setValue:memberLocationId forKey:@"MemberLocationId"];
    }
    
    [[NYHTTPSClient sharedClient]
     postPath: @"LocationV2/ArrangeAvailableLocation"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetMemberLocationListWithIsRetailStoreUse:(BOOL)isRetailStoreUse
                                              completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoList, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];

    if (isRetailStoreUse) {
        NSString *isRetailStoreUseStr = isRetailStoreUse ? @"true" : @"false";
        [parameters setValue:isRetailStoreUseStr forKey:@"isRetailStoreUse"];
    }

    [[NYHTTPSClient sharedClient]
     getPath: @"MemberLocationV2/GetMemberLocationList"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(returnCode, message, data, nil);
        } else {
            // 未登入時 data 為空，當 failure 處理
            completionHandler(nil, nil, nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

// 小時達外送「商品缺貨查看鄰近庫存」API，取得「該商品附近門市庫存資料列表」 [VSTS 203998]
- (void)getRetailStoreDeliveryStockInfoListWithSalePageId:(NSNumber *)salePageId
                                    completionHandler:(void (^)(NSString *returnCode, NSDictionary *storeInfo, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];
    [parameters setValue:salePageId forKey:@"SalePageId"];

    [[NYHTTPSClient sharedClient]
     getPath: @"RetailStore/GetHasStockLocationInfo"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(returnCode, data, nil);
        } else {
            // 無資料時也當 failure 處理
            completionHandler(nil, nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

// 小時達外送「輸入地址頁切換門市」選店 API，取得「三公里內可供切換的門市列表」 [VSTS 203763]
- (void)getRetailStoreDeliveryAvailableStoreListWithAddress:(NSString *)address
                                          completionHandler:(void (^)(NSArray *storeInfoList, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:address forKey:@"Address"];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];

    [[NYHTTPSClient sharedClient]
     getPath: @"RetailStore/GetArrangeableLocation"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSArray *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(data, nil);
        } else {
            // 無資料時也當 failure 處理
            completionHandler(nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

// 小時達選店 API，加入總店（預設店）維度 [VSTS 199714]
- (void)hadSelectedRetailStoreServiceWithCompletionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *retailStoreInfo, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];

    [[NYHTTPSClient sharedClient]
     getPath: @"RetailStore/HadSelectedService"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(returnCode, message, data, nil);
        } else {
            // 無資料時也當 failure 處理
            completionHandler(nil, nil, nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)removeMemberLocationWithMemberLocationId:(NSNumber *)memberLocationId
                               completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoList, NSError *error))completionHandler {
    // Parameter
    NSString *lang = [NYLocalizationString selectedLanguageCode].length > 0 ? [NYLocalizationString selectedLanguageCode] : @"en-US";
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];
    [parameters setValue:lang forKey:@"lang"];
    [parameters setValue:memberLocationId forKey:@"MemberLocationId"];

    [[NYHTTPSClient sharedClient]
     postPath: @"MemberLocationV2/RemoveMemberLocation"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(returnCode, message, data, nil);
        } else {
            // 未登入時 data 為空，當 failure 處理
            completionHandler(nil, nil, nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetNearByLocationListWithAddress:(NSString *)address
                                              location:(CLLocation *)location
                                  isEnabledRetailStore:(BOOL)isEnabledRetailStore
                                             takeCount:(NSNumber *)takeCount
                                     completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeList, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];

    if (address) {
        [parameters setValue:address forKey:@"Address"];
    }
    
    if (location) {
        NSNumber *latitude = [NSNumber numberWithDouble:location.coordinate.latitude];
        NSNumber *longitude = [NSNumber numberWithDouble:location.coordinate.longitude];
        [parameters setValue:latitude forKey:@"Latitude"];
        [parameters setValue:longitude forKey:@"Longitude"];
    }
    
    if (isEnabledRetailStore) {
        NSString *isEnabledRetailStoreStr = isEnabledRetailStore ? @"true" : @"false";
        [parameters setValue:isEnabledRetailStoreStr forKey:@"IsEnabledRetailStore"];
    }
    
    NSNumber *count = @5;
    if (takeCount) {
        count = takeCount;
    }
    [parameters setValue:count forKey:@"TakeCount"];

    [[NYHTTPSClient sharedClient]
     postPath: @"LocationV2/GetNearbyLocations"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(returnCode, message, data, nil);
        } else {
            // 無資料時也當 failure 處理
            completionHandler(nil, nil, nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getActiveOrdersWithShopId:(NSNumber * _Nullable)shopId
                completionHandler:(void (^ _Nullable)(NSString * _Nullable returnCode, NSString * _Nullable responseMessage, NSDictionary * _Nullable activeOrderJSON, NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"MemberTradesOrder/GetActiveOrders";

    //Parameter
    NSDictionary *parameters = @{@"ShopId"  : shopId};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        NSDictionary *activeOrderJSON = @{};
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            activeOrderJSON = data;
        }
        completionHandler(returnCode, message, activeOrderJSON, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 2.8X 門市庫存查詢
/// 取得門市庫存資料 By City
- (void)fetchStockInStoresByCity:(NSNumber *)cityID
                           skuID:(NSNumber *)skuID
               completionHandler:(void (^)(NSString * _Nullable returnCode,
                                           NSDictionary * _Nullable data,
                                           NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"gateway/stock/getStockInStoresByCity";
    NSDictionary *parameters = @{
        @"cityId": cityID,
        @"skuId": skuID
    };
    
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        completionHandler(returnCode, data, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

/// 取得門市庫存資料 By Area
- (void)fetchStockInStoresByArea:(NSNumber *)areaID
                           skuID:(NSNumber *)skuID
               completionHandler:(void (^)(NSString * _Nullable returnCode,
                                           NSDictionary * _Nullable data,
                                           NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"gateway/stock/getStockInStoresByArea";
    NSDictionary *parameters = @{
        @"areaId": areaID,
        @"skuId": skuID
    };
    
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        completionHandler(returnCode, data, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

/// 取得海外門市庫存資料
- (void)fetchStockInOverseaStoress:(NSNumber *)skuID
                 completionHandler:(void (^)(NSString * _Nullable returnCode,
                                             NSDictionary * _Nullable data,
                                             NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"gateway/stock/getStockInOverseaStores";
    NSDictionary *parameters = @{
        @"skuId": skuID,
    };
    
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];

        completionHandler(returnCode, data, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

/// 取得門市庫存說明文案
- (void)fetchStockInStoresDescriptionWithCompletionHandler:(void (^ _Nullable)(NSString * _Nullable returnCode, NSDictionary * _Nullable data, NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"gateway/stock/getStockInStoresDescription";
    NSDictionary *parameters = @{
        @"ShopId": self.shopId,
    };
    
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];

        completionHandler(returnCode, data, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark - 2.60 目前購物車金額提示（僅限全聯環境）

- (void)getCurrentShoppingCartAmountWithServiceTypeString:(NSString *)serviceTypeString
                                        completionHandler:(void (^)(NSString * _Nullable,
                                                                    NSDictionary * _Nullable,
                                                                    NSError * _Nullable))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"ShoppingCartV4/GetShoppingCartAmountPreview";
    NSDictionary *parameters = @{
        @"ShopId" : self.shopId,
        @"ServiceType" : serviceTypeString
    };
    
    // Get
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *amountJSON = @{};
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            amountJSON = data;
        }
        completionHandler(returnCode, amountJSON, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark - 2.73 購物車數量（僅限全聯環境）

- (void)getCurrentShoppingCartAllQtyWithCompletionHandler:(void (^)(NSString * _Nullable returnCode,
                                                                    NSArray * _Nullable allQtyData,
                                                                    NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = [NSString stringWithFormat:@"ShoppingCartQty/GetAllQty/%@", self.shopId];
    NSDictionary *parameters = @{
        @"shopId" : self.shopId
    };
    
    // Get
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSArray *allQtyJSON = @[];
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]] && data[@"AllQty"]) {
            allQtyJSON = data[@"AllQty"];
        }
        completionHandler(returnCode, allQtyJSON, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark - 2.75 PXPay 是否有升級全支付會員（僅限全聯環境）

- (void)getPXPayHasPXPayPlusMemberWithCompletionHandler:(void (^)(NSString * _Nullable returnCode,
                                                                  NSDictionary * _Nullable data,
                                                                  NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = [NSString stringWithFormat:@"ThirdPartyPay/GetMemberIsUpgradeToPXPayPlus"];
    NSDictionary *parameters = @{
        @"shopId" : self.shopId
    };
    
    // Get
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *dataJSON = @{};
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            dataJSON = data;
        }
        completionHandler(returnCode, dataJSON, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark - 2.71.10 全聯快速通關

- (void)getLastOrderWithServiceTypeString:(NSString *)serviceTypeString
                               completion:(void (^)(NSString * _Nullable,
                                                    NSDictionary * _Nullable,
                                                    NSError * _Nullable))completion {
    NSDictionary *parameters = @{
        @"ShopId" : self.shopId,
        @"ServiceType" : serviceTypeString
    };
    
    // 有 Cache，但不能過 CDN
    // Get
    [[NYHTTPSClient sharedClient]
     getPath:@"Rapidcheckout/GetLastOrder"
     parameters:parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];
        completion(returnCode, data, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

- (void)getShoppingDataWithServiceType:(NSString *)serviceTypeString
                            completion:(void (^)(NSDictionary *cartJSONDict,
                                                 NSString *jsonString,
                                                 NSString *returnCode,
                                                 NSString *message,
                                                 NSError *error))completion {
    NSDictionary *parameters = @{
        @"shopId" : self.shopId,
        @"source" : @"iOSApp",
        @"device" : @"Mobile",
        @"channel" : @"RapidCheckout",
        @"appVer" : [NYGlobalData appVersionString],
        @"serviceType" : serviceTypeString,
        @"eCouponVersion" : eCouponSupportVersion,
        @"PromoCodePoolGroupId": [NYUserDefault promoCodePoolGroupID] ? : @"",
        @"PromoCode":[NYUserDefault promoCode] ? : @""
    };
    
    // Get
    [[NYCartHTTPSClient sharedClient]
     getPath:@"RapidCheckout/GetShoppingData"
     parameters:parameters
     success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *cartJSONDict = response[kNYAPIDataKey];
        NSString *jsonString = [self jsonStringWithData:cartJSONDict];
        completion(cartJSONDict, jsonString, returnCode, message, nil);
        
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completion(nil, nil, nil, nil, error);
    }];
}

- (void)sendShoppingDataWithJSONString:(NSString *)jsonString
                            completion:(void (^)(NSDictionary *data,
                                                 NSString *returnCode,
                                                 NSString *message,
                                                 NSError *error))completion {
    NSDictionary *parameters = @{
        @"Context" : jsonString
    };
    
    // Post
    [[NYCartHTTPSClient sharedClient]
     postPath:@"RapidCheckout/Send"
     parameters:parameters
     success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *data = response[kNYAPIDataKey];
        
        completion(data, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completion(nil, nil, nil, error);
    }];
}

/// 用 API "RapidCheckout/GetShoppingData" Response 整包 Data 轉成的 JSON 字串，要當作 確認付款 API "RapidCheckout/Send" 的 Parameter
- (NSString *)jsonStringWithData:(NSDictionary *)data {
    if ([NSJSONSerialization isValidJSONObject:data]) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingWithoutEscapingSlashes error:nil];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return jsonString;
    }
    return @"";
}

#pragma mark - 2.6 LocationPoint (門市積點活動)

- (void)locationPointGetEventListWithShopId:(NSNumber *)shopId
                          completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *eventInfoJSON, NSError * error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationRewardPoint/GetRewardPointList";

    //Parameter
    NSDictionary *parameters = @{@"ShopId"  : shopId};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        //此API, Data在API0002時會是null
        NSArray *list = @[];
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            list = data[@"RewardPointList"];
        }
        
        //Call back
        completionHandler(returnCode, message, list, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}


- (void)locationPointGetEventDetailWithEventId:(NSNumber *)eventId
                             completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *eventInfoDictionary, NSError * error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationRewardPoint/GetRewardPointDetail";
    
    //Parameter
    NSDictionary *parameters = @{@"RewardPointId"   : eventId};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        //此API, Data在API0002時會是null
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSNull class]]) {
            data = @{};
        }
        
        //Call back
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}


- (void)locationPointGetUserCurrentPointWithEventId:(NSNumber *)eventId
                                  completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSNumber *userCurrentPoint, NSError * error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationRewardPoint/GetMemberRewardPoint";
    
    //Parameter
    NSDictionary *parameters = @{@"RewardPointId"   : eventId};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        //此API, Data在API0002時會是null
        NSNumber *currentPoint = @(0);
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            currentPoint = data[@"MemberRewardPoint"];
        }
        
        //Call back
        completionHandler(returnCode, message, currentPoint, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 2.6 FreeGift (滿額贈)

- (void)freeGiftGetSalePageGiftDetailWithGiftId:(NSNumber *)giftId
                              completionHandler:(void (^)(NSDictionary *giftInfomation, NSError *error))completionHandler {
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"SalePage/GetIsGiftSalePage/%@", giftId]
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id responseObject) {
         //Success
         NSDictionary *giftInfo = responseObject[kNYAPIDataKey];
         
         //Call back
         completionHandler(giftInfo, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         //Fail
         completionHandler(nil, error);
     }];
}

#pragma mark - 2.30 GetShopStaticSetting (來自API的APP設定)

- (void)getShopStaticSettingWithCompletionHandler:(void (^)(NSDictionary *responseObject, NSError *error))completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"ShopStaticSetting/GetShopStaticSetting"
                                parameters:@{@"shopId" : _shopId,
                                             @"appVer" : [NYGlobalData appVersionString],
                                             @"source" : @"iOSApp",
                                             @"device" : @"Mobile"}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
                                       completionHandler(responseObject, nil);
                                   }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                       completionHandler(nil, error);
                                   }];
}

#pragma mark 2.45.0 打 API 取得指定的 group name & key 的設定

- (void)getShopStaticSettingWithGroupName:(NSString *)groupName
                                      key:(NSString *)key
                               completion:(void (^)(NSString *returnCode, NSDictionary *data, NSError *error))completion {
    [[NYCDNHTTPClient sharedClient]
     getPath:@"ShopStaticSetting/GetShopStaticSettingByGroupNameKey"
     parameters:@{@"shopId" : _shopId,
                  @"groupName" : groupName,
                  @"key" : key}
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[@"ReturnCode"];
        NSDictionary *data = responseObject[@"Data"];
        completion(returnCode, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

#pragma mark - 2.43.0 GetShopPayShippingTypeDisplaySettingList

- (void)getShopPayShippingTypeDisplaySettingListWithShopId:(NSNumber *)shopId
                                         completionHandler:(void (^)(NSString *retrunCode, NSDictionary *displaySettingJSONListDict))completionHandler {
    
    NYHTTPSClient *client = [NYCDNHTTPClient sharedClient];
    NSString *path = [NSString stringWithFormat: @"Shop/GetShopPayShippingTypeDisplaySettingList/%@", shopId];
    
    //GET
    [client getPath:path parameters:nil requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *shippingDetailJSONList = JSON[kNYAPIDataKey];
        
        //Call back
        completionHandler(returnCode, shippingDetailJSONList);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil);
    }];
}

#pragma mark - 2.78.0 GetPayTypeChannelList
- (void)getPayTypeChannelListWithShopId:(NSNumber *)shopId
                      completionHandler:(void (^)(NSString *retrunCode, NSDictionary *payTypeChannelJSONListDict))completionHandler {
    NYHTTPSClient *client = [NYCDNHTTPClient sharedClient];
    NSString *path = [NSString stringWithFormat: @"Shop/GetPayTypeChannelList/%@", shopId];
    
    // GET
    [client getPath:path
         parameters:nil
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        // Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *payTypeChannelJSONListDict = JSON[kNYAPIDataKey];
        
        // Callback
        completionHandler(returnCode, payTypeChannelJSONListDict);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        // Fail
        completionHandler(nil, nil);
    }];
}

#pragma mark - 2.43 91 Track V2

- (void)sendNineYiTrackV2CollectWithParameters:(NSDictionary *)para {
    [self sendNineYiTrackCollectWithParameters:para path:@"v2/collect"];
}

- (void)sendNineYiTrackCollectWithParameters:(NSDictionary *)para path:(NSString *)path {
    //Get (Note:這行為看起來要用POST, 不過是要用GET)
    [[NYTrackingClient sharedClient] getPath:path parameters:para requestType:NYHTTPRequestTypeHTTP responseType:NYHTTPResponseTypeHTTP success:^(NSURLSessionDataTask *operation, id responseObj) {
        //Success (Do nothing)
        //成功會回一個1x1 px的圖片 (據說仿GA)
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail (Do nothing)
    }];
}

- (void)keepAlive {
    // 有開啟 session management 才打 KeepAlive
    if (![NYUserDefault isSessionManagementEnabled]) {
        return;
    }

    NSTimeInterval lastUpdate = self.lastUpdate;
    NSDate *now = [NSDate date];
    NYDateDifference diff = [now dateDifferenceWithTimeInterval:lastUpdate];
    
    NSInteger debounceTimeMinutes = [NYUserDefaultV2 keepAliveDebounceMinutes];
    if (diff.days > 0 || diff.hours > 0 || diff.minutes >= debounceTimeMinutes) {
        self.lastUpdate = [now timeIntervalSince1970];
        NSDictionary *param = @{@"shopId" : [NYGlobalData shopId],
                                @"lang" : @"zh-TW"};
        [[NYHTTPSClient sharedClient]
         getPath:@"AuthV4/KeepAlive"
         parameters:param
         success:nil
         failure:nil];
    }
}

#pragma mark - CMS 再買一次模組

- (void)getBuyAgainModuleProductsWithListDisplayCount:(NSNumber *)listDisplayCount
                                           completion:(void (^)(NSString *returnCode,
                                                                NSArray *data,
                                                                NSError *error))completion {
    NSString *path = @"MemberPurchasedSummary/GetLatestPurchasedList";
    NSDictionary *params = @{@"shopID" : self.shopId,
                             @"listDisplayCount" : listDisplayCount};
    
    [[NYHTTPSClient sharedClient]
     getPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSArray *productJSONs = responseObject[kNYAPIDataKey];
        completion(returnCode, productJSONs, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

#pragma mark - Payments
- (void)fetchMultipassTokenWithCompletion:(void (^ _Nonnull)(NSString * _Nullable returnCode,
                                                             NSString * _Nullable data,
                                                             NSString * _Nullable message,
                                                             NSError * _Nullable error))completion {
    NSString *path = @"/authv4/getMultipassToken";
    NSString *guid = [[NYCookieManager sharedManager] cookieValueFromLocal:kCOOKIE_NAME_GUID];
    NSDictionary *params = @{@"ShopId": _shopId,
                             @"DeviceType": @"iOSApp",
                             @"DeviceGuid": guid};
    
    // POST
    [[NYHTTPSClient sharedClient] postPath:path
                                parameters:params
                                   success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *data = JSON[kNYAPIDataKey];
        NSString *message = JSON[kNYAPIMessage];
        completion(returnCode, data, message, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, nil, error);
    }];
}

#pragma mark - 商品掃描

//寶雅掃描
- (void)getProductSKUInfoWithBarcode:(NSString *)barcode
                   completionHandler:(void (^)(NSString * _Nullable returnCode,
                                               NSString * _Nullable responseMessage,
                                               NSDictionary * _Nullable data,
                                               NSError * _Nullable error))completion {
    NSString *path = [NSString stringWithFormat:@"/gateway/scan/%@/productskuinfo", self.shopId.stringValue];
    NSDictionary *params = @{@"barcode": barcode,};
    
    [[NYHTTPSClient sharedClient]
     getPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        NSDictionary *productJSONs = responseObject[kNYAPIDataKey];
        
        completion(returnCode, message, productJSONs, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, nil, error);
    }];
}

//產品化掃描 (非寶雅）24.6 目前只有 HK 單店使用
- (void)getProductSKUInfoWithQRcode:(NSString *)qrcode
                   completionHandler:(void (^)(NSString * _Nullable returnCode,
                                               NSString * _Nullable responseMessage,
                                               NSDictionary * _Nullable data,
                                               NSError * _Nullable error))completion {
    NSString *path = [NSString stringWithFormat:@"/gateway/scan/%@/channelskuinfo", self.shopId.stringValue];
    NSDictionary *params = @{@"barcode": qrcode};
    [[NYHTTPSClient sharedClient]
     getPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, id responseObject) {

        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        NSDictionary *productJSONs = responseObject[kNYAPIDataKey];
        
        completion(returnCode, message, productJSONs, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, nil, error);
    }];
}


#pragma mark - 23.8 LINE 購物支援 App 訂單
- (void)setFRRelatedInfo:(NSString *)frCode
                 fr2Code:(NSString *)fr2Code
       completionHandler:(void (^)(NSString * _Nullable returnCode, NSError * _Nullable error))completion {
    NSString *path = @"FR/Set";
    NSDictionary *params = @{@"ShopId": self.shopId.stringValue,
                             @"Fr": frCode,
                             @"Fr2": fr2Code};
    
    // POST
    [[NYHTTPSClient sharedClient] postPath:path
                                parameters:params
                                   success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        completion(returnCode, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}

#pragma mark - 24.1 HTML 內容多語系
- (void)getHTMLMultilingualContentBy:(NSString *)urlString
                   completionHandler:(void (^)(NSString * _Nullable htmlContent,
                                               NSError * _Nullable error))completion {
    if (!urlString || urlString.length <= 0) {
        completion(nil, [NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL. URL is nil"}]);
        return;
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlString]
                                                             completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            completion(result, error);
        });
    }];
    
    [task resume];
}

#pragma mark - 24.5 個人化推薦
/// 供 CMS 後台、前台、App 判斷該店是否啟用 jooii 個人化推薦商品服務狀態開關（來源：BAPI 開關狀態）
- (void)getJooiiRecommendationSetting:(void (^)(NSDictionary * _Nullable data, NSError * _Nullable error))completion {
    NSString *shopId = [[NYGlobalData shopId] stringValue];
    NSString *path = [NSString stringWithFormat:@"salepage-listing/api/recommendation/setting-get/%@/jooii", shopId];
    
    [[NYFTSHTTPClient sharedClient] getPath:path
                                 parameters:@{}
                                    success:^(NSURLSessionDataTask *operation, id responseObject) {
        completion(responseObject, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}

#pragma mark - 24.12 商品特色標語
- (void)getMetaFieldTemplates:(void (^)(NSDictionary * _Nullable data, NSError * _Nullable error))completion {
    NSString *shopId = [[NYGlobalData shopId] stringValue];
    NSString *path = [NSString stringWithFormat:@"salepage-listing/api/template/%@", shopId];
    
    [[NYFTSHTTPClient sharedClient] getPath:path
                                 parameters:@{}
                                    success:^(NSURLSessionDataTask *operation, id responseObject) {
        completion(responseObject, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}
@end
//
//  NYDataProvider+BrandIdentity.m
//  NineyiAppApi
//
//  Created by Nick Lee on 2018/3/20.
//

#import "NYDataProvider+BrandIdentity.h"
#import "NYECouponHTTPSClient.h"
#import "NYCDNHTTPClient.h"

@implementation NYDataProvider (BrandIdentity)

- (void)getBrandIdentityConfigurationWithShopId:(NSNumber *)shopId completionHandler:(DataSourceCompletionHandler)hanlder {
    NSString *path = [NSString stringWithFormat: @"Shop/GetCustomizedBrandIdentityDisplaySettings/%@", shopId ? shopId : @(0)];
    
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:nil success:^(NSURLSessionDataTask *operation, id responseObject) {
         hanlder(responseObject, nil);
     } failure:^(NSURLSessionDataTask *operation, NSError *error) {
         hanlder(nil, error);
     }];
}

- (void)getVIPOuterPointWithFullUrl:(NSURL *)fullUrl completionHandler:(void(^)(NSDictionary *responseDict, NSError *error))completionHandler {
    NYHTTPSClient *client = [[NYHTTPSClient alloc] initWithBaseURL:fullUrl];
    [client getPath:@""
         parameters:nil
            success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
                completionHandler(responseObject, nil);
            } failure:^(NSURLSessionTask *operation, NSError *error) {
                completionHandler(nil, error);
            }];
}

@end
//
//  NYDataProvider+Login.m
//  Pods
//
//  Created by Eric Huang on 2019/11/28.
//

#import "NYDataProvider+Login.h"
#import "NYHTTPSClient.h"
#import "NYCDNHTTPClient.h"
#import <NYCore/NYCore-Swift.h>
#import "NYDataProvider+Logging.h"

#import <AdSupport/AdSupport.h>

@implementation NYDataProvider (Login)

- (void)getShopThirdpartyAuthInfoWithShopId:(NSNumber *)shopId
                                     device:(NSString *)device
                          completionHandler:(DataSourceCompletionHandler)completionHandler {
    //為減少server loading、商城勿call
    if (shopId.integerValue == 0 || device.length == 0) {
        completionHandler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    // 舊官網帳號登入轉導到店家自己的登入頁面，需讓店家判斷第三方登入是否開啟（目前只有小三美日使用)
    // 新增參數 thirdLoginEnable 給 Server ， Server 會篩選適用的店家（若需隱藏第三方登入 thirdLoginEnable = false：回傳的網址會多帶上 &3rdlogin_btn=disable）
    BOOL thirdLoginEnable = false;
    
    [[NYHTTPSClient sharedClient]
     postPath:@"AuthV3/GetShopThirdpartyAuthInfo"
     parameters:@{@"shopId": shopId,
                  @"device": device,
                  @"thirdLoginEnable": (thirdLoginEnable)? @"true" : @"false"}
     success:^(NSURLSessionDataTask * _Nonnull operation, id _Nonnull responseObject) {
        completionHandler(@{kDATA_KEY:responseObject}, nil);
    } failure:^(NSURLSessionDataTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler(nil, error);
    }];
}

- (void)getThirdpartyMemberRegisterStatusWithTokenWithAccessToken:(NSString *)accessToken
                                                           ShopId:(NSNumber *)shopId
                                                completionHandler:(DataSourceCompletionHandler)completionHandler {
    //為減少server loading、商城勿call
    if (shopId.integerValue == 0) {
        completionHandler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    NSDictionary *parameter = @{@"accessToken"  : (accessToken) ?: @"",
                                @"shopId"       : shopId,
                                @"source"       : @"iOSApp",
                                @"device"       : @"Mobile",
                                @"appVer"       : [NYGlobalData appVersionString]};

    [[NYHTTPSClient sharedClient]
     postPath:@"AuthV3/GetThirdpartyMemberRegisterStatusWithToken"
     parameters:parameter
     success:^(NSURLSessionDataTask * _Nonnull operation, id _Nonnull responseObject) {
        completionHandler(@{kDATA_KEY:responseObject}, nil);
    } failure:^(NSURLSessionDataTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler(nil, error);
    }];
}

#pragma mark 手機註冊

- (void)checkIsValidWithCellPhone:(NSString *)cellPhone
                 countryAliasCode:(NSString *)countryAliasCode
                completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"cellPhone": cellPhone,
                                 @"aliasCode": [countryAliasCode uppercaseString]};

    //POST
    [[NYHTTPSClient sharedClient] postPath:@"AuthV4/IsValidNumber" parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            completionHandler(@{kDATA_KEY:JSON}, nil);
        } else {
            completionHandler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

- (void)getRegisterStatusWithShopID:(NSNumber *)shopID
                          cellPhone:(NSString *)cellPhone
                     reCaptchaToken:(NSString *)reCaptchaToken
                        countryCode:(NSString *)countryCode
                          countryID:(NSNumber *)countryID
                  completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId" : shopID,
                                 @"cellPhone" : cellPhone,
                                 @"reCaptchaToken" : reCaptchaToken,
                                 @"source":@"iOSApp",
                                 @"device":@"Mobile",
                                 @"countryCode" : countryCode,
                                 @"countryProfileId" : countryID
                                 };

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/GetNineYiMemberRegisterStatus" parameters:parameters completionHandler:completionHandler];
}

- (void)cellPhoneRegisterWithShopID:(NSNumber *)shopID
                          cellPhone:(NSString *)cellPhone
                     reCaptchaToken:(NSString *)reCaptchaToken
                        countryCode:(NSString *)countryCode
                          countryID:(NSNumber *)countryID
                  completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"          : shopID,
                                 @"cellPhone"       : cellPhone,
                                 @"reCaptchaToken"  : reCaptchaToken,
                                 @"countryCode"     : countryCode,
                                 @"countryProfileId" : countryID
                                 };

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/CreateNineYiMemberRegisterRequest" parameters:parameters completionHandler:completionHandler];
}

- (void)sendVerifyCodeWithShopID:(NSNumber *)shopID
                       cellPhone:(NSString *)cellPhone
                  reCaptchaToken:(NSString *)reCaptchaToken
                     countryCode:(NSString *)countryCode
                       countryID:(NSNumber *)countryID
                         smsType:(NSString *)smsType
               completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"          : shopID,
                                 @"cellPhone"       : cellPhone,
                                 @"reCaptchaToken"  : reCaptchaToken,
                                 @"countryCode"     : countryCode,
                                 @"countryProfileId": countryID,
                                 @"smsType"         : smsType
    };
    
    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV4/SendVerifyCode" parameters:parameters completionHandler:completionHandler];
}

- (void)resendVerifyCodeWithShopID:(NSNumber *)shopID
                         cellPhone:(NSString *)cellPhone
                        memberType:(NSString *)memberType
                        verifyType:(NSString *)verifyType
                           smsType:(NSString *)smsType
                    reCaptchaToken:(NSString *)reCaptchaToken
                       countryCode:(NSString *)countryCode
                         countryID:(NSNumber *)countryID
                 completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"memberType"       : memberType,
                                 @"verifyType"       : verifyType,
                                 @"reCaptchaToken"   : reCaptchaToken,
                                 @"source"           : @"iOSApp",
                                 @"device"           : @"Mobile",
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID,
                                 @"smsType"          : smsType
                                 };

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/ResendVerifyCode" parameters:parameters completionHandler:completionHandler];
}

- (void)resendVerifyCodeUseVoiceWithShopID:(NSNumber *)shopID
                         cellPhone:(NSString *)cellPhone
                        memberType:(NSString *)memberType
                        verifyType:(NSString *)verifyType
                  countryPhoneCode:(NSString *)countryPhoneCode
                         countryID:(NSNumber *)countryID
                 completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"memberType"       : memberType,
                                 @"verifyType"       : verifyType,
                                 @"countryCode"      : countryPhoneCode,
                                 @"countryProfileId" : countryID
                                 };

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV4/ResendVerifyCodeUseVoice" parameters:parameters completionHandler:completionHandler];
}

- (void)confirmVerifyCodeWithShopID:(NSNumber *)shopID
                          cellPhone:(NSString *)cellPhone
                               code:(NSString *)code
                         verifyType:(NSString *)verifyType
                     reCaptchaToken:(NSString *)reCaptchaToken
                        countryCode:(NSString *)countryCode
                          countryID:(NSNumber *)countryID
                  completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"code"             : code,
                                 @"verifyType"       : verifyType,
                                 @"reCaptchaToken"   : reCaptchaToken,
                                 @"source"           : @"iOSApp",
                                 @"device"           : @"Mobile",
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/ConfirmNineYiMemberVerifyCode" parameters:parameters completionHandler:completionHandler];
}

- (void)finishCellPhoneRegisterWithShopID:(NSNumber *)shopID
                                cellPhone:(NSString *)cellPhone
                                 password:(NSString *)password
                                   source:(NSString *)source
                                   device:(NSString *)device
                               appVersion:(NSString *)appVersion
                              countryCode:(NSString *)countryCode
                                countryID:(NSNumber *)countryID
                         enableOptInSplit:(BOOL)enableOptInSplit
                                  isOptIn:(NSNumber *)isOptIn
                              isEnableEDM:(NSNumber *)isEnableEDM
                           isEnableEdmSMS:(NSNumber *)isEnableEdmSMS
                         isAppPushProfile:(NSNumber *)isAppPushProfile
                        completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSMutableDictionary *parameters = @{@"shopId"           : shopID,
                                        @"cellPhone"        : cellPhone,
                                        @"password"         : password,
                                        @"source"           : source,
                                        @"device"           : device,
                                        @"appVer"           : appVersion,
                                        @"countryCode"      : countryCode,
                                        @"countryProfileId" : countryID}.mutableCopy;
    
    if (enableOptInSplit) {
        if (isEnableEDM && isEnableEdmSMS && isAppPushProfile) {
            parameters[@"isEnableEDM"] = isEnableEDM.boolValue ? @"true" : @"false";
            parameters[@"isEnableEdmSMS"] = isEnableEdmSMS.boolValue ? @"true" : @"false";
            parameters[@"isAppPushProfile"] = isAppPushProfile.boolValue ? @"true" : @"false";
        }
    } else {
        if (isOptIn) {
            parameters[@"isOptIn"] = isOptIn.boolValue ? @"true" : @"false";
        }
    }
    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];

    NSString *path = @"AuthV3/FinishNineYiMemberRegister";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)mergeFavoriteListAndShoppingCartWithCompletionHandler:(DataSourceCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient]
     postPath: @"Auth/MergeMemberFavorites"
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id JSON) {
         [[NYDataProvider sharedInstance] getFavoriteProductListWithCompletionHandler:^(NSDictionary *data, NSError *error) {
             completionHandler(nil, nil);
         }];
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

#pragma mark 手機登入

- (void)cellPhoneLoginWithShopID:(NSNumber *)shopID
                       cellPhone:(NSString *)cellPhone
                        password:(NSString *)password
                  reCaptchaToken:(NSString *)reCaptchaToken
                          source:(NSString *)source
                          device:(NSString *)device
                      appVersion:(NSString *)appVersion
                     countryCode:(NSString *)countryCode
                       countryId:(NSNumber *)countryId
               completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"password"         : password,
                                 @"reCaptchaToken"   : reCaptchaToken,
                                 @"source"           : source,
                                 @"device"           : device,
                                 @"appVer"           : appVersion,
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryId };

    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];
    NSString *path = @"AuthV3/LoginNineYiMember";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark 取得國家清單

- (void)getCountryListWithShopID:(NSNumber *)shopID CompletionHandler:(DataSourceCompletionHandler)completionHandler {

    NSString *path = [NSString stringWithFormat:@"countryProfile/GetCountryProfileListByShopId"];
    NSDictionary *parameters = @{@"shopId" : shopID};

    [[NYCDNHTTPClient sharedClient] getPath:path
                                 parameters:parameters
                                    success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             completionHandler(JSON, nil);
         } else {
             completionHandler(nil, NineYiErrorWithCode(0));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

#pragma mark 取得密碼 regex

- (void)getPasswordRegexSettingWithShopID:(NSNumber *)shopID
                        completionHandler:(DataSourceCompletionHandler)completionHandler {
    
    NSString *path = [NSString stringWithFormat:@"MemberLogin/GetPasswordRegexSetting"];
    NSDictionary *parameters = @{@"ShopId" : shopID};
    
    [[NYHTTPSClient sharedClient] getPath:path
                               parameters:parameters
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            completionHandler(JSON, nil);
        } else {
            completionHandler(nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

#pragma mark 取得遮罩資料

- (void)getMaskedPhoneNumberWithShopID:(NSNumber *)shopID completion:(void (^)(NSString *hashedPhoneNumber))completion {
    NSString *path = [NSString stringWithFormat:@"Advertise/GetVIPMemberHashInfoForAdvertise/%@", shopID];
    [[NYHTTPSClient sharedClient] getPath:path parameters:nil success:^(NSURLSessionDataTask *operation, NSDictionary *data) {
        NSString *returnCode = data[kNYAPIReturnCodeKey];
        NSDictionary *jsonData = data[kNYAPIDataKey];
        NSString *hashedPhoneNumber = @"";
        if ([returnCode isEqualToString:APIReturnCode.api0001] && [jsonData[@"PhoneHashed"] isKindOfClass:[NSString class]]) {
            NSDictionary *jsonData = data[kNYAPIDataKey];
            hashedPhoneNumber = jsonData[@"PhoneHashed"];
        }
        completion(hashedPhoneNumber);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(@"");
    }];
}

#pragma mark Facebook註冊

- (void)getFBRegisterStatusWithShopID:(NSNumber *)shopID
                          accessToken:(NSString *)accessToken
                            authToken:(NSString *)authToken
                    completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"      : shopID,
                                 @"token"       : accessToken,
                                 @"authToken"   : authToken};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/GetFacebookMemberRegisterStatus" parameters:parameters completionHandler:completionHandler];
}

- (void)fbRegisterWithShopID:(NSNumber *)shopID
                   cellPhone:(NSString *)cellPhone
                 accessToken:(NSString *)accessToken
                   authToken:(NSString *)authToken
                 countryCode:(NSString *)countryCode
                   countryID:(NSNumber *)countryID
           completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"token"            : accessToken,
                                 @"authToken"        : authToken,
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/CreateFacebookMemberRegisterRequest" parameters:parameters completionHandler:completionHandler];
}

- (void)fbConfirmVerifyCodeWithShopID:(NSNumber *)shopID
                          accessToken:(NSString *)accessToken
                            authToken:(NSString *)authToken
                            cellPhone:(NSString *)cellPhone
                                 code:(NSString *)code
                               source:(NSString *)source
                               device:(NSString *)device
                           appVersion:(NSString *)appVersion
                          countryCode:(NSString *)countryCode
                            countryID:(NSNumber *)countryID
                     enableOptInSplit:(BOOL)enableOptInSplit
                              isOptIn:(NSNumber *)isOptIn
                          isEnableEDM:(NSNumber *)isEnableEDM
                       isEnableEdmSMS:(NSNumber *)isEnableEdmSMS
                     isAppPushProfile:(NSNumber *)isAppPushProfile
                    completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSMutableDictionary *parameters = @{@"shopId"           : shopID,
                                        @"token"            : accessToken,
                                        @"authToken"        : authToken,
                                        @"cellPhone"        : cellPhone,
                                        @"code"             : code,
                                        @"source"           : source,
                                        @"device"           : device,
                                        @"appVer"           : appVersion,
                                        @"countryCode"      : countryCode,
                                        @"countryProfileId" : countryID}.mutableCopy;

    if (enableOptInSplit) {
        if (isEnableEDM && isEnableEdmSMS && isAppPushProfile) {
            parameters[@"isEnableEDM"] = isEnableEDM.boolValue ? @"true" : @"false";
            parameters[@"isEnableEdmSMS"] = isEnableEdmSMS.boolValue ? @"true" : @"false";
            parameters[@"isAppPushProfile"] = isAppPushProfile.boolValue ? @"true" : @"false";
        }
    } else {
        if (isOptIn) {
            parameters[@"isOptIn"] = isOptIn.boolValue ? @"true" : @"false";
        }
    }
    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];

    NSString *path = @"AuthV3/ConfirmFacebookMemberVerifyCode";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark Facebook登入

- (void)fbLoginWithShopID:(NSNumber *)shopID
              accessToken:(NSString *)accessToken
                authToken:(NSString *)authToken
                   source:(NSString *)source
                   device:(NSString *)device
               appVersion:(NSString *)appVersion
        completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"      : shopID,
                                 @"token"       : accessToken,
                                 @"authToken"   : authToken,
                                 @"source"      : source,
                                 @"device"      : device,
                                 @"appVer"      : appVersion};

    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];
    NSString *path = @"AuthV3/LoginFacebookMember";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark Line Login 註冊
/// 目前有 Line 登入、Line 綁定送券會需要先取得 ChannelID
/// （需要先檢查各自的 Flag 再決定是否取得 ChannelID）
- (void)getLineLoginChannelIdWithShopId:(NSNumber *)shopId
                             completion:(void (^)(NSString *channelId))completion {
    NSDictionary *params = @{@"shopId": shopId};
    NSString *path = @"Line/GetLineOAChannelInfo";
    [[NYHTTPSClient sharedClient] getPath:path parameters:params success:^(NSURLSessionDataTask *operation, NSDictionary *data) {
        NSString *returnCode = data[kNYAPIReturnCodeKey];
        NSDictionary *jsonData = data[kNYAPIDataKey];
        NSString *lineChannelId = @"";
        if ([returnCode isEqualToString:APIReturnCode.api0001] && [jsonData[@"LoginChannelId"] isKindOfClass:[NSString class]]) {
            NSDictionary *jsonData = data[kNYAPIDataKey];
            lineChannelId = jsonData[@"LoginChannelId"];
            completion(lineChannelId);
        } else {
            completion(@"");
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(@"");
    }];
}

- (void)getLineMemberRegisterStatusWithShopId:(NSNumber *)shopId
                                  accessToken:(NSString *)accessToken
                            completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"          : shopId,
                                 @"memberIdentity"  : accessToken,
                                 @"memberType"      : @"Line"};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV4/GetMemberRegisterStatus" parameters:parameters completionHandler:completionHandler];
}

- (void)createLineMemberRegisterRequestWithShopId:(NSNumber *)shopId
                                        cellPhone:(NSString *)cellPhone
                                      accessToken:(NSString *)accessToken
                                      countryCode:(NSString *)countryCode
                                        countryId:(NSNumber *)countryId
                                completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopId,
                                 @"cellPhone"        : cellPhone,
                                 @"accessToken"      : accessToken,
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryId,
                                 @"targetPageType"   : @"AppLineLogin"};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV4/CreateLineMemberRegisterRequest" parameters:parameters completionHandler:completionHandler];
}

- (void)confirmLineMemberVerifyCodeWithCellPhone:(NSString *)cellPhone
                                            code:(NSString *)code
                                     countryCode:(NSString *)countryCode
                                       countryId:(NSNumber *)countryId
                                         isOptIn:(NSNumber *)isOptIn
                               completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSMutableDictionary *parameter = [[NSMutableDictionary alloc] init];
    [parameter setValue:cellPhone forKey:@"cellPhone"];
    [parameter setValue:code forKey:@"code"];
    [parameter setValue:countryCode forKey:@"countryCode"];
    [parameter setValue:countryId forKey:@"countryProfileId"];
    [parameter setValue:@"AppLineLogin" forKey:@"targetPageType"];
    if (isOptIn) {
        parameter[@"isOptIn"] = isOptIn.boolValue ? @"true" : @"false";
    }
    parameter = [self addCommonNYLoginAPIParamsWithDictionary:parameter];
    parameter = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameter];
    NSString *path = @"AuthV4/ConfirmLineMemberVerifyCode";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameter requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark Line Login 登入
- (void)loginLineMemberWithAccessToken:(NSString *)accessToken
                     completionHandler:(LoginCompletionHandler)completionHandler {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setValue:accessToken forKey:@"accessToken"];
    [parameters setValue:@"AppLineLogin" forKey:@"targetPageType"];
    parameters = [self addCommonNYLoginAPIParamsWithDictionary:parameters];
    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];
    NSString *path = @"AuthV4/LoginLineMember";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark 忘記密碼

- (void)resetPasswordWithShopID:(NSNumber *)shopID
                      cellPhone:(NSString *)cellPhone
                 reCaptchaToken:(NSString *)reCaptchaToken
                    countryCode:(NSString *)countryCode
                      countryID:(NSNumber *)countryID
              completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"reCaptchaToken"   : reCaptchaToken,
                                 @"source"           : @"iOSApp",
                                 @"device"           : @"Mobile",
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/CreateNineYiMemberResetPasswordRequest" parameters:parameters completionHandler:completionHandler];
}

- (void)finishResetPasswordWithShopID:(NSNumber *)shopID
                            cellPhone:(NSString *)cellPhone
                             password:(NSString *)password
                               source:(NSString *)source
                               device:(NSString *)device
                           appVersion:(NSString *)appVersion
                          countryCode:(NSString *)countryCode
                            countryID:(NSNumber *)countryID
                    completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"password"         : password,
                                 @"source"           : source,
                                 @"device"           : device,
                                 @"appVer"           : appVersion,
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID};

    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];
    NSString *path = @"AuthV3/FinishNineYiMemberResetPassword";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)checkResetPasswordMultiFactorAuthWithShopID:(NSNumber *)shopID
                                          cellPhone:(NSString *)cellPhone
                                        countryCode:(NSString *)countryCode
                                          countryID:(NSNumber *)countryID
                                  completionHandler:(MultiFactorAuthCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"source"           : @"iOSApp",
                                 @"device"           : @"Mobile",
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID};
    
    //POST
    NSString *path = @"AuthV4/CheckResetPasswordMultiFactorAuth";
    
    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSDictionary *data = JSON[kNYAPIDataKey];
            NSString *message = JSON[kNYAPIMessage];
            completionHandler(returnCode, data, message, nil);
        } else {
            completionHandler (nil, nil, nil, NineYiErrorWithCode(0));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)confirmResetPasswordMultiFactorAuthWithShopID:(NSNumber *)shopID
                                            cellPhone:(NSString *)cellPhone
                                          countryCode:(NSString *)countryCode
                                            countryID:(NSNumber *)countryID
                                multiFactorAuthFields:(NSArray *)multiFactorAuthFields
                                    completionHandler:(MultiFactorAuthCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"               : shopID,
                                 @"cellPhone"            : cellPhone,
                                 @"source"               : @"iOSApp",
                                 @"device"               : @"Mobile",
                                 @"countryCode"          : countryCode,
                                 @"countryProfileId"     : countryID,
                                 @"multiFactorAuthFields": multiFactorAuthFields};
    
    //POST
    NSString *path = @"AuthV4/ConfirmResetPasswordMultiFactorAuth";
    
    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSDictionary *data = JSON[kNYAPIDataKey];
            NSString *message = JSON[kNYAPIMessage];
            completionHandler(returnCode, data, message, nil);
        } else {
            completionHandler (nil, nil, nil, NineYiErrorWithCode(0));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark 修改密碼

- (void)changePasswordWithShopID:(NSNumber *)shopID
                     oldPassword:(NSString *)oldPassword
                     newPassword:(NSString *)newPassword
               completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"      : shopID,
                                 @"oldPassword" : oldPassword,
                                 @"newPassword" : newPassword};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/ChangeNineYiMemberPassword" parameters:parameters completionHandler:completionHandler];
}

#pragma mark 設定密碼
- (void)setPasswordWithShopID:(NSNumber *)shopID
                    cellPhone:(NSString *)cellPhone
                     password:(NSString *)password
                       source:(NSString *)source
                       device:(NSString *)device
                   appVersion:(NSString *)appVersion
                  countryCode:(NSString *)countryCode
                    countryID:(NSNumber *)countryID
                   verifyType:(NSString *)verifyType
            completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSMutableDictionary *parameters = @{@"shopId" : shopID,
                                        @"cellPhone" : cellPhone,
                                        @"password" : password,
                                        @"source" : source,
                                        @"device" : device,
                                        @"appVer" : appVersion,
                                        @"countryCode" : countryCode,
                                        @"countryProfileId" : countryID,
                                        @"isOptIn" : @(NO),
                                        @"verifyType": verifyType
    }.mutableCopy;
    
    NSString *path = @"AuthV5/SetPassword";
    
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark 商店第三方登入
- (void)getThirdpartyMemberRegisterStatusWithLoginId:(NSString *)loginId
                                            password:(NSString *)password
                                              shopId:(NSNumber *)shopId
                                   completionHandler:(LoginCompletionHandler)completionHandler {
    //防止有參數為nil
    if (!(loginId && password && shopId)) {
        completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    NSDictionary *parameter = @{@"loginId"  : loginId,
                                @"password" : password,
                                @"shopId"   : shopId};

    //POST
    [[NYHTTPSClient sharedClient] postPath:@"AuthV3/GetThirdpartyMemberRegisterStatus" parameters:parameter requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)createThirdpartyMemberRegisterRequestWithToken:(NSString *)token
                                             cellPhone:(NSString *)cellPhone
                                                shopId:(NSNumber *)shopId
                                           countryCode:(NSString *)countryCode
                                             countryID:(NSNumber *)countryID
                                     completionHandler:(DataSourceCompletionHandler)completionHandler {
    //防止有參數為nil
    if (!(token && cellPhone && shopId)) {
        completionHandler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    NSDictionary *parameter = @{@"authSessionToken"  : token,
                                @"cellPhone"         : cellPhone,
                                @"shopId"            : shopId,
                                @"countryCode"       : countryCode,
                                @"countryProfileId"  : countryID};

    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/CreateThirdpartyMemberRegisterRequest" parameters:parameter completionHandler:completionHandler];
}

- (void)confirmThirdpartyMemberVerifyCodeWithCellPhone:(NSString *)cellPhone
                                                shopId:(NSNumber *)shopId
                                                  code:(NSString *)code
                                                 token:(NSString *)token
                                                source:(NSString *)source
                                                device:(NSString *)device
                                            appVersion:(NSString *)appVersion
                                           countryCode:(NSString *)countryCode
                                             countryID:(NSNumber *)countryID
                                               isOptIn:(NSNumber *)isOptIn
                                     completionHandler:(LoginCompletionHandler)completionHandler {
    //防止有參數為nil
    if (!(cellPhone && shopId && code && token && source && device && appVersion)) {
        completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    NSMutableDictionary *parameter = @{@"cellPhone"         : cellPhone,
                                       @"shopId"            : shopId,
                                       @"code"              : code,
                                       @"authSessionToken"  : token,
                                       @"source"            : source,
                                       @"device"            : device,
                                       @"appVer"            : appVersion,
                                       @"countryCode"       : countryCode,
                                       @"countryProfileId"  : countryID}.mutableCopy;

    if (isOptIn) {
        parameter[@"isOptIn"] = isOptIn.boolValue ? @"true" : @"false";
    }

    parameter = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameter];

    //POST
    [[NYHTTPSClient sharedClient] postPath:@"AuthV3/ConfirmThirdpartyMemberVerifyCode" parameters:parameter requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)loginThirdpartyMemberWithAuthSessionToken:(NSString *)authSessionToken
                                           shopId:(NSNumber *)shopId
                                           source:(NSString *)source
                                           device:(NSString *)device
                                       appVersion:(NSString *)appVersion
                                completionHandler:(LoginCompletionHandler)completionHandler {
    //防止有參數為nil
    if (!(authSessionToken && shopId && source && device && appVersion)) {
        completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    NSDictionary *parameter = @{@"authSessionToken" : authSessionToken,
                                @"shopId"           : shopId,
                                @"source"           : source,
                                @"device"           : device,
                                @"appVer"           : appVersion};
    
    parameter = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameter];

    [[NYHTTPSClient sharedClient]
     postPath:@"AuthV3/LoginThirdpartyMember"
     parameters:parameter
     success:^(NSURLSessionDataTask * _Nonnull operation, id _Nonnull JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler(nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark - 2.3 Login & Register
#pragma mark General
/**
 *  簡單的通用POST
 *
 *  @param path              API路徑
 *  @param parameters        API吃的參數
 *  @param completionHandler Completion Block
 */
- (void)loginNRegisterGeneralPOSTMethodWithPath:(NSString *)path
                                     parameters:(NSDictionary *)parameters
                              completionHandler:(DataSourceCompletionHandler)completionHandler {

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            completionHandler(@{kDATA_KEY:JSON}, nil);
        } else {
            completionHandler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

#pragma mark 首下載折價券門市券自動歸戶

- (void)setMemberFirstDownloadECouponByAutoWithShopId:(NSNumber *)shopId
                                    completionHandler:(void (^)(NSString *returnCode, NSArray *eCouponList, NSError *error))completion {
    [[NYHTTPSClient sharedClient]
     postPath:@"ECoupon/SetMemberFirstDownloadECouponByAuto"
     parameters:@{@"shopId": shopId,
                  @"guid": [self GUID]}
     success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[@"ReturnCode"];
        NSArray *eCouponList = responseObject[@"Data"];

        completion(returnCode, eCouponList, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
     }];
}

- (void)setMemberFirstDownloadCouponByAutoWithShopId:(NSNumber *)shopId
                                   completionHandler:(void (^)(NSString *returnCode, NSArray *couponList, NSError *error))completion {
    [[NYHTTPSClient sharedClient]
     postPath:@"Coupon/SetMemberFirstDownloadCouponByAuto"
     parameters:@{@"shopId": shopId,
                  @"guid": [self GUID]}
     success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[@"ReturnCode"];
        NSArray *couponList = responseObject[@"Data"];

        completion(returnCode, couponList, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
     }];
}

#pragma mark Member Info

- (void)getRegisterSettingConfigWithShopID:(NSNumber *)shopID completion:(void (^)(BOOL enableProfile, BOOL enableOptin, BOOL defaultOptin, BOOL allFilled, BOOL enableOptInSplit, NSError *error))completion {

    // Note: 會先打API來決定是不是要往後打 “取得 OptIn 開關設定API”
    __weak typeof(self) weakSelf = self;
    [weakSelf getRegistrationSettingWithShopID:[NYGlobalData shopId] completion:^(BOOL flag, NSError *error) {

        if (!error && flag) {
            // Note: 同 getRegisterSettingWithShopID, 不過是純粹取 OptIn 開關設定
            [weakSelf getRegisterSettingWithShopID:shopID completion:^(NSDictionary *data, NSError *error) {
                if (!error) {
                    // Success
                    BOOL isEnable = [[data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.EnableRegistrationSetting"] boolValue];

                    BOOL enableProfile = [[data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.EnableRequiredProfile"] boolValue];
                    enableProfile &= isEnable;

                    BOOL enableOptin = [[data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.EnableOptIn"] boolValue];
                    enableOptin &= isEnable;
                    BOOL defaultOptin = [[data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.OptIn.Default"] boolValue];
                    
                    BOOL enableOptInSplit = [[data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.EnableOptInSplit"] boolValue];

                    __block BOOL allFilled = YES;
                    NSArray<NSDictionary *> *columnList = [data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.RequiredProfile.ColumnList"];
                    [columnList enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        BOOL isUsing = [obj[@"IsUsing"] boolValue];
                        id value = obj[@"Value"];
                        if (isUsing) {
                            BOOL hasValue = [value isKindOfClass:[NSString class]] && [value length] > 0;
                            allFilled &= hasValue;
                        }
                        // 找到有一個沒填寫就停
                        *stop = !allFilled;
                    }];

                    completion(enableProfile, enableOptin, defaultOptin, allFilled, enableOptInSplit, nil);
                } else {
                    // Fail
                    completion(NO, NO, NO, NO, NO, error);
                }
            }];
        } else {
            // 如果API Fail 取不到是否要繼續往後打的 Bool值，直接視為不開 OptIn。
            completion(NO, NO, NO, NO, NO, nil);
        }
    }];
}

/// 為了雙十一優化，希望 OptIn 前端可以有一層 cache，減低最後往後打的流量...
/// 所以先打這支API來決定，“是否要往後打取得Optin開關設定 API”，如果為 true 才繼續往後打 getRegisterSettingWithShopID 以取得 OptIn 開關設定。
- (void)getRegistrationSettingWithShopID:(NSNumber *)shopID
                              completion:(void (^)(BOOL data, NSError *error))completion {
    NSString *path = @"VIPMemberLite/GetRegistrationSetting";
    NSDictionary *params = @{@"shopId": shopID};

    [[NYHTTPSClient
      sharedClient] getPath:path parameters:params success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
        BOOL data = [responseObject[kNYAPIDataKey] boolValue];
        completion(data, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}

- (void)getRegisterSettingWithShopID:(NSNumber *)shopID
                          completion:(void (^)(NSDictionary *data, NSError *error))completion {
    NSString *path = @"vipmember/GetVIPMemberItemForRegistrationSetting";
    NSDictionary *params = @{@"shopId": shopID};

    [[NYHTTPSClient sharedClient] getPath:path parameters:params success:^(NSURLSessionDataTask *operation, id responseObject) {
        // Check data error
        if ([responseObject isKindOfClass:[NSDictionary class]] &&
            [[responseObject valueForKeyPath:@"Data"] isKindOfClass:[NSDictionary class]]) {
            completion(responseObject, nil);
        } else {
            NSError *dataError = [[NSError alloc] initWithDomain:@"nineyi.data.error" code:0 userInfo:@{}];
            completion(nil, dataError);
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}

- (void)updateRegisterSettingWithSetting:(NSDictionary *)setting
                                  shopID:(NSNumber *)shopID
                            memberCardID:(NSNumber *)cardID
                        enableOptInSplit:(BOOL)enableOptInSplit
                                 isOptIn:(BOOL)isOptIn
                             isEnableEDM:(BOOL)isEnableEDM
                          isEnableEdmSMS:(BOOL)isEnableEdmSMS
                        isAppPushProfile:(BOOL)isAppPushProfile
                              completion:(void (^)(NSDictionary *data, NSError *error))completion {
    NSString *basePath = [NSString stringWithFormat:@"vipmember/UpdateVIPMemberForRegistrationSetting?shopId=%@&memberCardId=%@&guid=%@", shopID, cardID, [self GUID]];
    NSString *path;
    if (enableOptInSplit) {
        NSString *query = [NSString stringWithFormat:@"&isEnableEDM=%@&isEnableEdmSMS=%@&isAppPushProfile=%@",
                           isEnableEDM? @"true": @"false",
                           isEnableEdmSMS? @"true": @"false",
                           isAppPushProfile? @"true": @"false"];
        path = [basePath stringByAppendingString:query];
    } else {
        path = [basePath stringByAppendingString:[NSString stringWithFormat:@"&isOptIn=%@", isOptIn? @"true": @"false"]];
    }

    NSDictionary *params = setting;

    [[NYHTTPSClient sharedClient]
     postPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
        completion(responseObject, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}

- (void)updateCellPhoneWithCellPhone:(NSString *)cellPhone
                    countryAliasCode:(NSString *)countryAliasCode
                   completionHandler:(LoginCompletionHandler)completionHandler {
  
    __weak typeof(self) weakSelf = self;
    NSDictionary *parameters = @{@"Cellphone": cellPhone,
                                 @"AliasCode": countryAliasCode};
    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];
    NSString *path = @"vipmember/UpdateMemberCellphone";
    
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        
        NSString *auth = [weakSelf getAuthFromURLSession:operation];
        
        [weakSelf crashlyticsFailureLogWithAPI:@"UpdateCellPhone"
                                     operation:operation
                                requestPayload:parameters
                                  responseData:JSON
                             successReturnCode:APIReturnCode.api0001];
        
        completionHandler(JSON, auth, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        
        [weakSelf crashlyticsFailureLogWithAPI:@"UpdateCellPhone"
                                     operation:operation
                                requestPayload:parameters
                                         error:error];
        
        completionHandler(nil, nil, error);
    }];
}

#pragma mark private method

/// Adding common login parameters
/// @param originalDict - original parameters
- (NSMutableDictionary *)addCommonNYLoginAPIParamsWithDictionary:(NSDictionary *)originalDict {
    NSMutableDictionary *processedDictionary = [[NSMutableDictionary alloc] initWithDictionary:originalDict];
    [processedDictionary setValue:[NYGlobalData shopId] forKey:@"shopId"];
    [processedDictionary setValue:[NYGlobalData appVersionString] forKey:@"appVer"];
    [processedDictionary setValue:@"Mobile" forKey:@"device"];
    [processedDictionary setValue:@"iOSApp" forKey:@"source"];
    return processedDictionary;
}

- (NSString *)getAuthFromURLSession:(NSURLSessionDataTask *)operation {
    NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)operation.response;
    NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields: urlResponse.allHeaderFields forURL:[NYBaseURLConfig baseHTTPSURLWithWebAPIDomain]];
    NSString *auth;
    
    for (NSHTTPCookie *cookie in cookies) {
        if ([@"auth" isEqualToString:[cookie.name lowercaseString]]) {
            auth = cookie.value;
            break;
        }
    }
    return auth;
}

#pragma mark Private Social Login/Register
- (void)socialLoginOrRegisterWithAPIVersion:(NSString *)apiVersion
                                       type:(NSString *)memberType
                                    content:(NSDictionary *) content
                                      email:(NSString *)email
                                successCode:(NSString *)code
                    completionHandler:(LoginCompletionHandler)completionHandler {
    
    __weak typeof(self) weakSelf = self;
    NSDictionary *payload = @{
        @"MemberType": memberType,
        memberType: content,
        @"ShopId": [NYGlobalData shopId],
        @"Email": email,
        @"Originate": @{
            @"Source": @"iOSApp",
            @"Device": @"Mobile",
            @"AppVersion": [NYGlobalData appVersionString],
            @"UnloginId": [self GUID]
        },
        @"Referee": [[NYReferrerBindingLinkInjectionHelper shared] referrerBindingLinkContent]
    };
    
    // 2024/9/27: AuthV5 尚不支援 Apple 登入，但是 payload 都一樣，所以社群登入自行帶入 API 版本
    NSString *path = [NSString stringWithFormat:@"%@/SocialLoginOrRegister", apiVersion];
    [[NYHTTPSClient sharedClient] postPath:path parameters:payload success:^(NSURLSessionDataTask *operation, NSDictionary *JSON) {
        NSString *auth = [weakSelf getAuthFromURLSession:operation];
        
        [weakSelf crashlyticsFailureLogWithAPI:@"SocialLoginOrRegister"
                                     operation:operation
                                requestPayload:payload
                                  responseData:JSON
                             successReturnCode:code];
        
        if (JSON) {
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        }   
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        
        [weakSelf crashlyticsFailureLogWithAPI:@"SocialLoginOrRegister"
                                 operation:operation
                            requestPayload:payload
                                     error:error];
        
        completionHandler(nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
    }];
}

#pragma mark Public Social Login/Registered

/// Sign In with Apple
- (void)appleIdLoginOrRegisterWithAuthCode:(NSString *)authCode
                                     email:(NSString *)email
                         completionHandler:(LoginCompletionHandler)completionHandler {
    
    /**
     Apple 登入-註冊登入設計文件
     https://docs.google.com/document/d/1UgNCU70YzplOhkheFcljgaoEmx5O209v_J79Lo4JvJU
     
     當開啟 Sign In with Apple, 必須關掉以下功能:
     - 必須填寫會員資料: welcomePage.shopContract.isLocationMember = False
     - 綁定門市會員: IsShowLocationBindingButton = False (此功能未完成)
     
     */
    NSDictionary *appleContent = @{
        @"AuthCode": authCode,
        @"BundleId": [NYGlobalData bundleId],
        @"TeamId": [NYGlobalData teamId]
    };
    
    [self socialLoginOrRegisterWithAPIVersion:@"AuthV4"
                                         type:@"Apple"
                                      content:appleContent
                                        email:email
                                  successCode:NYLoginReturnCodes.kNYAPIAppleSignInSuccess
                            completionHandler:completionHandler];
}

@end
//
//  NYDataProvider+MemberCenter.m
//  Pods
//
//  Created by Daniel Kao on 11/7/16.
//
//

#import "NYDataProvider+MemberCenter.h"
#import "NYHTTPSClient.h"
#import "NYCDNHTTPClient.h"
#import "NYECouponHTTPSClient.h"
#import "NYMemberHelper.h"
#import <CocoaSecurity/CocoaSecurity.h>
#import "NYMemberTypeConverter.h"
#import "NYUserDefault.h"
#import <NYCore/NYCore-Swift.h>
#import "NYDataProvider+Logging.h"

@implementation NYDataProvider (MemberCenter)

- (void)getVipMemberItemV2WithParameters:(NSDictionary *)parameters completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient]
     getPath:@"VipMember/GetVIPMemberItemV2"
     parameters:parameters
     success:^(NSURLSessionTask *operation, id JSON) {
         if ([JSON[@"ReturnCode"] isEqualToString:@"API0001"] && [JSON[@"Data"][@"Member"] isKindOfClass:[NSArray class]]) {
             handler (@{kDATA_KEY: JSON[@"Data"]}, nil);
         }
         else {
             handler (@{kDATA_KEY: JSON}, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
         }
     }
     failure:^(NSURLSessionTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)insertOrUpdateVIPMemberInfo:(NSDictionary *)memberInfo WithCompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient] postPath:@"vipMember/InsertOrUpdateVIPMember" parameters:memberInfo requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        
        [self crashlyticsFailureLogWithAPI:@"InsertOrUpdateVIPMember"
                                 operation:operation
                            requestPayload:memberInfo
                              responseData:JSON
                         successReturnCode:@"API0001"];
        
        if (JSON) {
            handler (@{kDATA_KEY:JSON}, nil);
        }
        else {
            handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        
        [self crashlyticsFailureLogWithAPI:@"InsertOrUpdateVIPMember"
                                 operation:operation
                            requestPayload:memberInfo
                                     error:error];
        
        handler(nil, error);
    }];
}

- (void)registerVIPMemberWithParameters:(NSDictionary *)parameters CompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient] postPath:@"vipMember/RegisterVIPMember" parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        if (JSON) {
            handler(@{kDATA_KEY:JSON}, nil);
        } else {
            handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        handler(nil, error);
    }];
}

- (void)bindingShopLocationVIPMemberWithParameters:(NSDictionary *)parameters CompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient] postPath:@"vipMember/BindingShopLocationVIPMember" parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        if (JSON) {
            handler (@{kDATA_KEY: JSON}, nil);
        }
        else {
            handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        handler(nil, error);
    }];
}



- (void)getVipShopInfoWithShopId:(NSInteger)shopId
               completionHandler:(DataSourceCompletionHandler)handler {
    //    NYHTTPSClient *client = [[NYHTTPSClient alloc] initWithBaseURL:[NSURL URLWithString:@"https://testapi.n2/APITest/api/Vip/webapi/VipMember/GetVipShopInfo"]];
    //    [client
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"VipMember/GetVipShopInfo"]
     parameters:@{@"shopId" : @(shopId)}
     success:^(NSURLSessionTask *operation, id JSON) {
         handler (@{kDATA_KEY:JSON}, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)getThirdPartyTradesOrderSettingWithShopId:(NSNumber *)shopId
                                completionHandler:(ThirdPartyTradesOrderSettingCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient]
     GET:@"VIPMember/GetThirdPartyTradesOrderConfiguration"
     parameters:@{@"shopId": shopId}
     progress: nil
     success:^(NSURLSessionTask * _Nonnull operation, id  _Nonnull responseObject) {
         NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
         NSString *message = responseObject[kNYAPIMessage];
         NSDictionary *data = responseObject[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask * _Nonnull operation, NSError * _Nonnull error) {
         completionHandler (nil, nil, nil, error);
     }];
}

- (void)getVIPMemberDisplaySettingsWithShopId:(NSNumber *)shopId
                            completionHandler:(GetDisplaySettingsCompletionHandler)completionHandler {
    // api error code: P:002.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    NSString *endpoint = [@"Shop/GetVipMemberDisplaySettings/" stringByAppendingString:shopId.stringValue];

    [[NYHTTPSClient sharedClient]
     GET:endpoint
     parameters:nil
     progress:nil
     success:^(NSURLSessionTask * _Nonnull operation, id  _Nonnull responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        NSDictionary *data = responseObject[kNYAPIDataKey];
        data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler (nil, nil, nil, error);
    }];
}

- (void)vipMemberCustomLinkSettingsWithShopId:(NSNumber *)shopId completionHandler:(void (^)(NSString *returnCode, NSArray *data, NSError *error))completionHandler {
    // api error code: N:003.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYHTTPSClient sharedClient]
     getPath:@"VIPMember/GetVipMemberCustomLinkSettings"
     parameters:@{@"shopId": shopId}
     success:^(NSURLSessionDataTask * _Nonnull operation, id _Nonnull responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSArray *data = @[];
        if ([responseObject[kNYAPIDataKey] isKindOfClass:[NSArray class]]) {
            // if not API00001, it returns "" (empty string)
            data = responseObject[kNYAPIDataKey];
        }
        completionHandler(returnCode, data, nil);
    } failure:^(NSURLSessionDataTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler (nil, nil, error);
    }];
}

#pragma mark - Member Info API Aggregation

- (void)getVIPInfoWithShopID:(NSNumber *)shopID
                   isBinding:(BOOL)isBinding
           completionHandler:(MemberInfoCompletionHandler)completionHandler {
    // api error code: P:001.99
    [[NYHTTPSClient sharedClient]
     postPath:@"VipMember/GetVipInfo"
     parameters:@{@"shopId": shopID,
                  @"isBinding": isBinding ? @"true" : @"false"}
     success:^(NSURLSessionTask *operation, id JSON) {
         // API format check.
         // If API format is incorrect, try add a empty result instead APP crash
         // see https://bts.nine-yi/edit_bug.aspx?id=14388 for more detail
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];
}

- (void)getMemberLocationTradesSummaryWithShopID:(NSNumber *)shopID
                               completionHandler:(MemberInfoCompletionHandler)completionHandler {
    // api error code: P:009.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYHTTPSClient sharedClient]
     postPath:@"VIPMemberLite/GetMemberLocationTradesSummary"
     parameters:@{@"shopId": shopID}
     success:^(NSURLSessionTask *operation, id JSON) {
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];
}

#pragma mark - Private

- (void)getVIPMemberActivateCardPresentStatusWithShopID:(NSNumber *)shopID
                                      completionHandler:(MemberPresentStatusCompletionHandler)completionHandler {
    // api error code: P:005.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYHTTPSClient sharedClient]
     postPath:@"VipMember/GetOpenCardPresentStatus"
     parameters:@{@"shopId": shopID}
     success:^(NSURLSessionTask *operation, id JSON) {
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];
}

- (void)getNormalMemberctivateCardPresentStatusWithShopID:(NSNumber *)shopID
                                        completionHandler:(MemberPresentStatusCompletionHandler)completionHandler {
    // api error code: P:004.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYHTTPSClient sharedClient]
     postPath:@"VipMember/GetNonVIPOpenCardPresentStatus"
     parameters:@{@"shopId": shopID}
     success:^(NSURLSessionTask *operation, id JSON) {
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];

}

- (void)getMemberBirthdayPresentStatusWithShopID:(NSNumber *)shopID
                               completionHandler:(MemberPresentStatusCompletionHandler)completionHandler {
    // api error code: P:006.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYHTTPSClient sharedClient]
     postPath:@"VipMember/GetBirthdayPresentStatus"
     parameters:@{@"shopId": shopID}
     success:^(NSURLSessionTask *operation, id JSON) {
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];
}

#pragma mark - 會員卡相關

- (void)getCRMMemberTierWithShopID:(NSNumber *)shopID
                 completionHandler:(CRMMemberTierCompletionHandler)completionHandler {
    // api error code: P:003.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    NSString *path = [NSString stringWithFormat:@"CrmMember/GetCrmMemberTier/%@", shopID];
    [[NYHTTPSClient sharedClient] postPath:path
                               parameters:nil
                                  success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
                                      NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
                                      NSString *message = responseObject[kNYAPIMessage];
                                      NSDictionary *data = responseObject[kNYAPIDataKey];
                                      data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
                                      completionHandler(returnCode, message, data, nil);
                                  } failure:^(NSURLSessionTask *operation, NSError *error) {
                                      completionHandler(nil, nil, nil, error);
                                  }];
}

- (void)getCRMMemberCardListWithShopID:(NSNumber *)shopID
                     completionHandler:(CRMShopMemberCardInfoCompletionHandler)completionHandler {
    // api error code: P:007.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    NSString *path = [NSString stringWithFormat:@"CrmShopMemberCard/GetCrmShopMemberCardInfo/%@", shopID];
    [[NYCDNHTTPClient sharedClient] getPath:path
                                 parameters:nil
                                    success:^(NSURLSessionTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        NSDictionary *data = responseObject[kNYAPIDataKey];
        data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 設定頁Email相關

- (void)getVipMemberEmailNotificationWithShopID:(NSNumber *)shopID
                              completionHandler:(MemberInfoCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"VipMember/GetVipMemberEmailNotification/%@", shopID]
     parameters:nil
     success:^(NSURLSessionTask *operation, id JSON) {
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];
}

- (void)updateVipMemberEmailNotificationWithShopID:(NSNumber *)shopID
                                              data:(NSDictionary *)postData
                                 completionHandler:(ShopCRMContractSettingCompletionHandler)completionHandler {
    NSDictionary *para = @{@"shopId" : shopID,
                           @"vipMemberEmailNotification" : (postData)? : @{}};
    
    [[NYHTTPSClient sharedClient] postPath:@"VipMember/UpdateVipMemberEmailNotification" parameters:para requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 貨態查詢

- (void)getShippingStatusForUserWithShopId:(NSNumber *)shopId
                         completionHandler:(MemberInfoCompletionHandler)completionHandler {
    // api error code: P:008.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    NSString *path = [NSString stringWithFormat:@"MemberTradesOrder/GetShippingStatusForUser"];
    NSDictionary *params = @{@"shopId" : shopId};
    [[NYHTTPSClient sharedClient] getPath:path
                               parameters:params
                                  success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
                                      NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
                                      NSString *message = responseObject[kNYAPIMessage];
                                      NSDictionary *data = responseObject[kNYAPIDataKey];
                                      data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
                                      completionHandler(returnCode, message, data, nil);
                                  } failure:^(NSURLSessionTask *operation, NSError *error) {
                                      completionHandler(nil, nil, nil, error);
                                  }];
}

- (void)getMemberPresentWithPurchaseWithShopId:(NSNumber *)shopId
                             completionHandler:(MemberInfoCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"VipMember/GetMemberPresentWithPurchase"
                                parameters:@{@"shopId" : shopId}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
                                       NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
                                       NSString *message = responseObject[kNYAPIMessage];
                                       NSDictionary *data = responseObject[kNYAPIDataKey];
                                       completionHandler(returnCode, message, data, nil);
                                   } failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                       completionHandler(nil, nil, nil, error);
                                   }];
}

#pragma mark - 查詢是否有定期購管理

- (void)getMemberHasRegularOrderWithShopId:(NSNumber *)shopId
                                completion:(void (^)(NSString *returnCode, NSArray *data, NSError *error))completion {
    // api error code: N:001.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYCDNHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"Sidebar/GetSettingList/%@",shopId]
                                 parameters:nil
                                    success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSArray *data = responseObject[kNYAPIDataKey];
        completion(returnCode, data, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

#pragma mark - 會員邀請碼
- (void)getMemberInvitationInfoWithCompletion:(void (^)(NSString *returnCode, NSDictionary *data, NSError *error))completion {
    NSString *path = @"MemberInvite/Inviter";
    NSMutableDictionary *param = [NSMutableDictionary new];
    NSNumber *shopId = [NYGlobalData shopId];
    if (shopId) {
        param[@"ShopId"] = shopId;
    }
    NSString *memberCode = [NYUserDefault memberCode];
    if (memberCode) {
        param[@"MemberId"] = memberCode;
    }
    
    [[NYHTTPSClient sharedClient]
     postPath:path
     parameters:param
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSDictionary *data = responseObject[kNYAPIDataKey];
        completion(returnCode, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

- (void)getMemberInvitationHistoryWithType:(NSString *)type skip:(NSNumber *)skip count:(NSNumber *)count  completion:(void (^)(NSString *returnCode, NSDictionary *data, NSError *error))completion {
    NSString *path = @"MemberInvite/InviteHistory";
    NSMutableDictionary *param = [NSMutableDictionary dictionaryWithDictionary:@{
        @"Type":type,
        @"Skip":skip,
        @"Count":count
    }];
    NSNumber *shopId = [NYGlobalData shopId];
    if (shopId) {
        param[@"ShopId"] = shopId;
    }
    NSString *memberCode = [NYUserDefault memberCode];
    if (memberCode) {
        param[@"MemberId"] = memberCode;
    }

    [[NYHTTPSClient sharedClient]
     postPath:path
     parameters:param
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSDictionary *data = responseObject[kNYAPIDataKey];
        completion(returnCode, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

- (void)getMemberInvitationExplanationDetailWithPromotionEngineID:(NSNumber *)promotionEngineID
                                                        completion:(void (^)(NSString *returnCode, NSDictionary *data, NSError *error))completion {
    NSMutableDictionary *param = [NSMutableDictionary new];
    param[@"ShopId"] = [NYGlobalData shopId];
    if (promotionEngineID) {
        param[@"PromotionEngineId"] = promotionEngineID;
    } else {
        completion(nil, nil, [NSError new]);
    }
    
    [[NYHTTPSClient sharedClient]
     getPath:@"MemberInvite/InviteDetail"
     parameters:param
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSDictionary *data = responseObject[kNYAPIDataKey];
        completion(returnCode, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

#pragma mark - 會員點數中心

- (void)getMemberLoyaltyPointWithShopId:(NSNumber *)shopId
                     membershipCardCode:(NSString *)membershipCardCode
                      completionHandler:(DataSourceCompletionHandler)completionHandler {
    NSDictionary *parameters;
    if (membershipCardCode) {
        parameters = @{@"shopId": shopId,
                       @"membershipCardCode": membershipCardCode};
    } else {
        parameters = @{@"shopId": shopId};
    }
    
    [[NYHTTPSClient sharedClient] getPath:@"LoyaltyPoint/GetPoints" parameters:parameters success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
        
        if ([responseObject[kNYAPIDataKey] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(data, nil);
        } else {
            completionHandler(nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

- (void)getMemberLoyaltyPointTransactionListWithShopId:(NSNumber *)shopID
                                    membershipCardCode:(NSString *)membershipCardCode
                                            startIndex:(NSInteger)startIndex
                                              maxCount:(NSInteger)maxCount
                                     completionHandler:(DataSourceCompletionHandler)completionHandler {
    NSDictionary *parm;
    if (membershipCardCode) {
        parm = @{@"shopId"             : shopID,
                 @"startIndex"         : @(startIndex),
                 @"maxCount"           : @(maxCount),
                 @"membershipCardCode" : membershipCardCode};
    } else {
        parm = @{@"shopId"     : shopID,
                 @"startIndex" : @(startIndex),
                 @"maxCount"   : @(maxCount)};
    }
    
    [[NYHTTPSClient sharedClient] getPath:@"LoyaltyPoint/GetTransactions" parameters:parm success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {

        if ([responseObject[kNYAPIDataKey] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(data, nil);
        } else {
            completionHandler(nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
    
}

- (void)gettPointExchangeECouponListWithShopId:(NSNumber *)shopId
                                    completion:(void (^)(NSString *returnCode, NSArray *data, NSError *error))completion {
    
    NSDictionary *parm = @{@"shopId" : shopId};
    
    [[NYECouponHTTPSClient sharedClient] getPath:@"ecoupon/GetPointExchangeECouponList" parameters:parm success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[@"ReturnCode"];
        NSArray *eCouponListData = responseObject[@"ShopECouponList"];
        
        completion(returnCode, eCouponListData, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completion(nil, @[], error);
    }];
}

- (void)redeemPointExchangeECouponWithECouponId:(NSNumber *)eCouponId
                             exchangeLocationId:(NSInteger)exchangeLocationId
                              outerLocationCode:(NSString *)outerLocationCode
                                   locationName:(NSString *)locationName
                                exchangeChannel:(NSString *)exchangeChannel
                                     completion:(void (^)(NSDictionary *data, NSError *error))completion {
    NSInteger locationId = (exchangeLocationId) ? exchangeLocationId : 0;
    NSString *outerCode = (outerLocationCode) ? outerLocationCode : @"";
    NSString *lName = (locationName) ? locationName : @"";
    NSString *eChannel = (exchangeChannel) ? exchangeChannel : @"All";
    [[NYHTTPSClient sharedClient]
     postPath:@"ECoupon/RedeemPointExchangeECoupon"
     parameters:@{@"eCouponId": eCouponId,
                  @"shopId": [NYGlobalData shopId],
                  @"exchangeLocationId": @(locationId),
                  @"outerLocationCode": outerCode,
                  @"locationName": lName,
                  @"exchangeChannel": eChannel,
                  @"source": @"iOSApp",
                  @"device": @"Mobile"}
     success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
         if ([responseObject isKindOfClass:[NSDictionary class]]) {
             completion(responseObject, nil);
         }
         else {
             completion(nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
         }
     }
     failure:^(NSURLSessionTask *operation, NSError *error) {
         completion(nil, error);
     }];
}

- (void)getIsPhantomMemberWithCompletion:(void(^)(NSString *returnCode, NSString *message, BOOL isPhantom, NSError *error))completion {
    [[NYHTTPSClient sharedClient]
     postPath:@"MemberV2/IsPhantomMember"
     parameters:nil
     success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        BOOL isPhantom = [responseObject[kNYAPIDataKey] boolValue];
        completion(returnCode, message, isPhantom, nil);
    }
     failure:^(NSURLSessionTask *operation, NSError *error) {
         completion(nil, nil, nil, error);
     }];
}

// H Club, UNY, Citi 的前台點數中心，不顯示類型為「消費折抵」、「消費給點」、「活動給點」的連結導頁，因這三家店的訂單不會同步，不能互查，連過去會導致出錯。(VSTS179652)
// 是否啟用此商店 會員點數交易細節 的連結導頁
- (void)getIsLoyaltyPointsTransactionsLinkEnableWithShopId:(NSNumber *)shopId
                                                completion:(void(^)(NSString *returnCode, NSString *message, BOOL isLoyaltyPointsTransactionsLinkEnable, NSError *error))completion {
    [[NYHTTPSClient sharedClient]
     postPath:@"LoyaltyPoint/IsLoyaltyPointsTransactionsLinkEnable"
     parameters:@{@"shopId" : shopId}
     success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        id data = responseObject[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]] && [data[@"IsLoyaltyPointsTransactionsLinkEnable"] isKindOfClass:[NSNumber class]]) {
            BOOL isLoyaltyPointsTransactionsLinkEnable = [data[@"IsLoyaltyPointsTransactionsLinkEnable"] boolValue];
            completion(returnCode, message, isLoyaltyPointsTransactionsLinkEnable, nil);
        } else {
            completion(returnCode, message, nil, nil);
        }
    }
     failure:^(NSURLSessionTask *operation, NSError *error) {
         completion(nil, nil, nil, error);
     }];
}

- (void)getLoyaltyPointConditionWithShopId:(NSNumber *)shopId
                         completionHandler:(void(^)(NSArray<NSDictionary *> * _Nullable data, NSError* _Nullable error))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId};
    
    [[NYHTTPSClient sharedClient] getPath:@"loyaltypoint/GetLoyaltyPointCondition"
                               parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]] &&
            [responseObject[kNYAPIDataKey] isKindOfClass:[NSArray class]]) {
            NSArray *data = responseObject[kNYAPIDataKey];
            completionHandler(data, nil);
        } else {
            completionHandler(nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

#pragma mark - Others

- (void)getMemberTierCalculateDescriptionWithCompletion:(void(^)(NSString *returnCode, NSString *message, NSString *memberDesc, NSError *error))completion {
    [[NYHTTPSClient sharedClient]
     postPath:@"Shop/GetMemberTierCalculateDescription"
     parameters:@{@"shopId": [NYGlobalData shopId]}
     success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        id data = responseObject[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSString *desc = data[@"MemberTierCalculateDescription"];
            completion(returnCode, message, desc, nil);
        } else {
            completion(returnCode, message, nil, nil);
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completion(nil, nil, nil, error);
    }];
}

- (void)logout {
    NSDictionary *param = @{@"shopId" : [NYGlobalData shopId],
                            @"lang" : @"zh-TW"};

    [[NYHTTPSClient sharedClient]
     getPath:@"Auth/Logout"
     parameters:param
     success:nil
     failure:nil];
}

- (void)insertOrUpdateCarrierCode:(NSString *)carrierCode
                       WithShopId:(NSNumber *)shopId
            WithCompletionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSError *error))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"CarrierCode": carrierCode};

    [[NYHTTPSClient sharedClient] postPath:@"vipMember/InsertOrUpdateCarrierCode"
                                parameters:parameters
                               requestType:NYHTTPRequestTypeJSON
                              responseType:NYHTTPResponseTypeJSON
                                   success:^(NSURLSessionTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSString *message = JSON[kNYAPIMessage];
            completionHandler(returnCode, message, nil);
        } else {
            completionHandler(nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)getGetCarrierCodeWithShopId:(NSNumber *)shopId
                  completionHandler:(void (^)(NSString *returnCode, NSDictionary *data, NSError *error))completionHandler {
    [[NYHTTPSClient sharedClient]
     getPath:@"VIPMember/GetCarrierCode"
     parameters:@{@"shopId": shopId}
     success:^(NSURLSessionDataTask * _Nonnull operation, id _Nonnull JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];
        completionHandler(returnCode, data, nil);
    } failure:^(NSURLSessionDataTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler (nil, nil, error);
    }];
}

- (void)requestDeleteAccountWithShopId:(NSNumber *)shopId
                          WithMemberId:(NSNumber *)memberId
                 WithCompletionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSError *error))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"MId": memberId};

    [[NYHTTPSClient sharedClient] postPath:@"Question/ApplyForDeleteAccount"
                                parameters:parameters
                               requestType:NYHTTPRequestTypeJSON
                              responseType:NYHTTPResponseTypeJSON
                                   success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSString *message = JSON[kNYAPIMessage];
            completionHandler(returnCode, message, nil);
        } else {
            completionHandler(nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);

    }];
}

#pragma mark - Line 綁定送券
/// 2.74.0 這家店是否啟用「店員幫手註冊後，進行 Line 綁定送券」
- (void)IsEnableRegisterLineBindingWithShopId:(NSNumber *)shopId
                            completionHandler:(void(^)(BOOL isEnable))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"device": @"iOS"};

    [[NYHTTPSClient sharedClient] getPath:@"Line/IsEnableRegisterLineBinding"
                               parameters:parameters
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
       if (JSON) {
           //Success
           NSString *returnCode = JSON[kNYAPIReturnCodeKey];
           BOOL data = [JSON[kNYAPIDataKey] boolValue];
           if ([returnCode isEqualToString:@"API0001"] && data) {
               completionHandler(YES);
           } else {
               completionHandler(NO);
           }
       } else {
           completionHandler(NO);
       }
   }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(NO);
   }];
}

/// 2.74.0 取得會員的 Line 綁定狀態,有錯誤情境會回傳 true
- (void)getLineBindingStatusWithShopId:(NSNumber *)shopId
                              memberId:(NSNumber *)memberId
                     completionHandler:(void(^)(BOOL isBinded))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"memberId": memberId};
    [NYHTTPSClient.sharedClient postPath:@"Line/IsLineBinding"
                              parameters:parameters
                                 success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            BOOL data = [JSON[kNYAPIDataKey] boolValue];

            if ([returnCode isEqualToString:@"API0001"] || ([returnCode isEqualToString:@"API0002"])) {
                completionHandler(data);
            } else {
                // 錯誤情境視為 已經綁定,不觸發 Line 綁定
                completionHandler(YES);
            }
        } else {
            // 錯誤情境視為 已經綁定,不觸發 Line 綁定
            completionHandler(YES);
        }
    }
                                 failure:^(NSURLSessionDataTask *operation, NSError *error) {
        // 錯誤情境視為 已經綁定,不觸發 Line 綁定
        completionHandler(YES);
    }];
}

/// 2.74.0 取得綁定送卷金額
- (void)getRewardInfoWithShopId:(NSNumber *)shopId
              completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {

    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"source": @"iOSApp",
                                 @"device": @"Mobile",
                                 @"appVer": [NYGlobalData appVersionString],
                                 @"lang": [NYLocalizationString selectedLanguageCode].length > 0 ? [NYLocalizationString selectedLanguageCode] : @"zh-TW",
                                 @"lineBindingRequestPage": @"iOS"};

    [[NYHTTPSClient sharedClient] getPath:@"SocialOfficialAccount/GetJoiningRewardInfo"
                               parameters:parameters
                              requestType:NYHTTPRequestTypeJSON
                             responseType:NYHTTPResponseTypeJSON
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
       if (JSON) {
           //Success
           NSString *returnCode = JSON[kNYAPIReturnCodeKey];
           NSString *message = JSON[kNYAPIMessage];
           NSDictionary *data = JSON[kNYAPIDataKey];
           completionHandler(returnCode, message, data, nil);
       } else {
           completionHandler(nil, nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
       }
   }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
   }];
}

/// 2.74.0 取得 Line 的隱私權 Web HTML string
- (void)getLineBindingPrivacyPolicyWithShopId:(NSNumber *)shopId
                            completionHandler:(void(^)(NSString *returnCode, NSString *message, NSString *htmlString, NSError *error))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"device": @"iOS"};
    [[NYHTTPSClient sharedClient] getPath:@"Line/GetLineBindingPrivacyPolicy"
                               parameters:parameters
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
       if (JSON) {
           //Success
           NSString *returnCode = JSON[kNYAPIReturnCodeKey];
           NSString *message = JSON[kNYAPIMessage];
           NSString *data = JSON[kNYAPIDataKey];
           completionHandler(returnCode, message, data, nil);
       } else {
           completionHandler(nil, nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
       }
   }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
   }];
}

/// 2.74.0 Line 綁定
- (void)bindLineMemberWithToken:(NSString *)token
                         shopId:(NSNumber *)shopId
                      cellPhone:(NSString *)cellPhone
                    countryCode:(NSString *)countryCode
               countryProfileId:(NSNumber *)countryProfileId
              completionHandler:(void(^)(NSString *returnCode, NSString *message, NSError *error))completionHandler {

    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"source": @"iOSApp",
                                 @"device": @"Mobile",
                                 @"appVer": [NYGlobalData appVersionString],
                                 @"accessToken": token,
                                 @"cellPhone": cellPhone,
                                 @"countryCode": countryCode,
                                 @"countryProfileId": countryProfileId
    };

    [NYHTTPSClient.sharedClient postPath:@"Line/BindingLineMember"
                              parameters:parameters
                                 success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSString *message = JSON[kNYAPIMessage];
            completionHandler(returnCode, message, nil);
        } else {
            completionHandler(nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    }
                                 failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

/// 24.12 取得 Line 綁定版位顯示設定（Hint: 會員專區最上方; Card: 會員專區 OtherFunction; PopUp: 彈窗）
- (void)getLineBindingDisplayWithShopId:(NSNumber *)shopId
                                 appVer:(NSString *)appVer
                      completionHandler:(void(^)(NSString *returnCode, NSDictionary *data, NSError *error))completionHandler {
    NSDictionary *parameters = @{@"shopId" : shopId,
                                 @"device" : @"iOS",
                                 @"appVer": appVer};
    
    [[NYHTTPSClient sharedClient] getPath:@"Line/IsLineBindingDisplay"
                               parameters:parameters
                              requestType:NYHTTPRequestTypeJSON
                             responseType:NYHTTPResponseTypeJSON
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSDictionary *data = JSON[kNYAPIDataKey];
            data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
            completionHandler(returnCode, data, nil);
        } else {
            completionHandler(nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

/// 取得商店是否有 Line Shop Account
- (void)getHasLineShopAccountWithShopId:(NSNumber *)shopId
                                 appVer:(NSString *)appVer
                      completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError *error))completionHandler {
    NSDictionary *parameters = @{@"shopId" : shopId,
                                 @"device" : @"iOS",
                                 @"appVer": appVer};
    
    [[NYHTTPSClient sharedClient] getPath:@"Line/HasLineShopAccount"
                               parameters:parameters
                              requestType:NYHTTPRequestTypeJSON
                             responseType:NYHTTPResponseTypeJSON
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSString *message = JSON[kNYAPIMessage];
            NSDictionary *data = JSON[kNYAPIDataKey];
            data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
            
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getDefaultLocationCountryWithShopId:(NSNumber *)shopId
                           countryProfileId:(NSNumber *)countryProfileId
                          completionHandler:(void(^)(NSString *returnCode, NSString *country, NSError *error))completionHandler {

    NSDictionary *parameters = @{@"shopId"              : shopId,
                                 @"countryProfileId"    : countryProfileId};

    [[NYHTTPSClient sharedClient] getPath:@"Vipmember/GetDefaultLocationCountry"
                               parameters:parameters
                              requestType:NYHTTPRequestTypeJSON
                             responseType:NYHTTPResponseTypeJSON
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
       if (JSON) {
           //Success
           NSString *returnCode = JSON[kNYAPIReturnCodeKey];
           NSString *country = JSON[kNYAPIDataKey];
           completionHandler(returnCode, country, nil);
       } else {
           completionHandler(nil, nil, NineYiErrorWithCode(0));
       }
   }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
   }];
}

- (void)getCountryCityListWithShopId:(NSNumber *)shopId
                        memberCardId:(NSNumber *)memberCardId
                   completionHandler:(void(^)(NSArray *list, NSError *error))completionHandler {

    NSDictionary *parameters = @{@"shopId"                : shopId,
                                 @"memberCardId"          : memberCardId};

    [[NYHTTPSClient sharedClient] getPath:@"zipcode/GetCountryCityList"
                               parameters:parameters
                              requestType:NYHTTPRequestTypeJSON
                             responseType:NYHTTPResponseTypeJSON
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
        if ([JSON isKindOfClass:[NSArray class]]) {
            completionHandler(JSON, nil);
        } else {
            completionHandler(nil, NineYiErrorWithCode(0));
        }
   }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
   }];
}

#pragma mark - 會員頭像
- (void)startUploadMemberPhotoWithShopId:(NSNumber *)shopId
                               photoType:(NSString *)photoType
                       completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"Type"  : photoType};
    
    [[NYHTTPSClient sharedClient] postPath:@"MemberService/StartUploadMemberPhoto"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)finishUploadMemberPhotoWithShopId:(NSNumber *)shopId
                        completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    
    NSDictionary *parameters = @{@"shopId": shopId};
    
    [[NYHTTPSClient sharedClient] postPath:@"MemberService/FinishUploadMemberPhoto"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)removeMemberPhotoWithShopId:(NSNumber *)shopId
                  completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    
    NSDictionary *parameters = @{@"shopId": shopId};
    
    [[NYHTTPSClient sharedClient] postPath:@"MemberService/RemoveMemberPhoto"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            // data 後端定義是 null
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getMemberServiceMemberInfoWithShopId:(NSNumber *)shopId
                           completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    
    NSDictionary *parameters = @{@"shopId": shopId};
    
    [[NYHTTPSClient sharedClient] postPath:@"MemberService/GetMemberInfo"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 購物金
- (void)getStoreCreditBalanceWithShopId:(NSNumber *)shopId
                      completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    
    NSDictionary *parameters = @{@"shopId": shopId};
    
    [[NYHTTPSClient sharedClient] getPath:@"StoreCredit/GetAccount"
                               parameters:parameters
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

@end
//
//  NYDataProvider+MemberCollection.m
//  NineyiAppApi
//
//  Created by Luke Wang on 2023/8/8.
//

#import "NYDataProvider+MemberCollection.h"
#import "NYHTTPSClient.h"

@implementation NYDataProvider (MemberCollection)

- (void)getMemberCollectionWithShopId:(NSNumber *)shopId
                           MemberCode:(NSString *)memberCode
                    CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSArray *data, NSError* error))completionHandler {
    NSString *path = [[NSString alloc] initWithFormat:@"MemberService/GetMemberCollection/%@/%@", shopId, memberCode];
    [[NYHTTPSClient sharedClient] getPath:path
                               parameters:nil
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSArray *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

@end
//
//  NYDataProvider+MemberShipCardManage.m
//  Pods
//
//  Created by Luke Wang on 2023/3/24.
//

#import "NYDataProvider+MemberShipCardManage.h"
#import "NYHTTPSClient.h"
#import <NYCore/NYCore-Swift.h>

@implementation NYDataProvider (MemberShipCardManage)

- (void)getVipMemberInfoOfficialIndexMemberInfoWithShopId:(NSNumber *)shopId
                                        completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"VipMemberInfoOfficialIndex/GetMemberInfo"
                               parameters:@{@"shopId": shopId}
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getComplexMemberInfoWithShopId:(NSNumber *)shopId
                           isEnableCRM:(BOOL)isEnableCRM
                isEnableMembershipCard:(BOOL)isEnableMembershipCard
                     completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"ComplexMemberInfoOfficialIndex/GetComplexMemberInfo"
                               parameters:@{@"shopId": shopId,
                                            @"isEnableCRM": isEnableCRM ? @"true" : @"false",
                                            @"isEnableMembershipCard": isEnableMembershipCard ? @"true" : @"false"}
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getMembershipCardMetasWithCompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSArray *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"MembershipCard/GetCardMetas"
                               parameters:nil
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSArray *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getMembershipCardOperationSettingsWithCompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSArray *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"MembershipCard/GetOperationSettings"
                               parameters:nil
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSArray *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getMembershipCardDetailsWithShopId:(NSNumber *)shopId
                       membershipCardCodes:(NSArray<NSString *> *)membershipCardCodes
                         CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSArray *data, NSError* error))completionHandler {
    NSDictionary *parameters = @{@"ShopId": shopId,
                                 @"MembershipCardCodes": membershipCardCodes};
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/GetMembershipCardDetails"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSArray *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getStampCountWithShopId:(NSNumber *)shopId
              CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    NSString *path = [NSString stringWithFormat:@"StampPoint/%@/Member/StampCount", shopId];
    [[NYHTTPSClient sharedClient] getPath:path
                               parameters:nil
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)setDefaultMembershipCardWithShopId:(NSNumber *)shopId
                        membershipCardCode:(NSString *)membershipCardCode
                         CompletionHandler:(void(^)(NSString *returnCode, NSString *message, BOOL data, NSError* error))completionHandler {
    NSDictionary *parameters = @{@"ShopId": shopId,
                                 @"MembershipCardCode": membershipCardCode};
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/SetDefaultCard"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            BOOL data = [responseObject[kNYAPIDataKey] boolValue];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)transferMembershipCardPointWithShopId:(NSNumber *)shopId
                       FromMembershipCardCode:(NSString *)fromMembershipCardCode
                         ToMembershipCardCode:(NSString *)toMembershipCardCode
                            CompletionHandler:(void(^)(NSString *returnCode, NSString *message, BOOL data, NSError* error))completionHandler {
    NSDictionary *parameters = @{@"ShopId": shopId,
                                 @"FromMembershipCardCode": fromMembershipCardCode,
                                 @"ToMembershipCardCode": toMembershipCardCode};
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/TransferPoint"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            BOOL data = [responseObject[kNYAPIDataKey] boolValue];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)removeMembershipCardWithShopId:(NSNumber *)shopId
                    MembershipCardCode:(NSString *)membershipCardCode
                     CompletionHandler:(void(^)(NSString *returnCode, NSString *message, BOOL data, NSError* error))completionHandler {
    NSDictionary *parameters = @{@"ShopId": shopId,
                                 @"MembershipCardCode": membershipCardCode};
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/Remove"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            BOOL data = [responseObject[kNYAPIDataKey] boolValue];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)bindingMembershipCardWithShopId:(NSNumber *)shopId
              BindingMembershipCardCode:(NSString *)bindingMembershipCardCode
                      CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    NSDictionary *parameters = @{@"ShopId": shopId,
                                 @"BindingMembershipCardCode": bindingMembershipCardCode};
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/Binding"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getMembershipCardPrivacyPolicyWithShopId:(NSNumber *)shopId
                               CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSString *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"MembershipCard/GetMembershipCardPrivacyPolicy"
                               parameters:@{@"ShopId": shopId,
                                            @"clientType": @"iOSApp"}
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSString *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getIsEnableForgottenMembershipCardWithShopId:(NSNumber *)shopId
                                   CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"MembershipCard/IsEnableForgottenMembershipCard"
                               parameters:@{@"shopId": shopId}
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)sendForgottenMembershipCardSMSWithShopId:(NSNumber *)shopId
                               CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/SendForgottenMembershipCardSMS"
                                parameters:@{@"ShopId": shopId}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)resendForgottenMembershipCardSMSByVoiceWithShopId:(NSNumber *)shopId
                                        CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/ResendForgottenMembershipCardSMSByVoice"
                                parameters:@{@"ShopId": shopId}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getForgottenMembershipCardsWithShopId:(NSNumber *)shopId
                                   VerifyCode:(NSString *)verifyCode
                            CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/GetForgottenMembershipCards"
                                parameters:@{@"ShopId": shopId,
                                             @"VerifyCode": verifyCode}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

@end
//
//  NYDataProvider+NewCoupon.m
//  NineyiAppApi
//
//  Created by Naiyu Wang on 2023/5/17.
//

#import "NYDataProvider+NewCoupon.h"
#import "NYHTTPSClient.h"
#import <NYCore/NYCore-Swift.h>

@implementation NYDataProvider (NewCoupon)


// MARK: 23.7.0 打 API 取得需使用新版或是舊版優惠券
- (void)getIsEnableNewCouponZoneWithShopId:(NSNumber *)shopId
                         completionHandler:(void (^)(NSString * _Nullable returnCode,
                                                     BOOL isEnabled,
                                                     NSError * _Nullable error))completionHandler
{
    [[NYHTTPSClient sharedClient]
     getPath:@"ShopStaticSetting/GetIsEnableNewCouponZone"
     parameters:@{@"shopId" : shopId}
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        BOOL isEnabled = [responseObject[kNYAPIDataKey] boolValue];
        completionHandler(returnCode, isEnabled, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, false, error);
    }];
}

- (void)getUnclaimedCouponsWithShopId:(NSNumber *)shopId
                   couponTypeRawValue:(NSString *)couponType
                       couponCustomId:(NSNumber * _Nullable)couponCustomId
                  channelTypeRawValue:(NSString * _Nullable)channelType
                     sortTypeRawValue:(NSString * _Nullable)sortType
                      catalogCustomId:(NSNumber * _Nullable)catalogCustomId
                               offset:(NSNumber * _Nonnull)offset
                                limit:(NSNumber * _Nullable)limit
                    completionHandler:(void (^)(NSString * _Nullable returnCode,
                                                NSString * _Nullable message,
                                                NSDictionary * _Nullable data,
                                                NSError * _Nullable error))completionHandler
{
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    [params setValue:shopId forKey:@"shopId"];
    [params setValue:@"iOSApp" forKey:@"source"];
    [params setValue:@(newCouponSupportVersion.integerValue) forKey:@"supportVersion"];
    [params setValue:[NYLocalizationString selectedLanguageCode].length > 0 ? [NYLocalizationString selectedLanguageCode] : @"zh-TW" forKey:@"lang"];
    [params setValue:couponType forKey:@"typeDef"];
    [params setValue:offset forKey:@"offset"];
    
    if (couponCustomId != nil) {
        [params setValue:couponCustomId forKey:@"ecouponCustomId"];
    }
    
    if (channelType != nil) {
        [params setValue:channelType forKey:@"channel"];
    }
    
    if (sortType != nil) {
        [params setValue:sortType forKey:@"sort"];
    }
    
    if (catalogCustomId != nil) {
        [params setValue:catalogCustomId forKey:@"catalogId"];
    }
    
    if (limit != nil) {
        [params setValue:limit forKey:@"limit"];
    }
        
    [[NYHTTPSClient sharedClient]
     getPath:@"CouponV2/GetCouponList"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        if ([data isKindOfClass:[NSDictionary class]] == false) {
            data = [NSDictionary dictionary];
        }
        
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getClaimedCouponsWithShopId:(NSNumber *)shopId
                          couponIds:(NSArray *)couponIds
                 couponTypeRawValue:(NSString *)couponType
                     couponCustomId:(NSNumber * _Nullable)couponCustomId
                channelTypeRawValue:(NSString * _Nullable)channelType
                   sortTypeRawValue:(NSString * _Nullable)sortType
                    catalogCustomId:(NSNumber * _Nullable)catalogCustomId
                             offset:(NSNumber * _Nonnull)offset
                              limit:(NSNumber * _Nullable)limit
                  completionHandler:(void (^)(NSString * _Nullable returnCode,
                                              NSString * _Nullable message,
                                              NSDictionary * _Nullable data,
                                              NSError * _Nullable error))completionHandler
{
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    [params setValue:shopId forKey:@"shopId"];
    [params setValue:@"iOSApp" forKey:@"source"];
    [params setValue:@(newCouponSupportVersion.integerValue) forKey:@"supportVersion"];
    [params setValue:couponIds forKey:@"couponIds"];
    [params setValue:[NYLocalizationString selectedLanguageCode].length > 0 ? [NYLocalizationString selectedLanguageCode] : @"zh-TW" forKey:@"lang"];
    [params setValue:couponType forKey:@"typeDef"];
    [params setValue:offset forKey:@"offset"];
    
    if (couponCustomId != nil) {
        [params setValue:couponCustomId forKey:@"ecouponCustomId"];
    }
    
    if (channelType != nil) {
        [params setValue:channelType forKey:@"channel"];
    }
    
    if (sortType != nil) {
        [params setValue:sortType forKey:@"sort"];
    }
    
    if (catalogCustomId != nil) {
        [params setValue:catalogCustomId forKey:@"catalogId"];
    }
    
    if (limit != nil) {
        [params setValue:limit forKey:@"limit"];
    }
    
    [[NYHTTPSClient sharedClient]
     postPath:@"CouponV2/GetMemberCouponList"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        if ([data isKindOfClass:[NSDictionary class]] == false) {
            data = [NSDictionary dictionary];
        }
        
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getCouponsAvailabilityWithShopId:(NSNumber *)shopId
                              couponType:(NSString *)type
                                couponId:(NSNumber *)couponId
                       completionHandler:(void (^)(NSString * _Nullable returnCode,
                                                   NSString * _Nullable message,
                                                   BOOL isAvailable,
                                                   NSError * _Nullable error))completionHandler
{
    NSDictionary *params = @{ @"shopId":shopId,
                              @"typeDef": type,
                              @"couponId":couponId
    };
    
    [[NYHTTPSClient sharedClient]
     getPath:@"CouponV2/GetCouponAvailability"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        BOOL isAvailable = [JSON[kNYAPIDataKey] boolValue];
                
        completionHandler(returnCode, message, isAvailable, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, NO, error);
    }];
}

- (void)getCouponsFilterSettingWithShopId:(NSNumber *)shopId
                        completionHandler:(void (^)(NSString * _Nullable returnCode,
                                                    NSString * _Nullable message,
                                                    NSDictionary * _Nullable data,
                                                    NSError * _Nullable error))completionHandler
{
    NSDictionary *params = @{ @"shopId":shopId,
                              @"lang":[NYLocalizationString selectedLanguageCode].length > 0 ? [NYLocalizationString selectedLanguageCode] : @"zh-TW"
    };
    
    [[NYHTTPSClient sharedClient]
     getPath:@"CouponV2/GetFilterSettings"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        if ([data isKindOfClass:[NSDictionary class]] == false) {
            data = [NSDictionary dictionary];
        }
        
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)cancelNewCouponAllDataFetching {
     [[NYHTTPSClient sharedClient] cancelAllHTTPOperationsWithMethod:@"GET" path:@"CouponV2/GetCouponList"];
     [[NYHTTPSClient sharedClient] cancelAllHTTPOperationsWithMethod:@"POST" path:@"CouponV2/GetMemberCouponList"];
     [[NYHTTPSClient sharedClient] cancelAllHTTPOperationsWithMethod:@"GET" path:@"CouponV2/GetCouponAvailability"];
     [[NYHTTPSClient sharedClient] cancelAllHTTPOperationsWithMethod:@"GET" path:@"CouponV2/GetFilterSettings"];
 }

- (void)getAvailableLocationsByEcouponIdWithShopId:(NSNumber *)shopId
                                         EcouponId:(NSNumber *)ecouponId
                                 CompletionHandler:(void (^)(NSString * _Nullable returnCode,
                                                             NSString * _Nullable message,
                                                             NSArray * _Nullable data,
                                                             NSError * _Nullable error))completionHandler {
    NSString *langString = ([NYLocalizationString selectedLanguageCode].length > 0) ? [NYLocalizationString selectedLanguageCode] : @"zh-TW";
    NSDictionary *params = @{ @"shopId": shopId,
                              @"ecouponId": ecouponId,
                              @"lang": langString
    };
    
    [[NYHTTPSClient sharedClient]
     getPath:@"CouponV2/GetAvailableLocationsByEcouponId"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSArray *data = nil;
        id dataObject = JSON[kNYAPIDataKey];
        if ([dataObject isKindOfClass:[NSArray class]]) {
            data = dataObject;
        }
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)distributeEcouponWithLocationWithShopId:(NSNumber *)shopId
                                      EcouponId:(NSNumber *)ecouponId
                                   LocationCode:(NSString *)locationCode
                              CompletionHandler:(void (^)(NSString * _Nullable returnCode,
                                                          NSString * _Nullable message,
                                                          NSDictionary * _Nullable data,
                                                          NSError * _Nullable error))completionHandler {
    NSString *langString = ([NYLocalizationString selectedLanguageCode].length > 0) ? [NYLocalizationString selectedLanguageCode] : @"zh-TW";
    NSDictionary *params = @{ @"shopId": shopId,
                              @"ecouponId": ecouponId,
                              @"locationCode": locationCode,
                              @"source": @"iOSApp",
                              @"supportVersion": @(newCouponSupportVersion.integerValue),
                              @"lang": langString
    };
    
    [[NYHTTPSClient sharedClient]
     postPath:@"CouponV2/DistributeEcouponWithLocation"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)transferECouponWithShopId:(NSNumber *)shopId
                        eCouponId:(NSNumber *)eCouponId
                   eCouponSlaveId:(NSNumber *)eCouponSlaveId
                        cellPhone:(NSString *)cellPhone
                        aliasCode:(NSString *)aliasCode
                completionHandler:(void (^)(NSString * _Nullable returnCode,
                                            NSString * _Nullable message,
                                            NSError * _Nullable error))completionHandler {
    NSString *langString = ([NYLocalizationString selectedLanguageCode].length > 0) ? [NYLocalizationString selectedLanguageCode] : @"zh-TW";
    NSDictionary *params = @{ @"shopId": shopId,
                              @"eCouponId": eCouponId,
                              @"eCouponSlaveId": eCouponSlaveId,
                              @"cellPhone": cellPhone,
                              @"aliasCode": aliasCode,
                              @"source": @"iOSApp",
                              @"lang": langString
    };
    
    [[NYHTTPSClient sharedClient]
     postPath:@"CouponV2/TransferECoupon"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        
        completionHandler(returnCode, message, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)getTransferCouponIdListWithShopId:(NSNumber *)shopId
                             couponIdList:(NSArray<NSNumber *> *)couponIdList
                        completionHandler:(void (^)(NSString * _Nullable returnCode,
                                                    NSString * _Nullable message,
                                                    NSDictionary * _Nullable data,
                                                    NSError * _Nullable error))completionHandler {
    NSString *langString = ([NYLocalizationString selectedLanguageCode].length > 0) ? [NYLocalizationString selectedLanguageCode] : @"zh-TW";
    NSDictionary *params = @{ @"shopId": shopId,
                              @"couponIdList": couponIdList,
                              @"source": @"iOSApp",
                              @"lang": langString
    };
    
    [[NYHTTPSClient sharedClient]
     postPath:@"CouponV2/GetTransferCouponIdList"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

@end
//
//  NYDataProvider+PromotionEngine.m
//  NineyiAppApi
//
//  Created by Irelia Song on 2019/4/12.
//

#import "NYDataProvider+PromotionEngine.h"
#import "NYHTTPSClient.h"
#import "NYCDNHTTPClient.h"
#import "NYGlobalData.h"
#import <NYCore/NYCore-Swift.h>

#import <NYCore/NSString+JSON.h>
#import <NYCore/NSArray+Map.h>

static NSString * const kShopIDKey = @"ShopId";
static NSString * const kPromotionIDKey = @"PromotionId";
static NSString * const kSalePageListKey = @"SalePageList";
static NSString * const kSalePageIDKey = @"SalePageId";
static NSString * const kSalePageSKUIDKey = @"SaleProductSKUId";
static NSString * const kTagIdsKey = @"TagIds";
static NSString * const kQtyKey = @"Qty";
static NSString * const kPriceKey = @"Price";

@interface NYPromotionEngineCalculateParamObject ()
@property (nonatomic, strong) NSNumber *shopID;
@property (nonatomic, strong) NSNumber *promotionID;
@property (nonatomic, strong) NSMutableArray *salePageList;

@end

@implementation NYPromotionEngineCalculateParamObject

- (instancetype)initWithShopID:(NSNumber *)shopID promotionID:(NSNumber *)promotionID {
    if (self = [self init]) {
        _shopID = shopID;
        _promotionID = promotionID;
        _salePageList = [NSMutableArray array];
    }
    
    return self;
}

- (void)updateWithSalePageList:(NSArray<NYPromotionEngineCalculateParamSalePageObject *> *)salePageList {
    self.salePageList = [[NSMutableArray alloc] initWithArray:[salePageList map:^id(NYPromotionEngineCalculateParamSalePageObject * obj) {
        return @{
            kSalePageIDKey: obj.salePageId,
            kSalePageSKUIDKey: obj.skuId,
            kQtyKey: obj.qty,
            kPriceKey: obj.price,
            kTagIdsKey: obj.promotionTags,
        };
    }]];
}

// 累加
- (void)addSalePageWithSalePageID:(NSNumber *)targetSalePageID
                    salePageSKUID:(NSNumber *)targetSalePageSKUID
                              qty:(NSNumber *)targetQty
                            price:(NSNumber *)price
            salePagePromotionTags:(NSArray <NSString *> *)salePagePromotionTags {
    __block BOOL hasFoundSalePage = NO;

    [_salePageList enumerateObjectsUsingBlock:^(NSMutableDictionary * _Nonnull salePageDict, NSUInteger idx, BOOL * _Nonnull stop) {
        NSNumber *salePageID = salePageDict[kSalePageIDKey];
        NSNumber *salePageSKUID = salePageDict[kSalePageSKUIDKey];
        
        if ([salePageID isEqualToNumber:targetSalePageID] && [salePageSKUID isEqualToNumber:targetSalePageSKUID]) {
            NSNumber *qty = salePageDict[kQtyKey];
            qty = @(qty.integerValue + targetQty.integerValue);
            salePageDict[kQtyKey] = qty;
            
            hasFoundSalePage = YES;
            *stop = YES;
        }
    }];
    
    if (hasFoundSalePage == NO) {
        NSMutableDictionary *product = [NSMutableDictionary new];
        product[kSalePageIDKey] = targetSalePageID;
        product[kSalePageSKUIDKey] = targetSalePageSKUID;
        product[kQtyKey] = targetQty;
        product[kPriceKey] = price;
        product[kTagIdsKey] = salePagePromotionTags;
        [_salePageList addObject:[product mutableCopy]];
    }
}

// 覆蓋
- (void)coverageSalePageWithSalePageID:(NSNumber *)targetSalePageID
                         salePageSKUID:(NSNumber *)targetSalePageSKUID
                                   qty:(NSNumber *)targetQty
                                 price:(NSNumber *)price
                 salePagePromotionTags:(NSArray <NSString *> *)salePagePromotionTags {
    __block BOOL hasFoundSalePage = NO;
    
    [_salePageList enumerateObjectsUsingBlock:^(NSMutableDictionary * _Nonnull salePageDict, NSUInteger idx, BOOL * _Nonnull stop) {
        NSNumber *salePageID = salePageDict[kSalePageIDKey];
        NSNumber *salePageSKUID = salePageDict[kSalePageSKUIDKey];
        
        if ([salePageID isEqualToNumber:targetSalePageID] && [salePageSKUID isEqualToNumber:targetSalePageSKUID]) {
            NSNumber *qty = salePageDict[kQtyKey];
            qty = @(targetQty.integerValue);
            salePageDict[kQtyKey] = qty;
            
            hasFoundSalePage = YES;
            *stop = YES;
        }
    }];
    
    if (hasFoundSalePage == NO) {
        [_salePageList addObject:[@{kSalePageIDKey: targetSalePageID,
                                    kSalePageSKUIDKey: targetSalePageSKUID,
                                    kQtyKey: targetQty,
                                    kPriceKey: price,
                                    kTagIdsKey: salePagePromotionTags} mutableCopy]];
    }
}

- (void)removeSalePageWithSalePageID:(NSNumber *)targetSalePageID
                       salePageSKUID:(NSNumber *)targetSalePageSKUID {
    __weak typeof(self) weakSelf = self;

    [_salePageList enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull salePageDict, NSUInteger idx, BOOL * _Nonnull stop) {
        typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            NSNumber *salePageID = salePageDict[kSalePageIDKey];
            NSNumber *salePageSKUID = salePageDict[kSalePageSKUIDKey];
            if ([salePageID isEqualToNumber:targetSalePageID] && [salePageSKUID isEqualToNumber:targetSalePageSKUID]) {
                [weakSelf.salePageList removeObjectAtIndex:idx];
            }
        }
    }];
}

- (void)removeLastSalePage {
    [_salePageList removeLastObject];
}

- (void)removeAllSalePage {
    [_salePageList removeAllObjects];
}

- (NSDictionary *)genCalculateAPIParam {
    NSDictionary *rawCartDict = @{kShopIDKey: _shopID,
                                  kPromotionIDKey: _promotionID,
                                  kSalePageListKey: _salePageList
                                  };
    
    NSString *rawCartJSONString = [NSString JSONFloatFixedStringFromDictionary:rawCartDict];
    
    return @{@"promotionDetailDiscount":rawCartJSONString,
             @"source":@"iOSApp"};
}

@end

@implementation NYDataProvider (PromotionEngine)

- (void)getShopPromotionEngineListDisplaySettingsWithShopId:(NSNumber *)shopId
                                          completionHandler:(void (^)(NSDictionary *json, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    
    NSString *path = [NSString stringWithFormat:@"PromotionEngine/GetListDisplaySettings/%@", shopId];
    
    [[NYCDNHTTPClient sharedClient] getPath:path parameters:nil success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *json = response[kNYAPIDataKey];
        
        completionHandler(json, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getShopPromotionEnginePromptWithShopId:(NSNumber *)shopId
                                   promotionId:(NSNumber *)promotionId
                             completionHandler:(void (^)(NSDictionary *json, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    
    NSString *path = [NSString stringWithFormat:@"PromotionEngine/GetPrompt/%@/%@", shopId, promotionId];
    NSDictionary *param = @{@"promptType":@"list"};
    
    [[NYCDNHTTPClient sharedClient] getPath:path parameters:param success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *json = response[kNYAPIDataKey];
        
        completionHandler(json, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getShopPromotionEngineDetailWithShopId:(NSNumber *)shopId
                                  memberCardId:(NSNumber *)memberCardId
                                   promotionId:(NSNumber *)promotionId
                             completionHandler:(void (^)(NSDictionary *data, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    
    NSDictionary *params = @{@"appVer":[NYGlobalData appVersionString],
                             @"crmShopMemberCardId":memberCardId ?: @0,
                             @"source":@"iOS"};

    NSString *path = [NSString stringWithFormat:@"PromotionEngine/GetDetail/%@/%@/%@", shopId, promotionId, promotionSupportVersion];

    [[NYCDNHTTPClient sharedClient] getPath:path parameters:params success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *json = response[kNYAPIDataKey];
        
        completionHandler(json, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getShopPromotionEngineDetailSalePgeeListWithShopId:(NSNumber *)shopId
                                               promotionId:(NSNumber *)promotionId
                                                categoryId:(NSString *)categoryId
                                       promotionEngineType:(NYPromotionEngineType)promotionEngineType
                                                    listId:(NSString *)listId
                                          collectionIdDict:(NSDictionary *)collectionIdDict
                                                startIndex:(NSInteger)startIndex
                                                  maxCount:(NSInteger)maxCount
                                           nextResultToken:(NSString *)nextResultToken
                                         completionHandler:(void (^)(NSDictionary *json, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    NSMutableDictionary *params = [NSMutableDictionary new];
    NSString *targetId = listId.length > 0 ? listId : @"";

    NSString *path = [NSString stringWithFormat:@"PromotionEngine/GetSalePageList/%@/%@", shopId, promotionId];
    if (promotionEngineType == NYPromotionEngineTypeReachGroupsPiece) {
        params = @{@"tagids": targetId,
                   @"startIndex": @(startIndex),
                   @"maxCount": @(maxCount)}.mutableCopy;
        
    } else if (promotionEngineType == NYPromotionEngineTypeReachPriceWithFreeGift) {
        BOOL isMustBuy = [targetId isEqualToString:collectionIdDict[@"MustBuyCollectionID"]];
        params = @{@"categoryId": categoryId,
                   @"startIndex": @(startIndex),
                   @"maxCount": @(maxCount),
                   @"nextResultToken": nextResultToken}.mutableCopy;
        
        if (isMustBuy) {
            params[@"mustCollectionId"] = targetId;
            
        } else {
            params[@"collectionId"] = targetId;
        }
        
    } else {
        params = @{@"categoryId": categoryId,
                   @"startIndex": @(startIndex),
                   @"maxCount": @(maxCount)}.mutableCopy;
    }

    
    [[NYCDNHTTPClient sharedClient] getPath:path parameters:params success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *json = response[kNYAPIDataKey];
        
        completionHandler(json, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getMatchedCartSalePageListWithShopId:(NSNumber *)shopId
                                 promotionId:(NSNumber *)promotionId
                           completionHandler:(void (^)(NSArray *data, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    NSString *path = @"PromotionEngine/GetMatchedCartSalePageList";
    NSDictionary *params = @{@"shopId":shopId,
                             @"promotionId":promotionId,
                             @"source":@"iOSApp"};
    
    [[NYHTTPSClient sharedClient] postPath:path
                                parameters:params
                                   success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
                                       NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
                                       NSString *message = responseObject[kNYAPIMessage];
                                       NSArray *data = responseObject[kNYAPIDataKey];
                                       
                                       completionHandler(data, returnCode, message, nil);
                                   } failure:^(NSURLSessionTask *operation, NSError *error) {
                                       completionHandler(nil, nil, nil, error);
                                   }];
}

- (void)calculatePromotionEngineCartWithParam:(NYPromotionEngineCalculateParamObject *)paramObject
                      completionHandler:(void (^)(NSDictionary *data, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    
    NSDictionary *params = [paramObject genCalculateAPIParam];

    [[NYHTTPSClient sharedClient] postPath:@"PromotionEngine/Calculate"
                                parameters:params
                                   success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
                                       NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
                                       NSString *message = responseObject[kNYAPIMessage];
                                       NSDictionary *data = responseObject[kNYAPIDataKey];

                                       completionHandler(data, returnCode, message, nil);
                                   } failure:^(NSURLSessionTask *operation, NSError *error) {
                                       completionHandler(nil, nil, nil, error);
                                   }];
}

- (void)promotionEngineGetIsMatchedUserScopedWithShopId:(NSNumber *)shopId
                                            promotionId:(NSNumber *)promotionId
                                      completionHandler:(void (^)(NSDictionary *data, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    
    NSString *path = [NSString stringWithFormat:@"PromotionEngine/IsMatchedUserScopes/%@/%@", shopId, promotionId];
    
    [[NYHTTPSClient sharedClient] getPath:path parameters:nil success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *json = response[kNYAPIDataKey];
        
        completionHandler(json, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

@end
//
//  NYDataProvider+PromotionV2.m
//  Pods
//
//  Created by Eric Huang on 2016/8/23.
//
//

#import "NYDataProvider+PromotionV2.h"
#import "NYHTTPSClient.h"
#import "NYCDNHTTPClient.h"
#import "NYGlobalData.h"

#import <NYCore/NSString+JSON.h>

static NSString * const kShopIDKey = @"ShopId";
static NSString * const kPromotionIDKey = @"PromotionId";
static NSString * const kSalePageListKey = @"SalePageList";
static NSString * const kSalePageIDKey = @"SalePageId";
static NSString * const kSalePageSKUIDKey = @"SaleProductSKUId";
static NSString * const kQtyKey = @"Qty";
static NSString * const kPriceKey = @"Price";

@interface NYPromotionCalculateParamObject ()
@property (nonatomic, copy) NSNumber *shopID;
@property (nonatomic, copy) NSNumber *promotionID;
@property (nonatomic, strong) NSMutableArray <NSDictionary <NSString *, NSNumber *> *> *salePageList;
@end

@implementation NYPromotionCalculateParamObject

- (instancetype)initWithShopID:(NSNumber *)shopID promotionID:(NSNumber *)promotionID {
    if (self = [self init]) {
        _shopID = shopID;
        _promotionID = promotionID;
        _salePageList = [NSMutableArray array];
    }
    
    return self;
}

- (void)addSalePageWithSalePageID:(NSNumber *)targetSalePageID
                    salePageSKUID:(NSNumber *)targetSalePageSKUID
                              qty:(NSNumber *)targetQty
                            price:(NSNumber *)price {
    __block BOOL hasFoundSalePage = NO;
    
    [[_salePageList copy] enumerateObjectsUsingBlock:^(NSMutableDictionary * _Nonnull salePageDict, NSUInteger idx, BOOL * _Nonnull stop) {
        NSNumber *salePageID = salePageDict[kSalePageIDKey];
        NSNumber *salePageSKUID = salePageDict[kSalePageSKUIDKey];
        
        if ([salePageID isEqualToNumber:targetSalePageID] && [salePageSKUID isEqualToNumber:targetSalePageSKUID]) {
            NSNumber *qty = salePageDict[kQtyKey];
            qty = @(qty.integerValue + targetQty.integerValue);
            salePageDict[kQtyKey] = qty;
            
            hasFoundSalePage = YES;
            *stop = YES;
        }
    }];

    if (hasFoundSalePage == NO) {
        [_salePageList addObject:[@{kSalePageIDKey: targetSalePageID,
                                    kSalePageSKUIDKey: targetSalePageSKUID,
                                    kQtyKey: targetQty,
                                    kPriceKey: price} mutableCopy]];
    }
}

- (void)removeSalePageWithSalePageID:(NSNumber *)targetSalePageID
                       salePageSKUID:(NSNumber *)targetSalePageSKUID {
    __weak typeof(self) weakSelf = self;
    [[_salePageList copy] enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull salePageDict, NSUInteger idx, BOOL * _Nonnull stop) {
        NSNumber *salePageID = salePageDict[kSalePageIDKey];
        NSNumber *salePageSKUID = salePageDict[kSalePageSKUIDKey];
        if ([salePageID isEqualToNumber:targetSalePageID] && [salePageSKUID isEqualToNumber:targetSalePageSKUID]) {
            [weakSelf.salePageList removeObjectAtIndex:idx];
        }
    }];
}

- (void)removeLastSalePage {
    [_salePageList removeLastObject];
}

- (NSDictionary *)genCalculateAPIParam {
    
    NSDictionary *rawCartDict = @{kShopIDKey: _shopID,
                                  kPromotionIDKey: _promotionID,
                                  kSalePageListKey: _salePageList
                                  };
    
    NSString *rawCartJSONString = [NSString JSONFloatFixedStringFromDictionary:rawCartDict];

    return @{@"promotionDetailDiscount":rawCartJSONString,
             @"appVer":[NYGlobalData appVersionString]
             };
}

@end

@implementation NYDataProvider (PromotionV2)

- (void)getShopPromotionV2ListWithShopId:(NSNumber *)shopId
                                 orderBy:(NSString *)orderBy
                              startIndex:(NSInteger)startIndex
                                maxCount:(NSInteger)maxCount
                                 typeDef:(NSString *)typeDef
                              sourcePage:(NSString *)sourcePage
                     crmShopMemberCardId:(NSNumber *)crmShopMemberCardId
                       completionHandler:(void (^)(NSDictionary *json, NSString *returnCode, NSString *message, NSError *error))completionHandler {

    /*
     - from = module(CMS 活動模組,有小標籤),list(活動列表,不會塞小標籤)
     - sourcePage = All, SalePage(商品頁), PromotionList(活動頁表), CmsModule(CMS 所有頁面), HomePage(首頁)... 可參考 BFF PromotionSourcePageType
       某些活動(ex.登記活動)，客戶可選擇哪些前端頁面需要顯示，故前端會須帶所在頁面上來；不帶的話後端會全給
     */
    NSDictionary *promotionParams = @{@"orderBy":orderBy,
                                      @"startIndex":@(startIndex),
                                      @"maxCount":@(maxCount),
                                      @"typeDef":typeDef,
                                      @"source":@"iOSApp",
                                      @"from":@"list",
                                      @"sourcePage":sourcePage,
                                      @"appVer":[NYGlobalData appVersionString],
                                      @"r":@"f"};
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:promotionParams];
    
    if (crmShopMemberCardId) {
        [params addEntriesFromDictionary:@{@"crmShopMemberCardId":crmShopMemberCardId.stringValue}];
    }
    
    // api error code: N:002.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    NSString *path = [NSString stringWithFormat:@"PromotionV2/GetList/%@/%@", shopId, promotionSupportVersion];
    
    [[NYCDNHTTPClient sharedClient] getPath:path parameters:params success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *json = response[kNYAPIDataKey];
        
        completionHandler(json, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getShopPromotionV2DetailWithPromotionId:(NSNumber *)promotionId
                              completionHandler:(void (^)(NSDictionary *json, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    NSString *path = [NSString stringWithFormat:@"PromotionV2/GetDetail/%@", promotionId];
    
    [[NYCDNHTTPClient sharedClient] getPath:path parameters:nil success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *json = response[kNYAPIDataKey];
        
        completionHandler(json, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getShopPromotionV2SalePageListWithShopId:(NSNumber *)shopId
                                     promotionId:(NSNumber *)promotionId
                                      categoryId:(NSNumber *)categoryId
                                      startIndex:(NSInteger)startIndex
                                        maxCount:(NSInteger)maxCount
                               completionHandler:(void (^)(NSDictionary *json, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    NSDictionary *params = @{@"categoryId":categoryId,
                             @"startIndex":@(startIndex),
                             @"maxCount":@(maxCount)};
    
    NSString *path = [NSString stringWithFormat:@"PromotionV2/GetSalePageList/%@/%@", shopId, promotionId];
    
    [[NYCDNHTTPClient sharedClient] getPath:path parameters:params success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *json = response[kNYAPIDataKey];
        
        completionHandler(json, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];

}

- (void)calculatePromotionCartWithParam:(NYPromotionCalculateParamObject *)paramObject
                      completionHandler:(void (^)(NSDictionary *data, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"PromotionV2/Calculate"
                                parameters:[paramObject genCalculateAPIParam]
                                   success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
                                       NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
                                       NSString *message = responseObject[kNYAPIMessage];
                                       NSDictionary *data = responseObject[kNYAPIDataKey];
                                       
                                       completionHandler(data, returnCode, message, nil);
                                   } failure:^(NSURLSessionTask *operation, NSError *error) {
                                       completionHandler(nil, nil, nil, error);
                                   }];
}

- (void)getPromotionListForCrmMemberTierWithShopId:(NSNumber *)shopId
                                      memberCardId:(NSNumber *)memberCardId
                                 completionHandler:(void (^)(NSDictionary *json, NSError *error))completionHandler {
    NSString *path = [NSString stringWithFormat:@"PromotionV2/GetListForCrmMemberTier/%@/%@", shopId, memberCardId];
    
    [[NYHTTPSClient sharedClient] getPath:path parameters:nil success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSDictionary *json = response[kNYAPIDataKey];

        completionHandler(json, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];

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
//  NYDataProvider+ShoppingCartV4.m
//  NineyiAppShop
//
//  Created by Daniel Kao on 5/23/16.
//  Copyright © 2016 91App. All rights reserved.
//

#import "NYDataProvider+ShoppingCartV4.h"
#import "NYHTTPSClient.h"
#import "NYCDNHTTPClient.h"
#import "NYCartHTTPSClient.h"
#import <NYCore/NYCore-Swift.h>
#import <NYCore/NYUserDefault.h>
#import <NYCore/NSString+JSON.h>

@implementation NYDataProvider (ShoppingCartV4)

- (void)getShoppingCartV4PreviewMappingWithCompletionHandler:(nonnull void (^)(NSArray * _Nullable previewJSONList, NSString * _Nullable returnCode, NSString * _Nullable message, NSError * _Nullable error))completionHandler {
    NSNumber *shopID = [NYGlobalData shopId];
    NSDictionary *params = @{@"shopId":shopID};
    
    [[NYCartHTTPSClient sharedClient]
     getPath:@"ShoppingCartV4/GetShoppingCartPreviewTypeMapping"
     parameters:params
     success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSArray *previewJSONList = response[kNYAPIDataKey];
        completionHandler(previewJSONList, returnCode, message, nil);
        
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getShoppingCartV3PreviewWithCompletionHandler:(void (^)(NSDictionary * _Nullable, NSString * _Nullable, NSString * _Nullable, NSError * _Nullable))completionHandler {
    NSNumber *shopID = [NYGlobalData shopId];
    NSDictionary *params = @{@"shopId":shopID};
    
    [[NYCartHTTPSClient sharedClient]
     getPath:@"ShoppingCartV3/GetShoppingCartPreview"
     parameters:params
     success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *previewJSONDict = response[kNYAPIDataKey];

        completionHandler(previewJSONDict, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getShoppingCartV4WithShopID:(NSNumber *)shopID
                             source:(NSString *)source
                            channel:(NSString *)channel
                             device:(NSString *)device
                         appVersion:(NSString *)appVersion
                        previewType:(NSString *)previewType
                  completionHandler:(void (^)(NSDictionary *cartJSONDict, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:
                                   @{@"shopId":shopID,
                                     @"source":source,
                                     @"channel":channel,
                                     @"device":device,
                                     @"appVer":appVersion,
                                     @"PromoCodePoolGroupId": [NYUserDefault promoCodePoolGroupID] ? : @"",
                                     @"PromoCode":[NYUserDefault promoCode] ? : @"",
                                     @"ECouponVersion":eCouponSupportVersion
                                   }];
    if ([NYUserDefault isEnableCartPreview] && previewType) {
        [params setObject:previewType forKey:@"PreviewType"];
    }

    [[NYCartHTTPSClient sharedClient] getPath:@"ShoppingCartV4/GetShoppingCart" parameters:params success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *cartJSONDict = response[kNYAPIDataKey];

        completionHandler(cartJSONDict, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)calculateShoppingCartV4:(NSDictionary *)rawCartDict
                     appVersion:(NSString *)appVersion
              completionHandler:(void (^)(NSDictionary *cartJSONDict, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    NSString *rawCartJSONString = [NSString JSONFloatFixedStringFromDictionary:rawCartDict];
    NSDictionary *params = @{@"shoppingCart":rawCartJSONString,
                             @"appVer":appVersion};
    
    [[NYCartHTTPSClient sharedClient] postPath:@"ShoppingCartV4/Calculate"
                                    parameters:params
                                       success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *rawCartDict = response[kNYAPIDataKey];
        
        completionHandler(rawCartDict, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)requestPayProcessUrlV2WithCartDict:(nonnull NSDictionary *)rawCartDict
                         completionHandler:(nonnull void (^)(NSString * _Nullable payProcessURLString,
                                                             NSString * _Nullable returnCode,
                                                             NSString * _Nullable message,
                                                             NSError * _Nullable error))completionHandler {
    NSString *rawCartJSONString = [NSString JSONFloatFixedStringFromDictionary:rawCartDict];
    
    [[NYCartHTTPSClient sharedClient] postPath:@"PayV2/RequestPayProcessUrlV2"
                                    parameters:@{@"shoppingcart":rawCartJSONString}
                                       success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSString *payProcessURLString = response[kNYAPIDataKey];
        
        completionHandler(payProcessURLString, returnCode, message, nil);
        
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)updateSalePageQtyBySalePageID:(NSNumber *)salePageID
                 salePageProductSKUID:(NSNumber *)salePageProductSKUID
                     salePageGroupSeq:(NSNumber *)salePageGroupSeq
                          salePageQty:(NSNumber *)salePageQty
                               shopID:(NSNumber *)shopID
                      optionalTypeDef:(NSString *)optionalTypeDef
                       optionalTypeId:(NSNumber *)optionalTypeId
                    completionHandler:(void (^)(NSString * _Nullable returnCode, NSString * _Nullable message, NSError * _Nullable error))completionHandler {
    NSMutableDictionary *params = [NSMutableDictionary new];
    params[@"SalePageId"] = salePageID;
    params[@"SaleProductSKUId"] = salePageProductSKUID;
    params[@"SalePageSeq"] = salePageGroupSeq;
    params[@"Qty"] = salePageQty;
    params[@"ShopId"] = shopID;

    if (optionalTypeDef && optionalTypeId) {
        params[@"OptionalTypeDef"] = optionalTypeDef;
        params[@"OptionalTypeId"] = optionalTypeId;
    } 
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:0 error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    [[NYCartHTTPSClient sharedClient]
     postPath:@"ShoppingCartV3/UpdateShoppingCartQty"
     parameters:@{@"qty":jsonString}
     success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        completionHandler(returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)addToCartByShopID:(nonnull NSNumber *)shopID
               salePageID:(nonnull NSNumber *)salePageID
            salePageSKUID:(nonnull NSNumber *)salePageSKUID
                      qty:(nonnull NSNumber *)qty
       isSkuQtyAccumulate:(BOOL)isSkuQtyAccumulate
            deliverPeriod:(nullable NSNumber *)deliverPeriod
          maxDeliverCount:(nullable NSNumber *)maxDeliverCount
               optionEnum:(nullable NSNumber *)optionEnum
          optionalTypeDef:(nullable NSString *)optionalTypeDef
           optionalTypeId:(nullable NSNumber *)optionalTypeId
        completionHandler:(nonnull void (^)(NSString * _Nullable returnCode, NSString * _Nullable message, NSError * _Nullable error))completionHandler {
    NSString *path = [[NSString alloc] initWithFormat:@"ShoppingCartV4/InsertItem/%@",
                      NYApiSupportVersion.cartSupportVersion];
    NSMutableDictionary *params = [NSMutableDictionary new];
    params[@"shopId"] = shopID;
    params[@"salePageId"] = salePageID;
    params[@"saleProductSKUId"] = salePageSKUID;
    params[@"qty"] = qty;
    params[@"isSkuQtyAccumulate"] = @(isSkuQtyAccumulate);
    
    // 定期購選項參數會有帶著 "<null>" 的情境
    id paramDeliverPeriod = deliverPeriod ?: [NSNull null];
    id paramMaxDeliverCount = maxDeliverCount ?: [NSNull null];
    id paramOptionEnum = optionEnum ?: [NSNull null];
    
    if (deliverPeriod && maxDeliverCount && optionEnum) {
        params[@"optionalInfo"] = @{@"DeliverPeriod":paramDeliverPeriod,
                                    @"MaxDeliverCount":paramMaxDeliverCount,
                                    @"OptionEnum":paramOptionEnum};
    } else {
        // 若參數皆為 "<null>", "optionalInfo" 節點帶 "<null>" 上去
        params[@"optionalInfo"] = [NSNull null];
    }

    if ([optionalTypeDef isEqualToString:@"PointsPay"]) {
        params[@"OptionalTypeDef"] = optionalTypeDef;
        params[@"OptionalTypeId"] = optionalTypeId;
    } else {
        params[@"OptionalTypeDef"] = @"";
        params[@"OptionalTypeId"] = @0;
    }
    
    [[NYCartHTTPSClient sharedClient] postPath:path
                                    parameters:params
                                       success:^(NSURLSessionTask *operation, NSDictionary *response) {
                                       NSString *returnCode = response[kNYAPIReturnCodeKey];
                                       NSString *message = response[kNYAPIMessage];
                                       completionHandler(returnCode, message, nil);
                                   }
                                   failure:^(NSURLSessionTask *operation, NSError *error) {
                                       completionHandler(nil, nil, error);
                                   }];
}

- (void)addToCartWithPXItemListByShopID:(nonnull NSNumber *)shopID
                             salePageID:(nonnull NSNumber *)salePageID
                          salePageSKUID:(nonnull NSNumber *)salePageSKUID
                                    qty:(nonnull NSNumber *)qty
                      completionHandler:(nonnull void (^)(NSString * _Nullable returnCode, NSString * _Nullable message, NSDictionary * _Nullable data, NSError * _Nullable error))completionHandler {
    NSString *path = [NSString stringWithFormat:@"ShoppingCartQty/ModifyItem/%@", shopID];
    NSMutableDictionary *params = [NSMutableDictionary new];
    params[@"shopId"] = shopID;
    params[@"salePageId"] = salePageID;
    params[@"saleProductSKUId"] = salePageSKUID;
    params[@"qty"] = qty;
    
    [[NYCartHTTPSClient sharedClient] postPath:path
                                    parameters:params
                                       success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *data = response[kNYAPIDataKey];
        
        completionHandler(returnCode, message, data, nil);
    }
                                       failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)removeSalePageBySalePageID:(nonnull NSNumber *)salePageID
              salePageProductSKUID:(nonnull NSNumber *)salePageProductSKUID
                  salePageGroupSeq:(nonnull NSNumber *)salePageGroupSeq
                            shopID:(nonnull NSNumber *)shopID
                   optionalTypeDef:(nullable NSString *)optionalTypeDef
                    optionalTypeId:(nullable NSNumber *)optionalTypeId
                         itemGroup:(nullable NSNumber *)itemGroup
                 completionHandler:(nonnull void (^)(NSString * _Nullable returnCode ,NSError * _Nullable error))completionHandler {
    // *** 注意 ***
    // Server不會回傳returnCode，如果刪除失敗就是直接走failure block
    NSMutableDictionary *params = [NSMutableDictionary new];
    params[@"SalePageId"] = salePageID;
    params[@"SaleProductSKUId"] = salePageProductSKUID;
    params[@"SalePageSeq"] = salePageGroupSeq;
    params[@"ShopId"] = shopID;

    if (optionalTypeDef && optionalTypeId) {
        params[@"OptionalTypeDef"] = optionalTypeDef;
        params[@"OptionalTypeId"] = optionalTypeId;
    }

    if (itemGroup) {
        params[@"CartExtendInfoItemGroup"] = itemGroup;
    }

    [[NYHTTPSClient sharedClient] postPath:@"ShoppingCartV2/RemoveItem" parameters:params success:^(NSURLSessionTask *operation, id responseObject) {
        completionHandler(nil, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

- (void)getShopDiscountDataWithPromotionId:(NSInteger)promotionId
                                startIndex:(NSUInteger)starindex
                                  maxCount:(NSUInteger)maxCount
                         CompletionHandler:(DataSourceCompletionHandler)handler {
    
    NSDictionary *parameters = @{@"id":@(promotionId),
                                 @"startIndex":@(starindex),
                                 @"maxCount":@(maxCount)};
    
    [[NYHTTPSClient sharedClient]
     getPath: @"Promotion/GetDetail"
     parameters: parameters
     success:^(NSURLSessionTask *operation, NSDictionary* JSON) {
         if (JSON) {
             //Note:舊API, error時會傳string, 這邊硬轉成新式的Error格式
             if ([JSON isKindOfClass:[NSString class]]) {
                 NSString *message = (NSString *)JSON;
                 JSON = @{@"ReturnCode" : @"API0002",
                          @"Data" : [NSDictionary dictionary],
                          @"Message" : message};
             }
             
             handler(@{kDATA_KEY : JSON}, nil);
         }
         else {
             handler( nil, NineYiErrorWithCode(NYDataProviderErrorCodeNoJSON) );
         }
     }
     failure:^(NSURLSessionTask *operation, NSError *error) {
         handler( nil, error );
     }];
}

- (void)getLocationListForPickupByShopId:(nonnull NSNumber *)shopId
                            isLocalStore:(BOOL)isLocalStore
                              startIndex:(NSUInteger)starindex
                                maxCount:(NSUInteger)maxCount
                       completionHandler:(void (^)(NSDictionary * _Nullable JSON, NSError * _Nullable error))completionHandler {
    // 2021/3/29: 91命名法 全部:0 國內:1 國外:2
    NSNumber *areaType = isLocalStore ? @1 : @2;
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"areaType": areaType,
                                 @"searchKey": @"",
                                 @"startIndex": @(starindex),
                                 @"maxCount": @(maxCount)};
    [[NYCartHTTPSClient sharedClient]
     getPath:@"LocationV2/GetLocationListForPickup"
     parameters:parameters
     success:^(NSURLSessionTask *operation, NSDictionary *response) {
         completionHandler(response, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

#pragma mark - 2.24.0 購物車加購

- (void)getBuyExtraItemListByShopId:(nonnull NSNumber *)shopId
                         locationId:(nonnull NSNumber *)locationId
                  completionHandler:(nonnull void (^)(NSDictionary * _Nullable JSON))completionHandler {
    NSDictionary *param = @{
        @"locationId": locationId
    };
    [[NYCDNHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"salepagev2/GetBuyExtraItemList/%@", shopId]
                                 parameters:param
                                    success:^(NSURLSessionTask *operation, NSDictionary *response) {
                                        completionHandler(response);
                                    } failure:^(NSURLSessionTask *operation, NSError *error) {
                                        completionHandler(nil);
                                    }];
}

#pragma mark - 2.26.0 購物車門檻加購

- (void)getThresholdBuyExtraItemListByShopId:(nonnull NSNumber *)shopId
                                  locationId:(nonnull NSNumber *)locationId
                           completionHandler:(nonnull void (^)(NSDictionary * _Nullable JSON))completionHandler {
    NSDictionary *param = @{
        @"locationId": locationId
    };
    [[NYCDNHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"salepagev2/GetThresholdBuyExtraItemList/%@", shopId]
                                 parameters:param
                                    success:^(NSURLSessionTask *operation, NSDictionary *response) {
                                        completionHandler(response);
                                    } failure:^(NSURLSessionTask *operation, NSError *error) {
                                        completionHandler(nil);
                                    }];
}

#pragma mark - ApplePay

- (void)sendTradeOrderV2WithPayProcessData:(NSDictionary *)payProcessData
                         completionHandler:(void (^)(NSArray *responseArray, NSString *returnCode, NSString *message, NSError *error))completionHandler {
    
    NYCartHTTPSClient *cartClient = (NYCartHTTPSClient *)[NYCartHTTPSClient sharedClient];
    [[cartClient paymentClient]
     postPath:@"tradesOrderV2/Send"
     parameters:payProcessData
     requestType:NYHTTPRequestTypeFixedFloat
     responseType:NYHTTPResponseTypeJSON
     success:^(NSURLSessionDataTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        // 目前不會用到，節點先開著但不接。理論上是 Array of String
        // NSArray *responseArray = response[kNYAPIDataKey];
        
        // 處理 tracking 用的 cookie
        NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)operation.response;
        NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields: urlResponse.allHeaderFields forURL:[NYBaseURLConfig baseHTTPSURLWithWebAPIDomain]];
        [cookies enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull cookie, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([@"TradesOrderCode" isEqualToString:cookie.name]) {
                [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
            }
        }];
        
        completionHandler(nil, returnCode, message, nil);

    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 2.50.0 店員代加入購物車
- (void)sendToCartWithSendToCartCode:(nonnull NSString *)sendToCartCode
                   completionHandler:(nonnull void (^)(NSString * _Nullable returnCode, NSString * _Nullable message, NSArray * _Nullable data, NSError * _Nullable error))completionHandler {
    NSString *path = [[NSString alloc] initWithFormat:@"ShoppingCartV4/InsertItemForSendToCart/%@",
                      NYApiSupportVersion.cartSupportVersion];
    NSDictionary *params = @{@"sendToCartCode": sendToCartCode};
    [[NYHTTPSClient sharedClient] postPath:path
                                parameters: params
                                   success:^(NSURLSessionTask *operation, NSDictionary *response) {
                                    NSString *returnCode = response[kNYAPIReturnCodeKey];
                                    NSString *message = response[kNYAPIMessage];
                                    NSArray *data = response[kNYAPIDataKey];
                                    completionHandler(returnCode, message, data, nil);
                                    }
                                   failure:^(NSURLSessionTask *operation, NSError *error) {
                                    completionHandler(nil, nil, nil, error);
    }];
}

- (void)getShoppingCartPromotionInfoWithSalePageList:(NSArray * _Nonnull)salePageList
                                      shippingAreaId:(NSNumber *)shippingAreaId
                                   completionHandler:(nonnull void (^)(NSString * _Nullable returnCode,
                                                                       NSString * _Nullable message,
                                                                       NSDictionary * _Nullable data,
                                                                       NSError * _Nullable error))completionHandler {
    NSDictionary *para = @{@"shopId": [NYGlobalData shopId],
                           @"ShippingAreaId": shippingAreaId ?: @0,
                           @"SalePageList": salePageList};
    [[NYCartHTTPSClient sharedClient]
     postPath: @"PromotionEngine/GetShoppingCartPromotionInfo?source=iOSApp"
     parameters: para
     requestType:NYHTTPRequestTypeJSON
     responseType:NYHTTPResponseTypeJSON
     requestTimeout:@1.5 // 2021/1/29: 大家說好先訂個 1.5 秒
     success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *data = response[kNYAPIDataKey];
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

/// 使用參數取得 Gift 的相關資訊
-(void)getFreeGiftListWithPromotionId:(NSNumber * _Nonnull)promotionId
                         isChoosePage:(BOOL)isChoosePage
             isReachPriceWithFreeGift:(BOOL)isReachPriceWithFreeGift
                              tagList:(NSArray<NSString *> * _Nonnull)tagList
                    completionHandler:(nonnull void (^)(NSString * _Nullable returnCode,
                                                        NSString * _Nullable message,
                                                        NSArray * _Nullable data,
                                                        NSError * _Nullable error))completionHandler {
    NSMutableDictionary *params =  @{@"shopId": [NYGlobalData shopId],
                                     @"promotionEngineId": promotionId ?: @0}.mutableCopy;
    
    if (isReachPriceWithFreeGift) {
        [params addEntriesFromDictionary:@{@"promotionTagList": [NSNull null],
                                           @"collectionIdList": tagList}];
    } else {
        [params addEntriesFromDictionary:@{@"promotionTagList": tagList}];
    }
    
    NSString *endPoint = isChoosePage ? @"GetPromotionGiftWithStockList" : @"GetPromotionGiftList";
    NSString *freeGiftPath = [NSString stringWithFormat:@"PromotionEngineFreeGift/%@", endPoint];
    
    [[NYCartHTTPSClient sharedClient]
     postPath: freeGiftPath
     parameters: params
     requestType:NYHTTPRequestTypeJSON
     responseType:NYHTTPResponseTypeJSON
     success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSArray *data = response[kNYAPIDataKey];
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)calculatePromoCodePromotionWithCode:(NSString * _Nonnull)code
                               salePageList:(NSArray * _Nonnull)salePageList
                         payProfileTypeList:(NSArray * _Nonnull)payProfileTypeList
                             shippingAreaId:(NSNumber *)shippingAreaId
                          completionHandler:(nonnull void (^)(NSString * _Nullable returnCode,
                                                              NSString * _Nullable message,
                                                              NSDictionary * _Nullable data,
                                                              NSError * _Nullable error))completionHandler {
    NSDictionary *para = @{@"shopId": [NYGlobalData shopId],
                           @"PromoCode": code,
                           @"SalePageList": salePageList,
                           @"ShippingAreaId": shippingAreaId ?: @0,
                           @"PayProfileTypeList": payProfileTypeList};
    [[NYCartHTTPSClient sharedClient]
     postPath: @"PromotionEngine/CalculatePromoCodePromotion?source=iOSApp"
     parameters: para
     requestType:NYHTTPRequestTypeJSON
     responseType:NYHTTPResponseTypeJSON
     success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *data = response[kNYAPIDataKey];
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getCustomOfflinePaymentInfoWithCompletion:(nonnull void (^)(NSString * _Nullable returnCode,
                                                                    NSString * _Nullable message,
                                                                    NSArray * _Nullable dataArray,
                                                                    NSError * _Nullable error))completion {
    NSDictionary *para = @{@"shopId": [NYGlobalData shopId],
                           @"payProfile": @"CustomOfflinePayment"};
    [[NYHTTPSClient sharedClient]
     getPath:@"PayProfile/PaymentInfo"
     parameters:para
     success:^(NSURLSessionDataTask *operation,
               NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        id responseData = response[kNYAPIDataKey];
        if ([responseData isKindOfClass:[NSArray class]]) {
            completion(returnCode, message, (NSArray *)responseData, nil);
        } else {
            completion(returnCode, message, @[], nil);
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, nil, error);
    }];
}

@end
//
//  NYDataProvider+Theme.m
//  Pods
//
//  Created by Alex Lin on 2016/3/1.
//
//

#import "NYDataProvider+Theme.h"

#import "NYCDNHTTPClient.h"
#import "NYHTTPSClient.h"
#import "NYItemObject.h"

#import <PromiseKit/PromiseKit.h>
#import <RegExCategories/RegExCategories.h>

@implementation NYDataProvider (Theme)

#pragma mark - General
#define THEME_USE_DUMMY true
- (void)getOfficialShopThemeWithShopID:(NSNumber *)shopID
                          templateName:(NSString *)templateName
                     completionHandler:(void (^)(NSString *returnCode, NSDictionary *data, NSString *message, NSError *error))completionHandler {
    //Create client & check dummy
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"Theme/GetOfficialShopTheme";
    
    //Parameter
    NSDictionary *params = @{@"shopId"          : shopID,
                             @"templateName"    : templateName,
                             @"device"          : @"App"};
    
    //GET
    [client getPath:path parameters:params requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[@"ReturnCode"];
        NSString *message = JSON[@"Message"];
        
        //Check null
        NSDictionary *data = JSON[@"Data"];
        if ([data isKindOfClass:[NSNull class]]) {
            data = @{};
        }
        
        //Call back
        completionHandler(returnCode, data, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        //Error
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 首頁部分

- (void)getOfficialRecommendSalePageListWithShopID:(NSNumber *)shopID
                                           orderBy:(NSString *)orderBy
                                        startIndex:(NSNumber *)startIndex
                                          maxCount:(NSNumber *)maxCount
                                           cidList:(NSArray *)cidList
                                 completionHandler:(DataSourceCompletionHandler)completionHandler {
    // Path
    NSString *path = [NSString stringWithFormat:@"SalePage/GetOfficialRecommendSalePageList/%@", shopID];
    
    //Create parameters
    NSMutableDictionary *params = @{@"orderBy"      :orderBy,
                                    @"startIndex"   :startIndex,
                                    @"maxCount"     :maxCount}.mutableCopy;
    
    //Add CID list to paramters
    [cidList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        //Generate key
        NSString *key = [NSString stringWithFormat:@"cidList[%lu]", idx];
        
        //Set value
        [params addEntriesFromDictionary:@{key:obj}];
    }];
    
    //Get request
    [[NYCDNHTTPClient sharedClient] getPath:path parameters:params success:^(NSURLSessionTask *operation, id responseObject) {
        //Success
        NSMutableArray *itemList = [NSMutableArray array];
        
        //Create item objects
        [responseObject[@"Data"] enumerateObjectsUsingBlock:^(NSDictionary *itemJSON, NSUInteger idx, BOOL *stop) {
            NYItemObject *itemObject = [[NYItemObject alloc] initWithJSONDict:itemJSON];
            [itemList addObject:itemObject];
        }];
        
        //Call back
        completionHandler(@{kNYDataKey:itemList}, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        //Error
        completionHandler(nil, error);
    }];
}

//TODO:For 2.10, need remove
- (void)getShopAppHomeLayoutDataWithShopID:(NSNumber *)shopID
                     saleRankingListPeriod:(NYHotSaleRankingPeriod)period
                      saleRankingListCount:(NSNumber *)count
                         completionHandler:(ShopAppHomeLayoutCompletionHandler)completionHandler {
    //Create promise
    AnyPromise *getShopIntroPromise = [self getShopIntroductionPromiseWithShopID:shopID];
    AnyPromise *getOfficialLayoutPromise = [self getShopHomeAllLoayoutTemplateDataAndInfoModuleDataPromiseWithShopID:shopID];
    AnyPromise *getHotSaleRankingListPromise = [self getHotSaleRankingListPromiseWithShopID:shopID period:period maxCount:count];
    AnyPromise *getDiscountEventListPromise = [self getDiscountEventListPromiseWithShopID:shopID];
    
    //Request (concurrence)
    PMKJoin(@[getShopIntroPromise, getOfficialLayoutPromise, getHotSaleRankingListPromise, getDiscountEventListPromise]).then(^(NSArray *fulfilledResults, NSArray *rejectedResults) {
        //Result
        NYShopObject *shopObject                = fulfilledResults[0] != [NSNull null] ? fulfilledResults[0] : nil;
        NSDictionary *bannerAdElementListsDict  = fulfilledResults[1][0] != [NSNull null] ? fulfilledResults[1][0] : nil;
        NSArray *cidList                        = fulfilledResults[1][1] != [NSNull null] ? fulfilledResults[1][1] : nil;
        NSArray *saleRankingList                = fulfilledResults[2] != [NSNull null] ? fulfilledResults[2] : nil;
        NSDictionary *discountEventDict         = fulfilledResults[3] != [NSNull null] ? fulfilledResults[3] : nil;
        
        completionHandler(bannerAdElementListsDict, saleRankingList, cidList, shopObject, discountEventDict);
    });
}

#pragma mark Promise Maker

- (AnyPromise *)getShopIntroductionPromiseWithShopID:(NSNumber *)shopID {
    NSString *path = [NSString stringWithFormat:@"Shop/GetShopintroductionV2/%@", shopID];
    return [[NYCDNHTTPClient sharedClient] getPath:path parameters:nil].then(^(NSDictionary *responseObject) {
        return [[NYShopObject alloc] initWithJSONDict:responseObject];
    }).catch(^(NSError *error) {
        return [NSNull null];
    });
}

// 新腰帶API
- (AnyPromise *)getDiscountEventListPromiseWithShopID:(NSNumber *)shopID {
    NSNumber *supportVersion = @1;
    NSString *path = [NSString stringWithFormat:@"PromotionEngine/GetDiscountEventList/%@/%@", shopID, supportVersion];
    NSDictionary *params = @{@"shopId"       :shopID,
                             @"orderBy"      :@"Newest",
                             @"startIndex"   :@0,
                             @"maxCount"     :@30,
                             @"typeDef"      :@"All",
                             @"source"       :@"iOSApp"};
    return [[NYCDNHTTPClient sharedClient] getPath:path parameters:params].then(^(id responseObject) {
        return responseObject[@"Data"];
    }).catch(^(NSError *error) {
        return [NSNull null];
    });
}

- (AnyPromise *)getShopHomeAllLoayoutTemplateDataAndInfoModuleDataPromiseWithShopID:(NSNumber *)shopID {
    NSString *path = [NSString stringWithFormat:@"LayoutTemplateData/GetShopHomeAllLoayoutTemplateData/%@", shopID];
    typeof(self) __weak weakSelf = self;
    return [[NYCDNHTTPClient sharedClient] getPath:path parameters:nil].then(^(id responseObject){
        NSMutableArray *shopHomeADElementLayoutTemplateData = responseObject;
        NSArray *cidList = [self extractCidListFromTemplateData:responseObject]; //cidList = 最新推薦商品
        
        AnyPromise *templateDataPromise = [AnyPromise promiseWithValue:shopHomeADElementLayoutTemplateData];
        AnyPromise *cidListPromise = [AnyPromise promiseWithValue:cidList];
        AnyPromise *getInfoModuleDataPromise = [weakSelf getInfoModuleDataListPromiseWithShopID:shopID
                                                                                     parameters:[self getInfoModuleParameterListFromTemplateData:responseObject]];
        
        return PMKJoin(@[getInfoModuleDataPromise, templateDataPromise, cidListPromise]);
    }).then(^(NSArray *fulfilledResults, NSArray *rejectedResults) {
        
        //因為"shopHomeAllADElementData"中的infoModule版位只帶id，沒有其他data，所以必須用拿到的id去打getInfoModule要其他資料再塞回"shopHomeAllADElementData"中
        NSArray *infoModuleDetailDataList = fulfilledResults[0] == [NSNull null] ? nil : fulfilledResults[0];   //infoModule詳細資料
        NSMutableArray *shopHomeADElementLayoutTemplateData = fulfilledResults[1];                              //首頁所有廣告版位資料
        
        
        //找出shopHomeAllADElementData中，code = MobileHome_SpBlogOfficial的dictionary的index
        NSInteger indexOfInfoModuleDict = [[shopHomeADElementLayoutTemplateData valueForKeyPath:@"Code"] indexOfObject:@"MobileHome_SpBlogOfficial"];
        
        //shopHomeADElementLayoutTemplateData找不到“MobileHome_SpBlogOfficial”欄位時，不做後續操作。
        //理論上這情況不可能發生，除非API的更動還在QA而已卻用Beta的環境去跑。
        if (indexOfInfoModuleDict != NSNotFound) {
            //防止GetInfoModuleForApp回來的資料為0
            if (infoModuleDetailDataList.count == 0) {
                [shopHomeADElementLayoutTemplateData removeObjectAtIndex:indexOfInfoModuleDict];
            } else {
                // 將infoModule的詳細資料寫回廣告版位的Dictionary
                NSMutableArray *infoModuleTemplateDataList = shopHomeADElementLayoutTemplateData[indexOfInfoModuleDict][@"Data"];
                __block NSMutableArray *completedInfoModuleList = [NSMutableArray array];
                [infoModuleTemplateDataList enumerateObjectsUsingBlock:^(NSMutableDictionary *infoModuleBannerData, NSUInteger idx, BOOL *stop) {
                    //為了防止不同資訊模組廣告版位id一樣，但是type不一樣時廣告版位圖都會放同一張(array順序較前面的那張)之問題
                    //因此過濾id與type
                    NSString *moduleId = [infoModuleBannerData valueForKeyPath:@"TargetInfo.TargetId"];
                    NSString *moduleTargetType = [infoModuleBannerData valueForKeyPath:@"TargetInfo.TargetType"];
                    NSArray *filteredInfoModuleDetailData = [infoModuleDetailDataList filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.ModuleId == %@ AND self.InfoModuleTypeDesc == %@", @(moduleId.integerValue), moduleTargetType]];
                    NSDictionary *mappedDetailData = [filteredInfoModuleDetailData firstObject];
                    
                    
                    if (mappedDetailData) {
                        NSString *moduleTitle = mappedDetailData[@"ModuleTitle"];
                        NSString *mainPicURLString = mappedDetailData[@"MainPicURL"];
                        [infoModuleBannerData setObject:moduleTitle forKey:@"Title"];
                        [infoModuleBannerData[@"PicturePath"] setObject:mainPicURLString forKey:@"FullUrl"];
                        [completedInfoModuleList addObject:infoModuleBannerData];
                    }
                }];
                
                shopHomeADElementLayoutTemplateData[indexOfInfoModuleDict][@"Data"] = completedInfoModuleList;
            }
        }
        
        
        //把infoModule的詳細資料塞回shopHomeAllADElementData後，把shopHomeAllADElementData裡面所有Dictionary轉為NYADElement的物件
        NSMutableDictionary *adElementsDict = @{}.mutableCopy;
        [shopHomeADElementLayoutTemplateData enumerateObjectsUsingBlock:^(NSDictionary *adDic, NSUInteger idx, BOOL *stop) {
            NSString *adCode = [RX(@"MobileHome_") replace:adDic[@"Code"] with:@""];
            NSMutableArray *data = @[].mutableCopy;
            [adDic[@"Data"] enumerateObjectsUsingBlock:^(NSDictionary *dataDic, NSUInteger idx, BOOL *stop) {
                NYADElementObject *elementObject = [[NYADElementObject alloc] initWithADCode:adCode andJSONDictionary:dataDic];
                [data addObject:elementObject];
            }];
            
            adElementsDict[adCode] = data;
        }];
        
        return @[adElementsDict, fulfilledResults[2]];
    }).catch(^(NSError *error) {
        return [NSNull null];
    });
}

- (AnyPromise *)getHotSaleRankingListPromiseWithShopID:(NSNumber *)shopID period:(NYHotSaleRankingPeriod)period maxCount:(NSNumber *)maxCount {
    NSString *path = [NSString stringWithFormat:@"HotSaleRanking/GetHotSaleRankingList/%@", shopID];
    
    NSDictionary *params = @{@"period":(period == NYHotSaleRankingPeriodWeekly) ? @"weekly" : @"daily",
                             @"maxCount":maxCount};
    
    return [[NYCDNHTTPClient sharedClient] getPath:path
                                        parameters:params].then(^(NSDictionary *JSON) {
        NSMutableArray *rankingItems = @[].mutableCopy;
        if ([JSON[@"ReturnCode"] isEqualToString:@"API0001"]) {
            [JSON[@"data"] enumerateObjectsUsingBlock:^(NSDictionary *itemDictionary, NSUInteger idx, BOOL *stop) {
                NYItemObject *itemObject = [[NYItemObject alloc] initWithSaleRankingJSONDict:itemDictionary];
                [rankingItems addObject:itemObject];
            }];
        }
        return rankingItems;
    }).catch(^(NSError *error) {
        return [NSNull null];
    });
}

/*
 *  先取得是否有開啟Theme, 如果有的話再去取得Theme的資料.
 *  GetOfficialShopThemeStatus -> Enable -> GetOfficialShopThemeStatus -> Result @{@"EnableTheme": YES, @"Data": ThemeData}
 *  GetOfficialShopThemeStatus -> Disable(Error) -> Result @{@"EnableTheme": NO}
 */
- (AnyPromise *)themeGetThemeDataPromiseWithShopId:(NSNumber *)shopId {
    //Create client & check dummy
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *getStatusPath = @"Theme/GetOfficialShopThemeStatus";
    NSString *getThemePath = @"Theme/GetOfficialShopTheme";
    
    //Parameters
    NSDictionary *parameters = @{@"ShopId" : shopId};
    
    //Get status
    AnyPromise *getStatusPromise = [client getPath:getStatusPath parameters:parameters].then(^id(NSDictionary *statusData) {
        //Get result
        NSString *isThemeEnableKey = @"EnableTheme";
        NSNumber *resultValue = statusData[isThemeEnableKey];
        BOOL isThemeEnable = [resultValue boolValue];
        
        //如果Theme enable則call GetOfficialShopTheme取得資料
        if (isThemeEnable) {
            //Enable (Get theme data)
            AnyPromise *getThemePromise = [client getPath:getThemePath parameters:parameters].then(^id(NSDictionary *themeData) {
                //Success
                return @{isThemeEnableKey : @(YES),
                         @"Data" : themeData};
            }).catch(^(NSError *error) {
                //如果在Error回傳NSNull, 失敗時不會在rejectedResults.
                return [NSNull null];
            });
            return getThemePromise;
        }
        else {
            //Disable
            return @{isThemeEnableKey : @(NO)};
        }
    }).catch(^(NSError* error) {
        //如果在Error回傳NSNull, 失敗時不會在rejectedResults.
        return [NSNull null];
    });
    
    return getStatusPromise;
}

- (AnyPromise *)getInfoModuleDataListPromiseWithShopID:(NSNumber *)shopID parameters:(NSMutableDictionary *)infoModuleParameters {
    NSString *path = [NSString stringWithFormat:@"Official/GetInfoModuleForApp/%@", shopID];
    return [[NYCDNHTTPClient sharedClient] getPath:path
                                        parameters:infoModuleParameters].then(^(id responseObject) {
        return responseObject;
    }).catch(^(NSError *error) {
        return [NSNull null];
    });
}

#pragma mark Private Helper

- (NSArray *)extractCidListFromTemplateData:(NSMutableArray *)templateData {
    __block NSMutableArray *cidList;
    [templateData.copy enumerateObjectsUsingBlock:^(NSDictionary *node, NSUInteger idx, BOOL *stop) {
        if ([RX(@"SpRcmdCatOfficial") isMatch:node[@"Code"]]) {
            cidList = [node[@"Data"] valueForKeyPath:@"TargetInfo.TargetId"];
            NSLog(@"cidList: %@", cidList);
            [templateData removeObjectAtIndex:idx];
        }
    }];
    //防止找不到對應欄位cidList回傳nil會crash
    return cidList ? cidList : @[];
}

- (NSMutableDictionary *)getInfoModuleParameterListFromTemplateData:(NSArray *)templateData {
    NSMutableDictionary *params = @{}.mutableCopy;
    [templateData.copy enumerateObjectsUsingBlock:^(NSDictionary *node, NSUInteger idx, BOOL *stop) {
        if ([RX(@"SpBlogOfficial") isMatch:node[@"Code"]]) {
            [node[@"Data"] enumerateObjectsUsingBlock:^(NSDictionary *infoModuleNode, NSUInteger idx, BOOL *stop) {
                NSString *keyPrefix = [NSString stringWithFormat:@"infos[%lu].", idx];
                [params addEntriesFromDictionary:@{
                                                   [keyPrefix stringByAppendingString:@"InfoModuleId"]:[infoModuleNode valueForKeyPath:@"TargetInfo.TargetId"],
                                                   [keyPrefix stringByAppendingString:@"InfoModuleType"]:[infoModuleNode valueForKeyPath:@"TargetInfo.TargetType"],
                                                   [keyPrefix stringByAppendingString:@"Order"]:[infoModuleNode valueForKeyPath:@"Order"]}];
            }];
        }
    }];
    return params;
}


@end
//
//  NYFTSHTTPClient.h
//  Pods
//
//  Created by Wen Tseng on 2025/9/26.
//

#import "NYHTTPSClient.h"

@interface NYDesignCloudHTTPClient : NYHTTPSClient

+ (NYDesignCloudHTTPClient *)sharedClient;

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
//  NYFacebookGraphAPIClient.m
//  NineYiShopping
//
//  Created by Daniel Kao on 2015/1/5.
//  Copyright (c) 2015年 91mai. All rights reserved.
//

#import "NYFacebookGraphAPIClient.h"

@implementation NYFacebookGraphAPIClient

+ (NYHTTPSClient *)sharedClient {
    static id _sharedClient = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[NYHTTPSClient alloc] initWithBaseURL:[NSURL URLWithString:@"https://graph.facebook.com/v2.6"]];
    });
    
    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url {
    if (self = [super initWithBaseURL:url]) {
    }
    return self;
}

@end
//
//  NYFTSHTTPClient.h
//  Pods
//
//  Created by Naiyu Wang on 2024/3/26.
//

#import "NYHTTPSClient.h"

@interface NYFTSHTTPClient : NYHTTPSClient

+ (NYFTSHTTPClient *)sharedClient;

@end
//
//  NYGraphQLClient.h
//  AFNetworking
//
//  Created by Nick Lee on 2019/5/8.
//

#import "NYHTTPSClient.h"

@interface NYGraphQLClient : NYHTTPSClient

+ (NYGraphQLClient *)sharedClient;

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
//  NYLoginHelper.m
//  NineYiShopping
//
//  Created by Prince on 13/3/26.
//  Copyright (c) 2013年 Julie Lin. All rights reserved.
//

#import "NYLoginHelper.h"

// FIXME: UI dependency
#import "NYCookieManager.h"
#import "NYFacebookHelper.h"
#import "NYHTTPSClient.h"
#import "NYDataProvider+Login.h"
#import "NYDataProvider+MemberCenter.h"
#import "NYUserDefaultsHelper.h"
#import "NYGlobalData.h"
#import "NYUserDefault.h"
#import "NYCartBadgeHelper.h"
#import "NYFavoriteManager.h"
#import "NYMemberHelper.h"
#import "NYUserDefault.h"
#import "NYKeychainHelper.h"

#import <NYCore/NYCore-Swift.h>
#import <AuthenticationServices/AuthenticationServices.h>

NSString * const kNYLoginType91Mai = @"91mai";
NSString * const kNYLoginTypeFacebook = @"Facebook";
NSString * const kNYLoginTypeLineLogin = @"LineLogin";
NSString * const kNYLoginTypeThirdPartyAuth = @"ThirdpartyAuth";
NSString * const kNYLoginTypeAppleSignIn = @"AppleSignIn";

@implementation NYLoginHelper

+ (instancetype)sharedInstance {
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

static void (^_logoutClearAllSetting)(BOOL);
+ (void)setLogoutClearAllSetting:(void (^)(BOOL))logoutClearAllSetting {
    _logoutClearAllSetting = logoutClearAllSetting;
}

+ (void (^)(BOOL))logoutClearAllSetting {
    if (_logoutClearAllSetting) {
        return _logoutClearAllSetting;
    } else {
        return nil;
    }
}

#pragma mark - Read-Only Properties

- (BOOL)isLogin {
    NSDictionary *cookies = [[NYCookieManager sharedManager] cookiesByCookieName:kCOOKIE_NAME_AUTH];
    BOOL isLogin = cookies.count > 0;
    
    return isLogin;
}

- (void)checkLoginAndMemberStatusWithCompletion:(void(^)(NYMemberLoginState memberLoginState, NSString *message))completion {
    typeof(self) __weak weakSelf = self;
    if ([self isLogin]) {
        // VSTS80198, 93301 前端統一處理方式
        [[NYDataProvider sharedInstance] getIsPhantomMemberWithCompletion:^(NSString *returnCode, NSString *message, BOOL isPhantom, NSError *error) {
            if(!error) {
                if (isPhantom) {
                    // Data 拿得到 true 代表 API 有打成功，和前端邏輯一樣（HTTP response status code == 200 && Data == true），判斷為被註銷會員，把會員登出
                    [weakSelf logoutWithCompletionHandler:^{
                        completion(NYMemberLoginStatePhantomMember, message);
                    }];
                } else {
                    completion(NYMemberLoginStateNormalLogin, message);
                }
            } else {
                // API 打失敗，可能是系統流量爆衝拿不回資料，判斷為系統錯誤，轉導到首頁
                completion(NYMemberLoginStateSystemError, @"common_alert_system_is_busy");
            }
        }];
    }
    else {
        completion(NYMemberLoginStateLogout, @"");
    }
}

#pragma mark - Handle login logic

- (void)cleanAllSettingsWithIsLoginAgain:(BOOL)isLoginAgain {
    [NYLoginHelper logoutClearAllSetting](isLoginAgain);
}

- (void)logoutAndLoginAgainWithCompletionHandler:(void (^)(void))completion {
    [self cleanAllSettingsWithIsLoginAgain:YES];

    if (completion) {
        completion();
    }
}

- (void)logoutWithCompletionHandler:(void (^)(void))completion {
    [self cleanAllSettingsWithIsLoginAgain:NO];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NYLogoutNotification" object:nil];
    if (completion) {
        completion();
    }
}

- (NYUserLoginType)userLoginType {
    NSString *loginType = [NYUserDefault loginType];

    if ([loginType isEqualToString:kNYLoginType91Mai]) {
        return NYUserLoginTypeNineyiMember;
    } else if ([loginType isEqualToString:kNYLoginTypeFacebook]) {
        return NYUserLoginTypeFacebook;
    } else if ([loginType isEqualToString:kNYLoginTypeThirdPartyAuth]) {
        return NYUserLoginTypeThirdPartyAuth;
    } else if ([loginType isEqualToString:kNYLoginTypeAppleSignIn]) {
        return NYUserLoginTypeAppleSignIn;
    } else if ([loginType isEqualToString:kNYLoginTypeLineLogin]) {
        return NYUserLoginTypeLineLogin;
    } else {
        return NYUserLoginTypeUnknown;
    }
}

/// 檢查 Apple 登入 credential state
- (void)verifyAppleSignInCredentialState {
    if (!self.isLogin || [self userLoginType] != NYUserLoginTypeAppleSignIn) {
        return;
    }
    
    NSString *userId = [NYKeychainHelper appleSignInUserId];
    if (!userId || userId.length == 0) {
        return;
    }
    
    ASAuthorizationAppleIDProvider *provider = [[ASAuthorizationAppleIDProvider alloc] init];
    [provider getCredentialStateForUserID:userId completion:^(ASAuthorizationAppleIDProviderCredentialState credentialState, NSError * _Nullable error) {
        switch (credentialState) {
            case ASAuthorizationAppleIDProviderCredentialRevoked:
            case ASAuthorizationAppleIDProviderCredentialNotFound:
                // remove apple user id & email
                [NYKeychainHelper deleteAppleSignInCredential];
                [self logoutWithCompletionHandler:nil];
                break;
            case ASAuthorizationAppleIDProviderCredentialTransferred:
                // 先不處理 app transferred 情境
                break;
            default:
                break;
        }
    }];
}

#pragma mark - Private

- (void)saveUserLoginTypeToUserDefaults:(NSString *)userLoginType {
    [NYUserDefault setLoginType:userLoginType];
}

- (void)handleLoginSuccessWithLoginType:(NYUserLoginType)loginType
                             authCookie:(NSString *)authCookie
                              cellPhone:(NSString *)cellPhone
                            countryCode:(NSString *)countryCode
                              countryID:(NSNumber *)countryID
                      completionHandler:(void (^)(void))completionHandler {
    NSString *uAuth = [[NYCookieManager sharedManager] cookieValueFromLocal:kCOOKIE_NAME_U_AUTH];
    // 2020/9/15 auth 和 uAuth 長度不會一樣，如果出現就把所有 auth 都砍掉當沒登入
    if (uAuth.length != authCookie.length) {
        [[NYCookieManager sharedManager] setCookieValue:authCookie forCookieName:kCOOKIE_NAME_AUTH];
    } else {
        [[NYCookieManager sharedManager] removeCookieWithCookieName:kCOOKIE_NAME_AUTH];
    }
    
    switch (loginType) {
        case NYUserLoginTypeNineyiMember:
            [self saveUserLoginTypeToUserDefaults:kNYLoginType91Mai];
            break;
        case NYUserLoginTypeFacebook:
            [self saveUserLoginTypeToUserDefaults:kNYLoginTypeFacebook];
            [self removeCellPhoneNumberFromUserDefaults];
            break;
        case NYUserLoginTypeThirdPartyAuth:
            [self saveUserLoginTypeToUserDefaults:kNYLoginTypeThirdPartyAuth];
            break;
        case NYUserLoginTypeLineLogin:
            [self saveUserLoginTypeToUserDefaults:kNYLoginTypeLineLogin];
            [self removeCellPhoneNumberFromUserDefaults];
            break;
        case NYUserLoginTypeAppleSignIn:
            [self saveUserLoginTypeToUserDefaults:kNYLoginTypeAppleSignIn];
            [self removeCellPhoneNumberFromUserDefaults];
            break;
        case NYUserLoginTypeUnknown:
            NSAssert(NO, @"User Login Type Unknown");
            break;
        default:
            break;
    }
    
    // loginType 非 NYUserLoginTypeNineyiMember 操作手機號碼綁定後，會帶入手機資訊，需存下來
    [self saveCellPhoneCountryCodeToUserDefaults:countryCode];
    [self saveCellPhoneCountryIDToUserDefaults:countryID];
    [self saveCellPhoneNumberToUserDefaults:cellPhone];
    
    //合併登入前後收藏跟購物車資料
    [self mergeFavoriteListAndShoppingCartWithCompletionHandler:^{
        //更新會員狀態 (取得會員資料有無填寫)
        [[NYMemberHelper shareInstance] updateMemberStatus:nil];
        
        if (completionHandler) {
            completionHandler();
        }
    }];
}

- (void)saveCellPhoneNumberToUserDefaults:(NSString *)cellPhone {
    [NYUserDefault setUserCellPhone:cellPhone];
}

- (void)saveCellPhoneCountryCodeToUserDefaults:(NSString *)countryCode {
    [NYUserDefault setUserCellPhoneCountryCode:countryCode];
}

- (void)saveCellPhoneCountryIDToUserDefaults:(NSNumber *)countryID {
    [NYUserDefault setUserCellPhoneCountryID:countryID];
}

- (void)removeCellPhoneNumberFromUserDefaults {
    [NYUserDefault setUserCellPhone:nil];
}

#pragma mark General

- (NSString *)getFacebookCurrentAccessTokenString {
    return [FBSDKAccessToken currentAccessToken].tokenString ?: @"";
}

- (NSString *)getFacebookCurrentAuthTokenString {
    return [FBSDKAuthenticationToken currentAuthenticationToken].tokenString ?: @"";
}

- (void)getFacebookTokenWithCompletionBlock:(void(^)(NSString *token, NSString *authToken, NSError *error))completionblock {
    //Clean state
    [self cleanAllSettingsWithIsLoginAgain:NO];
    
    [[NYFacebookHelper sharedInstance] facebookLoginWithHandler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if(result.isCancelled || error) {
            //失敗或者取消
            completionblock(nil, nil, error);
        }
        else {
            //成功
            completionblock(result.token.tokenString,
                            result.authenticationToken.tokenString,
                            error);
        }
    }];
}

- (void)mergeFavoriteListAndShoppingCartWithCompletionHandler:(void(^)(void))completionHandler
{
    // 1. 合併收藏商品
    // 2. 合併收藏商店
    // 3. ***合併購物車*** （不要懷疑，就是購物車）
    [[NYDataProvider sharedInstance] mergeFavoriteListAndShoppingCartWithCompletionHandler:^(NSDictionary *data, NSError *error) {
        [[NYCartBadgeHelper sharedInstance] updateCartBadgeNumber];
        [[NYFavoriteManager sharedManager] fetchAndMergeFavoriteListCompletion:^(NSArray *list, NSError *error) {
            if (completionHandler) {
                completionHandler();
            }
        }];
    }];
}

#pragma mark 手機註冊

- (void)getRegisterStatusVia91maiWithShopID:(NSNumber *)shopID
                                  cellPhone:(NSString *)cellPhone
                             reCaptchaToken:(NSString *)reCaptchaToken
                                countryCode:(NSString *)countryCode
                                  countryID:(NSNumber *)countryID
                          completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler __deprecated_msg("改用 NYLoginAPIManager.getCellPhoneRegisterStatus") {
    [[NYDataProvider sharedInstance] getRegisterStatusWithShopID:shopID cellPhone:cellPhone reCaptchaToken:reCaptchaToken countryCode:countryCode countryID:countryID completionHandler:completionHandler];
}

- (void)registerVia91maiWithShopID:(NSNumber *)shopID
                         cellPhone:(NSString *)cellPhone
                    reCaptchaToken:(NSString *)reCaptchaToken
                       countryCode:(NSString *)countryCode
                         countryID:(NSNumber *)countryID
                 completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler __deprecated_msg("改用 NYLoginAPIManager.sendOTPCellPhone") {
    [[NYDataProvider sharedInstance] cellPhoneRegisterWithShopID:shopID
                                                       cellPhone:cellPhone
                                                  reCaptchaToken:reCaptchaToken
                                                     countryCode:countryCode
                                                       countryID:countryID
                                               completionHandler:completionHandler];
}

- (void)sendVerifyCodeWithShopID:(NSNumber *)shopID
                       cellPhone:(NSString *)cellPhone
                  reCaptchaToken:(NSString *)reCaptchaToken
                     countryCode:(NSString *)countryCode
                       countryID:(NSNumber *)countryID
                         smsType:(NSString *)smsType
               completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] sendVerifyCodeWithShopID:shopID
                                                    cellPhone:cellPhone
                                               reCaptchaToken:reCaptchaToken
                                                  countryCode:countryCode
                                                    countryID:countryID
                                                      smsType:smsType
                                            completionHandler:completionHandler];
}

- (void)resendVerifyCodeWithShopID:(NSNumber *)shopID
                         cellPhone:(NSString *)cellPhone
                        memberType:(NSString *)memberType
                        verifyType:(NSString *)verifyType
                    reCaptchaToken:(NSString *)reCaptchaToken
                       countryCode:(NSString *)countryCode
                         countryID:(NSNumber *)countryID
                 completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler __deprecated_msg("改用 NYLoginAPIManager.resendVerifyCode") {
    [[NYDataProvider sharedInstance] resendVerifyCodeWithShopID:shopID
                                                      cellPhone:cellPhone
                                                     memberType:memberType
                                                     verifyType:verifyType
                                                        smsType:@""
                                                 reCaptchaToken:reCaptchaToken
                                                    countryCode:countryCode
                                                      countryID:countryID
                                              completionHandler:completionHandler];
}

- (void)resendVerifyCodeUseVoiceWithShopID:(NSNumber *)shopID
                                 cellPhone:(NSString *)cellPhone
                                memberType:(NSString *)memberType
                                verifyType:(NSString *)verifyType
                          countryPhoneCode:(NSString *)countryPhoneCode
                                 countryID:(NSNumber *)countryID
                         completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler __deprecated_msg("改用 NYLoginAPIManager.resendVerifyCodeUseVoice") {
    [[NYDataProvider sharedInstance] resendVerifyCodeUseVoiceWithShopID:shopID
                                                              cellPhone:cellPhone
                                                             memberType:memberType
                                                             verifyType:verifyType
                                                       countryPhoneCode:countryPhoneCode
                                                              countryID:countryID
                                                      completionHandler:completionHandler];
}

- (void)confirmVerifyCodeVia91maiWithShopID:(NSNumber *)shopID
                                  cellPhone:(NSString *)cellPhone
                                       code:(NSString *)code
                                 verifyType:(NSString *)verifyType
                             reCaptchaToken:(NSString *)reCaptchaToken
                                countryCode:(NSString *)countryCode
                                  countryID:(NSNumber *)countryID
                          completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler __deprecated_msg("改用 NYLoginAPIManager.confirmNineyiVerifyCode") {
    [[NYDataProvider sharedInstance] confirmVerifyCodeWithShopID:shopID
                                                       cellPhone:cellPhone
                                                            code:code
                                                      verifyType:verifyType
                                                  reCaptchaToken:reCaptchaToken
                                                     countryCode:countryCode
                                                       countryID:countryID
                                               completionHandler:completionHandler];
}

- (void)finishRegisterVia91maiWithShopID:(NSNumber *)shopID
                               cellPhone:(NSString *)cellPhone
                                password:(NSString *)password
                                  source:(NSString *)source
                                  device:(NSString *)device
                              appVersion:(NSString *)appVersion
                             countryCode:(NSString *)countryCode
                               countryID:(NSNumber *)countryID
                        enableOptInSplit:(BOOL)enableOptInSplit
                                 isOptIn:(NSNumber *)isOptIn
                             isEnableEDM:(NSNumber *)isEnableEDM
                          isEnableEdmSMS:(NSNumber *)isEnableEdmSMS
                        isAppPushProfile:(NSNumber *)isAppPushProfile
                       completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    //Call API (FinishRegister)
    [[NYDataProvider sharedInstance] finishCellPhoneRegisterWithShopID:shopID
                                                             cellPhone:cellPhone
                                                              password:password
                                                                source:source
                                                                device:device
                                                            appVersion:appVersion
                                                           countryCode:countryCode
                                                             countryID:countryID
                                                      enableOptInSplit:enableOptInSplit
                                                               isOptIn:isOptIn
                                                           isEnableEDM:isEnableEDM
                                                        isEnableEdmSMS:isEnableEdmSMS
                                                      isAppPushProfile:isAppPushProfile
                                                     completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];

        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3081"]) { // Check Register 成功
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeNineyiMember
                                           authCookie:auth
                                            cellPhone:cellPhone
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else  {
            completionHandler(data, nil);
        }
    }];
}

- (void)updateCellPhoneWithCellPhone:(NSString *)cellPhone
                         countryCode:(NSString *)countryCode
                           countryID:(NSNumber *)countryID
                    countryAliasCode:(NSString *)countryAliasCode
                   completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    [[NYDataProvider sharedInstance] updateCellPhoneWithCellPhone:cellPhone
                                                 countryAliasCode:countryAliasCode
                                                completionHandler:^(NSDictionary * _Nullable data, NSString * _Nullable auth, NSError * _Nullable error) {
        
        NSString *returnCode = data[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API0001"]) {
            
            if (auth != nil) {
                [[NYCookieManager sharedManager] setCookieValue:auth forCookieName:kCOOKIE_NAME_AUTH];
                [weakSelf saveCellPhoneNumberToUserDefaults:cellPhone];
                [weakSelf saveCellPhoneCountryCodeToUserDefaults:countryCode];
                [weakSelf saveCellPhoneCountryIDToUserDefaults:countryID];
            }
            completionHandler(data, nil);
            
        } else  {
            completionHandler(nil, [NSError errorWithDomain:@"UpdateCellPhone" code:0 userInfo:@{}]);
        }
    }];
}

#pragma mark 手機登入

- (void)loginVia91maiWithShopID:(NSNumber *)shopID
                      cellPhone:(NSString *)cellPhone
                       password:(NSString *)password
                 reCaptchaToken:(NSString *)reCaptchaToken
                         source:(NSString *)source
                         device:(NSString *)device
                     appVersion:(NSString *)appVersion
                    countryCode:(NSString *)countryCode
                      countryId:(NSNumber *)countryId
              completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    //Call API (Login)
    [DS cellPhoneLoginWithShopID:shopID
                       cellPhone:cellPhone
                        password:password
                  reCaptchaToken:reCaptchaToken
                          source:source
                          device:device
                      appVersion:appVersion
                     countryCode:countryCode
                       countryId:countryId
               completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3091"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeNineyiMember
                                           authCookie:auth
                                            cellPhone:cellPhone
                                          countryCode:countryCode
                                            countryID:countryId
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark 國家清單

- (void)getCountryListWithShopID:(NSNumber *)shopID
               completionHandler:(void(^)(NSArray *list, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] getCountryListWithShopID:shopID CompletionHandler:^(NSDictionary * _Nullable JSON, NSError * _Nullable error) {
        completionHandler(JSON[@"Data"], nil);
    }];
}

#pragma mark Line Login 註冊

- (void)getLineMemberRegisterStatusWithShopId:(NSNumber *)shopId
                                  accessToken:(NSString *)accessToken
                            completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] getLineMemberRegisterStatusWithShopId:shopId accessToken:accessToken completionHandler:completionHandler];
}

- (void)createLineMemberRegisterRequestWithShopId:(NSNumber *)shopId
                                        cellPhone:(NSString *)cellPhone
                                      accessToken:(NSString *)accessToken
                                      countryCode:(NSString *)countryCode
                                        countryId:(NSNumber *)countryId
                                completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] createLineMemberRegisterRequestWithShopId:shopId
                                                                     cellPhone:cellPhone
                                                                   accessToken:accessToken
                                                                   countryCode:countryCode
                                                                     countryId:countryId
                                                             completionHandler:completionHandler];
}

- (void)confirmLineVerifyCodeWithCellPhone:(NSString *)cellPhone
                                      code:(NSString *)code
                               countryCode:(NSString *)countryCode
                                 countryId:(NSNumber *)countryId
                                   isOptIn:(NSNumber *)isOptIn
                         completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    [[NYDataProvider sharedInstance] confirmLineMemberVerifyCodeWithCellPhone:cellPhone
                                                                         code:code
                                                                  countryCode:countryCode
                                                                    countryId:countryId
                                                                      isOptIn:isOptIn
                                                            completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        if (error) {
            completionHandler(nil, error);
        } else {
            NSDictionary *responseDict = data[kDATA_KEY];
            NSString *returnCode = responseDict[@"ReturnCode"];
            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILineMemberConfirmVerifyCodeCodeSuccess]) {
                [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeLineLogin
                                               authCookie:auth
                                                cellPhone:nil
                                              countryCode:countryCode
                                                countryID:countryId
                                        completionHandler:^{
                    completionHandler(data, nil);
                }];
            } else {
                completionHandler(data, nil);
            }
        }
    }];
}

#pragma mark Line Login 登入

- (void)loginViaLineWithToken:(NSString *)token
            completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] loginLineMemberWithAccessToken:token
                                                  completionHandler:^(NSDictionary *dataDict, NSString *auth, NSError *error) {
        if (error) {
            completionHandler(nil, error);
        } else {
            NSDictionary *responseDict = dataDict[kDATA_KEY];
            NSString *returnCode = responseDict[@"ReturnCode"];
            
            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILoginLineMemberSuccessed]) {
                [self handleLoginSuccessWithLoginType:NYUserLoginTypeLineLogin
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:nil
                                            countryID:nil
                                    completionHandler:^{
                    completionHandler(dataDict, nil);
                }];
            } else {
                completionHandler(dataDict, nil);
            }
        }
    }];
}

#pragma mark FB註冊

- (void)getRegisterStatusViaFacebookWithShopID:(NSNumber *)shopID
                                   accessToken:(NSString *)accessToken
                                     authToken:(NSString *)authToken
                             completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] getFBRegisterStatusWithShopID:shopID
                                                       accessToken:accessToken
                                                         authToken:authToken
                                                 completionHandler:completionHandler];
}

- (void)registerViaFacebookWithShopID:(NSNumber *)shopID
                            cellPhone:(NSString *)cellPhone
                          accessToken:(NSString *)accessToken
                            authToken:(NSString *)authToken
                          countryCode:(NSString *)countryCode
                            countryID:(NSNumber *)countryID
                    completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] fbRegisterWithShopID:shopID
                                                cellPhone:cellPhone
                                              accessToken:accessToken
                                                authToken:authToken
                                              countryCode:countryCode
                                                countryID:countryID
                                        completionHandler:completionHandler];
}

- (void)confirmVerifyCodeViaFacebookWithShopID:(NSNumber *)shopID
                                   accessToken:(NSString *)accessToken
                                     authToken:(NSString *)authToken
                                     cellPhone:(NSString *)cellPhone
                                          code:(NSString *)code
                                        source:(NSString *)source
                                        device:(NSString *)device
                                    appVersion:(NSString *)appVersion
                                   countryCode:(NSString *)countryCode
                                     countryID:(NSNumber *)countryID
                              enableOptInSplit:(BOOL)enableOptInSplit
                                       isOptIn:(NSNumber *)isOptIn
                                   isEnableEDM:(NSNumber *)isEnableEDM
                                isEnableEdmSMS:(NSNumber *)isEnableEdmSMS
                              isAppPushProfile:(NSNumber *)isAppPushProfile
                             completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    //Call API (FBConfirmVerifyCode)
    [[NYDataProvider sharedInstance] fbConfirmVerifyCodeWithShopID:shopID
                                                       accessToken:accessToken
                                                         authToken:authToken
                                                         cellPhone:cellPhone
                                                              code:code
                                                            source:source
                                                            device:device
                                                        appVersion:appVersion
                                                       countryCode:countryCode
                                                         countryID:countryID
                                                  enableOptInSplit:enableOptInSplit
                                                           isOptIn:isOptIn
                                                       isEnableEDM:isEnableEDM
                                                    isEnableEdmSMS:isEnableEdmSMS
                                                  isAppPushProfile:isAppPushProfile
                                                 completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3121"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeFacebook
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark FB登入

- (void)loginViaFacebookWithShopID:(NSNumber *)shopID
                             token:(NSString *)token
                         authToken:(NSString *)authToken
                            source:(NSString *)source
                            device:(NSString *)device
                        appVersion:(NSString *)appVersion
                       countryCode:(NSString *)countryCode
                         countryID:(NSNumber *)countryID
                 completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    //Call API (FBLogin)
    [DS fbLoginWithShopID:shopID accessToken:token authToken:authToken source:source device:device appVersion:appVersion completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3141"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeFacebook
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark 忘記密碼

- (void)resetPasswordVia91maiWithShopID:(NSNumber *)shopID
                              cellPhone:(NSString *)cellPhone
                         reCaptchaToken:(NSString *)reCaptchaToken
                            countryCode:(NSString *)countryCode
                              countryID:(NSNumber *)countryID
                      completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] resetPasswordWithShopID:shopID
                                                   cellPhone:cellPhone
                                              reCaptchaToken:reCaptchaToken
                                                 countryCode:countryCode
                                                   countryID:countryID
                                           completionHandler:completionHandler];
}

- (void)finishResetPasswordVia91maiWithShopID:(NSNumber *)shopID
                                    cellPhone:(NSString *)cellPhone
                                     password:(NSString *)password
                                       source:(NSString *)source
                                       device:(NSString *)device
                                   appVersion:(NSString *)appVersion
                                  countryCode:(NSString *)countryCode
                                    countryID:(NSNumber *)countryID
                            completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    //Call API (FinishResetPassword)
    [[NYDataProvider sharedInstance] finishResetPasswordWithShopID:shopID
                                                         cellPhone:cellPhone
                                                          password:password
                                                            source:source
                                                            device:device
                                                        appVersion:appVersion
                                                       countryCode:countryCode
                                                         countryID:countryID
                                                 completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3161"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeNineyiMember
                                           authCookie:auth
                                            cellPhone:cellPhone
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark Apple Sign In Registration Flow
- (void)appleLoginWithAuthCode:(NSString *)authCode
                         email:(NSString *)email
             completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    
    /// API 設計文件 https://docs.google.com/document/d/1UgNCU70YzplOhkheFcljgaoEmx5O209v_J79Lo4JvJU/
    [[NYDataProvider sharedInstance] appleIdLoginOrRegisterWithAuthCode:authCode email:email completionHandler:^(NSDictionary * _Nullable dataDict, NSString * _Nullable auth, NSError * _Nullable error) {
        __weak typeof(self) weakSelf = self;
        
        NSDictionary *responseDict = dataDict[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIAppleSignInSuccess]) {
            [weakSelf socialLoginSuccessWithLoginType:NYUserLoginTypeAppleSignIn
                                           authCookie:auth
                                         responseDict:dataDict
                                    completionHandler:^{
                completionHandler(dataDict, nil);
            }];
        } else {
            completionHandler(dataDict, nil);
        }
    }];
}

#pragma mark 修改密碼
- (void)changePasswordVia91maiWithShopID:(NSNumber *)shopID
                             oldPassword:(NSString *)oldPassword
                             newPassword:(NSString *)newPassword
                       completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] changePasswordWithShopID:shopID oldPassword:oldPassword newPassword:newPassword completionHandler:completionHandler];
}

#pragma mark 商店第三方登入
- (void)getThirdpartyMemberRegisterStatusWithLoginId:(NSString *)loginId
                                            password:(NSString *)password
                                              shopId:(NSNumber *)shopId
                                         countryCode:(NSString *)countryCode
                                           countryID:(NSNumber *)countryID
                                   completionHandler:(void (^)(NSDictionary *data, NSError *error))completionHandler {
    
    [[NYDataProvider sharedInstance] getThirdpartyMemberRegisterStatusWithLoginId:loginId password:password shopId:shopId completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        __weak typeof(self) weakSelf = self;
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];

        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3201"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeThirdPartyAuth
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

- (void)createThirdpartyMemberRegisterRequestWithToken:(NSString *)token
                                             cellPhone:(NSString *)cellPhone
                                                shopId:(NSNumber *)shopId
                                           countryCode:(NSString *)countryCode
                                             countryID:(NSNumber *)countryID
                                     completionHandler:(void (^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] createThirdpartyMemberRegisterRequestWithToken:token
                                                                          cellPhone:cellPhone
                                                                             shopId:shopId
                                                                        countryCode:countryCode
                                                                          countryID:countryID
                                                                  completionHandler:completionHandler];
}

- (void)confirmThirdpartyMemberVerifyCodeWithCellPhone:(NSString *)cellPhone
                                                shopId:(NSNumber *)shopId
                                                  code:(NSString *)code
                                                 token:(NSString *)token
                                                source:(NSString *)source
                                                device:(NSString *)device
                                            appVersion:(NSString *)appVersion
                                           countryCode:(NSString *)countryCode
                                             countryID:(NSNumber *)countryID
                                               isOptIn:(NSNumber *)isOptIn
                                     completionHandler:(void (^)(NSDictionary *, NSError *))completionHandler {
    __weak typeof(self) weakSelf = self;
    [[NYDataProvider sharedInstance] confirmThirdpartyMemberVerifyCodeWithCellPhone:cellPhone
                                                                             shopId:shopId
                                                                               code:code
                                                                              token:token
                                                                             source:source
                                                                             device:device
                                                                         appVersion:appVersion
                                                                        countryCode:countryCode
                                                                          countryID:countryID
                                                                            isOptIn:isOptIn
                                                                  completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3221"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeThirdPartyAuth
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark - OAuth登入

- (void)loginThirdpartyMemberWithAuthSessionToken:(NSString *)authSessionToken
                                           shopId:(NSNumber *)shopId
                                           source:(NSString *)source
                                           device:(NSString *)device
                                       appVersion:(NSString *)appVersion
                                      countryCode:(NSString *)countryCode
                                        countryID:(NSNumber *)countryID
                                completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    [[NYDataProvider sharedInstance] loginThirdpartyMemberWithAuthSessionToken:authSessionToken shopId:shopId source:source device:device appVersion:appVersion completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3251"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeThirdPartyAuth
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark 設定密碼
- (void)bindingCellPhoneSetPasswordWithShopID:(NSNumber *)shopID
                                    cellPhone:(NSString *)cellPhone
                                     password:(NSString *)password
                                       source:(NSString *)source
                                       device:(NSString *)device
                                   appVersion:(NSString *)appVersion
                                  countryCode:(NSString *)countryCode
                                    countryID:(NSNumber *)countryID
                                   verifyType:(NSString *)verifyType
                            completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    [[NYDataProvider sharedInstance] setPasswordWithShopID:shopID
                                                 cellPhone:cellPhone
                                                  password:password
                                                    source:source
                                                    device:device
                                                appVersion:appVersion
                                               countryCode:countryCode
                                                 countryID:countryID
                                                verifyType:verifyType
                                         completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeSuccess]) {
            [weakSelf handleLoginSuccessWithLoginType:[weakSelf userLoginType]
                                           authCookie:auth
                                            cellPhone:cellPhone
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else  {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark Public Helper

/// 非手機登入 update auth cookie/cell phone/country code/country id
- (void)socialLoginSuccessWithLoginType:(NYUserLoginType)loginType
                             authCookie:(NSString *)authCookie
                           responseDict:(NSDictionary *)responseDict
                      completionHandler:(void (^)(void))completionHandler {
    NSDictionary *memberDict = responseDict[kDATA_KEY][@"Data"][@"Member"];
    NSString *cellPhone = memberDict[@"CellPhone"] ?: nil;
    NSString *countryCode = memberDict[@"CountryCode"] ?: nil;
    NSNumber *countryID = memberDict[@"CountryProfileId"] ?: nil;
    
    [self handleLoginSuccessWithLoginType:loginType
                               authCookie:authCookie
                                cellPhone:cellPhone
                              countryCode:countryCode
                                countryID:countryID
                        completionHandler:completionHandler];
}

/// 驗證碼登入成功
- (void)expressLoginFinishWithAuthCookie:(NSString *)authCookie
                               cellPhone:(NSString *)cellPhone
                             countryCode:(NSString *)countryCode
                               countryID:(NSNumber *)countryID
                       completionHandler:(void (^)(void))completionHandler {
    [self handleLoginSuccessWithLoginType:NYUserLoginTypeNineyiMember
                               authCookie:authCookie
                                cellPhone:cellPhone
                              countryCode:countryCode
                                countryID:countryID
                        completionHandler:completionHandler];
}

@end
//
//  NYPHPHTTPClient.h
//  NineYiShopping
//
//  Created by Hanna on 2013/11/15.
//  Copyright (c) 2013年 Julie Lin. All rights reserved.
//

#import "NYHTTPSClient.h"

@interface NYPHPHTTPClient : NYHTTPSClient

+ (NYPHPHTTPClient *)sharedClient;


@end
//
//  NYTrackingClient.h
//  Pods
//
//  Created by Eric Huang on 2018/3/14.
//

#import <NYCore/NineyiAppApi.h>

#import "NYHTTPSClient.h"

@interface NYTrackingClient : NYHTTPSClient

+ (NYTrackingClient *)sharedClient;

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
//  NYDataProvider+ShopMemberPresent.swift
//  NineyiAppApi
//
//  Created by Fendy Wu on 2023/12/7.
//

import Foundation

extension NYDataProvider {
    
    private func httpGetPath(_ path: String,
                             _ params: [String: Any],
                             _ completion: MemberInfoCompletionHandler?) {
        NYHTTPSClient.shared().getPath(path, parameters: params) { operation, responseObject in
            if let jsonData = responseObject as? [String: Any] {
                let returnCode = jsonData[kNYAPIReturnCodeKey] as? String
                let message = jsonData[kNYAPIMessage] as? String
                let data = jsonData[kNYAPIDataKey] as? [String: Any]
                completion?(returnCode, message, data, nil)
            } else {
                completion?(nil, nil, nil, nil)
            }
        } failure: { operation, error in
            completion?(nil, nil, nil, error)
        }
    }
    
    public func getShopMemberPresentValidation(withShopId: NSNumber,
                                               typeDef: String,
                                               validationType: String = "",
                                               completion: MemberInfoCompletionHandler?) {
        
        let path = "ShopMemberPresent/Validation"
        let params = [
            "ShopId": withShopId,
            "TypeDef": typeDef,
            "From": validationType
        ] as [String : Any]
        httpGetPath(path, params, completion)
    }
    
    public func getShopMemberPresentValidationForVipInfo(withShopId: NSNumber,
                                                         typeDef: String,
                                                         completion: MemberInfoCompletionHandler?) {
        
        let path = "ShopMemberPresent/ValidationForVipInfo"
        let params = ["ShopId": withShopId, "TypeDef": typeDef] as [String : Any]
        httpGetPath(path, params, completion)
    }
    
    public func getShopMemberPresentDispatchFirstDownload(withShopId: NSNumber,
                                                          completion: MemberInfoCompletionHandler?) {
        
        let path = "ShopMemberPresent/DispatchFirstDownloadPresent"
        let params = ["shopId": withShopId,
                      "guid": NYKeychainHelper.guid() as Any] as [String : Any]
        httpGetPath(path, params, completion)
    }
    
    public func getShopMemberPresentInfo(withShopId: NSNumber,
                                        typeDef: String,
                                        completion: MemberInfoCompletionHandler?) {
        
        let path = "ShopMemberPresent/Get"
        let params = ["ShopId": withShopId, "TypeDef": typeDef] as [String : Any]
        httpGetPath(path, params, completion)
    }
}
//
//  NYDataProvider+ChatRoomSupplement.swift
//  NineyiAppApi
//
//  Created by Joan Lee on 2025/3/19.
//

import Foundation

public extension NYDataProvider {
    // MARK: 25.4 客服幫手未讀訊息
    func getChatMessageCount(_ completion: @escaping NYAPINormalCompletionHandler) {
        let path = "ChatRoom/GetMessageCount"
        let shopID = NYGlobalData.shopId().stringValue
        let isRead = "false"    // 因為是要取得未讀訊息，Request isRead 請帶 false
        
        let parameters: [AnyHashable: Any] = [
            "shopId": shopID,
            "isRead": isRead
        ]
        
        NYHTTPSClient.shared().getPath(path,
                                       parameters: parameters) { operation, json in
            guard let json = json as? [AnyHashable : Any] else {
                completion(nil, nil, nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            completion(nil, nil, json, nil)
            
        } failure: { operation, error in
            completion(nil, nil, nil, error)
        }
    }
}
//
//  NYDataProvider+CouponSupplement.swift
//  Pods
//
//  Created by Mike Fang on 2025/2/17.
//

import Foundation


public extension NYDataProvider {
    func getAvailableCouponCount(with shopId: NSNumber, couponIdList: [NSNumber], completion: @escaping (_ returnCode: String?, _ message: String?, _ data: [[String: Any]]?, _ error: Error?) -> Void) {
        let langString = NYLocalizationString.selectedLanguageCode.isEmpty ? "zh-TW" : NYLocalizationString.selectedLanguageCode
        let params: [String: Any] = [
            "shopId": shopId,
            "couponIdList": couponIdList,
            "source": "iOSApp",
            "lang": langString
        ]
        let path = "CouponV2/GetAvailableCouponCount"
        
        // 連續打兩隻 API, DB 來不及寫入, availableCount 會是錯的
        // 先睡 之後優化方向: availableCount 讓後端收到 getECouponWithECouponId response
        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            NYHTTPSClient.shared().postPath(path, parameters: params) { operation, json in
                guard let json = json as? [String: Any],
                      let data = json[kNYAPIDataKey] as? [[String: Any]]
                else {
                    completion(nil, nil, nil, NineyiError.apiReturnUnexpectFormat)
                    return
                }
                let returnCode = json[kNYAPIReturnCodeKey] as? String
                let message = json[kNYAPIMessage] as? String
                completion(returnCode, message, data, nil)
            } failure: { operation, error in
                completion(nil, nil, nil, error)
            }
        }
    }
}

// 給 OC 呼叫的中間層, 避免循環引用, swift 還是呼叫 DataProvider 
@objc public class NYCouponOCBridge: NSObject {
    @objc public static func getAvailableCouponCount(
        shopId: NSNumber,
        couponIdList: [NSNumber],
        completion: @escaping (_ returnCode: String?,
                               _ message: String?,
                               _ data: [[String: Any]]?,
                               _ error: Error?) -> Void) {
        NYDataProvider.sharedInstance().getAvailableCouponCount(with: shopId, couponIdList: couponIdList, completion: completion)
    }
}
//
//  NYDataProvider+CPDLSupplement.swift
//  NineyiAppApi
//
//  Created by Joan Lee on 2025/4/21.
//

import Foundation

public enum CPDLError: LocalizedError {
    public enum CPDLAPIError: Error {
        case invalidResponse(Any?)
        case apiError(msg: String?)
        case networkError(Error?)
        case unknown
    }
    
    public enum CPDLProcessError {
        case invalidAppLink(String)
        case invalidRedirectURL(String)
        case decompressionError(String)
    }
    
    case api(CPDLAPIError)
    case process(CPDLProcessError)
    
    public var errorCode: String {
        switch self {
        case .api(let apiError):
            switch apiError {
            case .invalidResponse: return "L:006.03"
            case .apiError(msg: _): return "L:006.05"
            case .networkError(_): return "L:006.06"
            case .unknown: return "L:006.99"
            }
        case .process(let processError):
            switch processError {
            case .invalidAppLink: return "L:006.02"
            case .invalidRedirectURL: return "L:006.01"
            case .decompressionError: return "L:006.04"
            }
        }
    }
    
    /// `localizedDescription` 回傳值
    ///
    /// 實作 LocalizedError 協定的 errorDescription 屬性
    /// 提供詳細的錯誤描述，包含上下文資訊以便除錯
    public var errorDescription: String? {
        switch self {
        case .api(let apiError):
            switch apiError {
            case .invalidResponse(let any):
                return "API 回應非 JSON: \((any != nil) ? String(describing: any) : "")"
            case .apiError(let msg):
                return "API 解析發生未知錯誤: \(msg ?? "")"
            case .networkError(let error):
                return "網路連線錯誤: \(error?.localizedDescription ?? "")"
            case .unknown:
                return "未知錯誤"
            }
        case .process(let processError):
            switch processError {
            case .invalidAppLink(let link):
                return "無效的 AppLink: \(link)"
            case .invalidRedirectURL(let urlString):
                return "無效的 URL: \(urlString)"
            case .decompressionError(let encodedValue):
                return "brotli 解碼失敗: \(encodedValue)"
            }
        }
    }
}

extension NYHTTPSClient {
    static var cpdlDeferredLinkClient: NYHTTPSClient {
        return NYHTTPSClient(baseURL: NYBaseURLConfig.basedHTTPSURLWithCPDLDeferredAPIDomain())
    }
    
    static var cpdlClient: NYHTTPSClient {
        return NYHTTPSClient(baseURL: NYBaseURLConfig.basedHTTPSURLWithCPDLAPIDomain())
    }
}

public extension NYDataProvider {
    
    /// 取得 deferred link
    ///
    /// ## References
    /// [swagger](https://cpdl-deferrer.qa.91dev.tw/swagger#/deferrer/getDeferrerLog)
    ///
    /// - Parameters:
    ///   - osVersion: OS版本
    ///   - pixel: 像素(小數點兩位)
    ///   - size: 尺寸(寬x高)
    ///   - osType: 作業系統類型\
    ///             Available values : Linux, iphone
    ///   - market: 市場\
    ///             Available values : tw, hk, my
    ///   - shopId: 商店ID
    ///   - env: 環境\
    ///          Available values : qa, prod
    ///   - completion: Result<[String : Any], Error>
    func getDeferredLink(osVersion: String,
                         pixel: String,
                         size: String,
                         osType: String,
                         market: String,
                         shopId: String,
                         env: String,
                         completion: @escaping (Swift.Result<[String : Any], Error>) -> Void) {
        let path = "api/v1/deferrer-log"
        let params = [
            "osVersion" : osVersion,
            "pixel" : pixel,
            "size" : size,
            "osType" : osType,
            "market" : market,
            "shopId" : shopId,
            "env" : env
        ] as [String : Any]
        
        NYHTTPSClient.cpdlDeferredLinkClient.getPath(path,
                                                     parameters: params) { _, response in
            if let json = response as? [String : Any] {
                completion(.success(json))
            } else {
                completion(.failure(CPDLError.api(.invalidResponse(response))))
            }
            
        } failure: { _, error in
            completion(.failure(error.toCPDLAPIError()))
        }
    }
    
    /// 取得縮網址
    ///
    /// API 透過 config 自動選用 CPDL 或 FDLC 服務來產生短網址，介面設計遵循 FDLC 規範以維持既有服務的兼容性
    ///
    /// ## References
    /// [swagger](https://cpdl-config.qa.91dev.tw/swagger#/fdlc/postFdlc)
    ///
    /// [FDLC Doc](https://docs.google.com/document/d/1gQ8f7N1zp81xB1a8BrnDV9ozYUo0EkRUa4F6L5R3Zf4/edit?tab=t.0#heading=h.wihac3r5j82e)
    ///
    func getShortURL(targetURL: String,
                     redirectType: Int,
                     socialInfo: [String : Any],
                     analytics: [String : Any],
                     completion: @escaping (Swift.Result<[String : Any], Error>) -> Void) {
        let path = "csls/fdlc"
        let shopID = NYGlobalData.shopId().stringValue
        let market = NYGlobalData.countryCode().lowercased()
        
        let params = ["ShopId" : shopID,
                      "TargetUrl" : targetURL,
                      "TargetUrlList" : [],
                      "FallbackUrl" : targetURL,
                      "RedirectType" : redirectType,
                      "UrlType" : 4,    // 目前皆產短網址，固定帶 4
                      "EnableForcedRedirect" : false,
                      "SocialInfo" : socialInfo,
                      "Analytics" : analytics,
                      "Market" : market,
                      "FeatureType" : "app_i_01"] as [String : Any]
        
        NYHTTPSClient.cpdlClient.postPath(path,
                                         parameters: params) { _, response in
            if let json = response as? [String : Any] {
                completion(.success(json))
            } else {
                completion(.failure(CPDLError.api(.invalidResponse(response))))
            }
            
        } failure: { _, error in
            completion(.failure(error.toCPDLAPIError()))
        }
    }
}

private extension Error? {
    func toCPDLAPIError() -> CPDLError {
        self != nil ? CPDLError.api(.networkError(self)) : CPDLError.api(.unknown)
    }
}
//
//  NYDataProvider+LoginSupplement.swift
//  NineyiAppApi
//
//  Created by Joan Lee on 2024/11/13.
//

import Foundation

// MARK: - Social Login / Register
extension NYDataProvider {
    private func socialLoginOrRegister(with loginMethod: NYLoginHelper.SocialLogin,
                                       content: [AnyHashable : Any],
                                       email: String = "",
                                       successCode: String,
                                       completion: @escaping LoginCompletionHandler) {
        let payload: [AnyHashable : Any] = [
            "MemberType" : loginMethod.memberType,
            loginMethod.memberType : content,
            "ShopId" : NYGlobalData.shopId() ?? "0",
            "Email" : email,
            "Originate" : [
                "Source" : "iOSApp",
                "Device" : "Mobile",
                "AppVersion": NYGlobalData.appVersionString(),
                "UnloginId": self.guid()
            ],
            "Referee" : NYReferrerBindingLinkInjectionHelper.shared.referrerBindingLinkContent()
        ]
        
        // 2024/9/27: AuthV5 尚不支援 Apple 登入，但是 payload 都一樣，所以社群登入自行帶入 API 版本
        let path = String(format: "%@/SocialLoginOrRegister", loginMethod.apiVersion)
        
        NYHTTPSClient.shared().postPath(path,
                                        parameters: payload) { [weak self] operation, json in
            let auth = self?.getAuth(from: operation)
            self?.crashlyticsFailureLog(withAPI: "SocialLoginOrRegister",
                                        operation: operation!,
                                        requestPayload: payload,
                                        responseData: json,
                                        successReturnCode: successCode)
            
            if let json = json {
                completion([kDATA_KEY : json], auth, nil)
            } else {
                completion(nil, nil, NineyiError.unknown)
            }
            
        } failure: { operation, error in
            completion(nil, nil, NineyiError.apiReturnUnexpectFormat)
        }

    }
    
    public func facebookSocialLoginOrRegister(with token: String, authToken: String, completion: @escaping LoginCompletionHandler) {
        // 社群登入支援無手機號碼 API 文件
        // https://docs.google.com/document/d/103dlE9IcnfSV5jgqtxuFFcnj7lwkPVendccxLBXk_ac/edit
        
        let content = ["Token" : token,
                       "AuthToken" : authToken]
        
        self.socialLoginOrRegister(with: .facebook,
                                   content: content,
                                   successCode: "",
                                   completion: completion)
    }
    
    public func lineSocialLoginOrRegister(with token: String, completion: @escaping LoginCompletionHandler) {
        // 社群登入支援無手機號碼 API 文件
        // https://docs.google.com/document/d/103dlE9IcnfSV5jgqtxuFFcnj7lwkPVendccxLBXk_ac/edit
        
        let content: [AnyHashable : Any] = [
            "AccessToken" : token,
            "TargetPageType" : "AppLineLogin",   // 目標頁面類型
            "IsOptIn" : false
        ]
        
        self.socialLoginOrRegister(with: .line,
                                   content: content,
                                   successCode: NYLoginReturnCodes.kNYAPILineLoginOrRegisterSuccess,
                                   completion: completion)
    }
}

// MARK: - 驗證碼登入 / 註冊（Express Member）
/**
 * 驗證碼登入 API 文件
 * https://docs.google.com/document/d/1HN82nVtUSxHG7CfmWFNB_qM26xtmoTTyEMApm_XSPYA/edit?tab=t.puzjmgr51a9v
 */
extension NYDataProvider {
    
    /// 取得會員登入設定（OTP 功能、密碼設定提示功能）
    public func getMemberAuthenticationSetting(withShopID shopID: NSNumber,
                                               completionHandler: @escaping ([String : Any]?, Error?) -> Void) {
        let authSettingParams = [
            "shopId": shopID,
            "source": "iOSApp"
        ] as [String : Any]
        
        NYHTTPSClient.shared().getPath("AuthV5/MemberAuthenticationSetting",
                                      parameters: authSettingParams) { operation, json in
            
            guard let json = json as? [String: Any] else {
                completionHandler(nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            completionHandler(json, nil)
            
        } failure: { operation, error in
            completionHandler(nil, error)
        }
    }
    
    /// 檢查 OTP / 快捷 會員是否已設定密碼
    @objc public func getMemberPasswordSettingResult(withShopID shopID: NSNumber,
                                                     cellPhone: String,
                                                     countryCode: String,
                                                     countryID: NSNumber) async -> Bool {
        let hasPasswordParams = [
            "cellPhone": cellPhone,
            "shopId": shopID,
            "countryCode": countryCode,
            "countryProfileId": countryID
        ] as [String : Any]
        
        return await withCheckedContinuation { continuation in
            NYHTTPSClient.shared().postPath("AuthV5/HasPassword",
                                            parameters: hasPasswordParams) { operation, json in
                
                guard let json = json as? [String: Any],
                      let data = json["Data"] as? [String: Any] else {
                    continuation.resume(returning: false)
                    return
                }
                
                let hasPassword = data["HasPassword"] as? Bool ?? false
                continuation.resume(returning: hasPassword)
                
            } failure: { operation, error in
                continuation.resume(returning: false)
            }
        }
    }
    
    /// 發送驗證碼（驗證碼登入）
    /// 
    /// API3031    發送成功\
    /// API3032    手機格式錯誤\
    /// API3034    已達到簡訊發送次數上限\
    /// API3035    手機號碼為空\
    /// API3039    系統錯誤
    /// 
    /// - Parameters:
    ///   - shopID: 商店 ID
    ///   - cellPhone: 手機號碼
    ///   - countryCode: 國家代碼
    ///   - countryID: 國家 ID
    ///   - reCaptchaToken: reCaptcha token
    ///   - completionHandler: ([String : Any]?, Error?)
    ///   - entry: 快捷會員專區 Express / 驗證碼註冊登入 OTP
    @objc public func createExpressMemberRegister(shopID: NSNumber,
                                                  cellPhone: String,
                                                  countryCode: String,
                                                  countryID: NSNumber,
                                                  reCaptchaToken: String = "",
                                                  entry: String = "OTP",
                                                  completionHandler: @escaping ([String : Any]?, Error?) -> Void) {
        let parameters = [
            "shopId": shopID,
            "source": "iOSApp",
            "cellPhone": cellPhone,
            "countryCode": countryCode,
            "countryProfileId": countryID,
            "reCaptchaToken": reCaptchaToken,
            "entry": entry
        ] as [String : Any]
        
        NYHTTPSClient.shared().postPath("MemberRegister/CreateExpressMemberRegister",
                                        parameters: parameters,
                                        requestType: .JSON,
                                        responseType: .JSON) { operation, json in
            
            guard let json = json as? [String : Any] else {
                completionHandler(nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            completionHandler(json, nil)
            
        } failure: { operation, error in
            completionHandler(nil, error)
        }
    }
    
    /// 發送驗證碼：會員登入（驗證碼登入註冊 且 未設定密碼）/ 會員專區設定密碼
    /// 
    /// API3151    成功建立重設密碼要求\
    /// API3001    會員未開通\
    /// API3035    手機號碼為空\
    /// API3152    會員不存在\
    /// API3154    驗證碼發送次數達上限\
    /// API3155    reCAPTCHA 驗證失敗\
    /// API3159    超過重設密碼次數上限 / 系統錯誤
    /// 
    /// - Parameters:
    ///   - shopID: 商店 ID
    ///   - cellPhone: 手機號碼
    ///   - countryCode: 國家代碼
    ///   - countryID: 國家 ID
    ///   - reCaptchaToken: reCaptcha token
    ///   - entry: 快捷會員專區 Express / 驗證碼註冊登入 OTP
    ///   - verifyType: Register / ResetPassword / Login
    ///   - completionHandler: ([String : Any]?, Error?)
    @objc public func createExpressMemberResetPassword(shopID: NSNumber,
                                                       cellPhone: String,
                                                       countryCode: String,
                                                       countryID: NSNumber,
                                                       verifyType: String,
                                                       reCaptchaToken: String = "",
                                                       entry: String = "OTP",   // Express/OTP
                                                       completionHandler: @escaping ([String : Any]?, Error?) -> Void) {
        let parameters = [
            "shopId": shopID,
            "source": "iOSApp",
            "cellPhone": cellPhone,
            "countryCode": countryCode,
            "countryProfileId": countryID,
            "reCaptchaToken": reCaptchaToken,
            "verifyType": verifyType,
            "entry": entry
        ] as [String : Any]
        
        NYHTTPSClient.shared().postPath("MemberRegister/CreateExpressMemberResetPasswordRequest",
                                        parameters: parameters,
                                        requestType: .JSON,
                                        responseType: .JSON) { operation, json in
            guard let json = json as? [String : Any] else {
                completionHandler(nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            completionHandler(json, nil)
            
        } failure: { operation, error in
            completionHandler(nil, error)
        }
    }
    
    /// 重新發送驗證碼（驗證碼登入）
    ///
    /// API3051     發送成功\
    /// API3052     超過發送限制\
    /// API3053     註冊次數超過上限\
    /// API3059     系統錯誤\
    /// API3155     未給 recaptcha response token 或 recaptcha 驗證失敗\
    ///
    /// - Parameters:
    ///   - shopID: 商店 ID
    ///   - cellPhone: 手機號碼
    ///   - countryCode: 國家代碼
    ///   - countryID: 國家 ID
    ///   - verifyType: Register / ResetPassword / Login
    ///   - smsType: RegisterMember / MemberPassword / LoginMember
    ///   - reCaptchaToken: reCaptcha token
    ///   - entry: 快捷會員專區 Express / 驗證碼註冊登入 OTP
    ///   - completionHandler: ([String : Any]?, Error?)
    @objc public func resendExpressMemberRegister(shopID: NSNumber,
                                                  cellPhone: String,
                                                  countryCode: String,
                                                  countryID: NSNumber,
                                                  verifyType: String,
                                                  smsType: String,
                                                  reCaptchaToken: String = "",
                                                  entry: String = "OTP",
                                                  completionHandler: @escaping ([String : Any]?, Error?) -> Void) {
        let parameters = [
            "shopId": shopID,
            "source": "iOSApp",
            "cellPhone": cellPhone,
            "countryCode": countryCode,
            "countryProfileId": countryID,
            "smsType": smsType,
            "reCaptchaToken": reCaptchaToken,
            "verifyType": verifyType,
            "entry": entry
        ] as [String : Any]
        
        NYHTTPSClient.shared().postPath("MemberRegister/ResendExpressMemberRegister",
                                        parameters: parameters,
                                        requestType: .JSON,
                                        responseType: .JSON) { operation, json in
            
            guard let json = json as? [String : Any] else {
                completionHandler(nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            completionHandler(json, nil)
            
        } failure: { operation, error in
            completionHandler(nil, error)
        }
    }
    
    /// 重新發送語音驗證碼（驗證碼登入）
    ///
    /// API3051     發送成功\
    /// API3052     超過發送限制\
    /// API3053     已註冊會員\
    /// API3059     系統錯誤\
    ///
    /// - Parameters:
    ///   - shopID: 商店 ID
    ///   - cellPhone: 手機號碼
    ///   - countryCode: 國家代碼
    ///   - countryID: 國家 ID
    ///   - verifyType: Register / ResetPassword / Login
    ///   - entry: 快捷會員專區 Express / 驗證碼註冊登入 OTP
    ///   - completionHandler: ([String : Any]?, Error?)
    @objc public func resendExpressVerifyCodeUseVoice(shopID: NSNumber,
                                                      cellPhone: String,
                                                      countryCode: String,
                                                      countryID: NSNumber,
                                                      verifyType: String,
                                                      entry: String = "OTP",
                                                      completionHandler: @escaping ([String : Any]?, Error?) -> Void) {
        let parameters = [
            "shopId": shopID,
            "source": "iOSApp",
            "cellPhone": cellPhone,
            "countryCode": countryCode,
            "countryProfileId": countryID,
            "verifyType": verifyType,
            "entry": entry
        ] as [String : Any]
        
        NYHTTPSClient.shared().postPath("MemberRegister/ResendExpressVerifyCodeUseVoice",
                                        parameters: parameters,
                                        requestType: .JSON,
                                        responseType: .JSON) { operation, json in
            
            guard let json = json as? [String : Any] else {
                completionHandler(nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            completionHandler(json, nil)
            
        } failure: { operation, error in
            completionHandler(nil, error)
        }
    }
    
    /// 驗證 OTP Login 驗證碼
    /// 
    /// API3061    驗證成功\
    /// API3062    驗證碼錯誤\
    /// API3064    驗證碼過期\
    /// API3035    手機號碼為空\
    /// API3155    reCAPTCHA 驗證失敗\
    /// API3069    系統錯誤
    /// 
    /// - Parameters:
    ///   - shopID: 商店 ID
    ///   - cellPhone: 手機號碼
    ///   - countryCode: 國家代碼
    ///   - countryID: 國家 ID
    ///   - reCaptchaToken: reCaptcha token
    ///   - completionHandler: ([String : Any]?, Error?)
    ///   - verifyCode: 驗證碼
    ///   - memberType: 會員類型，Express 相關目前預設都是 Express
    ///   - entry: 快捷會員專區 Express / 驗證碼註冊登入 OTP
    ///   - verifyType: Register / ResetPassword / Login
    @objc public func confirmExpressVerifyCode(shopID: NSNumber,
                                               cellPhone: String,
                                               countryCode: String,
                                               countryID: NSNumber,
                                               verifyCode: String,
                                               verifyType: String,
                                               memberType: String = "Express",
                                               reCaptchaToken: String = "",
                                               entry: String = "OTP",
                                               completionHandler: @escaping ([String : Any]?, Error?) -> Void) {
        let parameters = [
            "cellPhone": cellPhone,
            "shopId": shopID,
            "code": verifyCode,
            "reCaptchaToken": reCaptchaToken,
            "source": "iOSApp",
            "device": "Mobile",
            "countryCode": countryCode,
            "countryProfileId": countryID,
            "memberType": memberType,
            "entry": entry,
            "verifyType": verifyType
        ] as [String : Any]
        
        NYHTTPSClient.shared().postPath("MemberRegister/ConfirmExpressVerifyCode",
                                       parameters: parameters,
                                       requestType: .JSON,
                                       responseType: .JSON) { operation, json in
            guard let json = json as? [String: Any] else {
                completionHandler(nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            completionHandler(json, nil)
            
        } failure: { operation, error in
            completionHandler(nil, error)
        }
    }
    
    public func finishExpressMemberLogin(shopID: NSNumber,
                                         cellPhone: String,
                                         countryCode: String,
                                         countryID: NSNumber,
                                         reCaptchaToken: String,
                                         entry: String = "OTP",   // Express/OTP
                                         enableOptInSplit: Bool,
                                         isOptIn: Bool?,
                                         isEnableEDM: Bool?,
                                         isEnableEdmSMS: Bool?,
                                         isAppPushProfile: Bool?,
                                         completionHandler: @escaping ([String : Any]?, String?, Error?) -> Void) {
        var parameters = [
            "cellPhone": cellPhone,
            "shopId": shopID,
            "source": "iOSApp",
            "device": "Mobile",
            "appVer": NYGlobalData.appVersionString() ?? "",
            "countryCode": countryCode,
            "countryProfileId": countryID,
            "reCaptchaToken": reCaptchaToken,
            "entry": entry
        ] as [String : Any]
        
        if enableOptInSplit {
            if let isEnableEDM, let isEnableEdmSMS, let isAppPushProfile {
                parameters["isEnableEDM"] = isEnableEDM ? "true" : "false";
                parameters["isEnableEdmSMS"] = isEnableEdmSMS ? "true" : "false";
                parameters["isAppPushProfile"] = isAppPushProfile ? "true" : "false";
            }
        } else {
            if let isOptIn {
                parameters["isOptIn"] = isOptIn ? "true" : "false";
            }
        }
        
        NYHTTPSClient.shared().postPath("MemberRegisterFinish/FinishExpressMemberLogin",
                                       parameters: parameters,
                                       requestType: .JSON,
                                       responseType: .JSON) { [weak self] operation, json in
            let auth = self?.getAuth(from: operation)
            
            guard let json = json as? [String: Any] else {
                completionHandler(nil, nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            completionHandler(json, auth, nil)
            
        } failure: { operation, error in
            completionHandler(nil, nil, error)
        }
    }
    
    @objc public func finishExpressMemberResetPassword(shopID: NSNumber,
                                                       cellPhone: String,
                                                       countryCode: String,
                                                       countryID: NSNumber,
                                                       password: String,
                                                       completionHandler: @escaping ([String : Any]?, String?, Error?) -> Void) {
        let parameters = [
            "cellPhone": cellPhone,
            "shopId": shopID,
            "source": "iOSApp",
            "device": "Mobile",
            "appVer": NYGlobalData.appVersionString() ?? "",
            "countryCode": countryCode,
            "countryProfileId": countryID,
            "password": password,
            "unloginId": self.guid() ?? ""
        ] as [String : Any]
        
        NYHTTPSClient.shared().postPath("MemberRegisterFinish/FinishExpressMemberResetPassword",
                                       parameters: parameters,
                                       requestType: .JSON,
                                       responseType: .JSON) { [weak self] operation, json in
            let auth = self?.getAuth(from: operation)
            
            guard let json = json as? [String: Any] else {
                completionHandler(nil, nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            completionHandler(json, auth, nil)
            
        } failure: { operation, error in
            completionHandler(nil, nil, error)
        }
    }
}

// MARK: - Helper
extension NYDataProvider {
    func getAuth(from urlSession: URLSessionDataTask?) -> String {
        guard let urlResponse: HTTPURLResponse = urlSession?.response as? HTTPURLResponse,
              let allHeaderFields = urlResponse.allHeaderFields as? [String : String]
        else { return "" }
        
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaderFields, for: NYBaseURLConfig.baseHTTPSURLWithWebAPIDomain())
        
        let auth = cookies.filter({ $0.name.lowercased() == "auth" }).first?.value ?? ""
        
        return auth
    }
}

//
//  NYDataProvider+MemberSupplement.swift
//  NineyiAppApi
//
//  Created by Joan Lee on 2024/11/13.
//

import Foundation

public typealias NYAPINormalCompletionHandler = (_ returnCode: String?, _ message: String?, _ data: [AnyHashable : Any]?, _ error: Error?) -> Void


// MARK: - 帳號綁定

public extension NYDataProvider {
    
    /// 會員社群帳號綁定狀態
    func accountBindingStatus(_ completion: @escaping NYAPINormalCompletionHandler) {
        let path = "AuthV5/AccountBindingStatus"
        
        NYHTTPSClient.shared().getPath(path, parameters: [:]) { operation, json in
            guard let json = json as? [AnyHashable : Any] else {
                completion(nil, nil, nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            let returnCode = json[kNYAPIReturnCodeKey] as? String
            let message = json[kNYAPIMessage] as? String
            let data = json[kNYAPIDataKey] as? [AnyHashable : Any] ?? [:]
            
            completion(returnCode, message, data ,nil)
            
        } failure: { operation, error in
            completion(nil, nil, nil, error)
        }
    }
    
    /// 會員社群帳號綁定
    ///
    /// Line 綁定要用既有 API: Line/BindingLineMember
    func socialBinding(with memberType: String,
                       content: [String : Any],
                       completion: @escaping NYAPINormalCompletionHandler) {
        let path = "AuthV5/SocialBinding"
        let params: [AnyHashable : Any] = [
            "MemberType" : memberType,
            memberType : content
        ]
        
        NYHTTPSClient.shared().postPath(path,
                                        parameters: params) { operation, json in
            guard let json = json as? [AnyHashable : Any] else {
                completion(nil, nil, nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            let returnCode = json[kNYAPIReturnCodeKey] as? String
            let message = json[kNYAPIMessage] as? String
            let data = json[kNYAPIDataKey] as? [AnyHashable : Any] ?? [:]
            
            completion(returnCode, message, data ,nil)
            
        } failure: { operation, error in
            completion(nil, nil, nil, error)
        }
    }
}

// MARK: - 自訂會員專區

public extension NYDataProvider {
    
    private enum AdCode {
        static let customVipMember = "MobileHome_CustomVipMember"
    }
    
    // MARK: Config
    
    func getVipMemberDisplayLayout(
        shopId: NSNumber,
        completion: @escaping (_ data: [String: Any]?, _ error: Error?) -> Void
    ) {
        let parameters: [String: Any] = [
            "ShopId": shopId
        ]
        let adCode = AdCode.customVipMember
        
        NYCDNHTTPClient.shared().getPath("LayoutTemplateData/GetLayoutTemplateData/\(shopId)/\(adCode)",
                                         parameters: parameters,
                                         success: { _, response in
            if let dict = response as? [String: Any] {
                completion(dict, nil)
            } else {
                completion(nil, NineyiError.unknown)
            }
        }, failure: { _, error in
            completion(nil, error)
        })
    }
    
    // MARK: 客製化會員專區用的 多語系包
    func getLayoutTemplateDataLanguage(
        shopId: NSNumber,
        completion: @escaping (_ data: [String: String]?, _ error: Error?) -> Void
    ) {
        let parameters: [String: Any] = [
            "ShopId": shopId
        ]
        let adCode = AdCode.customVipMember
        
        NYCDNHTTPClient.shared().getPath("LayoutTemplateData/GetLayoutTemplateDataLanguage/\(shopId)/\(adCode)",
                                         parameters: parameters,
                                         success: { _, response in
            if let dict = response as? [String: String] {
                completion(dict, nil)
            } else {
                completion(nil, NineyiError.unknown)
            }
        }, failure: { _, error in
            completion(nil, error)
        })
    }
    
    // MARK: 圖片
    
    func getVipMemberDisplayImages(
        shopId: NSNumber,
        updatedDateTime: String,
        groupList: [String],
        completion: @escaping NYAPINormalCompletionHandler
    ) {
        let parameters: [String: Any] = [
            "ShopId": shopId,
            "Type": "CustomVipMember",
            "UpdatedDateTime": updatedDateTime,
            "GroupList": groupList,
            "IsMultilingual": true // 強制帶 true
        ]
        
        NYHTTPSClient.shared().postPath("CustomVipMemberSetting/GetVipMemberDisplayImages",
                                        parameters: parameters,
                                        success: { _, response in
            if let dict = response as? [String: Any] {
                let returnCode = dict[kNYAPIReturnCodeKey] as? String
                let message = dict[kNYAPIMessage] as? String
                let data = dict[kNYAPIDataKey] as? [String: Any]
                completion(returnCode, message, data, nil)
            } else {
                completion(nil, nil, nil, NineyiError.unknown)
            }
        }, failure: { _, error in
            completion(nil, nil, nil, error)
        })
    }
    
    
    // MARK: 取得會員優惠券數量
    
    func getMemberECouponCount(
        shopId: NSNumber,
        completion: @escaping (_ returnCode: String?, _ message: String?, _ data: NSNumber?, _ error: Error?) -> Void
    ) {
        let parameters: [String: Any] = [
            "ShopId": shopId,
            "typeDef": "All",
            "supportVersion": eCouponSupportVersion,
            "source": "iOSApp"
        ]
        
        NYHTTPSClient.shared().postPath("CouponV2/GetMemberECouponCount",
                                        parameters: parameters,
                                        success: { _, response in
            if let dict = response as? [String: Any] {
                let returnCode = dict[kNYAPIReturnCodeKey] as? String
                let message = dict[kNYAPIMessage] as? String
                let data = dict[kNYAPIDataKey] as? NSNumber
                completion(returnCode, message, data, nil)
            } else {
                completion(nil, nil, nil, NineyiError.unknown)
            }
        }, failure: { _, error in
            completion(nil, nil, nil, error)
        })
    }
    
    // MARK: - HamiPoint 支付帳號綁定
    
    /// 取得會員支付帳號綁定狀態
    ///
    /// 查詢當前登入會員的所有支付帳號綁定狀態，包含 HamiPoint 等外部夥伴帳號
    func getPaymentAccountBindingStatus(_ completion: @escaping NYAPINormalCompletionHandler) {
        let path = "VipMemberBinding/PaymentAccountBindingStatus"
        
        NYHTTPSClient.shared().getPath(path, parameters: [:]) { operation, json in
            guard let json = json as? [String : Any] else {
                completion(nil, nil, nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            let returnCode = json[kNYAPIReturnCodeKey] as? String
            let message = json[kNYAPIMessage] as? String
            let data = json[kNYAPIDataKey] as? [String : Any] ?? [:]
            
            completion(returnCode, message, data, nil)
            
        } failure: { operation, error in
            completion(nil, nil, nil, error)
        }
    }
    
    /// 取得 HamiPoint 綁定服務條款
    ///
    /// 取得 HamiPoint 帳號綁定的服務條款內容
    func getHamiPointBindingPolicy(_ completion: @escaping NYAPINormalCompletionHandler) {
        let path = "VipMemberBinding/GetHamiPointBindingPolicy"
        let params: [String : Any] = [
            "device": "iOS"
        ]
        
        NYHTTPSClient.shared().getPath(path, parameters: params) { operation, json in
            guard let json = json as? [String : Any] else {
                completion(nil, nil, nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            let returnCode = json[kNYAPIReturnCodeKey] as? String
            let message = json[kNYAPIMessage] as? String
            let data = json[kNYAPIDataKey] as? [String : Any] ?? [:]
            
            completion(returnCode, message, data, nil)
            
        } failure: { operation, error in
            completion(nil, nil, nil, error)
        }
    }
    
    /// HamiPoint 綁定前檢核
    ///
    /// 檢核會員是否符合 HamiPoint 綁定條件（手機號碼為 886 台灣手機）
    func validateHamiPointBinding(_ completion: @escaping NYAPINormalCompletionHandler) {
        let path = "VipMemberBinding/ValidBinding"
        let params: [String : Any] = [
            "PartnerType": "HamiPoint"
        ]
        
        NYHTTPSClient.shared().getPath(path, parameters: params) { operation, json in
            guard let json = json as? [String : Any] else {
                completion(nil, nil, nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            let returnCode = json[kNYAPIReturnCodeKey] as? String
            let message = json[kNYAPIMessage] as? String
            let data = json[kNYAPIDataKey] as? [String : Any] ?? [:]
            
            completion(returnCode, message, data, nil)
            
        } failure: { operation, error in
            completion(nil, nil, nil, error)
        }
    }
    
    /// HamiPoint 會員解綁
    ///
    /// 解除當前登入會員與 HamiPoint 帳號的綁定關係
    func unbindHamiPoint(_ completion: @escaping NYAPINormalCompletionHandler) {
        let path = "VipMemberBinding/UnbindHamiPoint"
        let params: [String : Any] = [:]
        
        NYHTTPSClient.shared().postPath(path, parameters: params) { operation, json in
            guard let json = json as? [String : Any] else {
                completion(nil, nil, nil, NineyiError.apiReturnUnexpectFormat)
                return
            }
            
            let returnCode = json[kNYAPIReturnCodeKey] as? String
            let message = json[kNYAPIMessage] as? String
            let data = json[kNYAPIDataKey] as? [String : Any] ?? [:]
            
            completion(returnCode, message, data, nil)
            
        } failure: { operation, error in
            completion(nil, nil, nil, error)
        }
    }
    
    // MARK: - 會員專區 / 自訂會員專區
    
    /// 會員是否已設定密碼 for 會員專區（RedisCache 15 分鐘）
    func getMemberPasswordDisplayResult(withShopID shopID: NSNumber) async throws -> Bool {
        let params = [
            "shopId": shopID
        ] as [String : Any]
        
        return try await withCheckedThrowingContinuation { continuation in
            NYHTTPSClient.shared().getPath("AuthV5/HasPasswordDisplaySetting",
                                            parameters: params) { operation, json in
                
                guard let json = json as? [String: Any],
                      let data = json["Data"] as? [String: Any] else {
                    continuation.resume(throwing: NineyiError.apiReturnUnexpectFormat)
                    return
                }
                
                let hasPassword = data["HasPassword"] as? Bool ?? false
                continuation.resume(returning: hasPassword)
                
            } failure: { operation, error in
                continuation.resume(throwing: NineyiError.apiConnectionError)
            }
        }
    }
}
//
//  NYDataProvider+StoreStock.swift
//  NineyiAppApi
//
//  Created by Joan Lee on 2025/6/12.
//

import Foundation

// MARK: - 門市庫存

public extension NYDataProvider {
    typealias StoreStockToggle = (isEnabled: Bool, isCityHidden: Bool)
    
    /// 取得門市庫存相關設定啟用開關
    /// 
    /// ## Reference
    /// [門市庫存開關 API 規格](https://docs.google.com/document/d/1Wm018Jt-rinKrSOaaRv7QWsDCNeMF3yv6lou0NCrrAQ/edit?tab=t.0)
    ///
    /// - Parameter completion: Result<[String : Any], Error>
    func storeStockToggles(completion: @escaping (Swift.Result<[String : Any], Error>) -> Void) {
        let shopID = NYGlobalData.shopId().stringValue
        let path = "gateway/stock/isAbleToGetStockInStores"
        let params = ["shopId": shopID]
        
        NYHTTPSClient.shared().getPath(path,
                                       parameters: params) { operation, json in
            if let json = json as? [String : Any],
               let data = json["Data"] as? [String : Any] {
                completion(.success(data))
            } else {
                completion(.failure(NineyiError.apiReturnUnexpectFormat))
            }
            
        } failure: { operation, error in
            completion(.failure(NineyiError.apiConnectionError))
        }
    }
    
    /// 取得所有門市庫存
    /// 
    /// ## Reference
    /// [門市庫存 API 規格](https://docs.google.com/document/d/1Wm018Jt-rinKrSOaaRv7QWsDCNeMF3yv6lou0NCrrAQ/edit?tab=t.7fvyb067zctt)
    ///
    /// - Parameters:
    ///   - skuID: SKU 編號
    ///   - startIndex: 第幾筆
    ///   - maxCount: 最大撈取數量
    ///   - completion: Swift.Result<[String : Any], Error>
    func fetchStockInAllStores(skuID: NSNumber,
                               startIndex: Int,
                               maxCount: Int,
                               completion: @escaping (Swift.Result<[String : Any], Error>) -> Void) {
        let shopID = NYGlobalData.shopId().stringValue
        let path = "gateway/stock/getStockInStoresAll"
        let params = ["shopId" : shopID,
                      "skuId" : skuID,
                      "startIndex" : startIndex,
                      "maxCount" : maxCount] as [String : Any]
        
        NYHTTPSClient.shared().getPath(path,
                                       parameters: params) { operation, json in
            if let json = json as? [String : Any] {
                completion(.success(json))
            } else {
                completion(.failure(NineyiError.apiReturnUnexpectFormat))
            }
            
        } failure: { operation, error in
            completion(.failure(NineyiError.apiConnectionError))
        }
    }
    
    
    /// 建立門市庫存預留單
    /// - Parameters:
    ///   - locationId: 門市 id
    ///   - pickupName: 取貨姓名
    ///   - pickupCountryCode: 手機國碼
    ///   - pickupCellphone: 手機號碼
    ///   - salePageId: 商品頁 id
    ///   - saleProductSKUId: SKU 編號
    func createStoreStockReservation(
        locationId: Int,
        pickupName: String,
        pickupCountryCode: String,
        pickupCellphone: String,
        salePageId: Int,
        saleProductSKUId: String,
        completion: @escaping (Swift.Result<[String : Any], Error>) -> Void
    ) {
        let path = "StoreReservation/Create"
        let params = [
            "shopId" : NYGlobalData.shopId().intValue,
            "locationId": locationId,
            "pickupName": pickupName,
            "pickupCountryCode": pickupCountryCode,
            "pickupCellphone": pickupCellphone,
            "salePageId": salePageId,
            "saleProductSKUId": saleProductSKUId,
            "qty": 1
        ] as [String : Any]
        
        NYHTTPSClient.shared().postPath(path, parameters: params) { _, json in
            if let json = json as? [String : Any] {
                completion(.success(json))
            } else {
                completion(.failure(NineyiError.apiReturnUnexpectFormat))
            }
            
        } failure: { _, _ in
            completion(.failure(NineyiError.apiConnectionError))
        }
    }
    
    /// 建立門市庫存預留單（async/await 版本）
    /// - Parameters:
    ///   - locationId: 門市 id
    ///   - pickupName: 取貨姓名
    ///   - pickupCountryCode: 手機國碼
    ///   - pickupCellphone: 手機號碼
    ///   - salePageId: 商品頁 id
    ///   - saleProductSKUId: SKU 編號
    /// - Returns: API 回應資料
    /// - Throws: 網路錯誤或 API 錯誤
    func createStoreStockReservation(
        locationId: Int,
        pickupName: String,
        pickupCountryCode: String,
        pickupCellphone: String,
        salePageId: Int,
        saleProductSKUId: String
    ) async throws -> [String : Any] {
        try await withCheckedThrowingContinuation { continuation in
            createStoreStockReservation(
                locationId: locationId,
                pickupName: pickupName,
                pickupCountryCode: pickupCountryCode,
                pickupCellphone: pickupCellphone,
                salePageId: salePageId,
                saleProductSKUId: saleProductSKUId
            ) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
