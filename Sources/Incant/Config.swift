import Foundation

enum Config {
    /// Looks for API key in order:
    /// 1. Environment variable OPENAI_API_KEY
    /// 2. ~/.env file (OPENAI_API_SECRET_KEY or OPENAI_API_KEY)
    /// 3. ~/Library/Application Support/Incant/config (future)
    static var openAIAPIKey: String {
        // Check environment variable first (standard approach)
        if let envVar = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envVar.isEmpty {
            return envVar
        }

        // Fall back to ~/.env file
        if let fromFile = loadFromEnvFile("OPENAI_API_KEY") ?? loadFromEnvFile("OPENAI_API_SECRET_KEY") {
            return fromFile
        }

        print("Warning: No OpenAI API key found. Set OPENAI_API_KEY environment variable or add to ~/.env")
        return ""
    }

    private static func loadFromEnvFile(_ key: String) -> String? {
        let envPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".env")

        guard let contents = try? String(contentsOf: envPath, encoding: .utf8) else {
            return nil
        }

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)

            // Remove surrounding quotes if present
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            if name == key {
                return value
            }
        }

        return nil
    }
}
