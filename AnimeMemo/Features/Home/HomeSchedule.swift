import SwiftUI

/// One day column in the home timetable. `items` keeps the full sorted list
/// so the card can open a sheet for shows hidden behind the preview.
struct HomeScheduleDay: Identifiable, Hashable {
    /// 1 = Monday … 7 = Sunday, matching the Bangumi calendar.
    let weekday: Int
    /// 0 = today, 1 = tomorrow, and so on.
    let relativeOffset: Int
    let dateLabel: String
    let items: [MockAnime]
    let previewLimit: Int

    var id: Int { weekday }

    private static let weekdayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    var weekdayName: String {
        guard (1...7).contains(weekday) else { return "本周" }
        return Self.weekdayNames[weekday - 1]
    }

    var title: String {
        switch relativeOffset {
        case 0: return "今天"
        case 1: return "明天"
        default: return weekdayName
        }
    }

    var sheetTitle: String {
        switch relativeOffset {
        case 0: return "今天 · \(weekdayName)"
        case 1: return "明天 · \(weekdayName)"
        default: return "\(weekdayName) · \(dateLabel)"
        }
    }

    var previewItems: [MockAnime] {
        Array(items.prefix(previewLimit))
    }

    var totalCount: Int {
        items.count
    }

    var remainingCount: Int {
        max(totalCount - previewItems.count, 0)
    }
}

enum HomeScheduleBuilder {
    /// Builds the week from Bangumi's calendar endpoint, starting with today.
    /// Within a day, the shows currently being watched by the most users come
    /// first so the timetable feels like "what's hot now".
    static func days(
        from calendarDays: [BangumiCalendarDay],
        now: Date = .now,
        calendar: Calendar = .current,
        limitPerDay: Int = 3
    ) -> [HomeScheduleDay] {
        var dayByWeekday: [Int: BangumiCalendarDay] = [:]
        for day in calendarDays {
            guard
                let weekday = day.weekday?.id,
                (1...7).contains(weekday),
                dayByWeekday[weekday] == nil
            else {
                continue
            }
            dayByWeekday[weekday] = day
        }

        return orderedDays(now: now, calendar: calendar) { weekday, offset, dateLabel in
            guard let day = dayByWeekday[weekday] else { return nil }

            var seen = Set<Int>()
            let unique = day.items.filter { seen.insert($0.id).inserted }
            let sorted = unique.sorted { lhs, rhs in
                if lhs.doingCount != rhs.doingCount {
                    return lhs.doingCount > rhs.doingCount
                }
                if (lhs.rating?.score ?? 0) != (rhs.rating?.score ?? 0) {
                    return (lhs.rating?.score ?? 0) > (rhs.rating?.score ?? 0)
                }
                return lhs.displayTitle.localizedCompare(rhs.displayTitle) == .orderedAscending
            }
            guard !sorted.isEmpty else { return nil }

            return HomeScheduleDay(
                weekday: weekday,
                relativeOffset: offset,
                dateLabel: dateLabel,
                items: sorted.map { MockAnime.from(bangumi: $0) },
                previewLimit: limitPerDay
            )
        }
    }

    /// TMDB has no weekly schedule endpoint. Fall back to its popular current
    /// anime and group by the weekday of the premiere date, which is still the
    /// regular broadcast slot for almost every weekly TV anime.
    static func days(
        from summaries: [TMDBMediaSummary],
        now: Date = .now,
        calendar: Calendar = .current,
        limitPerDay: Int = 3
    ) -> [HomeScheduleDay] {
        var bucketByWeekday: [Int: [MockAnime]] = [:]
        var seen = Set<Int>()

        for summary in summaries {
            guard
                summary.isAnimation,
                summary.resolvedMediaType(default: .tv) == .tv,
                let dateString = summary.dateString,
                let airedAt = TMDBDate.date(from: dateString),
                seen.insert(summary.id).inserted
            else {
                continue
            }

            let weekday = weekdayNumber(for: airedAt, calendar: utcCalendar)
            let anime = MockAnime.from(summary: summary, mediaType: .tv)
            bucketByWeekday[weekday, default: []].append(anime)
        }

        return orderedDays(now: now, calendar: calendar) { weekday, offset, dateLabel in
            guard let bucket = bucketByWeekday[weekday], !bucket.isEmpty else { return nil }

            return HomeScheduleDay(
                weekday: weekday,
                relativeOffset: offset,
                dateLabel: dateLabel,
                items: bucket,
                previewLimit: limitPerDay
            )
        }
    }

    private static func orderedDays(
        now: Date,
        calendar: Calendar,
        makeDay: (_ weekday: Int, _ offset: Int, _ dateLabel: String) -> HomeScheduleDay?
    ) -> [HomeScheduleDay] {
        let today = calendar.startOfDay(for: now)
        let todayWeekday = weekdayNumber(for: today, calendar: calendar)

        return (0..<7).compactMap { offset in
            let weekday = (todayWeekday - 1 + offset) % 7 + 1
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else {
                return nil
            }
            return makeDay(weekday, offset, dateLabel(for: date, calendar: calendar))
        }
    }

    private static func dateLabel(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 0)/\(components.day ?? 0)"
    }

    private static func weekdayNumber(for date: Date, calendar: Calendar) -> Int {
        // Calendar uses 1 = Sunday, Bangumi uses 1 = Monday.
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
}

/// Home timetable sourced from the active metadata provider. It sits above
/// "继续观看" and always starts at today, so the nearest broadcast day is first.
struct HomeScheduleView: View {
    @AppStorage("metadataProvider") private var providerRaw = MetadataProvider.tmdb.rawValue

    @State private var days: [HomeScheduleDay] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var reloadToken = 0

    private let bangumiClient = BangumiClient()

    private var provider: MetadataProvider {
        MetadataProvider(rawValue: providerRaw) ?? .tmdb
    }

    var body: some View {
        Group {
            if isLoading && days.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    loadingCard
                }
            } else if !days.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    scheduleRow
                }
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    errorCard(errorMessage)
                }
            }
        }
        .task(id: "\(providerRaw)|\(reloadToken)") {
            await load()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("课程表")
                .font(.title3.weight(.bold))

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text("本周热播")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scheduleRow: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(days) { day in
                    HomeScheduleDayCard(day: day)
                }
            }
            .scrollTargetLayout()
            .padding(.top, 12)
            .padding(.bottom, 12)
            .padding(.leading, 12)
            .padding(.trailing, 28)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.92),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .background {
            HomeScheduleBackdrop()
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text("正在加载本周放送…")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(.rect(cornerRadius: 18), variant: .regular)
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("课程表暂时不可用")
                    .font(.caption.weight(.semibold))

                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Button("重试") {
                reloadToken += 1
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .buttonStyle(.plain)
        }
        .padding(14)
        .glassSurface(.rect(cornerRadius: 18), variant: .regular)
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let built: [HomeScheduleDay]
            switch provider {
            case .bangumi:
                let calendarDays = try await bangumiClient.calendar()
                built = HomeScheduleBuilder.days(from: calendarDays)

            case .tmdb:
                guard let client = TMDBClient.makeFromConfiguration() else {
                    throw TMDBError.notConfigured
                }
                let page = try await client.discoverAnime()
                built = HomeScheduleBuilder.days(from: page.results)
            }

            guard !Task.isCancelled else { return }
            days = built
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            days = []
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

private struct HomeScheduleDayCard: View {
    let day: HomeScheduleDay

    @State private var showsFullDay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(day.title)
                    .font(.subheadline.weight(.bold))

                Text(day.dateLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text("\(day.totalCount) 部")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 8) {
                ForEach(day.previewItems) { anime in
                    NavigationLink {
                        AnimeDetailDestination(anime: anime)
                    } label: {
                        HomeScheduleRow(anime: anime)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.schedule.item.\(anime.id)")
                }
            }

            if day.remainingCount > 0 {
                Button {
                    showsFullDay = true
                } label: {
                    HStack(spacing: 4) {
                        Text("另有 \(day.remainingCount) 部")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.schedule.more.\(day.weekday)")
                .accessibilityLabel("查看\(day.title)全部 \(day.totalCount) 部")
            }
        }
        .padding(12)
        .frame(width: 226, alignment: .leading)
        .glassSurface(.rect(cornerRadius: 18), variant: .regular)
        .sheet(isPresented: $showsFullDay) {
            HomeScheduleDaySheet(day: day)
        }
    }
}

private struct HomeScheduleDaySheet: View {
    let day: HomeScheduleDay

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Text("共 \(day.totalCount) 部 · 按当前热度排序")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)

                    ForEach(day.items) { anime in
                        NavigationLink {
                            AnimeDetailDestination(anime: anime)
                        } label: {
                            HomeScheduleDetailRow(anime: anime)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.schedule.full.\(anime.id)")
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle(day.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct HomeScheduleDetailRow: View {
    let anime: MockAnime

    var body: some View {
        HStack(spacing: 14) {
            PosterArtwork(
                style: anime.poster,
                posterURL: anime.posterURL,
                cornerRadius: 10,
                showsLabel: false
            )
            .frame(width: 54, height: 76)

            VStack(alignment: .leading, spacing: 5) {
                Text(anime.title)
                    .font(.headline)
                    .lineLimit(1)

                if !anime.originalTitle.isEmpty {
                    Text(anime.originalTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    if anime.score > 0 {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(AppTheme.accent)

                        Text(String(format: "%.1f", anime.score))

                        if !anime.format.isEmpty || anime.year > 0 {
                            Text("·")
                        }
                    }

                    if !anime.format.isEmpty {
                        Text(anime.format)
                    }

                    if anime.year > 0 {
                        if !anime.format.isEmpty {
                            Text("·")
                        }
                        Text(String(anime.year))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.74))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.8)
                }
        }
        .contentShape(Rectangle())
    }
}

private struct HomeScheduleBackdrop: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.accentSoft.opacity(0.26),
                            Color(uiColor: .secondarySystemGroupedBackground).opacity(0.64),
                            AppTheme.accentDeep.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HomeScheduleGrid()
                .stroke(AppTheme.accent.opacity(0.09), lineWidth: 0.7)

            Circle()
                .fill(AppTheme.accent.opacity(0.10))
                .frame(width: 180, height: 180)
                .blur(radius: 30)
                .offset(x: -140, y: 80)

            Circle()
                .fill(AppTheme.accentDeep.opacity(0.08))
                .frame(width: 160, height: 160)
                .blur(radius: 30)
                .offset(x: 150, y: -70)
        }
        .accessibilityHidden(true)
    }
}

private struct HomeScheduleGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let columns = 7
        for index in 0...columns {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(columns)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }

        let rows = 5
        for index in 0...rows {
            let y = rect.minY + rect.height * CGFloat(index) / CGFloat(rows)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}

private struct HomeScheduleRow: View {
    let anime: MockAnime

    var body: some View {
        HStack(spacing: 10) {
            PosterArtwork(
                style: anime.poster,
                posterURL: anime.posterURL,
                cornerRadius: 8,
                showsLabel: false
            )
            .frame(width: 38, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(anime.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if anime.score > 0 {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(AppTheme.accent)

                        Text(String(format: "%.1f", anime.score))
                    } else {
                        Text(anime.format)
                    }

                    Text("·")
                    Text(anime.year > 0 ? String(anime.year) : "放送中")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
