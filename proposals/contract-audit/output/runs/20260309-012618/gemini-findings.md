```
Contract: Singleton Access
Category: D
Trigger:  Calling `[NYNotificationPresenter sharedInstance]` for the first time.
Effect:   An instance of `NYNotificationPresenter` is created and stored statically, ensuring all subsequent calls return the same object.
Evidence: NYNotificationPresenter.m:109 -- `dispatch_once(&onceToken, ^{ _sharedInstance = [[NYNotificationPresenter alloc] init]; });`

Contract: Global Navigation Controller Dependency
Category: D
Trigger:  Any method that performs navigation (e.g., `processNotificationAction:`, `pushToVC:`, `redirectToTabBarMemberDetail`).
Effect:   The class relies on a statically-held `globalActiveNavigationController` to be set from an external context. All navigation actions are performed on this controller.
Evidence: NYNotificationPresenter.m:118 -- `__weak static UINavigationController *globalActiveNavigationController;`

Contract: Tracking Event Dispatch
Category: N
Trigger:  Calling `trackingNotificationAction:`.
Effect:   Sends tracking data to an external analytics service (`NYStatisticHelper`, `NYTrackingServiceHelper`) about the notification being processed.
Evidence: NYNotificationPresenter.m:149 -- `[[NYStatisticHelper sharedHelper] sendEventNotificationOpenedWithMessageTitle:notif.title content:notif.content openType:[NYFAConstant kFAParamPush] landingPage:[notif abbreviationStringOfTargetType] cbd:notif.nyCallBackData];`

Contract: FR-Code Cookie Mutation
Category: M
Trigger:  Calling `processNotificationAction:` with a `RoutingObject` that has a non-empty `frCode`.
Effect:   Sets a tracking cookie named "trace_fr" with a 24-hour expiration.
Evidence: NYNotificationPresenter.m:171 -- `[[NYCookieManager sharedManager] setCookieValue:notif.frCode forCookieName:kCOOKIE_NAME_TRACE_FR expirationDate:[NSDate dateWithTimeIntervalSinceNow:24*60*60]];`

Contract: External URL Handling
Category: P
Trigger:  Processing a `RoutingObject` of type `RoutingTargetTypeWebView` where the URL is an external link.
Effect:   The application hands off the URL to the operating system to be opened in an external browser.
Evidence: NYNotificationPresenter.m:211 -- `[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];`

Contract: Unwrapping Short-URL
Category: P
Trigger:  Processing a `RoutingObject` of type `RoutingTargetTypeFullURL`.
Effect:   The method recursively calls `processNotificationAction:` with a new `RoutingObject` created from the unwrapped/redirected URL.
Evidence: NYNotificationPresenter.m:908 -- `RoutingObject *notifObj = [[RoutingObject alloc] initWithUrlString:url.absoluteString]; [self processNotificationAction:notifObj withCompletionBlock:completion];`

Contract: Forced Login Lifecycle
Category: L
Trigger:  Attempting to navigate to a target that requires login (e.g., `RoutingTargetTypeMyCouponList`, `RoutingTargetTypeTradesOrderList`) when the user is not logged in.
Effect:   A login view controller is presented. Upon successful login, the originally requested navigation is executed.
Evidence: NYNotificationPresenter.m:1506 -- `[globalActiveNavigationController presentLoginVCShouldShowUnLoginMask:NO WithLoginSuccessCompletion:^{ [self pushToVC:rootVc targetType:targetType completion:completion]; }];`

Contract: Open App Scheme Redirect
Category: P
Trigger:  Processing a `RoutingObject` of type `RoutingTargetTypeSchemeRedirect`.
Effect:   The application attempts to open a URL with a custom scheme, effectively launching another application.
Evidence: NYNotificationPresenter.m:1330 -- `[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlScheme] options:@{} completionHandler:nil];`

Contract: Scheme Availability Error Handling
Category: E
Trigger:  Processing a `RoutingTargetTypeSchemeRedirect` when the target application is not installed.
Effect:   A generic download alert is displayed to the user.
Evidence: NYNotificationPresenter.m:1327 -- `if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlScheme]] == NO) { [self popDefaultDownloadAlert]; ... }`

Contract: Global State Mutation
Category: M
Trigger:  Calling `+ (void)setActiveNavigationController:(UINavigationController *)navController`.
Effect:   Mutates the static `globalActiveNavigationController` variable, changing the target for all future navigation actions within the class.
Evidence: NYNotificationPresenter.m:121 -- `+ (void)setActiveNavigationController:(UINavigationController *)navController { globalActiveNavigationController = navController; }`

Contract: SSO State Dependency
Category: D
Trigger:  Calling `processThirdpartyBasedOAuthWithNotificationObj:`.
Effect:   Relies on the state and logic within the `NYThirdPartySSOHelper` singleton to determine the Single Sign-On flow, including whether to prompt for login.
Evidence: NYNotificationPresenter.m:1283 -- `[[NYThirdPartySSOHelper shared] analyzeSSOAuthWithUrl:notif.url];`

Contract: Chat Room Opened Notification
Category: N
Trigger:  Successfully presenting the customer live chat web view via `presentCustomerLiveChatWebVCWithQuery:`.
Effect:   Posts a `NYChatRoomDidOpen` notification to the default `NSNotificationCenter`.
Evidence: NYNotificationPresenter.m:1532 -- `[[NSNotificationCenter defaultCenter] postNotificationName: @"NYChatRoomDidOpen" object:nil];`

Contract: Invalid URL Fallback
Category: E
Trigger:  In `redirectViaWrappedURLWithNotificationObj:`, parsing a `customField` string into an `NSURL` fails.
Effect:   The method attempts to re-parse the string using a different helper (`recomposeWithString:`) and logs the unexpected URL to a crashlytics service.
Evidence: NYNotificationPresenter.m:955 -- `url = [NSURL recomposeWithString:customField]; [NYCrashlyticsHelper recordWithUnexpectedURL:customField];`

Contract: Barcode Display Logic
Category: L
Trigger:  Calling `showMemberBarcode`.
Effect:   The system checks multiple conditions (`hasCachedBarcode`, `shouldVerifyCellphoneWithoutOuterID`, `userCellPhoneIsEmpty`) to decide whether to show a barcode, present a phone verification VC, or show an error alert. This represents an implicit state machine.
Evidence: NYNotificationPresenter.m:1455 -- `if ([NYMemberHelper.shareInstance hasCachedBarcode]) { ... } else if ([NYLoginHelper sharedInstance].isLogin && [NYUserDefault shouldVerifyCellphoneWithoutOuterID] && [NYLoginHelper userCellPhoneIsEmpty]) { ... } else { ... }`

TOTAL CONTRACTS FOUND: 14
CATEGORY BREAKDOWN: M=[2] L=[2] N=[2] S=[0] E=[2] C=[0] D=[2] P=[4]
```

EXTERNAL_DEPENDENCY: `NYTabBarControllerV2` -- `redirectToTabBarMemberDetail`, `redirectToShoppingCartWithCode`, etc. all cast the `tabBarController` to this specific class to perform tab switching and present view controllers.
EXTERNAL_DEPENDENCY: `NYStatisticHelper` -- `trackingNotificationAction:` sends analytics events through this singleton.
EXTERNAL_DEPENDENCY: `NYCookieManager` -- `processNotificationAction:` sets a cookie via this singleton.
EXTERNAL_DEPENDENCY: `NYLoginHelper` -- Multiple methods check `isLogin` and present login VCs based on the state of this singleton.
EXTERNAL_DEPENDENCY: `NYGlobalData` -- Multiple methods read configuration and state, like `shopId` and `countryCode`, from this singleton.
EXTERNAL_DEPENDENCY: `NYLaunchHelper` -- Used to create various view controllers like `itemListVCWithCategoryId:` and `newestCategoryPage`.
EXTERNAL_DEPENDENCY: (observers of `NYChatRoomDidOpen`) -- `presentCustomerLiveChatWebVCWithQuery:` posts a notification that other parts of the app may listen for to react to the chat room opening.
EXTERNAL_DEPENDENCY: `NYThirdPartySSOHelper` -- `processThirdpartyBasedOAuthWithNotificationObj:` and `redirectToLocationPointEventDetailWithNotificationObj:` depend on this singleton to manage SSO state and navigation.
EXTERNAL_DEPENDENCY: `NYWKWebViewController` -- Many methods create and return instances of this class to display web content (e.g., `customerServiceCenterWebVC`, `standardWebVCWithUrl:`).
EXTERNAL_DEPENDENCY: `NYCrashlyticsHelper` -- `redirectViaWrappedURLWithNotificationObj:` reports malformed URLs to this helper.
EXTERNAL_DEPENDENCY: `DesignCloudBridge` -- `processNotificationAction` calls this bridge to get a native view controller from a URL path.
EXTERNAL_DEPENDENCY: `NYZendeskHelper` -- `pushToZendeskWithCompletion` uses this helper to create and display the Zendesk messaging view controller.
