---
description: Smart temporal analysis using git history - Hotspots, Coupling, and Recent Contributors
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write
argument-hint: (optional) [path or scope, e.g., "src/", "frontend", "last 6 months"] [--save] [--force]
---

# SourceAtlas: Smart Temporal Analysis (Git History)

> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../ANALYSIS_CONSTITUTION.md) v1.0
>
> Key principles enforced:
> - Article II: Mandatory directory exclusions (git log filtering)
> - Article IV: Evidence format (commit hash, file:line references)
> - Article V: Output format (Markdown reports)
> - Article VI: Scale awareness (limit analysis scope for large projects)

## Context

**Analysis Scope:** $ARGUMENTS (default: entire repository)

**Goal:** Provide actionable insights from git history to help developers understand:
1. **Hotspots** - Files changed most frequently (likely complex/risky)
2. **Temporal Coupling** - Files that change together (hidden dependencies)
3. **Recent Contributors** - Who has knowledge of which areas

**Time Limit:** Complete in 5-10 minutes.

**Prerequisite:** code-maat must be installed. If not found, **ask user permission** before installing.

---

## Cache Check (Highest Priority)

**If `--force` is NOT in arguments**, check cache first:

1. Cache path is fixed: `.sourceatlas/history.md`
2. Check cache:
   ```bash
   ls -la .sourceatlas/history.md 2>/dev/null
   ```

3. **If cache exists**:
   - Calculate days since creation
   - Use Read tool to load cache content
   - Output:
     ```
     📁 Loading cache: .sourceatlas/history.md (N days ago)
     💡 To re-analyze, add --force
     ```
   - **If over 30 days old**, additionally display:
     ```
     ⚠️ Cache is over 30 days old, recommend re-analysis
     ```
   - Then output:
     ```
     ---
     [Cache content]
     ```
   - **END - do not execute subsequent analysis**

4. **If cache does not exist**: Continue with analysis workflow below

**If `--force` is in arguments**: Skip cache check, execute analysis directly

---

## Your Task

You are **SourceAtlas History Analyzer**, specialized in extracting insights from git commit history using code-maat.

Help the user understand:
1. Which files are "hotspots" (frequently changed, likely complex)
2. Which files have hidden temporal coupling (change together)
3. Who has recent knowledge of different areas
4. Risk areas that need attention

---

## Workflow

### Step 0: Check Prerequisites (30 seconds)

**Check code-maat installation**:

```bash
# Check if CODEMAAT_JAR is set
if [ -z "$CODEMAAT_JAR" ]; then
    # Check default location
    if [ -f "$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar" ]; then
        export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
        echo "code-maat found at $CODEMAAT_JAR"
    else
        echo "code-maat not found."
    fi
fi
```

**If code-maat not found:**

Use **AskUserQuestion** tool to ask user:
- Question: "code-maat is required for git history analysis. Install now? (requires Java 8+)"
- Options:
  1. "Yes, install" - Run `./scripts/install-codemaat.sh` then continue
  2. "No, skip" - Stop and explain manual installation steps

**If user agrees to install:**
```bash
# Run installation script
./scripts/install-codemaat.sh

# Verify installation
if [ -f "$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar" ]; then
    export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
    echo "code-maat installed successfully!"
else
    echo "Installation failed. Please check Java installation and try again."
    exit 1
fi
```

**Verify it works**:
```bash
java -jar "$CODEMAAT_JAR" -h > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "code-maat installation is broken. Please reinstall."
    exit 1
fi
```

**Check Java**:
```bash
java -version 2>&1 | head -1
```

If Java not found, inform user to install Java 8+ first (brew install openjdk@11).

---

### Step 1: Generate Git Log (1 minute)

**Generate code-maat compatible git log**:

```bash
# Default: last 12 months of history
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    --after="$(date -v-12m +%Y-%m-%d 2>/dev/null || date -d '12 months ago' +%Y-%m-%d)" \
    > /tmp/git-history.log

# Count commits and files
COMMIT_COUNT=$(grep -c "^--" /tmp/git-history.log)
FILE_COUNT=$(awk 'NF==3 && $1 ~ /^[0-9]+$/' /tmp/git-history.log | cut -f3 | sort -u | wc -l)

echo "Analyzed: $COMMIT_COUNT commits, $FILE_COUNT unique files"
```

**If scope is specified** (e.g., "src/"):
```bash
# Filter to specific directory
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    --after="$(date -v-12m +%Y-%m-%d)" \
    -- "$SCOPE" > /tmp/git-history.log
```

---

### Step 2: Hotspot Analysis (2 minutes)

**Run code-maat revisions analysis**:

```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a revisions \
    2>/dev/null | head -30
```

**Output interpretation**:
- `entity` = file path
- `n-revs` = number of times changed
- Higher revision count = potential hotspot

**Identify top 10 hotspots**:
```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a revisions \
    2>/dev/null | tail -n +2 | sort -t, -k2 -nr | head -10
```

**Calculate complexity indicator** (LOC * revisions):
```bash
# For each hotspot, get current LOC
for file in $(cat hotspots.csv | tail -n +2 | cut -d, -f1 | head -10); do
    if [ -f "$file" ]; then
        LOC=$(wc -l < "$file")
        echo "$file,$LOC"
    fi
done
```

---

### Step 3: Temporal Coupling Analysis (2 minutes)

**Run code-maat coupling analysis**:

```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a coupling \
    2>/dev/null | head -30
```

**Output interpretation**:
- `entity` = file pair
- `coupled` = other file
- `degree` = coupling strength (0.0-1.0)
- `average-revs` = average revisions together

**Filter significant couplings** (degree > 0.5):
```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a coupling \
    2>/dev/null | awk -F, 'NR>1 && $3 >= 0.5' | head -20
```

**Identify suspicious couplings**:
- Cross-layer coupling (e.g., controller ↔ view)
- Cross-module coupling (e.g., user ↔ payment)
- Test ↔ Production coupling (normal)

---

### Step 4: Recent Contributors Analysis (2 minutes)

**Run code-maat author analysis**:

```bash
# Author summary per entity
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a entity-ownership \
    2>/dev/null | head -30
```

**Output interpretation**:
- `entity` = file path
- `author` = contributor name
- `added` = lines added
- `deleted` = lines deleted

**Generate knowledge map**:
```bash
# Most recent commits per area
git log --pretty=format:'%an|%ad|%s' --date=short -- "src/api/" | head -10
git log --pretty=format:'%an|%ad|%s' --date=short -- "src/components/" | head -10
```

**Identify knowledge concentration**:
- Files with single contributor = bus factor risk
- Files with many contributors = coordination overhead
- Recent activity = current knowledge

---

### Step 5: Risk Assessment (1 minute)

**Calculate risk scores**:

```bash
# Combine hotspot + coupling + ownership
# Risk = (revisions * coupling_count) / contributor_count

# High risk indicators:
# - Hotspot + Low contributor count = Knowledge concentration
# - Hotspot + High coupling = Fragile code
# - Frequent changes + No tests = Testing gap
```

**Risk categories**:
- **Bus Factor Risk**: Files with single recent contributor
- **Complexity Risk**: High revision count + high LOC
- **Coupling Risk**: High temporal coupling across modules
- **Testing Gap**: Hotspots without corresponding test file changes

---

## Output Format

```markdown
🗺️ SourceAtlas: History
───────────────────────────────
📜 [repo name] │ [N] months

**Analysis Period**: [date range]
**Commits Analyzed**: [count]
**Files Analyzed**: [count]

---

## 1. Hotspots (Top 10)

Files changed most frequently - likely complex or frequently enhanced:

| Rank | File | Changes | LOC | Complexity Score |
|------|------|---------|-----|------------------|
| 1 | src/core/processor.ts | 45 | 892 | 40,140 |
| 2 | src/api/handlers.ts | 38 | 456 | 17,328 |
| ... | ... | ... | ... | ... |

**Insights**:
- Hotspot #1: `processor.ts` has been modified in 45 commits
  - Consider refactoring into smaller modules
  - High complexity score indicates potential technical debt

---

## 2. Temporal Coupling (Significant Pairs)

Files that frequently change together - may indicate hidden dependencies:

| File A | File B | Coupling | Co-changes |
|--------|--------|----------|------------|
| src/user/model.ts | src/user/service.ts | 0.85 | 23 |
| src/api/auth.ts | src/middleware/jwt.ts | 0.72 | 18 |
| ... | ... | ... | ... |

**Insights**:
- **Expected coupling**: model ↔ service (same domain)
- **Suspicious coupling**: None found (good separation)
- **Consider**: Extracting shared logic if coupling > 0.8

---

## 3. Recent Contributors (Knowledge Map)

Who has recent knowledge of each area:

### src/api/
| Contributor | Recent Commits | Last Active |
|-------------|----------------|-------------|
| Alice | 12 | 2025-11-28 |
| Bob | 8 | 2025-11-25 |

### src/core/
| Contributor | Recent Commits | Last Active |
|-------------|----------------|-------------|
| Charlie | 15 | 2025-11-29 |
| Alice | 3 | 2025-11-20 |

**Bus Factor Risks**:
- `src/legacy/` - Only 1 contributor in last 6 months
- `src/payments/` - Primary contributor left 3 months ago

---

## 4. Risk Summary

| Risk Type | Count | Top Files |
|-----------|-------|-----------|
| Bus Factor | 3 | legacy/*, payments/gateway.ts |
| High Complexity | 2 | core/processor.ts, api/handlers.ts |
| Suspicious Coupling | 1 | user/model.ts ↔ billing/invoice.ts |

**Priority Actions**:
1. Document `legacy/*` before knowledge is lost
2. Add tests for `processor.ts` (hotspot without test changes)
3. Review coupling between user and billing modules

---

## 5. Recommendations

Based on temporal analysis:

1. **Refactoring Candidates**:
   - `processor.ts` - High change frequency suggests unstable design
   - Consider extracting into Strategy or Plugin pattern

2. **Knowledge Sharing**:
   - Schedule knowledge transfer for `payments/` module
   - Pair programming on `legacy/` code

3. **Architecture Review**:
   - Investigate user ↔ billing coupling
   - May indicate missing abstraction layer

---

## Recommended Next

Based on analysis findings, dynamically suggest 1-2 most relevant follow-up commands:

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:impact "[hotspot file]"` | [hotspot file] changed N times, need to understand dependencies |
| 2 | `/sourceatlas:pattern "[pattern]"` | Hotspot involves this pattern, need to understand implementation conventions |

💡 Enter a number (e.g., `1`) or copy the command to execute

───────────────────────────────
🗺️ v2.10.1 │ Constitution v1.1
```

---

## Critical Rules

1. **Privacy Aware**: Use "Recent Contributors" not "Ownership %" to avoid political issues
2. **Actionable Insights**: Every finding should have a recommended action
3. **Evidence-Based**: Reference specific commit counts and file paths
4. **Time-Bounded**: Focus on recent history (default: 12 months)
5. **Cross-Tool Portable**: Zero parameters for basic usage (Cursor, Copilot compatible)

---

## Error Handling

**If code-maat not installed**:
- Use AskUserQuestion to ask permission before installing
- If user agrees: run `./scripts/install-codemaat.sh` automatically
- If user declines: provide manual installation steps:
  ```
  1. Download from https://github.com/adamtornhill/code-maat/releases
  2. Place JAR in ~/.sourceatlas/bin/
  3. Or set CODEMAAT_JAR environment variable
  ```

**If git history too short**:
```
Only [N] commits found. Temporal analysis works best with >50 commits.

Consider:
- Extending time range
- Analyzing entire repository history
```

**If no significant patterns found**:
```
No significant temporal patterns detected.

This could mean:
- Clean architecture with good separation
- Young codebase with limited history
- Inconsistent commit practices (large commits)
```

---

## Tips for Interpretation

- **Hotspots** are not always bad - core logic files naturally change often
- **Coupling** between same-domain files is expected (model ↔ service)
- **Single contributor** is only a risk if they're unavailable
- **Compare with tests** - hotspots should have corresponding test activity

---

## Handoffs Decision Rules

> Follows **Constitution Article VII: Handoffs Principles**

### Termination vs Recommendation (Mutually Exclusive)

**⚠️ Important: The following two outputs are mutually exclusive - choose only one**

**Case A - Termination (Omit Recommended Next)**:
When any of the following conditions are met, **only output termination/warning message, do not output table**:
- History too short: <50 commits or <3 months, insufficient data
- Findings too vague: Cannot provide high-confidence (>0.7) specific parameters
- Analysis depth sufficient: Already executed 4+ commands

When history is too short, output:
```markdown
⚠️ **Insufficient Data Warning**
- Commits: N (recommend ≥50)
- Period: M days (recommend ≥90 days)

Recommend analyzing temporal patterns again in 3-6 months
```

**Case B - Recommendation (Output Recommended Next Table)**:
When there are clear findings (hotspots, coupling, risks), **only output table, do not output termination message**.

### Recommendation Selection (Applicable to Case B)

| Finding | Recommended Command | Parameter Source |
|---------|---------------------|------------------|
| High-risk hotspot | `/sourceatlas:impact` | Hotspot file name |
| Suspicious coupling | `/sourceatlas:flow` | Coupled module entry point |
| Hotspot needs refactoring | `/sourceatlas:pattern` | Related pattern |
| Need broader context | `/sourceatlas:overview` | No parameters needed |

### Output Format (Section 7.3)

Use numbered table for quick selection.

### Quality Requirements (Section 7.4-7.5)

- **Specific parameters**: Use actual discovered file names
- **Quantity limit**: 1-2 recommendations, no need to force-fill
- **Purpose field**: Reference specific findings (change count, coupling degree, contributor count)

---

## Integration with Other Commands

This command complements `/sourceatlas:impact` (static analysis) with temporal insights.

---

## Self-Verification Phase (REQUIRED)

> **Purpose**: Prevent hallucinated file paths, incorrect commit counts, and fictional contributor data from appearing in output.
> This phase runs AFTER output generation, BEFORE save.

### Step V1: Extract Verifiable Claims

After generating the history analysis output, extract all verifiable claims:

**Claim Types to Extract:**

| Type | Pattern | Verification Method |
|------|---------|---------------------|
| **File Path** | Hotspot files, coupled files | `test -f path` |
| **Commit Count** | "500 commits", "changed 120 times" | `git log --oneline \| wc -l` |
| **Contributor** | Author names, counts | `git shortlog -sn \| head` |
| **Date Range** | "since 2023", "last 6 months" | `git log --format="%ai" \| head/tail` |
| **Coupling Pair** | "A.ts ↔ B.ts (85%)" | Verify both files exist |

### Step V2: Parallel Verification Execution

Run **ALL** verification checks in parallel:

```bash
# Execute all verifications in a single parallel block

# 1. Verify hotspot files exist
for path in "src/core/service.ts" "lib/utils.py"; do
    if [ ! -f "$path" ]; then
        echo "❌ FILE_NOT_FOUND: $path"
    fi
done

# 2. Verify commit count is reasonable
claimed_total=500
actual_total=$(git rev-list --count HEAD 2>/dev/null)
if [ $((actual_total * 80 / 100)) -gt $claimed_total ] || [ $((actual_total * 120 / 100)) -lt $claimed_total ]; then
    echo "⚠️ COMMIT_COUNT_CHECK: claimed $claimed_total, actual $actual_total"
fi

# 3. Verify top contributor exists
claimed_contributor="bep"
if ! git shortlog -sn --all 2>/dev/null | grep -q "$claimed_contributor"; then
    echo "❌ CONTRIBUTOR_NOT_FOUND: $claimed_contributor"
fi

# 4. Verify coupling pairs
for pair in "file1.ts:file2.ts"; do
    IFS=':' read -r f1 f2 <<< "$pair"
    if [ ! -f "$f1" ] || [ ! -f "$f2" ]; then
        echo "❌ COUPLING_PAIR_INVALID: $f1 ↔ $f2"
    fi
done
```

### Step V3: Handle Verification Results

**If ALL checks pass:**
- Continue to output/save

**If ANY check fails:**
1. **DO NOT output the uncorrected analysis**
2. Fix each failed claim:
   - `FILE_NOT_FOUND` → Search for correct path or remove from hotspots
   - `COMMIT_COUNT_CHECK` → Update with actual count from git
   - `CONTRIBUTOR_NOT_FOUND` → Verify spelling or remove
   - `COUPLING_PAIR_INVALID` → Remove invalid coupling pairs
3. Re-generate affected sections with corrected information
4. Re-run verification on corrected sections

### Step V4: Verification Summary (Append to Output)

Add to footer (before `🗺️ v2.10.1 │ Constitution v1.1`):

**If all verifications passed:**
```
✅ Verified: [N] hotspot files, [M] contributors, commit counts
```

**If corrections were made:**
```
🔧 Self-corrected: [list specific corrections made]
✅ Verified: [N] hotspot files, [M] contributors, commit counts
```

### Verification Checklist

Before finalizing output, confirm:
- [ ] All hotspot file paths verified to exist
- [ ] Commit counts verified against `git rev-list --count`
- [ ] Top contributors verified against `git shortlog`
- [ ] Coupling pairs verified (both files exist)
- [ ] Date ranges verified against actual git history

---

## Save Mode (--save)

If `--save` is present in `$ARGUMENTS`:

### Step 1: Create directory

```bash
mkdir -p .sourceatlas
```

### Step 2: Save output

After generating the complete analysis, save the **entire output** (from `🗺️ SourceAtlas: History` to the end) to `.sourceatlas/history.md`

### Step 3: Confirm

Add at the very end:
```
💾 Saved to .sourceatlas/history.md
```
