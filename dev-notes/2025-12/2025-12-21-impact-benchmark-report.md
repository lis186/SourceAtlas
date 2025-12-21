# /atlas.impact Benchmark Report

**Date**: 2025-12-21
**Version**: v2.9.6

## Summary

| Metric | Result |
|--------|--------|
| **Internal Consistency** | 100% (5/5 projects) |
| **Languages Tested** | Swift, Ruby, Python, TypeScript, Kotlin |
| **Total Dependencies Analyzed** | 2,068 files |
| **Total Test Files** | 969 files |

### Important Definitions

| Term | Definition |
|------|------------|
| **Internal Consistency** | Category subtotals sum to total (no double-counting) |
| **NOT External Verifiability** | Numbers are LLM-analyzed, may differ from simple grep |

> ⚠️ **Note**: This benchmark validates that `/atlas.impact` produces internally consistent categorization. The actual file counts depend on LLM semantic analysis and may vary from simple `grep -rl` results due to pattern interpretation differences.

## Test Results by Project

| Project | Language | Target | Dependencies | Categories | Tests |
|---------|----------|--------|--------------|------------|-------|
| Firefox iOS | Swift | TabManager | 67 | 4+11+44+8=67 ✅ | 39 |
| Discourse | Ruby | User | 410 | 72+38+25+62+213=410 ✅ | 445 |
| Prefect | Python | FlowRun | 122 | 14+58+0+50=122 ✅ | 100 |
| Cal.com | TypeScript | Booking | 936 | 585+329+22=936 ✅ | 194 |
| Thunderbird | Kotlin | Account | 533 | 122+273+24+114=533 ✅ | 191 |

## Methodology

### Mutually Exclusive Categorization

Categories are counted using exclusion chains to avoid double-counting:

```bash
# 1. Save all dependent files
grep -rl "${TARGET}" --include="*.ext" . | grep -v Test | sort -u > /tmp/deps.txt

# 2. Count with exclusion (order matters)
CORE=$(grep 'core_pattern' /tmp/deps.txt | wc -l)
CAT2=$(grep -v 'core_pattern' /tmp/deps.txt | grep 'cat2_pattern' | wc -l)
CAT3=$(grep -v 'core_pattern' /tmp/deps.txt | grep -v 'cat2_pattern' | grep 'cat3_pattern' | wc -l)
OTHER=$(grep -v 'core_pattern' /tmp/deps.txt | grep -v 'cat2_pattern' | grep -v 'cat3_pattern' | wc -l)

# 3. Verify sum equals total
SUM=$((CORE + CAT2 + CAT3 + OTHER))
```

### Validation Criteria

- **Pass**: Sum of all categories equals total file count
- **Fail**: Any mismatch indicates double-counting

## Issues Fixed

| Issue | Root Cause | Fix |
|-------|------------|-----|
| Category double-counting | Non-exclusive grep patterns | Added Phase 4: Mutually Exclusive Categorization |
| Estimated API usage counts | No requirement for exact counts | Added Phase 5: Exact API Usage Counts |

## Command Definition Updates

File: `.claude/commands/atlas.impact.md`

Added two new required phases:
1. **Phase 4: Mutually Exclusive Categorization** - Ensures categories don't overlap
2. **Phase 5: Exact API Usage Counts** - Requires actual grep counts, not estimates

## Conclusion

`/atlas.impact` achieves 100% **internal consistency** across 5 projects in 5 different languages when using the updated categorization logic.

### What This Means

- ✅ **Categories don't overlap** - No double-counting in categorization
- ✅ **Math is correct** - Subtotals always sum to total
- ✅ **Multi-language support** - Works across Swift, Ruby, Python, TypeScript, Kotlin

### What This Does NOT Mean

- ❌ **Exact grep reproducibility** - LLM analysis differs from simple `grep -rl`
- ❌ **Deterministic counts** - Same query may produce slightly different results

### E2E Verification Results (2025-12-21)

| Project | Tests Match | Deps Variance | Notes |
|---------|-------------|---------------|-------|
| Thunderbird | ✅ 100% | +6.6% | Within acceptable range |
| Firefox iOS | ✅ 100% | -19.4% | Pattern sensitivity |
| Discourse | ❌ | +244% | "User" is common word |
| Prefect | ❌ | +91% | Broad pattern match |
| Cal.com | ⚠️ | +37% | Case sensitivity |

> 📋 Full E2E report: [2025-12-21-impact-e2e-verification.md](./2025-12-21-impact-e2e-verification.md)
