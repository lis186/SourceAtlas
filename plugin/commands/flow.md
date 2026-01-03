---
description: Extract business logic flow from code, trace execution path from entry point
model: opus
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: [flow description or entry point, e.g., "user checkout", "from OrderService.create()"] [--force]
---

# SourceAtlas: Flow Analysis

**Target:** $ARGUMENTS

---

## STEP 0: Mode Detection (EXECUTE IMMEDIATELY)

**IMPORTANT: Check these patterns FIRST before doing anything else.**

### Check for Tier 2-3 Keywords (External Mode Required)

Scan `$ARGUMENTS` for these keywords. **If ANY match, load external file and STOP reading this document:**

| If arguments contain... | Then execute this action |
|------------------------|--------------------------|
| "dead code" OR "unreachable" OR "unused" | `Read scripts/atlas/flow-modes/mode-13-dead-code.md` then follow its instructions |
| "async" OR "thread" OR "concurrent" OR "race" | `Read scripts/atlas/flow-modes/mode-14-concurrency.md` then follow its instructions |
| "taint" OR "injection" OR "untrusted" | `Read scripts/atlas/flow-modes/mode-12-taint-analysis.md` then follow its instructions |
| "state" OR "status" OR "lifecycle" | `Read scripts/atlas/flow-modes/mode-04-state-machine.md` then follow its instructions |
| "transaction" OR "rollback" OR "commit" | `Read scripts/atlas/flow-modes/mode-09-transaction.md` then follow its instructions |
| "log" OR "logging" OR "from logs" | `Read scripts/atlas/flow-modes/mode-06-log-discovery.md` then follow its instructions |
| "compare" OR "diff" OR "vs" | `Read scripts/atlas/flow-modes/mode-05-flow-comparison.md` then follow its instructions |
| "feature toggle" OR "feature flag" | `Read scripts/atlas/flow-modes/mode-07-feature-toggle.md` then follow its instructions |
| "cache" OR "redis" OR "TTL" | `Read scripts/atlas/flow-modes/mode-11-cache-flow.md` then follow its instructions |

**If a keyword matched above**: Load the file NOW, then execute ONLY that mode's instructions. Do NOT continue reading this document.

### Check for Tier 1 Keywords (Built-in Modes)

If none of the above matched, check for these Tier 1 patterns:

| If arguments contain... | Mode to use |
|------------------------|-------------|
| "who calls" OR "callers" OR "called by" | Mode 1: Reverse Tracing (see below) |
| "error" OR "failure" OR "exception" OR "fail" | Mode 2: Error Path (see below) |
| "data flow" OR "how is X calculated" OR "trace variable" | Mode 3: Data Flow (see below) |
| "event" OR "message" OR "pub/sub" OR "listener" | Mode 8: Event Tracing (see below) |
| "permission" OR "role" OR "auth" OR "access control" | Mode 10: Permission Flow (see below) |
| (none of the above) | Standard Flow Tracing (default) |

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

## Tier 1 Mode: Reverse Tracing

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

## Tier 1 Mode: Error Path

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

## Tier 1 Mode: Data Flow

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

## Tier 1 Mode: Event Tracing

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

## Tier 1 Mode: Permission Flow

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

Before output, verify:
1. File paths exist: `test -f {path}`
2. Methods exist: `grep -q "{method}" {file}`

Add to footer: `✅ Verified: [N] paths, [M] methods`

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

🗺️ SourceAtlas v3.0 │ Tiered Architecture
