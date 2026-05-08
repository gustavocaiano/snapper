import SwiftUI

struct SnapperMarkView: View {
    enum MarkStyle {
        case menuBar
        case brand
    }

    let size: CGFloat
    let style: MarkStyle

    init(size: CGFloat = 18, style: MarkStyle = .menuBar) {
        self.size = size
        self.style = style
    }

    var body: some View {
        ZStack {
            if style == .brand {
                RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.50, green: 0.82, blue: 1.00), Color(red: 0.29, green: 0.66, blue: 0.91)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: size * 0.72, height: size * 0.72)
                    .blur(radius: size * 0.08)
                    .offset(y: -size * 0.12)
            }

            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(windowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                        .stroke(frameStroke, lineWidth: max(1, size * 0.06))
                )
                .frame(width: size * 0.68, height: size * 0.62)

            Rectangle()
                .fill(frameStroke.opacity(style == .brand ? 0.34 : 0.6))
                .frame(width: size * 0.68, height: max(1, size * 0.035))
                .offset(y: -size * 0.16)

            trafficLights
                .offset(x: -size * 0.17, y: -size * 0.235)

            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .fill(snappedPaneFill)
                .frame(width: size * 0.23, height: size * 0.36)
                .offset(x: -size * 0.13, y: size * 0.09)

            VStack(spacing: size * 0.035) {
                RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                    .stroke(frameStroke.opacity(0.58), lineWidth: max(0.6, size * 0.035))
                RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                    .stroke(frameStroke.opacity(0.42), lineWidth: max(0.6, size * 0.035))
            }
            .frame(width: size * 0.2, height: size * 0.34)
            .offset(x: size * 0.16, y: size * 0.09)

            snapArrow
        }
        .frame(width: size, height: size)
    }

    private var frameStroke: Color {
        switch style {
        case .menuBar:
            return .primary
        case .brand:
            return .white.opacity(0.82)
        }
    }

    private var windowFill: Color {
        switch style {
        case .menuBar:
            return .clear
        case .brand:
            return Color(red: 0.02, green: 0.06, blue: 0.11).opacity(0.82)
        }
    }

    private var snappedPaneFill: Color {
        switch style {
        case .menuBar:
            return .primary
        case .brand:
            return Color(red: 0.86, green: 0.97, blue: 1.0)
        }
    }

    private var trafficLights: some View {
        HStack(spacing: max(1, size * 0.035)) {
            Circle().fill(trafficColor(red: 1.00, green: 0.37, blue: 0.34))
            Circle().fill(trafficColor(red: 1.00, green: 0.74, blue: 0.18))
            Circle().fill(trafficColor(red: 0.16, green: 0.78, blue: 0.25))
        }
        .frame(width: size * 0.16, height: size * 0.035)
    }

    private func trafficColor(red: Double, green: Double, blue: Double) -> Color {
        switch style {
        case .menuBar:
            return .primary.opacity(0.72)
        case .brand:
            return Color(red: red, green: green, blue: blue)
        }
    }

    private var snapArrow: some View {
        Path { path in
            let centerY = size * 0.56
            path.move(to: CGPoint(x: size * 0.52, y: centerY))
            path.addLine(to: CGPoint(x: size * 0.26, y: centerY))
            path.move(to: CGPoint(x: size * 0.38, y: size * 0.44))
            path.addLine(to: CGPoint(x: size * 0.26, y: centerY))
            path.addLine(to: CGPoint(x: size * 0.38, y: size * 0.68))
        }
        .stroke(arrowStroke, style: StrokeStyle(lineWidth: max(1, size * 0.055), lineCap: .round, lineJoin: .round))
    }

    private var arrowStroke: Color {
        switch style {
        case .menuBar:
            return Color.primary.opacity(0.86)
        case .brand:
            return .white
        }
    }
}
