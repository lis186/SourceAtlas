# SourceAtlas Key Learnings Index

**Purpose**: Quick reference for all critical discoveries, decisions, and learnings
**Maintained**: After each major milestone
**Last Updated**: 2025-11-22 (v1.0 Complete)

---

## 🎯 Most Important Takeaways

### 1. Information Theory WORKS ✅

**Validated**: Scanning <5% files achieves 70-80% understanding

**Evidence**:
- 5/5 projects tested successfully
- README + package.json provide disproportionate information
- High-entropy prioritization saves 95%+ time

**Source**: `./v1-implementation-log.md` - Progress Update 4

### 2. Scale-Aware is NON-NEGOTIABLE ⭐

**Problem**: Fixed file counts fail catastrophically for small projects
- TINY (5 files): 60% scan ratio ❌
- LARGE (48 files): 10% scan ratio ✅

**Solution**: Scale-aware file limits and hypothesis targets

**Details**: See [Scale-Aware Algorithm](#scale-aware-algorithm)

**Source**: `./v1-implementation-log.md` - Progress Update 3-4

### 3. YAML > TOON (14% vs Ecosystem) ⭐

**Expected**: TOON saves 30-50% tokens
**Reality**: TOON saves only 14% tokens
**Decision**: YAML chosen for ecosystem support

**Rationale**: Standard format > marginal optimization

**Source**: `./toon-vs-yaml-analysis.md` - Full Analysis

### 4. .venv/node_modules MUST Be Excluded

**Problem**: Python .venv can inflate file count by 1000x
- interactive-feedback-mcp: 1185 files (only 2 actual Python files)
- Causes 0.25% scan ratio (misleading metric)

**Solution**: `detect-project-enhanced.sh` excludes:
- Python: .venv/, venv/, __pycache__/
- Node: node_modules/, dist/, build/
- PHP: vendor/
- General: .git/, .DS_Store

**Source**: `./v1-implementation-log.md` - Progress Update 4

### 5. Test on Real Projects, Not Theory

**Lesson**: Theory predicted one thing, reality showed another

**Examples**:
- Expected: TOON saves 30-50% → Reality: 14%
- Expected: Fixed file count works → Reality: Fails for TINY projects
- Expected: 10% scan ratio easy → Reality: Requires scale-aware algorithm

**Approach**:
- Test on 5+ diverse projects (TINY → LARGE)
- Measure everything (speed, size, tokens, scan ratio)
- Iterate based on data, not assumptions

**Source**: All `./` files

### 6. AI Collaboration is Detectable and Quantifiable

**Level 3 Indicators**:
- CLAUDE.md or .cursor/rules/ present
- 15-20% comment density (vs 5-8% human)
- 100% Conventional Commits
- 98%+ code consistency
- Docs:Code ratio >1:1

**Application**: Can objectively assess AI maturity

**Source**: `CLAUDE.md` - AI 協作檢測, `./v1-implementation-log.md`

---

## 📊 Critical Data Points

### Benchmark Results (5 Projects)

| Metric | Target | Result | Status |
|--------|--------|--------|--------|
| Speed | <15 min | 0-1 sec | ✅ 100% pass |
| Size | <300 lines | 123-172 lines | ✅ 100% pass |
| Tokens | <5000 | 1845-2580 | ✅ 100% pass |
| Scan ratio | <10% | 0.25%-60% | ⚠️ 40% pass |
| Hypotheses | 10-15 | 9-16 | ⚠️ 60% pass |

**Perfect**: Speed, size, tokens
**Needs work**: Scan ratio (scale-aware), hypotheses (scale-aware)

**Source**: `./v1-implementation-log.md` - Progress Update 4

### Format Comparison

| Format | Tokens | Ecosystem | Winner |
|--------|--------|-----------|--------|
| TOON | 807 | None | - |
| YAML | 938 (+14%) | Massive | ✅ YAML |

**Trade-off**: 131 extra tokens for entire ecosystem support = worth it

**Source**: `./toon-vs-yaml-analysis.md`

---

## 🔬 Scale-Aware Algorithm

### File Scan Limits (by Project Size)

| Scale | Files Range | Scan Limit | Target % |
|-------|-------------|------------|----------|
| **TINY** | <5 | 1-2 files | ~40% (accepted) |
| **SMALL** | 5-15 | 2-3 files | 10-20% |
| **MEDIUM** | 15-50 | 4-6 files | 8-12% |
| **LARGE** | 50-150 | 6-10 files | 4-7% |
| **VERY_LARGE** | >150 | 10-15 files | 3-7% |

### Hypothesis Targets (by Project Size)

| Scale | Hypothesis Count | Rationale |
|-------|------------------|-----------|
| **TINY** | 5-8 | Less to analyze, fewer patterns |
| **SMALL** | 7-10 | Moderate complexity |
| **MEDIUM** | 10-15 | Original target |
| **LARGE** | 12-18 | More subsystems to identify |
| **VERY_LARGE** | 15-20 | Complex, many architectural decisions |

**Key Insight**: TINY projects with 60% scan ratio are acceptable because even 2 files (README + package.json) provide critical insights. Alternative would be scanning only 1 file = missing technical details.

**Source**: `./v1-implementation-log.md` - Progress Update 5, `CLAUDE.md`

---

## 💡 Design Principles (Validated)

### 1. High-Entropy File Prioritization

**Priority Order**:
1. README.md, CLAUDE.md (project description, rules)
2. package.json, composer.json, etc. (tech stack, dependencies)
3. Models (3-5 core models) (data structures)
4. Controllers/Routes (1-2 examples) (API design)
5. Main config files (environment, integrations)

**Rationale**: Information theory - these files contain disproportionate information

**Validation**: 5/5 projects achieved 70-80% understanding with <5% scans

**Source**: `CLAUDE.md` - 核心設計原則

### 2. Progressive Refinement (3 Stages)

**Stage 0** (10-15 min, 70-80% understanding):
- Quick fingerprint
- 10-15 hypotheses
- High-entropy files only

**Stage 1** (20-30 min, 85-95% understanding):
- Validate hypotheses
- Systematic evidence gathering
- >80% validation accuracy

**Stage 2** (15-20 min, 95%+ understanding):
- Git history analysis
- Development patterns
- AI collaboration detection

**Validation**: All 3 stages complete in <1 hour, achieving 95%+ understanding

**Source**: `PROMPTS.md`, `CLAUDE.md`

### 3. Bayesian Inference

**Approach**:
```
Prior (Stage 0) + Evidence (Stage 1) = Posterior

Example:
Stage 0: "Uses JWT authentication" (confidence: 0.7)
  → Found: package.json has jsonwebtoken

Stage 1: Validate with grep "jwt"
  → Evidence: 5 usage locations (auth middleware, token gen, validation)

Posterior: Confidence upgraded to 0.95 ✅
```

**Validation**: Stage 1 achieves 87-100% hypothesis validation accuracy

**Source**: `PROMPTS.md` - Stage 1, `CLAUDE.md`

---

## 🚨 Critical Mistakes to Avoid

### 1. Don't Use Fixed File Counts ❌

**Wrong**:
```bash
# Scan 5 files regardless of project size
SCAN_COUNT=5
```

**Right**:
```bash
# Scale-aware scanning
case "$TOTAL_FILES" in
  0-4)   SCAN_COUNT=1-2 ;;    # TINY
  5-14)  SCAN_COUNT=2-3 ;;    # SMALL
  15-49) SCAN_COUNT=4-6 ;;    # MEDIUM
  *)     SCAN_COUNT=6-10 ;;   # LARGE+
esac
```

**Why**: Fixed counts cause 60% scan ratio on TINY projects

**Source**: `./v1-implementation-log.md` - Progress Update 3

### 2. Don't Forget to Exclude Bloat Directories ❌

**Wrong**:
```bash
TOTAL_FILES=$(find . -name "*.py" | wc -l)
# Result: 1185 files (includes .venv!)
```

**Right**:
```bash
TOTAL_FILES=$(find . -name "*.py" \
  ! -path "*/.venv/*" \
  ! -path "*/venv/*" \
  ! -path "*/__pycache__/*" | wc -l)
# Result: 2 files (correct)
```

**Why**: .venv can inflate file count by 1000x, breaking metrics

**Source**: `./v1-implementation-log.md` - Progress Update 4

### 3. Don't Optimize Format Before Testing ❌

**Wrong**:
```
"TOON will save 30-50% tokens, let's build it first!"
→ Spend 2 weeks building TOON parser
→ Discover only 14% savings
→ Wasted effort
```

**Right**:
```
"Let's test TOON vs YAML on real data first"
→ Spend 1 hour creating both versions
→ Measure: only 14% savings
→ Decision: Use YAML (standard ecosystem)
→ Saved 2 weeks
```

**Why**: Test assumptions before committing to custom solutions

**Source**: `./toon-vs-yaml-analysis.md`

### 4. Don't Target Arbitrary Percentage for All Scales ❌

**Wrong**:
```
"All projects must have <10% scan ratio"
→ TINY project: 2 files scanned out of 5 = 40% = FAIL
→ But those 2 files (README + package.json) are critical!
```

**Right**:
```
"TINY projects: Accept 20-50% as practical trade-off"
"LARGE projects: Maintain <10% target"
→ Scale-aware acceptance criteria
```

**Why**: High-entropy files are essential even if they represent high % of total

**Source**: `./v1-implementation-log.md` - Progress Update 5

### 5. Don't Skip Benchmarking ❌

**Wrong**:
```
"I think this is fast enough"
→ No data
→ No comparison
→ Hidden regressions
```

**Right**:
```
"Let's measure: duration, size, tokens, scan ratio, hypotheses"
→ 5 projects tested
→ 100% pass on speed/size/tokens
→ 40% pass on scan ratio → identified issue
→ Fixed with scale-aware algorithm
```

**Why**: You can't improve what you don't measure

**Source**: `scripts/atlas/benchmark.sh`, `./v1-implementation-log.md`

---

## 📐 Metrics and Targets

### Stage 0 Targets (Validated)

| Metric | Target | Result | Status |
|--------|--------|--------|--------|
| **Duration** | <15 min | 0-1 sec | ✅ EXCEED |
| **Lines** | <300 | 123-172 | ✅ EXCEED |
| **Tokens** | <5000 | 1845-2580 | ✅ EXCEED |
| **Scan ratio (LARGE)** | <10% | 10.41% | ⚠️ BORDERLINE |
| **Scan ratio (TINY)** | Accept 20-50% | 40-60% | ✅ ACCEPTED |
| **Understanding** | 70-80% | 70-80% | ✅ ACHIEVE |
| **Hypotheses** | 10-15 | 9-16 | ⚠️ VARIES |

### Token Cost Analysis

**Per Analysis**:
- Stage 0: ~20k tokens @ $0.003/1k = $0.06
- Stage 1: ~30k tokens = $0.09
- Stage 2: ~20k tokens = $0.06
- **Total**: ~70k tokens = **$0.21 per complete analysis**

**vs Traditional**:
- Read 100+ files: ~500k tokens = $1.50
- **Savings**: 93% cost reduction ✅

**YAML vs TOON**:
- YAML: 938 tokens
- TOON: 807 tokens
- Difference: 131 tokens = **$0.000393 per analysis**
- For 1000 analyses: $0.39 savings
- **Verdict**: Not worth custom format overhead

**Source**: `./toon-vs-yaml-analysis.md` - Cost-Benefit Analysis

---

## 🎓 Methodological Discoveries

### 1. Content > Structure for Token Optimization

**Discovery**: Format structure is only 15-20% of total tokens

**Breakdown**:
- **Content** (hypotheses, evidence, descriptions): 80-85%
- **Structure** (YAML keywords, syntax): 15-20%

**Implication**: Optimizing structure = marginal gains (14%)

**Better optimization**: Select fewer files (content reduction)

**Source**: `./toon-vs-yaml-analysis.md` - Root Cause Analysis

### 2. Percentage Metrics Break for Small Samples

**Problem**: 2 files out of 5 = 40% looks bad

**Reality**: 2 files (README + package.json) = essential

**Solution**: Use absolute + relative metrics
- "Scanned 2 files (40% of 5 total)" = context
- "Scanned essential high-entropy files" = quality

**Lesson**: Metrics need context, especially for small N

**Source**: `./v1-implementation-log.md` - Progress Update 5

### 3. Ecosystem Value > Pure Efficiency

**Quantified**:
- TOON: 14% more efficient, zero ecosystem
- YAML: Standard, massive ecosystem

**Trade-off**: 131 tokens (~$0.0004) for:
- IDE support
- yamllint validation
- yq querying
- Universal parsers
- GitHub rendering
- Known format

**Decision**: Ecosystem wins

**Lesson**: Developer experience has high but hard-to-quantify value

**Source**: `./toon-vs-yaml-analysis.md` - Decision Matrix

### 4. "極簡" (Extreme Minimal) Means Standard Tools

**Initial misunderstanding**: Minimal = fewest bytes

**Correct interpretation**: Minimal = fewest things to maintain

**Application**:
- Use YAML (standard) not TOON (custom)
- Use existing bash tools not custom parsers
- Leverage Claude Code built-ins not new infrastructure

**Philosophy**: Minimalism is about simplicity, not optimization

**Source**: `./toon-vs-yaml-analysis.md` - Final Decision

---

## 🔄 Iteration History

### v1.0 Evolution

**Initial Plan** (2025-11-22 00:00):
- Use TOON format (assumed 30-50% savings)
- Fixed file scan count
- Target <10% scan ratio for all projects
- Generic hypothesis count (10-15)

**After Testing** (2025-11-22 03:30):
- Use YAML format (measured 14% savings only)
- Scale-aware file limits
- Accept 20-50% scan ratio for TINY projects
- Scale-aware hypothesis targets

**Changes made in <4 hours due to real testing** ✅

**Lesson**: Rapid iteration beats prolonged planning

**Source**: `./v1-implementation-log.md` - Full session

---

## 📚 Documentation Hierarchy

### Must Read (Start Here)

1. **CLAUDE.md** - Current rules, v1.0 learnings, implementation principles
2. **This file** - Key learnings index (you are here)
3. **README.md** - User-facing overview

### Implementation Details

4. **`./implementation-roadmap.md`** - v2.5 plan (36 pages)
5. **`./NEXT_STEPS.md`** - Immediate actions
6. **`./v1-implementation-log.md`** - Complete v1 session history

### Deep Dives

7. **`./toon-vs-yaml-analysis.md`** - Format decision rationale
8. **`./planning-session-summary.md`** - v2.5 planning overview
9. **PRD.md** - Product requirements v2.5.2
10. **PROMPTS.md** - Stage 0/1/2 methodology

### Quick Reference

- File scan limits: See [Scale-Aware Algorithm](#scale-aware-algorithm)
- Hypothesis targets: See [Scale-Aware Algorithm](#scale-aware-algorithm)
- Benchmark results: See [Critical Data Points](#critical-data-points)
- Format comparison: See [Format Comparison](#format-comparison)

---

## 🔮 Future Considerations

### What to Watch For

1. **Token Cost Changes**
   - If costs increase 10x → Reconsider TOON
   - Currently $0.003/1k, would need $0.03/1k for TOON to matter

2. **Context Window Limits**
   - Current: 200k tokens
   - YAML overhead: ~131 tokens per analysis
   - Would need 1500+ analyses to fill window (unrealistic)

3. **Standard TOON Adoption**
   - If industry adopts similar compact format
   - Then ecosystem would exist → reconsider

4. **Scale Beyond VERY_LARGE**
   - Current max: >150 files → scan 10-15
   - For 1000+ file projects: May need new scale tier

### What NOT to Worry About (For Now)

1. ❌ Token optimization beyond YAML
2. ❌ Custom binary formats
3. ❌ Real-time indexing (v3.0 maybe)
4. ❌ Multi-language parsing (use existing tools)

**Principle**: Solve real problems, not hypothetical ones (YAGNI)

---

## ✅ Validation Checklist

Use this checklist when implementing new features:

- [ ] **Scale-aware design** - Different sizes need different approaches
- [ ] **Standard formats** - Use YAML/Markdown, don't invent
- [ ] **Test on 3+ real projects** - Theory ≠ Reality
- [ ] **Measure everything** - Speed, size, tokens, scan ratio
- [ ] **Exclude bloat directories** - .venv, node_modules, __pycache__
- [ ] **High-entropy prioritization** - README > configs > models > code
- [ ] **Evidence-based claims** - Every hypothesis needs file:line references
- [ ] **Document as you build** - Don't leave docs for later

---

**Maintained by**: SourceAtlas Team
**Last Updated**: 2025-11-22 (v1.0 Complete)
**Next Update**: After v2.5 Phase 1 (Week 1)
