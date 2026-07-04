---
name: history
description: Analyzes git history to find hotspots (frequently changed files), temporal coupling (files that change together), contributor knowledge distribution, and bus factor risk, using code-maat-style analyses. Use when the user asks "what are the hotspots", "what files change most", "what files always change together", "who knows this code", "who should I ask about X", "bus factor", "knowledge silos", or wants to understand code evolution before refactoring.
model: sonnet
allowed-tools: Bash, Glob, Grep, Read, Write, AskUserQuestion
argument-hint: (optional) [path or scope, e.g., "src/", "last 6 months"] [--force]
---

# SourceAtlas: Git History Analysis

**Arguments**: ${ARGUMENTS:-entire repository}

Extract hotspots, temporal coupling, and knowledge distribution from git history. Requires a git repository (`git rev-parse --git-dir`).

## 1. Cache check (do this first)

Cache path: `.sourceatlas/history.md` (fixed — the analysis is repository-wide).

If the cache exists and `--force` is NOT in the arguments: read it, output its content under the branded header, then STOP — no analysis.

```
📁 Loading cache: .sourceatlas/history.md (N days ago)
💡 Add --force to re-analyze
```

Warn if the cache is older than 30 days.

## 2. Prerequisites

code-maat gives the best coupling/ownership data:

```bash
[ -f "$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar" ] &&
  export CODEMAAT_JAR="$HOME/.sourceatlas/bin/code-maat-1.0.4-standalone.jar"
```

If not found, ask via AskUserQuestion whether to install (requires Java 8+), then run `"${CLAUDE_PLUGIN_ROOT}/scripts/install-codemaat.sh"`. If declined or Java is unavailable, use the pure-git fallbacks below and note reduced coupling accuracy.

## 3. Generate git log

Default period 12 months (min 3, max 24 — parse a number from the arguments if given). Scope filter applies if a path was given.

```bash
MONTHS=12
AFTER=$(date -v-${MONTHS}m +%Y-%m-%d 2>/dev/null || date -d "${MONTHS} months ago" +%Y-%m-%d)
git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' \
    --after="$AFTER" ${SCOPE:+-- "$SCOPE"} > /tmp/git-history.log

COMMIT_COUNT=$(grep -c '^--' /tmp/git-history.log)
FILE_COUNT=$(awk 'NF==3 && $1 ~ /^[0-9]+$/' /tmp/git-history.log | cut -f3 | sort -u | wc -l)
```

If fewer than 50 commits, warn that temporal patterns will be weak and suggest widening the range. For huge repos, add `--max-count=1000` or narrow the scope.

## 4. Analyses

**Hotspots** (top 10 by revisions; complexity score = LOC × revisions):

```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a revisions 2>/dev/null > /tmp/revisions.csv
tail -n +2 /tmp/revisions.csv | sort -t, -k2 -nr | head -10 |
while IFS=, read -r file revs; do
  [ -f "$file" ] || continue
  LOC=$(wc -l < "$file"); echo "$file,$revs,$LOC,$((LOC * revs))"
done
```

Fallback without code-maat:

```bash
git log --after="$AFTER" --name-only --pretty=format: ${SCOPE:+-- "$SCOPE"} |
  grep -v '^$' | sort | uniq -c | sort -rn | head -10
```

**Temporal coupling** (keep degree ≥ 0.5, top 20):

```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a coupling 2>/dev/null > /tmp/coupling.csv
awk -F, 'NR>1 && $3 >= 0.5' /tmp/coupling.csv | sort -t, -k3 -nr | head -20
```

**Contributors / knowledge map** (per major area) and **bus factor** (single-contributor files in the last 6 months):

```bash
java -jar "$CODEMAAT_JAR" -l /tmp/git-history.log -c git2 -a entity-ownership 2>/dev/null > /tmp/ownership.csv

for area in src/api/ src/core/; do   # use the repo's actual top-level areas
  echo "=== $area ==="; git log --pretty=format:'%an|%ad|%s' --date=short -- "$area" | head -5
done

AFTER6=$(date -v-6m +%Y-%m-%d 2>/dev/null || date -d '6 months ago' +%Y-%m-%d)
git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --after="$AFTER6" > /tmp/recent-6m.log
java -jar "$CODEMAAT_JAR" -l /tmp/recent-6m.log -c git2 -a entity-ownership 2>/dev/null |
  awk -F, 'NR>1 {count[$1]++} END {for (f in count) if (count[f]==1) print f}'
```

## 5. Interpretation rules

- Composite risk = (revisions × coupling_count) / contributor_count. Risk types: bus factor, complexity, coupling, testing gap (hotspot with no matching test-file churn).
- Complexity score > 10,000 → refactoring candidate. High revisions + low LOC (configs, small utils) is normal. Low revisions + high LOC is stable, mature code.
- Coupling degree: ≥ 0.9 consider merging the files; 0.7–0.9 review the dependency; 0.5–0.7 monitor.
- Expected coupling: model↔service, route↔controller, test↔production, component↔styles. Suspicious: cross-layer (API↔DB), cross-module (user↔payment), backend↔frontend.
- Healthy knowledge: 2–3 active contributors per module. Risk: single contributor, especially if inactive > 6 months.
- Privacy: report "recent contributors", never ownership percentages; frame findings as opportunities, not blame. Note if duplicate author names may merge stats (`git log --format='%aN <%aE>' | sort -u`).
- If all couplings < 0.5 and hotspots < 10 revisions, say so plainly: clean separation, young history, or monolithic commits.

## 6. Report

Start with:

```markdown
🗺️ SourceAtlas: History
───────────────────────────────
📜 [repo name] │ [N] months
```

Then YAML:

```yaml
metadata:
  period: {months: ..., start: ..., end: ...}
  commits_analyzed: ...
  files_analyzed: ...
hotspots:                 # top 10 by revisions
  - {file: ..., revisions: ..., loc: ..., complexity: ...}   # complexity = loc × revisions
coupling:                 # degree ≥ 0.5
  - {a: ..., b: ..., degree: ..., co_changes: ..., verdict: expected|suspicious, note: ...}
knowledge:
  areas:
    - {area: ..., contributors: [{name: ..., recent_commits: ..., last_active: ...}]}
  bus_factor_risks:
    - {area: ..., level: high|medium|low, reason: ...}
risks:                    # composite assessment across dimensions
  - {target: ..., type: bus_factor|complexity|coupling|testing_gap, severity: ..., action: ...}
summary:
  priority_actions: [...]   # concrete, ordered; each references real files/metrics
```

Every finding needs a recommended action with real file paths and counts — no placeholders.

## 7. Verify, then save

Before saving, `test -f` each hotspot file and both files of each coupling pair claimed in the report (drop or correct entries that fail), spot-check 2–3 revision counts against `git log --oneline -- <file> | wc -l` (±20% tolerance), and confirm contributor names appear in `git shortlog -sn --all`. Then `mkdir -p .sourceatlas` and write the full report to `.sourceatlas/history.md`. Confirm: `💾 Saved to .sourceatlas/history.md`

## Recommended next

Suggest 1–2 follow-ups only when findings are concrete, using discovered names:

| Finding | Command |
|---------|---------|
| High-risk hotspot | `/sourceatlas:impact "[hotspot file]"` |
| Suspicious coupling | `/sourceatlas:flow "[entry point]"` |
| Refactoring needed | `/sourceatlas:pattern "[pattern]"` |
| Complexity everywhere | `/sourceatlas:overview` |

💡 Enter a number (e.g., `1`) or copy the command to execute
