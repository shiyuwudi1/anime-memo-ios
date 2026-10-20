import Foundation

enum TMDBMediaType: String, Decodable, Sendable, Hashable {
    case tv
    case movie
}

struct TMDBPage<Result: Decodable & Sendable>: Decodable, Sendable {
    let page: Int
    let results: [Result]
    let totalPages: Int
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct TMDBMediaSummary: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let mediaTypeRaw: String?
    let title: String?
    let name: String?
    let originalTitle: String?
    let originalName: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let genreIDs: [Int]?
    let originalLanguage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mediaTypeRaw = "media_type"
        case title
        case name
        case originalTitle = "original_title"
        case originalName = "original_name"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case genreIDs = "genre_ids"
        case originalLanguage = "original_language"
    }

    var mediaType: TMDBMediaType? {
        mediaTypeRaw.flatMap(TMDBMediaType.init(rawValue:))
    }

    var displayTitle: String {
        title ?? name ?? originalTitle ?? originalName ?? "未命名"
    }

    var displayOriginalTitle: String? {
        originalTitle ?? originalName
    }

    var dateString: String? {
        releaseDate ?? firstAirDate
    }

    var year: String? {
        dateString.flatMap { $0.count >= 4 ? String($0.prefix(4)) : nil }
    }

    var isAnimation: Bool {
        genreIDs?.contains(16) ?? false
    }

    var isSupportedMedia: Bool {
        mediaType == .tv || mediaType == .movie
    }
}

struct TMDBGenre: Decodable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct TMDBNetwork: Decodable, Hashable, Sendable {
    let id: Int
    let name: String
    let logoPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case logoPath = "logo_path"
    }
}

struct TMDBProductionCompany: Decodable, Hashable, Sendable {
    let id: Int
    let name: String
    let logoPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case logoPath = "logo_path"
    }
}

struct TMDBSeasonSummary: Decodable, Identifiable, Hashable, Sendable {
    let seasonNumber: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let airDate: String?
    let episodeCount: Int

    var id: Int { seasonNumber }

    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
        case name
        case overview
        case posterPath = "poster_path"
        case airDate = "air_date"
        case episodeCount = "episode_count"
    }
}

struct TMDBEpisode: Decodable, Identifiable, Hashable, Sendable {
    let seasonNumber: Int
    let episodeNumber: Int
    let name: String
    let overview: String?
    let airDate: String?
    let stillPath: String?
    let runtime: Int?

    var id: String { "\(seasonNumber)-\(episodeNumber)" }

    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case name
        case overview
        case airDate = "air_date"
        case stillPath = "still_path"
        case runtime
    }
}

struct TMDBTVDetail: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let originalName: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let status: String
    let genres: [TMDBGenre]
    let networks: [TMDBNetwork]
    let numberOfSeasons: Int
    let numberOfEpisodes: Int
    let seasons: [TMDBSeasonSummary]
    let nextEpisodeToAir: TMDBEpisode?
    let lastEpisodeToAir: TMDBEpisode?
    let voteAverage: Double
    let originalLanguage: String

    var displayTitle: String { name }
    var displayOriginalTitle: String? {
        originalName.isEmpty ? nil : originalName
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case originalName = "original_name"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
        case status
        case genres
        case networks
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case seasons
        case nextEpisodeToAir = "next_episode_to_air"
        case lastEpisodeToAir = "last_episode_to_air"
        case voteAverage = "vote_average"
        case originalLanguage = "original_language"
    }
}

struct TMDBMovieDetail: Decodable, Identifiable, Sendable {
    let id: Int
    let title: String
    let originalTitle: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let runtime: Int?
    let status: String
    let genres: [TMDBGenre]
    let productionCompanies: [TMDBProductionCompany]
    let voteAverage: Double
    let originalLanguage: String

    var displayTitle: String { title }
    var displayOriginalTitle: String? {
        originalTitle.isEmpty ? nil : originalTitle
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case originalTitle = "original_title"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case runtime
        case status
        case genres
        case productionCompanies = "production_companies"
        case voteAverage = "vote_average"
        case originalLanguage = "original_language"
    }
}

struct TMDBSeasonDetail: Decodable, Identifiable, Sendable {
    let id: Int
    let seasonNumber: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let airDate: String?
    let episodes: [TMDBEpisode]

    enum CodingKeys: String, CodingKey {
        case id
        case seasonNumber = "season_number"
        case name
        case overview
        case posterPath = "poster_path"
        case airDate = "air_date"
        case episodes
    }
}

struct TMDBImageConfiguration: Decodable, Sendable {
    let baseURL: String
    let posterSizes: [String]
    let backdropSizes: [String]
    let stillSizes: [String]

    enum CodingKeys: String, CodingKey {
        case baseURL = "secure_base_url"
        case posterSizes = "poster_sizes"
        case backdropSizes = "backdrop_sizes"
        case stillSizes = "still_sizes"
    }
}

struct TMDBConfigurationResponse: Decodable, Sendable {
    let images: TMDBImageConfiguration
}

enum TMDBImage {
    private static let baseURL = URL(string: "https://image.tmdb.org/t/p/")!

    static func url(_ path: String?, size: String = "w500") -> URL? {
        guard let path else { return nil }
        return baseURL
            .appendingPathComponent(size, isDirectory: true)
            .appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }
}

enum TMDBDate {
    static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
