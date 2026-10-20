import SwiftUI

struct RootTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(AppRouter.Tab.home)

            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(AppRouter.Tab.search)

            LibraryView()
                .tabItem {
                    Label("片库", systemImage: "books.vertical.fill")
                }
                .tag(AppRouter.Tab.library)
        }
        .tint(AppTheme.accent)
    }
}

#Preview {
    RootTabView()
        .environment(AppRouter())
        .environment(LibraryStore(entries: MockAnime.library))
}
