import Foundation

enum AppConfiguration {
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
        tmdbReadAccessToken != nil
    }
}
