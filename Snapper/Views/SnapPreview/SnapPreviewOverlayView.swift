import SwiftUI

struct SnapPreviewOverlayView: View {
    let screen: ScreenDescriptor

    @ObservedObject var state: SnapPreviewOverlayState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let canvasRect = CGRect(origin: .zero, size: proxy.size)

            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.04)
                    .allowsHitTesting(false)

                ForEach(zonesForCurrentScreen) { zone in
                    let rect = ZoneGeometryMapper.overlayRect(for: zone, in: canvasRect)
                    SnapPreviewZoneView(
                        zone: zone,
                        rect: rect,
                        isHovered: state.hoveredZoneID == zone.id,
                        reduceMotion: reduceMotion
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    private var zonesForCurrentScreen: [SnapperZone] {
        state.zones.filter { zone in
            ZoneGeometryMapper.screen(for: zone, in: state.screens)?.displayID == screen.displayID
        }
    }
}

private struct SnapPreviewZoneView: View {
    let zone: SnapperZone
    let rect: CGRect
    let isHovered: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(isHovered ? 0.46 : 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isHovered ? Color.accentColor : Color.white.opacity(0.72),
                            lineWidth: isHovered ? 3 : 1.5
                        )
                )
                .shadow(color: Color.accentColor.opacity(isHovered ? 0.38 : 0), radius: 18, x: 0, y: 0)

            if rect.width >= 88, rect.height >= 34 {
                Text(zone.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundStyle(.white)
                    .background(.black.opacity(isHovered ? 0.42 : 0.30), in: Capsule())
                    .padding(8)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .scaleEffect(isHovered && !reduceMotion ? 1.012 : 1)
        .animation(reduceMotion ? .easeOut(duration: 0.08) : .spring(response: 0.18, dampingFraction: 0.78), value: isHovered)
    }
}
