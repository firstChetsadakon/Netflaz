import Foundation
import Combine
import WebKit

/// The Teleparty-style co-watch engine.
///
/// How Teleparty actually works (and what this reproduces, legally):
///  • Each viewer loads the video **themselves**, in their own session — no
///    credentials pass through us, no DRM is touched, no private API is called.
///  • A small script injected into the page hooks the page's `<video>`
///    element: it reports `play` / `pause` / `seeked` to native code, and
///    exposes functions native code can call to apply remote actions.
///  • Those events ride the exact same WebSocket `PartyMessage` protocol and
///    server used by the in-app player, so a room stays in lock-step.
///
/// This is pointed at embeddable content (open media, or a URL the user is
/// allowed to embed). DRM streaming sites block WKWebView embedding and
/// forbid this by ToS, so they are intentionally out of scope.
@MainActor
final class WebCoWatchViewModel: NSObject, ObservableObject,
    WatchPartyClientDelegate, WKScriptMessageHandler, WKNavigationDelegate {

    enum ConnectionState: Equatable {
        case idle, connecting, connected, closed(String)
    }

    @Published private(set) var chat: [ChatMessage] = []
    @Published private(set) var participants: [Participant] = []
    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var isLoadingPage = true

    let media: Media
    let roomId: String
    let isHost: Bool
    let webView: WKWebView

    private let userId = UUID().uuidString
    private let userName: String
    private let serverURL: URL
    private let customURL: String?

    private let client = WatchPartyClient()
    private var syncTimer: Timer?

    init(media: Media, userName: String, roomId: String, serverURL: URL, isHost: Bool, customURL: String?) {
        self.media = media
        self.userName = userName.isEmpty ? "ผู้ชม" : userName
        self.roomId = roomId
        self.serverURL = serverURL
        self.isHost = isHost
        self.customURL = (customURL?.isEmpty == false) ? customURL : nil

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Self.injectedJS,
                                              injectionTime: .atDocumentEnd,
                                              forMainFrameOnly: false))
        config.userContentController = controller
        self.webView = WKWebView(frame: .zero, configuration: config)

        super.init()
        controller.add(self, name: "coWatch")
        webView.navigationDelegate = self
        client.delegate = self
    }

    // MARK: - Lifecycle

    func start() {
        connectionState = .connecting
        client.connect(to: serverURL)
        loadContent()
    }

    private func loadContent() {
        isLoadingPage = true
        if let customURL, let url = URL(string: customURL) {
            webView.load(URLRequest(url: url))
        } else if let video = media.videoURL {
            webView.loadHTMLString(Self.playerHTML(videoURL: video.absoluteString), baseURL: nil)
        } else {
            isLoadingPage = false
        }
    }

    func leave() {
        syncTimer?.invalidate()
        syncTimer = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "coWatch")
        send(.leave)
        client.disconnect()
        connectionState = .idle
    }

    func sendChat(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        send(.chat, text: trimmed)
        chat.append(ChatMessage(userId: userId, userName: userName, text: trimmed, date: Date()))
    }

    // MARK: - WKScriptMessageHandler (JS -> native)

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "coWatch",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        let time = (body["time"] as? NSNumber)?.doubleValue ?? (body["time"] as? Double)
        switch type {
        case "play": send(.play, time: time)
        case "pause": send(.pause, time: time)
        case "seek": send(.seek, time: time)
        default: break
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoadingPage = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoadingPage = false
    }

    // MARK: - WatchPartyClientDelegate (native <-> server)

    func partyClientDidConnect(_ client: WatchPartyClient) {
        connectionState = .connected
        send(.join, text: isHost ? "host" : "viewer")
        appendSystem("เชื่อมต่อห้อง \"\(roomId)\" สำเร็จ")
        if isHost { startHostHeartbeat() }
    }

    func partyClient(_ client: WatchPartyClient, didReceive message: PartyMessage) {
        if message.userId == userId, message.type != .roster, message.type != .hello { return }

        switch message.type {
        case .play: applyToVideo("play", message.time)
        case .pause: applyToVideo("pause", message.time)
        case .seek: applyToVideo("seek", message.time)
        case .sync: if !isHost { applyToVideo("sync", message.time) }
        case .chat:
            if let text = message.text {
                chat.append(ChatMessage(userId: message.userId, userName: message.userName, text: text, date: Date()))
            }
        case .join: appendSystem("\(message.userName) เข้าร่วมห้อง")
        case .leave: appendSystem("\(message.userName) ออกจากห้อง")
        case .roster, .hello:
            if let roster = message.roster {
                participants = roster.map {
                    Participant(id: $0.userId, name: $0.userName, isHost: $0.isHost, isMe: $0.userId == userId)
                }
            }
        }
    }

    func partyClient(_ client: WatchPartyClient, didCloseWith error: Error?) {
        syncTimer?.invalidate()
        connectionState = .closed(error?.localizedDescription ?? "การเชื่อมต่อถูกปิด")
        appendSystem("หลุดการเชื่อมต่อ — ออกแล้วเข้าห้องใหม่อีกครั้ง")
    }

    // MARK: - Helpers

    private func applyToVideo(_ type: String, _ time: Double?) {
        let t = time.map { String($0) } ?? "null"
        webView.evaluateJavaScript("window.__coWatchApply && window.__coWatchApply('\(type)', \(t));",
                                   completionHandler: nil)
    }

    private func startHostHeartbeat() {
        syncTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.broadcastSync() }
        }
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    private func broadcastSync() {
        webView.evaluateJavaScript("window.__coWatchTime ? window.__coWatchTime() : null") { [weak self] result, _ in
            guard let self else { return }
            let time = (result as? NSNumber)?.doubleValue ?? (result as? Double)
            self.send(.sync, time: time)
        }
    }

    private func send(_ type: PartyMessage.Kind, time: Double? = nil, text: String? = nil) {
        guard client.isConnected else { return }
        client.send(PartyMessage(
            type: type, roomId: roomId, userId: userId, userName: userName,
            time: (time?.isFinite == true) ? time : nil, text: text
        ))
    }

    private func appendSystem(_ text: String) {
        chat.append(ChatMessage(userId: "system", userName: "ระบบ", text: text, date: Date(), isSystem: true))
    }

    // MARK: - Injected web assets

    /// The page we load for built-in open content: a full-bleed HTML5 player.
    static func playerHTML(videoURL: String) -> String {
        """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
          html,body{margin:0;height:100%;background:#000;overflow:hidden}
          video{width:100%;height:100%;object-fit:contain;background:#000}
        </style></head><body>
        <video id="coWatchVideo" controls playsinline src="\(videoURL)"></video>
        </body></html>
        """
    }

    /// Injected into every page. Hooks the first `<video>` element and bridges
    /// its transport events to native code — the same technique a Teleparty
    /// browser extension uses, but inside our own WKWebView.
    static let injectedJS = """
    (function () {
      if (window.__coWatchInstalled) { return; }
      window.__coWatchInstalled = true;
      var applying = false;

      function post(type, time) {
        try {
          window.webkit.messageHandlers.coWatch.postMessage({ type: type, time: time });
        } catch (e) {}
      }
      function video() { return document.querySelector('video'); }

      function bind(v) {
        if (!v || v.__coWatchBound) { return; }
        v.__coWatchBound = true;
        v.addEventListener('play',   function () { if (!applying) post('play',  v.currentTime); });
        v.addEventListener('pause',  function () { if (!applying) post('pause', v.currentTime); });
        v.addEventListener('seeked', function () { if (!applying) post('seek',  v.currentTime); });
      }

      window.__coWatchApply = function (type, time) {
        var v = video(); if (!v) { return; }
        applying = true;
        try {
          if (type === 'seek' && time != null) {
            v.currentTime = time;
          } else if (type === 'play') {
            if (time != null && Math.abs(v.currentTime - time) > 1.5) { v.currentTime = time; }
            v.play();
          } else if (type === 'pause') {
            if (time != null) { v.currentTime = time; }
            v.pause();
          } else if (type === 'sync' && time != null) {
            if (Math.abs(v.currentTime - time) > 1.5) { v.currentTime = time; }
          }
        } catch (e) {}
        setTimeout(function () { applying = false; }, 350);
      };

      window.__coWatchTime = function () {
        var v = video();
        return v ? v.currentTime : null;
      };

      // The <video> may appear after load (SPA pages) — keep trying to bind.
      var tries = 0;
      var iv = setInterval(function () {
        var v = video();
        if (v) { bind(v); }
        if (++tries > 60) { clearInterval(iv); }
      }, 1000);
    })();
    """
}
