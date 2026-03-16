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
- /Users/justinlee/dev/nineyiappshop/clip-extension/ManuallyAddedLibs/MBProgressHUD/MBProgressHUD.m
- /Users/justinlee/dev/nineyiappshop/NineyiAppShop/NYDeviceToken+DI.swift
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYCDNHTTPClient.h
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYCookieManager.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYDataProvider+Search.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYECouponHTTPSClient.h
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYFacebookGraphAPIClient.h
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NineyiAppApi/NYTrackingClient.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NYLoginViewController/NYLoginChangePasswordVC.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NYLoginViewController/NYLoginVCInfo.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NYLoginViewController/NYLoginViewController.m
- /Users/justinlee/dev/nineyiappshop/NYCore/NYCore/Classes/ObjC/NYLoginViewController/NYThirdPartyLoginWebBrowserVC.m
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
