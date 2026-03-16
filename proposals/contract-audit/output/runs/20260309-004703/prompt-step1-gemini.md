# Blind Contract Scout
# 盲掃合約發現者 -- 語言無關版本
# 此 prompt 由 Gemini 執行，獨立於主稽核者（Auditor）運作，不參考任何既有合約清單。

## ROLE

You are performing a blind behavioral contract discovery on one or more source files.
You have NO prior list of contract IDs. You are NOT trying to confirm anyone else's work.
Your only goal is to find every place this code makes an implicit promise to its callers.

The target code may be written in any language (`objc`). Adapt your analysis accordingly.

## WHAT TO LOOK FOR

Scan for all eight categories of behavioral contracts:

| Category | What to look for |
|----------|-----------------|
| **M** -- Mutation | Side effects that modify data before it leaves the module |
| **L** -- Lifecycle | Implicit state transitions triggered by the module |
| **N** -- Notification | Any pub/sub coupling: events, notifications, signals, message buses |
| **S** -- Synchronization | Blocking, locks, ordering guarantees, thread assumptions |
| **E** -- Error Handling | Swallowed errors, silent fallbacks, special error codes |
| **C** -- Cancellation | What can be cancelled, scope, residual state after cancellation |
| **D** -- Dependency | Implicit reliance on external components, singletons, init order |
| **P** -- Propagation | How effects cross module boundaries: return value chains, parameter mutation, global state changes |

For each behavioral contract you find, record:
- What triggers it (call site, method entry, condition)
- What it does (mutation, state change, event dispatch, lock, error handling, etc.)
- Exact filename and line number
- One-sentence description

## OUTPUT FORMAT

For each contract:

```
Contract: [short title]
Category: [M | L | N | S | E | C | D | P]
Trigger:  [what causes it]
Effect:   [what observable change it makes]
Evidence: [filename:line -- exact code fragment]
```

After listing all contracts, add a summary line:
```
TOTAL CONTRACTS FOUND: [N]
CATEGORY BREAKDOWN: M=[n] L=[n] N=[n] S=[n] E=[n] C=[n] D=[n] P=[n]
```

## Section 4: Boundary Discovery

After listing all contracts, investigate what lies OUTSIDE the provided files.
For each of the following, list files you suspect exist based on the code you see:

1. **Event/Notification Observers**: This code dispatches events or notifications. What classes or modules likely observe them?
   Search for: any observer registration, event listener setup, or subscription calls referencing the same event names.

2. **External Synchronization**: This code uses synchronization primitives (locks, semaphores, actors, mutexes, async barriers). Are there other classes with similar patterns?

3. **Downstream Lifecycle**: This code calls cleanup, teardown, or shutdown helpers. What classes implement them?

4. **Singleton / Global State**: This code reads or writes shared global state. What other modules depend on the same state?

5. **Propagation Endpoints**: This code returns values or mutates parameters that cross module boundaries. What are the likely consumers?

For each finding, output:
```
EXTERNAL_DEPENDENCY: [suspected filename or class/module name] -- [reason / what event or call triggers it]
```

If you cannot find evidence, output:
```
EXTERNAL_DEPENDENCY: (none found)
```

## INSTRUCTIONS

- Read every line of the provided source file(s). Do not skip sections.
- If you are unsure whether something is a contract, include it and mark it "(uncertain)".
- Do NOT use contract IDs from any other document. Assign no IDs.
- Do NOT produce verification scripts or ast-grep rules. Discovery only.
- Adapt your analysis to `objc` idioms -- for example, use language-appropriate terminology for events, notifications, lifecycle hooks, and synchronization primitives.



## Step 0 Discovery Note
The following related files were found by static scan (not included in full -- reference them in Section 4):
- /Users/justinlee/dev/nineyiappshop/NineyiAppShop/DCWKWebViewController.swift
- /Users/justinlee/dev/nineyiappshop/NineyiAppShop/NYCMSBasedViewController.m
- /Users/justinlee/dev/nineyiappshop/NineyiAppShop/NYCMSLaunchViewController.m
- /Users/justinlee/dev/nineyiappshop/NineyiAppShop/NYECouponListHelper.m
- /Users/justinlee/dev/nineyiappshop/NineyiAppShop/NYECouponListVC.m
//
//  NYNotificationPresenter.m
//  NineyiAppShop
//
//  Created by Sean on 2015/5/25.
//  Copyright (c) 2015年 91App. All rights reserved.
//

#import "NYNotificationPresenter.h"
#import "NineyiAppShop-Swift.h"

#import "NYHomeViewPagerController.h"
#import "NYHotSaleRankListVC.h"
#import "NYCouponDetailVC.h"

#import "NYNotificationViewPagerController.h"

#import "NYSalePageViewController.h"
#import "NYLocationPointEventDetailVC.h"

#import "NYMemberPointExchangeVC.h"

#import <NYCore/NYStatisticHelper.h>
#import <NYCore/NYNotificationHelper.h>
#import <NYCore/NYCore-Swift.h>
#import "NYPromotionListVC.h"
#import "NYPromotionDetailContainerVC.h"
#import "NYMemberLoyaltyPointCenterVC.h"
#import "NYCMSBasedViewController.h"
#import "NYPromotionEngineDetailVC.h"
#import "NYCartFirstVC.h"

#import <NYCore/NYShopCategoryObject.h>
#import <NYCore/NYInfoModuleObject.h>
#import <NYCore/NYLoginHelper.h>
#import <NYCore/NYCookieManager.h>
#import <NYCore/NYGlobalData.h>
#import <NYCore/NYDataProvider.h>
#import <NYCore/NYUserDefault.h>
#import <NYCore/NYAppSettingsHelper.h>
#import <NYCore/NYUrlHelper.h>

#import "NYInfoModuleDetailViewController.h"
#import "NYInfoModuleListViewController.h"
#import <NYCore/NYLocalizationString.h>
#import <NYCore/UIViewController+NYAlertControllerHelper.h>

#import <NYCore/NYThirdPartyLoginWebBrowserVC.h>
#import "NYECouponDetailViewController.h"

#import "NYADLandingHelper.h"

@interface NYNotificationPushHelper : NSObject

+ (void)activeNavigationController:(UIViewController *)activeNavController
                pushViewController:(UIViewController *)viewController
              thenSelectTabAtIndex:(NSInteger)index;
@end

@implementation NYNotificationPushHelper

// 藉由指定 NYTabBarItemType，去找到其對應的 Index 再做轉導
+ (void)activeNavigationController:(UIViewController *)activeNavController
                pushViewController:(UIViewController *)viewController
               thenSelectTabAtType:(NYTabBarItemType)type {
    
    UITabBarController *tabBarController = activeNavController.tabBarController;
    NSInteger itemIndex = [(NYTabBarControllerV2 *)tabBarController getTabBarItemIndexOf:type];
    [self activeNavigationController:activeNavController pushViewController:viewController thenSelectTabAtIndex:itemIndex];
}

// Index 是指 TabBar 上對應的位置
+ (void)activeNavigationController:(UIViewController *)activeNavController
                pushViewController:(UIViewController *)viewController
              thenSelectTabAtIndex:(NSInteger)index {
    // Note: 應KK要求，先在選定的tab推頁之後才切換。所以selectFirstTab要在pushViewController之後執行。
    // TODO: 在navigation controller上增加category
    
    UITabBarController *tabBarController = activeNavController.tabBarController;
    UIViewController *selectedViewController = tabBarController.viewControllers[index];
    UINavigationController *navController;
    
    if ([selectedViewController isKindOfClass:[UINavigationController class]]){
        navController = (UINavigationController *)selectedViewController;
    }
    
    BOOL needPush = (viewController != nil);
    BOOL isCurrentTab = (tabBarController.selectedViewController == selectedViewController);
    BOOL needSelectTab = !isCurrentTab || !needPush;
    
    // 如果是當前 tab, 而且沒有要做推頁，即表示要做退頁
    if (isCurrentTab && !needPush) {
        [navController popToRootViewControllerAnimated:YES];
    } else if (needPush) {
        [navController pushViewController:viewController animated:index == tabBarController.selectedIndex ? YES : NO];
    }
    
    if (needSelectTab) {
        [(NYTabBarControllerV2 *)tabBarController selectTabBarItemAt:index];
    }
}

/// Note: 不切換Tab的導頁方式
+ (void)activeNavigationController:(UIViewController *)activeNavController
                pushViewController:(UIViewController *)viewController {
    // Get navigation controller
    UINavigationController *navi = activeNavController.navigationController;
    if ([activeNavController isKindOfClass:[UINavigationController class]]) {
        navi = (UINavigationController *)activeNavController;
    }
    
    // Push
    [navi pushViewController:viewController animated:YES];
}

@end


@implementation NYNotificationPresenter

+ (instancetype)sharedInstance {
    
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[NYNotificationPresenter alloc] init];
    });
    
    return _sharedInstance;
}

__weak static UINavigationController *globalActiveNavigationController;


+ (void)setActiveNavigationController:(UINavigationController *)navController {
    globalActiveNavigationController = navController;
}

- (void)trackingNotificationAction:(RoutingObject *)notif {
    // 各個參數的意思請參照
    // https://wiki.91app.com/pages/viewpage.action?pageId=54709160
    
    // 避免 nil導致 crash & 有說如果沒值, 就不要傳
    void (^addValue)(NSMutableDictionary *, NSString *, NSObject *) = ^(NSMutableDictionary *inputDic, NSString *key, NSObject *value) {
        if (value) {
            [inputDic setValue:value forKey:key];
        }
    };
    
    //Create parameters
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    addValue(parameters, @"ec", NYLocalizedString(@"ga_notification_push", nil));
    addValue(parameters, @"ea", NYLocalizedString(@"ga_action_push_press", nil));
    addValue(parameters, @"el", notif.title);
    addValue(parameters, @"cbd.sid", notif.nyCallBackData[@"sid"]);
    addValue(parameters, @"cbd.ncid", notif.nyCallBackData[@"ncid"]);
    addValue(parameters, @"cbd.st", notif.nyCallBackData[@"st"]);
    addValue(parameters, @"cbd.sys", notif.nyCallBackData[@"sys"]);
    
    //Send event
    [[NYStatisticHelper sharedHelper] sendEventNotificationOpenedWithMessageTitle:notif.title content:notif.content openType:[NYFAConstant kFAParamPush] landingPage:[notif abbreviationStringOfTargetType] cbd:notif.nyCallBackData];
    // TrackingV2 多送 dl 欄位（cbd 有什麼帶什麼）
    NSString *dlValue = [notif parseTrackingEventDLDataFrom:notif.nyCallBackData];
    if (dlValue) {
        NSString *tsValue = [NSString stringWithFormat:@"?%@", dlValue];
        NSDictionary *tsParams = @{@"dl": tsValue};
        [NYTrackingServiceHelper send91TrackingV2WithParameters:tsParams];
    }
}

- (void)processNotificationAction:(RoutingObject *)notif withCompletionBlock:(Completion)completion {
    UIViewController *rootVc;
    RoutingTargetType targetType = notif.targetType;
    
    //1.15.0推播效率化/業績追蹤
    if (notif.frCode && notif.frCode.length > 0) {
        [[NYCookieManager sharedManager] setCookieValue:notif.frCode 
                                          forCookieName:kCOOKIE_NAME_TRACE_FR
                                         expirationDate:[NSDate dateWithTimeIntervalSinceNow:24*60*60]];
    }
    
    if (notif.source == RoutingSourceRef && ![[NYGlobalData shopId] isEqualToNumber:notif.shopID]) {
        targetType = RoutingTargetTypeWebView;
    }
    
    if (targetType == RoutingTargetTypeShopSalePageCategory) {
        rootVc = [self redirectToSalePageCategoryWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeNotificationCenter) {
        rootVc = [self redirectToNotificationCenter];
        
    } else if (targetType == RoutingTargetTypeSalePageV2) {
        rootVc = [self redirectToSalePageWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeQuestionList) {
        rootVc = [self redirectToQuestionList];

    } else if (targetType == RoutingTargetTypeFAQ) {
        rootVc = [self redirectToCustomerServiceCenter];

    } else if (targetType == RoutingTargetTypeCustomerService) {
        rootVc = [self redirectToCustomerInquiry];
        
    }  else if (targetType == RoutingTargetTypeCustomerServiceEntry) {
        rootVc = [self redirectToCustomerServiceEntry];
        
    } else if (targetType == RoutingTargetTypeTradesOrderList) {
        rootVc = [self redirectToTradeOrderList];
        
    } else if (targetType == RoutingTargetTypeInvoice ||
               targetType == RoutingTargetTypeInvoiceV2 ||
               targetType == RoutingTargetTypeTradesOrderDetail ||
               targetType == RoutingTargetTypeTradesOrderDetailV2 ||
               targetType == RoutingTargetTypeCMSGameModule) {
        rootVc = [self redirectToWebViewViaUrlWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeWebView) {
        if ([notif.url isExternalLink]) {
            // 外開瀏覽器
            [self redirectToExternalBrowserWithURL:notif.url];
            return;
        } else {
            rootVc = [self redirectToWebViewViaUrlWithNotificationObj:notif];
        }
        
    } else if(targetType == RoutingTargetTypeCustomUrl) {
        rootVc = [self redirectToWebViewViaCustomFieldWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeFullURL) {
        // full url 的連結沒有限制格式，先確認是否有 customField1 再處理導頁
        [self redirectViaWrappedURLWithNotificationObj:notif completion:completion];
        
        rootVc = nil;
        
    } else if (targetType == RoutingTargetTypeLocationList) {
        rootVc = [self redirectToLocationList];
        
    } else if (targetType == RoutingTargetTypeStoreDetail) {
        rootVc = [self redirectToLocationDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeCouponList) {
        rootVc = [self redirectToCouponList];
        
    } else if (targetType == RoutingTargetTypeMyCouponList) {
        rootVc = [self redirectToMyCouponList];
        
    } else if (targetType == RoutingTargetTypeCoupon) {
        rootVc = [self redirectToCouponDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeAlbum ||
               targetType == RoutingTargetTypeArticle ||
               targetType == RoutingTargetTypeVideo) {
        rootVc = [self redirectToInfoModuleDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeAlbumList) {
        rootVc = [self redirectToInfoModuleListWithType:NYInfoModuleTypeAlbum];
        
    } else if (targetType == RoutingTargetTypeArticleList) {
        rootVc = [self redirectToInfoModuleListWithType:NYInfoModuleTypeArticle];
        
    } else if (targetType == RoutingTargetTypeVideoList) {
        rootVc = [self redirectToInfoModuleListWithType:NYInfoModuleTypeVideo];
        
    } else if (targetType == RoutingTargetTypeInfoModuleList) {
        rootVc = [self redirectToInfoModuleRecommandList];
        
    } else if (targetType == RoutingTargetTypeSearch) {
        rootVc = [self redirectToSearchViewController];
        
    } else if (targetType == RoutingTargetTypeSearchResult) {
        rootVc = [self redirectToSearchWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeECoupon) {
        rootVc = [self redirectToECouponWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeECouponList) {
        rootVc = [self redirectToECouponListWithPageType:NYCouponListV2DataSourceTypeEcoupon];
        
    } else if (targetType == RoutingTargetTypeMemberECouponList) {
        rootVc = [self redirectToMyECouponWithPageType:NYCouponListV2DataSourceTypeEcoupon];
        
    } else if (targetType == RoutingTargetTypeGiftECouponExplanation) {
        rootVc = [self redirectToECouponExplanationWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeGiftECouponList) {
        rootVc = [self redirectToECouponListWithPageType:NYCouponListV2DataSourceTypeGiftEcoupon];
        
    } else if (targetType == RoutingTargetTypeMemberGiftECouponList) {
        rootVc = [self redirectToMyECouponWithPageType:NYCouponListV2DataSourceTypeGiftEcoupon];

    } else if (targetType == RoutingTargetTypeGiftDetail) {
        rootVc = [self redirectToNYGiftDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeFreeShippingECoupon) {
        rootVc = [self redirectToECouponWithNotificationObj:notif];

    } else if (targetType == RoutingTargetTypeFreeShippingECouponList) {
        rootVc = [self redirectToECouponListWithPageType:NYCouponListV2DataSourceTypeFreeShippingECoupon];

    } else if (targetType == RoutingTargetTypeMemberFreeShippingECouponList) {
        rootVc = [self redirectToMyECouponWithPageType:NYCouponListV2DataSourceTypeFreeShippingECoupon];

    } else if (targetType == RoutingTargetTypeHotSaleRankList) {
        rootVc = [self redirectToHotSaleRankListWithShopId:notif.shopID];
        
    } else if (targetType == RoutingTargetTypeHotSaleRankDaily) {
        rootVc = [self redirectToHotSaleRankListWithPeriod:@"daily"];
        
    } else if (targetType == RoutingTargetTypeHotSaleRankWeekly) {
        rootVc = [self redirectToHotSaleRankListWithPeriod:@"weekly"];
        
    } else if (targetType == RoutingTargetTypeActivityDetail) {
        rootVc = [self redirectToActivityDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeLocationPointDetail) {
        rootVc = [self redirectToLocationPointEventDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypePromotionListV2) {
        rootVc = [self redirectToPromotionList];
        
    } else if (targetType == RoutingTargetTypePromotionDetail) {
        rootVc = [self redirectToPromotionDetailWithNotification:notif];
        
    } else if (targetType == RoutingTargetTypeMemberZone) {
        [self redirectToTabBarMemberDetail];
        
    } else if (targetType == RoutingTargetTypeVipMemberProfile) {
        [self redirectToVipMemberProfile];
        
    } else if (targetType == RoutingTargetTypeShoppingCart) {
        [self redirectToShoppingCartWithCode:notif.sendToCartCode];
        
    } else if (targetType == RoutingTargetTypeShoppingCartWithSlaveID) {
        [self redirectToShoppingCartWithSlaveId:notif.targetID];
        
    } else if (targetType == RoutingTargetTypeSCV2) {
        [self redirectToShoppingCartV2WithURL:notif.url];
    } else if (targetType == RoutingTargetTypeBocPayConfirm) {
        // BoC Pay 需要藉由認 host 的方式 parse path 出來轉導
        rootVc = [self redirectToBoCPayConfirmWebViewWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeLinePayConfirm ||
               targetType == RoutingTargetTypePXPayConfirm ||
               targetType == RoutingTargetTypeIcashPayConfirm ||
               targetType == RoutingTargetTypeUnionPayConfirm ||
               targetType == RoutingTargetTypeThirdPartyPayConfirm) {
        // LinePay, PXPay, icash Pay, 第三方支付（EasyWallet, POYA Pay, Wechat Pay HK) 付款結果處理方式相同
        // UnionPay 獨立一個 TargetType 同時為了滿足購物車完成瀏覽器內的結帳流程
        rootVc = [self redirectToThirdPartyPaymentConfirmWebViewWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeLinePayCancel ||
               targetType == RoutingTargetTypePXPayCancel) {
        // LinePay & PXPay 付款結果處理方式相同
        rootVc = [self redirectToThirdPartyPaymentCancelWebViewWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeLoyaltyPoint) {
        rootVc = [self redirectToLoyaltyPointCenter];
        
    } else if (targetType == RoutingTargetTypeCMSHiddenPage) {
        rootVc = [self redirectToCMSHiddenPageWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeCMSCustomPage) {
        rootVc = [self redirectToCMSCustomPageWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeCMSFeverSocialEvents) {
        rootVc = [self redirectToCMSFeverSocialWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeExchangeECouponList) {
        rootVc = [self redirectToMemberPointExchange];
        
    } else if (targetType == RoutingTargetTypeRegularOrder) {
        rootVc = [self redirectToRegularOrder];
        
    } else if (targetType == RoutingTargetTypePromotionEngine) {
        rootVc = [self redirectToPromotionEngineDetailWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeJKOPayPaymentConfirm) {
        rootVc = [self redirectToJKOPayPaymentConfirmWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypePaymentChannelReturn ||
               targetType == RoutingTargetTypeAlipayHKConfirm) {
        // PayMe 付款結果、 AlipayHK 付款成功處理方式相同
        rootVc = [self redirectToPaymentConfirmWithNotificationObj:notif];

    } else if (targetType == RoutingTargetTypeAlipayHKCancel) {
        rootVc = [self redirectToPaymentCancelWithNotificationObj:notif];

    } else if (targetType == RoutingTargetTypePXPartialPickup) {
        rootVc = [self redirectToPXPartialPickupWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypePXPartialPickupPush) {
        rootVc = [self redirectToPXPartialPickupPushWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeThirdpartyBasedOAuthSuccess) {
        [self processThirdpartyBasedOAuthWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeCloseWebviewThenPush) {
        rootVc = [self redirectToSelfDismissWebViewWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeOpenPXPay) {
        [self processOpenPxPay];
        
    } else if (targetType == RoutingTargetTypePrivacyPolicy) {
        rootVc = [self redirectToPrivacyPolicyPage];
        
    } else if (targetType == RoutingTargetTypeChoosingStoreDelivery ||
               targetType == RoutingTargetTypeChoosingStorePickup) {
        [self presentRetailStoreChoosingWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeStaffBoardList) {
        rootVc = [self redirectToStaffBoardList];
        
    } else if (targetType == RoutingTargetTypeStaffBoardDetail) {
        rootVc = [self redirectToStaffBoardDetailWithObject:notif];
    
    } else if (targetType == RoutingTargetTypeTagCategory) {
        rootVc = [self redirectToTagCategoryWithObject:notif];
        
    } else if (targetType == RoutingTargetTypeNewestCategory) {
        rootVc = [self redirectToNewestCategoryList];
    
    } else if (targetType == RoutingTargetTypeInvitingFriends) {
        rootVc = [self redirectToInvitingFriendsPage];
        
    } else if (targetType == RoutingTargetTypeEVoucherList) {
        rootVc = [self redirectToEVoucherListWebView];
        
    } else if (targetType == RoutingTargetTypeSubscriptionOrder) {
        rootVc = [self redirectToRegularOrder];
        
    } else if (targetType == RoutingTargetTypeInvitationCodeHistory) {
        rootVc = [self redirectToInvitationCodeHistoryPage];
        
    } else if (targetType == RoutingTargetTypeBackInStockAlert) {
        rootVc = [self redirectToArrivalNoticeList];
        
    } else if (targetType == RoutingTargetTypeMyFavorite) {
        rootVc = [self redirectToMyFavoriteList];
        
    } else if (targetType == RoutingTargetTypeRecentlyBrowse) {
        rootVc = [self redirectToRecentlyBrowse];
        
    } else if (targetType == RoutingTargetTypeCarrierBarcode) {
        [self showCarrierBarcode];
        
    } else if (targetType == RoutingTargetTypeEditCarrierBarcode) {
        [self showEditCarrierBarcode];
        
    } else if (targetType == RoutingTargetTypeMemberBarcode) {
        [self showMemberBarcode];

    } else if (targetType == RoutingTargetTypeMemberBarcodeOrCarrierBarcode) {
        [self showMemberBarcodeOrCarrierBarcodeAfterLogin];

    } else if (targetType == RoutingTargetTypeBrandPage) {
        // 品牌頁
        rootVc = [self redirectToBrandPageWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeBrandList) {
        // 品牌總覽
        rootVc = [self redirectToBrandListWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeBarcodeScanner) {
        // barcode 掃描器
        rootVc = [self openBarcodeScannerWithNotificationObj:notif];
        
    } else if (targetType == RoutingTargetTypeMemberShipCardManagePage) {
        // 會員多卡管理頁
        rootVc = [self openMemberShipCardManagePage];
        
    } else if (targetType == RoutingTargetTypeOuterTradesHistory) {
        // 交易紀錄頁（webView）
        rootVc = [NYWKWebViewController outerTradesHistoryWebVC];
        
    } else if (targetType == RoutingTargetTypeOuterTradesWalletHistoryAll) {
        // 交易紀錄頁 - 錢包交易紀錄 (WebView)
        rootVc = [NYWKWebViewController outerTradesWalletHistoryAllWebVC];
        
    } else if (targetType == RoutingTargetTypePayments91APPWallet) {
        NSString *queryString = [NSString stringWithFormat:@"?%@", notif.url.query];
        if ([notif.url.scheme isEqualToString:@"wallet-sdk"]) {
            // url scheme pattern 有差異，需把 query 內容差異補齊
            queryString = [NSString stringWithFormat:@"%@&target=%@", queryString, notif.url.host];
        }

        NSURLComponents *components = [NSURLComponents componentsWithString:queryString];
        [self redirectToPaymentWalletWithQueryItems:components.queryItems];
    } else if (targetType == RoutingTargetTypeOmnichatWebVC ||
               targetType == RoutingTargetTypeNine1Chat) {
        // 客服聊聊
        [self presentCustomerLiveChatWebVCWithQuery:notif.customField1];

    } else if (targetType == RoutingTargetTypeZendesk) {
        // zendesk
        [self pushToZendeskWithCompletion:completion];

    } else if (targetType == RoutingTargetTypeEstamp) {
        // 印花 webView
        rootVc = [NYWKWebViewController estampListWebVCWithQueryValue:notif.customField1];
        
    } else if (targetType == RoutingTargetTypeUnclaimedCoupons) {
        // 新版優惠券未領取頁
        rootVc = [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeUnclaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeEcoupon newCouponType:NYNewCouponMappingTypeAll newCouponCustomId:@"" autoClaimECouponID:nil];
        
    } else if (targetType == RoutingTargetTypeClaimedCoupons) {
        // 新版優惠券已領取頁
        rootVc = [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeClaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeEcoupon newCouponType:NYNewCouponMappingTypeAll newCouponCustomId:@"" autoClaimECouponID:nil];

    } else if (targetType == RoutingTargetTypeAutoClaimCoupon) {
        // 新版優惠券已領取頁，自動領券
        rootVc = [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeClaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeEcoupon newCouponType:NYNewCouponMappingTypeAll newCouponCustomId:@"" autoClaimECouponID:notif.targetIDString];

    } else if (targetType == RoutingTargetTypeUnclaimedCustomCoupons) {
        // 新版優惠券未領取頁自訂券
        NSString *customId = @"";
        if (notif.customField1) {
            customId = notif.customField1;
        }
        rootVc = [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeUnclaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeEcoupon newCouponType:NYNewCouponMappingTypeCustom newCouponCustomId:customId autoClaimECouponID:nil];

    } else if (targetType == RoutingTargetTypeClaimedCustomCoupons) {
        // 新版優惠券已領取頁自訂券
        NSString *customId = @"";
        if (notif.customField1) {
            customId = notif.customField1;
        }
        rootVc = [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeClaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeEcoupon newCouponType:NYNewCouponMappingTypeCustom newCouponCustomId:customId autoClaimECouponID:nil];

    } else if (targetType == RoutingTargetTypeCustomCouponDetail) {
        // 判斷是否為收到轉贈的推播通知，如果是就走已領取詳情頁的邏輯
        NSString *sysValue = [notif.nyCallBackData[@"sys"] lowercaseString];
        BOOL isTransferNoti = [sysValue isEqualToString:@"coupontransfer"];
        rootVc = [[NYNewCouponDetailViewController alloc] initWithCouponId:notif.targetID slaveId:@0 isFromClaimedPage:isTransferNoti];

    } else if (targetType == RoutingTargetTypeLiveBuyVideo) {
        rootVc = [NYWKWebViewController liveBuyVideoWebVCWithUrl:notif.url];

    } else if (targetType == RoutingTargetTypeDesignCloudWebPage) {
        rootVc = [[DCWKWebViewController alloc] initWithUrl:notif.url];
        
    } else if (targetType == RoutingTargetTypeDesignCloudNative) {
        // 使用 DesignCloudBridge 取得正確的視圖控制器
        NSString *urlPath = notif.url.path;
        if (globalActiveNavigationController && [globalActiveNavigationController isKindOfClass:[NaviController class]]) {
            rootVc = [DesignCloudBridge getViewControllerWithPath:urlPath navigator:(NaviController *)globalActiveNavigationController];
            if (!rootVc) {
                // 如果無法取得視圖控制器，則使用 WebView 作為備用方案
                targetType = RoutingTargetTypeDesignCloudWebPage;

                rootVc = [[DCWKWebViewController alloc] initWithUrl:notif.url];
            }
        } else {
            // 如果不是 NaviController，則使用 WebView
            targetType = RoutingTargetTypeDesignCloudWebPage;

            rootVc = [[DCWKWebViewController alloc] initWithUrl:notif.url];
        }
    } else {
        // RoutingTargetTypeUnknown
    }
     
    if (targetType == RoutingTargetTypeShopHome) {
        [NYNotificationPushHelper activeNavigationController:globalActiveNavigationController pushViewController:nil thenSelectTabAtType:NYTabBarItemTypeIndex];
        
    } else if (targetType == RoutingTargetTypeSchemeRedirect) {
        [self processSchemeRedirectWithNotificationObj:notif];
        
    } else if (rootVc && targetType != RoutingTargetTypeUnknown) {
        [self pushToVC:rootVc targetType:targetType completion:completion];
        
    }
}

- (void)navigateToTargetPageWith:(RoutingObject *)notif {
    [self processNotificationAction:notif shouldSendTrackingLogs:NO];
}

- (void)processPushNotificationAction:(RoutingObject *)notif {
    [self processNotificationAction:notif shouldSendTrackingLogs:YES];
}

- (void)processNotificationAction:(RoutingObject *)notif shouldSendTrackingLogs:(BOOL)shouldTrack {
    if (shouldTrack) {
        [self trackingNotificationAction:notif];
    }
    [self processNotificationAction:notif withCompletionBlock:nil];
}

- (void)processADElementAction:(NYADElementObject *)adElement {
    UIViewController *targetVC = [[[NYADLandingHelper alloc] init] viewControllerForADElement:adElement];
    
    //FIXME:這寫法其實不好, 暫時的解法
    UIViewController *rootVC = [[UIApplication sharedApplication] getKeyWindow].rootViewController;
    if ([rootVC isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabBarVC = (UITabBarController *)rootVC;
        [NYNotificationPushHelper activeNavigationController:tabBarVC.selectedViewController pushViewController:targetVC thenSelectTabAtIndex:tabBarVC.selectedIndex];
    }
}

#pragma Notification Actions

- (UIViewController *)redirectToSalePageCategoryWithNotificationObj:(RoutingObject *)notif {
    BrowserLayout layoutType = (notif.source == RoutingSourceUrl) ? (BrowserLayout)notif.customField1.integerValue : BrowserLayoutUnknown;
    NSString *serviceType = notif.customField3;
    
    UIViewController *itemListVC;
    if (notif.url) {
        NSURLComponents *urlComponent = [[NSURLComponents alloc] initWithURL:notif.url resolvingAgainstBaseURL:NO];
        NSString *queryString = urlComponent.query;
        SearchResultFilterObject *filterObj = [[SearchResultFilterObject alloc] initWithQueryString:queryString];
        
        itemListVC = [NYLaunchHelper itemListVCWithCategoryId:notif.targetID filterObj:filterObj layoutType:layoutType sortKey:notif.customField2 serviceType:serviceType];
    } else if (notif.customField1) {
        // 小分類頁的話通常 categoryId 都帶在 customField1
        int categoryId = [notif.customField1 intValue];
        itemListVC = [NYLaunchHelper itemListVCWithCategoryId:@(categoryId) filterObj:nil layoutType:layoutType sortKey:notif.customField2 serviceType:serviceType];
    } else {
        // Do Nothing
    }
    
    return itemListVC;
}

- (UIViewController *)redirectToNotificationCenter {
    NYNotificationViewPagerController *svc = [[NYNotificationViewPagerController alloc] initWithInitialPage:NYNotificationPageSystemMessage redDotDelegate:MenuRedDotManager.shared];
    svc.title = NYLocalizedString(@"msg_center_system_message", nil);
    return svc;
}

- (UIViewController *)redirectToSalePageWithNotificationObj:(RoutingObject *)notif {
    // 如果是隱賣商品，salePageID 就帶 nil 給商品頁初始化，實際的 salePageID 會從 API 取得
    BOOL isHiddenProduct = notif.targetIDString != nil;
    NSNumber *salePageID = isHiddenProduct ? nil : notif.targetID;
    NSString *salePageCode = notif.targetIDString ?: nil;
    NYSalePageViewController *salePageVC = [NYSalePageViewController viewControllerWithSalePageId:salePageID
                                                                                     salePageCode:salePageCode
                                                                               isFromShoppingCart:notif.isFromCart];
    
    return salePageVC;
}
// 24.8 點擊進到贈品詳情頁(放大圖)
- (UIViewController *)redirectToNYGiftDetailWithNotificationObj:(RoutingObject *)notif {
    NSNumber *giftID = notif.targetID;
    NYPromotionEngineGiftDetailVC *giftDetailVC = [[NYPromotionEngineGiftDetailVC alloc] initWithGiftID:giftID];
    // 找到正確的 VC & NavigationController
    UINavigationController *topNavController = [UIViewController topNavigationController];
    if (topNavController) {
        [topNavController pushViewController:giftDetailVC animated:YES];
        return nil;
    } else {
        return giftDetailVC;
    }
}

- (UIViewController *)redirectToCustomerServiceCenter {
    return [NYWKWebViewController customerServiceCenterWebVC];
}

- (UIViewController *)redirectToQuestionList {
    return [NYWKWebViewController questionListWebVC];
}

- (UIViewController *)redirectToTradeOrderList {
    return [NYWKWebViewController tradesOrderListWebVC];
}

- (UIViewController *)redirectToCustomerInquiry {
    return [NYWKWebViewController customerInquiryWebVC];
}

- (UIViewController *)redirectToCustomerServiceEntry {
    return [NYWKWebViewController shopCustomerServiceEntryWebVC];
}

- (void)redirectToExternalBrowserWithURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url
                                       options:@{}
                             completionHandler:nil];
}

- (UIViewController *)redirectToWebViewViaUrlWithNotificationObj:(RoutingObject *)notif {
    return [NYWKWebViewController standardWebVCWithUrl:notif.url allowsInlineMediaPlayback:YES];
}

- (UIViewController *)redirectToWebViewViaCustomFieldWithNotificationObj:(RoutingObject *)notif {
    // only one of "ShopHome" / "MallHome" will be invoked in one app
    // TODO: goo.gl 還可以用? 先純粹改 WK 不動邏輯
    NSString *urlString = [NSString stringWithFormat:@"https://goo.gl/%@", notif.customField1];
    NSURL *url = [NSURL URLWithString:urlString];
    NYWKWebViewController *vc = [NYWKWebViewController standardWebVCWithUrl:url allowsInlineMediaPlayback:YES];
    return vc;
}

- (UIViewController *)redirectToSelfDismissWebViewWithNotificationObj:(RoutingObject *)notif {
    NYWKWebViewController *vc = [NYWKWebViewController standardWebVCWithUrl:notif.url allowsInlineMediaPlayback:YES];
    vc.dismissStatus = NYWKWebViewSelfDismissStatusPageLoading;
    return vc;
}

- (void)redirectViaWrappedURLWithNotificationObj:(RoutingObject *)notif completion:(Completion)completion {
    // 取代goo.gl，後端給的 (customField1) 值可能為一串 URL 短網址 or 官網網址
    NSString *customField = notif.customField1;
    
    if (customField) {
        NSURL *url = [NSURL mwebParseWithString:customField];
        
        if (!url) {
            // 可能有特殊字元，嘗試重組 url
            url = [NSURL recomposeWithString:customField];
            // log unexpected url
            [NYCrashlyticsHelper recordWithUnexpectedURL:customField];
        }
        
        [self unwrapFullURLWith:url completion:completion];
        
    } else {
        // URL redirect (scheme://fullurl/{導頁 url})
        [self unwrapTargetURLWith:notif.url completion:completion];
    }
}

- (void)unwrapFullURLWith:(NSURL *)url completion:(Completion)completion {
    RoutingObject *notifObj = [[RoutingObject alloc] initWithUrlString:url.absoluteString];
    [self processNotificationAction:notifObj withCompletionBlock:completion];
}

/**
 * Parse Target URL
 *
 * 完整的 url 會長這樣：「scheme://fullurl/{導頁 url}」
 *
 * path format 會是：「/(真正要導頁的 url str)」，因此取「/」以後的 subString
 */
-(void)unwrapTargetURLWith:(NSURL *)url completion:(Completion)completion {
    NSString *targetPath = url.path;
    NSString *redirectURLString = [targetPath substringFromIndex:1];
    if (redirectURLString) {
        RoutingObject *notifObj = [[RoutingObject alloc] initWithUrlString:redirectURLString];
        [self processNotificationAction:notifObj withCompletionBlock:completion];
    }
}

- (UIViewController *)redirectToLocationList {
    NYStoreLocationListViewController *vc = [[NYStoreLocationListViewController alloc] initWithShopId:[NYGlobalData shopId]];
    return vc;
}

- (UIViewController *)redirectToLocationDetailWithNotificationObj:(RoutingObject *)notif {
    NYStoreLocationInfoDetailViewController *vc = [[NYStoreLocationInfoDetailViewController alloc] initWithStoreId:notif.targetID];
    return vc;
}

- (UIViewController *)redirectToCouponList {
    return [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeUnclaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeCoupon newCouponType:NYNewCouponMappingTypeStore newCouponCustomId:@"" autoClaimECouponID:nil];
}

- (UIViewController *)redirectToMyCouponList {
    return [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeClaimedPage oldCouponSourceType:NYCouponListV2DataSourceTypeCoupon newCouponType:NYNewCouponMappingTypeStore newCouponCustomId:@"" autoClaimECouponID:nil];
}

- (UIViewController *)redirectToCouponDetailWithNotificationObj:(RoutingObject *)notif {
    NYCouponDetailVC *vc = [[NYCouponDetailVC alloc] initWithCouponId:notif.targetID];
    return vc;
}

- (UIViewController *)redirectToInfoModuleDetailWithNotificationObj:(RoutingObject *)notif {
    NYInfoModuleObject *obj = [[NYInfoModuleObject alloc] initWithJSONDictionary:@{@"type": notif.targetCode.lowercaseString, @"id": notif.targetID}];
    NYInfoModuleDetailViewController *detailVC = [[NYInfoModuleDetailViewController alloc] initWithInfoModuleObject:obj];
    return detailVC;
}

- (UIViewController *)redirectToInfoModuleListWithType:(NYInfoModuleType)infoType {
    NYInfoModuleListViewController *vc = [[NYInfoModuleListViewController alloc] initWithInfoModuleType:infoType shopId:[NYGlobalData shopId]];
    return vc;
}

- (UIViewController *)redirectToInfoModuleRecommandList {
    NYInfoModuleListViewController *vc = [[NYInfoModuleListViewController alloc] initInfoRecommandWithShopId:[NYGlobalData shopId] isOnViewPager:NO];
    return vc;
}

- (UIViewController *)redirectToSearchViewController {
    SearchViewController *searchVC = [[SearchViewController alloc] init];
    return searchVC;
}

- (UIViewController *)redirectToSearchWithNotificationObj:(RoutingObject *)notif {
    NSString *apnsSearchKeyword = notif.customField1;
    if (apnsSearchKeyword && apnsSearchKeyword.length > 0) {
        // 推播進來的 pattern
        UIViewController *vc = [[SearchResultViewController alloc] initWithKeyword:apnsSearchKeyword];
        return vc;
    }
    // 一般網址的 pattern
    NSURL *url = [NSURL mwebParseWithString:notif.url.absoluteString];
    NSURLComponents *urlComponent = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    NSString *queryString = urlComponent.query;
    UIViewController *vc = [[SearchResultViewController alloc] initWithQueryStrings:queryString];
    return vc;
}

- (UIViewController *)redirectToECouponWithNotificationObj:(RoutingObject *)notif {
    if (notif.isFromCart) {
        NYECouponDetailViewController *eCouponDetailVC = [NYECouponDetailViewController vcWithECouponId:notif.targetID
                                                                                     isFromShoppingCart:YES];
        return eCouponDetailVC;
    } else {
        // 判斷是否為收到轉贈的推播通知，如果是就走未領取詳情頁的邏輯
        NSString *sysValue = [notif.nyCallBackData[@"sys"] lowercaseString];
        BOOL isTransferNoti = [sysValue isEqualToString:@"coupontransfer"];
        NYECouponDetailSpecialSource source = (notif.isRedirectActivity) ? NYECouponDetailSpecialSourceActivityDetailVC : NYECouponDetailSpecialSourceNone;
        NYECouponDetailViewController *eCouponDetailVC = [NYECouponDetailViewController vcWithECouponId:notif.targetID
                                                                                          specialSource:source
                                                                                      isFromClaimedPage:isTransferNoti];
        return eCouponDetailVC;
    }
}

- (UIViewController *)redirectToECouponExplanationWithNotificationObj:(RoutingObject *)notif {
    // 判斷是否為收到轉贈的推播通知，如果是就走已領取詳情頁的邏輯
    NSString *sysValue = [notif.nyCallBackData[@"sys"] lowercaseString];
    BOOL isTransferNoti = [sysValue isEqualToString:@"coupontransfer"];
    NYECouponExplanationViewController *explanationVC = [NYECouponExplanationViewController
                                                         viewControllerWithECouponId:notif.targetID
                                                         eCouponSlaveId:@0
                                                         specialSource:NYECouponDetailSpecialSourceNone
                                                         isFromClaimedPage:isTransferNoti];
    return explanationVC;
}

- (UIViewController *)redirectToECouponListWithPageType:(NYCouponListV2DataSourceType)pageType {
    NYNewCouponMappingType newType;
    switch (pageType) {
    case NYCouponListV2DataSourceTypeEcoupon:
            newType = NYNewCouponMappingTypeDiscount;
            break;
    case NYCouponListV2DataSourceTypeGiftEcoupon:
            newType = NYNewCouponMappingTypeGift;
            break;
    case NYCouponListV2DataSourceTypeFreeShippingECoupon:
            newType = NYNewCouponMappingTypeShipping;
            break;
    case NYCouponListV2DataSourceTypeCoupon:
            newType = NYNewCouponMappingTypeStore;
            break;
    }
    return [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeUnclaimedPage oldCouponSourceType:pageType newCouponType:newType newCouponCustomId:@"" autoClaimECouponID:nil];
}

- (UIViewController *)redirectToMyECouponWithPageType:(NYCouponListV2DataSourceType)pageType {
    NYNewCouponMappingType newType;
    switch (pageType) {
    case NYCouponListV2DataSourceTypeEcoupon:
            newType = NYNewCouponMappingTypeAll;
            break;
    case NYCouponListV2DataSourceTypeGiftEcoupon:
            newType = NYNewCouponMappingTypeGift;
            break;
    case NYCouponListV2DataSourceTypeFreeShippingECoupon:
            newType = NYNewCouponMappingTypeShipping;
            break;
    case NYCouponListV2DataSourceTypeCoupon:
            newType = NYNewCouponMappingTypeStore;
            break;
    }
    return [NYNewCouponContainerViewController initWithTypesWithPageType:NYMainCouponPageTypeClaimedPage oldCouponSourceType:pageType newCouponType:newType newCouponCustomId:@"" autoClaimECouponID:nil];
}

- (UIViewController *)redirectToHotSaleRankListWithShopId:(NSNumber *)shopId {
    NYHotSaleRankListVC *hotSaleRankVC = [[NYHotSaleRankListVC alloc] init];
    [hotSaleRankVC setContent:shopId];
    return hotSaleRankVC;
}

- (UIViewController *)redirectToHotSaleRankListWithPeriod:(NSString *)period {
    NYHotSaleRankListVC *hotSaleRankVC = [[NYHotSaleRankListVC alloc] init];
    [hotSaleRankVC setContent:period];
    return hotSaleRankVC;
}

- (UIViewController *)redirectToActivityDetailWithNotificationObj:(RoutingObject *)notif {
    NSInteger activityID = notif.targetID.integerValue;
    NYActivityDetailVC *vc = [[NYActivityDetailVC alloc] initWithActivityID:activityID];
    return vc;
}

- (UIViewController *)redirectToLocationPointEventDetailWithNotificationObj:(RoutingObject *)notif {
    [[NYThirdPartySSOHelper shared] recordNotificationObjectIfNeeded:notif];
    UIViewController *vc = [[NYLocationPointEventDetailVC alloc] initWithLocationPointEventId:notif.targetID];
    return vc;
}

- (UIViewController *)redirectToPromotionList {
    NYPromotionListVC *promotionListVC = [[NYPromotionListVC alloc] initWithShopId:[NYGlobalData shopId]];
    return promotionListVC;
}

- (UIViewController *)redirectToPromotionDetailWithNotification:(RoutingObject *)notif {
    NYPromotionDetailContainerVC *vc = [[NYPromotionDetailContainerVC alloc] initWithShopID:[NYGlobalData shopId]
                                                                                promotionID:notif.targetID
                                                                         isFromShoppingCart:notif.isFromCart];
    return vc;
}

- (void)redirectToTabBarMemberDetail {
    NYTabBarControllerV2 *tabBarController = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
    [tabBarController selectTabBarItemOf:NYTabBarItemTypeMemberDetail];
}

- (void)redirectToVipMemberProfile {
    BOOL (^typeCheckBlock)(id target, Class targetClass) = ^(id target, Class targetClass){
        BOOL result = [target isKindOfClass:targetClass];
        NSAssert(result, @"Wrong Type, NYTabBarController 有改？");
        return result;
    };
    
    //TODO:太多直接取特定Index, 這個只要Tabbar一改就會出事
    if (typeCheckBlock([globalActiveNavigationController tabBarController], [NYTabBarControllerV2 class])) {
        NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
        
        //Get member navigation controller
        UINavigationController *naviVC = [tabbarVC fetchNaviControllerWith:NYTabBarItemTypeMemberDetail];
        
        //Setup flag (這樣才會跳資料填寫)
        //2019/9/26 : API 會決定有沒有資料填寫頁，launch 時存在 NYUserDefault
        if (NYUserDefaultV2.isShowCustomVipMember == YES) {
            if (typeCheckBlock(naviVC.viewControllers.firstObject, [NYCustomVipMemberViewController class])) {
                NYCustomVipMemberViewController *memberVC = (NYCustomVipMemberViewController *)naviVC.viewControllers.firstObject;
                [memberVC setIsForceShowMemberCard:[NYUserDefault isShowVipMemberInfo]];
            }
        } else {
            if (typeCheckBlock(naviVC.viewControllers.firstObject, [NYMemberV2ViewController class])) {
                NYMemberV2ViewController *memberVC = (NYMemberV2ViewController *)naviVC.viewControllers.firstObject;
                memberVC.isForceShowMemberCard = [NYUserDefault isShowVipMemberInfo];
            }
        }
        
        //前往會員專區第一頁
        [naviVC popToRootViewControllerAnimated:NO];
        [tabbarVC selectTabBarItemOf:NYTabBarItemTypeMemberDetail];
    }
}

- (void)redirectToShoppingCartWithCode: (NSString *)code {
    NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
    [tabbarVC presentCartWith:code];
}

- (void)redirectToShoppingCartWithSlaveId: (NSNumber *)salveID {
    NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
    if (salveID) {
        [tabbarVC presentCartWithGiftCouponSlaveID: salveID];
    } else {
        [tabbarVC presentShoppingCart];
    }
}
/// 開新車路徑
/// 預期 URL 結構為 schema://SCV2?url=https://host/path?query=xxx&query2=ooo&query3=oxox
/// 為避免因 queryItem 解析導致讀取 url 時短少 queryItem，直接取用 url= 後的完整字串組成 redirectURL
/// - Parameters:
///  - url: deeplink URL，預期 queryItem 應含有 url.
- (void)redirectToShoppingCartV2WithURL: (NSURL *)url {
    NSURL* redirectURL;
    NSString * deepLink = url.absoluteString;
    NSRange range = [deepLink rangeOfString:@"url="];
    if (range.location != NSNotFound) {
        NSString *rawURLString = [deepLink substringFromIndex:(range.location + range.length)];
        redirectURL = [NSURL URLWithString:rawURLString];
    } else {
        NSLog(@"No query item with name 'url' found");
    }

    if (!redirectURL) {
        NSLog(@"SCV2 - Query value is not valid url.");
        return;
    }

    NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
    [tabbarVC presentV2CartWithUrl:redirectURL];
}

- (void)redirectToPaymentWalletWithQueryItems:(NSArray<NSURLQueryItem *> *) queryItems {
    NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
    [tabbarVC presentPaymentWalletWith:queryItems];
}

- (UIViewController *)redirectToBoCPayConfirmWebViewWithNotificationObj:(RoutingObject *)notif {
    // Parse Target URL
    NSString *targetPath = notif.url.path;
    NSString *encodeTargetURLString = [targetPath substringFromIndex:1]; // trim "/"
    NSString *decodeTargetURLString = [encodeTargetURLString stringByRemovingPercentEncoding];
    NSURL *targetURL = [[NSURL alloc] initWithString:decodeTargetURLString];
    
    // Create confirm web view
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC confirmPageWith:targetURL];
    return vc;
}

- (UIViewController *)redirectToThirdPartyPaymentConfirmWebViewWithNotificationObj:(RoutingObject *)notif {
    NSURLComponents *components = [NSURLComponents componentsWithURL:notif.url
                                             resolvingAgainstBaseURL:YES];
    // TODO: 等把現行的第三方支付 test case 補齊後，這邊就不該再拿"第一個"query string，這寫法太脆弱
    NSString *targetURLString = components.queryItems.firstObject.value;
    NSURL *targetURL = [[NSURL alloc] initWithString:targetURLString];
    
    // Create confirm web view
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC confirmPageWith:targetURL];
    return vc;
}

- (UIViewController *)redirectToThirdPartyPaymentCancelWebViewWithNotificationObj:(RoutingObject *)notif {
    NSURLComponents *components = [NSURLComponents componentsWithURL:notif.url
                                             resolvingAgainstBaseURL:YES];
    NSString *targetURLString = components.queryItems.firstObject.value;
    NSURL *targetURL = [[NSURL alloc] initWithString:targetURLString];
    
    // Create cancel web view
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC cancelPageWith:targetURL];
    return vc;
}

- (UIViewController *)redirectToLoyaltyPointCenter {
    // 2.32.0 積點
    NYMemberLoyaltyPointCenterVC *vc = [NYMemberLoyaltyPointCenterVC viewController];
    return vc;
}

- (UIViewController *)redirectToCMSHiddenPageWithNotificationObj:(RoutingObject *)notif {
    NSString *pageId = notif.targetIDString ? notif.targetIDString : notif.customField1;
    NYCMSBasedViewController *vc = [NYCMSBasedViewController customViewControllerWithPageType:NYCMSPageTypeHiddenActivity pageId:pageId];
    return vc;
}

- (UIViewController *)redirectToCMSCustomPageWithNotificationObj:(RoutingObject *)notif {
    NSString *pageId = notif.targetIDString ? notif.targetIDString : notif.customField1;
    NSString *serviceType = notif.customField2;
    if ([RetailStoreService isFeatureEnable]) {
        serviceType = [RetailStoreService serviceTypeWithPageId:pageId];
    }
    if ([CMSPresentVCHelper shouldChooseStoreFirstWithType:NYCMSPageTypeCustom pageId:pageId]) {
        [[RetailStoreService shared] setChooseStoreTargetWithCompletion:^{
            [[RetailStoreService shared] clearChooseStoreTarget];
            [[NYNotificationPresenter sharedInstance] navigateToTargetPageWith:notif];
        }];
        RoutingObject *newNotif = [[RoutingObject alloc] initWithTargetType:RoutingTargetTypeChoosingStoreDelivery];
        [self navigateToTargetPageWith:newNotif];
        return nil;
        
    } else {
        NYCMSBasedViewController *vc = [NYCMSBasedViewController customViewControllerWithPageType:NYCMSPageTypeCustom pageId:pageId];
        vc.serviceType = serviceType;
        return vc;
    }
}

- (UIViewController *)redirectToCMSFeverSocialWithNotificationObj:(RoutingObject *)notif {
    NYWKWebViewController *vc = [NYWKWebViewController feverSocialWebVCWithUrl:notif.url];
    return vc;
}

- (UIViewController *)redirectToMemberPointExchange {
    NYMemberPointExchangeVC *vc = [[NYMemberPointExchangeVC alloc] init];
    return vc;
}

- (UIViewController *)redirectToRegularOrder {
    // 2.38.0 定期購管理
    // 2.71 新增：新版定期購管理頁仍由此路轉導
    NYWKWebViewController *vc = [NYWKWebViewController regularOrderManagementWebVC];
    return vc;
}

- (UIViewController *)redirectToPromotionEngineDetailWithNotificationObj:(RoutingObject *)notif {
    // 2.40.0 折扣活動詳細頁 - promotion engine
    NYPromotionEngineDetailVC *vc = [[NYPromotionEngineDetailVC alloc] initWithShopId:[NYGlobalData shopId]
                                                                          promotionId:notif.targetID
                                                                   isFromShoppingCart:notif.isFromCart];
    return vc;
}

- (UIViewController *)redirectToJKOPayPaymentConfirmWithNotificationObj:(RoutingObject *)notif {
    // 2.42.0 街口支付付款結果
    NSString *urlString = [[NSString alloc] initWithFormat:@"%@/V2/ThirdPartyPayment/JkoPaymentConfirm?k=%@", [NYBaseURLConfig baseHTTPSURLWithAppServiceWebPageDomain].absoluteString, notif.targetIDString];
    NSURL *url = [[NSURL alloc] initWithString:urlString];
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC confirmPageWith:url];
    return vc;
}

- (UIViewController *)redirectToPaymentConfirmWithNotificationObj:(RoutingObject *)notif {
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC confirmPageWith:notif.url];
    return vc;
}

- (UIViewController *)redirectToPaymentCancelWithNotificationObj:(RoutingObject *)notif {
    NYThirdPartyPaymentWebVC *vc = [NYThirdPartyPaymentWebVC cancelPageWith:notif.url];
    return vc;
}

- (UIViewController *)redirectToPXPartialPickupWithNotificationObj:(RoutingObject *)notif {
    [[NYThirdPartySSOHelper shared] recordTargetUrlIfNeeded:notif.url];
    NYPXMartPartialPickupWebVC *vc = [[NYPXMartPartialPickupWebVC alloc] initWithStartUrl:notif.url];
    return vc;
}

- (UIViewController *)redirectToPXPartialPickupPushWithNotificationObj:(RoutingObject *)notif {
    NSURL *url = [NSURL URLWithString:notif.customField1];
    if (url == nil) {
        return nil;
    }
    [[NYThirdPartySSOHelper shared] recordTargetUrlIfNeeded:url];
    NYPXMartPartialPickupWebVC *vc = [[NYPXMartPartialPickupWebVC alloc] initWithStartUrl:url];
    return vc;
}

- (UIViewController *)redirectToPrivacyPolicyPage {
    NYWKWebViewController *vc = [NYWKWebViewController appPrivacyWebVC];
    return vc;
}

- (void)processThirdpartyBasedOAuthWithNotificationObj:(RoutingObject *)notif {
    [[NYThirdPartySSOHelper shared] analyzeSSOAuthWithUrl:notif.url];
    NSString *token = [NYThirdPartySSOHelper shared].thirdPartySsoToken;
    if (!token) { return; }
    
    if ([[NYThirdPartySSOHelper shared] needsLoginFirst] && ![NYLoginHelper sharedInstance].isLogin) {
        NYSSOType ssoType = [NYThirdPartySSOHelper shared].type;
        NSURL *destinationUrl;
        RoutingObject *redirectNotifObj;
        NYThirdPartyLoginWebBrowserVC *tpLoginVC;
        UINavigationController *webNavi;
        UIViewController *visibleVC;
        
        switch (ssoType) {
            case NYSSOTypeUrl: {
                // 外導內、web導頁中未特別用 LoginVCInfo completionHandler 指定登入後推頁者
                destinationUrl = [[NYThirdPartySSOHelper shared] getDestinationUrl];
                redirectNotifObj = [[RoutingObject alloc] initWithUrlString:destinationUrl.absoluteString];
                tpLoginVC = [NYThirdPartyLoginWebBrowserVC viewControllerWithThirdPartyToken:token loginSuccessCompletionBlock:^{
                    [self navigateToTargetPageWith:redirectNotifObj];
                }];
                webNavi = [[UINavigationController alloc] initWithRootViewController:tpLoginVC];
                webNavi.modalPresentationStyle = UIModalPresentationFullScreen;
                [self dismissThirdPartyLoginVCIfNeeded];
                [globalActiveNavigationController presentViewController:webNavi animated:YES completion:nil];
                break;
            }
                
            case NYSSOTypeNotificationObject: {
                // 外導內、web導頁中未特別用 LoginVCInfo completionHandler 指定登入後推頁者
                redirectNotifObj = [NYThirdPartySSOHelper shared].notif;
                tpLoginVC = [NYThirdPartyLoginWebBrowserVC viewControllerWithThirdPartyToken:token loginSuccessCompletionBlock:^{
                    [self navigateToTargetPageWith:redirectNotifObj];
                }];
                webNavi = [[UINavigationController alloc] initWithRootViewController:tpLoginVC];
                webNavi.modalPresentationStyle = UIModalPresentationFullScreen;
                [self dismissThirdPartyLoginVCIfNeeded];
                [globalActiveNavigationController presentViewController:webNavi animated:YES completion:nil];
                break;
            }

            case NYSSOTypeNotSpecified:
            default:
                // 用 LoginVCInfo completionHandler 處理登入後推頁者
                visibleVC = globalActiveNavigationController.visibleViewController;
                if (visibleVC && [visibleVC isKindOfClass:[NYThirdPartyLoginWebBrowserVC class]]) {
                    tpLoginVC = (NYThirdPartyLoginWebBrowserVC *)visibleVC;
                    [tpLoginVC processSSOLoginWithToken:token];
                }
                break;
        }
    } else {
        // Do nothing. 停留在原頁
    }
}

- (void)processSchemeRedirectWithNotificationObj:(RoutingObject *)notif {
    NSString *urlScheme = [self getRedirectUrlFromNotificationObj:notif];
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlScheme]] == NO) {
        [self popDefaultDownloadAlert];
        
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlScheme]
                                           options:@{}
                                 completionHandler:nil];
    }
}

- (NSString *)getRedirectUrlFromNotificationObj:(RoutingObject *)notif {
    NSURLComponents *components = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"%@",notif.url]];
    __block NSString *redirectUrlScheme = @"";
    
    [components.queryItems enumerateObjectsUsingBlock:^(NSURLQueryItem *queryItem, NSUInteger idx, BOOL *stop) {
        if ([queryItem.name containsString:@"schemeRedirect"]) {
            redirectUrlScheme = [NSString stringWithFormat:@"%@://", queryItem.value];
            *stop = YES;
        }
    }];
    
    return redirectUrlScheme;
}

- (void)processOpenPxPay {
    AlertPresentViewController *vc;
    NSURLComponents *component = [NSURLComponents new];
    component.scheme = [NYUrlHelper pxPaySSOUrlScheme];
    NSURL *url = component.URL;
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        vc = [OpenPXPayAlertBuilder openAlert];
    } else {
        vc = [OpenPXPayAlertBuilder downloadAlert];
    }
    [[globalActiveNavigationController visibleViewController] presentViewController:vc animated:YES completion:nil];
}

- (void)presentRetailStoreChoosingWithNotificationObj:(RoutingObject *)notif {
    BOOL isChooseStoreEnable = [RetailStoreService isFeatureEnable];
    if (!isChooseStoreEnable) {
        return;
    }
    
    UIViewController *vc = [UIViewController new];
    RoutingTargetType type = notif.targetType;
    switch (type) {
        case RoutingTargetTypeChoosingStorePickup:
            vc = [RetailStoreChoosingPagerVC hourToGoWithTab:RetailStoreLogisticsTypePickupStore];
            break;

        case RoutingTargetTypeChoosingStoreDelivery:
        default:
            vc = [RetailStoreChoosingPagerVC hourToGoWithTab:RetailStoreLogisticsTypeDeliveryStore];
            break;
    }
    
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:vc];
    nc.modalPresentationStyle = UIModalPresentationFullScreen;
    UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
    UIViewController *topViewController = [globalActiveNavigationController topViewController];
    UIViewController *presentingVC = visibleVC;
    BOOL isOnLeftMenu = [visibleVC isKindOfClass:[NYLeftMenuV2ViewController class]];
    if (isOnLeftMenu) {
        // 因為側欄最後會被關掉，所以改用側欄的 presentedVC（topViewController) 來推頁
        presentingVC = topViewController;
        [presentingVC dismissViewControllerAnimated:YES completion:^{
            [presentingVC presentViewController:nc animated:YES completion:nil];
        }];
    } else {
        [presentingVC presentViewController:nc animated:YES completion:nil];
    }
}

- (void)presentDesignCloudAddToCartEventWith:(NYAddToCartRequestObject *)cartObject {
    UIViewController *topVC = globalActiveNavigationController.topViewController;
    [[NYAddToCartHelper sharedInstance] addToCartFromDesignCloudEventWithRequestObject:cartObject from:topVC completion:^(id<NYAddToCartResultProtocol>  _Nullable resultObject, NSError * _Nullable error) {}];
}

- (UIViewController *)redirectToStaffBoardList {
    DCWKWebViewController *vc = [DCWKWebViewController staffBoardStyleListWith:nil];
    return vc;
}

- (UIViewController *)redirectToStaffBoardDetailWithObject:(RoutingObject *)notif {
    NSString *workId = notif.targetIDString ?: @"";
    NYCMSStaffBoardDetailViewController *vc = [NYCMSStaffBoardDetailViewController staffBoardDetailViewControllerWith:workId staffId:@"" isFromFDL:YES];
    return vc;
}

- (UIViewController *)redirectToTagCategoryWithObject:(RoutingObject *)notif {
    NSString *encodedTagStr = notif.encodedTagString ?: @"";
    NSArray <NSString *> *tagList = notif.tagList ?: @[];
    NYSmartTagCategoryListViewController *vc = [NYSmartTagCategoryListViewController createWithEncodedTag:encodedTagStr watchingTag:tagList];
    return vc;
}

- (UIViewController *)redirectToNewestCategoryList {
    return [NYLaunchHelper newestCategoryPage];
}

- (UIViewController *)redirectToInvitingFriendsPage {
    MemberInvitationCodeViewController *vc = [MemberInvitationCodeViewController new];
    return vc;
}

- (UIViewController *)redirectToEVoucherListWebView {
    NSString *pageTypeString = [NYSwiftAdapter convertEVoucherPageTypeToStringWithPageType:EVoucherPageTypeList];
    UIViewController *vc = [NYWKWebViewController eVoucherWebVCWithPageType:pageTypeString];
    return vc;
}

- (UIViewController *)redirectToInvitationCodeHistoryPage {
    MemberInvitationHistoryPagerViewController *vc = [[MemberInvitationHistoryPagerViewController alloc] initWithSelectedIndex:0];
    return vc;
}

- (UIViewController *)redirectToArrivalNoticeList {
    MyFavoritePagerViewController *vc = [[MyFavoritePagerViewController alloc] initWithPageType:MyFavoritePageTypeArrivalNotice];
    return vc;
}

- (UIViewController *)redirectToMyFavoriteList {
    MyFavoritePagerViewController *vc = [[MyFavoritePagerViewController alloc] initWithPageType:MyFavoritePageTypeFavorite];
    return vc;
}

- (UIViewController *)redirectToRecentlyBrowse {
    MyFavoritePagerViewController *vc = [[MyFavoritePagerViewController alloc] initWithPageType:MyFavoritePageTypeRecentlyBrowse];
    return vc;
}

- (UIViewController *)redirectToBrandListWithNotificationObj:(RoutingObject *)notif {
    // 品牌總覽
    BrandListViewController *vc = [BrandListViewController new];
    return vc;
}

- (UIViewController *)redirectToBrandPageWithNotificationObj:(RoutingObject *)notif {
    // 品牌頁
    NSString *brandID = notif.targetIDString ?: @"";
    NSString *sortMode = notif.customField1;
    NSString *shopCategoryID = notif.customField2;
    BrandPageViewController *vc = [[BrandPageViewController alloc] initWithBrandID:brandID
                                                                          sortMode:sortMode
                                                                    shopCategoryID:shopCategoryID];
    return vc;
}

- (void)showCarrierBarcode {
    UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
    
    if ([NYLoginHelper sharedInstance].isLogin) {
        [[NYMemberBarcodePresenterV2 shared] presentCarrierBarcodeIfAvailableOn:visibleVC.view];
    } else {
        [visibleVC ny_displayAlertWithTitle:NYLocalizedString(@"member_phone_barcode", nil)
                                    message:NYLocalizedString(@"backinstock_please_login_or_register", nil)];
    }
}

- (void)showEditCarrierBarcode {
    UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
    
    if ([NYLoginHelper sharedInstance].isLogin) {
        [[NYMemberBarcodePresenterV2 shared] presentSettingCarrierCodeView];
    } else {
        [visibleVC ny_displayAlertWithTitle:NYLocalizedString(@"member_phone_barcode", nil)
                                    message:NYLocalizedString(@"backinstock_please_login_or_register", nil)];
    }
}

- (void)showMemberBarcode {
    UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
    
    if ([NYMemberHelper.shareInstance hasCachedBarcode]) {
        [[NYMemberBarcodePresenterV2 shared] presentBarcode];
        
    } else if ([NYLoginHelper sharedInstance].isLogin && [NYUserDefault shouldVerifyCellphoneWithoutOuterID] &&
        [NYLoginHelper userCellPhoneIsEmpty]) {
        // 驗證手機以取得品牌會員編號
        [[globalActiveNavigationController visibleViewController] presentValidateCellPhoneVC];
        
    } else {
        [visibleVC ny_displayAlertWithTitle:NYLocalizedString(@"sidebar_member_barcode", nil)
                                    message:NYLocalizedString(@"member_barcode_empty_description", nil)];
    }
}

- (void)showMemberBarcodeOrCarrierBarcodeAfterLogin {
    if (![NYLoginHelper sharedInstance].isLogin) {
        UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
        [visibleVC presentLoginVCShouldShowUnLoginMask:NO WithLoginSuccessCompletion:^{
            [self showMemberBarcodeOrCarrierBarcode];
        }];
    } else {
        [self showMemberBarcodeOrCarrierBarcode];
    }
}

- (void)showMemberBarcodeOrCarrierBarcode {
    if ([NYMemberHelper.shareInstance hasCachedBarcode]) {
        [[NYMemberBarcodePresenterV2 shared] presentBarcode];

    } else if ([NYLoginHelper sharedInstance].isLogin && [NYUserDefault shouldVerifyCellphoneWithoutOuterID] &&
        [NYLoginHelper userCellPhoneIsEmpty]) {
        /// 驗證手機以取得品牌會員編號
        [[globalActiveNavigationController visibleViewController] presentValidateCellPhoneVC];

    } else if ([NYGlobalData isTaiwan]) {
        /// 檢查後開啟手機載具
        [[NYMemberBarcodePresenterV2 shared] presentCarrierBarcodeIfAvailableOn:nil];
    }
}

- (UIViewController *)openBarcodeScannerWithNotificationObj:(RoutingObject *)notif {
    NSString *countryCode = [NYGlobalData countryCode];
    NSString *scannerType = [NYCountryConfig productScanTypeIn:countryCode];
    // 商品掃描產品化 產品化的掃瞄器不強制用戶登入 (寶雅客製流程還是要求用戶登入)
    if ([NYLoginHelper sharedInstance].isLogin || [scannerType isEqualToString:@"standard"]) {
        return [NYBarcodeScannerViewController getVC];
    } else {
        UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
        [visibleVC presentLoginVCShouldShowUnLoginMask:NO WithLoginSuccessCompletion:^{
            [self navigateToTargetPageWith:notif];
        }];
    }
    
    return nil;
}

- (UIViewController *)openMemberShipCardManagePage {
    return [[NYMemberShipCardManageViewController alloc] init];
}

- (void)pushToZendeskWithCompletion:(Completion)completion {
    [NYZendeskHelper.shared zendeskMessagingViewControllerWithCompletionHandler:^(UIViewController * _Nullable zendeskVC) {
        [self pushToVC:zendeskVC targetType:RoutingTargetTypeZendesk completion:completion];
    }];
}

- (void)popDefaultDownloadAlert {
    NSString *alertMessage = @"";
    NSString *downloadURLString = @"";
    [self getDefaultDownloadURLString:&downloadURLString andAlertMessage:&alertMessage];
    [self popDownloadAlertWithMessage:alertMessage downloadURLString:downloadURLString];
}

- (void)getDefaultDownloadURLString:(NSString **)downloadURLString andAlertMessage:(NSString **)alertMessage {
    BOOL isPxPartWebView = [NYGlobalData o2oWebViewType] == NYO2OWebViewTypePXMart;
    if (isPxPartWebView) {
        *alertMessage = NYLocalizedString(@"brand_identity_px_pay_not_installed", nil);
        *downloadURLString = [NYUrlHelper pxpayAppStoreUrlString];
    }
}

- (void)popDownloadAlertWithMessage:(NSString *)alertMessage downloadURLString:(NSString *)downloadURLString {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:alertMessage
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:NYLocalizedString(@"common_download", nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * _Nonnull action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:downloadURLString]
                                           options:@{}
                                 completionHandler:nil];
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NYLocalizedString(@"common_cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alertController addAction:confirmAction];
    [alertController addAction:cancelAction];
    [alertController setPreferredAction:confirmAction];
    [[[UIApplication sharedApplication] getKeyWindow].rootViewController presentViewController:alertController
                                                                                 animated:YES
                                                                               completion:nil];
}

- (void)pushToVC:(UIViewController *)rootVc targetType:(RoutingTargetType)targetType completion:(Completion)completion {
    rootVc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    BOOL needLoginPage = targetType == RoutingTargetTypeRegularOrder ||
    targetType == RoutingTargetTypeLoyaltyPoint ||
    targetType == RoutingTargetTypeInvitingFriends ||
    targetType == RoutingTargetTypeInvitationCodeHistory ||
    targetType == RoutingTargetTypeMemberShipCardManagePage ||
    targetType == RoutingTargetTypeTradesOrderList ||
    targetType == RoutingTargetTypeAutoClaimCoupon;
    
    if (needLoginPage && [[NYAppSettingsHelper sharedInstance] thirdpartyBasedAuth] == NYThirdpartyBasedAuthNoData) {
        //針對推頁需登入的情境處理，thirdpartyBasedAuth為NYThirdpartyBasedAuthNoData時，需再call一次API取thirdpartyBasedAuth
        [[NYDataProvider sharedInstance] getShopStaticSettingWithCompletionHandler:^(NSDictionary *responseObject, NSError *error) {
            NSString *returnCode = responseObject[@"ReturnCode"];
            
            // 拿到沒有提示訊息
            if ([returnCode isKindOfClass:[NSString class]] && [returnCode isEqualToString:APIReturnCode.api0001]) {
                NSDictionary *data = responseObject[@"Data"];
                NSDictionary *thirdpartyBasedAuthSetting = ([data isKindOfClass:[NSDictionary class]]) ? data[@"ThirdpartyBasedAuthSetting"] : @{};
                BOOL isThirdpartyBasedAuthEnabled = [thirdpartyBasedAuthSetting[@"IsThirdpartyBasedAuthEnabled"] boolValue];
                
                NYAppSettingsHelper *appSettingsHelper = [NYAppSettingsHelper sharedInstance];
                appSettingsHelper.thirdpartyBasedAuth = isThirdpartyBasedAuthEnabled ? NYThirdpartyBasedAuthEnable : NYThirdpartyBasedAuthDisable;
                
                [NYNotificationPushHelper activeNavigationController:globalActiveNavigationController pushViewController:rootVc thenSelectTabAtType:NYTabBarItemTypeIndex];
            }
        }];
    } else if (needLoginPage && [[NYLoginHelper sharedInstance] isLogin] == NO) {
        [globalActiveNavigationController presentLoginVCShouldShowUnLoginMask:NO
                                                   WithLoginSuccessCompletion:^{
            [self pushToVC:rootVc targetType:targetType completion:completion];
        }];
    } else if (completion) {
        completion(rootVc);
    } else {
        [NYNotificationPushHelper activeNavigationController:globalActiveNavigationController pushViewController:rootVc];
    }
}

- (void)dismissThirdPartyLoginVCIfNeeded {
    // 避免已經有顯示登入頁，會重複顯示
    UIViewController *visibleVC = globalActiveNavigationController.visibleViewController;
    if (visibleVC && [visibleVC isKindOfClass:[NYThirdPartyLoginWebBrowserVC class]]) {
        [visibleVC dismissViewControllerAnimated:NO completion:nil];
    }
}

- (void)presentCustomerLiveChatWebVCWithQuery:(NSString *)queryString {
    void(^present)(UIViewController * ,UIViewController *) = ^(UIViewController *presentingVC, UIViewController *webVC) {
        [presentingVC presentViewController:webVC animated:YES completion:^{
            // 通知聊天室已開啟
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NYChatRoomDidOpen" object:nil];
        }];
    };
    
    UIViewController *webVC = [NYWKWebViewController customerServiceLiveChatVCWith:queryString];
    UIViewController *visibleVC = [globalActiveNavigationController visibleViewController];
    UIViewController *presentingVC = visibleVC;
    BOOL isOnLeftMenu = [visibleVC isKindOfClass:[NYLeftMenuV2ViewController class]];
    if (isOnLeftMenu) {
        UIViewController *topViewController = [globalActiveNavigationController topViewController];
        // 因為側欄最後會被關掉，所以改用側欄的 presentedVC（topViewController) 來推頁
        presentingVC = topViewController;
        [presentingVC dismissViewControllerAnimated:YES completion:^{
            present(presentingVC, webVC);
        }];
    } else {
        present(presentingVC, webVC);
    }
}

@end
//
//  NYNotificationPresenter.h
//  NineyiAppShop
//
//  Created by Sean on 2015/5/25.
//  Copyright (c) 2015年 91App. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NYCore/NYNotificationHelper.h>
@class NYAddToCartRequestObject;

@interface NYNotificationPresenter : NSObject <NYNotificationHelperDelegate>

+ (instancetype)sharedInstance;

+ (void)setActiveNavigationController:(UINavigationController *)navController;

- (void)processNotificationAction:(RoutingObject *)notif withCompletionBlock:(Completion)completion;
- (void)processPushNotificationAction:(RoutingObject *)notif;
- (void)navigateToTargetPageWith:(RoutingObject *)notif;
- (void)processADElementAction:(NYADElementObject *)adElement;
- (void)presentDesignCloudAddToCartEventWith:(NYAddToCartRequestObject *)cartObject;

@end
