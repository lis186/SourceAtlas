## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | dispatch_semaphore_create | 2 | NYHTTPSClient.m:606 |
| 2 | S | dispatch_semaphore_wait | 2 | NYHTTPSClient.m:650 |
| 3 | S | dispatch_semaphore_signal | 2 | NYHTTPSClient.m:642 |
| 4 | S | dispatch_queue_create | 1 | NYCookieManager.m:421 |
| 5 | S | dispatch_barrier | 1 | NYCookieManager.m:421 |
| 6 | S | dispatch_once | 4 | NYHTTPSClient.m:61 |
| 7 | S | DISPATCH_TIME_FOREVER | 2 | NYHTTPSClient.m:650 |
| 8 | N | postNotificationName | 3 | NYHTTPSClient.m:747 |
| 9 | N | defaultCenter | 3 | NYHTTPSClient.m:747 |
| 10 | N | completionHandler | 74 ⚠️ pervasive | NYHTTPSClient.m:610 |
| 11 | N | success_failure_block | 87 ⚠️ pervasive | NYHTTPSClient.m:172 |
| 12 | D | sharedInstance | 34 ⚠️ pervasive | NYHTTPSClient.m:635 |
| 13 | D | protocol_decl | 1 | NYHTTPSClient.h:28 |
| 14 | D | ifdef_feature | 1 | NYCookieManager.m:249 |
| 15 | D | category_interface | 3 | NYHTTPSClient.m:30 |
| 16 | E | NSError_param | 14 | NYHTTPSClient.m:235 |
| 17 | E | errorWithDomain | 12 | NYHTTPSClient.m:309 |
| 18 | C | cancel_operation | 1 | NYHTTPSClient.m:460 |

共 18 個錨點命中。
