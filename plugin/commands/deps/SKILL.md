---
name: deps
description: Analyze dependency usage for library/framework/SDK upgrades
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write, WebSearch, WebFetch
argument-hint: [target, e.g., "react 17 → 18", "iOS 16", "lodash"] [--force]
---

# SourceAtlas: Dependencies

> **Constitution**: [ANALYSIS_CONSTITUTION.md](../../../ANALYSIS_CONSTITUTION.md) v1.1

## Context

**Target:** $ARGUMENTS (library name, version upgrade, or iOS minimum version)
**Goal:** Analyze dependency usage and provide upgrade guidance
**Time Limit:** 5-15 minutes

## Quick Start

1. **Check cache** (skip if `--force` flag present)
2. **Detect version** from manifest files (package.json, Podfile, etc.)
3. **Search for upgrade rules** using WebSearch (if version upgrade)
4. **Find all usage points** using grep/Glob
5. **Categorize usage** by API type
6. **Generate YAML report** following [output-template.md](output-template.md)
7. **Verify output** using [verification-guide.md](verification-guide.md)
8. **Auto-save** to `.sourceatlas/deps/`

## Your Task

You are analyzing dependency usage to help users understand:
1. **Current state**: Which version is installed, where it's used
2. **Upgrade impact**: What needs to change for version upgrades
3. **Migration path**: Step-by-step upgrade checklist
4. **Risk assessment**: How complex is the upgrade

### Upgrade Types You Handle

| Input Pattern | Type | Focus |
|--------------|------|-------|
| `iOS 17`, `iOS 16 → 17` | iOS Minimum Version Upgrade | Removable `#available`, deprecated APIs, new opportunities |
| `iOS SDK 26`, `Xcode 16` | SDK/Compiler Upgrade | Compilation warnings, Swift version, new syntax |
| `react 17 → 18`, `pandas 1.x → 2.x` | Major Version Upgrade | Breaking changes, deprecated APIs, new patterns |
| `react`, `pandas` (no version) | Usage Inventory | List usage points only |

---

## Core Workflow

Execute these phases in order. See [workflow.md](workflow.md) for complete details.

### Phase 0: Rule Confirmation (1-2 minutes)

**Purpose:** Identify upgrade type and confirm analysis rules with user before proceeding.

**Steps:**
1. Detect upgrade type from `$ARGUMENTS`
2. Generate rules preview (what to check, where to search)
3. Use `AskUserQuestion` to confirm rules

→ See [workflow.md#phase-0](workflow.md#phase-0-rule-confirmation-1-2-minutes)

### Phase 1: Detect Current Version (1 minute)

**Purpose:** Find current dependency version from manifest files.

**Manifest files by ecosystem:**
- Node.js: `package.json`, `package-lock.json`
- iOS: `Podfile`, `Package.swift`
- Android: `build.gradle`, `build.gradle.kts`

→ See [workflow.md#phase-1](workflow.md#phase-1-detect-current-version-1-minute)

### Phase 2: Search for Upgrade Guide (2-3 minutes)

**Purpose:** Find official migration guide using WebSearch.

**Search for:**
1. Official migration guide
2. Official changelog
3. Community upgrade guides
4. GitHub release notes

→ See [workflow.md#phase-2](workflow.md#phase-2-search-for-upgrade-guide-2-3-minutes)

### Phase 3: Find All Usage Points (3-5 minutes)

**Purpose:** Locate every place the dependency is used.

**Search patterns:**
- JavaScript/TypeScript: `import` statements, API calls
- Swift/iOS: `import` statements, `#available` checks
- Android/Kotlin: `import` statements, API level checks

→ See [workflow.md#phase-3](workflow.md#phase-3-find-all-usage-points-3-5-minutes)

### Phase 4: Categorize API Usage (2-3 minutes)

**Purpose:** Group usage by category and match against upgrade rules.

**Categories:**
- Hooks (React), Components, Utilities (JavaScript)
- Frameworks, APIs (iOS/Android)
- Availability checks (iOS)
- Deprecated APIs (all platforms)

→ See [workflow.md#phase-4](workflow.md#phase-4-categorize-api-usage-2-3-minutes)

### Phase 5: Generate Analysis Report

**Purpose:** Output complete YAML analysis following template.

→ See [output-template.md](output-template.md) for complete format

---

## Output Format

Your analysis should follow this YAML structure:

```yaml
dependency_analysis:
  target: "${ARGUMENTS}"
  type: "[library|sdk|framework|runtime]"
  analysis_time: "[ISO 8601 timestamp]"
  constitution_version: "1.1"

version_info:
  current: "[detected version]"
  source: "[manifest file]"
  target: "[target version if upgrade]"

rules_applied:
  source: "[built-in|web_search|user_provided]"
  rule_count: [number]

# Required changes for upgrade
required_changes:
  removable_availability_checks: [...]
  deprecated_api_usages: [...]
  breaking_change_impacts: [...]

# Optional modernization opportunities
modernization_opportunities:
  items: [...]

# Complete usage inventory
usage_inventory:
  total_files: [number]
  total_usage_points: [number]
  by_category: [...]

# Step-by-step migration guide
migration_checklist:
  estimated_effort: "[low|medium|high]"
  recommended_approach: "[description]"
  steps: [...]

# Risk evaluation
risk_assessment:
  overall_risk: "[🟢 low|🟡 medium|🔴 high]"
  factors: [...]
  recommendations: [...]
```

→ See [output-template.md](output-template.md) for complete specification and examples

---

## Critical Rules

### 1. Rule Confirmation Required
- **Always use `AskUserQuestion`** in Phase 0 to confirm rules before full analysis
- Show user what you plan to check (availability patterns, deprecated APIs, etc.)
- Get explicit approval before proceeding to Phase 1-5

### 2. Version Detection Must Be Accurate
- **Always grep manifest files** for current version
- Use lock files (package-lock.json, Podfile.lock) for actual installed version
- Never guess or estimate version numbers

### 3. Evidence-Based Analysis Only
- **Every usage point must have `file:line` reference**
- All counts must be verifiable via grep
- No assumptions about code you haven't seen

### 4. Upgrade Guide Source Transparency
```yaml
rules_applied:
  source: "web_search"  # Or "built-in" if no guide found
  rule_count: 12
```
- Always disclose where upgrade rules came from
- Prefer official docs over community guides
- Note limitations if no official guide found

### 5. Verification Required Before Output
- Execute [verification-guide.md](verification-guide.md) after generating analysis
- Verify version numbers, file paths, usage counts
- Correct any discrepancies before final output

### 6. Constitutional Compliance
Follow [ANALYSIS_CONSTITUTION.md](../../../ANALYSIS_CONSTITUTION.md):
- **Article I**: Evidence-based (all claims reference actual code)
- **Article III**: Verification (run V1-V4 checks)
- **Article V**: Transparency (show cache age, source, limitations)
- **Article VII**: User Empowerment (actionable checklist, effort estimates)

---

## Self-Verification

After generating your analysis, execute verification steps:

### Step V1: Extract Verifiable Claims
Parse output for all quantifiable claims (counts, versions, file paths)

### Step V2: Parallel Verification
- Verify version detection
- Verify API usage counts (±5% tolerance)
- Verify file paths (sample 3-5 files)
- Verify upgrade guide quality

### Step V3: Handle Results
- ✅ All checks pass → Proceed to output
- ⚠️ Minor issues (1-2 checks) → Correct and note
- ❌ Major issues (3+ checks) → Re-execute analysis

### Step V4: Add Verification Summary
```yaml
verification_summary:
  checks_performed: [...]
  confidence_level: "high"  # high|medium|low
  notes: [...]
```

→ See [verification-guide.md](verification-guide.md) for complete checklist

---

## Advanced

### Cache Behavior
- **Default**: Use cache if exists and fresh
- **Force flag**: Skip cache with `--force`
- **Cache location**: `.sourceatlas/deps/${SANITIZED_TARGET}.md`

→ See [reference.md#cache-behavior](reference.md#cache-behavior)

### Auto-Save Mechanism
Complete YAML report auto-saves after verification:
```
💾 Saved to .sourceatlas/deps/react-17-18.md
```

→ See [reference.md#auto-save-behavior](reference.md#auto-save-behavior)

### Handoffs to Next Commands
After analysis, suggest appropriate next steps based on risk level.

→ See [reference.md#handoffs](reference.md#handoffs)

### Language-Specific Tips
- JavaScript/TypeScript: Include all variants (.js, .jsx, .ts, .tsx)
- Swift/iOS: Exclude Pods directory, check `#available` patterns
- Android/Kotlin: Check compileSdk, minSdk, targetSdk

→ See [reference.md#language-specific-best-practices](reference.md#language-specific-best-practices)

---

## Support Files

Detailed documentation available in:

- **[workflow.md](workflow.md)** - Complete Phase 0-5 execution guide with bash commands and examples
- **[output-template.md](output-template.md)** - Full YAML structure, field descriptions, and examples
- **[verification-guide.md](verification-guide.md)** - Self-verification steps V1-V4 with verification scripts
- **[reference.md](reference.md)** - Cache behavior, auto-save, handoffs, language-specific tips

---

## Output Header

Start your output with:

```markdown
🗺️ SourceAtlas: Dependencies
───────────────────────────────
📦 [target] │ [N] APIs found
```

Then output complete YAML following [output-template.md](output-template.md).
