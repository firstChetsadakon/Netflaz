import SwiftUI

/// Where you set up a shared viewing session: pick a title, choose how you'll
/// watch (in-app open content, or a Teleparty-style web page), set a room
/// code, then host or join.
struct WatchPartyLobbyView: View {
    var preselected: Media? = nil

    @AppStorage("displayName") private var displayName = ""
    @AppStorage("serverURL") private var serverURL = "ws://localhost:8080"

    @State private var selected: Media
    @State private var roomCode: String
    @State private var wrapInStack: Bool
    @State private var mode: Mode = .inApp
    @State private var webURL = ""

    enum Mode: String, CaseIterable {
        case inApp = "ในแอป"
        case web = "เว็บ (Teleparty)"
    }

    init(preselected: Media? = nil) {
        self.preselected = preselected
        let playable = SampleContent.all.filter { $0.isPlayable }
        _selected = State(initialValue: preselected ?? playable.first ?? SampleContent.all[0])
        _roomCode = State(initialValue: Self.randomCode())
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

                section("โหมดการดู") {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(mode == .inApp
                         ? "เล่นสื่อแบบเปิดในแอปด้วย AVPlayer ซิงก์กันเป๊ะทุกคน"
                         : "ฝังหน้าเว็บแล้วเกาะ <video> เพื่อซิงก์ (หลักการเดียวกับ Teleparty)")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }

                section("เลือกเรื่อง") {
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

                if mode == .web {
                    section("ลิงก์หน้าเว็บ (ไม่บังคับ)") {
                        TextField("https://… (เว้นว่างเพื่อใช้คลิปในแอป)", text: $webURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                        Text("ใส่ได้เฉพาะหน้าที่ฝังได้ (สื่อเปิด/เว็บของคุณเอง) บริการที่มี DRM จะบล็อกการฝังและผิด ToS")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
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
            if config.isWeb {
                WebCoWatchView(config: config)
            } else {
                WatchPartyRoomView(config: config)
            }
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
            NavigationLink(value: makeConfig(isHost: true)) {
                Label("สร้างห้อง (เป็นโฮสต์)", systemImage: "crown.fill")
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: 10))
            }
            .disabled(normalizedCode.isEmpty)

            NavigationLink(value: makeConfig(isHost: false)) {
                Label("เข้าร่วมห้อง", systemImage: "arrow.right.circle.fill")
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
            }
            .disabled(normalizedCode.isEmpty)
        }
    }

    private func makeConfig(isHost: Bool) -> WatchPartyConfig {
        let trimmedURL = webURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return WatchPartyConfig(
            mediaId: selected.id,
            roomId: normalizedCode,
            isHost: isHost,
            isWeb: mode == .web,
            sourceURL: (mode == .web && !trimmedURL.isEmpty) ? trimmedURL : nil
        )
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
    var isWeb: Bool = false
    var sourceURL: String? = nil
}
