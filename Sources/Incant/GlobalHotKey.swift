import Carbon
import AppKit

/// Manages global hotkeys using Carbon API
final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()

    private var hotKeys: [UInt32: () -> Void] = [:]  // id -> callback
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    private init() {
        installEventHandler()
    }

    deinit {
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
    }

    func register(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        let id = nextID
        nextID += 1

        hotKeys[id] = callback

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x494E4354), id: id) // "INCT"
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs[id] = ref
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }

            // Extract hotkey ID from event
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr else { return OSStatus(eventNotHandledErr) }

            let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            if let callback = manager.hotKeys[hotKeyID.id] {
                DispatchQueue.main.async {
                    callback()
                }
            }

            return noErr
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            refcon,
            &eventHandler
        )
    }
}

// Convenience wrapper for cleaner API
final class GlobalHotKey {
    // Key codes
    static let kVK_Grave: UInt32 = 0x32
    static let kVK_Space: UInt32 = 0x31
    static let kVK_Escape: UInt32 = 0x35

    init(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        GlobalHotKeyManager.shared.register(keyCode: keyCode, modifiers: modifiers, callback: callback)
    }
}
