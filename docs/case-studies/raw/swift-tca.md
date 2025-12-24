# TCA (Swift) Case Study - SourceAtlas Analysis

**Project**: [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) - Redux-like unidirectional data flow for Swift
**Language**: Swift
**Codebase Size**: 819 Swift files, ~45,000 LOC
**Analysis Time**: ~15 minutes
**Files Scanned**: 8 files (0.98%)
**Understanding Achieved**: ~80%

---

## Key Discovery

**TCA's power comes from three Swift patterns**: Result Builder for declarative reducer composition, KeyPath/CasePath for type-safe state slicing, and `RootCore._send()` for centralized action processing with reentrancy protection. The **RootCore** is the central runtime - it buffers actions, calls reducers, and processes effects in a tight loop.

---

## Analysis Process

### High-Entropy Files Scanned

| File | Purpose | Key Insight |
|------|---------|-------------|
| `README.md` | Overview | Philosophy: composition, testing, ergonomics |
| `Package.swift` | Config | Swift 6.0, 12+ Point-Free dependencies |
| `Store.swift:194` | Runtime | `@MainActor`, Scope mechanism |
| `Reducer.swift` | Protocol | `body` property pattern |
| `Effect.swift:5-24` | Side effects | Three operation types: none/publisher/run |
| `Core.swift:72-199` | Core logic | `_send()` with bufferedActions queue |
| `ReducerBuilder.swift:1-137` | DSL | `@resultBuilder` for composition |
| `Scope.swift` | Composition | State slicing via KeyPath |

### Core Architecture Discovered

```
┌─────────────────────────────────────────────────────────────┐
│                           Store                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                      RootCore                        │    │
│  │  bufferedActions: [Action]                           │    │
│  │  isSending: Bool (reentrancy guard)                  │    │
│  │  reducer: any Reducer<State, Action>                 │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  @MainActor guarantee for state mutations                    │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼ send(action)
┌─────────────────────────────────────────────────────────────┐
│  RootCore._send()                    [Core.swift:72]        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 1. Buffer action if already sending                  │   │
│  │ 2. isSending = true                                  │   │
│  │ 3. while bufferedActions.isNotEmpty:                 │   │
│  │       action = bufferedActions.removeFirst()         │   │
│  │       effect = reducer.reduce(into:action:)          │   │
│  │       processEffect(effect)                          │   │
│  │ 4. isSending = false                                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Result Builder Composition (`ReducerBuilder.swift:1-137`)

```swift
@resultBuilder
public enum ReducerBuilder<State, Action> {
    public static func buildBlock<R: Reducer>(_ reducer: R) -> R
    where R.State == State, R.Action == Action { reducer }

    // Combines multiple reducers into _Sequence
    public static func buildBlock<R0, R1>(_ r0: R0, _ r1: R1) -> _Sequence<R0, R1>
    where R0.State == State, R0.Action == Action { ... }
}
```

Key insight: `@ReducerBuilder` uses Swift's Result Builder to combine multiple reducers. The `_Sequence` type merges their effects in **parallel** execution.

### Effect System (`Effect.swift:5-24`)

```swift
public struct Effect<Action>: Sendable {
    enum Operation: Sendable {
        case none                                           // No side effect
        case publisher(AnyPublisher<Action, Never>)         // Combine integration
        case run(name: String?, priority: TaskPriority?,    // async/await
                 operation: @Sendable (Send<Action>) async -> Void)
    }
}
```

Key insight: Effect wraps **all** side effects with three operation types, enabling both legacy Combine and modern async/await patterns.

### Scope Composition (`Scope.swift`)

```swift
var body: some Reducer<State, Action> {
    Scope(state: \.child1, action: \.child1) { Child1() }  // Child first!
    Scope(state: \.child2, action: \.child2) { Child2() }
    Reduce { state, action in /* parent logic */ }          // Parent last
}
```

Key insight: **Child-first ordering** is mandatory. Parent's `Reduce` must come after all `Scope` declarations to prevent action interception.

---

## SourceAtlas Value Demonstration

### Without SourceAtlas (Traditional Approach)
- Read official tutorial: **2-3 hours**
- Understand Store/Reducer relationship: **Research time**
- Discover `RootCore._send()` reentrancy guard: **Easy to miss**
- Map Effect processing flow: **1+ hour**

### With SourceAtlas
- Identified 8 high-entropy files: **3 minutes**
- Understood core architecture: **12 minutes**
- Discovered all 3 core patterns: **From Core.swift + ReducerBuilder.swift**
- **Total: ~15 minutes, 80% understanding**

### Key Swift Patterns Discovered

| Pattern | Location | Purpose |
|---------|----------|---------|
| **Result Builder** | `ReducerBuilder.swift:1-137` | DSL for reducer composition |
| **KeyPath/CasePath** | `Scope.swift` | Type-safe state slicing |
| **Actor Isolation** | `Store.swift` | `@MainActor` for thread safety |
| **Sendable** | `Effect.swift` | Swift Concurrency compliance |
| **Macro** | `@Reducer` | Boilerplate reduction |
| **Protocol Witness** | `Reducer.swift` | Composition via protocol |

---

## Request Flow Trace

```
User Interaction (Button tap)
     │
     ▼
┌─────────────────────────────────────────┐
│ store.send(.buttonTapped)  [View]       │
│                                          │
│ 1. Store receives action                 │
│ 2. Delegates to RootCore                 │
└──────────────────┬──────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│ RootCore._send()        [Core.swift:72] │
│                                          │
│ 1. Check isSending (reentrancy guard)    │
│ 2. Buffer action if already sending      │
│ 3. Process action queue                  │
└──────────────────┬──────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│ Reducer Chain Execution                  │
│ ┌────────────────────┐                  │
│ │ Scope(child1)      │ → Child reducer  │
│ │   KeyPath slicing  │                  │
│ └────────────────────┘                  │
│ ┌────────────────────┐                  │
│ │ Scope(child2)      │ → Child reducer  │
│ └────────────────────┘                  │
│ ┌────────────────────┐                  │
│ │ Reduce { }         │ → Parent logic   │
│ │   return Effect    │                  │
│ └────────────────────┘                  │
└──────────────────┬──────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│ Effect Processing       [Core.swift:101]│
│ ┌────────────────┬───────────┬────────┐ │
│ │ .none          │ .publisher│ .run   │ │
│ │ (no-op)        │ (Combine) │ (async)│ │
│ └────────────────┴─────┬─────┴────┬───┘ │
│                        │          │     │
│               emit action    send(action)│
│                        └─────┬────┘     │
└──────────────────────────────┼──────────┘
                               │
                   ┌───────────┘
                   │ 🔄 Loop back to RootCore._send()
                   ▼
┌─────────────────────────────────────────┐
│ State Updated → View Re-renders         │
│ (SwiftUI observation)                    │
└─────────────────────────────────────────┘
```

---

## Pattern Catalog Applicable

From SourceAtlas pattern library:

| Pattern | Implementation |
|---------|---------------|
| `state-management` | Unidirectional data flow (Redux-like) |
| `reducer` | Pure function: (State, Action) → Effect |
| `middleware` | Effect system with three operation types |
| `dependency-injection` | `@Dependency` property wrapper |
| `testing` | `TestStore` with exhaustive assertion |
| `composition` | Result Builder + Scope for tree structure |

---

## Metrics

| Metric | Value |
|--------|-------|
| Total Files | 819 |
| Files Scanned | 8 |
| Scan Ratio | 0.98% |
| Time Spent | ~15 min |
| Understanding | ~80% |
| LOC Read | ~1,200 |
| Total LOC | ~45,000 |

---

## Conclusion

TCA demonstrates **idiomatic Swift patterns for state management**:

1. **Result Builder** - Declarative reducer composition via `@resultBuilder`
2. **KeyPath/CasePath** - Type-safe state slicing and action routing
3. **RootCore Loop** - Centralized action processing with reentrancy protection
4. **Effect System** - Unified side effect handling (none/publisher/run)
5. **Actor Isolation** - `@MainActor` guarantees thread safety

SourceAtlas identified the **unidirectional data flow architecture** in ~15 minutes by prioritizing:
- `Core.swift` - The RootCore._send() execution loop
- `ReducerBuilder.swift` - Result Builder DSL implementation
- `Effect.swift` - Three-type effect system
- `Scope.swift` - KeyPath-based state composition

The **`RootCore._send()` function** (`Core.swift:72-199`) is the key insight - it's the single point where all actions flow through, handling reentrancy, buffering, and effect processing. Easy to miss if reading files randomly, but immediately visible when tracing `Store.send()`.

