# Mode 9: Transaction Boundary Analysis

> Tier 2 | Trigger: "transaction", "rollback", "commit", "atomicity", "consistency"

## Purpose

Identify transaction boundaries in the code to understand atomicity, consistency, and potential data integrity issues.

## Analysis Steps

### Step 1: Find Transaction Patterns

```bash
# ORM/Framework transactions
grep -rn "@Transactional\|@transaction" src/
grep -rn "BEGIN\|COMMIT\|ROLLBACK" src/
grep -rn "withTransaction\|startTransaction\|beginTransaction" src/

# Specific ORMs
grep -rn "prisma\.\$transaction" src/
grep -rn "sequelize\.transaction" src/
grep -rn "typeorm.*transaction\|getManager" src/
grep -rn "mongoose.*session\|startSession" src/

# iOS Core Data
grep -rn "NSManagedObjectContext\|performAndWait\|perform\(" Sources/
```

### Step 2: Identify Transaction Scope

For each transaction:
- Where does it start?
- What operations are included?
- Where does it end?
- What's the isolation level?

## Output Format

```
{Flow} Transaction Analysis
===========================

┌─ Transaction 1 ({type}) ────────────────────┐
│                                              │
│ 1. {Operation 1}                             │
│    📍 {file}:{line}                          │
│    💾 {SQL/operation description}            │
│                                              │
│ 2. {Operation 2}                             │
│    📍 {file}:{line}                          │
│    💾 {SQL/operation description}            │
│                                              │
└──────────────────────────────────────────────┘
   📍 Start: {file}:{line}
   📍 End: {file}:{line}
   🔒 Isolation: {level}

[No Transaction Zone]
3. {External Operation}
   📍 {file}:{line}
   🌐 {External API / Cannot rollback}
   ⚠️ Risk: {description}

┌─ Transaction 2 ─────────────────────────────┐
│ ...                                          │
└──────────────────────────────────────────────┘

───────────────────────────────────
⚠️ Risk Analysis:

📌 Gap Between Transactions:
   • {Description of gap risk}
   • Impact: {What could go wrong}
   • Fix: {Recommended solution}

📌 External Calls in Transaction:
   • {External call that could fail}
   • Impact: {Transaction timeout / lock holding}
   • Fix: {Move outside transaction}

📌 Missing Rollback:
   • {Operation without proper rollback}
   • Fix: {Add compensation logic}
───────────────────────────────────
```

## Transaction Patterns

### Prisma (TypeScript)
```typescript
await prisma.$transaction(async (tx) => {
  await tx.order.create({ ... });
  await tx.inventory.update({ ... });
});
```

### TypeORM
```typescript
await getManager().transaction(async (em) => {
  await em.save(order);
  await em.update(Inventory, ...);
});
```

### Sequelize
```typescript
await sequelize.transaction(async (t) => {
  await Order.create({ ... }, { transaction: t });
});
```

### Python SQLAlchemy
```python
with session.begin():
    session.add(order)
    session.query(Inventory).update(...)
```

### Spring @Transactional
```java
@Transactional
public void createOrder() {
    orderRepo.save(order);
    inventoryRepo.update(...);
}
```

## Output Example

```
Checkout Flow Transaction Analysis
===================================

┌─ Transaction 1 (@Transactional) ────────────┐
│                                              │
│ 1. CartService.validate()                    │
│    📍 src/services/cart.ts:45                │
│    💾 SELECT FROM cart_items                 │
│                                              │
│ 2. InventoryService.reserve()                │
│    📍 src/services/inventory.ts:156          │
│    💾 UPDATE inventory SET reserved = ...    │
│                                              │
│ 3. OrderService.create()                     │
│    📍 src/services/order.ts:200              │
│    💾 INSERT INTO orders ...                 │
│                                              │
└──────────────────────────────────────────────┘
   📍 Transaction Start: checkout.ts:120
   📍 Transaction End: checkout.ts:180
   🔒 Isolation: READ_COMMITTED

[No Transaction - External Call]
4. PaymentService.process()
   📍 src/services/payment.ts:200
   🌐 External API call (Stripe)
   ⚠️ Cannot rollback if fails after Transaction 1

┌─ Transaction 2 ─────────────────────────────┐
│                                              │
│ 5. OrderService.confirm()                    │
│    📍 src/services/order.ts:250              │
│    💾 UPDATE orders SET status = 'PAID'      │
│                                              │
│ 6. InventoryService.deduct()                 │
│    📍 src/services/inventory.ts:200          │
│    💾 UPDATE inventory SET quantity = ...    │
│                                              │
└──────────────────────────────────────────────┘

───────────────────────────────────
⚠️ Risk Analysis:

📌 Gap Risk: Between Transaction 1 and 2
   • If payment fails, inventory is reserved but not released
   • Impact: Phantom reserved inventory
   • Fix: Add compensation logic or use Saga pattern

📌 External Call Timing:
   • Payment call is outside transaction (correct)
   • But no timeout configured
   • Fix: Add 30s timeout, implement retry logic

📌 Recommendation:
   • Consider Saga pattern for distributed transaction
   • Add OrderService.compensate() for failure cases
───────────────────────────────────
```

## Trigger Keywords

Primary: `transaction`, `transaction boundary`, `atomicity`
Secondary: `rollback`, `commit`, `ACID`, `isolation`, `consistency`
