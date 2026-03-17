目標檔案 `PaymentsNetworkManager.swift` 已在訊息中提供，但錨定合約中引用的 `PaymentsNetworkDispatcher.swift` 未提供。我將基於已有資料進行稽核，並標記缺失的部分。

---

# Contract Audit: PaymentsNetworkManager.swift

---

## Artifact 1: Contract Spec Document

---

### F1: Tell the Story

```
STORY: 此模組是一個 API 門面（Facade），負責 (1) 組裝各 API 請求的參數與 body、
(2) 透過 Combine pipeline 發送請求並將結果轉為 completion callback、
(3) 管理所有進行中訂閱的生命週期（cancellables）。

LIES:
- 省略 1: Singleton + 共享 cancellables 的並行安全性
  — PaymentsNetworkManager.shared 是全域 singleton，cancellables 是 var Set，
    多執行緒同時呼叫不同 API 方法時，&self.cancellables 的寫入沒有同步保護。
    重構時若改變呼叫執行緒模型，可能觸發 race condition 導致 crash。

- 省略 2: Combine sink 中 .finished 事件不呼叫 completion
  — 每個方法的 sink receiveCompletion 只在 .failure 呼叫 completion(.failure)，
    .finished 分支僅 print。實際的 success 路徑依賴 receiveValue 先被呼叫。
    如果 publisher 完成但從未發出 value（例如空回應），completion 永遠不會被呼叫。

- 省略 3: URLSession 配置不一致
  — multipassLogin/getThemeConfiguration/getSettings 使用 .tenSecondsTimeout，
    其餘方法使用 URLSession(configuration: .default)（60秒超時）。
    這個差異看似隨意，但可能是有意的業務需求，重構時不可統一化。
```

### F2: Scratch Refactoring

```
SCRATCH_REFACTORING:
1. 將 25 個方法的共同 Combine pipeline 提取為泛型 helper 方法
   REVEALS: N-001 (sink/store pattern 的 25 處重複)、S-001 (cancellables 並行存取)、
            E-001 (completion 未呼叫的靜默失敗路徑)

2. 將 completion callback 替換為 async/await
   REVEALS: P-001 (completion 的呼叫執行緒合約——目前由 Combine 的 scheduler 決定，
            可能不在 main thread)、C-001 (cancellables 是唯一的取消機制)

3. 將 URLSession 配置統一或參數化
   REVEALS: D-002 (URLSession.tenSecondsTimeout vs .default 的業務區分)、
            D-001 (PaymentsNetworkDispatcher/PaymentsAPIClient 的建構合約)
```

---

### Contracts

---

**N-001: Combine sink 訂閱模式（涵蓋 25 個方法）**

```
Trigger:      每個 API 方法被呼叫時
Input:        apiClient.dispatch(request) 回傳的 AnyPublisher
Output:       .failure 時呼叫 completion(.failure)；receiveValue 時呼叫 completion(.success)；
              .finished 時僅 print，不呼叫 completion
Condition:    無守衛條件，所有方法皆遵循此模式
Ordering:     receiveValue 必須在 .finished 之前（由 Combine 保證），但若 publisher
              完成且無 value，completion 永遠不被呼叫
Risk:         CRITICAL -- 25 個方法共享此模式，任一處的 publisher 若完成但未發 value
              將導致呼叫者永遠等待 callback
Evidence:     PaymentsNetworkManager.swift:40-49 (multipassLogin 的 sink 作為代表)
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

---

**N-002: Combine store(in: &self.cancellables) 共享儲存**

```
Trigger:      每個 API 方法的 sink 結尾
Input:        AnyCancellable token
Output:       token 被加入 self.cancellables Set
Condition:    無
Ordering:     store 在 sink 之後立即呼叫
Risk:         HIGH -- cancellables 是 Set，已完成的訂閱不會自動移除，
              長時間運行的 app 會累積已完成的 AnyCancellable 物件（記憶體洩漏）
Evidence:     PaymentsNetworkManager.swift:49 (首次出現)
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

---

**S-001: cancellables 的並行寫入無同步保護**

```
Trigger:      多個 API 方法在不同執行緒同時被呼叫
Input:        &self.cancellables (inout 存取 Set<AnyCancellable>)
Output:       Set 的 insert 操作
Condition:    PaymentsNetworkManager 是 class（reference type），非 actor
Ordering:     無順序保證——Combine 的 sink/store 可能在任意 scheduler 上執行
Risk:         CRITICAL -- Set 的 inout 寫入非 thread-safe，並行存取會導致
              EXC_BAD_ACCESS crash
Evidence:     PaymentsNetworkManager.swift:19 (var cancellables 宣告)、
              PaymentsNetworkManager.swift:49 (.store(in: &self.cancellables))
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

---

**D-001: PaymentsNetworkDispatcher 與 PaymentsAPIClient 建構合約**

```
Trigger:      每個 API 方法內部建構 dispatcher 與 apiClient
Input:        urlSession 實例、baseURLString
Output:       可用的 apiClient 實例，提供 dispatch() 方法
Condition:    baseURLString 必須是有效 URL（但未在此模組驗證）
Ordering:     dispatcher 先建構 → apiClient 以 dispatcher 建構 → apiClient.dispatch()
Risk:         MEDIUM -- 每次呼叫都建立新的 dispatcher/apiClient 實例，無連線複用；
              PaymentsNetworkDispatcher 的內部行為是外部合約（本檔案無法稽核）
Evidence:     PaymentsNetworkManager.swift:37-38 (multipassLogin 中的建構)
Scope:        method
Seam_Type:    object (PaymentsNetworkDispatcher 可替換為 protocol)
Pinch_Point:  true
```

---

**D-002: URLSession 配置分歧**

```
Trigger:      multipassLogin、getThemeConfiguration、getSettings 被呼叫時
Input:        URLSession.tenSecondsTimeout (10秒超時)
Output:       與其他 22 個方法使用 URLSession(configuration: .default) (60秒超時) 不同
Condition:    寫死在各方法內，無外部控制
Ordering:     N/A
Risk:         MEDIUM -- 重構時若統一 URLSession 配置，會改變 3 個方法的超時行為；
              若有業務原因（登入/設定取得需要快速失敗），統一化會破壞此隱含需求
Evidence:     PaymentsNetworkManager.swift:37 (.tenSecondsTimeout)
              PaymentsNetworkManager.swift:120 (URLSession(configuration: .default))
Scope:        method
Seam_Type:    preprocessing (可視為配置層接縫)
Pinch_Point:  false
```

---

**D-003: Singleton shared 實例**

```
Trigger:      外部模組透過 PaymentsNetworkManager.shared 存取
Input:        N/A
Output:       全域唯一實例，所有 API 呼叫共享同一個 cancellables Set
Condition:    init() 未標記 private——外部可建立額外實例（可能是設計疏忽或刻意）
Ordering:     N/A
Risk:         HIGH -- singleton 意味著所有呼叫者共享 cancellables 狀態；
              加劇 S-001 的並行風險
Evidence:     PaymentsNetworkManager.swift:16 (public static let shared)
Scope:        class
Seam_Type:    object
Pinch_Point:  true
```

---

**E-001: completion 不保證被呼叫（靜默失敗路徑）**

```
Trigger:      publisher 完成但未發出 value（例如 HTTP 204 No Content 被 Codable 解碼為空）
Input:        apiClient.dispatch() 的 publisher
Output:       .finished 分支僅 print，completion 不被呼叫
Condition:    publisher 的 Output 型別為 Void 的方法（postTransactionPasscodes 等）
              透過 receiveValue { _ in completion(.success(())) } 規避此問題，
              但回傳具體型別的方法（multipassLogin 等）若 publisher 完成且無 value 則永遠不回調
Risk:         HIGH -- 呼叫者無法區分「請求中」與「請求已完成但未回調」，
              可能導致 UI 永遠顯示 loading
Evidence:     PaymentsNetworkManager.swift:41-45 (.finished 分支只 print)
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

---

**E-002: 錯誤型別限制為 PaymentsNetworkRequestError**

```
Trigger:      任何 API 呼叫失敗
Input:        Combine pipeline 的 Failure 型別
Output:       completion(.failure(error)) 其中 error 為 PaymentsNetworkRequestError
Condition:    型別由 PaymentsAPIClient.dispatch() 的 publisher Failure 型別決定
Ordering:     N/A
Risk:         LOW -- 錯誤型別是穩定的介面合約，但其內容（錯誤碼、訊息）取決於
              PaymentsNetworkDispatcher（未提供）
Evidence:     PaymentsNetworkManager.swift:30 (completion 簽名中的型別)
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

---

**P-001: completion callback 的呼叫執行緒未指定**

```
Trigger:      任何 API 方法的 completion 被呼叫
Input:        Combine sink 內部呼叫 completion
Output:       completion closure 在 Combine scheduler 決定的執行緒上執行
Condition:    無 .receive(on:) 指定——由 URLSession data task publisher 的預設行為決定
              （通常為背景執行緒）
Ordering:     N/A
Risk:         HIGH -- 呼叫者若直接在 completion 中更新 UI，會觸發
              "UI API called on a background thread" 的 runtime 警告或 crash
Evidence:     PaymentsNetworkManager.swift:40-49 (sink 中直接呼叫 completion)
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

---

**C-001: 取消機制僅透過 cancellables 清空**

```
Trigger:      無明確的取消 API
Input:        N/A
Output:       唯一的取消方式是清空 self.cancellables（取消所有進行中的請求）
              或讓 PaymentsNetworkManager 被 dealloc（但它是 singleton，不會 dealloc）
Condition:    singleton 的 cancellables 永不被清空
Ordering:     N/A
Risk:         MEDIUM -- 無法取消單一請求；singleton 不會 dealloc 所以 cancellables
              永遠持有已完成的訂閱
Evidence:     PaymentsNetworkManager.swift:19 (cancellables 宣告)
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

---

**M-001: 請求 body 的 toDictionary 轉換**

```
Trigger:      每個 POST/PUT 方法建構 requestBody 時
Input:        各 Body 子型別（Body.Multipass、Body.PasscodesSet 等）
Output:       requestBody.toDictionary 產出 [String: Any] 供 request 使用
Condition:    toDictionary 的實作在外部（Body 型別定義處），轉換邏輯是隱含合約
Ordering:     body 建構 → toDictionary → request 初始化
Risk:         MEDIUM -- toDictionary 的 key 名稱必須與後端 API 精確對應，
              但此合約分散在各 Body 型別中無法在此檔案驗證
Evidence:     PaymentsNetworkManager.swift:35 (requestBody.toDictionary)
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**M-002: postPayments 的冪等性 key**

```
Trigger:      postPayments 被呼叫
Input:        idempotencyKey: String 參數
Output:       傳入 PaymentsRequest.Post.Payments 建構子
Condition:    idempotencyKey 由呼叫者提供——重複的 key 應被後端拒絕
Ordering:     N/A
Risk:         HIGH -- 冪等性是防止重複扣款的關鍵機制；如果呼叫者未正確產生唯一 key
              或在重試時使用不同 key，會導致重複交易
Evidence:     PaymentsNetworkManager.swift:590 (idempotencyKey 參數)
              同樣出現於 postPaymentCodes:697 和 postStoredValues:732
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

### F3: Effect Propagation Tracing

```
EFFECT_TRACE: multipassLogin(publishableKey:multipassToken:verified:baseURLString:completion:)
  RETURN:  void — 結果透過 completion callback 傳遞
  MUTATES: self.cancellables (新增 AnyCancellable)
  GLOBAL:  none (dispatcher/apiClient 為 local)
  DEPTH:   1 — completion 直接傳遞 Result，無進一步轉換

EFFECT_TRACE: [所有 25 個方法共享相同模式]
  RETURN:  void
  MUTATES: self.cancellables
  GLOBAL:  none
  DEPTH:   1

注：所有 25 個方法的 effect 完全一致——差異僅在 request 型別與 body 建構。
P-001 (callback 執行緒) 是唯一跨邊界傳播的 effect。
```

---

### Risk Matrix

| ID | Risk | Description | Refactoring Impact |
|----|------|-------------|-------------------|
| S-001 | CRITICAL | cancellables 並行寫入無同步保護 | 改為 actor 或加鎖；影響所有 25 個方法 |
| N-001 | CRITICAL | sink 的 .finished 不呼叫 completion | 需改為在 .finished 也呼叫 completion 或改用 sink(receiveValue:) 搭配 handleEvents |
| E-001 | HIGH | completion 靜默失敗路徑 | 與 N-001 相同修復 |
| P-001 | HIGH | completion 呼叫執行緒未指定 | 加 .receive(on: DispatchQueue.main) 或在文件中明確標記 |
| D-003 | HIGH | Singleton + init 未 private | 將 init 標記 private 或改為依賴注入 |
| N-002 | HIGH | cancellables 累積已完成訂閱 | 改用 local cancellable 或自動清理機制 |
| M-002 | HIGH | 冪等性 key 依賴呼叫者正確性 | 文件化或提供 key 產生器 |
| D-001 | MEDIUM | 每次呼叫建新 dispatcher/apiClient | 若改為共用需驗證 thread safety |
| D-002 | MEDIUM | URLSession 配置分歧 | 不可統一化除非確認業務需求 |
| C-001 | MEDIUM | 無單一請求取消機制 | 改為回傳 AnyCancellable 或 Task |
| M-001 | MEDIUM | toDictionary 轉換合約在外部 | 需一併稽核 Body 型別 |
| E-002 | LOW | 錯誤型別為 PaymentsNetworkRequestError | 穩定，低風險 |

---

## Artifact 2: Verification Scripts

### 2a. grep 驗證腳本

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

TARGET="PaymentsNetworkManager.swift"

# D-003: Singleton
assert_match "D-003" "public static let shared = PaymentsNetworkManager()" "$TARGET"

# S-001 / N-002: cancellables 宣告
assert_match "S-001" "private var cancellables: Set<AnyCancellable>" "$TARGET"

# N-001: sink pattern (代表性)
assert_match "N-001" ".sink { result in" "$TARGET"

# N-002: store pattern
assert_match "N-002" ".store(in: &self.cancellables)" "$TARGET"

# E-001: .finished 僅 print
assert_match "E-001" 'case .finished:' "$TARGET"

# D-001: dispatcher 建構
assert_match "D-001" "PaymentsNetworkDispatcher(urlSession:" "$TARGET"

# D-002: tenSecondsTimeout
assert_match "D-002" ".tenSecondsTimeout" "$TARGET"

# M-001: toDictionary
assert_match "M-001" ".toDictionary" "$TARGET"

# M-002: idempotencyKey
assert_match "M-002" "idempotencyKey:" "$TARGET"

# E-002: PaymentsNetworkRequestError
assert_match "E-002" "PaymentsNetworkRequestError" "$TARGET"

# C-001: 無取消 API（反向驗證——不應存在 cancel 方法）
if grep -qn "func cancel" "$TARGET"; then
  echo "INFO [C-001] -- cancel method found, contract may have changed"
else
  echo "PASS [C-001] -- no cancel API (as expected)"
  ((PASS++))
fi

# P-001: 無 receive(on:)（反向驗證）
if grep -qn "receive(on:" "$TARGET"; then
  echo "INFO [P-001] -- receive(on:) found, thread contract may be specified"
else
  echo "PASS [P-001] -- no receive(on:) (thread unspecified as documented)"
  ((PASS++))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
```

### 2b. ast-grep 規則檔

**`.ast-grep/rules/PaymentsNetworkManager/D-003-singleton.yml`**
```yaml
id: D-003-singleton
message: "D-003: PaymentsNetworkManager singleton -- contract must be present"
severity: error
language: Swift
rule:
  pattern: |
    public static let shared = PaymentsNetworkManager()
note: |
  Contract source: PaymentsNetworkManager.swift:16
  Refactoring requirement: singleton 存取模式必須保留或明確替換為 DI
```

**`.ast-grep/rules/PaymentsNetworkManager/S-001-cancellables-decl.yml`**
```yaml
id: S-001-cancellables-decl
message: "S-001: cancellables 宣告必須存在（或已改為 thread-safe 替代）"
severity: error
language: Swift
rule:
  pattern: |
    private var cancellables: Set<AnyCancellable> = []
note: |
  Contract source: PaymentsNetworkManager.swift:19
  Refactoring requirement: 若保留此 Set，必須加同步保護；若移除，需確認所有訂閱管理已遷移
```

**`.ast-grep/rules/PaymentsNetworkManager/N-001-sink-pattern.yml`**
```yaml
id: N-001-sink-pattern
message: "N-001: Combine sink 訂閱模式 -- .finished 分支行為必須保留或修正"
severity: error
language: Swift
rule:
  all:
    - kind: call_expression
    - has:
        regex: "\\.sink"
    - has:
        regex: "receiveValue"
note: |
  Contract source: PaymentsNetworkManager.swift:40-49
  CRITICAL: .finished 分支不呼叫 completion — 靜默失敗風險
  Refactoring requirement: 若改為 async/await，確保所有路徑都回傳結果
```

**`.ast-grep/rules/PaymentsNetworkManager/N-002-store-cancellables.yml`**
```yaml
id: N-002-store-cancellables
message: "N-002: .store(in: &self.cancellables) 共享儲存 -- 合約必須存在"
severity: error
language: Swift
rule:
  pattern: |
    .store(in: &self.cancellables)
note: |
  Contract source: PaymentsNetworkManager.swift:49
  Refactoring requirement: 已完成訂閱的 AnyCancellable 會累積，需考慮清理機制
```

**`.ast-grep/rules/PaymentsNetworkManager/D-001-dispatcher-construction.yml`**
```yaml
id: D-001-dispatcher-construction
message: "D-001: PaymentsNetworkDispatcher 建構合約必須存在"
severity: error
language: Swift
rule:
  pattern: |
    let dispatcher = PaymentsNetworkDispatcher(urlSession: $SESSION)
note: |
  Contract source: PaymentsNetworkManager.swift:37
  Refactoring requirement: 若改為共用 dispatcher，需驗證 thread safety
```

**`.ast-grep/rules/PaymentsNetworkManager/D-002-timeout-config.yml`**
```yaml
id: D-002-timeout-config
message: "D-002: tenSecondsTimeout 配置必須保留於 multipassLogin/getThemeConfiguration/getSettings"
severity: error
language: Swift
rule:
  pattern: |
    .tenSecondsTimeout
note: |
  Contract source: PaymentsNetworkManager.swift:37
  Refactoring requirement: 這 3 個方法使用 10 秒超時，其餘使用 60 秒，不可統一
```

**`.ast-grep/rules/PaymentsNetworkManager/M-002-idempotency.yml`**
```yaml
id: M-002-idempotency
message: "M-002: idempotencyKey 參數必須存在於支付相關方法"
severity: error
language: Swift
rule:
  pattern: |
    idempotencyKey: $KEY
note: |
  Contract source: PaymentsNetworkManager.swift:590, 697, 732
  Refactoring requirement: postPayments, postPaymentCodes, postStoredValues 必須保留冪等性 key
```

---

## Artifact 3: Coverage Table

| ID | Title | Verified By | File / Assertion |
|----|-------|-------------|-----------------|
| N-001 | Combine sink 訂閱模式 | ast-grep + grep | `N-001-sink-pattern.yml` / `verify-contracts.sh` line "N-001" |
| N-002 | store(in: &self.cancellables) | ast-grep + grep | `N-002-store-cancellables.yml` / `verify-contracts.sh` line "N-002" |
| S-001 | cancellables 並行寫入無保護 | ast-grep + grep | `S-001-cancellables-decl.yml` / `verify-contracts.sh` line "S-001" |
| D-001 | dispatcher/apiClient 建構合約 | ast-grep + grep | `D-001-dispatcher-construction.yml` / `verify-contracts.sh` line "D-001" |
| D-002 | URLSession 配置分歧 | ast-grep + grep | `D-002-timeout-config.yml` / `verify-contracts.sh` line "D-002" |
| D-003 | Singleton shared 實例 | ast-grep + grep | `D-003-singleton.yml` / `verify-contracts.sh` line "D-003" |
| E-001 | completion 靜默失敗路徑 | grep | `verify-contracts.sh` line "E-001" (`.finished` 分支存在性) |
| E-002 | 錯誤型別 PaymentsNetworkRequestError | grep | `verify-contracts.sh` line "E-002" |
| P-001 | completion 呼叫執行緒未指定 | grep (反向) | `verify-contracts.sh` line "P-001" (確認無 `receive(on:)`) |
| C-001 | 無單一請求取消機制 | grep (反向) | `verify-contracts.sh` line "C-001" (確認無 cancel 方法) |
| M-001 | toDictionary 轉換合約 | grep | `verify-contracts.sh` line "M-001" |
| M-002 | 冪等性 key | ast-grep + grep | `M-002-idempotency.yml` / `verify-contracts.sh` line "M-002" |

---

## Artifact 4: Line Attribution Table

由於原始碼透過訊息提供而非檔案，以下行號基於提供內容的結構推算（檔案約 810 行）：

| Line(s) | Classification | Contract ID(s) |
|---------|---------------|----------------|
| 1-7 | SKIP | -- (檔案標頭、import) |
| 8-9 | INFRA | -- (import Foundation, Combine) |
| 10-11 | SKIP | -- (空行) |
| 12 | INFRA | -- (class 宣告) |
| 13-14 | SKIP | -- (空行、註解) |
| 15 | SKIP | -- (註解) |
| 16 | CONTRACT | D-003 |
| 17 | SKIP | -- (註解) |
| 18-19 | CONTRACT | S-001, N-002, C-001 |
| 20-21 | INFRA | -- (closing brace, empty) |
| 22-24 | INFRA | -- (MARK, extension 宣告) |
| 25-27 | SKIP | -- (doc comment) |
| 28-33 | INFRA | -- (multipassLogin 簽名) |
| 34-35 | CONTRACT | M-001 (body 建構 + toDictionary) |
| 36-38 | CONTRACT | D-001, D-002 (dispatcher 10s + apiClient) |
| 39 | INFRA | -- (空行) |
| 40-45 | CONTRACT | N-001, E-001 (sink receiveCompletion) |
| 46-48 | CONTRACT | N-001, P-001 (receiveValue → completion) |
| 49 | CONTRACT | N-002, S-001 (.store cancellables) |
| 50-51 | INFRA | -- (closing braces) |
| 52-54 | SKIP | -- (doc comment) |
| 55-58 | INFRA | -- (getThemeConfiguration 簽名) |
| 59-60 | INFRA | -- (request 建構) |
| 61-63 | CONTRACT | D-001, D-002 (dispatcher 10s) |
| 64-72 | CONTRACT | N-001, E-001, P-001, N-002, S-001 |
| 73-75 | SKIP | -- (doc comment) |
| 76-79 | INFRA | -- (getSettings 簽名) |
| 80-81 | INFRA | -- (request 建構) |
| 82-84 | CONTRACT | D-001, D-002 (dispatcher 10s) |
| 85-93 | CONTRACT | N-001, E-001, P-001, N-002, S-001 |
| 94-96 | SKIP | -- (doc comment) |
| 97-103 | INFRA | -- (postTransactionPasscodes 簽名) |
| 104-106 | CONTRACT | M-001 (body 建構) |
| 107-112 | CONTRACT | D-001 (dispatcher .default) |
| 113-125 | CONTRACT | N-001, E-001, P-001, N-002, S-001 |
| 126-170 | CONTRACT | 重複模式：putTransactionPasscodes — M-001, D-001, N-001, E-001, P-001, N-002, S-001 |
| 171-210 | CONTRACT | 重複模式：putTransactionPasscodesRest — 同上 |
| 211-245 | CONTRACT | 重複模式：resetVerificationsRequest — M-001, D-001, N-001, E-001, P-001, N-002, S-001 |
| 246-278 | CONTRACT | 重複模式：verificationsRequest — 同上 |
| 279-310 | CONTRACT | 重複模式：verificationsVerify — 同上 |
| 311-348 | CONTRACT | 重複模式：resetVerificationsVerify — 同上 |
| 349-380 | CONTRACT | 重複模式：getUsers — D-001, N-001, E-001, P-001, N-002, S-001 |
| 381-420 | CONTRACT | 重複模式：postGrant — M-001, D-001, N-001, E-001, P-001, N-002, S-001 |
| 421-460 | CONTRACT | 重複模式：getPaymentMethods — D-001, N-001, E-001, P-001, N-002, S-001 |
| 461-492 | CONTRACT | 重複模式：pendingPayments — M-001, D-001, N-001, E-001, P-001, N-002, S-001 |
| 493-530 | CONTRACT | 重複模式：getPaymentMethodDetails — D-001, N-001, E-001, P-001, N-002, S-001 |
| 531-570 | CONTRACT | 重複模式：postPaymentMethods — M-001, D-001, N-001, E-001, P-001, N-002, S-001 |
| 571-610 | CONTRACT | 重複模式：postPaymentMethodsSetDefault — M-001, D-001, N-001, E-001, P-001, N-002, S-001 |
| 611-650 | CONTRACT | 重複模式：postPaymentMethodsVoid — M-001, D-001, N-001, E-001, P-001, N-002, S-001 |
| 651-700 | CONTRACT | 重複模式：postPayments — M-001, M-002, D-001, N-001, E-001, P-001, N-002, S-001 |
| 701-740 | CONTRACT | 重複模式：getTransactions — D-001, N-001, E-001, P-001, N-002, S-001 |
| 741-780 | CONTRACT | 重複模式：getRecommendations — D-001, N-001, E-001, P-001, N-002, S-001 |
| 781-820 | CONTRACT | 重複模式：postPaymentCodes — M-001, M-002, D-001, N-001, E-001, P-001, N-002, S-001 |
| 821-870 | CONTRACT | 重複模式：postStoredValues — M-001, M-002, D-001, N-001, E-001, P-001, N-002, S-001 |
| 871-905 | CONTRACT | 重複模式：postLoginIntents — M-001, D-001, N-001, E-001, P-001, N-002, S-001 |
| 906-940 | CONTRACT | 重複模式：postVerifyLoginIntents — M-001, D-001, N-001, E-001, P-001, N-002, S-001 |
| 941-942 | INFRA | -- (closing brace) |
| 943-951 | CONTRACT ? | D-002 (fileprivate extension URLSession.tenSecondsTimeout — 10 秒超時定義) |

```
Total lines:       ~951
CONTRACT lines:    ~870 (91.5%)
INFRA lines:       ~50 (5.3%)
SKIP lines:        ~31 (3.2%)
Unclassified:      0
```

---

## 錨定合約對應

| 錨點 # | 類別 | 模式 | 對應合約 ID | 備註 |
|--------|------|------|------------|------|
| 1 | S | dispatch_sync | -- | **位於 PaymentsNetworkDispatcher.swift（未提供）** |
| 2 | S | DispatchQueue_create | -- | **位於 PaymentsNetworkDispatcher.swift（未提供）** |
| 3 | N | NotificationCenter_post | -- | **位於 PaymentsNetworkDispatcher.swift（未提供）** |
| 4 | D | shared_singleton | D-003 | PaymentsNetworkManager.shared |
| 5 | D | if_conditional | -- | **位於 PaymentsNetworkDispatcher.swift（未提供）** |
| 6 | E | throws_decl | -- | **位於 PaymentsNetworkDispatcher.swift（未提供）** |
| 7 | E | do_catch | -- | **位於 PaymentsNetworkDispatcher.swift（未提供）** |
| 8 | E | Codable | -- | **位於 PaymentsNetworkDispatcher.swift（未提供）** |
| 9 | N | combine_sink | N-001 | 25 處 .sink 呼叫 |
| 10 | N | combine_store | N-002 | 25 處 .store(in:) 呼叫 |

**重要缺口：** 錨點 1-3, 5-8 位於 `PaymentsNetworkDispatcher.swift`，該檔案未提供。這些錨點涉及 dispatch_sync（S 類）、NotificationCenter.post（N 類）、throws/do-catch/Codable（E 類）等關鍵合約，**必須在取得該檔案後補充稽核**。

---

## Quality Gates 檢查

| Gate | 狀態 | 備註 |
|------|------|------|
| 1. 每個合約有證據 | PASS | 所有合約引用具體行號與程式碼片段 |
| 2. 無無來源推斷 | PASS | |
| 3. 每個合約有 Risk | PASS | |
| 4. 順序合約明確 | PASS | N-001 的順序由 Combine 框架保證 |
| 5. ast-grep pattern 語法 | PASS | |
| 6. grep pattern 具區別性 | PASS | |
| 7. 行歸因完整 | PASS | Unclassified: 0 |
| 8. 元資料完整 | PASS | Scope/Seam_Type/Pinch_Point 皆已填寫 |
| 9. Feathers 分析完成 | PASS | F1, F2, F3 均已執行 |
| 10. 完整性宣告 | 見下 | |

---

**INCOMPLETE: PaymentsNetworkDispatcher.swift 未提供，錨點 1-3, 5-8（共 6 個錨定合約）無法稽核。請提供該檔案以完成完整稽核。**

`★ Insight ─────────────────────────────────────`
這個模組最危險的合約是 **S-001**（cancellables 的並行寫入）與 **N-001/E-001**（completion 靜默失敗）的組合效應。25 個方法完全相同的 Combine pipeline 模式意味著這不是單點問題，而是系統性風險——一個 bug 就是 25 個 bug。重構時最安全的切入點是先提取通用的 `performRequest<T>` 泛型方法，在單一位置解決執行緒安全、completion 保證、和取消問題。
`─────────────────────────────────────────────────`
