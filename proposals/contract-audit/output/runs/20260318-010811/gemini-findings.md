```
Contract: Recording state change is published
Category: L
Trigger:  The `recordingState` property is changed.
Effect:   Any SwiftUI view observing this `WhisperState` object will be updated.
Evidence: WhisperState.swift:21 -- @Published var recordingState: RecordingState = .idle
```
```
Contract: Model load status is published
Category: L
Trigger:  The `isModelLoaded` property is changed.
Effect:   Observing UI is notified that a local model has been loaded or unloaded.
Evidence: WhisperState.swift:22 -- @Published var isModelLoaded = false
```
```
Contract: UI is updated with clipboard-related messages
Category: P
Trigger:  The `clipboardMessage` property is changed.
Effect:   An observing UI view displays a message, likely confirming a copy-to-clipboard action.
Evidence: WhisperState.swift:28 -- @Published var clipboardMessage = ""
```
```
Contract: Mini recorder visibility change triggers panel display
Category: L
Trigger:  The `isMiniRecorderVisible` property is set.
Effect:   The application shows or hides the main recorder UI panel asynchronously.
Evidence: WhisperState.swift:65 -- didSet { ... DispatchQueue.main.async { ... } ... }
```
```
Contract: Changing recorder type recreates the UI panel
Category: L
Trigger:  The `recorderType` property is changed.
Effect:   The old recorder window is hidden, a new one is shown, and the preference is saved to UserDefaults.
Evidence: WhisperState.swift:49 -- didSet { ... UserDefaults.standard.set(recorderType, forKey: "RecorderType") }
```
```
Contract: State machine transition from recording to transcribing
Category: L
Trigger:  `toggleRecord()` is called while in the `.recording` state.
Effect:   The state changes to `.transcribing`, `recorder.stopRecording()` is called, and a new `Transcription` object is created and persisted.
Evidence: WhisperState.swift:189 -- if recordingState == .recording { ... recordingState = .transcribing ... await recorder.stopRecording() ... modelContext.insert(transcription) }
```
```
Contract: Transcription creation triggers notification
Category: N
Trigger:  A recording is successfully stopped and a `Transcription` entity is created.
Effect:   A `NotificationCenter.default.post` is sent with the name `.transcriptionCreated`.
Evidence: WhisperState.swift:200 -- NotificationCenter.default.post(name: .transcriptionCreated, object: transcription)
```
```
Contract: Recording can be cancelled before transcription
Category: C
Trigger:  `toggleRecord()` is called to stop recording, and the `shouldCancelRecording` flag is true.
Effect:   Transcription is skipped, the session is cancelled, the audio file is deleted, and state returns to idle.
Evidence: WhisperState.swift:203 -- } else { currentSession?.cancel() ... try? FileManager.default.removeItem(at: recordedFile) ... recordingState = .idle }
```
```
Contract: Starting a recording buffers audio immediately
Category: S
Trigger:  `toggleRecord()` is called to start recording.
Effect:   Audio chunks are immediately appended to a lock-protected buffer (`pendingChunks`) while the transcription session is prepared asynchronously.
Evidence: WhisperState.swift:230 -- let pendingChunks = OSAllocatedUnfairLock(initialState: [Data]()) ... self.recorder.onAudioChunk = { data in pendingChunks.withLock { $0.append(data) } }
```
```
Contract: Recording buffers are flushed after session is ready
Category: S
Trigger:  The `TranscriptionSession`'s `prepare()` method completes.
Effect:   Any audio data buffered during session setup is sent to the session, ensuring no data is lost.
Evidence: WhisperState.swift:252 -- for chunk in buffered { realCallback(chunk) }
```
```
Contract: Background tasks are detached during recording
Category: S
Trigger:  Recording successfully starts.
Effect:   Model loading and context capturing are performed on a detached, non-blocking background task.
Evidence: WhisperState.swift:257 -- Task.detached { [weak self] in ... }
```
```
Contract: System context is captured for AI enhancement
Category: P
Trigger:  Recording starts and an enhancement service is available.
Effect:   The `AIEnhancementService` captures the current clipboard and screen content to use as context for later processing.
Evidence: WhisperState.swift:273 -- enhancementService.captureClipboardContext() ... await enhancementService.captureScreenContext()
```
```
Contract: Failed recording start shows notification
Category: E
Trigger:  `recorder.startRecording()` throws an error.
Effect:   An error is logged, a user-facing notification is displayed, and the UI is dismissed.
Evidence: WhisperState.swift:280 -- await NotificationManager.shared.showNotification(title: "Recording failed to start", type: .error)
```
```
Contract: Stop sound is played on transcription start
Category: P
Trigger:  The `transcribeAudio` function is called.
Effect:   `SoundManager.shared.playStopSound()` is called, providing audible feedback.
Evidence: WhisperState.swift:316 -- SoundManager.shared.playStopSound()
```
```
Contract: Transcription result is filtered
Category: P
Trigger:  A raw transcript is received from the transcription service.
Effect:   The text is processed by `TranscriptionOutputFilter.filter()`.
Evidence: WhisperState.swift:341 -- text = TranscriptionOutputFilter.filter(text)
```
```
Contract: Chinese language is converted
Category: P
Trigger:  A transcript is produced and the user's selected language is `zh-TW`.
Effect:   The text is converted from Simplified to Traditional Chinese.
Evidence: WhisperState.swift:345 -- text = ChineseConverter.simplifiedToTraditional(text)
```
```
Contract: Text formatting is conditionally applied
Category: P
Trigger:  A transcript is produced and the "IsTextFormattingEnabled" `UserDefaults` key is true.
Effect:   The text is processed by `WhisperTextFormatter.format()`.
Evidence: WhisperState.swift:356 -- text = WhisperTextFormatter.format(text)
```
```
Contract: User-defined word replacements are applied
Category: P
Trigger:  A transcript has been formatted.
Effect:   The text is passed to `WordReplacementService.shared.applyReplacements()` to substitute custom words.
Evidence: WhisperState.swift:360 -- text = WordReplacementService.shared.applyReplacements(to: text, using: modelContext)
```
```
Contract: Trigger words in transcript can alter AI behavior
Category: D
Trigger:  The `promptDetectionService` analyzes the transcribed text.
Effect:   The `AIEnhancementService`'s behavior may be temporarily changed based on detected trigger words.
Evidence: WhisperState.swift:380 -- await promptDetectionService.applyDetectionResult(detectionResult, to: enhancementService)
```
```
Contract: Transcription result is enhanced by AI
Category: P
Trigger:  AI enhancement is enabled and configured.
Effect:   The transcribed text is sent to `enhancementService.enhance()` and replaced with the result.
Evidence: WhisperState.swift:391 -- let (enhancedText, _, _) = try await enhancementService.enhance(textForAI)
```
```
Contract: AI enhancement failure is recorded
Category: E
Trigger:  `enhancementService.enhance()` throws an error.
Effect:   The `enhancedText` property of the `Transcription` object is set to an error message.
Evidence: WhisperState.swift:399 -- transcription.enhancedText = "Enhancement failed: \(error)"
```
```
Contract: Final transcription completion triggers notification
Category: N
Trigger:  The `transcribeAudio` function completes, either successfully or with an error.
Effect:   A `NotificationCenter.default.post` is sent with the name `.transcriptionCompleted`.
Evidence: WhisperState.swift:413 -- NotificationCenter.default.post(name: .transcriptionCompleted, object: transcription)
```
```
Contract: Expired trial modifies pasted text
Category: P
Trigger:  Pasting a completed transcription when `licenseViewModel.licenseState` is `.trialExpired`.
Effect:   A promotional message is prepended to the user's transcribed text before pasting.
Evidence: WhisperState.swift:419 -- textToPaste = """ Your trial has expired... """
```
```
Contract: Final text is pasted at the cursor position
Category: P
Trigger:  A transcription is successfully completed and processed.
Effect:   `CursorPaster.pasteAtCursor()` is called to insert the text into the active application.
Evidence: WhisperState.swift:426 -- CursorPaster.pasteAtCursor(textToPaste + (appendSpace ? " " : ""))
```
```
Contract: Auto-send feature presses Enter key
Category: P
Trigger:  A transcription is pasted and the active power mode has `isAutoSendEnabled` set to true.
Effect:   `CursorPaster.pressEnter()` is called after a short delay, submitting the pasted text.
Evidence: WhisperState.swift:431 -- CursorPaster.pressEnter()
```
```
Contract: Temporary AI settings are reverted after processing
Category: L
Trigger:  A transcription involving a trigger word has been fully processed.
Effect:   `promptDetectionService.restoreOriginalSettings()` is called to revert the `AIEnhancementService` to its original state.
Evidence: WhisperState.swift:437 -- await promptDetectionService.restoreOriginalSettings(result, to: enhancementService)
```
```
Contract: Cancellation check cleans up resources
Category: C
Trigger:  The `shouldCancelRecording` flag is found to be true during transcription.
Effect:   `cleanupModelResources()` is called, and the current operation is halted.
Evidence: WhisperState.swift:446 -- if shouldCancelRecording { await cleanupModelResources(); return true }
```
```
Contract: App directories are created on initialization
Category: M
Trigger:  The `WhisperState` object is initialized.
Effect:   `WhisperModels` and `Recordings` directories are created in the Application Support folder if they don't exist.
Evidence: WhisperState.swift:171 -- createModelsDirectoryIfNeeded() ... createRecordingsDirectoryIfNeeded()
```
```
Contract: Dependencies are injected and configured at init
Category: D
Trigger:  The `WhisperState` object is initialized.
Effect:   Configures `PowerModeSessionManager` and initializes `TranscriptionServiceRegistry`, establishing connections to other services.
Evidence: WhisperState.swift:163 -- PowerModeSessionManager.shared.configure(whisperState: self, enhancementService: enhancementService)
```

TOTAL CONTRACTS FOUND: 29
CATEGORY BREAKDOWN: M=[2] L=[6] N=[2] S=[3] E=[2] C=[3] D=[3] P=[8]

## Section 4: Boundary Discovery

EXTERNAL_DEPENDENCY: `WhisperState+ModelManagement.swift` -- Implements `cleanupModelResources()`, `loadModel()`, `loadAvailableModels()`, and `loadCurrentTranscriptionModel()` which are called from this file.
EXTERNAL_DEPENDENCY: `WhisperState+UI.swift` -- Likely implements UI-related logic such as `showRecorderPanel()`, `hideRecorderPanel()`, and `dismissMiniRecorder()`.
EXTERNAL_DEPENDENCY: `PowerModeSessionManager.shared` -- A singleton that manages application-wide "Power Mode" configurations, which are applied during recording.
EXTERNAL_DEPENDENCY: `AIEnhancementService` -- An external service, likely wrapping an API like OpenAI, that takes text and enhances it based on context and prompts. Triggered by `enhance()`.
EXTERNAL_DEPENDENCY: `TranscriptionServiceRegistry` -- A factory/registry that creates and manages different transcription backends (local, Parakeet, etc.). Triggered by `createSession()` and `transcribe()`.
EXTERNAL_DEPENDENCY: `CursorPaster` -- A global utility for simulating user input to paste text and press Enter in whatever application is currently active.
EXTERNAL_DEPENDENCY: `SoundManager.shared` -- A singleton responsible for playing application-wide sound effects, such as the recording stop sound.
EXTERNAL_DEPENDENCY: `NotificationManager.shared` -- A singleton that displays user-facing system notifications for events like recording failures.
EXTERNAL_DEPENDENCY: `ActiveWindowService.shared` -- A singleton that applies configurations based on the currently active application window.
EXTERNAL_DEPENDENCY: `WordReplacementService.shared` -- A singleton that manages and applies user-defined word substitutions to transcribed text.
EXTERNAL_DEPENDENCY: `PromptDetectionService` -- A service that inspects transcribed text for special keywords that temporarily alter the behavior of `AIEnhancementService`.
EXTERNAL_DEPENDENCY: `Recorder` -- The class responsible for the low-level audio recording via AVFoundation. It provides audio data via the `onAudioChunk` callback.
EXTERNAL_DEPENDENCY: (any UI view) -- Any SwiftUI view that observes `@Published` properties on `WhisperState` and listens for `.transcriptionCreated` or `.transcriptionCompleted` notifications to update its display.
EXTERNAL_DEPENDENCY: `UserDefaults.standard` -- A global key-value store for user preferences like `RecorderType` and `IsTextFormattingEnabled`.
```
