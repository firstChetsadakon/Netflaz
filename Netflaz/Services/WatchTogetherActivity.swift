import Foundation
import GroupActivities

/// The SharePlay "activity" that represents watching one title together.
///
/// Adopting `GroupActivity` is what makes our *own* content SharePlay-able:
/// when activated inside (or alongside) a FaceTime call, iOS coordinates
/// playback across everyone's devices for us. Stored properties are sent to
/// other participants, so they stay small and `Codable`-friendly (plain
/// strings).
///
/// Note: this only works for content *this app* plays. A third-party app
/// cannot SharePlay another app's content (e.g. Netflix) — only that app's
/// owner can adopt GroupActivities.
struct WatchTogetherActivity: GroupActivity {
    // Stable identifier for this activity type.
    static let activityIdentifier = "com.netflaz.app.watchtogether"

    let mediaId: String
    let title: String

    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = title
        metadata.subtitle = "ดูด้วยกันบน Netflaz"
        metadata.type = .watchTogether
        return metadata
    }
}
