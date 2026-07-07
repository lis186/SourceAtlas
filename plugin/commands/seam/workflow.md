# Seam Discovery: Workflow

Detailed step-by-step execution guide for `/atlas.seam`.

---

## Step 1: Parse Arguments and Detect Language

Parse `$ARGUMENTS` to extract:
- **File path**: Absolute or relative path to target file
- **Language**: Auto-detect from extension, or use `--language` flag
- **Force flag**: `--force` to skip cache

Language detection (handled by `detect-zones.sh`):

| Extension | Language |
|-----------|----------|
| `.m`, `.h` | objc |
| `.swift` | swift |
| `.ts`, `.tsx` | typescript |
| `.js`, `.jsx` | javascript |
| `.go` | go |
| `.java` | java |
| `.kt`, `.kts` | kotlin |
| `.py` | python |
| `.rs` | rust |

**Validation**: Check file exists and is readable. If not, suggest fuzzy matches.

---

## Step 2: Check Cache

Check `.sourceatlas/seam/` for existing zone report:

```bash
CACHE_DIR=".sourceatlas/seam"
MODULE=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
CACHE_FILE="$CACHE_DIR/${MODULE}.yaml"

if [[ -f "$CACHE_FILE" ]] && [[ -z "$FORCE" ]]; then
    echo "Cache hit: $CACHE_FILE"
    # Read and present cached results
fi
```

With `--force`, always re-run analysis.

---

## Step 2a: Detect Refactoring Phase

Run phase detection to determine zone ranking strategy before analysis:

```bash
PHASE_SCRIPT="${CLAUDE_PLUGIN_ROOT}/commands/seam/scripts/detect-phase.sh"
bash "$PHASE_SCRIPT" "$FILE_PATH"
```

### Phase Decision Table

| Phase | Condition | Zone Ranking |
|-------|-----------|-------------|
| **1** | `test_refs == 0` | Feathers ordering: testability first |
| **1.5** | `test_refs < 3` | Feathers ordering: expand coverage before restructuring |
| **2** | `test_refs >= 3` | Architectural ordering: highest-value zones first |

### Feathers Ordering Criteria (Phase 1 / 1.5)

Rank zones by:
1. **Least edit distance to a working test** — fewest changes to get a passing test
2. **Dependency direction** — zones pointing toward I/O / time / network cut first
3. **Enabling point accessibility** — skip zones where the switch is buried in a static initializer
4. **Collateral damage radius** — prefer small blast radius when coverage is thin
5. **Semantic coherence** — seam must fall on a real responsibility boundary

### Architectural Ordering Criteria (Phase 2)

Use the existing complexity × coupling formula from Step 5.

---

## Step 2b: Resolve Reviewers

```bash
BLIND_REVIEWER=$(command -v agy >/dev/null 2>&1 && echo agy || echo claude-subagent)
ADV_REVIEWER=$(command -v codex >/dev/null 2>&1 && echo codex || echo claude-subagent)
echo "reviewers: blind=$BLIND_REVIEWER adversarial=$ADV_REVIEWER"
```

The pipeline never blocks: when a CLI is missing (or fails at runtime, e.g. quota), the corresponding step runs in a **fresh-context Claude subagent** (Task tool) with the exact same prompt. Independence comes from the clean context, not the vendor. Record what actually ran in `seam_validation.reviewers`.

---

## Step 3: Run detect-zones.sh

```bash
SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/commands/seam/scripts"
bash "$SCRIPT_DIR/detect-zones.sh" "$FILE_PATH" --language "$LANGUAGE"
```

### Expected Output Structure

```yaml
# Zone Map: NYHTTPSClient.m
file: "/path/to/NYHTTPSClient.m"
language: objc
total_lines: 745
marker_count: 10
zones:
  - id: "initialization"
    name: "Initialization"
    lines: [1, 84]
    line_count: 84
    method_count: 2
    deps: [AFHTTPSessionManager, NYConfig]
  - id: "post-methods"
    name: "POST Methods"
    lines: [85, 294]
    ...

# Layer 2/3: Method implementations from clang AST
methods:
  - name: "-[postPath:dataStr:sendSynchronousRequest:success:failure:]"
    lines: [295, 330]
    line_count: 36
    sends: ["aesEncryptWithData:key:iv:", "base64", "hmacSha512:hmacKey:", ...]
    send_count: 14
```

### Fallback: No Zone Markers

If `marker_count: 0`, the script outputs `zones: []`. In this case:
1. Use Layer 3 method sends for clustering
2. Group methods by shared external collaborators
3. Create synthetic zones from clusters

---

## Step 3b: Blind Scan

The blind reviewer receives **only** the source file content and detect-zones.sh raw output. **Do NOT include**: Feathers seam taxonomy, language group table, or Claude's candidate list. The value of this step is independence.

### Option A: `agy` CLI

```bash
PROMPTS_DIR=".sourceatlas/seam/prompts"
mkdir -p "$PROMPTS_DIR"

# Build blind scan prompt (no taxonomy framing)
cat > "$PROMPTS_DIR/blind-scan.md" << PROMPT
Look at this source file and the zone map below. Find every place where
external dependencies are used — things that could be hard-coded, hard to
replace, or that a test might want to substitute. List them with file:line
evidence. Do not classify them, just list what you observe.

=== SOURCE FILE ===
$(cat "$FILE_PATH")

=== ZONE MAP ===
$(cat "$ZONES_OUTPUT")
PROMPT

agy -p "$(cat "$PROMPTS_DIR/blind-scan.md")" > "$PROMPTS_DIR/blind-output.md"
echo "✅ Blind scan complete (agy)"
```

### Option B: Claude subagent (agy unavailable or failed)

Build the same `blind-scan.md` prompt file, then spawn a **fresh-context subagent** (Task tool) whose entire instruction is that prompt plus "write your findings to `$PROMPTS_DIR/blind-output.md`". Do not pass any of this session's analysis or the taxonomy. Set `reviewers.blind: claude-subagent`.

---

## Step 4: Semantic Analysis (Claude's Job)

The script provides raw data. Claude performs all semantic interpretation.

### 4a. Responsibility Clustering

For each method in Layer 3, examine `sends`:

```
Method: -[postPath:dataStr:...] sends to [aesEncryptWithData:, hmacSha512:, base64]
→ Cluster: "Encryption"

Method: -[getPath:parameters:...] sends to [AFHTTPSessionManager, dispatch_semaphore_wait]
→ Cluster: "Core HTTP Dispatch"

Method: -[autoLogout] sends to [postNotificationName:, NSUserDefaults]
→ Cluster: "Session Management"
```

**Sandi Metz heuristic**: Methods belong to the same responsibility zone if they send messages to the same set of external collaborators.

### 4b. Cross-Reference with Layer 1 Zones

Map Layer 3 clusters back to Layer 1 zone boundaries:
- Does the pragma mark zone align with the responsibility cluster?
- If yes → zone is well-organized
- If no → zone name is misleading (see [gotchas.md#G1](gotchas.md))

### 4c. Seam Type Identification (Language-Group Aware)

Determine language group first (see [references/language-groups.md](references/language-groups.md)):

**Group A (Java, ObjC, Kotlin, Swift, Rust)** — Look for Object Seams:
- Does the zone accept protocol/interface parameters? → Object Seam exists
- Does the zone use categories/extensions? → Link Seam (risky)
- Does the zone have `#ifdef`/`cfg` guards? → Preprocessing Seam

**Group B (Go, TypeScript)** — Look for implicit Object Seams:
- Does the zone use struct fields or constructor params for dependencies? → Object Seam
- Go: Does the zone use package-level `var`? → Enabling point is function param, not constructor
- TS: Is the dependency imported as a module? → Module Seam available via jest.mock

**Group C (JavaScript, Python)** — Look for Module/Monkey-patch Seams:
- Is the dependency imported via `import`/`require`? → Module Seam (primary, zero code change)
- Is the dependency accessed via object property? → Monkey-patch Seam (secondary)
- Object Seam via constructor injection also works but adds unnecessary ceremony

### 4d. Code Smell Detection

Check for Fowler's refactoring signals:
- **Feature Envy**: Zone methods call external classes more than internal — count sends to external vs internal classes
- **Divergent Change**: Zone mixes unrelated responsibilities — multiple distinct clusters within one zone
- **Shotgun Surgery**: Changing one behavior requires editing multiple zones

---

## Step 4b: Adversarial Review

The adversarial reviewer receives: source file, detect-zones.sh output, the blind scan, and Claude's seam candidates.

### Option A: `codex` CLI

```bash
cat > "$PROMPTS_DIR/adversary.md" << PROMPT
You are an adversarial reviewer. Below are seam candidates proposed by two
prior analyses. Your job: issue a verdict for each candidate, and add any
you think are missing.

Verdicts:
- CONFIRM: candidate is valid, enabling point exists, coverage claim accurate
- DISPUTE: seam type wrong, enabling point absent, or coverage overstated (provide evidence)
- ADD: dependency or seam type the prior analyses missed
- FLAG: architectural issue that seams cannot solve (e.g., shared mutable state)

=== BLIND SCAN ===
$(cat "$PROMPTS_DIR/blind-output.md")

=== CLAUDE SEAM CANDIDATES ===
$(cat "$PROMPTS_DIR/claude-candidates.md")

=== SOURCE FILE ===
$(cat "$FILE_PATH")
PROMPT

codex < "$PROMPTS_DIR/adversary.md" > "$PROMPTS_DIR/adversary-output.md"
echo "✅ Adversarial review complete (codex)"
```

### Option B: Claude subagent (codex unavailable or failed)

Build the same `adversary.md` prompt file, then spawn a **fresh-context subagent** (Task tool) whose entire instruction is that prompt plus "write your verdicts to `$PROMPTS_DIR/adversary-output.md`". Set `reviewers.adversarial: claude-subagent`.

---

## Step 4c: Claude Merge

Resolve the adversarial verdicts and produce the final seam list:

1. **DISPUTED candidates**: Re-evaluate with evidence from both sides. Drop if the objection holds. Keep if Claude's evidence is stronger. Never keep without explicit reasoning.
2. **ADDED candidates**: Incorporate with Claude's seam type classification. Add `verification_grep` for each.
3. **FLAGGED concerns**: Record in `seam_validation.architectural_concerns` — these are not seam candidates, they are structural issues that must be fixed separately.

Tally cross-validation counts:
```bash
CONFIRMED=$(grep -c '^CONFIRM' "$PROMPTS_DIR/adversary-output.md" || echo 0)
DISPUTED=$(grep -c '^DISPUTE' "$PROMPTS_DIR/adversary-output.md" || echo 0)
ADDED=$(grep -c '^ADD' "$PROMPTS_DIR/adversary-output.md" || echo 0)
FLAGGED=$(grep -c '^FLAG' "$PROMPTS_DIR/adversary-output.md" || echo 0)
```

---

## Step 5: Score and Rank

Use the ranking strategy from Step 2a (`phase_detection.ranking_strategy`).

### Phase 2: Architectural Ordering

Priority formula:

```
priority = method_count × unique_external_deps × (1 + smell_count)
```

Sort zones by priority descending. Highest-scoring zone = recommended target.

### Phase 1 / 1.5: Feathers Ordering

Score each zone on 5 criteria (1=best, 4=worst relative to other zones):

| Score component | How to assess |
|----------------|---------------|
| **testability** | Count: async primitives + shared state + I/O calls in zone (fewer = better) |
| **io_direction** | Does zone own the I/O call itself? (yes = higher priority to cut) |
| **enabling_access** | Is the dependency injectable at a normal call site? (yes = accessible) |
| **blast_radius** | `prod_refs ÷ total_prod_files` — fraction of codebase affected |
| **semantic_coherence** | Does zone have exactly one responsibility cluster? |

Feathers rank = sort by `testability` ascending, break ties by `blast_radius` ascending.

**Annotate the output with which phase applies and why the ordering differs from architectural ordering.**

---

## Step 6: Present Results

Use the output format from [SKILL.md#output-format](SKILL.md#output-format).

Key presentation rules:
1. **Ranked list**: Highest priority first
2. **Visual hierarchy**: Use box-drawing characters for zone tree
3. **Cross-validation section**: Always include the blind/adversarial summary and which reviewers ran
4. **Actionable recommendation**: Always end with a specific `/atlas.audit` command
5. **Architectural concerns**: If the adversarial reviewer flagged any, list them separately before the recommendation
6. **Save to cache**: Write YAML to `.sourceatlas/seam/`

---

## Step 7: Auto-Save

```bash
mkdir -p .sourceatlas/seam
# Write zone-report.yaml following templates/zone-report.yaml
# Include seam_validation block:
#
# seam_validation:
#   reviewers: {blind: agy|claude-subagent, adversarial: codex|claude-subagent}
#   blind_candidates: N
#   claude_candidates: M
#   adversarial_confirmed: X
#   adversarial_disputed: Y
#   adversarial_added: Z
#   adversarial_flagged: W
#   architectural_concerns:
#     - "{description}"
```

---

## Error Handling

### File Not Found
- Search with `find` for similar filenames
- Suggest closest matches
- Ask user to clarify

### Language Not Detected
- Show supported extensions list
- Suggest `--language` flag

### detect-zones.sh Fails
- Check if file is readable
- Check stderr for clang errors
- Fall back to manual zone identification (read file, identify pragma marks directly)

### Clang AST Empty (ObjC)
- Check if `resolve-header-paths.sh` found any `-I` flags
- If Pods/ directory exists but headers not found, suggest running `pod install`
- Degrade to Layer 1 only (grep-based deps)

### No Zones AND No Methods
- File might be a header-only file (`.h` with no implementations)
- Or file uses unconventional structure
- Present the raw file structure and ask user to identify zones manually
