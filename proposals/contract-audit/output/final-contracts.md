# Final Contract Spec
# Generated: 2026-03-08
# Auditor artifacts: proposals/contract-audit/output/runs/20260308-200516/claude-artifacts/all-artifacts.md
# Adversary review: proposals/contract-audit/output/runs/20260308-200516/codex-review.md
# DEGRADED: no

## Merge Summary

| Action      | Count |
|-------------|-------|
| CONFIRM     | 23    |
| DISPUTE     | 12    |
| ADD         | 3     |
| META_ISSUE  | 3     |
| NEW (Coverage gap) | 1 |
| **Total contracts** | **40** |

### DISPUTE Resolutions

| ID | Verdict | Reason |
|----|---------|--------|
| L-001 | ACCEPTED | Enum has 18 tags (Message..VoiceBroadcastNoDisplay), not 17. Fixed. |
| L-002 | ACCEPTED | Default path leaves collapsable/collapsed untouched. Fixed condition text. |
| L-006 | ACCEPTED | Guard order starts with hasThreadRoot/style, then tag/event. Fixed ordering. |
| L-010 | ACCEPTED | Poll-end guard applies only when `self.tag == Poll`. Fixed condition. |
| M-001 | ACCEPTED | setCollapsed: invalidation is conditional on collapsed-series header. Fixed description. |
| M-007 | ACCEPTED | Additional-height update can run independently of position refresh. Fixed ordering. |
| S-002 | ACCEPTED | No dispatch_sync in method body; deadlock claim overstated. Risk downgraded. |
| S-003 | ACCEPTED | Code guards against dispatch_sync on main. Risk description clarified. |
| D-001 | ACCEPTED | Access is lazy at call sites, not required before creation. Fixed condition. |
| D-002 | ACCEPTED | Method exits early when preview should not show; not stuck loading forever. Fixed risk. |
| D-004 | ACCEPTED | Superclass field is `__weak`, not `unsafe_unretained`. Fixed. |
| P-001 | ACCEPTED | No nil/existence check before cross-object mutation. Condition clarified. |

### META_ISSUE Resolutions

| ID | Field | Change |
|----|-------|--------|
| L-003 | Scope | `class` -> `method` |
| S-001 | Scope | `class` -> `method` |
| N-001 | Seam_Type | `none` -> `link` |

---

## Contracts

---

### L-001: Event Type to Tag Classification

```
Trigger:      initWithEvent:andRoomState:andRoomDataSource: is called with an MXEvent
Input:        event.eventType, event.content, event.type, event.location, event.stateKey, roomState.stateEvents, roomDataSource
Output:       self.tag is set to one of 18 RoomBubbleCellDataTag enum values
Condition:    Switch on event.eventType with sub-conditions for MXEventTypeCustom (widget type, voice broadcast state) and MXEventTypeRoomMessage (location, voice broadcast chunk)
Ordering:     Before L-002, before keyVerificationDidUpdate call at line 272
Risk:         CRITICAL -- Tag determines entire cell display behavior; missing a case silently falls to default (tag=0=RoomBubbleCellDataTagMessage)
Evidence:     RoomBubbleCellData.m:62-270 -- `switch (event.eventType) { case MXEventTypeRoomMember: { self.tag = RoomBubbleCellDataTagMembership; ...`; RoomBubbleCellData.h:16-36 -- enum defines 18 values (Message through VoiceBroadcastNoDisplay)
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

### L-002: Collapsable/Collapsed State Initialization

```
Trigger:      initWithEvent:andRoomState:andRoomDataSource: is called
Input:        event.eventType (determines which case in the switch)
Output:       self.collapsable and self.collapsed are set (YES/YES for membership/create/topic/call; NO/NO for poll/beacon/voiceBroadcast/location); default path leaves values untouched (inherits super defaults)
Condition:    Determined by the same switch as L-001; default case does not set collapsable/collapsed
Ordering:     Set during L-001, before line 275 (maxComponentCount)
Risk:         HIGH -- Incorrect defaults cause timeline rendering errors (events that should collapse don't, or vice versa)
Evidence:     RoomBubbleCellData.m:70-73 -- `self.collapsable = YES; self.collapsed = YES;`; RoomBubbleCellData.m:268 -- `default: break;`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### L-003: Key Verification State Machine

```
Trigger:      keyVerification property setter is called, OR initWithEvent: completes (line 272)
Input:        event.eventType, _keyVerification.state, _keyVerification.transaction.reasonCancelCode, self.isIncoming, self.isKeyVerificationOperationPending
Output:       self.tag is updated to KeyVerificationNoDisplay, KeyVerificationConclusion, KeyVerificationRequest, or KeyVerificationRequestIncomingApproval
Condition:    Multiple nested conditions: event must be MXEventTypeKeyVerificationCancel, Done, or RoomMessage with kMXMessageTypeKeyVerificationRequest
Ordering:     Called at end of initWithEvent: (line 272); also called when keyVerification property is set (line 1261)
Risk:         HIGH -- Incorrect tag assignment hides verification UI or shows it when it shouldn't
Evidence:     RoomBubbleCellData.m:1264-1341 -- `- (void)keyVerificationDidUpdate { ... switch (event.eventType) { case MXEventTypeKeyVerificationCancel: ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

### L-004: Cell Visibility (hasNoDisplay)

```
Trigger:      hasNoDisplay is called (by rendering pipeline)
Input:        self.tag, self.beaconInfoSummary, self.events.lastObject.isEditEvent
Output:       BOOL indicating whether cell should be hidden from timeline
Condition:    Switch on self.tag; KeyVerificationNoDisplay/VoiceBroadcastNoDisplay -> YES; RoomCreationIntro/Location/VoiceBroadcast(Record|Playback)/RTCCallNotify -> NO; LiveLocation -> NO only if beaconInfoSummary exists; Poll -> NO only if not edit event; default -> delegates to super
Ordering:     Independent, but depends on tag being correctly set by L-001/L-003
Risk:         MEDIUM -- Incorrect visibility hides events from user or shows phantom cells
Evidence:     RoomBubbleCellData.m:349-396 -- `- (BOOL)hasNoDisplay { ... switch (self.tag) { ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

### L-005: Collapsed State Change with Layout Invalidation

```
Trigger:      setCollapsed: is called with a different value than current
Input:        collapsed (BOOL), self.collapsedAttributedTextMessage, self.nextCollapsableCellData
Output:       super.collapsed is updated; if this is a series header, text layout is invalidated
Condition:    collapsed != self.collapsed AND self.collapsedAttributedTextMessage AND self.nextCollapsableCellData
Ordering:     After super.collapsed is set
Risk:         LOW -- Missing invalidation would show stale text until next full refresh
Evidence:     RoomBubbleCellData.m:470-482 -- `- (void)setCollapsed:(BOOL)collapsed { if (collapsed != self.collapsed) { super.collapsed = collapsed; ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### L-006: Event Addition Guard (addEvent:andRoomState:)

```
Trigger:      addEvent:andRoomState: is called to attempt merging a new event into this bubble
Input:        self.tag, self.hasThreadRoot, event.eventType, event.location, event.content, timelineConfiguration.currentStyle
Output:       BOOL (YES if event was added, NO if rejected); side effect: URL preview refresh if added
Condition:    Three-phase guard: (1) hasThreadRoot short-circuit, (2) style gating via canAddEvent:and:to:, (3) tag/event type switch
Ordering:     hasThreadRoot check at line 1100, style check at line 1107, then tag switch; before super.addEvent:andRoomState:
Risk:         HIGH -- Allowing an event into the wrong bubble corrupts timeline; rejecting a valid event creates orphan cells
Evidence:     RoomBubbleCellData.m:1098-1255 -- `- (BOOL)addEvent:(MXEvent*)event andRoomState:(MXRoomState*)roomState { if (self.hasThreadRoot) { return NO; } ...`; :1107 -- `canAddEvent:event and:roomState to:self`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

### L-007: Merge Guard (mergeWithBubbleCellData:)

```
Trigger:      mergeWithBubbleCellData: is called by roomDataSource
Input:        bubbleCellData, RoomTimelineConfiguration.shared.currentStyle
Output:       BOOL (YES if merge allowed)
Condition:    timelineConfiguration.currentStyle.canMergeWithCellData:into: must return YES
Ordering:     Before super.mergeWithBubbleCellData:
Risk:         MEDIUM -- Incorrect merging creates visual artifacts in timeline
Evidence:     RoomBubbleCellData.m:415-423 -- `- (BOOL)mergeWithBubbleCellData:(id<MXKRoomBubbleCellDataStoring>)bubbleCellData { ...`
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

### L-008: Collapse Guard (collapseWith:)

```
Trigger:      collapseWith: is called to determine if two cells can be collapsed
Input:        self.tag, cellData.tag, event content (call IDs), date strings
Output:       BOOL (YES if collapse allowed)
Condition:    Membership cells: same tag + not conference user + same date; RoomCreateConfiguration: always YES; Call: same callId; RoomCreateWithPredecessor: always NO; default: delegates to super
Ordering:     Independent
Risk:         MEDIUM -- Incorrect collapse merges unrelated events visually
Evidence:     RoomBubbleCellData.m:427-468 -- `- (BOOL)collapseWith:(id<MXKRoomBubbleCellDataStoring>)cellData { ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### L-009: hasThreadRoot Guard

```
Trigger:      hasThreadRoot getter is called
Input:        RiotSettings.shared.enableThreads, roomDataSource.threadId
Output:       BOOL -- NO if threads disabled or in thread view, otherwise super.hasThreadRoot
Condition:    Guard on feature flag and context
Ordering:     Independent
Risk:         LOW -- Incorrect value affects thread root display
Evidence:     RoomBubbleCellData.m:398-413 -- `- (BOOL)hasThreadRoot { if (!RiotSettings.shared.enableThreads) { return NO; } ...`
Scope:        method
Seam_Type:    preprocessing
Pinch_Point:  false
```

### L-010: hasSameSenderAsBubbleCellData Guard

```
Trigger:      hasSameSenderAsBubbleCellData: is called during cell grouping
Input:        self.tag, bubbleCellData.tag, self.hasThreadRoot, bubbleCellData.hasThreadRoot, event.eventType (for poll end)
Output:       BOOL -- NO for membership, room create with predecessor, thread roots, poll end events (only when self.tag == Poll); otherwise super
Condition:    Tag-based and thread-based guards; poll-end guard applies only when self.tag == RoomBubbleCellDataTagPoll
Ordering:     Independent
Risk:         LOW -- Affects sender info display
Evidence:     RoomBubbleCellData.m:1066-1096 -- `- (BOOL)hasSameSenderAsBubbleCellData:(id<MXKRoomBubbleCellDataStoring>)bubbleCellData { ...`; :1080 -- `if (self.tag == RoomBubbleCellDataTagPoll)`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### L-011: UpdateEvent with Tag Mutation

```
Trigger:      updateEvent:withEvent: is called (event content updated, e.g., decryption)
Input:        eventId, event, self.tag, event.eventType, event.content
Output:       Updates URL preview, updates beacon info summary if LiveLocation tag, forces VoiceBroadcastNoDisplay tag if decrypted voice broadcast chunk
Condition:    Tag-specific and event type checks
Ordering:     After super.updateEvent:
Risk:         MEDIUM -- Late decryption of voice broadcast chunks must be hidden; missing this causes duplicate audio display
Evidence:     RoomBubbleCellData.m:287-308 -- `- (NSUInteger)updateEvent:(NSString *)eventId withEvent:(MXEvent *)event { ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

### M-001: Lazy Text Layout Invalidation

```
Trigger:      setSelectedEventId:, setContainsLastMessage:, setCollapsed:, invalidateLayout
Input:        New property value
Output:       Internal flag set so attributedTextMessage will be recomputed on next access
Condition:    For setContainsLastMessage: -- only if _containsLastMessage OR containsLastMessage (i.e., skip if both false). For setSelectedEventId: -- only if _selectedEventId OR selectedEventId.length. For setCollapsed: -- only invalidates if collapsed != self.collapsed AND self.collapsedAttributedTextMessage AND self.nextCollapsableCellData (conditional on collapsed-series header state)
Ordering:     Invalidation happens immediately; recomputation deferred until next read
Risk:         HIGH -- If invalidation is missed, stale text is displayed; if over-invalidated, performance degrades
Evidence:     RoomBubbleCellData.m:486-490 -- `- (void)invalidateLayout { [self invalidateTextLayout]; [self setNeedsUpdateAdditionalContentHeight]; }`; :477 -- `if (self.collapsedAttributedTextMessage && self.nextCollapsableCellData) { [self invalidateTextLayout]; }`
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

### M-002: Attributed String Construction

```
Trigger:      buildAttributedString is called (via buildAttributedStringIfNeeded)
Input:        bubbleComponents array, selectedComponentIndex, containsLastMessage, mostRecentComponentIndex, collapsed state, collapsedAttributedTextMessage
Output:       self.attributedTextMessage and self.attributedTextMessageWithoutPositioningSpace are set
Condition:    If collapsed and has collapsedAttributedTextMessage and nextCollapsableCellData -> use collapsed string; otherwise iterate all components
Ordering:     Must be on main thread (enforced by S-003); must be inside @synchronized(bubbleComponents) (enforced by S-001)
Risk:         CRITICAL -- This is the primary rendering output; any bug here causes visible timeline corruption
Evidence:     RoomBubbleCellData.m:492-612 -- `- (void)buildAttributedString { ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

### M-003: Component Alpha Blending for Selection

```
Trigger:      buildAttributedString is called with a selectedComponentIndex != NSNotFound
Input:        selectedComponentIndex, component.attributedTextMessage
Output:       Non-selected components get alpha 0.2 applied; Pills get alpha adjusted via PillsFormatter
Condition:    selectedComponentIndex != NSNotFound && selectedComponentIndex != current index && componentString.length > 0
Ordering:     During M-002 string construction loop
Risk:         MEDIUM -- Missing alpha reset causes permanently dimmed messages; iOS 15 availability check for Pills
Evidence:     RoomBubbleCellData.m:526-538 -- `componentString = [componentString withTextColorAlpha:.2]; if (@available(iOS 15.0, *)) { [PillsFormatter setPillAlpha:.2 ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### M-004: Show All Reactions State

```
Trigger:      setShowAllReactions:forEvent: is called
Input:        showAllReactions (BOOL), eventId (NSString)
Output:       eventId is added to or removed from self.eventsToShowAllReactions NSMutableSet
Condition:    showAllReactions == YES -> add; NO -> remove
Ordering:     Independent; consumed by reactionHeightForEventId:
Risk:         LOW -- Incorrect state shows truncated or full reactions
Evidence:     RoomBubbleCellData.m:1350-1360 -- `- (void)setShowAllReactions:(BOOL)showAllReactions forEvent:(NSString*)eventId { ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### M-005: URL Preview Data Mutation (Success Path)

```
Trigger:      URLPreviewService.shared success callback in refreshURLPreviewForEventId:
Input:        urlPreviewData from service, component reference
Output:       component.urlPreviewData = urlPreviewData; layout invalidated
Condition:    MXStrongifyAndReturnIfNil(self) -- silently drops update if self deallocated
Ordering:     Before N-001 notification dispatch
Risk:         HIGH -- component is mutated on callback thread (potentially background), then notification dispatched to main; race window between mutation and main-thread read
Evidence:     RoomBubbleCellData.m:1452-1461 -- `component.urlPreviewData = urlPreviewData; [self invalidateLayout]; dispatch_async(dispatch_get_main_queue(), ^{ ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### M-006: URL Preview Data Clear on Edit

```
Trigger:      refreshURLPreviewForEventId: is called when component already has urlPreviewData
Input:        component.urlPreviewData (non-nil means message was edited)
Output:       component.urlPreviewData = nil (shows loading state)
Condition:    component.urlPreviewData != nil
Ordering:     Before the URLPreviewService fetch call
Risk:         LOW -- Momentary loading state during edit
Evidence:     RoomBubbleCellData.m:1436-1439 -- `if (component.urlPreviewData) { component.urlPreviewData = nil; }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### M-007: Additional Content Height Computation

```
Trigger:      updateAdditionalContentHeightIfNeeded is called (from prepareBubbleComponentsPosition, line 332)
Input:        All bubble components' eventIds; urlPreview/reaction/thread/readReceipt heights
Output:       self.additionalContentHeight is set to sum of all component heights
Condition:    self.shouldUpdateAdditionalContentHeight == YES
Ordering:     Called from prepareBubbleComponentsPosition but can execute independently of position refresh (line 332 is outside the shouldUpdateComponentsPosition guard)
Risk:         MEDIUM -- Incorrect height causes cell clipping or excess whitespace
Evidence:     RoomBubbleCellData.m:772-788 -- `- (CGFloat)computeAdditionalHeight { ...`; :312 -- `if (shouldUpdateComponentsPosition)` ... :332 -- `[self updateAdditionalContentHeightIfNeeded];`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### M-008: Vertical Whitespace Injection

```
Trigger:      addVerticalWhitespaceToString:forEvent: during buildAttributedString or refreshBubbleComponentsPosition
Input:        eventId; heights from urlPreview, reactions, threadSummary, fromAThread, readReceipts
Output:       Attributed string gets newline characters appended to create visual spacing
Condition:    additionalVerticalHeight > 0
Ordering:     After component text is appended, before next separator
Risk:         MEDIUM -- Incorrect spacing causes layout jumps
Evidence:     RoomBubbleCellData.m:751-770 -- `- (void)addVerticalWhitespaceToString:(NSMutableAttributedString *)attributedString forEvent:(NSString *)eventId { ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### M-009: Blockquote Display Fix

```
Trigger:      buildAttributedString detects MXKRoomBubbleComponentDisplayFixHtmlBlockquote
Input:        self.displayFix flag
Output:       Seven space characters appended to attributedTextMessageWithoutPositioningSpace
Condition:    self.displayFix & MXKRoomBubbleComponentDisplayFixHtmlBlockquote
Ordering:     After all component strings are assembled, before final assignment
Risk:         LOW -- Visual-only fix for quote messages
Evidence:     RoomBubbleCellData.m:604-607 -- `if (self.displayFix & MXKRoomBubbleComponentDisplayFixHtmlBlockquote) { [currentAttributedTextMsgWithoutVertSpace appendString:@"       "]; }`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### M-010: Beacon Info Summary Update

```
Trigger:      updateBeaconInfoSummaryWithId:andEvent: called from initWithEvent: or updateEvent:
Input:        eventId, event (must be MXEventTypeBeaconInfo), mxSession.aggregations.beaconAggregations
Output:       self.beaconInfoSummary set (may be nil if no summary found)
Condition:    event.eventType must be MXEventTypeBeaconInfo (logs error otherwise)
Ordering:     During initialization or event update
Risk:         MEDIUM -- Missing beaconInfoSummary causes LiveLocation cell to be hidden (L-004)
Evidence:     RoomBubbleCellData.m:1478-1504 -- `- (void)updateBeaconInfoSummaryWithId:(NSString *)eventId andEvent:(MXEvent*)event { ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### M-011: maxComponentCount Override

```
Trigger:      initWithEvent: completion (line 275)
Input:        None (hardcoded)
Output:       self.maxComponentCount = 20
Condition:    Always, after tag classification
Ordering:     After L-001, before invalidateTextLayout
Risk:         LOW -- Changing this value affects how many events can be merged into one bubble
Evidence:     RoomBubbleCellData.m:275 -- `self.maxComponentCount = 20;`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

### N-001: URLPreviewDidUpdateNotification

```
Trigger:      URLPreviewService fetch completes (success or failure) in refreshURLPreviewForEventId:
Input:        eventId, self.roomId
Output:       NSNotification posted with name "URLPreviewDidUpdateNotification", object: nil, userInfo: { "eventId": eventId, "roomId": roomId }
Condition:    MXStrongifyAndReturnIfNil(self) -- notification not sent if self is deallocated
Ordering:     After component.urlPreviewData/showURLPreview is mutated; dispatched async to main queue
Risk:         CRITICAL -- Notification is the sole mechanism for UI refresh after URL preview load; thread contract (main queue) must be preserved; userInfo key names are implicit contracts with observers
Evidence:     RoomBubbleCellData.m:1459-1461 -- `dispatch_async(dispatch_get_main_queue(), ^{ [NSNotificationCenter.defaultCenter postNotificationName:URLPreviewDidUpdateNotification object:nil userInfo:userInfo]; });`
Scope:        module
Seam_Type:    link
Pinch_Point:  true
```

---

### S-001: @synchronized(bubbleComponents) in buildAttributedStringIfNeeded

```
Trigger:      attributedTextMessage or attributedTextMessageWithoutPositioningSpace getter is called
Input:        bubbleComponents array
Output:       Mutual exclusion on bubbleComponents during read + potential write (buildAttributedString)
Condition:    Always wraps the dirty-check and build
Ordering:     Acquires lock before checking hasAttributedTextMessage; holds lock during buildAttributedString (which may dispatch_sync to main)
Risk:         CRITICAL -- If dispatch_sync to main thread occurs while @synchronized is held, and the main thread is waiting for this same @synchronized, DEADLOCK. This is the most dangerous contract in the entire module.
Evidence:     RoomBubbleCellData.m:616-636 -- `@synchronized(bubbleComponents) { if (self.hasAttributedTextMessage && !attributedTextMessage.length) { ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  true
```

### S-002: @synchronized(bubbleComponents) in refreshBubbleComponentsPosition

```
Trigger:      refreshBubbleComponentsPosition is called (from prepareBubbleComponentsPosition)
Input:        bubbleComponents array
Output:       Mutual exclusion on bubbleComponents during position computation
Condition:    Always
Ordering:     Acquires lock, iterates all components, sets position property
Risk:         MEDIUM -- Lock only iterates/sets positions with no dispatch_sync in method body; no inherent deadlock risk in this method alone
Evidence:     RoomBubbleCellData.m:671-749 -- `@synchronized(bubbleComponents) { ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### S-003: Main Thread Enforcement via dispatch_sync

```
Trigger:      prepareBubbleComponentsPosition, buildAttributedStringIfNeeded, updateAdditionalContentHeightIfNeeded detect they are NOT on main thread
Input:        [NSThread currentThread] != [NSThread mainThread]
Output:       Work is synchronously dispatched to main queue via dispatch_sync(dispatch_get_main_queue(), ...)
Condition:    Not on main thread (explicitly guarded: dispatch_sync only fires when caller is NOT on main)
Ordering:     Blocks calling thread until main thread completes the work
Risk:         HIGH -- dispatch_sync to main while holding @synchronized(bubbleComponents) can deadlock if main thread is waiting to acquire the same lock; however, dispatch_sync-on-main-from-main is explicitly guarded against
Evidence:     RoomBubbleCellData.m:317-322 -- `if ([NSThread currentThread] != [NSThread mainThread]) { dispatch_sync(dispatch_get_main_queue(), ^{ [self refreshBubbleComponentsPosition]; }); }`; also m:623-628, m:801-806
Scope:        class
Seam_Type:    none
Pinch_Point:  true
```

### S-004: @synchronized(self) for Static timestampVerticalWhitespace

```
Trigger:      First call to +[RoomBubbleCellData timestampVerticalWhitespace]
Input:        Static variable timestampVerticalWhitespace (initially nil)
Output:       Lazily initialized NSAttributedString with newline, black color, 12pt system font
Condition:    timestampVerticalWhitespace == nil
Ordering:     Lock on class object (self in class method context)
Risk:         LOW -- Standard lazy initialization pattern; low contention
Evidence:     RoomBubbleCellData.m:1036-1047 -- `@synchronized(self) { if (timestampVerticalWhitespace == nil) { ...`
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

### S-005: dispatch_once for reactionsViewSizer

```
Trigger:      First call to reactionHeightForEventId: with non-zero reaction count
Input:        None
Output:       Static RoomReactionsViewSizer instance created once
Condition:    dispatch_once guarantees single initialization
Ordering:     Before height calculation
Risk:         LOW -- Standard singleton pattern; thread-safe by GCD guarantee
Evidence:     RoomBubbleCellData.m:902-905 -- `static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ reactionsViewSizer = [RoomReactionsViewSizer new]; });`
Scope:        class
Seam_Type:    none
Pinch_Point:  false
```

---

### E-001: Silent URL Preview Failure

```
Trigger:      URLPreviewService.shared failure callback in refreshURLPreviewForEventId:
Input:        NSError (logged but not propagated)
Output:       component.showURLPreview = NO; layout invalidated; notification sent (same as success)
Condition:    MXStrongifyAndReturnIfNil(self)
Ordering:     Same as success path minus setting urlPreviewData
Risk:         MEDIUM -- Error is swallowed; no retry mechanism; user sees preview disappear silently
Evidence:     RoomBubbleCellData.m:1463-1475 -- `failure:^(NSError * _Nullable error) { ... component.showURLPreview = NO; [self invalidateLayout]; ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

### C-001: URL Preview Fetch Has No Cancellation Contract

```
Trigger:      RoomBubbleCellData is deallocated or cell data is replaced while URL preview fetch is in-flight
Input:        In-flight URLPreviewService request
Output:       No cancellation occurs; MXWeakify/MXStrongifyAndReturnIfNil silently drops the callback if self is deallocated, but the network request itself continues
Condition:    Always -- there is no cancellation token, no tracking of in-flight requests, and no cleanup in dealloc
Ordering:     N/A (absence of contract)
Risk:         MEDIUM -- Wasted network resources; potential for stale callbacks if object is quickly re-created for same event; in Swift migration, must decide whether to adopt Task cancellation or replicate the silent-drop pattern
Evidence:     RoomBubbleCellData.m:1449-1475 -- `[URLPreviewService.shared previewFor:... success:^(...) { MXStrongifyAndReturnIfNil(self); ... } failure:^(...) { MXStrongifyAndReturnIfNil(self); ... }]` -- no cancel/dealloc handling
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

---

### D-001: RoomTimelineConfiguration.shared Dependency

```
Trigger:      mergeWithBubbleCellData: and addEvent:andRoomState:
Input:        RoomTimelineConfiguration.shared.currentStyle
Output:       Style object gates merge and add decisions
Condition:    Accessed lazily at method call sites (not required to be initialized before cell data creation)
Ordering:     Read at point of use
Risk:         MEDIUM -- Singleton not available or style changed mid-render could cause inconsistency
Evidence:     RoomBubbleCellData.m:417 -- `RoomTimelineConfiguration *timelineConfiguration = [RoomTimelineConfiguration shared];`
Scope:        module
Seam_Type:    object
Pinch_Point:  false
```

### D-002: URLPreviewService.shared Dependency

```
Trigger:      refreshURLPreviewForEventId:
Input:        URLPreviewService.shared singleton
Output:       Network fetch for URL preview data
Condition:    Singleton must be initialized; method exits early if shouldShowPreviewFor returns NO
Ordering:     After RiotSettings check (D-003); guarded by showURLPreview check at line 1429
Risk:         LOW -- ObjC message to nil returns nil; callback never fires; method's early return at line 1429 prevents stuck loading state
Evidence:     RoomBubbleCellData.m:1449 -- `[URLPreviewService.shared previewFor:component.link ...`; :1428-1431 -- `component.showURLPreview = ... && [URLPreviewService.shared shouldShowPreviewFor:...]; if (!component.showURLPreview) { return; }`
Scope:        module
Seam_Type:    object
Pinch_Point:  false
```

### D-003: RiotSettings.shared Dependency

```
Trigger:      hasThreadRoot, threadSummaryViewHeightForEventId:, fromAThreadViewHeightForEventId:, refreshURLPreviewForEventId:
Input:        RiotSettings.shared.enableThreads, RiotSettings.shared.roomScreenShowsURLPreviews
Output:       Feature flag gates behavior
Condition:    Always read from singleton; no caching
Ordering:     Read at call time; value can change between reads
Risk:         HIGH -- Settings change during cell data lifecycle could cause inconsistent state (e.g., thread summary shown for some events but not others in same bubble)
Evidence:     RoomBubbleCellData.m:400 -- `if (!RiotSettings.shared.enableThreads)`, m:824, m:851, m:1428
Scope:        module
Seam_Type:    preprocessing
Pinch_Point:  false
```

### D-004: roomDataSource Dependency (Multiple Uses)

```
Trigger:      initWithEvent: (voice broadcast cross-object mutation), collapseWith: (date formatting), addEvent: (mxSession access for widget creation)
Input:        roomDataSource (passed in init, stored in super)
Output:       Used for cellDataOfEventWithEventId:, eventFormatter, mxSession, roomState, threadId
Condition:    Assumed non-nil and fully initialized
Ordering:     Must be set before any method call
Risk:         HIGH -- roomDataSource is __weak in MXKit superclass (not unsafe_unretained); if deallocated, messages to nil return nil/0 rather than crashing, but logic may silently produce incorrect results
Evidence:     RoomBubbleCellData.m:238 -- `RoomBubbleCellData *bubbleData = [roomDataSource cellDataOfEventWithEventId:voiceBroadcastInfo.voiceBroadcastId];`; MXKRoomBubbleCellData.h:29 -- `__weak MXKRoomDataSource *roomDataSource;`
Scope:        module
Seam_Type:    object
Pinch_Point:  true
```

### D-005: mxSession Dependency (Beacon Aggregations)

```
Trigger:      updateBeaconInfoSummaryWithId:andEvent:
Input:        self.mxSession.aggregations.beaconAggregations
Output:       beaconInfoSummary retrieved for eventId in roomId
Condition:    mxSession must be initialized with aggregations support
Ordering:     Called during init or updateEvent:
Risk:         MEDIUM -- nil mxSession returns nil beaconInfoSummary, causing LiveLocation cell to be hidden
Evidence:     RoomBubbleCellData.m:1488 -- `id<MXBeaconInfoSummaryProtocol> beaconInfoSummary = [self.mxSession.aggregations.beaconAggregations beaconInfoSummaryFor:eventId inRoomWithId:self.roomId];`
Scope:        method
Seam_Type:    object
Pinch_Point:  false
```

### D-006: URL Preview Observer Coupling (ADD)

```
Trigger:      URLPreviewDidUpdateNotification is observed in RoomViewController
Input:        Notification userInfo with "roomId" and "eventId" keys
Output:       Consumer relies on roomId/eventId to locate index path and reload cell/table
Condition:    Observer must be registered; userInfo keys must match exactly
Ordering:     After N-001 posts the notification
Risk:         HIGH -- If userInfo key names change, observer silently fails to update; implicit string contract spans module boundary
Evidence:     Riot/Modules/Room/RoomViewController.m:1875 -- `addObserverForName:URLPreviewDidUpdateNotification ...`; :1880 -- `notification.userInfo[@"roomId"]`; :1886 -- `notification.userInfo[@"eventId"]`; :1903 -- `[self dataSource:self.roomDataSource didCellChange:updatedIndexPath];`
Scope:        module
Seam_Type:    link
Pinch_Point:  true
```

### D-007: DataSource Lifecycle Dispatch to CellData (ADD)

```
Trigger:      Timeline processing in MXKRoomDataSource
Input:        MXEvent from timeline, existing cell data array
Output:       External engine invokes addEvent:, falls back to initWithEvent:, and later invokes mergeWithBubbleCellData:, so RoomBubbleCellData behavior is orchestrator-dependent
Condition:    RoomDataSource controls which method is called and in what order
Ordering:     addEvent: tried first, then initWithEvent:, then merge pass
Risk:         HIGH -- RoomBubbleCellData's lifecycle contracts (L-006, L-007) assume specific call ordering from the data source; changes in data source logic silently break cell data invariants
Evidence:     Riot/Modules/MatrixKit/Models/Room/MXKRoomDataSource.m:3252 -- `eventManaged = [bubbleData addEvent:...];`; :3259 -- `[[class alloc] initWithEvent:... andRoomDataSource:self]`; :2624 -- `[cellData1 mergeWithBubbleCellData:cellData2]`
Scope:        module
Seam_Type:    object
Pinch_Point:  true
```

---

### P-001: Cross-Object Voice Broadcast State Propagation

```
Trigger:      initWithEvent: when voice broadcast state event is "stopped"
Input:        voiceBroadcastInfo.voiceBroadcastId (references a different event's cell data)
Output:       A DIFFERENT RoomBubbleCellData instance has its tag changed to VoiceBroadcastPlayback and voiceBroadcastState set to stoppedValue
Condition:    VoiceBroadcastInfo.isStoppedFor:voiceBroadcastInfo.state == YES; no nil/existence check on the returned bubbleData before property mutation (ObjC silently messages nil, so mutation is a no-op if target doesn't exist)
Ordering:     During init of the "stopped" event's cell data
Risk:         CRITICAL -- Cross-object mutation without synchronization; target object may be in use by rendering pipeline; in Swift migration, if cell data becomes a value type, this mutation would be on a copy; nil target silently drops the mutation
Evidence:     RoomBubbleCellData.m:234-241 -- `RoomBubbleCellData *bubbleData = [roomDataSource cellDataOfEventWithEventId:voiceBroadcastInfo.voiceBroadcastId]; bubbleData.tag = RoomBubbleCellDataTagVoiceBroadcastPlayback; bubbleData.voiceBroadcastState = VoiceBroadcastInfo.stoppedValue;`
Scope:        module
Seam_Type:    none
Pinch_Point:  true
```

### P-002: Component Position Propagation

```
Trigger:      refreshBubbleComponentsPosition called from prepareBubbleComponentsPosition
Input:        bubbleComponents array, attachment type, text heights
Output:       Each component's .position CGPoint is set based on cumulative text height
Condition:    bubbleComponentsCount > 0
Ordering:     After @synchronized(bubbleComponents) acquired; positions are consumed by table view cells
Risk:         HIGH -- Incorrect positions cause text overlap or misalignment; rawTextHeight computation depends on main thread font metrics
Evidence:     RoomBubbleCellData.m:667-749 -- `- (void)refreshBubbleComponentsPosition { @synchronized(bubbleComponents) { ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### P-003: Accessibility Label Propagation

```
Trigger:      accessibilityLabel getter is called
Input:        self.attachment (type), self.events.firstObject.content[kMXMessageBodyKey]
Output:       Localized accessibility string combining media type name and message body
Condition:    Only for media attachments (self.attachment != nil); returns nil for text messages
Ordering:     Independent
Risk:         LOW -- Missing accessibility label for text messages (handled by system default)
Evidence:     RoomBubbleCellData.m:1362-1383 -- `- (NSString *)accessibilityLabel { ...`
Scope:        method
Seam_Type:    none
Pinch_Point:  false
```

### P-004: Render-Pull Dependency on Bubble Computations (ADD)

```
Trigger:      Bubble cell layout/render cycle in MXKRoomBubbleTableViewCell
Input:        bubbleData.attributedTextMessage, bubbleData.attributedTextMessageWithoutPositioningSpace, component.position
Output:       UI pull-reads attributed text and forces component-position preparation, propagating model state into rendered layout/timestamp placement
Condition:    Cell is being laid out for display
Ordering:     Cell render triggers attributedTextMessage getter (which triggers S-001/M-002), then calls prepareBubbleComponentsPosition (which triggers S-002/P-002)
Risk:         HIGH -- Pull-based model means any missed invalidation silently shows stale data; caller must ensure model is ready before access
Evidence:     Riot/Modules/Room/TimelineCells/Common/MXKRoomBubbleTableViewCell.m:408 -- `bubbleData.attributedTextMessage`; :613 -- `[bubbleData prepareBubbleComponentsPosition];`; :641 -- `component.position.y`
Scope:        module
Seam_Type:    none
Pinch_Point:  true
```

---

## Completeness Check

| Category | Count | IDs |
|----------|-------|-----|
| L (Lifecycle) | 11 | L-001 .. L-011 |
| M (Mutation) | 11 | M-001 .. M-011 |
| N (Notification) | 1 | N-001 |
| S (Synchronization) | 5 | S-001 .. S-005 |
| E (Error Handling) | 1 | E-001 |
| C (Cancellation) | 1 | C-001 |
| D (Dependency) | 7 | D-001 .. D-007 |
| P (Propagation) | 4 | P-001 .. P-004 |
| **Total** | **41** | |

Pinch Points: L-001, L-003, L-004, L-006, M-001, M-002, N-001, S-001, S-003, D-004, D-006, D-007, P-001, P-004 = **14 pinch points**

COMPLETENESS: 41 contracts, 41 assertions, 0 ast-grep rules (ObjC not supported), 14 pinch_points -- COMPLETE
