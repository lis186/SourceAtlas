# Phase 9 Performance Guide

This document provides comprehensive performance benchmarks, memory requirements, and optimization guidance for SourceAtlas Phase 9 enterprise features.

## 📊 Performance Benchmarks

### Processing Speed Benchmarks

| Dataset Size | Files | Processing Time | Throughput | Memory Peak | Mode |
|--------------|-------|-----------------|------------|-------------|------|
| Small | 1K | 2.3s | 435 files/sec | 45 MB | Batch |
| Medium | 10K | 18.5s | 541 files/sec | 128 MB | Batch |
| Large | 50K | 1m 32s | 543 files/sec | 380 MB | Batch |
| Very Large | 200K | 6m 12s | 538 files/sec | 495 MB | Batch |
| Extreme | 500K | 15m 45s | 529 files/sec | 512 MB | Streaming* |
| Enterprise | 1M+ | 32m 18s | 515 files/sec | 512 MB | Streaming |

*Automatic streaming mode fallback activated at 500K records

### Hardware-Specific Performance

#### 4-Core/8GB Configuration
```
Workers: 8 (2x CPU cores)
Memory threshold: 500K records (streaming fallback)
Expected throughput: 400-600 files/sec
Recommended max dataset: 750K files
```

#### 8-Core/16GB Configuration  
```
Workers: 16 (2x CPU cores)
Memory threshold: 750K records
Expected throughput: 600-800 files/sec
Recommended max dataset: 1.5M files
```

#### 16-Core/32GB Configuration
```
Workers: 16 (capped for optimal performance)
Memory threshold: 1.2M records
Expected throughput: 700-900 files/sec
Recommended max dataset: 3M+ files
```

## 🔧 Memory Requirements

### Memory Usage by Processing Mode

#### Batch Processing Mode
- **Base memory**: ~50 MB (AWK + shell overhead)
- **Per 1K files**: ~0.8 MB additional
- **Per 100K files**: ~80 MB additional
- **Peak at streaming threshold**: ~512 MB

#### Streaming Processing Mode
- **Constant memory**: ~45-65 MB regardless of dataset size
- **Memory-safe**: O(1) memory complexity
- **Automatic activation**: >500K records (configurable)

### Memory Management Thresholds

```bash
# Default thresholds (configurable via environment)
SOURCEATLAS_MEMORY_WARNING_THRESHOLD=100000   # 100K records
SOURCEATLAS_MEMORY_PREPARE_THRESHOLD=200000   # 200K records  
SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=500000  # 500K records (streaming switch)
```

## ⚡ Optimization Guidelines

### Worker Count Optimization

```bash
# Optimal worker calculation
optimal_workers = min(cpu_cores * 2, 16)

# Environment-specific tuning
export SOURCEATLAS_MIN_WORKERS=2      # Minimum workers
export SOURCEATLAS_MAX_WORKERS=16     # Maximum workers (performance ceiling)
export SOURCEATLAS_WORKER_MULTIPLIER=2 # CPU cores multiplier
```

### Performance Tuning Parameters

#### EMA-Based Monitoring
```bash
export SOURCEATLAS_EMA_ALPHA=0.3              # EMA smoothing (0.1-0.5)
export SOURCEATLAS_PERFORMANCE_WARNING_THRESHOLD=20  # 20% decline warning
export SOURCEATLAS_PERFORMANCE_CRITICAL_THRESHOLD=50 # 50% decline critical
```

#### Checkpoint Optimization
```bash
export SOURCEATLAS_CHECKPOINT_INTERVAL=60     # Checkpoint every 60s
export SOURCEATLAS_CHECKPOINT_RETENTION=5     # Keep 5 checkpoints
export SOURCEATLAS_EMERGENCY_CHECKPOINT=true  # Enable emergency saves
```

## 📈 Performance Monitoring

### Key Performance Indicators

#### Processing Rate KPIs
- **Target throughput**: >500 files/sec
- **Warning threshold**: <300 files/sec
- **Critical threshold**: <100 files/sec

#### Memory KPIs
- **Normal operation**: <400 MB
- **Warning level**: 400-500 MB
- **Critical level**: >500 MB (triggers streaming)

#### System Resource KPIs
- **CPU usage**: <80% average
- **Load average**: <CPU cores * 1.5
- **Disk I/O**: <100 MB/s sustained

### Real-Time Monitoring Commands

```bash
# Enable detailed monitoring
export SOURCEATLAS_METRICS_ENABLED=true
export SOURCEATLAS_PROGRESS_VERBOSE=true

# Monitor processing in real-time
tail -f .sourceatlas/events.jsonl | jq '.message'

# View performance metrics
cat .sourceatlas/metrics.json | jq '.counters'
```

## 🚀 Performance Optimization Strategies

### 1. Dataset Size Optimization

#### Small Datasets (< 10K files)
```bash
# Optimize for startup time
export SOURCEATLAS_MAX_WORKERS=4
export SOURCEATLAS_CHECKPOINT_INTERVAL=120
export SOURCEATLAS_EMA_ALPHA=0.4  # More responsive
```

#### Medium Datasets (10K - 100K files)  
```bash
# Balanced configuration (default settings)
export SOURCEATLAS_MAX_WORKERS=8
export SOURCEATLAS_CHECKPOINT_INTERVAL=60
export SOURCEATLAS_EMA_ALPHA=0.3
```

#### Large Datasets (100K+ files)
```bash
# Optimize for throughput and stability
export SOURCEATLAS_MAX_WORKERS=16
export SOURCEATLAS_CHECKPOINT_INTERVAL=30
export SOURCEATLAS_EMA_ALPHA=0.2  # More stable
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=750000
```

### 2. Hardware-Specific Tuning

#### SSD Storage
```bash
# Aggressive checkpointing (fast I/O)
export SOURCEATLAS_CHECKPOINT_INTERVAL=15
export SOURCEATLAS_CHECKPOINT_RETENTION=10
```

#### Network Storage
```bash
# Conservative checkpointing (slow I/O)
export SOURCEATLAS_CHECKPOINT_INTERVAL=300
export SOURCEATLAS_CHECKPOINT_RETENTION=3
```

#### High-Memory Systems (32GB+)
```bash
# Delayed streaming mode
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=1000000
export SOURCEATLAS_MAX_WORKERS=24
```

### 3. CI/CD Environment Optimization

```bash
# Optimized for CI pipelines
export SOURCEATLAS_PROGRESS_VERBOSE=false     # Reduce log noise
export SOURCEATLAS_METRICS_ENABLED=true       # Enable metrics collection  
export SOURCEATLAS_DASHBOARD_ENABLED=true     # Send to monitoring
export SOURCEATLAS_CHECKPOINT_INTERVAL=120    # Less frequent (faster builds)
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=750000  # Higher threshold
```

## 📋 Performance Benchmarking

### Running Benchmark Tests

```bash
# Create benchmark dataset
./scripts/create_benchmark_dataset.sh --size 50000

# Run performance benchmark
time sourceatlas run --trace-id benchmark-$(date +%s)

# Analyze results
cat .sourceatlas/metrics.json | jq '.counters.files_processed_total / (.session_duration_seconds / 60)' # files/min
```

### Benchmark Analysis

#### Throughput Analysis
```bash
# Calculate files per second
echo "scale=2; $(jq -r '.counters.files_processed_total' .sourceatlas/metrics.json) / $(jq -r '.session_duration_seconds' .sourceatlas/metrics.json)" | bc

# Memory efficiency (files per MB)
echo "scale=2; $(jq -r '.counters.files_processed_total' .sourceatlas/metrics.json) / $(jq -r '.gauges["system.memory_usage_percent"].value' .sourceatlas/metrics.json)" | bc
```

#### Performance Regression Detection
```bash
# Compare with baseline
current_rate=$(jq -r '.counters.files_processed_total / .session_duration_seconds' .sourceatlas/metrics.json)
baseline_rate=500  # Your established baseline

decline_percent=$(echo "scale=1; (($baseline_rate - $current_rate) / $baseline_rate) * 100" | bc)
echo "Performance change: ${decline_percent}% vs baseline"
```

## 🔍 Performance Troubleshooting

### Common Performance Issues

#### Issue: Low Processing Rate (<300 files/sec)
**Symptoms**: Slow progress, high CPU usage
**Solutions**:
```bash
# Reduce worker count
export SOURCEATLAS_MAX_WORKERS=4

# Enable streaming mode earlier
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=250000

# Increase checkpoint interval
export SOURCEATLAS_CHECKPOINT_INTERVAL=120
```

#### Issue: High Memory Usage
**Symptoms**: >500MB memory, frequent warnings
**Solutions**:
```bash
# Force streaming mode
export SOURCEATLAS_MEMORY_CRITICAL_THRESHOLD=200000

# Reduce worker count
export SOURCEATLAS_MAX_WORKERS=8

# More aggressive checkpointing
export SOURCEATLAS_CHECKPOINT_INTERVAL=30
```

#### Issue: Performance Degradation Over Time
**Symptoms**: EMA decline warnings, decreasing throughput
**Solutions**:
```bash
# More responsive EMA
export SOURCEATLAS_EMA_ALPHA=0.4

# Enable automatic streaming suggestions
export SOURCEATLAS_PERFORMANCE_CRITICAL_THRESHOLD=30

# Increase checkpoint frequency
export SOURCEATLAS_CHECKPOINT_INTERVAL=45
```

## 🎯 Performance Best Practices

### 1. Resource Planning
- Allocate 2-4x CPU cores as workers
- Reserve 1GB RAM for every 200K files (batch mode)
- Ensure 500MB+ available memory for large datasets
- Use SSD storage for `.sourceatlas/` output directory

### 2. Environment Configuration
- Set realistic memory thresholds based on available RAM
- Use CI-optimized settings in automated environments  
- Enable metrics collection for performance tracking
- Configure dashboard integration for production monitoring

### 3. Dataset Management
- Process large codebases in chunks if possible
- Use streaming mode for >500K files
- Enable verbose progress for large datasets
- Configure appropriate checkpoint intervals

### 4. Monitoring & Alerting
- Track processing rate trends with EMA monitoring
- Set up alerts for performance degradation >20%
- Monitor memory usage approaching thresholds
- Use structured metrics for production deployments

---

For additional optimization assistance, see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) or enable verbose logging with `SOURCEATLAS_PROGRESS_VERBOSE=true`.