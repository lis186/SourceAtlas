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
| 1 | S | dispatch_async | 3 | NYCMSBasedViewController.m:968 |
| 2 | S | dispatch_once | 1 | NYNotificationPresenter.m:125 |
| 3 | S | dispatch_after | 1 | NYCMSBasedViewController.m:1078 |
| 4 | S | dispatch_group | 10 | NYCMSLaunchViewController.m:36 |
| 5 | N | postNotificationName | 5 | NYNotificationPresenter.m:1507 |
| 6 | N | addObserver_selector | 2 | NYCMSBasedViewController.m:167 |
| 7 | N | removeObserver | 1 | NYCMSLaunchViewController.m:202 |
| 8 | N | respondsToSelector | 13 | NYCMSBasedViewController.m:1518 |
| 9 | N | delegate_property | 72 ⚠️ pervasive | DCWKWebViewController.swift:296 |
| 10 | N | defaultCenter | 9 | NYNotificationPresenter.m:1507 |
| 11 | N | performSelector | 8 | NYECouponListHelper.m:318 |
| 12 | N | completionHandler | 15 | NYNotificationPresenter.m:678 |
| 13 | L | viewDidLoad | 9 | DCWKWebViewController.swift:64 |
| 14 | L | viewWillAppear | 8 | DCWKWebViewController.swift:90 |
| 15 | L | viewDidAppear | 6 | DCWKWebViewController.swift:96 |
| 16 | L | viewWillDisappear | 5 | DCWKWebViewController.swift:103 |
| 17 | L | viewDidDisappear | 2 | DCWKWebViewController.swift:109 |
| 18 | L | performSelector_afterDelay | 3 | NYECouponListHelper.m:615 |
| 19 | D | sharedInstance | 33 ⚠️ pervasive | NYNotificationPresenter.m:1043 |
| 20 | D | shared_dot | 18 | NYNotificationPresenter.m:625 |
| 21 | D | protocol_decl | 17 | NYCMSBasedViewController.m:477 |
| 22 | D | category_interface | 4 | NYCMSBasedViewController.m:46 |
| 23 | E | NSError_param | 2 | NYCMSBasedViewController.m:1054 |

共 23 個錨點命中。

對於每個錨定合約，你的 Artifact 1 必須包含至少一個對應的 {Category}-{NNN} 合約。
若你認為某個錨點不構成合約，必須在 Artifact 4 中說明原因。


## Step 0.8 Feature Sketch
以下方法-屬性矩陣顯示模組內部的功能群集，用於識別 M（Mutation）和 L（Lifecycle）合約：
## Feature Sketch（Step 0.8）

| # | 方法 | 行號 | 引用屬性 |
|---|------|------|---------|
| 1 | `+ (void)activeNavigationController:(UIViewController *)activeNavController` | NYNotificationPresenter.m:55 |  |
| 2 | `+ (void)activeNavigationController:(UIViewController *)activeNavController` | NYNotificationPresenter.m:63 |  |
| 3 | `+ (void)activeNavigationController:(UIViewController *)activeNavController` | NYNotificationPresenter.m:73 |  |
| 4 | `+ (void)activeNavigationController:(UIViewController *)activeNavController` | NYNotificationPresenter.m:104 |  |
| 5 | `+ (instancetype)sharedInstance {` | NYNotificationPresenter.m:121 | _once,_once_t,_sharedInstance,_weak |
| 6 | `+ (void)setActiveNavigationController:(UINavigationController *)navController {` | NYNotificationPresenter.m:135 |  |
| 7 | `- (void)trackingNotificationAction:(RoutingObject *)notif {` | NYNotificationPresenter.m:139 | _action_push_press,_notification_push |
| 8 | `- (void)processNotificationAction:(RoutingObject *)notif withCompletionBlock:(Co` | NYNotificationPresenter.m:171 |  |
| 9 | `- (void)navigateToTargetPageWith:(RoutingObject *)notif {` | NYNotificationPresenter.m:574 |  |
| 10 | `- (void)processPushNotificationAction:(RoutingObject *)notif {` | NYNotificationPresenter.m:578 |  |
| 11 | `- (void)processNotificationAction:(RoutingObject *)notif shouldSendTrackingLogs:` | NYNotificationPresenter.m:582 |  |
| 12 | `- (void)processADElementAction:(NYADElementObject *)adElement {` | NYNotificationPresenter.m:589 |  |
| 13 | `- (UIViewController *)redirectToSalePageCategoryWithNotificationObj:(RoutingObje` | NYNotificationPresenter.m:602 |  |
| 14 | `- (UIViewController *)redirectToNotificationCenter {` | NYNotificationPresenter.m:624 | _center_system_message |
| 15 | `- (UIViewController *)redirectToSalePageWithNotificationObj:(RoutingObject *)not` | NYNotificationPresenter.m:630 |  |
| 16 | `- (UIViewController *)redirectToNYGiftDetailWithNotificationObj:(RoutingObject *` | NYNotificationPresenter.m:642 |  |
| 17 | `- (UIViewController *)redirectToCustomerServiceCenter {` | NYNotificationPresenter.m:655 |  |
| 18 | `- (UIViewController *)redirectToQuestionList {` | NYNotificationPresenter.m:659 |  |
| 19 | `- (UIViewController *)redirectToTradeOrderList {` | NYNotificationPresenter.m:663 |  |
| 20 | `- (UIViewController *)redirectToCustomerInquiry {` | NYNotificationPresenter.m:667 |  |
| 21 | `- (UIViewController *)redirectToCustomerServiceEntry {` | NYNotificationPresenter.m:671 |  |
| 22 | `- (void)redirectToExternalBrowserWithURL:(NSURL *)url {` | NYNotificationPresenter.m:675 |  |
| 23 | `- (UIViewController *)redirectToWebViewViaUrlWithNotificationObj:(RoutingObject ` | NYNotificationPresenter.m:681 |  |
| 24 | `- (UIViewController *)redirectToWebViewViaCustomFieldWithNotificationObj:(Routin` | NYNotificationPresenter.m:685 |  |
| 25 | `- (UIViewController *)redirectToSelfDismissWebViewWithNotificationObj:(RoutingOb` | NYNotificationPresenter.m:694 |  |
| 26 | `- (void)redirectViaWrappedURLWithNotificationObj:(RoutingObject *)notif completi` | NYNotificationPresenter.m:700 |  |
| 27 | `- (void)unwrapFullURLWith:(NSURL *)url completion:(Completion)completion {` | NYNotificationPresenter.m:722 |  |
| 28 | `-(void)unwrapTargetURLWith:(NSURL *)url completion:(Completion)completion {` | NYNotificationPresenter.m:734 |  |
| 29 | `- (UIViewController *)redirectToLocationList {` | NYNotificationPresenter.m:743 |  |
| 30 | `- (UIViewController *)redirectToLocationDetailWithNotificationObj:(RoutingObject` | NYNotificationPresenter.m:748 |  |
| 31 | `- (UIViewController *)redirectToCouponList {` | NYNotificationPresenter.m:753 |  |
| 32 | `- (UIViewController *)redirectToMyCouponList {` | NYNotificationPresenter.m:757 |  |
| 33 | `- (UIViewController *)redirectToCouponDetailWithNotificationObj:(RoutingObject *` | NYNotificationPresenter.m:761 |  |
| 34 | `- (UIViewController *)redirectToInfoModuleDetailWithNotificationObj:(RoutingObje` | NYNotificationPresenter.m:766 |  |
| 35 | `- (UIViewController *)redirectToInfoModuleListWithType:(NYInfoModuleType)infoTyp` | NYNotificationPresenter.m:772 |  |
| 36 | `- (UIViewController *)redirectToInfoModuleRecommandList {` | NYNotificationPresenter.m:777 |  |
| 37 | `- (UIViewController *)redirectToSearchViewController {` | NYNotificationPresenter.m:782 |  |
| 38 | `- (UIViewController *)redirectToSearchWithNotificationObj:(RoutingObject *)notif` | NYNotificationPresenter.m:787 |  |
| 39 | `- (UIViewController *)redirectToECouponWithNotificationObj:(RoutingObject *)noti` | NYNotificationPresenter.m:802 |  |
| 40 | `- (UIViewController *)redirectToECouponExplanationWithNotificationObj:(RoutingOb` | NYNotificationPresenter.m:819 |  |
| 41 | `- (UIViewController *)redirectToECouponListWithPageType:(NYCouponListV2DataSourc` | NYNotificationPresenter.m:831 |  |
| 42 | `- (UIViewController *)redirectToMyECouponWithPageType:(NYCouponListV2DataSourceT` | NYNotificationPresenter.m:850 |  |
| 43 | `- (UIViewController *)redirectToHotSaleRankListWithShopId:(NSNumber *)shopId {` | NYNotificationPresenter.m:869 |  |
| 44 | `- (UIViewController *)redirectToHotSaleRankListWithPeriod:(NSString *)period {` | NYNotificationPresenter.m:875 |  |
| 45 | `- (UIViewController *)redirectToActivityDetailWithNotificationObj:(RoutingObject` | NYNotificationPresenter.m:881 |  |
| 46 | `- (UIViewController *)redirectToLocationPointEventDetailWithNotificationObj:(Rou` | NYNotificationPresenter.m:887 |  |
| 47 | `- (UIViewController *)redirectToPromotionList {` | NYNotificationPresenter.m:893 |  |
| 48 | `- (UIViewController *)redirectToPromotionDetailWithNotification:(RoutingObject *` | NYNotificationPresenter.m:898 |  |
| 49 | `- (void)redirectToTabBarMemberDetail {` | NYNotificationPresenter.m:905 |  |
| 50 | `- (void)redirectToVipMemberProfile {` | NYNotificationPresenter.m:910 |  |
| 51 | `- (void)redirectToShoppingCartWithCode: (NSString *)code {` | NYNotificationPresenter.m:944 |  |
| 52 | `- (void)redirectToShoppingCartWithSlaveId: (NSNumber *)salveID {` | NYNotificationPresenter.m:949 |  |
| 53 | `- (void)redirectToShoppingCartV2WithURL: (NSURL *)url {` | NYNotificationPresenter.m:962 |  |
| 54 | `- (void)redirectToPaymentWalletWithQueryItems:(NSArray<NSURLQueryItem *> *) quer` | NYNotificationPresenter.m:982 |  |
| 55 | `- (UIViewController *)redirectToBoCPayConfirmWebViewWithNotificationObj:(Routing` | NYNotificationPresenter.m:987 |  |
| 56 | `- (UIViewController *)redirectToThirdPartyPaymentConfirmWebViewWithNotificationO` | NYNotificationPresenter.m:999 |  |
| 57 | `- (UIViewController *)redirectToThirdPartyPaymentCancelWebViewWithNotificationOb` | NYNotificationPresenter.m:1011 |  |
| 58 | `- (UIViewController *)redirectToLoyaltyPointCenter {` | NYNotificationPresenter.m:1022 |  |
| 59 | `- (UIViewController *)redirectToCMSHiddenPageWithNotificationObj:(RoutingObject ` | NYNotificationPresenter.m:1028 |  |
| 60 | `- (UIViewController *)redirectToCMSCustomPageWithNotificationObj:(RoutingObject ` | NYNotificationPresenter.m:1034 |  |
| 61 | `- (UIViewController *)redirectToCMSFeverSocialWithNotificationObj:(RoutingObject` | NYNotificationPresenter.m:1056 |  |
| 62 | `- (UIViewController *)redirectToMemberPointExchange {` | NYNotificationPresenter.m:1061 |  |
| 63 | `- (UIViewController *)redirectToRegularOrder {` | NYNotificationPresenter.m:1066 |  |
| 64 | `- (UIViewController *)redirectToPromotionEngineDetailWithNotificationObj:(Routin` | NYNotificationPresenter.m:1073 |  |
| 65 | `- (UIViewController *)redirectToJKOPayPaymentConfirmWithNotificationObj:(Routing` | NYNotificationPresenter.m:1081 |  |
| 66 | `- (UIViewController *)redirectToPaymentConfirmWithNotificationObj:(RoutingObject` | NYNotificationPresenter.m:1089 |  |
| 67 | `- (UIViewController *)redirectToPaymentCancelWithNotificationObj:(RoutingObject ` | NYNotificationPresenter.m:1094 |  |
| 68 | `- (UIViewController *)redirectToPXPartialPickupWithNotificationObj:(RoutingObjec` | NYNotificationPresenter.m:1099 |  |
| 69 | `- (UIViewController *)redirectToPXPartialPickupPushWithNotificationObj:(RoutingO` | NYNotificationPresenter.m:1105 |  |
| 70 | `- (UIViewController *)redirectToPrivacyPolicyPage {` | NYNotificationPresenter.m:1115 |  |
| 71 | `- (void)processThirdpartyBasedOAuthWithNotificationObj:(RoutingObject *)notif {` | NYNotificationPresenter.m:1120 |  |
| 72 | `- (void)processSchemeRedirectWithNotificationObj:(RoutingObject *)notif {` | NYNotificationPresenter.m:1176 |  |
| 73 | `- (NSString *)getRedirectUrlFromNotificationObj:(RoutingObject *)notif {` | NYNotificationPresenter.m:1189 | _block |
| 74 | `- (void)processOpenPxPay {` | NYNotificationPresenter.m:1203 |  |
| 75 | `- (void)presentRetailStoreChoosingWithNotificationObj:(RoutingObject *)notif {` | NYNotificationPresenter.m:1216 |  |
| 76 | `- (void)presentDesignCloudAddToCartEventWith:(NYAddToCartRequestObject *)cartObj` | NYNotificationPresenter.m:1252 |  |
| 77 | `- (UIViewController *)redirectToStaffBoardList {` | NYNotificationPresenter.m:1257 |  |
| 78 | `- (UIViewController *)redirectToStaffBoardDetailWithObject:(RoutingObject *)noti` | NYNotificationPresenter.m:1262 |  |
| 79 | `- (UIViewController *)redirectToTagCategoryWithObject:(RoutingObject *)notif {` | NYNotificationPresenter.m:1268 |  |
| 80 | `- (UIViewController *)redirectToNewestCategoryList {` | NYNotificationPresenter.m:1275 |  |
| 81 | `- (UIViewController *)redirectToInvitingFriendsPage {` | NYNotificationPresenter.m:1279 |  |
| 82 | `- (UIViewController *)redirectToEVoucherListWebView {` | NYNotificationPresenter.m:1284 |  |
| 83 | `- (UIViewController *)redirectToInvitationCodeHistoryPage {` | NYNotificationPresenter.m:1290 |  |
| 84 | `- (UIViewController *)redirectToArrivalNoticeList {` | NYNotificationPresenter.m:1295 |  |
| 85 | `- (UIViewController *)redirectToMyFavoriteList {` | NYNotificationPresenter.m:1300 |  |
| 86 | `- (UIViewController *)redirectToRecentlyBrowse {` | NYNotificationPresenter.m:1305 |  |
| 87 | `- (UIViewController *)redirectToBrandListWithNotificationObj:(RoutingObject *)no` | NYNotificationPresenter.m:1310 |  |
| 88 | `- (UIViewController *)redirectToBrandPageWithNotificationObj:(RoutingObject *)no` | NYNotificationPresenter.m:1316 |  |
| 89 | `- (void)showCarrierBarcode {` | NYNotificationPresenter.m:1327 | _displayAlertWithTitle,_phone_barcode,_please_login_or_register |
| 90 | `- (void)showEditCarrierBarcode {` | NYNotificationPresenter.m:1338 | _displayAlertWithTitle,_phone_barcode,_please_login_or_register |
| 91 | `- (void)showMemberBarcode {` | NYNotificationPresenter.m:1349 | _barcode_empty_description,_displayAlertWithTitle,_member_barcode |
| 92 | `- (void)showMemberBarcodeOrCarrierBarcodeAfterLogin {` | NYNotificationPresenter.m:1366 |  |
| 93 | `- (void)showMemberBarcodeOrCarrierBarcode {` | NYNotificationPresenter.m:1377 |  |
| 94 | `- (UIViewController *)openBarcodeScannerWithNotificationObj:(RoutingObject *)not` | NYNotificationPresenter.m:1392 |  |
| 95 | `- (UIViewController *)openMemberShipCardManagePage {` | NYNotificationPresenter.m:1408 |  |
| 96 | `- (void)pushToZendeskWithCompletion:(Completion)completion {` | NYNotificationPresenter.m:1412 |  |
| 97 | `- (void)popDefaultDownloadAlert {` | NYNotificationPresenter.m:1418 |  |
| 98 | `- (void)getDefaultDownloadURLString:(NSString **)downloadURLString andAlertMessa` | NYNotificationPresenter.m:1425 | _identity_px_pay_not_installed |
| 99 | `- (void)popDownloadAlertWithMessage:(NSString *)alertMessage downloadURLString:(` | NYNotificationPresenter.m:1433 | _cancel,_download |
| 100 | `- (void)pushToVC:(UIViewController *)rootVc targetType:(RoutingTargetType)target` | NYNotificationPresenter.m:1455 |  |
| 101 | `- (void)dismissThirdPartyLoginVCIfNeeded {` | NYNotificationPresenter.m:1495 |  |
| 102 | `- (void)presentCustomerLiveChatWebVCWithQuery:(NSString *)queryString {` | NYNotificationPresenter.m:1503 |  |
| 1 | `+ (instancetype)sharedInstance;` | NYNotificationPresenter.h:15 |  |
| 2 | `+ (void)setActiveNavigationController:(UINavigationController *)navController;` | NYNotificationPresenter.h:17 |  |
| 3 | `- (void)processNotificationAction:(RoutingObject *)notif withCompletionBlock:(Co` | NYNotificationPresenter.h:19 |  |
| 4 | `- (void)processPushNotificationAction:(RoutingObject *)notif;` | NYNotificationPresenter.h:20 |  |
| 5 | `- (void)navigateToTargetPageWith:(RoutingObject *)notif;` | NYNotificationPresenter.h:21 |  |
| 6 | `- (void)processADElementAction:(NYADElementObject *)adElement;` | NYNotificationPresenter.h:22 |  |
| 7 | `- (void)presentDesignCloudAddToCartEventWith:(NYAddToCartRequestObject *)cartObj` | NYNotificationPresenter.h:23 |  |

共 109 個方法。


## Step 0.9 Caller Interface
以下是外部模組引用目標模組的片段，用於識別 D（Dependency）和 P（Propagation）合約：
## Caller Interface Extract（Step 0.9）

外部模組引用 NYNotificationPresenter 的片段（±5 行上下文）：

### NYCMSBasedViewController.m (6 references)
```
6-//  Copyright © 2018年 91App. All rights reserved.
7-//
8-
9-#import "NYCMSBasedViewController.h"
10-#import "NYCMSBasedLayoutEngine.h"
11:#import "NYNotificationPresenter.h"
12-#import "NYSalePageViewController.h"
13-#import "NYPromotionEngineDetailVC.h"
14-#import "NYPromotionDetailContainerVC.h"
15-#import "NineyiAppShop-Swift.h"
16-
--
456-
457-    if ((notif.targetType == RoutingTargetTypeCMSFeverSocialEvents || notif.targetType == RoutingTargetTypeCMSGameModule)
458-        && ![NYLoginHelper sharedInstance].isLogin) {
459-        [self presentLoginVCShouldShowUnLoginMask:NO
460-                          WithLoginSuccessCompletion:^{
461:            [[NYNotificationPresenter sharedInstance] navigateToTargetPageWith:notif];
462-        }];
463-    } else {
464:        [[NYNotificationPresenter sharedInstance] navigateToTargetPageWith:notif];
465-    }
466-    return YES;
467-}
468-
469-/// 開啟商品頁一律透過此 function 檢查是否為年齡限制商品
--
1699-     didStoredAreaPressedWith:(id<NYCMSMembershipCardViewModelProtocol>)viewModel {
1700-    // MARK: 開啟錢包/儲值頁
1701-    if (viewModel.storedEnable) {
1702-        // 沒開啟 run time 開關的點擊沒動作
1703-        RoutingObject *wallet = [RoutingObject getRoutingWithWalletRelayTypeStoredValueWithIdType:@"MembershipCard" id:viewModel.defaultCardCode];
1704:        [[NYNotificationPresenter sharedInstance]navigateToTargetPageWith:wallet];
1705-    }
1706-}
1707-
1708-- (void)cmsMembershipCardCell:(NYCMSMembershipCardCell *)cell
1709-      didPointAreaPressedWith:(id<NYCMSMembershipCardViewModelProtocol>)viewModel {
--
1977-            // 到店取貨
1978-//            targetType = RoutingTargetTypeChoosingStorePickup;
1979-            break;
1980-    }
1981-    RoutingObject *notif = [[RoutingObject alloc] initWithTargetType:targetType];
1982:    [[NYNotificationPresenter sharedInstance] navigateToTargetPageWith:notif];
1983-}
1984-
1985-#pragma mark - CMSTopMessageViewDelegate
1986-- (void)didClickTopMessage:(CMSTopMessageView *)view {
1987-    [self handleTouchEventWithUrlString:view.viewModel.linkURL];
--
2022-
2023-#pragma mark - CMSBuyAgainModuleCollectionViewCellDelegate
2024-- (void)didTapProductCardWith:(id<NYProductCardViewModelProtocol>)productVM {
2025-    NSNumber *salePageID = [NSNumber numberWithInteger:productVM.salePageId];
2026-    RoutingObject *notif = [RoutingObject salePageWithSalePageID:salePageID];
2027:    [[NYNotificationPresenter sharedInstance] navigateToTargetPageWith:notif];
2028-    
2029-    // FA
2030-    [self sendBuyAgainModuleSelectContentEventWithProductVM:productVM];
2031-}
2032-
```


## 目標原始碼

//
//  NYNotificationPresenter.m
//  NineyiAppShop
//
//  Created by Sean on 2015/5/25.
//  Copyright (c) 2015年 91App. All rights reserved.
//

#import "NYNotificationPresenter.h"
#import "NineyiAppShop-Swift.h"

#import "NYHomeViewPagerController.h"
#import "NYHotSaleRankListVC.h"
#import "NYCouponDetailVC.h"

#import "NYNotificationViewPagerController.h"

#import "NYSalePageViewController.h"
#import "NYLocationPointEventDetailVC.h"

#import "NYMemberPointExchangeVC.h"

#import <NYCore/NYStatisticHelper.h>
#import <NYCore/NYNotificationHelper.h>
#import <NYCore/NYCore-Swift.h>
#import "NYPromotionListVC.h"
#import "NYPromotionDetailContainerVC.h"
#import "NYMemberLoyaltyPointCenterVC.h"
#import "NYCMSBasedViewController.h"
#import "NYPromotionEngineDetailVC.h"
#import "NYCartFirstVC.h"

#import <NYCore/NYShopCategoryObject.h>
#import <NYCore/NYInfoModuleObject.h>
#import <NYCore/NYLoginHelper.h>
#import <NYCore/NYCookieManager.h>
#import <NYCore/NYGlobalData.h>
#import <NYCore/NYDataProvider.h>
#import <NYCore/NYUserDefault.h>
#import <NYCore/NYAppSettingsHelper.h>
#import <NYCore/NYUrlHelper.h>

#import "NYInfoModuleDetailViewController.h"
#import "NYInfoModuleListViewController.h"
#import <NYCore/NYLocalizationString.h>
#import <NYCore/UIViewController+NYAlertControllerHelper.h>

#import <NYCore/NYThirdPartyLoginWebBrowserVC.h>
#import "NYECouponDetailViewController.h"

#import "NYADLandingHelper.h"

@interface NYNotificationPushHelper : NSObject

+ (void)activeNavigationController:(UIViewController *)activeNavController
                pushViewController:(UIViewController *)viewController
              thenSelectTabAtIndex:(NSInteger)index;
@end

@implementation NYNotificationPushHelper

// 藉由指定 NYTabBarItemType，去找到其對應的 Index 再做轉導
+ (void)activeNavigationController:(UIViewController *)activeNavController
                pushViewController:(UIViewController *)viewController
               thenSelectTabAtType:(NYTabBarItemType)type {
    
    UITabBarController *tabBarController = activeNavController.tabBarController;
    NSInteger itemIndex = [(NYTabBarControllerV2 *)tabBarController getTabBarItemIndexOf:type];
    [self activeNavigationController:activeNavController pushViewController:viewController thenSelectTabAtIndex:itemIndex];
}

// Index 是指 TabBar 上對應的位置
+ (void)activeNavigationController:(UIViewController *)activeNavController
                pushViewController:(UIViewController *)viewController
              thenSelectTabAtIndex:(NSInteger)index {
    // Note: 應KK要求，先在選定的tab推頁之後才切換。所以selectFirstTab要在pushViewController之後執行。
    // TODO: 在navigation controller上增加category
    
    UITabBarController *tabBarController = activeNavController.tabBarController;
    UIViewController *selectedViewController = tabBarController.viewControllers[index];
    UINavigationController *navController;
    
    if ([selectedViewController isKindOfClass:[UINavigationController class]]){
        navController = (UINavigationController *)selectedViewController;
    }
    
    BOOL needPush = (viewController != nil);
    BOOL isCurrentTab = (tabBarController.selectedViewController == selectedViewController);
    BOOL needSelectTab = !isCurrentTab || !needPush;
    
    // 如果是當前 tab, 而且沒有要做推頁，即表示要做退頁
    if (isCurrentTab && !needPush) {
        [navController popToRootViewControllerAnimated:YES];
    } else if (needPush) {
        [navController pushViewController:viewController animated:index == tabBarController.selectedIndex ? YES : NO];
    }
    
    if (needSelectTab) {
        [(NYTabBarControllerV2 *)tabBarController selectTabBarItemAt:index];
    }
}

/// Note: 不切換Tab的導頁方式
+ (void)activeNavigationController:(UIViewController *)activeNavController
                pushViewController:(UIViewController *)viewController {
    // Get navigation controller
    UINavigationController *navi = activeNavController.navigationController;
    if ([activeNavController isKindOfClass:[UINavigationController class]]) {
        navi = (UINavigationController *)activeNavController;
    }
    
    // Push
    [navi pushViewController:viewController animated:YES];
}

@end


@implementation NYNotificationPresenter

+ (instancetype)sharedInstance {
    
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[NYNotificationPresenter alloc] init];
    });
    
    return _sharedInstance;
}

__weak static UINavigationController *globalActiveNavigationController;


+ (void)setActiveNavigationController:(UINavigationController *)navController {
    globalActiveNavigationController = navController;
}

- (void)trackingNotificationAction:(RoutingObject *)notif {
    // 各個參數的意思請參照
    // https://wiki.91app.com/pages/viewpage.action?pageId=54709160
    
    // 避免 nil導致 crash & 有說如果沒值, 就不要傳
    void (^addValue)(NSMutableDictionary *, NSString *, NSObject *) = ^(NSMutableDictionary *inputDic, NSString *key, NSObject *value) {
        if (value) {
            [inputDic setValue:value forKey:key];
        }
    };
    
    //Create parameters
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    addValue(parameters, @"ec", NYLocalizedString(@"ga_notification_push", nil));
    addValue(parameters, @"ea", NYLocalizedString(@"ga_action_push_press", nil));
    addValue(parameters, @"el", notif.title);
    addValue(parameters, @"cbd.sid", notif.nyCallBackData[@"sid"]);
    addValue(parameters, @"cbd.ncid", notif.nyCallBackData[@"ncid"]);
    addValue(parameters, @"cbd.st", notif.nyCallBackData[@"st"]);
    addValue(parameters, @"cbd.sys", notif.nyCallBackData[@"sys"]);
    
    //Send event
    [[NYStatisticHelper sharedHelper] sendEventNotificationOpenedWithMessageTitle:notif.title content:notif.content openType:[NYFAConstant kFAParamPush] landingPage:[notif abbreviationStringOfTargetType] cbd:notif.nyCallBackData];
    // TrackingV2 多送 dl 欄位（cbd 有什麼帶什麼）
    NSString *dlValue = [notif parseTrackingEventDLDataFrom:notif.nyCallBackData];
    if (dlValue) {
        NSString *tsValue = [NSString stringWithFormat:@"?%@", dlValue];
        NSDictionary *tsParams = @{@"dl": tsValue};
        [NYTrackingServiceHelper send91TrackingV2WithParameters:tsParams];
    }
}

- (void)processNotificationAction:(RoutingObject *)notif withCompletionBlock:(Completion)completion {
    UIViewController *rootVc;
    RoutingTargetType targetType = notif.targetType;
    
    //1.15.0推播效率化/業績追蹤
    if (notif.frCode && notif.frCode.length > 0) {
        [[NYCookieManager sharedManager] setCookieValue:notif.frCode 
                                          forCookieName:kCOOKIE_NAME_TRACE_FR
                                         expirationDate:[NSDate dateWithTimeIntervalSinceNow:24*60*60]];
    }
    
    if (notif.source == RoutingSourceRef && ![[NYGlobalData shopId] isEqualToNumber:notif.shopID]) {
        targetType = RoutingTargetTypeWebView;
    }
    
    if (targetType == RoutingTargetTypeShopSalePageCategory) {
        rootVc = [self redirectToSalePageCategoryWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeNotificationCenter) {
        rootVc = [self redirectToNotificationCenter];
        
    } else if (targetType == RoutingTargetTypeSalePageV2) {
        rootVc = [self redirectToSalePageWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeQuestionList) {
        rootVc = [self redirectToQuestionList];

    } else if (targetType == RoutingTargetTypeFAQ) {
        rootVc = [self redirectToCustomerServiceCenter];

    } else if (targetType == RoutingTargetTypeCustomerService) {
        rootVc = [self redirectToCustomerInquiry];
        
    }  else if (targetType == RoutingTargetTypeCustomerServiceEntry) {
        rootVc = [self redirectToCustomerServiceEntry];
        
    } else if (targetType == RoutingTargetTypeTradesOrderList) {
        rootVc = [self redirectToTradeOrderList];
        
    } else if (targetType == RoutingTargetTypeInvoice ||
               targetType == RoutingTargetTypeInvoiceV2 ||
               targetType == RoutingTargetTypeTradesOrderDetail ||
               targetType == RoutingTargetTypeTradesOrderDetailV2 ||
               targetType == RoutingTargetTypeCMSGameModule) {
        rootVc = [self redirectToWebViewViaUrlWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeWebView) {
        if ([notif.url isExternalLink]) {
            // 外開瀏覽器
            [self redirectToExternalBrowserWithURL:notif.url];
            return;
        } else {
            rootVc = [self redirectToWebViewViaUrlWithNotificationObj:notif];
        }
        
    } else if(targetType == RoutingTargetTypeCustomUrl) {
        rootVc = [self redirectToWebViewViaCustomFieldWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeFullURL) {
        // full url 的連結沒有限制格式，先確認是否有 customField1 再處理導頁
        [self redirectViaWrappedURLWithNotificationObj:notif completion:completion];
        
        rootVc = nil;
        
    } else if (targetType == RoutingTargetTypeLocationList) {
        rootVc = [self redirectToLocationList];
        
    } else if (targetType == RoutingTargetTypeStoreDetail) {
        rootVc = [self redirectToLocationDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeCouponList) {
        rootVc = [self redirectToCouponList];
        
    } else if (targetType == RoutingTargetTypeMyCouponList) {
        rootVc = [self redirectToMyCouponList];
        
    } else if (targetType == RoutingTargetTypeCoupon) {
        rootVc = [self redirectToCouponDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeAlbum ||
               targetType == RoutingTargetTypeArticle ||
               targetType == RoutingTargetTypeVideo) {
        rootVc = [self redirectToInfoModuleDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeAlbumList) {
        rootVc = [self redirectToInfoModuleListWithType:NYInfoModuleTypeAlbum];
        
    } else if (targetType == RoutingTargetTypeArticleList) {
        rootVc = [self redirectToInfoModuleListWithType:NYInfoModuleTypeArticle];
        
    } else if (targetType == RoutingTargetTypeVideoList) {
        rootVc = [self redirectToInfoModuleListWithType:NYInfoModuleTypeVideo];
        
    } else if (targetType == RoutingTargetTypeInfoModuleList) {
        rootVc = [self redirectToInfoModuleRecommandList];
        
    } else if (targetType == RoutingTargetTypeSearch) {
        rootVc = [self redirectToSearchViewController];
        
    } else if (targetType == RoutingTargetTypeSearchResult) {
        rootVc = [self redirectToSearchWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeECoupon) {
        rootVc = [self redirectToECouponWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeECouponList) {
        rootVc = [self redirectToECouponListWithPageType:NYCouponListV2DataSourceTypeEcoupon];
        
    } else if (targetType == RoutingTargetTypeMemberECouponList) {
        rootVc = [self redirectToMyECouponWithPageType:NYCouponListV2DataSourceTypeEcoupon];
        
    } else if (targetType == RoutingTargetTypeGiftECouponExplanation) {
        rootVc = [self redirectToECouponExplanationWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeGiftECouponList) {
        rootVc = [self redirectToECouponListWithPageType:NYCouponListV2DataSourceTypeGiftEcoupon];
        
    } else if (targetType == RoutingTargetTypeMemberGiftECouponList) {
        rootVc = [self redirectToMyECouponWithPageType:NYCouponListV2DataSourceTypeGiftEcoupon];

    } else if (targetType == RoutingTargetTypeGiftDetail) {
        rootVc = [self redirectToNYGiftDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeFreeShippingECoupon) {
        rootVc = [self redirectToECouponWithNotificationObj:notif];

    } else if (targetType == RoutingTargetTypeFreeShippingECouponList) {
        rootVc = [self redirectToECouponListWithPageType:NYCouponListV2DataSourceTypeFreeShippingECoupon];

    } else if (targetType == RoutingTargetTypeMemberFreeShippingECouponList) {
        rootVc = [self redirectToMyECouponWithPageType:NYCouponListV2DataSourceTypeFreeShippingECoupon];

    } else if (targetType == RoutingTargetTypeHotSaleRankList) {
        rootVc = [self redirectToHotSaleRankListWithShopId:notif.shopID];
        
    } else if (targetType == RoutingTargetTypeHotSaleRankDaily) {
        rootVc = [self redirectToHotSaleRankListWithPeriod:@"daily"];
        
    } else if (targetType == RoutingTargetTypeHotSaleRankWeekly) {
        rootVc = [self redirectToHotSaleRankListWithPeriod:@"weekly"];
        
    } else if (targetType == RoutingTargetTypeActivityDetail) {
        rootVc = [self redirectToActivityDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeLocationPointDetail) {
        rootVc = [self redirectToLocationPointEventDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypePromotionListV2) {
        rootVc = [self redirectToPromotionList];
        
    } else if (targetType == RoutingTargetTypePromotionDetail) {
        rootVc = [self redirectToPromotionDetailWithNotification:notif];
        
    } else if (targetType == RoutingTargetTypeMemberZone) {
        [self redirectToTabBarMemberDetail];
        
    } else if (targetType == RoutingTargetTypeVipMemberProfile) {
        [self redirectToVipMemberProfile];
        
    } else if (targetType == RoutingTargetTypeShoppingCart) {
        [self redirectToShoppingCartWithCode:notif.sendToCartCode];
        
    } else if (targetType == RoutingTargetTypeShoppingCartWithSlaveID) {
        [self redirectToShoppingCartWithSlaveId:notif.targetID];
        
    } else if (targetType == RoutingTargetTypeSCV2) {
        [self redirectToShoppingCartV2WithURL:notif.url];
    } else if (targetType == RoutingTargetTypeBocPayConfirm) {
        // BoC Pay 需要藉由認 host 的方式 parse path 出來轉導
        rootVc = [self redirectToBoCPayConfirmWebViewWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeLinePayConfirm ||
               targetType == RoutingTargetTypePXPayConfirm ||
               targetType == RoutingTargetTypeIcashPayConfirm ||
               targetType == RoutingTargetTypeUnionPayConfirm ||
               targetType == RoutingTargetTypeThirdPartyPayConfirm) {
        // LinePay, PXPay, icash Pay, 第三方支付（EasyWallet, POYA Pay, Wechat Pay HK) 付款結果處理方式相同
        // UnionPay 獨立一個 TargetType 同時為了滿足購物車完成瀏覽器內的結帳流程
        rootVc = [self redirectToThirdPartyPaymentConfirmWebViewWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeLinePayCancel ||
               targetType == RoutingTargetTypePXPayCancel) {
        // LinePay & PXPay 付款結果處理方式相同
        rootVc = [self redirectToThirdPartyPaymentCancelWebViewWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeLoyaltyPoint) {
        rootVc = [self redirectToLoyaltyPointCenter];
        
    } else if (targetType == RoutingTargetTypeCMSHiddenPage) {
        rootVc = [self redirectToCMSHiddenPageWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeCMSCustomPage) {
        rootVc = [self redirectToCMSCustomPageWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeCMSFeverSocialEvents) {
        rootVc = [self redirectToCMSFeverSocialWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeExchangeECouponList) {
        rootVc = [self redirectToMemberPointExchange];
        
    } else if (targetType == RoutingTargetTypeRegularOrder) {
        rootVc = [self redirectToRegularOrder];
        
    } else if (targetType == RoutingTargetTypePromotionEngine) {
        rootVc = [self redirectToPromotionEngineDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeJKOPayPaymentConfirm) {
        rootVc = [self redirectToJKOPayPaymentConfirmWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypePaymentChannelReturn ||
               targetType == RoutingTargetTypeAlipayHKConfirm) {
        // PayMe 付款結果、 AlipayHK 付款成功處理方式相同
        rootVc = [self redirectToPaymentConfirmWithNotificationObj:notif];

    } else if (targetType == RoutingTargetTypeAlipayHKCancel) {
        rootVc = [self redirectToPaymentCancelWithNotificationObj:notif];

    } else if (targetType == RoutingTargetTypePXPartialPickup) {
        rootVc = [self redirectToPXPartialPickupWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypePXPartialPickupPush) {
        rootVc = [self redirectToPXPartialPickupPushWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeThirdpartyBasedOAuthSuccess) {
        [self processThirdpartyBasedOAuthWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeCloseWebviewThenPush) {
        rootVc = [self redirectToSelfDismissWebViewWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeOpenPXPay) {
        [self processOpenPxPay];
        
    } else if (targetType == RoutingTargetTypePrivacyPolicy) {
        rootVc = [self redirectToPrivacyPolicyPage];
        
    } else if (targetType == RoutingTargetTypeChoosingStoreDelivery ||
               targetType == RoutingTargetTypeChoosingStorePickup) {
        [self presentRetailStoreChoosingWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeStaffBoardList) {
        rootVc = [self redirectToStaffBoardList];
        
    } else if (targetType == RoutingTargetTypeStaffBoardDetail) {
        rootVc = [self redirectToStaffBoardDetailWithObject:notif];
    
    } else if (targetType == RoutingTargetTypeTagCategory) {
        rootVc = [self redirectToTagCategoryWithObject:notif];
        
    } else if (targetType == RoutingTargetTypeNewestCategory) {
        rootVc = [self redirectToNewestCategoryList];
    
    } else if (targetType == RoutingTargetTypeInvitingFriends) {
        rootVc = [self redirectToInvitingFriendsPage];
        
    } else if (targetType == RoutingTargetTypeEVoucherList) {
        rootVc = [self redirectToEVoucherListWebView];
        
    } else if (targetType == RoutingTargetTypeSubscriptionOrder) {
        rootVc = [self redirectToRegularOrder];
        
    } else if (targetType == RoutingTargetTypeInvitationCodeHistory) {
        rootVc = [self redirectToInvitationCodeHistoryPage];
        
    } else if (targetType == RoutingTargetTypeBackInStockAlert) {
        rootVc = [self redirectToArrivalNoticeList];
        
    } else if (targetType == RoutingTargetTypeMyFavorite) {
        rootVc = [self redirectToMyFavoriteList];
        
    } else if (targetType == RoutingTargetTypeRecentlyBrowse) {
        rootVc = [self redirectToRecentlyBrowse];
        
    } else if (targetType == RoutingTargetTypeCarrierBarcode) {
        [self showCarrierBarcode];
        
    } else if (targetType == RoutingTargetTypeEditCarrierBarcode) {
        [self showEditCarrierBarcode];
        
    } else if (targetType == RoutingTargetTypeMemberBarcode) {
        [self showMemberBarcode];

    } else if (targetType == RoutingTargetTypeMemberBarcodeOrCarrierBarcode) {
        [self showMemberBarcodeOrCarrierBarcodeAfterLogin];

    } else if (targetType == RoutingTargetTypeBrandPage) {
        // 品牌頁
        rootVc = [self redirectToBrandPageWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeBrandList) {
        // 品牌總覽
        rootVc = [self redirectToBrandListWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeBarcodeScanner) {
        // barcode 掃描器
        rootVc = [self openBarcodeScannerWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeMemberShipCardManagePage) {
        // 會員多卡管理頁
        rootVc = [self openMemberShipCardManagePage];
        
    } else if (targetType == RoutingTargetTypeOuterTradesHistory) {
        // 交易紀錄頁（webView）
        rootVc = [NYWKWebViewController outerTradesHistoryWebVC];
        
    } else if (targetType == RoutingTargetTypeOuterTradesWalletHistoryAll) {
        // 交易紀錄頁 - 錢包交易紀錄 (WebView)
        rootVc = [NYWKWebViewController outerTradesWalletHistoryAllWebVC];
        
    } else if (targetType == RoutingTargetTypePayments91APPWallet) {
        NSString *queryString = [NSString stringWithFormat:@"?%@", notif.url.query];
        if ([notif.url.scheme isEqualToString:@"wallet-sdk"]) {
            // url scheme pattern 有差異，需把 query 內容差異補齊
            queryString = [NSString stringWithFormat:@"%@&target=%@", queryString, notif.url.host];
        }

        NSURLComponents *components = [NSURLComponents componentsWithString:queryString];
        [self redirectToPaymentWalletWithQueryItems:components.queryItems];
    } else if (targetType == RoutingTargetTypeOmnichatWebVC ||
               targetType == RoutingTargetTypeNine1Chat) {
        // 客服聊聊
        [self presentCustomerLiveChatWebVCWithQuery:notif.customField1];

    } else if (targetType == RoutingTargetTypeZendesk) {
        // zendesk
        [self pushToZendeskWithCompletion:completion];

    } else if (targetType == RoutingTargetTypeEstamp) {
        // 印花 webView
        rootVc = [NYWKWebViewController estampListWebVCWithQueryValue:notif.customField1];
        
    } else if (targetType == RoutingTargetTypeUnclaimedCoupons) {
        // 新版優惠券未領取頁
        rootVc = [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeUnclaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeEcoupon newCouponType:NYNewCouponMappingTypeAll newCouponCustomId:@"" autoClaimECouponID:nil];
        
    } else if (targetType == RoutingTargetTypeClaimedCoupons) {
        // 新版優惠券已領取頁
        rootVc = [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeClaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeEcoupon newCouponType:NYNewCouponMappingTypeAll newCouponCustomId:@"" autoClaimECouponID:nil];

    } else if (targetType == RoutingTargetTypeAutoClaimCoupon) {
        // 新版優惠券已領取頁，自動領券
        rootVc = [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeClaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeEcoupon newCouponType:NYNewCouponMappingTypeAll newCouponCustomId:@"" autoClaimECouponID:notif.targetIDString];

    } else if (targetType == RoutingTargetTypeUnclaimedCustomCoupons) {
        // 新版優惠券未領取頁自訂券
        NSString *customId = @"";
        if (notif.customField1) {
            customId = notif.customField1;
        }
        rootVc = [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeUnclaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeEcoupon newCouponType:NYNewCouponMappingTypeCustom newCouponCustomId:customId autoClaimECouponID:nil];

    } else if (targetType == RoutingTargetTypeClaimedCustomCoupons) {
        // 新版優惠券已領取頁自訂券
        NSString *customId = @"";
        if (notif.customField1) {
            customId = notif.customField1;
        }
        rootVc = [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeClaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeEcoupon newCouponType:NYNewCouponMappingTypeCustom newCouponCustomId:customId autoClaimECouponID:nil];

    } else if (targetType == RoutingTargetTypeCustomCouponDetail) {
        // 判斷是否為收到轉贈的推播通知，如果是就走已領取詳情頁的邏輯
        NSString *sysValue = [notif.nyCallBackData[@"sys"] lowercaseString];
        BOOL isTransferNoti = [sysValue isEqualToString:@"coupontransfer"];
        rootVc = [[NYNewCouponDetailViewController alloc] initWithCouponId:notif.targetID slaveId:@0 isFromClaimedPage:isTransferNoti];

    } else if (targetType == RoutingTargetTypeLiveBuyVideo) {
        rootVc = [NYWKWebViewController liveBuyVideoWebVCWithUrl:notif.url];

    } else if (targetType == RoutingTargetTypeDesignCloudWebPage) {
        rootVc = [[DCWKWebViewController alloc] initWithUrl:notif.url];
        
    } else if (targetType == RoutingTargetTypeDesignCloudNative) {
        // 使用 DesignCloudBridge 取得正確的視圖控制器
        NSString *urlPath = notif.url.path;
        if (globalActiveNavigationController && [globalActiveNavigationController isKindOfClass:[NaviController class]]) {
            rootVc = [DesignCloudBridge getViewControllerWithPath:urlPath navigator:(NaviController *)globalActiveNavigationController];
            if (!rootVc) {
                // 如果無法取得視圖控制器，則使用 WebView 作為備用方案
                targetType = RoutingTargetTypeDesignCloudWebPage;

                rootVc = [[DCWKWebViewController alloc] initWithUrl:notif.url];
            }
        } else {
            // 如果不是 NaviController，則使用 WebView
            targetType = RoutingTargetTypeDesignCloudWebPage;

            rootVc = [[DCWKWebViewController alloc] initWithUrl:notif.url];
        }
    } else {
        // RoutingTargetTypeUnknown
    }
     
    if (targetType == RoutingTargetTypeShopHome) {
        [NYNotificationPushHelper activeNavigationController:globalActiveNavigationController pushViewController:nil thenSelectTabAtType:NYTabBarItemTypeIndex];
        
    } else if (targetType == RoutingTargetTypeSchemeRedirect) {
        [self processSchemeRedirectWithNotificationObj:notif];
        
    } else if (rootVc && targetType != RoutingTargetTypeUnknown) {
        [self pushToVC:rootVc targetType:targetType completion:completion];
        
    }
}

- (void)navigateToTargetPageWith:(RoutingObject *)notif {
    [self processNotificationAction:notif shouldSendTrackingLogs:NO];
}

- (void)processPushNotificationAction:(RoutingObject *)notif {
    [self processNotificationAction:notif shouldSendTrackingLogs:YES];
}

- (void)processNotificationAction:(RoutingObject *)notif shouldSendTrackingLogs:(BOOL)shouldTrack {
    if (shouldTrack) {
        [self trackingNotificationAction:notif];
    }
    [self processNotificationAction:notif withCompletionBlock:nil];
}

- (void)processADElementAction:(NYADElementObject *)adElement {
    UIViewController *targetVC = [[[NYADLandingHelper alloc] init] viewControllerForADElement:adElement];
    
    //FIXME:這寫法其實不好, 暫時的解法
    UIViewController *rootVC = [[UIApplication sharedApplication] getKeyWindow].rootViewController;
    if ([rootVC isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabBarVC = (UITabBarController *)rootVC;
        [NYNotificationPushHelper activeNavigationController:tabBarVC.selectedViewController pushViewController:targetVC thenSelectTabAtIndex:tabBarVC.selectedIndex];
    }
}

#pragma Notification Actions

- (UIViewController *)redirectToSalePageCategoryWithNotificationObj:(RoutingObject *)notif {
    BrowserLayout layoutType = (notif.source == RoutingSourceUrl) ? (BrowserLayout)notif.customField1.integerValue : BrowserLayoutUnknown;
    NSString *serviceType = notif.customField3;
    
    UIViewController *itemListVC;
    if (notif.url) {
        NSURLComponents *urlComponent = [[NSURLComponents alloc] initWithURL:notif.url resolvingAgainstBaseURL:NO];
        NSString *queryString = urlComponent.query;
        SearchResultFilterObject *filterObj = [[SearchResultFilterObject alloc] initWithQueryString:queryString];
        
        itemListVC = [NYLaunchHelper itemListVCWithCategoryId:notif.targetID filterObj:filterObj layoutType:layoutType sortKey:notif.customField2 serviceType:serviceType];
    } else if (notif.customField1) {
        // 小分類頁的話通常 categoryId 都帶在 customField1
        int categoryId = [notif.customField1 intValue];
        itemListVC = [NYLaunchHelper itemListVCWithCategoryId:@(categoryId) filterObj:nil layoutType:layoutType sortKey:notif.customField2 serviceType:serviceType];
    } else {
        // Do Nothing
    }
    
    return itemListVC;
}

- (UIViewController *)redirectToNotificationCenter {
    NYNotificationViewPagerController *svc = [[NYNotificationViewPagerController alloc] initWithInitialPage:NYNotificationPageSystemMessage redDotDelegate:MenuRedDotManager.shared];
    svc.title = NYLocalizedString(@"msg_center_system_message", nil);
    return svc;
}

- (UIViewController *)redirectToSalePageWithNotificationObj:(RoutingObject *)notif {
    // 如果是隱賣商品，salePageID 就帶 nil 給商品頁初始化，實際的 salePageID 會從 API 取得
    BOOL isHiddenProduct = notif.targetIDString != nil;
    NSNumber *salePageID = isHiddenProduct ? nil : notif.targetID;
    NSString *salePageCode = notif.targetIDString ?: nil;
    NYSalePageViewController *salePageVC = [NYSalePageViewController viewControllerWithSalePageId:salePageID
                                                                                     salePageCode:salePageCode
                                                                               isFromShoppingCart:notif.isFromCart];
    
    return salePageVC;
}
// 24.8 點擊進到贈品詳情頁(放大圖)
- (UIViewController *)redirectToNYGiftDetailWithNotificationObj:(RoutingObject *)notif {
    NSNumber *giftID = notif.targetID;
    NYPromotionEngineGiftDetailVC *giftDetailVC = [[NYPromotionEngineGiftDetailVC alloc] initWithGiftID:giftID];
    // 找到正確的 VC & NavigationController
    UINavigationController *topNavController = [UIViewController topNavigationController];
    if (topNavController) {
        [topNavController pushViewController:giftDetailVC animated:YES];
        return nil;
    } else {
        return giftDetailVC;
    }
}

- (UIViewController *)redirectToCustomerServiceCenter {
    return [NYWKWebViewController customerServiceCenterWebVC];
}

- (UIViewController *)redirectToQuestionList {
    return [NYWKWebViewController questionListWebVC];
}

- (UIViewController *)redirectToTradeOrderList {
    return [NYWKWebViewController tradesOrderListWebVC];
}

- (UIViewController *)redirectToCustomerInquiry {
    return [NYWKWebViewController customerInquiryWebVC];
}

- (UIViewController *)redirectToCustomerServiceEntry {
    return [NYWKWebViewController shopCustomerServiceEntryWebVC];
}

- (void)redirectToExternalBrowserWithURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url
                                       options:@{}
                             completionHandler:nil];
}

- (UIViewController *)redirectToWebViewViaUrlWithNotificationObj:(RoutingObject *)notif {
    return [NYWKWebViewController standardWebVCWithUrl:notif.url allowsInlineMediaPlayback:YES];
}

- (UIViewController *)redirectToWebViewViaCustomFieldWithNotificationObj:(RoutingObject *)notif {
    // only one of "ShopHome" / "MallHome" will be invoked in one app
    // TODO: goo.gl 還可以用? 先純粹改 WK 不動邏輯
    NSString *urlString = [NSString stringWithFormat:@"https://goo.gl/%@", notif.customField1];
    NSURL *url = [NSURL URLWithString:urlString];
    NYWKWebViewController *vc = [NYWKWebViewController standardWebVCWithUrl:url allowsInlineMediaPlayback:YES];
    return vc;
}

- (UIViewController *)redirectToSelfDismissWebViewWithNotificationObj:(RoutingObject *)notif {
    NYWKWebViewController *vc = [NYWKWebViewController standardWebVCWithUrl:notif.url allowsInlineMediaPlayback:YES];
    vc.dismissStatus = NYWKWebViewSelfDismissStatusPageLoading;
    return vc;
}

- (void)redirectViaWrappedURLWithNotificationObj:(RoutingObject *)notif completion:(Completion)completion {
    // 取代goo.gl，後端給的 (customField1) 值可能為一串 URL 短網址 or 官網網址
    NSString *customField = notif.customField1;
    
    if (customField) {
        NSURL *url = [NSURL mwebParseWithString:customField];
        
        if (!url) {
            // 可能有特殊字元，嘗試重組 url
            url = [NSURL recomposeWithString:customField];
            // log unexpected url
            [NYCrashlyticsHelper recordWithUnexpectedURL:customField];
        }
        
        [self unwrapFullURLWith:url completion:completion];
        
    } else {
        // URL redirect (scheme://fullurl/{導頁 url})
        [self unwrapTargetURLWith:notif.url completion:completion];
    }
}

- (void)unwrapFullURLWith:(NSURL *)url completion:(Completion)completion {
    RoutingObject *notifObj = [[RoutingObject alloc] initWithUrlString:url.absoluteString];
    [self processNotificationAction:notifObj withCompletionBlock:completion];
}

/**
 * Parse Target URL
 *
 * 完整的 url 會長這樣：「scheme://fullurl/{導頁 url}」
 *
 * path format 會是：「/(真正要導頁的 url str)」，因此取「/」以後的 subString
 */
-(void)unwrapTargetURLWith:(NSURL *)url completion:(Completion)completion {
    NSString *targetPath = url.path;
    NSString *redirectURLString = [targetPath substringFromIndex:1];
    if (redirectURLString) {
        RoutingObject *notifObj = [[RoutingObject alloc] initWithUrlString:redirectURLString];
        [self processNotificationAction:notifObj withCompletionBlock:completion];
    }
}

- (UIViewController *)redirectToLocationList {
    NYStoreLocationListViewController *vc = [[NYStoreLocationListViewController alloc] initWithShopId:[NYGlobalData shopId]];
    return vc;
}

- (UIViewController *)redirectToLocationDetailWithNotificationObj:(RoutingObject *)notif {
    NYStoreLocationInfoDetailViewController *vc = [[NYStoreLocationInfoDetailViewController alloc] initWithStoreId:notif.targetID];
    return vc;
}

- (UIViewController *)redirectToCouponList {
    return [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeUnclaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeCoupon newCouponType:NYNewCouponMappingTypeStore newCouponCustomId:@"" autoClaimECouponID:nil];
}

- (UIViewController *)redirectToMyCouponList {
    return [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeClaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeCoupon newCouponType:NYNewCouponMappingTypeStore newCouponCustomId:@"" autoClaimECouponID:nil];
}

- (UIViewController *)redirectToCouponDetailWithNotificationObj:(RoutingObject *)notif {
    NYCouponDetailVC *vc = [[NYCouponDetailVC alloc] initWithCouponId:notif.targetID];
    return vc;
}

- (UIViewController *)redirectToInfoModuleDetailWithNotificationObj:(RoutingObject *)notif {
    NYInfoModuleObject *obj = [[NYInfoModuleObject alloc] initWithJSONDictionary:@{@"type": notif.targetCode.lowercaseString, @"id": notif.targetID}];
    NYInfoModuleDetailViewController *detailVC = [[NYInfoModuleDetailViewController alloc] initWithInfoModuleObject:obj];
    return detailVC;
}

- (UIViewController *)redirectToInfoModuleListWithType:(NYInfoModuleType)infoType {
    NYInfoModuleListViewController *vc = [[NYInfoModuleListViewController alloc] initWithInfoModuleType:infoType shopId:[NYGlobalData shopId]];
    return vc;
}

- (UIViewController *)redirectToInfoModuleRecommandList {
    NYInfoModuleListViewController *vc = [[NYInfoModuleListViewController alloc] initInfoRecommandWithShopId:[NYGlobalData shopId] isOnViewPager:NO];
    return vc;
}

- (UIViewController *)redirectToSearchViewController {
    SearchViewController *searchVC = [[SearchViewController alloc] init];
    return searchVC;
}

- (UIViewController *)redirectToSearchWithNotificationObj:(RoutingObject *)notif {
    NSString *apnsSearchKeyword = notif.customField1;
    if (apnsSearchKeyword && apnsSearchKeyword.length > 0) {
        // 推播進來的 pattern
        UIViewController *vc = [[SearchResultViewController alloc] initWithKeyword:apnsSearchKeyword];
        return vc;
    }
    // 一般網址的 pattern
    NSURL *url = [NSURL mwebParseWithString:notif.url.absoluteString];
    NSURLComponents *urlComponent = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    NSString *queryString = urlComponent.query;
    UIViewController *vc = [[SearchResultViewController alloc] initWithQueryStrings:queryString];
    return vc;
}

- (UIViewController *)redirectToECouponWithNotificationObj:(RoutingObject *)notif {
    if (notif.isFromCart) {
        NYECouponDetailViewController *eCouponDetailVC = [NYECouponDetailViewController vcWithECouponId:notif.targetID
                                                                                     isFromShoppingCart:YES];
        return eCouponDetailVC;
    } else {
        // 判斷是否為收到轉贈的推播通知，如果是就走未領取詳情頁的邏輯
        NSString *sysValue = [notif.nyCallBackData[@"sys"] lowercaseString];
        BOOL isTransferNoti = [sysValue isEqualToString:@"coupontransfer"];
        NYECouponDetailSpecialSource source = (notif.isRedirectActivity) ? NYECouponDetailSpecialSourceActivityDetailVC : NYECouponDetailSpecialSourceNone;
        NYECouponDetailViewController *eCouponDetailVC = [NYECouponDetailViewController vcWithECouponId:notif.targetID
                                                                                          specialSource:source
                                                                                      isFromClaimedPage:isTransferNoti];
        return eCouponDetailVC;
    }
}

- (UIViewController *)redirectToECouponExplanationWithNotificationObj:(RoutingObject *)notif {
    // 判斷是否為收到轉贈的推播通知，如果是就走已領取詳情頁的邏輯
    NSString *sysValue = [notif.nyCallBackData[@"sys"] lowercaseString];
    BOOL isTransferNoti = [sysValue isEqualToString:@"coupontransfer"];
    NYECouponExplanationViewController *explanationVC = [NYECouponExplanationViewController
                                                         viewControllerWithECouponId:notif.targetID
                                                         eCouponSlaveId:@0
                                                         specialSource:NYECouponDetailSpecialSourceNone
                                                         isFromClaimedPage:isTransferNoti];
    return explanationVC;
}

- (UIViewController *)redirectToECouponListWithPageType:(NYCouponListV2DataSourceType)pageType {
    NYNewCouponMappingType newType;
    switch (pageType) {
    case NYCouponListV2DataSourceTypeEcoupon:
            newType = NYNewCouponMappingTypeDiscount;
            break;
    case NYCouponListV2DataSourceTypeGiftEcoupon:
            newType = NYNewCouponMappingTypeGift;
            break;
    case NYCouponListV2DataSourceTypeFreeShippingECoupon:
            newType = NYNewCouponMappingTypeShipping;
            break;
    case NYCouponListV2DataSourceTypeCoupon:
            newType = NYNewCouponMappingTypeStore;
            break;
    }
    return [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeUnclaimedPage oldCouponSourceType:pageType newCouponType:newType newCouponCustomId:@"" autoClaimECouponID:nil];
}

- (UIViewController *)redirectToMyECouponWithPageType:(NYCouponListV2DataSourceType)pageType {
    NYNewCouponMappingType newType;
    switch (pageType) {
    case NYCouponListV2DataSourceTypeEcoupon:
            newType = NYNewCouponMappingTypeAll;
            break;
    case NYCouponListV2DataSourceTypeGiftEcoupon:
            newType = NYNewCouponMappingTypeGift;
            break;
    case NYCouponListV2DataSourceTypeFreeShippingECoupon:
            newType = NYNewCouponMappingTypeShipping;
            break;
    case NYCouponListV2DataSourceTypeCoupon:
            newType = NYNewCouponMappingTypeStore;
            break;
    }
    return [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeClaimedPage oldCouponSourceType:pageType newCouponType:newType newCouponCustomId:@"" autoClaimECouponID:nil];
}

- (UIViewController *)redirectToHotSaleRankListWithShopId:(NSNumber *)shopId {
    NYHotSaleRankListVC *hotSaleRankVC = [[NYHotSaleRankListVC alloc] init];
    [hotSaleRankVC setContent:shopId];
    return hotSaleRankVC;
}

- (UIViewController *)redirectToHotSaleRankListWithPeriod:(NSString *)period {
    NYHotSaleRankListVC *hotSaleRankVC = [[NYHotSaleRankListVC alloc] init];
    [hotSaleRankVC setContent:period];
    return hotSaleRankVC;
}

- (UIViewController *)redirectToActivityDetailWithNotificationObj:(RoutingObject *)notif {
    NSInteger activityID = notif.targetID.integerValue;
    NYActivityDetailVC *vc = [[NYActivityDetailVC alloc] initWithActivityID:activityID];
    return vc;
}

- (UIViewController *)redirectToLocationPointEventDetailWithNotificationObj:(RoutingObject *)notif {
    [[NYThirdPartySSOHelper shared] recordNotificationObjectIfNeeded:notif];
    UIViewController *vc = [[NYLocationPointEventDetailVC alloc] initWithLocationPointEventId:notif.targetID];
    return vc;
}

- (UIViewController *)redirectToPromotionList {
    NYPromotionListVC *promotionListVC = [[NYPromotionListVC alloc] initWithShopId:[NYGlobalData shopId]];
    return promotionListVC;
}

- (UIViewController *)redirectToPromotionDetailWithNotification:(RoutingObject *)notif {
    NYPromotionDetailContainerVC *vc = [[NYPromotionDetailContainerVC alloc] initWithShopID:[NYGlobalData shopId]
                                                                                promotionID:notif.targetID
                                                                         isFromShoppingCart:notif.isFromCart];
    return vc;
}

- (void)redirectToTabBarMemberDetail {
    NYTabBarControllerV2 *tabBarController = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
    [tabBarController selectTabBarItemOf:NYTabBarItemTypeMemberDetail];
}

- (void)redirectToVipMemberProfile {
    BOOL (^typeCheckBlock)(id target, Class targetClass) = ^(id target, Class targetClass){
        BOOL result = [target isKindOfClass:targetClass];
        NSAssert(result, @"Wrong Type, NYTabBarController 有改？");
        return result;
    };
    
    //TODO:太多直接取特定Index, 這個只要Tabbar一改就會出事
    if (typeCheckBlock([globalActiveNavigationController tabBarController], [NYTabBarControllerV2 class])) {
        NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
        
        //Get member navigation controller
        UINavigationController *naviVC = [tabbarVC fetchNaviControllerWith:NYTabBarItemTypeMemberDetail];
        
        //Setup flag (這樣才會跳資料填寫)
        //2019/9/26 : API 會決定有沒有資料填寫頁，launch 時存在 NYUserDefault
        if (NYUserDefaultV2.isShowCustomVipMember == YES) {
            if (typeCheckBlock(naviVC.viewControllers.firstObject, [NYCustomVipMemberViewController class])) {
                NYCustomVipMemberViewController *memberVC = (NYCustomVipMemberViewController *)naviVC.viewControllers.firstObject;
                [memberVC setIsForceShowMemberCard:[NYUserDefault isShowVipMemberInfo]];
            }
        } else {
            if (typeCheckBlock(naviVC.viewControllers.firstObject, [NYMemberV2ViewController class])) {
                NYMemberV2ViewController *memberVC = (NYMemberV2ViewController *)naviVC.viewControllers.firstObject;
                memberVC.isForceShowMemberCard = [NYUserDefault isShowVipMemberInfo];
            }
        }
        
        //前往會員專區第一頁
        [naviVC popToRootViewControllerAnimated:NO];
        [tabbarVC selectTabBarItemOf:NYTabBarItemTypeMemberDetail];
    }
}

- (void)redirectToShoppingCartWithCode: (NSString *)code {
    NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
    [tabbarVC presentCartWith:code];
}

- (void)redirectToShoppingCartWithSlaveId: (NSNumber *)salveID {
    NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
    if (salveID) {
        [tabbarVC presentCartWithGiftCouponSlaveID: salveID];
    } else {
        [tabbarVC presentShoppingCart];
    }
}
/// 開新車路徑
/// 預期 URL 結構為 schema://SCV2?url=https://host/path?query=xxx&query2=ooo&query3=oxox
/// 為避免因 queryItem 解析導致讀取 url 時短少 queryItem，直接取用 url= 後的完整字串組成 redirectURL
/// - Parameters:
///  - url: deeplink URL，預期 queryItem 應含有 url.
- (void)redirectToShoppingCartV2WithURL: (NSURL *)url {
    NSURL* redirectURL;
    NSString * deepLink = url.absoluteString;
    NSRange range = [deepLink rangeOfString:@"url="];
    if (range.location != NSNotFound) {
        NSString *rawURLString = [deepLink substringFromIndex:(range.location + range.length)];
        redirectURL = [NSURL URLWithString:rawURLString];
    } else {
        NSLog(@"No query item with name 'url' found");
    }

    if (!redirectURL) {
        NSLog(@"SCV2 - Query value is not valid url.");
        return;
    }

    NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
    [tabbarVC presentV2CartWithUrl:redirectURL];
}

- (void)redirectToPaymentWalletWithQueryItems:(NSArray<NSURLQueryItem *> *) queryItems {
    NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
    [tabbarVC presentPaymentWalletWith:queryItems];
}

- (UIViewController *)redirectToBoCPayConfirmWebViewWithNotificationObj:(RoutingObject *)notif {
    // Parse Target URL
    NSString *targetPath = notif.url.path;
    NSString *encodeTargetURLString = [targetPath substringFromIndex:1]; // trim "/"
    NSString *decodeTargetURLString = [encodeTargetURLString stringByRemovingPercentEncoding];
    NSURL *targetURL = [[NSURL alloc] initWithString:decodeTargetURLString];
    
    // Create confirm web view
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC confirmPageWith:targetURL];
    return vc;
}

- (UIViewController *)redirectToThirdPartyPaymentConfirmWebViewWithNotificationObj:(RoutingObject *)notif {
    NSURLComponents *components = [NSURLComponents componentsWithURL:notif.url
                                             resolvingAgainstBaseURL:YES];
    // TODO: 等把現行的第三方支付 test case 補齊後，這邊就不該再拿"第一個"query string，這寫法太脆弱
    NSString *targetURLString = components.queryItems.firstObject.value;
    NSURL *targetURL = [[NSURL alloc] initWithString:targetURLString];
    
    // Create confirm web view
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC confirmPageWith:targetURL];
    return vc;
}

- (UIViewController *)redirectToThirdPartyPaymentCancelWebViewWithNotificationObj:(RoutingObject *)notif {
    NSURLComponents *components = [NSURLComponents componentsWithURL:notif.url
                                             resolvingAgainstBaseURL:YES];
    NSString *targetURLString = components.queryItems.firstObject.value;
    NSURL *targetURL = [[NSURL alloc] initWithString:targetURLString];
    
    // Create cancel web view
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC cancelPageWith:targetURL];
    return vc;
}

- (UIViewController *)redirectToLoyaltyPointCenter {
    // 2.32.0 積點
    NYMemberLoyaltyPointCenterVC *vc = [NYMemberLoyaltyPointCenterVC viewController];
    return vc;
}

- (UIViewController *)redirectToCMSHiddenPageWithNotificationObj:(RoutingObject *)notif {
    NSString *pageId = notif.targetIDString ? notif.targetIDString : notif.customField1;
    NYCMSBasedViewController *vc = [NYCMSBasedViewController customViewControllerWithPageType:NYCMSPageTypeHiddenActivity pageId:pageId];
    return vc;
}

- (UIViewController *)redirectToCMSCustomPageWithNotificationObj:(RoutingObject *)notif {
    NSString *pageId = notif.targetIDString ? notif.targetIDString : notif.customField1;
    NSString *serviceType = notif.customField2;
    if ([RetailStoreService isFeatureEnable]) {
        serviceType = [RetailStoreService serviceTypeWithPageId:pageId];
    }
    if ([CMSPresentVCHelper shouldChooseStoreFirstWithType:NYCMSPageTypeCustom pageId:pageId]) {
        [[RetailStoreService shared] setChooseStoreTargetWithCompletion:^{
            [[RetailStoreService shared] clearChooseStoreTarget];
            [[NYNotificationPresenter sharedInstance] navigateToTargetPageWith:notif];
        }];
        RoutingObject *newNotif = [[RoutingObject alloc] initWithTargetType:RoutingTargetTypeChoosingStoreDelivery];
        [self navigateToTargetPageWith:newNotif];
        return nil;
        
    } else {
        NYCMSBasedViewController *vc = [NYCMSBasedViewController customViewControllerWithPageType:NYCMSPageTypeCustom pageId:pageId];
        vc.serviceType = serviceType;
        return vc;
    }
}

- (UIViewController *)redirectToCMSFeverSocialWithNotificationObj:(RoutingObject *)notif {
    NYWKWebViewController *vc = [NYWKWebViewController feverSocialWebVCWithUrl:notif.url];
    return vc;
}

- (UIViewController *)redirectToMemberPointExchange {
    NYMemberPointExchangeVC *vc = [[NYMemberPointExchangeVC alloc] init];
    return vc;
}

- (UIViewController *)redirectToRegularOrder {
    // 2.38.0 定期購管理
    // 2.71 新增：新版定期購管理頁仍由此路轉導
    NYWKWebViewController *vc = [NYWKWebViewController regularOrderManagementWebVC];
    return vc;
}

- (UIViewController *)redirectToPromotionEngineDetailWithNotificationObj:(RoutingObject *)notif {
    // 2.40.0 折扣活動詳細頁 - promotion engine
    NYPromotionEngineDetailVC *vc = [[NYPromotionEngineDetailVC alloc] initWithShopId:[NYGlobalData shopId]
                                                                          promotionId:notif.targetID
                                                                   isFromShoppingCart:notif.isFromCart];
    return vc;
}

- (UIViewController *)redirectToJKOPayPaymentConfirmWithNotificationObj:(RoutingObject *)notif {
    // 2.42.0 街口支付付款結果
    NSString *urlString = [[NSString alloc] initWithFormat:@"%@/V2/ThirdPartyPayment/JkoPaymentConfirm?k=%@", [NYBaseURLConfig baseHTTPSURLWithAppServiceWebPageDomain].absoluteString, notif.targetIDString];
    NSURL *url = [[NSURL alloc] initWithString:urlString];
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC confirmPageWith:url];
    return vc;
}

- (UIViewController *)redirectToPaymentConfirmWithNotificationObj:(RoutingObject *)notif {
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC confirmPageWith:notif.url];
    return vc;
}

- (UIViewController *)redirectToPaymentCancelWithNotificationObj:(RoutingObject *)notif {
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC cancelPageWith:notif.url];
    return vc;
}

- (UIViewController *)redirectToPXPartialPickupWithNotificationObj:(RoutingObject *)notif {
    [[NYThirdPartySSOHelper shared] recordTargetUrlIfNeeded:notif.url];
    NYPXMartPartialPickupWebVC *vc = [[NYPXMartPartialPickupWebVC alloc] initWithStartUrl:notif.url];
    return vc;
}

- (UIViewController *)redirectToPXPartialPickupPushWithNotificationObj:(RoutingObject *)notif {
    NSURL *url = [NSURL URLWithString:notif.customField1];
    if (url == nil) {
        return nil;
    }
    [[NYThirdPartySSOHelper shared] recordTargetUrlIfNeeded:url];
    NYPXMartPartialPickupWebVC *vc = [[NYPXMartPartialPickupWebVC alloc] initWithStartUrl:url];
    return vc;
}

- (UIViewController *)redirectToPrivacyPolicyPage {
    NYWKWebViewController *vc = [NYWKWebViewController appPrivacyWebVC];
    return vc;
}

- (void)processThirdpartyBasedOAuthWithNotificationObj:(RoutingObject *)notif {
    [[NYThirdPartySSOHelper shared] analyzeSSOAuthWithUrl:notif.url];
    NSString *token = [NYThirdPartySSOHelper shared].thirdPartySsoToken;
    if (!token) { return; }
    
    if ([[NYThirdPartySSOHelper shared] needsLoginFirst] && ![NYLoginHelper sharedInstance].isLogin) {
        NYSSOType ssoType = [NYThirdPartySSOHelper shared].type;
        NSURL *destinationUrl;
        RoutingObject *redirectNotifObj;
        NYThirdPartyLoginWebBrowserVC *tpLoginVC;
        UINavigationController *webNavi;
        UIViewController *visibleVC;
        
        switch (ssoType) {
            case NYSSOTypeUrl: {
                // 外導內、web導頁中未特別用 LoginVCInfo completionHandler 指定登入後推頁者
                destinationUrl = [[NYThirdPartySSOHelper shared] getDestinationUrl];
                redirectNotifObj = [[RoutingObject alloc] initWithUrlString:destinationUrl.absoluteString];
                tpLoginVC = [NYThirdPartyLoginWebBrowserVC viewControllerWithThirdPartyToken:token loginSuccessCompletionBlock:^{
                    [self navigateToTargetPageWith:redirectNotifObj];
                }];
                webNavi = [[UINavigationController alloc] initWithRootViewController:tpLoginVC];
                webNavi.modalPresentationStyle = UIModalPresentationFullScreen;
                [self dismissThirdPartyLoginVCIfNeeded];
                [globalActiveNavigationController presentViewController:webNavi animated:YES completion:nil];
                break;
            }
                
            case NYSSOTypeNotificationObject: {
                // 外導內、web導頁中未特別用 LoginVCInfo completionHandler 指定登入後推頁者
                redirectNotifObj = [NYThirdPartySSOHelper shared].notif;
                tpLoginVC = [NYThirdPartyLoginWebBrowserVC viewControllerWithThirdPartyToken:token loginSuccessCompletionBlock:^{
                    [self navigateToTargetPageWith:redirectNotifObj];
                }];
                webNavi = [[UINavigationController alloc] initWithRootViewController:tpLoginVC];
                webNavi.modalPresentationStyle = UIModalPresentationFullScreen;
                [self dismissThirdPartyLoginVCIfNeeded];
                [globalActiveNavigationController presentViewController:webNavi animated:YES completion:nil];
                break;
            }

            case NYSSOTypeNotSpecified:
            default:
                // 用 LoginVCInfo completionHandler 處理登入後推頁者
                visibleVC = globalActiveNavigationController.visibleViewController;
                if (visibleVC && [visibleVC isKindOfClass:[NYThirdPartyLoginWebBrowserVC class]]) {
                    tpLoginVC = (NYThirdPartyLoginWebBrowserVC *)visibleVC;
                    [tpLoginVC processSSOLoginWithToken:token];
                }
                break;
        }
    } else {
        // Do nothing. 停留在原頁
    }
}

- (void)processSchemeRedirectWithNotificationObj:(RoutingObject *)notif {
    NSString *urlScheme = [self getRedirectUrlFromNotificationObj:notif];
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlScheme]] == NO) {
        [self popDefaultDownloadAlert];
        
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlScheme]
                                           options:@{}
                                 completionHandler:nil];
    }
}

- (NSString *)getRedirectUrlFromNotificationObj:(RoutingObject *)notif {
    NSURLComponents *components = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%@",notif.url]];
    __block NSString *redirectUrlScheme = @"";
    
    [components.queryItems enumerateObjectsUsingBlock:^(NSURLQueryItem *queryItem, NSUInteger idx, BOOL *stop) {
        if ([queryItem.name containsString:@"schemeRedirect"]) {
            redirectUrlScheme = [NSString stringWithFormat:@"%@://", queryItem.value];
            *stop = YES;
        }
    }];
    
    return redirectUrlScheme;
}

- (void)processOpenPxPay {
    AlertPresentViewController *vc;
    NSURLComponents *component = [NSURLComponents new];
    component.scheme = [NYUrlHelper pxPaySSOUrlScheme];
    NSURL *url = component.URL;
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        vc = [OpenPXPayAlertBuilder openAlert];
    } else {
        vc = [OpenPXPayAlertBuilder downloadAlert];
    }
    [[globalActiveNavigationController visibleViewController] presentViewController:vc animated:YES completion:nil];
}

- (void)presentRetailStoreChoosingWithNotificationObj:(RoutingObject *)notif {
    BOOL isChooseStoreEnable = [RetailStoreService isFeatureEnable];
    if (!isChooseStoreEnable) {
        return;
    }
    
    UIViewController *vc = [UIViewController new];
    RoutingTargetType type = notif.targetType;
    switch (type) {
        case RoutingTargetTypeChoosingStorePickup:
            vc = [RetailStoreChoosingPagerVC hourToGoWithTab:RetailStoreLogisticsTypePickupStore];
            break;

        case RoutingTargetTypeChoosingStoreDelivery:
        default:
            vc = [RetailStoreChoosingPagerVC hourToGoWithTab:RetailStoreLogisticsTypeDeliveryStore];
            break;
    }
    
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:vc];
    nc.modalPresentationStyle = UIModalPresentationFullScreen;
    UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
    UIViewController *topViewController = [globalActiveNavigationController topViewController];
    UIViewController *presentingVC = visibleVC;
    BOOL isOnLeftMenu = [visibleVC isKindOfClass:[NYLeftMenuV2ViewController class]];
    if (isOnLeftMenu) {
        // 因為側欄最後會被關掉，所以改用側欄的 presentedVC（topViewController) 來推頁
        presentingVC = topViewController;
        [presentingVC dismissViewControllerAnimated:YES completion:^{
            [presentingVC presentViewController:nc animated:YES completion:nil];
        }];
    } else {
        [presentingVC presentViewController:nc animated:YES completion:nil];
    }
}

- (void)presentDesignCloudAddToCartEventWith:(NYAddToCartRequestObject *)cartObject {
    UIViewController *topVC = globalActiveNavigationController.topViewController;
    [[NYAddToCartHelper sharedInstance] addToCartFromDesignCloudEventWithRequestObject:cartObject from:topVC completion:^(id<NYAddToCartResultProtocol>  _Nullable resultObject, NSError * _Nullable error) {}];
}

- (UIViewController *)redirectToStaffBoardList {
    DCWKWebViewController *vc = [DCWKWebViewController staffBoardStyleListWith:nil];
    return vc;
}

- (UIViewController *)redirectToStaffBoardDetailWithObject:(RoutingObject *)notif {
    NSString *workId = notif.targetIDString ?: @"";
    NYCMSStaffBoardDetailViewController *vc = [NYCMSStaffBoardDetailViewController staffBoardDetailViewControllerWith:workId staffId:@"" isFromFDL:YES];
    return vc;
}

- (UIViewController *)redirectToTagCategoryWithObject:(RoutingObject *)notif {
    NSString *encodedTagStr = notif.encodedTagString ?: @"";
    NSArray <NSString *> *tagList = notif.tagList ?: @[];
    NYSmartTagCategoryListViewController *vc = [NYSmartTagCategoryListViewController createWithEncodedTag:encodedTagStr watchingTag:tagList];
    return vc;
}

- (UIViewController *)redirectToNewestCategoryList {
    return [NYLaunchHelper newestCategoryPage];
}

- (UIViewController *)redirectToInvitingFriendsPage {
    MemberInvitationCodeViewController *vc = [MemberInvitationCodeViewController new];
    return vc;
}

- (UIViewController *)redirectToEVoucherListWebView {
    NSString *pageTypeString = [NYSwiftAdapter convertEVoucherPageTypeToStringWithPageType:EVoucherPageTypeList];
    UIViewController *vc = [NYWKWebViewController eVoucherWebVCWithPageType:pageTypeString];
    return vc;
}

- (UIViewController *)redirectToInvitationCodeHistoryPage {
    MemberInvitationHistoryPagerViewController *vc = [[MemberInvitationHistoryPagerViewController alloc] initWithSelectedIndex:0];
    return vc;
}

- (UIViewController *)redirectToArrivalNoticeList {
    MyFavoritePagerViewController *vc = [[MyFavoritePagerViewController alloc] initWithPageType:MyFavoritePageTypeArrivalNotice];
    return vc;
}

- (UIViewController *)redirectToMyFavoriteList {
    MyFavoritePagerViewController *vc = [[MyFavoritePagerViewController alloc] initWithPageType:MyFavoritePageTypeFavorite];
    return vc;
}

- (UIViewController *)redirectToRecentlyBrowse {
    MyFavoritePagerViewController *vc = [[MyFavoritePagerViewController alloc] initWithPageType:MyFavoritePageTypeRecentlyBrowse];
    return vc;
}

- (UIViewController *)redirectToBrandListWithNotificationObj:(RoutingObject *)notif {
    // 品牌總覽
    BrandListViewController *vc = [BrandListViewController new];
    return vc;
}

- (UIViewController *)redirectToBrandPageWithNotificationObj:(RoutingObject *)notif {
    // 品牌頁
    NSString *brandID = notif.targetIDString ?: @"";
    NSString *sortMode = notif.customField1;
    NSString *shopCategoryID = notif.customField2;
    BrandPageViewController *vc = [[BrandPageViewController alloc] initWithBrandID:brandID
                                                                          sortMode:sortMode
                                                                    shopCategoryID:shopCategoryID];
    return vc;
}

- (void)showCarrierBarcode {
    UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
    
    if ([NYLoginHelper sharedInstance].isLogin) {
        [[NYMemberBarcodePresenterV2 shared] presentCarrierBarcodeIfAvailableOn:visibleVC.view];
    } else {
        [visibleVC ny_displayAlertWithTitle:NYLocalizedString(@"member_phone_barcode", nil)
                                    message:NYLocalizedString(@"backinstock_please_login_or_register", nil)];
    }
}

- (void)showEditCarrierBarcode {
    UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
    
    if ([NYLoginHelper sharedInstance].isLogin) {
        [[NYMemberBarcodePresenterV2 shared] presentSettingCarrierCodeView];
    } else {
        [visibleVC ny_displayAlertWithTitle:NYLocalizedString(@"member_phone_barcode", nil)
                                    message:NYLocalizedString(@"backinstock_please_login_or_register", nil)];
    }
}

- (void)showMemberBarcode {
    UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
    
    if ([NYMemberHelper.shareInstance hasCachedBarcode]) {
        [[NYMemberBarcodePresenterV2 shared] presentBarcode];
        
    } else if ([NYLoginHelper sharedInstance].isLogin && [NYUserDefault shouldVerifyCellphoneWithoutOuterID] &&
        [NYLoginHelper userCellPhoneIsEmpty]) {
        // 驗證手機以取得品牌會員編號
        [[globalActiveNavigationController visibleViewController] presentValidateCellPhoneVC];
        
    } else {
        [visibleVC ny_displayAlertWithTitle:NYLocalizedString(@"sidebar_member_barcode", nil)
                                    message:NYLocalizedString(@"member_barcode_empty_description", nil)];
    }
}

- (void)showMemberBarcodeOrCarrierBarcodeAfterLogin {
    if (![NYLoginHelper sharedInstance].isLogin) {
        UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
        [visibleVC presentLoginVCShouldShowUnLoginMask:NO WithLoginSuccessCompletion:^{
            [self showMemberBarcodeOrCarrierBarcode];
        }];
    } else {
        [self showMemberBarcodeOrCarrierBarcode];
    }
}

- (void)showMemberBarcodeOrCarrierBarcode {
    if ([NYMemberHelper.shareInstance hasCachedBarcode]) {
        [[NYMemberBarcodePresenterV2 shared] presentBarcode];

    } else if ([NYLoginHelper sharedInstance].isLogin && [NYUserDefault shouldVerifyCellphoneWithoutOuterID] &&
        [NYLoginHelper userCellPhoneIsEmpty]) {
        /// 驗證手機以取得品牌會員編號
        [[globalActiveNavigationController visibleViewController] presentValidateCellPhoneVC];

    } else if ([NYGlobalData isTaiwan]) {
        /// 檢查後開啟手機載具
        [[NYMemberBarcodePresenterV2 shared] presentCarrierBarcodeIfAvailableOn:nil];
    }
}

- (UIViewController *)openBarcodeScannerWithNotificationObj:(RoutingObject *)notif {
    NSString *countryCode = [NYGlobalData countryCode];
    NSString *scannerType = [NYCountryConfig productScanTypeIn:countryCode];
    // 商品掃描產品化 產品化的掃瞄器不強制用戶登入 (寶雅客製流程還是要求用戶登入)
    if ([NYLoginHelper sharedInstance].isLogin || [scannerType isEqualToString:@"standard"]) {
        return [NYBarcodeScannerViewController getVC];
    } else {
        UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
        [visibleVC presentLoginVCShouldShowUnLoginMask:NO WithLoginSuccessCompletion:^{
            [self navigateToTargetPageWith:notif];
        }];
    }
    
    return nil;
}

- (UIViewController *)openMemberShipCardManagePage {
    return [[NYMemberShipCardManageViewController alloc] init];
}

- (void)pushToZendeskWithCompletion:(Completion)completion {
    [NYZendeskHelper.shared zendeskMessagingViewControllerWithCompletionHandler:^(UIViewController * _Nullable zendeskVC) {
        [self pushToVC:zendeskVC targetType:RoutingTargetTypeZendesk completion:completion];
    }];
}

- (void)popDefaultDownloadAlert {
    NSString *alertMessage = @"";
    NSString *downloadURLString = @"";
    [self getDefaultDownloadURLString:&downloadURLString andAlertMessage:&alertMessage];
    [self popDownloadAlertWithMessage:alertMessage downloadURLString:downloadURLString];
}

- (void)getDefaultDownloadURLString:(NSString **)downloadURLString andAlertMessage:(NSString **)alertMessage {
    BOOL isPxPartWebView = [NYGlobalData o2oWebViewType] == NYO2OWebViewTypePXMart;
    if (isPxPartWebView) {
        *alertMessage = NYLocalizedString(@"brand_identity_px_pay_not_installed", nil);
        *downloadURLString = [NYUrlHelper pxpayAppStoreUrlString];
    }
}

- (void)popDownloadAlertWithMessage:(NSString *)alertMessage downloadURLString:(NSString *)downloadURLString {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:alertMessage
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:NYLocalizedString(@"common_download", nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:downloadURLString]
                                           options:@{}
                                 completionHandler:nil];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NYLocalizedString(@"common_cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alertController addAction:confirmAction];
    [alertController addAction:cancelAction];
    [alertController setPreferredAction:confirmAction];
    [[[UIApplication sharedApplication] getKeyWindow].rootViewController presentViewController:alertController
                                                                                 animated:YES
                                                                               completion:nil];
}

- (void)pushToVC:(UIViewController *)rootVc targetType:(RoutingTargetType)targetType completion:(Completion)completion {
    rootVc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    BOOL needLoginPage = targetType == RoutingTargetTypeRegularOrder ||
    targetType == RoutingTargetTypeLoyaltyPoint ||
    targetType == RoutingTargetTypeInvitingFriends ||
    targetType == RoutingTargetTypeInvitationCodeHistory ||
    targetType == RoutingTargetTypeMemberShipCardManagePage ||
    targetType == RoutingTargetTypeTradesOrderList ||
    targetType == RoutingTargetTypeAutoClaimCoupon;
    
    if (needLoginPage && [[NYAppSettingsHelper sharedInstance] thirdpartyBasedAuth] == NYThirdpartyBasedAuthNoData) {
        //針對推頁需登入的情境處理，thirdpartyBasedAuth為NYThirdpartyBasedAuthNoData時，需再call一次API取thirdpartyBasedAuth
        [[NYDataProvider sharedInstance] getShopStaticSettingWithCompletionHandler:^(NSDictionary *responseObject, NSError *error) {
            NSString *returnCode = responseObject[@"ReturnCode"];
            
            // 拿到沒有提示訊息
            if ([returnCode isKindOfClass:[NSString class]] && [returnCode isEqualToString:APIReturnCode.api0001]) {
                NSDictionary *data = responseObject[@"Data"];
                NSDictionary *thirdpartyBasedAuthSetting = ([data isKindOfClass:[NSDictionary class]]) ? data[@"ThirdpartyBasedAuthSetting"] : @{};
                BOOL isThirdpartyBasedAuthEnabled = [thirdpartyBasedAuthSetting[@"IsThirdpartyBasedAuthEnabled"] boolValue];
                
                NYAppSettingsHelper *appSettingsHelper = [NYAppSettingsHelper sharedInstance];
                appSettingsHelper.thirdpartyBasedAuth = isThirdpartyBasedAuthEnabled ? NYThirdpartyBasedAuthEnable : NYThirdpartyBasedAuthDisable;
                
                [NYNotificationPushHelper activeNavigationController:globalActiveNavigationController pushViewController:rootVc thenSelectTabAtType:NYTabBarItemTypeIndex];
            }
        }];
    } else if (needLoginPage && [[NYLoginHelper sharedInstance] isLogin] == NO) {
        [globalActiveNavigationController presentLoginVCShouldShowUnLoginMask:NO
                                                   WithLoginSuccessCompletion:^{
            [self pushToVC:rootVc targetType:targetType completion:completion];
        }];
    } else if (completion) {
        completion(rootVc);
    } else {
        [NYNotificationPushHelper activeNavigationController:globalActiveNavigationController pushViewController:rootVc];
    }
}

- (void)dismissThirdPartyLoginVCIfNeeded {
    // 避免已經有顯示登入頁，會重複顯示
    UIViewController *visibleVC = globalActiveNavigationController.visibleViewController;
    if (visibleVC && [visibleVC isKindOfClass:[NYThirdPartyLoginWebBrowserVC class]]) {
        [visibleVC dismissViewControllerAnimated:NO completion:nil];
    }
}

- (void)presentCustomerLiveChatWebVCWithQuery:(NSString *)queryString {
    void(^present)(UIViewController * ,UIViewController *) = ^(UIViewController *presentingVC, UIViewController *webVC) {
        [presentingVC presentViewController:webVC animated:YES completion:^{
            // 通知聊天室已開啟
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NYChatRoomDidOpen" object:nil];
        }];
    };
    
    UIViewController *webVC = [NYWKWebViewController customerServiceLiveChatVCWith:queryString];
    UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
    UIViewController *presentingVC = visibleVC;
    BOOL isOnLeftMenu = [visibleVC isKindOfClass:[NYLeftMenuV2ViewController class]];
    if (isOnLeftMenu) {
        UIViewController *topViewController = [globalActiveNavigationController topViewController];
        // 因為側欄最後會被關掉，所以改用側欄的 presentedVC（topViewController) 來推頁
        presentingVC = topViewController;
        [presentingVC dismissViewControllerAnimated:YES completion:^{
            present(presentingVC, webVC);
        }];
    } else {
        present(presentingVC, webVC);
    }
}

@end
//
//  NYNotificationPresenter.h
//  NineyiAppShop
//
//  Created by Sean on 2015/5/25.
//  Copyright (c) 2015年 91App. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NYCore/NYNotificationHelper.h>
@class NYAddToCartRequestObject;

@interface NYNotificationPresenter : NSObject <NYNotificationHelperDelegate>

+ (instancetype)sharedInstance;

+ (void)setActiveNavigationController:(UINavigationController *)navController;

- (void)processNotificationAction:(RoutingObject *)notif withCompletionBlock:(Completion)completion;
- (void)processPushNotificationAction:(RoutingObject *)notif;
- (void)navigateToTargetPageWith:(RoutingObject *)notif;
- (void)processADElementAction:(NYADElementObject *)adElement;
- (void)presentDesignCloudAddToCartEventWith:(NYAddToCartRequestObject *)cartObject;

@end
