import SwiftUI
import AVFoundation

@main
struct NetflazApp: App {
    init() {
        // Allow audio playback even when the ringer switch is silent, and play
        // nicely with other media — important for a video app.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.brand)
        }
    }
}
