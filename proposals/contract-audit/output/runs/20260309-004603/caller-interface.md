## Caller Interface Extract（Step 0.9）

外部模組引用 NYNotificationPresenter 的片段（±5 行上下文）：

### NYCMSBasedViewController.m (6 references)
```
6-//  Copyright © 2018年 91App. All rights reserved.
7-//
8-
9-#import "NYCMSBasedViewController.h"
10-#import "NYCMSBasedLayoutEngine.h"
11:#import "NYNotificationPresenter.h"
12-#import "NYSalePageViewController.h"
13-#import "NYPromotionEngineDetailVC.h"
14-#import "NYPromotionDetailContainerVC.h"
15-#import "NineyiAppShop-Swift.h"
16-
--
456-
457-    if ((notif.targetType == RoutingTargetTypeCMSFeverSocialEvents || notif.targetType == RoutingTargetTypeCMSGameModule)
458-        && ![NYLoginHelper sharedInstance].isLogin) {
459-        [self presentLoginVCShouldShowUnLoginMask:NO
460-                          WithLoginSuccessCompletion:^{
461:            [[NYNotificationPresenter sharedInstance] navigateToTargetPageWith:notif];
462-        }];
463-    } else {
464:        [[NYNotificationPresenter sharedInstance] navigateToTargetPageWith:notif];
465-    }
466-    return YES;
467-}
468-
469-/// 開啟商品頁一律透過此 function 檢查是否為年齡限制商品
--
1699-     didStoredAreaPressedWith:(id<NYCMSMembershipCardViewModelProtocol>)viewModel {
1700-    // MARK: 開啟錢包/儲值頁
1701-    if (viewModel.storedEnable) {
1702-        // 沒開啟 run time 開關的點擊沒動作
1703-        RoutingObject *wallet = [RoutingObject getRoutingWithWalletRelayTypeStoredValueWithIdType:@"MembershipCard" id:viewModel.defaultCardCode];
1704:        [[NYNotificationPresenter sharedInstance]navigateToTargetPageWith:wallet];
1705-    }
1706-}
1707-
1708-- (void)cmsMembershipCardCell:(NYCMSMembershipCardCell *)cell
1709-      didPointAreaPressedWith:(id<NYCMSMembershipCardViewModelProtocol>)viewModel {
--
1977-            // 到店取貨
1978-//            targetType = RoutingTargetTypeChoosingStorePickup;
1979-            break;
1980-    }
1981-    RoutingObject *notif = [[RoutingObject alloc] initWithTargetType:targetType];
1982:    [[NYNotificationPresenter sharedInstance] navigateToTargetPageWith:notif];
1983-}
1984-
1985-#pragma mark - CMSTopMessageViewDelegate
1986-- (void)didClickTopMessage:(CMSTopMessageView *)view {
1987-    [self handleTouchEventWithUrlString:view.viewModel.linkURL];
--
2022-
2023-#pragma mark - CMSBuyAgainModuleCollectionViewCellDelegate
2024-- (void)didTapProductCardWith:(id<NYProductCardViewModelProtocol>)productVM {
2025-    NSNumber *salePageID = [NSNumber numberWithInteger:productVM.salePageId];
2026-    RoutingObject *notif = [RoutingObject salePageWithSalePageID:salePageID];
2027:    [[NYNotificationPresenter sharedInstance] navigateToTargetPageWith:notif];
2028-    
2029-    // FA
2030-    [self sendBuyAgainModuleSelectContentEventWithProductVM:productVM];
2031-}
2032-
```

