import SwiftUI
import Foundation

public struct BenchmarkItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var subtitle: String
    public var themePalette: ThemePalette
    public var customStartColorHex: String?
    public var customEndColorHex: String?
    /// Mapping of Dimension ID string to numerical value
    public var values: [String: Double]
    /// Optional top annotation text (e.g. "8400 rpm / 9072 rpm")
    public var annotationText: String
    /// Mapping of Dimension ID string to bottom numerical value on that specific bar (e.g. 25, 19)
    public var bottomValues: [String: Double]
    /// Mapping of Dimension ID string to bottom text string on that specific bar
    public var bottomTexts: [String: String]
    
    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        themePalette: ThemePalette = .purple,
        customStartColorHex: String? = nil,
        customEndColorHex: String? = nil,
        values: [String: Double] = [:],
        annotationText: String = "",
        bottomValues: [String: Double] = [:],
        bottomTexts: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.themePalette = themePalette
        self.customStartColorHex = customStartColorHex
        self.customEndColorHex = customEndColorHex
        self.values = values
        self.annotationText = annotationText
        self.bottomValues = bottomValues
        self.bottomTexts = bottomTexts
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, themePalette, customStartColorHex, customEndColorHex, values, annotationText, bottomValues, bottomTexts
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        self.themePalette = try c.decodeIfPresent(ThemePalette.self, forKey: .themePalette) ?? .purple
        self.customStartColorHex = try c.decodeIfPresent(String.self, forKey: .customStartColorHex)
        self.customEndColorHex = try c.decodeIfPresent(String.self, forKey: .customEndColorHex)
        self.values = try c.decodeIfPresent([String: Double].self, forKey: .values) ?? [:]
        self.annotationText = try c.decodeIfPresent(String.self, forKey: .annotationText) ?? ""
        self.bottomValues = try c.decodeIfPresent([String: Double].self, forKey: .bottomValues) ?? [:]
        self.bottomTexts = try c.decodeIfPresent([String: String].self, forKey: .bottomTexts) ?? [:]
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(subtitle, forKey: .subtitle)
        try c.encode(themePalette, forKey: .themePalette)
        try c.encodeIfPresent(customStartColorHex, forKey: .customStartColorHex)
        try c.encodeIfPresent(customEndColorHex, forKey: .customEndColorHex)
        try c.encode(values, forKey: .values)
        try c.encode(annotationText, forKey: .annotationText)
        try c.encode(bottomValues, forKey: .bottomValues)
        try c.encode(bottomTexts, forKey: .bottomTexts)
    }
    
    public var effectiveStartColorHex: String {
        if themePalette == .custom, let hex = customStartColorHex, !hex.isEmpty {
            return hex
        }
        return themePalette.startColorHex
    }
    
    public var effectiveEndColorHex: String {
        if themePalette == .custom, let hex = customEndColorHex, !hex.isEmpty {
            return hex
        }
        return themePalette.endColorHex
    }
    
    public var effectiveLinearGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: effectiveStartColorHex), Color(hex: effectiveEndColorHex)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    public var effectiveGlowColor: Color {
        Color(hex: effectiveStartColorHex).opacity(0.6)
    }
    
    public func value(for dimensionId: UUID) -> Double {
        values[dimensionId.uuidString] ?? 0.0
    }
    
    public mutating func setValue(_ val: Double, for dimensionId: UUID) {
        values[dimensionId.uuidString] = val
    }
    
    public func hasBottomValue(for dimensionId: UUID) -> Bool {
        bottomValues[dimensionId.uuidString] != nil || bottomTexts[dimensionId.uuidString] != nil
    }
    
    public func bottomValue(for dimensionId: UUID) -> Double? {
        bottomValues[dimensionId.uuidString]
    }
    
    public func bottomDisplayString(for dimensionId: UUID) -> String {
        if let txt = bottomTexts[dimensionId.uuidString], !txt.isEmpty {
            return txt
        }
        if let val = bottomValues[dimensionId.uuidString] {
            if val.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", val)
            } else {
                return String(format: "%.1f", val)
            }
        }
        return ""
    }
    
    public mutating func setBottomValue(_ val: Double?, for dimensionId: UUID) {
        if let v = val {
            bottomValues[dimensionId.uuidString] = v
        } else {
            bottomValues.removeValue(forKey: dimensionId.uuidString)
            bottomTexts.removeValue(forKey: dimensionId.uuidString)
        }
    }
    
    public mutating func setBottomString(_ str: String, for dimensionId: UUID) {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        // 保留 bottomTexts 紀錄，即使當前為空字串（如用戶按 Delete 清除預設 0 時），亦絕不視為刪除此選項
        bottomTexts[dimensionId.uuidString] = trimmed
        if trimmed.isEmpty {
            bottomValues.removeValue(forKey: dimensionId.uuidString)
        } else {
            if let d = Double(trimmed) {
                bottomValues[dimensionId.uuidString] = d
            }
        }
    }
    
    public mutating func removeBottomValue(for dimensionId: UUID) {
        bottomValues.removeValue(forKey: dimensionId.uuidString)
        bottomTexts.removeValue(forKey: dimensionId.uuidString)
    }
}
