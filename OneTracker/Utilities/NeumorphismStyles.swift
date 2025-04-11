import SwiftUI

// MARK: - Neumorphism Colors & Shadows
// Centralized place for neumorphic styling constants

let neumorphicBackgroundColor = Color(hex: "E8EAEC")

// --- Shadow 2 (Drop Shadow) --- Used for FAB, Stats Card, List Rows
let darkDropShadowColor = Color(hex: "0D2750").opacity(0.16)
let darkDropShadowX: CGFloat = 28
let darkDropShadowY: CGFloat = 28
let darkDropShadowBlur: CGFloat = 50 / 2 // SwiftUI radius is roughly half the design blur

let lightDropShadowColor = Color.white.opacity(1.0)
let lightDropShadowX: CGFloat = -23
let lightDropShadowY: CGFloat = -23
let lightDropShadowBlur: CGFloat = 45 / 2 // SwiftUI radius is roughly half the design blur

// --- Shadow 4 (Inner Shadow) --- Used for Main Content Area Background
let lightInnerShadowColor = Color.white.opacity(0.64) // Opacity 64%
let lightInnerShadowX: CGFloat = -31
let lightInnerShadowY: CGFloat = -31
let lightInnerShadowBlur: CGFloat = 43 / 2

let darkInnerShadowColor = Color(hex: "0D2750").opacity(0.16) // Opacity 16%
let darkInnerShadowX: CGFloat = 26
let darkInnerShadowY: CGFloat = 26
let darkInnerShadowBlur: CGFloat = 48 / 2


// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0) // Default to black for invalid hex
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 