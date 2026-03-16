## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | dispatch_semaphore_create | 2 | NYHTTPSClient.m:606 |
| 2 | S | dispatch_semaphore_wait | 2 | NYHTTPSClient.m:650 |
| 3 | S | dispatch_semaphore_signal | 2 | NYHTTPSClient.m:642 |
| 4 | S | dispatch_async | 1 | NYDataProvider.m:2511 |
| 5 | S | dispatch_queue_create | 1 | NYCookieManager.m:421 |
| 6 | S | dispatch_barrier | 1 | NYCookieManager.m:421 |
| 7 | S | dispatch_once | 6 | NYHTTPSClient.m:61 |
| 8 | S | DISPATCH_TIME_FOREVER | 2 | NYHTTPSClient.m:650 |
| 9 | S | dispatch_group | 5 | NYCartSecondVC.m:561 |
| 10 | N | postNotificationName | 3 | NYHTTPSClient.m:747 |
| 11 | N | delegate_property | 12 | NYCartSecondVC.m:250 |
| 12 | N | defaultCenter | 3 | NYHTTPSClient.m:747 |
| 13 | N | completionHandler | 288 ⚠️ pervasive | NYHTTPSClient.m:610 |
| 14 | N | success_failure_block | 600 ⚠️ pervasive | NYHTTPSClient.m:172 |
| 15 | L | viewDidLoad | 2 | NYCartSecondVC.m:85 |
| 16 | L | viewWillAppear | 2 | NYCartSecondVC.m:101 |
| 17 | L | viewDidAppear | 2 | NYCartSecondVC.m:106 |
| 18 | D | sharedInstance | 60 ⚠️ pervasive | NYHTTPSClient.m:635 |
| 19 | D | shared_dot | 65 ⚠️ pervasive | NYAppDelegateHelper.m:52 |
| 20 | D | protocol_decl | 1 | NYHTTPSClient.h:28 |
| 21 | D | ifdef_feature | 1 | NYCookieManager.m:249 |
| 22 | D | category_interface | 8 | NYHTTPSClient.m:30 |
| 23 | E | NSError_param | 17 | NYHTTPSClient.m:235 |
| 24 | E | errorWithDomain | 15 | NYHTTPSClient.m:309 |
| 25 | C | cancel_operation | 1 | NYHTTPSClient.m:460 |

共 25 個錨點命中。
