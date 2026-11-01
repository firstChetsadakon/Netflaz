import Foundation

protocol WatchPartyClientDelegate: AnyObject {
    func partyClientDidConnect(_ client: WatchPartyClient)
    func partyClient(_ client: WatchPartyClient, didReceive message: PartyMessage)
    func partyClient(_ client: WatchPartyClient, didCloseWith error: Error?)
}

/// A thin WebSocket client for the Watch Party, built on the native
/// `URLSessionWebSocketTask` — zero third-party dependencies.
///
/// Responsibilities are deliberately tiny: connect, encode/decode
/// `PartyMessage` JSON, and hand messages to a delegate. All the interesting
/// synchronisation logic lives in `WatchPartyViewModel`.
///
/// We intentionally use a plain `URLSession` with no custom delegate to avoid
/// the session<->delegate retain cycle. Connection open is assumed on
/// `resume()` (the task buffers any early sends until the socket is open), and
/// closure is detected through the receive loop.
final class WatchPartyClient {

    weak var delegate: WatchPartyClientDelegate?

    private let session = URLSession(configuration: .default)
    private var task: URLSessionWebSocketTask?
    private(set) var isConnected = false

    func connect(to url: URL) {
        disconnect()
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        isConnected = true
        delegate?.partyClientDidConnect(self)
        receiveLoop()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    func send(_ message: PartyMessage) {
        guard let task else { return }
        guard let data = try? JSONEncoder().encode(message),
              let json = String(data: data, encoding: .utf8) else { return }
        task.send(.string(json)) { error in
            if let error { print("[WatchParty] send error: \(error.localizedDescription)") }
        }
    }

    // MARK: - Receiving

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                let wasConnected = self.isConnected
                self.isConnected = false
                if wasConnected {
                    DispatchQueue.main.async {
                        self.delegate?.partyClient(self, didCloseWith: error)
                    }
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    self.decodeAndDeliver(Data(text.utf8))
                case .data(let data):
                    self.decodeAndDeliver(data)
                @unknown default:
                    break
                }
                // Keep listening.
                self.receiveLoop()
            }
        }
    }

    private func decodeAndDeliver(_ data: Data) {
        guard let message = try? JSONDecoder().decode(PartyMessage.self, from: data) else { return }
        DispatchQueue.main.async {
            self.delegate?.partyClient(self, didReceive: message)
        }
    }
}
