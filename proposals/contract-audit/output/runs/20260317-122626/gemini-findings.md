Contract: Singleton Access
Category: D
Trigger:  Accessing the `PaymentsNetworkManager.shared` static property.
Effect:   Ensures that all callers use the same instance of `PaymentsNetworkManager`, creating a global dependency.
Evidence: PaymentsNetworkManager.swift:13 -- `public static let shared = PaymentsNetworkManager()`

Contract: Combine Subscription Lifetime
Category: M
Trigger:  Any public method that performs a network request.
Effect:   A new `AnyCancellable` is added to the internal `cancellables` set, mutating the manager's state.
Evidence: PaymentsNetworkManager.swift:34 -- `}.store(in: &self.cancellables)`

Contract: Network Request Cancellation
Category: C
Trigger:  Deallocation of the `PaymentsNetworkManager` instance.
Effect:   All `AnyCancellable` objects stored in the `cancellables` set are automatically cancelled, terminating any in-flight network requests initiated by this instance.
Evidence: PaymentsNetworkManager.swift:15 -- `private var cancellables: Set<AnyCancellable> = []`

Contract: Ephemeral Network Stack
Category: L
Trigger:  Entry into any public network request method (e.g., `multipassLogin`).
Effect:   A new `PaymentsNetworkDispatcher` and `PaymentsAPIClient` are instantiated for the duration of the single API call. They are not reused.
Evidence: PaymentsNetworkManager.swift:28 -- `let dispatcher = PaymentsNetworkDispatcher(urlSession: .tenSecondsTimeout)`

Contract: Asynchronous Callback Notification
Category: N
Trigger:  Completion of any network request initiated by a public method.
Effect:   The provided `@escaping completion` closure is invoked with the result of the operation. This serves as a notification to the original caller.
Evidence: PaymentsNetworkManager.swift:23 -- `completion: @escaping (Result<PaymentsRequest.Post.MultipassLogin.ReturnType, PaymentsNetworkRequestError>) -> Void)`

Contract: Error Propagation via Result Type
Category: E
Trigger:  A network request failing within the Combine pipeline.
Effect:   The failure is caught, wrapped in a `.failure` case of the `Result` type, and propagated to the caller via the `completion` handler.
Evidence: PaymentsNetworkManager.swift:32 -- `completion(.failure(error))`

Contract: Success Value Propagation
Category: P
Trigger:  A network request succeeding and emitting a value.
Effect:   The decoded value from the API response is wrapped in a `.success` case of the `Result` type and propagated to the caller via the `completion` handler.
Evidence: PaymentsNetworkManager.swift:34 -- `receiveValue: { value in completion(.success(value)) }`

Contract: Debug Logging
Category: P
Trigger:  The Combine pipeline for a network request finishing, regardless of success or failure.
Effect:   A message is printed to the console, propagating the result status outside the application's primary data flow.
Evidence: PaymentsNetworkManager.swift:30 -- `print("MultipassLogin completed with: \(result.self)")`

TOTAL CONTRACTS FOUND: 8
CATEGORY BREAKDOWN: M=[1] L=[1] N=[1] S=[0] E=[1] C=[1] D=[1] P=[2]

EXTERNAL_DEPENDENCY: PaymentsNetworkDispatcher -- Instantiated by every network call to dispatch the request.
EXTERNAL_DEPENDENCY: PaymentsAPIClient -- Instantiated by every network call to manage the API communication.
EXTERNAL_DEPENDENCY: Callers of `multipassLogin`, `getThemeConfiguration`, etc. -- These are the observers that provide the completion handler and consume the result.
EXTERNAL_DEPENDENCY: Any class accessing `PaymentsNetworkManager.shared` -- Depends on the singleton instance for making payments-related network calls.
