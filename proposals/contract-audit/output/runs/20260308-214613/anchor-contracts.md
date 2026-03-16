## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

| # | 類別 | 模式 | 命中次數 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | dispatch_semaphore_create | 1 | NYHTTPSClient.m:606 |
| 2 | S | dispatch_semaphore_wait | 1 | NYHTTPSClient.m:650 |
| 3 | S | dispatch_semaphore_signal | 1 | NYHTTPSClient.m:642 |
| 4 | S | dispatch_once | 1 | NYHTTPSClient.m:61 |
| 5 | S | DISPATCH_TIME_FOREVER | 1 | NYHTTPSClient.m:650 |
| 6 | N | postNotificationName | 2 | NYHTTPSClient.m:747 |
| 7 | D | sharedInstance | 1 | NYHTTPSClient.m:635 |
| 8 | D | protocol_decl | 1 | NYHTTPSClient.h:28 |
| 9 | D | category_interface | 1 | NYHTTPSClient.m:30 |
| 10 | E | NSError_param | 13 | NYHTTPSClient.m:235 |
| 11 | E | errorWithDomain | 9 | NYHTTPSClient.m:309 |
| 12 | C | cancel_operation | 1 | NYHTTPSClient.m:460 |

共 12 個錨點命中。
