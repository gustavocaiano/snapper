import SwiftUI

struct CrossScreenMoveTarget {
    let screenIndex: Int
    let screenDisplayID: UInt32
    let normalizedRect: CGRect
}

struct ZoneOverlayView: View {
    @Binding var zone: SnapperZone

    let screenRect: CGRect
    let isSelected: Bool
    let onSelect: () -> Void
    let crossScreenMoveResolver: ((CGRect) -> CrossScreenMoveTarget?)?

    @State private var moveStartRect: CGRect?
    @State private var resizeStartRect: CGRect?

    private let minimumSize: CGFloat = 24

    var body: some View {
        let rect = zone.rect.denormalized(in: screenRect)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(isSelected ? 0.33 : 0.22))

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.8), lineWidth: isSelected ? 2 : 1)

            Text(zone.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(6)
                .foregroundStyle(.white)

            if isSelected {
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
                    .position(x: rect.width - 8, y: rect.height - 8)
                    .gesture(resizeGesture(startRect: rect))
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .gesture(moveGesture(startRect: rect))
    }

    private func moveGesture(startRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                onSelect()

                if moveStartRect == nil {
                    moveStartRect = startRect
                }

                guard let moveStartRect else {
                    return
                }

                let moved = moveStartRect.offsetBy(dx: value.translation.width, dy: value.translation.height)

                if let target = crossScreenMoveResolver?(moved) {
                    zone.screenIndex = target.screenIndex
                    zone.screenDisplayID = target.screenDisplayID
                    zone.rect = target.normalizedRect.clampedUnitRect
                    self.moveStartRect = nil
                    return
                }

                zone.rect = moved.constrained(to: screenRect).normalized(in: screenRect)
            }
            .onEnded { _ in
                moveStartRect = nil
            }
    }

    private func resizeGesture(startRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                onSelect()

                if resizeStartRect == nil {
                    resizeStartRect = startRect
                }

                guard var rect = resizeStartRect else {
                    return
                }

                rect.size.width = (rect.width + value.translation.width)
                    .clamped(to: minimumSize ... max(minimumSize, screenRect.maxX - rect.minX))
                rect.size.height = (rect.height + value.translation.height)
                    .clamped(to: minimumSize ... max(minimumSize, screenRect.maxY - rect.minY))

                zone.rect = rect.constrained(to: screenRect).normalized(in: screenRect)
            }
            .onEnded { _ in
                resizeStartRect = nil
            }
    }
}
