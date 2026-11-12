import SwiftUI
import AVKit
import AppKit

/// 解析畫面比例字串為數值 (如 "16:9" -> 1.7777...)
public func parseAspectRatioValue(_ ratioString: String) -> CGFloat? {
    switch ratioString {
    case "16:9": return 16.0 / 9.0
    case "4:3":  return 4.0 / 3.0
    case "1:1":  return 1.0
    case "9:16": return 9.0 / 16.0
    case "21:9": return 21.0 / 9.0
    default:     return nil
    }
}

/// 純 SwiftUI 影音背景圖層渲染器：100% 遵守幾何限制，絕不覆蓋標題與圖表，支援縮放與任意長寬比
public struct MediaFrameView: View {
    public var cgImage: CGImage
    public var cropAspectRatio: String
    public var contentMode: String // "fill" (填滿裁切) 或 "fit" (等比留邊)
    
    public init(cgImage: CGImage, cropAspectRatio: String = "original", contentMode: String = "fill") {
        self.cgImage = cgImage
        self.cropAspectRatio = cropAspectRatio
        self.contentMode = contentMode
    }
    
    public var body: some View {
        GeometryReader { geo in
            let isFill = (contentMode == "fill")
            let containerW = max(geo.size.width, 1)
            let containerH = max(geo.size.height, 1)
            let targetRatio = parseAspectRatioValue(cropAspectRatio)
            
            ZStack {
                // 背景純黑基底 (留邊適應時提供乾淨黑邊)
                Color.black
                
                if let ratio = targetRatio {
                    // 依據用戶指定的預設比例 (16:9, 4:3, 1:1, 9:16 等) 進行裁切與適配
                    if isFill {
                        // 填滿畫布模式：以目標比例等比放大並滿版填滿
                        Image(decorative: cgImage, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .aspectRatio(ratio, contentMode: .fill)
                            .frame(width: containerW, height: containerH)
                            .clipped()
                    } else {
                        // 等比適應模式：在畫布內部維持目標比例與黑邊
                        let containerRatio = containerW / containerH
                        let boxW: CGFloat = (ratio > containerRatio) ? containerW : containerH * ratio
                        let boxH: CGFloat = (ratio > containerRatio) ? containerW / ratio : containerH
                        
                        Image(decorative: cgImage, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: boxW, height: boxH)
                            .clipped()
                    }
                } else {
                    // 原始比例 (Original)
                    Image(decorative: cgImage, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: isFill ? .fill : .fit)
                        .frame(width: containerW, height: containerH)
                        .clipped()
                }
            }
            .frame(width: containerW, height: containerH)
            .clipped()
        }
    }
}

@MainActor
public final class VideoBackgroundState: ObservableObject {
    @Published public var currentFrame: CGImage?
    private var generator: AVAssetImageGenerator?
    private var displayTimer: Timer?
    private var startTime: Double = 0.0
    private var endTime: Double = 0.0
    private var playhead: Double = 0.0
    private var lastLoadedKey: String = ""
    
    public init() {}
    
    public func loadVideo(path: String, config: CustomVideoConfig) {
        let key = "\(path)_\(config.trimStartTime)_\(config.trimEndTime)"
        if lastLoadedKey == key && currentFrame != nil {
            return
        }
        lastLoadedKey = key
        
        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 1280, height: 720)
        gen.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
        self.generator = gen
        
        self.startTime = max(0.0, config.trimStartTime)
        let durationSec = CMTimeGetSeconds(asset.duration)
        let safeDuration = (durationSec.isNaN || durationSec <= 0) ? 10.0 : durationSec
        self.endTime = (config.trimEndTime > config.trimStartTime) ? min(config.trimEndTime, safeDuration) : safeDuration
        self.playhead = self.startTime
        
        // 立即提取首幀海報圖，保證 0 延遲即時呈現
        updateFrame(at: self.startTime)
        
        // 啟動預覽即時循環播放 (30 fps)
        startLoop()
    }
    
    public func startLoop() {
        stopLoop()
        let interval: Double = 1.0 / 30.0
        displayTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.playhead += interval
                if self.playhead >= self.endTime {
                    self.playhead = self.startTime
                }
                self.updateFrame(at: self.playhead)
            }
        }
    }
    
    public func stopLoop() {
        displayTimer?.invalidate()
        displayTimer = nil
    }
    
    private func updateFrame(at time: Double) {
        guard let gen = generator else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        if let cgImg = try? gen.copyCGImage(at: cmTime, actualTime: nil) {
            self.currentFrame = cgImg
        }
    }
    
    deinit {
        displayTimer?.invalidate()
    }
}

public struct CustomMediaBackgroundView: View {
    public var filePath: String?
    public var videoConfig: CustomVideoConfig
    
    @StateObject private var videoState = VideoBackgroundState()
    
    public init(filePath: String?, videoConfig: CustomVideoConfig = CustomVideoConfig()) {
        self.filePath = filePath
        self.videoConfig = videoConfig
    }
    
    public var body: some View {
        Group {
            if let path = filePath, FileManager.default.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                let ext = url.pathExtension.lowercased()
                
                if ["mp4", "mov", "m4v"].contains(ext) {
                    if let frame = videoState.currentFrame {
                        MediaFrameView(
                            cgImage: frame,
                            cropAspectRatio: videoConfig.cropAspectRatio,
                            contentMode: videoConfig.contentMode
                        )
                    } else {
                        // 正在載入或解碼前顯示沉浸深色背景
                        Color.black
                            .onAppear {
                                videoState.loadVideo(path: path, config: videoConfig)
                            }
                    }
                } else if let nsImage = NSImage(contentsOf: url) {
                    var rect = CGRect(origin: .zero, size: nsImage.size)
                    if let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
                        MediaFrameView(
                            cgImage: cgImage,
                            cropAspectRatio: videoConfig.cropAspectRatio,
                            contentMode: videoConfig.contentMode
                        )
                    } else {
                        Color.black
                    }
                } else {
                    Color.black
                }
            } else {
                Color.black
            }
        }
        .onAppear {
            if let path = filePath {
                let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
                if ["mp4", "mov", "m4v"].contains(ext) {
                    videoState.loadVideo(path: path, config: videoConfig)
                }
            }
        }
        .onChange(of: filePath) { newPath in
            if let p = newPath {
                let ext = URL(fileURLWithPath: p).pathExtension.lowercased()
                if ["mp4", "mov", "m4v"].contains(ext) {
                    videoState.loadVideo(path: p, config: videoConfig)
                }
            }
        }
        .onChange(of: videoConfig) { newConfig in
            if let p = filePath {
                let ext = URL(fileURLWithPath: p).pathExtension.lowercased()
                if ["mp4", "mov", "m4v"].contains(ext) {
                    videoState.loadVideo(path: p, config: newConfig)
                }
            }
        }
    }
}
