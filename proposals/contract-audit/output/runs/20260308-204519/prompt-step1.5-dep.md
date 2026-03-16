你是一位遺留代碼專家。基於以下依賴資訊，執行以下分析：

1. 建立依賴方向圖（簡化版，列出 A -> B 表示 A 依賴 B）
2. 為每個依賴標記 Seam 類型：
   - Object Seam: 可透過物件替換改變行為（依賴注入、Protocol/Interface）
   - Preprocessing Seam: 編譯期可替換（宏、條件編譯）
   - Link Seam: 連結期可替換（動態連結庫、module alias）
   - None: 硬依賴，無法輕易替換
3. 識別 Pinch Point：入邊數 >= 3 的節點
4. 為每個 Pinch Point 建議依賴打破策略（Sprout/Wrap/Extract Interface）

語言: objc
模組: RoomBubbleCellData
重構意圖: Migrate RoomBubbleCellData from ObjC to Swift, preserving thread-safety contracts (@synchronized, dispatch_sync/async) and notification patterns (URLPreviewDidUpdateNotification)

=== 正向依賴（目標模組 import 了什麼）===

--- Riot/Modules/Room/CellData/RoomBubbleCellData.m ---
#import "RoomBubbleCellData.h"
#import "EventFormatter.h"
#import "AvatarGenerator.h"
#import "Tools.h"
#import "RoomReactionsViewSizer.h"
#import "GeneratedInterface-Swift.h"
--- Riot/Modules/Room/CellData/RoomBubbleCellData.h ---
#import "MatrixKit.h"
--- /Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/Room/Members/RoomParticipantsViewController.m ---
#import "RoomParticipantsViewController.h"
#import "RoomMemberDetailsViewController.h"
#import "GeneratedInterface-Swift.h"
#import "Contact.h"
#import "MXCallManager.h"
#import "ContactTableViewCell.h"
#import "RageShakeManager.h"
--- /Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/Room/RoomViewController.m ---
@import MobileCoreServices;
#import "RoomViewController.h"
#import "RoomDataSource.h"
#import "RoomBubbleCellData.h"
#import "RoomInputToolbarView.h"
#import "DisabledRoomInputToolbarView.h"
#import "RoomActivitiesView.h"
#import "AttachmentsViewController.h"
#import "EventDetailsView.h"
#import "RoomAvatarTitleView.h"
#import "ExpandedRoomTitleView.h"
#import "SimpleRoomTitleView.h"
#import "PreviewRoomTitleView.h"
#import "RoomMemberDetailsViewController.h"
#import "ContactDetailsViewController.h"
#import "SegmentedViewController.h"
#import "RoomSettingsViewController.h"
#import "RoomFilesViewController.h"
#import "RoomSearchViewController.h"
#import "UsersDevicesViewController.h"
#import "ReadReceiptsViewController.h"
#import "JitsiViewController.h"
#import "RoomEmptyBubbleCell.h"
#import "RoomMembershipExpandedBubbleCell.h"
#import "MXKRoomBubbleTableViewCell+Riot.h"
#import "AvatarGenerator.h"
#import "Tools.h"
#import "WidgetManager.h"
#import "ShareManager.h"
#import "GBDeviceInfo_iOS.h"
#import "RoomEncryptedDataBubbleCell.h"
#import "EncryptionInfoView.h"
#import "MXRoom+Riot.h"
#import "IntegrationManagerViewController.h"
#import "WidgetPickerViewController.h"
#import "StickerPickerViewController.h"
#import "EventFormatter.h"
#import "SettingsViewController.h"
#import "SecurityViewController.h"
#import "TypingUserInfo.h"
#import "MXSDKOptions.h"
#import "RoomTimelineCellProvider.h"
#import "GeneratedInterface-Swift.h"
--- /Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/MatrixKit/Controllers/MXKRoomSettingsViewController.m ---
#import "MXKRoomSettingsViewController.h"
#import "NSBundle+MatrixKit.h"
#import "MXKSwiftHeader.h"
--- /Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/MatrixKit/Controllers/MXKRecentListViewController.m ---
#import "MXKRecentListViewController.h"
#import "MXKRoomDataSourceManager.h"
#import "MXKInterleavedRecentsDataSource.h"
#import "MXKInterleavedRecentTableViewCell.h"
#import "MXKSwiftHeader.h"
--- /Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/MatrixKit/Models/Room/MXKRoomDataSourceManager.m ---
#import "MXKRoomDataSourceManager.h"
--- /Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/MatrixKit/Controllers/MXKCallViewController.m ---
#import "MXKCallViewController.h"
@import MatrixSDK;
#import "MXKAppSettings.h"
#import "MXKSoundPlayer.h"
#import "MXKTools.h"
#import "NSBundle+MatrixKit.h"
#import "MXKSwiftHeader.h"
--- /Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/MatrixKit/Controllers/MXKRoomMemberDetailsViewController.m ---
#import "MXKRoomMemberDetailsViewController.h"
@import MatrixSDK.MXMediaManager;
#import "MXKTableViewCellWithButtons.h"
#import "NSBundle+MatrixKit.h"
#import "MXKAppSettings.h"
#import "MXKConstants.h"
#import "MXKSwiftHeader.h"
--- /Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/MatrixKit/Models/Room/MXKRoomDataSource.m ---
#import "MXKRoomDataSource.h"
@import MatrixSDK;
#import "MXKQueuedEvent.h"
#import "MXKRoomBubbleTableViewCell.h"
#import "MXKRoomBubbleCellData.h"
#import "MXKTools.h"
#import "MXAggregatedReactions+MatrixKit.h"
#import "MXKAppSettings.h"
#import "GeneratedInterface-Swift.h"

=== 反向依賴（誰 import 了目標模組）===

--- 依賴 RoomBubbleCellData 的檔案 ---
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Categories/RoomBubbleCellData.swift
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Categories/MXKRoomBubbleCellData+Riot.swift
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Categories/MXKRoomBubbleTableViewCell+Riot.m
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/GlobalSearch/Files/Views/FilesSearchTableViewCell.m
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/GlobalSearch/Files/HomeFilesSearchViewController.m
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/GlobalSearch/Messages/HomeMessagesSearchViewController.m
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/GlobalSearch/Messages/DataSources/HomeMessagesSearchDataSource.m
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/Spaces/SpaceRoomList/ExploreRoomCoordinator.swift
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/Room/Files/RoomFilesViewController.m
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/Room/RoomViewController.m
--- 依賴 RoomBubbleCellData 的檔案 ---
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Categories/RoomBubbleCellData.swift
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Categories/MXKRoomBubbleCellData+Riot.swift
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Categories/MXKRoomBubbleTableViewCell+Riot.m
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Utils/EventFormatter.m
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Managers/Call/CallPresenter.swift
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/SupportingFiles/Riot-Bridging-Header.h
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/GlobalSearch/Files/Views/FilesSearchTableViewCell.m
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/GlobalSearch/Files/HomeFilesSearchViewController.m
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/GlobalSearch/Messages/HomeMessagesSearchViewController.m
/Users/justinlee/dev/sourceatlas2/test_targets/element-ios/Riot/Modules/GlobalSearch/Messages/DataSources/HomeMessagesSearchDataSource.m

輸出格式為 JSON，結構如下：
{
  "dependency_graph": [
    { "from": "ModuleA", "to": "ModuleB", "seam_type": "object|preprocessing|link|none" }
  ],
  "pinch_points": [
    {
      "node": "ModuleName",
      "in_degree": 5,
      "is_pinch_point": true,
      "suggested_strategy": "Extract Interface / Sprout / Wrap"
    }
  ],
  "seam_summary": [
    { "dependency": "A -> B", "seam_type": "object", "reason": "..." }
  ]
}
只輸出合法的 JSON，不要包含 Markdown 或其他格式。
