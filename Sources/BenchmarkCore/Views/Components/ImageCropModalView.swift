import SwiftUI
import AppKit

public struct CropRatioPreset: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let icon: String
    public let ratioValue: CGFloat? // nil 表示依原圖自身比例
    
    public init(id: String, name: String, icon: String, ratioValue: CGFloat?) {
        self.id = id
        self.name = name
        self.icon = icon
        self.ratioValue = ratioValue
    }
}

public let standardCropRatioPresets: [CropRatioPreset] = [
    CropRatioPreset(id: "1:1", name: "1:1 正方", icon: "square", ratioValue: 1.0),
    CropRatioPreset(id: "16:9", name: "16:9 寬螢幕", icon: "display", ratioValue: 16.0 / 9.0),
    CropRatioPreset(id: "4:3", name: "4:3 標準", icon: "rectangle", ratioValue: 4.0 / 3.0),
    CropRatioPreset(id: "3:2", name: "3:2 照片", icon: "photo", ratioValue: 3.0 / 2.0),
    CropRatioPreset(id: "9:16", name: "9:16 直式", icon: "iphone", ratioValue: 9.0 / 16.0),
    CropRatioPreset(id: "original", name: "原始比例", icon: "aspectratio", ratioValue: nil)
]

public final class ImageCropState: ObservableObject {
    @Published public var zoom: CGFloat = 1.0
    @Published public var offset: CGSize = .zero
    @Published public var lastOffset: CGSize = .zero
    @Published public var selectedRatioId: String = "1:1"
    
    public init(selectedRatioId: String = "1:1") {
        self.selectedRatioId = selectedRatioId
    }
    
    public func reset() {
        zoom = 1.0
        offset = .zero
        lastOffset = .zero
    }
}

public struct ImageCropModalView: View {
    public let inputImage: NSImage
    public let imageName: String
    public let onComplete: (String) -> Void
    public let onCancel: () -> Void
    
    @StateObject private var state: ImageCropState
    
    private let viewportWidth: CGFloat = 320.0
    private let viewportHeight: CGFloat = 260.0
    
    public init(
        inputImage: NSImage,
        imageName: String = "自訂圖示",
        initialRatioId: String = "1:1",
        onComplete: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.inputImage = inputImage
        self.imageName = imageName
        self._state = StateObject(wrappedValue: ImageCropState(selectedRatioId: initialRatioId))
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
    
    public var body: some View {
        let effectiveRatio = getEffectiveRatio()
        let cropSize = currentCropBoxSize(for: effectiveRatio)
        
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n("自訂圖檔可視化裁剪與縮放", "Visual Image Crop & Scale"))
                        .font(.system(size: 14, weight: .bold))
                    Text(l10n("支援自由拖曳平移、平滑縮放與多款預設比例 (1:1, 16:9, 4:3等)，自動進行等比例高品質輸出", "Supports pan, smooth zoom, and preset ratios (1:1, 16:9, 4:3, etc.) with proportional Retina export"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.04))
            
            Divider()
            
            // MARK: - Ratio Presets Toolbar
            HStack(spacing: 8) {
                Text(l10n("裁剪比例:", "Crop Ratio:"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                ForEach(standardCropRatioPresets) { preset in
                    let isSelected = (state.selectedRatioId == preset.id)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            state.selectedRatioId = preset.id
                            state.reset()
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 9))
                            Text(preset.name)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color(hex: "#7C3AED") : Color.white.opacity(0.06))
                        .foregroundColor(isSelected ? .white : Color(white: 0.8))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color(hex: "#A855F7") : Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.02))
            
            Divider()
            
            // MARK: - Content Area
            HStack(spacing: 24) {
                // Left: Interactive Crop Workspace
                VStack(spacing: 12) {
                    ZStack {
                        // Background workspace
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.65))
                            .frame(width: viewportWidth, height: viewportHeight)
                        
                        // Movable & Scalable Image
                        Image(nsImage: inputImage)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(state.zoom)
                            .offset(state.offset)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        state.offset = CGSize(
                                            width: state.lastOffset.width + value.translation.width,
                                            height: state.lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        state.lastOffset = state.offset
                                    }
                            )
                            .frame(width: cropSize.width, height: cropSize.height)
                        
                        // Mask / Cutout: Darkened border outside the target crop box
                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.55))
                                .frame(width: viewportWidth, height: viewportHeight)
                                .mask(
                                    Rectangle()
                                        .frame(width: viewportWidth, height: viewportHeight)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .frame(width: cropSize.width, height: cropSize.height)
                                                .blendMode(.destinationOut)
                                        )
                                )
                            
                            // Crop Guide Border + Rule of Thirds Guide Lines
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                                .frame(width: cropSize.width, height: cropSize.height)
                                .overlay(
                                    VStack {
                                        Spacer()
                                        Divider().background(Color.white.opacity(0.25))
                                        Spacer()
                                        Divider().background(Color.white.opacity(0.25))
                                        Spacer()
                                    }
                                    .overlay(
                                        HStack {
                                            Spacer()
                                            Divider().background(Color.white.opacity(0.25))
                                            Spacer()
                                            Divider().background(Color.white.opacity(0.25))
                                            Spacer()
                                        }
                                    )
                                )
                        }
                        .allowsHitTesting(false)
                    }
                    .frame(width: viewportWidth, height: viewportHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    
                    // Zoom Slider Controls
                    HStack(spacing: 12) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Slider(value: $state.zoom, in: 0.3...4.0, step: 0.05)
                            .frame(width: 170)
                        
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(state.zoom * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 42, alignment: .trailing)
                        
                        Button(action: { state.reset() }) {
                            Text(l10n("重置", "Reset"))
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Right: Real-time Live Preview & Specs
                VStack(alignment: .leading, spacing: 14) {
                    Text(l10n("即時預覽效果", "Live Preview"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    let previewMax: CGFloat = 88.0
                    let previewBoxW: CGFloat = effectiveRatio >= 1.0 ? previewMax : round(previewMax * effectiveRatio)
                    let previewBoxH: CGFloat = effectiveRatio >= 1.0 ? round(previewMax / effectiveRatio) : previewMax
                    
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(
                                    colors: [Color(white: 0.22), Color(white: 0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: previewBoxW + 8, height: previewBoxH + 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(LinearGradient(
                                            colors: [Color(hex: "#A855F7"), Color(hex: "#6366F1")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ), lineWidth: 1.5)
                                )
                                .shadow(color: Color(hex: "#A855F7").opacity(0.35), radius: 6, x: 0, y: 2)
                            
                            Image(nsImage: inputImage)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(state.zoom * (previewBoxW / cropSize.width))
                                .offset(
                                    x: state.offset.width * (previewBoxW / cropSize.width),
                                    y: state.offset.height * (previewBoxH / cropSize.height)
                                )
                                .frame(width: previewBoxW, height: previewBoxH)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .frame(height: 96)
                        
                        Text(l10n("套用後呈現外觀", "Applied Look"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    // Info Specs
                    let outputSize = computeTargetOutputSize(for: effectiveRatio)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(l10n("原圖尺寸", "Source Size"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(inputImage.size.width)) × \(Int(inputImage.size.height))")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        HStack {
                            Text(l10n("目標比例", "Target Ratio"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(currentRatioName())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "#60A5FA"))
                        }
                        HStack {
                            Text(l10n("輸出尺寸", "Output Spec"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(outputSize.width)) × \(Int(outputSize.height))")
                                .font(.system(size: 10, design: .monospaced))
                        }
                    }
                    .font(.system(size: 10))
                    .padding(10)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(6)
                    
                    Spacer()
                }
                .frame(width: 175)
            }
            .padding(18)
            
            Divider()
            
            // MARK: - Footer Action Buttons
            HStack {
                Button(action: onCancel) {
                    Text(l10n("取消", "Cancel"))
                        .frame(width: 75)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: confirmCrop) {
                    Label(l10n("完成裁剪並套用", "Apply Crop & Scale"), systemImage: "crop")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#7C3AED"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.04))
        }
        .frame(width: 580, height: 490)
        .background(Color(white: 0.14))
    }
    
    // MARK: - Helper Geometry & Output Calculation
    public func getEffectiveRatio() -> CGFloat {
        if let preset = standardCropRatioPresets.first(where: { $0.id == state.selectedRatioId }),
           let val = preset.ratioValue {
            return max(0.1, val)
        }
        let imgOrig = inputImage.size
        return max(0.1, imgOrig.width / max(imgOrig.height, 1))
    }
    
    private func currentRatioName() -> String {
        standardCropRatioPresets.first(where: { $0.id == state.selectedRatioId })?.name ?? "1:1"
    }
    
    public func currentCropBoxSize(for targetRatio: CGFloat) -> CGSize {
        let maxW: CGFloat = 260.0
        let maxH: CGFloat = 210.0
        
        if targetRatio >= (maxW / maxH) {
            let w = maxW
            let h = maxW / targetRatio
            return CGSize(width: round(w), height: round(h))
        } else {
            let h = maxH
            let w = maxH * targetRatio
            return CGSize(width: round(w), height: round(h))
        }
    }
    
    public func computeTargetOutputSize(for targetRatio: CGFloat) -> CGSize {
        let maxOutputDim: CGFloat = 320.0
        if targetRatio >= 1.0 {
            return CGSize(width: maxOutputDim, height: round(maxOutputDim / targetRatio))
        } else {
            return CGSize(width: round(maxOutputDim * targetRatio), height: maxOutputDim)
        }
    }
    
    private func confirmCrop() {
        let effectiveRatio = getEffectiveRatio()
        let cropSize = currentCropBoxSize(for: effectiveRatio)
        let targetSize = computeTargetOutputSize(for: effectiveRatio)
        
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        if let context = NSGraphicsContext.current {
            context.imageInterpolation = .high
        }
        
        let imgOrigSize = inputImage.size
        let imgAspect = imgOrigSize.width / max(imgOrigSize.height, 1)
        let boxAspect = cropSize.width / max(cropSize.height, 1)
        
        let fitW: CGFloat
        let fitH: CGFloat
        if imgAspect >= boxAspect {
            fitW = cropSize.width
            fitH = cropSize.width / imgAspect
        } else {
            fitH = cropSize.height
            fitW = cropSize.height * imgAspect
        }
        
        let drawnUIWidth = fitW * state.zoom
        let drawnUIHeight = fitH * state.zoom
        
        let canvasScale = targetSize.width / cropSize.width
        let finalDrawW = drawnUIWidth * canvasScale
        let finalDrawH = drawnUIHeight * canvasScale
        
        let finalCenterX = targetSize.width / 2.0 + (state.offset.width * canvasScale)
        let finalCenterY = targetSize.height / 2.0 - (state.offset.height * canvasScale)
        
        let finalDrawX = finalCenterX - finalDrawW / 2.0
        let finalDrawY = finalCenterY - finalDrawH / 2.0
        
        inputImage.draw(
            in: NSRect(x: finalDrawX, y: finalDrawY, width: finalDrawW, height: finalDrawH),
            from: NSRect(origin: .zero, size: imgOrigSize),
            operation: .sourceOver,
            fraction: 1.0
        )
        newImage.unlockFocus()
        
        if let tiff = newImage.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            let base64 = png.base64EncodedString()
            onComplete(base64)
        } else {
            onCancel()
        }
    }
}
