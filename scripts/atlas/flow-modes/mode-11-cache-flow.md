# Mode 11: Cache Flow Analysis

> Tier 3 | Trigger: "cache", "redis", "memoize", "TTL", "invalidate"

## Purpose

Analyze caching patterns in code flows, including cache hits/misses, invalidation strategies, and consistency issues.

## Analysis Steps

### Step 1: Find Cache Patterns

```bash
# Framework caching
grep -rn "@Cacheable\|@CacheEvict\|@CachePut" src/
grep -rn "cache\.get\|cache\.set\|cache\.del" src/

# Redis
grep -rn "redis\.\|ioredis\|RedisClient" src/

# Memcached
grep -rn "memcached\|Memcache" src/

# In-memory
grep -rn "memoize\|useMemo\|useCallback\|lru-cache" src/

# iOS
grep -rn "NSCache\|URLCache\|@Cached" Sources/
```

### Step 2: Trace Cache Flow

For each cached operation:
- What's the cache key?
- What's the TTL?
- What's the cache hit path?
- What's the cache miss path?
- What invalidates this cache?

## Output Format

```
{Operation} (Cache Analysis)
============================

1. {Entry Point}
   📍 {file}:{line}

2. Check Cache
   📍 {file}:{line}
   💾 Key: "{cache_key_pattern}"
   💾 Store: {Redis | Memcached | In-memory}
   💾 TTL: {duration}

   ┌─ [CACHE HIT] ────────────────┐
   │ → Return cached value        │
   │ ⏱️ ~{latency}                │
   └──────────────────────────────┘

   ┌─ [CACHE MISS] ───────────────┐
   │                              │
   │ 3. {Data fetch operation}    │
   │    📍 {file}:{line}          │
   │    💾 {SQL/API call}         │
   │    ⏱️ ~{latency}             │
   │                              │
   │ 4. {Cache write}             │
   │    📍 {file}:{line}          │
   │                              │
   └──────────────────────────────┘

───────────────────────────────────
📊 Cache Analysis:

Invalidation Points:
├── ✅ {Operation 1} - has @CacheEvict
├── ❌ {Operation 2} - NO invalidation!
└── ⚠️ {Operation 3} - partial invalidation

Consistency Risks:
├── {Risk 1}
└── {Risk 2}

Recommendations:
├── {Recommendation 1}
└── {Recommendation 2}
───────────────────────────────────
```

## Cache Patterns

### Read-Through (Lazy Loading)
```
Request → Check Cache → Miss → Load from DB → Store in Cache → Return
                     → Hit → Return cached
```

### Write-Through
```
Write → Update Cache → Update DB → Return
```

### Write-Behind (Write-Back)
```
Write → Update Cache → Return (async DB update later)
```

### Cache-Aside
```
Read: App checks cache, if miss, app loads from DB and writes to cache
Write: App updates DB, then invalidates/updates cache
```

## Common Issues

### 1. Missing Invalidation
```
⚠️ ProductService.updatePrice()
   Updates DB but doesn't invalidate cache
   📍 src/services/product.ts:180

   Fix: Add cache.del(`product:${id}:price`)
```

### 2. Cache Stampede
```
⚠️ High-traffic key with short TTL
   When cache expires, many requests hit DB simultaneously

   Fix: Use lock/mutex for cache refresh
        Or staggered TTL with jitter
```

### 3. Stale Read After Write
```
⚠️ Write to DB → Read from cache → Get stale data
   (Cache not yet updated)

   Fix: Invalidate before return, or use write-through
```

### 4. Unbounded Cache Growth
```
⚠️ In-memory cache without size limit
   Can cause OOM in long-running processes

   Fix: Use LRU cache with maxSize
```

## Output Example

```
Get Product Price (Cache Analysis)
==================================

1. ProductController.getPrice()
   📍 src/controllers/product.ts:45

2. Check Cache
   📍 src/services/cache.ts:30
   💾 Key: "product:{id}:price"
   💾 Store: Redis
   💾 TTL: 5 minutes

   ┌─ [CACHE HIT] ────────────────┐
   │ → Return cached price        │
   │ ⏱️ ~5ms                      │
   │ 📊 Est. hit rate: 85%        │
   └──────────────────────────────┘

   ┌─ [CACHE MISS] ───────────────┐
   │                              │
   │ 3. ProductRepository.find()  │
   │    📍 src/repos/product.ts:80│
   │    💾 SELECT price FROM ...  │
   │    ⏱️ ~50-100ms              │
   │                              │
   │ 4. CacheService.set()        │
   │    📍 src/services/cache.ts:45│
   │    💾 SET with 5min TTL      │
   │                              │
   └──────────────────────────────┘

───────────────────────────────────
📊 Invalidation Analysis:

Write Operations Found:
├── ✅ ProductService.updatePrice()
│   📍 src/services/product.ts:120
│   Has: @CacheEvict("product:{id}:price")

├── ❌ ProductService.bulkUpdate()
│   📍 src/services/product.ts:180
│   ⚠️ NO cache invalidation!
│   Risk: Stale prices after bulk update

├── ❌ Direct SQL UPDATE
│   📍 scripts/price-adjustment.sql
│   ⚠️ Bypasses ORM, cache not invalidated
│   Risk: Stale prices until TTL expires

───────────────────────────────────
⚠️ Consistency Risks:

1. Bulk Update Gap
   After bulkUpdate(), cache has old prices for up to 5 minutes

2. Direct SQL Risk
   Price adjustment scripts bypass cache entirely

3. Race Condition
   Between DB update and cache invalidation, some users
   may see old price while others see new

───────────────────────────────────
💡 Recommendations:

1. Add invalidation to bulkUpdate():
   await cache.del(`product:${id}:price`)

2. For bulk operations, use pattern delete:
   await cache.delPattern("product:*:price")

3. Consider shorter TTL (2 min) or event-driven invalidation

4. For scripts, add cache flush step:
   redis-cli KEYS "product:*:price" | xargs redis-cli DEL
───────────────────────────────────
```

## Trigger Keywords

Primary: `cache flow`, `caching`, `cache analysis`
Secondary: `redis`, `memoize`, `TTL`, `cache invalidation`, `cache miss`
