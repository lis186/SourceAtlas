Contract: Singleton Instance
Category: D
Trigger:  First call to `+[NYNotificationPresenter sharedInstance]`
Effect:   Creates and returns a single, globally accessible instance of `NYNotificationPresenter`. All subsequent calls return the same instance, making it a global dependency.
Evidence: NYNotificationPresenter.m:100 -- `+ (instancetype)sharedInstance`

Contract: Global Navigation Context
Category: D
Trigger:  Call to `+[NYNotificationPresenter setActiveNavigationController:]`
Effect:   Sets a weak, static (global) `UINavigationController` reference. All subsequent routing and presentation logic within the presenter depends on this globally mutable state.
Evidence: NYNotificationPresenter.m:109 -- `__weak static UINavigationController *globalActiveNavigationController;`

Contract: Analytics Tracking on Push Action
Category: N
Trigger:  Calling `-[NYNotificationPresenter processPushNotificationAction:]`
Effect:   Sends tracking events to `NYStatisticHelper` and `NYTrackingServiceHelper` with details from the notification object, notifying external analytics systems of the user's action.
Evidence: NYNotificationPresenter.m:128 -- `[[NYStatisticHelper sharedHelper] sendEventNotificationOpenedWithMessageTitle:notif.title ...]`

Contract: Side-effect Cookie Creation
Category: M
Trigger:  Processing a `RoutingObject` that contains a non-nil `frCode`.
Effect:   Sets a tracking cookie named `kCOOKIE_NAME_TRACE_FR` via `NYCookieManager` with a 24-hour lifespan. This modifies user-specific state that persists across app sessions.
Evidence: NYNotificationPresenter.m:160 -- `[[NYCookieManager sharedManager] setCookieValue:notif.frCode forCookieName:kCOOKIE_NAME_TRACE_FR ...]`

Contract: External URL Propagation
Category: P
Trigger:  Processing a `RoutingObject` of type `RoutingTargetTypeWebView` where the URL is an external link.
Effect:   The application yields control and attempts to open the URL in an external application (e.g., Safari browser), propagating the navigation outside the app.
Evidence: NYNotificationPresenter.m:200 -- `[self redirectToExternalBrowserWithURL:notif.url];`

Contract: Recursive URL Unwrapping and Processing
Category: P
Trigger:  Processing a `RoutingObject` of type `RoutingTargetTypeFullURL`.
Effect:   The method unwraps a nested URL from the notification object and re-invokes the main processing logic (`processNotificationAction:withCompletionBlock:`) with a new `RoutingObject`. This creates a chain of routing actions.
Evidence: NYNotificationPresenter.m:1003 -- `RoutingObject *notifObj = [[RoutingObject alloc] initWithUrlString:url.absoluteString]; [self processNotificationAction:notifObj withCompletionBlock:completion];`

Contract: Login-Gated Navigation
Category: L
Trigger:  Attempting to navigate to a target type that requires login (e.g., `RoutingTargetTypeRegularOrder`, `RoutingTargetTypeLoyaltyPoint`) when the user is not logged in.
Effect:   Interrupts the intended navigation, presents a login view controller modally, and only proceeds with the original navigation upon successful login.
Evidence: NYNotificationPresenter.m:1652 -- `if (needLoginPage && [[NYLoginHelper sharedInstance] isLogin] == NO)`

Contract: Conditional Tab Switching
Category: P
Trigger:  Calling `+[NYNotificationPushHelper activeNavigationController:pushViewController:thenSelectTabAtIndex:]`
Effect:   Manipulates a `UITabBarController` to switch to a specific tab by its index. It assumes the tab bar controller is of a specific class (`NYTabBarControllerV2`) to perform the selection.
Evidence: NYNotificationPushHelper.m:92 -- `[(NYTabBarControllerV2 *)tabBarController selectTabBarItemAt:index];`

Contract: View Stack Manipulation
Category: L
Trigger:  Calling `+[NYNotificationPushHelper activeNavigationController:pushViewController:thenSelectTabAtIndex:]` with `isCurrentTab` true and `needPush` false.
Effect:   Instead of pushing a new view, it pops the navigation stack of the current tab to its root view controller.
Evidence: NYNotificationPushHelper.m:89 -- `[navController popToRootViewControllerAnimated:YES];`

Contract: External App Scheme Redirect
Category: P
Trigger:  Processing a `RoutingObject` of type `RoutingTargetTypeSchemeRedirect`.
Effect:   Attempts to open a custom URL scheme, effectively trying to hand off control to another application installed on the device.
Evidence: NYNotificationPresenter.m:1330 -- `[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlScheme] ...]`

Contract: Missing App Alert
Category: E
Trigger:  An attempt to redirect to an external app scheme fails because the target app is not installed (`canOpenURL:` returns NO).
Effect:   An alert is displayed to the user prompting them to download the missing application.
Evidence: NYNotificationPresenter.m:1327 -- `[self popDefaultDownloadAlert];`

Contract: Design Cloud Native Fallback
Category: E
Trigger:  Processing a `RoutingTargetTypeDesignCloudNative` notification, but the `DesignCloudBridge` fails to return a native view controller.
Effect:   The system silently falls back to treating the target as a web page (`RoutingTargetTypeDesignCloudWebPage`) and opens it in a `DCWKWebViewController` instead.
Evidence: NYNotificationPresenter.m:846 -- `rootVc = [[DCWKWebViewController alloc] initWithUrl:notif.url];`

Contract: Login UI Management
Category: D
Trigger:  Processing a `RoutingTargetTypeThirdpartyBasedOAuthSuccess` notification when a third-party login flow is in progress.
Effect:   It depends on `NYThirdPartySSOHelper` and `NYLoginHelper` state, and may present or dismiss a specific login view controller (`NYThirdPartyLoginWebBrowserVC`) to manage the UI state transition during authentication.
Evidence: NYNotificationPresenter.m:1377 -- `[self dismissThirdPartyLoginVCIfNeeded]; [globalActiveNavigationController presentViewController:webNavi animated:YES completion:nil];`

Contract: Chat Room Open Notification
Category: N
Trigger:  A customer service live chat web view is successfully presented.
Effect:   A `NSNotification` with the name "NYChatRoomDidOpen" is posted to the default `NSNotificationCenter`, signaling to any other part of the app that the chat UI is now visible.
Evidence: NYNotificationPresenter.m:1680 -- `[[NSNotificationCenter defaultCenter] postNotificationName: @"NYChatRoomDidOpen" object:nil];`

TOTAL CONTRACTS FOUND: 14
CATEGORY BREAKDOWN: M=[1] L=[2] N=[2] S=[0] E=[2] C=[0] D=[3] P=[4]

EXTERNAL_DEPENDENCY: NYTabBarControllerV2 -- The push helper directly casts the tab bar controller to this subclass to call custom methods like `getTabBarItemIndexOf:` and `selectTabBarItemAt:`.
EXTERNAL_DEPENDENCY: NYStatisticHelper -- This singleton is an endpoint for analytics data propagation.
EXTERNAL_DEPENDENCY: NYTrackingServiceHelper -- This singleton is a second endpoint for analytics data propagation.
EXTERNAL_DEPENDENCY: NYCookieManager -- This singleton is used to mutate persistent user state (cookies).
EXTERNAL_DEPENDENCY: NYLoginHelper -- This singleton's state (`isLogin`) is a critical dependency that gates navigation to certain features.
EXTERNAL_DEPENDENCY: (numerous view controllers like NYSalePageViewController, NYCouponDetailVC, etc.) -- These are all downstream dependencies whose lifecycle is initiated by the presenter.
EXTERNAL_DEPENDENCY: UIApplication -- The presenter uses the shared application instance to open external URLs, propagating actions outside the app.
EXTERNAL_DEPENDENCY: NYCrashlyticsHelper -- Used as an error handling endpoint for logging unexpected URL formats.
EXTERNAL_DEPENDENCY: NSNotificationCenter -- Observers listening for "NYChatRoomDidOpen" are external dependencies.
EXTERNAL_DEPENDENCY: RetailStoreService -- This singleton's state is checked to decide complex routing logic for custom CMS pages.
EXTERNAL_DEPENDENCY: NYZendeskHelper -- Used to asynchronously fetch a view controller for display.
EXTERNAL_DEPENDENCY: DCWKWebViewController.swift -- This Swift class is a dependency for handling web-based routing targets.
EXTERNAL_DEPENDENCY: NYCMSBasedViewController.m -- This class calls `navigateToTargetPageWith:` on the presenter, acting as a client.
