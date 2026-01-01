---
description: Guidelines for managing dev-notes/ directory structure and content
---

# dev-notes/ Management Guide

## File Naming Rules

### UPPER_CASE.md (max 5 files)
Only for files that meet ALL criteria:
1. Updated weekly
2. Index/navigation purpose
3. Long-term methodology

Current: README.md, HISTORY.md, KEY_LEARNINGS.md, ROADMAP.md, METHODOLOGY.md
**Never create new uppercase files without explicit approval.**

### YYYY-MM-DD-topic-type.md
For everything else:
- `topic`: hyphen-separated (e.g., `objective-c-support`)
- `type`: implementation | analysis | decision | test | experiment

## Location Rules

```
if current/last month → dev-notes/YYYY-MM/
elif decision analysis → dev-notes/archives/decisions/
elif methodology deep-dive → dev-notes/archives/lessons/
else → dev-notes/YYYY-MM/ (matching month)
```

## Must-Follow Rules

1. **Never create new UPPER_CASE files**
2. **Always use date prefix for new content**
3. **Update HISTORY.md immediately after major features**
4. **Merge same-day + same-topic content**
5. **Move 3+ month old content to archives/**

## Update Templates

### HISTORY.md
```markdown
### Week N (MM/DD-MM/DD): Topic
- **Feature** (MM/DD): One-line description → [Details](link)
```

### KEY_LEARNINGS.md
```markdown
### N. Learning Title
**Discovery**: 1 sentence
**Evidence**: 1 sentence
**Application**: 1 sentence
→ [Full analysis](link)
```

## Information Layers

- **Layer 0** (README.md): 10-sec overview
- **Layer 1** (5 core files): 5-min understanding
- **Layer 2** (monthly folders): 30-min details
- **Layer 3** (archives/): Deep dive
