import Foundation

struct ProviderProbeResult: Sendable, Equatable {
    let provider: MetadataProvider
    let latency: TimeInterval
    let sampleCount: Int
    let sampleTitle: String

    var latencyText: String {
        String(format: "%.2f s", latency)
    }

    var summary: String {
        "\(provider.title) 连接正常 · \(latencyText) · \(sampleCount) 条结果"
    }
}

/// Lightweight connectivity check used by the settings screen so the user can
/// compare the TMDB reverse proxy with Bangumi side by side.
enum ProviderProbe {
    static func run(_ provider: MetadataProvider) async throws -> ProviderProbeResult {
        let start = Date()

        let count: Int
        let title: String

        switch provider {
        case .tmdb:
            guard let client = TMDBClient.makeFromConfiguration() else {
                throw TMDBError.notConfigured
            }
            let page = try await client.discoverAnime()
            // `/discover/tv` omits `media_type`, so filter on genre only.
            let items = page.results.filter(\.isAnimation)
            count = items.count
            title = items.first?.displayTitle ?? "（空）"

        case .bangumi:
            let subjects = try await BangumiClient().discover(limit: 20)
            count = subjects.count
            title = subjects.first?.displayTitle ?? "（空）"
        }

        return ProviderProbeResult(
            provider: provider,
            latency: Date().timeIntervalSince(start),
            sampleCount: count,
            sampleTitle: title
        )
    }
}
