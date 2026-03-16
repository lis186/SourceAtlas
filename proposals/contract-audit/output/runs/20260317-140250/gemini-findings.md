Contract: Global Singleton Access
Category: D
Trigger:  Accessing the `PaymentsNetworkManager.shared` static property.
Effect:   Binds the caller to a single, globally shared instance of `PaymentsNetworkManager`, creating an implicit dependency that affects state and testability.
Evidence: PaymentsNetworkManager.swift:16 -- `public static let shared = PaymentsNetworkManager()`

Contract: Asynchronous Result Propagation
Category: P
Trigger:  Calling any public network method (e.g., `multipassLogin`, `getThemeConfiguration`).
Effect:   The success or failure result of the network operation is propagated asynchronously to the caller via an `@escaping` completion handler.
Evidence: PaymentsNetworkManager.swift:27 -- `completion: @escaping (Result<PaymentsRequest.Post.MultipassLogin.ReturnType, PaymentsNetworkRequestError>) -> Void)`

Contract: Subscription Lifecycle Management
Category: L
Trigger:  A network request method is called.
Effect:   The Combine subscription for the network request is stored, tying its lifetime to the lifetime of the `PaymentsNetworkManager` instance itself.
Evidence: PaymentsNetworkManager.swift:18 -- `private var cancellables: Set<AnyCancellable> = []`

Contract: Implicit Cancellation on Dealloc
Category: C
Trigger:  The `PaymentsNetworkManager` instance is deallocated.
Effect:   All in-flight network requests are automatically cancelled as their subscriptions stored in the `cancellables` set are released.
Evidence: PaymentsNetworkManager.swift:45 -- `.store(in: &self.cancellables)`

Contract: Explicit Error Forwarding
Category: E
Trigger:  A network request fails and the Combine pipeline emits a `.failure`.
Effect:   The `PaymentsNetworkRequestError` is caught and explicitly passed to the caller's completion handler as a `.failure` case, ensuring no errors are silently swallowed.
Evidence: PaymentsNetworkManager.swift:42 -- `case .failure(let error): completion(.failure(error))`

Contract: Implicit Network Timeout Dependency
Category: D
Trigger:  Calling `multipassLogin`, `getThemeConfiguration`, or `getSettings`.
Effect:   An underlying `URLSession` with a hardcoded 10-second request timeout is used, creating a dependency on specific network conditions.
Evidence: PaymentsNetworkManager.swift:932 -- `configuration.timeoutIntervalForRequest = 10`

Contract: Implicit Default Session Dependency
Category: D
Trigger:  Calling any network method other than `multipassLogin`, `getThemeConfiguration`, or `getSettings`.
Effect:   An underlying `URLSession` is created with `.default` configuration, creating a dependency on the system's default caching, cookie, and credential policies.
Evidence: PaymentsNetworkManager.swift:120 -- `let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))`

Contract: Console Log Mutation
Category: M
Trigger:  A network request's Combine pipeline sends a `.finished` event.
Effect:   A log message is printed to the console, a side effect that mutates the standard output stream.
Evidence: PaymentsNetworkManager.swift:40 -- `print("MultipassLogin completed with: \(result.self)")`

TOTAL CONTRACTS FOUND: 8
CATEGORY BREAKDOWN: M=[1] L=[1] N=[0] S=[0] E=[1] C=[1] D=[3] P=[1]

EXTERNAL_DEPENDENCY: ViewModel or UIViewController classes (e.g., CheckoutViewModel, SettingsViewController) -- They are the likely callers of the public methods and provide the `completion` handlers to receive network results and update UI state.
EXTERNAL_DEPENDENCY: Any class calling PaymentsNetworkManager.shared from a background thread -- The shared singleton instance is not internally synchronized, so callers on background threads must provide their own synchronization to avoid race conditions when initiating requests.
EXTERNAL_DEPENDENCY: The application's main lifecycle manager (e.g., AppDelegate or a root coordinator) -- It implicitly controls the lifecycle of the singleton. Because a singleton is typically never deallocated, this implies network requests are not cancelled during the app's runtime via deallocation.
EXTERNAL_DEPENDENCY: `PaymentsAPIClient` -- Instantiated in every method to dispatch the created request. It is a direct downstream dependency for all network operations.
EXTERNAL_DEPENDENCY: `PaymentsNetworkDispatcher.swift` -- Instantiated in every method to handle the low-level network call, it is a required component for `PaymentsAPIClient`.
EXTERNAL_DEPENDENCY: Call-site closures within various services or ViewModels -- These closures are the endpoints for the propagated `Result` type and are responsible for handling the success data or failure errors returned by the API.
ClearcutLogger: Flush already in progress, marking pending flush.
