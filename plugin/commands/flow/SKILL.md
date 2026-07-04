---
name: flow
description: Traces code execution paths and business logic flow from an entry point, producing a call graph with boundary detection and file:line references. Use when the user asks "how does X work", "what happens when X", "trace this flow", "where does this data come from", or "who calls X".
model: opus
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: [flow description or entry point, e.g., "user checkout", "from OrderService.create()"] [--force]
---

# SourceAtlas: Flow Analysis

**Target:** $ARGUMENTS

---

## STEP 0: Mode Detection (EXECUTE IMMEDIATELY)

**IMPORTANT: Check these patterns FIRST before doing anything else.**

Scan `$ARGUMENTS` for these keywords to pick the analysis mode:

| If arguments contain... | Mode | Approach |
|------------------------|------|----------|
| "who calls" OR "callers" OR "called by" | Reverse Tracing | See template below |
| "error" OR "failure" OR "exception" OR "fail" | Error Path | See template below |
| "data flow" OR "how is X calculated" OR "trace variable" | Data Flow | See template below |
| "event" OR "message" OR "pub/sub" OR "listener" | Event Tracing | See template below |
| "permission" OR "role" OR "auth" OR "access control" | Permission Flow | See template below |
| "dead code" OR "unreachable" OR "unused" | Dead Code | Find definitions with no callers or references; before declaring dead, check exports, DI/reflection, config-driven dispatch, and tests |
| "async" OR "thread" OR "concurrent" OR "race" | Concurrency | Trace across async boundaries (threads, queues, await points); flag shared mutable state and unsynchronized access |
| "taint" OR "injection" OR "untrusted" | Taint Analysis | Trace untrusted input from source to sink; flag any path reaching SQL/exec/render/filesystem without sanitization |
| "state" OR "status" OR "lifecycle" | State Machine | Enumerate states and transitions; for each transition capture trigger, guard, and action; flag unreachable states and missing transitions |
| "transaction" OR "rollback" OR "commit" | Transaction | Trace begin/commit/rollback boundaries; flag operations outside the transaction and partial-failure risks |
| "log" OR "logging" OR "from logs" | Log Discovery | Match given log lines to logging statements in code, then trace the execution path between them |
| "compare" OR "diff" OR "vs" | Flow Comparison | Trace each flow separately, then diff step-by-step: shared path, divergence points, behavioral differences |
| "feature toggle" OR "feature flag" | Feature Toggle | Locate the flag definition and evaluation points, then trace both the enabled and disabled branches |
| "cache" OR "redis" OR "TTL" | Cache Flow | Trace read/write paths through the cache: hit/miss branches, TTL, invalidation points, stale-data risks |
| (none of the above) | Standard Flow Tracing (default) | Steps 2–4 below |

For modes without a template, follow the Approach column and adapt the STEP 4 output skeleton (steps table + flow diagram + patterns).

---

## STEP 1: Cache Check

If `--force` NOT in arguments:
1. Convert flow name to filename: lowercase, spaces→hyphens, max 50 chars
2. Check: `ls .sourceatlas/flows/{name}.md 2>/dev/null`
3. If exists: Load and output cache, then STOP
4. If not exists: Continue

---

## STEP 2: Find Entry Point

**If explicit path given** (e.g., "from OrderService.create()"):
→ Start tracing immediately

**If flow description only** (e.g., "checkout flow"):
→ Search for entry points:
```bash
grep -rn "{keyword}" --include="*.ts" --include="*.js" --include="*.py" src/ app/ lib/ 2>/dev/null | head -15
```
→ Present options if multiple matches

---

## STEP 3: Trace Flow

From entry point, trace each step:
1. Read the function
2. Identify what it calls
3. Follow the chain (depth: 5 levels default)
4. Stop at boundaries (DB, external API, third-party)

For each step capture:
- Function name
- File:line location
- Business meaning
- Notable patterns (🔒 security, 💾 DB, 🌐 API, ⚡ async, ⚠️ risk)

---

## STEP 4: Output Format

```
{Flow Name}
===========

Entry Point: {file}:{line}

┌──────┬──────────────────────────────┬───────────────────────┐
│ Step │ Operation                    │ Location              │
├──────┼──────────────────────────────┼───────────────────────┤
│  1   │ {description}                │ {file}:{line}         │
│  2   │ {description}                │ {file}:{line}         │
└──────┴──────────────────────────────┴───────────────────────┘

Flow Diagram:
{entry}() → {step1}() → {step2}() → {step3}()

Notable Patterns:
├── 🔒 {pattern1}
├── 💾 {pattern2}
└── ⚠️ {pattern3}

───────────────────────────────────
📊 Mode: Standard | Confidence: ~85% | Depth: 5
───────────────────────────────────
```

---

## Mode: Reverse Tracing

**Trigger**: "who calls", "callers", "called by"

Find all callers of target function:
```
Who calls {function}?
=====================

Callers (N found):
├── {Caller1}()  → {description}
│   📍 {file}:{line}
├── {Caller2}()  → {description}
│   📍 {file}:{line}
└── {Caller3}()  → {description}
    📍 {file}:{line}

💡 Modifying {function} affects these {N} callers
```

---

## Mode: Error Path

**Trigger**: "error", "failure", "exception", "fail"

Trace failure scenarios:
```
{Flow} Error Paths
==================

1. {Step}
   📍 {file}:{line}
   ⚠️ Failure → {ErrorType}
      └── {what happens}

📌 Risk: {identified risk}
```

---

## Mode: Data Flow

**Trigger**: "data flow", "how is X calculated", "trace variable"

Track data transformations:
```
Data Flow: {variable}
=====================

[Input] {source}
   ↓
1. {Transform}  → {result}
   📍 {file}:{line}
   ↓
[Output] {final}
```

---

## Mode: Event Tracing

**Trigger**: "event", "message", "pub/sub", "listener"

```
{EVENT} Tracing
===============

📤 Emission: {Publisher}() → emit("{EVENT}")
   📍 {file}:{line}

📥 Listeners:
├── {Listener1}()  → {action}
│   📍 {file}:{line}
└── {Listener2}()  → {action}
    📍 {file}:{line}
```

---

## Mode: Permission Flow

**Trigger**: "permission", "role", "auth", "access control"

```
{Operation} by Role
===================

[ADMIN] → Full access
├── {check}  🔐 @RequireRole("ADMIN")
└── 📍 {file}:{line}

[USER] → Limited access
├── {check}  🔐 @CheckOwnership
└── 📍 {file}:{line}
```

---

## Self-Verification

Before saving, verify every claimed file path exists (`test -f {path}`); correct anything that fails.

---

## Auto-Save (Default Behavior)

After analysis completes, automatically:
1. `mkdir -p .sourceatlas/flows`
2. Save to `.sourceatlas/flows/{name}.md`
3. Append: `💾 Saved to .sourceatlas/flows/{name}.md`

---

## Deprecated: --save flag

If `--save` is in arguments:
- Show: `⚠️ --save is deprecated, auto-save is now default`
- Remove `--save` from arguments
- Continue normal execution (still auto-saves)

---

🗺️ SourceAtlas Flow Analysis
