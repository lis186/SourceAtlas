# Seam Types Reference

Based on Michael Feathers' *Working Effectively with Legacy Code* — adapted per language.

## Seam Definition

A **seam** is a place where you can alter behavior in your program without editing in that place. Every seam has an **enabling point** — the place where you decide which behavior to use.

---

## Object Seam (Highest Leverage)

Replace behavior by substituting a different object at runtime.

| Language | Signal | Enabling Point |
|----------|--------|----------------|
| ObjC | Protocol conformance (`id<Protocol>`), delegate property, block parameter | Initializer or setter |
| Swift | Protocol conformance, closure parameter, dependency injection | Init or property |
| TypeScript | Interface parameter, callback/Promise, dependency injection | Constructor or factory |
| JavaScript | Callback parameter, dependency injection via module | Import or constructor |
| Go | Interface parameter | Function argument or struct field |
| Java | Interface parameter, abstract class | Constructor injection |
| Kotlin | Interface parameter, lambda | Constructor injection |
| Python | Duck typing (any parameter), dependency injection | Constructor or function arg |
| Rust | Trait bound (`impl Trait` or `dyn Trait`), closure | Generic parameter or Box |

**Refactoring pattern**: Extract Interface/Protocol → Inject via constructor → Test with mock.

---

## Link Seam (Medium Leverage, Higher Risk)

Replace behavior by changing what gets linked/loaded at compile or load time.

| Language | Signal | Enabling Point |
|----------|--------|----------------|
| ObjC | Category method (same selector = UB!), `method_exchangeImplementations` (swizzle) | Link order, runtime |
| Swift | Extension method (no override), `@objc` dynamic dispatch | Module import |
| TypeScript | Module re-export, barrel file | Import path |
| JavaScript | Module mock (`jest.mock`), monkey-patching | Import/require |
| Go | Build tags (`//go:build`), interface satisfaction at link time | Build flags |
| Java | Classpath ordering, ServiceLoader | Build config |
| Kotlin | Companion object factory, extension function | Import |
| Python | Module-level monkey-patching, `unittest.mock.patch` | Import time |
| Rust | Feature flags in Cargo.toml, conditional compilation | `cfg` attributes |

**Warning**: Link seams in ObjC (categories with same selector) are Undefined Behavior. Use Object Seams instead.

---

## Module Seam (Group C Primary, Group B Secondary)

Replace behavior by substituting what an `import`/`require` resolves to. No code change needed — the seam is at the module boundary.

| Language | Signal | Enabling Point |
|----------|--------|----------------|
| JavaScript | `require('module')`, `import x from 'module'` | `jest.mock('module')`, `proxyquire` |
| TypeScript | `import { x } from 'module'` | `jest.mock('module')`, import alias |
| Python | `import module`, `from module import Class` | `unittest.mock.patch('module.Class')` |
| Go | N/A (no module-level mock in std) | Build tags or interface |
| ObjC | N/A | — |
| Swift | N/A | — |
| Java | N/A (use DI framework) | — |
| Kotlin | N/A (use DI framework) | — |
| Rust | N/A (use trait) | — |

**Key insight**: Module Seam requires ZERO changes to production code. The test framework intercepts the import. This is why Group C languages (JS, Python) rarely need explicit interface extraction — the import IS the seam.

**Refactoring pattern**: Identify external dependency → mock at import level → write characterization test → done.

---

## Monkey-patch Seam (Group C Only, High Risk)

Replace behavior by directly overwriting an object's method at runtime.

| Language | Signal | Enabling Point |
|----------|--------|----------------|
| Python | Any method call | `unittest.mock.patch.object(obj, 'method')`, `setattr` |
| JavaScript | Any method call on object/prototype | `obj.method = fakeFn`, `jest.spyOn(obj, 'method')` |
| Ruby | Any method call | `allow(obj).to receive(:method)` |
| Go | N/A (no runtime method replacement) | — |
| ObjC | Method swizzling (`method_exchangeImplementations`) | Runtime — **dangerous, avoid** |
| Swift | N/A (static dispatch) | — |
| Java | N/A (reflection possible but fragile) | — |
| Kotlin | N/A | — |
| Rust | N/A (no runtime dispatch override) | — |

**Warning**: Monkey-patching is powerful but brittle. Use Module Seam first if available. Monkey-patch only when the dependency is deeply nested and not importable.

---

## Preprocessing Seam (Lowest Leverage)

Replace behavior via preprocessor directives — compile-time only, cannot vary at runtime.

| Language | Signal | Enabling Point |
|----------|--------|----------------|
| ObjC | `#ifdef`, `#if`, `#ifndef` | Compiler flags (-D) |
| Swift | `#if DEBUG`, `#if canImport()` | Build configuration |
| TypeScript | N/A (use bundler defines) | Webpack/Vite define |
| JavaScript | `process.env.NODE_ENV` checks | Environment variable |
| Go | Build tags (`//go:build`) | `go build -tags` |
| Java | N/A (no preprocessor) | — |
| Kotlin | N/A (no preprocessor) | — |
| Python | N/A (no preprocessor) | — |
| Rust | `#[cfg()]`, `cfg!()` | `--cfg` flags |

**Limitation**: Only useful for debug/release switching. Cannot substitute for testing.

---

## Detection Heuristics

When analyzing a zone's `sends` list from clang AST:

1. **If zone sends to 1-2 external classes** → Likely a clean Object Seam candidate (extract protocol for those classes)
2. **If zone sends to 5+ external classes** → Feature Envy smell; needs decomposition before seam extraction
3. **If zone has `#ifdef` guards** → Preprocessing Seam exists but low value
4. **If zone uses categories on same class** → Link Seam exists but dangerous (ObjC UB risk)
5. **If zone accepts block/closure/callback parameters** → Object Seam already partially exists
