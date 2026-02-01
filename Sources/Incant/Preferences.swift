import Foundation
import ServiceManagement

enum TranscriptionModel: String, Codable {
    case whisper = "whisper-1"
    case gpt4oMini = "gpt-4o-mini-transcribe"

    var displayName: String {
        switch self {
        case .whisper: return "Whisper ($0.006/min)"
        case .gpt4oMini: return "GPT-4o Mini ($0.003/min)"
        }
    }

    var costPerMinute: Double {
        switch self {
        case .whisper: return 0.006
        case .gpt4oMini: return 0.003
        }
    }
}

final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let model = "transcriptionModel"
        static let launchAtLogin = "launchAtLogin"
    }

    var model: TranscriptionModel {
        get {
            guard let raw = defaults.string(forKey: Keys.model),
                  let model = TranscriptionModel(rawValue: raw) else {
                return .gpt4oMini // Default to cheaper model
            }
            return model
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.model)
        }
    }

    var launchAtLogin: Bool {
        get {
            defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin(newValue)
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }

    private init() {}
}
