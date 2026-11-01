import Foundation
import AVFoundation
import Combine

/// The heart of the app: keeps an `AVPlayer` in lock-step across everyone in
/// a room, and carries the chat.
///
/// Design (the principle the project is here to demonstrate):
///  • The room creator is the **host**. The host periodically broadcasts an
///    authoritative `sync` heartbeat (position + play/pause).
///  • **Anyone** can press play / pause / scrub. That action is applied
///    locally *and* broadcast as an explicit transport event, so the whole
///    room reacts immediately.
///  • Remote transport events are applied straight to the player (never
///    re-broadcast), so there is no feedback loop.
///  • **Latency compensation:** every transport/sync event carries the moment
///    it was sampled, expressed on a shared clock (`ClockSync`). Receivers
///    advance the target position by the time the message actually spent in
///    flight, so viewers land on the host's *current* position — not where it
///    was when the packet left.
///
/// This is the same idea behind Teleparty / SharePlay-style "watch together",
/// built from scratch on a plain WebSocket.
@MainActor
final class WatchPartyViewModel: NSObject, ObservableObject, WatchPartyClientDelegate {

    enum ConnectionState: Equatable {
        case idle, connecting, connected, closed(String)
    }

    // MARK: Published UI state
    @Published private(set) var chat: [ChatMessage] = []
    @Published private(set) var participants: [Participant] = []
    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var rttMillis: Int = 0

    // MARK: Config
    let media: Media
    let player: AVPlayer
    let isHost: Bool
    let roomId: String

    private let userId = UUID().uuidString
    private let userName: String
    private let serverURL: URL

    // MARK: Internals
    private let client = WatchPartyClient()
    private let clock = ClockSync()
    private var timeObserver: Any?
    private var syncTimer: Timer?
    private var pingTimer: Timer?
    private let driftThreshold: Double = 0.5

    init(media: Media, userName: String, roomId: String, serverURL: URL, isHost: Bool) {
        self.media = media
        self.userName = userName.isEmpty ? "ผู้ชม" : userName
        self.roomId = roomId
        self.serverURL = serverURL
        self.isHost = isHost
        if let url = media.videoURL {
            self.player = AVPlayer(url: url)
        } else {
            self.player = AVPlayer()
        }
        super.init()
        client.delegate = self
        addPeriodicObserver()
    }

    // MARK: - Lifecycle

    func connect() {
        connectionState = .connecting
        client.connect(to: serverURL)
    }

    func leave() {
        syncTimer?.invalidate(); syncTimer = nil
        pingTimer?.invalidate(); pingTimer = nil
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player.pause()
        send(.leave)
        client.disconnect()
        connectionState = .idle
    }

    // MARK: - Local transport (driven by the custom player controls)

    func togglePlayPause() { isPlaying ? pause() : play() }

    func play() {
        player.play()
        isPlaying = true
        send(.play, time: player.currentTime().seconds)
    }

    func pause() {
        player.pause()
        isPlaying = false
        send(.pause, time: player.currentTime().seconds)
    }

    func scrub(to time: Double) {
        seekPlayer(to: time)
        currentTime = time
        send(.seek, time: time)
    }

    func sendChat(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        send(.chat, text: trimmed)
        chat.append(ChatMessage(userId: userId, userName: userName, text: trimmed, date: Date()))
    }

    // MARK: - WatchPartyClientDelegate

    func partyClientDidConnect(_ client: WatchPartyClient) {
        connectionState = .connected
        startClockSync()
        send(.join, text: isHost ? "host" : "viewer")
        appendSystem("เชื่อมต่อห้อง \"\(roomId)\" สำเร็จ")
        if isHost { startHostHeartbeat() }
    }

    func partyClient(_ client: WatchPartyClient, didReceive message: PartyMessage) {
        if message.type == .pong {
            if let c = message.clientTime, let s = message.serverTime {
                clock.handlePong(clientSend: c, serverTime: s)
                rttMillis = Int(clock.rttMillis.rounded())
            }
            return
        }

        if message.userId == userId, message.type != .roster, message.type != .hello { return }

        switch message.type {
        case .play:
            let target = compensatedTarget(message) ?? 0
            seekPlayer(to: target); player.play(); isPlaying = true
        case .pause:
            if let t = message.time { seekPlayer(to: t) }
            player.pause(); isPlaying = false
        case .seek:
            let target = compensatedTarget(message) ?? (message.time ?? 0)
            seekPlayer(to: target); currentTime = target
        case .sync:
            reconcile(message)
        case .chat:
            if let text = message.text {
                chat.append(ChatMessage(userId: message.userId, userName: message.userName, text: text, date: Date()))
            }
        case .join:
            appendSystem("\(message.userName) เข้าร่วมห้อง")
        case .leave:
            appendSystem("\(message.userName) ออกจากห้อง")
        case .roster, .hello:
            if let roster = message.roster {
                participants = roster.map {
                    Participant(id: $0.userId, name: $0.userName, isHost: $0.isHost, isMe: $0.userId == userId)
                }
            }
        case .ping, .pong:
            break
        }
    }

    func partyClient(_ client: WatchPartyClient, didCloseWith error: Error?) {
        syncTimer?.invalidate()
        pingTimer?.invalidate()
        connectionState = .closed(error?.localizedDescription ?? "การเชื่อมต่อถูกปิด")
        appendSystem("หลุดการเชื่อมต่อ — ลองกดเชื่อมต่อใหม่")
    }

    // MARK: - Latency compensation

    /// Advance a remote sample by the time it spent travelling, so we land on
    /// the sender's *current* position. Falls back to the raw time if we
    /// haven't synced clocks yet or the message carries no sample timestamp.
    private func compensatedTarget(_ message: PartyMessage) -> Double? {
        guard let media = message.time else { return nil }
        guard clock.isSynced, let sampledAt = message.serverTime else { return media }
        let elapsed = max(0, (clock.serverNowMillis() - sampledAt) / 1000)
        let playing = message.isPlaying ?? false
        return media + (playing ? elapsed : 0)
    }

    /// Participants nudge themselves toward the host's authoritative heartbeat.
    private func reconcile(_ message: PartyMessage) {
        guard !isHost, let target = compensatedTarget(message) else { return }
        let local = player.currentTime().seconds
        if local.isFinite, abs(local - target) > driftThreshold {
            seekPlayer(to: target)
        }
        if let remotePlaying = message.isPlaying {
            if remotePlaying, player.timeControlStatus == .paused {
                player.play(); isPlaying = true
            } else if !remotePlaying, player.timeControlStatus != .paused {
                player.pause(); isPlaying = false
            }
        }
    }

    // MARK: - Timers

    private func startHostHeartbeat() {
        syncTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.send(.sync, time: self.player.currentTime().seconds)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    private func startClockSync() {
        // A quick burst converges the offset fast, then we keep it fresh.
        for i in 0..<4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) { [weak self] in
                self?.pingServer()
            }
        }
        pingTimer?.invalidate()
        let timer = Timer(timeInterval: 4.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pingServer() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pingTimer = timer
    }

    private func pingServer() {
        guard client.isConnected else { return }
        client.send(PartyMessage(type: .ping, roomId: roomId, userId: userId, userName: userName,
                                 clientTime: clock.nowMillis()))
    }

    // MARK: - Player helpers

    private func seekPlayer(to time: Double) {
        let clamped = max(0, time)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func addPeriodicObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = time.seconds
            if seconds.isFinite { self.currentTime = seconds }
            if let item = self.player.currentItem {
                let d = item.duration.seconds
                if d.isFinite, d > 0 { self.duration = d }
            }
            self.isPlaying = self.player.timeControlStatus != .paused
        }
    }

    private func send(_ type: PartyMessage.Kind, time: Double? = nil, text: String? = nil) {
        guard client.isConnected else { return }
        var message = PartyMessage(
            type: type,
            roomId: roomId,
            userId: userId,
            userName: userName,
            time: time?.isFinite == true ? time : nil,
            isPlaying: isPlaying,
            text: text
        )
        // Stamp transport/sync events with the shared-clock sample time so
        // receivers can compensate for transit delay.
        if clock.isSynced, [.play, .pause, .seek, .sync].contains(type) {
            message.serverTime = clock.serverNowMillis()
        }
        client.send(message)
    }

    private func appendSystem(_ text: String) {
        chat.append(ChatMessage(userId: "system", userName: "ระบบ", text: text, date: Date(), isSystem: true))
    }
}
