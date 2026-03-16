# Blind Contract Scout
# 盲掃合約發現者 -- 語言無關版本
# 此 prompt 由 Gemini 執行，獨立於主稽核者（Auditor）運作，不參考任何既有合約清單。

## ROLE

You are performing a blind behavioral contract discovery on one or more source files.
You have NO prior list of contract IDs. You are NOT trying to confirm anyone else's work.
Your only goal is to find every place this code makes an implicit promise to its callers.

The target code may be written in any language (`swift`). Adapt your analysis accordingly.

## WHAT TO LOOK FOR

Scan for all eight categories of behavioral contracts:

| Category | What to look for |
|----------|-----------------|
| **M** -- Mutation | Side effects that modify data before it leaves the module |
| **L** -- Lifecycle | Implicit state transitions triggered by the module |
| **N** -- Notification | Any pub/sub coupling: events, notifications, signals, message buses |
| **S** -- Synchronization | Blocking, locks, ordering guarantees, thread assumptions |
| **E** -- Error Handling | Swallowed errors, silent fallbacks, special error codes |
| **C** -- Cancellation | What can be cancelled, scope, residual state after cancellation |
| **D** -- Dependency | Implicit reliance on external components, singletons, init order |
| **P** -- Propagation | How effects cross module boundaries: return value chains, parameter mutation, global state changes |

For each behavioral contract you find, record:
- What triggers it (call site, method entry, condition)
- What it does (mutation, state change, event dispatch, lock, error handling, etc.)
- Exact filename and line number
- One-sentence description

## OUTPUT FORMAT

For each contract:

```
Contract: [short title]
Category: [M | L | N | S | E | C | D | P]
Trigger:  [what causes it]
Effect:   [what observable change it makes]
Evidence: [filename:line -- exact code fragment]
```

After listing all contracts, add a summary line:
```
TOTAL CONTRACTS FOUND: [N]
CATEGORY BREAKDOWN: M=[n] L=[n] N=[n] S=[n] E=[n] C=[n] D=[n] P=[n]
```

## Section 4: Boundary Discovery

After listing all contracts, investigate what lies OUTSIDE the provided files.
For each of the following, list files you suspect exist based on the code you see:

1. **Event/Notification Observers**: This code dispatches events or notifications. What classes or modules likely observe them?
   Search for: any observer registration, event listener setup, or subscription calls referencing the same event names.

2. **External Synchronization**: This code uses synchronization primitives (locks, semaphores, actors, mutexes, async barriers). Are there other classes with similar patterns?

3. **Downstream Lifecycle**: This code calls cleanup, teardown, or shutdown helpers. What classes implement them?

4. **Singleton / Global State**: This code reads or writes shared global state. What other modules depend on the same state?

5. **Propagation Endpoints**: This code returns values or mutates parameters that cross module boundaries. What are the likely consumers?

For each finding, output:
```
EXTERNAL_DEPENDENCY: [suspected filename or class/module name] -- [reason / what event or call triggers it]
```

If you cannot find evidence, output:
```
EXTERNAL_DEPENDENCY: (none found)
```

## INSTRUCTIONS

- Read every line of the provided source file(s). Do not skip sections.
- If you are unsure whether something is a contract, include it and mark it "(uncertain)".
- Do NOT use contract IDs from any other document. Assign no IDs.
- Do NOT produce verification scripts or ast-grep rules. Discovery only.
- Adapt your analysis to `swift` idioms -- for example, use language-appropriate terminology for events, notifications, lifecycle hooks, and synchronization primitives.


//
//  PaymentsNetworkDispatcher.swift
//
//
//  Created by James Hung on 2023/2/13.
//

import Foundation
import Combine

/// Request Payments Error Type
public enum PaymentsNetworkRequestError: LocalizedError {
    // system level
    case badRequest(_ data: Data? = nil) // ?????
    case decodingError(_ description: String)
    case dataCorrupted(_ data: Data? = nil) // ????
    case urlSessionFailed(_ error: URLError)
    
    // not in sheet
    case passcodeConfirmedIncorrect(_ data: Data? = nil)
    case passcodeIncorrect(_ data: Data? = nil)
    case passcodeInvalid(_ data: Data? = nil)
    case passcodeRestricted(_ data: Data? = nil)
    case userPasscodeIncorrect(_ data: Data? = nil)
    case userStatusIncorrect(_ data: Data? = nil)
    case verifiedCodeIncorrect(_ data: Data? = nil)
    case verifiedCodeInvalid(_ data: Data? = nil)
    case verifiedCodeRestricted(_ data: Data? = nil)
    
    // in sheet
    case accountBalanceIsNull(_ data: Data? = nil)
    case accountWrong(_ data: Data? = nil)
    case amountMustGreaterThanZero(_ data: Data? = nil)
    case consecutiveLoginAttemptFail(_ data: Data? = nil)
    case createScaAuthFail(_ data: Data? = nil)
    case creditCardServiceUnavailable(_ data: Data? = nil)
    case currencyUnsupported(_ data: Data? = nil)
    case depositLessThanLowerLimit(_ data: Data? = nil)
    case depositMoreThanTotalLimit(_ data: Data? = nil)
    case depositMoreThanUpperLimit(_ data: Data? = nil)
    case duplicatedLoginDetected(_ data: Data? = nil)
    case grantIncorrect(_ data: Data? = nil)
    case inputsRequired(_ data: Data? = nil)
    case internalError(_ data: Data? = nil)
    case invalidInstalmentAmount(_ data: Data? = nil)
    case invalidNumberOfInstallments(_ data: Data? = nil)
    case invalidOperation(_ data: Data? = nil)
    case issuerBankUnsupported(_ data: Data? = nil)
    case loginVerificationRequired(_ data: Data? = nil)
    case notFound(_ data: Data? = nil)
    case numberOfInstallmentsNotSupport(_ data: Data? = nil)
    case panExisted(_ data: Data? = nil)
    case payTypeUnsupported(_ data: Data? = nil)
    case paymentMethodIncorrect(_ data: Data? = nil)
    case paymentMethodInvalid(_ data: Data? = nil)
    case paymentMethodNotFound(_ data: Data? = nil)
    case providerUnsupported(_ data: Data? = nil)
    case queryTypeInvalid(_ data: Data? = nil)
    case revokeCoBrandCardBindFail(_ data: Data? = nil)
    case storedValueServiceUnavailable(_ data: Data? = nil)
    case storedValuesSettingRequired(_ data: Data? = nil)
    case tokenAbandoned(_ data: Data? = nil)
    case tokenInvalid(_ data: Data? = nil)
    case tokenUnauthorized(_ data: Data? = nil)
    case tooManyRequests(_ data: Data? = nil)
    case tradeIdInvalid(_ data: Data? = nil)
    case tradeIdRequired(_ data: Data? = nil)
    case transactionExist(_ data: Data? = nil)
    case transactionTypeUnsupported(_ data: Data? = nil)
    case txnTokenInvalid(_ data: Data? = nil)
    case verifiedCodeTempRestricted(_ data: Data? = nil)
    case walletServiceUnavailable(_ data: Data? = nil)
    case walletUserBundleNotFound(_ data: Data? = nil)
    
    // TODO: remove unknown as default case
    case unknownError(_ data: Data? = nil)
}

// MARK: - NetworkDispatcher -
/// Responsibilities: Receive a URLRequest, transmit it over the network and decode the JSON response.
struct PaymentsNetworkDispatcher {
    
    private let urlSession: URLSession
    
    static private var responseDataByIdempotencyKey: [String: [String: Any]] = [:] // [idempotencyKey: data]
    static private var responseDataDispatch = DispatchQueue(label: "responseDataByIdempotencyKeyQueue")
    
    /// URLSession Initialization
    /// - Parameter urlSession: URLSession Dependency Injection
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    static public func getResponseDataBy(idempotencyKey: String) -> [String: Any]? {
        var result: [String: Any]?
        responseDataDispatch.sync {
            result = responseDataByIdempotencyKey[idempotencyKey]
        }
        return result
    }
    
    static private func storeResponseByIdempotencyKey(headers: HTTPHeaders?, request: URLRequest, data: Data) throws {
        guard let headers, let publishableKey = headers[HTTPHeaderField.idempotencyKey.rawValue] else {
            return
        }
        if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            responseDataDispatch.sync {
                PaymentsNetworkDispatcher.responseDataByIdempotencyKey[publishableKey] = dict
            }
        }
    }
}

// MARK: - Method
extension PaymentsNetworkDispatcher {
    /// Dispatches an URLRequest and returns a publisher
    /// - Parameter request: URLRequest
    /// - Returns: A publisher with the provided decoded data or an error
    func dispatch<ReturnModelType: Codable>(headers: HTTPHeaders?, request: URLRequest, decoder: JSONDecoder?) -> AnyPublisher<ReturnModelType, PaymentsNetworkRequestError> {
        // TODO: Refactor -> 包一層 Subject 讓其可被再次觸發
        return self.urlSession.dataTaskPublisher(for: request)
            .tryMap { responseOutput in
                try dispatchHandleResponseToData(headers: headers, request: request, responseOutput: responseOutput)
            }
            .tryMap(dispatchCheckData(data:))
            .decode(type: ReturnModelType.self, decoder: decoder ?? JSONDecoder())
            .mapError(dispatchMapError(error:))
            .eraseToAnyPublisher()
    }
    
    private func dispatchHandleResponseToData(headers: HTTPHeaders?, request: URLRequest, responseOutput: URLSession.DataTaskPublisher.Output) throws -> Data {
        let data = responseOutput.data
        
#if DEBUG
        print("[PaymentsNetworkDispatcher] ResponseData: \(String(data: data, encoding: .utf8) ?? "nil")")
#endif
        
        do {
            try PaymentsNetworkDispatcher.storeResponseByIdempotencyKey(headers: headers, request: request, data: data)
        } catch {
            // do nothing
        }
        
        do {
            try logger(request: request, data: data)
        } catch {
            PWLogger.e(NSError(domain: "PaymentsNetworkDispatcher::dispatch::loggererror", code: 0, userInfo: ["msg": error.localizedDescription]))
        }
        
        // If the response is invalid, throw an error
        guard let httpResponse = responseOutput.response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            PWLogger.e(NSError(domain: "PaymentsNetworkDispatcher::dispatch::httperror", code: 0, userInfo: ["msg": String(data: data, encoding: .utf8) ?? "nil"]))
            // Decode error data using our ErrorType
            throw handlePaymentResponseFailure(data: data)
        }
        
        // header info
        let field = HTTPHeaderField.accessToken.rawValue
        if let token = httpResponse.value(forHTTPHeaderField: field) {
            // update access token
            let center = NotificationCenter.default
            center.post(name: .updateAccessToken, object: nil, userInfo: [field: token])
        }
        
        // TODO: Refactor -> 讓其可直接傳空值出去，並觸發完成
        return data
    }
    
    private func dispatchCheckData(data: Data) throws -> Data {
        guard !data.isEmpty else {
            return try JSONEncoder().encode(Return.Empty() )
        }
        return data
    }
    
    private func dispatchMapError(error: Error) -> PaymentsNetworkRequestError {
        if let error = error as? PaymentsNetworkRequestError {
            switch error {
            case .grantIncorrect:
                // Too many grantIncorrect error
                break
            default:
                PWLogger.e(NSError(domain: "PaymentsNetworkDispatcher::dispatch::mapError", code: 0, userInfo: ["error": error]))
            }
        }
        return handlePaymentsRequestError(error)
    }
}

// MARK: - Private Method
extension PaymentsNetworkDispatcher {
    
    private func logger(request: URLRequest, data: Data) throws {
        // TODO: For payment tracking only, needs to remove on 202401.
        
        var zipBodyStr: String?
        if let body = request.httpBody {
            let zipBodyData = try body.gzipped(level: .bestCompression)
            zipBodyStr = zipBodyData.base64EncodedString()
        }
        
        let zipData = try data.gzipped(level: .bestCompression)
        let zipResponseStr = zipData.base64EncodedString()
        PWLogger.e(NSError(domain: "PaymentsNetworkDispatcher::dispatch", code: 0, userInfo: ["url": request.url?.absoluteString ?? "unknown url", "zipBodyStr": zipBodyStr ?? "no request body", "zipResponseStr": zipResponseStr]))
    }
}

// MARK: - Error methods
extension PaymentsNetworkDispatcher {
    
    private func handlePaymentResponseFailure(data: Data?) -> PaymentsNetworkRequestError {
        // Check
        guard let data = data else {
            // Invalid data
            return PaymentsNetworkRequestError.dataCorrupted()
        }
        
        do {
            // Decode
            let decoder = JSONDecoder()
            let error = try decoder.decode(Return.ErrorData.self, from: data)
            
            // https://docs.google.com/spreadsheets/d/1umifHa_X87g_HA5pVTIM5VuBzpKhfOSg3qw4mTOnPto/edit#gid=2089159530
            
            switch error.errorCode {
            case "passcodeConfirmedIncorrect":
                return .passcodeConfirmedIncorrect(data)
            case "PasscodeIncorrect":
                return .passcodeIncorrect(data)
            case "PasscodeInvalid":
                return .passcodeInvalid(data)
            case "PasscodeRestricted":
                return .passcodeRestricted(data)
            case "UserPasscodeIncorrect":
                return .userPasscodeIncorrect(data)
            case "UserStatusIncorrect":
                return .userStatusIncorrect(data)
            case "VerifiedCodeIncorrect":
                return .verifiedCodeIncorrect(data)
            case "VerifiedCodeInvalid":
                return .verifiedCodeInvalid(data)
            case "VerifiedCodeRestricted":
                return .verifiedCodeRestricted(data)
            case "AccountBalanceIsNull":
                return .accountBalanceIsNull(data)
            case "AccountWrong":
                return .accountWrong(data)
            case "AmountMustGreaterThanZero":
                return .amountMustGreaterThanZero(data)
            case "ConsecutiveLoginAttemptFail":
                return .consecutiveLoginAttemptFail(data)
            case "CreateScaAuthFail":
                return .createScaAuthFail(data)
            case "CreditCardServiceUnavailable":
                return .creditCardServiceUnavailable(data)
            case "CurrencyUnsupported":
                return .currencyUnsupported(data)
            case "DepositLessThanLowerLimit":
                return .depositLessThanLowerLimit(data)
            case "DepositMoreThanTotalLimit":
                return .depositMoreThanTotalLimit(data)
            case "DepositMoreThanUpperLimit":
                return .depositMoreThanUpperLimit(data)
            case "DuplicatedLoginDetected":
                return .duplicatedLoginDetected(data)
            case "GrantIncorrect":
                return .grantIncorrect(data)
            case "InputsRequired":
                return .inputsRequired(data)
            case "InternalError":
                return .internalError(data)
            case "InvalidInstalmentAmount":
                return .invalidInstalmentAmount(data)
            case "InvalidNumberOfInstallments":
                return .invalidNumberOfInstallments(data)
            case "InvalidOperation":
                return .invalidOperation(data)
            case "IssuerBankUnsupported":
                return .issuerBankUnsupported(data)
            case "LoginVerificationRequired":
                return .loginVerificationRequired(data)
            case "NotFound":
                return .notFound(data)
            case "NumberOfInstallmentsNotSupport":
                return .numberOfInstallmentsNotSupport(data)
            case "PanExisted":
                return .panExisted(data)
            case "PayTypeUnsupported":
                return .payTypeUnsupported(data)
            case "PaymentMethodIncorrect":
                return .paymentMethodIncorrect(data)
            case "PaymentMethodInvalid":
                return .paymentMethodInvalid(data)
            case "PaymentMethodNotFound":
                return .paymentMethodNotFound(data)
            case "ProviderUnsupported":
                return .providerUnsupported(data)
            case "QueryTypeInvalid":
                return .queryTypeInvalid(data)
            case "RevokeCoBrandCardBindFail":
                return .revokeCoBrandCardBindFail(data)
            case "StoredValueServiceUnavailable":
                return .storedValueServiceUnavailable(data)
            case "StoredValuesSettingRequired":
                return .storedValuesSettingRequired(data)
            case "TokenAbandoned":
                return .tokenAbandoned(data)
            case "TokenInvalid":
                return .tokenInvalid(data)
            case "TokenUnauthorized":
                return .tokenUnauthorized(data)
            case "TooManyRequests":
                return .tooManyRequests(data)
            case "TradeIdInvalid":
                return .tradeIdInvalid(data)
            case "TradeIdRequired":
                return .tradeIdRequired(data)
            case "TransactionExist":
                return .transactionExist(data)
            case "TransactionTypeUnsupported":
                return .transactionTypeUnsupported(data)
            case "TxnTokenInvalid":
                return .txnTokenInvalid(data)
            case "VerifiedCodeTempRestricted":
                return .verifiedCodeTempRestricted(data)
            case "WalletServiceUnavailable":
                return .walletServiceUnavailable(data)
            case "WalletUserBundleNotFound":
                return .walletUserBundleNotFound(data)
            default:
                return .unknownError()
            }
        } catch {
            // Decode fail
            return PaymentsNetworkRequestError.decodingError("Error decode fail.")
        }
    }
    
    /// Parses URLSession Publisher errors and return proper ones
    /// - Parameter error: URLSession publisher error
    /// - Returns: Readable NetworkRequestError
    private func handlePaymentsRequestError(_ error: Error) -> PaymentsNetworkRequestError {
        switch error {
        case let error as Swift.DecodingError:
            handleDecodingError(error: error)
            return .decodingError(error.localizedDescription)
        case let urlError as URLError:
            return .urlSessionFailed(urlError)
        case let error as PaymentsNetworkRequestError:
            handleWalletGlobalError(error: error)
            return error
        default:
            return .unknownError()
        }
    }
    
    private func handleWalletGlobalError(error: PaymentsNetworkRequestError) {
        switch error {
        case .tokenAbandoned, .tokenUnauthorized, .duplicatedLoginDetected:
            let key = Notification.Name.walletGlobalErrorHandling.rawValue
            NotificationCenter.default.post(name: .walletGlobalErrorHandling, object: nil, userInfo: [key: error])
        default:
            break
        }
    }
    
    private func handleDecodingError(error: Swift.DecodingError) {
        switch error {
        case .valueNotFound(let key, let value):
            PWLogger.e(NSError(domain: "PaymentsNetworkDispatcher.DecodingError.valueNotFound", code: 0, userInfo: ["msg": error.localizedDescription, "idempotencyKey-latest": PWLogger.idempotencyKey ?? "", "key": key, "value": value]))
        case .typeMismatch(let key, let value):
            PWLogger.e(NSError(domain: "PaymentsNetworkDispatcher.DecodingError.typeMismatch", code: 0, userInfo: ["msg": error.localizedDescription, "idempotencyKey-latest": PWLogger.idempotencyKey ?? "", "key": key, "value": value]))
        case .keyNotFound(let key, let value):
            PWLogger.e(NSError(domain: "PaymentsNetworkDispatcher.DecodingError.keyNotFound", code: 0, userInfo: ["msg": error.localizedDescription, "idempotencyKey-latest": PWLogger.idempotencyKey ?? "", "key": key, "value": value]))
        case .dataCorrupted(let key):
            PWLogger.e(NSError(domain: "PaymentsNetworkDispatcher.DecodingError.dataCorrupted", code: 0, userInfo: ["msg": error.localizedDescription, "idempotencyKey-latest": PWLogger.idempotencyKey ?? "", "key": key]))
        @unknown default:
            PWLogger.e(NSError(domain: "PaymentsNetworkDispatcher.DecodingError.unknown", code: 0, userInfo: ["msg": error.localizedDescription, "idempotencyKey-latest": PWLogger.idempotencyKey ?? ""]))
        }
    }
}
//
//  NetworkClientProtocol.swift
//  NYCore
//
//  T5: NetworkClientProtocol 設計
//  核心 Swift-first Protocol，配套型別：RequestOptions、NetworkResponse、RequestContext、RequestMatcher。
//  ObjC 橋接層不在此檔；由 T6 的 NetworkClientObjCBridge.swift 處理。

import Foundation

// MARK: - Request Type (Swift mirror for NYHTTPRequestType)

/// Swift mirror for `NYHTTPRequestType`。
///
/// 映射關係：
/// - `.fixedFloat` ↔ `NYHTTPRequestTypeFixedFloat`
/// - `.http`       ↔ `NYHTTPRequestTypeHTTP`
/// - `.json`       ↔ `NYHTTPRequestTypeJSON`
public enum RequestType {
    case fixedFloat
    case http
    case json
}

// MARK: - Response Type (Swift mirror for NYHTTPResponseType)

/// Swift mirror for `NYHTTPResponseType`。
///
/// 映射關係：
/// - `.http` ↔ `NYHTTPResponseTypeHTTP`
/// - `.json` ↔ `NYHTTPResponseTypeJSON`
public enum ResponseType {
    case http
    case json
}

// MARK: - RequestOptions

/// 單次請求的可選參數，取代散落於各呼叫點的參數組合。
///
/// 對應合約：M7（預設 timeout 30s）、M12（per-request timeout 覆寫）。
public struct RequestOptions {
    /// 請求序列化方式（對應合約 M4–M6）。
    public var requestType: RequestType

    /// 回應反序列化方式。
    public var responseType: ResponseType

    /// 請求逾時秒數；nil 代表使用預設值 30s（合約 M7）。
    /// 非 nil 時覆寫預設值（合約 M12）。
    public var timeout: TimeInterval?

    /// 附加 HTTP headers，由呼叫端注入（不覆蓋 interceptor 設定的 headers）。
    public var additionalHeaders: [String: String]

    public init(
        requestType: RequestType,
        responseType: ResponseType,
        timeout: TimeInterval? = nil,
        additionalHeaders: [String: String] = [:]
    ) {
        self.requestType = requestType
        self.responseType = responseType
        self.timeout = timeout
        self.additionalHeaders = additionalHeaders
    }

    /// 預設值：HTTP request、JSON response、30s timeout。
    public static let `default` = RequestOptions(
        requestType: .http,
        responseType: .json
    )
}

// MARK: - NetworkResponse

/// 解碼成功後的回應，包含型別化 value 與 HTTP 層級資訊。
///
/// `task` 供 NotificationInterceptor 廣播用（合約 N1、N2）。
public struct NetworkResponse<T> {
    public let value: T
    public let httpResponse: HTTPURLResponse
    public let task: URLSessionTask

    public init(value: T, httpResponse: HTTPURLResponse, task: URLSessionTask) {
        self.value = value
        self.httpResponse = httpResponse
        self.task = task
    }
}

// MARK: - RequestContext

/// 貫穿整條 interceptor chain 的請求上下文。
///
/// `task` 由 NetworkClient 在 `resume()` 後填入，供 post-response interceptor 使用。
public struct RequestContext {
    public let method: HTTPMethod
    public let path: String
    public let options: RequestOptions

    /// 由 NetworkClient 在任務建立後填入；pre-request 階段為 nil。
    public var task: URLSessionTask?

    public init(
        method: HTTPMethod,
        path: String,
        options: RequestOptions,
        task: URLSessionTask? = nil
    ) {
        self.method = method
        self.path = path
        self.options = options
        self.task = task
    }
}

// MARK: - RequestMatcher

/// 取消請求的匹配條件。
///
/// 對應合約 B2 修正版：用 `.path`（非 `.absoluteString`）比對路徑。
public enum RequestMatcher {
    /// 取消符合特定 method + path 組合的請求。
    case methodAndPath(HTTPMethod, String)

    /// 取消所有進行中的請求。
    case all
}

// MARK: - NetworkClientProtocol

/// 核心網路客戶端 Protocol，Swift-first async throws 介面。
///
/// ObjC callback 橋接不在此 Protocol；由 `NetworkClientObjCBridge`（T6）薄層包裝。
///
/// ## 合約覆蓋（T5 驗收）
///
/// ### T1 Request Mutation（M1–M18）
/// | 合約    | 對應位置                                                      |
/// |---------|---------------------------------------------------------------|
/// | M1      | CommonHeaderInterceptor — appVer 無條件覆寫（T6）             |
/// | M2      | NetworkClient.request() 實作 — URL path 正規化（T6）          |
/// | M3      | ShopIdLangInterceptor — parameters nil guard + mutableCopy（T6）|
/// | M4,M5   | ShopIdLangInterceptor — GET: shopId/lang 注入 query（T6）    |
/// | M6      | ShopIdLangInterceptor — Non-GET: shopId/lang 附加 query（T6）|
/// | M7      | TimeoutInterceptor + RequestOptions.timeout — 預設 30s       |
/// | M8      | NetworkClient 實作 — URLRequest 建立（T6）                   |
/// | M9      | CookieInterceptor — uAuth 強制更新（T6）                     |
/// | M10     | AuthLangHeaderInterceptor — Accept-Language（T6）            |
/// | M11     | AuthLangHeaderInterceptor — Authorization header（T6）       |
/// | M12     | RequestOptions.timeout — per-request 覆寫                    |
/// | M13     | CookieInterceptor — HTTPShouldHandleCookies 啟用（T6）       |
/// | M14     | CommonHeaderInterceptor — ny-idempotency-key（T6）           |
/// | M15     | CommonHeaderInterceptor — n1-shop-id（T6）                   |
/// | M16(B1) | per-request serializer，不寫入 self（T6 實作責任）           |
/// | M17     | SSLPolicyInterceptor — 測試環境 SSL Policy 放寬（T6）        |
/// | M18     | CommonHeaderInterceptor — Content-Type per-request 設定（T6）|
///
/// ### T2 Logout State Machine（L1–L13）
/// | 合約    | 對應位置                                                                |
/// |---------|-------------------------------------------------------------------------|
/// | L1      | LogoutCheckInterceptor — success 路徑中判斷 session 過期（T7）         |
/// | L2      | LogoutCheckInterceptor — logoutWithURL 用 url.path + regex（T7）       |
/// | L3      | LogoutCheckInterceptor — logoutAPICheckList lazy-init（T7）            |
/// | L4      | LogoutCheckInterceptor — ignoreAuthExpireLogoutEnabled 抑制（T7）      |
/// | L5      | LogoutCheckInterceptor — loginAgain 路徑不發 NYLogoutNotification（T7）|
/// | L6      | LogoutCheckInterceptor — 一般 logout 發 NYLogoutNotification（T7）     |
/// | L7      | LogoutCheckInterceptor — cleanAllSettings 外部注入 block（T7）         |
/// | L8      | LogoutCheckInterceptor — isLogin guard 防重複清理（T7）                |
/// | L9      | LogoutCheckInterceptor — loginAgain 參數控制是否呈現登入頁（T7）       |
/// | L10     | LogoutCheckInterceptor — Facebook token 路徑直呼 cleanAllSettings（T7）|
/// | L11     | LogoutCheckInterceptor — logoutWithURL first-match 語意（T7）          |
/// | L12     | LogoutCheckInterceptor — WebView idleLogout 雙條件（T7）               |
/// | L13     | LogoutCheckInterceptor — App 強制版本登出（T7）                        |
///
/// ### T3 Notification（N1–N7）
/// | 合約    | 對應位置                                                                      |
/// |---------|-------------------------------------------------------------------------------|
/// | N1      | NotificationInterceptor — apiRequest 通知，在 resume 前發送（T7）            |
/// | N2      | NotificationInterceptor — apiResponse 通知，在 callback 前發送（T7）         |
/// | N3      | NYAPIResponseTimeMonitorManager Observer — apiRequest（既有元件，不在此 Protocol）|
/// | N4      | NYAPIResponseTimeMonitorManager Observer — apiResponse（既有元件，不在此 Protocol）|
/// | N5      | NYAgathaManager Observer — apiTimeout（既有元件，不在此 Protocol）            |
/// | N6      | NYAgathaManager — launchTimeout 發送與 Observer（既有元件，不在此 Protocol）  |
/// | N7      | NotificationInterceptor — apiTimeout 通知發送（T7）                          |
///
/// ### T4 Semaphore（S1–S8）
/// | 合約    | 對應位置                                                                      |
/// |---------|-------------------------------------------------------------------------------|
/// | S1–S3   | async/await 原生取代 DispatchSemaphore；sync 方法廢棄（T6）                  |
/// | S4      | async/await — AnyPromise postPath 同步語意由 async/await 取代（T6）          |
/// | S5      | async/await — getCDNDomainSynchronously 改為 async（T6）                     |
/// | S6      | async/await — registerAPP barrier_sync 改為 structured concurrency（T6）     |
/// | S7      | NYTrackingClient — 子類別 semaphore，獨立於 NetworkClientProtocol（T6 評估） |
/// | S8      | NYAppAnnouncementHelper — 5s 超時 semaphore，獨立元件（T6 評估）             |
///
/// ### Bug 修正
/// | 合約    | 對應位置                                                      |
/// |---------|---------------------------------------------------------------|
/// | B2      | cancel(matching:) 用 `.path` 比對（非 `.absoluteString`）    |
/// | B3      | resolve responseObject（非 responseType）（T6 實作責任）     |
public protocol NetworkClientProtocol {

    /// 送出請求並以 async/await 等待結果。
    ///
    /// - Parameters:
    ///   - method: HTTP 方法。
    ///   - path: API 路徑（不含 base URL）。
    ///   - parameters: 請求參數；GET 轉 query string，non-GET 轉 request body。
    ///   - options: 請求選項；預設使用 `RequestOptions.default`。
    /// - Returns: 解碼後的回應與 HTTP 層級資訊。
    /// - Throws: `NetworkError` 或解碼相關 error。
    func request<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        parameters: [String: Any]?,
        options: RequestOptions
    ) async throws -> NetworkResponse<T>

    /// 取消符合條件的進行中請求（對應合約 B2 修正版）。
    func cancel(matching: RequestMatcher)

    /// 取消所有進行中的請求。
    func cancelAll()
}

// MARK: - NetworkClientProtocol + Encrypted (特殊路徑)

public extension NetworkClientProtocol {

    /// AES-CBC + HMAC 加密請求（RegistAPP、MemberCard 等特殊 API）。
    ///
    /// 此為擴充方法，由支援加密的 concrete client 覆寫；
    /// 預設實作拋出 `NetworkError.unknown`，明確告知呼叫端該功能未支援。
    func requestEncrypted<T: Decodable>(
        _ method: HTTPMethod,
        path: String,
        parameters: [String: Any]?,
        options: RequestOptions
    ) async throws -> NetworkResponse<T> {
        throw NetworkError.unknown(
            NSError(
                domain: "NetworkClientProtocol",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "requestEncrypted not implemented by this client"]
            )
        )
    }
}
