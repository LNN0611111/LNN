import SwiftUI

public struct DimensionSection: View {
    @Binding public var dimensions: [BenchmarkDimension]
    @Binding public var container: ContainerConfig
    @Binding public var typography: TypographyConfig
    
    public init(
        dimensions: Binding<[BenchmarkDimension]>,
        container: Binding<ContainerConfig> = .constant(ContainerConfig()),
        typography: Binding<TypographyConfig> = .constant(TypographyConfig())
    ) {
        self._dimensions = dimensions
        self._container = container
        self._typography = typography
    }
    
    public var body: some View {
        SidebarSectionCard(
            title: "\(l10n("指標欄位設定", "Dimension Settings")) (\(dimensions.count))",
            systemImage: "chart.bar.doc.horizontal"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // MARK: - 首欄標題自訂修改
                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n("首欄表頭標題 (可自訂修改)", "Product Column Header"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    TextField(l10n("例：產品 / 規格", "e.g. Product / Specs"), text: $container.productColumnTitle)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                
                // MARK: - 指標字體大小拉桿 (加入分項)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(l10n("指標名稱字級", "Metric Name Size"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(typography.dimensionHeaderSize)) pt")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    Slider(value: $typography.dimensionHeaderSize, in: 9...16, step: 1)
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                
                // MARK: - 自訂指標文字顏色 (全域)
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(l10n("自訂指標文字顏色", "Custom Dimension Color"), isOn: $container.useCustomDimensionColor)
                        .font(.system(size: 10, weight: .bold))
                    
                    if container.useCustomDimensionColor {
                        HStack(spacing: 8) {
                            Text(l10n("全域指標顏色", "Global Color"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            
                            ColorPicker("", selection: Binding<Color>(
                                get: { Color(hex: container.dimensionHeaderColorHex) },
                                set: { container.dimensionHeaderColorHex = $0.toHex() }
                            ))
                            .labelsHidden()
                            .frame(width: 24, height: 24)
                            
                            TextField("#HEX", text: $container.dimensionHeaderColorHex)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 10, design: .monospaced))
                        }
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                
                Divider().background(Color.white.opacity(0.1))
                
                ForEach($dimensions) { $dim in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(dim.name.isEmpty ? l10n("未命名維度", "Untitled Dimension") : dim.name)
                                .font(.system(size: 12, weight: .bold))
                            
                            Spacer()
                            
                            if dimensions.count > 1 {
                                Button(action: {
                                    if let idx = dimensions.firstIndex(where: { $0.id == dim.id }) {
                                        dimensions.remove(at: idx)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red)
                                        .frame(width: 24, height: 24)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Mode Selection: 放數據 vs 留空（後期疊加圖層）
                        VStack(alignment: .leading, spacing: 3) {
                            Text(l10n("欄位內容模式", "Column Content Mode"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $dim.isBlankPlaceholder) {
                                Text(l10n("放數據 (長條圖與數值)", "Show Data & Bars")).tag(false)
                                Text(l10n("留空 (供後期自行新增圖層)", "Leave Blank (For Layering)")).tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Dimension Name & Unit
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("指標名稱", "Name"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                TextField(l10n("例：功耗", "e.g. Power"), text: $dim.name)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("單位", "Unit"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                TextField(l10n("例：W", "e.g. W"), text: $dim.unit)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                            }
                        }
                        
                        if dim.isBlankPlaceholder {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "#60A5FA"))
                                Text(l10n("此維度在圖表中保留嚴格對齊空間與網格，長條圖位置完全留空以供後期疊加影片或圖層，未留空指標欄位置完全固定。", "This column retains its exact width and alignment slot, leaving the bar area blank for custom overlay."))
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(white: 0.7))
                            }
                            .padding(.vertical, 2)
                        } else {
                            // Max value (for bar calculation) & Decimals
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l10n("長條圖比例上限值 (Max)", "Max Value"))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    TextField(l10n("最大值", "Max"), value: $dim.maxValue, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l10n("小數位數", "Decimals"))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Picker("", selection: $dim.decimalPlaces) {
                                        Text("0位 (整數)").tag(0)
                                        Text("1位 (87.0)").tag(1)
                                        Text("2位 (87.00)").tag(2)
                                    }
                                    .labelsHidden()
                                    .frame(width: 95)
                                }
                            }
                            
                            // 獨立指標專屬顏色 (可選)
                            HStack(spacing: 6) {
                                Text(l10n("此指標專屬顏色 (選填)", "Specific Metric Color"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                
                                ColorPicker("", selection: Binding<Color>(
                                    get: { Color(hex: dim.customColorHex ?? container.dimensionHeaderColorHex) },
                                    set: { dim.customColorHex = $0.toHex() }
                                ))
                                .labelsHidden()
                                .frame(width: 22, height: 22)
                                
                                if dim.customColorHex != nil {
                                    Button(l10n("重置為預設", "Reset")) {
                                        dim.customColorHex = nil
                                    }
                                    .font(.system(size: 9))
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.top, 2)
                            
                            // 將顯示上限選項移到各項指標：讓用戶能選是否針對特定指標顯示
                            Toggle(
                                l10n("在表頭顯示此指標上限 (例：(上限 \(Int(dim.maxValue))\(dim.unit)))", "Show Max Value in Header"),
                                isOn: $dim.showMaxValue
                            )
                            .font(.system(size: 10))
                            .padding(.top, 2)
                        }
                    }
                    .padding(8)
                    .background(Color(white: 0.16))
                    .cornerRadius(6)
                }
                
                Button(action: addDimension) {
                    Label(l10n("新增對比維度", "Add Dimension"), systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func addDimension() {
        let newDim = BenchmarkDimension(
            name: "\(l10n("指標", "Metric")) \(dimensions.count + 1)",
            unit: "",
            maxValue: 100.0,
            decimalPlaces: 1,
            isBlankPlaceholder: false,
            showMaxValue: true
        )
        dimensions.append(newDim)
    }
}
