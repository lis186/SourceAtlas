---
description: Pre-release checklist before version bump
---

# Pre-Release Checklist

**Trigger**: Before asking "Should we update the version?"

## Checklist (11 items)

| # | Item | Location |
|---|------|----------|
| 1 | README version badge | `README.md`, `README.zh-TW.md` |
| 2 | CLAUDE.md version | `CLAUDE.md` header |
| 3 | Plugin version | `plugin/.claude-plugin/plugin.json` |
| 4 | Marketplace version | `.claude-plugin/marketplace.json` |
| 5 | Plugin CHANGELOG | `plugin/CHANGELOG.md` |
| 6 | Dev history | `dev-notes/HISTORY.md` |
| 7 | Implementation notes | `dev-notes/YYYY-MM/YYYY-MM-DD-*.md` |
| 8 | Command files sync | `.claude/commands/` ↔ `plugin/commands/` |
| 9 | Command footers | Version in command files |
| 10 | USAGE_GUIDE footers | `USAGE_GUIDE.md`, `USAGE_GUIDE.zh-TW.md` |
| 11 | New scripts | `scripts/atlas/*.sh` executable |

## Flow

```
1. Feature implementation complete
2. Execute all 11 checks
3. Fix any missing items
4. Ask user: "Update version to vX.Y.Z?"
5. Execute only after confirmation
```

## Version Rules

- **PATCH** (x.y.Z): Bug fixes, minor improvements
- **MINOR** (x.Y.0): New features, new commands
- **MAJOR** (X.0.0): Breaking changes
