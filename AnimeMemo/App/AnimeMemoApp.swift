import SwiftUI

@main
struct AnimeMemoApp: App {
    @State private var router: AppRouter

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
        case "settings":
            SettingsView()
        case "glasslab":
            NavigationStack {
                GlassLabView()
            }
        default:
            RootTabView()
        }
        #else
        RootTabView()
        #endif
    }
}
