# Pattern Learning Reference

Advanced features, caching behavior, and best practices.

---

## Cache Behavior

### When Cache is Used

```bash
# Default: Use cache if exists and fresh
/sourceatlas:pattern "api endpoint"

# Check logic:
pattern_name="api-endpoint"  # sanitized from arguments
cache_file=".sourceatlas/patterns/${pattern_name}.md"

if [ -f "$cache_file" ]; then
  age_days=$(calculate_age_in_days)
  echo "📁 Loading from cache ($age_days days ago)"
  if [ $age_days -gt 30 ]; then
    echo "⚠️ Cache over 30 days old, recommend re-analysis"
  fi
  cat "$cache_file"
  exit 0
fi
```

### When Cache is Skipped

```bash
# Force flag: Always skip cache
/sourceatlas:pattern "api endpoint" --force
# → Executes full analysis even if cache exists

# No cache: First time analysis
# → .sourceatlas/patterns/api-endpoint.md doesn't exist yet
```

### Cache File Naming

```bash
# Pattern name sanitization
"API Endpoint"     → "api-endpoint.md"
"Background Job"   → "background-job.md"
"React Component"  → "react-component.md"
"Very Long Pattern Name..." → "very-long-pattern-name-that-exceeds-limit.md" (truncated to 50 chars)

# Rules:
# - Spaces → hyphens
# - Lowercase
# - Remove special characters
# - Truncate to 50 characters
```

---

## Auto-Save Behavior

### File Structure

```
.sourceatlas/patterns/
├── api-endpoint.md
├── background-job.md
├── repository-pattern.md
└── custom-hook.md
```

### Save Timing

Auto-save occurs **immediately after Step V4 verification**:

```yaml
# After verification passes
verification_summary:
  confidence_level: "high"

# Then auto-save
💾 Saved to .sourceatlas/patterns/api-endpoint.md
```

### What Gets Saved

Complete Markdown output including:
- Header with pattern name and file count
- Overview summary
- Best Examples (2-3 with code snippets)
- Key Conventions
- Testing Pattern
- Common Pitfalls
- Step-by-Step Guide
- Verification summary

**Format:** Full Markdown as specified in [output-template.md](output-template.md)

---

## Handoffs: When to Suggest Next Commands

### After Pattern with Complex Flow

If pattern involves multi-step execution:

**Suggest:**
```
| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:flow "src/api/controllers/UserController.ts"` | Pattern involves 3-layer architecture, trace full execution flow |
```

### After Pattern with Wide Usage

If pattern used in many files:

**Suggest:**
```
| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:impact "src/services/BaseService.ts"` | Pattern used in 23 services, need to understand dependencies |
```

### After Finding Related Pattern

If analysis mentions related patterns:

**Suggest:**
```
| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:pattern "repository pattern"` | Controllers depend on repositories, need to understand that pattern next |
```

### When to Stop (No Recommendations)

- **Pattern is simple**: Self-contained, no complex dependencies
- **No clear next steps**: Analysis complete, ready to implement
- **Analysis depth sufficient**: User already ran 4+ commands

**Output instead:**
```
✅ **Pattern analysis complete** - Can start implementation following the Step-by-Step Guide above
```

---

## Common Verification Errors

### Error 1: Hallucinated File Paths

**Symptom:** File paths that sound plausible but don't exist

**Prevention:**
- Always use actual search results
- Never guess file paths
- Verify each path before including

### Error 2: Outdated Code Snippets

**Symptom:** Code snippet doesn't match current file

**Recovery:**
```bash
# Re-read file
cat "path/to/file.ts"

# Extract fresh snippet
sed -n '40,55p' "path/to/file.ts"
```

### Error 3: Wrong Line Numbers

**Symptom:** Line number points to wrong content

**Debug:**
```bash
# Check file length
wc -l file.ts

# View lines around claimed line
sed -n '43,47p' file.ts  # Show 45 ±2 lines
```

**Fix:** Re-read file, find correct line number

---

## Integration with Other Commands

After pattern verification, consider:
- **Pattern involves complex flow** → `/sourceatlas:flow "[entry point]"`
- **Pattern used in many files** → `/sourceatlas:impact "[core file]"`
- **Related pattern found** → `/sourceatlas:pattern "[related pattern]"`
