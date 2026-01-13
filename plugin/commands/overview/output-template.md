# Overview Output Template

Complete YAML format specification for Stage 0 fingerprint analysis.

---

## Header Format

```markdown
🗺️ SourceAtlas: Overview
───────────────────────────────
🔭 [project_name] │ [SCALE] ([file count] files)
```

**Example:**
```markdown
🗺️ SourceAtlas: Overview
───────────────────────────────
🔭 sourceatlas2 │ LARGE (127 files)
```

---

## YAML Structure

Complete YAML output with all sections:

```yaml
metadata:
  project_name: "[detected name]"
  scan_time: "[ISO 8601 timestamp]"
  target_path: "${ARGUMENTS:-.}"
  total_files: [actual count after exclusions]
  scanned_files: [files read]
  scan_ratio: "[percentage]"
  project_scale: "[TINY|SMALL|MEDIUM|LARGE|VERY_LARGE]"
  constitution_version: "1.1"
  # Branch-Aware Context (v2.8.2)
  context:
    git_branch: "[branch name or null]"
    relative_path: "[path within repo or null]"
    package_name: "[detected package name or null]"

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
    tools_detected:
      - tool: "[tool name]"
        config_file: "[file path]"
        content_quality: "[minimal|basic|comprehensive]"
    indicators:
      - "[indicator 1]"
      - "[indicator 2]"
    # Level interpretation:
    # 0: No AI (no config files, 5-8% comments)
    # 1: Occasional (1 config, minimal content)
    # 2: Frequent (1-2 configs + indirect indicators)
    # 3: Systematic (complete config + high comments + consistent style)
    # 4: Ecosystem (multiple tools/AGENTS.md + team standards)

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
```

---

## Section Specifications

### Section 1: metadata

**Required Fields:**

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| project_name | string | "sourceatlas2" | From package.json, pyproject.toml, or directory name |
| scan_time | ISO 8601 | "2025-01-14T10:30:00Z" | UTC timestamp |
| target_path | string | "." or "src/api" | From $ARGUMENTS, default "." |
| total_files | integer | 127 | After exclusions (no .venv, node_modules) |
| scanned_files | integer | 8 | Actual files read |
| scan_ratio | string | "6.3%" | (scanned_files / total_files * 100) |
| project_scale | enum | "LARGE" | TINY/SMALL/MEDIUM/LARGE/VERY_LARGE |
| constitution_version | string | "1.1" | Current version |

**Context Subfields** (v2.8.2):

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| git_branch | string or null | "main" | Current branch, null if not git repo |
| relative_path | string or null | "packages/api" | Path within monorepo, null if root |
| package_name | string or null | "@org/api" | From package.json name field |

**Example:**
```yaml
metadata:
  project_name: "sourceatlas2"
  scan_time: "2025-01-14T10:30:00Z"
  target_path: "."
  total_files: 127
  scanned_files: 8
  scan_ratio: "6.3%"
  project_scale: "LARGE"
  constitution_version: "1.1"
  context:
    git_branch: "main"
    relative_path: null
    package_name: "@sourceatlas/plugin"
```

### Section 2: project_fingerprint

High-level project classification.

**Fields:**

| Field | Type | Values | Example |
|-------|------|--------|---------|
| project_type | enum | WEB_APP, CLI, LIBRARY, MOBILE_APP, MICROSERVICE, MONOREPO | "CLI" |
| scale | enum | TINY, SMALL, MEDIUM, LARGE, VERY_LARGE | "LARGE" |
| primary_language | string | Include version | "TypeScript 5.3" |
| framework | string | Include version | "None (vanilla TS)" |
| architecture | string | Pattern name | "Modular CLI with plugins" |

**Scale Definitions:**
- **TINY**: <500 LOC
- **SMALL**: 500-2k LOC
- **MEDIUM**: 2k-10k LOC
- **LARGE**: 10k-50k LOC
- **VERY_LARGE**: >50k LOC

**Example:**
```yaml
project_fingerprint:
  project_type: "CLI"
  scale: "LARGE"
  primary_language: "TypeScript 5.3"
  framework: "None (vanilla TS)"
  architecture: "Modular CLI with plugins"
```

### Section 3: tech_stack

Technology stack breakdown.

**Structure:**
- `backend`: Always present
- `frontend`: Optional (web apps, mobile apps)
- `infrastructure`: Optional (Docker, K8s)

**Example (Backend-Only):**
```yaml
tech_stack:
  backend:
    language: "Python 3.11"
    framework: "FastAPI 0.104"
    database: "PostgreSQL 15"
```

**Example (Full Stack):**
```yaml
tech_stack:
  backend:
    language: "Node.js 20"
    framework: "Express 4.18"
    database: "MongoDB 7.0"

  frontend:
    language: "TypeScript"
    framework: "React 18.2"

  infrastructure:
    containerization: "Docker 24.0"
    orchestration: "Kubernetes 1.28"
```

### Section 4: hypotheses

Scale-appropriate hypotheses with evidence.

**Subsections:**
- `architecture`: 2-4 hypotheses
- `tech_stack`: 2-4 hypotheses
- `development`: 2-4 hypotheses
- `ai_collaboration`: 1 hypothesis (special structure)
- `business`: 1-3 hypotheses

**Hypothesis Structure:**
```yaml
- hypothesis: "[clear, specific statement]"
  confidence: 0.0-1.0  # aim for >0.7
  evidence: "[file:line references]"
  validation_method: "[how to verify in Stage 1]"
```

**Example (architecture):**
```yaml
hypotheses:
  architecture:
    - hypothesis: "3-layer architecture: Controller → Service → Repository"
      confidence: 0.85
      evidence: "src/controllers/, src/services/, src/repositories/ directories exist"
      validation_method: "trace UserController.ts flow to UserService.ts to UserRepository.ts"

    - hypothesis: "Dependency injection via constructor parameters"
      confidence: 0.90
      evidence: "src/controllers/UserController.ts:15-20, src/services/UserService.ts:10-12"
      validation_method: "grep 'constructor.*private' src/**/*.ts"
```

**Example (tech_stack):**
```yaml
  tech_stack:
    - hypothesis: "Express.js 4.18 with TypeScript for REST API"
      confidence: 0.95
      evidence: "package.json:12, src/app.ts:1-5"
      validation_method: "grep 'express' package.json; check tsconfig.json"

    - hypothesis: "Sequelize ORM for PostgreSQL database access"
      confidence: 0.80
      evidence: "package.json:18, src/config/database.ts:5-10"
      validation_method: "check models/ directory for Sequelize model definitions"
```

**Example (development):**
```yaml
  development:
    - hypothesis: "Jest + Supertest for API integration testing"
      confidence: 0.85
      evidence: "package.json:25, tests/api/users.test.ts:1-20"
      validation_method: "run npm test -- --coverage"

    - hypothesis: "ESLint + Prettier for code quality enforcement"
      confidence: 0.90
      evidence: ".eslintrc.json, .prettierrc.json exist"
      validation_method: "run npm run lint"
```

**Example (ai_collaboration - Special Structure):**
```yaml
  ai_collaboration:
    level: 3
    confidence: 0.90
    tools_detected:
      - tool: "Claude Code"
        config_file: "CLAUDE.md"
        content_quality: "comprehensive"
      - tool: "Cursor"
        config_file: ".cursorrules"
        content_quality: "basic"
    indicators:
      - "High comment density (18% vs typical 5-8%)"
      - "Consistent code style across all files"
      - "Comprehensive inline documentation"
      - "Conventional Commits with AI tool signatures"
```

**AI Collaboration Levels:**
- **Level 0**: No AI detection
- **Level 1**: 1 tool config, minimal content
- **Level 2**: 1-2 tool configs + some indirect indicators
- **Level 3**: Complete AI config + high comment density + consistent style
- **Level 4**: Multiple tools (Ruler/.ruler/) or AGENTS.md + team standards

**Content Quality:**
- **minimal**: <5 lines, basic instructions
- **basic**: 5-50 lines, clear guidance
- **comprehensive**: >50 lines, detailed guidelines, examples

**Example (business):**
```yaml
  business:
    - hypothesis: "E-commerce platform with user, product, order management"
      confidence: 0.80
      evidence: "README.md:15-30, models/User.ts, models/Product.ts, models/Order.ts"
      validation_method: "review core entity relationships in models/"

    - hypothesis: "Multi-tenant SaaS with organization-level isolation"
      confidence: 0.70
      evidence: "models/Organization.ts:5-10, middleware/tenantIsolation.ts:15-30"
      validation_method: "trace request flow through tenant middleware"
```

### Section 5: scanned_files

List of files scanned with reasons and insights.

**Structure:**
```yaml
scanned_files:
  - file: "[path]"
    reason: "[why scanned - entropy category]"
    key_insight: "[main learning]"
```

**Example:**
```yaml
scanned_files:
  - file: "README.md"
    reason: "Documentation (highest entropy)"
    key_insight: "CLI tool for codebase analysis using information theory"

  - file: "package.json"
    reason: "Configuration (project-level decisions)"
    key_insight: "TypeScript project with 15 dependencies, targets Node.js 18+"

  - file: "CLAUDE.md"
    reason: "AI collaboration detection"
    key_insight: "Comprehensive Claude Code configuration, Level 3 collaboration"

  - file: "src/commands/overview/SKILL.md"
    reason: "Core model (data structure)"
    key_insight: "Stage 0 fingerprint command with scale-aware analysis"

  - file: "src/app.ts"
    reason: "Entry point (architecture pattern)"
    key_insight: "Plugin-based architecture, modular command system"

  - file: "tests/integration/overview.test.ts"
    reason: "Testing (development practices)"
    key_insight: "Jest integration tests with real project fixtures"
```

### Section 6: summary

High-level summary with key findings.

**Fields:**

| Field | Type | Example | Notes |
|-------|------|---------|-------|
| understanding_depth | string | "75%" | Target: 70-80% |
| key_findings | array | [3-5 findings] | Most important discoveries |

**Example:**
```yaml
summary:
  understanding_depth: "75%"
  key_findings:
    - "TypeScript CLI tool for codebase analysis"
    - "Modular plugin architecture with 5 analysis commands"
    - "Information theory-based approach (scan <5% for 70-80% understanding)"
    - "Level 3 AI collaboration with comprehensive CLAUDE.md"
    - "Constitutional compliance v1.1 with mandatory exclusions"
```

---

## Recommended Next Section

**Decision Logic:** Choose ONE of these outputs, NOT both.

### Case A: End Condition (No Table)

When any of these conditions are met:
- Project too small: TINY (<10 files)
- Findings too vague: Cannot provide high confidence (>0.7) parameters
- Goal achieved: AI collaboration Level ≥3 and scale TINY/SMALL

**Output:**
```markdown
✅ **Analysis sufficient** - Project is small, can read all files directly to start development
```

### Case B: Suggestions (Table Output)

When project scale is large enough or there are clear next steps:

**Format:**
```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:pattern "[pattern name]"` | [reason based on findings] |
| 2 | `/sourceatlas:flow "[entry point]"` | [reason based on findings] |

💡 Enter a number (e.g., `1`) or copy the command to execute
```

**Suggestion Rules:**

| Finding | Suggested Command | Parameter Source |
|---------|-------------------|------------------|
| Clear design patterns | `/sourceatlas:pattern` | Discovered pattern name |
| Complex architecture (multi-layer/microservices) | `/sourceatlas:flow` | Main entry point file |
| Scale ≥ LARGE | `/sourceatlas:history` | No parameters needed |
| High risk areas | `/sourceatlas:impact` | Risk file/module name |

**Requirements:**
- **Specific parameters**: Use actual names from analysis (e.g., `"repository"` not `"related pattern"`)
- **Quantity limit**: 1-2 suggestions, don't force fill
- **Purpose column**: Reference specific findings (numbers, file names)

**Example (Good):**
```markdown
## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:pattern "repository pattern"` | Found Repository pattern used in 15 files |
| 2 | `/sourceatlas:flow "src/app.ts"` | Trace 3-layer architecture execution flow |
```

**Example (Bad - Too Generic):**
```markdown
| 1 | `/sourceatlas:pattern "some pattern"` | Learn more patterns |
```

---

## Footer Format

```markdown
───────────────────────────────
🗺️ v2.11.0 │ Constitution v1.1
```

---

## Complete Example

```markdown
🗺️ SourceAtlas: Overview
───────────────────────────────
🔭 express-api │ MEDIUM (42 files)

```yaml
metadata:
  project_name: "express-api"
  scan_time: "2025-01-14T10:30:00Z"
  target_path: "."
  total_files: 42
  scanned_files: 5
  scan_ratio: "11.9%"
  project_scale: "MEDIUM"
  constitution_version: "1.1"
  context:
    git_branch: "main"
    relative_path: null
    package_name: "@company/express-api"

project_fingerprint:
  project_type: "WEB_APP"
  scale: "MEDIUM"
  primary_language: "TypeScript 5.3"
  framework: "Express.js 4.18"
  architecture: "3-layer MVC (Controller-Service-Repository)"

tech_stack:
  backend:
    language: "TypeScript 5.3"
    framework: "Express 4.18"
    database: "PostgreSQL 15"

  infrastructure:
    containerization: "Docker 24.0"
    orchestration: "none"

hypotheses:
  architecture:
    - hypothesis: "3-layer architecture: Controller → Service → Repository"
      confidence: 0.85
      evidence: "src/controllers/, src/services/, src/repositories/ exist"
      validation_method: "trace UserController.ts flow"

    - hypothesis: "RESTful API design with route-based organization"
      confidence: 0.90
      evidence: "src/routes/users.ts:1-20, routes follow REST conventions"
      validation_method: "check all routes/*.ts files"

  tech_stack:
    - hypothesis: "Express.js 4.18 with TypeScript for type safety"
      confidence: 0.95
      evidence: "package.json:12, tsconfig.json:5-10"
      validation_method: "grep 'express' package.json"

    - hypothesis: "Sequelize ORM for PostgreSQL access"
      confidence: 0.80
      evidence: "package.json:18, src/config/database.ts:5-10"
      validation_method: "check models/ for Sequelize definitions"

  development:
    - hypothesis: "Jest + Supertest for API testing, likely >70% coverage"
      confidence: 0.75
      evidence: "package.json:25, tests/api/users.test.ts:1-20"
      validation_method: "run npm test -- --coverage"

    - hypothesis: "ESLint + Prettier enforce code quality"
      confidence: 0.90
      evidence: ".eslintrc.json, .prettierrc.json exist"
      validation_method: "run npm run lint"

  ai_collaboration:
    level: 2
    confidence: 0.80
    tools_detected:
      - tool: "Claude Code"
        config_file: "CLAUDE.md"
        content_quality: "basic"
    indicators:
      - "High comment density (12% vs typical 5-8%)"
      - "Consistent code style"

  business:
    - hypothesis: "User management API with authentication/authorization"
      confidence: 0.80
      evidence: "README.md:15-30, models/User.ts, routes/auth.ts"
      validation_method: "review auth flow in middleware/auth.ts"

scanned_files:
  - file: "README.md"
    reason: "Documentation (highest entropy)"
    key_insight: "REST API for user management with JWT auth"

  - file: "package.json"
    reason: "Configuration (project-level decisions)"
    key_insight: "Express + TypeScript + Sequelize stack"

  - file: "CLAUDE.md"
    reason: "AI collaboration detection"
    key_insight: "Basic Claude Code config, Level 2 collaboration"

  - file: "src/controllers/UserController.ts"
    reason: "Entry point (architecture pattern)"
    key_insight: "Controller calls UserService, follows 3-layer pattern"

  - file: "tests/api/users.test.ts"
    reason: "Testing (development practices)"
    key_insight: "Jest + Supertest for API integration tests"

summary:
  understanding_depth: "75%"
  key_findings:
    - "Express.js REST API with 3-layer architecture"
    - "TypeScript + Sequelize for type-safe database access"
    - "JWT-based authentication with role-based authorization"
    - "Level 2 AI collaboration (Claude Code, basic config)"
    - "Good test coverage with Jest + Supertest"

## Recommended Next

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/sourceatlas:pattern "repository pattern"` | Found Repository pattern in 8 files |
| 2 | `/sourceatlas:flow "src/routes/users.ts"` | Trace 3-layer flow from route to database |

💡 Enter a number (e.g., `1`) or copy the command to execute

───────────────────────────────
🗺️ v2.11.0 │ Constitution v1.1
```
