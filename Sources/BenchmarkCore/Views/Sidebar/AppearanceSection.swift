import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class AppearanceSectionState: ObservableObject {
    @Published var isShowingVideoTrimModal: Bool = false
    init() {}
}

public struct AppearanceSection: View {
    @Binding public var chartType: ChartType
    @Binding public var backgroundMode: BackgroundMode
    @Binding public var aspectRatio: CanvasAspectRatio
    @Binding public var customMediaFilePath: String?
    @Binding public var container: ContainerConfig
    @Binding public var verticalConfig: VerticalChartConfig
    @Binding public var customVideoConfig: CustomVideoConfig
    public var items: [BenchmarkItem]
    public var animationDuration: Double
    
    @StateObject private var state = AppearanceSectionState()
    
    public init(
        chartType: Binding<ChartType>,
        backgroundMode: Binding<BackgroundMode>,
        aspectRatio: Binding<CanvasAspectRatio>,
        customMediaFilePath: Binding<String?>,
        container: Binding<ContainerConfig>,
        verticalConfig: Binding<VerticalChartConfig>,
        customVideoConfig: Binding<CustomVideoConfig> = .constant(CustomVideoConfig()),
        items: [BenchmarkItem] = [],
        animationDuration: Double = 3.5
    ) {
        self._chartType = chartType
        self._backgroundMode = backgroundMode
        self._aspectRatio = aspectRatio
        self._customMediaFilePath = customMediaFilePath
        self._container = container
        self._verticalConfig = verticalConfig
        self._customVideoConfig = customVideoConfig
        self.items = items
        self.animationDuration = animationDuration
    }
    
    public var body: some View {
        SidebarSectionCard(title: l10n("圖表外觀、比例與背景設定", "Chart Style, Ratio & Background"), systemImage: "paintpalette.fill") {
            VStack(alignment: .leading, spacing: 12) {
                // 1. Overall Canvas Aspect Ratio (畫面比例調整)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(l10n("整體畫面比例", "Canvas Aspect Ratio"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(aspectRatio.rawValue.components(separatedBy: " ").first ?? "16:9")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#60A5FA"))
                    }
                    
                    Picker("", selection: $aspectRatio) {
                        ForEach(CanvasAspectRatio.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text(l10n("所有文字、發光圖示、長條圖與毛玻璃邊框均隨比例進行等比例縮放適配。", "All elements, icons, bars, and containers scale proportionally."))
                        .font(.system(size: 9))
                        .foregroundColor(Color(white: 0.6))
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // 2. Chart Presentation Type Selection (2 modes: 橫向長條圖 (預設) vs 縱向分組比例圖 - 已去除括號附圖樣式)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(l10n("圖表呈現方式", "Chart Presentation Style"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(chartType == .horizontalBar ? l10n("橫向長條圖", "Horizontal Bar") : l10n("縱向分組比例圖", "Vertical Grouped"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#60A5FA"))
                    }
                    
                    Picker("", selection: $chartType) {
                        ForEach(ChartType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 2.1 縱向模式專屬設定：100% 基準項目設定與自動百分比數值轉換
                if chartType == .verticalGroupedBar {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(l10n("縱向圖表 100% 基準設定", "100% Baseline Setting"), systemImage: "percent")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#A855F7"))
                            Spacer()
                        }
                        
                        Picker(l10n("基準模式", "Baseline Mode"), selection: $verticalConfig.baselineMode) {
                            ForEach(VerticalBaselineMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        if verticalConfig.baselineMode == .productBaseline && !items.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("選擇 100% 基準產品", "Select 100% Baseline Product"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: Binding<UUID>(
                                    get: { verticalConfig.baselineItemId ?? items.first?.id ?? UUID() },
                                    set: { verticalConfig.baselineItemId = $0 }
                                )) {
                                    ForEach(items) { item in
                                        Text(item.title).tag(item.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        
                        if verticalConfig.baselineMode != .none {
                            Toggle(l10n("柱頂自動顯示轉換後百分比數值 (%)", "Show values as percentage (%)"), isOn: $verticalConfig.showPercentageNumber)
                                .font(.system(size: 10))
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // 數值顯示開關與呈現位置 (隨長條圖頂端 vs 呈現在 100% 虛線上)
                        Toggle(l10n("在長條圖上顯示數值", "Show Numbers on Bars"), isOn: $verticalConfig.showBarValues)
                            .font(.system(size: 10, weight: .semibold))
                        
                        if verticalConfig.showBarValues {
                            Picker(l10n("數值呈現位置", "Value Display Position"), selection: $verticalConfig.valuePosition) {
                                ForEach(VerticalValuePosition.allCases) { pos in
                                    Text(pos.rawValue).tag(pos)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                }
                
                // 3. Container Glass Style
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n("中央容器毛玻璃效果", "Center Glass Container"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $container.glassMode) {
                        ForEach(GlassMaterialMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }
                
                // 4. Highlight Border & Corner Radius
                Toggle(l10n("啟用細微亮邊框 (1px 漸層描邊)", "Enable 1px Gradient Highlight Border"), isOn: $container.showHighlightBorder)
                    .font(.system(size: 12))
                
                Toggle(l10n("顯示長條圖正上方附加標註文字", "Show Top Annotation Text"), isOn: $container.showTopAnnotations)
                    .font(.system(size: 12))
                
                if container.showTopAnnotations {
                    Toggle(l10n("頂部標註文字顯示外框", "Show Border on Annotations"), isOn: $container.showAnnotationBorder)
                        .font(.system(size: 11))
                        .padding(.leading, 12)
                }
                
                Toggle(l10n("在圖表表頭顯示比例上限文字 (例：(上限 100W))", "Show Max Value in Headers"), isOn: $container.showDimensionMaxValue)
                    .font(.system(size: 12))
                
                // 5. Background Mode (Includes 綠幕 Green Screen)
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n("底部背景模式", "Canvas Background Mode"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $backgroundMode) {
                        ForEach(BackgroundMode.allCases) { mode in
                            HStack(spacing: 6) {
                                if mode == .greenScreen {
                                    Circle().fill(Color(hex: "#00FF00")).frame(width: 10, height: 10)
                                }
                                Text(mode.rawValue)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    
                    if backgroundMode == .customMedia {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button(action: pickCustomMedia) {
                                    Label(
                                        customMediaFilePath != nil ? l10n("更換背景檔", "Change Background File") : l10n("匯入背景檔 (PNG/JPG/MP4/MOV)", "Import File (PNG/JPG/MP4/MOV)"),
                                        systemImage: "folder.badge.plus"
                                    )
                                    .font(.system(size: 11))
                                }
                                .buttonStyle(.bordered)
                                
                                if customMediaFilePath != nil {
                                    Button(l10n("清除", "Clear"), role: .destructive) {
                                        customMediaFilePath = nil
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.system(size: 11))
                                }
                            }
                            
                            if let path = customMediaFilePath {
                                let isVideo = ["mp4", "mov", "m4v"].contains(URL(fileURLWithPath: path).pathExtension.lowercased())
                                
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                if isVideo {
                                    // 影片剪輯長度與比例按鈕
                                    Button(action: { state.isShowingVideoTrimModal = true }) {
                                        Label(l10n("🎬 裁剪影片長度與比例", "Trim Video Length & Ratio"), systemImage: "scissors")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(Color(hex: "#60A5FA"))
                                    
                                    // 剪輯參數摘要
                                    HStack(spacing: 8) {
                                        Text(l10n("起點: \(String(format: "%.1f", customVideoConfig.trimStartTime))s", "Start: \(String(format: "%.1f", customVideoConfig.trimStartTime))s"))
                                        Text("|")
                                        Text(customVideoConfig.trimEndTime > 0 ? l10n("終點: \(String(format: "%.1f", customVideoConfig.trimEndTime))s", "End: \(String(format: "%.1f", customVideoConfig.trimEndTime))s") : l10n("終點: 完整", "End: Full"))
                                        Text("|")
                                        Text(customVideoConfig.contentMode == "fill" ? l10n("填滿", "Fill") : l10n("適應", "Fit"))
                                    }
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    
                                    // 超長播放選項
                                    Toggle(
                                        l10n("影片長於動畫時繼續播放背景直到影片結束", "Continue playing video background if longer than chart"),
                                        isOn: $customVideoConfig.extendPlaybackUntilVideoEnds
                                    )
                                    .font(.system(size: 10, weight: .semibold))
                                    
                                    Text(l10n("啟用後若影片長於圖表動畫，背景影片將持續播放至結束，數據圖表維持結束態。", "If enabled, video plays until end while chart stays at completed final state."))
                                        .font(.system(size: 9))
                                        .foregroundColor(Color(white: 0.6))
                                }
                            }
                        }
                        .padding(.top, 4)
                        .sheet(isPresented: $state.isShowingVideoTrimModal) {
                            if let path = customMediaFilePath {
                                VideoTrimCropModalView(
                                    videoURL: URL(fileURLWithPath: path),
                                    config: $customVideoConfig,
                                    chartDuration: animationDuration,
                                    onApply: {
                                        state.isShowingVideoTrimModal = false
                                    },
                                    onCancel: {
                                        state.isShowingVideoTrimModal = false
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func pickCustomMedia() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .png, .jpeg, .mpeg4Movie, .quickTimeMovie,
            UTType(filenameExtension: "mp4") ?? .movie,
            UTType(filenameExtension: "mov") ?? .movie
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            customMediaFilePath = url.path
        }
    }
}
