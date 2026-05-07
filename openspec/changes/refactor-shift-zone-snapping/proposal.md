## Why

Snapper currently requires a zone hotkey or cycling shortcut to move the focused window, even though users already design visual zones on-screen. The app should support a direct, native-feeling pointer workflow: while dragging a window, hold Shift to reveal mapped zones, hover the desired target, and release to lock the window into that zone.

## What Changes

- Add a Shift-drag snapping interaction that passively detects a window drag, shows all mapped zones as transient semi-transparent overlays while Shift is held, highlights the zone under the cursor, and snaps the dragged/focused window when the mouse is released over a zone.
- Introduce a dedicated snap-preview overlay path separate from the zone editor so mapped zones can be displayed without entering edit mode or intercepting normal app/window drags.
- Refactor window snapping so the AX move/resize operation can target either the currently focused window or a captured window reference from the active drag session.
- Add deterministic zone hit-testing across displays using the stored normalized zone rects and current screen descriptors.
- Keep existing hotkey snapping, cycle snapping, zone editing, persistence, and launch-at-login behavior intact.
- Avoid hijacking non-window drags: Shift-drag overlays should observe events passively and commit only when a valid window and hovered zone are available.

## Capabilities

### New Capabilities
- `shift-drag-zone-snapping`: Users can reveal mapped zones while dragging a window with Shift, hover a zone, and release to snap the window into that zone.

### Modified Capabilities
- None.

## Impact

- `Snapper/App/AppState.swift`: Coordinate drag-session state, accessibility validation, hovered zone state, and snap commit/cancel flow.
- `Snapper/Services/WindowManager.swift`: Extract reusable AX window capture and snap-to-zone/frame operations.
- `Snapper/Services/OnScreenZoneEditorManager.swift`: Keep editor lifecycle isolated; share only low-level overlay-window creation if refactored.
- New service area, likely `Snapper/Services/ShiftDragSnapController.swift` or similar: Monitor global mouse/modifier events, track active drag sessions, update cursor/hover state, and commit snaps.
- New overlay presentation area, likely `Snapper/Services/SnapPreviewOverlayManager.swift` plus `Snapper/Views/SnapPreview/SnapPreviewOverlayView.swift`: Present non-editing zone previews on all displays.
- `Snapper/Utilities/Extensions.swift` or a new geometry helper: Centralize screen-space zone rect conversion and overlap/priority hit-testing.
- `project.yml`: Include any new Swift source files automatically through the existing `Snapper` source path; no new external dependencies expected.
