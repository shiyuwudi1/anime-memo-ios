import SwiftUI

enum GlassEmphasis {
    case regular
    case prominent
}

struct GlassButton<Label: View>: View {
    let emphasis: GlassEmphasis
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    init(
        emphasis: GlassEmphasis = .regular,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.emphasis = emphasis
        self.action = action
        self.label = label
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            switch emphasis {
            case .regular:
                Button(action: action, label: label)
                    .buttonStyle(.glass)
            case .prominent:
                Button(action: action, label: label)
                    .buttonStyle(.glassProminent)
            }
        } else {
            Button(action: action) {
                label()
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .foregroundStyle(emphasis == .prominent ? Color.white : Color.primary)
                    .glassSurface(
                        .capsule,
                        variant: emphasis == .prominent ? .tinted(AppTheme.accent) : .regular,
                        interactive: true
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

struct GlassIconButton: View {
    let systemName: String
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 42, height: 42)
                .foregroundStyle(tint == nil ? Color.primary : Color.white)
                .contentShape(Circle())
                .glassSurface(
                    .circle,
                    variant: tint.map { GlassVariant.tinted($0) } ?? .regular,
                    interactive: true
                )
        }
        .buttonStyle(.plain)
    }
}
