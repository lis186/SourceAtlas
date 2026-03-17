DISPUTE N-001: Category assignment is overstated; this is callback wiring, not pub/sub notification coupling.
  Evidence: PaymentsNetworkManager.swift:40-49 -- `.sink { result in ... } receiveValue: { value in completion(.success(value)) }`

DISPUTE N-002: "memory leak" is overstated; code proves accumulation risk, but not a strict leak claim from this file alone.
  Evidence: PaymentsNetworkManager.swift:49 -- `.store(in: &self.cancellables)` (no matching removal logic in file)

DISPUTE S-001: Reasoning overstates scheduler behavior; `store(in:)` occurs in call-site setup path, not shown here as scheduler-hopped mutation.
  Evidence: PaymentsNetworkManager.swift:40-49 -- `apiClient.dispatch(request).sink ... .store(in: &self.cancellables)` (single fluent setup chain)

CONFIRM D-001: Each method constructs `PaymentsNetworkDispatcher` then `PaymentsAPIClient` and dispatches request.
DISPUTE D-003: "external can instantiate extra instances" is imprecise; class is not `public`, so this is module-internal, not external API behavior.
  Evidence: PaymentsNetworkManager.swift:12 -- `class PaymentsNetworkManager {`

CONFIRM D-002: Timeout split is real: three methods use `.tenSecondsTimeout`, others use `.default`.
DISPUTE E-001: The stated "Void methods circumvent this" is incorrect; they still depend on `receiveValue` to fire success.
  Evidence: PaymentsNetworkManager.swift:113-125 -- `.finished` only prints; success only in `receiveValue: { _ in completion(.success(())) }`

CONFIRM E-002: Error propagation type is explicitly `PaymentsNetworkRequestError` through completion signatures and failure forwarding.
CONFIRM P-001: No `.receive(on:)`; completion thread is not fixed by this module.
DISPUTE C-001: "singleton never dealloc so only global-cancel" is overstated; non-shared instances are possible inside module and could deallocate.
  Evidence: PaymentsNetworkManager.swift:12 -- `class PaymentsNetworkManager {` (no private init shown)

CONFIRM M-001: Request bodies are consistently transformed via `toDictionary` before request creation.
DISPUTE M-002: Backend idempotency enforcement claim is speculative from this file; manager only forwards key, no local uniqueness/retry policy.
  Evidence: PaymentsNetworkManager.swift:651-700 -- `idempotencyKey: idempotencyKey` passthrough in request construction

ADD Subscription lifetime bound to manager instance:
  Category: L
  Trigger:  Any API method stores a new subscription.
  Effect:   Request subscription lifetime is tied to manager-held `cancellables`.
  Evidence: PaymentsNetworkManager.swift:18 -- `private var cancellables: Set<AnyCancellable> = []`

ADD Console logging side effect on completion:
  Category: M
  Trigger:  Combine emits `.finished`.
  Effect:   Writes completion log to stdout (`print`), creating observable side effect.
  Evidence: PaymentsNetworkManager.swift:40 -- `print("MultipassLogin completed with: \(result.self)")`

ADD [EXTERNAL] Caller-thread synchronization dependency:
  Category: D
  Trigger:  Multiple external callers invoke `PaymentsNetworkManager.shared` concurrently.
  Effect:   Correctness depends on caller-side threading discipline because shared mutable subscription store is unsynchronized.
  Evidence: [inferred from EXTERNAL_DEPENDENCY hint]

META_ISSUE N-001: Seam_Type -- `none` appears incorrect; callback handoff to caller is a `link` seam.
META_ISSUE E-001: Seam_Type -- `none` appears incorrect; failure/success callback contract crosses boundary (`link`).
META_ISSUE P-001: Seam_Type -- `none` appears incorrect; thread-context propagation is boundary behavior (`link`).
META_ISSUE M-002: Seam_Type -- `none` appears weak; idempotency behavior is cross-system dependency seam (`link`).

COVERAGE M: 3 contracts found -- OK
COVERAGE L: 1 contracts found -- SUSPECT_MISSING: Artifact 1 had none; only surfaced via Gemini.
COVERAGE N: 2 contracts found -- SUSPECT_MISSING: Dispatcher-side `NotificationCenter_post` anchor unresolved.
COVERAGE S: 1 contracts found -- SUSPECT_MISSING: Dispatcher-side `dispatch_sync` / queue contracts not audited.
COVERAGE E: 2 contracts found -- SUSPECT_MISSING: Dispatcher-side `throws`/`do-catch`/`Codable` anchors missing.
COVERAGE C: 1 contracts found -- OK
COVERAGE D: 4 contracts found -- SUSPECT_MISSING: Dispatcher conditional/singleton dependency anchors unresolved.
COVERAGE P: 1 contracts found -- SUSPECT_MISSING: Result propagation beyond callback thread semantics is under-specified.

SUMMARY
CONFIRM: 5
DISPUTE: 7
ADD: 3
META_ISSUE: 4
CONFIRM_RATIO: 42%DEGRADED=no
