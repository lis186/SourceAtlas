#!/bin/bash
# Format Comparison Script: TOON vs YAML
# Compares token efficiency and readability

set -e

PROJECT_PATH="${1:-.}"
PROJECT_NAME=$(basename "$PROJECT_PATH")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="format-comparison"

mkdir -p "$RESULTS_DIR"
RESULT_FILE="$RESULTS_DIR/${PROJECT_NAME}_${TIMESTAMP}.json"

echo "🔬 Format Comparison: TOON vs YAML"
echo "📁 Project: $PROJECT_NAME"

# Function to estimate tokens (rough: char count / 4)
count_tokens() {
    local file=$1
    local chars=$(wc -c < "$file" | tr -d ' ')
    echo $((chars / 4))
}

# Check if we have both formats
if [ ! -f ".sourceatlas/fingerprint.toon" ]; then
    echo "❌ fingerprint.toon not found"
    exit 1
fi

# Generate YAML version from TOON (manual conversion for now)
echo "📝 Converting TOON to YAML for comparison..."

# Create YAML version (simplified structure)
cat > .sourceatlas/fingerprint.yaml <<'YAML_EOF'
# This is a test YAML version
# TODO: Implement proper TOON -> YAML converter

metadata:
  project_name: placeholder
  scan_time: 2025-11-22T10:00:00Z
  total_files_estimate: 100
  scanned_files: 10
  scan_ratio: 10.0%

project_fingerprint:
  project_type: WEB_APP
  scale: MEDIUM
  primary_language: TypeScript 5.0+
  framework: Express.js
  architecture: Microservice

technology_stack:
  backend:
    language: TypeScript 5.0+
    framework: Express.js
    runtime: Node.js 18+

hypotheses:
  architecture:
    - hypothesis: "Uses service-oriented architecture"
      confidence: 0.90
      evidence: "services/ directory with 12 files"
      validation_method: "Check service pattern consistency"
YAML_EOF

# Measure both formats
echo "📊 Measuring formats..."

TOON_LINES=$(wc -l < .sourceatlas/fingerprint.toon | tr -d ' ')
TOON_BYTES=$(stat -f%z .sourceatlas/fingerprint.toon 2>/dev/null || stat -c%s .sourceatlas/fingerprint.toon)
TOON_TOKENS=$(count_tokens .sourceatlas/fingerprint.toon)

YAML_LINES=$(wc -l < .sourceatlas/fingerprint.yaml | tr -d ' ')
YAML_BYTES=$(stat -f%z .sourceatlas/fingerprint.yaml 2>/dev/null || stat -c%s .sourceatlas/fingerprint.yaml)
YAML_TOKENS=$(count_tokens .sourceatlas/fingerprint.yaml)

# Calculate savings
TOKEN_DIFF=$((YAML_TOKENS - TOON_TOKENS))
if [ $YAML_TOKENS -gt 0 ]; then
    TOKEN_SAVINGS_PCT=$(echo "scale=2; $TOKEN_DIFF * 100 / $YAML_TOKENS" | bc)
else
    TOKEN_SAVINGS_PCT=0
fi

SIZE_DIFF=$((YAML_BYTES - TOON_BYTES))
if [ $YAML_BYTES -gt 0 ]; then
    SIZE_SAVINGS_PCT=$(echo "scale=2; $SIZE_DIFF * 100 / $YAML_BYTES" | bc)
else
    SIZE_SAVINGS_PCT=0
fi

# Generate comparison report
cat > "$RESULT_FILE" <<EOF
{
  "project": "$PROJECT_NAME",
  "timestamp": "$TIMESTAMP",
  "toon_format": {
    "lines": $TOON_LINES,
    "bytes": $TOON_BYTES,
    "estimated_tokens": $TOON_TOKENS
  },
  "yaml_format": {
    "lines": $YAML_LINES,
    "bytes": $YAML_BYTES,
    "estimated_tokens": $YAML_TOKENS
  },
  "comparison": {
    "token_difference": $TOKEN_DIFF,
    "token_savings_percent": $TOKEN_SAVINGS_PCT,
    "size_difference_bytes": $SIZE_DIFF,
    "size_savings_percent": $SIZE_SAVINGS_PCT,
    "toon_is_smaller": $([ $TOON_TOKENS -lt $YAML_TOKENS ] && echo "true" || echo "false")
  },
  "notes": "YAML version is placeholder for now. Need actual conversion."
}
EOF

# Display results
echo ""
echo "✅ Comparison Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 TOON Format:"
echo "   Lines: $TOON_LINES"
echo "   Bytes: $TOON_BYTES"
echo "   Tokens: ~$TOON_TOKENS"
echo ""
echo "📋 YAML Format:"
echo "   Lines: $YAML_LINES"
echo "   Bytes: $YAML_BYTES"
echo "   Tokens: ~$YAML_TOKENS"
echo ""
echo "💡 Savings (TOON vs YAML):"
echo "   Token difference: $TOKEN_DIFF"
echo "   Token savings: ${TOKEN_SAVINGS_PCT}%"
echo "   Size savings: ${SIZE_SAVINGS_PCT}%"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Full report saved to: $RESULT_FILE"
echo ""
echo "⚠️  Note: YAML version is placeholder. Need proper converter."
