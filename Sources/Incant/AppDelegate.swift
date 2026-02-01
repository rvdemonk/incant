import AppKit
import Carbon

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var recordingState: RecordingState!
    private let cache = TranscriptCache()
    private let costTracker = CostTracker()

    // Hotkeys for different modes
    private var hotKeyCopyOnly: GlobalHotKey?      // ⌥`
    private var hotKeyAutoPaste: GlobalHotKey?     // ⌥⇧`
    private var hotKeyAutoPasteSend: GlobalHotKey? // ⌥⌃`

    // Recording duration display
    private var recordingStartTime: Date?
    private var durationTimer: Timer?

    // Transcribing animation
    private var pulseTimer: Timer?
    private var pulsePhase: CGFloat = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        recordingState = RecordingState(
            onStateChange: { [weak self] state in self?.updateIcon(for: state) },
            onTranscript: { [weak self] text, duration, mode in self?.handleTranscript(text, duration: duration, mode: mode) },
            onError: { [weak self] error in self?.showError(error) },
            onDiscarded: { [weak self] in self?.handleDiscarded() }
        )
        setupMenuBar()
        setupGlobalHotKeys()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }
        updateIcon(for: .idle)

        // Any click shows the menu
        button.target = self
        button.action = #selector(handleClick)
    }

    private func setupGlobalHotKeys() {
        // ⌥` — Copy only (default)
        hotKeyCopyOnly = GlobalHotKey(
            keyCode: GlobalHotKey.kVK_Grave,
            modifiers: UInt32(optionKey),
            callback: { [weak self] in
                self?.toggleRecording(mode: .copyOnly)
            }
        )

        // ⌥⇧` — Auto-paste
        hotKeyAutoPaste = GlobalHotKey(
            keyCode: GlobalHotKey.kVK_Grave,
            modifiers: UInt32(optionKey) | UInt32(shiftKey),
            callback: { [weak self] in
                self?.toggleRecording(mode: .autoPaste)
            }
        )

        // ⌥⌃` — Auto-paste + Enter
        hotKeyAutoPasteSend = GlobalHotKey(
            keyCode: GlobalHotKey.kVK_Grave,
            modifiers: UInt32(optionKey) | UInt32(controlKey),
            callback: { [weak self] in
                self?.toggleRecording(mode: .autoPasteSend)
            }
        )
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        showMenu()
    }

    private func toggleRecording(mode: RecordingMode = .copyOnly) {
        Task {
            await recordingState.toggle(mode: mode)
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        // Cost tracking
        let todayCost = costTracker.todayCost
        let totalCost = costTracker.totalCost
        menu.addItem(NSMenuItem(title: String(format: "Today: $%.4f", todayCost), action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: String(format: "Total: $%.4f", totalCost), action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Recent transcripts
        let recentItems = cache.recent
        if !recentItems.isEmpty {
            menu.addItem(NSMenuItem(title: "Recent Transcripts", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())

            for (index, item) in recentItems.prefix(5).enumerated() {
                let preview = String(item.text.prefix(50)) + (item.text.count > 50 ? "..." : "")
                let menuItem = NSMenuItem(title: preview, action: #selector(copyTranscript(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.tag = index
                menu.addItem(menuItem)
            }
            menu.addItem(NSMenuItem.separator())
        }

        // Settings
        menu.addItem(NSMenuItem(title: "Settings", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Model selection
        let currentModel = Preferences.shared.model
        for model in [TranscriptionModel.gpt4oMini, .whisper] {
            let item = NSMenuItem(title: model.displayName, action: #selector(selectModel(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = model
            item.state = (model == currentModel) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())

        // Launch at login
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = Preferences.shared.launchAtLogin ? .on : .off
        menu.addItem(launchItem)
        menu.addItem(NSMenuItem.separator())

        // Hotkey hints
        menu.addItem(NSMenuItem(title: "Hotkeys", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "⌥`  Copy to clipboard", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "⌥⇧`  Copy + paste", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "⌥⌃`  Copy + paste + enter", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // Clear so left-click works again
    }

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let model = sender.representedObject as? TranscriptionModel else { return }
        Preferences.shared.model = model
    }

    @objc private func toggleLaunchAtLogin() {
        Preferences.shared.launchAtLogin.toggle()
    }

    @objc private func copyTranscript(_ sender: NSMenuItem) {
        let index = sender.tag
        let recentItems = cache.recent
        guard index < recentItems.count else { return }

        let text = recentItems[index].text
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func updateIcon(for state: State) {
        guard let button = statusItem?.button else { return }

        switch state {
        case .idle:
            stopDurationTimer()
            stopPulseAnimation()
            button.title = ""
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Incant - Ready")
            button.alphaValue = 1.0
            button.appearsDisabled = false

        case .recording:
            stopPulseAnimation()
            startDurationTimer()
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Incant - Recording")
            button.alphaValue = 1.0
            button.appearsDisabled = false

        case .transcribing:
            stopDurationTimer()
            button.title = ""
            button.image = NSImage(systemSymbolName: "arrow.up.circle", accessibilityDescription: "Incant - Transcribing")
            button.appearsDisabled = false
            startPulseAnimation()
        }
    }

    private func startPulseAnimation() {
        pulsePhase = 0
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.updatePulse()
            }
        }
    }

    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        statusItem?.button?.alphaValue = 1.0
    }

    private func updatePulse() {
        guard let button = statusItem?.button else { return }
        pulsePhase += 0.1
        // Sine wave between 0.4 and 1.0
        let alpha = 0.7 + 0.3 * sin(pulsePhase)
        button.alphaValue = CGFloat(alpha)
    }

    private func startDurationTimer() {
        recordingStartTime = Date()
        updateDurationDisplay()

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateDurationDisplay()
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        recordingStartTime = nil
    }

    private func updateDurationDisplay() {
        guard let startTime = recordingStartTime,
              let button = statusItem?.button else { return }

        let elapsed = Int(Date().timeIntervalSince(startTime))
        button.title = " \(elapsed)s"
    }

    private func handleTranscript(_ text: String, duration: Double, mode: RecordingMode) {
        cache.add(text)
        costTracker.recordCost(durationSeconds: duration)
        SoundEffects.playReady()

        // Flash the icon green briefly
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Incant - Done")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.updateIcon(for: .idle)
            }
        }

        // Handle auto-paste modes
        switch mode {
        case .copyOnly:
            showNotification(title: "Copied to clipboard", body: String(text.prefix(100)))
        case .autoPaste:
            // Small delay to ensure clipboard is ready, then paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                KeySimulator.paste()
            }
        case .autoPasteSend:
            // Paste, then send
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                KeySimulator.paste()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    KeySimulator.enter()
                }
            }
        }
    }

    private func handleDiscarded() {
        // Recording too short - just reset silently (no success sound/notification)
        updateIcon(for: .idle)
    }

    private func showError(_ message: String) {
        showNotification(title: "Incant Error", body: message)
        updateIcon(for: .idle)
    }

    private func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = nil
        NSUserNotificationCenter.default.deliver(notification)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
