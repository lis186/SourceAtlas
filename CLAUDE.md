# CLAUDE.md

AI collaboration guide for SourceAtlas development.

## What is SourceAtlas

**AI-optimized codebase analysis tool** - scan <5% of files to achieve 70-95% understanding using information theory principles.

**Current Version**: v2.11.0 (2026-01-02)

## Key Files

| File | Purpose |
|------|---------|
| `ANALYSIS_CONSTITUTION.md` | Immutable analysis principles (7 Articles) |
| `PROMPTS.md` | Stage 0-1-2 prompt templates |
| `PRD.md` | Product requirements |
| `USAGE_GUIDE.md` | User documentation |
| `dev-notes/ROADMAP.md` | Future plans |
| `dev-notes/HISTORY.md` | Version history |

## Commands

```
/atlas.overview  - Project fingerprint (Stage 0)
/atlas.pattern   - Learn design patterns
/atlas.flow      - Flow tracing (11 modes)
/atlas.history   - Git temporal analysis
/atlas.impact    - Change impact analysis
/atlas.deps      - Dependency analysis
/atlas.list      - List saved analyses
/atlas.clear     - Clear saved analyses
```

All commands auto-save to `.sourceatlas/`. Use `--force` to skip cache and re-analyze.

## Must Follow

### GitButler Workflow
- **Never use `git commit`** - GitButler manages all commits
- Focus on code, let GitButler handle version control
- When done, stop and let GitButler hooks execute

### Analysis Principles (from Constitution)
1. **Information Theory** - High-entropy files first (configs, docs, models)
2. **Scale-Aware** - TINY 50%, SMALL 20%, MEDIUM 10%, LARGE 5%, VERY_LARGE 3%
3. **Evidence-Based** - Every claim needs `file:line` reference
4. **Exclude Always** - `.venv`, `node_modules`, `__pycache__`

### Implementation Rules
1. Standards over custom (YAML, Markdown)
2. Test on 3+ real projects
3. Document while developing
4. Use `validate-constitution.sh` for compliance

## Key Learnings (v1.0)

1. **Information theory works** - <5% scan → 70-80% understanding
2. **Scale-awareness critical** - Different strategies per size
3. **YAML > TOON** - Standard ecosystem > 14% token savings
4. **Benchmarking reveals truth** - Test on real projects
5. **AI collaboration detectable** - Level 0-4 maturity model

## Directory Structure

```
sourceatlas2/
├── plugin/              # Official Claude Code Plugin
├── .claude/commands/    # Local dev slash commands
├── scripts/atlas/       # Core analysis scripts
├── dev-notes/           # Development history
├── proposals/           # Feature proposals
└── ideas/               # Experimental notes
```

## Using Project Memory

When user asks about "this project", "architecture", "overview":
1. Check `.sourceatlas/` exists
2. Read `overview.yaml` for context
3. Read specific caches based on question topic

## Related Skills

- `/multi-approach` - Compare 2+ implementation options
- `/dev-notes-guide` - dev-notes/ management rules
- `/pre-release` - Version bump checklist
