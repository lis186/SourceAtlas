# SourceAtlas - Next Steps

**Status**: v2.7.0 Complete (2025-12-01)
**Next Target**: v2.8.0

---

## Current State

### Completed Features (v2.7.0)

**6 Core Commands**:
| Command | Purpose | Status |
|---------|---------|--------|
| `/atlas.init` | Project initialization | ✅ |
| `/atlas.overview` | Project fingerprint (Stage 0) | ✅ |
| `/atlas.pattern` | Learn design patterns | ✅ |
| `/atlas.impact` | Change impact analysis | ✅ |
| `/atlas.history` | Git temporal analysis | ✅ |
| `/atlas.flow` | Flow tracing (11 modes) | ✅ |

**Multi-Language Support** (141 patterns):
- iOS/Swift: 34 patterns
- Kotlin/Android: 31 patterns
- Python: 26 patterns
- TypeScript/React/Vue: 50 patterns

---

## v2.8 Planning

### Priority P0 - Language Expansion

**Goal**: Expand pattern support to more languages

**Candidates**:
1. **Go** - Backend services, CLI tools
2. **Rust** - Systems programming, WebAssembly
3. **Ruby** - Rails ecosystem
4. **PHP** - Laravel, WordPress

**Approach** (per language):
1. Research: Identify 10+ test projects
2. Analysis: Extract common patterns
3. Implementation: Tier 1 (10-15) + Tier 2 (10-15)
4. Validation: Test on 5+ projects

### Priority P0 - `/atlas.flow` Improvements

Based on `2025-12-01-atlas-flow-p0a-implementation.md`:

- [ ] AST analysis integration (higher accuracy)
- [ ] Cross-file tracing (import graph)
- [ ] Dynamic pattern learning
- [ ] More language support in flow analysis

### Priority P1 - SourceAtlas Monitor

**Concept**: Continuous codebase health tracking

**Features**:
- Automated trend analysis
- Health dashboard
- Technical debt quantification
- Refactoring suggestions

**Decision Point**: Evaluate after user feedback on v2.7

### Priority P1 - User Feedback

- [ ] Publish v2.7.0 release notes
- [ ] Collect usage feedback
- [ ] Identify pain points
- [ ] Prioritize improvements

### Priority P2 - Nice to Have

- Performance benchmarking dashboard
- Pattern statistics visualization
- Cross-repository analysis
- Monorepo support

---

## Immediate Actions

### This Week

1. **Documentation Sync** (Current)
   - [x] Update NEXT_STEPS.md (this file)
   - [ ] Update ROADMAP.md
   - [ ] Update PRD.md version status
   - [ ] Update HISTORY.md statistics

2. **Release Preparation**
   - [ ] Finalize v2.7.0 changelog
   - [ ] Update README.md with new features
   - [ ] Prepare release announcement

### Next Week

Choose one focus area:

**Option A: Language Expansion**
- Start Go patterns research
- Clone 5+ Go projects for testing
- Draft Tier 1 pattern list

**Option B: Flow Improvements**
- Research AST parsing options
- Prototype import graph analysis
- Benchmark accuracy improvements

**Option C: Monitor Planning**
- Design data model for tracking
- Prototype health metrics
- Define MVP scope

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-12-01 | v2.7.0 Complete | 6 commands + 141 patterns |
| 2025-11-30 | `/atlas.find` Cancelled | Covered by existing commands |
| 2025-11-25 | Remove time estimates | Provide facts, not predictions |
| 2025-11-24 | YAML > TOON | Ecosystem > 14% optimization |

---

## Success Metrics

### v2.7.0 (Achieved)
- [x] 6 core commands implemented
- [x] 141 patterns across 4 languages
- [x] `/atlas.flow` accuracy >90%
- [x] Multi-project validation

### v2.8.0 (Targets)
- [ ] 200+ patterns (add 2 more languages)
- [ ] `/atlas.flow` AST integration
- [ ] User feedback >4/5 rating
- [ ] Real-world usage data collected

---

## Quick Reference

**Key Files**:
- Commands: `.claude/commands/atlas.*.md`
- Scripts: `scripts/atlas/*.sh`
- Patterns: `scripts/atlas/find-patterns.sh`

**Key Docs**:
- [PRD.md](../PRD.md) - Product requirements
- [ROADMAP.md](./ROADMAP.md) - Timeline and milestones
- [HISTORY.md](./HISTORY.md) - Development history
- [KEY_LEARNINGS.md](./KEY_LEARNINGS.md) - Core insights

**Test Projects** (in `test_targets/`):
- iOS: Signal-iOS, wikipedia-ios
- Android: nowinandroid, tivi
- Python: Django, FastAPI
- TypeScript: Excalidraw, Mantine

---

**Last Updated**: 2025-12-03 (v2.7.0)
