import SwiftUI

/// Routes search and timetable entries to the right detail loader without
/// forcing every caller to know which metadata provider produced the item.
struct AnimeDetailDestination: View {
    let anime: MockAnime

    var body: some View {
        if anime.bangumiID != nil {
            BangumiDetailLoader(summary: anime)
        } else if anime.tmdbID != nil {
            RemoteAnimeDetailLoader(summary: anime)
        } else {
            AnimeDetailView(anime: anime)
        }
    }
}
