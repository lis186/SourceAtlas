---
name: history
description: Smart temporal analysis using git history - Hotspots, Coupling, and Recent Contributors
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write, AskUserQuestion
argument-hint: (optional) [path or scope, e.g., "src/", "frontend", "last 6 months"] [--force]
---

# SourceAtlas: Smart Temporal Analysis (Git History)

> **Constitution**: [ANALYSIS_CONSTITUTION.md](../../../ANALYSIS_CONSTITUTION.md) v1.0

## Context

**Analysis Scope:** $ARGUMENTS (default: entire repository)
**Goal:** Extract actionable insights from git history
**Time Limit:** 5-10 minutes
**Prerequisite:** code-maat (will ask permission to install if missing)

## Quick Start

1. **Check cache** (skip if `--force` flag present)
2. **Check code-maat** installation (install if needed with permission)
3. **Generate git log** (last 12 months, code-maat compatible)
4. **Run analyses**: Hotspots, Coupling, Contributors
5. **Risk assessment** combining all dimensions
6. **Generate report** following [output-template.md](output-template.md)
7. **Verify output** using [verification-guide.md](verification-guide.md)
8. **Auto-save** to `.sourceatlas/history.md`

## Your Task

You are analyzing git commit history to understand:
1. **Hotspots** - Files changed most frequently (likely complex/risky)
2. **Temporal Coupling** - Files that change together (hidden dependencies)
3. **Recent Contributors** - Who has knowledge of which areas (bus factor)
4. **Risk Areas** - Aggregate assessment for prioritization

### What You'll Discover

| Analysis Type | Insight | Business Value |
|---------------|---------|----------------|
| **Hotspots** | Complexity indicators | Refactoring priorities, technical debt |
| **Coupling** | Hidden dependencies | Architecture review targets |
| **Contributors** | Knowledge distribution | Bus factor risks, training needs |
| **Risk** | Aggregate assessment | Resource allocation decisions |

---

## Core Workflow

Execute these steps in order. See [workflow.md](workflow.md) for complete details.

### Step 0: Check Prerequisites (30 seconds)

**Purpose:** Ensure code-maat is installed and Java is available.

**Check code-maat:**
```bash
if [ -f "$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar" ]; then
  export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
fi
```

**If not found, use AskUserQuestion:**
- "code-maat required for analysis. Install now? (requires Java 8+)"
- If yes → run `./scripts/install-codemaat.sh`
- If no → show manual installation steps

→ See [workflow.md#step-0](workflow.md#step-0-check-prerequisites-30-seconds)

### Step 1: Generate Git Log (1 minute)

**Purpose:** Create code-maat compatible git log file.

**Default: Last 12 months**
```bash
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    --after="$(date -v-12m +%Y-%m-%d)" \
    > /tmp/git-history.log
```

**If scope specified:** Filter to directory (e.g., "src/")

→ See [workflow.md#step-1](workflow.md#step-1-generate-git-log-1-minute)

### Step 2: Hotspot Analysis (2 minutes)

**Purpose:** Identify frequently changed files.

**Run code-maat revisions:**
```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a revisions
```

**Calculate complexity scores:** LOC × Revisions

**Identify top 10 hotspots** sorted by complexity

→ See [workflow.md#step-2](workflow.md#step-2-hotspot-analysis-2-minutes)

### Step 3: Temporal Coupling Analysis (2 minutes)

**Purpose:** Find files that change together.

**Run code-maat coupling:**
```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a coupling
```

**Filter significant couplings:** degree ≥ 0.5

**Categorize:** Expected vs Suspicious

→ See [workflow.md#step-3](workflow.md#step-3-temporal-coupling-analysis-2-minutes)

### Step 4: Recent Contributors Analysis (2 minutes)

**Purpose:** Map knowledge distribution across modules.

**Run code-maat entity-ownership:**
```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a entity-ownership
```

**Generate knowledge map** by area (src/api/, src/core/, etc.)

**Identify bus factor risks:** Single-contributor modules

→ See [workflow.md#step-4](workflow.md#step-4-recent-contributors-analysis-2-minutes)

### Step 5: Risk Assessment (1 minute)

**Purpose:** Combine all dimensions into actionable priorities.

**Calculate composite risk:** (Revisions × Coupling_Count) / Contributor_Count

**Risk categories:**
- Bus Factor Risk
- Complexity Risk
- Coupling Risk
- Testing Gap Risk

→ See [workflow.md#step-5](workflow.md#step-5-risk-assessment-1-minute)

---

## Output Format

Your analysis should follow this Markdown structure:

```markdown
🗺️ SourceAtlas: History
───────────────────────────────
📜 [repo name] │ [N] months

**Analysis Period**: [start] → [end]
**Commits Analyzed**: [count]
**Files Analyzed**: [count]

## 1. Hotspots (Top 10)
[Table with Rank, File, Changes, LOC, Complexity Score]
[Insights paragraph]

## 2. Temporal Coupling (Significant Pairs)
[Table with File A, File B, Coupling, Co-changes]
[Expected vs Suspicious coupling analysis]

## 3. Recent Contributors (Knowledge Map)
[Per-area tables with Contributor, Commits, Last Active]
[Bus Factor Risks section]

## 4. Risk Summary
[Risk aggregation table]
[Priority Actions numbered list]

## 5. Recommendations
[Refactoring candidates, knowledge sharing, architecture review]

## Recommended Next
[Dynamic suggestions based on findings]
```

→ See [output-template.md](output-template.md) for complete specification and examples

---

## Critical Rules

### 1. Privacy Aware
- Use "Recent Contributors" not "Ownership %"
- Focus on knowledge distribution, not blame
- Frame findings as opportunities, not criticisms

### 2. Actionable Insights
- Every finding must have recommended action
- Reference specific commit counts and file paths
- Provide concrete next steps (not vague suggestions)

### 3. Evidence-Based
- All hotspot files must exist (verify)
- Commit counts must match git history (±20% tolerance)
- Contributor names must be in git log

### 4. Time-Bounded
- Default: 12 months (good balance)
- Minimum: 3 months (for meaningful patterns)
- Maximum: 24 months (avoid ancient history)

### 5. Verification Required
- Execute [verification-guide.md](verification-guide.md) after analysis
- Verify file paths, commit counts, contributors
- Correct discrepancies before output

### 6. Constitutional Compliance
Follow [ANALYSIS_CONSTITUTION.md](../../../ANALYSIS_CONSTITUTION.md):
- **Article I**: Evidence-based (all claims from git/code-maat)
- **Article III**: Verification (run V1-V4 checks)
- **Article IV**: Evidence format (file:line references)
- **Article V**: Transparency (show analysis period, cache age)
- **Article VII**: User Empowerment (actionable recommendations)

---

## Self-Verification

After generating your analysis, execute verification steps:

### Step V1: Extract Verifiable Claims
Parse output for all quantifiable claims:
- File paths (hotspots, coupled files)
- Commit counts (total, per file, per contributor)
- Contributor names
- Coupling pairs
- Date ranges

### Step V2: Parallel Verification
- Verify hotspot files exist (sample 3-5)
- Verify commit counts (±20% tolerance)
- Verify contributors in git history
- Verify coupling pairs (both files exist)
- Verify date ranges within repository history

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
- **Default**: Use cache if exists
- **Force flag**: Skip cache with `--force`
- **Cache location**: `.sourceatlas/history.md` (fixed path)
- **Cache age warning**: If >30 days old

→ See [reference.md#cache-behavior](reference.md#cache-behavior)

### Auto-Save Mechanism
Complete Markdown report auto-saves after verification:
```
💾 Saved to .sourceatlas/history.md
```

→ See [reference.md#auto-save-behavior](reference.md#auto-save-behavior)

### Handoffs to Next Commands
Based on findings, suggest:
- High-risk hotspot → `/sourceatlas:impact "[hotspot]"`
- Suspicious coupling → `/sourceatlas:flow "[entry point]"`
- Refactoring needed → `/sourceatlas:pattern "[pattern]"`

→ See [reference.md#handoffs](reference.md#handoffs)

### code-maat Installation
- Default location: `~/.sourceatlas/bin/code-maat-1.0.4-standalone.jar`
- Auto-install via: `./scripts/install-codemaat.sh`
- Requires: Java 8+

→ See [reference.md#code-maat-installation](reference.md#code-maat-installation)

### Interpretation Guidelines
- Hotspots: Not always bad (core logic changes often)
- Coupling: Expected (same domain) vs Suspicious (cross-module)
- Contributors: Healthy = 2-3 per module, Risk = single contributor

→ See [reference.md#interpretation-guidelines](reference.md#interpretation-guidelines)

---

## Support Files

Detailed documentation available in:

- **[workflow.md](workflow.md)** - Complete Step 0-5 execution guide with bash commands
- **[output-template.md](output-template.md)** - Full Markdown structure and examples
- **[verification-guide.md](verification-guide.md)** - Self-verification steps V1-V4
- **[reference.md](reference.md)** - Cache, code-maat, interpretation, troubleshooting

---

## Output Header

Start your output with:

```markdown
🗺️ SourceAtlas: History
───────────────────────────────
📜 [repo name] │ [N] months
```

Then follow complete structure in [output-template.md](output-template.md).
