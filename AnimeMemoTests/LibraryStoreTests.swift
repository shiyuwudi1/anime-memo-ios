import Foundation
import Testing
@testable import AnimeMemo

@MainActor
struct LibraryStoreTests {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AnimeMemoTests-\(UUID().uuidString)")
            .appendingPathComponent("library.json")
    }

    @Test
    func incrementMovesEntryAndUpdatesStatus() {
        let store = LibraryStore(entries: [MockAnime.frieren], fileURL: temporaryURL())

        let result = store.increment(id: MockAnime.frieren.id)

        #expect(result?.previous.progress == 5)
        #expect(result?.current.progress == 6)
        #expect(store.entry(for: MockAnime.frieren.id)?.progress == 6)
        #expect(store.entry(for: MockAnime.frieren.id)?.status == .watching)
    }

    @Test
    func incrementCompletesAtTotal() {
        var almostDone = MockAnime.frieren
        almostDone.progress = almostDone.total - 1
        let store = LibraryStore(entries: [almostDone], fileURL: temporaryURL())

        let result = store.increment(id: almostDone.id)

        #expect(result?.current.progress == almostDone.total)
        #expect(result?.current.status == .completed)
    }

    @Test
    func removeAndRestore() {
        let store = LibraryStore(entries: [MockAnime.frieren, MockAnime.solo], fileURL: temporaryURL())

        let removed = store.remove(id: MockAnime.frieren.id)
        #expect(store.entries.count == 1)
        #expect(removed?.anime.id == MockAnime.frieren.id)

        if let removed {
            store.restore(removed.anime, at: removed.index)
        }
        #expect(store.entries.count == 2)
    }

    @Test
    func backupRoundTrip() throws {
        let store = LibraryStore(
            entries: [MockAnime.frieren, MockAnime.lookback],
            fileURL: temporaryURL()
        )

        let data = try store.exportData()
        let backup = try JSONDecoder.iso8601.decode(LibraryBackup.self, from: data)
        #expect(backup.version == 1)
        #expect(backup.entries.count == 2)

        let restored = LibraryStore(entries: [], fileURL: temporaryURL())
        try restored.importData(data)
        #expect(restored.entries.count == 2)
        #expect(restored.entry(for: MockAnime.lookback.id)?.isMovie == true)
    }

    @Test
    func upsertFindsExistingSeriesBySeason() {
        var existing = MockAnime.frieren
        existing.tmdbID = 123
        existing.mediaType = "tv"
        existing.seasonNumber = 2

        let store = LibraryStore(entries: [existing], fileURL: temporaryURL())

        var updated = existing
        updated.id = "a-different-id"
        updated.progress = 9
        store.upsert(updated)

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.progress == 9)
    }

    @Test
    func mutationsPersistAcrossStoreInstances() {
        let url = temporaryURL()
        let store = LibraryStore(entries: [MockAnime.frieren], fileURL: url)
        _ = store.increment(id: MockAnime.frieren.id)

        let reloaded = LibraryStore(fileURL: url)
        #expect(reloaded.entry(for: MockAnime.frieren.id)?.progress == 6)
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
