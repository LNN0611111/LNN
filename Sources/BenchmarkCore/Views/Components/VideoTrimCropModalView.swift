import SwiftUI
import AVKit
import AVFoundation

@MainActor
public final class VideoTrimState: ObservableObject {
    @Published public var player: AVPlayer?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var videoTotalDuration: Double = 0.0
    @Published public var startVal: Double = 0.0
    @Published public var endVal: Double = 0.0
    public var timeObserver: Any?
    
    public init() {}
    
    public func stopAndClean() {
        if let p = player, let obs = timeObserver {
            p.removeTimeObserver(obs)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
    }
}

public struct VideoTrimCropModalView: View {
    public let videoURL: URL
    @Binding public var config: CustomVideoConfig
    public let chartDuration: Double
    public let onApply: () -> Void
    public let onCancel: () -> Void
    
    @StateObject private var state = VideoTrimState()
    
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
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n("自訂背景影片可視化剪輯與比例", "Visual Video Trim & Crop"))
                        .font(.system(size: 14, weight: .bold))
                    Text(l10n("裁剪影片播放長度、設定畫面比例與超長接續播放模式", "Trim playback range, set aspect ratio, and configure extended playback"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
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
            
            // Player & Controls Body
            ScrollView {
                VStack(spacing: 18) {
                    // 1. AVPlayer Video Preview Box
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black)
                            .frame(height: 240)
                        
                        if let player = state.player {
                            VideoPlayer(player: player)
                                .frame(height: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            ProgressView()
                                .frame(height: 240)
                        }
                    }
                    .overlay(
                        VStack {
                            Spacer()
                            // Floating playback bar
                            HStack(spacing: 12) {
                                Button(action: togglePlay) {
                                    Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                                
                                Text(formatTime(state.currentTime))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("總長: \(formatTime(state.videoTotalDuration))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(white: 0.8))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(8)
                        }
                    )
                    .frame(height: 240)
                    
                    // 2. Length Trimming Controls (長度裁剪)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(l10n("影片播放長度裁剪 (Trim Range)", "Video Playback Trim Range"))
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            let trimmedLen = max(0.1, state.endVal - state.startVal)
                            Text(l10n("剪輯時長: \(String(format: "%.1f", trimmedLen)) 秒", "Trimmed: \(String(format: "%.1f", trimmedLen))s"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#60A5FA"))
                        }
                        
                        // Start Slider
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(l10n("開始時間 (Start Time)", "Start Time"))
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
                                seekTo(state.startVal)
                            }
                        }
                        
                        // End Slider
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(l10n("結束時間 (End Time)", "End Time"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatTime(state.endVal))
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            Slider(value: $state.endVal, in: min(state.videoTotalDuration, state.startVal + 0.5)...max(0.5, state.videoTotalDuration), step: 0.1) { _ in
                                seekTo(state.endVal)
                            }
                        }
                        
                        // Quick Action Buttons
                        HStack(spacing: 8) {
                            Button(l10n("設起點為當前播放點", "Set Start = Current")) {
                                state.startVal = state.currentTime
                                if state.startVal >= state.endVal { state.endVal = min(state.videoTotalDuration, state.startVal + 0.5) }
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 10))
                            
                            Button(l10n("設終點為當前播放點", "Set End = Current")) {
                                state.endVal = max(state.startVal + 0.5, state.currentTime)
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 10))
                            
                            Button(l10n("重置全長", "Reset Full")) {
                                state.startVal = 0.0
                                state.endVal = state.videoTotalDuration
                                seekTo(0.0)
                            }
                            .buttonStyle(.bordered)
                            .font(.system(size: 10))
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    // 3. Aspect Ratio & Content Mode (比例與裁切模式)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(l10n("影片比例與填滿模式", "Aspect Ratio & Fit Mode"))
                            .font(.system(size: 12, weight: .bold))
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("裁切比例", "Aspect Ratio"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $config.cropAspectRatio) {
                                    Text("原始比例").tag("original")
                                    Text("16:9 (橫片)").tag("16:9")
                                    Text("9:16 (直片)").tag("9:16")
                                    Text("4:3 (平板)").tag("4:3")
                                    Text("1:1 (正方)").tag("1:1")
                                }
                                .labelsHidden()
                                .frame(width: 140)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l10n("畫面呈現", "Content Mode"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $config.contentMode) {
                                    Text("滿版填滿 (裁切黑邊)").tag("fill")
                                    Text("完整適應 (等比留邊)").tag("fit")
                                }
                                .labelsHidden()
                                .frame(width: 160)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    
                    // 4. Extended Playback Option (超長接續播放)
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(
                            l10n("若影片長於動畫，背景繼續播放直到影片結束（數據圖表維持完成狀態）", "If video is longer than animation, continue video playback until video ends while chart stays completed"),
                            isOn: $config.extendPlaybackUntilVideoEnds
                        )
                        .font(.system(size: 11, weight: .bold))
                        
                        let trimmedLen = max(0.1, state.endVal - state.startVal)
                        HStack {
                            Text(l10n("圖表動畫時長：\(String(format: "%.1f", chartDuration))s | 剪輯影片時長：\(String(format: "%.1f", trimmedLen))s", "Chart anim: \(String(format: "%.1f", chartDuration))s | Video: \(String(format: "%.1f", trimmedLen))s"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            if trimmedLen > chartDuration && config.extendPlaybackUntilVideoEnds {
                                Text(l10n("✦ 將額外播放 \(String(format: "%.1f", trimmedLen - chartDuration)) 秒", "✦ Plays +\(String(format: "%.1f", trimmedLen - chartDuration))s extra"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(hex: "#10B981"))
                            }
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
            
            // Footer Action Buttons
            HStack {
                Button(l10n("取消", "Cancel")) {
                    state.stopAndClean()
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(width: 75)
                
                Spacer()
                
                Button(action: saveAndApply) {
                    Label(l10n("儲存並套用剪輯", "Apply Trim & Crop"), systemImage: "checkmark.circle.fill")
                        .frame(minWidth: 130)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#7C3AED"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.04))
        }
        .frame(width: 580, height: 600)
        .background(Color(white: 0.13))
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            state.stopAndClean()
        }
    }
    
    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL)
        Task {
            let duration = (try? await asset.load(.duration)) ?? .zero
            let totalSeconds = CMTimeGetSeconds(duration)
            await MainActor.run {
                state.videoTotalDuration = max(0.1, totalSeconds)
                state.startVal = max(0.0, config.trimStartTime)
                if config.trimEndTime > state.startVal && config.trimEndTime <= state.videoTotalDuration {
                    state.endVal = config.trimEndTime
                } else {
                    state.endVal = state.videoTotalDuration
                }
                
                let p = AVPlayer(url: videoURL)
                p.isMuted = true
                state.player = p
                
                let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
                state.timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak state] time in
                    guard let state = state else { return }
                    state.currentTime = CMTimeGetSeconds(time)
                    if state.currentTime >= state.endVal {
                        seekTo(state.startVal)
                    }
                }
                seekTo(state.startVal)
            }
        }
    }
    
    private func togglePlay() {
        guard let p = state.player else { return }
        if state.isPlaying {
            p.pause()
            state.isPlaying = false
        } else {
            if state.currentTime >= state.endVal {
                seekTo(state.startVal)
            }
            p.play()
            state.isPlaying = true
        }
    }
    
    private func seekTo(_ seconds: Double) {
        guard let p = state.player else { return }
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        p.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        state.currentTime = seconds
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
