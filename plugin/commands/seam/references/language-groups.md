# Language Groups for Seam Discovery

Three groups based on typing discipline and seam mechanics.
The tool MUST behave differently per group — do NOT apply Group A patterns to Group C languages.

---

## Group A: Nominal Typing

**Languages**: Java, ObjC, Kotlin, Swift, Rust

**Characteristics**:
- Must explicitly declare interface conformance (`implements`, `conforms to`, `impl`)
- Interface file is REQUIRED for substitution
- Legacy Adapter is REQUIRED (old impl can't satisfy new interface without declaration)

**Step 5 behavior**: Generate interface/protocol/trait file (full)
**Step 6 behavior**: Generate Legacy Adapter class + minimal diff on original file
**Enabling point**: Constructor/init parameter injection

**Seam types available**:
- Object Seam (primary) — extract interface, inject via constructor
- Preprocessing Seam (Rust `cfg`, ObjC `#ifdef`) — compile-time substitution

---

## Group B: Structural Typing

**Languages**: Go, TypeScript

**Characteristics**:
- Interface satisfaction is implicit (method set match)
- Interface file is RECOMMENDED but not required
- Legacy Adapter is CONDITIONAL — old impl may already satisfy interface

**Step 5 behavior**: Generate small interfaces (1-2 methods, Pike's principle)
**Step 6 behavior**: Check if old impl already satisfies interface → skip adapter if yes
**Enabling point**: struct field (Go), constructor parameter (TS)

**Seam types available**:
- Object Seam — implicit satisfaction, no `implements` needed
- Module Seam (TS) — `jest.mock('module')` at import level

**Go-specific notes**:
- Prefer 1-method interfaces (io.Reader pattern)
- Package-level `var` is common legacy pattern → enabling point is function parameter, not constructor
- `init()` functions create hidden coupling → flag as seam blocker
- If adapter is needed, interface may be wrong — warn user

**TypeScript-specific notes**:
- Can use both Object Seam (interface + constructor) and Module Seam (jest.mock)
- Module Seam is often easier for existing code — no refactoring needed
- Interface file helps IDE autocomplete and type checking

---

## Group C: Dynamic Typing

**Languages**: JavaScript, Python

**Characteristics**:
- No native interface enforcement at runtime
- "Interface" = the set of messages an object responds to (duck typing)
- Tests define the interface, not a file (Metz's principle)
- Legacy Adapter is UNNECESSARY — mock the module/object directly

**Step 5 behavior**: Output Message Contract (not an interface file)
**Step 6 behavior**: Output mock setup instructions (not an adapter class)
**Enabling point**: Module Seam (import mock) or Monkey-patch Seam

**Seam types available**:
- Module Seam (primary) — `jest.mock('module')`, `unittest.mock.patch('module.Class')`
- Monkey-patch Seam — `setattr()`, prototype override
- Object Seam (optional) — constructor injection works but adds ceremony

**JavaScript-specific notes**:
- `jest.mock('./crypto-module')` is the primary seam — zero code change needed
- JSDoc `@typedef` is optional documentation, not enforced
- CommonJS `require()` vs ESM `import` affects mock strategy

**Python-specific notes**:
- `unittest.mock.patch('module.ClassName.method')` is the primary seam
- `typing.Protocol` (PEP 544) is for type checkers only, not runtime
- ABC (`abc.ABC`) enforces at runtime but is heavy ceremony for testing
- Prefer `mock.patch` over ABC for legacy code seams

---

## Decision Matrix

```
                    Interface file?    Adapter?         Primary Seam
Group A (nominal)   YES (required)     YES (required)   Object Seam
Group B (structural)YES (recommended)  CONDITIONAL      Object Seam
Group C (dynamic)   NO (message contract) NO            Module/Monkey-patch
```

---

## Seam Interface vs Target Interface (Metz's distinction)

ALL groups must label generated abstractions:

- **Seam Interface** (temporary): Reflects current God Class shape. May be ugly.
  Purpose: enable testing. Lifespan: until Step 13 (delete legacy).
- **Target Interface** (permanent): Clean API design for new implementation.
  Purpose: define long-term architecture. Lifespan: permanent.

The tool generates Seam Interfaces. Target Interfaces are a design decision for the user.
