import Foundation
import Testing
@testable import AnimeMemo

@MainActor
struct SeasonProgressTests {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AnimeMemoSeasonTests-\(UUID().uuidString)")
            .appendingPathComponent("library.json")
    }

    private func series() -> MockAnime {
        var item = MockAnime.debugRemoteFrieren
        item.seasons = [
            SeasonOption(number: 1, name: "第 1 季", episodeCount: 28),
            SeasonOption(number: 2, name: "第 2 季", episodeCount: 12)
        ]
        item.seasonNumber = 1
        item.total = 28
        return item
    }

    @Test
    func scopedSeasonUsesItsOwnIdentifierAndEpisodeCount() {
        let anime = series()
        let first = anime.scoped(to: anime.seasons[0])
        let second = anime.scoped(to: anime.seasons[1])

        #expect(first.id == "tv-209867-s1")
        #expect(second.id == "tv-209867-s2")
        #expect(first.total == 28)
        #expect(second.total == 12)
        #expect(first.seasonNumber == 1)
        #expect(second.seasonNumber == 2)
    }

    @Test
    func seasonsKeepIndependentProgress() {
        let anime = series()
        let store = LibraryStore(entries: [], fileURL: temporaryURL())

        var seasonOne = anime.scoped(to: anime.seasons[0])
        seasonOne.progress = 28
        seasonOne.status = .completed
        store.upsert(seasonOne)

        var seasonTwo = anime.scoped(to: anime.seasons[1])
        seasonTwo.progress = 5
        seasonTwo.status = .watching
        store.upsert(seasonTwo)

        #expect(store.entries.count == 2)
        #expect(store.entry(for: "tv-209867-s1")?.progress == 28)
        #expect(store.entry(for: "tv-209867-s2")?.progress == 5)
        #expect(store.entry(tmdbID: 209867, mediaType: "tv", seasonNumber: 1)?.status == .completed)
        #expect(store.entry(tmdbID: 209867, mediaType: "tv", seasonNumber: 2)?.status == .watching)
    }

    @Test
    func incrementingOneSeasonDoesNotTouchTheOther() throws {
        let anime = series()
        let store = LibraryStore(entries: [], fileURL: temporaryURL())

        var seasonOne = anime.scoped(to: anime.seasons[0])
        seasonOne.progress = 3
        seasonOne.status = .watching
        store.upsert(seasonOne)

        var seasonTwo = anime.scoped(to: anime.seasons[1])
        seasonTwo.progress = 8
        seasonTwo.status = .watching
        store.upsert(seasonTwo)

        let result = try #require(store.increment(id: "tv-209867-s2"))
        #expect(result.current.progress == 9)
        #expect(store.entry(for: "tv-209867-s1")?.progress == 3)
    }
}
