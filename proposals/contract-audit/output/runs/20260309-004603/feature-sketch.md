## Feature Sketch（Step 0.8）

| # | 方法 | 行號 | 引用屬性 |
|---|------|------|---------|
| 1 | `+ (void)activeNavigationController:(UIViewController *)activeNavController` | NYNotificationPresenter.m:55 |  |
| 2 | `+ (void)activeNavigationController:(UIViewController *)activeNavController` | NYNotificationPresenter.m:63 |  |
| 3 | `+ (void)activeNavigationController:(UIViewController *)activeNavController` | NYNotificationPresenter.m:73 |  |
| 4 | `+ (void)activeNavigationController:(UIViewController *)activeNavController` | NYNotificationPresenter.m:104 |  |
| 5 | `+ (instancetype)sharedInstance {` | NYNotificationPresenter.m:121 | _once,_once_t,_sharedInstance,_weak |
| 6 | `+ (void)setActiveNavigationController:(UINavigationController *)navController {` | NYNotificationPresenter.m:135 |  |
| 7 | `- (void)trackingNotificationAction:(RoutingObject *)notif {` | NYNotificationPresenter.m:139 | _action_push_press,_notification_push |
| 8 | `- (void)processNotificationAction:(RoutingObject *)notif withCompletionBlock:(Co` | NYNotificationPresenter.m:171 |  |
| 9 | `- (void)navigateToTargetPageWith:(RoutingObject *)notif {` | NYNotificationPresenter.m:574 |  |
| 10 | `- (void)processPushNotificationAction:(RoutingObject *)notif {` | NYNotificationPresenter.m:578 |  |
| 11 | `- (void)processNotificationAction:(RoutingObject *)notif shouldSendTrackingLogs:` | NYNotificationPresenter.m:582 |  |
| 12 | `- (void)processADElementAction:(NYADElementObject *)adElement {` | NYNotificationPresenter.m:589 |  |
| 13 | `- (UIViewController *)redirectToSalePageCategoryWithNotificationObj:(RoutingObje` | NYNotificationPresenter.m:602 |  |
| 14 | `- (UIViewController *)redirectToNotificationCenter {` | NYNotificationPresenter.m:624 | _center_system_message |
| 15 | `- (UIViewController *)redirectToSalePageWithNotificationObj:(RoutingObject *)not` | NYNotificationPresenter.m:630 |  |
| 16 | `- (UIViewController *)redirectToNYGiftDetailWithNotificationObj:(RoutingObject *` | NYNotificationPresenter.m:642 |  |
| 17 | `- (UIViewController *)redirectToCustomerServiceCenter {` | NYNotificationPresenter.m:655 |  |
| 18 | `- (UIViewController *)redirectToQuestionList {` | NYNotificationPresenter.m:659 |  |
| 19 | `- (UIViewController *)redirectToTradeOrderList {` | NYNotificationPresenter.m:663 |  |
| 20 | `- (UIViewController *)redirectToCustomerInquiry {` | NYNotificationPresenter.m:667 |  |
| 21 | `- (UIViewController *)redirectToCustomerServiceEntry {` | NYNotificationPresenter.m:671 |  |
| 22 | `- (void)redirectToExternalBrowserWithURL:(NSURL *)url {` | NYNotificationPresenter.m:675 |  |
| 23 | `- (UIViewController *)redirectToWebViewViaUrlWithNotificationObj:(RoutingObject ` | NYNotificationPresenter.m:681 |  |
| 24 | `- (UIViewController *)redirectToWebViewViaCustomFieldWithNotificationObj:(Routin` | NYNotificationPresenter.m:685 |  |
| 25 | `- (UIViewController *)redirectToSelfDismissWebViewWithNotificationObj:(RoutingOb` | NYNotificationPresenter.m:694 |  |
| 26 | `- (void)redirectViaWrappedURLWithNotificationObj:(RoutingObject *)notif completi` | NYNotificationPresenter.m:700 |  |
| 27 | `- (void)unwrapFullURLWith:(NSURL *)url completion:(Completion)completion {` | NYNotificationPresenter.m:722 |  |
| 28 | `-(void)unwrapTargetURLWith:(NSURL *)url completion:(Completion)completion {` | NYNotificationPresenter.m:734 |  |
| 29 | `- (UIViewController *)redirectToLocationList {` | NYNotificationPresenter.m:743 |  |
| 30 | `- (UIViewController *)redirectToLocationDetailWithNotificationObj:(RoutingObject` | NYNotificationPresenter.m:748 |  |
| 31 | `- (UIViewController *)redirectToCouponList {` | NYNotificationPresenter.m:753 |  |
| 32 | `- (UIViewController *)redirectToMyCouponList {` | NYNotificationPresenter.m:757 |  |
| 33 | `- (UIViewController *)redirectToCouponDetailWithNotificationObj:(RoutingObject *` | NYNotificationPresenter.m:761 |  |
| 34 | `- (UIViewController *)redirectToInfoModuleDetailWithNotificationObj:(RoutingObje` | NYNotificationPresenter.m:766 |  |
| 35 | `- (UIViewController *)redirectToInfoModuleListWithType:(NYInfoModuleType)infoTyp` | NYNotificationPresenter.m:772 |  |
| 36 | `- (UIViewController *)redirectToInfoModuleRecommandList {` | NYNotificationPresenter.m:777 |  |
| 37 | `- (UIViewController *)redirectToSearchViewController {` | NYNotificationPresenter.m:782 |  |
| 38 | `- (UIViewController *)redirectToSearchWithNotificationObj:(RoutingObject *)notif` | NYNotificationPresenter.m:787 |  |
| 39 | `- (UIViewController *)redirectToECouponWithNotificationObj:(RoutingObject *)noti` | NYNotificationPresenter.m:802 |  |
| 40 | `- (UIViewController *)redirectToECouponExplanationWithNotificationObj:(RoutingOb` | NYNotificationPresenter.m:819 |  |
| 41 | `- (UIViewController *)redirectToECouponListWithPageType:(NYCouponListV2DataSourc` | NYNotificationPresenter.m:831 |  |
| 42 | `- (UIViewController *)redirectToMyECouponWithPageType:(NYCouponListV2DataSourceT` | NYNotificationPresenter.m:850 |  |
| 43 | `- (UIViewController *)redirectToHotSaleRankListWithShopId:(NSNumber *)shopId {` | NYNotificationPresenter.m:869 |  |
| 44 | `- (UIViewController *)redirectToHotSaleRankListWithPeriod:(NSString *)period {` | NYNotificationPresenter.m:875 |  |
| 45 | `- (UIViewController *)redirectToActivityDetailWithNotificationObj:(RoutingObject` | NYNotificationPresenter.m:881 |  |
| 46 | `- (UIViewController *)redirectToLocationPointEventDetailWithNotificationObj:(Rou` | NYNotificationPresenter.m:887 |  |
| 47 | `- (UIViewController *)redirectToPromotionList {` | NYNotificationPresenter.m:893 |  |
| 48 | `- (UIViewController *)redirectToPromotionDetailWithNotification:(RoutingObject *` | NYNotificationPresenter.m:898 |  |
| 49 | `- (void)redirectToTabBarMemberDetail {` | NYNotificationPresenter.m:905 |  |
| 50 | `- (void)redirectToVipMemberProfile {` | NYNotificationPresenter.m:910 |  |
| 51 | `- (void)redirectToShoppingCartWithCode: (NSString *)code {` | NYNotificationPresenter.m:944 |  |
| 52 | `- (void)redirectToShoppingCartWithSlaveId: (NSNumber *)salveID {` | NYNotificationPresenter.m:949 |  |
| 53 | `- (void)redirectToShoppingCartV2WithURL: (NSURL *)url {` | NYNotificationPresenter.m:962 |  |
| 54 | `- (void)redirectToPaymentWalletWithQueryItems:(NSArray<NSURLQueryItem *> *) quer` | NYNotificationPresenter.m:982 |  |
| 55 | `- (UIViewController *)redirectToBoCPayConfirmWebViewWithNotificationObj:(Routing` | NYNotificationPresenter.m:987 |  |
| 56 | `- (UIViewController *)redirectToThirdPartyPaymentConfirmWebViewWithNotificationO` | NYNotificationPresenter.m:999 |  |
| 57 | `- (UIViewController *)redirectToThirdPartyPaymentCancelWebViewWithNotificationOb` | NYNotificationPresenter.m:1011 |  |
| 58 | `- (UIViewController *)redirectToLoyaltyPointCenter {` | NYNotificationPresenter.m:1022 |  |
| 59 | `- (UIViewController *)redirectToCMSHiddenPageWithNotificationObj:(RoutingObject ` | NYNotificationPresenter.m:1028 |  |
| 60 | `- (UIViewController *)redirectToCMSCustomPageWithNotificationObj:(RoutingObject ` | NYNotificationPresenter.m:1034 |  |
| 61 | `- (UIViewController *)redirectToCMSFeverSocialWithNotificationObj:(RoutingObject` | NYNotificationPresenter.m:1056 |  |
| 62 | `- (UIViewController *)redirectToMemberPointExchange {` | NYNotificationPresenter.m:1061 |  |
| 63 | `- (UIViewController *)redirectToRegularOrder {` | NYNotificationPresenter.m:1066 |  |
| 64 | `- (UIViewController *)redirectToPromotionEngineDetailWithNotificationObj:(Routin` | NYNotificationPresenter.m:1073 |  |
| 65 | `- (UIViewController *)redirectToJKOPayPaymentConfirmWithNotificationObj:(Routing` | NYNotificationPresenter.m:1081 |  |
| 66 | `- (UIViewController *)redirectToPaymentConfirmWithNotificationObj:(RoutingObject` | NYNotificationPresenter.m:1089 |  |
| 67 | `- (UIViewController *)redirectToPaymentCancelWithNotificationObj:(RoutingObject ` | NYNotificationPresenter.m:1094 |  |
| 68 | `- (UIViewController *)redirectToPXPartialPickupWithNotificationObj:(RoutingObjec` | NYNotificationPresenter.m:1099 |  |
| 69 | `- (UIViewController *)redirectToPXPartialPickupPushWithNotificationObj:(RoutingO` | NYNotificationPresenter.m:1105 |  |
| 70 | `- (UIViewController *)redirectToPrivacyPolicyPage {` | NYNotificationPresenter.m:1115 |  |
| 71 | `- (void)processThirdpartyBasedOAuthWithNotificationObj:(RoutingObject *)notif {` | NYNotificationPresenter.m:1120 |  |
| 72 | `- (void)processSchemeRedirectWithNotificationObj:(RoutingObject *)notif {` | NYNotificationPresenter.m:1176 |  |
| 73 | `- (NSString *)getRedirectUrlFromNotificationObj:(RoutingObject *)notif {` | NYNotificationPresenter.m:1189 | _block |
| 74 | `- (void)processOpenPxPay {` | NYNotificationPresenter.m:1203 |  |
| 75 | `- (void)presentRetailStoreChoosingWithNotificationObj:(RoutingObject *)notif {` | NYNotificationPresenter.m:1216 |  |
| 76 | `- (void)presentDesignCloudAddToCartEventWith:(NYAddToCartRequestObject *)cartObj` | NYNotificationPresenter.m:1252 |  |
| 77 | `- (UIViewController *)redirectToStaffBoardList {` | NYNotificationPresenter.m:1257 |  |
| 78 | `- (UIViewController *)redirectToStaffBoardDetailWithObject:(RoutingObject *)noti` | NYNotificationPresenter.m:1262 |  |
| 79 | `- (UIViewController *)redirectToTagCategoryWithObject:(RoutingObject *)notif {` | NYNotificationPresenter.m:1268 |  |
| 80 | `- (UIViewController *)redirectToNewestCategoryList {` | NYNotificationPresenter.m:1275 |  |
| 81 | `- (UIViewController *)redirectToInvitingFriendsPage {` | NYNotificationPresenter.m:1279 |  |
| 82 | `- (UIViewController *)redirectToEVoucherListWebView {` | NYNotificationPresenter.m:1284 |  |
| 83 | `- (UIViewController *)redirectToInvitationCodeHistoryPage {` | NYNotificationPresenter.m:1290 |  |
| 84 | `- (UIViewController *)redirectToArrivalNoticeList {` | NYNotificationPresenter.m:1295 |  |
| 85 | `- (UIViewController *)redirectToMyFavoriteList {` | NYNotificationPresenter.m:1300 |  |
| 86 | `- (UIViewController *)redirectToRecentlyBrowse {` | NYNotificationPresenter.m:1305 |  |
| 87 | `- (UIViewController *)redirectToBrandListWithNotificationObj:(RoutingObject *)no` | NYNotificationPresenter.m:1310 |  |
| 88 | `- (UIViewController *)redirectToBrandPageWithNotificationObj:(RoutingObject *)no` | NYNotificationPresenter.m:1316 |  |
| 89 | `- (void)showCarrierBarcode {` | NYNotificationPresenter.m:1327 | _displayAlertWithTitle,_phone_barcode,_please_login_or_register |
| 90 | `- (void)showEditCarrierBarcode {` | NYNotificationPresenter.m:1338 | _displayAlertWithTitle,_phone_barcode,_please_login_or_register |
| 91 | `- (void)showMemberBarcode {` | NYNotificationPresenter.m:1349 | _barcode_empty_description,_displayAlertWithTitle,_member_barcode |
| 92 | `- (void)showMemberBarcodeOrCarrierBarcodeAfterLogin {` | NYNotificationPresenter.m:1366 |  |
| 93 | `- (void)showMemberBarcodeOrCarrierBarcode {` | NYNotificationPresenter.m:1377 |  |
| 94 | `- (UIViewController *)openBarcodeScannerWithNotificationObj:(RoutingObject *)not` | NYNotificationPresenter.m:1392 |  |
| 95 | `- (UIViewController *)openMemberShipCardManagePage {` | NYNotificationPresenter.m:1408 |  |
| 96 | `- (void)pushToZendeskWithCompletion:(Completion)completion {` | NYNotificationPresenter.m:1412 |  |
| 97 | `- (void)popDefaultDownloadAlert {` | NYNotificationPresenter.m:1418 |  |
| 98 | `- (void)getDefaultDownloadURLString:(NSString **)downloadURLString andAlertMessa` | NYNotificationPresenter.m:1425 | _identity_px_pay_not_installed |
| 99 | `- (void)popDownloadAlertWithMessage:(NSString *)alertMessage downloadURLString:(` | NYNotificationPresenter.m:1433 | _cancel,_download |
| 100 | `- (void)pushToVC:(UIViewController *)rootVc targetType:(RoutingTargetType)target` | NYNotificationPresenter.m:1455 |  |
| 101 | `- (void)dismissThirdPartyLoginVCIfNeeded {` | NYNotificationPresenter.m:1495 |  |
| 102 | `- (void)presentCustomerLiveChatWebVCWithQuery:(NSString *)queryString {` | NYNotificationPresenter.m:1503 |  |
| 1 | `+ (instancetype)sharedInstance;` | NYNotificationPresenter.h:15 |  |
| 2 | `+ (void)setActiveNavigationController:(UINavigationController *)navController;` | NYNotificationPresenter.h:17 |  |
| 3 | `- (void)processNotificationAction:(RoutingObject *)notif withCompletionBlock:(Co` | NYNotificationPresenter.h:19 |  |
| 4 | `- (void)processPushNotificationAction:(RoutingObject *)notif;` | NYNotificationPresenter.h:20 |  |
| 5 | `- (void)navigateToTargetPageWith:(RoutingObject *)notif;` | NYNotificationPresenter.h:21 |  |
| 6 | `- (void)processADElementAction:(NYADElementObject *)adElement;` | NYNotificationPresenter.h:22 |  |
| 7 | `- (void)presentDesignCloudAddToCartEventWith:(NYAddToCartRequestObject *)cartObj` | NYNotificationPresenter.h:23 |  |

共 109 個方法。
