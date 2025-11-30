# SourceAtlas v2 - Next Steps

**Status**: v1.0 Complete → v2.5 Implementation Starting
**Date**: 2025-11-22
**Timeline**: 3-4 weeks to v2.5.2

---

## 🎯 Start Here

### Immediate Actions (Today/This Week)

**Priority P0** - Start Immediately:

```bash
# 1. Create the most important command
touch .claude/commands/atlas.pattern.md
touch scripts/atlas/find-patterns.sh

# 2. Implement pattern detection script
vim scripts/atlas/find-patterns.sh
# (See implementation roadmap for spec)

# 3. Create the command
vim .claude/commands/atlas.pattern.md
# (See templates in PRD.md or implementation roadmap)

# 4. Test on real project
cd /path/to/test/project
# Use: /atlas.pattern "api endpoint"
# Use: /atlas.pattern "background job"
```

**Goal**: Get `/atlas.pattern` working by end of week

---

## 📋 Phase 1 Checklist (Week 1)

### Day 1-2: `/atlas.pattern` Implementation

- [ ] **Create `find-patterns.sh`**
  - [ ] Detect "api endpoint" pattern (routes, controllers)
  - [ ] Detect "background job" pattern (job classes, queue configs)
  - [ ] Detect "file upload" pattern (upload handlers, storage)
  - [ ] Detect "database query" pattern (models, query builders)
  - [ ] Detect "authentication" pattern (auth middleware, sessions)
  - [ ] Return relevance-ranked file list

- [ ] **Create `atlas-pattern.md` command**
  - [ ] Integrate `find-patterns.sh`
  - [ ] Extract pattern from 2-3 best examples
  - [ ] Provide step-by-step implementation guide
  - [ ] Include testing patterns
  - [ ] Add common pitfalls section

- [ ] **Test on 3 projects**
  - [ ] cursor-talk-to-figma-mcp: "websocket integration"
  - [ ] sourceatlas2: "bash script pattern"
  - [ ] Any project: "api endpoint", "file upload"

- [ ] **Document**
  - [ ] Add usage examples to USAGE_GUIDE.md
  - [ ] Create pattern library starter (templates/patterns.yaml)
  - [ ] Add to README.md quick start

### Day 3-5: `/atlas` Full Analysis

- [ ] **Create `collect-git.sh`**
  - [ ] Commit frequency and patterns
  - [ ] File hotspots (most changed files)
  - [ ] Timeline reconstruction
  - [ ] AI collaboration indicators

- [ ] **Create `atlas.md` command**
  - [ ] Stage 0: Use existing `detect-project-enhanced.sh` + `scan-entropy.sh`
  - [ ] Stage 1: Systematic hypothesis validation
  - [ ] Stage 2: Git analysis using `collect-git.sh`
  - [ ] Output YAML (Stage 0) + Markdown (Stage 1/2)

- [ ] **Migrate output format**
  - [ ] Change Stage 0 output from TOON to YAML
  - [ ] Update templates in templates/
  - [ ] Test backward compatibility

- [ ] **Integration test**
  - [ ] Test on cursor-talk-to-figma-mcp (SMALL)
  - [ ] Verify all 3 stages complete
  - [ ] Check understanding targets (70%/85%/95%)

### Day 6-7: Documentation & Review

- [ ] **Update documentation**
  - [ ] README.md: Add v2.5 features
  - [ ] USAGE_GUIDE.md: Add Commands usage
  - [ ] PRD.md: Update implementation status

- [ ] **Review Phase 1**
  - [ ] Are commands useful in practice?
  - [ ] What's the actual usage frequency?
  - [ ] Any performance issues?
  - [ ] What patterns are requested most?

---

## 📅 Remaining Phases (Quick Reference)

### Phase 2: Impact Analysis (Week 2, Days 1-4)

**Deliverable**: `/atlas.impact`

**Key Tasks**:
- Create `analyze-dependencies.sh`
- Create `atlas-impact.md` command
- Test on function/model/API changes
- Create migration checklist templates

### Phase 3: Quick Tools (Week 2, Days 5-7)

**Deliverables**: `/atlas.find`, `/atlas.explain`

**Key Tasks**:
- Create `atlas-find.md` (smart search)
- Create `atlas-explain.md` (deep dive)
- Optional: `smart-search.sh` script

### Phase 4: Polish & Launch (Week 3-4)

**Deliverables**: v2.5.2 Release

**Key Tasks**:
- Real-world testing (5+ projects)
- Complete documentation
- Performance optimization
- Bug fixes
- Launch prep

---

## 🎯 Success Criteria

**Phase 1 Complete When**:
- [x] `/atlas.pattern` returns actionable guidance in <10 min
- [x] Works on 3+ different pattern types
- [x] `/atlas` completes all 3 stages successfully
- [x] Documentation updated
- [x] No critical bugs

**v2.5.2 Release Ready When**:
- [x] All 5 commands implemented and tested
- [x] All 5 scripts working cross-platform
- [x] 5+ real projects tested successfully
- [x] Documentation complete and accurate
- [x] User feedback >4/5 (if available)

---

## 🚀 Fast Track Option

**If time is limited**, prioritize in this order:

1. **Week 1**: `/atlas.pattern` only (P0) ⭐⭐⭐⭐⭐
   - Most important command
   - Immediate value
   - Daily use expected

2. **Week 2**: `/atlas.overview` refinement + `/atlas`
   - Complete analysis capability
   - Builds on v1.0 work

3. **Later**: Impact analysis and quick tools
   - Nice-to-have
   - Can ship incrementally

---

## 📊 Tracking Progress

### Daily Standup Questions

1. What did I ship yesterday?
2. What am I shipping today?
3. Any blockers?

### Weekly Review Questions

1. Did we meet phase goals?
2. What worked well?
3. What needs adjustment?
4. Should we adapt the plan?

### Metrics to Track

- [ ] Commands implemented: 1/5 (`/atlas.overview` done)
- [ ] Scripts implemented: 2/5 (detect-project-enhanced, scan-entropy done)
- [ ] Projects tested: 5/5 (v1 testing done)
- [ ] Documentation pages updated: 0/4

---

## 🔗 Key Resources

**Implementation Details**:
- [Implementation Roadmap](./implementation-roadmap.md) - Complete plan
- [PRD v2.5.2](PRD.md) - Product requirements
- [PROMPTS.md](PROMPTS.md) - Stage 0/1/2 prompts (reference for `/atlas`)

**v1.0 Learnings**:
- [Implementation Log](./v1-implementation-log.md) - What we learned
- [TOON vs YAML Analysis](./toon-vs-yaml-analysis.md) - Format decision

**Existing Work**:
- `.claude/commands/atlas.overview.md` - Working Stage 0 command
- `scripts/atlas/detect-project-enhanced.sh` - Scale-aware detection
- `scripts/atlas/scan-entropy.sh` - High-entropy file scanner

---

## 💡 Tips for Implementation

### Pattern Detection Strategy

**Good patterns have**:
- Clear file naming conventions (e.g., `*Controller.ts`, `*Job.rb`)
- Consistent directory structure (e.g., `app/controllers/`, `jobs/`)
- Recognizable imports/requires
- Similar method signatures

**Start with**:
1. File name patterns (glob)
2. Directory structure (find)
3. Content patterns (grep)
4. Rank by relevance (count occurrences)

### Command Design Principles

**Keep commands focused**:
- One clear purpose per command
- Time limit: 5-15 minutes max
- Output actionable, not exhaustive

**Use scripts for data collection**:
- Scripts collect, AI interprets
- Keep scripts simple and fast (<5 sec)
- Return raw data, not conclusions

**Provide context**:
- Show file:line references
- Explain "why" not just "what"
- Give next steps

---

## 🚨 Watch Out For

### Common Pitfalls

1. **Over-engineering**
   - Start simple, add complexity as needed
   - YAGNI (You Aren't Gonna Need It)

2. **Platform-specific scripts**
   - Test on macOS AND Linux
   - Use POSIX-compliant bash
   - Avoid GNU-specific flags

3. **Too generic patterns**
   - Be specific to codebase patterns
   - Learn from 2-3 examples, not 1
   - Avoid over-abstracting

4. **Documentation drift**
   - Update docs as you code, not after
   - Keep examples real and tested
   - PRD should match reality

### Red Flags

⚠️ **Stop and reassess if**:
- Command takes >15 minutes
- Pattern detection gives irrelevant results
- Scripts fail on different platforms
- Documentation is confusing
- Real usage doesn't match expectations

---

## ✅ Definition of Done

**For Each Command**:
- [ ] Command file exists in `.claude/commands/`
- [ ] Supporting scripts (if any) in `scripts/atlas/`
- [ ] Tested on 3+ projects
- [ ] Examples in USAGE_GUIDE.md
- [ ] No critical bugs
- [ ] Meets time/quality targets

**For v2.5.2 Release**:
- [ ] 5 commands: atlas-overview ✅, atlas-pattern, atlas-impact, atlas, atlas-find, atlas-explain
- [ ] 5 scripts: detect-project-enhanced ✅, scan-entropy ✅, find-patterns, collect-git, analyze-dependencies
- [ ] Real-world validation on 5+ projects
- [ ] Complete documentation
- [ ] PRD updated with actual status

---

## 🎬 Getting Started Script

Copy-paste this to start Phase 1:

```bash
# Navigate to project
cd /Users/justinlee/dev/sourceatlas2

# Create Phase 1 files
touch .claude/commands/atlas.pattern.md
touch scripts/atlas/find-patterns.sh
chmod +x scripts/atlas/find-patterns.sh

# Open for editing
code .claude/commands/atlas.pattern.md scripts/atlas/find-patterns.sh

# (Implement based on specs in implementation-roadmap.md)

# Test on sample project
cd /Users/justinlee/dev/cursor-talk-to-figma-mcp
# Use: /atlas.pattern "websocket integration"

# Document results
cd /Users/justinlee/dev/sourceatlas2
# Update USAGE_GUIDE.md with examples
```

---

**Ready to start? Begin with Phase 1, Day 1: Create `find-patterns.sh`** 🚀

**Questions? Check**:
- Implementation Roadmap for detailed specs
- PRD for design decisions
- v1 Implementation Log for lessons learned

**Need help? Review**:
- Existing `/atlas.overview` command for reference
- PROMPTS.md for Stage 0/1/2 structure
- Test results for validation approach
