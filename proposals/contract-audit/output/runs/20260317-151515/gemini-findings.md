Contract: Singleton Instance
Category: D
Trigger:  Accessing `PaymentsNetworkManager.shared`
Effect:   Ensures that all callers across the application use the same single instance of `PaymentsNetworkManager`, creating a global state dependency.
Evidence: PaymentsNetworkManager.swift:13 -- `public static let shared = PaymentsNetworkManager()`

Contract: Request Lifecycle Management
Category: L
Trigger:  Any network request method is called (e.g., `multipassLogin`).
Effect:   The Combine subscription for the network request is stored in a private `cancellables` set. This ties the lifecycle of the request to the lifecycle of the `PaymentsNetworkManager` singleton. If the singleton were to be deallocated (which is unlikely in a typical app lifecycle), all ongoing requests would be cancelled.
Evidence: PaymentsNetworkManager.swift:44 -- `.store(in: &self.cancellables)`

Contract: Asynchronous Result Propagation via Completion
Category: P
Trigger:  A network request method successfully completes.
Effect:   The decoded value from the network response is passed back to the original caller through the `completion` handler.
Evidence: PaymentsNetworkManager.swift:43 -- `receiveValue: { value in completion(.success(value)) }`

Contract: Explicit Error Propagation
Category: E
Trigger:  A network request method fails at any point in the Combine chain.
Effect:   The `PaymentsNetworkRequestError` is caught and propagated to the original caller via the `.failure` case of the `completion` handler's `Result` type.
Evidence: PaymentsNetworkManager.swift:40 -- `completion(.failure(error))`

Contract: Implicit Cancellation
Category: C
Trigger:  The `PaymentsNetworkManager` instance is deallocated.
Effect:   All `AnyCancellable` objects stored in the `cancellables` set are automatically cancelled, which terminates any in-flight network requests initiated by this manager.
Evidence: PaymentsNetworkManager.swift:15 -- `private var cancellables: Set<AnyCancellable> = []`

Contract: Internal Dependency Creation
Category: D
Trigger:  Any public network request method is called.
Effect:   A new `PaymentsNetworkDispatcher` and `PaymentsAPIClient` are instantiated for each API call, creating a dependency on these two classes to perform the actual network dispatch.
Evidence: PaymentsNetworkManager.swift:31 -- `let dispatcher = PaymentsNetworkDispatcher(urlSession: .tenSecondsTimeout)`

Contract: Unsafe Concurrent Mutation (uncertain)
Category: S
Trigger:  Multiple network request methods are called from different threads concurrently on the `shared` singleton instance.
Effect:   Multiple threads may attempt to write to the `cancellables` set simultaneously via the `.store(in: &self.cancellables)` call. Swift's `Set` is not thread-safe for concurrent modifications, which could lead to a crash or undefined behavior.
Evidence: PaymentsNetworkManager.swift:15 -- `private var cancellables: Set<AnyCancellable> = []`

Contract: Silent Failure on Finished
Category: E
Trigger:  The Combine publisher for a network request sends a `.finished` event without having sent a value.
Effect:   A debug message is printed to the console, but the caller's `completion` handler is never called. The caller will wait indefinitely for a result that never arrives.
Evidence: PaymentsNetworkManager.swift:38 -- `case .finished: print("MultipassLogin completed with: \(result.self)")`

TOTAL CONTRACTS FOUND: 8
CATEGORY BREAKDOWN: M=[0] L=[1] N=[0] S=[1] E=[2] C=[1] D=[2] P=[1]

---

EXTERNAL_DEPENDENCY: PaymentsAPIClient -- Used by every method in `PaymentsNetworkManager` to dispatch the created network request.
EXTERNAL_DEPENDENCY: PaymentsNetworkDispatcher -- Instantiated by every method in `PaymentsNetworkManager` and passed to `PaymentsAPIClient` to handle the low-level network communication.
EXTERNAL_DEPENDENCY: Any caller of `PaymentsNetworkManager.shared` -- Callers provide the completion handlers that are the endpoints for result propagation (P) and error handling (E).
EXTERNAL_DEPENDENCY: Combine framework -- The entire asynchronous pattern relies on Combine's Publishers, Subscribers (`sink`), and `AnyCancellable` for lifecycle management (L) and cancellation (C).
EXTERNAL_DEPENDENCY: PaymentsRequest -- This struct (and its nested types) is used to define the API request structure for every call, forming a data contract dependency.
