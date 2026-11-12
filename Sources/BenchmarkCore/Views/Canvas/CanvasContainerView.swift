import SwiftUI

public struct CanvasContainerView: View {
    public var project: BenchmarkProject
    public var headerProgress: Double
    public var containerProgress: Double
    public var rowProgresses: [UUID: Double]
    public var numberProgresses: [UUID: Double]
    public var isExportMode: Bool // If true, do not show checkerboard if background is transparent
    public var customExportVideoFrame: CGImage?
    public var currentTime: Double
    
    public init(
        project: BenchmarkProject,
        headerProgress: Double = 1.0,
        containerProgress: Double = 1.0,
        rowProgresses: [UUID: Double] = [:],
        numberProgresses: [UUID: Double] = [:],
        isExportMode: Bool = false,
        customExportVideoFrame: CGImage? = nil,
        currentTime: Double = 0.0
    ) {
        self.project = project
        self.headerProgress = headerProgress
        self.containerProgress = containerProgress
        self.rowProgresses = rowProgresses
        self.numberProgresses = numberProgresses
        self.isExportMode = isExportMode
        self.customExportVideoFrame = customExportVideoFrame
        self.currentTime = currentTime
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
            
        case .animatedPattern:
            AnimatedPatternBackgroundView(
                config: project.patternConfig,
                isExportMode: isExportMode,
                currentTime: currentTime
            )
        }
    }
    
    // MARK: - Center Chart Container
    @ViewBuilder
    private var chartContainer: some View {
        let isDark = project.container.glassMode == .dark
        let fontFamily = project.typography.fontFamily
        let refSize = project.aspectRatio.referenceSize
        let isGreenScreen = (project.backgroundMode == .greenScreen)
        
        ZStack(alignment: .center) {
            // 毛玻璃效果與背景層 (綠幕模式下強制採用 100% 不透明純色底色，徹底杜絕綠光穿透與後期摳像穿孔)
            if isGreenScreen {
                if isDark {
                    RoundedRectangle(cornerRadius: project.container.cornerRadius)
                        .fill(Color(hex: "#0F172A")) // 100% 不透明沉穩曜黑/深岩灰底色
                        .overlay(
                            RoundedRectangle(cornerRadius: project.container.cornerRadius)
                                .fill(Color(hex: "#1E293B").opacity(0.35))
                        )
                } else {
                    RoundedRectangle(cornerRadius: project.container.cornerRadius)
                        .fill(Color(hex: "#FFFFFF")) // 100% 不透明純淨亮白底色
                }
            } else {
                let trans = project.container.glassTransparency
                // 通透度計算：trans=0.05 (濃郁磨砂, 遮蔽度高), trans=0.98 (極限透明, 幾近全透)
                let matOpacity = max(0.04, 1.0 - trans)
                let tintOpacity = (1.0 - trans) * (isDark ? 0.38 : 0.42)
                
                if isDark {
                    RoundedRectangle(cornerRadius: project.container.cornerRadius)
                        .fill(Color(hex: "#05070B").opacity(0.40 * (1.0 - trans))) // 基礎沉穩黑底，杜絕離屏渲染翻白
                        .overlay(
                            RoundedRectangle(cornerRadius: project.container.cornerRadius)
                                .fill(.ultraThinMaterial)
                                .opacity(matOpacity)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: project.container.cornerRadius)
                                .fill(Color.black.opacity(tintOpacity))
                        )
                } else {
                    RoundedRectangle(cornerRadius: project.container.cornerRadius)
                        .fill(.thinMaterial)
                        .opacity(matOpacity)
                        .overlay(
                            RoundedRectangle(cornerRadius: project.container.cornerRadius)
                                .fill(Color.white.opacity(tintOpacity))
                        )
                }
            }
            
            // 細微亮邊框 (1px 漸層描邊，綠幕模式採用不透綠純淨漸層)
            if project.container.showHighlightBorder {
                RoundedRectangle(cornerRadius: project.container.cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: isGreenScreen ? (isDark ? [
                                Color.white.opacity(0.45),
                                Color(hex: "#334155"),
                                Color(hex: "#1E293B")
                            ] : [
                                Color(hex: "#CBD5E1"),
                                Color(hex: "#94A3B8")
                            ]) : (isDark ? [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.04)
                            ] : [
                                Color.white.opacity(0.9),
                                Color.black.opacity(0.15)
                            ]),
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
                        container: project.container,
                        showBarValues: project.verticalConfig.showBarValues
                    )
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .opacity(min(max(containerProgress, 0.0), 1.0))
        .offset(y: (1.0 - min(max(containerProgress, 0.0), 1.0)) * 12.0)
        .environment(\.colorScheme, isDark ? .dark : .light)
    }
}
