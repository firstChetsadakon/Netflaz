import SwiftUI
import AVKit
import AVFoundation

/// Full-screen player that co-watches our own content over SharePlay.
/// System playback controls drive an `AVPlayer` whose transport is
/// coordinated by `SharePlayCoordinator` — so pressing play/pause/seek here
/// is mirrored on everyone in the FaceTime SharePlay session, by iOS itself.
struct SharePlayPlayerView: View {
    let media: Media

    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator = SharePlayCoordinator()
    @State private var player = AVPlayer()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                VideoPlayer(player: player)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)

                statusCard
                Spacer()
            }

            Button {
                player.pause()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline).foregroundStyle(.white)
                    .padding(12).background(.black.opacity(0.5), in: Circle())
            }
            .padding()
        }
        .onAppear {
            if player.currentItem == nil, let url = media.videoURL {
                player.replaceCurrentItem(with: AVPlayerItem(url: url))
            }
            coordinator.attach(player: player)
            coordinator.startListening()
        }
        .onDisappear {
            player.pause()
            coordinator.leave()
        }
    }

    private var statusCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: coordinator.isActive ? "shareplay" : "person.2.wave.2.fill")
                    .foregroundStyle(coordinator.isActive ? Theme.brand : Theme.textSecondary)
                Text(coordinator.statusText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if coordinator.isActive {
                Label("ผู้ร่วมดู \(coordinator.participantCount) คน · iOS ซิงก์การเล่นให้อัตโนมัติ",
                      systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    Task { await coordinator.startSharePlay(for: media) }
                } label: {
                    Label("เริ่ม SharePlay", systemImage: "shareplay")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: 10))
                }

                Text("ต้องอยู่ในสาย FaceTime และเปิด capability “Group Activities” (ดู docs/SHAREPLAY.md) ใช้งานจริงบนอุปกรณ์จริงเท่านั้น")
                    .font(.caption2).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .background(Theme.surface)
    }
}
