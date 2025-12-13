# ast-grep Rules for SourceAtlas

Pre-defined YAML rules for ast-grep integration.

## Directory Structure

```
ast-grep-rules/
├── swift/
│   ├── async-function.yaml      # async func declarations
│   └── availability-condition.yaml  # #available checks
├── typescript/
│   ├── custom-hook.yaml         # use* hook definitions
│   └── use-client.yaml          # 'use client' directive
└── kotlin/
    ├── suspend-function.yaml    # suspend fun declarations
    └── data-class.yaml          # data class declarations
```

## Usage

### Direct ast-grep

```bash
ast-grep scan --rule swift/async-function.yaml --json .
```

### Via ast-grep-search.sh

```bash
# The unified script uses these rules internally
./ast-grep-search.sh pattern "async" --lang swift
```

## Adding New Rules

1. Create a `.yaml` file in the appropriate language directory
2. Follow the naming convention: `<pattern-name>.yaml`
3. Include id, language, and rule sections
4. Test with: `ast-grep scan --rule <file> --json .`

## Rule Template

```yaml
# Description of what this rule matches
# Usage: ast-grep scan --rule <file>
id: <unique-id>
language: <Swift|Tsx|Kotlin|Python>
rule:
  kind: <ast-node-kind>
  has:
    pattern: <pattern>
    # or
    kind: <child-kind>
    regex: "<regex>"
```

## References

- [ast-grep Rule Reference](https://ast-grep.github.io/reference/rule.html)
- [ast-grep Playground](https://ast-grep.github.io/playground.html)
