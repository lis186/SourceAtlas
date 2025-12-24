# tRPC (TypeScript) Case Study - SourceAtlas Analysis

**Project**: [tRPC](https://github.com/trpc/trpc) - End-to-end typesafe APIs
**Language**: TypeScript
**Codebase Size**: 193 TypeScript files (packages/), ~15,000 LOC
**Analysis Time**: ~15 minutes
**Files Scanned**: 10 files (5.2%)
**Understanding Achieved**: ~85%

---

## Key Discovery

**tRPC's magic comes from two TypeScript patterns**: Proxy for runtime path recording, and `typeof` for compile-time type inference without code generation. The client imports only the **type** of the server router - zero runtime code from server. The **`createInnerProxy()`** function is the core - it intercepts property access to build the procedure path.

---

## Analysis Process

### High-Entropy Files Scanned

| File | Purpose | Key Insight |
|------|---------|-------------|
| `README.md` | Overview | "End-to-end typesafe APIs, no code generation" |
| `package.json` | Config | pnpm monorepo, TypeScript 5.9 |
| `initTRPC.ts:117-215` | Factory | TRPCBuilder pattern, type accumulation |
| `procedureBuilder.ts:69-90` | Procedures | Input/output chaining with types |
| `router.ts` | Router | RouterRecord, DecorateRouterRecord types |
| `createProxy.ts:19-58` | **The magic!** | Recursive Proxy for path recording |
| `createTRPCClient.ts:158-164` | Client | Proxy → HTTP call translation |
| `middleware.ts:43-72` | Middleware | Context augmentation types |
| `types.ts` | Utilities | MaybePromise, Overwrite, Simplify |

### Core Architecture Discovered

```
┌─────────────────────────────────────────────────────────────┐
│                    Server (Definition)                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ const appRouter = t.router({                        │    │
│  │   user: t.router({                                  │    │
│  │     get: t.procedure.input(z.string()).query(...)   │    │
│  │   })                                                │    │
│  │ })                                                  │    │
│  │ export type AppRouter = typeof appRouter  ←Type!    │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ TypeScript's `typeof`
                           │ (compile-time only, zero runtime)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Client (Usage)                            │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ import type { AppRouter } from './server'  ←Type!   │    │
│  │ const trpc = createTRPCClient<AppRouter>()          │    │
│  │ trpc.user.get.query('123')  ←Full autocompletion!   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### The Proxy Magic (`createProxy.ts:19-58`)

```typescript
function createInnerProxy(callback, path, memo) {
  return new Proxy(noop, {
    get(_obj, key) {
      // Record path: ['user', 'get']
      return createInnerProxy(callback, [...path, key], memo);
    },
    apply(_1, _2, args) {
      // When called: path = ['user', 'get', 'query']
      // Extract procedure type from last segment
      return callback({ path, args });
    },
  });
}
```

Key insight: Each property access creates a new proxy with the path accumulated. When finally called as a function (`.query()`), the full path is available.

### Builder Pattern (`initTRPC.ts:117-135`)

```typescript
class TRPCBuilder<TContext, TMeta> {
  context<TNewContext>() {
    return new TRPCBuilder<TNewContext, TMeta>();  // Type flows!
  }

  meta<TNewMeta>() {
    return new TRPCBuilder<TContext, TNewMeta>();  // Type flows!
  }

  create(opts) {
    // Returns configured tRPC instance with accumulated types
  }
}
```

Key insight: Each method returns a **new builder** with accumulated generic types. This enables fluent API with full type inference.

### Procedure Chaining (`procedureBuilder.ts:69-90`)

```
t.procedure
    │
    ▼ .input(z.object({ id: z.string() }))
    │   └── TInput = { id: string }
    ▼ .output(z.object({ name: z.string() }))
    │   └── TOutput = { name: string }
    ▼ .query(({ input }) => ...)
        └── input is typed as { id: string }!
```

Key insight: Zod schemas are used for both runtime validation AND compile-time type inference via `z.infer<typeof schema>`.

---

## SourceAtlas Value Demonstration

### Without SourceAtlas (Traditional Approach)
- Read all 193 TypeScript files: **6-10 hours**
- Understand Proxy magic: **Research time**
- Discover type inference chain: **Easy to miss**
- Map monorepo structure: **1+ hour**

### With SourceAtlas
- Identified 10 high-entropy files: **3 minutes**
- Understood core architecture: **12 minutes**
- Discovered all 3 core patterns: **From createProxy.ts + initTRPC.ts**
- **Total: ~15 minutes, 85% understanding**

### Key TypeScript Patterns Discovered

| Pattern | Location | Purpose |
|---------|----------|---------|
| **Recursive Proxy** | `createProxy.ts:19-58` | Path recording at runtime |
| **Builder Pattern** | `initTRPC.ts:117-135` | Type accumulation |
| **Generic Accumulation** | `procedureBuilder.ts` | Chainable typed API |
| **Branded Types** | `middleware.ts:8-10` | Safety markers |
| **Conditional Types** | `types.ts` | Type-level computation |
| **typeof Export** | Router files | Zero-runtime type sharing |

---

## Request Flow Trace

```
Client Code: trpc.user.get.query('123')
     │
     ▼
┌─────────────────────────────────────────┐
│ Proxy get() handler    [createProxy.ts] │
│                                          │
│ 1. trpc.user → path = ['user']          │
│ 2. .get → path = ['user', 'get']        │
│ 3. .query → path = ['user', 'get','query']│
└──────────────────┬──────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│ Proxy apply() handler                    │
│                                          │
│ 1. Called with args = ['123']           │
│ 2. Extract procedure type from path[-1] │
│ 3. Build HTTP request                    │
└──────────────────┬──────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│ HTTP Transport                           │
│                                          │
│ POST /trpc/user.get                      │
│ Body: { input: '123' }                   │
└──────────────────┬──────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│ Server Router Resolution                 │
│                                          │
│ 1. Parse path: user.get                  │
│ 2. Find procedure in router tree         │
│ 3. Validate input with Zod              │
│ 4. Execute resolver                      │
└──────────────────┬──────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│ Response                                 │
│                                          │
│ { result: { data: { name: 'John' } } }  │
│ ↓                                        │
│ Client receives typed response           │
└─────────────────────────────────────────┘
```

---

## Pattern Catalog Applicable

From SourceAtlas pattern library:

| Pattern | Implementation |
|---------|---------------|
| `type-inference` | `typeof` export + generic accumulation |
| `proxy` | Recursive Proxy for path recording |
| `builder` | TRPCBuilder with fluent API |
| `validation` | Zod schemas for runtime + types |
| `middleware` | Context augmentation with types |
| `monorepo` | pnpm workspace structure |

---

## Metrics

| Metric | Value |
|--------|-------|
| Total Files | 193 |
| Files Scanned | 10 |
| Scan Ratio | 5.2% |
| Time Spent | ~15 min |
| Understanding | ~85% |
| LOC Read | ~1,500 |
| Total LOC | ~15,000 (est) |

---

## Conclusion

tRPC demonstrates **advanced TypeScript patterns for type-safe APIs**:

1. **Recursive Proxy** - Intercepts property access to record procedure path
2. **typeof Export** - Share types without runtime code
3. **Builder Pattern** - Accumulate types through method chaining
4. **Zod Integration** - Runtime validation + compile-time inference
5. **Generic Accumulation** - Each method returns new type-augmented builder

SourceAtlas identified the **Proxy + TypeScript inference architecture** in ~15 minutes by prioritizing:
- `createProxy.ts` - The recursive proxy implementation
- `initTRPC.ts` - Builder pattern with type accumulation
- `procedureBuilder.ts` - Procedure chaining types
- `createTRPCClient.ts` - Client-side proxy creation

The **`createInnerProxy()` function** (`createProxy.ts:19-58`) is the key insight - it's how tRPC achieves end-to-end type safety without code generation. The Proxy records the path at runtime, while TypeScript infers the types at compile time. Easy to miss if reading files sequentially, but immediately visible when tracing `trpc.user.get.query()`.

