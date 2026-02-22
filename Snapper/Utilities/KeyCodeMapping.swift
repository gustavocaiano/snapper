import AppKit
import Carbon

enum KeyCodeMapping {
    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        36: "Return", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc",
        55: "Cmd", 56: "Shift", 57: "Caps", 58: "Option", 59: "Ctrl",
        60: "Right Shift", 61: "Right Option", 62: "Right Ctrl",
        63: "Fn",
        64: "F17", 65: "Num .", 67: "Num *", 69: "Num +", 71: "Num Clear", 75: "Num /", 76: "Num Enter", 78: "Num -", 81: "Num =", 82: "Num 0", 83: "Num 1", 84: "Num 2", 85: "Num 3", 86: "Num 4", 87: "Num 5", 88: "Num 6", 89: "Num 7", 91: "Num 8", 92: "Num 9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "Home", 116: "PgUp", 117: "Forward Delete", 118: "F4", 119: "End", 120: "F2", 121: "PgDn", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    static func sanitizedModifiers(from flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags.intersection([.command, .option, .control, .shift])
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let cleaned = sanitizedModifiers(from: flags)
        var result: UInt32 = 0

        if cleaned.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if cleaned.contains(.option) {
            result |= UInt32(optionKey)
        }
        if cleaned.contains(.control) {
            result |= UInt32(controlKey)
        }
        if cleaned.contains(.shift) {
            result |= UInt32(shiftKey)
        }

        return result
    }

    static func eventModifiers(from carbonModifiers: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []

        if carbonModifiers & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }
        if carbonModifiers & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }

        return flags
    }

    static func modifierSymbols(for carbonModifiers: UInt32) -> String {
        var value = ""

        if carbonModifiers & UInt32(controlKey) != 0 {
            value += "⌃"
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            value += "⌥"
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            value += "⇧"
        }
        if carbonModifiers & UInt32(cmdKey) != 0 {
            value += "⌘"
        }

        return value
    }

    static func keyName(for keyCode: UInt32) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }

    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        let symbols = modifierSymbols(for: modifiers)
        return symbols + keyName(for: keyCode)
    }
}
