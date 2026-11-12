import SwiftUI

public struct BarRowView: View {
    public var item: BenchmarkItem
    public var dimensions: [BenchmarkDimension]
    public var chartType: ChartType
    public var progress: Double // Animation progress for the capsule bar (supports spring bounce & overshoot)
    public var numberProgress: Double // Monotonic progress for the rolling counter (never drops)
    public var showAnnotations: Bool
    public var showAnnotationBorder: Bool
    public var isDarkGlass: Bool
    public var fontFamily: String
    
    public init(
        item: BenchmarkItem,
        dimensions: [BenchmarkDimension],
        chartType: ChartType = .horizontalBar,
        progress: Double,
        numberProgress: Double = 1.0,
        showAnnotations: Bool = true,
        showAnnotationBorder: Bool = true,
        isDarkGlass: Bool = true,
        fontFamily: String = "System Default"
    ) {
        self.item = item
        self.dimensions = dimensions
        self.chartType = chartType
        self.progress = progress
        self.numberProgress = numberProgress
        self.showAnnotations = showAnnotations
        self.showAnnotationBorder = showAnnotationBorder
        self.isDarkGlass = isDarkGlass
        self.fontFamily = fontFamily
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 20) {
            // Left Column: Product Title & Spec Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(FontManager.shared.font(family: fontFamily, size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(item.effectiveLinearGradient)
                    .lineLimit(1)
                    .shadow(color: item.effectiveGlowColor.opacity(0.4), radius: 6, x: 0, y: 1)
                
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(FontManager.shared.font(family: fontFamily, size: 12, weight: .medium))
                        .foregroundColor(isDarkGlass ? Color(white: 0.6) : Color(white: 0.35))
                        .lineLimit(1)
                }
            }
            .frame(width: 175, alignment: .leading)
            
            // Right Side: 並排顯示多個維度的橫向圓角長條圖（Capsule 形狀）或完全留空
            HStack(spacing: 24) {
                ForEach(dimensions) { dim in
                    dimensionBar(for: dim)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .opacity(min(max(progress * 1.5, 0.0), 1.0))
        .offset(y: (1.0 - min(max(progress, 0.0), 1.0)) * 14.0)
    }
    
    @ViewBuilder
    private func dimensionBar(for dim: BenchmarkDimension) -> some View {
        if dim.isBlankPlaceholder {
            // 完全留空（供後期剪輯軟體疊加自訂影片、圖層或散熱模組圖示）
            // 關鍵：使用與非留空欄位完全一致的幾何結構與固定寬度佔位，確保未留空指標欄位置完全固定不偏移
            VStack(alignment: .leading, spacing: 3) {
                if showAnnotations {
                    Spacer()
                        .frame(height: 15)
                }
                
                HStack(spacing: 12) {
                    Color.clear
                        .frame(height: 22)
                    
                    Color.clear
                        .frame(width: 68, height: 22)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            let rawVal = item.value(for: dim.id)
            let safeMax = max(dim.maxValue, 0.001)
            let baseRatio = max(0.0, min(rawVal / safeMax, 1.0))
            let currentRatio = baseRatio * max(0.0, progress)
            
            let displayTargetNumber: Double = rawVal
            let currentNumber = displayTargetNumber * min(max(numberProgress, 0.0), 1.0)
            let displayUnit: String = dim.unit
            let decimalPlaces: Int = dim.decimalPlaces
            let formattedNumber = String(format: "%.\(decimalPlaces)f", currentNumber)
            
            VStack(alignment: .leading, spacing: 3) {
                // 可選填附加頂部標註文字 (選填，如在特定長條圖上方顯示「8400 rpm / 9072 rpm」)
                if showAnnotations && !item.annotationText.isEmpty {
                    Text(item.annotationText)
                        .font(FontManager.shared.font(family: fontFamily, size: 10, weight: .bold, design: .monospaced))
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
                        .transition(.opacity)
                } else if showAnnotations {
                    // Reserve spacing to maintain row alignment if other items have annotations
                    Spacer()
                        .frame(height: 15)
                }
                
                HStack(spacing: 12) {
                    // Horizontal Capsule Bar
                    GeometryReader { geo in
                        let trackWidth = geo.size.width
                        let barWidth = min(max(trackWidth * currentRatio, 0), trackWidth * 1.1)
                        
                        ZStack(alignment: .leading) {
                            // Track Background
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
                                .frame(height: 22)
                            
                            // Active Animated Gradient Capsule
                            if barWidth > 0 {
                                Capsule()
                                    .fill(item.effectiveLinearGradient)
                                    .frame(width: max(barWidth, 6), height: 22)
                                    .overlay(
                                        // Top gloss highlight
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
                            }
                        }
                    }
                    .frame(height: 22)
                    
                    // Number Counter & Unit
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(formattedNumber)
                            .font(FontManager.shared.font(family: fontFamily, size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(isDarkGlass ? .white : Color(white: 0.15))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .contentTransition(.numericText())
                        
                        if !displayUnit.isEmpty {
                            Text(displayUnit)
                                .font(FontManager.shared.font(family: fontFamily, size: 11, weight: .semibold))
                                .foregroundColor(isDarkGlass ? Color(white: 0.65) : Color(white: 0.45))
                        }
                    }
                    .frame(width: 68, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
