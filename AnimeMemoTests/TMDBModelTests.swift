import Foundation
import Testing
@testable import AnimeMemo

struct TMDBModelTests {
    @Test
    func searchMultiDecodesTVAndMovie() throws {
        let json = """
        {
          "page": 1,
          "results": [
            {
              "id": 154587,
              "media_type": "tv",
              "name": "葬送的芙莉莲",
              "original_name": "Sousou no Frieren",
              "overview": "精灵魔法使的旅程。",
              "poster_path": "/frieren.jpg",
              "first_air_date": "2023-09-29",
              "vote_average": 9.2,
              "genre_ids": [16, 12, 14],
              "original_language": "ja"
            },
            {
              "id": 123,
              "media_type": "movie",
              "title": "蓦然回首",
              "original_title": "Look Back",
              "overview": "两个女孩的漫画人生。",
              "poster_path": "/lookback.jpg",
              "release_date": "2024-06-28",
              "vote_average": 9.0,
              "genre_ids": [16, 18],
              "original_language": "ja"
            },
            {
              "id": 999,
              "media_type": "person",
              "name": "Someone"
            }
          ],
          "total_pages": 1,
          "total_results": 3
        }
        """

        let page = try JSONDecoder().decode(
            TMDBPage<TMDBMediaSummary>.self,
            from: Data(json.utf8)
        )

        #expect(page.results.count == 3)
        #expect(page.results[0].mediaType == .tv)
        #expect(page.results[0].displayTitle == "葬送的芙莉莲")
        #expect(page.results[0].year == "2023")
        #expect(page.results[0].isAnimation)
        #expect(page.results[1].mediaType == .movie)
        #expect(page.results[1].displayTitle == "蓦然回首")
        #expect(page.results[1].year == "2024")
        #expect(page.results[2].mediaType == nil)
        #expect(page.results.filter(\.isSupportedMedia).count == 2)
    }

    @Test
    func tvDetailDecodesSeasonsAndNextEpisode() throws {
        let json = """
        {
          "id": 154587,
          "name": "葬送的芙莉莲",
          "original_name": "Sousou no Frieren",
          "overview": "精灵魔法使的旅程。",
          "poster_path": "/frieren.jpg",
          "backdrop_path": "/frieren-backdrop.jpg",
          "first_air_date": "2023-09-29",
          "status": "Returning Series",
          "genres": [{ "id": 16, "name": "动画" }],
          "networks": [{ "id": 1, "name": "Nippon TV", "logo_path": null }],
          "number_of_seasons": 2,
          "number_of_episodes": 40,
          "seasons": [
            {
              "season_number": 1,
              "name": "第 1 季",
              "overview": "第一季",
              "poster_path": "/s1.jpg",
              "air_date": "2023-09-29",
              "episode_count": 28
            },
            {
              "season_number": 2,
              "name": "第 2 季",
              "overview": "第二季",
              "poster_path": "/s2.jpg",
              "air_date": "2026-01-09",
              "episode_count": 12
            }
          ],
          "next_episode_to_air": {
            "season_number": 2,
            "episode_number": 6,
            "name": "第 6 话",
            "overview": "新的旅程。",
            "air_date": "2026-10-23",
            "still_path": "/still.jpg",
            "runtime": 24
          },
          "last_episode_to_air": {
            "season_number": 2,
            "episode_number": 5,
            "name": "第 5 话",
            "overview": "上一话。",
            "air_date": "2026-10-16",
            "still_path": "/still5.jpg",
            "runtime": 24
          },
          "vote_average": 9.2,
          "original_language": "ja"
        }
        """

        let detail = try JSONDecoder().decode(TMDBTVDetail.self, from: Data(json.utf8))

        #expect(detail.id == 154587)
        #expect(detail.seasons.count == 2)
        #expect(detail.seasons[1].episodeCount == 12)
        #expect(detail.nextEpisodeToAir?.episodeNumber == 6)
        #expect(detail.nextEpisodeToAir?.seasonNumber == 2)
        #expect(detail.lastEpisodeToAir?.episodeNumber == 5)
        #expect(detail.genres.first?.name == "动画")
    }

    @Test
    func movieDetailDecodesRuntime() throws {
        let json = """
        {
          "id": 123,
          "title": "蓦然回首",
          "original_title": "Look Back",
          "overview": "两个女孩的漫画人生。",
          "poster_path": "/lookback.jpg",
          "backdrop_path": "/lookback-backdrop.jpg",
          "release_date": "2024-06-28",
          "runtime": 58,
          "status": "Released",
          "genres": [{ "id": 16, "name": "动画" }],
          "production_companies": [{ "id": 1, "name": "Studio", "logo_path": null }],
          "vote_average": 9.0,
          "original_language": "ja"
        }
        """

        let detail = try JSONDecoder().decode(TMDBMovieDetail.self, from: Data(json.utf8))

        #expect(detail.runtime == 58)
        #expect(detail.productionCompanies.first?.name == "Studio")
        #expect(TMDBDate.date(from: detail.releaseDate) != nil)
    }

    @Test
    func imageURLUsesRequestedSize() {
        let url = TMDBImage.url("/poster.jpg", size: "w342")
        #expect(url?.absoluteString == "https://image.tmdb.org/t/p/w342/poster.jpg")
    }
}
