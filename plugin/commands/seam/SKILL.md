---
name: seam
description: Discover responsibility zones and seam candidates using multi-LLM cross-validation (Gemini blind scan → Claude structured analysis → Codex adversarial review)
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: "<file-path> [--language objc|swift|typescript|javascript|go|java|kotlin|python|rust] [--force]"
---

# SourceAtlas: Seam Discovery

> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../../ANALYSIS_CONSTITUTION.md) v1.0
>
> Key principles enforced:
> - Article I: Structure over details (find responsibility boundaries, not implementation)
> - Article IV: Evidence format (file:line references)
> - Article VI: Scale awareness (narrow before deep)

## Context

**Target:** $ARGUMENTS

**Goal:** Discover responsibility zones and seam points in a large file, so the user can run `/atlas.audit` on a focused subset instead of the entire file.

**Time Limit:** 2-5 minutes per file.

**Composability:** This skill outputs zone maps that feed into `/atlas.audit --zone <zone-id>`.

---

## When to Use

- File has **200+ lines** with multiple responsibilities
- Running `/atlas.audit` on the whole file produces **too many contracts** to act on
- User needs to **choose which zone to refactor first**
- Architect says "narrow scope before extracting contracts"

---

## Quick Start

1. **Parse arguments** → file path + language detection
2. **Check environment** → gemini CLI, codex CLI (degraded mode if missing)
3. **Run `detect-zones.sh`** → raw zone map (boundaries + methods + message sends)
4. **Gemini blind scan** → broad seam discovery without Claude framing
5. **Claude structured analysis** → cluster by responsibility, identify seam types
6. **Codex adversarial review** → CONFIRM / DISPUTE / ADD / FLAG
7. **Claude merge** → resolve disputes, integrate additions
8. **Present zone map** → ranked by refactoring priority + cross-validation summary
9. **User selects zone** → pipe to `/atlas.audit`

---

## Your Task

You are **SourceAtlas Seam Analyst**, specialized in Michael Feathers' seam analysis and responsibility zone discovery.

Help the user understand:
1. **What responsibility zones exist** in the target file (domain clustering)
2. **Where the seams are** — places where behavior can be altered without editing (Object/Link/Preprocessing)
3. **Which zone to refactor first** (complexity × coupling score)
4. **How to feed the chosen zone into `/atlas.audit`** for focused contract extraction

---

## Core Workflow

> For step-by-step execution details, see [workflow.md](workflow.md).

### Step 1: Parse Arguments and Run detect-zones.sh (30 seconds)

```bash
# Auto-detect language from extension
bash plugin/commands/seam/scripts/detect-zones.sh "$FILE_PATH"

# Or explicit language
bash plugin/commands/seam/scripts/detect-zones.sh "$FILE_PATH" --language objc
```

The script outputs YAML with 3 layers:
- **Layer 1**: Zone boundaries (pragma marks, MARK comments, regions) + grep-based deps
- **Layer 2**: Method signatures per zone (line counts)
- **Layer 3**: Clang AST method details with message sends (ObjC/Swift only)

> If clang is unavailable, Layer 2/3 falls back to grep — still useful but less precise.

### Step 2: Environment Check (30 seconds)

Check for `gemini` and `codex` CLIs. If either is missing, enter **degraded mode**: generate prompt files for manual execution and continue with Claude-only analysis, marking output as `mode: degraded`.

### Step 3: Gemini Blind Scan (2-3 minutes)

Gemini receives **only the source code and detect-zones.sh output** — no taxonomy framing, no Feathers schema. This prevents confirmation bias from Claude's structured prompt.

Gemini outputs: a list of potential injection points, dependency boundaries, and patterns it finds suspicious or hard-coded.

### Step 4: Claude Structured Analysis (2-3 minutes)

With the raw zone map AND Gemini's blind scan in hand, perform semantic analysis:

#### 4a. Responsibility Clustering (Sandi Metz's message-passing)

Group methods by their **external collaborators** (from `sends` in Layer 3):
- Methods sending to `aesEncryptWithData:`, `hmacSha512:` → **Encryption zone**
- Methods sending to `postNotificationName:`, `addObserver:` → **Notification zone**
- Methods sending to `dispatch_semaphore_wait`, `dispatch_sync` → **Synchronization zone**

#### 4b. Seam Type Identification (Michael Feathers)

For each zone, identify available seams **based on language group**:

| Group | Languages | Primary Seam | Enabling Point |
|-------|-----------|-------------|----------------|
| **A: Nominal** | Java, ObjC, Kotlin, Swift, Rust | Object Seam | Constructor/init injection |
| **B: Structural** | Go, TypeScript | Object Seam (implicit) | Struct field / constructor |
| **C: Dynamic** | JavaScript, Python | Module Seam | `jest.mock` / `mock.patch` |

> See [references/language-groups.md](references/language-groups.md) for full decision matrix.
> See [references/seam-types.md](references/seam-types.md) for all seam types per language.

#### 4c. Code Smell Detection (Martin Fowler)

Flag zones exhibiting:
- **Feature Envy**: Methods that call more external classes than internal ones
- **Divergent Change**: Zone changes for unrelated reasons
- **Shotgun Surgery**: Small change requires touching many zones

### Step 5: Codex Adversarial Review (2-3 minutes)

Codex receives: source code, detect-zones.sh output, Gemini blind scan, Claude's seam candidates.

Codex issues one verdict per candidate — and independently adds any it finds missing:

| Verdict | Meaning |
|---------|---------|
| **CONFIRM** | Seam candidate valid, enabling point exists, coverage claim accurate |
| **DISPUTE** | Seam type wrong, enabling point missing, or coverage overstated |
| **ADD** | Dependency or seam type Claude missed (Gemini or Codex found it) |
| **FLAG** | Architectural issue seams cannot solve (e.g., shared mutable state) |

### Step 6: Claude Merge (1 minute)

Resolve disputes and integrate additions to produce the final seam list:
- **DISPUTED** candidates: re-evaluate with evidence from both sides; drop if Codex's objection holds
- **ADDED** candidates: incorporate with Claude's seam type classification
- **FLAGGED** concerns: record in `seam_validation.architectural_concerns`

### Step 7: Score and Rank Zones (30 seconds)

For each zone, compute a **refactoring priority score**:

```
priority = method_count × unique_deps × (1 + smell_count)
```

Higher score = more urgent to extract. Present as a ranked list.

### Step 8: Present Zone Map

> See [Output Format](#output-format) below.

### Step 9: User Selection → Audit

After the user picks a zone:

```
/atlas.audit <file-path> --lines <start>-<end>
```

Or suggest copy-pasting the zone into a temporary file for isolated audit.

---

## Output Format

```
🔬 SourceAtlas: Seam Analysis
───────────────────────────────
📋 $FILENAME │ $LANGUAGE │ $TOTAL_LINES lines │ $ZONE_COUNT zones

📊 Zone Map (ranked by refactoring priority)

┌─ #1 ⚡ Encryption (lines 295-410, 8 methods)
│  Responsibility: AES encrypt/decrypt, HMAC signing
│  Sends to: CocoaSecurity, NSData+Base64, CommonCrypto
│  Seams: Object (extractable via protocol)
│  Smells: Feature Envy (7/8 methods call CocoaSecurity)
│  Priority: 24 (8 methods × 3 deps × 1 smell)
│
├─ #2 Core Dispatch (lines 85-200, 5 methods)
│  Responsibility: HTTP request building + semaphore sync
│  Sends to: AFNetworking, dispatch_semaphore_*
│  Seams: Object (inject HTTP client), Preprocessing (#ifdef DEBUG)
│  Smells: Divergent Change (HTTP + sync mixed)
│  Priority: 20
│
├─ #3 Notification (lines 410-480, 3 methods)
│  ...
│
└─ #4 Lifecycle (lines 1-84, 2 methods)
│  ...

🎯 Cross-Validation
- Gemini candidates: N
- Claude candidates: M
- Codex confirmed: X / disputed: Y / added: Z / flagged: W
[Architectural concerns, if any]

🎯 Recommendation
Start with Zone #1 (Encryption) — highest priority, cleanest Object Seam.
Run: /atlas.audit $FILE_PATH --lines 295-410

📁 Saved to: .sourceatlas/seam/$MODULE.yaml
```

> See [templates/zone-report.yaml](templates/zone-report.yaml) for structured output.

---

## Critical Rules

1. **Script is camera, Claude is photographer** — `detect-zones.sh` outputs raw facts, you do all semantic analysis
2. **Evidence-Based**: Every zone boundary must reference file:line
3. **Language-Aware**: Use language-specific markers from detect-zones.sh
4. **Compose with audit**: Output must be directly usable as `/atlas.audit` input
5. **One File at a Time**: Do not batch-process multiple files
6. **Graceful Degradation**: No clang? Use grep-based deps. No pragma marks? Use method clustering.
7. **Cross-Validated**: Seam candidates require Gemini blind scan + Codex adversarial review. Claude-only analysis is degraded mode only.
8. **Gemini sees no taxonomy**: The blind scan prompt must NOT include Feathers seam types, language groups, or Claude's candidate list. Independence is the value.
9. **Degraded Mode**: If `gemini` or `codex` CLI is unavailable, generate prompt files in `.sourceatlas/seam/prompts/` and mark output `mode: degraded`.

---

## Gotchas

> See [gotchas.md](gotchas.md) for full list.

Key pitfalls:
- **Pragma marks lie**: `#pragma mark - POST Methods` may contain GET logic (e.g., `postPathForECoupon:` calls `getPath:`)
- **success:/failure: false positives**: Pattern `success:|failure:` in objc.patterns matches almost every AFNetworking method — not useful for zone differentiation
- **Clang needs headers**: Without CocoaPods `-I` flags, clang stops at the first `#import <Framework/X.h>` — Layer 3 will be empty. `resolve-header-paths.sh` handles this automatically.

---

## Support Files

- **[workflow.md](workflow.md)** - Detailed step-by-step execution guide
- **[gotchas.md](gotchas.md)** - Known failure patterns and workarounds
- **[references/seam-types.md](references/seam-types.md)** - Feathers seam taxonomy per language
- **[templates/zone-report.yaml](templates/zone-report.yaml)** - Structured output template
- **scripts/detect-zones.sh** - Zone detection script (9 languages)
- **scripts/resolve-header-paths.sh** - Header path resolution for clang
