#!/bin/bash
# SourceAtlas Benchmark Script
# Measures performance metrics for Stage 0 analysis

set -e

PROJECT_PATH="${1:-.}"
PROJECT_NAME=$(basename "$PROJECT_PATH")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="benchmark-results"

mkdir -p "$RESULTS_DIR"
RESULT_FILE="$RESULTS_DIR/${PROJECT_NAME}_${TIMESTAMP}.json"

echo "🔍 Benchmarking SourceAtlas on: $PROJECT_NAME"
echo "📊 Results will be saved to: $RESULT_FILE"

# Start timing
START_TIME=$(date +%s)

# Count total files
TOTAL_FILES=$(find "$PROJECT_PATH" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.rb" -o -name "*.go" -o -name "*.java" \) | wc -l | tr -d ' ')

echo "📁 Total code files: $TOTAL_FILES"

# Simulate Stage 0 analysis (will be replaced with actual command)
echo "⏱️  Running Stage 0 analysis..."

# TODO: Run actual /atlas-overview command here
# For now, using existing output as baseline

# End timing
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Calculate metrics from output
if [ -f ".sourceatlas/fingerprint.toon" ]; then
    LINES=$(wc -l < .sourceatlas/fingerprint.toon | tr -d ' ')
    BYTES=$(stat -f%z .sourceatlas/fingerprint.toon 2>/dev/null || stat -c%s .sourceatlas/fingerprint.toon)

    # Rough token estimate: 1 line ≈ 15 tokens (average)
    ESTIMATED_TOKENS=$((LINES * 15))

    # Count hypotheses (lines starting with "- h:" or "- hypothesis:")
    HYPOTHESES=$(grep -c "^\s*- h:" .sourceatlas/fingerprint.toon || echo "0")

    # Try to extract scanned files count
    SCANNED_FILES=$(grep "scanned_files:" .sourceatlas/fingerprint.toon | head -1 | awk '{print $2}' | cut -d'/' -f1)
    SCAN_RATIO=$(echo "scale=2; $SCANNED_FILES * 100 / $TOTAL_FILES" | bc)
else
    echo "⚠️  No fingerprint.toon found"
    LINES=0
    BYTES=0
    ESTIMATED_TOKENS=0
    HYPOTHESES=0
    SCANNED_FILES=0
    SCAN_RATIO=0
fi

# Generate JSON report
cat > "$RESULT_FILE" <<EOF
{
  "project": "$PROJECT_NAME",
  "timestamp": "$TIMESTAMP",
  "performance": {
    "duration_seconds": $DURATION,
    "duration_target": 900,
    "meets_target": $([ $DURATION -le 900 ] && echo "true" || echo "false")
  },
  "size": {
    "lines": $LINES,
    "lines_target": 300,
    "meets_target": $([ $LINES -le 300 ] && echo "true" || echo "false"),
    "bytes": $BYTES,
    "estimated_tokens": $ESTIMATED_TOKENS,
    "tokens_target": 5000,
    "tokens_meets_target": $([ $ESTIMATED_TOKENS -le 5000 ] && echo "true" || echo "false")
  },
  "coverage": {
    "total_files": $TOTAL_FILES,
    "scanned_files": $SCANNED_FILES,
    "scan_ratio_percent": $SCAN_RATIO,
    "scan_ratio_target": 10.0,
    "meets_target": $(echo "$SCAN_RATIO <= 10" | bc -l | grep -q 1 && echo "true" || echo "false")
  },
  "quality": {
    "hypotheses_count": $HYPOTHESES,
    "hypotheses_target_min": 10,
    "hypotheses_target_max": 15,
    "meets_target": $([ $HYPOTHESES -ge 10 ] && [ $HYPOTHESES -le 15 ] && echo "true" || echo "false")
  }
}
EOF

# Display summary
echo ""
echo "✅ Benchmark Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏱️  Duration: ${DURATION}s (target: ≤900s) $([ $DURATION -le 900 ] && echo "✅" || echo "❌")"
echo "📄 Lines: $LINES (target: ≤300) $([ $LINES -le 300 ] && echo "✅" || echo "❌")"
echo "🎯 Tokens: ~$ESTIMATED_TOKENS (target: ≤5000) $([ $ESTIMATED_TOKENS -le 5000 ] && echo "✅" || echo "❌")"
echo "🔍 Scan ratio: ${SCAN_RATIO}% (target: ≤10%) $(echo "$SCAN_RATIO <= 10" | bc -l | grep -q 1 && echo "✅" || echo "❌")"
echo "💡 Hypotheses: $HYPOTHESES (target: 10-15) $([ $HYPOTHESES -ge 10 ] && [ $HYPOTHESES -le 15 ] && echo "✅" || echo "❌")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Full report saved to: $RESULT_FILE"
