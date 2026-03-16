Contract: Singleton Access
Category: D
Trigger:  Calling `[NYHTTPSClient sharedClient]`
Effect:   Ensures that only one instance of `NYHTTPSClient` is created and used throughout the application, creating a dependency on this shared instance.
Evidence: NYHTTPSClient.m:67 -- `+ (NYHTTPSClient *)sharedClient { ... }`

Contract: Log Level Configuration
Category: M
Trigger:  Calling `[NYHTTPSClient setLogLevel:NYHTTPClientLogLevelAPIInfo]`
Effect:   Modifies the static `_logLevel` variable and triggers the deletion and re-initialization of the "API-Log.csv" file.
Evidence: NYHTTPSClient.m:59 -- `+ (void)setLogLevel:(NYHTTPClientLogLevel)logLevel { if (logLevel == NYHTTPClientLogLevelAPIInfo) { [self initLogFile]; } _logLevel = logLevel; }`

Contract: SSL Pinning Policy
Category: D
Trigger:  Initializing the `sharedClient` when `NYUserDefaultV2.isSSLPinningEnabled` is true.
Effect:   Applies a security policy (`NYSecurityPolicy`) to the client, creating a dependency on this policy's configuration for all subsequent requests.
Evidence: NYHTTPSClient.m:71 -- `if (NYUserDefaultV2.isSSLPinningEnabled) { [_sharedClient setSecurityPolicy:[NYSecurityPolicy policy]]; }`

Contract: Automatic URL Parameter Injection
Category: P
Trigger:  Making any request using `requestWithType:method:path:parameters:`.
Effect:   Automatically appends `shopId` and `lang` as query parameters to the request URL, propagating state from `NYGlobalData` and `NYLocalizationString` into the network call.
Evidence: NYHTTPSClient.m:103 -- `updatedParameters[shopIDKey] = shopId; updatedParameters[ @"lang"] = lang;`

Contract: Auth Cookie Restoration
Category: M
Trigger:  Creating any request via `requestWithType:method:path:parameters:`.
Effect:   Forces an update to the 'uAuth' cookie by calling `[[NYCookieManager sharedManager] forceUpdateUAuth]`, a side effect that modifies shared cookie storage.
Evidence: NYHTTPSClient.m:133 -- `[[NYCookieManager sharedManager] forceUpdateUAuth];`

Contract: Header Modification based on Global State
Category: P
Trigger:  Creating any request via `requestWithType:method:path:parameters:`.
Effect:   Modifies the outgoing request headers `Accept-Language` and `Authorization` based on global state from `NYLocalizationString` and `NYLoginUserDataModel`.
Evidence: NYHTTPSClient.m:136 -- `[outputRequest setValue:NYLocalizationString.selectedLanguageCode forHTTPHeaderField: @"Accept-Language"];`

Contract: Synchronous Request Blocking
Category: S
Trigger:  Calling any `sync...` method (e.g., `syncGetPath:`) or any method with `isSynchrounousRequest:YES`.
Effect:   Blocks the calling thread using a `dispatch_semaphore_t` until the network request completes or fails.
Evidence: NYHTTPSClient.m:777 -- `if (isSynchrounousRequest) { dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER); }`

Contract: Automatic Logout on Specific API Errors
Category: L
Trigger:  An API response matches a path and `logoutReturnCode` specified in `[NYUserDefault logoutAPICheckList]`.
Effect:   Triggers a global user logout and re-login flow by calling `[[NYLoginHelper sharedInstance] logoutAndLoginAgainWithCompletionHandler:nil]`.
Evidence: NYHTTPSClient.m:796 -- `if ([self logoutWithURL:dataTask.originalRequest.URL resposeObj:responseObject] && ![NYUserDefault ignoreAuthExpireLogoutEnabled]) { [[NYLoginHelper sharedInstance] logoutAndLoginAgainWithCompletionHandler:nil]; }`

Contract: Request/Response Notification
Category: N
Trigger:  Any data task is started or completed.
Effect:   Broadcasts a `NSNotification` with the name "apiRequest" or "apiResponse", containing the `NSURLSessionTask` and optionally the `responseObject`.
Evidence: NYHTTPSClient.m:1003 -- `[NSNotificationCenter.defaultCenter postNotificationName: @"apiRequest" object:self userInfo:@{ @"task": task}];`

Contract: API Call Logging to File
Category: M
Trigger:  A request is made while `_logLevel` is `NYHTTPClientLogLevelAPIInfo`.
Effect:   Appends a line describing the API call details to the "API-Log.csv" file in the app's document directory.
Evidence: NYHTTPSClient.m:887 -- `[apiLog writeToFile:[[self class] logFilePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];`

Contract: Shop ID Mismatch Logging
Category: E
Trigger:  An API response contains an `x-shop-id` header that does not match the value from `[NYGlobalData shopId]`.
Effect:   An error with domain `NSURLErrorDomain` and code `91400` is recorded via the configured `logger` object.
Evidence: NYHTTPSClient.m:789 -- `[self logMismatchShopID:responseShopId urlString:request.URL.absoluteString];`

Contract: Request Encryption with Fallback Key
Category: D
Trigger:  Calling `postPath:dataStr:...`.
Effect:   Relies on `NYAESKeyManager` to provide an AES key, using a hardcoded fallback key if the primary one is unavailable.
Evidence: NYHTTPSClient.m:28 -- `static NSString *aesKey(void) { NSString *key = [NYAESKeyManager decryptedAESKey]; return key ?: [NYAESKeyManager fallbackKey]; }`

Contract: Response Decryption and Signature Validation
Category: E
Trigger:  Calling `postPathForEncryptData:...` and receiving a successful response from the server.
Effect:   Performs HMAC signature validation on the response. If validation fails, it invokes the `failure` block with a specific error message, otherwise it attempts AES decryption.
Evidence: NYHTTPSClient.m:501 -- `if ([hmacSha512Hex isEqualToString:signature]) { ... } else { NSError *error = [NSError errorWithDomain: @"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"HMAC signature verification failed"}]; failure(operation, error); }`

Contract: Operation Cancellation
Category: C
Trigger:  Calling `cancelAllHTTPOperationsWithMethod:path:`.
Effect:   Iterates through the client's `operationQueue` and cancels any ongoing `NSURLSessionDataTask` that matches the given HTTP method and path.
Evidence: NYHTTPSClient.m:597 -- `if (hasMatchingMethod && hasMatchingPath) { [operation cancel]; }`

Contract: Implicit Method Change for ECoupon
Category: P
Trigger:  Calling `postPathForECoupon:parameters:success:failure:`.
Effect:   Despite its name starting with "postPath", the method actually performs a GET request to the server after adding signature parameters.
Evidence: NYHTTPSClient.m:568 -- `[self getPath:path parameters:parametersForRequest success:^(NSURLSessionDataTask *operation, id responseObject) { ... }];`

Contract: Idempotency Key Injection
Category: P
Trigger:  Executing any request via `addOperationWithRequestType:...`.
Effect:   A unique UUID is generated and injected into the `ny-idempotency-key` header for each request, ensuring a level of idempotency is communicated to the server.
Evidence: NYHTTPSClient.m:761 -- `[request setValue:[NSUUID UUID].UUIDString forHTTPHeaderField: @"ny-idempotency-key"];`

TOTAL CONTRACTS FOUND: 16
CATEGORY BREAKDOWN: M=[3] L=[1] N=[1] S=[1] E=[2] C=[1] D=[2] P=[5]

EXTERNAL_DEPENDENCY: [Any UI class displaying network activity] -- Listens for "apiRequest" and "apiResponse" NSNotifications to show/hide a spinner.
EXTERNAL_DEPENDENCY: NYLoginHelper -- Called via `[NYLoginHelper sharedInstance]` to perform a global logout and re-login when a specific API error occurs.
EXTERNAL_DEPENDENCY: NYCookieManager -- Called via `[NYCookieManager sharedManager]` to force-update the uAuth cookie before any request is sent.
EXTERNAL_DEPENDENCY: NYAESKeyManager -- Called via `[NYAESKeyManager decryptedAESKey]` and `[NYAESKeyManager fallbackKey]` to get encryption keys for secure communication.
EXTERNAL_DEPENDENCY: NYGlobalData -- Called via `[NYGlobalData shopId]` to inject the shop ID into requests and for response validation.
EXTERNAL_DEPENDENCY: NYUserDefault / NYUserDefaultV2 -- Read to get configuration like `isSSLPinningEnabled` and the `logoutAPICheckList`.
EXTERNAL_DEPENDENCY: NYLoginUserDataModel -- Read via `[NYLoginUserDataModel sharedModel]` to get the `expressAccessToken` for the Authorization header.
EXTERNAL_DEPENDENCY: NYCryptoSwiftInterface -- Called to perform AES and HMAC-SHA512 cryptographic operations.
EXTERNAL_DEPENDENCY: NYDataProvider (and its categories) -- These are the likely primary callers of the `getPath`/`postPath` methods to fetch data for the application.
EXTERNAL_DEPENDENCY: (NYHTTPSClientLogger implementor) -- An unknown class conforms to `NYHTTPSClientLogger` and is assigned to the `logger` property to handle recording errors like shop ID mismatches.
