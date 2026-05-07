## ADDED Requirements

### Requirement: Shift-drag zone preview activation
The system SHALL arm zone-preview snapping when the user is actively dragging a movable window and Shift is held before or during that drag.

#### Scenario: Shift pressed during an active window drag
- **WHEN** the user starts dragging a window and then presses Shift while continuing to hold the mouse button
- **THEN** the system displays the user's mapped snap zones as a transient preview overlay

#### Scenario: Drag starts while Shift is already held
- **WHEN** the user holds Shift and starts dragging a movable window
- **THEN** the system displays the user's mapped snap zones after the drag threshold is crossed

#### Scenario: Drag does not pass threshold
- **WHEN** the user clicks a window or makes a pointer movement below the drag threshold while Shift is held
- **THEN** the system MUST NOT display the zone preview overlay

### Requirement: Passive zone preview overlay
The system SHALL show mapped zones in passive read-only overlays that do not activate Snapper, intercept mouse events, or enter zone-editing mode.

#### Scenario: Preview overlay appears
- **WHEN** Shift-drag snapping is armed
- **THEN** all mapped zones for connected displays are shown with semi-transparent styling and without edit handles, inspector controls, or zone mutation gestures

#### Scenario: Underlying drag continues
- **WHEN** the preview overlay is visible during a window drag
- **THEN** the underlying application MUST continue receiving its normal drag events

#### Scenario: Existing editor remains separate
- **WHEN** the user is not in the on-screen zone editor
- **THEN** previewing zones MUST NOT set the app into draw mode, edit mode, or show the editor inspector

### Requirement: Hovered zone feedback
The system SHALL identify the zone under the cursor during an armed Shift-drag session and render that zone with a distinct active visual state.

#### Scenario: Cursor enters a mapped zone
- **WHEN** the cursor moves inside a mapped zone while the preview overlay is visible
- **THEN** that zone is marked hovered and rendered with stronger opacity and border emphasis than non-hovered zones

#### Scenario: Cursor leaves all zones
- **WHEN** the cursor moves outside every mapped zone while the preview overlay is visible
- **THEN** no zone is marked hovered and all zones return to their inactive preview style

#### Scenario: Cursor crosses displays
- **WHEN** the cursor moves from one connected display to another during an armed Shift-drag session
- **THEN** hovered-zone detection updates using the zones mapped to the display containing the cursor

### Requirement: Snap on mouse release over hovered zone
The system SHALL snap the captured dragged window to the hovered zone when the mouse button is released while Shift-drag snapping is armed.

#### Scenario: Release over zone commits snap
- **WHEN** the user releases the mouse button while a zone is hovered during an armed Shift-drag session
- **THEN** the preview overlay is dismissed and the captured window is moved and resized to the hovered zone's target frame

#### Scenario: Release outside zones cancels snap
- **WHEN** the user releases the mouse button while no zone is hovered during an armed Shift-drag session
- **THEN** the preview overlay is dismissed and the dragged window remains where the underlying application leaves it

### Requirement: Cancel on Shift release
The system SHALL cancel the active zone-preview snap session when Shift is released before the mouse button is released.

#### Scenario: Shift released before drop
- **WHEN** the user releases Shift while still dragging the window
- **THEN** the preview overlay is dismissed and no snap is committed for that drag

#### Scenario: Shift pressed again during same drag
- **WHEN** the user releases Shift to cancel and then presses Shift again while still dragging
- **THEN** the system MAY re-arm the preview only if it can still validate the dragged window and current drag state

### Requirement: Captured window targeting
The system SHALL snap the window captured for the active drag session rather than resolving the focused window at mouse-release time.

#### Scenario: Window captured on arm
- **WHEN** Shift-drag snapping becomes armed for a valid window drag
- **THEN** the system captures and stores the AX window associated with that drag session

#### Scenario: Focus changes during drag
- **WHEN** focus changes before the mouse button is released during an armed Shift-drag session
- **THEN** the system still snaps the originally captured window if a zone is hovered at release time

#### Scenario: No valid window can be captured
- **WHEN** the system cannot identify a movable AX window for the drag session
- **THEN** the preview overlay MUST NOT be shown and no snap MUST be committed

### Requirement: Deterministic zone hit-testing
The system SHALL map global cursor position to user zones deterministically across displays using display identity and normalized zone rectangles.

#### Scenario: Display ID matches a zone
- **WHEN** the cursor is on a display whose ID matches a zone's `screenDisplayID`
- **THEN** that zone is eligible for hover and drop hit-testing on that display

#### Scenario: Display ID unavailable for a zone
- **WHEN** a zone has no matching connected display ID but has a valid screen index fallback
- **THEN** the system uses the reconciled screen index as a fallback for hover and drop hit-testing

#### Scenario: Overlapping zones contain cursor
- **WHEN** multiple zones on the same display contain the cursor
- **THEN** the system selects the smallest containing zone as hovered, using stable zone order as a tie-breaker

### Requirement: Existing snapping behavior remains intact
The system SHALL preserve existing shortcut-based zone snapping and cycle snapping behavior.

#### Scenario: User presses a zone shortcut
- **WHEN** the user invokes an existing zone hotkey
- **THEN** Snapper snaps the currently focused window to that zone as it did before this change

#### Scenario: User invokes cycle snapping
- **WHEN** the user invokes the configured cycle shortcut
- **THEN** Snapper cycles through configured zones and snaps the currently focused window as it did before this change

### Requirement: Graceful failure handling
The system SHALL fail safely when permissions, displays, windows, or zones are unavailable during Shift-drag snapping.

#### Scenario: Accessibility permission unavailable
- **WHEN** the user attempts Shift-drag snapping without required Accessibility access
- **THEN** the system does not show a misleading snap target and provides an appropriate prompt or throttled warning using existing permission UX

#### Scenario: No zones configured
- **WHEN** the user drags a window with Shift held but no zones exist
- **THEN** the system does not show a preview overlay and does not alter the window

#### Scenario: Display configuration changes during drag
- **WHEN** connected display configuration changes during an armed Shift-drag session
- **THEN** the system cancels the session, dismisses overlays, and commits no snap
