## Feature Sketch（Step 0.8）

| # | 方法 | 行號 | 引用屬性 |
|---|------|------|---------|
| 1 | `init(modelContext: ModelContext, enhancementService: AIEnhancementService? = nil` | WhisperState.swift:110 | self.enhancementService,self.licenseViewModel,self.modelContext,self.modelsDirectory,self.recordingsDirectory,self.serviceRegistry |
| 2 | `func toggleRecord(powerModeId: UUID? = nil) async {` | WhisperState.swift:147 | self.availableModels,self.currentSession,self.currentTranscriptionModel,self.dismissMiniRecorder,self.enhancementService,self.loadModel,self.logger,self.recordedFile,self.recorder,self.recordingsDirectory,self.recordingState,self.serviceRegistry,self.whisperContext |
| 3 | `func getEnhancementService() -> AIEnhancementService? {` | WhisperState.swift:479 |  |
| 4 | `deinit {` | WhisperState.swift:495 |  |

共 4 個方法。
