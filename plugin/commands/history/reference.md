# History Analysis Reference

Advanced features, caching behavior, and best practices.

---

## Cache Behavior

### When Cache is Used

```bash
# Default: Use cache if exists and fresh
/sourceatlas:history

# Check logic:
if [ -f ".sourceatlas/history.md" ]; then
  age_days=$(calculate_age_in_days)
  if [ $age_days -eq 0 ]; then
    echo "📁 Loading from cache (today)"
  elif [ $age_days -eq 1 ]; then
    echo "📁 Loading from cache (1 day ago)"
  else
    echo "📁 Loading from cache ($age_days days ago)"
  fi
  # If >30 days, warn user
  if [ $age_days -gt 30 ]; then
    echo "⚠️ Cache is older than 30 days, recommend re-analysis"
  fi
  # Output cached content
  exit 0
fi
```

### When Cache is Skipped

```bash
# Force flag: Always skip cache
/sourceatlas:history --force
# → Executes full analysis even if cache exists

# No cache: First time analysis
# → .sourceatlas/history.md doesn't exist yet
```

### Cache File Naming

Unlike other commands, history has **fixed cache path**:
```bash
# Always the same
.sourceatlas/history.md
```

**Rationale:** History analysis is repository-wide, doesn't vary by target.

---

## Auto-Save Behavior

### File Structure

```
.sourceatlas/
└── history.md              # Fixed filename
```

### Save Timing

Auto-save occurs **immediately after Step V4 verification**:

```yaml
# After verification passes
verification_summary:
  confidence_level: "high"

# Then auto-save
💾 Saved to .sourceatlas/history.md
```

### What Gets Saved

Complete Markdown output including:
- Header with analysis period and counts
- Hotspots table (top 10)
- Temporal coupling table
- Recent contributors knowledge map
- Risk summary
- Recommendations
- Verification summary

**Format:** Full Markdown as specified in [output-template.md](output-template.md)

---

## Handoffs: When to Suggest Next Commands

### After Hotspot Identification

If high-risk hotspots found (complexity >10,000):

**Suggest:**
```
| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:impact "src/core/processor.ts"` | processor.ts changed 45 times, need to understand dependencies |
```

### After Suspicious Coupling Found

If cross-module coupling detected (degree >0.6):

**Suggest:**
```
| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:flow "src/orders/checkout"` | Suspicious coupling with payments, trace execution flow |
```

### After Bus Factor Risk Found

If single-contributor modules identified:

**Suggest:**
```
| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:pattern "legacy patterns"` | Bus factor risk in legacy/, need to understand patterns before knowledge transfer |
```

### When to Stop (No Recommendations)

- **History too short**: <50 commits or <3 months
- **No significant patterns**: All coupling <0.5, all hotspots <10 revisions
- **Analysis depth sufficient**: User already ran 4+ commands

**Output instead:**
```
⚠️ **Insufficient Data Warning**
- Commits: 38 (recommend ≥50)
- Period: 67 days (recommend ≥90 days)

Recommend analyzing temporal patterns again in 3-6 months
```

---

## code-maat Installation

### Default Installation Location

```bash
$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar
```

### Environment Variable

```bash
export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
```

### Installation Script

```bash
./scripts/install-codemaat.sh
```

**What it does:**
1. Creates `~/.sourceatlas/bin/`
2. Downloads code-maat JAR from GitHub releases
3. Sets executable permissions
4. Verifies installation

### Manual Installation

If automatic installation fails:

```bash
# 1. Download from GitHub
wget https://github.com/adamtornhill/code-maat/releases/download/v1.0.4/code-maat-1.0.4-standalone.jar

# 2. Create directory
mkdir -p ~/.sourceatlas/bin/

# 3. Move JAR
mv code-maat-1.0.4-standalone.jar ~/.sourceatlas/bin/

# 4. Set environment variable
export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
```

### Prerequisites

**Java 8+** required:

```bash
# Check Java version
java -version

# Install if missing (macOS)
brew install openjdk@11

# Install if missing (Ubuntu)
sudo apt-get install openjdk-11-jdk
```

---

## Analysis Parameters

### Time Range

**Default: Last 12 months**

```bash
git log --after="$(date -v-12m +%Y-%m-%d)" ...
```

**Custom time range:**

```bash
# Last 6 months
/sourceatlas:history "last 6 months"

# Last 18 months
/sourceatlas:history "last 18 months"
```

**Parsing logic:**
```bash
# Extract number from arguments
MONTHS=$(echo "$ARGUMENTS" | grep -o '[0-9]\+')
if [ -z "$MONTHS" ]; then
  MONTHS=12  # Default
fi
```

### Scope Filtering

**Default: Entire repository**

**Custom scope:**

```bash
# Specific directory
/sourceatlas:history "src/"

# Multiple directories (future enhancement)
/sourceatlas:history "src/ lib/"
```

**Implementation:**
```bash
if [ -n "$SCOPE" ]; then
  git log --all --numstat ... -- "$SCOPE" > /tmp/git-history.log
else
  git log --all --numstat ... > /tmp/git-history.log
fi
```

---

## Interpretation Guidelines

### Hotspots

**Not always bad:**
- Core logic files naturally change often
- Configuration files updated for environments
- Test files should mirror production changes

**Red flags:**
- High complexity score (>10,000)
- Hotspot without corresponding test changes
- Frequent changes without documentation updates

### Temporal Coupling

**Expected (normal):**
- Model ↔ Service (same domain)
- Route ↔ Controller (MVC pattern)
- Component ↔ Component styles
- Test ↔ Production code

**Suspicious (review needed):**
- Cross-layer: API ↔ Database
- Cross-module: User ↔ Payment
- Backend ↔ Frontend (if separated)

### Contributors

**Healthy distribution:**
- 2-3 active contributors per module
- Regular activity (monthly commits)
- Knowledge overlap between contributors

**Bus factor risks:**
- Single contributor (especially if inactive >6 months)
- Primary contributor left team
- No knowledge overlap in critical modules

---

## Performance Optimization

### For Large Repositories (>10K commits)

```bash
# Limit analysis to recent history
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    --after="$(date -v-6m +%Y-%m-%d)" \
    --max-count=1000 \
    > /tmp/git-history.log
```

### For Monorepos

```bash
# Analyze specific package only
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    -- "packages/app/" \
    > /tmp/git-history.log

# Or analyze multiple related packages
git log --all --numstat --date=short \
    --pretty=format:'--%h--%ad--%aN' \
    -- "packages/app/" "packages/shared/" \
    > /tmp/git-history.log
```

### For Slow code-maat Execution

```bash
# Use faster analysis types
# revisions: Fast (seconds)
# coupling: Moderate (seconds to minutes)
# entity-ownership: Slow (minutes)

# Skip entity-ownership if too slow
# Focus on revisions + coupling
```

---

## Edge Cases

### Case 1: No Git History

```bash
# Check if git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a git repository"
    echo "History analysis requires git version control"
    exit 1
fi
```

---

### Case 2: Very Short History (<50 commits)

```yaml
output:
  message: |
    ⚠️ Only 38 commits found in analysis period

    Temporal analysis works best with >50 commits.

    Consider:
    - Extending time range (e.g., --after="2 years ago")
    - Analyzing entire repository history (omit --after)
    - Waiting for more development activity
```

---

### Case 3: Monolithic Commits

If commits are very large (>100 files per commit):

```yaml
warning: |
  Large, infrequent commits detected.

  This may affect coupling analysis accuracy:
  - Many files change together in single commit
  - Hard to distinguish real vs coincidental coupling

  Recommend:
  - Smaller, atomic commits going forward
  - Focus on hotspot analysis (more reliable)
```

---

### Case 4: Multiple Contributors with Same Name

```bash
# If "Alice" appears as:
# - Alice Smith <alice@company.com>
# - Alice Johnson <alice@contractor.com>

# code-maat uses author name only, may merge stats
# Verify in git log:
git log --format='%aN <%aE>' | sort -u | grep -i alice
```

**Action:** If ambiguous, note in output:
```
Note: Multiple contributors with name "Alice" found.
Stats may be aggregated.
```

---

## Constitutional Compliance

### Article I: Evidence-Based Analysis
- ✅ Every hotspot must have actual revision count
- ✅ Coupling degrees from code-maat output
- ✅ Contributor names from git log

### Article II: Directory Exclusions
- ✅ Git log naturally excludes untracked files
- ✅ code-maat processes committed files only

### Article III: Verification Required
- ✅ Execute [verification-guide.md](verification-guide.md) before output
- ✅ Re-verify after corrections

### Article IV: Evidence Format
- ✅ Use `file:line` for hotspots
- ✅ Reference commit hashes where relevant
- ✅ Include coupling degrees in output

### Article V: Transparency
- ✅ Show cache age: "Loading from cache (2 days ago)"
- ✅ Show analysis period explicitly
- ✅ Note if history insufficient

### Article VI: Scale Awareness
- ✅ Limit analysis to 12 months by default
- ✅ Cap hotspot list to top 10
- ✅ Filter coupling to degree ≥0.5

### Article VII: User Empowerment
- ✅ Provide actionable recommendations
- ✅ Suggest next commands based on findings
- ✅ Include priority actions in risk summary

---

## Related Commands

After history analysis, consider:

- **`/sourceatlas:impact "[hotspot]"`** - Understand dependencies of frequently changed files
- **`/sourceatlas:pattern "[pattern]"`** - Learn patterns used in hotspots before refactoring
- **`/sourceatlas:flow "[entry point]"`** - Trace execution through coupled modules
- **`/sourceatlas:overview`** - Get broader context if history reveals complexity

---

## Troubleshooting

### Issue: code-maat Not Found

**Symptom:** `CODEMAAT_JAR not set` or `file not found`

**Debug:**
```bash
# Check environment
echo $CODEMAAT_JAR

# Check default location
ls -la ~/.sourceatlas/bin/code-maat-*.jar

# Verify Java
java -version
```

**Fix:** Run installation script or set environment variable

---

### Issue: Empty Git Log

**Symptom:** `0 commits found`

**Debug:**
```bash
# Check git repository
git log --oneline | head -5

# Check date filter
date -v-12m +%Y-%m-%d  # macOS
date -d '12 months ago' +%Y-%m-%d  # Linux
```

**Fix:** Adjust date range or check if repository has history

---

### Issue: code-maat Fails

**Symptom:** `Exception in thread "main"` or Java errors

**Debug:**
```bash
# Test code-maat directly
java -jar "$CODEMAAT_JAR" -h

# Check git log format
head -20 /tmp/git-history.log
```

**Fix:**
- Verify Java version (need 8+)
- Regenerate git log with correct format
- Re-download code-maat JAR if corrupted

---

### Issue: No Significant Patterns

**Symptom:** All couplings <0.3, all hotspots <5 revisions

**Possible causes:**
1. Very stable codebase (good!)
2. Short history period
3. Large, infrequent commits hiding patterns

**Action:**
```
✅ No significant temporal patterns detected.

This could mean:
- Clean architecture with good separation
- Young codebase with limited history
- Stable, mature codebase

Consider re-analyzing after more development activity.
```

---

## Best Practices

1. **Run quarterly** - Temporal patterns evolve over time
2. **Compare with previous runs** - Track if hotspots are growing
3. **Act on bus factor risks** - Document before knowledge is lost
4. **Review coupling trends** - Monitor if architecture is degrading
5. **Cross-reference with static analysis** - Combine history + impact for complete picture
