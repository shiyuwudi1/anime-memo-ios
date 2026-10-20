import SwiftUI

struct HomeView: View {
    @Environment(AppRouter.self) private var router

    @State private var entries: [MockAnime] = MockAnime.library
    @State private var showSettings = false
    @State private var toast: HomeToast?

    private var watching: [MockAnime] {
        entries.filter { $0.status == .watching }
    }

    private var todayUpdates: [MockAnime] {
        entries.filter { $0.status == .watching && $0.nextEpisode != nil }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<11: return "早上好"
        case 11..<18: return "下午好"
        default: return "晚上好"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    header

                    if watching.isEmpty {
                        emptyContinueState
                    } else {
                        continueSection
                    }

                    if !todayUpdates.isEmpty {
                        todaySection
                    }

                    recentSection
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 6)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityLabel("设置")
                }
            }
            .navigationDestination(for: MockAnime.self) { anime in
                AnimeDetailView(anime: anime)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(greeting)，追番人")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("今天想看点什么？")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(-0.8)

            Text("不登录，打开就记。数据只存在这台设备上。")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(.top, 8)
    }

    private var continueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("继续观看", detail: "\(watching.count) 部")

            VStack(spacing: 10) {
                ForEach(watching.prefix(3)) { anime in
                    ContinueWatchingRow(anime: anime) {
                        increment(anime)
                    }
                }
            }
        }
    }

    private var emptyContinueState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles.tv")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(AppTheme.accent)

            Text("还没有在看的番")
                .font(.headline)

            Text("去搜索一部作品，记录第一话。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            GlassButton(emphasis: .prominent) {
                router.selectedTab = .search
            } label: {
                Label("去搜索", systemImage: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .glassSurface(.rect(cornerRadius: AppTheme.cardRadius), variant: .regular)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("今日更新", detail: "\(todayUpdates.count) 部")

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(todayUpdates) { anime in
                        TodayUpdateCard(anime: anime) {
                            increment(anime)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("最近加入", detail: nil)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(entries) { anime in
                        NavigationLink(value: anime) {
                            VStack(alignment: .leading, spacing: 7) {
                                PosterArtwork(style: anime.poster)
                                    .frame(width: 104, height: 148)

                                Text(anime.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)

                                Text(anime.seasonLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 104, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func sectionHeader(_ title: String, detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))

            Spacer()

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

        let didFinish = nextProgress >= total
        if didFinish {
            entries[index].status = .completed
        }

        let text: String
        if entries[index].isMovie {
            text = didFinish ? "《\(entries[index].title)》已看完" : "《\(entries[index].title)》进度已更新"
        } else {
            text = didFinish
                ? "《\(entries[index].title)》已看完"
                : "已记录《\(entries[index].title)》第 \(nextProgress) 话"
        }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            toast = HomeToast(text: text) {
                guard let undoIndex = entries.firstIndex(where: { $0.id == anime.id }) else { return }
                entries[undoIndex].progress = previousProgress
                entries[undoIndex].status = previousStatus
                withAnimation {
                    toast = nil
                }
            }
        }
    }
}

private struct ContinueWatchingRow: View {
    let anime: MockAnime
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            NavigationLink(value: anime) {
                HStack(spacing: 14) {
                    PosterArtwork(style: anime.poster, cornerRadius: 12, showsLabel: false)
                        .frame(width: 62, height: 90)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(anime.title)
                            .font(.headline)
                            .lineLimit(1)

                        Text("\(anime.seasonLabel) · \(anime.progressText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ProgressView(value: anime.progressFraction)
                            .tint(AppTheme.accent)
                            .scaleEffect(x: 1, y: 1.35, anchor: .center)

                        if let nextEpisode = anime.nextEpisode {
                            Label(nextEpisode, systemImage: "calendar")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(AppTheme.accent)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            GlassIconButton(systemName: "plus", tint: AppTheme.accent, action: onIncrement)
                .accessibilityLabel("记录一话")
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.74))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.8)
                }
        }
    }
}

private struct TodayUpdateCard: View {
    let anime: MockAnime
    let onIncrement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: anime) {
                PosterArtwork(style: anime.poster)
                    .frame(width: 152, height: 214)
            }
            .buttonStyle(.plain)

            Text(anime.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(width: 152, alignment: .leading)

            HStack(spacing: 8) {
                Text("第 \(min(anime.progress + 1, anime.total)) 话 · 今天")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.white)
                        .background(AppTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("记录一话")
            }
            .frame(width: 152)
        }
    }
}

private struct HomeToast: Identifiable {
    let id = UUID()
    let text: String
    let undo: (() -> Void)?
}
