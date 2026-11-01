import SwiftUI

/// Central place for the app's colors, gradients and spacing so the UI
/// stays consistent and easy to retheme.
enum Theme {
    static let brand = Color(red: 0.898, green: 0.035, blue: 0.078) // Netflix-style red
    static let background = Color.black
    static let surface = Color(white: 0.11)
    static let surfaceElevated = Color(white: 0.16)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.72)

    /// A deterministic gradient derived from any string (e.g. a media id),
    /// used to render attractive poster tiles without hotlinking artwork.
    static func gradient(for seed: String) -> LinearGradient {
        let palettes: [[Color]] = [
            [Color(hex: 0x3A1C71), Color(hex: 0xD76D77), Color(hex: 0xFFAF7B)],
            [Color(hex: 0x0F2027), Color(hex: 0x203A43), Color(hex: 0x2C5364)],
            [Color(hex: 0x42275A), Color(hex: 0x734B6D)],
            [Color(hex: 0x000428), Color(hex: 0x004E92)],
            [Color(hex: 0x8E0E00), Color(hex: 0x1F1C18)],
            [Color(hex: 0x1D4350), Color(hex: 0xA43931)],
            [Color(hex: 0x200122), Color(hex: 0x6F0000)],
            [Color(hex: 0x16222A), Color(hex: 0x3A6073)],
        ]
        let index = abs(seed.hashValue) % palettes.count
        return LinearGradient(
            colors: palettes[index],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
