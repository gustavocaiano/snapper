import SwiftUI

struct OnScreenZoneEditorView: View {
    @EnvironmentObject private var appState: AppState

    let screenIndex: Int
    let screenName: String
    let showsInspector: Bool

    @State private var draftZone: DraftZone?
    @State private var isInspectorCollapsed = true

    var body: some View {
        GeometryReader { proxy in
            let canvasRect = CGRect(origin: .zero, size: proxy.size)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.black.opacity(0.16))
                    .overlay(Rectangle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                    .contentShape(Rectangle())
                    .gesture(createZoneGesture(in: canvasRect))

                ForEach(Array(appState.config.zones.indices), id: \.self) { index in
                    if appState.config.zones[index].screenIndex == screenIndex {
                        ZoneOverlayView(
                            zone: $appState.config.zones[index],
                            screenRect: canvasRect,
                            isSelected: appState.selectedZoneID == appState.config.zones[index].id,
                            onSelect: {
                                appState.selectedZoneID = appState.config.zones[index].id
                            },
                            crossScreenMoveResolver: { movedRect in
                                crossScreenMoveTarget(for: movedRect)
                            }
                        )
                        .allowsHitTesting(!appState.isZoneCreateMode)
                    }
                }

                if let draftRect = draftRect(in: canvasRect) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        )
                        .frame(width: draftRect.width, height: draftRect.height)
                        .position(x: draftRect.midX, y: draftRect.midY)
                }

                screenBadge
                    .padding(16)

            }
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                if showsInspector {
                    if isInspectorCollapsed {
                        collapsedInspectorButton
                            .padding(16)
                    } else {
                        inspector(maxHeight: proxy.size.height - 32)
                            .padding(16)
                    }
                }
            }
            .onExitCommand {
                appState.closeOnScreenEditor()
            }
        }
    }

    private var screenBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(screenName)
                .font(.headline)
                .foregroundStyle(.white)
            Text(appState.isZoneCreateMode ? "Draw mode: drag anywhere to create zones." : "Edit mode: drag zones to move or resize.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func inspector(maxHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    SnapperMarkView(size: 22, style: .brand)
                        .accessibilityHidden(true)
                    Text("Snapper Zones")
                        .font(.headline)
                }

                Spacer()

                Button {
                    isInspectorCollapsed = true
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    appState.closeOnScreenEditor()
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Edit zones directly on your real screens. Drag on any display to create a new region.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Mode", selection: Binding(
                get: { appState.isZoneCreateMode },
                set: { appState.isZoneCreateMode = $0 }
            )) {
                Text("Edit").tag(false)
                Text("Draw").tag(true)
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    appState.addCenteredZone(on: screenIndex)
                } label: {
                    Label("Add Centered Zone", systemImage: "plus")
                }

                Button("Draw New Zone") {
                    appState.isZoneCreateMode = true
                }

                Button("Refresh Displays") {
                    appState.reloadScreens()
                }
            }

            if appState.config.zones.isEmpty {
                Text("No zones yet. Drag on any display to create one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach($appState.config.zones) { $zone in
                            ZoneDetailView(
                                zone: $zone,
                                screens: appState.screens,
                                warningMessage: appState.registrationWarning(for: zone.id),
                                isSelected: appState.selectedZoneID == zone.id,
                                onSelect: {
                                    appState.selectedZoneID = zone.id
                                },
                                onDelete: {
                                    appState.removeZone(id: zone.id)
                                },
                                onShortcutChange: { hotKey in
                                    appState.assignShortcut(hotKey, to: zone.id)
                                }
                            )
                        }
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: maxHeight)
            }
        }
        .padding(14)
        .frame(width: 380)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var collapsedInspectorButton: some View {
        Button {
            isInspectorCollapsed = false
        } label: {
            Label("Panel", systemImage: "sidebar.right")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    private func createZoneGesture(in canvasRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if draftZone == nil {
                    let startedInExistingZone = pointIsInsideExistingZone(value.startLocation, in: canvasRect)

                    guard appState.isZoneCreateMode || !startedInExistingZone else {
                        return
                    }

                    draftZone = DraftZone(start: value.startLocation, current: value.location)
                } else {
                    draftZone?.current = value.location
                }
            }
            .onEnded { _ in
                defer {
                    draftZone = nil
                }

                guard let draftZone else {
                    return
                }

                let rawRect = CGRect.fromPoints(draftZone.start, draftZone.current)
                let clampedRect = rawRect.intersection(canvasRect)

                guard clampedRect.width >= 18, clampedRect.height >= 18 else {
                    return
                }

                let normalized = clampedRect.normalized(in: canvasRect)
                appState.addZone(on: screenIndex, normalizedRect: normalized)
                appState.isZoneCreateMode = true
            }
    }

    private func crossScreenMoveTarget(for movedRect: CGRect) -> CrossScreenMoveTarget? {
        guard
            let sourceScreen = appState.screens.first(where: { $0.index == screenIndex })
        else {
            return nil
        }

        let globalRect = movedRect.offsetBy(dx: sourceScreen.frame.minX, dy: sourceScreen.frame.minY)
        let center = CGPoint(x: globalRect.midX, y: globalRect.midY)

        guard
            let targetScreen = appState.screens.first(where: {
                $0.index != sourceScreen.index && ($0.frame.contains(center) || $0.frame.intersects(globalRect))
            })
        else {
            return nil
        }

        let targetCanvas = CGRect(origin: .zero, size: targetScreen.frame.size)
        let targetRect = globalRect
            .offsetBy(dx: -targetScreen.frame.minX, dy: -targetScreen.frame.minY)
            .constrained(to: targetCanvas)

        return CrossScreenMoveTarget(
            screenIndex: targetScreen.index,
            screenDisplayID: targetScreen.displayID,
            normalizedRect: targetRect.normalized(in: targetCanvas)
        )
    }

    private func draftRect(in canvasRect: CGRect) -> CGRect? {
        guard let draftZone else {
            return nil
        }

        return CGRect.fromPoints(draftZone.start, draftZone.current).intersection(canvasRect)
    }

    private func pointIsInsideExistingZone(_ point: CGPoint, in canvasRect: CGRect) -> Bool {
        for zone in appState.config.zones where zone.screenIndex == screenIndex {
            let rect = zone.rect.denormalized(in: canvasRect)
            if rect.contains(point) {
                return true
            }
        }

        return false
    }
}

private struct DraftZone {
    let start: CGPoint
    var current: CGPoint
}
