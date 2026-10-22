import SwiftUI

@main
struct AnimeMemoApp: App {
    @State private var router: AppRouter
    @State private var library = LibraryStore()
    @AppStorage("appearance") private var appearance = "system"

    init() {
        let tab = UserDefaults.standard.string(forKey: "tab")
        let initialTab: AppRouter.Tab = switch tab {
        case "search": .search
        case "library": .library
        default: .home
        }
        _router = State(initialValue: AppRouter(selectedTab: initialTab))
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .environment(router)
                .environment(library)
                .preferredColorScheme(preferredColorScheme)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "screen") {
        case "search":
            SearchView()
        case "library":
            LibraryView()
        case "detail":
            NavigationStack {
                AnimeDetailView(anime: .frieren)
            }
        case "detailShort":
            NavigationStack {
                AnimeDetailView(anime: .debugShortSynopsis)
            }
        case "detailLong":
            NavigationStack {
                AnimeDetailView(anime: .debugLongSynopsis)
            }
        case "detailSeasons":
            NavigationStack {
                AnimeDetailView(anime: .debugMultiSeason)
            }
        case "remoteDetail":
            NavigationStack {
                RemoteAnimeDetailLoader(summary: .debugRemoteFrieren)
            }
        case "settings":
            SettingsView()
        case "glasslab":
            NavigationStack {
                GlassLabView()
            }
        case "home":
            RootTabView()
        default:
            ProviderLaunchGate()
        }
        #else
        ProviderLaunchGate()
        #endif
    }
}
