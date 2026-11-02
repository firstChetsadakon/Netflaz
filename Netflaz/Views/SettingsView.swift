import SwiftUI

struct SettingsView: View {
    @AppStorage("tmdbKey") private var tmdbKey = ""

    var body: some View {
        NavigationStack {
            Form {
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
                    aboutRow(icon: "shareplay", title: "ดูด้วยกันด้วย SharePlay",
                             detail: "ซิงก์การเล่นผ่าน FaceTime โดย iOS จัดการให้ ไม่ต้องมีเซิร์ฟเวอร์")
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
