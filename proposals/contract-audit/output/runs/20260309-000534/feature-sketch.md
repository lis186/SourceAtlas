## Feature Sketch（Step 0.8）

| # | 方法 | 行號 | 引用屬性 |
|---|------|------|---------|
| 1 | `- (AFHTTPRequestSerializer *)requestSerializerWithType:(NYHTTPRequestType)type;` | NYHTTPSClient.m:31 |  |
| 2 | `- (AFHTTPResponseSerializer *)responseSerializerWithType:(NYHTTPResponseType)typ` | NYHTTPSClient.m:32 |  |
| 3 | `- (BOOL)shouldAppendAppVerToURL:(NSURL *)url;` | NYHTTPSClient.m:34 |  |
| 4 | `- (void)recordApiInfo:(NSString *)path parameters:(NSDictionary *)parameter meth` | NYHTTPSClient.m:37 |  |
| 5 | `+ (void)initLogFile;` | NYHTTPSClient.m:39 |  |
| 6 | `+ (NSString *)logFilePath;` | NYHTTPSClient.m:40 | _logLevel |
| 7 | `+ (NYHTTPClientLogLevel)logLevel {` | NYHTTPSClient.m:47 | _logLevel |
| 8 | `+ (void)setLogLevel:(NYHTTPClientLogLevel)logLevel {` | NYHTTPSClient.m:51 | _logLevel |
| 9 | `+ (NYHTTPSClient *)sharedClient {` | NYHTTPSClient.m:58 | _once,_once_t,_sharedClient |
| 10 | `- (id)initWithBaseURL:(NSURL *)url {` | NYHTTPSClient.m:70 |  |
| 11 | `- (NSMutableURLRequest *)requestWithType:(NYHTTPRequestType)type method:(NSStrin` | NYHTTPSClient.m:78 | _block,self.baseURL,self.name |
| 12 | `- (NSMutableURLRequest *)httpRequestWithMethod:(NSString *)method path:(NSString` | NYHTTPSClient.m:160 |  |
| 13 | `- (NSMutableURLRequest *)jsonRequestWithMethod:(NSString *)method path:(NSString` | NYHTTPSClient.m:164 |  |
| 14 | `- (void)syncGetPath:(NSString *)path` | NYHTTPSClient.m:170 |  |
| 15 | `- (void)syncGetPath:(NSString *)path` | NYHTTPSClient.m:177 |  |
| 16 | `- (AnyPromise *)getPath:(NSString *)path parameters:(NSDictionary *)parameters {` | NYHTTPSClient.m:194 |  |
| 17 | `- (NSURLSessionDataTask *)getPath:(NSString *)path` | NYHTTPSClient.m:205 |  |
| 18 | `- (NSURLSessionDataTask *)getPath:(NSString *)path` | NYHTTPSClient.m:212 |  |
| 19 | `- (void)syncPostPath:(NSString *)path` | NYHTTPSClient.m:223 |  |
| 20 | `- (void)syncPostPath:(NSString *)path` | NYHTTPSClient.m:230 |  |
| 21 | `- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters ` | NYHTTPSClient.m:247 |  |
| 22 | `- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters ` | NYHTTPSClient.m:258 |  |
| 23 | `- (NSURLSessionDataTask *)postPath:(NSString *)path` | NYHTTPSClient.m:268 |  |
| 24 | `- (NSURLSessionDataTask *)postPath:(NSString *)path` | NYHTTPSClient.m:275 |  |
| 25 | `- (NSURLSessionDataTask *)postPath:(NSString *)path` | NYHTTPSClient.m:284 |  |
| 26 | `- (void)postPath:(NSString *)path dataStr:(NSString *)dataStr   //For RegistAPP` | NYHTTPSClient.m:301 |  |
| 27 | `- (void)postPathForEncryptData:(NSString *)path` | NYHTTPSClient.m:357 |  |
| 28 | `- (void)postPathForECoupon:(NSString *)path` | NYHTTPSClient.m:412 |  |
| 29 | `- (void)cancelAllHTTPOperationsWithMethod:(NSString *)method` | NYHTTPSClient.m:443 | self.baseURL,self.operationQueue |
| 30 | `- (NSString *)timestamp {` | NYHTTPSClient.m:465 | _timestamp |
| 31 | `- (void)logMismatchShopID:(NSString *)responseShopID urlString:(NSString *)urlSt` | NYHTTPSClient.m:479 | self.logger |
| 32 | `- (AFHTTPRequestSerializer *)requestSerializerWithType:(NYHTTPRequestType)type {` | NYHTTPSClient.m:491 |  |
| 33 | `- (AFHTTPResponseSerializer *)responseSerializerWithType:(NYHTTPResponseType)typ` | NYHTTPSClient.m:514 |  |
| 34 | `- (NSURLSessionDataTask *)addOperationWithRequestType:(NYHTTPRequestType)request` | NYHTTPSClient.m:530 |  |
| 35 | `- (NSURLSessionDataTask *)addOperationWithRequestType:(NYHTTPRequestType)request` | NYHTTPSClient.m:549 |  |
| 36 | `- (NSURLSessionDataTask *)addOperationWithRequestType:(NYHTTPRequestType)request` | NYHTTPSClient.m:569 | _block,_semaphore_create,_semaphore_signal,_semaphore_t,_semaphore_wait,self.baseURL,self.responseSerializer,self.securityPolicy |
| 37 | `- (BOOL)shouldAppendAppVerToURL:(NSURL *)url {` | NYHTTPSClient.m:656 | self.baseURL |
| 38 | `- (BOOL)logoutWithURL:(NSURL *)url` | NYHTTPSClient.m:677 |  |
| 39 | `- (void)recordApiInfo:(NSString *)path parameters:(NSDictionary *)parameters met` | NYHTTPSClient.m:699 | _logLevel,self.baseURL |
| 40 | `+ (NSString *)logFilePath {` | NYHTTPSClient.m:732 |  |
| 41 | `+ (void)initLogFile {` | NYHTTPSClient.m:738 |  |
| 42 | `- (void)notifyRequestWithTask:(NSURLSessionTask * _Nullable)task {` | NYHTTPSClient.m:745 |  |
| 43 | `- (void)notifyResponseWithTask:(NSURLSessionTask * _Nullable)task` | NYHTTPSClient.m:752 |  |
| 1 | `- (void)recordError:(NSError *)error NS_SWIFT_NAME(record(error:));` | NYHTTPSClient.h:30 |  |
| 2 | `+ (NYHTTPClientLogLevel)logLevel;` | NYHTTPSClient.h:40 |  |
| 3 | `+ (void)setLogLevel:(NYHTTPClientLogLevel)logLevel;` | NYHTTPSClient.h:41 |  |
| 4 | `+(NYHTTPSClient *)sharedClient;` | NYHTTPSClient.h:43 |  |
| 5 | `- (NSMutableURLRequest *)requestWithType:(NYHTTPRequestType)type method:(NSStrin` | NYHTTPSClient.h:45 |  |
| 6 | `- (NSMutableURLRequest *)httpRequestWithMethod:(NSString *)method path:(NSString` | NYHTTPSClient.h:46 |  |
| 7 | `- (NSMutableURLRequest *)jsonRequestWithMethod:(NSString *)method path:(NSString` | NYHTTPSClient.h:47 |  |
| 8 | `- (void)syncGetPath:(NSString *)path` | NYHTTPSClient.h:49 |  |
| 9 | `- (void)syncGetPath:(NSString *)path` | NYHTTPSClient.h:54 |  |
| 10 | `- (AnyPromise *)getPath:(NSString *)path parameters:(NSDictionary *)parameters;` | NYHTTPSClient.h:61 |  |
| 11 | `- (NSURLSessionDataTask *)getPath:(NSString *)path` | NYHTTPSClient.h:63 |  |
| 12 | `- (NSURLSessionDataTask *)getPath:(NSString *)path` | NYHTTPSClient.h:68 |  |
| 13 | `- (void)syncPostPath:(NSString *)path` | NYHTTPSClient.h:75 |  |
| 14 | `- (void)syncPostPath:(NSString *)path` | NYHTTPSClient.h:80 |  |
| 15 | `- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters;` | NYHTTPSClient.h:87 |  |
| 16 | `- (AnyPromise *)postPath:(NSString *)path parameters:(NSDictionary *)parameters ` | NYHTTPSClient.h:89 |  |
| 17 | `- (NSURLSessionDataTask *)postPath:(NSString *)path` | NYHTTPSClient.h:91 |  |
| 18 | `- (NSURLSessionDataTask *)postPath:(NSString *)path` | NYHTTPSClient.h:96 |  |
| 19 | `- (NSURLSessionDataTask *)postPath:(NSString *)path` | NYHTTPSClient.h:103 |  |
| 20 | `- (void)postPathForECoupon:(NSString *)path` | NYHTTPSClient.h:111 |  |
| 21 | `- (void)postPathForEncryptData:(NSString *)path` | NYHTTPSClient.h:116 |  |
| 22 | `- (void)postPath:(NSString *)path dataStr:(NSString *)dataStr` | NYHTTPSClient.h:121 |  |
| 23 | `- (void)cancelAllHTTPOperationsWithMethod:(NSString *)method` | NYHTTPSClient.h:126 |  |
| 24 | `- (NSString *)timestamp;` | NYHTTPSClient.h:129 |  |
| 25 | `- (AFHTTPRequestSerializer *)requestSerializerWithType:(NYHTTPRequestType)type;` | NYHTTPSClient.h:132 |  |
| 26 | `- (AFHTTPResponseSerializer *)responseSerializerWithType:(NYHTTPResponseType)typ` | NYHTTPSClient.h:133 |  |
| 27 | `- (BOOL)shouldAppendAppVerToURL:(NSURL *)url;` | NYHTTPSClient.h:134 |  |

共 70 個方法。
