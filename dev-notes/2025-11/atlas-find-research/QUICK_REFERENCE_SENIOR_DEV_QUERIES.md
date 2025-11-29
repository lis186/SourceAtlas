# Quick Reference: Senior iOS Developer `/atlas-find` Queries

## One-Page Cheat Sheet

### By Investigation Goal

#### Goal: Understand Message Encryption & Persistence
**Project**: Signal-iOS | **Time**: 3-4h | **Files**: 10-15

1. `encrypt message database store secure encapsulation` → InteractionStore, crypto layer
2. `transaction atomic write message attachment consistency` → GRDB patterns
3. `signal protocol double ratchet session key rotation` → Key lifecycle

#### Goal: Add New REST Endpoint
**Project**: WordPress-iOS | **Time**: 2-3h | **Files**: 5-8

1. `REST API endpoint response parsing model mapping repository` → WordPressKit client
2. `flux store state reducer action dispatch side effects` → State management
3. `authentication token refresh session invalidation` → Auth lifecycle

#### Goal: Optimize Call Performance
**Project**: Signal-iOS | **Time**: 2-3h | **Files**: 15-20

1. `call link voice video call connection setup initialization` → Call establishment
2. `WebRTC peer connection ICE candidate offer answer SDP` → RTC integration
3. `call audio route speaker phone bluetooth microphone` → Audio management

#### Goal: Extend Share Extension
**Project**: WordPress-iOS | **Time**: 2-3h | **Files**: 10-15

1. `share extension content type activity detection URI provider` → Content detection
2. `share extension to main app data handoff secure container` → App Group communication
3. `WordPress blog selector multi-site account selection interface` → Site selection UI

#### Goal: Extract Modular Package
**Project**: WordPress-iOS | **Time**: 2-3h | **Files**: 8-12

1. `SPM module package swift dependency internal external targets` → Module structure
2. `WordPressCore protocol abstraction dependency injection container` → Contracts
3. `DesignSystem component foundation shared SwiftUI theming` → Precedent example

#### Goal: Fix NSE Message Decryption
**Project**: Signal-iOS | **Time**: 2h | **Files**: 8-12

1. `notification service extension decrypt NSE message key` → NSE crypto
2. `transaction atomic write message attachment consistency` → Persistence guarantee
3. `signal protocol double ratchet session key rotation` → Key management

---

## Query Pattern Quick Reference

| Pattern | Template | Example |
|---------|----------|---------|
| **Architecture Flow** | `[component] [component] [operation]` | "encrypt message database store" |
| **System Boundary** | `[extension/module] [protocol] [other system]` | "share extension to main app data handoff" |
| **Consistency** | `[operation] [guarantee] [mechanism]` | "transaction atomic write consistency" |
| **Precedent** | `[feature] [pattern/strategy]` | "post revision conflict resolution strategy" |
| **Technology** | `[tech] [integration] [iOS API]` | "WebRTC peer connection ICE candidate" |
| **Module** | `[module] [boundary] [dependency]` | "SPM module package swift dependency" |

---

## Red Flags to Watch For

When a senior dev queries these terms, they're investigating **risky areas**:

- "atomic" / "transaction" → Concurrency/consistency issues
- "encrypt" / "key" / "token" → Security vulnerabilities
- "conflict" / "resolution" → Data corruption risks
- "invalidation" → Session/auth edge cases
- "background task" → App lifecycle issues
- "extension" → Sandbox/entitlement boundary
- "rotation" → Key material/secret lifecycle

---

## Expected Results Summary

| Scenario | Files | Time | Questions Answered |
|----------|-------|------|-------------------|
| Security architecture review | 10-15 | 3-4h | Is E2EE maintained? Safe integration point? |
| API integration | 5-8 | 2-3h | Where does new endpoint fit? What patterns exist? |
| Real-time optimization | 15-20 | 2-3h | What's the signal path? Where's the bottleneck? |
| Extension development | 10-15 | 2-3h | How do extensions communicate? What's in/out of sandbox? |
| Module extraction | 8-12 | 2-3h | How are modules decoupled? What APIs are stable? |
| Bug investigation | 8-12 | 2h | What's the data flow? Where could corruption happen? |

---

## Do's and Don'ts

### DO ✓
- Be specific: "notification service extension decrypt NSE message" (not "NSE")
- Target flows: "API → model → store update" (not just "API")
- Assume expertise: Use domain terminology (Flux, WebRTC, GRDB)
- Seek precedent: "like post revision strategy" (learn from existing)
- Flag risk: Query for "atomic", "consistent", "secure" when needed

### DON'T ✗
- Be vague: "how does messaging work" (too broad)
- Query implementations: "find InteractionStore.swift" (use file search instead)
- Ignore context: "show me everything about calls" (that's 50+ files)
- Query syntax: "what is @Observable" (that's documentation, not navigation)
- Seek exhaustiveness: "understand all of Flux" (impossible in 2 hours)

---

## Senior Dev Mental Model

When a senior dev needs to understand unfamiliar code:

```
1. IDENTIFY GOAL
   "I need to add a new feature safely"

2. DECOMPOSE INTO LAYERS
   "Where does it integrate?"
   "What are consistency guarantees?"
   "What's the precedent?"

3. QUERY FOR CRITICAL FILES
   "encrypt message database store"
   "transaction atomic write"
   "signal protocol key rotation"

4. READ THOSE 10-15 FILES
   → Understand architecture
   → Identify integration point
   → Verify safety guarantees

5. IMPLEMENT WITH CONFIDENCE
   "I know what can break and how to avoid it"
```

---

## File Categories They'll Look For

### Core Architecture (must read)
- Store/Repository abstractions
- State management patterns
- API client abstraction
- Model/entity definitions

### Integration Points (must read)
- Module boundaries/protocols
- Extension communication (NSE, Share)
- HTTP/RTC/database wrappers
- Authentication/authorization flow

### Safety Guarantees (must read)
- Transaction/atomic operation patterns
- Conflict resolution strategies
- Error recovery mechanisms
- Consistency checks

### Implementation Details (optional)
- UI/View components
- Specific business logic
- Utility functions
- Test infrastructure

---

## Project-Specific Checklists

### For Signal-iOS
- [ ] Understand InteractionStore pattern
- [ ] Understand SignalProtocolStore key lifecycle
- [ ] Understand NSE constraints and key sharing
- [ ] Understand GRDB transaction patterns
- [ ] Understand message flow end-to-end

### For WordPress-iOS
- [ ] Understand Flux reducer pattern
- [ ] Understand REST client abstraction
- [ ] Understand model mapping layer
- [ ] Understand App Group communication
- [ ] Understand module boundaries (SPM)

---

## Tools This Exercise Shows

`/atlas-find` should support these features:

1. **Context-aware search**: Understand "encrypt → database" means full flow
2. **Pattern indexing**: Index by architectural pattern, not just keywords
3. **Boundary highlighting**: Surface integration points
4. **Risk annotation**: Flag consistency/security implications
5. **Precedent linking**: "This pattern also used in..."
6. **Scope limiting**: "Top 15 most important files" not "all 300 matches"
7. **Pattern templates**: Help users ask the right questions

