import SwiftUI

struct BangumiDetailLoader: View {
    @Environment(LibraryStore.self) private var library

    let summary: MockAnime

    @State private var loaded: MockAnime?
    @State private var errorMessage: String?

    private let client = BangumiClient()

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
                ProgressView("正在加载 Bangumi 详情…")
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
        guard let bangumiID = summary.bangumiID else {
            errorMessage = "Bangumi 作品信息不完整。"
            return
        }

        errorMessage = nil

        do {
            let detail = try await client.subject(id: bangumiID)
            let episodes = (try? await client.episodes(subjectID: bangumiID)) ?? []
            var item = MockAnime.from(bangumi: detail, episodes: episodes)
            applyStoreEntry(to: &item)
            loaded = item
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
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
