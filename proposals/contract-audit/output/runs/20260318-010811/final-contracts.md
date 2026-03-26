# Final Contract Spec
# Generated: 2026-03-18
# Auditor artifacts: runs/20260318-010811/claude-artifacts/all-artifacts.md
# Adversary review: runs/20260318-010811/codex-review.md
# DEGRADED: no

---

## Merge Summary

- CONFIRM applied: 37 contracts carried forward as-is
- DISPUTE corrections applied: 16 (see notes on each disputed contract)
- ADD contracts integrated: 3 (P-010, P-011, D-009)
- META_ISSUE scope fixes: 3 (E-002, D-003, P-009)
- Final contract count: 56

---

## M — Mutation Contracts

### M-001: App Support Directories Created on Init

Trigger:      WhisperState.init() 被呼叫
Input:        FileManager.default, Bundle ID "com.prakashjoshipax.VoiceInk"
Output:       Application Support/com.prakashjoshipax.VoiceInk/WhisperModels/ 和 Recordings/ 目錄被創建（若不存在）
Condition:    withIntermediateDirectories: true，不會重複創建
Ordering:     after setupNotifications()（line 131 < 132-133）[DISPUTE APPLIED: ordering corrected; setupNotifications() runs at line 131, BEFORE directory creation at 132-133]
Risk:         MEDIUM -- 目錄創建失敗被靜默吞掉（logger.error 但繼續執行）；後續錄音失敗在寫入階段而非初始化階段
Evidence:     WhisperState.swift:131-133 -- `setupNotifications()` / `createModelsDirectoryIfNeeded()` / `createRecordingsDirectoryIfNeeded()`
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

### M-002: Transcription Entity Created Before Transcription Starts

Trigger:      toggleRecord() 呼叫時 recordingState == .recording 且 shouldCancelRecording == false
Input:        AVURLAsset duration (async)、recordedFile URL
Output:       Transcription entity 以 .pending status 插入 ModelContext 並 save()
Condition:    recordedFile 必須存在（非 nil）；若為 nil 走 E-005 路徑
Ordering:     before NotificationCenter.post(.transcriptionCreated)（line 163-165 < 166）；before transcribeAudio()（line 163-165 < 168）
Risk:         HIGH -- Transcription entity 在轉錄完成前即存在 DB；呼叫者收到 .transcriptionCreated 時 text == ""
Evidence:     WhisperState.swift:155-165 -- `let transcription = Transcription(text: "", ..., transcriptionStatus: .pending); modelContext.insert(transcription); try? modelContext.save()`
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### M-003: Audio File UUID Path Assigned Before Recording Starts

Trigger:      toggleRecord() 進入 start-recording 分支
Input:        UUID().uuidString、recordingsDirectory
Output:       self.recordedFile = permanentURL（.wav 副檔名）；實際檔案在 recorder.startRecording() 時建立
Condition:    requestRecordPermission 返回 true（目前永遠為 true，見 E-002）
Ordering:     before recorder.startRecording()；before pendingChunks buffer 設置
Risk:         MEDIUM -- 若 startRecording 失敗，recordedFile 被設為 nil（line 283）但實際檔案可能已被部分建立
Evidence:     WhisperState.swift:204-206 -- `let fileName = "\(UUID().uuidString).wav"; let permanentURL = ...; self.recordedFile = permanentURL`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### M-004: Audio File Deleted on Cancel

Trigger:      shouldCancelRecording == true 且 recordedFile 存在，toggleRecord() 的取消分支
Input:        recordedFile URL
Output:       FileManager.default.removeItem(at: recordedFile)；currentSession?.cancel()；recordingState = .idle
Condition:    shouldCancelRecording 必須為 true 且 recordedFile 非 nil
Ordering:     after recorder.stopRecording()；before cleanupModelResources()
Risk:         MEDIUM -- 使用 try? 吞掉 removeItem 錯誤；孤立的 .wav 檔將累積在 recordingsDirectory
Evidence:     WhisperState.swift:170-176 -- `currentSession?.cancel(); currentSession = nil; try? FileManager.default.removeItem(at: recordedFile); recordingState = .idle`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### M-005: Transcription Text Mutated by Post-Processing Chain

Trigger:      transcribeAudio() 成功取得原始 transcript
Input:        原始 text string from TranscriptionSession/serviceRegistry
Output:       text 依序被 TranscriptionOutputFilter、zh-TW 轉換、trimmingCharacters、WhisperTextFormatter、WordReplacementService 修改；AI enhancement 和 paste 是條件性的
Condition:    各步驟均有條件守衛（見 P-001 到 P-009）
Ordering:     固定順序，不可更改（見 P-001）
Risk:         HIGH -- 任一步驟改變內容都可能影響後續步驟；WordReplacementService 依賴 modelContext（D-004）；zh-TW 在 trim 之前，trim 在 format 之前
Evidence:     WhisperState.swift:360-420 -- sequential transformations
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  true

---

### M-006: Transcription Metadata Written to SwiftData Entity

Trigger:      post-processing chain 完成後（或失敗後）
Input:        transcription entity（M-002 建立），processed text, duration, model name, power mode info
Output:       **Success path**: transcription.text, .duration, .transcriptionModelName, .transcriptionDuration, power mode fields 均被設定；**Failure path (catch)**: only transcription.text and transcription.transcriptionStatus are set；modelContext.save() 在兩條路徑均呼叫
Condition:    成功路徑和失敗路徑都會 save()（line 439）
Ordering:     after all post-processing; before NotificationCenter.post(.transcriptionCompleted)
Risk:         HIGH -- modelContext.save() 使用 try? 靜默吞掉 save 錯誤；failure path 中 duration/model/power mode 字段不被設定 [DISPUTE APPLIED: failure path metadata limitation clarified]
Evidence:     WhisperState.swift:389-394, 428, 435-439 -- `transcription.text = text ... try? modelContext.save()`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### M-007: shouldCancelRecording Reset Only at Normal Completion of transcribeAudio

Trigger:      transcribeAudio() 正常結束（非 early return）
Input:        N/A
Output:       shouldCancelRecording = false
Condition:    只在非 early-return 路徑執行（line 476）；checkCancellationAndCleanup() 的 early return 路徑**不會**重置此 flag；下一次 toggleRecord start（line 197）會重置此 flag
Ordering:     last statement before function exits (line 476)
Risk:         HIGH -- 多個 early return 路徑不執行此重置，導致 shouldCancelRecording 停留在 true；下一次 toggleRecord 的 start 路徑在 line 197 重置，但在此期間讀取 flag 的呼叫者看到 stale true [DISPUTE APPLIED: downgraded from CRITICAL; line 197 resets flag at next recording start]
Evidence:     WhisperState.swift:476 -- `shouldCancelRecording = false`
              WhisperState.swift:197 -- `shouldCancelRecording = false` (at recording start — Codex correction)
              WhisperState.swift:483-489 -- `checkCancellationAndCleanup()` 不重置 flag
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### M-008: Trial Expired Prepends Promotional Text with Newline Separator

Trigger:      transcription 完成且 licenseViewModel.licenseState == .trialExpired
Input:        finalPastedText
Output:       "Your trial has expired. Upgrade to VoiceInk Pro at tryvoiceink.com/buy\n[textToPaste]" 被組合（單一 \n 分隔，非 \n\n）
Condition:    case .trialExpired = licenseViewModel.licenseState；transcription.transcriptionStatus == .completed
Ordering:     after all post-processing; before CursorPaster.pasteAtCursor()
Risk:         MEDIUM -- 每次貼上都包含廣告文字；UX 合約；\n 為單一換行符（非雙換行） [DISPUTE APPLIED: prefix uses \n separator, not \n\n as previously stated]
Evidence:     WhisperState.swift:449-451 -- `textToPaste = "Your trial has expired...\n\(textToPaste)"`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

## L — Lifecycle Contracts

### L-001: RecordingState Transitions (State Machine)

Trigger:      toggleRecord()、transcribeAudio() 中的各個狀態轉換點
Input:        當前 recordingState、shouldCancelRecording
Output:       recordingState 依序轉換：idle→recording→transcribing→enhancing→idle；.busy 狀態由 WhisperState+UI 使用
Condition:    .starting 狀態存在於 enum（line 12）但**從未被設定**（dead state）；.busy 狀態由 WhisperState+UI.swift 使用（lines 66, 100）
Ordering:     idle→recording（line 218）; recording→transcribing（line 151）; transcribing→enhancing（line 408）; →idle（透過 dismissMiniRecorder 或 cleanupModelResources）; busy→idle（WhisperState+UI.swift:100）
Risk:         CRITICAL -- .starting 是 dead state；重構若引入 .starting 會改變 SwiftUI 顯示邏輯；.busy 狀態在 WhisperState+UI 中使用但未在主審計中發現 [DISPUTE APPLIED: .busy state added from WhisperState+UI.swift:66,100]
Evidence:     WhisperState.swift:10-17 -- RecordingState enum（含 .starting dead state）
              WhisperState+UI.swift:66,100 -- `recordingState = .busy` / `recordingState = .idle`
Scope:        class
Seam_Type:    object
Pinch_Point:  true

---

### L-002: recorderType.didSet Recreates UI Panel With 50ms Delay

Trigger:      self.recorderType property 被賦新值
Input:        oldValue、isMiniRecorderVisible
Output:       若正在顯示：隱藏舊視窗 → nil 化管理器 → Task { @MainActor: sleep 50ms → showRecorderPanel() }；UserDefaults 永遠更新
Condition:    只有當 isMiniRecorderVisible == true 時才重建視窗
Ordering:     隱藏舊視窗 before sleep(50ms) before showRecorderPanel()
Risk:         HIGH -- 50ms sleep 是規避競態條件的 workaround；低端機器視窗 hide 可能超過 50ms
Evidence:     WhisperState.swift:36-51 -- `didSet { ... Task { @MainActor in try? await Task.sleep(nanoseconds: 50_000_000); showRecorderPanel() } ... UserDefaults.standard.set(recorderType, ...) }`
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

### L-003: isMiniRecorderVisible.didSet Triggers Panel Via DispatchQueue.main.async

Trigger:      self.isMiniRecorderVisible property 被賦新值
Input:        新的 isMiniRecorderVisible 值（true/false）
Output:       true → DispatchQueue.main.async { showRecorderPanel() }；false → DispatchQueue.main.async { hideRecorderPanel() }
Condition:    無條件——每次賦值都觸發
Ordering:     非同步（enqueued to main queue），在 didSet 返回後執行
Risk:         HIGH -- DispatchQueue.main.async 造成副作用延遲；若呼叫者立即讀取視窗狀態可能看到過期狀態
Evidence:     WhisperState.swift:54-65 -- `didSet { DispatchQueue.main.async { [self] in if isMiniRecorderVisible { showRecorderPanel() } else { hideRecorderPanel() } } }`
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

### L-004: AI Prompt Detection Settings Temporarily Applied and Restored

Trigger:      enhancementService 非 nil 且 isConfigured == true
Input:        transcribed text、promptDetectionService、enhancementService
Output:       applyDetectionResult() 臨時修改 enhancementService 設定；完成後 restoreOriginalSettings() 恢復
Condition:    result.shouldEnableAI 必須為 true 才執行 restore（line 470）
Ordering:     applyDetectionResult()（line 400）before enhance()（line 412）；restore（line 471）after main body but before dismissMiniRecorder()
Risk:         HIGH -- 若 early return（checkCancellationAndCleanup 在 enhance 後返回 true）發生在 restore 之前，enhancementService 設定將永久停留在臨時狀態
Evidence:     WhisperState.swift:398-401, 468-472 -- `await promptDetectionService.applyDetectionResult(...); ... await promptDetectionService.restoreOriginalSettings(...)`
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### L-005: dismissMiniRecorder Called as Final Cleanup

Trigger:      transcribeAudio() 正常完成（非 early return 路徑）
Input:        N/A
Output:       miniRecorder 被關閉
Condition:    只在 line 474 這一條路徑執行；checkCancellationAndCleanup() early return 路徑不執行
Ordering:     after paste operation; after promptDetection restore; before shouldCancelRecording = false
Risk:         MEDIUM -- early return 路徑（透過 cleanupModelResources）可能不關閉 miniRecorder
Evidence:     WhisperState.swift:474 -- `await self.dismissMiniRecorder()`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### L-006: No Model Selected Shows Error Notification

Trigger:      toggleRecord() 進入 start-recording 分支（else 分支，非 .recording 狀態），且 currentTranscriptionModel == nil
Input:        N/A
Output:       NotificationManager.shared.showNotification(title: "No AI Model Selected", type: .error)；函式 return
Condition:    currentTranscriptionModel == nil；可從任何非 .recording 狀態觸發 [DISPUTE APPLIED: guard runs in else branch, not strictly from .idle state]
Ordering:     first check in start-recording branch
Risk:         LOW -- 行為正確；state 不保證維持 .idle（取決於呼叫時的狀態）
Evidence:     WhisperState.swift:188-196 -- `guard currentTranscriptionModel != nil else { ... showNotification("No AI Model Selected") ... return }`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

## N — Notification Contracts

### N-001: .transcriptionCreated Posted with Empty Text (Before Transcription)

Trigger:      Transcription entity 插入 ModelContext 後
Input:        Transcription object（status: .pending, text: ""）
Output:       NotificationCenter.default.post(name: .transcriptionCreated, object: transcription)
Condition:    recordedFile 存在且 shouldCancelRecording == false
Ordering:     after modelContext.insert() + save()（line 164-165）; **before** transcribeAudio()（line 168）
Risk:         HIGH -- 觀察者在 .transcriptionCreated 時收到 text: "" 的 Transcription；若觀察者假設通知時 text 已填入，將讀取空字串
Evidence:     WhisperState.swift:166 -- `NotificationCenter.default.post(name: .transcriptionCreated, object: transcription)`
Scope:        method
Seam_Type:    none
Pinch_Point:  true

---

### N-002: .transcriptionCompleted Always Posted (Success and Failure, But Not All Early Returns)

Trigger:      transcribeAudio() 的主要 do-catch 結束後
Input:        transcription object（可能為 completed 或 failed 狀態）
Output:       NotificationCenter.default.post(name: .transcriptionCompleted, object: transcription)
Condition:    此通知在 success 和 catch 兩條路徑後均發送（line 442 在 catch 之後）；但 early return 路徑（invalid URL, cancellation at start）**不會**發送此通知
Ordering:     after modelContext.save()（line 439）; before checkCancellationAndCleanup()（line 444）
Risk:         HIGH -- 觀察者必須判斷 transcription.transcriptionStatus；early return 路徑不發送通知，觀察者可能永遠等待
Evidence:     WhisperState.swift:442 -- `NotificationCenter.default.post(name: .transcriptionCompleted, object: transcription)`
Scope:        method
Seam_Type:    none
Pinch_Point:  true

---

### N-003: setupNotifications Registers Observers at Init

Trigger:      WhisperState.init()（line 131）
Input:        N/A（實作於 extension）
Output:       NotificationCenter 觀察者被註冊
Condition:    在 serviceRegistry 初始化之後執行
Ordering:     after serviceRegistry init（129 < 131）; before directory creation（131 < 132）[DISPUTE NOTE: consistent with M-001 correction — setupNotifications is before directories]
Risk:         MEDIUM -- setupNotifications() 實作在 extension 中，但 deinit 的 removeObserver(self) 依賴此處 self，形成跨 extension 隱含合約
Evidence:     WhisperState.swift:131 -- `setupNotifications()`
              WhisperState.swift:496 -- `NotificationCenter.default.removeObserver(self)`
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

### N-004: deinit Removes All Self-Based Observers

Trigger:      WhisperState 實例被釋放
Input:        N/A
Output:       NotificationCenter.default.removeObserver(self)
Condition:    無條件
Ordering:     最終清理
Risk:         LOW -- 若觀察者是透過 addObserver(forName:...:using:) 以 token 方式持有，removeObserver(self) 不移除這些 token 型觀察者
Evidence:     WhisperState.swift:495-497 -- `deinit { NotificationCenter.default.removeObserver(self) }`
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

## S — Synchronization Contracts

### S-001: WhisperState @MainActor Isolation

Trigger:      任何對 WhisperState 屬性或方法的存取
Input:        N/A
Output:       所有 @Published 屬性更新、UI 副作用均在主執行緒執行
Condition:    @MainActor class 宣告（line 19）
Risk:         MEDIUM -- Task.detached（S-004）脫離 @MainActor 隔離；Task.detached 內部存取 self 的屬性使用 await（actor hops），這是正確的做法，不構成隔離違反 [DISPUTE APPLIED: downgraded from HIGH; detached block correctly uses await for actor-isolated state]
Evidence:     WhisperState.swift:19 -- `@MainActor class WhisperState: NSObject, ObservableObject`
              WhisperState.swift:252-275 -- `Task.detached { [weak self] in ... await self.currentTranscriptionModel ... }` (uses await correctly)
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

### S-002: Audio Chunks Buffered via OSAllocatedUnfairLock Before Session Ready

Trigger:      錄音開始，TranscriptionSession.prepare() 尚未完成
Input:        recorder.onAudioChunk 收到的 Data 片段
Output:       pendingChunks (OSAllocatedUnfairLock<[Data]>) 累積音訊資料
Condition:    realCallback 從 session.prepare() 返回後才換入
Ordering:     buffering before callback swap; callback swap before flush; flush before new chunks
Risk:         HIGH -- 若 session.prepare() 非常慢，pendingChunks 可能累積大量資料；若 Task 在 prepare() 完成前被取消，buffered data 被丟棄
Evidence:     WhisperState.swift:209-212 -- `let pendingChunks = OSAllocatedUnfairLock(initialState: [Data]()); self.recorder.onAudioChunk = { data in pendingChunks.withLock { $0.append(data) } }`
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### S-003: Callback Swap Must Precede Buffer Flush

Trigger:      session.prepare() 返回 realCallback（非 nil）
Input:        pendingChunks buffer、realCallback closure
Output:       self.recorder.onAudioChunk = realCallback；pendingChunks 中所有資料依序傳給 realCallback；pendingChunks 被清空
Condition:    realCallback 非 nil；若為 nil（line 245-248），onAudioChunk 設為 nil，buffer 清空
Ordering:     **CRITICAL**: onAudioChunk 必須先設為 realCallback（line 237）**再**讀取 buffered chunks（line 239-243）
Risk:         CRITICAL -- 若順序錯誤（先讀 buffer 再換 callback），新到達的 chunk 落入 old buffer 後被丟棄；目前實作順序正確，重構必須保持此原子性語意
Evidence:     WhisperState.swift:237-244 -- `self.recorder.onAudioChunk = realCallback; let buffered = pendingChunks.withLock { ... }; for chunk in buffered { realCallback(chunk) }`
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### S-004: Task.detached for Model Loading is NOT Cancellable

Trigger:      錄音成功開始後（line 252）
Input:        self（weak）、currentTranscriptionModel、enhancementService
Output:       loadModel() 或 parakeet loadModel()；captureClipboardContext()；captureScreenContext()
Condition:    Task.detached 脫離 @MainActor 和父 Task 的取消傳播；shouldCancelRecording 對此 Task 無效
Risk:         HIGH -- 若使用者在 Task.detached 執行中取消錄音，模型載入仍繼續；多次快速觸發 toggleRecord 可能造成多個 Task.detached 並行執行
Evidence:     WhisperState.swift:252 -- `Task.detached { [weak self] in ... }`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### S-005: Stop Sound Played via Unstructured Task with Optional Delay

Trigger:      transcribeAudio() 開始執行
Input:        UserDefaults.standard.bool(forKey: "isSystemMuteEnabled")
Output:       若 isSystemMuteEnabled：延遲 200ms 後 SoundManager.shared.playStopSound()；否則：立即呼叫
Condition:    Unstructured Task（不受 shouldCancelRecording 控制）
Risk:         LOW -- 若 transcription 很快完成，stop sound 可能在轉錄結果已貼上後才播放
Evidence:     WhisperState.swift:322-330 -- `Task { let isSystemMuteEnabled = ...; if isSystemMuteEnabled { try? await Task.sleep(nanoseconds: 200_000_000) }; ... SoundManager.shared.playStopSound() }`
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  false

---

### S-006: Paste Scheduled via DispatchQueue.main.asyncAfter 50ms — Before dismissMiniRecorder Await

Trigger:      transcribeAudio() 成功完成且 finalPastedText 非 nil
Input:        textToPaste、UserDefaults "AppendTrailingSpace"
Output:       50ms 後 CursorPaster.pasteAtCursor() 在 main queue 執行
Condition:    transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue
Ordering:     asyncAfter **scheduled** at line 454 (before dismissMiniRecorder await at line 474); actual paste **execution** occurs 50ms after scheduling, likely after dismissMiniRecorder completes [DISPUTE APPLIED: scheduling order vs execution order clarified]
Risk:         HIGH -- 50ms asyncAfter 使 paste 發生在 dismissMiniRecorder 之後（通常）；若 app 在此期間改變焦點，paste 目標可能不正確
Evidence:     WhisperState.swift:454-456 -- `DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { ... CursorPaster.pasteAtCursor(textToPaste + ...) }`
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  true

---

### S-007: Auto-Send pressEnter with Additional 200ms Delay

Trigger:      paste 執行後，若 isAutoSendEnabled == true
Input:        PowerModeManager.shared.currentActiveConfiguration（在 main asyncAfter closure 中即時讀取）
Output:       DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { CursorPaster.pressEnter() }
Ordering:     after pasteAtCursor; 200ms delay
Risk:         MEDIUM -- 若使用者在 200ms 內切換 power mode，pressEnter 可能被錯誤觸發或不觸發
Evidence:     WhisperState.swift:459-463 -- `if let activeConfig = powerMode.currentActiveConfiguration, activeConfig.isAutoSendEnabled { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { CursorPaster.pressEnter() } }`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

## E — Error Handling Contracts

### E-001: startRecording Failure Shows Notification and Dismisses Panel

Trigger:      recorder.startRecording() throws an error
Input:        error description
Output:       logger.error()；NotificationManager.shared.showNotification(title: "Recording failed to start", type: .error)；dismissMiniRecorder()；recordedFile = nil
Condition:    catch block 在 toggleRecord() 的 start-recording Task 中
Risk:         MEDIUM -- recordedFile 被設為 nil，但若檔案在 startRecording 拋出前已部分建立，孤立檔案不被清理（有意設計）
Evidence:     WhisperState.swift:277-284 -- `} catch { self.logger.error(...); await NotificationManager.shared.showNotification(...); await self.dismissMiniRecorder(); self.recordedFile = nil }`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### E-002: requestRecordPermission Always Grants Permission (No-Op)

Trigger:      toggleRecord() 呼叫 requestRecordPermission
Input:        N/A
Output:       response(true)——永遠授權
Condition:    無條件
Risk:         HIGH -- 真實的 microphone permission 請求被旁路；callback-based 介面（而非 async/await）在引入真實權限請求時需要大量重構
Evidence:     WhisperState.swift:293-295 -- `private func requestRecordPermission(response: @escaping (Bool) -> Void) { response(true) }`
Scope:        method  [META_ISSUE APPLIED: method scope, not class]
Seam_Type:    preprocessing
Pinch_Point:  true

---

### E-003: Transcription Failure Written to Entity Text Field

Trigger:      transcribeAudio() 的 catch block，或 invalid URL early return
Input:        LocalizedError（或任意 Error）
Output:       transcription.text = "Transcription Failed: \(fullErrorText)"；transcription.transcriptionStatus = .failed；modelContext.save()
Condition:    任何從 do 塊逃逸的 error；invalid URL（line 303-305）
Risk:         MEDIUM -- "Transcription Failed:" prefix 是 contract（呼叫者可能 string-match 此前綴判斷失敗）
Evidence:     WhisperState.swift:430-437 -- `transcription.text = "Transcription Failed: \(fullErrorText)"; transcription.transcriptionStatus = TranscriptionStatus.failed.rawValue`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### E-004: AI Enhancement Failure Sets enhancedText to Error String

Trigger:      enhancementService.enhance() throws
Input:        error description
Output:       transcription.enhancedText = "Enhancement failed: \(error)"；原始 text 保留（finalPastedText 保持為原始轉錄）
Condition:    catch block 在 AI enhancement do-block 中
Risk:         MEDIUM -- finalPastedText 保持原始 text——正確的降級行為；但 transcription.enhancedText 包含錯誤字串
Evidence:     WhisperState.swift:421-424 -- `} catch { transcription.enhancedText = "Enhancement failed: \(error)" ... }`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### E-005: No Recorded File After Stop — Silent Error Recovery

Trigger:      recorder.stopRecording() 後 recordedFile == nil
Input:        N/A
Output:       logger.error()；currentSession?.cancel()；recordingState = .idle（無用戶通知）
Condition:    recordedFile is nil after recorder.stopRecording()
Risk:         HIGH -- 不發送 .transcriptionCreated 或 .transcriptionCompleted 通知；UI 恢復 idle 但使用者不會收到錯誤通知
Evidence:     WhisperState.swift:178-185 -- `logger.error("❌ No recorded file found after stopping recording"); currentSession?.cancel(); ... recordingState = .idle`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### E-006: Directory Creation Errors Silently Logged

Trigger:      createRecordingsDirectoryIfNeeded() 中 FileManager.createDirectory 失敗
Input:        FileManager error
Output:       logger.error() only；繼續初始化
Risk:         LOW -- 目錄創建失敗的後果延遲到錄音時才顯現；init 不拋出錯誤，呼叫者無法感知
Evidence:     WhisperState.swift:142-144 -- `} catch { logger.error("Error creating recordings directory: \(error.localizedDescription)") }`
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

## C — Cancellation Contracts

### C-001: shouldCancelRecording Flag Gates Cancel Path in toggleRecord

Trigger:      toggleRecord() 呼叫時 recordingState == .recording 且 shouldCancelRecording == true
Input:        shouldCancelRecording flag（@Published）
Output:       currentSession?.cancel()；FileManager.removeItem(recordedFile)；recordingState = .idle；cleanupModelResources()
Condition:    else branch at line 169
Risk:         MEDIUM -- shouldCancelRecording 是 @Published var，但 WhisperState 是 @MainActor 類別，存取是串行的，不存在 race condition；risk 是邏輯正確性而非 thread safety [DISPUTE APPLIED: downgraded from HIGH; @MainActor serializes access]
Evidence:     WhisperState.swift:154-177 -- `if !shouldCancelRecording { ... } else { currentSession?.cancel(); ... }`
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### C-002: Cancellation Checked at 5 Points During Transcription

Trigger:      shouldCancelRecording == true 在 transcribeAudio() 執行期間
Input:        shouldCancelRecording flag
Output:       (1)line 309-315: idle+cleanup+return；(2)line 374: checkCancellationAndCleanup→return；(3)line 406: checkCancellationAndCleanup→return；(4)line 424: checkCancellationAndCleanup→return；(5)line 444: checkCancellationAndCleanup→return
Condition:    shouldCancelRecording == true
Ordering:     5 個檢查點分布在轉錄管線中 [DISPUTE APPLIED: count corrected from 4 to 5; lines 309, 374, 406, 424, 444]
Risk:         HIGH -- 若 AI enhance 耗時 30 秒，取消需等到 enhance 完成後才在 line 424 或 444 被處理
Evidence:     WhisperState.swift:309-315, 374, 406, 424, 444 -- cancel check points
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### C-003: defer Block May Double-Call cleanupModelResources

Trigger:      transcribeAudio() 執行到 defer block（line 332-338）且 shouldCancelRecording == true
Input:        shouldCancelRecording flag
Output:       Task { await cleanupModelResources() }（新的 unstructured Task）
Condition:    defer 在函式任何出口點執行；early return 路徑已呼叫 cleanupModelResources，defer 此時仍會執行——可能**重複呼叫**
Risk:         HIGH -- double cleanup 是隱含的 bug；需確認 cleanupModelResources 是否 idempotent
Evidence:     WhisperState.swift:332-338 -- `defer { if shouldCancelRecording { Task { await cleanupModelResources() } } }`
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### C-004: shouldCancelRecording Not Reset on Early Return Paths

Trigger:      transcribeAudio() 透過 checkCancellationAndCleanup() early return
Input:        shouldCancelRecording == true
Output:       函式 return；shouldCancelRecording 保持 true，直到下一次 toggleRecord start（line 197）重置
Condition:    line 476 的 `shouldCancelRecording = false` 只在函式正常到達末尾時執行；line 197 在下一次 recording start 時重置
Risk:         HIGH -- flag 在 early return 後維持 true；下次 toggleRecord 的 start 路徑在 line 197 重置；中間期間讀取此 flag 的觀察者看到 stale true [DISPUTE APPLIED: downgraded from CRITICAL; next recording start resets at line 197]
Evidence:     WhisperState.swift:476 -- `shouldCancelRecording = false` (only at normal completion)
              WhisperState.swift:197 -- `shouldCancelRecording = false` (at next recording start)
              WhisperState.swift:483-489 -- `checkCancellationAndCleanup()` does not reset flag
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### C-005: Task.detached Model Loading Cannot Be Cancelled

Trigger:      Task.detached 在 toggleRecord start 路徑中啟動
Input:        shouldCancelRecording（不被此 Task 觀察）
Output:       loadModel() / parakeet loadModel() / captureClipboardContext() / captureScreenContext() 繼續執行
Risk:         HIGH -- 多次快速觸發 toggleRecord 可能造成多個 Task.detached 並行執行 loadModel()，造成 whisperContext 的競態條件
Evidence:     WhisperState.swift:252 -- `Task.detached { [weak self] in ...`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

## D — Dependency Contracts

### D-001: PowerModeSessionManager.shared Configured with Self in init

Trigger:      WhisperState.init()（line 124-126）
Input:        self（WhisperState）、enhancementService
Output:       PowerModeSessionManager.shared 持有對 WhisperState 的 reference
Condition:    只有當 enhancementService 非 nil 時執行
Risk:         MEDIUM -- PowerModeSessionManager 持有 WhisperState 的 reference，但 WhisperState 並未 store PowerModeSessionManager；retain cycle 風險較低（非雙向強引用）[DISPUTE APPLIED: downgraded from HIGH; no reciprocal manager reference stored in WhisperState]
Evidence:     WhisperState.swift:124-126 -- `PowerModeSessionManager.shared.configure(whisperState: self, enhancementService: enhancementService)`
              PowerModeSessionManager.swift:26 -- `private var whisperState: WhisperState?`
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

### D-002: TranscriptionServiceRegistry Created with Weak Self Reference

Trigger:      WhisperState.init()（line 129）
Input:        self（WhisperState）、modelsDirectory
Output:       self.serviceRegistry = TranscriptionServiceRegistry(whisperState: self, ...)
Condition:    在 super.init() 之後（line 121）
Risk:         LOW -- serviceRegistry 持有 WhisperState 的 weak reference（TranscriptionServiceRegistry.swift:8）；retain cycle 風險已排除 [DISPUTE APPLIED: downgraded from HIGH; weak storage confirmed at TranscriptionServiceRegistry.swift:8]
Evidence:     WhisperState.swift:77, 129 -- `internal var serviceRegistry: TranscriptionServiceRegistry!`
              TranscriptionServiceRegistry.swift:8 -- `private weak var whisperState: WhisperState?`
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

### D-003: currentTranscriptionModel Must Be Set Before Recording Starts

Trigger:      toggleRecord() 進入 start-recording 分支
Input:        self.currentTranscriptionModel
Output:       若 nil：顯示錯誤通知並 return；若非 nil：繼續錄音
Condition:    guard at line 188
Risk:         MEDIUM -- currentTranscriptionModel 由 loadCurrentTranscriptionModel()（init 中）從 UserDefaults 載入；若無值，使用者必須先選擇 model
Evidence:     WhisperState.swift:188-196 -- `guard currentTranscriptionModel != nil else { ... return }`
Scope:        method  [META_ISSUE APPLIED: method scope, not class]
Seam_Type:    object
Pinch_Point:  false

---

### D-004: WordReplacementService Requires Valid ModelContext

Trigger:      transcribeAudio() 執行到 WordReplacementService.shared.applyReplacements（line 383）
Input:        text、modelContext
Output:       text 被 word replacement 修改
Condition:    modelContext 由 init 注入，不可為 nil
Risk:         MEDIUM -- modelContext 在長時間轉錄中可能有 concurrent writes
Evidence:     WhisperState.swift:383 -- `text = WordReplacementService.shared.applyReplacements(to: text, using: modelContext)`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### D-005: ActiveWindowService Applied After Recording Starts (~50-200ms Gap)

Trigger:      錄音成功開始後（line 223）
Input:        powerModeId（可選 UUID）
Output:       ActiveWindowService.shared.applyConfiguration() 解析並應用 power mode 設定
Condition:    在 recorder.startRecording() 成功後才呼叫
Ordering:     after recordingState = .recording（line 218）; before session creation（line 226）
Risk:         HIGH -- 錄音已開始但 power mode 尚未解析（~50-200ms 窗口）；在此期間音訊已被錄製但 language/prompt 尚未設定
Evidence:     WhisperState.swift:223 -- `await ActiveWindowService.shared.applyConfiguration(powerModeId: powerModeId)`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### D-006: Bundle Model URL Has 3 Fallback Paths

Trigger:      modelUrl computed property 被存取
Input:        Bundle.main
Output:       在 Models/ subdirectory、bundle root、或 bundleURL/Models/ 中搜尋 ggml-base.en.bin；返回第一個存在的 URL，或 nil
Risk:         LOW -- 三個路徑覆蓋不同部署情境
Evidence:     WhisperState.swift:79-92 -- `let possibleURLs = [Bundle.main.url(forResource: "ggml-base.en", ...), ...]`
Scope:        class
Seam_Type:    preprocessing
Pinch_Point:  false

---

### D-007: enhancementService Optional — All Enhancement Paths Guarded With isConfigured Check

Trigger:      transcribeAudio() 進入 AI enhancement 檢查
Input:        enhancementService（Optional）
Output:       若 nil：跳過 promptDetection 和 AI enhancement；若非 nil 但 !isConfigured：跳過 promptDetection（line 397）但 AI enhance 也跳過（line 403）；若非 nil 且 isConfigured：執行完整 AI pipeline
Condition:    line 397: `if let enhancementService = enhancementService, enhancementService.isConfigured`；line 403: `if let enhancementService = enhancementService, enhancementService.isEnhancementEnabled, enhancementService.isConfigured`
Ordering:     promptDetection guard（line 397）before AI enhance guard（line 403）
Risk:         MEDIUM -- isConfigured == false 時 promptDetection 和 AI enhance 均不執行；promptDetectionResult 不被設定，restore 不被呼叫 [DISPUTE APPLIED: clarified that promptDetection also guarded by isConfigured at line 397]
Evidence:     WhisperState.swift:397, 403-405 -- guard conditions with isConfigured
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### D-008: PowerModeManager.shared Read During Transcription

Trigger:      transcribeAudio() 在 post-processing 中（lines 369-372）
Input:        PowerModeManager.shared.currentActiveConfiguration
Output:       powerModeName、powerModeEmoji 寫入 transcription entity
Risk:         LOW -- 僅讀取、無副作用；記錄的 power mode 是讀取時的值
Evidence:     WhisperState.swift:369-372 -- `let powerModeManager = PowerModeManager.shared; let activePowerModeConfig = powerModeManager.currentActiveConfiguration`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### D-009: ActiveWindowService Bootstrap Dependency at App Startup [ADD]

Trigger:      App 初始化時（VoiceInk.swift:106-108）
Input:        activeWindowService.configure...；configureWhisperState(whisperState)
Output:       ActiveWindowService.shared 的行為依賴於 app 啟動時的 configure 呼叫
Condition:    在任何 recording 前
Ordering:     must precede any recording flow that calls ActiveWindowService.shared.applyConfiguration()
Risk:         MEDIUM -- 若 configure 未在 recording 前呼叫，applyConfiguration() 行為未定義
Evidence:     VoiceInk.swift:106-108 -- `activeWindowService.configure...; configureWhisperState(whisperState)`
Scope:        module
Seam_Type:    object
Pinch_Point:  false

---

## P — Propagation Contracts

### P-001: Post-Processing Chain Partially-Fixed Execution Order

Trigger:      成功取得原始 transcript
Input:        原始 text string
Output:       text 通過固定順序的轉換步驟；steps 1-5 是無條件或 feature-flag 控制的；steps 6-7（enhance、paste）是條件性的
Ordering:     1. TranscriptionOutputFilter.filter（line 360, unconditional）
              2. ChineseConverter.simplifiedToTraditional（zh-TW, line 365）
              3. text.trimmingCharacters（line 376, unconditional）
              4. WhisperTextFormatter.format（IsTextFormattingEnabled, line 379）
              5. WordReplacementService.applyReplacements（line 383, unconditional）
              6. AIenhancement.enhance（isEnhancementEnabled+isConfigured, conditional）
              7. CursorPaster.pasteAtCursor（line 456, conditional on .completed status）
Risk:         CRITICAL -- steps 1-5 的順序改變將產生不同結果；steps 6-7 是條件性的；重構時 steps 1-5 的順序必須完整保留 [DISPUTE APPLIED: clarified that steps 6-7 are conditional branches]
Evidence:     WhisperState.swift:360-420 -- sequential text transformations
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  true

---

### P-002: TranscriptionOutputFilter Applied First (Unconditional)

Trigger:      transcript text 可用
Input:        原始 transcript string
Output:       filter() 的輸出 text
Condition:    無條件（無 UserDefaults 守衛）
Ordering:     first in post-processing chain（line 360）
Risk:         MEDIUM -- 無法被 feature flag 關閉；重構時若跳過此步驟，後續所有處理都接收未過濾輸入
Evidence:     WhisperState.swift:360 -- `text = TranscriptionOutputFilter.filter(text)`
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  false

---

### P-003: zh-TW Conversion Conditional on UserDefaults SelectedLanguage String

Trigger:      post-processing chain，在 OutputFilter 之後
Input:        filtered text
Output:       若 SelectedLanguage == "zh-TW"：ChineseConverter.simplifiedToTraditional(text)；否則：text 不變
Condition:    UserDefaults.standard.string(forKey: "SelectedLanguage") == "zh-TW"（string literal equality）
Ordering:     after OutputFilter（line 360）; **before** trimming（line 376）
Risk:         MEDIUM -- "zh-TW" 是 string literal comparison；若 key 更名或值格式改變，此步驟靜默跳過
Evidence:     WhisperState.swift:364-366 -- `if UserDefaults.standard.string(forKey: "SelectedLanguage") == "zh-TW" { text = ChineseConverter.simplifiedToTraditional(text) }`
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  false

---

### P-004: Text Trimmed Before Formatting

Trigger:      post-processing chain，在 zh-TW 之後
Input:        text（可能含前後空白）
Output:       text.trimmingCharacters(in: .whitespacesAndNewlines)
Condition:    無條件
Ordering:     after zh-TW（line 365）; **before** WhisperTextFormatter（line 379）
Risk:         LOW -- Formatter 接收到已去除前後空白的文字
Evidence:     WhisperState.swift:376 -- `text = text.trimmingCharacters(in: .whitespacesAndNewlines)`
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  false

---

### P-005: Text Formatting Conditional on UserDefaults Flag

Trigger:      post-processing chain，在 trimming 之後
Input:        trimmed text
Output:       若 "IsTextFormattingEnabled" == true：WhisperTextFormatter.format(text)；否則：text 不變
Condition:    UserDefaults.standard.bool(forKey: "IsTextFormattingEnabled")
Ordering:     after trimming（line 376）; before WordReplacementService（line 383）
Risk:         LOW -- feature flag 控制此步驟
Evidence:     WhisperState.swift:378-381 -- `if UserDefaults.standard.bool(forKey: "IsTextFormattingEnabled") { text = WhisperTextFormatter.format(text) }`
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  false

---

### P-006: Word Replacement Uses Live ModelContext

Trigger:      post-processing chain，在 formatting 之後
Input:        formatted text、modelContext
Output:       text = WordReplacementService.shared.applyReplacements(to: text, using: modelContext)
Condition:    無條件
Ordering:     after formatting（line 381）; before AI enhancement（line 403）
Risk:         MEDIUM -- 使用 shared singleton + live modelContext；concurrent writes 可能讀取不一致的 replacement rules
Evidence:     WhisperState.swift:383 -- `text = WordReplacementService.shared.applyReplacements(to: text, using: modelContext)`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### P-007: AI Enhancement Uses Context Captured at Recording Start

Trigger:      AI enhancement 步驟（line 412）
Input:        textForAI（由 promptDetectionResult?.processedText 或原始 text 決定）
Output:       (enhancedText, enhancementDuration, promptName) = try await enhancementService.enhance(textForAI)；finalPastedText = enhancedText
Condition:    enhancementService.isEnhancementEnabled && isConfigured
Risk:         HIGH -- clipboard 和 screen context 在錄音開始時捕獲（S-004），長時間錄音後 context 可能已過期
Evidence:     WhisperState.swift:412-420 -- `let (enhancedText, ...) = try await enhancementService.enhance(textForAI) ... finalPastedText = enhancedText`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### P-008: Final Text Pasted via CursorPaster with Optional Space Append

Trigger:      transcribeAudio() 成功完成，finalPastedText 非 nil，transcription.transcriptionStatus == .completed
Input:        textToPaste（可能含 M-008 的 trial expired prefix）、UserDefaults "AppendTrailingSpace"
Output:       CursorPaster.pasteAtCursor(textToPaste + (appendSpace ? " " : ""))
Condition:    transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue（string comparison）
Ordering:     executed via DispatchQueue.main.asyncAfter(deadline: .now() + 0.05)（S-006）
Risk:         HIGH -- AppendTrailingSpace 在 asyncAfter closure 中即時讀取（line 455），不是在 transcribeAudio 開始時讀取
Evidence:     WhisperState.swift:446-456 -- `if var textToPaste = finalPastedText, ... { ... CursorPaster.pasteAtCursor(textToPaste + ...) }`
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### P-009: getEnhancementService Exposes Internal Service Reference

Trigger:      任何呼叫者呼叫 getEnhancementService()
Input:        N/A
Output:       enhancementService（Optional AIEnhancementService reference）
Risk:         LOW -- 暴露 internal service reference；由於 WhisperState 是 @MainActor，getter 本身是 actor-isolated 的，risk 主要在於呼叫者是否在正確 actor 上使用此 reference [DISPUTE APPLIED: clarified that getter is actor-isolated; risk is at call site]
Evidence:     WhisperState.swift:479-481 -- `func getEnhancementService() -> AIEnhancementService? { return enhancementService }`
Scope:        method  [META_ISSUE APPLIED: method scope, not class]
Seam_Type:    object
Pinch_Point:  false

---

### P-010: isModelLoaded @Published Propagation to UI Observers [ADD]

Trigger:      isModelLoaded 屬性改變
Input:        isModelLoaded Bool
Output:       ObservableObject 發布變更給所有訂閱的 SwiftUI 視圖或 reactive consumers
Condition:    WhisperState 作為 ObservableObject 被觀察
Risk:         LOW -- @Published 屬性的標準 ObservableObject 行為；重構時若 isModelLoaded 移至子物件，觀察者必須更新觀察路徑
Evidence:     WhisperState.swift:22 -- `@Published var isModelLoaded = false`
Scope:        class
Seam_Type:    none
Pinch_Point:  false

---

### P-011: clipboardMessage @Published Propagation to UI Observers [ADD]

Trigger:      clipboardMessage 屬性被賦值
Input:        clipboardMessage String
Output:       UI 觀察者收到更新，顯示 clipboard 相關訊息
Condition:    WhisperState 作為 ObservableObject 被觀察
Risk:         LOW -- 標準 @Published 行為；重構時若 clipboardMessage 移至子物件，觀察 UI 必須更新綁定
Evidence:     WhisperState.swift:28 -- `@Published var clipboardMessage = ""`
Scope:        class
Seam_Type:    none
Pinch_Point:  false

---

## Risk Summary (Final)

| Risk Level | Contracts | Top Concerns |
|------------|-----------|--------------|
| CRITICAL   | S-003, L-001, P-001 | Callback swap order; dead .starting state; post-processing chain ordering |
| HIGH       | M-002, M-006, M-007, N-001, N-002, C-002, C-003, C-005, S-002, S-004, S-006, L-002, L-003, L-004, E-002, E-005, D-005, P-007, P-008 | 19 high-risk contracts |
| MEDIUM     | M-001, M-003, M-004, M-008, E-001, E-003, E-004, D-001, D-003, D-004, D-007, D-009, P-002, P-003, P-006, S-001, S-007, L-005, L-006, N-003 | 20 medium-risk contracts |
| LOW        | M-005, N-004, S-005, E-006, D-002, D-006, D-008, P-004, P-005, P-009, P-010, P-011, C-001 | 13 low-risk contracts |

COMPLETENESS: 56 contracts total
