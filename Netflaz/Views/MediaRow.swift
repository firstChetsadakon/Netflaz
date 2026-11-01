import SwiftUI

/// A titled, horizontally-scrolling carousel of posters.
struct MediaRow: View {
    let row: MediaRowData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(row.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(row.items) { media in
                        NavigationLink(value: media) {
                            AsyncPoster(media: media)
                                .frame(width: 124, height: 186)
                                .overlay(alignment: .topTrailing) {
                                    if !media.isPlayable {
                                        Text("ข้อมูล")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.black.opacity(0.6), in: Capsule())
                                            .foregroundStyle(.white)
                                            .padding(6)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
