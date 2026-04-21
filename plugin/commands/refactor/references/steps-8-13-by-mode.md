# Steps 8–13 by Migration Mode

This document provides mode-specific variants for Steps 8–13 of the Playbook.
The main `SKILL.md` table shows the `seam-injection` (default) path.
For other modes, refer to the appropriate section below.

> **How to use**: Check `state.yaml → migration_mode.mode_name`. Then jump to that mode's section.

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

The `{Name}ShadowLogger` protocol is minimal by design — the playbook does not dictate the logging backend. Common implementations:

```swift
// Minimal: print to console during development
class ConsoleShadowLogger: CryptoShadowLogger {
    func shadow(method: String, primary: Any?, shadow: Any?, matched: Bool) {
        if !matched { print("[SHADOW MISMATCH] \(method): \(primary ?? "nil") vs \(shadow ?? "nil")") }
    }
}

// Production: structured logging (Datadog, Firebase, os_log)
class AnalyticsShadowLogger: CryptoShadowLogger {
    func shadow(method: String, primary: Any?, shadow: Any?, matched: Bool) {
        Analytics.log("shadow_compare", ["method": method, "matched": matched])
    }
}
```

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
