import Foundation
import Observation

struct LibraryBackup: Codable {
    let version: Int
    let exportedAt: Date
    let entries: [MockAnime]
}

@MainActor
@Observable
final class LibraryStore {
    private(set) var entries: [MockAnime]
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()

        #if DEBUG
        // Deterministic state for UI tests: `-resetLibrary` starts from seeds.
        if CommandLine.arguments.contains("-resetLibrary") {
            self.entries = Self.seedEntries()
            persist()
            return
        }
        #endif

        if let loaded = Self.load(from: self.fileURL) {
            let enriched = loaded.map(Self.enrichingMockMetadata)
            self.entries = enriched
            if enriched != loaded {
                persist()
            }
        } else {
            self.entries = Self.seedEntries()
            persist()
        }
    }

    init(entries: [MockAnime], fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.entries = entries
    }

    func entry(for id: String) -> MockAnime? {
        entries.first { $0.id == id }
    }

    func entry(tmdbID: Int, mediaType: String, seasonNumber: Int?) -> MockAnime? {
        entries.first {
            $0.tmdbID == tmdbID
                && $0.mediaType == mediaType
                && $0.seasonNumber == seasonNumber
        }
    }

    func contains(tmdbID: Int, mediaType: String, seasonNumber: Int?) -> Bool {
        entry(tmdbID: tmdbID, mediaType: mediaType, seasonNumber: seasonNumber) != nil
    }

    func upsert(_ anime: MockAnime) {
        if let index = entries.firstIndex(where: { $0.id == anime.id }) {
            entries[index] = anime
        } else if anime.tmdbID != nil, let index = entries.firstIndex(where: {
            $0.tmdbID == anime.tmdbID
                && $0.mediaType == anime.mediaType
                && $0.seasonNumber == anime.seasonNumber
        }) {
            entries[index] = anime
        } else {
            entries.insert(anime, at: 0)
        }
        persist()
    }

    func replace(_ anime: MockAnime) {
        guard let index = entries.firstIndex(where: { $0.id == anime.id }) else { return }
        entries[index] = anime
        persist()
    }

    @discardableResult
    func increment(id: String) -> (previous: MockAnime, current: MockAnime)? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }

        let previous = entries[index]
        var current = previous
        let total = max(current.total, 1)
        current.progress = min(current.progress + 1, total)

        if current.status == .planning {
            current.status = .watching
        }
        if current.progress >= total {
            current.status = .completed
        }

        entries.remove(at: index)
        entries.insert(current, at: 0)
        persist()
        return (previous, current)
    }

    @discardableResult
    func remove(id: String) -> (anime: MockAnime, index: Int)? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = entries.remove(at: index)
        persist()
        return (removed, index)
    }

    func restore(_ anime: MockAnime, at index: Int) {
        entries.insert(anime, at: min(index, entries.count))
        persist()
    }

    func clear() {
        entries = []
        persist()
    }

    func exportData() throws -> Data {
        let backup = LibraryBackup(
            version: 1,
            exportedAt: .now,
            entries: entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    func importData(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let imported: [MockAnime]
        if let backup = try? decoder.decode(LibraryBackup.self, from: data) {
            imported = backup.entries
        } else {
            imported = try decoder.decode([MockAnime].self, from: data)
        }

        entries = imported
        persist()
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("LibraryStore persist failed: \(error)")
            #endif
        }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("AnimeMemo", isDirectory: true)
            .appendingPathComponent("library.json")
    }

    private static func load(from url: URL) -> [MockAnime]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([MockAnime].self, from: data)
    }

    private static func seedEntries() -> [MockAnime] {
        #if DEBUG
        return MockAnime.library
        #else
        return []
        #endif
    }

    private static func enrichingMockMetadata(_ entry: MockAnime) -> MockAnime {
        guard
            entry.tmdbID == nil,
            let mock = MockAnime.library.first(where: { $0.id == entry.id })
        else {
            return entry
        }

        var enriched = entry
        if enriched.posterURL == nil {
            enriched.posterURL = mock.posterURL
        }
        return enriched
    }
}
