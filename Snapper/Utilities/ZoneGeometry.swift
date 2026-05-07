import CoreGraphics
import Foundation

struct ResolvedZone {
    let zone: SnapperZone
    let screen: ScreenDescriptor
    let zoneIndex: Int
}

enum ZoneGeometryMapper {
    static let minimumWindowSize = CGSize(width: 60, height: 60)

    static func screen(
        for zone: SnapperZone,
        in screens: [ScreenDescriptor],
        allowScreenIndexFallbackForMissingDisplayID: Bool = true
    ) -> ScreenDescriptor? {
        if let displayID = zone.screenDisplayID {
            if let matchedScreen = screens.first(where: { $0.displayID == displayID }) {
                return matchedScreen
            }

            guard allowScreenIndexFallbackForMissingDisplayID else {
                return nil
            }
        }

        return screens.first(where: { $0.index == zone.screenIndex })
    }

    static func resolvedZones(for zones: [SnapperZone], in screens: [ScreenDescriptor]) -> [ResolvedZone] {
        zones.enumerated().compactMap { index, zone in
            guard let screen = screen(for: zone, in: screens) else {
                return nil
            }

            return ResolvedZone(zone: zone, screen: screen, zoneIndex: index)
        }
    }

    static func overlayRect(for zone: SnapperZone, in localScreenRect: CGRect) -> CGRect {
        zone.rect.clampedUnitRect.denormalized(in: localScreenRect)
    }

    static func globalHitTestRect(for zone: SnapperZone, on screen: ScreenDescriptor) -> CGRect {
        let localRect = overlayRect(
            for: zone,
            in: CGRect(origin: .zero, size: screen.frame.size)
        )

        return CGRect(
            x: screen.frame.minX + localRect.minX,
            y: screen.frame.maxY - localRect.maxY,
            width: localRect.width,
            height: localRect.height
        ).integral
    }

    static func targetWindowFrame(
        for zone: SnapperZone,
        in screen: ScreenDescriptor,
        minimumSize: CGSize = minimumWindowSize
    ) -> CGRect {
        targetWindowFrame(for: zone.rect, in: screen.frame, minimumSize: minimumSize)
    }

    static func targetWindowFrame(
        for normalizedRect: CGRect,
        in screenFrame: CGRect,
        minimumSize: CGSize = minimumWindowSize
    ) -> CGRect {
        let rect = normalizedRect.clampedUnitRect
        var x = screenFrame.minX + (rect.minX * screenFrame.width)
        let targetMinYNormalized = 1 - rect.minY - rect.height
        var y = screenFrame.minY + (targetMinYNormalized * screenFrame.height)
        let width = min(screenFrame.width, max(minimumSize.width, screenFrame.width * rect.width))
        let height = min(screenFrame.height, max(minimumSize.height, screenFrame.height * rect.height))

        x = min(max(x, screenFrame.minX), screenFrame.maxX - width)
        y = min(max(y, screenFrame.minY), screenFrame.maxY - height)

        return CGRect(x: x, y: y, width: width, height: height).integral
    }

    static func accessibilityTopLeftPosition(
        forAppKitFrame frame: CGRect,
        mainScreenFrame: CGRect
    ) -> CGPoint {
        CGPoint(x: frame.minX, y: mainScreenFrame.maxY - frame.maxY)
    }

    static func localPoint(forGlobalPoint point: CGPoint, in screen: ScreenDescriptor) -> CGPoint? {
        guard screen.frame.contains(point) else {
            return nil
        }

        return CGPoint(
            x: point.x - screen.frame.minX,
            y: screen.frame.maxY - point.y
        )
    }
}

struct ZoneHitTester {
    func hoveredZone(
        at globalPoint: CGPoint,
        zones: [SnapperZone],
        screens: [ScreenDescriptor]
    ) -> SnapperZone? {
        let matches = ZoneGeometryMapper
            .resolvedZones(for: zones, in: screens)
            .filter { resolvedZone in
                ZoneGeometryMapper
                    .globalHitTestRect(for: resolvedZone.zone, on: resolvedZone.screen)
                    .contains(globalPoint)
            }

        return matches
            .sorted { lhs, rhs in
                let lhsArea = ZoneGeometryMapper.globalHitTestRect(for: lhs.zone, on: lhs.screen).area
                let rhsArea = ZoneGeometryMapper.globalHitTestRect(for: rhs.zone, on: rhs.screen).area

                if lhsArea == rhsArea {
                    return lhs.zoneIndex > rhs.zoneIndex
                }

                return lhsArea < rhsArea
            }
            .first?
            .zone
    }
}

private extension CGRect {
    var area: CGFloat {
        width * height
    }
}
