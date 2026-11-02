import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var featured: Media?
    @Published var rows: [MediaRowData] = []
    @Published var isLoadingTMDB = false
    @Published var tmdbNotice: String?

    private let tmdb = TMDBService()

    func load() {
        // Always start from the playable, open-content catalog.
        featured = SampleContent.animation.first
        rows = [
            MediaRowData(title: "เล่นได้จริง · Open Cinema", items: SampleContent.all),
            MediaRowData(title: "แอนิเมชันโอเพนซอร์ส", items: SampleContent.animation),
            MediaRowData(title: "คลิปสาธิตสั้นๆ", items: SampleContent.demos),
        ]
        Task { await loadTMDB() }
    }

    /// If the user has configured a TMDB key, append browse-only rows so they
    /// can see how a licensed metadata API plugs in. These rows are not
    /// playable (no stream is ours to serve) — the UI makes that clear.
    func loadTMDB() async {
        guard tmdb.isConfigured else {
            tmdbNotice = nil
            return
        }
        isLoadingTMDB = true
        tmdbNotice = nil
        defer { isLoadingTMDB = false }

        do {
            async let trending = tmdb.trending()
            async let popular = tmdb.popular()
            let trendingItems = try await trending
            let popularItems = try await popular

            var newRows = rows.filter { !$0.title.contains("TMDB") }
            if !trendingItems.isEmpty {
                newRows.append(MediaRowData(title: "มาแรงสัปดาห์นี้ · TMDB (ดูข้อมูลเท่านั้น)",
                                            items: trendingItems))
            }
            if !popularItems.isEmpty {
                newRows.append(MediaRowData(title: "ยอดนิยม · TMDB (ดูข้อมูลเท่านั้น)",
                                            items: popularItems))
            }
            rows = newRows
        } catch {
            tmdbNotice = error.localizedDescription
        }
    }
}
