import Foundation
import Combine
import AVFoundation
import GroupActivities

/// Drives a SharePlay session for our own content.
///
/// The flow:
///  1. `startListening()` awaits incoming/created sessions for our activity.
///  2. `startSharePlay(for:)` asks the system to begin SharePlay (shows the
///     SharePlay UI / attaches to an ongoing FaceTime call).
///  3. When a session arrives, we hand our `AVPlayer` to the session via
///     `playbackCoordinator.coordinateWithSession(_:)`. From then on, iOS keeps
///     play / pause / seek in lock-step across all participants — no custom
///     sync code, no server. That is the whole point of SharePlay.
///
/// Requirements to actually run: real devices on a FaceTime call, and the
/// "Group Activities" capability enabled in Xcode (see docs/SHAREPLAY.md). In
/// the Simulator the calls no-op gracefully.
@MainActor
final class SharePlayCoordinator: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var participantCount = 0
    @Published private(set) var statusText = "แตะ \"เริ่ม SharePlay\" ขณะอยู่ในสาย FaceTime"

    private weak var player: AVPlayer?
    private var session: GroupSession<WatchTogetherActivity>?
    private var subscriptions = Set<AnyCancellable>()
    private var listenTask: Task<Void, Never>?

    func attach(player: AVPlayer) { self.player = player }

    /// Begin receiving SharePlay sessions for our activity.
    func startListening() {
        guard listenTask == nil else { return }
        listenTask = Task { @MainActor [weak self] in
            for await session in WatchTogetherActivity.sessions() {
                self?.configure(session)
            }
        }
    }

    /// Ask the system to start SharePlay for a title.
    func startSharePlay(for media: Media) async {
        let activity = WatchTogetherActivity(mediaId: media.id, title: media.title)
        switch await activity.prepareForActivation() {
        case .activationPreferred:
            do {
                _ = try await activity.activate()
            } catch {
                statusText = "เริ่ม SharePlay ไม่สำเร็จ: \(error.localizedDescription)"
            }
        case .activationDisabled:
            statusText = "SharePlay ยังเริ่มไม่ได้ (ต้องอยู่ในสาย FaceTime และเปิด Group Activities)"
        case .cancelled:
            statusText = "ยกเลิกการเริ่ม SharePlay"
        @unknown default:
            break
        }
    }

    func leave() {
        session?.leave()
        session = nil
        isActive = false
        participantCount = 0
        subscriptions.removeAll()
        listenTask?.cancel()
        listenTask = nil
    }

    private func configure(_ session: GroupSession<WatchTogetherActivity>) {
        self.session = session

        session.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .joined:
                    self.isActive = true
                    self.statusText = "กำลังดูด้วยกันผ่าน SharePlay"
                case .invalidated:
                    self.isActive = false
                    self.statusText = "SharePlay จบแล้ว"
                    self.session = nil
                default:
                    break
                }
            }
            .store(in: &subscriptions)

        session.$activeParticipants
            .receive(on: DispatchQueue.main)
            .sink { [weak self] participants in
                self?.participantCount = participants.count
            }
            .store(in: &subscriptions)

        // Hand the player to SharePlay — iOS now coordinates transport for us.
        if let player {
            player.playbackCoordinator.coordinateWithSession(session)
        }

        session.join()
    }
}
