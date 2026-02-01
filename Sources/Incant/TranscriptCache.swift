import Foundation

struct CachedTranscript: Codable {
    let text: String
    let timestamp: Date
}

@MainActor
final class TranscriptCache {
    private var items: [CachedTranscript] = []
    private let fileURL: URL
    private let maxItems = 50

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let incantDir = appSupport.appendingPathComponent("Incant", isDirectory: true)
        try? FileManager.default.createDirectory(at: incantDir, withIntermediateDirectories: true)

        fileURL = incantDir.appendingPathComponent("transcripts.json")
        items = Self.load(from: fileURL)
    }

    var recent: [CachedTranscript] {
        items
    }

    func add(_ text: String) {
        let item = CachedTranscript(text: text, timestamp: Date())
        items.insert(item, at: 0)

        // Keep last N items
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(items) {
            try? data.write(to: fileURL)
        }
    }

    private static func load(from url: URL) -> [CachedTranscript] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CachedTranscript].self, from: data)) ?? []
    }
}
