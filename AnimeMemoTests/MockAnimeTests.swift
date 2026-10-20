import Testing
@testable import AnimeMemo

struct MockAnimeTests {
    @Test
    func progressFractionIsClamped() {
        #expect(MockAnime.frieren.progressFraction == 5.0 / 12.0)

        var finished = MockAnime.lookback
        finished.progress = 1
        #expect(finished.progressFraction == 1)

        var overdone = MockAnime.frieren
        overdone.progress = 99
        #expect(overdone.progressFraction == 1)
    }

    @Test
    func movieProgressUsesSingleEpisode() {
        #expect(MockAnime.lookback.isMovie)
        #expect(MockAnime.lookback.total == 1)
        #expect(MockAnime.lookback.progressText == "已看完")
    }
}
