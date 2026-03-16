#!/bin/bash
# Contract Verification Script: NYNotificationPresenter
# Generated: 2026-03-09
# Language: Objective-C (grep-only, ast-grep not supported)
#
# Usage: ./verify-contracts-NYNotificationPresenter.sh <path-to-NYNotificationPresenter.m>
#
# This script verifies that all identified contracts still exist in the source code.
# Run AFTER any refactoring to ensure no contracts were accidentally removed.

set -e

PASS=0
FAIL=0

TARGET="${1:-NYNotificationPresenter.m}"
HEADER="${TARGET%.m}.h"

if [ ! -f "$TARGET" ]; then
    echo "ERROR: Target file not found: $TARGET"
    echo "Usage: $0 <path-to-NYNotificationPresenter.m>"
    exit 2
fi

assert_match() {
    local id="$1" pattern="$2" file="$3"
    if grep -qn "$pattern" "$file" 2>/dev/null; then
        echo "PASS [$id]"
        ((PASS++))
    else
        echo "FAIL [$id] -- pattern not found: $pattern in $file"
        ((FAIL++))
    fi
}

echo "=== Contract Verification: NYNotificationPresenter ==="
echo "Target: $TARGET"
echo "Header: $HEADER"
echo ""

# ============================================================
# Category M -- Mutation Contracts
# ============================================================
echo "--- Category M: Mutation Contracts ---"

# M-001: frCode Cookie Injection
assert_match "M-001" 'setCookieValue:notif.frCode' "$TARGET"

# M-002: GA Tracking Event
assert_match "M-002" 'sendEventNotificationOpenedWithMessageTitle:notif.title' "$TARGET"

# M-003: 91TrackingV2 dl Parameter
assert_match "M-003" 'send91TrackingV2WithParameters:tsParams' "$TARGET"

# M-004: VIP Member Force Show Card
assert_match "M-004" 'setIsForceShowMemberCard:\[NYUserDefault isShowVipMemberInfo\]' "$TARGET"

# M-004b: Also check NYMemberV2ViewController path
assert_match "M-004b" 'isForceShowMemberCard = \[NYUserDefault isShowVipMemberInfo\]' "$TARGET"

# M-005: RetailStore Choose Store Target
assert_match "M-005" 'setChooseStoreTargetWithCompletion' "$TARGET"

# M-005b: Clear after completion
assert_match "M-005b" 'clearChooseStoreTarget' "$TARGET"

# M-006: SSO Token Extraction
assert_match "M-006" 'analyzeSSOAuthWithUrl:notif.url' "$TARGET"

# M-006b: Token read
assert_match "M-006b" 'thirdPartySsoToken' "$TARGET"

# M-007: AppSettings thirdpartyBasedAuth Update
assert_match "M-007" 'thirdpartyBasedAuth = isThirdpartyBasedAuthEnabled' "$TARGET"

# M-008: SSO Record Notification Object
assert_match "M-008" 'recordNotificationObjectIfNeeded:notif' "$TARGET"

# M-009: SSO Record Target URL
assert_match "M-009" 'recordTargetUrlIfNeeded' "$TARGET"

# M-010: Crashlytics URL Recording
assert_match "M-010" 'recordWithUnexpectedURL:customField' "$TARGET"

echo ""

# ============================================================
# Category L -- Lifecycle / State Machine Contracts
# ============================================================
echo "--- Category L: Lifecycle Contracts ---"

# L-001: Push Before Tab Select (ordering verified by manual review)
# Verify both operations exist in NYNotificationPushHelper
assert_match "L-001a" 'pushViewController:viewController animated' "$TARGET"
assert_match "L-001b" 'selectTabBarItemAt:index' "$TARGET"

# L-002: Pop to Root on Current Tab
assert_match "L-002" 'popToRootViewControllerAnimated:YES' "$TARGET"

# L-003: Cross-Shop TargetType Override
assert_match "L-003" 'isEqualToNumber:notif.shopID' "$TARGET"

# L-004: External Link Short-Circuit
assert_match "L-004" 'isExternalLink' "$TARGET"

# L-005: FullURL Recursive Routing
assert_match "L-005" 'redirectViaWrappedURLWithNotificationObj:notif completion:completion' "$TARGET"

# L-005b: Recursive call in unwrap
assert_match "L-005b" 'processNotificationAction:notifObj withCompletionBlock:completion' "$TARGET"

# L-006: Post-Routing Dispatch -- ShopHome branch
assert_match "L-006a" 'RoutingTargetTypeShopHome' "$TARGET"

# L-006b: SchemeRedirect branch
assert_match "L-006b" 'processSchemeRedirectWithNotificationObj:notif' "$TARGET"

# L-007: Login Gate -- needLoginPage check
assert_match "L-007" 'needLoginPage' "$TARGET"

# L-007b: thirdpartyBasedAuth NoData check
assert_match "L-007b" 'NYThirdpartyBasedAuthNoData' "$TARGET"

# L-007c: Login VC presentation in gate
assert_match "L-007c" 'presentLoginVCShouldShowUnLoginMask:NO' "$TARGET"

# L-008: OAuth SSO Type Switch
assert_match "L-008a" 'NYSSOTypeUrl' "$TARGET"
assert_match "L-008b" 'NYSSOTypeNotificationObject' "$TARGET"
assert_match "L-008c" 'NYSSOTypeNotSpecified' "$TARGET"

# L-009: Dismiss Before Present (Left Menu)
assert_match "L-009" 'NYLeftMenuV2ViewController' "$TARGET"

# L-010: DesignCloudNative Fallback
assert_match "L-010" 'DesignCloudBridge getViewControllerWithPath' "$TARGET"

echo ""

# ============================================================
# Category N -- Notification Contracts
# ============================================================
echo "--- Category N: Notification Contracts ---"

# N-001: NYChatRoomDidOpen
assert_match "N-001" 'postNotificationName:@"NYChatRoomDidOpen"' "$TARGET"

# N-003: NYNotificationHelperDelegate
if [ -f "$HEADER" ]; then
    assert_match "N-003" 'NYNotificationHelperDelegate' "$HEADER"
else
    echo "SKIP [N-003] -- Header file not found: $HEADER"
fi

echo ""

# ============================================================
# Category S -- Synchronization Contracts
# ============================================================
echo "--- Category S: Synchronization Contracts ---"

# S-001: dispatch_once Singleton
assert_match "S-001" 'dispatch_once(&onceToken' "$TARGET"

# S-002: Weak Global NavController
assert_match "S-002" '__weak static UINavigationController \*globalActiveNavigationController' "$TARGET"

echo ""

# ============================================================
# Category E -- Error Handling Contracts
# ============================================================
echo "--- Category E: Error Handling Contracts ---"

# E-003: Nil URL Return for PXPartialPickupPush
assert_match "E-003" 'redirectToPXPartialPickupPushWithNotificationObj' "$TARGET"

echo ""

# ============================================================
# Category D -- Dependency Contracts
# ============================================================
echo "--- Category D: Dependency Contracts ---"

# D-001: globalActiveNavigationController (existence)
assert_match "D-001" 'globalActiveNavigationController' "$TARGET"

# D-002: NYGlobalData shopId
assert_match "D-002" '\[NYGlobalData shopId\]' "$TARGET"

# D-003: NYLoginHelper sharedInstance
assert_match "D-003" '\[NYLoginHelper sharedInstance\]' "$TARGET"

# D-004: NYAppSettingsHelper sharedInstance
assert_match "D-004" '\[NYAppSettingsHelper sharedInstance\]' "$TARGET"

# D-005: NYCookieManager sharedManager
assert_match "D-005" '\[NYCookieManager sharedManager\]' "$TARGET"

# D-006: NYStatisticHelper sharedHelper
assert_match "D-006" '\[NYStatisticHelper sharedHelper\]' "$TARGET"

# D-007: NYThirdPartySSOHelper shared
assert_match "D-007" '\[NYThirdPartySSOHelper shared\]' "$TARGET"

# D-008: NYDataProvider sharedInstance
assert_match "D-008" '\[NYDataProvider sharedInstance\]' "$TARGET"

# D-009: NYUserDefault
assert_match "D-009" 'NYUserDefault' "$TARGET"

# D-010: NYMemberBarcodePresenterV2 shared
assert_match "D-010" '\[NYMemberBarcodePresenterV2 shared\]' "$TARGET"

# D-011: NYMemberHelper shareInstance
assert_match "D-011" 'NYMemberHelper.shareInstance' "$TARGET"

# D-012: NYAddToCartHelper sharedInstance
assert_match "D-012" '\[NYAddToCartHelper sharedInstance\]' "$TARGET"

# D-013: RetailStoreService
assert_match "D-013" '\[RetailStoreService isFeatureEnable\]' "$TARGET"

# D-014: NYBaseURLConfig
assert_match "D-014" 'NYBaseURLConfig baseHTTPSURLWithAppServiceWebPageDomain' "$TARGET"

# D-015: NYUrlHelper
assert_match "D-015" 'NYUrlHelper' "$TARGET"

# D-016: MenuRedDotManager
assert_match "D-016" 'MenuRedDotManager.shared' "$TARGET"

# D-017: NYZendeskHelper
assert_match "D-017" 'NYZendeskHelper.shared' "$TARGET"

# D-018: NYCountryConfig
assert_match "D-018" 'NYCountryConfig productScanTypeIn' "$TARGET"

# D-019: NYGlobalData country
assert_match "D-019" '\[NYGlobalData' "$TARGET"

# D-020: CMSPresentVCHelper
assert_match "D-020" 'CMSPresentVCHelper shouldChooseStoreFirstWithType' "$TARGET"

# D-021: DesignCloudBridge
assert_match "D-021" 'DesignCloudBridge' "$TARGET"

echo ""

# ============================================================
# Category P -- Propagation Contracts
# ============================================================
echo "--- Category P: Propagation Contracts ---"

# P-002: Recursive URL Unwrapping (unwrapFullURLWith calls processNotificationAction)
assert_match "P-002a" 'unwrapFullURLWith' "$TARGET"
assert_match "P-002b" 'unwrapTargetURLWith' "$TARGET"

# P-005: Scheme URL Construction
assert_match "P-005" 'containsString:@"schemeRedirect"' "$TARGET"

echo ""

# ============================================================
# Results
# ============================================================
echo "==========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "==========================================="

if [ $FAIL -eq 0 ]; then
    echo "All contracts verified."
    exit 0
else
    echo "WARNING: $FAIL contract(s) may have been removed or modified."
    echo "Review each FAIL line above and verify the contract is preserved."
    exit 1
fi
