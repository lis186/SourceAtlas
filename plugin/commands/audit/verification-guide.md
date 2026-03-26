# Contract Audit Verification Guide

Prevent hallucinated contracts, incorrect line references, and unverifiable assertions.

**When to Run**: After pipeline execution, BEFORE output and save.

---

## Step V1: Verify File References

Every contract must reference a real file and line.

```bash
ERRORS=0

# For each contract, verify evidence exists
while IFS='|' read -r contract_id file line snippet; do
    if [ ! -f "$file" ]; then
        echo "❌ $contract_id: File not found: $file"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    actual=$(sed -n "${line}p" "$file")
    if ! echo "$actual" | grep -qF "$snippet"; then
        echo "⚠️ $contract_id: Line $line doesn't match expected snippet"
        echo "   Expected: $snippet"
        echo "   Actual:   $actual"
        ERRORS=$((ERRORS + 1))
    fi
done < contracts_evidence.tsv

echo "File verification: $ERRORS errors"
```

---

## Step V2: Verify Contract ID Uniqueness

```bash
# Extract all contract IDs and check for duplicates
DUPES=$(grep -oP '[A-Z]-\d{3}' contracts.yaml | sort | uniq -d)
if [ -n "$DUPES" ]; then
    echo "❌ Duplicate contract IDs: $DUPES"
fi
```

---

## Step V3: Verify Grep Assertions

Each contract should produce a machine-verifiable assertion. Test them all:

```bash
PASS=0
FAIL=0

while IFS='|' read -r contract_id verify_cmd; do
    if eval "$verify_cmd" 2>/dev/null; then
        PASS=$((PASS + 1))
    else
        echo "❌ $contract_id: Verification failed: $verify_cmd"
        FAIL=$((FAIL + 1))
    fi
done < verification_commands.tsv

echo "Grep assertions: $PASS passed, $FAIL failed"
```

---

## Step V4: Validate Cross-Validation Metrics

```bash
TOTAL=$((CONFIRMED + DISPUTED + ADDED))
if [ "$TOTAL" -eq 0 ]; then
    echo "❌ No cross-validation data"
    exit 1
fi

RATIO=$((CONFIRMED * 100 / TOTAL))

if [ "$RATIO" -gt 70 ]; then
    echo "⚠️ CONFIRM_RATIO=$RATIO% (>70%)"
    echo "   Too high — Codex may not be reviewing critically enough"
elif [ "$RATIO" -lt 30 ]; then
    echo "⚠️ CONFIRM_RATIO=$RATIO% (<30%)"
    echo "   Too low — contracts may need revision"
else
    echo "✅ CONFIRM_RATIO=$RATIO% (healthy range 30-70%)"
fi
```

---

## Step V5: Category Distribution Check

Ensure contracts aren't all one category (indicates shallow analysis):

```bash
CATEGORIES=$(grep -oP '^[A-Z](?=-\d{3})' contracts.yaml | sort | uniq -c | sort -rn)
UNIQUE_CATS=$(echo "$CATEGORIES" | wc -l)

if [ "$UNIQUE_CATS" -lt 3 ]; then
    echo "⚠️ Only $UNIQUE_CATS categories found"
    echo "   Expected at least 3 for thorough analysis"
    echo "   Distribution: $CATEGORIES"
fi
```

---

## Verification Summary Template

Append this to the output:

```markdown
---

## ✅ Verification Summary

| Check | Result | Details |
|-------|--------|---------|
| File references | ✅/❌ | [N] verified, [N] failed |
| ID uniqueness | ✅/❌ | [N] unique, [N] duplicates |
| Grep assertions | ✅/❌ | [N] passed, [N] failed |
| CONFIRM_RATIO | ✅/⚠️ | [N]% ([assessment]) |
| Category spread | ✅/⚠️ | [N] categories |
```

---

## Handling Failures

### File Reference Failures

- **File not found**: Remove contract or update path
- **Line mismatch**: Search for the snippet in the file and update line number
- **Snippet not found**: The contract may be hallucinated — flag for manual review

### Grep Assertion Failures

- **Pattern too specific**: Relax the grep pattern
- **File changed since analysis**: Re-run with `--force`
- **ast-grep not available**: Fall back to grep pattern

### Cross-Validation Anomalies

- **CONFIRM_RATIO > 70%**: Consider re-running Codex with stricter prompt
- **CONFIRM_RATIO < 30%**: Review disputed contracts — are they actually valid?
- **No ADDs from Codex**: May indicate target is well-understood (not necessarily bad)
