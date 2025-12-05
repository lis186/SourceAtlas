# SourceAtlas Roadmap

**Current Status**: v2.7.0 Complete ✅
**Last Updated**: 2025-12-03
**Pattern Count**: 141 patterns (iOS 34, TypeScript/React/Vue 50, Android/Kotlin 31, Python 26)

---

## 🎯 Current Release: v2.7.0 ✅

### Core Commands (6/6 Complete)

| Command | Purpose | Completed |
|---------|---------|-----------|
| `/atlas.init` | Project initialization | 2025-11-30 |
| `/atlas.overview` | Project fingerprint | 2025-11-20 |
| `/atlas.pattern` | Learn patterns | 2025-11-22 |
| `/atlas.impact` | Impact analysis | 2025-11-25 |
| `/atlas.history` | Git temporal analysis | 2025-11-30 |
| `/atlas.flow` | Flow tracing (11 modes) | 2025-12-01 |

### Multi-Language Patterns (141 Total)

| Language | Patterns | Tier 1 | Tier 2 |
|----------|----------|--------|--------|
| iOS/Swift | 34 | 16 | 18 |
| TypeScript/React/Vue | 50 | 25 | 25 |
| Android/Kotlin | 31 | 12 | 19 |
| Python | 26 | 12 | 14 |

---

## 📅 v2.8 Planning (Next)

### Priority P0 - Must Do

#### 1. Language Expansion
**Goal**: Add 60+ patterns for 2 more languages

**Candidates** (choose 2):
| Language | Use Case | Difficulty |
|----------|----------|------------|
| **Go** | Backend, CLI, K8s | Medium |
| **Rust** | Systems, WASM | High |
| **Ruby** | Rails, Scripts | Low |
| **PHP** | Laravel, WordPress | Low |

**Recommendation**: Start with Go + Ruby (broader coverage, lower risk)

#### 2. `/atlas.flow` Improvements
Based on P0-A implementation (2025-12-01):

| Feature | Impact | Effort |
|---------|--------|--------|
| AST analysis | High accuracy | High |
| Import graph | Cross-file tracing | Medium |
| Pattern learning | Project-specific | Medium |

### Priority P1 - Should Do

#### 3. SourceAtlas Monitor
**Concept**: Continuous health tracking

**MVP Features**:
- Weekly health snapshot
- Hotspot trend tracking
- Bus factor alerts
- Technical debt score

**Decision**: Evaluate after v2.7 user feedback

#### 4. User Feedback Collection
- [ ] Publish release notes
- [ ] Create feedback form
- [ ] Track real usage
- [ ] Identify top pain points

### Priority P2 - Nice to Have

- Performance dashboard
- Pattern statistics
- Monorepo support
- Cross-repo analysis
- `/atlas.standup` - GitLab MR integration

---

## 📊 Progress Tracking

### Completed Milestones ✅

| Date | Milestone | Impact |
|------|-----------|--------|
| 2025-12-01 | v2.7.0 Release | 6 commands + `/atlas.flow` |
| 2025-11-30 | `/atlas.history` | Git temporal analysis |
| 2025-11-30 | 141 patterns | 4 language support |
| 2025-11-25 | `/atlas.impact` | Change analysis |
| 2025-11-22 | v1.0 Complete | Methodology validated |
| 2025-11-20 | YAML Decision | Standard > optimization |

### In Progress 🔵

- [ ] v2.8 Planning finalization
- [ ] User feedback collection
- [ ] Documentation sync

### Upcoming 📋

- [ ] Go patterns research
- [ ] Ruby patterns research
- [ ] `/atlas.flow` AST integration

---

## 🎓 Key Learnings

From v1.0 to v2.7.0:

1. **Information Theory Works**: <5% scan achieves 70-80% understanding
2. **Scale Awareness Matters**: Different project sizes need different strategies
3. **Standard > Optimization**: YAML ecosystem > 14% token savings
4. **Language-Specific Patterns**: Generic patterns don't achieve high accuracy
5. **Zero-Parameter Design**: Better portability across AI tools
6. **Political Sensitivity**: "Recent Contributors" > "Ownership %"
7. **Confidence Scoring**: Helps users trust results appropriately

---

## 🔧 Technical Debt

### Resolved ✅
- [x] Plugin sync (4 → 6 commands)
- [x] PROMPTS.md update
- [x] Version unification
- [x] Vue directive pattern fix
- [x] Path-based patterns removal

### Remaining
- [ ] Linux compatibility testing
- [ ] Performance benchmarking
- [ ] Error message improvements

---

## 📈 Success Metrics

### v2.7.0 (Achieved) ✅
- [x] 6 core commands
- [x] 141 patterns
- [x] Entry point accuracy >90%
- [x] 10 boundary types

### v2.8.0 (Targets)
- [ ] 200+ patterns (+60)
- [ ] 6 languages supported (+2)
- [ ] AST-based flow analysis
- [ ] User satisfaction >4/5

### Long-term Vision
- [ ] 300+ patterns (8+ languages)
- [ ] Real-time monitoring
- [ ] IDE plugin integration
- [ ] Team collaboration features

---

**Next Review**: Weekly on Sunday
**Contact**: Check issues at https://github.com/lis186/SourceAtlas
