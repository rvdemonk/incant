import Carbon
import AppKit

/// Global hotkey using Carbon API (works without accessibility permissions)
final class GlobalHotKey {
    private static var nextID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let callback: () -> Void
    private let id: UInt32

    // Modifier flags for Carbon
    static let optionKey: UInt32 = UInt32(optionKey)
    static let commandKey: UInt32 = UInt32(cmdKey)
    static let controlKey: UInt32 = UInt32(controlKey)
    static let shiftKey: UInt32 = UInt32(shiftKey)

    init(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        self.id = GlobalHotKey.nextID
        GlobalHotKey.nextID += 1
        self.callback = callback
        register(keyCode: keyCode, modifiers: modifiers)
    }

    deinit {
        unregister()
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        // Store self reference for callback
        let refcon = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())

        // Set up event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                hotKey.callback()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerCallback,
            1,
            &eventType,
            refcon,
            &eventHandler
        )

        // Register the hotkey
        let hotKeyID = EventHotKeyID(signature: OSType(0x494E4354), id: id) // "INCT"
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

// Common key codes
extension GlobalHotKey {
    // Key code for ` (grave/backtick) - key below Escape
    static let kVK_Grave: UInt32 = 0x32

    // Key code for Space
    static let kVK_Space: UInt32 = 0x31

    // Key code for Escape
    static let kVK_Escape: UInt32 = 0x35
}
