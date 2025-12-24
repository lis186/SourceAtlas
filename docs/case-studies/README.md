# SourceAtlas Case Studies

Real-world analysis of popular open-source frameworks demonstrating SourceAtlas's ability to achieve 70-95% codebase understanding by scanning <5% of files.

## Results Summary

| Language | Framework | Files | Scanned | Ratio | Time | Understanding | Key Pattern |
|----------|-----------|-------|---------|-------|------|---------------|-------------|
| Go | [Gin](https://github.com/gin-gonic/gin) | 56 | 8 | 14.3% | ~10 min | ~90% | sync.Pool + radix tree |
| Swift | [TCA](https://github.com/pointfreeco/swift-composable-architecture) | 819 | 8 | ~1% | ~15 min | ~80% | Result Builder + RootCore |
| Python | [FastAPI](https://github.com/tiangolo/fastapi) | 1,113 | 8 | 0.72% | ~12 min | ~80% | Depends() + solve_dependencies |
| TypeScript | [tRPC](https://github.com/trpc/trpc) | 193 | 10 | 5.2% | ~15 min | ~85% | Recursive Proxy + typeof |
| Kotlin | [Circuit](https://github.com/slackhq/circuit) | 450 | 8 | 1.8% | ~12 min | ~85% | Presenter/UI + Compose Runtime |
| Ruby | [Sinatra](https://github.com/sinatra/sinatra) | 7 | 4 | 57%* | ~12 min | ~90% | Delegator + dup.call! |
| Rust | [Axum](https://github.com/tokio-rs/axum) | 117 | 4 | 3.4% | ~15 min | ~90% | Tower Service + FromRequest |

\* Sinatra's lib/ is only 7 files, so scan ratio appears high but still follows high-entropy prioritization.

---

## Complete Example: Gin (Go)

This section shows exactly what SourceAtlas produces when analyzing a codebase.

### Key Discovery

**Gin's performance comes from three Go patterns**: sync.Pool for Context reuse, radix tree for O(log n) routing, and handler chain for middleware composition. The Context is the **central abstraction** - it's pooled, passed through the handler chain, and provides all request/response operations.

### High-Entropy Files Scanned

| File | Purpose | Key Insight |
|------|---------|-------------|
| `README.md:1-100` | Overview | 40x faster than Martini, zero-allocation router |
| `gin.go:92-189` | Engine struct | Embeds RouterGroup, uses sync.Pool for Context |
| `gin.go:662-675` | ServeHTTP | Context pooling: Get → handle → Put |
| `context.go:58-96` | Context struct | Request, Writer, Params, handlers chain |
| `routergroup.go:53-91` | RouterGroup | Middleware composition via combineHandlers |
| `tree.go:45-100` | Radix tree | From httprouter, O(log n) route matching |
| `recovery.go:34-80` | Middleware | defer/recover pattern for panic handling |
| `binding/binding.go:28-89` | Binding | Interface-based request binding with validation |

### Core Architecture Discovered

```
┌─────────────────────────────────────────────────────────────┐
│                         Engine                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    RouterGroup                      │    │
│  │  basePath: "/"                                      │    │
│  │  Handlers: [Logger, Recovery]  (middleware chain)   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  trees: methodTrees         pool: sync.Pool                 │
│  ┌──────────────────┐       ┌──────────────────┐            │
│  │ GET  → radix tree│       │ Context objects  │            │
│  │ POST → radix tree│       │ (reused per req) │            │
│  │ PUT  → radix tree│       └──────────────────┘            │
│  └──────────────────┘                                       │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼ ServeHTTP(w, req)
┌─────────────────────────────────────────────────────────────┐
│  1. c := pool.Get().(*Context)    // Get from pool          │
│  2. c.reset()                      // Clear previous state  │
│  3. c.Request = req                // Set request           │
│  4. engine.handleHTTPRequest(c)    // Route + execute       │
│  5. pool.Put(c)                    // Return to pool        │
└─────────────────────────────────────────────────────────────┘
```

### The Context Pattern (`context.go:58-96`)

```go
type Context struct {
    writermem responseWriter
    Request   *http.Request
    Writer    ResponseWriter

    Params   Params           // URL parameters
    handlers HandlersChain    // Middleware + handler chain
    index    int8             // Current position in chain
    fullPath string

    engine   *Engine
    Keys     map[any]any      // Request-scoped storage
    Errors   errorMsgs        // Error accumulator
}
```

Context is **pooled and reused** (`gin.go:229-231`):

```go
engine.pool.New = func() any {
    return engine.allocateContext(engine.maxParams)
}
```

### Handler Chain & Next() Pattern

```go
func (engine *Engine) handleHTTPRequest(c *Context) {
    // Find route in radix tree
    root := engine.trees.get(httpMethod)
    value := root.getValue(rPath, c.params, c.skippedNodes, unescape)

    if value.handlers != nil {
        c.handlers = value.handlers  // [Logger, Recovery, YourHandler]
        c.Next()                      // Start chain execution
    }
}
```

The `Next()` pattern allows middleware to wrap handler execution:

```go
func (c *Context) Next() {
    c.index++
    for c.index < int8(len(c.handlers)) {
        c.handlers[c.index](c)
        c.index++
    }
}
```

### Request Flow Trace

```
HTTP Request
     │
     ▼
┌─────────────────────────────────────────┐
│ ServeHTTP(w, req)         [gin.go:662]  │
│ ┌─────────────────────────────────────┐ │
│ │ c := pool.Get().(*Context)          │ │
│ │ c.reset()                           │ │
│ │ c.Request = req                     │ │
│ └─────────────────────────────────────┘ │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│ handleHTTPRequest(c)      [gin.go:690]  │
│ ┌─────────────────────────────────────┐ │
│ │ tree := trees.get(method)           │ │
│ │ value := tree.root.getValue(path)   │ │
│ │ c.handlers = value.handlers         │ │
│ │ c.Next()                            │ │
│ └─────────────────────────────────────┘ │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│ Handler Chain Execution                 │
│ ┌────────────────────┐                  │
│ │ Logger()           │ → logs request   │
│ │   c.Next()         │                  │
│ └────────────────────┘                  │
│ ┌────────────────────┐                  │
│ │ Recovery()         │ → defer/recover  │
│ │   c.Next()         │                  │
│ └────────────────────┘                  │
│ ┌────────────────────┐                  │
│ │ YourHandler()      │ → business logic │
│ │   c.JSON(200, ...) │                  │
│ └────────────────────┘                  │
└────────────────┬────────────────────────┘
                 ▼
┌─────────────────────────────────────────┐
│ pool.Put(c)               [gin.go:674]  │
│ (Context returned to pool for reuse)    │
└─────────────────────────────────────────┘
```

### Key Go Patterns Discovered

| Pattern | Location | Purpose |
|---------|----------|---------|
| **sync.Pool** | `gin.go:183,229-231,667,674` | Context reuse, zero allocation |
| **Handler Chain** | `routergroup.go:241-248` | Middleware composition |
| **Interface-based Design** | `binding/binding.go:28-34` | Extensible binding system |
| **defer/recover** | `recovery.go:58-60` | Panic-safe middleware |
| **Radix Tree** | `tree.go` | O(log n) routing |

### Metrics

| Metric | Value |
|--------|-------|
| Total Files | 56 |
| Files Scanned | 8 |
| Scan Ratio | 14.3% |
| Time Spent | ~10 min |
| Understanding | ~90% |
| LOC Read | ~800 |
| Total LOC | ~8,000 (est) |

---

## Methodology

Each case study follows the SourceAtlas methodology:

1. **Start with README/docs** - Highest entropy, project overview
2. **Read config files** - Tech stack decisions in one place
3. **Find entry points** - lib.rs, main.go, base.rb, etc.
4. **Trace core abstractions** - 2-3 key files that define the architecture
5. **Skip implementation details** - Tests, examples, utilities

## Other Case Studies

Detailed analyses available in [raw/](./raw/):

- **Swift/TCA**: Result Builder + RootCore execution loop
- **Python/FastAPI**: Depends() frozen dataclass + recursive resolution
- **TypeScript/tRPC**: Recursive Proxy + typeof export
- **Kotlin/Circuit**: Presenter/UI separation + Compose Runtime
- **Ruby/Sinatra**: Delegator + dup.call! per-request isolation
- **Rust/Axum**: Tower Service + FromRequest trait + macro implementations
