import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("หน้าแรก", systemImage: "house.fill") }

            WatchPartyLobbyView()
                .tabItem { Label("ดูด้วยกัน", systemImage: "person.2.fill") }

            SettingsView()
                .tabItem { Label("ตั้งค่า", systemImage: "gearshape.fill") }
        }
        .tint(Theme.brand)
    }
}

#Preview {
    RootView().preferredColorScheme(.dark)
}
