# Steps 8–13 by Migration Mode

This document provides mode-specific variants for Steps 8–13 of the Playbook.
The main `SKILL.md` table shows the `seam-injection` (default) path.
For other modes, refer to the appropriate section below.

> **How to use**: Check `state.yaml → migration_mode.mode_name`. Then jump to that mode's section.

> **All modes**: whatever the mode, the final cleanup step (Step 12 in `seam-injection` / `platform-migration` / `platform-strangler`; after all zones are done in `strangler-fig`) also runs `gate-postswap.sh --step 12 [--impl-file <new-file>]` to record structural metrics into `12_metrics.yaml`. Metrics are evidence, not a gate — see the verification boundary note in [SKILL.md](../SKILL.md).

---

## Mode: `seam-injection` (default)

Check `5_interface.yaml → swap_strategy` for the sub-path:

- **`direct`** — see the standard table in [SKILL.md](../SKILL.md).
- **`shadow`** — see the shadow table in [SKILL.md](../SKILL.md) (Steps 9a / 9b / 9c replace Step 9).

### When to choose shadow

Use shadow when the dependency being replaced has **output correctness requirements** that unit tests alone cannot guarantee:

| Signal | Example |
|--------|---------|
| Encryption / decryption output must be byte-for-byte identical | `CocoaSecurity → CryptoSwift` |
| Hash output must be identical across all inputs | SHA-256, HMAC implementations |
| Serialisation format must be wire-compatible | JSON codec, Protobuf encoder |
| Novel input distribution only observable in production | ML inference, user-generated content |

Do **not** use shadow if:
- Methods have side effects that are unsafe to run twice (network calls, DB writes, billing)
- The interface is too thin to produce meaningful comparison data (e.g. pure DI container)
- Unit tests can exhaustively cover the input space

### Shadow logger implementation guidance

The `{Name}ShadowLogger` protocol is minimal by design — the playbook does not dictate the logging backend. Pick one of the patterns below based on infra you already have.

#### Pattern 1: Console (development only)

```swift
class ConsoleShadowLogger: CryptoShadowLogger {
    func shadow(method: String, primary: Any?, shadow: Any?, matched: Bool) {
        if !matched { print("[SHADOW MISMATCH] \(method): \(primary ?? "nil") vs \(shadow ?? "nil")") }
    }
}
```

#### Pattern 2: os_log (Apple unified logging — production-safe, no extra dep)

```swift
import os.log

class OSLogShadowLogger: CryptoShadowLogger {
    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "shadow", category: "Crypto")
    func shadow(method: String, primary: Any?, shadow: Any?, matched: Bool) {
        os_log(matched ? .info : .error,
               log: log,
               "%{public}@ matched=%{public}@",
               method, String(matched))
    }
}
```
View in Console.app filtering by your subsystem; or `log show --predicate 'subsystem == "..."'`.

#### Pattern 3: Firebase Analytics (mobile, free tier OK for low volume)

```swift
import FirebaseAnalytics

class FirebaseShadowLogger: CryptoShadowLogger {
    func shadow(method: String, primary: Any?, shadow: Any?, matched: Bool) {
        Analytics.logEvent("shadow_compare", parameters: [
            "method": method,
            "matched": matched,
        ])
    }
}
```

#### Pattern 4: Datadog (custom metric — preferred when you already have Datadog SDK)

```swift
import DatadogRUM

class DatadogShadowLogger: CryptoShadowLogger {
    func shadow(method: String, primary: Any?, shadow: Any?, matched: Bool) {
        RUMMonitor.shared().addUserAction(type: .custom, name: "shadow_compare", attributes: [
            "method": method,
            "matched": matched,
        ])
    }
}
```

#### Pattern 5: Sentry (error-tracking-shaped infra, useful when mismatch == bug)

```swift
import Sentry

class SentryShadowLogger: CryptoShadowLogger {
    func shadow(method: String, primary: Any?, shadow: Any?, matched: Bool) {
        if !matched {
            SentrySDK.capture(message: "shadow_mismatch:\(method)") { scope in
                scope.setTag(value: method, key: "shadow_method")
                // Avoid logging primary/shadow values directly if they contain PII or secrets.
            }
        }
    }
}
```

### Sampling / volume control

Shadow runs every method twice. For high-frequency methods (called per-frame, per-tap), the log volume can swamp your infra.

**Rule of thumb**: if the method is called > 100×/min, sample at 1–10%. Below that, log every call.

```swift
class SampledShadowLogger: CryptoShadowLogger {
    private let sampleRate: Double
    private let inner: CryptoShadowLogger
    init(inner: CryptoShadowLogger, sampleRate: Double = 0.01) {
        self.inner = inner
        self.sampleRate = sampleRate
    }
    func shadow(method: String, primary: Any?, shadow: Any?, matched: Bool) {
        // Always log mismatches (rare → safe to keep verbose);
        // sample matches at sampleRate (frequent → reduce volume).
        if !matched || Double.random(in: 0..<1) < sampleRate {
            inner.shadow(method: method, primary: primary, shadow: shadow, matched: matched)
        }
    }
}
```

### Match-rate dashboard

The S9b "Monitor Shadow Period" gate compares against `shadow_config.threshold` from `5_interface.yaml`. Build a dashboard that reports:

| Metric | Source | Pass threshold (default) |
|--------|--------|--------------------------|
| `match_rate_pct` | matched count / total count | ≥ 99.9% |
| `mismatch_count` | non-matched events | flat or decreasing trend |
| `total_samples` | total events for method | ≥ 1000 |
| `days_observed` | first event timestamp → now | ≥ 7 |

Group by `method` so you can see if one method is dragging down the aggregate. A single buggy method that mismatches 50% will show up clearly.

For OSLog: build a query in Console.app or pipe `log show` to a script.
For Firebase: BigQuery export → SQL aggregation.
For Datadog: log-based metric on `shadow_compare` event, faceted by `matched` and `method`.
For Sentry: Issues view filtered by `shadow_mismatch:*` tag.

### PII / secrets warning

If the methods being shadowed handle credentials, encryption keys, user tokens, or PII:

- **Do not log `primary` / `shadow` values directly** — pattern 5 (Sentry) shows this. Log only the method name and the matched boolean.
- For crypto methods, if mismatch occurs, log a hash of inputs (e.g. SHA-256 truncated to 8 chars) so you can correlate without exposing the secret.

Delete the logger implementation file in Step 12 after hard swap.

---

## Mode: `platform-migration`

Platform-prescribed migration (e.g. UIKit Scene Lifecycle per TN3187, SwiftUI App protocol).
The target interface is defined by Apple/Google — no new implementation file to design.

| Step | Start From | Do (concrete actions) | Done When |
|------|------------|-----------------------|-----------|
| 8 — Implement in Platform File | `S_strangler_plan.yaml` + `4_tests` | For each zone with `to_slot` filled: implement the target platform method. No new file — work directly in the platform-defined file (e.g. `SceneDelegate.swift`). Do not import or call the legacy class. | All `to_slot` methods implemented; spike tests still green; `grep -c "TODO" S_strangler_plan.yaml` returns 0 |
| 9 — Wire Platform Entry Point | Platform file + `Info.plist` (iOS) or `AndroidManifest.xml` | Declare the platform lifecycle adoption: add `UIApplicationSceneManifest` to `Info.plist` (iOS scenes), or update `@main` / manifest entry. This is the **single** wiring commit. | App launches and routes through the new platform class; `gate-platform-migration.sh` `target_implemented` = pass |
| 10 — Run Platform Gate | Wired app + `7_gate_results.yaml` (baseline) | Re-run `gate-platform-migration.sh`. Diff all three sections (legacy_removed / target_implemented / no_double_dispatch) against baseline. | Gate output: all three sections pass; no new failures vs baseline |
| 11 — Integration Testing | Gate-verified app | Run full test suite; manually exercise every user-facing flow that previously touched the legacy delegate; check that deep links / push / handoff still work (they have their own migration slots). | Full suite green; manual flows pass; no crash on background/foreground cycle |
| 12 — Clean Up Legacy Delegate | Integrated app from Step 11 | Remove migrated methods from legacy delegate file (leave only what has no platform equivalent, e.g. `applicationWillTerminate:`). Remove `window` property from AppDelegate (iOS scenes). Run `grep -rn "rootViewController" AppDelegate.m` → 0 hits. | `gate-platform-migration.sh` `legacy_removed` = pass; full suite green |
| 13 — Delete Legacy File (if fully empty) | Cleaned codebase | If legacy delegate file has 0 migrated methods remaining (only scaffolding): delete it, update `@UIApplicationMain` / `@main` annotation. Else keep the shell. Final full-suite run. | `grep -r "AppDelegate" —include="*.swift"` returns only test references or zero; full suite green; deletion in its own commit |

> **Reference**: [TN3187 — Migrating to UIKit Scene-Based Life Cycle](https://developer.apple.com/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle)

---

## Mode: `strangler-fig`

Pure responsibility migration, no platform-prescribed interface. Developer designs where logic goes.

| Step | Start From | Do (concrete actions) | Done When |
|------|------------|-----------------------|-----------|
| 8 — Write Zone Implementation | `5_interface.{ext}` + `S_strangler_plan.yaml` + `4_tests` | For the **current zone only**: create a new class/module implementing the Seam Interface. No imports of the legacy class. Work one zone at a time per `S_strangler_plan.yaml` order. | New file compiles; unit tests green; `grep -l "<LegacyClass>" <new-file>` = 0 hits; update `S_strangler_plan.yaml` zone status → done |
| 9 — Swap One Zone | New impl + `recommended_seam.enabling_point` | Replace the LegacyAdapter with the new implementation **at the single injection site for this zone**. Single-file, single-line wiring commit per zone. | Characterization tests pass; zone status in plan = done |
| 10 — Run Zone Gate | Swapped zone + baseline | Re-run `gate-strangler.sh --zone <zone-id>`. Check zone's `legacy_removed` + `new_implemented` pass. | Zone gate passes; no regression in other zones |
| 11 — Integration Testing (per zone) | Verified zone swap | Run full suite; manually exercise user-facing flows for this zone's responsibility. Confirm no regression in adjacent zones. | Full suite green; no adjacent zone regressions |
| 12 — Repeat for next zone | `S_strangler_plan.yaml` (next pending zone) | Return to Step 8 for the next zone. Continue until all zones are `status: done`. | All zones in `S_strangler_plan.yaml` are `status: done`; `gate-strangler.sh` overall = pass |
| 13 — Delete Legacy | All zones done | `grep -r "<LegacyClassName>"` → 0 refs; delete legacy file; final full-suite run. | Legacy file deleted; full suite green; own commit |

---

## Mode: `platform-strangler`

Combination: platform-prescribed interface **and** zone-by-zone migration (legacy file is large enough that all zones cannot move in a single commit).

This mode follows the `platform-migration` Steps 8–9 approach (implement in platform file, wire via Info.plist/manifest) but **one zone at a time**, tracked via `S_strangler_plan.yaml`.

| Step | Start From | Do | Done When |
|------|------------|-----|-----------|
| 8 — Implement one zone in platform file | `S_strangler_plan.yaml` (pick first pending zone) + `4_tests` | Implement the single `to_slot` method for this zone in the platform file. No wiring yet — just the implementation. | Method exists; spike tests pass for this zone |
| 9 — Wire incrementally | Platform file + Info.plist | If this is the **first** zone: add the UIApplicationSceneManifest / manifest entry. For subsequent zones: wiring is already in place, just verify the new method is reached by running a targeted UI test. | `gate-platform-migration.sh` `target_implemented` passes for this zone |
| 10–12 — Same as `platform-migration` Step 10–12 but scoped to the current zone | (see platform-migration) | Repeat per zone until `S_strangler_plan.yaml` is complete. | All zones done; gate overall = pass |
| 13 — Delete legacy | All zones done | Same as platform-migration Step 13. | Legacy file cleaned or deleted; full suite green |

---

## Gate scripts by mode

| Mode | Step 7 script | Notes |
|------|--------------|-------|
| `seam-injection` | `gate-step7.sh` | Standard: spike + characterization tests + contract CI |
| `platform-migration` | `gate-platform-migration.sh` | Platform checks: legacy_removed + target_implemented + no_double_dispatch |
| `strangler-fig` | `gate-strangler.sh` | Per-zone: each `S_strangler_plan.yaml` entry verified |
| `platform-strangler` | `gate-platform-migration.sh` | Runs platform checks; also calls `gate-strangler.sh` internally for zone tracking |
