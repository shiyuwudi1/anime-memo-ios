import Foundation

struct BangumiSearchResponse: Decodable, Sendable {
    let data: [BangumiSubject]
    let total: Int?
}

struct BangumiSubject: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let nameCN: String?
    let summary: String?
    let images: BangumiImages?
    let rating: BangumiRating?
    let date: String?
    let airDate: String?
    let platform: String?
    let eps: Int?
    let totalEpisodes: Int?
    let type: Int?
    let metaTags: [String]?
    let tags: [BangumiTag]?
    let nsfw: Bool?

    var displayTitle: String {
        if let nameCN, !nameCN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nameCN
        }
        return name
    }

    var displayOriginalTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == displayTitle ? "" : trimmed
    }

    var displaySummary: String {
        let trimmed = (summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "暂无简介。" : trimmed
    }

    var posterURL: URL? {
        guard let raw = images?.large ?? images?.common ?? images?.medium else { return nil }
        let normalized = raw.replacingOccurrences(of: "http://", with: "https://")
        return URL(string: normalized)
    }

    var year: Int {
        guard let value = date ?? airDate, value.count >= 4 else { return 0 }
        return Int(value.prefix(4)) ?? 0
    }

    var isMovie: Bool {
        // Search results sometimes omit `platform`, but keep the tag around.
        let value = [platform ?? "", (metaTags ?? []).joined(separator: " ")]
            .joined(separator: " ")
        return value.contains("剧场版") || value.contains("电影")
    }

    var episodeCount: Int? {
        if let eps, eps > 0 { return eps }
        if let totalEpisodes, totalEpisodes > 0 { return totalEpisodes }
        return nil
    }

    var displayFormat: String {
        let value = platform?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !value.isEmpty { return value }
        return isMovie ? "剧场版" : "TV"
    }

    var displayGenres: [String] {
        let preferred = (metaTags ?? []).filter {
            !["TV", "WEB", "OVA", "日本", "中国", "美国"].contains($0)
        }
        if !preferred.isEmpty { return Array(preferred.prefix(4)) }
        return Array((tags ?? []).map(\.name).prefix(4))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameCN = "name_cn"
        case summary
        case images
        case rating
        case date
        case airDate = "air_date"
        case platform
        case eps
        case totalEpisodes = "total_episodes"
        case type
        case metaTags = "meta_tags"
        case tags
        case nsfw
    }
}

struct BangumiImages: Decodable, Hashable, Sendable {
    let small: String?
    let grid: String?
    let large: String?
    let medium: String?
    let common: String?
}

struct BangumiRating: Decodable, Hashable, Sendable {
    let score: Double?
}

struct BangumiTag: Decodable, Hashable, Sendable {
    let name: String
}

struct BangumiCalendarDay: Decodable, Sendable {
    let weekday: BangumiWeekday?
    let items: [BangumiSubject]
}

struct BangumiWeekday: Decodable, Sendable {
    /// 1 = Monday … 7 = Sunday.
    let id: Int?
    let cn: String?
}

struct BangumiEpisode: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let subjectID: Int
    let name: String?
    let nameCN: String?
    let airdate: String?
    let ep: Int?
    let sort: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case subjectID = "subject_id"
        case name
        case nameCN = "name_cn"
        case airdate
        case ep
        case sort
    }
}

struct BangumiSearchRequest: Encodable, Sendable {
    let keyword: String
    let filter: Filter

    struct Filter: Encodable, Sendable {
        let type: [Int]
        let nsfw: Bool
    }
}
