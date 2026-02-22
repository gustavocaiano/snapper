import SwiftUI

struct ZoneDetailView: View {
    @Binding var zone: SnapperZone

    let screens: [ScreenDescriptor]
    let warningMessage: String?
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onShortcutChange: (HotKey?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Zone name", text: $zone.name)
                    .textFieldStyle(.roundedBorder)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
            }

            Picker("Display", selection: $zone.screenIndex) {
                ForEach(screens) { screen in
                    Text(screen.name).tag(screen.index)
                }
            }

            HStack {
                Text("Shortcut")
                    .font(.subheadline)
                Spacer()
                ShortcutRecorderView(value: zone.shortcut, onChange: onShortcutChange)
            }

            Text(frameSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let warningMessage {
                Text(warningMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
    }

    private var frameSummary: String {
        let x = Int(zone.rect.origin.x * 100)
        let y = Int(zone.rect.origin.y * 100)
        let width = Int(zone.rect.size.width * 100)
        let height = Int(zone.rect.size.height * 100)
        return "x:\(x)% y:\(y)%  w:\(width)% h:\(height)%"
    }
}
