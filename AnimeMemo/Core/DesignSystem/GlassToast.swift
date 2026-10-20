import SwiftUI

struct GlassToast: View {
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.accent)

            Text(message)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassSurface(.capsule, variant: .regular)
        .padding(.horizontal, 20)
    }
}
