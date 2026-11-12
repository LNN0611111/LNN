import SwiftUI

public struct HorizontalBarChartView: View {
    public var items: [BenchmarkItem]
    public var dimensions: [BenchmarkDimension]
    public var chartType: ChartType
    public var canvasWidth: CGFloat
    public var rowProgresses: [UUID: Double]
    public var numberProgresses: [UUID: Double]
    public var showAnnotations: Bool
    public var showAnnotationBorder: Bool
    public var isDarkGlass: Bool
    public var fontFamily: String
    public var typography: TypographyConfig
    public var showDimensionMaxValue: Bool
    public var productColumnTitle: String
    public var container: ContainerConfig
    
    public init(
        items: [BenchmarkItem],
        dimensions: [BenchmarkDimension],
        chartType: ChartType,
        canvasWidth: CGFloat,
        rowProgresses: [UUID: Double],
        numberProgresses: [UUID: Double],
        showAnnotations: Bool,
        showAnnotationBorder: Bool = true,
        isDarkGlass: Bool,
        fontFamily: String,
        typography: TypographyConfig = TypographyConfig(),
        showDimensionMaxValue: Bool = true,
        productColumnTitle: String = "產品 / 規格",
        container: ContainerConfig = ContainerConfig()
    ) {
        self.items = items
        self.dimensions = dimensions
        self.chartType = chartType
        self.canvasWidth = canvasWidth
        self.rowProgresses = rowProgresses
        self.numberProgresses = numberProgresses
        self.showAnnotations = showAnnotations
        self.showAnnotationBorder = showAnnotationBorder
        self.isDarkGlass = isDarkGlass
        self.fontFamily = fontFamily
        self.typography = typography
        self.showDimensionMaxValue = showDimensionMaxValue
        self.productColumnTitle = productColumnTitle
        self.container = container
    }
    
    private var anyItemHasAnnotation: Bool {
        showAnnotations && items.contains(where: { !$0.annotationText.isEmpty })
    }
    
    public var body: some View {
        let productWidth: CGFloat = 220
        let hSpacing: CGFloat = 24
        let vSpacing: CGFloat = 10
        let dimCount = CGFloat(max(dimensions.count, 1))
        
        // Exact geometric slot calculation:
        let totalChartWidth = max(400, canvasWidth - 104)
        let dimsAreaWidth = max(120, totalChartWidth - productWidth - hSpacing)
        let colWidth = max(90, (dimsAreaWidth - (dimCount - 1) * hSpacing) / dimCount)
        
        VStack(alignment: .leading, spacing: vSpacing) {
            // MARK: - 1. Header Row (固定高度 26pt，調整字體大小時其餘元素嚴格不動)
            HStack(spacing: hSpacing) {
                Text(productColumnTitle.isEmpty ? l10n("產品 / 規格", "Product / Specs") : productColumnTitle)
                    .font(FontManager.shared.font(
                        family: fontFamily,
                        size: CGFloat(typography.dimensionHeaderSize),
                        weight: .bold,
                        isBoldMode: typography.isBoldMode
                    ))
                    .foregroundColor(isDarkGlass ? Color(white: 0.6) : Color(hex: "#334155"))
                    .frame(width: productWidth, height: 26, alignment: .leading)
                
                HStack(spacing: hSpacing) {
                    ForEach(dimensions) { dim in
                        if dim.isBlankPlaceholder {
                            // 留空欄位：表頭完全留空，嚴格佔位鎖定保證未留空指標欄位置完全固定不偏移
                            Color.clear
                                .frame(width: colWidth, height: 26)
                        } else {
                            let dimHeaderColor: Color = {
                                if let customHex = dim.customColorHex, !customHex.isEmpty {
                                    return Color(hex: customHex)
                                }
                                if container.useCustomDimensionColor {
                                    return Color(hex: container.dimensionHeaderColorHex)
                                }
                                return isDarkGlass ? Color(white: 0.85) : Color(hex: "#0F172A")
                            }()
                            
                            HStack(spacing: 4) {
                                Text(dim.name)
                                    .font(FontManager.shared.font(
                                        family: fontFamily,
                                        size: CGFloat(typography.dimensionHeaderSize),
                                        weight: .bold,
                                        isBoldMode: typography.isBoldMode
                                    ))
                                    .foregroundColor(dimHeaderColor)
                                    .lineLimit(1)
                                
                                if dim.showMaxValue {
                                    Text(l10n("(上限 \(Int(dim.maxValue))\(dim.unit))", "(Max \(Int(dim.maxValue))\(dim.unit))"))
                                        .font(FontManager.shared.font(
                                            family: fontFamily,
                                            size: max(8, CGFloat(typography.dimensionHeaderSize) - 2),
                                            weight: .medium,
                                            isBoldMode: typography.isBoldMode
                                        ))
                                        .foregroundColor(isDarkGlass ? Color(white: 0.5) : Color(hex: "#475569"))
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: colWidth, height: 26, alignment: .leading)
                        }
                    }
                }
            }
            .frame(height: 26)
            
            // MARK: - 2. Divider Row (一體成型無縫分割線，嚴格截斷於留空欄位前)
            let validDimCount = dimensions.firstIndex(where: { $0.isBlankPlaceholder }) ?? dimensions.count
            let activeLineWidth: CGFloat = (validDimCount == 0)
                ? productWidth
                : (productWidth + hSpacing + CGFloat(validDimCount) * colWidth + CGFloat(validDimCount - 1) * hSpacing)
            
            ZStack(alignment: .leading) {
                Color.clear
                    .frame(width: totalChartWidth, height: 1)
                
                Rectangle()
                    .fill(isDarkGlass ? Color.white.opacity(0.18) : Color.black.opacity(0.22))
                    .frame(width: activeLineWidth, height: 1)
            }
            .frame(height: 1)
            
            // MARK: - 3. Product Data Rows
            ForEach(items) { item in
                let progress = rowProgresses[item.id] ?? 1.0
                let numProgress = numberProgresses[item.id] ?? 1.0
                
                HStack(alignment: .center, spacing: hSpacing) {
                    // Left Column: Product Title & Spec Subtitle (固定高度 42pt，調整字體大小時其餘元素嚴格不動)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(FontManager.shared.font(
                                family: fontFamily,
                                size: CGFloat(typography.productTitleSize),
                                weight: .bold,
                                design: .rounded,
                                isBoldMode: typography.isBoldMode
                            ))
                            .foregroundStyle(item.effectiveLinearGradient)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.leading)
                            .shadow(color: item.effectiveGlowColor.opacity(0.3), radius: 4, x: 0, y: 1)
                        
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(FontManager.shared.font(
                                    family: fontFamily,
                                    size: CGFloat(typography.productSubtitleSize),
                                    weight: .medium,
                                    isBoldMode: typography.isBoldMode
                                ))
                                .foregroundColor(isDarkGlass ? Color(white: 0.6) : Color(hex: "#334155"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    .frame(width: productWidth, height: 42, alignment: .leading)
                    
                    // Right Columns: Dimensions Data Bar or Blank
                    HStack(spacing: hSpacing) {
                        ForEach(dimensions) { dim in
                            dimensionCell(
                                item: item,
                                dim: dim,
                                colWidth: colWidth,
                                progress: progress,
                                numProgress: numProgress
                            )
                        }
                    }
                }
                .opacity(min(max(progress * 1.5, 0.0), 1.0))
                .offset(y: (1.0 - min(max(progress, 0.0), 1.0)) * 14.0)
            }
        }
        .frame(width: totalChartWidth, alignment: .leading)
    }
    
    @ViewBuilder
    private func dimensionCell(
        item: BenchmarkItem,
        dim: BenchmarkDimension,
        colWidth: CGFloat,
        progress: Double,
        numProgress: Double
    ) -> some View {
        if dim.isBlankPlaceholder {
            // 完全留空：嚴格維持相同高度與固定寬度插槽，保證零位移零跳動
            VStack(alignment: .leading, spacing: 3) {
                if anyItemHasAnnotation {
                    Spacer().frame(height: 18)
                }
                Color.clear
                    .frame(width: colWidth, height: 22)
            }
            .frame(width: colWidth, alignment: .leading)
        } else {
            let rawVal = item.value(for: dim.id)
            let safeMax = max(dim.maxValue, 0.001)
            let baseRatio = max(0.0, min(rawVal / safeMax, 1.0))
            let currentRatio = baseRatio * max(0.0, progress)
            let currentNumber = rawVal * min(max(numProgress, 0.0), 1.0)
            let formattedNumber = String(format: "%.\(dim.decimalPlaces)f", currentNumber)
            
            // 固定數字寬度與軌道寬度公式
            let numberWidth: CGFloat = 68
            let trackWidth: CGFloat = max(20, colWidth - 12 - numberWidth)
            // 比例上限平滑約束：長條圖精準在軌道內伸展，絕不爆出軌道擠壓右側數值文字
            let barWidth = min(max(trackWidth * currentRatio, 0), trackWidth)
            
            VStack(alignment: .leading, spacing: 3) {
                // Top Annotation text (固定 18pt 槽位高度，支援自選外框，字級調整零位移)
                if anyItemHasAnnotation {
                    if !item.annotationText.isEmpty {
                        Text(item.annotationText)
                            .font(FontManager.shared.font(
                                family: fontFamily,
                                size: CGFloat(typography.annotationSize),
                                weight: .bold,
                                design: .monospaced,
                                isBoldMode: typography.isBoldMode
                            ))
                            .foregroundColor(isDarkGlass ? .white : .black)
                            .padding(.horizontal, showAnnotationBorder ? 6 : 2)
                            .padding(.vertical, showAnnotationBorder ? 1.5 : 0)
                            .background(
                                Group {
                                    if showAnnotationBorder {
                                        Capsule()
                                            .fill(item.effectiveGlowColor.opacity(0.35))
                                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                                    }
                                }
                            )
                            .shadow(color: isDarkGlass ? .black.opacity(0.5) : .white.opacity(0.5), radius: showAnnotationBorder ? 0 : 2, x: 0, y: 1)
                            .lineLimit(1)
                            .frame(height: 18, alignment: .leading)
                    } else {
                        Spacer().frame(height: 18)
                    }
                }
                
                HStack(spacing: 12) {
                    // Capsule Bar (已移除長條圖旁模糊外陰影，邊緣清晰俐落)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(
                                isDarkGlass
                                ? Color.white.opacity(0.07)
                                : Color.black.opacity(0.06)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        Color.white.opacity(isDarkGlass ? 0.08 : 0.15),
                                        lineWidth: 0.5
                                    )
                            )
                            .frame(width: trackWidth, height: 22)
                        
                        if barWidth > 0 {
                            let hasBottomVal = item.hasBottomValue(for: dim.id)
                            let bText = item.bottomDisplayString(for: dim.id)
                            
                            Capsule()
                                .fill(item.effectiveLinearGradient)
                                .frame(width: max(barWidth, 6), height: 22)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [.white.opacity(0.6), .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1.0
                                        )
                                    )
                                .overlay(alignment: .leading) {
                                    // 在單條長條圖最底部添加自選數字 (平滑渲染，杜絕抽動)
                                    if hasBottomVal && !bText.isEmpty && barWidth > 28 {
                                        HStack(spacing: 0) {
                                            Text(bText)
                                                .font(FontManager.shared.font(
                                                    family: fontFamily,
                                                    size: CGFloat(typography.bottomValueSize),
                                                    weight: .heavy,
                                                    design: .rounded,
                                                    isBoldMode: typography.isBoldMode
                                                ))
                                                .foregroundColor(.white)
                                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                                                .padding(.leading, 7)
                                                .fixedSize(horizontal: true, vertical: false)
                                            Spacer(minLength: 0)
                                        }
                                        .frame(width: barWidth, height: 22)
                                    }
                                }
                        }
                    }
                    .frame(width: trackWidth, height: 22, alignment: .leading)
                    
                    // Value and Unit (固定槽位寬高，移除 numericText 動畫衝突，杜絕高頻更新抽動)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(formattedNumber)
                            .font(FontManager.shared.font(
                                family: fontFamily,
                                size: CGFloat(typography.dataValueSize),
                                weight: .heavy,
                                design: .rounded,
                                isBoldMode: typography.isBoldMode
                            ))
                            .foregroundColor(isDarkGlass ? .white : Color(hex: "#0F172A"))
                            .shadow(color: isDarkGlass ? .black.opacity(0.3) : .clear, radius: 2, x: 0, y: 1)
                        
                        if !dim.unit.isEmpty {
                            Text(dim.unit)
                                .font(FontManager.shared.font(
                                    family: fontFamily,
                                    size: max(9, CGFloat(typography.dataValueSize) - 4),
                                    weight: .semibold,
                                    isBoldMode: typography.isBoldMode
                                ))
                                .foregroundColor(isDarkGlass ? Color(white: 0.65) : Color(hex: "#475569"))
                        }
                    }
                    .frame(width: numberWidth, height: 22, alignment: .leading)
                }
            }
            .frame(width: colWidth, alignment: .leading)
        }
    }
}
