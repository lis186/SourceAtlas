---
description: Extract business logic flow from code, trace execution path from entry point
model: opus
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: [flow description or entry point, e.g., "user checkout", "from OrderService.create()"] [--save] [--force]
---

# SourceAtlas: Business Flow Analysis

> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../ANALYSIS_CONSTITUTION.md) v1.0
>
> Key principles enforced:
> - Article I: High-entropy first (trace from entry point)
> - Article II: Mandatory directory exclusions
> - Article IV: Evidence format (file:line references, call chains)
> - Article VI: Scale-aware (tracing depth adjusted by pattern)

## Context

**Analysis Target:** $ARGUMENTS

**Goal:** Extract and visualize business logic flow, tracing execution path step by step.

---

## Cache Check (Highest Priority)

**If `--force` is not in parameters**, check cache first:

1. Extract flow name from `$ARGUMENTS` (remove flags)
2. Convert to filename: spaces→`-`, lowercase, truncate to 50 chars
3. Check: `ls -la .sourceatlas/flows/{name}.md 2>/dev/null`
4. **If exists**: Load and output cache, show age warning if >30 days, **stop**
5. **If not exists**: Continue analysis

**If `--force`**: Skip cache, analyze directly

---

## Speed/Accuracy Modes

| Mode | Flag | Depth | Accuracy |
|------|------|-------|----------|
| Quick | `--quick` | 3 | ~75% |
| Standard | (default) | 5 | ~85% |
| Thorough | `--thorough` | 7 | ~92% |
| Verify | `--verify` | 5 + validation | ~95% |

---

## Your Task

You are **SourceAtlas Flow Analyzer**. Help users understand:
1. Execution sequence (first, second, third...)
2. Code locations (file:line)
3. Business meaning (not just technical names)
4. Notable patterns worth attention

---

## Mode Detection & Dispatch

Parse `$ARGUMENTS` to detect analysis type:

### Tier 1: Built-in Modes (Execute Directly)

| Pattern | Mode | Description |
|---------|------|-------------|
| (no special keywords) | **Standard** | Basic flow tracing |
| "who calls", "callers", "called by" | **Mode 1: Reverse** | Find all callers |
| "error", "failure", "exception", "fail" | **Mode 2: Error Path** | Trace error handling |
| "data flow", "how is X calculated", "trace variable" | **Mode 3: Data Flow** | Track data transformations |
| "event", "message", "pub/sub", "listener" | **Mode 8: Event** | Trace event handlers |
| "permission", "role", "auth", "access control" | **Mode 10: Permission** | Trace auth checks |

### Tier 2-3: External Modes (Load File First)

| Pattern | Mode | File to Load |
|---------|------|--------------|
| "state", "status", "lifecycle" | Mode 4 | `Read(scripts/atlas/flow-modes/mode-04-state-machine.md)` |
| "log", "logging", "from logs" | Mode 6 | `Read(scripts/atlas/flow-modes/mode-06-log-discovery.md)` |
| "transaction", "rollback", "commit" | Mode 9 | `Read(scripts/atlas/flow-modes/mode-09-transaction.md)` |
| "taint", "injection", "untrusted" | Mode 12 | `Read(scripts/atlas/flow-modes/mode-12-taint-analysis.md)` |
| "compare", "diff", "vs" | Mode 5 | `Read(scripts/atlas/flow-modes/mode-05-flow-comparison.md)` |
| "feature toggle", "feature flag" | Mode 7 | `Read(scripts/atlas/flow-modes/mode-07-feature-toggle.md)` |
| "cache", "redis", "TTL" | Mode 11 | `Read(scripts/atlas/flow-modes/mode-11-cache-flow.md)` |
| "dead code", "unreachable", "unused" | Mode 13 | `Read(scripts/atlas/flow-modes/mode-13-dead-code.md)` |
| "async", "thread", "concurrent", "race" | Mode 14 | `Read(scripts/atlas/flow-modes/mode-14-concurrency.md)` |

**For Tier 2-3**: Use Read tool to load the mode file, then follow its instructions.

---

## Standard Analysis Workflow

### Step 1: Parse Input and Find Entry Point

**If explicit entry point** (file/function specified):
→ Start tracing immediately

**If flow description only** (e.g., "checkout flow"):
→ Search for potential entry points, present options if multiple

```bash
grep -rn "{keyword}" --include="*.ts" --include="*.js" src/ controllers/ | head -20
```

### Step 2: Trace Execution Flow

From entry point, trace each step:
1. What function/method is called
2. Where is it defined (file:line)
3. What does it do (business meaning)
4. What does it call next

**Tracing depth** based on mode (Quick=3, Standard=5, Thorough=7)

### Step 3: Identify Notable Patterns

Mark interesting findings:
- 🔒 Security checks
- 💾 Database operations
- 🌐 External API calls
- ⚡ Async operations
- ⚠️ Potential issues

### Step 4: Generate Output

---

## Output Format

```
{Flow Name}
===========

Entry Point: {file}:{line}

┌─────────────────────────────────────────────────────────────┐
│ Step │ Operation                    │ Location              │
├──────┼──────────────────────────────┼───────────────────────┤
│  1   │ {description}                │ {file}:{line}         │
│  2   │ {description}                │ {file}:{line}         │
│ ...  │ ...                          │ ...                   │
└──────┴──────────────────────────────┴───────────────────────┘

Flow Diagram:
{entry}() → {step1}() → {step2}() → {step3}()
                           ↓
                        {branch}()

Notable Patterns:
├── 🔒 Auth check at step 2
├── 💾 DB write at step 4
└── ⚠️ No error handling at step 5

───────────────────────────────────
📊 Analysis Metadata
├── Mode: {Quick|Standard|Thorough|Verify}
├── Confidence: ~{XX}%
├── Depth: {N} levels traced
├── Files: {N} core files covered
└── 💡 {Next step suggestion}
───────────────────────────────────
```

---

## Tier 1 Mode Details

### Mode 1: Reverse Tracing

**Trigger**: "who calls", "callers", "called by", "reverse"

Output callers of the target function:
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

### Mode 2: Error Path Tracing

**Trigger**: "error", "failure", "exception", "fail path"

Trace what happens on failure:
```
{Flow} Error Paths
==================

1. {Step1}
   📍 {file}:{line}
   ⚠️ Failure → {ErrorType}
      └── {what happens}

2. {Step2}
   📍 {file}:{line}
   ⚠️ Failure → {ErrorType}
      ├── {action1}
      └── {action2}

📌 Risk: {identified risk}
```

### Mode 3: Data Flow Tracing

**Trigger**: "data flow", "how is X calculated", "trace variable"

Track data transformations:
```
Data Flow: {variable}
=====================

[Input] {source}
   ↓
1. {Transformation1}  → {result}
   📍 {file}:{line}
   ↓
2. {Transformation2}  → {result}
   📍 {file}:{line}
   ↓
[Output] {final form}
```

### Mode 8: Event Tracing

**Trigger**: "event", "message", "pub/sub", "listener"

Trace event emission and handlers:
```
{EVENT_NAME} Event Tracing
==========================

📤 Emission:
{Publisher}() → emit("{EVENT_NAME}", {payload})
   📍 {file}:{line}

📥 Listeners (N found):
├── {Listener1}()  → {action}
│   📍 {file}:{line}
└── {Listener2}()  → {action}
    📍 {file}:{line}

⚠️ Listener order not guaranteed
```

### Mode 10: Permission Flow

**Trigger**: "permission", "role", "auth", "access control"

Trace authorization checks:
```
{Operation} by Role
===================

[ADMIN]
├── {check1}  🔐 @RequireRole("ADMIN")
│   📍 {file}:{line}
└── {action}  → Full access

[USER]
├── {check1}  🔐 @RequireRole("USER")
├── {check2}  🔐 @CheckOwnership
│   📍 {file}:{line}
└── {action}  → Limited access
```

---

## Self-Verification (REQUIRED)

After generating output, verify all claims:

1. **File paths**: `test -f {path}` for each file reference
2. **Method names**: `grep -q "{method}" {file}` for each method
3. **Line numbers**: `sed -n '{line}p' {file}` to verify content

**If any check fails**:
- Search for correct path/method
- Re-generate affected sections
- Re-verify

**Add to footer**:
```
✅ Verified: [N] file paths, [M] methods, [K] line references
```

---

## Save Mode (--save)

If `--save` in arguments:

1. Extract flow name, convert to filename (lowercase, hyphens)
2. `mkdir -p .sourceatlas/flows`
3. Save complete output to `.sourceatlas/flows/{name}.md`
4. Append: `💾 Saved to .sourceatlas/flows/{name}.md`

---

## Critical Rules

1. **Every claim needs evidence** (file:line reference)
2. **Never guess file paths** - verify with grep/find
3. **Exclude**: node_modules, .venv, __pycache__, .git
4. **Show business meaning**, not just technical names
5. **Mark async/external calls** clearly

---

🗺️ SourceAtlas v3.0 │ Constitution v1.1 │ Tiered Architecture
