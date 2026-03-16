# Final Contract Spec
# Generated: 2026-03-17
# Auditor artifacts: claude-artifacts/ (Artifact 1-4)
# Adversary review: codex-review.md
# DEGRADED: no

---

## N-001: Combine sink 訂閱模式（涵蓋 25 個方法）

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
Seam_Type:    link
Pinch_Point:  true
```

[DISPUTED -- Adversary argues category "N" is overstated for callback wiring; evidence inconclusive on category naming, contract behavior description retained]
[META_ISSUE APPLIED -- Seam_Type changed from `none` to `link`: callback handoff to caller crosses boundary]

---

## N-002: Combine store(in: &self.cancellables) 共享儲存

```
Trigger:      每個 API 方法的 sink 結尾
Input:        AnyCancellable token
Output:       token 被加入 self.cancellables Set
Condition:    無
Ordering:     store 在 sink 之後立即呼叫
Risk:         HIGH -- cancellables 是 Set，已完成的訂閱不會自動移除，
              長時間運行的 app 會累積已完成的 AnyCancellable 物件（累積風險）
Evidence:     PaymentsNetworkManager.swift:49 (首次出現)
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

[DISPUTED -- Adversary correctly notes "memory leak" is overstated; updated to "累積風險" (accumulation risk). No matching removal logic confirmed in file, but strict leak requires broader analysis.]

---

## S-001: cancellables 的並行寫入無同步保護

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

[DISPUTED -- Adversary argues store occurs in call-site setup chain, not scheduler-hopped mutation; evidence inconclusive — concurrent callers on different threads still produce unsynchronized inout access to shared Set]

---

## D-001: PaymentsNetworkDispatcher 與 PaymentsAPIClient 建構合約

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

## D-002: URLSession 配置分歧

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

## D-003: Singleton shared 實例

```
Trigger:      模組內透過 PaymentsNetworkManager.shared 存取
Input:        N/A
Output:       全域唯一實例，所有 API 呼叫共享同一個 cancellables Set
Condition:    init() 未標記 private——模組內部可建立額外實例（class 非 public，外部模組不可直接實例化）
Ordering:     N/A
Risk:         HIGH -- singleton 意味著所有呼叫者共享 cancellables 狀態；
              加劇 S-001 的並行風險
Evidence:     PaymentsNetworkManager.swift:16 (public static let shared)
              PaymentsNetworkManager.swift:12 (class PaymentsNetworkManager — non-public)
Scope:        class
Seam_Type:    object
Pinch_Point:  true
```

[DISPUTED -- APPLIED: Adversary correctly identified class is not `public`; updated from "外部可建立額外實例" to "模組內部可建立額外實例"]

---

## E-001: completion 不保證被呼叫（靜默失敗路徑）

```
Trigger:      publisher 完成但未發出 value（例如 HTTP 204 No Content 被 Codable 解碼為空）
Input:        apiClient.dispatch() 的 publisher
Output:       .finished 分支僅 print，completion 不被呼叫
Condition:    所有方法（包含 Void 回傳型別）皆依賴 receiveValue 觸發 success 路徑；
              若 publisher 完成且無 value 則永遠不回調
Risk:         HIGH -- 呼叫者無法區分「請求中」與「請求已完成但未回調」，
              可能導致 UI 永遠顯示 loading
Evidence:     PaymentsNetworkManager.swift:41-45 (.finished 分支只 print)
              PaymentsNetworkManager.swift:113-125 (Void 方法同樣依賴 receiveValue)
Scope:        class
Seam_Type:    link
Pinch_Point:  true
```

[DISPUTED -- Adversary notes Void methods also depend on receiveValue; updated Condition to clarify all methods share this dependency]
[META_ISSUE APPLIED -- Seam_Type changed from `none` to `link`: failure/success callback crosses boundary]

---

## E-002: 錯誤型別限制為 PaymentsNetworkRequestError

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

## P-001: completion callback 的呼叫執行緒未指定

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
Seam_Type:    link
Pinch_Point:  true
```

[META_ISSUE APPLIED -- Seam_Type changed from `none` to `link`: thread-context propagation is boundary behavior]

---

## C-001: 取消機制僅透過 cancellables 清空

```
Trigger:      無明確的取消 API
Input:        N/A
Output:       唯一的取消方式是清空 self.cancellables（取消所有進行中的請求）
              或讓 PaymentsNetworkManager 被 dealloc（但主要透過 singleton 使用，不會 dealloc）
Condition:    singleton 的 cancellables 永不被清空；模組內部的非 shared 實例可被 dealloc
Ordering:     N/A
Risk:         MEDIUM -- 無法取消單一請求；singleton 不會 dealloc 所以 cancellables
              永遠持有已完成的訂閱
Evidence:     PaymentsNetworkManager.swift:19 (cancellables 宣告)
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

[DISPUTED -- Adversary notes non-shared instances are possible inside module; updated Condition to acknowledge this while retaining singleton as primary usage pattern]

---

## M-001: 請求 body 的 toDictionary 轉換

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

## M-002: postPayments 的冪等性 key

```
Trigger:      postPayments、postPaymentCodes、postStoredValues 被呼叫
Input:        idempotencyKey: String 參數
Output:       passthrough 傳入對應 PaymentsRequest 建構子；本模組不驗證唯一性、不執行重試策略
Condition:    idempotencyKey 由呼叫者提供並原封傳遞；後端行為由外部合約決定（本檔案無法驗證）
Ordering:     N/A
Risk:         HIGH -- 冪等性是防止重複扣款的關鍵機制；本模組僅負責傳遞 key，
              正確性完全依賴呼叫者與後端的配合
Evidence:     PaymentsNetworkManager.swift:590 (idempotencyKey 參數)
              PaymentsNetworkManager.swift:697 (postPaymentCodes)
              PaymentsNetworkManager.swift:732 (postStoredValues)
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

[DISPUTED -- APPLIED: Removed backend enforcement speculation; updated to clarify passthrough-only role]
[META_ISSUE -- Adversary suggests Seam_Type `link` for cross-system dependency; evidence inconclusive as this file only passes through the key, retained `none` with note]

---

## L-001: 訂閱生命週期綁定 manager 實例

```
Trigger:      任何 API 方法儲存新的訂閱
Input:        AnyCancellable token
Output:       訂閱生命週期綁定至持有 cancellables 的 manager 實例
Condition:    若 manager 被 dealloc，所有進行中的訂閱將被取消
Ordering:     store(in:) 後生效
Risk:         MEDIUM -- singleton 不 dealloc 故無影響；但非 shared 實例的提前釋放
              會取消所有進行中的請求
Evidence:     PaymentsNetworkManager.swift:18 (private var cancellables: Set<AnyCancellable> = [])
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

[ADDED from Adversary review -- valid evidence with filename:line]

---

## M-003: Console logging side effect on completion

```
Trigger:      Combine 發出 .finished 事件
Input:        completion result 描述字串
Output:       透過 print() 寫入 stdout，產生可觀察的 side effect
Condition:    所有 25 個方法的 .finished 分支皆包含 print
Ordering:     在 .finished 處理中立即執行
Risk:         LOW -- print 在 production 環境中不應產生使用者可見的影響，
              但會影響 log 輸出與測試 output 的雜訊
Evidence:     PaymentsNetworkManager.swift:40 (print("MultipassLogin completed with: \(result.self)"))
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

[ADDED from Adversary review -- valid evidence with filename:line]

---

## Risk Matrix

| ID | Risk | Description | Pinch_Point |
|----|------|-------------|-------------|
| S-001 | CRITICAL | cancellables 並行寫入無同步保護 | true |
| N-001 | CRITICAL | sink 的 .finished 不呼叫 completion | true |
| E-001 | HIGH | completion 靜默失敗路徑 | true |
| P-001 | HIGH | completion 呼叫執行緒未指定 | true |
| D-003 | HIGH | Singleton + init 未 private | true |
| N-002 | HIGH | cancellables 累積已完成訂閱 | true |
| M-002 | HIGH | 冪等性 key 依賴呼叫者正確性 | false |
| D-001 | MEDIUM | 每次呼叫建新 dispatcher/apiClient | true |
| D-002 | MEDIUM | URLSession 配置分歧 | false |
| C-001 | MEDIUM | 無單一請求取消機制 | false |
| M-001 | MEDIUM | toDictionary 轉換合約在外部 | false |
| L-001 | MEDIUM | 訂閱生命週期綁定 manager 實例 | true |
| E-002 | LOW | 錯誤型別為 PaymentsNetworkRequestError | false |
| M-003 | LOW | Console logging side effect | false |

---

## Adversary ADD Rejected

- **D-004 (Caller-thread synchronization dependency)**: REJECTED -- Evidence is `[inferred from EXTERNAL_DEPENDENCY hint]`, no valid filename:line. Requirement not met per merge rules.

---

## Coverage Gaps (from Adversary)

The following anchors remain unresolved due to `PaymentsNetworkDispatcher.swift` not being provided:
- Anchors 1-3: dispatch_sync, DispatchQueue_create, NotificationCenter_post
- Anchors 5-8: if_conditional, throws_decl, do_catch, Codable

**Action required**: Provide `PaymentsNetworkDispatcher.swift` for complete audit.
