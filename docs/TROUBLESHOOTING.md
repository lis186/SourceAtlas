# Phase 9 Troubleshooting Guide

This guide helps diagnose and resolve common issues with SourceAtlas Phase 9 enterprise features.

## 🚨 Quick Diagnostics

### Health Check Command
```bash
# Run comprehensive health check
source lib/phase9_config.sh
validate_phase9_dependencies && echo "✅ Dependencies OK" || echo "❌ Dependency issues"
print_config_summary
```

### Enable Verbose Debugging
```bash
# Maximum debugging output
export SOURCEATLAS_PROGRESS_VERBOSE=true
export SOURCEATLAS_EVENTS_ENABLED=true
export SOURCEATLAS_METRICS_ENABLED=true

# Run with detailed logging
sourceatlas run --trace-id debug-$(date +%s) 2>&1 | tee debug.log
```

## 🔧 Common Issues & Solutions

### 1. Performance Issues

#### Issue: Very Slow Processing (<100 files/sec)
**Symptoms**: 
- Processing rate well below expected throughput
- High CPU usage, system feels sluggish
- Long processing times for small datasets

**Diagnosis**:
```bash
# Check current processing rate
grep "files/sec" .sourceatlas/events.jsonl | tail -5

# Check system resources
top -p $(pgrep -f sourceatlas) -n 1

# Check worker count
ps aux | grep -c "awk.*batch_optimize"
```

**Solutions**:
```bash
# Solution 1: Reduce worker count
export SOURCEATLAS_MAX_WORKERS=4
export SOURCEATLAS_MIN_WORKERS=2

# Solution 2: Enable streaming mode early
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=100000

# Solution 3: Disable heavy features temporarily
export SOURCEATLAS_CHECKPOINT_INTERVAL=300
export SOURCEATLAS_METRICS_ENABLED=false

# Test with minimal configuration
sourceatlas run --trace-id performance-test
```

#### Issue: Performance Degradation Over Time
**Symptoms**:
- EMA decline warnings in stderr
- Processing rate decreases during execution
- "Significant performance degradation detected" messages

**Diagnosis**:
```bash
# Check EMA trends
grep "EMA:" .sourceatlas/events.jsonl | tail -10

# Analyze performance metrics
jq -r 'select(.event=="performance_degradation") | .message' .sourceatlas/events.jsonl
```

**Solutions**:
```bash
# Solution 1: More responsive EMA monitoring
export SOURCEATLAS_EMA_ALPHA=0.4  # More sensitive to changes

# Solution 2: Enable streaming mode suggestions
export SOURCEATLAS_PERFORMANCE_CRITICAL_THRESHOLD=30  # Earlier warnings

# Solution 3: Increase checkpoint frequency
export SOURCEATLAS_CHECKPOINT_INTERVAL=30  # More frequent checkpoints

# Solution 4: Switch to streaming mode manually
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=50000  # Force streaming
```

### 2. Memory Issues

#### Issue: Out of Memory Errors
**Symptoms**:
- Process killed by system (OOM killer)
- "Cannot allocate memory" errors
- System becomes unresponsive

**Diagnosis**:
```bash
# Check memory usage patterns
dmesg | grep -i "killed process.*sourceatlas"

# Check current memory thresholds
echo "Warning: $SOURCEATLAS_MEMORY_WARNING_THRESHOLD"
echo "Prepare: $SOURCEATLAS_MEMORY_PREPARE_THRESHOLD"  
echo "Critical: $SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD"

# Monitor memory in real-time
watch 'ps aux | grep sourceatlas | head -10'
```

**Solutions**:
```bash
# Solution 1: Lower memory thresholds (force streaming earlier)
export SOURCEATLAS_MEMORY_WARNING_THRESHOLD=50000
export SOURCEATLAS_MEMORY_PREPARE_THRESHOLD=100000
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=200000

# Solution 2: Reduce worker count
export SOURCEATLAS_MAX_WORKERS=2

# Solution 3: Process in smaller chunks
split -l 50000 large_dataset.tsv chunk_
for chunk in chunk_*; do
    awk -f lib/batch_optimize.awk "$chunk" >> results.jsonl
done

# Solution 4: Force streaming mode from start
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=1  # Immediate streaming
```

#### Issue: Memory Warnings but No Streaming Switch
**Symptoms**:
- Frequent "Approaching memory limits" warnings
- Memory usage stays high without switching to streaming
- No "STREAMING_MODE_REQUIRED" signals generated

**Diagnosis**:
```bash
# Check streaming signals
ls -la .sourceatlas/processing_signals.txt
cat .sourceatlas/processing_signals.txt

# Check exit codes
echo $? # After running batch_optimize.awk

# Check AWK script for streaming logic
grep -n "exit(2)" lib/batch_optimize.awk
```

**Solutions**:
```bash
# Solution 1: Verify streaming logic
awk 'BEGIN{print "Testing streaming threshold"; exit(2)}' 
echo "Exit code: $?"  # Should be 2

# Solution 2: Manual streaming mode test
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=100
# Run on dataset with >100 records

# Solution 3: Check parent process handling
# Ensure parent script checks for exit code 2
if [[ $awk_exit -eq 2 ]]; then
    echo "Switching to streaming mode"
fi
```

### 3. Checkpoint/Recovery Issues

#### Issue: Checkpoint Files Not Created
**Symptoms**:
- No files in `.sourceatlas/checkpoints/`
- Process doesn't recover after interruption
- "No checkpoint found" messages

**Diagnosis**:
```bash
# Check checkpoint directory
ls -la .sourceatlas/checkpoints/

# Check checkpoint configuration
echo "Interval: $SOURCEATLAS_CHECKPOINT_INTERVAL"
echo "Retention: $SOURCEATLAS_CHECKPOINT_RETENTION"
echo "Emergency: $SOURCEATLAS_EMERGENCY_CHECKPOINT"

# Check permissions
ls -ld .sourceatlas/
ls -ld .sourceatlas/checkpoints/ 2>/dev/null || echo "Directory missing"
```

**Solutions**:
```bash
# Solution 1: Create checkpoint directory
mkdir -p .sourceatlas/checkpoints
chmod 755 .sourceatlas/checkpoints

# Solution 2: Enable checkpoints explicitly
export SOURCEATLAS_EMERGENCY_CHECKPOINT=true
export SOURCEATLAS_CHECKPOINT_INTERVAL=60

# Solution 3: Test checkpoint creation manually
source lib/parallel_optimize.sh
create_checkpoint ".sourceatlas/checkpoints/test.checkpoint" "/tmp" "4" "test-trace"

# Solution 4: Check disk space
df -h .sourceatlas/
```

#### Issue: Checkpoint Recovery Fails
**Symptoms**:
- "Failed to restore from checkpoint" errors
- Corrupted checkpoint files
- Process starts from beginning despite checkpoint

**Diagnosis**:
```bash
# Check checkpoint file integrity
for checkpoint in .sourceatlas/checkpoints/*.checkpoint; do
    echo "=== $checkpoint ==="
    head -10 "$checkpoint"
    echo "Valid format: $(grep -c '^TRACE_ID=' "$checkpoint")"
done

# Check checkpoint age
find .sourceatlas/checkpoints/ -name "*.checkpoint" -mtime +1
```

**Solutions**:
```bash
# Solution 1: Clean old/corrupted checkpoints
find .sourceatlas/checkpoints/ -name "*.checkpoint" -mtime +7 -delete

# Solution 2: Validate checkpoint format
for checkpoint in .sourceatlas/checkpoints/*.checkpoint; do
    if ! grep -q "^TRACE_ID=" "$checkpoint"; then
        echo "Removing invalid checkpoint: $checkpoint"
        rm -f "$checkpoint"
    fi
done

# Solution 3: Manual checkpoint creation
cat > .sourceatlas/checkpoints/manual.checkpoint << EOF
# SourceAtlas Checkpoint
TRACE_ID=manual-recovery-$(date +%s)
STATUS=RUNNING
TIMESTAMP=$(date +%s)
TOTAL_WORKERS=4
WORKER_0_COMPLETED=0
WORKER_1_COMPLETED=0
WORKER_2_COMPLETED=0
WORKER_3_COMPLETED=0
EOF
```

### 4. Observability Issues

#### Issue: No Events Generated
**Symptoms**:
- Empty `.sourceatlas/events.jsonl` file
- No progress messages in stderr
- Missing observability data

**Diagnosis**:
```bash
# Check event configuration
echo "Events enabled: $SOURCEATLAS_EVENTS_ENABLED"
echo "Events file: $SOURCEATLAS_EVENTS_FILE"

# Check file permissions
ls -la .sourceatlas/events.jsonl

# Test event generation manually
echo '{"test":"event"}' >> .sourceatlas/events.jsonl
```

**Solutions**:
```bash
# Solution 1: Enable events explicitly
export SOURCEATLAS_EVENTS_ENABLED=true
mkdir -p .sourceatlas
touch .sourceatlas/events.jsonl

# Solution 2: Check stderr redirection
sourceatlas run 2>debug_stderr.log
grep "batch_optimize" debug_stderr.log

# Solution 3: Test event function
source lib/batch_optimize.awk  # Won't work - AWK functions
# Instead, test with small dataset
echo -e "test.js\t100\t10\thash\t12345" | awk -f lib/batch_optimize.awk
```

#### Issue: Metrics Not Exported
**Symptoms**:
- No `.sourceatlas/metrics.json` file
- Dashboard integration not working
- Missing performance data

**Diagnosis**:
```bash
# Check metrics configuration
source lib/phase9_config.sh
print_config_summary

# Check metrics system initialization
source lib/phase9_metrics.sh
echo "Counters file: $METRICS_COUNTERS"
ls -la "$METRICS_COUNTERS" 2>/dev/null || echo "Counters not initialized"
```

**Solutions**:
```bash
# Solution 1: Enable metrics system
export SOURCEATLAS_METRICS_ENABLED=true
source lib/phase9_metrics.sh
init_metrics

# Solution 2: Manual metrics collection
source lib/phase9_metrics.sh
record_counter "test_metric" 5
collect_and_export_metrics "json"

# Solution 3: Test dashboard integration
export SOURCEATLAS_DASHBOARD_ENABLED=true
export SOURCEATLAS_DASHBOARD_WEBHOOK="https://httpbin.org/post"  # Test endpoint
collect_and_export_metrics
```

### 5. Configuration Issues

#### Issue: Environment Variables Not Applied
**Symptoms**:
- Default values used despite setting environment variables
- Configuration doesn't match expected settings
- Settings not persisting between runs

**Diagnosis**:
```bash
# Check current environment
env | grep SOURCEATLAS_

# Check configuration loading
source lib/phase9_config.sh
echo "Config loaded, max workers: $SOURCEATLAS_MAX_WORKERS"

# Test specific variable
echo "Test: $SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD"
```

**Solutions**:
```bash
# Solution 1: Export variables properly
export SOURCEATLAS_MAX_WORKERS=8
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=300000

# Source configuration after setting
source lib/phase9_config.sh

# Solution 2: Create configuration file
generate_sample_config ~/.sourceatlas/config
# Edit the generated file with your settings

# Solution 3: Validate configuration
validate_config && echo "Config OK" || echo "Config errors"

# Solution 4: Override in script
cat > custom_config.sh << 'EOF'
#!/bin/bash
export SOURCEATLAS_MAX_WORKERS=12
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=400000
source lib/phase9_config.sh
EOF

source custom_config.sh
```

## 🔍 Advanced Debugging

### Trace Analysis
```bash
# Extract processing timeline
jq -r '. | "\(.timestamp) \(.event) \(.message)"' .sourceatlas/events.jsonl

# Performance trend analysis  
jq -r 'select(.event=="batch_progress") | .message' .sourceatlas/events.jsonl | \
    grep -oE '[0-9.]+ files/sec'

# Memory usage trend
jq -r 'select(.event | contains("memory")) | "\(.timestamp) \(.message)"' .sourceatlas/events.jsonl
```

### System Resource Analysis
```bash
# CPU usage by workers
ps -eo pid,ppid,cmd,%cpu,%mem | grep batch_optimize

# Memory usage over time
while true; do
    echo "$(date): $(ps -o pid,rss,cmd | grep sourceatlas | awk '{sum+=$2} END {print sum/1024 " MB"}')"
    sleep 5
done

# I/O analysis
iostat -x 1 | grep -A 20 "Device"
```

### Network Issues (Dashboard Integration)
```bash
# Test webhook connectivity
curl -X POST -H "Content-Type: application/json" \
    -d '{"test":"connectivity"}' \
    "$SOURCEATLAS_DASHBOARD_WEBHOOK"

# Check SSL/TLS issues
curl -v "$SOURCEATLAS_DASHBOARD_WEBHOOK" 2>&1 | grep -i tls

# Test with reduced timeout
timeout 10 curl "$SOURCEATLAS_DASHBOARD_WEBHOOK"
```

## 📞 Getting Help

### Diagnostic Information to Collect
```bash
# System information
echo "=== System Info ===" > diagnostic.txt
uname -a >> diagnostic.txt
df -h >> diagnostic.txt
free -h >> diagnostic.txt

# Configuration
echo "=== Configuration ===" >> diagnostic.txt
env | grep SOURCEATLAS_ >> diagnostic.txt

# Recent events
echo "=== Recent Events ===" >> diagnostic.txt  
tail -50 .sourceatlas/events.jsonl >> diagnostic.txt

# Metrics
echo "=== Metrics ===" >> diagnostic.txt
cat .sourceatlas/metrics.json >> diagnostic.txt 2>/dev/null || echo "No metrics file" >> diagnostic.txt

# Send diagnostic.txt when reporting issues
```

### Performance Baseline Testing
```bash
# Create baseline performance test
./test_phase9_functionality.sh > baseline_results.txt 2>&1

# Compare with previous baseline
diff baseline_results.txt previous_baseline.txt
```

---

For additional support:
- Check [PERFORMANCE.md](./PERFORMANCE.md) for optimization guidance
- Enable verbose logging: `SOURCEATLAS_PROGRESS_VERBOSE=true`  
- Review [Phase 9 configuration reference](../lib/phase9_config.sh)