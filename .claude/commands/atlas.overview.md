---
description: Get project overview - scan <5% of files to achieve 70-80% understanding
allowed-tools: Bash, Glob, Grep, Read
argument-hint: [optional: specific directory to analyze, e.g., "src/api"]
---

# SourceAtlas: Project Overview (Stage 0 Fingerprint)

> **Constitution**: This command operates under [ANALYSIS_CONSTITUTION.md](../../ANALYSIS_CONSTITUTION.md) v1.0
>
> Key principles enforced:
> - Article I: 高熵優先、掃描比例上限
> - Article II: 強制排除目錄
> - Article III: 假設數量限制、必要元素
> - Article IV: 證據格式要求

## Context

**Analysis Target**: ${ARGUMENTS:-.}

**Goal**: Generate a comprehensive project fingerprint by scanning <5% of files to achieve 70-80% understanding in 10-15 minutes.

---

## Your Task

Execute **Stage 0 Analysis Only** - generate a project overview using information theory principles.

### Phase 1: Project Detection & Scale-Aware Planning (2-3 minutes)

**IMPORTANT**: Use the enhanced detection script for accurate file counts and scale-aware recommendations.

```bash
# Run enhanced detection script (RECOMMENDED)
# Will try global install first, then local
bash ~/.claude/scripts/atlas/detect-project-enhanced.sh ${ARGUMENTS:-.} 2>/dev/null || \
bash scripts/atlas/detect-project-enhanced.sh ${ARGUMENTS:-.}
```

The script will:
- Detect project type and language
- Count actual code files (excluding .venv, node_modules, vendor, etc.)
- Determine project scale (TINY/SMALL/MEDIUM/LARGE/VERY_LARGE)
- Recommend file scan limits (to stay <10%)
- Suggest hypothesis targets (scale-aware)

**Scale-Aware Scan Limits**:
- **TINY** (<5 files): Scan 1-2 files max (50% max to avoid over-scanning tiny projects)
- **SMALL** (5-15 files): Scan 2-3 files (10-20%)
- **MEDIUM** (15-50 files): Scan 4-6 files (8-12%)
- **LARGE** (50-150 files): Scan 6-10 files (4-7%)
- **VERY_LARGE** (>150 files): Scan 10-15 files (3-7%)

**Scale-Aware Hypothesis Targets**:
- **TINY**: 5-8 hypotheses (simple projects have fewer dimensions)
- **SMALL**: 7-10 hypotheses
- **MEDIUM**: 10-15 hypotheses
- **LARGE**: 12-18 hypotheses
- **VERY_LARGE**: 15-20 hypotheses

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
# Use helper script if available (try global first, then local)
bash ~/.claude/scripts/atlas/scan-entropy.sh ${ARGUMENTS:-.} 2>/dev/null || \
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

Generate output in **YAML format** (standard, ecosystem-supported):

```yaml
metadata:
  project_name: "[detected name]"
  scan_time: "[ISO 8601 timestamp]"
  target_path: "${ARGUMENTS:-.}"
  total_files: [actual count after exclusions]
  scanned_files: [files read]
  scan_ratio: "[percentage]"
  project_scale: "[TINY|SMALL|MEDIUM|LARGE|VERY_LARGE]"
  constitution_version: "1.0"

project_fingerprint:
  project_type: "[WEB_APP|CLI|LIBRARY|MOBILE_APP|MICROSERVICE|MONOREPO]"
  scale: "[TINY|SMALL|MEDIUM|LARGE|VERY_LARGE]"
  # TINY: <500 LOC, SMALL: 500-2k, MEDIUM: 2k-10k, LARGE: 10k-50k, VERY_LARGE: >50k
  primary_language: "[language + version]"
  framework: "[framework + version]"
  architecture: "[pattern name]"

tech_stack:
  backend:
    language: "[name + version]"
    framework: "[name + version]"
    database: "[name + version]"

  frontend:  # if applicable
    language: "[name]"
    framework: "[name]"

  infrastructure:  # if applicable
    containerization: "[Docker/none]"
    orchestration: "[K8s/none]"

hypotheses:
  architecture:
    - hypothesis: "[architectural pattern description]"
      confidence: 0.0-1.0
      evidence: "[file:line references]"
      validation_method: "[how to verify]"

  tech_stack:
    - hypothesis: "[technology decision]"
      confidence: 0.0-1.0
      evidence: "[file:line references]"
      validation_method: "[how to verify]"

  development:
    - hypothesis: "[development practice]"
      confidence: 0.0-1.0
      evidence: "[file:line references]"
      validation_method: "[how to verify]"

  ai_collaboration:
    level: 0-4
    confidence: 0.0-1.0
    evidence: "[specific indicators]"
    indicators:
      - "[indicator 1]"
      - "[indicator 2]"

  business:
    - hypothesis: "[business domain insight]"
      confidence: 0.0-1.0
      evidence: "[file:line references]"
      validation_method: "[how to verify]"

scanned_files:
  - file: "[path/to/file]"
    reason: "[why scanned]"
    key_insight: "[main learning]"

summary:
  understanding_depth: "[70-80%]"
  key_findings:
    - "[finding 1]"
    - "[finding 2]"
    - "[finding 3]"

# Handoffs - 根據分析發現動態建議，省略此區塊若發現太模糊
recommended_next:
  primary:
    command: "[具體命令含參數，如 /atlas.pattern \"repository\"]"
    why: "[1 句話理由，基於上述發現]"
  secondary:  # 可選，只有一個相關建議時省略
    command: "[具體命令含參數]"
    why: "[1 句話理由]"
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

## Handoffs 判斷規則

根據分析發現，在 `recommended_next` 區塊建議 1-2 個最相關的後續命令。

**何時建議**（根據發現選擇最相關的）：
- 發現明確的設計 patterns（Repository, Service, Controller 等）→ `/atlas.pattern "[pattern名稱]"`
- 架構複雜（多層、微服務、大量模組）→ `/atlas.flow "[主要入口點]"`
- 專案規模 >= LARGE → `/atlas.history`（找出 hotspots）
- 發現可能的高風險區域 → `/atlas.impact "[目標]"`

**何時不建議**（省略整個 `recommended_next` 區塊）：
- 分析結果太模糊，沒有高信心發現
- 無法確定具體參數
- AI 協作等級 >= 3 且專案規模 TINY/SMALL（可直接開發）

**限制**：
- 最多 2 個建議（primary + secondary）
- 必須包含具體參數（不是泛泛的 "可以用 /atlas.pattern"）
- 理由必須基於上述分析發現
