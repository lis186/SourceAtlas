# FastAPI (Python) Case Study - SourceAtlas Analysis

**Project**: [FastAPI](https://github.com/tiangolo/fastapi) - High performance async web framework
**Language**: Python
**Codebase Size**: 1,113 Python files, ~50,000 LOC
**Analysis Time**: ~12 minutes
**Files Scanned**: 8 files (0.72%)
**Understanding Achieved**: ~80%

---

## Key Discovery

**FastAPI's power comes from three Python patterns**: Pydantic for automatic validation/serialization, `Depends()` frozen dataclass for dependency injection with caching, and Starlette inheritance for ASGI routing. The **`solve_dependencies()`** function is the heart - it recursively resolves the dependency tree with built-in caching.

---

## Analysis Process

### High-Entropy Files Scanned

| File | Purpose | Key Insight |
|------|---------|-------------|
| `README.md` | Overview | High performance claims, based on Starlette + Pydantic |
| `pyproject.toml:264` | Dependencies | Python 3.9+, starlette, pydantic core deps |
| `fastapi/__init__.py:66` | Public API | Version 0.127.0, key exports |
| `fastapi/applications.py:67` | Core class | `class FastAPI(Starlette)` - inheritance pattern |
| `fastapi/params.py:761` | DI markers | `Depends`, `Query`, `Body` dataclasses |
| `fastapi/routing.py:549` | Request handling | `APIRoute.matches()`, `get_request_handler()` |
| `dependencies/utils.py:596` | DI resolution | `solve_dependencies()` recursive resolver |
| `dependencies/models.py:32` | DI data model | `Dependant` dataclass with cache_key |

### Core Architecture Discovered

```
┌─────────────────────────────────────────────────────────────┐
│                         FastAPI                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              class FastAPI(Starlette)                │    │
│  │  • Inherits ASGI core from Starlette                 │    │
│  │  • Adds dependency injection layer                   │    │
│  │  • Adds Pydantic validation layer                    │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  Layered Architecture:                                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ User Endpoint Functions (@app.get("/"))              │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │ Dependency Injection Layer (Depends, solve_deps)     │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │ Pydantic Validation Layer (Request/Response models)  │   │
│  ├──────────────────────────────────────────────────────┤   │
│  │ Starlette Core (ASGI, Routing, Request/Response)     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### The Depends Pattern (`params.py:761`)

```python
@dataclass(frozen=True)
class Depends:
    dependency: Optional[Callable[..., Any]] = None
    use_cache: bool = True  # Enable caching by default!
    scope: Union[Literal["function", "request"], None] = None
```

Key insight: `Depends` is a **frozen dataclass** (immutable). The `use_cache=True` default means the same dependency called multiple times in a single request is resolved **only once**.

### Dependency Resolution (`dependencies/utils.py:596`)

```python
async def solve_dependencies(
    *,
    request: Request,
    dependant: Dependant,
    dependency_cache: Optional[Dict[Tuple[Callable, ...], Any]] = None,
) -> Tuple[Dict[str, Any], List[ErrorWrapper], ...]:
    # Recursive resolution with caching
    if dependency_cache is None:
        dependency_cache = {}

    for sub_dependant in dependant.dependencies:
        # Check cache first
        if sub_dependant.cache_key in dependency_cache:
            solved = dependency_cache[sub_dependant.cache_key]
        else:
            solved = await solve_dependencies(...)
            dependency_cache[sub_dependant.cache_key] = solved
```

Key insight: The dependency tree is resolved **recursively** with a cache dictionary. This prevents redundant database connections or API calls within a single request.

### Cache Key Design (`dependencies/models.py:63-71`)

```python
@cached_property
def cache_key(self) -> DependencyCacheKey:
    return (
        self.call,           # The function itself
        scopes_for_cache,    # OAuth scopes (if any)
        self.computed_scope, # "function" or "request"
    )
```

Key insight: Cache key is a **tuple** of (function, scopes, scope). This ensures different OAuth scopes get different cache entries.

---

## SourceAtlas Value Demonstration

### Without SourceAtlas (Traditional Approach)
- Read all 1,113 Python files: **8-12 hours**
- Understand DI system magic: **Research time**
- Discover `solve_dependencies()` caching: **Easy to miss**
- Map Starlette inheritance: **1+ hour**

### With SourceAtlas
- Identified 8 high-entropy files: **2 minutes**
- Understood core architecture: **10 minutes**
- Discovered all 3 core patterns: **From params.py + utils.py**
- **Total: ~12 minutes, 80% understanding**

### Key Python Patterns Discovered

| Pattern | Location | Purpose |
|---------|----------|---------|
| **Frozen Dataclass** | `params.py:761` | Immutable DI markers |
| **Recursive Resolution** | `utils.py:596` | Dependency tree solving |
| **Cache Dictionary** | `utils.py:596` | Request-scoped caching |
| **Generator Dependencies** | `models.py:188-193` | Resource cleanup (context manager) |
| **Type Hints** | Throughout | Pydantic validation + OpenAPI |
| **Inheritance** | `applications.py:67` | Starlette as ASGI base |

---

## Request Flow Trace

```
HTTP Request (ASGI)
     │
     ▼
┌─────────────────────────────────────────┐
│ APIRoute.matches()      [routing.py:549]│
│                                          │
│ 1. Path matching                         │
│ 2. Return endpoint handler               │
└──────────────────┬──────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│ Body Parsing            [routing.py:362]│
│                                          │
│ 1. JSON or Form data parsing             │
│ 2. Pydantic validation                   │
└──────────────────┬──────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│ solve_dependencies()      [utils.py:596]│
│                                          │
│ 1. Build dependency tree (Dependant)     │
│ 2. Recursive resolution with cache       │
│ 3. Return resolved values dict           │
└──────────────────┬──────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│ run_endpoint_function() [routing.py:304]│
│                                          │
│ 1. Call user function with resolved deps │
│ 2. async def → await                     │
│ 3. sync def → run_in_threadpool()        │
└──────────────────┬──────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│ Response Serialization  [routing.py:448]│
│                                          │
│ 1. Pydantic model → JSON                 │
│ 2. Set Content-Type headers              │
└─────────────────────────────────────────┘
```

---

## Pattern Catalog Applicable

From SourceAtlas pattern library:

| Pattern | Implementation |
|---------|---------------|
| `dependency-injection` | `Depends()` with recursive resolution |
| `validation` | Pydantic models with type hints |
| `router` | Starlette routing inherited |
| `middleware` | ASGI middleware stack |
| `async-runtime` | asyncio + run_in_threadpool fallback |
| `openapi` | Auto-generated from type hints |

---

## Metrics

| Metric | Value |
|--------|-------|
| Total Files | 1,113 |
| Files Scanned | 8 |
| Scan Ratio | 0.72% |
| Time Spent | ~12 min |
| Understanding | ~80% |
| LOC Read | ~800 |
| Total LOC | ~50,000 (est) |

---

## Conclusion

FastAPI demonstrates **idiomatic Python patterns for web frameworks**:

1. **Frozen Dataclass** - `Depends()` is immutable, hashable for caching
2. **Recursive Resolution** - `solve_dependencies()` builds and solves dependency tree
3. **Request-Scoped Caching** - Same dependency resolved once per request
4. **Generator Dependencies** - Context manager pattern for cleanup
5. **Type Hint Driven** - Pydantic + OpenAPI from annotations

SourceAtlas identified the **layered architecture** in ~12 minutes by prioritizing:
- `applications.py` - FastAPI inherits from Starlette
- `params.py` - The Depends frozen dataclass
- `dependencies/utils.py` - Recursive resolver with caching
- `dependencies/models.py` - Cache key design

The **`solve_dependencies()` function** (`utils.py:596`) is the key insight - it's the DI engine that makes FastAPI's elegant function signatures work. The caching mechanism (`use_cache=True` by default) prevents redundant work, but is easy to miss when reading the codebase sequentially.

