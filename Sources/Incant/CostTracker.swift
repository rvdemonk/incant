import Foundation

struct DailyCost: Codable {
    let date: String // YYYY-MM-DD
    var cost: Double
}

struct CostData: Codable {
    var totalCost: Double
    var dailyCosts: [DailyCost]

    static let empty = CostData(totalCost: 0, dailyCosts: [])
}

final class CostTracker {
    private var data: CostData
    private let fileURL: URL

    init() {
        // Store in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let incantDir = appSupport.appendingPathComponent("Incant", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: incantDir, withIntermediateDirectories: true)

        fileURL = incantDir.appendingPathComponent("costs.json")
        data = Self.load(from: fileURL)
    }

    /// Record cost for a transcription based on audio duration
    func recordCost(durationSeconds: Double) {
        let costPerMinute = Preferences.shared.model.costPerMinute
        let cost = (durationSeconds / 60.0) * costPerMinute

        data.totalCost += cost

        let today = Self.todayString()
        if let index = data.dailyCosts.firstIndex(where: { $0.date == today }) {
            data.dailyCosts[index].cost += cost
        } else {
            data.dailyCosts.append(DailyCost(date: today, cost: cost))
        }

        // Keep only last 30 days of daily data
        if data.dailyCosts.count > 30 {
            data.dailyCosts = Array(data.dailyCosts.suffix(30))
        }

        save()
    }

    var totalCost: Double {
        data.totalCost
    }

    var todayCost: Double {
        let today = Self.todayString()
        return data.dailyCosts.first(where: { $0.date == today })?.cost ?? 0
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let jsonData = try? encoder.encode(data) {
            try? jsonData.write(to: fileURL)
        }
    }

    private static func load(from url: URL) -> CostData {
        guard let jsonData = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(CostData.self, from: jsonData) else {
            return .empty
        }
        return decoded
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
