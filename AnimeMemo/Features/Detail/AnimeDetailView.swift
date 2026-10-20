import SwiftUI

struct AnimeDetailView: View {
    let anime: MockAnime

    @State private var progress: Int
    @State private var selectedSeason = 0
    @State private var isFavorite = false
    @State private var isSynopsisExpanded = false
    @State private var showEditSheet = false
    @State private var toast: DetailToast?

    private let seasons = ["第 1 季", "第 2 季", "特别篇"]

    init(anime: MockAnime) {
        self.anime = anime
        _progress = State(initialValue: anime.progress)
        _selectedSeason = State(initialValue: anime.seasonLabel.contains("2") ? 1 : 0)
    }

    private var total: Int { max(anime.total, 1) }
    private var fraction: Double { min(Double(progress) / Double(total), 1) }

    private var progressLabel: String {
        if anime.isMovie {
            return progress >= 1 ? "已看完" : "未看"
        }
        return "第 \(progress) 话 / 共 \(total) 话"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                seasonPicker
                progressCard
                synopsisCard
                metadataCard
            }
            .padding(.bottom, 130)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
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
            EditEntrySheet(anime: anime, progress: $progress)
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
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            PosterArtwork(style: anime.poster, cornerRadius: 0, showsLabel: false)
                .frame(height: 320)
                .clipped()

            LinearGradient(
                colors: [.clear, Color(uiColor: .systemBackground).opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 320)

            HStack(alignment: .bottom, spacing: 16) {
                PosterArtwork(style: anime.poster)
                    .frame(width: 108, height: 158)
                    .shadow(color: .black.opacity(0.28), radius: 18, y: 10)

                VStack(alignment: .leading, spacing: 7) {
                    Text(anime.seasonLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(AppTheme.accent, in: Capsule())

                    Text(anime.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(anime.originalTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(String(format: "%.1f", anime.score), systemImage: "star.fill")
                        Text("·")
                        Text(String(anime.year))
                        Text("·")
                        Text(anime.format)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 6)
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.bottom, 18)
        }
        .padding(.top, -8)
    }

    @ViewBuilder
    private var seasonPicker: some View {
        if !anime.isMovie {
            VStack(alignment: .leading, spacing: 10) {
                Text("季")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                GlassChipRow(spacing: 8) {
                    ForEach(seasons.indices, id: \.self) { index in
                        GlassChip(
                            title: seasons[index],
                            isSelected: selectedSeason == index
                        ) {
                            withAnimation(.snappy) {
                                selectedSeason = index
                            }
                        }
                    }
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
                Text(anime.isMovie ? "看完就是 1 话" : "看到第 \(progress) 话")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                GlassButton(emphasis: .prominent) {
                    increment()
                } label: {
                    Label("第 \(min(progress + 1, total)) 话", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                }
                .disabled(progress >= total)
                .opacity(progress >= total ? 0.55 : 1)
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

            Text(anime.synopsis)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .lineLimit(isSynopsisExpanded ? nil : 4)

            Button(isSynopsisExpanded ? "收起" : "展开") {
                withAnimation(.snappy) {
                    isSynopsisExpanded.toggle()
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.pagePadding)
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("作品信息")
                .font(.headline)

            infoRow("类型", anime.genres.joined(separator: " / "))
            infoRow("格式", anime.format)
            infoRow("首播", String(anime.year))
            infoRow("时长", anime.isMovie ? "\(anime.runtime) 分钟" : "\(anime.runtime) 分钟 / 话")
            infoRow("下一话", anime.nextEpisode ?? "暂无")
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

        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
            toast = DetailToast(
                text: progress >= total
                    ? "《\(anime.title)》已看完"
                    : "已记录《\(anime.title)》第 \(progress) 话"
            ) {
                progress = previous
                withAnimation {
                    toast = nil
                }
            }
        }
    }
}

private struct DetailToast: Identifiable {
    let id = UUID()
    let text: String
    let undo: (() -> Void)?
}
