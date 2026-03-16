```
Contract: Singleton Access
Category: D
Trigger:  Calling `[NYNotificationPresenter sharedInstance]`
Effect:   Ensures that only one instance of `NYNotificationPresenter` exists throughout the application's lifecycle, creating a global dependency.
Evidence: NYNotificationPresenter.m:92 -- `+ (instancetype)sharedInstance { ... }`

Contract: Global Navigation Controller Dependency
Category: D
Trigger:  Any method in `NYNotificationPresenter` or `NYNotificationPushHelper` that performs navigation.
Effect:   Relies on a globally accessible, weakly-held `UINavigationController` instance (`globalActiveNavigationController`) being set from outside the module. Operations will fail or do nothing if this is nil.
Evidence: NYNotificationPresenter.m:99 -- `__weak static UINavigationController *globalActiveNavigationController;`

Contract: Analytics Event Dispatch
Category: N
Trigger:  Calling `-[NYNotificationPresenter trackingNotificationAction:]`.
Effect:   Sends tracking data to an external analytics service (`NYStatisticHelper`, `NYTrackingServiceHelper`) using details from the `RoutingObject`.
Evidence: NYNotificationPresenter.m:128 -- `[[NYStatisticHelper sharedHelper] sendEventNotificationOpenedWithMessageTitle:notif.title content:notif.content openType:[NYFAConstant kFAParamPush] landingPage:[notif abbreviationStringOfTargetType] cbd:notif.nyCallBackData];`

Contract: Cookie-based User Tracking
Category: M
Trigger:  Processing a notification action with a `frCode` (`-[NYNotificationPresenter processNotificationAction:withCompletionBlock:]`).
Effect:   Sets a tracking cookie (`kCOOKIE_NAME_TRACE_FR`) with a 24-hour expiration, modifying shared browser state.
Evidence: NYNotificationPresenter.m:145 -- `[[NYCookieManager sharedManager] setCookieValue:notif.frCode forCookieName:kCOOKIE_NAME_TRACE_FR expirationDate:[NSDate dateWithTimeIntervalSinceNow:24*60*60]];`

Contract: Centralized Routing Logic
Category: P
Trigger:  Calling `-[NYNotificationPresenter processNotificationAction:withCompletionBlock:]`.
Effect:   Acts as a central router, taking a `RoutingObject` and determining which `UIViewController` to create and navigate to based on the `targetType`. The entire method body is a large-scale propagation contract.
Evidence: NYNotificationPresenter.m:140 -- `- (void)processNotificationAction:(RoutingObject *)notif withCompletionBlock:(Completion)completion { ... }`

Contract: External URL Opening
Category: P
Trigger:  Processing a notification with a `targetType` of `RoutingTargetTypeWebView` and an external link.
Effect:   Propagates a URL to the underlying operating system to be opened in an external application (e.g., Safari).
Evidence: NYNotificationPresenter.m:903 -- `[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];`

Contract: Recursive URL Unwrapping
Category: P
Trigger:  Processing a notification with `targetType` `RoutingTargetTypeFullURL`.
Effect:   Parses a URL from the notification's data and recursively calls its own `processNotificationAction:` method to handle the unwrapped URL, creating an internal processing loop.
Evidence: NYNotificationPresenter.m:944 -- `[self processNotificationAction:notifObj withCompletionBlock:completion];`

Contract: Login-Gated Navigation
Category: D
Trigger:  Attempting to navigate to a target that requires authentication (e.g., `RoutingTargetTypeMyCouponList`, `RoutingTargetTypeTradesOrderList`).
Effect:   Implicitly depends on the `NYLoginHelper` singleton. If the user is not logged in, it interrupts the navigation flow to present a login view controller.
Evidence: NYNotificationPresenter.m:1664 -- `} else if (needLoginPage && [[NYLoginHelper sharedInstance] isLogin] == NO) { [globalActiveNavigationController presentLoginVCShouldShowUnLoginMask:NO WithLoginSuccessCompletion:^{ [self pushToVC:rootVc targetType:targetType completion:completion]; }];`

Contract: Asynchronous Settings Fetch
Category: S
Trigger:  Navigating to a login-gated page (`needLoginPage`) when third-party auth settings are not yet loaded.
Effect:   Initiates an asynchronous network call (`getShopStaticSettingWithCompletionHandler`) and defers the final navigation action until the network call completes, creating an ordering dependency.
Evidence: NYNotificationPresenter.m:1653 -- `[[NYDataProvider sharedInstance] getShopStaticSettingWithCompletionHandler:^(NSDictionary *responseObject, NSError *error) { ... }]`

Contract: UI Navigation and Tab Switching
Category: P
Trigger:  Calling `[NYNotificationPushHelper activeNavigationController:pushViewController:thenSelectTabAtIndex:]`.
Effect:   Manipulates the main application's UI hierarchy by pushing a new view controller onto a specific tab's navigation stack and then switching to that tab. The order of operations (push then switch) is explicitly defined.
Evidence: NYNotificationPushHelper.m:77 -- `[navController pushViewController:viewController animated:index == tabBarController.selectedIndex ? YES : NO];`

Contract: Chat Room State Notification
Category: N
Trigger:  Successfully presenting the customer live chat view controller.
Effect:   Posts a `NYChatRoomDidOpen` notification to the default `NSNotificationCenter`, allowing other modules to observe when the chat UI is shown.
Evidence: NYNotificationPresenter.m:1697 -- `[[NSNotificationCenter defaultCenter] postNotificationName: @"NYChatRoomDidOpen" object:nil];`

Contract: Third-Party App Integration
Category: P
Trigger:  Processing a `RoutingTargetTypeSchemeRedirect` notification.
Effect:   Attempts to open a custom URL scheme, propagating the action to another installed application. If the app is not installed, it shows a download alert.
Evidence: NYNotificationPresenter.m:1473 -- `[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlScheme] options:@{} completionHandler:nil];`

TOTAL CONTRACTS FOUND: 12
CATEGORY BREAKDOWN: M=[1] L=[0] N=[2] S=[1] E=[0] C=[0] D=[3] P=[5]
```
EXTERNAL_DEPENDENCY: [NYStatisticHelper, NYTrackingServiceHelper] -- Listens for analytics events sent by `trackingNotificationAction:`.
EXTERNAL_DEPENDENCY: [NSNotificationCenter observers for "NYChatRoomDidOpen"] -- Listens for the notification posted when the live chat view is presented.
EXTERNAL_DEPENDENCY: [AppDelegate or SceneDelegate] -- Responsible for setting the `globalActiveNavigationController` that this presenter depends on.
EXTERNAL_DEPENDENCY: [NYCookieManager, NYGlobalData, NYUserDefault, NYLoginHelper, NYAppSettingsHelper] -- These singletons represent shared global state that `NYNotificationPresenter` reads from and writes to. Other modules depend on this same state.
EXTERNAL_DEPENDENCY: [UITabBarController, UINavigationController] -- The core consumers of the view controllers created by this presenter. The presenter's primary effect is to push VCs onto their stacks.
EXTERNAL_DEPENDENCY: [NYWKWebViewController, NYSalePageViewController, NYCouponDetailVC, and dozens of other UIViewController subclasses] -- These view controllers are the downstream endpoints of the presenter's routing logic. Their lifecycle is initiated by this presenter.
EXTERNAL_DEPENDENCY: [iOS Springboard/OS] -- The ultimate consumer of propagation actions like opening external URLs (`openURL:`) or custom schemes.
