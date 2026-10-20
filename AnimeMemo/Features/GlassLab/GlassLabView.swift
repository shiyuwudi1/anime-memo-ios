import SwiftUI

struct GlassLabView: View {
    @State private var selectedChip = 0
    @State private var showToast = false

    var body: some View {
        ZStack {
            labBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    section("按钮") {
                        HStack(spacing: 12) {
                            GlassButton(emphasis: .prominent) {} label: {
                                Label("主操作", systemImage: "plus")
                            }

                            GlassButton {} label: {
                                Text("次操作")
                            }

                            GlassIconButton(systemName: "heart.fill", tint: AppTheme.accent) {}
                        }
                    }

                    section("Chips") {
                        GlassChipRow(spacing: 8) {
                            ForEach(Array(["全部", "在看", "想看", "看过"].enumerated()), id: \.offset) { index, title in
                                GlassChip(title: title, isSelected: selectedChip == index) {
                                    withAnimation(.snappy) {
                                        selectedChip = index
                                    }
                                }
                            }
                        }
                    }

                    section("Glass Surface") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("自定义玻璃容器")
                                .font(.headline)
                            Text("适合承载少量控制或浮层信息，不用于长列表和密集正文。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassSurface(.rect(cornerRadius: AppTheme.cardRadius))
                    }

                    section("底部操作栏") {
                        GlassBar {
                            Button {} label: {
                                Image(systemName: "heart")
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(width: 38, height: 38)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {} label: {
                                Label("+1 第 6 话", systemImage: "plus")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 11)
                                    .background(AppTheme.accent, in: Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {} label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 38, height: 38)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    section("Toast") {
                        Button("显示撤销提示") {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showToast.toggle()
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    section("说明") {
                        Text("这个页面只用于开发期对比。iOS 26/27 使用原生 Liquid Glass；iOS 18 使用系统材质近似。实际页面会把玻璃限制在导航、按钮、chips、操作栏和 toast。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                }
                .padding(AppTheme.pagePadding)
                .padding(.bottom, 40)
            }

            if showToast {
                VStack {
                    Spacer()
                    GlassToast(message: "已记录第 6 话", actionTitle: "撤销") {
                        withAnimation {
                            showToast = false
                        }
                    }
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Glass Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("LIQUID GLASS")
                    .font(.caption.weight(.black))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.72))

                if #available(iOS 26.0, *) {
                    Text("原生")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accent, in: Capsule())
                } else {
                    Text("材质回退")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.18), in: Capsule())
                }
            }

            Text("Glass\nDesign System")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .tracking(-1.5)

            Text("控制层用玻璃，内容层保持清晰。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.66))
        }
        .padding(.top, 8)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))

            content()
        }
    }

    private var labBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.16),
                    Color(red: 0.19, green: 0.08, blue: 0.28),
                    Color(red: 0.05, green: 0.16, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppTheme.accent.opacity(0.55))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 130, y: -240)

            Circle()
                .fill(AppTheme.accentDeep.opacity(0.50))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -150, y: 260)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationStack {
        GlassLabView()
    }
}
