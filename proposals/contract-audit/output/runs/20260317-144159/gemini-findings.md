Contract: Singleton Access
Category: D
Trigger:  Accessing `PaymentsNetworkManager.shared`
Effect:   All callers are coupled to a single, globally shared instance of the network manager.
Evidence: PaymentsNetworkManager.swift:10 -- `public static let shared = PaymentsNetworkManager()`

Contract: Network Request Cancellation
Category: C
Trigger:  The `PaymentsNetworkManager` instance is deallocated or the `cancellables` set is cleared.
Effect:   All in-flight Combine network requests initiated by this instance are cancelled.
Evidence: PaymentsNetworkManager.swift:12 -- `private var cancellables: Set<AnyCancellable> = []`

Contract: API Result Propagation
Category: P
Trigger:  An API call completes successfully.
Effect:   The decoded result is passed to the caller via an escaping completion handler.
Evidence: PaymentsNetworkManager.swift:34 -- `completion(.success(value))`

Contract: API Error Propagation
Category: E
Trigger:  An API call fails at the network or decoding layer.
Effect:   The specific `PaymentsNetworkRequestError` is passed to the caller via an escaping completion handler.
Evidence: PaymentsNetworkManager.swift:31 -- `completion(.failure(error))`

Contract: Unhandled API Completion
Category: E
Trigger:  An API call finishes its Combine pipeline (`.finished`).
Effect:   A debug message is printed to the console, but no information is propagated to the caller. This can hide the distinction between a successful completion with a value and a successful completion with no value.
Evidence: PaymentsNetworkManager.swift:29 -- `print("MultipassLogin completed with: \(result.self)")`

Contract: Implicit Network Timeout
Category: D
Trigger:  Calling `multipassLogin`, `getThemeConfiguration`, or `getSettings`.
Effect:   The underlying network request will fail if it does not complete within a hardcoded 10-second window.
Evidence: PaymentsNetworkManager.swift:25 -- `let dispatcher = PaymentsNetworkDispatcher(urlSession: .tenSecondsTimeout)`

Contract: Default Network Timeout
Category: D
Trigger:  Calling any API method other than `multipassLogin`, `getThemeConfiguration`, or `getSettings`.
Effect:   The network request uses the `URLSession` default timeout, which may differ from the 10-second timeout used elsewhere.
Evidence: PaymentsNetworkManager.swift:122 -- `let dispatcher = PaymentsNetworkDispatcher(urlSession: URLSession(configuration: .default))`

Contract: Remote State Mutation
Category: M
Trigger:  Calling methods that perform `POST`, `PUT`, or `DELETE` operations (e.g., `postTransactionPasscodes`, `putTransactionPasscodes`).
Effect:   Sends a request to a remote server with the intention of creating, updating, or deleting data.
Evidence: PaymentsNetworkManager.swift:119 -- `let request = PaymentsRequest.Post.TransactionPasscodesSet(...)`

Contract: Idempotency Key Dependency
Category: D
Trigger:  Calling `postPayments`, `postPaymentCodes`, or `postStoredValues`.
Effect:   The caller is required to provide a unique `idempotencyKey` to prevent duplicate operations, making the caller responsible for generating and managing this key.
Evidence: PaymentsNetworkManager.swift:513 -- `idempotencyKey: String,`

Contract: Temporary POST Compatibility
Category: L
Trigger:  Calling the `pendingPayments` method.
Effect:   The method is explicitly marked as temporarily using POST for a GET operation, implying a future state transition where this behavior will change.
Evidence: PaymentsNetworkManager.swift:425 -- `// TODO: 此 API 暫時兼容 POST`

TOTAL CONTRACTS FOUND: 10
CATEGORY BREAKDOWN: M=[1] L=[1] N=[0] S=[0] E=[2] C=[1] D=[4] P=[1]

EXTERNAL_DEPENDENCY: PaymentsNetworkDispatcher.swift -- This class is instantiated in every API call to handle the actual network dispatching.
EXTERNAL_DEPENDENCY: PaymentsAPIClient.swift -- This class is instantiated in every API call and uses the dispatcher to execute `PaymentsRequest` objects.
EXTERNAL_DEPENDENCY: PaymentsRequest.swift -- This file (or files) defines the structures for all API requests (e.g., `PaymentsRequest.Post.MultipassLogin`).
EXTERNAL_DEPENDENCY: Body.swift -- This file likely defines the request body structures like `Body.Multipass`, `Body.PasscodesSet`, etc., used to create request dictionaries.
EXTERNAL_DEPENDENCY: PaymentsNetworkRequestError.swift -- This file defines the custom error type used in all completion handlers.
EXTERNAL_DEPENDENCY: (Any caller of PaymentsNetworkManager.shared) -- Any module that uses the singleton (e.g., a view model for a payment screen) depends on this manager to perform its functions.
ClearcutLogger: Flush already in progress, marking pending flush.
