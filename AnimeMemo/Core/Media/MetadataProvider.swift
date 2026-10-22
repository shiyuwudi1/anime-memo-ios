import Foundation

enum MetadataProvider: String, CaseIterable, Identifiable, Sendable {
    case tmdb
    case bangumi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tmdb: return "TMDB"
        case .bangumi: return "Bangumi"
        }
    }

    var systemImage: String {
        switch self {
        case .tmdb: return "film.stack"
        case .bangumi: return "sparkles"
        }
    }

    var detail: String {
        switch self {
        case .tmdb:
            return "全球作品库，海报和分季信息更完整；中国大陆通常需要代理。"
        case .bangumi:
            return "中文动画条目和评分更贴近国内；无需代理，但没有 TMDB 式的自动分季聚合。"
        }
    }

    /// Short line used in empty/error states.
    var networkHint: String {
        switch self {
        case .tmdb:
            return "请检查网络或代理地址。"
        case .bangumi:
            return "请检查网络后重试。"
        }
    }
}
