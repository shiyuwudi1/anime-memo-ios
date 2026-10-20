import SwiftUI

struct GlassBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        HStack(spacing: 12) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.barRadius, style: .continuous)
                .fill(Color(uiColor: .systemBackground).opacity(0.55))
        }
        .glassSurface(.rect(cornerRadius: AppTheme.barRadius), variant: .regular)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
