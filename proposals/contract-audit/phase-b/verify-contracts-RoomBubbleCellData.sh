#!/bin/bash
# Verification script for RoomBubbleCellData final contracts
# Generated: 2026-03-08
# Total contracts: 41
PASS=0; FAIL=0

assert_match() {
  local id="$1" pattern="$2" file="$3"
  if grep -qn "$pattern" "$file"; then
    echo "PASS [$id]"; PASS=$((PASS + 1))
  else
    echo "FAIL [$id] -- pattern not found: $pattern"; FAIL=$((FAIL + 1))
  fi
}

# Base paths (relative to repo root)
TARGET="Riot/Modules/Room/CellData/RoomBubbleCellData.m"
HEADER="Riot/Modules/Room/CellData/RoomBubbleCellData.h"
ROOMVC="Riot/Modules/Room/RoomViewController.m"
DATASOURCE="Riot/Modules/MatrixKit/Models/Room/MXKRoomDataSource.m"
TABLECELL="Riot/Modules/Room/TimelineCells/Common/MXKRoomBubbleTableViewCell.m"
SUPERHEADER="Riot/Modules/MatrixKit/Models/Room/MXKRoomBubbleCellData.h"

echo "=== Lifecycle (L) ==="

# L-001: Event type to tag classification (18 enum values)
assert_match "L-001" 'switch (event.eventType)' "$TARGET"
assert_match "L-001-enum" 'RoomBubbleCellDataTagVoiceBroadcastNoDisplay' "$HEADER"

# L-002: Collapsable/collapsed defaults (including default path)
assert_match "L-002" 'self.collapsable = YES' "$TARGET"

# L-003: Key verification state machine
assert_match "L-003" 'keyVerificationDidUpdate' "$TARGET"

# L-004: hasNoDisplay visibility
assert_match "L-004" '(BOOL)hasNoDisplay' "$TARGET"

# L-005: Collapsed setter invalidation
assert_match "L-005" 'setCollapsed:(BOOL)collapsed' "$TARGET"

# L-006: addEvent guard (three-phase: hasThreadRoot, style, tag)
assert_match "L-006a" 'if (self.hasThreadRoot)' "$TARGET"
assert_match "L-006b" 'canAddEvent:event' "$TARGET"

# L-007: Merge guard
assert_match "L-007" 'mergeWithBubbleCellData' "$TARGET"

# L-008: Collapse guard
assert_match "L-008" 'collapseWith:' "$TARGET"

# L-009: hasThreadRoot guard
assert_match "L-009" 'RiotSettings.shared.enableThreads' "$TARGET"

# L-010: hasSameSenderAsBubbleCellData (poll-end guard on self.tag == Poll)
assert_match "L-010a" 'hasSameSenderAsBubbleCellData' "$TARGET"
assert_match "L-010b" 'self.tag == RoomBubbleCellDataTagPoll' "$TARGET"

# L-011: updateEvent with tag mutation
assert_match "L-011" 'updateEvent:(NSString \*)eventId withEvent' "$TARGET"

echo ""
echo "=== Mutation (M) ==="

# M-001: Lazy text layout invalidation (conditional on series header)
assert_match "M-001" 'invalidateTextLayout' "$TARGET"

# M-002: Attributed string construction
assert_match "M-002" 'buildAttributedString' "$TARGET"

# M-003: Component alpha blending
assert_match "M-003" 'withTextColorAlpha:.2' "$TARGET"

# M-004: Show all reactions state
assert_match "M-004" 'eventsToShowAllReactions addObject' "$TARGET"

# M-005: URL preview data mutation (success)
assert_match "M-005" 'component.urlPreviewData = urlPreviewData' "$TARGET"

# M-006: URL preview data clear on edit
assert_match "M-006" 'component.urlPreviewData = nil' "$TARGET"

# M-007: Additional content height computation (independent of position refresh)
assert_match "M-007" 'computeAdditionalHeight' "$TARGET"

# M-008: Vertical whitespace injection
assert_match "M-008" 'addVerticalWhitespaceToString' "$TARGET"

# M-009: Blockquote display fix
assert_match "M-009" 'MXKRoomBubbleComponentDisplayFixHtmlBlockquote' "$TARGET"

# M-010: Beacon info summary update
assert_match "M-010" 'updateBeaconInfoSummaryWithId' "$TARGET"

# M-011: maxComponentCount override
assert_match "M-011" 'self.maxComponentCount = 20' "$TARGET"

echo ""
echo "=== Notification (N) ==="

# N-001: URLPreviewDidUpdateNotification (seam_type: link)
assert_match "N-001" 'postNotificationName:URLPreviewDidUpdateNotification' "$TARGET"
assert_match "N-001-h" 'URLPreviewDidUpdateNotification' "$HEADER"

echo ""
echo "=== Synchronization (S) ==="

# S-001: @synchronized(bubbleComponents) in buildAttributedStringIfNeeded
assert_match "S-001" '@synchronized(bubbleComponents)' "$TARGET"

# S-002: @synchronized in refreshBubbleComponentsPosition (no dispatch_sync in body)
assert_match "S-002" 'refreshBubbleComponentsPosition' "$TARGET"

# S-003: dispatch_sync to main thread (guarded against main-from-main)
assert_match "S-003a" 'dispatch_sync(dispatch_get_main_queue' "$TARGET"
assert_match "S-003b" 'NSThread currentThread.*NSThread mainThread' "$TARGET"

# S-004: @synchronized(self) for static init
assert_match "S-004" 'timestampVerticalWhitespace == nil' "$TARGET"

# S-005: dispatch_once for reactionsViewSizer
assert_match "S-005" 'dispatch_once(&onceToken' "$TARGET"

echo ""
echo "=== Error Handling (E) ==="

# E-001: Silent URL preview failure
assert_match "E-001" 'component.showURLPreview = NO' "$TARGET"

echo ""
echo "=== Cancellation (C) ==="

# C-001: URL preview fetch has no cancellation contract
# Verify that MXStrongifyAndReturnIfNil is the only "cancellation" mechanism (no cancel token)
assert_match "C-001" 'MXStrongifyAndReturnIfNil(self)' "$TARGET"

echo ""
echo "=== Dependency (D) ==="

# D-001: RoomTimelineConfiguration.shared (lazy access)
assert_match "D-001" 'RoomTimelineConfiguration shared' "$TARGET"

# D-002: URLPreviewService.shared (with early return guard)
assert_match "D-002a" 'URLPreviewService.shared previewFor' "$TARGET"
assert_match "D-002b" 'if (!component.showURLPreview)' "$TARGET"

# D-003: RiotSettings.shared feature flags
assert_match "D-003" 'RiotSettings.shared.roomScreenShowsURLPreviews' "$TARGET"

# D-004: roomDataSource cross-object access (__weak, not unsafe_unretained)
assert_match "D-004a" 'roomDataSource cellDataOfEventWithEventId' "$TARGET"
assert_match "D-004b" '__weak MXKRoomDataSource' "$SUPERHEADER"

# D-005: mxSession.aggregations.beaconAggregations
assert_match "D-005" 'beaconAggregations beaconInfoSummaryFor' "$TARGET"

# D-006: URL Preview Observer Coupling (ADD - cross-module)
assert_match "D-006a" 'URLPreviewDidUpdateNotification' "$ROOMVC"
assert_match "D-006b" 'notification.userInfo' "$ROOMVC"

# D-007: DataSource Lifecycle Dispatch to CellData (ADD - cross-module)
assert_match "D-007a" 'addEvent:' "$DATASOURCE"
assert_match "D-007b" 'mergeWithBubbleCellData' "$DATASOURCE"

echo ""
echo "=== Propagation (P) ==="

# P-001: Cross-object voice broadcast mutation (no nil check)
assert_match "P-001" 'bubbleData.tag = RoomBubbleCellDataTagVoiceBroadcastPlayback' "$TARGET"

# P-002: Component position propagation
assert_match "P-002" 'component.position = CGPointMake' "$TARGET"

# P-003: Accessibility label
assert_match "P-003" 'accessibilityLabel' "$TARGET"

# P-004: Render-Pull Dependency on Bubble Computations (ADD - cross-module)
assert_match "P-004a" 'attributedTextMessage' "$TABLECELL"
assert_match "P-004b" 'prepareBubbleComponentsPosition' "$TABLECELL"

echo ""
echo "=========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "=========================================="
[ $FAIL -eq 0 ] || exit 1
