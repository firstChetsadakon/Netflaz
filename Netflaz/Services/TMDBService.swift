import Foundation

/// Optional integration with The Movie Database (TMDB) — a *legitimate*,
/// publicly documented content API with a free key.
///
/// This exists purely to show how a real streaming app would populate its
/// browse experience from a licensed metadata provider. TMDB gives us
/// posters, titles and descriptions only; it does NOT provide streamable
/// video, so items returned here are marked `.tmdb` and are not playable in
/// the app. That boundary is intentional: metadata is fair to show, the
/// protected stream is not ours to serve.
///
/// Add your own key in the Settings tab (stored locally in UserDefaults).
/// Get one free at https://developer.themoviedb.org
final class TMDBService {

    enum TMDBError: LocalizedError {
        case noAPIKey
        case badResponse
        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "ยังไม่ได้ตั้งค่า TMDB API key (ไปที่แท็บ ตั้งค่า)"
            case .badResponse: return "เรียกข้อมูลจาก TMDB ไม่สำเร็จ"
            }
        }
    }

    static let apiKeyDefaultsKey = "tmdbKey"

    private let session: URLSession
    private let imageBase = "https://image.tmdb.org/t/p/w500"
    private let backdropBase = "https://image.tmdb.org/t/p/w780"

    init(session: URLSession = .shared) {
        self.session = session
    }

    var apiKey: String? {
        let key = UserDefaults.standard.string(forKey: Self.apiKeyDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (key?.isEmpty == false) ? key : nil
    }

    var isConfigured: Bool { apiKey != nil }

    /// Trending movies this week.
    func trending() async throws -> [Media] {
        try await fetch(path: "/trending/movie/week")
    }

    /// Popular movies.
    func popular() async throws -> [Media] {
        try await fetch(path: "/movie/popular")
    }

    private func fetch(path: String) async throws -> [Media] {
        guard let apiKey else { throw TMDBError.noAPIKey }

        var components = URLComponents(string: "https://api.themoviedb.org/3" + path)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "language", value: "th-TH"),
        ]
        guard let url = components.url else { throw TMDBError.badResponse }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TMDBError.badResponse
        }

        let decoded = try JSONDecoder().decode(TMDBListResponse.self, from: data)
        return decoded.results.map { dto in
            Media(
                id: "tmdb-\(dto.id)",
                title: dto.title ?? dto.name ?? "ไม่ทราบชื่อ",
                overview: dto.overview?.isEmpty == false
                    ? dto.overview!
                    : "ยังไม่มีเรื่องย่อภาษาไทยสำหรับเรื่องนี้",
                posterURL: dto.posterPath.map { URL(string: imageBase + $0)! },
                backdropURL: dto.backdropPath.map { URL(string: backdropBase + $0)! },
                videoURL: nil, // metadata only — not streamable here, by design
                year: String((dto.releaseDate ?? "----").prefix(4)),
                genres: ["TMDB"],
                rating: dto.voteAverage ?? 0,
                durationMinutes: 0,
                maturity: dto.adult == true ? "18+" : "13+",
                source: .tmdb
            )
        }
    }
}

// MARK: - DTOs

private struct TMDBListResponse: Decodable {
    let results: [TMDBItem]
}

private struct TMDBItem: Decodable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let voteAverage: Double?
    let adult: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, adult
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
    }
}
