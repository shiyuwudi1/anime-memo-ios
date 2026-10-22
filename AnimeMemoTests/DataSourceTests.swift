import Foundation
import Testing
@testable import AnimeMemo

struct AppConfigurationTests {
    @Test
    func proxyAddressIsNormalized() {
        #expect(
            AppConfiguration.normalizedTMDBBaseURL("https://tmdb.example.com/3/").absoluteString
                == "https://tmdb.example.com/3"
        )
        #expect(
            AppConfiguration.normalizedTMDBBaseURL("tmdb.example.com").absoluteString
                == "https://tmdb.example.com/3"
        )
        #expect(
            AppConfiguration.normalizedTMDBBaseURL("https://tmdb.example.com").absoluteString
                == "https://tmdb.example.com/3"
        )
        #expect(
            AppConfiguration.normalizedTMDBBaseURL("https://tmdb.example.com/proxy/3?x=1").absoluteString
                == "https://tmdb.example.com/proxy/3"
        )
    }

    @Test
    func invalidProxyFallsBackToOfficialAPI() {
        #expect(
            AppConfiguration.normalizedTMDBBaseURL("   ").absoluteString
                == AppConfiguration.defaultTMDBBaseURLString
        )
        #expect(
            AppConfiguration.normalizedTMDBBaseURL("ftp://example.com").absoluteString
                == AppConfiguration.defaultTMDBBaseURLString
        )
    }
}

struct ProviderAvailabilityTests {
    private func health(_ provider: MetadataProvider, available: Bool) -> ProviderHealth {
        ProviderHealth(
            provider: provider,
            failureReason: available ? nil : "offline"
        )
    }

    @Test
    func keepsCurrentProviderWhenItWorks() {
        let results = [
            health(.tmdb, available: true),
            health(.bangumi, available: true)
        ]

        #expect(ProviderHealth.preferredProvider(from: results, current: .bangumi) == .bangumi)
        #expect(ProviderHealth.preferredProvider(from: results, current: .tmdb) == .tmdb)
    }

    @Test
    func fallsBackToTheOnlyWorkingProvider() {
        let results = [
            health(.tmdb, available: false),
            health(.bangumi, available: true)
        ]

        #expect(ProviderHealth.preferredProvider(from: results, current: .tmdb) == .bangumi)
        #expect(ProviderHealth.preferredProvider(from: results, current: .bangumi) == .bangumi)
    }

    @Test
    func blocksLaunchWhenNeitherProviderWorks() {
        let results = [
            health(.tmdb, available: false),
            health(.bangumi, available: false)
        ]

        #expect(ProviderHealth.preferredProvider(from: results, current: .tmdb) == nil)
    }
}

struct TMDBMediaTypeResolutionTests {
    @Test
    func discoverItemsWithoutMediaTypeDefaultToTV() throws {
        let json = """
        { "id": 1, "name": "A", "genre_ids": [16], "first_air_date": "2024-01-01" }
        """

        let summary = try JSONDecoder().decode(TMDBMediaSummary.self, from: Data(json.utf8))

        #expect(summary.mediaType == nil)
        #expect(summary.resolvedMediaType(default: .tv) == .tv)
        #expect(summary.isAnimation)

        let anime = MockAnime.from(summary: summary, mediaType: .tv)
        #expect(anime.mediaType == "tv")
        #expect(anime.isMovie == false)
        #expect(anime.id == "tv-1")
    }

    @Test
    func peopleResultsAreRejected() throws {
        let json = """
        { "id": 2, "media_type": "person", "name": "Somebody" }
        """

        let summary = try JSONDecoder().decode(TMDBMediaSummary.self, from: Data(json.utf8))
        #expect(summary.resolvedMediaType(default: .tv) == nil)
    }
}

struct BangumiMappingTests {
    private func subject(_ json: String) throws -> BangumiSubject {
        try JSONDecoder().decode(BangumiSubject.self, from: Data(json.utf8))
    }

    @Test
    func subjectMapsToAnimeEntry() throws {
        let subject = try subject(
            """
            {
              "id": 400602,
              "name": "Sousou no Frieren",
              "name_cn": "葬送的芙莉莲",
              "summary": "勇者一行击败魔王之后的故事。",
              "images": { "large": "http://lain.bgm.tv/pic/cover/l/aa/bb.jpg" },
              "rating": { "score": 8.8 },
              "date": "2023-09-29",
              "platform": "TV",
              "eps": 28,
              "total_episodes": 28,
              "type": 2,
              "meta_tags": ["TV", "日本", "奇幻"]
            }
            """
        )

        #expect(subject.displayTitle == "葬送的芙莉莲")
        #expect(subject.displayOriginalTitle == "Sousou no Frieren")
        #expect(subject.posterURL?.scheme == "https")
        #expect(subject.episodeCount == 28)
        #expect(subject.displayFormat == "TV")
        #expect(subject.displayGenres == ["奇幻"])

        let anime = MockAnime.from(bangumi: subject, episodes: [])
        #expect(anime.id == "bgm-400602")
        #expect(anime.total == 28)
        #expect(anime.score == 8.8)
        #expect(anime.isBangumi)
        #expect(anime.format == "TV")
    }

    @Test
    func episodeListFillsInMissingTotal() throws {
        let subject = try subject(
            """
            {
              "id": 1,
              "name": "Test",
              "name_cn": "测试",
              "summary": "",
              "images": {},
              "rating": { "score": 7.0 },
              "date": "2026-10-01",
              "platform": "TV",
              "eps": 0,
              "total_episodes": 0,
              "type": 2,
              "meta_tags": ["TV"]
            }
            """
        )

        let episodes = (1...12).map { number in
            BangumiEpisode(
                id: number,
                subjectID: 1,
                name: nil,
                nameCN: nil,
                airdate: "2099-01-\(String(format: "%02d", number))",
                ep: number,
                sort: Double(number)
            )
        }

        let anime = MockAnime.from(bangumi: subject, episodes: episodes)
        #expect(anime.total == 12)
        #expect(anime.nextEpisode != nil)
        #expect(anime.synopsis == "暂无简介。")
    }

    @Test
    func movieSubjectUsesSingleEpisodeProgress() throws {
        let subject = try subject(
            """
            {
              "id": 264225,
              "name": "Look Back",
              "name_cn": "蓦然回首",
              "summary": "两个女孩的故事。",
              "images": {},
              "rating": { "score": 8.6 },
              "date": "2024-06-28",
              "platform": "剧场版",
              "eps": 1,
              "total_episodes": 1,
              "type": 2,
              "meta_tags": ["剧场版"]
            }
            """
        )

        let anime = MockAnime.from(bangumi: subject, episodes: [])
        #expect(anime.isMovie)
        #expect(anime.total == 1)
        #expect(anime.progressText == "未看")
    }
}

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

struct TMDBProxyClientTests {
    private static let discoverJSON = """
    {
      "page": 1,
      "results": [
        {
          "id": 209867,
          "media_type": "tv",
          "name": "葬送的芙莉莲",
          "original_name": "葬送のフリーレン",
          "overview": "测试",
          "poster_path": null,
          "first_air_date": "2023-09-29",
          "vote_average": 8.8,
          "genre_ids": [16],
          "original_language": "ja"
        }
      ],
      "total_pages": 1,
      "total_results": 1
    }
    """

    @Test
    func proxyBaseURLDoesNotRequireClientToken() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url?.host == "tmdb.example.com")
            #expect(request.url?.path == "/3/discover/tv")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            return (try #require(response), Data(Self.discoverJSON.utf8))
        }

        let client = TMDBClient(
            token: "",
            session: StubURLProtocol.makeSession(),
            baseURL: URL(string: "https://tmdb.example.com/3")!
        )

        let page = try await client.discoverAnime()
        #expect(page.results.count == 1)
        #expect(page.results.first?.id == 209867)

        StubURLProtocol.handler = nil
    }

    @Test
    func officialAPIWithoutTokenReportsNotConfigured() async throws {
        let client = TMDBClient(
            token: "",
            session: StubURLProtocol.makeSession(),
            baseURL: URL(string: AppConfiguration.defaultTMDBBaseURLString)!
        )

        await #expect(throws: TMDBError.self) {
            _ = try await client.discoverAnime()
        }
    }
}

struct BangumiClientRequestTests {
    @Test
    func calendarRequestUsesAPIHostAndUserAgent() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://api.bgm.tv/calendar")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "User-Agent")?.contains("AnimeMemo") == true)

            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            return (try #require(response), Data("[]".utf8))
        }

        let client = BangumiClient(session: StubURLProtocol.makeSession())
        let days = try await client.calendar()
        #expect(days.isEmpty)

        StubURLProtocol.handler = nil
    }

    @Test
    func rateLimitIsReported() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )
            return (try #require(response), Data())
        }

        let client = BangumiClient(session: StubURLProtocol.makeSession())

        await #expect(throws: BangumiError.self) {
            _ = try await client.subject(id: 1)
        }

        StubURLProtocol.handler = nil
    }
}
