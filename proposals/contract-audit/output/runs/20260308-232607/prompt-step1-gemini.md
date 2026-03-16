# Blind Contract Scout
# 盲掃合約發現者 -- 語言無關版本
# 此 prompt 由 Gemini 執行，獨立於主稽核者（Auditor）運作，不參考任何既有合約清單。

## ROLE

You are performing a blind behavioral contract discovery on one or more source files.
You have NO prior list of contract IDs. You are NOT trying to confirm anyone else's work.
Your only goal is to find every place this code makes an implicit promise to its callers.

The target code may be written in any language (`objc`). Adapt your analysis accordingly.

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
- Adapt your analysis to `objc` idioms -- for example, use language-appropriate terminology for events, notifications, lifecycle hooks, and synchronization primitives.



## Step 0 Discovery Note
The following related files were found by static scan (not included in full -- reference them in Section 4):
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYCookieManager.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYDataProvider.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYDataProvider+Login.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYDataProvider+MemberCenter.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYDataProvider+MemberShipCardManage.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYDataProvider+NewCoupon.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYLoginHelper.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYTrackingClient.m
//
//  NYHTTPSClient.m
//  NineYiShopping
//
//  Created by stedy on 13/4/17.
//  Copyright (c) 2013年 Julie Lin. All rights reserved.
//

#import "NYHTTPSClient.h"
#import "NYJSONRequestSerializer.h"
#import "NYBaseURLConfig.h"
#import "NSString+Regex.h"
#import "NYCookieManager.h"
#import "NYGlobalData.h"
#import "NYUserDefault.h"
#import "NYLoginHelper.h"
#import <NYCore/NYCore-Swift.h>

// Deprecated: 保留作為 fallback，請使用 NYAESKeyManager.decryptedAESKey() 取得 AES Key
static NSString *const kAesKey      = @"8167b887e6b30cbb553cdf7fdd62e602";
static NSString *const kSalt        = @"fdsfds";
static NSString *const kHMAC_SHA512 = @"8167b887";

/// 取得 AES Key（優先使用加密儲存的 key，失敗則使用 fallback）
static NSString *aesKey(void) {
    NSString *key = [NYAESKeyManager decryptedAESKey];
    return key ?: [NYAESKeyManager fallbackKey];
}

@interface NYHTTPSClient ()
- (AFHTTPRequestSerializer *)requestSerializerWithType:(NYHTTPRequestType)type;
- (AFHTTPResponseSerializer *)responseSerializerWithType:(NYHTTPResponseType)type;

- (BOOL)shouldAppendAppVerToURL:(NSURL *)url;

// For record API info only, should not use this method in Release build.
- (void)recordApiInfo:(NSString *)path parameters:(NSDictionary *)parameter method:(NSString *)method requestSerializerType:(NYHTTPRequestType)requestType responseSerializerType:(NYHTTPResponseType)responseType responseContentType:(NSString *)responseContentType;

+ (void)initLogFile;
+ (NSString *)logFilePath;
@end

@implementation NYHTTPSClient

static NYHTTPClientLogLevel _logLevel = NYHTTPClientLogLevelOff;

+ (NYHTTPClientLogLevel)logLevel {
    return _logLevel;
}

+ (void)setLogLevel:(NYHTTPClientLogLevel)logLevel {
    if (logLevel == NYHTTPClientLogLevelAPIInfo) {
        [self initLogFile];
    }
    _logLevel = logLevel;
}

+ (NYHTTPSClient *)sharedClient {
    static id _sharedClient = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[NYHTTPSClient alloc] initWithBaseURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/webapi/", [NYBaseURLConfig baseHTTPSURLWithWebAPIDomain].absoluteString]]];
        if (NYUserDefaultV2.isSSLPinningEnabled) {
            [_sharedClient setSecurityPolicy:[NYSecurityPolicy policy]];
        }
    });
    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url {
    if (self = [super initWithBaseURL:url]) {
        
    }
    return self;
}

#pragma mark - NSMutableURLRequest Factory
- (NSMutableURLRequest *)requestWithType:(NYHTTPRequestType)type method:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    NSString *URLString;
    if (![self.baseURL.absoluteString hasSuffix:@"/"] && ![path hasPrefix:@"/"]) {
        URLString = [NSString stringWithFormat:@"%@/%@", self.baseURL.absoluteString, path];
    } else {
        URLString = [NSString stringWithFormat:@"%@%@", self.baseURL.absoluteString, path];
    }
    
    // 在還沒有取得交集之前，預設語系帶 en-US。理論上只有 GetShopAvailLanguages 這隻 API 會使用
    NSMutableString *updateURLString = URLString.mutableCopy;
    NSMutableDictionary *updatedParameters = (parameters == nil) ? @{}.mutableCopy : parameters.mutableCopy;
    NSNumber *shopId = [NYGlobalData shopId];
    NSString *selectedLang = [NYLocalizationString selectedLanguageCode];
    NSString *preferedLang = [NSLocale preferredLanguages].firstObject;
    NSString *lang = selectedLang.length > 0 ? selectedLang
    : preferedLang.length > 0 ? preferedLang
    : @"en-US";
    
    if ([method.uppercaseString isEqualToString:@"GET"]) {
        // 如果已經有ShopID就更新 (大小寫不拘)
        __block NSString *shopIDKey = nil;
        [updatedParameters enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([key.lowercaseString isEqualToString:@"shopid"]) {
                shopIDKey = key;
                *stop = YES;
            }
        }];
        shopIDKey = shopIDKey ? : @"shopId";

        // 因為只有 GET 才放在 parameters 會被放進 query string
        updatedParameters[shopIDKey] = shopId;
        updatedParameters[@"lang"] = lang;
    } else {
        // 非 GET 需另外處理
        NSURLComponents *urlComponenets = [NSURLComponents componentsWithString:URLString];
        NSArray<NSURLQueryItem *> *queryItems = urlComponenets.queryItems;
        if (queryItems.count == 0) {
            // 代表沒有 query string，需要加 ?shopId=%@&lang=%@
            [updateURLString appendString:[NSString stringWithFormat:@"?shopId=%@&lang=%@", shopId, lang]];
        } else {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.name LIKE[cd] %@", @"shopId"];
            if ([queryItems filteredArrayUsingPredicate:predicate].count > 0) {
                // 有包含 shopId，僅需加上 lang=%@
                [updateURLString appendString:[NSString stringWithFormat:@"&lang=%@", lang]];
            } else {
                // 沒有包含 shopId，也是需要兩個都加
                [updateURLString appendString:[NSString stringWithFormat:@"&shopId=%@&lang=%@", shopId, lang]];
            }
        }
    }
    
    AFHTTPRequestSerializer *requestSerializer = [self requestSerializerWithType:type];
    NSMutableURLRequest *outputRequest = [requestSerializer requestWithMethod:method
                                                                    URLString:updateURLString
                                                                   parameters:updatedParameters
                                                                        error:nil];
    // Restore uAuth
    [[NYCookieManager sharedManager] forceUpdateUAuth];

    // Change Accept-Language if user selected other language
    if (NYLocalizationString.selectedLanguage != NYLanguageUserDefault) {
        [outputRequest setValue:NYLocalizationString.selectedLanguageCode
             forHTTPHeaderField:@"Accept-Language"];
    } else {
        // 將語系對應到LanguageTool上合法的語系 (如zh-MY -> zh-TW)
        NSString *currentLanguageCode = [[NSLocale preferredLanguages] firstObject];
        NSString *supportedLanguageCode = [NYLocalizationString properLanguageKeyWith:currentLanguageCode];

        if (supportedLanguageCode) {
            [outputRequest setValue:supportedLanguageCode forHTTPHeaderField:@"Accept-Language"];
        }
    }
    
    // Set Authorization
    if (NYLoginUserDataModel.sharedModel.expressAccessToken != nil) {
        [outputRequest setValue:NYLoginUserDataModel.sharedModel.expressAccessToken
             forHTTPHeaderField:@"Authorization"];
    }
    
    return outputRequest;
}

- (NSMutableURLRequest *)httpRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    return [self requestWithType:NYHTTPRequestTypeHTTP method:method path:path parameters:parameters];
}

- (NSMutableURLRequest *)jsonRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    return [self requestWithType:NYHTTPRequestTypeJSON method:method path:path parameters:parameters];
}

#pragma mark - HTTP GET

- (void)syncGetPath:(NSString *)path
         parameters:(NSDictionary *)parameters
            success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
            failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    [self syncGetPath:path parameters:parameters requestType:NYHTTPRequestTypeHTTP responseType:NYHTTPResponseTypeJSON success:success failure:failure];
}

- (void)syncGetPath:(NSString *)path
         parameters:(NSDictionary *)parameters
        requestType:(NYHTTPRequestType)requestType
       responseType:(NYHTTPResponseType)responseType
            success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
            failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    [self addOperationWithRequestType:requestType
                         responseType:responseType
                               method:@"GET"
                                 path:path
                           parameters:parameters
                isSynchrounousRequest:YES
                       requestTimeout:nil
                              success:success
                              failure:failure];
}

- (AnyPromise *)getPath:(NSString *)path parameters:(NSDictionary *)parameters {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver  _Nonnull resolve) {
        [self getPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {
            resolve(PMKManifold(responseObject, operation));
        } failure:^(NSURLSessionDataTask *operation, NSError *error) {
            resolve(error);
        }];
    }];
    //return [[self getPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {} failure:^(NSURLSessionDataTask *operation, NSError *error) {}] promise];
}

- (NSURLSessionDataTask *)getPath:(NSString *)path
                       parameters:(NSDictionary *)parameters
                          success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                          failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    return [self getPath:path parameters:parameters requestType:NYHTTPRequestTypeHTTP responseType:NYHTTPResponseTypeJSON success:success failure:failure];
}

- (NSURLSessionDataTask *)getPath:(NSString *)path
                       parameters:(NSDictionary *)parameters
                      requestType:(NYHTTPRequestType)requestType
                     responseType:(NYHTTPResponseType)responseType
                          success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
                          failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    return [self addOperationWithRequestType:requestType responseType:responseType method:@"GET" path:path parameters:parameters success:success failure:failure];
}

#pragma mark - HTP POST

- (void)syncPostPath:(NSString *)path
          parameters:(NSDictionary *)parameters
             success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
             failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    [self syncPostPath:path parameters:parameters requestType:NYHTTPRequestTypeHTTP responseType:NYHTTPResponseTypeJSON success:success failure:failure];
}

- (void)syncPostPath:(NSString *)path
          parameters:(NSDictionary *)parameters
         requestType:(NYHTTPRequestType)requestType
        responseType:(NYHTTPResponseType)responseType
             success:(void (^)(NSURLSessionDataTask *, id))success
             failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    [self addOperationWithRequestType:requestType
                         responseType:responseType
                               method:@"POST"
                                 path:path
                           parameters:parameters
                isSynchrounousRequest:YES
                       requestTimeout:nil
                              success:success
                              failure:failure];
}

- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver  _Nonnull resolve) {
        [self syncPostPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {
            resolve(PMKManifold(responseObject, operation));
        } failure:^(NSURLSessionDataTask *operation, NSError *error) {
            resolve(error);
        }];
    }];
    //return [[self postPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {} failure:^(NSURLSessionDataTask *operation, NSError *error) {}] promise];
}

- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters requestType:(NYHTTPRequestType)requestType responseType:(NYHTTPResponseType)responseType {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver  _Nonnull resolve) {
        [self postPath:path parameters:parameters requestType:requestType responseType:responseType success:^(NSURLSessionDataTask *operation, id responseObject) {
            resolve(PMKManifold(responseType, operation));
        } failure:^(NSURLSessionDataTask *operation, NSError *error) {
            resolve(error);
        }];
    }];
}

- (NSURLSessionDataTask *)postPath:(NSString *)path
      parameters:(NSDictionary *)parameters
         success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    return [self postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:success failure:failure];
}

- (NSURLSessionDataTask *)postPath:(NSString *)path
                        parameters:(NSDictionary *)parameters
                       requestType:(NYHTTPRequestType)requestType
                      responseType:(NYHTTPResponseType)responseType
                           success:(void (^)(NSURLSessionDataTask *, id))success
                           failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    return [self addOperationWithRequestType:requestType responseType:responseType method:@"POST" path:path parameters:parameters success:success failure:failure];
}

- (NSURLSessionDataTask *)postPath:(NSString *)path
                        parameters:(NSDictionary *)parameters
                       requestType:(NYHTTPRequestType)requestType
                      responseType:(NYHTTPResponseType)responseType
                    requestTimeout:(NSNumber *)requestTimeout
                           success:(void (^)(NSURLSessionDataTask *, id))success
                           failure:(void (^)(NSURLSessionDataTask *, NSError *))failure {
    return [self addOperationWithRequestType:requestType
                                responseType:responseType
                                      method:@"POST"
                                        path:path
                                  parameters:parameters
                              requestTimeout:requestTimeout
                                     success:success
                                     failure:failure];
}

- (void)postPath:(NSString *)path dataStr:(NSString *)dataStr   //For RegistAPP
sendSynchronousRequest:(BOOL)sendSynchronousRequest
         success:(void (^)(NSURLSessionDataTask *operation, id JSON))success
         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure {
    
    NSData *data = [dataStr dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    NSString *currentAESKey = aesKey();
    if (currentAESKey.length < 32) {
        NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid AES key length"}];
        failure(nil, error);
        return;
    }
    
    NSData *aesKey = [[currentAESKey substringWithRange:NSMakeRange(0, 32)] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *aesIv = [[currentAESKey substringWithRange:NSMakeRange(0, 16)] dataUsingEncoding:NSUTF8StringEncoding];
    
    // 使用 CryptoSwift 進行 AES 加密
    NSString *encryptedBase64 = [NYCryptoSwiftInterface aesEncryptWithData:data key:aesKey iv:aesIv];
    if (!encryptedBase64) {
        NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"AES encryption failed"}];
        failure(nil, error);
        return;
    }
    NSLog(@"encrypted base64: %@", encryptedBase64);
    
    NSString *timestamp     = [self timestamp];
    NSString *salt          = kSalt;
    NSString *hmacSHA512    = kHMAC_SHA512;
    
    // 使用 CryptoSwift 進行 HMAC-SHA512
    NSString *hmacSha512Hex = [NYCryptoSwiftInterface hmacSha512:[NSString stringWithFormat:@"%@%@%@", timestamp, salt, encryptedBase64] hmacKey:hmacSHA512];
    if (!hmacSha512Hex) {
        NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"HMAC-SHA512 failed"}];
        failure(nil, error);
        return;
    }
    NSLog(@"hmacSha512 hex signature: %@", hmacSha512Hex);
    
    NSDictionary *parameters = @{
                                 @"ciphertext":encryptedBase64,
                                 @"timeStamp":timestamp,
                                 @"signature":hmacSha512Hex
                                 };
    
    if (sendSynchronousRequest) {
        [self syncPostPath:path parameters:parameters success:success failure:failure];
    }
    else {
        [self postPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {
            success(operation, responseObject);
        } failure:^(NSURLSessionDataTask *operation, NSError *error) {
            failure(operation, error);
        }];
    }
}

- (void)postPathForEncryptData:(NSString *)path
                    parameters:(NSDictionary *)parameters
                       success:(void (^)(NSURLSessionDataTask *, id))success
                       failure:(void (^)(NSURLSessionDataTask *, NSError *))failure   //For NYMemberCard pull data
{
    [self postPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *currentAESKey = aesKey();
        if (currentAESKey.length < 32) {
            NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid AES key length"}];
            failure(nil, error);
            return;
        }
        
        NSData *aesKey = [[currentAESKey substringWithRange:NSMakeRange(0, 32)] dataUsingEncoding:NSUTF8StringEncoding];
        NSData *aesIv = [[currentAESKey substringWithRange:NSMakeRange(0, 16)] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *salt  = kSalt;
        NSString *hmacSHA512 = kHMAC_SHA512;
        
        NSString *cipherText = responseObject[@"cipherText"];
        NSString *signature = responseObject[@"signature"];
        NSString *timestamp = responseObject[@"timeStamp"];
        
        // 使用 CryptoSwift 進行 HMAC-SHA512 驗證
        NSString *hmacSha512Hex = [NYCryptoSwiftInterface hmacSha512:[NSString stringWithFormat:@"%@%@%@", timestamp, salt, cipherText] hmacKey:hmacSHA512];
        if (!hmacSha512Hex) {
            NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"HMAC-SHA512 verification failed"}];
            failure(operation, error);
            return;
        }
        
        if ([hmacSha512Hex isEqualToString:signature]) {
            // 使用 CryptoSwift 進行 AES 解密
            NSData *decryptedData = [NYCryptoSwiftInterface aesDecryptWithBase64:cipherText key:aesKey iv:aesIv];
            if (!decryptedData) {
                NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"AES decryption failed"}];
                failure(operation, error);
                return;
            }
            
            NSError *error;
            id jsonObject = [NSJSONSerialization JSONObjectWithData:decryptedData options:0 error:&error];
            if (error) {
                failure(operation, error);
                return;
            }
            success(operation, jsonObject);
        } else {
            NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"HMAC signature verification failed"}];
            failure(operation, error);
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        failure (operation, error);
    }];
}

- (void)postPathForECoupon:(NSString *)path
                parameters:(NSDictionary *)parameters
                   success:(void (^)(NSURLSessionDataTask *, id))success
                   failure:(void (^)(NSURLSessionDataTask *, NSError *))failure
{
    NSString *timestamp     = [self timestamp];
    NSString *salt          = kSalt;
    NSString *hmacSHA512    = kHMAC_SHA512;
    
    // 使用 CryptoSwift 進行 HMAC-SHA512
    NSString *hmacSha512Hex = [NYCryptoSwiftInterface hmacSha512:[NSString stringWithFormat:@"%@%@%@", timestamp, salt, parameters[@"eCouponGiftId"]] hmacKey:hmacSHA512];
    if (!hmacSha512Hex) {
        NSError *error = [NSError errorWithDomain:@"NYHTTPSClient" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"HMAC-SHA512 failed"}];
        failure(nil, error);
        return;
    }
    
    NSDictionary *parametersForRequest = @{@"eCouponId":parameters[@"eCouponId"],
                                           @"eCouponGiftId": parameters[@"eCouponGiftId"],
                                           @"SenderFBId": parameters[@"SenderFBId"],
                                           @"ReceiverFBId": parameters[@"ReceiverFBId"],
                                           @"timestamp": timestamp,
                                           @"signature": hmacSha512Hex};
    //應Alan要求將post改為get, 方便server tracking
    [self getPath:path parameters:parametersForRequest success:^(NSURLSessionDataTask *operation, id responseObject) {
        success(operation, responseObject);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        failure(operation, error);
    }];
}

- (void)cancelAllHTTPOperationsWithMethod:(NSString *)method
                                     path:(NSString *)path
{
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.baseURL.absoluteString, path];
    NSURLRequest *request = [[AFHTTPRequestSerializer serializer] requestWithMethod:method URLString:urlString parameters:nil error:nil];
    NSString *pathToBeMatched = request.URL.absoluteString;
    
    for (NSOperation *operation in [self.operationQueue operations]) {
        if (![operation isKindOfClass:[NSURLSessionDataTask class]]) {
            continue;
        }

        NSURLSessionDataTask *task = (NSURLSessionDataTask *)operation;
        BOOL hasMatchingMethod = !method || [method isEqualToString:task.currentRequest.HTTPMethod];
        BOOL hasMatchingPath = [task.currentRequest.URL.path isEqual:pathToBeMatched];
        
        if (hasMatchingMethod && hasMatchingPath) {
            [operation cancel];
        }
    }
}

- (NSString *)timestamp {
    NSDate *start = [NSDate date];
    NSTimeInterval timeInterval = [start timeIntervalSince1970];
    double now_timestamp = fabs(timeInterval);
    
    now_timestamp += 28800; //GMT +8
    NSLog(@"time: %.0f", now_timestamp);
    
    NSString *timestamp = [NSString stringWithFormat:@"%.0f", now_timestamp];
    return timestamp;
}

#pragma mark - Logger

- (void)logMismatchShopID:(NSString *)responseShopID urlString:(NSString *)urlString {
    NSDictionary *logData = @{@"url": urlString,
                              @"exceptedShopId": [NYGlobalData shopId],
                              @"responseShopId": responseShopID};

    // error code: 91-400 代表示 91 專屬 400 bad request
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:91400 userInfo:logData];
    [self.logger recordError:error];
}

#pragma mark - Private Helpers

- (AFHTTPRequestSerializer *)requestSerializerWithType:(NYHTTPRequestType)type {
    AFHTTPRequestSerializer *serializer;
    switch (type) {
        case NYHTTPRequestTypeHTTP:
            serializer = [AFHTTPRequestSerializer serializer];
            break;
        case NYHTTPRequestTypeJSON:
            serializer = [AFJSONRequestSerializer serializer];
            break;
        case NYHTTPRequestTypeFixedFloat:
            serializer = [NYJSONRequestSerializer serializer];
            break;
        default:
            NSAssert(NO, @"Unrecognized Request Type");
            break;
    }
    
    //APP/Web 對齊timeout setting
    serializer.timeoutInterval = 30.0f;
    
    return serializer;
}

- (AFHTTPResponseSerializer *)responseSerializerWithType:(NYHTTPResponseType)type {
    AFHTTPResponseSerializer *serializer;
    switch (type) {
        case NYHTTPResponseTypeHTTP:
            serializer = [AFHTTPResponseSerializer serializer];
            break;
        case NYHTTPResponseTypeJSON:
            serializer = [AFJSONResponseSerializer serializerWithReadingOptions:NSJSONReadingMutableContainers | NSJSONReadingAllowFragments];
            break;
        default:
            NSAssert(NO, @"Unrecognized Request Type");
            break;
    }
    return serializer;
}

- (NSURLSessionDataTask *)addOperationWithRequestType:(NYHTTPRequestType)requestType
                       responseType:(NYHTTPResponseType)responseType
                             method:(NSString *)method
                               path:(NSString *)path
                         parameters:(NSDictionary *)parameters
                            success:(void (^)(NSURLSessionDataTask *, id))success
                            failure:(void (^)(NSURLSessionDataTask *, id))failure {

    return [self addOperationWithRequestType:requestType
                                responseType:responseType
                                      method:method
                                        path:path
                                  parameters:parameters
                       isSynchrounousRequest:NO
                              requestTimeout:nil
                                     success:success
                                     failure:failure];
}

- (NSURLSessionDataTask *)addOperationWithRequestType:(NYHTTPRequestType)requestType
                                         responseType:(NYHTTPResponseType)responseType
                                               method:(NSString *)method
                                                 path:(NSString *)path
                                           parameters:(NSDictionary *)parameters
                                       requestTimeout:(NSNumber *)requestTimeout
                                              success:(void (^)(NSURLSessionDataTask *, id))success
                                              failure:(void (^)(NSURLSessionDataTask *, id))failure {

    return [self addOperationWithRequestType:requestType
                                responseType:responseType
                                      method:method
                                        path:path
                                  parameters:parameters
                       isSynchrounousRequest:NO
                              requestTimeout:requestTimeout
                                     success:success
                                     failure:failure];
}

- (NSURLSessionDataTask *)addOperationWithRequestType:(NYHTTPRequestType)requestType
                                         responseType:(NYHTTPResponseType)responseType
                                               method:(NSString *)method
                                                 path:(NSString *)path
                                           parameters:(NSDictionary *)parameters
                                isSynchrounousRequest:(BOOL)isSynchrounousRequest
                                       requestTimeout:(NSNumber *)requestTimeout
                                              success:(void (^)(NSURLSessionDataTask *, id))success
                                              failure:(void (^)(NSURLSessionDataTask *, id))failure {
    NSMutableDictionary *mutableParameters = [parameters mutableCopy];
    if ([self shouldAppendAppVerToURL:self.baseURL]) {
        NSDictionary *appVerParameter = @{@"appVer" : [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]};
        if (!mutableParameters) {
            mutableParameters = [appVerParameter mutableCopy];
        }
        else {
            [mutableParameters setValuesForKeysWithDictionary:appVerParameter];
        }
    }
    
    NSMutableURLRequest *request = [self requestWithType:requestType method:method path:path parameters:mutableParameters];
    if (requestTimeout) {
        [request setTimeoutInterval:requestTimeout.doubleValue];
    }
    request.HTTPShouldHandleCookies = YES;
    [request setValue:[NSUUID UUID].UUIDString forHTTPHeaderField:@"ny-idempotency-key"];
    [request setValue:[[NYGlobalData shopId] stringValue]  forHTTPHeaderField:@"n1-shop-id"];

    self.responseSerializer = [self responseSerializerWithType:responseType];
    
    if ([NYBaseURLConfig isTestEnvironment]) {
        self.securityPolicy.allowInvalidCertificates = YES;
        self.securityPolicy.validatesDomainName = NO;
    }

    dispatch_semaphore_t semaphore;
    if (isSynchrounousRequest) {
        semaphore = dispatch_semaphore_create(0);
    }

    __block NSURLSessionDataTask *dataTask = nil;
    dataTask = [self dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        [self notifyResponseWithTask:dataTask responseObject:responseObject];
        // Note: 檢查 response header shopId 跟目前 shopId 是否一致，如果不同需要 log error.
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSString *expectedShopIdString = [NYGlobalData shopId].stringValue;
            NSString *responseShopId = httpResponse.allHeaderFields[@"x-shop-id"] ? : expectedShopIdString;
            BOOL isShopIdMismatch = ![expectedShopIdString isEqualToString:responseShopId];
            
            if (isShopIdMismatch) {
                [self logMismatchShopID:responseShopId
                              urlString:request.URL.absoluteString];
            }
        }

        if (error) {
            if (failure) {
                failure(dataTask, error);
            }
        } else {
            if (success) {
                // ignoreAuthExpireLogoutEnabled : debug 專用，從 setting 改
                if ([self logoutWithURL:dataTask.originalRequest.URL
                             resposeObj:responseObject] &&
                    ![NYUserDefault ignoreAuthExpireLogoutEnabled]) {
                    [[NYLoginHelper sharedInstance] logoutAndLoginAgainWithCompletionHandler:nil];
                }
                success(dataTask, responseObject);
            }
        }
         
         if (isSynchrounousRequest) {
             dispatch_semaphore_signal(semaphore);
         }
    }];

    [self notifyRequestWithTask:dataTask];
    [dataTask resume];
    
    if (isSynchrounousRequest) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }

    return dataTask;
}

- (BOOL)shouldAppendAppVerToURL:(NSURL *)url {
    NSString *urlStr = self.baseURL.absoluteString;
    NSString *facebookDomainPattern = @"(graph.facebook)";
    NSString *cdnDomainPattern = [NSString stringWithFormat:@"(%@)", [NYBaseURLConfig domainNameForCDNServer]];
    // tracking service 的 key 不是 "appVer" 所以不在這邊送額外處理
    NSString *trackingDomainPattern = [NSString stringWithFormat:@"(%@)", [NYBaseURLConfig domainNameForTrackServer]];
    // cms domain 不加 query string
    NSString *cmsDomainPattern = @"cms";
    // cpdl domain 不加
    NSString *cpdlDomainPattern = @"(cpdl)";
    
    if ([urlStr isMatchWithPattern:facebookDomainPattern] ||
        [urlStr isMatchWithPattern:cdnDomainPattern] ||
        [urlStr isMatchWithPattern:trackingDomainPattern] ||
        [urlStr containsString:cmsDomainPattern] ||
        [urlStr isMatchWithPattern:cpdlDomainPattern]) {
        return NO;
    }
    return YES;
}

- (BOOL)logoutWithURL:(NSURL *)url
           resposeObj:(id)resposeObj {
    NSDictionary *resposeDict = (NSDictionary *)resposeObj;
    if (![resposeDict isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSString *path = url.path;
    NSString *returnCode = resposeDict[@"ReturnCode"];
    for (NSDictionary *apiCheck in [NYUserDefault logoutAPICheckList]) {
        NSString *checkPattern = [NSString stringWithFormat:@"(%@)", apiCheck[@"path"]];
        if ([path isMatchWithPattern:checkPattern]) {
            if ([returnCode isEqualToString:apiCheck[@"logoutReturnCode"]]) {
                return YES;
            }
            break;
        }
    }
    return NO;
}

#pragma mark - Log Helpers

- (void)recordApiInfo:(NSString *)path parameters:(NSDictionary *)parameters method:(NSString *)method requestSerializerType:(NYHTTPRequestType)requestType responseSerializerType:(NYHTTPResponseType)responseType responseContentType:(NSString *)responseContentType {
    if (_logLevel == NYHTTPClientLogLevelAPIInfo) {
        NSString *parameterEncoding, *responseEncoding;
        if ([method isEqualToString:@"GET"]) {
            parameterEncoding = @"Query String parameter";
        } else if ([method isEqualToString:@"POST"]) {
            parameterEncoding = requestType == NYHTTPRequestTypeHTTP ? @"URL form parameter" : @"JSON form parameter ";
        } else {
            parameterEncoding = @"Unrecognized parameter encofing";
        }
        responseEncoding = responseType == NYHTTPResponseTypeHTTP ? @"plain/text Response" : @"JSON Response";
        
        NSMutableString *parameterString;
        if (parameters) {
            NSError *error = nil;
            NSData *parameterData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&error];
            parameterString = [[NSMutableString alloc] initWithData:parameterData encoding:NSUTF8StringEncoding];
            [parameterString replaceOccurrencesOfString:@"," withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, parameterString.length)];
        }
        NSString *apiInfo = [NSString stringWithFormat:@"%@, %@, %@, %@, %@, %@, %@", self.baseURL, path, parameterString, method, parameterEncoding, responseEncoding, responseContentType];
        
        NSMutableString *apiLog = [NSMutableString stringWithContentsOfFile:[[self class] logFilePath] encoding:NSUTF8StringEncoding error:nil];
        if (!apiLog) {
            apiLog = @"".mutableCopy;
        }
        if ([apiLog rangeOfString:apiInfo].location == NSNotFound) {
            [apiLog appendFormat:@"%@\n", apiInfo];
        }
        
        [apiLog writeToFile:[[self class] logFilePath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

+ (NSString *)logFilePath {
    NSString *documentDirPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *logFilePath = [documentDirPath stringByAppendingPathComponent:@"API-Log.csv"];
    return logFilePath;
}

+ (void)initLogFile {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self logFilePath]]) {
        [fileManager removeItemAtPath:[self logFilePath] error:nil];
    }
}

- (void)notifyRequestWithTask:(NSURLSessionTask * _Nullable)task {
    if (task == nil) { return; }
    [NSNotificationCenter.defaultCenter postNotificationName:@"apiRequest"
                                                      object:self
                                                    userInfo:@{@"task": task}];
}

- (void)notifyResponseWithTask:(NSURLSessionTask * _Nullable)task
                responseObject:(id _Nullable)responseObject {
    if (task == nil) { return; }

    NSDictionary * aUserInfo;

    if (responseObject == nil) {
        aUserInfo = @{@"task": task};
    } else {
        aUserInfo = @{@"task": task, @"responseObject":responseObject};
    }

    [NSNotificationCenter.defaultCenter postNotificationName:@"apiResponse"
                                                      object:self
                                                    userInfo:aUserInfo];
}

@end
//
//  NYHTTPSClient.h
//  NineYiShopping
//
//  Created by stedy on 13/4/17.
//  Copyright (c) 2013年 Julie Lin. All rights reserved.
//

#import <AFNetworking/AFHTTPSessionManager.h>
#import <PromiseKit/PromiseKit.h>

typedef NS_ENUM(NSInteger, NYHTTPRequestType) {
    NYHTTPRequestTypeFixedFloat,
    NYHTTPRequestTypeHTTP,
    NYHTTPRequestTypeJSON
};

typedef NS_ENUM(NSInteger, NYHTTPResponseType) {
    NYHTTPResponseTypeHTTP,
    NYHTTPResponseTypeJSON
};

typedef NS_ENUM(NSInteger, NYHTTPClientLogLevel) {
    NYHTTPClientLogLevelOff,
    NYHTTPClientLogLevelAPIInfo
};

@protocol NYHTTPSClientLogger <NSObject>

- (void)recordError:(NSError *)error NS_SWIFT_NAME(record(error:));

@end

#pragma mark -

@interface NYHTTPSClient : AFHTTPSessionManager

@property (nonatomic, strong) id<NYHTTPSClientLogger> logger;

+ (NYHTTPClientLogLevel)logLevel;
+ (void)setLogLevel:(NYHTTPClientLogLevel)logLevel;

+(NYHTTPSClient *)sharedClient;

- (NSMutableURLRequest *)requestWithType:(NYHTTPRequestType)type method:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters;
- (NSMutableURLRequest *)httpRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters;
- (NSMutableURLRequest *)jsonRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters;

- (void)syncGetPath:(NSString *)path
        parameters:(NSDictionary *)parameters
           success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
           failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

- (void)syncGetPath:(NSString *)path
        parameters:(NSDictionary *)parameters
       requestType:(NYHTTPRequestType)requestType
      responseType:(NYHTTPResponseType)responseType
           success:(void (^)(NSURLSessionDataTask *, id))success
           failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (AnyPromise *)getPath:(NSString *)path parameters:(NSDictionary *)parameters;

- (NSURLSessionDataTask *)getPath:(NSString *)path
     parameters:(NSDictionary *)parameters
        success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
        failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

- (NSURLSessionDataTask *)getPath:(NSString *)path
     parameters:(NSDictionary *)parameters
    requestType:(NYHTTPRequestType)requestType
   responseType:(NYHTTPResponseType)responseType
        success:(void (^)(NSURLSessionDataTask *, id))success
        failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (void)syncPostPath:(NSString *)path
          parameters:(NSDictionary *)parameters
             success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
             failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

- (void)syncPostPath:(NSString *)path
          parameters:(NSDictionary *)parameters
         requestType:(NYHTTPRequestType)requestType
        responseType:(NYHTTPResponseType)responseType
             success:(void (^)(NSURLSessionDataTask *, id))success
             failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters;

- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters requestType:(NYHTTPRequestType)requestType responseType:(NYHTTPResponseType)responseType;

- (NSURLSessionDataTask *)postPath:(NSString *)path
      parameters:(NSDictionary *)parameters
         success:(void (^)(NSURLSessionDataTask *operation, id responseObject))success
         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

- (NSURLSessionDataTask *)postPath:(NSString *)path
                        parameters:(NSDictionary *)parameters
                       requestType:(NYHTTPRequestType)requestType
                      responseType:(NYHTTPResponseType)responseType
                           success:(void (^)(NSURLSessionDataTask *, id))success
                           failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (NSURLSessionDataTask *)postPath:(NSString *)path
                        parameters:(NSDictionary *)parameters
                       requestType:(NYHTTPRequestType)requestType
                      responseType:(NYHTTPResponseType)responseType
                    requestTimeout:(NSNumber *)requestTimeout
                           success:(void (^)(NSURLSessionDataTask *, id))success
                           failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (void)postPathForECoupon:(NSString *)path
                parameters:(NSDictionary *)parameters
                   success:(void (^)(NSURLSessionDataTask *, id))success
                   failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;

- (void)postPathForEncryptData:(NSString *)path
                    parameters:(NSDictionary *)parameters
                       success:(void (^)(NSURLSessionDataTask *, id))success
                       failure:(void (^)(NSURLSessionDataTask *, NSError *))failure;   //For NYMemberCard pull data

- (void)postPath:(NSString *)path dataStr:(NSString *)dataStr
sendSynchronousRequest:(BOOL)sendSynchronousRequest
         success:(void (^)(NSURLSessionDataTask *operation, id JSON))success
         failure:(void (^)(NSURLSessionDataTask *operation, NSError *error))failure;

- (void)cancelAllHTTPOperationsWithMethod:(NSString *)method
                                     path:(NSString *)path;

- (NSString *)timestamp;

#pragma mark - for tracking client use
- (AFHTTPRequestSerializer *)requestSerializerWithType:(NYHTTPRequestType)type;
- (AFHTTPResponseSerializer *)responseSerializerWithType:(NYHTTPResponseType)type;
- (BOOL)shouldAppendAppVerToURL:(NSURL *)url;

@end
//
//  NYCookieManager.m
//  NineYiShopping
//
//  Created by Daniel Kao on 2014/11/21.
//  Copyright (c) 2014年 91mai. All rights reserved.
//

#import "NYCookieManager.h"
#import "NYDataProvider.h"
#import "NYGlobalData.h"
#import "NYBaseURLConfig.h"

// NOTE: CookieManager的寫法目前無法把NYUserDefaultsHelper拿掉，可能需要大改
// (可以寫動態selector來取userDefault中的method，但不大好)
#import "NYUserDefault.h"
#import "NYUserDefaultsHelper.h"

#import "NYKeychainHelper.h"
#import "NYNotificationExtensionKeychainHelper.h"

#import <NYCore/NSDateFormatter+Formatter.h>
#import <Webkit/WebKit.h>
#import <NYCore/NYCore-Swift.h>


static NSString * const kExpirationDateSuffix = @"-expiratio-date";

NSString * const kNYCookieStatusServerReturnsEmpty = @"NYCookieStatusServerReturnsEmpty";

NSString * const kCOOKIE_NAME_AUTH                      = @"auth";
NSString * const kCOOKIE_NAME_U_AUTH                    = @"uAUTH";
NSString * const kCOOKIE_NAME_U_AUTH_EXPRESS            = @"uAUTH_express";
NSString * const kCOOKIE_NAME_GUID                      = @"GUID";
NSString * const kCOOKIE_NAME_APP_VER                   = @"appVer";
NSString * const kCOOKIE_NAME_TRACE_FR                  = @"trace-fr";

NSString * const kCOOKIE_FR_CODE_DEFAULT                = @"direct";
NSString * const kCOOKIE_FR_CODE_REF                    = @"ref";

@interface NYCookieManager ()
@property (nonatomic, strong) NSMutableDictionary *cookieDict;

- (NSString *)expirationDateKeyForCookieName:(NSString *)cookieName;
- (NSArray *)filteredCookiesWithPredicateString:(NSString *)predicateString;
- (void)loadCookiesFromDisk;

- (void)restoreCookies;
- (void)overwriteSpecificCookies;
- (void)registerAppIfGUIDNotExist;
- (void)updateServerUDIDIfVDIDChanged;
- (void)updateUauthFromLocalGUID;
@end

@implementation NYCookieManager

+ (NYCookieManager *)sharedManager {
    static NYCookieManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[NYCookieManager alloc] init];
    });
    return _sharedManager;
}

- (instancetype)init {
    if (self = [super init]) {
        [self loadCookiesFromDisk];
    }
    return self;
}

- (void)setupCookies {
    // The following methods should be excuted synchronously.
    [self restoreCookies];
    [self registerAppIfGUIDNotExist];
    [self updateServerUDIDIfVDIDChanged];
    [self updateUauthFromLocalGUID];
    [self overwriteSpecificCookies];
}

- (NSArray *)domainNames {
    NSArray <NSString *> *domains = [NYBaseURLConfig allDomains];
    //由於 mobile domain 是 run time 從 API 拿到的，如果不放在這裡跟其他 domain 一起處理, 就必須在所有登入的地方都 manually set cookie to mobile domain，會顯得很分散
    NSString *mobileDomain = [NYUserDefault mobileDomainUrlString];
    if ([mobileDomain length] > 0 &&
        ![domains containsObject:mobileDomain]) {
        domains = [domains arrayByAddingObject:mobileDomain];
    }

    NSString *officialShopDomain = [NYUserDefault officialShopUrlString];
    if ([officialShopDomain length] > 0 &&
        ![domains containsObject:officialShopDomain]) {
        domains = [domains arrayByAddingObject:officialShopDomain];
    }

    return domains;
}

- (NSArray *)domainNamesExcludeCDNDomain {
    NSMutableArray <NSString *> *allDomains = [NYBaseURLConfig allDomains].mutableCopy;
    [allDomains removeObject:[NYBaseURLConfig domainNameForCDNServer]];
    return allDomains;
}

- (NSArray *)cookieNames {
    return @[kCOOKIE_NAME_GUID, kCOOKIE_NAME_U_AUTH, kCOOKIE_NAME_AUTH, kCOOKIE_NAME_APP_VER, kCOOKIE_NAME_TRACE_FR];
}

- (NSDictionary *)cookieDict {
    return _cookieDict;
}

- (NSString *)cookieValueFromLocal:(NSString *)cookieName {
    NSString *cookieValue = _cookieDict[cookieName];
    if (!cookieValue || [cookieValue hasPrefix:kNYCookieStatusServerReturnsEmpty]) {
        cookieValue = @"";
    }
    return cookieValue;
}

- (NSDictionary *)cookiesByCookieName:(NSString *)cookieName {
    NSArray *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"name LIKE '%@'", cookieName]];
    
    __block NSMutableDictionary *cookiePairs = @{}.mutableCopy;
    [matchedCookies enumerateObjectsUsingBlock:^(NSHTTPCookie *cookie, NSUInteger idx, BOOL *stop) {
        NSString *cookieDomain = cookie.domain;
        NSString *cookieValue = cookie.value;
        [cookiePairs addEntriesFromDictionary:@{cookieDomain:cookieValue}];
    }];
    
    return cookiePairs;
}

- (NSDictionary *)cookiesByDomain:(NSString *)domainName {
    NSArray *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"domain == '%@'", domainName]];
    
    __block NSMutableDictionary *cookiePairs = @{}.mutableCopy;
    [matchedCookies enumerateObjectsUsingBlock:^(NSHTTPCookie *cookie, NSUInteger idx, BOOL *stop) {
        NSString *cookieName = cookie.name;
        NSString *cookieValue = cookie.value;
        [cookiePairs addEntriesFromDictionary:@{cookieName:cookieValue}];
    }];
    
    return cookiePairs;
}

- (NSString *)cookieByCookieName:(NSString *)cookieName domain:(NSString *)domainName {
    NSArray *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"name == '%@' and domain == '%@'", cookieName, domainName]];
    NSHTTPCookie *cookie = [matchedCookies lastObject];
    return cookie.value;
}

- (NSString *)cookieByCookieName:(NSString *)cookieName domain:(NSString *)domainName path:(NSString *)path {
    NSArray *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"name == '%@' and domain == '%@' and path == '%@'", cookieName, domainName, path]];
    NSHTTPCookie *cookie = [matchedCookies lastObject];
    return cookie.value;
}

- (void)setCookieValue:(NSString *)cookieValue forCookieName:(NSString *)cookieName {
    [self setCookieValue:cookieValue forCookieName:cookieName expirationDate:nil];
}

- (void)setCookieValue:(NSString *)cookieValue forCookieName:(NSString *)cookieName expirationDate:(NSDate *)expirationDate {
    if (!cookieValue || !cookieName) {
        return;
    } else if (cookieValue.length == 0 || [cookieValue isEqualToString:kNYCookieStatusServerReturnsEmpty]) {
        if ([cookieName isEqualToString:kCOOKIE_NAME_AUTH]) {
            [NYCrashlyticsHelper recordWithError:[NSError errorWithDomain:@"NYCookieManager.emptyAuth" code:0 userInfo:@{}]];
        }
    }
    
    if (!expirationDate || [[NSDate date] timeIntervalSinceDate:expirationDate] < 0) {
        [self setNSHTTPCookieWithCookieName:cookieName andValue:cookieValue];
    }
    
    if ([cookieName isEqualToString:kCOOKIE_NAME_GUID] || [cookieName isEqualToString:kCOOKIE_NAME_U_AUTH]) {
        [self setKeychainValue:cookieValue forKey:cookieName];
    }
    
    _cookieDict[cookieName] = cookieValue;
    
    [NYUserDefaultsHelper setObject:cookieValue forKey:cookieName];
    if (expirationDate) {
        [NYUserDefaultsHelper setObject:expirationDate forKey:[self expirationDateKeyForCookieName:cookieName]];
    }
}

- (void)setFRAsRefAtTime:(NSDate* )setDate {
    [self setCookieValue:kCOOKIE_FR_CODE_REF forCookieName:kCOOKIE_NAME_TRACE_FR expirationDate:[setDate dateByAddingTimeInterval:24*60*60]];
}

- (void)removeCookieWithCookieName:(NSString *)cookieName {
    [self removeCookieWithCookieName:cookieName shouldRemoveFromNSUserDefaults:YES];
    
    if ([cookieName isEqualToString:kCOOKIE_NAME_AUTH]) {
        [NYCrashlyticsHelper recordWithError:[NSError errorWithDomain:@"NYCookieManager.removeAuth" code:0 userInfo:@{}]];
    }
}

- (void)removeCookieWithCookieName:(NSString *)cookieName
    shouldRemoveFromNSUserDefaults:(BOOL)shouldRemoveFromNSUserDefaults {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray<NSHTTPCookie *> *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"name == '%@'", cookieName]];
    [matchedCookies enumerateObjectsUsingBlock:^(NSHTTPCookie *cookie, NSUInteger idx, BOOL *stop) {
        // Remove cookie from NSHTTPCookieStorage
        [cookieStorage deleteCookie:cookie];
    }];
    
    [_cookieDict removeObjectForKey:cookieName];

    if (shouldRemoveFromNSUserDefaults) {
        [NYUserDefaultsHelper removeObjectForKey:cookieName];
    }
}

- (void)resetFRCookie {
    NSString* expirationDateKey = [self expirationDateKeyForCookieName:kCOOKIE_NAME_TRACE_FR];
    
    // 1. Remove Cookie from NSHTTPCookieStorage
    [self removeCookieWithCookieName:kCOOKIE_NAME_TRACE_FR shouldRemoveFromNSUserDefaults:NO];
    
    // 2. Get latest Cookie from NSUserDefaults
    NSDate *expirationDate = [NYUserDefaultsHelper objectForKey:expirationDateKey];
    NSString *cookieValue = [NYUserDefaultsHelper objectForKey:kCOOKIE_NAME_TRACE_FR];
    
    // 3. Set Cookie in NSHTTPCookieStorage if cookie is up to date
    BOOL expired = expirationDate &&
    [expirationDate timeIntervalSinceDate:[NSDate date]] < 0; // 20150202 - 20150203 < 0
    
    BOOL hasCookieValue = cookieValue && cookieValue.length > 0;
    if (expired || !hasCookieValue || [cookieValue isEqualToString:@"<null>"]) {
        cookieValue = kCOOKIE_FR_CODE_DEFAULT; // bts 8583, 8585. If expired, set FR code to DEFAULT
        expirationDate = [[NSDate date] dateByAddingTimeInterval:24*60*60]; // bts 8585 (Comment) FR為direct時，需顯示expiry date，時間為下單後的24小時
    }
    
    [self setNSHTTPCookieWithCookieName:kCOOKIE_NAME_TRACE_FR andValue:cookieValue];
    _cookieDict[kCOOKIE_NAME_TRACE_FR] = cookieValue;
    
    [NYUserDefaultsHelper setObject:cookieValue forKey:kCOOKIE_NAME_TRACE_FR];
    if (expirationDate) {
        [NYUserDefaultsHelper setObject:expirationDate forKey:expirationDateKey];
    } else {
        [NYUserDefaultsHelper removeObjectForKey:expirationDateKey];
    }
}

- (void)printNSHTTPCookies {
#ifdef DEBUG
        NSLog(@"=================");
        NSHTTPCookieStorage *sharedHTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSArray *cookies = [sharedHTTPCookieStorage cookies];
        NSEnumerator *enumerator = [cookies objectEnumerator];
        NSHTTPCookie *cookie;
        while (cookie = [enumerator nextObject]) {
            NSLog(@"-----------------------------");
            NSLog(@"Domain: %@", cookie.domain);
            NSLog(@"CookieName: %@", cookie.name);
            NSLog(@"CookieValue: %@", cookie.value);
            NSLog(@"[cookie description] %@",[cookie description]);
        }
        NSLog(@"=================");
#endif
}

- (NSString *)expirationDateStringForCookieName:(NSString *)cookieName {
    NSDate *expirationDate = [NYUserDefaultsHelper objectForKey:[self expirationDateKeyForCookieName:cookieName]];
    NSDateFormatter *dateFormatter = [NSDateFormatter dateFormatterToSecond];

    return [dateFormatter stringFromDate:expirationDate];
}

- (NSString *)localVDID {
    NSString *vdid = [NYUserDefault VDID];
    if (!vdid) {
        vdid = @"";
    }
    return vdid;
}

- (NSString *)VDID {
    return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}


#pragma mark - Private Helpers

- (NSString *)expirationDateKeyForCookieName:(NSString *)cookieName {
    return [cookieName stringByAppendingString:kExpirationDateSuffix];
}

- (NSArray *)filteredCookiesWithPredicateString:(NSString *)predicateString {
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    NSPredicate *filter = [NSPredicate predicateWithFormat:predicateString];
    NSArray *matchedCookies = [cookies filteredArrayUsingPredicate:filter];

    return matchedCookies;
}

- (void)loadCookiesFromDisk {
    
    BOOL (^isCookieValueValid)(id cookieValue) = ^BOOL(id cookieValue) {
        return [cookieValue isKindOfClass:[NSString class]] && [(NSString *)cookieValue length] > 0;
    };
    
    self.cookieDict = @{}.mutableCopy;
    NSMutableDictionary *cookies = _cookieDict;
    [[self cookieNames] enumerateObjectsUsingBlock:^(NSString *cookieName, NSUInteger idx, BOOL *stop) {

        BOOL isCookieNameGUIDorUauth = [cookieName isEqualToString:kCOOKIE_NAME_GUID] || [cookieName isEqualToString:kCOOKIE_NAME_U_AUTH];
        if (isCookieNameGUIDorUauth) {
            NSString *cookieValueFromKeychain = [self keychainValueForKey:cookieName];
            if (isCookieValueValid(cookieValueFromKeychain)) {
                [cookies addEntriesFromDictionary:@{cookieName:cookieValueFromKeychain}];
            }
        } else {
            NSString *cookieValue = [NYUserDefaultsHelper objectForKey:cookieName];
            if (isCookieValueValid(cookieValue)) {
                [cookies addEntriesFromDictionary:@{cookieName:cookieValue}];
            }
        }
    }];
}

- (void)restoreCookies {
    typeof(self) __weak weakSelf = self;
    [_cookieDict.copy enumerateKeysAndObjectsUsingBlock:^(NSString *cookieName, NSString *cookieValue, BOOL *stop) {
        [weakSelf setCookieValue:cookieValue forCookieName:cookieName];
    }];
}

- (void)restoreDictCookies:(NSString *)cookieName value:(NSString *)cookieValue {
    _cookieDict[cookieName] = cookieValue;
}

- (void)forceUpdateUAuth {
    /*
     只有 HTTPCookieStorage 裡的 uAuth 跟我們自己存的 uAuth 不一樣時才要拿自己存的蓋過去，避免不必要的 set 動作（somehow API request 可能會沒有帶 uAuth，此時 response 會給一組臨時的 uAuth 並要求 setCookie，這個時候就會被蓋成我們不想要的資料，所以需要再覆蓋回來）
     */
    __block BOOL shouldUpdateUAuth = NO;
    __block NSString *uAuth = self.cookieDict[kCOOKIE_NAME_U_AUTH];
    if (uAuth == nil) { return; }
    NSArray<NSHTTPCookie *> *matchedCookies = [self filteredCookiesWithPredicateString:[NSString stringWithFormat:@"name == '%@'", kCOOKIE_NAME_U_AUTH]];
    [matchedCookies enumerateObjectsUsingBlock:^(NSHTTPCookie *cookie, NSUInteger idx, BOOL *stop) {
        if ([uAuth isEqualToString:cookie.value] == NO) {
            shouldUpdateUAuth = YES;
            *stop = YES;
        }
    }];
    
    if (shouldUpdateUAuth) {
        [self setNSHTTPCookieWithCookieName:kCOOKIE_NAME_U_AUTH
                                   andValue:uAuth];
    }
}

- (void)updateUauthFromLocalGUID {
    NSString *guid = [self cookieValueFromLocal:kCOOKIE_NAME_GUID];
    if (guid.length > 0) {
        [[NYDataProvider sharedInstance] getUauthWithCompletionHandler:^(NSDictionary *data, NSError *error) {
            NSDictionary *response = data[kDATA_KEY];
            if ([response[@"ReturnCode"] isEqualToString:@"API0001"]) {
                NSString *uAuth = response[@"uAUTH"];
                if ([uAuth isKindOfClass:[NSString class]] && uAuth.length > 0) {
                    [self setCookieValue:uAuth forCookieName:kCOOKIE_NAME_U_AUTH];
                }
            }
        }];
    }
}

- (void)updateServerUDIDIfVDIDChanged {
    NSString *VDID = [self VDID];
    
    BOOL isVDIDChanged = ![VDID isEqualToString:[self localVDID]];
    if (isVDIDChanged) {
        [[NYDataProvider sharedInstance] updateServerUDIDWithCompletionHandler:^(NSDictionary *data, NSError *error) {
            NSDictionary *response = data[kDATA_KEY];
            if ([response isKindOfClass:[NSDictionary class]] && [response[@"ReturnCode"] isEqualToString:@"API0001"]) {
                [NYUserDefault setVDID:VDID];
            }
        }];
    }
}

- (void)registerAppIfGUIDNotExist {
    NSInteger count = 0;
    // 如果沒拿到GUID, retry 3次。
    while ([[self cookieValueFromLocal:kCOOKIE_NAME_GUID] length] == 0 && count < 3) {
        NSString *guid = [self cookieValueFromLocal:kCOOKIE_NAME_GUID];
        
        if ([guid isEqualToString:@""]) {
            [self registerAPP];
        }
        
        count++;
    }
}

- (void)setAppVerCookie {
    // Make sure appVer cookie get updated
    NSString *appVer = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    [self setCookieValue:appVer forCookieName:kCOOKIE_NAME_APP_VER];
}

- (void)overwriteSpecificCookies {
    [self setAppVerCookie];
}

- (void)registerAPP {
    // 第一次使用
    NSString *VDID = [self VDID];
    
    typeof(self) __weak weakSelf = self;
    [[NYDataProvider sharedInstance]
     registerAppWithVDID:VDID
     shopId:[NYGlobalData shopId]
     platform:@"iOS"
     sendSynchronousRequest:YES
     completionHandler:^(NSDictionary *data, NSError *error) {
        dispatch_barrier_sync(dispatch_queue_create("com.nineyi.SerialQueue", DISPATCH_QUEUE_SERIAL), ^{
            // App 首次開啟，會 retry 3 次，此處先不顯示 error message
            [weakSelf handleRegisterResponse:data shouldAlert:NO vdid:VDID];
        });
     }];
}

- (void)registerAPPWithCompletion:(void(^)(void))completion {
    NSString *VDID = [self VDID];
    
    typeof(self) __weak weakSelf = self;
    [[NYDataProvider sharedInstance]
     registerAppWithVDID:VDID
     shopId:[NYGlobalData shopId]
     platform:@"iOS"
     sendSynchronousRequest:NO
     completionHandler:^(NSDictionary *data, NSError *error) {
        // 從 CMSLaunchViewController 來的，顯示 error message
        [weakSelf handleRegisterResponse:data shouldAlert:YES vdid:VDID];
        
        completion();
     }];
}

- (void)handleRegisterResponse:(NSDictionary *)data shouldAlert:(BOOL)shouldAlert vdid:(NSString *)vdid {
    NSDictionary *dict = data[kDATA_KEY];
    id returnCode = dict[@"ReturnCode"];
    NSString *defaultErrorMsg = NYLocalizedString(@"common_alert_system_is_busy", nil);
    
    void(^alertWithErrorCode)(NSString *) = ^(NSString *message){
        if (!shouldAlert) {
            return;
        }
        
        NSString *errorCode = [AppErrorCodeLegacy p01199];
        NSString *errorCodeDesc = [NSString stringWithFormat:NYLocalizedString(@"common_alert_error_code", nil), errorCode];
        NSString *alertMessage = [message stringByAppendingFormat:@"\n(%@)", errorCodeDesc];
        [self displayErrorAlertWithTitle:nil message:alertMessage];
    };
    
    // 無效的 response or returnCode
    if (!dict || ![returnCode isKindOfClass:[NSString class]]) {
        alertWithErrorCode(defaultErrorMsg);
        return;
    }
    
    // 成功 (API0001)
    if ([returnCode isEqualToString:@"API0001"]) {
        NSString *GUID = dict[@"Data"];
        NSString *uAuth = dict[@"uAUTH"];
        
        GUID = GUID.length > 0 ? GUID : kNYCookieStatusServerReturnsEmpty;
        uAuth = uAuth.length > 0 ? uAuth : kNYCookieStatusServerReturnsEmpty;
        
        // 寫入CookieStorage
        [self setCookieWithGUID:GUID uAuth:uAuth VDID:vdid];
        
        // uAUTH_express 要清掉
        [self removeCookieWithCookieName:kCOOKIE_NAME_U_AUTH_EXPRESS];
        return;
    }
    
    if (!shouldAlert) {
        return;
    }
    
    // 其他錯誤情況
    NSString *message = dict[@"Message"];
    
    // Server 已知錯誤，不加 error code
    // API0002: 兩把金鑰都解密失敗
    // API0005: 舊金鑰被阻擋
    BOOL isKnownServerError = ([returnCode isEqualToString:@"API0002"] || [returnCode isEqualToString:@"API0005"]);
    
    if (isKnownServerError) {
        if (message && message.length > 0) {
            [self displayErrorAlertWithTitle:nil message:message];
            return;
        }
    }
    
    if (message && message.length > 0) {
        alertWithErrorCode(message);
    } else {
        alertWithErrorCode(defaultErrorMsg);
    }
}

- (void)displayErrorAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIViewController *rootVC = [[NYUIComponentUtil getKeyWindow] rootViewController];
    [rootVC ny_displayAlertWithTitle:title message:message];
}

- (void) setNSHTTPCookieWithCookieName:(NSString* ) cookieName andValue:(NSString*) cookieValue {
    [self removeCookieWithCookieName:cookieName shouldRemoveFromNSUserDefaults:NO];
    if ([cookieName isEqualToString:kCOOKIE_NAME_U_AUTH]) {
        [self restoreDictCookies:cookieName value:cookieValue];
    }
    
    for (NSString *domain in [self domainNames]) {
        NSMutableDictionary *cookieProperties = @{}.mutableCopy;
        [cookieProperties setObject:cookieName forKey:NSHTTPCookieName];
        [cookieProperties setObject:cookieValue forKey:NSHTTPCookieValue];
        [cookieProperties setObject:domain forKey:NSHTTPCookieDomain];
        [cookieProperties setObject:@"/" forKey:NSHTTPCookiePath];

        if ([cookieName isEqualToString:@"uAUTH"]) {
            [cookieProperties setObject:@"true" forKey:@"HttpOnly"];
        }
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }
}

- (void)setCookiesToDomain:(NSString* )domainName {
    [_cookieDict enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSMutableDictionary *properties = @{}.mutableCopy;
        [properties setObject:key forKey:NSHTTPCookieName];
        [properties setObject:obj forKey:NSHTTPCookieValue];
        [properties setObject:domainName forKey:NSHTTPCookieDomain];
        [properties setObject:@"/" forKey:NSHTTPCookiePath];
        NSHTTPCookie *newCookie = [NSHTTPCookie cookieWithProperties:properties];
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:newCookie];
    }];
}

- (void)setCookieWithGUID:(NSString *)GUID uAuth:(NSString *)uAuth VDID:(NSString *)VDID {
    [self setCookieValue:GUID forCookieName:kCOOKIE_NAME_GUID];
    [self setCookieValue:uAuth forCookieName:kCOOKIE_NAME_U_AUTH];
    [NYUserDefault setVDID:VDID];
    
    // 移除 Clip 來的 uAUTH_express
    [self removeCookieWithCookieName:kCOOKIE_NAME_U_AUTH_EXPRESS];
}

- (NSString *)keychainValueForKey:(NSString *)key {
    NSString *value;
    if ([key isEqualToString:kCOOKIE_NAME_U_AUTH]) {
        value = [NYKeychainHelper uAuth];
    } else if ([key isEqualToString:kCOOKIE_NAME_GUID]) {
        value = [NYKeychainHelper GUID];
    } else {
        NSAssert(NO, @"不認識的 Cookie Name");
    }
    
    return value;
}

- (void)setKeychainValue:(NSString *)value forKey:(NSString *)key {
    if ([key isEqualToString:kCOOKIE_NAME_U_AUTH]) {
        [NYKeychainHelper saveUAUTH:value];
    } else if ([key isEqualToString:kCOOKIE_NAME_GUID]) {
        [NYKeychainHelper saveGUID:value];
        [NYNotificationExtensionKeychainHelper saveGUID:value];
    } else {
        NSAssert(NO, @"不認識的 Cookie Name");
    }
}

- (void)clearGUIDAndUAUTH {
    [NYKeychainHelper deleteGUID];
    [NYKeychainHelper deleteUAUAH];
    _cookieDict[kCOOKIE_NAME_GUID] = nil;
    _cookieDict[kCOOKIE_NAME_U_AUTH] = nil;
}

@end
//
//  NYDataProvider.m
//  NineYiShopping
//
//  Created by stedy on 13/3/8.
//  Copyright (c) 2013年 Julie Lin. All rights reserved.
//

//只會出現model相關的import，不該出現跟view有關的class
#import "NYDataProvider.h"
#import "NYCookieManager.h"
#import "NSArray+Map.h"
#import "NYPHPHTTPClient.h"
#import "NYECouponHTTPSClient.h"
#import "NYCDNHTTPClient.h"
#import "NYHTTPSClient.h"
#import "NYTrackingClient.h"
#import "NYFacebookGraphAPIClient.h"
#import "NYCartHTTPSClient.h"
#import "NYFTSHTTPClient.h"

#import "NYShopObject.h"
#import "NYShopCategoryObject.h"
#import "NYItemObject.h"
#import "NYItemStatusEnum.h"
#import "NYADElementObject.h"
#import "NYShopAppObject.h"
#import "NYShopDiscountObject.h"
#import <NYCore/NYCore-Swift.h>
#import "NYCouponDetailObject.h"
#import "NYPopularListObject.h"
#import "NYInfoModuleObject.h"
#import "NYMemberCardObject.h"
#import "NYServiceInfoObject.h"
#import "NYGraphQLTemporaryDataMediator.h"

#import "NYFacebookHelper.h"
#import <NYCore/UIDevice+PlatformHelper.h>
#import <NYCore/NSString+Regex.h>
#import "NYUserDefault.h"
#import "NYBaseURLConfig.h"
#import "NYActivityDetailObject.h"

#import <NYCore/NSString+TimestampDecoder.h>
#import <NYCore/NSDate+Calculate.h>

#import <AdSupport/AdSupport.h>

NSString * const kNYDataKey = @"DATA_KEY";
NSString * const kNYAPIDataKey = @"Data";
NSString * const kNYAPIReturnCodeKey = @"ReturnCode";
NSString * const kNYAPIMessage = @"Message";

@interface NYDataProvider ()
@property (nonatomic) NSNumber *shopId;
@property (nonatomic, assign) NSTimeInterval lastUpdate;
@end

@implementation NYDataProvider
+ (instancetype)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init]; // or some other init method
    });

    [_sharedObject keepAlive];
    return _sharedObject;
}

-(instancetype)init{
    self = [super init];
    if (self) {
        self.shopId = [NYGlobalData shopId];
        self.lastUpdate = 0;
    }
    return self;
}

- (NSString *)GUID {
    return [[NYCookieManager sharedManager] cookieValueFromLocal:kCOOKIE_NAME_GUID];
}

- (NSString *)VDID {
    return [[NYCookieManager sharedManager] VDID];
}

#pragma mark - AD Layout

-(void)getShopLayoutTemplateDataForShopId:(NSInteger)shopId
                                andADCode:(NSString *)adCode
                        completionHandler:(DataSourceCompletionHandler)handler
{
    NSString *mobileAdCode = [@"MobileHome_" stringByAppendingString:adCode];
    NSString *path = [NSString stringWithFormat:@"LayoutTemplateData/GetLayoutTemplateData/%@/%@", @(shopId), mobileAdCode];
    
    [[NYCDNHTTPClient sharedClient]
     getPath:path
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON)
         {
             NSArray *object = [self parseLayoutTemplate:adCode withJSONDictionary:JSON];
             handler(@{
                     kAPI_AD_CODE_KEY : adCode,
                     kDATA_KEY : object,
                     }, nil );
         }
         else
         {
             handler( nil, NineYiErrorWithCode(0) );
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        handler( nil, error );
    }];

}

#pragma mark - shop home item

-(void)getShopBasicInfoForShopId:(NSInteger)shopId
               completionHandler:(DataSourceCompletionHandler)handler
{
    NSString *path = [NSString stringWithFormat:@"Shop/GetShopintroductionV2/%@", @(shopId)];
    
    [[NYCDNHTTPClient sharedClient]
     getPath:path
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             if( JSON[@"ShopIntroduceEntity"] == [NSNull null] ) {
                 handler( nil, NineYiErrorWithCode(0));
             }
             else {
                 handler(@{kDATA_KEY : [[NYShopObject alloc] initWithJSONDict: JSON]}, nil );
             }
         }
         else {
             handler( nil, NineYiErrorWithCode(0) );
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        handler( nil, error );
     }];
}

#pragma mark - category list

-(void)getShopCategoryListV2ForShopId:(int)shopId
                    completionHandler:(DataSourceCompletionHandler)handler {
    //Create client
    NSString *path = [NSString stringWithFormat:@"Shop/GetShopCategoryListV2/%d", shopId];
    
    //Parameter
    NSDictionary *params = @{};
    
    //Get (大致跟舊的一樣)
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:params success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        if (JSON) {
            handler(@{kDATA_KEY : [self parseShopCategoryListWithJSONDictionary:JSON]}, nil );
        }
        else {
            handler(nil, NineYiErrorWithCode(0));
        }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         //Error
         handler(nil, error);
     }];
}

#pragma mark - Item detail page related

- (void)getItemStockListBySaleProductSKUIdList:(NSArray *)SKUIdList
                            completionHandler:(void(^)(NSArray *sellingQtyList, NSError *error))completionHandler {
    NSString *idListString = [SKUIdList componentsJoinedByString:@","];
    
    [[NYHTTPSClient sharedClient] postPath:@"ProductStock/GetSellingQtyListNew"
                                parameters:@{@"ids" : idListString}
                                   success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             NSArray *sellingQtyList = JSON;
             completionHandler(sellingQtyList, nil);
         } else {
             completionHandler(nil, NineYiErrorWithCode(0));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

- (void)getSalePageRealTimeData:(NSNumber *)salepageId completionHandler:(DataSourceCompletionHandler)handler {
    [[NYHTTPSClient sharedClient]
     postPath:[NSString stringWithFormat:@"SalePage/GetSalePageRealTimeData/%@", salepageId]
     parameters:nil
     success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
         handler(@{kDATA_KEY : responseObject}, nil );
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        handler(nil, error);
     }];
}

- (void)getItemDetailPageMoreInfoWithShopID:(NSNumber *)shopID
                                 salePageID:(NSNumber *)salePageID
                          completionHandler:(DataSourceCompletionHandler)completionHandler {
    NSString *path = [NSString stringWithFormat:@"SalePage/GetSalePageMoreInfo/%@", salePageID];
    NSDictionary *params = @{@"source":@"iOSApp",
                             @"shopId":shopID};
    
    [[NYCDNHTTPClient sharedClient]
     getPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             completionHandler(JSON, nil);
         } else {
             completionHandler(nil, NineYiErrorWithCode(0));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

- (void)getCMSSalePageListByIds:(NSArray *)ids
           includeSalePageGroup:(BOOL)includeSalePageGroup
          withCompletionHandler:(DataSourceCompletionHandler)handler{
    if (!ids) {
        handler(nil, NineYiErrorWithCode(0));
        return;
    }
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    [params setValue:_shopId forKey:@"shopId"];
    NSString * paramString = [ids componentsJoinedByString:@","];
    [params setValue:paramString forKey:@"salePageIds"];
    [params setValue:(includeSalePageGroup)? @"true" : @"false" forKey:@"includeSalePageGroup"];
    [params setValue:false forKey:@"includeInvisibleSalepage"];
    
    [[NYHTTPSClient sharedClient]
     getPath: @"Cms/GetSalePageListById"
     parameters: params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        if (!JSON) {
            handler(nil, NineYiErrorWithCode(0));
            return;
        }
        
        if (![JSON[kNYAPIDataKey] isKindOfClass:[NSArray class]]) {
            handler(nil, NineYiErrorWithCode(0));
            return;
        }
        
        NSArray *itemObjects = [JSON[kNYAPIDataKey] map: (id)^(id o) {
            return [[NYItemObject alloc] initWithJSONDict:o];
        }];
        
        if (!itemObjects) {
            handler(nil, NineYiErrorWithCode(0));
        } else {
            handler(@{kNYAPIDataKey : itemObjects}, nil);
        }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler(nil, error);
     }];
}

-(void)deleteFavoriteProductForSalePageId:(NSString *)salePageId
                        completionHandler: (DataSourceCompletionHandler) handler
{
   [[NYHTTPSClient sharedClient]
     postPath: @"TraceSalePageList/DeleteItem"
    parameters: @{ @"salePageId":salePageId, @"ShopId":_shopId }
     success:^(NSURLSessionDataTask *operation, id JSON) {
         handler(@{}, nil ); // this command has no return value, always success
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler( nil, error );
     }];

}

-(void)getFavoriteProductListWithCompletionHandler:(DataSourceCompletionHandler) handler
{
    // TODO: 用delegate是暫解，避免NineyiAppApi與NYGraphQLClient兩個pods相互循環引用。最佳解是把使用方(NYLoginHelper, NYFavoriteManager)與NYDataProvider切乾淨
    [[NYGraphQLTemporaryDataMediator shared] getFavoriteProductListWithCompletionHandler: handler];
}

// FIXME: this seems redundant with the fact that we can get the listing of the products already
// 24.8 移除 收藏舊邏輯, 新邏輯詳見 initFavoriteList
// 先保留 comment, 觀察幾個版本再移除
//-(void)getFavoriteProductCountWithCompletionHandler:(DataSourceCompletionHandler) handler
//{
//    [[NYHTTPSClient sharedClient] postPath:@"TraceSalePageList/GetCount" parameters:@{@"ShopId":_shopId} success:^(NSURLSessionDataTask *operation, NSNumber *count) {
//        handler(@{kDATA_KEY:count}, nil);
//    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
//        handler(nil, error);
//    }];
//}

-(void)insertFavoriteProductForSalePageId:(NSString *)salePageId
                        completionHandler: (DataSourceCompletionHandler) handler
{
    // NOTE: 原本的邏輯是先去拉server-side的收藏商品數再打InsertItem，似乎沒必要。
    // 直接打InsertItem就好了，server-side的收藏商品上限是100個，如果要收藏第101個商品時，
    // Server會將最舊的收藏商品踢掉，然後將第101個商品加入
    [[NYHTTPSClient sharedClient]
     postPath:@"TraceSalePageList/InsertItem"
     parameters:@{@"salePageId":salePageId, @"ShopId":_shopId}
     success:^(NSURLSessionDataTask *operation, id res) {
         handler(@{}, nil); // this command has no return value, always success
     } failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler(nil, error);
     }];
}

// Recently browsed APIs
// FIXME
-(NSArray*)getRecentlyBrowsedSalePageIdsAndTitles
{
    NSUserDefaults* pref = [NSUserDefaults standardUserDefaults];
    NSMutableArray *prev20 = [[pref objectForKey: kPREF_RECENTLY_BROWSED] mutableCopy];
    if (prev20.count > 20) {
        [prev20 removeObjectsInRange:NSMakeRange(20, prev20.count - 20)];
    }
    return prev20;
}

-(void)addRecentlyBrowsedForSalePageId:(NSInteger)salePageId andTitle:(NSString*)title
{
    NSUserDefaults* pref = [NSUserDefaults standardUserDefaults];
    NSMutableArray* recents = [[pref objectForKey: kPREF_RECENTLY_BROWSED] mutableCopy];
    if( !recents ) recents = [NSMutableArray new];
    if (!title) title = @"";
    
    NSDictionary* entry = @{ @"SalePageId" : @(salePageId), @"Title" : title};
    
    // first, remove existing pair from the array
    [recents removeObject: entry];
    
    // then, append the new one to the "top"
    [recents insertObject: entry atIndex: 0];
    
    // trim if too long
//    if( recents.count > 20 ) [recents removeLastObject];
    
    [pref setObject: recents forKey: kPREF_RECENTLY_BROWSED];
    [pref synchronize];
}

-(void)clearAllRecentlyBroswedList{
    NSUserDefaults* pref = [NSUserDefaults standardUserDefaults];
    [pref removeObjectForKey:kPREF_RECENTLY_BROWSED];
    [pref synchronize];    
}

#pragma mark - cart


-(void)getCartItemCountWithCompletionHandler:(DataSourceCompletionHandler)handler{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NYCartHTTPSClient sharedClient] postPath:@"ShoppingCartV2/GetCount" parameters:@{ @"ShopId":_shopId} success:^(NSURLSessionDataTask *operation, NSNumber *count) {
         handler(@{kDATA_KEY : count}, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler( nil, error );
    }];
}

#pragma mark - o2o

- (void)getLocationPushInformation:(int)shopId userLocation:(CLLocation *)userLocation completionHandler:(DataSourceCompletionHandler)handler {
    //Create client
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"Lbs/GetLbsList";

    //Parameter
    NSDictionary *parameters = @{@"shopId"  : @(shopId),
                                 @"lat"     : @(userLocation.coordinate.latitude),
                                 @"lon"     : @(userLocation.coordinate.longitude)};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        handler(JSON, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        handler(nil, error);
    }];
}

- (void)getCouponListByShopId:(NSNumber *)shopId CouponType:(NSString *)type completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYPHPHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"o2o/api/coupon/%@/%@", type, shopId]
                 parameters:nil
                    success:^(NSURLSessionDataTask *operation, id JSON) {
                        if (JSON) {
                            NSArray *couponDictionaries = (NSArray *)JSON[@"feed"];
                            __block NSMutableArray *coupons = [NSMutableArray arrayWithCapacity:couponDictionaries.count];
                            [couponDictionaries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

                                if ([@"my" isEqualToString:type]) {
                                    NYCouponDetailObject *couponDetailObject = [[NYCouponDetailObject alloc] initMyCouponWithJSONDictionary:obj];
                                    [coupons addObject:couponDetailObject];
                                }
                                else {
                                    NYCouponDetailObject *couponDetailObject = [[NYCouponDetailObject alloc] initWithJSONDictionary:obj];
                                    [coupons addObject:couponDetailObject];
                                }
                            }];
                            handler (@{kDATA_KEY:coupons}, nil);
                        }else {
                            handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
                        }
                    }
                    failure:^(NSURLSessionDataTask *operation, NSError *error) {
                        handler (nil, error);
                    }];
}


- (void)getCouponListByShopId:(NSNumber *)shopId IsAllCoupon:(BOOL)isAllCoupon completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYPHPHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"o2o/api/coupon/%@/%@", (isAllCoupon) ? @"list" : @"my", shopId]
             parameters:nil
                success:^(NSURLSessionDataTask *operation, id JSON) {
                    if (JSON) {
                        NSArray *couponDictionaries = (NSArray *)JSON[@"feed"];
                        __block NSMutableArray *coupons = [NSMutableArray arrayWithCapacity:couponDictionaries.count];
                        [couponDictionaries enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            NYCouponDetailObject *couponDetailObject = [[NYCouponDetailObject alloc] initWithJSONDictionary:obj];
                            [coupons addObject:couponDetailObject];
                        }];
                        handler (@{kDATA_KEY:coupons}, nil);
                    }else {
                        handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
                    }
                }
                failure:^(NSURLSessionDataTask *operation, NSError *error) {
                    handler (nil, error);
                }];
}

- (void)getCouponDetailByCouponId:(NSString *)couponId shopId:(int)shopId completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYPHPHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"o2o/api/coupon/detail/%@", couponId]
             parameters:nil
                success:^(NSURLSessionDataTask *operation, id JSON) {
                    __block NYCouponDetailObject *couponDetailObject;
                    if (([JSON[@"feed"] count] > 0) && (![[[JSON valueForKeyPath:@"feed.type"] firstObject] isEqualToString:@"location"])) {
                        [(NSArray *)JSON[@"feed"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            couponDetailObject = [[NYCouponDetailObject alloc] initWithJSONDictionary:obj];
                        }];
                    }else {
                        couponDetailObject = [[NYCouponDetailObject alloc] initWithJSONDictionary:nil];
                    }
                    handler (@{kDATA_KEY:couponDetailObject}, nil);
                } failure:^(NSURLSessionDataTask *operation, NSError *error) {
                    handler (nil, error);
                }];
}

- (void)takeCouponActionByCouponId:(int)couponId completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYPHPHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"o2o/api/v2/coupon/take/%d", couponId]
                                 parameters:@{@"source": @"iOSApp",
                                              @"supportVersion": eCouponSupportVersion}
                 success:^(NSURLSessionDataTask *operation, id JSON) {
                     if (JSON) {
                         handler (JSON, nil);
                     }else {
                         handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
                     }
                 }
                 failure:^(NSURLSessionDataTask *operation, NSError *error) {
                     handler (nil, error);
                 }];
}

- (void)useCouponActionByCouponId:(int)couponId userCouponID:(NSNumber*)userCouponID userLocation:(CLLocation *)userLocation completionHandler:(DataSourceCompletionHandler)handler
{
    NSDictionary* para = nil;
    if (userCouponID)
    {
        para = @{@"user_coupon_id":userCouponID,
                 @"lat":[NSNumber numberWithFloat:userLocation.coordinate.latitude],
                 @"lon":[NSNumber numberWithFloat:userLocation.coordinate.longitude]
                 };
    }
    else
    {
        para = @{@"lat":[NSNumber numberWithFloat:userLocation.coordinate.latitude],
                 @"lon":[NSNumber numberWithFloat:userLocation.coordinate.longitude]
                 };
    }
    
    [[NYPHPHTTPClient sharedClient] postPath:[NSString stringWithFormat:@"o2o/api/coupon/use/%d", couponId]
              parameters:para
                 success:^(NSURLSessionDataTask *operation, id JSON) {
                     if (JSON) {
                         handler (JSON, nil);
                     }else {
                         handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
                     }
                 }
                 failure:^(NSURLSessionDataTask *operation, NSError *error) {
                     handler (nil, error);
                 }];
}

- (void)getCouponSerialNumberByUserCouponID:(NSNumber *)userCouponID
                          completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYPHPHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"o2o/api/coupon/serialnumber/%@", userCouponID]
                                 parameters:nil
                                    success:^(NSURLSessionDataTask *operation, id JSON) {
                                        //12/25note:  出現錯誤訊息時JSON還是有東西，return code是空字串，錯誤判斷在caller做
                                        handler (JSON, nil);
                                    }
                                    failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                        handler (nil, error);
                                    }];
}

#pragma mark - eCoupon

- (void)setMemberECouponByCode:(NSString *)code
                        shopId:(NSNumber *)shopId
                   eCouponType:(NYECouponType)eCouponType
             CompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYECouponHTTPSClient sharedClient]
     postPath:@"ECoupon/SetMemberECouponByCode"
     parameters:@{@"Code": code,
                  @"ShopId": shopId,
                  @"GUID": [self GUID],
                  @"eCouponType":[NYECouponTypeConverter eCouponTypeStringByType:eCouponType],
                  @"source":@"iOSApp",
                  @"supportVersion":eCouponSupportVersion}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         handler (JSON, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)setMemberECouponByECouponId:(NSNumber *)eCouponId CompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYECouponHTTPSClient sharedClient]
     postPath:@"ECoupon/SetMemberECouponByECouponId"
     parameters:@{@"ECouponId": eCouponId,
                  @"GUID": [self GUID],
                  @"eCouponType":[NYECouponTypeConverter eCouponTypeStringByType:NYECouponTypeAll],
                  @"source":@"iOSApp",
                  @"supportVersion":eCouponSupportVersion}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             handler (JSON, nil);
         }
         else {
             handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)setMemberFirstDownloadECouponByECouponId:(NSNumber *)firstDownloadECouponId CompletionHandler:(DataSourceCompletionHandler)handler {
    [[NYECouponHTTPSClient sharedClient]
     postPath:@"ECoupon/SetMemberFirstDownloadECouponByECouponId"
     parameters:@{@"ECouponId": firstDownloadECouponId,
                  @"GUID": [self GUID]}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             handler (JSON, nil);
         }
         else {
             handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
 
}

#pragma mark - Shop Discount

-(void)getShopDiscountDataWithPromotionId:(NSInteger)promotionId CompletionHandler:(DataSourceCompletionHandler)handler{
    
    NSDictionary *parameters = @{@"id":@(promotionId)};

    [[NYHTTPSClient sharedClient]
     getPath: @"Promotion/GetDetail"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, NSDictionary* JSON) {
         if (JSON) {
             //Note:舊API, error時會傳string, 這邊硬轉成新式的Error格式
             if ([JSON isKindOfClass:[NSString class]]) {
                 NSString *message = (NSString *)JSON;
                 JSON = @{kNYAPIReturnCodeKey : @"API0002",
                          kNYAPIDataKey : [NSDictionary dictionary],
                          kNYAPIMessage : message};
             }
             
             handler(@{kDATA_KEY : JSON}, nil);
         }
         else {
             handler( nil, NineYiErrorWithCode(NYDataProviderErrorCodeNoJSON) );
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler( nil, error );
     }];
}

#pragma mark - Location Wizard

- (void)getMemberInfoWithCompletionHandler:(DataSourceCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"Location/GetMemberInfo" parameters:nil success:^(NSURLSessionDataTask *operation, NSDictionary *JSON) {
         if ([JSON[kNYAPIReturnCodeKey] isEqualToString:@"API0001"]) {
             if ([JSON[kNYAPIDataKey] count] == 0) {
                 completionHandler(nil, NineYiErrorWithCode(NYDataProviderErrorCodeNoJSON));
             }
             else {
                completionHandler(@{kDATA_KEY : JSON}, nil);
             }
         }
         else {
             completionHandler(nil, NineYiErrorWithCode(NYDataProviderErrorCodeNoJSON));
         }
     } failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

#pragma mark
// get hot item list
-(void)getShopSalePageHotItemListByCategoryId:(int)categoryId
                                      orderBy:(NSString *)orderBy
                                   salePageId:(int)salePageId
                            completionHandler: (DataSourceCompletionHandler) handler{
    NSString *path = [@"SalePage/GetSalePageHotListByShopCategoryId/" stringByAppendingFormat:@"%d", categoryId];
    
    NSDictionary *params =
    @{
    @"o"       : orderBy,
    @"sid"    : [NSNumber numberWithInt:salePageId]
    };
    
    [[NYCDNHTTPClient sharedClient]
     getPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
         NSMutableArray *allData = [NSMutableArray array];
         for (NSArray *data in JSON[@"data"]) {
             NSArray *newArray = [allData arrayByAddingObjectsFromArray:data];
             allData = [newArray mutableCopy];
         }
         NSArray *result = [allData map: (id)^(id o) {
             return [[NYItemObject alloc] initWithJSONDict: o];
         }];
         handler(@{kDATA_KEY : result}, nil );
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler( nil, error );
     }];
}

//notification center

-(void)getNotificationDataByShopId:(NSInteger)shopId
                        startIndex:(NSInteger)startIndex
                          maxCount:(NSInteger)maxCount
                 completionHandler:(DataSourceCompletionHandler) handler{
    
    NSDictionary *params =
    @{
    @"shopId"       : [NSString stringWithFormat:@"%ld", (long)shopId],
    @"startIndex"   : [NSString stringWithFormat:@"%ld", (long)startIndex],
    @"maxCount"     : [NSString stringWithFormat:@"%ld", (long)maxCount]
    };
    
    [[NYHTTPSClient sharedClient]
     postPath: @"notificationcenter/getfrontendList"
     parameters: params
     success:^(NSURLSessionDataTask *operation, NSArray* JSON) {
         NSArray* result = [JSON map: (id)^(id obj) {
             return [[RoutingObject alloc] initWithJson:obj];
         }];
         handler(@{kDATA_KEY : result}, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler( nil, error );
     }];
}

// app push notification setting

-(void)getAllAPPPushNotificationSettingWithCompletionHandler:(DataSourceCompletionHandler) handler
{
    NSDictionary *params = @{@"GUID":[self GUID]};
    
    [[NYHTTPSClient sharedClient]
     postPath: @"APPNotification/GetAllAppPhshProfileDataV2"
     parameters: params
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if ([@"API0001" isEqualToString:JSON[kNYAPIReturnCodeKey]]) {
             handler(@{kDATA_KEY:JSON[kNYAPIDataKey][@"APPPushProfileList"]}, nil);
         }
         else {
             handler(nil, [NSError errorWithDomain:JSON[kNYAPIMessage] code:0 userInfo:@{@"GUID": [self GUID]}]);
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler(nil, error);
     }];
}

// Sever 說原本的 API "APPNotification/GetAllAppPhshProfileDataV2/" 是拿 Read/Write DB 會影響效能
// Launch 時改打新 API 拿 Readonly DB 資料，參數和回傳 data 都和原本一樣
-(void)getAllAPPPushNotificationSettingFromReadOnlyDBWithCompletionHandler:(DataSourceCompletionHandler) handler
{
    NSDictionary *params = @{@"GUID":[self GUID]};
    
    [[NYHTTPSClient sharedClient]
     postPath: @"APPNotification/GetAllAppPushProfileDataFromReplica"
     parameters: params
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if ([@"API0001" isEqualToString:JSON[kNYAPIReturnCodeKey]]) {
             handler(@{kDATA_KEY:JSON[kNYAPIDataKey][@"APPPushProfileList"]}, nil);
         }
         else {
             handler(nil, [NSError errorWithDomain:JSON[kNYAPIMessage] code:0 userInfo:@{@"GUID": [self GUID]}]);
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler(nil, error);
     }];
}

- (void)set91AppPushNotificationSettingForType:(NSString *)notificationType
                                       isOn:(BOOL)isOn
                          completionHandler:(AppPushSettingCompletionHandler)completionHandler {
    NSDictionary *params = @{@"appPushProfileDataEntites":@[@{@"GUID":[self GUID],
                                                              @"type":notificationType,
                                                              @"switchValue" : [NSNumber numberWithBool:isOn]
                                                              }]};
    
    [self set91AppPushProfileWithParams:params completionHandler:completionHandler];
}

- (void)set91AppPushProfileWithParams:(NSDictionary *)params completionHandler:(AppPushSettingCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"APPNotification/SetAPPPushProfileDataV2" parameters:params requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        completionHandler(returnCode, message, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

// check web api status
- (void)checkWebApiStatusWithCompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient]
     getPath:@"APPNotification/checkwebapistatus"
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id JSON) {
         if ([@"online" isEqualToString:JSON[@"Status"]]) {
             handler (JSON, nil);
         }else {
             handler (JSON, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnErrorMessage));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

#pragma mark - Cookie Related

- (void)registerAppWithVDID:(NSString *)VDID
                     shopId:(NSNumber *)shopId
                   platform:(NSString *)platform
     sendSynchronousRequest:(BOOL)sendSynchronousRequest
          completionHandler:(DataSourceCompletionHandler)completionHandler {
    NSString *appVer = [NYGlobalData appVersionString];
    NSDictionary *dict = @{@"UDID":VDID,
                           @"ShopID":shopId,
                           @"platformID":platform,
                           @"AdvertisingId":[[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString]?:@"",
                           @"appVer": appVer,
                           @"source":@"iOSApp",
                           @"device":@"Mobile"};
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:0 // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    NSString *jsonString;
    if (!jsonData) {
        NSLog(@"Got an error: %@", error);
    }
    else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    NSString *path = [NSString stringWithFormat:@"APPNotification/APPRegister?appVer=%@", appVer];
    [[NYHTTPSClient sharedClient]
     postPath:path
     dataStr:jsonString
     sendSynchronousRequest:sendSynchronousRequest
     success:^(NSURLSessionDataTask *operation, id JSON) {
         completionHandler(@{kDATA_KEY:JSON}, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

- (void)updateServerUDIDWithCompletionHandler:(DataSourceCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] syncGetPath:@"APPNotification/UpdateUDID" parameters:@{@"GUID":[self GUID], @"UDID":[self VDID]} success:^(NSURLSessionDataTask *operation, id responseObject) {
        completionHandler(@{kDATA_KEY:responseObject}, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

- (void)getUauthWithCompletionHandler:(DataSourceCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] syncGetPath:@"APPNotification/GetuAUTHByGUID"
                                   parameters:@{@"GUID":[self GUID]}
                                      success:^(NSURLSessionDataTask *operation, id responseObject) {
                                          completionHandler(@{kDATA_KEY:responseObject}, nil);
                                      } failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                          completionHandler(nil, error);
                                      }];
}

#pragma mark - Facebook Related

- (void)getFanPageDataWithFanPageID:(NSString *)fanPageID
                        accessToken:(NSString *)accessToken
                          postCount:(NSNumber *)count
                  completionHandler:(void (^)(NSArray *posts, NSError *error))completionHandler {
    NSString *path = [NSString stringWithFormat:@"%@/posts", fanPageID];
    
    NSString *fields = @"from,message,picture,link,source,name,description,icon,type,status_type,object_id,created_time,child_attachments";
    NSDictionary *params = @{@"limit": @(25),
                             @"access_token": accessToken,
                             @"fields": fields
                             };
    
    [[NYFacebookGraphAPIClient sharedClient] getPath:path parameters:params success:^(NSURLSessionDataTask *operation, NSDictionary *JSON) {
        completionHandler(JSON[@"data"], nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

- (void)getFanPagePhotoURLsWithAccessToken:(NSString *)accessToken
                                    postID:(NSString *)postID
                         completionHandler:(void (^)(NSArray *attachment, NSError *error))completionHandler {
    NSString *path = [NSString stringWithFormat:@"%@/attachments", postID];
    [[NYFacebookGraphAPIClient sharedClient] getPath:path parameters:@{@"access_token":accessToken} success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSArray *attachments = [[responseObject valueForKeyPath:@"data.subattachments.data.media.image.src"] lastObject];
        if (![attachments isKindOfClass:[NSArray class]]) {
            attachments = [responseObject valueForKeyPath:@"data.media.image.src"];
        }
        NSMutableArray *attachmentURLs = @[].mutableCopy;
        [attachments enumerateObjectsUsingBlock:^(NSString *urlString, NSUInteger idx, BOOL *stop) {
            NSURL *url = [NSURL URLWithString:urlString];
            if (url) {
                [attachmentURLs addObject:url];
            }
        }];
        completionHandler(attachmentURLs, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

#pragma mark - 2.0

#pragma mark - APP Configuration

- (void)getCDNDomainSynchronouslyWithCompletionHandler:(DataSourceCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] syncGetPath:@"APPNotification/GetWebAPICDNDomain"
                                   parameters:nil
                                      success:^(NSURLSessionDataTask *operation, id responseObject) {
                                          completionHandler(@{kDATA_KEY:responseObject[@"CDNDomain"]}, nil);
                                      }
                                      failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                          completionHandler(nil, error);
                                      }];
}

#pragma mark - Referee

- (void)getAppRefereeSettings:(NSInteger)shopId completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"AppReferee/GetAppRefereeProfile"]
     parameters:@{@"shopId" : @(shopId)}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         handler (@{kDATA_KEY:JSON}, nil);
     } failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)getSimpleLocationList:(NSInteger)shopId completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"AppReferee/GetLocationList"]
     parameters: @{@"shopId" : @(shopId)}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         handler (@{kDATA_KEY:JSON}, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)getLocationEmployeeList:(NSInteger)shopId locationId:(NSInteger)locationId completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"AppReferee/GetLocationEmployeeList"]
     parameters: @{@"shopId" : @(shopId), @"locationId" : @(locationId)}
     success:^(NSURLSessionDataTask *operation, id JSON) {
         handler (@{kDATA_KEY:JSON}, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)insertAppRefereeWithLocationId:(NSInteger)locationId
                                 empId:(NSString *)empId
                        isRequireLogin:(BOOL)isRequireLogin
                            sourceType:(NSString *)sourceType
                       linkClickedTime:(NSString *)linkClickedTime
                     completionHandler:(DataSourceCompletionHandler)handler {
    NSDictionary *paramDic = @{@"guid":[self GUID],
                               @"shopId":_shopId,
                               @"locationId": @(locationId),
                               @"empId": empId,
                               @"isRequireLogin": (isRequireLogin)? @"true" : @"false",
                               @"appRefereeSourceTypeDef": sourceType};
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:paramDic];
    
    if (linkClickedTime) {
        [params setObject:linkClickedTime forKey:@"linkClickedTime"];
    }
    
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"AppReferee/InsertAppReferee"]
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        if (handler != nil) {
            handler (@{kDATA_KEY:JSON}, nil);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        if (handler != nil) {
            handler (nil, error);
        }
    }];
}

- (void)getAppRefereeWithIsRequireLogin:(BOOL)isRequireLogin
                      completionHandler:(void(^)(NSDictionary *responseObject, NSError *error))completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"AppReferee/GetAppReferee"
                                parameters:@{@"guid":[self GUID],
                                             @"shopId":_shopId,
                                             @"isRequireLogin": (isRequireLogin)? @"true" : @"false"}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
                                       completionHandler(responseObject, nil);
                                   } failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                       completionHandler(nil, error);
                                   }];
}


- (void)getReferrerTitleWithCompletionHandler:(void(^)(NSString *referrerTitle, NSError *error))completionHandler {
    [[NYHTTPSClient sharedClient]
     getPath:@"AppReferee/GetReferrerTitle"
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id responseObject) {
         NSString *referrerTitle = nil;
         if ([responseObject isKindOfClass:[NSDictionary class]]) {
             NSDictionary *json = (NSDictionary *)responseObject;
             id data = json[kNYAPIDataKey];
             if ([data isKindOfClass:[NSDictionary class]]) {
                 id title = ((NSDictionary *)data)[@"ReferrerTitle"];
                 if ([title isKindOfClass:[NSString class]]) {
                     referrerTitle = (NSString *)title;
                 }
             }
         }
         if (completionHandler) {
             completionHandler(referrerTitle, nil);
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         if (completionHandler) {
             completionHandler(nil, error);
         }
     }];
}

#pragma mark - Activity (活動頁公版)

// 側欄使用 - 已轉換成BFF
- (void)getActivityListForShopID:(NSNumber *)shopID compleionHandler:(ActivityListCompletionHandler)handler {

    // input
    // { 'shopId': 0 }
    NSDictionary *params = @{@"shopId": shopID};

    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:[NSString stringWithFormat:@"Activity/GetActivityList"]
            parameters: params
            success:^(NSURLSessionDataTask *operation, id JSON) {
                if ( JSON && JSON[kNYAPIDataKey] ) {
                    NSMutableArray *activityList = [NSMutableArray array];
                    for (NSDictionary *dict in JSON[kNYAPIDataKey] ) {
                        NYActivityDetailObject *activity = [NYActivityDetailObject activityObjectWithJSONDict:dict];
                        if ( activity ) {
                            [activityList addObject:activity];
                        }
                    }

                    NSString *message    = GET_VAL_WITH_DEFAULT(JSON, kNYAPIMessage, @"");
                    NSString *returnCode = GET_VAL_WITH_DEFAULT(JSON, kNYAPIReturnCodeKey, @"");
                    handler(activityList, message, returnCode, nil);
                }
            }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
                handler ([NSArray array], nil, nil, error); // return an empty Activity array
            }];
}

- (void)getActivityDetailForShopId:(NSNumber *)shopId andActivityId:(NSNumber *)activityId
                  compleionHandler:(ActivityDetailCompletionHandler)handler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];

    // input
    // { 'shopId': 0}
    NSDictionary *params = @{@"shopId": shopId};
    [client
            getPath:[NSString stringWithFormat:@"Activity/GetActivityDetail/%@", activityId]
         parameters: params
            success:^(NSURLSessionDataTask *operation, id JSON) {
                NYActivityDetailObject *activity = nil;
                if ( JSON && JSON[kNYAPIDataKey] ) {
                    activity = [NYActivityDetailObject activityObjectWithJSONDict:JSON[kNYAPIDataKey]];
                }
                NSString *message    = GET_VAL_WITH_DEFAULT(JSON, kNYAPIMessage, @"");
                NSString *returnCode = GET_VAL_WITH_DEFAULT(JSON, kNYAPIReturnCodeKey, @"");
                handler(activity, message, returnCode, nil);
            }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
                handler (nil, nil, nil, error); // return an empty Activity array
            }];

}
#pragma mark - Program Logic

#pragma mark - Private Helpers

-(NSDictionary*)parseShopSalesPageQueryResponseWithJSONDictionary:(NSDictionary*)dict
{
    NSMutableDictionary *res = [NSMutableDictionary new];
    
    res[ @"categoryName"            ] = dict[ @"name"                   ];
    res[ @"categoryAllItemCount"    ] = dict[ @"count"                  ];
    res[ @"parentCategoryName"      ] = dict[ @"parentCategoryText"     ];
    res[ @"parentCategoryId"        ] = dict[ @"parentCategoryId"       ];
    res[ @"categoryNameForDisplay"  ] = dict[ @"name"    ];
    if( [dict.allKeys containsObject: @"listmode"] )
        res[ @"listmode"            ] = dict[ @"listmode"               ];
    res[ kAPI_ITEMS_KEY             ] = [dict[ @"data" ] map: (id)^(id o) {
        return [[NYItemObject alloc] initWithJSONDict: o];
    }];
    
    return res;
}

-(NSDictionary *)parseCategoryQueryResponseWithJSONDictionary:(id)dict
{
    NSMutableDictionary *res = [NSMutableDictionary new];

    NSString *statusValue;
    id statusdef = dict[@"statusdef"];
    if ([statusdef isKindOfClass:[NSString class]]) {
        statusValue = statusdef;
    }
    else if ([statusdef isKindOfClass:[NSNumber class]]) {
        NSNumber *status = (NSNumber *)statusdef;
        if ([@(1) isEqualToNumber:status]) {
            statusValue = @"Normal";
        }
        else if ([@(2) isEqualToNumber:status]) {
            statusValue = @"Hide";
        }
    }
    
    [res setValue:statusValue forKey:@"status"];
    res[ @"categoryName"            ] = dict[ @"name"                   ];
    res[ @"categoryAllItemCount"    ] = dict[ @"count"                  ];
    res[ @"parentCategoryName"      ] = dict[ @"parentCategoryText"     ];
    res[ @"parentCategoryId"        ] = dict[ @"parentCategoryId"       ];
    res[ @"categoryNameForDisplay"  ] = dict[ @"name"    ];
    res[ @"listmode"                ] = dict[ @"listmode"               ];
    
    __block NSMutableArray *promotionDetailList = @[].mutableCopy;
    [dict[@"promotionDetailList"] enumerateObjectsUsingBlock:^(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
        //Parse start and end time (time interval since 1970)
        NSTimeInterval startTimeStamp = [dict[@"StartTime"] decodeAPIFormatTimeStamp] / 1000;
        NSTimeInterval endTimeStamp = [dict[@"EndTime"] decodeAPIFormatTimeStamp] / 1000;
        
        //Current time
        NSTimeInterval currentTimeStamp = [NSDate date].timeIntervalSince1970;
        
        //Check range
        if (currentTimeStamp >= startTimeStamp && currentTimeStamp < endTimeStamp) {
            //優惠活動在時間區間內才會加入
            NYShopDiscountObject *discountObject = [[NYShopDiscountObject alloc] initWithJSONDict:dict];
            [promotionDetailList addObject:discountObject];
        }
    }];

    res[@"promotionDetailList"] = promotionDetailList;
    
    res[ kAPI_ITEMS_KEY             ] = [dict[ @"data" ] map: (id)^(id o) {
        return [[NYItemObject alloc] initWithJSONDict: o];
    }];
    
    if ([promotionDetailList firstObject]) {
        res[@"discount"] = [promotionDetailList firstObject];
    }
    
    return res;
}

-(NSDictionary *)parseSalePageListJSONDictionary:(NSDictionary *)oldData {
    //Products
    NSArray *productionJSONs = oldData[@"SalePageList"];
    NSMutableArray *productionList = [NSMutableArray array];
    [productionJSONs enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull json, NSUInteger idx, BOOL * _Nonnull stop) {
        [productionList addObject:[[NYItemObject alloc] initWithJSONDict:json]];
    }];
    
    //Data
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [[oldData allKeys] enumerateObjectsUsingBlock:^(id _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        [dataDict setObject:oldData[key] forKey:key];
    }];
    [dataDict setObject:productionList forKey:@"SalePageList"];
    
    return dataDict;
}

- (NSArray *)parsePromotionListJSONArray:(NSArray *)promotionJSONs {
    NSMutableArray *promotionList = [NSMutableArray array];
    [promotionJSONs enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull json, NSUInteger idx, BOOL * _Nonnull stop) {
        //Parse start and end time (time interval since 1970)
        NSTimeInterval startTimeStamp = [json[@"StartTime"] decodeAPIFormatTimeStamp] / 1000;
        NSTimeInterval endTimeStamp = [json[@"EndTime"] decodeAPIFormatTimeStamp] / 1000;
        
        //Current time
        NSTimeInterval currentTimeStamp = [NSDate date].timeIntervalSince1970;
        
        //Check range
        if (currentTimeStamp >= startTimeStamp && currentTimeStamp < endTimeStamp) {
            //優惠活動在時間區間內才會加入
            NYShopDiscountObject *discountObject = [[NYShopDiscountObject alloc] initWithJSONDict:json];
            [promotionList addObject:discountObject];
        }
    }];
    
    return promotionList;
}

-(NSArray *)parseLayoutTemplate:(NSString *)adCode withJSONDictionary:(id)dict
{
    adCode = [adCode stringByReplacingOccurrencesOfString:@"MobileHome_" withString:@""];
    return [dict map: (id)^(id o) {
        return [[NYADElementObject alloc] initWithADCode: adCode andJSONDictionary: o];
    }];
}

-(NSArray *)parseShopCategoryListWithJSONDictionary:(id)dict
{
    return [dict[ @"List"] map: (id)^(id o) {
        return [[NYShopCategoryObject alloc] initWithJSONDict: o];
    }];
}

-(NSString *)parseItemStatusWithJSONDictionary:(NSString *)dict{
    NSDictionary *itemStatusHashTable = @{
        @"Normal" : @(ItemStatusNormal).stringValue,
        @"NoStart" : @(ItemStatusNoStart).stringValue,
        @"SoldOut" : @(ItemStatusSoldOut).stringValue,
        @"UnListing" : @(ItemStatusUnListing).stringValue,
        @"IsClosed" : @(ItemStatusIsClosed).stringValue
    };
    
    if ([[itemStatusHashTable allKeys] containsObject:dict]) {
        return itemStatusHashTable[dict];
    }
    else {
        return @(ItemStatusUnknown).stringValue;
    }
    
}

#pragma mark - 2.5 InfoModule (資訊模組)

- (void)infoModuleGetInfoModuleListWithShopId:(NSNumber *)shopId
                                         Type:(NYInfoModuleType)infoModuleType
                                   startIndex:(NSInteger)startIndex
                                     maxCount:(NSInteger)maxCount
                             compleionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *infoObjectsList, NSError *error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];

    //Path
    NSMutableString *infoModulePathString = [NSMutableString stringWithString:@"InfoModuleV2/"];
    switch (infoModuleType) {
        case NYInfoModuleTypeAlbum:
            [infoModulePathString appendString:@"GetAlbumList"];
            break;
            
        case NYInfoModuleTypeArticle:
            [infoModulePathString appendString:@"GetArticleList"];
            break;
            
        case NYInfoModuleTypeVideo:
            [infoModulePathString appendString:@"GetVideoList"];
            break;
            
        default:
            break;
    }
    
    //Parameter
    NSDictionary *parameters = @{@"shopId"      : shopId,
                                 @"startIndex"  : @(startIndex),
                                 @"maxCount"    : @(maxCount)};

    
    //GET
    [client getPath:infoModulePathString parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        NSMutableArray *infoModuleObjectsList = [NSMutableArray array];
        id data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]){
            NSArray *list = data[@"List"];
            NSDictionary *shopInfoDict = data[@"Shop"];
            
            [list enumerateObjectsUsingBlock:^(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
                
                //Parse & Add to list
                NYInfoModuleObject *infoObj = [[NYInfoModuleObject alloc] initWithJSONDictionaryFromWebAPI:dict shopInfoDictionary:shopInfoDict];
                [infoModuleObjectsList addObject:infoObj];
            }];
        }

        
        completionHandler(returnCode, message, infoModuleObjectsList, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)infoModuleGetInfoModuleDetailWithInfoModuleObject:(NYInfoModuleObject *)infoModuleObj
                                         compleionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *dict, NSError *error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    //Path
    NSMutableString *infoModulePathString = [NSMutableString stringWithString:@"InfoModuleV2/"];
    NSString *idParameterString = @"albumId";
    switch (infoModuleObj.type) {
        case NYInfoModuleTypeAlbum:
            [infoModulePathString appendString:@"GetAlbumDetail"];
            idParameterString = @"albumId";
            break;
            
        case NYInfoModuleTypeArticle:
            [infoModulePathString appendString:@"GetArticleDetail"];
            idParameterString = @"articleId";
            break;
            
        case NYInfoModuleTypeVideo:
            [infoModulePathString appendString:@"GetVideoDetail"];
            idParameterString = @"videoId";
            break;
            
        default:
            break;
    }
    
    //Parameter
    NSDictionary *parameters = @{idParameterString : infoModuleObj.objId};
    
    //GET
    [client getPath:infoModulePathString parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];

        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 2.5 Location (門市資訊)

- (void)locationModuleGetCityAreaListWithShopId:(NSNumber *)shopId
                            isEnableRetailStore:(BOOL)isEnableRetailStore
                              completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *cityAreaInfoJSON, NSError *error))completionHandler {
    NSString *path = @"LocationV2/GetCityAreaList";
    
    //Parameter
    NSString *isEnableRetailStoreStr = isEnableRetailStore ? @"true" : @"false";
    NSDictionary *parameters = @{@"shopId" : shopId,
                                 @"IsEnableRetailStore" : isEnableRetailStoreStr};
    
    //Get
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:parameters success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        //Call back
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetAreaLocationListWithShopId:(NSNumber *)shopId
                                             areaId:(NSNumber *)areaId
                                isEnableRetailStore:(BOOL)isEnableRetailStore
                                         startIndex:(NSInteger)startIndex
                                           maxCount:(NSInteger)maxCount
                                  completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoJSONList, NSError *error))completionHandler {
    NSString *path = @"LocationV2/GetLocationListByArea";
    
    //Parameter
    NSString *isEnableRetailStoreStr = isEnableRetailStore ? @"true" : @"false";
    NSDictionary *parameters = @{@"shopId"      : shopId,
                                 @"areaId"      : areaId,
                                 @"IsEnableRetailStore" : isEnableRetailStoreStr,
                                 @"startIndex"  : @(startIndex),
                                 @"maxCount"    : @(maxCount)};
    
    //GET
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *list = JSON[kNYAPIDataKey][@"List"];
        
        //Call back
        completionHandler(returnCode, message, list, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetLocationStoreWithStoreId:(NSNumber *)storeId
                                completionHandler:(void (^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError *error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationV2/GetLocationDetail";
    
    //Parameter
    NSMutableDictionary * parameters = [NSMutableDictionary dictionary];
    [parameters setValue:storeId forKey:@"locationId"];
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        if ([data isKindOfClass:[NSDictionary class]]) {
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(returnCode, message, nil, nil);
        }
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetLocationListWithShopId:(NSNumber *)shopId
                                   userLocation:(CLLocation *)userLocation
                            isEnableRetailStore:(BOOL)isEnableRetailStore
                              completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoJSONList, BOOL isSorted, NSInteger totalCount, NSError *error))completionHandler {
    NSString *path = @"LocationV2/GetLocationList";
    
    //Parameter
    NSMutableDictionary * parameters = [NSMutableDictionary dictionary];
    [parameters setValue:shopId forKey:@"shopId"];
    
    //如果有傳經緯度才帶給Server
    if (userLocation) {
        [parameters setValue:@(userLocation.coordinate.latitude) forKey:@"lat"];
        [parameters setValue:@(userLocation.coordinate.longitude) forKey:@"lon"];
    }
    //如果有填才帶給Server
    if (isEnableRetailStore) {
        NSString *isEnableRetailStoreStr = isEnableRetailStore ? @"true" : @"false";
        [parameters setValue:isEnableRetailStoreStr forKey:@"isEnableRetailStore"];
    }
    
    //GET
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        // API format check.
        // If API format is incorrect, try add a empty result instead APP crash
        // see https://bts.nine-yi/edit_bug.aspx?id=14392 for more detail
        id data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]){
            NSArray *list = data[@"List"];
            NSNumber *isSorted = data[@"StoreSort"];
            NSNumber *totalCount = JSON[kNYAPIDataKey][@"LocationCount"];
            completionHandler(returnCode, message, list, [isSorted boolValue], totalCount.integerValue, nil);
        }else{
            completionHandler(returnCode, message, [NSArray array], NO, 0, nil);
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, NO, 0, error);
    }];
}

- (void)locationModuleGetLocationListWithShopId:(NSNumber *)shopId
                                      searchKey:(NSString *)searchKey
                                     startIndex:(NSInteger)startIndex
                                       maxCount:(NSInteger)maxCount
                            isEnableRetailStore:(BOOL)isEnableRetailStore
                              completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoJSONList, BOOL isSorted, NSInteger totalCount, NSError *error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationV2/QueryLocationList";
    
    //Parameter
    NSMutableDictionary * parameters = [NSMutableDictionary dictionary];
    [parameters setValue:shopId forKey:@"shopId"];
    [parameters setValue:searchKey forKey:@"searchKey"];
    [parameters setValue:@(startIndex) forKey:@"startIndex"];
    [parameters setValue:@(maxCount) forKey:@"maxCount"];
    
    //如果有填才帶給Server
    if (isEnableRetailStore) {
        NSString *isEnableRetailStoreStr = isEnableRetailStore ? @"true" : @"false";
        [parameters setValue:isEnableRetailStoreStr forKey:@"isEnableRetailStore"];
    }
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        // API format check.
        // If API format is incorrect, try add a empty result instead APP crash
        // see https://bts.nine-yi/edit_bug.aspx?id=14392 for more detail
        id data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]){
            NSArray *list = data[@"LocationList"];
            NSNumber *isSorted = data[@"StoreSort"];
            NSNumber *totalCount = JSON[kNYAPIDataKey][@"LocationCount"];
            completionHandler(returnCode, message, list, [isSorted boolValue], totalCount.integerValue, nil);
        }else{
            completionHandler(returnCode, message, [NSArray array], NO, 0, nil);
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, NO, 0, error);
    }];
}

- (void)locationModuleGetCityLocationListWithShopId:(NSNumber *)shopId
                                             cityId:(NSNumber *)cityId
                                         startIndex:(NSInteger)startIndex
                                           maxCount:(NSInteger)maxCount
                                  completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoJSONList, NSError *error))completionHandler {
    NSString *path = @"LocationV2/GetLocationListByCity";
    
    //Parameter
    NSDictionary *parameters = @{@"shopId"      : shopId,
                                 @"cityId"      : cityId,
                                 @"startIndex"  : @(startIndex),
                                 @"maxCount"    : @(maxCount)};
    
    //GET
    NYCDNHTTPClient *client = [NYCDNHTTPClient sharedClient];
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *list = JSON[kNYAPIDataKey][@"List"];
        
        //Call back
        completionHandler(returnCode, message, list, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetOverseaLocationListWithShopId:(NSNumber *)shopId
                                            startIndex:(NSInteger)startIndex
                                              maxCount:(NSInteger)maxCount
                                     completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoJSONList, NSError *error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationV2/GetOverseaLocationList";
    
    //Parameter
    NSDictionary *parameters = @{@"shopId"      : shopId,
                                 @"startIndex"  : @(startIndex),
                                 @"maxCount"    : @(maxCount)};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *list = JSON[kNYAPIDataKey][@"List"];
        
        //Call back
        completionHandler(returnCode, message, list, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 2.52 LocationAvailable (門市購)

- (void)locationModuleCheckAndArrangeAvailableLocationWithAddress:(NSString *)address
                                                       locationId:(NSNumber *)locationId
                                                 memberLocationId:(NSNumber *)memberLocationId
                                                completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error))completionHandler {
    [self locationModuleGetAvailableLocationListWithAddress:address
                                                 locationId:locationId
                                            isCheckDistance:YES
                                           memberLocationId:memberLocationId
                                          completionHandler:^(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error) {
        if (completionHandler) {
            completionHandler(returnCode, responseMessage, storeInfoDict, error);
        }
    }];
}

- (void)locationModuleArrangeAvailableLocationWithLocationId:(NSNumber *)locationId
                                           completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error))completionHandler {
    [self locationModuleGetAvailableLocationListWithAddress:nil
                                                 locationId:locationId
                                            isCheckDistance:NO
                                           memberLocationId:nil
                                          completionHandler:^(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error) {
        if (completionHandler) {
            completionHandler(returnCode, responseMessage, storeInfoDict, error);
        }
    }];
}

- (void)locationModuleArrangeLocationWithLocationId:(NSNumber *)locationId
                                  completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error))completionHandler {
    [self locationModuleGetAvailableLocationListWithAddress:nil
                                                 locationId:locationId
                                            isCheckDistance:NO
                                           memberLocationId:nil
                                          completionHandler:^(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error) {
        if (completionHandler) {
            completionHandler(returnCode, responseMessage, storeInfoDict, error);
        }
    }];
}

- (void)locationModuleGetAvailableLocationListWithAddress:(NSString *)address
                                               locationId:(NSNumber *)locationId
                                          isCheckDistance:(BOOL)isCheckDistance
                                         memberLocationId:(NSNumber *)memberLocationId
                                        completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *storeInfoDict, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"ShopId"];
    // 告訴 server 是否要打 Google API 來計算距離（因為要錢），目前只有門市外送會是 true，門市自取、選擇服務門市都是 false
    [parameters setValue:isCheckDistance ? @"true" : @"false" forKey:@"IsCheckDistance"];
    if (locationId) {
        [parameters setValue:locationId forKey:@"CurrentLocation"];
    }
    if (address) {
        [parameters setValue:address forKey:@"Address"];
    }
    if (memberLocationId) {
        // 告訴 server 常用收件人資料，購物車顯示要用
        [parameters setValue:memberLocationId forKey:@"MemberLocationId"];
    }
    
    [[NYHTTPSClient sharedClient]
     postPath: @"LocationV2/ArrangeAvailableLocation"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetMemberLocationListWithIsRetailStoreUse:(BOOL)isRetailStoreUse
                                              completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoList, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];

    if (isRetailStoreUse) {
        NSString *isRetailStoreUseStr = isRetailStoreUse ? @"true" : @"false";
        [parameters setValue:isRetailStoreUseStr forKey:@"isRetailStoreUse"];
    }

    [[NYHTTPSClient sharedClient]
     getPath: @"MemberLocationV2/GetMemberLocationList"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(returnCode, message, data, nil);
        } else {
            // 未登入時 data 為空，當 failure 處理
            completionHandler(nil, nil, nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

// 小時達外送「商品缺貨查看鄰近庫存」API，取得「該商品附近門市庫存資料列表」 [VSTS 203998]
- (void)getRetailStoreDeliveryStockInfoListWithSalePageId:(NSNumber *)salePageId
                                    completionHandler:(void (^)(NSString *returnCode, NSDictionary *storeInfo, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];
    [parameters setValue:salePageId forKey:@"SalePageId"];

    [[NYHTTPSClient sharedClient]
     getPath: @"RetailStore/GetHasStockLocationInfo"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(returnCode, data, nil);
        } else {
            // 無資料時也當 failure 處理
            completionHandler(nil, nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

// 小時達外送「輸入地址頁切換門市」選店 API，取得「三公里內可供切換的門市列表」 [VSTS 203763]
- (void)getRetailStoreDeliveryAvailableStoreListWithAddress:(NSString *)address
                                          completionHandler:(void (^)(NSArray *storeInfoList, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:address forKey:@"Address"];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];

    [[NYHTTPSClient sharedClient]
     getPath: @"RetailStore/GetArrangeableLocation"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSArray *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(data, nil);
        } else {
            // 無資料時也當 failure 處理
            completionHandler(nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

// 小時達選店 API，加入總店（預設店）維度 [VSTS 199714]
- (void)hadSelectedRetailStoreServiceWithCompletionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *retailStoreInfo, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];

    [[NYHTTPSClient sharedClient]
     getPath: @"RetailStore/HadSelectedService"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(returnCode, message, data, nil);
        } else {
            // 無資料時也當 failure 處理
            completionHandler(nil, nil, nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)removeMemberLocationWithMemberLocationId:(NSNumber *)memberLocationId
                               completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeInfoList, NSError *error))completionHandler {
    // Parameter
    NSString *lang = [NYLocalizationString selectedLanguageCode].length > 0 ? [NYLocalizationString selectedLanguageCode] : @"en-US";
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];
    [parameters setValue:lang forKey:@"lang"];
    [parameters setValue:memberLocationId forKey:@"MemberLocationId"];

    [[NYHTTPSClient sharedClient]
     postPath: @"MemberLocationV2/RemoveMemberLocation"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(returnCode, message, data, nil);
        } else {
            // 未登入時 data 為空，當 failure 處理
            completionHandler(nil, nil, nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)locationModuleGetNearByLocationListWithAddress:(NSString *)address
                                              location:(CLLocation *)location
                                  isEnabledRetailStore:(BOOL)isEnabledRetailStore
                                             takeCount:(NSNumber *)takeCount
                                     completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *storeList, NSError *error))completionHandler {
    // Parameter
    NSMutableDictionary *parameters = [NSMutableDictionary new];
    [parameters setValue:[NYGlobalData shopId] forKey:@"shopId"];

    if (address) {
        [parameters setValue:address forKey:@"Address"];
    }
    
    if (location) {
        NSNumber *latitude = [NSNumber numberWithDouble:location.coordinate.latitude];
        NSNumber *longitude = [NSNumber numberWithDouble:location.coordinate.longitude];
        [parameters setValue:latitude forKey:@"Latitude"];
        [parameters setValue:longitude forKey:@"Longitude"];
    }
    
    if (isEnabledRetailStore) {
        NSString *isEnabledRetailStoreStr = isEnabledRetailStore ? @"true" : @"false";
        [parameters setValue:isEnabledRetailStoreStr forKey:@"IsEnabledRetailStore"];
    }
    
    NSNumber *count = @5;
    if (takeCount) {
        count = takeCount;
    }
    [parameters setValue:count forKey:@"TakeCount"];

    [[NYHTTPSClient sharedClient]
     postPath: @"LocationV2/GetNearbyLocations"
     parameters: parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSArray *data = JSON[kNYAPIDataKey];
        if (data) {
            completionHandler(returnCode, message, data, nil);
        } else {
            // 無資料時也當 failure 處理
            completionHandler(nil, nil, nil, [NSError new]);
        }
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getActiveOrdersWithShopId:(NSNumber * _Nullable)shopId
                completionHandler:(void (^ _Nullable)(NSString * _Nullable returnCode, NSString * _Nullable responseMessage, NSDictionary * _Nullable activeOrderJSON, NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"MemberTradesOrder/GetActiveOrders";

    //Parameter
    NSDictionary *parameters = @{@"ShopId"  : shopId};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        NSDictionary *activeOrderJSON = @{};
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            activeOrderJSON = data;
        }
        completionHandler(returnCode, message, activeOrderJSON, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 2.8X 門市庫存查詢
/// 取得門市庫存資料 By City
- (void)fetchStockInStoresByCity:(NSNumber *)cityID
                           skuID:(NSNumber *)skuID
               completionHandler:(void (^)(NSString * _Nullable returnCode,
                                           NSDictionary * _Nullable data,
                                           NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"gateway/stock/getStockInStoresByCity";
    NSDictionary *parameters = @{
        @"cityId": cityID,
        @"skuId": skuID
    };
    
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        completionHandler(returnCode, data, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

/// 取得門市庫存資料 By Area
- (void)fetchStockInStoresByArea:(NSNumber *)areaID
                           skuID:(NSNumber *)skuID
               completionHandler:(void (^)(NSString * _Nullable returnCode,
                                           NSDictionary * _Nullable data,
                                           NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"gateway/stock/getStockInStoresByArea";
    NSDictionary *parameters = @{
        @"areaId": areaID,
        @"skuId": skuID
    };
    
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        completionHandler(returnCode, data, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

/// 取得海外門市庫存資料
- (void)fetchStockInOverseaStoress:(NSNumber *)skuID
                 completionHandler:(void (^)(NSString * _Nullable returnCode,
                                             NSDictionary * _Nullable data,
                                             NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"gateway/stock/getStockInOverseaStores";
    NSDictionary *parameters = @{
        @"skuId": skuID,
    };
    
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];

        completionHandler(returnCode, data, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

/// 取得門市庫存說明文案
- (void)fetchStockInStoresDescriptionWithCompletionHandler:(void (^ _Nullable)(NSString * _Nullable returnCode, NSDictionary * _Nullable data, NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"gateway/stock/getStockInStoresDescription";
    NSDictionary *parameters = @{
        @"ShopId": self.shopId,
    };
    
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];

        completionHandler(returnCode, data, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark - 2.60 目前購物車金額提示（僅限全聯環境）

- (void)getCurrentShoppingCartAmountWithServiceTypeString:(NSString *)serviceTypeString
                                        completionHandler:(void (^)(NSString * _Nullable,
                                                                    NSDictionary * _Nullable,
                                                                    NSError * _Nullable))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"ShoppingCartV4/GetShoppingCartAmountPreview";
    NSDictionary *parameters = @{
        @"ShopId" : self.shopId,
        @"ServiceType" : serviceTypeString
    };
    
    // Get
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *amountJSON = @{};
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            amountJSON = data;
        }
        completionHandler(returnCode, amountJSON, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark - 2.73 購物車數量（僅限全聯環境）

- (void)getCurrentShoppingCartAllQtyWithCompletionHandler:(void (^)(NSString * _Nullable returnCode,
                                                                    NSArray * _Nullable allQtyData,
                                                                    NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = [NSString stringWithFormat:@"ShoppingCartQty/GetAllQty/%@", self.shopId];
    NSDictionary *parameters = @{
        @"shopId" : self.shopId
    };
    
    // Get
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSArray *allQtyJSON = @[];
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]] && data[@"AllQty"]) {
            allQtyJSON = data[@"AllQty"];
        }
        completionHandler(returnCode, allQtyJSON, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark - 2.75 PXPay 是否有升級全支付會員（僅限全聯環境）

- (void)getPXPayHasPXPayPlusMemberWithCompletionHandler:(void (^)(NSString * _Nullable returnCode,
                                                                  NSDictionary * _Nullable data,
                                                                  NSError * _Nullable error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = [NSString stringWithFormat:@"ThirdPartyPay/GetMemberIsUpgradeToPXPayPlus"];
    NSDictionary *parameters = @{
        @"shopId" : self.shopId
    };
    
    // Get
    [client getPath:path
         parameters:parameters
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *dataJSON = @{};
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            dataJSON = data;
        }
        completionHandler(returnCode, dataJSON, nil);
    }
            failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark - 2.71.10 全聯快速通關

- (void)getLastOrderWithServiceTypeString:(NSString *)serviceTypeString
                               completion:(void (^)(NSString * _Nullable,
                                                    NSDictionary * _Nullable,
                                                    NSError * _Nullable))completion {
    NSDictionary *parameters = @{
        @"ShopId" : self.shopId,
        @"ServiceType" : serviceTypeString
    };
    
    // 有 Cache，但不能過 CDN
    // Get
    [[NYHTTPSClient sharedClient]
     getPath:@"Rapidcheckout/GetLastOrder"
     parameters:parameters
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];
        completion(returnCode, data, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

- (void)getShoppingDataWithServiceType:(NSString *)serviceTypeString
                            completion:(void (^)(NSDictionary *cartJSONDict,
                                                 NSString *jsonString,
                                                 NSString *returnCode,
                                                 NSString *message,
                                                 NSError *error))completion {
    NSDictionary *parameters = @{
        @"shopId" : self.shopId,
        @"source" : @"iOSApp",
        @"device" : @"Mobile",
        @"channel" : @"RapidCheckout",
        @"appVer" : [NYGlobalData appVersionString],
        @"serviceType" : serviceTypeString,
        @"eCouponVersion" : eCouponSupportVersion,
        @"PromoCodePoolGroupId": [NYUserDefault promoCodePoolGroupID] ? : @"",
        @"PromoCode":[NYUserDefault promoCode] ? : @""
    };
    
    // Get
    [[NYCartHTTPSClient sharedClient]
     getPath:@"RapidCheckout/GetShoppingData"
     parameters:parameters
     success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *cartJSONDict = response[kNYAPIDataKey];
        NSString *jsonString = [self jsonStringWithData:cartJSONDict];
        completion(cartJSONDict, jsonString, returnCode, message, nil);
        
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completion(nil, nil, nil, nil, error);
    }];
}

- (void)sendShoppingDataWithJSONString:(NSString *)jsonString
                            completion:(void (^)(NSDictionary *data,
                                                 NSString *returnCode,
                                                 NSString *message,
                                                 NSError *error))completion {
    NSDictionary *parameters = @{
        @"Context" : jsonString
    };
    
    // Post
    [[NYCartHTTPSClient sharedClient]
     postPath:@"RapidCheckout/Send"
     parameters:parameters
     success:^(NSURLSessionTask *operation, NSDictionary *response) {
        NSString *returnCode = response[kNYAPIReturnCodeKey];
        NSString *message = response[kNYAPIMessage];
        NSDictionary *data = response[kNYAPIDataKey];
        
        completion(data, returnCode, message, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completion(nil, nil, nil, error);
    }];
}

/// 用 API "RapidCheckout/GetShoppingData" Response 整包 Data 轉成的 JSON 字串，要當作 確認付款 API "RapidCheckout/Send" 的 Parameter
- (NSString *)jsonStringWithData:(NSDictionary *)data {
    if ([NSJSONSerialization isValidJSONObject:data]) {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingWithoutEscapingSlashes error:nil];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return jsonString;
    }
    return @"";
}

#pragma mark - 2.6 LocationPoint (門市積點活動)

- (void)locationPointGetEventListWithShopId:(NSNumber *)shopId
                          completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSArray *eventInfoJSON, NSError * error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationRewardPoint/GetRewardPointList";

    //Parameter
    NSDictionary *parameters = @{@"ShopId"  : shopId};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        //此API, Data在API0002時會是null
        NSArray *list = @[];
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            list = data[@"RewardPointList"];
        }
        
        //Call back
        completionHandler(returnCode, message, list, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}


- (void)locationPointGetEventDetailWithEventId:(NSNumber *)eventId
                             completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSDictionary *eventInfoDictionary, NSError * error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationRewardPoint/GetRewardPointDetail";
    
    //Parameter
    NSDictionary *parameters = @{@"RewardPointId"   : eventId};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        //此API, Data在API0002時會是null
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSNull class]]) {
            data = @{};
        }
        
        //Call back
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}


- (void)locationPointGetUserCurrentPointWithEventId:(NSNumber *)eventId
                                  completionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSNumber *userCurrentPoint, NSError * error))completionHandler {
    NYHTTPSClient *client = [NYHTTPSClient sharedClient];
    NSString *path = @"LocationRewardPoint/GetMemberRewardPoint";
    
    //Parameter
    NSDictionary *parameters = @{@"RewardPointId"   : eventId};
    
    //GET
    [client getPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        
        //此API, Data在API0002時會是null
        NSNumber *currentPoint = @(0);
        NSDictionary *data = JSON[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            currentPoint = data[@"MemberRewardPoint"];
        }
        
        //Call back
        completionHandler(returnCode, message, currentPoint, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 2.6 FreeGift (滿額贈)

- (void)freeGiftGetSalePageGiftDetailWithGiftId:(NSNumber *)giftId
                              completionHandler:(void (^)(NSDictionary *giftInfomation, NSError *error))completionHandler {
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"SalePage/GetIsGiftSalePage/%@", giftId]
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id responseObject) {
         //Success
         NSDictionary *giftInfo = responseObject[kNYAPIDataKey];
         
         //Call back
         completionHandler(giftInfo, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         //Fail
         completionHandler(nil, error);
     }];
}

#pragma mark - 2.30 GetShopStaticSetting (來自API的APP設定)

- (void)getShopStaticSettingWithCompletionHandler:(void (^)(NSDictionary *responseObject, NSError *error))completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"ShopStaticSetting/GetShopStaticSetting"
                                parameters:@{@"shopId" : _shopId,
                                             @"appVer" : [NYGlobalData appVersionString],
                                             @"source" : @"iOSApp",
                                             @"device" : @"Mobile"}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
                                       completionHandler(responseObject, nil);
                                   }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                       completionHandler(nil, error);
                                   }];
}

#pragma mark 2.45.0 打 API 取得指定的 group name & key 的設定

- (void)getShopStaticSettingWithGroupName:(NSString *)groupName
                                      key:(NSString *)key
                               completion:(void (^)(NSString *returnCode, NSDictionary *data, NSError *error))completion {
    [[NYCDNHTTPClient sharedClient]
     getPath:@"ShopStaticSetting/GetShopStaticSettingByGroupNameKey"
     parameters:@{@"shopId" : _shopId,
                  @"groupName" : groupName,
                  @"key" : key}
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[@"ReturnCode"];
        NSDictionary *data = responseObject[@"Data"];
        completion(returnCode, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

#pragma mark - 2.43.0 GetShopPayShippingTypeDisplaySettingList

- (void)getShopPayShippingTypeDisplaySettingListWithShopId:(NSNumber *)shopId
                                         completionHandler:(void (^)(NSString *retrunCode, NSDictionary *displaySettingJSONListDict))completionHandler {
    
    NYHTTPSClient *client = [NYCDNHTTPClient sharedClient];
    NSString *path = [NSString stringWithFormat: @"Shop/GetShopPayShippingTypeDisplaySettingList/%@", shopId];
    
    //GET
    [client getPath:path parameters:nil requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        //Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *shippingDetailJSONList = JSON[kNYAPIDataKey];
        
        //Call back
        completionHandler(returnCode, shippingDetailJSONList);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail
        completionHandler(nil, nil);
    }];
}

#pragma mark - 2.78.0 GetPayTypeChannelList
- (void)getPayTypeChannelListWithShopId:(NSNumber *)shopId
                      completionHandler:(void (^)(NSString *retrunCode, NSDictionary *payTypeChannelJSONListDict))completionHandler {
    NYHTTPSClient *client = [NYCDNHTTPClient sharedClient];
    NSString *path = [NSString stringWithFormat: @"Shop/GetPayTypeChannelList/%@", shopId];
    
    // GET
    [client getPath:path
         parameters:nil
        requestType:NYHTTPRequestTypeJSON
       responseType:NYHTTPResponseTypeJSON
            success:^(NSURLSessionDataTask *operation, id JSON) {
        // Success
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *payTypeChannelJSONListDict = JSON[kNYAPIDataKey];
        
        // Callback
        completionHandler(returnCode, payTypeChannelJSONListDict);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        // Fail
        completionHandler(nil, nil);
    }];
}

#pragma mark - 2.43 91 Track V2

- (void)sendNineYiTrackV2CollectWithParameters:(NSDictionary *)para {
    [self sendNineYiTrackCollectWithParameters:para path:@"v2/collect"];
}

- (void)sendNineYiTrackCollectWithParameters:(NSDictionary *)para path:(NSString *)path {
    //Get (Note:這行為看起來要用POST, 不過是要用GET)
    [[NYTrackingClient sharedClient] getPath:path parameters:para requestType:NYHTTPRequestTypeHTTP responseType:NYHTTPResponseTypeHTTP success:^(NSURLSessionDataTask *operation, id responseObj) {
        //Success (Do nothing)
        //成功會回一個1x1 px的圖片 (據說仿GA)
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        //Fail (Do nothing)
    }];
}

- (void)keepAlive {
    // 有開啟 session management 才打 KeepAlive
    if (![NYUserDefault isSessionManagementEnabled]) {
        return;
    }

    NSTimeInterval lastUpdate = self.lastUpdate;
    NSDate *now = [NSDate date];
    NYDateDifference diff = [now dateDifferenceWithTimeInterval:lastUpdate];
    
    NSInteger debounceTimeMinutes = [NYUserDefaultV2 keepAliveDebounceMinutes];
    if (diff.days > 0 || diff.hours > 0 || diff.minutes >= debounceTimeMinutes) {
        self.lastUpdate = [now timeIntervalSince1970];
        NSDictionary *param = @{@"shopId" : [NYGlobalData shopId],
                                @"lang" : @"zh-TW"};
        [[NYHTTPSClient sharedClient]
         getPath:@"AuthV4/KeepAlive"
         parameters:param
         success:nil
         failure:nil];
    }
}

#pragma mark - CMS 再買一次模組

- (void)getBuyAgainModuleProductsWithListDisplayCount:(NSNumber *)listDisplayCount
                                           completion:(void (^)(NSString *returnCode,
                                                                NSArray *data,
                                                                NSError *error))completion {
    NSString *path = @"MemberPurchasedSummary/GetLatestPurchasedList";
    NSDictionary *params = @{@"shopID" : self.shopId,
                             @"listDisplayCount" : listDisplayCount};
    
    [[NYHTTPSClient sharedClient]
     getPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSArray *productJSONs = responseObject[kNYAPIDataKey];
        completion(returnCode, productJSONs, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

#pragma mark - Payments
- (void)fetchMultipassTokenWithCompletion:(void (^ _Nonnull)(NSString * _Nullable returnCode,
                                                             NSString * _Nullable data,
                                                             NSString * _Nullable message,
                                                             NSError * _Nullable error))completion {
    NSString *path = @"/authv4/getMultipassToken";
    NSString *guid = [[NYCookieManager sharedManager] cookieValueFromLocal:kCOOKIE_NAME_GUID];
    NSDictionary *params = @{@"ShopId": _shopId,
                             @"DeviceType": @"iOSApp",
                             @"DeviceGuid": guid};
    
    // POST
    [[NYHTTPSClient sharedClient] postPath:path
                                parameters:params
                                   success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *data = JSON[kNYAPIDataKey];
        NSString *message = JSON[kNYAPIMessage];
        completion(returnCode, data, message, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, nil, error);
    }];
}

#pragma mark - 商品掃描

//寶雅掃描
- (void)getProductSKUInfoWithBarcode:(NSString *)barcode
                   completionHandler:(void (^)(NSString * _Nullable returnCode,
                                               NSString * _Nullable responseMessage,
                                               NSDictionary * _Nullable data,
                                               NSError * _Nullable error))completion {
    NSString *path = [NSString stringWithFormat:@"/gateway/scan/%@/productskuinfo", self.shopId.stringValue];
    NSDictionary *params = @{@"barcode": barcode,};
    
    [[NYHTTPSClient sharedClient]
     getPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        NSDictionary *productJSONs = responseObject[kNYAPIDataKey];
        
        completion(returnCode, message, productJSONs, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, nil, error);
    }];
}

//產品化掃描 (非寶雅）24.6 目前只有 HK 單店使用
- (void)getProductSKUInfoWithQRcode:(NSString *)qrcode
                   completionHandler:(void (^)(NSString * _Nullable returnCode,
                                               NSString * _Nullable responseMessage,
                                               NSDictionary * _Nullable data,
                                               NSError * _Nullable error))completion {
    NSString *path = [NSString stringWithFormat:@"/gateway/scan/%@/channelskuinfo", self.shopId.stringValue];
    NSDictionary *params = @{@"barcode": qrcode};
    [[NYHTTPSClient sharedClient]
     getPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, id responseObject) {

        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        NSDictionary *productJSONs = responseObject[kNYAPIDataKey];
        
        completion(returnCode, message, productJSONs, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, nil, error);
    }];
}


#pragma mark - 23.8 LINE 購物支援 App 訂單
- (void)setFRRelatedInfo:(NSString *)frCode
                 fr2Code:(NSString *)fr2Code
       completionHandler:(void (^)(NSString * _Nullable returnCode, NSError * _Nullable error))completion {
    NSString *path = @"FR/Set";
    NSDictionary *params = @{@"ShopId": self.shopId.stringValue,
                             @"Fr": frCode,
                             @"Fr2": fr2Code};
    
    // POST
    [[NYHTTPSClient sharedClient] postPath:path
                                parameters:params
                                   success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        completion(returnCode, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}

#pragma mark - 24.1 HTML 內容多語系
- (void)getHTMLMultilingualContentBy:(NSString *)urlString
                   completionHandler:(void (^)(NSString * _Nullable htmlContent,
                                               NSError * _Nullable error))completion {
    if (!urlString || urlString.length <= 0) {
        completion(nil, [NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL. URL is nil"}]);
        return;
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlString]
                                                             completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            completion(result, error);
        });
    }];
    
    [task resume];
}

#pragma mark - 24.5 個人化推薦
/// 供 CMS 後台、前台、App 判斷該店是否啟用 jooii 個人化推薦商品服務狀態開關（來源：BAPI 開關狀態）
- (void)getJooiiRecommendationSetting:(void (^)(NSDictionary * _Nullable data, NSError * _Nullable error))completion {
    NSString *shopId = [[NYGlobalData shopId] stringValue];
    NSString *path = [NSString stringWithFormat:@"salepage-listing/api/recommendation/setting-get/%@/jooii", shopId];
    
    [[NYFTSHTTPClient sharedClient] getPath:path
                                 parameters:@{}
                                    success:^(NSURLSessionDataTask *operation, id responseObject) {
        completion(responseObject, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}

#pragma mark - 24.12 商品特色標語
- (void)getMetaFieldTemplates:(void (^)(NSDictionary * _Nullable data, NSError * _Nullable error))completion {
    NSString *shopId = [[NYGlobalData shopId] stringValue];
    NSString *path = [NSString stringWithFormat:@"salepage-listing/api/template/%@", shopId];
    
    [[NYFTSHTTPClient sharedClient] getPath:path
                                 parameters:@{}
                                    success:^(NSURLSessionDataTask *operation, id responseObject) {
        completion(responseObject, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}
@end
//
//  NYDataProvider+Login.m
//  Pods
//
//  Created by Eric Huang on 2019/11/28.
//

#import "NYDataProvider+Login.h"
#import "NYHTTPSClient.h"
#import "NYCDNHTTPClient.h"
#import <NYCore/NYCore-Swift.h>
#import "NYDataProvider+Logging.h"

#import <AdSupport/AdSupport.h>

@implementation NYDataProvider (Login)

- (void)getShopThirdpartyAuthInfoWithShopId:(NSNumber *)shopId
                                     device:(NSString *)device
                          completionHandler:(DataSourceCompletionHandler)completionHandler {
    //為減少server loading、商城勿call
    if (shopId.integerValue == 0 || device.length == 0) {
        completionHandler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    // 舊官網帳號登入轉導到店家自己的登入頁面，需讓店家判斷第三方登入是否開啟（目前只有小三美日使用)
    // 新增參數 thirdLoginEnable 給 Server ， Server 會篩選適用的店家（若需隱藏第三方登入 thirdLoginEnable = false：回傳的網址會多帶上 &3rdlogin_btn=disable）
    BOOL thirdLoginEnable = false;
    
    [[NYHTTPSClient sharedClient]
     postPath:@"AuthV3/GetShopThirdpartyAuthInfo"
     parameters:@{@"shopId": shopId,
                  @"device": device,
                  @"thirdLoginEnable": (thirdLoginEnable)? @"true" : @"false"}
     success:^(NSURLSessionDataTask * _Nonnull operation, id _Nonnull responseObject) {
        completionHandler(@{kDATA_KEY:responseObject}, nil);
    } failure:^(NSURLSessionDataTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler(nil, error);
    }];
}

- (void)getThirdpartyMemberRegisterStatusWithTokenWithAccessToken:(NSString *)accessToken
                                                           ShopId:(NSNumber *)shopId
                                                completionHandler:(DataSourceCompletionHandler)completionHandler {
    //為減少server loading、商城勿call
    if (shopId.integerValue == 0) {
        completionHandler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    NSDictionary *parameter = @{@"accessToken"  : (accessToken) ?: @"",
                                @"shopId"       : shopId,
                                @"source"       : @"iOSApp",
                                @"device"       : @"Mobile",
                                @"appVer"       : [NYGlobalData appVersionString]};

    [[NYHTTPSClient sharedClient]
     postPath:@"AuthV3/GetThirdpartyMemberRegisterStatusWithToken"
     parameters:parameter
     success:^(NSURLSessionDataTask * _Nonnull operation, id _Nonnull responseObject) {
        completionHandler(@{kDATA_KEY:responseObject}, nil);
    } failure:^(NSURLSessionDataTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler(nil, error);
    }];
}

#pragma mark 手機註冊

- (void)checkIsValidWithCellPhone:(NSString *)cellPhone
                 countryAliasCode:(NSString *)countryAliasCode
                completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"cellPhone": cellPhone,
                                 @"aliasCode": [countryAliasCode uppercaseString]};

    //POST
    [[NYHTTPSClient sharedClient] postPath:@"AuthV4/IsValidNumber" parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            completionHandler(@{kDATA_KEY:JSON}, nil);
        } else {
            completionHandler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

- (void)getRegisterStatusWithShopID:(NSNumber *)shopID
                          cellPhone:(NSString *)cellPhone
                     reCaptchaToken:(NSString *)reCaptchaToken
                        countryCode:(NSString *)countryCode
                          countryID:(NSNumber *)countryID
                  completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId" : shopID,
                                 @"cellPhone" : cellPhone,
                                 @"reCaptchaToken" : reCaptchaToken,
                                 @"source":@"iOSApp",
                                 @"device":@"Mobile",
                                 @"countryCode" : countryCode,
                                 @"countryProfileId" : countryID
                                 };

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/GetNineYiMemberRegisterStatus" parameters:parameters completionHandler:completionHandler];
}

- (void)cellPhoneRegisterWithShopID:(NSNumber *)shopID
                          cellPhone:(NSString *)cellPhone
                     reCaptchaToken:(NSString *)reCaptchaToken
                        countryCode:(NSString *)countryCode
                          countryID:(NSNumber *)countryID
                  completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"          : shopID,
                                 @"cellPhone"       : cellPhone,
                                 @"reCaptchaToken"  : reCaptchaToken,
                                 @"countryCode"     : countryCode,
                                 @"countryProfileId" : countryID
                                 };

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/CreateNineYiMemberRegisterRequest" parameters:parameters completionHandler:completionHandler];
}

- (void)sendVerifyCodeWithShopID:(NSNumber *)shopID
                       cellPhone:(NSString *)cellPhone
                  reCaptchaToken:(NSString *)reCaptchaToken
                     countryCode:(NSString *)countryCode
                       countryID:(NSNumber *)countryID
                         smsType:(NSString *)smsType
               completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"          : shopID,
                                 @"cellPhone"       : cellPhone,
                                 @"reCaptchaToken"  : reCaptchaToken,
                                 @"countryCode"     : countryCode,
                                 @"countryProfileId": countryID,
                                 @"smsType"         : smsType
    };
    
    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV4/SendVerifyCode" parameters:parameters completionHandler:completionHandler];
}

- (void)resendVerifyCodeWithShopID:(NSNumber *)shopID
                         cellPhone:(NSString *)cellPhone
                        memberType:(NSString *)memberType
                        verifyType:(NSString *)verifyType
                           smsType:(NSString *)smsType
                    reCaptchaToken:(NSString *)reCaptchaToken
                       countryCode:(NSString *)countryCode
                         countryID:(NSNumber *)countryID
                 completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"memberType"       : memberType,
                                 @"verifyType"       : verifyType,
                                 @"reCaptchaToken"   : reCaptchaToken,
                                 @"source"           : @"iOSApp",
                                 @"device"           : @"Mobile",
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID,
                                 @"smsType"          : smsType
                                 };

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/ResendVerifyCode" parameters:parameters completionHandler:completionHandler];
}

- (void)resendVerifyCodeUseVoiceWithShopID:(NSNumber *)shopID
                         cellPhone:(NSString *)cellPhone
                        memberType:(NSString *)memberType
                        verifyType:(NSString *)verifyType
                  countryPhoneCode:(NSString *)countryPhoneCode
                         countryID:(NSNumber *)countryID
                 completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"memberType"       : memberType,
                                 @"verifyType"       : verifyType,
                                 @"countryCode"      : countryPhoneCode,
                                 @"countryProfileId" : countryID
                                 };

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV4/ResendVerifyCodeUseVoice" parameters:parameters completionHandler:completionHandler];
}

- (void)confirmVerifyCodeWithShopID:(NSNumber *)shopID
                          cellPhone:(NSString *)cellPhone
                               code:(NSString *)code
                         verifyType:(NSString *)verifyType
                     reCaptchaToken:(NSString *)reCaptchaToken
                        countryCode:(NSString *)countryCode
                          countryID:(NSNumber *)countryID
                  completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"code"             : code,
                                 @"verifyType"       : verifyType,
                                 @"reCaptchaToken"   : reCaptchaToken,
                                 @"source"           : @"iOSApp",
                                 @"device"           : @"Mobile",
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/ConfirmNineYiMemberVerifyCode" parameters:parameters completionHandler:completionHandler];
}

- (void)finishCellPhoneRegisterWithShopID:(NSNumber *)shopID
                                cellPhone:(NSString *)cellPhone
                                 password:(NSString *)password
                                   source:(NSString *)source
                                   device:(NSString *)device
                               appVersion:(NSString *)appVersion
                              countryCode:(NSString *)countryCode
                                countryID:(NSNumber *)countryID
                         enableOptInSplit:(BOOL)enableOptInSplit
                                  isOptIn:(NSNumber *)isOptIn
                              isEnableEDM:(NSNumber *)isEnableEDM
                           isEnableEdmSMS:(NSNumber *)isEnableEdmSMS
                         isAppPushProfile:(NSNumber *)isAppPushProfile
                        completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSMutableDictionary *parameters = @{@"shopId"           : shopID,
                                        @"cellPhone"        : cellPhone,
                                        @"password"         : password,
                                        @"source"           : source,
                                        @"device"           : device,
                                        @"appVer"           : appVersion,
                                        @"countryCode"      : countryCode,
                                        @"countryProfileId" : countryID}.mutableCopy;
    
    if (enableOptInSplit) {
        if (isEnableEDM && isEnableEdmSMS && isAppPushProfile) {
            parameters[@"isEnableEDM"] = isEnableEDM.boolValue ? @"true" : @"false";
            parameters[@"isEnableEdmSMS"] = isEnableEdmSMS.boolValue ? @"true" : @"false";
            parameters[@"isAppPushProfile"] = isAppPushProfile.boolValue ? @"true" : @"false";
        }
    } else {
        if (isOptIn) {
            parameters[@"isOptIn"] = isOptIn.boolValue ? @"true" : @"false";
        }
    }
    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];

    NSString *path = @"AuthV3/FinishNineYiMemberRegister";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)mergeFavoriteListAndShoppingCartWithCompletionHandler:(DataSourceCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient]
     postPath: @"Auth/MergeMemberFavorites"
     parameters:nil
     success:^(NSURLSessionDataTask *operation, id JSON) {
         [[NYDataProvider sharedInstance] getFavoriteProductListWithCompletionHandler:^(NSDictionary *data, NSError *error) {
             completionHandler(nil, nil);
         }];
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

#pragma mark 手機登入

- (void)cellPhoneLoginWithShopID:(NSNumber *)shopID
                       cellPhone:(NSString *)cellPhone
                        password:(NSString *)password
                  reCaptchaToken:(NSString *)reCaptchaToken
                          source:(NSString *)source
                          device:(NSString *)device
                      appVersion:(NSString *)appVersion
                     countryCode:(NSString *)countryCode
                       countryId:(NSNumber *)countryId
               completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"password"         : password,
                                 @"reCaptchaToken"   : reCaptchaToken,
                                 @"source"           : source,
                                 @"device"           : device,
                                 @"appVer"           : appVersion,
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryId };

    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];
    NSString *path = @"AuthV3/LoginNineYiMember";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark 取得國家清單

- (void)getCountryListWithShopID:(NSNumber *)shopID CompletionHandler:(DataSourceCompletionHandler)completionHandler {

    NSString *path = [NSString stringWithFormat:@"countryProfile/GetCountryProfileListByShopId"];
    NSDictionary *parameters = @{@"shopId" : shopID};

    [[NYCDNHTTPClient sharedClient] getPath:path
                                 parameters:parameters
                                    success:^(NSURLSessionDataTask *operation, id JSON) {
         if (JSON) {
             completionHandler(JSON, nil);
         } else {
             completionHandler(nil, NineYiErrorWithCode(0));
         }
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
         completionHandler(nil, error);
     }];
}

#pragma mark 取得密碼 regex

- (void)getPasswordRegexSettingWithShopID:(NSNumber *)shopID
                        completionHandler:(DataSourceCompletionHandler)completionHandler {
    
    NSString *path = [NSString stringWithFormat:@"MemberLogin/GetPasswordRegexSetting"];
    NSDictionary *parameters = @{@"ShopId" : shopID};
    
    [[NYHTTPSClient sharedClient] getPath:path
                               parameters:parameters
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            completionHandler(JSON, nil);
        } else {
            completionHandler(nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

#pragma mark 取得遮罩資料

- (void)getMaskedPhoneNumberWithShopID:(NSNumber *)shopID completion:(void (^)(NSString *hashedPhoneNumber))completion {
    NSString *path = [NSString stringWithFormat:@"Advertise/GetVIPMemberHashInfoForAdvertise/%@", shopID];
    [[NYHTTPSClient sharedClient] getPath:path parameters:nil success:^(NSURLSessionDataTask *operation, NSDictionary *data) {
        NSString *returnCode = data[kNYAPIReturnCodeKey];
        NSDictionary *jsonData = data[kNYAPIDataKey];
        NSString *hashedPhoneNumber = @"";
        if ([returnCode isEqualToString:APIReturnCode.api0001] && [jsonData[@"PhoneHashed"] isKindOfClass:[NSString class]]) {
            NSDictionary *jsonData = data[kNYAPIDataKey];
            hashedPhoneNumber = jsonData[@"PhoneHashed"];
        }
        completion(hashedPhoneNumber);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(@"");
    }];
}

#pragma mark Facebook註冊

- (void)getFBRegisterStatusWithShopID:(NSNumber *)shopID
                          accessToken:(NSString *)accessToken
                            authToken:(NSString *)authToken
                    completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"      : shopID,
                                 @"token"       : accessToken,
                                 @"authToken"   : authToken};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/GetFacebookMemberRegisterStatus" parameters:parameters completionHandler:completionHandler];
}

- (void)fbRegisterWithShopID:(NSNumber *)shopID
                   cellPhone:(NSString *)cellPhone
                 accessToken:(NSString *)accessToken
                   authToken:(NSString *)authToken
                 countryCode:(NSString *)countryCode
                   countryID:(NSNumber *)countryID
           completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"token"            : accessToken,
                                 @"authToken"        : authToken,
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/CreateFacebookMemberRegisterRequest" parameters:parameters completionHandler:completionHandler];
}

- (void)fbConfirmVerifyCodeWithShopID:(NSNumber *)shopID
                          accessToken:(NSString *)accessToken
                            authToken:(NSString *)authToken
                            cellPhone:(NSString *)cellPhone
                                 code:(NSString *)code
                               source:(NSString *)source
                               device:(NSString *)device
                           appVersion:(NSString *)appVersion
                          countryCode:(NSString *)countryCode
                            countryID:(NSNumber *)countryID
                     enableOptInSplit:(BOOL)enableOptInSplit
                              isOptIn:(NSNumber *)isOptIn
                          isEnableEDM:(NSNumber *)isEnableEDM
                       isEnableEdmSMS:(NSNumber *)isEnableEdmSMS
                     isAppPushProfile:(NSNumber *)isAppPushProfile
                    completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSMutableDictionary *parameters = @{@"shopId"           : shopID,
                                        @"token"            : accessToken,
                                        @"authToken"        : authToken,
                                        @"cellPhone"        : cellPhone,
                                        @"code"             : code,
                                        @"source"           : source,
                                        @"device"           : device,
                                        @"appVer"           : appVersion,
                                        @"countryCode"      : countryCode,
                                        @"countryProfileId" : countryID}.mutableCopy;

    if (enableOptInSplit) {
        if (isEnableEDM && isEnableEdmSMS && isAppPushProfile) {
            parameters[@"isEnableEDM"] = isEnableEDM.boolValue ? @"true" : @"false";
            parameters[@"isEnableEdmSMS"] = isEnableEdmSMS.boolValue ? @"true" : @"false";
            parameters[@"isAppPushProfile"] = isAppPushProfile.boolValue ? @"true" : @"false";
        }
    } else {
        if (isOptIn) {
            parameters[@"isOptIn"] = isOptIn.boolValue ? @"true" : @"false";
        }
    }
    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];

    NSString *path = @"AuthV3/ConfirmFacebookMemberVerifyCode";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark Facebook登入

- (void)fbLoginWithShopID:(NSNumber *)shopID
              accessToken:(NSString *)accessToken
                authToken:(NSString *)authToken
                   source:(NSString *)source
                   device:(NSString *)device
               appVersion:(NSString *)appVersion
        completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"      : shopID,
                                 @"token"       : accessToken,
                                 @"authToken"   : authToken,
                                 @"source"      : source,
                                 @"device"      : device,
                                 @"appVer"      : appVersion};

    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];
    NSString *path = @"AuthV3/LoginFacebookMember";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark Line Login 註冊
/// 目前有 Line 登入、Line 綁定送券會需要先取得 ChannelID
/// （需要先檢查各自的 Flag 再決定是否取得 ChannelID）
- (void)getLineLoginChannelIdWithShopId:(NSNumber *)shopId
                             completion:(void (^)(NSString *channelId))completion {
    NSDictionary *params = @{@"shopId": shopId};
    NSString *path = @"Line/GetLineOAChannelInfo";
    [[NYHTTPSClient sharedClient] getPath:path parameters:params success:^(NSURLSessionDataTask *operation, NSDictionary *data) {
        NSString *returnCode = data[kNYAPIReturnCodeKey];
        NSDictionary *jsonData = data[kNYAPIDataKey];
        NSString *lineChannelId = @"";
        if ([returnCode isEqualToString:APIReturnCode.api0001] && [jsonData[@"LoginChannelId"] isKindOfClass:[NSString class]]) {
            NSDictionary *jsonData = data[kNYAPIDataKey];
            lineChannelId = jsonData[@"LoginChannelId"];
            completion(lineChannelId);
        } else {
            completion(@"");
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(@"");
    }];
}

- (void)getLineMemberRegisterStatusWithShopId:(NSNumber *)shopId
                                  accessToken:(NSString *)accessToken
                            completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"          : shopId,
                                 @"memberIdentity"  : accessToken,
                                 @"memberType"      : @"Line"};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV4/GetMemberRegisterStatus" parameters:parameters completionHandler:completionHandler];
}

- (void)createLineMemberRegisterRequestWithShopId:(NSNumber *)shopId
                                        cellPhone:(NSString *)cellPhone
                                      accessToken:(NSString *)accessToken
                                      countryCode:(NSString *)countryCode
                                        countryId:(NSNumber *)countryId
                                completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopId,
                                 @"cellPhone"        : cellPhone,
                                 @"accessToken"      : accessToken,
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryId,
                                 @"targetPageType"   : @"AppLineLogin"};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV4/CreateLineMemberRegisterRequest" parameters:parameters completionHandler:completionHandler];
}

- (void)confirmLineMemberVerifyCodeWithCellPhone:(NSString *)cellPhone
                                            code:(NSString *)code
                                     countryCode:(NSString *)countryCode
                                       countryId:(NSNumber *)countryId
                                         isOptIn:(NSNumber *)isOptIn
                               completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSMutableDictionary *parameter = [[NSMutableDictionary alloc] init];
    [parameter setValue:cellPhone forKey:@"cellPhone"];
    [parameter setValue:code forKey:@"code"];
    [parameter setValue:countryCode forKey:@"countryCode"];
    [parameter setValue:countryId forKey:@"countryProfileId"];
    [parameter setValue:@"AppLineLogin" forKey:@"targetPageType"];
    if (isOptIn) {
        parameter[@"isOptIn"] = isOptIn.boolValue ? @"true" : @"false";
    }
    parameter = [self addCommonNYLoginAPIParamsWithDictionary:parameter];
    parameter = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameter];
    NSString *path = @"AuthV4/ConfirmLineMemberVerifyCode";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameter requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark Line Login 登入
- (void)loginLineMemberWithAccessToken:(NSString *)accessToken
                     completionHandler:(LoginCompletionHandler)completionHandler {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setValue:accessToken forKey:@"accessToken"];
    [parameters setValue:@"AppLineLogin" forKey:@"targetPageType"];
    parameters = [self addCommonNYLoginAPIParamsWithDictionary:parameters];
    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];
    NSString *path = @"AuthV4/LoginLineMember";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark 忘記密碼

- (void)resetPasswordWithShopID:(NSNumber *)shopID
                      cellPhone:(NSString *)cellPhone
                 reCaptchaToken:(NSString *)reCaptchaToken
                    countryCode:(NSString *)countryCode
                      countryID:(NSNumber *)countryID
              completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"reCaptchaToken"   : reCaptchaToken,
                                 @"source"           : @"iOSApp",
                                 @"device"           : @"Mobile",
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/CreateNineYiMemberResetPasswordRequest" parameters:parameters completionHandler:completionHandler];
}

- (void)finishResetPasswordWithShopID:(NSNumber *)shopID
                            cellPhone:(NSString *)cellPhone
                             password:(NSString *)password
                               source:(NSString *)source
                               device:(NSString *)device
                           appVersion:(NSString *)appVersion
                          countryCode:(NSString *)countryCode
                            countryID:(NSNumber *)countryID
                    completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"password"         : password,
                                 @"source"           : source,
                                 @"device"           : device,
                                 @"appVer"           : appVersion,
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID};

    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];
    NSString *path = @"AuthV3/FinishNineYiMemberResetPassword";

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)checkResetPasswordMultiFactorAuthWithShopID:(NSNumber *)shopID
                                          cellPhone:(NSString *)cellPhone
                                        countryCode:(NSString *)countryCode
                                          countryID:(NSNumber *)countryID
                                  completionHandler:(MultiFactorAuthCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"           : shopID,
                                 @"cellPhone"        : cellPhone,
                                 @"source"           : @"iOSApp",
                                 @"device"           : @"Mobile",
                                 @"countryCode"      : countryCode,
                                 @"countryProfileId" : countryID};
    
    //POST
    NSString *path = @"AuthV4/CheckResetPasswordMultiFactorAuth";
    
    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSDictionary *data = JSON[kNYAPIDataKey];
            NSString *message = JSON[kNYAPIMessage];
            completionHandler(returnCode, data, message, nil);
        } else {
            completionHandler (nil, nil, nil, NineYiErrorWithCode(0));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)confirmResetPasswordMultiFactorAuthWithShopID:(NSNumber *)shopID
                                            cellPhone:(NSString *)cellPhone
                                          countryCode:(NSString *)countryCode
                                            countryID:(NSNumber *)countryID
                                multiFactorAuthFields:(NSArray *)multiFactorAuthFields
                                    completionHandler:(MultiFactorAuthCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"               : shopID,
                                 @"cellPhone"            : cellPhone,
                                 @"source"               : @"iOSApp",
                                 @"device"               : @"Mobile",
                                 @"countryCode"          : countryCode,
                                 @"countryProfileId"     : countryID,
                                 @"multiFactorAuthFields": multiFactorAuthFields};
    
    //POST
    NSString *path = @"AuthV4/ConfirmResetPasswordMultiFactorAuth";
    
    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSDictionary *data = JSON[kNYAPIDataKey];
            NSString *message = JSON[kNYAPIMessage];
            completionHandler(returnCode, data, message, nil);
        } else {
            completionHandler (nil, nil, nil, NineYiErrorWithCode(0));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark 修改密碼

- (void)changePasswordWithShopID:(NSNumber *)shopID
                     oldPassword:(NSString *)oldPassword
                     newPassword:(NSString *)newPassword
               completionHandler:(DataSourceCompletionHandler)completionHandler {
    //Create parameters
    NSDictionary *parameters = @{@"shopId"      : shopID,
                                 @"oldPassword" : oldPassword,
                                 @"newPassword" : newPassword};

    //POST
    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/ChangeNineYiMemberPassword" parameters:parameters completionHandler:completionHandler];
}

#pragma mark 設定密碼
- (void)setPasswordWithShopID:(NSNumber *)shopID
                    cellPhone:(NSString *)cellPhone
                     password:(NSString *)password
                       source:(NSString *)source
                       device:(NSString *)device
                   appVersion:(NSString *)appVersion
                  countryCode:(NSString *)countryCode
                    countryID:(NSNumber *)countryID
                   verifyType:(NSString *)verifyType
            completionHandler:(LoginCompletionHandler)completionHandler {
    //Create parameters
    NSMutableDictionary *parameters = @{@"shopId" : shopID,
                                        @"cellPhone" : cellPhone,
                                        @"password" : password,
                                        @"source" : source,
                                        @"device" : device,
                                        @"appVer" : appVersion,
                                        @"countryCode" : countryCode,
                                        @"countryProfileId" : countryID,
                                        @"isOptIn" : @(NO),
                                        @"verifyType": verifyType
    }.mutableCopy;
    
    NSString *path = @"AuthV5/SetPassword";
    
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark 商店第三方登入
- (void)getThirdpartyMemberRegisterStatusWithLoginId:(NSString *)loginId
                                            password:(NSString *)password
                                              shopId:(NSNumber *)shopId
                                   completionHandler:(LoginCompletionHandler)completionHandler {
    //防止有參數為nil
    if (!(loginId && password && shopId)) {
        completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    NSDictionary *parameter = @{@"loginId"  : loginId,
                                @"password" : password,
                                @"shopId"   : shopId};

    //POST
    [[NYHTTPSClient sharedClient] postPath:@"AuthV3/GetThirdpartyMemberRegisterStatus" parameters:parameter requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)createThirdpartyMemberRegisterRequestWithToken:(NSString *)token
                                             cellPhone:(NSString *)cellPhone
                                                shopId:(NSNumber *)shopId
                                           countryCode:(NSString *)countryCode
                                             countryID:(NSNumber *)countryID
                                     completionHandler:(DataSourceCompletionHandler)completionHandler {
    //防止有參數為nil
    if (!(token && cellPhone && shopId)) {
        completionHandler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    NSDictionary *parameter = @{@"authSessionToken"  : token,
                                @"cellPhone"         : cellPhone,
                                @"shopId"            : shopId,
                                @"countryCode"       : countryCode,
                                @"countryProfileId"  : countryID};

    [self loginNRegisterGeneralPOSTMethodWithPath:@"AuthV3/CreateThirdpartyMemberRegisterRequest" parameters:parameter completionHandler:completionHandler];
}

- (void)confirmThirdpartyMemberVerifyCodeWithCellPhone:(NSString *)cellPhone
                                                shopId:(NSNumber *)shopId
                                                  code:(NSString *)code
                                                 token:(NSString *)token
                                                source:(NSString *)source
                                                device:(NSString *)device
                                            appVersion:(NSString *)appVersion
                                           countryCode:(NSString *)countryCode
                                             countryID:(NSNumber *)countryID
                                               isOptIn:(NSNumber *)isOptIn
                                     completionHandler:(LoginCompletionHandler)completionHandler {
    //防止有參數為nil
    if (!(cellPhone && shopId && code && token && source && device && appVersion)) {
        completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    NSMutableDictionary *parameter = @{@"cellPhone"         : cellPhone,
                                       @"shopId"            : shopId,
                                       @"code"              : code,
                                       @"authSessionToken"  : token,
                                       @"source"            : source,
                                       @"device"            : device,
                                       @"appVer"            : appVersion,
                                       @"countryCode"       : countryCode,
                                       @"countryProfileId"  : countryID}.mutableCopy;

    if (isOptIn) {
        parameter[@"isOptIn"] = isOptIn.boolValue ? @"true" : @"false";
    }

    parameter = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameter];

    //POST
    [[NYHTTPSClient sharedClient] postPath:@"AuthV3/ConfirmThirdpartyMemberVerifyCode" parameters:parameter requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)loginThirdpartyMemberWithAuthSessionToken:(NSString *)authSessionToken
                                           shopId:(NSNumber *)shopId
                                           source:(NSString *)source
                                           device:(NSString *)device
                                       appVersion:(NSString *)appVersion
                                completionHandler:(LoginCompletionHandler)completionHandler {
    //防止有參數為nil
    if (!(authSessionToken && shopId && source && device && appVersion)) {
        completionHandler (nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        return;
    }

    NSDictionary *parameter = @{@"authSessionToken" : authSessionToken,
                                @"shopId"           : shopId,
                                @"source"           : source,
                                @"device"           : device,
                                @"appVer"           : appVersion};
    
    parameter = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameter];

    [[NYHTTPSClient sharedClient]
     postPath:@"AuthV3/LoginThirdpartyMember"
     parameters:parameter
     success:^(NSURLSessionDataTask * _Nonnull operation, id _Nonnull JSON) {
        if (JSON) {
            NSString *auth = [self getAuthFromURLSession:operation];
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        } else {
            completionHandler(nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler(nil, nil, error);
    }];
}

#pragma mark - 2.3 Login & Register
#pragma mark General
/**
 *  簡單的通用POST
 *
 *  @param path              API路徑
 *  @param parameters        API吃的參數
 *  @param completionHandler Completion Block
 */
- (void)loginNRegisterGeneralPOSTMethodWithPath:(NSString *)path
                                     parameters:(NSDictionary *)parameters
                              completionHandler:(DataSourceCompletionHandler)completionHandler {

    //POST
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            completionHandler(@{kDATA_KEY:JSON}, nil);
        } else {
            completionHandler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

#pragma mark 首下載折價券門市券自動歸戶

- (void)setMemberFirstDownloadECouponByAutoWithShopId:(NSNumber *)shopId
                                    completionHandler:(void (^)(NSString *returnCode, NSArray *eCouponList, NSError *error))completion {
    [[NYHTTPSClient sharedClient]
     postPath:@"ECoupon/SetMemberFirstDownloadECouponByAuto"
     parameters:@{@"shopId": shopId,
                  @"guid": [self GUID]}
     success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[@"ReturnCode"];
        NSArray *eCouponList = responseObject[@"Data"];

        completion(returnCode, eCouponList, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
     }];
}

- (void)setMemberFirstDownloadCouponByAutoWithShopId:(NSNumber *)shopId
                                   completionHandler:(void (^)(NSString *returnCode, NSArray *couponList, NSError *error))completion {
    [[NYHTTPSClient sharedClient]
     postPath:@"Coupon/SetMemberFirstDownloadCouponByAuto"
     parameters:@{@"shopId": shopId,
                  @"guid": [self GUID]}
     success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[@"ReturnCode"];
        NSArray *couponList = responseObject[@"Data"];

        completion(returnCode, couponList, nil);
     }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
     }];
}

#pragma mark Member Info

- (void)getRegisterSettingConfigWithShopID:(NSNumber *)shopID completion:(void (^)(BOOL enableProfile, BOOL enableOptin, BOOL defaultOptin, BOOL allFilled, BOOL enableOptInSplit, NSError *error))completion {

    // Note: 會先打API來決定是不是要往後打 “取得 OptIn 開關設定API”
    __weak typeof(self) weakSelf = self;
    [weakSelf getRegistrationSettingWithShopID:[NYGlobalData shopId] completion:^(BOOL flag, NSError *error) {

        if (!error && flag) {
            // Note: 同 getRegisterSettingWithShopID, 不過是純粹取 OptIn 開關設定
            [weakSelf getRegisterSettingWithShopID:shopID completion:^(NSDictionary *data, NSError *error) {
                if (!error) {
                    // Success
                    BOOL isEnable = [[data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.EnableRegistrationSetting"] boolValue];

                    BOOL enableProfile = [[data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.EnableRequiredProfile"] boolValue];
                    enableProfile &= isEnable;

                    BOOL enableOptin = [[data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.EnableOptIn"] boolValue];
                    enableOptin &= isEnable;
                    BOOL defaultOptin = [[data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.OptIn.Default"] boolValue];
                    
                    BOOL enableOptInSplit = [[data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.EnableOptInSplit"] boolValue];

                    __block BOOL allFilled = YES;
                    NSArray<NSDictionary *> *columnList = [data valueForKeyPath:@"Data.Member.RegistrationSettingEntity.RequiredProfile.ColumnList"];
                    [columnList enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        BOOL isUsing = [obj[@"IsUsing"] boolValue];
                        id value = obj[@"Value"];
                        if (isUsing) {
                            BOOL hasValue = [value isKindOfClass:[NSString class]] && [value length] > 0;
                            allFilled &= hasValue;
                        }
                        // 找到有一個沒填寫就停
                        *stop = !allFilled;
                    }];

                    completion(enableProfile, enableOptin, defaultOptin, allFilled, enableOptInSplit, nil);
                } else {
                    // Fail
                    completion(NO, NO, NO, NO, NO, error);
                }
            }];
        } else {
            // 如果API Fail 取不到是否要繼續往後打的 Bool值，直接視為不開 OptIn。
            completion(NO, NO, NO, NO, NO, nil);
        }
    }];
}

/// 為了雙十一優化，希望 OptIn 前端可以有一層 cache，減低最後往後打的流量...
/// 所以先打這支API來決定，“是否要往後打取得Optin開關設定 API”，如果為 true 才繼續往後打 getRegisterSettingWithShopID 以取得 OptIn 開關設定。
- (void)getRegistrationSettingWithShopID:(NSNumber *)shopID
                              completion:(void (^)(BOOL data, NSError *error))completion {
    NSString *path = @"VIPMemberLite/GetRegistrationSetting";
    NSDictionary *params = @{@"shopId": shopID};

    [[NYHTTPSClient
      sharedClient] getPath:path parameters:params success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
        BOOL data = [responseObject[kNYAPIDataKey] boolValue];
        completion(data, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}

- (void)getRegisterSettingWithShopID:(NSNumber *)shopID
                          completion:(void (^)(NSDictionary *data, NSError *error))completion {
    NSString *path = @"vipmember/GetVIPMemberItemForRegistrationSetting";
    NSDictionary *params = @{@"shopId": shopID};

    [[NYHTTPSClient sharedClient] getPath:path parameters:params success:^(NSURLSessionDataTask *operation, id responseObject) {
        // Check data error
        if ([responseObject isKindOfClass:[NSDictionary class]] &&
            [[responseObject valueForKeyPath:@"Data"] isKindOfClass:[NSDictionary class]]) {
            completion(responseObject, nil);
        } else {
            NSError *dataError = [[NSError alloc] initWithDomain:@"nineyi.data.error" code:0 userInfo:@{}];
            completion(nil, dataError);
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}

- (void)updateRegisterSettingWithSetting:(NSDictionary *)setting
                                  shopID:(NSNumber *)shopID
                            memberCardID:(NSNumber *)cardID
                        enableOptInSplit:(BOOL)enableOptInSplit
                                 isOptIn:(BOOL)isOptIn
                             isEnableEDM:(BOOL)isEnableEDM
                          isEnableEdmSMS:(BOOL)isEnableEdmSMS
                        isAppPushProfile:(BOOL)isAppPushProfile
                              completion:(void (^)(NSDictionary *data, NSError *error))completion {
    NSString *basePath = [NSString stringWithFormat:@"vipmember/UpdateVIPMemberForRegistrationSetting?shopId=%@&memberCardId=%@&guid=%@", shopID, cardID, [self GUID]];
    NSString *path;
    if (enableOptInSplit) {
        NSString *query = [NSString stringWithFormat:@"&isEnableEDM=%@&isEnableEdmSMS=%@&isAppPushProfile=%@",
                           isEnableEDM? @"true": @"false",
                           isEnableEdmSMS? @"true": @"false",
                           isAppPushProfile? @"true": @"false"];
        path = [basePath stringByAppendingString:query];
    } else {
        path = [basePath stringByAppendingString:[NSString stringWithFormat:@"&isOptIn=%@", isOptIn? @"true": @"false"]];
    }

    NSDictionary *params = setting;

    [[NYHTTPSClient sharedClient]
     postPath:path
     parameters:params
     success:^(NSURLSessionDataTask *operation, NSDictionary *responseObject) {
        completion(responseObject, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, error);
    }];
}

- (void)updateCellPhoneWithCellPhone:(NSString *)cellPhone
                    countryAliasCode:(NSString *)countryAliasCode
                   completionHandler:(LoginCompletionHandler)completionHandler {
  
    __weak typeof(self) weakSelf = self;
    NSDictionary *parameters = @{@"Cellphone": cellPhone,
                                 @"AliasCode": countryAliasCode};
    parameters = [[NYReferrerBindingLinkInjectionHelper shared] addReferrerBindingLinkParametersWithParam:parameters];
    NSString *path = @"vipmember/UpdateMemberCellphone";
    
    [[NYHTTPSClient sharedClient] postPath:path parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionDataTask *operation, id JSON) {
        
        NSString *auth = [weakSelf getAuthFromURLSession:operation];
        
        [weakSelf crashlyticsFailureLogWithAPI:@"UpdateCellPhone"
                                     operation:operation
                                requestPayload:parameters
                                  responseData:JSON
                             successReturnCode:APIReturnCode.api0001];
        
        completionHandler(JSON, auth, nil);
        
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        
        [weakSelf crashlyticsFailureLogWithAPI:@"UpdateCellPhone"
                                     operation:operation
                                requestPayload:parameters
                                         error:error];
        
        completionHandler(nil, nil, error);
    }];
}

#pragma mark private method

/// Adding common login parameters
/// @param originalDict - original parameters
- (NSMutableDictionary *)addCommonNYLoginAPIParamsWithDictionary:(NSDictionary *)originalDict {
    NSMutableDictionary *processedDictionary = [[NSMutableDictionary alloc] initWithDictionary:originalDict];
    [processedDictionary setValue:[NYGlobalData shopId] forKey:@"shopId"];
    [processedDictionary setValue:[NYGlobalData appVersionString] forKey:@"appVer"];
    [processedDictionary setValue:@"Mobile" forKey:@"device"];
    [processedDictionary setValue:@"iOSApp" forKey:@"source"];
    return processedDictionary;
}

- (NSString *)getAuthFromURLSession:(NSURLSessionDataTask *)operation {
    NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)operation.response;
    NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields: urlResponse.allHeaderFields forURL:[NYBaseURLConfig baseHTTPSURLWithWebAPIDomain]];
    NSString *auth;
    
    for (NSHTTPCookie *cookie in cookies) {
        if ([@"auth" isEqualToString:[cookie.name lowercaseString]]) {
            auth = cookie.value;
            break;
        }
    }
    return auth;
}

#pragma mark Private Social Login/Register
- (void)socialLoginOrRegisterWithAPIVersion:(NSString *)apiVersion
                                       type:(NSString *)memberType
                                    content:(NSDictionary *) content
                                      email:(NSString *)email
                                successCode:(NSString *)code
                    completionHandler:(LoginCompletionHandler)completionHandler {
    
    __weak typeof(self) weakSelf = self;
    NSDictionary *payload = @{
        @"MemberType": memberType,
        memberType: content,
        @"ShopId": [NYGlobalData shopId],
        @"Email": email,
        @"Originate": @{
            @"Source": @"iOSApp",
            @"Device": @"Mobile",
            @"AppVersion": [NYGlobalData appVersionString],
            @"UnloginId": [self GUID]
        },
        @"Referee": [[NYReferrerBindingLinkInjectionHelper shared] referrerBindingLinkContent]
    };
    
    // 2024/9/27: AuthV5 尚不支援 Apple 登入，但是 payload 都一樣，所以社群登入自行帶入 API 版本
    NSString *path = [NSString stringWithFormat:@"%@/SocialLoginOrRegister", apiVersion];
    [[NYHTTPSClient sharedClient] postPath:path parameters:payload success:^(NSURLSessionDataTask *operation, NSDictionary *JSON) {
        NSString *auth = [weakSelf getAuthFromURLSession:operation];
        
        [weakSelf crashlyticsFailureLogWithAPI:@"SocialLoginOrRegister"
                                     operation:operation
                                requestPayload:payload
                                  responseData:JSON
                             successReturnCode:code];
        
        if (JSON) {
            completionHandler(@{kDATA_KEY:JSON}, auth, nil);
        }   
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        
        [weakSelf crashlyticsFailureLogWithAPI:@"SocialLoginOrRegister"
                                 operation:operation
                            requestPayload:payload
                                     error:error];
        
        completionHandler(nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
    }];
}

#pragma mark Public Social Login/Registered

/// Sign In with Apple
- (void)appleIdLoginOrRegisterWithAuthCode:(NSString *)authCode
                                     email:(NSString *)email
                         completionHandler:(LoginCompletionHandler)completionHandler {
    
    /**
     Apple 登入-註冊登入設計文件
     https://docs.google.com/document/d/1UgNCU70YzplOhkheFcljgaoEmx5O209v_J79Lo4JvJU
     
     當開啟 Sign In with Apple, 必須關掉以下功能:
     - 必須填寫會員資料: welcomePage.shopContract.isLocationMember = False
     - 綁定門市會員: IsShowLocationBindingButton = False (此功能未完成)
     
     */
    NSDictionary *appleContent = @{
        @"AuthCode": authCode,
        @"BundleId": [NYGlobalData bundleId],
        @"TeamId": [NYGlobalData teamId]
    };
    
    [self socialLoginOrRegisterWithAPIVersion:@"AuthV4"
                                         type:@"Apple"
                                      content:appleContent
                                        email:email
                                  successCode:NYLoginReturnCodes.kNYAPIAppleSignInSuccess
                            completionHandler:completionHandler];
}

@end
//
//  NYDataProvider+MemberCenter.m
//  Pods
//
//  Created by Daniel Kao on 11/7/16.
//
//

#import "NYDataProvider+MemberCenter.h"
#import "NYHTTPSClient.h"
#import "NYCDNHTTPClient.h"
#import "NYECouponHTTPSClient.h"
#import "NYMemberHelper.h"
#import <CocoaSecurity/CocoaSecurity.h>
#import "NYMemberTypeConverter.h"
#import "NYUserDefault.h"
#import <NYCore/NYCore-Swift.h>
#import "NYDataProvider+Logging.h"

@implementation NYDataProvider (MemberCenter)

- (void)getVipMemberItemV2WithParameters:(NSDictionary *)parameters completionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient]
     getPath:@"VipMember/GetVIPMemberItemV2"
     parameters:parameters
     success:^(NSURLSessionTask *operation, id JSON) {
         if ([JSON[@"ReturnCode"] isEqualToString:@"API0001"] && [JSON[@"Data"][@"Member"] isKindOfClass:[NSArray class]]) {
             handler (@{kDATA_KEY: JSON[@"Data"]}, nil);
         }
         else {
             handler (@{kDATA_KEY: JSON}, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
         }
     }
     failure:^(NSURLSessionTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)insertOrUpdateVIPMemberInfo:(NSDictionary *)memberInfo WithCompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient] postPath:@"vipMember/InsertOrUpdateVIPMember" parameters:memberInfo requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        
        [self crashlyticsFailureLogWithAPI:@"InsertOrUpdateVIPMember"
                                 operation:operation
                            requestPayload:memberInfo
                              responseData:JSON
                         successReturnCode:@"API0001"];
        
        if (JSON) {
            handler (@{kDATA_KEY:JSON}, nil);
        }
        else {
            handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        
        [self crashlyticsFailureLogWithAPI:@"InsertOrUpdateVIPMember"
                                 operation:operation
                            requestPayload:memberInfo
                                     error:error];
        
        handler(nil, error);
    }];
}

- (void)registerVIPMemberWithParameters:(NSDictionary *)parameters CompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient] postPath:@"vipMember/RegisterVIPMember" parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        if (JSON) {
            handler(@{kDATA_KEY:JSON}, nil);
        } else {
            handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        handler(nil, error);
    }];
}

- (void)bindingShopLocationVIPMemberWithParameters:(NSDictionary *)parameters CompletionHandler:(DataSourceCompletionHandler)handler
{
    [[NYHTTPSClient sharedClient] postPath:@"vipMember/BindingShopLocationVIPMember" parameters:parameters requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        if (JSON) {
            handler (@{kDATA_KEY: JSON}, nil);
        }
        else {
            handler (nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        handler(nil, error);
    }];
}



- (void)getVipShopInfoWithShopId:(NSInteger)shopId
               completionHandler:(DataSourceCompletionHandler)handler {
    //    NYHTTPSClient *client = [[NYHTTPSClient alloc] initWithBaseURL:[NSURL URLWithString:@"https://testapi.n2/APITest/api/Vip/webapi/VipMember/GetVipShopInfo"]];
    //    [client
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"VipMember/GetVipShopInfo"]
     parameters:@{@"shopId" : @(shopId)}
     success:^(NSURLSessionTask *operation, id JSON) {
         handler (@{kDATA_KEY:JSON}, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         handler (nil, error);
     }];
}

- (void)getThirdPartyTradesOrderSettingWithShopId:(NSNumber *)shopId
                                completionHandler:(ThirdPartyTradesOrderSettingCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient]
     GET:@"VIPMember/GetThirdPartyTradesOrderConfiguration"
     parameters:@{@"shopId": shopId}
     progress: nil
     success:^(NSURLSessionTask * _Nonnull operation, id  _Nonnull responseObject) {
         NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
         NSString *message = responseObject[kNYAPIMessage];
         NSDictionary *data = responseObject[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask * _Nonnull operation, NSError * _Nonnull error) {
         completionHandler (nil, nil, nil, error);
     }];
}

- (void)getVIPMemberDisplaySettingsWithShopId:(NSNumber *)shopId
                            completionHandler:(GetDisplaySettingsCompletionHandler)completionHandler {
    // api error code: P:002.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    NSString *endpoint = [@"Shop/GetVipMemberDisplaySettings/" stringByAppendingString:shopId.stringValue];

    [[NYHTTPSClient sharedClient]
     GET:endpoint
     parameters:nil
     progress:nil
     success:^(NSURLSessionTask * _Nonnull operation, id  _Nonnull responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        NSDictionary *data = responseObject[kNYAPIDataKey];
        data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler (nil, nil, nil, error);
    }];
}

- (void)vipMemberCustomLinkSettingsWithShopId:(NSNumber *)shopId completionHandler:(void (^)(NSString *returnCode, NSArray *data, NSError *error))completionHandler {
    // api error code: N:003.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYHTTPSClient sharedClient]
     getPath:@"VIPMember/GetVipMemberCustomLinkSettings"
     parameters:@{@"shopId": shopId}
     success:^(NSURLSessionDataTask * _Nonnull operation, id _Nonnull responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSArray *data = @[];
        if ([responseObject[kNYAPIDataKey] isKindOfClass:[NSArray class]]) {
            // if not API00001, it returns "" (empty string)
            data = responseObject[kNYAPIDataKey];
        }
        completionHandler(returnCode, data, nil);
    } failure:^(NSURLSessionDataTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler (nil, nil, error);
    }];
}

#pragma mark - Member Info API Aggregation

- (void)getVIPInfoWithShopID:(NSNumber *)shopID
                   isBinding:(BOOL)isBinding
           completionHandler:(MemberInfoCompletionHandler)completionHandler {
    // api error code: P:001.99
    [[NYHTTPSClient sharedClient]
     postPath:@"VipMember/GetVipInfo"
     parameters:@{@"shopId": shopID,
                  @"isBinding": isBinding ? @"true" : @"false"}
     success:^(NSURLSessionTask *operation, id JSON) {
         // API format check.
         // If API format is incorrect, try add a empty result instead APP crash
         // see https://bts.nine-yi/edit_bug.aspx?id=14388 for more detail
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];
}

- (void)getMemberLocationTradesSummaryWithShopID:(NSNumber *)shopID
                               completionHandler:(MemberInfoCompletionHandler)completionHandler {
    // api error code: P:009.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYHTTPSClient sharedClient]
     postPath:@"VIPMemberLite/GetMemberLocationTradesSummary"
     parameters:@{@"shopId": shopID}
     success:^(NSURLSessionTask *operation, id JSON) {
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];
}

#pragma mark - Private

- (void)getVIPMemberActivateCardPresentStatusWithShopID:(NSNumber *)shopID
                                      completionHandler:(MemberPresentStatusCompletionHandler)completionHandler {
    // api error code: P:005.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYHTTPSClient sharedClient]
     postPath:@"VipMember/GetOpenCardPresentStatus"
     parameters:@{@"shopId": shopID}
     success:^(NSURLSessionTask *operation, id JSON) {
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];
}

- (void)getNormalMemberctivateCardPresentStatusWithShopID:(NSNumber *)shopID
                                        completionHandler:(MemberPresentStatusCompletionHandler)completionHandler {
    // api error code: P:004.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYHTTPSClient sharedClient]
     postPath:@"VipMember/GetNonVIPOpenCardPresentStatus"
     parameters:@{@"shopId": shopID}
     success:^(NSURLSessionTask *operation, id JSON) {
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];

}

- (void)getMemberBirthdayPresentStatusWithShopID:(NSNumber *)shopID
                               completionHandler:(MemberPresentStatusCompletionHandler)completionHandler {
    // api error code: P:006.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYHTTPSClient sharedClient]
     postPath:@"VipMember/GetBirthdayPresentStatus"
     parameters:@{@"shopId": shopID}
     success:^(NSURLSessionTask *operation, id JSON) {
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];
}

#pragma mark - 會員卡相關

- (void)getCRMMemberTierWithShopID:(NSNumber *)shopID
                 completionHandler:(CRMMemberTierCompletionHandler)completionHandler {
    // api error code: P:003.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    NSString *path = [NSString stringWithFormat:@"CrmMember/GetCrmMemberTier/%@", shopID];
    [[NYHTTPSClient sharedClient] postPath:path
                               parameters:nil
                                  success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
                                      NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
                                      NSString *message = responseObject[kNYAPIMessage];
                                      NSDictionary *data = responseObject[kNYAPIDataKey];
                                      data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
                                      completionHandler(returnCode, message, data, nil);
                                  } failure:^(NSURLSessionTask *operation, NSError *error) {
                                      completionHandler(nil, nil, nil, error);
                                  }];
}

- (void)getCRMMemberCardListWithShopID:(NSNumber *)shopID
                     completionHandler:(CRMShopMemberCardInfoCompletionHandler)completionHandler {
    // api error code: P:007.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    NSString *path = [NSString stringWithFormat:@"CrmShopMemberCard/GetCrmShopMemberCardInfo/%@", shopID];
    [[NYCDNHTTPClient sharedClient] getPath:path
                                 parameters:nil
                                    success:^(NSURLSessionTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        NSDictionary *data = responseObject[kNYAPIDataKey];
        data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 設定頁Email相關

- (void)getVipMemberEmailNotificationWithShopID:(NSNumber *)shopID
                              completionHandler:(MemberInfoCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient]
     getPath:[NSString stringWithFormat:@"VipMember/GetVipMemberEmailNotification/%@", shopID]
     parameters:nil
     success:^(NSURLSessionTask *operation, id JSON) {
         NSString *returnCode = JSON[kNYAPIReturnCodeKey];
         NSString *message = JSON[kNYAPIMessage];
         NSDictionary *data = JSON[kNYAPIDataKey];
         data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
         completionHandler(returnCode, message, data, nil);
     } failure:^(NSURLSessionTask *operation, NSError *error) {
         completionHandler(nil, nil, nil, error);
     }];
}

- (void)updateVipMemberEmailNotificationWithShopID:(NSNumber *)shopID
                                              data:(NSDictionary *)postData
                                 completionHandler:(ShopCRMContractSettingCompletionHandler)completionHandler {
    NSDictionary *para = @{@"shopId" : shopID,
                           @"vipMemberEmailNotification" : (postData)? : @{}};
    
    [[NYHTTPSClient sharedClient] postPath:@"VipMember/UpdateVipMemberEmailNotification" parameters:para requestType:NYHTTPRequestTypeJSON responseType:NYHTTPResponseTypeJSON success:^(NSURLSessionTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString *message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
        completionHandler(returnCode, message, data, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 貨態查詢

- (void)getShippingStatusForUserWithShopId:(NSNumber *)shopId
                         completionHandler:(MemberInfoCompletionHandler)completionHandler {
    // api error code: P:008.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    NSString *path = [NSString stringWithFormat:@"MemberTradesOrder/GetShippingStatusForUser"];
    NSDictionary *params = @{@"shopId" : shopId};
    [[NYHTTPSClient sharedClient] getPath:path
                               parameters:params
                                  success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
                                      NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
                                      NSString *message = responseObject[kNYAPIMessage];
                                      NSDictionary *data = responseObject[kNYAPIDataKey];
                                      data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
                                      completionHandler(returnCode, message, data, nil);
                                  } failure:^(NSURLSessionTask *operation, NSError *error) {
                                      completionHandler(nil, nil, nil, error);
                                  }];
}

- (void)getMemberPresentWithPurchaseWithShopId:(NSNumber *)shopId
                             completionHandler:(MemberInfoCompletionHandler)completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"VipMember/GetMemberPresentWithPurchase"
                                parameters:@{@"shopId" : shopId}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
                                       NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
                                       NSString *message = responseObject[kNYAPIMessage];
                                       NSDictionary *data = responseObject[kNYAPIDataKey];
                                       completionHandler(returnCode, message, data, nil);
                                   } failure:^(NSURLSessionDataTask *operation, NSError *error) {
                                       completionHandler(nil, nil, nil, error);
                                   }];
}

#pragma mark - 查詢是否有定期購管理

- (void)getMemberHasRegularOrderWithShopId:(NSNumber *)shopId
                                completion:(void (^)(NSString *returnCode, NSArray *data, NSError *error))completion {
    // api error code: N:001.99
    // 若此 API failure 且要跳 alert，需帶上此錯誤代碼，以便發生錯誤時反查 API
    [[NYCDNHTTPClient sharedClient] getPath:[NSString stringWithFormat:@"Sidebar/GetSettingList/%@",shopId]
                                 parameters:nil
                                    success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSArray *data = responseObject[kNYAPIDataKey];
        completion(returnCode, data, nil);
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

#pragma mark - 會員邀請碼
- (void)getMemberInvitationInfoWithCompletion:(void (^)(NSString *returnCode, NSDictionary *data, NSError *error))completion {
    NSString *path = @"MemberInvite/Inviter";
    NSMutableDictionary *param = [NSMutableDictionary new];
    NSNumber *shopId = [NYGlobalData shopId];
    if (shopId) {
        param[@"ShopId"] = shopId;
    }
    NSString *memberCode = [NYUserDefault memberCode];
    if (memberCode) {
        param[@"MemberId"] = memberCode;
    }
    
    [[NYHTTPSClient sharedClient]
     postPath:path
     parameters:param
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSDictionary *data = responseObject[kNYAPIDataKey];
        completion(returnCode, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

- (void)getMemberInvitationHistoryWithType:(NSString *)type skip:(NSNumber *)skip count:(NSNumber *)count  completion:(void (^)(NSString *returnCode, NSDictionary *data, NSError *error))completion {
    NSString *path = @"MemberInvite/InviteHistory";
    NSMutableDictionary *param = [NSMutableDictionary dictionaryWithDictionary:@{
        @"Type":type,
        @"Skip":skip,
        @"Count":count
    }];
    NSNumber *shopId = [NYGlobalData shopId];
    if (shopId) {
        param[@"ShopId"] = shopId;
    }
    NSString *memberCode = [NYUserDefault memberCode];
    if (memberCode) {
        param[@"MemberId"] = memberCode;
    }

    [[NYHTTPSClient sharedClient]
     postPath:path
     parameters:param
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSDictionary *data = responseObject[kNYAPIDataKey];
        completion(returnCode, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

- (void)getMemberInvitationExplanationDetailWithPromotionEngineID:(NSNumber *)promotionEngineID
                                                        completion:(void (^)(NSString *returnCode, NSDictionary *data, NSError *error))completion {
    NSMutableDictionary *param = [NSMutableDictionary new];
    param[@"ShopId"] = [NYGlobalData shopId];
    if (promotionEngineID) {
        param[@"PromotionEngineId"] = promotionEngineID;
    } else {
        completion(nil, nil, [NSError new]);
    }
    
    [[NYHTTPSClient sharedClient]
     getPath:@"MemberInvite/InviteDetail"
     parameters:param
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSDictionary *data = responseObject[kNYAPIDataKey];
        completion(returnCode, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completion(nil, nil, error);
    }];
}

#pragma mark - 會員點數中心

- (void)getMemberLoyaltyPointWithShopId:(NSNumber *)shopId
                     membershipCardCode:(NSString *)membershipCardCode
                      completionHandler:(DataSourceCompletionHandler)completionHandler {
    NSDictionary *parameters;
    if (membershipCardCode) {
        parameters = @{@"shopId": shopId,
                       @"membershipCardCode": membershipCardCode};
    } else {
        parameters = @{@"shopId": shopId};
    }
    
    [[NYHTTPSClient sharedClient] getPath:@"LoyaltyPoint/GetPoints" parameters:parameters success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
        
        if ([responseObject[kNYAPIDataKey] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(data, nil);
        } else {
            completionHandler(nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

- (void)getMemberLoyaltyPointTransactionListWithShopId:(NSNumber *)shopID
                                    membershipCardCode:(NSString *)membershipCardCode
                                            startIndex:(NSInteger)startIndex
                                              maxCount:(NSInteger)maxCount
                                     completionHandler:(DataSourceCompletionHandler)completionHandler {
    NSDictionary *parm;
    if (membershipCardCode) {
        parm = @{@"shopId"             : shopID,
                 @"startIndex"         : @(startIndex),
                 @"maxCount"           : @(maxCount),
                 @"membershipCardCode" : membershipCardCode};
    } else {
        parm = @{@"shopId"     : shopID,
                 @"startIndex" : @(startIndex),
                 @"maxCount"   : @(maxCount)};
    }
    
    [[NYHTTPSClient sharedClient] getPath:@"LoyaltyPoint/GetTransactions" parameters:parm success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {

        if ([responseObject[kNYAPIDataKey] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(data, nil);
        } else {
            completionHandler(nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
    
}

- (void)gettPointExchangeECouponListWithShopId:(NSNumber *)shopId
                                    completion:(void (^)(NSString *returnCode, NSArray *data, NSError *error))completion {
    
    NSDictionary *parm = @{@"shopId" : shopId};
    
    [[NYECouponHTTPSClient sharedClient] getPath:@"ecoupon/GetPointExchangeECouponList" parameters:parm success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[@"ReturnCode"];
        NSArray *eCouponListData = responseObject[@"ShopECouponList"];
        
        completion(returnCode, eCouponListData, nil);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completion(nil, @[], error);
    }];
}

- (void)redeemPointExchangeECouponWithECouponId:(NSNumber *)eCouponId
                             exchangeLocationId:(NSInteger)exchangeLocationId
                              outerLocationCode:(NSString *)outerLocationCode
                                   locationName:(NSString *)locationName
                                exchangeChannel:(NSString *)exchangeChannel
                                     completion:(void (^)(NSDictionary *data, NSError *error))completion {
    NSInteger locationId = (exchangeLocationId) ? exchangeLocationId : 0;
    NSString *outerCode = (outerLocationCode) ? outerLocationCode : @"";
    NSString *lName = (locationName) ? locationName : @"";
    NSString *eChannel = (exchangeChannel) ? exchangeChannel : @"All";
    [[NYHTTPSClient sharedClient]
     postPath:@"ECoupon/RedeemPointExchangeECoupon"
     parameters:@{@"eCouponId": eCouponId,
                  @"shopId": [NYGlobalData shopId],
                  @"exchangeLocationId": @(locationId),
                  @"outerLocationCode": outerCode,
                  @"locationName": lName,
                  @"exchangeChannel": eChannel,
                  @"source": @"iOSApp",
                  @"device": @"Mobile"}
     success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
         if ([responseObject isKindOfClass:[NSDictionary class]]) {
             completion(responseObject, nil);
         }
         else {
             completion(nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
         }
     }
     failure:^(NSURLSessionTask *operation, NSError *error) {
         completion(nil, error);
     }];
}

- (void)getIsPhantomMemberWithCompletion:(void(^)(NSString *returnCode, NSString *message, BOOL isPhantom, NSError *error))completion {
    [[NYHTTPSClient sharedClient]
     postPath:@"MemberV2/IsPhantomMember"
     parameters:nil
     success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        BOOL isPhantom = [responseObject[kNYAPIDataKey] boolValue];
        completion(returnCode, message, isPhantom, nil);
    }
     failure:^(NSURLSessionTask *operation, NSError *error) {
         completion(nil, nil, nil, error);
     }];
}

// H Club, UNY, Citi 的前台點數中心，不顯示類型為「消費折抵」、「消費給點」、「活動給點」的連結導頁，因這三家店的訂單不會同步，不能互查，連過去會導致出錯。(VSTS179652)
// 是否啟用此商店 會員點數交易細節 的連結導頁
- (void)getIsLoyaltyPointsTransactionsLinkEnableWithShopId:(NSNumber *)shopId
                                                completion:(void(^)(NSString *returnCode, NSString *message, BOOL isLoyaltyPointsTransactionsLinkEnable, NSError *error))completion {
    [[NYHTTPSClient sharedClient]
     postPath:@"LoyaltyPoint/IsLoyaltyPointsTransactionsLinkEnable"
     parameters:@{@"shopId" : shopId}
     success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        id data = responseObject[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]] && [data[@"IsLoyaltyPointsTransactionsLinkEnable"] isKindOfClass:[NSNumber class]]) {
            BOOL isLoyaltyPointsTransactionsLinkEnable = [data[@"IsLoyaltyPointsTransactionsLinkEnable"] boolValue];
            completion(returnCode, message, isLoyaltyPointsTransactionsLinkEnable, nil);
        } else {
            completion(returnCode, message, nil, nil);
        }
    }
     failure:^(NSURLSessionTask *operation, NSError *error) {
         completion(nil, nil, nil, error);
     }];
}

- (void)getLoyaltyPointConditionWithShopId:(NSNumber *)shopId
                         completionHandler:(void(^)(NSArray<NSDictionary *> * _Nullable data, NSError* _Nullable error))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId};
    
    [[NYHTTPSClient sharedClient] getPath:@"loyaltypoint/GetLoyaltyPointCondition"
                               parameters:parameters success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]] &&
            [responseObject[kNYAPIDataKey] isKindOfClass:[NSArray class]]) {
            NSArray *data = responseObject[kNYAPIDataKey];
            completionHandler(data, nil);
        } else {
            completionHandler(nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
    }];
}

#pragma mark - Others

- (void)getMemberTierCalculateDescriptionWithCompletion:(void(^)(NSString *returnCode, NSString *message, NSString *memberDesc, NSError *error))completion {
    [[NYHTTPSClient sharedClient]
     postPath:@"Shop/GetMemberTierCalculateDescription"
     parameters:@{@"shopId": [NYGlobalData shopId]}
     success:^(NSURLSessionTask *operation, NSDictionary *responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        NSString *message = responseObject[kNYAPIMessage];
        id data = responseObject[kNYAPIDataKey];
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSString *desc = data[@"MemberTierCalculateDescription"];
            completion(returnCode, message, desc, nil);
        } else {
            completion(returnCode, message, nil, nil);
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completion(nil, nil, nil, error);
    }];
}

- (void)logout {
    NSDictionary *param = @{@"shopId" : [NYGlobalData shopId],
                            @"lang" : @"zh-TW"};

    [[NYHTTPSClient sharedClient]
     getPath:@"Auth/Logout"
     parameters:param
     success:nil
     failure:nil];
}

- (void)insertOrUpdateCarrierCode:(NSString *)carrierCode
                       WithShopId:(NSNumber *)shopId
            WithCompletionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSError *error))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"CarrierCode": carrierCode};

    [[NYHTTPSClient sharedClient] postPath:@"vipMember/InsertOrUpdateCarrierCode"
                                parameters:parameters
                               requestType:NYHTTPRequestTypeJSON
                              responseType:NYHTTPResponseTypeJSON
                                   success:^(NSURLSessionTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSString *message = JSON[kNYAPIMessage];
            completionHandler(returnCode, message, nil);
        } else {
            completionHandler(nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)getGetCarrierCodeWithShopId:(NSNumber *)shopId
                  completionHandler:(void (^)(NSString *returnCode, NSDictionary *data, NSError *error))completionHandler {
    [[NYHTTPSClient sharedClient]
     getPath:@"VIPMember/GetCarrierCode"
     parameters:@{@"shopId": shopId}
     success:^(NSURLSessionDataTask * _Nonnull operation, id _Nonnull JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSDictionary *data = JSON[kNYAPIDataKey];
        completionHandler(returnCode, data, nil);
    } failure:^(NSURLSessionDataTask * _Nonnull operation, NSError * _Nonnull error) {
        completionHandler (nil, nil, error);
    }];
}

- (void)requestDeleteAccountWithShopId:(NSNumber *)shopId
                          WithMemberId:(NSNumber *)memberId
                 WithCompletionHandler:(void (^)(NSString *returnCode, NSString *responseMessage, NSError *error))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"MId": memberId};

    [[NYHTTPSClient sharedClient] postPath:@"Question/ApplyForDeleteAccount"
                                parameters:parameters
                               requestType:NYHTTPRequestTypeJSON
                              responseType:NYHTTPResponseTypeJSON
                                   success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSString *message = JSON[kNYAPIMessage];
            completionHandler(returnCode, message, nil);
        } else {
            completionHandler(nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);

    }];
}

#pragma mark - Line 綁定送券
/// 2.74.0 這家店是否啟用「店員幫手註冊後，進行 Line 綁定送券」
- (void)IsEnableRegisterLineBindingWithShopId:(NSNumber *)shopId
                            completionHandler:(void(^)(BOOL isEnable))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"device": @"iOS"};

    [[NYHTTPSClient sharedClient] getPath:@"Line/IsEnableRegisterLineBinding"
                               parameters:parameters
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
       if (JSON) {
           //Success
           NSString *returnCode = JSON[kNYAPIReturnCodeKey];
           BOOL data = [JSON[kNYAPIDataKey] boolValue];
           if ([returnCode isEqualToString:@"API0001"] && data) {
               completionHandler(YES);
           } else {
               completionHandler(NO);
           }
       } else {
           completionHandler(NO);
       }
   }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(NO);
   }];
}

/// 2.74.0 取得會員的 Line 綁定狀態,有錯誤情境會回傳 true
- (void)getLineBindingStatusWithShopId:(NSNumber *)shopId
                              memberId:(NSNumber *)memberId
                     completionHandler:(void(^)(BOOL isBinded))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"memberId": memberId};
    [NYHTTPSClient.sharedClient postPath:@"Line/IsLineBinding"
                              parameters:parameters
                                 success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            BOOL data = [JSON[kNYAPIDataKey] boolValue];

            if ([returnCode isEqualToString:@"API0001"] || ([returnCode isEqualToString:@"API0002"])) {
                completionHandler(data);
            } else {
                // 錯誤情境視為 已經綁定,不觸發 Line 綁定
                completionHandler(YES);
            }
        } else {
            // 錯誤情境視為 已經綁定,不觸發 Line 綁定
            completionHandler(YES);
        }
    }
                                 failure:^(NSURLSessionDataTask *operation, NSError *error) {
        // 錯誤情境視為 已經綁定,不觸發 Line 綁定
        completionHandler(YES);
    }];
}

/// 2.74.0 取得綁定送卷金額
- (void)getRewardInfoWithShopId:(NSNumber *)shopId
              completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {

    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"source": @"iOSApp",
                                 @"device": @"Mobile",
                                 @"appVer": [NYGlobalData appVersionString],
                                 @"lang": [NYLocalizationString selectedLanguageCode].length > 0 ? [NYLocalizationString selectedLanguageCode] : @"zh-TW",
                                 @"lineBindingRequestPage": @"iOS"};

    [[NYHTTPSClient sharedClient] getPath:@"SocialOfficialAccount/GetJoiningRewardInfo"
                               parameters:parameters
                              requestType:NYHTTPRequestTypeJSON
                             responseType:NYHTTPResponseTypeJSON
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
       if (JSON) {
           //Success
           NSString *returnCode = JSON[kNYAPIReturnCodeKey];
           NSString *message = JSON[kNYAPIMessage];
           NSDictionary *data = JSON[kNYAPIDataKey];
           completionHandler(returnCode, message, data, nil);
       } else {
           completionHandler(nil, nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
       }
   }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
   }];
}

/// 2.74.0 取得 Line 的隱私權 Web HTML string
- (void)getLineBindingPrivacyPolicyWithShopId:(NSNumber *)shopId
                            completionHandler:(void(^)(NSString *returnCode, NSString *message, NSString *htmlString, NSError *error))completionHandler {
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"device": @"iOS"};
    [[NYHTTPSClient sharedClient] getPath:@"Line/GetLineBindingPrivacyPolicy"
                               parameters:parameters
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
       if (JSON) {
           //Success
           NSString *returnCode = JSON[kNYAPIReturnCodeKey];
           NSString *message = JSON[kNYAPIMessage];
           NSString *data = JSON[kNYAPIDataKey];
           completionHandler(returnCode, message, data, nil);
       } else {
           completionHandler(nil, nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
       }
   }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
   }];
}

/// 2.74.0 Line 綁定
- (void)bindLineMemberWithToken:(NSString *)token
                         shopId:(NSNumber *)shopId
                      cellPhone:(NSString *)cellPhone
                    countryCode:(NSString *)countryCode
               countryProfileId:(NSNumber *)countryProfileId
              completionHandler:(void(^)(NSString *returnCode, NSString *message, NSError *error))completionHandler {

    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"source": @"iOSApp",
                                 @"device": @"Mobile",
                                 @"appVer": [NYGlobalData appVersionString],
                                 @"accessToken": token,
                                 @"cellPhone": cellPhone,
                                 @"countryCode": countryCode,
                                 @"countryProfileId": countryProfileId
    };

    [NYHTTPSClient.sharedClient postPath:@"Line/BindingLineMember"
                              parameters:parameters
                                 success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSString *message = JSON[kNYAPIMessage];
            completionHandler(returnCode, message, nil);
        } else {
            completionHandler(nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    }
                                 failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

/// 24.12 取得 Line 綁定版位顯示設定（Hint: 會員專區最上方; Card: 會員專區 OtherFunction; PopUp: 彈窗）
- (void)getLineBindingDisplayWithShopId:(NSNumber *)shopId
                                 appVer:(NSString *)appVer
                      completionHandler:(void(^)(NSString *returnCode, NSDictionary *data, NSError *error))completionHandler {
    NSDictionary *parameters = @{@"shopId" : shopId,
                                 @"device" : @"iOS",
                                 @"appVer": appVer};
    
    [[NYHTTPSClient sharedClient] getPath:@"Line/IsLineBindingDisplay"
                               parameters:parameters
                              requestType:NYHTTPRequestTypeJSON
                             responseType:NYHTTPResponseTypeJSON
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSDictionary *data = JSON[kNYAPIDataKey];
            data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
            completionHandler(returnCode, data, nil);
        } else {
            completionHandler(nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

/// 取得商店是否有 Line Shop Account
- (void)getHasLineShopAccountWithShopId:(NSNumber *)shopId
                                 appVer:(NSString *)appVer
                      completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError *error))completionHandler {
    NSDictionary *parameters = @{@"shopId" : shopId,
                                 @"device" : @"iOS",
                                 @"appVer": appVer};
    
    [[NYHTTPSClient sharedClient] getPath:@"Line/HasLineShopAccount"
                               parameters:parameters
                              requestType:NYHTTPRequestTypeJSON
                             responseType:NYHTTPResponseTypeJSON
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
        if (JSON) {
            //Success
            NSString *returnCode = JSON[kNYAPIReturnCodeKey];
            NSString *message = JSON[kNYAPIMessage];
            NSDictionary *data = JSON[kNYAPIDataKey];
            data = [data isKindOfClass:[NSDictionary class]] ? data : @{};
            
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(NYDataProviderErrorCodeAPIReturnUnExpectFormatError));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getDefaultLocationCountryWithShopId:(NSNumber *)shopId
                           countryProfileId:(NSNumber *)countryProfileId
                          completionHandler:(void(^)(NSString *returnCode, NSString *country, NSError *error))completionHandler {

    NSDictionary *parameters = @{@"shopId"              : shopId,
                                 @"countryProfileId"    : countryProfileId};

    [[NYHTTPSClient sharedClient] getPath:@"Vipmember/GetDefaultLocationCountry"
                               parameters:parameters
                              requestType:NYHTTPRequestTypeJSON
                             responseType:NYHTTPResponseTypeJSON
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
       if (JSON) {
           //Success
           NSString *returnCode = JSON[kNYAPIReturnCodeKey];
           NSString *country = JSON[kNYAPIDataKey];
           completionHandler(returnCode, country, nil);
       } else {
           completionHandler(nil, nil, NineYiErrorWithCode(0));
       }
   }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
   }];
}

- (void)getCountryCityListWithShopId:(NSNumber *)shopId
                        memberCardId:(NSNumber *)memberCardId
                   completionHandler:(void(^)(NSArray *list, NSError *error))completionHandler {

    NSDictionary *parameters = @{@"shopId"                : shopId,
                                 @"memberCardId"          : memberCardId};

    [[NYHTTPSClient sharedClient] getPath:@"zipcode/GetCountryCityList"
                               parameters:parameters
                              requestType:NYHTTPRequestTypeJSON
                             responseType:NYHTTPResponseTypeJSON
                                  success:^(NSURLSessionDataTask *operation, id JSON) {
        if ([JSON isKindOfClass:[NSArray class]]) {
            completionHandler(JSON, nil);
        } else {
            completionHandler(nil, NineYiErrorWithCode(0));
        }
   }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, error);
   }];
}

#pragma mark - 會員頭像
- (void)startUploadMemberPhotoWithShopId:(NSNumber *)shopId
                               photoType:(NSString *)photoType
                       completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    
    NSDictionary *parameters = @{@"shopId": shopId,
                                 @"Type"  : photoType};
    
    [[NYHTTPSClient sharedClient] postPath:@"MemberService/StartUploadMemberPhoto"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)finishUploadMemberPhotoWithShopId:(NSNumber *)shopId
                        completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    
    NSDictionary *parameters = @{@"shopId": shopId};
    
    [[NYHTTPSClient sharedClient] postPath:@"MemberService/FinishUploadMemberPhoto"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)removeMemberPhotoWithShopId:(NSNumber *)shopId
                  completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    
    NSDictionary *parameters = @{@"shopId": shopId};
    
    [[NYHTTPSClient sharedClient] postPath:@"MemberService/RemoveMemberPhoto"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            // data 後端定義是 null
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getMemberServiceMemberInfoWithShopId:(NSNumber *)shopId
                           completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    
    NSDictionary *parameters = @{@"shopId": shopId};
    
    [[NYHTTPSClient sharedClient] postPath:@"MemberService/GetMemberInfo"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

#pragma mark - 購物金
- (void)getStoreCreditBalanceWithShopId:(NSNumber *)shopId
                      completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    
    NSDictionary *parameters = @{@"shopId": shopId};
    
    [[NYHTTPSClient sharedClient] getPath:@"StoreCredit/GetAccount"
                               parameters:parameters
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    } failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

@end
//
//  NYDataProvider+MemberShipCardManage.m
//  Pods
//
//  Created by Luke Wang on 2023/3/24.
//

#import "NYDataProvider+MemberShipCardManage.h"
#import "NYHTTPSClient.h"
#import <NYCore/NYCore-Swift.h>

@implementation NYDataProvider (MemberShipCardManage)

- (void)getVipMemberInfoOfficialIndexMemberInfoWithShopId:(NSNumber *)shopId
                                        completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"VipMemberInfoOfficialIndex/GetMemberInfo"
                               parameters:@{@"shopId": shopId}
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getComplexMemberInfoWithShopId:(NSNumber *)shopId
                           isEnableCRM:(BOOL)isEnableCRM
                isEnableMembershipCard:(BOOL)isEnableMembershipCard
                     completionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"ComplexMemberInfoOfficialIndex/GetComplexMemberInfo"
                               parameters:@{@"shopId": shopId,
                                            @"isEnableCRM": isEnableCRM ? @"true" : @"false",
                                            @"isEnableMembershipCard": isEnableMembershipCard ? @"true" : @"false"}
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getMembershipCardMetasWithCompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSArray *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"MembershipCard/GetCardMetas"
                               parameters:nil
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSArray *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getMembershipCardOperationSettingsWithCompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSArray *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"MembershipCard/GetOperationSettings"
                               parameters:nil
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSArray *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getMembershipCardDetailsWithShopId:(NSNumber *)shopId
                       membershipCardCodes:(NSArray<NSString *> *)membershipCardCodes
                         CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSArray *data, NSError* error))completionHandler {
    NSDictionary *parameters = @{@"ShopId": shopId,
                                 @"MembershipCardCodes": membershipCardCodes};
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/GetMembershipCardDetails"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSArray *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getStampCountWithShopId:(NSNumber *)shopId
              CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    NSString *path = [NSString stringWithFormat:@"StampPoint/%@/Member/StampCount", shopId];
    [[NYHTTPSClient sharedClient] getPath:path
                               parameters:nil
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)setDefaultMembershipCardWithShopId:(NSNumber *)shopId
                        membershipCardCode:(NSString *)membershipCardCode
                         CompletionHandler:(void(^)(NSString *returnCode, NSString *message, BOOL data, NSError* error))completionHandler {
    NSDictionary *parameters = @{@"ShopId": shopId,
                                 @"MembershipCardCode": membershipCardCode};
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/SetDefaultCard"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            BOOL data = [responseObject[kNYAPIDataKey] boolValue];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)transferMembershipCardPointWithShopId:(NSNumber *)shopId
                       FromMembershipCardCode:(NSString *)fromMembershipCardCode
                         ToMembershipCardCode:(NSString *)toMembershipCardCode
                            CompletionHandler:(void(^)(NSString *returnCode, NSString *message, BOOL data, NSError* error))completionHandler {
    NSDictionary *parameters = @{@"ShopId": shopId,
                                 @"FromMembershipCardCode": fromMembershipCardCode,
                                 @"ToMembershipCardCode": toMembershipCardCode};
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/TransferPoint"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            BOOL data = [responseObject[kNYAPIDataKey] boolValue];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)removeMembershipCardWithShopId:(NSNumber *)shopId
                    MembershipCardCode:(NSString *)membershipCardCode
                     CompletionHandler:(void(^)(NSString *returnCode, NSString *message, BOOL data, NSError* error))completionHandler {
    NSDictionary *parameters = @{@"ShopId": shopId,
                                 @"MembershipCardCode": membershipCardCode};
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/Remove"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            BOOL data = [responseObject[kNYAPIDataKey] boolValue];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)bindingMembershipCardWithShopId:(NSNumber *)shopId
              BindingMembershipCardCode:(NSString *)bindingMembershipCardCode
                      CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    NSDictionary *parameters = @{@"ShopId": shopId,
                                 @"BindingMembershipCardCode": bindingMembershipCardCode};
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/Binding"
                                parameters:parameters
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getMembershipCardPrivacyPolicyWithShopId:(NSNumber *)shopId
                               CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSString *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"MembershipCard/GetMembershipCardPrivacyPolicy"
                               parameters:@{@"ShopId": shopId,
                                            @"clientType": @"iOSApp"}
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSString *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getIsEnableForgottenMembershipCardWithShopId:(NSNumber *)shopId
                                   CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] getPath:@"MembershipCard/IsEnableForgottenMembershipCard"
                               parameters:@{@"shopId": shopId}
                                  success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                  failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)sendForgottenMembershipCardSMSWithShopId:(NSNumber *)shopId
                               CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/SendForgottenMembershipCardSMS"
                                parameters:@{@"ShopId": shopId}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)resendForgottenMembershipCardSMSByVoiceWithShopId:(NSNumber *)shopId
                                        CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/ResendForgottenMembershipCardSMSByVoice"
                                parameters:@{@"ShopId": shopId}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getForgottenMembershipCardsWithShopId:(NSNumber *)shopId
                                   VerifyCode:(NSString *)verifyCode
                            CompletionHandler:(void(^)(NSString *returnCode, NSString *message, NSDictionary *data, NSError* error))completionHandler {
    [[NYHTTPSClient sharedClient] postPath:@"MembershipCard/GetForgottenMembershipCards"
                                parameters:@{@"ShopId": shopId,
                                             @"VerifyCode": verifyCode}
                                   success:^(NSURLSessionDataTask *operation, id responseObject) {
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            //Success
            NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
            NSString *message = responseObject[kNYAPIMessage];
            NSDictionary *data = responseObject[kNYAPIDataKey];
            completionHandler(returnCode, message, data, nil);
        } else {
            completionHandler(nil, nil, nil, NineYiErrorWithCode(0));
        }
    }
                                   failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

@end
//
//  NYDataProvider+NewCoupon.m
//  NineyiAppApi
//
//  Created by Naiyu Wang on 2023/5/17.
//

#import "NYDataProvider+NewCoupon.h"
#import "NYHTTPSClient.h"
#import <NYCore/NYCore-Swift.h>

@implementation NYDataProvider (NewCoupon)


// MARK: 23.7.0 打 API 取得需使用新版或是舊版優惠券
- (void)getIsEnableNewCouponZoneWithShopId:(NSNumber *)shopId
                         completionHandler:(void (^)(NSString * _Nullable returnCode,
                                                     BOOL isEnabled,
                                                     NSError * _Nullable error))completionHandler
{
    [[NYHTTPSClient sharedClient]
     getPath:@"ShopStaticSetting/GetIsEnableNewCouponZone"
     parameters:@{@"shopId" : shopId}
     success:^(NSURLSessionDataTask *operation, id responseObject) {
        NSString *returnCode = responseObject[kNYAPIReturnCodeKey];
        BOOL isEnabled = [responseObject[kNYAPIDataKey] boolValue];
        completionHandler(returnCode, isEnabled, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, false, error);
    }];
}

- (void)getUnclaimedCouponsWithShopId:(NSNumber *)shopId
                   couponTypeRawValue:(NSString *)couponType
                       couponCustomId:(NSNumber * _Nullable)couponCustomId
                  channelTypeRawValue:(NSString * _Nullable)channelType
                     sortTypeRawValue:(NSString * _Nullable)sortType
                      catalogCustomId:(NSNumber * _Nullable)catalogCustomId
                               offset:(NSNumber * _Nonnull)offset
                                limit:(NSNumber * _Nullable)limit
                    completionHandler:(void (^)(NSString * _Nullable returnCode,
                                                NSString * _Nullable message,
                                                NSDictionary * _Nullable data,
                                                NSError * _Nullable error))completionHandler
{
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    [params setValue:shopId forKey:@"shopId"];
    [params setValue:@"iOSApp" forKey:@"source"];
    [params setValue:@(newCouponSupportVersion.integerValue) forKey:@"supportVersion"];
    [params setValue:[NYLocalizationString selectedLanguageCode].length > 0 ? [NYLocalizationString selectedLanguageCode] : @"zh-TW" forKey:@"lang"];
    [params setValue:couponType forKey:@"typeDef"];
    [params setValue:offset forKey:@"offset"];
    
    if (couponCustomId != nil) {
        [params setValue:couponCustomId forKey:@"ecouponCustomId"];
    }
    
    if (channelType != nil) {
        [params setValue:channelType forKey:@"channel"];
    }
    
    if (sortType != nil) {
        [params setValue:sortType forKey:@"sort"];
    }
    
    if (catalogCustomId != nil) {
        [params setValue:catalogCustomId forKey:@"catalogId"];
    }
    
    if (limit != nil) {
        [params setValue:limit forKey:@"limit"];
    }
        
    [[NYHTTPSClient sharedClient]
     getPath:@"CouponV2/GetCouponList"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        if ([data isKindOfClass:[NSDictionary class]] == false) {
            data = [NSDictionary dictionary];
        }
        
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getClaimedCouponsWithShopId:(NSNumber *)shopId
                          couponIds:(NSArray *)couponIds
                 couponTypeRawValue:(NSString *)couponType
                     couponCustomId:(NSNumber * _Nullable)couponCustomId
                channelTypeRawValue:(NSString * _Nullable)channelType
                   sortTypeRawValue:(NSString * _Nullable)sortType
                    catalogCustomId:(NSNumber * _Nullable)catalogCustomId
                             offset:(NSNumber * _Nonnull)offset
                              limit:(NSNumber * _Nullable)limit
                  completionHandler:(void (^)(NSString * _Nullable returnCode,
                                              NSString * _Nullable message,
                                              NSDictionary * _Nullable data,
                                              NSError * _Nullable error))completionHandler
{
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    [params setValue:shopId forKey:@"shopId"];
    [params setValue:@"iOSApp" forKey:@"source"];
    [params setValue:@(newCouponSupportVersion.integerValue) forKey:@"supportVersion"];
    [params setValue:couponIds forKey:@"couponIds"];
    [params setValue:[NYLocalizationString selectedLanguageCode].length > 0 ? [NYLocalizationString selectedLanguageCode] : @"zh-TW" forKey:@"lang"];
    [params setValue:couponType forKey:@"typeDef"];
    [params setValue:offset forKey:@"offset"];
    
    if (couponCustomId != nil) {
        [params setValue:couponCustomId forKey:@"ecouponCustomId"];
    }
    
    if (channelType != nil) {
        [params setValue:channelType forKey:@"channel"];
    }
    
    if (sortType != nil) {
        [params setValue:sortType forKey:@"sort"];
    }
    
    if (catalogCustomId != nil) {
        [params setValue:catalogCustomId forKey:@"catalogId"];
    }
    
    if (limit != nil) {
        [params setValue:limit forKey:@"limit"];
    }
    
    [[NYHTTPSClient sharedClient]
     postPath:@"CouponV2/GetMemberCouponList"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        if ([data isKindOfClass:[NSDictionary class]] == false) {
            data = [NSDictionary dictionary];
        }
        
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)getCouponsAvailabilityWithShopId:(NSNumber *)shopId
                              couponType:(NSString *)type
                                couponId:(NSNumber *)couponId
                       completionHandler:(void (^)(NSString * _Nullable returnCode,
                                                   NSString * _Nullable message,
                                                   BOOL isAvailable,
                                                   NSError * _Nullable error))completionHandler
{
    NSDictionary *params = @{ @"shopId":shopId,
                              @"typeDef": type,
                              @"couponId":couponId
    };
    
    [[NYHTTPSClient sharedClient]
     getPath:@"CouponV2/GetCouponAvailability"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        BOOL isAvailable = [JSON[kNYAPIDataKey] boolValue];
                
        completionHandler(returnCode, message, isAvailable, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, NO, error);
    }];
}

- (void)getCouponsFilterSettingWithShopId:(NSNumber *)shopId
                        completionHandler:(void (^)(NSString * _Nullable returnCode,
                                                    NSString * _Nullable message,
                                                    NSDictionary * _Nullable data,
                                                    NSError * _Nullable error))completionHandler
{
    NSDictionary *params = @{ @"shopId":shopId,
                              @"lang":[NYLocalizationString selectedLanguageCode].length > 0 ? [NYLocalizationString selectedLanguageCode] : @"zh-TW"
    };
    
    [[NYHTTPSClient sharedClient]
     getPath:@"CouponV2/GetFilterSettings"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        if ([data isKindOfClass:[NSDictionary class]] == false) {
            data = [NSDictionary dictionary];
        }
        
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)cancelNewCouponAllDataFetching {
     [[NYHTTPSClient sharedClient] cancelAllHTTPOperationsWithMethod:@"GET" path:@"CouponV2/GetCouponList"];
     [[NYHTTPSClient sharedClient] cancelAllHTTPOperationsWithMethod:@"POST" path:@"CouponV2/GetMemberCouponList"];
     [[NYHTTPSClient sharedClient] cancelAllHTTPOperationsWithMethod:@"GET" path:@"CouponV2/GetCouponAvailability"];
     [[NYHTTPSClient sharedClient] cancelAllHTTPOperationsWithMethod:@"GET" path:@"CouponV2/GetFilterSettings"];
 }

- (void)getAvailableLocationsByEcouponIdWithShopId:(NSNumber *)shopId
                                         EcouponId:(NSNumber *)ecouponId
                                 CompletionHandler:(void (^)(NSString * _Nullable returnCode,
                                                             NSString * _Nullable message,
                                                             NSArray * _Nullable data,
                                                             NSError * _Nullable error))completionHandler {
    NSString *langString = ([NYLocalizationString selectedLanguageCode].length > 0) ? [NYLocalizationString selectedLanguageCode] : @"zh-TW";
    NSDictionary *params = @{ @"shopId": shopId,
                              @"ecouponId": ecouponId,
                              @"lang": langString
    };
    
    [[NYHTTPSClient sharedClient]
     getPath:@"CouponV2/GetAvailableLocationsByEcouponId"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSArray *data = nil;
        id dataObject = JSON[kNYAPIDataKey];
        if ([dataObject isKindOfClass:[NSArray class]]) {
            data = dataObject;
        }
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)distributeEcouponWithLocationWithShopId:(NSNumber *)shopId
                                      EcouponId:(NSNumber *)ecouponId
                                   LocationCode:(NSString *)locationCode
                              CompletionHandler:(void (^)(NSString * _Nullable returnCode,
                                                          NSString * _Nullable message,
                                                          NSDictionary * _Nullable data,
                                                          NSError * _Nullable error))completionHandler {
    NSString *langString = ([NYLocalizationString selectedLanguageCode].length > 0) ? [NYLocalizationString selectedLanguageCode] : @"zh-TW";
    NSDictionary *params = @{ @"shopId": shopId,
                              @"ecouponId": ecouponId,
                              @"locationCode": locationCode,
                              @"source": @"iOSApp",
                              @"supportVersion": @(newCouponSupportVersion.integerValue),
                              @"lang": langString
    };
    
    [[NYHTTPSClient sharedClient]
     postPath:@"CouponV2/DistributeEcouponWithLocation"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

- (void)transferECouponWithShopId:(NSNumber *)shopId
                        eCouponId:(NSNumber *)eCouponId
                   eCouponSlaveId:(NSNumber *)eCouponSlaveId
                        cellPhone:(NSString *)cellPhone
                        aliasCode:(NSString *)aliasCode
                completionHandler:(void (^)(NSString * _Nullable returnCode,
                                            NSString * _Nullable message,
                                            NSError * _Nullable error))completionHandler {
    NSString *langString = ([NYLocalizationString selectedLanguageCode].length > 0) ? [NYLocalizationString selectedLanguageCode] : @"zh-TW";
    NSDictionary *params = @{ @"shopId": shopId,
                              @"eCouponId": eCouponId,
                              @"eCouponSlaveId": eCouponSlaveId,
                              @"cellPhone": cellPhone,
                              @"aliasCode": aliasCode,
                              @"source": @"iOSApp",
                              @"lang": langString
    };
    
    [[NYHTTPSClient sharedClient]
     postPath:@"CouponV2/TransferECoupon"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        
        completionHandler(returnCode, message, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, error);
    }];
}

- (void)getTransferCouponIdListWithShopId:(NSNumber *)shopId
                             couponIdList:(NSArray<NSNumber *> *)couponIdList
                        completionHandler:(void (^)(NSString * _Nullable returnCode,
                                                    NSString * _Nullable message,
                                                    NSDictionary * _Nullable data,
                                                    NSError * _Nullable error))completionHandler {
    NSString *langString = ([NYLocalizationString selectedLanguageCode].length > 0) ? [NYLocalizationString selectedLanguageCode] : @"zh-TW";
    NSDictionary *params = @{ @"shopId": shopId,
                              @"couponIdList": couponIdList,
                              @"source": @"iOSApp",
                              @"lang": langString
    };
    
    [[NYHTTPSClient sharedClient]
     postPath:@"CouponV2/GetTransferCouponIdList"
     parameters:params
     success:^(NSURLSessionDataTask *operation, id JSON) {
        NSString *returnCode = JSON[kNYAPIReturnCodeKey];
        NSString * message = JSON[kNYAPIMessage];
        NSDictionary *data = JSON[kNYAPIDataKey];
        
        completionHandler(returnCode, message, data, nil);
    }
     failure:^(NSURLSessionDataTask *operation, NSError *error) {
        completionHandler(nil, nil, nil, error);
    }];
}

@end
//
//  NYLoginHelper.m
//  NineYiShopping
//
//  Created by Prince on 13/3/26.
//  Copyright (c) 2013年 Julie Lin. All rights reserved.
//

#import "NYLoginHelper.h"

// FIXME: UI dependency
#import "NYCookieManager.h"
#import "NYFacebookHelper.h"
#import "NYHTTPSClient.h"
#import "NYDataProvider+Login.h"
#import "NYDataProvider+MemberCenter.h"
#import "NYUserDefaultsHelper.h"
#import "NYGlobalData.h"
#import "NYUserDefault.h"
#import "NYCartBadgeHelper.h"
#import "NYFavoriteManager.h"
#import "NYMemberHelper.h"
#import "NYUserDefault.h"
#import "NYKeychainHelper.h"

#import <NYCore/NYCore-Swift.h>
#import <AuthenticationServices/AuthenticationServices.h>

NSString * const kNYLoginType91Mai = @"91mai";
NSString * const kNYLoginTypeFacebook = @"Facebook";
NSString * const kNYLoginTypeLineLogin = @"LineLogin";
NSString * const kNYLoginTypeThirdPartyAuth = @"ThirdpartyAuth";
NSString * const kNYLoginTypeAppleSignIn = @"AppleSignIn";

@implementation NYLoginHelper

+ (instancetype)sharedInstance {
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

static void (^_logoutClearAllSetting)(BOOL);
+ (void)setLogoutClearAllSetting:(void (^)(BOOL))logoutClearAllSetting {
    _logoutClearAllSetting = logoutClearAllSetting;
}

+ (void (^)(BOOL))logoutClearAllSetting {
    if (_logoutClearAllSetting) {
        return _logoutClearAllSetting;
    } else {
        return nil;
    }
}

#pragma mark - Read-Only Properties

- (BOOL)isLogin {
    NSDictionary *cookies = [[NYCookieManager sharedManager] cookiesByCookieName:kCOOKIE_NAME_AUTH];
    BOOL isLogin = cookies.count > 0;
    
    return isLogin;
}

- (void)checkLoginAndMemberStatusWithCompletion:(void(^)(NYMemberLoginState memberLoginState, NSString *message))completion {
    typeof(self) __weak weakSelf = self;
    if ([self isLogin]) {
        // VSTS80198, 93301 前端統一處理方式
        [[NYDataProvider sharedInstance] getIsPhantomMemberWithCompletion:^(NSString *returnCode, NSString *message, BOOL isPhantom, NSError *error) {
            if(!error) {
                if (isPhantom) {
                    // Data 拿得到 true 代表 API 有打成功，和前端邏輯一樣（HTTP response status code == 200 && Data == true），判斷為被註銷會員，把會員登出
                    [weakSelf logoutWithCompletionHandler:^{
                        completion(NYMemberLoginStatePhantomMember, message);
                    }];
                } else {
                    completion(NYMemberLoginStateNormalLogin, message);
                }
            } else {
                // API 打失敗，可能是系統流量爆衝拿不回資料，判斷為系統錯誤，轉導到首頁
                completion(NYMemberLoginStateSystemError, @"common_alert_system_is_busy");
            }
        }];
    }
    else {
        completion(NYMemberLoginStateLogout, @"");
    }
}

#pragma mark - Handle login logic

- (void)cleanAllSettingsWithIsLoginAgain:(BOOL)isLoginAgain {
    [NYLoginHelper logoutClearAllSetting](isLoginAgain);
}

- (void)logoutAndLoginAgainWithCompletionHandler:(void (^)(void))completion {
    [self cleanAllSettingsWithIsLoginAgain:YES];

    if (completion) {
        completion();
    }
}

- (void)logoutWithCompletionHandler:(void (^)(void))completion {
    [self cleanAllSettingsWithIsLoginAgain:NO];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NYLogoutNotification" object:nil];
    if (completion) {
        completion();
    }
}

- (NYUserLoginType)userLoginType {
    NSString *loginType = [NYUserDefault loginType];

    if ([loginType isEqualToString:kNYLoginType91Mai]) {
        return NYUserLoginTypeNineyiMember;
    } else if ([loginType isEqualToString:kNYLoginTypeFacebook]) {
        return NYUserLoginTypeFacebook;
    } else if ([loginType isEqualToString:kNYLoginTypeThirdPartyAuth]) {
        return NYUserLoginTypeThirdPartyAuth;
    } else if ([loginType isEqualToString:kNYLoginTypeAppleSignIn]) {
        return NYUserLoginTypeAppleSignIn;
    } else if ([loginType isEqualToString:kNYLoginTypeLineLogin]) {
        return NYUserLoginTypeLineLogin;
    } else {
        return NYUserLoginTypeUnknown;
    }
}

/// 檢查 Apple 登入 credential state
- (void)verifyAppleSignInCredentialState {
    if (!self.isLogin || [self userLoginType] != NYUserLoginTypeAppleSignIn) {
        return;
    }
    
    NSString *userId = [NYKeychainHelper appleSignInUserId];
    if (!userId || userId.length == 0) {
        return;
    }
    
    ASAuthorizationAppleIDProvider *provider = [[ASAuthorizationAppleIDProvider alloc] init];
    [provider getCredentialStateForUserID:userId completion:^(ASAuthorizationAppleIDProviderCredentialState credentialState, NSError * _Nullable error) {
        switch (credentialState) {
            case ASAuthorizationAppleIDProviderCredentialRevoked:
            case ASAuthorizationAppleIDProviderCredentialNotFound:
                // remove apple user id & email
                [NYKeychainHelper deleteAppleSignInCredential];
                [self logoutWithCompletionHandler:nil];
                break;
            case ASAuthorizationAppleIDProviderCredentialTransferred:
                // 先不處理 app transferred 情境
                break;
            default:
                break;
        }
    }];
}

#pragma mark - Private

- (void)saveUserLoginTypeToUserDefaults:(NSString *)userLoginType {
    [NYUserDefault setLoginType:userLoginType];
}

- (void)handleLoginSuccessWithLoginType:(NYUserLoginType)loginType
                             authCookie:(NSString *)authCookie
                              cellPhone:(NSString *)cellPhone
                            countryCode:(NSString *)countryCode
                              countryID:(NSNumber *)countryID
                      completionHandler:(void (^)(void))completionHandler {
    NSString *uAuth = [[NYCookieManager sharedManager] cookieValueFromLocal:kCOOKIE_NAME_U_AUTH];
    // 2020/9/15 auth 和 uAuth 長度不會一樣，如果出現就把所有 auth 都砍掉當沒登入
    if (uAuth.length != authCookie.length) {
        [[NYCookieManager sharedManager] setCookieValue:authCookie forCookieName:kCOOKIE_NAME_AUTH];
    } else {
        [[NYCookieManager sharedManager] removeCookieWithCookieName:kCOOKIE_NAME_AUTH];
    }
    
    switch (loginType) {
        case NYUserLoginTypeNineyiMember:
            [self saveUserLoginTypeToUserDefaults:kNYLoginType91Mai];
            break;
        case NYUserLoginTypeFacebook:
            [self saveUserLoginTypeToUserDefaults:kNYLoginTypeFacebook];
            [self removeCellPhoneNumberFromUserDefaults];
            break;
        case NYUserLoginTypeThirdPartyAuth:
            [self saveUserLoginTypeToUserDefaults:kNYLoginTypeThirdPartyAuth];
            break;
        case NYUserLoginTypeLineLogin:
            [self saveUserLoginTypeToUserDefaults:kNYLoginTypeLineLogin];
            [self removeCellPhoneNumberFromUserDefaults];
            break;
        case NYUserLoginTypeAppleSignIn:
            [self saveUserLoginTypeToUserDefaults:kNYLoginTypeAppleSignIn];
            [self removeCellPhoneNumberFromUserDefaults];
            break;
        case NYUserLoginTypeUnknown:
            NSAssert(NO, @"User Login Type Unknown");
            break;
        default:
            break;
    }
    
    // loginType 非 NYUserLoginTypeNineyiMember 操作手機號碼綁定後，會帶入手機資訊，需存下來
    [self saveCellPhoneCountryCodeToUserDefaults:countryCode];
    [self saveCellPhoneCountryIDToUserDefaults:countryID];
    [self saveCellPhoneNumberToUserDefaults:cellPhone];
    
    //合併登入前後收藏跟購物車資料
    [self mergeFavoriteListAndShoppingCartWithCompletionHandler:^{
        //更新會員狀態 (取得會員資料有無填寫)
        [[NYMemberHelper shareInstance] updateMemberStatus:nil];
        
        if (completionHandler) {
            completionHandler();
        }
    }];
}

- (void)saveCellPhoneNumberToUserDefaults:(NSString *)cellPhone {
    [NYUserDefault setUserCellPhone:cellPhone];
}

- (void)saveCellPhoneCountryCodeToUserDefaults:(NSString *)countryCode {
    [NYUserDefault setUserCellPhoneCountryCode:countryCode];
}

- (void)saveCellPhoneCountryIDToUserDefaults:(NSNumber *)countryID {
    [NYUserDefault setUserCellPhoneCountryID:countryID];
}

- (void)removeCellPhoneNumberFromUserDefaults {
    [NYUserDefault setUserCellPhone:nil];
}

#pragma mark General

- (NSString *)getFacebookCurrentAccessTokenString {
    return [FBSDKAccessToken currentAccessToken].tokenString ?: @"";
}

- (NSString *)getFacebookCurrentAuthTokenString {
    return [FBSDKAuthenticationToken currentAuthenticationToken].tokenString ?: @"";
}

- (void)getFacebookTokenWithCompletionBlock:(void(^)(NSString *token, NSString *authToken, NSError *error))completionblock {
    //Clean state
    [self cleanAllSettingsWithIsLoginAgain:NO];
    
    [[NYFacebookHelper sharedInstance] facebookLoginWithHandler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if(result.isCancelled || error) {
            //失敗或者取消
            completionblock(nil, nil, error);
        }
        else {
            //成功
            completionblock(result.token.tokenString,
                            result.authenticationToken.tokenString,
                            error);
        }
    }];
}

- (void)mergeFavoriteListAndShoppingCartWithCompletionHandler:(void(^)(void))completionHandler
{
    // 1. 合併收藏商品
    // 2. 合併收藏商店
    // 3. ***合併購物車*** （不要懷疑，就是購物車）
    [[NYDataProvider sharedInstance] mergeFavoriteListAndShoppingCartWithCompletionHandler:^(NSDictionary *data, NSError *error) {
        [[NYCartBadgeHelper sharedInstance] updateCartBadgeNumber];
        [[NYFavoriteManager sharedManager] fetchAndMergeFavoriteListCompletion:^(NSArray *list, NSError *error) {
            if (completionHandler) {
                completionHandler();
            }
        }];
    }];
}

#pragma mark 手機註冊

- (void)getRegisterStatusVia91maiWithShopID:(NSNumber *)shopID
                                  cellPhone:(NSString *)cellPhone
                             reCaptchaToken:(NSString *)reCaptchaToken
                                countryCode:(NSString *)countryCode
                                  countryID:(NSNumber *)countryID
                          completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler __deprecated_msg("改用 NYLoginAPIManager.getCellPhoneRegisterStatus") {
    [[NYDataProvider sharedInstance] getRegisterStatusWithShopID:shopID cellPhone:cellPhone reCaptchaToken:reCaptchaToken countryCode:countryCode countryID:countryID completionHandler:completionHandler];
}

- (void)registerVia91maiWithShopID:(NSNumber *)shopID
                         cellPhone:(NSString *)cellPhone
                    reCaptchaToken:(NSString *)reCaptchaToken
                       countryCode:(NSString *)countryCode
                         countryID:(NSNumber *)countryID
                 completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler __deprecated_msg("改用 NYLoginAPIManager.sendOTPCellPhone") {
    [[NYDataProvider sharedInstance] cellPhoneRegisterWithShopID:shopID
                                                       cellPhone:cellPhone
                                                  reCaptchaToken:reCaptchaToken
                                                     countryCode:countryCode
                                                       countryID:countryID
                                               completionHandler:completionHandler];
}

- (void)sendVerifyCodeWithShopID:(NSNumber *)shopID
                       cellPhone:(NSString *)cellPhone
                  reCaptchaToken:(NSString *)reCaptchaToken
                     countryCode:(NSString *)countryCode
                       countryID:(NSNumber *)countryID
                         smsType:(NSString *)smsType
               completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] sendVerifyCodeWithShopID:shopID
                                                    cellPhone:cellPhone
                                               reCaptchaToken:reCaptchaToken
                                                  countryCode:countryCode
                                                    countryID:countryID
                                                      smsType:smsType
                                            completionHandler:completionHandler];
}

- (void)resendVerifyCodeWithShopID:(NSNumber *)shopID
                         cellPhone:(NSString *)cellPhone
                        memberType:(NSString *)memberType
                        verifyType:(NSString *)verifyType
                    reCaptchaToken:(NSString *)reCaptchaToken
                       countryCode:(NSString *)countryCode
                         countryID:(NSNumber *)countryID
                 completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler __deprecated_msg("改用 NYLoginAPIManager.resendVerifyCode") {
    [[NYDataProvider sharedInstance] resendVerifyCodeWithShopID:shopID
                                                      cellPhone:cellPhone
                                                     memberType:memberType
                                                     verifyType:verifyType
                                                        smsType:@""
                                                 reCaptchaToken:reCaptchaToken
                                                    countryCode:countryCode
                                                      countryID:countryID
                                              completionHandler:completionHandler];
}

- (void)resendVerifyCodeUseVoiceWithShopID:(NSNumber *)shopID
                                 cellPhone:(NSString *)cellPhone
                                memberType:(NSString *)memberType
                                verifyType:(NSString *)verifyType
                          countryPhoneCode:(NSString *)countryPhoneCode
                                 countryID:(NSNumber *)countryID
                         completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler __deprecated_msg("改用 NYLoginAPIManager.resendVerifyCodeUseVoice") {
    [[NYDataProvider sharedInstance] resendVerifyCodeUseVoiceWithShopID:shopID
                                                              cellPhone:cellPhone
                                                             memberType:memberType
                                                             verifyType:verifyType
                                                       countryPhoneCode:countryPhoneCode
                                                              countryID:countryID
                                                      completionHandler:completionHandler];
}

- (void)confirmVerifyCodeVia91maiWithShopID:(NSNumber *)shopID
                                  cellPhone:(NSString *)cellPhone
                                       code:(NSString *)code
                                 verifyType:(NSString *)verifyType
                             reCaptchaToken:(NSString *)reCaptchaToken
                                countryCode:(NSString *)countryCode
                                  countryID:(NSNumber *)countryID
                          completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler __deprecated_msg("改用 NYLoginAPIManager.confirmNineyiVerifyCode") {
    [[NYDataProvider sharedInstance] confirmVerifyCodeWithShopID:shopID
                                                       cellPhone:cellPhone
                                                            code:code
                                                      verifyType:verifyType
                                                  reCaptchaToken:reCaptchaToken
                                                     countryCode:countryCode
                                                       countryID:countryID
                                               completionHandler:completionHandler];
}

- (void)finishRegisterVia91maiWithShopID:(NSNumber *)shopID
                               cellPhone:(NSString *)cellPhone
                                password:(NSString *)password
                                  source:(NSString *)source
                                  device:(NSString *)device
                              appVersion:(NSString *)appVersion
                             countryCode:(NSString *)countryCode
                               countryID:(NSNumber *)countryID
                        enableOptInSplit:(BOOL)enableOptInSplit
                                 isOptIn:(NSNumber *)isOptIn
                             isEnableEDM:(NSNumber *)isEnableEDM
                          isEnableEdmSMS:(NSNumber *)isEnableEdmSMS
                        isAppPushProfile:(NSNumber *)isAppPushProfile
                       completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    //Call API (FinishRegister)
    [[NYDataProvider sharedInstance] finishCellPhoneRegisterWithShopID:shopID
                                                             cellPhone:cellPhone
                                                              password:password
                                                                source:source
                                                                device:device
                                                            appVersion:appVersion
                                                           countryCode:countryCode
                                                             countryID:countryID
                                                      enableOptInSplit:enableOptInSplit
                                                               isOptIn:isOptIn
                                                           isEnableEDM:isEnableEDM
                                                        isEnableEdmSMS:isEnableEdmSMS
                                                      isAppPushProfile:isAppPushProfile
                                                     completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];

        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3081"]) { // Check Register 成功
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeNineyiMember
                                           authCookie:auth
                                            cellPhone:cellPhone
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else  {
            completionHandler(data, nil);
        }
    }];
}

- (void)updateCellPhoneWithCellPhone:(NSString *)cellPhone
                         countryCode:(NSString *)countryCode
                           countryID:(NSNumber *)countryID
                    countryAliasCode:(NSString *)countryAliasCode
                   completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    [[NYDataProvider sharedInstance] updateCellPhoneWithCellPhone:cellPhone
                                                 countryAliasCode:countryAliasCode
                                                completionHandler:^(NSDictionary * _Nullable data, NSString * _Nullable auth, NSError * _Nullable error) {
        
        NSString *returnCode = data[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API0001"]) {
            
            if (auth != nil) {
                [[NYCookieManager sharedManager] setCookieValue:auth forCookieName:kCOOKIE_NAME_AUTH];
                [weakSelf saveCellPhoneNumberToUserDefaults:cellPhone];
                [weakSelf saveCellPhoneCountryCodeToUserDefaults:countryCode];
                [weakSelf saveCellPhoneCountryIDToUserDefaults:countryID];
            }
            completionHandler(data, nil);
            
        } else  {
            completionHandler(nil, [NSError errorWithDomain:@"UpdateCellPhone" code:0 userInfo:@{}]);
        }
    }];
}

#pragma mark 手機登入

- (void)loginVia91maiWithShopID:(NSNumber *)shopID
                      cellPhone:(NSString *)cellPhone
                       password:(NSString *)password
                 reCaptchaToken:(NSString *)reCaptchaToken
                         source:(NSString *)source
                         device:(NSString *)device
                     appVersion:(NSString *)appVersion
                    countryCode:(NSString *)countryCode
                      countryId:(NSNumber *)countryId
              completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    //Call API (Login)
    [DS cellPhoneLoginWithShopID:shopID
                       cellPhone:cellPhone
                        password:password
                  reCaptchaToken:reCaptchaToken
                          source:source
                          device:device
                      appVersion:appVersion
                     countryCode:countryCode
                       countryId:countryId
               completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3091"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeNineyiMember
                                           authCookie:auth
                                            cellPhone:cellPhone
                                          countryCode:countryCode
                                            countryID:countryId
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark 國家清單

- (void)getCountryListWithShopID:(NSNumber *)shopID
               completionHandler:(void(^)(NSArray *list, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] getCountryListWithShopID:shopID CompletionHandler:^(NSDictionary * _Nullable JSON, NSError * _Nullable error) {
        completionHandler(JSON[@"Data"], nil);
    }];
}

#pragma mark Line Login 註冊

- (void)getLineMemberRegisterStatusWithShopId:(NSNumber *)shopId
                                  accessToken:(NSString *)accessToken
                            completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] getLineMemberRegisterStatusWithShopId:shopId accessToken:accessToken completionHandler:completionHandler];
}

- (void)createLineMemberRegisterRequestWithShopId:(NSNumber *)shopId
                                        cellPhone:(NSString *)cellPhone
                                      accessToken:(NSString *)accessToken
                                      countryCode:(NSString *)countryCode
                                        countryId:(NSNumber *)countryId
                                completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] createLineMemberRegisterRequestWithShopId:shopId
                                                                     cellPhone:cellPhone
                                                                   accessToken:accessToken
                                                                   countryCode:countryCode
                                                                     countryId:countryId
                                                             completionHandler:completionHandler];
}

- (void)confirmLineVerifyCodeWithCellPhone:(NSString *)cellPhone
                                      code:(NSString *)code
                               countryCode:(NSString *)countryCode
                                 countryId:(NSNumber *)countryId
                                   isOptIn:(NSNumber *)isOptIn
                         completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    [[NYDataProvider sharedInstance] confirmLineMemberVerifyCodeWithCellPhone:cellPhone
                                                                         code:code
                                                                  countryCode:countryCode
                                                                    countryId:countryId
                                                                      isOptIn:isOptIn
                                                            completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        if (error) {
            completionHandler(nil, error);
        } else {
            NSDictionary *responseDict = data[kDATA_KEY];
            NSString *returnCode = responseDict[@"ReturnCode"];
            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILineMemberConfirmVerifyCodeCodeSuccess]) {
                [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeLineLogin
                                               authCookie:auth
                                                cellPhone:nil
                                              countryCode:countryCode
                                                countryID:countryId
                                        completionHandler:^{
                    completionHandler(data, nil);
                }];
            } else {
                completionHandler(data, nil);
            }
        }
    }];
}

#pragma mark Line Login 登入

- (void)loginViaLineWithToken:(NSString *)token
            completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] loginLineMemberWithAccessToken:token
                                                  completionHandler:^(NSDictionary *dataDict, NSString *auth, NSError *error) {
        if (error) {
            completionHandler(nil, error);
        } else {
            NSDictionary *responseDict = dataDict[kDATA_KEY];
            NSString *returnCode = responseDict[@"ReturnCode"];
            
            if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPILoginLineMemberSuccessed]) {
                [self handleLoginSuccessWithLoginType:NYUserLoginTypeLineLogin
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:nil
                                            countryID:nil
                                    completionHandler:^{
                    completionHandler(dataDict, nil);
                }];
            } else {
                completionHandler(dataDict, nil);
            }
        }
    }];
}

#pragma mark FB註冊

- (void)getRegisterStatusViaFacebookWithShopID:(NSNumber *)shopID
                                   accessToken:(NSString *)accessToken
                                     authToken:(NSString *)authToken
                             completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] getFBRegisterStatusWithShopID:shopID
                                                       accessToken:accessToken
                                                         authToken:authToken
                                                 completionHandler:completionHandler];
}

- (void)registerViaFacebookWithShopID:(NSNumber *)shopID
                            cellPhone:(NSString *)cellPhone
                          accessToken:(NSString *)accessToken
                            authToken:(NSString *)authToken
                          countryCode:(NSString *)countryCode
                            countryID:(NSNumber *)countryID
                    completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] fbRegisterWithShopID:shopID
                                                cellPhone:cellPhone
                                              accessToken:accessToken
                                                authToken:authToken
                                              countryCode:countryCode
                                                countryID:countryID
                                        completionHandler:completionHandler];
}

- (void)confirmVerifyCodeViaFacebookWithShopID:(NSNumber *)shopID
                                   accessToken:(NSString *)accessToken
                                     authToken:(NSString *)authToken
                                     cellPhone:(NSString *)cellPhone
                                          code:(NSString *)code
                                        source:(NSString *)source
                                        device:(NSString *)device
                                    appVersion:(NSString *)appVersion
                                   countryCode:(NSString *)countryCode
                                     countryID:(NSNumber *)countryID
                              enableOptInSplit:(BOOL)enableOptInSplit
                                       isOptIn:(NSNumber *)isOptIn
                                   isEnableEDM:(NSNumber *)isEnableEDM
                                isEnableEdmSMS:(NSNumber *)isEnableEdmSMS
                              isAppPushProfile:(NSNumber *)isAppPushProfile
                             completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    //Call API (FBConfirmVerifyCode)
    [[NYDataProvider sharedInstance] fbConfirmVerifyCodeWithShopID:shopID
                                                       accessToken:accessToken
                                                         authToken:authToken
                                                         cellPhone:cellPhone
                                                              code:code
                                                            source:source
                                                            device:device
                                                        appVersion:appVersion
                                                       countryCode:countryCode
                                                         countryID:countryID
                                                  enableOptInSplit:enableOptInSplit
                                                           isOptIn:isOptIn
                                                       isEnableEDM:isEnableEDM
                                                    isEnableEdmSMS:isEnableEdmSMS
                                                  isAppPushProfile:isAppPushProfile
                                                 completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3121"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeFacebook
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark FB登入

- (void)loginViaFacebookWithShopID:(NSNumber *)shopID
                             token:(NSString *)token
                         authToken:(NSString *)authToken
                            source:(NSString *)source
                            device:(NSString *)device
                        appVersion:(NSString *)appVersion
                       countryCode:(NSString *)countryCode
                         countryID:(NSNumber *)countryID
                 completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    //Call API (FBLogin)
    [DS fbLoginWithShopID:shopID accessToken:token authToken:authToken source:source device:device appVersion:appVersion completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3141"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeFacebook
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark 忘記密碼

- (void)resetPasswordVia91maiWithShopID:(NSNumber *)shopID
                              cellPhone:(NSString *)cellPhone
                         reCaptchaToken:(NSString *)reCaptchaToken
                            countryCode:(NSString *)countryCode
                              countryID:(NSNumber *)countryID
                      completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] resetPasswordWithShopID:shopID
                                                   cellPhone:cellPhone
                                              reCaptchaToken:reCaptchaToken
                                                 countryCode:countryCode
                                                   countryID:countryID
                                           completionHandler:completionHandler];
}

- (void)finishResetPasswordVia91maiWithShopID:(NSNumber *)shopID
                                    cellPhone:(NSString *)cellPhone
                                     password:(NSString *)password
                                       source:(NSString *)source
                                       device:(NSString *)device
                                   appVersion:(NSString *)appVersion
                                  countryCode:(NSString *)countryCode
                                    countryID:(NSNumber *)countryID
                            completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    //Call API (FinishResetPassword)
    [[NYDataProvider sharedInstance] finishResetPasswordWithShopID:shopID
                                                         cellPhone:cellPhone
                                                          password:password
                                                            source:source
                                                            device:device
                                                        appVersion:appVersion
                                                       countryCode:countryCode
                                                         countryID:countryID
                                                 completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3161"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeNineyiMember
                                           authCookie:auth
                                            cellPhone:cellPhone
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark Apple Sign In Registration Flow
- (void)appleLoginWithAuthCode:(NSString *)authCode
                         email:(NSString *)email
             completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    
    /// API 設計文件 https://docs.google.com/document/d/1UgNCU70YzplOhkheFcljgaoEmx5O209v_J79Lo4JvJU/
    [[NYDataProvider sharedInstance] appleIdLoginOrRegisterWithAuthCode:authCode email:email completionHandler:^(NSDictionary * _Nullable dataDict, NSString * _Nullable auth, NSError * _Nullable error) {
        __weak typeof(self) weakSelf = self;
        
        NSDictionary *responseDict = dataDict[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIAppleSignInSuccess]) {
            [weakSelf socialLoginSuccessWithLoginType:NYUserLoginTypeAppleSignIn
                                           authCookie:auth
                                         responseDict:dataDict
                                    completionHandler:^{
                completionHandler(dataDict, nil);
            }];
        } else {
            completionHandler(dataDict, nil);
        }
    }];
}

#pragma mark 修改密碼
- (void)changePasswordVia91maiWithShopID:(NSNumber *)shopID
                             oldPassword:(NSString *)oldPassword
                             newPassword:(NSString *)newPassword
                       completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] changePasswordWithShopID:shopID oldPassword:oldPassword newPassword:newPassword completionHandler:completionHandler];
}

#pragma mark 商店第三方登入
- (void)getThirdpartyMemberRegisterStatusWithLoginId:(NSString *)loginId
                                            password:(NSString *)password
                                              shopId:(NSNumber *)shopId
                                         countryCode:(NSString *)countryCode
                                           countryID:(NSNumber *)countryID
                                   completionHandler:(void (^)(NSDictionary *data, NSError *error))completionHandler {
    
    [[NYDataProvider sharedInstance] getThirdpartyMemberRegisterStatusWithLoginId:loginId password:password shopId:shopId completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        __weak typeof(self) weakSelf = self;
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];

        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3201"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeThirdPartyAuth
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

- (void)createThirdpartyMemberRegisterRequestWithToken:(NSString *)token
                                             cellPhone:(NSString *)cellPhone
                                                shopId:(NSNumber *)shopId
                                           countryCode:(NSString *)countryCode
                                             countryID:(NSNumber *)countryID
                                     completionHandler:(void (^)(NSDictionary *data, NSError *error))completionHandler {
    [[NYDataProvider sharedInstance] createThirdpartyMemberRegisterRequestWithToken:token
                                                                          cellPhone:cellPhone
                                                                             shopId:shopId
                                                                        countryCode:countryCode
                                                                          countryID:countryID
                                                                  completionHandler:completionHandler];
}

- (void)confirmThirdpartyMemberVerifyCodeWithCellPhone:(NSString *)cellPhone
                                                shopId:(NSNumber *)shopId
                                                  code:(NSString *)code
                                                 token:(NSString *)token
                                                source:(NSString *)source
                                                device:(NSString *)device
                                            appVersion:(NSString *)appVersion
                                           countryCode:(NSString *)countryCode
                                             countryID:(NSNumber *)countryID
                                               isOptIn:(NSNumber *)isOptIn
                                     completionHandler:(void (^)(NSDictionary *, NSError *))completionHandler {
    __weak typeof(self) weakSelf = self;
    [[NYDataProvider sharedInstance] confirmThirdpartyMemberVerifyCodeWithCellPhone:cellPhone
                                                                             shopId:shopId
                                                                               code:code
                                                                              token:token
                                                                             source:source
                                                                             device:device
                                                                         appVersion:appVersion
                                                                        countryCode:countryCode
                                                                          countryID:countryID
                                                                            isOptIn:isOptIn
                                                                  completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3221"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeThirdPartyAuth
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark - OAuth登入

- (void)loginThirdpartyMemberWithAuthSessionToken:(NSString *)authSessionToken
                                           shopId:(NSNumber *)shopId
                                           source:(NSString *)source
                                           device:(NSString *)device
                                       appVersion:(NSString *)appVersion
                                      countryCode:(NSString *)countryCode
                                        countryID:(NSNumber *)countryID
                                completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    [[NYDataProvider sharedInstance] loginThirdpartyMemberWithAuthSessionToken:authSessionToken shopId:shopId source:source device:device appVersion:appVersion completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:@"API3251"]) {
            [weakSelf handleLoginSuccessWithLoginType:NYUserLoginTypeThirdPartyAuth
                                           authCookie:auth
                                            cellPhone:nil
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark 設定密碼
- (void)bindingCellPhoneSetPasswordWithShopID:(NSNumber *)shopID
                                    cellPhone:(NSString *)cellPhone
                                     password:(NSString *)password
                                       source:(NSString *)source
                                       device:(NSString *)device
                                   appVersion:(NSString *)appVersion
                                  countryCode:(NSString *)countryCode
                                    countryID:(NSNumber *)countryID
                                   verifyType:(NSString *)verifyType
                            completionHandler:(void(^)(NSDictionary *data, NSError *error))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    [[NYDataProvider sharedInstance] setPasswordWithShopID:shopID
                                                 cellPhone:cellPhone
                                                  password:password
                                                    source:source
                                                    device:device
                                                appVersion:appVersion
                                               countryCode:countryCode
                                                 countryID:countryID
                                                verifyType:verifyType
                                         completionHandler:^(NSDictionary *data, NSString *auth, NSError *error) {
        NSDictionary *responseDict = data[kDATA_KEY];
        NSString *returnCode = responseDict[@"ReturnCode"];
        
        if (error) {
            completionHandler(nil, error);
        } else if ([returnCode isEqualToString:NYLoginReturnCodes.kNYAPIFinishRegisterCodeSuccess]) {
            [weakSelf handleLoginSuccessWithLoginType:[weakSelf userLoginType]
                                           authCookie:auth
                                            cellPhone:cellPhone
                                          countryCode:countryCode
                                            countryID:countryID
                                    completionHandler:^{
                completionHandler(data, nil);
            }];
        } else  {
            completionHandler(data, nil);
        }
    }];
}

#pragma mark Public Helper

/// 非手機登入 update auth cookie/cell phone/country code/country id
- (void)socialLoginSuccessWithLoginType:(NYUserLoginType)loginType
                             authCookie:(NSString *)authCookie
                           responseDict:(NSDictionary *)responseDict
                      completionHandler:(void (^)(void))completionHandler {
    NSDictionary *memberDict = responseDict[kDATA_KEY][@"Data"][@"Member"];
    NSString *cellPhone = memberDict[@"CellPhone"] ?: nil;
    NSString *countryCode = memberDict[@"CountryCode"] ?: nil;
    NSNumber *countryID = memberDict[@"CountryProfileId"] ?: nil;
    
    [self handleLoginSuccessWithLoginType:loginType
                               authCookie:authCookie
                                cellPhone:cellPhone
                              countryCode:countryCode
                                countryID:countryID
                        completionHandler:completionHandler];
}

/// 驗證碼登入成功
- (void)expressLoginFinishWithAuthCookie:(NSString *)authCookie
                               cellPhone:(NSString *)cellPhone
                             countryCode:(NSString *)countryCode
                               countryID:(NSNumber *)countryID
                       completionHandler:(void (^)(void))completionHandler {
    [self handleLoginSuccessWithLoginType:NYUserLoginTypeNineyiMember
                               authCookie:authCookie
                                cellPhone:cellPhone
                              countryCode:countryCode
                                countryID:countryID
                        completionHandler:completionHandler];
}

@end
//
//  NYTrackingClient.m
//  Pods
//
//  Created by Eric Huang on 2018/3/14.
//

#import "NYTrackingClient.h"
#import "NYBaseURLConfig.h"
#import "NYGlobalData.h"
#import <sys/utsname.h>

#import <WebKit/WebKit.h>
#import <NYCore/NYCore-Swift.h>

@interface NYTrackingClient ()

@property (nonatomic, strong) NSString *userAgent;

@end

@implementation NYTrackingClient

+ (NYTrackingClient *)sharedClient {
    static NYTrackingClient *_sharedClient = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[NYTrackingClient alloc] initWithBaseURL:[NYBaseURLConfig baseHTTPSURLWith91AnalyticsDomain]];
        _sharedClient.userAgent = WKWebView.userAgent;
    });
    return _sharedClient;
}

- (NSURLSessionDataTask *)addOperationWithRequestType:(NYHTTPRequestType)requestType
                                         responseType:(NYHTTPResponseType)responseType
                                               method:(NSString *)method
                                                 path:(NSString *)path
                                           parameters:(NSDictionary *)parameters
                                isSynchrounousRequest:(BOOL)isSynchrounousRequest
                                              success:(void (^)(NSURLSessionDataTask *, id))success
                                              failure:(void (^)(NSURLSessionDataTask *, id))failure {
    
    NSMutableDictionary *mutableParameters = [parameters mutableCopy];
    if ([super shouldAppendAppVerToURL:self.baseURL]) {
        NSDictionary *appVerParameter = @{@"appVer" : [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]};
        if (!mutableParameters) {
            mutableParameters = [appVerParameter mutableCopy];
        }
        else {
            [mutableParameters setValuesForKeysWithDictionary:appVerParameter];
        }
    }
    
    NSMutableURLRequest *request = [self requestWithType:requestType method:method path:path parameters:mutableParameters];
    request.HTTPShouldHandleCookies = YES;
    
    struct utsname systemInfo;
    uname(&systemInfo);
   
    NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString *userAppInfo = [NSString stringWithFormat:@" %@/%@ %@", [NYGlobalData bundleId], [NYGlobalData appVersionString], deviceModel];
    NSString *headerValue = [self.userAgent stringByAppendingString:userAppInfo];
    
    [request setValue:headerValue forHTTPHeaderField:@"User-Agent"];
    
    self.responseSerializer = [super responseSerializerWithType:responseType];
    
    if ([NYBaseURLConfig isTestEnvironment]) {
        self.securityPolicy.allowInvalidCertificates = YES;
        self.securityPolicy.validatesDomainName = NO;
    }
    
    dispatch_semaphore_t semaphore;
    if (isSynchrounousRequest) {
        semaphore = dispatch_semaphore_create(0);
    }
    
    __block NSURLSessionDataTask *dataTask = nil;
    dataTask = [self dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (error) {
            if (failure) {
                failure(dataTask, error);
            }
        } else {
            if (success) {
                success(dataTask, responseObject);
            }
        }
        
        if (isSynchrounousRequest) {
            dispatch_semaphore_signal(semaphore);
        }
    }];
    
    [dataTask resume];
    
    if (isSynchrounousRequest) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    
    return dataTask;
}

@end
