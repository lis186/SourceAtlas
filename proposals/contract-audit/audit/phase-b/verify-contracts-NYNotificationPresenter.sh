#!/bin/bash
# verify-contracts-NYNotificationPresenter.sh
# Generated from Contract Audit - NYNotificationPresenter (Final Merged)
# Generated: 2026-03-09
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

# M-006: thirdpartyBasedAuth mutation after API [DISPUTED -- risk downgraded]
assert_match "M-006" 'thirdpartyBasedAuth.*NYThirdpartyBasedAuthEnable' "$TARGET_M"

# M-007: isForceShowMemberCard flag setting
assert_match "M-007" 'setIsForceShowMemberCard' "$TARGET_M"

# M-008: Tracking event - GA notification
assert_match "M-008" 'sendEventNotificationOpenedWithMessageTitle' "$TARGET_M"

# --- Category L: Lifecycle Contracts ---

# L-001: dispatch_once singleton
assert_match "L-001" 'dispatch_once(&onceToken' "$TARGET_M"

# L-002: pushToVC login gate recursion [DISPUTED -- risk downgraded]
assert_match "L-002" 'pushToVC:rootVc targetType:targetType completion:completion' "$TARGET_M"

# L-003: processNotificationAction dual if-else (verify second chain) [DISPUTED -- description corrected]
assert_match "L-003" 'RoutingTargetTypeShopHome' "$TARGET_M"

# L-004: Third-party OAuth - analyzeSSOAuthWithUrl
assert_match "L-004" 'analyzeSSOAuthWithUrl:notif.url' "$TARGET_M"

# L-005: RetailStore choose-store-then-navigate (clearChooseStoreTarget)
assert_match "L-005" 'clearChooseStoreTarget' "$TARGET_M"

# L-006: showMemberBarcodeOrCarrierBarcodeAfterLogin
assert_match "L-006" 'showMemberBarcodeOrCarrierBarcodeAfterLogin' "$TARGET_M"

# L-007: openBarcodeScannerWithNotificationObj conditional login
assert_match "L-007" 'NYBarcodeScannerViewController getVC' "$TARGET_M"

# L-008: Current Tab Pop-to-Root lifecycle [ADD]
assert_match "L-008" 'popToRootViewControllerAnimated' "$TARGET_M"

# --- Category N: Notification Contracts ---

# N-001: NYChatRoomDidOpen notification [META: seam_type → link]
assert_match "N-001" 'postNotificationName:@"NYChatRoomDidOpen"' "$TARGET_M"

# N-002: NYNotificationHelperDelegate conformance [DISPUTED -- description corrected]
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

# E-001: SCV2 URL parse failure with NSLog [DISPUTED -- not fully silent, has NSLog]
assert_match "E-001" 'SCV2 - Query value is not valid url' "$TARGET_M"

# E-002: Crashlytics URL recording
assert_match "E-002" 'recordWithUnexpectedURL:customField' "$TARGET_M"

# E-003: getShopStaticSettingWithCompletionHandler (verify the API call exists)
assert_match "E-003" 'getShopStaticSettingWithCompletionHandler' "$TARGET_M"

# E-004: PXPartialPickupPush nil URL return
assert_match "E-004" 'redirectToPXPartialPickupPushWithNotificationObj' "$TARGET_M"

# E-005: Scheme Redirect missing-app fallback [ADD]
assert_match "E-005" 'popDefaultDownloadAlert' "$TARGET_M"

# --- Category C: Cancellation Contracts ---

# C-001: dismissThirdPartyLoginVCIfNeeded [DISPUTED -- risk downgraded]
assert_match "C-001" 'dismissThirdPartyLoginVCIfNeeded' "$TARGET_M"

# --- Category D: Dependency Contracts ---

# D-001: globalActiveNavigationController read [DISPUTED -- description corrected]
assert_match "D-001" 'globalActiveNavigationController' "$TARGET_M"

# D-002: NYTabBarControllerV2 unchecked cast [DISPUTED -- description corrected]
assert_match "D-002" 'NYTabBarControllerV2 \*).*tabBarController' "$TARGET_M"

# D-003: NYLoginHelper.sharedInstance
assert_match "D-003" 'NYLoginHelper sharedInstance.*isLogin' "$TARGET_M"

# D-004: NYGlobalData shopId [DISPUTED -- risk downgraded]
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

# D-011: NYZendeskHelper.shared [DISPUTED -- nil guard issue noted]
assert_match "D-011" 'NYZendeskHelper.shared.*zendeskMessaging' "$TARGET_M"

# D-012: NYBaseURLConfig
assert_match "D-012" 'NYBaseURLConfig baseHTTPSURLWithAppServiceWebPageDomain' "$TARGET_M"

# --- Category P: Propagation Contracts ---

# P-001: rootVc propagation (pushToVC call with rootVc)
assert_match "P-001" 'pushToVC:rootVc targetType:targetType' "$TARGET_M"

# P-002: out parameters (getDefaultDownloadURLString)
assert_match "P-002" 'getDefaultDownloadURLString.*andAlertMessage' "$TARGET_M"

# P-003: globalActiveNavigationController propagation [DISPUTED -- description corrected]
# Shared verification with S-002 + D-001

# P-004: Conditional Tab Selection [ADD]
assert_match "P-004" 'selectTabBarItemAt' "$TARGET_M"

# P-005: Scheme Redirect external propagation [ADD]
assert_match "P-005" 'openURL.*URLWithString:urlScheme' "$TARGET_M"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
