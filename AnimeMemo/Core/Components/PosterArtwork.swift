import SwiftUI

enum PosterStyle: String, CaseIterable, Hashable {
    case frieren
    case dandadan
    case apothecary
    case spy
    case solo
    case lookback

    var colors: [Color] {
        switch self {
        case .frieren:
            return [
                Color(red: 0.07, green: 0.20, blue: 0.24),
                Color(red: 0.18, green: 0.45, blue: 0.43),
                Color(red: 0.86, green: 0.80, blue: 0.62)
            ]
        case .dandadan:
            return [
                Color(red: 0.16, green: 0.07, blue: 0.28),
                Color(red: 0.56, green: 0.18, blue: 0.58),
                Color(red: 0.98, green: 0.39, blue: 0.35)
            ]
        case .apothecary:
            return [
                Color(red: 0.07, green: 0.20, blue: 0.14),
                Color(red: 0.32, green: 0.52, blue: 0.31),
                Color(red: 0.85, green: 0.70, blue: 0.39)
            ]
        case .spy:
            return [
                Color(red: 0.14, green: 0.09, blue: 0.19),
                Color(red: 0.56, green: 0.20, blue: 0.38),
                Color(red: 0.94, green: 0.55, blue: 0.58)
            ]
        case .solo:
            return [
                Color(red: 0.03, green: 0.08, blue: 0.20),
                Color(red: 0.10, green: 0.33, blue: 0.64),
                Color(red: 0.32, green: 0.78, blue: 0.88)
            ]
        case .lookback:
            return [
                Color(red: 0.20, green: 0.08, blue: 0.06),
                Color(red: 0.72, green: 0.26, blue: 0.16),
                Color(red: 0.95, green: 0.68, blue: 0.38)
            ]
        }
    }

    var overlayText: String {
        switch self {
        case .frieren: return "FRIEREN"
        case .dandadan: return "DAN DA DAN"
        case .apothecary: return "APOTHECARY"
        case .spy: return "SPY × FAMILY"
        case .solo: return "SOLO\nLEVELING"
        case .lookback: return "LOOK BACK"
        }
    }

    var symbol: String {
        switch self {
        case .frieren: return "moon.stars.fill"
        case .dandadan: return "bolt.fill"
        case .apothecary: return "leaf.fill"
        case .spy: return "eye.fill"
        case .solo: return "diamond.fill"
        case .lookback: return "film.fill"
        }
    }
}

struct PosterArtwork: View {
    let style: PosterStyle
    var cornerRadius: CGFloat = AppTheme.posterRadius
    var showsLabel: Bool = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: style.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 180, height: 180)
                    .blur(radius: 2)
                    .offset(x: 70, y: -90)

                Circle()
                    .fill(.black.opacity(0.16))
                    .frame(width: 220, height: 220)
                    .blur(radius: 18)
                    .offset(x: -80, y: 120)

                if showsLabel {
                    VStack(spacing: 8) {
                        Spacer()
                        Text(style.overlayText)
                            .font(.system(size: min(26, proxy.size.width * 0.16), weight: .black, design: .rounded))
                            .tracking(1)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.94))
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                            .padding(.horizontal, 14)
                        Rectangle()
                            .fill(.white.opacity(0.55))
                            .frame(width: 28, height: 2)
                            .padding(.bottom, 18)
                    }
                }

                Image(systemName: style.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
            }
        }
    }
}
