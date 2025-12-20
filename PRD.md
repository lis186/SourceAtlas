# SourceAtlas PRD v2.9.0

**AI-Powered Codebase Understanding Assistant**

- **Version**: 2.9.0
- **Last Updated**: 2025-12-08
- **Status**: 🔵 In Development (v2.9.0 /atlas.deps)

---

## Executive Summary

SourceAtlas is an intelligent code understanding assistant integrated into Claude Code. Through the architecture of **Claude Commands (slash commands) + Lightweight Scripts**, it provides real-time project understanding, pattern learning, and impact analysis capabilities within the developer's workflow.

**Core Positioning Shift**:
- ❌ **NOT**: A standalone CLI indexing tool
- ✅ **BUT**: A native Claude Code analysis assistant (Commands)

### Core Features

- 🎯 **Real-time Exploration**: No pre-indexing required, analyze on-demand
- 📋 **Standard Format**: Uses YAML format with complete ecosystem support
- 🧠 **Intelligent Understanding**: AI dynamic reasoning, not static indexing
- ⚡ **Workflow Integration**: Seamlessly integrated into Claude Code
- 🛠️ **Lightweight Design**: Scripts collect data, AI handles understanding
- 📜 **Quality Assurance**: Constitution v1.0 ensures consistent analysis quality

---

## Table of Contents

1. [Product Positioning](#1-product-positioning)
2. [Use Cases](#2-use-cases)
3. [Product Architecture](#3-product-architecture)
4. [Core Capabilities](#4-core-capabilities)
5. [Output Format Decisions](#5-output-format-decisions)
6. [Command Interface Design](#6-command-interface-design)
7. [Scripts Design](#7-scripts-design)
8. [Analysis Methodology](#8-analysis-methodology)
9. [Implementation Specifications](#9-implementation-specifications)
10. [Success Metrics](#10-success-metrics)
11. [Implementation Roadmap](#11-implementation-roadmap)

---

## 1. Product Positioning

### 1.1 Product Evolution

```
v2.0 (Completed) - Manual Prompts Methodology
  ↓
v2.7 (Completed) - SourceAtlas Commands ✅
  ├─ Claude Code Commands Integration
  ├─ 6 Core Commands Completed
  ├─ Git History Temporal Analysis
  └─ 141 Patterns Support
  ↓
v2.8.1 - Constitution v1.1 + Handoffs ✅
  ├─ Analysis Quality Framework (7 Articles)
  ├─ Automated Compliance Validation
  ├─ Monorepo Detection Support
  └─ Discovery-driven Handoffs (Article VII: Handoffs Principles)
  ↓
v2.8.2 - Branch-Aware Analysis ✅
  ├─ Git Branch Detection
  ├─ Monorepo Subdirectory Awareness
  ├─ Package Name Identification
  └─ Context-Aware Output Path Suggestions
  ↓
v2.9.0 (Current) - Dependency Analysis ⭐ NEW
  ├─ /atlas.deps Command
  ├─ Library Usage Point Analysis
  ├─ Breaking Change Comparison
  └─ Migration Checklist Generation
  ↓
v3.0 (Future) - SourceAtlas Monitor
  ├─ Continuous Tracking System
  ├─ Historical Trend Analysis
  └─ Health Dashboard
```

### 1.2 Why Choose Skill Architecture

#### Problem: Limitations of Standalone CLI

The standalone CLI tool designed in the original PRD has the following issues:

| Problem | Impact |
|---------|--------|
| Requires index export | Developers need to leave Claude Code |
| Pre-build index | Cannot handle dynamic changes |
| Reinventing the wheel | Claude Code already has file operation tools |
| Long development cycle | 8 weeks to complete MVP |
| High learning curve | Need to memorize new CLI commands |

#### Solution: Skill + Scripts

| Advantage | Description |
|-----------|-------------|
| **Native Integration** | Use `/atlas.*` commands directly in Claude Code |
| **Real-time Analysis** | On-demand exploration, no pre-indexing |
| **Zero Learning Cost** | Natural language interaction |
| **Rapid Development** | 1-2 weeks to complete core features |
| **AI-Driven** | Leverage Claude's understanding capabilities |

### 1.3 Target Users

- **Primary**: Engineers developing with Claude Code
- **Scenarios**: Taking over new projects, learning existing patterns, debugging, code review
- **Frequency**: Multiple times daily

---

## 2. Use Cases

### Scenario 0: Quickly Understanding a New Project (Project Overview) ⭐

**Context**:
```
Alice just joined the team and needs to quickly understand a 2000+ LOC project
PM expects her to start contributing tomorrow
```

**Traditional Approach**:
- Start reading from README
- Open files one by one to browse directory structure
- Guess tech stack and architecture patterns
- Ask senior colleagues
- **Takes 2-3 days to get a global concept**

**Using SourceAtlas**:
```
Alice: /atlas.overview

AI analyzes and responds (10-15 minutes):

=== Project Fingerprint Analysis ===

📊 Basic Information:
  - Project Type: WEB_APP
  - Scale: MEDIUM (~3500 LOC)
  - Architecture Pattern: MVC + Service Layer

🔧 Tech Stack:
  Backend: Ruby on Rails 7.0
  Database: PostgreSQL + Redis
  Frontend: React 18 + TypeScript

🏗️ Architecture Inference (Confidence: 0.85):
  - Controllers handle HTTP requests
  - Services contain business logic
  - Jobs handle async tasks
  - Policies manage permissions

💡 Key Findings:
  1. Has complete test coverage (85%+)
  2. Uses Sidekiq for background tasks
  3. AI Collaboration Level: Level 3 (has CLAUDE.md)

📁 Priority Reading Files:
  1. app/models/user.rb - Core data model
  2. app/services/order_service.rb - Main business logic
  3. config/routes.rb - API route definitions
```

**Time Saved**: From 2-3 days → 10-15 minutes to achieve 70-80% understanding

**Follow-up Actions**:
- Need to learn specific patterns → `/atlas.pattern`
- Need to modify code → `/atlas.impact` to assess impact

---

### Scenario 1: Taking Over Legacy System (Bug Fix)

**Context**:
```
New developer Alice needs to fix a bug:
"After user login, specific roles cannot see the order list"
```

**Traditional Approach**:
- Search "orders" → 50 files
- Guess it's OrdersController?
- Find authorization logic, but where's the Policy?
- Ask senior colleague (might be busy)
- **Takes 2 hours**

**Using SourceAtlas**:
```
Alice: /atlas.impact "order list authorization"

AI responds:
Order list authorization chain:
  1. OrdersController#index (app/controllers/orders_controller.rb:23)
     → Calls authorize(@orders)

  2. OrderPolicy#index? (app/policies/order_policy.rb:15)
     → Checks user.role and store permissions

  3. Related tests: spec/requests/orders_spec.rb:45

Possible issue:
  - OrderPolicy modified 2 days ago
  - Commit: "fix: update role check logic"

Suggestion: First check order_policy.rb:18 role judgment logic
```

**Time Saved**: From 2 hours → 15 minutes

---

### Scenario 2: New Feature Development (Learning Existing Patterns)

**Context**:
```
PM: "We need a new feature: users can export invoice PDFs"
Developer Bob: "OK, but how does this project handle PDF generation?"
```

**Using SourceAtlas**:
```
Bob: /atlas.pattern "file generation"

AI responds:
This project's file generation pattern (Example: Order PDF):

Standard Process:
  1. Controller receives request
  2. Enqueue background job GeneratePdfJob
  3. Service uses Prawn gem to generate
  4. Upload to S3 (config/storage.yml:15)
  5. Send email notification to user

Reference Implementation:
  - Service: app/services/order_pdf_service.rb
  - Job: app/jobs/generate_pdf_job.rb
  - Test: spec/services/order_pdf_service_spec.rb

To add invoice PDF following this pattern:
  1. Create InvoicePdfService
  2. Create GenerateInvoicePdfJob
  3. Configure S3 bucket
  4. Update InvoiceMailer
```

**Value**: Avoid redesign, follow existing architecture

---

### Scenario 3: Impact Scope Analysis

Impact analysis is a critical need in development, including two common situations:

#### 3A. Cascading Impact of Model Changes

**Context**:
```
Found in test environment: After changing User model validation rules,
3 seemingly unrelated features broke
```

**Using SourceAtlas**:
```
Developer: /atlas.impact "User model validation"

AI responds:
Impact scope of User model validation changes:

Direct Impact (4 places):
  - RegistrationController#create
  - Admin::UsersController#update
  - Api::V1::ProfileController#update
  - UserImportService (bulk import)

Cascading Impact (3 places):
  - Order model (belongs_to :user, validates: true)
  - Notification service (assumes user.email is always valid)
  - Analytics job (depends on user data structure)

Test Coverage Gaps:
  ⚠️ UserImportService has no validation failure tests
  ⚠️ Order#user association doesn't test invalid user

Suggestions:
  1. First add missing tests
  2. Check Notification service's email handling
```

**Value**: Prevent cascading failures, add tests proactively

---

#### 3B. Library/Framework Upgrade (⭐ High-Frequency Scenario)

**Context**:
```
Need to upgrade React 17 → 18, or axios 0.x → 1.x
Unsure which APIs the project uses, which will be affected by breaking changes
```

**Traditional Approach**:
- Read Migration Guide, search item by item
- `grep` search, but might miss dynamic imports
- Try upgrading, see what breaks
- **Often miss things, takes days**

**Using SourceAtlas**:
```
Developer: /atlas.deps "react"

AI responds:
=== Dependency Analysis: react ===

📦 Version Info:
  - Current Version: 17.0.2
  - Latest Stable: 18.2.0

📊 Usage Statistics:
  - Import Count: 156 places
  - APIs Used: 23 types

🔍 API Usage Details:

| API | Usage Count | File Count | React 18 Status |
|-----|------------|-----------|----------------|
| `useState` | 89 | 45 | ✅ Compatible |
| `useEffect` | 67 | 38 | ✅ Compatible |
| `ReactDOM.render` | 3 | 1 | ⚠️ Deprecated → createRoot |
| `componentWillMount` | 5 | 3 | 🔴 Removed |

⚠️ Breaking Changes Impact:

1. **ReactDOM.render** (3 places)
   - `src/index.tsx:5` - App entry point
   - `src/utils/modal.tsx:12` - Modal helper
   - `tests/setup.ts:3` - Test setup
   → Need to use `createRoot`

2. **componentWillMount** (5 places)
   - `src/legacy/OldComponent.tsx:15`
   - `src/legacy/AnotherOld.tsx:22`
   → Need to use `useEffect` or `componentDidMount`

📋 Migration Checklist:

- [ ] Update src/index.tsx: ReactDOM.render → createRoot
- [ ] Refactor 3 Legacy component lifecycles
- [ ] Update test setup
- [ ] Check Concurrent Mode compatibility

Estimated Effort: 4-6 hours
Risk Level: 🟡 Medium (has deprecated APIs)
```

**Value**:
- Complete inventory of all usage points, avoid omissions
- Automatically compare breaking changes
- Generate specific Migration Checklist
- Assess effort and risk

---

#### 3C. API Change Impact Scope

**Context**:
```
Backend API endpoint changes, need to inventory which frontend pages will be affected

Example: GET /api/users/{id} response format changes
- 'role' field changes from string to array 'roles'
- Added nested 'profile' object
```

**Using SourceAtlas**:
```
Developer: /atlas.impact api "/api/users/{id}"

AI responds:
=== API Impact Analysis ===

📍 Call Chain:
  1. API Layer
     - src/types/api.ts (type definitions)
     - src/lib/apiClient.ts (call wrapper)

  2. Hook Layer
     - src/hooks/useUser.ts (main Hook)
       → Used by 5 components

  3. Component Layer
     - src/app/profile/page.tsx
     - src/app/users/[id]/page.tsx
     - src/components/UserCard.tsx
     - src/components/UserBadge.tsx
     - src/app/dashboard/page.tsx

📊 Field Usage Analysis:

'role' field (⚠️ Will be changed to 'roles' array):
  - Usage Count: 8 places
  - Key Locations:
    1. UserBadge.tsx:34 - Render role badge
       if (user.role === 'admin') { ... }

    2. permissions.ts:12 - Permission check
       return user.role === 'admin' || user.role === 'editor'

    3. UserForm.tsx:67 - Form display
    4. useUser.ts:23 - Data transformation

  - Assumes string type: ✅ Yes (all)
  - Impact Assessment: 🔴 Breaking Change (requires modification)

🧪 Test Impact:
  Need to update 5 test files:
  - useUser.test.ts - Mock data
  - UserBadge.test.tsx
  - permissions.test.ts
  - UserForm.test.tsx
  - e2e/user-profile.spec.ts

📋 Migration Checklist:
  [ ] Update API type definitions (api.ts)
  [ ] Update 8 places role → roles usage
  [ ] Change to user.roles.includes('admin')
  [ ] Add backward compatibility if needed
  [ ] Update 5 test files
  [ ] Test all affected pages

Estimated Effort: 2-3 hours
Risk Level: 🔴 High (breaking change)
```

**Value**:
- Discover all impact points in advance, avoid omissions
- Provide clear modification list and migration steps
- Assess effort and risk level
- Reduce frontend-backend collaboration friction

**Applicable Scenarios**:
- API Response format changes
- Adding required parameters
- Field removal or renaming
- Status code logic changes

---

### Scenario 4: Code Review (Understanding Change Intent)

**Context**:
```
Received PR: Added PaymentRefundService
Reviewer unfamiliar with payment module, needs to quickly understand context
```

**Using SourceAtlas**:
```
Reviewer: /atlas.review PR#123

AI responds:
This PR adds refund service to payment module

Module Context:
  - Existing: PaymentService (charge, capture)
  - Existing: PaymentWebhookHandler
  - New: PaymentRefundService ← This PR

Architecture Compliance: ✅ Good
  - Follows existing Service Object pattern
  - Error handling consistent (Result pattern)
  - Naming follows conventions

Potential Issues:
  ⚠️ Missing idempotency handling (PaymentService has it)
  ⚠️ Webhook handler needs update to support refund events
  ⚠️ Test coverage 85% (suggest >90% for payment logic)

Suggestions:
  1. Reference PaymentService#charge's idempotency implementation
  2. Update webhook_handler.rb
```

**Value**: Improve review quality, reduce back-and-forth revisions

---

### Scenario 5: Technical Debt Management (Project Health)

**Context**:
```
Tech Lead needs to report to CTO:
"How serious is our technical debt? Refactoring priorities?"
```

**Using SourceAtlas**:
```
Tech Lead: /atlas.health

AI responds:
Project Health Report

🔴 High-Risk Areas (Need Immediate Action):
  1. PaymentService
     - Complexity: 450 lines, 8 dependencies
     - Depended by 12 files (core module)
     - Modified 23 times in 6 months (high churn)
     - Test coverage 78% (payment logic should be >95%)
     → Suggestion: Split into multiple small Services + add tests

  2. User model
     - God Object pattern (15 concerns)
     - Affects 45 files
     → Suggestion: Extract Authentication, Authorization as separate modules

🟡 Medium Risk (Plan refactoring):
  ...

✅ Healthy Areas:
  - API Controllers (98% consistency)
  - Background Jobs (95% test coverage)
```

**Value**: Quantify technical debt, priority ranking

---

### Scenario Classification

| Scenario Type | Need Characteristics | Applicable Product | Commands Used |
|--------------|---------------------|-------------------|---------------|
| **Real-time Exploration** | No historical data, real-time reasoning | ✅ SourceAtlas Commands | |
| Scenario 0: Quickly understand new project ⭐ | 10-15 min global view | ✅ Commands | `/atlas.overview` ⭐⭐⭐⭐⭐ |
| Scenario 1: Bug fixing | Quickly locate issues | ✅ Commands | `/atlas.flow` + `/atlas.impact` |
| Scenario 2: Learning patterns | Identify design patterns | ✅ Commands | `/atlas.pattern` ⭐⭐⭐⭐⭐ |
| Scenario 3B: Library upgrade ⭐ | Inventory dependency usage points | ✅ Commands (v2.9) | `/atlas.deps` ⭐⭐⭐⭐⭐ NEW |
| Scenario 3C: API impact analysis | Track API call chain | ✅ Commands | `/atlas.impact` ⭐⭐⭐⭐ |
| Scenario 4: Code Review | Understand change intent | ✅ Commands | `/atlas.overview` + `/atlas.pattern` |
| **Continuous Tracking** | Need historical data, trend analysis | 🔮 SourceAtlas Monitor (v3.0) | |
| Scenario 3A: Model change impact | Git history, association analysis | ✅ Commands | `/atlas.history` |
| Scenario 5: Technical debt | Continuous tracking, quantified metrics | 🔮 Monitor | `/atlas.health` (future) |

---

## 3. Product Architecture

### 3.1 Overall Architecture

```
┌─────────────────────────────────────────────┐
│           Claude Code Environment           │
├─────────────────────────────────────────────┤
│  SourceAtlas Commands (Slash Commands)     │
│  ├─ /atlas.overview      - Project Fingerprint ⭐⭐⭐⭐⭐
│  ├─ /atlas.pattern       - Learn Patterns ⭐⭐⭐⭐⭐
│  ├─ /atlas.impact        - Impact Analysis ⭐⭐⭐⭐
│  ├─ /atlas.history       - Git Temporal Analysis ⭐⭐⭐⭐
│  ├─ /atlas.flow          - Flow Tracing ⭐⭐⭐⭐
│  ├─ /atlas.deps          - Dependency Analysis ⭐⭐⭐⭐⭐ NEW
│  └─ /atlas.init          - Project Setup ⭐⭐⭐
├─────────────────────────────────────────────┤
│  Helper Scripts (Bash)                      │
│  ├─ detect-project.sh                      │
│  ├─ scan-entropy.sh                        │
│  ├─ find-patterns.sh                       │
│  ├─ collect-git.sh                         │
│  └─ analyze-dependencies.sh                │
├─────────────────────────────────────────────┤
│  Claude Code Built-in Tools                 │
│  ├─ Glob (file pattern matching)           │
│  ├─ Grep (content search)                  │
│  ├─ Read (file reading)                    │
│  └─ Bash (command execution)               │
└─────────────────────────────────────────────┘
```

> **Historical Evolution**: SourceAtlas evolved from standalone CLI design to Claude Code Commands integration. Complete evolution process in `dev-notes/HISTORY.md`

### 3.2 File Structure

**Current Status** (v1.0 completed, v2.5 in development):

```
sourceatlas2/
├── .claude/commands/                    # Claude Code Commands
│   ├── atlas.overview.md                # ✅ /atlas.overview (completed)
│   ├── atlas.pattern.md                 # ✅ /atlas.pattern (completed) ⭐
│   └── atlas.impact.md                  # ✅ /atlas.impact (completed)
│
├── dev-notes/                           # ⭐ v1.0 Development Records (Important!)
│   ├── HISTORY.md                       # ✅ Complete history and decision records
│   ├── KEY_LEARNINGS.md                 # ✅ v1.0 key learnings summary
│   ├── toon-vs-yaml-analysis.md         # ✅ Format decision analysis
│   ├── v1-implementation-log.md         # ✅ Complete implementation log
│   ├── implementation-roadmap.md        # ✅ v2.5 roadmap
│   └── NEXT_STEPS.md                    # ✅ Next steps guide
│
├── PROMPTS.md                           # Manual Prompts (Stage 0/1/2)
│
├── scripts/atlas/                       # Helper Scripts
│   ├── detect-project-enhanced.sh       # ✅ Scale-aware detection
│   ├── scan-entropy.sh                  # ✅ High-entropy file scanning
│   ├── find-patterns.sh                 # ✅ Pattern identification (completed) ⭐
│   ├── benchmark.sh                     # ✅ Performance testing
│   └── compare-formats.sh               # ✅ Format comparison
│   # Planned:
│   # ├── collect-git.sh                 # ⏳ Git statistics (Phase 2)
│   # └── analyze-dependencies.sh        # ⏳ Dependency analysis (Phase 3)
│
├── plugin/                              # 🔮 Marketplace publishing preparation
│   └── (separate plugin structure)
│
├── test_results/                        # Validation cases (git ignored)
├── test_targets/                        # Test projects (git ignored)
│
├── CLAUDE.md                            # AI work guide
├── PRD.md                               # Product requirements document
├── PROMPTS.md                           # Complete prompt templates
├── README.md                            # Project overview
└── USAGE_GUIDE.md                       # Usage guide
```

> **Note**:
> - ✅ = Completed
> - 🔵 = In Development (Phase 1)
> - ⏳ = Planned (Phase 2-3)
> - 🔮 = Future Features

---

## 4. Core Capabilities

### 4.1 Three-Stage Analysis (Retain v2.0 Core)

#### Stage 0: Project Fingerprint
- **Goal**: Scan <5% of files to achieve 70-80% understanding
- **Method**: High-entropy file prioritization (README, package.json, Models)
- **Output**: YAML format project fingerprint
- **Time**: 10-15 minutes

#### Stage 1: Hypothesis Validation
- **Goal**: Validate Stage 0 hypotheses, achieve 85-95% understanding
- **Method**: Systematic validation, provide evidence
- **Output**: Validation report
- **Time**: 20-30 minutes

#### Stage 2: Git Hotspots Analysis
- **Goal**: Identify development patterns, 95%+ understanding depth
- **Method**: Analyze commit history, identify hotspots
- **Output**: Git analysis report
- **Time**: 15-20 minutes

### 4.2 Real-time Exploration Capabilities (New)

#### Pattern (Pattern Recognition) ⭐⭐⭐⭐⭐
```
/atlas.pattern "api endpoint"

AI identifies:
1. Find best example files
2. Extract design pattern
3. Explain conventions
4. Provide step-by-step guidance
```

#### Impact (Impact Analysis) ⭐⭐⭐⭐
```
/atlas.impact api "/api/users/{id}"

AI analyzes:
1. Track call chain
2. Identify affected files
3. Assess change risk
4. Provide migration list
```

### 4.3 AI Collaboration Recognition (Retain v2.0 Discovery)

Identify project's AI collaboration maturity (Level 0-4):

| Level | Characteristics | Identification Method |
|-------|----------------|----------------------|
| **Level 0** | No AI | Traditional code style |
| **Level 1-2** | Basic use | Occasional AI traces |
| **Level 3** | Systematic | CLAUDE.md, high consistency, detailed comments |
| **Level 4** | Ecosystem | Team-level AI collaboration (future) |

---

## 5. Output Format Decisions

### 5.1 Format Choice: YAML (v1.0 Decision)

**Decision Result**: Use **YAML** as Stage 0 output format

**Evaluation Process**: During v1.0 implementation, evaluated custom TOON (Token Optimized Output Notation) format

| Feature | JSON | YAML | TOON (Evaluated) |
|---------|------|------|-----------------|
| Token Efficiency | Baseline | Baseline +15% | Baseline -14% ✅ |
| Ecosystem | Wide | **Wide** ✅ | None |
| Readability | Medium | **High** ✅ | High |
| IDE Support | ✓ | **✓** ✅ | ✗ |
| Tool Support | Many | **Many** ✅ | None |
| Learning Curve | Low | **Low** ✅ | Needs learning |

**TOON vs YAML Test Results** (cursor-talk-to-figma-mcp project):
- TOON: 807 tokens
- YAML: 938 tokens
- **Difference**: 131 tokens (14% savings)

**Decision Rationale**:
1. **14% savings is marginal benefit** - Not the expected 30-50%
2. **Content is 85%, structure only 15%** - Limited benefit of optimizing structure
3. **High ecosystem value** - YAML has complete toolchain, IDE support, widespread use
4. **Aligns with "minimalist" philosophy** - Use standard tools, don't reinvent the wheel
5. **Development efficiency** - No need to maintain custom parser and documentation

**Complete Analysis**: See `dev-notes/toon-vs-yaml-analysis.md`

### 5.2 YAML Format Specification

Used for Stage 0 output:

```yaml
metadata:
  project_name: EcommerceAPI
  scan_time: "2025-11-22T10:00:00Z"
  scanned_files: 12
  total_files_estimate: 450

project_fingerprint:
  project_type: WEB_APP
  framework: Rails 7.0
  architecture: Service-oriented
  scale: LARGE

tech_stack:
  backend:
    language: Ruby 3.1
    framework: Rails 7.0
    database: PostgreSQL 14

hypotheses:
  architecture:
    - hypothesis: "Uses Service Object pattern for business logic"
      confidence: 0.9
      evidence: "app/services/ has 15 Service classes"
      validation_method: "Check Service class structure and calling patterns"
```

> **Format Decision History**: v1.0 evaluated custom TOON format (14% token savings), but ultimately chose YAML for ecosystem support. Details in `dev-notes/HISTORY.md` and `dev-notes/toon-vs-yaml-analysis.md`

---

## 6. Command Interface Design

### 6.1 Core Commands (By Priority)

```bash
# Priority ⭐⭐⭐⭐⭐ - Most frequently used features
/atlas.overview                    # Project overview (Stage 0 fingerprint)
/atlas.overview src/api            # Analyze specific directory
/atlas.pattern "api endpoint"      # Learn how project implements API endpoints
/atlas.pattern "background job"    # Learn background job patterns
/atlas.pattern "file upload"       # Learn file upload flow

# Priority ⭐⭐⭐⭐⭐ - Dependency analysis (v2.9 new) ⭐ NEW
/atlas.deps "react"                   # Analyze React usage
/atlas.deps "axios"                   # Analyze axios usage
/atlas.deps "lodash" --breaking       # Show breaking changes impact

# Priority ⭐⭐⭐⭐ - Impact scope analysis
/atlas.impact "User authentication"   # Feature change impact
/atlas.impact api "/api/users/{id}"   # API change impact

# Priority ⭐⭐⭐⭐ - Git history analysis
/atlas.history                        # Entire project hotspots
/atlas.history auth                   # Module analysis (auto-detect)
/atlas.history src/auth/login.ts      # Single file detailed analysis

# Priority ⭐⭐⭐⭐ - Flow tracing
/atlas.flow "user checkout"           # Trace checkout flow
/atlas.flow "from OrderService"       # Trace from specific Service

# Priority ⭐⭐⭐ - Project setup
/atlas.init                           # Inject SourceAtlas trigger rules into CLAUDE.md

# Future features (v3.0+)
/atlas.health             # Project health analysis
/atlas.review PR#123      # PR change analysis
```

**Complete Three-Stage Analysis** (Rare scenario):

For deep due diligence scenarios (evaluating open source projects, hiring assessment, technical due diligence), use `PROMPTS.md` to manually execute complete Stage 0-1-2 analysis:

```bash
# Applicable scenarios:
✅ Evaluate if open source project is suitable for adoption
✅ Evaluate developer candidate's work
✅ Technical due diligence (investment, acquisition)
✅ Complete assessment before major refactoring

# Not applicable to daily development work (use above Commands)
```

### 6.2 Command Definition Structure

#### Example 1: `/atlas.overview` (Project Overview)

```markdown
# .claude/commands/atlas.overview.md

---
description: Get project overview - scan <5% of files to achieve 70-80% understanding
allowed-tools: Bash, Glob, Grep, Read
argument-hint: [optional: specific directory to analyze]
---

# SourceAtlas: Project Overview (Stage 0 Fingerprint)

## Context

Analysis Target: $ARGUMENTS

Goal: Generate project fingerprint by scanning <5% of files in 10-15 minutes.

## Your Task

Execute Stage 0 Analysis using information theory principles:

1. Run: `bash scripts/atlas/detect-project.sh`
2. Run: `bash scripts/atlas/scan-entropy.sh`
3. Apply high-entropy file prioritization
4. Generate 10-15 hypotheses with confidence levels
5. Output YAML format report

### High-Entropy Priority:
1. Documentation (README, CLAUDE.md)
2. Config files (package.json, etc.)
3. Core models (3-5 samples)
4. Entry points (1-2 samples)
5. Tests (1-2 samples)

Output Format: YAML (Standard format with ecosystem support)
Time Limit: 10-15 minutes
Understanding Target: 70-80%

STOP after Stage 0 - do not proceed to validation or git analysis.
```

#### Example 2: `/atlas.pattern` (Learn Design Patterns)

```markdown
# .claude/commands/atlas.pattern.md

---
description: Learn design patterns from the current codebase
allowed-tools: Bash, Glob, Grep, Read
argument-hint: [pattern type, e.g., "api endpoint", "background job"]
---

# SourceAtlas: Pattern Learning Mode

## Context

Project structure: !`tree -L 2 -d --charset ascii`

Pattern type requested: **$ARGUMENTS**

## Your Task

Goal: Help the user learn how THIS codebase implements the requested pattern.

Workflow:
1. Run: `bash scripts/atlas/find-patterns.sh "$ARGUMENTS"`
2. Identify 2-3 exemplary implementations
3. Extract the design pattern
4. Provide actionable guidance

Output Format:
- Pattern name and standard approach
- Best example files with line numbers
- Key conventions to follow
- Common pitfalls to avoid
- Testing patterns

Remember: Scan <5% of files, focus on patterns not exhaustive details.
```

#### Example 3: `/atlas.deps` (Dependency Analysis) ⭐ NEW

```markdown
# .claude/commands/atlas.deps.md

---
description: Analyze dependency usage for library/framework upgrades
allowed-tools: Bash, Glob, Grep, Read, WebFetch
argument-hint: [library name, e.g., "react", "axios", "lodash"]
---

# SourceAtlas: Dependency Analysis

## Context

Target library: $ARGUMENTS

Goal: Analyze how this library is used in the codebase to facilitate upgrade planning.

## Your Task

1. **Identify Current Version**
   - Check package.json, requirements.txt, Cargo.toml, go.mod, etc.
   - Note: locked version vs declared version

2. **Find All Import/Usage Points**
   - Search for import statements
   - Search for require() calls
   - Search for dynamic imports
   - Count total usage occurrences

3. **Categorize API Usage**
   - List all unique APIs/functions used from the library
   - Count usage frequency for each
   - Identify deprecated APIs if known

4. **Breaking Changes Assessment** (if --breaking flag or latest version differs)
   - Fetch library's CHANGELOG or migration guide (WebFetch if needed)
   - Cross-reference with found usages
   - Highlight affected code locations

5. **Generate Migration Checklist**
   - List all files needing changes
   - Provide specific file:line references
   - Estimate effort level

## Output Format

```yaml
dependency_analysis:
  library: [name]
  current_version: [version]
  latest_version: [version]

usage_summary:
  total_imports: [number]
  unique_files: [number]
  api_count: [number]

api_usage:
  - api: [function/class name]
    count: [number]
    files: [list of file:line]
    status: compatible | deprecated | removed

breaking_changes:
  - change: [description]
    affected_files: [count]
    locations:
      - file: [path]
        line: [number]
        current_usage: [code snippet]
        migration: [suggested fix]

migration_checklist:
  - task: [description]
    files: [list]
    effort: low | medium | high

risk_level: low | medium | high
estimated_effort: [hours]
```

## Key Principles

- Focus on USED APIs, not all available APIs
- Provide specific file:line references (Constitution Article IV)
- Include migration suggestions, not just problem identification
- Assess risk honestly
```

---

#### Example 4: `/atlas.init` (Project Setup)

```markdown
# .claude/commands/atlas.init.md

---
description: Initialize SourceAtlas in current project - inject auto-trigger rules into CLAUDE.md
allowed-tools: Read, Write, Edit
---

# SourceAtlas: Project Initialization

## Purpose

Inject SourceAtlas auto-trigger rules into the project's CLAUDE.md so Claude Code
knows when to automatically suggest using Atlas commands.

## Behavior

1. Check if CLAUDE.md exists in project root
2. If exists: Append SourceAtlas section (avoid duplicates)
3. If not exists: Create minimal CLAUDE.md with SourceAtlas section

## Injected Content (English)

The command injects the following section:

## SourceAtlas Auto-Trigger Rules

When encountering these situations, automatically execute the corresponding command:

| User Intent | Command |
|-------------|---------|
| "What is this project", "Help me understand codebase" | `/atlas.overview` |
| "How to implement X pattern", "Learn the approach" | `/atlas.pattern [pattern]` |
| "What will this change affect" | `/atlas.impact [target]` |
| Just entered project + unfamiliar | `/atlas.overview` |

## Design Rationale

- Similar to spec-kit's `specify init` approach
- Enables Claude Code to auto-suggest Atlas commands contextually
- Uses English by default (international standard)
- Non-invasive: appends to existing CLAUDE.md
```

---

## 7. Scripts Design

### 7.1 Design Principles

**Scripts only do data collection, not understanding reasoning**

```bash
# ✅ Good Script Design
detect_project_type() {
    # Output raw data
    echo "package.json: $(test -f package.json && echo 'exists')"
    echo "composer.json: $(test -f composer.json && echo 'exists')"
    # AI judges itself whether it's Node or PHP project
}

# ❌ Bad Script Design
detect_project_type() {
    # Don't do judgment logic in Script
    if [ -f "package.json" ]; then
        echo "This is a Node.js project"
    fi
}
```

### 7.2 Core Scripts

#### scripts/atlas.stage0.sh

```bash
#!/bin/bash
# Stage 0: Collect basic project information

main() {
    echo "=== Project Detection ==="
    detect_project_files

    echo ""
    echo "=== Project Stats ==="
    project_statistics

    echo ""
    echo "=== High-Entropy Files ==="
    list_high_entropy_files

    echo ""
    echo "=== Directory Structure ==="
    show_structure
}

detect_project_files() {
    # Check if key files exist
    for file in package.json composer.json requirements.txt Gemfile pom.xml; do
        [ -f "$file" ] && echo "Found: $file"
    done
}

project_statistics() {
    # Basic statistics
    echo "Total files: $(find . -type f | wc -l)"
    echo "Total lines: $(find . -name '*.rb' -o -name '*.js' | xargs wc -l | tail -1)"
    echo "Languages: $(find . -name '*.rb' -o -name '*.js' -o -name '*.py' | \
                         sed 's/.*\.//' | sort | uniq -c)"
}

list_high_entropy_files() {
    # List high-entropy files (README, configs, Models)
    find . -maxdepth 2 -iname 'readme*' -o -iname 'claude*'
    find . -name 'package.json' -o -name 'composer.json'
    find . -path '*/models/*' -o -path '*/app/models/*' | head -5
}

show_structure() {
    # Show directory structure (2 levels)
    tree -L 2 -d --charset ascii 2>/dev/null || find . -maxdepth 2 -type d
}

main
```

#### scripts/atlas.find.sh

```bash
#!/bin/bash
# Smart search helper tool

search_term="$1"

main() {
    echo "=== File Name Search ==="
    find . -iname "*${search_term}*" -type f | head -10

    echo ""
    echo "=== Content Search ==="
    grep -r -i "$search_term" --include="*.rb" --include="*.js" . | head -20

    echo ""
    echo "=== Related Files ==="
    # After finding files containing search term, list their dependencies
    grep -l -r -i "$search_term" . | head -5
}

main
```

### 7.3 Scripts vs AI Division of Labor

| Task | Responsible | Example |
|------|------------|---------|
| File listing | Script | `find . -name "*.rb"` |
| Content search | Script | `grep -r "User"` |
| Statistics | Script | `wc -l`, `git log --stat` |
| **Understand intent** | AI | "This is user authentication module" |
| **Identify patterns** | AI | "Uses Service Object pattern" |
| **Infer relationships** | AI | "Changing User model will affect Order" |
| **Generate suggestions** | AI | "Suggest splitting into multiple Services" |

---

## 8. Analysis Methodology

### 8.1 High-Entropy File Priority Strategy (Retain v2.0)

**Information Theory Basis**:
```
Information Entropy = Amount of "surprising" information a file contains

High-entropy files: README.md, Models, config files
  → Contains project-level understanding, data structures, architecture decisions

Low-entropy files: Repetitive CRUD Controllers, boilerplate code
  → Patterns are predictable, low value when viewed alone
```

**Scanning Priority**:
```
1. README.md, CLAUDE.md        (project description, specifications)
2. package.json, composer.json (tech stack, dependencies)
3. Models (3-5 core)           (data structure)
4. Routes, Controllers (1-2)   (API design)
5. Main config files           (environment, integration)
```

### 8.2 Bayesian Reasoning Model (Retain v2.0)

```
Prior Probability (Stage 0) + Evidence (Stage 1) = Posterior Probability

Example:
Stage 0 hypothesis: "Uses JWT authentication" (confidence 0.7)
  Based on: package.json has jsonwebtoken

Stage 1 validation: grep "jwt" → Found 5 usage points
  Evidence: Auth middleware, Token generation, validation logic

Posterior probability: Confidence raised to 0.95 ✅ Confirmed
```

### 8.3 Pattern Recognition Rules

#### Architecture Patterns

```yaml
MVC:
  indicators:
    - directories: [models, views, controllers]
    - framework: Rails, Django

Service-oriented:
  indicators:
    - directory: services/
    - naming: *_service.rb
    - pattern: Single responsibility

Microservices:
  indicators:
    - multiple: package.json
    - docker: docker-compose.yml
    - gateway: API gateway config
```

#### Design Patterns

```yaml
Repository:
  indicators:
    - suffix: Repository
    - methods: [find, save, delete]

Factory:
  indicators:
    - suffix: Factory
    - methods: [create, build]

Observer:
  indicators:
    - methods: [subscribe, notify]
    - gems: [wisper, eventmachine]
```

---

## 9. Implementation Specifications

### 9.1 Tech Stack

```yaml
skill:
  format: Markdown
  location: .claude/skills/atlas.md
  size: ~500 lines

scripts:
  language: Bash (POSIX)
  location: scripts/
  total_size: ~1000 lines

  dependencies:
    required: [bash, find, grep, git]
    optional: [tree, jq]

templates:
  format: Plain text + YAML
  location: templates/
```

### 9.2 Development Priorities

#### Phase 1: Core Commands Framework (Week 1)
- [x] Create `.claude/commands/` directory structure ✅
- [x] Implement `/atlas.overview` - Project fingerprint ⭐⭐⭐⭐⭐ ✅ (2025-11-20)
- [x] Implement `/atlas.pattern` - Learn patterns ⭐⭐⭐⭐⭐ ✅ (2025-11-22)
- [x] Implement `find-patterns.sh` script ✅ (2025-11-22)
- [x] YAML format output ✅ (v1.0 decision)

#### Phase 2: Impact Analysis Features
- [x] Implement `/atlas.impact` - Static impact analysis ⭐⭐⭐⭐ ✅ (2025-11-25)
  - API change impact (Scenario 3B)
  - Frontend-backend call chain analysis
  - Test impact assessment
  - Swift/ObjC language deep analysis (auto-triggered)

#### Phase 3: Enhancement & Release (Current)
- [x] Implement `/atlas.init` - Project setup ⭐⭐⭐ ✅ (2025-11-30)
  - Inject SourceAtlas trigger rules into CLAUDE.md
  - Let Claude Code auto-suggest using Atlas commands
- [x] Expand multi-language support (Kotlin ✅, Python ✅, TypeScript/React/Vue ✅, Go/Rust TBD)
- [ ] Improve Git analysis Scripts
- [ ] Overall testing and documentation
- [ ] User feedback collection
- [ ] Release v2.5.4

**Decision**: `/atlas.find` cancelled (functionality covered by existing 3 commands)

---

## 10. Success Metrics

### 10.1 Quantitative Metrics

| Metric | Target | Measurement | v2.0 Validation Result |
|--------|--------|-------------|----------------------|
| **Understanding Accuracy** | >85% | AI can correctly locate features | ✅ 87-100% |
| **Token Savings** | >80% | vs complete file reading | ✅ 95%+ |
| **Time Savings** | >90% | vs manual understanding | ✅ 95%+ |
| **Stage 0 Accuracy** | >70% | Hypothesis validation rate | ✅ 75-95% |
| **Usage Frequency** | 3+ times/day | Developer actual usage | 🔜 To test |

### 10.2 Qualitative Metrics

```yaml
user_experience:
  - Learning cost: < 5 minutes to get started
  - Response speed: < 30 seconds to get results
  - Accuracy: 85%+ useful
  - Integration: Seamlessly integrated into workflow

technical_quality:
  - Script execution: < 5 seconds to complete data collection
  - Error handling: Graceful degradation
  - Compatibility: Support mainstream languages (Ruby, JS, Python, Go)
```

### 10.3 Acceptance Criteria

#### Basic Features
- [x] Stage 0 can complete analysis within 15 minutes ✅
- [x] Stage 1 validation rate >80% ✅
- [x] Stage 2 identifies AI collaboration patterns ✅
- [x] `/atlas.overview` can quickly generate project fingerprint ✅ (2025-11-20)
- [x] `/atlas.pattern` can identify design patterns ✅ (2025-11-22, 95%+ accuracy)
- [x] `/atlas.impact` static impact analysis ✅ (2025-11-25, 4.2/5 average rating, 8 subagent tests)

#### Quality Standards
- [x] Tested on 4+ real projects ✅ (`/atlas.pattern` tested on 3 large projects)
- [x] Scripts run on macOS ✅ (Linux to be tested)
- [x] Provide clear messages on errors ✅
- [ ] User feedback >4/5 score (to be collected)

---

## 11. Implementation Roadmap

> **Detailed Roadmap & Version History**: See [dev-notes/ROADMAP.md](./dev-notes/ROADMAP.md)
>
> **Historical Version Detailed Records**: See [dev-notes/archives/2025-11-prd-roadmap-history.md](./dev-notes/archives/2025-11-prd-roadmap-history.md)

### Current Status Summary

| Version | Status | Main Features |
|---------|--------|--------------|
| v1.0 | ✅ | Methodology validation (5 project tests) |
| v2.5.4 | ✅ | Commands architecture + 141 patterns |
| v2.6.0 | ✅ | `/atlas.history` temporal analysis |
| v2.7.0 | ✅ | `/atlas.flow` flow tracing (11 patterns) |
| v2.8.1 | ✅ | Constitution v1.1 + Handoffs |
| v2.9.0 | ✅ | `/atlas.deps` dependency analysis |
| v3.0 | 🔮 | Language expansion (Go/Ruby) + Monitor |

### Core Commands

| Command | Purpose | Completion Date |
|---------|---------|----------------|
| `/atlas.init` | Project initialization | 2025-11-30 |
| `/atlas.overview` | Project fingerprint | 2025-11-20 |
| `/atlas.pattern` | Learn design patterns | 2025-11-22 |
| `/atlas.impact` | Impact scope analysis | 2025-11-25 |
| `/atlas.history` | Git temporal analysis | 2025-11-30 |
| `/atlas.flow` | Flow tracing | 2025-12-01 |
| `/atlas.deps` | Dependency analysis | 2025-12-12 |

---

## Appendix A: Design Decision Records

> **Complete Design Decision Records**: See [dev-notes/archives/decisions/2025-11-prd-design-decisions.md](./dev-notes/archives/decisions/2025-11-prd-design-decisions.md)

### Key Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| CLI vs Commands | Commands | Native integration, fast development, user control |
| Scripts Responsibility | Only data collection | AI handles understanding reasoning |
| Continuous Indexing | Deferred | First validate real-time exploration value |
| YAML vs TOON | YAML | Ecosystem > 14% token optimization |

---

## Version Information

**Current Version**: v2.9.0 (2025-12-08)

**Development Status**:
- v1.0 ✅ - Methodology validation completed (5 project tests)
- v2.5.4 ✅ - Commands architecture completed
  - `/atlas.overview` ✅ - Project overview (completed, 2025-11-20)
  - `/atlas.pattern` ✅ - Pattern learning (completed, 2025-11-22) ⭐
  - `/atlas.impact` ✅ - Static impact analysis (completed, 2025-11-25)
  - `/atlas.init` ✅ - Project initialization (completed, 2025-11-30)
  - **Multi-language support**: iOS (34), Kotlin (31), Python (26), TypeScript/React/Vue (50) = 141 patterns
- v2.6.0 ✅ - Temporal analysis completed
  - `/atlas.history` ✅ - Git history analysis (completed, 2025-11-30)
  - **Core outputs**: Hotspots + Coupling + Recent Contributors
- v2.7.0 ✅ - Flow analysis completed
  - `/atlas.flow` ✅ - Flow tracing (completed, 2025-12-01) ⭐
  - **11 analysis patterns**: Language-specific entry point detection
  - **10 boundary types**: API, DB, LIB, LOOP, MQ, CLOUD, AUTH, PAY, FILE, PUSH
  - **Entry point identification accuracy**: 60% → 90%
- v2.8.0 ✅ - Constitution v1.0 quality framework
  - **Constitution v1.0** ✅ - Immutable principles for analysis behavior (completed, 2025-12-05)
  - **validate-constitution.sh** ✅ - Automated compliance validation
  - **Monorepo detection** ✅ - lerna/pnpm/nx/turborepo/npm workspaces
  - **Quality improvements**: +3900% file:line references, -63% output lines, -95% validation cost
- v2.8.1 ✅ - Discovery-driven Handoffs
  - **Constitution v1.1** ✅ - Added Article VII: Handoffs Principles (completed, 2025-12-06)
  - **Dynamic next step suggestions** ✅ - Based on analysis findings, suggest 1-2 most relevant follow-up commands
  - **5 Sections**: Discovery-driven, termination conditions, suggestion count, parameter quality, rationale quality
  - **Test results**: 27 scenarios 95%+ maturity
- v2.9.0 🔵 - Dependency Analysis ⭐ IN PROGRESS
  - `/atlas.deps` 🔵 - Dependency usage analysis (in development)
  - **Core features**: Library usage point inventory, Breaking Change comparison, Migration Checklist
  - **Target scenario**: Library/Framework upgrades (Scenario 8)
- **Complete three-stage analysis**: Use `PROMPTS.md` manual execution (deep due diligence scenarios)

**Decision Records** (2025-12-08) - v2.9.0:
- 🔵 **Added `/atlas.deps` command**: Specifically handles Library/Framework upgrade scenarios
  - **Problem identification**: Scenario 8 (Library upgrades) currently lacks specialized tools
  - **Design choice**: New command (semantic clarity) rather than extending impact (conceptual confusion)
  - **Core features**: Usage inventory, Breaking Change comparison, Migration Checklist
  - **Output format**: YAML (complies with existing Constitution specifications)

**Decision Records** (2025-12-06) - v2.8.2:
- ✅ **Branch-Aware Context**: Learning from spec-kit's context-aware design
  - **Git branch detection**: Auto-identify current branch
  - **Monorepo subdirectory awareness**: Detect relative paths
  - **Package name identification**: Extract from package.json/Cargo.toml/go.mod/pyproject.toml
  - **Context Metadata**: YAML metadata includes `context` block
- ✅ **--save parameter**: Optional save analysis results to `.sourceatlas/overview.yaml`
- ✅ **Built-in quality checks**: Constitution Section 5.4

**Decision Records** (2025-12-06) - v2.8.1:
- ✅ Constitution v1.1 implemented: Added Article VII: Handoffs Principles
- ✅ Discovery-driven Handoffs completed: 27 test scenarios validated, 95%+ maturity
  - **Core insight**: SourceAtlas is exploratory tool (non-linear), not suitable for spec-kit's linear handoffs
  - **Design choice**: Dynamically generate suggestions based on actual findings, not statically list all possible commands
  - **5 Sections**: Discovery-driven(7.1), termination conditions(7.2), suggestion count(7.3), parameter quality(7.4), rationale quality(7.5)
- ❌ `/atlas.validate` command cancelled: Changed to built-in quality checks
  - **Inspiration source**: spec-kit checklist.md's "Unit Tests for English" concept
  - **Cancellation reason**: Standalone command over-engineered, analysis outputs usually consumed immediately, judge quality themselves
  - **Alternative approach**: Built-in automatic checks before each command output, warn if non-compliant

**Decision Records** (2025-12-05):
- ✅ Constitution v1.0 implemented: Learning from spec-kit's Constitution pattern
- ✅ 7 Articles: Information theory, exclusion principles, hypothesis principles, evidence principles, output principles, scale awareness, revision principles

**Decision Records** (2025-12-01):
- ✅ `/atlas.flow` P0-A accuracy improvement: Language-specific patterns + confidence scoring

**Decision Records** (2025-11-30):
- ✅ Naming decision: `/atlas.history` (3 votes won, intuitive, cross-platform universal)
- ✅ Design decision: Single command + smart output (zero parameters preferred, facilitates cross-platform porting)
- ✅ Remove `/atlas.expert` - Low value for legacy takeovers (original author may have left)
- ✅ Politically friendly design: Show "Recent Contributors" instead of "Ownership %"

**Decision Records** (2025-11-25):
- ✅ Cancel `/atlas.find` - Functionality already covered by existing 3 commands

> **Complete Version History & Decision Records**: See `dev-notes/HISTORY.md`

---

*This document is licensed under CC-BY-SA 4.0*
