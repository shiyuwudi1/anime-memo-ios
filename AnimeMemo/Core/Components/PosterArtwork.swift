import SwiftUI
import UIKit

enum PosterStyle: String, CaseIterable, Hashable, Codable {
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

/// Decoded posters kept in memory, so returning to a screen never touches disk
/// or the network again for artwork that is already on screen elsewhere.
@MainActor
final class PosterImageMemoryCache {
    static let shared = PosterImageMemoryCache()

    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 240
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

/// Downloads posters once and keeps the raw bytes on disk, so a poster that has
/// been loaded before is served from the cache on the next launch.
actor PosterImageLoader {
    static let shared = PosterImageLoader()

    private let session: URLSession
    private let directory: URL
    private var inFlight: [URL: Task<Data?, Never>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let base = caches ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.directory = base.appendingPathComponent("PosterImages", isDirectory: true)
    }

    func data(for url: URL) async -> Data? {
        let cacheFile = fileURL(for: url)

        if let cached = try? Data(contentsOf: cacheFile), !cached.isEmpty {
            return cached
        }

        if let running = inFlight[url] {
            return await running.value
        }

        let session = self.session
        let task = Task.detached(priority: .utility) {
            await PosterImageDownload.fetch(url, using: session)
        }
        inFlight[url] = task

        let data = await task.value

        if let data, !data.isEmpty {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: cacheFile, options: .atomic)
        }

        inFlight[url] = nil
        return data
    }

    private func fileURL(for url: URL) -> URL {
        directory.appendingPathComponent(PosterImageDownload.fileName(for: url))
    }
}

private enum PosterImageDownload {
    static func fetch(_ url: URL, using session: URLSession) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard (200..<300).contains(http.statusCode) else { return nil }
            return data.isEmpty ? nil : data
        } catch {
            return nil
        }
    }

    /// Stable across launches (unlike `Hasher`), so the disk cache actually hits.
    static func fileName(for url: URL) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Data(url.absoluteString.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}

struct PosterArtwork: View {
    let style: PosterStyle
    var posterURL: URL? = nil
    var cornerRadius: CGFloat = AppTheme.posterRadius
    var showsLabel: Bool = true
    /// Text drawn on the fallback artwork. Always pass the item's own title so
    /// the placeholder can never show another show's name.
    var placeholderTitle: String? = nil

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                gradient

                if posterURL == nil {
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
                }

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .transition(.opacity)
                } else {
                    if showsLabel {
                        VStack(spacing: 8) {
                            Spacer()
                            Text(placeholderTitle ?? style.overlayText)
                                .font(.system(size: min(26, proxy.size.width * 0.16), weight: .black, design: .rounded))
                                .tracking(1)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .minimumScaleFactor(0.6)
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
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
            }
            .task(id: posterURL) {
                await loadImage()
            }
        }
    }

    private var gradient: some View {
        LinearGradient(
            colors: style.colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @MainActor
    private func loadImage() async {
        guard let posterURL else {
            image = nil
            return
        }

        if let cached = PosterImageMemoryCache.shared.image(for: posterURL) {
            image = cached
            return
        }

        image = nil

        guard let data = await PosterImageLoader.shared.data(for: posterURL) else { return }
        guard !Task.isCancelled, let loaded = UIImage(data: data) else { return }

        PosterImageMemoryCache.shared.store(loaded, for: posterURL)
        withAnimation(.easeIn(duration: 0.2)) {
            image = loaded
        }
    }
}
