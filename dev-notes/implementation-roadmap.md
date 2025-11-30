# SourceAtlas v2 Implementation Roadmap

**Version**: v2.0 → v2.5
**Created**: 2025-11-22
**Status**: Planning → Implementation

---

## 🎯 Executive Summary

**Current State**: v1.0 validation complete with proven methodology
**Target State**: v2.5 Commands architecture with 5 slash commands
**Timeline**: 3-4 weeks (phased rollout)
**Success Criteria**: `/atlas.pattern` and `/atlas.overview` in production use

---

## 📊 Gap Analysis

### What We Have (v1.0 ✅)

**Proven Methodology**:
- ✅ 3-stage analysis framework (Stage 0/1/2)
- ✅ Scale-aware file limits (TINY→VERY_LARGE)
- ✅ Information theory-based prioritization
- ✅ AI collaboration detection (Level 0-4)
- ✅ Format decision: **YAML chosen** (14% token savings vs ecosystem support)

**Validation Results** (5 projects tested):
- ✅ Speed: 100% pass (all under 5 min)
- ✅ Size: 100% pass (all under 150 lines)
- ✅ Token efficiency: 100% pass
- ✅ Understanding depth: 70-80% (Stage 0), 85-95% (Stage 1)

**Infrastructure**:
- ✅ `/atlas.overview` command (Stage 0 fingerprint)
- ✅ `detect-project-enhanced.sh` - Scale-aware detection
- ✅ `scan-entropy.sh` - High-entropy file scanner
- ✅ Comprehensive documentation

### What We're Missing (PRD v2.5.2 Expectations)

**Commands** (0/5 complete):
- ❌ `/atlas.pattern` ⭐⭐⭐⭐⭐ (MOST IMPORTANT - learn design patterns)
- ❌ `/atlas.impact` ⭐⭐⭐⭐ (impact analysis)
- ❌ `/atlas` ⭐⭐⭐ (complete 3-stage analysis)
- ❌ `/atlas.find` ⭐⭐ (smart search)
- ❌ `/atlas.explain` ⭐ (deep dive)

**Scripts** (2/5 complete):
- ✅ `detect-project-enhanced.sh`
- ✅ `scan-entropy.sh`
- ❌ `find-patterns.sh` (P0 - supports `/atlas.pattern`)
- ❌ `collect-git.sh` (P1 - Stage 2 analysis)
- ❌ `analyze-dependencies.sh` (P1 - impact analysis)

**Documentation**:
- ❌ Real-world usage examples
- ❌ Pattern library (common patterns database)
- ❌ Integration tests

---

## 🏗️ Implementation Plan

### Phase 1: Most Valuable Command (Week 1, Days 1-3)

**Goal**: Ship `/atlas.pattern` ⭐⭐⭐⭐⭐ - THE most important feature

**Why Priority #1?**
- PRD user scenarios: "学习现有模式" is #1 use case
- Immediate value: Help developers learn "how THIS codebase does X"
- High frequency: Daily use expected
- Enables: Faster onboarding, consistent patterns, fewer mistakes

**Tasks**:

1. **Create `scripts/atlas/find-patterns.sh`**
   ```bash
   #!/bin/bash
   # Find exemplary implementations of a pattern
   # Usage: find-patterns.sh "api endpoint"

   PATTERN_TYPE="$1"

   # Pattern detection strategies:
   # - "api endpoint" → find routes, controllers
   # - "background job" → find job classes, queue configs
   # - "file upload" → find upload handlers, storage configs
   # - "database query" → find model methods, query builders

   # Return: List of best example files with relevance scores
   ```

2. **Create `.claude/commands/atlas.pattern.md`**
   ```markdown
   ---
   description: Learn design patterns from the current codebase
   allowed-tools: Bash, Glob, Grep, Read
   argument-hint: [pattern type, e.g., "api endpoint", "background job", "file upload"]
   ---

   # SourceAtlas: Pattern Learning Mode

   ## Context
   Pattern requested: **$ARGUMENTS**

   ## Your Task
   1. Run: `bash scripts/atlas/find-patterns.sh "$ARGUMENTS"`
   2. Identify 2-3 exemplary implementations
   3. Extract the design pattern
   4. Provide step-by-step guidance for implementing similar features

   ## Output Format
   - Pattern name and description
   - Best example files (with line numbers)
   - Key conventions to follow
   - Testing patterns
   - Common pitfalls to avoid

   Time limit: 5-10 minutes
   ```

3. **Test on real projects**
   - cursor-talk-to-figma-mcp: "websocket integration"
   - sourceatlas2: "bash script pattern"
   - Test 3+ pattern types

4. **Document usage examples**
   - Add to USAGE_GUIDE.md
   - Create pattern library starter (templates/patterns.yaml)

**Success Criteria**:
- [ ] `/atlas.pattern "api endpoint"` returns actionable guidance
- [ ] Works on 3+ different pattern types
- [ ] Complete in <10 minutes
- [ ] Provides file:line references

**Estimated Time**: 1-2 days

---

### Phase 2: Complete Analysis Pipeline (Week 1, Days 4-7)

**Goal**: Ship `/atlas` (complete 3-stage analysis)

**Why Second Priority?**
- Builds on proven v1.0 methodology
- Enables complete codebase understanding
- Required for deep analysis scenarios

**Tasks**:

1. **Create `scripts/atlas/collect-git.sh`**
   ```bash
   #!/bin/bash
   # Collect Git statistics for Stage 2 analysis
   # - Commit frequency and patterns
   # - File hotspots (most changed files)
   # - Timeline reconstruction
   # - AI collaboration indicators
   ```

2. **Create `.claude/commands/atlas.md`**
   - Integrate Stage 0/1/2 prompts from PROMPTS.md
   - Use existing `detect-project-enhanced.sh` and `scan-entropy.sh`
   - Call `collect-git.sh` for Stage 2
   - Output YAML format (Stage 0) + Markdown (Stage 1/2)

3. **Update output format**
   - Change from TOON to YAML (per v1 decision)
   - Update templates in `templates/`
   - Ensure backward compatibility

4. **Integration testing**
   - Test on cursor-talk-to-figma-mcp (SMALL)
   - Test on webscout (LARGE) if available
   - Verify all 3 stages complete successfully

**Success Criteria**:
- [ ] `/atlas` completes all 3 stages
- [ ] Output in YAML + Markdown formats
- [ ] Stage 0: 70-80% understanding in 10-15 min
- [ ] Stage 1: 85-95% understanding
- [ ] Stage 2: Git analysis complete

**Estimated Time**: 2-3 days

---

### Phase 3: Impact Analysis (Week 2, Days 1-4)

**Goal**: Ship `/atlas.impact` ⭐⭐⭐⭐ - high-value feature

**Why Third Priority?**
- Addresses critical pain point: "what breaks if I change X?"
- PRD scenario 3B: API impact analysis is ⭐ priority
- Daily use in production development

**Tasks**:

1. **Create `scripts/atlas/analyze-dependencies.sh`**
   ```bash
   #!/bin/bash
   # Analyze dependency chains
   # Usage: analyze-dependencies.sh "User model"
   #        analyze-dependencies.sh api "/api/users/{id}"

   TARGET="$1"
   TYPE="${2:-function}"  # function|api|model

   # Strategies:
   # - Grep for imports/requires
   # - Find function call sites
   # - Trace API endpoint usage (frontend files)
   # - Identify model associations
   ```

2. **Create `.claude/commands/atlas.impact.md`**
   ```markdown
   ---
   description: Analyze impact of changes to code, models, or APIs
   allowed-tools: Bash, Glob, Grep, Read
   argument-hint: [target, e.g., "User model", api "/api/users/{id}"]
   ---

   # SourceAtlas: Impact Analysis

   ## Context
   Target: **$ARGUMENTS**

   ## Your Task
   1. Run: `bash scripts/atlas/analyze-dependencies.sh "$ARGUMENTS"`
   2. Map dependency chains
   3. Identify all affected files
   4. Assess risk level and breaking changes
   5. Generate migration checklist

   ## Output Format
   - Direct impacts (files that import/call target)
   - Cascading impacts (dependencies of dependencies)
   - Risk assessment (LOW/MEDIUM/HIGH)
   - Migration checklist
   - Estimated effort

   Time limit: 10-15 minutes
   ```

3. **Test scenarios**:
   - Function change impact
   - Model validation change impact
   - **API endpoint change impact** (PRD scenario 3B)
   - Database schema change impact

4. **Create migration checklist templates**

**Success Criteria**:
- [ ] Identifies all direct dependents
- [ ] Maps cascading impacts
- [ ] Works for functions, models, and APIs
- [ ] Provides actionable migration checklist
- [ ] Risk assessment is accurate

**Estimated Time**: 2-3 days

---

### Phase 4: Quick Tools (Week 2, Days 5-7)

**Goal**: Ship `/atlas.find` and `/atlas.explain`

**Why Last?**
- Lower priority (⭐⭐ and ⭐)
- Nice-to-have, not critical
- Can leverage existing infrastructure

**Tasks**:

1. **Create `.claude/commands/atlas.find.md`**
   - Smart search combining file name + content
   - Semantic understanding of query
   - Quick results (<30 seconds)

2. **Create `.claude/commands/atlas.explain.md`**
   - Deep dive into specific file
   - Explain purpose, dependencies, usage
   - Show tests and examples

3. **Optional: Create `scripts/atlas/smart-search.sh`**
   - Enhanced grep with context
   - File name fuzzy matching
   - Relevance ranking

**Success Criteria**:
- [ ] `/atlas.find "user login"` returns relevant files
- [ ] `/atlas.explain path/to/file.ts` provides comprehensive explanation
- [ ] Both complete in <5 minutes

**Estimated Time**: 1-2 days

---

## 📅 Timeline Summary

| Week | Phase | Deliverables | Status |
|------|-------|-------------|--------|
| **Week 1** | Foundation | `/atlas.pattern`, `/atlas` | 🔵 Planned |
| **Week 2** | Impact + Tools | `/atlas.impact`, `/atlas.find`, `/atlas.explain` | 🔵 Planned |
| **Week 3** | Testing & Docs | Real-world testing, documentation, examples | 🔵 Planned |
| **Week 4** | Polish & Launch | Bug fixes, optimization, launch prep | 🔵 Planned |

**Fast Track Option** (if time constrained):
- Week 1: `/atlas.pattern` only (P0)
- Week 2: `/atlas` only (P1)
- Defer impact analysis and quick tools to later

---

## 🎯 Success Metrics

### Quantitative

| Metric | Target | Measurement |
|--------|--------|-------------|
| Command coverage | 5/5 (100%) | Commands implemented |
| Script coverage | 5/5 (100%) | Scripts implemented |
| Real-world testing | 3+ projects | Test projects analyzed |
| User satisfaction | >4/5 | Feedback score (when available) |
| Time to value | <5 min | Time from `/atlas.pattern` to actionable result |

### Qualitative

- [ ] Developers use `/atlas.pattern` daily
- [ ] `/atlas` provides complete understanding
- [ ] Impact analysis prevents breaking changes
- [ ] Documentation is clear and comprehensive
- [ ] Commands feel "native" to Claude Code

---

## 🔀 Decision Points

### Decision 1: Format Migration (RESOLVED ✅)

**Question**: TOON or YAML for v2.5?

**Decision**: **YAML** (per v1 analysis)
- 14% token savings with TOON not worth custom format overhead
- YAML ecosystem support > optimization
- Aligns with "極簡" philosophy

**Action Items**:
- ✅ Update PRD.md to reflect YAML as default
- [ ] Update all command templates to use YAML
- [ ] Remove TOON references from new implementations

### Decision 2: Commands vs Skills (RESOLVED ✅)

**Question**: Use Commands or Skills?

**Decision**: **Commands** (per PRD v2.5.1 Decision 4)
- User expects explicit control
- Different scenarios need different entry points
- Simpler implementation

**No action needed** - architecture already decided.

### Decision 3: Pattern Library Scope

**Question**: Create comprehensive pattern library or minimal starter?

**Options**:
1. **Minimal starter** (5-10 common patterns)
   - Pros: Ship faster, learn from real usage
   - Cons: Less immediately useful

2. **Comprehensive library** (50+ patterns)
   - Pros: More valuable out of the box
   - Cons: Slower to ship, may include unused patterns

**Recommendation**: **Minimal starter** → expand based on usage
- Start with: API endpoint, background job, file upload, database query, authentication
- Add patterns based on real user needs
- Community can contribute patterns

**Decision**: 🔵 To be decided in Phase 1

### Decision 4: SpecStory Integration

**Question**: Use .specstory for tracking implementation?

**Current State**: .specstory/ exists with .project.json

**Options**:
1. Use SpecStory for task tracking
2. Use manual tracking (this document + todos)

**Recommendation**: **Manual tracking** for now
- SpecStory adds complexity
- Implementation roadmap (this doc) is sufficient
- Can integrate later if needed

**Decision**: 🔵 Manual tracking

---

## 🚨 Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Scripts don't work cross-platform** | HIGH | MEDIUM | Test on macOS + Linux, use POSIX-compliant bash |
| **Pattern detection too generic** | HIGH | MEDIUM | Start with specific patterns, refine based on testing |
| **Commands too slow** | MEDIUM | LOW | Enforce time limits, optimize scripts |
| **Documentation incomplete** | MEDIUM | MEDIUM | Write docs as we implement, not after |
| **Real projects don't match test cases** | HIGH | MEDIUM | Test on 3+ diverse real projects |

---

## 📚 Documentation Updates Needed

### PRD.md

- [ ] Update "当前版本" from v2.5.2 to reflect implementation status
- [ ] Mark Phase 1-4 tasks with actual completion status
- [ ] Update "实作路线图" section with this roadmap
- [ ] Change TOON references to YAML in examples

### README.md

- [ ] Add v2.5 features when shipped
- [ ] Update "快速開始" with Commands usage
- [ ] Add `/atlas.pattern` examples
- [ ] Update roadmap section

### USAGE_GUIDE.md

- [ ] Add Commands usage guide (all 5 commands)
- [ ] Add real-world usage examples
- [ ] Add troubleshooting for Scripts
- [ ] Add pattern library reference

### New Documentation

- [ ] `PATTERNS.md` - Pattern library with examples
- [ ] `COMMANDS_REFERENCE.md` - Complete command documentation
- [ ] `SCRIPTS_REFERENCE.md` - Script documentation and API

---

## 🎓 Learning from v1.0

### Key Insights to Apply

1. **Test Early, Test Often**
   - v1: Tested on 5 projects → found scale-aware bugs
   - v2: Test each command on 3+ projects before moving on

2. **Metrics Matter**
   - v1: Benchmark suite revealed 40% scan ratio issue
   - v2: Create benchmarks for all commands

3. **Scale-Aware Design**
   - v1: One-size-fits-all failed for TINY projects
   - v2: Build scale awareness into all commands

4. **Format Pragmatism**
   - v1: TOON vs YAML → chose ecosystem over optimization
   - v2: Don't over-engineer, use standard formats

5. **Documentation = Implementation**
   - v1: Comprehensive logs helped track decisions
   - v2: Write docs as we build, not after

---

## 🔄 Iteration Strategy

### After Phase 1 (Week 1)

**Review**:
- Is `/atlas.pattern` actually useful?
- Do developers use it daily?
- What patterns are requested most?

**Adapt**:
- Expand pattern library based on usage
- Refine detection algorithms
- Add missing pattern types

### After Phase 2 (Week 2)

**Review**:
- Does `/atlas` provide complete understanding?
- Are 3 stages necessary or can we optimize?
- What's the actual time/token cost?

**Adapt**:
- Optimize slow stages
- Consider optional Stage 2 (skip if no Git)
- Adjust understanding targets

### After Phase 3-4 (Week 2-3)

**Review**:
- Are impact analysis and quick tools used?
- What features are missing?
- Any performance issues?

**Adapt**:
- Add missing features
- Optimize performance bottlenecks
- Improve documentation

---

## 💡 Future Enhancements (v3.0+)

**Not in scope for v2.5, but worth tracking**:

1. **SourceAtlas Monitor** (PRD v3.0)
   - Continuous tracking
   - Trend analysis
   - Health dashboard
   - Technical debt quantification

2. **Pattern Library Expansion**
   - 50+ common patterns
   - Language-specific patterns
   - Framework-specific patterns
   - Community contributions

3. **Advanced Impact Analysis**
   - Static analysis integration
   - Runtime dependency tracking
   - Breaking change detection
   - Automated migration tools

4. **Team Features**
   - Multi-project analysis
   - Team onboarding automation
   - Knowledge base building
   - Pattern documentation generation

---

## 📝 Next Actions

**Immediate** (Start Now):

1. **Create `find-patterns.sh`**
   - [ ] Define pattern detection strategies
   - [ ] Implement basic pattern matching
   - [ ] Test on 2-3 projects

2. **Create `.claude/commands/atlas.pattern.md`**
   - [ ] Write command prompt
   - [ ] Define output format
   - [ ] Add usage examples

3. **Test `/atlas.pattern`**
   - [ ] Test on cursor-talk-to-figma-mcp
   - [ ] Test on sourceatlas2
   - [ ] Collect feedback

**This Week** (Week 1):

- [ ] Complete Phase 1: `/atlas.pattern`
- [ ] Start Phase 2: `/atlas` command
- [ ] Create `collect-git.sh` script

**This Month** (Weeks 1-4):

- [ ] Complete all 5 commands
- [ ] Complete all 5 scripts
- [ ] Test on 5+ real projects
- [ ] Update all documentation
- [ ] Ship v2.5.2

---

## ✅ Definition of Done

**Per Command**:
- [ ] Command file created in `.claude/commands/`
- [ ] Supporting scripts implemented in `scripts/atlas/`
- [ ] Tested on 3+ diverse projects
- [ ] Documentation added to USAGE_GUIDE.md
- [ ] Examples added to README.md
- [ ] Success criteria met

**Per Phase**:
- [ ] All commands in phase complete
- [ ] Integration testing passed
- [ ] Documentation updated
- [ ] Review conducted
- [ ] Feedback incorporated

**v2.5.2 Release**:
- [ ] All 5 commands implemented
- [ ] All 5 scripts implemented
- [ ] 5+ projects tested successfully
- [ ] All documentation updated
- [ ] PRD.md reflects actual implementation
- [ ] README.md updated with v2.5 features
- [ ] USAGE_GUIDE.md comprehensive

---

**Roadmap Version**: 1.0
**Last Updated**: 2025-11-22
**Next Review**: After Phase 1 completion
**Maintained By**: SourceAtlas Team
