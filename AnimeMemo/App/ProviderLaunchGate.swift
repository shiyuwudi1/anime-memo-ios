import SwiftUI

/// Gate shown before the main UI on every cold launch.
///
/// Both metadata sources are probed concurrently. If at least one responds the
/// app enters silently, switching to that source only when the current choice
/// is down. When neither responds the main UI stays locked and a guided
/// troubleshooting screen is shown instead.
struct ProviderLaunchGate: View {
    private enum Phase: Equatable {
        case checking
        case ready
        case blocked([ProviderHealth])
    }

    /// Startup should feel immediate, so the probe gets a shorter budget than
    /// in-app requests.
    private static let probeTimeout: TimeInterval = 5

    @AppStorage("metadataProvider") private var providerRaw = MetadataProvider.tmdb.rawValue
    @State private var phase: Phase = .checking
    @State private var launchStatus = "正在检查网络连接…"

    private var provider: MetadataProvider {
        MetadataProvider(rawValue: providerRaw) ?? .tmdb
    }

    var body: some View {
        ZStack {
            switch phase {
            case .checking:
                LaunchCheckingView(status: launchStatus)
                    .transition(.opacity)

            case .ready:
                RootTabView()
                    .transition(.opacity)

            case .blocked(let results):
                ProviderUnavailableView(results: results) {
                    Task { await checkProviders() }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
        .task { await checkProviders() }
    }

    @MainActor
    private func checkProviders() async {
        phase = .checking
        launchStatus = "正在连接 TMDB 与 Bangumi…"

        let results = await probeResults()
        guard !Task.isCancelled else { return }

        guard let preferred = ProviderHealth.preferredProvider(from: results, current: provider) else {
            phase = .blocked(results)
            return
        }

        // Silent fallback: no alert, no banner, just use the working source.
        if preferred != provider {
            providerRaw = preferred.rawValue
        }
        phase = .ready
    }

    @MainActor
    private func probeResults() async -> [ProviderHealth] {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "failProviderProbes") {
            return MetadataProvider.allCases.map {
                ProviderHealth(provider: $0, failureReason: "调试模式：模拟连接失败。")
            }
        }
        #endif

        var results: [ProviderHealth] = []
        for await health in ProviderHealth.probeUpdates(timeout: Self.probeTimeout) {
            guard !Task.isCancelled else { break }
            results.append(health)
            updateLaunchStatus(for: health, completed: results.count)
        }
        return results
    }

    @MainActor
    private func updateLaunchStatus(for health: ProviderHealth, completed: Int) {
        guard completed < MetadataProvider.allCases.count else {
            launchStatus = "数据源检测完成，正在进入…"
            return
        }

        let remaining = MetadataProvider.allCases
            .filter { $0 != health.provider }
            .map(\.title)
            .joined(separator: "、")

        launchStatus = health.isAvailable
            ? "\(health.provider.title) 已连接 · \(remaining) 检测中…"
            : "\(health.provider.title) 暂无响应 · \(remaining) 检测中…"
    }
}

// MARK: - Splash

private struct LaunchCheckingView: View {
    let status: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 104, height: 104)
                        .shadow(color: AppTheme.accent.opacity(0.35), radius: 24, y: 12)

                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(isPulsing ? 1.02 : 0.98)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                    value: isPulsing
                )

                VStack(spacing: 5) {
                    Text("番忆")
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("追番进度，都在这里")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ProgressView()
                        .tint(AppTheme.accent)

                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: status)
                        .accessibilityIdentifier("launchGate.status")
                }
                .frame(maxWidth: 300)
                .padding(.top, 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(status)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { isPulsing = true }
    }
}

// MARK: - Blocking guidance

private struct ProviderUnavailableView: View {
    let results: [ProviderHealth]
    let onRetry: () -> Void

    @AppStorage(AppConfiguration.proxyBaseURLKey) private var proxyBaseURL = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statusCard
                stepsCard
                proxyCard
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .safeAreaInset(edge: .bottom) {
            actions
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.14))
                    .frame(width: 80, height: 80)

                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(spacing: 7) {
                Text("暂时无法连接数据源")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("TMDB 和 Bangumi 都没有响应。番忆至少需要其中一个数据源才能使用，请按下面的步骤排查。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
    }

    private var statusCard: some View {
        VStack(spacing: 0) {
            ForEach(results) { health in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: health.provider.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(AppTheme.accent.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(health.provider.title)
                                .font(.subheadline.weight(.semibold))

                            Spacer(minLength: 8)

                            Text(health.isAvailable ? "可用" : "不可用")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(health.isAvailable ? Color.green : AppTheme.accent)
                        }

                        if let reason = health.failureReason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(14)

                if health.id != results.last?.id {
                    Divider()
                        .opacity(0.5)
                        .padding(.leading, 58)
                }
            }
        }
        .glassSurface(.rect(cornerRadius: AppTheme.cardRadius))
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("按下面的步骤排查", systemImage: "list.number")
                .font(.headline)

            step(1, "确认手机已联网", "用 Safari 打开任意网页验证。如果开着 VPN 或网络代理，先关掉再试。")
            step(2, "换一个网络", "在 Wi-Fi 和蜂窝数据之间切换。部分网络会污染 Bangumi 的域名解析。")
            step(3, "给 TMDB 配一个代理", "在下方填写你的反向代理地址，例如 https://你的域名/3 。")
            step(4, "重新检测", "修好后点「重新检测」，只要一个数据源可用就会直接进入 App。")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(.rect(cornerRadius: AppTheme.cardRadius))
    }

    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(AppTheme.accent))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var proxyCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("TMDB 反向代理地址")
                .font(.subheadline.weight(.semibold))

            TextField("https://你的域名/3", text: $proxyBaseURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassSurface(.rect(cornerRadius: 12))
                .accessibilityIdentifier("launchGate.proxyField")

            Text("留空则使用 TMDB 官方接口。填好后点「重新检测」即可生效。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(.rect(cornerRadius: AppTheme.cardRadius))
    }

    private var actions: some View {
        VStack(spacing: 8) {
            GlassButton(emphasis: .prominent) {
                onRetry()
            } label: {
                Label("重新检测", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityIdentifier("launchGate.retry")

            Text("检测通过前不会进入主界面，避免展示过期内容。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .padding(.horizontal, AppTheme.pagePadding)
        .background {
            Rectangle()
                .fill(.bar)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Divider().opacity(0.4)
        }
    }
}
