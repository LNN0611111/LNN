import SwiftUI
import AppKit

public final class ImageCropState: ObservableObject {
    @Published public var zoom: CGFloat = 1.0
    @Published public var offset: CGSize = .zero
    @Published public var lastOffset: CGSize = .zero
    
    public init() {}
    
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
    
    @StateObject private var state = ImageCropState()
    
    private let cropBoxSize: CGFloat = 220.0
    
    public init(
        inputImage: NSImage,
        imageName: String = "自訂圖示",
        onComplete: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.inputImage = inputImage
        self.imageName = imageName
        self.onComplete = onComplete
        self.onCancel = onCancel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n("自訂圖示可視化裁剪與縮放", "Visual Icon Crop & Scale"))
                        .font(.system(size: 14, weight: .bold))
                    Text(l10n("拖曳移動位置，滑動縮放，系統自動等比例縮放至標準圖示尺寸 (80×80)", "Drag to reposition, slide to zoom. Scaled proportionally to icon standard (80×80)"))
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
            
            // Content Area: Interactive Crop Area + Live Preview
            HStack(spacing: 24) {
                // Left: 1:1 Crop Viewport
                VStack(spacing: 12) {
                    ZStack {
                        // Background workspace
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 280, height: 280)
                        
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
                            .frame(width: cropBoxSize, height: cropBoxSize)
                        
                        // Mask / Cutout: Darkened border outside 1:1 square
                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.55))
                                .frame(width: 280, height: 280)
                                .mask(
                                    Rectangle()
                                        .frame(width: 280, height: 280)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .frame(width: cropBoxSize, height: cropBoxSize)
                                                .blendMode(.destinationOut)
                                        )
                                )
                            
                            // 1:1 Square Border + Rule of Thirds Guide Lines
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                                .frame(width: cropBoxSize, height: cropBoxSize)
                                .overlay(
                                    // Grid lines
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
                    .frame(width: 280, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    
                    // Zoom Slider Controls
                    HStack(spacing: 12) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Slider(value: $state.zoom, in: 0.5...3.0, step: 0.05)
                            .frame(width: 150)
                        
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Button(action: { state.reset() }) {
                            Text(l10n("重置", "Reset"))
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                // Right: Real-time Live Preview & Specs
                VStack(alignment: .leading, spacing: 16) {
                    Text(l10n("即時圖示預覽", "Live Icon Preview"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        // Render miniature preview using current crop
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(
                                    colors: [Color(white: 0.25), Color(white: 0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 58, height: 58)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(LinearGradient(
                                            colors: [Color(hex: "#A855F7"), Color(hex: "#6366F1")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ), lineWidth: 1.5)
                                )
                                .shadow(color: Color(hex: "#A855F7").opacity(0.4), radius: 6, x: 0, y: 2)
                            
                            // Clipped preview of image inside 58x58
                            Image(nsImage: inputImage)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(state.zoom * (58.0 / cropBoxSize))
                                .offset(
                                    x: state.offset.width * (58.0 / cropBoxSize),
                                    y: state.offset.height * (58.0 / cropBoxSize)
                                )
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Text(l10n("畫布預覽樣式", "Canvas Look"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    // Info Specs
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(l10n("原圖尺寸", "Source Size"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(inputImage.size.width)) × \(Int(inputImage.size.height))")
                                .font(.system(size: 11, design: .monospaced))
                        }
                        HStack {
                            Text(l10n("目標裁剪", "Target Crop"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("1:1 正方形")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#60A5FA"))
                        }
                        HStack {
                            Text(l10n("輸出規範", "Output Spec"))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("等比標準化 Retina")
                                .font(.system(size: 11))
                        }
                    }
                    .font(.system(size: 11))
                    .padding(10)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(6)
                    
                    Spacer()
                }
                .frame(width: 170)
            }
            .padding(20)
            
            Divider()
            
            // Footer Action Buttons
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
        .frame(width: 530, height: 450)
        .background(Color(white: 0.14))
    }
    
    private func confirmCrop() {
        let targetSize = CGSize(width: 256, height: 256)
        let newImage = NSImage(size: targetSize)
        
        newImage.lockFocus()
        if let context = NSGraphicsContext.current {
            context.imageInterpolation = .high
        }
        
        let imgOrigSize = inputImage.size
        let aspect = imgOrigSize.width / max(imgOrigSize.height, 1)
        var drawW = targetSize.width * state.zoom
        var drawH = targetSize.height * state.zoom
        if aspect > 1.0 {
            drawH = drawW / aspect
        } else {
            drawW = drawH * aspect
        }
        
        let drawX = (targetSize.width - drawW) / 2.0 + (state.offset.width * (targetSize.width / cropBoxSize))
        let drawY = (targetSize.height - drawH) / 2.0 - (state.offset.height * (targetSize.height / cropBoxSize))
        
        inputImage.draw(
            in: NSRect(x: drawX, y: drawY, width: drawW, height: drawH),
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
