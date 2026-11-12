import SwiftUI
import AppKit

final class DataItemsSectionState: ObservableObject {
    @Published var showFontSliders: Bool = false
    init() {}
}

public struct DataItemsSection: View {
    @Binding public var items: [BenchmarkItem]
    public var dimensions: [BenchmarkDimension]
    @Binding public var showAnnotationBorder: Bool
    @Binding public var productColumnTitle: String
    @Binding public var typography: TypographyConfig
    
    @StateObject private var state = DataItemsSectionState()
    
    public init(
        items: Binding<[BenchmarkItem]>,
        dimensions: [BenchmarkDimension],
        showAnnotationBorder: Binding<Bool> = .constant(true),
        productColumnTitle: Binding<String> = .constant("產品 / 規格"),
        typography: Binding<TypographyConfig> = .constant(TypographyConfig())
    ) {
        self._items = items
        self.dimensions = dimensions
        self._showAnnotationBorder = showAnnotationBorder
        self._productColumnTitle = productColumnTitle
        self._typography = typography
    }
    
    public var body: some View {
        SidebarSectionCard(
            title: "\(l10n("數據項目管理", "Data Items")) (\(items.count))",
            systemImage: "list.bullet.rectangle"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // 2. 讓用戶能夠修改「產品 / 規格」這行字
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n("產品 / 規格 欄位表頭標題", "Product Column Title"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    TextField(l10n("例：產品 / 規格", "e.g. Product / Specs"), text: $productColumnTitle)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(6)
                
                // MARK: - 數據各分項字體大小調整 (從設定中移入分項)
                VStack(alignment: .leading, spacing: 6) {
                    Button(action: { withAnimation { state.showFontSliders.toggle() } }) {
                        HStack {
                            Text(l10n("各項目字體大小設定", "Component Font Sizes"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: state.showFontSliders ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if state.showFontSliders {
                        VStack(spacing: 6) {
                            HStack {
                                Text(l10n("產品名稱", "Product Title"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .frame(width: 52, alignment: .leading)
                                Slider(value: $typography.productTitleSize, in: 11...22, step: 1)
                                Text("\(Int(typography.productTitleSize)) pt")
                                    .font(.system(size: 9, design: .monospaced))
                                    .frame(width: 28, alignment: .trailing)
                            }
                            
                            HStack {
                                Text(l10n("產品規格", "Product Spec"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .frame(width: 52, alignment: .leading)
                                Slider(value: $typography.productSubtitleSize, in: 9...16, step: 1)
                                Text("\(Int(typography.productSubtitleSize)) pt")
                                    .font(.system(size: 9, design: .monospaced))
                                    .frame(width: 28, alignment: .trailing)
                            }
                            
                            HStack {
                                Text(l10n("長條數值", "Bar Value"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .frame(width: 52, alignment: .leading)
                                Slider(value: $typography.dataValueSize, in: 11...22, step: 1)
                                Text("\(Int(typography.dataValueSize)) pt")
                                    .font(.system(size: 9, design: .monospaced))
                                    .frame(width: 28, alignment: .trailing)
                            }
                            
                            HStack {
                                Text(l10n("頂部標註", "Annotation"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .frame(width: 52, alignment: .leading)
                                Slider(value: $typography.annotationSize, in: 8...15, step: 1)
                                Text("\(Int(typography.annotationSize)) pt")
                                    .font(.system(size: 9, design: .monospaced))
                                    .frame(width: 28, alignment: .trailing)
                            }
                            
                            HStack {
                                Text(l10n("底部數字", "Bottom Num"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .frame(width: 52, alignment: .leading)
                                Slider(value: $typography.bottomValueSize, in: 8...15, step: 1)
                                Text("\(Int(typography.bottomValueSize)) pt")
                                    .font(.system(size: 9, design: .monospaced))
                                    .frame(width: 28, alignment: .trailing)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(6)
                ForEach(items.indices, id: \.self) { idx in
                    let item = items[idx]
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Header with move buttons & delete
                        HStack {
                            Circle()
                                .fill(item.effectiveLinearGradient)
                                .frame(width: 10, height: 10)
                            
                            Text(item.title.isEmpty ? l10n("未命名產品", "Untitled Product") : item.title)
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Move Up
                            Button(action: { moveItem(from: idx, to: idx - 1) }) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(idx == 0)
                            
                            // Move Down
                            Button(action: { moveItem(from: idx, to: idx + 1) }) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(idx == items.count - 1)
                            
                            // Delete
                            Button(action: {
                                items.remove(at: idx)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(items.count <= 1)
                        }
                        
                        // Product Main Title & Spec Subtitle
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("產品主名稱", "Product Name"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                TextField(l10n("例：MacBook Pro 16", "e.g. MacBook Pro 16"), text: $items[idx].title)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("規格/副名稱", "Specs / Subtitle"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                TextField(l10n("例：M5 Max", "e.g. M5 Max"), text: $items[idx].subtitle)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        
                        // Theme Palette Picker: Grid of presets + 自訂配色
                        VStack(alignment: .leading, spacing: 4) {
                            Text(l10n("主題色漸層 (同步套用至名稱與長條圖)", "Theme Gradient"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                                ForEach(ThemePalette.allCases) { palette in
                                    Button(action: {
                                        items[idx].themePalette = palette
                                        if palette == .custom {
                                            if items[idx].customStartColorHex == nil {
                                                items[idx].customStartColorHex = "#A855F7"
                                            }
                                            if items[idx].customEndColorHex == nil {
                                                items[idx].customEndColorHex = "#EC4899"
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            palettePill(palette: palette, item: items[idx])
                                            
                                            Text(palette.rawValue)
                                                .font(.system(size: 10, weight: items[idx].themePalette == palette ? .bold : .regular))
                                                .foregroundColor(items[idx].themePalette == palette ? .white : Color(white: 0.75))
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            items[idx].themePalette == palette
                                            ? Color.accentColor.opacity(0.3)
                                            : Color(white: 0.12)
                                        )
                                        .cornerRadius(5)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(
                                                    items[idx].themePalette == palette ? Color.accentColor : Color.white.opacity(0.08),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Custom Color Picker & Hex Input Panel
                            if items[idx].themePalette == .custom {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Label(l10n("自訂漸層色盤", "Custom Color Palette"), systemImage: "slider.horizontal.3")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color(hex: "#A855F7"))
                                        Spacer()
                                    }
                                    
                                    HStack(spacing: 12) {
                                        // Start Color
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(l10n("起始顏色", "Start Color"))
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                            
                                            HStack(spacing: 4) {
                                                ColorPicker(
                                                    "",
                                                    selection: Binding<Color>(
                                                        get: { Color(hex: items[idx].effectiveStartColorHex) },
                                                        set: { newColor in
                                                            items[idx].customStartColorHex = newColor.toHex()
                                                        }
                                                    ),
                                                    supportsOpacity: false
                                                )
                                                .labelsHidden()
                                                .frame(width: 24, height: 24)
                                                
                                                TextField(
                                                    "#HEX",
                                                    text: Binding<String>(
                                                        get: { items[idx].effectiveStartColorHex },
                                                        set: { items[idx].customStartColorHex = $0 }
                                                    )
                                                )
                                                .textFieldStyle(.roundedBorder)
                                                .font(.system(size: 10, design: .monospaced))
                                            }
                                        }
                                        
                                        // End Color
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(l10n("結束顏色", "End Color"))
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                            
                                            HStack(spacing: 4) {
                                                ColorPicker(
                                                    "",
                                                    selection: Binding<Color>(
                                                        get: { Color(hex: items[idx].effectiveEndColorHex) },
                                                        set: { newColor in
                                                            items[idx].customEndColorHex = newColor.toHex()
                                                        }
                                                    ),
                                                    supportsOpacity: false
                                                )
                                                .labelsHidden()
                                                .frame(width: 24, height: 24)
                                                
                                                TextField(
                                                    "#HEX",
                                                    text: Binding<String>(
                                                        get: { items[idx].effectiveEndColorHex },
                                                        set: { items[idx].customEndColorHex = $0 }
                                                    )
                                                )
                                                .textFieldStyle(.roundedBorder)
                                                .font(.system(size: 10, design: .monospaced))
                                            }
                                        }
                                    }
                                    
                                    // Gradient Preview Pill
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(items[idx].effectiveLinearGradient)
                                        .frame(height: 12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                        )
                                }
                                .padding(8)
                                .background(Color(white: 0.12))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                        
                        // Dimension Numerical Inputs & Bottom Numbers
                        let dataDims = dimensions.filter { !$0.isBlankPlaceholder }
                        if !dataDims.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(l10n("各維度數值與底部數字", "Dimension Values & Bottom Numbers"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                ForEach(dataDims) { dim in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(dim.name)
                                                .font(.system(size: 11))
                                                .frame(width: 85, alignment: .leading)
                                                .lineLimit(1)
                                            
                                            TextField(
                                                l10n("數值", "Value"),
                                                value: Binding<Double>(
                                                    get: { items[idx].value(for: dim.id) },
                                                    set: { items[idx].setValue($0, for: dim.id) }
                                                ),
                                                format: .number
                                            )
                                            .textFieldStyle(.roundedBorder)
                                            
                                            if !dim.unit.isEmpty {
                                                Text(dim.unit)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 26, alignment: .leading)
                                            }
                                            
                                            // 底部數字切換按鈕 (在單一一條長條圖最底部添加數字)
                                            Button(action: {
                                                if items[idx].hasBottomValue(for: dim.id) {
                                                    items[idx].removeBottomValue(for: dim.id)
                                                } else {
                                                    items[idx].setBottomValue(0, for: dim.id)
                                                }
                                            }) {
                                                HStack(spacing: 3) {
                                                    Image(systemName: items[idx].hasBottomValue(for: dim.id) ? "checkmark.circle.fill" : "plus.circle")
                                                    Text(l10n("底部數字", "Bottom Val"))
                                                }
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(items[idx].hasBottomValue(for: dim.id) ? Color(hex: "#10B981") : .secondary)
                                            }
                                            .buttonStyle(.bordered)
                                            .help(l10n("在此長條圖最底部添加獨立數字", "Add number at the very bottom of this bar"))
                                        }
                                        
                                        // 若該長條圖啟用底部數字，展開輸入框
                                        if items[idx].hasBottomValue(for: dim.id) {
                                            HStack(spacing: 6) {
                                                Spacer().frame(width: 14)
                                                Image(systemName: "arrow.turn.down.right")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(Color(hex: "#10B981"))
                                                Text(l10n("長條圖最底部數字:", "Bottom Number:"))
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                
                                                TextField(
                                                    l10n("例：25", "e.g. 25"),
                                                    text: Binding<String>(
                                                        get: { items[idx].bottomDisplayString(for: dim.id) },
                                                        set: { items[idx].setBottomString($0, for: dim.id) }
                                                    )
                                                )
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 80)
                                                
                                                Button(action: {
                                                    items[idx].removeBottomValue(for: dim.id)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.secondary)
                                                }
                                                .buttonStyle(.plain)
                                                .help(l10n("移除此長條圖之底部數字", "Remove bottom number"))
                                            }
                                            .padding(.vertical, 3)
                                            .padding(.horizontal, 6)
                                            .background(Color(hex: "#10B981").opacity(0.08))
                                            .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Optional Top Annotation Text
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(l10n("附加頂部標註文字 (選填)", "Top Annotation (Optional)"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Toggle(l10n("顯示外框", "Border"), isOn: $showAnnotationBorder)
                                    .font(.system(size: 9))
                                    .toggleStyle(.checkbox)
                            }
                            TextField(l10n("例：8400 rpm / 9072 rpm", "e.g. 8400 rpm / 9072 rpm"), text: $items[idx].annotationText)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(8)
                    .background(Color(white: 0.16))
                    .cornerRadius(6)
                }
                
                Button(action: addItem) {
                    Label(l10n("新增數據項目", "Add Item"), systemImage: "plus.rectangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func moveItem(from: Int, to: Int) {
        guard to >= 0 && to < items.count else { return }
        let moved = items.remove(at: from)
        items.insert(moved, at: to)
    }
    
    private func addItem() {
        var newValues: [String: Double] = [:]
        for dim in dimensions where !dim.isBlankPlaceholder {
            newValues[dim.id.uuidString] = dim.maxValue * 0.7
        }
        let newItem = BenchmarkItem(
            title: "\(l10n("新設備", "New Device")) \(items.count + 1)",
            subtitle: l10n("規格說明", "Specs description"),
            themePalette: ThemePalette.allCases[items.count % (ThemePalette.allCases.count - 1)],
            values: newValues,
            annotationText: ""
        )
        items.append(newItem)
    }
    
    @ViewBuilder
    private func palettePill(palette: ThemePalette, item: BenchmarkItem) -> some View {
        if palette == .custom {
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: item.effectiveStartColorHex), Color(hex: item.effectiveEndColorHex)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 14, height: 14)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.3), lineWidth: 0.5))
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(palette.linearGradient)
                .frame(width: 14, height: 14)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.3), lineWidth: 0.5))
        }
    }
}
