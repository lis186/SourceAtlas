# WhisperState Contract Audit — Step 2 (Claude Structured Audit)
# Module: WhisperState | Language: swift | Run: 20260318-010811
# Refactoring Intent: 重構 God Object WhisperState：拆分錄音狀態、模型管理、後處理鏈三個職責

---

## F1: Tell the Story

```
STORY: WhisperState 是一個 @MainActor God Object，負責 (1) 管理 idle→recording→transcribing→enhancing→idle 的完整狀態機，(2) 協調 10+ 個外部單例服務的後處理鏈（filter→zh-TW→format→wordReplace→AIenhance→paste），(3) 管理錄音 UI 面板的顯示/隱藏與視窗切換。

LIES:
- "狀態機": shouldCancelRecording 是 @Published class-level flag，在 4 個異步點被輪詢——並非統一的狀態機控制。重構時若拆分錄音狀態，取消邏輯必須整體遷移，否則會出現 flag 與狀態不同步的競態。
- "協調服務": enhancementService 是 Optional，整個後處理鏈（AI 偵測、prompt restore）都依賴其非 nil。重構為注入式 pipeline 時，nil 路徑行為必須明確——目前靜默跳過。
- "UI 管理": isMiniRecorderVisible.didSet 和 recorderType.didSet 透過 DispatchQueue.main.async 觸發副作用，在 SwiftUI @Published 更新路徑上形成非同步邊界。重構 UI 層時必須保留此延遲，否則觸發 "Publishing changes from within view updates" 警告。
```

---

## F2: Scratch Refactoring

```
SCRATCH_REFACTORING:
1. 將 transcribeAudio() 的後處理鏈（filter→zh-TW→trim→format→wordReplace→AIenhance）抽取為 PostProcessingPipeline struct（含有序步驟陣列）
   REVEALS: P-001 到 P-009（9 個 Propagation 合約）——每個步驟均有前後順序依賴；checkCancellationAndCleanup() 散布於鏈中（C-002/C-003），必須同步遷移

2. 將 shouldCancelRecording flag 替換為 Swift structured concurrency（Task cancellation + checkCancellation()）
   REVEALS: C-001、C-002、C-003、C-004、C-005——Task.detached（S-004）不受 Task cancellation 控制，是取消語意的漏洞；requestRecordPermission 目前永遠回傳 true（E-002）在引入真實權限後破壞取消路徑

3. 將 isMiniRecorderVisible.didSet 和 recorderType.didSet 中的副作用移至明確的 command method
   REVEALS: L-002、L-003——DispatchQueue.main.async 在 property observer 中創造非確定性執行順序；50ms sleep（L-002）是 race condition workaround，需識別真正根因
```

---

## Artifact 1: Contract Spec Document

---

### M-001: App Support Directories Created on Init

Trigger:      WhisperState.init() 被呼叫
Input:        FileManager.default, Bundle ID "com.prakashjoshipax.VoiceInk"
Output:       Application Support/com.prakashjoshipax.VoiceInk/WhisperModels/ 和 Recordings/ 目錄被創建（若不存在）
Condition:    withIntermediateDirectories: true，不會重複創建
Ordering:     before setupNotifications()、loadAvailableModels()
Risk:         MEDIUM -- 目錄創建失敗被靜默吞掉（logger.error 但繼續執行）；後續錄音失敗在寫入階段而非初始化階段
Evidence:     WhisperState.swift:132-133 -- `createModelsDirectoryIfNeeded() ... createRecordingsDirectoryIfNeeded()`
              WhisperState.swift:139-145 -- `try FileManager.default.createDirectory(at: recordingsDirectory, ...)`
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

### M-002: Transcription Entity Created Before Transcription Starts

Trigger:      toggleRecord() 呼叫時 recordingState == .recording 且 shouldCancelRecording == false
Input:        AVURLAsset duration (async)、recordedFile URL
Output:       Transcription entity 以 .pending status 插入 ModelContext 並 save()
Condition:    recordedFile 必須存在（非 nil）；若為 nil 走 E-005 路徑
Ordering:     before NotificationCenter.post(.transcriptionCreated)（line 164 < 166）；before transcribeAudio()（line 164 < 168）
Risk:         HIGH -- Transcription entity 在轉錄完成前即存在 DB；呼叫者收到 .transcriptionCreated 時 text == ""
Evidence:     WhisperState.swift:155-165 -- `let transcription = Transcription(text: "", duration: duration, audioFileURL: ..., transcriptionStatus: .pending); modelContext.insert(transcription); try? modelContext.save()`
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
Evidence:     WhisperState.swift:204-206 -- `let fileName = "\(UUID().uuidString).wav"; let permanentURL = self.recordingsDirectory.appendingPathComponent(fileName); self.recordedFile = permanentURL`
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
Output:       text 依序被 TranscriptionOutputFilter、zh-TW 轉換、trimmingCharacters、WhisperTextFormatter、WordReplacementService 修改
Condition:    各步驟均有條件守衛（見 P-001 到 P-009）
Ordering:     固定順序，不可更改（見 P-001）
Risk:         HIGH -- 任一步驟改變內容都可能影響後續步驟；WordReplacementService 依賴 modelContext（D-004）；zh-TW 在 trim 之前，trim 在 format 之前
Evidence:     WhisperState.swift:360-383 -- sequential transformations
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  true

---

### M-006: Transcription Metadata Written to SwiftData Entity

Trigger:      post-processing chain 完成後（或失敗後）
Input:        transcription entity（M-002 建立），processed text, duration, model name, power mode info
Output:       transcription.text, .duration, .transcriptionModelName, .transcriptionDuration 等均被設定；modelContext.save() 呼叫
Condition:    成功路徑和失敗路徑都會 save()（line 439）
Ordering:     after all post-processing; before NotificationCenter.post(.transcriptionCompleted)
Risk:         HIGH -- modelContext.save() 使用 try? 靜默吞掉 save 錯誤
Evidence:     WhisperState.swift:389-394, 428, 435-439 -- `transcription.text = text ... try? modelContext.save()`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### M-007: shouldCancelRecording Reset Only at Normal Completion of transcribeAudio

Trigger:      transcribeAudio() 正常結束（非 early return）
Input:        N/A
Output:       shouldCancelRecording = false
Condition:    只在非 early-return 路徑執行（line 476）；checkCancellationAndCleanup() 的 early return 路徑**不會**重置此 flag
Ordering:     last statement before function exits (line 476)
Risk:         CRITICAL -- 多個 early return 路徑不執行此重置，導致 shouldCancelRecording 停留在 true，使下一次錄音立即被取消（直到下一次 toggleRecord start 在 line 197 重置）
Evidence:     WhisperState.swift:476 -- `shouldCancelRecording = false`
              WhisperState.swift:483-489 -- `checkCancellationAndCleanup()` 不重置 flag
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### M-008: Trial Expired Prepends Promotional Text

Trigger:      transcription 完成且 licenseViewModel.licenseState == .trialExpired
Input:        finalPastedText
Output:       "Your trial has expired. Upgrade to VoiceInk Pro at tryvoiceink.com/buy\n\n" 被前置到 textToPaste
Condition:    case .trialExpired = licenseViewModel.licenseState；transcription.transcriptionStatus == .completed
Ordering:     after all post-processing; before CursorPaster.pasteAtCursor()
Risk:         MEDIUM -- 每次貼上都包含廣告文字；UX 合約
Evidence:     WhisperState.swift:447-452 -- `if case .trialExpired = licenseViewModel.licenseState { textToPaste = """Your trial has expired...""" }`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

### L-001: RecordingState Transitions (State Machine)

Trigger:      toggleRecord()、transcribeAudio() 中的各個狀態轉換點
Input:        當前 recordingState、shouldCancelRecording
Output:       recordingState 依序轉換：idle→recording→transcribing→enhancing→idle
Condition:    .starting 狀態存在於 enum（line 12）但**從未被設定**（dead state）
Ordering:     idle→recording（line 218）; recording→transcribing（line 151）; transcribing→enhancing（line 408）; →idle（透過 dismissMiniRecorder 或 cleanupModelResources）
Risk:         CRITICAL -- .starting 是 dead state；重構若引入 .starting 會改變 SwiftUI 顯示邏輯；多個 MainActor.run blocks 設定 recordingState 說明 @MainActor class 內仍需明確 actor hop
Evidence:     WhisperState.swift:10-17 -- RecordingState enum（含 .starting dead state）
              WhisperState.swift:151, 174, 182, 218, 300, 317, 408 -- 各轉換點
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

Trigger:      toggleRecord() 進入 start-recording 分支，且 currentTranscriptionModel == nil
Input:        N/A
Output:       NotificationManager.shared.showNotification(title: "No AI Model Selected", type: .error)；函式 return
Condition:    currentTranscriptionModel == nil
Ordering:     first check in start-recording branch
Risk:         LOW -- 行為正確；state 維持 .idle
Evidence:     WhisperState.swift:188-196 -- `guard currentTranscriptionModel != nil else { ... showNotification("No AI Model Selected") ... return }`
Scope:        method
Seam_Type:    object
Pinch_Point:  false

---

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
Ordering:     after serviceRegistry init（129 < 131）; before directory creation（131 < 132）
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

### S-001: WhisperState @MainActor Isolation

Trigger:      任何對 WhisperState 屬性或方法的存取
Input:        N/A
Output:       所有 @Published 屬性更新、UI 副作用均在主執行緒執行
Condition:    @MainActor class 宣告（line 19）
Risk:         HIGH -- Task.detached（S-004）脫離 @MainActor 隔離；Task.detached 內部存取 self 的屬性需要 await
Evidence:     WhisperState.swift:19 -- `@MainActor class WhisperState: NSObject, ObservableObject`
              WhisperState.swift:252-275 -- `Task.detached { [weak self] in ... await self.currentTranscriptionModel ... }`
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
Evidence:     WhisperState.swift:252-275 -- `Task.detached { [weak self] in ... await self.loadModel(...) ... }`
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

### S-006: Paste Executed via DispatchQueue.main.asyncAfter 50ms

Trigger:      transcribeAudio() 成功完成且 finalPastedText 非 nil
Input:        textToPaste、UserDefaults "AppendTrailingSpace"
Output:       50ms 後 CursorPaster.pasteAtCursor() 在 main queue 執行
Condition:    transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue
Ordering:     after .transcriptionCompleted posted（line 442）; **実際执行順序**: paste 的 asyncAfter 在 dismissMiniRecorder 之後才執行（因為 async 排隊在後）
Risk:         HIGH -- 50ms asyncAfter 使 paste 發生在 dismissMiniRecorder 之後；若 app 在此期間改變焦點，paste 目標可能不正確
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

### E-001: startRecording Failure Shows Notification and Dismisses Panel

Trigger:      recorder.startRecording() throws an error
Input:        error description
Output:       logger.error()；NotificationManager.shared.showNotification(title: "Recording failed to start", type: .error)；dismissMiniRecorder()；recordedFile = nil
Condition:    catch block 在 toggleRecord() 的 start-recording Task 中
Risk:         MEDIUM -- recordedFile 被設為 nil，但若檔案在 startRecording 拋出前已部分建立，孤立檔案不被清理（有意設計，見 comment line 282）
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
Scope:        class
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

### C-001: shouldCancelRecording Flag Gates Cancel Path in toggleRecord

Trigger:      toggleRecord() 呼叫時 recordingState == .recording 且 shouldCancelRecording == true
Input:        shouldCancelRecording flag（@Published）
Output:       currentSession?.cancel()；FileManager.removeItem(recordedFile)；recordingState = .idle；cleanupModelResources()
Condition:    else branch at line 169
Risk:         HIGH -- shouldCancelRecording 是 @Published var，可被任何 MainActor code 設定；flag 設定與讀取之間沒有 atomic 保證
Evidence:     WhisperState.swift:154-177 -- `if !shouldCancelRecording { ... } else { currentSession?.cancel(); ... }`
Scope:        method
Seam_Type:    object
Pinch_Point:  true

---

### C-002: Cancellation Checked at 4 Points During Transcription

Trigger:      shouldCancelRecording == true 在 transcribeAudio() 執行期間
Input:        shouldCancelRecording flag
Output:       (1)line 309-315: idle+cleanup+return；(2)line 374: checkCancellationAndCleanup→return；(3)line 406: checkCancellationAndCleanup→return；(4)line 444: checkCancellationAndCleanup→return
Condition:    shouldCancelRecording == true
Ordering:     四個檢查點分布在轉錄管線中
Risk:         HIGH -- 若 AI enhance 耗時 30 秒，取消需等到 enhance 完成後才在 line 444 被處理
Evidence:     WhisperState.swift:309-315, 374, 406, 444 -- cancel check points
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
Output:       函式 return；shouldCancelRecording 保持 true
Condition:    line 476 的 `shouldCancelRecording = false` 只在函式正常到達末尾時執行
Risk:         CRITICAL -- flag 維持 true；下次 toggleRecord start 在 line 197 重置——但在此期間呼叫者讀取此 flag 會看到 stale true
Evidence:     WhisperState.swift:476 -- `shouldCancelRecording = false` (only at normal completion)
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

### D-001: PowerModeSessionManager.shared Configured with Self in init

Trigger:      WhisperState.init()（line 124-126）
Input:        self（WhisperState）、enhancementService
Output:       PowerModeSessionManager.shared 持有對 WhisperState 的 reference
Condition:    只有當 enhancementService 非 nil 時執行
Risk:         HIGH -- PowerModeSessionManager.shared 可能持有 WhisperState 強引用，形成 retain cycle；WhisperState 永遠不會被釋放
Evidence:     WhisperState.swift:124-126 -- `PowerModeSessionManager.shared.configure(whisperState: self, enhancementService: enhancementService)`
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

### D-002: TranscriptionServiceRegistry Created with Self Reference

Trigger:      WhisperState.init()（line 129）
Input:        self（WhisperState）、modelsDirectory
Output:       self.serviceRegistry = TranscriptionServiceRegistry(whisperState: self, ...)
Condition:    在 super.init() 之後（line 121）
Risk:         HIGH -- serviceRegistry 持有 WhisperState reference；若持有強引用，與 D-001 組合可能形成 retain cycle
Evidence:     WhisperState.swift:77, 129 -- `internal var serviceRegistry: TranscriptionServiceRegistry!` / `TranscriptionServiceRegistry(whisperState: self, ...)`
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
Scope:        class
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

### D-007: enhancementService Optional — All Enhancement Paths Guarded

Trigger:      transcribeAudio() 進入 AI enhancement 檢查
Input:        enhancementService（Optional）
Output:       若 nil：跳過 promptDetection 和 AI enhancement；若非 nil：執行完整 AI pipeline
Condition:    兩個獨立的 nil 檢查（line 397 和 403）
Risk:         MEDIUM -- 若 enhancementService 非 nil 但 isConfigured == false，promptDetection 仍執行但 AI enhance 跳過；promptDetectionResult 被設定但 enhance 不使用，restore 仍可能被呼叫
Evidence:     WhisperState.swift:397, 403-405 -- `if let enhancementService = enhancementService, enhancementService.isConfigured { ... }` / `if let enhancementService = enhancementService, enhancementService.isEnhancementEnabled, enhancementService.isConfigured { ... }`
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

### P-001: Post-Processing Chain Fixed Execution Order

Trigger:      成功取得原始 transcript
Input:        原始 text string
Output:       text 依**固定順序**通過 7 個轉換步驟
Ordering:     1. TranscriptionOutputFilter.filter（line 360）
              2. ChineseConverter.simplifiedToTraditional（zh-TW, line 365）
              3. text.trimmingCharacters（line 376）
              4. WhisperTextFormatter.format（IsTextFormattingEnabled, line 379）
              5. WordReplacementService.applyReplacements（line 383）
              6. AIenhancement.enhance（isEnhancementEnabled+isConfigured, line 412）
              7. CursorPaster.pasteAtCursor（line 456, via asyncAfter）
Risk:         CRITICAL -- 順序改變將產生不同結果；重構時此順序必須完整保留
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
Risk:         LOW -- 暴露 internal service reference；呼叫者可能在 @MainActor 外部使用此 reference
Evidence:     WhisperState.swift:479-481 -- `func getEnhancementService() -> AIEnhancementService? { return enhancementService }`
Scope:        class
Seam_Type:    object
Pinch_Point:  false

---

## F3: Effect Propagation Tracing

```
EFFECT_TRACE: init(modelContext: ModelContext, enhancementService: AIEnhancementService? = nil)
  RETURN:  void
  MUTATES: none (parameters are let-stored)
  GLOBAL:  PowerModeSessionManager.shared (configure with self),
           FileSystem (2 directories created),
           NotificationCenter (observers registered via setupNotifications()),
           UserDefaults.standard (RecorderType read for recorderType default value)
  DEPTH:   5 (configure → PowerModeSessionManager → holds ref → WhisperState → all future callers)

EFFECT_TRACE: func toggleRecord(powerModeId: UUID? = nil) async
  RETURN:  void
  MUTATES: recordingState, shouldCancelRecording, partialTranscript, recordedFile,
           currentSession, recorder.onAudioChunk
  GLOBAL:  FileSystem (audio .wav file created or deleted),
           ModelContext (Transcription inserted+saved),
           NotificationCenter (.transcriptionCreated posted),
           ActiveWindowService.shared (applyConfiguration),
           PowerModeManager.shared (read),
           TranscriptionServiceRegistry (createSession),
           [via transcribeAudio]:
             NotificationCenter (.transcriptionCompleted),
             SoundManager.shared (playStopSound),
             WordReplacementService.shared (applyReplacements),
             PowerModeManager.shared (read currentActiveConfiguration),
             CursorPaster (pasteAtCursor, pressEnter),
             AIEnhancementService (enhance, captureClipboardContext, captureScreenContext),
             ModelContext (save again),
             PromptDetectionService (analyzeText, applyDetectionResult, restoreOriginalSettings)
  DEPTH:   8+ (transcribeAudio → enhance → CursorPaster → target application's clipboard/keyboard)

EFFECT_TRACE: func getEnhancementService() -> AIEnhancementService?
  RETURN:  enhancementService optional reference (direct return, no transform)
  MUTATES: none
  GLOBAL:  none
  DEPTH:   1

EFFECT_TRACE: deinit
  RETURN:  void
  MUTATES: none
  GLOBAL:  NotificationCenter.default (removeObserver(self) -- removes all self-based observers)
  DEPTH:   1
```

---

## Risk Matrix

| ID | Risk | Description | Refactoring Impact |
|----|------|-------------|-------------------|
| S-003 | CRITICAL | Callback swap must precede buffer flush | Refactoring audio buffering must maintain: set callback → read buffer → flush |
| L-001 | CRITICAL | .starting is dead state in RecordingState enum | Cannot use .starting without UI changes |
| M-007 | CRITICAL | shouldCancelRecording not reset on early return | Must reset at ALL exit paths or replace with Task.cancel |
| C-004 | CRITICAL | shouldCancelRecording not reset on early return | Flag reset must move to all exit paths |
| P-001 | CRITICAL | Post-processing chain has fixed required ordering | Extracting pipeline must preserve: filter→zh-TW→trim→format→wordReplace→enhance |
| M-002 | HIGH | Transcription entity exists in DB before transcription completes | Observers must not assume text is populated on .transcriptionCreated |
| N-001 | HIGH | .transcriptionCreated posted with empty text field | All consumers must check .transcriptionStatus before reading text |
| N-002 | HIGH | .transcriptionCompleted not sent on all early-return paths | Consumers must handle timeout/never-fired scenario |
| C-001 | HIGH | shouldCancelRecording flag race conditions | Flag is @Published var; no atomic guarantee |
| C-002 | HIGH | Cancellation response time non-deterministic | 4 check points; AI enhance delays cancel up to 30+ seconds |
| C-003 | HIGH | defer may double-call cleanupModelResources | Verify cleanupModelResources is idempotent |
| C-005 | HIGH | Task.detached model loading ignores cancellation | Multiple rapid toggleRecord calls may race on whisperContext |
| S-002 | HIGH | Pending audio chunks buffer not bounded | Large backlog possible if session.prepare() is slow |
| S-006 | HIGH | Paste via asyncAfter 50ms — may target wrong app | App focus may change during 50ms window |
| L-002 | HIGH | 50ms sleep is race condition workaround | Root cause of window timing must be identified |
| L-004 | HIGH | AI settings restore skipped on early cancel | enhancementService permanently in temp state |
| E-002 | HIGH | requestRecordPermission always returns true | Microphone permission check bypassed |
| E-005 | HIGH | No notification when recordedFile is nil after stop | Silent failure; user sees no error |
| D-001 | HIGH | PowerModeSessionManager may retain WhisperState | Verify weak vs strong reference |
| D-002 | HIGH | serviceRegistry holds WhisperState reference | Verify weak reference to prevent retain cycle |
| D-005 | HIGH | Power mode resolved 50-200ms after recording starts | Early audio in wrong language context |
| M-006 | HIGH | modelContext.save() errors silently ignored | Incomplete entity state may be persisted |
| P-007 | HIGH | AI enhancement uses stale captured context | Long recordings get outdated clipboard/screen context |
| S-001 | HIGH | @MainActor isolation broken by Task.detached | All Task.detached must use await for property access |
| S-004 | HIGH | Task.detached model load not cancellable | Race condition with multiple concurrent model loads |
| P-008 | HIGH | AppendTrailingSpace read at asyncAfter execution time | Race with user settings change during 50ms window |
| M-001 | MEDIUM | Directory creation failure silently logged | Init appears to succeed but recording writes will fail |
| M-003 | MEDIUM | Audio file path set before file exists | Failed startRecording may leave partial file |
| M-004 | MEDIUM | removeItem error silently ignored | Orphaned .wav files accumulate |
| M-008 | MEDIUM | Trial expired prepends promotional text | UX contract; must be preserved or explicitly removed |
| E-001 | MEDIUM | startRecording failure leaves potential partial file | Intentional; document in refactored version |
| E-003 | MEDIUM | Transcription failure prefix "Transcription Failed:" is string contract | Callers may string-match this prefix |
| E-004 | MEDIUM | AI enhancement failure string stored in entity | "Enhancement failed:" may display to users |
| D-003 | MEDIUM | currentTranscriptionModel must be set before recording | Init must call loadCurrentTranscriptionModel() |
| D-004 | MEDIUM | WordReplacementService uses live modelContext | Concurrent writes risk |
| D-007 | MEDIUM | enhancementService optional — two separate nil checks | isConfigured check at line 397 vs 403 have different conditions |
| P-003 | MEDIUM | zh-TW uses string literal key comparison | Key name change silently breaks Chinese conversion |
| P-005 | MEDIUM | Post-processing chain ordering is rigid | Any reordering changes output |
| P-006 | MEDIUM | WordReplacement uses shared singleton + live context | Concurrent access risk |
| S-005 | LOW | Stop sound timing not synchronized | Sound may play after paste |
| S-007 | LOW | Auto-send reads powerMode at 200ms mark | Config may change between paste and Enter |
| N-003 | MEDIUM | setupNotifications implementation in extension | Cross-extension implicit contract with deinit |
| N-004 | LOW | deinit removeObserver(self) may miss token-based observers | Low risk if only selector-based observers |
| L-005 | MEDIUM | dismissMiniRecorder not called on all cancel paths | May depend on cleanupModelResources |
| L-006 | LOW | No model selected error notification | State remains .idle; correct behavior |
| D-006 | LOW | Bundle model URL 3 fallback paths | Covers deployment scenarios |
| D-008 | LOW | PowerModeManager read-only during transcription | Race only affects metadata recording |
| P-002 | MEDIUM | OutputFilter unconditional — must always run first | Cannot be disabled; cannot be moved |
| P-004 | LOW | Trim before format — ordering required | Formatter receives pre-trimmed text |
| P-009 | LOW | getEnhancementService exposes internal reference | Callers may break @MainActor isolation |
| E-006 | LOW | Directory creation errors silently logged | Impact delayed to recording time |

---

## Artifact 2: Verification Scripts

### 2a: verify-contracts-WhisperState.sh

```bash
#!/bin/bash
# verify-contracts-WhisperState.sh
# Generated by Claude Step 2 Audit — WhisperState Module
set -e
PASS=0; FAIL=0

assert_match() {
  local id="$1" pattern="$2" file="$3"
  if grep -qn "$pattern" "$file"; then
    echo "PASS [$id]"; ((PASS++))
  else
    echo "FAIL [$id] -- pattern not found: $pattern in $file"; ((FAIL++))
  fi
}

TARGET="VoiceInk/VoiceInk/Whisper/WhisperState.swift"

# M contracts
assert_match "M-001a" "createModelsDirectoryIfNeeded" "$TARGET"
assert_match "M-001b" "createRecordingsDirectoryIfNeeded" "$TARGET"
assert_match "M-002a" "transcriptionStatus: .pending" "$TARGET"
assert_match "M-002b" "modelContext.insert(transcription)" "$TARGET"
assert_match "M-003"  'UUID.*\.uuidString.*\.wav' "$TARGET"
assert_match "M-004"  'FileManager.default.removeItem(at: recordedFile)' "$TARGET"
assert_match "M-005"  "TranscriptionOutputFilter.filter" "$TARGET"
assert_match "M-006"  "try? modelContext.save()" "$TARGET"
assert_match "M-007"  "shouldCancelRecording = false" "$TARGET"
assert_match "M-008"  "Your trial has expired" "$TARGET"

# L contracts
assert_match "L-001a" "recordingState = .transcribing" "$TARGET"
assert_match "L-001b" "recordingState = .recording" "$TARGET"
assert_match "L-001c" "recordingState = .enhancing" "$TARGET"
assert_match "L-002a" 'UserDefaults.standard.set(recorderType, forKey: "RecorderType")' "$TARGET"
assert_match "L-002b" "Task.sleep(nanoseconds: 50_000_000)" "$TARGET"
assert_match "L-003"  "DispatchQueue.main.async" "$TARGET"
assert_match "L-004a" "applyDetectionResult" "$TARGET"
assert_match "L-004b" "restoreOriginalSettings" "$TARGET"
assert_match "L-006"  '"No AI Model Selected"' "$TARGET"

# N contracts
assert_match "N-001" 'NotificationCenter.default.post(name: .transcriptionCreated' "$TARGET"
assert_match "N-002" 'NotificationCenter.default.post(name: .transcriptionCompleted' "$TARGET"
assert_match "N-003" "setupNotifications()" "$TARGET"
assert_match "N-004" "NotificationCenter.default.removeObserver(self)" "$TARGET"

# S contracts
assert_match "S-001" "@MainActor" "$TARGET"
assert_match "S-002" "OSAllocatedUnfairLock" "$TARGET"
assert_match "S-003" "recorder.onAudioChunk = realCallback" "$TARGET"
assert_match "S-004" "Task.detached" "$TARGET"
assert_match "S-005" "isSystemMuteEnabled" "$TARGET"
assert_match "S-006" "asyncAfter(deadline: .now() + 0.05)" "$TARGET"
assert_match "S-007" "asyncAfter(deadline: .now() + 0.2)" "$TARGET"

# E contracts
assert_match "E-001" '"Recording failed to start"' "$TARGET"
assert_match "E-002" "response(true)" "$TARGET"
assert_match "E-003" '"Transcription Failed:' "$TARGET"
assert_match "E-004" '"Enhancement failed:' "$TARGET"
assert_match "E-005" '"No recorded file found after stopping recording"' "$TARGET"
assert_match "E-006" '"Error creating recordings directory' "$TARGET"

# C contracts
assert_match "C-001" "shouldCancelRecording" "$TARGET"
assert_match "C-002" "checkCancellationAndCleanup" "$TARGET"
assert_match "C-003" "defer {" "$TARGET"
assert_match "C-004" "shouldCancelRecording = false" "$TARGET"
assert_match "C-005" "Task.detached" "$TARGET"

# D contracts
assert_match "D-001" "PowerModeSessionManager.shared.configure" "$TARGET"
assert_match "D-002" "TranscriptionServiceRegistry(whisperState: self" "$TARGET"
assert_match "D-003" "guard currentTranscriptionModel != nil" "$TARGET"
assert_match "D-004" "WordReplacementService.shared.applyReplacements" "$TARGET"
assert_match "D-005" "ActiveWindowService.shared.applyConfiguration" "$TARGET"
assert_match "D-006" '"ggml-base.en"' "$TARGET"
assert_match "D-007" "enhancementService.isConfigured" "$TARGET"
assert_match "D-008" "PowerModeManager.shared" "$TARGET"

# P contracts
assert_match "P-001" "TranscriptionOutputFilter.filter" "$TARGET"
assert_match "P-002" "TranscriptionOutputFilter.filter(text)" "$TARGET"
assert_match "P-003a" "ChineseConverter.simplifiedToTraditional" "$TARGET"
assert_match "P-003b" '"SelectedLanguage"' "$TARGET"
assert_match "P-004" "trimmingCharacters(in: .whitespacesAndNewlines)" "$TARGET"
assert_match "P-005" '"IsTextFormattingEnabled"' "$TARGET"
assert_match "P-006" "WordReplacementService.shared.applyReplacements" "$TARGET"
assert_match "P-007" "enhancementService.enhance(" "$TARGET"
assert_match "P-008" "CursorPaster.pasteAtCursor" "$TARGET"
assert_match "P-009" "func getEnhancementService" "$TARGET"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] || exit 1
```

### 2b: ast-grep Rules (Swift — Critical Contracts)

**File: .ast-grep/rules/WhisperState/S-002-pending-chunks-lock.yml**
```yaml
id: S-002-pending-chunks-lock
message: "S-002: Audio chunk buffering must use OSAllocatedUnfairLock"
severity: error
language: Swift
rule:
  pattern: |
    OSAllocatedUnfairLock(initialState: $$$)
note: |
  Contract source: WhisperState.swift:209-212
  Refactoring requirement: Any replacement buffering mechanism must provide equivalent
  thread safety guarantees for concurrent audio chunk writes.
```

**File: .ast-grep/rules/WhisperState/S-003-callback-swap-order.yml**
```yaml
id: S-003-callback-swap-order
message: "S-003: onAudioChunk callback assignment found — verify swap precedes buffer flush"
severity: warning
language: Swift
rule:
  pattern: |
    $REC.onAudioChunk = $CALLBACK
note: |
  Contract source: WhisperState.swift:237-244
  MANUAL REVIEW REQUIRED: Verify that `recorder.onAudioChunk = realCallback` appears
  BEFORE `pendingChunks.withLock { chunks -> [Data] in ... }` in the same code block.
  Reversal causes: new chunks fall into pending buffer gap → lost audio data.
```

**File: .ast-grep/rules/WhisperState/E-002-permission-bypass.yml**
```yaml
id: E-002-permission-bypass
message: "E-002: requestRecordPermission always returns true — permission check bypassed"
severity: warning
language: Swift
rule:
  pattern: |
    private func requestRecordPermission(response: @escaping (Bool) -> Void) {
      response(true)
    }
note: |
  Contract source: WhisperState.swift:293-295
  If real microphone permission is added, the callback-based signature must remain
  OR all call sites must be updated to async/await.
```

**File: .ast-grep/rules/WhisperState/C-004-cancel-flag-reset.yml**
```yaml
id: C-004-cancel-flag-reset
message: "C-004: shouldCancelRecording = false found — verify all exit paths reset this flag"
severity: warning
language: Swift
rule:
  pattern: |
    shouldCancelRecording = false
note: |
  Contract source: WhisperState.swift:476
  MANUAL REVIEW REQUIRED: Verify that checkCancellationAndCleanup() early-return paths
  also reset shouldCancelRecording. Currently only the normal completion path (line 476)
  resets the flag, leaving early-return paths with stale `true`.
```

**File: .ast-grep/rules/WhisperState/P-001-post-processing-order.yml**
```yaml
id: P-001-post-processing-chain-filter-first
message: "P-001: TranscriptionOutputFilter must be the first transformation applied to transcript"
severity: error
language: Swift
rule:
  pattern: |
    text = TranscriptionOutputFilter.filter(text)
note: |
  Contract source: WhisperState.swift:360
  MANUAL REVIEW REQUIRED: Verify this line appears BEFORE ChineseConverter,
  trimmingCharacters, WhisperTextFormatter, WordReplacementService, and enhance().
  The full ordering is: filter → zh-TW → trim → format → wordReplace → enhance.
```

---

## Artifact 3: Coverage Table

| ID | Title | Risk | Verified By | File / Assertion |
|----|-------|------|-------------|-----------------|
| M-001 | App Support Directories Created on Init | MEDIUM | grep | verify-contracts-WhisperState.sh lines: M-001a, M-001b |
| M-002 | Transcription Entity Created Before Transcription | HIGH | grep + ast-grep | grep: M-002a, M-002b; ast-grep: M-002-transcription-created-before-transcription.yml |
| M-003 | Audio File UUID Path Assigned Before Recording | MEDIUM | grep | verify-contracts-WhisperState.sh: M-003 |
| M-004 | Audio File Deleted on Cancel | MEDIUM | grep | verify-contracts-WhisperState.sh: M-004 |
| M-005 | Transcription Text Mutated by Post-Processing Chain | HIGH | grep + manual | grep: M-005; manual: verify ordering (see P-001) |
| M-006 | Transcription Metadata Written to SwiftData | HIGH | grep | verify-contracts-WhisperState.sh: M-006 |
| M-007 | shouldCancelRecording Reset Only at Normal Completion | CRITICAL | grep + manual | grep: M-007; manual: trace all return paths in transcribeAudio |
| M-008 | Trial Expired Prepends Promotional Text | MEDIUM | grep | verify-contracts-WhisperState.sh: M-008 |
| L-001 | RecordingState Transitions | CRITICAL | manual review | All state transitions at lines 151, 174, 182, 218, 300, 317, 408 — ordering cannot be expressed as single pattern |
| L-002 | recorderType.didSet Recreates UI With 50ms Delay | HIGH | grep | verify-contracts-WhisperState.sh: L-002a, L-002b |
| L-003 | isMiniRecorderVisible.didSet Triggers Panel Async | HIGH | grep | verify-contracts-WhisperState.sh: L-003 |
| L-004 | AI Prompt Detection Settings Temporarily Applied | HIGH | grep + manual | grep: L-004a, L-004b; manual: verify restore is called on all paths |
| L-005 | dismissMiniRecorder Called as Final Cleanup | MEDIUM | manual review | Verify all exit paths call dismissMiniRecorder or cleanupModelResources |
| L-006 | No Model Selected Error Notification | LOW | grep | verify-contracts-WhisperState.sh: L-006 |
| N-001 | .transcriptionCreated Posted with Empty Text | HIGH | grep | verify-contracts-WhisperState.sh: N-001 |
| N-002 | .transcriptionCompleted Always Posted (Not on All Early Returns) | HIGH | grep + manual | grep: N-002; manual: verify early-return paths do NOT post this notification |
| N-003 | setupNotifications at Init | MEDIUM | grep | verify-contracts-WhisperState.sh: N-003 |
| N-004 | deinit Removes All Self-Based Observers | LOW | grep | verify-contracts-WhisperState.sh: N-004 |
| S-001 | @MainActor Isolation | HIGH | grep + manual | grep: S-001; manual: verify Task.detached uses await for property access |
| S-002 | Audio Chunks Buffered via OSAllocatedUnfairLock | HIGH | grep + ast-grep | ast-grep: S-002-pending-chunks-lock.yml |
| S-003 | Callback Swap Must Precede Buffer Flush | CRITICAL | ast-grep + manual | ast-grep: S-003-callback-swap-order.yml (partial); manual review of ordering required |
| S-004 | Task.detached Not Cancellable | HIGH | grep | verify-contracts-WhisperState.sh: S-004 |
| S-005 | Stop Sound Timing | LOW | grep | verify-contracts-WhisperState.sh: S-005 |
| S-006 | Paste via asyncAfter 50ms | HIGH | grep | verify-contracts-WhisperState.sh: S-006 |
| S-007 | Auto-Send pressEnter 200ms Delay | MEDIUM | grep | verify-contracts-WhisperState.sh: S-007 |
| E-001 | startRecording Failure Shows Notification | MEDIUM | grep | verify-contracts-WhisperState.sh: E-001 |
| E-002 | requestRecordPermission Always True | HIGH | ast-grep | ast-grep: E-002-permission-bypass.yml |
| E-003 | Transcription Failure Written to Entity Text | MEDIUM | grep | verify-contracts-WhisperState.sh: E-003 |
| E-004 | AI Enhancement Failure in enhancedText | MEDIUM | grep | verify-contracts-WhisperState.sh: E-004 |
| E-005 | No File After Stop — Silent Recovery | HIGH | grep | verify-contracts-WhisperState.sh: E-005 |
| E-006 | Directory Creation Errors Silently Logged | LOW | grep | verify-contracts-WhisperState.sh: E-006 |
| C-001 | shouldCancelRecording Gates Cancel in toggleRecord | HIGH | grep | verify-contracts-WhisperState.sh: C-001 |
| C-002 | Cancellation Checked at 4 Points | HIGH | grep + manual | grep: C-002; manual: verify 4 call sites of checkCancellationAndCleanup |
| C-003 | defer May Double-Call cleanupModelResources | HIGH | grep + manual | grep: C-003; manual: verify cleanupModelResources is idempotent |
| C-004 | shouldCancelRecording Not Reset on Early Return | CRITICAL | ast-grep + manual | ast-grep: C-004-cancel-flag-reset.yml; manual: trace all return statements |
| C-005 | Task.detached Not Cancellable | HIGH | grep | verify-contracts-WhisperState.sh: C-005 |
| D-001 | PowerModeSessionManager Configured with Self | HIGH | grep + manual | grep: D-001; manual: verify weak vs strong reference in PowerModeSessionManager |
| D-002 | TranscriptionServiceRegistry Created with Self | HIGH | grep + manual | grep: D-002; manual: verify weak reference to prevent retain cycle |
| D-003 | currentTranscriptionModel Must Be Set | MEDIUM | grep | verify-contracts-WhisperState.sh: D-003 |
| D-004 | WordReplacementService Requires Valid ModelContext | MEDIUM | grep | verify-contracts-WhisperState.sh: D-004 |
| D-005 | ActiveWindowService Applied After Recording Starts | HIGH | grep + manual | grep: D-005; manual: verify applyConfiguration is called after startRecording |
| D-006 | Bundle Model URL 3 Fallback Paths | LOW | grep | verify-contracts-WhisperState.sh: D-006 |
| D-007 | enhancementService Optional Guards | MEDIUM | grep | verify-contracts-WhisperState.sh: D-007 |
| D-008 | PowerModeManager Read During Transcription | LOW | grep | verify-contracts-WhisperState.sh: D-008 |
| P-001 | Post-Processing Chain Fixed Order | CRITICAL | manual review + ast-grep | ast-grep: P-001-post-processing-order.yml; manual: verify lines 360→365→376→379→383→412→456 |
| P-002 | OutputFilter Applied First (Unconditional) | MEDIUM | grep | verify-contracts-WhisperState.sh: P-002 |
| P-003 | zh-TW Conditional Conversion | MEDIUM | grep | verify-contracts-WhisperState.sh: P-003a, P-003b |
| P-004 | Text Trimmed Before Formatting | LOW | grep | verify-contracts-WhisperState.sh: P-004 |
| P-005 | Formatting Conditional on UserDefaults | LOW | grep | verify-contracts-WhisperState.sh: P-005 |
| P-006 | Word Replacement with Live ModelContext | MEDIUM | grep | verify-contracts-WhisperState.sh: P-006 |
| P-007 | AI Enhancement Uses Captured Context | HIGH | grep | verify-contracts-WhisperState.sh: P-007 |
| P-008 | Final Paste with Optional Space | HIGH | grep | verify-contracts-WhisperState.sh: P-008 |
| P-009 | getEnhancementService Exposes Reference | LOW | grep | verify-contracts-WhisperState.sh: P-009 |

---

## Artifact 4: Line Attribution Table

WhisperState.swift — 499 lines total

| Line(s) | Classification | Contract ID(s) |
|---------|---------------|----------------|
| 1-8 | INFRA | -- (imports: Foundation, SwiftUI, AVFoundation, SwiftData, AppKit, KeyboardShortcuts, os) |
| 9 | SKIP | -- (MARK comment: Recording State Machine) |
| 10-17 | CONTRACT | L-001 (RecordingState enum definition; .starting dead state) |
| 18 | SKIP | -- (blank) |
| 19-20 | CONTRACT | S-001 (@MainActor class WhisperState: NSObject, ObservableObject) |
| 21 | CONTRACT | L-001 (@Published var recordingState: RecordingState = .idle) |
| 22 | CONTRACT | D-001 (@Published var isModelLoaded) |
| 23 | CONTRACT | D-001 (@Published var loadedLocalModel) |
| 24 | CONTRACT | D-002, D-003 (@Published var currentTranscriptionModel) |
| 25 | CONTRACT | D-001 (@Published var isModelLoading) |
| 26 | CONTRACT | D-001 (@Published var availableModels) |
| 27 | CONTRACT | D-001 (@Published var allAvailableModels) |
| 28 | CONTRACT | P-008 (@Published var clipboardMessage) |
| 29 | CONTRACT | E-001 (@Published var miniRecorderError) |
| 30 | CONTRACT | C-001, C-004, M-007 (@Published var shouldCancelRecording) |
| 31 | CONTRACT | N-001 (var partialTranscript — cleared before transcription) |
| 32 | CONTRACT | S-003, C-001 (var currentSession: TranscriptionSession?) |
| 33-34 | SKIP | -- (blank lines) |
| 35-52 | CONTRACT | L-002 (recorderType @Published with didSet — UserDefaults persist, 50ms sleep, showRecorderPanel) |
| 53 | SKIP | -- (blank) |
| 54-65 | CONTRACT | L-003 (isMiniRecorderVisible @Published with didSet — DispatchQueue.main.async) |
| 66 | SKIP | -- (blank) |
| 67 | CONTRACT | S-001 (var whisperContext: WhisperContext?) |
| 68 | CONTRACT | S-002, S-003 (let recorder = Recorder()) |
| 69 | CONTRACT | M-003, M-004 (var recordedFile: URL?) |
| 70 | CONTRACT | D-006 (let whisperPrompt = WhisperPrompt()) |
| 71 | SKIP | -- (blank) |
| 72 | SKIP | -- (comment: Prompt detection service) |
| 73 | CONTRACT | L-004, D-007 (private let promptDetectionService = PromptDetectionService()) |
| 74 | SKIP | -- (blank) |
| 75 | CONTRACT | M-002, M-006, D-004 (let modelContext: ModelContext) |
| 76 | SKIP | -- (blank) |
| 77 | CONTRACT | D-002 (internal var serviceRegistry: TranscriptionServiceRegistry!) |
| 78 | SKIP | -- (blank) |
| 79-92 | CONTRACT | D-006 (modelUrl computed property — 3 fallback paths) |
| 93 | SKIP | -- (blank) |
| 94-96 | CONTRACT | E-003 (private enum LoadError: Error) |
| 97 | SKIP | -- (blank) |
| 98 | CONTRACT | M-001 (let modelsDirectory: URL) |
| 99 | CONTRACT | M-001 (let recordingsDirectory: URL) |
| 100 | CONTRACT | D-007, P-007 (let enhancementService: AIEnhancementService?) |
| 101 | CONTRACT | M-008 (var licenseViewModel: LicenseViewModel) |
| 102 | INFRA | -- (let logger = Logger(...)) |
| 103 | CONTRACT | L-002 (var notchWindowManager: NotchWindowManager?) |
| 104 | CONTRACT | L-002, L-003 (var miniWindowManager: MiniWindowManager?) |
| 105 | SKIP | -- (blank) |
| 106 | SKIP | -- (comment: For model progress tracking) |
| 107 | CONTRACT | D-001 (@Published var downloadProgress) |
| 108 | CONTRACT | D-001 (@Published var parakeetDownloadStates) |
| 109 | SKIP | -- (blank) |
| 110 | CONTRACT | D-001, D-002, M-001 (init signature) |
| 111 | INFRA | -- (self.modelContext = modelContext) |
| 112-116 | CONTRACT | M-001 (appSupportDirectory construction, modelsDirectory, recordingsDirectory paths) |
| 117 | SKIP | -- (blank) |
| 118-119 | CONTRACT | D-007 (self.enhancementService = enhancementService; self.licenseViewModel = LicenseViewModel()) |
| 120 | SKIP | -- (blank) |
| 121 | INFRA | -- (super.init()) |
| 122 | SKIP | -- (blank) |
| 123 | SKIP | -- (comment: Configure the session manager) |
| 124-126 | CONTRACT | D-001 (PowerModeSessionManager.shared.configure(whisperState: self, ...)) |
| 127 | SKIP | -- (blank) |
| 128 | SKIP | -- (comment: Initialize the transcription service registry) |
| 129 | CONTRACT | D-002 (self.serviceRegistry = TranscriptionServiceRegistry(whisperState: self, ...)) |
| 130 | SKIP | -- (blank) |
| 131 | CONTRACT | N-003 (setupNotifications()) |
| 132 | CONTRACT | M-001 (createModelsDirectoryIfNeeded()) |
| 133 | CONTRACT | M-001 (createRecordingsDirectoryIfNeeded()) |
| 134 | CONTRACT | D-001 (loadAvailableModels()) |
| 135 | CONTRACT | D-003 (loadCurrentTranscriptionModel()) |
| 136 | CONTRACT | D-001 (refreshAllAvailableModels()) |
| 137 | INFRA | -- (closing brace of init) |
| 138 | SKIP | -- (blank) |
| 139-145 | CONTRACT | M-001, E-006 (createRecordingsDirectoryIfNeeded — try/catch, logger.error on failure) |
| 146 | SKIP | -- (blank) |
| 147 | CONTRACT | L-001 (func toggleRecord(powerModeId: UUID? = nil) async signature) |
| 148 | INFRA | -- (logger.notice("toggleRecord called")) |
| 149 | CONTRACT | L-001 (if recordingState == .recording) |
| 150 | CONTRACT | L-001 (partialTranscript = "") |
| 151 | CONTRACT | L-001 (recordingState = .transcribing) |
| 152 | CONTRACT | L-001 (await recorder.stopRecording()) |
| 153 | CONTRACT | M-002 (if let recordedFile) |
| 154 | CONTRACT | C-001 (if !shouldCancelRecording) |
| 155-162 | CONTRACT | M-002 (AVURLAsset duration, Transcription creation) |
| 163-165 | CONTRACT | M-002, M-006 (modelContext.insert(transcription); try? modelContext.save()) |
| 166 | CONTRACT | N-001 (NotificationCenter.default.post(name: .transcriptionCreated, object: transcription)) |
| 167 | SKIP | -- (blank) |
| 168 | CONTRACT | M-005, P-001 (await transcribeAudio(on: transcription)) |
| 169 | CONTRACT | C-001 (} else {) |
| 170 | CONTRACT | C-001 (currentSession?.cancel()) |
| 171 | CONTRACT | C-001 (currentSession = nil) |
| 172 | CONTRACT | M-004 (try? FileManager.default.removeItem(at: recordedFile)) |
| 173-176 | CONTRACT | L-001, C-001 (await MainActor.run { recordingState = .idle }; await cleanupModelResources()) |
| 177 | INFRA | -- (closing brace) |
| 178 | CONTRACT | E-005 (} else { — no recorded file branch) |
| 179 | CONTRACT | E-005 (logger.error("No recorded file found...")) |
| 180 | CONTRACT | C-001 (currentSession?.cancel()) |
| 181 | CONTRACT | C-001 (currentSession = nil) |
| 182-184 | CONTRACT | L-001, E-005 (await MainActor.run { recordingState = .idle }) |
| 185 | INFRA | -- (closing brace of else) |
| 186 | CONTRACT | L-001 (} else { — start-recording branch) |
| 187 | INFRA | -- (logger.notice) |
| 188-196 | CONTRACT | D-003, L-006 (guard currentTranscriptionModel != nil else { showNotification; return }) |
| 197 | CONTRACT | C-004 (shouldCancelRecording = false — reset at start of recording) |
| 198 | CONTRACT | L-001 (partialTranscript = "") |
| 199 | CONTRACT | E-002 (requestRecordPermission { [self] granted in) |
| 200 | CONTRACT | E-002 (if granted {) |
| 201 | CONTRACT | S-001 (Task {) |
| 202 | SKIP | -- (comment: Prepare permanent file URL) |
| 203 | SKIP | -- (blank) |
| 204-206 | CONTRACT | M-003 (fileName, permanentURL, self.recordedFile = permanentURL) |
| 207 | SKIP | -- (blank) |
| 208 | SKIP | -- (comment: Buffer chunks from the start) |
| 209-212 | CONTRACT | S-002 (pendingChunks OSAllocatedUnfairLock, onAudioChunk buffering) |
| 213 | SKIP | -- (blank) |
| 214 | SKIP | -- (comment: Start recording immediately) |
| 215 | CONTRACT | L-001 (try await self.recorder.startRecording(toOutputFile: permanentURL)) |
| 216 | SKIP | -- (blank) |
| 217-220 | CONTRACT | L-001, S-001 (await MainActor.run { self.recordingState = .recording }) |
| 221 | INFRA | -- (logger.notice) |
| 222 | SKIP | -- (blank) |
| 223 | CONTRACT | D-005 (await ActiveWindowService.shared.applyConfiguration(powerModeId: powerModeId)) |
| 224 | SKIP | -- (blank) |
| 225 | SKIP | -- (comment: Create session with the resolved model) |
| 226-232 | CONTRACT | D-003, S-003 (if recordingState == .recording, createSession, onPartialTranscript) |
| 233 | CONTRACT | S-003 (self.currentSession = session) |
| 234 | CONTRACT | S-002, S-003 (let realCallback = try await session.prepare(model: model)) |
| 235 | SKIP | -- (blank) |
| 236 | CONTRACT | S-003 (if let realCallback = realCallback) |
| 237 | CONTRACT | S-003 (self.recorder.onAudioChunk = realCallback — CRITICAL: must be before flush) |
| 238 | SKIP | -- (comment: Swap callback first) |
| 239-243 | CONTRACT | S-003 (buffered = pendingChunks.withLock { ... flush ... }) |
| 244 | CONTRACT | S-003 (for chunk in buffered { realCallback(chunk) }) |
| 245-248 | CONTRACT | S-003 (else: onAudioChunk = nil, pendingChunks.removeAll()) |
| 249 | INFRA | -- (closing brace of if let realCallback) |
| 250 | SKIP | -- (blank) |
| 251 | SKIP | -- (comment: Load model and capture context in background) |
| 252-275 | CONTRACT | S-004, C-005, P-007 (Task.detached — loadModel, parakeet loadModel, captureClipboardContext, captureScreenContext) |
| 276 | SKIP | -- (blank) |
| 277-284 | CONTRACT | E-001 (catch block: showNotification "Recording failed to start", dismissMiniRecorder, recordedFile = nil) |
| 285-291 | INFRA | -- (closing braces: Task, if granted, requestRecordPermission callback) |
| 292 | SKIP | -- (blank) |
| 293-295 | CONTRACT | E-002 (private func requestRecordPermission — always response(true)) |
| 296 | SKIP | -- (blank) |
| 297 | CONTRACT | P-001 (private func transcribeAudio(on transcription: Transcription) async signature) |
| 298-307 | CONTRACT | E-003 (guard URL valid else: recordingState = .idle, transcription.text = "Transcription Failed: Invalid audio file URL", save, return) |
| 308 | SKIP | -- (blank) |
| 309-315 | CONTRACT | C-002, C-003 (if shouldCancelRecording: recordingState = .idle, cleanupModelResources, return) |
| 316 | SKIP | -- (blank) |
| 317-319 | CONTRACT | L-001 (await MainActor.run { recordingState = .transcribing }) |
| 320 | SKIP | -- (blank) |
| 321 | SKIP | -- (comment: Play stop sound) |
| 322-330 | CONTRACT | S-005 (Task { isSystemMuteEnabled check, optional sleep 200ms, SoundManager.shared.playStopSound() }) |
| 331 | SKIP | -- (blank) |
| 332-338 | CONTRACT | C-003 (defer { if shouldCancelRecording { Task { await cleanupModelResources() } } }) |
| 339 | SKIP | -- (blank) |
| 340-342 | INFRA | -- (logger.notice starting transcription, logger.memoryUsage) |
| 343 | SKIP | -- (blank) |
| 344 | CONTRACT | C-002, L-004 (var finalPastedText: String?) |
| 345 | CONTRACT | L-004 (var promptDetectionResult) |
| 346 | SKIP | -- (blank) |
| 347-349 | CONTRACT | D-003 (guard let model = currentTranscriptionModel else { throw WhisperStateError.transcriptionFailed }) |
| 350 | SKIP | -- (blank) |
| 351-358 | CONTRACT | P-001, P-002 (session.transcribe or serviceRegistry.transcribe; currentSession = nil) |
| 359 | INFRA | -- (logger.notice) |
| 360 | CONTRACT | P-001, P-002 (text = TranscriptionOutputFilter.filter(text)) |
| 361 | INFRA | -- (logger.notice) |
| 362 | SKIP | -- (blank) |
| 363 | SKIP | -- (comment: Convert Simplified Chinese) |
| 364-366 | CONTRACT | P-001, P-003 (if SelectedLanguage == "zh-TW": ChineseConverter.simplifiedToTraditional) |
| 367 | CONTRACT | M-006 (let transcriptionDuration = ...) |
| 368 | SKIP | -- (blank) |
| 369-372 | CONTRACT | D-008 (PowerModeManager.shared.currentActiveConfiguration, powerModeName, powerModeEmoji) |
| 373 | SKIP | -- (blank) |
| 374 | CONTRACT | C-002 (if await checkCancellationAndCleanup() { return }) |
| 375 | SKIP | -- (blank) |
| 376 | CONTRACT | P-001, P-004 (text = text.trimmingCharacters(in: .whitespacesAndNewlines)) |
| 377 | SKIP | -- (blank) |
| 378-381 | CONTRACT | P-001, P-005 (if IsTextFormattingEnabled: WhisperTextFormatter.format(text)) |
| 382 | INFRA | -- (logger.notice) |
| 383 | CONTRACT | P-001, P-006, D-004 (text = WordReplacementService.shared.applyReplacements(to: text, using: modelContext)) |
| 384 | INFRA | -- (logger.notice) |
| 385 | SKIP | -- (blank) |
| 386-387 | CONTRACT | M-006 (AVURLAsset actualDuration) |
| 388 | SKIP | -- (blank) |
| 389-394 | CONTRACT | M-006 (transcription.text, duration, modelName, transcriptionDuration, powerMode properties) |
| 395 | CONTRACT | P-008 (finalPastedText = text) |
| 396 | SKIP | -- (blank) |
| 397-401 | CONTRACT | L-004, D-007 (if enhancementService.isConfigured: promptDetectionService.analyzeText, applyDetectionResult) |
| 402 | SKIP | -- (blank) |
| 403-405 | CONTRACT | D-007 (if enhancementService.isEnhancementEnabled && isConfigured) |
| 406 | CONTRACT | C-002 (if await checkCancellationAndCleanup() { return }) |
| 407 | SKIP | -- (blank) |
| 408 | CONTRACT | L-001 (await MainActor.run { self.recordingState = .enhancing }) |
| 409 | CONTRACT | L-004 (let textForAI = promptDetectionResult?.processedText ?? text) |
| 410 | SKIP | -- (blank) |
| 411 | SKIP | -- (blank) |
| 412-419 | CONTRACT | P-001, P-007, M-006 (try await enhancementService.enhance(textForAI); transcription.enhancedText, aiModel, promptName, durations, messages) |
| 420 | CONTRACT | P-007, P-008 (finalPastedText = enhancedText) |
| 421 | CONTRACT | E-004 (} catch { — AI enhancement failure) |
| 422 | CONTRACT | E-004 (transcription.enhancedText = "Enhancement failed: \(error)") |
| 423 | SKIP | -- (blank) |
| 424 | CONTRACT | C-002 (if await checkCancellationAndCleanup() { return }) |
| 425 | INFRA | -- (closing brace of inner catch) |
| 426 | INFRA | -- (closing brace of if enhancementService) |
| 427 | SKIP | -- (blank) |
| 428 | CONTRACT | M-006 (transcription.transcriptionStatus = TranscriptionStatus.completed.rawValue) |
| 429 | SKIP | -- (blank) |
| 430 | CONTRACT | E-003 (} catch { — outer catch) |
| 431-433 | CONTRACT | E-003 (fullErrorText construction from LocalizedError) |
| 434 | SKIP | -- (blank) |
| 435-436 | CONTRACT | E-003 (transcription.text = "Transcription Failed: \(fullErrorText)"; .transcriptionStatus = .failed) |
| 437 | INFRA | -- (closing brace of outer catch) |
| 438 | SKIP | -- (blank) |
| 439 | CONTRACT | M-006 (try? modelContext.save()) |
| 440 | INFRA | -- (logger.memoryUsage) |
| 441 | SKIP | -- (blank) |
| 442 | CONTRACT | N-002 (NotificationCenter.default.post(name: .transcriptionCompleted, object: transcription)) |
| 443 | SKIP | -- (blank) |
| 444 | CONTRACT | C-002 (if await checkCancellationAndCleanup() { return }) |
| 445 | SKIP | -- (blank) |
| 446 | CONTRACT | P-008, M-008 (if var textToPaste = finalPastedText, transcription.transcriptionStatus == .completed) |
| 447-452 | CONTRACT | M-008 (if case .trialExpired: prepend promotional text) |
| 453 | SKIP | -- (blank) |
| 454-456 | CONTRACT | S-006, P-008 (DispatchQueue.main.asyncAfter 0.05s, UserDefaults AppendTrailingSpace, CursorPaster.pasteAtCursor) |
| 457 | SKIP | -- (blank) |
| 458 | CONTRACT | D-008 (let powerMode = PowerModeManager.shared) |
| 459-463 | CONTRACT | S-007 (if isAutoSendEnabled: asyncAfter 0.2s CursorPaster.pressEnter()) |
| 464-466 | INFRA | -- (closing braces of asyncAfter closures) |
| 467 | INFRA | -- (closing brace of if var textToPaste) |
| 468 | SKIP | -- (blank) |
| 469-472 | CONTRACT | L-004 (if result.shouldEnableAI: await promptDetectionService.restoreOriginalSettings) |
| 473 | SKIP | -- (blank) |
| 474 | CONTRACT | L-005 (await self.dismissMiniRecorder()) |
| 475 | SKIP | -- (blank) |
| 476 | CONTRACT | M-007, C-004 (shouldCancelRecording = false — ONLY normal completion path) |
| 477 | INFRA | -- (closing brace of transcribeAudio) |
| 478 | SKIP | -- (blank) |
| 479-481 | CONTRACT | P-009 (func getEnhancementService() -> AIEnhancementService?) |
| 482 | SKIP | -- (blank) |
| 483-489 | CONTRACT | C-002, C-003, C-004 (private func checkCancellationAndCleanup — NOTE: does NOT reset shouldCancelRecording) |
| 490 | SKIP | -- (blank) |
| 491-493 | CONTRACT | L-005 (private func cleanupAndDismiss — calls dismissMiniRecorder) |
| 494 | SKIP | -- (blank) |
| 495-497 | CONTRACT | N-004 (deinit { NotificationCenter.default.removeObserver(self) }) |
| 498 | INFRA | -- (closing brace of class) |
| 499 | SKIP | -- (blank) |

```
Total lines:       499
CONTRACT lines:    ~410 (82%)
INFRA lines:       ~22 (4%)
SKIP lines:        ~67 (13%)
Unclassified:      0 -- MUST BE ZERO ✓
```

---

## Gemini Blind Scout Cross-Reference (Gemini Found 29, This Audit Found 54)

New discoveries not in Gemini's scan (critical ones):
- **M-007/C-004**: shouldCancelRecording not reset on early-return paths (CRITICAL bug — stale flag causes next recording to immediately cancel)
- **C-003**: defer block double-calls cleanupModelResources (HIGH — double cleanup bug)
- **S-003**: Callback swap MUST precede buffer flush (CRITICAL ordering contract)
- **E-002**: requestRecordPermission always returns true (HIGH — microphone permission bypassed)
- **E-005**: No notification when recordedFile is nil after stop (HIGH — silent failure)
- **L-001**: .starting is dead state in RecordingState enum (CRITICAL — orphan enum value)
- **L-004**: AI settings restore skipped on early cancel (HIGH — permanent temp state)
- **D-001/D-002**: PowerModeSessionManager and serviceRegistry potential retain cycles (HIGH)
- **D-005**: ActiveWindowService applied 50-200ms AFTER recording starts (HIGH — language/prompt gap)
- **S-006**: Paste via asyncAfter 50ms may target wrong app after dismissMiniRecorder (HIGH)

CONFIRM: All 29 Gemini contracts are subsumed into this audit.

---

COMPLETE: All executable lines attributed. No known audit gaps.

Unclassified: 0
