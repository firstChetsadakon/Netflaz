import SwiftUI

struct WatchPartyRoomView: View {
    @StateObject private var vm: WatchPartyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var tab: Tab = .chat
    @State private var messageText = ""
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    enum Tab: String, CaseIterable { case chat = "แชต", people = "ผู้ชม" }

    init(config: WatchPartyConfig) {
        let media = SampleContent.media(withId: config.mediaId) ?? SampleContent.all[0]
        let name = UserDefaults.standard.string(forKey: "displayName") ?? ""
        let urlString = UserDefaults.standard.string(forKey: "serverURL") ?? "ws://localhost:8080"
        let url = URL(string: urlString) ?? URL(string: "ws://localhost:8080")!
        _vm = StateObject(wrappedValue: WatchPartyViewModel(
            media: media, userName: name, roomId: config.roomId, serverURL: url, isHost: config.isHost
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            playerArea
            connectionBar
            picker
            Divider().overlay(Color.white.opacity(0.1))
            switch tab {
            case .chat: chatPane
            case .people: peoplePane
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("ห้อง \(vm.roomId)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.connect() }
        .onDisappear { vm.leave() }
    }

    // MARK: Player

    private var playerArea: some View {
        ZStack {
            Color.black
            PlayerLayerView(player: vm.player)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .overlay(alignment: .bottom) { transportControls }
        .overlay(alignment: .topLeading) {
            if vm.isHost {
                Label("โฮสต์", systemImage: "crown.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.brand.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(8)
            }
        }
    }

    private var transportControls: some View {
        VStack(spacing: 4) {
            HStack(spacing: 18) {
                Button { seekRelative(-10) } label: {
                    Image(systemName: "gobackward.10")
                }
                Button { vm.togglePlayPause() } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                Button { seekRelative(10) } label: {
                    Image(systemName: "goforward.10")
                }
                Spacer()
                Text("\(timeString(displayTime)) / \(timeString(vm.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white)
            }
            .font(.title3)
            .foregroundStyle(.white)

            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : vm.currentTime },
                    set: { scrubValue = $0 }
                ),
                in: 0...max(vm.duration, 1),
                onEditingChanged: { editing in
                    if editing {
                        isScrubbing = true
                        scrubValue = vm.currentTime
                    } else {
                        isScrubbing = false
                        vm.scrub(to: scrubValue)
                    }
                }
            )
            .tint(Theme.brand)
        }
        .padding(10)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private var displayTime: Double { isScrubbing ? scrubValue : vm.currentTime }

    // MARK: Connection bar

    @ViewBuilder
    private var connectionBar: some View {
        switch vm.connectionState {
        case .connecting:
            banner(color: .orange, text: "กำลังเชื่อมต่อเซิร์ฟเวอร์…", system: "antenna.radiowaves.left.and.right")
        case .connected:
            banner(color: .green, text: "เชื่อมต่อแล้ว · เล่น/หยุด/เลื่อน จะซิงก์ให้ทุกคน", system: "checkmark.circle.fill")
        case .closed(let reason):
            Button { vm.connect() } label: {
                banner(color: Theme.brand, text: "ไม่ได้เชื่อมต่อ: \(reason) — แตะเพื่อลองใหม่", system: "exclamationmark.triangle.fill")
            }
            .buttonStyle(.plain)
        case .idle:
            EmptyView()
        }
    }

    private func banner(color: Color, text: String, system: String) -> some View {
        Label(text, systemImage: system)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(color.opacity(0.22))
    }

    // MARK: Tabs

    private var picker: some View {
        Picker("", selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(10)
    }

    private var chatPane: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(vm.chat) { msg in
                            ChatBubble(message: msg).id(msg.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: vm.chat.count) { _, _ in
                    if let last = vm.chat.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            HStack(spacing: 8) {
                TextField("พิมพ์ข้อความ…", text: $messageText)
                    .padding(10)
                    .background(Theme.surface, in: Capsule())
                    .submitLabel(.send)
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white).padding(10)
                        .background(Theme.brand, in: Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
        }
        .frame(maxHeight: .infinity)
    }

    private var peoplePane: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if vm.participants.isEmpty {
                    Text("ยังไม่มีผู้ชมคนอื่นในห้อง")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                        .padding()
                }
                ForEach(vm.participants) { p in
                    HStack {
                        Image(systemName: p.isHost ? "crown.fill" : "person.fill")
                            .foregroundStyle(p.isHost ? Theme.brand : Theme.textSecondary)
                        Text(p.name) + Text(p.isMe ? " (คุณ)" : "").foregroundColor(Theme.textSecondary)
                        Spacer()
                        if p.isHost { Text("โฮสต์").font(.caption).foregroundStyle(Theme.textSecondary) }
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(12)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: Actions

    private func send() {
        vm.sendChat(messageText)
        messageText = ""
    }

    private func seekRelative(_ delta: Double) {
        let target = max(0, min(vm.currentTime + delta, max(vm.duration, 0)))
        vm.scrub(to: target)
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.isSystem {
            Text(message.text)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(message.userName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.brand)
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
