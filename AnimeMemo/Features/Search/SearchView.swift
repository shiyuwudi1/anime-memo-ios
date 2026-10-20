import SwiftUI

struct SearchView: View {
    @State private var query = UserDefaults.standard.string(forKey: "searchQuery") ?? ""
    @State private var filter: SearchFilter = .all
    @State private var recentSearches = ["芙莉莲", "胆大党", "剧场版"]
    @State private var remoteResults: [MockAnime] = []
    @State private var remoteDiscover: [MockAnime] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didLoadDiscover = false

    private let client = TMDBClient.makeFromConfiguration()

    private var usesRemote: Bool {
        client != nil
    }

    private var results: [MockAnime] {
        if usesRemote {
            return remoteResults.filter { anime in
                switch filter {
                case .all: return true
                case .tv: return !anime.isMovie
                case .movie: return anime.isMovie
                }
            }
        }

        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        return MockAnime.all.filter { anime in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .tv: matchesFilter = !anime.isMovie
            case .movie: matchesFilter = anime.isMovie
            }

            let matchesQuery = anime.title.localizedCaseInsensitiveContains(normalized)
                || anime.originalTitle.localizedCaseInsensitiveContains(normalized)
            return matchesFilter && matchesQuery
        }
    }

    private var discoveryItems: [MockAnime] {
        usesRemote ? remoteDiscover : MockAnime.all
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GlassChipRow(spacing: 8) {
                        ForEach(SearchFilter.allCases) { item in
                            GlassChip(
                                title: item.title,
                                isSelected: filter == item
                            ) {
                                withAnimation(.snappy) {
                                    filter = item
                                }
                            }
                        }
                    }

                    if isLoading {
                        ProgressView("正在搜索 TMDB…")
                            .frame(maxWidth: .infinity, minHeight: 260)
                    } else if let errorMessage {
                        VStack(spacing: 14) {
                            ContentUnavailableView(
                                "加载失败",
                                systemImage: "wifi.exclamationmark",
                                description: Text(errorMessage)
                            )

                            Button("重试") {
                                Task { await performSearch() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                        }
                        .frame(minHeight: 280)
                    } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        discoveryContent
                    } else if results.isEmpty {
                        ContentUnavailableView(
                            "没有找到",
                            systemImage: "magnifyingglass",
                            description: Text("试试日文名或英文名。TMDB 的中文覆盖不一定完整。")
                        )
                        .frame(minHeight: 280)
                    } else {
                        resultsContent
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜索番剧、剧场版"
            )
            .navigationDestination(for: MockAnime.self) { anime in
                if anime.tmdbID != nil {
                    RemoteAnimeDetailLoader(summary: anime)
                } else {
                    AnimeDetailView(anime: anime)
                }
            }
            .task(id: query) {
                await performSearch()
            }
        }
    }

    private var discoveryContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("最近搜索")

                    GlassChipRow(spacing: 8) {
                        ForEach(recentSearches, id: \.self) { term in
                            GlassChip(title: term) {
                                query = term
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("本季热门")

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 18
                ) {
                    ForEach(discoveryItems) { anime in
                        NavigationLink(value: anime) {
                            VStack(alignment: .leading, spacing: 8) {
                                PosterArtwork(style: anime.poster, posterURL: anime.posterURL)
                                    .frame(height: 232)

                                Text(anime.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)

                                HStack(spacing: 6) {
                                    Text(anime.format)
                                    Text("·")
                                    Text(String(anime.year))
                                    Spacer(minLength: 0)
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(AppTheme.accent)
                                    Text(String(format: "%.1f", anime.score))
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var resultsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("\(results.count) 个结果")

            VStack(spacing: 0) {
                ForEach(results) { anime in
                    NavigationLink(value: anime) {
                        HStack(spacing: 14) {
                            PosterArtwork(style: anime.poster, posterURL: anime.posterURL, cornerRadius: 10, showsLabel: false)
                                .frame(width: 58, height: 82)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(anime.title)
                                    .font(.headline)
                                    .lineLimit(1)

                                Text(anime.originalTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    Text(anime.format)
                                    Text("·")
                                    Text(String(anime.year))
                                }
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            }

                            Spacer(minLength: 8)

                            VStack(alignment: .trailing, spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.accent)
                                Text(String(format: "%.1f", anime.score))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if anime.id != results.last?.id {
                        Divider()
                            .opacity(0.5)
                    }
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
    }

    @MainActor
    private func performSearch() async {
        guard let client else { return }

        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty {
            guard !didLoadDiscover else { return }
            didLoadDiscover = true
            isLoading = true
            errorMessage = nil

            do {
                let page = try await client.discoverAnime()
                remoteDiscover = map(page.results)
                isLoading = false
            } catch {
                didLoadDiscover = false
                isLoading = false
                errorMessage = error.localizedDescription
            }
            return
        }

        // Wait for the user to finish typing before hitting the API.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        isLoading = true
        errorMessage = nil

        do {
            let page = try await client.searchMulti(query: normalized)
            guard !Task.isCancelled else { return }
            remoteResults = map(page.results)
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            remoteResults = []
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func map(_ results: [TMDBMediaSummary]) -> [MockAnime] {
        results
            .filter { $0.isSupportedMedia && $0.isAnimation }
            .map(MockAnime.from(summary:))
    }
}

private enum SearchFilter: String, CaseIterable, Identifiable {
    case all
    case tv
    case movie

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .tv: return "TV"
        case .movie: return "剧场版"
        }
    }
}
