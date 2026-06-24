import SwiftUI

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// Wavey's "Warm Daylight" palette + tokens, mirroring the Figma design system.
/// Type is approximated with the system faces for now (rounded ≈ Nunito, default
/// ≈ Inter); bundling the real Inter/Nunito is the theming item in DEL-211.
enum Theme {
    static let paper        = Color(hex: 0xFBF7F0)  // bg/base
    static let surface      = Color(hex: 0xFFFFFF)  // bg/surface
    static let sunken       = Color(hex: 0xF3EDE3)  // bg/sunken
    static let ink          = Color(hex: 0x1C1A17)  // text/primary
    static let textSecond   = Color(hex: 0x6B6560)  // text/secondary
    static let textTertiary = Color(hex: 0xA39B90)  // text/tertiary
    static let onColor      = Color(hex: 0xFFFFFF)  // text/on-color
    static let primary      = Color(hex: 0xFF6A3D)  // tangerine
    static let secondary    = Color(hex: 0x14B8A6)  // teal
    static let secondaryTint = Color(hex: 0xD2F4EF)
    static let match        = Color(hex: 0x16A34A)  // green — in tune / correct
    static let matchTint    = Color(hex: 0xDCFCE7)
    static let warn         = Color(hex: 0xF59E0B)  // amber — sharp / flat
    static let wrong        = Color(hex: 0xEF4444)  // red — wrong
    static let hairline     = Color(hex: 0xECE4D7)  // border/hairline
}

/// Full-width tangerine primary button.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.onColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Theme.primary.opacity(configuration.isPressed ? 0.85 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }
}
