import Foundation

/// Wire protocol for the Watch Party. Every packet exchanged with the sync
/// server is a `PartyMessage` encoded as JSON. Keeping one flat struct keeps
/// the client and the Node server trivially in sync.
struct PartyMessage: Codable {
    enum Kind: String, Codable {
        case join       // a client enters the room
        case leave      // a client leaves
        case play       // transport: resume at `time`
        case pause      // transport: pause at `time`
        case seek       // transport: jump to `time`
        case sync       // host heartbeat: authoritative time + play state
        case chat       // a chat line
        case roster     // server -> clients: current participant list
        case hello      // server -> a client: your assigned info / room state
        case ping       // client -> server: clock-sync probe
        case pong       // server -> client: clock-sync reply
    }

    var type: Kind
    var roomId: String
    var userId: String
    var userName: String
    var time: Double?            // playback position in seconds
    var isPlaying: Bool?
    var text: String?           // chat body
    var roster: [RosterEntry]?  // for .roster / .hello
    var clientTime: Double?     // ping: client send time (local clock, ms)
    var serverTime: Double?     // pong: server clock (ms); transport/sync: sample time on the shared (server) clock
    var sentAt: Double          // epoch millis, informational

    init(type: Kind,
         roomId: String,
         userId: String,
         userName: String,
         time: Double? = nil,
         isPlaying: Bool? = nil,
         text: String? = nil,
         roster: [RosterEntry]? = nil,
         clientTime: Double? = nil,
         serverTime: Double? = nil) {
        self.type = type
        self.roomId = roomId
        self.userId = userId
        self.userName = userName
        self.time = time
        self.isPlaying = isPlaying
        self.text = text
        self.roster = roster
        self.clientTime = clientTime
        self.serverTime = serverTime
        self.sentAt = Date().timeIntervalSince1970 * 1000
    }
}

struct RosterEntry: Codable, Identifiable, Hashable {
    let userId: String
    let userName: String
    var isHost: Bool
    var id: String { userId }
}

/// A chat line as shown in the UI.
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let userId: String
    let userName: String
    let text: String
    let date: Date
    var isSystem: Bool = false
}

struct Participant: Identifiable, Hashable {
    let id: String
    let name: String
    let isHost: Bool
    let isMe: Bool
}
