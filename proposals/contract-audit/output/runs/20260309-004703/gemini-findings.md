Contract: Singleton Initialization
Category: D
Trigger:  First call to `[NYNotificationPresenter sharedInstance]`
Effect:   Creates and returns a single, shared instance of `NYNotificationPresenter`.
Evidence: NYNotificationPresenter.m:100 -- `dispatch_once(&onceToken, ^{ _sharedInstance = [[NYNotificationPresenter alloc] init]; });`

Contract: Global Navigator State
Category: M
Trigger:  Call to `[NYNotificationPresenter setActiveNavigationController:]`
Effect:   Mutates a global static variable (`globalActiveNavigationController`) to hold a reference to the currently active navigation controller. This is a critical state for all subsequent navigation actions.
Evidence: NYNotificationPresenter.m:108 -- `globalActiveNavigationController = navController;`

Contract: Analytics Event Propagation
Category: P
Trigger:  Call to `trackingNotificationAction:`
Effect:   Formats and sends tracking data to external analytics services (`NYStatisticHelper` and `NYTrackingServiceHelper`).
Evidence: NYNotificationPresenter.m:137 -- `[[NYStatisticHelper sharedHelper] sendEventNotificationOpenedWithMessageTitle:notif.title ...];`

Contract: Cookie-based User Tracking
Category: M
Trigger:  Processing a notification action with a `frCode` (`processNotificationAction:withCompletionBlock:`)
Effect:   Sets a tracking cookie (`kCOOKIE_NAME_TRACE_FR`) with a 24-hour expiration.
Evidence: NYNotificationPresenter.m:158 -- `[[NYCookieManager sharedManager] setCookieValue:notif.frCode forCookieName:kCOOKIE_NAME_TRACE_FR ...];`

Contract: Routing and View Controller Creation
Category: P
Trigger:  Call to `processNotificationAction:withCompletionBlock:` with a `RoutingObject`
Effect:   Based on the `targetType` of the `RoutingObject`, creates a specific `UIViewController` subclass to handle the navigation target. This is the primary routing mechanism.
Evidence: NYNotificationPresenter.m:169-588 -- The large `if-else if` block that matches `targetType` to a `redirectTo...` method call.

Contract: Recursive URL Unwrapping
Category: L
Trigger:  Processing a notification with `targetType == RoutingTargetTypeFullURL`.
Effect:   Extracts a nested URL from the `RoutingObject`, creates a *new* `RoutingObject` from it, and re-invokes the processing logic, effectively starting a new navigation lifecycle within the current one.
Evidence: NYNotificationPresenter.m:824 -- `RoutingObject *notifObj = [[RoutingObject alloc] initWithUrlString:url.absoluteString]; [self processNotificationAction:notifObj withCompletionBlock:completion];`

Contract: External Application Navigation
Category: P
Trigger:  Processing a URL that `isExternalLink` or `targetType == RoutingTargetTypeSchemeRedirect`.
Effect:   Passes a URL to the operating system to be opened by an external application.
Evidence: NYNotificationPresenter.m:905 -- `[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];`

Contract: Implicit Login Gate
Category: L
Trigger:  Attempting to navigate to a target that requires authentication when the user is not logged in.
Effect:   Interrupts the navigation flow to present a login view controller. Upon successful login, the original navigation is resumed.
Evidence: NYNotificationPresenter.m:1450 -- `if (needLoginPage && [[NYLoginHelper sharedInstance] isLogin] == NO) { [globalActiveNavigationController presentLoginVCShouldShowUnLoginMask:NO WithLoginSuccessCompletion:^{ [self pushToVC:rootVc targetType:targetType completion:completion]; }]; }`

Contract: Chat Status Notification
Category: N
Trigger:  Presenting the customer live chat view controller.
Effect:   Posts a `NYChatRoomDidOpen` notification to `NSNotificationCenter`, signaling to other parts of the app that the chat UI is now active.
Evidence: NYNotificationPresenter.m:1474 -- `[[NSNotificationCenter defaultCenter] postNotificationName: @"NYChatRoomDidOpen" object:nil];`

Contract: Navigation Order Guarantee
Category: S
Trigger:  Call to `[NYNotificationPushHelper activeNavigationController:pushViewController:thenSelectTabAtIndex:]`.
Effect:   Ensures a view controller is pushed onto a navigation stack *before* its containing tab is selected.
Evidence: NYNotificationPushHelper.m:77 -- `// Note: 應KK要求，先在選定的tab推頁之後才切換。所以selectFirstTab要在pushViewController之後執行。`

Contract: Root View Controller Reset
Category: P
Trigger:  Call to `[NYNotificationPushHelper activeNavigationController:pushViewController:thenSelectTabAtIndex:]` for the current tab with a `nil` view controller.
Effect:   Pops all view controllers on the current navigation stack, returning to the root view controller for that tab.
Evidence: NYNotificationPushHelper.m:85 -- `[navController popToRootViewControllerAnimated:YES];`

Contract: Global State Dependency
Category: D
Trigger:  Any navigation or routing action within the presenter.
Effect:   Relies on numerous singletons and global data providers to function, including `NYGlobalData`, `NYLoginHelper`, `NYCookieManager`, `NYAppSettingsHelper`, `NYUserDefault`, and the `globalActiveNavigationController` static variable.
Evidence: NYNotificationPresenter.m:161 -- `if (notif.source == RoutingSourceRef && ![[NYGlobalData shopId] isEqualToNumber:notif.shopID])` (and many other examples).

TOTAL CONTRACTS FOUND: 12
CATEGORY BREAKDOWN: M=2 L=2 N=1 S=1 E=0 C=0 D=2 P=4

EXTERNAL_DEPENDENCY: `NYTabBarControllerV2` -- Manages tab bar state and is manipulated by `NYNotificationPushHelper` to switch tabs.
EXTERNAL_DEPENDENCY: `NYStatisticHelper`, `NYTrackingServiceHelper` -- Receives analytics and tracking data from `trackingNotificationAction`.
EXTERNAL_DEPENDENCY: `NYLoginHelper` -- Its `isLogin` state determines whether the login gate is triggered for certain navigation targets.
EXTERNAL_DEPENDENCY: `NYCookieManager` -- Its `setCookieValue` method is called to persist tracking information.
EXTERNAL_DEPENDENCY: Any class observing `NYChatRoomDidOpen` notification -- This code posts the notification, but consumers are external to it.
EXTERNAL_DEPENDENCY: `NYCrashlyticsHelper` -- Receives error reports for unparseable URLs.
EXTERNAL_DEPENDENCY: `UINavigationController` (provided via `globalActiveNavigationController`) -- This is the primary endpoint for all `pushViewController` propagation effects.
EXTERNAL_DEPENDENCY: `NYCMSBasedViewController.m` -- Calls `navigateToTargetPageWith:` to handle user interactions, acting as a client to this presenter.
EXTERNAL_DEPENDENCY: `DCWKWebViewController.swift` -- One of the many view controller classes instantiated and pushed by the presenter.
EXTERNAL_DEPENDENCY: `NYThirdPartySSOHelper` -- Manages complex state for third-party Single Sign-On flows, which this presenter triggers and responds to.
