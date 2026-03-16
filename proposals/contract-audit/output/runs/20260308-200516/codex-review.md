DISPUTE L-001: Enum cardinality is misstated; header defines 18 tags, not 17.
  Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.h:18 -- `RoomBubbleCellDataTagMessage = 0` ... Riot/Modules/Room/CellData/RoomBubbleCellData.h:35 -- `RoomBubbleCellDataTagVoiceBroadcastNoDisplay`

DISPUTE L-002: `collapsable/collapsed` are not always set in this switch; default path leaves values untouched.
  Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:268 -- `default:` ... `break;`

CONFIRM L-003: `keyVerificationDidUpdate` is called from both init and setter and mutates `self.tag` by event/state.
CONFIRM L-004: `hasNoDisplay` visibility is tag-driven with explicit exceptions and super fallback.
CONFIRM L-005: `setCollapsed:` invalidates text layout for series-header case after state change.
DISPUTE L-006: The guard order is overstated; it first checks thread-root/style gating before tag/event switches.
  Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:1100 -- `if (self.hasThreadRoot) { return NO; }` and :1107 -- `canAddEvent:event ... to:self`

CONFIRM L-007: Merge is gated by `RoomTimelineConfiguration.shared.currentStyle` before super merge.
CONFIRM L-008: `collapseWith:` applies membership/date, room-create, callId, predecessor guards then super.
CONFIRM L-009: `hasThreadRoot` short-circuits on settings/thread context then delegates to super.
DISPUTE L-010: Poll-end guard applies only when `self.tag == Poll`, not universally for both operands.
  Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:1080 -- `if (self.tag == RoomBubbleCellDataTagPoll)`

CONFIRM L-011: `updateEvent` can force `VoiceBroadcastNoDisplay` on decrypted voice-broadcast chunks.

DISPUTE M-001: `setCollapsed:` does not always invalidate; invalidation is conditional on collapsed-series header state.
  Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:477 -- `if (self.collapsedAttributedTextMessage && self.nextCollapsableCellData) { [self invalidateTextLayout]; }`

CONFIRM M-002: `buildAttributedString` sets both attributed outputs with collapsed/non-collapsed branches.
CONFIRM M-003: Non-selected components are alpha-dimmed, with pill alpha adjustments on iOS 15+.
CONFIRM M-004: `setShowAllReactions:forEvent:` mutates `eventsToShowAllReactions` add/remove.
CONFIRM M-005: URL preview success mutates component data and invalidates layout before notification dispatch.
CONFIRM M-006: Existing `urlPreviewData` is cleared before fetch to show loading state.
DISPUTE M-007: Ordering claim is too strict; additional-height update can run without a position refresh.
  Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:312 -- `if (shouldUpdateComponentsPosition)` ... :332 -- `[self updateAdditionalContentHeightIfNeeded];`

CONFIRM M-008: Additional vertical whitespace is computed from URL/reactions/thread/read-receipt heights.
CONFIRM M-009: Blockquote display fix appends seven spaces.
CONFIRM M-010: Beacon summary update enforces beacon-event type and logs on mismatch.
CONFIRM M-011: `maxComponentCount` is explicitly overridden to `20` in init path.

CONFIRM N-001: URL preview completion posts `URLPreviewDidUpdateNotification` on main queue with `eventId/roomId`.

CONFIRM S-001: `buildAttributedStringIfNeeded` wraps dirty-check/build in `@synchronized(bubbleComponents)`.
DISPUTE S-002: “Same deadlock risk as S-001” is overstated for this method; it only locks/iterates/sets positions.
  Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:671 -- `@synchronized(bubbleComponents)` ... no `dispatch_sync` in method body

DISPUTE S-003: Claim includes “dispatch_sync to main while on main”; code explicitly guards against that.
  Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:317 -- `if ([NSThread currentThread] != [NSThread mainThread]) { dispatch_sync(...); }`

CONFIRM S-004: Static `timestampVerticalWhitespace` lazy init is protected by `@synchronized(self)`.
CONFIRM S-005: `dispatch_once` is used for one-time `reactionsViewSizer` initialization.

CONFIRM E-001: Failure callback suppresses preview (`showURLPreview = NO`), invalidates layout, and posts update notification.

DISPUTE D-001: “Must be initialized before any cell data is created” is overstated; access is lazy at method call sites.
  Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:417 -- `RoomTimelineConfiguration *timelineConfiguration = [RoomTimelineConfiguration shared];`

DISPUTE D-002: “Preview stays loading forever if singleton unavailable” is overstated; method exits early when preview should not show.
  Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:1428 -- `component.showURLPreview = ... && [URLPreviewService.shared shouldShowPreviewFor:...]` and :1429 -- `if (!component.showURLPreview) { return; }`

CONFIRM D-003: Multiple behaviors are directly gated by `RiotSettings.shared` flags at call time.
DISPUTE D-004: Auditor states `unsafe_unretained`; superclass field is actually `__weak`.
  Evidence: Riot/Modules/MatrixKit/Models/Room/MXKRoomBubbleCellData.h:29 -- `__weak MXKRoomDataSource *roomDataSource;`

CONFIRM D-005: Beacon summary path depends on `self.mxSession.aggregations.beaconAggregations`.

DISPUTE P-001: Condition “target cell data must already exist” is overstated; no nil/existence check before mutation sends.
  Evidence: Riot/Modules/Room/CellData/RoomBubbleCellData.m:238 -- `RoomBubbleCellData *bubbleData = [roomDataSource cellDataOfEventWithEventId:...]` then :239-240 direct property sets

CONFIRM P-002: `refreshBubbleComponentsPosition` propagates computed `CGPoint` into each component’s `position`.
CONFIRM P-003: Accessibility label is derived from attachment type + message body when attachment exists.

ADD URL Preview Observer Coupling:
  Category: D
  Trigger:  `URLPreviewDidUpdateNotification` is observed in room screen.
  Effect:   Consumer relies on `roomId/eventId` userInfo keys to locate index path and reload cell/table.
  Evidence: Riot/Modules/Room/RoomViewController.m:1875 -- `addObserverForName:URLPreviewDidUpdateNotification ...`; :1880 -- `notification.userInfo[@"roomId"]`; :1886 -- `notification.userInfo[@"eventId"]`; :1903 -- `[self dataSource:self.roomDataSource didCellChange:updatedIndexPath];`

ADD DataSource Lifecycle Dispatch to CellData:
  Category: D
  Trigger:  Timeline processing in `MXKRoomDataSource`.
  Effect:   External engine invokes `addEvent`, falls back to `initWithEvent`, and later invokes `mergeWithBubbleCellData`, so RoomBubbleCellData behavior is orchestrator-dependent.
  Evidence: Riot/Modules/MatrixKit/Models/Room/MXKRoomDataSource.m:3252 -- `eventManaged = [bubbleData addEvent:...];`; :3259 -- `[[class alloc] initWithEvent:... andRoomDataSource:self]`; :2624 -- `[cellData1 mergeWithBubbleCellData:cellData2]`

ADD Render-Pull Dependency on Bubble Computations:
  Category: P
  Trigger:  Bubble cell layout/render cycle.
  Effect:   UI pull-reads attributed text and forces component-position preparation, propagating model state into rendered layout/timestamp placement.
  Evidence: Riot/Modules/Room/TimelineCells/Common/MXKRoomBubbleTableViewCell.m:408 -- `... ? bubbleData.attributedTextMessage : bubbleData.attributedTextMessageWithoutPositioningSpace`; :613 -- `[bubbleData prepareBubbleComponentsPosition];`; :641 -- `component.position.y`

META_ISSUE L-003: Scope -- marked `class`, but executable contract logic is method-local (`-keyVerificationDidUpdate`).
META_ISSUE S-001: Scope -- marked `class`, but lock contract is method-local (`-buildAttributedStringIfNeeded`).
META_ISSUE N-001: Seam_Type -- marked `none`, but this is notification coupling and fits `link`.

COVERAGE M: 11 contracts found -- OK
COVERAGE L: 11 contracts found -- OK
COVERAGE N: 1 contracts found -- OK
COVERAGE S: 5 contracts found -- OK
COVERAGE E: 1 contracts found -- OK
COVERAGE C: 0 contracts found -- SUSPECT_MISSING: async URL preview fetch has no explicit cancellation contract or residual-state cleanup path.
COVERAGE D: 5 contracts found -- OK
COVERAGE P: 3 contracts found -- OK

SUMMARY
CONFIRM: 23
DISPUTE: 12
ADD: 3
META_ISSUE: 3
CONFIRM_RATIO: 66%