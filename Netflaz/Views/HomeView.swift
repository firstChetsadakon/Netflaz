import SwiftUI

struct HomeView: View {
    @StateObject private var model = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if let featured = model.featured {
                        HeroBanner(media: featured)
                            .padding(.bottom, 4)
                    }

                    ForEach(model.rows) { row in
                        MediaRow(row: row)
                    }

                    if model.isLoadingTMDB {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("กำลังโหลดข้อมูลจาก TMDB…")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal)
                    }

                    if let notice = model.tmdbNotice {
                        Label(notice, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal)
                    }

                    disclaimer
                        .padding(.top, 8)
                }
                .padding(.bottom, 28)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationDestination(for: Media.self) { media in
                MediaDetailView(media: media)
            }
            .navigationTitle("Netflaz")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { model.load() }
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().overlay(Color.white.opacity(0.1))
            Text("เนื้อหาที่เล่นได้ทั้งหมดเป็นสื่อแบบเปิด (Creative Commons / สาธารณสมบัติ) ไม่มีการถอดรหัส DRM หรือเชื่อมต่อบริการสตรีมมิงเชิงพาณิชย์ใดๆ — โปรเจกต์นี้ทำเพื่อสาธิตหลักการเท่านั้น")
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
        }
        .padding(.horizontal)
    }
}

#Preview {
    HomeView().preferredColorScheme(.dark)
}
