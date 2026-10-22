import SwiftUI

struct RemoteAnimeDetailLoader: View {
    @Environment(LibraryStore.self) private var library

    let summary: MockAnime

    @State private var loaded: MockAnime?
    @State private var errorMessage: String?

    private let client = TMDBClient.makeFromConfiguration()

    var body: some View {
        Group {
            if let loaded {
                AnimeDetailView(anime: loaded)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("加载失败", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("重试") {
                        Task { await load() }
                    }
                }
            } else {
                ProgressView("正在加载详情…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await load()
                    }
            }
        }
        .navigationTitle(summary.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func load() async {
        guard let client else {
            errorMessage = "TMDB API key 尚未配置。"
            return
        }
        guard let tmdbID = summary.tmdbID, let mediaType = summary.mediaType else {
            errorMessage = "作品信息不完整。"
            return
        }

        errorMessage = nil

        do {
            switch mediaType {
            case "movie":
                let detail = try await client.movieDetail(id: tmdbID)
                var item = MockAnime.from(movie: detail)
                applyStoreEntry(to: &item)
                loaded = item

            case "tv":
                let detail = try await client.tvDetail(id: tmdbID)
                guard let season = preferredSeason(for: detail) else {
                    errorMessage = "没有找到可播放的季信息。"
                    return
                }
                var item = MockAnime.from(
                    tv: detail,
                    season: season,
                    seasons: MockAnime.seasonOptions(from: detail)
                )
                applyStoreEntry(to: &item)
                loaded = item

            default:
                errorMessage = "不支持的媒体类型。"
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func preferredSeason(for detail: TMDBTVDetail) -> TMDBSeasonSummary? {
        // Every season keeps its own library entry, so prefer whatever the user
        // is actually watching right now.
        let trackedSeasons = library.entries
            .filter { $0.tmdbID == detail.id && $0.mediaType == "tv" }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status == .watching
                }
                return (lhs.seasonNumber ?? -1) > (rhs.seasonNumber ?? -1)
            }
            .compactMap(\.seasonNumber)

        for seasonNumber in trackedSeasons {
            if let season = detail.seasons.first(where: { $0.seasonNumber == seasonNumber }) {
                return season
            }
        }

        if let next = detail.nextEpisodeToAir,
           let season = detail.seasons.first(where: { $0.seasonNumber == next.seasonNumber }) {
            return season
        }

        return detail.seasons
            .filter { $0.seasonNumber > 0 && $0.episodeCount > 0 }
            .max(by: { $0.seasonNumber < $1.seasonNumber })
            ?? detail.seasons.first
    }

    private func applyStoreEntry(to item: inout MockAnime) {
        guard let entry = library.entry(for: item.id) else { return }
        item.progress = entry.progress
        item.status = entry.status
        item.isFavorite = entry.isFavorite
        item.userScore = entry.userScore
        item.notes = entry.notes
    }
}
