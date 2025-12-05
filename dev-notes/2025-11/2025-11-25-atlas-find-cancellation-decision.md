# Decision: Cancel `/atlas.find` Command

**Date**: 2025-11-25
**Type**: Feature Cancellation
**Impact**: PRD v2.5.3, CLAUDE.md, Phase 3 Roadmap
**Status**: ✅ Approved and Implemented

---

## Executive Summary

After user research with **8 developer personas** across **9 projects** (80+ queries), we decided to **cancel `/atlas.find`**. Analysis revealed **70%+ of use cases already covered** by existing commands or built-in tools.

**Decision**: Focus on perfecting 3 core commands rather than adding a 4th with unclear value.

---

## Background

### Original Plan

```bash
/atlas.find "user login"  # Quickly locate feature implementation
```

**Intended**: Bridge between `/atlas.pattern` (learn patterns) and Grep (keyword search)

### Problem

Every intended use case mapped to existing solutions:
- Learn HOW → `/atlas.pattern` ✅
- Find WHO uses it → `/atlas.impact` ✅
- Search keywords → Built-in Grep/Glob ✅
- Debug issues → Ask Claude conversationally ✅

**Question**: What unique value does `/atlas.find` provide? → **None found**

---

## Research Method

Simulated **8 developer roles** (Intern to Senior Architect) across 9 real-world projects:
- iOS: commercial-ios-app, Signal-iOS, Wikipedia-iOS, WordPress-iOS
- Android: NewPipe, AntennaPod, Signal Android
- Ruby: Spree
- Python: CTFd

**Total**: 80+ realistic queries collected

→ Full research archived in `dev-notes/2025-11/atlas.find-research/`

---

## Key Findings

### Finding 1: Query Type Distribution

| Query Type | % | Already Solved By |
|-----------|---|-------------------|
| Pattern Learning | 35% | `/atlas.pattern` ✅ |
| Impact Analysis | 35% | `/atlas.impact` ✅ |
| Architecture Navigation | 15% | `/atlas.overview` ✅ |
| Symptom Diagnosis | 10% | Conversational ✅ |
| Keyword Search | 5% | Grep/Glob ✅ |

**→ Top 2 categories (70%) already solved!**

### Finding 2: No Unique Value

Example mappings:
```
"find checkout button"
  → Learn pattern? /atlas.pattern "checkout button"
  → See impact? /atlas.impact "checkout"
  → Find file? Grep "checkout"

"where is User authentication"
  → Learn pattern? /atlas.pattern "authentication"
  → See usage? /atlas.impact "User"
```

Every query had a better existing solution.

### Finding 3: Risk of Confusion

Having 4 similar commands creates decision paralysis:
> "Should I use /atlas.find, /atlas.pattern, /atlas.impact, or Grep?"

**Better UX**: 3 clear, non-overlapping commands with obvious purposes.

---

## Decision

### ✅ Cancel `/atlas.find`

**Rationale**:
1. 70%+ use cases already covered
2. Remaining 30% better served by conversation or built-in tools
3. Avoids feature overlap and user confusion
4. Allows focus on perfecting core commands

### Phase 3 Redirect

**Before**: Implement `/atlas.find` + `/atlas.explain`
**After**: Multi-language expansion + Testing + v2.5.0 release

---

## Impact

### Files Updated
- ✅ PRD.md - Removed all `/atlas.find` references
- ✅ CLAUDE.md - Updated roadmap
- ✅ HISTORY.md - Added decision record

### Development Time Saved
~2-3 weeks avoided by deciding early (before implementation)

---

## Lessons Learned

1. **User research before implementation** ⭐
   - Tested with realistic personas BEFORE building
   - Avoided wasted development time

2. **"Feature Addition" ≠ "Value Addition"**
   - Wrong: "We need 'find' because others have it"
   - Right: "What unique problem does this solve?"

3. **Fewer, better commands > Many overlapping commands**
   - Clear boundaries = Better UX
   - Each command needs unique, obvious value

---

## Conclusion

Canceling `/atlas.find` was correct based on:
- ✅ Evidence: 70%+ use cases already covered
- ✅ UX: Avoiding confusion
- ✅ Efficiency: Focus on core value

**Next Steps**:
1. Complete Phase 3: Multi-language expansion
2. Collect feedback on existing 3 commands
3. Prepare v2.5.0 release

---

**Decision Status**: ✅ APPROVED AND IMPLEMENTED
**Reversibility**: High (Could add later if real need emerges)
