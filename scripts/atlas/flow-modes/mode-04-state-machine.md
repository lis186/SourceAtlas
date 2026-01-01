# Mode 4: State Machine Visualization

> Tier 2 | Trigger: "state machine", "state", "status", "status change", "lifecycle", "transitions"

## Purpose

Visualize state transitions in entities like Order, Payment, User status, etc.

## Analysis Steps

### Step 1: Find State Definitions

```bash
# Enum/const definitions
grep -rn "enum.*Status\|enum.*State\|type.*Status" src/
grep -rn "STATUS\|STATE\|LIFECYCLE" --include="*.ts" src/

# Database status columns
grep -rn "status.*varchar\|state.*enum" migrations/
```

### Step 2: Find Transition Logic

```bash
# State changes
grep -rn "status =\|state =\|setState\|setStatus" src/
grep -rn "transition\|moveTo\|changeStatus" src/
```

## Output Format

```
{Entity} State Machine
======================

States:
┌──────────┐   ┌───────────┐   ┌────────┐
│ PENDING  │──→│ CONFIRMED │──→│  PAID  │
└──────────┘   └───────────┘   └────────┘
     │              │               │
     │ cancel       │ cancel        │ ship
     ↓              ↓               ↓
┌───────────┐  ┌───────────┐   ┌─────────┐
│ CANCELLED │  │ CANCELLED │   │ SHIPPED │
└───────────┘  └───────────┘   └─────────┘
                                    │
                                    │ deliver
                                    ↓
                               ┌───────────┐
                               │ DELIVERED │
                               └───────────┘

───────────────────────────────────

State Definitions:
📍 {file}:{line}

Transitions:
| From | To | Trigger | Location |
|------|----|---------|---------:|
| PENDING | CONFIRMED | confirm() | order.ts:45 |
| CONFIRMED | PAID | payment.complete() | payment.ts:120 |
| PAID | SHIPPED | ship() | shipping.ts:80 |
| * | CANCELLED | cancel() | order.ts:200 |

───────────────────────────────────

Validation Rules:
├── CANCELLED is terminal (no outgoing transitions)
├── DELIVERED can only transition to REFUNDING
└── Only PENDING and CONFIRMED can be cancelled

⚠️ Issues Found:
├── No transition from SHIPPED to CANCELLED
└── Missing validation in bulkUpdate()
```

## State Detection Patterns

### TypeScript/JavaScript
```typescript
// Enum definition
enum OrderStatus {
  PENDING = 'pending',
  CONFIRMED = 'confirmed',
  PAID = 'paid',
}

// State transition
order.status = OrderStatus.CONFIRMED;
this.setState({ status: 'active' });
```

### Python
```python
# Enum definition
class OrderStatus(Enum):
    PENDING = 'pending'
    CONFIRMED = 'confirmed'

# State transition
order.status = OrderStatus.CONFIRMED
```

### Swift
```swift
// Enum definition
enum OrderStatus: String {
    case pending, confirmed, paid
}

// State transition
order.status = .confirmed
```

## Output Example

```
Order State Machine
===================

┌──────────┐
│ PENDING  │
└────┬─────┘
     │ confirm()
     ↓
┌───────────┐   cancel()   ┌───────────┐
│ CONFIRMED │─────────────→│ CANCELLED │
└─────┬─────┘              └───────────┘
      │ pay()
      ↓
┌──────────┐
│   PAID   │
└────┬─────┘
     │ ship()
     ↓
┌──────────┐
│ SHIPPED  │
└────┬─────┘
     │ deliver()
     ↓
┌───────────┐
│ DELIVERED │
└───────────┘

State definitions: 📍 src/models/order.ts:15-25

Transition logic:
• PENDING → CONFIRMED: OrderService.confirm()  📍 :45
• CONFIRMED → PAID: PaymentService.complete()  📍 :120
• PAID → SHIPPED: ShippingService.ship()       📍 :80
• SHIPPED → DELIVERED: DeliveryService.complete() 📍 :95
• PENDING/CONFIRMED → CANCELLED: OrderService.cancel() 📍 :200

⚠️ Note: PAID orders cannot be cancelled (requires refund flow)
```

## Trigger Keywords

Primary: `state machine`, `status transitions`, `lifecycle`
Secondary: `state`, `status`, `how does X change`, `state diagram`
