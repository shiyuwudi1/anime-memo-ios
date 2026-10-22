import Foundation

enum AppConfiguration {
    static let defaultTMDBBaseURLString = "https://api.themoviedb.org/3"
    static let proxyBaseURLKey = "tmdbAPIBaseURL"

    static var tmdbReadAccessToken: String? {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "TMDBReadAccessToken") as? String
        else {
            return nil
        }

        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !token.hasPrefix("$(") else { return nil }
        return token
    }

    static var isTMDBConfigured: Bool {
        tmdbReadAccessToken != nil || !tmdbAPIBaseURLIsDefault
    }

    static var tmdbAPIBaseURL: URL {
        normalizedTMDBBaseURL(UserDefaults.standard.string(forKey: proxyBaseURLKey))
    }

    /// Accepts `proxy.example.com`, `https://proxy.example.com/3` or
    /// `https://proxy.example.com/3/` and always returns a URL ending in `/3`.
    static func normalizedTMDBBaseURL(_ raw: String?) -> URL {
        let fallback = URL(string: defaultTMDBBaseURLString)!

        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return fallback
        }

        if !text.contains("://") {
            text = "https://\(text)"
        }

        guard
            var components = URLComponents(string: text),
            let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            let host = components.host,
            !host.isEmpty
        else {
            return fallback
        }

        components.query = nil
        components.fragment = nil

        var path = components.path
        while path.hasSuffix("/") {
            path.removeLast()
        }
        if path.isEmpty {
            path = "/3"
        }
        components.path = path

        return components.url ?? fallback
    }

    static var tmdbAPIBaseURLIsDefault: Bool {
        tmdbAPIBaseURL.absoluteString == defaultTMDBBaseURLString
    }
}
