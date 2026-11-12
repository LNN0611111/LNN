import SwiftUI

public struct VerticalGroupedBarChartView: View {
    public var items: [BenchmarkItem]
    public var dimensions: [BenchmarkDimension]
    public var verticalConfig: VerticalChartConfig
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
        verticalConfig: VerticalChartConfig,
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
        self.verticalConfig = verticalConfig
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
    
    public var body: some View {
        VStack(spacing: 12) {
            // Level 0: Top Legend Bar (圖例列)
            legendBar
            
            // MARK: - Main Chart Area (Y軸刻度 + 0%~100% 虛線輔助線 + 柱狀圖 + 虛線下指標名稱)
            GeometryReader { geo in
                let chartWidth = geo.size.width
                let chartHeight = geo.size.height
                let yAxisWidth: CGFloat = 46
                let dimensionLabelHeight: CGFloat = 26
                let plotWidth = max(chartWidth - yAxisWidth - 16, 100)
                
                // Available height for plot area (leaving space for dimension labels below 0% baseline)
                let totalPlotHeight = max(chartHeight - dimensionLabelHeight - 10, 120)
                
                // 動態計算所有非留空指標與項目的最高比例 (Max Ratio)
                let maxDataRatio: CGFloat = {
                    var highest: CGFloat = 1.0
                    for dim in dimensions where !dim.isBlankPlaceholder {
                        let safeMax = max(dim.maxValue, 0.001)
                        for item in items {
                            let rawVal = item.value(for: dim.id)
                            let (r, _, _) = computeBaselineRatio(for: item, in: dim, rawVal: rawVal, safeMax: safeMax)
                            if CGFloat(r) > highest {
                                highest = CGFloat(r)
                            }
                        }
                    }
                    return highest
                }()
                
                // 動態淨空空間 (Headroom)：
                // 額外納入彈簧物理 15% 衝出緩衝空間 (Overshoot Cushion)，確保即使自訂極限比例或衝出動畫時頂部亦擁有充裕淨空，杜絕抽動
                let effectiveMaxRatio = max(1.0, min(maxDataRatio, 2.5))
                let numberLabelReserved: CGFloat = verticalConfig.showBarValues ? 34 : 14
                let overshootHeadroomRatio: CGFloat = 1.15
                let baseHeight = max(50, (totalPlotHeight - numberLabelReserved) / (effectiveMaxRatio * overshootHeadroomRatio))
                let headroom = max(numberLabelReserved, totalPlotHeight - baseHeight)
                
                VStack(spacing: 8) {
                    // Level 1: Plot Area (Y-Axis + Grid Lines + Bars touching 0% and 100% exactly)
                    HStack(alignment: .top, spacing: 8) {
                        // Left Y-Axis labels (100%, 75%, 50%, 25%, 0%)
                        ZStack(alignment: .topTrailing) {
                            ForEach([100, 75, 50, 25, 0], id: \.self) { pct in
                                let yPos: CGFloat = headroom + (1.0 - CGFloat(pct) / 100.0) * baseHeight
                                
                                Text("\(pct)%")
                                    .font(FontManager.shared.font(
                                        family: fontFamily,
                                        size: 10,
                                        weight: .bold,
                                        design: .monospaced,
                                        isBoldMode: typography.isBoldMode
                                    ))
                                    .foregroundColor(isDarkGlass ? Color(white: 0.5) : Color(hex: "#334155"))
                                    .position(x: yAxisWidth - 14, y: yPos)
                            }
                        }
                        .frame(width: yAxisWidth, height: totalPlotHeight)
                        
                        // Chart Plot Container
                        ZStack(alignment: .topLeading) {
                            // Horizontal Grid Lines (100%, 75%, 50%, 25%, 0%)
                            ForEach([100, 75, 50, 25, 0], id: \.self) { pct in
                                let yPos: CGFloat = headroom + (1.0 - CGFloat(pct) / 100.0) * baseHeight
                                
                                Line()
                                    .stroke(
                                        style: StrokeStyle(
                                            lineWidth: pct == 0 ? 1.2 : 1.0,
                                            dash: pct == 0 ? [] : [4, 4]
                                        )
                                    )
                                    .foregroundColor(
                                        pct == 0
                                        ? (isDarkGlass ? Color.white.opacity(0.4) : Color.black.opacity(0.45))
                                        : (isDarkGlass ? Color.white.opacity(0.12) : Color.black.opacity(0.2))
                                    )
                                    .frame(width: plotWidth, height: 1)
                                    .position(x: plotWidth / 2.0, y: yPos)
                            }
                            
                            // Grouped Vertical Bars (起點貼緊 0% 底線，100% 終點精確貼齊 100% 虛線)
                            HStack(alignment: .bottom, spacing: 0) {
                                let groupWidth = plotWidth / CGFloat(max(dimensions.count, 1))
                                
                                ForEach(dimensions) { dim in
                                    if dim.isBlankPlaceholder {
                                        // 留空欄位：完全透明保留精確網格寬度，供後期剪輯自行加入圖層
                                        Color.clear
                                            .frame(width: groupWidth, height: totalPlotHeight)
                                    } else {
                                        HStack(alignment: .bottom, spacing: max(4, min(10, 20 / CGFloat(max(items.count, 1))))) {
                                            let barWidth: CGFloat = max(18, min(34, (groupWidth - 24) / CGFloat(max(items.count, 1))))
                                            
                                            ForEach(items) { item in
                                                let progress = rowProgresses[item.id] ?? 1.0
                                                let numProgress = numberProgresses[item.id] ?? 1.0
                                                
                                                verticalBarItem(
                                                    item: item,
                                                    dimension: dim,
                                                    baseHeight: baseHeight,
                                                    headroom: headroom,
                                                    barWidth: barWidth,
                                                    progress: progress,
                                                    numberProgress: numProgress
                                                )
                                            }
                                        }
                                        .frame(width: groupWidth, height: totalPlotHeight, alignment: .bottom)
                                    }
                                }
                            }
                            .frame(width: plotWidth, height: totalPlotHeight, alignment: .bottomLeading)
                        }
                        .frame(width: plotWidth, height: totalPlotHeight)
                    }
                    
                    // Level 2: Dimension Labels Row (指標名稱完全移至 0% 虛線基準線下方)
                    HStack(spacing: 8) {
                        Color.clear
                            .frame(width: yAxisWidth, height: dimensionLabelHeight)
                        
                        HStack(spacing: 0) {
                            let groupWidth = plotWidth / CGFloat(max(dimensions.count, 1))
                            
                            ForEach(dimensions) { dim in
                                if dim.isBlankPlaceholder {
                                    Color.clear
                                        .frame(width: groupWidth, height: dimensionLabelHeight)
                                } else {
                                    let dimColor: Color = {
                                        if let customHex = dim.customColorHex, !customHex.isEmpty {
                                            return Color(hex: customHex)
                                        }
                                        if container.useCustomDimensionColor {
                                            return Color(hex: container.dimensionHeaderColorHex)
                                        }
                                        return isDarkGlass ? Color(white: 0.85) : Color(hex: "#0F172A")
                                    }()
                                    
                                    Text(dim.name)
                                        .font(FontManager.shared.font(
                                            family: fontFamily,
                                            size: CGFloat(typography.dimensionHeaderSize),
                                            weight: .bold,
                                            isBoldMode: typography.isBoldMode
                                        ))
                                        .foregroundColor(dimColor)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                        .multilineTextAlignment(.center)
                                        .frame(width: groupWidth, height: dimensionLabelHeight, alignment: .center)
                                }
                            }
                        }
                        .frame(width: plotWidth)
                    }
                }
            }
            .frame(minHeight: 250)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Single Vertical Bar Item View
    @ViewBuilder
    private func verticalBarItem(
        item: BenchmarkItem,
        dimension: BenchmarkDimension,
        baseHeight: CGFloat,
        headroom: CGFloat,
        barWidth: CGFloat,
        progress: Double,
        numberProgress: Double
    ) -> some View {
        let rawVal = item.value(for: dimension.id)
        let safeMax = max(dimension.maxValue, 0.001)
        
        // 100% 基準項目設定與自動百分比數值轉換
        let (targetRatio, displayValue, isPercentage) = computeBaselineRatio(for: item, in: dimension, rawVal: rawVal, safeMax: safeMax)
        
        let totalPlotHeight = baseHeight + headroom
        let currentRatio = targetRatio * max(0.0, progress)
        let barHeight = max(2.0, baseHeight * CGFloat(currentRatio))
        
        let currentNumber = displayValue * min(max(numberProgress, 0.0), 1.0)
        let formattedNumber: String = isPercentage
            ? String(format: "%.0f%%", currentNumber)
            : String(format: "%.\(dimension.decimalPlaces)f", currentNumber)
        
        // Active Colored Bar (已徹底刪除隱形背景框，底部平整貼齊 0% 底線，頂部圓角精確貼齊 100% 虛線)
        let hasBottomVal = item.hasBottomValue(for: dimension.id)
        let bottomText = item.bottomDisplayString(for: dimension.id)
        
        let activeBar = TopRoundedRectangle(radius: 4)
            .fill(item.effectiveLinearGradient)
            .frame(width: barWidth, height: barHeight)
            .overlay(
                TopRoundedRectangle(radius: 4)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.7), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.0
                    )
            )
            .overlay(alignment: .bottom) {
                // 選項：在單一一條長條圖最底部添加自選數字 (比照附圖 2 對比效果)
                if hasBottomVal && !bottomText.isEmpty && barHeight > 18 {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        
                        if let bVal = item.bottomValue(for: dimension.id), rawVal > 0 {
                            let subRatio = min(0.92, max(0.08, bVal / rawVal))
                            let subHeight = max(16, barHeight * CGFloat(subRatio))
                            
                            TopRoundedRectangle(radius: 3)
                                .fill(Color.black.opacity(0.25))
                                .overlay(
                                    TopRoundedRectangle(radius: 3)
                                        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                                )
                                .frame(width: max(4, barWidth - 2), height: subHeight)
                                .overlay(alignment: .bottom) {
                                    Text(bottomText)
                                        .font(FontManager.shared.font(
                                            family: fontFamily,
                                            size: max(8, CGFloat(typography.bottomValueSize)),
                                            weight: .heavy,
                                            design: .rounded,
                                            isBoldMode: typography.isBoldMode
                                        ))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                                        .padding(.bottom, 4)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                        } else {
                            Text(bottomText)
                                .font(FontManager.shared.font(
                                    family: fontFamily,
                                    size: max(8, CGFloat(typography.bottomValueSize)),
                                    weight: .heavy,
                                    design: .rounded,
                                    isBoldMode: typography.isBoldMode
                                ))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                                .padding(.bottom, 5)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .frame(width: barWidth, height: barHeight, alignment: .bottom)
                }
            }
        
        // Number Counter Label (字體大小全項目完全一致，移除 numericText 動畫衝突，杜絕高頻更新抽動)
        let numberLabel = Text(formattedNumber)
            .font(FontManager.shared.font(
                family: fontFamily,
                size: CGFloat(typography.dataValueSize),
                weight: .heavy,
                design: .rounded,
                isBoldMode: typography.isBoldMode
            ))
            .foregroundColor(isDarkGlass ? .white : Color(hex: "#0F172A"))
            .shadow(color: isDarkGlass ? .black.opacity(0.35) : .clear, radius: 2, x: 0, y: 1)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(width: max(barWidth, 38), alignment: .center)
        
        // 組合長條圖與數值標籤（底層對齊 + offset 浮動，完全避免容器高度擠壓造成的抽動問題）
        if !verticalConfig.showBarValues {
            // 用戶選擇不顯示數值時，僅繪製柱狀圖
            ZStack(alignment: .bottom) {
                activeBar
            }
            .frame(width: max(barWidth, 38), height: totalPlotHeight, alignment: .bottom)
        } else if verticalConfig.valuePosition == .onTopGridLine {
            // 選項 2：呈現在 100% 虛線上（若單項超過 100% 則自動浮動於柱頂不被遮擋）
            let labelBottomOffset = max(baseHeight + 3, barHeight + 3)
            ZStack(alignment: .bottom) {
                activeBar
                
                numberLabel
                    .offset(y: -labelBottomOffset)
            }
            .frame(width: max(barWidth, 38), height: totalPlotHeight, alignment: .bottom)
        } else {
            // 選項 3：隨長條圖頂端顯示（預設：數值平滑跟隨長條圖頂部上升，絕不發生版面擠壓抽動）
            let labelBottomOffset = barHeight + 3
            ZStack(alignment: .bottom) {
                activeBar
                
                numberLabel
                    .offset(y: -labelBottomOffset)
            }
            .frame(width: max(barWidth, 38), height: totalPlotHeight, alignment: .bottom)
        }
    }
    
    // MARK: - Baseline Computation
    private func computeBaselineRatio(
        for item: BenchmarkItem,
        in dimension: BenchmarkDimension,
        rawVal: Double,
        safeMax: Double
    ) -> (ratio: Double, displayVal: Double, isPct: Bool) {
        switch verticalConfig.baselineMode {
        case .none:
            let r = max(0.0, min(rawVal / safeMax, 2.5))
            return (r, rawVal, false)
            
        case .productBaseline:
            let baseItem = items.first(where: { $0.id == verticalConfig.baselineItemId }) ?? items.first
            let baseVal = max(baseItem?.value(for: dimension.id) ?? safeMax, 0.0001)
            let ratio = rawVal / baseVal
            let clampedRatio = max(0.0, min(ratio, 2.5))
            let pct = ratio * 100.0
            if verticalConfig.showPercentageNumber {
                return (clampedRatio, pct, true)
            } else {
                return (clampedRatio, rawVal, false)
            }
            
        case .groupMax:
            let groupHighest = items.map { $0.value(for: dimension.id) }.max() ?? safeMax
            let safeGroupHighest = max(groupHighest, 0.0001)
            let ratio = rawVal / safeGroupHighest
            let clampedRatio = max(0.0, min(ratio, 2.5))
            let pct = ratio * 100.0
            if verticalConfig.showPercentageNumber {
                return (clampedRatio, pct, true)
            } else {
                return (clampedRatio, rawVal, false)
            }
        }
    }
    
    // MARK: - Top Legend Bar (圖例列)
    private var legendBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    let isBaseline = (verticalConfig.baselineMode == .productBaseline) &&
                        ((item.id == verticalConfig.baselineItemId) || (verticalConfig.baselineItemId == nil && item.id == items.first?.id))
                    
                    HStack(spacing: 6) {
                        // Colored Pill
                        RoundedRectangle(cornerRadius: 3)
                            .fill(item.effectiveLinearGradient)
                            .frame(width: 14, height: 14)
                        
                        Text(item.title)
                            .font(FontManager.shared.font(
                                family: fontFamily,
                                size: CGFloat(typography.productTitleSize),
                                weight: .bold,
                                isBoldMode: typography.isBoldMode
                            ))
                            .foregroundStyle(item.effectiveLinearGradient)
                        
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(FontManager.shared.font(
                                    family: fontFamily,
                                    size: CGFloat(typography.productSubtitleSize),
                                    weight: .medium,
                                    isBoldMode: typography.isBoldMode
                                ))
                                .foregroundColor(isDarkGlass ? Color(white: 0.6) : Color(hex: "#334155"))
                        }
                        
                        if isBaseline {
                            Text("100% 基準")
                                .font(FontManager.shared.font(
                                    family: fontFamily,
                                    size: 9,
                                    weight: .bold,
                                    isBoldMode: typography.isBoldMode
                                ))
                                .foregroundColor(Color(hex: "#10B981"))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color(hex: "#10B981").opacity(0.2))
                                .cornerRadius(3)
                        }
                        
                        if showAnnotations && !item.annotationText.isEmpty {
                            Text(item.annotationText)
                                .font(FontManager.shared.font(
                                    family: fontFamily,
                                    size: CGFloat(typography.annotationSize),
                                    weight: .bold,
                                    design: .monospaced,
                                    isBoldMode: typography.isBoldMode
                                ))
                                .foregroundColor(isDarkGlass ? Color.white.opacity(0.85) : Color(hex: "#0F172A"))
                                .padding(.horizontal, showAnnotationBorder ? 5 : 2)
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
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isDarkGlass ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                    )
                }
            }
            
            Spacer()
            
            // Unit Legend
            if verticalConfig.baselineMode != .none && verticalConfig.showPercentageNumber {
                Text(l10n("基準對比 (100%)", "Baseline Index (100%)"))
                    .font(FontManager.shared.font(
                        family: fontFamily,
                        size: 11,
                        weight: .medium,
                        isBoldMode: typography.isBoldMode
                    ))
                    .foregroundColor(isDarkGlass ? Color(white: 0.5) : Color(white: 0.45))
            } else if let firstDim = dimensions.first(where: { !$0.isBlankPlaceholder }), !firstDim.unit.isEmpty {
                Text(l10n("單位: \(firstDim.unit)", "Unit: \(firstDim.unit)"))
                    .font(FontManager.shared.font(
                        family: fontFamily,
                        size: 11,
                        weight: .medium,
                        isBoldMode: typography.isBoldMode
                    ))
                    .foregroundColor(isDarkGlass ? Color(white: 0.5) : Color(white: 0.45))
            }
        }
        .padding(.horizontal, 4)
    }
}

// Helper Shape for Dashed Grid Lines
fileprivate struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

fileprivate struct TopRoundedRectangle: Shape {
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
