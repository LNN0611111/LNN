import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var selectedTab: Int = 0
    @Published public var cacheSizeBytes: Int64 = 0
    @Published public var cacheStatusMessage: String = ""
    @Published public var fontStatusMessage: String = ""
    
    public init() {}
}

public struct SettingsModalView: View {
    @Binding public var project: BenchmarkProject
    @Binding public var isPresented: Bool
    
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var fontMgr = FontManager.shared
    @StateObject private var vm = SettingsViewModel()
    
    public init(
        project: Binding<BenchmarkProject>,
        isPresented: Binding<Bool>
    ) {
        self._project = project
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Label(l10n("軟體偏好設定", "Preferences & Settings"), systemImage: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 12)
            
            Divider()
            
            // Tab Selector
            Picker("", selection: $vm.selectedTab) {
                Text(l10n("介面與圖表", "Interface & Chart")).tag(0)
                Text(l10n("字體管理", "Typography & Fonts")).tag(1)
                Text(l10n("快取與效能", "Cache & Storage")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if vm.selectedTab == 0 {
                        interfaceAndChartTab
                    } else if vm.selectedTab == 1 {
                        typographyTab
                    } else {
                        cacheTab
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
            .frame(height: 340)
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button(l10n("完成", "Done")) {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#7C3AED"))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
        .frame(width: 540)
        .background(Color(white: 0.13))
        .onAppear {
            refreshCacheSize()
        }
    }
    
    // MARK: - Tab 0: Interface & Chart Style
    private var interfaceAndChartTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Language Option
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n("1. 介面語言 (Language)", "1. Interface Language"))
                    .font(.system(size: 13, weight: .bold))
                
                Picker("", selection: Binding(
                    get: { loc.currentLanguage },
                    set: { newLang in
                        loc.currentLanguage = newLang
                        project.language = newLang
                    }
                )) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                
                Text(l10n("切換語言將即時套用於整個軟體操作介面、按鈕與導出設定。", "Switching language applies instantly across all controls, buttons, and export dialogs."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 2. Chart Presentation Style
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n("2. 圖表呈現方式 (Chart Display Mode)", "2. Chart Display Mode"))
                    .font(.system(size: 13, weight: .bold))
                
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: { project.chartType = .horizontalBar }) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: project.chartType == .horizontalBar ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(project.chartType == .horizontalBar ? Color(hex: "#A855F7") : .secondary)
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(l10n("橫向長條圖 (預設)", "Horizontal Bar Chart (Default)"))
                                    .font(.system(size: 12, weight: .bold))
                                Text(l10n("經典評測長條圖。左側為產品名稱，右側延伸橫向彩色膠囊長條與數值。", "Classic benchmark horizontal bars. Product on left, animated gradient capsules on right."))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { project.chartType = .verticalGroupedBar }) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: project.chartType == .verticalGroupedBar ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(project.chartType == .verticalGroupedBar ? Color(hex: "#A855F7") : .secondary)
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(l10n("縱向分組比例圖", "Vertical Grouped Ratio Chart"))
                                    .font(.system(size: 12, weight: .bold))
                                Text(l10n("縱向比例柱狀圖。Y 軸帶 0%~100% 虛線刻度，底部按維度分組，組內並列各產品垂直柱狀圖，頂端標註數值。", "Vertical grouped bars. 0%~100% dashed Y-grid, grouped by dimension on X-axis with top numbers and legend."))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                
                // 縱向模式專屬設定：100% 基準項目設定
                if project.chartType == .verticalGroupedBar {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(l10n("縱向圖表 100% 基準設定", "100% Baseline Setting"), systemImage: "percent")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#A855F7"))
                            Spacer()
                        }
                        
                        Picker(l10n("基準模式", "Baseline Mode"), selection: $project.verticalConfig.baselineMode) {
                            ForEach(VerticalBaselineMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        if project.verticalConfig.baselineMode == .productBaseline && !project.items.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("選擇 100% 基準產品", "Select 100% Baseline Product"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: Binding<UUID>(
                                    get: { project.verticalConfig.baselineItemId ?? project.items.first?.id ?? UUID() },
                                    set: { project.verticalConfig.baselineItemId = $0 }
                                )) {
                                    ForEach(project.items) { item in
                                        Text(item.title).tag(item.id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        
                        if project.verticalConfig.baselineMode != .none {
                            Toggle(l10n("柱頂自動顯示轉換後百分比數值 (%)", "Show values as percentage (%)"), isOn: $project.verticalConfig.showPercentageNumber)
                                .font(.system(size: 11))
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // 數值顯示開關與呈現位置 (隨長條圖頂端 vs 呈現在 100% 虛線上)
                        Toggle(l10n("在長條圖上顯示數值", "Show Numbers on Bars"), isOn: $project.verticalConfig.showBarValues)
                            .font(.system(size: 11, weight: .semibold))
                        
                        if project.verticalConfig.showBarValues && project.chartType == .verticalGroupedBar {
                            Picker(l10n("數值呈現位置", "Value Display Position"), selection: $project.verticalConfig.valuePosition) {
                                ForEach(VerticalValuePosition.allCases) { pos in
                                    Text(pos.rawValue).tag(pos)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                }
            }
        }
    }
    
    // MARK: - Tab 1: Typography & Fonts
    private var typographyTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. 字體選擇
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n("選擇圖表與標題字體", "Select Chart & Title Font"))
                    .font(.system(size: 13, weight: .bold))
                
                HStack(spacing: 12) {
                    Picker("", selection: $project.typography.fontFamily) {
                        ForEach(fontMgr.availableFontFamilies, id: \.self) { family in
                            Text(family).tag(family)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    
                    Button(action: importCustomFont) {
                        Label(l10n("匯入字體檔案 (.ttf / .otf)", "Import Font File (.ttf/.otf)"), systemImage: "plus.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                }
                
                if !vm.fontStatusMessage.isEmpty {
                    Text(vm.fontStatusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#10B981"))
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // 2. 字體粗體模式 (Bold Font Mode)
            VStack(alignment: .leading, spacing: 6) {
                Toggle(l10n("字體粗體模式 (全面加粗強化科技視覺對比)", "Bold Font Mode (Enhanced bold weights)"), isOn: $project.typography.isBoldMode)
                    .font(.system(size: 12, weight: .bold))
                
                Text(l10n("開啟時將畫布與圖表中的所有文字（主副標題、產品規格、數據數字、指標標籤）同步加粗為 Heavy/Black 粗體，增強評測影片中的辨識度。", "When enabled, all text in the canvas and charts are rendered with heavier bold weights for maximum readability."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
            
            Divider().background(Color.white.opacity(0.1))
            
            // 3. 各分項字體大小調整 (調整字體大小時其餘元素佈局嚴格不動)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n("各分項字體大小調整", "Component Font Size Controls"))
                            .font(.system(size: 13, weight: .bold))
                        Text(l10n("各項目插槽尺寸固定，微調字體大小時長條圖、網格與其餘元素嚴格不動", "Slots are geometric-locked; adjusting font size never shifts charts or layouts."))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(l10n("重置字級", "Reset Sizes")) {
                        project.typography.mainTitleSize = 26.0
                        project.typography.subtitleSize = 14.0
                        project.typography.productTitleSize = 15.0
                        project.typography.productSubtitleSize = 11.0
                        project.typography.dataValueSize = 15.0
                        project.typography.dimensionHeaderSize = 11.0
                        project.typography.annotationSize = 10.0
                        project.typography.bottomValueSize = 10.0
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                }
                
                // Sliders Grid
                VStack(spacing: 8) {
                    fontSizeSliderRow(title: l10n("主標題字級", "Main Title Size"), value: $project.typography.mainTitleSize, range: 18...36, defaultVal: 26)
                    fontSizeSliderRow(title: l10n("副標題字級", "Subtitle Size"), value: $project.typography.subtitleSize, range: 10...20, defaultVal: 14)
                    fontSizeSliderRow(title: l10n("產品名稱字級", "Product Title Size"), value: $project.typography.productTitleSize, range: 11...22, defaultVal: 15)
                    fontSizeSliderRow(title: l10n("產品規格字級", "Product Spec Size"), value: $project.typography.productSubtitleSize, range: 9...16, defaultVal: 11)
                    fontSizeSliderRow(title: l10n("數據數值字級", "Data Value Size"), value: $project.typography.dataValueSize, range: 11...22, defaultVal: 15)
                    fontSizeSliderRow(title: l10n("指標名稱字級", "Metric Name Size"), value: $project.typography.dimensionHeaderSize, range: 9...16, defaultVal: 11)
                    fontSizeSliderRow(title: l10n("頂部標註字級", "Annotation Size"), value: $project.typography.annotationSize, range: 8...15, defaultVal: 10)
                    fontSizeSliderRow(title: l10n("長條圖底部數字", "Bottom Number Size"), value: $project.typography.bottomValueSize, range: 8...15, defaultVal: 10)
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }
            
            // 4. 即時預覽卡片
            VStack(alignment: .leading, spacing: 6) {
                Text(l10n("字體即時預覽效果", "Live Font Preview"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cinebench R23 解熱測試 (2026)")
                        .font(fontMgr.font(
                            family: project.typography.fontFamily,
                            size: CGFloat(project.typography.mainTitleSize * 0.75),
                            weight: .heavy,
                            isBoldMode: project.typography.isBoldMode
                        ))
                    
                    HStack {
                        Text("產品 A (旗艦規格)")
                            .font(fontMgr.font(
                                family: project.typography.fontFamily,
                                size: CGFloat(project.typography.productTitleSize),
                                weight: .bold,
                                isBoldMode: project.typography.isBoldMode
                            ))
                            .foregroundStyle(LinearGradient(colors: [Color(hex: "#A855F7"), Color(hex: "#6366F1")], startPoint: .leading, endPoint: .trailing))
                        
                        Spacer()
                        
                        Text("87.0 W  |  48 dB  |  100%")
                            .font(fontMgr.font(
                                family: project.typography.fontFamily,
                                size: CGFloat(project.typography.dataValueSize),
                                weight: .bold,
                                design: .monospaced,
                                isBoldMode: project.typography.isBoldMode
                            ))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }
    
    @ViewBuilder
    private func fontSizeSliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, defaultVal: Double) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.85))
                .frame(width: 110, alignment: .leading)
            
            Slider(value: value, in: range, step: 0.5)
            
            Text("\(Int(value.wrappedValue)) pt")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(value.wrappedValue != defaultVal ? Color(hex: "#A855F7") : .secondary)
                .frame(width: 42, alignment: .trailing)
        }
    }
    
    // MARK: - Tab 2: Cache & Storage (Moved from sidebar)
    private var cacheTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(l10n("本機暫存快取管理", "Local Cache & Storage Management"))
                    .font(.system(size: 13, weight: .bold))
                
                Text(l10n("軟體在進行即時預覽、自訂背景影片解碼與 4K/2K 影片匯出時，會在 macOS 暫存目錄建立影像中介檔與硬體編碼緩衝。", "Visualized Benchmark generates temporary frame buffers and hardware encoding caches during preview and video rendering."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n("目前暫存佔用空間", "Current Cache Usage"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(CacheService.shared.formatBytes(vm.cacheSizeBytes))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(vm.cacheSizeBytes > 100 * 1024 * 1024 ? Color(hex: "#F59E0B") : Color(hex: "#10B981"))
                }
                
                Spacer()
                
                Button(action: performClearCache) {
                    Label(l10n("立即清除所有暫存快取", "Clear All Cache Now"), systemImage: "trash.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#EF4444"))
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            
            if !vm.cacheStatusMessage.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#10B981"))
                    Text(vm.cacheStatusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#10B981"))
                }
                .padding(.horizontal, 4)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n("Apple Silicon M 晶片硬體調用狀態", "Apple Silicon Media Engine Status"))
                    .font(.system(size: 11, weight: .bold))
                Text(l10n("已啟用 IOSurface DMA 零拷貝記憶體池化與 VideoToolbox 專屬硬體編碼器加速。", "IOSurface DMA Zero-copy memory pooling and VideoToolbox hardware encoder acceleration are active."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func refreshCacheSize() {
        vm.cacheSizeBytes = CacheService.shared.calculateCacheSize()
    }
    
    private func performClearCache() {
        let res = CacheService.shared.clearCache()
        refreshCacheSize()
        vm.cacheStatusMessage = res.message
    }
    
    private func importCustomFont() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "ttf") ?? .data,
            UTType(filenameExtension: "otf") ?? .data
        ]
        panel.title = l10n("選擇自訂字體檔案 (.ttf / .otf)", "Select Custom Font File (.ttf/.otf)")
        
        if panel.runModal() == .OK, let fontURL = panel.url {
            do {
                let name = try fontMgr.registerCustomFont(from: fontURL)
                project.typography.fontFamily = name
                vm.fontStatusMessage = l10n("成功匯入並套用字體: \(name)", "Successfully imported and applied font: \(name)")
            } catch {
                vm.fontStatusMessage = "匯入失敗: \(error.localizedDescription)"
            }
        }
    }
}
