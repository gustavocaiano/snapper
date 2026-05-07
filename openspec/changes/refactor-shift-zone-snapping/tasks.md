## 1. Test and Geometry Foundation

- [x] 1.1 Add an XCTest target to `project.yml` if the project still has no test target, and ensure `xcodegen generate` can regenerate the project.
- [x] 1.2 Add pure geometry types/helpers for resolving zones to connected displays using `screenDisplayID` first and `screenIndex` as fallback.
- [x] 1.3 Implement `ZoneGeometryMapper` for normalized zone rect to target window frame conversion, preserving current shortcut snapping semantics unless intentionally changed.
- [x] 1.4 Implement `ZoneHitTester` for global cursor point to hovered zone resolution across displays, including smallest-area overlap priority and stable tie-breaking.
- [x] 1.5 Add unit tests for zone hit-testing, display-ID fallback, overlapping zones, negative display origins, and target-frame/minimum-size conversion.

## 2. Window Capture and Snapping Refactor

- [x] 2.1 Refactor `WindowManager` so AX window lookup/capture and AX move/resize operations are separate from the existing `snapFocusedWindow(to:)` convenience method.
- [x] 2.2 Add a captured-window snap API that moves/resizes a supplied AX window to a `SnapperZone` using the shared geometry mapper.
- [x] 2.3 Add window capture support for the active drag session, preferring the AX window under the original mouse-down point and falling back to the focused window.
- [x] 2.4 Validate captured windows by accessibility availability, window role/subrole, movability/resizability, and exclusion of Snapper-owned overlay windows.
- [x] 2.5 Verify existing zone hotkeys and cycle snapping still call the focused-window path and behave as before.

## 3. Passive Snap Preview Overlay

- [x] 3.1 Create `SnapPreviewOverlayView` as a read-only SwiftUI renderer for zones on a display with inactive and hovered visual states.
- [x] 3.2 Create `ZoneSnapOverlayManager` that presents borderless transparent overlay windows per display with `ignoresMouseEvents = true` and without activating Snapper.
- [x] 3.3 Ensure overlays show mapped zones on all connected displays, exclude editor controls/gestures, and dismiss cleanly on cancel or snap commit.
- [x] 3.4 Add visual polish for semi-transparent zones, highlighted hovered zone, readable labels, Reduce Motion behavior, and overlapping-zone clarity.

## 4. Global Drag State Machine

- [x] 4.1 Add `GlobalDragEventMonitor` as a listen-only CGEvent tap adapter for left mouse down/drag/up and flags-changed events, returning all events unchanged.
- [x] 4.2 Handle CGEvent tap disable/timeout events by attempting re-enable and surfacing a throttled warning when monitoring cannot run.
- [x] 4.3 Implement `ShiftDragSnapController` with explicit idle, mouse-down, dragging, armed, snapping, and cancelled states.
- [x] 4.4 Arm the controller only after drag threshold, Shift held, zones available, accessibility available, and valid window captured.
- [x] 4.5 Update hovered zone from cursor movement using `ZoneHitTester`, throttling high-frequency updates before publishing overlay state.
- [x] 4.6 Commit snap on mouse-up over a hovered zone, cancel on mouse-up outside zones, cancel on Shift release, and cancel on display changes.
- [x] 4.7 Add controller unit tests with fake monitor, overlay, window capture, and snap executor dependencies.

## 5. App Integration and Validation

- [x] 5.1 Wire controller lifecycle into app startup/shutdown without moving global event-monitor logic into `AppState`.
- [x] 5.2 Connect controller inputs to current `AppState.config.zones`, `AppState.screens`, accessibility prompts, and screen-change cancellation.
- [ ] 5.3 Regenerate/build the project and run the new test target.
- [ ] 5.4 Manually validate single-display Shift-drag snap, Shift-before-drag, Shift-during-drag, Shift-release cancel, mouse-up outside zones, and existing hotkey/cycle snapping.
- [ ] 5.5 Manually validate multi-display behavior, overlapping zones, unavailable displays, non-resizable windows, full-screen/Space behavior, and event-tap permission failure handling.
