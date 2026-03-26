# Seam Discovery: Gotchas

Known failure patterns discovered during development against `NYHTTPSClient.m` (745-line God Class).

---

## G1: Pragma Marks Lie About Responsibility

**Problem**: `#pragma mark - POST Methods` sounds like it owns all POST logic, but `postPathForECoupon:` actually calls `getPath:` internally. The zone name misleads.

**Detection**: Layer 3 clang AST reveals the truth — check `sends` list, not zone name.

**Mitigation**: Always verify zone responsibility via message sends, never trust marker names alone.

---

## G2: success:/failure: Pattern Matches Everything

**Problem**: The `success:|failure:` pattern from `objc.patterns` (category N) matches nearly every method that uses AFNetworking completion blocks. It's not useful for differentiating zones.

**Detection**: If a pattern matches >60% of methods in a file, it has no discriminating power.

**Mitigation**: Skip high-frequency patterns when computing zone deps. Focus on patterns with selective distribution across zones.

---

## G3: Clang AST Empty Without Header Paths

**Problem**: For ObjC projects with CocoaPods, clang hits `fatal error: 'AFNetworking/AFHTTPSessionManager.h' file not found` at the first framework import and produces only error-recovery AST (few or no methods).

**Detection**: Layer 3 section shows 0 methods, or `# clang not found` comment.

**Mitigation**: `resolve-header-paths.sh` auto-discovers CocoaPods header paths. If it fails, the script degrades gracefully to grep-based analysis (Layer 1 only). Check stderr for diagnostics.

---

## G4: Framework-Style Imports Need Parent Directory

**Problem**: `#import <AFNetworking/AFHTTPSessionManager.h>` requires `-I` pointing to the directory CONTAINING `AFNetworking/`, not `AFNetworking/` itself.

**Detection**: Clang errors like `'AFNetworking/X.h' not found` despite AFNetworking headers existing.

**Mitigation**: `resolve-header-paths.sh` adds both the directory containing `.h` files AND its parent directory. Already fixed in v1.

---

## G5: Zone Count = 0 (No Markers Found)

**Problem**: Some files have zero `#pragma mark` / `// MARK:` / `// region` markers. detect-zones.sh outputs `zones: []`.

**Detection**: `marker_count: 0` in output.

**Mitigation**: Claude should fall back to method-clustering analysis using Layer 3 sends data. Group methods by shared external collaborators (Sandi Metz's message-passing heuristic). This is noted in the script output: `# WARNING: No zone markers found. Claude should use method-clustering fallback.`

---

## G6: Python `import yaml` Not Available

**Problem**: The inline Python in detect-zones.sh has `import json, sys, yaml` but the `yaml` module may not be installed and is actually unused.

**Detection**: Python ImportError on yaml (though currently doesn't crash because yaml isn't called).

**Mitigation**: Should be cleaned up — remove unused `yaml` import. The script only uses `json` and `sys`.

---

## G7: Large Clang AST JSON (200MB+)

**Problem**: For large ObjC files, `clang -ast-dump=json` can produce 200MB+ of JSON. This passes through a Python filter which handles it via streaming, but the initial JSON parse loads it all into memory.

**Detection**: Slow Layer 3 extraction (>5 seconds).

**Mitigation**: `clang-extract-methods.py` uses `json.load()` which buffers the entire AST. For extremely large files, this may need streaming JSON parsing (ijson). Not an issue for files <2000 lines.
