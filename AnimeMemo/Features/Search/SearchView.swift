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
    @State private var isOffline = false
    @AppStorage("metadataProvider") private var providerRaw = MetadataProvider.tmdb.rawValue

    private let bangumiClient = BangumiClient()

    private var provider: MetadataProvider {
        MetadataProvider(rawValue: providerRaw) ?? .tmdb
    }

    private var tmdbClient: TMDBClient? {
        TMDBClient.makeFromConfiguration()
    }

    private var usesRemote: Bool {
        provider == .bangumi || AppConfiguration.isTMDBConfigured
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
        if usesRemote && !remoteDiscover.isEmpty {
            return remoteDiscover
        }
        return MockAnime.all
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if isOffline {
                        offlineBanner
                    }

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

                    if isLoading && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(spacing: 14) {
                            ProgressView("正在连接 \(provider.title)…")
                            Button("先看本地示例") {
                                useOfflineFallback()
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .buttonStyle(.plain)
                        }
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
                        if isLoading {
                            inlineLoadingBanner
                        }
                        discoveryContent
                    } else if results.isEmpty {
                        ContentUnavailableView(
                            "没有找到",
                            systemImage: "magnifyingglass",
                            description: Text(
                                provider == .bangumi
                                    ? "试试简体中文名、日文名或原名。"
                                    : "试试日文名或英文名。TMDB 的中文覆盖不一定完整。"
                            )
                        )
                        .frame(minHeight: 280)
                    } else {
                        resultsContent
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 120)
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
            .task(id: "\(providerRaw)|\(query)") {
                await performSearch()
            }
            .onChange(of: providerRaw) { _, _ in
                remoteResults = []
                remoteDiscover = []
                didLoadDiscover = false
                isOffline = false
                errorMessage = nil
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
                sectionTitle(provider == .bangumi ? "本季新番" : "本季热门")

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    spacing: 18
                ) {
                    ForEach(discoveryItems) { anime in
                        NavigationLink(destination: detailDestination(for: anime)) {
                            VStack(alignment: .leading, spacing: 8) {
                                PosterArtwork(
                                    style: anime.poster,
                                    posterURL: anime.posterURL,
                                    placeholderTitle: anime.title
                                )
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
                    NavigationLink(destination: detailDestination(for: anime)) {
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

    private var inlineLoadingBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("正在连接 \(provider.title)，先显示本地示例…")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("跳过") {
                useOfflineFallback()
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private var offlineBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(provider.title) 暂不可用")
                    .font(.caption.weight(.semibold))
                Text("当前显示本地示例。\(provider.networkHint)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button("重试") {
                retryLoading()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .buttonStyle(.plain)
        }
        .padding(12)
        .glassSurface(.rect(cornerRadius: 16), variant: .regular)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
    }

    private func localResults(for query: String) -> [MockAnime] {
        MockAnime.all.filter { anime in
            anime.title.localizedCaseInsensitiveContains(query)
                || anime.originalTitle.localizedCaseInsensitiveContains(query)
        }
    }

    private func retryLoading() {
        isOffline = false
        didLoadDiscover = false
        errorMessage = nil
        Task {
            await performSearch()
        }
    }

    private func useOfflineFallback() {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        remoteDiscover = MockAnime.all
        if !normalized.isEmpty {
            remoteResults = localResults(for: normalized)
        }
        isOffline = true
        isLoading = false
        errorMessage = nil
    }

    @ViewBuilder
    private func detailDestination(for anime: MockAnime) -> some View {
        if anime.bangumiID != nil {
            BangumiDetailLoader(summary: anime)
        } else if anime.tmdbID != nil {
            RemoteAnimeDetailLoader(summary: anime)
        } else {
            AnimeDetailView(anime: anime)
        }
    }

    @MainActor
    private func performSearch() async {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty {
            guard !didLoadDiscover else { return }
            didLoadDiscover = true
            isLoading = true
            errorMessage = nil

            do {
                let items: [MockAnime]
                switch provider {
                case .tmdb:
                    guard let client = tmdbClient else {
                        throw TMDBError.notConfigured
                    }
                    let page = try await client.discoverAnime()
                    items = map(page.results, defaultMediaType: .tv)
                case .bangumi:
                    let subjects = try await bangumiClient.discover()
                    items = subjects.map { MockAnime.from(bangumi: $0) }
                }
                guard !Task.isCancelled else { return }
                remoteDiscover = items
                isOffline = false
                isLoading = false
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                didLoadDiscover = false
                remoteDiscover = MockAnime.all
                isOffline = true
                isLoading = false
                errorMessage = nil
            }
            return
        }

        // Wait for the user to finish typing before hitting the API.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        isLoading = true
        errorMessage = nil

        do {
            let items: [MockAnime]
            switch provider {
            case .tmdb:
                guard let client = tmdbClient else {
                    throw TMDBError.notConfigured
                }
                let page = try await client.searchMulti(query: normalized)
                items = map(page.results)
            case .bangumi:
                let subjects = try await bangumiClient.search(query: normalized)
                items = subjects.map { MockAnime.from(bangumi: $0) }
            }
            guard !Task.isCancelled else { return }
            remoteResults = items
            isOffline = false
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            remoteResults = localResults(for: normalized)
            isOffline = true
            isLoading = false
            errorMessage = nil
        }
    }

    private func map(
        _ results: [TMDBMediaSummary],
        defaultMediaType: TMDBMediaType? = nil
    ) -> [MockAnime] {
        results.compactMap { summary in
            guard
                let type = summary.resolvedMediaType(default: defaultMediaType),
                summary.isAnimation
            else {
                return nil
            }
            return MockAnime.from(summary: summary, mediaType: type)
        }
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
