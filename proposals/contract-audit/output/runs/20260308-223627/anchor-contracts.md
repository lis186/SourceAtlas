## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | dispatch_semaphore_create | 2 | NYHTTPSClient.m:606 |
| 2 | S | dispatch_semaphore_wait | 2 | NYHTTPSClient.m:650 |
| 3 | S | dispatch_semaphore_signal | 2 | NYHTTPSClient.m:642 |
| 4 | S | dispatch_async | 2 | NYLoginViewController.m:154 |
| 5 | S | dispatch_queue_create | 2 | NYCookieManager.m:421 |
| 6 | S | dispatch_barrier | 1 | NYCookieManager.m:421 |
| 7 | S | dispatch_once | 4 | NYHTTPSClient.m:61 |
| 8 | S | DISPATCH_TIME_FOREVER | 2 | NYHTTPSClient.m:650 |
| 9 | S | dispatch_after | 3 | NYLoginChangePasswordVC.m:361 |
| 10 | S | dispatch_group | 9 | NYLoginViewController.m:147 |
| 11 | N | postNotificationName | 5 | NYHTTPSClient.m:747 |
| 12 | N | addObserver_selector | 5 | MBProgressHUD.m:745 |
| 13 | N | addObserver_forKeyPath | 3 | NYLoginViewController.m:812 |
| 14 | N | removeObserver | 6 | MBProgressHUD.m:753 |
| 15 | N | respondsToSelector | 4 | MBProgressHUD.m:294 |
| 16 | N | delegate_property | 7 | MBProgressHUD.m:293 |
| 17 | N | defaultCenter | 15 | NYHTTPSClient.m:747 |
| 18 | N | performSelector | 2 | MBProgressHUD.m:295 |
| 19 | N | completionHandler | 44 | NYHTTPSClient.m:610 |
| 20 | N | success_failure_block | 103 | NYHTTPSClient.m:172 |
| 21 | L | viewDidLoad | 6 | NYLoginChangePasswordVC.m:89 |
| 22 | L | viewWillAppear | 7 | NYLoginChangePasswordVC.m:114 |
| 23 | L | viewDidAppear | 2 | NYLoginViewController.m:476 |
| 24 | L | viewWillDisappear | 2 | NYThirdPartyLoginWebBrowserVC.m:115 |
| 25 | L | viewDidDisappear | 1 | NYLoginViewController.m:489 |
| 26 | L | performSelector_afterDelay | 5 | MBProgressHUD.m:167 |
| 27 | D | sharedInstance | 45 | NYHTTPSClient.m:635 |
| 28 | D | shared_dot | 3 | NYDeviceToken+DI.swift:23 |
| 29 | D | protocol_decl | 1 | NYHTTPSClient.h:28 |
| 30 | D | ifdef_feature | 1 | NYCookieManager.m:249 |
| 31 | D | if_conditional | 10 | MBProgressHUD.m:375 |
| 32 | D | category_interface | 9 | NYHTTPSClient.m:30 |
| 33 | E | NSError_param | 14 | NYHTTPSClient.m:235 |
| 34 | E | errorWithDomain | 11 | NYHTTPSClient.m:309 |
| 35 | C | cancel_operation | 5 | NYHTTPSClient.m:460 |

共 35 個錨點命中。
