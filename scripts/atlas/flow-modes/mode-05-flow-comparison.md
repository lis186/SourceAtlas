# Mode 5: Flow Comparison (Diff)

> Tier 3 | Trigger: "compare", "diff", "vs", "difference", "different", "contrast"

## Purpose

Compare two flows side by side to highlight differences, useful for understanding variations between user types, versions, or feature flags.

## Use Cases

- Compare VIP vs Regular user flows
- Compare old vs new implementation
- Compare feature flag ON vs OFF
- Compare different payment methods
- Compare web vs mobile flows

## Analysis Steps

### Step 1: Identify Both Flows

Parse user input to identify:
- Flow A (baseline)
- Flow B (comparison target)

### Step 2: Trace Both Flows

Execute standard flow tracing for both paths.

### Step 3: Align and Compare

- Find common steps
- Identify divergence points
- Highlight additions/removals/changes

## Output Format

```
{Flow A} vs {Flow B}
====================

Legend: [=] Same  [+] Added  [-] Removed  [~] Changed

───────────────────────────────────

Common Steps:
├── 1. {Step 1} - identical in both
├── 2. {Step 2} - identical in both
└── 6. {Step 6} - identical in both

───────────────────────────────────

Differences:
┌─────────────────────────────────────────────────┐
│ Step 3: {Step Name}                             │
├────────────────────┬────────────────────────────┤
│ {Flow A}           │ {Flow B}                   │
├────────────────────┼────────────────────────────┤
│ {A implementation} │ {B implementation}         │
│ 📍 {file}:{line}   │ 📍 {file}:{line}           │
│                    │ [+] Additional step        │
└────────────────────┴────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ Step 4: {Step Name}                             │
├────────────────────┬────────────────────────────┤
│ {Flow A}           │ {Flow B}                   │
├────────────────────┼────────────────────────────┤
│ {A implementation} │ [-] Not present            │
└────────────────────┴────────────────────────────┘

───────────────────────────────────

Summary:
├── Common steps: N
├── Different steps: M
├── A-only steps: X
├── B-only steps: Y
└── Code overlap: Z%

⚠️ Notable Differences:
├── {Important difference 1}
├── {Important difference 2}
└── {Risk or consideration}
───────────────────────────────────
```

## Comparison Types

### 1. User Type Comparison
```
/atlas.flow "compare VIP order vs regular order"
```

### 2. Version Comparison
```
/atlas.flow "compare old login vs new login"
```

### 3. Feature Flag Comparison
```
/atlas.flow "compare payment with NEW_FLOW=ON vs OFF"
```

### 4. Platform Comparison
```
/atlas.flow "compare web checkout vs mobile checkout"
```

## Output Example

```
VIP Order vs Regular Order (Differences)
========================================

Legend: [=] Same  [+] Added  [-] Removed  [~] Changed

───────────────────────────────────

Common Steps:
├── 1. CartService.validate()
├── 2. InventoryService.check()
├── 5. PaymentService.process()
└── 6. OrderService.create()

───────────────────────────────────

Differences:

┌─────────────────────────────────────────────────┐
│ Step 3: Discount Calculation                    │
├────────────────────┬────────────────────────────┤
│ Regular            │ VIP                        │
├────────────────────┼────────────────────────────┤
│ CouponService      │ VIPDiscount.calculate()    │
│ 📍 discount.ts:45  │ 📍 vip-discount.ts:30      │
│                    │ [+] Priority discount      │
│ PointsService      │ PointsService (2x rate)    │
│ 📍 points.ts:80    │ 📍 points.ts:95            │
│                    │ [~] Double points rate     │
└────────────────────┴────────────────────────────┘

┌─────────────────────────────────────────────────┐
│ Step 4: Shipping                                │
├────────────────────┬────────────────────────────┤
│ Regular            │ VIP                        │
├────────────────────┼────────────────────────────┤
│ Standard shipping  │ Free express shipping      │
│ 📍 shipping.ts:60  │ 📍 vip-shipping.ts:25      │
│ Fee: calculated    │ Fee: $0 (waived)           │
└────────────────────┴────────────────────────────┘

───────────────────────────────────

Summary:
├── Common steps: 4
├── Different steps: 2
├── Regular-only: 0
├── VIP-only: 1 (priority discount)
└── Code overlap: 75%

⚠️ Notable Differences:
├── VIP gets priority discount before coupons
├── VIP points earn at 2x rate
├── VIP shipping is always free express
└── 📌 VIP logic scattered across 3 services
    Consider consolidating to VIPBenefitsService

💡 Recommendation:
Consider extracting VIP-specific logic into a
dedicated service for easier maintenance
───────────────────────────────────
```

## Trigger Keywords

Primary: `compare`, `vs`, `difference between`
Secondary: `diff`, `contrast`, `what's different`, `how does X differ from Y`
