import SwiftUI
import WebKit

/// Hosts a pre-configured `WKWebView` in SwiftUI. The web view is built and
/// owned by `WebCoWatchViewModel` so it can inject/evaluate JavaScript to
/// drive the Teleparty-style sync.
struct WebVideoView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
