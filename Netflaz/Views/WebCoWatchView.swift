import SwiftUI

/// Teleparty-style co-watch screen: an embedded web player whose `<video>` is
/// kept in sync across the room, with chat below.
struct WebCoWatchView: View {
    @StateObject private var vm: WebCoWatchViewModel
    @State private var messageText = ""

    init(config: WatchPartyConfig) {
        let media = SampleContent.media(withId: config.mediaId) ?? SampleContent.all[0]
        let name = UserDefaults.standard.string(forKey: "displayName") ?? ""
        let urlString = UserDefaults.standard.string(forKey: "serverURL") ?? "ws://localhost:8080"
        let url = URL(string: urlString) ?? URL(string: "ws://localhost:8080")!
        _vm = StateObject(wrappedValue: WebCoWatchViewModel(
            media: media, userName: name, roomId: config.roomId,
            serverURL: url, isHost: config.isHost, customURL: config.sourceURL
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            playerArea
            connectionBar
            hint
            Divider().overlay(Color.white.opacity(0.1))
            chatPane
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("ห้อง \(vm.roomId)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.start() }
        .onDisappear { vm.leave() }
    }

    private var playerArea: some View {
        ZStack {
            Color.black
            WebVideoView(webView: vm.webView)
            if vm.isLoadingPage {
                ProgressView().tint(.white)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
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

    @ViewBuilder
    private var connectionBar: some View {
        switch vm.connectionState {
        case .connecting:
            banner(.orange, "กำลังเชื่อมต่อเซิร์ฟเวอร์…", "antenna.radiowaves.left.and.right")
        case .connected:
            banner(.green,
                   "เชื่อมต่อแล้ว · ผู้ชม \(max(vm.participants.count, 1)) คน" + (vm.rttMillis > 0 ? " · ~\(vm.rttMillis)ms" : ""),
                   "checkmark.circle.fill")
        case .closed(let reason):
            banner(Theme.brand, "ไม่ได้เชื่อมต่อ: \(reason)", "exclamationmark.triangle.fill")
        case .idle:
            EmptyView()
        }
    }

    private var hint: some View {
        Text("กดเล่น/หยุด/เลื่อนบนตัวเล่นวิดีโอได้เลย ระบบจะซิงก์ให้ทุกคนในห้อง")
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.bottom, 6)
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

    private func banner(_ color: Color, _ text: String, _ system: String) -> some View {
        Label(text, systemImage: system)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(color.opacity(0.22))
    }

    private func send() {
        vm.sendChat(messageText)
        messageText = ""
    }
}
