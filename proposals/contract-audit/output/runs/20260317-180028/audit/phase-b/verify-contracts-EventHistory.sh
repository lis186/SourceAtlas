#!/bin/bash
# verify-contracts-EventHistory.sh
# Generated: 2026-03-17
# Final merged verification script (Auditor + Adversary review)
# DEGRADED: no
set -e
PASS=0; FAIL=0
assert_match() {
  local id="$1" pattern="$2" file="$3"
  if grep -qn "$pattern" "$file"; then
    echo "PASS [$id]"; ((PASS++))
  else
    echo "FAIL [$id] -- pattern not found: $pattern"; ((FAIL++))
  fi
}

TARGET="EventHistory.ts"

# === Category M — Mutation ===

# M-001: Auto-timestamp in record creation
assert_match "M-001" "timestamp: Date.now()" "$TARGET"

# M-002: Cleanup uses retentionTime
assert_match "M-002" "cleanupExpiredRecords" "$TARGET"

# M-003: Clear all records
assert_match "M-003" "clearAllRecords" "$TARGET"

# M-004: updateOptions shallow merge without re-init
assert_match "M-004" "this.options = { ...this.options, ...newOptions }" "$TARGET"

# M-005: Default options in constructor
assert_match "M-005" "retentionTime: 300000" "$TARGET"

# === Category L — Lifecycle ===

# L-001: Idempotent init guard
assert_match "L-001" "if (this.isInitialized)" "$TARGET"

# L-002: Disabled early return in init
assert_match "L-002" "if (!this.options.enabled)" "$TARGET"

# L-003: startCleanupTimer called in init
assert_match "L-003" "this.startCleanupTimer()" "$TARGET"

# L-004: close stops timer then closes dbManager
assert_match "L-004" "this.stopCleanupTimer()" "$TARGET"

# L-005: isInitialized boolean field
assert_match "L-005" "private isInitialized = false" "$TARGET"

# === Category N — Notification ===

# N-001: Warning on sensitive DB option changes (ADD from Adversary)
assert_match "N-001" "資料庫名稱或版本變更需要重新初始化" "$TARGET"

# === Category E — Error Handling ===

# E-001: init re-throws
assert_match "E-001" "EventHistory 初始化失敗" "$TARGET"

# E-002: recordOperation swallows errors
assert_match "E-002" "記錄事件操作失敗" "$TARGET"

# E-003: queryRecords swallows errors
assert_match "E-003" "查詢事件記錄失敗" "$TARGET"

# E-004: getLatestPublishRecord swallows errors
assert_match "E-004" "獲取最新發布記錄失敗" "$TARGET"

# E-005: getStats swallows errors
assert_match "E-005" "獲取統計資訊失敗" "$TARGET"

# E-006: clear re-throws
assert_match "E-006" "清空記錄失敗" "$TARGET"

# E-007: cleanup swallows errors
assert_match "E-007" "清理過期記錄失敗" "$TARGET"

# E-008: Timer callback error handling (defensive catch)
assert_match "E-008" "定期清理失敗" "$TARGET"

# E-009: DatabaseManager.ensureDb throws -- cross-module, requires DatabaseManager.ts
# SKIP E-009 -- cross-module contract; verify in DatabaseManager audit or manually check DatabaseManager.ts:60

# === Category S — Synchronization ===

# S-001: Non-atomic init guard (structural)
assert_match "S-001" "await this.dbManager.init()" "$TARGET"

# S-002: setInterval for cleanup
assert_match "S-002" "setInterval" "$TARGET"

# S-003: close sets isInitialized false (race condition marker)
assert_match "S-003" "this.isInitialized = false" "$TARGET"

# S-004: Promise.all in DatabaseManager.getStats -- cross-module
# SKIP S-004 -- cross-module contract; verify in DatabaseManager audit or manually check DatabaseManager.ts:238

# === Category D — Dependency ===

# D-001: DatabaseManager instantiation
assert_match "D-001" "new DatabaseManager" "$TARGET"

# D-002: Logger import
assert_match "D-002" "import { logger } from" "$TARGET"

# D-003: IEventHistory interface
assert_match "D-003" "implements IEventHistory" "$TARGET"

# D-004: NodeJS.Timeout type annotation
assert_match "D-004" "NodeJS.Timeout" "$TARGET"

# D-005: Types import
assert_match "D-005" "from './types'" "$TARGET"

# === Category C — Cancellation ===

# C-001: clearInterval in stopCleanupTimer
assert_match "C-001" "clearInterval(this.cleanupTimer)" "$TARGET"

# C-002: No AbortSignal in any async method (structural absence)
# This is a negative assertion -- we verify NO AbortSignal exists
if grep -qn "AbortSignal\|AbortController" "$TARGET"; then
  echo "FAIL [C-002] -- AbortSignal/AbortController found (contract says none should exist)"
  ((FAIL++))
else
  echo "PASS [C-002] -- no AbortSignal/AbortController (confirms no in-flight cancellation)"
  ((PASS++))
fi

# === Category P — Propagation ===

# P-001: Guard pattern (representative check)
assert_match "P-001" "!this.isInitialized || !this.options.enabled" "$TARGET"

# P-002: Optional chaining on event
assert_match "P-002" "eventType: event?.type" "$TARGET"

# P-003: getStats fallback value
assert_match "P-003" "totalRecords: 0, channelCount: 0" "$TARGET"

# P-004: queryRecords passthrough (ADD from Adversary)
assert_match "P-004" "return await this.dbManager.queryRecords" "$TARGET"

echo ""
echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="
echo "Skipped: E-009 (cross-module), S-004 (cross-module)"
[ $FAIL -eq 0 ] || exit 1
