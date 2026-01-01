# Mode 6: Log-Based Flow Discovery

> Tier 2 | Trigger: "log", "logging", "from logs", "debug", "trace logs"

## Purpose

Reconstruct execution flow by analyzing log statements in the codebase, useful for understanding what information is available during debugging.

## Analysis Steps

### Step 1: Find Log Statements

```bash
# JavaScript/TypeScript
grep -rn "console\.log\|console\.info\|console\.error\|console\.warn" src/
grep -rn "logger\.\|log\.\|logging\." src/

# Python
grep -rn "logging\.\|logger\.\|print(" src/

# Swift/iOS
grep -rn "print\|NSLog\|os_log\|Logger" Sources/

# Kotlin/Android
grep -rn "Log\.\|Timber\.\|println" src/
```

### Step 2: Extract Log Context

For each log statement, identify:
- Log level (INFO, DEBUG, ERROR, WARN)
- Message content
- Variables being logged
- Function/method context

## Output Format

```
{Flow Name} (Reconstructed from Logs)
=====================================

Found N log points, reconstructed flow:

1. [{LEVEL}] "{message}"
   📍 {file}:{line}
   → {function/method}()
   📌 {notes about logged data}

2. [{LEVEL}] "{message}"
   📍 {file}:{line}
   → {function/method}()

3. [{LEVEL}] "{message}"
   📍 {file}:{line}
   → {function/method}()
   ⚠️ {security/privacy concern if any}

───────────────────────────────────
📊 Log Coverage Analysis:
├── Steps with logs: N/M
├── Missing logs in critical steps: [list]
└── Log level distribution: INFO(x), DEBUG(y), ERROR(z)

⚠️ Data Sensitivity Issues:
├── PII logged at line X
├── Credentials risk at line Y
└── PCI-DSS violation at line Z

💡 Recommendations:
├── Add logs for: [missing steps]
├── Remove/mask: [sensitive data]
└── Add correlation IDs for distributed tracing
───────────────────────────────────
```

## Log Level Guidelines

| Level | Use Case | Example |
|-------|----------|---------|
| **ERROR** | Failures requiring attention | Payment failed, DB connection lost |
| **WARN** | Potential issues | Retry attempt, deprecated API |
| **INFO** | Key business events | Order created, user logged in |
| **DEBUG** | Development details | Variable values, flow decisions |
| **TRACE** | Verbose debugging | Loop iterations, raw data |

## Output Example

```
Order Flow (Reconstructed from Logs)
====================================

Found 8 log points, reconstructed flow:

1. [INFO] "Starting checkout process"
   📍 src/controllers/checkout.ts:125
   → CheckoutController.submit()

2. [DEBUG] "Validating cart items: ${count}"
   📍 src/services/cart.ts:48
   → CartService.validate()

3. [INFO] "Applying discounts for user: ${userId}"
   📍 src/services/discount.ts:122
   → DiscountEngine.apply()
   ⚠️ PII: userId logged (consider masking)

4. [DEBUG] "Reserving inventory: ${JSON.stringify(items)}"
   📍 src/services/inventory.ts:160
   → InventoryService.reserve()

5. [INFO] "Processing payment: amount=${amount}"
   📍 src/services/payment.ts:205
   → PaymentService.process()
   ⚠️ PCI-DSS: payment amount logged

6. [INFO] "Order created: ${orderId}"
   📍 src/services/order.ts:210
   → OrderService.create()

7. [ERROR] (conditional) "Payment failed: ${error.message}"
   📍 src/services/payment.ts:230
   → PaymentService.handleError()

8. [INFO] "Sending confirmation email"
   📍 src/services/notification.ts:45
   → NotificationService.sendConfirmation()

───────────────────────────────────
📊 Log Coverage: 6/8 steps have logs

⚠️ Missing logs in:
├── TaxService.calculate() - No log
└── ShippingService.calculate() - No log

⚠️ Data Sensitivity Issues:
├── Line 122: userId logged (PII)
└── Line 205: payment amount (PCI-DSS risk)

💡 Recommendations:
├── Add DEBUG logs to Tax/Shipping steps
├── Mask userId: log only last 4 chars
├── Add correlation ID for request tracing
└── Consider structured logging (JSON format)
───────────────────────────────────
```

## Trigger Keywords

Primary: `from logs`, `log flow`, `trace logs`
Secondary: `logging`, `debug`, `what is logged`, `log coverage`
