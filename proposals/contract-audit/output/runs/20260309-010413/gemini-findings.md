```
Contract: Singleton Access
Category: D
Trigger:  Any call to `+[NYNotificationPresenter sharedInstance]`
Effect:   Ensures that all callers receive the exact same instance of `NYNotificationPresenter`, creating a globally shared state and dependency.
Evidence: NYNotificationPresenter.m:126 -- `+ (instancetype)sharedInstance { static id _sharedInstance = nil; ... }`

Contract: Global Navigation Controller Dependency
Category: D
Trigger:  Any routing action performed by the presenter.
Effect:   The presenter's ability to navigate is entirely dependent on an external caller having previously set a static, global `UINavigationController` via `setActiveNavigationController:`. All routing actions implicitly rely on this shared global state.
Evidence: NYNotificationPresenter.m:136 -- `__weak static UINavigationController *globalActiveNavigationController;`

Contract: FR-Code Cookie Mutation
Category: M
Trigger:  Processing a notification action that contains an `frCode`.
Effect:   Writes a tracking cookie (`kCOOKIE_NAME_TRACE_FR`) with a 24-hour expiration. This modifies shared state that can be read by web views or subsequent network requests.
Evidence: NYNotificationPresenter.m:198 -- `[[NYCookieManager sharedManager] setCookieValue:notif.frCode forCookieName:kCOOKIE_NAME_TRACE_FR ...]`

Contract: Action Tracking Notification
Category: N
Trigger:  Processing a push notification via `processPushNotificationAction:`.
Effect:   Sends tracking data, including event category, action, label, and other callback data, to an external analytics service via `NYStatisticHelper` and `NYTrackingServiceHelper`.
Evidence: NYNotificationPresenter.m:149 -- `[[NYStatisticHelper sharedHelper] sendEventNotificationOpenedWithMessageTitle:notif.title ...]`

Contract: Conditional Login Lifecycle
Category: L
Trigger:  Attempting to navigate to a target that requires authentication (e.g., `RoutingTargetTypeRegularOrder`) when the user is not logged in.
Effect:   Interrupts the current navigation flow, presents a login view controller, and upon successful login, resumes the original navigation action using a completion block. This manages an implicit login-then-proceed state transition.
Evidence: NYNotificationPresenter.m:1554 -- `if (needLoginPage && [[NYLoginHelper sharedInstance] isLogin] == NO) { [globalActiveNavigationController presentLoginVCShouldShowUnLoginMask:NO WithLoginSuccessCompletion:^{ ... }]; }`

Contract: External URL Propagation
Category: P
Trigger:  Processing a notification with a `targetType` that resolves to an external link.
Effect:   Propagates the URL to the operating system to be opened in an external application (typically the default web browser), leaving the current app.
Evidence: NYNotificationPresenter.m:601 -- `[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];`

Contract: Asynchronous Routing Completion
Category: S
Trigger:  Calling a method that accepts a `(Completion)completion` block, such as `processNotificationAction:withCompletionBlock:`.
Effect:   Provides a synchronization point for the caller to execute code *after* the asynchronous navigation or processing logic has finished.
Evidence: NYNotificationPresenter.h:21 -- `- (void)processNotificationAction:(RoutingObject *)notif withCompletionBlock:(Completion)completion;`

Contract: Chat Room Opened Notification
Category: N
Trigger:  Presenting the customer live chat web view.
Effect:   Posts a `NYChatRoomDidOpen` notification to the default `NSNotificationCenter`, allowing any other module in the app to react to the chat room becoming visible.
Evidence: NYNotificationPresenter.m:1584 -- `[[NSNotificationCenter defaultCenter] postNotificationName: @"NYChatRoomDidOpen" object:nil];`

Contract: Malformed URL Error Reporting
Category: E
Trigger:  Attempting to unwrap a `fullurl` redirect where the custom field does not resolve to a valid URL.
Effect:   The invalid URL string is reported to a crash/error reporting service (`NYCrashlyticsHelper`) instead of causing a crash or failing silently.
Evidence: NYNotificationPresenter.m:631 -- `[NYCrashlyticsHelper recordWithUnexpectedURL:customField];`

Contract: UI Hierarchy Assumption
Category: D
Trigger:  Any navigation that involves switching tabs, like `redirectToTabBarMemberDetail`.
Effect:   Implicitly depends on the application's root view controller being a `UITabBarController` and the active navigation controller being part of that tab bar hierarchy. It frequently casts to a specific subclass, `NYTabBarControllerV2`.
Evidence: NYNotificationPresenter.m:1003 -- `NYTabBarControllerV2 *tabBarController = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];`

Contract: Recursive Unwrapping Propagation
Category: P
Trigger:  Processing a notification of type `RoutingTargetTypeFullURL` or a wrapped URL.
Effect:   The presenter calls back into itself (`processNotificationAction:withCompletionBlock:`) with a new `RoutingObject` created from the unwrapped URL. This propagates control flow recursively within the presenter.
Evidence: NYNotificationPresenter.m:640 -- `[self processNotificationAction:notifObj withCompletionBlock:completion];`

Contract: Navigation Stack Reset
Category: L
Trigger:  Calling `activeNavigationController:pushViewController:thenSelectTabAtIndex:` for the currently active tab *without* providing a view controller to push.
Effect:   The navigation stack for that tab is popped to its root view controller, effectively resetting its state.
Evidence: NYNotificationPushHelper.m:77 -- `[navController popToRootViewControllerAnimated:YES];`

Contract: Tab Navigation Order Guarantee
Category: S
Trigger:  Calling `activeNavigationController:pushViewController:thenSelectTabAtIndex:`.
Effect:   Guarantees a specific order of operations: the view controller is pushed onto the destination navigation stack *before* the tab bar visibly switches to that tab.
Evidence: NYNotificationPushHelper.m:79 -- `[navController pushViewController:viewController animated:index == tabBarController.selectedIndex ? YES : NO]; ... if (needSelectTab) { ... selectTabBarItemAt:index]; }`

TOTAL CONTRACTS FOUND: 13
CATEGORY BREAKDOWN: M=[1] L=[2] N=[2] S=[2] E=[1] C=[0] D=[3] P=[2]
```
EXTERNAL_DEPENDENCY: `NYTabBarControllerV2` -- `NYNotificationPresenter` and `NYNotificationPushHelper` both assume that the active view controller's `tabBarController` is an instance of `NYTabBarControllerV2` to perform tab selections and other UI manipulations.
EXTERNAL_DEPENDENCY: `NYLoginHelper` -- The presenter depends on this singleton to check user login status (`isLogin`) before routing to protected sections of the app.
EXTERNAL_DEPENDENCY: `NYStatisticHelper`, `NYTrackingServiceHelper` -- These are the direct observers for analytics events dispatched by the presenter. They act as proxies to an external analytics backend.
EXTERNAL_DEPENDENCY: `NYCookieManager` -- The presenter modifies shared cookie state via this helper, affecting any `WKWebView` or network client that uses shared cookies.
EXTERNAL_DEPENDENCY: Any class calling `+[NYNotificationPresenter setActiveNavigationController:]` -- These classes are responsible for providing the global navigation context required for the presenter to function.
EXTERNAL_DEPENDENCY: `NYWKWebViewController` -- The presenter creates numerous instances of this class to display web-based content for many different `RoutingTargetType`s.
EXTERNAL_DEPENDENCY: `NSNotificationCenter` Listeners for `NYChatRoomDidOpen` -- Some module, likely related to UI state, is expected to be listening for this notification to update itself when the chat view is presented.
EXTERNAL_DEPENDENCY: `NYZendeskHelper` -- The presenter relies on this helper to asynchronously provide a `UIViewController` for the Zendesk interface.
