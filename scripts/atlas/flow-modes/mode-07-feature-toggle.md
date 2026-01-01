# Mode 7: Feature Toggle Analysis

> Tier 3 | Trigger: "feature toggle", "feature flag", "switch", "toggle", "flag", "rollout", "A/B"

## Purpose

Analyze how feature flags affect code paths, helping understand flow variations and plan rollouts.

## Analysis Steps

### Step 1: Find Feature Flag Patterns

```bash
# Common feature flag patterns
grep -rn "featureFlag\|feature_flag\|isEnabled\|isFeatureEnabled" src/
grep -rn "LaunchDarkly\|Unleash\|Split\|ConfigCat" src/
grep -rn "process\.env\.\|getConfig\|remoteConfig" src/

# Platform-specific
grep -rn "@available\|#available\|canImport" Sources/  # iOS
grep -rn "BuildConfig\.\|isDebug\|isBeta" src/  # Android
```

### Step 2: Map Toggles to Flow

For each toggle found:
- Where is it checked?
- What code paths are affected?
- What's the ON behavior vs OFF behavior?

## Output Format

### Toggle Discovery
```
{Flow} Feature Toggles
======================

Found N feature toggles affecting this flow:

┌───────────────────────────────────────────────────────────┐
│ Toggle              │ Affected Step    │ Current State    │
├─────────────────────┼──────────────────┼──────────────────┤
│ NEW_PAYMENT_FLOW    │ Step 5 Payment   │ 🟡 50% rollout   │
│ ENABLE_POINTS       │ Step 3 Discount  │ 🟢 ON (100%)     │
│ USE_NEW_INVENTORY   │ Step 4 Inventory │ 🔴 OFF           │
│ BETA_CHECKOUT_UI    │ Step 1 Frontend  │ 🟡 Beta users    │
└───────────────────────────────────────────────────────────┘

📍 Toggle Definitions:
├── src/config/featureFlags.ts:15
└── src/services/flagService.ts:30
```

### Toggle Impact
```
{Flow} (TOGGLE_NAME = ON)
=========================

1-4. [Previous steps unchanged...]

5. PaymentService.process()
   📍 src/services/payment.ts:200

   🚩 TOGGLE_NAME = ON:
   ┌─────────────────────────────────────────────┐
   │ New Flow                                    │
   ├─────────────────────────────────────────────┤
   │ 5a. PaymentV2.init()                        │
   │     📍 src/services/payment-v2.ts:45        │
   │                                             │
   │ 5b. PaymentV2.process()                     │
   │     📍 src/services/payment-v2.ts:80        │
   │     📌 Faster: ~300ms (vs ~800ms)           │
   │                                             │
   │ 5c. PaymentV2.confirm()                     │
   │     📍 src/services/payment-v2.ts:120       │
   │     📌 New: 3D Secure support               │
   └─────────────────────────────────────────────┘

   🚩 TOGGLE_NAME = OFF:
   ┌─────────────────────────────────────────────┐
   │ Legacy Flow                                 │
   ├─────────────────────────────────────────────┤
   │ 5a. PaymentGateway.charge()                 │
   │     📍 src/services/payment-legacy.ts:200   │
   └─────────────────────────────────────────────┘

6. [Subsequent steps...]

───────────────────────────────────
📊 Toggle Impact Analysis:
├── Change Scope: 1 step
├── New Files: payment-v2.ts (320 lines)
├── Performance: -40% latency
└── Risk: 3D Secure needs testing
───────────────────────────────────
```

### Toggle Combination Matrix
```
Toggle Combination Matrix
=========================

┌──────────────────────┬─────────────┬─────────────┬─────────────┐
│ Combination          │ Payment     │ Inventory   │ Performance │
├──────────────────────┼─────────────┼─────────────┼─────────────┤
│ All OFF (safe)       │ Legacy      │ Legacy      │ ~3s         │
│ All ON (target)      │ V2 + 3DS    │ New API     │ ~1.2s       │
│ Current Production   │ 50/50       │ Legacy      │ ~2.1s avg   │
│ Recommended Staging  │ V2 + 3DS    │ Legacy      │ ~1.8s       │
└──────────────────────┴─────────────┴─────────────┴─────────────┘

⚠️ Risk Warnings:
├── NEW_PAYMENT + NEW_INVENTORY untested together
└── BETA_UI only tested on iOS
```

## Feature Flag Lifecycle

| State | Meaning | Action |
|-------|---------|--------|
| 🔴 OFF | Not enabled | Ready for testing |
| 🟡 Partial | % rollout or segment | Monitor metrics |
| 🟢 ON | 100% enabled | Consider removing flag |
| ⚫ Stale | 100% for >30 days | Remove flag (tech debt) |

## Stale Flag Detection

```
⚠️ Stale Toggles (candidates for removal):

1. ENABLE_DARK_MODE
   📍 src/config/flags.ts:45
   Status: 🟢 ON (100%) since 2024-01-15 (180+ days)
   💡 Can be removed, dark mode is now default

2. OLD_CHECKOUT_FALLBACK
   📍 src/config/flags.ts:52
   Status: 🔴 OFF since 2023-11-01 (400+ days)
   💡 Dead code, safe to remove
```

## Output Example

```
Checkout Flow Feature Toggles
=============================

Found 4 feature toggles affecting this flow:

┌───────────────────────────────────────────────────────────┐
│ Toggle                  │ Affected Step   │ Current State │
├─────────────────────────┼─────────────────┼───────────────┤
│ NEW_PAYMENT_FLOW        │ Step 5 Payment  │ 🟡 50% rollout│
│ ENABLE_POINTS_REDEMPTION│ Step 3 Discount │ 🟢 ON         │
│ USE_NEW_INVENTORY_API   │ Step 4 Inventory│ 🔴 OFF        │
│ BETA_CHECKOUT_UI        │ Step 1 Frontend │ 🟡 Beta users │
└───────────────────────────────────────────────────────────┘

📍 Toggle Definitions:
├── src/config/featureFlags.ts:15
└── src/services/launchDarkly.ts:30

⚠️ Stale Toggle Alert:
└── ENABLE_POINTS_REDEMPTION: ON for 90+ days
    Consider removing flag and making permanent

💬 Next Steps:
├── "flow with NEW_PAYMENT_FLOW = ON"
├── "compare old vs new payment flow"
└── "flow with all toggles enabled"
```

## Trigger Keywords

Primary: `feature toggle`, `feature flag`, `flag analysis`
Secondary: `toggle`, `switch`, `rollout`, `A/B test`, `gradual rollout`
