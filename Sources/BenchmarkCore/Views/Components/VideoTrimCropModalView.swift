import SwiftUI
import AVFoundation
import AppKit

@MainActor
public final class VideoTrimState: ObservableObject {
    @Published public var currentFrame: CGImage?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var videoTotalDuration: Double = 0.0
    @Published public var startVal: Double = 0.0
    @Published public var endVal: Double = 0.0
    
    private var asset: AVURLAsset?
    private var generator: AVAssetImageGenerator?
    private var timer: Timer?
    
    public init() {}
    
    public func load(url: URL, config: CustomVideoConfig) {
        let asset = AVURLAsset(url: url)
        self.asset = asset
        
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 960, height: 540)
        gen.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
        self.generator = gen
        
        Task {
            let duration = (try? await asset.load(.duration)) ?? .zero
            let totalSeconds = CMTimeGetSeconds(duration)
            let safeTotal = (totalSeconds.isNaN || totalSeconds <= 0) ? 10.0 : totalSeconds
            
            await MainActor.run {
                self.videoTotalDuration = safeTotal
                self.startVal = max(0.0, config.trimStartTime)
                if config.trimEndTime > self.startVal && config.trimEndTime <= self.videoTotalDuration {
                    self.endVal = config.trimEndTime
                } else {
                    self.endVal = self.videoTotalDuration
                }
                self.currentTime = self.startVal
                self.updateFrame(at: self.startVal)
            }
        }
    }
    
    public func seekTo(_ seconds: Double) {
        self.currentTime = min(max(0, seconds), videoTotalDuration)
        updateFrame(at: self.currentTime)
    }
    
    public func updateFrame(at seconds: Double) {
        guard let gen = generator else { return }
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        if let cgImg = try? gen.copyCGImage(at: cmTime, actualTime: nil) {
            self.currentFrame = cgImg
        }
    }
    
    public func togglePlay() {
        if isPlaying {
            stopPlay()
        } else {
            startPlay()
        }
    }
    
    public func startPlay() {
        isPlaying = true
        if currentTime >= endVal {
            currentTime = startVal
        }
        timer?.invalidate()
        let interval: Double = 1.0 / 30.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying else { return }
                self.currentTime += interval
                if self.currentTime >= self.endVal {
                    self.currentTime = self.startVal
                }
                self.updateFrame(at: self.currentTime)
            }
        }
    }
    
    public func stopPlay() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
    
    public func stopAndClean() {
        stopPlay()
        generator = nil
        asset = nil
        currentFrame = nil
    }
    
    deinit {
        timer?.invalidate()
    }
}

public struct VideoTrimCropModalView: View {
    public let videoURL: URL
    @Binding public var config: CustomVideoConfig
    public let chartDuration: Double
    public let onApply: () -> Void
    public let onCancel: () -> Void
    
    @StateObject private var state = VideoTrimState()
    
    // 預設比例清單
    private let presetAspectRatios: [(id: String, name: String, desc: String)] = [
        ("original", "原始比例", "保持影片拍攝比例"),
        ("16:9", "16:9 寬螢幕", "YouTube / 電腦橫向標準"),
        ("4:3", "4:3 標準", "iPad / 傳統螢幕比例"),
        ("1:1", "1:1 正方", "社群方形發布格式"),
        ("9:16", "9:16 直式", "Reels / TikTok 直式短影音")
    ]
    
    public init(
        videoURL: URL,
        config: Binding<CustomVideoConfig>,
        chartDuration: Double = 3.5,
        onApply: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.videoURL = videoURL
        self._config = config
        self.chartDuration = chartDuration
        self.onApply = onApply
        self.onCancel = onCancel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#8B5CF6"))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n("自訂背景影片可視化剪輯與比例", "Visual Video Trim & Crop"))
                            .font(.system(size: 14, weight: .bold))
                        Text(l10n("裁剪播放長度、設定預設畫面比例，並決定是否填滿畫布", "Trim playback range, select preset aspect ratio, and decide fill mode"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    state.stopAndClean()
                    onCancel()
                }) {
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
            
            // MARK: - Body Content
            ScrollView {
                VStack(spacing: 16) {
                    // 1. 可視化影片預覽視窗 (純 SwiftUI 解碼渲染，保證絕不崩潰)
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                        
                        if let frame = state.currentFrame {
                            GeometryReader { geo in
                                let w = geo.size.width
                                let h = geo.size.height
                                let targetRatio = parseAspectRatioValue(config.cropAspectRatio)
                                
                                ZStack {
                                    MediaFrameView(
                                        cgImage: frame,
                                        cropAspectRatio: config.cropAspectRatio,
                                        contentMode: config.contentMode
                                    )
                                    .frame(width: w, height: h)
                                    .clipped()
                                    
                                    // 預設比例可視化裁切框與九宮格輔助線
                                    if let ratio = targetRatio {
                                        let containerRatio = w / max(1, h)
                                        let boxW: CGFloat = (ratio > containerRatio) ? w * 0.92 : h * 0.92 * ratio
                                        let boxH: CGFloat = (ratio > containerRatio) ? (w * 0.92) / ratio : h * 0.92
                                        
                                        // 裁切框邊框與九宮格
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                                            .frame(width: boxW, height: boxH)
                                            .overlay(
                                                VStack(spacing: 0) {
                                                    Spacer()
                                                    Divider().background(Color.white.opacity(0.3))
                                                    Spacer()
                                                    Divider().background(Color.white.opacity(0.3))
                                                    Spacer()
                                                }
                                                .overlay(
                                                    HStack(spacing: 0) {
                                                        Spacer()
                                                        Divider().background(Color.white.opacity(0.3))
                                                        Spacer()
                                                        Divider().background(Color.white.opacity(0.3))
                                                        Spacer()
                                                    }
                                                )
                                            )
                                            .overlay(
                                                Text(config.cropAspectRatio)
                                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple.opacity(0.85))
                                                    .cornerRadius(4)
                                                    .padding(6),
                                                alignment: .topTrailing
                                            )
                                    }
                                }
                                .frame(width: w, height: h)
                            }
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        // 底部播放控制浮動條
                        VStack {
                            Spacer()
                            HStack(spacing: 12) {
                                Button(action: { state.togglePlay() }) {
                                    Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                                
                                Text(formatTime(state.currentTime))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text(l10n("影片總長: \(formatTime(state.videoTotalDuration))", "Duration: \(formatTime(state.videoTotalDuration))"))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(white: 0.8))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(8)
                        }
                    )
                    
                    // 2. 影片播放長度裁剪 (Trim Range)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(l10n("影片長度裁剪 (Trim Range)", "Video Playback Trim Range"))
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            let trimmedLen = max(0.1, state.endVal - state.startVal)
                            Text(l10n("剪輯時長: \(String(format: "%.1f", trimmedLen)) 秒", "Trimmed: \(String(format: "%.1f", trimmedLen))s"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#60A5FA"))
                        }
                        
                        // 開始時間
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(l10n("開始時間點 (Start Time)", "Start Time"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatTime(state.startVal))
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            Slider(value: $state.startVal, in: 0...max(0.1, state.videoTotalDuration - 0.5), step: 0.1) { _ in
                                if state.startVal >= state.endVal {
                                    state.endVal = min(state.videoTotalDuration, state.startVal + 0.5)
                                }
                                state.seekTo(state.startVal)
                            }
                        }
                        
                        // 結束時間
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(l10n("結束時間點 (End Time)", "End Time"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatTime(state.endVal))
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            Slider(value: $state.endVal, in: min(state.videoTotalDuration, state.startVal + 0.5)...max(0.5, state.videoTotalDuration), step: 0.1) { _ in
                                state.seekTo(state.endVal)
                            }
                        }
                        
                        // 快速設定按鈕
                        HStack(spacing: 8) {
                            Button(l10n("設起點為當前點", "Set Start = Now")) {
                                state.startVal = state.currentTime
                                if state.startVal >= state.endVal {
                                    state.endVal = min(state.videoTotalDuration, state.startVal + 0.5)
                                }
                                state.seekTo(state.startVal)
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 10))
                            
                            Button(l10n("設終點為當前點", "Set End = Now")) {
                                state.endVal = max(state.startVal + 0.5, state.currentTime)
                                state.seekTo(state.endVal)
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 10))
                            
                            Button(l10n("重置為完整長度", "Reset Full")) {
                                state.startVal = 0.0
                                state.endVal = state.videoTotalDuration
                                state.seekTo(0.0)
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 10))
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    // 3. 預設比例選擇 (提供預設比例：16:9, 4:3, 1:1, 9:16 等)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n("設定畫面比例 (預設比例)", "Preset Aspect Ratio"))
                            .font(.system(size: 12, weight: .bold))
                        
                        HStack(spacing: 6) {
                            ForEach(presetAspectRatios, id: \.id) { item in
                                let isSelected = (config.cropAspectRatio == item.id)
                                Button(action: {
                                    config.cropAspectRatio = item.id
                                }) {
                                    VStack(spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                            .foregroundColor(isSelected ? .white : Color(white: 0.7))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color(hex: "#7C3AED") : Color.white.opacity(0.06))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? Color(hex: "#A855F7") : Color.white.opacity(0.12), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    // 4. 決定是否填滿畫面 (Fill vs Fit)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n("畫面呈現模式 (決定是否填滿畫面)", "Fill Mode Decision"))
                            .font(.system(size: 12, weight: .bold))
                        
                        Picker("", selection: $config.contentMode) {
                            Text(l10n("填滿畫面 (滿版裁切黑邊)", "Fill Canvas (Crop excess borders)")).tag("fill")
                            Text(l10n("等比適應 (完整呈現保留留白)", "Fit Content (Keep full media with borders)")).tag("fit")
                        }
                        .pickerStyle(.segmented)
                        
                        Text(config.contentMode == "fill" ?
                             l10n("✦ 填滿畫面：影片等比例放大至滿版填滿畫布，多餘邊界將自動裁切，畫面無黑邊。", "Fill: Video expands to cover the canvas completely without letterboxing.") :
                             l10n("✦ 等比適應：完整保留全片畫面內容不被裁切，未填滿區域以純黑底色呈現。", "Fit: Entire video is shown inside canvas with letterboxing/pillarboxing."))
                            .font(.system(size: 9))
                            .foregroundColor(Color(white: 0.6))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    // 5. 超長播放選項 (若影片長於動畫，接續播放)
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(
                            l10n("若影片長於動畫，背景繼續播放直到影片結束（數據圖表維持結束態）", "Continue playing background video until end if longer than chart"),
                            isOn: $config.extendPlaybackUntilVideoEnds
                        )
                        .font(.system(size: 11, weight: .semibold))
                        
                        let trimmedLen = max(0.1, state.endVal - state.startVal)
                        if trimmedLen > chartDuration && config.extendPlaybackUntilVideoEnds {
                            Text(l10n("✦ 影片剪輯長度 (\(String(format: "%.1f", trimmedLen))s) 超過圖表動畫時長 (\(String(format: "%.1f", chartDuration))s)，動畫完成後背景將持續播放 \(String(format: "%.1f", trimmedLen - chartDuration)) 秒。", "✦ Video (\(String(format: "%.1f", trimmedLen))s) exceeds chart (\(String(format: "%.1f", chartDuration))s). Background continues +\(String(format: "%.1f", trimmedLen - chartDuration))s."))
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "#10B981"))
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                }
                .padding(20)
            }
            .frame(maxHeight: 460)
            
            Divider()
            
            // MARK: - Footer Actions
            HStack {
                Button(l10n("取消", "Cancel")) {
                    state.stopAndClean()
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(width: 75)
                
                Spacer()
                
                Button(action: saveAndApply) {
                    Label(l10n("套用並完成", "Apply & Save"), systemImage: "checkmark.circle.fill")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#7C3AED"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.04))
        }
        .frame(width: 600, height: 620)
        .background(Color(white: 0.13))
        .onAppear {
            state.load(url: videoURL, config: config)
        }
        .onDisappear {
            state.stopAndClean()
        }
    }
    
    private func saveAndApply() {
        config.trimStartTime = state.startVal
        config.trimEndTime = state.endVal
        state.stopAndClean()
        onApply()
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1.0)) * 10)
        return String(format: "%02d:%02d.%d", mins, secs, ms)
    }
}
