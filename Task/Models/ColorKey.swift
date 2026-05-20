import SwiftUI

enum ColorKey: String, Codable, CaseIterable, Identifiable {
    case purple
    case blue
    case red
    case yellow
    case green
    case pink
    case gray

    var id: String { rawValue }

    var hue: Color {
        switch self {
        case .purple: return Color(red: 0.55, green: 0.42, blue: 0.78)
        case .blue:   return Color(red: 0.30, green: 0.55, blue: 0.85)
        case .red:    return Color(red: 0.85, green: 0.40, blue: 0.40)
        case .yellow: return Color(red: 0.78, green: 0.62, blue: 0.20)
        case .green:  return Color(red: 0.36, green: 0.65, blue: 0.45)
        case .pink:   return Color(red: 0.85, green: 0.45, blue: 0.58)
        case .gray:   return Color(red: 0.45, green: 0.45, blue: 0.48)
        }
    }

    var background: Color { hue.opacity(0.16) }
    var foreground: Color { hue }
    var dot: Color { hue }
}
