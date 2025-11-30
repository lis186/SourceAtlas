# Senior iOS Developer Query Patterns for `/atlas.find`

Quick reference: How experienced iOS developers query large codebases.

## Query Pattern #1: Architecture + Flow

**Template**: `[component] [component] [operation] [goal]`

**Examples**:
- "encrypt message database store secure encapsulation"
- "REST API endpoint response parsing model mapping"
- "share extension to main app data handoff secure container"

**What they're finding**: Data flow through architectural layers
**Files to expect**: 3-8 core files showing transformation pipeline

---

## Query Pattern #2: System Boundaries

**Template**: `[extension/module] [communication/protocol] [other system]`

**Examples**:
- "notification service extension decrypt NSE message key"
- "share extension to main app data handoff App Groups"
- "module dependency injection protocol abstraction"

**What they're finding**: How isolated components talk to each other
**Files to expect**: 4-6 files showing interface boundaries

---

## Query Pattern #3: Consistency & Safety

**Template**: `[operation] [consistency/safety guarantee] [mechanism]`

**Examples**:
- "transaction atomic write message attachment consistency"
- "conflict resolution draft autosave strategy"
- "token refresh session invalidation SSO flow"

**What they're finding**: How to ensure their changes don't break things
**Files to expect**: 3-5 files showing atomic/transactional patterns

---

## Query Pattern #4: Implementation Precedent

**Template**: `[feature] [implementation style/pattern]`

**Examples**:
- "post revision draft autosave conflict resolution strategy"
- "media library upload progress tracking cancellation backoff"
- "DesignSystem component foundation shared SwiftUI theming"

**What they're finding**: How the codebase solved a similar problem
**Files to expect**: 5-10 files showing the pattern in action

---

## Query Pattern #5: Technology Integration

**Template**: `[technology] [integration mechanism] [iOS API/framework]`

**Examples**:
- "WebRTC peer connection ICE candidate offer answer SDP"
- "signal protocol double ratchet session key rotation"
- "call audio route speaker phone bluetooth microphone"

**What they're finding**: How external tech is wrapped for iOS
**Files to expect**: 4-8 files showing wrapper/abstraction layer

---

## Query Pattern #6: Module Structure

**Template**: `[module/package] [boundary/interface] [dependency]`

**Examples**:
- "SPM module package swift dependency internal external targets"
- "WordPressCore protocol abstraction dependency injection"
- "build settings configuration debug release feature flags"

**What they're finding**: Module layout and dependency graph
**Files to expect**: 3-6 files showing structure and contracts

---

## Red Flags in Senior Dev Queries

These indicate areas that need careful investigation:

1. **Consistency keywords**: "atomic", "transaction", "conflict", "reconciliation"
   - Reason: Want to ensure safe integration

2. **Security keywords**: "encrypt", "secure", "key", "token", "invalidation"
   - Reason: Don't want to introduce vulnerabilities

3. **Boundary keywords**: "extension", "process", "container", "entitlement", "handoff"
   - Reason: Need to understand sandbox/privilege constraints

4. **Precedent keywords**: "strategy", "pattern", "like", "similar", "exists"
   - Reason: Want to follow existing patterns, not invent

---

## File Count Expectations

| Query Type | Expected Files | Investigation Depth |
|------------|----------------|-------------------|
| Architecture flow | 3-8 | Medium (understand data transformation) |
| System boundary | 4-6 | Medium (understand protocol/interface) |
| Consistency guarantee | 3-5 | High (ensure safety) |
| Implementation precedent | 5-10 | Medium-High (learn from example) |
| Technology integration | 4-8 | Medium (understand wrapper layer) |
| Module structure | 3-6 | Low (get layout overview) |

---

## Time Investment Goals

| Investigation Goal | Typical Time | Required Files |
|-------------------|-------------|----------------|
| Security architecture review | 3-4 hours | 10-15 |
| API integration planning | 2-3 hours | 5-8 |
| Call infrastructure optimization | 2-3 hours | 15-20 |
| Share Extension extension | 2-3 hours | 10-15 |
| Module extraction planning | 2-3 hours | 8-12 |

---

## What Senior Devs Avoid Querying

**Too broad** (don't do):
- "how does messaging work"
- "understand the networking layer"
- "show me the architecture"

**Too narrow** (don't do):
- "find InteractionStore.swift"
- "show me line 42 of CallRecordStore"
- "what does @Observable do"

**Just right** (do this):
- "encrypt message database store secure encapsulation" (specific flow)
- "notification service extension decrypt NSE message key" (boundary problem)
- "transaction atomic write message attachment consistency" (consistency guarantee)

---

## Integration with `/atlas.find` Expectations

### Senior devs expect `/atlas.find` to:

1. **Understand intent from context**
   - Query: "metadata encryption strategy"
   - Should find: Pattern of how to encrypt metadata, not just files with "metadata" in name

2. **Prioritize architectural files**
   - Query: "REST API endpoint response parsing"
   - Should surface: API client abstraction, model layer, response mapping
   - Should NOT surface: Every file that parses a response

3. **Show integration points**
   - Query: "share extension to main app data handoff"
   - Should highlight: App Group setup, data serialization points, security boundaries

4. **Provide precedent examples**
   - Query: "conflict resolution strategy"
   - Should show: Existing examples of conflict resolution in the codebase

5. **Respect time budgets**
   - Query: "understand media upload infrastructure"
   - Should return: 8-12 files max, not 200 files with "upload"

---

## Why These Patterns Work

1. **Leverage domain knowledge**: Senior devs know iOS patterns; queries use that knowledge
2. **Target integration points**: Focus on where new code attaches to existing system
3. **Identify risks early**: Query for consistency/security guarantees
4. **Follow precedent**: Find existing examples before implementing
5. **Respect scope**: 10-15 files is a reasonable investigation, 2,667 is not

---

## Examples by Domain Expertise

### Security-Focused Developer
- "encrypt decrypt message secure encapsulation"
- "signal protocol double ratchet session key rotation"
- "transaction atomic write message attachment consistency"

### Real-Time Communications Developer
- "WebRTC peer connection ICE candidate"
- "call state preservation background task"
- "audio route management session"

### API/State Management Developer
- "REST API endpoint response parsing model mapping"
- "flux store state reducer action dispatch"
- "post revision draft autosave conflict resolution"

### Extensions/Modular Architecture Developer
- "share extension content type activity detection"
- "SPM module package swift dependency"
- "build settings configuration debug release"

---

## For `/atlas.find` Implementation Guidance

These query patterns reveal what the search algorithm should optimize for:

1. **Context-aware results**: Understand the investigation goal from query terms
2. **Architectural relevance scoring**: Prioritize files that define patterns over files that use them
3. **Boundary highlighting**: Flag files at module/system boundaries
4. **Integration point surfacing**: Show where new code would attach
5. **Precedent linking**: "This pattern also used in..."
6. **Risk annotation**: Flag consistency/security implications
7. **Scope limiting**: Return "most important 10-15 files" not "all 200 matches"

