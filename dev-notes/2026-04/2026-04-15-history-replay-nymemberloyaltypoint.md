# History-Replay: NYMemberLoyaltyPointCenterVC ObjC→Swift Migration

**Date**: 2026-04-15
**Branch**: `feature/atlas-refactor-playbook`
**Method**: B (history-replay) — checkout pre-migration commit, run `/atlas.refactor`,
compare its recommendation to what real engineers actually did.

## Setup

- **Migration commit**: `352713944b` (2026-03-30) by NaiYuWang
  - Title: *feat: make NYMemberLoyaltyPointCenterVC from objc to swift*
  - `.m` (638 lines) deleted, `.swift` (664 lines) added in a single commit
- **Pre-migration HEAD**: `bcfa334a78` (parent of the migration commit)
- **Worktree**: `/Users/justinlee/dev/test_targets/nineyiappshop-pre-migration`
- **Skill**: `pilot-run.sh` from sourceatlas2 (current branch)

## What the skill recommended

Phase: **1.5** (1 test file referencing the module)
Heuristic: **smallest zone with fewest deps** (Feathers' easiest-first)
First slice:

```yaml
recommended_zone:
  id: "dynamicheightlistviewcontrollerlayout"
  name: "DynamicHeightListViewControllerLayout"
  lines: [612, 617]
  line_count: 6
  dep_count: 1
```

Strategy: write a characterization test for that 6-line zone, then move outward.

## What NaiYuWang actually did

git history shows the migration was the *third* step of a multi-commit plan:

1. **(earlier)** `a39a1c756b` — *feat: new NYMemberLoyaltyPointCenterSummaryView*
   → Extracted a sub-view to its own file (cross-file seam, before any rewrite).
2. **(earlier)** `b7f108b019` — *feat: replace xib to codes for LoyaltyPointCenterVC UI*
   → Removed the xib so the VC no longer depends on IB string-dispatch.
3. **(2026-03-30)** `352713944b` — *make .m to swift*
   → Single-commit full rewrite, **no characterization tests added**.

Verified: `git log -- "*MemberLoyaltyPoint*Test*"` returns empty — **no XCTest
exists for this VC at any point in history**.

## Where the strategies diverge

| | Skill said | Reality |
|---|---|---|
| First action | Write a characterization test on a 6-line internal zone | Extract a sub-view to its own file |
| Safety net | Test-first | Structural debt removal first (xib → code) |
| Final step | Multi-step incremental seams | Single-commit full rewrite |

Both approaches are *valid Feathers moves* — but the skill's heuristic always
picks "test-first easiest zone", and that's wrong when:

- The target is a UIViewController with **0 existing tests**
- Adding a characterization test means stubbing the entire UIKit lifecycle
- Real path of least edit-distance is **removing IB / extracting sub-views**

## Insights worth keeping

1. **Test-first heuristic assumes tests are cheap to add.** For UI code with no
   existing test scaffolding, that assumption breaks. Skill should detect "0
   tests on a UIViewController" and switch heuristic.

2. **Skill doesn't know about cross-file seams.** Real engineers reduce surface
   area by extracting sub-views into separate files *before* rewriting the
   container. Skill only ranks zones *within* the target file.

3. **xib / storyboard removal is a seam-equivalent action.** Removing IB
   bindings breaks string-dispatch dependencies — equivalent in safety value to
   extracting a Java seam, but skill never proposes it.

4. **History-replay > adding more codebases for evaluation.** A 4th codebase
   would have surfaced more grep edge cases. This single replay surfaced
   *strategic* gaps in the skill's heuristic, which is far more valuable.

## Concrete suggestions for the skill

| Suggestion | Where |
|---|---|
| When `phase` ≤ 1.5 AND target is `UIViewController` AND `0` tests, warn that test-first may not be the cheapest path; suggest sprout-class / sub-view extraction | `pilot-run.sh` Recommended First Slice |
| Detect `.xib` / storyboard scenes referencing the target; recommend removing IB bindings before language migration | `runtime-hidden-deps.sh` IB section + new pilot section |
| Look for sub-types defined inside the target file (large nested classes / structs) and propose them as cross-file extraction candidates | `detect-zones.sh` could classify zones by "extractable as new file" |
| Add a `confidence` field to the recommended slice — small line count is necessary but not sufficient for "easy" | `pilot-run.sh` |

## Next

Find more migration commits in nineyiappshop history; verify whether the
"sub-view extraction → IB removal → rewrite" pattern is consistent across
the team's migrations.

## Artifacts

- Pilot report: `/Users/justinlee/dev/refactor_harness/history-replay/pre-migration-pilot.md`
- Worktree: `/Users/justinlee/dev/test_targets/nineyiappshop-pre-migration`
  (cleanup with `git worktree remove`)
