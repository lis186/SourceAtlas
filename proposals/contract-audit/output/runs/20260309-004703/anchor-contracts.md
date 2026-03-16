## 確定性錨定合約（Step 0.7）

以下模式在目標檔案中被偵測到，後續 LLM 步驟**必須**為每個錨點產出對應合約：

| # | 類別 | 模式 | 獨特位置 | 首次出現 |
|---|------|------|---------|---------|
| 1 | S | dispatch_async | 3 | NYCMSBasedViewController.m:968 |
| 2 | S | dispatch_once | 1 | NYNotificationPresenter.m:125 |
| 3 | S | dispatch_after | 1 | NYCMSBasedViewController.m:1078 |
| 4 | S | dispatch_group | 10 | NYCMSLaunchViewController.m:36 |
| 5 | N | postNotificationName | 5 | NYNotificationPresenter.m:1507 |
| 6 | N | addObserver_selector | 2 | NYCMSBasedViewController.m:167 |
| 7 | N | removeObserver | 1 | NYCMSLaunchViewController.m:202 |
| 8 | N | respondsToSelector | 13 | NYCMSBasedViewController.m:1518 |
| 9 | N | delegate_property | 72 ⚠️ pervasive | DCWKWebViewController.swift:296 |
| 10 | N | defaultCenter | 9 | NYNotificationPresenter.m:1507 |
| 11 | N | performSelector | 8 | NYECouponListHelper.m:318 |
| 12 | N | completionHandler | 15 | NYNotificationPresenter.m:678 |
| 13 | L | viewDidLoad | 9 | DCWKWebViewController.swift:64 |
| 14 | L | viewWillAppear | 8 | DCWKWebViewController.swift:90 |
| 15 | L | viewDidAppear | 6 | DCWKWebViewController.swift:96 |
| 16 | L | viewWillDisappear | 5 | DCWKWebViewController.swift:103 |
| 17 | L | viewDidDisappear | 2 | DCWKWebViewController.swift:109 |
| 18 | L | performSelector_afterDelay | 3 | NYECouponListHelper.m:615 |
| 19 | D | sharedInstance | 33 ⚠️ pervasive | NYNotificationPresenter.m:1043 |
| 20 | D | shared_dot | 18 | NYNotificationPresenter.m:625 |
| 21 | D | protocol_decl | 17 | NYCMSBasedViewController.m:477 |
| 22 | D | category_interface | 4 | NYCMSBasedViewController.m:46 |
| 23 | E | NSError_param | 2 | NYCMSBasedViewController.m:1054 |

共 23 個錨點命中。
