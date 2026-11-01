import SwiftUI

struct SettingsView: View {
    @AppStorage("displayName") private var displayName = ""
    @AppStorage("serverURL") private var serverURL = "ws://localhost:8080"
    @AppStorage("tmdbKey") private var tmdbKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("โปรไฟล์") {
                    TextField("ชื่อที่จะแสดงในห้อง", text: $displayName)
                }

                Section {
                    TextField("ws://localhost:8080", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("เซิร์ฟเวอร์ Watch Party")
                } footer: {
                    Text("ที่อยู่ WebSocket ของเซิร์ฟเวอร์ซิงก์ รันได้จากโฟลเดอร์ server/ (ดู README) ใช้ ws:// สำหรับทดสอบในเครื่อง หรือ wss:// เมื่อดีพลอยจริง")
                }

                Section {
                    SecureField("ใส่ TMDB API key (ถ้ามี)", text: $tmdbKey)
                } header: {
                    Text("TMDB (ไม่บังคับ)")
                } footer: {
                    Text("ใส่คีย์เพื่อดึงรายการหนังจริงมาโชว์ในหน้าแรก (ดูข้อมูลอย่างเดียว เล่นไม่ได้) ขอคีย์ฟรีได้ที่ developer.themoviedb.org")
                }

                Section {
                    aboutRow(icon: "checkmark.shield.fill", title: "เนื้อหาถูกลิขสิทธิ์",
                             detail: "เล่นเฉพาะสื่อแบบเปิด (CC/สาธารณสมบัติ) ไม่มีการถอด DRM")
                    aboutRow(icon: "person.2.fill", title: "Watch Party",
                             detail: "ซิงก์การเล่นผ่าน WebSocket ที่เขียนเอง ไม่พึ่งบริการภายนอก")
                    aboutRow(icon: "book.closed.fill", title: "จุดประสงค์",
                             detail: "สาธิตหลักการแอปสตรีมมิงเพื่อการศึกษา")
                } header: {
                    Text("เกี่ยวกับ")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("ตั้งค่า")
        }
    }

    private func aboutRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.brand).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

#Preview {
    SettingsView().preferredColorScheme(.dark)
}
