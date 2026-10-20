import SwiftUI
import UIKit

enum GlassVariant {
    case regular
    case clear
    case tinted(Color)
}

extension View {
    func glassSurface<S: InsettableShape>(
        _ shape: S,
        variant: GlassVariant = .regular,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassSurfaceModifier(shape: shape, variant: variant, interactive: interactive))
    }
}

private struct GlassSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    let variant: GlassVariant
    let interactive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else if reduceTransparency {
            content
                .background(shape.fill(Color(uiColor: .secondarySystemBackground)))
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        } else {
            content
                .background {
                    shape
                        .fill(.ultraThinMaterial)
                        .overlay {
                            shape.strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.52), .white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                        }
                        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                }
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        switch variant {
        case .regular:
            return .regular.interactive(interactive)
        case .clear:
            return .clear.interactive(interactive)
        case .tinted(let color):
            return .regular.tint(color).interactive(interactive)
        }
    }
}
