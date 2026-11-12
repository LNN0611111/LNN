import SwiftUI
import AppKit
import UniformTypeIdentifiers

final class HeaderSectionState: ObservableObject {
    @Published var isShowingCropModal: Bool = false
    @Published var imageToCrop: NSImage? = nil
    @Published var imageToCropName: String = ""
    @Published var imageToCropId: UUID? = nil
    init() {}
}

public struct HeaderSection: View {
    @Binding public var header: HeaderConfig
    @Binding public var typography: TypographyConfig
    
    @StateObject private var state = HeaderSectionState()
    
    // Popular benchmark / hardware SF symbols (includes battery, CPU, GPU, fan, etc.)
    private let commonSymbols = [
        "battery.100.bolt",
        "battery.100",
        "cpu.fill",
        "bolt.fill",
        "chart.bar.fill",
        "flame.fill",
        "fan.fill",
        "speedometer",
        "macbook.and.iphone",
        "laptopcomputer",
        "memorychip.fill",
        "gauge.with.needle.fill"
    ]
    
    // Quick preset color combinations
    private let presetIconPalettes: [(name: String, c1: String, c2: String)] = [
        ("紫藍漸層", "#A855F7", "#6366F1"),
        ("霓虹藍綠", "#06B6D4", "#3B82F6"),
        ("炫光翠綠", "#10B981", "#059669"),
        ("日落橘紅", "#F59E0B", "#EF4444"),
        ("霓虹粉紫", "#EC4899", "#8B5CF6"),
        ("電池閃金", "#FACC15", "#EAB308"),
        ("極簡銀白", "#E2E8F0", "#94A3B8")
    ]
    
    public init(
        header: Binding<HeaderConfig>,
        typography: Binding<TypographyConfig> = .constant(TypographyConfig())
    ) {
        self._header = header
        self._typography = typography
    }
    
    public var body: some View {
        SidebarSectionCard(title: l10n("標題設定", "Title Settings"), systemImage: "character.textbox") {
            VStack(alignment: .leading, spacing: 14) {
                // 1. Main Title Input
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n("主標題", "Main Title"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    TextField(l10n("輸入主標題", "Enter main title"), text: $header.mainTitle)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 2. Subtitle Input
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n("副標題 (字體較小)", "Subtitle (Smaller font)"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    TextField(l10n("輸入副標題（例：高電量模式 + 風扇滿轉）", "Enter subtitle (e.g. Max Fan Speed)"), text: $header.subtitle)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 3. 標題字體大小拉桿 (從設定中加入分項)
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n("標題字體大小", "Title Font Sizes"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(l10n("主標題", "Main Title"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 44, alignment: .leading)
                        Slider(value: $typography.mainTitleSize, in: 18...36, step: 1)
                        Text("\(Int(typography.mainTitleSize)) pt")
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 32, alignment: .trailing)
                    }
                    
                    HStack {
                        Text(l10n("副標題", "Subtitle"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 44, alignment: .leading)
                        Slider(value: $typography.subtitleSize, in: 10...22, step: 1)
                        Text("\(Int(typography.subtitleSize)) pt")
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 32, alignment: .trailing)
                    }
                }
                
                // 4. 自訂標題與副標題文字顏色
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(l10n("自訂標題文字顏色", "Custom Title Text Color"), isOn: $header.useCustomTitleColor)
                        .font(.system(size: 11, weight: .bold))
                    
                    if header.useCustomTitleColor {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("主標題色", "Main Title"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    ColorPicker("", selection: Binding<Color>(
                                        get: { Color(hex: header.titleColorHex) },
                                        set: { header.titleColorHex = $0.toHex() }
                                    ))
                                    .labelsHidden()
                                    .frame(width: 24, height: 24)
                                    
                                    TextField("#HEX", text: $header.titleColorHex)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 10, design: .monospaced))
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("副標題色", "Subtitle"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    ColorPicker("", selection: Binding<Color>(
                                        get: { Color(hex: header.subtitleColorHex) },
                                        set: { header.subtitleColorHex = $0.toHex() }
                                    ))
                                    .labelsHidden()
                                    .frame(width: 24, height: 24)
                                    
                                    TextField("#HEX", text: $header.subtitleColorHex)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 10, design: .monospaced))
                                }
                            }
                        }
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // 5. Icon Settings (SF Symbols & Multi-Image Gallery)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(l10n("左上角標誌圖示", "Top-left Logo Icon"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    // SF Symbol selector grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 32), spacing: 6)], spacing: 6) {
                        ForEach(commonSymbols, id: \.self) { sym in
                            Button(action: {
                                header.iconSymbol = sym
                                header.customIconBase64 = nil
                                header.selectedImageId = nil
                            }) {
                                Image(systemName: sym)
                                    .font(.system(size: 14))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        (header.iconSymbol == sym && header.customIconBase64 == nil)
                                        ? Color.accentColor.opacity(0.35)
                                        : Color(white: 0.18)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                (header.iconSymbol == sym && header.customIconBase64 == nil)
                                                ? Color.accentColor
                                                : Color.white.opacity(0.12),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // 匯入自訂圖檔按鈕 (支援多選)
                    HStack {
                        Button(action: importMultipleCustomIcons) {
                            Label(l10n("匯入自訂圖檔 (支援多檔選取)", "Import Custom Icons (Multi)"), systemImage: "photo.badge.plus")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        
                        if header.customIconBase64 != nil {
                            Button(l10n("清除當前自訂", "Clear Active"), role: .destructive) {
                                header.customIconBase64 = nil
                                header.selectedImageId = nil
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 11))
                        }
                    }
                    
                    // 自訂圖檔庫 (Gallery) - 讓用戶能夠切換多個圖檔、重新裁剪或刪除
                    if !header.customImages.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(l10n("已匯入圖檔庫 (點選切換 / 點✂️重新裁剪):", "Imported Icon Gallery (Tap to select / ✂️ to crop):"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(header.customImages) { rec in
                                        let isSelected = (header.selectedImageId == rec.id) || (header.customIconBase64 == rec.base64)
                                        
                                        VStack(spacing: 4) {
                                            ZStack(alignment: .topTrailing) {
                                                Button(action: {
                                                    header.selectedImageId = rec.id
                                                    header.customIconBase64 = rec.base64
                                                }) {
                                                    if let data = Data(base64Encoded: rec.base64),
                                                       let img = NSImage(data: data) {
                                                        Image(nsImage: img)
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: 36, height: 36)
                                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                                    } else {
                                                        Color.gray.frame(width: 36, height: 36)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                                .padding(3)
                                                .background(isSelected ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.06))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                                                )
                                                
                                                // 刪除圖檔小叉叉
                                                Button(action: {
                                                    removeCustomImage(rec)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.white.opacity(0.8))
                                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                                }
                                                .buttonStyle(.plain)
                                                .offset(x: 4, y: -4)
                                            }
                                            
                                            // 裁剪按鈕
                                            Button(action: {
                                                openCropFor(record: rec)
                                            }) {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "crop")
                                                    Text(l10n("裁剪", "Crop"))
                                                }
                                                .font(.system(size: 9))
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    }
                    
                    // 填滿圖示框選項 (Fill vs Fit)
                    if header.customIconBase64 != nil {
                        VStack(alignment: .leading, spacing: 3) {
                            Toggle(l10n("將匯入圖片填滿圖示框", "Fill Icon Box with Image"), isOn: $header.fillIconBox)
                                .font(.system(size: 11, weight: .semibold))
                            
                            Text(l10n("開啟後圖片填滿整體圓角外框；關閉則以等比適中居中呈現。", "Fill: covers entire rounded box; Off: fits proportionally inside."))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // MARK: - 圖示配色模式（單色 / 雙色漸層）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(l10n("圖示配色調整", "Icon Color Palette"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    Picker("", selection: $header.iconColorMode) {
                        ForEach(IconColorMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // 顏色選取器與色碼輸入
                    if header.iconColorMode == .monochrome {
                        // 單色
                        HStack(spacing: 8) {
                            ColorPicker("", selection: Binding<Color>(
                                get: { Color(hex: header.iconColor1Hex) },
                                set: { header.iconColor1Hex = $0.toHex() }
                            ))
                            .labelsHidden()
                            .frame(width: 28, height: 28)
                            
                            TextField(l10n("主色碼", "Color Hex"), text: $header.iconColor1Hex)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }
                    } else {
                        // 雙色漸層
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("起點色", "Start Color"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    ColorPicker("", selection: Binding<Color>(
                                        get: { Color(hex: header.iconColor1Hex) },
                                        set: { header.iconColor1Hex = $0.toHex() }
                                    ))
                                    .labelsHidden()
                                    .frame(width: 24, height: 24)
                                    
                                    TextField("#HEX", text: $header.iconColor1Hex)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 10, design: .monospaced))
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("終點色", "End Color"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    ColorPicker("", selection: Binding<Color>(
                                        get: { Color(hex: header.iconColor2Hex) },
                                        set: { header.iconColor2Hex = $0.toHex() }
                                    ))
                                    .labelsHidden()
                                    .frame(width: 24, height: 24)
                                    
                                    TextField("#HEX", text: $header.iconColor2Hex)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 10, design: .monospaced))
                                }
                            }
                        }
                    }
                    
                    // 快速預設色票
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(presetIconPalettes, id: \.name) { p in
                                Button(action: {
                                    header.iconColor1Hex = p.c1
                                    header.iconColor2Hex = p.c2
                                }) {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: p.c1), Color(hex: p.c2)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 10, height: 10)
                                        Text(p.name)
                                            .font(.system(size: 10))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $state.isShowingCropModal) {
            if let img = state.imageToCrop {
                ImageCropModalView(
                    inputImage: img,
                    imageName: state.imageToCropName,
                    onComplete: { croppedBase64 in
                        state.isShowingCropModal = false
                        // Update the record in gallery and active icon
                        if let targetId = state.imageToCropId,
                           let idx = header.customImages.firstIndex(where: { $0.id == targetId }) {
                            header.customImages[idx].base64 = croppedBase64
                        }
                        header.customIconBase64 = croppedBase64
                    },
                    onCancel: {
                        state.isShowingCropModal = false
                    }
                )
            }
        }
    }
    
    // MARK: - Import Multiple Images & Trigger Crop
    private func importMultipleCustomIcons() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            var firstImportedImage: NSImage?
            var firstImportedName: String = ""
            var firstImportedId: UUID?
            
            for url in panel.urls {
                if let data = try? Data(contentsOf: url),
                   let img = NSImage(data: data) {
                    let base64 = data.base64EncodedString()
                    let name = url.lastPathComponent
                    let rec = CustomImageRecord(base64: base64, name: name)
                    header.customImages.append(rec)
                    
                    if firstImportedImage == nil {
                        firstImportedImage = img
                        firstImportedName = name
                        firstImportedId = rec.id
                        header.selectedImageId = rec.id
                        header.customIconBase64 = base64
                    }
                }
            }
            
            // Immediately open visual crop editor for the first newly imported image
            if let firstImg = firstImportedImage, let firstId = firstImportedId {
                state.imageToCrop = firstImg
                state.imageToCropName = firstImportedName
                state.imageToCropId = firstId
                state.isShowingCropModal = true
            }
        }
    }
    
    private func openCropFor(record: CustomImageRecord) {
        if let data = Data(base64Encoded: record.base64),
           let img = NSImage(data: data) {
            state.imageToCrop = img
            state.imageToCropName = record.name
            state.imageToCropId = record.id
            state.isShowingCropModal = true
        }
    }
    
    private func removeCustomImage(_ rec: CustomImageRecord) {
        header.customImages.removeAll(where: { $0.id == rec.id })
        if header.selectedImageId == rec.id {
            if let next = header.customImages.first {
                header.selectedImageId = next.id
                header.customIconBase64 = next.base64
            } else {
                header.selectedImageId = nil
                header.customIconBase64 = nil
            }
        }
    }
}
