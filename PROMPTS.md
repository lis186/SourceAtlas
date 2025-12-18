# SourceAtlas - Complete Prompts

**Current Status**:
- **v1.0** ✅ - Methodology validated (5 projects tested)
- **v2.9.3** ✅ - All core Commands completed (7 commands)

**Version**: v2.9.3
**Last Updated**: 2025-12-18
**Author**: SourceAtlas Team
**Validation Projects**: trySwiftTokyoApp, taiwan-calendar, monorepo-sample, sample-projects (5 projects)

---

## 🚀 v2.9 Commands (Recommended for Daily Use)

v2.9 provides 7 Claude Code slash commands for quick daily analysis:

| Command | Purpose | Time |
|---------|---------|------|
| `/atlas.init` | Initialize project, inject auto-trigger rules | <1 min |
| `/atlas.overview` | Quick project fingerprint (Stage 0 lite) | 5-10 min |
| `/atlas.pattern [type]` | Learn specific design patterns | 5-10 min |
| `/atlas.impact [target]` | Analyze code change impact scope | 5-10 min |
| `/atlas.history [scope]` | Git history temporal analysis (Hotspots, Coupling) | 5-10 min |
| `/atlas.flow [entry]` | Flow tracing (11 analysis modes) | 5-10 min |
| `/atlas.deps [library]` | Dependency analysis (upgrade impact assessment) | 5-10 min |

**When to Use**:
- ✅ Quick codebase understanding during daily development
- ✅ Learning project design patterns
- ✅ Assessing modification impact scope
- ✅ Tracing business flows and data flows
- ✅ Pre-upgrade assessment for Library/Framework

**Complete Documentation**: See individual command files in `.claude/commands/` directory

---

## 📋 Manual Three-Stage Prompts (For Deep Analysis)

The following complete three-stage manual Prompts are suitable for deep analysis scenarios:
- Technical Due Diligence
- Hiring Assessment (evaluating developer capabilities)
- Deep learning of open source projects
- Complete project audit

---

## 📖 Overview

SourceAtlas provides three-stage codebase analysis Prompts, designed based on information theory principles to achieve maximum understanding depth with minimal file scanning.

**v2.9 Commands vs Manual Prompts**:
- **Commands** (daily use): Fast, automated, concise output
- **Prompts** (deep analysis): Complete three-stage, detailed reports, hypothesis validation

### Three-Stage Design Philosophy

| Stage | Name | Goal | Token Usage | Understanding Depth |
|-------|------|------|------------|-------------------|
| **Stage 0** | Project Fingerprint | Quickly establish project outline | ~20k | 70-80% |
| **Stage 1** | Hypothesis Validation | Validate Stage 0 inferences | ~30k | 85-95% |
| **Stage 2** | Git Hotspots Analysis | Identify development patterns and evolution | ~20k | 95%+ |

**Core Advantages**:

- ✅ Scan <5% of files to achieve 70-80% understanding
- ✅ Save 95%+ time and Tokens
- ✅ Systematic analysis process
- ✅ Repeatable, verifiable results

---

## 🎯 Stage 0: Project Fingerprint

### Goal

Establish a complete project outline in the shortest time, including:

- Technology stack identification
- Architecture pattern inference
- Business domain analysis
- Initial developer capability assessment
- Key hypothesis generation (for Stage 1 validation)

### Core Philosophy

**Information Theory Foundation**:

- Prioritize high-entropy files
- Small number of key files contain large amounts of information
- Structural files are more valuable than code

**High-Entropy File Priorities**:

1. **Configuration files** (package.json, composer.json, Cargo.toml, go.mod)
2. **Documentation files** (README.md, CLAUDE.md, architecture docs)
3. **Directory structure** (ls -R, tree)
4. **Model/Entity files** (core of business domain)
5. **Type definitions** (api.ts, types.ts, interfaces.go)

### Prompt Template

```markdown
# SourceAtlas Stage 0: Project Fingerprint Analysis

You are a senior software architecture analyst specializing in quickly understanding large codebases. Your task is to establish a complete project outline by scanning the minimum number of files based on information theory.

## 📋 Analysis Goal

Please perform project fingerprint analysis on directory `[PROJECT_PATH]`, with the goal of scanning <5% of files to achieve 70-80% understanding depth.

## 🔍 Analysis Process

### Phase 1: Quick Scan (High-Entropy Files First)

**Step 1: Identify Project Type and Tech Stack**
- Scan configuration files in root directory:
  - `package.json` (Node.js/TypeScript)
  - `composer.json` (PHP/Laravel)
  - `Cargo.toml` (Rust)
  - `go.mod` (Go)
  - `pom.xml` / `build.gradle` (Java)
  - `requirements.txt` / `pyproject.toml` (Python)
  - `*.csproj` (C#/.NET)

**Step 2: Read Project Documentation**
- `README.md` (project overview)
- `CLAUDE.md` / `.cursor/rules/` (AI development standards)
- Technical documentation (architecture diagrams, deployment guides)

**Step 3: Scan Project Structure**
```bash
# Get directory structure
ls -R [PROJECT_PATH]

# Or use tree (if available)
tree -L 3 [PROJECT_PATH]

# Count file types
find [PROJECT_PATH] -type f | grep -E "\.(ts|tsx|js|jsx|php|go|rs|py|java)$" | wc -l
```

**Step 4: Identify Business Domain (Scan Models/Entities)**

- Laravel: `app/Models/*.php`
- Rails: `app/models/*.rb`
- Go: `**/models/*.go` or `**/entities/*.go`
- TypeScript: `**/types/*.ts` or `**/models/*.ts`

Read 3-5 core Model files to understand:

- Business entities (User, Product, Order, etc.)
- Relationships (hasMany, belongsTo)
- Business logic (methods, calculated fields)

**Step 5: Scan Key Architecture Files**

- Controllers/Handlers: Read 1-2 examples
- Services: Check if there's a Service Layer
- Routes/API definitions: Understand API architecture

### Phase 2: Inference and Hypothesis Generation

Based on Phase 1 information, make the following inferences:

**Tech Stack Inference**:

- Frontend framework (React, Vue, Svelte)
- Backend framework (Laravel, Rails, Go Gin)
- Database type (MySQL, PostgreSQL, MongoDB)
- Testing framework (Jest, PHPUnit, pytest)
- Deployment method (Docker, Cloud, traditional)

**Architecture Pattern Inference**:

- MVC, MVVM, MVP, Clean Architecture
- Repository Pattern, Service Layer
- Factory/DIContainer, Use Case/Interactor
- Router (API/Navigation), Middleware
- Policy-based Authorization

**iOS Specific Patterns** (34 patterns supported):
- **SwiftUI**: ObservableObject, Reducer (TCA), Router
- **UIKit**: Protocol/Delegate, UICollectionViewLayout, Animation
- **Architecture**: Repository, Service Layer, Use Case/Interactor, Factory/DIContainer
- **State Management**: Reducer (TCA), Middleware (Redux), ObservableObject
- **Support**: Cache, Theme/Style, Environment/Configuration, Localization, Mock/Stub
- **Modern**: async/await, Combine/Publisher (requires content analysis)

**Code Quality Inference**:

- Test coverage (estimate)
- Comment density
- Type safety level
- Error handling completeness

**Initial Developer Capability Assessment**:

- Years of experience (based on code complexity)
- Git habits (commit frequency and quality)
- Documentation skills
- Architecture thinking

**Generate 10-15 Hypotheses** (for Stage 1 validation):

- Each hypothesis includes:
  - Hypothesis statement
  - Confidence level (0.0-1.0)
  - Validation method
  - Reasoning basis

### Phase 3: Generate YAML Format Report

Output format: `[project-name]-stage0-fingerprint.yaml`

```yaml
# stage0-fingerprint.yaml - [Project Name]

metadata:
  project_name: [Name]
  developer: [GitHub Username / Name]
  scan_time: [ISO 8601 timestamp]
  scanned_files: [number]
  total_files_estimate: [estimated total]
  total_lines_estimate: [estimated lines]
  git_commits: [number]
  development_period: [time span]

## Project Fingerprint

project_type: [WEB_APP | CLI_TOOL | LIBRARY | MOBILE_APP | ...]
primary_purpose: [one-sentence description]
architecture: [MVC | CLEAN_ARCHITECTURE | MICROSERVICES | ...]
scale: [SMALL <10k | MEDIUM 10-50k | LARGE 50-100k | SUPER_LARGE >100k]
complexity: [LOW | MEDIUM | HIGH | ENTERPRISE_GRADE]
maturity: [PROTOTYPE | DEVELOPMENT | PRODUCTION_READY]

## Core Tech Stack

### Frontend (if any)
framework: [React | Vue | Svelte | ...]
language: [TypeScript | JavaScript]
version: [version]
ui_library: [Material-UI | Tailwind | ...]
state_management: [Redux | Context API | ...]

key_packages:
  - [package-name]: [version] (description)
  - ...

### Backend
framework: [Laravel | Rails | Django | ...]
language: [PHP | Ruby | Python | ...]
version: [version]

key_packages:
  - [package-name]: [version] (description)
  - ...

database:
  type: [MySQL | PostgreSQL | MongoDB]
  orm: [Eloquent | ActiveRecord | SQLAlchemy]

authentication: [JWT | Session | OAuth]

## Project Architecture Inference

architecture_pattern: [specific pattern]
  layers:
    - [Layer 1]: [responsibility]
    - [Layer 2]: [responsibility]
    - ...

  confidence: [0.0-1.0]
  evidence:
    - [evidence 1]
    - [evidence 2]

  note: |\
    [detailed explanation]

[other architecture patterns...]

## Business Domain Analysis

business_domain: [domain name]
  core_modules:
    - [module 1]
    - [module 2]
    - ...

data_models_identified: [number] Models
  complexity: [SIMPLE | MEDIUM | COMPLEX | VERY_HIGH]
  relationships: [SIMPLE | COMPLEX]

  key_models:
    - [Model 1]: [description]
    - [Model 2]: [description]
    - ...

## Code Quality Initial Assessment

estimated_test_coverage: [0-100]%
  evidence:
    - [number of test files]
    - [testing framework]
  confidence: [0.0-1.0]

code_organization: [POOR | FAIR | GOOD | EXCELLENT]
  evidence:
    - [clear directory structure]
    - [layered architecture]

comment_density: [0-100]%
  style: [none | concise | detailed | tutorial]

type_safety: [NONE | PARTIAL | STRONG | STRICT]
  evidence:
    - [TypeScript usage]
    - [type annotation coverage]

## AI-Assisted Development Evidence (if any)

ai_assisted_development: [NONE | SUSPECTED | CONFIRMED]
  confidence: [0.0-1.0]
  evidence:
    - file: [AI config file path]
    - [other evidence]

  key_characteristics:
    - [characteristic 1]: [description]
    - [characteristic 2]: [description]

## Developer Capability Initial Assessment

developer_profile:
  skill_level: [BEGINNER | INTERMEDIATE | SENIOR | EXPERT]
  estimated_experience: [time range]

  strengths:
    - [strength 1]
    - [strength 2]

  weaknesses:
    - [weakness 1]
    - [weakness 2]

## Important Files Inference (sorted by information value)

high_priority_files:
  tier_0_critical:
    - file: [path]
      lines: [line count]
      reason: [why important]
      information_density: [LOW | MEDIUM | HIGH | VERY_HIGH | EXTREME]

  tier_1_architecture:
    - file: [path]
      ...

  [other tiers...]

## Hypothesis List (for Stage 1 validation)

hypotheses:
  [category_1]:
    - hypothesis: [hypothesis statement]
      confidence: [0.0-1.0]
      validation_method: [how to validate]
      reasoning: [reasoning basis]

    - hypothesis: [next hypothesis]
      ...

  [category_2]:
    ...

## Next Step Validation Plan

stage1_focus_areas:
  priority_1:
    - [validation item 1]
    - [validation item 2]

  priority_2:
    ...

estimated_understanding: [0-100]%
  note: |\
    [explain understanding level and uncertainties]

## Information Theory Assessment

total_files: [total]
scanned_files: [scanned]
scan_ratio: [percentage]

information_gained: [0-100]%
  reasoning: |\
    [explain why scanning these files gains so much information]

time_saved: [percentage]
  traditional_approach: [time needed for traditional approach]
  this_approach: [time needed for this approach]
  saved_time: [percentage saved]

confidence_score: [0.0-1.0]
  note: |\
    [confidence assessment of analysis results]

next_stage_preparation: [READY | NEED_MORE_INFO]
  [explanation]
```

## ⚠️ Important Principles

1. **High-Entropy First**: Always scan config files, README, Models first
2. **Avoid Deep Code**: Don't get stuck reading lots of business logic code
3. **Structure Over Content**: Directory structure more important than individual file content
4. **Bold Inferences**: Make reasonable inferences based on limited information
5. **Explicit Hypotheses**: Generate verifiable hypotheses for Stage 1
6. **Save Tokens**: Goal is to scan <5% of files to achieve 70-80% understanding

## 📊 Validation Criteria

A good Stage 0 analysis should:

- ✅ Scan <5% of total files
- ✅ Achieve 70-80% understanding depth
- ✅ Generate 10-15 verifiable hypotheses
- ✅ Clearly identify tech stack
- ✅ Infer architecture patterns
- ✅ Assess developer capabilities
- ✅ Use <20k tokens

## 🎓 Example References

Check these actual analysis examples:

- `test_results/trySwift-stage0-fingerprint.yaml`
- `test_results/taiwan-calendar-stage0-fingerprint.yaml`
- `test_results/sample-project-stage0-fingerprint.yaml`

```

---

## 🔬 Stage 1: Hypothesis Validation

### Goal

Systematically validate hypotheses generated in Stage 0, through precise file reading and code searching, to elevate understanding depth from 70-80% to 85-95%.

### Core Philosophy

**Bayesian Reasoning**:
- Stage 0 provides prior probability
- Stage 1 provides evidence
- Update posterior probability

**Precise Validation**:
- Each hypothesis must find clear evidence
- Evidence can be: file existence, code snippets, statistical data
- Record validation process and results

### Prompt Template

```markdown
# SourceAtlas Stage 1: Hypothesis Validation

You are a rigorous software analyst specializing in validating technical hypotheses. Your task is to systematically validate hypotheses generated in Stage 0.

## 📋 Validation Goal

Systematically validate hypotheses in Stage 0 report `[STAGE0_REPORT_PATH]`.

## 🔍 Validation Process

### Phase 1: Read Stage 0 Report

```bash
# Read Stage 0 report
cat [STAGE0_REPORT_PATH]
```

Extract all hypotheses (hypotheses section), establish validation checklist.

### Phase 2: Systematic Validation

For each hypothesis, execute the following validation steps:

**Validation Template**:

```
Hypothesis: [hypothesis statement]
Initial confidence: [0.0-1.0]
Validation method: [specific method]

Execute validation:
[specific commands or operations]

Evidence:
[found evidence]

Result: [✅ Confirmed | ⚠️ Partially confirmed | ❌ Refuted]
Updated confidence: [0.0-1.0]

Explanation:
[detailed explanation of why confirmed or refuted]
```

### Phase 3: Validation Method Guide

**Architecture Validation**:

```bash
# Check if directory exists
test -d [PATH] && echo "EXISTS" || echo "NOT_FOUND"

# List directory contents
ls -la [PATH]

# Count files
find [PATH] -name "*.php" | wc -l
```

**Code Pattern Validation**:

```bash
# Search for specific pattern
grep -r "[PATTERN]" [PATH] --include="*.ts"

# Count occurrences
grep -r "[PATTERN]" [PATH] | wc -l

# Find files using this pattern
grep -rl "[PATTERN]" [PATH]
```

**Type Safety Validation**:

```bash
# Search for 'any' type
grep -r ": any\|as any" src/ --include="*.ts" | wc -l

# Search for @ts-ignore
grep -r "@ts-ignore" src/ --include="*.ts"
```

**Test Validation**:

```bash
# Count test files
find . -name "*.test.*" -o -name "*.spec.*" | wc -l

# Check test configuration
ls jest.config.* vitest.config.* phpunit.xml
```

**Git Validation**:

```bash
# Check commit format
git log --oneline -30

# Count Conventional Commits
git log --format="%s" | grep -E "^(feat|fix|docs|style|refactor|test|chore):" | wc -l

# Analyze commit frequency
git log --format="%ad" --date=short | sort | uniq -c
```

### Phase 4: Generate Validation Report

Output format: `[project-name]-stage1-validation.md`

```markdown
# Stage 1: Hypothesis Validation Report - [Project Name]

**Validation Time**: [ISO 8601]
**Project**: [name]
**Original Hypothesis Count**: [number]

---

## 📊 Validation Results Summary

| Category | Hypothesis Count | ✅ Confirmed | ⚠️ Partially Confirmed | ❌ Refuted | Accuracy |
|----------|-----------------|-------------|----------------------|-----------|----------|
| [Category1] | [count] | [count] | [count] | [count] | [%] |
| [Category2] | [count] | [count] | [count] | [count] | [%] |
| **Total** | [count] | [count] | [count] | [count] | [%] |

---

## ✅ Confirmed Hypotheses ([count]/[total])

### [Category Name]

#### ✅ H1: [hypothesis statement]
- **Initial confidence**: [0.0-1.0]
- **Validation result**: ✅ **Confirmed**
- **Evidence**:
  - [evidence1]
  - [evidence2]
- **Validation method**:
  ```bash
  [commands used]
  ```

- **Findings**: [detailed explanation]

#### ✅ H2: [next hypothesis]

...

---

## ⚠️ Partially Confirmed Hypotheses ([count]/[total])

#### ⚠️ H3: [hypothesis statement]

- **Initial confidence**: [0.0-1.0]
- **Validation result**: ⚠️ **Partially confirmed**
- **Evidence**:
  - [supporting evidence]
  - [contradicting evidence]
- **Updated confidence**: [0.0-1.0]
- **Explanation**: [why only partially confirmed]

---

## ❌ Refuted Hypotheses ([count]/[total])

#### ❌ H4: [hypothesis statement]

- **Initial confidence**: [0.0-1.0]
- **Validation result**: ❌ **Refuted**
- **Counter-evidence**:
  - [counter-evidence1]
  - [counter-evidence2]
- **Actual situation**: [what's the real situation]
- **Why refuted**: [detailed explanation]

---

## 🔍 Key Findings

### 1. [Important finding1]

- **Impact**: [HIGH | MEDIUM | LOW]
- **Description**: [detailed description]

### 2. [Important finding2]

...

---

## 📈 Validation Accuracy Analysis

### Overall Accuracy: [%] ([confirmed count]/[total])

### Category Accuracy

1. **[Category1]**: [%] ([confirmed count]/[category count])
2. **[Category2]**: [%]
...

### Why were some hypotheses refuted?

**Reason analysis**:

### Improvements to Validation Methods

**Successful methods**:

- ✅ [method1]
- ✅ [method2]

**Failed methods**:

- ❌ [method1]: [why it failed]
- ❌ [method2]: [why it failed]

---

## 💡 Improvement Suggestions for Stage 0

Based on validation results, suggest Stage 0 improvements:

1. [improvement suggestion1]
2. [improvement suggestion2]
...

---

## 🎯 Updated Project Understanding

Based on validation results, update project understanding:

### Tech Stack (updated)

- [corrections or additions]

### Architecture Patterns (updated)

- [corrections or additions]

### Code Quality (updated)

- [corrections or additions]

### Developer Capabilities (updated)

- [corrections or additions]

---

## 📋 Appendix: Validation Command List

```bash
# [Category1] validation
[command1]
[command2]

# [Category2] validation
[command3]
[command4]
```

---

**Report Completion Time**: [ISO 8601]
**Understanding Depth**: [85-95]%
**Confidence Level**: [0.0-1.0]

```

## ⚠️ Important Principles

1. **Evidence must be clear**: Every conclusion needs concrete evidence
2. **Admit uncertainty**: Mark hypotheses that can't be validated as "need more information"
3. **Record validation process**: Write down commands used for reproducibility
4. **Objective assessment**: Don't ignore counter-evidence just to confirm
5. **Update understanding**: Update project understanding based on validation results

## 📊 Validation Criteria

A good Stage 1 validation should:
- ✅ Validate all Stage 0 hypotheses
- ✅ Each conclusion has clear evidence
- ✅ Accuracy >80%
- ✅ Identify incorrect Stage 0 inferences
- ✅ Update understanding depth to 85-95%
- ✅ Use <30k tokens

## 🎓 Example References

Check these actual validation examples:
- `test_results/trySwift-stage1-validation.md`
- `test_results/taiwan-calendar-stage1-validation.md`
- `test_results/sample-project-stage1-validation.md`
```

---

## 📊 Stage 2: Git Hotspots Analysis

### Goal

Through Git history analysis, identify:

- Development patterns and rhythm
- Code hotspots (most frequently modified files)
- Developer capabilities and habits
- AI collaboration evidence
- Technical debt management patterns
- Project evolution timeline

### Core Philosophy

**Git is a time capsule of development history**:

- Commit patterns reflect development habits
- File modification frequency reflects architecture hotspots
- Commit messages reflect thinking patterns
- Time distribution reflects development rhythm

### Prompt Template

```markdown
# SourceAtlas Stage 2: Git Hotspots Analysis

You are an analyst specializing in software archaeology, skilled at mining insights from Git history. Your task is to analyze the project's Git history to identify development patterns and evolution.

## 📋 Analysis Goal

Analyze Git history of project `[PROJECT_PATH]` to identify development hotspots and patterns.

## 🔍 Analysis Process

### Phase 1: Git History Statistics

**Basic Statistics**:
```bash
# Total commit count
git log --all --oneline | wc -l

# Development time span
git log --all --format="%ad" --date=short | sort | uniq | head -1
git log --all --format="%ad" --date=short | sort | uniq | tail -1

# Author statistics
git log --all --format="%an <%ae>" | sort | uniq

# Commit count per author
git log --all --format="%an" | sort | uniq -c | sort -rn

# Monthly commit statistics
git log --all --format="%ad" --date=format:"%Y-%m" | sort | uniq -c
```

**Commit Time Analysis**:

```bash
# Commits in last 30 days
git log --all --since="30 days ago" --oneline | wc -l

# Daily commit distribution
git log --all --format="%ad" --date=short | sort | uniq -c | tail -20

# Hourly commit distribution (identify work hours)
git log --all --format="%ad" --date=format:"%H" | sort | uniq -c
```

### Phase 2: File Hotspot Analysis

**Most Frequently Modified Files**:

```bash
# Top 20 most modified files
git log --all --name-only --format="" | sort | uniq -c | sort -rn | head -20

# Modification frequency for specific directory
git log --all --name-only --format="" -- [PATH]/ | sort | uniq -c | sort -rn
```

**Code Change Volume Analysis**:

```bash
# Total code change statistics
git log --all --numstat --format="" | awk 'NF==3 {plus+=$1; minus+=$2} END {
  printf "Total added: %d\nTotal removed: %d\nNet change: %d\n", plus, minus, plus-minus
}'

# Largest single changes
git log --all --numstat --format="%H %s" |
  awk 'NF==3 {files++; added+=$1; deleted+=$2}
       NF!=3 && files>0 {printf "%d files, +%d -%d | %s\n", files, added, deleted, $0; files=added=deleted=0}'|
  sort -rn | head -10
```

### Phase 3: Commit Message Analysis

**Commit Format Analysis**:

```bash
# Conventional Commits statistics
git log --all --format="%s" | grep -E "^(feat|fix|docs|style|refactor|test|chore|perf):" | wc -l

# Commit message length distribution
git log --all --format="%s" | awk '{print length}' | sort -n | uniq -c

# Most common commit prefixes
git log --all --format="%s" | grep -oE "^[a-z]+:" | sort | uniq -c | sort -rn
```

**Development Pattern Identification**:

```bash
# Find refactor commits
git log --all --grep="refactor" --oneline | wc -l

# Find bug fixes
git log --all --grep="fix\|bug\|Fix\|Bug" --oneline | wc -l

# Find new features
git log --all --grep="feat\|feature\|add" --oneline | wc -l

# Find technical debt related
git log --all --grep="debt\|todo\|cleanup" --oneline
```

### Phase 4: Developer Behavior Analysis

**Multi-Author Projects**:

```bash
# Code contribution per author
git log --all --numstat --format="%an" |
  awk '{if (NF==1) author=$0; else {files[author]++; added[author]+=$1; deleted[author]+=$2}}
       END {for (a in files) printf "%s: %d files, +%d -%d\n", a, files[a], added[a], deleted[a]}' |
  sort -t: -k2 -rn

# Active period per author
for author in $(git log --all --format="%an" | sort -u); do
  echo "=== $author ==="
  git log --all --author="$author" --format="%ad" --date=short | sort | uniq -c | tail -10
done
```

**Single Author Multi-Environment Detection**:

```bash
# Check if same person uses multiple emails/environments
git log --all --format="%an|%ae|%cn|%ce" | sort -u
```

### Phase 5: AI Collaboration Evidence Analysis

**AI Code Characteristics**:

```bash
# Search for AI config file modifications
git log --all --name-only --format="" | grep -E "(\.claude|\.cursor|CLAUDE\.md|\.ai)"

# Analyze commit message consistency (AI is usually very consistent)
git log --all --format="%s" | head -50

# Search for possible AI-generated code markers
git log --all --grep="AI\|Claude\|GPT\|generated" --oneline

# Check Traditional Chinese usage in commit messages
git log --all --format="%s" | grep -E "[\u4e00-\u9fff]" | wc -l
```

### Phase 6: Generate Analysis Report

Output format: `[project-name]-stage2-git-hotspots.md`

```markdown
# Stage 2: Git Hotspots Analysis Report - [Project Name]

**Analysis Time**: [ISO 8601]
**Project**: [name]
**Total Commits**: [count]
**Analysis Scope**: [time span]

---

## 📊 Overall Statistics

### Development Timeline
```

Start date: [YYYY-MM-DD]
End date: [YYYY-MM-DD]
Total development time: [X months/weeks]
Total Commits: [count]
Average daily Commits: [count]

```

### Code Change Volume
```

Total lines added: [count]
Total lines removed: [count]
Net growth: [count]
Efficiency ratio: [add/delete ratio]

```

### Developer Statistics
```

[Author1]: [X] commits ([Y]%)
[Author2]: [X] commits ([Y]%)
...

```

---

## 🔥 File Hotspot Analysis

### Top 20 Most Modified Files

| Rank | File | Modifications | Type | Description |
|------|------|--------------|------|-------------|
| 1 | [path] | [count] | [config/business/test] | [description] |
| 2 | ... | ... | ... | ... |

### Hotspot Categories

#### 🚀 Deployment & DevOps Hotspots ([X]% of changes)
- [file1]: [description]
- [file2]: [description]

#### 📦 Dependency Management Hotspots ([X]% of changes)
- [file1]: [description]

#### 🛠️ Business Logic Hotspots ([X]% of changes)
- [file1]: [description]

#### 📝 Documentation & Config Hotspots ([X]% of changes)
- [file1]: [description]

---

## 📅 Timeline Analysis

### Phase 1: [phase name] ([start] ~ [end])

**Time span**: [X] days
**Commits**: [count]
**Main activities**:
- [activity1]
- [activity2]

**Peak days**:
- [date]: [X] commits
- [date]: [X] commits

**Representative Commits**:
```

[hash] [message]
[hash] [message]

```

### Phase 2: [next phase]
...

---

## 🎯 Development Pattern Analysis

### Commit Message Standards

**Format statistics**:
- Conventional Commits: [X]% ([count]/[total])
- Traditional format: [X]%
- No standard: [X]%

**Common prefixes**:
```

feat:     [X] commits ([Y]%)
fix:      [X] commits ([Y]%)
refactor: [X] commits ([Y]%)
...

```

### Development Rhythm

**Average development pattern**:
- Weekdays: [X] commits/day
- Weekends: [X] commits/day
- Peak hours: [time range]

**Work hours analysis**:
```

[analyze developer's work time preferences]

```

### Refactoring Frequency

**Refactoring statistics**:
- Explicit refactor commits: [count]
- Refactor ratio: [X]%
- Average 1 refactor per [X] commits

**Refactoring types**:
- [type1]: [count]
- [type2]: [count]

---

## 🤖 AI Collaboration Evidence

### AI Configuration Files

**Discovered AI-related files**:
- [file1]: [first appearance date]
- [file2]: [first appearance date]

**AI collaboration timeline**:
```

[describe introduction and evolution of AI collaboration]

```

### AI Code Characteristics

**Commit Message Characteristics**:
- Consistency: [HIGH | MEDIUM | LOW]
- Detail level: [detailed | medium | concise]
- Format compliance: [X]% follow Conventional Commits

**Code characteristics**:
- [characteristic1]: [evidence]
- [characteristic2]: [evidence]

**AI Collaboration Maturity**: [Level 0-4]
- [assessment basis]

---

## 💡 Key Insights

### 1. [Insight1]
- **Finding**: [description]
- **Evidence**: [data or commits]
- **Impact**: [explain impact]

### 2. [Insight2]
...

---

## 📈 Developer Capability Assessment (Based on Git History)

### Commit Quality
- **Message quality**: [excellent | good | fair | poor]
- **Commit granularity**: [appropriate | too large | too small]
- **Standard compliance**: [X]%

### Development Habits
- **Commit frequency**: [high | medium | low]
- **Refactoring awareness**: [strong | medium | weak]
- **Technical debt management**: [excellent | good | fair | lacking]

### Problem-Solving Ability
- **Bug fix patterns**: [description]
- **Debugging efficiency**: [high | medium | low]
- **Sustained focus**: [able to sustain focus]

---

## 📋 Stage 2 Summary

### Core Findings

1. [Finding1]
2. [Finding2]
3. [Finding3]

### SourceAtlas Validation

- ✅ **Git hotspot analysis effectiveness**: [assessment]
- ✅ **Development pattern identification**: [assessment]
- ✅ **AI collaboration identification**: [assessment]

---

**Report Completion Time**: [ISO 8601]
**Analysis Depth**: [95]%+
**Confidence Level**: [0.0-1.0]
```

## ⚠️ Important Principles

1. **Timeline reconstruction**: Understand how the project evolved
2. **Pattern recognition**: Find repeated development patterns
3. **Objective analysis**: Based on data, not subjective judgments
4. **Completeness**: Analyze entire Git history, not just recent
5. **Context**: Understand Git history combined with Stage 0-1 results

## 📊 Analysis Criteria

A good Stage 2 analysis should:

- ✅ Complete timeline reconstruction
- ✅ Identify all key phases
- ✅ Find file hotspots
- ✅ Analyze development patterns
- ✅ Assess AI collaboration evidence
- ✅ Use <20k tokens

## 🎓 Example References

Check these actual analysis examples:

- `test_results/trySwift-stage2-git-hotspots.md`
- `test_results/taiwan-calendar-stage2-git-hotspots.md`
- `test_results/sample-project-stage2-git-hotspots.md`

```

---

## 📚 Complete Workflow

### Standard Analysis Process

```

1. Stage 0: Project Fingerprint
   ↓ (generate 10-15 hypotheses)

2. Stage 1: Hypothesis Validation
   ↓ (validate hypotheses, update understanding)

3. Stage 2: Git Hotspots Analysis
   ↓ (identify development patterns)

4. Comprehensive Report
   (integrate three-stage results)

```

### When to Skip a Stage?

**Can skip Stage 2**:
- Project has no Git history
- Project has only 1-2 commits
- Git history not important (e.g., forked projects)

**Can simplify Stage 1**:
- Stage 0 confidence >90%
- Project extremely simple (<500 lines)

**Cannot skip Stage 0**:
- Stage 0 is the necessary foundation

### Applicable Scenarios

| Code Scale | Recommended Stages | Reason |
|------------|-------------------|--------|
| <500 lines | Stage 0 only | Faster to read entire project |
| 500-2000 lines | Stage 0-1 | Stage 2 provides little value |
| 2000-10k lines | Stage 0-2 | Complete three-stage |
| 10k-100k lines | Stage 0-2 | Complete three-stage |
| >100k lines | Stage 0-2 | Must use, saves significant time |

---

## 🎯 Effectiveness Evaluation

Based on actual testing (trySwift, taiwan-calendar, monorepo-sample, sample-projects):

| Metric | Target | Actual | Achieved |
|--------|--------|--------|----------|
| **Stage 0 Accuracy** | >70% | 75-95% | ✅ |
| **Stage 1 Validation Rate** | >80% | 87-100% | ✅ |
| **Token Savings** | >80% | 95%+ | ✅ |
| **Time Savings** | >90% | 95%+ | ✅ |
| **Understanding Depth** | >85% | 85-95% | ✅ |

### Success Stories

1. **monorepo-sample** (156k lines)
   - Scanned <5% of files to achieve 75% understanding
   - Stage 1 validation rate 87%
   - Identified Level 3 AI collaboration

2. **taiwan-calendar** (15k lines)
   - Stage 0 accuracy 100%
   - Completely identified architecture and test culture

3. **sample-projects** (5 projects)
   - Quickly identified capability weaknesses (data persistence)
   - Accurately assessed years of experience

---

## 📖 Further Reading

- `USAGE_GUIDE.md` - Detailed usage guide
- `EVALUATION_STANDARDS.md` - Evaluation standards system
- `test_results/` - Actual analysis case studies
- `THREE-WAY-DEVELOPER-COMPARISON.md` - Developer comparison study

---

## 🔄 When to Use Which Approach?

| Scenario | Recommended Approach | Reason |
|----------|---------------------|--------|
| Daily codebase understanding | `/atlas.overview` | Fast, automated |
| Learning design patterns | `/atlas.pattern` | Precise, actionable |
| Assessing change impact | `/atlas.impact` | Static dependency analysis |
| Tracing business flows | `/atlas.flow` | 11 analysis modes |
| Library upgrade assessment | `/atlas.deps` | Breaking change comparison |
| Technical due diligence | Manual Stage 0-1-2 | Complete hypothesis validation |
| Hiring assessment | Manual Stage 0-1-2 | Need Git analysis |
| Deep learning open source projects | Manual Stage 0-1-2 | Complete three-stage report |

---

**Documentation Version**: v2.9.3
**Last Updated**: 2025-12-18
**Maintainer**: SourceAtlas Team
