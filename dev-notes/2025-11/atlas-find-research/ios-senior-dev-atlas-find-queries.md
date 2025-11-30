# iOS Senior Developer - `/atlas.find` Query Examples

## Executive Summary

This document demonstrates how a **senior iOS engineer (7+ years)** with deep technical expertise would use `/atlas.find` to navigate **large, unfamiliar codebases** efficiently. Instead of reading thousands of files, they ask precise technical queries that leverage domain knowledge to jump directly to implementation details.

**Key insight**: Senior developers don't explore broadly—they target specific architectural patterns they already understand conceptually.

---

## Project Comparison

| Aspect | Signal-iOS | WordPress-iOS |
|--------|-----------|---------------|
| **Files** | 2,667 (Swift/ObjC) | 3,639 (Swift/ObjC) |
| **Domain** | End-to-end encrypted messaging | Content management & publishing |
| **Architecture** | Modular (features by domain) | SPM modular (30+ packages) |
| **Key Challenge** | Security-critical paths | State management (Flux) + API integration |
| **Senior Dev Focus** | Crypto, persistence, NSE | API patterns, module boundaries, extensions |

---

## Developer Persona 1: Signal-iOS (E2EE Architecture)

**Profile**: Senior iOS Engineer, 7+ years, security-focused
**Investigation Goal**: Implementing a new message feature while maintaining end-to-end encryption guarantees
**Time to understand architecture**: 3-4 hours (vs. weeks reading code)

### Queries I would use:

1. **"encrypt message database store secure encapsulation"**
   - What I'm looking for: Data flow from SignalProtocol crypto layer → InteractionStore persistence
   - Why: Ensure new feature doesn't bypass encryption
   - Expected files: `InteractionStore.swift`, `SignalProtocolStore`, message encryption pipeline

2. **"notification service extension decrypt NSE message key"**
   - What I'm looking for: How NSE decrypts messages in a separate process
   - Why: NSE has different entitlements; need to understand key sharing mechanism
   - Expected files: NSE code, key material sharing logic

3. **"transaction atomic write message attachment consistency"**
   - What I'm looking for: GRDB transaction patterns for atomicity
   - Why: New features touching messages must maintain transactional guarantees
   - Expected files: `InteractionStore` transaction patterns, GRDB wrappers

4. **"call record store history metadata encrypted"**
   - What I'm looking for: How sensitive metadata is encrypted at rest
   - Why: Calls are security-sensitive; understand metadata encryption patterns
   - Expected files: `CallRecordStore.swift`, metadata encryption wrappers

5. **"signal protocol double ratchet session key rotation"**
   - What I'm looking for: Double Ratchet implementation for forward secrecy
   - Why: Key lifecycle is critical for secure feature design
   - Expected files: `SignalProtocolStore`, session management code

### What I expect to find:
- 10-15 core security architecture files
- Store pattern abstractions (CallRecordStore, InteractionStore, etc.)
- NSE-specific code paths
- GRDB transaction wrappers
- SignalProtocol FFI bindings

### My efficiency goal:
- Navigate directly to 12 security-critical files (not 2,667)
- Understand end-to-end message flow
- Identify safe extension points
- Verify transactional consistency
- **Complete architecture review in < 4 hours**

---

## Developer Persona 2: Signal-iOS (Call Infrastructure)

**Profile**: Senior iOS Engineer, 7+ years, real-time communications specialist
**Investigation Goal**: Optimize call connection setup and network transition handling
**Time to understand architecture**: 2-3 hours

### Queries I would use:

1. **"call link voice video call connection setup initialization"**
   - Looking for: Call establishment flow from UI → RTC layer
   - Why: Connection time optimization requires understanding signal path
   - Expected files: Call controllers, setup orchestration

2. **"WebRTC peer connection ICE candidate offer answer SDP"**
   - Looking for: WebRTC integration and ICE candidate handling
   - Why: Network transitions fail without proper ICE restart
   - Expected files: WebRTC wrapper, peer connection management

3. **"background task call state preservation termination handler"**
   - Looking for: Call state preservation during backgrounding
   - Why: Calls drop when backgrounded—need state machine understanding
   - Expected files: Call lifecycle manager, background task handlers

4. **"deleted call record cleanup retention policy store"**
   - Looking for: Call history storage and privacy retention
   - Why: Understand side effects of call deletion on other features
   - Expected files: `DeletedCallRecordStore.swift`, `CallRecordStore.swift`

5. **"call audio route speaker phone bluetooth microphone"**
   - Looking for: Audio routing management for different scenarios
   - Why: Audio issues are UX-critical
   - Expected files: Audio route manager, AVAudioSession configuration

### What I expect to find:
- Call state machine and lifecycle
- WebRTC peer connection wrapper
- Audio session/route management
- Background execution handlers
- Network transition logic

### My efficiency goal:
- Isolate call infrastructure (15-20 files)
- Understand state transitions and error recovery
- Find metrics/logging points
- Identify bottlenecks in connection setup

---

## Developer Persona 3: WordPress-iOS (REST API Integration)

**Profile**: Senior iOS Engineer, 7+ years, API architecture specialist
**Investigation Goal**: Add new REST API endpoint following existing patterns
**Time to understand architecture**: 2-3 hours

### Queries I would use:

1. **"REST API endpoint response parsing model mapping repository"**
   - Looking for: REST response → model → reactive updates flow
   - Why: New endpoint must follow patterns, not create custom code
   - Expected files: `WordPressKit` API client, Flux action/store patterns

2. **"flux store state reducer action dispatch side effects"**
   - Looking for: State management pattern and action flow
   - Why: WordPress uses custom Flux; need action dispatch patterns
   - Expected files: `WordPressFlux` module, store implementations

3. **"post revision draft autosave conflict resolution strategy"**
   - Looking for: Draft conflict handling (local edit vs server update)
   - Why: Understand conflict resolution before adding new fields
   - Expected files: Post store, revision management, sync handlers

4. **"media library upload progress tracking cancellation backoff"**
   - Looking for: Large file upload management with network resilience
   - Why: Adding media features requires understanding retry logic
   - Expected files: Media upload manager, progress tracking, error recovery

5. **"authentication token refresh session invalidation SSO flow"**
   - Looking for: OAuth token lifecycle and session management
   - Why: Understand auth boundaries (especially Jetpack integration)
   - Expected files: `WordPressAuthenticator` module, token refresh handlers

### What I expect to find:
- REST client abstractions in `WordPressKit`
- Custom Flux implementation (reducers, stores, actions)
- Model/response mapping layer
- Upload/sync manager
- Auth token lifecycle
- Conflict resolution logic

### My efficiency goal:
- Map Flux architecture (10-12 core store files)
- Understand API layer abstraction (5-8 files)
- Identify integration point for new endpoint
- Find conflict resolution patterns
- **Complete integration planning in < 3 hours**

---

## Developer Persona 4: WordPress-iOS (Share Extension)

**Profile**: Senior iOS Engineer, 7+ years, app extensions specialist
**Investigation Goal**: Extend Share Extension to support new content types
**Time to understand architecture**: 2-3 hours

### Queries I would use:

1. **"share extension content type activity detection URI provider"**
   - Looking for: UTType detection and content processing
   - Why: Add support for new content type without breaking existing ones
   - Expected files: `ShareExtensionCore` module, activity provider handling

2. **"share extension to main app data handoff secure container"**
   - Looking for: Share Extension ↔ Main App communication (App Groups)
   - Why: Understand security boundaries and data passing
   - Expected files: `ShareExtensionCore`, app group coordination

3. **"NotificationServiceExtension message decryption shared keychain"**
   - Looking for: NSE/Share Extension credential sharing
   - Why: Extensions are separate processes; understand entitlements
   - Expected files: `NotificationServiceExtensionCore`, keychain utils

4. **"WordPress blog selector multi-site account selection interface"**
   - Looking for: Site selection logic in Share Extension UI
   - Why: New content means updating site selection
   - Expected files: Share Extension UI, blog selection logic

5. **"metadata preservation custom fields taxonomy tags categories"**
   - Looking for: Metadata extraction and preservation
   - Why: New content type may have different metadata
   - Expected files: Metadata extraction, field mapping

### What I expect to find:
- `ShareExtensionCore` module architecture
- NSE/Share Extension entitlements
- App Group data passing mechanisms
- Blog/site selection UI
- UTType mapping
- Keychain sharing patterns

### My efficiency goal:
- Understand Share Extension sandbox (10-15 files)
- Map Share → Main App data flow
- Identify content type abstraction
- Ensure new type fits pattern
- **Design API in < 2 hours**

---

## Developer Persona 5: WordPress-iOS (Modular Architecture)

**Profile**: Senior iOS Engineer, 7+ years, SPM & modular architecture specialist
**Investigation Goal**: Extract internal feature module and publish as reusable package
**Time to understand architecture**: 2-3 hours

### Queries I would use:

1. **"SPM module package swift dependency internal external targets"**
   - Looking for: Module structure, public/private interface boundaries
   - Why: Know which dependencies to expose vs hide
   - Expected files: `Package.swift` files, module manifests

2. **"WordPressCore protocol abstraction dependency injection container"**
   - Looking for: Module loose coupling through protocols
   - Why: Extraction requires understanding dependency contracts
   - Expected files: `WordPressCoreProtocols`, DI setup

3. **"DesignSystem component foundation shared SwiftUI UIKit theming"**
   - Looking for: Design system consumption patterns
   - Why: DesignSystem extraction is precedent for my module
   - Expected files: `DesignSystem` module, component structure

4. **"build settings configuration debug release feature flags"**
   - Looking for: Build configuration management across modules
   - Why: Module needs to work in different build contexts
   - Expected files: `BuildSettingsKit`, configuration management

5. **"test mock foundation UITestsFoundation module testing utilities"**
   - Looking for: Shared testing infrastructure
   - Why: Extracted module needs proper test support
   - Expected files: `UITestsFoundation`, mock utilities, test helpers

### What I expect to find:
- Clear module boundaries in `Package.swift`
- Protocol-based dependency injection
- Public/private interface segregation
- Cross-module dependency graph
- Shared testing foundation
- Configuration management patterns

### My efficiency goal:
- Understand module boundaries (8-12 files)
- Identify stable public API surface
- Find precedents in existing modules (DesignSystem, JetpackStats)
- Plan extraction strategy with minimal impact
- **Validate approach in < 3 hours**

---

## Key Patterns These Queries Reveal

### 1. Architecture Understanding
- Senior developers query for **patterns**, not implementations
- Examples: "Store pattern", "Flux reducer", "protocol abstraction"
- They leverage existing domain knowledge

### 2. Integration Points
- Focus on **boundaries between systems**
- Examples: "API → model → reactive update", "Share Extension → App Group → Main App"
- Find where new code attaches to existing system

### 3. Risk Identification
- Query for **consistency guarantees**
- Examples: "transaction atomic write", "conflict resolution", "key rotation"
- Understand failure modes before implementing

### 4. Precedent Following
- Look for **existing examples** of the pattern they need
- Examples: "post revision strategy" (for understanding conflict patterns), "DesignSystem" (for module extraction precedent)
- Reuse > invent

### 5. Efficiency Metrics
- Senior developers set **time boundaries** (< 4 hours, < 3 hours, < 2 hours)
- They know what 10-15 files is reasonable, 2,667 is not
- They query to **navigate, not to read everything**

---

## What Makes These Queries Effective

1. **Technical specificity**: Not "how does messaging work" but "how does encryption → storage flow"
2. **Domain expertise**: Queries assume knowledge of E2EE, Flux, SPM, app extensions
3. **Implementation-agnostic**: Focus on patterns, not syntax
4. **Bounded scope**: Each query targets 5-20 files, not hundreds
5. **Risk-aware**: Queries identify consistency, security, and compatibility concerns
6. **Precedent-seeking**: Find existing examples before implementing

---

## For the SourceAtlas Team: Design Implications

These queries show what **senior developers actually need**:

1. **Pattern-based search** - Find implementations of known patterns (Repository, Factory, Flux reducer)
2. **Boundary navigation** - Jump to integration points between systems
3. **Risk assessment** - Flag consistency/security implications
4. **Cross-reference** - "How did this feature solve the same problem?"
5. **Architectural context** - Understand layers without reading all code

**For `/atlas.find` implementation**:
- Index files by architectural patterns, not just keywords
- Surface integration points between modules
- Flag risk areas (security, consistency, performance)
- Provide precedent examples ("like DesignSystem module")
- Focus on "what matters" (10-15 files), not "everything"

