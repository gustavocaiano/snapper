## Context

Snapper is a macOS 13+ menu bar app built with SwiftUI/AppKit. Users create zones in the on-screen editor, zones are persisted as normalized `SnapperZone.rect` values, and existing snapping is triggered through Carbon hotkeys that call `AppState.snap(zoneID:)` and `WindowManager.snapFocusedWindow(to:)`.

The requested interaction is global and pointer-driven: while the user is dragging a regular macOS window, pressing Shift should reveal the user's mapped zones with opacity, highlight the zone under the cursor, and snapping should happen when the mouse button is released over a zone. This differs from the current editor overlay because it must be passive, non-editing, non-activating, and safe while another app owns the drag.

Current constraints:
- The on-screen editor windows are interactive (`ignoresMouseEvents = false`) and activate Snapper; they should not be reused directly for snap preview.
- `WindowManager` captures the focused window at snap time; Shift-drag snapping needs a stable captured AX window reference for the drag target.
- There are no tests today; the refactor should isolate pure geometry/state logic so it can be tested independently from AppKit, CGEvent, and AX adapters.
- Existing hotkey/cycle snapping, zone editing, config persistence, and launch-at-login flows must continue to work.

## Goals / Non-Goals

**Goals:**
- Add a passive Shift-drag snapping flow: drag window, hold Shift, see mapped zones, hover a zone, release mouse, snap into that zone.
- Show read-only zone preview overlays on all relevant displays without entering edit mode or stealing mouse/focus from the dragged app.
- Capture the intended dragged window once and snap that captured window, not an arbitrary focused window at release time.
- Centralize zone hit-testing and target-frame conversion so multi-display behavior is deterministic and testable.
- Preserve existing hotkey-based snapping behavior through the public `snapFocusedWindow(to:)` path.
- Keep the feature dependency-free by using AppKit, CoreGraphics, ApplicationServices, and existing Accessibility permission infrastructure.

**Non-Goals:**
- Redesign the zone editor or change how users create, move, resize, name, or persist zones.
- Replace global hotkeys or cycle snapping.
- Add grid templates, auto-layout suggestions, keyboard-only drag snapping, or animated OS-level window dragging.
- Guarantee snapping for apps/windows that do not expose movable/resizable AX windows.
- Introduce external libraries or a new persistence format.

## Decisions

### 1. Build a separate passive snap-preview pipeline

Create a new flow instead of extending `OnScreenZoneEditorManager`/`OnScreenZoneEditorView`.

Recommended components:
- `ShiftDragSnapController`: owns the state machine and coordinates monitor, overlay, hit-testing, and snap commit.
- `GlobalDragEventMonitor`: thin adapter around global mouse/modifier events.
- `ZoneSnapOverlayManager`: owns passive, read-only overlay windows per display.
- `SnapPreviewOverlayView`: SwiftUI read-only renderer for zone rectangles and hover state.
- `ZoneHitTester` / `ZoneGeometryMapper`: pure geometry helpers for pointer-to-zone and zone-to-target-frame conversion.
- `WindowManager` extensions/refactor: expose captured-window snapping while preserving focused-window snapping.

Rationale: the editor manager is deliberately interactive and app-activating. The Shift-drag feature must never intercept the drag or mutate zones, so separating the lifecycle prevents focus bugs and keeps the editor simpler.

Alternative considered: reuse `ZoneOverlayView` and editor windows. Rejected because `ZoneOverlayView` mutates zones via bindings and gestures, and editor windows currently accept mouse events and activate Snapper.

### 2. Use a listen-only CGEvent tap as the primary event source

`GlobalDragEventMonitor` should observe `.leftMouseDown`, `.leftMouseDragged`, `.leftMouseUp`, and `.flagsChanged`. It should emit normalized events to the controller and dispatch UI/state mutations onto the main actor.

Rationale: this feature must track drag/modifier sequencing while another app is frontmost. A listen-only CGEvent tap gives more precise ordering than AppKit local monitors and avoids polling-only mouse-up races.

Operational details:
- The event tap must be passive and must return events unchanged.
- Re-enable the tap if CoreGraphics reports timeout/user-input disable events.
- Do not perform AX work or SwiftUI mutations inside the event-tap callback.
- Throttle high-frequency hover updates before publishing overlay state.

Alternative considered: `NSEvent.addGlobalMonitorForEvents`. It is simpler but less reliable for precise drag state and modifier transitions across apps.

Alternative considered: polling only. Rejected because mouse-up commit timing is central to the feature.

### 3. Capture the target window before commit

Refactor `WindowManager` so snapping can operate on a captured AX window reference:
- Keep `snapFocusedWindow(to:)` for existing hotkeys.
- Add lower-level operations such as `focusedWindow()`, `window(at:)` or equivalent capture service, and `snapWindow(_:to:)`.
- Capture when drag threshold is crossed and Shift arms the feature, preferring the window under the original mouse-down point and falling back to the focused window.
- Store that AX element in the controller until mouse-up/cancel.

Rationale: if Snapper waits until mouse-up to ask for the focused window, it may snap the wrong window after focus changes or overlay lifecycle changes. Capturing once makes the commit deterministic.

Validation should exclude Snapper overlay windows, non-window roles/subroles, minimized/full-screen/system UI windows, and unavailable AX elements. If validation fails, cancel quietly or show a throttled accessibility/window warning.

### 4. Use a small explicit state machine

`ShiftDragSnapController` should model the interaction explicitly:
- `idle`
- `mouseDown(startPoint)`
- `dragging(startPoint, latestPoint)`
- `armed(capturedWindow, hoveredZoneID?)`
- `snapping(capturedWindow, zone)`
- `cancelled`

Rules:
- Mouse down starts observation only.
- A drag threshold prevents accidental overlay flashes.
- Shift held during an active drag arms the feature if zones and accessibility are available.
- Shift release before mouse-up cancels and dismisses overlays.
- Mouse-up over a hovered zone commits; mouse-up outside a zone cancels.
- Screen changes, app termination, missing permissions, missing zones, or invalid windows cancel the session.

Rationale: an explicit state machine makes edge cases testable and prevents state being scattered across `AppState`.

### 5. Render passive overlays on all displays

`ZoneSnapOverlayManager` should create borderless transparent `NSWindow`s for current screens using settings similar to the editor overlays, but with these differences:
- `ignoresMouseEvents = true`
- no `NSApp.activate(ignoringOtherApps:)`
- no editor controls or gestures
- visible only while the controller is armed
- dismissed before or immediately after snap commit to avoid visual artifacts

Visual behavior:
- Inactive zones: semi-transparent fill around 15-22% opacity, thin border, zone name if space allows.
- Hovered zone: stronger fill around 40-50%, accent border/glow, slightly elevated visual treatment.
- Respect Reduce Motion by replacing spring/scale effects with fast opacity transitions.
- If zones overlap, choose the smallest area containing the cursor, falling back to most recently created zone order if needed.

### 6. Centralize coordinate conversion and zone hit-testing

Add pure helpers that accept `SnapperZone`, `ScreenDescriptor`, and points/rects, then return deterministic results.

Design invariants:
- `screenDisplayID` is the primary display match; `screenIndex` is fallback for legacy/reconciled zones.
- Hit-testing uses the cursor point, not the dragged window bounds.
- All displays should be considered so the user can drag from one monitor to another and release into zones on any connected display.
- Use the same target-frame semantics as current shortcut snapping unless explicitly changed during implementation. The existing `WindowManager` currently denormalizes against `NSScreen.frame`; the refactor should preserve compatibility or document a deliberate move to `visibleFrame`.

The helpers must handle negative display origins, displays above/below the primary display, Retina scaling, overlapping zones, unavailable displays, and minimum window size constraints.

### 7. Add tests around pure logic first

Introduce tests for pure Swift pieces before or during implementation:
- `ZoneHitTester`: zone under point, no match outside zones, multi-display selection, overlap priority, display-ID preference.
- `ZoneGeometryMapper`: normalized zone to target frame, y-axis conversion, negative-origin displays, minimum size behavior.
- `ShiftDragSnapController` with protocol-backed fakes: no Shift no overlay, Shift during drag arms overlay, Shift release cancels, mouse-up over zone snaps, mouse-up outside zone cancels.

Thin adapters around CGEvent and AX can remain integration-tested manually because they depend on macOS permissions and external app windows.

## Risks / Trade-offs

- **CGEvent tap permissions or disablement** → Reuse Accessibility trust checks where applicable, surface one throttled warning when monitoring cannot start, and re-enable taps after timeout/user-input disable events.
- **AX window capture ambiguity** → Capture from the original mouse-down point when possible, fall back to focused window, validate roles/subroles, and never snap if the captured target is uncertain.
- **Mouse-up race with the dragged app** → Dismiss overlay immediately, then dispatch snap on the next main runloop tick if direct snap conflicts with the OS finishing the drag.
- **Coordinate bugs on complex display layouts** → Centralize mapping logic and cover negative origins, vertical display arrangements, display-ID matching, and overlap priority in tests.
- **Overlay focus or event interception** → Use a separate passive overlay manager with `ignoresMouseEvents = true` and no app activation.
- **Performance during high-frequency drag events** → Capture AX once, perform only cheap geometry hit-tests per move, and throttle published hover updates.
- **Apps with AX limitations** → Preserve graceful failure alerts from existing snapping where useful, but avoid repeated alerts during drag sessions.

## Migration Plan

1. Add pure geometry/hit-testing helpers and unit tests without changing runtime behavior.
2. Refactor `WindowManager` to support captured-window snapping while keeping `snapFocusedWindow(to:)` compatible for hotkeys.
3. Add passive snap-preview overlay manager and view, initially driven by controlled/debug state.
4. Add the global event monitor and `ShiftDragSnapController` state machine.
5. Wire controller startup/shutdown from app launch lifecycle and cancel on screen changes.
6. Validate manually on one display, multiple displays, overlapping zones, Shift release cancel, mouse-up outside zone, and apps with non-resizable windows.

Rollback strategy: because this adds a separate runtime path, it can be disabled by not starting `ShiftDragSnapController`; existing hotkey snapping and editor flows should remain usable.

## Open Questions

- Should target frames continue to use full `NSScreen.frame` exactly like current shortcut snapping, or should both old and new snapping move to `visibleFrame` to avoid menu bar/Dock overlap?
- Should the Shift-drag feature be always enabled, or should a user-facing preference be added after implementation proves stable?
- How aggressive should the app be in warning about event-monitor failures versus quietly keeping existing hotkey behavior available?
