---
description: Quick project mapping - scan <5% of files to achieve 70-80% understanding
allowed-tools: Bash, Glob, Grep, Read
argument-hint: [optional: specific directory to analyze, e.g., "src/api"]
---

# SourceAtlas: Project Map (Stage 0 Fingerprint)

## Context

**Analysis Target**: ${ARGUMENTS:-.}

**Goal**: Generate a comprehensive project fingerprint by scanning <5% of files to achieve 70-80% understanding in 10-15 minutes.

---

## Your Task

Execute **Stage 0 Analysis Only** - create a project map using information theory principles.

### Phase 1: Project Detection (2-3 minutes)

Detect project type and collect basic statistics:

```bash
# Run helper script (if available)
bash scripts/atlas/detect-project.sh ${ARGUMENTS:-.} 2>/dev/null || {
  # Fallback: manual detection
  echo "=== Project Files Detection ==="
  find ${ARGUMENTS:-.} -maxdepth 3 -type f \( \
    -name "package.json" -o \
    -name "composer.json" -o \
    -name "Gemfile" -o \
    -name "go.mod" -o \
    -name "Cargo.toml" -o \
    -name "requirements.txt" -o \
    -name "pyproject.toml" -o \
    -name "pom.xml" \
  \) 2>/dev/null

  echo ""
  echo "=== Directory Structure ==="
  tree -L 2 -d ${ARGUMENTS:-.} 2>/dev/null || \
    find ${ARGUMENTS:-.} -maxdepth 2 -type d | head -20
}
```

### Phase 2: High-Entropy File Prioritization (5-8 minutes)

Apply information theory - **high-entropy files contain disproportionate information**.

**Scan Priority Order**:

1. **Documentation** (Highest entropy)
   - README.md, CLAUDE.md, CONTRIBUTING.md
   - docs/, documentation/

2. **Configuration Files** (Project-level decisions)
   - package.json, composer.json, Gemfile, etc.
   - Config files in root
   - docker-compose.yml, Dockerfile

3. **Core Models** (Data structure - scan 3-5 only)
   - models/, entities/, domain/
   - Pick the most important ones

4. **Entry Points** (Architecture patterns - scan 1-2 examples)
   - Controllers, Routes, API definitions
   - main.*, index.*, app.*

5. **Tests** (Development practices - scan 1-2 examples)
   - Key test files to understand testing approach

**Execute scans**:

```bash
# Use helper script if available
bash scripts/atlas/scan-entropy.sh ${ARGUMENTS:-.} 2>/dev/null
```

### Phase 3: Generate Hypotheses (3-5 minutes)

Based on scanned files, generate **scale-appropriate hypotheses** (use targets from Phase 1) about:

**Technology Stack**:
- Primary language(s) and versions
- Framework(s) and major dependencies
- Database(s) and storage solutions
- Testing frameworks

**Architecture**:
- Overall pattern (MVC, Clean Architecture, Microservices, etc.)
- Directory structure conventions
- Layering and separation of concerns
- Design patterns used

**Development Practices**:
- Code quality indicators
- Testing coverage and approach
- Documentation depth
- Git workflow patterns

**AI Collaboration** (SourceAtlas Signature Analysis):
- Level 0-4 detection:
  - Level 0: Traditional development (5-8% comments, inconsistent style)
  - Level 3: Systematic AI collaboration (CLAUDE.md present, 15-20% comments, 98%+ consistency)
- Look for: CLAUDE.md, .cursor/rules/, high comment density, conventional commits

**Business Domain**:
- What does this project do?
- Key entities and concepts
- Main features

Each hypothesis must include:
- **Confidence level** (0.0-1.0)
- **Evidence** (specific files/lines)
- **Validation method** (how to verify in Stage 1)

---

## Output Format

Generate output in **TOON format** (Token Optimized Output Notation):

```toon
metadata:
  project_name: [detected name]
  scan_time: [ISO 8601 timestamp]
  target_path: ${ARGUMENTS:-.}
  total_files_estimate: [estimate]
  scanned_files: [actual count]
  scan_ratio: [percentage]
  analysis_time: [minutes]

## Project Fingerprint

project_type: [WEB_APP|CLI|LIBRARY|MOBILE_APP|MICROSERVICE|MONOREPO]
scale: [TINY|SMALL|MEDIUM|LARGE|VERY_LARGE]
  # TINY: <500 LOC
  # SMALL: 500-2k LOC
  # MEDIUM: 2k-10k LOC
  # LARGE: 10k-50k LOC
  # VERY_LARGE: >50k LOC

primary_language: [language + version]
framework: [framework + version]
architecture: [pattern name]

## Technology Stack

backend:
  language: [name + version]
  framework: [name + version]
  database: [name + version]

frontend:
  # (if applicable)
  language: [name]
  framework: [name]

infrastructure:
  # (if applicable)
  containerization: [Docker/none]
  orchestration: [K8s/none]

## Hypotheses

architecture:
  - hypothesis: "[architectural pattern description]"
    confidence: [0.0-1.0]
    evidence: "[file:line references]"
    validation_method: "[how to verify]"

tech_stack:
  - hypothesis: "[technology decision]"
    confidence: [0.0-1.0]
    evidence: "[file:line references]"
    validation_method: "[how to verify]"

development:
  - hypothesis: "[development practice]"
    confidence: [0.0-1.0]
    evidence: "[file:line references]"
    validation_method: "[how to verify]"

ai_collaboration:
  level: [0-4]
  confidence: [0.0-1.0]
  evidence: "[specific indicators]"
  indicators:
    - "[indicator 1]"
    - "[indicator 2]"

business:
  - hypothesis: "[business domain insight]"
    confidence: [0.0-1.0]
    evidence: "[file:line references]"
    validation_method: "[how to verify]"

## Scanned Files

[List all files actually read, with key insights from each]

## Summary

understanding_depth: [70-80%]
key_findings:
  - "[finding 1]"
  - "[finding 2]"
  - "[finding 3]"

recommended_next_steps:
  - "[action 1]"
  - "[action 2]"
```

---

## Critical Rules

1. **Scale-Aware Scanning**: Follow recommended file limits from Phase 1 detection
2. **Exclude Common Bloat**: Never scan .venv/, node_modules/, vendor/, __pycache__, .git/
3. **Time Limit**: Complete in 10-15 minutes (though usually takes 0-5 minutes)
4. **Hypothesis Quality**: Each must have confidence level and evidence
5. **Scale-Aware Targets**: Use hypothesis targets appropriate for project scale
6. **No Deep Diving**: Understand structure > implementation details
7. **STOP after Stage 0**: Do not proceed to validation or git analysis

---

## Tips for Efficient Analysis

- **README first**: Often contains 30-40% of project understanding
- **Config files are gold**: Technology decisions in one place
- **Sample, don't enumerate**: Read 2-3 models, not all 50
- **Pattern over detail**: Identify the pattern from 1-2 examples
- **Trust your hypotheses**: 70-80% confidence is the goal, not 100%

---

## What's Next?

After `/atlas-map`, users can:
- Use `/atlas-pattern` to learn specific design patterns
- Use `/atlas-impact` to analyze change impact
- Run full `/atlas` for complete 3-stage analysis (Stage 0 + 1 + 2)
