import SwiftUI

struct LibraryView: View {
    @State private var entries: [MockAnime] = MockAnime.library
    @State private var filter: LibraryFilter = .watching
    @State private var sort: LibrarySort = .recent
    @State private var query = ""
    @State private var toast: LibraryToast?

    private var filteredEntries: [MockAnime] {
        var result = entries.filter { anime in
            let matchesFilter = filter.status == nil || anime.status == filter.status
            let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = normalized.isEmpty
                || anime.title.localizedCaseInsensitiveContains(normalized)
                || anime.originalTitle.localizedCaseInsensitiveContains(normalized)
            return matchesFilter && matchesQuery
        }

        switch sort {
        case .recent:
            break
        case .title:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .score:
            result.sort { $0.score > $1.score }
        case .year:
            result.sort { $0.year > $1.year }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text("\(entries.count) 部作品")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        Picker("排序", selection: $sort) {
                            ForEach(LibrarySort.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                    } label: {
                        Label(sort.title, systemImage: "arrow.up.arrow.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .glassSurface(.capsule, variant: .regular, interactive: true)
                    }
                    .accessibilityLabel("排序")
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 2)
                .padding(.bottom, 8)

                ScrollView(.horizontal) {
                    GlassChipRow(spacing: 8) {
                        ForEach(LibraryFilter.allCases) { item in
                            GlassChip(
                                title: "\(item.title) \(count(for: item))",
                                isSelected: filter == item
                            ) {
                                withAnimation(.snappy) {
                                    filter = item
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.pagePadding)
                }
                .scrollIndicators(.hidden)
                .padding(.bottom, 10)

                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        "这里还没有记录",
                        systemImage: "books.vertical",
                        description: Text("去搜索一部番，把它加入片库。")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredEntries) { anime in
                            NavigationLink(value: anime) {
                                LibraryRow(anime: anime)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: AppTheme.pagePadding, bottom: 6, trailing: AppTheme.pagePadding))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    increment(anime)
                                } label: {
                                    Label("+1", systemImage: "plus")
                                }
                                .tint(AppTheme.accent)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    delete(anime)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.bottom, 80, for: .scrollContent)
                }
            }
            .background(AppBackground())
            .navigationTitle("片库")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "在片库中搜索")
            .navigationDestination(for: MockAnime.self) { anime in
                AnimeDetailView(anime: anime)
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    GlassToast(
                        message: toast.text,
                        actionTitle: toast.undo == nil ? nil : "撤销",
                        action: toast.undo
                    )
                    .padding(.bottom, 76)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: toast?.id)
        }
    }

    private func count(for filter: LibraryFilter) -> Int {
        guard let status = filter.status else { return entries.count }
        return entries.filter { $0.status == status }.count
    }

    private func increment(_ anime: MockAnime) {
        guard let index = entries.firstIndex(where: { $0.id == anime.id }) else { return }

        let previousProgress = entries[index].progress
        let previousStatus = entries[index].status
        let total = max(entries[index].total, 1)
        let nextProgress = min(previousProgress + 1, total)

        entries[index].progress = nextProgress
        if entries[index].status == .planning {
            entries[index].status = .watching
        }
        if nextProgress >= total {
            entries[index].status = .completed
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            toast = LibraryToast(
                text: nextProgress >= total
                    ? "《\(entries[index].title)》已看完"
                    : "已记录《\(entries[index].title)》第 \(nextProgress) 话"
            ) {
                guard let undoIndex = entries.firstIndex(where: { $0.id == anime.id }) else { return }
                entries[undoIndex].progress = previousProgress
                entries[undoIndex].status = previousStatus
                withAnimation {
                    toast = nil
                }
            }
        }
    }

    private func delete(_ anime: MockAnime) {
        let removed = anime
        let index = entries.firstIndex(where: { $0.id == anime.id })
        entries.removeAll { $0.id == anime.id }
        withAnimation {
            toast = LibraryToast(text: "已从片库移除《\(removed.title)》") {
                if let index {
                    entries.insert(removed, at: min(index, entries.count))
                }
                withAnimation {
                    toast = nil
                }
            }
        }
    }
}

private struct LibraryRow: View {
    let anime: MockAnime

    var body: some View {
        HStack(spacing: 14) {
            PosterArtwork(style: anime.poster, cornerRadius: 12, showsLabel: false)
                .frame(width: 58, height: 82)

            VStack(alignment: .leading, spacing: 6) {
                Text(anime.title)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(anime.seasonLabel) · \(anime.format)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ProgressView(value: anime.progressFraction)
                        .tint(AppTheme.accent)
                        .scaleEffect(x: 1, y: 1.25, anchor: .center)

                    Text(anime.isMovie ? "\(anime.progress)/1" : "\(anime.progress)/\(anime.total)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let nextEpisode = anime.nextEpisode {
                    Text(nextEpisode)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.accent)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                    Text(String(format: "%.1f", anime.score))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(AppTheme.accent)

                Text(anime.status.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case watching
    case planning
    case completed
    case paused
    case dropped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .watching: return "在看"
        case .planning: return "想看"
        case .completed: return "看过"
        case .paused: return "搁置"
        case .dropped: return "弃番"
        }
    }

    var status: LibraryStatus? {
        switch self {
        case .all: return nil
        case .watching: return .watching
        case .planning: return .planning
        case .completed: return .completed
        case .paused: return .paused
        case .dropped: return .dropped
        }
    }
}

private enum LibrarySort: String, CaseIterable, Identifiable {
    case recent
    case title
    case score
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "最近更新"
        case .title: return "标题"
        case .score: return "评分"
        case .year: return "首播时间"
        }
    }
}

private struct LibraryToast: Identifiable {
    let id = UUID()
    let text: String
    let undo: (() -> Void)?
}
