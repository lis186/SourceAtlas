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
- **語言上下文**：由語言插件定義（參見 `languages/swift.md`）
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
- **Seam_Type**: 根據語言插件定義的接縫類型（見 `languages/swift.md`）
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

根據語言插件（`languages/swift.md`）產出對應的驗證方式。

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

查閱語言插件（`languages/swift.md`）中的「驗證策略」段落，決定使用 2a、2b、或兩者皆用。

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

Language context: [language] (語言插件: languages/swift.md)

Refactoring intent: [brief description]

Apply the Contract Audit Skeleton with language plugin: languages/swift.md
```

---

## LANGUAGE PLUGIN REFERENCE

語言插件提供以下語言特定的資訊，以 `languages/swift.md` 佔位符引用：

1. **通知/事件原語** -- 語言特定的 pub/sub 機制
2. **同步原語** -- 語言特定的並行控制機制
3. **生命週期模式** -- 框架特定的生命週期 hook
4. **驗證策略** -- 使用 grep、ast-grep、或兩者
5. **Effect 防火牆** -- 語言提供的不可變性保證強度
6. **Seam 類型** -- 語言支援的接縫類型及其運作方式
7. **Sprout/Wrap 策略** -- 可用的遺留程式碼改造模式
8. **常見隱含合約** -- 語言特有的典型隱含合約範例

--- LANGUAGE PLUGIN: swift ---
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

**重構風險：** 如果將 protocol extension 中的預設實作移除或改為 `fatalError("Subclass must implement")`，所有未明確實作該方法的遵循者會從「靜默忽略」變為「編譯錯誤」或「runtime crash」。更微妙的情況是：當遵循者定義了同名方法但簽名略有不同（例如參數標籤不同），Swift 會靜默使用 extension 的預設實作而非遵循者的版本——這種分歧不會產生任何編譯警告。
--- END LANGUAGE PLUGIN ---

## Step 0.7 錨定合約
## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

**載入的框架 patterns**：combine

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | dispatch_sync | 2 | PaymentsNetworkDispatcher.swift:96 |
| 2 | S | DispatchQueue_create | 1 | PaymentsNetworkDispatcher.swift:86 |
| 3 | N | NotificationCenter_post | 1 | PaymentsNetworkDispatcher.swift:362 |
| 4 | D | shared_singleton | 1 | PaymentsNetworkDispatcher.swift:90 |
| 5 | D | if_conditional | 1 | PaymentsNetworkDispatcher.swift:134 |
| 6 | E | throws_decl | 4 | PaymentsNetworkDispatcher.swift:102 |
| 7 | E | do_catch | 3 | PaymentsNetworkDispatcher.swift:140 |
| 8 | E | Codable | 1 | PaymentsNetworkDispatcher.swift:119 |
| 9 | N | combine_sink | 25 ⚠️ pervasive | PaymentsNetworkManager.swift:40 |
| 10 | N | combine_store | 25 ⚠️ pervasive | PaymentsNetworkManager.swift:49 |

共 10 個錨點命中。

對於每個錨定合約，你的 Artifact 1 必須包含至少一個對應的 {Category}-{NNN} 合約。
若你認為某個錨點不構成合約，必須在 Artifact 4 中說明原因。


## Step 0.8 Feature Sketch
以下方法-屬性矩陣顯示模組內部的功能群集，用於識別 M（Mutation）和 L（Lifecycle）合約：
## Feature Sketch（Step 0.8）

| # | 方法 | 行號 | 引用屬性 |
|---|------|------|---------|
| 1 | `func multipassLogin(publishableKey: String,` | PaymentsNetworkManager.swift:26 | self.cancellables |
| 2 | `func getThemeConfiguration(publishableKey: String,` | PaymentsNetworkManager.swift:53 | self.cancellables |
| 3 | `func getSettings(publishableKey: String,` | PaymentsNetworkManager.swift:77 | self.cancellables |
| 4 | `func postTransactionPasscodes(publishableKey: String,` | PaymentsNetworkManager.swift:101 | self.cancellables |
| 5 | `func putTransactionPasscodes(publishableKey: String,` | PaymentsNetworkManager.swift:134 | self.cancellables |
| 6 | `func putTransactionPasscodesRest(publishableKey: String,` | PaymentsNetworkManager.swift:168 | self.cancellables |
| 7 | `func resetVerificationsRequest(publishableKey: String,` | PaymentsNetworkManager.swift:202 | self.cancellables |
| 8 | `func verificationsRequest(publishableKey: String,` | PaymentsNetworkManager.swift:233 | self.cancellables |
| 9 | `func verificationsVerify(publishableKey: String,` | PaymentsNetworkManager.swift:264 | self.cancellables |
| 10 | `func resetVerificationsVerify(publishableKey: String,` | PaymentsNetworkManager.swift:296 | self.cancellables |
| 11 | `func getUsers(publishableKey: String,` | PaymentsNetworkManager.swift:327 | self.cancellables |
| 12 | `func postGrant(publishableKey: String,` | PaymentsNetworkManager.swift:353 | self.cancellables |
| 13 | `func getPaymentMethods(publishableKey: String,` | PaymentsNetworkManager.swift:386 | self.cancellables |
| 14 | `func pendingPayments(publishableKey: String,` | PaymentsNetworkManager.swift:421 | self.cancellables |
| 15 | `func getPaymentMethodDetails(publishableKey: String,` | PaymentsNetworkManager.swift:447 | self.cancellables |
| 16 | `func postPaymentMethods(publishableKey: String,` | PaymentsNetworkManager.swift:479 | self.cancellables |
| 17 | `func postPaymentMethodsSetDefault(publishableKey: String,` | PaymentsNetworkManager.swift:511 | self.cancellables |
| 18 | `func postPaymentMethodsVoid(publishableKey: String,` | PaymentsNetworkManager.swift:544 | self.cancellables |
| 19 | `func postPayments(publishableKey: String,` | PaymentsNetworkManager.swift:577 | self.cancellables |
| 20 | `func getTransactions(publishableKey: String,` | PaymentsNetworkManager.swift:620 | self.cancellables |
| 21 | `func getRecommendations(publishableKey: String,` | PaymentsNetworkManager.swift:652 | self.cancellables |
| 22 | `func postPaymentCodes(publishableKey: String,` | PaymentsNetworkManager.swift:684 | self.cancellables |
| 23 | `func postStoredValues(publishableKey: String,` | PaymentsNetworkManager.swift:719 | self.cancellables |
| 24 | `func postLoginIntents(publishableKey: String,` | PaymentsNetworkManager.swift:760 | self.cancellables |
| 25 | `func postVerifyLoginIntents(publishableKey: String,` | PaymentsNetworkManager.swift:786 | self.cancellables |

共 25 個方法。


## Step 0.9 Caller Interface
以下是外部模組引用目標模組的片段，用於識別 D（Dependency）和 P（Propagation）合約：
## Caller Interface Extract（Step 0.9）

外部模組引用 PaymentsNetworkManager 的片段（±5 行上下文）：


## 目標原始碼

//
//  PaymentsNetworkManager.swift
//
//
//  Created by James Hung on 2023/2/10.
//

import Foundation
import Combine

class PaymentsNetworkManager {
    
    /// Singleton Instance (Prod)
    public static let shared = PaymentsNetworkManager()
    /// Cancellables
    private var cancellables: Set<AnyCancellable> = []
    
}

// MARK: - Methods
extension PaymentsNetworkManager {
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/users/multipass-login
    /// - Parameters:
    ///   - verified: false,  一率做簡訊驗證；true,  可以設定 Bypass, 但仍以該商店的設定為主
    func multipassLogin(publishableKey: String,
                        multipassToken: String,
                        verified: Bool,
                        baseURLString: String,
                        completion: @escaping (Result<PaymentsRequest.Post.MultipassLogin.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.Multipass(multipassToken: multipassToken, verified: verified)
        let request = PaymentsRequest.Post.MultipassLogin(publishableKey: publishableKey, body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: .tenSecondsTimeout)
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("MultipassLogin completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/theme
    func getThemeConfiguration(publishableKey: String,
                               baseURLString: String,
                               completion: @escaping (Result<PaymentsRequest.Get.ThemeConfiguraion.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let request = PaymentsRequest.Get.ThemeConfiguraion(publishableKey: publishableKey)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: .tenSecondsTimeout)
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("getThemeConfiguration completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/settings
    func getSettings(publishableKey: String,
                     baseURLString: String,
                     completion: @escaping (Result<PaymentsRequest.Get.Settings.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let request = PaymentsRequest.Get.Settings(publishableKey: publishableKey)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: .tenSecondsTimeout)
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("getSettings completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (POST) https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/transaction-passcodes
    func postTransactionPasscodes(publishableKey: String,
                                  accessToken: String,
                                  passcode: String,
                                  isConfirmation: Bool,
                                  userUUID: String,
                                  baseURLString: String,
                                  completion: @escaping (Result<Void, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PasscodesSet(passcode: passcode, isConfirmation: isConfirmation)
        let request = PaymentsRequest.Post.TransactionPasscodesSet(publishableKey: publishableKey,
                                                                   accessToken: accessToken,
                                                                   userUUID: userUUID,
                                                                   body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PostTransactionPasscodes completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { _ in
                // No return value
                completion(.success(()))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (PUT) https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/transaction-passcodes
    func putTransactionPasscodes(publishableKey: String,
                                 accessToken: String,
                                 newPasscode: String,
                                 isConfirmation: Bool,
                                 grant: Body.CodeGrant,
                                 userUUID: String,
                                 baseURLString: String,
                                 completion: @escaping (Result<Void, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PasscodesUpdate(newPasscode: newPasscode, isConfirmation: isConfirmation, grant: grant)
        let request = PaymentsRequest.Put.TransactionPasscodesUpdate(publishableKey: publishableKey,
                                                                     accessToken: accessToken,
                                                                     userUUID: userUUID,
                                                                     body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PutTransactionPasscodes completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { _ in
                // No return value
                completion(.success(()))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (PUT) https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/transaction-passcodes/reset
    func putTransactionPasscodesRest(publishableKey: String,
                                     accessToken: String,
                                     newPasscode: String,
                                     isConfirmation: Bool,
                                     grant: Body.CodeGrant,
                                     userUUID: String,
                                     baseURLString: String,
                                     completion: @escaping (Result<Void, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PasscodesReset(newPasscode: newPasscode, isConfirmation: isConfirmation, grant: grant)
        let request = PaymentsRequest.Put.TransactionPasscodesReset(publishableKey: publishableKey,
                                                                    accessToken: accessToken,
                                                                    userUUID: userUUID,
                                                                    body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PutTransactionPasscodesRest completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { _ in
                // No return value
                completion(.success(()))
            }.store(in: &self.cancellables)
    }
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/transaction-passcodes/request-verification
    func resetVerificationsRequest(publishableKey: String,
                                   accessToken: String,
                                   userUUID: String,
                                   baseURLString: String,
                                   completion: @escaping (Result<Void, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.Verification.ResetRequest()
        let request = PaymentsRequest.Post.Verifications.ResetRequest(publishableKey: publishableKey,
                                                                      accessToken: accessToken,
                                                                      userUUID: userUUID,
                                                                      body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("ResetVerificationsRequest completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { _ in
                // No return value
                completion(.success(()))
            }.store(in: &self.cancellables)
    }
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/verifications
    func verificationsRequest(publishableKey: String,
                              accessToken: String,
                              userUUID: String,
                              baseURLString: String,
                              completion: @escaping (Result<Void, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.Verification.Request()
        let request = PaymentsRequest.Post.Verifications.Request(publishableKey: publishableKey,
                                                                 accessToken: accessToken,
                                                                 userUUID: userUUID,
                                                                 body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("VerificationsRequest completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { _ in
                // No return value
                completion(.success(()))
            }.store(in: &self.cancellables)
    }
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/verifications/verify
    func verificationsVerify(publishableKey: String,
                             accessToken: String,
                             code: String,
                             userUUID: String,
                             baseURLString: String,
                             completion: @escaping (Result<Void, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.Verification.Verify(code: code)
        let request = PaymentsRequest.Post.Verifications.Verify(publishableKey: publishableKey,
                                                                accessToken: accessToken,
                                                                userUUID: userUUID,
                                                                body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("VerificationsVerify completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { _ in
                // No return value
                completion(.success(()))
            }.store(in: &self.cancellables)
    }
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/transaction-passcodes/confirm-verification
    func resetVerificationsVerify(publishableKey: String,
                                  accessToken: String,
                                  code: String,
                                  userUUID: String,
                                  baseURLString: String,
                                  completion: @escaping (Result<PaymentsRequest.Post.Verifications.ResetVerify.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.Verification.ResetVerify(code: code)
        let request = PaymentsRequest.Post.Verifications.ResetVerify(publishableKey: publishableKey,
                                                                     accessToken: accessToken,
                                                                     userUUID: userUUID,
                                                                     body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("ResetVerificationsVerify completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}
    func getUsers(publishableKey: String,
                  accessToken: String,
                  userUUID: String,
                  baseURLString: String,
                  completion: @escaping (Result<PaymentsRequest.Get.Users.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let request = PaymentsRequest.Get.Users(publishableKey: publishableKey, accessToken: accessToken, userUUID: userUUID)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("GetUsers completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (POST) https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/grant
    func postGrant(publishableKey: String,
                   accessToken: String,
                   passcode: String,
                   userUUID: String,
                   baseURLString: String,
                   completion: @escaping (Result<PaymentsRequest.Post.Grant.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PasscodeGrant(passcode: passcode)
        let request = PaymentsRequest.Post.Grant(publishableKey: publishableKey,
                                                 accessToken: accessToken,
                                                 userUUID: userUUID,
                                                 body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("Grant completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/payment-methods?payType={payType}&scope={scope}&amount={amount}
    /// - Parameters:
    ///   - scope: 當 scope = transaction, 須給 amount，會針對餘額與付款金額的相對關係而有不同排序
    func getPaymentMethods(publishableKey: String,
                           accessToken: String,
                           userUUID: String,
                           scope: String,
                           payType: String? = nil,
                           amount: String? = nil,
                           baseURLString: String,
                           completion: @escaping (Result<PaymentsRequest.Get.PaymentMethods.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let request = PaymentsRequest.Get.PaymentMethods(publishableKey: publishableKey,
                                                         accessToken: accessToken,
                                                         userUUID: userUUID,
                                                         scope: scope,
                                                         payType: payType,
                                                         amount: amount)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PaymentMethods completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    // TODO: 此 API 暫時兼容 POST
    /// API example: (GET/POST) https://checkout.payments.qa.91dev.tw/api/wallet/pending-payments?code={code}
    func pendingPayments(publishableKey: String,
                         code: String,
                         baseURLString: String,
                         completion: @escaping (Result<PaymentsRequest.Get.PendingPayments.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PostPendingPayments(code: code)
        let request = PaymentsRequest.Post.PendingPayments(publishableKey: publishableKey, body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PendingPayments completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/payment-methods/{payment-method-uuid}?amount={amount}
    func getPaymentMethodDetails(publishableKey: String,
                                 accessToken: String,
                                 userUUID: String,
                                 paymentMethodUUID: String,
                                 amount: String,
                                 baseURLString: String,
                                 completion: @escaping (Result<PaymentsRequest.Get.PaymentMethodDetails.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let request = PaymentsRequest.Get.PaymentMethodDetails(publishableKey: publishableKey,
                                                               accessToken: accessToken,
                                                               userUUID: userUUID,
                                                               paymentMethodUUID: paymentMethodUUID,
                                                               amount: amount)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("GetPaymentMethodDetails completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (PUT) https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/payment-methods
    func postPaymentMethods(publishableKey: String,
                            accessToken: String,
                            payType: String,
                            provider: String,
                            userUUID: String,
                            baseURLString: String,
                            completion: @escaping (Result<PaymentsRequest.Post.PaymentMethods.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PostPaymentMethods(payType: payType, provider: provider)
        let request = PaymentsRequest.Post.PaymentMethods(publishableKey: publishableKey,
                                                          accessToken: accessToken,
                                                          userUUID: userUUID,
                                                          body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PaymentMethods completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (POST) https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/payment-methods/{payment-method-uuid}/set-default
    func postPaymentMethodsSetDefault(publishableKey: String,
                                      accessToken: String,
                                      payType: String,
                                      paymentMethodUUID: String,
                                      userUUID: String,
                                      baseURLString: String,
                                      completion: @escaping (Result<PaymentsRequest.Post.PaymentMethodsSetDefault.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PostPaymentMethodsSetDefault(payType: payType)
        let request = PaymentsRequest.Post.PaymentMethodsSetDefault(publishableKey: publishableKey,
                                                                    accessToken: accessToken,
                                                                    paymentMethodUUID: paymentMethodUUID,
                                                                    userUUID: userUUID,
                                                                    body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PaymentMethodsSetDefault completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (POST) https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/payment-methods/{payment-method-uuid}/void
    func postPaymentMethodsVoid(publishableKey: String,
                                accessToken: String,
                                paymentMethodUUID: String,
                                grant: Body.CodeGrant,
                                userUUID: String,
                                baseURLString: String,
                                completion: @escaping (Result<PaymentsRequest.Post.PaymentMethodsVoid.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PostPaymentMethodsVoid(grant: grant)
        let request = PaymentsRequest.Post.PaymentMethodsVoid(publishableKey: publishableKey,
                                                              accessToken: accessToken,
                                                              paymentMethodUUID: paymentMethodUUID,
                                                              userUUID: userUUID,
                                                              body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PaymentMethodsVoid completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (POST) https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/payments
    func postPayments(publishableKey: String,
                      accessToken: String,
                      idempotencyKey: String,
                      grant: Body.CodeGrant,
                      tradeId: String,
                      paymentMethodUUID: String,
                      currency: String,
                      amount: Int,
                      instalment: Int? = nil,
                      userUUID: String,
                      baseURLString: String,
                      completion: @escaping (Result<PaymentsRequest.Post.Payments.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PostPayments(grant: grant,
                                            tradeId: tradeId,
                                            paymentMethodUuid: paymentMethodUUID,
                                            currency: currency,
                                            amount: amount,
                                            instalment: instalment)
        let request = PaymentsRequest.Post.Payments(publishableKey: publishableKey,
                                                    accessToken: accessToken,
                                                    idempotencyKey: idempotencyKey,
                                                    userUUID: userUUID,
                                                    body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PostPayments completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/transactions
    func getTransactions(publishableKey: String,
                         accessToken: String,
                         userUUID: String,
                         transIDType: String,
                         transID: String,
                         baseURLString: String,
                         completion: @escaping (Result<PaymentsRequest.Get.Transactions.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let request = PaymentsRequest.Get.Transactions(publishableKey: publishableKey,
                                                       accessToken: accessToken,
                                                       userUUID: userUUID,
                                                       transIDType: transIDType,
                                                       transID: transID)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("GetTransactions completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/recommendations
    func getRecommendations(publishableKey: String,
                            accessToken: String,
                            userUUID: String,
                            transactionType: String,
                            source: String,
                            baseURLString: String,
                            completion: @escaping (Result<PaymentsRequest.Get.Recommendations.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let request = PaymentsRequest.Get.Recommendations(publishableKey: publishableKey,
                                                          accessToken: accessToken,
                                                          userUUID: userUUID,
                                                          transactionType: transactionType,
                                                          source: source)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("GetRecommendations completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (POST) https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/payment-codes
    func postPaymentCodes(publishableKey: String,
                          accessToken: String,
                          idempotencyKey: String,
                          grant: Body.CodeGrant,
                          paymentMethodUUID: String,
                          userUUID: String,
                          baseURLString: String,
                          completion: @escaping (Result<PaymentsRequest.Post.PaymentCodes.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PostPaymentCodes(grant: grant,
                                                paymentMethodUuid: paymentMethodUUID)
        let request = PaymentsRequest.Post.PaymentCodes(publishableKey: publishableKey,
                                                        accessToken: accessToken,
                                                        idempotencyKey: idempotencyKey,
                                                        userUUID: userUUID,
                                                        body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PostPaymentCodes completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (POST) https://checkout.payments.qa.91dev.tw/api/wallet/users/{user-uuid}/stored-values
    func postStoredValues(publishableKey: String,
                          accessToken: String,
                          idempotencyKey: String,
                          target: String,
                          payFrom: String,
                          amount: Int,
                          currency: String,
                          grant: Body.CodeGrant,
                          userUUID: String,
                          baseURLString: String,
                          completion: @escaping (Result<PaymentsRequest.Post.StoredValues.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PostStoredValues(target: target,
                                                payFrom: payFrom,
                                                amount: amount,
                                                currency: currency,
                                                grant: grant)
        let request = PaymentsRequest.Post.StoredValues(publishableKey: publishableKey,
                                                        accessToken: accessToken,
                                                        idempotencyKey: idempotencyKey,
                                                        userUUID: userUUID,
                                                        body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PostStoredValues completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (POST) https://checkout.payments.qa.91dev.tw/api/wallet/login-intents
    func postLoginIntents(publishableKey: String,
                          multipassToken: String,
                          baseURLString: String,
                          completion: @escaping (Result<PaymentsRequest.Post.LoginIntents.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        // Build request
        let requestBody = Body.PostLoginIntents(multipassToken: multipassToken)
        let request = PaymentsRequest.Post.LoginIntents(publishableKey: publishableKey, body: requestBody.toDictionary)
        
        // Perform request
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PostLoginIntents completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
    
    /// API example: (POST) https://checkout.payments.qa.91dev.tw/api/wallet/login-intents/{login-intent-id}
    func postVerifyLoginIntents(publishableKey: String,
                                loginIntentsId: String,
                                code: String,
                                baseURLString: String,
                                completion: @escaping (Result<PaymentsRequest.Post.VerifyLoginIntents.ReturnType, PaymentsNetworkRequestError>) -> Void) {
        let requestBody = Body.PostVerifyLoginIntents(code: code)
        let request = PaymentsRequest.Post.VerifyLoginIntents(publishableKey: publishableKey,
                                                              loginIntentId: loginIntentsId,
                                                              body: requestBody.toDictionary)
        
        let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))
        let apiClient = PaymentsAPIClient(baseURLString: baseURLString, networkDispatcher: dispatcher)
        
        apiClient.dispatch(request)
            .sink { result in
                switch result {
                case .finished:
                    print("PostVerifyLoginIntent completed with: \(result.self)")
                case .failure(let error):
                    completion(.failure(error))
                }
            } receiveValue: { value in
                completion(.success(value))
            }.store(in: &self.cancellables)
    }
}

fileprivate extension URLSession {
    static var tenSecondsTimeout: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: configuration)
        return session
    }
}
