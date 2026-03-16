CONFIRM M-001: `frCode` 條件成立時確實寫入追蹤 cookie，且在主要路由判斷前執行。  
CONFIRM M-002: `RoutingSourceRef` 且 shop 不同時，`targetType` 會被改成 `RoutingTargetTypeWebView`。  
CONFIRM M-003: `DesignCloudNative` 取不到 native VC 或 navigator 型別不符時，會 fallback 到 WebView 並覆寫 `targetType`。  
CONFIRM M-004: 兩個 SSO 記錄點（`recordNotificationObjectIfNeeded:` / `recordTargetUrlIfNeeded:`）都存在且為前置副作用。  
CONFIRM M-005: 選店流程會寫入 `chooseStoreTarget` completion，完成後清除並重導原始 notif。  
DISPUTE M-006: 「移除此 API 呼叫會導致需登入頁面永遠無法導航」過度推論；程式仍有登入分支與一般 push 分支。  
  Evidence: NYNotificationPresenter.m:1578 -- `} else if (needLoginPage && [[NYLoginHelper sharedInstance] isLogin] == NO) { ... } else { [NYNotificationPushHelper ... pushViewController:rootVc]; }`  
CONFIRM M-007: 會員頁 `isForceShowMemberCard` 旗標確實在型別分支內被設定。  
CONFIRM M-008: push action 會先送 GA 事件，再在 `dl` 存在時送 TrackingV2。  

CONFIRM L-001: `dispatch_once` singleton 實作正確且唯一化。  
DISPUTE L-002: 「潛在無限迴圈」敘述過度；遞迴只掛在登入成功 callback，並非無條件重入。  
  Evidence: NYNotificationPresenter.m:1579-1580 -- `WithLoginSuccessCompletion:^{ [self pushToVC:rootVc targetType:targetType completion:completion]; }`  
DISPUTE L-003: 合約文字把 `FullURL` 歸為「直接 return」不精確；`FullURL` 分支是設 `rootVc = nil`，不是 return。  
  Evidence: NYNotificationPresenter.m:235-240 -- `[self redirectViaWrappedURLWithNotificationObj:notif completion:completion]; rootVc = nil;`  
DISPUTE L-004: dismiss/present 風險描述偏推測；此處 dismiss 是 `animated:NO`。  
  Evidence: NYNotificationPresenter.m:1498 -- `[visibleVC dismissViewControllerAnimated:NO completion:nil];`  
CONFIRM L-005: 選店流程是「設 completion -> 導去選店 -> completion 再導原目標」的狀態鏈。  
CONFIRM L-006: `showMemberBarcodeOrCarrierBarcodeAfterLogin` 符合標準登入前置流程。  
CONFIRM L-007: `openBarcodeScanner...` 在未登入且非 standard 時會登入後重入路由。  

CONFIRM N-001: 聊天室 present completion 會發 `NYChatRoomDidOpen` 通知。  
DISPUTE N-002: 「.m 未見明確 protocol 方法實作」不成立；可見多個候選 delegate 方法已實作。  
  Evidence: NYNotificationPresenter.m:578 -- `- (void)processPushNotificationAction:(RoutingObject *)notif`  
CONFIRM N-003: `trackingNotificationAction:` 的兩段 analytics 發送存在且順序正確。  

CONFIRM S-001: `dispatch_once_t onceToken` 提供初始化同步保證。  
CONFIRM S-002: `__weak static` 全域 nav 讀寫沒有任何鎖/barrier，確有同步隱患。  
CONFIRM S-003: 模組內未做主執行緒保護，確實依賴呼叫端執行緒語境。  

DISPUTE E-001: 「靜默」不精確；此路徑至少有 `NSLog` 記錄。  
  Evidence: NYNotificationPresenter.m:975-977 -- `NSLog(@"SCV2 - Query value is not valid url."); return;`  
CONFIRM E-002: URL parse 失敗時會 recompose 並記 Crashlytics，再繼續 unwrap。  
CONFIRM E-003: API error / 非 `0001` 路徑沒有顯式 fallback 或使用者回饋。  
CONFIRM E-004: `PXPartialPickupPush` URL 無效時直接回傳 `nil`。  

DISPUTE C-001: 取消風險敘述偏推測；目前僅能確定是條件 dismiss，非完整 cancellation contract。  
  Evidence: NYNotificationPresenter.m:1496-1500 -- `if (visibleVC && [visibleVC isKindOfClass:[NYThirdPartyLoginWebBrowserVC class]]) { [visibleVC dismissViewControllerAnimated:NO completion:nil]; }`  

DISPUTE D-001: 「所有導航方法都依賴 globalActiveNavigationController」過度；`processADElementAction:` 走 keyWindow rootVC。  
  Evidence: NYNotificationPresenter.m:603-608 -- `UIViewController *rootVC = [[UIApplication sharedApplication] getKeyWindow].rootViewController; ... [NYNotificationPushHelper activeNavigationController:tabBarVC.selectedViewController ...]`  
DISPUTE D-002: 合約把 `redirectToVipMemberProfile` 也列為「未檢查轉型」不準確；該方法有型別檢查。  
  Evidence: NYNotificationPresenter.m:1012 -- `if (typeCheckBlock([globalActiveNavigationController tabBarController], [NYTabBarControllerV2 class])) { ... }`  
CONFIRM D-003: 多個流程直接依賴 `[NYLoginHelper sharedInstance].isLogin`。  
DISPUTE D-004: 「shopId 為 nil 會比較失敗/異常」表述過度；程式僅做布林比較分支。  
  Evidence: NYNotificationPresenter.m:186-188 -- `if (notif.source == RoutingSourceRef && ![[NYGlobalData shopId] isEqualToNumber:notif.shopID]) { targetType = RoutingTargetTypeWebView; }`  
CONFIRM D-005: 會員流程確實依賴 `NYUserDefault/NYUserDefaultV2` 設定值。  
CONFIRM D-006: `thirdpartyBasedAuth == NoData` 時確實依賴 `NYDataProvider` 非同步回傳。  
CONFIRM D-007: `DesignCloudBridge` 是 `DesignCloudNative` 路由的關鍵外部依賴。  
CONFIRM D-008: `processADElementAction` 每次 new `NYADLandingHelper` 並取目標 VC。  
CONFIRM D-009: `frCode` 路徑確實依賴 `NYCookieManager.sharedManager`。  
CONFIRM D-010: RetailStore feature flag/serviceType 直接決定 CMS custom 流程分岔。  
DISPUTE D-011: 「nil 由 pushToVC 負責處理」不成立；未見 `zendeskVC` nil guard。  
  Evidence: NYNotificationPresenter.m:1506-1508 -- `zendeskMessagingViewControllerWithCompletionHandler:^(UIViewController * _Nullable zendeskVC) { [self pushToVC:zendeskVC ...]; }`  
CONFIRM D-012: 街口支付確認頁 URL 依賴 `NYBaseURLConfig`。  

CONFIRM P-001: `rootVc` 在第一段分支被賦值，再由第二段決定 push，是明確傳播鏈。  
CONFIRM P-002: `NSString **` out parameter 會被下游 alert 使用，構成參數傳播副作用。  
DISPUTE P-003: 「每個 redirect/push/present 都讀 globalActiveNavigationController」不成立，存在非 global 路徑。  
  Evidence: NYNotificationPresenter.m:603-608 -- `rootVC = [[UIApplication sharedApplication] getKeyWindow].rootViewController; ... activeNavigationController:tabBarVC.selectedViewController ...`  

ADD Conditional Tab Selection Propagation:
  Category: P
  Trigger:  呼叫 `NYNotificationPushHelper activeNavigationController:pushViewController:thenSelectTabAtIndex:`
  Effect:   根據 `needSelectTab` 決定是否切 tab，將 push/popup 的結果傳播到 tab 狀態
  Evidence: NYNotificationPresenter.m:88-90 -- `if (needSelectTab) { [(NYTabBarControllerV2 *)tabBarController selectTabBarItemAt:index]; }`

ADD Current Tab Pop-to-Root Lifecycle:
  Category: L
  Trigger:  `isCurrentTab && !needPush`
  Effect:   不 push 新頁，直接把當前 tab 導覽堆疊退回 root
  Evidence: NYNotificationPresenter.m:81-83 -- `if (isCurrentTab && !needPush) { [navController popToRootViewControllerAnimated:YES]; }`

ADD Scheme Redirect External Propagation:
  Category: P
  Trigger:  `processSchemeRedirectWithNotificationObj:` 且 `canOpenURL == YES`
  Effect:   呼叫 `UIApplication openURL`，導航效果傳播到 app 外部
  Evidence: NYNotificationPresenter.m:1189-1191 -- `[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlScheme] options:@{} completionHandler:nil];`

ADD Missing-App Alert Fallback:
  Category: E
  Trigger:  `processSchemeRedirectWithNotificationObj:` 且 `canOpenURL == NO`
  Effect:   不執行 redirect，改為彈下載提示 alert
  Evidence: NYNotificationPresenter.m:1179-1181 -- `if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlScheme]] == NO) { [self popDefaultDownloadAlert]; }`

META_ISSUE M-005: Scope -- 標為 `module` 過大；行為集中在單一方法，較合理為 `method`。  
META_ISSUE M-006: Scope -- 標為 `module` 過大；突變點實際在 `pushToVC:targetType:completion:`。  
META_ISSUE L-002: Scope -- 標為 `module` 過大；狀態機核心在 `pushToVC...` 單一方法。  
META_ISSUE L-004: Scope -- 標為 `module` 過大；流程位於 `processThirdpartyBasedOAuthWithNotificationObj:`。  
META_ISSUE L-005: Scope -- 標為 `module` 過大；流程起點明確在 `redirectToCMSCustomPageWithNotificationObj:`。  
META_ISSUE N-001: Scope -- 標為 `module` 不精確；通知發送點是單一方法 completion。  
META_ISSUE N-001: Seam_Type -- `NSNotificationCenter postNotificationName` 屬 pub/sub 連結，`none` 不合理（應偏 `link`）。  

COVERAGE M: 8 contracts found -- OK  
COVERAGE L: 8 contracts found -- OK  
COVERAGE N: 3 contracts found -- SUSPECT_MISSING: delegate/observer coupling 仍偏薄  
COVERAGE S: 3 contracts found -- SUSPECT_MISSING: async callback ordering/scheduler contracts 未明確化  
COVERAGE E: 5 contracts found -- OK  
COVERAGE C: 1 contracts found -- SUSPECT_MISSING: 多個 modal/login 流程僅建模一個 cancellation 點  
COVERAGE D: 12 contracts found -- SUSPECT_MISSING: `NYThirdPartySSOHelper` 作為顯式依賴未獨立成 D 合約  
COVERAGE P: 5 contracts found -- SUSPECT_MISSING: 外部 openURL 與 helper-level 狀態傳播仍有漏列空間  

SUMMARY
CONFIRM: 28
DISPUTE: 12
ADD: 4
META_ISSUE: 7
CONFIRM_RATIO: 70%DEGRADED=no
