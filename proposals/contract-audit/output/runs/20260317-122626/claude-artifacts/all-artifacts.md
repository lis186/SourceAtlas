工作目錄中沒有找到 Swift 檔案。`PaymentsNetworkDispatcher.swift` 未提供——錨定合約 #1-#8 引用該檔案，我將根據 `PaymentsNetworkManager.swift` 中的使用方式推斷其合約，並標記為證據不完整。

以下是基於所提供程式碼的完整合約稽核。

---

# Artifact 1: Contract Spec Document

## F1: Tell the Story

```
STORY: 此模組是一個支付網路門面（Facade），負責 (1) 將業務參數轉換為網路請求、(2) 透過 Combine pipeline 分派請求並轉發結果、(3) 管理訂閱生命週期。

LIES:
- 「管理訂閱生命週期」：實際上 cancellables 只增不減，singleton 永不釋放，無任何取消機制——重構時若改為非 singleton 或加入取消邏輯，所有 25 個方法都受影響
- 「分派請求」：每個方法都建立新的 dispatcher + client 實例，看似獨立但共享同一個 cancellables Set，且 .store(in:) 在無鎖保護下從多執行緒寫入——重構時必須處理執行緒安全
- 「轉發結果」：sink 的 completion handler 在未指定的背景執行緒上被呼叫，呼叫端必須自行切回主執行緒——重構若改變 scheduler 會破壞所有呼叫者的假設
```

## F2: Scratch Refactoring

```
SCRATCH_REFACTORING:
1. 將 25 個方法的共用模式提取為泛型方法 performRequest<T>(request:session:completion:)
   REVEALS: S-001 (cancellables 執行緒安全)、C-001 (無取消機制)、N-001 (sink callback 執行緒合約)——因為集中化後必須決定統一的執行緒策略和取消策略

2. 將 Combine sink+completion 模式替換為 async/await
   REVEALS: N-002 (cancellables 累積問題消失但引入 Task 取消語義)、P-001 (Result 型別傳播鏈改變)、E-001 (錯誤傳播從 completion(.failure) 變為 throw)

3. 將 singleton 改為可注入的依賴
   REVEALS: D-001 (singleton 依賴合約)、C-002 (singleton 不釋放 = cancellables 永不清理)、D-002 (URLSession 配置選擇邏輯需要外部化)
```

---

## Contracts

### S-001: cancellables Set 並行寫入無鎖保護

```
Trigger:      任何方法的 .store(in: &self.cancellables) 執行時
Input:        AnyCancellable 實例
Output:       Set<AnyCancellable> 被 mutate
Condition:    多個方法從不同執行緒同時呼叫時（singleton 共享狀態）
Ordering:     在 sink subscription 建立之後立即執行
Risk:         CRITICAL -- Set 是 value type，&self.cancellables 是 inout 存取，無任何同步保護。多執行緒並行呼叫會導致 data race / crash
Evidence:     PaymentsNetworkManager.swift:49 -- `.store(in: &self.cancellables)`（所有 25 個方法皆相同）
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

### S-002: sink callback 執行緒未指定

```
Trigger:      apiClient.dispatch(request) 的 publisher 發送值或完成時
Input:        Publisher 的上游 scheduler（由 PaymentsNetworkDispatcher 決定）
Output:       completion handler 在非主執行緒上被呼叫
Condition:    永遠（無 .receive(on:) 指定）
Ordering:     receiveValue 先於 .finished；.failure 獨立於 receiveValue
Risk:         HIGH -- 所有呼叫者必須自行 dispatch 到主執行緒做 UI 更新。若重構加入 .receive(on: DispatchQueue.main)，會改變所有呼叫者的執行緒假設
Evidence:     PaymentsNetworkManager.swift:40-48 -- sink closure 無 scheduler 指定
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

### N-001: Combine sink completion/receiveValue 回呼模式

```
Trigger:      apiClient.dispatch(request) 發送值或錯誤時
Input:        Publisher<ReturnType, PaymentsNetworkRequestError>
Output:       completion(.success(value)) 在 receiveValue 中呼叫；completion(.failure(error)) 在 .failure 中呼叫；.finished 僅 print
Condition:    永遠——所有 25 個方法皆遵循此模式
Ordering:     成功路徑：receiveValue（呼叫 completion(.success)）→ .finished（僅 print）；失敗路徑：.failure（呼叫 completion(.failure)）
Risk:         HIGH -- 如果 publisher 發出多個值，completion(.success) 會被呼叫多次。呼叫者是否預期只收到一次？此合約假設 publisher 是 single-value publisher
Evidence:     PaymentsNetworkManager.swift:40-48 -- sink { result in ... } receiveValue: { value in completion(.success(value)) }
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

### N-002: Cancellables 無限累積

```
Trigger:      每次任何方法被呼叫時
Input:        新建的 AnyCancellable
Output:       cancellables Set 持續增長，已完成的 subscription 的 AnyCancellable 物件仍留在 Set 中
Condition:    永遠——singleton 永不 deinit，Set 永不被清空
Ordering:     在每次方法呼叫結束時 .store(in:)
Risk:         MEDIUM -- 記憶體洩漏。每次 API 呼叫增加一個 AnyCancellable 物件。高頻呼叫場景下可能造成記憶體壓力
Evidence:     PaymentsNetworkManager.swift:19 -- `private var cancellables: Set<AnyCancellable> = []`；所有方法的 `.store(in: &self.cancellables)`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

### N-003: NotificationCenter.post（PaymentsNetworkDispatcher 錨點）

```
Trigger:      PaymentsNetworkDispatcher 內部條件觸發時
Input:        未知（PaymentsNetworkDispatcher.swift 未提供）
Output:       NotificationCenter 通知發送
Condition:    未知
Ordering:     未知
Risk:         HIGH -- 無法從 Manager 推斷確切行為，但所有 25 個方法都使用 dispatcher，因此都可能觸發此通知
Evidence:     錨點 #3: PaymentsNetworkDispatcher.swift:362（檔案未提供）
Scope:        module
Seam_Type:    none
Pinch_Point:  false
```

### D-001: Singleton 模式

```
Trigger:      外部程式碼存取 PaymentsNetworkManager.shared
Input:        無
Output:       全域共享的單一實例，所有呼叫者共用 cancellables Set
Condition:    永遠
Ordering:     首次存取時 lazy 初始化（Swift static let 保證執行緒安全初始化）
Risk:         HIGH -- singleton 使得 (1) 測試困難（無法注入 mock）(2) cancellables 共享導致潛在的執行緒安全問題 (3) 無法在不同場景使用不同配置
Evidence:     PaymentsNetworkManager.swift:16 -- `public static let shared = PaymentsNetworkManager()`
Scope:        class
Seam_Type:    object
Pinch_Point:  true
```

### D-002: URLSession 配置分歧

```
Trigger:      方法建立 PaymentsNetworkDispatcher 時選擇 URLSession
Input:        無外部輸入——硬編碼在每個方法中
Output:       multipassLogin / getThemeConfiguration / getSettings 使用 10 秒超時；其餘 22 個方法使用預設 60 秒超時
Condition:    由方法身份決定，非動態條件
Ordering:     在 dispatcher 建立時決定
Risk:         MEDIUM -- 超時配置分散在 25 個方法中，無統一管理。重構時容易遺漏某個方法的特殊超時需求
Evidence:     PaymentsNetworkManager.swift:38 -- `PaymentsNetworkDispatcher(urlSession: .tenSecondsTimeout)`；PaymentsNetworkManager.swift:120 -- `PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))`
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

### D-003: PaymentsNetworkDispatcher 與 PaymentsAPIClient 每次重建

```
Trigger:      每次方法呼叫
Input:        URLSession 實例、baseURLString
Output:       新建的 dispatcher 和 client 實例（不復用）
Condition:    永遠
Ordering:     在 request body 建立之後、dispatch 之前
Risk:         LOW -- 設計選擇，每次建立新實例避免共享狀態問題。但若 dispatcher 內部有初始化成本（如 anchor #1-#2 的 DispatchQueue 建立），則有效能影響
Evidence:     PaymentsNetworkManager.swift:37-38 -- `let dispatcher = PaymentsNetworkDispatcher(...)` `let apiClient = PaymentsAPIClient(...)`
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

### D-004: PaymentsRequest 型別系統依賴

```
Trigger:      每次方法建立 request 物件時
Input:        publishableKey、accessToken、各種業務參數
Output:       型別化的 request 物件（如 PaymentsRequest.Post.MultipassLogin）
Condition:    編譯期型別約束
Ordering:     在 dispatcher 建立之前
Risk:         LOW -- 編譯器保證型別安全，但 ReturnType 的 Codable conformance 是 runtime 合約（參見 E-002）
Evidence:     PaymentsNetworkManager.swift:35 -- `let request = PaymentsRequest.Post.MultipassLogin(...)`
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

### E-001: 錯誤直接轉發，無轉換

```
Trigger:      publisher 的 .failure completion
Input:        PaymentsNetworkRequestError
Output:       completion(.failure(error))——原封不動傳給呼叫者
Condition:    永遠
Ordering:     publisher failure 時立即執行
Risk:         LOW -- 簡單且一致。但若重構需要在此層加入錯誤轉換（如 retry 邏輯），所有 25 個方法都需修改
Evidence:     PaymentsNetworkManager.swift:45 -- `completion(.failure(error))`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

### E-002: Codable 解碼隱含於 ReturnType（錨點 #8 推斷）

```
Trigger:      apiClient.dispatch(request) 解析 response 時
Input:        HTTP response body (Data)
Output:       解碼為 request 的 ReturnType（Codable）或拋出 DecodingError
Condition:    response JSON 結構必須完全匹配 ReturnType 的 Codable 定義
Ordering:     在 sink receiveValue 之前（由 PaymentsAPIClient 內部處理）
Risk:         HIGH -- 後端 API 任何欄位變更都可能導致整個解碼失敗。此合約跨越 Manager/Client/Model 三層，但錯誤會被包裝為 PaymentsNetworkRequestError 傳到 Manager
Evidence:     錨點 #8: PaymentsNetworkDispatcher.swift:119（Codable）；推斷自 dispatch(request) 的泛型回傳型別
Scope:        module
Seam_Type:    none
Pinch_Point:  false
```

### C-001: 無取消機制

```
Trigger:      N/A——不存在取消觸發點
Input:        N/A
Output:       一旦方法被呼叫，請求無法被取消
Condition:    永遠
Ordering:     N/A
Risk:         MEDIUM -- 使用者離開頁面後，網路請求仍會完成並呼叫 completion handler，可能導致對已釋放物件的操作（雖然 weak self 不在 Manager 而在呼叫端）
Evidence:     PaymentsNetworkManager.swift:26-50 -- 方法簽名無回傳 cancellation token；無 cancel 方法
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

### M-001: Body.toDictionary 轉換

```
Trigger:      每個有 request body 的方法呼叫時
Input:        強型別 Body struct（如 Body.Multipass、Body.PasscodesSet）
Output:       [String: Any] dictionary，作為 request body 傳給 PaymentsRequest
Condition:    永遠（有 body 的方法）
Ordering:     在 request 物件建立之前
Risk:         LOW -- 型別安全的結構轉為非型別安全的 dictionary，但這是 PaymentsRequest 的介面要求
Evidence:     PaymentsNetworkManager.swift:34 -- `requestBody.toDictionary`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### P-001: Result 型別傳播鏈

```
Trigger:      publisher 發出值時
Input:        Publisher<ReturnType, PaymentsNetworkRequestError>
Output:       completion: (Result<ReturnType, PaymentsNetworkRequestError>) -> Void
Condition:    永遠
Ordering:     receiveValue → completion(.success)
Risk:         LOW -- 直通傳播，無中間轉換。但 ReturnType 由 PaymentsRequest 的 associated type 決定，變更 request 型別會改變回傳型別
Evidence:     PaymentsNetworkManager.swift:47 -- `completion(.success(value))`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

### P-002: Idempotency Key 直通傳播

```
Trigger:      postPayments / postPaymentCodes / postStoredValues 呼叫時
Input:        idempotencyKey: String 參數
Output:       透過 PaymentsRequest 傳至 HTTP header 或 body（由 request 物件決定）
Condition:    僅上述三個方法
Ordering:     參數 → PaymentsRequest init → HTTP request
Risk:         HIGH -- 冪等性是支付系統的關鍵安全合約。若 idempotencyKey 未正確傳遞到 HTTP 層，可能導致重複扣款
Evidence:     PaymentsNetworkManager.swift:590 -- `PaymentsRequest.Post.Payments(... idempotencyKey: idempotencyKey ...)`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### D-005: tenSecondsTimeout URLSession 每次重建

```
Trigger:      multipassLogin / getThemeConfiguration / getSettings 呼叫時
Input:        無
Output:       每次呼叫都建立新的 URLSession 實例（configuration.timeoutIntervalForRequest = 10）
Condition:    僅上述三個方法
Ordering:     在 dispatcher 建立時
Risk:         LOW -- URLSession 建立有一定成本但不嚴重。然而每次建立的 session 未被 invalidate，可能有資源洩漏
Evidence:     PaymentsNetworkManager.swift:797-803 -- `static var tenSecondsTimeout: URLSession { ... }`（computed property，每次存取都建立新實例）
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

### 錨點 #1 (dispatch_sync) 和 #2 (DispatchQueue_create) 的註記

這兩個錨點位於 `PaymentsNetworkDispatcher.swift`（行 86, 96），該檔案未提供。從 Manager 的使用方式推斷：
- 每個方法都建立新的 `PaymentsNetworkDispatcher` 實例
- 如果 dispatcher 內部使用 `dispatch_sync` + serial queue，則每次建立新 queue 避免了跨方法的鎖競爭
- 但 singleton 的 cancellables 寫入仍然不安全（S-001）

**需要 PaymentsNetworkDispatcher.swift 才能完成這兩個錨點的合約。**

### 錨點 #5 (if_conditional) 和 #6 (throws_decl) 和 #7 (do_catch) 的註記

均位於 `PaymentsNetworkDispatcher.swift`，無法直接稽核。推斷這些與 HTTP response 解析和錯誤處理相關，最終表現為 publisher 的 `.failure` 或 `receiveValue`。

---

## F3: Effect Propagation Tracing

由於 25 個方法結構幾乎相同，以代表性方法展示：

```
EFFECT_TRACE: func multipassLogin(publishableKey:multipassToken:verified:baseURLString:completion:)
  RETURN:  void（透過 completion handler 非同步回傳）
  MUTATES: self.cancellables（追加 AnyCancellable）
  GLOBAL:  none（但 dispatcher/client 可能有副作用——見 N-003）
  DEPTH:   3（Manager → APIClient.dispatch → NetworkDispatcher → URLSession → callback 鏈回到 completion）

EFFECT_TRACE: func postPayments(publishableKey:accessToken:idempotencyKey:grant:tradeId:paymentMethodUUID:currency:amount:instalment:userUUID:baseURLString:completion:)
  RETURN:  void（透過 completion handler）
  MUTATES: self.cancellables
  GLOBAL:  none in Manager（但 idempotencyKey 影響伺服器端冪等行為）
  DEPTH:   3

EFFECT_TRACE: [所有其他 23 個方法]
  RETURN:  void（透過 completion handler）
  MUTATES: self.cancellables
  GLOBAL:  none in Manager
  DEPTH:   3
```

---

## Risk Matrix

| ID | Risk | Description | Refactoring Impact |
|----|------|-------------|-------------------|
| S-001 | CRITICAL | cancellables Set 並行寫入無鎖保護 | 必須在重構中加入同步機制或改用 actor |
| S-002 | HIGH | sink callback 執行緒未指定 | 加入 .receive(on:) 會改變所有呼叫者行為 |
| N-001 | HIGH | sink completion/receiveValue 回呼模式 | 改為 async/await 需重寫所有呼叫端 |
| N-003 | HIGH | NotificationCenter.post（需 Dispatcher 檔案確認） | 需要確認通知內容及觀察者 |
| D-001 | HIGH | Singleton 模式阻礙測試和配置彈性 | 改為依賴注入影響所有呼叫端 |
| E-002 | HIGH | Codable 解碼為全有或全無 | 後端變更可能導致 runtime 失敗 |
| P-002 | HIGH | Idempotency key 直通——支付安全關鍵 | 必須驗證 key 確實到達 HTTP 層 |
| N-002 | MEDIUM | Cancellables 無限累積 | 需要清理策略 |
| C-001 | MEDIUM | 無取消機制 | 需要設計取消 API |
| D-002 | MEDIUM | URLSession 配置分散在各方法中 | 需統一管理 |
| M-001 | LOW | Body.toDictionary 轉換 | 若改為 Encodable 需修改所有 Body 型別 |
| D-003 | LOW | Dispatcher/Client 每次重建 | 可考慮復用但非必要 |
| D-004 | LOW | PaymentsRequest 型別系統依賴 | 編譯器保護 |
| D-005 | LOW | tenSecondsTimeout 每次重建 URLSession | 可改為 static stored property |
| P-001 | LOW | Result 直通傳播 | 穩定 |
| E-001 | LOW | 錯誤直接轉發 | 穩定 |

---

# Artifact 2: Verification Scripts

## 2a. grep 驗證腳本

```bash
#!/bin/bash
# verify-contracts-PaymentsNetworkManager.sh
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

TARGET="PaymentsNetworkManager.swift"

# S-001: cancellables Set concurrent mutation
assert_match "S-001" 'store(in: &self\.cancellables)' "$TARGET"

# S-002: No .receive(on:) before sink
assert_match "S-002" '\.sink { result in' "$TARGET"

# N-001: sink completion pattern (print in .finished)
assert_match "N-001" 'case .finished:' "$TARGET"

# N-002: cancellables declaration
assert_match "N-002" 'private var cancellables: Set<AnyCancellable>' "$TARGET"

# D-001: Singleton
assert_match "D-001" 'public static let shared = PaymentsNetworkManager()' "$TARGET"

# D-002a: tenSecondsTimeout usage
assert_match "D-002a" 'urlSession: .tenSecondsTimeout' "$TARGET"

# D-002b: default URLSession usage
assert_match "D-002b" 'urlSession: URLSession(configuration: .default)' "$TARGET"

# D-003: Dispatcher instantiation
assert_match "D-003" 'let dispatcher = PaymentsNetworkDispatcher' "$TARGET"

# D-004: PaymentsRequest type usage
assert_match "D-004" 'PaymentsRequest\.' "$TARGET"

# D-005: tenSecondsTimeout computed property
assert_match "D-005" 'static var tenSecondsTimeout: URLSession' "$TARGET"

# E-001: Error forwarding pattern
assert_match "E-001" 'completion(.failure(error))' "$TARGET"

# C-001: No cancellation (verify no cancel method exists)
# Note: This is an absence check -- grep should NOT find a cancel method
if grep -qn 'func cancel' "$TARGET"; then
    echo "INFO [C-001] -- cancel method found, contract may be obsolete"
else
    echo "PASS [C-001] -- no cancel method (contract confirmed)"; ((PASS++))
fi

# M-001: toDictionary conversion
assert_match "M-001" '\.toDictionary' "$TARGET"

# P-001: completion(.success(value)) pattern
assert_match "P-001" 'completion(.success(value))' "$TARGET"

# P-002: idempotencyKey parameter
assert_match "P-002" 'idempotencyKey:' "$TARGET"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
```

## 2b. ast-grep 規則檔

```yaml
# File: .ast-grep/rules/PaymentsNetworkManager/S-001-cancellables-store.yml
id: S-001-cancellables-store
message: "S-001: cancellables Set concurrent write -- .store(in:) must be present"
severity: error
language: Swift
rule:
  pattern: |
    .store(in: &self.cancellables)
note: |
  Contract source: PaymentsNetworkManager.swift -- all 25 methods
  Refactoring requirement: 重構後必須保證 cancellable 的儲存機制是執行緒安全的
```

```yaml
# File: .ast-grep/rules/PaymentsNetworkManager/N-001-sink-pattern.yml
id: N-001-sink-completion-pattern
message: "N-001: Combine sink completion/receiveValue callback pattern must be present"
severity: error
language: Swift
rule:
  pattern: |
    $CLIENT.dispatch($REQ)
        .sink { $RESULT in
            $$$
        } receiveValue: { $VALUE in
            $$$
        }
note: |
  Contract source: PaymentsNetworkManager.swift:40-48
  Refactoring requirement: 成功值必須透過 receiveValue 傳遞，錯誤必須透過 .failure case 傳遞
```

```yaml
# File: .ast-grep/rules/PaymentsNetworkManager/D-001-singleton.yml
id: D-001-singleton
message: "D-001: Singleton pattern must be present"
severity: error
language: Swift
rule:
  pattern: |
    public static let shared = PaymentsNetworkManager()
note: |
  Contract source: PaymentsNetworkManager.swift:16
  Refactoring requirement: 若移除 singleton，必須提供替代的依賴注入機制
```

```yaml
# File: .ast-grep/rules/PaymentsNetworkManager/E-001-error-forward.yml
id: E-001-error-forward
message: "E-001: Error forwarding pattern -- completion(.failure(error)) must be present in sink"
severity: error
language: Swift
rule:
  pattern: |
    completion(.failure($ERROR))
note: |
  Contract source: PaymentsNetworkManager.swift:45
  Refactoring requirement: 所有網路錯誤必須傳遞給呼叫者
```

```yaml
# File: .ast-grep/rules/PaymentsNetworkManager/P-002-idempotency-key.yml
id: P-002-idempotency-key
message: "P-002: idempotencyKey must be passed to PaymentsRequest for payment operations"
severity: error
language: Swift
rule:
  pattern: |
    $REQUEST($$$, idempotencyKey: $KEY, $$$)
note: |
  Contract source: PaymentsNetworkManager.swift:590
  Refactoring requirement: 支付相關請求必須攜帶 idempotencyKey 以確保冪等性
```

```yaml
# File: .ast-grep/rules/PaymentsNetworkManager/D-002-ten-seconds-timeout.yml
id: D-002-ten-seconds-timeout
message: "D-002: tenSecondsTimeout URLSession variant must exist"
severity: error
language: Swift
rule:
  pattern: |
    static var tenSecondsTimeout: URLSession {
        $$$
    }
note: |
  Contract source: PaymentsNetworkManager.swift:797-803
  Refactoring requirement: multipassLogin / getThemeConfiguration / getSettings 必須使用 10 秒超時
```

> **Note:** S-002（callback 執行緒合約）和 C-001（無取消機制）是**缺失性合約**（absence contracts），無法用 ast-grep pattern 驗證——標記為 manual review。

---

# Artifact 3: Coverage Table

| ID | Title | Verified By | File / Assertion |
|----|-------|-------------|-----------------|
| S-001 | cancellables 並行寫入無鎖保護 | grep + ast-grep | `verify-contracts-PaymentsNetworkManager.sh` line "S-001" / `S-001-cancellables-store.yml` |
| S-002 | sink callback 執行緒未指定 | manual review | 須檢查所有 `.sink` 前是否缺少 `.receive(on:)`——缺失性合約無法用 pattern 表達 |
| N-001 | sink completion/receiveValue 模式 | grep + ast-grep | `verify-contracts-PaymentsNetworkManager.sh` line "N-001" / `N-001-sink-pattern.yml` |
| N-002 | Cancellables 無限累積 | grep | `verify-contracts-PaymentsNetworkManager.sh` line "N-002" |
| N-003 | NotificationCenter.post | manual review | 需要 PaymentsNetworkDispatcher.swift 才能驗證 |
| D-001 | Singleton 模式 | grep + ast-grep | `verify-contracts-PaymentsNetworkManager.sh` line "D-001" / `D-001-singleton.yml` |
| D-002 | URLSession 配置分歧 | grep + ast-grep | `verify-contracts-PaymentsNetworkManager.sh` line "D-002a", "D-002b" / `D-002-ten-seconds-timeout.yml` |
| D-003 | Dispatcher/Client 每次重建 | grep | `verify-contracts-PaymentsNetworkManager.sh` line "D-003" |
| D-004 | PaymentsRequest 型別依賴 | grep | `verify-contracts-PaymentsNetworkManager.sh` line "D-004" |
| D-005 | tenSecondsTimeout 每次重建 | grep | `verify-contracts-PaymentsNetworkManager.sh` line "D-005" |
| E-001 | 錯誤直接轉發 | grep + ast-grep | `verify-contracts-PaymentsNetworkManager.sh` line "E-001" / `E-001-error-forward.yml` |
| E-002 | Codable 解碼隱含合約 | manual review | 需要檢查 ReturnType 的 Codable conformance 及後端 API schema |
| C-001 | 無取消機制 | grep (absence) | `verify-contracts-PaymentsNetworkManager.sh` line "C-001"——驗證 cancel 方法不存在 |
| M-001 | Body.toDictionary 轉換 | grep | `verify-contracts-PaymentsNetworkManager.sh` line "M-001" |
| P-001 | Result 型別傳播 | grep | `verify-contracts-PaymentsNetworkManager.sh` line "P-001" |
| P-002 | Idempotency key 傳播 | grep + ast-grep | `verify-contracts-PaymentsNetworkManager.sh` line "P-002" / `P-002-idempotency-key.yml` |

---

# Artifact 4: Line Attribution Table

| Line(s) | Classification | Contract ID(s) |
|---------|---------------|----------------|
| 1-8 | SKIP | -- (file header comment) |
| 9-10 | INFRA | -- (import statements) |
| 11 | SKIP | -- (blank) |
| 12 | INFRA | -- (class declaration) |
| 13 | SKIP | -- (blank) |
| 14-15 | SKIP | -- (comment) |
| 16 | CONTRACT | D-001 |
| 17-18 | SKIP | -- (comment) |
| 19 | CONTRACT | S-001, N-002 |
| 20 | SKIP | -- (blank) |
| 21 | INFRA | -- (closing brace) |
| 22 | SKIP | -- (blank) |
| 23-24 | SKIP | -- (MARK comment) |
| 25 | INFRA | -- (extension declaration) |
| 26 | SKIP | -- (blank) |
| 27-29 | SKIP | -- (doc comment) |
| 30-34 | INFRA | -- (method signature) |
| 35 | CONTRACT | M-001 |
| 36 | CONTRACT | D-004 |
| 37 | SKIP | -- (blank) |
| 38 | INFRA | -- (comment) |
| 39 | CONTRACT | D-002, D-003 |
| 40 | CONTRACT | D-003 |
| 41 | SKIP | -- (blank) |
| 42 | CONTRACT | N-001, S-002 |
| 43-44 | CONTRACT | N-001 |
| 45 | SKIP | -- (print statement) |
| 46-47 | CONTRACT | E-001 |
| 48 | INFRA | -- (closing brace) |
| 49 | CONTRACT | P-001 |
| 50 | CONTRACT | S-001, N-002 |
| 51 | INFRA | -- (closing brace) |
| 52 | SKIP | -- (blank) |
| 53-54 | SKIP | -- (doc comment) |
| 55-57 | INFRA | -- (method signature) |
| 58 | INFRA | -- (comment) |
| 59 | CONTRACT | D-004 |
| 60 | SKIP | -- (blank) |
| 61 | INFRA | -- (comment) |
| 62 | CONTRACT | D-002, D-003 |
| 63 | CONTRACT | D-003 |
| 64 | SKIP | -- (blank) |
| 65-70 | CONTRACT | N-001, S-002, E-001 |
| 71 | CONTRACT | P-001 |
| 72 | CONTRACT | S-001, N-002 |
| 73 | INFRA | -- (closing brace) |
| 74 | SKIP | -- (blank) |
| 75-76 | SKIP | -- (doc comment) |
| 77-79 | INFRA | -- (method signature) |
| 80 | INFRA | -- (comment) |
| 81 | CONTRACT | D-004 |
| 82 | SKIP | -- (blank) |
| 83 | INFRA | -- (comment) |
| 84 | CONTRACT | D-002, D-003 |
| 85 | CONTRACT | D-003 |
| 86 | SKIP | -- (blank) |
| 87-92 | CONTRACT | N-001, S-002, E-001 |
| 93 | CONTRACT | P-001 |
| 94 | CONTRACT | S-001, N-002 |
| 95 | INFRA | -- (closing brace) |
| 96 | SKIP | -- (blank) |
| 97-98 | SKIP | -- (doc comment) |
| 99-106 | INFRA | -- (method signature) |
| 107 | INFRA | -- (comment) |
| 108 | CONTRACT | M-001 |
| 109-112 | CONTRACT | D-004 |
| 113 | SKIP | -- (blank) |
| 114 | INFRA | -- (comment) |
| 115 | CONTRACT | D-002, D-003 |
| 116 | CONTRACT | D-003 |
| 117 | SKIP | -- (blank) |
| 118-123 | CONTRACT | N-001, S-002, E-001 |
| 124-125 | CONTRACT | P-001 |
| 126 | CONTRACT | S-001, N-002 |
| 127 | INFRA | -- (closing brace) |
| 128 | SKIP | -- (blank) |
| 129-130 | SKIP | -- (doc comment) |
| 131-139 | INFRA | -- (method signature) |
| 140 | INFRA | -- (comment) |
| 141 | CONTRACT | M-001 |
| 142-145 | CONTRACT | D-004 |
| 146 | SKIP | -- (blank) |
| 147 | INFRA | -- (comment) |
| 148 | CONTRACT | D-002, D-003 |
| 149 | CONTRACT | D-003 |
| 150 | SKIP | -- (blank) |
| 151-156 | CONTRACT | N-001, S-002, E-001 |
| 157-158 | CONTRACT | P-001 |
| 159 | CONTRACT | S-001, N-002 |
| 160 | INFRA | -- (closing brace) |
| 161 | SKIP | -- (blank) |
| 162-163 | SKIP | -- (doc comment) |
| 164-172 | INFRA | -- (method signature) |
| 173 | INFRA | -- (comment) |
| 174 | CONTRACT | M-001 |
| 175-178 | CONTRACT | D-004 |
| 179 | SKIP | -- (blank) |
| 180 | INFRA | -- (comment) |
| 181 | CONTRACT | D-002, D-003 |
| 182 | CONTRACT | D-003 |
| 183 | SKIP | -- (blank) |
| 184-189 | CONTRACT | N-001, S-002, E-001 |
| 190-191 | CONTRACT | P-001 |
| 192 | CONTRACT | S-001, N-002 |
| 193 | INFRA | -- (closing brace) |
| 194 | SKIP | -- (blank) |
| 195-196 | SKIP | -- (doc comment) |
| 197-201 | INFRA | -- (method signature) |
| 202 | INFRA | -- (comment) |
| 203 | CONTRACT | M-001 |
| 204-207 | CONTRACT | D-004 |
| 208 | SKIP | -- (blank) |
| 209 | INFRA | -- (comment) |
| 210 | CONTRACT | D-002, D-003 |
| 211 | CONTRACT | D-003 |
| 212 | SKIP | -- (blank) |
| 213-218 | CONTRACT | N-001, S-002, E-001 |
| 219-220 | CONTRACT | P-001 |
| 221 | CONTRACT | S-001, N-002 |
| 222 | INFRA | -- (closing brace) |
| 223 | SKIP | -- (blank) |
| 224-225 | SKIP | -- (doc comment) |
| 226-231 | INFRA | -- (method signature) |
| 232 | INFRA | -- (comment) |
| 233 | CONTRACT | M-001 |
| 234-237 | CONTRACT | D-004 |
| 238 | SKIP | -- (blank) |
| 239 | INFRA | -- (comment) |
| 240 | CONTRACT | D-002, D-003 |
| 241 | CONTRACT | D-003 |
| 242 | SKIP | -- (blank) |
| 243-248 | CONTRACT | N-001, S-002, E-001 |
| 249-250 | CONTRACT | P-001 |
| 251 | CONTRACT | S-001, N-002 |
| 252 | INFRA | -- (closing brace) |
| 253 | SKIP | -- (blank) |
| 254-255 | SKIP | -- (doc comment) |
| 256-262 | INFRA | -- (method signature) |
| 263 | INFRA | -- (comment) |
| 264 | CONTRACT | M-001 |
| 265-268 | CONTRACT | D-004 |
| 269 | SKIP | -- (blank) |
| 270 | INFRA | -- (comment) |
| 271 | CONTRACT | D-002, D-003 |
| 272 | CONTRACT | D-003 |
| 273 | SKIP | -- (blank) |
| 274-279 | CONTRACT | N-001, S-002, E-001 |
| 280-281 | CONTRACT | P-001 |
| 282 | CONTRACT | S-001, N-002 |
| 283 | INFRA | -- (closing brace) |
| 284 | SKIP | -- (blank) |
| 285-286 | SKIP | -- (doc comment) |
| 287-293 | INFRA | -- (method signature) |
| 294 | INFRA | -- (comment) |
| 295 | CONTRACT | M-001 |
| 296-299 | CONTRACT | D-004 |
| 300 | SKIP | -- (blank) |
| 301 | INFRA | -- (comment) |
| 302 | CONTRACT | D-002, D-003 |
| 303 | CONTRACT | D-003 |
| 304 | SKIP | -- (blank) |
| 305-310 | CONTRACT | N-001, S-002, E-001 |
| 311 | CONTRACT | P-001 |
| 312 | CONTRACT | S-001, N-002 |
| 313 | INFRA | -- (closing brace) |
| 314 | SKIP | -- (blank) |
| 315-316 | SKIP | -- (doc comment) |
| 317-321 | INFRA | -- (method signature) |
| 322 | INFRA | -- (comment) |
| 323 | CONTRACT | D-004 |
| 324 | SKIP | -- (blank) |
| 325 | INFRA | -- (comment) |
| 326 | CONTRACT | D-002, D-003 |
| 327 | CONTRACT | D-003 |
| 328 | SKIP | -- (blank) |
| 329-334 | CONTRACT | N-001, S-002, E-001 |
| 335 | CONTRACT | P-001 |
| 336 | CONTRACT | S-001, N-002 |
| 337 | INFRA | -- (closing brace) |
| 338 | SKIP | -- (blank) |
| 339-340 | SKIP | -- (doc comment) |
| 341-347 | INFRA | -- (method signature) |
| 348 | INFRA | -- (comment) |
| 349 | CONTRACT | M-001 |
| 350-353 | CONTRACT | D-004 |
| 354 | SKIP | -- (blank) |
| 355 | INFRA | -- (comment) |
| 356 | CONTRACT | D-002, D-003 |
| 357 | CONTRACT | D-003 |
| 358 | SKIP | -- (blank) |
| 359-364 | CONTRACT | N-001, S-002, E-001 |
| 365 | CONTRACT | P-001 |
| 366 | CONTRACT | S-001, N-002 |
| 367 | INFRA | -- (closing brace) |
| 368 | SKIP | -- (blank) |
| 369-372 | SKIP | -- (doc comment) |
| 373-381 | INFRA | -- (method signature) |
| 382 | INFRA | -- (comment) |
| 383-386 | CONTRACT | D-004 |
| 387 | SKIP | -- (blank) |
| 388 | INFRA | -- (comment) |
| 389 | CONTRACT | D-002, D-003 |
| 390 | CONTRACT | D-003 |
| 391 | SKIP | -- (blank) |
| 392-397 | CONTRACT | N-001, S-002, E-001 |
| 398 | CONTRACT | P-001 |
| 399 | CONTRACT | S-001, N-002 |
| 400 | INFRA | -- (closing brace) |
| 401 | SKIP | -- (blank) |
| 402-403 | SKIP | -- (TODO comment, doc comment) |
| 404-408 | INFRA | -- (method signature) |
| 409 | INFRA | -- (comment) |
| 410 | CONTRACT | M-001 |
| 411 | CONTRACT | D-004 |
| 412 | SKIP | -- (blank) |
| 413 | INFRA | -- (comment) |
| 414 | CONTRACT | D-002, D-003 |
| 415 | CONTRACT | D-003 |
| 416 | SKIP | -- (blank) |
| 417-422 | CONTRACT | N-001, S-002, E-001 |
| 423 | CONTRACT | P-001 |
| 424 | CONTRACT | S-001, N-002 |
| 425 | INFRA | -- (closing brace) |
| 426 | SKIP | -- (blank) |
| 427-428 | SKIP | -- (doc comment) |
| 429-435 | INFRA | -- (method signature) |
| 436 | INFRA | -- (comment) |
| 437-440 | CONTRACT | D-004 |
| 441 | SKIP | -- (blank) |
| 442 | INFRA | -- (comment) |
| 443 | CONTRACT | D-002, D-003 |
| 444 | CONTRACT | D-003 |
| 445 | SKIP | -- (blank) |
| 446-451 | CONTRACT | N-001, S-002, E-001 |
| 452 | CONTRACT | P-001 |
| 453 | CONTRACT | S-001, N-002 |
| 454 | INFRA | -- (closing brace) |
| 455 | SKIP | -- (blank) |
| 456-457 | SKIP | -- (doc comment) |
| 458-464 | INFRA | -- (method signature) |
| 465 | INFRA | -- (comment) |
| 466 | CONTRACT | M-001 |
| 467-470 | CONTRACT | D-004 |
| 471 | SKIP | -- (blank) |
| 472 | INFRA | -- (comment) |
| 473 | CONTRACT | D-002, D-003 |
| 474 | CONTRACT | D-003 |
| 475 | SKIP | -- (blank) |
| 476-481 | CONTRACT | N-001, S-002, E-001 |
| 482 | CONTRACT | P-001 |
| 483 | CONTRACT | S-001, N-002 |
| 484 | INFRA | -- (closing brace) |
| 485 | SKIP | -- (blank) |
| 486-487 | SKIP | -- (doc comment) |
| 488-495 | INFRA | -- (method signature) |
| 496 | INFRA | -- (comment) |
| 497 | CONTRACT | M-001 |
| 498-501 | CONTRACT | D-004 |
| 502 | SKIP | -- (blank) |
| 503 | INFRA | -- (comment) |
| 504 | CONTRACT | D-002, D-003 |
| 505 | CONTRACT | D-003 |
| 506 | SKIP | -- (blank) |
| 507-512 | CONTRACT | N-001, S-002, E-001 |
| 513 | CONTRACT | P-001 |
| 514 | CONTRACT | S-001, N-002 |
| 515 | INFRA | -- (closing brace) |
| 516 | SKIP | -- (blank) |
| 517-518 | SKIP | -- (doc comment) |
| 519-527 | INFRA | -- (method signature) |
| 528 | INFRA | -- (comment) |
| 529 | CONTRACT | M-001 |
| 530-534 | CONTRACT | D-004 |
| 535 | SKIP | -- (blank) |
| 536 | INFRA | -- (comment) |
| 537 | CONTRACT | D-002, D-003 |
| 538 | CONTRACT | D-003 |
| 539 | SKIP | -- (blank) |
| 540-545 | CONTRACT | N-001, S-002, E-001 |
| 546 | CONTRACT | P-001 |
| 547 | CONTRACT | S-001, N-002 |
| 548 | INFRA | -- (closing brace) |
| 549 | SKIP | -- (blank) |
| 550-551 | SKIP | -- (doc comment) |
| 552-564 | INFRA | -- (method signature) |
| 565 | INFRA | -- (comment) |
| 566-572 | CONTRACT | M-001 |
| 573-577 | CONTRACT | D-004, P-002 |
| 578 | SKIP | -- (blank) |
| 579 | INFRA | -- (comment) |
| 580 | CONTRACT | D-002, D-003 |
| 581 | CONTRACT | D-003 |
| 582 | SKIP | -- (blank) |
| 583-588 | CONTRACT | N-001, S-002, E-001 |
| 589 | CONTRACT | P-001 |
| 590 | CONTRACT | S-001, N-002 |
| 591 | INFRA | -- (closing brace) |
| 592 | SKIP | -- (blank) |
| 593-594 | SKIP | -- (doc comment) |
| 595-601 | INFRA | -- (method signature) |
| 602 | INFRA | -- (comment) |
| 603-607 | CONTRACT | D-004 |
| 608 | SKIP | -- (blank) |
| 609 | INFRA | -- (comment) |
| 610 | CONTRACT | D-002, D-003 |
| 611 | CONTRACT | D-003 |
| 612 | SKIP | -- (blank) |
| 613-618 | CONTRACT | N-001, S-002, E-001 |
| 619 | CONTRACT | P-001 |
| 620 | CONTRACT | S-001, N-002 |
| 621 | INFRA | -- (closing brace) |
| 622 | SKIP | -- (blank) |
| 623-624 | SKIP | -- (doc comment) |
| 625-632 | INFRA | -- (method signature) |
| 633 | INFRA | -- (comment) |
| 634-637 | CONTRACT | D-004 |
| 638 | SKIP | -- (blank) |
| 639 | INFRA | -- (comment) |
| 640 | CONTRACT | D-002, D-003 |
| 641 | CONTRACT | D-003 |
| 642 | SKIP | -- (blank) |
| 643-648 | CONTRACT | N-001, S-002, E-001 |
| 649 | CONTRACT | P-001 |
| 650 | CONTRACT | S-001, N-002 |
| 651 | INFRA | -- (closing brace) |
| 652 | SKIP | -- (blank) |
| 653-654 | SKIP | -- (doc comment) |
| 655-663 | INFRA | -- (method signature) |
| 664 | INFRA | -- (comment) |
| 665-667 | CONTRACT | M-001 |
| 668-672 | CONTRACT | D-004, P-002 |
| 673 | SKIP | -- (blank) |
| 674 | INFRA | -- (comment) |
| 675 | CONTRACT | D-002, D-003 |
| 676 | CONTRACT | D-003 |
| 677 | SKIP | -- (blank) |
| 678-683 | CONTRACT | N-001, S-002, E-001 |
| 684 | CONTRACT | P-001 |
| 685 | CONTRACT | S-001, N-002 |
| 686 | INFRA | -- (closing brace) |
| 687 | SKIP | -- (blank) |
| 688-689 | SKIP | -- (doc comment) |
| 690-700 | INFRA | -- (method signature) |
| 701 | INFRA | -- (comment) |
| 702-706 | CONTRACT | M-001 |
| 707-712 | CONTRACT | D-004, P-002 |
| 713 | SKIP | -- (blank) |
| 714 | INFRA | -- (comment) |
| 715 | CONTRACT | D-002, D-003 |
| 716 | CONTRACT | D-003 |
| 717 | SKIP | -- (blank) |
| 718-723 | CONTRACT | N-001, S-002, E-001 |
| 724 | CONTRACT | P-001 |
| 725 | CONTRACT | S-001, N-002 |
| 726 | INFRA | -- (closing brace) |
| 727 | SKIP | -- (blank) |
| 728-729 | SKIP | -- (doc comment) |
| 730-734 | INFRA | -- (method signature) |
| 735 | INFRA | -- (comment) |
| 736 | CONTRACT | M-001 |
| 737 | CONTRACT | D-004 |
| 738 | SKIP | -- (blank) |
| 739 | INFRA | -- (comment) |
| 740 | CONTRACT | D-002, D-003 |
| 741 | CONTRACT | D-003 |
| 742 | SKIP | -- (blank) |
| 743-748 | CONTRACT | N-001, S-002, E-001 |
| 749 | CONTRACT | P-001 |
| 750 | CONTRACT | S-001, N-002 |
| 751 | INFRA | -- (closing brace) |
| 752 | SKIP | -- (blank) |
| 753-754 | SKIP | -- (doc comment) |
| 755-760 | INFRA | -- (method signature) |
| 761 | CONTRACT | M-001 |
| 762-764 | CONTRACT | D-004 |
| 765 | SKIP | -- (blank) |
| 766 | CONTRACT | D-002, D-003 |
| 767 | CONTRACT | D-003 |
| 768 | SKIP | -- (blank) |
| 769-774 | CONTRACT | N-001, S-002, E-001 |
| 775 | CONTRACT | P-001 |
| 776 | CONTRACT | S-001, N-002 |
| 777 | INFRA | -- (closing brace) |
| 778 | INFRA | -- (closing brace for extension) |
| 779 | SKIP | -- (blank) |
| 780-781 | INFRA | -- (fileprivate extension declaration) |
| 782-789 | CONTRACT | D-005 |
| 790 | INFRA | -- (closing brace) |
| 791 | INFRA | -- (closing brace) |

```
Total lines:       ~791
CONTRACT lines:    ~420 (53%)
INFRA lines:       ~185 (23%)
SKIP lines:        ~186 (24%)
Unclassified:      0
```

> **注意：** 行號為估算值，因原始碼是從 prompt 內文提供，非從檔案直接讀取。實際行號可能有 ±5 行偏差。每個可執行行都已歸因。

---

## 錨點覆蓋確認

| 錨點 # | 類別 | 模式 | 對應合約 ID | 狀態 |
|--------|------|------|-----------|------|
| 1 | S | dispatch_sync | -- | **GAP**: PaymentsNetworkDispatcher.swift 未提供 |
| 2 | S | DispatchQueue_create | -- | **GAP**: PaymentsNetworkDispatcher.swift 未提供 |
| 3 | N | NotificationCenter_post | N-003 | 推斷合約，需要 Dispatcher 檔案確認 |
| 4 | D | shared_singleton | D-001 | 已覆蓋 |
| 5 | D | if_conditional | -- | **GAP**: PaymentsNetworkDispatcher.swift 未提供 |
| 6 | E | throws_decl | E-002 | 推斷合約（Codable + throws） |
| 7 | E | do_catch | E-001 | 間接覆蓋（Manager 接收 Dispatcher 的錯誤並轉發） |
| 8 | E | Codable | E-002 | 已覆蓋 |
| 9 | N | combine_sink (×25) | N-001, S-002 | 已覆蓋 |
| 10 | N | combine_store (×25) | S-001, N-002 | 已覆蓋 |

---

**INCOMPLETE: 錨點 #1, #2, #5 無法稽核——PaymentsNetworkDispatcher.swift 未提供。請提供該檔案以完成錨點 #1 (dispatch_sync), #2 (DispatchQueue_create), #5 (if_conditional) 的合約分析。**
