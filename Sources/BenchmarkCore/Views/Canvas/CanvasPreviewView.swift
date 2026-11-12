import SwiftUI

public struct CanvasPreviewView: View {
    public var project: BenchmarkProject
    public var headerProgress: Double
    public var containerProgress: Double
    public var rowProgresses: [UUID: Double]
    public var numberProgresses: [UUID: Double]
    public var isPlaying: Bool
    public var currentTime: Double
    public var totalDuration: Double
    public var onPlay: () -> Void
    public var onReset: () -> Void
    public var onExport: () -> Void
    
    public init(
        project: BenchmarkProject,
        headerProgress: Double,
        containerProgress: Double,
        rowProgresses: [UUID: Double],
        numberProgresses: [UUID: Double] = [:],
        isPlaying: Bool,
        currentTime: Double,
        totalDuration: Double,
        onPlay: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onExport: @escaping () -> Void
    ) {
        self.project = project
        self.headerProgress = headerProgress
        self.containerProgress = containerProgress
        self.rowProgresses = rowProgresses
        self.numberProgresses = numberProgresses
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.totalDuration = totalDuration
        self.onPlay = onPlay
        self.onReset = onReset
        self.onExport = onExport
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Preview Status Bar
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isPlaying ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(isPlaying ? l10n("動畫播放中", "Animating...") : "\(l10n("預覽畫布", "Canvas Preview")) (\(project.aspectRatio.displayName))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(white: 0.8))
                }
                
                Spacer()
                
                // Animation Time readout
                Text(String(format: "%.2f s / %.2f s", currentTime, totalDuration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white: 0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(white: 0.15))
                    .cornerRadius(4)
                
                // Quick Export Button
                Button(action: onExport) {
                    Label(l10n("匯出影片/圖檔", "Export Video/Images"), systemImage: "square.and.arrow.up.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#7C3AED"))
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(white: 0.08))
            .overlay(Divider().background(Color(white: 0.15)), alignment: .bottom)
            
            // Dynamic Aspect Ratio Canvas Workspace (Adaptive fit with ZERO overflow into sidebar)
            GeometryReader { geo in
                let availableWidth = max(geo.size.width - 40, 100)
                let availableHeight = max(geo.size.height - 40, 100)
                
                let targetAspect = project.aspectRatio.ratioValue
                let refSize = project.aspectRatio.referenceSize
                
                let widthFromHeight = availableHeight * targetAspect
                let heightFromWidth = availableWidth / targetAspect
                
                let renderWidth: CGFloat = (widthFromHeight <= availableWidth) ? widthFromHeight : availableWidth
                let renderHeight: CGFloat = (widthFromHeight <= availableWidth) ? availableHeight : heightFromWidth
                let scale = renderWidth / refSize.width
                
                ZStack {
                    // Dark editor canvas background
                    Color(white: 0.05)
                    
                    // Dynamic Canvas Container
                    CanvasContainerView(
                        project: project,
                        headerProgress: headerProgress,
                        containerProgress: containerProgress,
                        rowProgresses: rowProgresses,
                        numberProgresses: numberProgresses,
                        isExportMode: false
                    )
                    .frame(width: refSize.width, height: refSize.height)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: renderWidth, height: renderHeight, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 10 * scale))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10 * scale)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 12)
                    .clipped()
                    .allowsHitTesting(false)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            .clipped()
            
            // Bottom Timeline & Playback Bar
            HStack(spacing: 16) {
                Button(action: onPlay) {
                    Label(isPlaying ? l10n("重新播放", "Replay") : l10n("播放進場動畫", "Play Animation"), systemImage: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#2563EB"))
                .contentShape(Rectangle())
                
                Button(action: onReset) {
                    Label(l10n("重置狀態", "Reset"), systemImage: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .contentShape(Rectangle())
                
                Spacer()
                
                // Native linear progress bar without nested GeometryReader
                ProgressView(
                    value: min(currentTime, max(totalDuration, 0.001)),
                    total: max(totalDuration, 0.001)
                )
                .progressViewStyle(.linear)
                .frame(width: 200)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(white: 0.08))
            .overlay(
                Divider().background(Color(white: 0.15)).allowsHitTesting(false),
                alignment: .top
            )
        }
        .clipped()
    }
}
