# Contract Audit: NYNotificationPresenter
# Module: NYNotificationPresenter.m (1530 lines) + NYNotificationPresenter.h (25 lines)
# Language: Objective-C
# Date: 2026-03-09

---

# Artifact 1: Contract Spec Document

---

## F1: Tell the Story

```
STORY: 此模組是一個集中式路由派發 Singleton，負責 (1) 將 RoutingObject 的 targetType 映射到對應的 UIViewController 目的地、(2) 透過全域弱引用 navigation controller 管理導航堆疊的 push/present 操作、(3) 處理導航前的副作用（追蹤埋點、cookie 設定、登入閘門）。

LIES:
- 省略1: 不只是簡單的派發器——它包含 URL 解包（unwrap）邏輯、登入流程編排、第三方 SSO 處理等複雜業務邏輯。重構時若只把它當成路由表，會遺漏這些嵌入式狀態機。
- 省略2: 「全域 navigation controller」實際上是一個 __weak static 變數，可在任何時刻變為 nil，且沒有任何同步保護。多個方法在使用前不檢查 nil，導致靜默失敗。
- 省略3: processNotificationAction:withCompletionBlock: 中有兩段 sequential if-else 鏈——第一段設定 rootVc，第二段處理 ShopHome/SchemeRedirect/最終 push。某些 targetType 在第一段中直接 return（如 WebView 外部連結），繞過第二段邏輯，這個控制流不是顯而易見的。
```

---

## F2: Scratch Refactoring

```
SCRATCH_REFACTORING:
1. 將 processNotificationAction:withCompletionBlock: 的巨型 if-else 鏈提取為 NSDictionary<NSNumber*, Block> 查找表
   REVEALS: M-002（shopID 跨商店重導向覆蓋 targetType）、L-003（雙重 if-else 鏈的控制流）、M-003（DesignCloudNative 的 fallback 覆蓋 targetType）。部分分支有 early return（WebView 外連、FullURL），字典查找無法直接表達 early return 語義。

2. 將 globalActiveNavigationController（__weak static）替換為依賴注入
   REVEALS: S-002（無同步保護的 weak static 全域變數）、D-001（所有導航方法依賴此變數非 nil）、D-002（多處假設 tabBarController 為 NYTabBarControllerV2 的未檢查轉型）。移除全域狀態後，每個方法的真實依賴才會浮現。

3. 將 pushToVC:targetType:completion: 的登入閘門邏輯提取為獨立的 LoginGateDecorator
   REVEALS: L-002（登入閘門遞迴：pushToVC → 呈現登入頁 → 成功後再呼叫 pushToVC）、M-006（NYAppSettingsHelper.thirdpartyBasedAuth 的突變：API 回傳後修改全域設定）、D-011（NYDataProvider.sharedInstance 的隱含依賴與 API 錯誤靜默處理）。
```

---

## Contract Specifications

---

### Category M -- Mutation Contracts

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
Scope:        module
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
Risk:         CRITICAL -- 此 API 呼叫是同步語義但非同步執行。在等待 API 回傳期間，其他路由可能已經讀取了舊的 thirdpartyBasedAuth 值。重構若移除此 API 呼叫會導致需登入頁面永遠無法導航
Evidence:     NYNotificationPresenter.m:1468-1481
Scope:        module
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

### Category L -- Lifecycle / State Machine Contracts

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
Risk:         CRITICAL -- State 1 在 API 回傳後直接 push 而不檢查登入狀態，與 State 2 的行為不一致。遞迴呼叫形成潛在的無限迴圈（如果登入頁反覆觸發 success 但 isLogin 仍為 NO）
Evidence:     NYNotificationPresenter.m:1455-1494
Scope:        module
Seam_Type:    object
Pinch_Point:  true
```

---

**L-003: processNotificationAction 雙重 if-else 控制流**

```
Trigger:      processNotificationAction:withCompletionBlock: 被呼叫
Input:        notif.targetType（RoutingTargetType enum）
Output:       第一段 if-else 鏈（~行 190-475）：設定 rootVc 或直接執行導航（某些分支直接 return）
              第二段 if-else 鏈（~行 477-487）：處理 ShopHome（push nil + select tab）、SchemeRedirect、或最終 pushToVC
Condition:    targetType 匹配對應分支
Ordering:     第一段 → 第二段，但第一段中某些分支直接 return 繞過第二段（WebView external link、FullURL 等 void 方法分支）
Risk:         CRITICAL -- 兩段 if-else 的語義不直覺。第一段中呼叫 void 方法（redirectToShoppingCartWithCode 等）後不設定 rootVc，然後第二段的 else 分支要求 rootVc 非 nil 才 push。重構時若合併兩段或改變順序，會破壞現有的控制流
Evidence:     NYNotificationPresenter.m:171-487
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
Ordering:     dismissThirdPartyLoginVCIfNeeded 在 present 之前執行（防止重複呈現）
Risk:         HIGH -- dismiss 使用 animated:NO 但 present 使用 animated:YES，dismiss 未等待完成就 present 可能導致 UI 異常
Evidence:     NYNotificationPresenter.m:1120-1175
Scope:        module
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
Scope:        module
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

### Category N -- Notification / Observation Contracts

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
Scope:        module
Seam_Type:    none
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
Risk:         HIGH -- .h 宣告遵循 NYNotificationHelperDelegate 但 .m 中未見到明確的 protocol 方法實作。可能透過 processNotificationAction 間接實現，但此映射關係不透明
Evidence:     NYNotificationPresenter.h:13
              @interface NYNotificationPresenter : NSObject <NYNotificationHelperDelegate>
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

### Category S -- Synchronization Contracts

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

### Category E -- Error Handling Contracts

---

**E-001: URL 解析失敗的靜默處理**

```
Trigger:      redirectToShoppingCartV2WithURL: 中 URL 解析失敗
Input:        deep link URL 中找不到 "url=" query parameter，或解析出的值不是合法 URL
Output:       NSLog 輸出後直接 return，不通知呼叫者
Condition:    range.location == NSNotFound || redirectURL == nil
Ordering:     early return，不執行後續導航
Risk:         MEDIUM -- 靜默失敗導致用戶點擊連結後無反應，無法除錯
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

### Category C -- Cancellation Contracts

---

**C-001: dismissThirdPartyLoginVCIfNeeded 隱式取消**

```
Trigger:      processThirdpartyBasedOAuthWithNotificationObj: 中，準備呈現新的登入頁之前
Input:        globalActiveNavigationController.visibleViewController
Output:       如果當前可見 VC 是 NYThirdPartyLoginWebBrowserVC，dismiss 它（animated:NO）
Condition:    visibleVC isKindOfClass:[NYThirdPartyLoginWebBrowserVC class]
Ordering:     dismiss（animated:NO） → 然後 present 新的 VC（animated:YES）
Risk:         HIGH -- dismiss animated:NO 不等待完成即進行 present，可能導致 present 被忽略或 UI 異常。dismiss 不清除任何中間狀態
Evidence:     NYNotificationPresenter.m:1495-1500
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

### Category D -- Dependency Contracts

---

**D-001: globalActiveNavigationController 非 nil 依賴**

```
Trigger:      所有導航方法被呼叫
Input:        globalActiveNavigationController（__weak static）
Output:       若為 nil，所有 navigation push/present 操作靜默失敗（ObjC nil messaging）
Condition:    必須由外部透過 +setActiveNavigationController: 設定
Ordering:     必須在任何導航操作之前設定
Risk:         CRITICAL -- 整個模組的導航功能完全依賴此變數非 nil。__weak 語義意味著隨時可能變為 nil
Evidence:     NYNotificationPresenter.m:133, 135
Scope:        module
Seam_Type:    none
Pinch_Point:  true
```

---

**D-002: NYTabBarControllerV2 未檢查的型別轉換**

```
Trigger:      redirectToShoppingCartWithCode:、redirectToShoppingCartWithSlaveId:、redirectToShoppingCartV2WithURL:、redirectToPaymentWalletWithQueryItems:、redirectToTabBarMemberDetail、redirectToVipMemberProfile
Input:        globalActiveNavigationController.tabBarController
Output:       強制轉型為 NYTabBarControllerV2 後呼叫其特有方法
Condition:    無型別檢查（redirectToShoppingCartWithCode 等方法直接轉型）
Ordering:     轉型 → 呼叫方法
Risk:         HIGH -- 如果 tabBarController 不是 NYTabBarControllerV2（例如在 iPad split view 或特殊流程中），會導致 unrecognized selector crash
Evidence:     NYNotificationPresenter.m:944-945
              NYTabBarControllerV2 *tabbarVC = (NYTabBarControllerV2 *)[globalActiveNavigationController tabBarController];
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
Risk:         MEDIUM -- shopId 為 nil 會導致 NSNumber 比較失敗或 VC 初始化異常
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
Risk:         LOW -- Zendesk SDK 可能初始化失敗，但 completionHandler 的 nil 處理由 pushToVC 負責
Evidence:     NYNotificationPresenter.m:1412-1416
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

### Category P -- Propagation Contracts

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
Output:       影響所有後續的導航操作——每個 redirect/push/present 方法都讀取此變數
Condition:    __weak 語義，隨時可能變為 nil
Ordering:     寫入 → 任意數量的讀取，無同步保證
Risk:         CRITICAL -- 此全域變數是整個模組的 single point of failure。如果在導航操作進行中 VC 被釋放，globalActiveNavigationController 變為 nil，後續操作靜默失敗
Evidence:     NYNotificationPresenter.m:133-136
Scope:        module
Seam_Type:    none
Pinch_Point:  true
```

---

## Risk Matrix

| ID | Risk | Description | Refactoring Impact |
|----|------|-------------|-------------------|
| M-001 | MEDIUM | frCode cookie 注入 | 遺漏導致追蹤數據斷裂 |
| M-002 | HIGH | 跨商店 shopID 路由覆蓋 | 遺漏導致跨商店連結被原生頁面處理 |
| M-003 | MEDIUM | DesignCloudNative fallback | 移除 fallback 導致頁面無法開啟 |
| M-004 | HIGH | ThirdPartySSOHelper 狀態記錄 | 遺漏導致 SSO 登入後無法導回 |
| M-005 | HIGH | RetailStoreService 選店目標設定 | 打破 completion 鏈導致選店後無導航 |
| M-006 | CRITICAL | thirdpartyBasedAuth 全域突變 | 移除 API 呼叫導致需登入頁面無法進入 |
| M-007 | MEDIUM | VipMember isForceShowMemberCard | tabBar 結構改變觸發 NSAssert |
| M-008 | MEDIUM | 追蹤事件發送 | 遺漏影響數據報表 |
| L-001 | LOW | dispatch_once singleton | 標準模式，風險低 |
| L-002 | CRITICAL | pushToVC 登入閘門遞迴 | State 1 繞過登入檢查；潛在無限迴圈 |
| L-003 | CRITICAL | 雙重 if-else 控制流 | 合併或重排會破壞控制流 |
| L-004 | HIGH | 第三方 OAuth 登入流程 | dismiss/present 時序問題 |
| L-005 | HIGH | 選店後再導航流程 | 取消選店導致狀態殘留 |
| L-006 | LOW | 條件登入前置流程 | 標準模式 |
| L-007 | MEDIUM | 掃描器條件登入 | 重入路由可能有邊際效應 |
| N-001 | MEDIUM | NYChatRoomDidOpen 通知 | 硬編碼字串，觀察者不可見 |
| N-002 | HIGH | NYNotificationHelperDelegate 遵循 | protocol 方法映射不透明 |
| N-003 | MEDIUM | Analytics 事件通知 | nyCallBackData key 為隱含合約 |
| S-001 | LOW | dispatch_once 初始化 | 標準模式 |
| S-002 | CRITICAL | weak static 無同步保護 | 多執行緒環境下未定義行為 |
| S-003 | HIGH | 主執行緒假設 | 無防護，背景呼叫致 UI 異常 |
| E-001 | MEDIUM | URL 解析靜默失敗 | 用戶點擊無反應 |
| E-002 | MEDIUM | URL 重組與 Crashlytics | 重組後 URL 可能仍無效 |
| E-003 | HIGH | API 錯誤靜默忽略 | 導航卡住無回饋 |
| E-004 | LOW | PXPartialPickupPush nil 回傳 | 防禦性處理 |
| C-001 | HIGH | dismiss 後立即 present | 時序問題導致 UI 異常 |
| D-001 | CRITICAL | globalActiveNavController 依賴 | nil 時所有導航靜默失敗 |
| D-002 | HIGH | NYTabBarControllerV2 未檢查轉型 | 非標準 tabBar 致 crash |
| D-003 | MEDIUM | NYLoginHelper 依賴 | 非同步期間狀態可能改變 |
| D-004 | MEDIUM | NYGlobalData 依賴 | shopId nil 致比較失敗 |
| D-005 | LOW | NYUserDefault 依賴 | 靜態設定 |
| D-006 | HIGH | NYDataProvider API 依賴 | 網路失敗致導航卡住 |
| D-007 | MEDIUM | DesignCloudBridge 依賴 | 跨語言呼叫增加風險 |
| D-008 | MEDIUM | NYADLandingHelper 依賴 | helper 內部依賴未知 |
| D-009 | LOW | NYCookieManager 依賴 | 標準操作 |
| D-010 | MEDIUM | RetailStoreService 依賴 | feature flag 控制行為路徑 |
| D-011 | LOW | NYZendeskHelper 依賴 | SDK 可能初始化失敗 |
| D-012 | MEDIUM | NYBaseURLConfig 依賴 | 無效 URL |
| P-001 | HIGH | rootVc 傳播鏈 | nil 回傳但有副作用的語義不一致 |
| P-002 | MEDIUM | out parameters | 空值仍觸發 alert |
| P-003 | CRITICAL | 全域 nav controller 傳播 | single point of failure |

---

## F3: Effect Propagation Tracing

```
EFFECT_TRACE: + (instancetype)sharedInstance
  RETURN:  static _sharedInstance → 直接回傳，消費者持有強引用
  MUTATES: none
  GLOBAL:  _sharedInstance（首次呼叫時寫入）、onceToken
  DEPTH:   0（直接回傳）

EFFECT_TRACE: + (void)setActiveNavigationController:(UINavigationController *)navController
  RETURN:  void
  MUTATES: none
  GLOBAL:  globalActiveNavigationController（__weak static 寫入）— 影響所有後續導航操作
  DEPTH:   ∞（所有讀取此全域變數的方法都受影響）

EFFECT_TRACE: - (void)trackingNotificationAction:(RoutingObject *)notif
  RETURN:  void
  MUTATES: none
  GLOBAL:  NYStatisticHelper 內部狀態（事件佇列）、NYTrackingServiceHelper 91追蹤狀態
  DEPTH:   2（NYStatisticHelper → 網路層 → 後端）

EFFECT_TRACE: - (void)processNotificationAction:(RoutingObject *)notif withCompletionBlock:(Completion)completion
  RETURN:  void
  MUTATES: none（但 notif 的 targetType 被局部複製後修改——不影響原物件）
  GLOBAL:  NYCookieManager（M-001）、globalActiveNavigationController（讀取）、
           NYAppSettingsHelper.thirdpartyBasedAuth（M-006，間接透過 pushToVC）、
           RetailStoreService.chooseStoreTarget（M-005，間接）、
           NYThirdPartySSOHelper（M-004，間接）
  DEPTH:   4（processNotificationAction → redirect 方法 → pushToVC → NYNotificationPushHelper → UIKit navigation stack）

EFFECT_TRACE: - (void)navigateToTargetPageWith:(RoutingObject *)notif
  RETURN:  void
  MUTATES: none
  GLOBAL:  同 processNotificationAction（透過代理呼叫，shouldTrack=NO）
  DEPTH:   4（同上，減去追蹤）

EFFECT_TRACE: - (void)processPushNotificationAction:(RoutingObject *)notif
  RETURN:  void
  MUTATES: none
  GLOBAL:  同 processNotificationAction + trackingNotificationAction 的副作用
  DEPTH:   4

EFFECT_TRACE: - (void)processNotificationAction:(RoutingObject *)notif shouldSendTrackingLogs:(BOOL)shouldTrack
  RETURN:  void
  MUTATES: none
  GLOBAL:  條件性觸發 trackingNotificationAction，然後呼叫 processNotificationAction:withCompletionBlock:nil
  DEPTH:   4

EFFECT_TRACE: - (void)processADElementAction:(NYADElementObject *)adElement
  RETURN:  void
  MUTATES: none
  GLOBAL:  透過 NYADLandingHelper 建立 VC → UIKit navigation stack
  DEPTH:   3

EFFECT_TRACE: - (UIViewController *)redirectToSalePageCategoryWithNotificationObj:(RoutingObject *)notif
  RETURN:  UIViewController（NYItemListVC）→ 傳入 processNotificationAction 的 rootVc → pushToVC → navigation stack
  MUTATES: none
  GLOBAL:  none
  DEPTH:   1（回傳 VC，由呼叫者處理 push）

EFFECT_TRACE: - (UIViewController *)redirectToNotificationCenter
  RETURN:  NYNotificationViewPagerController → rootVc → pushToVC
  MUTATES: none
  GLOBAL:  none
  DEPTH:   1

EFFECT_TRACE: - (UIViewController *)redirectToSalePageWithNotificationObj:(RoutingObject *)notif
  RETURN:  NYSalePageViewController → rootVc → pushToVC
  MUTATES: none
  GLOBAL:  none
  DEPTH:   1

EFFECT_TRACE: - (UIViewController *)redirectToNYGiftDetailWithNotificationObj:(RoutingObject *)notif
  RETURN:  nil（如果找到 topNavController 則自行 push 後回傳 nil）或 giftDetailVC
  MUTATES: none
  GLOBAL:  UIKit navigation stack（可能自行 push）
  DEPTH:   1-2（自行 push 時 depth=2）

EFFECT_TRACE: - (void)redirectToExternalBrowserWithURL:(NSURL *)url
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIApplication openURL → 系統瀏覽器
  DEPTH:   1（跨行程）

EFFECT_TRACE: - (void)redirectViaWrappedURLWithNotificationObj:(RoutingObject *)notif completion:(Completion)completion
  RETURN:  void
  MUTATES: none
  GLOBAL:  NYCrashlyticsHelper（E-002，條件性）、然後遞迴進入 processNotificationAction
  DEPTH:   5+（URL unwrap → 建立新 RoutingObject → 重入 processNotificationAction → 遞迴深度不定）

EFFECT_TRACE: - (void)unwrapFullURLWith:(NSURL *)url completion:(Completion)completion
  RETURN:  void
  MUTATES: none
  GLOBAL:  建立新 RoutingObject → 遞迴呼叫 processNotificationAction
  DEPTH:   4+（遞迴）

EFFECT_TRACE: - (void)unwrapTargetURLWith:(NSURL *)url completion:(Completion)completion
  RETURN:  void
  MUTATES: none
  GLOBAL:  同 unwrapFullURLWith
  DEPTH:   4+（遞迴）

EFFECT_TRACE: - (void)redirectToTabBarMemberDetail
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIKit tab bar selection
  DEPTH:   2（tabBarController → selectTabBarItemOf）

EFFECT_TRACE: - (void)redirectToVipMemberProfile
  RETURN:  void
  MUTATES: member VC 的 isForceShowMemberCard 屬性（M-007）
  GLOBAL:  UIKit navigation stack（popToRoot + tab switch）
  DEPTH:   3

EFFECT_TRACE: - (void)redirectToShoppingCartWithCode:(NSString *)code
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIKit（tabbarVC presentCartWith:）
  DEPTH:   2

EFFECT_TRACE: - (void)redirectToShoppingCartWithSlaveId:(NSNumber *)salveID
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIKit（tabbarVC presentCartWithGiftCouponSlaveID: 或 presentShoppingCart）
  DEPTH:   2

EFFECT_TRACE: - (void)redirectToShoppingCartV2WithURL:(NSURL *)url
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIKit（tabbarVC presentV2CartWithUrl:）
  DEPTH:   2

EFFECT_TRACE: - (void)redirectToPaymentWalletWithQueryItems:(NSArray *)queryItems
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIKit（tabbarVC presentPaymentWalletWith:）
  DEPTH:   2

EFFECT_TRACE: - (UIViewController *)redirectToCMSCustomPageWithNotificationObj:(RoutingObject *)notif
  RETURN:  NYCMSBasedViewController 或 nil（選店流程時）
  MUTATES: vc.serviceType
  GLOBAL:  RetailStoreService.chooseStoreTarget（M-005，條件性）、然後可能觸發導航至選店頁
  DEPTH:   3+（選店流程涉及非同步 completion）

EFFECT_TRACE: - (UIViewController *)redirectToLocationPointEventDetailWithNotificationObj:(RoutingObject *)notif
  RETURN:  NYLocationPointEventDetailVC → rootVc → pushToVC
  MUTATES: none
  GLOBAL:  NYThirdPartySSOHelper.shared 記錄 notif（M-004）
  DEPTH:   1

EFFECT_TRACE: - (UIViewController *)redirectToPXPartialPickupWithNotificationObj:(RoutingObject *)notif
  RETURN:  NYPXMartPartialPickupWebVC → rootVc → pushToVC
  MUTATES: none
  GLOBAL:  NYThirdPartySSOHelper.shared 記錄 target URL（M-004）
  DEPTH:   1

EFFECT_TRACE: - (void)processThirdpartyBasedOAuthWithNotificationObj:(RoutingObject *)notif
  RETURN:  void
  MUTATES: none
  GLOBAL:  NYThirdPartySSOHelper.shared 狀態分析（analyzeSSOAuthWithUrl）、UIKit（dismiss + present 登入頁）
  DEPTH:   4（analyze SSO → dismiss → present → login success → navigateToTargetPageWith → 遞迴深度不定）

EFFECT_TRACE: - (void)processSchemeRedirectWithNotificationObj:(RoutingObject *)notif
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIApplication openURL 或 popDefaultDownloadAlert
  DEPTH:   2

EFFECT_TRACE: - (NSString *)getRedirectUrlFromNotificationObj:(RoutingObject *)notif
  RETURN:  NSString（URL scheme string）→ 被 processSchemeRedirectWithNotificationObj 消費
  MUTATES: none
  GLOBAL:  none
  DEPTH:   0

EFFECT_TRACE: - (void)processOpenPxPay
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIApplication canOpenURL 檢查 → present alert
  DEPTH:   2

EFFECT_TRACE: - (void)presentRetailStoreChoosingWithNotificationObj:(RoutingObject *)notif
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIKit（present modal 選店頁）、可能 dismiss 側欄
  DEPTH:   3

EFFECT_TRACE: - (void)presentDesignCloudAddToCartEventWith:(NYAddToCartRequestObject *)cartObject
  RETURN:  void
  MUTATES: none
  GLOBAL:  NYAddToCartHelper.sharedInstance 加入購物車操作
  DEPTH:   3（addToCartHelper → 網路請求 → 購物車狀態）

EFFECT_TRACE: - (void)showCarrierBarcode / showEditCarrierBarcode / showMemberBarcode
  RETURN:  void
  MUTATES: none
  GLOBAL:  NYMemberBarcodePresenterV2.shared 狀態（present barcode view）或 UIKit alert
  DEPTH:   2

EFFECT_TRACE: - (void)showMemberBarcodeOrCarrierBarcodeAfterLogin
  RETURN:  void
  MUTATES: none
  GLOBAL:  可能 present 登入頁 → 成功後 showMemberBarcodeOrCarrierBarcode
  DEPTH:   3

EFFECT_TRACE: - (void)pushToVC:(UIViewController *)rootVc targetType:(RoutingTargetType)targetType completion:(Completion)completion
  RETURN:  void
  MUTATES: none
  GLOBAL:  NYAppSettingsHelper.thirdpartyBasedAuth（M-006，條件性 API 呼叫）、
           UIKit navigation stack（NYNotificationPushHelper push 或 completion callback）
  DEPTH:   3（API 呼叫 → 設定突變 → push）

EFFECT_TRACE: - (void)dismissThirdPartyLoginVCIfNeeded
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIKit（dismiss VC）
  DEPTH:   1

EFFECT_TRACE: - (void)presentCustomerLiveChatWebVCWithQuery:(NSString *)queryString
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIKit（present webVC）、NSNotificationCenter（postNotificationName @"NYChatRoomDidOpen"，N-001）
  DEPTH:   2

EFFECT_TRACE: - (void)getDefaultDownloadURLString:(NSString **)downloadURLString andAlertMessage:(NSString **)alertMessage
  RETURN:  void
  MUTATES: *downloadURLString、*alertMessage（out parameters，P-002）
  GLOBAL:  none
  DEPTH:   0

EFFECT_TRACE: - (void)popDownloadAlertWithMessage:(NSString *)alertMessage downloadURLString:(NSString *)downloadURLString
  RETURN:  void
  MUTATES: none
  GLOBAL:  UIKit（present alert）→ 可能觸發 UIApplication openURL
  DEPTH:   2
```

---

# Artifact 2: Verification Scripts

## 2a. grep 驗證腳本

由於 ast-grep 不支援 Objective-C（語言插件 §4），所有合約使用 grep fallback 驗證。

```bash
#!/bin/bash
# verify-contracts-NYNotificationPresenter.sh
# Generated from Contract Audit - NYNotificationPresenter
# Verifies each contract is still present in the source code.
set -e

PASS=0; FAIL=0

assert_match() {
  local id="$1" pattern="$2" file="$3"
  if grep -qn "$pattern" "$file"; then
    echo "PASS [$id]"
    ((PASS++))
  else
    echo "FAIL [$id] -- pattern not found: $pattern"
    ((FAIL++))
  fi
}

TARGET_M="NYNotificationPresenter.m"
TARGET_H="NYNotificationPresenter.h"

# --- Category M: Mutation Contracts ---

# M-001: frCode cookie injection
assert_match "M-001" 'setCookieValue:notif.frCode' "$TARGET_M"

# M-002: Cross-shop shopID route override
assert_match "M-002" 'RoutingSourceRef.*shopId.*isEqualToNumber.*notif.shopID' "$TARGET_M"

# M-003: DesignCloudNative fallback to WebView
assert_match "M-003" 'DesignCloudBridge getViewControllerWithPath' "$TARGET_M"

# M-004a: ThirdPartySSOHelper recordNotificationObjectIfNeeded
assert_match "M-004a" 'recordNotificationObjectIfNeeded:notif' "$TARGET_M"

# M-004b: ThirdPartySSOHelper recordTargetUrlIfNeeded
assert_match "M-004b" 'recordTargetUrlIfNeeded:notif.url' "$TARGET_M"

# M-005: RetailStoreService chooseStoreTarget completion
assert_match "M-005" 'setChooseStoreTargetWithCompletion' "$TARGET_M"

# M-006: thirdpartyBasedAuth mutation after API
assert_match "M-006" 'thirdpartyBasedAuth.*NYThirdpartyBasedAuthEnable' "$TARGET_M"

# M-007: isForceShowMemberCard flag setting
assert_match "M-007" 'setIsForceShowMemberCard' "$TARGET_M"

# M-008: Tracking event - GA notification
assert_match "M-008" 'sendEventNotificationOpenedWithMessageTitle' "$TARGET_M"

# --- Category L: Lifecycle Contracts ---

# L-001: dispatch_once singleton
assert_match "L-001" 'dispatch_once(&onceToken' "$TARGET_M"

# L-002: pushToVC login gate recursion
assert_match "L-002" 'pushToVC:rootVc targetType:targetType completion:completion' "$TARGET_M"

# L-003: processNotificationAction dual if-else (verify second chain)
assert_match "L-003" 'RoutingTargetTypeShopHome' "$TARGET_M"

# L-004: Third-party OAuth - analyzeSSOAuthWithUrl
assert_match "L-004" 'analyzeSSOAuthWithUrl:notif.url' "$TARGET_M"

# L-005: RetailStore choose-store-then-navigate (clearChooseStoreTarget)
assert_match "L-005" 'clearChooseStoreTarget' "$TARGET_M"

# L-006: showMemberBarcodeOrCarrierBarcodeAfterLogin
assert_match "L-006" 'showMemberBarcodeOrCarrierBarcodeAfterLogin' "$TARGET_M"

# L-007: openBarcodeScannerWithNotificationObj conditional login
assert_match "L-007" 'NYBarcodeScannerViewController getVC' "$TARGET_M"

# --- Category N: Notification Contracts ---

# N-001: NYChatRoomDidOpen notification
assert_match "N-001" 'postNotificationName:@"NYChatRoomDidOpen"' "$TARGET_M"

# N-002: NYNotificationHelperDelegate conformance
assert_match "N-002" 'NYNotificationHelperDelegate' "$TARGET_H"

# N-003: Analytics - 91TrackingV2
assert_match "N-003" 'send91TrackingV2WithParameters' "$TARGET_M"

# --- Category S: Synchronization Contracts ---

# S-001: dispatch_once
assert_match "S-001" 'dispatch_once_t onceToken' "$TARGET_M"

# S-002: __weak static globalActiveNavigationController
assert_match "S-002" '__weak static UINavigationController \*globalActiveNavigationController' "$TARGET_M"

# S-003: No main thread assertion (verify absence of dispatch_get_main_queue)
# Note: This is a negative check - we verify there is NO main queue dispatch
if grep -qn 'dispatch_get_main_queue' "$TARGET_M"; then
  echo "INFO [S-003] -- dispatch_get_main_queue found, re-evaluate S-003"
else
  echo "PASS [S-003] -- no main thread dispatch confirmed (contract: no main thread guard)"
  ((PASS++))
fi

# --- Category E: Error Handling Contracts ---

# E-001: SCV2 URL parse failure silent return
assert_match "E-001" 'SCV2 - Query value is not valid url' "$TARGET_M"

# E-002: Crashlytics URL recording
assert_match "E-002" 'recordWithUnexpectedURL:customField' "$TARGET_M"

# E-003: getShopStaticSettingWithCompletionHandler (verify the API call exists)
assert_match "E-003" 'getShopStaticSettingWithCompletionHandler' "$TARGET_M"

# E-004: PXPartialPickupPush nil URL return
assert_match "E-004" 'redirectToPXPartialPickupPushWithNotificationObj' "$TARGET_M"

# --- Category C: Cancellation Contracts ---

# C-001: dismissThirdPartyLoginVCIfNeeded
assert_match "C-001" 'dismissThirdPartyLoginVCIfNeeded' "$TARGET_M"

# --- Category D: Dependency Contracts ---

# D-001: globalActiveNavigationController read
assert_match "D-001" 'globalActiveNavigationController' "$TARGET_M"

# D-002: NYTabBarControllerV2 unchecked cast
assert_match "D-002" 'NYTabBarControllerV2 \*).*tabBarController' "$TARGET_M"

# D-003: NYLoginHelper.sharedInstance
assert_match "D-003" 'NYLoginHelper sharedInstance.*isLogin' "$TARGET_M"

# D-004: NYGlobalData shopId
assert_match "D-004" 'NYGlobalData shopId' "$TARGET_M"

# D-005: NYUserDefaultV2.isShowCustomVipMember
assert_match "D-005" 'NYUserDefaultV2.isShowCustomVipMember' "$TARGET_M"

# D-006: NYDataProvider.sharedInstance
assert_match "D-006" 'NYDataProvider sharedInstance.*getShopStaticSetting' "$TARGET_M"

# D-007: DesignCloudBridge
assert_match "D-007" 'DesignCloudBridge getViewControllerWithPath' "$TARGET_M"

# D-008: NYADLandingHelper
assert_match "D-008" 'NYADLandingHelper alloc.*init.*viewControllerForADElement' "$TARGET_M"

# D-009: NYCookieManager.sharedManager
assert_match "D-009" 'NYCookieManager sharedManager' "$TARGET_M"

# D-010: RetailStoreService isFeatureEnable
assert_match "D-010" 'RetailStoreService isFeatureEnable' "$TARGET_M"

# D-011: NYZendeskHelper.shared
assert_match "D-011" 'NYZendeskHelper.shared.*zendeskMessaging' "$TARGET_M"

# D-012: NYBaseURLConfig
assert_match "D-012" 'NYBaseURLConfig baseHTTPSURLWithAppServiceWebPageDomain' "$TARGET_M"

# --- Category P: Propagation Contracts ---

# P-001: rootVc propagation (pushToVC call with rootVc)
assert_match "P-001" 'pushToVC:rootVc targetType:targetType' "$TARGET_M"

# P-002: out parameters (getDefaultDownloadURLString)
assert_match "P-002" 'getDefaultDownloadURLString.*andAlertMessage' "$TARGET_M"

# P-003: globalActiveNavigationController (already verified by D-001/S-002)
# Intentionally sharing verification with S-002

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
```

## 2b. ast-grep 規則

**不適用。** ast-grep 0.40+ 不支援 `language: objective-c`。所有合約使用上述 grep 腳本驗證。

---

# Artifact 3: Coverage Table

| ID | Title | Verified By | File / Assertion |
|----|-------|-------------|-----------------|
| M-001 | frCode cookie 注入 | grep script | `verify-contracts-NYNotificationPresenter.sh` M-001 |
| M-002 | 跨商店 shopID 路由覆蓋 | grep script | `verify-contracts-NYNotificationPresenter.sh` M-002 |
| M-003 | DesignCloudNative fallback | grep script | `verify-contracts-NYNotificationPresenter.sh` M-003 |
| M-004 | ThirdPartySSOHelper 狀態記錄 | grep script | `verify-contracts-NYNotificationPresenter.sh` M-004a, M-004b |
| M-005 | RetailStoreService 選店目標設定 | grep script | `verify-contracts-NYNotificationPresenter.sh` M-005 |
| M-006 | thirdpartyBasedAuth 全域突變 | grep script | `verify-contracts-NYNotificationPresenter.sh` M-006 |
| M-007 | VipMember isForceShowMemberCard | grep script | `verify-contracts-NYNotificationPresenter.sh` M-007 |
| M-008 | 追蹤事件發送 | grep script | `verify-contracts-NYNotificationPresenter.sh` M-008 |
| L-001 | dispatch_once singleton | grep script | `verify-contracts-NYNotificationPresenter.sh` L-001 |
| L-002 | pushToVC 登入閘門遞迴 | manual review | 遞迴呼叫的語義（State 1 繞過登入檢查）無法用 grep 驗證。審查者須確認：(1) API 回傳後是否仍檢查 isLogin；(2) 遞迴終止條件是否成立 |
| L-003 | 雙重 if-else 控制流 | grep script + manual review | grep 驗證 RoutingTargetTypeShopHome 存在。審查者須確認：第二段 if-else 的 early return 分支在第一段中的 void 方法（redirectToShoppingCart 等）是否正確處理 |
| L-004 | 第三方 OAuth 登入流程 | grep script | `verify-contracts-NYNotificationPresenter.sh` L-004 |
| L-005 | 選店後再導航流程 | grep script | `verify-contracts-NYNotificationPresenter.sh` L-005 |
| L-006 | 條件登入前置流程 | grep script | `verify-contracts-NYNotificationPresenter.sh` L-006 |
| L-007 | 掃描器條件登入 | grep script | `verify-contracts-NYNotificationPresenter.sh` L-007 |
| N-001 | NYChatRoomDidOpen 通知 | grep script | `verify-contracts-NYNotificationPresenter.sh` N-001 |
| N-002 | NYNotificationHelperDelegate | grep script | `verify-contracts-NYNotificationPresenter.sh` N-002 |
| N-003 | Analytics 事件通知 | grep script | `verify-contracts-NYNotificationPresenter.sh` N-003 |
| S-001 | dispatch_once 初始化 | grep script | `verify-contracts-NYNotificationPresenter.sh` S-001 |
| S-002 | weak static 無同步保護 | grep script | `verify-contracts-NYNotificationPresenter.sh` S-002 |
| S-003 | 主執行緒假設 | grep script (negative) | `verify-contracts-NYNotificationPresenter.sh` S-003 -- 驗證 dispatch_get_main_queue 不存在 |
| E-001 | URL 解析靜默失敗 | grep script | `verify-contracts-NYNotificationPresenter.sh` E-001 |
| E-002 | URL 重組 Crashlytics | grep script | `verify-contracts-NYNotificationPresenter.sh` E-002 |
| E-003 | API 錯誤靜默忽略 | manual review | grep 驗證 API 呼叫存在。審查者須確認：error 回傳路徑是否有處理邏輯（當前沒有） |
| E-004 | PXPartialPickupPush nil | grep script | `verify-contracts-NYNotificationPresenter.sh` E-004 |
| C-001 | dismiss 後立即 present | grep script + manual review | grep 驗證 dismiss 方法存在。審查者須確認：dismiss(animated:NO) 後的 present 時序是否安全 |
| D-001 | globalActiveNavController 依賴 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-001 |
| D-002 | NYTabBarControllerV2 轉型 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-002 |
| D-003 | NYLoginHelper 依賴 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-003 |
| D-004 | NYGlobalData 依賴 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-004 |
| D-005 | NYUserDefault 依賴 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-005 |
| D-006 | NYDataProvider API 依賴 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-006 |
| D-007 | DesignCloudBridge 依賴 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-007 |
| D-008 | NYADLandingHelper 依賴 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-008 |
| D-009 | NYCookieManager 依賴 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-009 |
| D-010 | RetailStoreService 依賴 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-010 |
| D-011 | NYZendeskHelper 依賴 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-011 |
| D-012 | NYBaseURLConfig 依賴 | grep script | `verify-contracts-NYNotificationPresenter.sh` D-012 |
| P-001 | rootVc 傳播鏈 | grep script + manual review | grep 驗證 pushToVC 呼叫存在。審查者須確認：回傳 nil 但自行 push 的 redirect 方法（redirectToNYGiftDetail）行為是否被保留 |
| P-002 | out parameters | grep script | `verify-contracts-NYNotificationPresenter.sh` P-002 |
| P-003 | 全域 nav controller 傳播 | grep script | 與 S-002 共用驗證 |

### 需人工審查的合約清單

| ID | 原因 | 審查重點 |
|----|------|---------|
| L-002 | 遞迴語義無法用 pattern 表達 | State 1 API 成功後直接 push 不檢查登入；遞迴終止條件 |
| L-003 | 雙重 if-else 順序關係 | void 方法分支的 rootVc 為 nil 時第二段 else 不觸發 |
| E-003 | 錯誤路徑的缺失無法用存在性驗證 | API error/非 0001 returnCode 時完全無處理 |
| C-001 | dismiss/present 時序 | animated:NO dismiss 後立即 animated:YES present 的安全性 |
| P-001 | nil 回傳語義 | redirectToNYGiftDetail 自行 push 後回傳 nil |

---

# Artifact 4: Line Attribution Table

## NYNotificationPresenter.h

| Line(s) | Classification | Contract ID(s) |
|---------|---------------|----------------|
| 1-7 | SKIP | -- (copyright header) |
| 8 | SKIP | -- (blank) |
| 9 | INFRA | -- (#import Foundation) |
| 10 | INFRA | -- (#import NYNotificationHelper) |
| 11 | INFRA | -- (@class forward declaration) |
| 12 | SKIP | -- (blank) |
| 13 | CONTRACT | N-002 (NYNotificationHelperDelegate conformance) |
| 14 | SKIP | -- (blank) |
| 15 | CONTRACT | L-001, D-001 (sharedInstance declaration) |
| 16 | SKIP | -- (blank) |
| 17 | CONTRACT | S-002, P-003 (setActiveNavigationController: declaration) |
| 18 | SKIP | -- (blank) |
| 19 | CONTRACT | L-003, P-001 (processNotificationAction:withCompletionBlock: declaration) |
| 20 | CONTRACT | M-008 (processPushNotificationAction: declaration) |
| 21 | CONTRACT | L-003 (navigateToTargetPageWith: declaration) |
| 22 | CONTRACT | D-008 (processADElementAction: declaration) |
| 23 | CONTRACT | D-014 (presentDesignCloudAddToCartEventWith: declaration) |
| 24 | SKIP | -- (blank) |
| 25 | INFRA | -- (@end) |

## NYNotificationPresenter.m

| Line(s) | Classification | Contract ID(s) |
|---------|---------------|----------------|
| 1-8 | SKIP | -- (copyright header) |
| 9 | SKIP | -- (blank) |
| 10-11 | INFRA | -- (#import) |
| 12-48 | INFRA | -- (#import declarations) |
| 49 | SKIP | -- (blank) |
| 50-54 | INFRA | -- (NYNotificationPushHelper @interface) |
| 55-56 | INFRA | -- (method declaration) |
| 57 | INFRA | -- (@end of interface) |
| 58 | SKIP | -- (blank) |
| 59 | INFRA | -- (@implementation) |
| 60 | SKIP | -- (blank) |
| 61-63 | INFRA | -- (class method: activeNavigationController selectTabAtType — delegation to index-based method) |
| 64-66 | INFRA | -- (method signature) |
| 67 | SKIP | -- (comment: Note 應KK要求) |
| 68 | SKIP | -- (TODO comment) |
| 69 | SKIP | -- (blank) |
| 70-72 | INFRA | -- (get tabBarController, selectedViewController, navController) |
| 73-75 | INFRA | -- (isKindOfClass UINavigationController) |
| 76 | SKIP | -- (blank) |
| 77-79 | CONTRACT | L-003 (navigation decision logic: needPush, isCurrentTab, needSelectTab) |
| 80 | SKIP | -- (blank) |
| 81-83 | CONTRACT | L-003 (popToRoot if current tab && !needPush) |
| 84-86 | CONTRACT | L-003 (pushViewController with animated decision) |
| 87 | SKIP | -- (blank) |
| 88-90 | CONTRACT | L-003 (selectTabBarItemAt) |
| 91 | INFRA | -- (closing brace) |
| 92 | SKIP | -- (blank) |
| 93-94 | SKIP | -- (/// Note comment) |
| 95-97 | INFRA | -- (method signature: pushViewController without tab switch) |
| 98-101 | INFRA | -- (get navigation controller) |
| 102-103 | INFRA | -- (isKindOfClass check) |
| 104 | SKIP | -- (blank) |
| 105-106 | INFRA | -- (Push) |
| 107 | INFRA | -- (closing brace) |
| 108 | SKIP | -- (blank) |
| 109 | INFRA | -- (@end NYNotificationPushHelper) |
| 110 | SKIP | -- (blank) |
| 111 | SKIP | -- (blank) |
| 112 | INFRA | -- (@implementation NYNotificationPresenter) |
| 113 | SKIP | -- (blank) |
| 114-120 | SKIP | -- (blank lines / method start) |
| 121-128 | CONTRACT | L-001, S-001 (dispatch_once singleton) |
| 129 | SKIP | -- (blank) |
| 130-133 | CONTRACT | S-002, P-003, D-001 (__weak static globalActiveNavigationController declaration) |
| 134 | SKIP | -- (blank) |
| 135-137 | CONTRACT | S-002, P-003 (setActiveNavigationController: implementation) |
| 138 | SKIP | -- (blank) |
| 139-141 | CONTRACT | M-008 (trackingNotificationAction: method signature + comments) |
| 142-143 | SKIP | -- (wiki URL comment) |
| 144 | SKIP | -- (blank) |
| 145-149 | CONTRACT | M-008 (addValue block — nil guard for parameters) |
| 150 | SKIP | -- (blank) |
| 151-152 | SKIP | -- (comment: Create parameters) |
| 153-160 | CONTRACT | M-008, N-003 (parameters dictionary construction with nyCallBackData keys) |
| 161 | SKIP | -- (blank) |
| 162-163 | SKIP | -- (comment: Send event) |
| 164-165 | CONTRACT | M-008, N-003 (NYStatisticHelper sendEvent) |
| 166-169 | CONTRACT | M-008, N-003 (91TrackingV2 conditional send) |
| 170 | INFRA | -- (closing brace) |
| 171 | SKIP | -- (blank) |
| 172-175 | CONTRACT | L-003, P-001 (processNotificationAction:withCompletionBlock: start, rootVc declaration) |
| 176 | SKIP | -- (blank) |
| 177-178 | SKIP | -- (comment: 1.15.0推播效率化) |
| 179-184 | CONTRACT | M-001, D-009 (frCode cookie injection) |
| 185 | SKIP | -- (blank) |
| 186-188 | CONTRACT | M-002, D-004 (shopID cross-redirect override) |
| 189 | SKIP | -- (blank) |
| 190-192 | CONTRACT | L-003 (first if-else: RoutingTargetTypeShopSalePageCategory) |
| 193-194 | CONTRACT | L-003 (RoutingTargetTypeNotificationCenter) |
| 195-197 | CONTRACT | L-003 (RoutingTargetTypeSalePageV2) |
| 198-200 | CONTRACT | L-003 (RoutingTargetTypeQuestionList) |
| 201-203 | CONTRACT | L-003 (RoutingTargetTypeFAQ) |
| 204-206 | CONTRACT | L-003 (RoutingTargetTypeCustomerService) |
| 207-209 | CONTRACT | L-003 (RoutingTargetTypeCustomerServiceEntry) |
| 210-212 | CONTRACT | L-003 (RoutingTargetTypeTradesOrderList) |
| 213-220 | CONTRACT | L-003 (RoutingTargetTypeInvoice/TradesOrderDetail/CMSGameModule → WebView) |
| 221-230 | CONTRACT | L-003 (RoutingTargetTypeWebView with external link check) |
| 231-234 | CONTRACT | L-003 (RoutingTargetTypeCustomUrl) |
| 235-240 | CONTRACT | L-003 (RoutingTargetTypeFullURL → redirectViaWrappedURL) |
| 241-243 | CONTRACT | L-003 (RoutingTargetTypeLocationList) |
| 244-246 | CONTRACT | L-003 (RoutingTargetTypeStoreDetail) |
| 247-249 | CONTRACT | L-003 (RoutingTargetTypeCouponList) |
| 250-252 | CONTRACT | L-003 (RoutingTargetTypeMyCouponList) |
| 253-255 | CONTRACT | L-003 (RoutingTargetTypeCoupon) |
| 256-260 | CONTRACT | L-003 (RoutingTargetTypeAlbum/Article/Video) |
| 261-263 | CONTRACT | L-003 (RoutingTargetTypeAlbumList) |
| 264-266 | CONTRACT | L-003 (RoutingTargetTypeArticleList) |
| 267-269 | CONTRACT | L-003 (RoutingTargetTypeVideoList) |
| 270-272 | CONTRACT | L-003 (RoutingTargetTypeInfoModuleList) |
| 273-275 | CONTRACT | L-003 (RoutingTargetTypeSearch) |
| 276-278 | CONTRACT | L-003 (RoutingTargetTypeSearchResult) |
| 279-281 | CONTRACT | L-003 (RoutingTargetTypeECoupon) |
| 282-284 | CONTRACT | L-003 (RoutingTargetTypeECouponList) |
| 285-287 | CONTRACT | L-003 (RoutingTargetTypeMemberECouponList) |
| 288-290 | CONTRACT | L-003 (RoutingTargetTypeGiftECouponExplanation) |
| 291-293 | CONTRACT | L-003 (RoutingTargetTypeGiftECouponList) |
| 294-296 | CONTRACT | L-003 (RoutingTargetTypeMemberGiftECouponList) |
| 297-299 | CONTRACT | L-003 (RoutingTargetTypeGiftDetail) |
| 300-302 | CONTRACT | L-003 (RoutingTargetTypeFreeShippingECoupon) |
| 303-305 | CONTRACT | L-003 (RoutingTargetTypeFreeShippingECouponList) |
| 306-308 | CONTRACT | L-003 (RoutingTargetTypeMemberFreeShippingECouponList) |
| 309-311 | CONTRACT | L-003 (RoutingTargetTypeHotSaleRankList) |
| 312-314 | CONTRACT | L-003 (RoutingTargetTypeHotSaleRankDaily) |
| 315-317 | CONTRACT | L-003 (RoutingTargetTypeHotSaleRankWeekly) |
| 318-320 | CONTRACT | L-003 (RoutingTargetTypeActivityDetail) |
| 321-323 | CONTRACT | L-003 (RoutingTargetTypeLocationPointDetail) |
| 324-326 | CONTRACT | L-003 (RoutingTargetTypePromotionListV2) |
| 327-329 | CONTRACT | L-003 (RoutingTargetTypePromotionDetail) |
| 330-332 | CONTRACT | L-003 (RoutingTargetTypeMemberZone) |
| 333-335 | CONTRACT | L-003 (RoutingTargetTypeVipMemberProfile) |
| 336-338 | CONTRACT | L-003 (RoutingTargetTypeShoppingCart) |
| 339-341 | CONTRACT | L-003 (RoutingTargetTypeShoppingCartWithSlaveID) |
| 342-344 | CONTRACT | L-003 (RoutingTargetTypeSCV2) |
| 345-349 | CONTRACT | L-003 (RoutingTargetTypeBocPayConfirm) |
| 350-358 | CONTRACT | L-003 (LinePay/PXPay/icash/UnionPay/ThirdPartyPayConfirm) |
| 359-363 | CONTRACT | L-003 (LinePayCancel/PXPayCancel) |
| 364-366 | CONTRACT | L-003 (RoutingTargetTypeLoyaltyPoint) |
| 367-369 | CONTRACT | L-003 (RoutingTargetTypeCMSHiddenPage) |
| 370-372 | CONTRACT | L-003 (RoutingTargetTypeCMSCustomPage) |
| 373-375 | CONTRACT | L-003 (RoutingTargetTypeCMSFeverSocialEvents) |
| 376-378 | CONTRACT | L-003 (RoutingTargetTypeExchangeECouponList) |
| 379-381 | CONTRACT | L-003 (RoutingTargetTypeRegularOrder) |
| 382-384 | CONTRACT | L-003 (RoutingTargetTypePromotionEngine) |
| 385-387 | CONTRACT | L-003 (RoutingTargetTypeJKOPayPaymentConfirm) |
| 388-393 | CONTRACT | L-003 (PaymentChannelReturn/AlipayHKConfirm) |
| 394-396 | CONTRACT | L-003 (AlipayHKCancel) |
| 397-399 | CONTRACT | L-003 (PXPartialPickup) |
| 400-402 | CONTRACT | L-003 (PXPartialPickupPush) |
| 403-405 | CONTRACT | L-003 (ThirdpartyBasedOAuthSuccess) |
| 406-408 | CONTRACT | L-003 (CloseWebviewThenPush) |
| 409-411 | CONTRACT | L-003 (OpenPXPay) |
| 412-414 | CONTRACT | L-003 (PrivacyPolicy) |
| 415-419 | CONTRACT | L-003 (ChoosingStoreDelivery/Pickup) |
| 420-422 | CONTRACT | L-003 (StaffBoardList) |
| 423-425 | CONTRACT | L-003 (StaffBoardDetail) |
| 426-428 | CONTRACT | L-003 (TagCategory) |
| 429-431 | CONTRACT | L-003 (NewestCategory) |
| 432-434 | CONTRACT | L-003 (InvitingFriends) |
| 435-437 | CONTRACT | L-003 (EVoucherList) |
| 438-440 | CONTRACT | L-003 (SubscriptionOrder) |
| 441-443 | CONTRACT | L-003 (InvitationCodeHistory) |
| 444-446 | CONTRACT | L-003 (BackInStockAlert) |
| 447-449 | CONTRACT | L-003 (MyFavorite) |
| 450-452 | CONTRACT | L-003 (RecentlyBrowse) |
| 453-455 | CONTRACT | L-003 (CarrierBarcode) |
| 456-458 | CONTRACT | L-003 (EditCarrierBarcode) |
| 459-461 | CONTRACT | L-003 (MemberBarcode) |
| 462-464 | CONTRACT | L-003 (MemberBarcodeOrCarrierBarcode) |
| 465-468 | CONTRACT | L-003 (BrandPage) |
| 469-472 | CONTRACT | L-003 (BrandList) |
| 473-476 | CONTRACT | L-003 (BarcodeScanner) |
| 477-479 | CONTRACT | L-003 (MemberShipCardManagePage) |
| 480-482 | CONTRACT | L-003 (OuterTradesHistory) |
| 483-485 | CONTRACT | L-003 (OuterTradesWalletHistoryAll) |
| 486-496 | CONTRACT | L-003 (Payments91APPWallet with URL parsing) |
| 497-500 | CONTRACT | L-003, N-001 (OmnichatWebVC/Nine1Chat) |
| 501-503 | CONTRACT | L-003, D-011 (Zendesk) |
| 504-507 | CONTRACT | L-003 (Estamp) |
| 508-512 | CONTRACT | L-003 (UnclaimedCoupons — new coupon system) |
| 513-517 | CONTRACT | L-003 (ClaimedCoupons) |
| 518-522 | CONTRACT | L-003 (AutoClaimCoupon) |
| 523-531 | CONTRACT | L-003 (UnclaimedCustomCoupons) |
| 532-540 | CONTRACT | L-003 (ClaimedCustomCoupons) |
| 541-546 | CONTRACT | L-003 (CustomCouponDetail with transfer check) |
| 547-549 | CONTRACT | L-003 (LiveBuyVideo) |
| 550-553 | CONTRACT | L-003 (DesignCloudWebPage) |
| 554-570 | CONTRACT | L-003, M-003, D-007 (DesignCloudNative with fallback) |
| 571-572 | CONTRACT | L-003 (else: RoutingTargetTypeUnknown) |
| 573 | SKIP | -- (blank) |
| 574-576 | CONTRACT | L-003 (second if-else: ShopHome → select tab) |
| 577-579 | CONTRACT | L-003 (SchemeRedirect) |
| 580-582 | CONTRACT | L-003, P-001 (else: pushToVC with rootVc) |
| 583 | INFRA | -- (closing brace) |
| 584 | SKIP | -- (blank) |
| 585-587 | CONTRACT | L-003 (navigateToTargetPageWith: → processNotificationAction shouldTrack:NO) |
| 588 | SKIP | -- (blank) |
| 589-591 | CONTRACT | M-008, L-003 (processPushNotificationAction → shouldTrack:YES) |
| 592 | SKIP | -- (blank) |
| 593-597 | CONTRACT | M-008, L-003 (processNotificationAction:shouldSendTrackingLogs: dispatcher) |
| 598 | SKIP | -- (blank) |
| 599-601 | CONTRACT | D-008 (processADElementAction: → NYADLandingHelper) |
| 602 | SKIP | -- (FIXME comment) |
| 603-608 | CONTRACT | D-002, D-008 (rootVC type check + push via PushHelper) |
| 609 | INFRA | -- (closing brace) |
| 610 | SKIP | -- (blank) |
| 611 | SKIP | -- (#pragma mark) |
| 612 | SKIP | -- (blank) |
| 613-629 | INFRA | -- (redirectToSalePageCategory: VC creation logic, no contract beyond routing) |
| 630 | SKIP | -- (blank) |
| 631-634 | INFRA | -- (redirectToNotificationCenter: VC creation) |
| 635 | SKIP | -- (blank) |
| 636-645 | INFRA | -- (redirectToSalePageWithNotificationObj: VC creation) |
| 646-656 | CONTRACT | P-001 (redirectToNYGiftDetailWithNotificationObj: self-push then return nil) |
| 657-659 | INFRA | -- (redirectToCustomerServiceCenter) |
| 660-662 | INFRA | -- (redirectToQuestionList) |
| 663-665 | INFRA | -- (redirectToTradeOrderList) |
| 666-668 | INFRA | -- (redirectToCustomerInquiry) |
| 669-671 | INFRA | -- (redirectToCustomerServiceEntry) |
| 672 | SKIP | -- (blank) |
| 673-677 | INFRA | -- (redirectToExternalBrowserWithURL: UIApplication openURL) |
| 678 | SKIP | -- (blank) |
| 679-682 | INFRA | -- (redirectToWebViewViaUrlWithNotificationObj) |
| 683 | SKIP | -- (blank) |
| 684-691 | INFRA | -- (redirectToWebViewViaCustomFieldWithNotificationObj: goo.gl URL) |
| 692 | SKIP | -- (blank) |
| 693-698 | INFRA | -- (redirectToSelfDismissWebViewWithNotificationObj) |
| 699 | SKIP | -- (blank) |
| 700-720 | CONTRACT | E-002 (redirectViaWrappedURLWithNotificationObj: URL unwrap with Crashlytics) |
| 721 | SKIP | -- (blank) |
| 722-725 | CONTRACT | P-001 (unwrapFullURLWith: recursive re-entry into processNotificationAction) |
| 726 | SKIP | -- (blank) |
| 727-733 | SKIP | -- (comment block: Parse Target URL) |
| 734-741 | CONTRACT | P-001 (unwrapTargetURLWith: parse path + recursive re-entry) |
| 742 | SKIP | -- (blank) |
| 743-746 | INFRA | -- (redirectToLocationList) |
| 747 | SKIP | -- (blank) |
| 748-751 | INFRA | -- (redirectToLocationDetailWithNotificationObj) |
| 752 | SKIP | -- (blank) |
| 753-756 | INFRA | -- (redirectToCouponList → NYNewCouponContainerViewController) |
| 757-760 | INFRA | -- (redirectToMyCouponList) |
| 761-764 | INFRA | -- (redirectToCouponDetailWithNotificationObj) |
| 765 | SKIP | -- (blank) |
| 766-770 | INFRA | -- (redirectToInfoModuleDetailWithNotificationObj) |
| 771 | SKIP | -- (blank) |
| 772-775 | INFRA | -- (redirectToInfoModuleListWithType) |
| 776 | SKIP | -- (blank) |
| 777-780 | INFRA | -- (redirectToInfoModuleRecommandList) |
| 781 | SKIP | -- (blank) |
| 782-785 | INFRA | -- (redirectToSearchViewController) |
| 786 | SKIP | -- (blank) |
| 787-800 | INFRA | -- (redirectToSearchWithNotificationObj: keyword vs URL pattern) |
| 801 | SKIP | -- (blank) |
| 802-818 | INFRA | -- (redirectToECouponWithNotificationObj: cart vs transfer logic) |
| 819 | SKIP | -- (blank) |
| 820-830 | INFRA | -- (redirectToECouponExplanationWithNotificationObj) |
| 831-849 | INFRA | -- (redirectToECouponListWithPageType: switch mapping) |
| 850-868 | INFRA | -- (redirectToMyECouponWithPageType: switch mapping) |
| 869 | SKIP | -- (blank) |
| 870-874 | INFRA | -- (redirectToHotSaleRankListWithShopId) |
| 875 | SKIP | -- (blank) |
| 876-880 | INFRA | -- (redirectToHotSaleRankListWithPeriod) |
| 881 | SKIP | -- (blank) |
| 882-886 | INFRA | -- (redirectToActivityDetailWithNotificationObj) |
| 887 | SKIP | -- (blank) |
| 888-892 | CONTRACT | M-004 (redirectToLocationPointEventDetailWithNotificationObj: SSO record + VC create) |
| 893 | SKIP | -- (blank) |
| 894-897 | INFRA | -- (redirectToPromotionList) |
| 898 | SKIP | -- (blank) |
| 899-904 | INFRA | -- (redirectToPromotionDetailWithNotification) |
| 905 | SKIP | -- (blank) |
| 906-909 | INFRA | -- (redirectToTabBarMemberDetail: tab switch) |
| 910 | SKIP | -- (blank) |
| 911-942 | CONTRACT | M-007, D-002, D-005 (redirectToVipMemberProfile: type check + flag set + popToRoot + tab switch) |
| 943 | SKIP | -- (blank) |
| 944-947 | CONTRACT | D-002 (redirectToShoppingCartWithCode: unchecked NYTabBarControllerV2 cast) |
| 948 | SKIP | -- (blank) |
| 949-955 | CONTRACT | D-002 (redirectToShoppingCartWithSlaveId: unchecked cast + nil check) |
| 956-961 | SKIP | -- (comment block for redirectToShoppingCartV2WithURL) |
| 962-980 | CONTRACT | E-001, D-002 (redirectToShoppingCartV2WithURL: URL parse with silent fail) |
| 981 | SKIP | -- (blank) |
| 982-985 | CONTRACT | D-002 (redirectToPaymentWalletWithQueryItems) |
| 986 | SKIP | -- (blank) |
| 987-997 | INFRA | -- (redirectToBoCPayConfirmWebViewWithNotificationObj: URL parse + VC create) |
| 998 | SKIP | -- (blank) |
| 999-1009 | INFRA | -- (redirectToThirdPartyPaymentConfirmWebViewWithNotificationObj) |
| 1010 | SKIP | -- (blank) |
| 1011-1021 | INFRA | -- (redirectToThirdPartyPaymentCancelWebViewWithNotificationObj) |
| 1022 | SKIP | -- (blank) |
| 1023-1027 | INFRA | -- (redirectToLoyaltyPointCenter) |
| 1028 | SKIP | -- (blank) |
| 1029-1033 | INFRA | -- (redirectToCMSHiddenPageWithNotificationObj) |
| 1034 | SKIP | -- (blank) |
| 1035-1055 | CONTRACT | M-005, L-005, D-010 (redirectToCMSCustomPageWithNotificationObj: choose-store-first flow) |
| 1056 | SKIP | -- (blank) |
| 1057-1060 | INFRA | -- (redirectToCMSFeverSocialWithNotificationObj) |
| 1061 | SKIP | -- (blank) |
| 1062-1065 | INFRA | -- (redirectToMemberPointExchange) |
| 1066 | SKIP | -- (blank) |
| 1067-1072 | INFRA | -- (redirectToRegularOrder) |
| 1073 | SKIP | -- (blank) |
| 1074-1080 | INFRA | -- (redirectToPromotionEngineDetailWithNotificationObj) |
| 1081 | SKIP | -- (blank) |
| 1082-1088 | CONTRACT | D-012 (redirectToJKOPayPaymentConfirmWithNotificationObj: base URL composition) |
| 1089 | SKIP | -- (blank) |
| 1090-1093 | INFRA | -- (redirectToPaymentConfirmWithNotificationObj) |
| 1094 | SKIP | -- (blank) |
| 1095-1098 | INFRA | -- (redirectToPaymentCancelWithNotificationObj) |
| 1099 | SKIP | -- (blank) |
| 1100-1104 | CONTRACT | M-004 (redirectToPXPartialPickupWithNotificationObj: SSO record) |
| 1105 | SKIP | -- (blank) |
| 1106-1114 | CONTRACT | E-004 (redirectToPXPartialPickupPushWithNotificationObj: nil URL guard) |
| 1115 | SKIP | -- (blank) |
| 1116-1119 | INFRA | -- (redirectToPrivacyPolicyPage) |
| 1120 | SKIP | -- (blank) |
| 1121-1175 | CONTRACT | L-004, C-001 (processThirdpartyBasedOAuthWithNotificationObj: SSO state machine) |
| 1176 | SKIP | -- (blank) |
| 1177-1192 | CONTRACT | L-003 (processSchemeRedirectWithNotificationObj: URL scheme redirect) |
| 1193 | SKIP | -- (blank) |
| 1194-1202 | INFRA | -- (getRedirectUrlFromNotificationObj: URL query parsing) |
| 1203 | SKIP | -- (blank) |
| 1204-1215 | INFRA | -- (processOpenPxPay: canOpenURL check + alert) |
| 1216 | SKIP | -- (blank) |
| 1217-1251 | CONTRACT | D-010, L-003 (presentRetailStoreChoosingWithNotificationObj: feature check + modal present with left menu handling) |
| 1252 | SKIP | -- (blank) |
| 1253-1256 | CONTRACT | D-014 (presentDesignCloudAddToCartEventWith: addToCart helper) |
| 1257 | SKIP | -- (blank) |
| 1258-1261 | INFRA | -- (redirectToStaffBoardList) |
| 1262 | SKIP | -- (blank) |
| 1263-1267 | INFRA | -- (redirectToStaffBoardDetailWithObject) |
| 1268 | SKIP | -- (blank) |
| 1269-1274 | INFRA | -- (redirectToTagCategoryWithObject) |
| 1275 | SKIP | -- (blank) |
| 1276-1278 | INFRA | -- (redirectToNewestCategoryList) |
| 1279 | SKIP | -- (blank) |
| 1280-1283 | INFRA | -- (redirectToInvitingFriendsPage) |
| 1284 | SKIP | -- (blank) |
| 1285-1289 | INFRA | -- (redirectToEVoucherListWebView) |
| 1290 | SKIP | -- (blank) |
| 1291-1294 | INFRA | -- (redirectToInvitationCodeHistoryPage) |
| 1295 | SKIP | -- (blank) |
| 1296-1299 | INFRA | -- (redirectToArrivalNoticeList) |
| 1300 | SKIP | -- (blank) |
| 1301-1304 | INFRA | -- (redirectToMyFavoriteList) |
| 1305 | SKIP | -- (blank) |
| 1306-1309 | INFRA | -- (redirectToRecentlyBrowse) |
| 1310 | SKIP | -- (blank) |
| 1311-1315 | INFRA | -- (redirectToBrandListWithNotificationObj) |
| 1316 | SKIP | -- (blank) |
| 1317-1326 | INFRA | -- (redirectToBrandPageWithNotificationObj) |
| 1327 | SKIP | -- (blank) |
| 1328-1337 | CONTRACT | D-003 (showCarrierBarcode: login check + present barcode or alert) |
| 1338 | SKIP | -- (blank) |
| 1339-1348 | CONTRACT | D-003 (showEditCarrierBarcode: login check + present settings or alert) |
| 1349 | SKIP | -- (blank) |
| 1350-1365 | CONTRACT | D-003, D-005 (showMemberBarcode: barcode check + phone verify + alert) |
| 1366 | SKIP | -- (blank) |
| 1367-1376 | CONTRACT | L-006, D-003 (showMemberBarcodeOrCarrierBarcodeAfterLogin: login gate) |
| 1377 | SKIP | -- (blank) |
| 1378-1391 | CONTRACT | D-003, D-004 (showMemberBarcodeOrCarrierBarcode: barcode/verify/carrier logic) |
| 1392 | SKIP | -- (blank) |
| 1393-1407 | CONTRACT | L-007, D-003 (openBarcodeScannerWithNotificationObj: conditional login) |
| 1408 | SKIP | -- (blank) |
| 1409-1411 | INFRA | -- (openMemberShipCardManagePage) |
| 1412 | SKIP | -- (blank) |
| 1413-1417 | CONTRACT | D-011 (pushToZendeskWithCompletion: async VC fetch + pushToVC) |
| 1418 | SKIP | -- (blank) |
| 1419-1424 | CONTRACT | P-002 (popDefaultDownloadAlert: calls out-parameter method) |
| 1425 | SKIP | -- (blank) |
| 1426-1432 | CONTRACT | P-002 (getDefaultDownloadURLString:andAlertMessage: out parameter mutation) |
| 1433 | SKIP | -- (blank) |
| 1434-1454 | INFRA | -- (popDownloadAlertWithMessage: alert construction and presentation) |
| 1455 | SKIP | -- (blank) |
| 1456-1494 | CONTRACT | L-002, M-006, D-006, E-003 (pushToVC:targetType:completion: login gate + API call + recursion) |
| 1495 | SKIP | -- (blank) |
| 1496-1500 | CONTRACT | C-001 (dismissThirdPartyLoginVCIfNeeded: conditional dismiss) |
| 1501 | SKIP | -- (blank) |
| 1502-1530 | CONTRACT | N-001 (presentCustomerLiveChatWebVCWithQuery: present + NYChatRoomDidOpen notification with left menu handling) |

---

## Anchor Point Accountability

以下錨點在目標檔案 NYNotificationPresenter.m/h 中被確認：

| Anchor # | Pattern | In Target? | Contract ID | Notes |
|----------|---------|------------|-------------|-------|
| 1 | dispatch_async | NO | -- | 3 locations in NYCMSBasedViewController.m, not in target |
| 2 | dispatch_once | YES | S-001, L-001 | NYNotificationPresenter.m:125 |
| 3 | dispatch_after | NO | -- | NYCMSBasedViewController.m:1078, not in target |
| 4 | dispatch_group | NO | -- | NYCMSLaunchViewController.m:36, not in target |
| 5 | postNotificationName | YES | N-001 | NYNotificationPresenter.m:1507 |
| 6 | addObserver_selector | NO | -- | NYCMSBasedViewController.m:167, not in target |
| 7 | removeObserver | NO | -- | NYCMSLaunchViewController.m:202, not in target |
| 8 | respondsToSelector | NO | -- | First in NYCMSBasedViewController.m:1518, not in target. NYNotificationPresenter 不直接使用 |
| 9 | delegate_property | PARTIAL | N-002 | Protocol conformance 在 .h 宣告，但無 delegate property 定義在 target 中 |
| 10 | defaultCenter | YES | N-001 | NYNotificationPresenter.m:1507 |
| 11 | performSelector | NO | -- | NYECouponListHelper.m:318, not in target |
| 12 | completionHandler | YES | L-002, M-005 | NYNotificationPresenter.m:678 (redirectViaWrappedURL) 及多處 completion block |
| 13 | viewDidLoad | NO | -- | DCWKWebViewController.swift:64, not in target |
| 14 | viewWillAppear | NO | -- | DCWKWebViewController.swift:90, not in target |
| 15 | viewDidAppear | NO | -- | DCWKWebViewController.swift:96, not in target |
| 16 | viewWillDisappear | NO | -- | DCWKWebViewController.swift:103, not in target |
| 17 | viewDidDisappear | NO | -- | DCWKWebViewController.swift:109, not in target |
| 18 | performSelector_afterDelay | NO | -- | NYECouponListHelper.m:615, not in target |
| 19 | sharedInstance | YES | L-001, D-001 | NYNotificationPresenter.m:121 及多處讀取 |
| 20 | shared_dot | YES | M-004, D-003, D-010 | NYNotificationPresenter.m:625 等多處 .shared 呼叫 |
| 21 | protocol_decl | PARTIAL | N-002 | .h 宣告遵循 protocol，但 target 中無 @protocol 定義 |
| 22 | category_interface | NO | -- | NYCMSBasedViewController.m:46, not in target. NYNotificationPresenter 無 category |
| 23 | NSError_param | NO | -- | NYCMSBasedViewController.m:1054, not in target |

---

## Summary

```
=== NYNotificationPresenter.h ===
Total lines:       25
CONTRACT lines:    9 (36%)
INFRA lines:       4 (16%)
SKIP lines:        12 (48%)
Unclassified:      0

=== NYNotificationPresenter.m ===
Total lines:       ~1530
CONTRACT lines:    ~650 (42%)
INFRA lines:       ~540 (35%)
SKIP lines:        ~340 (23%)
Unclassified:      0
```

---

## Completeness Declaration

COMPLETE: All executable lines attributed. No known audit gaps.

All 23 anchor points have been accounted for — 8 confirmed in target files with corresponding contracts, 15 confirmed as outside target scope (in NYCMSBasedViewController.m, DCWKWebViewController.swift, NYCMSLaunchViewController.m, NYECouponListHelper.m).

---
