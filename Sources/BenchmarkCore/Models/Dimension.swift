import Foundation

public struct BenchmarkDimension: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var unit: String
    public var maxValue: Double
    public var decimalPlaces: Int
    /// Whether this dimension is left blank for post-production layering (留空供後期疊加圖層)
    public var isBlankPlaceholder: Bool
    /// 讓用戶能選是否針對特定指標顯示比例上限 (例：(上限 100W))
    public var showMaxValue: Bool
    /// 用戶自訂此指標標題顏色 (若為 nil 則採用預設/全域指標配色)
    public var customColorHex: String?
    
    public init(
        id: UUID = UUID(),
        name: String,
        unit: String = "",
        maxValue: Double = 100.0,
        decimalPlaces: Int = 1,
        isBlankPlaceholder: Bool = false,
        showMaxValue: Bool = true,
        customColorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.unit = unit
        self.maxValue = max(maxValue, 0.001)
        self.decimalPlaces = decimalPlaces
        self.isBlankPlaceholder = isBlankPlaceholder
        self.showMaxValue = showMaxValue
        self.customColorHex = customColorHex
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, unit, maxValue, decimalPlaces, isBlankPlaceholder, showMaxValue, customColorHex
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.unit = try container.decode(String.self, forKey: .unit)
        self.maxValue = try container.decode(Double.self, forKey: .maxValue)
        self.decimalPlaces = try container.decode(Int.self, forKey: .decimalPlaces)
        self.isBlankPlaceholder = try container.decodeIfPresent(Bool.self, forKey: .isBlankPlaceholder) ?? false
        self.showMaxValue = try container.decodeIfPresent(Bool.self, forKey: .showMaxValue) ?? true
        self.customColorHex = try? container.decodeIfPresent(String.self, forKey: .customColorHex)
    }
}
