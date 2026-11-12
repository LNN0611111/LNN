import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class AppearanceSectionState: ObservableObject {
    @Published var isShowingVideoTrimModal: Bool = false
    @Published var isShowingPatternCropModal: Bool = false
    @Published var patternImageToCrop: NSImage? = nil
    @Published var patternImageToCropName: String = ""
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
    @Binding public var patternConfig: AnimatedPatternConfig
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
        patternConfig: Binding<AnimatedPatternConfig> = .constant(AnimatedPatternConfig()),
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
        self._patternConfig = patternConfig
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
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                }
                
                // 3. Container Glass Style
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n("中央容器毛玻璃效果", "Center Glass Container"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $container.glassMode) {
                        ForEach(GlassMaterialMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    
                    // 毛玻璃通透度/透明度調節滑桿 (5% 濃郁磨砂 ~ 98% 極致通透晶瑩，預設 75%)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(l10n("毛玻璃通透度 (越高越透明)", "Glass Transparency (higher = clearer)"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.0f%%", container.glassTransparency * 100))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(hex: "#60A5FA"))
                        }
                        Slider(
                            value: Binding<Double>(
                                get: { container.glassTransparency },
                                set: { newVal in
                                    container.glassTransparency = newVal
                                    container.glassOpacity = max(0.02, min(0.95, 1.0 - newVal))
                                }
                            ),
                            in: 0.05...0.98,
                            step: 0.01
                        )
                    }
                    .padding(.top, 4)
                }
                
                // 4. Highlight Border & Corner Radius
                Toggle(l10n("啟用細微亮邊框 (1px 漸層描邊)", "Enable 1px Gradient Highlight Border"), isOn: $container.showHighlightBorder)
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
                                    HStack(spacing: 6) {
                                        Text(l10n("起點: \(String(format: "%.1f", customVideoConfig.trimStartTime))s", "Start: \(String(format: "%.1f", customVideoConfig.trimStartTime))s"))
                                        Text("|")
                                        Text(customVideoConfig.trimEndTime > 0 ? l10n("終點: \(String(format: "%.1f", customVideoConfig.trimEndTime))s", "End: \(String(format: "%.1f", customVideoConfig.trimEndTime))s") : l10n("終點: 完整", "End: Full"))
                                        Text("|")
                                        Text(customVideoConfig.cropAspectRatio == "original" ? l10n("原始比例", "Original") : customVideoConfig.cropAspectRatio)
                                        Text("|")
                                        Text(customVideoConfig.contentMode == "fill" ? l10n("填滿畫面", "Fill") : l10n("等比適應", "Fit"))
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
                    
                    if backgroundMode == .animatedPattern {
                        VStack(alignment: .leading, spacing: 10) {
                            // 標題與說明 + 隨機樣式 & 回復預設按鈕
                            HStack {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .foregroundColor(Color(hex: "#FACC15"))
                                Text(l10n("文字/圖片平移設定", "Text/Image Panning Settings"))
                                    .font(.system(size: 11, weight: .bold))
                                Spacer()
                                
                                Button(action: {
                                    patternConfig.applyRandomPreset()
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "dice")
                                        Text(l10n("隨機樣式", "Random"))
                                    }
                                    .font(.system(size: 10, weight: .semibold))
                                }
                                .buttonStyle(.bordered)
                                .tint(Color(hex: "#FACC15"))
                                
                                Button(action: {
                                    patternConfig = AnimatedPatternConfig(
                                        useRandomPreset: false,
                                        text: "TECH REVIEW",
                                        sfSymbol: "cpu",
                                        backgroundColorHex: "#0F172A",
                                        textColorHex: "#38BDF8",
                                        iconColorHex: "#38BDF8",
                                        rotationAngle: -12.0,
                                        scrollDirection: .diagonalUpLeft
                                    )
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text(l10n("回復預設", "Reset Defaults"))
                                    }
                                    .font(.system(size: 10))
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            // 1. 呈現模式 (圖標 + 文字 / 僅文字 / 僅圖標)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(l10n("呈現模式", "Content Mode"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $patternConfig.contentMode) {
                                    ForEach(PatternContentMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // 2. 文字設定 (當包含文字時)
                            if patternConfig.contentMode != .iconOnly {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(l10n("品牌/標題文字", "Brand / Title Text"))
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Toggle(l10n("粗體", "Bold"), isOn: $patternConfig.isBold)
                                            .font(.system(size: 10))
                                    }
                                    
                                    TextField(l10n("例如: TECH REVIEW", "e.g. Channel / Brand Name"), text: $patternConfig.text)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 11))
                                    
                                    // 字級拉桿
                                    HStack {
                                        Text(l10n("字體大小: \(Int(patternConfig.fontSize)) pt", "Font Size: \(Int(patternConfig.fontSize)) pt"))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    Slider(value: $patternConfig.fontSize, in: 14...48, step: 1)
                                }
                            }
                            
                            // 3. 圖標選取與自訂 (當包含圖標時)
                            if patternConfig.contentMode != .textOnly {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(l10n("圖標設定", "Icon Settings"))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    // 快捷 SF Symbols
                                    let presets = [
                                        ("cpu", "晶片"),
                                        ("bolt.fill", "閃電"),
                                        ("chart.bar.xaxis", "圖表"),
                                        ("flame.fill", "火焰"),
                                        ("speedometer", "跑分"),
                                        ("play.rectangle.fill", "影片"),
                                        ("camera.fill", "相機"),
                                        ("battery.100.bolt", "電池"),
                                        ("star.fill", "星星"),
                                        ("crown.fill", "皇冠")
                                    ]
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(presets, id: \.0) { sym, name in
                                                Button(action: {
                                                    patternConfig.sfSymbol = sym
                                                    patternConfig.customIconBase64 = nil
                                                }) {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: sym)
                                                        Text(name).font(.system(size: 9))
                                                    }
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .fill(patternConfig.sfSymbol == sym && patternConfig.customIconBase64 == nil ? Color(hex: "#FACC15").opacity(0.3) : Color.white.opacity(0.06))
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .stroke(patternConfig.sfSymbol == sym && patternConfig.customIconBase64 == nil ? Color(hex: "#FACC15") : Color.clear, lineWidth: 1)
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                    
                                    // 自訂圖檔上傳與可視化裁剪
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Button(action: pickCustomPatternIcon) {
                                                Label(
                                                    patternConfig.customIconBase64 != nil ? l10n("更換自訂圖標", "Change Icon") : l10n("匯入自訂圖檔 (PNG/JPG)", "Import Custom Icon"),
                                                    systemImage: "photo.badge.plus"
                                                )
                                                .font(.system(size: 10))
                                            }
                                            .buttonStyle(.bordered)
                                            
                                            if patternConfig.customIconBase64 != nil {
                                                Button(action: {
                                                    if let b64 = patternConfig.customIconBase64,
                                                       let data = Data(base64Encoded: b64),
                                                       let img = NSImage(data: data) {
                                                        state.patternImageToCrop = img
                                                        state.patternImageToCropName = l10n("平移圖騰圖標", "Pattern Icon")
                                                        state.isShowingPatternCropModal = true
                                                    }
                                                }) {
                                                    Label(l10n("✂️ 裁剪/縮放比例", "Crop/Scale"), systemImage: "crop")
                                                        .font(.system(size: 10))
                                                }
                                                .buttonStyle(.bordered)
                                                
                                                Button(l10n("清除自訂圖標", "Clear Icon"), role: .destructive) {
                                                    patternConfig.customIconBase64 = nil
                                                }
                                                .buttonStyle(.bordered)
                                                .font(.system(size: 10))
                                            }
                                        }
                                        
                                        // 顯示已匯入自訂圖標之縮圖預覽與尺寸資訊
                                        if let b64 = patternConfig.customIconBase64,
                                           let data = Data(base64Encoded: b64),
                                           let thumb = NSImage(data: data) {
                                            HStack(spacing: 6) {
                                                Image(nsImage: thumb)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(height: 22)
                                                    .background(Color.black.opacity(0.4))
                                                    .cornerRadius(4)
                                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.2), lineWidth: 0.8))
                                                
                                                Text(l10n("已套用自訂圖檔 (\(Int(thumb.size.width))×\(Int(thumb.size.height)))", "Active custom icon (\(Int(thumb.size.width))×\(Int(thumb.size.height)))"))
                                                    .font(.system(size: 9))
                                                    .foregroundColor(Color(hex: "#60A5FA"))
                                            }
                                            .padding(.top, 2)
                                        }
                                    }
                                }
                            }
                            
                            Divider().opacity(0.3)
                            
                            // 4. 色彩配置 (底色、文字、圖標)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(l10n("色彩配置", "Color Palette"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                                    // 底色
                                    GridRow {
                                        Text(l10n("背景底色", "Background Color"))
                                            .font(.system(size: 10))
                                        HStack(spacing: 6) {
                                            ColorPicker("", selection: Binding(
                                                get: { Color(hex: patternConfig.backgroundColorHex) },
                                                set: { patternConfig.backgroundColorHex = $0.toHex() }
                                            ))
                                            .labelsHidden()
                                            TextField("", text: $patternConfig.backgroundColorHex)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 76)
                                                .font(.system(size: 10, design: .monospaced))
                                        }
                                    }
                                    
                                    // 文字顏色
                                    if patternConfig.contentMode != .iconOnly {
                                        GridRow {
                                            Text(l10n("文字色彩", "Text Color"))
                                                .font(.system(size: 10))
                                            HStack(spacing: 6) {
                                                ColorPicker("", selection: Binding(
                                                    get: { Color(hex: patternConfig.textColorHex) },
                                                    set: { patternConfig.textColorHex = $0.toHex() }
                                                ))
                                                .labelsHidden()
                                                TextField("", text: $patternConfig.textColorHex)
                                                    .textFieldStyle(.roundedBorder)
                                                    .frame(width: 76)
                                                    .font(.system(size: 10, design: .monospaced))
                                            }
                                        }
                                    }
                                    
                                    // 圖標顏色
                                    if patternConfig.contentMode != .textOnly {
                                        GridRow {
                                            Text(l10n("圖標色彩", "Icon Color"))
                                                .font(.system(size: 10))
                                            HStack(spacing: 6) {
                                                ColorPicker("", selection: Binding(
                                                    get: { Color(hex: patternConfig.iconColorHex) },
                                                    set: { patternConfig.iconColorHex = $0.toHex() }
                                                ))
                                                .labelsHidden()
                                                TextField("", text: $patternConfig.iconColorHex)
                                                    .textFieldStyle(.roundedBorder)
                                                    .frame(width: 76)
                                                    .font(.system(size: 10, design: .monospaced))
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Divider().opacity(0.3)
                            
                            // 5. 動畫移動方向與速度
                            VStack(alignment: .leading, spacing: 6) {
                                Text(l10n("動態效果 (移動方向與速度)", "Motion & Direction"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text(l10n("移動方向", "Direction"))
                                        .font(.system(size: 10))
                                    Spacer()
                                    Picker("", selection: $patternConfig.scrollDirection) {
                                        ForEach(PatternScrollDirection.allCases) { dir in
                                            Text(dir.rawValue).tag(dir)
                                        }
                                    }
                                    .frame(width: 170)
                                }
                                
                                // 速度拉桿
                                HStack {
                                    Text(l10n("移動速度: \(Int(patternConfig.speed)) pt/s", "Speed: \(Int(patternConfig.speed)) pt/s"))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                Slider(value: $patternConfig.speed, in: 5...120, step: 1)
                            }
                            
                            Divider().opacity(0.3)
                            
                            // 6. 傾斜角度與排版
                            VStack(alignment: .leading, spacing: 6) {
                                Text(l10n("角度與圖騰密度", "Angle & Layout Spacing"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                // 旋轉角度
                                HStack {
                                    Text(l10n("傾斜旋轉角度: \(Int(patternConfig.rotationAngle))°", "Angle: \(Int(patternConfig.rotationAngle))°"))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button(l10n("水平 0°", "0° Flat")) {
                                        patternConfig.rotationAngle = 0
                                    }
                                    .font(.system(size: 9))
                                    .buttonStyle(.borderless)
                                }
                                Slider(value: $patternConfig.rotationAngle, in: -45...45, step: 1)
                                
                                // 水平間距
                                HStack {
                                    Text(l10n("水平項目間距: \(Int(patternConfig.itemSpacing)) pt", "Item Spacing: \(Int(patternConfig.itemSpacing)) pt"))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                Slider(value: $patternConfig.itemSpacing, in: 20...120, step: 2)
                                
                                // 垂直行距
                                HStack {
                                    Text(l10n("垂直行距: \(Int(patternConfig.rowSpacing)) pt", "Row Spacing: \(Int(patternConfig.rowSpacing)) pt"))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                Slider(value: $patternConfig.rowSpacing, in: 16...80, step: 2)
                                
                                // 奇偶行交錯排版
                                Toggle(l10n("交錯磚牆排版 (Staggered)", "Staggered Offset"), isOn: $patternConfig.staggeredOffset)
                                    .font(.system(size: 10))
                                
                                // 不透明度
                                HStack {
                                    Text(l10n("圖騰不透明度: \(Int(patternConfig.opacity * 100))%", "Opacity: \(Int(patternConfig.opacity * 100))%"))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                Slider(value: $patternConfig.opacity, in: 0.1...1.0, step: 0.05)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "#FACC15").opacity(0.3), lineWidth: 1)
                        )
                        .sheet(isPresented: $state.isShowingPatternCropModal) {
                            if let img = state.patternImageToCrop {
                                ImageCropModalView(
                                    inputImage: img,
                                    imageName: state.patternImageToCropName.isEmpty ? l10n("平移圖騰圖標", "Pattern Icon") : state.patternImageToCropName,
                                    initialRatioId: "1:1",
                                    onComplete: { croppedBase64 in
                                        patternConfig.customIconBase64 = croppedBase64
                                        state.isShowingPatternCropModal = false
                                        state.patternImageToCrop = nil
                                    },
                                    onCancel: {
                                        state.isShowingPatternCropModal = false
                                        state.patternImageToCrop = nil
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
            let ext = url.pathExtension.lowercased()
            if ["mp4", "mov", "m4v"].contains(ext) {
                // 用戶自行匯入影片時，立即跳出跟自訂圖標時一樣的可視化視窗讓用戶裁切影片長度及比例
                state.isShowingVideoTrimModal = true
            }
        }
    }
    
    private func pickCustomPatternIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let data = try? Data(contentsOf: url),
                   let image = NSImage(data: data) {
                    state.patternImageToCrop = image
                    state.patternImageToCropName = url.lastPathComponent
                    state.isShowingPatternCropModal = true
                }
            }
        }
    }
}
