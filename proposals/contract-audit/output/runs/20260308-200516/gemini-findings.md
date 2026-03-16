Okay, I will start by performing a blind behavioral contract discovery on the provided source files.

First, I will read the header file to understand the public interface of the `RoomBubbleCellData` class.
Contract: Main Thread UI Computations
Category: S
Trigger:  Calling `prepareBubbleComponentsPosition`, `buildAttributedStringIfNeeded`, or `updateAdditionalContentHeightIfNeeded`.
Effect:   If called from a background thread, the work is synchronously dispatched to the main thread to prevent race conditions with UI rendering.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:415 -- `if ([NSThread currentThread] != [NSThread mainThread]) { dispatch_sync(dispatch_get_main_queue(), ^{ ... }); }`

Contract: URL Preview Update Notification
Category: N
Trigger:  Successful or failed fetching of a URL preview via `refreshURLPreviewForEventId:`.
Effect:   An asynchronous `URLPreviewDidUpdateNotification` is posted on the main thread's `NSNotificationCenter`, containing the `eventId` and `roomId`.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:1614 -- `[NSNotificationCenter.defaultCenter postNotificationName:URLPreviewDidUpdateNotification object:nil userInfo:userInfo];`

Contract: Initial State Machine
Category: L
Trigger:  Object creation via `initWithEvent:andRoomState:andRoomDataSource:`.
Effect:   The object's `tag`, `collapsable`, and `collapsed` properties are set based on the `eventType`, defining its fundamental lifecycle behavior and appearance.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:98 -- `switch (event.eventType) { ... self.tag = ...; self.collapsable = ...; self.collapsed = ...; }`

Contract: Cross-Object State Propagation
Category: P
Trigger:  Receiving a "voice broadcast stopped" state event.
Effect:   The code finds a *different* `RoomBubbleCellData` instance (the one for the start event) in the `roomDataSource` and force-mutates its `tag` and `voiceBroadcastState` properties.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:306 -- `RoomBubbleCellData *bubbleData = [roomDataSource cellDataOfEventWithEventId:voiceBroadcastInfo.voiceBroadcastId]; bubbleData.tag = RoomBubbleCellDataTagVoiceBroadcastPlayback; bubbleData.voiceBroadcastState = VoiceBroadcastInfo.stoppedValue;`

Contract: Thread-Safe Component Access
Category: S
Trigger:  Accessing `attributedTextMessage` or `attributedTextMessageWithoutPositioningSpace` properties, which calls `buildAttributedStringIfNeeded`.
Effect:   Access to the `bubbleComponents` array is wrapped in an `@synchronized` block to prevent race conditions during read/write operations.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:791 -- `@synchronized(bubbleComponents)`

Contract: Global Setting Dependency
Category: D
Trigger:  Checking for thread roots (`hasThreadRoot`), thread summaries (`threadSummaryViewHeightForEventId:`), or URL previews (`refreshURLPreviewForEventId:`).
Effect:   The behavior depends on the state of the `RiotSettings.shared` singleton (e.g., `enableThreads`, `roomScreenShowsURLPreviews`).
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:1175 -- `if (!RiotSettings.shared.enableThreads)`

Contract: Silent URL Preview Failure
Category: E
Trigger:  The `URLPreviewService` fails to fetch a preview in `refreshURLPreviewForEventId:`.
Effect:   The error is logged, but the UI state is silently updated to hide the preview (`component.showURLPreview = NO;`), preventing a crash and gracefully degrading.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:1610 -- `failure:^(NSError * _Nullable error) { ... component.showURLPreview = NO; [self invalidateLayout]; ... }`

Contract: Lazy Re-computation Flag
Category: M
Trigger:  Setting properties like `selectedEventId`, `containsLastMessage`, or calling `invalidateLayout`.
Effect:   An internal state is mutated (`[self invalidateTextLayout]`, `setNeedsUpdateAdditionalContentHeight`) which flags the attributed string or layout heights as dirty, causing them to be recalculated on the next display pass.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:610 -- `[self invalidateTextLayout]; [self setNeedsUpdateAdditionalContentHeight];`

Contract: Dynamic Cell Visibility
Category: L
Trigger:  Calling `hasNoDisplay`.
Effect:   The visibility of the entire cell is determined by its `tag` and other state (e.g., `beaconInfoSummary`), deciding if it should be rendered in the timeline.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:480 -- `- (BOOL)hasNoDisplay { switch (self.tag) { ... } }`

Contract: Thread-Safe Static Initialization
Category: S
Trigger:  First-time access to `[RoomBubbleCellData timestampVerticalWhitespace]`.
Effect:   A `@synchronized` block protects the initialization of the `static` variable `timestampVerticalWhitespace`.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:1286 -- `@synchronized(self) { if (timestampVerticalWhitespace == nil) { ... } }`

Contract: One-Time Static Initialization
Category: S
Trigger:  First-time calculation of reaction height via `reactionHeightForEventId:`.
Effect:   `dispatch_once` ensures that the `reactionsViewSizer` static variable is initialized only once, making it a thread-safe singleton.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:1212 -- `static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ reactionsViewSizer = [RoomReactionsViewSizer new]; });`

Contract: External Service Dependency
Category: D
Trigger:  Initiating a URL preview fetch.
Effect:   The class calls out to a shared singleton, `URLPreviewService.shared`, to perform the network request and data processing.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:1603 -- `[URLPreviewService.shared previewFor:component.link ...]`

Contract: Show All Reactions State
Category: M
Trigger:  Calling `setShowAllReactions:forEvent:`.
Effect:   The `eventId` is added to or removed from the internal `eventsToShowAllReactions` `NSMutableSet`, changing the state used for rendering reactions.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:1546 -- `[self.eventsToShowAllReactions addObject:eventId];`

Contract: Key Verification State Update
Category: L
Trigger:  The `keyVerification` property is set, which calls `keyVerificationDidUpdate`.
Effect:   The cell's `tag` is changed based on the `state` of the `MXKeyVerification` object, altering its appearance and behavior.
Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:1483 -- `- (void)keyVerificationDidUpdate { ... self.tag = cellDataTag; }`

TOTAL CONTRACTS FOUND: 14
CATEGORY BREAKDOWN: M=2 L=4 N=1 S=4 E=1 C=0 D=2 P=1

---
## Section 4: Boundary Discovery

EXTERNAL_DEPENDENCY: Riot/Modules/Room/RoomViewController.m -- Likely observes `URLPreviewDidUpdateNotification` to reload the corresponding table view cell.
EXTERNAL_DEPENDENCY: Riot/Modules/Room/MXKRoomViewController.m -- Likely observes `URLPreviewDidUpdateNotification` to reload cells if it's still in use.
EXTERNAL_DEPENDENCY: MXKRoomDataSource.m -- Calls `initWithEvent`, `addEvent`, and `mergeWithBubbleCellData` to manage the lifecycle of `RoomBubbleCellData` instances. Also provides the `cellDataOfEventWithEventId:` used for cross-object propagation.
EXTERNAL_DEPENDENCY: Riot/Modules/Room/Views/TableViewCells/RoomBubbleTableViewCell.swift -- Consumes the calculated properties like `attributedTextMessage`, `additionalContentHeight`, and `tag` to render the cell UI. It's also the component that respects the main-thread synchronization contracts.
EXTERNAL_DEPENDENCY: Riot/Utils/RiotSettings.swift -- Provides the global `shared` singleton that `RoomBubbleCellData` depends on to control features like threads and URL previews.
EXTERNAL_DEPENDENCY: Riot/Services/URLPreview/URLPreviewService.swift -- Provides the `shared` singleton service used to fetch URL previews.
EXTERNAL_DEPENDENCY: RoomTimelineConfiguration.swift -- Provides the `shared` singleton that `RoomBubbleCellData` depends on for styling and merging decisions.
ClearcutLogger: Flush already in progress, marking pending flush.
