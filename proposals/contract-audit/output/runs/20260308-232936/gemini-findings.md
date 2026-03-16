Contract: AES Key Fallback
Category: E
Trigger:  Internal `aesKey()` function call during encryption operations.
Effect:   If `[NYAESKeyManager decryptedAESKey]` returns nil, it silently falls back to using `[NYAESKeyManager fallbackKey]`.
Evidence: NYHTTPSClient.m:33 -- `return key ?: [NYAESKeyManager fallbackKey];`

Contract: Log Level Initializes File
Category: M
Trigger:  Calling `+[NYHTTPSClient setLogLevel:]` with `NYHTTPClientLogLevelAPIInfo`.
Effect:   Deletes the existing API log file by calling `[self initLogFile]`, which is a destructive side effect on the file system.
Evidence: NYHTTPSClient.m:51 -- `if (logLevel == NYHTTPClientLogLevelAPIInfo) { [self initLogFile]; }`

Contract: Singleton Initialization
Category: L
Trigger:  First-time access to `+[NYHTTPSClient sharedClient]`.
Effect:   Initializes and configures a global singleton instance using `dispatch_once`, setting the base URL and a security policy based on external configuration.
Evidence: NYHTTPSClient.m:59 -- `dispatch_once(&onceToken, ^{ _sharedClient = [[NYHTTPSClient alloc] initWithBaseURL:...]; ... });`

Contract: Request Parameter and Header Injection
Category: P
Trigger:  Any network request creation via internal `requestWithType:...` method.
Effect:   Mutates the request URL to include `shopId` and `lang` query parameters, and mutates headers to add `Accept-Language`, `Authorization`, `ny-idempotency-key`, and `n1-shop-id` based on global state.
Evidence: NYHTTPSClient.m:88-152 -- (multiple lines within `requestWithType:method:path:parameters:`)

Contract: Forced Cookie Update
Category: M
Trigger:  Creating any request via `requestWithType:method:path:parameters:`.
Effect:   Forces an update to the 'uAuth' cookie by calling `[[NYCookieManager sharedManager] forceUpdateUAuth]`.
Evidence: NYHTTPSClient.m:134 -- `[[NYCookieManager sharedManager] forceUpdateUAuth];`

Contract: Authorization Header Injection
Category: P
Trigger:  Creating a request when `NYLoginUserDataModel.sharedModel.expressAccessToken` is not nil.
Effect:   Propagates the user's login state to the backend by injecting an `Authorization` header into the outgoing request.
Evidence: NYHTTPSClient.m:148 -- `[outputRequest setValue:NYLoginUserDataModel.sharedModel.expressAccessToken forHTTPHeaderField: @"Authorization"];`

Contract: Synchronous Request Blocking
Category: S
Trigger:  Calling any method prefixed with `sync...` (e.g., `syncGetPath:`).
Effect:   Blocks the calling thread using a `dispatch_semaphore_t` until the network operation completes.
Evidence: NYHTTPSClient.m:664 -- `dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);`

Contract: Request Payload Encryption
Category: P
Trigger:  Calling `postPath:dataStr:...`.
Effect:   Abstracts the encryption scheme by taking a plain string, encrypting it with AES, signing it with HMAC-SHA512, and sending the results as the POST body.
Evidence: NYHTTPSClient.m:382-403 -- (method implementation)

Contract: Response Decryption and Verification
Category: P
Trigger:  A successful network response in `postPathForEncryptData:...`.
Effect:   The method intercepts the raw response, verifies its HMAC signature, decrypts the payload, and propagates the decrypted JSON object to the success callback, hiding the crypto details from the caller.
Evidence: NYHTTPSClient.m:417-436 -- (success block implementation)

Contract: ECoupon Method Override
Category: M
Trigger:  Calling `postPathForECoupon:...`.
Effect:   Mutates the intended HTTP method from POST to GET before sending the request, as noted by the inline comment.
Evidence: NYHTTPSClient.m:468 -- `//應Alan要求將post改為get, 方便server tracking`

Contract: Targeted Operation Cancellation
Category: C
Trigger:  Calling `cancelAllHTTPOperationsWithMethod:path:`.
Effect:   Cancels in-flight `NSURLSessionDataTask` operations that match a specific HTTP method and path.
Evidence: NYHTTPSClient.m:474 -- `- (void)cancelAllHTTPOperationsWithMethod:(NSString *)method path:(NSString *)path`

Contract: Shop ID Mismatch Silent Logging
Category: E
Trigger:  Receiving a response where the `x-shop-id` header does not match the app's current `shopId`.
Effect:   An error is logged via a `logger` object, but the primary success path for the request continues, and the `failure` block is not invoked.
Evidence: NYHTTPSClient.m:628 -- `if (isShopIdMismatch) { [self logMismatchShopID:responseShopId urlString:request.URL.absoluteString]; }`

Contract: Automatic Logout on Specific API Response
Category: L
Trigger:  Receiving a response from a specific API endpoint with a designated "logout" return code.
Effect:   Implicitly triggers a global application state transition to log the user out and restart the login flow.
Evidence: NYHTTPSClient.m:637 -- `[[NYLoginHelper sharedInstance] logoutAndLoginAgainWithCompletionHandler:nil];`

Contract: Global API Request/Response Notifications
Category: N
Trigger:  Start and completion of any API request.
Effect:   Broadcasts global `NSNotification`s named "apiRequest" and "apiResponse" to any observers in the application.
Evidence: NYHTTPSClient.m:741, 757 -- `[NSNotificationCenter.defaultCenter postNotificationName: ...]`

Contract: API Info Logging to File
Category: M
Trigger:  An API request is made while the log level is `NYHTTPClientLogLevelAPIInfo`.
Effect:   Mutates the file system by appending information about the API call to a local log file (`API-Log.csv`).
Evidence: NYHTTPSClient.m:726 -- `[apiLog writeToFile:[[self class] logFilePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];`

TOTAL CONTRACTS FOUND: 15
CATEGORY BREAKDOWN: M=4 L=2 N=1 S=1 E=2 C=1 D=0 P=5

EXTERNAL_DEPENDENCY: Any class observing "apiRequest" or "apiResponse" NSNotifications -- The client posts these notifications on every request and response.
EXTERNAL_DEPENDENCY: NYLoginHelper -- The client calls `-[NYLoginHelper logoutAndLoginAgainWithCompletionHandler:]` to tear down the user session.
EXTERNAL_DEPENDENCY: NYAESKeyManager -- The client depends on this class to provide the primary and fallback AES encryption keys.
EXTERNAL_DEPENDENCY: NYHTTPSClientLogger -- The client has a `logger` property and calls `record(error:)` on it for shop ID mismatches.
EXTERNAL_DEPENDENCY: NYBaseURLConfig -- Used to get the base URL for the client and other domain names.
EXTERNAL_DEPENDENCY: NYUserDefault / NYUserDefaultV2 -- Used to check for SSL pinning, the auto-logout feature, and the list of APIs that trigger logout.
EXTERNAL_DEPENDENCY: NYGlobalData -- Used to get the global `shopId` for parameter injection and response validation.
EXTERNAL_DEPENDENCY: NYLocalizationString -- Used to get the selected language code for the `Accept-Language` header.
EXTERNAL_DEPENDENCY: NYCookieManager -- Used to force update the uAuth cookie on every request.
EXTERNAL_DEPENDENCY: NYLoginUserDataModel -- Used to get the `expressAccessToken` for the `Authorization` header.
EXTERNAL_DEPENDENCY: NYCryptoSwiftInterface -- Used for AES and HMAC-SHA512 cryptographic operations.
EXTERNAL_DEPENDENCY: PromiseKit consumers (e.g., PMKResolver) -- Methods like `postPath:` return an `AnyPromise`, which is consumed by other parts of the app using this framework.
EXTERNAL_DEPENDENCY: NYDataProvider (and its categories) -- Static analysis suggests these classes are the primary callers of NYHTTPSClient, consuming the results via promises or completion blocks.
ClearcutLogger: Flush already in progress, marking pending flush.
