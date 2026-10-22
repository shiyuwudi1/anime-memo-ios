import SwiftUI

struct AnimeDetailView: View {
    @Environment(LibraryStore.self) private var library

    let anime: MockAnime

    @State private var progress: Int
    @State private var selectedSeasonNumber: Int?
    @State private var isFavorite = false
    @State private var status: LibraryStatus
    @State private var userScore: Double?
    @State private var notes: String
    @State private var isSynopsisExpanded = false
    @State private var showEditSheet = false
    @State private var toast: DetailToast?
    @State private var topPull: CGFloat = 0

    private static let heroBaseHeight: CGFloat = 320

    init(anime: MockAnime) {
        self.anime = anime
        _progress = State(initialValue: anime.progress)
        _selectedSeasonNumber = State(initialValue: Self.defaultSeasonNumber(for: anime))
        _status = State(initialValue: anime.status)
        _userScore = State(initialValue: anime.userScore)
        _notes = State(initialValue: anime.notes)
    }

    private static func defaultSeasonNumber(for anime: MockAnime) -> Int? {
        if let seasonNumber = anime.seasonNumber {
            return seasonNumber
        }
        return anime.seasons.first(where: { $0.number > 0 })?.number
            ?? anime.seasons.first?.number
    }

    private var current: MockAnime {
        guard
            let seasonNumber = selectedSeasonNumber,
            let option = anime.seasons.first(where: { $0.number == seasonNumber })
        else {
            return anime
        }
        return anime.scoped(to: option)
    }

    private var total: Int { max(current.total, 1) }

    /// Shows the stored progress of seasons that were already started, so it is
    /// obvious every season tracks its own episodes.
    private func seasonChipTitle(for option: SeasonOption) -> String {
        guard
            let tmdbID = anime.tmdbID,
            let entry = library.entry(
                tmdbID: tmdbID,
                mediaType: anime.mediaType ?? "tv",
                seasonNumber: option.number
            ),
            entry.progress > 0
        else {
            return option.name
        }

        let episodeTotal = max(option.episodeCount, 1)
        return "\(option.name) \(min(entry.progress, episodeTotal))/\(episodeTotal)"
    }

    private var fraction: Double { min(Double(progress) / Double(total), 1) }
    private var isInLibrary: Bool { library.entry(for: current.id) != nil }

    private var progressLabel: String {
        if current.isMovie {
            return progress >= 1 ? "已看完" : "未看"
        }
        return "第 \(progress) 话 / 共 \(total) 话"
    }

    var body: some View {
        GeometryReader { proxy in
            page(topInset: proxy.safeAreaInsets.top)
        }
    }

    private func page(topInset: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero(topInset: topInset)
                seasonPicker
                progressCard
                synopsisCard
                metadataCard
            }
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
        } action: { _, newValue in
            topPull = newValue
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) {
                        isFavorite.toggle()
                    }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? AppTheme.accent : .primary)
                }
                .accessibilityLabel(isFavorite ? "取消收藏" : "收藏")
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .sheet(isPresented: $showEditSheet) {
            EditEntrySheet(anime: editableSnapshot) { newStatus, newProgress, newScore, newNotes, newFavorite in
                status = newStatus
                progress = newProgress
                userScore = newScore
                notes = newNotes
                isFavorite = newFavorite
                persistEntry(force: true)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                GlassToast(
                    message: toast.text,
                    actionTitle: toast.undo == nil ? nil : "撤销",
                    action: toast.undo
                )
                .padding(.bottom, 142)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: toast?.id)
        .task(id: toast?.id) {
            guard let toastID = toast?.id else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, toast?.id == toastID else { return }
            withAnimation {
                toast = nil
            }
        }
        .onAppear {
            syncFromStore()
        }
        .onChange(of: progress) { _, _ in
            persistEntry()
        }
        .onChange(of: isFavorite) { _, _ in
            persistEntry()
        }
        .onChange(of: selectedSeasonNumber) { _, _ in
            toast = nil
            isSynopsisExpanded = false
            syncFromStore()
        }
    }

    private func hero(topInset: CGFloat) -> some View {
        // The hero is full bleed: it reaches under the status bar and
        // navigation bar, so there is never an empty strip above it.
        let height = Self.heroBaseHeight + topInset
        // Scaling proportionally from the bottom keeps the hero's aspect
        // ratio intact while its top edge stays pinned to the screen edge
        // during pull-to-overscroll. The extra width is clipped by the
        // scroll view, so the image never distorts or leaves a gap.
        let stretchScale = (height + topPull) / height

        return ZStack(alignment: .bottomLeading) {
            PosterArtwork(style: current.poster, posterURL: current.posterURL, cornerRadius: 0, showsLabel: false)
                .frame(height: height)
                .clipped()
                .scaleEffect(stretchScale, anchor: .bottom)

            LinearGradient(
                colors: [.clear, Color(uiColor: .systemBackground).opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: height)

            HStack(alignment: .bottom, spacing: 16) {
                PosterArtwork(
                    style: current.poster,
                    posterURL: current.posterURL,
                    placeholderTitle: current.title
                )
                .frame(width: 108, height: 158)
                .shadow(color: .black.opacity(0.28), radius: 18, y: 10)

                VStack(alignment: .leading, spacing: 7) {
                    Text(current.seasonLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent, in: Capsule())

                    Text(current.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(current.originalTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(String(format: "%.1f", current.score), systemImage: "star.fill")
                        Text("·")
                        Text(String(current.year))
                        Text("·")
                        Text(current.format)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 6)
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 18)
        }
    }

    @ViewBuilder
    private var seasonPicker: some View {
        // Bangumi has no season hierarchy; the platform is already in the hero.
        if !current.isMovie && current.bangumiID == nil {
            VStack(alignment: .leading, spacing: 10) {
                Text("季")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if current.seasons.isEmpty {
                    Text(current.seasonLabel)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .glassSurface(
                            .capsule,
                            variant: .tinted(AppTheme.accent.opacity(0.62)),
                            interactive: false
                        )
                } else {
                    ScrollView(.horizontal) {
                        GlassChipRow(spacing: 8) {
                            ForEach(anime.seasons) { option in
                                GlassChip(
                                    title: seasonChipTitle(for: option),
                                    isSelected: selectedSeasonNumber == option.number
                                ) {
                                    withAnimation(.snappy) {
                                        selectedSeasonNumber = option.number
                                    }
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, AppTheme.pagePadding)
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("我的进度")
                    .font(.headline)

                Spacer()

                Text(progressLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: fraction)
                .tint(AppTheme.accent)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

            HStack(spacing: 12) {
                Text(current.isMovie ? "看完就是 1 话" : "看到第 \(progress) 话")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                GlassButton(emphasis: .prominent) {
                    increment()
                } label: {
                    Text("+1")
                        .font(.subheadline.weight(.bold))
                }
                .disabled(progress >= total)
                .opacity(progress >= total ? 0.55 : 1)
            }

            if !isInLibrary {
                Button {
                    addToLibrary(status: .planning)
                } label: {
                    Label("加入想看", systemImage: "bookmark")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(.plain)
            }

            if let userScore {
                HStack(spacing: 6) {
                    Text("我的评分")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                    Text(String(format: "%.1f", userScore))
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.74))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.8)
                }
        }
        .padding(.horizontal, AppTheme.pagePadding)
    }

    private var synopsisCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("简介")
                .font(.headline)

            ExpandableSynopsis(
                text: current.synopsis,
                isExpanded: $isSynopsisExpanded
            )
        }
        .padding(.horizontal, AppTheme.pagePadding)
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("作品信息")
                .font(.headline)

            infoRow("类型", current.genres.joined(separator: " / "))
            infoRow("格式", current.format)
            infoRow("首播", String(current.year))
            infoRow("时长", current.isMovie ? "\(current.runtime) 分钟" : "\(current.runtime) 分钟 / 话")
            infoRow("下一话", current.nextEpisode ?? "暂无")
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.52))
        }
        .padding(.horizontal, AppTheme.pagePadding)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }

    private var actionBar: some View {
        GlassBar {
            Button {
                withAnimation(.snappy) {
                    isFavorite.toggle()
                }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isFavorite ? AppTheme.accent : .primary)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "取消收藏" : "收藏")

            Spacer(minLength: 4)

            Button {
                increment()
            } label: {
                Label(progress >= total ? "已看完" : "第 \(min(progress + 1, total)) 话", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(AppTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(progress >= total)
            .opacity(progress >= total ? 0.55 : 1)

            Button {
                showEditSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑条目")
        }
    }

    private func increment() {
        guard progress < total else { return }
        let previous = progress
        progress = min(progress + 1, total)

        if status == .planning {
            status = .watching
        }
        if progress >= total {
            status = .completed
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            toast = DetailToast(
                text: progress >= total
                    ? "《\(current.title)》已看完"
                    : "已记录《\(current.title)》第 \(progress) 话"
            ) {
                progress = previous
                if previous == 0 {
                    status = .planning
                } else if previous < total {
                    status = .watching
                }
                withAnimation {
                    toast = nil
                }
            }
        }
    }

    private var editableSnapshot: MockAnime {
        var copy = current
        copy.progress = progress
        copy.status = status
        copy.userScore = userScore
        copy.notes = notes
        copy.isFavorite = isFavorite
        return copy
    }

    private func addToLibrary(status newStatus: LibraryStatus) {
        status = newStatus
        progress = 0
        persistEntry(force: true)

        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            toast = DetailToast(
                text: newStatus == .planning
                    ? "《\(current.title)》已加入想看"
                    : "《\(current.title)》已加入在看"
            )
        }
    }

    private func syncFromStore() {
        guard let entry = library.entry(for: current.id) else {
            progress = 0
            isFavorite = false
            status = .planning
            userScore = nil
            notes = ""
            return
        }
        progress = min(entry.progress, total)
        isFavorite = entry.isFavorite
        status = entry.status
        userScore = entry.userScore
        notes = entry.notes
    }

    private func persistEntry(force: Bool = false) {
        let alreadyInLibrary = library.entry(for: current.id) != nil
        guard force || alreadyInLibrary || progress > 0 || isFavorite else { return }

        var updated = current
        updated.progress = min(progress, total)
        updated.isFavorite = isFavorite
        updated.status = status
        updated.userScore = userScore
        updated.notes = notes

        if progress >= total {
            updated.status = .completed
        } else if updated.status == .planning && progress > 0 {
            updated.status = .watching
        }

        library.upsert(updated)
    }
}

private struct DetailToast: Identifiable {
    let id = UUID()
    let text: String
    var undo: (() -> Void)? = nil
}


private struct SynopsisMetrics: Equatable {
    var collapsed: CGFloat = 0
    var full: CGFloat = 0
}

private struct SynopsisMetricsKey: PreferenceKey {
    static let defaultValue = SynopsisMetrics()

    static func reduce(value: inout SynopsisMetrics, nextValue: () -> SynopsisMetrics) {
        let next = nextValue()
        value.collapsed = max(value.collapsed, next.collapsed)
        value.full = max(value.full, next.full)
    }
}

private struct ExpandableSynopsis: View {
    let text: String
    @Binding var isExpanded: Bool

    @State private var metrics = SynopsisMetrics()

    private let lineLimit = 4

    /// Only offer the toggle when the text really overflows the collapsed
    /// line limit; short synopses stay plain text.
    private var needsToggle: Bool {
        metrics.full > metrics.collapsed + 0.5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .lineLimit(isExpanded ? nil : lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        measuringText(limit: lineLimit, isCollapsed: true)
                        measuringText(limit: nil, isCollapsed: false)
                    }
                }
                .onPreferenceChange(SynopsisMetricsKey.self) {
                    metrics = $0
                }

            if needsToggle {
                Button(isExpanded ? "收起" : "展开") {
                    withAnimation(.snappy) {
                        isExpanded.toggle()
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "收起简介" : "展开简介")
            }
        }
        .onChange(of: text) { _, _ in
            isExpanded = false
        }
    }

    private func measuringText(limit: Int?, isCollapsed: Bool) -> some View {
        Text(text)
            .font(.subheadline)
            .lineSpacing(4)
            .lineLimit(limit)
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SynopsisMetricsKey.self,
                        value: SynopsisMetrics(
                            collapsed: isCollapsed ? proxy.size.height : 0,
                            full: isCollapsed ? 0 : proxy.size.height
                        )
                    )
                }
            }
    }
}
