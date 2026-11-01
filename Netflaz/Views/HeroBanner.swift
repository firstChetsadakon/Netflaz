import SwiftUI

/// The big featured title at the top of the home screen.
struct HeroBanner: View {
    let media: Media

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.gradient(for: media.id)
                .frame(height: 460)
                .overlay(
                    LinearGradient(
                        colors: [.clear, .clear, Theme.background.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 14) {
                Text(media.title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(radius: 8)

                Text(media.genres.joined(separator: " · "))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 12) {
                    NavigationLink(value: media) {
                        Label("เล่น", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    }

                    NavigationLink(value: media) {
                        Label("ข้อมูล", systemImage: "info.circle")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 18)
        }
    }
}
