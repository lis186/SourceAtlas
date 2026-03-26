#!/bin/bash
# verify-contracts-WhisperState.sh
# Auto-generated contract verification script for WhisperState (Swift)
# Each assert_match verifies that a behavioral contract still exists in source.
set -uo pipefail
PASS=0; FAIL=0

TARGET="/private/var/folders/ty/64splpcj3bv3hnccl01m5bsr0000gp/T/tmp.k3p57JEaQG/audit-target/WhisperState.swift"

assert_match() {
  local id="$1" pattern="$2" file="$3"
  if grep -qn "$pattern" "$file"; then
    echo "PASS [$id]"; PASS=$((PASS+1))
  else
    echo "FAIL [$id] -- pattern not found: $pattern in $file"; FAIL=$((FAIL+1))
  fi
}

# M-001: transcription.text に転写テキスト/エラー文字列書き込み
assert_match "M-001a" 'transcription\.text = text' "$TARGET"
assert_match "M-001b" 'Transcription Failed:' "$TARGET"

# M-002: shouldCancelRecording = false リセット
assert_match "M-002" 'shouldCancelRecording = false' "$TARGET"

# M-003: recorderType didSet → UserDefaults 書き込み
assert_match "M-003" 'UserDefaults\.standard\.set(recorderType, forKey: "RecorderType")' "$TARGET"

# M-004: modelContext.insert + save + transcriptionCreated の順序
assert_match "M-004a" 'modelContext\.insert(transcription)' "$TARGET"
assert_match "M-004b" 'try? modelContext\.save()' "$TARGET"
assert_match "M-004c" '\.transcriptionCreated' "$TARGET"

# M-005: AI強化フィールド書き込み
assert_match "M-005" 'transcription\.enhancedText = enhancedText' "$TARGET"

# M-006: onAudioChunk コールバックスワップ
assert_match "M-006a" 'self\.recorder\.onAudioChunk = realCallback' "$TARGET"
assert_match "M-006b" 'pendingChunks\.withLock' "$TARGET"

# L-001: recording → transcribing 遷移順序
assert_match "L-001a" 'recordingState = \.transcribing' "$TARGET"
assert_match "L-001b" 'await recorder\.stopRecording()' "$TARGET"

# L-003: deinit → removeObserver
assert_match "L-003" 'NotificationCenter\.default\.removeObserver(self)' "$TARGET"

# L-004: isMiniRecorderVisible didSet → DispatchQueue.main.async
assert_match "L-004" 'DispatchQueue\.main\.async' "$TARGET"

# L-005: recorderType didSet → 50ms sleep
assert_match "L-005" 'Task\.sleep(nanoseconds: 50_000_000)' "$TARGET"

# N-001: .transcriptionCreated 通知発行
assert_match "N-001" 'name: \.transcriptionCreated' "$TARGET"

# N-002: .transcriptionCompleted 通知発行
assert_match "N-002" 'name: \.transcriptionCompleted' "$TARGET"

# S-001: OSAllocatedUnfairLock pendingChunks
assert_match "S-001" 'OSAllocatedUnfairLock' "$TARGET"

# S-002: @MainActor クラス宣言
assert_match "S-002" '@MainActor' "$TARGET"

# S-003: DispatchQueue.main.async（isMiniRecorderVisible didSet）
assert_match "S-003" 'DispatchQueue\.main\.async.*\[self\]' "$TARGET"

# E-001: enhancement エラー文字列書き込み
assert_match "E-001" 'Enhancement failed:' "$TARGET"

# E-002: modelContext.save() try? サイレント
assert_match "E-002" 'try? modelContext\.save()' "$TARGET"

# E-003: createRecordingsDirectoryIfNeeded エラーログのみ
assert_match "E-003" 'Error creating recordings directory' "$TARGET"

# E-004: URL検証失敗時のフォールバック
assert_match "E-004" 'Invalid audio file URL' "$TARGET"

# C-001: currentSession cancel + nil
assert_match "C-001a" 'currentSession?.cancel()' "$TARGET"
assert_match "C-001b" 'currentSession = nil' "$TARGET"

# C-002: checkCancellationAndCleanup 呼び出し（複数箇所）
assert_match "C-002" 'checkCancellationAndCleanup()' "$TARGET"

# C-003: recordedFile 削除
assert_match "C-003" 'FileManager\.default\.removeItem(at: recordedFile)' "$TARGET"

# D-001: PowerModeSessionManager.shared.configure
assert_match "D-001" 'PowerModeSessionManager\.shared\.configure' "$TARGET"

# D-002: ActiveWindowService.shared.applyConfiguration
assert_match "D-002" 'ActiveWindowService\.shared\.applyConfiguration' "$TARGET"

# D-003: serviceRegistry! 強制アンラップ宣言
assert_match "D-003" 'serviceRegistry: TranscriptionServiceRegistry!' "$TARGET"

# D-004: UserDefaults RecorderType キー読み込み
assert_match "D-004" 'forKey: "RecorderType"' "$TARGET"

# D-005: LicenseViewModel インライン初期化
assert_match "D-005" 'LicenseViewModel()' "$TARGET"

# P-001: 転写テキスト変換チェーン（TranscriptionOutputFilter）
assert_match "P-001a" 'TranscriptionOutputFilter\.filter' "$TARGET"
assert_match "P-001b" 'WordReplacementService\.shared\.applyReplacements' "$TARGET"
assert_match "P-001c" 'CursorPaster\.pasteAtCursor' "$TARGET"

# P-002: finalPastedText 昇格
assert_match "P-002a" 'finalPastedText = text' "$TARGET"
assert_match "P-002b" 'finalPastedText = enhancedText' "$TARGET"

# N-004: SoundManager audio feedback (ADD from Gemini/Codex)
assert_match "N-004" 'SoundManager\.shared\.playStopSound()' "$TARGET"

# P-003: Auto-Send Enter with 200ms delay (ADD from Gemini/Codex)
assert_match "P-003a" 'isAutoSendEnabled' "$TARGET"
assert_match "P-003b" 'CursorPaster\.pressEnter()' "$TARGET"

# M-007: AppendTrailingSpace (ADD from Gemini/Codex)
assert_match "M-007" 'AppendTrailingSpace' "$TARGET"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
