# SourceAtlas Roadmap

**Current Status**: v2.5 Core Commands Complete ✅
**Last Updated**: 2025-11-30

---

## 🎯 Immediate Actions (This Week)

### Phase 1 - Pattern Detection (Week 1) ✅ COMPLETE
- [x] `/atlas.pattern` command
- [x] `find-patterns.sh` script (ultra-fast version)
- [x] Multi-project validation

### Phase 2 - Pattern System Optimization (Week 2-4) ✅ COMPLETE
- [x] TypeScript patterns expansion (13→22)
- [x] iOS patterns consolidation (34→29)
- [x] Objective-C support (all 29 patterns)
- [x] Patterns audit & cleanup

### Phase 3 - Core Commands (Week 5-8) ✅ COMPLETE
- [x] `/atlas.overview` command (Stage 0) ✅ (2025-11-20)
- [x] Command architecture simplification ✅ (2025-11-24)
- [x] `/atlas.impact` command (change impact) ✅ (2025-11-25)
- [x] `/atlas.init` command (auto-trigger rules) ✅ (2025-11-30)
- [x] ~~`/atlas.find`~~ 已取消 - 功能由現有 commands 涵蓋 (2025-11-25)

### Phase 4 - Testing & Polish (Week 9-16)
- [x] Comprehensive testing ✅ (2025-11-30) - 90% pass rate, 9/10 tests
- [x] Documentation update ✅ (2025-11-30) - Plugin sync, PROMPTS.md, version unification
- [x] Performance optimization ✅ (2025-11-30) - Current performance sufficient
- [ ] v2.5.2 Release

---

## 📅 Timeline

### v2.5.2 (Current)

**Week 1-4** ✅ (11/20-11/23):
- Pattern Detection System
- Multi-language Support
- Pattern Optimization

**Week 5-8** 🔵 (Next 4 weeks):
- Core Commands Implementation
- Stage 0-2 Integration
- Testing Framework

**Week 9-12**:
- Advanced Commands
- Performance Tuning
- User Documentation

**Week 13-16**:
- Final Testing
- Bug Fixes
- v2.5.2 Release

### v2.6 (Future Vision)

**SourceAtlas Monitor**:
- Continuous tracking
- Trend analysis
- Health dashboard

**Technical Debt Quantification**:
- Automated debt detection
- Refactoring suggestions
- Priority ranking

**Multi-Repository Support**:
- Monorepo analysis
- Cross-project patterns
- Dependency mapping

---

## 🔥 Current Sprint (Week 5)

### Priority P0 (Must Do) ⭐
1. **`/atlas.impact` implementation** ✅ (Done 11/25)
   - Static dependency analysis
   - API change impact tracking
   - Tested on 5 real scenarios (100% success)
   - **Key decision**: Remove automatic time estimation

### Priority P1 (Should Do)
2. Document command architecture decisions ✅ (Done 11/24)
3. `/atlas.init` implementation ✅ (Done 11/30)
4. Collect user feedback

### Priority P2 (Nice to Have)
5. Performance benchmarking
6. Pattern statistics dashboard

### Technical Debt 🔧
- [x] Plugin 同步：更新 `plugin/` 以匹配已實作的 4 個 commands (init, overview, pattern, impact) ✅ (2025-11-30)
- [x] PROMPTS.md 更新：新增 v2.5 Commands 區段，保留手動 Prompts 用於深度分析 ✅ (2025-11-30)

---

## 📊 Progress Tracking

### Completed Milestones ✅
- [x] v1.0 Methodology Validation (2025-10-22)
- [x] YAML Format Decision (2025-11-20)
- [x] Atlas Overview Command (2025-11-20)
- [x] Atlas Pattern Command (2025-11-22)
- [x] TypeScript Patterns Expansion (2025-11-23)
- [x] iOS Patterns Consolidation (2025-11-23)
- [x] Objective-C Support (2025-11-23)
- [x] Command Architecture Simplification (2025-11-24)
- [x] Version Number Unification (2025-11-24)
- [x] Atlas Impact Command (2025-11-25)
- [x] Time Estimation Decision (2025-11-25)

### In Progress 🔵
- [x] dev-notes/ Restructuring (100% complete)
- [x] v2.5 Core Commands ✅ (4/4 complete: init, overview, pattern, impact)

### Blocked ❌
- None

---

## 🎓 Lessons Learned

從 v1.0 到當前的關鍵學習：

1. **資訊理論有效**: <5% 掃描確實能達 70-80% 理解
2. **規模感知重要**: 不同大小專案需要不同策略
3. **標準優於優化**: YAML > TOON（+14% tokens 但生態系統好）
4. **混合專案挑戰**: Swift/ObjC 需要特殊處理
5. **Pattern 一致性**: 跨語言命名慣例相似度高
6. **使用場景驅動設計** (2025-11-24): 從真實場景倒推功能需求，發現 `/atlas` 無實際使用場景
7. **命令命名重要性** (2025-11-24): 技術性命名（如 "coupling"）不易理解，發現重疊後果斷簡化

---

**Next Review**: 每週日更新進度
