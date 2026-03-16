# Final Contract Spec
# Generated: 2026-03-09
# Auditor artifacts: Artifact 1-4 (inline prompt)
# Adversary review: codex-review (inline prompt)
# DEGRADED: no

---

## Category M -- Mutation Contracts

---

**M-001: frCode Cookie 注入（推播效率化追蹤）**

```
Trigger:      processNotificationAction:withCompletionBlock: 被呼叫，且 notif.frCode 非 nil 且長度 > 0
Input:        notif.frCode（NSString，來自推播或 deep link 的追蹤碼）
Output:       透過 NYCookieManager 設定名為 kCOOKIE_NAME_TRACE_FR 的 cookie，有效期 24 小時
Condition:    notif.frCode && notif.frCode.length > 0
Ordering:     在 targetType 路由判斷之前執行（before L-003）
Risk:         MEDIUM -- cookie 若在重構中被遺漏，會導致推播業績追蹤數據斷裂，但不影響功能
Evidence:     NYNotificationPresenter.m:181-184
              [[NYCookieManager sharedManager] setCookieValue:notif.frCode
                                                forCookieName:kCOOKIE_NAME_TRACE_FR
                                               expirationDate:[NSDate dateWithTimeIntervalSinceNow:24*60*60]];
Scope:        method
Seam_Type:    object
Pinch_Point:  true
```

---

**M-002: 跨商店 shopID 路由覆蓋**

```
Trigger:      processNotificationAction:withCompletionBlock: 被呼叫，且 notif.source == RoutingSourceRef
Input:        notif.shopID（NSNumber）與 [NYGlobalData shopId]
Output:       若 shopID 不匹配，targetType 被靜默覆蓋為 RoutingTargetTypeWebView
Condition:    notif.source == RoutingSourceRef && ![[NYGlobalData shopId] isEqualToNumber:notif.shopID]
Ordering:     在 frCode cookie 注入之後、if-else 路由鏈之前（after M-001, before L-003）
Risk:         HIGH -- 此覆蓋改變了整個路由行為，重構若遺漏會導致跨商店連結被原生頁面處理而非 WebView
Evidence:     NYNotificationPresenter.m:186-188
              if (notif.source == RoutingSourceRef && ![[NYGlobalData shopId] isEqualToNumber:notif.shopID]) {
                  targetType = RoutingTargetTypeWebView;
              }
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  true
```

---

**M-003: DesignCloudNative fallback 至 WebView**

```
Trigger:      processNotificationAction 處理 RoutingTargetTypeDesignCloudNative
Input:        globalActiveNavigationController 型別、DesignCloudBridge.getViewControllerWithPath: 回傳值
Output:       若 globalActiveNavigationController 不是 NaviController，或 DesignCloudBridge 回傳 nil，targetType 被覆蓋為 DesignCloudWebPage，rootVc 改用 DCWKWebViewController
Condition:    globalActiveNavigationController 非 NaviController || DesignCloudBridge 回傳 nil
Ordering:     在 if-else 路由鏈中（within L-003）
Risk:         MEDIUM -- fallback 邏輯確保功能可用，但重構時若移除 fallback 會導致 DesignCloud 頁面無法開啟
Evidence:     NYNotificationPresenter.m:~480-495
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**M-004: ThirdPartySSOHelper 狀態記錄**

```
Trigger:      redirectToLocationPointEventDetailWithNotificationObj: 或 redirectToPXPartialPickupWithNotificationObj: 被呼叫
Input:        notif（RoutingObject）或 notif.url（NSURL）
Output:       呼叫 [NYThirdPartySSOHelper shared] recordNotificationObjectIfNeeded: 或 recordTargetUrlIfNeeded:，修改全域 SSO 狀態
Condition:    無守衛——總是執行
Ordering:     在建立目標 VC 之前
Risk:         HIGH -- SSO 狀態記錄影響後續登入流程，遺漏會導致第三方登入後無法正確導回目標頁
Evidence:     NYNotificationPresenter.m:889 -- [[NYThirdPartySSOHelper shared] recordNotificationObjectIfNeeded:notif];
              NYNotificationPresenter.m:1101 -- [[NYThirdPartySSOHelper shared] recordTargetUrlIfNeeded:notif.url];
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**M-005: RetailStoreService 選店目標設定**

```
Trigger:      redirectToCMSCustomPageWithNotificationObj: 且 CMSPresentVCHelper shouldChooseStoreFirst 回傳 YES
Input:        notif（RoutingObject）
Output:       設定 RetailStoreService.shared 的 chooseStoreTarget completion block，該 block 會在選店完成後清除 target 並呼叫 navigateToTargetPageWith:
Condition:    [CMSPresentVCHelper shouldChooseStoreFirstWithType:NYCMSPageTypeCustom pageId:pageId] == YES
Ordering:     設定 completion → 導航至選店頁 → 選店完成後執行 completion
Risk:         HIGH -- completion block 中引用了 self（NYNotificationPresenter singleton）和 notif，形成延遲執行的副作用鏈。重構若打破此鏈會導致選店後無法導航到目標頁
Evidence:     NYNotificationPresenter.m:1043-1051
Scope:        method
Seam_Type:    object
Pinch_Point:  true
```

---

**M-006: NYAppSettingsHelper thirdpartyBasedAuth 全域狀態突變**

```
Trigger:      pushToVC:targetType:completion: 被呼叫，且 needLoginPage == YES 且 thirdpartyBasedAuth == NYThirdpartyBasedAuthNoData
Input:        API 回傳的 ThirdpartyBasedAuthSetting.IsThirdpartyBasedAuthEnabled
Output:       修改 [NYAppSettingsHelper sharedInstance].thirdpartyBasedAuth 為 Enable 或 Disable
Condition:    needLoginPage && thirdpartyBasedAuth == NYThirdpartyBasedAuthNoData && API returnCode == "0001"
Ordering:     API 回傳後修改設定，然後才執行導航（after API callback, before navigation push）
Risk:         HIGH -- 此 API 呼叫是同步語義但非同步執行。在等待 API 回傳期間，其他路由可能已讀取舊的 thirdpartyBasedAuth 值。然而程式仍有其他登入分支與一般 push 分支（NYNotificationPresenter.m:1578），移除此呼叫不會使導航「永遠」無法進入，但會導致第三方登入設定無法初始化 [DISPUTED -- 原 CRITICAL 降為 HIGH，因「永遠無法導航」過度推論]
Evidence:     NYNotificationPresenter.m:1468-1481
Scope:        method
Seam_Type:    object
Pinch_Point:  true
```

---

**M-007: VipMemberProfile isForceShowMemberCard 旗標設定**

```
Trigger:      redirectToVipMemberProfile 被呼叫
Input:        NYUserDefaultV2.isShowCustomVipMember、[NYUserDefault isShowVipMemberInfo]
Output:       設定會員頁 VC 的 isForceShowMemberCard 屬性
Condition:    依 isShowCustomVipMember 決定對 NYCustomVipMemberViewController 或 NYMemberV2ViewController 設定
Ordering:     設定旗標 → popToRoot → 切換 tab
Risk:         MEDIUM -- 型別判斷依賴 tabBar 中 VC 的固定位置。如果 tabBar 結構改變，typeCheckBlock 會觸發 NSAssert
Evidence:     NYNotificationPresenter.m:916-940
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**M-008: 追蹤事件發送（Analytics Mutation）**

```
Trigger:      trackingNotificationAction: 被呼叫（由 processPushNotificationAction 觸發）
Input:        notif.title、notif.content、notif.nyCallBackData
Output:       1) NYStatisticHelper sendEventNotificationOpened 發送 GA 事件
              2) NYTrackingServiceHelper send91TrackingV2 發送 91 追蹤事件（如果 dl 欄位存在）
Condition:    shouldSendTrackingLogs == YES（processNotificationAction:shouldSendTrackingLogs: 的參數）
Ordering:     在 processNotificationAction:withCompletionBlock: 之前
Risk:         MEDIUM -- 追蹤為非功能性需求，遺漏不影響導航但影響數據報表
Evidence:     NYNotificationPresenter.m:139-169
Scope:        method
Seam_Type:    object
Pinch_Point:  true
```

---

## Category L -- Lifecycle / State Machine Contracts

---

**L-001: Singleton 生命週期（dispatch_once）**

```
Trigger:      首次呼叫 [NYNotificationPresenter sharedInstance]
Input:        無
Output:       建立唯一實例，存於 static _sharedInstance
Condition:    dispatch_once 保證只執行一次
Ordering:     必須在任何實例方法呼叫之前
Risk:         LOW -- 標準 singleton 模式，但實例永不釋放
Evidence:     NYNotificationPresenter.m:121-128
              static id _sharedInstance = nil;
              static dispatch_once_t onceToken = 0;
              dispatch_once(&onceToken, ^{ _sharedInstance = [[NYNotificationPresenter alloc] init]; });
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

---

**L-002: pushToVC 登入閘門遞迴狀態機**

```
Trigger:      pushToVC:targetType:completion: 被呼叫且 needLoginPage == YES
Input:        targetType（決定是否需要登入）、NYLoginHelper.isLogin、NYAppSettingsHelper.thirdpartyBasedAuth
Output:       狀態轉換：
              State 1: thirdpartyBasedAuth == NoData → 呼叫 API → 設定 thirdpartyBasedAuth → 直接 push（不再檢查登入！）
              State 2: 未登入 → 呈現登入頁 → 登入成功後遞迴呼叫 pushToVC（重新進入閘門檢查）
              State 3: 已登入或不需登入 → 呼叫 completion 或直接 push
Condition:    needLoginPage 由固定的 targetType 列表決定
Ordering:     State 1 的 API 回傳後直接 push，繞過 State 2 的登入檢查——這是一個隱含的行為差異
Risk:         HIGH -- State 1 在 API 回傳後直接 push 而不檢查登入狀態，與 State 2 的行為不一致。遞迴呼叫掛在登入成功 callback 上（NYNotificationPresenter.m:1579-1580），非無條件重入，因此無限迴圈風險較低但仍存在（如登入頁反覆觸發 success 但 isLogin 仍為 NO）[DISPUTED -- 原 CRITICAL 降為 HIGH，「潛在無限迴圈」風險被限縮]
Evidence:     NYNotificationPresenter.m:1455-1494
Scope:        method
Seam_Type:    object
Pinch_Point:  true
```

---

**L-003: processNotificationAction 雙重 if-else 控制流**

```
Trigger:      processNotificationAction:withCompletionBlock: 被呼叫
Input:        notif.targetType（RoutingTargetType enum）
Output:       第一段 if-else 鏈（~行 190-570）：設定 rootVc 或呼叫 void 方法執行導航
              第二段 if-else 鏈（~行 574-582）：處理 ShopHome（push nil + select tab）、SchemeRedirect、或最終 pushToVC
Condition:    targetType 匹配對應分支
Ordering:     第一段 → 第二段。第一段中呼叫 void 方法（redirectToShoppingCart 等）後不設定 rootVc；FullURL 分支呼叫 redirectViaWrappedURL 後設 rootVc = nil（非直接 return）。第二段 else 分支要求 rootVc 非 nil 才 push [DISPUTED -- 修正 FullURL 描述]
Risk:         CRITICAL -- 兩段 if-else 的語義不直覺。重構時若合併兩段或改變順序，會破壞現有的控制流
Evidence:     NYNotificationPresenter.m:171-582
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

---

**L-004: 第三方 OAuth 登入流程狀態機**

```
Trigger:      processThirdpartyBasedOAuthWithNotificationObj: 被呼叫
Input:        notif.url、NYThirdPartySSOHelper.shared 的 thirdPartySsoToken、needsLoginFirst、type
Output:       狀態轉換：
              Guard: token 為 nil → return（靜默退出）
              Guard: needsLoginFirst == NO || 已登入 → do nothing
              State NYSSOTypeUrl: 解析目標 URL → dismiss 既有登入頁 → present 新登入頁 → 成功後 navigateToTargetPageWith:
              State NYSSOTypeNotificationObject: 取得 notif → dismiss → present → 成功後 navigateToTargetPageWith:
              State NYSSOTypeNotSpecified: 找到既有的 NYThirdPartyLoginWebBrowserVC → 直接處理 SSO token
Condition:    NYThirdPartySSOHelper.shared.type 決定走哪條路徑
Ordering:     dismissThirdPartyLoginVCIfNeeded 在 present 之前執行（防止重複呈現）。dismiss 使用 animated:NO（NYNotificationPresenter.m:1498），present 使用 animated:YES [DISPUTED -- evidence inconclusive on timing risk]
Risk:         HIGH -- dismiss/present 時序風險屬推測但合理考量。dismiss animated:NO 通常同步完成，但 UIKit 不保證
Evidence:     NYNotificationPresenter.m:1120-1175
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**L-005: RetailStore 選店後再導航流程**

```
Trigger:      redirectToCMSCustomPageWithNotificationObj: 且 shouldChooseStoreFirst == YES
Input:        notif（RoutingObject）、pageId
Output:       設定 completion block → navigateToTargetPageWith: 選店頁 → 用戶選完店後觸發 completion → clearChooseStoreTarget → navigateToTargetPageWith: 原始 notif
Condition:    [CMSPresentVCHelper shouldChooseStoreFirstWithType:NYCMSPageTypeCustom pageId:pageId]
Ordering:     設定 completion（M-005） → 導航至選店 → 選店完成 → 清除 target → 原始導航
Risk:         HIGH -- completion block 捕獲了 notif（strong reference）。如果用戶取消選店而非完成，completion 永遠不被呼叫，chooseStoreTarget 永遠不被清除
Evidence:     NYNotificationPresenter.m:1043-1055
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**L-006: showMemberBarcodeOrCarrierBarcodeAfterLogin 登入前置流程**

```
Trigger:      RoutingTargetTypeMemberBarcodeOrCarrierBarcode 路由到此方法
Input:        NYLoginHelper.sharedInstance.isLogin
Output:       未登入 → present 登入頁 → 成功後呼叫 showMemberBarcodeOrCarrierBarcode
              已登入 → 直接呼叫 showMemberBarcodeOrCarrierBarcode
Condition:    isLogin
Ordering:     login success completion → showMemberBarcodeOrCarrierBarcode
Risk:         LOW -- 標準的登入前置模式
Evidence:     NYNotificationPresenter.m:1366-1376
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**L-007: openBarcodeScannerWithNotificationObj 條件登入**

```
Trigger:      RoutingTargetTypeBarcodeScanner 路由到此方法
Input:        NYLoginHelper.isLogin、NYCountryConfig productScanTypeIn:countryCode
Output:       已登入或 scannerType == "standard" → 直接回傳 BarcodeScannerVC
              未登入且非 standard → present 登入頁 → 成功後 navigateToTargetPageWith: 重入路由
Condition:    isLogin || [scannerType isEqualToString:@"standard"]
Ordering:     login success → re-enter routing
Risk:         MEDIUM -- 成功後重入 navigateToTargetPageWith: 會再次走完整個路由鏈，但此時 isLogin 應為 YES 所以不會再觸發登入
Evidence:     NYNotificationPresenter.m:1392-1406
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**L-008: Current Tab Pop-to-Root 生命週期** *(ADD)*

```
Trigger:      NYNotificationPushHelper activeNavigationController:pushViewController:... 被呼叫，且 isCurrentTab == YES && needPush == NO
Input:        navController（當前 tab 的 UINavigationController）
Output:       不 push 新頁，直接把當前 tab 導覽堆疊退回 root
Condition:    isCurrentTab && !needPush
Ordering:     判斷 isCurrentTab → popToRootViewControllerAnimated:YES → 不執行 push
Risk:         LOW -- 標準導航操作，但如果導覽堆疊為空則為 no-op
Evidence:     NYNotificationPresenter.m:81-83
              if (isCurrentTab && !needPush) { [navController popToRootViewControllerAnimated:YES]; }
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

## Category N -- Notification / Observation Contracts

---

**N-001: NYChatRoomDidOpen 通知發送**

```
Trigger:      presentCustomerLiveChatWebVCWithQuery: 中的 presentViewController completion block 被呼叫
Input:        無
Output:       發送名為 @"NYChatRoomDidOpen" 的 NSNotification，object: nil，userInfo: nil
Condition:    presentViewController 動畫完成後
Ordering:     在聊天室 VC 呈現完成之後
Risk:         MEDIUM -- 觀察者可能依賴此通知來更新 UI 狀態（如標記已讀）。通知名稱為硬編碼字串，編譯時不會驗證
Evidence:     NYNotificationPresenter.m:1507
              [[NSNotificationCenter defaultCenter] postNotificationName:@"NYChatRoomDidOpen" object:nil];
Scope:        method
Seam_Type:    link
Pinch_Point:  false
```

---

**N-002: Delegate 呼叫 — NYNotificationHelperDelegate 協定遵循**

```
Trigger:      外部透過 NYNotificationHelperDelegate 協定呼叫
Input:        由 NYNotificationHelper 傳入的 RoutingObject
Output:       執行對應的導航操作
Condition:    NYNotificationPresenter 宣告遵循 NYNotificationHelperDelegate
Ordering:     由外部框架決定
Risk:         HIGH -- .h 宣告遵循 NYNotificationHelperDelegate，.m 中的 processPushNotificationAction: 等方法為候選 delegate 方法實作，但此映射關係需跨 protocol 定義檔確認 [DISPUTED -- 修正「未見明確實作」，實際有候選方法]
Evidence:     NYNotificationPresenter.h:13
              @interface NYNotificationPresenter : NSObject <NYNotificationHelperDelegate>
              NYNotificationPresenter.m:578 -- processPushNotificationAction: 為候選 delegate 方法
Scope:        class
Seam_Type:    object
Pinch_Point:  true
```

---

**N-003: Analytics 事件通知（NYStatisticHelper + NYTrackingServiceHelper）**

```
Trigger:      trackingNotificationAction: 被呼叫
Input:        notif.title、notif.content、notif.nyCallBackData 中的 sid/ncid/st/sys
Output:       1) NYStatisticHelper.sendEventNotificationOpened 發送通知開啟事件
              2) NYTrackingServiceHelper.send91TrackingV2 發送 dl 追蹤參數（條件性）
Condition:    dlValue 為非 nil 時才發送 91TrackingV2
Ordering:     sendEvent 先於 send91TrackingV2
Risk:         MEDIUM -- nyCallBackData 的 key（sid、ncid、st、sys）是隱含合約，發送端與接收端都假設這些 key 存在
Evidence:     NYNotificationPresenter.m:161-169
Scope:        method
Seam_Type:    object
Pinch_Point:  true
```

---

## Category S -- Synchronization Contracts

---

**S-001: dispatch_once Singleton 初始化**

```
Trigger:      +sharedInstance 首次呼叫
Input:        無
Output:       執行緒安全地建立唯一實例
Condition:    onceToken == 0（首次）
Ordering:     保證只執行一次，任何執行緒皆安全
Risk:         LOW -- 標準模式
Evidence:     NYNotificationPresenter.m:123-127
              dispatch_once(&onceToken, ^{ _sharedInstance = [[NYNotificationPresenter alloc] init]; });
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

---

**S-002: globalActiveNavigationController 無同步保護的 weak static 變數**

```
Trigger:      任何時刻呼叫 +setActiveNavigationController: 寫入，或任何實例方法讀取
Input:        UINavigationController 實例（寫入）
Output:       全域可見的 navigation controller 引用（讀取）
Condition:    __weak 語義——被引用的物件被釋放後自動變為 nil
Ordering:     無鎖、無 barrier——讀寫可在不同執行緒同時發生
Risk:         CRITICAL -- weak static 變數的讀寫在多執行緒環境下是未定義行為（ObjC runtime 的 weak 讀寫在 ARM64 上通常是安全的，但規範上不保證）。實務上由於幾乎所有操作都在主執行緒，問題不常出現
Evidence:     NYNotificationPresenter.m:133
              __weak static UINavigationController *globalActiveNavigationController;
Scope:        module
Seam_Type:    none
Pinch_Point:  true
```

---

**S-003: 所有導航操作的主執行緒假設**

```
Trigger:      任何 redirect/push/present 方法被呼叫
Input:        UIKit 操作（pushViewController、presentViewController）
Output:       UIKit 要求在主執行緒執行，否則行為未定義
Condition:    無顯式執行緒檢查（無 NSAssert、無 dispatch_async(main)）
Ordering:     呼叫者必須保證在主執行緒
Risk:         HIGH -- 呼叫者（如推播處理、deep link 處理）可能在背景執行緒觸發。缺少防護意味著重構後引入背景呼叫會靜默產生 UI 異常
Evidence:     整個 NYNotificationPresenter.m——無任何 dispatch_get_main_queue 調用
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

---

## Category E -- Error Handling Contracts

---

**E-001: URL 解析失敗的日誌記錄與靜默回傳**

```
Trigger:      redirectToShoppingCartV2WithURL: 中 URL 解析失敗
Input:        deep link URL 中找不到 "url=" query parameter，或解析出的值不是合法 URL
Output:       NSLog 輸出錯誤訊息後直接 return，不通知呼叫者 [DISPUTED -- 非完全靜默，有 NSLog 記錄]
Condition:    range.location == NSNotFound || redirectURL == nil
Ordering:     early return，不執行後續導航
Risk:         MEDIUM -- 用戶點擊連結後無反應，但有 NSLog 可供開發時偵錯
Evidence:     NYNotificationPresenter.m:968-977
              if (!redirectURL) { NSLog(@"SCV2 - Query value is not valid url."); return; }
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

**E-002: redirectViaWrappedURLWithNotificationObj URL 重組與 Crashlytics 記錄**

```
Trigger:      customField 的 URL 無法用 mwebParseWithString: 解析
Input:        notif.customField1（URL 字串）
Output:       嘗試 [NSURL recomposeWithString:]，並記錄到 Crashlytics
Condition:    [NSURL mwebParseWithString:customField] 回傳 nil
Ordering:     mwebParse 失敗 → recompose 嘗試 → Crashlytics 記錄 → 繼續 unwrap 流程
Risk:         MEDIUM -- recompose 後的 URL 可能仍然無效，但會傳入 unwrapFullURLWith: 繼續處理
Evidence:     NYNotificationPresenter.m:710-716
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

**E-003: pushToVC API 回傳錯誤靜默忽略**

```
Trigger:      getShopStaticSettingWithCompletionHandler 的 error 非 nil 或 returnCode 非 "0001"
Input:        API 回傳的 responseObject 和 error
Output:       什麼都不做——不導航、不提示、不重試
Condition:    error != nil || returnCode != "0001"
Ordering:     API 回傳後直接結束，用戶看到的是點擊後無反應
Risk:         HIGH -- 網路錯誤或 API 異常會導致需登入的頁面完全無法進入，且無任何回饋
Evidence:     NYNotificationPresenter.m:1468-1481（只處理 returnCode == "0001" 的情況）
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

**E-004: PXPartialPickupPush URL 為 nil 時回傳 nil**

```
Trigger:      redirectToPXPartialPickupPushWithNotificationObj: 且 customField1 無法解析為 URL
Input:        notif.customField1
Output:       回傳 nil，導致 pushToVC 不被呼叫
Condition:    [NSURL URLWithString:notif.customField1] == nil
Ordering:     early return nil
Risk:         LOW -- 防禦性處理，但呼叫者不知道為什麼沒有導航
Evidence:     NYNotificationPresenter.m:1107-1109
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

**E-005: Scheme Redirect 缺少 App 的下載提示 Fallback** *(ADD)*

```
Trigger:      processSchemeRedirectWithNotificationObj: 且 canOpenURL == NO
Input:        urlScheme（從 notif 中解析的 URL scheme 字串）
Output:       不執行 redirect，改為彈下載提示 alert（popDefaultDownloadAlert）
Condition:    [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlScheme]] == NO
Ordering:     canOpenURL 檢查 → 失敗 → popDefaultDownloadAlert
Risk:         LOW -- 標準 fallback 行為，提供使用者回饋
Evidence:     NYNotificationPresenter.m:1179-1181
              if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlScheme]] == NO) { [self popDefaultDownloadAlert]; }
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

## Category C -- Cancellation Contracts

---

**C-001: dismissThirdPartyLoginVCIfNeeded 條件 dismiss**

```
Trigger:      processThirdpartyBasedOAuthWithNotificationObj: 中，準備呈現新的登入頁之前
Input:        globalActiveNavigationController.visibleViewController
Output:       如果當前可見 VC 是 NYThirdPartyLoginWebBrowserVC，dismiss 它（animated:NO）
Condition:    visibleVC isKindOfClass:[NYThirdPartyLoginWebBrowserVC class]
Ordering:     dismiss（animated:NO） → 然後 present 新的 VC（animated:YES）
Risk:         MEDIUM -- 條件式 dismiss，不清除任何中間狀態。dismiss animated:NO 後的 present 時序風險屬推測 [DISPUTED -- evidence inconclusive，原 HIGH 降為 MEDIUM]
Evidence:     NYNotificationPresenter.m:1495-1500
              if (visibleVC && [visibleVC isKindOfClass:[NYThirdPartyLoginWebBrowserVC class]]) { [visibleVC dismissViewControllerAnimated:NO completion:nil]; }
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

## Category D -- Dependency Contracts

---

**D-001: globalActiveNavigationController 非 nil 依賴**

```
Trigger:      大多數導航方法被呼叫（processADElementAction: 除外，其走 keyWindow.rootViewController 路徑）
Input:        globalActiveNavigationController（__weak static）
Output:       若為 nil，navigation push/present 操作靜默失敗（ObjC nil messaging）
Condition:    必須由外部透過 +setActiveNavigationController: 設定
Ordering:     必須在任何導航操作之前設定
Risk:         CRITICAL -- 整個模組的導航功能幾乎完全依賴此變數非 nil。__weak 語義意味著隨時可能變為 nil [DISPUTED -- 修正「所有」為「大多數」，processADElementAction 走 keyWindow 路徑]
Evidence:     NYNotificationPresenter.m:133, 135
              NYNotificationPresenter.m:603-608 -- processADElementAction 使用 getKeyWindow.rootViewController
Scope:        module
Seam_Type:    none
Pinch_Point:  true
```

---

**D-002: NYTabBarControllerV2 未檢查的型別轉換**

```
Trigger:      redirectToShoppingCartWithCode:、redirectToShoppingCartWithSlaveId:、redirectToShoppingCartV2WithURL:、redirectToPaymentWalletWithQueryItems:、redirectToTabBarMemberDetail
Input:        globalActiveNavigationController.tabBarController
Output:       強制轉型為 NYTabBarControllerV2 後呼叫其特有方法
Condition:    部分方法無型別檢查（redirectToShoppingCartWithCode 等直接轉型），但 redirectToVipMemberProfile 有透過 typeCheckBlock 進行型別檢查 [DISPUTED -- 修正移除 redirectToVipMemberProfile]
Ordering:     轉型 → 呼叫方法
Risk:         HIGH -- 如果 tabBarController 不是 NYTabBarControllerV2（例如在 iPad split view 或特殊流程中），會導致 unrecognized selector crash
Evidence:     NYNotificationPresenter.m:944-945
              NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
              NYNotificationPresenter.m:1012 -- redirectToVipMemberProfile 有 typeCheckBlock 檢查
Scope:        class
Seam_Type:    object
Pinch_Point:  false
```

---

**D-003: NYLoginHelper.sharedInstance 登入狀態依賴**

```
Trigger:      showCarrierBarcode、showEditCarrierBarcode、showMemberBarcode、showMemberBarcodeOrCarrierBarcodeAfterLogin、pushToVC、openBarcodeScannerWithNotificationObj
Input:        NYLoginHelper.sharedInstance.isLogin（BOOL）
Output:       決定是否需要呈現登入頁或直接執行功能
Condition:    isLogin 在呼叫期間不可變（假設）
Ordering:     必須在 singleton 初始化之後
Risk:         MEDIUM -- 標準依賴，但 isLogin 狀態可能在非同步操作期間改變
Evidence:     NYNotificationPresenter.m:1329, 1340, 1367, 1393, 1485
Scope:        class
Seam_Type:    object
Pinch_Point:  false
```

---

**D-004: NYGlobalData 靜態方法依賴**

```
Trigger:      多處導航方法需要 shopId、countryCode、isTaiwan
Input:        無（class method 讀取全域設定）
Output:       shopId 用於路由判斷（M-002）、VC 初始化（redirectToInfoModuleListWithType 等）
Condition:    假設 NYGlobalData 已在 app 啟動時初始化
Ordering:     必須在 app 初始化完成之後
Risk:         LOW -- shopId 用於布林比較分支，nil 時 isEqualToNumber: 回傳 NO，不會產生異常，僅導致 targetType 被覆蓋為 WebView [DISPUTED -- 原 MEDIUM 降為 LOW，nil 行為為安全分支]
Evidence:     NYNotificationPresenter.m:187（shopId）、1394（countryCode）、1389（isTaiwan）
Scope:        module
Seam_Type:    none
Pinch_Point:  false
```

---

**D-005: NYUserDefault / NYUserDefaultV2 設定依賴**

```
Trigger:      redirectToVipMemberProfile、showMemberBarcode
Input:        NYUserDefaultV2.isShowCustomVipMember、NYUserDefault.isShowVipMemberInfo、NYUserDefault.shouldVerifyCellphoneWithoutOuterID
Output:       決定會員頁類型和是否需要手機驗證
Condition:    值在 app launch 時設定
Ordering:     必須在 launch 設定載入後
Risk:         LOW -- 靜態設定值，不太可能在運行時變更
Evidence:     NYNotificationPresenter.m:923, 928, 1355
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

**D-006: NYDataProvider.sharedInstance API 依賴**

```
Trigger:      pushToVC 中 thirdpartyBasedAuth == NoData
Input:        無（呼叫 getShopStaticSettingWithCompletionHandler）
Output:       非同步 API 回傳 ThirdpartyBasedAuthSetting
Condition:    needLoginPage && thirdpartyBasedAuth == NYThirdpartyBasedAuthNoData
Ordering:     API 回傳後才能繼續導航
Risk:         HIGH -- 網路超時或失敗會導致導航完全卡住（E-003）
Evidence:     NYNotificationPresenter.m:1468
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**D-007: DesignCloudBridge 動態分派依賴**

```
Trigger:      processNotificationAction 處理 RoutingTargetTypeDesignCloudNative
Input:        notif.url.path、globalActiveNavigationController（必須為 NaviController 子型別）
Output:       DesignCloudBridge.getViewControllerWithPath:navigator: 回傳 UIViewController 或 nil
Condition:    globalActiveNavigationController isKindOfClass:[NaviController class]
Ordering:     嘗試 native → 失敗則 fallback 至 WebView（M-003）
Risk:         MEDIUM -- NaviController 型別檢查正確，但 DesignCloudBridge 是 Swift 類別，跨語言呼叫增加重構風險
Evidence:     NYNotificationPresenter.m:~483-494
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**D-008: NYADLandingHelper 廣告著陸頁依賴**

```
Trigger:      processADElementAction: 被呼叫
Input:        NYADElementObject
Output:       viewControllerForADElement: 回傳目標 VC
Condition:    無——總是建立新的 NYADLandingHelper 實例
Ordering:     建立 helper → 取得 VC → 取得 rootVC → push
Risk:         MEDIUM -- 每次呼叫都 alloc init 新的 helper，helper 的內部依賴未知
Evidence:     NYNotificationPresenter.m:594
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**D-009: NYCookieManager.sharedManager Cookie 管理依賴**

```
Trigger:      processNotificationAction 中 frCode 非空（M-001）
Input:        cookie name（kCOOKIE_NAME_TRACE_FR）、value（frCode）、expiration
Output:       寫入 HTTP cookie store
Condition:    frCode 存在且長度 > 0
Ordering:     在路由判斷之前
Risk:         LOW -- 標準 cookie 操作
Evidence:     NYNotificationPresenter.m:181-184
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**D-010: RetailStoreService 功能開關與門市選擇依賴**

```
Trigger:      redirectToCMSCustomPageWithNotificationObj:、presentRetailStoreChoosingWithNotificationObj:
Input:        RetailStoreService.isFeatureEnable、RetailStoreService.shared
Output:       決定是否啟用門市選擇流程、提供 serviceType
Condition:    feature flag 控制
Ordering:     isFeatureEnable 檢查 → serviceType 取得 → shouldChooseStoreFirst 判斷
Risk:         MEDIUM -- feature flag 狀態決定整個 CMS 自訂頁的行為路徑
Evidence:     NYNotificationPresenter.m:1040, 1042, 1216-1217
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  false
```

---

**D-011: NYZendeskHelper.shared 客服 SDK 依賴**

```
Trigger:      pushToZendeskWithCompletion: 被呼叫
Input:        無
Output:       非同步取得 Zendesk messaging VC
Condition:    無——總是呼叫
Ordering:     非同步回傳 VC → pushToVC
Risk:         MEDIUM -- Zendesk SDK 可能初始化失敗，回傳的 zendeskVC 可能為 nil。nil 會直接傳入 pushToVC，但 pushToVC 未見對 rootVc == nil 的明確 guard [DISPUTED -- 修正「nil 由 pushToVC 負責處理」，實際未見 nil guard]
Evidence:     NYNotificationPresenter.m:1412-1416
              NYNotificationPresenter.m:1506-1508 -- zendeskVC nullable 直接傳入 pushToVC
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

---

**D-012: NYBaseURLConfig 基礎 URL 依賴**

```
Trigger:      redirectToJKOPayPaymentConfirmWithNotificationObj: 被呼叫
Input:        [NYBaseURLConfig baseHTTPSURLWithAppServiceWebPageDomain]
Output:       組合街口支付確認頁 URL
Condition:    無——總是呼叫
Ordering:     取得 base URL → 組合完整 URL → 建立 VC
Risk:         MEDIUM -- base URL 若在 runtime 未正確設定，會產生無效 URL
Evidence:     NYNotificationPresenter.m:1083
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

## Category P -- Propagation Contracts

---

**P-001: processNotificationAction rootVc 傳播鏈**

```
Trigger:      processNotificationAction:withCompletionBlock: 中的路由分支
Input:        各 redirect 方法的回傳值（UIViewController * 或 nil）
Output:       rootVc 被傳入 pushToVC:targetType:completion:，最終透過 NYNotificationPushHelper 推入 navigation stack
Condition:    rootVc 非 nil 且 targetType 非 Unknown
Ordering:     redirect 方法回傳 → rootVc 賦值 → 第二段 if-else → pushToVC
Risk:         HIGH -- 部分 redirect 方法回傳 nil 但仍有副作用（如 redirectToNYGiftDetailWithNotificationObj 自行 push 後回傳 nil），rootVc == nil 時 pushToVC 不被呼叫但功能已完成——語義不一致
Evidence:     NYNotificationPresenter.m:175, 485-487
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

---

**P-002: getDefaultDownloadURLString:andAlertMessage: out parameters**

```
Trigger:      popDefaultDownloadAlert 呼叫此方法
Input:        兩個 NSString ** out parameters
Output:       修改 *downloadURLString 和 *alertMessage 的值
Condition:    isPxPartWebView == YES 時才設定值
Ordering:     設定值 → popDownloadAlertWithMessage 使用值
Risk:         MEDIUM -- 如果 isPxPartWebView == NO，兩個 out parameter 保持為空字串 @""（由呼叫者初始化），但 popDownloadAlertWithMessage 仍會被呼叫，顯示空內容的 alert
Evidence:     NYNotificationPresenter.m:1425-1431
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

**P-003: globalActiveNavigationController 全域狀態傳播**

```
Trigger:      +setActiveNavigationController: 寫入
Input:        UINavigationController 實例
Output:       影響大多數後續的導航操作——redirect/push/present 方法讀取此變數（processADElementAction: 除外，其走 keyWindow 路徑）
Condition:    __weak 語義，隨時可能變為 nil
Ordering:     寫入 → 任意數量的讀取，無同步保證
Risk:         CRITICAL -- 此全域變數是模組的 single point of failure（對大多數路由路徑）。如果在導航操作進行中 VC 被釋放，globalActiveNavigationController 變為 nil，後續操作靜默失敗 [DISPUTED -- 修正為「大多數」而非「所有」]
Evidence:     NYNotificationPresenter.m:133-136
              NYNotificationPresenter.m:603-608 -- processADElementAction 走獨立的 keyWindow 路徑
Scope:        module
Seam_Type:    none
Pinch_Point:  true
```

---

**P-004: Conditional Tab Selection 傳播** *(ADD)*

```
Trigger:      呼叫 NYNotificationPushHelper activeNavigationController:pushViewController:thenSelectTabAtIndex:
Input:        needSelectTab（BOOL）、tabBarController、index
Output:       根據 needSelectTab 決定是否切換 tab，將 push 的結果傳播到 tab 狀態
Condition:    needSelectTab == YES
Ordering:     push VC → 判斷 needSelectTab → selectTabBarItemAt:
Risk:         LOW -- 標準 tab 切換操作
Evidence:     NYNotificationPresenter.m:88-90
              if (needSelectTab) { [(NYTabBarControllerV2 *)tabBarController selectTabBarItemAt:index]; }
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

**P-005: Scheme Redirect 外部 App 傳播** *(ADD)*

```
Trigger:      processSchemeRedirectWithNotificationObj: 且 canOpenURL == YES
Input:        urlScheme（從 notif 中解析的 URL scheme 字串）
Output:       呼叫 UIApplication openURL，導航效果傳播到 app 外部
Condition:    [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlScheme]] == YES
Ordering:     getRedirectUrl → canOpenURL 檢查 → openURL
Risk:         LOW -- 標準外部 app 開啟操作
Evidence:     NYNotificationPresenter.m:1189-1191
              [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlScheme] options:@{} completionHandler:nil];
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

## Risk Matrix

| ID | Risk | Description | Pinch Point |
|----|------|-------------|-------------|
| M-001 | MEDIUM | frCode cookie 注入 | YES |
| M-002 | HIGH | 跨商店 shopID 路由覆蓋 | YES |
| M-003 | MEDIUM | DesignCloudNative fallback | NO |
| M-004 | HIGH | ThirdPartySSOHelper 狀態記錄 | NO |
| M-005 | HIGH | RetailStoreService 選店目標設定 | YES |
| M-006 | HIGH | thirdpartyBasedAuth 全域突變 [DISPUTED ↓CRITICAL] | YES |
| M-007 | MEDIUM | VipMember isForceShowMemberCard | NO |
| M-008 | MEDIUM | 追蹤事件發送 | YES |
| L-001 | LOW | dispatch_once singleton | YES |
| L-002 | HIGH | pushToVC 登入閘門遞迴 [DISPUTED ↓CRITICAL] | YES |
| L-003 | CRITICAL | 雙重 if-else 控制流 [DISPUTED -- 描述修正] | YES |
| L-004 | HIGH | 第三方 OAuth 登入流程 [DISPUTED -- evidence inconclusive] | NO |
| L-005 | HIGH | 選店後再導航流程 | NO |
| L-006 | LOW | 條件登入前置流程 | NO |
| L-007 | MEDIUM | 掃描器條件登入 | NO |
| L-008 | LOW | Current Tab Pop-to-Root [ADD] | NO |
| N-001 | MEDIUM | NYChatRoomDidOpen 通知 [META: seam→link] | NO |
| N-002 | HIGH | NYNotificationHelperDelegate [DISPUTED -- 描述修正] | YES |
| N-003 | MEDIUM | Analytics 事件通知 | YES |
| S-001 | LOW | dispatch_once 初始化 | YES |
| S-002 | CRITICAL | weak static 無同步保護 | YES |
| S-003 | HIGH | 主執行緒假設 | NO |
| E-001 | MEDIUM | URL 解析 NSLog 記錄與靜默回傳 [DISPUTED -- 描述修正] | NO |
| E-002 | MEDIUM | URL 重組 Crashlytics | NO |
| E-003 | HIGH | API 錯誤靜默忽略 | NO |
| E-004 | LOW | PXPartialPickupPush nil 回傳 | NO |
| E-005 | LOW | Scheme Redirect 下載提示 [ADD] | NO |
| C-001 | MEDIUM | 條件 dismiss [DISPUTED ↓HIGH] | NO |
| D-001 | CRITICAL | globalActiveNavController 依賴 [DISPUTED -- 描述修正] | YES |
| D-002 | HIGH | NYTabBarControllerV2 未檢查轉型 [DISPUTED -- 描述修正] | NO |
| D-003 | MEDIUM | NYLoginHelper 依賴 | NO |
| D-004 | LOW | NYGlobalData 依賴 [DISPUTED ↓MEDIUM] | NO |
| D-005 | LOW | NYUserDefault 依賴 | NO |
| D-006 | HIGH | NYDataProvider API 依賴 | NO |
| D-007 | MEDIUM | DesignCloudBridge 依賴 | NO |
| D-008 | MEDIUM | NYADLandingHelper 依賴 | NO |
| D-009 | LOW | NYCookieManager 依賴 | NO |
| D-010 | MEDIUM | RetailStoreService 依賴 | NO |
| D-011 | MEDIUM | NYZendeskHelper 依賴 [DISPUTED -- 描述修正] | NO |
| D-012 | MEDIUM | NYBaseURLConfig 依賴 | NO |
| P-001 | HIGH | rootVc 傳播鏈 | YES |
| P-002 | MEDIUM | out parameters | NO |
| P-003 | CRITICAL | 全域 nav controller 傳播 [DISPUTED -- 描述修正] | YES |
| P-004 | LOW | Conditional Tab Selection [ADD] | NO |
| P-005 | LOW | Scheme Redirect 外部傳播 [ADD] | NO |
