import SwiftUI
import Foundation

public enum CanvasAspectRatio: String, CaseIterable, Identifiable, Codable, Sendable {
    case ratio16_9 = "16:9 (橫向寬螢幕 - 預設 / 評測橫片)"
    case ratio9_16 = "9:16 (直向短影音 - Shorts / Reels / TikTok)"
    case ratio16_10 = "16:10 (MacBook / 筆電螢幕原生比例)"
    case ratio4_3 = "4:3 (經典平板 / 簡報比例)"
    case ratio1_1 = "1:1 (正方形 - 社群貼文)"
    case ratio21_9 = "21:9 (超寬曲面電影級寬螢幕)"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .ratio16_9: return "16:9"
        case .ratio9_16: return "9:16"
        case .ratio16_10: return "16:10"
        case .ratio4_3: return "4:3"
        case .ratio1_1: return "1:1"
        case .ratio21_9: return "21:9"
        }
    }
    
    public var displayName: String { shortName }
    
    public var ratioValue: CGFloat {
        switch self {
        case .ratio16_9: return 16.0 / 9.0   // 1.7778
        case .ratio9_16: return 9.0 / 16.0   // 0.5625
        case .ratio16_10: return 16.0 / 10.0 // 1.6
        case .ratio4_3: return 4.0 / 3.0     // 1.3333
        case .ratio1_1: return 1.0           // 1.0
        case .ratio21_9: return 21.0 / 9.0   // 2.3333
        }
    }
    
    /// Reference canvas base size (for proportional preview rendering)
    public var referenceSize: CGSize {
        switch self {
        case .ratio16_9: return CGSize(width: 1280, height: 720)
        case .ratio9_16: return CGSize(width: 720, height: 1280)
        case .ratio16_10: return CGSize(width: 1280, height: 800)
        case .ratio4_3: return CGSize(width: 1200, height: 900)
        case .ratio1_1: return CGSize(width: 1000, height: 1000)
        case .ratio21_9: return CGSize(width: 1680, height: 720)
        }
    }
}

public enum ChartType: String, CaseIterable, Identifiable, Codable, Sendable {
    case horizontalBar = "橫向長條圖 (預設)"
    case verticalGroupedBar = "縱向分組比例圖"
    
    public var id: String { rawValue }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if raw.contains("比例") || raw.contains("縱向") || raw.contains("vertical") || raw == "verticalGroupedBar" || raw == "proportionalBar" {
            self = .verticalGroupedBar
        } else {
            self = .horizontalBar
        }
    }
}

public enum BackgroundMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case transparent = "透明化去背（直接進入剪輯）"
    case greenScreen = "純綠幕背景 (#00FF00 Chroma Key)"
    case gradientDark = "深色科技漸層"
    case gradientLight = "簡約明亮白底"
    case customMedia = "自訂背景（圖檔/影片）"
    
    public var id: String { rawValue }
}

public enum GlassMaterialMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case dark = "深色毛玻璃 (.ultraThinMaterial)"
    case light = "淺色毛玻璃 (精緻透光)"
    
    public var id: String { rawValue }
}

public enum AnimationStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case spring = "流暢彈簧 (Spring 0.8/0.75)"
    case burstRush = "數據圖表衝出 (Burst Rush-out)"
    case easeOut = "平滑緩出 (Smooth Ease-out)"
    case bounce = "彈跳進場 (Bouncy Pop)"
    
    public var id: String { rawValue }
}

public enum IconColorMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case monochrome = "單色"
    case gradient = "雙色漸層"
    
    public var id: String { rawValue }
}

public struct CustomImageRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var base64: String
    public var name: String
    
    public init(id: UUID = UUID(), base64: String, name: String = "自訂圖示") {
        self.id = id
        self.base64 = base64
        self.name = name
    }
}

public struct CustomVideoConfig: Codable, Equatable, Sendable {
    public var trimStartTime: Double
    public var trimEndTime: Double // 0.0 代表播放至影片自然結尾
    public var cropAspectRatio: String // "original", "16:9", "9:16", "4:3", "1:1"
    public var contentMode: String // "fill" (裁切填滿), "fit" (等比縮放完整顯示)
    public var extendPlaybackUntilVideoEnds: Bool // 若影片長於動畫，背景繼續播放（數據圖表維持結束態）直到影片結束
    
    public init(
        trimStartTime: Double = 0.0,
        trimEndTime: Double = 0.0,
        cropAspectRatio: String = "original",
        contentMode: String = "fill",
        extendPlaybackUntilVideoEnds: Bool = true
    ) {
        self.trimStartTime = trimStartTime
        self.trimEndTime = trimEndTime
        self.cropAspectRatio = cropAspectRatio
        self.contentMode = contentMode
        self.extendPlaybackUntilVideoEnds = extendPlaybackUntilVideoEnds
    }
}

public struct HeaderConfig: Codable, Equatable, Sendable {
    public var mainTitle: String
    public var subtitle: String
    public var iconSymbol: String
    public var customIconBase64: String?
    public var iconColorMode: IconColorMode
    public var iconColor1Hex: String
    public var iconColor2Hex: String
    
    // 1. 自訂左上角圖示多圖管理與填滿設定
    public var customImages: [CustomImageRecord]
    public var selectedImageId: UUID?
    public var fillIconBox: Bool
    
    public var selectedImage: CustomImageRecord? {
        if let selectedImageId = selectedImageId,
           let match = customImages.first(where: { $0.id == selectedImageId }) {
            return match
        }
        return customImages.first
    }
    
    // 4. 用戶自訂標題與副標題文字顏色
    public var useCustomTitleColor: Bool
    public var titleColorHex: String
    public var subtitleColorHex: String
    
    public init(
        mainTitle: String = "Cinebench R23 + 3Dmark SNL 解熱測試",
        subtitle: String = "高電量模式 + 風扇滿轉",
        iconSymbol: String = "cpu.fill",
        customIconBase64: String? = nil,
        iconColorMode: IconColorMode = .gradient,
        iconColor1Hex: String = "#A855F7",
        iconColor2Hex: String = "#6366F1",
        customImages: [CustomImageRecord] = [],
        selectedImageId: UUID? = nil,
        fillIconBox: Bool = false,
        useCustomTitleColor: Bool = false,
        titleColorHex: String = "#FFFFFF",
        subtitleColorHex: String = "#9CA3AF"
    ) {
        self.mainTitle = mainTitle
        self.subtitle = subtitle
        self.iconSymbol = iconSymbol
        self.customIconBase64 = customIconBase64
        self.iconColorMode = iconColorMode
        self.iconColor1Hex = iconColor1Hex
        self.iconColor2Hex = iconColor2Hex
        self.customImages = customImages
        self.selectedImageId = selectedImageId
        self.fillIconBox = fillIconBox
        self.useCustomTitleColor = useCustomTitleColor
        self.titleColorHex = titleColorHex
        self.subtitleColorHex = subtitleColorHex
    }
    
    enum CodingKeys: String, CodingKey {
        case mainTitle, subtitle, iconSymbol, customIconBase64, iconColorMode, iconColor1Hex, iconColor2Hex
        case customImages, selectedImageId, fillIconBox
        case useCustomTitleColor, titleColorHex, subtitleColorHex
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mainTitle = try c.decodeIfPresent(String.self, forKey: .mainTitle) ?? "Cinebench R23 + 3Dmark SNL 解熱測試"
        self.subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? "高電量模式 + 風扇滿轉"
        self.iconSymbol = try c.decodeIfPresent(String.self, forKey: .iconSymbol) ?? "cpu.fill"
        self.customIconBase64 = try? c.decodeIfPresent(String.self, forKey: .customIconBase64)
        self.iconColorMode = try c.decodeIfPresent(IconColorMode.self, forKey: .iconColorMode) ?? .gradient
        self.iconColor1Hex = try c.decodeIfPresent(String.self, forKey: .iconColor1Hex) ?? "#A855F7"
        self.iconColor2Hex = try c.decodeIfPresent(String.self, forKey: .iconColor2Hex) ?? "#6366F1"
        
        var imgs = (try? c.decodeIfPresent([CustomImageRecord].self, forKey: .customImages)) ?? []
        if imgs.isEmpty, let singleB64 = self.customIconBase64, !singleB64.isEmpty {
            let initialRec = CustomImageRecord(base64: singleB64, name: "自訂圖示")
            imgs.append(initialRec)
        }
        self.customImages = imgs
        self.selectedImageId = try? c.decodeIfPresent(UUID.self, forKey: .selectedImageId) ?? self.customImages.first?.id
        self.fillIconBox = (try? c.decodeIfPresent(Bool.self, forKey: .fillIconBox)) ?? false
        
        self.useCustomTitleColor = (try? c.decodeIfPresent(Bool.self, forKey: .useCustomTitleColor)) ?? false
        self.titleColorHex = (try? c.decodeIfPresent(String.self, forKey: .titleColorHex)) ?? "#FFFFFF"
        self.subtitleColorHex = (try? c.decodeIfPresent(String.self, forKey: .subtitleColorHex)) ?? "#9CA3AF"
    }
}

public struct ContainerConfig: Codable, Equatable, Sendable {
    public var glassMode: GlassMaterialMode
    public var cornerRadius: Double
    public var showHighlightBorder: Bool
    public var showTopAnnotations: Bool
    public var showAnnotationBorder: Bool
    public var showDimensionMaxValue: Bool // 1. 可選是否顯示上限的設定
    public var productColumnTitle: String   // 2. 可修改 產品/規格 這行字
    
    // 4. 用戶自訂全域指標文字顏色
    public var useCustomDimensionColor: Bool
    public var dimensionHeaderColorHex: String
    
    public init(
        glassMode: GlassMaterialMode = .dark,
        cornerRadius: Double = 22.0,
        showHighlightBorder: Bool = true,
        showTopAnnotations: Bool = true,
        showAnnotationBorder: Bool = true,
        showDimensionMaxValue: Bool = true,
        productColumnTitle: String = "產品 / 規格",
        useCustomDimensionColor: Bool = false,
        dimensionHeaderColorHex: String = "#9CA3AF"
    ) {
        self.glassMode = glassMode
        self.cornerRadius = cornerRadius
        self.showHighlightBorder = showHighlightBorder
        self.showTopAnnotations = showTopAnnotations
        self.showAnnotationBorder = showAnnotationBorder
        self.showDimensionMaxValue = showDimensionMaxValue
        self.productColumnTitle = productColumnTitle
        self.useCustomDimensionColor = useCustomDimensionColor
        self.dimensionHeaderColorHex = dimensionHeaderColorHex
    }
    
    enum CodingKeys: String, CodingKey {
        case glassMode, cornerRadius, showHighlightBorder, showTopAnnotations, showAnnotationBorder
        case showDimensionMaxValue, productColumnTitle
        case useCustomDimensionColor, dimensionHeaderColorHex
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.glassMode = try c.decodeIfPresent(GlassMaterialMode.self, forKey: .glassMode) ?? .dark
        self.cornerRadius = try c.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 22.0
        self.showHighlightBorder = try c.decodeIfPresent(Bool.self, forKey: .showHighlightBorder) ?? true
        self.showTopAnnotations = try c.decodeIfPresent(Bool.self, forKey: .showTopAnnotations) ?? true
        self.showAnnotationBorder = try c.decodeIfPresent(Bool.self, forKey: .showAnnotationBorder) ?? true
        self.showDimensionMaxValue = try c.decodeIfPresent(Bool.self, forKey: .showDimensionMaxValue) ?? true
        self.productColumnTitle = try c.decodeIfPresent(String.self, forKey: .productColumnTitle) ?? "產品 / 規格"
        self.useCustomDimensionColor = try c.decodeIfPresent(Bool.self, forKey: .useCustomDimensionColor) ?? false
        self.dimensionHeaderColorHex = try c.decodeIfPresent(String.self, forKey: .dimensionHeaderColorHex) ?? "#9CA3AF"
    }
}

public struct AnimationConfig: Codable, Equatable, Sendable {
    public var style: AnimationStyle
    public var duration: Double
    public var springDamping: Double
    public var springResponse: Double
    public var staggeredDelay: Double
    public var holdDuration: Double
    
    public init(
        style: AnimationStyle = .spring,
        duration: Double = 1.6,
        springDamping: Double = 0.75,
        springResponse: Double = 0.8,
        staggeredDelay: Double = 0.08,
        holdDuration: Double = 1.5
    ) {
        self.style = style
        self.duration = duration
        self.springDamping = springDamping
        self.springResponse = springResponse
        self.staggeredDelay = staggeredDelay
        self.holdDuration = holdDuration
    }
}

public enum ExportFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case mov = "MOV 影片 (支援 ProRes Alpha 透明去背)"
    case mp4 = "MP4 影片 (高相容性通用格式)"
    case pngSnapshot = "PNG 單張高畫質圖檔"
    case pngSequence = "PNG 透明序列幀"
    
    public var id: String { rawValue }
    
    public var fileExtension: String {
        switch self {
        case .mov: return "mov"
        case .mp4: return "mp4"
        case .pngSnapshot: return "png"
        case .pngSequence: return "zip"
        }
    }
}

public enum ExportCodec: String, CaseIterable, Identifiable, Codable, Sendable {
    case proRes4444 = "Apple ProRes 4444 (帶 Alpha 透明通道)"
    case hevcWithAlpha = "HEVC / H.265 (帶 Alpha 透明通道)"
    case h264 = "H.264 / AVC (標準畫質編碼)"
    case proRes422 = "Apple ProRes 422 HQ (專業無失真)"
    
    public var id: String { rawValue }
    
    /// Whether this codec requires QuickTime MOV container
    public var requiresMOVContainer: Bool {
        self == .proRes4444 || self == .proRes422
    }
}

// Sorted strictly from largest to smallest: 4K -> 2K -> 1080p -> 720p
public enum ExportResolution: String, CaseIterable, Identifiable, Codable, Sendable {
    case p4k = "4K Ultra HD (2160p)"
    case p2k = "2K Quad HD (1440p)"
    case p1080 = "1080p Full HD"
    case p720 = "720p HD"
    
    public var id: String { rawValue }
    
    public var baseVerticalHeight: CGFloat {
        switch self {
        case .p4k:   return 2160
        case .p2k:   return 1440
        case .p1080: return 1080
        case .p720:  return 720
        }
    }
    
    /// Computes pixel resolution for a given canvas aspect ratio (ensuring even pixel dimensions for video encoders)
    public func size(for aspectRatio: CanvasAspectRatio = .ratio16_9) -> CGSize {
        let h = baseVerticalHeight
        let w = round((h * aspectRatio.ratioValue) / 2.0) * 2.0
        return CGSize(width: w, height: h)
    }
}

public struct ExportConfig: Codable, Equatable, Sendable {
    public var format: ExportFormat
    public var codec: ExportCodec
    public var resolution: ExportResolution
    public var fps: Int
    public var bitrateMbps: Double
    public var holdDuration: Double
    public var enableFastOptimization: Bool
    
    public init(
        format: ExportFormat = .mov,
        codec: ExportCodec = .proRes4444,
        resolution: ExportResolution = .p1080,
        fps: Int = 60,
        bitrateMbps: Double = 25.0,
        holdDuration: Double = 1.5,
        enableFastOptimization: Bool = true
    ) {
        self.format = format
        self.codec = codec
        self.resolution = resolution
        self.fps = fps
        self.bitrateMbps = bitrateMbps
        self.holdDuration = holdDuration
        self.enableFastOptimization = enableFastOptimization
    }
    
    enum CodingKeys: String, CodingKey {
        case format, codec, resolution, fps, bitrateMbps, holdDuration, enableFastOptimization
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.format = try container.decode(ExportFormat.self, forKey: .format)
        self.codec = try container.decode(ExportCodec.self, forKey: .codec)
        self.resolution = try container.decode(ExportResolution.self, forKey: .resolution)
        self.fps = try container.decode(Int.self, forKey: .fps)
        self.bitrateMbps = try container.decode(Double.self, forKey: .bitrateMbps)
        self.holdDuration = try container.decode(Double.self, forKey: .holdDuration)
        self.enableFastOptimization = try container.decodeIfPresent(Bool.self, forKey: .enableFastOptimization) ?? true
    }
}

public enum VerticalBaselineMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "依指標上限值 (0%~100%)"
    case productBaseline = "指定單一產品為 100% 基準"
    case groupMax = "各指標組內最高者為 100%"
    
    public var id: String { rawValue }
}

public enum VerticalValuePosition: String, CaseIterable, Identifiable, Codable, Sendable {
    case followBarTop = "隨長條圖頂端顯示"
    case onTopGridLine = "呈現在 100% 虛線上"
    
    public var id: String { rawValue }
}

public struct VerticalChartConfig: Codable, Equatable, Sendable {
    public var baselineMode: VerticalBaselineMode
    public var baselineItemId: UUID?
    public var showPercentageNumber: Bool
    public var showBarValues: Bool
    public var valuePosition: VerticalValuePosition
    
    public init(
        baselineMode: VerticalBaselineMode = .none,
        baselineItemId: UUID? = nil,
        showPercentageNumber: Bool = true,
        showBarValues: Bool = true,
        valuePosition: VerticalValuePosition = .followBarTop
    ) {
        self.baselineMode = baselineMode
        self.baselineItemId = baselineItemId
        self.showPercentageNumber = showPercentageNumber
        self.showBarValues = showBarValues
        self.valuePosition = valuePosition
    }
    
    enum CodingKeys: String, CodingKey {
        case baselineMode
        case baselineItemId
        case showPercentageNumber
        case showBarValues
        case valuePosition
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.baselineMode = (try? container.decode(VerticalBaselineMode.self, forKey: .baselineMode)) ?? .none
        self.baselineItemId = try? container.decodeIfPresent(UUID.self, forKey: .baselineItemId)
        self.showPercentageNumber = (try? container.decode(Bool.self, forKey: .showPercentageNumber)) ?? true
        self.showBarValues = (try? container.decode(Bool.self, forKey: .showBarValues)) ?? true
        self.valuePosition = (try? container.decode(VerticalValuePosition.self, forKey: .valuePosition)) ?? .followBarTop
    }
}

public struct TypographyConfig: Codable, Equatable, Sendable {
    public var fontFamily: String
    public var baseScale: Double
    public var isBoldMode: Bool
    
    // 各分項獨立字體大小設定 (調整時其餘元素佈局不動)
    public var mainTitleSize: Double
    public var subtitleSize: Double
    public var productTitleSize: Double
    public var productSubtitleSize: Double
    public var dataValueSize: Double
    public var dimensionHeaderSize: Double
    public var annotationSize: Double
    public var bottomValueSize: Double
    
    public init(
        fontFamily: String = "System Default",
        baseScale: Double = 1.0,
        isBoldMode: Bool = false,
        mainTitleSize: Double = 26.0,
        subtitleSize: Double = 14.0,
        productTitleSize: Double = 15.0,
        productSubtitleSize: Double = 11.0,
        dataValueSize: Double = 15.0,
        dimensionHeaderSize: Double = 11.0,
        annotationSize: Double = 10.0,
        bottomValueSize: Double = 10.0
    ) {
        self.fontFamily = fontFamily
        self.baseScale = baseScale
        self.isBoldMode = isBoldMode
        self.mainTitleSize = mainTitleSize
        self.subtitleSize = subtitleSize
        self.productTitleSize = productTitleSize
        self.productSubtitleSize = productSubtitleSize
        self.dataValueSize = dataValueSize
        self.dimensionHeaderSize = dimensionHeaderSize
        self.annotationSize = annotationSize
        self.bottomValueSize = bottomValueSize
    }
    
    enum CodingKeys: String, CodingKey {
        case fontFamily, baseScale, isBoldMode
        case mainTitleSize, subtitleSize, productTitleSize, productSubtitleSize
        case dataValueSize, dimensionHeaderSize, annotationSize, bottomValueSize
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.fontFamily = try c.decodeIfPresent(String.self, forKey: .fontFamily) ?? "System Default"
        self.baseScale = try c.decodeIfPresent(Double.self, forKey: .baseScale) ?? 1.0
        self.isBoldMode = try c.decodeIfPresent(Bool.self, forKey: .isBoldMode) ?? false
        self.mainTitleSize = try c.decodeIfPresent(Double.self, forKey: .mainTitleSize) ?? 26.0
        self.subtitleSize = try c.decodeIfPresent(Double.self, forKey: .subtitleSize) ?? 14.0
        self.productTitleSize = try c.decodeIfPresent(Double.self, forKey: .productTitleSize) ?? 15.0
        self.productSubtitleSize = try c.decodeIfPresent(Double.self, forKey: .productSubtitleSize) ?? 11.0
        self.dataValueSize = try c.decodeIfPresent(Double.self, forKey: .dataValueSize) ?? 15.0
        self.dimensionHeaderSize = try c.decodeIfPresent(Double.self, forKey: .dimensionHeaderSize) ?? 11.0
        self.annotationSize = try c.decodeIfPresent(Double.self, forKey: .annotationSize) ?? 10.0
        self.bottomValueSize = try c.decodeIfPresent(Double.self, forKey: .bottomValueSize) ?? 10.0
    }
}

public struct BenchmarkProject: Codable, Equatable, Sendable {
    public var version: String
    public var header: HeaderConfig
    public var dimensions: [BenchmarkDimension]
    public var items: [BenchmarkItem]
    public var chartType: ChartType
    public var backgroundMode: BackgroundMode
    public var aspectRatio: CanvasAspectRatio
    public var customMediaFilePath: String?
    public var container: ContainerConfig
    public var animationConfig: AnimationConfig
    public var export: ExportConfig
    public var typography: TypographyConfig
    public var language: AppLanguage
    public var verticalConfig: VerticalChartConfig
    public var customVideoConfig: CustomVideoConfig
    
    public init(
        version: String = "1.0",
        header: HeaderConfig = HeaderConfig(),
        dimensions: [BenchmarkDimension] = [],
        items: [BenchmarkItem] = [],
        chartType: ChartType = .horizontalBar,
        backgroundMode: BackgroundMode = .transparent,
        aspectRatio: CanvasAspectRatio = .ratio16_9,
        customMediaFilePath: String? = nil,
        container: ContainerConfig = ContainerConfig(),
        animationConfig: AnimationConfig = AnimationConfig(),
        export: ExportConfig = ExportConfig(),
        typography: TypographyConfig = TypographyConfig(),
        language: AppLanguage = .traditionalChinese,
        verticalConfig: VerticalChartConfig = VerticalChartConfig(),
        customVideoConfig: CustomVideoConfig = CustomVideoConfig()
    ) {
        self.version = version
        self.header = header
        self.dimensions = dimensions
        self.items = items
        self.chartType = chartType
        self.backgroundMode = backgroundMode
        self.aspectRatio = aspectRatio
        self.customMediaFilePath = customMediaFilePath
        self.container = container
        self.animationConfig = animationConfig
        self.export = export
        self.typography = typography
        self.language = language
        self.verticalConfig = verticalConfig
        self.customVideoConfig = customVideoConfig
    }
    
    enum CodingKeys: String, CodingKey {
        case version, header, dimensions, items, chartType, backgroundMode, aspectRatio, customMediaFilePath, container, animationConfig, export, typography, language, verticalConfig, customVideoConfig
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = (try? container.decode(String.self, forKey: .version)) ?? "1.0"
        self.header = (try? container.decode(HeaderConfig.self, forKey: .header)) ?? HeaderConfig()
        self.dimensions = (try? container.decode([BenchmarkDimension].self, forKey: .dimensions)) ?? []
        self.items = (try? container.decode([BenchmarkItem].self, forKey: .items)) ?? []
        self.chartType = (try? container.decode(ChartType.self, forKey: .chartType)) ?? .horizontalBar
        self.backgroundMode = (try? container.decode(BackgroundMode.self, forKey: .backgroundMode)) ?? .transparent
        self.aspectRatio = (try? container.decodeIfPresent(CanvasAspectRatio.self, forKey: .aspectRatio)) ?? .ratio16_9
        self.customMediaFilePath = try? container.decodeIfPresent(String.self, forKey: .customMediaFilePath)
        self.container = (try? container.decode(ContainerConfig.self, forKey: .container)) ?? ContainerConfig()
        self.animationConfig = (try? container.decode(AnimationConfig.self, forKey: .animationConfig)) ?? AnimationConfig()
        self.export = (try? container.decode(ExportConfig.self, forKey: .export)) ?? ExportConfig()
        self.typography = (try? container.decodeIfPresent(TypographyConfig.self, forKey: .typography)) ?? TypographyConfig()
        self.language = (try? container.decodeIfPresent(AppLanguage.self, forKey: .language)) ?? .traditionalChinese
        self.verticalConfig = (try? container.decodeIfPresent(VerticalChartConfig.self, forKey: .verticalConfig)) ?? VerticalChartConfig()
        self.customVideoConfig = (try? container.decodeIfPresent(CustomVideoConfig.self, forKey: .customVideoConfig)) ?? CustomVideoConfig()
    }
}
