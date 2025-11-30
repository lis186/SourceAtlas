# Senior iOS Developer `/atlas.find` Query Exercise

**Status**: Completed November 25, 2025
**Scope**: 25 realistic technical queries across 2 large iOS projects
**Purpose**: Understand how senior engineers query large codebases

---

## Quick Start (5 minutes)

### Read this first:
**File**: `EXERCISE_SUMMARY.txt` (11 KB)
- Overview of the entire exercise
- Key findings and design implications
- Success criteria

### Then check this:
**File**: `QUICK_REFERENCE_SENIOR_DEV_QUERIES.md` (7 KB)
- One-page cheat sheet
- Query pattern templates
- Red flags and Do's/Don'ts

---

## Complete Deep Dive (60 minutes)

### Detailed Analysis:
1. **ios-senior-dev-atlas-find-queries.md** (14 KB, 30 min read)
   - 5 developer personas
   - 25 specific technical queries
   - Context for each query

2. **SENIOR_DEV_QUERY_PATTERNS.md** (7.5 KB, 20 min read)
   - 6 query pattern templates
   - File count expectations
   - Design implications

3. **SENIOR_DEV_EXERCISE_INDEX.md** (8.6 KB, 10 min read)
   - Navigation guide
   - Takeaways for implementation
   - Related reading

---

## What You'll Learn

### Senior Developers Query For:
✓ PATTERNS, not implementations
✓ INTEGRATION POINTS, not entire features
✓ PRECEDENT EXAMPLES, not original solutions
✓ CONSISTENCY GUARANTEES, not business logic

### They Expect:
✓ 10-15 core files per investigation
✓ Results within 5 seconds
✓ Context-aware (not keyword-based)
✓ Integration points highlighted
✓ Precedent examples provided
✓ Risk areas annotated

### Time Budgets:
- Security review: 3-4 hours, 10-15 files
- API integration: 2-3 hours, 5-8 files
- Real-time optimization: 2-3 hours, 15-20 files
- Extension development: 2-3 hours, 10-15 files

---

## Project Coverage

### Signal-iOS (2,667 files)
- 2 personas, 10 queries
- E2EE architecture, call infrastructure
- Focus: Encryption, persistence, NSE, WebRTC

### WordPress-iOS (3,639 files)
- 3 personas, 15 queries
- API integration, share extension, modular architecture
- Focus: Flux, REST API, SPM modules, extensions

---

## Key Insights for `/atlas.find`

The tool should support:

1. **Pattern-aware indexing** → Index by architectural patterns, not keywords
2. **Context-sensitive search** → Understand "encrypt → database" as data flow
3. **Boundary detection** → Highlight module/system boundaries
4. **Precedent finding** → "This pattern also used in..." suggestions
5. **Risk annotation** → Flag consistency, security, data corruption risks
6. **Scope limiting** → Return "top 10-15 files" not all 200 matches
7. **Pattern templates** → Help users ask better questions

---

## Document Locations

```
/Users/justinlee/dev/sourceatlas2/
├── START_HERE.md (you are here)
├── EXERCISE_SUMMARY.txt (start here for quick overview)
├── QUICK_REFERENCE_SENIOR_DEV_QUERIES.md (cheat sheet)
├── ios-senior-dev-atlas-find-queries.md (detailed analysis)
├── SENIOR_DEV_QUERY_PATTERNS.md (pattern study)
└── SENIOR_DEV_EXERCISE_INDEX.md (navigation guide)
```

---

## Reading Guide

**Time: 5 minutes**
→ Read: EXERCISE_SUMMARY.txt

**Time: 10 minutes**
→ Read: QUICK_REFERENCE_SENIOR_DEV_QUERIES.md

**Time: 30 minutes**
→ Read: ios-senior-dev-atlas-find-queries.md

**Time: 20 minutes**
→ Read: SENIOR_DEV_QUERY_PATTERNS.md

**Time: 10 minutes**
→ Read: SENIOR_DEV_EXERCISE_INDEX.md

**Total time: 60 minutes for complete understanding**

---

## Statistics

- **Documents**: 5 (this + 4 main documents)
- **Total size**: 47 KB
- **Total lines**: 2,065
- **Personas**: 5
- **Queries**: 25
- **Query patterns**: 6
- **Projects**: 2

---

## Success Criteria

`/atlas.find` should successfully answer these types of queries:

✓ "encrypt message database store secure encapsulation"
✓ "notification service extension decrypt NSE message key"
✓ "transaction atomic write message attachment consistency"
✓ "REST API endpoint response parsing model mapping repository"
✓ "flux store state reducer action dispatch side effects"
✓ "share extension content type activity detection URI provider"
✓ "SPM module package swift dependency internal external targets"
✓ [+ 18 more documented queries]

With:
✓ < 5 second response time
✓ 10-15 targeted files
✓ Context-aware results
✓ Integration points highlighted
✓ Risk areas annotated

---

## Next Steps

1. (**Now**) Read EXERCISE_SUMMARY.txt (5 min)
2. (**Today**) Skim QUICK_REFERENCE_SENIOR_DEV_QUERIES.md (10 min)
3. (**This week**) Study ios-senior-dev-atlas-find-queries.md (30 min)
4. (**This week**) Analyze SENIOR_DEV_QUERY_PATTERNS.md (20 min)
5. (**Next sprint**) Use findings to enhance `/atlas.find`:
   - Implement pattern-aware indexing
   - Add scope limiting
   - Include risk annotation
   - Surface precedent examples
6. (**Testing**) Validate against all 25 queries

---

**Ready?** Start with: `/Users/justinlee/dev/sourceatlas2/EXERCISE_SUMMARY.txt`

