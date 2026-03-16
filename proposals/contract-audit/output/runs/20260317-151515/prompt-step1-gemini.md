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



## Step 0 Discovery Note
The following related files were found by static scan (not included in full -- reference them in Section 4):
- /Users/justinlee/dev/nineyiappshop/91Modules/payments91app/Sources/Payments91App/PaymentsCore/Networking/PaymentsNetworkDispatcher.swift
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
