# Overview Self-Verification Guide

Complete verification checklist for Stage 0 fingerprint analysis.

---

## When to Verify

Execute **after generating YAML output, before saving** to `.sourceatlas/overview.yaml`.

---

## Purpose

Prevent hallucinated file paths, incorrect counts, and fictional configurations from appearing in output.

---

## Verification Steps

### Step V1: Extract Verifiable Claims

After generating the YAML output, extract all verifiable claims.

**Claim Types to Extract:**

| Type | YAML Path | Verification Method |
|------|-----------|---------------------|
| **File Path** | `scanned_files[].file` | `test -f path` |
| **Directory** | Architecture mentions | `test -d path` |
| **File Count** | `metadata.total_files`, `metadata.scanned_files` | `find . -type f \| wc -l` |
| **Config File** | `hypotheses.ai_collaboration.tools_detected[].config_file` | `test -f config_file` |
| **Git Branch** | `metadata.context.git_branch` | `git branch --show-current` |
| **Evidence** | `hypotheses.*.evidence` | Verify file:line exists |

**Example extraction:**
```yaml
# From generated YAML:
scanned_files:
  - file: "README.md"  # ✅ Verify
  - file: "package.json"  # ✅ Verify
  - file: "CLAUDE.md"  # ✅ Verify

metadata:
  total_files: 127  # ✅ Verify ±10%
  scanned_files: 8  # ✅ Verify exact
  context:
    git_branch: "main"  # ✅ Verify

hypotheses:
  ai_collaboration:
    tools_detected:
      - config_file: "CLAUDE.md"  # ✅ Verify
      - config_file: ".cursorrules"  # ✅ Verify
```

---

### Step V2: Parallel Verification Execution

Run **ALL** verification checks in parallel for speed.

#### V2.1: Verify Scanned Files

```bash
# Check all scanned_files entries exist
for path in "README.md" "package.json" "CLAUDE.md" "src/app.ts"; do
    if [ ! -f "$path" ]; then
        echo "❌ FILE_NOT_FOUND: $path"
    fi
done
```

**Check:**
- ✅ All `scanned_files[].file` entries exist
- ⚠️ If file not found → Remove from scanned_files or find correct path

#### V2.2: Verify AI Tool Config Files

```bash
# Check all AI tool config files
for config in "CLAUDE.md" ".cursorrules" ".github/copilot-instructions.md"; do
    if [ ! -f "$config" ] && [ ! -d "$config" ]; then
        echo "❌ CONFIG_NOT_FOUND: $config"
    fi
done
```

**Check:**
- ✅ All `tools_detected[].config_file` entries exist
- ⚠️ If config not found → Remove from tools_detected

#### V2.3: Verify File Count

```bash
# Verify total_files count is reasonable
claimed_count=127
actual_count=$(find . -type f \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/.venv/*" \
    -not -path "*/vendor/*" \
    -not -path "*/__pycache__/*" \
    2>/dev/null | wc -l | tr -d ' ')

# Allow 10% variance for dynamic counts
lower_bound=$((actual_count * 90 / 100))
upper_bound=$((actual_count * 110 / 100))

if [ $claimed_count -lt $lower_bound ] || [ $claimed_count -gt $upper_bound ]; then
    echo "⚠️ COUNT_CHECK: claimed $claimed_count, actual $actual_count (±10% tolerance)"
fi
```

**Check:**
- ✅ `metadata.total_files` within ±10% of actual count
- ⚠️ If significant difference → Update with actual count

#### V2.4: Verify Git Branch

```bash
# Verify git branch if claimed
claimed_branch="main"
actual_branch=$(git branch --show-current 2>/dev/null)

if [ -n "$claimed_branch" ] && [ "$actual_branch" != "$claimed_branch" ]; then
    echo "❌ BRANCH_MISMATCH: claimed $claimed_branch, actual $actual_branch"
fi
```

**Check:**
- ✅ `metadata.context.git_branch` matches current branch
- ⚠️ If mismatch → Update with actual branch
- ✅ If not a git repo → set to `null`

#### V2.5: Verify Evidence References

```bash
# Verify evidence file:line references
evidence_files="package.json README.md src/app.ts"

for file in $evidence_files; do
    if [ ! -f "$file" ]; then
        echo "❌ EVIDENCE_FILE_NOT_FOUND: $file"
    fi
done
```

**Check:**
- ✅ All files mentioned in `hypotheses.*.evidence` exist
- ⚠️ If file not found → Update evidence or remove hypothesis

#### V2.6: Verify Directories

```bash
# Verify directories mentioned in hypotheses
for dir in "src/controllers" "src/services" "src/repositories"; do
    if [ ! -d "$dir" ]; then
        echo "❌ DIR_NOT_FOUND: $dir"
    fi
done
```

**Check:**
- ✅ All directories mentioned in hypotheses exist
- ⚠️ If directory not found → Update hypothesis or remove claim

---

### Step V3: Handle Verification Results

Based on verification outcomes:

#### If All Checks Pass ✅

```yaml
verification_status:
  verified: true
  checks_passed: 6
  confidence: high
```

**Action:**
- Continue to output/save
- Add verification summary to footer

#### If Minor Issues Found ⚠️ (1-2 checks failed)

**Examples:**
- File count off by <10%
- One config file path incorrect
- Git branch name slightly different

**Action:**
1. **Correct the specific claims** without regenerating entire output
2. Re-verify corrected claims
3. Add note to verification summary:

```yaml
verification_notes:
  - "File count corrected to 134 (was 127)"
  - "Git branch corrected to 'develop' (was 'main')"
```

#### If Major Issues Found ❌ (3+ checks failed)

**Examples:**
- Multiple scanned files don't exist
- AI tool configs not found
- File count wildly different (>20% off)
- Many evidence references invalid

**Action:**
1. **STOP** - Do not output current analysis
2. Re-execute relevant phases:
   - If scanned files wrong → Re-run Phase 2 (High-Entropy Scanning)
   - If AI tools wrong → Re-run detect-ai-tools.sh
   - If file count wrong → Re-run detect-project.sh
3. Regenerate affected YAML sections
4. Re-run full verification

---

### Step V4: Verification Summary

Add to footer (before `🗺️ v2.11.0 │ Constitution v1.1`):

#### If All Verifications Passed

```markdown
✅ Verified: [N] scanned files, [M] config paths, file count
```

**Example:**
```markdown
✅ Verified: 8 scanned files, 2 config paths, file count

───────────────────────────────
🗺️ v2.11.0 │ Constitution v1.1
```

#### If Corrections Were Made

```markdown
🔧 Self-corrected: [list specific corrections]
✅ Verified: [N] scanned files, [M] config paths, file count
```

**Example:**
```markdown
🔧 Self-corrected: File count updated to 134 (was 127)
✅ Verified: 8 scanned files, 2 config paths, file count

───────────────────────────────
🗺️ v2.11.0 │ Constitution v1.1
```

---

## Verification Checklist

Before finalizing output, confirm:

- [ ] All `scanned_files[].file` entries verified to exist
- [ ] All `tools_detected[].config_file` entries verified to exist
- [ ] `metadata.total_files` verified against filesystem (±10%)
- [ ] `metadata.scanned_files` count matches actual files read
- [ ] `metadata.context.git_branch` verified against current branch
- [ ] All evidence file references in hypotheses verified to exist
- [ ] All directories mentioned in hypotheses verified to exist
- [ ] No placeholder values like `"[detected name]"` in output

---

## Verification Examples

### Example 1: File Path Verification

**Claim:**
```yaml
scanned_files:
  - file: "README.md"
```

**Verification:**
```bash
test -f "README.md"
echo $?  # 0 = exists
```

**Result:** ✅ File exists

**Action:** No correction needed

---

### Example 2: Config File Verification

**Claim:**
```yaml
hypotheses:
  ai_collaboration:
    tools_detected:
      - tool: "Claude Code"
        config_file: "CLAUDE.md"
```

**Verification:**
```bash
test -f "CLAUDE.md"
echo $?  # 0 = exists
```

**Result:** ✅ Config exists

**Action:** No correction needed

---

### Example 3: File Count Verification

**Claim:**
```yaml
metadata:
  total_files: 127
```

**Verification:**
```bash
actual=$(find . -type f \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/.venv/*" \
    2>/dev/null | wc -l | tr -d ' ')
echo "Claimed: 127, Actual: $actual"
# Output: Claimed: 127, Actual: 134
```

**Result:** ⚠️ Count off by 7 (5.5%), within tolerance but should update

**Action:**
- Update `metadata.total_files: 134`
- Recalculate `scan_ratio: "6.0%"` (8/134)
- Note: "File count corrected to 134"

---

### Example 4: Non-existent Config File

**Claim:**
```yaml
hypotheses:
  ai_collaboration:
    tools_detected:
      - tool: "Cursor"
        config_file: ".cursorrules"
```

**Verification:**
```bash
test -f ".cursorrules"
echo $?  # 1 = not found
```

**Result:** ❌ Config file doesn't exist

**Action:**
- Remove Cursor from `tools_detected`
- Lower AI collaboration level if appropriate
- Update confidence level
- Note: "Removed .cursorrules (file not found)"

---

### Example 5: Wrong Git Branch

**Claim:**
```yaml
metadata:
  context:
    git_branch: "main"
```

**Verification:**
```bash
git branch --show-current
# Output: develop
```

**Result:** ❌ Branch mismatch

**Action:**
- Update `git_branch: "develop"`
- Note: "Git branch corrected to 'develop'"

---

### Example 6: Directory Not Found

**Claim:**
```yaml
hypotheses:
  architecture:
    - hypothesis: "3-layer architecture: Controller → Service → Repository"
      evidence: "src/controllers/, src/services/, src/repositories/ exist"
```

**Verification:**
```bash
test -d "src/controllers" && test -d "src/services" && test -d "src/repositories"
echo $?  # 1 = at least one doesn't exist

# Check individually
test -d "src/controllers" && echo "✅ controllers"
test -d "src/services" && echo "✅ services"
test -d "src/repositories" || echo "❌ repositories not found"
```

**Result:** ❌ repositories directory doesn't exist

**Action:**
- Update hypothesis to reflect reality
- Lower confidence level
- Change evidence: "src/controllers/, src/services/ exist (no repository layer)"
- Update hypothesis: "2-layer architecture: Controller → Service"

---

## Error Recovery

### If Verification Script Fails

```bash
# If file not found, search for similar
find . -name "*README*" -type f 2>/dev/null

# If git command fails (not a git repo)
git branch 2>&1 | grep -q "not a git repository"
if [ $? -eq 0 ]; then
    echo "Not a git repo, set git_branch to null"
fi

# If find fails (permission issues)
find . -type f 2>&1 | grep -i "permission denied" && echo "Permission issues detected"
```

### If Many Files Don't Exist

**Likely causes:**
1. Analyzing wrong directory
2. Files from different project
3. Placeholder values not replaced

**Action:**
1. Verify current directory: `pwd`
2. Check expected location: `ls -la`
3. Re-run Phase 2 (High-Entropy Scanning)
4. Only include files that currently exist

---

## Best Practices

1. **Always verify file paths** - Don't assume files exist
2. **Check AI tool configs** - Many similar filenames (.cursorrules vs .cursor/rules/)
3. **Verify file counts** - Use same exclusions as analysis
4. **Check git context** - Projects may not be git repos
5. **Note all corrections** - Transparency in verification summary

---

## Handoff to Next Steps

After verification:
- ✅ If confidence HIGH → Proceed to save
- ⚠️ If confidence MEDIUM → Save with corrections noted
- ❌ If confidence LOW → Re-execute analysis phases

See [reference.md#auto-save](reference.md#auto-save) for save behavior.
