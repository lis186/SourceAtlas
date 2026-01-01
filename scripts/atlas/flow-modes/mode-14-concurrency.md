# Mode 14: Concurrency Flow Analysis

> Tier 3 | Trigger: "async", "await", "promise", "thread", "concurrent", "race condition", "parallel", "lock", "mutex"

## Purpose

Analyze asynchronous and concurrent code flows, identifying execution order, potential race conditions, and synchronization issues.

## Concurrency Patterns

| Pattern | Description | Languages |
|---------|-------------|-----------|
| **Async/Await** | Promise-based async | JS/TS, Python, C#, Swift |
| **Promises/Futures** | Deferred execution | JS/TS, Java, Rust |
| **Threads** | OS-level parallelism | Java, Python, C++ |
| **Actors** | Message-passing concurrency | Swift, Erlang, Akka |
| **Channels** | Go-style communication | Go, Rust |
| **Coroutines** | Lightweight concurrency | Kotlin, Python |

## Analysis Steps

### Step 1: Identify Async Entry Points

```bash
# JavaScript/TypeScript
grep -rn "async function\|async (" --include="*.ts" --include="*.js" src/

# Python
grep -rn "async def" --include="*.py" src/

# Swift
grep -rn "func.*async" --include="*.swift" Sources/
```

### Step 2: Find Parallel Operations

```bash
# Promise.all / Promise.allSettled
grep -rn "Promise\.all\|Promise\.allSettled\|Promise\.race" src/

# Python asyncio
grep -rn "asyncio\.gather\|asyncio\.wait" src/

# Go goroutines
grep -rn "go func\|go \w" src/
```

### Step 3: Identify Shared State

```bash
# Class/module level variables modified in async
grep -rn "this\.\w\+ =\|self\.\w\+ =" src/
```

### Step 4: Find Synchronization Primitives

```bash
# Locks, mutexes, semaphores
grep -rn "Lock\|Mutex\|Semaphore\|synchronized" src/
```

## Output Format

```
Concurrency Flow Analysis: {Description}
========================================

Execution Model: {Async/Await | Multi-threaded | Actor-based}
Entry Point: {file}:{line}

───────────────────────────────────

## Async Execution Flow

{caller}()
    │
    ├─── await ──→ {async1}()      [~Nms]
    │                 │
    │                 └─→ completes
    │
    └─── continues after await

## Parallel Execution

{parallelCaller}()
    │
    ├──┬── {task1}() ────────┐
    │  │                     │
    │  ├── {task2}() ────────┼── await all ──→ continue
    │  │                     │
    │  └── {task3}() ────────┘
    │
    └─→ all tasks complete, then continue

───────────────────────────────────

## Potential Issues

### 1. Race Condition Risk
📍 {file}:{line}
```{language}
// Read
const balance = await getBalance(userId);
// ⚠️ GAP: Another request could modify balance here
// Write
await setBalance(userId, balance - amount);
```

**Problem**: Non-atomic read-modify-write
**Impact**: {Data corruption | Lost updates | Inconsistent state}
**Fix**: {Use transaction | Optimistic locking | Atomic operation}

### 2. Missing Error Handling in Parallel
📍 {file}:{line}
```{language}
await Promise.all([
  chargePayment(),    // If this fails...
  updateInventory(),  // ...this may have already run
  sendEmail()
]);
```

**Problem**: Partial completion on failure
**Impact**: Inconsistent state
**Fix**: Use Promise.allSettled + rollback, or sequential with cleanup

### 3. Potential Deadlock
📍 {file}:{line}
```{language}
// Thread A                    // Thread B
lock(resourceA);               lock(resourceB);
lock(resourceB);  // waits     lock(resourceA);  // waits
```

**Problem**: Circular lock dependency
**Fix**: Establish consistent lock ordering

───────────────────────────────────

## Shared State Analysis

| Variable | Location | Accessed By | Risk |
|----------|----------|-------------|------|
| {var1} | {file}:{line} | {func1}, {func2} | 🟡 Medium |
| {var2} | {file}:{line} | {func3}, {func4} | 🔴 High |

───────────────────────────────────

## Timing Diagram

```
Time ──────────────────────────────────────────→

Task A: ████████████░░░░░░░░░████████
Task B: ░░░░████████████████░░░░░░░░░
Task C: ░░░░░░░░████████░░░░░░░░░░░░░
                    ↑
              Shared access (potential race)
```

───────────────────────────────────

Summary:
├── Async operations: N
├── Parallel blocks: N
├── Shared state access: N locations
├── Race condition risks: N
├── Missing error handling: N
└── Overall safety: {Safe | Needs Review | Risky}
```

## Common Issues

### 1. Race Condition (Read-Modify-Write)

```typescript
// UNSAFE
async function withdraw(userId: string, amount: number) {
  const balance = await db.getBalance(userId);  // Read
  if (balance >= amount) {
    await db.setBalance(userId, balance - amount);  // Write
  }
}

// SAFE
async function withdraw(userId: string, amount: number) {
  await db.transaction(async (tx) => {
    const balance = await tx.getBalance(userId, { forUpdate: true });
    if (balance >= amount) {
      await tx.setBalance(userId, balance - amount);
    }
  });
}
```

### 2. Promise.all Partial Failure

```typescript
// UNSAFE
await Promise.all([
  chargePayment(order),      // Succeeds
  reserveInventory(order),   // Fails!
  sendConfirmation(order)    // Already sent!
]);

// SAFER
const results = await Promise.allSettled([...]);
if (results.some(r => r.status === 'rejected')) {
  await rollback(results);
}
```

### 3. Async in Loop (Sequential vs Parallel)

```typescript
// SEQUENTIAL (slow)
for (const item of items) {
  await processItem(item);
}

// PARALLEL (fast, but watch for rate limits)
await Promise.all(items.map(item => processItem(item)));

// CONTROLLED PARALLELISM
import pLimit from 'p-limit';
const limit = pLimit(5);
await Promise.all(items.map(item => limit(() => processItem(item))));
```

### 4. Forgotten Await

```typescript
// BUG: Missing await
async function process() {
  saveToDatabase(data);  // Fire and forget! May fail silently
  return "done";
}

// CORRECT
async function process() {
  await saveToDatabase(data);
  return "done";
}
```

## Language-Specific Patterns

### TypeScript/JavaScript
```typescript
// Async patterns
async/await
Promise.all([...])
Promise.allSettled([...])
Promise.race([...])

// Issues to detect
- Missing await
- Unhandled promise rejection
- Promise.all partial failure
```

### Python
```python
# Async patterns
async def / await
asyncio.gather(*tasks)
asyncio.wait(tasks)
asyncio.create_task()

# Threading
threading.Lock()
threading.Thread()
concurrent.futures.ThreadPoolExecutor()

# Issues to detect
- GIL limitations
- Missing await
- Shared state in threads
```

### Swift
```swift
// Async patterns
async/await
Task { }
TaskGroup
actor

// Issues to detect
- Actor reentrancy
- MainActor requirements
- Sendable conformance
```

### Go
```go
// Concurrency patterns
go func() { }
channel <- value
<-channel
sync.Mutex

// Issues to detect
- Goroutine leaks
- Channel deadlock
- Race conditions (use -race flag)
```

## Output Example

```
Concurrency Flow Analysis: Payment Processing
=============================================

Execution Model: Async/Await (TypeScript)
Entry Point: src/services/payment.ts:45

───────────────────────────────────

## Async Execution Flow

processPayment()
    │
    ├─── await ──→ validateCard()     [~100ms]
    │
    ├─── await ──→ chargeCard()       [~500ms]
    │
    └─── await ──→ updateOrder()      [~50ms]

Total sequential time: ~650ms

## Parallel Execution

sendNotifications()
    │
    ├──┬── sendEmail() ──────────┐
    │  │                         │
    │  ├── sendSMS() ────────────┼── await all
    │  │                         │
    │  └── sendPush() ───────────┘
    │
    └─→ continue (no return value needed)

───────────────────────────────────

## Potential Issues

### 1. Race Condition Risk
📍 src/services/inventory.ts:78
```typescript
async function decrementStock(itemId: string, qty: number) {
  const current = await db.getStock(itemId);
  // ⚠️ GAP: High-traffic items vulnerable
  await db.setStock(itemId, current - qty);
}
```

**Problem**: Non-atomic read-modify-write
**Impact**: Overselling inventory
**Fix**:
```typescript
await db.query('UPDATE stock SET qty = qty - ? WHERE id = ?', [qty, itemId])
```

### 2. Missing Error Handling in Parallel
📍 src/services/order.ts:120
```typescript
await Promise.all([
  chargePayment(order),
  updateInventory(order),  // If this fails after payment...
  createShipment(order)
]);
```

**Problem**: No rollback if middle operation fails
**Fix**: Implement saga pattern or use Promise.allSettled

───────────────────────────────────

Summary:
├── Async operations: 12
├── Parallel blocks: 3
├── Shared state access: 4 locations
├── Race condition risks: 2 (High priority)
├── Missing error handling: 1
└── Overall safety: ⚠️ Needs Review
```

## Trigger Keywords

Primary: `async flow`, `concurrent`, `parallel execution`
Secondary: `race condition`, `thread safety`, `await`, `Promise.all`, `deadlock`, `mutex`, `lock`
