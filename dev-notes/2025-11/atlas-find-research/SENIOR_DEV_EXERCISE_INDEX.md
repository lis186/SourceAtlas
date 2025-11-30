# Senior iOS Developer - `/atlas.find` Query Exercise

**Purpose**: Understand how experienced iOS engineers query large unfamiliar codebases, and what `/atlas.find` should support.

**Created**: November 25, 2025
**Scope**: 25 realistic technical queries across 2 large iOS projects (Signal-iOS, WordPress-iOS)

---

## Documents in This Exercise

### 1. Quick Reference (3-5 min read) ⭐ START HERE
**File**: `QUICK_REFERENCE_SENIOR_DEV_QUERIES.md` (195 lines, 8KB)

One-page cheat sheet for quick lookups:
- Investigation goals with query sets
- Query pattern templates
- Red flags to watch for
- Do's and Don'ts
- File categories to prioritize

**Perfect for**: Getting a quick overview before diving deeper

---

### 2. Full Reference (20-30 min read)
**File**: `ios-senior-dev-atlas-find-queries.md` (326 lines, 16KB)

Comprehensive analysis with 5 developer personas:

1. **Signal-iOS: E2EE Architecture** (Security-focused)
   - Goal: Implement new message feature safely
   - 5 queries targeting encryption, persistence, NSE
   - Time: 3-4 hours | Files: 10-15

2. **Signal-iOS: Call Infrastructure** (Real-time comms specialist)
   - Goal: Optimize call connection setup
   - 5 queries targeting WebRTC, audio, state management
   - Time: 2-3 hours | Files: 15-20

3. **WordPress-iOS: REST API Integration** (API architect)
   - Goal: Add new REST endpoint
   - 5 queries targeting API layer, Flux, auth
   - Time: 2-3 hours | Files: 5-8

4. **WordPress-iOS: Share Extension** (Extensions specialist)
   - Goal: Extend Share Extension for new content types
   - 5 queries targeting UTTypes, App Groups, NSE
   - Time: 2-3 hours | Files: 10-15

5. **WordPress-iOS: Modular Architecture** (SPM specialist)
   - Goal: Extract feature module as reusable package
   - 5 queries targeting module boundaries, protocols, precedents
   - Time: 2-3 hours | Files: 8-12

**Perfect for**: Understanding the full context and multiple real scenarios

---

### 3. Pattern Reference (15-20 min read)
**File**: `SENIOR_DEV_QUERY_PATTERNS.md` (223 lines, 8KB)

Query pattern analysis and design implications:

**6 Query Patterns**:
1. Architecture + Flow (data transformation)
2. System Boundaries (isolated component communication)
3. Consistency & Safety (atomic/transactional guarantees)
4. Implementation Precedent (learn from existing examples)
5. Technology Integration (external tech wrappers)
6. Module Structure (layout and dependencies)

**File count expectations** by pattern type
**Time investment goals** (2-4 hours per investigation)
**Red flags** indicating risky areas to investigate carefully

**Design implications** for `/atlas.find` implementation

**Perfect for**: Understanding the patterns behind effective queries

---

## Key Takeaways

### What Senior iOS Devs Actually Query For

1. **Architecture patterns**, not implementations
   - NOT: "find InteractionStore.swift"
   - YES: "encrypt message database store secure encapsulation"

2. **System boundaries**, not individual features
   - NOT: "show me call code"
   - YES: "notification service extension decrypt NSE message key"

3. **Integration points**, not comprehensive understanding
   - NOT: "understand all of Flux"
   - YES: "flux store state reducer action dispatch side effects"

4. **Precedent examples**, not original solutions
   - NOT: "how do I handle conflicts"
   - YES: "post revision draft autosave conflict resolution strategy"

5. **Consistency guarantees**, not business logic
   - NOT: "how does messaging work"
   - YES: "transaction atomic write message attachment consistency"

### Why These Queries Work

- **Leverage domain knowledge**: Senior devs already know iOS patterns
- **Target integration points**: Focus on where new code attaches
- **Identify risks early**: Consistency, security, compatibility concerns
- **Follow precedent**: Learn from existing solutions
- **Respect scope**: 10-15 files is reasonable, 2,667 is not

### Time Efficiency

Senior developers set strict time budgets:
- **< 2 hours**: Focused bug investigation, simple feature extension
- **2-3 hours**: Moderate feature integration (API endpoint, UI extension)
- **3-4 hours**: Deep architecture review (E2EE understanding, state management)
- **4+ hours**: Unacceptable for navigation; indicates missing architecture knowledge

Corresponding file counts:
- **5-8 files**: Core API/integration layer
- **10-15 files**: Architecture + integration points
- **15-20 files**: Comprehensive subsystem (calls, uploads, etc.)

---

## Project Comparison

### Signal-iOS (2,667 files)
**Domain**: End-to-end encrypted messaging
**Key challenges**:
- Understanding security-critical paths (encryption, message persistence)
- NSE constraints and key sharing
- Real-time communication (WebRTC, calls)

**Senior dev focus areas**:
- Message flow: UI → encryption → storage
- NSE: Separate process constraints
- Calls: WebRTC, audio routing, state transitions
- Data consistency: GRDB transactions

### WordPress-iOS (3,639 files)
**Domain**: Content management and publishing
**Key challenges**:
- State management (custom Flux)
- REST API integration
- Module boundaries (30+ SPM packages)
- Extensions (Share, NSE)

**Senior dev focus areas**:
- API layer: REST client → models → store
- State management: Flux reducers and actions
- Extensions: Sandbox constraints, app group communication
- Module extraction: Public API boundaries

---

## For the SourceAtlas Team

This exercise reveals what `/atlas.find` should optimize for:

### Core Capabilities Needed

1. **Pattern-aware search**
   - Index files by architectural patterns (Store, Repository, Factory, Flux Reducer)
   - Return files that define patterns, not just use them

2. **Context-sensitive results**
   - Understand query intent from terms like "encrypt → database"
   - Return data flow sequence, not scattered matches

3. **Boundary detection**
   - Highlight module/system boundaries
   - Surface integration points where new code attaches

4. **Precedent finding**
   - "This pattern also used in..." suggestions
   - Cross-reference similar solutions

5. **Risk annotation**
   - Flag consistency/concurrency implications
   - Highlight security-sensitive areas
   - Note data corruption risks

6. **Scope limiting**
   - Return "top 10-15 most important files" not all 200 matches
   - Respect developer time budgets (2-4 hours max)

7. **Pattern templates**
   - Help developers ask better questions
   - Suggest queries based on their goal

### Example Improvements

**Current behavior** (hypothetical):
- Query: "message encrypt store"
- Result: 47 files with all three words (including message display, encryption tests, storage utilities)
- Time to useful information: 30 minutes (reading through irrelevant files)

**Desired behavior**:
- Query: "message encrypt store"
- Result: InteractionStore.swift, MessageCrypto.swift, SignalProtocolStore.swift, etc. (8 core files)
- Time to useful information: 5 minutes (focused architecture files)
- Annotation: "These define how encrypted messages are persisted atomically"

---

## How to Use These Documents

### For `/atlas.find` Implementation
1. Read `SENIOR_DEV_QUERY_PATTERNS.md` for design principles
2. Review `QUICK_REFERENCE_SENIOR_DEV_QUERIES.md` for red flags and patterns
3. Study `ios-senior-dev-atlas-find-queries.md` for real scenarios

### For Training Users
1. Show `QUICK_REFERENCE_SENIOR_DEV_QUERIES.md` first (patterns and examples)
2. Reference `ios-senior-dev-atlas-find-queries.md` for detailed scenarios
3. Use `SENIOR_DEV_QUERY_PATTERNS.md` for pattern templates

### For Evaluating `/atlas.find` Effectiveness
Test against these 25 queries:
- Can it return the right 10-15 files in < 5 seconds?
- Does it understand the data flow intent?
- Does it highlight integration points?
- Does it suggest precedent examples?
- Does it surface risk areas?

---

## Statistics

| Metric | Value |
|--------|-------|
| Total lines | 744 |
| Total size | 32 KB |
| Personas | 5 |
| Queries | 25 |
| Projects covered | 2 |
| Expected files per query | 5-20 |
| Total development time for investigations | 2-4 hours |

---

## Related Reading

- `CLAUDE.md` - Project overview and methodology
- `PRD.md` - Product requirements for v2.5
- `dev-notes/KEY_LEARNINGS.md` - v1.0 validation findings
- `dev-notes/HISTORY.md` - Project timeline

---

## Feedback

This exercise demonstrates that senior developers:
1. Know what they're looking for (patterns, not code)
2. Query strategically (integration points, not features)
3. Respect their own time (2-4 hour investigations)
4. Leverage domain knowledge (iOS patterns, security, state management)
5. Seek precedent (learn from existing implementations)

The `/atlas.find` tool should be designed to support these proven behaviors.

