import Foundation

final class PersistenceService {
    static let shared = PersistenceService()

    private let url: URL

    init(filename: String = "WaterQuestState.json") {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.url = directory.appendingPathComponent(filename)
    }

    func load<T: Decodable>(_ type: T.Type, fallback: T) -> T {
        guard let data = try? Data(contentsOf: url) else { return fallback }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(T.self, from: data)) ?? fallback
    }

    func save<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(value)
            let directory = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try data.write(to: url, options: [.atomic])
        } catch {
            #if DEBUG
            print("Failed to save Sipli state: \(error)")
            #endif
        }
    }
}
