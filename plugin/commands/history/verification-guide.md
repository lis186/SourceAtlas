# History Analysis Self-Verification Guide

Complete verification checklist to ensure temporal analysis accuracy.

---

## When to Verify

Execute after completing your history analysis, before outputting final results.

---

## Verification Steps

### Step V1: Extract Verifiable Claims

Parse your analysis output to identify all **quantifiable claims**:

```yaml
verifiable_claims:
  - "500 commits analyzed"
  - "src/core/processor.ts changed 45 times"
  - "Alice made 12 commits to src/api/"
  - "Coupling degree 0.85"
  - "Analysis period: 2024-11-30 → 2025-11-30"
```

**Extract these for verification:**
- File paths (hotspots, coupled files)
- Commit counts (total, per file, per contributor)
- Contributor names
- Date ranges
- Coupling pairs (both files must exist)
- LOC counts

---

### Step V2: Parallel Verification Execution

Run verification commands in **parallel** for speed:

#### V2.1: Verify Hotspot Files Exist

```bash
# Check top 10 hotspot files
for path in "src/core/processor.ts" "src/api/handlers.ts" "config/settings.json"; do
    if [ ! -f "$path" ]; then
        echo "❌ FILE_NOT_FOUND: $path"
    fi
done
```

**Check:**
- ✅ All sampled hotspot file paths exist
- ⚠️ If file not found → Remove from hotspots or find correct path

#### V2.2: Verify Commit Counts

```bash
# Verify total commit count
claimed_total=500
actual_total=$(git rev-list --count HEAD 2>/dev/null)

# Allow ±20% tolerance (git log filters may vary)
min_expected=$((actual_total * 80 / 100))
max_expected=$((actual_total * 120 / 100))

if [ $claimed_total -lt $min_expected ] || [ $claimed_total -gt $max_expected ]; then
    echo "⚠️ COMMIT_COUNT_CHECK: claimed $claimed_total, actual ~$actual_total"
fi

# Verify specific file change count
claimed_revisions=45
actual_revisions=$(git log --oneline -- "src/core/processor.ts" | wc -l)

if [ $((actual_revisions * 80 / 100)) -gt $claimed_revisions ] || [ $((actual_revisions * 120 / 100)) -lt $claimed_revisions ]; then
    echo "⚠️ FILE_REVISION_MISMATCH: claimed $claimed_revisions, actual $actual_revisions"
fi
```

**Check:**
- ✅ Total commit count within ±20% (accounts for filtering differences)
- ✅ Per-file revision counts within ±20%
- ⚠️ If significant difference → Re-run code-maat analysis

#### V2.3: Verify Contributors

```bash
# Verify top contributor exists
claimed_contributor="Alice"
if ! git shortlog -sn --all 2>/dev/null | grep -qi "$claimed_contributor"; then
    echo "❌ CONTRIBUTOR_NOT_FOUND: $claimed_contributor"
fi

# Verify contributor commit count
claimed_commits=12
actual_commits=$(git log --author="$claimed_contributor" --oneline | wc -l)

if [ $((actual_commits / 2)) -gt $claimed_commits ] || [ $((actual_commits * 2)) -lt $claimed_commits ]; then
    echo "⚠️ CONTRIBUTOR_COUNT_MISMATCH: claimed $claimed_commits, actual $actual_commits"
fi
```

**Check:**
- ✅ All mentioned contributors exist in git history
- ✅ Commit counts per contributor are reasonable
- ⚠️ If contributor not found → Check spelling or remove

#### V2.4: Verify Coupling Pairs

```bash
# Verify both files in coupling pair exist
for pair in "src/user/model.ts:src/user/service.ts" "src/api/auth.ts:src/middleware/jwt.ts"; do
    IFS=':' read -r f1 f2 <<< "$pair"
    if [ ! -f "$f1" ]; then
        echo "❌ COUPLING_FILE1_NOT_FOUND: $f1"
    fi
    if [ ! -f "$f2" ]; then
        echo "❌ COUPLING_FILE2_NOT_FOUND: $f2"
    fi
done
```

**Check:**
- ✅ Both files in each coupling pair exist
- ⚠️ If either file not found → Remove coupling pair

#### V2.5: Verify Date Range

```bash
# Verify analysis period matches actual git history
claimed_start="2024-11-30"
claimed_end="2025-11-30"

actual_start=$(git log --reverse --format="%ai" | head -1 | cut -d' ' -f1)
actual_end=$(git log --format="%ai" | head -1 | cut -d' ' -f1)

echo "Claimed: $claimed_start → $claimed_end"
echo "Actual:  $actual_start → $actual_end"
```

**Check:**
- ✅ Start date is within repository history
- ✅ End date is recent (not in future)
- ⚠️ If dates outside actual range → Update analysis period

---

### Step V3: Handle Verification Results

Based on verification outcomes:

#### If All Checks Pass ✅

```yaml
verification_status:
  verified: true
  checks_passed: 5
  confidence: high
```

Proceed to output.

#### If Minor Issues Found ⚠️ (1-2 checks failed)

**Examples:**
- File revision count off by <30%
- Contributor commit count slightly different
- Date range off by a few days

**Action:**
1. Correct the specific claims
2. Re-verify those claims
3. Add note to output:

```yaml
verification_notes:
  - "Commit counts adjusted after verification"
  - "File revision count corrected to [N] (was [M])"
```

#### If Major Issues Found ❌ (3+ checks failed)

**Examples:**
- Multiple hotspot files don't exist
- Contributor names not in git history
- Commit counts off by >50%
- Coupling pairs with non-existent files

**Action:**
1. **STOP** - Do not output current analysis
2. Re-execute Step 1-5 from [workflow.md](workflow.md)
3. Check code-maat installation
4. Verify git log generation
5. Re-run all analyses

---

### Step V4: Verification Summary

Add to final output (before footer):

```yaml
verification_summary:
  timestamp: "[ISO 8601]"
  checks_performed:
    - "Hotspot files: ✅"
    - "Commit counts: ✅"
    - "Contributors: ✅"
    - "Coupling pairs: ✅"
    - "Date ranges: ✅"

  confidence_level: "high"  # high|medium|low
  notes:
    - "[Any corrections made]"
```

**Confidence Level Criteria:**

| Level | Criteria |
|-------|----------|
| **High** | All 5 checks passed, no corrections needed |
| **Medium** | 4/5 checks passed, minor corrections made |
| **Low** | <4 checks passed, significant corrections made |

---

## Verification Examples

### Example 1: Hotspot File Verification

**Claim:** "processor.ts changed 45 times"

**Verification:**
```bash
git log --oneline -- "src/core/processor.ts" | wc -l
# Output: 43
```

**Result:** ⚠️ Minor difference (45 → 43)

**Action:**
- Update analysis: `processor.ts changed 43 times`
- Note: "Revision count verified and adjusted"

---

### Example 2: Contributor Verification

**Claim:** "Alice made 12 commits to src/api/"

**Verification:**
```bash
git log --author="Alice" --oneline -- "src/api/" | wc -l
# Output: 11
```

**Result:** ⚠️ Minor difference (12 → 11)

**Action:**
- Update analysis: "Alice made 11 commits"
- Acceptable within ±1 commit tolerance

---

### Example 3: Coupling Pair Verification

**Claim:** "model.ts ↔ service.ts coupling 0.85"

**Verification:**
```bash
test -f "src/user/model.ts" && echo "✅ File 1 exists"
test -f "src/user/service.ts" && echo "✅ File 2 exists"
```

**Result:** ✅ Both files exist

**Action:** No correction needed

---

### Example 4: Non-existent File

**Claim:** "legacy/old-auth.ts is a hotspot"

**Verification:**
```bash
test -f "legacy/old-auth.ts"
# Exit code: 1 (file not found)
```

**Result:** ❌ File doesn't exist

**Action:**
- Search for similar path: `find . -name "*old-auth*"`
- If found at different path → Update path
- If deleted from codebase → Remove from hotspots entirely
- Note: "File was deleted after analysis period"

---

## Error Recovery

### If Verification Script Fails

```bash
# If git command fails
# → Check if inside git repository
git status > /dev/null 2>&1 || echo "Not a git repository"

# If file not found
# → Use find to locate
find . -name "processor.ts" 2>/dev/null

# If contributor not found
# → List all contributors
git shortlog -sn | head -10
```

### If Commit Count Discrepancy Large (>30%)

**Likely causes:**
1. Git log time filter different from code-maat
2. Branch filtering issues (--all vs single branch)
3. Git history rewritten recently

**Action:**
1. Regenerate git log with explicit date range
2. Verify code-maat ran successfully
3. Check if repository had recent force push

---

## Best Practices

1. **Always verify file paths** - Files may be renamed/deleted after analysis
2. **Sample at least 3 hotspots** - Ensures code-maat output is accurate
3. **Check contributor spelling** - Git author names may have variations
4. **Verify coupling makes sense** - Both files should be in same repository
5. **Note all corrections** - Transparency builds trust

---

## Verification Checklist

Before finalizing output, confirm:

- [ ] All hotspot file paths verified to exist (sample 3-5)
- [ ] Total commit count reasonable (within ±20% of git rev-list --count)
- [ ] Top contributors verified against git shortlog
- [ ] Coupling pairs verified (both files exist)
- [ ] Date ranges within actual repository history
- [ ] LOC counts match current file sizes (use wc -l)
- [ ] No placeholder values like "[N]" or "[file]" in output

---

## Handoff to Next Steps

After verification:
- ✅ If confidence HIGH → Proceed to output
- ⚠️ If confidence MEDIUM → Include verification notes, warn user
- ❌ If confidence LOW → Re-execute entire analysis

See [reference.md#handoffs](reference.md#handoffs) for when to suggest next commands.
