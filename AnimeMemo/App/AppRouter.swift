import SwiftUI

@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case home
        case search
        case library
    }

    var selectedTab: Tab = .home

    init(selectedTab: Tab = .home) {
        self.selectedTab = selectedTab
    }
}
