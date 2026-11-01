import Foundation

/// A single movie / show in the catalog.
///
/// `source` records where the item came from so the UI can be honest about
/// what is actually playable. Only `.openContent` items ship with a real,
/// legally streamable `videoURL`. `.tmdb` items are metadata-only: they let
/// us demonstrate integrating a real content API for browsing, without ever
/// touching DRM-protected streams.
struct Media: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let overview: String
    let posterURL: URL?
    let backdropURL: URL?
    let videoURL: URL?
    let year: String
    let genres: [String]
    let rating: Double          // 0...10
    let durationMinutes: Int
    let maturity: String        // e.g. "ALL", "13+", "16+"
    let source: Source

    enum Source: String, Codable {
        case openContent        // Creative Commons / public domain — playable
        case tmdb               // metadata only, for browse demos
    }

    var isPlayable: Bool { videoURL != nil }

    var ratingText: String { String(format: "%.1f", rating) }

    var durationText: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        if h > 0 { return "\(h)ชม \(m)น" }
        return "\(m) นาที"
    }
}

/// A labelled horizontal carousel of media on the home screen.
struct MediaRowData: Identifiable {
    let id = UUID()
    let title: String
    let items: [Media]
}
