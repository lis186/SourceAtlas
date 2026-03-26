## Caller Interface Extract（Step 0.9）

外部模組引用 WhisperState 的片段（±5 行上下文）：

### LibWhisper.swift (1 references)
```
138-        let context = whisper_init_from_file_with_params(path, params)
139-        if let context {
140-            self.context = context
141-        } else {
142-            logger.error("Couldn't load model at \(path)")
143:            throw WhisperStateError.modelLoadFailed
144-        }
145-    }
146-    
147-    private func setVADModelPath(_ path: String?) {
148-        self.vadModelPath = path
```

### WhisperState+ModelManagement.swift (1 references)
```
1-import Foundation
2-import SwiftUI
3-
4-@MainActor
5:extension WhisperState {
6-    // Loads the default transcription model from UserDefaults
7-    func loadCurrentTranscriptionModel() {
8-        if let savedModelName = UserDefaults.standard.string(forKey: "CurrentTranscriptionModel"),
9-           let savedModel = allAvailableModels.first(where: { $0.name == savedModelName }) {
10-            currentTranscriptionModel = savedModel
```

### WhisperState+UI.swift (1 references)
```
1-import Foundation
2-import SwiftUI
3-import os
4-
5-// MARK: - UI Management Extension
6:extension WhisperState {
7-    
8-    // MARK: - Recorder Panel Management
9-    
10-    func showRecorderPanel() {
11-        logger.notice("📱 Showing \(self.recorderType) recorder")
```

