# Proposal: YAML-based Pattern Configuration

**Status**: Draft
**Version**: 1.0
**Author**: Claude & Justin
**Created**: 2025-11-30
**Target Version**: v2.6

---

## Problem Statement

### Current Pain Points

1. **Hard-coded patterns**: All 141 patterns are embedded in `find-patterns.sh` as 500+ lines of case statements
2. **Difficult to extend**: Adding a new language requires editing shell script internals
3. **No user customization**: Users cannot add project-specific patterns without forking
4. **Maintenance burden**: Each language update requires careful shell scripting
5. **No discoverability**: Users can't easily see all available patterns

### User Stories

> "I want to add a custom pattern for our company's internal framework"

> "I'm working on a Rust project and want to contribute Rust patterns"

> "I want to see what patterns are available for my project type"

---

## Proposed Solution

### YAML-based Pattern Configuration

Replace hard-coded shell patterns with external YAML configuration files.

```
scripts/atlas/patterns/
├── languages/
│   ├── ios.yaml           # iOS/Swift (34 patterns)
│   ├── typescript.yaml    # TypeScript/React/Vue (50 patterns)
│   ├── kotlin.yaml        # Android/Kotlin (31 patterns)
│   └── python.yaml        # Python (26 patterns)
├── schema.yaml            # Pattern schema definition
└── _custom.yaml           # User custom patterns (git ignored)
```

### Global User Patterns

```
~/.sourceatlas/
└── patterns/
    ├── my-company.yaml    # Company-specific patterns
    └── rust.yaml          # Personal Rust patterns
```

---

## YAML Schema Design

### Language Definition (`ios.yaml`)

```yaml
# SourceAtlas Pattern Definition
# Language: iOS/Swift
# Version: 2.5.4
# Patterns: 34

language:
  name: ios
  display_name: "iOS/Swift"
  aliases: [swift, xcode, apple]

detection:
  # Files that indicate this project type
  marker_files:
    - "*.xcodeproj"
    - "*.xcworkspace"
    - Package.swift
  # Priority when multiple languages detected (higher = preferred)
  priority: 100

file_extensions:
  - .swift
  - .m
  - .h

patterns:
  # ==== TIER 1: Core Patterns ====

  - name: viewmodel
    tier: 1
    aliases: [mvvm, vm]
    description: "MVVM ViewModel pattern for UI state management"
    files:
      - "*ViewModel.swift"
      - "*VM.swift"
    directories:
      - ViewModels
      - ViewModel
      - Presentation
    examples:
      - "UserProfileViewModel.swift"
      - "LoginVM.swift"
    related_patterns:
      - view
      - coordinator

  - name: coordinator
    tier: 1
    aliases: [navigation, flow]
    description: "Coordinator pattern for navigation flow"
    files:
      - "*Coordinator.swift"
      - "*Flow.swift"
    directories:
      - Coordinators
      - Navigation
      - Flows
    examples:
      - "AppCoordinator.swift"
      - "AuthFlow.swift"

  - name: repository
    tier: 1
    aliases: [repo, data-access]
    description: "Repository pattern for data abstraction"
    files:
      - "*Repository.swift"
      - "*Repo.swift"
    directories:
      - Repositories
      - Repository
      - Data
    objc_support: true  # Also search .m/.h files

  # ==== TIER 2: Supplementary Patterns ====

  - name: mock
    tier: 2
    aliases: [stub, fake, test-double]
    description: "Test doubles for unit testing"
    files:
      - "Mock*.swift"
      - "*Mock.swift"
      - "Stub*.swift"
      - "Fake*.swift"
    directories:
      - Mocks
      - Stubs
      - TestDoubles
    test_only: true  # Only search in test directories
```

### TypeScript/React/Vue Example (`typescript.yaml`)

```yaml
language:
  name: typescript
  display_name: "TypeScript/React/Vue"
  aliases: [ts, react, vue, nextjs, nuxt]

detection:
  marker_files:
    - package.json
    - tsconfig.json
  marker_content:
    # Check package.json for framework indicators
    package.json:
      dependencies:
        - react
        - vue
        - next
        - nuxt
  priority: 50

file_extensions:
  - .ts
  - .tsx
  - .vue
  - .js
  - .jsx

patterns:
  # React Patterns
  - name: react hook
    tier: 1
    aliases: [hook, hooks, custom-hook]
    framework: react
    files:
      - "use*.ts"
      - "use*.tsx"
      - "*.hook.ts"
    directories:
      - hooks
      - composables
      - utils/hooks

  - name: zustand store
    tier: 1
    aliases: [zustand, store]
    framework: react
    files:
      - "*Store.ts"
      - "*store.ts"
      - "use*Store.ts"
    directories:
      - stores
      - state
      - store
    dependencies:
      - zustand

  # Vue Patterns
  - name: vue composable
    tier: 1
    aliases: [composable]
    framework: vue
    files:
      - "use*.ts"
      - "*.composable.ts"
    directories:
      - composables
      - hooks

  - name: pinia store
    tier: 1
    aliases: [pinia, vue-store]
    framework: vue
    files:
      - "*Store.ts"
      - "use*Store.ts"
    directories:
      - stores
      - store
    dependencies:
      - pinia
```

### Custom Pattern Example (`_custom.yaml`)

```yaml
# User Custom Patterns
# This file is git-ignored and won't be overwritten on updates

custom_patterns:
  - language: typescript
    patterns:
      - name: acme-component
        tier: 1
        aliases: [acme]
        description: "ACME Corp internal component pattern"
        files:
          - "Acme*.tsx"
          - "*Acme.tsx"
        directories:
          - acme-components

  - language: ios
    patterns:
      - name: our-analytics
        tier: 2
        description: "Internal analytics wrapper"
        files:
          - "*Analytics.swift"
          - "*Tracker.swift"
```

---

## Implementation Plan

### Phase 1: Schema & Migration (Week 1)

1. **Define YAML schema** (`schema.yaml`)
2. **Create language files** by extracting from `find-patterns.sh`
3. **Write migration script** to convert existing patterns
4. **Validate with existing tests**

### Phase 2: Parser Implementation (Week 2)

1. **Add `yq` dependency check** with fallback instructions
2. **Create `parse-patterns.sh`** to load YAML configs
3. **Modify `find-patterns.sh`** to use parsed patterns
4. **Maintain backward compatibility** (fallback to embedded if no YAML)

### Phase 3: User Customization (Week 3)

1. **Support `_custom.yaml`** in project directory
2. **Support `~/.sourceatlas/patterns/`** for global patterns
3. **Add pattern merge logic** (custom overrides default)
4. **Document customization workflow**

### Phase 4: Discovery & Tooling (Week 4)

1. **`/atlas.pattern --list`**: Show all available patterns
2. **`/atlas.pattern --add`**: Interactive pattern creation
3. **`/atlas.pattern --validate`**: Validate custom patterns
4. **Update documentation**

---

## Technical Considerations

### yq Dependency

```bash
# Check for yq
if command -v yq &> /dev/null; then
    # Use yq for YAML parsing
    patterns=$(yq '.patterns[] | select(.name == "'$pattern'")' "$yaml_file")
else
    # Fallback to embedded patterns
    echo "Warning: yq not found, using embedded patterns"
    use_embedded_patterns
fi
```

**Installation**:
```bash
# macOS
brew install yq

# Linux
sudo apt-get install yq
# or
pip install yq
```

### Performance

| Operation | Current | With YAML |
|-----------|---------|-----------|
| First load | N/A | ~100ms (parse YAML) |
| Pattern lookup | O(1) case | O(1) cached |
| Memory | ~50KB | ~200KB |

**Mitigation**: Cache parsed patterns in memory during session.

### Backward Compatibility

1. **Fallback mechanism**: If YAML files missing, use embedded patterns
2. **Version flag**: `find-patterns.sh --use-embedded` forces old behavior
3. **Gradual migration**: Both modes work during transition period

---

## File Structure After Implementation

```
scripts/atlas/
├── find-patterns.sh          # Main script (reads YAML)
├── parse-patterns.sh         # YAML parser utilities
├── patterns/
│   ├── schema.yaml           # Schema definition
│   ├── languages/
│   │   ├── ios.yaml          # 34 patterns
│   │   ├── typescript.yaml   # 50 patterns
│   │   ├── kotlin.yaml       # 31 patterns
│   │   └── python.yaml       # 26 patterns
│   └── _custom.yaml          # Git ignored
└── detect-project.sh         # Project type detection

~/.sourceatlas/               # User global config
├── config.yaml               # User preferences
└── patterns/
    └── *.yaml                # User patterns
```

---

## Benefits

### For Users

1. **Easy customization**: Edit YAML instead of shell scripts
2. **Pattern discovery**: `--list` shows all available patterns
3. **Project-specific patterns**: Add patterns for internal frameworks
4. **Contributing patterns**: Submit YAML files instead of shell code

### For Maintainers

1. **Cleaner codebase**: Separate data from logic
2. **Easier testing**: Test YAML files independently
3. **Better documentation**: YAML is self-documenting
4. **Community contributions**: Lower barrier for new patterns

### For the Project

1. **Scalability**: Add new languages without code changes
2. **Consistency**: Standard format across all languages
3. **Extensibility**: Future features (pattern scoring, examples) easy to add

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| yq not installed | Fallback to embedded patterns |
| YAML parse errors | Validation script + clear error messages |
| Performance regression | Caching + lazy loading |
| Breaking changes | Version flag + gradual migration |

---

## Success Metrics

1. **User adoption**: 50%+ users customize patterns within 3 months
2. **Community contributions**: 5+ community-submitted language files
3. **Maintenance reduction**: 50% less time updating patterns
4. **Bug reduction**: Fewer pattern-related bug reports

---

## Open Questions

1. **yq version**: Use `yq` (Go version) or `yq` (Python version)?
   - Recommendation: Go version (`mikefarah/yq`) for speed

2. **Pattern inheritance**: Should patterns inherit from base definitions?
   - Recommendation: Start simple, add if needed

3. **Hot reload**: Should patterns reload without restart?
   - Recommendation: No, keep simple for v1

---

## Next Steps

1. [ ] Review and approve this proposal
2. [ ] Create `schema.yaml` with validation rules
3. [ ] Migrate iOS patterns as proof of concept
4. [ ] Implement parser and test
5. [ ] Roll out to all languages

---

**Decision Needed**: Approve, modify, or defer this proposal?
