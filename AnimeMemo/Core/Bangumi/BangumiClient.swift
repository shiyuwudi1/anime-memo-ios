import Foundation

enum BangumiError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case rateLimited
    case network(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Bangumi 请求地址无效。"
        case .invalidResponse:
            return "Bangumi 返回了无法识别的响应。"
        case .httpStatus(let code):
            return "Bangumi 请求失败（HTTP \(code)）。"
        case .rateLimited:
            return "Bangumi 请求过于频繁，请稍后再试。"
        case .network(let message):
            return "无法连接 Bangumi。\(message)"
        case .decoding(let message):
            return "Bangumi 数据解析失败：\(message)"
        }
    }
}

actor BangumiClient {
    private let session: URLSession
    private let baseURL: URL
    private let userAgent = "AnimeMemo/0.1 (https://shiyuwudi1.github.io/anime-memo-ios/)"
    private let decoder = JSONDecoder()

    init(session: URLSession? = nil, baseURL: URL = URL(string: "https://api.bgm.tv")!) {
        self.baseURL = baseURL

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 12
            configuration.timeoutIntervalForResource = 24
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    /// Today's airing shows first, then the rest of the week.
    func discover(limit: Int = 20) async throws -> [BangumiSubject] {
        let days = try await calendar()
        let ordered = orderedDays(days)
        var seen = Set<Int>()
        let items = ordered
            .flatMap(\.items)
            .filter { seen.insert($0.id).inserted }

        return Array(items.prefix(limit))
    }

    func calendar() async throws -> [BangumiCalendarDay] {
        let endpoint = baseURL.appendingPathComponent("calendar")
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return try await send(request)
    }

    func search(query: String, limit: Int = 20) async throws -> [BangumiSubject] {
        let endpoint = baseURL.appendingPathComponent("v0/search/subjects")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let body = BangumiSearchRequest(
            keyword: query,
            filter: .init(type: [2], nsfw: false)
        )
        request.httpBody = try JSONEncoder().encode(body)

        let response: BangumiSearchResponse = try await send(request)
        return Array(response.data.prefix(limit))
    }

    func subject(id: Int) async throws -> BangumiSubject {
        let endpoint = baseURL.appendingPathComponent("v0/subjects/\(id)")
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return try await send(request)
    }

    func episodes(subjectID: Int) async throws -> [BangumiEpisode] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("v0/episodes"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "subject_id", value: String(subjectID)),
            URLQueryItem(name: "type", value: "0"),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "offset", value: "0")
        ]
        guard let url = components?.url else { throw BangumiError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let response: BangumiEpisodePage = try await send(request)
        return response.data
    }

    private func orderedDays(_ days: [BangumiCalendarDay]) -> [BangumiCalendarDay] {
        guard !days.isEmpty else { return [] }

        // `Calendar` uses 1 = Sunday, Bangumi uses 1 = Monday.
        let weekday = Calendar.current.component(.weekday, from: .now)
        let bangumiWeekday = (weekday + 5) % 7 + 1

        guard let index = days.firstIndex(where: { $0.weekday?.id == bangumiWeekday }) else {
            return days
        }

        return Array(days[index...]) + Array(days[..<index])
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw BangumiError.network("连接超时。")
            case .notConnectedToInternet:
                throw BangumiError.network("当前设备没有网络。")
            case .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                throw BangumiError.network("服务器无法访问。")
            default:
                throw BangumiError.network(error.localizedDescription)
            }
        }

        guard let http = response as? HTTPURLResponse else {
            throw BangumiError.invalidResponse
        }
        if http.statusCode == 429 {
            throw BangumiError.rateLimited
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BangumiError.httpStatus(http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw BangumiError.decoding(error.localizedDescription)
        }
    }
}

private struct BangumiEpisodePage: Decodable, Sendable {
    let data: [BangumiEpisode]
}
