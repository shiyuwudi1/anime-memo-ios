import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)

            LinearGradient(
                colors: [
                    AppTheme.accent.opacity(colorScheme == .dark ? 0.22 : 0.12),
                    AppTheme.accentDeep.opacity(colorScheme == .dark ? 0.16 : 0.06),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 420)
            .frame(maxHeight: .infinity, alignment: .top)
            .blur(radius: 8)

            Circle()
                .fill(AppTheme.accentSoft.opacity(colorScheme == .dark ? 0.10 : 0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: 140, y: -260)
        }
        .ignoresSafeArea()
    }
}
