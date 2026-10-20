import SwiftUI

struct GlassChip: View {
    let title: String
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .primary)
                .glassSurface(
                    .capsule,
                    variant: isSelected ? .tinted(AppTheme.accent.opacity(0.62)) : .regular,
                    interactive: true
                )
        }
        .buttonStyle(.plain)
    }
}

struct GlassChipRow<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                HStack(spacing: spacing) {
                    content()
                }
            }
        } else {
            HStack(spacing: spacing) {
                content()
            }
        }
    }
}
