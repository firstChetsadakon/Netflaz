import SwiftUI

/// Where you set up a shared viewing session: pick a title, choose a room
/// code, and either host a new room or join an existing one.
struct WatchPartyLobbyView: View {
    var preselected: Media? = nil

    @AppStorage("displayName") private var displayName = ""
    @AppStorage("serverURL") private var serverURL = "ws://localhost:8080"

    @State private var selected: Media
    @State private var roomCode: String
    @State private var wrapInStack: Bool

    init(preselected: Media? = nil) {
        self.preselected = preselected
        let playable = SampleContent.all.filter { $0.isPlayable }
        _selected = State(initialValue: preselected ?? playable.first ?? SampleContent.all[0])
        _roomCode = State(initialValue: Self.randomCode())
        // When opened from a Detail screen we're already inside a navigation
        // stack; as a tab we need to provide our own.
        _wrapInStack = State(initialValue: preselected == nil)
    }

    var body: some View {
        Group {
            if wrapInStack {
                NavigationStack { content }
            } else {
                content
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                intro

                section("ชื่อที่จะแสดงในห้อง") {
                    TextField("เช่น First", text: $displayName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                }

                section("เลือกเรื่องที่จะดูด้วยกัน") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SampleContent.all.filter { $0.isPlayable }) { media in
                                Button { selected = media } label: {
                                    AsyncPoster(media: media)
                                        .frame(width: 96, height: 144)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Theme.brand, lineWidth: selected.id == media.id ? 3 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                section("รหัสห้อง") {
                    HStack {
                        TextField("รหัสห้อง", text: $roomCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                        Button { roomCode = Self.randomCode() } label: {
                            Image(systemName: "dice.fill").padding(12)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .foregroundStyle(.white)
                    }
                }

                section("เซิร์ฟเวอร์ซิงก์ (WebSocket)") {
                    TextField("ws://localhost:8080", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                    Text("รันเซิร์ฟเวอร์จากโฟลเดอร์ server/ แล้วใส่ที่อยู่ที่นี่ (ดูวิธีใน README)")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }

                buttons
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("ดูด้วยกัน")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: WatchPartyConfig.self) { config in
            WatchPartyRoomView(config: config)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ดูไปด้วยกัน เล่น/หยุด/เลื่อนพร้อมกัน")
                .font(.title3.weight(.bold)).foregroundStyle(.white)
            Text("โฮสต์คุมจังหวะหลัก ทุกคนในห้องซิงก์ตามแบบเรียลไทม์ พร้อมแชตคุยระหว่างดู")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            NavigationLink(value: WatchPartyConfig(mediaId: selected.id, roomId: normalizedCode, isHost: true)) {
                Label("สร้างห้อง (เป็นโฮสต์)", systemImage: "crown.fill")
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: 10))
            }
            .disabled(normalizedCode.isEmpty)

            NavigationLink(value: WatchPartyConfig(mediaId: selected.id, roomId: normalizedCode, isHost: false)) {
                Label("เข้าร่วมห้อง", systemImage: "arrow.right.circle.fill")
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
            }
            .disabled(normalizedCode.isEmpty)
        }
    }

    private var normalizedCode: String {
        roomCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    private static func randomCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<5).map { _ in letters.randomElement()! })
    }
}

/// Value passed through navigation to open a room.
struct WatchPartyConfig: Hashable {
    let mediaId: String
    let roomId: String
    let isHost: Bool
}
