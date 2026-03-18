# Contract Audit Workflow

Complete step-by-step guide for executing the multi-LLM contract audit pipeline.

## Pipeline Location

All pipeline scripts are located at:
```
proposals/contract-audit/pipeline/
```

Referenced from this file as `$PIPELINE_DIR` = `../../../proposals/contract-audit/pipeline/`

---

## Step 1: Parse Arguments and Detect Language

Parse `$ARGUMENTS` to extract the target file path and language.

### Argument Parsing

```bash
# Extract file path (first non-flag argument)
FILE_PATH=""
LANGUAGE=""
ZONE_ID=""
FORCE=false

for arg in $ARGUMENTS; do
    case "$arg" in
        --force) FORCE=true ;;
        --language) NEXT_IS_LANG=true ;;
        --zone) NEXT_IS_ZONE=true ;;
        objc|swift|typescript|javascript)
            if [ "$NEXT_IS_LANG" = true ]; then
                LANGUAGE="$arg"
                NEXT_IS_LANG=false
            else
                FILE_PATH="$arg"
            fi
            ;;
        *)
            if [ "$NEXT_IS_ZONE" = true ]; then
                ZONE_ID="$arg"
                NEXT_IS_ZONE=false
            else
                FILE_PATH="$arg"
            fi
            ;;
    esac
done
```

### Language Detection

If `--language` not specified, detect from file extension:

| Extension | Language |
|-----------|----------|
| `.m`, `.h` (with ObjC patterns) | objc |
| `.swift` | swift |
| `.ts`, `.tsx` | typescript |
| `.js`, `.jsx` | javascript |
| `.kt` | kotlin |
| `.py` | python |
| `.go` | go |
| `.rs` | rust |
| `.java` | java |

**Fallback**: Use `detect-language.sh`:

```bash
eval "$(bash $PIPELINE_DIR/detect-language.sh --file "$FILE_PATH")"
echo "Detected: LANGUAGE=$LANGUAGE, PLUGIN=$PLUGIN"
```

### Validation

```bash
# Verify file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File not found: $FILE_PATH"
    echo "Searching for similar files..."
    # Fuzzy search
    basename=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
    find . -name "*${basename}*" -type f 2>/dev/null | head -5
    exit 1
fi

# Verify language is supported
SUPPORTED_LANGUAGES="objc swift typescript javascript kotlin python go rust java"
if ! echo "$SUPPORTED_LANGUAGES" | grep -qw "$LANGUAGE"; then
    echo "Warning: Language '$LANGUAGE' not fully supported"
    echo "Supported: $SUPPORTED_LANGUAGES"
    echo "Proceeding with generic analysis..."
fi
```

### Zone Scoping (optional)

If `--zone <zone-id>` is provided, narrow the audit to a specific responsibility zone from `/atlas.seam` output.

```bash
if [ -n "$ZONE_ID" ]; then
    MODULE_NAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]')
    SEAM_FILE=".sourceatlas/seam/${MODULE_NAME}.yaml"

    if [ ! -f "$SEAM_FILE" ]; then
        echo "⚠️ Seam file not found: $SEAM_FILE"
        echo "Run /atlas.seam $FILE_PATH first, then use --zone"
        exit 1
    fi

    # Extract line range for the specified zone
    # Zone entries in seam YAML have format: zone_id, start_line, end_line
    ZONE_START=$(grep -A5 "id: ${ZONE_ID}" "$SEAM_FILE" | grep "start_line:" | awk '{print $2}')
    ZONE_END=$(grep -A5 "id: ${ZONE_ID}" "$SEAM_FILE" | grep "end_line:" | awk '{print $2}')

    if [ -z "$ZONE_START" ] || [ -z "$ZONE_END" ]; then
        echo "⚠️ Zone '${ZONE_ID}' not found in $SEAM_FILE"
        echo "Available zones:"
        grep "id:" "$SEAM_FILE" | awk '{print "  - " $2}'
        exit 1
    fi

    echo "📍 Scoping audit to zone '${ZONE_ID}' (lines ${ZONE_START}-${ZONE_END})"
    # Extract only the zone's lines for analysis
    ZONE_CONTENT=$(sed -n "${ZONE_START},${ZONE_END}p" "$FILE_PATH")
fi
```

When zone-scoped, all pipeline steps operate on the extracted zone content rather than the full file. Line references in contracts are adjusted to be absolute (relative to the original file).

---

## Step 2: Environment Check

Check for required external CLI tools.

### Required Tools

| Tool | Purpose | Required |
|------|---------|----------|
| `gemini` | Step 1 blind scan | Optional (degraded mode) |
| `codex` | Step 3 adversarial review | Optional (degraded mode) |
| `rg` (ripgrep) | Boundary discovery | Required |
| `ast-grep` | Structured verification | Optional (grep fallback) |

### Check Script

```bash
DEGRADED=false
MISSING_TOOLS=""

# Check gemini CLI
if ! command -v gemini &>/dev/null; then
    MISSING_TOOLS="$MISSING_TOOLS gemini"
    DEGRADED=true
fi

# Check codex CLI
if ! command -v codex &>/dev/null; then
    MISSING_TOOLS="$MISSING_TOOLS codex"
    DEGRADED=true
fi

# Check ripgrep (required)
if ! command -v rg &>/dev/null; then
    echo "Error: ripgrep (rg) is required but not found"
    echo "Install: brew install ripgrep"
    exit 1
fi

if [ "$DEGRADED" = true ]; then
    echo "⚠️ Degraded mode: missing$MISSING_TOOLS"
    echo "Will generate prompt files for manual execution"
fi
```

---

## Step 3: Cache Check

If `--force` is NOT set, check for existing results.

```bash
# Convert module name to cache filename
MODULE_NAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]')
CACHE_FILE=".sourceatlas/audit/${MODULE_NAME}.yaml"

if [ "$FORCE" = false ] && [ -f "$CACHE_FILE" ]; then
    DAYS_AGO=$(( ($(date +%s) - $(stat -f %m "$CACHE_FILE")) / 86400 ))
    echo "📁 Loading from cache: $CACHE_FILE ($DAYS_AGO days ago)"
    echo "💡 Use --force to re-audit"
    cat "$CACHE_FILE"
    exit 0
fi
```

---

## Step 4: Execute Pipeline

### Option A: Full Pipeline (gemini + codex available)

Execute `run-baseline.sh` with appropriate parameters:

```bash
cd $PIPELINE_DIR

# Build config or use CLI args
bash run-baseline.sh \
    --file "$FILE_PATH" \
    --language "$LANGUAGE" \
    --output-dir ".sourceatlas/audit/runs/$(date +%Y%m%d-%H%M%S)"
```

The pipeline executes 4 steps internally:

#### Step 0 — Boundary Discovery

`rg` scans the codebase for files related to the target module:
- Import/include references
- Type references
- Notification/event patterns

#### Step 1 — Gemini Blind Scan

Gemini independently discovers hidden behaviors WITHOUT seeing the Claude prompt. This prevents confirmation bias.

Input: Target file + boundary context files
Output: List of discovered behaviors with evidence

#### Step 2 — Claude Structured Audit

Claude extracts formal contracts using the M/L/N/S/E/C/D/P taxonomy:
- Each contract includes: Trigger, Input, Output, Condition, Ordering, Risk, Evidence
- Each contract has metadata: scope, seam_type, pinch_point
- Verification scripts (grep/ast-grep) for each contract

#### Step 3 — Codex Adversarial Review

Codex reviews each contract with an adversarial lens:
- **CONFIRM**: Contract is valid and well-evidenced
- **DISPUTE**: Contract is incorrect or overstated (with reasoning)
- **ADD**: Missing contract discovered by Codex

Quality gate: CONFIRM_RATIO should be ≤70% (healthy disagreement means thorough review).

#### Step 4 — Claude Merge

Claude merges all three LLM outputs:
- Resolve disputes
- Integrate additions
- Produce final contract list + CI verification rules

### Option B: Degraded Mode (missing CLI tools)

Generate prompt files that the user can manually feed to each LLM:

```bash
PROMPTS_DIR=".sourceatlas/audit/prompts"
mkdir -p "$PROMPTS_DIR"

# Generate Step 1 prompt for Gemini
cat > "$PROMPTS_DIR/step1-gemini.md" << 'PROMPT'
[Generated from proposals/contract-audit/prompts/gemini-blind-scan.md]
[With language plugin content inserted]
[And target file content appended]
PROMPT

# Generate Step 2 prompt for Claude
cat > "$PROMPTS_DIR/step2-claude.md" << 'PROMPT'
[Generated from proposals/contract-audit/prompts/skeleton.md]
[With language plugin content inserted]
PROMPT

# Generate Step 3 prompt for Codex
cat > "$PROMPTS_DIR/step3-codex.md" << 'PROMPT'
[Generated from proposals/contract-audit/prompts/codex-adversary.md]
PROMPT

echo "📝 Prompt files generated in $PROMPTS_DIR"
echo ""
echo "Manual execution steps:"
echo "1. Feed step1-gemini.md to Gemini"
echo "2. Feed step2-claude.md to Claude (include Gemini output)"
echo "3. Feed step3-codex.md to Codex (include Claude output)"
echo "4. Run /atlas.audit $FILE_PATH --force to merge results"
```

---

## Step 5: Output and Save

### Format Output

Parse the pipeline output and format using [output-template.md](output-template.md).

### Auto-Save

```bash
# Ensure directory exists
mkdir -p .sourceatlas/audit

# Save YAML output
MODULE_NAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//' | tr '[:upper:]' '[:lower:]')
cp "$OUTPUT_DIR/final-contracts.yaml" ".sourceatlas/audit/${MODULE_NAME}.yaml"

echo "📁 Saved to: .sourceatlas/audit/${MODULE_NAME}.yaml"
```

### Save with backup

Use `save-output.sh` for timestamped backup:

```bash
bash $PIPELINE_DIR/save-output.sh \
    --module "$MODULE_NAME" \
    --output-dir "$OUTPUT_DIR" \
    --target ".sourceatlas/audit/"
```

---

## Error Handling

### File Not Found

```bash
echo "❌ File not found: $FILE_PATH"
echo ""
echo "Did you mean one of these?"
# Search by basename pattern
find . -name "*$(basename "$FILE_PATH" .${FILE_PATH##*.})*" -type f \
    | grep -v node_modules | grep -v .git | head -5
```

### Language Not Supported

```bash
echo "⚠️ Language '$LANGUAGE' has limited support"
echo ""
echo "Fully supported (with language plugin):"
echo "  objc, swift, typescript, javascript"
echo ""
echo "Basic support (generic analysis):"
echo "  kotlin, python, go, rust, java"
echo ""
echo "Proceeding with generic skeleton.md..."
```

### Pipeline Failure

If `run-baseline.sh` exits non-zero:

```bash
echo "❌ Pipeline failed at step $FAILED_STEP"
echo ""
echo "Partial results saved to: $OUTPUT_DIR"
echo "Check logs: $OUTPUT_DIR/pipeline.log"
echo ""
echo "Common fixes:"
echo "  - Gemini rate limit: wait 60s and retry"
echo "  - Codex timeout: use --timeout 300"
echo "  - File too large (>1000 lines): split into logical sections"
```

### Empty Results

If no contracts are found:

```bash
echo "📋 No contracts found for $MODULE_NAME"
echo ""
echo "This may mean:"
echo "  1. The file is a leaf module with no hidden behavior"
echo "  2. The file is too simple for contract audit"
echo "  3. Consider using /atlas.impact instead for dependency analysis"
```
