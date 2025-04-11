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

// MARK: - Neumorphic Helper Views & Styles

// Reusable Section Header View
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(Color(hex: "0D2750").opacity(0.7))
            .padding(.leading) // Align with card content
            .padding(.top, 5) 
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Custom Button Style for Neumorphism
struct NeumorphicButtonStyle: ButtonStyle {
    @State private var isPressed: Bool = false // Track press state internally

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .background(
                ZStack { // Use ZStack to layer base and shadow effect
                    RoundedRectangle(cornerRadius: 8)
                        .fill(neumorphicBackgroundColor)
                        // Apply shadows based on press state
                        .shadow(color: configuration.isPressed ? lightInnerShadowColor : darkDropShadowColor, radius: 3, x: configuration.isPressed ? -2 : 2, y: configuration.isPressed ? -2 : 2)
                        .shadow(color: configuration.isPressed ? darkInnerShadowColor : lightDropShadowColor, radius: 3, x: configuration.isPressed ? 2 : -2, y: configuration.isPressed ? 2 : -2)

                    // Subtle overlay to enhance pressed state
                    RoundedRectangle(cornerRadius: 8)
                         .fill(configuration.isPressed ? Color.black.opacity(0.05) : Color.clear)
                }
                 .clipShape(RoundedRectangle(cornerRadius: 8)) // Clip shadows
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Text color
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Custom TextField Style for Neumorphism (Inset Appearance)
struct NeumorphicTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(neumorphicBackgroundColor)
                    // Inner shadows for inset look
                    .shadow(color: lightInnerShadowColor, radius: 3, x: -2, y: -2)
                    .shadow(color: darkInnerShadowColor, radius: 3, x: 2, y: 2)
                    // Use clipShape to contain the inner shadows
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            )
    }
}

// Custom ProgressView for Neumorphism
struct NeumorphicProgressView: View {
    var value: Double // Progress value between 0.0 and 1.0
    var color: Color = .blue // Color of the progress bar

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background Track (Slightly inset)
                RoundedRectangle(cornerRadius: 8)
                    .fill(neumorphicBackgroundColor)
                    .shadow(color: lightInnerShadowColor, radius: 3, x: -2, y: -2) // Inner shadow light
                    .shadow(color: darkInnerShadowColor, radius: 3, x: 2, y: 2)   // Inner shadow dark
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Progress Fill (Slightly raised)
                RoundedRectangle(cornerRadius: 6) // Smaller radius for inset effect
                    .fill(color)
                    .frame(width: max(0, geometry.size.width * CGFloat(value)), height: geometry.size.height - 4) // Adjust height for inset
                    .padding(2) // Padding to create the inset look
                    .shadow(color: darkDropShadowColor.opacity(0.2), radius: 2, x: 1, y: 1) // Subtle drop shadow on fill
                    .animation(.spring(), value: value)
            }
        }
    }
}

// Tip View Helper
struct TipView: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)
                 .foregroundColor(Color(hex: "0D2750").opacity(0.8)) // Use consistent dark text color
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary) // Keep secondary color for less emphasis
        }
        // Padding applied by the caller
    }
}

// Reusable Card Background Helper Function (Or make it a ViewModifier)
@ViewBuilder
func neumorphicCardBackground() -> some View {
    RoundedRectangle(cornerRadius: 15)
        .fill(neumorphicBackgroundColor)
        .shadow(color: darkDropShadowColor, radius: darkDropShadowBlur / 2, x: darkDropShadowX / 2, y: darkDropShadowY / 2)
        .shadow(color: lightDropShadowColor, radius: lightDropShadowBlur / 2, x: lightDropShadowX / 2, y: lightDropShadowY / 2)
} 