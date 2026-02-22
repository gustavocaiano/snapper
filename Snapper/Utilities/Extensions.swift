import AppKit
import CoreGraphics

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension CGRect {
    var clampedUnitRect: CGRect {
        var value = standardized
        value.origin.x = value.origin.x.clamped(to: 0 ... 1)
        value.origin.y = value.origin.y.clamped(to: 0 ... 1)
        value.size.width = value.size.width.clamped(to: 0 ... 1)
        value.size.height = value.size.height.clamped(to: 0 ... 1)

        if value.maxX > 1 {
            value.size.width = 1 - value.minX
        }
        if value.maxY > 1 {
            value.size.height = 1 - value.minY
        }

        return value
    }

    static func fromPoints(_ start: CGPoint, _ end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    func normalized(in container: CGRect) -> CGRect {
        guard container.width > 0, container.height > 0 else {
            return .zero
        }

        let x = (minX - container.minX) / container.width
        let y = (minY - container.minY) / container.height
        let width = self.width / container.width
        let height = self.height / container.height

        return CGRect(x: x, y: y, width: width, height: height).clampedUnitRect
    }

    func denormalized(in container: CGRect) -> CGRect {
        CGRect(
            x: container.minX + (origin.x * container.width),
            y: container.minY + (origin.y * container.height),
            width: width * container.width,
            height: height * container.height
        )
    }

    func constrained(to container: CGRect) -> CGRect {
        var result = self

        result.size.width = min(result.width, container.width)
        result.size.height = min(result.height, container.height)

        result.origin.x = min(max(result.minX, container.minX), container.maxX - result.width)
        result.origin.y = min(max(result.minY, container.minY), container.maxY - result.height)

        return result
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        let number = deviceDescription[key] as? NSNumber
        return CGDirectDisplayID(number?.uint32Value ?? 0)
    }
}
