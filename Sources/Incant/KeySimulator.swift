import CoreGraphics
import Carbon

enum KeySimulator {
    /// Simulate Cmd+V (paste)
    static func paste() {
        simulateKeyPress(keyCode: UInt16(kVK_ANSI_V), flags: .maskCommand)
    }

    /// Simulate Enter/Return
    static func enter() {
        simulateKeyPress(keyCode: UInt16(kVK_Return), flags: [])
    }

    private static func simulateKeyPress(keyCode: UInt16, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDown.flags = flags
            keyDown.post(tap: .cghidEventTap)
        }

        // Small delay between down and up
        usleep(10000) // 10ms

        // Key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUp.flags = flags
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
