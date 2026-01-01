# Flow Modes Index

External mode files for `/atlas.flow` tiered architecture.

## Tier 2: Common Modes

| Mode | File | Trigger Keywords |
|------|------|------------------|
| 4 | mode-04-state-machine.md | state machine, status, lifecycle, transitions |
| 6 | mode-06-log-discovery.md | log, logging, debug, trace logs |
| 9 | mode-09-transaction.md | transaction, rollback, commit, atomicity |
| 12 | mode-12-taint-analysis.md | taint, injection, untrusted input, xss, sql injection |

## Tier 3: Specialized Modes

| Mode | File | Trigger Keywords |
|------|------|------------------|
| 5 | mode-05-flow-comparison.md | compare, diff, vs, difference |
| 7 | mode-07-feature-toggle.md | feature toggle, feature flag, rollout, A/B |
| 11 | mode-11-cache-flow.md | cache, redis, memoize, TTL, invalidate |
| 13 | mode-13-dead-code.md | dead code, unreachable, unused, orphan |
| 14 | mode-14-concurrency.md | async, thread, concurrent, race condition, parallel |

## Usage

When main atlas.flow.md detects a Tier 2/3 pattern:

```
1. Identify mode from trigger keywords
2. Read(scripts/atlas/flow-modes/{mode-file}.md)
3. Execute instructions from loaded file
```
