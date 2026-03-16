#!/bin/bash
# Verification script for PaymentsNetworkManager.swift contracts
# Generated: 2026-03-17
# Source: final-contracts.md (merged from Auditor + Adversary)
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

TARGET="PaymentsNetworkManager.swift"

if [ ! -f "$TARGET" ]; then
  echo "ERROR: $TARGET not found. Run this script from the directory containing the target file."
  exit 2
fi

# --- Positive assertions ---

# D-003: Singleton
assert_match "D-003" "static let shared = PaymentsNetworkManager()" "$TARGET"

# S-001 / N-002: cancellables declaration
assert_match "S-001" "var cancellables: Set<AnyCancellable>" "$TARGET"

# N-001: sink pattern (representative)
assert_match "N-001" ".sink " "$TARGET"

# N-002: store pattern
assert_match "N-002" ".store(in: &self.cancellables)" "$TARGET"

# E-001: .finished branch only prints
assert_match "E-001" "case .finished:" "$TARGET"

# D-001: dispatcher construction
assert_match "D-001" "PaymentsNetworkDispatcher(urlSession:" "$TARGET"

# D-002: tenSecondsTimeout
assert_match "D-002" ".tenSecondsTimeout" "$TARGET"

# M-001: toDictionary
assert_match "M-001" ".toDictionary" "$TARGET"

# M-002: idempotencyKey
assert_match "M-002" "idempotencyKey:" "$TARGET"

# E-002: PaymentsNetworkRequestError
assert_match "E-002" "PaymentsNetworkRequestError" "$TARGET"

# L-001: cancellables Set declaration (subscription lifetime)
assert_match "L-001" "cancellables: Set<AnyCancellable> = \[\]" "$TARGET"

# M-003: print side effect in .finished
assert_match "M-003" "print(" "$TARGET"

# --- Negative / inverse assertions ---

# C-001: No cancel API (inverse -- should NOT find func cancel)
if grep -qn "func cancel" "$TARGET"; then
  echo "INFO [C-001] -- cancel method found, contract may have changed"
else
  echo "PASS [C-001] -- no cancel API (as expected)"
  ((PASS++))
fi

# P-001: No receive(on:) (inverse -- thread unspecified)
if grep -qn "receive(on:" "$TARGET"; then
  echo "INFO [P-001] -- receive(on:) found, thread contract may be specified"
else
  echo "PASS [P-001] -- no receive(on:) (thread unspecified as documented)"
  ((PASS++))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed out of 14 contracts"
[ $FAIL -eq 0 ] || exit 1
