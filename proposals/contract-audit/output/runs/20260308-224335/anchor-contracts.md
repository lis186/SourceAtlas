## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | dispatch_semaphore_create | 1 | NYHTTPSClient.m:606 |
| 2 | S | dispatch_semaphore_wait | 1 | NYHTTPSClient.m:650 |
| 3 | S | dispatch_semaphore_signal | 1 | NYHTTPSClient.m:642 |
| 4 | S | dispatch_queue_create | 1 | NYCookieManager.m:421 |
| 5 | S | dispatch_barrier | 1 | NYCookieManager.m:421 |
| 6 | S | dispatch_once | 2 | NYHTTPSClient.m:61 |
| 7 | S | DISPATCH_TIME_FOREVER | 1 | NYHTTPSClient.m:650 |
| 8 | N | postNotificationName | 2 | NYHTTPSClient.m:747 |
| 9 | N | defaultCenter | 2 | NYHTTPSClient.m:747 |
| 10 | N | completionHandler | 9 | NYHTTPSClient.m:610 |
| 11 | N | success_failure_block | 101 ⚠️ pervasive | NYHTTPSClient.m:172 |
| 12 | D | sharedInstance | 5 | NYHTTPSClient.m:635 |
| 13 | D | shared_dot | 3 | NYDeviceToken+DI.swift:23 |
| 14 | D | protocol_decl | 1 | NYHTTPSClient.h:28 |
| 15 | D | ifdef_feature | 1 | NYCookieManager.m:249 |
| 16 | D | category_interface | 2 | NYHTTPSClient.m:30 |
| 17 | E | NSError_param | 14 | NYHTTPSClient.m:235 |
| 18 | E | errorWithDomain | 11 | NYHTTPSClient.m:309 |
| 19 | C | cancel_operation | 1 | NYHTTPSClient.m:460 |

共 19 個錨點命中。
