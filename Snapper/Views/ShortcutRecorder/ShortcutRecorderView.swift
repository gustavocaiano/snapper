import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorderView: View {
    let value: HotKey?
    let onChange: (HotKey?) -> Void

    @State private var isRecording = false
    @State private var keyDownMonitor: Any?
    @State private var flagsMonitor: Any?
    @State private var liveModifiers: NSEvent.ModifierFlags = []
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    isRecording ? stopRecording() : startRecording()
                } label: {
                    Text(buttonLabel)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 112)
                }
                .buttonStyle(.borderedProminent)

                if value != nil, !isRecording {
                    Button {
                        onChange(nil)
                        validationMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private var buttonLabel: String {
        if isRecording {
            let symbols = KeyCodeMapping.modifierSymbols(
                for: KeyCodeMapping.carbonModifiers(from: liveModifiers)
            )
            return symbols.isEmpty ? "Press shortcut..." : "\(symbols)..."
        }

        return value?.displayString ?? "Record Shortcut"
    }

    private func startRecording() {
        validationMessage = nil
        isRecording = true

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            liveModifiers = KeyCodeMapping.sanitizedModifiers(from: event.modifierFlags)
            return event
        }

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event: event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        liveModifiers = []

        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }

        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
            self.flagsMonitor = nil
        }
    }

    private func handle(event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        let modifiers = KeyCodeMapping.sanitizedModifiers(from: event.modifierFlags)
        guard !modifiers.isEmpty else {
            validationMessage = "Shortcut must include at least one modifier key."
            return
        }

        let carbonModifiers = KeyCodeMapping.carbonModifiers(from: modifiers)
        let keyCode = UInt32(event.keyCode)
        let displayString = KeyCodeMapping.displayString(keyCode: keyCode, modifiers: carbonModifiers)

        onChange(
            HotKey(
                keyCode: keyCode,
                modifiers: carbonModifiers,
                displayString: displayString
            )
        )

        validationMessage = nil
        stopRecording()
    }
}
