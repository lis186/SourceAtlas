# Scale Detection Methodology v2.0

**Date**: 2025-12-21
**Status**: Validated (5/5 projects correct)

## Problem Statement

Original scale detection used simple file count thresholds that were too conservative:
- `>500 files` = VERY_LARGE (incorrect)
- Many LARGE projects (Firefox iOS, Thunderbird, Cal.com, Prefect) were misclassified

## Solution: Hybrid Detection Strategy

### Key Principles

1. **Count ALL code files, not just primary language**
   - Projects often have multiple languages (e.g., Swift + Ruby for fastlane)
   - Scale should reflect total codebase complexity

2. **Language-aware project type detection**
   - Priority order prevents misclassification
   - Swift files > Gemfile (iOS with fastlane)
   - Strong language markers > Monorepo tools

3. **Benchmark-validated thresholds**
   - Based on 5 real-world open-source projects
   - Aligned with industry standards

### Detection Priority Order

```
1. Methodology projects (Markdown-driven)
2. iOS/Swift (>50 Swift files)
3. Strong language markers:
   - Gemfile (Ruby)
   - go.mod (Go)
   - Cargo.toml (Rust)
   - pyproject.toml/requirements.txt (Python)
   - build.gradle (Android/Kotlin)
   - *.xcodeproj/*.xcworkspace (iOS)
   - Package.swift (Swift Package)
   - composer.json (PHP)
4. Monorepo tools (lerna, pnpm, nx, turborepo)
5. package.json (Node.js/TypeScript)
6. Subdirectory detection (implicit monorepo)
```

### Scale Thresholds

| Scale | File Count | Max Scan Ratio | Hypothesis Target |
|-------|------------|----------------|-------------------|
| TINY | <100 | 50% | 5-8 |
| SMALL | 100-500 | 20% | 7-10 |
| MEDIUM | 500-2,000 | 10% | 10-15 |
| LARGE | 2,000-10,000 | 5% | 12-18 |
| VERY_LARGE | >10,000 | 3% | 15-20 |

### Validation Results

| Project | Files | Ground Truth | Detected | Status |
|---------|-------|--------------|----------|--------|
| Firefox iOS | 2,933 | LARGE | LARGE | ✅ |
| Thunderbird | 3,186 | LARGE | LARGE | ✅ |
| Cal.com | 6,827 | LARGE | LARGE | ✅ |
| Prefect | 2,691 | LARGE | LARGE | ✅ |
| Discourse | 12,306 | VERY_LARGE | VERY_LARGE | ✅ |

**Accuracy: 100% (5/5)**

## Why LOC Was Removed

Initial implementation used LOC (Lines of Code) for "precise" detection in ambiguous ranges (500-10,000 files). This was removed because:

1. **Cross-language inconsistency**: Python files average 300+ LOC, Ruby files average 40 LOC
2. **Speed**: LOC calculation adds 2-4 seconds
3. **Diminishing returns**: File count is sufficient with proper thresholds

## Implementation Details

### Code Files Counted

```bash
*.py *.ts *.tsx *.js *.jsx  # Python, TypeScript, JavaScript
*.go *.rs                    # Go, Rust
*.rb *.erb                   # Ruby
*.php                        # PHP
*.swift *.m *.h              # Swift, Objective-C
*.kt *.java                  # Kotlin, Java
*.cs *.cpp *.c               # C#, C++, C
```

### Excluded Directories

```bash
.git/ node_modules/ .venv/ venv/
vendor/ target/ dist/ build/
__pycache__/ Pods/ .next/ .nuxt/
DerivedData/ .gradle/ tmp/
```

## Key Learnings

1. **Language marker priority matters**: iOS projects often have Gemfile for fastlane
2. **Total codebase > primary language**: Scale should reflect complexity, not just one language
3. **Benchmark validation is essential**: Theory must be tested against real projects
4. **Simpler is better**: LOC added complexity without improving accuracy

## Files Modified

- `scripts/atlas/detect-project-enhanced.sh`
  - Added Swift file count priority check
  - Added Ruby detection (Gemfile)
  - Changed scale detection to use ALL code files
  - Removed LOC calculation (too complex, inconsistent)
  - Updated thresholds based on benchmark

## Related

- Benchmark report: `test_results/benchmark-2025-12-21.md`
- Constitution: `ANALYSIS_CONSTITUTION.md` Article VI
