import SwiftUI
import UIKit
import AVFoundation

/// A bare `AVPlayerLayer` wrapped for SwiftUI. Unlike AVKit's `VideoPlayer`,
/// this exposes no system transport controls — which is exactly what the
/// Watch Party needs, because we drive play/pause/seek ourselves so every
/// action can be broadcast to the room.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
