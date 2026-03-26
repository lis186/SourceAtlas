# Contract Audit Reference

Advanced features and behaviors reference.

---

## Cache Behavior

### Cache Check (Highest Priority)

**If `--force` is not in arguments**, check cache first:

1. Extract module name from file path (basename, no extension, lowercase)
   - Example: `NYHTTPSClient.m` → `nyhttpsclient`
   - Example: `src/auth/AuthService.ts` → `authservice`
2. Check cache:
   ```bash
   ls -la .sourceatlas/audit/{name}.yaml 2>/dev/null
   ```

3. **If cache exists**:
   - Calculate days since creation
   - Read cache content using Read tool
   - Output:
     ```
     📁 Loading from cache: .sourceatlas/audit/{name}.yaml (N days ago)
     💡 Use --force to re-audit
     ```
   - **If over 30 days**, additionally display:
     ```
     ⚠️ Cache is N days old. Code may have changed.
     💡 Consider re-auditing with --force
     ```

4. **If cache does not exist**: Proceed with pipeline execution

---

## Auto-Save

After successful pipeline execution:

1. Create directory: `mkdir -p .sourceatlas/audit`
2. Save YAML: `.sourceatlas/audit/{module_name}.yaml`
3. Timestamped backup via `save-output.sh`

### Save Format

See [output-template.md#yaml-save-format](output-template.md#yaml-save-format) for schema.

---

## Language Support

### Fully Supported (with language plugin)

| Language | Plugin | ast-grep | Verification |
|----------|--------|----------|--------------|
| Objective-C | `languages/objc.md` | ❌ (grep fallback) | grep only |
| Swift | `languages/swift.md` | ✅ | ast-grep + grep |
| TypeScript | `languages/typescript.md` | ✅ | ast-grep + grep |
| JavaScript | `languages/javascript.md` | ✅ | ast-grep + grep |
| Kotlin | `languages/kotlin.md` | ✅ | ast-grep + grep |

### Basic Support (generic skeleton)

| Language | Plugin | ast-grep | Verification |
|----------|--------|----------|-------------|
| Python | planned | ✅ | ast-grep + grep |
| Go | planned | ✅ | ast-grep + grep |
| Rust | planned | ✅ | ast-grep + grep |
| Java | planned | ✅ | ast-grep + grep |

### Language Detection

Priority order:
1. `--language` CLI flag (explicit)
2. File extension mapping
3. `detect-language.sh` fallback (project-level detection)

Detection script: `proposals/contract-audit/pipeline/detect-language.sh`

---

## Degraded Mode

When `gemini` or `codex` CLI is unavailable, the pipeline operates in degraded mode:

### What Changes

| Feature | Full Mode | Degraded Mode |
|---------|-----------|---------------|
| Gemini blind scan | Automatic | Prompt file generated |
| Claude audit | Automatic | Automatic (always available) |
| Codex review | Automatic | Prompt file generated |
| Cross-validation | 3-LLM | Manual (user feeds prompts) |
| Output quality | Highest | Depends on manual execution |

### Prompt File Location

Generated at: `.sourceatlas/audit/prompts/`

```
.sourceatlas/audit/prompts/
├── step1-gemini.md      # Feed to Gemini (web or API)
├── step2-claude.md      # Feed to Claude (include Gemini output)
└── step3-codex.md       # Feed to Codex (include Claude output)
```

### Re-merging After Manual Execution

After manually running all three LLMs:

```bash
/atlas.audit <file-path> --force
# Paste each LLM's output when prompted
```

---

## Pipeline Scripts

All scripts located at `proposals/contract-audit/pipeline/`:

| Script | Purpose |
|--------|---------|
| `run-baseline.sh` | Main pipeline orchestrator (Steps 0-4) |
| `detect-language.sh` | Language detection bridge |
| `recommend-targets.sh` | Auto-recommend high-value audit targets |
| `save-output.sh` | Save with timestamped backup |
| `output-template.yaml` | YAML output schema |
| `audit.config.schema.yaml` | Config file JSON schema |
| `contract-output.schema.yaml` | Contract output schema |

### Configuration Files

Example configs in `proposals/contract-audit/pipeline/`:

| File | Language | Target |
|------|----------|--------|
| `audit.config.example-objc.yml` | Objective-C | NYHTTPSClient |
| `audit.config.example-swift.yml` | Swift | Example Swift module |
| `audit.config.example-typescript.yml` | TypeScript | AuthService |

---

## Handoffs (Recommended Next)

After contract audit, suggest:

| Situation | Recommended Next |
|-----------|-----------------|
| Found high-risk dependencies | `/atlas.impact <module>` |
| Need to understand call chains | `/atlas.flow <function>` |
| Planning refactoring scope | `/atlas.deps` |
| Want to find similar patterns | `/atlas.pattern <pattern>` |
| Need historical context | `/atlas.history` |

---

## Best Practices

1. **Start with high-risk modules**: Use `--recommend` or `/atlas.history` hotspots
2. **One module at a time**: Each audit is 3 LLM calls — budget accordingly
3. **Review disputes carefully**: Codex DISPUTE often reveals real issues
4. **Keep Phase B rules**: Add grep assertions to CI to prevent regression
5. **Re-audit after major changes**: Cache expires in 30 days, but re-audit sooner if the module changes significantly
