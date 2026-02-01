import AppKit

enum SoundEffects {
    // Subtle system sounds
    // Pop for toggle (start/stop), Glass for success
    private static let toggleSound = NSSound(named: "Pop")
    private static let readySound = NSSound(named: "Glass")

    static func playStart() {
        toggleSound?.play()
    }

    static func playStop() {
        toggleSound?.play()
    }

    static func playReady() {
        readySound?.play()
    }
}
