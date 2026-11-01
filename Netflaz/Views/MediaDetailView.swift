import SwiftUI

struct MediaDetailView: View {
    let media: Media

    @State private var showPlayer = false
    @State private var showParty = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header

                VStack(alignment: .leading, spacing: 16) {
                    metadata

                    if media.isPlayable {
                        actionButtons
                    } else {
                        notPlayableNote
                    }

                    Text(media.overview)
                        .font(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    genreChips
                }
                .padding(20)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPlayer) {
            SoloPlayerView(media: media)
        }
        .navigationDestination(isPresented: $showParty) {
            WatchPartyLobbyView(preselected: media)
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let backdrop = media.backdropURL {
                    AsyncImage(url: backdrop) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Theme.gradient(for: media.id)
                    }
                } else {
                    Theme.gradient(for: media.id)
                }
            }
            .frame(height: 260)
            .clipped()
            .overlay(
                LinearGradient(colors: [.clear, Theme.background],
                               startPoint: .center, endPoint: .bottom)
            )

            Text(media.title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 6)
                .padding(20)
        }
    }

    private var metadata: some View {
        HStack(spacing: 10) {
            Label(media.ratingText, systemImage: "star.fill")
                .foregroundStyle(.yellow)
            Text(media.year)
            Text(media.maturity)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.textSecondary))
            if media.durationMinutes > 0 {
                Text(media.durationText)
            }
            Spacer()
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Theme.textSecondary)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showPlayer = true
            } label: {
                Label("เล่น", systemImage: "play.fill")
                    .font(.headline).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8))
            }

            Button {
                showParty = true
            } label: {
                Label("ชวนดูด้วยกัน (Watch Party)", systemImage: "person.2.fill")
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var notPlayableNote: some View {
        Label("รายการนี้มาจาก TMDB เพื่อสาธิตการดึงข้อมูลเท่านั้น จึงเล่นในแอปไม่ได้ (ไม่มีไฟล์วิดีโอแบบเปิดให้สตรีม)",
              systemImage: "info.circle")
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private var genreChips: some View {
        HStack {
            ForEach(media.genres, id: \.self) { genre in
                Text(genre)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.surface, in: Capsule())
                    .foregroundStyle(Theme.textPrimary)
            }
        }
    }
}
