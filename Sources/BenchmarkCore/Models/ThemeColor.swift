import SwiftUI
import AppKit

public enum ThemePalette: String, CaseIterable, Identifiable, Codable, Sendable {
    case purple = "紫色漸層"
    case blue = "藍色漸層"
    case cyan = "青藍霓虹"
    case green = "翡翠極光"
    case sunset = "日落橙紅"
    case amber = "琥珀金黃"
    case pink = "烈焰桃紅"
    case silver = "鈦金銀灰"
    case custom = "自訂配色"
    
    public var id: String { rawValue }
    
    public var startColorHex: String {
        switch self {
        case .purple: return "#A855F7"
        case .blue:   return "#3B82F6"
        case .cyan:   return "#06B6D4"
        case .green:  return "#10B981"
        case .sunset: return "#F97316"
        case .amber:  return "#F59E0B"
        case .pink:   return "#EC4899"
        case .silver: return "#94A3B8"
        case .custom: return "#EC4899"
        }
    }
    
    public var endColorHex: String {
        switch self {
        case .purple: return "#6366F1"
        case .blue:   return "#1D4ED8"
        case .cyan:   return "#0284C7"
        case .green:  return "#059669"
        case .sunset: return "#EF4444"
        case .amber:  return "#D97706"
        case .pink:   return "#BE185D"
        case .silver: return "#475569"
        case .custom: return "#8B5CF6"
        }
    }
    
    public var linearGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: startColorHex), Color(hex: endColorHex)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    public var glowColor: Color {
        Color(hex: startColorHex).opacity(0.6)
    }
}

extension Color {
    public init(hex: String) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexClean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    public func toHex() -> String {
        let nsColor = NSColor(self)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return "#7C3AED" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }
}
