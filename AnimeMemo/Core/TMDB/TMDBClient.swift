import Foundation

enum TMDBError: Error, LocalizedError, Sendable {
    case notConfigured
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case network(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "TMDB API key 尚未配置。"
        case .invalidURL:
            return "TMDB 请求地址无效。"
        case .invalidResponse:
            return "TMDB 返回了无法识别的响应。"
        case .httpStatus(let code):
            return "TMDB 请求失败（HTTP \(code)）。"
        case .network(let message):
            return "无法连接 TMDB。\(message) 请检查网络，或在 iPhone 上开启代理/VPN 后重试。"
        case .decoding(let message):
            return "TMDB 数据解析失败：\(message)"
        }
    }
}

actor TMDBClient {
    private let token: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let baseURL = URL(string: "https://api.themoviedb.org/3")!

    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
        self.decoder = JSONDecoder()
    }

    static func makeFromConfiguration(session: URLSession? = nil) -> TMDBClient? {
        guard let token = AppConfiguration.tmdbReadAccessToken else { return nil }
        return TMDBClient(token: token, session: session ?? makeDefaultSession())
    }

    private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    func searchMulti(query: String, page: Int = 1) async throws -> TMDBPage<TMDBMediaSummary> {
        try await get(
            "/search/multi",
            query: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "include_adult", value: "false")
            ]
        )
    }

    func discoverAnime(page: Int = 1) async throws -> TMDBPage<TMDBMediaSummary> {
        try await get(
            "/discover/tv",
            query: [
                URLQueryItem(name: "with_genres", value: "16"),
                URLQueryItem(name: "with_original_language", value: "ja"),
                URLQueryItem(name: "sort_by", value: "popularity.desc"),
                URLQueryItem(name: "vote_count.gte", value: "10"),
                URLQueryItem(name: "page", value: String(page))
            ]
        )
    }

    func tvDetail(id: Int) async throws -> TMDBTVDetail {
        try await get("/tv/\(id)", query: [])
    }

    func movieDetail(id: Int) async throws -> TMDBMovieDetail {
        try await get("/movie/\(id)", query: [])
    }

    func seasonDetail(tvID: Int, seasonNumber: Int) async throws -> TMDBSeasonDetail {
        try await get("/tv/\(tvID)/season/\(seasonNumber)", query: [])
    }

    func configuration() async throws -> TMDBConfigurationResponse {
        try await get("/configuration", query: [])
    }

    private func get<T: Decodable & Sendable>(
        _ path: String,
        query: [URLQueryItem]
    ) async throws -> T {
        guard !token.isEmpty else { throw TMDBError.notConfigured }

        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
            resolvingAgainstBaseURL: false
        ) else {
            throw TMDBError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "language", value: "zh-CN")
        ] + query

        guard let url = components.url else { throw TMDBError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw TMDBError.network("连接超时。")
            case .notConnectedToInternet:
                throw TMDBError.network("当前设备没有网络。")
            case .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                throw TMDBError.network("服务器无法访问。")
            default:
                throw TMDBError.network(error.localizedDescription)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TMDBError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw TMDBError.decoding(error.localizedDescription)
        }
    }
}
