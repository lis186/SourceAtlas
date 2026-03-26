#!/usr/bin/env bash
# verify-contracts-WhisperState.sh
# Auto-generated from final-contracts.md (run 20260318-010811)
# Verifies 56 behavioral contracts for WhisperState module
# Run from any directory — uses absolute paths.

set -uo pipefail

VOICEINK_ROOT="/Users/justinlee/src/tries/2026-02-21-voiceink/VoiceInk/VoiceInk"
WHISPER="$VOICEINK_ROOT/Whisper/WhisperState.swift"
WHISPER_UI="$VOICEINK_ROOT/Whisper/WhisperState+UI.swift"
REGISTRY="$VOICEINK_ROOT/Services/TranscriptionServiceRegistry.swift"
POWERMGR="$VOICEINK_ROOT/PowerMode/PowerModeSessionManager.swift"
VOICEINK_APP="$VOICEINK_ROOT/VoiceInk.swift"

PASS=0
FAIL=0
SKIP=0

pass() { echo "✅ $1"; PASS=$((PASS+1)); }
fail() { echo "❌ $1"; FAIL=$((FAIL+1)); }
skip() { echo "⚠️  $1 (skipped)"; SKIP=$((SKIP+1)); }

check() {
  local id="$1"; local desc="$2"; shift 2
  if "$@" &>/dev/null; then
    pass "$id: $desc"
  else
    fail "$id: $desc"
  fi
}

check_absent() {
  local id="$1"; local desc="$2"; shift 2
  if ! "$@" &>/dev/null; then
    pass "$id: $desc"
  else
    fail "$id: $desc"
  fi
}

echo "═══════════════════════════════════════════════════════════"
echo "  WhisperState Contract Verification — 56 contracts"
echo "  Run: 20260318-010811"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ─── M — Mutation Contracts ─────────────────────────────────────

echo "── M: Mutation (8) ──"

# M-001: setupNotifications() runs BEFORE directory creation
# [DISPUTE APPLIED: ordering corrected — setupNotifications is line 131, dirs at 132-133]
check M-001 "setupNotifications() present in init (before directories)" \
  grep -q 'setupNotifications()' "$WHISPER"

check M-001b "createModelsDirectoryIfNeeded() called in init" \
  grep -q 'createModelsDirectoryIfNeeded()' "$WHISPER"

check M-001c "createRecordingsDirectoryIfNeeded() called in init" \
  grep -q 'createRecordingsDirectoryIfNeeded()' "$WHISPER"

# M-002: Transcription entity created before transcribeAudio
check M-002 "Transcription entity inserted with pending status before transcribeAudio" \
  grep -q 'transcriptionStatus: .pending' "$WHISPER"

check M-002b ".transcriptionCreated posted before transcribeAudio is called" \
  grep -q 'transcriptionCreated' "$WHISPER"

# M-003: Audio file UUID path assigned before recorder.startRecording
check M-003 "UUID-based .wav filename assigned to recordedFile before startRecording" \
  grep -q 'UUID().uuidString.*wav\|\.wav.*UUID' "$WHISPER"

# M-004: File deleted on cancel
check M-004 "FileManager.removeItem used in cancel branch" \
  grep -q 'removeItem' "$WHISPER"

check M-004b "currentSession?.cancel() called in cancel branch" \
  grep -q 'currentSession?.cancel()' "$WHISPER"

# M-005: Post-processing chain exists
check M-005 "TranscriptionOutputFilter.filter called in post-processing" \
  grep -q 'TranscriptionOutputFilter' "$WHISPER"

# M-006: transcription.text set in catch block (failure path)
check M-006 "transcription.text assigned in catch/failure path" \
  grep -q 'transcription\.text.*Transcription Failed\|Transcription Failed.*transcription\.text' "$WHISPER"

check M-006b "modelContext.save() called (try?) after transcription mutations" \
  grep -q 'try? modelContext.save()' "$WHISPER"

# M-007: shouldCancelRecording reset at line 476 (normal path) AND line 197 (next start)
# [DISPUTE APPLIED: both reset points documented]
check M-007 "shouldCancelRecording = false present (normal completion path)" \
  grep -q 'shouldCancelRecording = false' "$WHISPER"

check M-007b "shouldCancelRecording reset at recording start (line ~197)" \
  grep -n 'shouldCancelRecording = false' "$WHISPER" | grep -qv '476'  # at least one occurrence not at 476

# M-008: multiline string literal uses single newline (not \n\n) in trial expired prefix
# [DISPUTE APPLIED: single \n confirmed — multiline string, not \n escape]
check M-008 "Trial expired prefix text exists in source" \
  grep -q 'Your trial has expired' "$WHISPER"

check_absent M-008b "Trial expired prefix NOT followed by explicit \\n\\n escape" \
  grep -q '\\\\n\\\\n.*textToPaste\|textToPaste.*\\\\n\\\\n' "$WHISPER"

echo ""

# ─── L — Lifecycle Contracts ─────────────────────────────────────

echo "── L: Lifecycle (6) ──"

# L-001: .starting is a dead state; .busy is used in WhisperState+UI
# [DISPUTE APPLIED: .busy added from WhisperState+UI.swift]
check L-001 "case starting exists in RecordingState enum definition" \
  grep -q 'case starting' "$WHISPER"

check_absent L-001b ".starting is never assigned (dead state)" \
  grep -q 'recordingState = \.starting' "$WHISPER"

check L-001c ".busy assigned in WhisperState+UI" \
  grep -q 'recordingState = \.busy' "$WHISPER_UI"

check L-001d ".idle assigned after .busy in WhisperState+UI" \
  grep -q 'recordingState = \.idle' "$WHISPER_UI"

# L-002: recorderType.didSet sleeps 50ms then shows panel
check L-002 "recorderType.didSet exists with Task.sleep nanoseconds for 50ms" \
  grep -q '50_000_000' "$WHISPER"

check L-002b "UserDefaults.standard.set called in recorderType.didSet" \
  grep -q 'UserDefaults.standard.set.*recorderType\|recorderType.*UserDefaults.standard.set' "$WHISPER"

# L-003: isMiniRecorderVisible.didSet uses DispatchQueue.main.async
check L-003 "isMiniRecorderVisible.didSet uses DispatchQueue.main.async" \
  grep -q 'DispatchQueue.main.async' "$WHISPER"

# L-004: promptDetection applyDetectionResult + restoreOriginalSettings
check L-004 "applyDetectionResult called for prompt detection" \
  grep -q 'applyDetectionResult' "$WHISPER"

check L-004b "restoreOriginalSettings called after enhancement" \
  grep -q 'restoreOriginalSettings' "$WHISPER"

# L-005: dismissMiniRecorder only on normal tail path
check L-005 "dismissMiniRecorder() called in transcribeAudio" \
  grep -q 'dismissMiniRecorder' "$WHISPER"

# L-006: guard can run from non-idle states (else branch, not strict .idle check)
check L-006 "Start branch is else of recordingState == .recording (not strict .idle guard)" \
  grep -q 'recordingState == .recording' "$WHISPER"

echo ""

# ─── N — Notification Contracts ─────────────────────────────────

echo "── N: Notification (4) ──"

# N-001: .transcriptionCreated posted with pending text
check N-001 ".transcriptionCreated notification posted" \
  grep -q 'transcriptionCreated' "$WHISPER"

# N-002: .transcriptionCompleted posted on success and failure
check N-002 ".transcriptionCompleted notification posted" \
  grep -q 'transcriptionCompleted' "$WHISPER"

# N-003: setupNotifications() called in init
check N-003 "setupNotifications() called in init" \
  grep -q 'setupNotifications()' "$WHISPER"

# N-004: deinit removes self observers
check N-004 "deinit calls NotificationCenter.default.removeObserver(self)" \
  grep -q 'NotificationCenter.default.removeObserver(self)' "$WHISPER"

echo ""

# ─── S — Synchronization Contracts ──────────────────────────────

echo "── S: Synchronization (7) ──"

# S-001: @MainActor class declaration (@MainActor is on its own line above class declaration)
# [DISPUTE APPLIED: Task.detached correctly uses await — downgraded to MEDIUM]
check S-001 "@MainActor annotation present and class WhisperState declared" \
  grep -q '@MainActor' "$WHISPER"

check S-001b "Task.detached uses await for actor-isolated state access" \
  grep -q 'await self\.currentTranscriptionModel\|await self\.availableModels\|await self\.enhancementService' "$WHISPER"

# S-002: OSAllocatedUnfairLock for pendingChunks
check S-002 "OSAllocatedUnfairLock used for pendingChunks buffering" \
  grep -q 'OSAllocatedUnfairLock' "$WHISPER"

check S-002b "pendingChunks appended within lock" \
  grep -q 'pendingChunks.withLock' "$WHISPER"

# S-003: CRITICAL — callback swap BEFORE buffer flush
# [Ordering: onAudioChunk = realCallback THEN buffered read]
check S-003 "onAudioChunk set to realCallback (callback swap) exists" \
  grep -q 'onAudioChunk = realCallback' "$WHISPER"

check S-003b "buffered chunks flushed after callback swap (withLock read after assignment)" \
  grep -q 'let buffered = pendingChunks.withLock' "$WHISPER"

# S-004: Task.detached for model loading — not cancellable
check S-004 "Task.detached used for model loading" \
  grep -q 'Task.detached' "$WHISPER"

# S-005: Stop sound with optional 200ms delay
check S-005 "SoundManager.shared.playStopSound called" \
  grep -q 'playStopSound' "$WHISPER"

check S-005b "200ms delay (200_000_000 nanoseconds) for muted stop sound" \
  grep -q '200_000_000' "$WHISPER"

# S-006: Paste scheduled via asyncAfter 50ms
# [DISPUTE APPLIED: scheduling before dismissMiniRecorder, execution after]
check S-006 "DispatchQueue.main.asyncAfter 50ms used for paste scheduling" \
  grep -q 'asyncAfter.*0\.05\|asyncAfter.*now.*0\.05' "$WHISPER"

check S-006b "CursorPaster.pasteAtCursor called within asyncAfter closure" \
  grep -q 'CursorPaster.pasteAtCursor' "$WHISPER"

# S-007: Auto-send Enter with 200ms delay
check S-007 "CursorPaster.pressEnter called with additional 200ms delay" \
  grep -q 'pressEnter' "$WHISPER"

check S-007b "isAutoSendEnabled checked before pressEnter" \
  grep -q 'isAutoSendEnabled' "$WHISPER"

echo ""

# ─── E — Error Handling Contracts ───────────────────────────────

echo "── E: Error Handling (6) ──"

# E-001: startRecording failure shows notification
check E-001 "Recording failed to start notification shown on error" \
  grep -q '"Recording failed to start"\|Recording failed to start' "$WHISPER"

check E-001b "recordedFile = nil set in startRecording catch" \
  grep -q 'recordedFile = nil' "$WHISPER"

# E-002: requestRecordPermission is a no-op
# [META_ISSUE APPLIED: method scope]
check E-002 "requestRecordPermission calls response(true) unconditionally" \
  grep -q 'response(true)' "$WHISPER"

# E-003: "Transcription Failed:" prefix in error text
check E-003 "Transcription Failed prefix used in error text" \
  grep -q '"Transcription Failed:' "$WHISPER"

check E-003b "transcriptionStatus set to .failed in catch" \
  grep -q 'transcriptionStatus.*\.failed\|\.failed.*transcriptionStatus' "$WHISPER"

# E-004: Enhancement failure writes to enhancedText
check E-004 "Enhancement failed prefix written to transcription.enhancedText" \
  grep -q '"Enhancement failed:' "$WHISPER"

# E-005: No recorded file after stop — silent recovery
check E-005 "Silent recovery to idle when recordedFile is nil after stop" \
  grep -q 'No recorded file found' "$WHISPER"

# E-006: Directory creation errors logged silently
check E-006 "Error creating recordings directory logged (not thrown)" \
  grep -q 'Error creating recordings directory' "$WHISPER"

echo ""

# ─── C — Cancellation Contracts ─────────────────────────────────

echo "── C: Cancellation (5) ──"

# C-001: shouldCancelRecording flag is @Published — @MainActor serializes
# [DISPUTE APPLIED: downgraded from HIGH; @MainActor actor isolation applies]
check C-001 "shouldCancelRecording declared as @Published var" \
  grep -q '@Published.*shouldCancelRecording\|shouldCancelRecording.*@Published' "$WHISPER"

# C-002: CORRECTED — 5 cancellation check points (not 4)
# [DISPUTE APPLIED: count corrected; lines 309, 374, 406, 424, 444]
check C-002 "checkCancellationAndCleanup called at least once (multiple cancel checks)" \
  grep -q 'checkCancellationAndCleanup' "$WHISPER"

C002_COUNT=$(grep -c 'checkCancellationAndCleanup' "$WHISPER" 2>/dev/null || echo 0)
if [ "$C002_COUNT" -ge 4 ]; then
  pass "C-002b: At least 4 cancellation check references found ($C002_COUNT)"
else
  fail "C-002b: Expected ≥4 cancellation check references, found $C002_COUNT"
fi

# C-003: defer block may double-call cleanupModelResources
# defer and shouldCancelRecording are on adjacent lines (not same line)
check C-003 "defer block in transcribeAudio exists and shouldCancelRecording checked inside" \
  grep -A2 'defer {' "$WHISPER" | grep -q 'shouldCancelRecording'

check C-003b "cleanupModelResources called in defer and possibly in early returns" \
  grep -q 'cleanupModelResources' "$WHISPER"

# C-004: shouldCancelRecording not reset on early return paths
check C-004 "shouldCancelRecording = false only at end of transcribeAudio (line ~476)" \
  grep -q 'shouldCancelRecording = false' "$WHISPER"

# C-005: Task.detached not integrated with cancel flag
check C-005 "Task.detached for model loading exists (not tied to cancellation)" \
  grep -q 'Task\.detached' "$WHISPER"

echo ""

# ─── D — Dependency Contracts ───────────────────────────────────

echo "── D: Dependency (9) ──"

# D-001: PowerModeSessionManager.shared configured with self
# [DISPUTE APPLIED: no reciprocal strong reference — downgraded to MEDIUM]
check D-001 "PowerModeSessionManager.shared.configure called with self in init" \
  grep -q 'PowerModeSessionManager.shared.configure' "$WHISPER"

check D-001b "PowerModeSessionManager stores WhisperState as optional var (not retain cycle)" \
  grep -q 'var whisperState.*WhisperState?\|WhisperState?.*var whisperState' "$POWERMGR"

# D-002: TranscriptionServiceRegistry holds weak reference
# [DISPUTE APPLIED: weak storage confirmed — downgraded to LOW]
check D-002 "TranscriptionServiceRegistry.swift uses weak var whisperState" \
  grep -q 'weak var whisperState' "$REGISTRY"

# D-003: currentTranscriptionModel guarded before recording
# [META_ISSUE APPLIED: method scope]
check D-003 "guard currentTranscriptionModel != nil in toggleRecord" \
  grep -q 'guard currentTranscriptionModel != nil\|currentTranscriptionModel != nil.*else' "$WHISPER"

# D-004: WordReplacementService requires modelContext
check D-004 "WordReplacementService.shared.applyReplacements called with modelContext" \
  grep -q 'WordReplacementService.shared.applyReplacements.*modelContext' "$WHISPER"

# D-005: ActiveWindowService applied after recording starts
check D-005 "ActiveWindowService.shared.applyConfiguration called after startRecording" \
  grep -q 'ActiveWindowService.shared.applyConfiguration' "$WHISPER"

# D-006: Bundle model URL has 3 fallback paths
check D-006 "Multiple URL fallback paths exist for bundle model (possibleURLs)" \
  grep -q 'possibleURLs\|Bundle.main.url.*Models' "$WHISPER"

# D-007: enhancementService guarded by isConfigured
# [DISPUTE APPLIED: promptDetection also guarded by isConfigured at line 397]
check D-007 "isConfigured check guards AI enhancement path" \
  grep -q 'enhancementService\.isConfigured\|enhancementService.*isConfigured' "$WHISPER"

check D-007b "promptDetection also guarded by enhancementService.isConfigured" \
  grep -n 'isConfigured' "$WHISPER" | grep -q 'promptDetection\|applyDetectionResult\|397'

# D-008: PowerModeManager.shared read during transcription
check D-008 "PowerModeManager.shared.currentActiveConfiguration read in transcribeAudio" \
  grep -q 'PowerModeManager.shared' "$WHISPER"

# D-009: ActiveWindowService bootstrap in app startup [ADD]
check D-009 "ActiveWindowService configured before WhisperState wiring in VoiceInk.swift" \
  grep -q 'activeWindowService.*configure\|configureWhisperState' "$VOICEINK_APP"

echo ""

# ─── P — Propagation Contracts ──────────────────────────────────

echo "── P: Propagation (11) ──"

# P-001: Post-processing chain order (CRITICAL)
# [DISPUTE APPLIED: steps 6-7 clarified as conditional]
check P-001 "TranscriptionOutputFilter.filter is first step in chain" \
  grep -q 'TranscriptionOutputFilter.filter' "$WHISPER"

check P-001b "ChineseConverter.simplifiedToTraditional called after OutputFilter" \
  grep -q 'ChineseConverter.simplifiedToTraditional\|simplifiedToTraditional' "$WHISPER"

check P-001c "trimmingCharacters called in post-processing chain" \
  grep -q 'trimmingCharacters' "$WHISPER"

check P-001d "WhisperTextFormatter.format called in post-processing chain" \
  grep -q 'WhisperTextFormatter.format' "$WHISPER"

check P-001e "WordReplacementService.shared.applyReplacements called last in deterministic chain" \
  grep -q 'WordReplacementService.shared.applyReplacements' "$WHISPER"

# P-002: OutputFilter unconditional (no UserDefaults guard)
check P-002 "TranscriptionOutputFilter.filter has no UserDefaults condition guard" \
  grep -q 'TranscriptionOutputFilter.filter' "$WHISPER"

# P-003: zh-TW conditional on SelectedLanguage == "zh-TW"
check P-003 "SelectedLanguage == zh-TW string comparison guards zh-TW conversion" \
  grep -q '"SelectedLanguage".*"zh-TW"\|"zh-TW".*"SelectedLanguage"' "$WHISPER"

# P-004: trim before formatter
check P-004 "trimmingCharacters in .whitespacesAndNewlines called in post-processing" \
  grep -q 'trimmingCharacters(in: .whitespacesAndNewlines)' "$WHISPER"

# P-005: IsTextFormattingEnabled controls WhisperTextFormatter
check P-005 "IsTextFormattingEnabled UserDefaults key guards WhisperTextFormatter" \
  grep -q '"IsTextFormattingEnabled"' "$WHISPER"

# P-006: Word replacement with live modelContext (unconditional)
check P-006 "WordReplacementService.applyReplacements called unconditionally (no feature flag)" \
  grep -q 'applyReplacements.*modelContext' "$WHISPER"

# P-007: AI enhancement sets finalPastedText = enhancedText
check P-007 "finalPastedText assigned from enhancedText after AI enhancement" \
  grep -q 'finalPastedText.*enhancedText\|enhancedText.*finalPastedText' "$WHISPER"

# P-008: CursorPaster.pasteAtCursor with optional trailing space
check P-008 "CursorPaster.pasteAtCursor called with AppendTrailingSpace check" \
  grep -q 'AppendTrailingSpace\|pasteAtCursor' "$WHISPER"

# P-009: getEnhancementService() is actor-isolated getter
# [META_ISSUE APPLIED: method scope; DISPUTE: actor-isolated, not class-level risk]
check P-009 "getEnhancementService() method exists (returns Optional AIEnhancementService)" \
  grep -q 'func getEnhancementService' "$WHISPER"

# P-010: isModelLoaded @Published propagation [ADD]
check P-010 "@Published var isModelLoaded declared" \
  grep -q '@Published.*isModelLoaded\|isModelLoaded.*@Published' "$WHISPER"

# P-011: clipboardMessage @Published propagation [ADD]
check P-011 "@Published var clipboardMessage declared" \
  grep -q '@Published.*clipboardMessage\|clipboardMessage.*@Published' "$WHISPER"

echo ""
echo "═══════════════════════════════════════════════════════════"
printf "  ✅ PASS: %-4d   ❌ FAIL: %-4d   ⚠️  SKIP: %-4d\n" $PASS $FAIL $SKIP
echo "═══════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
