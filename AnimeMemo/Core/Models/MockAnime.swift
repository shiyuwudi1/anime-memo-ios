import SwiftUI

enum LibraryStatus: String, CaseIterable, Identifiable, Hashable, Codable {
    case watching
    case planning
    case completed
    case paused
    case dropped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .watching: return "在看"
        case .planning: return "想看"
        case .completed: return "看过"
        case .paused: return "搁置"
        case .dropped: return "弃番"
        }
    }

    var systemImage: String {
        switch self {
        case .watching: return "play.fill"
        case .planning: return "bookmark.fill"
        case .completed: return "checkmark.circle.fill"
        case .paused: return "pause.fill"
        case .dropped: return "xmark.circle.fill"
        }
    }
}

struct MockAnime: Identifiable, Hashable, Codable {
    var id: String
    var title: String
    var originalTitle: String
    var seasonLabel: String
    var progress: Int
    var total: Int
    var nextEpisode: String?
    var nextEpisodeDateString: String? = nil
    var score: Double
    var format: String
    var year: Int
    var genres: [String]
    var synopsis: String
    var poster: PosterStyle
    var status: LibraryStatus
    var isFavorite: Bool = false
    var userScore: Double? = nil
    var notes: String = ""
    var isMovie: Bool = false
    var runtime: Int = 24
    var tmdbID: Int?
    var mediaType: String?
    var seasonNumber: Int?
    var posterURL: URL?

    var progressText: String {
        isMovie ? (progress >= 1 ? "已看完" : "未看") : "第 \(progress) 话 / 共 \(total) 话"
    }

    var progressFraction: Double {
        guard total > 0 else { return 0 }
        return min(Double(progress) / Double(total), 1)
    }

    var isAiringToday: Bool {
        guard let nextEpisodeDateString else {
            // Mock entries have a display-only next episode.
            return nextEpisode != nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return nextEpisodeDateString == formatter.string(from: .now)
    }

    static let frieren = MockAnime(
        id: "frieren-s2",
        title: "葬送的芙莉莲",
        originalTitle: "Sousou no Frieren",
        seasonLabel: "第 2 季",
        progress: 5,
        total: 12,
        nextEpisode: "今天更新",
        score: 9.2,
        format: "TV",
        year: 2026,
        genres: ["奇幻", "冒险", "治愈"],
        synopsis: "在勇者一行击败魔王之后，精灵魔法使芙莉莲踏上了重新理解人类、记住同伴的旅程。时间对她而言近乎无限，而每一次相遇都变得格外珍贵。",
        poster: .frieren,
        status: .watching,
        posterURL: TMDBImage.url("/1TtrtRIwXz5BB0gXEl8zgBypl9c.jpg")
    )

    static let dandadan = MockAnime(
        id: "dandadan-s2",
        title: "胆大党",
        originalTitle: "Dandadan",
        seasonLabel: "第 2 季",
        progress: 0,
        total: 12,
        nextEpisode: "周五更新",
        score: 8.7,
        format: "TV",
        year: 2026,
        genres: ["超自然", "喜剧", "战斗"],
        synopsis: "相信幽灵的少女与相信外星人的少年，在一场荒诞的赌局后一起被卷入超自然事件。战斗、搞笑和青春，全都不讲道理地混在一起。",
        poster: .dandadan,
        status: .planning,
        posterURL: TMDBImage.url("/dRNNUYCJB9gACxqiIbbDLOkpFB2.jpg")
    )

    static let apothecary = MockAnime(
        id: "apothecary-s2",
        title: "药屋少女的呢喃",
        originalTitle: "Kusuriya no Hitorigoto",
        seasonLabel: "第 2 季",
        progress: 24,
        total: 24,
        nextEpisode: nil,
        score: 8.9,
        format: "TV",
        year: 2025,
        genres: ["古风", "推理", "宫廷"],
        synopsis: "在后宫做杂役的少女猫猫，凭借对药理的狂热与敏锐的观察力，卷入了宫廷里一桩又一桩谜案。",
        poster: .apothecary,
        status: .completed,
        posterURL: TMDBImage.url("/nUFTbH417TqmCbw2b2mPSAESoTb.jpg")
    )

    static let spy = MockAnime(
        id: "spy-s3",
        title: "间谍过家家",
        originalTitle: "SPY×FAMILY",
        seasonLabel: "第 3 季",
        progress: 8,
        total: 12,
        nextEpisode: "周六更新",
        score: 8.3,
        format: "TV",
        year: 2026,
        genres: ["喜剧", "动作", "日常"],
        synopsis: "间谍、杀手和超能力少女组成了一个假家庭。任务之外，他们正在认真经营一段真实的亲子关系。",
        poster: .spy,
        status: .paused,
        posterURL: TMDBImage.url("/xkEGd9GF3oty89xDiXMGJm6pGQL.jpg")
    )

    static let solo = MockAnime(
        id: "solo-s2",
        title: "我独自升级",
        originalTitle: "Solo Leveling",
        seasonLabel: "第 2 季",
        progress: 3,
        total: 13,
        nextEpisode: "今天更新",
        score: 8.1,
        format: "TV",
        year: 2026,
        genres: ["战斗", "奇幻", "成长"],
        synopsis: "从最弱猎人开始，成振宇在一次次生死边缘的挑战中不断变强，也逐渐触碰到这个世界真正的规则。",
        poster: .solo,
        status: .watching,
        posterURL: TMDBImage.url("/9vAmQQD1Ewus7kqwsGgeoM7sjE6.jpg")
    )

    static let lookback = MockAnime(
        id: "lookback-movie",
        title: "蓦然回首",
        originalTitle: "Look Back",
        seasonLabel: "剧场版",
        progress: 1,
        total: 1,
        nextEpisode: nil,
        score: 9.0,
        format: "剧场版",
        year: 2024,
        genres: ["青春", "创作", "剧情"],
        synopsis: "两个热爱画漫画的女孩，在相遇、竞争与分离之间，走过了漫长的时间。画画是她们表达世界的方式，也是她们彼此连接的方式。",
        poster: .lookback,
        status: .completed,
        isMovie: true,
        runtime: 58,
        posterURL: TMDBImage.url("/5WhrCOmnZXoW8ku7XxT6zkI88zS.jpg")
    )

    static let library: [MockAnime] = [
        .frieren,
        .solo,
        .spy,
        .dandadan,
        .apothecary,
        .lookback
    ]

    static let all: [MockAnime] = library

    static var debugRemoteFrieren: MockAnime {
        from(summary: TMDBMediaSummary(
            id: 209867,
            mediaTypeRaw: "tv",
            title: "葬送的芙莉莲",
            name: nil,
            originalTitle: nil,
            originalName: "葬送のフリーレン",
            overview: nil,
            posterPath: nil,
            backdropPath: nil,
            releaseDate: nil,
            firstAirDate: "2023-09-29",
            voteAverage: 8.8,
            genreIDs: [16],
            originalLanguage: "ja"
        ))
    }

    static func from(summary: TMDBMediaSummary) -> MockAnime {
        let isMovie = summary.mediaType == .movie
        let type = summary.mediaType ?? .tv
        return MockAnime(
            id: "\(type.rawValue)-\(summary.id)",
            title: summary.displayTitle,
            originalTitle: summary.displayOriginalTitle ?? "",
            seasonLabel: isMovie ? "剧场版" : "TV",
            progress: 0,
            total: 0,
            nextEpisode: nil,
            score: summary.voteAverage ?? 0,
            format: isMovie ? "剧场版" : "TV",
            year: year(from: summary.dateString),
            genres: [],
            synopsis: summary.overview ?? "",
            poster: fallbackPoster(for: summary.id),
            status: .planning,
            isMovie: isMovie,
            runtime: isMovie ? 0 : 24,
            tmdbID: summary.id,
            mediaType: type.rawValue,
            seasonNumber: nil,
            posterURL: TMDBImage.url(summary.posterPath, size: "w500")
        )
    }

    static func from(tv detail: TMDBTVDetail, season: TMDBSeasonSummary) -> MockAnime {
        let seasonLabel = season.seasonNumber == 0 ? "特别篇/OVA" : "第 \(season.seasonNumber) 季"
        let nextDateString = detail.nextEpisodeToAir?.seasonNumber == season.seasonNumber
            ? detail.nextEpisodeToAir?.airDate
            : nil
        return MockAnime(
            id: "tv-\(detail.id)-s\(season.seasonNumber)",
            title: detail.displayTitle,
            originalTitle: detail.displayOriginalTitle ?? "",
            seasonLabel: seasonLabel,
            progress: 0,
            total: season.episodeCount,
            nextEpisode: nextEpisodeText(for: detail, season: season),
            nextEpisodeDateString: nextDateString,
            score: detail.voteAverage,
            format: "TV",
            year: year(from: detail.firstAirDate),
            genres: detail.genres.map(\.name),
            synopsis: detail.overview ?? "",
            poster: fallbackPoster(for: detail.id),
            status: .planning,
            isMovie: false,
            runtime: 24,
            tmdbID: detail.id,
            mediaType: "tv",
            seasonNumber: season.seasonNumber,
            posterURL: TMDBImage.url(season.posterPath ?? detail.posterPath, size: "w500")
        )
    }

    static func from(movie detail: TMDBMovieDetail) -> MockAnime {
        MockAnime(
            id: "movie-\(detail.id)",
            title: detail.displayTitle,
            originalTitle: detail.displayOriginalTitle ?? "",
            seasonLabel: "剧场版",
            progress: 0,
            total: 1,
            nextEpisode: nil,
            score: detail.voteAverage,
            format: "剧场版",
            year: year(from: detail.releaseDate),
            genres: detail.genres.map(\.name),
            synopsis: detail.overview ?? "",
            poster: fallbackPoster(for: detail.id),
            status: .planning,
            isMovie: true,
            runtime: detail.runtime ?? 0,
            tmdbID: detail.id,
            mediaType: "movie",
            seasonNumber: nil,
            posterURL: TMDBImage.url(detail.posterPath, size: "w500")
        )
    }

    private static func fallbackPoster(for id: Int) -> PosterStyle {
        let styles = PosterStyle.allCases
        guard !styles.isEmpty else { return .frieren }
        return styles[abs(id) % styles.count]
    }

    private static func year(from dateString: String?) -> Int {
        guard let dateString, dateString.count >= 4 else { return 0 }
        return Int(dateString.prefix(4)) ?? 0
    }

    private static func nextEpisodeText(for detail: TMDBTVDetail, season: TMDBSeasonSummary) -> String? {
        guard
            let next = detail.nextEpisodeToAir,
            next.seasonNumber == season.seasonNumber,
            let dateString = next.airDate
        else {
            return nil
        }

        let localCalendarFormatter = DateFormatter()
        localCalendarFormatter.locale = Locale(identifier: "en_US_POSIX")
        localCalendarFormatter.timeZone = .current
        localCalendarFormatter.dateFormat = "yyyy-MM-dd"

        if dateString == localCalendarFormatter.string(from: .now) {
            return "第 \(next.episodeNumber) 话 · 今天更新"
        }

        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.timeZone = TimeZone(secondsFromGMT: 0)
        input.dateFormat = "yyyy-MM-dd"

        guard let date = input.date(from: dateString) else { return nil }

        let output = DateFormatter()
        output.locale = Locale(identifier: "zh_CN")
        output.timeZone = TimeZone(secondsFromGMT: 0)
        output.dateFormat = "M月d日"
        return "第 \(next.episodeNumber) 话 · \(output.string(from: date))"
    }
}
