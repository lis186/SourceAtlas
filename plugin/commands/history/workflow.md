# History Analysis Workflow

Complete step-by-step guide for git temporal analysis using code-maat.

---

## Overview

This workflow uses code-maat to analyze git history and extract:
1. **Hotspots** - Frequently changed files (complexity indicators)
2. **Temporal Coupling** - Files that change together (hidden dependencies)
3. **Recent Contributors** - Knowledge distribution (bus factor risks)

**Time Budget**: 5-10 minutes total

---

## Step 0: Check Prerequisites (30 seconds)

### Check code-maat Installation

```bash
# Check if CODEMAAT_JAR is set
if [ -z "$CODEMAAT_JAR" ]; then
    # Check default location
    if [ -f "$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar" ]; then
        export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
        echo "✅ code-maat found at $CODEMAAT_JAR"
    else
        echo "⚠️ code-maat not found."
    fi
fi
```

### If code-maat Not Found

Use **AskUserQuestion** tool:

```yaml
questions:
  - header: "Install Tool"
    question: "code-maat is required for git history analysis. Install now? (requires Java 8+)"
    multiSelect: false
    options:
      - label: "Yes, install"
        description: "Run installation script automatically"
      - label: "No, skip"
        description: "Show manual installation instructions"
```

### If User Agrees to Install

```bash
# Run installation script
./scripts/install-codemaat.sh

# Verify installation
if [ -f "$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar" ]; then
    export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
    echo "✅ code-maat installed successfully!"
else
    echo "❌ Installation failed. Please check Java installation."
    exit 1
fi
```

### Verify code-maat Works

```bash
java -jar "$CODEMAAT_JAR" -h > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ code-maat installation is broken. Please reinstall."
    exit 1
fi
```

### Check Java Installation

```bash
java -version 2>&1 | head -1
```

**If Java not found**, inform user:
```
⚠️ Java 8+ required for code-maat
Install: brew install openjdk@11
```

---

## Step 1: Generate Git Log (1 minute)

### Default: Last 12 Months

```bash
# Generate code-maat compatible git log
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    --after="$(date -v-12m +%Y-%m-%d 2>/dev/null || date -d '12 months ago' +%Y-%m-%d)" \
    > /tmp/git-history.log

# Count commits and files
COMMIT_COUNT=$(grep -c "^--" /tmp/git-history.log)
FILE_COUNT=$(awk 'NF==3 && $1 ~ /^[0-9]+$/' /tmp/git-history.log | cut -f3 | sort -u | wc -l)

echo "📊 Analyzed: $COMMIT_COUNT commits, $FILE_COUNT unique files"
```

### If Scope Specified

If user provides scope (e.g., "src/", "frontend"):

```bash
# Filter to specific directory
SCOPE="src/"
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    --after="$(date -v-12m +%Y-%m-%d)" \
    -- "$SCOPE" > /tmp/git-history.log
```

### Custom Time Range

If user specifies time range (e.g., "last 6 months"):

```bash
# Parse time range
MONTHS=6
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    --after="$(date -v-${MONTHS}m +%Y-%m-%d)" \
    > /tmp/git-history.log
```

### Validate Log Size

```bash
# Check if history is sufficient
if [ $COMMIT_COUNT -lt 50 ]; then
    echo "⚠️ Only $COMMIT_COUNT commits found"
    echo "Temporal analysis works best with >50 commits"
fi
```

---

## Step 2: Hotspot Analysis (2 minutes)

### Run Revisions Analysis

```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a revisions \
    2>/dev/null > /tmp/revisions.csv
```

**Output format:**
```
entity,n-revs
src/core/processor.ts,45
src/api/handlers.ts,38
...
```

### Identify Top 10 Hotspots

```bash
# Sort by revision count descending
cat /tmp/revisions.csv | tail -n +2 | sort -t, -k2 -nr | head -10 > /tmp/hotspots.csv
```

### Calculate Complexity Scores

For each hotspot, calculate: **LOC × Revisions**

```bash
while IFS=, read -r file revs; do
    if [ -f "$file" ]; then
        LOC=$(wc -l < "$file" 2>/dev/null || echo 0)
        COMPLEXITY=$((LOC * revs))
        echo "$file,$revs,$LOC,$COMPLEXITY"
    fi
done < /tmp/hotspots.csv > /tmp/hotspots-with-loc.csv
```

### Interpret Hotspots

**High complexity score (>10,000)**:
- Indicates frequently changed, large files
- Potential technical debt
- Refactoring candidates

**High revision count, low LOC**:
- Configuration files (normal)
- Small utility files (normal)

**Low revision count, high LOC**:
- Stable, mature code
- May need modernization

---

## Step 3: Temporal Coupling Analysis (2 minutes)

### Run Coupling Analysis

```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a coupling \
    2>/dev/null > /tmp/coupling.csv
```

**Output format:**
```
entity,coupled,degree,average-revs
src/user/model.ts,src/user/service.ts,0.85,23
src/api/auth.ts,src/middleware/jwt.ts,0.72,18
...
```

### Filter Significant Couplings

```bash
# Filter coupling degree >= 0.5
awk -F, 'NR>1 && $3 >= 0.5' /tmp/coupling.csv | \
    sort -t, -k3 -nr | \
    head -20 > /tmp/significant-coupling.csv
```

### Categorize Couplings

**Expected Couplings** (normal):
- Model ↔ Service (same domain)
- Test ↔ Production code
- Component ↔ Component styles

**Suspicious Couplings** (review needed):
- Cross-layer: Controller ↔ View
- Cross-module: User ↔ Payment
- Backend ↔ Frontend

### Interpret Coupling Degrees

| Degree | Meaning | Action |
|--------|---------|--------|
| 0.9-1.0 | Always change together | Consider merging files |
| 0.7-0.9 | Very strong coupling | Review dependency |
| 0.5-0.7 | Moderate coupling | Monitor |
| <0.5 | Weak coupling | Normal |

---

## Step 4: Recent Contributors Analysis (2 minutes)

### Run Entity Ownership Analysis

```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a entity-ownership \
    2>/dev/null > /tmp/ownership.csv
```

**Output format:**
```
entity,author,added,deleted
src/api/handlers.ts,Alice,234,45
src/api/handlers.ts,Bob,89,12
...
```

### Generate Knowledge Map by Area

```bash
# Most recent commits per area
for area in "src/api/" "src/core/" "src/components/"; do
    echo "=== $area ==="
    git log --pretty=format:'%an|%ad|%s' --date=short -- "$area" | head -5
done
```

### Identify Bus Factor Risks

```bash
# Files with single contributor in last 6 months
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    --after="$(date -v-6m +%Y-%m-%d)" \
    > /tmp/recent-6m.log

java -jar "$CODEMAAT_JAR" -l /tmp/recent-6m.log -c git2 -a entity-ownership \
    2>/dev/null | awk -F, 'NR>1 {count[$1]++} END {for (f in count) if (count[f]==1) print f}'
```

**High bus factor risk**:
- Only 1 contributor in last 6 months
- Primary contributor no longer active
- Critical files with concentrated knowledge

---

## Step 5: Risk Assessment (1 minute)

### Calculate Composite Risk Scores

Combine multiple dimensions:

```bash
# Risk = (Revisions × Coupling_Count) / Contributor_Count

# Example: processor.ts
# - 45 revisions
# - Coupled with 3 other files
# - 2 contributors
# Risk = (45 × 3) / 2 = 67.5 (HIGH)
```

### Risk Categories

**1. Bus Factor Risk**
- Single contributor files
- No recent activity (>6 months)
- Critical path files

**2. Complexity Risk**
- High revision count (>30 in 12 months)
- High LOC (>500 lines)
- Complexity score >10,000

**3. Coupling Risk**
- Coupled with >5 files
- Cross-module coupling (suspicious)
- High coupling degree (>0.8)

**4. Testing Gap Risk**
- Hotspot without test file
- Test file change frequency < 20% of production changes

### Priority Ranking

```
🔴 HIGH RISK:
- Bus factor + Complexity + No tests

🟡 MEDIUM RISK:
- Coupling risk + High revisions

🟢 LOW RISK:
- High revisions but well-tested
- Multiple contributors
```

---

## Error Handling

### Issue: Git History Too Short

```bash
if [ $COMMIT_COUNT -lt 50 ]; then
    echo "⚠️ Only $COMMIT_COUNT commits found"
    echo ""
    echo "Temporal analysis works best with >50 commits."
    echo ""
    echo "Consider:"
    echo "- Extending time range"
    echo "- Analyzing entire repository history"
    exit 0
fi
```

### Issue: No Significant Patterns

If all couplings < 0.5 and hotspots < 10 revisions:

```
✅ No significant temporal patterns detected.

This could mean:
- Clean architecture with good separation
- Young codebase with limited history
- Inconsistent commit practices (large commits)
```

### Issue: code-maat Fails

```bash
if ! java -jar "$CODEMAAT_JAR" -h > /dev/null 2>&1; then
    echo "❌ code-maat failed to run"
    echo ""
    echo "Possible causes:"
    echo "1. Java not installed (brew install openjdk@11)"
    echo "2. JAR file corrupted (re-run install script)"
    echo "3. Incompatible Java version (need Java 8+)"
    exit 1
fi
```

---

## Output Generation Tips

### Hotspot Table

```markdown
| Rank | File | Changes | LOC | Complexity Score |
|------|------|---------|-----|------------------|
| 1 | src/core/processor.ts | 45 | 892 | 40,140 |
```

**Insights**:
- Reference specific complexity scores
- Mention if file lacks tests
- Suggest concrete actions (refactor, document, test)

### Coupling Table

```markdown
| File A | File B | Coupling | Co-changes |
|--------|--------|----------|------------|
| src/user/model.ts | src/user/service.ts | 0.85 | 23 |
```

**Insights**:
- Distinguish expected vs suspicious coupling
- Reference architectural concerns
- Note if cross-layer or cross-module

### Knowledge Map

```markdown
### src/api/
| Contributor | Recent Commits | Last Active |
|-------------|----------------|-------------|
| Alice | 12 | 2025-11-28 |
```

**Insights**:
- Highlight bus factor risks
- Note inactive contributors
- Suggest knowledge transfer actions

---

## Performance Optimization

### For Large Repositories

```bash
# Limit git log to avoid timeout
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    --after="$(date -v-6m +%Y-%m-%d)" \
    --max-count=1000 \
    > /tmp/git-history.log
```

### For Monorepos

```bash
# Analyze specific module only
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    -- "packages/app/" \
    > /tmp/git-history.log
```

---

## Integration with Other Commands

After history analysis, suggest:
- **High-risk hotspot found** → `/sourceatlas:impact "[hotspot]"`
- **Suspicious coupling** → `/sourceatlas:flow "[entry point]"`
- **Need refactoring guidance** → `/sourceatlas:pattern "[pattern]"`
