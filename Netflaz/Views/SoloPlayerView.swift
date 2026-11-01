import SwiftUI
import AVKit
import AVFoundation

/// Plain single-viewer playback using AVKit's `VideoPlayer` (with system
/// controls). Used when you just want to watch on your own.
struct SoloPlayerView: View {
    let media: Media
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear { player.play() }
            } else {
                ProgressView().tint(.white)
            }

            Button {
                player?.pause()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .padding()
        }
        .onAppear {
            if player == nil, let url = media.videoURL {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear { player?.pause() }
    }
}
