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

/// Availability of one metadata provider, as decided at app launch.
struct ProviderHealth: Sendable, Equatable, Identifiable {
    let provider: MetadataProvider
    /// `nil` means the latest probe succeeded.
    let failureReason: String?

    var id: String { provider.id }

    var isAvailable: Bool { failureReason == nil }

    static func probe(_ provider: MetadataProvider, timeout: TimeInterval? = nil) async -> ProviderHealth {
        do {
            _ = try await ProviderProbe.run(provider, timeout: timeout)
            return ProviderHealth(provider: provider, failureReason: nil)
        } catch {
            return ProviderHealth(provider: provider, failureReason: error.localizedDescription)
        }
    }

    /// Probes both sources concurrently so launch waits for the slowest one
    /// instead of the sum of both timeouts.
    static func probeAll(timeout: TimeInterval? = nil) async -> [ProviderHealth] {
        var byProvider: [MetadataProvider: ProviderHealth] = [:]
        for await health in probeUpdates(timeout: timeout) {
            byProvider[health.provider] = health
        }
        return MetadataProvider.allCases.compactMap { byProvider[$0] }
    }

    /// Emits each provider's health as soon as its probe settles, in
    /// completion order. The launch splash uses this to describe what it is
    /// still waiting for.
    static func probeUpdates(timeout: TimeInterval? = nil) -> AsyncStream<ProviderHealth> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: ProviderHealth.self) { group in
                    for provider in MetadataProvider.allCases {
                        group.addTask {
                            await probe(provider, timeout: timeout)
                        }
                    }

                    for await health in group {
                        continuation.yield(health)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Keeps the current choice when it responds, otherwise silently falls
    /// back to the other source. `nil` means neither source is usable.
    static func preferredProvider(
        from results: [ProviderHealth],
        current: MetadataProvider
    ) -> MetadataProvider? {
        let available = Set(results.filter(\.isAvailable).map(\.provider))
        if available.contains(current) { return current }
        return MetadataProvider.allCases.first { available.contains($0) }
    }
}

/// Lightweight connectivity check used by the launch gate and the settings
/// screen so the user can compare the TMDB reverse proxy with Bangumi.
enum ProviderProbe {
    static func run(
        _ provider: MetadataProvider,
        timeout: TimeInterval? = nil
    ) async throws -> ProviderProbeResult {
        let start = Date()
        let session = makeSession(timeout: timeout)

        let count: Int
        let title: String

        switch provider {
        case .tmdb:
            guard let client = TMDBClient.makeFromConfiguration(session: session) else {
                throw TMDBError.notConfigured
            }
            let page = try await client.discoverAnime()
            // `/discover/tv` omits `media_type`, so filter on genre only.
            let items = page.results.filter(\.isAnimation)
            count = items.count
            title = items.first?.displayTitle ?? "（空）"

        case .bangumi:
            let subjects = try await BangumiClient(session: session).discover(limit: 20)
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

    /// `nil` keeps the clients' built-in timeouts.
    private static func makeSession(timeout: TimeInterval?) -> URLSession? {
        guard let timeout else { return nil }
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}
