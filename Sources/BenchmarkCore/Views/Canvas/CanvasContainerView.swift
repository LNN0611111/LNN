import SwiftUI

public struct CanvasContainerView: View {
    public var project: BenchmarkProject
    public var headerProgress: Double
    public var containerProgress: Double
    public var rowProgresses: [UUID: Double]
    public var numberProgresses: [UUID: Double]
    public var isExportMode: Bool // If true, do not show checkerboard if background is transparent
    public var customExportVideoFrame: CGImage?
    
    public init(
        project: BenchmarkProject,
        headerProgress: Double = 1.0,
        containerProgress: Double = 1.0,
        rowProgresses: [UUID: Double] = [:],
        numberProgresses: [UUID: Double] = [:],
        isExportMode: Bool = false,
        customExportVideoFrame: CGImage? = nil
    ) {
        self.project = project
        self.headerProgress = headerProgress
        self.containerProgress = containerProgress
        self.rowProgresses = rowProgresses
        self.numberProgresses = numberProgresses
        self.isExportMode = isExportMode
        self.customExportVideoFrame = customExportVideoFrame
    }
    
    // Primary accent color taken from the first item or purple default
    private var primaryAccent: Color {
        if let first = project.items.first {
            return Color(hex: first.effectiveStartColorHex)
        }
        return Color(hex: "#A855F7")
    }
    
    public var body: some View {
        let refSize = project.aspectRatio.referenceSize
        let fontFamily = project.typography.fontFamily
        
        ZStack {
            // 1. 底部背景 (Background Layer)
            backgroundLayer
            
            // 2. 內容疊加 (Content Overlay)
            VStack(spacing: 16) {
                // 頂部標題區：左側顯示圓角矩形發光圖示，右側為粗斜體大字主標題與灰色副標題
                HeaderBarView(
                    header: project.header,
                    primaryAccent: primaryAccent,
                    progress: headerProgress,
                    fontFamily: fontFamily,
                    typography: project.typography,
                    isLightBackground: project.backgroundMode == .gradientLight
                )
                
                // 中央圖表容器：毛玻璃效果、圓角矩形、細微亮邊框
                chartContainer
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: refSize.width, height: refSize.height)
        .clipped()
        .allowsHitTesting(false)
    }
    
    // MARK: - Background Layer
    @ViewBuilder
    private var backgroundLayer: some View {
        switch project.backgroundMode {
        case .transparent:
            if isExportMode {
                // Fully transparent for ProRes 4444 / HEVC Alpha export
                Color.clear
            } else {
                // Checkerboard in editor preview to indicate alpha transparency
                CheckerboardView(squareSize: 18)
            }
            
        case .greenScreen:
            // Standard Chroma Key Green (#00FF00) for video editors (Premiere Ultra Key, FCP, DaVinci)
            Color(hex: "#00FF00")
            
        case .customMedia:
            if isExportMode, let videoFrame = customExportVideoFrame {
                MediaFrameView(
                    cgImage: videoFrame,
                    cropAspectRatio: project.customVideoConfig.cropAspectRatio,
                    contentMode: project.customVideoConfig.contentMode
                )
            } else {
                CustomMediaBackgroundView(
                    filePath: project.customMediaFilePath,
                    videoConfig: project.customVideoConfig
                )
            }
            
        case .gradientDark:
            RadialGradient(
                colors: [
                    Color(hex: "#1E1B4B").opacity(0.85),
                    Color(hex: "#0F172A"),
                    Color(hex: "#020617")
                ],
                center: .center,
                startRadius: 50,
                endRadius: 750
            )
            
        case .gradientLight:
            LinearGradient(
                colors: [
                    Color(hex: "#F8FAFC"),
                    Color(hex: "#E2E8F0")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Center Chart Container
    @ViewBuilder
    private var chartContainer: some View {
        let isDark = project.container.glassMode == .dark
        let fontFamily = project.typography.fontFamily
        let refSize = project.aspectRatio.referenceSize
        
        ZStack(alignment: .center) {
            // 毛玻璃效果與背景層
            if isDark {
                RoundedRectangle(cornerRadius: project.container.cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: project.container.cornerRadius)
                            .fill(Color.black.opacity(0.48))
                    )
            } else {
                RoundedRectangle(cornerRadius: project.container.cornerRadius)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: project.container.cornerRadius)
                            .fill(Color.white.opacity(0.75))
                    )
            }
            
            // 細微亮邊框 (1px 漸層白色/黑色的半透明描邊)
            if project.container.showHighlightBorder {
                RoundedRectangle(cornerRadius: project.container.cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: isDark ? [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.04)
                            ] : [
                                Color.white.opacity(0.9),
                                Color.black.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            }
            
            // 兩種圖表呈現方式（垂直與水平完美置中，重現初版經典平衡美感）
            VStack {
                Spacer(minLength: 0)
                
                if project.chartType == .verticalGroupedBar {
                    VerticalGroupedBarChartView(
                        items: project.items,
                        dimensions: project.dimensions,
                        verticalConfig: project.verticalConfig,
                        rowProgresses: rowProgresses,
                        numberProgresses: numberProgresses,
                        showAnnotations: project.container.showTopAnnotations,
                        showAnnotationBorder: project.container.showAnnotationBorder,
                        isDarkGlass: isDark,
                        fontFamily: fontFamily,
                        typography: project.typography,
                        showDimensionMaxValue: project.container.showDimensionMaxValue,
                        productColumnTitle: project.container.productColumnTitle,
                        container: project.container
                    )
                } else {
                    HorizontalBarChartView(
                        items: project.items,
                        dimensions: project.dimensions,
                        chartType: project.chartType,
                        canvasWidth: refSize.width,
                        rowProgresses: rowProgresses,
                        numberProgresses: numberProgresses,
                        showAnnotations: project.container.showTopAnnotations,
                        showAnnotationBorder: project.container.showAnnotationBorder,
                        isDarkGlass: isDark,
                        fontFamily: fontFamily,
                        typography: project.typography,
                        showDimensionMaxValue: project.container.showDimensionMaxValue,
                        productColumnTitle: project.container.productColumnTitle,
                        container: project.container
                    )
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .opacity(min(max(containerProgress, 0.0), 1.0))
        .offset(y: (1.0 - min(max(containerProgress, 0.0), 1.0)) * 12.0)
    }
}
