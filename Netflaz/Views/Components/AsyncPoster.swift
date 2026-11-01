import SwiftUI

/// Renders a poster for a `Media`. If the item has a real artwork URL (e.g.
/// from TMDB) it loads it; otherwise it falls back to a deterministic,
/// good-looking gradient tile derived from the title — so the UI always looks
/// intentional and never shows broken images.
struct AsyncPoster: View {
    let media: Media
    var cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            if let url = media.posterURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        placeholder.overlay(ProgressView().tint(.white))
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var placeholder: some View {
        Theme.gradient(for: media.id)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    Text(media.title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    Text(media.genres.first ?? "")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(10)
                .shadow(radius: 4)
            }
    }
}
